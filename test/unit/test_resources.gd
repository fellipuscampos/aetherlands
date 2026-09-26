extends GutTest

## Cobre recursos (ResourceDatabase + HexGrid._assign_resources): elegibilidade
## por bioma, contagem de fontes controladas e determinismo pela map_seed — assim como bioma, Salvar/Carregar depende
## de recursos nunca mudarem de lugar ao regenerar o mesmo mapa.

func test_eligible_resources_matches_expected_biomes():
	assert_true("iron" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.HILLS))
	assert_true("horses" in ResourceDatabase.eligible_resources(HexTileData.TerrainType.GRASSLAND))
	assert_eq(ResourceDatabase.eligible_resources(HexTileData.TerrainType.OCEAN).size(), 0, "oceano nao deveria ter recurso elegivel")

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

## ANTI-CLUSTER (pedido do usuario, tarefa "9. ANTI-CLUSTER DE RECURSOS":
## "penalidade de probabilidade por vizinhanca" -- ver comentario de
## RESOURCE_CLUSTER_RADIUS em HexGrid.gd). Testa _resource_cluster_reject
## isoladamente (sem gerar um mapa inteiro, mais rapido e deterministico) --
## confirma que a chance de rejeicao SOBE com o numero de vizinhos do MESMO
## recurso ja proximos, que fica em 0% sem nenhum vizinho (proximidade
## isolada nunca e' penalizada) e que 1 vizinho continua raramente rejeitado
## (o caso "proximidade interessante" que o usuario quer preservar).
func test_resource_cluster_reject_scales_with_nearby_same_type_count():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var probe := Vector2i(10, 10)
	hex_grid.tiles[probe] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in range(50):
		assert_false(hex_grid._resource_cluster_reject(probe, "iron", rng), "sem nenhum vizinho do mesmo recurso, nunca deveria rejeitar")

	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[0]] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[0]].resource = "iron"
	var trials := 1000
	var rejects_one := 0
	for i in range(trials):
		if hex_grid._resource_cluster_reject(probe, "iron", rng):
			rejects_one += 1
	var rate_one := float(rejects_one) / trials
	assert_lt(rate_one, 0.6, "1 vizinho proximo nao deveria virar rejeicao frequente -- proximidade ocasional deve continuar comum")

	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[1]] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[1]].resource = "iron"
	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[2]] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[probe + HexGrid.NEIGHBOR_DIRS[2]].resource = "iron"
	var rejects_three := 0
	for i in range(trials):
		if hex_grid._resource_cluster_reject(probe, "iron", rng):
			rejects_three += 1
	var rate_three := float(rejects_three) / trials

	assert_gt(rate_three, rate_one, "mais vizinhos do mesmo recurso proximos deveria aumentar a chance de rejeicao")
	assert_gt(rate_three, 0.75, "com varios vizinhos proximos, rejeicao deveria virar o comportamento tipico -- sequencias exageradas ficam raras")

	hex_grid.queue_free()

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

## Roadmap de gameplay Fase 3 — pedido do usuario: "controla N recursos
## estrategicos do tipo X = tem N fontes disponiveis pro bonus daquele
## tipo". Conta ladrilho da PROPRIA cidade e ladrilho POSSUIDO (owned_tiles),
## nao so os trabalhados — recurso possuido mas nao trabalhado ainda conta
## pra esta contagem (diferente do bonus de yield normal).
func test_count_controlled_counts_city_and_owned_tiles_with_the_resource():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var owned := Vector2i(1, 0)
	var not_owned := Vector2i(2, 0)
	var center_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	center_tile.resource = "horses"
	hex_grid.tiles[center] = center_tile
	var owned_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	owned_tile.resource = "horses"
	hex_grid.tiles[owned] = owned_tile
	var not_owned_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	not_owned_tile.resource = "horses"
	hex_grid.tiles[not_owned] = not_owned_tile

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.owned_tiles = [owned]

	assert_eq(ResourceDatabase.count_controlled(player, hex_grid, "horses"), 2, "deveria contar o tile da cidade + o possuido, mas nao o nao-possuido")

	hex_grid.queue_free()

func test_count_controlled_is_zero_without_the_resource():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_eq(ResourceDatabase.count_controlled(player, hex_grid, "horses"), 0)

	hex_grid.queue_free()

## Fase 25: o recurso só rende pela Melhoria V2 -- todo id gerado no mapa precisa ter uma.
func test_every_map_resource_has_a_v2_improvement():
	for resource_id in ResourceDatabase.DISPLAY_NAMES:
		assert_true(V2ResourceImprovementData.has_resource(resource_id), resource_id)
		assert_false(V2ResourceImprovementData.effects_for_resource(resource_id).is_empty(), resource_id)

func test_resource_database_has_no_v1_economic_semantics():
	for member in ["yield_for", "cavalry_cost_multiplier", "heavy_unit_cost_multiplier", "spell_mana_cost_multiplier", "rush_buy_cost_multiplier", "extra_trade_route_capacity"]:
		assert_false(FileAccess.get_file_as_string("res://scripts/data/ResourceDatabase.gd").contains("func %s(" % member), member)
