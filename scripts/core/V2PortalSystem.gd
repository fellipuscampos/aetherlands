class_name V2PortalSystem
extends RefCounted

## Pares persistentes de mobilidade mágica V2 (Fase 21). O estado canônico vive no HexGrid como
## dados puros: owner_index estável em GameManager.players, Escola e duas coordenadas. Os índices por
## dono/Escola e coordenada são caches transitórios reconstruídos no load; Portal nunca entra em
## compute_path/compute_reachable e só é atravessado por ação explícita.

const INVALID_COORD := Vector2i(999999, 999999)
const REASON_NO_PAIR := "Esta unidade não está sobre um Portal próprio."
const REASON_NO_MOVEMENT := "A unidade já agiu neste turno."
const REASON_EXIT_HIDDEN := "A saída do Portal está fora de visão."
const REASON_NO_LANDING := "Não há espaço livre no destino do Portal."

static func _grid(hex_grid: HexGrid) -> HexGrid:
	return hex_grid if hex_grid != null else GameManager.hex_grid

static func owner_index(player: PlayerData) -> int:
	return GameManager.players.find(player) if player != null else -1

static func _key(index: int, school: String) -> String:
	return "%d:%s" % [index, school]

static func _rebuild_indexes(grid: HexGrid) -> void:
	grid.v2_portal_endpoint_index.clear()
	grid.v2_portal_owner_school_index.clear()
	for pair in grid.v2_portal_pairs:
		var key := _key(int(pair.owner_index), String(pair.school))
		grid.v2_portal_owner_school_index[key] = pair
		grid.v2_portal_endpoint_index[pair.a] = pair
		grid.v2_portal_endpoint_index[pair.b] = pair

static func pair_for(player: PlayerData, school: String, hex_grid: HexGrid = null) -> Dictionary:
	var grid := _grid(hex_grid)
	if grid == null:
		return {}
	return grid.v2_portal_owner_school_index.get(_key(owner_index(player), school), {})

static func endpoint_at(coord: Vector2i, hex_grid: HexGrid = null) -> Dictionary:
	var grid := _grid(hex_grid)
	return grid.v2_portal_endpoint_index.get(coord, {}) if grid != null else {}

static func paired_endpoint(coord: Vector2i, hex_grid: HexGrid = null) -> Vector2i:
	var pair := endpoint_at(coord, hex_grid)
	if pair.is_empty():
		return INVALID_COORD
	return pair.b if pair.a == coord else pair.a

static func _has_resource_improvement(grid: HexGrid, coord: Vector2i) -> bool:
	for city in grid.cities_by_coord.values():
		if city.resource_improvements.has(coord):
			return true
	return false

## Regra do endpoint escolhido no cast. Recurso bruto e modificação Druídica não ocupam a camada
## do Portal; cidade, prédio, melhoria, covil, unidade e terreno terrestre impossível ocupam.
static func creation_destination_reason(coord: Vector2i, hex_grid: HexGrid = null, player: PlayerData = null, school: String = "") -> String:
	var grid := _grid(hex_grid)
	if grid == null:
		return "Tile inválido."
	var tile: HexTileData = grid.get_tile(coord)
	if tile == null:
		return "Tile inválido."
	if tile.blocks_land_units():
		return "O Portal precisa de terreno terrestre transitável."
	if grid.get_unit_at(coord) != null:
		return "O tile está ocupado."
	if grid.get_city_at(coord) != null:
		return "Não é possível criar um Portal numa cidade."
	if grid.get_building_at(coord) != null or _has_resource_improvement(grid, coord):
		return "O terreno está ocupado por uma estrutura permanente."
	if grid.lairs_by_coord.has(coord):
		return "Não é possível criar um Portal sobre um covil."
	var existing: Dictionary = grid.v2_portal_endpoint_index.get(coord, {})
	if not existing.is_empty():
		var own_key := _key(owner_index(player), school) if player != null and school != "" else ""
		if own_key == "" or _key(int(existing.owner_index), String(existing.school)) != own_key:
			return "Já existe um Portal neste tile."
	return ""

static func create_or_replace_pair(player: PlayerData, school: String, endpoint_a: Vector2i, endpoint_b: Vector2i, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	var index := owner_index(player)
	if grid == null or index < 0 or school == "" or endpoint_a == endpoint_b:
		return false
	var origin_tile: HexTileData = grid.get_tile(endpoint_a)
	if origin_tile == null or origin_tile.blocks_land_units() or creation_destination_reason(endpoint_b, grid, player, school) != "":
		return false
	var origin_pair: Dictionary = grid.v2_portal_endpoint_index.get(endpoint_a, {})
	if not origin_pair.is_empty() and _key(int(origin_pair.owner_index), String(origin_pair.school)) != _key(index, school):
		return false
	# A validação terminou: só agora o par anterior é removido (substituição transacional).
	close_pair(player, school, grid, false)
	var pair := {"owner_index": index, "school": school, "a": endpoint_a, "b": endpoint_b}
	grid.v2_portal_pairs.append(pair)
	_rebuild_indexes(grid)
	grid.refresh_v2_portal_markers()
	return true

static func close_pair(player: PlayerData, school: String, hex_grid: HexGrid = null, refresh_markers: bool = true) -> bool:
	var grid := _grid(hex_grid)
	if grid == null:
		return false
	var key := _key(owner_index(player), school)
	var pair: Dictionary = grid.v2_portal_owner_school_index.get(key, {})
	if pair.is_empty():
		return false
	grid.v2_portal_pairs.erase(pair)
	_rebuild_indexes(grid)
	if refresh_markers:
		grid.refresh_v2_portal_markers()
	return true

static func close_pair_at(coord: Vector2i, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	if grid == null:
		return false
	var pair: Dictionary = grid.v2_portal_endpoint_index.get(coord, {})
	if pair.is_empty():
		return false
	grid.v2_portal_pairs.erase(pair)
	_rebuild_indexes(grid)
	grid.refresh_v2_portal_markers()
	return true

static func clear_all(hex_grid: HexGrid = null) -> void:
	var grid := _grid(hex_grid)
	if grid == null:
		return
	grid.v2_portal_pairs.clear()
	_rebuild_indexes(grid)
	grid.refresh_v2_portal_markers()

static func _visible_to_owner(unit: Unit, coord: Vector2i, grid: HexGrid) -> bool:
	if unit.owner_player != GameManager.human_player or grid.visibility.is_empty():
		return true
	return grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

static func _owned_pair_at(unit: Unit, grid: HexGrid) -> Dictionary:
	var pair: Dictionary = endpoint_at(unit.coord, grid)
	if pair.is_empty() or int(pair.owner_index) != owner_index(unit.owner_player):
		return {}
	return pair

static func is_owned_endpoint(unit: Unit, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	return unit != null and grid != null and not _owned_pair_at(unit, grid).is_empty()

static func traversal_destination(unit: Unit, hex_grid: HexGrid = null) -> Vector2i:
	var grid := _grid(hex_grid)
	if unit == null or grid == null:
		return INVALID_COORD
	var pair := _owned_pair_at(unit, grid)
	if pair.is_empty():
		return INVALID_COORD
	var exit_coord: Vector2i = pair.b if pair.a == unit.coord else pair.a
	if not _visible_to_owner(unit, exit_coord, grid):
		return INVALID_COORD
	# Ordem canônica: endpoint exato; depois NEIGHBOR_DIRS de HexGrid, sem ordenar Dictionary.
	for candidate in [exit_coord] + grid.get_neighbors(exit_coord):
		if _visible_to_owner(unit, candidate, grid) and grid.unit_destination_reason(unit, candidate) == "":
			return candidate
	return INVALID_COORD

static func traversal_reason(unit: Unit, hex_grid: HexGrid = null) -> String:
	var grid := _grid(hex_grid)
	if unit == null or grid == null or unit.owner_player == null:
		return REASON_NO_PAIR
	if _owned_pair_at(unit, grid).is_empty():
		return REASON_NO_PAIR
	if not unit.can_receive_orders():
		return unit.order_block_reason()
	if unit.movement_left <= 0.0:
		return REASON_NO_MOVEMENT
	var exit_coord := paired_endpoint(unit.coord, grid)
	if not _visible_to_owner(unit, exit_coord, grid):
		return REASON_EXIT_HIDDEN
	if traversal_destination(unit, grid) == INVALID_COORD:
		return REASON_NO_LANDING
	return ""

static func can_traverse(unit: Unit, hex_grid: HexGrid = null) -> bool:
	return traversal_reason(unit, hex_grid) == ""

static func traverse(unit: Unit, hex_grid: HexGrid = null) -> bool:
	var grid := _grid(hex_grid)
	if grid == null or traversal_reason(unit, grid) != "":
		return false
	var destination := traversal_destination(unit, grid)
	if destination == INVALID_COORD:
		return false
	grid.teleport_unit(unit, destination)
	unit.movement_left = 0.0
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	return true

static func to_save_array(hex_grid: HexGrid = null) -> Array:
	var grid := _grid(hex_grid)
	var result: Array = []
	if grid == null:
		return result
	for pair in grid.v2_portal_pairs:
		result.append({
			"owner_index": int(pair.owner_index),
			"school": String(pair.school),
			"a": [pair.a.x, pair.a.y],
			"b": [pair.b.x, pair.b.y],
		})
	return result

static func _coord_from_variant(value) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return INVALID_COORD
	if typeof(value[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(value[1]) not in [TYPE_INT, TYPE_FLOAT]:
		return INVALID_COORD
	return Vector2i(int(value[0]), int(value[1]))

## Primeiro registro válido por owner+School vence; registros corrompidos e endpoints duplicados são ignorados.
static func load_save_array(entries, hex_grid: HexGrid = null) -> int:
	var grid := _grid(hex_grid)
	if grid == null:
		return 0
	grid.v2_portal_pairs.clear()
	_rebuild_indexes(grid)
	if typeof(entries) != TYPE_ARRAY:
		grid.refresh_v2_portal_markers()
		return 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY or not (entry.get("owner_index") is float or entry.get("owner_index") is int) or typeof(entry.get("school", null)) != TYPE_STRING:
			continue
		var index := int(entry.owner_index)
		var school := String(entry.school)
		var a := _coord_from_variant(entry.get("a", null))
		var b := _coord_from_variant(entry.get("b", null))
		var key := _key(index, school)
		if index < 0 or index >= GameManager.players.size() or school == "" or not V2MagicContent.is_v2_school(school) or a == INVALID_COORD or b == INVALID_COORD or a == b:
			continue
		var tile_a: HexTileData = grid.get_tile(a)
		var tile_b: HexTileData = grid.get_tile(b)
		if tile_a == null or tile_b == null or tile_a.blocks_land_units() or tile_b.blocks_land_units():
			continue
		# B é o endpoint implantado: estrutura permanente/cidade/covil indicam estado impossível.
		if grid.get_city_at(b) != null or grid.get_building_at(b) != null or _has_resource_improvement(grid, b) or grid.lairs_by_coord.has(b):
			continue
		if grid.v2_portal_owner_school_index.has(key) or grid.v2_portal_endpoint_index.has(a) or grid.v2_portal_endpoint_index.has(b):
			continue
		var pair := {"owner_index": index, "school": school, "a": a, "b": b}
		grid.v2_portal_pairs.append(pair)
		grid.v2_portal_owner_school_index[key] = pair
		grid.v2_portal_endpoint_index[a] = pair
		grid.v2_portal_endpoint_index[b] = pair
	grid.refresh_v2_portal_markers()
	return grid.v2_portal_pairs.size()
