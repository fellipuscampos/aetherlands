extends GutTest

## Cobre recursos estrategicos/luxo (ResourceDatabase + HexGrid._maybe_assign_resource):
## elegibilidade por bioma, bonus de yield aplicado em City.collect_yields,
## e determinismo pela map_seed — assim como bioma, Salvar/Carregar depende
## de recursos nunca mudarem de lugar ao regenerar o mesmo mapa.

func test_eligible_resources_matches_expected_biomes():
	assert_true("iron" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.HILLS))
	assert_true("horses" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.GRASSLAND))
	assert_eq(ResourceDatabase.eligible_resources(HexTileData.TerrainType.OCEAN).size(), 0, "oceano nao deveria ter recurso elegivel")

func test_yield_for_known_resource():
	assert_eq(ResourceDatabase.yield_for("iron").production, 2)
	assert_eq(ResourceDatabase.yield_for("gems").gold, 3)

func test_yield_for_no_resource_is_zero():
	var y = ResourceDatabase.yield_for("")
	assert_eq(y.food, 0)
	assert_eq(y.production, 0)
	assert_eq(y.gold, 0)
	assert_eq(y.mana, 0)

## Nodulo Arcano (Ponto 3, "Economia Arcana"): mesmo mecanismo de
## recurso estrategico de sempre, so que rendendo MANA em vez de comida/
## producao/ouro — pedido do usuario: "Trabalhar um tile com MANA_NODE
## gera +2 de Mana por turno".
func test_mana_node_is_eligible_on_hills_and_forest():
	assert_true("mana_node" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.HILLS))
	assert_true("mana_node" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.FOREST))

func test_mana_node_is_not_eligible_on_unrelated_biomes():
	assert_false("mana_node" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.GRASSLAND))
	assert_false("mana_node" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.OCEAN))

## Regressao (pedido do usuario: "faca recursos nao nascerem nas
## montanhas") — Montanha nao deve mais oferecer recurso nenhum,
## nem Ferro nem Nodulo Arcano (os dois unicos que ja apareceram la).
func test_no_resource_is_eligible_on_mountains():
	assert_eq(ResourceDatabase.eligible_resources(HexTileData.TerrainType.MOUNTAINS).size(), 0)

func test_yield_for_mana_node_gives_two_mana_and_nothing_else():
	var y = ResourceDatabase.yield_for("mana_node")
	assert_eq(y.mana, 2)
	assert_eq(y.food, 0)
	assert_eq(y.production, 0)
	assert_eq(y.gold, 0)

func test_display_name_for_mana_node():
	assert_eq(ResourceDatabase.display_name("mana_node"), "Nódulo Arcano")

func test_resource_placement_is_deterministic_for_same_seed():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(11, 11, 999)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(11, 11, 999)

	for coord in grid_a.tiles.keys():
		assert_eq(
			grid_b.get_tile(coord).resource, grid_a.get_tile(coord).resource,
			"recurso do tile %s deveria ser identico com a mesma semente" % coord
		)

	grid_a.queue_free()
	grid_b.queue_free()

func test_at_least_one_resource_appears_on_a_large_enough_map():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 42)

	var found_any := false
	for coord in grid.tiles.keys():
		if grid.get_tile(coord).resource != "":
			found_any = true
			break

	assert_true(found_any, "um mapa grande o suficiente deveria ter pelo menos um tile com recurso")

	grid.queue_free()

## Costa (HexTileData.TerrainType.COAST) incluida aqui tambem — e Oceano
## reclassificado (ver HexGrid._reclassify_coastal_ocean), mesma familia de
## agua, mesma regra "nunca tem recurso". Sem isso o teste podia rodar sem
## nenhuma assercao de verdade num mapa pequeno onde TODO Oceano vira Costa
## (todo o litoral perto de terra, comum em mapas pequenos) — bug de
## regressao pego ao adicionar Costa (GUT acusa "Risky: Did not assert").
func test_ocean_and_coast_tiles_never_get_a_resource():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 7)

	var checked_count := 0
	for coord in grid.tiles.keys():
		var data: HexTileData = grid.get_tile(coord)
		if data.terrain_type == HexTileData.TerrainType.OCEAN or data.terrain_type == HexTileData.TerrainType.COAST:
			checked_count += 1
			assert_eq(data.resource, "", "oceano/costa nunca deveria ter recurso")

	assert_gt(checked_count, 0, "mapa deveria ter pelo menos um tile de Oceano/Costa pra este teste checar algo de verdade")

	grid.queue_free()

func test_city_collect_yields_applies_resource_bonus():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[coord] = tile

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.coord = coord

	var yields = city.collect_yields(hex_grid)

	assert_eq(yields.production, tile.production_yield + 2, "bonus de ferro (+2 producao) deveria ser somado")

	hex_grid.queue_free()
	city.queue_free()
