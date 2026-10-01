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
## Fase 33D1 — covis que ESTA civilização descobriu (tile explorado/observado) e que continuam ativos:
## {coord, kind}. Nunca a lista global do HexGrid; a população ao redor não é exposta (só o que for visto
## entra em visible_enemy_units). Covil destruído sai da lista (não está mais em lair_coords).
var known_lairs: Array[Dictionary] = []
## Fase 33D3 — marcos PÚBLICOS de vitória dos rivais ({owner_id: [marcos]}; PublicVictoryMilestones): só o fato.
var public_milestones: Dictionary = {}
## Fase 33D3 — grandes eventos PÚBLICOS em andamento (Relicário: o local é público pelo anúncio; Dragão: região
## de origem anunciada). {event_id, type, phase, coord}.
var public_world_events: Array[Dictionary] = []

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
				player.remember_enemy_city(city) # Fase 33D3: com o nível observado agora
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
				if player.known_enemy_city_levels.has(city.coord):
					record["level"] = int(player.known_enemy_city_levels[city.coord]) # último nível OBSERVADO
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
	for lair_coord in hex_grid.lair_coords:
		if player.explored_tiles.has(lair_coord):
			# Fase 33D2: o papel (regional/guardião) é público para quem vê o covil (TileInspector mostra).
			view.known_lairs.append({"coord": lair_coord, "kind": String(hex_grid.lair_kind_by_coord.get(lair_coord, "")), "role": hex_grid.lair_role(lair_coord)})
	view.known_lairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _coord_less(a.coord, b.coord))
	RegionalThreatSystem.note_observation(hex_grid, player)
	var own_id := V2VictoryConditions.stable_id(player)
	var facts := PublicVictoryMilestones.public_facts()
	for owner_id in facts:
		if int(owner_id) != own_id:
			view.public_milestones[int(owner_id)] = facts[owner_id]
	for event in WorldEventManager.active_events:
		if event is ReliquaryEvent and (event as ReliquaryEvent).is_open() and event.phase != WorldEvent.PHASE_DORMANT:
			view.public_world_events.append({"event_id": event.event_id, "type": event.event_type, "phase": event.phase, "coord": (event as ReliquaryEvent).site_coord})
		elif event is DragonEvent:
			view.public_world_events.append({"event_id": event.event_id, "type": event.event_type, "phase": event.phase, "coord": (event as DragonEvent).origin_region})
	return view

func has_public_milestone(owner_id: int, milestone: String) -> bool:
	return milestone in (public_milestones.get(owner_id, []) as Array)

func is_lair_known(coord: Vector2i) -> bool:
	for record in known_lairs:
		if record.coord == coord:
			return true
	return false

func known_lair(coord: Vector2i) -> Dictionary:
	for record in known_lairs:
		if record.coord == coord:
			return record
	return {}

## Fase 33D2 — defesa CONHECIDA de um covil descoberto, em poder de unidade (CityDefense.unit_power):
## monstros hostis VISÍVEIS na área do covil; se a área não está toda visível, no mínimo o chefe típico do
## tipo (estimativa conservadora pelo catálogo público de monstros) — nunca a população escondida real.
func known_lair_defense(coord: Vector2i) -> float:
	var observed := 0.0
	for unit in visible_enemy_units:
		if unit.owner_player == null and HexMetrics.axial_distance(unit.coord, coord) <= 1:
			observed += CityDefense.unit_power(unit)
	var area_visible := is_visible(coord)
	if area_visible and grid != null:
		for neighbor in grid.get_neighbors(coord):
			if not is_visible(neighbor):
				area_visible = false
				break
	if area_visible:
		return observed
	var record := known_lair(coord)
	var kind := String(record.get("kind", "goblin"))
	return maxf(observed, CityDefense.unit_data_power(MonsterDatabase.create_monster(kind, true)))

## Perigo de covil em `coord` só com o conhecimento desta civilização (mesma fórmula do HexGrid).
func known_lair_danger_at(coord: Vector2i) -> float:
	return grid.get_lair_danger_at(coord, observer.explored_tiles) if grid != null and observer != null else 0.0

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
