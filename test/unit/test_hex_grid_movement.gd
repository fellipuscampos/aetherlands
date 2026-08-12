extends GutTest

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []

func before_each():
	_created_units = []
	hex_grid = HexGrid.new()
	# HexGrid so cria _units_root/_cities_root em _ready(), que o motor so
	# chama quando o node entra na scene tree. Nao adicionamos a arvore
	# real aqui (teste isolado), entao chamamos manualmente — nada dentro
	# de _ready() depende de estar parentado, so cria meshes/nodes filhos.
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())

func after_each():
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

## Regressao do bug relatado pelo usuario: atacar uma cidade inimiga sem
## defensor estava so movendo a unidade pra cima dela em vez de capturar,
## porque compute_reachable() nao excluia tiles de cidade inimiga — o tile
## entrava tanto em "alcancavel" quanto em "atacavel", e o movimento
## ganhava prioridade no clique. Ver SelectionManager.handle_world_click().
func test_enemy_city_is_not_reachable_by_movement():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.found_city(Vector2i(1, 0), rival, "Cidade Inimiga")

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_false(reachable.has(Vector2i(1, 0)), "cidade inimiga nao deveria ser destino de movimento — so de ataque/captura")

func test_own_city_is_still_reachable_for_garrisoning():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.found_city(Vector2i(1, 0), human, "Minha Cidade")

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_true(reachable.has(Vector2i(1, 0)), "unidade deveria poder guarnecer a propria cidade")

func test_tile_occupied_by_any_unit_blocks_movement():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(1, 0)) # mesmo dono, ainda bloqueia (sem empilhar)

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_false(reachable.has(Vector2i(1, 0)))

func test_capturing_undefended_city_transfers_ownership():
	hex_grid.found_city(Vector2i(1, 0), rival, "Cidade Inimiga")
	var city = hex_grid.get_city_at(Vector2i(1, 0))

	hex_grid.capture_city(city, human)

	assert_eq(city.owner_player, human)
	assert_true(human.cities.has(city))
	assert_false(rival.cities.has(city))

## Predio POSICIONADO no mapa (Building.gd, ver City.building_coords) —
## registrado igual unidade/cidade (units_by_coord/cities_by_coord).
func test_place_building_registers_it_at_the_right_coord():
	var building = hex_grid.place_building(Vector2i(1, 0), "granary", human)

	assert_eq(hex_grid.get_building_at(Vector2i(1, 0)), building)
	assert_eq(building.building_id, "granary")
	assert_eq(building.owner_player, human)

func test_is_tile_building_site_reflects_placed_building():
	assert_false(hex_grid.is_tile_building_site(Vector2i(1, 0)))
	hex_grid.place_building(Vector2i(1, 0), "granary", human)
	assert_true(hex_grid.is_tile_building_site(Vector2i(1, 0)))

## "Limite da cidade sempre visivel, como um contorno do Civilization"
## (pedido do usuario): fundar uma cidade ja cria um contorno permanente
## na cor da civilizacao, sem depender de selecao na HUD.
func test_found_city_creates_a_border():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	assert_true(hex_grid._city_borders.has(city), "fundar deveria criar um contorno pra cidade")

## Regressao: capturar uma cidade precisa RECONSTRUIR o contorno (cor nova,
## do novo dono) — senao o territorio capturado continuaria mostrando a
## cor do dono antigo.
func test_capture_city_rebuilds_border():
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var border_before = hex_grid._city_borders[city]

	hex_grid.capture_city(city, human)

	assert_true(hex_grid._city_borders.has(city))
	assert_ne(hex_grid._city_borders[city], border_before, "contorno deveria ser reconstruido ao mudar de dono")

func test_city_territory_tiles_includes_city_and_all_neighbors():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var territory = hex_grid.city_territory_tiles(city)

	assert_true(territory.has(Vector2i(0, 0)))
	for dir in HexGrid.NEIGHBOR_DIRS:
		assert_true(territory.has(dir))

func test_city_owning_tile_detects_conflict_with_other_city():
	var city_a = hex_grid.found_city(Vector2i(0, 0), human, "Cidade A")

	assert_eq(hex_grid.city_owning_tile(Vector2i(0, 0)), city_a)
	assert_null(hex_grid.city_owning_tile(Vector2i(0, 0), city_a), "excluindo a propria cidade, ninguem mais possui esse tile")

## Territorio agora e dinamico (City.owned_tiles, nao mais sempre "celula +
## 6 vizinhos") — confirma que a malha de contorno filtra arestas internas
## corretamente mesmo pra um formato IRREGULAR (aqui, so 2 tiles vizinhos,
## um "dominó" em vez de um hexagono completo). Cada tile isolado tem 6
## arestas; a aresta COMPARTILHADA entre os 2 e filtrada dos dois lados
## (interna), sobrando 5 expostas em cada um = 10 arestas x 6 vertices
## (2 triangulos por aresta) cada.
func test_build_city_border_mesh_filters_internal_edges_for_irregular_territory():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var neighbor_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[0]
	# Array[Vector2i] explicito (nao um literal [a, b] cru) — atribuir um
	# Array generico direto a uma propriedade Array[Vector2i] de outro
	# objeto falha em tempo de execucao no GDScript se o literal nao for
	# reconhecido como homogeneo em tempo de compilacao.
	var domino_territory: Array[Vector2i] = [Vector2i(0, 0), neighbor_coord]
	city.owned_tiles = domino_territory
	for coord in city.owned_tiles:
		hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE

	var mesh = hex_grid._build_city_border_mesh(city)

	assert_eq(mesh.get_surface_count(), 1)
	var vertex_count = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_eq(vertex_count, 10 * 6, "2 tiles em 'domino': 5 arestas expostas cada (a compartilhada e filtrada dos dois lados) = 10 arestas x 6 vertices")

## Acompanhamento de relevo (pedido do usuario: "nao use uma altura Y fixa
## para todo o segmento... busque a altura real do terreno"). Reusa a
## mesma tecnica de _tallest_neighbor_height/_corner_point_safe ja usada
## pelos rios pra nao atravessar a "parede" de um vizinho bem mais alto.
func test_border_mesh_snaps_to_tallest_neighbor_not_flat_tile_height():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var raised_coord = HexGrid.NEIGHBOR_DIRS[0]
	var raised_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	raised_tile.base_height = 5.0 # bem acima de qualquer bioma padrao, pra nao dar empate por acaso
	hex_grid.tiles[raised_coord] = raised_tile
	for coord in city.owned_tiles:
		hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var center_tile: HexTileData = hex_grid.tiles[Vector2i(0, 0)]

	var mesh = hex_grid._build_city_border_mesh(city)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var max_y := -INF
	for v in vertices:
		max_y = max(max_y, v.y)

	assert_almost_eq(max_y, 5.0 + HexGrid.BORDER_ABOVE_OFFSET, 0.001, "canto do contorno deveria subir ate a altura do vizinho mais alto")
	assert_gt(max_y, center_tile.base_height + HexGrid.BORDER_ABOVE_OFFSET, "deveria ser maior que a altura FIXA antiga (base_height cru do proprio tile), provando que agora acompanha o relevo vizinho")

## Nevoa POR SEGMENTO (requisito do usuario): UNSEEN nem gera geometria
## (oculto sob a nevoa), EXPLORED gera com alfa reduzido e cor dessaturada
## (nao a cor crua da civ), VISIBLE fica cheio.
func test_border_mesh_skips_unseen_tiles_and_dims_explored_ones():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	# visibility nunca foi populado neste fixture — todo o territorio comeca UNSEEN.
	var empty_mesh = hex_grid._build_city_border_mesh(city)
	assert_eq(empty_mesh.get_surface_count(), 0, "territorio inteiro UNSEEN nao deveria gerar geometria nenhuma")

	# Encolhe pra so 2 tiles: com o hexagono completo (7 tiles) de found_city,
	# o proprio tile central fica "cercado" pelo resto do territorio (todo
	# vizinho seu ainda esta em owned_tiles, mesmo fogado) e nunca expoe
	# nenhuma aresta, independente da propria visibilidade — precisa de um
	# territorio menor pra garantir que os 2 tiles realmente expoem borda.
	var explored_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[0]
	var shrunk_territory: Array[Vector2i] = [Vector2i(0, 0), explored_coord]
	city.owned_tiles = shrunk_territory
	hex_grid.visibility[Vector2i(0, 0)] = HexGrid.Visibility.VISIBLE
	hex_grid.visibility[explored_coord] = HexGrid.Visibility.EXPLORED

	var mesh = hex_grid._build_city_border_mesh(city)
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var civ_color = human.civ.color
	var full_color := Color(civ_color.r, civ_color.g, civ_color.b, 1.0)

	# SurfaceTool.commit() comprime COLOR pra 8 bits por canal por padrao —
	# 0.55 vira ~140/255 (0.549...) na malha final, entao a comparacao de
	# alfa precisa de uma tolerancia maior que is_equal_approx() (feito pra
	# ruido de ponto flutuante, nao quantizacao de 1/255 ~= 0.0039).
	var saw_full_alpha := false
	var saw_reduced_alpha := false
	for c in colors:
		if c.is_equal_approx(full_color):
			saw_full_alpha = true
		elif abs(c.a - HexGrid.EXPLORED_BORDER_ALPHA) < 0.01:
			saw_reduced_alpha = true
	assert_true(saw_full_alpha, "trecho VISIBLE deveria ter alfa 1.0 e cor cheia da civ")
	assert_true(saw_reduced_alpha, "trecho EXPLORED deveria ter alfa reduzido e cor dessaturada (nao a cor crua da civ)")

## Marcador animado de "em construcao" (pedido do usuario: mostrar que ali
## tem uma obra rolando) — refresh_construction_markers() reconcilia com
## City.pending_building_coord de TODAS as cidades, em vez de precisar
## rastrear manualmente cada lugar que esse campo pode mudar.
func test_refresh_construction_markers_creates_marker_for_pending_building():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	city.pending_building_coord = Vector2i(1, 0)

	hex_grid.refresh_construction_markers()

	assert_true(hex_grid._construction_markers.has(Vector2i(1, 0)))

func test_refresh_construction_markers_removes_marker_once_no_longer_pending():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	city.pending_building_coord = Vector2i(1, 0)
	hex_grid.refresh_construction_markers()
	assert_true(hex_grid._construction_markers.has(Vector2i(1, 0)))

	city.pending_building_coord = City.NO_PENDING_COORD
	hex_grid.refresh_construction_markers()

	assert_false(hex_grid._construction_markers.has(Vector2i(1, 0)), "marcador deveria sumir quando o predio nao esta mais pendente")

## Base da previa de trajeto (estilo Civilization) mostrada ao passar o
## mouse sobre um tile alcancavel — ver SelectionManager.handle_world_hover().
func test_reconstruct_path_returns_correct_step_sequence():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.movement_left = 2.0 # grama custa 1 por tile, guerreiro alcanca 2 tiles

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)
	assert_true(reachable.has(Vector2i(2, 0)), "com 2 pontos de movimento devia alcancar 2 tiles de grama a frente")

	var path = hex_grid.reconstruct_path(warrior.coord, Vector2i(2, 0))
	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0)], "caminho deveria passar pelo tile intermediario")

func test_reconstruct_path_to_unreachable_tile_is_empty():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	var path = hex_grid.reconstruct_path(warrior.coord, Vector2i(50, 50))

	assert_eq(path.size(), 0)

## Base do alcance de ataque (SelectionManager/RivalAI) — nunca tinha
## teste proprio, so cobertura indireta via esses chamadores.
func test_tiles_in_range_returns_immediate_neighbors_for_range_1():
	var center := Vector2i(0, 0)
	var result = hex_grid.tiles_in_range(center, 1)

	assert_eq(result.size(), 6, "raio 1 deveria devolver exatamente os 6 vizinhos imediatos")
	for dir in HexGrid.NEIGHBOR_DIRS:
		assert_true(center + dir in result)

func test_tiles_in_range_excludes_the_center_tile():
	var center := Vector2i(0, 0)
	var result = hex_grid.tiles_in_range(center, 1)

	assert_false(center in result, "o proprio tile central nao deveria entrar no resultado")

func test_tiles_in_range_includes_tiles_two_steps_away():
	var center := Vector2i(0, 0)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var result = hex_grid.tiles_in_range(center, 2)

	assert_true(Vector2i(2, 0) in result, "tile a 2 passos deveria entrar no alcance 2")

## Grifo (UnitData.flies): atravessa oceano onde qualquer outra unidade
## fica presa — reforca o tema de fantasia (montaria voadora ignora o
## limite geografico que trava o resto do exercito).
func test_flying_unit_can_cross_ocean():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(griffin.coord, griffin.movement_left, griffin.owner_player, griffin.unit_data.flies)

	assert_true(reachable.has(Vector2i(1, 0)), "unidade voadora deveria conseguir atravessar oceano")

func test_non_flying_unit_cannot_cross_ocean():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player, warrior.unit_data.flies)

	assert_false(reachable.has(Vector2i(1, 0)), "unidade terrestre nao deveria atravessar oceano")

## Regressao: voar "por cima" do terreno significa ignorar o CUSTO dele
## tambem, nao so a restricao de oceano — senao colina/floresta ainda
## atrasariam o grifo como qualquer outra unidade.
func test_flying_unit_ignores_terrain_movement_cost():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS) # custo alto
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))
	griffin.movement_left = 2.0

	var reachable = hex_grid.compute_reachable(griffin.coord, griffin.movement_left, griffin.owner_player, griffin.unit_data.flies)

	assert_true(reachable.has(Vector2i(2, 0)), "com custo 1/tile (voando), 2 pontos de movimento deveriam alcancar 2 montanhas")

## Lava (HexTileData.blocks_land_units(), bioma vulcanico novo) e
## intransitavel pra unidade terrestre, mesma regra do oceano — so
## unidade que voa consegue atravessar.
func test_non_flying_unit_cannot_cross_lava():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player, warrior.unit_data.flies)

	assert_false(reachable.has(Vector2i(1, 0)), "unidade terrestre nao deveria atravessar lava")

func test_flying_unit_can_cross_lava():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(griffin.coord, griffin.movement_left, griffin.owner_player, griffin.unit_data.flies)

	assert_true(reachable.has(Vector2i(1, 0)), "unidade voadora deveria conseguir atravessar lava")

## Mar Gelado (variante polar do Oceano, "os mares") tambem e agua de
## verdade — mesma regra de intransitavel pra unidade terrestre.
func test_non_flying_unit_cannot_cross_frozen_ocean():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.FROZEN_OCEAN)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player, warrior.unit_data.flies)

	assert_false(reachable.has(Vector2i(1, 0)), "unidade terrestre nao deveria atravessar Mar Gelado")

func test_tiles_in_range_does_not_include_tiles_beyond_range():
	var center := Vector2i(0, 0)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var result = hex_grid.tiles_in_range(center, 1)

	assert_false(Vector2i(2, 0) in result, "tile a 2 passos nao deveria entrar no alcance 1")
