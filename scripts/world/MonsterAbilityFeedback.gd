class_name MonsterAbilityFeedback
extends Node3D

## V3 / Etapa 3 — camada de APRESENTAÇÃO das habilidades e da ecologia (telegraph → execução → consequência).
## Só escuta EventBus.combat_ecology_event (que a lógica já emite com coordenadas) e desenha efeitos provisórios
## — texto flutuante, feixes, aros, tiles destacados, deslizes curtos, marcadores de território. Nada aqui é
## condição de gameplay: a lógica resolve tudo antes, instantaneamente (headless continua igual); a animação só
## representa o que já aconteceu.
##
## Segurança de visão: só desenha em tile VISÍVEL agora para o humano (feixe só com as duas pontas visíveis) — nunca
## revela monstro, alvo ou perigo ocultos. Reduced Motion: sem deslizes/expansões (marcas estáticas curtas). Sem RNG.

const LABEL_RISE := 0.7
const LABEL_TIME := 1.2
const EFFECT_TIME := 0.7
const COLORS := {
	"gold": Color(1.0, 0.82, 0.25), "poison": Color(0.45, 0.95, 0.3), "burn": Color(1.0, 0.5, 0.12),
	"stone": Color(0.72, 0.72, 0.75), "root": Color(0.5, 0.36, 0.15), "arcane": Color(0.68, 0.38, 1.0),
	"spore": Color(0.95, 0.45, 0.75), "heal": Color(0.45, 1.0, 0.55), "bone": Color(0.93, 0.9, 0.8),
	"hunt": Color(1.0, 0.25, 0.2), "dust": Color(0.6, 0.45, 0.3), "info": Color(0.85, 0.9, 1.0),
}
## Nome do território ecológico (sítio SEM estrutura) por espécie — "Covil" fica reservado à estrutura real.
const HABITAT_NAMES := {
	"goblin": "Acampamento Goblin", "skeleton": "Ossário", "worg": "Território de Worgs", "giant_spider": "Ninho de Aranhas",
	"troll": "Território de Troll", "wyvern": "Poleiro de Wyvern", "minotaur": "Território do Minotauro", "basilisk": "Toca do Basilisco",
	"colossal_worm": "Território do Verme", "arboreal_ancient": "Bosque Ancestral", "mana_devourer": "Fenda Arcana", "corrupted_hero": "Ruínas do Herói",
}

## Etapa 4: o "−2 Ouro" sobe acima da placa de nome da cidade (na validação visual ele encostava no nome).
const PLUNDER_LABEL_LIFT := 1.0

## Sem tela (lab/testes headless) os efeitos não são criados — custo zero na simulação. Testes ligam isto.
static var enabled_in_headless := false

var grid: HexGrid
var effects_spawned := 0 # telemetria de teste/visual (quantos efeitos foram desenhados)
var _site_markers: Dictionary = {} # site_id -> Node3D
var _label_stack: Dictionary = {} # coord -> rótulos ainda no ar (empilha em vez de sobrepor)

## Etapa 4 — texto do Saque Rápido: o valor exato só na cidade do próprio humano (o tesouro de um rival é privado; o
## evento visível — o saque — continua mostrado).
static func plunder_text(info: Dictionary) -> String:
	var index := int(info.get("target", -1))
	var own := index >= 0 and index < GameManager.players.size() and GameManager.players[index] == GameManager.human_player
	if not own:
		return "Saque!"
	var stolen := int(round(float(info.get("gold_stolen", 0.0))))
	return "−%d Ouro" % stolen if stolen > 0 else "Saque: tesouro vazio"

static func habitat_name(kind: String) -> String:
	return String(HABITAT_NAMES.get(kind, "Território de criaturas"))

func _init(owner_grid: HexGrid = null) -> void:
	grid = owner_grid
	name = "MonsterAbilityFeedback"

func _ready() -> void:
	if not EventBus.combat_ecology_event.is_connected(_on_event):
		EventBus.combat_ecology_event.connect(_on_event)
	if not EventBus.fog_updated.is_connected(refresh_site_markers):
		EventBus.fog_updated.connect(refresh_site_markers)

func _exit_tree() -> void:
	if EventBus.combat_ecology_event.is_connected(_on_event):
		EventBus.combat_ecology_event.disconnect(_on_event)
	if EventBus.fog_updated.is_connected(refresh_site_markers):
		EventBus.fog_updated.disconnect(refresh_site_markers)

# ---------------------------------------------------------------------------
# Visão
# ---------------------------------------------------------------------------

func _visible(coord: Vector2i) -> bool:
	if grid == null or not grid.tiles.has(coord):
		return false
	return grid.visibility.is_empty() or grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

static func _coord(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return HexGrid.NO_LAIR

func _motion() -> bool:
	return not Settings.reduced_motion and is_inside_tree()

# ---------------------------------------------------------------------------
# Roteamento de eventos
# ---------------------------------------------------------------------------

func _active() -> bool:
	return grid != null and is_inside_tree() and (enabled_in_headless or DisplayServer.get_name() != "headless")

func _on_event(action: String, info: Dictionary) -> void:
	if not _active():
		return
	var source := _coord(info.get("source"))
	var target := _coord(info.get("target_coord"))
	match action:
		"ability":
			_on_ability(String(info.get("ability", "")), info, source, target)
		"status_tick":
			var poison := String(info.get("status", "")) == UnitStatusEffects.POISON
			if _visible(target):
				_burst(target, COLORS.poison if poison else COLORS.burn)
				_label(target, "%s −%d" % ["Veneno" if poison else "Chamas", int(round(float(info.get("damage", 0.0))))], COLORS.poison if poison else COLORS.burn)
		"infection_damage":
			if _visible(target):
				_burst(target, COLORS.spore, 0.55)
				_label(target, "Esporos −%d" % int(round(float(info.get("damage", 0.0)))), COLORS.spore)
		"infection_entered":
			var at := _coord(info.get("coord"))
			if _visible(at):
				_label(at, "Área Micótica", COLORS.spore, 0.6)
		"aggro_acquire":
			# Só o monstro VISÍVEL ganha o "!" de aggro (nunca revela quem está escondido na névoa).
			if _visible(source):
				_label(source, "!", COLORS.hunt, 0.5)
		"site_depleted":
			var anchor := _coord(info.get("anchor"))
			if _visible(anchor):
				_label(anchor, "Área limpa", COLORS.info)
			refresh_site_markers()
		"refill":
			refresh_site_markers()

func _on_ability(id: String, info: Dictionary, source: Vector2i, target: Vector2i) -> void:
	match id:
		MonsterAbilityData.QUICK_PLUNDER:
			if _visible(target):
				_ring(target, COLORS.gold)
				_burst(target, COLORS.gold, 0.3)
				if _visible(source) and source != target:
					_beam(target, source, COLORS.gold, 0.035) # o saque "sai" da cidade para o Goblin
				_label(target, plunder_text(info), COLORS.gold, PLUNDER_LABEL_LIFT) # acima da placa de nome da cidade
		MonsterAbilityData.RISING_HORDE:
			if _visible(target):
				_burst(target, COLORS.bone, 0.6)
				_label(target, "Horda Crescente: ergueu-se!", COLORS.bone)
		MonsterAbilityData.BLOOD_SCENT:
			if info.has("isolated_hunted") and _visible(source) and _visible(target):
				_beam(source, target, COLORS.hunt, 0.04)
				_label(source, "Faro de Sangue", COLORS.hunt, 0.5)
		MonsterAbilityData.VENOMOUS_BITE:
			if _visible(target):
				_burst(target, COLORS.poison, 0.5)
				_label(target, "Envenenado", COLORS.poison)
		MonsterAbilityData.MONSTROUS_REGENERATION:
			if _visible(source):
				_ring(source, COLORS.heal)
				_label(source, "Regeneração +%d (sem dano no turno)" % int(round(float(info.get("healed", 0.0)))), COLORS.heal)
		MonsterAbilityData.FLAME_BREATH:
			var tiles: Array[Vector2i] = []
			for entry in info.get("tiles", []):
				var coord := _coord(entry)
				if _visible(coord):
					tiles.append(coord)
			if _visible(source) and not tiles.is_empty():
				_beam(source, tiles[0], COLORS.burn, 0.12)
			_tiles(tiles, COLORS.burn)
			if not tiles.is_empty():
				_label(tiles[0], "Sopro Incendiário", COLORS.burn)
		MonsterAbilityData.CHARGE:
			_charge(info, source)
		MonsterAbilityData.PETRIFYING_GAZE:
			if _visible(source) and _visible(target):
				_beam(source, target, COLORS.stone, 0.08)
			if _visible(target):
				_label(target, "Petrificação Parcial", COLORS.stone)
		MonsterAbilityData.SHIELD_BLOCK:
			if _visible(source):
				_ring(source, COLORS.stone)
				_label(source, "Bloqueou!", COLORS.info)
		MonsterAbilityData.BURROW:
			var dest := _coord(info.get("dest"))
			if String(info.get("stage", "")) == "burrow":
				if _visible(source):
					_ring(source, COLORS.dust)
					_label(source, "Escavou — foge sob a terra", COLORS.dust)
			elif _visible(dest):
				_ring(dest, COLORS.dust)
				_label(dest, "Emergiu", COLORS.dust)
		MonsterAbilityData.ROOTS_OF_THE_WORLD:
			var any := false
			for entry in info.get("tiles", []):
				var coord := _coord(entry)
				if _visible(coord):
					any = true
					if _visible(source):
						_beam(source, coord, COLORS.root, 0.05)
			if any and _visible(source):
				_label(source, "Raízes do Mundo", COLORS.root)
		MonsterAbilityData.ARCANE_HUNGER:
			if _visible(source) and _visible(target):
				_beam(target, source, COLORS.arcane, 0.05)
			if _visible(target):
				_label(target, "−%d Mana" % int(round(float(info.get("mana_drained", 0.0)))), COLORS.arcane)
			if _visible(source) and float(info.get("barrier", 0.0)) > 0.0:
				_label(source, "Barreira Arcana +%d" % int(round(float(info.barrier))), COLORS.arcane, 0.4)
		MonsterAbilityData.AETHER_RUPTURE:
			if _visible(source) and _visible(target):
				_beam(source, target, COLORS.arcane, 0.1)
			if _visible(target):
				_burst(target, COLORS.arcane, 0.5)
				_label(target, "Ruptura Etérea — Silenciado", COLORS.arcane)

## Investida: preparação no ponto de partida → seta da rota → deslize do Minotauro → impacto → empurrão da vítima.
func _charge(info: Dictionary, source: Vector2i) -> void:
	var landing := _coord(info.get("landing"))
	var victim_from := _coord(info.get("victim_from"))
	var victim_to := _coord(info.get("victim_to"))
	if not (_visible(source) or _visible(landing)):
		return
	_ring(source, COLORS.gold, 0.4)
	_beam(source, victim_from, COLORS.gold, 0.06)
	_label(landing, "Investida!", COLORS.gold)
	var minotaur := grid.get_unit_at(landing)
	if minotaur != null and _motion():
		var final := minotaur.position
		minotaur.position = grid.world_surface_for_coord(source)
		var tween := minotaur.create_tween()
		tween.tween_interval(0.25)
		tween.tween_property(minotaur, "position", final, 0.2)
	var outcome := String(info.get("outcome", ""))
	if outcome == "knockback":
		var victim := grid.get_unit_at(victim_to)
		if victim != null and _motion():
			var end := victim.position
			victim.position = grid.world_surface_for_coord(victim_from)
			var push := victim.create_tween()
			push.tween_interval(0.45)
			push.tween_property(victim, "position", end, 0.15)
		_ring(victim_to, COLORS.gold, 0.3)
	elif outcome == "blocked":
		_label(victim_from, "Abalado", COLORS.gold, 0.4)

# ---------------------------------------------------------------------------
# Primitivas de efeito (sem colisão, auto-liberadas, sem _process)
# ---------------------------------------------------------------------------

func _unshaded(color: Color, alpha: float = 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	return material

func _finish(node: Node3D, material: StandardMaterial3D, duration: float) -> void:
	effects_spawned += 1
	if not _motion():
		get_tree().create_timer(duration).timeout.connect(node.queue_free) # conexão some sozinha se o nó já saiu
		return
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(node.queue_free)

func _label(coord: Vector2i, text: String, color: Color, extra_height: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var slot := int(_label_stack.get(coord, 0))
	_label_stack[coord] = slot + 1
	label.position = grid.world_surface_for_coord(coord) + Vector3(0, 1.2 + extra_height + slot * 0.45, 0)
	effects_spawned += 1
	var tween := label.create_tween()
	if _motion():
		tween.tween_property(label, "position:y", label.position.y + LABEL_RISE, LABEL_TIME)
		tween.parallel().tween_property(label, "modulate:a", 0.0, LABEL_TIME)
	else:
		tween.tween_interval(LABEL_TIME)
	tween.tween_callback(_release_label_slot.bind(coord))
	tween.tween_callback(label.queue_free)

func _release_label_slot(coord: Vector2i) -> void:
	var left := int(_label_stack.get(coord, 1)) - 1
	if left <= 0:
		_label_stack.erase(coord)
	else:
		_label_stack[coord] = left

func _ring(coord: Vector2i, color: Color, radius: float = 0.55) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.8
	torus.outer_radius = radius
	ring.mesh = torus
	var material := _unshaded(color)
	ring.material_override = material
	add_child(ring)
	ring.position = grid.world_surface_for_coord(coord) + Vector3(0, 0.08, 0)
	if _motion():
		ring.create_tween().tween_property(ring, "scale", Vector3.ONE * 1.6, EFFECT_TIME)
	_finish(ring, material, EFFECT_TIME)

func _burst(coord: Vector2i, color: Color, size: float = 0.45) -> void:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	sphere.mesh = mesh
	var material := _unshaded(color, 0.55)
	sphere.material_override = material
	add_child(sphere)
	sphere.position = grid.world_surface_for_coord(coord) + Vector3(0, 0.5, 0)
	if _motion():
		sphere.scale = Vector3.ONE * 0.3
		sphere.create_tween().tween_property(sphere, "scale", Vector3.ONE * 1.4, EFFECT_TIME)
	_finish(sphere, material, EFFECT_TIME)

func _beam(from_coord: Vector2i, to_coord: Vector2i, color: Color, width: float = 0.06) -> void:
	var a := grid.world_surface_for_coord(from_coord) + Vector3(0, 0.6, 0)
	var b := grid.world_surface_for_coord(to_coord) + Vector3(0, 0.6, 0)
	var length := a.distance_to(b)
	if length <= 0.01:
		return
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	beam.mesh = mesh
	var material := _unshaded(color)
	beam.material_override = material
	add_child(beam)
	beam.position = (a + b) * 0.5
	beam.look_at_from_position(beam.position, b, Vector3.UP)
	_finish(beam, material, EFFECT_TIME)

func _tiles(coords: Array[Vector2i], color: Color) -> void:
	for coord in coords:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.55
		mesh.bottom_radius = 0.55
		mesh.height = 0.04
		mesh.radial_segments = 6
		disc.mesh = mesh
		var material := _unshaded(color, 0.5)
		disc.material_override = material
		add_child(disc)
		disc.position = grid.world_surface_for_coord(coord) + Vector3(0, 0.06, 0)
		_finish(disc, material, EFFECT_TIME + 0.3)

# ---------------------------------------------------------------------------
# Marcadores de TERRITÓRIO ecológico (sítio sem estrutura) — derivados, nunca salvos
# ---------------------------------------------------------------------------

## Mostra o marcador discreto de cada território ecológico que o humano já descobriu (âncora explorada); remove o
## de sítios esvaziados. Não bloqueia tile, não é atacável, não dá recompensa. Chamado no fog_updated e quando a
## ecologia repõe/esvazia sítios.
func refresh_site_markers() -> void:
	if not _active():
		return
	var human := GameManager.human_player
	var wanted := {}
	for site in MonsterEcologySystem.sites:
		if site.lair != HexGrid.NO_LAIR or human == null:
			continue
		var anchor: Vector2i = site.anchor
		if human.explored_tiles.has(anchor) or grid.visibility.get(anchor, HexGrid.Visibility.UNSEEN) != HexGrid.Visibility.UNSEEN:
			wanted[int(site.id)] = site
	for site_id in _site_markers.keys():
		if not wanted.has(site_id):
			var marker: Node3D = _site_markers[site_id]
			if is_instance_valid(marker):
				marker.queue_free()
			_site_markers.erase(site_id)
	for site_id in wanted:
		if not _site_markers.has(site_id):
			_site_markers[site_id] = _build_site_marker(wanted[site_id])

func site_marker_count() -> int:
	return _site_markers.size()

func _build_site_marker(site: Dictionary) -> Node3D:
	var kind := String(site.species)
	var tier := MonsterEcologyData.tier_of(kind)
	var color := Color(0.85, 0.75, 0.35) if tier == MonsterEcologyData.TIER_BASIC else (Color(0.9, 0.5, 0.2) if tier == MonsterEcologyData.TIER_INTERMEDIATE else Color(0.85, 0.25, 0.3))
	var marker := Node3D.new()
	marker.name = "Territory_%d" % int(site.id)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 0.7
	pole.mesh = pole_mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.25, 0.15)
	pole.material_override = wood
	pole.position = Vector3(0.38, 0.35, 0.3)
	marker.add_child(pole)
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.24, 0.16, 0.02)
	banner.mesh = banner_mesh
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	banner.material_override = cloth
	banner.position = Vector3(0.5, 0.6, 0.3)
	marker.add_child(banner)
	var label := Label3D.new()
	label.text = habitat_name(kind)
	label.font_size = 28
	label.outline_size = 8
	label.modulate = color.lightened(0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.4, 0.95, 0.3)
	marker.add_child(label)
	add_child(marker)
	marker.position = grid.world_surface_for_coord(site.anchor)
	return marker
