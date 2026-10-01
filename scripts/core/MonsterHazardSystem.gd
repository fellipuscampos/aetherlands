class_name MonsterHazardSystem
extends RefCounted

## V3 / Etapa 2 — perigos ESPACIAIS temporários criados por criaturas avançadas: Raízes do Mundo (Ancião
## Arbóreo), Contaminação Micótica (Colmeia) e o Rastro Subterrâneo do Verme Colossal (telegraph).
##
## Por que não reusa V2EnvironmentalZoneSystem/V2TerrainRuntime: zonas ambientais pertencem a um conjurador de
## civilização (dono, Escola, dano por rodada fixo) e modificações de terreno são físicas e PERMANENTES até um
## feitiço removê-las. Raízes/infecção não têm dono de civilização, expiram/decaem sozinhas e valem só contra
## unidades de civilização — então ficam numa coleção própria, pequena e fixa (≤ 4 tiles por lançamento de
## raízes, ≤ 12 por Colmeia). Nunca alteram o terreno-base; nada roda por frame.
##
## Estado (salvo dentro do bloco combat_ecology): raízes {coord: rodada de expiração}, infecções por sítio
## {site, anchor, tiles, decay, started} e o último turno em que cada unidade sofreu o dano da infecção.

const ROOT_MARKER_COLOR := Color(0.42, 0.3, 0.12)
const INFECTION_MARKER_COLOR := Color(0.85, 0.35, 0.65)
const TELEGRAPH_MARKER_COLOR := Color(0.95, 0.55, 0.15)
## Custo extra de caminho (só avaliação de rota) de um tile infectado CONHECIDO pela civilização.
const KNOWN_INFECTION_PATH_PENALTY := 3.0

static var roots: Dictionary = {} # Vector2i -> int (turno global de expiração, exclusivo)
static var infections: Array[Dictionary] = [] # {site, anchor, tiles: Array[Vector2i], decay: int, started: bool}
static var infection_ticks: Dictionary = {} # serial_id -> último turno de dano da infecção
static var _infected: Dictionary = {} # Vector2i -> true (índice derivado)
static var _markers: Dictionary = {} # "kind:x:y" -> Node3D (só visual)

static func reset() -> void:
	_clear_markers()
	roots = {}
	infections = []
	infection_ticks = {}
	_infected = {}

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

static func is_root(coord: Vector2i) -> bool:
	return roots.has(coord) and int(roots[coord]) > TurnManager.turn_number

static func is_infected(coord: Vector2i) -> bool:
	return _infected.has(coord)

## Custo extra de MOVIMENTO real para unidade de civilização (HexGrid.terrain_step_cost). Fast path sem raízes.
static func root_cost(coord: Vector2i) -> float:
	if roots.is_empty() or not is_root(coord):
		return 0.0
	return float(MonsterAbilityData.param(MonsterAbilityData.ROOTS_OF_THE_WORLD, "move_cost", 2.0))

## Custo extra só de AVALIAÇÃO de caminho (HexGrid.compute_path): infecção que a civilização já conhece.
static func path_penalty(coord: Vector2i, owner: PlayerData) -> float:
	if owner == null or _infected.is_empty() or not _infected.has(coord) or not owner.explored_tiles.has(coord):
		return 0.0
	return KNOWN_INFECTION_PATH_PENALTY

## Multiplicador de cura recebida (cura de guarnição/fortificar/regeneração/feitiço) de unidade de civilização.
static func heal_multiplier(unit: Unit) -> float:
	if unit == null or unit.owner_player == null or _infected.is_empty() or not _infected.has(unit.coord):
		return 1.0
	return float(MonsterAbilityData.param(MonsterAbilityData.MYCOTIC_CONTAMINATION, "heal_multiplier", 0.5))

static func infected_count() -> int:
	return _infected.size()

static func infection_for_site(site_id: int) -> Dictionary:
	for entry in infections:
		if int(entry.site) == site_id:
			return entry
	return {}

# ---------------------------------------------------------------------------
# Raízes do Mundo
# ---------------------------------------------------------------------------

static func add_roots(grid: HexGrid, coords: Array[Vector2i], rounds: int) -> void:
	var expiry := TurnManager.turn_number + rounds
	for coord in coords:
		roots[coord] = maxi(int(roots.get(coord, 0)), expiry)
		_refresh_marker(grid, "root", coord, true)

# ---------------------------------------------------------------------------
# Infecção
# ---------------------------------------------------------------------------

static func _infectable(grid: HexGrid, coord: Vector2i) -> bool:
	var tile: HexTileData = grid.get_tile(coord)
	return tile != null and not tile.blocks_land_units() and grid.get_city_at(coord) == null

static func _rebuild_index() -> void:
	_infected = {}
	for entry in infections:
		for coord in entry.tiles:
			_infected[coord] = true

## Rodada global (MonsterEcologySystem.process_round, fase dos monstros): raízes expiram; cada Colmeia viva
## inicia (âncora + raio 1) ou cresce 1 tile adjacente à infecção (raio ≤ 2, ≤ 12); Colmeia morta decai em duas
## rodadas (metade mais distante da âncora primeiro). Determinístico por distância/coordenada.
static func process_round(grid: HexGrid, turn: int, live_hive_sites: Dictionary) -> void:
	for coord in roots.keys():
		if int(roots[coord]) <= turn:
			roots.erase(coord)
			_refresh_marker(grid, "root", coord, false)
	var params := MonsterAbilityData.get_ability(MonsterAbilityData.MYCOTIC_CONTAMINATION)
	var max_radius := int(params.get("max_radius", 2))
	var max_tiles := int(params.get("max_tiles", 12))
	for site_id in MonsterEcologyPlanner.sorted_ints(live_hive_sites.keys()):
		if infection_for_site(int(site_id)).is_empty():
			infections.append({"site": int(site_id), "anchor": live_hive_sites[site_id], "tiles": [] as Array[Vector2i], "decay": 0, "started": false})
	var kept: Array[Dictionary] = []
	for entry in infections:
		var site_id := int(entry.site)
		var anchor: Vector2i = entry.anchor
		if live_hive_sites.has(site_id):
			entry.decay = 0
			if not bool(entry.started):
				entry.started = true
				for coord in [anchor] + MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(anchor)):
					if _infectable(grid, coord) and not coord in entry.tiles:
						entry.tiles.append(coord)
						MonsterEcologySystem.emit_event("infection_spread", "mycotic_hive", {"tiles": entry.tiles.size()})
			elif entry.tiles.size() < max_tiles:
				var best := HexGrid.NO_LAIR
				for coord in entry.tiles:
					for neighbor in grid.get_neighbors(coord):
						if neighbor in entry.tiles or HexMetrics.axial_distance(anchor, neighbor) > max_radius or not _infectable(grid, neighbor):
							continue
						if best == HexGrid.NO_LAIR or _infection_order(anchor, neighbor, best):
							best = neighbor
				if best != HexGrid.NO_LAIR:
					entry.tiles.append(best)
					MonsterEcologySystem.emit_event("infection_spread", "mycotic_hive", {"tiles": entry.tiles.size()})
			kept.append(entry)
			continue
		# Colmeia morta: decai em duas rodadas.
		entry.decay = int(entry.decay) + 1
		var ordered: Array = entry.tiles.duplicate()
		ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _infection_order(anchor, b, a))
		if int(entry.decay) == 1 and ordered.size() > 1:
			var remove_count := int(ceil(ordered.size() / 2.0))
			entry.tiles = _typed(ordered.slice(remove_count))
			kept.append(entry)
		# decay >= 2 (ou 1 tile só): some de vez.
	infections = kept
	var before := _infected.duplicate()
	_rebuild_index()
	for coord in before:
		if not _infected.has(coord):
			_refresh_marker(grid, "infection", coord, false)
	for coord in _infected:
		if not before.has(coord):
			_refresh_marker(grid, "infection", coord, true)

## Ordem de expansão/decaimento: mais perto da âncora primeiro, depois coordenada.
static func _infection_order(anchor: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	var da := HexMetrics.axial_distance(anchor, a)
	var db := HexMetrics.axial_distance(anchor, b)
	if da != db:
		return da < db
	return a.x < b.x if a.x != b.x else a.y < b.y

static func _typed(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(value)
	return result

## Dano da infecção: 3% da Vida máxima (1–3), no máximo UMA vez por turno por unidade de civilização. Ao ENTRAR
## (HexGrid.move_unit/teleport_unit) nunca mata na hora (fica com ≥ 1 Vida, o movimento em curso não é cortado);
## no início do turno (GameManager._finish_turn) pode matar. Nunca afeta cidade nem melhoria.
static func damage_on(unit: Unit, grid: HexGrid, entering: bool) -> void:
	if unit == null or not is_instance_valid(unit) or unit.owner_player == null or unit.hp <= 0.0 or not _infected.has(unit.coord):
		return
	var turn := TurnManager.turn_number
	if int(infection_ticks.get(unit.serial_id, -1)) == turn:
		return
	infection_ticks[unit.serial_id] = turn
	var params := MonsterAbilityData.get_ability(MonsterAbilityData.MYCOTIC_CONTAMINATION)
	var damage := clampf(unit.unit_data.max_hp * float(params.damage_fraction), float(params.damage_min), float(params.damage_max))
	if entering:
		damage = minf(damage, maxf(unit.hp - 1.0, 0.0))
	if damage <= 0.0:
		return
	var owner_index := GameManager.players.find(unit.owner_player)
	var killed := CombatResolver.apply_environmental_unit_damage(unit, damage, grid)
	MonsterEcologySystem.emit_event("infection_damage", "mycotic_hive", {"damage": damage, "killed": killed, "target": owner_index})

static func on_unit_entered(unit: Unit, grid: HexGrid) -> void:
	if _infected.is_empty():
		return
	damage_on(unit, grid, true)

## Início do turno (GameManager._finish_turn): quem começa o turno num tile infectado.
static func process_turn_start(players: Array, grid: HexGrid) -> void:
	if _infected.is_empty():
		return
	for player in players:
		if player == null:
			continue
		for unit in player.units.duplicate():
			if is_instance_valid(unit) and _infected.has(unit.coord):
				damage_on(unit, grid, false)

# ---------------------------------------------------------------------------
# IA de civilização: só perigo VISÍVEL/CONHECIDO
# ---------------------------------------------------------------------------

## Tile perigoso para `player`: infecção/raiz conhecida (explorada) ou o impacto de um Rastro Subterrâneo VISÍVEL agora.
static func known_danger(coord: Vector2i, player: PlayerData, visible: Dictionary) -> bool:
	if player == null:
		return false
	if (_infected.has(coord) or is_root(coord)) and player.explored_tiles.has(coord):
		return true
	# Rastro Subterrâneo visível: a IA sai do tile de IMPACTO previsto (os vizinhos ainda levam o golpe de 80% —
	# reação deliberadamente imperfeita; a leitura completa da área fica para o jogador).
	for dest in MonsterAbilitySystem.telegraph_coords():
		if dest == coord and visible.has(dest):
			return true
	return false

## Uma unidade de IA parada em perigo conhecido (infecção/raiz conhecida ou área do telegraph visível) e sem
## inimigo colado sai para o tile alcançável seguro mais barato. true = gastou a ação saindo. Não exige
## perfeição: sem tile seguro, fica.
static func ai_evade(unit: Unit, grid: HexGrid, visible: Dictionary) -> bool:
	if unit == null or unit.movement_left <= 0.0 or (roots.is_empty() and _infected.is_empty() and MonsterAbilitySystem.telegraph_coords().is_empty()):
		return false
	if not known_danger(unit.coord, unit.owner_player, visible):
		return false
	for neighbor in grid.get_neighbors(unit.coord):
		var other := grid.get_unit_at(neighbor)
		if other != null and other != unit and CombatResolver.is_hostile_unit_target(unit.owner_player, other, grid):
			return false
	var reachable := grid.unit_reachable(unit)
	var best := HexGrid.NO_LAIR
	var best_cost := INF
	for coord in MonsterEcologyPlanner.sorted_coords(reachable.keys()):
		if known_danger(coord, unit.owner_player, visible):
			continue
		if float(reachable[coord]) < best_cost:
			best_cost = float(reachable[coord])
			best = coord
	if best == HexGrid.NO_LAIR:
		return false
	grid.move_unit(unit, best, best_cost)
	MonsterEcologySystem.emit_event("ai_evade", "", {"target": GameManager.players.find(unit.owner_player)}, false)
	return true

# ---------------------------------------------------------------------------
# Visual (placeholder legível, sem _process): disco + aro por tile, gated pela neblina do humano
# ---------------------------------------------------------------------------

static func _root_node(grid: HexGrid) -> Node3D:
	var node: Node3D = grid.get_node_or_null("MonsterHazards")
	if node == null:
		node = Node3D.new()
		node.name = "MonsterHazards"
		grid.add_child(node)
	return node

static func _refresh_marker(grid: HexGrid, kind: String, coord: Vector2i, present: bool) -> void:
	if grid == null:
		return
	var key := "%s:%d:%d" % [kind, coord.x, coord.y]
	var old: Node3D = _markers.get(key, null)
	if old != null:
		if is_instance_valid(old):
			old.queue_free()
		_markers.erase(key)
	if not present or not grid.tiles.has(coord) or not grid.is_inside_tree():
		return
	var color := ROOT_MARKER_COLOR if kind == "root" else (INFECTION_MARKER_COLOR if kind == "infection" else TELEGRAPH_MARKER_COLOR)
	var marker := Node3D.new()
	marker.name = "Hazard_%s_%d_%d" % [kind, coord.x, coord.y]
	marker.set_meta("coord", coord)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.45 if kind != "telegraph" else 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.5
	disc_mesh.bottom_radius = 0.5
	disc_mesh.height = 0.03
	disc_mesh.radial_segments = 6
	disc.mesh = disc_mesh
	disc.material_override = material
	marker.add_child(disc)
	match kind:
		"root":
			# Raízes: três toras baixas cruzadas.
			var wood := StandardMaterial3D.new()
			wood.albedo_color = color.darkened(0.2)
			for i in 3:
				var log := MeshInstance3D.new()
				var log_mesh := BoxMesh.new()
				log_mesh.size = Vector3(0.7, 0.06, 0.08)
				log.mesh = log_mesh
				log.material_override = wood
				log.position = Vector3(0, 0.05, 0)
				log.rotation_degrees = Vector3(0, i * 60.0, 0)
				marker.add_child(log)
		"infection":
			# Infecção: dois cogumelos rosados.
			var cap := StandardMaterial3D.new()
			cap.albedo_color = color
			cap.emission_enabled = true
			cap.emission = color
			cap.emission_energy_multiplier = 0.6
			for offset in [Vector3(-0.18, 0, 0.12), Vector3(0.2, 0, -0.1)]:
				var mushroom := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.09
				sphere.height = 0.09
				mushroom.mesh = sphere
				mushroom.material_override = cap
				mushroom.position = offset + Vector3(0, 0.08, 0)
				marker.add_child(mushroom)
		"telegraph":
			# Rastro Subterrâneo: aro laranja + monte de terra.
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.55
			ring.mesh = torus
			var ring_material := material.duplicate() as StandardMaterial3D
			ring_material.emission_enabled = true
			ring_material.emission = color
			ring_material.emission_energy_multiplier = 1.4
			ring.material_override = ring_material
			ring.position.y = 0.04
			marker.add_child(ring)
			var mound := MeshInstance3D.new()
			var mound_mesh := SphereMesh.new()
			mound_mesh.radius = 0.22
			mound_mesh.height = 0.18
			mound.mesh = mound_mesh
			var dirt := StandardMaterial3D.new()
			dirt.albedo_color = Color(0.45, 0.32, 0.2)
			mound.material_override = dirt
			mound.position.y = 0.05
			marker.add_child(mound)
	_root_node(grid).add_child(marker)
	marker.position = grid.world_surface_for_coord(coord) + Vector3(0.0, 0.04, 0.0)
	marker.visible = grid.visibility.is_empty() or grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE
	_markers[key] = marker

static func set_telegraph(grid: HexGrid, coord: Vector2i, present: bool) -> void:
	_refresh_marker(grid, "telegraph", coord, present)

## Neblina do humano (HexGrid._apply_fog_to_entities): o marcador segue a visão ATUAL do tile.
static func apply_fog(grid: HexGrid) -> void:
	for marker in _markers.values():
		if is_instance_valid(marker):
			var coord: Vector2i = marker.get_meta("coord")
			marker.visible = grid.visibility.is_empty() or grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

static func _clear_markers() -> void:
	for marker in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	_markers = {}

## Reconstrói todos os marcadores a partir do estado (load).
static func rebuild_markers(grid: HexGrid) -> void:
	_clear_markers()
	for coord in roots:
		_refresh_marker(grid, "root", coord, true)
	for coord in _infected:
		_refresh_marker(grid, "infection", coord, true)
	for coord in MonsterAbilitySystem.telegraph_coords():
		_refresh_marker(grid, "telegraph", coord, true)

# ---------------------------------------------------------------------------
# Persistência
# ---------------------------------------------------------------------------

static func to_save_dict() -> Dictionary:
	var saved_roots: Array = []
	for coord in roots:
		saved_roots.append([coord.x, coord.y, int(roots[coord])])
	var saved_infections: Array = []
	for entry in infections:
		var tiles: Array = []
		for coord in entry.tiles:
			tiles.append([coord.x, coord.y])
		saved_infections.append({"site": int(entry.site), "anchor": [entry.anchor.x, entry.anchor.y], "tiles": tiles, "decay": int(entry.decay), "started": bool(entry.started)})
	var ticks: Array = []
	for serial in infection_ticks:
		ticks.append([int(serial), int(infection_ticks[serial])])
	return {"roots": saved_roots, "infections": saved_infections, "infection_ticks": ticks}

static func load_save_dict(data: Variant, grid: HexGrid) -> void:
	reset()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for entry in data.get("roots", []):
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 3:
			roots[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	for entry in data.get("infections", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tiles: Array[Vector2i] = []
		for coord in entry.get("tiles", []):
			if typeof(coord) == TYPE_ARRAY and (coord as Array).size() >= 2:
				tiles.append(Vector2i(int(coord[0]), int(coord[1])))
		var anchor_value: Variant = entry.get("anchor", [0, 0])
		infections.append({"site": int(entry.get("site", -1)), "anchor": Vector2i(int(anchor_value[0]), int(anchor_value[1])), "tiles": tiles, "decay": int(entry.get("decay", 0)), "started": bool(entry.get("started", true))})
	for entry in data.get("infection_ticks", []):
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
			infection_ticks[int(entry[0])] = int(entry[1])
	_rebuild_index()
	if grid != null:
		rebuild_markers(grid)
