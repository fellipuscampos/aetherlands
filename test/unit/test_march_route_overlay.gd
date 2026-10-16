extends GutTest

## ROTA DE MARCHA VISÍVEL (2026-10-13) — pedido do usuário: "às vezes selecionamos uma rota pra um personagem porém a
## gente esquece pra onde ele tá indo; quero que deixe a rota do personagem visível até que ele chegue no ponto de
## destino; a rota só deve ser visível pro dono da tropa". MarchRouteOverlay desenha a rota de toda unidade do jogador
## com ordem de marcha pendente (Unit.move_order_target). (O MultiMesh não devolve instâncias em headless: os testes
## conferem o que a camada registrou — routes()/dot_count()/goal_count().)

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var routes: MarchRouteOverlay
var _original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-14, 15):
		for r in range(-6, 7):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora")
	rival = _player("Crepúsculo")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 10
	routes = grid.march_routes

func after_each():
	SelectionManager.reset()
	for player in [human, rival]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _player(civ_name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	return PlayerData.new(civ)

func _unit(coord: Vector2i, owner: PlayerData) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), owner)

const START := Vector2i(-10, 0)
const FAR := Vector2i(8, 0)

# --- A rota aparece e acompanha a marcha ---------------------------------------------------------------------------------------

func test_a_unit_without_a_march_order_has_no_route():
	var idle := _unit(START, human)
	routes.refresh_now()
	assert_true(routes.routes().is_empty())
	assert_true(routes.route_of(idle).is_empty())
	assert_eq(routes.dot_count(), 0)
	assert_eq(routes.goal_count(), 0)

func test_a_march_order_draws_the_whole_planned_route_to_the_destination():
	var marcher := _unit(START, human)

	marcher.move_order_target = FAR
	routes.refresh_now()

	var route := routes.route_of(marcher)
	assert_eq(route, Array(grid.unit_path(marcher, FAR)), "é a rota que a unidade vai andar de fato")
	assert_eq(route.size(), HexMetrics.axial_distance(START, FAR))
	assert_eq(route.back(), FAR, "termina no destino")
	assert_false(START in route, "o tile da própria unidade não entra na trilha")
	assert_eq(routes.goal_count(), 1, "um anel no destino")
	assert_eq(routes.dot_count(), route.size() - 1, "uma marca por tile do caminho (o destino leva o anel)")

func test_the_route_shrinks_as_the_unit_advances_and_disappears_on_arrival():
	var marcher := _unit(START, human)
	marcher.move_order_target = FAR
	routes.refresh_now()
	var full := routes.route_of(marcher).size()

	grid.continue_move_order(marcher) # anda o que o movimento do turno permite
	routes.refresh_now()

	assert_ne(marcher.coord, START, "pré-condição: andou")
	assert_ne(marcher.coord, FAR, "pré-condição: ainda não chegou")
	var remaining := routes.route_of(marcher)
	assert_lt(remaining.size(), full, "a parte já percorrida some")
	assert_eq(remaining.size(), HexMetrics.axial_distance(marcher.coord, FAR))
	assert_eq(remaining.back(), FAR, "o destino continua marcado até a chegada")

	for turn in 20:
		if marcher.move_order_target == Unit.NO_MOVE_ORDER:
			break
		TurnManager.turn_number += 1
		marcher.reset_movement()
		grid.continue_move_order(marcher)
	routes.refresh_now()

	assert_eq(marcher.coord, FAR, "pré-condição: chegou")
	assert_true(routes.route_of(marcher).is_empty(), "chegou: a rota some")
	assert_eq(routes.dot_count() + routes.goal_count(), 0)

func test_cancelling_the_order_removes_the_route():
	var marcher := _unit(START, human)
	marcher.move_order_target = FAR
	routes.refresh_now()
	assert_false(routes.route_of(marcher).is_empty())

	marcher.move_order_target = Unit.NO_MOVE_ORDER
	routes.refresh_now()

	assert_true(routes.routes().is_empty())
	assert_eq(routes.goal_count(), 0)

func test_a_real_march_order_from_the_player_is_drawn_without_anyone_asking():
	var marcher := _unit(START, human)
	watch_signals(EventBus)

	assert_true(SelectionManager._try_queue_move_order(marcher, FAR), "pré-condição: a ordem de marcha foi aceita")
	await wait_process_frames(2)

	assert_signal_emitted(EventBus, "unit_move_order_changed")
	assert_eq(marcher.move_order_target, FAR)
	assert_false(routes.route_of(marcher).is_empty(), "a trilha aparece sozinha, pelo sinal")
	assert_eq(routes.route_of(marcher).back(), FAR)
	assert_eq(routes.route_of(marcher).size(), HexMetrics.axial_distance(marcher.coord, FAR), "já descontado o que ela andou neste turno")

func test_a_removed_unit_takes_its_route_with_it():
	var marcher := _unit(START, human)
	marcher.move_order_target = FAR
	routes.refresh_now()
	grid.remove_unit(marcher)
	await wait_process_frames(2)
	assert_true(routes.routes().is_empty())
	assert_eq(routes.dot_count() + routes.goal_count(), 0)

func test_a_blocked_destination_still_shows_where_the_unit_is_headed():
	var marcher := _unit(START, human)
	_unit(FAR, human) # o destino está ocupado agora: não há caminho neste instante
	marcher.move_order_target = FAR
	routes.refresh_now()
	assert_true(grid.unit_path(marcher, FAR).is_empty(), "pré-condição: sem caminho")
	assert_eq(routes.route_of(marcher), [FAR], "o destino continua marcado")
	assert_eq(routes.goal_count(), 1)
	assert_eq(routes.dot_count(), 0)

func test_every_marching_unit_of_the_player_has_its_own_route():
	var first := _unit(START, human)
	var second := _unit(Vector2i(-10, 4), human)
	first.move_order_target = FAR
	second.move_order_target = Vector2i(6, 4)
	routes.refresh_now()
	assert_eq(routes.routes().size(), 2)
	assert_eq(routes.goal_count(), 2)
	assert_eq(routes.dot_count(), routes.route_of(first).size() + routes.route_of(second).size() - 2)

# --- Só o dono vê --------------------------------------------------------------------------------------------------------------

func test_another_civilization_orders_are_never_drawn():
	var mine := _unit(START, human)
	var theirs := _unit(Vector2i(-10, 4), rival)
	mine.move_order_target = FAR
	theirs.move_order_target = Vector2i(6, 4)

	routes.refresh_now()

	assert_eq(routes.viewer(), human)
	assert_false(routes.route_of(mine).is_empty())
	assert_true(routes.route_of(theirs).is_empty(), "a rota de outra civilização não aparece")
	assert_eq(routes.routes().size(), 1)
	assert_eq(routes.goal_count(), 1)

func test_nothing_is_drawn_when_no_person_plays_the_seat():
	var marcher := _unit(START, human)
	marcher.move_order_target = FAR
	GameManager.ai_controls_human_seat = true # laboratório 4-IA: ninguém para ver
	routes.refresh_now()
	assert_null(routes.viewer())
	assert_true(routes.routes().is_empty())
	assert_eq(routes.dot_count() + routes.goal_count(), 0)

# --- Custo e posição ---------------------------------------------------------------------------------------------------------

func test_the_plan_is_reused_until_the_unit_moves_the_destination_changes_or_the_turn_passes():
	var marcher := _unit(START, human)
	marcher.move_order_target = FAR
	var plan := routes.planned_path(marcher)
	assert_same(routes.planned_path(marcher), plan, "mesma posição, destino e turno: o mesmo plano, sem outro A*")
	TurnManager.turn_number += 1
	assert_not_same(routes.planned_path(marcher), plan, "turno novo: replaneja (o mundo pode ter mudado)")
	var replanned := routes.planned_path(marcher)
	marcher.move_order_target = Vector2i(6, 3)
	assert_not_same(routes.planned_path(marcher), replanned, "destino novo: plano novo")
	assert_eq(routes.planned_path(marcher).back(), Vector2i(6, 3))

func test_marks_sit_just_above_the_ground_and_never_run_per_frame():
	var coord := Vector2i(2, 0)
	var expected := grid.world_surface_for_coord(coord) + Vector3(0.0, MarchRouteOverlay.LIFT, 0.0)
	assert_almost_eq(routes._mark_position(coord).y, expected.y, 0.0001)
	assert_almost_eq(routes._mark_position(coord).x, expected.x, 0.0001)
	assert_false(FileAccess.get_file_as_string("res://scripts/world/MarchRouteOverlay.gd").contains("func _process"), "orientada a evento, sem custo por quadro")
