extends Node

## CPU do planejamento, sem animação, neblina/render ou IA. Baseline reproduz somente a seleção anterior
## de 24 candidatos. Uma rota vazia do baseline em caso corrigido é falha funcional, não vantagem de desempenho.
var grid: HexGrid
var player: PlayerData
var unit: Unit

func _ready():
	_run.call_deferred()

func _run():
	grid = HexGrid.new()
	add_child(grid)
	player = PlayerData.new(CivilizationData.new())
	var size := Vector2i(320, 84) if "--large" in OS.get_cmdline_user_args() else Vector2i(128, 72)
	for q in range(-size.x / 2, size.x / 2):
		for r in range(-size.y / 2, size.y / 2):
			var coord := Vector2i(q, r)
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			grid.visibility[coord] = HexGrid.Visibility.VISIBLE if HexMetrics.axial_distance(Vector2i.ZERO, coord) <= 4 else HexGrid.Visibility.UNSEEN
	unit = grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("warrior"), player)
	var results := {"tiles": grid.tiles.size(), "scope": "CPU planning only; no movement/fog/render"}
	results.ground_open = _measure(30)
	unit.unit_data.movement_profile = UnitData.MovementProfile.FLYING
	results.flight_open = _measure(30)
	unit.unit_data.movement_profile = UnitData.MovementProfile.INFILTRATOR
	results.infiltration_open = _measure(30)
	for coord in grid.visibility: grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	unit.unit_data.movement_profile = UnitData.MovementProfile.FLYING
	results.flight_fully_seen = _measure(10)
	# Uma fronteira pequena e isolada: identifica se a busca faz trabalho desnecessário no continente inteiro.
	var goal := Vector2i(25, 0)
	grid.visibility[goal] = HexGrid.Visibility.UNSEEN
	for coord in HexMetrics.coords_within(goal, 4):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid._land_component_tile_count = -1
	grid._amphibious_component_tile_count = -1
	results.flight_isolated_goal = _measure(1)
	var output := "user://exploration_bench.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.substr(6)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print("EXPLORATION_BENCH ", JSON.stringify(results))
	player.release_relations()
	grid.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _measure(count: int) -> Dictionary:
	var result := {}
	for old in [true, false]:
		var samples: Array[float] = []
		var length := 0
		for i in count:
			var started := Time.get_ticks_usec()
			var route: Array[Vector2i] = _legacy_plan() if old else grid._exploration_path(unit)
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
			length = route.size()
		var sum := 0.0
		for sample in samples: sum += sample
		samples.sort()
		result["before" if old else "after"] = {"samples": count, "mean_ms": sum / count, "p95_ms": samples[mini(count - 1, int(ceil(count * 0.95)) - 1)], "max_ms": samples[-1], "route_length": length}
	return result

func _legacy_plan() -> Array[Vector2i]:
	var heap: Array = []
	for coord in grid.tiles.keys():
		if grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) != HexGrid.Visibility.UNSEEN: continue
		var terrain: HexTileData = grid.tiles[coord]
		if not unit.unit_data.flies and terrain.blocks_land_units(): continue
		var dist := float(HexMetrics.axial_distance(unit.coord, coord))
		if heap.size() < HexGrid.EXPLORE_CANDIDATE_LIMIT:
			grid._heap_push(heap, -dist, coord)
		elif -dist > heap[0][0]:
			grid._heap_pop_min(heap)
			grid._heap_push(heap, -dist, coord)
	var candidates: Array[Vector2i] = []
	while not heap.is_empty(): candidates.push_front(grid._heap_pop_min(heap)[1])
	for candidate in candidates:
		var route: Array[Vector2i] = grid.unit_path(unit, candidate)
		if not route.is_empty(): return route
	return []
