extends GutTest

## O DRAGÃO MODELADO (2026-10-13) — pedido do usuário: "pegue o dragão modelado novo, ele tem 6 animações, 2 idle, 2
## walk e 2 attack, pra quando tá no ar e pra quando tá na terra, substitua o dragão do evento atual por ele".
## O dragão vermelho escuro (assets/generated/dragons/dark_red_dragon_v5_animated) no lugar do corpo procedural de
## caixas: posturas "flying"/"ground" (Unit.set_posture, guiadas pelo modo de viagem do DragonEvent), sopro de fogo
## preso ao osso da boca (Unit.play_fire_breath) e tombo de morte (Unit.play_death_topple). Só arte: as regras do
## evento (test_dragon_event.gd) não mudaram.

const FLYING := MonsterDatabase.DRAGON_POSTURE_FLYING
const GROUND := MonsterDatabase.DRAGON_POSTURE_GROUND
const FRAME := 1.0 / 60.0
## Quanto um osso pode andar/girar num quadro logo depois de uma troca (ver test_grand_manifestations_in_game.gd).
const MAX_STEP_POSITION := 0.03
const MAX_STEP_DEGREES := 3.0

var grid: HexGrid
var _players: Array[PlayerData] = []
var _original_turn: int

func before_each():
	_original_turn = TurnManager.turn_number
	DragonEvent.min_target_cities = 1
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-12, 13):
		for r in range(-4, 5):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

func after_each():
	DragonEvent.min_target_cities = DragonEvent.MIN_TARGET_CITIES
	TurnManager.turn_number = _original_turn
	for player in _players:
		player.release_relations()
	_players.clear()

func _player() -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = "Aurora"
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _dragon(coord: Vector2i = Vector2i.ZERO) -> Unit:
	return grid.spawn_monster_at(coord, "dragon")

func _skeleton(unit: Unit) -> Skeleton3D:
	return unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func _pose(skeleton: Skeleton3D) -> Array:
	var pose := []
	for bone in skeleton.get_bone_count():
		pose.append([skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone)])
	return pose

func _largest_step(before: Array, after: Array) -> Dictionary:
	var step := {"position": 0.0, "degrees": 0.0}
	for bone in before.size():
		step.position = maxf(step.position, (before[bone][0] as Vector3).distance_to(after[bone][0]))
		step.degrees = maxf(step.degrees, rad_to_deg((before[bone][1] as Quaternion).angle_to(after[bone][1])))
	return step

func _assert_no_pop(unit: Unit, label: String, trigger: Callable) -> void:
	var skeleton := _skeleton(unit)
	var before := _pose(skeleton)
	trigger.call()
	unit._anim_player.advance(FRAME)
	var step := _largest_step(before, _pose(skeleton))
	assert_lt(step.position, MAX_STEP_POSITION, "%s: nenhum osso salta de lugar (%.4f m)" % [label, step.position])
	assert_lt(step.degrees, MAX_STEP_DEGREES, "%s: nenhum osso salta de ângulo (%.2f°)" % [label, step.degrees])

func _active_event(city_coord: Vector2i) -> Array:
	var player := _player()
	grid.found_city(city_coord, player, "Alvo", true)
	var players: Array[PlayerData] = [player]
	var event := DragonEvent.new()
	event.origin_region = Vector2i.ZERO
	TurnManager.turn_number = 10
	event.advance_turn(grid, players) # -> Announced
	event.advance_turn(grid, players) # -> Preparation
	TurnManager.turn_number = event.turn_deadline + 1
	event.advance_turn(grid, players) # -> Active: o Dragão nasce
	return [event, players]

# --- O modelo ---------------------------------------------------------------------------------------------------------

func test_the_dragon_is_the_modelled_one_at_native_scale():
	var data := MonsterDatabase.create_monster("dragon")
	assert_eq(data.model_scene_path, MonsterDatabase.DRAGON_MODEL)
	assert_true(ResourceLoader.exists(MonsterDatabase.DRAGON_MODEL), "GLB importado")
	assert_eq(data.model_scale_multiplier, 1.0, "3 m na escala nativa — nunca normalizar pela caixa (asas abertas)")
	assert_eq(data.model_yaw_offset_degrees, 0.0, "frente em +Z")
	var unit := _dragon()
	assert_not_null(unit._anim_player)
	assert_null(unit.find_child("DragonVisualRoot", true, false), "o corpo procedural de caixas saiu")
	var body: MeshInstance3D = null
	for mesh in unit.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			body = mesh
	assert_not_null(body, "malha com esqueleto")
	assert_almost_eq(body.mesh.get_aabb().size.y, 3.0, 0.01, "3 m de altura em repouso")
	assert_eq((unit._anim_player.get_parent() as Node3D).scale, Vector3.ONE)
	var playing := 0
	for player in unit.find_children("*", "AnimationPlayer", true, false):
		if player.is_playing():
			playing += 1
	assert_eq(playing, 1, "só a Unit comanda o esqueleto")
	assert_false(unit.has_method("_build_dragon_body"), "o código do dragão procedural foi removido")

func test_art_did_not_touch_the_dragon_rules():
	var data := MonsterDatabase.create_monster("dragon")
	assert_eq([data.attack, data.defense, data.max_hp, data.movement_points, data.vision_range], [24.0, 12.0, 50.0, 2.0, 2]) # ATQ/DEF ×1,5 do balanceamento 14/10
	assert_true(data.flies)
	assert_eq(data.unit_name, "Dragao")

func test_six_clips_two_postures_same_bones():
	var unit := _dragon()
	var player := unit._anim_player
	assert_eq(player.get_animation_list().size(), 6)
	assert_eq(MonsterDatabase.DRAGON_POSTURES.size(), 2)
	var reference := {}
	var seen := {}
	for posture in [FLYING, GROUND]:
		var clips: Dictionary = MonsterDatabase.DRAGON_POSTURES[posture]
		for role in ["idle", "walk", "attack"]:
			var clip := String(clips[role])
			seen[clip] = true
			assert_true(player.has_animation(clip), clip)
			var animation := player.get_animation(clip)
			assert_eq(animation.loop_mode, Animation.LOOP_NONE if role == "attack" else Animation.LOOP_LINEAR, "%s: ciclo certo" % clip)
			var paths := {}
			for track in animation.get_track_count():
				paths[String(animation.track_get_path(track))] = true
			if reference.is_empty():
				reference = paths
			assert_eq(paths.size(), reference.size(), "%s anima os mesmos canais (mistura sem puxão)" % clip)
		assert_eq(player.get_animation(String(clips.attack)).length, 3.0, "%s: ataque de 3 s" % posture)
	assert_eq(seen.size(), 6, "seis clipes distintos: parado, andar e atacar para cada postura")

func test_markers_float_above_the_flying_wings():
	var unit := _dragon()
	assert_gte(unit._marker_height, MonsterDatabase.DRAGON_MARKER_HEIGHT, "barra de vida acima das asas no voo (3,86 m)")
	assert_gt(unit.markers_top_height(), 3.9)

# --- Posturas -----------------------------------------------------------------------------------------------------------

func test_the_dragon_is_born_flying():
	var unit := _dragon()
	assert_eq(unit.posture, FLYING)
	assert_eq(String(unit._anim_player.current_animation), "Dragon_Idle_Flying")
	assert_eq([unit.idle_animation, unit.moving_animation, unit.attack_animation], ["Dragon_Idle_Flying", "Dragon_Walk_Flying", "Dragon_Attack_Flying"])

func test_set_posture_swaps_the_three_clips_and_the_one_playing():
	var unit := _dragon()
	var player := unit._anim_player
	assert_true(unit.set_posture(GROUND))
	assert_eq(unit.posture, GROUND)
	assert_eq([unit.idle_animation, unit.moving_animation, unit.attack_animation], ["Dragon_Idle_Ground", "Dragon_Walk_Ground", "Dragon_Attack_Ground"])
	assert_eq(String(player.current_animation), "Dragon_Idle_Ground", "parado no ar -> parado em terra")

	unit.slide_to(Vector3(2, 0, 0))
	assert_eq(String(player.current_animation), "Dragon_Walk_Ground", "anda com a marcha de terra")
	assert_true(unit.set_posture(FLYING))
	assert_eq(String(player.current_animation), "Dragon_Walk_Flying", "andando em terra -> voando: decola sem parar")
	unit.place_at(Vector3(2, 0, 0))
	assert_eq(String(player.current_animation), "Dragon_Idle_Flying", "chega e paira")

	assert_false(unit.set_posture("nadando"), "postura que o modelo não tem")
	assert_eq(unit.posture, FLYING, "nada muda")
	assert_true(unit.set_posture(FLYING), "pedir a postura atual não faz nada")
	assert_eq(String(player.current_animation), "Dragon_Idle_Flying")

func test_an_attack_in_progress_finishes_and_lands_in_the_new_posture():
	var unit := _dragon()
	var player := unit._anim_player
	unit._play_animation(unit.attack_animation)
	assert_eq(String(player.current_animation), "Dragon_Attack_Flying")
	unit.set_posture(GROUND)
	assert_eq(String(player.current_animation), "Dragon_Attack_Flying", "o golpe em curso termina como começou")
	player.advance(3.1)
	assert_eq(String(player.current_animation), "Dragon_Idle_Ground", "e volta ao parado da postura nova")

func test_units_without_postures_ignore_set_posture():
	var goblin := grid.spawn_monster_at(Vector2i(2, 0), "goblin")
	var idle := goblin.idle_animation
	assert_false(goblin.set_posture(GROUND))
	assert_eq(goblin.posture, "")
	assert_eq(goblin.idle_animation, idle)

func test_landing_takeoff_and_every_state_change_are_smooth():
	var unit := _dragon()
	var player := unit._anim_player
	assert_true(player.get_meta(Unit.POSE_TRANSITION_META, null) is PoseCaptureTransition, "transição por captura de pose")
	assert_gt(MonsterDatabase.DRAGON_POSTURE_TRANSITION_TIME, MonsterDatabase.DRAGON_TRANSITION_TIME, "pouso/decolagem levam mais tempo")
	player.advance(0.83)
	_assert_no_pop(unit, "pairando -> pouso", func() -> void: unit.set_posture(GROUND))
	player.advance(0.4) # no meio do pouso
	_assert_no_pop(unit, "pouso interrompido -> andar em terra", func() -> void: unit.slide_to(Vector3(2, 0, 0)))
	player.advance(0.7)
	_assert_no_pop(unit, "andando em terra -> decolar", func() -> void: unit.set_posture(FLYING))
	player.advance(1.4)
	_assert_no_pop(unit, "voando -> parar no ar", func() -> void: unit.place_at(Vector3(2, 0, 0)))
	player.advance(1.1)
	_assert_no_pop(unit, "pairando -> atacar no ar", func() -> void: unit._play_animation(unit.attack_animation))
	player.advance(1.3) # boca aberta, no meio da rajada
	_assert_no_pop(unit, "ataque no ar interrompido -> voar", func() -> void: unit.slide_to(Vector3(4, 0, 0)))
	unit.place_at(Vector3(4, 0, 0))
	unit.set_posture(GROUND)
	player.advance(2.0)
	_assert_no_pop(unit, "parado em terra -> atacar em terra", func() -> void: unit._play_animation(unit.attack_animation))

func test_the_two_postures_really_differ_in_height():
	# O voo paira: o corpo fica bem acima do chão; em terra as patas apoiam.
	var unit := _dragon()
	var skeleton := _skeleton(unit)
	var chest := skeleton.find_bone("chest")
	unit._anim_player.advance(2.0)
	var flying_height := skeleton.get_bone_global_pose(chest).origin.y
	unit.set_posture(GROUND)
	unit._anim_player.advance(3.0)
	var ground_height := skeleton.get_bone_global_pose(chest).origin.y
	assert_gt(flying_height, ground_height + 0.5, "no ar o peito fica mais alto (%.2f vs %.2f)" % [flying_height, ground_height])

# --- O evento escolhe a postura -------------------------------------------------------------------------------------------

func test_travel_mode_maps_to_posture_by_distance():
	assert_eq(DragonEvent.TRAVEL_MODE_FLYING, FLYING, "o modo de viagem É o nome da postura")
	assert_eq(DragonEvent.TRAVEL_MODE_GROUND, GROUND)
	assert_eq(DragonEvent.travel_mode_for_distance(DragonEvent.DRAGON_GROUND_ENGAGE_RANGE), GROUND)
	assert_eq(DragonEvent.travel_mode_for_distance(DragonEvent.DRAGON_GROUND_ENGAGE_RANGE + 1), FLYING)
	assert_eq(DragonEvent.travel_mode_for_distance(0.0), GROUND)

func test_the_event_dragon_flies_far_and_lands_near_the_target():
	var target_distance := DragonEvent.DRAGON_FLYING_TILES_PER_TURN + 1
	var setup := _active_event(Vector2i(target_distance, 0))
	var event: DragonEvent = setup[0]
	var players: Array[PlayerData] = setup[1]
	var dragon := event.dragon_unit
	assert_eq(dragon.posture, FLYING, "nasce voando")

	event.advance_turn(grid, players) # longe: um salto de voo
	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_FLYING)
	assert_eq(dragon.posture, FLYING)
	assert_string_contains(String(dragon._anim_player.current_animation), "Flying")

	event.advance_turn(grid, players) # agora perto: pousa
	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_GROUND)
	assert_eq(dragon.posture, GROUND)
	assert_string_contains(String(dragon._anim_player.current_animation), "Ground")

func test_a_loaded_dragon_next_to_its_target_is_already_on_the_ground():
	var setup := _active_event(Vector2i(2, 0))
	var event: DragonEvent = setup[0]
	var players: Array[PlayerData] = setup[1]
	event.advance_turn(grid, players)
	assert_eq(event.dragon_unit.posture, GROUND)
	# Save/load: a Unit é reconstruída (nasce voando) e o evento a reencontra.
	var saved := event.to_save_dict()
	var coord := event.dragon_unit.coord
	grid.remove_unit(event.dragon_unit)
	await wait_frames(1)
	var rebuilt := grid.spawn_monster_at(coord, "dragon")
	assert_eq(rebuilt.posture, FLYING, "a unidade reconstruída nasce na postura padrão")
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	loaded.relink_unit(grid)
	assert_same(loaded.dragon_unit, rebuilt)
	if loaded.current_target_city_coord != DragonEvent.NO_COORD:
		assert_eq(rebuilt.posture, GROUND, "perto da cidade-alvo: já aparece pousado, sem esperar o próximo turno")
	else:
		pass_test("sem alvo corrente no save: a postura é decidida no próximo turno")

# --- Sopro de fogo --------------------------------------------------------------------------------------------------------

func test_the_fire_breath_lives_on_the_mouth_bone_and_starts_off():
	var unit := _dragon()
	assert_true(unit.has_fire_breath())
	var emitter := unit.find_child(Unit.FIRE_BREATH_EMITTER, true, false) as GPUParticles3D
	var light := unit.find_child(Unit.FIRE_BREATH_LIGHT, true, false) as OmniLight3D
	assert_not_null(emitter)
	assert_not_null(light)
	var anchor := emitter.get_parent() as BoneAttachment3D
	assert_not_null(anchor, "preso a um osso: segue a cabeça em qualquer clipe")
	assert_eq(anchor.bone_name, MonsterDatabase.DRAGON_FIRE_BONE)
	assert_same(light.get_parent(), anchor)
	assert_false(emitter.emitting, "desligado até o ataque")
	assert_false(emitter.one_shot, "rajada sustentada, não um estouro")
	assert_false(emitter.local_coords, "o fogo solto não gira com a cabeça")
	assert_eq(light.light_energy, 0.0)
	assert_false(light.visible)
	assert_false(light.shadow_enabled)
	assert_eq((emitter.process_material as ParticleProcessMaterial).direction, Vector3(0, 1, 0), "+Y do osso aponta para a frente")
	# O osso da boca fica à frente e aponta para a frente (+Z do modelo).
	var skeleton := _skeleton(unit)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(MonsterDatabase.DRAGON_FIRE_BONE))
	assert_gt(rest.origin.z, 1.0)
	assert_gt(rest.basis.y.z, 0.9)

func test_the_fire_window_matches_the_model_markers():
	var data := MonsterDatabase.create_monster("dragon")
	assert_eq([data.fire_breath_bone, data.fire_breath_start, data.fire_breath_end], ["mouth_fire", 0.75, 2.0])
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dragons/dark_red_dragon_v5_animated/godot_animation_validation.json"))
	assert_eq(float(report.fire_start_seconds), data.fire_breath_start, "FIRE_START do modelo")
	assert_eq(float(report.fire_end_seconds), data.fire_breath_end, "FIRE_END do modelo")
	assert_eq(String(report.mouth_socket), data.fire_breath_bone)
	assert_lt(data.fire_breath_end, 3.0, "a rajada termina antes do clipe de ataque")

func test_the_breath_opens_and_closes_on_the_attack_window():
	var unit := _dragon()
	var emitter := unit.find_child(Unit.FIRE_BREATH_EMITTER, true, false) as GPUParticles3D
	var light := unit.find_child(Unit.FIRE_BREATH_LIGHT, true, false) as OmniLight3D
	unit.play_fire_breath()
	assert_false(emitter.emitting, "antes da janela a boca ainda está fechada")
	var tween := unit._fire_breath_tween
	assert_true(tween != null and tween.is_valid())
	tween.custom_step(0.74)
	assert_false(unit.is_breathing_fire())
	tween.custom_step(0.03) # 0,77 s
	assert_true(unit.is_breathing_fire(), "abre aos 0,75 s")
	assert_true(light.visible)
	tween.custom_step(0.6) # 1,37 s
	assert_true(unit.is_breathing_fire())
	assert_almost_eq(light.light_energy, Unit.FIRE_BREATH_LIGHT_ENERGY, 0.01, "luz cheia durante a rajada")
	tween.custom_step(0.66) # 2,03 s
	assert_false(unit.is_breathing_fire(), "fecha aos 2,0 s")
	tween.custom_step(1.0)
	assert_eq(light.light_energy, 0.0)
	assert_false(light.visible, "a luz apaga depois")

func test_a_new_breath_or_death_cancels_the_running_one():
	var unit := _dragon()
	unit.play_fire_breath()
	unit._fire_breath_tween.custom_step(1.0)
	assert_true(unit.is_breathing_fire())
	unit.play_fire_breath()
	assert_false(unit.is_breathing_fire(), "a rajada nova recomeça fechada")
	unit._fire_breath_tween.custom_step(1.0)
	assert_true(unit.is_breathing_fire())
	unit.play_death_topple(1.2)
	assert_false(unit.is_breathing_fire(), "morto não cospe fogo")
	assert_eq((unit.find_child(Unit.FIRE_BREATH_LIGHT, true, false) as OmniLight3D).light_energy, 0.0)

func test_units_without_a_fire_bone_have_no_breath():
	var goblin := grid.spawn_monster_at(Vector2i(2, 0), "goblin")
	assert_false(goblin.has_fire_breath())
	assert_null(goblin.find_child(Unit.FIRE_BREATH_EMITTER, true, false))
	goblin.play_fire_breath() # não quebra
	assert_false(goblin.is_breathing_fire())

func test_the_event_attack_plays_the_posture_attack_with_fire():
	var setup := _active_event(Vector2i(2, 0))
	var event: DragonEvent = setup[0]
	var dragon := event.dragon_unit
	dragon.set_posture(GROUND)
	event._play_dragon_attack_effects()
	assert_eq(String(dragon._anim_player.current_animation), "Dragon_Attack_Ground")
	assert_true(dragon._fire_breath_tween != null and dragon._fire_breath_tween.is_valid(), "a rajada foi agendada junto com o golpe")
	dragon._anim_player.advance(3.1)
	assert_eq(String(dragon._anim_player.current_animation), "Dragon_Idle_Ground", "o golpe termina e volta ao parado")

	dragon.set_posture(FLYING)
	event._play_dragon_attack_effects()
	assert_eq(String(dragon._anim_player.current_animation), "Dragon_Attack_Flying", "no ar, o ataque de voo")

# --- Morte ------------------------------------------------------------------------------------------------------------------

func test_the_slain_dragon_topples_and_sinks():
	var setup := _active_event(Vector2i(2, 0))
	var event: DragonEvent = setup[0]
	var dragon := event.dragon_unit
	var height := dragon.position.y
	event._play_dragon_death_effects()
	await wait_seconds(DragonEvent.DRAGON_DEATH_SECONDS + 0.3)
	assert_almost_eq(dragon.rotation.z, deg_to_rad(Unit.DEATH_TOPPLE_DEGREES), 0.02, "tomba de lado")
	assert_almost_eq(dragon.position.y, height - 0.35, 0.02, "e afunda um pouco")

func test_topple_outside_the_tree_is_immediate():
	var loose := Unit.new()
	loose.setup(MonsterDatabase.create_monster("dragon"), null, Vector2i.ZERO)
	loose.play_death_topple()
	assert_almost_eq(loose.rotation.z, deg_to_rad(Unit.DEATH_TOPPLE_DEGREES), 0.0001)
	loose.play_fire_breath() # fora da árvore: não agenda nada, não quebra
	assert_false(loose.is_breathing_fire())
	loose.free()
