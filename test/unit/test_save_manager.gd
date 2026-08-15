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
var _original_map_width: int
var _original_map_height: int
var _original_difficulty: String

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_kingdom_name = GameManager.human_kingdom_name
	_original_state = GameManager.state
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	_original_difficulty = GameManager.difficulty
	_created_units = []
	_created_hex_grids = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(7, 7, 12345) # mapa pequeno com semente fixa (determinismo)
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
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height
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
	human.mana = 18.0
	human.mana_income_per_turn = 5.0
	human.spell_cooldowns["Lança de Arcana"] = 12
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

	human.researched_techs["canalizacao_base"] = true
	human.current_research = "transmutacao_rocha"
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
	assert_almost_eq(GameManager.human_player.mana, 18.0, 0.01, "saldo de mana deveria sobreviver ao save/load")
	assert_almost_eq(GameManager.human_player.mana_income_per_turn, 5.0, 0.01)
	assert_eq(GameManager.human_player.spell_cooldowns.get("Lança de Arcana", 0), 12, "recarga de feitico deveria sobreviver ao save/load")
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

	assert_true(GameManager.human_player.researched_techs.has("canalizacao_base"), "tecnologia pesquisada deveria sobreviver ao save/load")
	assert_eq(GameManager.human_player.current_research, "transmutacao_rocha")
	assert_almost_eq(GameManager.human_player.research_progress, 12.0, 0.01)

	assert_eq(GameManager.rival_players.size(), 1)
	assert_false(
		GameManager.human_player.is_at_war_with(GameManager.rival_players[0]),
		"paz negociada antes de salvar deveria sobreviver ao save/load"
	)

## Regressao: GameManager.map_width/map_height so eram setados na tela de
## titulo/novo jogo, nunca no load — RTSCamera.reset_view() usa esses
## valores (nao o hex_grid.map_width/map_height de verdade) pro limite de
## pan. Carregar um save de mapa diferente do jogo atual deixava a camera
## com o limite errado.
func test_load_updates_game_manager_map_size_to_match_loaded_map():
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH)) # hex_grid tem 7x7 (before_each)
	GameManager.map_width = 99 # simula dimensoes "presas" de uma partida anterior diferente
	GameManager.map_height = 99

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_eq(GameManager.map_width, 7, "map_width deveria bater com a largura de verdade do mapa carregado")
	assert_eq(GameManager.map_height, 7, "map_height deveria bater com a altura de verdade do mapa carregado")

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

## Territorio dinamico (City.owned_tiles, ver HexGrid.city_territory_tiles)
## precisa sobreviver ao save/load igual worked_tiles — sem isso, uma
## cidade que ja cresceu alem do hexagono inicial "encolheria" de volta
## pro territorio padrao (celula+6 vizinhos) toda vez que a partida fosse
## carregada.
func test_save_and_load_restores_grown_city_territory():
	var city_coord: Vector2i = hex_grid.tiles.keys()[0]
	var city = hex_grid.found_city(city_coord, human, "Capital")
	# Simula territorio JA crescido alem do hexagono inicial (pedido do
	# usuario: expansao dinamica) — nao precisa rodar process_turn de
	# verdade, so provar que o campo extra sobrevive ao ciclo save/load.
	var fake_grown_tile := Vector2i(50, 50)
	city.owned_tiles.append(fake_grown_tile)
	var expected_owned_tiles = city.owned_tiles.duplicate()

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.owned_tiles.size(), expected_owned_tiles.size(), "territorio deveria sobreviver ao save/load com o mesmo numero de tiles")
	for t in expected_owned_tiles:
		assert_true(t in loaded_city.owned_tiles, "tile de territorio %s deveria estar presente apos carregar" % t)

## Regressao: um Covil de Monstro ja derrotado antes de salvar nao deveria
## "ressuscitar" ao carregar — generate_map() no load recria TODOS os
## guardioes originais (mesma semente), entao SaveManager precisa descartar
## esse povoamento automatico e restaurar o mapa de monstros EXATO que
## existia no save (ver HexGrid.clear_neutral_units/neutral_units,
## SaveManager._serialize_neutral_units/_deserialize_neutral_units).
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

## Regressao (feature nova): um covil DESTRUIDO de verdade (HexGrid.
## destroy_lair — jogador entrou no tile vazio e recebeu a recompensa de
## limpeza, ver HexGrid.move_unit/_grant_lair_clear_reward) precisa
## continuar destruido apos salvar/carregar: generate_map() no load recria
## TODOS os covis da semente do zero, entao SaveManager precisa reconciliar
## por cima (ver cleared_lair_coords/_serialize_cleared_lairs), mesmo
## padrao ja usado pros monstros neutros no teste acima. Tambem confere que
## a recompensa de ouro nao e concedida DE NOVO so por carregar.
func test_save_and_load_preserves_a_destroyed_lair():
	if hex_grid.lair_coords.is_empty():
		pending("mapa de teste (radius 3) nao gerou nenhum covil nesta semente")
		return
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var guardian = hex_grid.get_unit_at(lair_coord)
	hex_grid.remove_unit(guardian)
	var soldier = _make_unit("warrior", human, lair_coord)
	hex_grid.move_unit(soldier, lair_coord, 1.0) # tile vazio: concede recompensa e chama destroy_lair()
	assert_false(lair_coord in hex_grid.lair_coords, "pre-condicao: covil deveria estar destruido antes de salvar")
	var gold_after_clear = human.gold
	hex_grid.remove_unit(soldier) # vaga o tile — so serviu pra disparar a limpeza, o teste e sobre o COVIL, nao sobre onde o soldado ficou

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_false(lair_coord in loaded_grid.lair_coords, "covil destruido antes de salvar nao deveria voltar a existir apos carregar")
	assert_false(loaded_grid.lairs_by_coord.has(lair_coord), "estrutura visual nao deveria reaparecer apos carregar")
	assert_null(loaded_grid.get_unit_at(lair_coord), "nenhum guardiao deveria respawnar num covil ja destruido")
	assert_almost_eq(GameManager.human_player.gold, gold_after_clear, 0.01, "ouro da recompensa de limpeza nao deveria ser concedido de novo ao carregar")

## Regressao critica (pedido do usuario: reforcos de covil NAO deveriam
## desaparecer ao salvar/carregar): gera um reforco de verdade (monstro
## extra alem do guardiao original, com hp/kills customizados pra provar
## que o estado INTEIRO sobrevive, nao so a posicao) e confere que ele
## continua no mapa, na mesma posicao, com o mesmo hp/kills, depois de uma
## volta completa por save/load.
func test_save_and_load_preserves_a_reinforcement_monster_with_its_exact_state():
	if hex_grid.lair_coords.is_empty():
		pending("mapa de teste nao gerou nenhum covil nesta semente")
		return
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var kind = hex_grid.lair_kind_by_coord[lair_coord]
	var free_neighbor = hex_grid._find_free_tile_for_lair_spawn(lair_coord)
	assert_not_null(free_neighbor, "precondicao: covil deveria ter espaco livre pra um reforco")

	var reinforcement = hex_grid.spawn_monster_at(free_neighbor, kind)
	reinforcement.hp = 3.5
	reinforcement.kills = 2
	reinforcement.veterancy_level = 1
	reinforcement.monster_behavior_state = "invader" # promovido pela MonsterAI antes de salvar
	reinforcement.movement_left = 1.5
	var neutral_count_before = hex_grid.neutral_units().size()

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_eq(loaded_grid.neutral_units().size(), neutral_count_before, "numero de monstros neutros deveria sobreviver ao save/load")
	var restored = loaded_grid.get_unit_at(free_neighbor)
	assert_not_null(restored, "reforco deveria continuar no mesmo tile apos carregar")
	assert_eq(restored.unit_data.visual_kind, kind)
	assert_almost_eq(restored.hp, 3.5, 0.01)
	assert_eq(restored.kills, 2)
	assert_eq(restored.veterancy_level, 1)
	assert_null(restored.owner_player, "monstro restaurado deveria continuar neutro")
	assert_false(restored.is_camp_boss, "reforco nao e o boss original do covil")
	assert_eq(restored.monster_behavior_state, "invader", "promocao a Invasor (MonsterAI) deveria sobreviver ao save/load")
	assert_almost_eq(restored.movement_left, 1.5, 0.01)

	# O guardiao ORIGINAL do covil (nao o reforco criado acima) e sempre um
	# camp boss — confere que isso tambem sobrevive ao save/load.
	var restored_guardian = loaded_grid.get_unit_at(lair_coord)
	assert_not_null(restored_guardian)
	assert_true(restored_guardian.is_camp_boss, "guardiao original do covil deveria continuar marcado como camp boss apos carregar")

## Regressao critica (determinismo/replay): o `.state` do RNG dedicado de
## covil (HexGrid.monster_turn_rng) precisa sobreviver ao save/load — sem
## isso, recarregar reiniciaria a sequencia de sorteios de reforco/patrulha
## do zero (turno 0), divergindo do que teria acontecido sem o save/load no
## meio do caminho.
func test_save_and_load_preserves_monster_turn_rng_state():
	for i in range(5):
		hex_grid.process_monster_lairs(i)
	var state_before_save = hex_grid.monster_turn_rng.state

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_eq(loaded_grid.monster_turn_rng.state, state_before_save, "RNG de covil deveria continuar exatamente de onde parou apos carregar")

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
