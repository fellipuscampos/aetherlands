extends GutTest

## Fase 33D1 — correções fundamentais antes das ameaças regionais:
## #1 fila de cidade capturada revalidada para o novo dono; #2 distância mínima entre capitais;
## #3 Dragão ONCE_PER_GAME; #4 IA só conhece covis descobertos; #5 nome player-facing de evento mundial.

const SHIELDBEARER := "v2_unit_shieldbearer"
const GUARDIAN_HALL := "v2_building_guardian_hall"
const GUARDIAN_MASTERY := "v2_building_guardian_mastery"
const CHAMPION := "v2_legendary_guardian_champion"
const SACRED_RITUAL := "v2_building_sacred_ritual"
const SERAPH := "v2_manifestation_seraph"
const MARKET := "v2_building_market"
const SMALL_MAP := 61

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false

func after_each():
	V2AITacticalAI.clear_views()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)

# --- Fixture manual ------------------------------------------------------------------------------

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

func _manual_world() -> void:
	grid = HexGrid.new()
	grid._ready()
	for q in range(-12, 13):
		for r in range(-12, 13):
			if absi(q + r) <= 12:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Conquistador")
	rival = _player("Defensor")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 60
	grid.found_city(Vector2i(-8, 0), human, "Base", true)

func _rival_city_producing(item: String, stored: float) -> City:
	var city := grid.found_city(Vector2i(4, 0), rival, "Alvo", true)
	city.production_item = item
	city.stored_production = stored
	return city

func _research_to_tier(player: PlayerData, tree: int, branch: String, tier: int) -> void:
	for node in V2ResearchDatabase.nodes_for_branch(tree, branch):
		if node.tier <= tier:
			assert_true(player.v2_research.complete_research(node.id), "pesquisa %s" % node.id)

# --- Bug #1: fila da cidade capturada --------------------------------------------------------------

func test_captured_unit_the_new_owner_researched_keeps_production():
	_manual_world()
	for player in [human, rival]:
		_research_to_tier(player, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian", 3)
	var city := _rival_city_producing(SHIELDBEARER, 12.0)
	city.buildings[GUARDIAN_HALL] = true
	grid.capture_city(city, human)
	assert_eq(city.owner_player, human)
	assert_eq(city.production_item, SHIELDBEARER, "item legítimo continua")
	assert_eq(city.stored_production, 12.0, "progresso preservado, nada cobrado de novo")

func test_captured_unit_the_new_owner_never_researched_is_cleared():
	_manual_world()
	_research_to_tier(rival, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian", 3)
	var city := _rival_city_producing(SHIELDBEARER, 15.0)
	city.buildings[GUARDIAN_HALL] = true
	assert_eq(human.v2_research.completed_ids.size(), 0)
	grid.capture_city(city, human)
	assert_eq(city.production_item, "", "unidade não pesquisada pelo novo dono não continua")
	assert_eq(city.stored_production, 0.0, "PP do item ilegítimo não viram banco")

func test_captured_valid_building_continues_and_invalid_building_is_cleared():
	_manual_world()
	var market_node := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, "economy")[0]
	assert_true(rival.v2_research.complete_research(market_node.id))
	var city := _rival_city_producing(MARKET, 9.0)
	city.pending_building_coord = Vector2i(5, 0)
	grid.capture_city(city, human)
	assert_eq(city.production_item, "", "Mercado sem a pesquisa do novo dono é limpo")
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD, "reserva de tile liberada")
	# Mesmo prédio, agora com o novo dono também tendo a pesquisa: continua.
	assert_true(human.v2_research.complete_research(market_node.id))
	var second := grid.found_city(Vector2i(8, -4), rival, "Segunda", true)
	second.production_item = MARKET
	second.stored_production = 7.0
	second.pending_building_coord = Vector2i(9, -4)
	grid.capture_city(second, human)
	assert_eq(second.production_item, MARKET, "prédio legítimo continua")
	assert_eq(second.stored_production, 7.0)
	assert_eq(second.pending_building_coord, Vector2i(9, -4))

func test_captured_legendary_is_cleared_when_the_new_owner_slot_is_taken():
	_manual_world()
	for player in [human, rival]:
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	grid.spawn_unit(Vector2i(-8, 1), UnitDatabase.create_unit(CHAMPION), human)
	assert_true(V2LegendarySystem.has_active_legendary(human))
	var city := _rival_city_producing(CHAMPION, 40.0)
	city.buildings[GUARDIAN_MASTERY] = true
	grid.capture_city(city, human)
	assert_eq(city.production_item, "", "slot Lendário do novo dono já ocupado")
	assert_eq(city.stored_production, 0.0)

func test_captured_manifestation_is_cleared_when_the_school_slot_is_taken():
	_manual_world()
	for player in [human, rival]:
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	grid.spawn_unit(Vector2i(-8, 1), UnitDatabase.create_unit(SERAPH), human)
	var city := _rival_city_producing(SERAPH, 60.0)
	city.buildings[SACRED_RITUAL] = true
	grid.capture_city(city, human)
	assert_eq(city.production_item, "", "slot da Escola do novo dono já ocupado")
	assert_eq(city.stored_production, 0.0)

func test_cleared_production_never_transfers_to_the_next_choice():
	_manual_world()
	_research_to_tier(rival, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian", 3)
	var city := _rival_city_producing(SHIELDBEARER, 18.0)
	city.buildings[GUARDIAN_HALL] = true
	grid.capture_city(city, human)
	var market_node := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, "economy")[0]
	assert_true(human.v2_research.complete_research(market_node.id))
	city.set_production(MARKET)
	assert_eq(city.stored_production, 0.0, "nova escolha começa do zero")

func test_capture_revalidation_survives_save_and_load():
	var config := BalanceSeedSet.match_config(2, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	grid = BalanceMatchRunner.setup_match(self, config)
	var attacker: PlayerData = GameManager.players[0]
	var defender: PlayerData = GameManager.players[1]
	_research_to_tier(defender, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian", 3)
	var invalid_city: City = defender.cities[0]
	invalid_city.buildings[GUARDIAN_HALL] = true
	invalid_city.production_item = SHIELDBEARER
	invalid_city.stored_production = 11.0
	grid.capture_city(invalid_city, attacker)
	var coord := invalid_city.coord
	assert_eq(invalid_city.production_item, "")
	var path := "user://test_phase33d1_capture.json"
	assert_true(SaveManager.save_game(grid, path))
	assert_true(SaveManager.load_game(grid, path))
	SaveManager.delete_save(path)
	var loaded := grid.get_city_at(coord)
	assert_not_null(loaded)
	assert_eq(loaded.owner_player, GameManager.players[0], "dono preservado")
	assert_eq(loaded.production_item, "", "fila limpa continua limpa após o load")
	assert_eq(loaded.stored_production, 0.0)
	await BalanceMatchRunner.teardown_match(self, grid)
	grid = null

# --- Bug #2: distância mínima entre capitais -----------------------------------------------------

func test_start_tiles_keep_minimum_distance_even_when_origins_touch():
	_manual_world()
	var accepted: Array[Vector2i] = []
	for origin in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		var start := WorldSetup.find_start_tile(grid, origin, accepted)
		for other in accepted:
			assert_gte(HexMetrics.axial_distance(start, other), WorldSetup.MIN_CAPITAL_DISTANCE, "capitais a >= 12 tiles")
		accepted.append(start)

func test_impossible_distance_is_reported_not_silent():
	grid = HexGrid.new()
	grid._ready()
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var before := WorldSetup.start_distance_violations
	var first := WorldSetup.find_start_tile(grid, Vector2i.ZERO, [])
	var second := WorldSetup.find_start_tile(grid, Vector2i.ZERO, [first] as Array[Vector2i])
	assert_ne(first, second, "nunca o mesmo tile")
	assert_eq(WorldSetup.start_distance_violations, before + 1, "mapa pequeno demais é contabilizado, não silencioso")

func test_real_worlds_respect_minimum_distance_and_are_deterministic():
	# Seed da F33B-004 (índice 3), onde os assentos 0 e 2 nasciam a 1 tile, e a F33B-001.
	for index in [3, 0]:
		var config := BalanceSeedSet.match_config(index, 8)
		var violations := WorldSetup.start_distance_violations
		var first: Array[Vector2i] = await _capitals_for(config)
		var second: Array[Vector2i] = await _capitals_for(config)
		assert_eq(first, second, "mesma seed, mesmas capitais (%s)" % config.match_id)
		assert_eq(WorldSetup.start_distance_violations, violations, "nenhuma violação no mapa real")
		for a in first.size():
			for b in range(a + 1, first.size()):
				assert_gte(HexMetrics.axial_distance(first[a], first[b]), WorldSetup.MIN_CAPITAL_DISTANCE, "%s assentos %d/%d" % [config.match_id, a, b])

func _capitals_for(config: Dictionary) -> Array[Vector2i]:
	var world := BalanceMatchRunner.setup_match(self, config)
	var result: Array[Vector2i] = []
	for player in GameManager.players:
		result.append(player.cities[0].coord)
	await BalanceMatchRunner.teardown_match(self, world)
	return result

# --- Bug #3: Dragão uma vez por partida ----------------------------------------------------------

func test_resolved_dragon_never_spawns_again_even_after_save_and_load():
	_manual_world()
	WorldEventManager.reset_for_new_match(60)
	var dragon := DragonEvent.new()
	WorldEventManager.register_event(dragon)
	dragon.phase = WorldEvent.PHASE_RESOLUTION
	dragon.result = {"outcome": "defeated"}
	WorldEventManager.advance_turn(grid, GameManager.players)
	assert_true(WorldEventManager.active_events.is_empty(), "Dragão concluído e removido")
	assert_eq(int(WorldEventManager.completed_event_types.get(DragonEvent.EVENT_TYPE, 0)), 1)
	var triggers := 0
	for turn in range(WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN, 600):
		if WorldEventTrigger.should_spawn_dragon(grid.map_seed, turn):
			triggers += 1
		WorldEventManager.maybe_spawn_dragon(grid, turn)
	assert_gt(triggers, 0, "o gatilho real disparou dezenas de vezes")
	assert_true(WorldEventManager.active_events.is_empty(), "nenhum segundo Dragão")
	var saved := WorldEventManager.to_save_dict()
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(JSON.parse_string(JSON.stringify(saved)))
	for turn in range(WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN, 600):
		WorldEventManager.maybe_spawn_dragon(grid, turn)
	assert_true(WorldEventManager.active_events.is_empty(), "nenhum segundo Dragão depois do load")
	WorldEventManager.reset_for_new_match()
	assert_true(WorldEventManager.can_start_event_type(DragonEvent.EVENT_TYPE), "partida nova volta a permitir o Dragão")

func test_old_save_without_completion_state_defaults_to_not_completed():
	_manual_world()
	WorldEventManager.from_save_dict({"next_event_id": 3, "events": []})
	assert_eq(WorldEventManager.completed_event_types, {}, "sem inferência frágil")
	assert_true(WorldEventManager.can_start_event_type(DragonEvent.EVENT_TYPE))

# --- Bug #4: conhecimento de covis da IA ---------------------------------------------------------

func test_ai_only_knows_lairs_it_has_discovered():
	_manual_world()
	var lair := Vector2i(10, -10)
	grid.lair_coords.append(lair)
	grid.lair_kind_by_coord[lair] = "troll"
	rival.explored_tiles.clear()
	var probe := Vector2i(9, -9)
	var view := V2AIWorldView.capture(rival, grid)
	assert_false(view.is_lair_known(lair), "covil escondido não entra na visão da IA")
	assert_eq(grid.get_lair_danger_at(probe, rival.explored_tiles), 0.0, "exploração não pesa o que não conhece")
	rival.explored_tiles[lair] = true
	view = V2AIWorldView.capture(rival, grid)
	assert_true(view.is_lair_known(lair), "covil explorado passa a ser conhecido")
	assert_eq(String(view.known_lairs[0].kind), "troll")
	assert_gt(view.known_lair_danger_at(probe), 0.0, "perigo conhecido derivado do tipo")
	grid.destroy_lair(lair)
	view = V2AIWorldView.capture(rival, grid)
	assert_false(view.is_lair_known(lair), "covil destruído sai do conhecimento")
	assert_eq(grid.get_lair_danger_at(probe, rival.explored_tiles), 0.0)

# --- Bug #5: nome player-facing ------------------------------------------------------------------

func test_world_events_use_player_facing_names_in_the_event_center():
	_manual_world()
	WorldEventManager.reset_for_new_match(60)
	# Captura pelo sinal (o histórico do Event Center tem teto e pode estar cheio na suíte completa).
	var published: Array = []
	var collect := func(event: UIEventData): published.append(event)
	UIEvents.event_published.connect(collect)
	WorldEventManager.register_event(DragonEvent.new())
	UIEvents.event_published.disconnect(collect)
	var announced := published.filter(func(e): return e.event_type == "world_event_announced")
	assert_eq(announced.size(), 1)
	var text: String = announced[0].title + " " + announced[0].message
	assert_eq(announced[0].title, "O Dragão desperta")
	for forbidden in ["WorldEvent", "DragonEvent", "RefCounted", ".gd", "dragon"]:
		assert_false(text.contains(forbidden), "sem nome interno: %s" % forbidden)
	assert_eq(WorldEvent.new().display_name(), "Evento mundial", "base genérica também é player-facing")
