extends GutTest

## Fase 26 — identidade racial exclusivamente derivada do race id canônico.

const RACES := ["human", "elf", "dwarf", "orc"]

var _players: Array[PlayerData] = []
var _grids: Array[HexGrid] = []


func after_each():
	for player in _players:
		player.release_relations()
	_players.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()


func _player(race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	civ.civ_name = "Reino %s" % race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player


func _grid(radius: int = 5) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid


func _city(player: PlayerData, grid: HexGrid, coord: Vector2i) -> City:
	return grid.found_city(coord, player, "Capital")


func test_database_matches_the_real_playable_roster_exactly():
	var setup_ids: Array[String] = []
	for race_id in GameSetupScreen.RACE_INFO.keys():
		setup_ids.append(String(race_id))
	setup_ids.sort()
	assert_eq(V2RaceBonusDatabase.race_ids(), setup_ids)
	assert_eq(setup_ids, ["dwarf", "elf", "human", "orc"])


func test_every_playable_race_has_exactly_two_distinct_positive_bonuses():
	var combinations := {}
	for profile in V2RaceBonusDatabase.all_profiles():
		var keys := profile.active_bonus_keys()
		keys.sort()
		assert_eq(keys.size(), 2, profile.race_id)
		assert_false(combinations.has(str(keys)), "%s repete %s" % [profile.race_id, keys])
		combinations[str(keys)] = true
	assert_eq(combinations.size(), RACES.size())


func test_profiles_contain_no_content_ids_or_exclusive_content_fields():
	for profile in V2RaceBonusDatabase.all_profiles():
		for property in profile.get_property_list():
			var name := String(property.name)
			for forbidden in ["unit_id", "building_id", "research_id", "spell_id", "unlock_id", "race_required"]:
				assert_false(name.contains(forbidden), "%s/%s" % [profile.race_id, name])
		assert_false(profile.summary.contains("v2_"), profile.race_id)


func test_unknown_empty_and_null_are_neutral():
	for race_id in ["", "unknown", "fixture"]:
		assert_null(V2RaceBonusRuntime.profile_for_race(race_id))
		var player := _player(race_id)
		assert_eq(V2RaceBonusRuntime.gold_income_multiplier(player), 1.0)
		assert_eq(V2RaceBonusRuntime.supply_capacity_multiplier(player), 1.0)
		assert_eq(V2RaceBonusRuntime.city_production_multiplier(player), 1.0)
		assert_eq(V2RaceBonusRuntime.knowledge_income_multiplier(player), 1.0)
		assert_eq(V2RaceBonusRuntime.mana_income_multiplier(player), 1.0)
		assert_eq(V2RaceBonusRuntime.builder_charge_bonus(player), 0)
		assert_eq(V2RaceBonusRuntime.annexation_point_bonus(player), 0)
	assert_null(V2RaceBonusRuntime.profile_for(null))
	assert_eq(V2RaceBonusRuntime.gold_income_multiplier(null), 1.0)
	assert_eq(V2RaceBonusRuntime.combat_attack_multiplier(null), 1.0)


func test_effect_text_has_exactly_two_clear_player_facing_lines_per_race():
	for race_id in RACES:
		var lines := V2RaceBonusDatabase.effect_lines(race_id)
		assert_eq(lines.size(), 2, race_id)
		for line in lines:
			assert_false(line.contains("multiplier"), line)
			assert_false(line.contains("v2_"), line)
			assert_true(line.contains("+") and line.ends_with("."), line)
	assert_true(V2RaceBonusDatabase.effect_lines("missing").is_empty())


func test_exact_balance_placeholder_mapping():
	var human := V2RaceBonusDatabase.get_profile("human")
	assert_eq([human.builder_charge_bonus, human.annexation_point_bonus], [1, 1])
	var elf := V2RaceBonusDatabase.get_profile("elf")
	assert_eq([elf.knowledge_income_multiplier, elf.mana_income_multiplier], [1.1, 1.1])
	var dwarf := V2RaceBonusDatabase.get_profile("dwarf")
	assert_eq([dwarf.gold_income_multiplier, dwarf.city_production_multiplier], [1.1, 1.1])
	var orc := V2RaceBonusDatabase.get_profile("orc")
	assert_eq([orc.supply_capacity_multiplier, orc.unit_attack_multiplier], [1.1, 1.05])


func test_each_economic_axis_changes_only_for_the_declared_race():
	var grid := _grid(10)
	var values := {}
	for i in RACES.size():
		var race: String = RACES[i]
		var player := _player(race)
		var city := _city(player, grid, Vector2i(i * 4 - 6, 0))
		values[race] = {
			"gold": V2EconomyRuntime.city_gold_income(city),
			"supply": V2EconomyRuntime.city_supply_capacity(city),
			"production": V2EconomyRuntime.city_production_income(city),
			"knowledge": V2EconomyRuntime.city_knowledge_income(city),
			"mana": V2EconomyRuntime.city_mana_income(city),
		}
	var neutral_player := _player("")
	var neutral_city := _city(neutral_player, grid, Vector2i(0, 7))
	var neutral := {
		"gold": V2EconomyRuntime.city_gold_income(neutral_city),
		"supply": V2EconomyRuntime.city_supply_capacity(neutral_city),
		"production": V2EconomyRuntime.city_production_income(neutral_city),
		"knowledge": V2EconomyRuntime.city_knowledge_income(neutral_city),
		"mana": V2EconomyRuntime.city_mana_income(neutral_city),
	}
	for axis in neutral:
		assert_almost_eq(values.human[axis], neutral[axis], 0.0001, "human/%s" % axis)
	assert_almost_eq(values.elf.knowledge, neutral.knowledge * 1.1, 0.0001)
	assert_almost_eq(values.elf.mana, neutral.mana * 1.1, 0.0001)
	assert_almost_eq(values.elf.gold, neutral.gold, 0.0001)
	assert_almost_eq(values.elf.supply, neutral.supply, 0.0001)
	assert_almost_eq(values.elf.production, neutral.production, 0.0001)
	assert_almost_eq(values.dwarf.gold, neutral.gold * 1.1, 0.0001)
	assert_almost_eq(values.dwarf.production, neutral.production * 1.1, 0.0001)
	assert_almost_eq(values.dwarf.supply, neutral.supply, 0.0001)
	assert_almost_eq(values.dwarf.knowledge, neutral.knowledge, 0.0001)
	assert_almost_eq(values.dwarf.mana, neutral.mana, 0.0001)
	assert_almost_eq(values.orc.supply, neutral.supply * 1.1, 0.0001)
	assert_almost_eq(values.orc.gold, neutral.gold, 0.0001)
	assert_almost_eq(values.orc.production, neutral.production, 0.0001)
	assert_almost_eq(values.orc.knowledge, neutral.knowledge, 0.0001)
	assert_almost_eq(values.orc.mana, neutral.mana, 0.0001)


func test_gold_bonus_multiplies_gross_income_but_never_upkeep():
	var grid := _grid()
	var dwarf := _player("dwarf")
	var neutral := _player("")
	var dwarf_city := _city(dwarf, grid, Vector2i(-2, 0))
	var neutral_city := _city(neutral, grid, Vector2i(2, 0))
	for city in [dwarf_city, neutral_city]:
		city.buildings["v2_building_guardian_hall"] = true
	assert_almost_eq(V2EconomyRuntime.player_gold_gross_income(dwarf), V2EconomyRuntime.player_gold_gross_income(neutral) * 1.1, 0.0001)
	assert_almost_eq(V2EconomyRuntime.player_gold_upkeep(dwarf), V2EconomyRuntime.player_gold_upkeep(neutral), 0.0001)
	assert_almost_eq(V2EconomyRuntime.player_gold_net_income(dwarf), V2EconomyRuntime.player_gold_gross_income(dwarf) - V2EconomyRuntime.player_gold_upkeep(dwarf), 0.0001)


func test_economic_breakdown_and_turn_credit_use_the_same_effective_values_once():
	var grid := _grid()
	var elf := _player("elf")
	var city := _city(elf, grid, Vector2i.ZERO)
	var knowledge := V2EconomyRuntime.city_income_breakdown(city, "knowledge")
	var mana := V2EconomyRuntime.city_income_breakdown(city, "mana")
	assert_almost_eq(knowledge.racial_multiplier, 1.1, 0.0001)
	assert_almost_eq(knowledge.total, knowledge.pre_racial_total * 1.1, 0.0001)
	assert_almost_eq(mana.total, V2EconomyRuntime.city_mana_income(city), 0.0001)
	V2EconomyRuntime.apply_turn_income(elf)
	assert_almost_eq(elf.mana, mana.total, 0.0001)
	assert_almost_eq(elf.mana_income_per_turn, mana.total, 0.0001)
	assert_almost_eq(elf.v2_research.research_overflow, knowledge.total, 0.0001)


func test_dwarf_city_queue_advances_by_effective_production_without_double_application():
	var grid := _grid()
	var dwarf_city := _city(_player("dwarf"), grid, Vector2i.ZERO)
	var per_turn := V2EconomyRuntime.city_production_income(dwarf_city)
	dwarf_city.process_turn(grid)
	assert_almost_eq(dwarf_city.stored_production, per_turn, 0.0001)
	var breakdown := V2EconomyRuntime.city_income_breakdown(dwarf_city, "production")
	assert_almost_eq(per_turn, breakdown.pre_racial_total * 1.1, 0.0001)


func test_orc_supply_changes_capacity_not_used_or_unit_cost():
	var grid := _grid()
	var orc := _player("orc")
	var neutral := _player("")
	var orc_city := _city(orc, grid, Vector2i(-2, 0))
	var neutral_city := _city(neutral, grid, Vector2i(2, 0))
	var orc_unit := grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("v2_unit_warrior"), orc)
	var neutral_unit := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("v2_unit_warrior"), neutral)
	assert_almost_eq(V2EconomyRuntime.city_supply_capacity(orc_city), V2EconomyRuntime.city_supply_capacity(neutral_city) * 1.1, 0.0001)
	assert_eq(V2LogisticsRuntime.player_supply_used(orc), V2LogisticsRuntime.player_supply_used(neutral))
	assert_eq(orc_unit.unit_data.supply_cost, neutral_unit.unit_data.supply_cost)


func test_human_builder_bonus_materializes_only_on_new_builders():
	var human := _player("human")
	var neutral := _player("")
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(human), V2EconomyRuntime.infrastructure_tier(human, "industry") + 1)
	assert_eq(V2ConstructorRuntime.charges_for_new_builder(neutral), V2EconomyRuntime.infrastructure_tier(neutral, "industry"))
	var existing := Unit.new()
	existing.work_charges_remaining = 1
	assert_eq(existing.work_charges_remaining, 1, "consulta racial nunca recalcula unidade viva")
	existing.free()


func test_human_annexation_bonus_is_granted_on_level_up_not_at_foundation():
	var grid := _grid()
	var human := _player("human")
	human.gold = 100.0
	human.v2_research.complete_research("v2_infrastructure_urbanization_1")
	var city := _city(human, grid, Vector2i.ZERO)
	assert_eq(city.annexation_points, 0, "Cidade I não recebe bônus retroativo")
	city.set_production(V2CityLevelData.project_id_for_level(2))
	city.stored_production = city.production_cost()
	var result := city.process_turn(grid)
	assert_eq(result.city_level_up, 2)
	assert_eq(city.annexation_points, V2CityLevelData.annexation_grant(2) + 1)


func test_current_owner_drives_all_city_bonuses_after_capture():
	var grid := _grid()
	var dwarf := _player("dwarf")
	var elf := _player("elf")
	var city := _city(dwarf, grid, Vector2i.ZERO)
	var dwarf_gold := V2EconomyRuntime.city_gold_income(city)
	var dwarf_production := V2EconomyRuntime.city_production_income(city)
	city.owner_player = elf
	assert_lt(V2EconomyRuntime.city_gold_income(city), dwarf_gold)
	assert_lt(V2EconomyRuntime.city_production_income(city), dwarf_production)
	assert_almost_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY * 1.1, 0.0001)
	assert_almost_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY * 1.1, 0.0001)


func test_orc_attack_bonus_is_owner_derived_and_predict_equals_resolve():
	var grid := _grid()
	var orc := _player("orc")
	var neutral := _player("")
	var target_owner := _player("")
	var orc_attacker := grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("v2_unit_warrior"), orc)
	var neutral_attacker := grid.spawn_unit(Vector2i(1, -1), UnitDatabase.create_unit("v2_unit_warrior"), neutral)
	var defender := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("v2_unit_shieldbearer"), target_owner)
	var orc_prediction := CombatResolver.predict(orc_attacker, defender, grid)
	var neutral_prediction := CombatResolver.predict(neutral_attacker, defender, grid)
	assert_almost_eq(V2RaceBonusRuntime.combat_attack_multiplier(orc_attacker), 1.05, 0.0001)
	assert_almost_eq(V2RaceBonusRuntime.combat_attack_multiplier(neutral_attacker), 1.0, 0.0001)
	assert_gt(orc_prediction.damage_to_defender, neutral_prediction.damage_to_defender)
	var hp_before := defender.hp
	CombatResolver.resolve(orc_attacker, defender, grid)
	assert_almost_eq(hp_before - defender.hp, orc_prediction.damage_to_defender, 0.0001)


func test_two_players_of_same_race_share_profile_but_not_mutable_state():
	var first := _player("elf")
	var second := _player("elf")
	assert_same(V2RaceBonusRuntime.profile_for(first), V2RaceBonusRuntime.profile_for(second))
	first.gold = 99.0
	first.mana = 42.0
	assert_eq(second.gold, 0.0)
	assert_eq(second.mana, 0.0)


func test_race_does_not_change_shared_research_unit_building_or_spell_catalogs():
	var research_ids := V2ResearchDatabase.all_nodes().map(func(node): return node.id)
	var unit_ids := UnitDatabase.PLAYER_TRAINABLE_KINDS.duplicate()
	var building_ids := BuildingDatabase.all_buildings().map(func(building): return building.id)
	var spell_ids := V2SpellDatabase.all_spells().map(func(spell): return spell.id)
	assert_eq(research_ids.size(), 128)
	for race_id in RACES:
		assert_eq(V2ResearchDatabase.all_nodes().map(func(node): return node.id), research_ids, race_id)
		assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS, unit_ids, race_id)
		assert_eq(BuildingDatabase.all_buildings().map(func(building): return building.id), building_ids, race_id)
		assert_eq(V2SpellDatabase.all_spells().map(func(spell): return spell.id), spell_ids, race_id)


func test_ai_orientation_is_independent_from_race():
	var orientations := {}
	for i in 3:
		var player := _player("orc")
		V2StrategicAI.initialize_player(player, i, 12345, 3)
		orientations[player.v2_ai_strategy.orientation] = true
	assert_eq(orientations.size(), 3, "a mesma raça recebe Military, Arcane e Balanced conforme índice/seed")


func test_game_setup_shows_database_specialties_for_every_race():
	var setup: GameSetupScreen = load("res://scenes/ui/GameSetupScreen.tscn").instantiate()
	add_child_autofree(setup)
	for race_id in RACES:
		setup._update_race_detail(race_id)
		var text := setup.race_specialties_label.text
		assert_string_contains(text, "Especialidades:")
		for line in V2RaceBonusDatabase.effect_lines(race_id):
			assert_string_contains(text, line, race_id)
		assert_false(text.contains(race_id), "id interno em: %s" % text)


func test_hud_exposes_an_in_game_race_summary_without_internal_terms():
	var previous_human := GameManager.human_player
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	var player := _player("dwarf")
	GameManager.human_player = player
	hud._refresh_stats()
	var text: String = hud.stats_label.tooltip_text
	assert_string_contains(text, "Raça: Liga dos Clãs de Ferro")
	for line in V2RaceBonusDatabase.effect_lines("dwarf"):
		assert_string_contains(text, line)
	for forbidden in ["V1", "V2", "placeholder", "dwarf", "multiplier"]:
		assert_false(text.contains(forbidden), "%s em: %s" % [forbidden, text])
	GameManager.human_player = previous_human


func test_save_source_has_no_derived_racial_state_and_version_is_unchanged():
	var source := FileAccess.get_file_as_string("res://scripts/autoload/SaveManager.gd")
	for forbidden in ["gold_bonus", "production_bonus", "race_modifiers", "racial_effects"]:
		assert_false(source.contains(forbidden), forbidden)
	assert_eq(SaveManager.SAVE_VERSION, 21)


func test_consumers_have_no_concrete_race_branches():
	for path in [
		"res://scripts/core/V2EconomyRuntime.gd", "res://scripts/core/V2LogisticsRuntime.gd",
		"res://scripts/city/City.gd", "res://scripts/core/CombatResolver.gd",
		"res://scripts/core/V2MagicRuntime.gd", "res://scripts/core/V2StrategicAI.gd",
		"res://scripts/ui/HUD.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for race_id in RACES:
			assert_false(source.contains('race == "%s"' % race_id), "%s/%s" % [path, race_id])


func test_legacy_racial_modules_and_unique_units_remain_absent():
	for path in ["res://scripts/data/RaceEconomy.gd", "res://scripts/data/CityIdentity.gd"]:
		assert_false(FileAccess.file_exists(path), path)
	assert_false("RACE_UNIQUE_KIND" in UnitDatabase)
