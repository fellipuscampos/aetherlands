extends GutTest

## Cobre recursos estrategicos/luxo (ResourceDatabase + HexGrid._assign_resources):
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

func test_cavalry_cost_multiplier_discounts_per_horse_source_up_to_a_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	tile.resource = "horses"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital") # 1 fonte (o proprio tile da cidade)

	assert_almost_eq(
		ResourceDatabase.cavalry_cost_multiplier(player, hex_grid),
		1.0 - ResourceDatabase.CAVALRY_COST_DISCOUNT_PER_HORSE_SOURCE, 0.01
	)

	hex_grid.queue_free()

func test_cavalry_cost_multiplier_is_one_without_any_horse_source():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(ResourceDatabase.cavalry_cost_multiplier(player, hex_grid), 1.0, 0.01)

	hex_grid.queue_free()

## Integracao: City.production_cost(hex_grid) de verdade aplica o
## desconto — sem hex_grid nenhum (chamador antigo, ex: rush-buy/HUD),
## continua devolvendo o custo BASE sem desconto (compatibilidade
## deliberada, ver comentario da funcao em City.gd).
func test_city_production_cost_applies_cavalry_discount_only_when_hex_grid_is_given():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	tile.resource = "horses"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.set_production("cavalry")
	var base_cost = UnitDatabase.create_unit("cavalry").production_cost

	assert_almost_eq(city.production_cost(), base_cost, 0.01, "sem hex_grid, deveria continuar devolvendo o custo base")
	assert_lt(city.production_cost(hex_grid), base_cost, "com hex_grid e uma fonte de Cavalos controlada, deveria custar menos")

	hex_grid.queue_free()

## Roadmap 2.0 Parte 1 (B1) — identidade de Ferro, mesmo padrao dos testes
## de Cavalos acima.
func test_heavy_unit_cost_multiplier_discounts_per_iron_source_up_to_a_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(
		ResourceDatabase.heavy_unit_cost_multiplier(player, hex_grid),
		1.0 - ResourceDatabase.IRON_COST_DISCOUNT_PER_SOURCE, 0.01
	)

	hex_grid.queue_free()

func test_heavy_unit_cost_multiplier_is_one_without_any_iron_source():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(ResourceDatabase.heavy_unit_cost_multiplier(player, hex_grid), 1.0, 0.01)

	hex_grid.queue_free()

## Regressao explicita da correcao B1: human_knight e Cavalaria (usa
## Estabulo), NAO deveria receber o desconto de Ferro mesmo sendo "pesado".
func test_city_production_cost_never_discounts_human_knight_with_iron():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.set_production("human_knight")
	var base_cost = UnitDatabase.create_unit("human_knight").production_cost

	assert_almost_eq(city.production_cost(hex_grid), base_cost, 0.01, "human_knight e Cavalaria, nao deveria ser descontado por Ferro")

	hex_grid.queue_free()

## Roadmap 2.0 Parte 1 (B1) — identidade de Gemas.
func test_rush_buy_cost_multiplier_discounts_per_gems_source_up_to_a_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
	tile.resource = "gems"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(
		ResourceDatabase.rush_buy_cost_multiplier(player, hex_grid),
		1.0 - ResourceDatabase.GEMS_RUSH_BUY_DISCOUNT_PER_SOURCE, 0.01
	)

	hex_grid.queue_free()

func test_rush_buy_cost_multiplier_is_one_without_any_gems_source():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(ResourceDatabase.rush_buy_cost_multiplier(player, hex_grid), 1.0, 0.01)

	hex_grid.queue_free()

func test_city_rush_buy_cost_applies_gems_discount_only_when_hex_grid_is_given():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
	tile.resource = "gems"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.buildings["market"] = true
	city.set_production("warrior")
	city.stored_production = 1.0 # deixa producao restante > 0 pro rush-buy fazer sentido

	var cost_without_grid := city.rush_buy_cost()
	var cost_with_grid := city.rush_buy_cost(hex_grid)

	assert_gt(cost_without_grid, 0.0, "precondicao: deveria haver custo de rush-buy pra comparar")
	assert_lt(cost_with_grid, cost_without_grid, "com hex_grid e uma fonte de Gemas controlada, deveria custar menos")

	hex_grid.queue_free()

## Roadmap 2.0 Parte 1 (B1) — identidade de Nodulo Arcano.
func test_spell_mana_cost_multiplier_discounts_per_mana_node_source_up_to_a_cap():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "mana_node"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(
		ResourceDatabase.spell_mana_cost_multiplier(player, hex_grid),
		1.0 - ResourceDatabase.MANA_COST_DISCOUNT_PER_SOURCE, 0.01
	)

	hex_grid.queue_free()

func test_spell_mana_cost_multiplier_is_one_without_any_mana_node_source():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(center, player, "Capital")

	assert_almost_eq(ResourceDatabase.spell_mana_cost_multiplier(player, hex_grid), 1.0, 0.01)

	hex_grid.queue_free()

## Roadmap 2.0 Parte 1 (B1) — identidade de Seda: capacidade DISCRETA de
## rota, nao um multiplicador — teste cobre a escada inteira de valores em
## vez de um par "aplica/nao aplica" como os quatro descontos acima.
func test_extra_trade_route_capacity_is_a_stepped_value_by_silk_sources():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var ring := HexGrid.NEIGHBOR_DIRS.duplicate()
	for dir in ring:
		hex_grid.tiles[dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.owned_tiles = [center]

	assert_eq(ResourceDatabase.extra_trade_route_capacity(city, hex_grid), 0, "0 fontes -> +0")

	city.owned_tiles = [center, ring[0]]
	hex_grid.get_tile(ring[0]).resource = "silk"
	assert_eq(ResourceDatabase.extra_trade_route_capacity(city, hex_grid), 0, "1 fonte -> +0")

	city.owned_tiles = [center, ring[0], ring[1]]
	hex_grid.get_tile(ring[1]).resource = "silk"
	assert_eq(ResourceDatabase.extra_trade_route_capacity(city, hex_grid), 1, "2 fontes -> +1")

	city.owned_tiles = [center, ring[0], ring[1], ring[2], ring[3]]
	hex_grid.get_tile(ring[2]).resource = "silk"
	hex_grid.get_tile(ring[3]).resource = "silk"
	assert_eq(ResourceDatabase.extra_trade_route_capacity(city, hex_grid), 2, "4 fontes -> +2")

	city.owned_tiles = [center, ring[0], ring[1], ring[2], ring[3], ring[4], ring[5]]
	hex_grid.get_tile(ring[4]).resource = "silk"
	hex_grid.get_tile(ring[5]).resource = "silk"
	assert_eq(ResourceDatabase.extra_trade_route_capacity(city, hex_grid), 2, "6 fontes -> +2 (confirma o teto)")

	hex_grid.queue_free()

func test_city_max_trade_routes_adds_silk_bonus_only_when_hex_grid_is_given():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var ring := HexGrid.NEIGHBOR_DIRS.duplicate()
	for i in range(2):
		hex_grid.tiles[ring[i]] = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
		hex_grid.tiles[ring[i]].resource = "silk"

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.owned_tiles = [center, ring[0], ring[1]]
	city.buildings["market"] = true

	assert_eq(city.max_trade_routes(), City.MARKET_ROUTE_CAPACITY_BONUS, "sem hex_grid, deveria continuar devolvendo so o bonus do Mercado")
	assert_eq(city.max_trade_routes(hex_grid), City.MARKET_ROUTE_CAPACITY_BONUS + 1, "com hex_grid e 2 fontes de Seda, deveria somar +1")

	hex_grid.queue_free()
