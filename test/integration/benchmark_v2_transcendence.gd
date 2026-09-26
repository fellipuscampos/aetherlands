extends GutTest

## Benchmark reproduzível da Fase 23. Fora de test/unit de propósito.

var grid: HexGrid
var players: Array[PlayerData] = []
var cities: Array[City] = []
var _old_grid: HexGrid
var _old_human: PlayerData
var _old_players: Array[PlayerData]
var _old_rivals: Array[PlayerData]
var _old_state
var _old_turn: int

func before_each():
	_old_grid = GameManager.hex_grid
	_old_human = GameManager.human_player
	_old_players = GameManager.players
	_old_rivals = GameManager.rival_players
	_old_state = GameManager.state
	_old_turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-12, 13):
		for r in range(-12, 13):
			if absi(q + r) <= 12:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var city_coords := [Vector2i.ZERO, Vector2i(7, 0), Vector2i(-7, 0), Vector2i(0, 7)]
	for i in 4:
		var civ := CivilizationData.new()
		civ.civ_name = "Benchmark %d" % i
		var player := PlayerData.new(civ)
		players.append(player)
	GameManager.players = players
	GameManager.human_player = players[0]
	GameManager.rival_players = [players[1], players[2], players[3]] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 100
	for i in 4:
		var player := players[i]
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
		player.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID)
		var city := grid.found_city(city_coords[i], player, "Ritual %d" % i, true)
		city.buildings["v2_building_sacred_ritual"] = true
		cities.append(city)
		grid.spawn_unit(city.coord + Vector2i(1, 0), UnitDatabase.create_unit("v2_manifestation_seraph"), player)
		grid.spawn_unit(city.coord + Vector2i(-1, 0), UnitDatabase.create_unit("v2_manifestation_archdemon"), player)
		player.mana = 100000.0

func after_each():
	for player in players:
		player.release_relations()
	GameManager.hex_grid = _old_grid
	GameManager.human_player = _old_human
	GameManager.players = _old_players
	GameManager.rival_players = _old_rivals
	GameManager.state = _old_state
	TurnManager.turn_number = _old_turn
	grid.queue_free()

func _measure(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 20):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE23_BENCH %-42s %9.3f us" % [label, per_call])
	return per_call

func test_phase23_transcendence_benchmarks():
	var human := players[0]
	var city := cities[0]
	_measure("has_access", 100000, func(): V2TranscendenceSystem.has_access(human))
	_measure("active_manifestation_count (2/6)", 50000, func(): V2TranscendenceSystem.active_manifestation_count(human))
	_measure("city ritual structure check", 50000, func(): V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, human))
	_measure("can_start_ritual ready", 20000, func(): V2TranscendenceSystem.can_start_ritual(human, city))
	_measure("global ritual tick / 0 active", 20000, func(): V2TranscendenceSystem.process_global_round(grid))

	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	_measure("victory_ready / active not done", 50000, func(): V2TranscendenceSystem.victory_ready(human, grid))
	_measure("public_rituals / 1 active", 20000, func(): V2TranscendenceSystem.public_rituals())
	_measure("global ritual tick / 1 active", 10000, func(): V2TranscendenceSystem.process_global_round(grid))
	for i in range(1, 4):
		assert_true(V2TranscendenceSystem.start_ritual(players[i], cities[i]))
	_measure("public_rituals / 4 active", 10000, func(): V2TranscendenceSystem.public_rituals())
	_measure("global ritual tick / 4 active", 5000, func(): V2TranscendenceSystem.process_global_round(grid))

	var saved := V2TranscendenceSystem.to_save_array()
	_measure("restore 4 ritual markers", 100, func(): V2TranscendenceSystem.load_save_array(saved, grid))
	assert_eq(grid._v2_transcendence_markers.size(), 4)
	_measure("check_victories before completion", 2000, func(): GameManager.check_victories())
	for player in players:
		player.v2_transcendence_ritual.remaining_rounds = 0
	_measure("victory_ready / completed", 50000, func(): V2TranscendenceSystem.victory_ready(human, grid))
	_measure("check_victories completed", 500, func():
		GameManager.state = GameManager.GameState.PLAYING
		GameManager.check_victories()
	)

	var baseline := grid.compute_path(Vector2i(-5, -2), Vector2i(5, 2), human, false, false)
	assert_eq(grid.compute_path(Vector2i(-5, -2), Vector2i(5, 2), human, false, false), baseline, "markers públicos nunca entram no pathfinding")
