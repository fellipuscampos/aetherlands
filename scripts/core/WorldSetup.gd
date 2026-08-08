class_name WorldSetup
extends RefCounted

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
static func find_start_tile(hex_grid: HexGrid, origin: Vector2i, excluded: Array[Vector2i] = []) -> Vector2i:
	var preferred = [HexTileData.TerrainType.GRASSLAND]
	var fallback = [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.HILLS, HexTileData.TerrainType.DESERT]

	var best = _closest_of_types(hex_grid, origin, preferred, excluded)
	if best != null:
		return best

	best = _closest_of_types(hex_grid, origin, fallback, excluded)
	if best != null:
		return best

	if hex_grid.tiles.has(origin) and not origin in excluded:
		return origin
	for coord in hex_grid.tiles.keys():
		if not coord in excluded:
			return coord
	return origin # mapa absurdamente pequeno pro numero de civs: aceita a colisao

## Consome um Colonizador e funda uma cidade no lugar dele. Compartilhado
## entre o jogador (SelectionManager) e a IA rival (RivalAI) para nao
## duplicar a regra de nomeacao/consumo em dois lugares.
static func found_city_from_settler(hex_grid: HexGrid, unit: Unit) -> City:
	var player = unit.owner_player
	var coord = unit.coord
	hex_grid.remove_unit(unit)
	var city_number = player.cities.size() + 1
	return hex_grid.found_city(coord, player, player.civ.civ_name + " - Cidade " + str(city_number))

## Acha um tile de terra firme e livre de unidade pra posicionar algo,
## preferindo o proprio coord (ex: a propria cidade, pra formar guarnicao)
## e so entao varrendo vizinhos. Sem isso, uma cidade costeira podia jogar
## uma unidade recem-criada dentro do oceano (vizinho "index 0" as cegas
## nao respeitava terreno nem ocupacao).
static func find_spawn_tile(hex_grid: HexGrid, coord: Vector2i) -> Vector2i:
	if _is_valid_spawn(hex_grid, coord):
		return coord
	for n in hex_grid.get_neighbors(coord):
		if _is_valid_spawn(hex_grid, n):
			return n
	return coord

static func _is_valid_spawn(hex_grid: HexGrid, coord: Vector2i) -> bool:
	if hex_grid.get_unit_at(coord) != null:
		return false
	var data: HexTileData = hex_grid.get_tile(coord)
	return data != null and data.terrain_type != HexTileData.TerrainType.OCEAN

static func _closest_of_types(hex_grid: HexGrid, origin: Vector2i, types: Array, excluded: Array[Vector2i] = []):
	var best_coord = null
	var best_dist = 999999
	for coord in hex_grid.tiles.keys():
		if coord in excluded:
			continue
		# Nunca escolhe um tile ja guardado por um Covil de Monstro (Unit
		# neutra, ver HexGrid._spawn_monster_lairs) — sem isso uma capital
		# podia nascer em cima de um monstro, deixando o tile ocupado pra
		# sempre e a cidade cercada por algo hostil a ela mesma.
		if hex_grid.get_unit_at(coord) != null:
			continue
		var data: HexTileData = hex_grid.tiles[coord]
		if data.terrain_type in types:
			var d = HexMetrics.axial_distance(origin, coord)
			if d < best_dist:
				best_dist = d
				best_coord = coord
	return best_coord
