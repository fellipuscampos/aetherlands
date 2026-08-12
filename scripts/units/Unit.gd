class_name Unit
extends Node3D

const HP_BAR_WIDTH := 0.5
const HP_BAR_HEIGHT := 0.07
const HP_BAR_Y := 0.95
const MOVE_DURATION := 0.35

## Cor FALLBACK pro corpo/base de monstro neutro (owner_player == null, ver
## MonsterDatabase) sem entrada em MONSTER_KIND_COLORS — nao tem civ.color
## pra puxar, entao um vermelho sangue fixo serve tambem pra diferenciar
## visualmente "isso e hostil a todo mundo" de qualquer unidade de jogador.
const MONSTER_COLOR := Color(0.45, 0.08, 0.08)

## Cada tipo de monstro (MonsterDatabase.KIND_DATA) tem sua PROPRIA cor fixa
## de silhueta — pedido: "Goblins verde viva, Trolls cinza/rocha, Vivern/
## Dragao vermelho-laranja/roxo, Esqueleto branco/creme" — em vez de todos
## caindo no mesmo MONSTER_COLOR vermelho-sangue generico. Usado tanto no
## corpo (_build_procedural_body) quanto na base (_build_base_disc).
const MONSTER_KIND_COLORS := {
	"goblin": Color(0.25, 0.75, 0.2),
	"troll": Color(0.5, 0.5, 0.52),
	"wyvern": Color(0.85, 0.35, 0.05),
	"dragon": Color(0.55, 0.1, 0.55),
	"skeleton": Color(0.92, 0.9, 0.82),
}

## Veterania: unidade que vence combate (mata ou sobrevive matando quem a
## atacou) acumula kills e sobe de nivel em thresholds fixos, ganhando
## +10%/nivel em ataque E defesa (CombatResolver.predict() aplica) e uma
## cura parcial na hora da promocao — da um motivo real pra manter
## unidades veteranas vivas em vez de sempre produzir novas.
const VETERANCY_TITLES := ["Recruta", "Veterano", "Elite", "Lendario"]
const VETERANCY_KILL_THRESHOLDS := [0, 1, 3, 6] # kills minimos pra cada indice/nivel
const VETERANCY_BONUS_PER_LEVEL := 0.1
const PROMOTION_HEAL_FRACTION := 0.2

var unit_data: UnitData
var owner_player: PlayerData
var coord: Vector2i
var movement_left: float = 0.0
var kills: int = 0
var veterancy_level: int = 0

## true so pro ocupante ORIGINAL de um Covil de Monstro (ver HexGrid.
## spawn_monster_at/_spawn_monster_lairs) — do lado de MonsterDatabase.
## create_monster, controla HP/ataque reforcados e movement_points travado
## em 0. O marcador visual do covil em si (tenda/caverna/etc) NAO depende
## mais disso — ver LairStructure, uma entidade de terreno separada que
## sobrevive mesmo depois do camp boss morrer/ser afastado.
var is_camp_boss: bool = false

## "" = usa o comportamento PADRAO do tipo (MonsterDatabase.KIND_DATA[kind].
## behavior); "guardian"/"invader"/"hunter" (ver MonsterDatabase.BEHAVIOR_*)
## sobrescreve por INSTANCIA — usado pela MonsterAI pra promover um grupo
## ocioso de Goblins Guardioes a Invasores (ver MonsterAI, HexGrid.
## KIND_DATA["goblin"].invader_promotable). So se aplica a monstro neutro
## (owner_player == null); unidade de jogador/rival ignora este campo.
var monster_behavior_state: String = ""

## Setter dispara a atualizacao visual da barra de vida sozinha — assim
## qualquer lugar que faca `unit.hp -= dano` (CombatResolver, etc.) ja
## reflete na barra sem precisar lembrar de chamar nada extra.
var hp: float = 10.0:
	set(value):
		hp = value
		_update_hp_bar()

var _hp_bar_fg: MeshInstance3D
var _hp_bar_bg: MeshInstance3D

func setup(data: UnitData, player: PlayerData, start_coord: Vector2i, camp_boss: bool = false) -> void:
	unit_data = data
	owner_player = player
	coord = start_coord
	is_camp_boss = camp_boss
	hp = data.max_hp
	movement_left = data.movement_points
	_build_visual()

func reset_movement() -> void:
	movement_left = unit_data.movement_points

## Chamado por CombatResolver quando esta unidade vence um combate (mata o
## alvo, ou sobrevive ao contra-ataque de quem morreu tentando mata-la).
## Cura uma fracao do HP maximo so quando sobe de nivel de verdade — nao
## em todo kill, senao viraria um jeito facil demais de curar sem recuar.
func register_kill() -> void:
	kills += 1
	var new_level = _level_for_kills(kills)
	if new_level > veterancy_level:
		veterancy_level = new_level
		hp = min(hp + unit_data.max_hp * PROMOTION_HEAL_FRACTION, unit_data.max_hp)

static func _level_for_kills(k: int) -> int:
	var level := 0
	for i in range(VETERANCY_KILL_THRESHOLDS.size()):
		if k >= VETERANCY_KILL_THRESHOLDS[i]:
			level = i
	return level

func veterancy_title() -> String:
	return VETERANCY_TITLES[veterancy_level]

## Multiplica ataque E defesa igualmente (CombatResolver.predict()) — uma
## unidade veterana e melhor nos dois papeis, nao so atacando.
func veterancy_multiplier() -> float:
	return 1.0 + veterancy_level * VETERANCY_BONUS_PER_LEVEL

## Anima a posicao ate `target_pos` (em vez de teletransportar) e vira a
## unidade de frente pra direcao do movimento. Puramente visual — quem
## chama isso (HexGrid.move_unit) ja atualizou coord/ocupacao na hora.
func slide_to(target_pos: Vector3) -> void:
	var direction = target_pos - position
	direction.y = 0.0

	# create_tween() exige a unidade estar dentro da SceneTree (ex: testes
	# GUT que criam Unit/HexGrid isolados, sem add_child). Sem isso o jogo
	# de verdade nunca chama slide_to fora da arvore, mas nao custa nada
	# nao quebrar se acontecer — so pula a animacao e teletransporta.
	if not is_inside_tree():
		position = target_pos
		if direction.length() > 0.05:
			rotation.y = atan2(direction.x, direction.z)
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE)
	if direction.length() > 0.05:
		var target_angle = atan2(direction.x, direction.z)
		tween.tween_property(self, "rotation:y", target_angle, MOVE_DURATION * 0.6)

func _build_visual() -> void:
	_build_procedural_body()
	_build_base_disc()
	_build_hp_bar()

## Cor do corpo/base de uma unidade: cor da civilizacao pro jogador, ou —
## pra monstro neutro (owner_player == null) — a cor FIXA do proprio tipo
## (MONSTER_KIND_COLORS), caindo no vermelho-sangue generico (MONSTER_
## COLOR) so se o visual_kind nao tiver entrada la (unidade neutra futura
## sem cor propria ainda definida).
func _body_color() -> Color:
	if owner_player:
		return owner_player.civ.color
	return MONSTER_KIND_COLORS.get(unit_data.visual_kind, MONSTER_COLOR)

## Formas proceduras simples, cada uma com silhueta diferente pra dar pra
## reconhecer o tipo de unidade a distancia mesmo sem textura/detalhe.
func _build_procedural_body() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _body_color()

	match unit_data.visual_kind:
		"settler":
			var body := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.3
			mesh.height = 0.6
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.35
			add_child(body)
		"archer":
			var body := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.04
			mesh.bottom_radius = 0.17
			mesh.height = 0.8
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.42
			add_child(body)
		"cavalry":
			var horse := MeshInstance3D.new()
			var horse_mesh := BoxMesh.new()
			horse_mesh.size = Vector3(0.55, 0.32, 0.28)
			horse.mesh = horse_mesh
			horse.material_override = mat
			horse.position.y = 0.28
			add_child(horse)

			var rider := MeshInstance3D.new()
			var rider_mesh := CapsuleMesh.new()
			rider_mesh.radius = 0.12
			rider_mesh.height = 0.4
			rider.mesh = rider_mesh
			var rider_mat := StandardMaterial3D.new()
			rider_mat.albedo_color = owner_player.civ.color.darkened(0.25)
			rider.material_override = rider_mat
			rider.position = Vector3(0.05, 0.55, 0.0)
			add_child(rider)
		"catapult":
			var frame := MeshInstance3D.new()
			var frame_mesh := BoxMesh.new()
			frame_mesh.size = Vector3(0.6, 0.25, 0.4)
			frame.mesh = frame_mesh
			frame.material_override = mat
			frame.position.y = 0.2
			add_child(frame)

			var arm := MeshInstance3D.new()
			var arm_mesh := BoxMesh.new()
			arm_mesh.size = Vector3(0.08, 0.5, 0.08)
			arm.mesh = arm_mesh
			var arm_mat := StandardMaterial3D.new()
			arm_mat.albedo_color = owner_player.civ.color.darkened(0.3)
			arm.material_override = arm_mat
			arm.position = Vector3(-0.1, 0.5, 0.0)
			arm.rotation_degrees = Vector3(0, 0, -25)
			add_child(arm)
		"mage":
			var robe := MeshInstance3D.new()
			var robe_mesh := PrismMesh.new()
			robe_mesh.size = Vector3(0.4, 0.75, 0.4)
			robe.mesh = robe_mesh
			robe.material_override = mat
			robe.position.y = 0.38
			add_child(robe)

			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.14
			head_mesh.height = 0.28
			head.mesh = head_mesh
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.85, 0.75, 0.6) # "pele" clara generica
			head.material_override = head_mat
			head.position.y = 0.85
			add_child(head)
		"goblin":
			# Esfera pequena verde — pedido do usuario: silhueta minima,
			# rasteira, facil de ler como "fraco" a distancia.
			var body := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.44
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.22
			add_child(body)
		"troll":
			# Cubo grande e largo cinza-rocha — pedido do usuario: silhueta
			# "atarracada"/pesada, oposto do resto do bestiario.
			var body := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.6, 0.85, 0.5)
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.42
			add_child(body)
		"skeleton":
			# Silhueta bem fina (mais magra que qualquer outro humanoide do
			# bestiario) branca/creme — pedido do usuario.
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.11
			mesh.height = 0.8
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.4
			add_child(body)
		"wyvern":
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.22
			mesh.height = 0.9
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.5
			add_child(body)
			# Duas "asas" (prismas achatados) inclinadas pra cima — silhueta
			# minima que ja basta pra ler "isso voa", sem precisar de rig.
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.5, 0.05, 0.28)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.32, 0.68, 0.0)
				wing.rotation_degrees = Vector3(0, 0, side * 35)
				add_child(wing)
		"dragon":
			# Mesmo padrao do Vivern (corpo alongado + asas), so numa escala
			# bem maior — pedido do usuario: "Dragao (Boss Raro)... atributos
			# massivos", a silhueta precisa ler "muito maior" a distancia,
			# nao so "outro voador vermelho".
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.4
			mesh.height = 1.6
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.85
			add_child(body)
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.95, 0.08, 0.5)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.55, 1.15, 0.0)
				wing.rotation_degrees = Vector3(0, 0, side * 35)
				add_child(wing)
			var tail := MeshInstance3D.new()
			var tail_mesh := PrismMesh.new()
			tail_mesh.size = Vector3(0.2, 0.2, 0.8)
			tail.mesh = tail_mesh
			tail.material_override = mat
			tail.position = Vector3(0, 0.6, -0.55)
			tail.rotation_degrees = Vector3(90, 0, 0)
			add_child(tail)
		"griffin":
			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.2
			body_mesh.height = 0.65
			body.mesh = body_mesh
			body.material_override = mat
			body.position = Vector3(0, 0.42, 0)
			body.rotation_degrees = Vector3(90, 0, 0) # deitado, tipo corpo de leao/aguia
			add_child(body)

			var head := MeshInstance3D.new()
			var head_mesh := PrismMesh.new()
			head_mesh.size = Vector3(0.16, 0.2, 0.16)
			head.mesh = head_mesh
			head.material_override = mat
			head.position = Vector3(0, 0.5, 0.3)
			head.rotation_degrees = Vector3(90, 0, 0)
			add_child(head)

			# Asas bem maiores que as do vivern — grifo e uma montaria nobre,
			# nao um monstro rasteiro, a silhueta precisa deixar isso claro.
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wing_mesh := PrismMesh.new()
				wing_mesh.size = Vector3(0.75, 0.06, 0.4)
				wing.mesh = wing_mesh
				wing.material_override = mat
				wing.position = Vector3(side * 0.4, 0.55, -0.05)
				wing.rotation_degrees = Vector3(0, 0, side * 40)
				add_child(wing)
		"treant":
			# Tronco na cor da civilizacao (mesmo padrao de "corpo principal"
			# de todo outro kind), folhagem sempre verde fixo — nao faz
			# sentido uma arvore ter folhas na cor do dono, so o "estandarte"
			# (aqui, o proprio tronco) precisa identificar de quem e.
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.12
			trunk_mesh.bottom_radius = 0.19
			trunk_mesh.height = 0.55
			trunk.mesh = trunk_mesh
			trunk.material_override = mat
			trunk.position.y = 0.28
			add_child(trunk)

			var foliage := MeshInstance3D.new()
			var foliage_mesh := SphereMesh.new()
			foliage_mesh.radius = 0.34
			foliage_mesh.height = 0.68
			foliage.mesh = foliage_mesh
			var foliage_mat := StandardMaterial3D.new()
			foliage_mat.albedo_color = Color(0.18, 0.42, 0.2)
			foliage.material_override = foliage_mat
			foliage.position.y = 0.75
			add_child(foliage)
		"dwarf_axeguard":
			# Baixo e largo (silhueta "atarracada" reconhecivel de longe,
			# oposto do humanoide alto e magro do padrao) + cabeca de
			# machado numa haste, cor do metal fixa independente do dono.
			var torso := MeshInstance3D.new()
			var torso_mesh := BoxMesh.new()
			torso_mesh.size = Vector3(0.34, 0.4, 0.24)
			torso.mesh = torso_mesh
			torso.material_override = mat
			torso.position.y = 0.24
			add_child(torso)

			var axe_handle := MeshInstance3D.new()
			var handle_mesh := CylinderMesh.new()
			handle_mesh.top_radius = 0.025
			handle_mesh.bottom_radius = 0.025
			handle_mesh.height = 0.55
			axe_handle.mesh = handle_mesh
			var handle_mat := StandardMaterial3D.new()
			handle_mat.albedo_color = Color(0.4, 0.28, 0.18)
			axe_handle.material_override = handle_mat
			axe_handle.position = Vector3(0.22, 0.45, 0.0)
			add_child(axe_handle)

			var axe_head := MeshInstance3D.new()
			var head_mesh := PrismMesh.new()
			head_mesh.size = Vector3(0.16, 0.18, 0.04)
			axe_head.mesh = head_mesh
			var head_mat := StandardMaterial3D.new()
			head_mat.albedo_color = Color(0.65, 0.66, 0.68)
			axe_head.material_override = head_mat
			axe_head.position = Vector3(0.22, 0.68, 0.0)
			add_child(axe_head)
		"orc_berserker":
			# Corpo maior e mais bruto que o padrao (torso avantajado,
			# corcunda) — silhueta que le "forca bruta" antes mesmo de
			# reconhecer qualquer arma.
			var body := MeshInstance3D.new()
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = 0.24
			body_mesh.height = 0.75
			body.mesh = body_mesh
			body.material_override = mat
			body.position = Vector3(0, 0.42, 0.03)
			body.rotation_degrees = Vector3(8, 0, 0) # levemente curvado pra frente
			add_child(body)

			var club := MeshInstance3D.new()
			var club_mesh := BoxMesh.new()
			club_mesh.size = Vector3(0.09, 0.5, 0.09)
			club.mesh = club_mesh
			var club_mat := StandardMaterial3D.new()
			club_mat.albedo_color = Color(0.32, 0.24, 0.16)
			club.material_override = club_mat
			club.position = Vector3(0.26, 0.5, 0.0)
			club.rotation_degrees = Vector3(0, 0, -18)
			add_child(club)
		"elf_ranger":
			# Silhueta alta e esguia (mais fina que o Arqueiro comum) + um
			# arco fino nas costas — leitura de "movel e a distancia", nao
			# "forte e corpo-a-corpo" como os outros dois novos.
			var body := MeshInstance3D.new()
			var body_mesh := CylinderMesh.new()
			body_mesh.top_radius = 0.03
			body_mesh.bottom_radius = 0.13
			body_mesh.height = 0.85
			body.mesh = body_mesh
			body.material_override = mat
			body.position.y = 0.45
			add_child(body)

			var bow := MeshInstance3D.new()
			var bow_mesh := CylinderMesh.new()
			bow_mesh.top_radius = 0.015
			bow_mesh.bottom_radius = 0.015
			bow_mesh.height = 0.5
			bow.mesh = bow_mesh
			var bow_mat := StandardMaterial3D.new()
			bow_mat.albedo_color = Color(0.42, 0.3, 0.2)
			bow.material_override = bow_mat
			bow.position = Vector3(-0.14, 0.5, -0.05)
			bow.rotation_degrees = Vector3(0, 0, 12)
			add_child(bow)
		_: # "warrior" e qualquer kind desconhecido caem no padrao
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.2
			mesh.height = 0.7
			body.mesh = mesh
			body.material_override = mat
			body.position.y = 0.4
			add_child(body)

## Disco colorido embaixo dos pes — indica de quem e a unidade sem precisar
## tingir o modelo real inteiro (o que destruiria a textura pintada dele,
## mesma logica usada na bandeira das cidades vs a pedra da torre).
func _build_base_disc() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.35
	base_mesh.bottom_radius = 0.35
	base_mesh.height = 0.06
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = _body_color().darkened(0.3)
	base.material_override = base_mat
	base.position.y = 0.03
	add_child(base)

## Barra de vida sempre visivel (nao so quando selecionada) — pra dar pra
## ver a vida das suas unidades E das inimigas so olhando o mapa, sem
## precisar clicar em cada uma. Fundo escuro fixo + barra colorida que
## encolhe da direita pra esquerda conforme o HP cai.
func _build_hp_bar() -> void:
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg = MeshInstance3D.new()
	_hp_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 1
	_hp_bar_bg.material_override = bg_mat
	_hp_bar_bg.position = Vector3(0, HP_BAR_Y, 0)
	add_child(_hp_bar_bg)

	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fg = MeshInstance3D.new()
	_hp_bar_fg.mesh = fg_mesh
	var fg_mat := StandardMaterial3D.new()
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.no_depth_test = true
	fg_mat.render_priority = 2
	_hp_bar_fg.material_override = fg_mat
	_hp_bar_fg.position = Vector3(0, HP_BAR_Y, 0.001)
	add_child(_hp_bar_fg)

	_update_hp_bar()

func _update_hp_bar() -> void:
	# Chamado pelo setter de hp mesmo antes de _build_visual() rodar
	# (setup() seta hp = data.max_hp antes de construir a barra) — nesse
	# momento a barra ainda nao existe, entao so ignora.
	if _hp_bar_fg == null or unit_data == null:
		return
	var frac = clamp(hp / unit_data.max_hp, 0.0, 1.0)
	var mesh := _hp_bar_fg.mesh as QuadMesh
	mesh.size = Vector2(HP_BAR_WIDTH * frac, HP_BAR_HEIGHT)
	_hp_bar_fg.position.x = -(HP_BAR_WIDTH - HP_BAR_WIDTH * frac) * 0.5

	var mat := _hp_bar_fg.material_override as StandardMaterial3D
	if frac > 0.6:
		mat.albedo_color = Color(0.25, 0.85, 0.25)
	elif frac > 0.3:
		mat.albedo_color = Color(0.9, 0.75, 0.15)
	else:
		mat.albedo_color = Color(0.85, 0.2, 0.2)

	_hp_bar_bg.visible = frac < 1.0
	_hp_bar_fg.visible = frac < 1.0
