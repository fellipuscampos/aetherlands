extends GutTest

## V3 / Etapa 2 — Bloco A (pesquisa só depois da primeira cidade) e Bloco B (UX do Colonizador): board visível mas
## sem início antes da cidade, estado semântico "Requer uma cidade", widget "Pesquisa indisponível", nenhum Attention
## REQUIRED antes da cidade, desbloqueio imediato e sem auto-seleção ao fundar, IA sem cidade não pesquisa, save
## antes da cidade continua bloqueado; Colonizador só com Mover + Fundar Cidade, Fundar sempre visível (desabilitada
## com motivo real no tile inválido, primária no tile válido), atalho F.

const SAVE_PATH := "user://test_v3_e2_opening.json"
const MAP := 31

var _original := {}
var grid: HexGrid

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "rival_count", "map_width", "map_height", "debug_mode", "combat_ecology_on_new_match", "regional_threats_on_new_match"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	GameManager.rival_count = 1
	GameManager.map_width = MAP
	GameManager.map_height = MAP
	GameManager.combat_ecology_on_new_match = false
	GameManager.regional_threats_on_new_match = false
	grid = HexGrid.new()
	add_child(grid)
	grid.generate_map(MAP, MAP, 31031)
	GameManager.start_new_game(grid)

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	SaveManager.delete_save(SAVE_PATH)

func _human() -> PlayerData:
	return GameManager.human_player

func _settler() -> Unit:
	for unit in _human().units:
		if unit.unit_data.can_found_city:
			return unit
	return null

func _first_available(state: V2ResearchState) -> String:
	for node in V2ResearchDatabase.all_nodes():
		if state.is_available(node.id):
			return node.id
	return ""

func _found_capital() -> City:
	var settler := _settler()
	SelectionManager.select_unit(settler)
	SelectionManager.found_city_with_selected()
	return _human().cities[0] if not _human().cities.is_empty() else null

# --- Bloco A — pesquisa ---------------------------------------------------------------------------

func test_new_human_match_starts_with_research_locked_until_the_first_city():
	var human := _human()
	assert_true(human.cities.is_empty(), "partida humana nova: só o Colonizador")
	assert_eq(V2ResearchAccess.start_blocked_reason(human), V2ResearchAccess.REASON_REQUIRES_CITY)
	var board := V2ResearchBoard.new()
	add_child_autofree(board)
	board.bind_state(human.v2_research)
	var node_id := _first_available(human.v2_research)
	assert_ne(node_id, "", "a árvore continua visível e com nós disponíveis")
	assert_not_null(board.card_for(node_id))
	board.select_node(node_id)
	assert_true(board.action_disabled(), "nenhum nó iniciável antes da cidade")
	assert_eq(board.action_text(), V2ResearchAccess.STATE_LABEL_REQUIRES_CITY)
	assert_true(board.footer_text().contains(V2ResearchAccess.REASON_REQUIRES_CITY), "motivo semântico próprio, não pré-requisito")
	board.press_action()
	assert_eq(human.v2_research.active_id, "", "clique não inicia pesquisa")
	assert_eq(board._card_state_label(V2ResearchDatabase.NodeState.AVAILABLE), V2ResearchAccess.STATE_LABEL_REQUIRES_CITY)
	assert_true(board.status_text().contains("Pesquisa indisponível"))

func test_widget_and_attention_before_and_after_the_first_city():
	var human := _human()
	var widget := ResearchStatusWidget.new()
	add_child_autofree(widget)
	widget.bind_player(human)
	assert_eq(widget.name_label.text, "Pesquisa indisponível")
	assert_eq(widget.detail_label.text, "Funde sua primeira cidade.")
	assert_false(widget.attention_badge.visible, "não acusa o jogador de erro")
	var service := AttentionService.new()
	service.bind_player(human)
	assert_true(service.items().filter(func(item: AttentionItem): return item.id == "research_idle").is_empty(), "nenhum REQUIRED de pesquisa antes da cidade")
	var city := _found_capital()
	assert_not_null(city)
	assert_true(V2ResearchAccess.can_start(human), "pesquisa disponível imediatamente")
	assert_eq(human.v2_research.active_id, "", "sem auto-seleção")
	service.refresh()
	var required := service.items().filter(func(item: AttentionItem): return item.id == "research_idle")
	assert_eq(required.size(), 1)
	assert_eq((required[0] as AttentionItem).priority, AttentionItem.Priority.REQUIRED, "Attention normal de escolher pesquisa")
	widget.refresh()
	assert_eq(widget.name_label.text, "Escolher Pesquisa")
	var node_id := _first_available(human.v2_research)
	var board := V2ResearchBoard.new()
	add_child_autofree(board)
	board.bind_state(human.v2_research)
	board.select_node(node_id)
	board.press_action()
	assert_eq(human.v2_research.active_id, node_id, "board utilizável depois da cidade")

func test_ai_without_a_city_never_chooses_research_and_does_after_founding():
	var ai := _human()
	V2StrategicAI._choose_research(ai)
	assert_eq(ai.v2_research.active_id, "", "civ sem cidade não escolhe pesquisa")
	_found_capital()
	V2StrategicAI._choose_research(ai)
	assert_ne(ai.v2_research.active_id, "", "com cidade usa o sistema normal")
	var rival: PlayerData = GameManager.rival_players[0]
	assert_false(rival.cities.is_empty(), "rival já nasce com capital")
	assert_true(V2ResearchAccess.can_start(rival))

func test_losing_every_city_does_not_cancel_the_active_research_but_blocks_changes():
	var human := _human()
	var city := _found_capital()
	var node_id := _first_available(human.v2_research)
	human.v2_research.select_research(node_id)
	human.cities.erase(city)
	assert_eq(human.v2_research.active_id, node_id, "pesquisa ativa não é destruída silenciosamente")
	assert_false(V2ResearchAccess.can_start(human), "sem cidade não troca de projeto")
	human.cities.append(city)

func test_save_before_the_first_city_keeps_research_locked_after_load():
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(grid, SAVE_PATH))
	var human := _human()
	assert_true(human.cities.is_empty())
	assert_false(V2ResearchAccess.can_start(human), "continua bloqueado depois do load")
	assert_not_null(_found_capital())
	assert_true(V2ResearchAccess.can_start(human), "fundar desbloqueia")

# --- Bloco B — Colonizador ---------------------------------------------------------------------------

func _ids(views: Array) -> Array:
	return views.map(func(view): return String(view.id))

func test_settler_strip_has_only_move_and_found_city():
	var settler := _settler()
	var views := UnitPresenter.commands_for(settler, grid)
	assert_eq(_ids(views), ["move", "found_city"], "Mover + Fundar Cidade, sem Fortificar/Explorar")
	var warrior: Unit = null
	for unit in _human().units:
		if not unit.unit_data.can_found_city:
			warrior = unit
	var warrior_ids := _ids(UnitPresenter.commands_for(warrior, grid))
	assert_true("fortify" in warrior_ids and "explore" in warrior_ids, "as outras unidades mantêm as APIs")
	assert_false("found_city" in warrior_ids)

func test_found_city_is_primary_on_a_valid_tile_and_disabled_with_the_real_reason_otherwise():
	var settler := _settler()
	var found: UnitAbilityViewData = UnitPresenter.commands_for(settler, grid).filter(func(view): return view.id == "found_city")[0]
	assert_eq(CitySite.rejection_reason(grid, settler.coord, _human()), "", "tile inicial é válido")
	assert_eq(found.state, UnitAbilityViewData.State.READY)
	assert_true(found.is_primary, "ação primária semântica")
	assert_eq(found.hotkey, "F")
	var button := AECommandButton.new()
	add_child_autofree(button)
	button.configure_view(found)
	assert_eq(button.theme_type_variation, &"PrimaryButton", "estilo primário do design system")
	assert_false(button.disabled)
	# Tile inválido: colado numa cidade existente.
	var rival_city: City = GameManager.rival_players[0].cities[0]
	var invalid := HexGrid.NO_LAIR
	for coord in grid.get_neighbors(rival_city.coord):
		var tile := grid.get_tile(coord)
		if tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null:
			invalid = coord
			break
	assert_ne(invalid, HexGrid.NO_LAIR)
	grid.teleport_unit(settler, invalid)
	var reason := CitySite.rejection_reason(grid, settler.coord, _human())
	assert_ne(reason, "")
	found = UnitPresenter.commands_for(settler, grid).filter(func(view): return view.id == "found_city")[0]
	assert_eq(found.state, UnitAbilityViewData.State.BLOCKED, "continua visível, desabilitada")
	assert_eq(found.blocked_reason, CitySite.reason_text(reason), "motivo real no tooltip")
	assert_false(found.is_primary)
	button.configure_view(found)
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains(CitySite.reason_text(reason)))
	assert_ne(button.theme_type_variation, &"PrimaryButton")

func test_found_city_shortcut_founds_with_the_selected_settler():
	var settler := _settler()
	SelectionManager.select_unit(settler)
	var hud_script: GDScript = load("res://scripts/ui/HUD.gd")
	assert_true(hud_script.source_code.contains("KEY_F"), "atalho F registrado no HUD")
	SelectionManager.found_city_with_selected()
	assert_eq(_human().cities.size(), 1, "o mesmo caminho do botão funda e consome o Colonizador")
	assert_null(_settler())
	assert_true(V2ResearchAccess.can_start(_human()), "pesquisa liberada no mesmo fluxo")
