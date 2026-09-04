extends GutTest

## Roadmap 2.0 Parte 1 (A2) — HexGrid.is_under_rival_pressure: proxy MINIMO
## de "tile sob pressao de cidade rival", puramente distancia hexagonal ate
## a cidade rival mais perto, sem nenhuma camada de cultura/influencia.

func test_is_under_rival_pressure_true_within_radius_of_rival_city():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var rival_coord := Vector2i(0, 0)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(rival_coord, rival, "Capital Rival")

	var nearby_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS, 0)
	assert_true(hex_grid.is_under_rival_pressure(nearby_coord, human))

	hex_grid.queue_free()

func test_is_under_rival_pressure_false_outside_radius():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var rival_coord := Vector2i(0, 0)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(rival_coord, rival, "Capital Rival")

	var far_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS + 1, 0)
	assert_false(hex_grid.is_under_rival_pressure(far_coord, human))

	hex_grid.queue_free()

## Uma cidade PROPRIA perto nao conta como "pressao rival" — so cidade de
## OUTRO jogador.
func test_is_under_rival_pressure_false_for_own_city():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var own_coord := Vector2i(0, 0)
	hex_grid.tiles[own_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(own_coord, human, "Capital")

	var nearby_coord := Vector2i(1, 0)
	assert_false(hex_grid.is_under_rival_pressure(nearby_coord, human))

	hex_grid.queue_free()
