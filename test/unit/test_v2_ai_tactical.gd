extends GutTest

var grid: HexGrid
var human: PlayerData
var ai: PlayerData
var original_players: Array[PlayerData]
var original_human: PlayerData
var original_rivals: Array[PlayerData]
var original_grid: HexGrid
var original_turn: int

func before_each():
	original_players = GameManager.players
	original_human = GameManager.human_player
	original_rivals = GameManager.rival_players
	original_grid = GameManager.hex_grid
	original_turn = TurnManager.turn_number
	TurnManager.turn_number = 20
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Human")
	ai = _player("AI")
	GameManager.players = [human, ai]
	GameManager.human_player = human
	GameManager.rival_players = [ai]
	GameManager.hex_grid = grid
	V2StrategicAI.initialize_player(ai, 0, 24024, 1)
	Diplomacy.declare_war(ai, human)
	ai.mana = 200.0

func after_each():
	V2AITacticalAI.clear_views()
	human.release_relations()
	ai.release_relations()
	GameManager.players = original_players
	GameManager.human_player = original_human
	GameManager.rival_players = original_rivals
	GameManager.hex_grid = original_grid
	TurnManager.turn_number = original_turn
	if is_instance_valid(grid):
		grid.queue_free()

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	return PlayerData.new(civ)

func _learn_doctrine(branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		ai.v2_research.complete_research("v2_doctrine_%s_%d" % [branch, i])

func _learn_magic(branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		ai.v2_research.complete_research("v2_magic_%s_%d" % [branch, i])

func _unit(owner: PlayerData, kind: String, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func test_ai_uses_profitable_visible_strike_through_normal_runtime():
	_learn_doctrine("warrior", 4)
	var warrior := _unit(ai, "v2_unit_warrior", Vector2i.ZERO)
	var target := _unit(human, "guard", Vector2i(1, 0))
	target.hp = 2.0
	var before := target.hp
	assert_true(V2AITacticalAI.take_special_action(warrior, ai, grid))
	assert_lt(target.hp, before)
	assert_eq(warrior.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(warrior, "v2_technique_power_strike"), 3)

func test_ai_respects_technique_cooldown_and_spent_action():
	_learn_doctrine("warrior", 4)
	var warrior := _unit(ai, "v2_unit_warrior", Vector2i.ZERO)
	var target := _unit(human, "guard", Vector2i(1, 0))
	target.hp = 20.0
	warrior.magic_cooldowns["v2_technique_power_strike"] = TurnManager.turn_number + 2
	var before := target.hp
	assert_false(V2AITacticalAI.take_special_action(warrior, ai, grid))
	assert_eq(target.hp, before)
	warrior.movement_left = 0.0
	assert_true(V2AITacticalAI.take_special_action(warrior, ai, grid), "spent units are consumed without a second action")
	assert_eq(target.hp, before)

func test_defensive_technique_is_used_only_under_visible_threat():
	_learn_doctrine("guardian", 4)
	var guardian := _unit(ai, "v2_unit_shieldbearer", Vector2i.ZERO)
	assert_false(V2AITacticalAI.take_special_action(guardian, ai, grid))
	assert_false(V2TechniqueRuntime.is_active(guardian, "v2_technique_shield_wall"))
	_unit(human, "guard", Vector2i(1, 0))
	V2AITacticalAI.clear_views()
	assert_true(V2AITacticalAI.take_special_action(guardian, ai, grid))
	assert_true(V2TechniqueRuntime.is_active(guardian, "v2_technique_shield_wall"))

func test_ai_heals_wounded_ally_and_spends_real_mana_and_action():
	_learn_magic("sacred", 4)
	var cleric := _unit(ai, "v2_unit_sacred_cleric", Vector2i.ZERO)
	var ally := _unit(ai, "guard", Vector2i(1, 0))
	ally.hp = 2.0
	var before_mana := ai.mana
	assert_true(V2AITacticalAI.take_special_action(cleric, ai, grid))
	assert_gt(ally.hp, 2.0)
	assert_lt(ai.mana, before_mana)
	assert_eq(cleric.movement_left, 0.0)

func test_ai_does_not_waste_heal_when_everyone_is_full():
	_learn_magic("sacred", 4)
	var cleric := _unit(ai, "v2_unit_sacred_cleric", Vector2i.ZERO)
	_unit(ai, "guard", Vector2i(1, 0))
	var before_mana := ai.mana
	V2AITacticalAI.take_special_action(cleric, ai, grid)
	assert_eq(ai.mana, before_mana)

func test_arcane_mana_reserve_blocks_non_emergency_spell():
	_learn_magic("infernal", 4)
	var caster := _unit(ai, "v2_unit_infernal_warlock", Vector2i.ZERO)
	var enemy := _unit(human, "guard", Vector2i(2, 0))
	ai.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.TRANSCENDENCE
	ai.mana = V2StrategicAI.strategic_mana_reserve(ai)
	var before := enemy.hp
	V2AITacticalAI.take_special_action(caster, ai, grid)
	assert_eq(enemy.hp, before)
	assert_eq(ai.mana, V2StrategicAI.strategic_mana_reserve(ai))

func test_uncommanded_retinue_receives_no_ai_action():
	var data := UnitDatabase.create_unit("v2_unit_skeleton_host")
	var retinue := grid.spawn_unit(Vector2i.ZERO, data, ai)
	var before := retinue.coord
	assert_false(retinue.can_receive_orders())
	assert_true(V2AITacticalAI.take_special_action(retinue, ai, grid))
	assert_eq(retinue.coord, before)
	assert_eq(retinue.movement_left, retinue.unit_data.movement_points)

func test_special_movement_profile_uses_unit_reachable_instead_of_legacy_ground_path():
	_learn_doctrine("rogue", 9)
	var infiltrator := _unit(ai, "v2_legendary_shadow_master", Vector2i.ZERO)
	for coord in [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]:
		_unit(ai, "guard", coord)
	var target_city := grid.found_city(Vector2i(4, 0), human, "Target", true)
	ai.known_enemy_cities[target_city.coord] = true
	ai.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY
	target_city.city_level = 3
	var view := V2AIWorldView.capture(ai, grid)
	assert_true(view.is_enemy_city_visible(target_city))
	assert_true(V2AITacticalAI.take_special_action(infiltrator, ai, grid))
	assert_ne(infiltrator.coord, Vector2i.ZERO)

## Fase 25: o véu de ocultação da magia V1 (que escondia "hidden" deste teste) foi removido junto com ela.
func test_ai_uses_infernal_damage_on_a_visible_target():
	_learn_magic("infernal", 4)
	var caster := _unit(ai, "v2_unit_infernal_warlock", Vector2i.ZERO)
	var visible := _unit(human, "guard", Vector2i(2, 0))
	visible.hp = 5.0
	var visible_before := visible.hp
	assert_true(V2AITacticalAI.take_special_action(caster, ai, grid))
	assert_lt(visible.hp, visible_before)

func test_ai_summons_through_real_command_and_mana_gates():
	_learn_magic("necromancy", 4)
	var caster := _unit(ai, "v2_unit_necromancer", Vector2i.ZERO)
	var before_mana := ai.mana
	assert_true(V2AITacticalAI.take_special_action(caster, ai, grid))
	assert_true(ai.units.any(func(u): return u.unit_data.visual_kind == "v2_unit_skeleton_host"))
	assert_lt(ai.mana, before_mana)
	assert_eq(caster.movement_left, 0.0)

func test_ai_silences_visible_enemy_caster():
	_learn_magic("arcanism", 5)
	var caster := _unit(ai, "v2_unit_arcanist", Vector2i.ZERO)
	var target := _unit(human, "v2_unit_sacred_cleric", Vector2i(2, 0))
	assert_true(V2AITacticalAI.take_special_action(caster, ai, grid))
	assert_true(V2MagicRuntime.is_spellcasting_silenced(target))

func test_ai_dispels_visible_hostile_beneficial_status():
	_learn_magic("arcanism", 6)
	var caster := _unit(ai, "v2_unit_arcanist", Vector2i.ZERO)
	var target := _unit(human, "guard", Vector2i(2, 0))
	target.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2AITacticalAI.take_special_action(caster, ai, grid))
	assert_false(target.magic_status.has("v2_spell_sacred_aegis"))

func test_ai_places_environmental_damage_on_enemy_cluster_without_friendly_fire():
	_learn_magic("elementalism", 6)
	var caster := _unit(ai, "v2_unit_elementalist", Vector2i.ZERO)
	for coord in [Vector2i(2, 0), Vector2i(2, -1), Vector2i(1, 0)]:
		_unit(human, "guard", coord)
	var before_mana := ai.mana
	assert_true(V2AITacticalAI.take_special_action(caster, ai, grid))
	assert_lt(ai.mana, before_mana)
	assert_false(grid.v2_environmental_zones.is_empty())
	assert_true(grid.v2_environmental_zones.keys().any(func(coord): return grid.get_unit_at(coord) != null and grid.get_unit_at(coord).owner_player == human))

func test_ai_uses_city_strike_only_through_the_city_combat_runtime():
	_learn_doctrine("siege", 6)
	var siege := _unit(ai, "v2_unit_catapult", Vector2i.ZERO)
	var city := grid.found_city(Vector2i(2, 0), human, "Target", true)
	var before_hp := city.hp
	assert_true(V2AITacticalAI.take_special_action(siege, ai, grid))
	assert_lt(city.hp, before_hp)
	assert_eq(siege.movement_left, 0.0)
	assert_gt(V2TechniqueRuntime.cooldown_remaining(siege, "v2_technique_prepared_bombardment"), 0)

func test_ai_uses_tactical_retreat_when_wounded_and_adjacent_to_threat():
	_learn_doctrine("cavalry", 6)
	var cavalry := _unit(ai, "v2_unit_cavalier", Vector2i.ZERO)
	cavalry.hp = 2.0
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_unit(human, "guard", coord)
	var retreat := V2DoctrineTechniqueDatabase.get_technique("v2_technique_tactical_retreat")
	assert_true(V2TechniqueRuntime.can_use(cavalry, retreat.id, grid))
	assert_false(V2TechniqueRuntime.relocation_tiles(cavalry, retreat, grid).is_empty())
	var before := cavalry.coord
	assert_true(V2AITacticalAI.take_special_action(cavalry, ai, grid))
	assert_ne(cavalry.coord, before)
	assert_true(V2TechniqueRuntime.is_active(cavalry, "v2_technique_tactical_retreat"))

func test_ai_creates_druid_terrain_at_a_visible_front_instead_of_empty_noise():
	_learn_magic("druidism", 4)
	var druid := _unit(ai, "v2_unit_druid", Vector2i.ZERO)
	_unit(ai, "guard", Vector2i(2, 0))
	_unit(human, "guard", Vector2i(2, -1))
	assert_true(V2AITacticalAI.take_special_action(druid, ai, grid))
	assert_false(grid.v2_terrain_modifications.is_empty())
	var modified: Vector2i = grid.v2_terrain_modifications.keys()[0]
	assert_lte(HexMetrics.axial_distance(modified, Vector2i(2, 0)), 1)
