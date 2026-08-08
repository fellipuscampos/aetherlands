extends GutTest

## Cobre WorldSetup.find_start_tile: prefere planicie mais proxima da
## origem, cai pro fallback (floresta/colina/deserto) se nao achar, e
## nunca escolhe uma coordenada em `excluded` — usado por
## GameManager._spawn_starting_forces() pra impedir que duas capitais
## (humano ou rivais diferentes) acabem no mesmo tile num mapa pequeno.

func test_find_start_tile_prefers_grassland_closest_to_origin():
	var hex_grid := HexGrid.new()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.DESERT)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0))

	assert_eq(start, Vector2i(1, 0), "deveria escolher a planicie mais proxima da origem, nao a mais distante")
	hex_grid.queue_free()

func test_find_start_tile_falls_back_to_other_terrain_without_grassland():
	var hex_grid := HexGrid.new()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0))

	assert_eq(start, Vector2i(1, 0))
	hex_grid.queue_free()

## Regressao: duas civs com origens diferentes podiam convergir pra mesma
## "planicie mais proxima". A segunda HexGrid.found_city() sobrescrevia a
## primeira em cities_by_coord — a primeira capital continuava existindo
## (ainda gerando producao pro dono dela) mas ficava invisivel/inatacavel,
## ja que so uma cidade por coordenada aparece no grid.
func test_find_start_tile_never_returns_an_excluded_coord():
	var hex_grid := HexGrid.new()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var first = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0))
	var second = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0), [first])

	assert_ne(first, second, "a segunda busca nao deveria repetir a coordenada ja reivindicada")
	hex_grid.queue_free()

func test_find_start_tile_excludes_from_fallback_terrain_too():
	var hex_grid := HexGrid.new()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0), [Vector2i(0, 0)])

	assert_eq(start, Vector2i(1, 0))
	hex_grid.queue_free()

## Regressao: um Covil de Monstro (Unit neutra, ver MonsterDatabase) na
## planicie mais proxima da origem nao deveria ser escolhido como capital
## — sem essa checagem, a cidade nasceria em cima do guardiao, deixando o
## tile ocupado pra sempre e a "capital" cercada por algo hostil a ela
## mesma desde o primeiro turno.
func test_find_start_tile_never_returns_a_tile_guarded_by_a_monster():
	var hex_grid := HexGrid.new()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var guardian := Unit.new()
	guardian.setup(MonsterDatabase.create_monster("goblin"), null, Vector2i(0, 0))
	hex_grid.units_by_coord[Vector2i(0, 0)] = guardian

	var start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0))

	assert_eq(start, Vector2i(1, 0), "deveria pular o tile guardado por um monstro e escolher o proximo melhor")
	hex_grid.queue_free()
