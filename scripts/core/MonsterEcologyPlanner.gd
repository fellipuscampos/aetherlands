class_name MonsterEcologyPlanner
extends RefCounted

## V3 / Combat Ecology — Etapa 1. Regras PURAS de colocação dos sítios ecológicos (setup e reposição):
## terra elegível, legalidade de tile, zona de segurança das capitais por tier, espaçamento entre sítios,
## folga de covis e tiles do grupo. Não guarda estado, não spawna e não consome RNG próprio — quem
## orquestra (e passa o RNG dedicado da ecologia) é o MonsterEcologySystem.
##
## Não é o RegionalThreatPlanner: aquele continua dono da ameaça garantida por capital (7–10). Este só
## espalha a população WILD/ECOLOGY pelo continente principal.

## Terra ESTÁTICA elegível (ordenada): continente principal (zona MAIN do mapa padrão; mapas menores são
## inteiros MAIN), terreno que não bloqueia unidade terrestre, massa de terra >= MIN_LANDMASS e sem
## recurso (recursos ficam para cidades/Guardiões Troll). Estado dinâmico (unidade, cidade, território,
## construção, covil) é checado por is_legal_spawn_tile no momento da colocação.
static func eligible_tiles(grid: HexGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid == null:
		return result
	grid._ensure_land_components()
	for coord in grid.tiles:
		var tile: HexTileData = grid.tiles[coord]
		if tile.blocks_land_units() or tile.resource != "":
			continue
		if grid._zone_for(coord) != HexGrid._Zone.MAIN:
			continue
		if grid.land_component_size(coord) < MonsterEcologyData.MIN_LANDMASS:
			continue
		result.append(coord)
	return sorted_coords(result)

## Tile onde um monstro ecológico pode NASCER agora: elegível estaticamente e livre de unidade, cidade,
## território de cidade, construção, estrutura de covil, portal e marcador de evento mundial.
static func is_legal_spawn_tile(grid: HexGrid, coord: Vector2i) -> bool:
	var tile: HexTileData = grid.get_tile(coord)
	if tile == null or tile.blocks_land_units() or tile.resource != "":
		return false
	if grid._zone_for(coord) != HexGrid._Zone.MAIN or grid.land_component_size(coord) < MonsterEcologyData.MIN_LANDMASS:
		return false
	if grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or grid.city_owning_tile(coord) != null:
		return false
	if grid.buildings_by_coord.has(coord) or grid.lairs_by_coord.has(coord) or coord in grid.lair_coords:
		return false
	if grid.v2_portal_endpoint_index.has(coord):
		return false
	return not _near_world_event_site(coord)

static func _near_world_event_site(coord: Vector2i) -> bool:
	for event in WorldEventManager.active_events:
		if event is ReliquaryEvent and (event as ReliquaryEvent).site_coord != ReliquaryEvent.NO_COORD and HexMetrics.axial_distance((event as ReliquaryEvent).site_coord, coord) <= 2:
			return true
	return false

## Zona de segurança: `coord` a >= CAPITAL_MIN_DISTANCE[tier] de toda âncora de capital.
static func capital_distance_ok(coord: Vector2i, tier: String, anchors: Array[Vector2i]) -> bool:
	var minimum := int(MonsterEcologyData.CAPITAL_MIN_DISTANCE.get(tier, 0))
	for anchor in anchors:
		if HexMetrics.axial_distance(anchor, coord) < minimum:
			return false
	return true

## Espaçamento: par (novo, existente) exige o MAIOR dos dois SITE_SPACING.
static func spacing_ok(coord: Vector2i, tier: String, sites: Array) -> bool:
	var own := int(MonsterEcologyData.SITE_SPACING.get(tier, 0))
	for site in sites:
		var other := int(MonsterEcologyData.SITE_SPACING.get(MonsterEcologyData.tier_of(String(site.species)), 0))
		if HexMetrics.axial_distance(site.anchor, coord) < maxi(own, other):
			return false
	return true

## Nenhum sítio novo encosta na área (raio 1) de um covil existente (selvagem, regional, guardião).
static func lair_clearance_ok(grid: HexGrid, coord: Vector2i) -> bool:
	for lair_coord in grid.lair_coords:
		if HexMetrics.axial_distance(lair_coord, coord) < MonsterEcologyData.LAIR_CLEARANCE:
			return false
	return true

## Memória de esvaziamento: nenhum sítio novo a REFILL_DEPLETED_RADIUS de um sítio esvaziado há menos de
## REFILL_DEPLETED_COOLDOWN rodadas.
static func depletion_ok(coord: Vector2i, depleted: Array, turn: int) -> bool:
	for entry in depleted:
		if turn - int(entry.turn) < MonsterEcologyData.REFILL_DEPLETED_COOLDOWN and HexMetrics.axial_distance(entry.coord, coord) <= MonsterEcologyData.REFILL_DEPLETED_RADIUS:
			return false
	return true

## Tiles do grupo: a âncora (se legal e `anchor_occupiable`) e depois os vizinhos legais em ordem estável,
## todos dentro da zona de segurança do tier — até `count`.
static func group_tiles(grid: HexGrid, anchor: Vector2i, count: int, tier: String, anchors: Array[Vector2i], anchor_occupiable: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if anchor_occupiable and is_legal_spawn_tile(grid, anchor) and capital_distance_ok(anchor, tier, anchors):
		result.append(anchor)
	for neighbor in sorted_coords(grid.get_neighbors(anchor)):
		if result.size() >= count:
			break
		if is_legal_spawn_tile(grid, neighbor) and capital_distance_ok(neighbor, tier, anchors):
			result.append(neighbor)
	return result

## Âncora nova completa para um sítio de `tier`: tile legal, zona de segurança, espaçamento, folga de
## covil e o grupo inteiro cabendo.
static func is_valid_new_anchor(grid: HexGrid, coord: Vector2i, tier: String, group: int, anchors: Array[Vector2i], sites: Array) -> bool:
	if not is_legal_spawn_tile(grid, coord) or not capital_distance_ok(coord, tier, anchors):
		return false
	if not spacing_ok(coord, tier, sites) or not lair_clearance_ok(grid, coord):
		return false
	return group_tiles(grid, coord, group, tier, anchors).size() >= group

## Tiles bloqueados para REPOSIÇÃO: visíveis agora para qualquer civilização ativa ou a menos de
## REFILL_MIN_CIV_DISTANCE de qualquer unidade/cidade de civilização. Calculado uma vez por tentativa.
static func refill_blocked_tiles(grid: HexGrid, players: Array) -> Dictionary:
	var blocked := {}
	for player in players:
		if player == null:
			continue
		blocked.merge(grid.compute_visible_tiles(player))
		var coords: Array[Vector2i] = []
		for unit in player.units:
			if is_instance_valid(unit):
				coords.append(unit.coord)
		for city in player.cities:
			coords.append(city.coord)
		for coord in coords:
			blocked[coord] = true
			for near in HexMetrics.coords_within(coord, MonsterEcologyData.REFILL_MIN_CIV_DISTANCE - 1):
				blocked[near] = true
	return blocked

## Uma âncora de REPOSIÇÃO por amostragem aleatória da terra elegível (sem varrer o mapa): fora de toda
## visão de civilização, nunca adjacente a unidade/cidade, fora da memória de esvaziamento recente e com
## as mesmas regras de colocação do setup. NO_LAIR se nenhuma amostra servir (tenta de novo na próxima rodada).
static func find_refill_anchor(grid: HexGrid, eligible: Array[Vector2i], tier: String, group: int, anchors: Array[Vector2i], sites: Array, depleted: Array, blocked: Dictionary, turn: int, rng: RandomNumberGenerator) -> Vector2i:
	if eligible.is_empty():
		return HexGrid.NO_LAIR
	for attempt in MonsterEcologyData.REFILL_SAMPLE_ATTEMPTS:
		var coord: Vector2i = eligible[rng.randi_range(0, eligible.size() - 1)]
		if blocked.has(coord) or not depletion_ok(coord, depleted, turn):
			continue
		if not is_valid_new_anchor(grid, coord, tier, group, anchors, sites):
			continue
		var members := group_tiles(grid, coord, group, tier, anchors)
		var clear := true
		for member in members:
			if blocked.has(member):
				clear = false
				break
		if clear:
			return coord
	return HexGrid.NO_LAIR

## Cotas por espécie dentro do tier (aproximadamente uniforme): o resto da divisão vai para espécies a
## partir de uma rotação sorteada, para nenhuma espécie ser sempre a favorecida.
static func species_quotas(tier: String, target: int, rng: RandomNumberGenerator) -> Dictionary:
	var species := MonsterEcologyData.species_of_tier(tier)
	var quotas := {}
	if species.is_empty():
		return quotas
	var base := target / species.size()
	var remainder := target % species.size()
	var start := rng.randi_range(0, species.size() - 1)
	for i in species.size():
		quotas[species[i]] = base
	for k in remainder:
		var kind: String = species[(start + k) % species.size()]
		quotas[kind] = int(quotas[kind]) + 1
	return quotas

## Fila round-robin a partir das cotas restantes: toda espécie ganha a PRIMEIRA vaga antes de qualquer
## uma ganhar a segunda (cobertura das 12 espécies mesmo se o espaço acabar no fim da fila).
static func round_robin_queue(tier: String, remaining: Dictionary) -> Array[String]:
	var queue: Array[String] = []
	var left := remaining.duplicate()
	var any := true
	while any:
		any = false
		for kind in MonsterEcologyData.species_of_tier(tier):
			if int(left.get(kind, 0)) > 0:
				queue.append(kind)
				left[kind] = int(left[kind]) - 1
				any = true
	return queue

## Tier de uma reposição: sorteio ponderado pelos pesos da ERA entre os tiers com déficit (> 0).
static func choose_refill_tier(phase: int, deficits: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for tier in MonsterEcologyData.TIERS:
		if int(deficits.get(tier, 0)) > 0:
			total += MonsterActivityProfile.reinforcement_weight(tier, phase)
	if total <= 0:
		return ""
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	for tier in MonsterEcologyData.TIERS:
		if int(deficits.get(tier, 0)) <= 0:
			continue
		acc += MonsterActivityProfile.reinforcement_weight(tier, phase)
		if roll < acc:
			return tier
	return ""

static func shuffled(coords: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = coords.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

static func sorted_coords(coords: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in coords:
		result.append(coord)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	return result

static func sorted_ints(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	result.sort()
	return result
