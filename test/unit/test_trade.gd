extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## Comercio, MVP fechado (roadmap de gameplay Fase 4A, ver TradeManager.gd/
## TradeRoute.gd). Escopo deliberadamente minimo: rota ponto-a-ponto entre
## duas cidades, renda pequena de comida/producao/ouro todo turno enquanto
## ativa, capacidade vinda do Mercado, cancelamento por guerra ou captura.
## Sem caravana atacavel nem transporte de recurso aqui — isso e Fase 4B.

var hex_grid: HexGrid

func before_each():
	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

func after_each():
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
	hex_grid.queue_free()

func _city_with_market(coord: Vector2i, player: PlayerData, name: String) -> City:
	var city := hex_grid.found_city(coord, player, name)
	city.buildings["market"] = true
	return city

func test_propose_route_succeeds_between_cities_of_different_players_at_peace_with_market():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")

	var route := TradeManager.propose_route(city_a, city_b)

	assert_not_null(route, "rota deveria ser criada entre cidades de jogadores diferentes, em paz, com Mercado")
	assert_true(a.trade_routes.has(route))
	assert_true(b.trade_routes.has(route))

func test_propose_route_fails_between_cities_of_the_same_player():
	var a := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), a, "Cidade B")

	var route := TradeManager.propose_route(city_a, city_b)

	assert_null(route, "nao deveria haver rota de comercio de uma civ com ela mesma")

func test_propose_route_fails_when_at_war():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	Diplomacy.declare_war(a, b)
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")

	var route := TradeManager.propose_route(city_a, city_b)

	assert_null(route, "nao deveria haver comercio entre civs em guerra")

## Pedido do usuario: "Mercado ganha um segundo efeito real: aumenta o
## numero maximo de rotas simultaneas" — sem ele, capacidade e 0.
func test_propose_route_fails_without_market_in_either_city():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var city_a := hex_grid.found_city(Vector2i(0, 0), a, "Cidade A") # sem Mercado
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")

	var route := TradeManager.propose_route(city_a, city_b)

	assert_null(route, "sem Mercado numa das pontas, a rota nao deveria caber")

func test_propose_route_fails_when_a_citys_capacity_is_full():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var c := _track_player(CivilizationData.new())
	var d := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A") # capacidade 2 (1 Mercado)
	hex_grid.tiles[Vector2i(6, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(7, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")
	var city_c := _city_with_market(Vector2i(6, 0), c, "Cidade C")
	var city_d := _city_with_market(Vector2i(7, 0), d, "Cidade D")

	assert_not_null(TradeManager.propose_route(city_a, city_b))
	assert_not_null(TradeManager.propose_route(city_a, city_c))
	var third := TradeManager.propose_route(city_a, city_d)

	assert_null(third, "capacidade da Cidade A (2, so 1 Mercado) ja deveria estar cheia")

## Mesma heuristica de Diplomacy._accepts_peace (reaproveitada, nao
## reinventada) — uma civ "ganhando" (mais unidades) recusa a proposta.
func test_propose_route_is_refused_by_a_much_stronger_civ():
	var proposer := _track_player(CivilizationData.new())
	var other := _track_player(CivilizationData.new())
	for i in range(3):
		other.units.append(null)
	var city_a := _city_with_market(Vector2i(0, 0), proposer, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), other, "Cidade B")

	var route := TradeManager.propose_route(city_a, city_b)

	assert_null(route, "civ muito mais forte deveria recusar a proposta, mesma heuristica de aceitar paz")

func test_process_all_routes_applies_income_to_both_cities_and_owners():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")
	TradeManager.propose_route(city_a, city_b)
	var food_a_before = city_a.stored_food
	var production_a_before = city_a.stored_production
	var gold_a_before = a.gold

	TradeManager.process_all_routes([a, b])

	assert_almost_eq(city_a.stored_food, food_a_before + TradeManager.ROUTE_INCOME_FOOD, 0.01)
	assert_almost_eq(city_a.stored_production, production_a_before + TradeManager.ROUTE_INCOME_PRODUCTION, 0.01)
	assert_almost_eq(a.gold, gold_a_before + TradeManager.ROUTE_INCOME_GOLD, 0.01)
	assert_almost_eq(city_b.stored_food, TradeManager.ROUTE_INCOME_FOOD, 0.01, "a outra ponta tambem deveria render")

## O elo mais importante pedido pelo usuario: guerra declarada entre as
## duas pontas cancela a rota no proximo processamento de turno.
func test_process_all_routes_removes_route_when_war_is_declared():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")
	var route := TradeManager.propose_route(city_a, city_b)
	assert_not_null(route, "pre-condicao: rota deveria existir antes da guerra")

	Diplomacy.declare_war(a, b)
	TradeManager.process_all_routes([a, b])

	assert_false(a.trade_routes.has(route), "guerra deveria cancelar a rota do lado do proposer")
	assert_false(b.trade_routes.has(route), "guerra deveria cancelar a rota do outro lado tambem")

func test_process_all_routes_removes_route_when_a_city_is_captured():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var c := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")
	var route := TradeManager.propose_route(city_a, city_b)

	city_b.change_owner(c) # capturada por um TERCEIRO jogador, nao envolvido na rota original

	TradeManager.process_all_routes([a, b, c])

	assert_false(a.trade_routes.has(route), "cidade capturada deveria cancelar o acordo comercial antigo")
	assert_false(c.trade_routes.has(route), "novo dono nao herda a rota do antigo")

func test_active_route_count_reflects_routes_touching_a_city():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A")
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")

	assert_eq(TradeManager.active_route_count(city_a), 0)

	TradeManager.propose_route(city_a, city_b)

	assert_eq(TradeManager.active_route_count(city_a), 1)
	assert_eq(TradeManager.active_route_count(city_b), 1)

func test_max_trade_routes_is_zero_without_market():
	var player := _track_player(CivilizationData.new())
	var city := hex_grid.found_city(Vector2i(0, 0), player, "Capital")
	assert_eq(city.max_trade_routes(), 0)

func test_max_trade_routes_with_market():
	var player := _track_player(CivilizationData.new())
	var city := _city_with_market(Vector2i(0, 0), player, "Capital")
	assert_eq(city.max_trade_routes(), City.MARKET_ROUTE_CAPACITY_BONUS)

## Roadmap 2.0 Parte 1 (B1) — identidade de Seda: com `hex_grid` passado,
## uma cidade com 2+ fontes de Seda controladas aceita uma rota ALEM da
## capacidade base do Mercado (que sozinha ja estaria cheia).
func test_propose_route_succeeds_over_market_capacity_with_enough_silk():
	var a := _track_player(CivilizationData.new())
	var b := _track_player(CivilizationData.new())
	var c := _track_player(CivilizationData.new())
	var d := _track_player(CivilizationData.new())
	var city_a := _city_with_market(Vector2i(0, 0), a, "Cidade A") # capacidade base 2 (1 Mercado)
	# owned_tiles setado A MAO (nao via anel automatico de found_city, que
	# so pega vizinhos JA presentes em hex_grid.tiles no momento da
	# fundacao — os tiles de Seda abaixo ainda nao existiam nesse momento).
	var silk_coords: Array[Vector2i] = [HexGrid.NEIGHBOR_DIRS[0], HexGrid.NEIGHBOR_DIRS[1]]
	for dir in silk_coords:
		var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
		tile.resource = "silk"
		hex_grid.tiles[dir] = tile
	city_a.owned_tiles.append_array(silk_coords)
	hex_grid.tiles[Vector2i(6, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(-6, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_b := _city_with_market(Vector2i(5, 0), b, "Cidade B")
	var city_c := _city_with_market(Vector2i(6, 0), c, "Cidade C")
	var city_d := _city_with_market(Vector2i(-6, 0), d, "Cidade D")

	assert_not_null(TradeManager.propose_route(city_a, city_b)) # 1a rota, dentro da capacidade base
	assert_not_null(TradeManager.propose_route(city_a, city_c)) # 2a rota, capacidade base (2) ja cheia agora

	var third_without_grid := TradeManager.propose_route(city_a, city_d)
	assert_null(third_without_grid, "sem hex_grid, capacidade base (2) ja deveria estar cheia")

	var third_with_grid := TradeManager.propose_route(city_a, city_d, hex_grid)
	assert_not_null(third_with_grid, "com hex_grid e 2 fontes de Seda, a capacidade extra (+1) deveria caber uma 3a rota")
