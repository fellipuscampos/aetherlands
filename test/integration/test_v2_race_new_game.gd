extends GutTest

## Fase 26: smoke isolado do ciclo real de nova partida para cada raça jogável.
## Fora da suíte unitária para manter a validação de integração explícita e reproduzível.

const RACES: Array[String] = ["human", "elf", "dwarf", "orc"]
const MAP_SIZE := 41

var original := {}


func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "human_kingdom_name", "debug_mode"]:
		original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	original.player_index = TurnManager.current_player_index
	original.events = WorldEventManager.active_events.duplicate()
	original.event_id = WorldEventManager._next_event_id
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0


func after_each():
	V2AITacticalAI.clear_views()
	GameManager.end_match()
	for key in original:
		if key not in ["turn", "player_index", "events", "event_id"]:
			GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	TurnManager.current_player_index = original.player_index
	WorldEventManager.active_events.assign(original.events)
	WorldEventManager._next_event_id = original.event_id


func test_each_playable_race_starts_founds_and_processes_real_turns():
	for race_index in RACES.size():
		var race_id := RACES[race_index]
		var grid := HexGrid.new()
		add_child(grid)
		GameManager.map_width = MAP_SIZE
		GameManager.map_height = MAP_SIZE
		GameManager.rival_count = 1
		GameManager.human_race = race_id
		GameManager.human_kingdom_name = ""
		grid.generate_map(MAP_SIZE, MAP_SIZE, 260260 + race_index)
		GameManager.start_new_game(grid)

		assert_eq(GameManager.human_player.civ.race, race_id)
		assert_not_null(V2RaceBonusRuntime.profile_for(GameManager.human_player), race_id)
		assert_eq(V2RaceBonusRuntime.effect_lines(GameManager.human_player).size(), 2, race_id)
		var settlers := GameManager.human_player.units.filter(func(unit): return unit.unit_data.can_found_city)
		assert_eq(settlers.size(), 1, "%s inicia com um fundador" % race_id)
		assert_not_null(WorldSetup.found_city_from_settler(grid, settlers[0]), "%s funda a capital" % race_id)
		assert_eq(GameManager.human_player.cities.size(), 1, race_id)
		_assert_declared_axes_are_effective(race_id, GameManager.human_player)

		for turn in range(3):
			TurnManager.end_turn()
			assert_eq(GameManager.state, GameManager.GameState.PLAYING, "%s continua jogável no turno %d" % [race_id, turn + 1])
			assert_true(is_finite(GameManager.human_player.gold), race_id)
			assert_true(is_finite(GameManager.human_player.mana), race_id)

		GameManager.end_match()
		grid.queue_free()
		await get_tree().process_frame


func _assert_declared_axes_are_effective(race_id: String, player: PlayerData) -> void:
	var city: City = player.cities[0]
	match race_id:
		"human":
			assert_eq(V2ConstructorRuntime.charges_for_new_builder(player), V2EconomyRuntime.infrastructure_tier(player, "industry") + 1)
			assert_eq(V2RaceBonusRuntime.annexation_point_bonus(player), 1)
		"elf":
			assert_almost_eq(V2EconomyRuntime.city_knowledge_income(city), V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY * 1.1, 0.0001)
			assert_almost_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY * 1.1, 0.0001)
		"dwarf":
			var gold := V2EconomyRuntime.city_income_breakdown(city, "gold")
			var production := V2EconomyRuntime.city_income_breakdown(city, "production")
			assert_almost_eq(gold.total, gold.pre_racial_total * 1.1, 0.0001)
			assert_almost_eq(production.total, production.pre_racial_total * 1.1, 0.0001)
		"orc":
			var supply := V2EconomyRuntime.city_income_breakdown(city, "supply")
			assert_almost_eq(supply.total, supply.pre_racial_total * 1.1, 0.0001)
			assert_almost_eq(V2RaceBonusRuntime.combat_attack_multiplier(player.units[0]), 1.05, 0.0001)
