class_name WorldSetup
extends RefCounted

const NO_SPAWN_COORD := Vector2i(999999, 999999)

## Encontra um bom tile inicial (terreno habitavel) mais proximo de uma
## origem desejada, com fallback progressivo se nao achar o ideal.
## `excluded` (coords ja reivindicados por OUTRA civ nesta mesma geracao de
## mapa, ver GameManager._spawn_starting_forces) evita que duas capitais
## acabem no mesmo tile — sem isso, num mapa Pequeno com varios rivais, a
## busca "grama mais proxima" de origens diferentes podia convergir pro
## mesmo tile e a segunda `HexGrid.found_city()` simplesmente sobrescrevia
## a primeira em `cities_by_coord` (a cidade da primeira civ continuava
## existindo — inclusive gerando producao — mas ficava invisivel/
## inatacavel, ja que so uma cidade por coordenada aparece no grid).
##
## Fase 33D1 — FAIRNESS: `excluded` também impõe uma distância hex MÍNIMA entre capitais
## (MIN_CAPITAL_DISTANCE, igual para todos os assentos). A busca amplia em estágios determinísticos:
## grama → floresta/colina/deserto → qualquer terra firme, sempre o candidato mais próximo da origem que
## respeita a distância. Só num mapa pequeno demais para isso o tile mais afastado das capitais já
## aceitas é usado — nunca em silêncio: push_warning + start_distance_violations (o laboratório de
## balanceamento e os testes exigem 0).
const MIN_CAPITAL_DISTANCE := 12
static var start_distance_violations := 0
## Fase 33D2 (Bug Register #8) — capital nunca nasce numa ilhota: a massa de terra contínua do tile inicial
## precisa ter pelo menos isto de tiles (espaço para a ameaça regional a 7–10, para expandir por terra e
## para uma rota terrestre aos vizinhos). Onde a capital já estava em terra grande, nada muda.
const MIN_START_LANDMASS := 120

static func find_start_tile(hex_grid: HexGrid, origin: Vector2i, excluded: Array[Vector2i] = []) -> Vector2i:
	var preferred = [HexTileData.TerrainType.GRASSLAND]
	var fallback = [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.HILLS, HexTileData.TerrainType.DESERT]

	var best = _closest_of_types(hex_grid, origin, preferred, excluded, MIN_CAPITAL_DISTANCE)
	if best != null:
		return best

	best = _closest_of_types(hex_grid, origin, fallback, excluded, MIN_CAPITAL_DISTANCE)
	if best != null:
		return best

	best = _closest_of_types(hex_grid, origin, [], excluded, MIN_CAPITAL_DISTANCE)
	if best != null:
		return best

	# Nenhum tile respeita a distância mínima: mapa pequeno demais para o número de civilizações.
	start_distance_violations += 1
	push_warning("WorldSetup: nenhum tile inicial a >= %d de todas as capitais; usando o mais afastado." % MIN_CAPITAL_DISTANCE)
	var farthest = null
	var farthest_distance := -1
	for coord in hex_grid.tiles.keys():
		if coord in excluded or hex_grid.get_unit_at(coord) != null or hex_grid.tiles[coord].blocks_land_units():
			continue
		var distance := _min_distance_to(coord, excluded)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = coord
	if farthest != null:
		return farthest
	if hex_grid.tiles.has(origin) and not origin in excluded:
		return origin
	for coord in hex_grid.tiles.keys():
		if not coord in excluded:
			return coord
	return origin # mapa absurdamente pequeno pro numero de civs: aceita a colisao

## Mapas de teste minúsculos (menores que o próprio limite) usam a maior massa de terra que existir.
static func _min_start_landmass(hex_grid: HexGrid) -> int:
	return mini(MIN_START_LANDMASS, hex_grid.tiles.size() / 32)

## Menor distância hex de `coord` até qualquer capital já aceita (999999 sem nenhuma).
static func _min_distance_to(coord: Vector2i, accepted: Array[Vector2i]) -> int:
	var best := 999999
	for other in accepted:
		best = mini(best, HexMetrics.axial_distance(coord, other))
	return best


## Consome um Colonizador e funda uma cidade no lugar dele. Compartilhado
## entre o jogador (SelectionManager) e a IA rival (RivalAI) para nao
## duplicar a regra de nomeacao/consumo em dois lugares. Task 22: a regra de
## distancia/terreno/territorio (CitySite.rejection_reason) vale AQUI, pros
## dois lados -- devolve null (sem consumir o colonizador) quando o local nao
## e' valido.
static func found_city_from_settler(hex_grid: HexGrid, unit: Unit) -> City:
	var player = unit.owner_player
	var coord = unit.coord
	if CitySite.rejection_reason(hex_grid, coord, player) != "":
		return null
	hex_grid.remove_unit(unit)
	var city_number = player.cities.size() + 1
	return hex_grid.found_city(coord, player, player.civ.civ_name + " - Cidade " + str(city_number))

## Acha um tile de terra firme e livre de unidade pra posicionar algo,
## SEMPRE num vizinho de `coord`, nunca no proprio `coord` (ex: a propria
## cidade) — pedido do usuario: "quando terminar de fazer uma tropa, faça
## ela spawnar fora da cidade, ao inves de dentro". So volta a devolver
## `coord` se NENHUM vizinho servir (mapa minusculo/cercado de agua,
## fallback pra nao devolver uma coordenada invalida). Sem varrer vizinhos
## primeiro, uma cidade costeira tambem podia jogar uma unidade recem-
## criada dentro do oceano (vizinho "index 0" as cegas nao respeitava
## terreno nem ocupacao).
static func find_spawn_tile(hex_grid: HexGrid, coord: Vector2i) -> Vector2i:
	for n in hex_grid.get_neighbors(coord):
		if _is_valid_spawn(hex_grid, n):
			var source := hex_grid.get_city_at(coord)
			var destination := hex_grid.get_city_at(n)
			if destination and (source == null or destination.owner_player != source.owner_player):
				continue
			return n
	if hex_grid.get_unit_at(coord) == null and (hex_grid.get_city_at(coord) != null or _is_valid_spawn(hex_grid, coord)):
		return coord
	return NO_SPAWN_COORD

static func _is_valid_spawn(hex_grid: HexGrid, coord: Vector2i) -> bool:
	if hex_grid.get_unit_at(coord) != null:
		return false
	var data: HexTileData = hex_grid.get_tile(coord)
	return data != null and not data.blocks_land_units()

## `types` vazio = qualquer terra firme. `min_distance` > 0 exige essa distância de TODOS os `excluded`.
## Ordem de iteração = ordem de inserção dos tiles (determinística pela seed), a mesma de sempre: onde a
## distância já era respeitada, a capital continua exatamente no mesmo tile.
static func _closest_of_types(hex_grid: HexGrid, origin: Vector2i, types: Array, excluded: Array[Vector2i] = [], min_distance: int = 0):
	var best_coord = null
	var best_dist = 999999
	for coord in hex_grid.tiles.keys():
		if coord in excluded:
			continue
		if min_distance > 0 and _min_distance_to(coord, excluded) < min_distance:
			continue
		# Nunca escolhe um tile ja guardado por um Covil de Monstro (Unit
		# neutra, ver HexGrid._spawn_monster_lairs) — sem isso uma capital
		# podia nascer em cima de um monstro, deixando o tile ocupado pra
		# sempre e a cidade cercada por algo hostil a ela mesma.
		if hex_grid.get_unit_at(coord) != null:
			continue
		var data: HexTileData = hex_grid.tiles[coord]
		if (types.is_empty() and not data.blocks_land_units()) or data.terrain_type in types:
			if min_distance > 0 and hex_grid.land_component_size(coord) < _min_start_landmass(hex_grid):
				continue
			var d = HexMetrics.axial_distance(origin, coord)
			if d < best_dist:
				best_dist = d
				best_coord = coord
	return best_coord
