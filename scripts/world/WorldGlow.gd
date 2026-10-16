class_name WorldGlow
extends Node3D

## BRILHO DO MUNDO — só visual (nenhuma regra de jogo lê nada daqui). Pedido do usuário 2026-10-12: "ponha o cristal e
## o nódulo arcano para terem um certo brilho, que ilumine inclusive o mapa dependendo da iluminação... faça de forma
## que possamos utilizar esse mesmo efeito em outras coisas no futuro".
##
## Um ponto só para tudo que brilha no mapa. Quem brilha é descrito por um PERFIL (GlowProfiles) e pede duas coisas:
##  - a LUZ que ilumina o mapa em volta: add_light(grupo, chave, posição, perfil). Um OmniLight3D sem sombra por fonte,
##    filho deste nó. `grupo` é de quem pediu (hoje "resources", do ResourcePropsManager): cada sistema limpa e
##    reconstrói só as suas (clear_group);
##  - a EMISSÃO do próprio modelo: prop_material(material do modelo, perfil) devolve o shaders/glow_prop.gdshader com
##    a aparência do material original mais o brilho.
## Os dois seguem a ESCURIDÃO da cena (0 = dia, 1 = noite profunda), que vem do DayNightController: a luz por
## set_darkness (energia = light_energy × GlowProfiles.strength) e a emissão pelo parâmetro global de shader
## `world_darkness`, que o próprio controlador de dia e noite envia. De dia sobra só `day_strength` do perfil.
##
## NÉVOA DE GUERRA: quem pediu a luz diz quando ela aparece (set_light_shown) — luz em tile não visível agora
## entregaria o que há ali. A luz nasce apagada.
##
## COISAS QUE SE MOVEM (2026-10-13, núcleos das Grandes Manifestações): attach_light prende a luz a um nó do próprio
## modelo (o osso do núcleo) em vez de a um ponto do mapa — ela anda, flutua e some junto com a criatura (névoa,
## embarque e morte não precisam de código: a luz é descendente do modelo). track_emission faz o mapa de emissão que
## o modelo JÁ tem crescer com a escuridão, como o dos cristais.
##
## CAMADAS (opções de vídeo "Luzes do mapa" e "Luzes das criaturas"): cada grupo pertence a uma camada (layer_of);
## set_layer_enabled apaga/acende todas as LUZES dela de uma vez. A emissão do próprio modelo não é luz e continua.
##
## CUSTO: Forward+ agrupa luzes por cluster; sem sombra, cada uma só pesa nos pixels que alcança. Luz apagada
## (névoa) ou de energia zero fica `visible = false` e não entra no quadro. A energia só é reenviada quando a escuridão
## muda mais que DARKNESS_STEP, nunca por quadro. Medição em docs/PERFORMANCE_GUIDE.md.

const DARKNESS_SHADER_PARAM := &"world_darkness"
const PROP_SHADER := preload("res://shaders/glow_prop.gdshader")
## Mudança mínima de escuridão para reenviar a energia das luzes (o anoitecer inteiro vira ~100 passos).
const DARKNESS_STEP := 0.01
## Abaixo disto a luz não contribui com nada visível e sai do quadro.
const MIN_VISIBLE_ENERGY := 0.01

## Camadas de luz que o jogador pode desligar em Configurações → Vídeo.
const LAYER_MAP := &"map"
const LAYER_CREATURES := &"creatures"
## Grupo das luzes presas a unidades (Unit._build_core_glow).
const GROUP_UNITS := &"units"
const GROUP_CASTING := &"casting"
## Grupo -> camada. Grupo fora da tabela é do mapa (recursos e o que vier: prédios, biomas).
const GROUP_LAYERS := {GROUP_UNITS: LAYER_CREATURES, GROUP_CASTING: LAYER_CREATURES}
## Meta do material com a cor de emissão original (track_emission): a base nunca se perde entre partidas.
const BASE_EMISSION_META := &"world_glow_base_emission"

var darkness := 0.0
## grupo (StringName) -> { chave -> {"light": OmniLight3D, "profile": StringName, "shown": bool, "layer": StringName} }
var _groups: Dictionary = {}
var _disabled_layers: Dictionary = {}
## id do material -> {"material": WeakRef, "profile": StringName}
var _emissive: Dictionary = {}

static func layer_of(group: StringName) -> StringName:
	return GROUP_LAYERS.get(group, LAYER_MAP)

func _init() -> void:
	name = "WorldGlow"

# --- Escuridão da cena ------------------------------------------------------------------------------------------------

## Escuridão atual da cena (DayNightController.darkness_changed). Reaplica a energia das luzes acesas.
func set_darkness(value: float) -> void:
	var target := clampf(value, 0.0, 1.0)
	# Os extremos sempre passam (o dia volta exatamente ao mínimo e a noite chega exatamente ao máximo).
	if absf(target - darkness) < DARKNESS_STEP and not ((target == 0.0 or target == 1.0) and target != darkness):
		return
	darkness = target
	_reapply_lights()
	_apply_emission()

## Reaplica a energia de todas as luzes; aproveita para esquecer as que morreram com o dono (unidade removida).
func _reapply_lights() -> void:
	for group in _groups.values():
		var entries: Dictionary = group
		for key in entries.keys():
			if is_instance_valid(entries[key].light):
				_apply(entries[key])
			else:
				entries.erase(key)

# --- Camadas (opções de vídeo) ----------------------------------------------------------------------------------------

## Liga/desliga todas as luzes de uma camada (LAYER_MAP, LAYER_CREATURES). Só as luzes: a emissão dos modelos fica.
func set_layer_enabled(layer: StringName, enabled: bool) -> void:
	if is_layer_enabled(layer) == enabled:
		return
	if enabled:
		_disabled_layers.erase(layer)
	else:
		_disabled_layers[layer] = true
	_reapply_lights()

func is_layer_enabled(layer: StringName) -> bool:
	return not _disabled_layers.has(layer)

## As duas opções de Configurações → Vídeo de uma vez (Main._apply_graphics_settings).
func apply_lighting_settings(map_lights: bool, creature_lights: bool) -> void:
	set_layer_enabled(LAYER_MAP, map_lights)
	set_layer_enabled(LAYER_CREATURES, creature_lights)

# --- Luzes --------------------------------------------------------------------------------------------------------------

## Cria (ou move/troca o perfil de) a luz `key` do grupo `group` em `world_position` — o ponto de APOIO (o chão); a
## altura acima dele vem do perfil. Nasce apagada: quem pediu acende com set_light_shown. Perfil desconhecido = nada.
func add_light(group: StringName, key: Variant, world_position: Vector3, profile_id: StringName) -> OmniLight3D:
	var profile := GlowProfiles.profile(profile_id)
	if profile.is_empty():
		return null
	var entries: Dictionary = _groups.get(group, {})
	_groups[group] = entries
	var entry: Dictionary = entries.get(key, {})
	var light: OmniLight3D = entry.get("light")
	if light == null or not is_instance_valid(light):
		light = OmniLight3D.new()
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		entry = {"light": light, "profile": profile_id, "shown": false, "layer": layer_of(group)}
		entries[key] = entry
	entry.profile = profile_id
	light.light_color = profile.light_color
	light.omni_range = float(profile.light_range)
	light.omni_attenuation = float(profile.light_attenuation)
	light.position = world_position + Vector3(0.0, float(profile.light_height), 0.0)
	_apply(entry)
	return light

## Luz PRESA a `anchor` (um nó do próprio modelo: o osso do núcleo de uma criatura), em `offset` local. Segue o nó em
## tudo — posição, animação, visibilidade (névoa de guerra, modelo escondido) e fim de vida — então nasce ACESA e
## ninguém precisa movê-la nem removê-la. Pedir de novo a mesma chave com outro nó (modelo reconstruído) troca a luz.
func attach_light(group: StringName, key: Variant, anchor: Node3D, profile_id: StringName, offset: Vector3 = Vector3.ZERO) -> OmniLight3D:
	var profile := GlowProfiles.profile(profile_id)
	if profile.is_empty() or anchor == null or not is_instance_valid(anchor):
		return null
	var entries: Dictionary = _groups.get(group, {})
	_groups[group] = entries
	var previous: OmniLight3D = (entries.get(key, {}) as Dictionary).get("light")
	if previous != null and is_instance_valid(previous) and previous.get_parent() != anchor:
		previous.queue_free()
		previous = null
	var light := previous if previous != null and is_instance_valid(previous) else OmniLight3D.new()
	if light.get_parent() == null:
		light.name = "GlowLight"
		light.shadow_enabled = false
		anchor.add_child(light)
	light.light_color = profile.light_color
	light.omni_range = float(profile.light_range)
	light.omni_attenuation = float(profile.light_attenuation)
	light.position = offset + Vector3(0.0, float(profile.light_height), 0.0)
	var entry := {"light": light, "profile": profile_id, "shown": true, "layer": layer_of(group)}
	entries[key] = entry
	_apply(entry)
	return light

func remove_light(group: StringName, key: Variant) -> void:
	var entries: Dictionary = _groups.get(group, {})
	if not entries.has(key):
		return
	var light: OmniLight3D = entries[key].light
	if is_instance_valid(light):
		light.queue_free()
	entries.erase(key)

## Apaga todas as luzes de um grupo (quem pediu vai reconstruir as suas).
func clear_group(group: StringName) -> void:
	for entry in (_groups.get(group, {}) as Dictionary).values():
		if is_instance_valid(entry.light):
			entry.light.queue_free()
	_groups.erase(group)

## Acende/apaga a luz sem destruí-la (névoa de guerra, ocultação temporária).
func set_light_shown(group: StringName, key: Variant, shown: bool) -> void:
	var entries: Dictionary = _groups.get(group, {})
	if not entries.has(key):
		return
	var entry: Dictionary = entries[key]
	if bool(entry.shown) == shown:
		return
	entry.shown = shown
	_apply(entry)

## Temporary intensity envelope, used by staff/core charging without bypassing scene lighting.
func set_light_gain(group: StringName, key: Variant, gain: float) -> void:
	var entries: Dictionary = _groups.get(group,{})
	if not entries.has(key): return
	entries[key].gain = clampf(gain,0.0,2.0)
	_apply(entries[key])

## Reposiciona o ponto de apoio de uma luz (o chão do tile mudou de altura).
func move_light(group: StringName, key: Variant, world_position: Vector3) -> void:
	var entries: Dictionary = _groups.get(group, {})
	if not entries.has(key) or not is_instance_valid(entries[key].light):
		return
	var profile := GlowProfiles.profile(entries[key].profile)
	(entries[key].light as OmniLight3D).position = world_position + Vector3(0.0, float(profile.get("light_height", 0.0)), 0.0)

func has_light(group: StringName, key: Variant) -> bool:
	return (_groups.get(group, {}) as Dictionary).has(key)

func get_light(group: StringName, key: Variant) -> OmniLight3D:
	var entries: Dictionary = _groups.get(group, {})
	return entries[key].light if entries.has(key) else null

## Luzes vivas (as de donos que já morreram não contam).
func light_count(group: StringName = &"") -> int:
	var total := 0
	for group_name in _groups:
		if group != &"" and group_name != group:
			continue
		for entry in (_groups[group_name] as Dictionary).values():
			if is_instance_valid(entry.light) and not (entry.light as Node).is_queued_for_deletion():
				total += 1
	return total

func _apply(entry: Dictionary) -> void:
	var light: OmniLight3D = entry.light
	if not is_instance_valid(light):
		return
	var energy := float(GlowProfiles.profile(entry.profile).light_energy) * GlowProfiles.strength(entry.profile, darkness)
	energy *= float(entry.get("gain",1.0))
	light.light_energy = energy
	light.visible = bool(entry.shown) and energy >= MIN_VISIBLE_ENERGY and is_layer_enabled(entry.get("layer", LAYER_MAP))

# --- Emissão do modelo ------------------------------------------------------------------------------------------------

## Faz a emissão que `material` JÁ tem (mapa de emissão do modelo) seguir a escuridão da cena pelo perfil: a cor de
## emissão original × GlowProfiles.emission_factor. Para materiais compartilhados por todas as instâncias de um modelo
## (o do GLB): registrar de novo o mesmo material não faz nada. Mexe na COR de emissão, não na energia — há modelo que
## anima a energia num clipe (o núcleo do Primordial) e os dois se multiplicam.
func track_emission(material: BaseMaterial3D, profile_id: StringName) -> void:
	if material == null or not material.emission_enabled or not GlowProfiles.has_profile(profile_id):
		return
	if not material.has_meta(BASE_EMISSION_META):
		material.set_meta(BASE_EMISSION_META, material.emission)
	_emissive[material.get_instance_id()] = {"material": weakref(material), "profile": profile_id}
	_apply_emission_to(material, profile_id)

func tracked_emission_count() -> int:
	return _emissive.size()

func _apply_emission() -> void:
	for id in _emissive.keys():
		var material := (_emissive[id].material as WeakRef).get_ref() as BaseMaterial3D
		if material == null:
			_emissive.erase(id)
		else:
			_apply_emission_to(material, _emissive[id].profile)

func _apply_emission_to(material: BaseMaterial3D, profile_id: StringName) -> void:
	var base: Color = material.get_meta(BASE_EMISSION_META, material.emission)
	var factor := GlowProfiles.emission_factor(profile_id, darkness)
	material.emission = Color(base.r * factor, base.g * factor, base.b * factor, base.a)

## Material de um prop que brilha: a aparência de `source` (textura, cor, rugosidade, metal, especular) no shader de
## brilho, com a emissão do perfil. `per_instance`: MultiMesh com use_custom_data, em que INSTANCE_CUSTOM.r liga o
## brilho de cada instância (névoa de guerra). Devolve null se o perfil não existe.
static func prop_material(source: BaseMaterial3D, profile_id: StringName, per_instance: bool = false) -> ShaderMaterial:
	var profile := GlowProfiles.profile(profile_id)
	if profile.is_empty():
		return null
	var material := ShaderMaterial.new()
	material.shader = PROP_SHADER
	if source != null:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		material.set_shader_parameter("albedo", source.albedo_color)
		material.set_shader_parameter("roughness", source.roughness)
		material.set_shader_parameter("metallic", source.metallic)
		material.set_shader_parameter("specular", source.metallic_specular)
	material.set_shader_parameter("glow_energy", float(profile.emission_energy))
	material.set_shader_parameter("glow_day_strength", float(profile.day_strength))
	material.set_shader_parameter("glow_per_instance", per_instance)
	return material
