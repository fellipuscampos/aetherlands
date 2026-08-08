extends GutTest

## Cobre o ciclo salvar/carregar: o estado logico (ouro, unidades com
## hp/movimento, cidades com producao/populacao, semente do mapa, turno)
## precisa sobreviver a uma volta completa por JSON em disco. Usa um
## arquivo de teste isolado (TEST_SAVE_PATH) pra nunca tocar no save real
## do jogador.

const TEST_SAVE_PATH := "user://test_savegame.json"

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _created_hex_grids: Array[HexGrid] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_kingdom_name: String
var _original_state
var _original_turn_number: int
var _original_turn_player_index: int
var _original_map_radius: int
var _original_difficulty: String

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_kingdom_name = GameManager.human_kingdom_name
	_original_state = GameManager.state
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_map_radius = GameManager.map_radius
	_original_difficulty = GameManager.difficulty
	_created_units = []
	_created_hex_grids = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(3, 12345) # mapa pequeno com semente fixa (determinismo)
	_created_hex_grids.append(hex_grid)

	human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	rival = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	GameManager.human_player = human
	GameManager.rival_players = [rival]

func after_each():
	SaveManager.delete_save(TEST_SAVE_PATH)
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.human_kingdom_name = _original_kingdom_name
	GameManager.state = _original_state
	TurnManager.turn_number = _original_turn_number
	TurnManager.current_player_index = _original_turn_player_index
	GameManager.map_radius = _original_map_radius
	GameManager.difficulty = _original_difficulty

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_save_and_load_restores_player_and_map_state():
	var coords = hex_grid.tiles.keys()
	var unit_coord: Vector2i = coords[0]
	var city_coord: Vector2i = coords[1]
	var rival_coord: Vector2i = coords[2]

	var warrior = _make_unit("warrior", human, unit_coord)
	warrior.hp = 7.0
	warrior.movement_left = 1.0
	human.gold = 42.0
	_make_unit("warrior", rival, rival_coord) # so pra check_game_over() nao fechar o jogo no load

	var city = hex_grid.found_city(city_coord, human, "Minha Capital")
	city.set_production("archer") # antes de setar stored_production: ver comentario em SaveManager
	city.population = 3
	city.auto_assign_worked_tiles(hex_grid) # populacao cresceu, arruma mais tiles trabalhados
	city.stored_food = 5.0
	city.stored_production = 2.0
	city.buildings["granary"] = true
	city.buildings["walls"] = true
	var expected_worked_tiles = city.worked_tiles.duplicate()

	human.researched_techs["agriculture"] = true
	human.current_research = "mining"
	human.research_progress = 12.0

	var peace_accepted = Diplomacy.propose_peace(human, rival) # 1 unidade de cada lado, empate aceita a paz (ver Diplomacy._accepts_peace)
	assert_true(peace_accepted, "pre-condicao do teste: paz devia ser aceita com exercitos empatados")

	TurnManager.turn_number = 9
	TurnManager.current_player_index = 0

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH), "save_game deveria ter sucesso")

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)

	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok, "load_game deveria ter sucesso com um save valido")
	assert_eq(loaded_grid.map_seed, hex_grid.map_seed, "a mesma semente deveria recriar o mesmo terreno")
	assert_eq(loaded_grid.get_tile(unit_coord).terrain_type, hex_grid.get_tile(unit_coord).terrain_type)
	assert_eq(TurnManager.turn_number, 9)

	assert_eq(GameManager.human_player.civ.civ_name, "Reino de Teste")
	assert_almost_eq(GameManager.human_player.gold, 42.0, 0.01)
	assert_eq(GameManager.human_player.units.size(), 1)
	assert_almost_eq(GameManager.human_player.units[0].hp, 7.0, 0.01)
	assert_almost_eq(GameManager.human_player.units[0].movement_left, 1.0, 0.01)
	assert_eq(GameManager.human_player.units[0].coord, unit_coord)

	assert_eq(GameManager.human_player.cities.size(), 1)
	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.city_name, "Minha Capital")
	assert_eq(loaded_city.population, 3)
	assert_almost_eq(loaded_city.stored_food, 5.0, 0.01)
	assert_almost_eq(loaded_city.stored_production, 2.0, 0.01)
	assert_eq(loaded_city.production_item, "archer")
	assert_eq(loaded_city.worked_tiles.size(), expected_worked_tiles.size(), "tiles trabalhados deveriam sobreviver ao save/load")
	for w in expected_worked_tiles:
		assert_true(w in loaded_city.worked_tiles, "tile trabalhado %s deveria estar presente depois de carregar" % w)
	assert_true(loaded_city.buildings.has("granary"), "predios construidos deveriam sobreviver ao save/load")
	assert_true(loaded_city.buildings.has("walls"))

	assert_true(GameManager.human_player.researched_techs.has("agriculture"), "tecnologia pesquisada deveria sobreviver ao save/load")
	assert_eq(GameManager.human_player.current_research, "mining")
	assert_almost_eq(GameManager.human_player.research_progress, 12.0, 0.01)

	assert_eq(GameManager.rival_players.size(), 1)
	assert_false(
		GameManager.human_player.is_at_war_with(GameManager.rival_players[0]),
		"paz negociada antes de salvar deveria sobreviver ao save/load"
	)

## Regressao: GameManager.map_radius so era setado na tela de titulo/novo
## jogo, nunca no load — RTSCamera.reset_view() usa esse valor (nao o
## hex_grid.map_radius de verdade) pro limite de pan. Carregar um save de
## raio diferente do jogo atual deixava a camera com o limite errado.
func test_load_updates_game_manager_map_radius_to_match_loaded_map():
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH)) # hex_grid tem raio 3 (before_each)
	GameManager.map_radius = 99 # simula um raio "preso" de uma partida anterior diferente

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_eq(GameManager.map_radius, 3, "map_radius deveria bater com o raio de verdade do mapa carregado")

## Regressao: dificuldade escolhida na tela de titulo (GameManager.difficulty)
## precisa sobreviver ao save/load — senao carregar uma partida "Dificil"
## voltaria os rivais pro multiplicador padrao (ver SaveManager.load_game,
## que seta difficulty ANTES de setup_players() pra valer no re-spawn).
func test_save_and_load_restores_difficulty():
	GameManager.difficulty = "hard"

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	GameManager.difficulty = "normal" # simula um novo jogo "Normal" iniciado antes de carregar
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_eq(GameManager.difficulty, "hard")
	for r in GameManager.rival_players:
		assert_almost_eq(r.yield_multiplier, GameManager.DIFFICULTY_MULTIPLIERS.hard, 0.01)

## Regressao: predio POSICIONADO no mapa (building_coords, ver
## SelectionManager.start_building_placement) precisa sobreviver ao save/
## load com o modelo 3D recriado no MESMO tile — sem isso o predio ficaria
## invisivel apos carregar, mesmo continuando a contar pro bonus/limite.
func test_save_and_load_restores_positioned_building():
	var city_coord: Vector2i = hex_grid.tiles.keys()[0]
	var city = hex_grid.found_city(city_coord, human, "Capital com Predio")
	var building_coord: Vector2i = hex_grid.get_neighbors(city_coord)[0]
	city.buildings["granary"] = true
	city.building_coords["granary"] = building_coord

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.building_coords.get("granary"), building_coord)
	var placed = loaded_grid.get_building_at(building_coord)
	assert_not_null(placed, "predio deveria ter um modelo 3D recriado no mesmo tile apos carregar")
	assert_eq(placed.building_id, "granary")

## Regressao: um Covil de Monstro ja derrotado antes de salvar nao deveria
## "ressuscitar" ao carregar — generate_map() no load recria TODOS os
## guardioes originais (mesma semente), entao SaveManager precisa desfazer
## isso pros coords que o save marca como ja limpos (ver
## HexGrid.lair_coords / _serialize_cleared_lairs).
func test_save_and_load_does_not_respawn_a_cleared_monster_lair():
	if hex_grid.lair_coords.is_empty():
		pending("mapa de teste (radius 3) nao gerou nenhum covil nesta semente")
		return
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var guardian = hex_grid.get_unit_at(lair_coord)
	assert_not_null(guardian, "pre-condicao: covil deveria comecar guardado")
	hex_grid.remove_unit(guardian)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_null(loaded_grid.get_unit_at(lair_coord), "covil ja limpo antes de salvar nao deveria respawnar guardiao ao carregar")

func test_load_without_a_save_file_returns_false():
	SaveManager.delete_save(TEST_SAVE_PATH)
	var empty_grid := HexGrid.new()
	empty_grid._ready()
	_created_hex_grids.append(empty_grid)

	assert_false(SaveManager.load_game(empty_grid, TEST_SAVE_PATH))

func test_has_save_reflects_file_presence():
	SaveManager.delete_save(TEST_SAVE_PATH)
	assert_false(SaveManager.has_save(TEST_SAVE_PATH))

	SaveManager.save_game(hex_grid, TEST_SAVE_PATH)
	assert_true(SaveManager.has_save(TEST_SAVE_PATH))

	SaveManager.delete_save(TEST_SAVE_PATH)
	assert_false(SaveManager.has_save(TEST_SAVE_PATH))
