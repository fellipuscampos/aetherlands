class_name V2AIWorldView
extends RefCounted

## The only enemy-information boundary used by the V2 AI. It exposes full
## ownership data but never enemy resources, research, queues or cooldowns.

var observer: PlayerData
var grid: HexGrid
var visible_tiles: Dictionary = {}
var visible_enemy_units: Array[Unit] = []
## Sanitized records only. A hidden city's City/PlayerData objects would expose
## buildings, queue and resources through ordinary property access.
var known_enemy_cities: Array[Dictionary] = []
var own_lost_cities: Array[Dictionary] = []
var public_rituals: Array[Dictionary] = []
var visible_enemy_city_coords: Dictionary = {}

static func capture(player: PlayerData, hex_grid: HexGrid) -> V2AIWorldView:
	var view := V2AIWorldView.new()
	view.observer = player
	view.grid = hex_grid
	if player == null or hex_grid == null:
		return view
	view.visible_tiles = hex_grid.compute_visible_tiles(player)
	player.explored_tiles.merge(view.visible_tiles, true)
	for other in GameManager.players:
		if other == player:
			continue
		for unit in other.units:
			if view.is_visible(unit.coord):
				view.visible_enemy_units.append(unit)
		for city in other.cities:
			var currently_visible := view.is_visible(city.coord)
			if currently_visible:
				player.known_enemy_cities[city.coord] = true
				view.visible_enemy_city_coords[city.coord] = true
			if player.known_enemy_cities.has(city.coord):
				var record := {
					"coord": city.coord,
					"owner_id": V2VictoryConditions.stable_id(other),
					"at_war": player.is_at_war_with(other),
					"visible": currently_visible,
				}
				if currently_visible:
					record["developed"] = city.is_developed_v2()
				view.known_enemy_cities.append(record)
			# This provenance is public to the former owner and is the exact
			# qualification used by Military Supremacy at capture time.
			if city.v2_supremacy_captured_from == V2VictoryConditions.stable_id(player):
				view.own_lost_cities.append({"coord": city.coord, "owner_id": V2VictoryConditions.stable_id(other)})
	for unit in hex_grid.neutral_units():
		if view.is_visible(unit.coord):
			view.visible_enemy_units.append(unit)
	view.visible_enemy_units.sort_custom(func(a: Unit, b: Unit) -> bool: return a.serial_id < b.serial_id)
	view.known_enemy_cities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _coord_less(a.coord, b.coord))
	view.own_lost_cities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _coord_less(a.coord, b.coord))
	view.public_rituals = V2TranscendenceSystem.public_rituals()
	return view

func is_visible(coord: Vector2i) -> bool:
	return visible_tiles.has(coord)

func visible_hostiles_near(coord: Vector2i, radius: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in visible_enemy_units:
		if _is_hostile(unit) and HexMetrics.axial_distance(coord, unit.coord) <= radius:
			result.append(unit)
	return result

func visible_hostile_at(coord: Vector2i) -> Unit:
	for unit in visible_enemy_units:
		if unit.coord == coord and _is_hostile(unit):
			return unit
	return null

func known_hostile_city_at(coord: Vector2i) -> Dictionary:
	for record in known_enemy_cities:
		if record.coord == coord and bool(record.at_war):
			return record.duplicate()
	return {}

func is_enemy_city_visible(city: City) -> bool:
	return city != null and visible_enemy_city_coords.has(city.coord)

func _is_hostile(unit: Unit) -> bool:
	return unit != null and (unit.owner_player == null or observer.is_at_war_with(unit.owner_player))

func public_enemy_rituals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var own_index := V2VictoryConditions.stable_id(observer)
	for info in public_rituals:
		if int(info.owner_index) != own_index:
			result.append(info.duplicate())
	return result

static func _coord_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y
