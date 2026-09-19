extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## COVIS DE MONSTROS -- SOBREPOSICAO: o chefao original agora nasce ao
## REDOR do covil (num vizinho), nao mais sempre exatamente em lair_coord
## (ver HexGrid._find_free_tile_for_lair_spawn) -- helper pra achar o
## chefao pela FLAG (is_camp_boss) dentro da area do covil inteira, nao
## mais assumindo a coordenada exata.
func _find_camp_boss(grid: HexGrid, lair_coord: Vector2i) -> Unit:
	for coord in grid._lair_area(lair_coord):
		var unit: Unit = grid.get_unit_at(coord)
		if unit != null and unit.is_camp_boss:
			return unit
	return null

## Cobre o ciclo salvar/carregar: o estado logico (ouro, unidades com
## hp/movimento, cidades com producao/populacao, semente do mapa, turno)
## precisa sobreviver a uma volta completa por JSON em disco. Usa um
## arquivo de teste isolado (TEST_SAVE_PATH) pra nunca tocar no save real
## do jogador.

const TEST_SAVE_PATH := "user://test_savegame.json"
## Roadmap "sistema de menu de jogo moderno" -- diretorio ISOLADO pros testes
## da camada de slots (list_slots/save_to_slot/load_from_slot/delete_slot,
## ver final deste arquivo), nunca o SaveManager.SAVE_DIR de verdade.
const TEST_SAVE_DIR := "user://test_saves/"

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
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int
var _original_players: Array[PlayerData]
var _original_rules: int

func before_each():
	_original_players = GameManager.players
	_original_rules = GameManager.victory_rules_version
	GameManager.players = []
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
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	_created_units = []
	_created_hex_grids = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(7, 7, 12345) # mapa pequeno com semente fixa (determinismo)
	_created_hex_grids.append(hex_grid)

	human = _track_player(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	rival = _track_player(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	GameManager.human_player = human
	GameManager.rival_players = [rival]

func after_each():
	for player in GameManager.players:
		player.release_relations()
	GameManager.players = _original_players
	GameManager.victory_rules_version = _original_rules
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
	SaveManager.delete_save(TEST_SAVE_PATH)
	_clear_test_save_dir()
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
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id

func _clear_test_save_dir() -> void:
	var da := DirAccess.open(TEST_SAVE_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			da.remove(fname)
		fname = da.get_next()
	da.list_dir_end()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_current_save_keeps_mounted_scout_research_and_war():
	human.researched_techs["batedor_montado"] = true
	human.current_research = "batedor_montado"
	human.war_weariness = 23.0
	var coords := hex_grid.tiles.keys()
	var unit := _make_unit("warrior", human, coords[0])
	unit.fortified = true
	unit.move_order_target = coords[2]
	_make_unit("warrior", rival, coords[1])
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	var loaded := GameManager.human_player
	assert_true(loaded.researched_techs.has("batedor_montado"))
	assert_eq(loaded.current_research, "batedor_montado")
	assert_true(loaded.is_at_war_with(GameManager.rival_players[0]))
	assert_true(GameManager.rival_players[0].is_at_war_with(loaded))
	assert_eq(loaded.war_weariness, 23.0)
	assert_true(loaded.units[0].fortified)
	assert_eq(loaded.units[0].move_order_target, coords[2])

func test_save_restores_transformed_land_pillage_and_trade_income():
	var coords := hex_grid.tiles.keys()
	var a := hex_grid.found_city(coords[0], human, "A")
	var b := hex_grid.found_city(coords[1], rival, "B")
	Diplomacy.propose_peace(human, rival)
	a.buildings["market"] = true
	b.buildings["market"] = true
	var route := TradeRoute.new(a, b)
	human.trade_routes.append(route)
	rival.trade_routes.append(route)
	a._consecutive_siege_turns = 3
	hex_grid.transform_tile_terrain(coords[2], HexTileData.TerrainType.GRASSLAND)
	hex_grid._pillaged_tiles[coords[3]] = TurnManager.turn_number + 5
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	assert_eq(hex_grid.get_tile(coords[2]).terrain_type, HexTileData.TerrainType.GRASSLAND)
	assert_true(hex_grid.is_tile_pillaged(coords[3], TurnManager.turn_number))
	var loaded := GameManager.human_player
	assert_eq(loaded.cities[0]._consecutive_siege_turns, 3)
	assert_eq(loaded.trade_routes.size(), 1)
	assert_same(loaded.trade_routes[0], GameManager.rival_players[0].trade_routes[0])
	var gold := loaded.gold
	TradeManager.process_all_routes(GameManager.players)
	assert_eq(loaded.gold, gold + TradeManager.ROUTE_INCOME_GOLD)

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
	city.hp = 17.5
	city.shield = 6.0
	var expected_worked_tiles = city.worked_tiles.duplicate()

	human.researched_techs["quartel"] = true
	human.researched_magic["canalizacao_base"] = true
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
	assert_almost_eq(loaded_city.hp, 17.5, 0.01, "vida da cidade deveria sobreviver ao save/load")
	assert_almost_eq(loaded_city.shield, 6.0, 0.01, "escudo da cidade deveria sobreviver ao save/load")

	assert_true(GameManager.human_player.researched_techs.has("quartel"), "tecnologia mundana pesquisada deveria sobreviver ao save/load")
	assert_true(GameManager.human_player.researched_magic.has("canalizacao_base"), "tecnologia magica pesquisada deveria sobreviver ao save/load, separada de researched_techs")
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

## Roadmap "Parte B" B4 — nao e um teste de "round-trip" no sentido usual:
## personalidade NUNCA e serializada (ver CivilizationPersonality.gd,
## comentario de topo). O que isto prova e RECONSTRUCAO DETERMINISTICA apos
## load: save -> load restaura map_seed -> setup_players() deriva de novo
## -> resultado bate com o estado anterior ao save. Usa GameManager.
## setup_players() de verdade (nao o atalho de _track_player() direto que
## before_each usa pros outros testes deste arquivo) porque personalidade
## so existe depois desse fluxo real.
func test_save_and_load_reconstructs_the_identical_personality():
	GameManager.rival_count = 2
	GameManager.setup_players(hex_grid) # sobrescreve human/rival do before_each com o fluxo real
	var coords := hex_grid.tiles.keys()
	_make_unit("warrior", GameManager.human_player, coords[0])
	for i in range(GameManager.rival_players.size()):
		_make_unit("warrior", GameManager.rival_players[i], coords[i + 1])

	var human_personality_before: Dictionary = GameManager.human_player.personality.duplicate()
	var rival_personalities_before := []
	for rival in GameManager.rival_players:
		rival_personalities_before.append(rival.personality.duplicate())

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	assert_eq(GameManager.human_player.personality, human_personality_before, "personalidade do humano deveria ser reconstruida identica apos o load")
	for i in range(GameManager.rival_players.size()):
		assert_eq(GameManager.rival_players[i].personality, rival_personalities_before[i], "personalidade do rival %d deveria ser reconstruida identica apos o load" % i)

## Confirma que a propriedade "zero codigo de serializacao" e real, nao uma
## coincidencia de valores: o JSON salvo nao tem NENHUMA chave
## "personality" em lugar nenhum.
func test_save_file_never_contains_a_personality_key():
	GameManager.rival_count = 2
	GameManager.setup_players(hex_grid)
	var coords := hex_grid.tiles.keys()
	_make_unit("warrior", GameManager.human_player, coords[0])
	for i in range(GameManager.rival_players.size()):
		_make_unit("warrior", GameManager.rival_players[i], coords[i + 1])

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	assert_false(text.contains("personality"), "o arquivo de save nao deveria conter a chave 'personality' em lugar nenhum")

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
	var guardian = _find_camp_boss(hex_grid, lair_coord)
	assert_not_null(guardian, "pre-condicao: covil deveria comecar guardado")
	hex_grid.remove_unit(guardian)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_null(_find_camp_boss(loaded_grid, lair_coord), "covil ja limpo antes de salvar nao deveria respawnar guardiao ao carregar")

## Regressao (feature nova): um covil DESTRUIDO de verdade (HexGrid.
## destroy_lair — jogador entrou no tile vazio e recebeu a recompensa de
## limpeza, ver HexGrid.move_unit/_grant_lair_clear_reward) precisa
## continuar destruido apos salvar/carregar: generate_map() no load recria
## TODOS os covis da semente do zero, entao SaveManager precisa reconciliar
## por cima (ver cleared_lair_coords/_serialize_cleared_lairs), mesmo
## padrao ja usado pros monstros neutros no teste acima. Tambem confere que
## a recompensa de ouro nao e concedida DE NOVO so por carregar.
## AGGRO / TERRITORIO DE AMEACA: covil ALERTADO (ver HexGrid.alert_lair_near)
## e' um efeito temporario com expiracao por turno absoluto -- precisa
## sobreviver a salvar/carregar (mesmo padrao de pillaged_tiles/
## lair_structure_hp). Usa um mapa maior (29x29, seed 555, ja usado em
## test_monsters.gd) porque o mapa 7x7 padrao deste arquivo pode nao gerar
## covil nenhum -- e o `pending` dos testes vizinhos escondia isso.
func test_save_and_load_preserves_an_active_lair_alert():
	var big_grid := HexGrid.new()
	big_grid._ready()
	big_grid.generate_map(29, 29, 555)
	_created_hex_grids.append(big_grid)
	assert_gt(big_grid.lair_coords.size(), 0, "precondicao: mapa 29x29 seed 555 deveria ter pelo menos um covil")
	var lair_coord: Vector2i = big_grid.lair_coords[0]
	big_grid.alert_lair_near(lair_coord, 5)

	assert_true(SaveManager.save_game(big_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(lair_coord in loaded_grid.lair_coords, "precondicao: mesma semente deveria recriar o mesmo covil")
	assert_true(loaded_grid.is_lair_alerted(lair_coord, 6), "alerta ativo antes de salvar deveria continuar ativo apos carregar")
	assert_false(loaded_grid.is_lair_alerted(lair_coord, 5 + HexGrid.LAIR_ALERT_DURATION_TURNS), "alerta deveria expirar no mesmo turno absoluto de antes")

func test_save_and_load_preserves_a_destroyed_lair():
	if hex_grid.lair_coords.is_empty():
		pending("mapa de teste (radius 3) nao gerou nenhum covil nesta semente")
		return
	var lair_coord: Vector2i = hex_grid.lair_coords[0]
	var guardian = _find_camp_boss(hex_grid, lair_coord)
	hex_grid.remove_unit(guardian)
	# COVIS DE MONSTROS -- DESTRUICAO: destruir agora exige atacar a
	# ESTRUTURA de verdade ate zerar o HP dela (ver CombatResolver.
	# resolve_lair_attack), nao mais so' "visitar" o tile vazio (antigo
	# HexGrid._grant_lair_clear_reward acionado por move_unit, removido).
	var soldier = _make_unit("warrior", human, lair_coord)
	var hits := 0
	while lair_coord in hex_grid.lair_coords and hits < 10:
		soldier.movement_left = soldier.unit_data.movement_points
		CombatResolver.resolve_lair_attack(soldier, lair_coord, hex_grid)
		hits += 1
	assert_false(lair_coord in hex_grid.lair_coords, "pre-condicao: covil deveria estar destruido antes de salvar")
	var gold_after_clear = human.gold
	hex_grid.remove_unit(soldier) # so' serviu pra disparar a destruicao, o teste e sobre o COVIL, nao sobre onde o soldado ficou

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_false(lair_coord in loaded_grid.lair_coords, "covil destruido antes de salvar nao deveria voltar a existir apos carregar")
	assert_false(loaded_grid.lairs_by_coord.has(lair_coord), "estrutura visual nao deveria reaparecer apos carregar")
	assert_null(_find_camp_boss(loaded_grid, lair_coord), "nenhum guardiao deveria respawnar num covil ja destruido")
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
	var restored_guardian = _find_camp_boss(loaded_grid, lair_coord)
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

## Roadmap 2.0 Parte 1 (C6) — EXCECAO deliberada: diferente de fortified/
## exploring/move_order_target (que nao sobrevivem de proposito), perder
## `embarked` deixaria uma unidade presa em pleno oceano tratada como
## terrestre apos carregar. Unidade salva EMBARCADA sobre Oceano deveria
## voltar embarcada apos carregar.
func test_save_and_load_preserves_embarked_state_on_a_unit_at_sea():
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var warrior = _make_unit("warrior", human, coord)
	warrior.embarked = true
	_make_unit("warrior", rival, Vector2i(1, 0)) # so pra check_game_over() nao fechar o jogo no load

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	assert_eq(GameManager.human_player.units.size(), 1)
	assert_true(GameManager.human_player.units[0].embarked, "unidade embarcada sobre agua deveria continuar embarcada apos carregar")

## Roadmap "Parte C" C3 — diferente de B4 (personalidade, derivada do
## map_seed, ZERO codigo de serializacao novo), campanha de guerra e estado
## novo de verdade -- a asserção de round-trip importa aqui.
func test_save_and_load_restores_war_campaign():
	var coords = hex_grid.tiles.keys()
	var target_coord: Vector2i = coords[3]
	_make_unit("warrior", rival, coords[2]) # so pra check_game_over() nao fechar o jogo no load
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES,
		"target_coord": target_coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	assert_true(loaded_rival.war_campaigns.has(GameManager.human_player), "a chave deveria ter sido religada ao PlayerData humano VIVO pos-load, nao a um objeto obsoleto")
	var campaign: Dictionary = loaded_rival.war_campaigns[GameManager.human_player]
	assert_eq(campaign.objective, RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES)
	assert_eq(campaign.target_coord, target_coord)
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ACTIVE)

## Roadmap "Parte E" E1 -- confirma que o status ABANDONED produzido pelo
## encerramento automatico de campanha (Diplomacy.propose_peace ->
## RivalAI.end_campaigns_on_peace) sobrevive ao mesmo round-trip ja provado
## pra ACTIVE acima (test_save_and_load_restores_war_campaign). Nenhum
## codigo de serializacao novo -- status e so mais uma String -- mas vale
## a asserção depois de mudar QUEM escreve nesse campo.
func test_save_and_load_restores_campaign_abandoned_by_peace():
	var coords = hex_grid.tiles.keys()
	var target_coord: Vector2i = coords[3]
	_make_unit("warrior", rival, coords[2]) # rival com 1 unidade, humano com 0 -- humano aceita a paz (e so pra check_game_over() nao fechar o jogo no load)
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES,
		"target_coord": target_coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	assert_true(Diplomacy.propose_peace(rival, human), "pre-condicao: paz deveria ter sido aceita (humano em desvantagem numerica)")
	assert_eq(rival.war_campaigns[human].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "pre-condicao")

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var campaign: Dictionary = loaded_rival.war_campaigns[GameManager.human_player]
	assert_eq(campaign.status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

## Roadmap "Fase F" F1/F2/F4 — territorial_streak/arcane_ritual_* sao
## HISTORICO acumulado de verdade (turnos de sustentacao ja conquistados);
## perder isso ao salvar/carregar "roubaria" progresso legitimo. Mesma
## disciplina de round-trip de test_save_and_load_restores_war_campaign
## acima. Da unidade a AMBOS human e rival (nao so rival, diferente do
## padrao de war_campaign) -- com os dois em 0 unidades/cidades,
## check_victories() no fim do load() declararia Dominancia pra qualquer
## um dos dois so pela fixture, mascarando o que este teste quer provar.
func test_save_and_load_restores_territorial_streak():
	_make_unit("warrior", human, hex_grid.tiles.keys()[0])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[1])
	rival.territorial_streak = 3

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	assert_eq(GameManager.rival_players[0].territorial_streak, 3)

func test_save_and_load_restores_active_arcane_ritual_mid_sustain():
	var ritual_coord: Vector2i = hex_grid.tiles.keys()[3]
	_make_unit("warrior", human, hex_grid.tiles.keys()[0])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[1])
	rival.arcane_ritual_active = true
	rival.arcane_ritual_city_coord = ritual_coord
	rival.arcane_ritual_streak = 3
	rival.mana = 42.0

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	assert_true(loaded_rival.arcane_ritual_active)
	assert_eq(loaded_rival.arcane_ritual_city_coord, ritual_coord)
	assert_eq(loaded_rival.arcane_ritual_streak, 3)
	assert_almost_eq(loaded_rival.mana, 42.0, 0.001)

## O teste mais importante desta fatia (pedido explicito do usuario):
## carregar no MEIO de um ritual ativo nao pode ganhar nem perder um
## turno artificialmente. SaveManager.load_game() so chama
## check_victories() (deteccao PURA) -- NUNCA _update_victory_state()
## (quem incrementaria o streak) -- entao o streak precisa sair do load
## EXATAMENTE como foi salvo, nem +1 nem resetado, e sem declarar vitoria
## so por estar a 1 turno do limiar.
func test_save_and_load_mid_ritual_does_not_advance_or_reset_the_streak():
	var ritual_coord: Vector2i = hex_grid.tiles.keys()[3]
	_make_unit("warrior", human, hex_grid.tiles.keys()[0])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[1])
	rival.arcane_ritual_active = true
	rival.arcane_ritual_city_coord = ritual_coord
	rival.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS - 1 # 1 turno do limiar
	rival.mana = 1000.0

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	assert_eq(loaded_rival.arcane_ritual_streak, VictoryConditions.ARCANE_SUSTAIN_TURNS - 1, "carregar nao pode avancar o streak sozinho")
	assert_true(loaded_rival.arcane_ritual_active, "carregar 1 turno abaixo do limiar nao pode interromper o ritual sozinho")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "1 turno abaixo do limiar -- carregar nao deveria declarar vitoria sozinho")

func test_save_and_load_with_no_ritual_defaults_to_inactive():
	_make_unit("warrior", human, hex_grid.tiles.keys()[0])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[1])
	# nenhum campo de vitoria setado -- equivalente a um save de ANTES da v16 existir

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	assert_false(loaded_rival.arcane_ritual_active)
	assert_eq(loaded_rival.arcane_ritual_streak, 0)
	assert_eq(loaded_rival.territorial_streak, 0)
	assert_eq(loaded_rival.arcane_ritual_city_coord, PlayerData.NO_RITUAL_CITY_COORD)

func test_save_and_load_with_no_campaign_omits_war_campaign_key():
	_make_unit("warrior", rival, hex_grid.tiles.keys()[0]) # so pra check_game_over() nao fechar o jogo no load

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok)
	assert_true(GameManager.rival_players[0].war_campaigns.is_empty(), "rival sem campanha nenhuma deveria voltar do load sem nenhuma entrada")

## Roadmap "Parte C" C4 — fecha o circuito que C3 preparou: nao basta o
## target_coord sobreviver ao save/load (ja provado por test_save_and_load_
## restores_war_campaign), a EXECUCAO tatica (RivalAI.take_turn ->
## _handle_attacker -> _campaign_attack_target) precisa realmente obedecer
## o valor restaurado, lido do PlayerData humano VIVO pos-load.
func test_save_and_load_war_campaign_directs_unit_behavior_after_load():
	var target_coord: Vector2i = hex_grid.tiles.keys()[3]
	var attacker_coord: Vector2i = hex_grid.get_neighbors(target_coord)[0]
	hex_grid.found_city(target_coord, human, "Alvo")
	rival.known_enemy_cities[target_coord] = true
	rival.war_campaigns[human] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": target_coord,
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	_make_unit("warrior", rival, attacker_coord)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)
	assert_true(ok)

	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var loaded_target_city := loaded_grid.get_city_at(target_coord)
	assert_not_null(loaded_target_city, "pre-condicao: cidade-alvo deveria existir no mapa carregado")
	var loaded_hp_before := loaded_target_city.hp

	RivalAI.take_turn(loaded_rival, loaded_grid, GameManager.human_player)

	assert_lt(loaded_target_city.hp, loaded_hp_before, "unidade deveria obedecer o target_coord da campanha restaurada, nao um alvo escolhido do zero")

## --- World Event System (v17, ver docs/WORLD_EVENT_CONTRACT.md) -----------
## Nenhum evento concreto existe ainda (DragonEvent vem no Step 5) --
## _construct_event() do WorldEventManager retorna null pra qualquer tipo,
## entao um evento registrado nunca sobrevive a reconstrucao ainda (mesmo
## comportamento ja coberto em test_world_event_manager.gd, aqui testado
## END-TO-END pelo SaveManager de verdade). O que PRECISA sobreviver desde
## ja e o que nao depende de reconstrucao de tipo nenhum: o contador
## _next_event_id (senao um evento novo criado apos um load colidiria com
## o id de um evento salvo antes do load).

## O teste mais importante deste bloco (destacado explicitamente): registrar
## eventos, salvar, carregar, e confirmar que um evento NOVO criado depois
## do load continua a numeracao de onde parou, nunca reaproveitando um id
## ja usado antes de salvar.
func test_save_and_load_restores_next_event_id_avoiding_collision_with_new_events():
	for i in range(5):
		WorldEventManager.register_event(WorldEvent.new())
	assert_eq(WorldEventManager._next_event_id, 5, "pre-condicao: 5 eventos registrados deveriam consumir os ids 0-4")

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	assert_eq(WorldEventManager._next_event_id, 5, "o contador deveria sobreviver ao save/load, mesmo os 5 eventos originais nao sobrevivendo (nenhum tipo concreto existe ainda)")

	var new_event := WorldEvent.new()
	WorldEventManager.register_event(new_event)
	assert_eq(new_event.event_id, 5, "um evento novo apos o load nao deveria colidir com nenhum dos 5 ids usados antes de salvar")

func test_save_game_writes_world_event_manager_state_to_disk():
	WorldEventManager.register_event(WorldEvent.new())
	WorldEventManager.register_event(WorldEvent.new())

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	assert_true(data.has("world_events"), "o save deveria ter uma chave world_events dedicada (v17)")
	assert_eq(int(data.world_events.next_event_id), 2)
	assert_eq(data.world_events.events.size(), 2, "os 2 eventos registrados deveriam aparecer no arquivo, mesmo que ainda nao sobrevivam a reconstrucao no load")

## Fallback pra um save sem a chave world_events (contrato, "Persistencia"
## -> "Fallback/teste de saves antigos") -- um dict de save montado a mao
## sem essa chave (ou, na pratica, qualquer coisa que chegue incompleta a
## from_save_dict) nunca deveria travar o load inteiro.
func test_save_and_load_defaults_safely_when_world_events_key_is_absent():
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	data.erase("world_events") # simula um save sem esta chave
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok, "ausencia da chave world_events nao deveria travar o load inteiro")
	assert_eq(WorldEventManager.active_events.size(), 0)
	assert_eq(WorldEventManager._next_event_id, 0)

## Nenhum tipo concreto existe ainda -- um evento de tipo desconhecido no
## save nao deveria impedir o load do RESTO do jogo (mapa/jogadores/
## cidades), so o proprio evento e que nao sobrevive.
func test_save_and_load_succeeds_even_with_an_unreconstructable_event_in_the_file():
	var event := WorldEvent.new()
	event.event_type = "some_future_event_type"
	WorldEventManager.register_event(event)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok, "um evento de tipo desconhecido no save nao deveria impedir o load do resto do jogo")
	assert_eq(WorldEventManager.active_events.size(), 0, "o proprio evento nao sobrevive ainda -- nenhum tipo concreto existe (DragonEvent vem no Step 5)")
	assert_eq(WorldEventManager._next_event_id, 1, "o contador continua correto mesmo com o evento em si descartado")

## --- DragonEvent (Step 5A) end-to-end -- sequencia completa pedida pelo
## usuario: criar -> colocar em fase intermediaria -> salvar -> carregar ->
## confirmar mesma fase E mesmo estado especifico -> confirmar que NENHUM
## avanco ocorreu durante o load -> so ENTAO avancar um turno de verdade ->
## confirmar que a evolucao so acontece a partir dai.
func test_save_and_load_restores_a_dragon_event_in_its_exact_phase_and_state():
	# So pra check_victories() nao fechar o jogo por Dominacao trivial (um
	# dos dois lados sem NENHUMA unidade/cidade "perderia" sozinho) antes
	# do _on_turn_changed() do fim do teste -- os DOIS lados precisam de
	# pelo menos uma unidade, nao so o rival.
	_make_unit("warrior", human, hex_grid.tiles.keys()[1])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[2])
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.origin_region = Vector2i(3, 4)
	WorldEventManager.register_event(event)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	assert_eq(WorldEventManager.active_events.size(), 1, "DragonEvent e reconstruivel -- deveria sobreviver ao load")
	var loaded_event: WorldEvent = WorldEventManager.active_events[0]
	assert_true(loaded_event is DragonEvent)
	assert_eq(loaded_event.phase, WorldEvent.PHASE_ACTIVE, "load nao deveria ter avancado o evento nenhuma fase")
	assert_eq((loaded_event as DragonEvent).origin_region, Vector2i(3, 4), "estado especifico deveria sobreviver identico")

	# So DEPOIS do load, um turno de verdade deveria avancar o evento --
	# prova que a evolucao so acontece via _finish_turn(), nunca via load.
	GameManager._on_turn_changed(TurnManager.turn_number, 0)

	assert_eq(loaded_event.phase, WorldEvent.PHASE_RESOLUTION, "um turno real DEPOIS do load deveria avancar exatamente uma fase")

## Roadmap "Fase Macro" 5B.3-A: a Unit fisica do Dragao nunca e' serializada
## diretamente -- sobrevive ao load pelo mesmo caminho generico de
## monstros neutros (HexGrid.neutral_units), e SaveManager.load_game()
## precisa RE-LINKAR event.dragon_unit a ela depois, usando spawn_coord.
func test_save_and_load_relinks_the_dragon_unit_to_the_reconstructed_event():
	_make_unit("warrior", human, hex_grid.tiles.keys()[1])
	_make_unit("warrior", rival, hex_grid.tiles.keys()[2])
	var spawn_coord: Vector2i = hex_grid.tiles.keys()[3]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.origin_region = spawn_coord
	event.spawn_coord = spawn_coord
	event.dragon_unit = hex_grid.spawn_monster_at(spawn_coord, "dragon")
	WorldEventManager.register_event(event)

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	var loaded_event: DragonEvent = WorldEventManager.active_events[0]
	assert_not_null(loaded_event.dragon_unit, "relink_unit deveria ter encontrado a Unit restaurada pelo save generico de monstros neutros")
	assert_eq(loaded_event.dragon_unit, loaded_grid.get_unit_at(spawn_coord))
	assert_eq(loaded_event.dragon_unit.unit_data.visual_kind, "dragon")

## Migracao de save v17 -> v18 (separacao estrutural das arvores de
## pesquisa, ver SaveManager.MIGRATABLE_SAVE_VERSION): antes da separacao,
## "researched_techs" guardava ids de TECNOLOGIA e de MAGIA misturados, e
## nao existia a chave "researched_magic" no save. Simula esse formato
## antigo direto no JSON em disco (mesmo padrao de test_save_and_load_
## defaults_safely_when_world_events_key_is_absent acima) e confirma que o
## load reclassifica cada id pra dentro da arvore certa, sem perder
## nenhuma pesquisa e sem invalidar o save so por causa da versao antiga.
func test_save_and_load_migrates_a_pre_split_v17_save_without_losing_research():
	human.researched_techs["quartel"] = true
	human.researched_techs["celeiro"] = true
	human.researched_techs["invocacao_espiritos"] = true # id magico, mas simulado como se ainda estivesse no formato antigo
	human.researched_techs["transmutacao_rocha"] = true # id magico

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	# Reescreve o arquivo pra parecer um save v17 de verdade: version 17,
	# ids das duas arvores misturados numa unica "researched_techs", SEM a
	# chave "researched_magic" (o sinal que _deserialize_player usa pra
	# saber que precisa migrar).
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	data["version"] = 17
	data["human"]["researched_techs"] = ["quartel", "celeiro", "invocacao_espiritos", "transmutacao_rocha"]
	data["human"].erase("researched_magic")
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok, "save v17 (versao anterior a separacao) deveria continuar carregando, nao ser invalidado")
	var loaded_human := GameManager.human_player
	assert_true(loaded_human.researched_techs.has("quartel"), "tech mundana deveria continuar em researched_techs")
	assert_true(loaded_human.researched_techs.has("celeiro"), "tech mundana deveria continuar em researched_techs")
	assert_true(loaded_human.researched_magic.has("invocacao_espiritos"), "id magico misturado no researched_techs antigo deveria migrar pra researched_magic")
	assert_true(loaded_human.researched_magic.has("transmutacao_rocha"), "id magico misturado no researched_techs antigo deveria migrar pra researched_magic")
	assert_false(loaded_human.researched_techs.has("invocacao_espiritos"), "id magico nao deveria sobrar em researched_techs depois da migracao")
	assert_false(loaded_human.researched_techs.has("transmutacao_rocha"), "id magico nao deveria sobrar em researched_techs depois da migracao")
	assert_eq(loaded_human.researched_techs.size() + loaded_human.researched_magic.size(), 7, "Preserva quatro pesquisas antigas e concede os três níveis equivalentes de Arcanismo.")
	assert_true(loaded_human.researched_magic.has("arcanismo_3"))

## Migracao de save v18 -> v19 (redesenho da arvore de Tecnologia em 10
## niveis, ver SaveManager.TECH_TIER_REDESIGN_REMAP): "arquearia" (id
## antigo que desbloqueava PREDIO e UNIDADE juntos) precisa virar os DOIS
## ids novos ("campo_de_tiro" + "arqueiro"), e "batedor_montado" antigo
## (que desbloqueava o kind "scout") precisa virar "batedor" — NAO o novo
## id "batedor_montado" (que agora e uma unidade diferente). Ids que so
## preservam o proprio nome (quartel/celeiro/estabulo/muralhas/mercado/
## oficina/navegacao) tambem entram, pra confirmar que a migracao nao
## mexe neles por engano.
func test_save_and_load_migrates_a_pre_tier_redesign_v18_save_without_losing_research():
	human.researched_techs["quartel"] = true
	human.researched_techs["celeiro"] = true
	human.researched_techs["arquearia"] = true # id antigo: predio + unidade juntos
	human.researched_techs["batedor_montado"] = true # id antigo: desbloqueava "scout"

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	# Reescreve o arquivo pra parecer um save v18 de verdade: version 18,
	# ids antigos da arvore de Tecnologia (a chave "researched_magic" ja
	# existe nesse formato, so os ids de researched_techs sao antigos).
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	data["version"] = 18
	data["human"]["researched_techs"] = ["quartel", "celeiro", "arquearia", "batedor_montado"]
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	var ok = SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	assert_true(ok, "save v18 (versao anterior ao redesenho de 10 niveis) deveria continuar carregando, nao ser invalidado")
	var loaded_human := GameManager.human_player
	assert_true(loaded_human.researched_techs.has("quartel"), "id que preserva o proprio nome nao deveria mudar")
	assert_true(loaded_human.researched_techs.has("celeiro"), "id que preserva o proprio nome nao deveria mudar")
	assert_true(loaded_human.researched_techs.has("campo_de_tiro"), "arquearia antiga deveria migrar pro predio novo")
	assert_true(loaded_human.researched_techs.has("arqueiro"), "arquearia antiga deveria migrar TAMBEM pra unidade nova")
	assert_false(loaded_human.researched_techs.has("arquearia"), "id antigo nao deveria sobrar depois da migracao")
	assert_true(loaded_human.researched_techs.has("batedor"), "batedor_montado antigo (desbloqueava scout) deveria migrar pra 'batedor'")
	assert_false(loaded_human.researched_techs.has("batedor_montado"), "id novo 'batedor_montado' e uma unidade DIFERENTE, nao deveria receber credito automatico")
	assert_eq(loaded_human.researched_techs.size(), 5, "arquearia virou 2 ids, entao 4 ids antigos viram 5 novos, nada perdido")

func test_save_and_load_redirects_an_in_progress_research_on_a_removed_tech_id():
	human.current_research = "arquearia"
	human.research_progress = 12.0

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	data["version"] = 18
	data["human"]["current_research"] = "arquearia"
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	assert_eq(GameManager.human_player.current_research, "campo_de_tiro", "pesquisa em andamento num id que sumiu deveria redirecionar pro primeiro id novo do mapeamento")
	assert_almost_eq(GameManager.human_player.research_progress, 12.0, 0.01, "progresso acumulado nao deveria ser perdido na redirecao")

## Roadmap "sistema de menu de jogo moderno" -- pedido do usuario: "o
## salvar salva de fato o jogo, criando um slot daquela partida e salvando
## por cima ela sempre que e clicando salvar, ai voce pode ver seus jogos
## ao clicar em carregar jogo". Camada de slots por cima de save_game/
## load_game (testados a exaustao acima, intocados) -- estes testes cobrem
## so a camada NOVA: geracao de id, round-trip por slot, listagem de
## metadados sem reconstruir o jogo, e exclusao.

func test_new_slot_id_is_unique_even_when_called_twice_in_the_same_second():
	var id1 := SaveManager.new_slot_id(TEST_SAVE_DIR)
	# Simula a colisao real que new_slot_id() se defende de: o id sorteado
	# ja existe em disco (mesmo segundo) -- forca a segunda chamada a cair
	# no sufixo de desempate.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE_DIR))
	var f := FileAccess.open(TEST_SAVE_DIR.path_join(id1 + ".json"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()

	var id2 := SaveManager.new_slot_id(TEST_SAVE_DIR)

	assert_ne(id1, id2, "dois ids gerados apos uma colisao real nao deveriam ser iguais")

func test_save_to_slot_then_load_from_slot_round_trips():
	human.gold = 77.0
	human.civ.civ_name = "Reino do Slot"
	var slot_id := "test_slot_round_trip"

	assert_true(SaveManager.save_to_slot(hex_grid, slot_id, TEST_SAVE_DIR), "save_to_slot deveria ter sucesso")

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)

	assert_true(SaveManager.load_from_slot(loaded_grid, slot_id, TEST_SAVE_DIR), "load_from_slot deveria ter sucesso")
	assert_eq(GameManager.human_player.gold, 77.0)
	assert_eq(loaded_grid.map_seed, hex_grid.map_seed)

## Salvar de novo no MESMO slot sobrescreve -- e o comportamento pedido
## explicitamente ("salvando por cima ela sempre que e clicando salvar"),
## nao cria um segundo arquivo.
func test_save_to_slot_twice_overwrites_the_same_file_instead_of_creating_a_new_one():
	var slot_id := "test_slot_overwrite"
	human.gold = 10.0
	assert_true(SaveManager.save_to_slot(hex_grid, slot_id, TEST_SAVE_DIR))
	human.gold = 999.0
	assert_true(SaveManager.save_to_slot(hex_grid, slot_id, TEST_SAVE_DIR))

	assert_eq(SaveManager.list_slots(TEST_SAVE_DIR).size(), 1, "salvar duas vezes no mesmo slot nao deveria duplicar o arquivo")

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_from_slot(loaded_grid, slot_id, TEST_SAVE_DIR)
	assert_eq(GameManager.human_player.gold, 999.0, "o valor mais recente deveria ter sobrescrito o anterior")

func test_list_slots_reads_kingdom_race_turn_saved_at_without_full_load():
	human.civ.civ_name = "Reino Listado"
	human.civ.race = "elf" # save_game() le a raca de human_player.civ.race, nao de GameManager.human_race (so sincronizado ali por setup_players(), nao usado nesta rodada)
	GameManager.difficulty = "hard"
	TurnManager.turn_number = 5
	assert_true(SaveManager.save_to_slot(hex_grid, "test_slot_meta", TEST_SAVE_DIR))

	var slots := SaveManager.list_slots(TEST_SAVE_DIR)

	assert_eq(slots.size(), 1)
	assert_eq(slots[0].slot_id, "test_slot_meta")
	assert_eq(slots[0].kingdom_name, "Reino Listado")
	assert_eq(slots[0].race, "elf")
	assert_eq(slots[0].turn_number, 5)
	assert_eq(slots[0].difficulty, "hard")
	assert_gt(slots[0].saved_at, 0, "saved_at deveria ter sido gravado por save_to_slot")

func test_list_slots_sorts_newest_first():
	SaveManager.save_to_slot(hex_grid, "test_slot_old", TEST_SAVE_DIR)
	# forca um saved_at anterior no arquivo ja gravado, sem depender de
	# esperar 1 segundo real de diferenca entre as duas chamadas.
	var old_path := TEST_SAVE_DIR.path_join("test_slot_old.json")
	var old_file := FileAccess.open(old_path, FileAccess.READ)
	var old_data = JSON.parse_string(old_file.get_as_text())
	old_file.close()
	old_data["saved_at"] = 1
	var rewrite := FileAccess.open(old_path, FileAccess.WRITE)
	rewrite.store_string(JSON.stringify(old_data))
	rewrite.close()
	SaveManager.save_to_slot(hex_grid, "test_slot_new", TEST_SAVE_DIR)

	var slots := SaveManager.list_slots(TEST_SAVE_DIR)

	assert_eq(slots[0].slot_id, "test_slot_new", "o slot salvo mais recentemente deveria vir primeiro")

func test_list_slots_skips_corrupted_files_instead_of_crashing():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE_DIR))
	var bad_file := FileAccess.open(TEST_SAVE_DIR.path_join("corrupted.json"), FileAccess.WRITE)
	bad_file.store_string("isto nao e JSON valido{{{")
	bad_file.close()
	SaveManager.save_to_slot(hex_grid, "test_slot_good", TEST_SAVE_DIR)

	var slots := SaveManager.list_slots(TEST_SAVE_DIR)

	assert_eq(slots.size(), 1, "o arquivo corrompido deveria ser pulado, nao derrubar a lista inteira")
	assert_eq(slots[0].slot_id, "test_slot_good")

func test_has_any_slots_reflects_whether_any_slot_exists():
	assert_false(SaveManager.has_any_slots(TEST_SAVE_DIR))
	SaveManager.save_to_slot(hex_grid, "test_slot_any", TEST_SAVE_DIR)
	assert_true(SaveManager.has_any_slots(TEST_SAVE_DIR))

func test_delete_slot_removes_it_from_list_slots():
	SaveManager.save_to_slot(hex_grid, "test_slot_to_delete", TEST_SAVE_DIR)
	assert_eq(SaveManager.list_slots(TEST_SAVE_DIR).size(), 1)

	SaveManager.delete_slot("test_slot_to_delete", TEST_SAVE_DIR)

	assert_true(SaveManager.list_slots(TEST_SAVE_DIR).is_empty())
