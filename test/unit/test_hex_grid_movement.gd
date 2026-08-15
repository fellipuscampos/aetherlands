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

## Tingimento de territorio (pedido do usuario, requisito 3: "camada
## transparente com a cor da civilizacao no chao de cada hexagono do
## territorio"). Cada tile vira um leque de 6 triangulos (centro + par de
## cantos consecutivos) = 18 vertices; o territorio padrao de found_city
## (celula + 6 vizinhos) tem 7 tiles = 126 vertices, contando que todos
## estejam VISIBLE.
func test_build_city_tint_mesh_covers_all_owned_tiles():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	for coord in city.owned_tiles:
		hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE

	var mesh = hex_grid._build_city_tint_mesh(city)

	assert_eq(mesh.get_surface_count(), 1)
	var vertex_count = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_eq(vertex_count, 7 * 18, "7 tiles (celula + 6 vizinhos) x 18 vertices (leque de 6 triangulos) cada")

## Nevoa no tingimento — mesma filosofia do contorno: UNSEEN nao gera
## geometria nenhuma, EXPLORED fica com uma FRACAO da opacidade normal.
func test_build_city_tint_mesh_skips_unseen_and_dims_explored_tiles():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	# visibility nunca foi populado neste fixture — tudo comeca UNSEEN.
	var empty_mesh = hex_grid._build_city_tint_mesh(city)
	assert_eq(empty_mesh.get_surface_count(), 0, "territorio inteiro UNSEEN nao deveria gerar tingimento nenhum")

	hex_grid.visibility[Vector2i(0, 0)] = HexGrid.Visibility.VISIBLE
	var explored_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.visibility[explored_coord] = HexGrid.Visibility.EXPLORED

	var mesh = hex_grid._build_city_tint_mesh(city)
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]

	var saw_full_alpha := false
	var saw_dimmed_alpha := false
	var expected_dimmed = HexGrid.TERRITORY_TINT_ALPHA * HexGrid.TERRITORY_TINT_EXPLORED_ALPHA_MULT
	for c in colors:
		if abs(c.a - HexGrid.TERRITORY_TINT_ALPHA) < 0.005:
			saw_full_alpha = true
		elif abs(c.a - expected_dimmed) < 0.005:
			saw_dimmed_alpha = true
	assert_true(saw_full_alpha, "tile VISIBLE deveria tingir com TERRITORY_TINT_ALPHA cheio")
	assert_true(saw_dimmed_alpha, "tile EXPLORED deveria tingir com uma fracao da opacidade normal")

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

## "Mover ate" tipo Civilization (pedido do usuario: "no civilization eu
## posso colocar pra ela se mover pra um lugar longe... o movimento fica
## gravado e todo turno essa tropa vai se movendo") — compute_path acha o
## caminho INTEIRO ate um destino longe, sem o teto de movement_points que
## compute_reachable tem.
func test_compute_path_returns_full_route_ignoring_movement_cap():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(4, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0)) # so 2 de movimento, destino fica a 4 tiles

	var path = hex_grid.compute_path(warrior.coord, Vector2i(4, 0), warrior.owner_player)

	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "caminho completo deveria incluir os 4 passos, mesmo bem alem do movimento de UM turno")

func test_compute_path_to_the_same_tile_is_empty():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var path = hex_grid.compute_path(warrior.coord, warrior.coord, warrior.owner_player)

	assert_eq(path.size(), 0)

func test_compute_path_to_a_tile_outside_the_map_is_empty():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var path = hex_grid.compute_path(warrior.coord, Vector2i(999, 999), warrior.owner_player)

	assert_eq(path.size(), 0)

## Continua um pedido pendente (Unit.move_order_target) sozinha, sem
## precisar de novo clique do jogador — chega direto se o destino cabe no
## movimento atual.
func test_continue_move_order_reaches_destination_directly_when_it_fits_in_current_movement():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0)) # 2 de movimento, destino a 2 tiles
	warrior.move_order_target = Vector2i(2, 0)

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(2, 0))
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "ordem deveria ser limpa ao chegar")

## O ponto central do pedido: destino longe demais pra UM turno anda o
## quanto der e MANTEM a ordem pendente, pra continuar sozinha depois.
func test_continue_move_order_advances_partially_and_keeps_the_order_pending_when_destination_is_far():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(4, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0)) # 2 de movimento, destino a 4 tiles
	warrior.move_order_target = Vector2i(4, 0)

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(2, 0), "deveria andar exatamente os 2 tiles que o movimento do turno permite")
	assert_eq(warrior.movement_left, 0.0)
	assert_eq(warrior.move_order_target, Vector2i(4, 0), "ordem deveria continuar pendente pro proximo turno")

## Simula 2 turnos seguidos (reset_movement + continue_move_order, mesma
## sequencia de GameManager._on_turn_changed) ate a unidade chegar sozinha.
func test_continue_move_order_resumes_across_turns_until_arrival():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(4, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.move_order_target = Vector2i(4, 0)

	hex_grid.continue_move_order(warrior) # turno 1: anda ate (2,0), sem movimento sobrando
	assert_eq(warrior.coord, Vector2i(2, 0))

	warrior.reset_movement() # troca de turno
	hex_grid.continue_move_order(warrior) # turno 2: anda o resto ate (4,0)

	assert_eq(warrior.coord, Vector2i(4, 0))
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER)

## Rota recalculada do ZERO a cada chamada (nao segue um caminho salvo) —
## se outra unidade ocupar o UNICO caminho possivel no meio do trajeto, a
## ordem desiste (limpa move_order_target) em vez de ficar tentando pra
## sempre sem nenhum feedback.
func test_continue_move_order_gives_up_when_the_path_becomes_blocked():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.move_order_target = Vector2i(2, 0)
	_make_unit("warrior", rival, Vector2i(1, 0)) # bloqueia o unico caminho ate (2,0) neste fixture minimo

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0), "nao deveria ter se movido nenhum passo")
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "deveria desistir da ordem em vez de travar tentando pra sempre")

func test_continue_move_order_does_nothing_without_a_pending_order():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0))
	assert_eq(warrior.movement_left, warrior.unit_data.movement_points)

## Regressao/relato de bug do usuario: "se ele tiver movendo e eu ativar
## o fortificar ele não para... ao ativar o estado de fortificado ele
## deve cancelar as outras ações" — rede de seguranca no proprio
## continue_move_order (alem do cancelamento em SelectionManager.
## fortify_selected): uma unidade fortificada NUNCA deveria continuar
## andando sozinha, mesmo que move_order_target continue setado por
## algum motivo.
func test_continue_move_order_does_nothing_when_fortified():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.move_order_target = Vector2i(2, 0)
	warrior.fortified = true

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0), "unidade fortificada nao deveria se mover sozinha")
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "a ordem pendente deveria ser limpa, nao so ignorada")

## "Explorar" tipo Civilization (pedido do usuario: "uma função que fica
## ativada... que se baseie em ficar andando por territórios que ainda
## não foram explorados") — anda sozinha na direcao do tile UNSEEN mais
## perto. Marca tudo VISIBLE exceto UM vizinho especifico, senao o "mais
## perto" empataria entre os 6 vizinhos identicos do fixture padrao.
func test_explore_step_moves_toward_the_nearest_unseen_tile():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.exploring = true
	hex_grid.visibility[Vector2i(0, 0)] = HexGrid.Visibility.VISIBLE
	for dir in HexGrid.NEIGHBOR_DIRS:
		if dir != Vector2i(1, 0):
			hex_grid.visibility[dir] = HexGrid.Visibility.VISIBLE

	hex_grid.explore_step(warrior)

	assert_eq(warrior.coord, Vector2i(1, 0), "deveria ter andado na direcao do UNICO tile UNSEEN por perto")

func test_explore_step_turns_off_when_nothing_left_unexplored():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.exploring = true
	hex_grid.visibility[Vector2i(0, 0)] = HexGrid.Visibility.VISIBLE
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.visibility[dir] = HexGrid.Visibility.VISIBLE

	hex_grid.explore_step(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0), "sem tile UNSEEN nenhum, nao deveria se mover")
	assert_false(warrior.exploring, "deveria desligar sozinho quando nao sobra nada pra explorar")

func test_explore_step_does_nothing_when_not_exploring():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	hex_grid.explore_step(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0))

## Mesma rede de seguranca de test_continue_move_order_does_nothing_when_
## fortified acima — Fortificar sempre vence.
func test_explore_step_does_nothing_when_fortified():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.exploring = true
	warrior.fortified = true

	hex_grid.explore_step(warrior)

	assert_eq(warrior.coord, Vector2i(0, 0), "unidade fortificada nao deveria explorar sozinha")
	assert_false(warrior.exploring, "exploring deveria ser desligado, nao so ignorado")

func test_tiles_in_range_does_not_include_tiles_beyond_range():
	var center := Vector2i(0, 0)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var result = hex_grid.tiles_in_range(center, 1)

	assert_false(Vector2i(2, 0) in result, "tile a 2 passos nao deveria entrar no alcance 1")
