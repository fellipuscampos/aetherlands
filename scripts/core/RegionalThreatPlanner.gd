class_name RegionalThreatPlanner
extends RefCounted

## Fase 33D2 — COLOCAÇÃO das ameaças do mundo (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md §6/§7).
## Estático e pequeno. Responsável SÓ por: encontrar o local da ameaça regional de uma civilização,
## reusar um covil selvagem compatível, deslocar/remover covil selvagem perto demais da capital, escolher
## o tipo (Goblin/Esqueleto), registrar o papel do covil e sortear o turno de despertar — e, na entrada da
## Ascensão, escolher os Guardiões Troll em recursos que já existem. Não controla MonsterAI, recompensas
## nem o estado do objetivo (dono do registro: RegionalThreatSystem/WorldEventManager).
##
## Determinismo: RNG próprio por assento (map_seed + RNG_SALT + índice × PLAYER_SALT) e varreduras em
## ordem de coordenada; nenhum RNG global nem monster_turn_rng é consumido. Mesma seed + mesma capital +
## mesmo assento → mesmo local, tipo e despertar.

const RING_MIN := 7
const RING_MAX := 10
const RNG_SALT := 8000
const PLAYER_SALT := 7919
const GUARDIAN_SALT := 8100
## Despertar relativo à fundação da capital (não ao turno global): o humano que atrasa a fundação não perde
## o prazo de preparo.
const WAKE_DELAY_MIN := 8
const WAKE_DELAY_MAX := 12
## Outra capital a menos disto → a ameaça evita o corredor direto entre as duas (hemisfério oposto).
const CORRIDOR_RADIUS := 16
## Meia largura (hexes) da faixa entre duas capitais tratada como "corredor direto".
const CORRIDOR_HALF_WIDTH := 4.0
## Distância mínima (hard) de QUALQUER outra capital/âncora; PREFERRED só pesa na pontuação.
const OTHER_CAPITAL_MIN := 7
const OTHER_CAPITAL_PREFERRED := 11
## Realocação de covil selvagem perto demais: anel alvo em volta da capital âncora (fora do anel regional).
const RELOCATE_MIN := 11
const RELOCATE_MAX := 16
## Mesma regra da geração da seed (_spawn_monster_lairs): áreas de covis nunca se sobrepõem.
const LAIR_SPACING := 2

const GOBLIN := "goblin"
const SKELETON := "skeleton"
const TROLL := "troll"
const GOBLIN_BIOMES := [HexTileData.TerrainType.GRASSLAND, HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.FOREST, HexTileData.TerrainType.HILLS]
const SKELETON_BIOMES := [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.TUNDRA]

## Guardiões Troll (Ascensão): recurso de alto valor JÁ EXISTENTE a GUARDIAN_MIN..GUARDIAN_MAX da capital.
const GUARDIAN_MIN := 12
const GUARDIAN_MAX := 20
const GUARDIAN_RESOURCES := ["mana_node", "gems", "silk", "iron", "horses"]
## Cópias do MESMO recurso neste raio da capital formam o "teatro": com uma só cópia livre, não guarda.
const GUARDIAN_THEATER_RADIUS := 20
## Preferência (não regra): longe de ameaça regional ainda viva.
const GUARDIAN_REGIONAL_CLEARANCE := 4

static func rng_for(map_seed: int, player_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + RNG_SALT + player_index * PLAYER_SALT
	return rng

# ---------------------------------------------------------------------------
# Ameaça regional
# ---------------------------------------------------------------------------

## Coloca a ameaça regional de `player` (índice `player_index`) ancorada na capital REAL `capital`.
## `others` = âncoras das outras civilizações (capital real ou, antes de fundar, o tile do Colonizador).
## Devolve {ok, coord, kind, source ("reused"/"created"), wake_turn, visible_at_creation, explored_at_creation,
## boss_coord, relocated, removed, preserved_close, corridor_neighbors, corridor_violation}; ok=false só
## num mapa sem nenhum local legal (mapas de teste minúsculos).
static func place_regional(grid: HexGrid, player: PlayerData, player_index: int, capital: Vector2i, others: Array[Vector2i], turn: int) -> Dictionary:
	var rng := rng_for(grid.map_seed, player_index)
	var wake_turn := turn + rng.randi_range(WAKE_DELAY_MIN, WAKE_DELAY_MAX)
	var result := {
		"ok": false, "coord": HexGrid.NO_LAIR, "kind": "", "source": "", "wake_turn": wake_turn,
		"visible_at_creation": false, "explored_at_creation": false, "boss_coord": HexGrid.NO_LAIR,
		"relocated": 0, "removed": 0, "preserved_close": 0, "corridor_neighbors": 0, "corridor_violation": false,
	}
	grid._ensure_land_components()
	var component: int = grid._land_components.get(capital, -1)
	var close_neighbors: Array[Vector2i] = []
	for other in others:
		if HexMetrics.axial_distance(capital, other) < CORRIDOR_RADIUS:
			close_neighbors.append(other)
	result.corridor_neighbors = close_neighbors.size()
	var visible := grid.compute_visible_tiles(player)
	var anchors: Array[Vector2i] = [capital]
	anchors.append_array(others)
	_clear_close_wild_lairs(grid, player, capital, anchors, component, rng, result)

	# Candidatos novos: anel 7–10, terra do mesmo componente terrestre, legal para um covil. Tile de recurso
	# só como último recurso (península estreita cujo anel é todo recurso): o anel nunca é ampliado.
	var best_new: Dictionary = {}
	for allow_resource in [false, true]:
		for coord in _sorted(HexMetrics.coords_within(capital, RING_MAX)):
			var distance := HexMetrics.axial_distance(capital, coord)
			if distance < RING_MIN:
				continue
			if not _is_legal_new_site(grid, coord, component, anchors, capital, allow_resource):
				continue
			var tile: HexTileData = grid.get_tile(coord)
			var ideal := tile.terrain_type in GOBLIN_BIOMES or tile.terrain_type in SKELETON_BIOMES
			var rank := _rank(coord, capital, others, close_neighbors, visible, player.explored_tiles, ideal, rng.randf())
			if best_new.is_empty() or _rank_less(rank, best_new.rank):
				best_new = {"coord": coord, "rank": rank}
		if not best_new.is_empty():
			break

	# Reuso: covil selvagem Goblin/Esqueleto já no anel, intocado, não pior que o melhor local novo em
	# corredor/visibilidade (o reuso nunca compra densidade às custas de fairness).
	var best_reuse: Dictionary = {}
	for lair_coord in _sorted(grid.lair_coords.duplicate()):
		var kind := String(grid.lair_kind_by_coord.get(lair_coord, ""))
		if kind not in [GOBLIN, SKELETON] or grid.lair_role(lair_coord) != HexGrid.LAIR_ROLE_WILD:
			continue
		var distance := HexMetrics.axial_distance(capital, lair_coord)
		if distance < RING_MIN or distance > RING_MAX or grid._land_components.get(lair_coord, -2) != component:
			continue
		if _min_distance(lair_coord, others) < OTHER_CAPITAL_MIN or is_touched(grid, lair_coord, player):
			continue
		var rank := _rank(lair_coord, capital, others, close_neighbors, visible, player.explored_tiles, true, rng.randf())
		if best_reuse.is_empty() or _rank_less(rank, best_reuse.rank):
			best_reuse = {"coord": lair_coord, "rank": rank}

	var use_reuse := not best_reuse.is_empty() and (best_new.is_empty() or _fairness_tuple(best_reuse.rank) <= _fairness_tuple(best_new.rank))
	if use_reuse:
		var coord: Vector2i = best_reuse.coord
		result.coord = coord
		result.kind = String(grid.lair_kind_by_coord.get(coord, GOBLIN))
		result.source = "reused"
		grid.set_lair_role(coord, HexGrid.LAIR_ROLE_REGIONAL)
		# Os moradores atuais passam a pertencer ao covil regional (população própria desde já).
		for area_coord in grid._lair_area(coord):
			var occupant: Unit = grid.get_unit_at(area_coord)
			if occupant != null and occupant.owner_player == null and not occupant.world_event_managed and occupant.source_lair_coord in [coord, HexGrid.NO_LAIR]:
				occupant.source_lair_coord = coord
	elif not best_new.is_empty():
		var coord: Vector2i = best_new.coord
		var tile: HexTileData = grid.get_tile(coord)
		var boss_coord := _pick_boss_tile(grid, coord, rng)
		result.coord = coord
		result.kind = SKELETON if tile.terrain_type in SKELETON_BIOMES else GOBLIN
		result.source = "created"
		result.boss_coord = boss_coord
		grid.create_lair(coord, result.kind, HexGrid.LAIR_ROLE_REGIONAL, boss_coord)
	else:
		return result
	result.ok = true
	result.visible_at_creation = visible.has(result.coord)
	result.explored_at_creation = player.explored_tiles.has(result.coord)
	for neighbor in close_neighbors:
		if corridor_relation(capital, neighbor, result.coord) == 2:
			result.corridor_violation = true
	return result

## 0 = hemisfério oposto ao vizinho (ângulo ≥ 90° visto da capital); 1 = mesmo hemisfério, fora da faixa
## do corredor; 2 = dentro do corredor direto (projeção entre as duas capitais e desvio lateral ≤
## CORRIDOR_HALF_WIDTH). Geometria em coordenadas cartesianas do hex (1 unidade = 1 passo de hex).
static func corridor_relation(capital: Vector2i, neighbor: Vector2i, coord: Vector2i) -> int:
	var origin := cartesian(capital)
	var axis := cartesian(neighbor) - origin
	var point := cartesian(coord) - origin
	var length := axis.length()
	if length <= 0.0:
		return 0
	var direction := axis / length
	var projection := point.dot(direction)
	if projection <= 0.0:
		return 0
	var lateral := absf(point.x * direction.y - point.y * direction.x)
	if projection < length and lateral <= CORRIDOR_HALF_WIDTH:
		return 2
	return 1

static func cartesian(coord: Vector2i) -> Vector2:
	return Vector2(float(coord.x) + float(coord.y) / 2.0, float(coord.y) * sqrt(3.0) / 2.0)

## Ângulo (graus) entre `coord` e `neighbor` vistos da capital.
static func angle_from(capital: Vector2i, neighbor: Vector2i, coord: Vector2i) -> float:
	var origin := cartesian(capital)
	var a := cartesian(neighbor) - origin
	var b := cartesian(coord) - origin
	if a.length() <= 0.0 or b.length() <= 0.0:
		return 180.0
	return absf(rad_to_deg(a.angle_to(b)))

## Covil já observado/interagido por OUTRA civilização, danificado, alertado ou com papel: o mundo
## observado nunca é teletransportado para acomodar uma capital nova.
static func is_touched(grid: HexGrid, lair_coord: Vector2i, owner: PlayerData) -> bool:
	if grid.lair_role(lair_coord) != HexGrid.LAIR_ROLE_WILD or grid.lair_alert_until_turn.has(lair_coord):
		return true
	var structure: LairStructure = grid.lairs_by_coord.get(lair_coord)
	if structure != null and structure.hp < structure.max_hp:
		return true
	for other in GameManager.players:
		if other != owner and other.explored_tiles.has(lair_coord):
			return true
	for area_coord in grid._lair_area(lair_coord):
		var occupant: Unit = grid.get_unit_at(area_coord)
		if occupant != null and occupant.owner_player == null and occupant.hp < occupant.unit_data.max_hp:
			return true
	return false

## Covil selvagem a < RING_MIN da capital nova: realoca (determinístico) para o anel RELOCATE_MIN..MAX
## ou, sem local legal, remove. Covil tocado (is_touched) é preservado.
static func _clear_close_wild_lairs(grid: HexGrid, player: PlayerData, capital: Vector2i, anchors: Array[Vector2i], component: int, rng: RandomNumberGenerator, result: Dictionary) -> void:
	for lair_coord in _sorted(grid.lair_coords.duplicate()):
		if grid.lair_role(lair_coord) != HexGrid.LAIR_ROLE_WILD or HexMetrics.axial_distance(capital, lair_coord) >= RING_MIN:
			continue
		if is_touched(grid, lair_coord, player):
			result.preserved_close = int(result.preserved_close) + 1
			continue
		var kind := String(grid.lair_kind_by_coord.get(lair_coord, GOBLIN))
		var biomes: Array = MonsterDatabase.KIND_DATA.get(kind, {}).get("biomes", [])
		grid.remove_lair_silently(lair_coord)
		var best: Dictionary = {}
		for coord in _sorted(HexMetrics.coords_within(capital, RELOCATE_MAX)):
			if HexMetrics.axial_distance(capital, coord) < RELOCATE_MIN:
				continue
			if not _is_legal_new_site(grid, coord, component, anchors, capital):
				continue
			var tile: HexTileData = grid.get_tile(coord)
			var score := (0.0 if tile.terrain_type in biomes else 10.0) + float(HexMetrics.axial_distance(lair_coord, coord)) * 0.1 + rng.randf() * 0.01
			if best.is_empty() or score < float(best.score):
				best = {"coord": coord, "score": score}
		if best.is_empty():
			result.removed = int(result.removed) + 1
			continue
		grid.create_lair(best.coord, kind, HexGrid.LAIR_ROLE_WILD, _pick_boss_tile(grid, best.coord, rng))
		result.relocated = int(result.relocated) + 1

## Tile onde um covil NOVO pode nascer: terra do mesmo componente da capital, sem unidade/cidade/covil/
## construção/recurso, fora de território de qualquer cidade, longe de outras âncoras e das áreas de
## outros covis, com pelo menos um vizinho livre para o chefe.
static func _is_legal_new_site(grid: HexGrid, coord: Vector2i, component: int, anchors: Array[Vector2i], own_capital: Vector2i, allow_resource: bool = false) -> bool:
	var tile: HexTileData = grid.get_tile(coord)
	if tile == null or tile.blocks_land_units() or (tile.resource != "" and not allow_resource):
		return false
	if grid._land_components.get(coord, -2) != component:
		return false
	if grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or grid.lairs_by_coord.has(coord) or grid.buildings_by_coord.has(coord):
		return false
	if grid.city_owning_tile(coord) != null:
		return false
	for anchor in anchors:
		if anchor != own_capital and HexMetrics.axial_distance(anchor, coord) < OTHER_CAPITAL_MIN:
			return false
	for lair_coord in grid.lair_coords:
		if HexMetrics.axial_distance(lair_coord, coord) <= LAIR_SPACING:
			return false
	return not _free_boss_tiles(grid, coord).is_empty()

static func _free_boss_tiles(grid: HexGrid, lair_coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in grid.get_neighbors(lair_coord):
		var tile: HexTileData = grid.get_tile(neighbor)
		if tile == null or tile.blocks_land_units() or grid.get_unit_at(neighbor) != null or grid.get_city_at(neighbor) != null or grid.lairs_by_coord.has(neighbor):
			continue
		result.append(neighbor)
	return _sorted(result)

static func _pick_boss_tile(grid: HexGrid, lair_coord: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var free := _free_boss_tiles(grid, lair_coord)
	if free.is_empty():
		return HexGrid.NO_LAIR
	return free[rng.randi_range(0, free.size() - 1)]

## Ordem lexicográfica de preferência: [corredor, visível, bioma não ideal, explorado] (menor é melhor)
## e então a pontuação (maior é melhor): meio do anel, longe das outras capitais, maior ângulo em relação
## aos vizinhos próximos, desempate pelo RNG do assento.
static func _rank(coord: Vector2i, capital: Vector2i, others: Array[Vector2i], close_neighbors: Array[Vector2i], visible: Dictionary, explored: Dictionary, ideal_biome: bool, tie: float) -> Array:
	var corridor := 0
	var min_angle := 180.0
	for neighbor in close_neighbors:
		corridor = maxi(corridor, corridor_relation(capital, neighbor, coord))
		min_angle = minf(min_angle, angle_from(capital, neighbor, coord))
	var distance := HexMetrics.axial_distance(capital, coord)
	var score := -absf(float(distance) - 8.5) * 0.5
	score += minf(float(_min_distance(coord, others)), float(OTHER_CAPITAL_PREFERRED) + 9.0) * 0.1
	score += min_angle / 180.0 * 2.0
	score += tie * 0.01
	return [corridor, 1 if visible.has(coord) else 0, 0 if ideal_biome else 1, 1 if explored.has(coord) else 0, -score]

static func _fairness_tuple(rank: Array) -> Array:
	return [rank[0], rank[1]]

static func _rank_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

static func _min_distance(coord: Vector2i, others: Array[Vector2i]) -> int:
	var best := 999999
	for other in others:
		best = mini(best, HexMetrics.axial_distance(coord, other))
	return best

static func _sorted(coords: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in coords:
		result.append(coord)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

# ---------------------------------------------------------------------------
# Guardiões Troll (entrada da Ascensão)
# ---------------------------------------------------------------------------

## Escolhe e cria até 1 Guardião Troll por civilização ativa (`anchors`: índice → capital), só em
## recursos de alto valor que já existem, livres (sem cidade, território, melhoria, construção ou
## unidade), a GUARDIAN_MIN..GUARDIAN_MAX da capital e a ≥ GUARDIAN_MIN de todas as capitais. Nunca guarda
## a única cópia livre daquele recurso no teatro da civilização. Recurso escolhido por duas civs → um só
## site, associado às duas. Devolve {sites: [{coord, resource_coord, resource, for_players}], stats}.
static func place_guardians(grid: HexGrid, anchors: Dictionary, unresolved_regional: Array[Vector2i]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = grid.map_seed + GUARDIAN_SALT
	grid._ensure_land_components()
	var stats := {"candidates_by_player": {}, "no_candidate": [], "skipped_sole": 0, "shared": 0}
	var sites: Array = []
	var capitals: Array[Vector2i] = []
	for index in _sorted_keys(anchors):
		capitals.append(anchors[index])
	# Uma varredura do mapa: todas as cópias de cada recurso de alto valor (oferta do teatro) e, entre elas,
	# as livres (candidatas). Ordenação só da lista curta de recursos, nunca do mapa inteiro.
	var copies_by_resource := {}
	var free_resources: Array = []
	for coord in grid.tiles:
		var tile: HexTileData = grid.tiles[coord]
		if not tile.resource in GUARDIAN_RESOURCES:
			continue
		if not copies_by_resource.has(tile.resource):
			copies_by_resource[tile.resource] = []
		copies_by_resource[tile.resource].append(coord)
		if not tile.blocks_land_units() and _is_free_resource(grid, coord):
			free_resources.append(coord)
	var resources := _sorted(free_resources)
	var guarded := {}
	for index in _sorted_keys(anchors):
		var capital: Vector2i = anchors[index]
		var component: int = grid._land_components.get(capital, -1)
		var best_by_resource := {}
		var candidates := 0
		for coord in resources:
			var distance := HexMetrics.axial_distance(capital, coord)
			if distance < GUARDIAN_MIN or distance > GUARDIAN_MAX or grid._land_components.get(coord, -2) != component:
				continue
			if _min_distance(coord, capitals) < GUARDIAN_MIN:
				continue
			var lair_tile := _guardian_lair_tile(grid, coord, rng)
			if lair_tile == HexGrid.NO_LAIR and not guarded.has(coord):
				continue
			candidates += 1
			var resource := String(grid.tiles[coord].resource)
			if not guarded.has(coord) and _unguarded_copies(grid, copies_by_resource.get(resource, []), guarded, capital, component) <= 1:
				stats.skipped_sole = int(stats.skipped_sole) + 1
				continue
			var score := -absf(float(distance) - 16.0) * 0.05 + rng.randf() * 0.01
			if _min_distance(coord, unresolved_regional) <= GUARDIAN_REGIONAL_CLEARANCE:
				score -= 5.0
			var current: Dictionary = best_by_resource.get(resource, {})
			if current.is_empty() or score > float(current.score):
				best_by_resource[resource] = {"coord": coord, "score": score, "lair": lair_tile}
		stats.candidates_by_player[str(index)] = candidates
		if best_by_resource.is_empty():
			stats.no_candidate.append(index)
			continue
		# Todos os GUARDIAN_RESOURCES já são "alto valor" no catálogo. O TIPO é sorteado entre os disponíveis
		# para esta civ (depois o melhor tile dele): o recurso livre mais abundante do mapa (em geral o Nódulo
		# Arcano) não vira o alvo de todo Guardião, concentrando o bloqueio num único recurso de vitória.
		var types := best_by_resource.keys()
		types.sort()
		var best: Dictionary = best_by_resource[types[rng.randi_range(0, types.size() - 1)]]
		if guarded.has(best.coord):
			var shared: Dictionary = sites[int(guarded[best.coord])]
			shared.for_players.append(index)
			stats.shared = int(stats.shared) + 1
			continue
		var resource_coord: Vector2i = best.coord
		var lair_coord: Vector2i = best.lair
		grid.create_lair(lair_coord, TROLL, HexGrid.LAIR_ROLE_GUARDIAN, resource_coord)
		guarded[resource_coord] = sites.size()
		sites.append({"coord": lair_coord, "resource_coord": resource_coord, "resource": String(grid.tiles[resource_coord].resource), "for_players": [index]})
	return {"sites": sites, "stats": stats}

## Recurso ainda "livre": sem cidade, território, melhoria, construção, covil ou unidade.
static func _is_free_resource(grid: HexGrid, coord: Vector2i) -> bool:
	if grid.get_city_at(coord) != null or grid.city_owning_tile(coord) != null or grid.buildings_by_coord.has(coord):
		return false
	if grid.lairs_by_coord.has(coord) or grid.get_unit_at(coord) != null:
		return false
	for city in grid.cities_by_coord.values():
		if (city as City).resource_improvements.has(coord):
			return false
	return true

## Tile vizinho do recurso para a caverna (o Troll fica EM CIMA do recurso): terra sem recurso, livre, fora
## de território, sem sobrepor a área de outro covil.
static func _guardian_lair_tile(grid: HexGrid, resource_coord: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var options: Array[Vector2i] = []
	for neighbor in _sorted(grid.get_neighbors(resource_coord)):
		var tile: HexTileData = grid.get_tile(neighbor)
		if tile == null or tile.blocks_land_units() or tile.resource != "":
			continue
		if grid.get_unit_at(neighbor) != null or grid.get_city_at(neighbor) != null or grid.buildings_by_coord.has(neighbor) or grid.city_owning_tile(neighbor) != null:
			continue
		var spaced := true
		for lair_coord in grid.lair_coords:
			if HexMetrics.axial_distance(lair_coord, neighbor) <= LAIR_SPACING:
				spaced = false
				break
		if spaced:
			options.append(neighbor)
	if options.is_empty():
		return HexGrid.NO_LAIR
	return options[rng.randi_range(0, options.size() - 1)]

## Cópias do recurso no teatro da civilização que continuariam SEM guardião (livres, já dela ou de
## outros — qualquer cópia que não esteja guardada conta como oferta disponível).
static func _unguarded_copies(grid: HexGrid, copies: Array, guarded: Dictionary, capital: Vector2i, component: int) -> int:
	var count := 0
	for coord in copies:
		if guarded.has(coord) or HexMetrics.axial_distance(capital, coord) > GUARDIAN_THEATER_RADIUS:
			continue
		if grid._land_components.get(coord, -2) == component:
			count += 1
	return count

static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
