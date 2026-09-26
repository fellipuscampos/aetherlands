class_name V2EnvironmentalZoneSystem
extends RefCounted

## Camada ambiental temporária, esparsa e independente de terreno/Portal.
## Estado canônico: HexGrid.v2_environmental_zones[coord] = Dictionary.

const INVALID_COORD := Vector2i(999999, 999999)
const OCCUPIED_REASON := "Este tile já está sob uma zona ambiental."

static func _grid(hex_grid: HexGrid) -> HexGrid:
	return hex_grid if hex_grid != null else GameManager.hex_grid

static func zone_entry_at(coord: Vector2i, hex_grid: HexGrid = null) -> Dictionary:
	var grid := _grid(hex_grid)
	return grid.v2_environmental_zones.get(coord, {}) if grid != null else {}

static func zone_at(coord: Vector2i, hex_grid: HexGrid = null) -> V2EnvironmentalZoneData:
	var entry := zone_entry_at(coord, hex_grid)
	return V2EnvironmentalZoneDatabase.get_zone(String(entry.get("zone_id", ""))) if not entry.is_empty() else null

static func application_reason(hex_grid: HexGrid, coord: Vector2i, zone_id: String) -> String:
	if hex_grid == null or hex_grid.get_tile(coord) == null or V2EnvironmentalZoneDatabase.get_zone(zone_id) == null:
		return "Tile ambiental inválido."
	if hex_grid.v2_environmental_zones.has(coord):
		return OCCUPIED_REASON
	return ""

static func _owner_index(player: PlayerData) -> int:
	return GameManager.players.find(player) if player != null else -1

static func _entry(zone_id: String, owner_index: int, school: String, rounds: int) -> Dictionary:
	return {"zone_id": zone_id, "owner_index": owner_index, "school": school, "remaining_rounds": rounds}

static func apply(hex_grid: HexGrid, coord: Vector2i, zone_id: String, owner_index: int, school: String, duration_bonus: int = 0, refresh: bool = true) -> bool:
	if application_reason(hex_grid, coord, zone_id) != "" or owner_index < 0 or owner_index >= GameManager.players.size() or not V2MagicContent.is_v2_school(school):
		return false
	var data := V2EnvironmentalZoneDatabase.get_zone(zone_id)
	var rounds := data.duration_rounds + maxi(duration_bonus, 0)
	if rounds <= 0:
		return false
	hex_grid.v2_environmental_zones[coord] = _entry(zone_id, owner_index, school, rounds)
	if refresh:
		hex_grid.refresh_environmental_zone_marker(coord)
		_refresh_human_fog_if_needed(hex_grid, [coord], data.vision_delta != 0)
	return true

## Primary primeiro; secundários na ordem canônica do disco hexagonal. Para o
## humano, secundários ocultos são ignorados. Uma zona preexistente nunca é sobrescrita.
static func apply_area(caster: Unit, zone_id: String, primary: Vector2i, radius: int, hex_grid: HexGrid = null) -> Array[Vector2i]:
	var grid := _grid(hex_grid)
	var result: Array[Vector2i] = []
	if caster == null or caster.owner_player == null or grid == null:
		return result
	var index := _owner_index(caster.owner_player)
	var bonus := maxi(caster.unit_data.environmental_zone_duration_bonus, 0)
	var coords: Array[Vector2i] = [primary]
	if radius > 0:
		coords.append_array(HexMetrics.coords_within(primary, radius))
	for coord in coords:
		if not grid.tiles.has(coord) or grid.v2_environmental_zones.has(coord):
			continue
		if coord != primary and not _visible_to_owner(caster, coord, grid):
			continue
		if apply(grid, coord, zone_id, index, caster.unit_data.v2_magic_school, bonus, false):
			result.append(coord)
	if not result.is_empty():
		for coord in result:
			grid.refresh_environmental_zone_marker(coord)
		var data := V2EnvironmentalZoneDatabase.get_zone(zone_id)
		_refresh_human_fog_if_needed(grid, result, data != null and data.vision_delta != 0)
	return result

static func _visible_to_owner(caster: Unit, coord: Vector2i, grid: HexGrid) -> bool:
	if caster.owner_player != GameManager.human_player or grid.visibility.is_empty():
		return true
	return grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

static func remove(hex_grid: HexGrid, coord: Vector2i, only_if_dispellable: bool = false, refresh: bool = true) -> bool:
	if hex_grid == null or not hex_grid.v2_environmental_zones.has(coord):
		return false
	var data := zone_at(coord, hex_grid)
	if only_if_dispellable and (data == null or not data.dispellable):
		return false
	hex_grid.v2_environmental_zones.erase(coord)
	if refresh:
		hex_grid.refresh_environmental_zone_marker(coord)
		_refresh_human_fog_if_needed(hex_grid, [coord], data != null and data.vision_delta != 0)
	return true

static func is_dispellable_at(coord: Vector2i, hex_grid: HexGrid = null) -> bool:
	var data := zone_at(coord, hex_grid)
	return data != null and data.dispellable

## Fonte única da visão de Unit. Fast path: mapa sem zonas ou tile sem entrada.
static func effective_unit_vision(unit: Unit, hex_grid: HexGrid = null) -> int:
	if unit == null or unit.unit_data == null:
		return 1
	var grid := _grid(hex_grid)
	if grid == null or grid.v2_environmental_zones.is_empty():
		return maxi(1, unit.unit_data.vision_range)
	var data := zone_at(unit.coord, grid)
	return maxi(1, unit.unit_data.vision_range + (data.vision_delta if data != null else 0))

## Fator do atacante para combate físico de Unit. Spell/cidade/tick nunca chamam isto.
static func physical_ranged_attack_multiplier(attacker: Unit, hex_grid: HexGrid = null) -> float:
	if attacker == null or attacker.unit_data == null or attacker.unit_data.attack_range <= 1:
		return 1.0
	var grid := _grid(hex_grid)
	if grid == null or grid.v2_environmental_zones.is_empty():
		return 1.0
	var data := zone_at(attacker.coord, grid)
	return data.physical_ranged_attack_multiplier if data != null else 1.0

static func unit_lines(unit: Unit, hex_grid: HexGrid = null) -> Array[String]:
	var lines: Array[String] = []
	if unit == null:
		return lines
	var entry := zone_entry_at(unit.coord, hex_grid)
	var data := zone_at(unit.coord, hex_grid)
	if data == null:
		return lines
	lines.append("Ambiente — %s (%d rodada(s))" % [data.display_name, int(entry.remaining_rounds)])
	lines.append_array(V2EnvironmentalZoneDatabase.effect_lines(data))
	return lines

## UMA chamada por rodada global. Snapshot estável; dano não concede abate,
## XP, saque ou recompensa. Depois decrementa e remove exatamente em zero.
static func process_global_round(hex_grid: HexGrid = null, defer_fog_refresh: bool = false) -> Dictionary:
	var grid := _grid(hex_grid)
	var summary := {"damaged_units": 0, "expired_zones": 0}
	if grid == null or grid.v2_environmental_zones.is_empty():
		return summary
	var victims: Array[Unit] = []
	for coord in grid.v2_environmental_zones.keys():
		var data := zone_at(coord, grid)
		if data == null or data.round_tick_magic_damage <= 0.0:
			continue
		var unit := grid.get_unit_at(coord)
		if unit != null and is_instance_valid(unit) and unit.hp > 0.0:
			victims.append(unit)
	victims.sort_custom(func(a: Unit, b: Unit) -> bool:
		var ai := GameManager.players.find(a.owner_player) if a.owner_player != null else GameManager.players.size()
		var bi := GameManager.players.find(b.owner_player) if b.owner_player != null else GameManager.players.size()
		return a.serial_id < b.serial_id if ai == bi else ai < bi)
	for unit in victims:
		if not is_instance_valid(unit) or unit.hp <= 0.0:
			continue
		var zone := zone_at(unit.coord, grid)
		if zone != null and zone.round_tick_magic_damage > 0.0:
			CombatResolver.apply_environmental_unit_damage(unit, zone.round_tick_magic_damage, grid)
			summary.damaged_units += 1
	var expired: Array[Vector2i] = []
	var vision_changed := false
	for coord in grid.v2_environmental_zones.keys():
		var entry: Dictionary = grid.v2_environmental_zones[coord]
		entry.remaining_rounds = int(entry.remaining_rounds) - 1
		if int(entry.remaining_rounds) <= 0:
			var data := zone_at(coord, grid)
			vision_changed = vision_changed or (data != null and data.vision_delta != 0)
			expired.append(coord)
	for coord in expired:
		grid.v2_environmental_zones.erase(coord)
		grid.refresh_environmental_zone_marker(coord)
	summary.expired_zones = expired.size()
	# GameManager._finish_turn recalcula uma vez logo depois. Chamadas diretas (testes)
	# ainda preservam a semântica imediata se não estiver processando um turno.
	if vision_changed and not defer_fog_refresh:
		# A unidade humana que sofria a penalidade pode ter morrido no tick acima;
		# nesse caso ela já não está no tile para o filtro usado por casts/Dispel.
		# Expiração é um evento de rodada raro e recalcula uma única vez.
		if GameManager.human_player != null:
			grid.recompute_fog(GameManager.human_player)
	return summary

static func _refresh_human_fog_if_needed(grid: HexGrid, coords: Array, effect_changes_vision: bool) -> void:
	if not effect_changes_vision or grid == null or GameManager.human_player == null:
		return
	for coord in coords:
		var unit := grid.get_unit_at(coord)
		if unit != null and unit.owner_player == GameManager.human_player:
			grid.recompute_fog(GameManager.human_player)
			return

static func to_save_array(hex_grid: HexGrid = null) -> Array:
	var grid := _grid(hex_grid)
	var result: Array = []
	if grid == null:
		return result
	var coords: Array = grid.v2_environmental_zones.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for coord in coords:
		var entry: Dictionary = grid.v2_environmental_zones[coord]
		result.append({"coord": [coord.x, coord.y], "zone_id": String(entry.zone_id), "owner_index": int(entry.owner_index), "school": String(entry.school), "remaining_rounds": int(entry.remaining_rounds)})
	return result

static func _coord_from_variant(value) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() != 2 or typeof(value[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(value[1]) not in [TYPE_INT, TYPE_FLOAT]:
		return INVALID_COORD
	return Vector2i(int(value[0]), int(value[1]))

## Primeiro registro válido por coordenada vence; todo dado derivado continua no DB.
static func load_save_array(entries, hex_grid: HexGrid = null) -> int:
	var grid := _grid(hex_grid)
	if grid == null:
		return 0
	grid.v2_environmental_zones.clear()
	if typeof(entries) == TYPE_ARRAY:
		for value in entries:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var coord := _coord_from_variant(value.get("coord", null))
			var zone_id = value.get("zone_id", null)
			var owner = value.get("owner_index", null)
			var school = value.get("school", null)
			var rounds = value.get("remaining_rounds", null)
			if coord == INVALID_COORD or not grid.tiles.has(coord) or grid.v2_environmental_zones.has(coord):
				continue
			if typeof(zone_id) != TYPE_STRING or V2EnvironmentalZoneDatabase.get_zone(String(zone_id)) == null:
				continue
			if typeof(owner) not in [TYPE_INT, TYPE_FLOAT] or int(owner) < 0 or int(owner) >= GameManager.players.size():
				continue
			if typeof(school) != TYPE_STRING or not V2MagicContent.is_v2_school(String(school)):
				continue
			if typeof(rounds) not in [TYPE_INT, TYPE_FLOAT] or int(rounds) <= 0:
				continue
			grid.v2_environmental_zones[coord] = _entry(String(zone_id), int(owner), String(school), int(rounds))
	grid.refresh_all_environmental_zone_markers()
	return grid.v2_environmental_zones.size()
