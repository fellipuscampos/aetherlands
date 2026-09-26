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

func before_each():
	_original_players = GameManager.players
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

func test_current_save_keeps_war_and_unit_orders():
	human.war_weariness = 23.0
	var coords := hex_grid.tiles.keys()
	var unit := _make_unit("warrior", human, coords[0])
	unit.fortified = true
	unit.move_order_target = coords[2]
	_make_unit("warrior", rival, coords[1])
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	var loaded := GameManager.human_player
	assert_true(loaded.is_at_war_with(GameManager.rival_players[0]))
	assert_true(GameManager.rival_players[0].is_at_war_with(loaded))
	assert_eq(loaded.war_weariness, 23.0)
	assert_true(loaded.units[0].fortified)
	assert_eq(loaded.units[0].move_order_target, coords[2])

func test_save_restores_transformed_land_and_pillage():
	var coords := hex_grid.tiles.keys()
	var a := hex_grid.found_city(coords[0], human, "A")
	hex_grid.found_city(coords[1], rival, "B")
	a._consecutive_siege_turns = 3
	hex_grid.transform_tile_terrain(coords[2], HexTileData.TerrainType.GRASSLAND)
	hex_grid._pillaged_tiles[coords[3]] = TurnManager.turn_number + 5
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	assert_eq(hex_grid.get_tile(coords[2]).terrain_type, HexTileData.TerrainType.GRASSLAND)
	assert_true(hex_grid.is_tile_pillaged(coords[3], TurnManager.turn_number))
	var loaded := GameManager.human_player
	assert_eq(loaded.cities[0]._consecutive_siege_turns, 3)

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
	_make_unit("warrior", rival, rival_coord) # so pra check_game_over() nao fechar o jogo no load

	var city = hex_grid.found_city(city_coord, human, "Minha Capital")
	city.set_production("v2_unit_archer") # antes de setar stored_production: ver comentario em SaveManager
	city.stored_production = 2.0
	city.buildings["v2_building_guardian_hall"] = true
	city.fortification_level = 1 # Fase 16: o escudo vem da Fortificação V2 (máx. 8)
	city.hp = 17.5
	city.shield = 6.0

	human.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_2"))

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
	assert_eq(GameManager.human_player.units.size(), 1)
	assert_almost_eq(GameManager.human_player.units[0].hp, 7.0, 0.01)
	assert_almost_eq(GameManager.human_player.units[0].movement_left, 1.0, 0.01)
	assert_eq(GameManager.human_player.units[0].coord, unit_coord)

	assert_eq(GameManager.human_player.cities.size(), 1)
	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.city_name, "Minha Capital")
	assert_almost_eq(loaded_city.stored_production, 2.0, 0.01)
	assert_eq(loaded_city.production_item, "v2_unit_archer")
	assert_true(loaded_city.buildings.has("v2_building_guardian_hall"), "predios construidos deveriam sobreviver ao save/load")
	assert_almost_eq(loaded_city.hp, 17.5, 0.01, "vida da cidade deveria sobreviver ao save/load")
	assert_almost_eq(loaded_city.shield, 6.0, 0.01, "escudo da cidade deveria sobreviver ao save/load")
	assert_eq(loaded_city.fortification_level, 1, "nível de Fortificação deveria sobreviver ao save/load")

	assert_true(GameManager.human_player.v2_research.is_completed("v2_doctrine_guardian_1"), "pesquisa concluída deveria sobreviver ao save/load")
	assert_eq(GameManager.human_player.v2_research.active_id, "v2_doctrine_guardian_2")

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

	assert_eq(GameManager.difficulty, "hard", "o campo continua viajando no save (sem efeito de jogo desde a Fase 25)")

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
	city.buildings["v2_building_guardian_hall"] = true
	city.building_coords["v2_building_guardian_hall"] = building_coord

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	SaveManager.load_game(loaded_grid, TEST_SAVE_PATH)

	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.building_coords.get("v2_building_guardian_hall"), building_coord)
	var placed = loaded_grid.get_building_at(building_coord)
	assert_not_null(placed, "predio deveria ter um modelo 3D recriado no mesmo tile apos carregar")
	assert_eq(placed.building_id, "v2_building_guardian_hall")

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

func test_save_and_load_never_restores_v1_victory_state():
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
	for field in ["arcane_ritual_active", "arcane_ritual_streak", "territorial_streak", "arcane_ritual_city_coord"]:
		assert_false(field in loaded_rival, "Fase 25: %s (vitória V1) não existe mais" % field)

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

## Aetherlands V2, Fase 1: o estado de pesquisa V2 é salvo POR CIVILIZAÇÃO num
## bloco opcional "v2_research" (sem bump de SAVE_VERSION). Save antigo sem o bloco
## carrega com estado V2 vazio; bloco corrompido nunca derruba o load.
func _read_test_save() -> Dictionary:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	return data

func _write_test_save(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _prepare_minimal_save_setup() -> void:
	var coords := hex_grid.tiles.keys()
	_make_unit("warrior", human, coords[0])
	_make_unit("warrior", rival, coords[1])

## Fase 26: identidade racial é derivada exclusivamente do id de raça que o save já possuía.
## Não existe snapshot de multiplicadores, cargas ou perfil racial no formato persistido.
func test_racial_profile_round_trip_is_rederived_from_the_existing_race_id():
	_prepare_minimal_save_setup()
	human.civ.race = "dwarf"
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	var save_text := JSON.stringify(data)
	assert_eq(data.human_race, "dwarf")
	for derived_key in ["race_bonus", "racial_bonus", "gold_income_multiplier", "builder_charge_bonus", "annexation_point_bonus"]:
		assert_false(save_text.contains(derived_key), "estado racial derivado não entra no save: %s" % derived_key)

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_eq(GameManager.human_player.civ.race, "dwarf")
	assert_almost_eq(V2RaceBonusRuntime.gold_income_multiplier(GameManager.human_player), 1.10, 0.0001)
	assert_almost_eq(V2RaceBonusRuntime.city_production_multiplier(GameManager.human_player), 1.10, 0.0001)

func test_pre_phase26_save_with_only_the_race_id_receives_the_profile_automatically():
	_prepare_minimal_save_setup()
	human.civ.race = "elf"
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	# Estrutura representativa da Fase 25: a versão não muda e não há bloco racial novo.
	assert_eq(int(data.version), SaveManager.SAVE_VERSION)
	assert_false(data.has("v2_race_bonuses"))
	assert_false(data.human.has("v2_race_bonuses"))
	_write_test_save(data)

	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	assert_eq(GameManager.human_player.civ.race, "elf")
	assert_almost_eq(V2RaceBonusRuntime.knowledge_income_multiplier(GameManager.human_player), 1.10, 0.0001)
	assert_almost_eq(V2RaceBonusRuntime.mana_income_multiplier(GameManager.human_player), 1.10, 0.0001)

func test_save_and_load_restores_v2_research_per_civilization():
	_prepare_minimal_save_setup()
	var mine := human.v2_research
	mine.complete_research("v2_doctrine_guardian_1")
	mine.select_research("v2_doctrine_guardian_2")
	mine.add_knowledge(7.5)
	mine.select_research("v2_magic_sacred_1")
	mine.add_knowledge(2.0)
	mine.select_research("v2_doctrine_guardian_2") # ativo de novo; sacred_1 fica PARCIAL
	var theirs := rival.v2_research
	theirs.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	theirs.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	theirs.add_knowledge(12.0) # sem ativo: Conhecimento guardado
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))

	var loaded_mine := GameManager.human_player.v2_research
	assert_eq(loaded_mine.active_id, "v2_doctrine_guardian_2")
	assert_eq(loaded_mine.get_completed_ids(), ["v2_doctrine_guardian_1"])
	assert_almost_eq(loaded_mine.get_progress("v2_doctrine_guardian_2"), 7.5, 0.001)
	assert_almost_eq(loaded_mine.get_progress("v2_magic_sacred_1"), 2.0, 0.001, "vários progressos guardados")
	assert_eq(loaded_mine.node_state("v2_magic_sacred_1"), V2ResearchDatabase.NodeState.PARTIAL)
	var loaded_theirs := GameManager.rival_players[0].v2_research
	assert_eq(loaded_theirs.active_id, "")
	assert_almost_eq(loaded_theirs.research_overflow, 12.0, 0.001, "Conhecimento guardado sobrevive")
	assert_true(loaded_theirs.is_available("v2_transcendence"), "capstone disponível depois do load")
	assert_false(loaded_mine.is_available("v2_transcendence"), "cada civilização tem o seu")

func test_save_file_has_a_v2_block_for_every_civilization_and_keeps_the_save_version():
	_prepare_minimal_save_setup()
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))

	var data := _read_test_save()

	assert_eq(int(data.version), SaveManager.SAVE_VERSION, "campo opcional: não exige bump de versão")
	assert_true(data.human.has("v2_research"))
	assert_eq(data.human.v2_research.completed_ids, ["v2_doctrine_guardian_1"])
	for rival_data in data.rivals:
		assert_true(rival_data.has("v2_research"))

func test_load_of_a_save_without_the_v2_block_starts_with_empty_state():
	_prepare_minimal_save_setup()
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	data.human.erase("v2_research") # como um save de antes da Fase 1
	for rival_data in data.rivals:
		rival_data.erase("v2_research")
	_write_test_save(data)

	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH), "save antigo continua carregando")

	assert_eq(GameManager.human_player.v2_research.to_dict(), V2ResearchState.new().to_dict())
	assert_eq(GameManager.rival_players[0].v2_research.to_dict(), V2ResearchState.new().to_dict())

func test_load_survives_corrupt_and_invalid_v2_blocks():
	_prepare_minimal_save_setup()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	data.human.v2_research = "lixo"
	data.rivals[0].v2_research = {
		"active_id": "v2_doctrine_guardian_2",             # bloqueado: N1 não concluído
		"completed_ids": ["v2_magic_sacred_1", "v2_id_que_nao_existe", 7],
		"progress_by_id": {"v2_magic_infernal_1": -4.0, "v2_magic_druidism_1": 99999.0, "v2_fantasma": 3.0},
		"research_overflow": -10.0,
	}
	_write_test_save(data)

	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH), "bloco V2 ruim nunca rejeita o save")

	assert_eq(GameManager.human_player.v2_research.to_dict(), V2ResearchState.new().to_dict())
	var sanitized := GameManager.rival_players[0].v2_research
	assert_eq(sanitized.active_id, "", "ativo inválido descartado")
	assert_eq(sanitized.get_completed_ids(), ["v2_magic_sacred_1"], "id inexistente e tipo errado ignorados")
	assert_false(sanitized.progress_by_id.has("v2_magic_infernal_1"), "progresso negativo descartado")
	var druidism_cost := V2ResearchDatabase.get_node("v2_magic_druidism_1").cost
	assert_almost_eq(sanitized.get_progress("v2_magic_druidism_1"), druidism_cost, 0.001, "progresso limitado ao custo")
	assert_false(sanitized.progress_by_id.has("v2_fantasma"))
	assert_almost_eq(sanitized.research_overflow, 0.0, 0.001)

func test_save_and_load_restores_rival_v2_ai_strategy_but_never_adds_it_to_human():
	_prepare_minimal_save_setup()
	GameManager.players = [human, rival]
	V2StrategicAI.initialize_player(rival, 0, hex_grid.map_seed, 1)
	rival.v2_ai_strategy.victory_focus = V2AIStrategyState.VictoryFocus.TRANSCENDENCE
	rival.v2_ai_strategy.adaptive_doctrine_branch = "siege"
	rival.v2_ai_strategy.pressure_by_role_or_trait = {"mounted": 2.75, "caster": 1.25}
	rival.v2_ai_strategy.last_strategy_review_turn = 37
	var expected := rival.v2_ai_strategy.to_dict()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := _read_test_save()
	assert_false(raw.human.has("v2_ai_strategy"), "o jogador humano não recebe estado de IA")
	assert_true(raw.rivals[0].has("v2_ai_strategy"))

	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	assert_eq(GameManager.rival_players[0].v2_ai_strategy.to_dict(), expected)

func test_legacy_save_without_v2_ai_strategy_rederives_deterministic_orientation():
	_prepare_minimal_save_setup()
	GameManager.players = [human, rival]
	V2StrategicAI.initialize_player(rival, 0, hex_grid.map_seed, 1)
	var expected_orientation := rival.v2_ai_strategy.orientation
	var expected_seed := rival.v2_ai_strategy.strategy_seed
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := _read_test_save()
	raw.rivals[0].erase("v2_ai_strategy")
	_write_test_save(raw)

	assert_true(SaveManager.load_game(hex_grid, TEST_SAVE_PATH))
	var restored := GameManager.rival_players[0].v2_ai_strategy
	assert_eq(restored.orientation, expected_orientation)
	assert_eq(restored.strategy_seed, expected_seed)
	assert_true(restored.is_initialized())

# --- Aetherlands V2, Fase 15: Construtor, melhorias de recurso, Déficit/Tensão derivados ---------

## Só o id da melhoria + a coordenada vão pro save (§77 do pedido) — o rendimento é sempre
## derivado de novo, pelo tier do dono no momento da consulta. O marcador visual é reconstruído.
func test_save_and_load_restores_resource_improvements_by_coord_and_rebuilds_the_marker():
	var city_coord: Vector2i = hex_grid.tiles.keys()[0]
	var city = hex_grid.found_city(city_coord, human, "Capital")
	var improved: Vector2i = hex_grid.get_neighbors(city_coord)[0]
	city.resource_improvements[improved] = "v2_improvement_gem_mine"

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	assert_true(text.contains("v2_improvement_gem_mine"), "o id vai pro save")
	assert_false(text.contains("improvement_total"), "o rendimento derivado nunca é salvo")

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded_city: City = GameManager.human_player.cities[0]
	assert_eq(loaded_city.resource_improvements.get(improved), "v2_improvement_gem_mine")
	assert_eq(loaded_city.resource_improvements.size(), 1)
	assert_true(loaded_grid.improvement_markers_by_coord.has(improved), "marcador visual reconstruído no load")
	var marker: Node3D = loaded_grid.improvement_markers_by_coord[improved]
	assert_eq(marker.get_child_count(), 2, "modelo KayKit reaproveitado da Mina de Gemas + o selo dourado")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(loaded_city, "gold").improvement_total, 4.0, 0.0001, "rendimento re-derivado (tier 1)")

func test_save_and_load_restores_the_builders_remaining_charges():
	var coord: Vector2i = hex_grid.tiles.keys()[0]
	var builder := _make_unit("v2_unit_builder", human, coord)
	builder.work_charges_remaining = 2

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded_builder: Unit = loaded_grid.get_unit_at(coord)
	assert_not_null(loaded_builder)
	assert_eq(loaded_builder.unit_data.visual_kind, "v2_unit_builder")
	assert_eq(loaded_builder.work_charges_remaining, 2, "cargas restantes sobrevivem -- nunca recalculadas pelo tier atual")

## Déficit e Tensão Logística são DERIVADOS (§35/§131): nada disso vai pro save, e o load os
## recalcula idênticos a partir de cidades/prédios/unidades/Ouro.
func test_deficit_and_logistic_tension_are_never_saved_and_are_rederived_after_load():
	var city_coord: Vector2i = hex_grid.tiles.keys()[0]
	var city = hex_grid.found_city(city_coord, human, "Capital")
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true # upkeep 3 > renda base 2
	human.gold = 0.0
	var n := 0
	for coord in hex_grid.tiles.keys():
		if n >= 5:
			break
		if coord != city_coord and hex_grid.get_unit_at(coord) == null:
			_make_unit("v2_unit_shieldbearer", human, coord)
			n += 1
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "pré-condição: Déficit")
	assert_true(V2LogisticsRuntime.is_logistically_strained(human), "pré-condição: Tensão (5 > 4)")

	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH).to_lower()
	for key in ["deficit", "tension", "strained", "supply_used", "supply_capacity"]:
		assert_false(text.contains(key), "'%s' nunca é salvo" % key)

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_true(V2EconomyRuntime.is_gold_deficit(GameManager.human_player), "Déficit re-derivado")
	assert_true(V2LogisticsRuntime.is_logistically_strained(GameManager.human_player), "Tensão re-derivada")

# --- Aetherlands V2, Fase 16: Fortificação, Ataque da Cidade e Supremacia Militar V2 ----------------

func _phase16_city(owner: PlayerData, name: String) -> City:
	for coord in hex_grid.tiles.keys():
		if hex_grid.get_city_at(coord) == null and hex_grid.get_unit_at(coord) == null and hex_grid.city_owning_tile(coord) == null and not hex_grid.get_tile(coord).blocks_land_units():
			return hex_grid.found_city(coord, owner, name, true)
	fail_test("sem tile livre pra %s" % name)
	return null

func _phase16_reload() -> HexGrid:
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	return loaded_grid

func test_save_and_load_restores_fortification_city_attack_turn_and_supremacy_credit():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	var city := _phase16_city(human, "Bastião")
	city.city_level = 3
	city.fortification_level = 2
	city.shield = 9.0
	city.hp = 20.0
	city.last_city_attack_turn = 41
	city.v2_supremacy_captured_from = 1
	_prepare_minimal_save_setup()
	_phase16_reload()
	var loaded: City = GameManager.human_player.cities[0]
	assert_eq(loaded.fortification_level, 2)
	assert_eq(loaded.shield, 9.0, "escudo danificado sobrevive")
	assert_eq(loaded.hp, 20.0)
	assert_eq(loaded.last_city_attack_turn, 41, "o disparo usado continua usado depois do load")
	assert_eq(loaded.v2_supremacy_captured_from, 1)
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(GameManager.human_player, GameManager.rival_players[0]), "crédito re-derivado pelo id estável")

func test_supremacy_progress_is_never_saved_only_its_source_field():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	_phase16_city(human, "Bastião")
	_prepare_minimal_save_setup()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH).to_lower()
	for key in ["satisfied", "supremacy_progress", "rival_count", "city_attack_power"]:
		assert_false(text.contains(key), "'%s' nunca é salvo" % key)

func test_a_legacy_save_without_the_field_migrates_the_v1_wall_chain():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	var city := _phase16_city(human, "Antiga")
	city.city_level = 3
	city.buildings["walls"] = true
	city.buildings["walls_2"] = true
	_prepare_minimal_save_setup()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	var c: Dictionary = data.human.cities[0]
	c.erase("fortification_level")
	c.erase("last_city_attack_turn")
	c.erase("v2_supremacy_captured_from")
	c["hp"] = 60.0 # vida V1 antiga (20 + 4 x população) acima do novo máximo
	c["shield"] = 15.0
	_write_test_save(data)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded: City = GameManager.human_player.cities[0]
	assert_eq(loaded.fortification_level, 2, "Muralhas II V1 -> Muralhas II V2")
	assert_eq(loaded.hp, 36.0, "limitada ao máximo da Cidade III, nunca destruída")
	assert_eq(loaded.shield, 14.0, "limitado ao máximo de Muralhas II")
	assert_eq(loaded.last_city_attack_turn, -1)
	assert_eq(loaded.v2_supremacy_captured_from, -1)
	assert_almost_eq(loaded.defense_bonus(), V2FortificationData.city_defense_bonus(2), 0.0001)
	assert_false(loaded.buildings.has("walls") or loaded.buildings.has("walls_2"), "Fase 25: os prédios V1 saem do save na sanitização, sem reembolso")

func test_a_legacy_save_without_walls_has_no_fortification():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	_phase16_city(human, "Aberta")
	_prepare_minimal_save_setup()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	data.human.cities[0].erase("fortification_level")
	_write_test_save(data)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_eq(GameManager.human_player.cities[0].fortification_level, 0)

# --- Aetherlands V2, Fase 17: Magia Sagrada ------------------------------------------------------------------

func _phase17_free_coord(near: Vector2i = Vector2i(999, 999)) -> Vector2i:
	for coord in hex_grid.tiles.keys():
		if hex_grid.get_city_at(coord) == null and hex_grid.get_unit_at(coord) == null and not hex_grid.get_tile(coord).blocks_land_units():
			if near == Vector2i(999, 999) or HexMetrics.axial_distance(coord, near) <= 2:
				return coord
	fail_test("sem tile livre")
	return Vector2i(999, 999)

func test_save_and_load_restores_spell_cooldown_aegis_mana_and_seraph_and_the_aegis_still_expires():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	for i in range(1, 10):
		human.v2_research.complete_research("v2_magic_sacred_%d" % i)
	var cleric_coord := _phase17_free_coord()
	var cleric := _make_unit("v2_unit_sacred_cleric", human, cleric_coord)
	var seraph := _make_unit("v2_manifestation_seraph", human, _phase17_free_coord(cleric_coord))
	var ally := _make_unit("warrior", human, _phase17_free_coord(cleric_coord))
	human.mana = 50.0
	TurnManager.turn_number = 12
	GameManager.hex_grid = hex_grid
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", ally.coord, hex_grid))
	var ally_coord := ally.coord
	var seraph_coord := seraph.coord
	_phase16_reload()
	var loaded_cleric: Unit = null
	var loaded_ally: Unit = null
	var loaded_seraph: Unit = null
	for unit in GameManager.human_player.units:
		if unit.coord == cleric_coord:
			loaded_cleric = unit
		elif unit.coord == ally_coord:
			loaded_ally = unit
		elif unit.coord == seraph_coord:
			loaded_seraph = unit
	assert_eq(GameManager.human_player.mana, 44.0, "Mana sobrevive")
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_cleric, "v2_spell_sacred_aegis"), 2, "recarga sobrevive")
	assert_true(V2MagicRuntime.is_status_active(loaded_ally, "v2_spell_sacred_aegis"), "Égide ativa sobrevive")
	assert_eq(V2MagicRuntime.spells_for_unit(loaded_cleric).size(), 4, "repertório re-derivado, nunca salvo")
	assert_true(loaded_seraph.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_eq(loaded_seraph.unit_data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_false(V2ManifestationSystem.slot_available(GameManager.human_player, "sacred"), "slot derivado após o load")
	TurnManager.turn_number += 1
	V2MagicRuntime.expire_finished(GameManager.human_player)
	assert_false(V2MagicRuntime.is_status_active(loaded_ally, "v2_spell_sacred_aegis"), "expira no momento certo depois do load")

func test_save_and_load_keeps_a_seraph_production_waiting_for_mana_and_it_pays_once():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	for i in range(1, 10):
		human.v2_research.complete_research("v2_magic_sacred_%d" % i)
	var city := _phase16_city(human, "Catedral")
	city.city_level = 3
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	human.mana = 60.0
	city.set_production("v2_manifestation_seraph")
	human.mana = 10.0
	city.stored_production = 100.0
	_prepare_minimal_save_setup()
	var loaded_grid := _phase16_reload()
	var loaded: City = GameManager.human_player.cities[0]
	assert_eq(loaded.production_item, "v2_manifestation_seraph")
	assert_eq(loaded.stored_production, 100.0)
	assert_eq(loaded.production_waiting_for_mana(), 60, "continua esperando")
	var result := loaded.process_turn(loaded_grid)
	assert_eq(result.spawn_unit_kind, "", "sem Mana não nasce")
	assert_eq(loaded.stored_production, 100.0, "sem perder PP")
	GameManager.human_player.mana = 70.0
	result = loaded.process_turn(loaded_grid)
	assert_eq(result.spawn_unit_kind, "v2_manifestation_seraph", "com Mana conclui (a cobrança é do GameManager, uma vez)")

# --- Aetherlands V2, Fase 18: duas Escolas e namespace derivado ---------------------------------

func test_save_and_load_restores_both_v2_schools_without_serializing_the_school_field():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	for branch in ["sacred", "infernal"]:
		for i in range(1, 10):
			human.v2_research.complete_research("v2_magic_%s_%d" % [branch, i])
	var cleric_coord := _phase17_free_coord()
	var cleric := _make_unit("v2_unit_sacred_cleric", human, cleric_coord)
	var warlock_coord := _phase17_free_coord(cleric_coord)
	var warlock := _make_unit("v2_unit_infernal_warlock", human, warlock_coord)
	var seraph_coord := _phase17_free_coord(cleric_coord)
	_make_unit("v2_manifestation_seraph", human, seraph_coord)
	var archdemon_coord := _phase17_free_coord(warlock_coord)
	_make_unit("v2_manifestation_archdemon", human, archdemon_coord)
	var ally_coord := _phase17_free_coord(cleric_coord)
	var ally := _make_unit("warrior", human, ally_coord)
	var rival_coord := _phase17_free_coord(warlock_coord)
	_make_unit("warrior", rival, rival_coord)
	human.mana = 123.0
	TurnManager.turn_number = 23
	GameManager.hex_grid = hex_grid
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", ally.coord, hex_grid))
	warlock.magic_cooldowns["v2_spell_infernal_blast"] = TurnManager.turn_number + 3
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	assert_false(raw.contains("v2_magic_school"), "a Escola é dado canônico do kind, não estado mutável")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var by_coord := {}
	for unit in GameManager.human_player.units:
		by_coord[unit.coord] = unit
	var loaded_cleric: Unit = by_coord[cleric_coord]
	var loaded_warlock: Unit = by_coord[warlock_coord]
	var loaded_seraph: Unit = by_coord[seraph_coord]
	var loaded_archdemon: Unit = by_coord[archdemon_coord]
	var loaded_ally: Unit = by_coord[ally_coord]
	assert_eq([loaded_cleric.unit_data.v2_magic_school], ["sacred"])
	assert_eq([loaded_warlock.unit_data.v2_magic_school], ["infernal"])
	assert_eq(V2MagicRuntime.spells_for_unit(loaded_cleric).size(), 4)
	assert_eq(V2MagicRuntime.spells_for_unit(loaded_warlock).size(), 4)
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_warlock, "v2_spell_infernal_blast"), 3)
	assert_true(V2MagicRuntime.is_status_active(loaded_ally, "v2_spell_sacred_aegis"))
	assert_true(loaded_seraph.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_true(loaded_archdemon.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_false(V2ManifestationSystem.slot_available(GameManager.human_player, "sacred"))
	assert_false(V2ManifestationSystem.slot_available(GameManager.human_player, "infernal"))
	assert_eq(GameManager.human_player.mana, 117.0, "Mana e custo da Égide sobrevivem")

# --- Aetherlands V2, Fase 19: retinues e comando derivado ----------------------------------------

func test_save_and_load_restores_hosts_and_rederives_command_without_saving_it():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	for i in range(1, 10):
		human.v2_research.complete_research("v2_magic_necromancy_%d" % i)
	var necro_coord := _phase17_free_coord()
	_make_unit("v2_unit_necromancer", human, necro_coord)
	var first_coord := _phase17_free_coord(necro_coord)
	var first := _make_unit("v2_unit_skeleton_host", human, first_coord)
	var macabre_coord := _phase17_free_coord(first_coord)
	var macabre := _make_unit("v2_unit_macabre_host", human, macabre_coord)
	var lich_coord := _phase17_free_coord(macabre_coord)
	_make_unit("v2_manifestation_lich_sovereign", human, lich_coord)
	first.hp = 7.0
	first.serial_id = 11 # _make_unit não passa por spawn_unit: serial explícito
	macabre.serial_id = 12
	macabre.magic_status["v2_spell_macabre_command"] = V2OwnerTurnEffect.expiry_for_now()
	GameManager.hex_grid = hex_grid
	assert_eq(V2RetinueSystem.command_state(human, "necromancy").total_cost, 3)
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	for field in ["retinue", "command_capacity", "command_used", "commanded"]:
		assert_false(raw.contains(field), "comando é derivado, nunca salvo: %s" % field)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var by_coord := {}
	for unit in GameManager.human_player.units:
		by_coord[unit.coord] = unit
	var loaded_first: Unit = by_coord[first_coord]
	var loaded_macabre: Unit = by_coord[macabre_coord]
	assert_eq(loaded_first.unit_data.visual_kind, "v2_unit_skeleton_host")
	assert_eq(loaded_first.hp, 7.0)
	assert_eq(loaded_first.serial_id, first.serial_id, "a ordem determinística usa o serial restaurado")
	assert_true(loaded_first.unit_data.has_trait(UnitData.TRAIT_RETINUE))
	assert_eq(V2RetinueSystem.command_capacity(GameManager.human_player, "necromancy"), 6)
	assert_eq(V2RetinueSystem.command_used(GameManager.human_player, "necromancy"), 3)
	assert_true(V2RetinueSystem.is_commanded(loaded_first) and V2RetinueSystem.is_commanded(loaded_macabre))
	assert_almost_eq(V2MagicRuntime.attack_multiplier(loaded_macabre), 1.4, 0.0001)
	assert_false(V2ManifestationSystem.slot_available(GameManager.human_player, "necromancy"))

# --- Aetherlands V2, Fase 20: modificação física de terreno (estado global do mapa) -------------

func test_save_and_load_restores_terrain_modifications_as_a_sparse_global_block():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	GameManager.hex_grid = hex_grid
	var coords: Array[Vector2i] = []
	for coord in hex_grid.tiles.keys():
		if coords.size() >= 2:
			break
		if not hex_grid.get_tile(coord).blocks_land_units() and hex_grid.get_city_at(coord) == null and hex_grid.get_unit_at(coord) == null:
			coords.append(coord)
	assert_true(V2TerrainRuntime.apply(hex_grid, coords[0], "v2_terrain_dense_grove"))
	assert_true(V2TerrainRuntime.apply(hex_grid, coords[1], "v2_terrain_raised_ground"))
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	assert_true(raw.contains("v2_terrain_modifications"))
	assert_false(raw.contains("defense_multiplier"), "o efeito é derivado do id, nunca salvo")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_eq(V2TerrainRuntime.modification_id_at(loaded_grid, coords[0]), "v2_terrain_dense_grove")
	assert_eq(V2TerrainRuntime.modification_id_at(loaded_grid, coords[1]), "v2_terrain_raised_ground")
	assert_eq(loaded_grid.terrain_step_cost(coords[1]), float(loaded_grid.get_tile(coords[1]).movement_cost) + 2.0)

# --- Aetherlands V2, Fase 22: zonas ambientais temporárias (estado global) ---------------------

func test_save_and_load_restores_environmental_zones_with_owner_school_and_remaining_rounds():
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.hex_grid = hex_grid
	var coord := Vector2i.ZERO
	assert_true(V2EnvironmentalZoneSystem.apply(hex_grid, coord, "v2_zone_elemental_cataclysm", 0, "elementalism", 1))
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	assert_true(raw.contains("v2_environmental_zones"))
	assert_false(raw.contains("physical_ranged_attack_multiplier"), "efeitos continuam derivados do id")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var entry := V2EnvironmentalZoneSystem.zone_entry_at(coord, loaded_grid)
	assert_eq([entry.zone_id, entry.owner_index, entry.school, entry.remaining_rounds], ["v2_zone_elemental_cataclysm", 0, "elementalism", 3])
	assert_eq(V2EnvironmentalZoneSystem.zone_at(coord, loaded_grid).round_tick_magic_damage, 5.0)
	assert_true(loaded_grid._v2_environmental_zone_markers.has(coord))

func test_old_save_without_environmental_block_loads_with_empty_layer():
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.hex_grid = hex_grid
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	data.erase("v2_environmental_zones")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_true(loaded_grid.v2_environmental_zones.is_empty())

# --- Aetherlands V2, Fase 23: Ritual Final de Transcendência (estado global) -------------------

func _phase23_ready_ritual() -> City:
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival]
	GameManager.hex_grid = hex_grid
	GameManager.state = GameManager.GameState.PLAYING
	for branch in ["sacred", "infernal"]:
		for tier in range(1, 10):
			human.v2_research.complete_research("v2_magic_%s_%d" % [branch, tier])
	human.v2_research.complete_research("v2_transcendence")
	var city := _phase16_city(human, "Cidade Ritual")
	city.buildings["v2_building_sacred_ritual"] = true
	_make_unit("v2_manifestation_seraph", human, _phase17_free_coord(city.coord))
	_make_unit("v2_manifestation_archdemon", human, _phase17_free_coord(city.coord))
	_make_unit("warrior", rival, _phase17_free_coord(city.coord))
	human.mana = 150.0
	return city

func test_save_and_load_restores_active_transcendence_ritual_marker_and_same_turn_guard():
	var city := _phase23_ready_ritual()
	TurnManager.turn_number = 77
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	TurnManager.turn_number = 78
	V2TranscendenceSystem.process_global_round(hex_grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := _read_test_save()
	assert_eq(raw.v2_transcendence_rituals.size(), 1)
	assert_eq(int(raw.v2_transcendence_rituals[0].remaining_rounds), 3)
	assert_eq(int(raw.v2_transcendence_rituals[0].last_progress_turn), 78)

	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded := GameManager.human_player
	assert_true(V2TranscendenceSystem.has_active_ritual(loaded))
	assert_eq(V2TranscendenceSystem.ritual_site_coord(loaded), city.coord)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(loaded), 3)
	assert_true(loaded_grid._v2_transcendence_markers.has(0), "o marker público é reconstruído depois do mundo")
	V2TranscendenceSystem.process_global_round(loaded_grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(loaded), 3, "load no mesmo turno não duplica o tick")
	TurnManager.turn_number = 79
	assert_eq(int(loaded.v2_transcendence_ritual.last_progress_turn), 78)
	assert_eq(V2TranscendenceSystem.active_invalid_reason(loaded, loaded_grid), "")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	V2TranscendenceSystem.process_global_round(loaded_grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(loaded), 2)

func test_old_save_without_transcendence_block_loads_without_a_ritual_or_marker():
	var city := _phase23_ready_ritual()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := _read_test_save()
	raw.erase("v2_transcendence_rituals")
	_write_test_save(raw)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_false(V2TranscendenceSystem.has_active_ritual(GameManager.human_player))
	assert_true(loaded_grid._v2_transcendence_markers.is_empty())

func test_corrupt_transcendence_save_entries_are_silently_discarded():
	_phase23_ready_ritual()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var raw := _read_test_save()
	raw.v2_transcendence_rituals = [
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": 0, "last_progress_turn": TurnManager.turn_number},
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": 5, "last_progress_turn": TurnManager.turn_number},
		{"owner_index": 99, "site": [0, 0], "remaining_rounds": 2, "last_progress_turn": TurnManager.turn_number},
	]
	_write_test_save(raw)
	watch_signals(EventBus)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	assert_false(V2TranscendenceSystem.has_active_ritual(GameManager.human_player))
	assert_true(loaded_grid._v2_transcendence_markers.is_empty())
	assert_signal_not_emitted(EventBus, "v2_transcendence_interrupted", "load inválido não anuncia falsa interrupção")

func test_transcendence_save_with_one_round_wins_on_the_next_valid_global_round():
	var city := _phase23_ready_ritual()
	TurnManager.turn_number = 90
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 1
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded := GameManager.human_player
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(loaded), 1)
	TurnManager.turn_number = 91
	V2TranscendenceSystem.process_global_round(loaded_grid)
	assert_true(V2TranscendenceSystem.victory_ready(loaded, loaded_grid))
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [loaded, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE])

# --- Fase 25: saves antigos com estado V1 --------------------------------------------------------------------

## Um save da Fase 24 (ou anterior) ainda traz pesquisa/magia/ciência V1 e campos V1 de cidade. Tudo
## isso carrega sem crash e é DESCARTADO -- nunca convertido em progresso V2.
func test_legacy_v1_player_state_loads_and_is_never_converted():
	_prepare_minimal_save_setup()
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	data.human["researched_techs"] = ["quartel", "celeiro", "muralhas", "navegacao"]
	data.human["researched_magic"] = ["canalizacao_base", "arcanismo_3"]
	data.human["current_research"] = "arquearia"
	data.human["research_progress"] = 40.0
	data.human["spell_cooldowns"] = {"Lança de Arcana": 3}
	data.human["magic_effects"] = [{"effect": "veil", "center": [0, 0]}]
	data.human["trade_routes"] = [[0, 0, 1, 1]]
	data.human["arcane_ritual_active"] = true
	data.human["territorial_streak"] = 4
	data["victory_rules_version"] = 1
	_write_test_save(data)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded := GameManager.human_player
	assert_true(loaded.v2_research.get_completed_ids().is_empty(), "pesquisa V1 nunca vira pesquisa V2")
	assert_eq(loaded.v2_research.active_id, "")
	for field in ["researched_techs", "researched_magic", "current_research", "research_progress", "spell_cooldowns", "trade_routes"]:
		assert_false(field in loaded, field)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória V1 é avaliada no load")

func test_legacy_city_fields_are_sanitized_on_load_without_refund():
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	_phase16_city(human, "Antiga")
	_prepare_minimal_save_setup()
	var gold_before := human.gold
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	var c: Dictionary = data.human.cities[0]
	c["population"] = 7
	c["stored_food"] = 12.0
	c["worked_tiles"] = [[1, 0], [0, 1]]
	c["captured_developed"] = true
	c["buildings"] = ["granary", "barracks", "market", "v2_building_market"]
	c["repeatable_building_counts"] = {"v2_building_market": 1, "granary": 2}
	c["production_item"] = "barracks_2"
	c["stored_production"] = 9.0
	_write_test_save(data)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded: City = GameManager.human_player.cities[0]
	assert_eq(loaded.buildings.keys(), ["v2_building_market"], "só o prédio V2 sobrevive")
	assert_false(loaded.repeatable_building_counts.has("granary"))
	assert_eq(loaded.production_item, "", "item de produção V1 é cancelado")
	assert_eq(loaded.stored_production, 0.0, "sem reembolso nem crédito do progresso V1")
	assert_almost_eq(GameManager.human_player.gold, gold_before, 0.001, "nenhum reembolso em ouro")
	for field in ["population", "stored_food", "worked_tiles", "captured_developed"]:
		assert_false(field in loaded, field)

func test_legacy_unit_of_an_unknown_kind_is_skipped_and_a_legacy_known_unit_is_kept():
	_prepare_minimal_save_setup()
	var coords := hex_grid.tiles.keys()
	_make_unit("cavalry", human, coords[2])
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var data := _read_test_save()
	var ghost: Dictionary = data.human.units[0].duplicate(true)
	ghost["kind"] = "mercador_antigo_inexistente"
	ghost["coord"] = [coords[3].x, coords[3].y]
	ghost["serial_id"] = 987654
	data.human.units.append(ghost)
	_write_test_save(data)
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var kinds: Array = GameManager.human_player.units.map(func(u): return u.unit_data.visual_kind)
	assert_true("cavalry" in kinds, "unidade legada conhecida continua existindo")
	assert_eq(GameManager.human_player.units.size(), 2, "o kind desconhecido é descartado sem crash")

func test_new_saves_never_write_v1_fields():
	_prepare_minimal_save_setup()
	_phase16_city(human, "Nova")
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	for key in ["researched_techs", "researched_magic", "current_research", "research_progress", "\"population\"", "stored_food", "worked_tiles", "trade_routes", "arcane_ritual", "territorial_streak", "victory_rules_version", "personality", "spell_cooldowns", "magic_effects"]:
		assert_false(text.contains(key), key)
	assert_eq(_read_test_save().version, float(SaveManager.SAVE_VERSION))
