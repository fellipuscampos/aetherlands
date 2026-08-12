extends GutTest

## Colonizador e o unico kind sem predio de treino associado (ver
## BuildingDatabase.building_that_trains), entao e o default seguro pra
## uma cidade recem-fundada — Guerreiro agora exige o Quartel construido
## (ver can_train() abaixo), nao pode mais ser o default.
func test_default_production_is_settler():
	var city := City.new()
	assert_eq(city.production_item, "settler")
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
	city.stored_production = 10.0
	city.set_production("settler") # ja e o padrao, nao deveria zerar
	assert_eq(city.stored_production, 10.0)

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

	city.stored_food = 999.0 # forca cruzar o limiar de crescimento neste turno
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

	assert_true(spawned, "cidade deveria ter completado a producao do guerreiro em 20 turnos")

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
	assert_true(city.can_build("granary"))
	city.buildings["granary"] = true
	assert_false(city.can_build("granary"))
	city.queue_free()

## Pivot pedido pelo usuario: "cada tropa e feita numa construcao... so
## pode treinar as tropas na sua respectiva construcao". Guerreiro exige o
## Quartel ja construido nesta cidade especifica antes de poder ser
## produzido — ver BuildingDatabase.building_that_trains().
func test_can_train_is_false_without_the_matching_training_building():
	var city := City.new()
	assert_false(city.can_train("warrior"), "sem Quartel construido, Guerreiro nao deveria ser treinavel")
	city.queue_free()

func test_can_train_is_true_once_the_matching_training_building_is_built():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_true(city.can_train("warrior"))
	city.queue_free()

## Ter o predio de treino de OUTRA tropa nao libera esta — cada predio so
## libera o kind que ele mesmo treina.
func test_can_train_does_not_leak_across_different_training_buildings():
	var city := City.new()
	city.buildings["barracks"] = true # treina Guerreiro, nao Arqueiro
	assert_false(city.can_train("archer"))
	city.queue_free()

## Pivot seguinte pedido pelo usuario: "so posso construir esses predios
## especiais quando pesquisar a tecnologia, ai aparece disponivel pra
## construir". Campo de Tiro (treina Arqueiro) so pode ser CONSTRUIDO
## depois de pesquisar Tiro com Arco — antes disso can_build() ja bloqueia,
## nem chega a abrir o modo de posicionamento de tile.
func test_can_build_training_building_is_false_without_its_tech():
	var human := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = human
	assert_false(city.can_build("archery_range"), "sem Tiro com Arco pesquisado, Campo de Tiro nao deveria poder ser construido")
	city.queue_free()

func test_can_build_training_building_is_true_once_its_tech_is_researched():
	var human := PlayerData.new(CivilizationData.new())
	human.researched_techs["archery"] = true
	var city := City.new()
	city.owner_player = human
	assert_true(city.can_build("archery_range"))
	city.queue_free()

## Quartel treina Guerreiro, que nunca exigiu pesquisa nenhuma
## (TechDatabase.tech_that_unlocks("warrior") == null) — deveria continuar
## sempre construivel desde o inicio, sem depender de owner_player nem de
## tecnologia nenhuma.
func test_can_build_barracks_never_requires_research():
	var city := City.new()
	assert_true(city.can_build("barracks"))
	city.queue_free()

## Regressao critica: predios de RENDIMENTO (trains_unit vazio) NAO
## deveriam exigir tecnologia nenhuma — sem essa guarda,
## TechDatabase.tech_that_unlocks("") "encontraria" a primeira tech de
## bioma da lista (Agricultura) por acidente, bloqueando o Celeiro ate
## pesquisar algo que nem tem nada a ver com ele.
func test_can_build_yield_building_never_requires_research():
	var city := City.new()
	assert_true(city.can_build("granary"), "Celeiro (predio de rendimento) nao deveria depender de tecnologia nenhuma")
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

	assert_false(city.can_build("workshop"), "populacao 1 so cabe 1 predio — ja tem o Celeiro, nao deveria caber mais nenhum")

	city.population = 2
	assert_true(city.can_build("workshop"), "populacao 2 deveria abrir espaco pro segundo predio")

	city.queue_free()

## Regressao: completar um predio precisa marcar buildings[id]=true (pra
## sempre, ver collect_yields()) e devolver built_kind pro GameManager
## notificar — diferente de unidade, nao spawna nada no grid.
func test_process_turn_completes_building_and_switches_back_to_settler():
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
	assert_eq(city.production_item, "settler", "deveria trocar pro unico kind sempre produzivel (sem predio de treino) em vez de tentar reconstruir o mesmo predio")

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
	city.buildings["granary"] = true # +2 comida

	var yields = city.collect_yields(hex_grid)

	assert_almost_eq(yields.food, 5.0, 0.01, "3 (tile) + 2 (Celeiro) = 5")

	hex_grid.queue_free()
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
	human.researched_techs["mining"] = true # +1 producao em colinas/montanhas
	var city := City.new()
	city.owner_player = human

	var data = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao base 2
	data.resource = "iron" # +2 producao

	var y = city.effective_tile_yield(data)

	assert_eq(y.production, 5, "2 (base) + 1 (mineracao) + 2 (ferro) = 5")

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
