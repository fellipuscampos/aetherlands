extends RefCounted

## Busca de fronteira para perfis especiais e fallback da seleção rápida terrestre. Uma busca compartilhada,
## encerrada no primeiro destino inexplorado alcançável; nunca uma nova rodada de A* por candidato.
## O grafo só contém paradas legais: voo salta até um pouso por turno; infiltração atravessa ocupantes sem
## estacionar sobre eles. Estado/caches locais à chamada, sem polling ou dados persistentes no save.

static func path(grid, unit) -> Array[Vector2i]:
	var profile: int = unit.unit_data.movement_profile
	var closed: Dictionary = grid.closed_tiles_for(unit.owner_player)
	var costs := {}
	var flight_offsets: Array[Vector2i] = []
	if profile == UnitData.MovementProfile.FLYING:
		flight_offsets = HexMetrics.coords_within(Vector2i.ZERO, int(floor(unit.unit_data.movement_points)))
	var isolated := {}
	var has_goal := false
	for coord in grid.tiles:
		if grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) != HexGrid.Visibility.UNSEEN:
			continue
		if not _is_goal(grid, unit, coord) or closed.has(coord):
			continue
		if _entry(grid, unit, coord, costs, closed) < 0.0:
			continue
		if profile != UnitData.MovementProfile.FLYING and not unit.unit_data.flies and not grid._route_possible(unit.coord, coord, unit.can_embark()):
			continue
		if isolated.has(coord) or _isolated_goal(grid, unit, coord, costs, closed, flight_offsets, isolated):
			continue
		has_goal = true
		break
	if not has_goal:
		return []
	var frontier: Array = []
	grid._heap_push(frontier, 0.0, unit.coord)
	var distance := {unit.coord: 0.0}
	var previous := {}
	var settled := {}
	while not frontier.is_empty():
		var current: Vector2i = grid._heap_pop_min(frontier)[1]
		if settled.has(current): continue
		settled[current] = true
		if current != unit.coord and _is_goal(grid, unit, current):
			var result: Array[Vector2i] = []
			while current != unit.coord:
				result.append(current)
				current = previous[current]
			result.reverse()
			return result
		var neighbors: Dictionary = _neighbors(grid, unit, current, costs, closed, flight_offsets)
		for next in neighbors:
			var cost: float = distance[current] + neighbors[next]
			if not distance.has(next) or cost < distance[next]:
				distance[next] = cost
				previous[next] = current
				grid._heap_push(frontier, cost, next)
	return []

static func _is_goal(grid, unit, coord: Vector2i) -> bool:
	if grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) != HexGrid.Visibility.UNSEEN or grid.units_by_coord.has(coord):
		return false
	var terrain: HexTileData = grid.tiles[coord]
	return unit.unit_data.flies or not terrain.blocks_land_units()

static func _entry(grid, unit, coord: Vector2i, costs: Dictionary, closed: Dictionary) -> float:
	if coord == unit.coord: return 0.0
	if costs.has(coord): return costs[coord]
	var profile: int = unit.unit_data.movement_profile
	var cost := -1.0
	if not closed.has(coord):
		cost = grid._route_enter_cost(coord, unit.owner_player, unit.unit_data.flies,
			unit.can_embark(), profile != UnitData.MovementProfile.GROUND or unit.unit_data.flies,
			profile == UnitData.MovementProfile.INFILTRATOR, profile == UnitData.MovementProfile.GROUND)
	costs[coord] = cost
	return cost

static func _neighbors(grid, unit, origin: Vector2i, costs: Dictionary, closed: Dictionary, flight_offsets: Array[Vector2i]) -> Dictionary:
	var result := {}
	if unit.unit_data.movement_profile == UnitData.MovementProfile.FLYING:
		for offset in flight_offsets:
			var coord := origin + offset
			if _entry(grid, unit, coord, costs, closed) >= 0.0:
				result[coord] = float(HexMetrics.axial_distance(origin, coord))
		return result
	if unit.unit_data.movement_profile != UnitData.MovementProfile.INFILTRATOR:
		for offset in HexGrid.NEIGHBOR_DIRS:
			var coord: Vector2i = origin + offset
			var cost := _entry(grid, unit, coord, costs, closed)
			if cost >= 0.0: result[coord] = cost
		return result
	# Cada tile livre já é um vértice. Só estende a aresta através de ocupantes, e no máximo um turno inteiro:
	# uma formação mais larga não pode ser atravessada sem um tile livre onde terminar o movimento.
	var queue: Array[Vector2i] = [origin]
	var depth := {origin: 0}
	var index := 0
	var budget := int(floor(unit.unit_data.movement_points))
	while index < queue.size():
		var current := queue[index]
		index += 1
		if depth[current] >= budget: continue
		for offset in HexGrid.NEIGHBOR_DIRS:
			var coord: Vector2i = current + offset
			if depth.has(coord) or _entry(grid, unit, coord, costs, closed) < 0.0: continue
			depth[coord] = int(depth[current]) + 1
			if grid.units_by_coord.has(coord) and coord != unit.coord:
				queue.append(coord)
			else:
				result[coord] = float(depth[coord])
	return result

## Equivalente ao corte de bolsão do A* canônico, com as arestas do perfil correto. Uma ilha pequena onde não
## há pouso/travessia não dispara uma busca por todo o continente. Explora no máximo 24 paradas; um bolsão
## maior é inconclusivo (nunca rejeita uma rota válida). Memoriza só os componentes pequenos provados isolados.
static func _isolated_goal(grid, unit, goal: Vector2i, costs: Dictionary, closed: Dictionary, offsets: Array[Vector2i], isolated: Dictionary) -> bool:
	var queue: Array[Vector2i] = [goal]
	var seen := {goal: true}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next in _neighbors(grid, unit, current, costs, closed, offsets):
			if next == unit.coord: return false
			if seen.has(next): continue
			seen[next] = true
			if seen.size() > 24: return false
			queue.append(next)
	isolated.merge(seen)
	return true

## Executa só paradas legais que cabem no movimento ATUAL. A rota é recalculada pelo mesmo helper da prévia;
## ocupantes intermediários da infiltração nunca são removidos/sobrescritos no índice.
static func advance(grid, unit, route: Array[Vector2i]) -> bool:
	var known: Dictionary = grid._hostiles_in_reach(unit)
	for landing in route:
		var steps: Array[Vector2i] = grid.unit_route(unit, landing)
		if steps.is_empty() or float(steps.size()) > unit.movement_left: break
		grid.move_unit(unit, landing, float(steps.size()), "", steps)
		if unit.coord != landing or unit.hp <= 0.0: break
		for hostile in grid._hostiles_in_reach(unit):
			if not known.has(hostile): return true
		if unit.movement_left <= 0.0: break
	return false
