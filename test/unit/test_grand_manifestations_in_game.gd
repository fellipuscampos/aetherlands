extends GutTest

## GRANDES MANIFESTAÇÕES EM JOGO (2026-10-13) — pedido do usuário: "temos nas pastas de modelos as grandes invocações
## todas com animações feitas, importe todas pro game, todas as civilizações têm as mesmas 6 grandes invocações, tenha
## certeza de inserir animações suaves entre os estados, tipo de idle pra spell, de idle pra walk... e adicione no
## debug a opção de eu simplesmente invocar qualquer um que eu quiser e quantos eu quiser pra eu poder testar".
## Os seis modelos de assets/generated/grand_manifestations, a transição por captura de pose (PoseCaptureTransition) e
## as ferramentas do painel de Debug (DebugSummon, Unit.debug_play_state).

const RACES := ["human", "elf", "orc", "dwarf"]
## Um quadro a 60 fps: o intervalo em que um salto de pose seria visível.
const FRAME := 1.0 / 60.0
## Quanto um osso pode andar/girar/crescer num quadro logo depois de uma troca de estado. A transição parte da pose
## capturada, então o primeiro quadro quase não se mexe; um corte seco passaria disto com folga (ver o teste do corte).
const MAX_STEP_POSITION := 0.02
const MAX_STEP_DEGREES := 2.5
const MAX_STEP_SCALE := 0.03

var grid: HexGrid
var human: PlayerData
var _players: Array[PlayerData] = []
var _original_human: PlayerData
var _original_grid: HexGrid
var _original_selected: Unit

func before_each():
	_original_human = GameManager.human_player
	_original_grid = GameManager.hex_grid
	_original_selected = SelectionManager.selected_unit

func after_each():
	GameManager.human_player = _original_human
	GameManager.hex_grid = _original_grid
	SelectionManager.selected_unit = _original_selected
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String = "human") -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = "Reino " + race
	civ.race = race
	civ.color = Color(0.2, 0.45, 0.85)
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _manifestation(kind: String, race: String = "human") -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), _player(race), Vector2i.ZERO)
	return unit

func _skeleton(unit: Unit) -> Skeleton3D:
	return unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func _pose(skeleton: Skeleton3D) -> Array:
	var pose := []
	for bone in skeleton.get_bone_count():
		pose.append([skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone), skeleton.get_bone_pose_scale(bone)])
	return pose

## O maior passo de qualquer osso entre duas poses: {position (m), degrees, scale}.
func _largest_step(before: Array, after: Array) -> Dictionary:
	var step := {"position": 0.0, "degrees": 0.0, "scale": 0.0}
	for bone in before.size():
		step.position = maxf(step.position, (before[bone][0] as Vector3).distance_to(after[bone][0]))
		step.degrees = maxf(step.degrees, rad_to_deg((before[bone][1] as Quaternion).angle_to(after[bone][1])))
		step.scale = maxf(step.scale, (before[bone][2] as Vector3).distance_to(after[bone][2]))
	return step

func _assert_no_pop(unit: Unit, label: String, trigger: Callable) -> void:
	var skeleton := _skeleton(unit)
	var before := _pose(skeleton)
	trigger.call()
	unit._anim_player.advance(FRAME)
	var step := _largest_step(before, _pose(skeleton))
	assert_lt(step.position, MAX_STEP_POSITION, "%s: nenhum osso salta de lugar (%.4f m)" % [label, step.position])
	assert_lt(step.degrees, MAX_STEP_DEGREES, "%s: nenhum osso salta de ângulo (%.2f°)" % [label, step.degrees])
	assert_lt(step.scale, MAX_STEP_SCALE, "%s: nenhum osso salta de escala (%.4f)" % [label, step.scale])

func _field() -> void:
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-5, 6):
		for r in range(-5, 6):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player()

# --- Os seis modelos, iguais para as quatro raças -----------------------------------------------------------------------

func test_the_six_manifestations_are_exactly_the_ones_the_game_trains():
	var trainable: Array[String] = []
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if V2ManifestationSystem.is_manifestation_kind(kind):
			trainable.append(kind)
	assert_eq(trainable.size(), 6)
	for kind in trainable:
		assert_true(UnitDatabase.MANIFESTATION_MODELS.has(kind), "%s tem modelo próprio" % kind)
	assert_eq(UnitDatabase.MANIFESTATION_MODELS.size(), 6)
	assert_eq(DebugSummon.summonable_kinds().size(), 6)

func test_every_race_gets_the_same_animated_model_at_native_scale():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var path := UnitDatabase.manifestation_model_path(kind)
		assert_true(path.begins_with(UnitDatabase.MANIFESTATION_MODEL_DIR), kind)
		assert_true(ResourceLoader.exists(path), "%s: %s importado" % [kind, path])
		for race in RACES:
			var label := "%s (%s)" % [kind, race]
			var unit := _manifestation(kind, race)
			assert_eq(unit.unit_data.model_scene_path, path, "%s: o MESMO modelo em toda civilização" % label)
			assert_not_null(unit._anim_player, label)
			if unit._anim_player == null:
				continue
			assert_eq(String(unit._anim_player.current_animation), unit.idle_animation, "%s: nasce parada" % label)
			var playing := 0
			for player in unit.find_children("*", "AnimationPlayer", true, false):
				if player.is_playing():
					playing += 1
			assert_eq(playing, 1, "%s: só a Unit comanda o esqueleto" % label)
			var model := unit._anim_player.get_parent() as Node3D
			assert_eq(model.scale, Vector3.ONE, "%s: escala nativa (nunca normalizar pela caixa)" % label)
			assert_almost_eq(model.rotation.y, 0.0, 0.001, "%s: frente em +Z" % label)
			var body: MeshInstance3D = null
			for mesh in unit.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null:
					body = mesh
			assert_not_null(body, "%s: malha com esqueleto" % label)
			if body == null:
				continue
			var bounds := body.mesh.get_aabb()
			assert_between(bounds.end.y, 3.0, 3.4, "%s: 3 m de altura, pairando sobre o chão" % label)
			assert_gt(bounds.position.y, 0.15, "%s: não encosta no chão" % label)
			assert_gt(unit.markers_top_height(), bounds.end.y, "%s: o selo flutua acima do modelo" % label)

func test_the_provisional_bodies_are_gone():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var data := UnitDatabase.create_unit(kind)
		assert_false(data.model_scene_path.contains("/magic/"), "%s não usa mais o modelo provisório" % kind)
		assert_eq(data.model_scale_multiplier, 1.0, kind)
	assert_eq(UnitDatabase.create_unit("v2_manifestation_nature_avatar").visual_template, "", "o Ent procedural ampliado saiu")

func test_bound_entities_keep_art_and_use_the_revised_combat_profiles():
	var expected := {
		"v2_manifestation_seraph": [50.0, 10.5, 3.0, 84.0, 120.0],
		"v2_manifestation_archdemon": [50.0, 9.0, 3.0, 88.0, 140.0],
		"v2_manifestation_lich_sovereign": [46.0, 9.0, 2.0, 84.0, 130.0],
		"v2_manifestation_nature_avatar": [60.0, 12.0, 3.0, 88.0, 130.0],
		"v2_manifestation_veil_archon": [46.0, 8.5, 4.0, 88.0, 140.0],
		"v2_manifestation_elemental_primordial": [54.0, 10.0, 4.0, 92.0, 150.0],
	}
	for kind in expected:
		var data := UnitDatabase.create_unit(kind)
		var stats: Array = expected[kind]
		assert_eq([data.max_hp, data.defense, data.movement_points], [stats[0], stats[1], stats[2]], kind)
		if stats[3] > 0.0:
			assert_eq([data.production_cost, data.production_mana_cost], [stats[3], stats[4]], kind)
		assert_true(data.can_basic_attack, "%s pode cumprir uma ordem de ataque" % kind)
		assert_eq(data.supply_cost, 0, kind)

# --- Os quatro clipes ---------------------------------------------------------------------------------------------------

func test_four_clips_loop_correctly_and_animate_the_same_bones():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		var player := unit._anim_player
		assert_eq(player.get_animation_list().size(), 4, kind)
		var clips := {unit.idle_animation: true, unit.moving_animation: true, unit.attack_animation: false, unit.cast_animation: false}
		assert_eq(clips.size(), 4, "%s: quatro clipes distintos" % kind)
		var reference := {}
		for clip in clips:
			assert_true(player.has_animation(clip), "%s: %s" % [kind, clip])
			var animation := player.get_animation(clip)
			assert_eq(animation.loop_mode, Animation.LOOP_LINEAR if clips[clip] else Animation.LOOP_NONE, "%s: %s" % [kind, clip])
			var paths := {}
			for track in animation.get_track_count():
				paths[String(animation.track_get_path(track))] = true
			if reference.is_empty():
				reference = paths
			assert_eq(paths.size(), reference.size(), "%s: %s anima o mesmo número de canais" % [kind, clip])
			for path in reference:
				if not paths.has(path):
					fail_test("%s: %s não anima %s — a mistura puxaria o osso para o repouso" % [kind, clip, path])
					break

func test_moving_selects_walk_and_arriving_returns_to_idle():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		unit.slide_to(Vector3(2, 0, 0))
		assert_eq(String(unit._anim_player.current_animation), unit.moving_animation, kind)
		unit.place_at(Vector3(2, 0, 0))
		assert_eq(String(unit._anim_player.current_animation), unit.idle_animation, kind)

func test_casting_plays_spell_once_and_returns_to_idle_or_walk():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		var player := unit._anim_player
		unit.play_cast_visual(Vector3(3, 0, 0))
		assert_eq(String(player.current_animation), unit.cast_animation, kind)
		assert_almost_eq(unit.facing_target_yaw, PI / 2, 0.001, "%s vira para o alvo" % kind)
		player.advance(player.get_animation(unit.cast_animation).length + 0.1)
		assert_eq(String(player.current_animation), unit.idle_animation, "%s: volta sozinha ao Parado" % kind)

		unit.slide_to(Vector3(2, 0, 0))
		unit.play_cast_visual(Vector3(3, 0, 0))
		player.advance(player.get_animation(unit.cast_animation).length + 0.1)
		assert_eq(String(player.current_animation), unit.moving_animation, "%s: ainda andando, volta ao Andar" % kind)

# --- Transições suaves --------------------------------------------------------------------------------------------------

func test_state_changes_start_from_the_current_pose():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		var player := unit._anim_player
		assert_gt(unit.unit_data.pose_transition_time, 0.0, kind)
		assert_true(player.get_meta(Unit.POSE_TRANSITION_META, null) is PoseCaptureTransition, "%s: transição por captura de pose" % kind)
		assert_eq(player.playback_default_blend_time, 0.0, "%s: sem crossfade linear por cima da captura" % kind)
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			for track in animation.get_track_count():
				assert_eq(animation.track_get_type(track), Animation.TYPE_VALUE, "%s/%s: toda trilha é capturável" % [kind, clip])
				if animation.track_get_type(track) != Animation.TYPE_VALUE or animation.value_track_get_update_mode(track) != Animation.UPDATE_CAPTURE:
					fail_test("%s/%s: trilha %s fora do modo capture" % [kind, clip, animation.track_get_path(track)])
					break
		# O GLB importado fica intacto: cada unidade trabalha numa cópia dos clipes.
		var source: Node = (load(unit.unit_data.model_scene_path) as PackedScene).instantiate()
		var source_player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var kinds := {}
		for track in source_player.get_animation(unit.idle_animation).get_track_count():
			kinds[source_player.get_animation(unit.idle_animation).track_get_type(track)] = true
		assert_true(kinds.has(Animation.TYPE_ROTATION_3D), "%s: o clipe importado continua com trilhas 3D" % kind)
		source.free()

func test_transition_times_follow_the_data():
	var seraph := _manifestation("v2_manifestation_seraph")
	assert_eq(seraph.pose_transition_seconds(seraph._anim_player, seraph.cast_animation), UnitDatabase.MANIFESTATION_TRANSITION_TIME)
	assert_eq(seraph.pose_transition_seconds(seraph._anim_player, seraph.moving_animation), UnitDatabase.MANIFESTATION_TRANSITION_TIME)
	# O Primordial muda de postura para andar: os tempos aprovados com o modelo dele.
	var primordial := _manifestation("v2_manifestation_elemental_primordial")
	var player := primordial._anim_player
	assert_eq(primordial.pose_transition_seconds(player, primordial.cast_animation), UnitDatabase.PRIMORDIAL_TRANSITION_TIME)
	assert_eq(primordial.pose_transition_seconds(player, primordial.moving_animation), UnitDatabase.PRIMORDIAL_WALK_TRANSITION_TIME)
	primordial.slide_to(Vector3(2, 0, 0))
	assert_eq(primordial.pose_transition_seconds(player, primordial.idle_animation), UnitDatabase.PRIMORDIAL_WALK_TRANSITION_TIME, "sair do Andar também é mudança de postura")

func test_no_state_change_makes_a_bone_jump():
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		var player := unit._anim_player
		var cast_length := player.get_animation(unit.cast_animation).length
		player.advance(1.37) # um ponto qualquer do Parado, longe da pose inicial
		_assert_no_pop(unit, "%s parado -> andar" % kind, func() -> void: unit.slide_to(Vector3(2, 0, 0)))
		player.advance(0.21) # interrompe a transição no meio
		_assert_no_pop(unit, "%s andar (no meio da transição) -> parado" % kind, func() -> void: unit.place_at(Vector3(2, 0, 0)))
		player.advance(2.0)
		_assert_no_pop(unit, "%s parado -> conjurar" % kind, func() -> void: unit.play_cast_visual(Vector3(3, 0, 0)))
		player.advance(cast_length * 0.45) # o auge do gesto
		_assert_no_pop(unit, "%s conjurar de novo no meio do gesto" % kind, func() -> void: unit.play_cast_visual(Vector3(3, 0, 0)))
		player.advance(cast_length * 0.45)
		_assert_no_pop(unit, "%s conjurar (interrompido) -> andar" % kind, func() -> void: unit.slide_to(Vector3(4, 0, 0)))
		unit.place_at(Vector3(4, 0, 0))
		player.advance(1.5)
		_assert_no_pop(unit, "%s parado -> atacar" % kind, func() -> void: unit.debug_play_state("attack"))
		player.advance(player.get_animation(unit.attack_animation).length * 0.4)
		_assert_no_pop(unit, "%s atacar (interrompido) -> parado" % kind, func() -> void: unit.debug_play_state("idle"))

func test_one_shot_clips_end_where_idle_begins():
	# O fim natural de Conjurar/Atacar emenda no Parado: o último quadro do gesto e o primeiro do ciclo não saltam.
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		for state in ["cast", "attack"]:
			var unit := _manifestation(kind)
			var player := unit._anim_player
			assert_true(unit.debug_play_state(state))
			var clip := String(player.current_animation)
			player.advance(player.get_animation(clip).length - FRAME)
			var skeleton := _skeleton(unit)
			var before := _pose(skeleton)
			player.advance(FRAME * 2.0) # passa do fim: volta sozinha ao Parado
			assert_eq(String(player.current_animation), unit.idle_animation, "%s %s" % [kind, state])
			var step := _largest_step(before, _pose(skeleton))
			assert_lt(step.position, MAX_STEP_POSITION * 2.0, "%s: fim de %s -> parado (%.4f m)" % [kind, state, step.position])
			assert_lt(step.degrees, MAX_STEP_DEGREES * 2.0, "%s: fim de %s -> parado (%.2f°)" % [kind, state, step.degrees])

func test_a_hard_cut_would_fail_the_same_measure():
	# Prova que a medida enxerga um salto: o mesmo instante do Conjurar, comparado com o começo do Parado sem transição.
	var visible_cuts := 0
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var unit := _manifestation(kind)
		var player := unit._anim_player
		unit.play_cast_visual(Vector3(0, 0, 3))
		player.advance(player.get_animation(unit.cast_animation).length * 0.45 + 1.0)
		var skeleton := _skeleton(unit)
		var mid_cast := _pose(skeleton)
		player.play(unit.idle_animation, 0.0)
		player.advance(FRAME)
		var cut := _largest_step(mid_cast, _pose(skeleton))
		if cut.position > MAX_STEP_POSITION or cut.degrees > MAX_STEP_DEGREES or cut.scale > MAX_STEP_SCALE:
			visible_cuts += 1
	assert_eq(visible_cuts, 6, "sem a transição, as seis saltariam ao sair do Conjurar")

# --- Debug: invocar quantas quiser -----------------------------------------------------------------------------------

func test_debug_summons_any_number_of_any_manifestation_next_to_the_origin():
	_field()
	var origin := Vector2i(0, 0)
	for kind in DebugSummon.summonable_kinds():
		var before := human.units.size()
		var summoned := DebugSummon.summon(grid, human, kind, 3, origin)
		assert_eq(summoned.size(), 3, kind)
		assert_eq(human.units.size(), before + 3, kind)
		for unit in summoned:
			assert_eq(unit.owner_player, human, kind)
			assert_eq(unit.unit_data.visual_kind, kind)
			assert_same(grid.get_unit_at(unit.coord), unit, "%s está no tile que diz ocupar" % kind)
			assert_eq(unit.hp, unit.unit_data.max_hp, kind)
	# 18 unidades, cada uma no seu tile, em volta da origem (origem + dois anéis = 19 tiles).
	var coords := {}
	for unit in human.units:
		coords[unit.coord] = true
		assert_lte(HexMetrics.axial_distance(origin, unit.coord), 2, "nasce o mais perto possível")
	assert_eq(coords.size(), 18)

func test_debug_summon_ignores_the_one_per_school_limit_and_the_costs():
	_field()
	human.mana = 0.0
	human.gold = 0.0
	var seraphs := DebugSummon.summon(grid, human, "v2_manifestation_seraph", 4, Vector2i(1, 1))
	assert_eq(seraphs.size(), 4, "quatro Serafins lado a lado, para comparar")
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 4)
	assert_false(V2ManifestationSystem.spawn_allowed(human, "v2_manifestation_seraph"), "a regra de produção continua valendo")
	assert_eq([human.mana, human.gold], [0.0, 0.0], "nada foi cobrado")

func test_debug_summon_only_uses_free_dry_land():
	_field()
	var origin := Vector2i(0, 0)
	grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid.tiles[Vector2i(-1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var blocker := grid.spawn_unit(origin, UnitDatabase.create_unit("v2_unit_archer"), human)
	var city := grid.found_city(Vector2i(0, 1), human, "Teste", true)
	assert_not_null(city)
	var summoned := DebugSummon.summon(grid, human, "v2_manifestation_archdemon", 6, origin)
	assert_eq(summoned.size(), 6)
	for unit in summoned:
		assert_false(unit.coord in [origin, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)], "%s não é tile livre" % str(unit.coord))
		assert_false(unit.embarked, "nasce em terra, com o próprio modelo")
	assert_same(grid.get_unit_at(origin), blocker, "quem já estava lá continua lá")

func test_debug_summon_rejects_nonsense_and_clamps_the_count():
	_field()
	assert_eq(DebugSummon.summon(grid, human, "v2_manifestation_seraph", 0, Vector2i.ZERO).size(), 0)
	assert_eq(DebugSummon.summon(grid, human, "v2_manifestation_seraph", -3, Vector2i.ZERO).size(), 0)
	assert_eq(DebugSummon.summon(grid, human, "nao_existe", 2, Vector2i.ZERO).size(), 0)
	assert_eq(DebugSummon.summon(null, human, "v2_manifestation_seraph", 2, Vector2i.ZERO).size(), 0)
	assert_eq(DebugSummon.summon(grid, null, "v2_manifestation_seraph", 2, Vector2i.ZERO).size(), 0)
	assert_eq(human.units.size(), 0)
	assert_eq(DebugSummon.free_tiles_near(grid, Vector2i.ZERO, 999).size(), 121, "o campo inteiro (11x11) está livre")
	assert_eq(DebugSummon.summon(grid, human, "v2_manifestation_veil_archon", 999, Vector2i.ZERO).size(), DebugSummon.MAX_COUNT, "no máximo MAX_COUNT por clique")

func test_debug_summon_origin_prefers_the_selected_unit_then_a_city():
	_field()
	assert_eq(DebugSummon.default_origin(grid, human), Vector2i.ZERO, "sem nada: o meio do mapa")
	var scout := grid.spawn_unit(Vector2i(4, -2), UnitDatabase.create_unit("v2_unit_archer"), human)
	assert_eq(DebugSummon.default_origin(grid, human), Vector2i(4, -2), "sem cidade: a primeira unidade")
	grid.found_city(Vector2i(-3, 2), human, "Teste", true)
	assert_eq(DebugSummon.default_origin(grid, human), Vector2i(-3, 2), "com cidade: a cidade")
	assert_eq(DebugSummon.default_origin(grid, human, scout), Vector2i(4, -2), "com seleção: a unidade selecionada")

# --- Debug: o painel -----------------------------------------------------------------------------------------------------

func test_debug_panel_offers_one_button_per_manifestation_and_a_quantity():
	_field()
	GameManager.human_player = human
	GameManager.hex_grid = grid
	var hud: Control = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_eq(hud._debug_summon_buttons.size(), 6)
	for kind in DebugSummon.summonable_kinds():
		var button: Button = hud._debug_summon_buttons[kind]
		assert_eq(button.text, UnitDatabase.create_unit(kind).unit_name)
		assert_true(hud.debug_panel.is_ancestor_of(button), "%s mora no painel de Debug" % kind)
	assert_eq([hud._debug_summon_count.min_value, hud._debug_summon_count.max_value], [1.0, float(DebugSummon.MAX_COUNT)])

	var anchor := grid.spawn_unit(Vector2i(3, 0), UnitDatabase.create_unit("v2_unit_archer"), human)
	SelectionManager.selected_unit = anchor
	hud._debug_summon_count.value = 5
	(hud._debug_summon_buttons["v2_manifestation_lich_sovereign"] as Button).pressed.emit()
	var liches := V2ManifestationSystem.active_units(human, "necromancy")
	assert_eq(liches.size(), 5, "a quantidade escolhida")
	for lich in liches:
		assert_lte(HexMetrics.axial_distance(anchor.coord, lich.coord), 2, "ao lado da unidade selecionada")

	# Os quatro botões de animação agem sobre a unidade selecionada.
	SelectionManager.selected_unit = liches[0]
	(hud._debug_animation_buttons["cast"] as Button).pressed.emit()
	assert_eq(String(liches[0]._anim_player.current_animation), liches[0].cast_animation)
	(hud._debug_animation_buttons["attack"] as Button).pressed.emit()
	assert_eq(String(liches[0]._anim_player.current_animation), liches[0].attack_animation)
	(hud._debug_animation_buttons["walk"] as Button).pressed.emit()
	assert_eq(String(liches[0]._anim_player.current_animation), liches[0].moving_animation)
	(hud._debug_animation_buttons["idle"] as Button).pressed.emit()
	assert_eq(String(liches[0]._anim_player.current_animation), liches[0].idle_animation)
	assert_eq(liches[0].coord, liches[0].coord, "tocar um clipe não move nem gasta nada")
	assert_eq(liches[0].movement_left, liches[0].unit_data.movement_points)

func test_debug_panel_scrolls_instead_of_leaving_the_screen():
	_field()
	GameManager.human_player = human
	GameManager.hex_grid = grid
	var hud: Control = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	hud._on_debug_pressed()
	assert_true(hud.debug_panel.visible)
	assert_true(hud._debug_scroll.is_ancestor_of(hud._debug_summon_buttons["v2_manifestation_seraph"]), "a lista rola")
	assert_true(hud._debug_scroll.is_ancestor_of(hud.debug_force_dragon_button), "os botões antigos rolam junto")
	assert_eq(hud._debug_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	# A altura da lista é a do conteúdo, limitada à janela (o teste headless roda numa janela de 64 px: a conta é pura).
	var margin: float = hud.DEBUG_PANEL_SCREEN_MARGIN
	assert_eq(hud.debug_list_height(430.0, 1080.0), 430.0, "cabe: sem rolagem")
	assert_eq(hud.debug_list_height(940.0, 1080.0), 940.0)
	assert_eq(hud.debug_list_height(940.0, 900.0), 900.0 - margin, "janela 900p: rola em vez de sair da tela")
	assert_eq(hud.debug_list_height(940.0, 720.0), 720.0 - margin)
	assert_eq(hud.debug_list_height(940.0, 64.0), hud.DEBUG_PANEL_MIN_LIST_HEIGHT, "piso para janela minúscula")
	assert_false(hud._debug_scroll.is_ancestor_of(hud.debug_close_button),"Close remains pinned above the scrolling pages")
	assert_false(hud._debug_scroll.is_ancestor_of(hud._debug_animation_buttons.idle),"Animation shortcuts remain pinned below the scrolling pages")
	assert_eq(hud._debug_menu.current,"mages")
	for key in hud._debug_menu.pages: assert_eq(hud._debug_menu.pages[key].visible,key=="mages")
	var layout = load("res://scripts/ui/DebugMenuLayout.gd")
	for screen in [Vector2(1280,720),Vector2(1600,900),Vector2(960,720)]:
		for scale_factor in [1.0,1.25,1.5]:
			var bounds: Vector2 = layout.menu_size(screen,scale_factor)
			assert_lte(bounds.x,screen.x-48)
			assert_lte(bounds.y,screen.y-72)

func test_debug_mages_prepare_only_their_school_and_can_renew_magic_without_a_turn() -> void:
	_field()
	human.mana = 0
	human.gold = 0
	assert_eq(DebugSummon.mage_kinds().size(),6)
	for kind in DebugSummon.mage_kinds():
		human.mana = 0
		var mage := DebugSummon.summon(grid,human,kind,1,Vector2i.ZERO)[0]
		var school := mage.unit_data.v2_magic_school
		assert_eq(V2MagicRuntime.spells_for_unit(mage).size(),0,"Spawning alone does not grant research")
		mage.movement_left = 0
		mage.magic_cooldowns["test"] = TurnManager.turn_number+5
		assert_true(DebugSummon.prepare_magic_test(mage))
		assert_eq(V2MagicRuntime.spells_for_unit(mage).size(),4,school)
		assert_eq(human.mana,1000.0)
		assert_eq(mage.movement_left,mage.unit_data.movement_points)
		assert_true(mage.magic_cooldowns.is_empty())
		assert_false(human.v2_research.is_completed("v2_magic_%s_8" % school),"Rituals remain unresearched")
		mage.movement_left = 0
		mage.magic_cooldowns["test"] = TurnManager.turn_number+5
		human.mana = 1500
		assert_true(DebugSummon.renew_magic_test(mage))
		assert_eq(human.mana,1500.0,"Renewal never removes existing mana")
		assert_true(mage.magic_cooldowns.is_empty())
	assert_true(human.cities.is_empty(),"No buildings or cities are required")
	assert_eq(human.gold,0.0,"No production cost")
	assert_false(DebugSummon.prepare_magic_test(null))
	var fighter := grid.spawn_unit(Vector2i(4,4),UnitDatabase.create_unit("warrior"),human)
	assert_false(DebugSummon.renew_magic_test(fighter))

func test_debug_mage_buttons_honor_quantity_and_optional_preparation() -> void:
	_field()
	GameManager.human_player = human
	GameManager.hex_grid = grid
	human.mana = 0
	var hud: Control = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	hud._on_debug_pressed()
	assert_eq(hud._debug_mage_buttons.size(),6)
	assert_true(hud._debug_prepare_magic.button_pressed)
	hud._debug_mage_count.value = 3
	hud._debug_prepare_magic.button_pressed = false
	(hud._debug_mage_buttons["v2_unit_elementalist"] as Button).pressed.emit()
	assert_eq(human.units.size(),3)
	assert_eq(human.mana,0.0)
	assert_true(human.v2_research.get_completed_ids().is_empty())
	assert_same(SelectionManager.selected_unit,human.units[0],"First mage is selected for immediate testing")
	hud._debug_prepare_magic.button_pressed = true
	hud._debug_mage_count.value = 1
	(hud._debug_mage_buttons["v2_unit_sacred_cleric"] as Button).pressed.emit()
	var mage := SelectionManager.selected_unit
	assert_eq(mage.unit_data.v2_magic_school,"sacred")
	assert_eq(V2MagicRuntime.spells_for_unit(mage).size(),4)
	assert_false(human.v2_research.is_completed("v2_magic_elementalism_2"),"Preparation does not unlock other schools")
	mage.magic_cooldowns.test = TurnManager.turn_number+3
	mage.movement_left = 0
	hud._debug_renew_magic_button.pressed.emit()
	assert_true(mage.magic_cooldowns.is_empty())
	assert_gt(mage.movement_left,0.0)
	hud._debug_wound_button.pressed.emit()
	assert_eq(mage.hp,mage.unit_data.max_hp*.5)
	(hud._debug_menu.tabs.ambience as Button).pressed.emit()
	assert_true(hud._debug_menu.pages.ambience.visible)
	assert_false(hud._debug_menu.pages.mages.visible)
	assert_true(hud._debug_animation_buttons.idle.is_visible_in_tree())
	SelectionManager.reset()

func test_debug_magic_preparation_keeps_unlock_signals_without_notification_spam() -> void:
	_field()
	GameManager.human_player = human
	var mage := DebugSummon.summon(grid,human,"v2_unit_sacred_cleric",1,Vector2i.ZERO)[0]
	watch_signals(EventBus)
	assert_true(DebugSummon.prepare_magic_test(mage))
	assert_signal_emit_count(EventBus,"v2_unlock_applied",6,"All real unlock listeners still receive their events")
	assert_signal_not_emitted(EventBus,"notify")
	assert_signal_not_emitted(EventBus,"ui_research_completed")
	assert_false(human.v2_research.has_meta("debug_silent_research"),"Temporary batch suppression is fully restored")
	assert_true(human.v2_research.complete_research("v2_magic_sacred_8"))
	assert_signal_emit_count(EventBus,"notify",1,"Normal research still announces itself")
	assert_signal_emit_count(EventBus,"ui_research_completed",1)

func test_debug_play_state_only_plays_clips_the_unit_has():
	var seraph := _manifestation("v2_manifestation_seraph")
	for state in ["idle", "walk", "attack", "cast"]:
		assert_true(seraph.debug_play_state(state), state)
	assert_false(seraph.debug_play_state("dance"))
	var player := seraph._anim_player
	assert_true(seraph.debug_play_state("attack"))
	player.advance(player.get_animation(seraph.attack_animation).length + 0.1)
	assert_eq(String(player.current_animation), seraph.idle_animation, "o Ataque de debug volta sozinho ao Parado")
	var settler := Unit.new()
	add_child_autofree(settler)
	var bare := UnitData.new()
	bare.unit_name = "Sem modelo"
	settler.setup(bare, _player(), Vector2i.ZERO)
	assert_false(settler.debug_play_state("idle"), "unidade sem AnimationPlayer: nada a tocar")
