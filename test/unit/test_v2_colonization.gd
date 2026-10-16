extends GutTest

## Linha de Infraestrutura "Colonização" (2026-10-09): limite de Colonos TREINADOS na partida.
## Sem pesquisa: nenhum; N1: 1; N2: 2; N3: sem limite. O Colono inicial é grátis e não conta.

const INFRA := V2ResearchNode.TreeType.INFRASTRUCTURE
const N1 := "v2_infrastructure_colonization_1"
const N2 := "v2_infrastructure_colonization_2"
const N3 := "v2_infrastructure_colonization_3"
const TEST_SAVE_PATH := "user://test_v2_colonization_save.json"

var _players: Array[PlayerData] = []
var _grids: Array[HexGrid] = []
var _original := {}

func before_each() -> void:
	_original = {"human": GameManager.human_player, "rivals": GameManager.rival_players, "players": GameManager.players,
		"grid": GameManager.hex_grid, "debug": GameManager.debug_mode, "state": GameManager.state, "turn": TurnManager.turn_number}

func after_each() -> void:
	GameManager.human_player = _original.human
	GameManager.rival_players = _original.rivals
	GameManager.players = _original.players
	GameManager.hex_grid = _original.grid
	GameManager.debug_mode = _original.debug
	GameManager.state = _original.state
	TurnManager.turn_number = _original.turn
	for player in _players:
		player.release_relations()
	_players.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.free()
	_grids.clear()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

func _player(name: String = "Teste") -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _grid() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-2, 14):
		for r in range(-2, 3):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

## Mundo mínimo de turno real: humano com 2 cidades, rival com 1 (o fim de jogo não dispara).
func _world() -> Dictionary:
	var grid := _grid()
	var human := _player("Humano")
	var rival := _player("Rival")
	GameManager.hex_grid = grid
	GameManager.human_player = human
	GameManager.rival_players = [rival]
	GameManager.players = [human, rival]
	GameManager.state = GameManager.GameState.PLAYING
	var a := grid.found_city(Vector2i(0, 0), human, "A")
	var b := grid.found_city(Vector2i(6, 0), human, "B")
	grid.found_city(Vector2i(12, 0), rival, "R")
	return {"grid": grid, "human": human, "rival": rival, "a": a, "b": b}

func _settlers(player: PlayerData) -> int:
	return player.units.filter(func(u): return u.unit_data.can_found_city).size()

## Uma cidade do humano conclui o Colono pelo fluxo REAL de turno (GameManager, produção em 1 turno no debug).
func _complete_settler(w: Dictionary, city: City) -> void:
	city.set_production("settler")
	GameManager.debug_mode = true
	GameManager._on_turn_changed(0, 0)
	GameManager.debug_mode = false

# --- Dados --------------------------------------------------------------------------------------------------------------

func test_the_colonization_line_is_a_regular_three_level_infrastructure_line():
	var nodes := V2ResearchDatabase.nodes_for_branch(INFRA, "colonization")
	assert_eq(nodes.map(func(n): return n.id), [N1, N2, N3])
	assert_eq(nodes.map(func(n): return n.unlock_id), ["v2_settler_limit_1", "v2_settler_limit_2", "v2_settler_limit_unlimited"])
	assert_eq(nodes.map(func(n): return int(n.cost)), [16, 40, 96], "a mesma curva das outras linhas de Infraestrutura")
	for node in nodes:
		assert_eq(node.unlock_type, "settler_limit")
		assert_true(node.gameplay_connected)
		assert_false(node.is_placeholder)
		assert_eq(node.branch_role, "expansion")
	assert_true(nodes[0].prerequisites.is_empty())
	assert_eq(nodes[1].prerequisites, [N1] as Array[String])
	assert_eq(nodes[2].prerequisites, [N2] as Array[String])
	assert_eq(V2ResearchDatabase.nodes_for_tree(INFRA).size(), 21, "7 linhas x 3 níveis")
	assert_eq(V2ResearchDatabase.unlock_type_label("settler_limit"), "Limite de Colonos")
	var tooltip := V2ResearchDatabase.node_tooltip(nodes[0]).replace("\n", " ")
	assert_string_contains(tooltip, "Permite treinar até 1 Colono na partida.")
	assert_eq(V2UnlockSystem.announcement_text("settler_limit", "Expedições", "v2_settler_limit_2"), "Colonização ampliada: até 2 Colonos na partida.")
	assert_eq(V2UnlockSystem.announcement_text("settler_limit", "Expansão Territorial", "v2_settler_limit_unlimited"), "Colonização ampliada: Colonos sem limite.")

func test_the_limit_comes_from_the_highest_completed_level():
	var player := _player()
	assert_eq(V2ColonizationRuntime.settler_limit(player), 0, "sem pesquisa, nenhum Colono")
	assert_true(player.v2_research.complete_research(N1))
	assert_eq(V2ColonizationRuntime.settler_limit(player), 1)
	assert_true(player.v2_research.complete_research(N2))
	assert_eq(V2ColonizationRuntime.settler_limit(player), 2, "o maior nível, nunca somado")
	assert_true(player.v2_research.complete_research(N3))
	assert_eq(V2ColonizationRuntime.settler_limit(player), V2ColonizationData.UNLIMITED)

# --- Treino ------------------------------------------------------------------------------------------------------------

func test_without_research_no_city_can_train_a_settler_and_the_ui_explains_why():
	var w := _world()
	assert_false(w.a.can_train("settler"))
	var reason := V2ColonizationRuntime.training_soft_reason(w.human, w.a, "settler")
	assert_eq(reason, "Requer pesquisa: Expedições (linha de Colonização).")
	var item := CityPresenter.unit_item(w.a, "settler")
	assert_false(item.is_empty(), "o Colono aparece desabilitado, explicando, em vez de sumir")
	assert_eq(V2ColonizationRuntime.training_soft_reason(w.human, w.a, "v2_unit_warrior"), "", "só o Colono é afetado")

func test_level_1_allows_exactly_one_settler_in_the_whole_match():
	var w := _world()
	w.human.v2_research.complete_research(N1)
	assert_true(w.a.can_train("settler"))
	w.a.set_production("settler")
	assert_false(w.b.can_train("settler"), "a produção da outra cidade já reserva o único Colono")
	assert_string_contains(V2ColonizationRuntime.training_soft_reason(w.human, w.b, "settler"), "Limite de Colonos atingido (1/1). Pesquise Colônias")
	assert_true(w.a.can_train("settler"), "a cidade que já produz não conta contra si mesma")
	GameManager.debug_mode = true
	GameManager._on_turn_changed(0, 0)
	GameManager.debug_mode = false
	assert_eq(_settlers(w.human), 1)
	assert_eq(w.human.settlers_trained, 1)
	assert_false(w.a.can_train("settler"), "o limite é da partida: o Colono treinado continua contando")
	assert_false(w.b.can_train("settler"))

func test_level_2_allows_a_second_settler_and_level_3_removes_the_limit():
	var w := _world()
	w.human.v2_research.complete_research(N1)
	_complete_settler(w, w.a)
	assert_false(w.a.can_train("settler"))
	w.human.v2_research.complete_research(N2)
	assert_true(w.a.can_train("settler"), "N2: um segundo Colono")
	_complete_settler(w, w.a)
	assert_eq(w.human.settlers_trained, 2)
	assert_false(w.b.can_train("settler"))
	w.human.v2_research.complete_research(N3)
	for i in 3:
		assert_true(w.b.can_train("settler"), "N3: sem limite")
		_complete_settler(w, w.b)
	assert_eq(w.human.settlers_trained, 5)

func test_founding_or_losing_a_settler_never_gives_the_slot_back():
	var w := _world()
	w.human.v2_research.complete_research(N1)
	_complete_settler(w, w.a)
	var settler: Unit = w.human.units.filter(func(u): return u.unit_data.can_found_city)[0]
	w.grid.remove_unit(settler)
	assert_eq(w.human.settlers_trained, 1)
	assert_false(w.a.can_train("settler"), "o limite conta Colonos TREINADOS, não vivos")

func test_the_starting_settler_is_free():
	var w := _world()
	w.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("settler"), w.human)
	assert_eq(w.human.settlers_trained, 0, "nascer fora de produção (Colono inicial) não conta")

func test_completion_is_fail_closed_and_refunds_the_production():
	var w := _world()
	w.a.set_production("settler") # enfileirado sem passar pela checagem (ex.: save editado)
	var cost := UnitDatabase.create_unit("settler").production_cost
	GameManager.debug_mode = true
	GameManager._on_turn_changed(0, 0)
	GameManager.debug_mode = false
	assert_eq(_settlers(w.human), 0, "sem a pesquisa, nenhum Colono nasce")
	assert_eq(w.human.settlers_trained, 0)
	assert_gte(w.a.stored_production, cost, "o custo pago volta para a cidade (mais a produção do turno)")
	assert_false(V2ColonizationRuntime.spawn_allowed(w.human, "settler"))
	assert_true(V2ColonizationRuntime.spawn_allowed(w.human, "v2_unit_warrior"))

func test_a_captured_city_producing_a_settler_is_revalidated_for_the_new_owner():
	var w := _world()
	w.human.v2_research.complete_research(N1)
	w.b.set_production("settler")
	assert_eq(w.b.production_eligibility_reason(), "")
	w.grid.capture_city(w.b, w.rival)
	assert_eq(w.b.production_item, "", "o rival não pesquisou a Colonização: a fila não continua")

# --- Save ---------------------------------------------------------------------------------------------------------------

func test_the_trained_counter_survives_save_and_load_and_old_saves_start_at_zero():
	var w := _world()
	w.human.v2_research.complete_research(N1)
	_complete_settler(w, w.a)
	assert_true(SaveManager.save_game(w.grid, TEST_SAVE_PATH))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	assert_eq(int(data.human.settlers_trained), 1)
	var loaded := HexGrid.new()
	loaded._ready()
	_grids.append(loaded)
	_players.append_array(GameManager.players)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH))
	_players.append_array(GameManager.players)
	assert_eq(GameManager.human_player.settlers_trained, 1)
	var loaded_city: City = GameManager.human_player.cities[0]
	assert_false(loaded_city.can_train("settler"), "o limite continua atingido depois do load")
	# Save anterior à linha: sem o campo -> 0.
	data.human.erase("settlers_trained")
	var old := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	old.store_string(JSON.stringify(data))
	old.close()
	var older := HexGrid.new()
	older._ready()
	_grids.append(older)
	assert_true(SaveManager.load_game(older, TEST_SAVE_PATH))
	_players.append_array(GameManager.players)
	assert_eq(GameManager.human_player.settlers_trained, 0)

# --- IA -----------------------------------------------------------------------------------------------------------------

func test_the_ai_values_colonization_research_only_when_the_limit_blocks_its_expansion():
	var w := _world()
	var rival: PlayerData = w.rival
	TurnManager.turn_number = 1
	assert_false(V2StrategicAI.wants_more_cities(rival), "turno 1: a meta é a capital")
	var calm := V2StrategicAI._economic_urgency(rival, "expansion")
	TurnManager.turn_number = 30 - V2AITuning.EXPANSION_RESEARCH_LEAD_TURNS + 2
	assert_false(V2StrategicAI.wants_more_cities(rival), "a meta ainda não pede a segunda cidade...")
	assert_eq(V2StrategicAI._economic_urgency(rival, "expansion"), V2AITuning.EXPANSION_RESEARCH_URGENCY, "...mas a pesquisa já é urgente: antecedência para o Colono sair no turno 30")
	TurnManager.turn_number = 40
	assert_true(V2StrategicAI.wants_more_cities(rival))
	var urgent := V2StrategicAI._economic_urgency(rival, "expansion")
	assert_eq(urgent, V2AITuning.EXPANSION_RESEARCH_URGENCY, "quer expandir e o limite (0) barra o Colono")
	assert_lt(calm, urgent)
	var n1 := V2ResearchDatabase.get_node(N1)
	var market := V2ResearchDatabase.get_node("v2_infrastructure_economy_2")
	assert_gt(V2StrategicAI.research_score(rival, n1), V2StrategicAI.research_score(rival, market), "a expansão bloqueada passa à frente de uma melhoria econômica comum")
	rival.v2_research.complete_research(N1)
	assert_lt(V2StrategicAI._economic_urgency(rival, "expansion"), 0.0, "com Colono disponível, nada a pesquisar ainda")
