extends GutTest

## Benchmark reproduzível da Fase 24. Fora de test/unit de propósito.

var grid: HexGrid
var players: Array[PlayerData] = []
var old := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state"]:
		old[key] = GameManager.get(key)
	old.turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-15, 16):
		for r in range(-15, 16):
			if absi(q + r) <= 15:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for i in 4:
		var civ := CivilizationData.new()
		civ.civ_name = "AI benchmark %d" % i
		players.append(PlayerData.new(civ))
	GameManager.players = players
	GameManager.human_player = players[0]
	GameManager.rival_players = [players[1], players[2], players[3]] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 50
	var coords := [Vector2i(-9, 0), Vector2i.ZERO, Vector2i(9, 0), Vector2i(0, 9)]
	for i in 4:
		grid.found_city(coords[i], players[i], "Cidade %d" % i, true)
		grid.spawn_unit(coords[i] + Vector2i(1, 0), UnitDatabase.create_unit("guard"), players[i])
	for i in 3:
		V2StrategicAI.initialize_player(players[i + 1], i, grid.map_seed, 3)
	Diplomacy.declare_war(players[1], players[0])
	# Uma frente visível de 12 peças exercita observação e pressão sem
	# conceder à IA qualquer estado privado do adversário.
	for i in 12:
		var coord := Vector2i(-4 + i % 4, -4 + i / 4)
		grid.spawn_unit(coord, UnitDatabase.create_unit("cavalry" if i % 2 == 0 else "mage"), players[0])

func after_each():
	V2AITacticalAI.clear_views()
	for player in players:
		player.release_relations()
	GameManager.players = old.players
	GameManager.rival_players = old.rival_players
	GameManager.human_player = old.human_player
	GameManager.hex_grid = old.hex_grid
	GameManager.state = old.state
	TurnManager.turn_number = old.turn
	grid.queue_free()

func _measure(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 10):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE24_BENCH %-44s %10.3f us" % [label, per_call])
	return per_call

func test_phase24_ai_benchmarks():
	var rival := players[1]
	var view := V2AIWorldView.capture(rival, grid)
	assert_gt(view.visible_enemy_units.size(), 0)
	_measure("WorldView capture / 12 visible enemies", 500, func(): V2AIWorldView.capture(rival, grid))
	_measure("research scoring / all 128 nodes", 500, func():
		for node in V2ResearchDatabase.all_nodes():
			V2StrategicAI.research_score(rival, node)
	)
	_measure("strategic target / public view", 5000, func(): V2StrategicAI.strategic_target_coord(rival, view))
	_measure("tactical no-op / one ordinary unit", 500, func():
		var unit: Unit = rival.units[0]
		unit.movement_left = unit.unit_data.movement_points
		V2AITacticalAI.take_special_action(unit, rival, grid)
	)
	_measure("one rival strategic plan", 100, func():
		TurnManager.turn_number += 1
		V2StrategicAI.plan_turn(rival, grid)
	)
	_measure("three rival strategic plans", 50, func():
		TurnManager.turn_number += 1
		for ai in GameManager.rival_players:
			V2StrategicAI.plan_turn(ai, grid)
	)
	assert_lte(V2StrategicAI.relevant_unit_count(rival), V2AITuning.HARD_TOKEN_CAP)
