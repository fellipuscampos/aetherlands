extends GutTest

var players: Array[PlayerData] = []

func after_each() -> void:
	for player in players: player.release_relations()
	players.clear()

func dwarf_player() -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = "dwarf"
	var player := PlayerData.new(civ)
	players.append(player)
	return player

func unit_of(kind: String, player: PlayerData) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), player, Vector2i.ZERO)
	return unit

func test_all_24_dwarves_use_their_own_model_and_skill_clips() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dwarves/dwarf_troops_manifest.json"))
	var player := dwarf_player()
	var count := 0
	for row: Dictionary in rows:
		var data := UnitDatabase.create_unit(row.gameplay_id)
		var themed := UnitArtCatalog.for_owner(data, player)
		assert_eq(themed.model_scene_path, row.path)
		assert_eq([themed.attack, themed.defense, themed.max_hp, themed.production_cost, themed.movement_points],
			[data.attack, data.defense, data.max_hp, data.production_cost, data.movement_points])
		var unit := unit_of(row.gameplay_id, player)
		assert_not_null(unit._anim_player)
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row.path.get_basename() + "_report.json"))
		for clip: String in report.skills.clips:
			assert_true(unit._anim_player.has_animation(clip), row.stem + ": " + clip)
			var expected: Dictionary = report.skills.clips[clip]
			assert_eq(unit._anim_player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR if bool(expected.loop) else Animation.LOOP_NONE)
			count += 1
	assert_eq(count, 43)

func test_second_technique_is_only_declared_for_evolved_forms() -> void:
	for pair: Array in [["v2_unit_warrior", "v2_unit_swordsman", V2DoctrineTechniqueDatabase.CLEAVE],
		["v2_unit_archer", "v2_unit_hunter", V2DoctrineTechniqueDatabase.VOLLEY],
		["v2_unit_cavalier", "v2_unit_shock_cavalier", V2DoctrineTechniqueDatabase.TACTICAL_RETREAT],
		["v2_unit_rogue", "v2_unit_saboteur", V2DoctrineTechniqueDatabase.DISMANTLE],
		["v2_unit_catapult", "v2_unit_trebuchet", V2DoctrineTechniqueDatabase.PREPARED_BOMBARDMENT]]:
		var first: Dictionary = UnitArtCatalog.entry(pair[0], "dwarf").techniques
		var evolved: Dictionary = UnitArtCatalog.entry(pair[1], "dwarf").techniques
		assert_false(first.has(pair[2]))
		assert_true(evolved.has(pair[2]))
		for technique in first: assert_eq(evolved[technique], first[technique])

func test_active_melee_and_ranged_techniques_play_the_native_clip() -> void:
	var player := dwarf_player()
	var victim := unit_of("v2_unit_guardian", dwarf_player())
	for kind: String in ["v2_unit_weapon_master", "v2_unit_elite_marksman", "v2_unit_armored_cavalier", "v2_unit_assassin"]:
		var unit := unit_of(kind, player)
		for technique in unit.unit_data.technique_animation_overrides:
			if technique in [V2DoctrineTechniqueDatabase.DISMANTLE, V2DoctrineTechniqueDatabase.TACTICAL_RETREAT]: continue
			var expected := String(unit.unit_data.technique_animation_overrides[technique])
			unit.begin_technique_animation(technique)
			unit.play_attack_visual(victim)
			assert_eq(String(unit._anim_player.current_animation), expected)
			unit._anim_player.seek(0.4, true)
			unit.play_attack_visual(victim)
			assert_almost_eq(unit._anim_player.current_animation_position, 0.4, 0.001, "multi-target resolve does not restart")
			unit.end_technique_animation()

func test_shield_enter_chains_to_hold_and_expiry_returns_to_idle() -> void:
	var unit := unit_of("v2_unit_guardian", dwarf_player())
	unit._braced = true
	unit._anim_player.play("shield_wall")
	unit._anim_player.advance(unit._anim_player.current_animation_length + 0.01)
	assert_eq(String(unit._anim_player.current_animation), "shield_wall_hold")
	assert_eq(unit._rest_animation(), "shield_wall_hold")
	unit._refresh_brace_visual()
	assert_eq(String(unit._anim_player.current_animation), "idle")

func test_prepared_city_attack_plays_the_native_bombardment() -> void:
	var unit := unit_of("v2_unit_bombard", dwarf_player())
	unit.begin_technique_animation(V2DoctrineTechniqueDatabase.PREPARED_BOMBARDMENT)
	unit.play_city_attack_visual(null)
	assert_eq(String(unit._anim_player.current_animation), "prepared_bombardment")
	unit.end_technique_animation()
	unit._anim_player.advance(unit._anim_player.current_animation_length + 0.01)
	assert_eq(String(unit._anim_player.current_animation), "idle")

func test_tactical_retreat_plays_during_the_real_movement_queue() -> void:
	var unit := unit_of("v2_unit_shock_cavalier", dwarf_player())
	unit.walk_path([unit.position + Vector3(0, 0, 1)], "tactical_retreat")
	assert_eq(String(unit._anim_player.current_animation), "tactical_retreat")
	await get_tree().create_timer(Unit.MOVE_DURATION + 0.15).timeout
	assert_eq(String(unit._anim_player.current_animation), "idle")
	assert_eq(unit._movement_skill_clip, "")

func test_charge_finishes_after_the_approach_queue_ends() -> void:
	var unit := unit_of("v2_unit_cavalier", dwarf_player())
	var victim := unit_of("v2_unit_guardian", dwarf_player())
	unit.walk_path([unit.position + Vector3(0, 0, 1)])
	unit.begin_technique_animation(V2DoctrineTechniqueDatabase.CHARGE)
	unit.play_attack_visual(victim)
	unit.end_technique_animation()
	await get_tree().create_timer(Unit.MOVE_DURATION + 0.15).timeout
	assert_eq(String(unit._anim_player.current_animation), "charge", "arrival must not interrupt the strike")
	unit._anim_player.advance(unit._anim_player.current_animation_length + 0.01)
	assert_eq(String(unit._anim_player.current_animation), "idle")
