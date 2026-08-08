extends GutTest

## Cobre a geracao de biomas (HexGrid._pick_biome/_temperature_for): a
## matriz temperatura x umidade que substituiu a progressao unica por
## elevacao, e a determinacao pela semente do mapa — critica pro
## Salvar/Carregar continuar recriando o terreno identico (SaveManager.gd
## guarda so `map_seed` + `map_radius`, nunca os tiles em si).

var hex_grid: HexGrid

func before_each():
	hex_grid = HexGrid.new()
	hex_grid._ready()

func after_each():
	hex_grid.queue_free()

func test_pick_biome_very_cold_is_snow():
	assert_eq(hex_grid._pick_biome(0.05, 0.5), HexTileData.TerrainType.SNOW)

func test_pick_biome_cold_and_dry_is_tundra():
	assert_eq(hex_grid._pick_biome(0.3, 0.2), HexTileData.TerrainType.TUNDRA)

func test_pick_biome_cold_and_wet_is_taiga():
	assert_eq(hex_grid._pick_biome(0.3, 0.8), HexTileData.TerrainType.TAIGA)

func test_pick_biome_temperate_and_moderate_is_grassland():
	assert_eq(hex_grid._pick_biome(0.5, 0.5), HexTileData.TerrainType.GRASSLAND)

func test_pick_biome_temperate_and_dry_is_plains():
	assert_eq(hex_grid._pick_biome(0.5, 0.1), HexTileData.TerrainType.PLAINS)

func test_pick_biome_temperate_and_wet_is_forest():
	assert_eq(hex_grid._pick_biome(0.5, 0.9), HexTileData.TerrainType.FOREST)

func test_pick_biome_hot_and_dry_is_desert():
	assert_eq(hex_grid._pick_biome(0.9, 0.1), HexTileData.TerrainType.DESERT)

func test_pick_biome_hot_and_moderate_is_savanna():
	assert_eq(hex_grid._pick_biome(0.9, 0.45), HexTileData.TerrainType.SAVANNA)

func test_pick_biome_hot_and_wet_is_jungle():
	assert_eq(hex_grid._pick_biome(0.9, 0.9), HexTileData.TerrainType.JUNGLE)

## Regressao: Salvar/Carregar so guarda map_seed + map_radius e recria o
## terreno chamando generate_map() de novo (ver SaveManager.load_game) —
## se a geracao deixasse de ser 100% deterministica pela semente, todo
## save antigo passaria a carregar um mapa diferente do salvo.
func test_generate_map_is_deterministic_for_same_seed():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(4, 777)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(4, 777)

	for coord in grid_a.tiles.keys():
		assert_eq(
			grid_b.get_tile(coord).terrain_type, grid_a.get_tile(coord).terrain_type,
			"tile %s deveria ter o mesmo bioma nos dois mapas com a mesma semente" % coord
		)

	grid_a.queue_free()
	grid_b.queue_free()

func test_generate_map_with_different_seeds_can_differ():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(6, 111)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(6, 222)

	var any_different = false
	for coord in grid_a.tiles.keys():
		if grid_b.get_tile(coord).terrain_type != grid_a.get_tile(coord).terrain_type:
			any_different = true
			break
	assert_true(any_different, "sementes diferentes deveriam produzir mapas diferentes")

	grid_a.queue_free()
	grid_b.queue_free()
