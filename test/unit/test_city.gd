extends GutTest

## Pedido do usuario, apos reportar que uma cidade recem-fundada spawnava
## um Colonizador sozinha sem ninguem escolher nada: "fundei uma cidade e
## fiquei dando next, e do nada uma hora spawnou um colonizador" — toda
## cidade nova nasce OCIOSA ("", ver comentario do campo em City.gd), NAO
## mais com "settler" pre-selecionado (isso sofria do mesmo bug que
## process_turn() ja corrige apos completar: produzir sem o jogador ter
## pedido).
func test_default_production_is_idle():
	var city := City.new()
	assert_eq(city.production_item, "")
	city.queue_free()

func test_set_production_changes_item_and_resets_progress():
	var city := City.new()
	city.stored_production = 10.0
	city.set_production("archer")
	assert_eq(city.production_item, "archer")
	assert_eq(city.stored_production, 0.0)
	city.queue_free()

func test_set_production_same_kind_keeps_progress():
	var city := City.new()
	city.set_production("settler") # cidade nasce ociosa (""), ver City.gd — precisa escolher antes de repetir a mesma escolha
	city.stored_production = 10.0
	city.set_production("settler") # MESMO kind de novo, nao deveria zerar
	assert_eq(city.stored_production, 10.0)
	city.queue_free()

## Regressao: abandonar um predio EM ANDAMENTO (trocar pra unidade ou
## outro predio antes de completar) precisa limpar pending_building_coord
## — senao o tile reservado ficava "preso" e o marcador de construcao
## (HexGrid.refresh_construction_markers) nunca saberia que a obra foi
## cancelada.
func test_set_production_clears_pending_coord_when_abandoning_a_building():
	var city := City.new()
	city.set_production("granary")
	city.pending_building_coord = Vector2i(3, 3)

	city.set_production("warrior")

	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	city.queue_free()

func test_set_production_keeps_pending_coord_when_switching_between_units():
	var city := City.new()
	city.set_production("warrior")
	city.pending_building_coord = Vector2i(3, 3) # nao deveria acontecer na pratica, so pra isolar o comportamento

	city.set_production("archer")

	assert_eq(city.pending_building_coord, Vector2i(3, 3), "trocar entre unidades (sem predio envolvido) nao deveria mexer no coord pendente")
	city.queue_free()
	city.queue_free()

func test_production_cost_matches_unit_database():
	var city := City.new()
	city.set_production("cavalry")
	assert_eq(city.production_cost(), UnitDatabase.create_unit("cavalry").production_cost)
	city.queue_free()

## Roadmap "Parte B" (B2) — desconto militar de identidade se aplica MESMO
## SEM hex_grid (diferente dos descontos de recurso de ResourceDatabase),
## porque so depende de buildings LOCAIS da propria cidade.
func test_production_cost_applies_militar_identity_discount_without_hex_grid():
	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true
	city.set_production("men_at_arms")
	var base_cost = UnitDatabase.create_unit("men_at_arms").production_cost

	assert_almost_eq(city.production_cost(), base_cost * (1.0 - CityIdentity.MILITAR_UNIT_COST_DISCOUNT_MAX), 0.01, "desconto militar deveria se aplicar mesmo sem hex_grid nenhum")

	city.queue_free()

## Confirma que o desconto de identidade militar e o desconto de recurso
## (Ferro, ver ResourceDatabase.heavy_unit_cost_multiplier) empilham
## MULTIPLICATIVAMENTE, nenhum dos dois sozinho ja explica o custo final —
## mesmo padrao de raca x dificuldade x predio ja empilhando em
## collect_yields().
func test_production_cost_stacks_militar_identity_with_iron_discount():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[center] = tile

	var player := PlayerData.new(CivilizationData.new())
	var city := hex_grid.found_city(center, player, "Capital")
	city.buildings["barracks"] = true # militar 1/5, identidade sozinha ja desconta
	city.set_production("men_at_arms") # esta no ResourceDatabase.IRON_DISCOUNT_KINDS
	var base_cost = UnitDatabase.create_unit("men_at_arms").production_cost

	var identity_only = base_cost * CityIdentity.militar_unit_cost_multiplier(city, "men_at_arms")
	var iron_only = base_cost * ResourceDatabase.heavy_unit_cost_multiplier(player, hex_grid)
	var actual = city.production_cost(hex_grid)

	assert_lt(actual, identity_only, "com hex_grid e Ferro controlado, o custo deveria ficar ABAIXO do que so o desconto de identidade explicaria")
	assert_lt(actual, iron_only, "deveria ficar ABAIXO do que so o desconto de Ferro explicaria")
	assert_almost_eq(actual, base_cost * CityIdentity.militar_unit_cost_multiplier(city, "men_at_arms") * ResourceDatabase.heavy_unit_cost_multiplier(player, hex_grid), 0.01, "os dois descontos deveriam empilhar multiplicativamente")

	hex_grid.queue_free()

## Regressao: cidade deve mesmo crescer com comida suficiente acumulada
## (a base de todo o loop de expansao do jogo).
func test_process_turn_accumulates_food_and_grows_population():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var city := City.new()
	city.coord = coord
	city.population = 1

	for i in range(10):
		city.process_turn(hex_grid)

	assert_gt(city.population, 1, "cidade deveria crescer depois de varios turnos com comida sobrando")

	hex_grid.queue_free()
	city.queue_free()

## Territorio (City.owned_tiles, ver HexGrid.city_territory_tiles) cresce
## JUNTO com a populacao — pedido do usuario: expansao dinamica de
## territorio. Mapa de 2 aneis (19 tiles) pra sobrar um 2o anel de verdade
## alem do territorio inicial (celula+6 vizinhos) pro tile novo vir de la.
func test_city_growth_claims_exactly_one_new_frontier_tile_per_population_point():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	for q in range(-2, 3):
		for r in range(-2, 3):
			var coord = Vector2i(q, r)
			if HexMetrics.axial_distance(coord, center) <= 2:
				hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var city = hex_grid.found_city(center, human, "Capital")
	assert_eq(city.owned_tiles.size(), 7, "precondicao: territorio inicial e celula + 6 vizinhos")
	var owned_before := {}
	for t in city.owned_tiles:
		owned_before[t] = true

	city.stored_food = 999.0 # forca cruzar o teto de armazenamento (clamp) neste turno
	city.process_turn(hex_grid)

	assert_eq(city.population, 2, "precondicao: populacao deveria ter crescido neste turno")
	assert_eq(city.owned_tiles.size(), 8, "cada crescimento de populacao deveria reivindicar exatamente 1 tile novo de fronteira")
	var new_tiles = city.owned_tiles.filter(func(t): return not owned_before.has(t))
	assert_eq(new_tiles.size(), 1)
	assert_eq(HexMetrics.axial_distance(new_tiles[0], center), 2, "o tile reivindicado deveria vir da fronteira (2o anel), nao repetir o territorio inicial")

	hex_grid.queue_free()

## Regressao: se toda a fronteira de uma cidade ja pertence a OUTRA cidade,
## o crescimento de territorio nao deveria roubar tile nenhum (mesma regra
## de disputa que worked_tiles ja tem via city_working_tile, ver
## HexGrid.city_owning_tile).
func test_claim_frontier_tile_never_claims_a_tile_already_owned_by_another_city():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	city.owned_tiles = [center]
	var other = hex_grid.found_city(Vector2i(-5, -5), rival, "Outra")
	other.owned_tiles = HexGrid.NEIGHBOR_DIRS.duplicate() # "possui" toda a unica fronteira possivel de `city`

	city._claim_frontier_tile(hex_grid)

	assert_eq(city.owned_tiles.size(), 1, "nenhum tile deveria ser reivindicado — toda a fronteira ja pertence a outra cidade")

	hex_grid.queue_free()
	city.queue_free()

## Roadmap 2.0 Parte 1 (A1) — um tile de recurso com yield BRUTO pior que um
## vizinho comum ainda deveria ser reivindicado primeiro, uma vez que o
## bonus fixo de FRONTIER_RESOURCE_SCORE_BONUS entra na pontuacao. Nodulo
## Arcano em Colina escolhido de proposito: pontuaria 0 pela formula antiga
## (sem food/producao/ouro), pior que QUALQUER vizinho de Planicie/Grama —
## exatamente o caso que o bonus corrige.
func test_claim_frontier_tile_prefers_resource_tile_over_higher_raw_yield_neighbor():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var resource_coord = HexGrid.NEIGHBOR_DIRS[0]
	var resource_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	resource_tile.resource = "mana_node"
	hex_grid.tiles[resource_coord] = resource_tile
	for dir in HexGrid.NEIGHBOR_DIRS.slice(1):
		hex_grid.tiles[dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.owned_tiles = [center]

	city._claim_frontier_tile(hex_grid)

	assert_eq(city.owned_tiles, [center, resource_coord], "o tile com Nodulo Arcano deveria ser reivindicado antes de qualquer Planicie comum")

	hex_grid.queue_free()
	city.queue_free()

## Confirma que _best_unassigned_neighbor (trabalho) usa a MESMA pontuacao
## de _claim_frontier_tile (posse) — as duas passaram a compartilhar
## _tile_claim_score, sem duplicar a formula.
func test_best_unassigned_neighbor_also_prefers_resource_tile():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var resource_coord = HexGrid.NEIGHBOR_DIRS[0]
	var resource_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	resource_tile.resource = "mana_node"
	hex_grid.tiles[resource_coord] = resource_tile
	for dir in HexGrid.NEIGHBOR_DIRS.slice(1):
		hex_grid.tiles[dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var city := City.new()
	city.coord = center

	var best = city._best_unassigned_neighbor(hex_grid)

	assert_eq(best, resource_coord)

	hex_grid.queue_free()
	city.queue_free()

## --- Roadmap "Fase F"/G: mana passa a participar de _tile_claim_score ----
## F7 (diagnostico causal, ver conversa) achou um erro arquitetural GENERICO
## nesta formula: mana e um yield valido de effective_tile_yield(), mas
## nunca entrava na pontuacao de posse/trabalho de tile — 5/15 seeds nunca
## passavam de 2/3 Nodulos Arcanos mesmo com fartura deles no mapa (seed
## 1010: 14 Nodulos, so 1 jamais reivindicado por qualquer jogador). A
## formula raciocina sobre YIELD (data.resource == "mana_node" de proposito
## NAO aparece em lugar nenhum abaixo), nunca sobre o NOME do recurso — pra
## nao acoplar esta heuristica generica a um recurso especifico e ja cobrir
## qualquer terreno/efeito futuro que produza mana.

func test_tile_claim_score_adds_a_bonus_proportional_to_mana():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var plain_hills = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	var mana_hills = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	mana_hills.resource = "mana_node" # +2 de mana (ResourceDatabase.YIELDS)
	var city := City.new()
	city.owner_player = PlayerData.new(CivilizationData.new())

	var plain_score = city._tile_claim_score(plain_hills, hex_grid, coord)
	var mana_score = city._tile_claim_score(mana_hills, hex_grid, coord)

	# diferenca = +4 generico de recurso (FRONTIER_RESOURCE_SCORE_BONUS) +
	# 2 de mana * MANA_TILE_WEIGHT -- as duas dimensoes somam, nenhuma
	# substitui a outra (mesmo principio ja usado por resource/lair).
	var expected_diff: float = City.FRONTIER_RESOURCE_SCORE_BONUS + 2.0 * City.MANA_TILE_WEIGHT
	assert_almost_eq(mana_score - plain_score, expected_diff, 0.01)

	hex_grid.queue_free()
	city.queue_free()

func test_tile_claim_score_resource_bonus_is_independent_of_mana():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var plain_hills = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	var iron_hills = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	iron_hills.resource = "iron" # +2 producao, ZERO mana (ResourceDatabase.YIELDS)
	var city := City.new()
	city.owner_player = PlayerData.new(CivilizationData.new())

	var plain_score = city._tile_claim_score(plain_hills, hex_grid, coord)
	var iron_score = city._tile_claim_score(iron_hills, hex_grid, coord)

	# ferro rende producao (yield normal, peso 1.3) + o mesmo +4 generico de
	# recurso -- nenhuma contribuicao de mana, ja que ferro nao rende mana.
	var expected_diff: float = 2.0 * 1.3 + City.FRONTIER_RESOURCE_SCORE_BONUS
	assert_almost_eq(iron_score - plain_score, expected_diff, 0.01, "bonus de recurso continua fixo em +4, independente de mana -- ferro nao rende mana nenhum")

	hex_grid.queue_free()
	city.queue_free()

func test_tile_claim_score_matches_plain_yield_formula_for_tiles_without_mana():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var data = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var city := City.new()
	city.owner_player = PlayerData.new(CivilizationData.new())

	var y = city.effective_tile_yield(data)
	assert_almost_eq(y.mana, 0.0, 0.01, "planicie sem recurso nao deveria render mana nenhum")
	var score = city._tile_claim_score(data, hex_grid, coord)
	assert_almost_eq(score, y.food * 1.5 + y.production * 1.3 + y.gold, 0.01, "sem mana nem recurso, a formula deveria continuar identica a formula antiga")

	hex_grid.queue_free()
	city.queue_free()

## Integracao: Nodulo Arcano preferido a uma Colina EQUIVALENTE (mesmo
## terreno, mesma ausencia de perigo) que so nao tem recurso nenhum --
## isola o termo de mana do resto do cenario (a diferenca entre os dois
## coords e SO o recurso/mana, nada mais).
func test_claim_frontier_tile_prefers_mana_node_over_an_equivalent_tile_without_it():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var mana_coord = HexGrid.NEIGHBOR_DIRS[0]
	var mana_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	mana_tile.resource = "mana_node"
	hex_grid.tiles[mana_coord] = mana_tile
	var plain_coord = HexGrid.NEIGHBOR_DIRS[1]
	hex_grid.tiles[plain_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # mesmo terreno, sem recurso
	for dir in HexGrid.NEIGHBOR_DIRS.slice(2):
		hex_grid.tiles[dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.owned_tiles = [center]

	city._claim_frontier_tile(hex_grid)

	assert_eq(city.owned_tiles, [center, mana_coord], "Nodulo Arcano deveria ser preferido a uma Colina equivalente sem recurso nenhum")

	hex_grid.queue_free()
	city.queue_free()

## Roadmap 2.0 (fecha Parte A) — dois candidatos de mesmo yield (Planicie),
## um perto de um covil de Dragao ativo (dentro de LAIR_DANGER_RADIUS), o
## outro longe — a cidade deveria reivindicar o tile LONGE do covil.
func test_claim_frontier_tile_avoids_tile_near_active_lair():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var safe_coord := Vector2i(1, 0)
	var near_lair_coord := Vector2i(-1, 0)
	hex_grid.tiles[safe_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[near_lair_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var lair_coord := Vector2i(-5, 0) # distancia 4 (== LAIR_DANGER_RADIUS) de near_lair_coord, 6 de safe_coord
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"
	hex_grid.spawn_monster_at(lair_coord, "dragon", true)

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.owned_tiles = [center]

	city._claim_frontier_tile(hex_grid)

	assert_eq(city.owned_tiles, [center, safe_coord], "deveria reivindicar o tile longe do covil de Dragao, nao o vizinho dele")

	hex_grid.queue_free()
	city.queue_free()

## A tensao "trade-off, nao bloqueio" pedida pelo usuario: um tile de
## recurso colado num covil de Dragao ainda deveria vencer um tile sem
## recurso e sem covil por perto, se o bonus de recurso superar a
## penalidade de perigo.
func test_claim_frontier_tile_still_prefers_resource_tile_despite_nearby_dangerous_lair():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var plain_coord := Vector2i(1, 0)
	hex_grid.tiles[plain_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var resource_coord := Vector2i(-1, 0)
	var resource_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	resource_tile.resource = "iron"
	hex_grid.tiles[resource_coord] = resource_tile
	var lair_coord := Vector2i(-5, 0) # distancia 4 de resource_coord, 6 de plain_coord
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"
	hex_grid.spawn_monster_at(lair_coord, "dragon", true)

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.owned_tiles = [center]

	city._claim_frontier_tile(hex_grid)

	assert_eq(city.owned_tiles, [center, resource_coord], "bonus de recurso (+4) deveria superar a penalidade de perigo de Dragao (-3), mesmo tile sem recurso/sem covil rendendo mais yield bruto")

	hex_grid.queue_free()
	city.queue_free()

## Mesma checagem de test_claim_frontier_tile_avoids_tile_near_active_lair,
## agora via _best_unassigned_neighbor — confirma que a penalidade de covil
## se aplica aos dois call sites de _tile_claim_score, nao so a um.
func test_best_unassigned_neighbor_also_avoids_lair_danger():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var safe_coord := Vector2i(1, 0)
	var near_lair_coord := Vector2i(-1, 0)
	hex_grid.tiles[safe_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[near_lair_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var lair_coord := Vector2i(-5, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"
	hex_grid.spawn_monster_at(lair_coord, "dragon", true)

	var city := City.new()
	city.coord = center

	var best = city._best_unassigned_neighbor(hex_grid)

	assert_eq(best, safe_coord)

	hex_grid.queue_free()
	city.queue_free()

func test_process_turn_spawns_unit_once_production_cost_is_reached():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("warrior") # custa 15 producao

	var spawned := false
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.spawn_unit_kind != "":
			spawned = true
			assert_eq(result.spawn_unit_kind, "warrior")
			break

	assert_true(spawned, "cidade deveria ter completado a producao do guarda em 20 turnos")

	hex_grid.queue_free()
	city.queue_free()

## Pedido do usuario apos reportar a barra de progresso "vários turnos com
## ela no 0": "não sei se o problema é que a construção realmente fica
## congelada no tempo no início". Confirmado: Planicie (GRASSLAND) tem
## production_yield 0 (ver TerrainDatabase) — uma cidade fundada/sem tile
## trabalhado nenhum sobre esse terreno ficava com producao literalmente
## zero por turno, indefinidamente. collect_yields() agora garante um piso
## (CITY_CENTER_MIN_PRODUCTION) so pro tile CENTRAL da cidade, exatamente
## como Civilization e outros 4X fazem.
func test_collect_yields_guarantees_minimum_production_on_zero_yield_city_tile():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # producao 0/turno

	var city := City.new()
	city.coord = coord

	var yields = city.collect_yields(hex_grid)

	assert_eq(yields.production, City.CITY_CENTER_MIN_PRODUCTION, "tile central sem producao nenhuma deveria cair no piso garantido, nao ficar em zero")

	hex_grid.queue_free()
	city.queue_free()

## Roadmap "Parte B" (B1/B2) — CityIdentity.apply_yield_bonus() de verdade
## chamada dentro de collect_yields(). Compara DUAS cidades EQUIVALENTES
## (mesmo tile central, mesma ausencia de tiles trabalhados), uma com
## Celeiro construido e outra sem — nao basta checar "o yield reflete algum
## bonus", precisa isolar o bonus de IDENTIDADE do bonus de YIELD que o
## proprio Celeiro ja da via BuildingDatabase.total_bonus (+1 comida), que
## e um efeito SEPARADO e ja coberto por outros testes.
func test_collect_yields_applies_agricola_identity_bonus_on_top_of_granary_own_yield():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var city_without_granary := City.new()
	city_without_granary.coord = coord
	var food_without_granary = city_without_granary.collect_yields(hex_grid).food

	var city_with_granary := City.new()
	city_with_granary.coord = coord
	city_with_granary.buildings["granary"] = true
	var food_with_granary = city_with_granary.collect_yields(hex_grid).food

	# Diferenca esperada = bonus de YIELD do Celeiro (+1 comida, ver
	# BuildingDatabase) DEPOIS multiplicado pelo bonus de IDENTIDADE
	# agricola (a comida INTEIRA e multiplicada, nao so a parte do Celeiro,
	# ver CityIdentity.apply_yield_bonus) — nao a soma simples dos dois.
	var expected_food = (food_without_granary + 1.0) * (1.0 + CityIdentity.AGRICOLA_FOOD_BONUS_MAX)
	assert_almost_eq(food_with_granary, expected_food, 0.01, "comida com Celeiro deveria refletir TANTO o bonus de yield do predio QUANTO o bonus de identidade agricola por cima")
	assert_gt(food_with_granary, food_without_granary + 1.0, "o bonus de identidade deveria somar ALEM do bonus de yield puro do Celeiro")

	hex_grid.queue_free()
	city_without_granary.queue_free()
	city_with_granary.queue_free()

## Mesmo cenario acima, mas verificando que process_turn() de fato ACUMULA
## producao turno apos turno em vez de ficar travado — e nao so que
## collect_yields() calcula certo isoladamente.
func test_process_turn_accumulates_production_even_on_zero_yield_terrain():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # producao 0/turno

	var city := City.new()
	city.coord = coord
	city.set_production("granary")

	# 2 turnos: bem longe do teto de armazenamento (FOOD_STORAGE_BASE=15,
	# comida liquida da Planicie sozinha e so 2/turno depois do consumo por
	# populacao) — fora do escopo deste teste, que so quer confirmar que a
	# producao NAO fica travada em zero.
	for i in range(2):
		city.process_turn(hex_grid)

	assert_eq(city.stored_production, City.CITY_CENTER_MIN_PRODUCTION * 2, "producao deveria avancar todo turno, nunca ficar travada em zero")

	hex_grid.queue_free()
	city.queue_free()

## production_item pode ser um id de predio (BuildingDatabase) em vez de um
## kind de unidade — production_cost() precisa checar la primeiro.
func test_production_cost_recognizes_building_id():
	var city := City.new()
	city.set_production("granary")
	assert_eq(city.production_cost(), BuildingDatabase.get_building("granary").production_cost)
	city.queue_free()

func test_can_build_is_false_once_building_already_built():
	var city := City.new()
	assert_true(city.can_build("sages_tower"))
	city.buildings["sages_tower"] = true
	assert_false(city.can_build("sages_tower"))
	city.queue_free()

## Pivot pedido pelo usuario: "cada tropa e feita numa construcao... so
## pode treinar as tropas na sua respectiva construcao". Homem de Armas
## exige o Quartel ja construido nesta cidade especifica antes de poder
## ser produzido — ver BuildingDatabase.building_that_trains(). Guarda NAO
## entra mais nesta regra (pedido do usuario numa rodada seguinte: "o
## guarda comum nao precisa de quartel pra ser feito", ver teste dedicado
## abaixo).
func test_can_train_is_false_without_the_matching_training_building():
	var city := City.new()
	assert_false(city.can_train("men_at_arms"), "sem Quartel construido, Homem de Armas nao deveria ser treinavel")
	city.queue_free()

func test_can_train_is_true_once_the_matching_training_building_is_built():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_true(city.can_train("men_at_arms"))
	city.queue_free()

## Guarda voltou a nao exigir predio nenhum (mesmo status do Colonizador) —
## pedido do usuario: "o guarda comum nao precisa de quartel pra ser
## feito". Precisa continuar treinavel MESMO sem o Quartel construido.
func test_can_train_warrior_never_requires_a_building():
	var city := City.new()
	assert_true(city.can_train("warrior"), "Guarda nao deveria depender de predio nenhum")
	city.queue_free()

## Ter o predio de treino de OUTRA tropa nao libera esta — cada predio so
## libera o kind que ele mesmo treina.
func test_can_train_does_not_leak_across_different_training_buildings():
	var city := City.new()
	city.buildings["barracks"] = true # treina Homem de Armas, nao Arqueiro
	assert_false(city.can_train("archer"))
	city.queue_free()

## Pedido do usuario: escolher raca na tela de titulo precisa ter uma
## implicacao real — so a raca DONA de uma tropa racial (UnitDatabase.
## RACE_UNIQUE_KIND) pode treina-la, mesmo com o predio (Quartel) ja
## construido.
func test_can_train_is_false_for_a_racial_unit_of_a_different_race():
	var human := PlayerData.new(CivilizationData.new())
	human.civ.race = "human"
	var city := City.new()
	city.owner_player = human
	city.buildings["barracks"] = true
	assert_false(city.can_train("dwarf_axeguard"), "Humano nao deveria conseguir treinar a tropa exclusiva Ana")
	city.queue_free()

func test_can_train_is_true_for_the_matching_race_once_barracks_is_built():
	var dwarf := PlayerData.new(CivilizationData.new())
	dwarf.civ.race = "dwarf"
	var city := City.new()
	city.owner_player = dwarf
	city.buildings["barracks"] = true
	assert_true(city.can_train("dwarf_axeguard"))
	city.queue_free()

func test_can_train_is_false_for_matching_race_without_barracks():
	var dwarf := PlayerData.new(CivilizationData.new())
	dwarf.civ.race = "dwarf"
	var city := City.new()
	city.owner_player = dwarf
	assert_false(city.can_train("dwarf_axeguard"), "tropa racial tambem precisa do Quartel, mesmo com a raca certa")
	city.queue_free()

## Defensivo: cidade sem owner_player (ex: City.new() cru, ver outros
## testes acima) nao deveria travar checando raca de tropa racial — so
## nunca fica treinavel, sem exception.
func test_can_train_racial_unit_is_false_without_an_owner_player():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_false(city.can_train("elf_ranger"))
	city.queue_free()

## Pivot seguinte pedido pelo usuario: "so posso construir esses predios
## especiais quando pesquisar a tecnologia, ai aparece disponivel pra
## construir". Torre Arcana (treina Mago) so pode ser CONSTRUIDA depois de
## pesquisar Invocacao de Espiritos — antes disso can_build() ja bloqueia,
## nem chega a abrir o modo de posicionamento de tile. (Arqueiro/Cavaleiro
## viraram tropas mundanas sempre liberadas na arvore magica atual, ver
## TechDatabase — so as tropas MAGICAS ainda tem esse gate de 3 passos.)
func test_can_build_training_building_is_false_without_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("arcane_tower"), "sem Invocacao de Espiritos pesquisada, Torre Arcana nao deveria poder ser construida")
	city.queue_free()

func test_can_build_training_building_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["invocacao_espiritos"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("arcane_tower"))
	city.queue_free()

## Mudanca de comportamento pedida pelo usuario ("Mesmo Quartel, agora com
## pesquisa" — confirmado via pergunta de esclarecimento explicita): Quartel
## passou a ter sua PROPRIA tecnologia (TechDatabase.tech_that_unlocks(
## "warrior") agora acha "quartel", nao mais null), entao deixou de ser
## construivel de graca desde o inicio — mesma cadeia de 3 passos que a
## Torre Arcana ja seguia (ver testes acima), so que agora tambem cobre o
## Quartel. Isso atrasa tanto o Guarda quanto o Homem de Armas (os dois
## dependem do mesmo predio), efeito colateral aceito explicitamente pelo
## usuario.
func test_can_build_barracks_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("barracks"), "sem a tech Quartel pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_barracks_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["quartel"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("barracks"))
	city.queue_free()

## Pedido do usuario: "a muralha nao faz tanto sentido [como predio sempre
## liberado, sem tech nenhuma]... vamos remover ela, e adicionar como
## pesquisa". Diferente de Quartel/Estabulo/Arquearia (que travam via
## TechData.unlocks_unit == building.trains_unit), Muralhas nao treina
## tropa nenhuma — trava via TechData.unlocks_building (ver TechDatabase.
## tech_that_unlocks_building), gate SEPARADO que _tech_unlocked_for_
## building tambem precisa consultar quando o gate de trains_unit nao acha
## nada.
func test_can_build_walls_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("walls"), "sem a tech Muralhas pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_walls_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["muralhas"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("walls"))
	city.queue_free()

## Vida/escudo da cidade (ver comentario de CITY_BASE_MAX_HP em City.gd) —
## pedido do usuario: "quero... estabelecer a vida da cidade, sempre
## mostrando na tela quanta vida ela tem, e o shield tambem, a partir do
## momento que voce construir a muralha".
func test_max_hp_grows_with_population():
	var city := City.new()
	city.population = 1
	var hp_at_pop_1 = city.max_hp()
	city.population = 5
	var hp_at_pop_5 = city.max_hp()
	assert_gt(hp_at_pop_5, hp_at_pop_1, "cidade maior deveria ser mais dificil de arrasar")
	city.queue_free()

func test_max_shield_is_zero_without_walls_built():
	var city := City.new()
	assert_eq(city.max_shield(), 0.0, "sem Muralhas construida, a cidade nao deveria ter escudo nenhum")
	city.queue_free()

func test_max_shield_is_positive_once_walls_is_built():
	var city := City.new()
	city.buildings["walls"] = true
	assert_gt(city.max_shield(), 0.0)
	city.queue_free()

func test_setup_initializes_hp_to_max_and_shield_to_zero():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()

	city.setup(human, Vector2i(0, 0), "Capital")

	assert_almost_eq(city.hp, city.max_hp(), 0.01, "cidade recem-fundada deveria comecar com vida cheia")
	assert_eq(city.shield, 0.0, "cidade recem-fundada nao tem Muralhas construida ainda")
	city.queue_free()

## process_turn() cura vida/escudo aos poucos todo turno (mesmo espirito
## da cura de guarnicao de unidade, GameManager._heal_if_garrisoned) —
## sem isso, uma cidade que sobreviveu a um ataque ficaria ferida pra
## sempre, trivialmente capturavel por qualquer ataque seguinte.
func test_process_turn_regenerates_hp_over_time():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	city.process_turn(hex_grid)

	assert_gt(city.hp, city.max_hp() * 0.5, "vida deveria regenerar um pouco a cada turno")
	assert_lte(city.hp, city.max_hp(), "regeneracao nunca deveria passar do maximo")

	hex_grid.queue_free()
	city.queue_free()

func test_process_turn_regenerates_shield_over_time_once_walls_is_built():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.buildings["walls"] = true
	city.shield = city.max_shield() * 0.5

	city.process_turn(hex_grid)

	assert_gt(city.shield, city.max_shield() * 0.5, "escudo deveria regenerar um pouco a cada turno")
	assert_lte(city.shield, city.max_shield(), "regeneracao nunca deveria passar do maximo")

	hex_grid.queue_free()
	city.queue_free()

## Roadmap de gameplay Fase 2: sitio (unidade inimiga adjacente por 2+
## turnos SEGUIDOS) suspende a regeneracao de HP — pedido do usuario:
## "comecar com UMA unica consequencia simples e legivel" em vez de um
## dreno novo, so desliga um bonus que ja existe. N=2 (nao 1) de proposito
## — o teste confirma que o PRIMEIRO turno de contato ainda regenera
## normalmente, so o segundo turno SEGUIDO suspende.
func test_process_turn_suspends_hp_regen_while_under_siege_for_two_turns():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var enemy_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[enemy_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var enemy_unit := Unit.new()
	enemy_unit.setup(UnitDatabase.create_unit("warrior"), rival, enemy_coord)
	hex_grid.units_by_coord[enemy_coord] = enemy_unit

	city.process_turn(hex_grid) # 1o turno de contato: ainda regenera (sitio exige 2+)
	var hp_after_first_turn = city.hp
	assert_gt(hp_after_first_turn, city.max_hp() * 0.5, "primeiro turno de contato ainda deveria regenerar normalmente")

	city.process_turn(hex_grid) # 2o turno SEGUIDO com o mesmo inimigo adjacente: sitio de verdade agora

	assert_eq(city.hp, hp_after_first_turn, "com sitio de 2+ turnos, a regeneracao deveria ficar suspensa")

	hex_grid.queue_free()
	city.queue_free()
	enemy_unit.queue_free()

func test_process_turn_regenerates_normally_when_adjacent_unit_is_at_peace():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var other_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[other_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	var other := PlayerData.new(CivilizationData.new()) # sem Diplomacy.declare_war — em paz
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var other_unit := Unit.new()
	other_unit.setup(UnitDatabase.create_unit("warrior"), other, other_coord)
	hex_grid.units_by_coord[other_coord] = other_unit

	city.process_turn(hex_grid)
	city.process_turn(hex_grid)

	assert_almost_eq(city.hp, city.max_hp() * 0.5 + 2 * city.max_hp() * City.CITY_HP_REGEN_FRACTION, 0.01, "unidade em PAZ adjacente nao deveria contar como sitio")

	hex_grid.queue_free()
	city.queue_free()
	other_unit.queue_free()

## Covil de Monstro (owner_player == null) sempre conta como ameaca de
## sitio, mesmo sem estado de guerra formal — diplomacia nao existe pra
## monstro neutro.
func test_process_turn_suspends_regen_for_a_neutral_monster_adjacent():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var monster_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[monster_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("goblin"), null, monster_coord)
	hex_grid.units_by_coord[monster_coord] = monster

	city.process_turn(hex_grid)
	var hp_after_first_turn = city.hp
	city.process_turn(hex_grid)

	assert_eq(city.hp, hp_after_first_turn, "monstro neutro adjacente por 2+ turnos deveria suspender a regeneracao tambem")

	hex_grid.queue_free()
	city.queue_free()
	monster.queue_free()

## Mesma mudanca de comportamento, pro Estabulo — pedido do usuario: "voce
## precisa pesquisar[,] o estabulo [pra poder] construir". TechDatabase.
## tech_that_unlocks("cavalry") agora acha "estabulo", nao mais null.
func test_can_build_stable_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("stable"), "sem a tech Estabulo pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

## Precisa da tech E do Quartel construido (ver testes de
## requires_building abaixo) — so a tech sozinha ainda nao basta.
## population = 2 pra abrir espaco pro segundo predio (Quartel ja ocupa o
## unico slot de uma cidade populacao 1, ver max_building_slots()).
func test_can_build_stable_is_true_once_its_tech_is_researched_and_barracks_built():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["estabulo"] = true
	var city := City.new()
	city.owner_player = human
	city.population = 2
	city.buildings["barracks"] = true
	assert_true(city.can_build("stable"))
	city.queue_free()

## Pedido do usuario: "faca o estabulo ser uma coisa que so pode ser feita
## depois do quartel" — BuildingData.requires_building. Mesmo com a tech
## "Estabulo" ja pesquisada, sem o Quartel FISICAMENTE construido nesta
## cidade o Estabulo continua bloqueado.
func test_can_build_stable_requires_the_barracks_built_even_with_its_tech_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["estabulo"] = true
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("stable"), "sem o Quartel construido, o Estabulo nao deveria poder ser construido")
	city.queue_free()

## Regressao pro caminho oposto: Quartel construido mas SEM a tech
## "Estabulo" pesquisada ainda bloqueia — os dois gates (predio + tech) se
## combinam, nenhum sozinho basta. population = 2 pra isolar o gate de
## TECNOLOGIA como unico motivo do bloqueio (population 1 ja bloquearia so
## pelo limite de slots, com o Quartel sozinho ocupando o unico espaco).
func test_can_build_stable_requires_its_tech_even_with_the_barracks_built():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	city.population = 2
	city.buildings["barracks"] = true
	assert_false(city.can_build("stable"), "sem a tech Estabulo pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

## Cavaleiro Real (human_knight) e a UNICA tropa racial que treina no
## Estabulo, nao no Quartel (ver BuildingDatabase.building_that_trains) —
## pedido do usuario: "apos construido no estabulo voce pode fazer o
## cavaleiro real". Ter so o Quartel construido NAO deveria libera-lo.
func test_can_train_human_knight_requires_the_stable_not_the_barracks():
	var human := PlayerData.new(CivilizationData.new())
	human.civ.race = "human"
	var city := City.new()
	city.owner_player = human
	city.buildings["barracks"] = true
	assert_false(city.can_train("human_knight"), "Quartel construido nao deveria liberar o Cavaleiro Real, so o Estabulo")
	city.buildings["stable"] = true
	assert_true(city.can_train("human_knight"))
	city.queue_free()

## Mesma mudanca de comportamento, pro Campo de Tiro — pedido do usuario:
## "introduza a pesquisa em arqueria... nela voce libera a construcao que
## atualmente temos pra treinar arqueiros". TechDatabase.tech_that_unlocks
## ("archer") agora acha "arquearia", nao mais null.
func test_can_build_archery_range_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("archery_range"), "sem a tech Arquearia pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_archery_range_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["arquearia"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("archery_range"))
	city.queue_free()

## Batedor (scout) cai no MESMO Estabulo que ja treina Cavaleiro/Cavaleiro
## Real, sem predio proprio — pedido do usuario: "uma pesquisa seguinte ao
## estabulo... o batedor montado, que libera a construcao do batedor".
func test_can_train_scout_requires_the_stable():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_train("scout"), "sem Estabulo construido, Batedor nao deveria ser treinavel")
	city.buildings["stable"] = true
	assert_true(city.can_train("scout"))
	city.queue_free()

## Regressao critica: predios de RENDIMENTO sem tech propria (trains_unit
## vazio E sem entrada em TechData.unlocks_building, ex: Torre dos Sabios)
## NAO deveriam exigir tecnologia nenhuma — sem essa guarda,
## TechDatabase.tech_that_unlocks("") "encontraria" a primeira tech de
## bioma da lista (Canalizacao da Trama) por acidente, bloqueando a Torre
## dos Sabios ate pesquisar algo que nem tem nada a ver com ela. Celeiro,
## Oficina e Mercado DEIXARAM de ser exemplo disso (ganharam tech propria
## "celeiro"/"oficina"/"mercado", ver testes test_can_build_granary_
## requires_its_tech/test_can_build_workshop_requires_its_tech/
## test_can_build_market_requires_its_tech abaixo).
func test_can_build_yield_building_never_requires_research():
	var city := City.new()
	assert_true(city.can_build("sages_tower"), "Torre dos Sabios (predio de rendimento sem tech propria) nao deveria depender de tecnologia nenhuma")
	city.queue_free()

## Mesmo mecanismo de test_can_build_walls_requires_its_tech (unlocks_
## building, nao unlocks_unit — Celeiro nao treina tropa nenhuma). Pedido
## do usuario, redesenho do sistema de comida: "precisamos fazer pesquisa
## de cada uma dessas coisas, tudo deve ter pesquisa".
func test_can_build_granary_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("granary"), "sem a tech Celeiro pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_granary_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["celeiro"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("granary"))
	city.queue_free()

## Mesmo mecanismo de test_can_build_granary_requires_its_tech — pedido do
## usuario: "a oficina precisa de uma pesquisa, depois de ser pesquisado[,]
## p[oder] ser construida".
func test_can_build_workshop_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("workshop"), "sem a tech Oficina pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_workshop_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["oficina"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("workshop"))
	city.queue_free()

## Mesmo mecanismo de test_can_build_granary_requires_its_tech — pedido do
## usuario: "é uma boa, faça isso" (rush-buy com ouro, liberado pelo
## Mercado construido).
func test_can_build_market_requires_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("market"), "sem a tech Mercado pesquisada, o predio nao deveria poder ser construido")
	city.queue_free()

func test_can_build_market_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["mercado"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("market"))
	city.queue_free()

## Rush-buy (Mercado): sem o predio "market" construido nesta cidade,
## comprar producao com ouro nao deveria estar disponivel — pedido do
## usuario: "o mercado pode servir pra [dar um uso real pro ouro]"/"é uma
## boa, faça isso".
func test_can_rush_buy_is_false_without_market_built():
	var city := City.new()
	city.set_production("warrior")
	assert_false(city.can_rush_buy(), "sem o Mercado construido, rush-buy nao deveria estar disponivel")
	city.queue_free()

## Cidade OCIOSA (sem nada em producao) nao tem o que comprar, mesmo com o
## Mercado construido.
func test_can_rush_buy_is_false_when_idle():
	var city := City.new()
	city.buildings["market"] = true
	assert_false(city.can_rush_buy(), "cidade ociosa nao tem producao nenhuma pra comprar")
	city.queue_free()

func test_can_rush_buy_is_true_with_market_and_production_in_progress():
	var city := City.new()
	city.buildings["market"] = true
	city.set_production("warrior")
	assert_true(city.can_rush_buy())
	city.queue_free()

## rush_buy_cost() e proporcional so ao que FALTA (production_cost() -
## stored_production), nao ao custo total — senao comprar um item quase
## pronto custaria o mesmo que comprar do zero.
func test_rush_buy_cost_is_proportional_to_remaining_production():
	var city := City.new()
	city.buildings["market"] = true
	city.set_production("warrior") # custa 15 producao (UnitDatabase)
	city.stored_production = 10.0

	assert_almost_eq(city.rush_buy_cost(), 5.0 * City.RUSH_BUY_GOLD_PER_PRODUCTION, 0.01, "faltam 5 de producao (15-10), vezes a taxa de conversao")
	city.queue_free()

## Regressao: rush_buy() completa o item so ate stored_production ==
## production_cost() — a CONCLUSAO de fato (spawnar unidade/marcar predio
## construido/voltar a ficar ociosa) so acontece no PROXIMO process_turn(),
## reaproveitando a mesma logica de sempre em vez de duplicar aqui.
func test_rush_buy_completes_production_and_spends_gold():
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	var city := City.new()
	city.owner_player = human
	city.buildings["market"] = true
	city.set_production("warrior") # custa 15 producao
	city.stored_production = 10.0

	var expected_cost = 5.0 * City.RUSH_BUY_GOLD_PER_PRODUCTION
	var result = city.rush_buy()

	assert_true(result)
	assert_almost_eq(city.stored_production, city.production_cost(), 0.01, "producao deveria estar completa apos o rush-buy")
	assert_almost_eq(human.gold, 100.0 - expected_cost, 0.01, "ouro deveria ter sido descontado")
	city.queue_free()

func test_rush_buy_fails_without_enough_gold():
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 1.0 # bem menos que o custo de comprar 5 de producao faltante
	var city := City.new()
	city.owner_player = human
	city.buildings["market"] = true
	city.set_production("warrior")
	city.stored_production = 10.0

	var result = city.rush_buy()

	assert_false(result)
	assert_almost_eq(city.stored_production, 10.0, 0.01, "producao nao deveria mudar quando o rush-buy falha por falta de ouro")
	assert_almost_eq(human.gold, 1.0, 0.01, "ouro nao deveria ser descontado quando o rush-buy falha")
	city.queue_free()

func test_rush_buy_fails_when_not_available():
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 1000.0
	var city := City.new() # sem o Mercado construido
	city.owner_player = human
	city.set_production("warrior")

	assert_false(city.rush_buy())
	assert_almost_eq(human.gold, 1000.0, 0.01, "ouro nao deveria ser descontado sem o Mercado construido")
	city.queue_free()

## Torre dos Sabios e um predio de RENDIMENTO (trains_unit vazio, mesma
## familia de Celeiro/Oficina/Mercado/Muralhas) — mesma regra acima, sem
## gate de tecnologia nenhum, mesmo a descricao de canalizacao_base
## "prometendo" ela (ver TechDatabase.gd/BuildingDatabase.gd).
func test_can_build_sages_tower_never_requires_research():
	var city := City.new()
	assert_true(city.can_build("sages_tower"))
	city.queue_free()

## Santuario do Nodulo (Roadmap Fase F, F1): mesmo mecanismo da Torre dos
## Sabios acima, "tech gate: nenhum" foi decisao explicita do usuario — o
## Santuario precisa estar sempre disponivel pra nao adicionar mais um
## gargalo estrutural em cima do que o F7 ja apontou (schools/nodes prontos,
## sanctuary=0% em todo seed por FALTA do predio, nao por gate faltando).
func test_can_build_arcane_sanctuary_never_requires_research():
	var city := City.new()
	assert_true(city.can_build("arcane_sanctuary"))
	city.queue_free()

## Colonizador nao tem predio de treino associado (BuildingDatabase.
## building_that_trains("settler") == null) — precisa continuar sempre
## produzivel, e o unico kind seguro pro default de uma cidade nova.
func test_can_train_ignores_the_gate_for_kinds_without_a_training_building():
	var city := City.new()
	assert_true(city.can_train("settler"))
	city.queue_free()

## Regressao/feature: numero de predios e limitado pela populacao (1
## predio por ponto de populacao) — sem isso uma vila de populacao 1
## conseguiria acumular Celeiro+Oficina+Mercado+Muralhas ao mesmo tempo,
## sem nenhum motivo pra crescer alem do rendimento puro dos tiles.
func test_max_building_slots_equals_population():
	var city := City.new()
	city.population = 1
	assert_eq(city.max_building_slots(), 1)
	city.population = 3
	assert_eq(city.max_building_slots(), 3)
	city.queue_free()

func test_can_build_respects_population_limit_even_for_a_new_building():
	var city := City.new()
	city.population = 1
	city.buildings["granary"] = true

	assert_false(city.can_build("sages_tower"), "populacao 1 so cabe 1 predio — ja tem o Celeiro, nao deveria caber mais nenhum")

	city.population = 2
	assert_true(city.can_build("sages_tower"), "populacao 2 deveria abrir espaco pro segundo predio")

	city.queue_free()

## Regressao: completar um predio precisa marcar buildings[id]=true (pra
## sempre, ver collect_yields()) e devolver built_kind pro GameManager
## notificar — diferente de unidade, nao spawna nada no grid.
##
## Pedido do usuario: "a partir do momento que voce funda a cidade, ele
## fica produzindo sem parar unidades... eu quero que... quando ela
## acabar, so produza outra se voce for la e por pra produzir de novo" —
## ANTES completar um predio trocava production_item de volta pra
## "settler" (que ai ficava se auto-reconstruindo pra sempre, mesmo bug).
## Agora fica OCIOSA ("") ate o jogador escolher o proximo item.
func test_process_turn_completes_building_and_goes_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("granary") # custa 20 producao

	var built := ""
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built = result.built_kind
			break

	assert_eq(built, "granary", "cidade deveria ter completado o Celeiro em 20 turnos")
	assert_true(city.buildings.has("granary"))
	assert_eq(city.production_item, "", "cidade deveria ficar OCIOSA apos completar, nao reconstruir sozinha nem trocar pra outro item automaticamente")

	hex_grid.queue_free()
	city.queue_free()

## Mesma mudanca de comportamento, pra UNIDADE — antes uma cidade
## produzindo Guarda (ou qualquer outra tropa) ficava reconstruindo a
## MESMA tropa pra sempre sozinha (production_item nunca era limpo apos
## spawnar); agora fica ociosa ate o jogador escolher de novo.
func test_process_turn_completes_a_unit_and_goes_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("warrior") # custa 15 producao

	var spawned := ""
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.spawn_unit_kind != "":
			spawned = result.spawn_unit_kind
			break

	assert_eq(spawned, "warrior", "cidade deveria ter completado o Guarda")
	assert_eq(city.production_item, "", "cidade deveria ficar OCIOSA apos completar a tropa, nao continuar produzindo a mesma sozinha")

	hex_grid.queue_free()
	city.queue_free()

## production_cost() precisa devolver 0.0 (nao o custo default de
## UnitDatabase.create_unit("")) pra uma cidade OCIOSA — senao qualquer
## chamador (HUD, marcador de construcao) leria um numero enganoso.
func test_production_cost_is_zero_when_idle():
	var city := City.new()
	city.set_production("granary")
	city.set_production("") # cancela/limpa producao direto

	assert_eq(city.production_item, "")
	assert_eq(city.production_cost(), 0.0)
	city.queue_free()

## Regressao central: uma cidade ociosa nunca deveria "completar" nada
## sozinha so por acumular producao — mesmo apos MUITOS turnos, sem o
## jogador escolher um item, spawn_unit_kind/built_kind ficam sempre
## vazios.
func test_process_turn_never_completes_anything_while_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("")

	for i in range(30):
		var result = city.process_turn(hex_grid)
		assert_eq(result.spawn_unit_kind, "", "cidade ociosa nao deveria spawnar unidade nenhuma sozinha")
		assert_eq(result.built_kind, "", "cidade ociosa nao deveria completar predio nenhum sozinho")

	hex_grid.queue_free()
	city.queue_free()

## Feature: o jogador escolhe ONDE o predio vai no mapa (como fundar
## cidade) — is_valid_building_tile() e o que valida essa escolha antes de
## SelectionManager aceitar o clique.
func test_is_valid_building_tile_accepts_a_free_land_neighbor():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_true(city.is_valid_building_tile(HexGrid.NEIGHBOR_DIRS[0], hex_grid))

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_non_neighbor():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(Vector2i(5, 0), hex_grid), "tile longe demais da cidade nao deveria ser um destino valido")

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_ocean():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var ocean_dir = HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.tiles[center + ocean_dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city := City.new()
	city.coord = center

	assert_false(city.is_valid_building_tile(ocean_dir, hex_grid))

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_tile_occupied_by_unit():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var target = HexGrid.NEIGHBOR_DIRS[0]
	var human := PlayerData.new(CivilizationData.new())
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), human, target)
	hex_grid.units_by_coord[target] = unit
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(target, hex_grid))

	hex_grid.queue_free()
	city.queue_free()
	unit.queue_free()

func test_is_valid_building_tile_rejects_tile_already_used_by_a_building():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var target = HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.buildings_by_coord[target] = true # so precisa existir a chave pra is_tile_building_site() acusar
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(target, hex_grid))

	hex_grid.queue_free()
	city.queue_free()

## Regressao: process_turn() precisa gravar building_coords[id] e devolver
## built_coord SO quando o jogador de fato escolheu um tile
## (pending_building_coord) — ver SelectionManager.start_building_placement.
func test_process_turn_places_building_at_pending_coord():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("granary")
	city.pending_building_coord = Vector2i(1, 0)

	var built_coord = City.NO_PENDING_COORD
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built_coord = result.built_coord
			break

	assert_eq(built_coord, Vector2i(1, 0))
	assert_eq(city.building_coords.get("granary"), Vector2i(1, 0))
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD, "coord pendente deveria ser consumido ao completar")

	hex_grid.queue_free()
	city.queue_free()

## Graceful degrade: se production_item virou um predio sem passar pelo
## fluxo de posicionamento (ex: set_production() chamado direto, como em
## testes antigos), o predio ainda completa e conta pro bonus/limite — so
## nao ganha coordenada nem modelo 3D.
func test_process_turn_completes_building_without_a_coord_when_none_was_chosen():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("granary")

	var built_kind := ""
	var built_coord = City.NO_PENDING_COORD
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built_kind = result.built_kind
			built_coord = result.built_coord
			break

	assert_eq(built_kind, "granary")
	assert_eq(built_coord, City.NO_PENDING_COORD)
	assert_false(city.building_coords.has("granary"))

	hex_grid.queue_free()
	city.queue_free()

## Muralhas (BuildingData.self_placed = true) NUNCA passa por
## pending_building_coord (nem via SelectionManager, ver HUD._on_produce_
## pressed) — diferente do "graceful degrade" acima (que cobre um caso
## ACIDENTAL), aqui a ausencia de coord/modelo 3D e o comportamento
## PRETENDIDO: o efeito e o anel de muralha da PROPRIA cidade (ver City.
## _add_walls), acionado na hora que a producao completa (ver process_turn
## chamando _build_visual_procedural quando building.self_placed), sem
## esperar o proximo crescimento de populacao.
func test_process_turn_completes_self_placed_walls_and_refreshes_the_wall_ring():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["muralhas"] = true
	var city := City.new()
	city.setup(human, coord, "Capital") # _build_visual() inicializa _buildings_root, ver comentario abaixo
	city.set_production("walls")
	var child_count_before = city._buildings_root.get_child_count()

	var built_kind := ""
	var built_coord = City.NO_PENDING_COORD
	for i in range(30):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built_kind = result.built_kind
			built_coord = result.built_coord
			break

	assert_eq(built_kind, "walls")
	assert_eq(built_coord, City.NO_PENDING_COORD, "Muralhas nao deveria gerar um Building.gd separado num tile")
	assert_false(city.building_coords.has("walls"))
	assert_true(city.buildings.has("walls"))
	assert_gt(city._buildings_root.get_child_count(), child_count_before, "o anel de muralha deveria aparecer na hora, sem esperar a cidade crescer")

	hex_grid.queue_free()
	city.queue_free()

## Regressao geometrica: pedido do usuario ("se as celulas sao hexagonos, a
## muralha devem ser um conjunto de retas em cada aresta pra formar um
## hexagono ao redor da celula") — a versao anterior espalhava 6 blocos
## soltos num CIRCULO, todos no CIRCUNRAIO (onde ficam os VERTICES de um
## hexagono, nao o meio das arestas), com vaos largos entre eles — nunca
## fechava silhueta de hexagono nenhuma. Agora: 6 segmentos retos
## centralizados no APOTEMA (meio de cada aresta) + 6 pilares de canto
## EXATAMENTE nos vertices (HexMetrics.corner), fechando as juntas.
func test_walls_visual_forms_a_closed_hexagon_of_segments_and_corner_pillars():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.setup(human, Vector2i(0, 0), "Capital") # tile_radius default 1.0
	city.buildings["walls"] = true
	city._build_visual_procedural()

	var expected_wall_radius = city.tile_radius * City.WALL_RADIUS_FACTOR
	var expected_apothem = expected_wall_radius * 0.8660254
	var expected_segment_length = expected_wall_radius * City.WALL_SEGMENT_LENGTH_FACTOR
	var expected_pillar_radius = expected_wall_radius * City.WALL_PILLAR_RADIUS_FACTOR

	var segments: Array = []
	var pillars: Array = []
	for child in city._buildings_root.get_children():
		if child is MeshInstance3D:
			if child.mesh is BoxMesh and is_equal_approx(child.mesh.size.x, expected_segment_length):
				segments.append(child)
			elif child.mesh is CylinderMesh and is_equal_approx(child.mesh.top_radius, expected_pillar_radius):
				pillars.append(child)

	assert_eq(segments.size(), 6, "deveria ter exatamente 1 segmento reto por aresta do hexagono")
	assert_eq(pillars.size(), 6, "deveria ter exatamente 1 pilar por vertice do hexagono")

	# Cada segmento fica centralizado no APOTEMA (meio da aresta), NAO no
	# circunraio (onde ficam os vertices) — essa era a diferenca chave do
	# PRIMEIRO bug (segmentos flutuando alem da aresta de verdade).
	#
	# Regressao do SEGUNDO bug (posicao certa, ROTACAO errada — so este
	# assert de distancia nao pegava isso, deixou passar batido apesar da
	# muralha ficar visualmente toda torta/cruzada): confere que a direcao
	# de cada segmento (extremos calculados a partir da rotacao de
	# verdade, via transform.basis) fica PARALELA a direcao real da
	# aresta do hexagono correspondente, nao girada pro lado espelhado
	# errado.
	for seg in segments:
		var dist_from_center = Vector2(seg.position.x, seg.position.z).length()
		assert_almost_eq(dist_from_center, expected_apothem, 0.01, "segmento deveria ficar no apotema (meio da aresta), nao no circunraio")

		var half_length = expected_segment_length * 0.5
		var world_offset = seg.transform.basis * Vector3(half_length, 0, 0)
		var seg_dir = Vector2(world_offset.x, world_offset.z).normalized()

		# a posicao do segmento (angulo = 60*i graus) diz de qual aresta i
		# ele deveria fazer parte.
		var seg_angle_deg = rad_to_deg(atan2(seg.position.z, seg.position.x))
		var i = ((roundi(seg_angle_deg / 60.0) % 6) + 6) % 6
		var corner_a = HexMetrics.corner(expected_wall_radius, i)
		var corner_b = HexMetrics.corner(expected_wall_radius, (i + 1) % 6)
		var edge_dir = Vector2(corner_b.x - corner_a.x, corner_b.z - corner_a.z).normalized()

		var alignment = abs(seg_dir.dot(edge_dir)) # 1.0 = perfeitamente paralelo (ou anti-paralelo, tanto faz pra uma caixa simetrica)
		assert_almost_eq(alignment, 1.0, 0.01, "segmento deveria estar alinhado com a aresta real do hexagono, nao girado/cruzado em outro angulo")

	# Cada pilar fica EXATAMENTE num vertice do hexagono (so X/Z importam
	# aqui — Y e so a altura do pilar acima do chao).
	for i in range(6):
		var expected = HexMetrics.corner(expected_wall_radius, i)
		var found = false
		for pillar in pillars:
			var pillar_xz = Vector2(pillar.position.x, pillar.position.z)
			var expected_xz = Vector2(expected.x, expected.z)
			if pillar_xz.distance_to(expected_xz) < 0.01:
				found = true
				break
		assert_true(found, "deveria existir um pilar exatamente no vertice %d do hexagono" % i)

	city.queue_free()

## Pedido do usuario, apos ver a muralha pequena/mal-encaixada: "voce
## conseguiria fazer... como esse vermelho que tracei" (um hexagono do
## TAMANHO do proprio tile, nao de um raio local arbitrario) — confirma
## que a muralha de fato escala com o hex_size REAL do tile (HexGrid.
## hex_size, propagado via found_city -> City.setup -> tile_radius), nao
## um numero fixo desconectado do mapa.
func test_walls_visual_scales_with_the_real_tile_hex_size():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.hex_size = 2.0 # tile bem maior que o default (1.0)
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())

	var city = hex_grid.found_city(coord, human, "Capital")
	city.buildings["walls"] = true
	city._build_visual_procedural()

	assert_almost_eq(city.tile_radius, 2.0, 0.01, "tile_radius deveria vir do hex_size real do HexGrid, nao ficar preso no default 1.0")

	var expected_apothem = (2.0 * City.WALL_RADIUS_FACTOR) * 0.8660254
	var found_segment_at_expected_radius = false
	for child in city._buildings_root.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var dist_from_center = Vector2(child.position.x, child.position.z).length()
			if is_equal_approx(dist_from_center, expected_apothem):
				found_segment_at_expected_radius = true
				break
	assert_true(found_segment_at_expected_radius, "muralha deveria acompanhar o hex_size 2.0, nao ficar presa numa escala fixa pequena")

	hex_grid.queue_free()

## Regressao: collect_yields() precisa somar o bonus PERMANENTE dos predios
## ja construidos (BuildingDatabase.total_bonus), nao so o rendimento de
## tile — diferente de tecnologia/recurso, o bonus de predio nao depende de
## nenhum tile especifico.
func test_collect_yields_includes_building_bonus():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3

	var city := City.new()
	city.coord = center
	city.buildings["granary"] = true # +1 comida (bonus_food, ver BuildingDatabase.gd)

	var yields = city.collect_yields(hex_grid)

	# 3 (tile) + 1 (Celeiro) = 4, DEPOIS multiplicado pelo bonus de
	# identidade agricola (Roadmap Parte B, CityIdentity.gd — Celeiro
	# sozinho ja da forca agricola 1.0/1.0): 4 * (1 + 0.10) = 4.4.
	assert_almost_eq(yields.food, 4.0 * (1.0 + CityIdentity.AGRICOLA_FOOD_BONUS_MAX), 0.01, "3 (tile) + 1 (Celeiro), com bonus de identidade agricola por cima")

	hex_grid.queue_free()
	city.queue_free()

## Economia arcana (Ponto 3): mana rendida por um Nodulo Arcano TRABALHADO
## (recurso, ver ResourceDatabase) soma com o bonus PERMANENTE da Torre dos
## Sabios (predio) — os dois canais somam, nenhum substitui o outro, mesmo
## padrao ja provado pra food/production/gold acima.
func test_collect_yields_includes_mana_from_worked_resource_and_building():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var resource_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[0]
	var resource_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	resource_tile.resource = "mana_node"
	hex_grid.tiles[resource_coord] = resource_tile

	var city := City.new()
	city.coord = center
	city.buildings["sages_tower"] = true # +3 mana
	var worked: Array[Vector2i] = [resource_coord]
	city.worked_tiles = worked

	var yields = city.collect_yields(hex_grid)

	# 2 (nodulo arcano trabalhado) + 3 (Torre dos Sabios) = 5, DEPOIS
	# multiplicado pelo bonus de identidade arcana (Roadmap Parte B,
	# CityIdentity.gd — Torre dos Sabios sozinha da forca arcana 1.0/7.0
	# desde que o Santuario do Nodulo entrou no balde, Roadmap Fase F):
	# 5 * (1 + 0.15 * (1/7)) = 5.10714...
	assert_almost_eq(yields.mana, 5.0 * (1.0 + CityIdentity.ARCANA_MANA_BONUS_MAX * (1.0 / 7.0)), 0.01, "2 (nodulo arcano trabalhado) + 3 (Torre dos Sabios), com bonus de identidade arcana por cima")

	hex_grid.queue_free()
	city.queue_free()

func test_effective_tile_yield_mana_node_resource_gives_two_mana():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human

	var data = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
	data.resource = "mana_node"

	var y = city.effective_tile_yield(data)

	assert_eq(y.mana, 2)

	city.queue_free()

func _make_ring_hex_grid(center: Vector2i) -> HexGrid:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return hex_grid

## Regressao: collect_yields() costumava somar o tile da cidade + TODOS os
## vizinhos automaticamente. Agora so soma o tile da cidade (sempre de
## graca) + os tiles em worked_tiles — o resto do potencial da cidade fica
## la, disponivel, mas so conta se um cidadao estiver de fato trabalhando.
func test_collect_yields_only_counts_worked_tiles_not_all_neighbors():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # comida 1
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3 cada

	var city := City.new()
	city.coord = center
	city.population = 2
	city.worked_tiles = [center + HexGrid.NEIGHBOR_DIRS[0]] # so 1 tile trabalhado, mesmo com populacao 2

	var yields = city.collect_yields(hex_grid)

	assert_eq(yields.food, 4, "deveria somar so o centro (oceano=1) + 1 tile trabalhado (planicie=3), nao os 6 vizinhos")

	hex_grid.queue_free()
	city.queue_free()

## Saque de Invasor (MonsterAI._maybe_pillage_tile) zera o rendimento de um
## tile TRABALHADO enquanto a pilhagem estiver ativa (ver HexGrid.
## pillage_tile/is_tile_pillaged) — pedido do usuario: "melhoria do tile
## fica desativada por X turnos". TurnManager.turn_number e global
## (autoload compartilhado por toda a suite), entao salva/restaura o valor
## original igual test_game_manager.gd/test_save_manager.gd ja fazem.
func test_collect_yields_ignores_a_pillaged_worked_tile():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # comida 1
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3 cada

	var city := City.new()
	city.coord = center
	city.population = 2
	var worked_coord = center + HexGrid.NEIGHBOR_DIRS[0]
	city.worked_tiles = [worked_coord]

	var original_turn = TurnManager.turn_number
	TurnManager.turn_number = 10
	hex_grid.pillage_tile(worked_coord, 10, 6)

	var yields = city.collect_yields(hex_grid)
	assert_eq(yields.food, 1, "tile trabalhado pilhado nao deveria render nada, so o centro (oceano=1) deveria contar")

	TurnManager.turn_number = 17 # depois do prazo (10+6=16) — pilhagem deveria ter expirado
	var yields_after = city.collect_yields(hex_grid)
	assert_eq(yields_after.food, 4, "depois de expirar, o tile trabalhado deveria voltar a render normalmente")

	TurnManager.turn_number = original_turn
	hex_grid.queue_free()
	city.queue_free()

## Regressao: dificuldade (PlayerData.yield_multiplier) precisa multiplicar
## o rendimento TOTAL da cidade, nao so o do dono aparecer no numero cru do
## terreno (ver GameManager.DIFFICULTY_MULTIPLIERS).
func test_collect_yields_applies_owner_yield_multiplier():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3

	var rival := PlayerData.new(CivilizationData.new())
	rival.yield_multiplier = 1.5

	var city := City.new()
	city.owner_player = rival
	city.coord = center

	var yields = city.collect_yields(hex_grid)

	assert_almost_eq(yields.food, 4.5, 0.01, "3 (rendimento cru) * 1.5 (multiplicador de dificuldade) = 4.5")

	hex_grid.queue_free()
	city.queue_free()

func test_found_city_auto_assigns_one_worked_tile_for_population_one():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))

	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")

	assert_eq(city.worked_tiles.size(), 1, "populacao 1 deveria comecar com exatamente 1 tile trabalhado")

	hex_grid.queue_free()

func test_auto_assign_worked_tiles_grows_with_population():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")

	city.population = 3
	city.auto_assign_worked_tiles(hex_grid)

	assert_eq(city.worked_tiles.size(), 3, "populacao 3 deveria acabar com 3 tiles trabalhados")

	hex_grid.queue_free()

## Regressao: _best_unassigned_neighbor() costumava pontuar so o rendimento
## CRU do terreno, ignorando bonus de tecnologia/recurso — resultado,
## sugeria uma planicie comum em vez de uma colina com ferro, mesmo o
## ferro rendendo mais no total (ver City.effective_tile_yield).
func test_auto_assign_prefers_tile_with_resource_bonus_over_plain_higher_base_yield():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var plain_dir = HexGrid.NEIGHBOR_DIRS[0]
	var resource_dir = HexGrid.NEIGHBOR_DIRS[1]
	hex_grid.tiles[center + plain_dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3, sem recurso
	var hills_with_iron = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hills_with_iron.resource = "iron" # +2 producao
	hex_grid.tiles[center + resource_dir] = hills_with_iron
	for dir in HexGrid.NEIGHBOR_DIRS:
		if not hex_grid.tiles.has(center + dir):
			hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # fora da disputa

	var city = hex_grid.found_city(center, human, "Capital")

	assert_eq(
		city.worked_tiles[0], center + resource_dir,
		"colinas+ferro rende mais no total (contando o bonus) do que a planicie comum, deveria ser preferida"
	)

	hex_grid.queue_free()

func test_effective_tile_yield_includes_tech_and_resource_bonus():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["transmutacao_rocha"] = true # +1 producao em colinas/montanhas
	var city := City.new()
	city.owner_player = human

	var data = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao base 2
	data.resource = "iron" # +2 producao

	var y = city.effective_tile_yield(data)

	assert_eq(y.production, 5, "2 (base) + 1 (transmutacao de rochas) + 2 (ferro) = 5")

	city.queue_free()

func test_toggle_worked_tile_respects_population_cap():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital") # populacao 1, ja tem 1 tile auto-atribuido

	var extra_neighbor = null
	for n in hex_grid.get_neighbors(Vector2i(0, 0)):
		if not n in city.worked_tiles:
			extra_neighbor = n
			break
	var ok = city.toggle_worked_tile(extra_neighbor, hex_grid)

	assert_false(ok, "nao deveria conseguir trabalhar mais tiles do que a populacao permite")

	hex_grid.queue_free()

func test_toggle_worked_tile_can_unassign_and_reassign():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var worked: Vector2i = city.worked_tiles[0]

	var removed = city.toggle_worked_tile(worked, hex_grid)
	assert_true(removed)
	assert_false(worked in city.worked_tiles)

	var added = city.toggle_worked_tile(worked, hex_grid)
	assert_true(added, "com o cidadao livre de novo, deveria conseguir reatribuir o mesmo tile")
	assert_true(worked in city.worked_tiles)

	hex_grid.queue_free()

func test_is_tile_worked_detects_conflict_with_other_city():
	var human := PlayerData.new(CivilizationData.new())
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city_a = hex_grid.found_city(Vector2i(0, 0), human, "Cidade A")
	var worked_coord: Vector2i = city_a.worked_tiles[0]

	assert_true(hex_grid.is_tile_worked(worked_coord), "tile ja trabalhado por A deveria contar como ocupado")
	assert_false(hex_grid.is_tile_worked(worked_coord, city_a), "excluindo a propria cidade A, nao deveria contar como ocupado")

	hex_grid.queue_free()
