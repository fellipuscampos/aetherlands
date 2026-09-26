extends GutTest

## Fluxo REAL do runtime de pesquisa V2 (Fase 1), de ponta a ponta, incluindo
## salvar/carregar pelo SaveManager: seleção -> Conhecimento -> conclusão -> troca
## entre árvores -> progresso preservado -> save/load -> continuar -> capstone.
## Fase 1: sem efeito de gameplay V1 — só o estado de pesquisa muda. (O fluxo de
## unlock REAL da Doutrina do Guardião N1-N3 é testado em test_v2_guardian_flow.gd.)

const TEST_SAVE_PATH := "user://test_v2_integration_savegame.json"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _created_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []

var _original_players: Array[PlayerData]
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

func before_each():
	_original_players = GameManager.players
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
	GameManager.players = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(7, 7, 12345)
	_created_grids.append(hex_grid)
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	_players_to_release = [human, rival]
	Diplomacy.declare_war(human, rival)
	GameManager.human_player = human
	GameManager.rival_players = [rival]
	var coords := hex_grid.tiles.keys()
	_spawn("warrior", human, coords[0])
	_spawn("warrior", rival, coords[1]) # pra check_game_over não encerrar a partida no load

func after_each():
	for player in GameManager.players:
		player.release_relations()
	for player in _players_to_release:
		player.release_relations()
	GameManager.players = _original_players
	SaveManager.delete_save(TEST_SAVE_PATH)
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for grid in _created_grids:
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

func _spawn(kind: String, player: PlayerData, coord: Vector2i) -> void:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)

## O que a V1 libera hoje pra esta civilização (has_unlocked é fail-open pra tipos
## sem tech, então só vale COMPARAR antes/depois, não afirmar false).
func _v1_unlock_snapshot() -> Dictionary:
	var snapshot := {}
	for kind in ["warrior", "archer", "mage", "catapult", "knight", "guard"]:
		snapshot[kind] = human.has_unlocked(kind)
	return snapshot

func _save_and_reload() -> V2ResearchState:
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH), "save_game")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH), "load_game")
	_players_to_release.append(GameManager.human_player)
	_players_to_release.append_array(GameManager.rival_players)
	return GameManager.human_player.v2_research

func test_full_research_flow_with_save_and_load():
	var state := human.v2_research
	var guardian_1_cost := V2ResearchDatabase.get_node("v2_doctrine_guardian_1").cost
	var guardian_2_cost := V2ResearchDatabase.get_node("v2_doctrine_guardian_2").cost
	var sacred_1_cost := V2ResearchDatabase.get_node("v2_magic_sacred_1").cost
	var guardian_2_partial := guardian_2_cost * 0.4
	var completed_in_order: Array[String] = []
	state.research_completed.connect(func(id): completed_in_order.append(id))
	assert_true(state.completed_ids.is_empty(), "1. estado V2 vazio")
	assert_eq(state.active_id, "")

	# 2-4. Guardião I: seleciona, paga e conclui.
	assert_true(state.select_research("v2_doctrine_guardian_1"))
	state.add_knowledge(guardian_1_cost)
	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_eq(state.active_id, "", "nada é escolhido sozinho")

	# 5-6. Guardião II com progresso parcial.
	assert_true(state.select_research("v2_doctrine_guardian_2"))
	state.add_knowledge(guardian_2_partial)
	assert_almost_eq(state.get_progress_ratio("v2_doctrine_guardian_2"), 0.4, 0.001)

	# 7-8. Troca pra outra ÁRVORE (Magia): Sagrada I, e avança.
	assert_true(state.select_research("v2_magic_sacred_1"))
	assert_eq(state.active_id, "v2_magic_sacred_1", "um único projeto ativo")
	state.add_knowledge(sacred_1_cost)
	assert_true(state.is_completed("v2_magic_sacred_1"))

	# 9-10. Volta pro Guardião II: o progresso estava guardado.
	assert_true(state.select_research("v2_doctrine_guardian_2"))
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_2"), guardian_2_partial, 0.001, "preservado entre árvores")

	# 11-13. Salva, carrega e confere.
	var loaded := _save_and_reload()
	assert_not_same(loaded, state, "o jogador carregado é outro objeto")
	assert_eq(loaded.active_id, "v2_doctrine_guardian_2")
	assert_eq(loaded.get_completed_ids(), ["v2_doctrine_guardian_1", "v2_magic_sacred_1"])
	assert_almost_eq(loaded.get_progress("v2_doctrine_guardian_2"), guardian_2_partial, 0.001)

	# 14. Continua a pesquisa exatamente de onde parou.
	var after_load: Array[String] = []
	loaded.research_completed.connect(func(id): after_load.append(id))
	loaded.add_knowledge(guardian_2_cost - guardian_2_partial)
	assert_true(loaded.is_completed("v2_doctrine_guardian_2"), "o progresso parcial mais o restante conclui o nó")
	assert_eq(after_load, ["v2_doctrine_guardian_2"])

	# 15-17. Completa duas linhas (modo de teste) e o capstone abre.
	assert_false(loaded.is_available("v2_supreme_army"))
	loaded.debug_complete_branch(MILITARY, "guardian")
	assert_false(loaded.is_available("v2_supreme_army"), "uma Doutrina só")
	loaded.debug_complete_branch(MILITARY, "warrior")
	assert_true(loaded.is_available("v2_supreme_army"), "duas Doutrinas até o N9")
	assert_eq(completed_in_order, ["v2_doctrine_guardian_1", "v2_magic_sacred_1"], "o estado antigo não recebeu eventos do novo")

func test_the_flow_grants_no_v1_gameplay_unlock_of_any_kind():
	var state := human.v2_research
	var units_before := human.units.size()
	var gold_before := human.gold
	var mana_before := human.mana
	var v1_unlocks_before := _v1_unlock_snapshot()
	state.debug_complete_branch(MILITARY, "guardian")
	state.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	state.add_knowledge(50.0)

	assert_eq(human.units.size(), units_before)
	assert_eq(human.gold, gold_before)
	assert_eq(human.mana, mana_before)
	assert_false("researched_techs" in human, "Fase 25: estado V1 removido")
	assert_false("researched_magic" in human, "Fase 25: estado V1 removido")
	assert_false("current_research" in human, "Fase 25: estado V1 removido")
	assert_eq(_v1_unlock_snapshot(), v1_unlocks_before, "unlock_type é só metadata: nada mudou no que a V1 libera")

func test_capstone_availability_and_overflow_survive_the_round_trip():
	var state := human.v2_research
	state.debug_complete_branch(MILITARY, "cavalry")
	state.debug_complete_branch(MILITARY, "siege")
	state.add_knowledge(33.0) # sem projeto ativo: guardado

	var loaded := _save_and_reload()

	assert_true(loaded.is_available("v2_supreme_army"))
	assert_true(loaded.select_research("v2_supreme_army"))
	assert_almost_eq(loaded.get_progress("v2_supreme_army"), 33.0, 0.001, "o Conhecimento guardado paga o capstone")
	assert_almost_eq(loaded.research_overflow, 0.0, 0.001)

func test_each_civilization_keeps_its_own_state_through_the_round_trip():
	human.v2_research.select_research("v2_doctrine_guardian_1")
	human.v2_research.add_knowledge(4.0)
	rival.v2_research.select_research("v2_magic_infernal_1")
	rival.v2_research.add_knowledge(6.0)

	_save_and_reload()

	assert_eq(GameManager.human_player.v2_research.active_id, "v2_doctrine_guardian_1")
	assert_eq(GameManager.rival_players[0].v2_research.active_id, "v2_magic_infernal_1")
	assert_almost_eq(GameManager.human_player.v2_research.get_progress("v2_magic_infernal_1"), 0.0, 0.001)
	assert_almost_eq(GameManager.rival_players[0].v2_research.get_progress("v2_magic_infernal_1"), 6.0, 0.001)
