extends GutTest

## Cobre a geracao de biomas (HexGrid._pick_biome/_temperature_for): a
## matriz temperatura x umidade que substituiu a progressao unica por
## elevacao, e a determinacao pela semente do mapa — critica pro
## Salvar/Carregar continuar recriando o terreno identico (SaveManager.gd
## guarda so `map_seed` + `map_width`/`map_height`, nunca os tiles em si).

var hex_grid: HexGrid

func before_each():
	hex_grid = HexGrid.new()
	hex_grid._ready()

func after_each():
	hex_grid.queue_free()

## 0.15 (nao mais 0.05, ver test_pick_biome_extreme_cold_is_ice abaixo):
## Gelo Eterno agora ocupa a faixa mais extrema (< 0.08), Neve continua a
## faixa "fria mas habitavel" logo acima dele.
func test_pick_biome_very_cold_is_snow():
	assert_eq(hex_grid._pick_biome(0.15, 0.5), HexTileData.TerrainType.SNOW)

## Gelo Eterno (pedido do usuario: "biomas de gelo") e mais severo que
## Neve — a faixa de temperatura mais fria de todas.
func test_pick_biome_extreme_cold_is_ice():
	assert_eq(hex_grid._pick_biome(0.05, 0.5), HexTileData.TerrainType.ICE)

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

## Regressao: Salvar/Carregar so guarda map_seed + map_width/map_height e
## recria o terreno chamando generate_map() de novo (ver SaveManager.load_game) —
## se a geracao deixasse de ser 100% deterministica pela semente, todo
## save antigo passaria a carregar um mapa diferente do salvo.
func test_generate_map_is_deterministic_for_same_seed():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(9, 9, 777)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(9, 9, 777)

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
	grid_a.generate_map(13, 13, 111)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(13, 13, 222)

	var any_different = false
	for coord in grid_a.tiles.keys():
		if grid_b.get_tile(coord).terrain_type != grid_a.get_tile(coord).terrain_type:
			any_different = true
			break
	assert_true(any_different, "sementes diferentes deveriam produzir mapas diferentes")

	grid_a.queue_free()
	grid_b.queue_free()

## Regressao critica (pedido do usuario): o mapa estava saindo ~74% agua
## ("arquipelago denso", medido empiricamente antes desta correcao),
## sufocando a expansao terrestre dos impérios — ver OCEAN_ELEVATION_
## THRESHOLD/continent_noise_frequency (HexGrid.gd) pro ajuste. Gera 5
## mapas com sementes fixas e exige que TODOS fiquem dentro da faixa
## tolerada de 40%-55% de agua — um pouco mais larga que o alvo de design
## (45%-50%) de proposito, pra nao ficar flutuante com a variacao normal
## de ~±5 pontos percentuais entre sementes (medida na mesma amostragem
## que escolheu o threshold).
func test_generate_map_water_percentage_stays_within_the_continents_range():
	var seeds = [1, 42, 999, 12345, 7]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(41, 41, s)

		var water_count := 0
		var total := 0
		for coord in grid.tiles.keys():
			total += 1
			if grid.tiles[coord].is_water():
				water_count += 1
		var water_pct = 100.0 * water_count / total

		assert_true(
			water_pct >= 40.0 and water_pct <= 55.0,
			"semente %d: %.1f%% de agua, fora da faixa tolerada de mapa Continentes/Pangaea (40%%-55%%)" % [s, water_pct]
		)

		grid.queue_free()

## Requisito de "continent shaping" (pedido do usuario): a terra deveria
## formar massas continentais CONTINUAS (onde cabem varias cidades), nao
## um monte de ilhas de 2-3 tiles isoladas — reusa _land_component_size_
## by_coord (BFS de vizinhanca real, ja existente pra decidir ilha pequena
## elegivel a Campos de Cristal) pra medir quanto da terra pertence a UM
## SO bloco conectado. 50% e uma margem folgada de proposito (medido
## empiricamente com os mesmos parametros: ~90-96% na pratica) — so pra
## pegar uma regressao de verdade (ex.: alguem subindo a frequencia do
## ruido de continente de novo), nao flutuacao normal entre sementes.
func test_generate_map_land_forms_large_connected_masses_not_scattered_islands():
	var seeds = [1, 42, 999, 12345, 7]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(41, 41, s)

		# "Terra" aqui e so "nao e agua" (mesmo criterio usado pra classificar
		# elevacao em generate_map — is_land_by_coord = elevation >=
		# OCEAN_ELEVATION_THRESHOLD) — Lava/Mar de Lava continuam contando
		# como parte da massa continental visualmente, so a agua de verdade
		# (is_water()) quebra a continuidade.
		var is_land_by_coord := {}
		var land_total := 0
		for coord in grid.tiles.keys():
			var is_land = not grid.tiles[coord].is_water()
			is_land_by_coord[coord] = is_land
			if is_land:
				land_total += 1

		var component_size = grid._land_component_size_by_coord(grid.tiles.keys(), is_land_by_coord)
		var largest := 0
		for coord in component_size.keys():
			largest = max(largest, component_size[coord])

		assert_true(
			float(largest) / float(land_total) >= 0.5,
			"semente %d: maior massa de terra conectada tem so %d/%d tiles de terra (%.0f%%) — terra parece fragmentada em ilhas pequenas" % [s, largest, land_total, 100.0 * largest / land_total]
		)

		grid.queue_free()

## Regressao ("ta meio bugado os biomas... um monte de celula distribuida
## aleatoriamente... isso nao e bioma de fato", reportado pelo usuario):
## bioma precisa formar REGIOES continuas (varios tiles vizinhos do mesmo
## tipo), nao um padrao "sal e pimenta" tile a tile. Mede, pra cada tile,
## a fracao dos vizinhos que compartilham o MESMO terrain_type, e tira a
## media do mapa inteiro — baixo demais indica biomas fragmentados igual
## ruido puro (cada tile um "bioma" isolado); alto indica regioes de
## verdade. 0.4 e uma margem folgada de proposito (medido empiricamente:
## mapa 61x61 semente 4242 da ~0.75) — so pra pegar uma regressao de verdade
## tipo alguem subindo a frequencia do ruido de novo, nao flutuacao normal
## entre semente/raio diferentes.
func test_generate_map_biomes_form_contiguous_regions_not_scattered_cells():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(61, 61, 4242)

	var fractions := []
	for coord in grid.tiles.keys():
		var data: HexTileData = grid.tiles[coord]
		var neighbors = grid.get_neighbors(coord)
		if neighbors.is_empty():
			continue
		var same := 0
		for n in neighbors:
			if grid.tiles[n].terrain_type == data.terrain_type:
				same += 1
		fractions.append(float(same) / float(neighbors.size()))

	var average = 0.0
	for f in fractions:
		average += f
	average /= fractions.size()

	assert_gt(average, 0.4, "biomas parecem fragmentados demais (media de vizinhos do mesmo tipo: %.2f) — deveriam formar regioes continuas" % average)

	grid.queue_free()

## Mar Gelado (`_pick_water_biome`, pedido do usuario: "mares") e a
## variante polar do Oceano — mesma funcao pura de `_pick_biome`.
func test_pick_water_biome_cold_is_frozen_ocean():
	assert_eq(hex_grid._pick_water_biome(0.05), HexTileData.TerrainType.FROZEN_OCEAN)

func test_pick_water_biome_warm_is_ocean():
	assert_eq(hex_grid._pick_water_biome(0.5), HexTileData.TerrainType.OCEAN)

## Lava (`_maybe_volcanic`, pedido do usuario, roadmap item 30: "e ser um
## bioma terrestre tal qual qualquer outro... nao montanhas") — mesma
## ideia de `_maybe_crystal`, so substitui QUALQUER bioma de terra firme
## (plano, Colina ou Montanha) ja escolhido quando o ruido vulcanico passa
## do limiar raro (mas nao o limiar AINDA MAIOR do Mar de Lava, ver teste
## seguinte), senao devolve o bioma original sem mexer.
func test_maybe_volcanic_high_volcanic_value_overrides_any_land_biome():
	assert_eq(hex_grid._maybe_volcanic(HexTileData.TerrainType.GRASSLAND, 0.35), HexTileData.TerrainType.LAVA)
	assert_eq(hex_grid._maybe_volcanic(HexTileData.TerrainType.HILLS, 0.35), HexTileData.TerrainType.LAVA)
	assert_eq(hex_grid._maybe_volcanic(HexTileData.TerrainType.MOUNTAINS, 0.35), HexTileData.TerrainType.LAVA)

## Mar de Lava (`_maybe_volcanic`, roadmap item 32, pedido do usuario:
## "pegar o sistema de oceano que temos e fazer um igual so que
## vermelho") — limiar ainda MAIS raro que a pedra de Lava, sobre o MESMO
## ruido vulcanico (o nucleo mais quente de uma regiao de Lava vira
## liquido).
func test_maybe_volcanic_very_high_volcanic_value_becomes_lava_sea():
	assert_eq(hex_grid._maybe_volcanic(HexTileData.TerrainType.GRASSLAND, 0.9), HexTileData.TerrainType.LAVA_SEA)

func test_maybe_volcanic_normal_value_keeps_original_biome():
	assert_eq(hex_grid._maybe_volcanic(HexTileData.TerrainType.GRASSLAND, 0.1), HexTileData.TerrainType.GRASSLAND)

## Campos de Cristal (`_maybe_crystal`, bioma arcano original): so
## substitui o bioma "plano" ja escolhido quando o ruido arcano e alto,
## senao devolve o bioma original sem mexer.
func test_maybe_crystal_high_arcane_value_overrides_biome():
	assert_eq(hex_grid._maybe_crystal(HexTileData.TerrainType.GRASSLAND, 0.9), HexTileData.TerrainType.CRYSTAL)

func test_maybe_crystal_normal_value_keeps_original_biome():
	assert_eq(hex_grid._maybe_crystal(HexTileData.TerrainType.GRASSLAND, 0.1), HexTileData.TerrainType.GRASSLAND)

## Regressao: HexTileData.blocks_land_units() precisa cobrir os 2 tipos de
## agua E lava — usado por HexGrid.compute_reachable, City.is_valid_
## building_tile/_best_unassigned_neighbor/toggle_worked_tile, WorldSetup
## (spawn/capital) e HUD (lista de "tiles trabalhados").
func test_blocks_land_units_covers_water_and_lava():
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN).blocks_land_units())
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.FROZEN_OCEAN).blocks_land_units())
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA).blocks_land_units())
	assert_false(TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND).blocks_land_units())

func test_is_water_does_not_include_lava():
	assert_false(TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA).is_water(), "Lava e intransitavel mas nao e agua")

## Costa (pedido do usuario, "Coast" tipo Civilization): agua de verdade
## (unidade terrestre nao anda), mas — diferente de Oceano aberto/Mar
## Gelado/Mar de Lava — PODE ser trabalhada por uma cidade (ver
## City._best_unassigned_neighbor/toggle_worked_tile, que agora usam
## can_be_worked() em vez de blocks_land_units() direto).
func test_coast_is_water_and_workable_but_ocean_is_not():
	var coast = TerrainDatabase.create_tile(HexTileData.TerrainType.COAST)
	assert_true(coast.is_water())
	assert_true(coast.blocks_land_units())
	assert_true(coast.can_be_worked())

	var ocean = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	assert_true(ocean.is_water())
	assert_false(ocean.can_be_worked())

	var frozen = TerrainDatabase.create_tile(HexTileData.TerrainType.FROZEN_OCEAN)
	assert_false(frozen.can_be_worked())

## _reclassify_coastal_ocean (chamado em generate_map, ver HexGrid.gd) —
## Oceano vizinho de terra firme vira Costa; Oceano isolado no meio do mar
## e Mar Gelado (mesmo vizinho de terra) ficam como estavam.
func test_reclassify_coastal_ocean_converts_only_ocean_touching_land():
	hex_grid.tiles.clear()
	var land := Vector2i(0, 0)
	hex_grid.tiles[land] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var coastal_ocean := land + HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.tiles[coastal_ocean] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var coastal_frozen := land + HexGrid.NEIGHBOR_DIRS[1]
	hex_grid.tiles[coastal_frozen] = TerrainDatabase.create_tile(HexTileData.TerrainType.FROZEN_OCEAN)
	var deep_ocean := land + HexGrid.NEIGHBOR_DIRS[2] * 5 # bem longe, sem vizinho de terra nenhum
	hex_grid.tiles[deep_ocean] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

	hex_grid._reclassify_coastal_ocean()

	assert_eq(hex_grid.tiles[coastal_ocean].terrain_type, HexTileData.TerrainType.COAST, "Oceano vizinho de terra deveria virar Costa")
	assert_eq(hex_grid.tiles[coastal_frozen].terrain_type, HexTileData.TerrainType.FROZEN_OCEAN, "Mar Gelado nao tem variante de Costa, deveria continuar igual")
	assert_eq(hex_grid.tiles[deep_ocean].terrain_type, HexTileData.TerrainType.OCEAN, "Oceano sem vizinho de terra deveria continuar Oceano aberto")

## Regressao de performance: gerar o mapa Grande retangular (96x60, 5760
## tiles — pedido do usuario com as dimensoes exatas do Civilization)
## precisa continuar rapido o bastante pra nao travar a tela de "Jogar"
## perceptivelmente. Medido na maquina de desenvolvimento: ~60-90ms; a
## margem aqui (2s) e generosa de proposito, so pra pegar uma regressao
## de verdade (ex: alguem tornando a geracao acidentalmente quadratica),
## nao performance normal variando entre maquinas.
func test_generate_map_at_large_radius_completes_quickly():
	var t0 = Time.get_ticks_msec()
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 999)
	var elapsed_ms = Time.get_ticks_msec() - t0

	assert_lt(elapsed_ms, 2000, "geracao do mapa Grande esta demorando demais: %dms" % elapsed_ms)

	grid.queue_free()

## Reportado pelo usuario: "os biomas nao parecem bem trabalhados... nem
## pareciam biomas de neve... nao vi o de fogo". _material_kind_for() e o
## que diz ao shader qual tratamento visual especial usar em vez da
## textura de chao generica (0 = generica, 1 = Neve/Gelo, 2 = Deserto,
## 3 = Lava, 4 = Cristal) — pura, testavel sem precisar de contexto de
## shader/desenho.
func test_material_kind_for_snow_and_ice_is_one():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.SNOW), 1.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.ICE), 1.0)

func test_material_kind_for_desert_is_two():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.DESERT), 2.0)

func test_material_kind_for_lava_is_three():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.LAVA), 3.0)

func test_material_kind_for_crystal_is_four():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.CRYSTAL), 4.0)

func test_material_kind_for_ordinary_biomes_is_zero():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.GRASSLAND), 0.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.OCEAN), 0.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.MOUNTAINS), 0.0)

## Reportado pelo usuario: biomas raros (Lava, Cristal, Mar Gelado, Gelo)
## as vezes nao apareciam nenhuma vez no mapa. "Acho que faz sentido todos
## os biomas sempre serem gerados pelo menos no grande" — no tamanho
## Grande (`TitleScreen.MAP_SIZES.large`), TODO tipo de bioma precisa
## aparecer pelo menos uma vez.
func test_generate_map_at_large_size_contains_every_biome_type():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 555)

	var present := {}
	for data in grid.tiles.values():
		present[data.terrain_type] = true

	for terrain_type in HexGrid.ALL_BIOME_TYPES:
		assert_true(present.has(terrain_type), "bioma %d deveria aparecer pelo menos uma vez no tamanho Grande" % terrain_type)

	grid.queue_free()

## Mesma garantia com uma semente diferente — nao deveria depender de
## sorte de uma unica semente especifica.
func test_generate_map_at_large_size_contains_every_biome_type_with_another_seed():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 12321)

	var present := {}
	for data in grid.tiles.values():
		present[data.terrain_type] = true

	for terrain_type in HexGrid.ALL_BIOME_TYPES:
		assert_true(present.has(terrain_type), "bioma %d deveria aparecer pelo menos uma vez no tamanho Grande" % terrain_type)

	grid.queue_free()

## Mapas menores continuam 100% probabilisticos de proposito ("nos outros
## talvez faça sentido ter menos", palavras do usuario) — _ensure_biome_
## variety() nao deveria mexer em nada abaixo do tamanho Grande.
func test_ensure_biome_variety_does_nothing_below_the_large_threshold():
	var grid := HexGrid.new()
	grid._ready()
	grid.map_width = TitleScreen.MAP_SIZES.large.width - 1
	grid.map_height = TitleScreen.MAP_SIZES.large.height - 1
	grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	grid._ensure_biome_variety()

	assert_eq(grid.tiles[Vector2i(0, 0)].terrain_type, HexTileData.TerrainType.GRASSLAND, "abaixo do tamanho Grande, nao deveria forcar bioma nenhum")

	grid.queue_free()

## A garantia de biomas continua deterministica pela map_seed, igual todo
## o resto da geracao — Salvar/Carregar depende disso.
func test_generate_map_at_large_size_biome_variety_is_deterministic():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 777)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 777)

	for coord in grid_a.tiles.keys():
		assert_eq(
			grid_b.get_tile(coord).terrain_type, grid_a.get_tile(coord).terrain_type,
			"tile %s deveria ter o mesmo bioma nos dois mapas com a mesma semente, mesmo depois de _ensure_biome_variety()" % coord
		)

	grid_a.queue_free()
	grid_b.queue_free()

## Regressao ("seria um bioma agrupado... com rios de lava e pedras
## negras", pedido do usuario): Lava agora nasce em qualquer terra firme
## (`_maybe_volcanic`) pela mesma mancha de ruido vulcanico, entao deveria
## formar REGIOES de varios tiles vizinhos, nao ficar so como picos
## isolados. Mede a fracao de tiles de Lava que tem pelo menos UM vizinho
## tambem de Lava — semente 555 no tamanho Grande, confirmada manualmente
## a gerar uma regiao vulcanica de verdade, maioria em terreno que era
## originalmente PLANO, nao Colina/Montanha (roadmap item 30).
func test_generate_map_lava_forms_a_clustered_region_not_isolated_tiles():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 555)

	var lava_coords := []
	for coord in grid.tiles.keys():
		if grid.tiles[coord].terrain_type == HexTileData.TerrainType.LAVA:
			lava_coords.append(coord)

	assert_gt(lava_coords.size(), 1, "semente/raio deveriam gerar mais de um tile de Lava")

	var clustered := 0
	for c in lava_coords:
		for n in grid.get_neighbors(c):
			if grid.tiles[n].terrain_type == HexTileData.TerrainType.LAVA:
				clustered += 1
				break

	var fraction = float(clustered) / float(lava_coords.size())
	assert_gt(fraction, 0.5, "Lava deveria formar regiao agrupada (fracao com vizinho de Lava: %.2f)" % fraction)

	grid.queue_free()

## Regressao critica ("acho que voce ta fazendo como se fossem montanhas,
## o lance do bioma vulcanico e ser um bioma terrestre tal qual qualquer
## outro... nao montanhas", reportado pelo usuario): antes do roadmap item
## 30, Lava so podia nascer dentro da faixa de elevacao de Colina/Montanha
## (`_pick_hills_biome`/`_pick_mountain_biome`, ja removidas) — mesmo
## formando uma regiao "agrupada" tecnicamente, ela nunca conseguia se
## espalhar pra terreno PLANO, entao sempre ficava perto/dentro de uma
## cadeia de montanhas, parecendo so "montanha diferente" em vez de um
## bioma de verdade. Gera o mapa Grande com 5 sementes diferentes e exige
## que a MAIORIA dos tiles de Lava de cada mapa esteja em elevacao FLAT
## (terreno que teria sido plano se nao fosse Lava), nao HILLS/MOUNTAINS.
func test_generate_map_lava_mostly_occupies_flat_terrain_not_just_mountains():
	var seeds = [1, 2, 3, 4, 5]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var flat_count := 0
		var total := 0
		for coord in grid.tiles.keys():
			if grid.tiles[coord].terrain_type != HexTileData.TerrainType.LAVA:
				continue
			total += 1
			if grid._elevation_tier(coord) == grid._ElevationTier.FLAT:
				flat_count += 1

		assert_gt(total, 0, "semente %d: mapa Grande deveria ter Lava" % s)
		assert_gt(
			float(flat_count) / float(total), 0.5,
			"semente %d: so %d/%d tiles de Lava estao em terreno originalmente plano — deveria ser a maioria, nao ficar restrito a Colina/Montanha" % [s, flat_count, total]
		)

		grid.queue_free()

## Regressao critica ("gerei o mapa grande 2x e nenhum veio com bioma de
## vulcao, no maximo vem uma celula vulcanica, nao se forma regiao
## vulcanica", reportado pelo usuario): a garantia de cobertura no Grande
## (`_ensure_biome_variety`) so checava Lava "existir" no mapa, entao 1-2
## celulas isoladas (ou ate uma unica) ja contavam como "coberto" e nunca
## disparavam nenhum reforco — exatamente o bug relatado. Testa 8 sementes
## diferentes (bateria maior que os outros testes de terreno de proposito,
## pra realmente pegar o pior caso) no tamanho Grande: TODAS precisam ter
## uma regiao VULCANICA conectada (pedra de Lava OU Mar de Lava — ver
## HexTileData.is_lava(), roadmap item 32: o nucleo de uma regiao pode
## virar liquido, entao a regiao continua sendo UMA SO mesmo com pedra e
## liquido misturados) de pelo menos `FORCED_CLUSTER_MIN` tiles (ver
## `_ensure_forced_region`).
func test_generate_map_at_large_size_lava_always_forms_a_real_region():
	var seeds = [1, 2, 3, 4, 5, 6, 7, 8]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var lava_coords := []
		for coord in grid.tiles.keys():
			if grid.tiles[coord].is_lava():
				lava_coords.append(coord)

		var visited := {}
		var largest = 0
		for coord in lava_coords:
			if visited.has(coord):
				continue
			var size = 0
			var stack = [coord]
			visited[coord] = true
			while stack.size() > 0:
				var c = stack.pop_back()
				size += 1
				for n in grid.get_neighbors(c):
					if grid.tiles[n].is_lava() and not visited.has(n):
						visited[n] = true
						stack.append(n)
			largest = max(largest, size)

		assert_gte(
			largest, grid.FORCED_CLUSTER_MIN,
			"semente %d: maior regiao conectada de Lava tem so %d tile(s) — deveria formar uma regiao de verdade, nao ficar isolada" % [s, largest]
		)

		grid.queue_free()

## Regressao critica (roadmap item 31), **reportado pelo usuario** pela
## TERCEIRA vez seguida sobre o mesmo assunto: "ele ainda ta formando
## celulas isoladas... nenhum bioma deve ser tao pequeno ao ponto de
## formar celulas isoladas de um bioma... o deserto e o vulcanico sao os
## piores... tem uma floresta gigante e 1 celula de vulcanico". Cortar
## ruido continuo em faixas com limiar fixo (`_pick_biome`,
## `_maybe_volcanic`, `_maybe_crystal`) sempre deixa alguns tiles isolados
## perto das bordas — corrigido com `_smooth_isolated_biome_cells()`
## (roda em TODO tamanho de mapa, antes de `_ensure_biome_variety`).
## Gera 10 mapas no tamanho Grande (unico tamanho que o jogo cria desde
## "elimine a criacao do mapa medio e pequeno, vamos a partir de agora
## usar so o grande" — sementes deterministicas de um RandomNumberGenerator
## com semente fixa) e exige que NENHUM tile fique sem nenhum vizinho do
## mesmo bioma — nao especifico de Deserto/Lava, vale pra qualquer um dos
## 16 tipos.
func test_generate_map_never_has_isolated_single_tile_biomes():
	var randgen = RandomNumberGenerator.new()
	randgen.seed = 5555
	var sizes = [TitleScreen.MAP_SIZES.large]
	for map_size in sizes:
		for i in range(10):
			var s = randgen.randi()
			var grid := HexGrid.new()
			grid._ready()
			grid.generate_map(map_size.width, map_size.height, s)

			for coord in grid.tiles.keys():
				var terrain_type = grid.tiles[coord].terrain_type
				var neighbors = grid.get_neighbors(coord)
				if neighbors.is_empty():
					continue
				var has_same_neighbor = false
				for n in neighbors:
					if grid.tiles[n].terrain_type == terrain_type:
						has_same_neighbor = true
						break
				assert_true(
					has_same_neighbor,
					"mapa %dx%d semente %d: tile %s (bioma %d) esta isolado, sem nenhum vizinho do mesmo bioma" % [map_size.width, map_size.height, s, coord, terrain_type]
				)

			grid.queue_free()

## Regressao critica (roadmap item 32), **reportado pelo usuario**: "nada
## de oceanos de lava ainda, e literalmente impossivel pegar o sistema de
## oceano que temos e fazer um igual so que vermelho num bioma com aquele
## solo vulcanico?". `_ensure_lava_sea_present()` garante que todo mapa
## Grande com regiao de Lava tambem tem Mar de Lava (o limiar mais alto
## do ruido vulcanico ja da isso na maioria das sementes sozinho, medido
## empiricamente; a garantia so cobre o resto). Testa 8 sementes: toda vez
## que ha Lava no mapa Grande, tem que ter Mar de Lava tambem, E os dois
## tiles do Mar de Lava (ou mais) tem que estar conectados entre si
## (nunca uma "poca" de 1 tile isolada — mesmo principio do item 31).
func test_generate_map_at_large_size_always_has_a_lava_sea_when_lava_present():
	var seeds = [1, 2, 3, 4, 5, 6, 7, 8]
	var checked_at_least_one_map_with_lava = false
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var has_lava := false
		var sea_coords := []
		for coord in grid.tiles.keys():
			if grid.tiles[coord].terrain_type == HexTileData.TerrainType.LAVA:
				has_lava = true
			if grid.tiles[coord].terrain_type == HexTileData.TerrainType.LAVA_SEA:
				sea_coords.append(coord)

		if not has_lava:
			grid.queue_free()
			continue
		checked_at_least_one_map_with_lava = true

		assert_gt(sea_coords.size(), 0, "semente %d: mapa Grande tem Lava mas nenhum Mar de Lava" % s)

		var visited := {}
		var largest = 0
		for coord in sea_coords:
			if visited.has(coord):
				continue
			var size = 0
			var stack = [coord]
			visited[coord] = true
			while stack.size() > 0:
				var c = stack.pop_back()
				size += 1
				for n in grid.get_neighbors(c):
					if grid.tiles[n].terrain_type == HexTileData.TerrainType.LAVA_SEA and not visited.has(n):
						visited[n] = true
						stack.append(n)
			largest = max(largest, size)
		assert_gt(largest, 1, "semente %d: Mar de Lava existe mas fica isolado (maior regiao conectada: %d tile(s))" % [s, largest])

		grid.queue_free()

	assert_true(checked_at_least_one_map_with_lava, "nenhuma das sementes testadas gerou Lava — teste nao esta cobrindo nada")

## Regressao: Mar de Lava participa do MESMO tratamento de "corpo liquido"
## que Oceano no shader (roadmap item 32) — `_material_kind_for` devolve
## 5 (o codigo que o shader usa pra tingir de vermelho/emissivo em vez do
## azul padrao de agua).
func test_material_kind_for_lava_sea_is_five():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.LAVA_SEA), 5.0)

## Regressao: Mar de Lava bloqueia unidade terrestre igual pedra de Lava
## (`is_lava()`/`blocks_land_units()`) mas NAO conta como agua de verdade
## (`is_water()` continua exclusiva de Oceano/Mar Gelado) — sao sistemas
## visuais parecidos (mesma animacao de onda) mas semanticamente
## diferentes no jogo.
func test_lava_sea_blocks_land_units_but_is_not_water():
	var data = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA_SEA)
	assert_true(data.is_lava())
	assert_true(data.blocks_land_units())
	assert_false(data.is_water(), "Mar de Lava e lava, nao agua")

## Regressao critica (roadmap item 33), **reportado pelo usuario** pela
## QUARTA vez seguida sobre o mesmo assunto, bem direto: "esse bioma
## vulcanico ainda ta extremamente pequeno, o de deserto tambem esta
## extremamente pequeno... 5 celulaszinhas nao fazem um bioma". Antes
## desta correcao, Deserto/Estepe ficavam com ~3-11% da propria faixa de
## temperatura (limiares de umidade 0.3/0.6 mal calibrados pra distribuicao
## real do `_moisture_noise`) e Lava com ~0.1-1% do mapa (limiar alto
## demais, pensado pra ser "raro"), enquanto Floresta/Selva ficavam com
## ~2.5-9.5%. Gera o mapa Grande com 5 sementes e exige que Deserto e a
## regiao vulcanica (pedra + Mar de Lava) fiquem pelo menos numa fracao
## razoavel do tamanho MEDIO das florestas/selvas do mesmo mapa — nao
## precisam ser identicos (biomas diferentes tem area diferente por
## natureza), mas nao podem mais ser uma ordem de grandeza menores.
func test_generate_map_desert_and_volcanic_are_comparable_in_size_to_other_biomes():
	var seeds = [1, 2, 3, 4, 5]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var counts := {}
		for coord in grid.tiles.keys():
			var t = grid.tiles[coord].terrain_type
			counts[t] = counts.get(t, 0) + 1

		var forest_jungle_avg = (
			counts.get(HexTileData.TerrainType.FOREST, 0)
			+ counts.get(HexTileData.TerrainType.JUNGLE, 0)
			+ counts.get(HexTileData.TerrainType.TUNDRA, 0)
			+ counts.get(HexTileData.TerrainType.TAIGA, 0)
		) / 4.0
		var desert_count = counts.get(HexTileData.TerrainType.DESERT, 0)
		var volcanic_count = counts.get(HexTileData.TerrainType.LAVA, 0) + counts.get(HexTileData.TerrainType.LAVA_SEA, 0)

		assert_gt(
			desert_count, forest_jungle_avg * 0.3,
			"semente %d: Deserto (%d tiles) esta desproporcionalmente pequeno perto da media de Floresta/Selva/Tundra/Taiga (%.0f)" % [s, desert_count, forest_jungle_avg]
		)
		# Vulcanico usa uma razao mais baixa que Deserto (0.1 em vez de 0.3,
		# ver VOLCANIC_COASTAL_MAX_DISTANCE em HexGrid.gd): elegibilidade
		# vulcanica exige litoral proximo OU Montanha, entao ela escala com
		# a fracao de terra COSTEIRA, nao com a area total de terra. O
		# rebalanceamento de agua/terra (pedido do usuario — continentes
		# grandes e conectados em vez de arquipelago) fez a terra costeira
		# encolher como FRACAO da terra total (continente maior = menos
		# litoral por area, geometria basica), entao a media de Floresta/
		# Selva/Tundra/Taiga (que escala com area total) cresceu bem mais
		# rapido que a regiao vulcanica nesta rodada — nao e mais "5
		# celulaszinhas" (a barra que este teste realmente existe pra
		# pegar, ver o pedido original do usuario acima), so uma proporcao
		# menor perto de biomas que nao dependem de litoral.
		assert_gt(
			volcanic_count, forest_jungle_avg * 0.1,
			"semente %d: regiao vulcanica (%d tiles) esta desproporcionalmente pequena perto da media de Floresta/Selva/Tundra/Taiga (%.0f)" % [s, volcanic_count, forest_jungle_avg]
		)

		grid.queue_free()

## Fim a fim (mapa Grande de verdade, nao construido a mao): confere que
## _reclassify_coastal_ocean (chamado dentro de generate_map) converteu
## TODO Oceano vizinho de terra OU de outra Costa em Costa (nenhum Oceano
## "preso" sobrando, ver comentario da funcao sobre o bug de tile isolado
## que a expansao em passadas corrige) e que TODA Costa faz parte de uma
## faixa costeira de verdade — toca terra firme diretamente OU toca outra
## Costa (nunca aparece sozinha e desconectada no meio do oceano aberto).
func test_generate_map_coastal_ocean_becomes_coast_end_to_end():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 777)

	var coast_count := 0
	for coord in grid.tiles.keys():
		var data: HexTileData = grid.tiles[coord]
		var touches_land := false
		var touches_coast := false
		for n in grid.get_neighbors(coord):
			var ndata: HexTileData = grid.tiles[n]
			if not ndata.is_water() and not ndata.is_lava():
				touches_land = true
			elif ndata.terrain_type == HexTileData.TerrainType.COAST:
				touches_coast = true

		if data.terrain_type == HexTileData.TerrainType.OCEAN:
			assert_false(touches_land, "Oceano em %s toca terra firme e deveria ter virado Costa" % str(coord))
			assert_false(touches_coast, "Oceano em %s toca Costa e deveria ter virado Costa tambem (expansao em passadas)" % str(coord))
		elif data.terrain_type == HexTileData.TerrainType.COAST:
			coast_count += 1
			assert_true(touches_land or touches_coast, "Costa em %s deveria fazer parte de uma faixa costeira de verdade (tocar terra ou outra Costa)" % str(coord))

	assert_gt(coast_count, 0, "mapa Grande deveria ter gerado pelo menos uma Costa")

	grid.queue_free()
