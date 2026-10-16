extends GutTest

## Construir um prédio em cima de um recurso de mapa (2026-10-12) — pedido do usuário: "se tiver algum recurso de
## mapa, e eu construir algo em cima, deve aparecer um modal, falando que construir um prédio ali destruirá o
## recurso, e se a pessoa aceitar o prédio começa a ser construído e o recurso daquele tile some".
## Cobre a regra (HexGrid.destroy_resource_at / City.start_building), o fluxo do jogador (SelectionManager +
## BuildingSiteConfirmPresenter com a HUD real) e a preferência da IA por tiles sem recurso.

const HALL := "v2_building_guardian_hall"
const IRON_MINE := "v2_improvement_iron_mine"

var hud: Control
var shell: UIShell
var grid: HexGrid
var player: PlayerData
var rival: PlayerData
var city: City
var iron: Vector2i
var plain: Vector2i
var _original := {}

func before_each():
	for key in ["hex_grid", "human_player", "players", "rival_players", "state"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
				grid.visibility[Vector2i(q, r)] = HexGrid.Visibility.VISIBLE
	player = PlayerData.new(CivilizationData.new())
	player.civ.civ_name = "Aurora"
	rival = PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Crepúsculo"
	GameManager.players = [player, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 5
	player.gold = 300.0
	player.v2_research.complete_research("v2_doctrine_guardian_2") # libera o Salão dos Guardiões
	city = grid.found_city(Vector2i.ZERO, player, "Capital", true)
	iron = HexGrid.NEIGHBOR_DIRS[0]
	plain = HexGrid.NEIGHBOR_DIRS[1]
	grid.get_tile(iron).resource = "iron"
	hud = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	shell = hud.ui_shell

func after_each():
	SelectionManager.reset()
	shell.modal_manager.clear()
	for key in ["hex_grid", "human_player", "players", "rival_players", "state"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	for someone in [player, rival]:
		someone.release_relations()
	grid.queue_free()

func _improve_iron() -> void:
	city.resource_improvements[iron] = IRON_MINE
	grid.refresh_resource_improvement_marker(iron)

func _click(coord: Vector2i) -> void:
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(coord.x, coord.y, grid.hex_size))

func _modal() -> AEModalFrame:
	return shell.building_site_confirm.current_modal()

func _modal_text() -> String:
	var parts: Array[String] = [_modal().title_label.text]
	for label: Label in _modal().find_children("*", "Label", true, false):
		parts.append(label.text)
	for button: Button in _modal().find_children("*", "Button", true, false):
		parts.append(button.text)
	return "\n".join(parts)

# --- Regra ------------------------------------------------------------------------------------------

func test_destroying_a_resource_removes_it_and_everything_that_depended_on_it():
	_improve_iron()
	grid.pillage_tile(iron, TurnManager.turn_number, 5)
	var income_before := V2EconomyRuntime.city_production_income(city)

	assert_eq(grid.destroy_resource_at(iron), "iron", "devolve o recurso destruído")

	assert_eq(grid.get_tile(iron).resource, "", "o recurso some do tile")
	assert_eq(grid.destroyed_resources.get(iron), "iron", "registrado para o save")
	assert_false(city.resource_improvements.has(iron), "a melhoria vai junto")
	assert_false(grid.improvement_markers_by_coord.has(iron), "e o marcador dela também")
	assert_false(grid.is_tile_pillaged(iron, TurnManager.turn_number), "pilhagem de uma melhoria que não existe mais")
	assert_true(V2EconomyRuntime.city_production_income(city) <= income_before, "nenhum rendimento fantasma")
	assert_eq(grid.destroy_resource_at(iron), "", "idempotente: não há mais o que destruir")
	assert_eq(grid.destroy_resource_at(plain), "", "tile sem recurso: nada acontece")
	assert_false(grid.destroyed_resources.has(plain))

func test_a_standing_building_never_keeps_a_resource_under_it():
	grid.place_building(iron, HALL, player) # obra iniciada por um caminho que não passou por start_building
	assert_eq(grid.get_tile(iron).resource, "")
	assert_true(grid.destroyed_resources.has(iron))

func test_building_site_loss_reports_the_resource_and_its_improvement():
	assert_eq(city.building_site_loss(plain, grid), {}, "tile comum: nada a perder")
	assert_eq(city.building_site_loss(iron, grid), {"resource": "iron", "improvement": ""})
	_improve_iron()
	assert_eq(city.building_site_loss(iron, grid), {"resource": "iron", "improvement": IRON_MINE})

func test_start_building_destroys_the_resource_when_the_work_begins():
	assert_eq(city.start_building(HALL, iron, grid), "iron")
	assert_eq(city.production_item, HALL)
	assert_eq(city.pending_building_coord, iron)
	assert_eq(grid.get_tile(iron).resource, "", "some ao INICIAR a obra, não só ao concluir")
	city.set_production("") # obra cancelada
	assert_eq(grid.get_tile(iron).resource, "", "cancelar a obra não devolve o recurso")

# --- Fluxo do jogador ---------------------------------------------------------------------------------

func test_a_plain_tile_starts_the_building_without_any_modal():
	SelectionManager.start_building_placement(city, HALL)
	_click(plain)
	assert_null(_modal())
	assert_eq(city.production_item, HALL)
	assert_eq(city.pending_building_coord, plain)
	assert_eq(grid.get_tile(iron).resource, "iron", "o recurso do vizinho não é tocado")

func test_a_resource_tile_opens_the_warning_and_changes_nothing_until_answered():
	_improve_iron()
	SelectionManager.start_building_placement(city, HALL)
	assert_true(iron in SelectionManager.placeable_coords, "tile com recurso continua sendo um destino válido")
	_click(iron)

	assert_not_null(_modal(), "o aviso abre")
	assert_true(shell.modal_manager.is_modal_open())
	var text := _modal_text()
	assert_string_contains(text, "Ferro")
	assert_string_contains(text, "Salão dos Guardiões")
	assert_string_contains(text, "destrói")
	assert_string_contains(text, "Mina de Ferro", "a melhoria que se perde aparece, com o rendimento")
	assert_string_contains(text, "Produção")
	assert_eq(city.production_item, "", "nada começa antes da resposta")
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	assert_eq(grid.get_tile(iron).resource, "iron")
	assert_true(city.resource_improvements.has(iron))
	assert_false(grid._construction_markers.has(iron))
	assert_eq(SelectionManager.placing_city, city, "o posicionamento continua ativo")
	assert_eq(SelectionManager.placement_confirmation_coord, iron)

func test_accepting_starts_the_building_and_the_resource_disappears():
	_improve_iron()
	watch_signals(EventBus)
	SelectionManager.start_building_placement(city, HALL)
	_click(iron)
	_modal().find_child("ConfirmButton", true, false).pressed.emit()

	assert_false(shell.modal_manager.is_modal_open())
	assert_eq(city.production_item, HALL, "a obra começa")
	assert_eq(city.pending_building_coord, iron)
	assert_true(grid._construction_markers.has(iron), "canteiro no tile")
	assert_eq(grid.get_tile(iron).resource, "", "o recurso some")
	assert_false(city.resource_improvements.has(iron), "a melhoria some junto")
	assert_null(SelectionManager.placing_city, "o posicionamento termina")
	assert_eq(SelectionManager.placement_confirmation_coord, City.NO_PENDING_COORD)
	var notified := false
	for index in get_signal_emit_count(EventBus, "notify"):
		notified = notified or String(get_signal_parameters(EventBus, "notify", index)[0]).contains("Ferro destruído")
	assert_true(notified, "a notificação da obra diz o que foi destruído")

func test_declining_keeps_the_resource_and_goes_back_to_choosing_a_tile():
	SelectionManager.start_building_placement(city, HALL)
	var options := SelectionManager.placeable_coords.duplicate()
	_click(iron)
	_modal().find_child("CancelButton", true, false).pressed.emit()

	assert_false(shell.modal_manager.is_modal_open())
	assert_eq(grid.get_tile(iron).resource, "iron", "nada é destruído")
	assert_eq(city.production_item, "", "nada é gasto")
	assert_eq(SelectionManager.placing_city, city, "continua escolhendo o tile")
	assert_eq(SelectionManager.placeable_coords, options)
	assert_eq(SelectionManager.placement_confirmation_coord, City.NO_PENDING_COORD)
	_click(plain)
	assert_eq(city.pending_building_coord, plain, "e pode construir em outro tile")
	assert_eq(grid.get_tile(iron).resource, "iron")

func test_escape_and_the_close_button_count_as_declining():
	SelectionManager.start_building_placement(city, HALL)
	_click(iron)
	shell.modal_manager.handle_escape()
	assert_null(_modal(), "ESC fecha o aviso")
	assert_eq(grid.get_tile(iron).resource, "iron")
	assert_eq(SelectionManager.placing_city, city)
	assert_eq(SelectionManager.placement_confirmation_coord, City.NO_PENDING_COORD)

	_click(iron)
	assert_not_null(_modal(), "o aviso reabre a cada tentativa")
	_modal().close_button.pressed.emit()
	assert_null(_modal())
	assert_eq(grid.get_tile(iron).resource, "iron")
	assert_eq(city.production_item, "")

func test_cancelling_the_placement_drops_a_pending_confirmation():
	SelectionManager.start_building_placement(city, HALL)
	_click(iron)
	SelectionManager.cancel_building_placement()
	assert_false(SelectionManager.confirm_building_placement(), "sem posicionamento não há o que confirmar")
	assert_eq(grid.get_tile(iron).resource, "iron")
	assert_eq(city.production_item, "")

func test_hover_warns_before_the_click():
	SelectionManager.start_building_placement(city, HALL)
	SelectionManager.handle_world_hover(HexMetrics.axial_to_world(iron.x, iron.y, grid.hex_size))
	assert_string_contains(grid._hover_label.text, "destrói Ferro")
	SelectionManager.handle_world_hover(HexMetrics.axial_to_world(plain.x, plain.y, grid.hex_size))
	assert_false(grid._hover_label.text.contains("destrói"), "tile comum: rótulo normal")

# --- IA -------------------------------------------------------------------------------------------------

func test_ai_only_builds_over_a_resource_when_no_other_tile_is_left():
	var free_choice := V2StrategicAI._building_site(city, grid)
	grid.get_tile(free_choice).resource = "gems"
	var second := V2StrategicAI._building_site(city, grid)
	assert_ne(second, free_choice, "com outro tile disponível a IA preserva o recurso")
	assert_eq(grid.get_tile(second).resource, "")
	for coord in city.owned_tiles:
		if coord != city.coord and grid.get_tile(coord).resource == "":
			grid.get_tile(coord).resource = "silk"
	var forced := V2StrategicAI._building_site(city, grid)
	assert_ne(forced, City.NO_PENDING_COORD, "só restam tiles com recurso: a IA ainda constrói")
	city.start_building(HALL, forced, grid)
	assert_eq(grid.get_tile(forced).resource, "", "e a regra é a mesma do jogador: o recurso é destruído")
