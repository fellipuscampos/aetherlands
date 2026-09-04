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

## Regressao de performance: gerar o mapa Grande retangular precisa
## continuar rapido o bastante pra nao travar a tela de "Jogar"
## perceptivelmente. Medido na maquina de desenvolvimento a ~60-90ms pro
## tamanho ORIGINAL (96x60, 5760 tiles); pedido do usuario de expandir a
## grid pra caber os continentes Vulcanico/de Cristal (320x84, ~26900
## tiles, ~4.7x mais) subiu isso pra ~2.7-2.9s (varias passadas O(tiles)
## — _reclassify_coastal_ocean/_smooth_isolated_biome_cells rodam MULTIPLAS
## vezes cada, entao o custo nao escala so linear com tile count). Margem
## aqui (5s) generosa sobre o observado, so pra pegar uma regressao de
## verdade (ex: alguem tornando a geracao acidentalmente quadratica), nao
## performance normal variando entre maquinas — geracao roda so 1x por
## jogo novo/carregado, nao por turno, entao um tanto mais lenta aqui e um
## trade-off aceito pelo mapa maior, nao uma regressao de turno-a-turno.
func test_generate_map_at_large_radius_completes_quickly():
	var t0 = Time.get_ticks_msec()
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 999)
	var elapsed_ms = Time.get_ticks_msec() - t0

	assert_lt(elapsed_ms, 5000, "geracao do mapa Grande esta demorando demais: %dms" % elapsed_ms)

	grid.queue_free()

## Reportado pelo usuario: "os biomas nao parecem bem trabalhados... nem
## pareciam biomas de neve... nao vi o de fogo". _material_kind_for() e o
## que diz ao shader qual tratamento visual especial usar em vez da
## textura de chao generica (0 = generica, 1 = Neve/Gelo, 2 = Deserto,
## 3 = rocha vulcanica solida generica, 4 = Cristal, 6 = Lava solida) —
## pura, testavel sem precisar de contexto de shader/desenho.
func test_material_kind_for_snow_and_ice_is_one():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.SNOW), 1.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.ICE), 1.0)

func test_material_kind_for_desert_is_two():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.DESERT), 2.0)

## Pedido do usuario: "faça o terreno lava... parecer mais magma,
## atualmente é só uma pedra preta" — Lava ganhou mat_kind PROPRIO (6),
## separado da rocha vulcanica solida generica (3, ver
## test_material_kind_for_volcanic_continent_rock_is_three abaixo), pra
## poder ter veios de magma brilhando sem afetar Terra/Colinas/Montanhas
## Vulcanicas.
func test_material_kind_for_lava_is_six():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.LAVA), 6.0)

func test_material_kind_for_crystal_is_four():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.CRYSTAL), 4.0)

func test_material_kind_for_ordinary_biomes_is_zero():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.GRASSLAND), 0.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.OCEAN), 0.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.MOUNTAINS), 0.0)

## Microbiomas dos continentes Vulcanico/de Cristal reusam mat_kind
## existente (so o `color` de TerrainDatabase muda) — Picos de Cristal e
## Fonte Mistica reusam o brilho/textura animada de Cristal (4); Solo
## Mistico cai no padrao (0), igual a maioria dos biomas normais.
func test_material_kind_for_crystal_peaks_and_mystic_spring_is_four():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.CRYSTAL_PEAKS), 4.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.MYSTIC_SPRING), 4.0)

func test_material_kind_for_mystic_soil_is_zero():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.MYSTIC_SOIL), 0.0)

## Rocha vulcanica solida "morta" de verdade (Montanhas Vulcanicas/Colinas
## Vulcanicas/Terra Vulcanica — SEM Lava, que tem mat_kind PROPRIO agora,
## ver test_material_kind_for_lava_is_six acima) reusa a MESMA textura de
## rocha negra real — regressao original reportada pelo usuario: cor
## generica (mat_kind 0) lia como "terreno marrom apagado que parece
## deserto" em vez de basalto/rocha queimada. So o `color` por tipo muda
## (ver TerrainDatabase, recalibrado numa segunda regressao — "mesmo
## material de basalto preto para tudo, sem contraste" — pra sobrar
## diferenca depois do escurecimento que este mat_kind aplica).
func test_material_kind_for_volcanic_continent_rock_is_three():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.VOLCANIC_PEAKS), 3.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.VOLCANIC_HILLS), 3.0)
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.VOLCANIC_ROCK), 3.0)

## Solo de Cinzas NAO reusa a rocha (regressao: "mude para um tom
## CINZA-CLARO/GRAFITE... contraste imediato com a terra firme") — reusa
## a formula de Deserto (textura de dunas, SEM o escurecimento ×0.6 que a
## rocha aplica) com tint claro, pra ficar genuinamente diferente da
## rocha solida, nao so uma variacao de cor sobre a MESMA textura.
func test_material_kind_for_volcanic_ash_is_two():
	assert_eq(hex_grid._material_kind_for(HexTileData.TerrainType.VOLCANIC_ASH), 2.0)

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
## 30, Lava so podia nascer dentro da faixa de elevacao de Colina/Montanha.
##
## Redesenhado DUAS vezes nesta sessao (continentes Vulcanico/de Cristal +
## regressao "eliminou completamente a lava/gerou 30 montanhas
## agrupadas"): dentro da zona Vulcanica, `_generate_tile_data` reserva
## elevacao MOUNTAINS exclusivamente pra Montanhas Vulcanicas (checada
## ANTES de qualquer decisao de Lava, ver comentario la) — Lava/Mar de
## Lava praticamente nunca nascem em elevacao Montanha por CONSTRUCAO.
## "Praticamente" porque _smooth_isolated_biome_cells (roda DEPOIS, sem
## saber de elevacao) pode ocasionalmente virar um tile de Terra Vulcanica
## isolado (ex: sobra da poda de _thin_special_zone_peaks, ver
## MAX_SPECIAL_ZONE_PEAK_NEIGHBORS) pro bioma Lava se TODOS os vizinhos
## dele ja forem Lava — um punhado de excecoes aceitas (a limpeza de
## isolamento importa mais que exclusividade de elevacao 100% perfeita),
## nao uma regressao de verdade. Colina/Plano continuam livres pra Lava
## (o elemento DOMINANTE ali agora, pedido do usuario).
func test_generate_map_lava_rarely_occupies_mountain_elevation():
	var seeds = [1, 2, 3, 4, 5]
	var saw_lava_anywhere := false
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var lava_total := 0
		var lava_on_mountain := 0
		for coord in grid.tiles.keys():
			if grid.tiles[coord].terrain_type != HexTileData.TerrainType.LAVA and grid.tiles[coord].terrain_type != HexTileData.TerrainType.LAVA_SEA:
				continue
			lava_total += 1
			if grid._elevation_tier(coord) == grid._ElevationTier.MOUNTAINS:
				lava_on_mountain += 1

		if lava_total == 0:
			grid.queue_free()
			continue
		saw_lava_anywhere = true
		assert_lt(
			float(lava_on_mountain) / float(lava_total), 0.1,
			"semente %d: %d/%d tiles de Lava/Mar de Lava estao em elevacao Montanha — deveria ser excecao rara, nao comum" % [s, lava_on_mountain, lava_total]
		)

		grid.queue_free()

	assert_true(saw_lava_anywhere, "nenhuma das %d sementes testadas gerou Lava/Mar de Lava" % seeds.size())

## Regressao critica ("gerei o mapa grande 2x e nenhum veio com bioma de
## vulcao, no maximo vem uma celula vulcanica, nao se forma regiao
## vulcanica", reportado pelo usuario): a garantia de cobertura no Grande
## (`_ensure_biome_variety`) so checava Lava "existir" no mapa, entao 1-2
## celulas isoladas (ou ate uma unica) ja contavam como "coberto" e nunca
## disparavam nenhum reforco — exatamente o bug relatado.
##
## `_ensure_biome_variety` NAO cobre mais Lava (escopada so pra zona
## Principal, ver comentario em ALL_BIOME_TYPES) — Lava agora e uma
## mancha de perigo minoritaria dentro do interior da zona Vulcanica
## dedicada (pedido do usuario nesta sessao: "em vez de ser 100% lava,
## estruture o solo em Terra Vulcanica/Basalto como terreno base"), entao
## a garantia de "SEMPRE forma regiao de FORCED_CLUSTER_MIN" nao existe
## mais pra Lava especificamente (pode legitimamente faltar nalguma
## semente, sem ser bug). O que continua valendo, e o que este teste
## agora confere: QUANDO Lava aparece, ela forma cluster de verdade (nao
## fica em tile isolado sozinho) — regressao ainda relevante pro ruido
## continuo que a gera (_maybe_volcanic).
func test_generate_map_at_large_size_lava_always_forms_a_real_region():
	var seeds = [1, 2, 3, 4, 5, 6, 7, 8]
	var saw_lava_anywhere := false
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var lava_coords := []
		for coord in grid.tiles.keys():
			if grid.tiles[coord].is_lava():
				lava_coords.append(coord)

		if lava_coords.is_empty():
			grid.queue_free()
			continue
		saw_lava_anywhere = true

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

		assert_gt(
			largest, 1,
			"semente %d: maior regiao conectada de Lava tem so %d tile(s) — deveria formar cluster de verdade, nao ficar isolada" % [s, largest]
		)

		grid.queue_free()

	assert_true(saw_lava_anywhere, "nenhuma das %d sementes testadas gerou Lava — algo esta errado com _maybe_volcanic/_volcanic_noise" % seeds.size())

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
				# Montanha Vulcanica (VOLCANIC_PEAKS) e a UNICA excecao
				# deliberada a esta regra — pedido do usuario numa rodada
				# seguinte, depois de reportar vulcoes gerando grudados:
				# "vulcões tem que estar apenas sozinhos" (ver
				# VOLCANIC_PEAK_MAX_NEIGHBORS/_thin_special_zone_peaks em
				# HexGrid.gd). Todo outro bioma continua proibido de ficar
				# isolado — so vulcao TEM que ficar.
				if terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS:
					continue
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
## real do `_moisture_noise`), enquanto Floresta/Selva ficavam com
## ~2.5-9.5%. Gera o mapa Grande com 5 sementes e exige que Deserto fique
## pelo menos numa fracao razoavel do tamanho MEDIO das florestas/selvas
## do mesmo mapa — nao precisa ser identico (biomas diferentes tem area
## diferente por natureza), mas nao pode mais ser uma ordem de grandeza
## menor.
##
## A comparacao equivalente pra Lava/regiao vulcanica foi RETIRADA daqui
## (existia como `volcanic_count` medido no mapa inteiro) — desde que os
## continentes Vulcanico/de Cristal existem, Lava deixou de ser um bioma
## espalhado pelo continente Principal e virou uma mancha de perigo
## MINORITARIA dentro do interior da zona Vulcanica dedicada (pedido do
## usuario nesta sessao: "em vez de ser 100% lava, estruture o solo em
## Terra Vulcanica/Basalto como terreno base"), entao comparar sua
## contagem contra a media de Floresta/Selva do mapa INTEIRO nao mede mais
## nada relevante — ver test_generate_map_at_large_size_volcanic_continent_
## has_real_relief pro equivalente que agora importa (Terra Vulcanica
## precisa ser MAIS comum que Lava/Mar de Lava dentro da propria zona).
func test_generate_map_desert_is_comparable_in_size_to_other_biomes():
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

		assert_gt(
			desert_count, forest_jungle_avg * 0.3,
			"semente %d: Deserto (%d tiles) esta desproporcionalmente pequeno perto da media de Floresta/Selva/Tundra/Taiga (%.0f)" % [s, desert_count, forest_jungle_avg]
		)

		grid.queue_free()

## Fim a fim (mapa Grande de verdade, nao construido a mao): confere que
## _reclassify_coastal_ocean (chamado dentro de generate_map) converteu
## TODO Oceano vizinho de terra FIRME em Costa (o caso incondicional, nunca
## depende de quantas passadas sobram — ver COAST_RECLASSIFY_MAX_PASSES) e
## que TODA Costa faz parte de uma faixa costeira de verdade — toca terra
## firme diretamente OU toca outra Costa (nunca aparece sozinha e
## desconectada no meio do oceano aberto).
##
## NAO afirma mais "todo Oceano vizinho de Costa tambem devia ter virado
## Costa" — isso exigiria a onda de conversao convergir por completo (ate
## nao sobrar NENHUM Oceano tocando Costa), o que so era garantido no mapa
## menor de antes. Com os continentes Vulcanico/de Cristal (pedido do
## usuario) o oceano de separacao entre eles e bem mais largo que qualquer
## faixa costeira litoranea de verdade deveria alcancar, entao a onda
## legitimamente para (por design, COAST_RECLASSIFY_MAX_PASSES) antes de
## consumir o oceano aberto inteiro — Costa continua uma faixa litoranea
## estreita de verdade, nao um problema de convergencia.
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
		elif data.terrain_type == HexTileData.TerrainType.COAST:
			coast_count += 1
			assert_true(touches_land or touches_coast, "Costa em %s deveria fazer parte de uma faixa costeira de verdade (tocar terra ou outra Costa)" % str(coord))

	assert_gt(coast_count, 0, "mapa Grande deveria ter gerado pelo menos uma Costa")

	grid.queue_free()

## Continentes Vulcanico/de Cristal (pedido do usuario: "dois novos
## continentes especiais... utilizando estritamente os tipos de terreno
## que JA EXISTEM"). So no tamanho Grande de verdade (HexGrid._zone_for so
## classifica por retangulo fixo quando _is_large_map_or_bigger()) — mapa
## de teste pequeno continua 100% zona Principal, sem zona especial
## nenhuma (ver test_generate_map_water_percentage_stays_within_the_
## continents_range, que so passa de novo por causa dessa distincao).
func test_zone_for_classifies_main_volcanic_crystal_and_gap_correctly_on_large_map():
	var grid := HexGrid.new()
	grid._ready()
	grid.map_width = TitleScreen.MAP_SIZES.large.width
	grid.map_height = TitleScreen.MAP_SIZES.large.height

	assert_eq(grid._zone_for(Vector2i(0, 0)), grid._Zone.MAIN, "origem deveria estar na zona Principal")
	assert_eq(grid._zone_for(grid.VOLCANIC_ZONE_CENTER), grid._Zone.VOLCANIC, "centro da zona Vulcanica deveria classificar como Vulcanica")
	assert_eq(grid._zone_for(grid.CRYSTAL_ZONE_CENTER), grid._Zone.CRYSTAL, "centro da zona de Cristal deveria classificar como Cristal")
	# Ponto a meio caminho entre Principal e Vulcanica, fora dos limites das duas — oceano de separacao garantido.
	var gap_coord = Vector2i((grid.MAIN_ZONE_CENTER.x + grid.VOLCANIC_ZONE_CENTER.x) / 2, 0)
	assert_eq(grid._zone_for(gap_coord), grid._Zone.NONE, "ponto no meio do gap Principal<->Vulcanica deveria ser NONE (oceano garantido)")

	grid.queue_free()

## Identidade tematica estrita (pedido do usuario: "cada continente deve
## MANTER sua identidade tematica estrita — nada de florestas normais ou
## deserto no vulcanico/cristal"), agora com MICROBIOMAS de verdade em vez
## de um bloco monobioma (pedido do usuario, sessao seguinte: "aplicar a
## eles o mesmo nivel de complexidade, relevo e variacao de microbiomas
## que o Continente Principal possui"): continente Vulcanico so pode ter
## Lava/Mar de Lava/Terra Vulcanica/Montanhas Vulcanicas/Solo de Cinzas;
## continente de Cristal so pode ter Cristal/Picos de Cristal/Solo
## Mistico/Fonte Mistica; continente Principal SEM NENHUM dos 8 tipos
## especiais (nem os originais LAVA/LAVA_SEA/CRYSTAL, nem os 6
## microbiomas novos); e nenhuma contaminacao cruzada entre as duas zonas
## especiais (nada de tipo do Vulcanico aparecendo no Cristal ou
## vice-versa). Semente fixa, mapa Grande de verdade.
func test_generate_map_at_large_size_special_continents_have_pure_composition():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 2024)

	var volcanic_types: Array = [
		HexTileData.TerrainType.LAVA, HexTileData.TerrainType.LAVA_SEA,
		HexTileData.TerrainType.VOLCANIC_ROCK, HexTileData.TerrainType.VOLCANIC_HILLS, HexTileData.TerrainType.VOLCANIC_PEAKS, HexTileData.TerrainType.VOLCANIC_ASH,
	]
	var crystal_types: Array = [
		HexTileData.TerrainType.CRYSTAL, HexTileData.TerrainType.CRYSTAL_PEAKS,
		HexTileData.TerrainType.MYSTIC_SOIL, HexTileData.TerrainType.MYSTIC_SPRING,
	]
	var water_types: Array = [HexTileData.TerrainType.OCEAN, HexTileData.TerrainType.FROZEN_OCEAN, HexTileData.TerrainType.COAST]

	var volcanic_land_count := 0
	var crystal_land_count := 0
	for coord in grid.tiles.keys():
		var terrain_type = grid.tiles[coord].terrain_type
		var zone = grid._zone_for(coord)
		match zone:
			grid._Zone.MAIN:
				assert_false(terrain_type in volcanic_types, "zona Principal nao deveria ter nenhum tile vulcanico (bioma %d) em %s" % [terrain_type, str(coord)])
				assert_false(terrain_type in crystal_types, "zona Principal nao deveria ter nenhum tile de cristal (bioma %d) em %s" % [terrain_type, str(coord)])
			grid._Zone.VOLCANIC:
				if not (terrain_type in water_types):
					assert_true(terrain_type in volcanic_types, "terra na zona Vulcanica deveria ser um microbioma vulcanico, achei bioma %d em %s" % [terrain_type, str(coord)])
					assert_false(terrain_type in crystal_types, "zona Vulcanica nao deveria ter nenhum tile de cristal (contaminacao cruzada), achei bioma %d em %s" % [terrain_type, str(coord)])
					volcanic_land_count += 1
			grid._Zone.CRYSTAL:
				if not (terrain_type in water_types):
					assert_true(terrain_type in crystal_types, "terra na zona de Cristal deveria ser um microbioma de cristal, achei bioma %d em %s" % [terrain_type, str(coord)])
					assert_false(terrain_type in volcanic_types, "zona de Cristal nao deveria ter nenhum tile vulcanico (contaminacao cruzada), achei bioma %d em %s" % [terrain_type, str(coord)])
					crystal_land_count += 1

	assert_gt(volcanic_land_count, 0, "continente Vulcanico deveria ter gerado terra de verdade")
	assert_gt(crystal_land_count, 0, "continente de Cristal deveria ter gerado terra de verdade")

	grid.queue_free()

## Relevo/microbiomas de verdade (pedido do usuario: "gere cordilheiras de
## Montanhas Vulcanicas no centro"/"em vez de ser 100% lava, estruture o
## solo em Terra Vulcanica/Basalto como terreno base"/"adicione zonas de
## Solo de Cinzas nas bordas e praias") — confere que os TRES papeis
## (cordilheira, base caminhavel, periferia) realmente aparecem no
## continente Vulcanico, nao so Lava/Mar de Lava sobrando do design antigo.
func test_generate_map_at_large_size_volcanic_continent_has_real_relief():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 2024)

	var counts := {}
	for coord in grid.tiles.keys():
		if grid._zone_for(coord) != grid._Zone.VOLCANIC:
			continue
		var t = grid.tiles[coord].terrain_type
		counts[t] = counts.get(t, 0) + 1

	assert_gt(counts.get(HexTileData.TerrainType.VOLCANIC_ROCK, 0), 0, "Vulcanico deveria ter Terra Vulcanica (base caminhavel) de verdade")
	assert_gt(counts.get(HexTileData.TerrainType.VOLCANIC_HILLS, 0), 0, "Vulcanico deveria ter Colinas Vulcanicas (elevacao media) de verdade")
	assert_gt(counts.get(HexTileData.TerrainType.VOLCANIC_PEAKS, 0), 0, "Vulcanico deveria ter Montanhas Vulcanicas (cordilheira central) de verdade")
	assert_gt(counts.get(HexTileData.TerrainType.VOLCANIC_ASH, 0), 0, "Vulcanico deveria ter Solo de Cinzas (periferia/praia) de verdade")
	# Lava precisa ser o elemento FLUIDO DOMINANTE (pedido explicito do
	# usuario apos regressao: "a Lava DEVE ser o elemento fluido dominante
	# desta zona... grandes corpos fluidos de Lava cortando a massa
	# terrestre" — NAO mais "minoria", como uma iteracao anterior desta
	# mesma feature tinha deixado). Exige uma fracao substancial (>=35%)
	# do total Lava-ou-Rocha, sem travar num "mais que" exato contra Rocha
	# (o continente ainda precisa de solo caminhavel de verdade pra
	# navegacao, pedido igualmente explicito — "o interior deve ser
	# navegavel/caminhavel entre as fendas de lava e rocha").
	var walkable_base = counts.get(HexTileData.TerrainType.VOLCANIC_ROCK, 0)
	var hazard = counts.get(HexTileData.TerrainType.LAVA, 0) + counts.get(HexTileData.TerrainType.LAVA_SEA, 0)
	assert_gt(hazard, 0, "Vulcanico deveria ter Lava/Mar de Lava de verdade (elemento fluido dominante pedido pelo usuario)")
	assert_gt(
		float(hazard) / float(hazard + walkable_base), 0.35,
		"Lava/Mar de Lava (%d tiles) esta desproporcionalmente pequena perto de Terra Vulcanica (%d tiles) — deveria ser o elemento dominante" % [hazard, walkable_base]
	)

	grid.queue_free()

## Pedido do usuario apos testar de verdade: "eu criei um mapa e veio 3
## vulcoes juntos, vulcoes tem que estar apenas sozinhos" — Montanha
## Vulcanica (VOLCANIC_PEAKS) nunca deveria ter outra Montanha Vulcanica
## como vizinha direta (VOLCANIC_PEAK_MAX_NEIGHBORS=0, mais estrito que o
## limiar de 2 que Picos de Cristal ainda usam). Varias sementes pra nao
## depender de uma unica ter sorteado um caso de teste representativo.
func test_generate_map_volcanic_peaks_are_always_isolated_from_each_other():
	var seeds = [1, 2, 3, 4, 5, 2024]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		for coord in grid.tiles.keys():
			if grid.tiles[coord].terrain_type != HexTileData.TerrainType.VOLCANIC_PEAKS:
				continue
			for n in grid.get_neighbors(coord):
				var ndata: HexTileData = grid.tiles.get(n)
				assert_false(
					ndata != null and ndata.terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS,
					"vulcao em %s (semente %d) tem outro vulcao vizinho em %s — deveriam estar sempre sozinhos" % [str(coord), s, str(n)]
				)

		grid.queue_free()

## Pedido do usuario: "tem que ter pelo menos uns 3 por continente de
## fogo" — _ensure_minimum_volcanic_peaks garante isso mesmo quando a poda
## de isolamento total (teste acima) derruba a maioria dos Picos que a
## elevacao crua tinha proposto.
func test_generate_map_has_at_least_three_isolated_volcanoes():
	var seeds = [1, 2, 3, 4, 5, 2024]
	for s in seeds:
		var grid := HexGrid.new()
		grid._ready()
		grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, s)

		var peak_count := 0
		for coord in grid.tiles.keys():
			if grid._zone_for(coord) == grid._Zone.VOLCANIC and grid.tiles[coord].terrain_type == HexTileData.TerrainType.VOLCANIC_PEAKS:
				peak_count += 1
		assert_gte(peak_count, HexGrid.MIN_VOLCANIC_PEAKS, "semente %d gerou so %d vulcao(oes), esperava pelo menos %d" % [s, peak_count, HexGrid.MIN_VOLCANIC_PEAKS])

		grid.queue_free()

## Mesma ideia do teste acima, pro continente de Cristal (pedido do
## usuario: "gere Picos/Montanhas de Cristal no interior"/"transicionando
## para areas de Solo Mistico... nas regioes mais baixas e costeiras").
## Fonte Mistica ("recursos fluidos") e uma feature RARA de proposito
## (ruido bem acima do limiar normal de Cristal), entao nao e exigida em
## toda semente — so confere que ela pelo menos PODE nascer (usada por
## outro teste especifico, ver test_maybe_crystal_* pro limiar em si).
func test_generate_map_at_large_size_crystal_continent_has_real_relief():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(TitleScreen.MAP_SIZES.large.width, TitleScreen.MAP_SIZES.large.height, 2024)

	var counts := {}
	for coord in grid.tiles.keys():
		if grid._zone_for(coord) != grid._Zone.CRYSTAL:
			continue
		var t = grid.tiles[coord].terrain_type
		counts[t] = counts.get(t, 0) + 1

	assert_gt(counts.get(HexTileData.TerrainType.MYSTIC_SOIL, 0), 0, "Cristal deveria ter Solo Mistico (base caminhavel/periferia) de verdade")
	assert_gt(counts.get(HexTileData.TerrainType.CRYSTAL_PEAKS, 0), 0, "Cristal deveria ter Picos de Cristal (cordilheira central) de verdade")
	assert_gt(counts.get(HexTileData.TerrainType.CRYSTAL, 0), 0, "Cristal deveria ter Campos de Cristal (nucleo denso) de verdade")

	grid.queue_free()

## Roadmap de gameplay Fase 5 — "Metamorfose de Gaia" (ver SpellManager.
## _apply_terrain_transform): troca o TIPO de terreno na Dictionary
## tiles e (melhor esforco) atualiza a COR da instancia no multimesh de
## terreno solido pra nao ficar com a aparencia antiga ate o mapa inteiro
## regenerar. So confere o lado de DADOS aqui — MultiMesh.get_instance_
## color() nao da pra confiar em teste headless (unico lugar desta suite
## que tentou, o renderer "dummy" do --headless nao mantem esse buffer
## de forma legivel; ver transform_tile_terrain em HexGrid.gd pro codigo
## de atualizacao visual em si, exercitado de verdade so jogando).
## Precisa de um mapa GERADO de verdade (nao so tiles populados a mao)
## pra ter _coord_to_index/_multimesh_instance montados.
func test_transform_tile_terrain_updates_the_tile_data():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 555)

	var land_coord = null
	for coord in grid.tiles.keys():
		if not grid.tiles[coord].is_water() and grid._coord_to_index.has(coord):
			land_coord = coord
			break
	assert_not_null(land_coord, "pre-condicao: mapa deveria ter pelo menos 1 tile de terra solida indexado no multimesh")

	var new_type = HexTileData.TerrainType.LAVA if grid.tiles[land_coord].terrain_type != HexTileData.TerrainType.LAVA else HexTileData.TerrainType.SNOW

	grid.transform_tile_terrain(land_coord, new_type)

	assert_eq(grid.get_tile(land_coord).terrain_type, new_type, "dado do tile deveria ter mudado")

	grid.queue_free()
