extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Guardião N1-N3 (Aetherlands V2,
## Fase 3), pelos mesmos caminhos do jogo: jogo novo -> pesquisa V2 vazia ->
## pesquisar N1 e N2 -> construir o Salão dos Guardiões numa cidade (posicionamento
## de prédio + fim de turno) -> pesquisar N3 -> pôr o Escudeiro em produção ->
## treinar (fim de turno) -> a unidade nasce -> move -> ataque básico -> salvar ->
## carregar -> conferir pesquisas, Salão e unidade -> produzir outro Escudeiro.
##
## O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana
## pra 1 turno, como no jogo; nada do que é testado aqui é debug.

const TEST_SAVE_PATH := "user://test_v2_guardian_flow_savegame.json"
const HALL := "v2_building_guardian_hall"
const KIND := "v2_unit_shieldbearer"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
## Mapa grande o bastante pra o Colonizador inicial não nascer perto demais de uma capital rival.
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []

var _original_state
var _original_players: Array[PlayerData]
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_hex_grid: HexGrid
var _original_rival_count: int
var _original_map_width: int
var _original_map_height: int
var _original_turn_number: int
var _original_turn_player_index: int
var _original_difficulty: String
var _original_human_race: String
var _original_debug_mode: bool
var _original_stagger_ai_turns: bool
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int
var _original_current_save_slot: String
var _original_kingdom_name: String

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_hex_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_difficulty = GameManager.difficulty
	_original_human_race = GameManager.human_race
	_original_debug_mode = GameManager.debug_mode
	_original_stagger_ai_turns = GameManager.stagger_ai_turns
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	_original_current_save_slot = GameManager.current_save_slot
	_original_kingdom_name = GameManager.human_kingdom_name
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	GameManager.stagger_ai_turns = false
	GameManager.human_race = "human"
	GameManager.rival_count = 2
	GameManager.map_width = MAP_WIDTH
	GameManager.map_height = MAP_HEIGHT
	GameManager.debug_mode = true

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
	for player in _players_to_release:
		player.release_relations()
	_players_to_release.clear()
	SaveManager.delete_save(TEST_SAVE_PATH)
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.hex_grid = _original_hex_grid
	GameManager.rival_count = _original_rival_count
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height
	TurnManager.turn_number = _original_turn_number
	TurnManager.current_player_index = _original_turn_player_index
	GameManager.difficulty = _original_difficulty
	GameManager.human_race = _original_human_race
	GameManager.debug_mode = _original_debug_mode
	GameManager.stagger_ai_turns = _original_stagger_ai_turns
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	GameManager._ai_batch_timer = 0.0
	GameManager.current_save_slot = _original_current_save_slot
	GameManager.human_kingdom_name = _original_kingdom_name
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id
	for grid in _hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_hex_grids.clear()

# --- Helpers ----------------------------------------------------------------------------------------------

func _new_game() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_WIDTH, MAP_HEIGHT, 555)
	_hex_grids.append(grid)
	GameManager.start_new_game(grid)
	return grid

## Funda a cidade do humano com o Colonizador inicial, pelo mesmo caminho do jogo.
func _found_human_city(grid: HexGrid) -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			var reason := CitySite.rejection_reason(grid, unit.coord, GameManager.human_player)
			var city := WorldSetup.found_city_from_settler(grid, unit)
			assert_not_null(city, "pré-condição: o Colonizador inicial funda a cidade (motivo: '%s', min_dist %d)" % [reason, CitySite.min_city_distance])
			return city
	fail_test("o humano deveria começar com um Colonizador")
	return null

func _research(state: V2ResearchState, node_id: String) -> void:
	assert_true(state.select_research(node_id), "select %s" % node_id)
	state.add_knowledge(V2ResearchDatabase.get_node(node_id).cost)
	assert_true(state.is_completed(node_id), "concluiu %s" % node_id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")

func _units_of_kind(player: PlayerData, kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in player.units:
		if unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

## Produz um item no MESMO fluxo da HUD (HUD._on_produce_pressed) e conclui o
## turno. Devolve true se a cidade aceitou a produção.
func _train_through_normal_pipeline(city: City, kind: String) -> bool:
	if not GameManager.human_player.has_unlocked(kind) or not city.can_train(kind):
		return false
	city.set_production(kind)
	_end_turn()
	return true

func _save_and_reload() -> HexGrid:
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH), "save_game")
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	_players_to_release.append_array(GameManager.players)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH), "load_game")
	return loaded

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_guardian_n1_to_n3_flow_from_research_to_a_working_shieldbearer_across_save_and_load():
	# 1-2. Jogo novo: a pesquisa V2 do humano está vazia e nada V2 está liberado.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	assert_true(state.completed_ids.is_empty(), "1. pesquisa V2 vazia")
	assert_eq(V2UnlockSystem.unlocked_ids(human), [])
	var city := _found_human_city(grid)
	assert_false(city.can_build(HALL), "sem N2 não constrói o Salão")
	assert_false(city.can_train(KIND))
	assert_false(human.has_unlocked(KIND))

	# 3. Pesquisa N1 e N2 (a única regra de ordem é a do próprio nó: N2 exige N1).
	assert_false(state.can_research("v2_doctrine_guardian_2"), "N2 exige N1")
	_research(state, "v2_doctrine_guardian_1")
	_research(state, "v2_doctrine_guardian_2")
	assert_true(city.can_build(HALL), "N2 libera a construção")
	assert_false(city.can_train(KIND), "ainda sem N3 nem Salão")

	# 4. Constrói o Salão pelo fluxo de posicionamento de prédio (escolhe o tile).
	SelectionManager.start_building_placement(city, HALL)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pra posicionar o Salão")
	var hall_coord: Vector2i = SelectionManager.placeable_coords[0]
	SelectionManager._handle_building_placement_click(hall_coord)
	assert_eq(city.production_item, HALL, "o Salão entrou na produção normal da cidade")
	assert_eq(city.pending_building_coord, hall_coord)
	assert_eq(city.production_cost(), BuildingDatabase.get_building(HALL).production_cost)
	_end_turn()
	assert_true(city.buildings.has(HALL), "o Salão foi construído")
	assert_eq(city.building_coords.get(HALL), hall_coord)
	assert_true(grid.buildings_by_coord.has(hall_coord), "e existe no mapa")
	assert_false(city.can_train(KIND), "o Salão sozinho não treina o Escudeiro (falta o N3)")

	# 5. Pesquisa N3: agora sim.
	_research(state, "v2_doctrine_guardian_3")
	assert_true(human.has_unlocked(KIND))
	assert_true(city.can_train(KIND))
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_guardian", "v2_building_guardian_hall", "v2_unit_shieldbearer"])

	# 6-7. Produz e treina o Escudeiro (fila normal), a unidade nasce.
	var before := _units_of_kind(human, KIND).size()
	assert_eq(before, 0)
	city.set_production(KIND)
	assert_eq(city.production_item, KIND, "6. Escudeiro em produção")
	_end_turn()
	var shieldbearers := _units_of_kind(human, KIND)
	assert_eq(shieldbearers.size(), 1, "7. o Escudeiro nasceu")
	var unit: Unit = shieldbearers[0]
	assert_eq(unit.unit_data.unit_name, "Escudeiro")
	assert_eq(unit.owner_player, human)
	assert_eq(unit.hp, unit.unit_data.max_hp)
	assert_eq(grid.get_unit_at(unit.coord), unit, "está no mapa")
	assert_eq(city.production_item, "", "a cidade voltou a ficar ociosa")

	# 8. Move: alcance normal (mesmo pipeline de seleção/movimento do jogador).
	SelectionManager._select_unit(unit)
	assert_false(SelectionManager.reachable.is_empty(), "o Escudeiro tem pra onde ir")
	var destination := Vector2i.ZERO
	for coord in SelectionManager.reachable:
		if grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			destination = coord
			break
	assert_ne(destination, Vector2i.ZERO)
	var start := unit.coord
	SelectionManager._move_selected_to(destination)
	assert_eq(unit.coord, destination, "8. moveu")
	assert_ne(unit.coord, start)

	# 9. Ataque básico contra uma unidade de um rival em guerra, num vizinho livre.
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var target_coord := Vector2i.ZERO
	for n in grid.get_neighbors(unit.coord):
		if WorldSetup._is_valid_spawn(grid, n):
			target_coord = n
			break
	assert_ne(target_coord, Vector2i.ZERO, "pré-condição: vizinho livre pro alvo")
	var target := grid.spawn_unit(target_coord, UnitDatabase.create_unit("warrior"), rival)
	assert_not_null(target)
	unit.movement_left = unit.unit_data.movement_points
	var target_hp := target.hp
	SelectionManager._select_unit(unit)
	assert_true(target_coord in SelectionManager.attackable, "o alvo é atacável")
	SelectionManager._attack_from_selected(target_coord)
	assert_true(target.hp < target_hp or target.hp <= 0.0, "9. o ataque básico causou dano")

	# 10. Salva e carrega.
	var unit_hp := unit.hp
	var unit_coord := unit.coord
	var loaded_grid := _save_and_reload()
	var loaded_human := GameManager.human_player

	# 11. Pesquisas, Salão e unidade voltaram.
	assert_not_same(loaded_human, human, "o jogador carregado é outro objeto")
	assert_eq(loaded_human.v2_research.get_completed_ids(), ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2", "v2_doctrine_guardian_3"])
	assert_eq(V2UnlockSystem.unlocked_ids(loaded_human), ["v2_doctrine_guardian", "v2_building_guardian_hall", "v2_unit_shieldbearer"])
	assert_eq(loaded_human.cities.size(), 1)
	var loaded_city: City = loaded_human.cities[0]
	assert_true(loaded_city.buildings.has(HALL), "o Salão foi restaurado")
	assert_eq(loaded_city.building_coords.get(HALL), hall_coord)
	assert_true(loaded_grid.buildings_by_coord.has(hall_coord), "e existe no mapa carregado")
	var loaded_units := _units_of_kind(loaded_human, KIND)
	assert_eq(loaded_units.size(), 1, "o Escudeiro foi restaurado")
	assert_eq(loaded_units[0].unit_data.unit_name, "Escudeiro")
	assert_eq(loaded_units[0].coord, unit_coord)
	assert_almost_eq(loaded_units[0].hp, unit_hp, 0.001)

	# 12. A cidade carregada ainda pode produzir outro Escudeiro.
	assert_true(loaded_city.can_train(KIND))
	assert_true(_train_through_normal_pipeline(loaded_city, KIND), "produção aceita depois do load")
	assert_eq(_units_of_kind(loaded_human, KIND).size(), 2, "12. o segundo Escudeiro nasceu")

func test_after_a_new_game_nothing_v2_is_unlocked_and_no_building_or_unit_leaks():
	var grid := _new_game()
	var city := _found_human_city(grid)
	assert_eq(V2UnlockSystem.unlocked_ids(GameManager.human_player), [])
	for player in GameManager.players:
		assert_true(player.v2_research.completed_ids.is_empty())
	assert_false(city.can_build(HALL))
	assert_false(city.can_train(KIND))

func test_ai_civilizations_keep_playing_without_ever_using_v2_content():
	var grid := _new_game()
	for i in 8:
		_end_turn()
	for rival in GameManager.rival_players:
		for city in rival.cities:
			assert_false(city.buildings.has(HALL), "a IA não constrói o Salão")
			assert_ne(city.production_item, HALL)
			assert_ne(city.production_item, KIND)
			assert_false(city.buildings.has(HALL) or city.can_train(KIND), "sem a pesquisa, nem o Salão nem o Escudeiro são opção de produção")
		assert_eq(_units_of_kind(rival, KIND).size(), 0, "a IA não treina Escudeiro sem a pesquisa V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "o jogo segue rodando")

func test_an_old_save_without_v2_data_loads_with_nothing_unlocked():
	var grid := _new_game()
	_found_human_city(grid)
	assert_true(SaveManager.save_game(grid, TEST_SAVE_PATH))
	# Reescreve o save como um save ANTIGO: sem o bloco v2_research em nenhum jogador.
	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var data: Dictionary = JSON.parse_string(text)
	assert_true(data.human.has("v2_research"), "pré-condição: o save novo tem o bloco")
	data.human.erase("v2_research")
	for rival_data in data.rivals:
		rival_data.erase("v2_research")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	_players_to_release.append_array(GameManager.players)
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH), "save antigo carrega")
	var human := GameManager.human_player
	assert_true(human.v2_research.completed_ids.is_empty())
	assert_eq(V2UnlockSystem.unlocked_ids(human), [])
	assert_false(human.cities[0].can_build(HALL))

func test_a_save_taken_between_n2_and_the_hall_keeps_the_hall_available_but_not_the_shieldbearer():
	var grid := _new_game()
	var city := _found_human_city(grid)
	var state := GameManager.human_player.v2_research
	_research(state, "v2_doctrine_guardian_1")
	_research(state, "v2_doctrine_guardian_2")
	assert_true(city.can_build(HALL))

	_save_and_reload()

	var loaded_city: City = GameManager.human_player.cities[0]
	assert_true(loaded_city.can_build(HALL), "o unlock é derivado do estado de pesquisa salvo")
	assert_false(loaded_city.can_train(KIND))
	assert_false(GameManager.human_player.has_unlocked(KIND))
