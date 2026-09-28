extends GutTest

## Fase 30 / UI-3 — telas estratégicas: Império (Visão geral, Cidades, Unidades),
## Diplomacia (estados públicos, confirmação de guerra, deep link), Vitória
## (Summary/Detail com V2VictoryConditions, rival só público), Research Board
## responsivo e o contrato de navegação (exclusividade, ESC, foco, Space, save).

const SHIELDBEARER := "v2_unit_shieldbearer"
const CLERIC := "v2_unit_sacred_cleric"
const SKELETON := "v2_unit_skeleton_host"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"

var hud: Control
var shell: UIShell
var grid: HexGrid
var player: PlayerData
var rival: PlayerData
var third: PlayerData
var _original_grid: HexGrid
var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]
var _original_turn: int
var _original_state

func before_each():
	_original_grid = GameManager.hex_grid
	_original_human = GameManager.human_player
	_original_players = GameManager.players
	_original_rivals = GameManager.rival_players
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
				grid.visibility[Vector2i(q, r)] = HexGrid.Visibility.VISIBLE
	player = PlayerData.new(CivilizationData.new())
	player.civ.civ_name = "Aurora"
	rival = PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Crepúsculo"
	third = PlayerData.new(CivilizationData.new())
	third.civ.civ_name = "Maré"
	GameManager.players = [player, rival, third] as Array[PlayerData]
	GameManager.rival_players = [rival, third] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	GameManager.state = GameManager.GameState.PLAYING
	player.gold = 300.0
	player.mana = 50.0
	TurnManager.turn_number = 5
	grid.spawn_unit(Vector2i(-7, 3), UnitDatabase.create_unit("warrior"), rival)
	grid.spawn_unit(Vector2i(-7, 5), UnitDatabase.create_unit("warrior"), third)
	hud = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	shell = hud.ui_shell

func after_each():
	SelectionManager.reset()
	shell.modal_manager.clear()
	shell.close_strategic_overlay()
	GameManager.hex_grid = _original_grid
	GameManager.human_player = _original_human
	GameManager.players = _original_players
	GameManager.rival_players = _original_rivals
	GameManager.state = _original_state
	TurnManager.turn_number = _original_turn
	for someone in [player, rival, third]:
		someone.release_relations()
	grid.queue_free()

func _unit(kind: String, coord: Vector2i, owner: PlayerData = null) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner if owner != null else player)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _empire_fixture() -> Array[City]:
	var cities: Array[City] = []
	for index in 3:
		cities.append(grid.found_city(Vector2i(index * 4 - 4, -3), player, "Cidade %d" % index, true))
	cities[0].set_production("settler")
	cities[1].set_production("")
	for index in 8:
		_unit("warrior", Vector2i(index - 4, 2))
	_unit(CLERIC, Vector2i(-4, 4))
	_unit(SKELETON, Vector2i(-3, 4))
	_unit("settler", Vector2i(-2, 4))
	return cities

# --- Império ------------------------------------------------------------------------------

func test_empire_is_a_navigation_destination_with_three_tabs():
	assert_true(shell.navigation_manager.registered_destinations().has(NavigationManager.EMPIRE))
	assert_not_null(shell.global_bar.navigation_row.get_node_or_null("EmpireButton"))
	_empire_fixture()
	hud._on_empire_pressed()
	var screen := shell.empire_screen
	assert_true(screen.visible)
	assert_eq(screen.tabs.keys(), ["overview", "cities", "units"])
	assert_true(shell.overlay_dimmer.visible)

func test_empire_overview_counts_match_the_real_empire():
	_empire_fixture()
	var overview := EmpirePresenter.overview(player, shell.attention_service.items())
	assert_eq(overview.cities.count, 3)
	assert_eq(overview.cities.idle, 2, "sem produção = ociosa")
	assert_eq(overview.units.count, 11)
	assert_eq(overview.units.caster, 1)
	assert_eq(overview.units.special, 2, "Hoste + Colonizador")
	assert_eq(overview.units.military, 8)
	assert_eq(overview.units.uncommanded, 1)
	assert_eq(overview.resources.gold, 300)
	shell.open_destination(NavigationManager.EMPIRE)
	assert_not_null(shell.empire_screen.find_child("OverviewGrid", true, false))

func test_city_list_sorts_and_row_click_focuses_the_city_panel():
	var cities := _empire_fixture()
	var by_attention := EmpirePresenter.city_rows(player, EmpirePresenter.SORT_ATTENTION)
	assert_eq(by_attention[0].production_state, "idle", "ociosa primeiro")
	var by_name := EmpirePresenter.city_rows(player, EmpirePresenter.SORT_NAME)
	assert_eq(by_name.map(func(row): return row.name), ["Cidade 0", "Cidade 1", "Cidade 2"])
	shell.empire_screen.open_tab("cities")
	shell.open_destination(NavigationManager.EMPIRE)
	assert_eq(shell.empire_screen.city_row_buttons.size(), 3)
	shell.empire_screen.city_row_buttons[0].pressed.emit()
	assert_false(shell.empire_screen.visible, "linha fecha a tela e leva ao mapa")
	assert_eq(shell.context_router.mode, ContextRouter.MODE_CITY)
	assert_true(cities.has(shell.context_router.city_panel.city))

func test_unit_list_filters_and_row_click_selects_the_unit():
	_empire_fixture()
	assert_eq(EmpirePresenter.unit_rows(player, EmpirePresenter.FILTER_CASTER).size(), 1)
	var special := EmpirePresenter.unit_rows(player, EmpirePresenter.FILTER_SPECIAL)
	assert_eq(special.size(), 2)
	assert_true(special.any(func(row): return row.status == "SEM COMANDO"), "Hoste sem comando visível na lista")
	shell.empire_screen.open_tab("units", EmpirePresenter.FILTER_MILITARY)
	shell.open_destination(NavigationManager.EMPIRE)
	assert_eq(shell.empire_screen.unit_row_buttons.size(), 8)
	shell.empire_screen.unit_row_buttons[0].pressed.emit()
	shell.context_router.flush()
	assert_eq(shell.context_router.mode, ContextRouter.MODE_UNIT)
	assert_not_null(SelectionManager.selected_unit)
	assert_eq(SelectionManager.selected_unit.owner_player, player)

func test_retinue_attention_opens_the_uncommanded_host():
	_empire_fixture()
	shell.attention_service.refresh()
	var item: AttentionItem = shell.attention_service.items().filter(func(entry): return entry.id == "retinue_uncommanded")[0]
	hud._on_attention_action_requested(item.primary_action, item)
	shell.context_router.flush()
	assert_eq(shell.context_router.mode, ContextRouter.MODE_UNIT)
	assert_true(shell.context_router.unit_panel.unit.unit_data.is_retinue())

# --- Diplomacia --------------------------------------------------------------------------

func test_diplomacy_rows_show_war_peace_truce_and_eliminated():
	Diplomacy.declare_war(player, rival, "Fronteira", true)
	var peace_rows := DiplomacyPresenter.rows(player)
	assert_eq(peace_rows[0].state, DiplomacyPresenter.STATE_WAR)
	assert_eq(peace_rows[1].state, DiplomacyPresenter.STATE_PEACE)
	third.truces[player] = TurnManager.turn_number + 4
	player.truces[third] = TurnManager.turn_number + 4
	assert_eq(DiplomacyPresenter.row(player, third).state, DiplomacyPresenter.STATE_TRUCE)
	assert_eq(DiplomacyPresenter.row(player, third).truce_remaining, 4)
	for unit in rival.units.duplicate():
		grid.remove_unit(unit)
	assert_eq(DiplomacyPresenter.row(player, rival).state, DiplomacyPresenter.STATE_ELIMINATED)
	var detail := DiplomacyPresenter.detail(player, third)
	assert_false(detail.can_declare_war, "trégua bloqueia pela regra real")
	assert_string_contains(detail.declare_reason, "Trégua")

func test_declare_war_requires_confirmation_cancel_changes_nothing_confirm_declares_once():
	hud._on_diplomacy_pressed()
	var screen := shell.diplomacy_screen
	screen.select_rival(rival)
	watch_signals(EventBus)
	screen.request_declare_war(rival)
	assert_true(shell.modal_manager.is_modal_open())
	var modal := screen.confirmation_modal()
	assert_not_null(modal)
	modal.find_child("CancelButton", true, false).pressed.emit()
	assert_false(player.is_at_war_with(rival), "cancelar não muda nada")
	assert_signal_not_emitted(EventBus, "diplomacy_changed")
	screen.request_declare_war(rival)
	screen.confirmation_modal().find_child("ConfirmButton", true, false).pressed.emit()
	assert_true(player.is_at_war_with(rival))
	assert_signal_emit_count(EventBus, "diplomacy_changed", 1)
	assert_false(shell.modal_manager.is_modal_open())
	var history := UIEvents.get_history()
	assert_true(history.any(func(event): return event.event_type == "war_declared"), "fluxo de eventos da F29 continua")

func test_war_event_deep_link_opens_diplomacy_on_the_right_faction():
	Diplomacy.declare_war(third, player, "Ambição")
	var events := UIEvents.get_history().filter(func(event): return event.event_type == "war_declared")
	assert_false(events.is_empty())
	hud._on_event_action_requested(events.back())
	assert_true(shell.diplomacy_screen.visible)
	assert_eq(shell.diplomacy_screen.selected_rival, third)

func test_diplomacy_presenter_never_reads_private_ai_state():
	var source := ""
	for path in ["res://scripts/ui/presenters/DiplomacyPresenter.gd", "res://scripts/ui/strategy/DiplomacyScreen.gd"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if not line.strip_edges().begins_with("#"):
				source += line + "\n"
	for private in ["war_campaigns", "v2_ai_strategy", "production_item", "v2_research", ".gold", ".mana", "known_enemy_cities"]:
		assert_false(source.contains(private), "diplomacia lê %s" % private)

# --- Vitória -----------------------------------------------------------------------------

func test_victory_summary_has_three_comparable_cards_and_detail_explains():
	shell.open_destination(NavigationManager.VICTORY)
	var screen := shell.victory_screen
	assert_eq(screen.summary_cards.keys(), [VictoryPresenter.DOMINATION, VictoryPresenter.SUPREMACY, VictoryPresenter.TRANSCENDENCE])
	for card in screen.summary_cards.values():
		assert_not_null(card.find_child("Progress", true, false))
		assert_not_null(card.find_child("NextRequirement", true, false))
		assert_null(card.find_child("HowToWin", true, false), "explicação longa só no detalhe")
	screen.show_detail(VictoryPresenter.SUPREMACY)
	assert_not_null(screen.find_child("HowToWin", true, false))
	assert_not_null(screen.find_child("Checklist", true, false))
	screen.show_summary()
	assert_eq(screen.current_detail, "")

func test_domination_counts_eliminated_rivals_without_arbitrary_percentages():
	for unit in rival.units.duplicate():
		grid.remove_unit(unit)
	var card := VictoryPresenter.domination_card(player)
	assert_eq(card.progress_text, "1 / 2 rivais eliminados")
	assert_eq(card.segments.filter(func(segment): return segment.filled).size(), 1)

func test_supremacy_uses_v2_victory_conditions_exactly():
	var status := V2VictoryConditions.military_supremacy_status(player)
	var detail := VictoryPresenter.supremacy_detail(player)
	assert_eq(detail.checklist[1].done, status.access)
	var rival_rows: Array = detail.sections[0].rows
	assert_eq(rival_rows.size(), status.rivals.size())
	for index in rival_rows.size():
		assert_eq(rival_rows[index].done, status.rivals[index].satisfied)
	var card := VictoryPresenter.supremacy_card(player)
	assert_string_contains(card.next, "Exército Supremo", "sem acesso, o próximo requisito é a pesquisa")

func test_transcendence_detail_tracks_own_requirements_and_rival_only_public():
	for branch in ["sacred", "infernal"]:
		for tier in range(1, 10):
			player.v2_research.complete_research("v2_magic_%s_%d" % [branch, tier])
	player.v2_research.complete_research("v2_transcendence")
	var detail := VictoryPresenter.transcendence_detail(player)
	var labels: Array = detail.checklist.map(func(row): return row.label)
	for expected in ["Duas Escolas completas (N9)", "Transcendência pesquisada", "Grandes Manifestações ativas", "Estrutura Ritual utilizável", "Ritual Final"]:
		assert_has(labels, expected)
	assert_true(detail.checklist[0].done)
	assert_true(detail.checklist[1].done)
	for tier in range(1, 10):
		rival.v2_research.complete_research("v2_magic_arcanism_%d" % tier)
	var rival_card := VictoryPresenter.transcendence_card(player)
	assert_eq(rival_card.threat, "", "pesquisa rival não aparece; só Ritual público")
	var rival_city := grid.found_city(Vector2i(5, -5), rival, "Umbra", true)
	rival_city.buildings["v2_building_infernal_ritual"] = true
	for branch in ["sacred", "infernal"]:
		for tier in range(1, 10):
			rival.v2_research.complete_research("v2_magic_%s_%d" % [branch, tier])
	rival.v2_research.complete_research("v2_transcendence")
	grid.spawn_unit(Vector2i(6, -5), UnitDatabase.create_unit(SERAPH), rival)
	grid.spawn_unit(Vector2i(6, -6), UnitDatabase.create_unit(ARCHDEMON), rival)
	rival.mana = 200.0
	assert_true(V2TranscendenceSystem.start_ritual(rival, rival_city))
	rival_card = VictoryPresenter.transcendence_card(player)
	assert_string_contains(rival_card.threat, "Crepúsculo")
	var rows: Array = VictoryPresenter.transcendence_detail(player).sections[0].rows
	assert_eq(rows.size(), 1)
	assert_false(String(rows[0].status).contains("Manifest"), "Manifestações rivais não são listadas")

func test_ritual_attention_deep_link_opens_transcendence_detail():
	var item := AttentionItem.create("rival_ritual:1", AttentionItem.Priority.WARNING, "Transcendência iminente")
	item.category = "victory"
	item.primary_action = "victory"
	hud._on_attention_action_requested("victory", item)
	assert_true(shell.victory_screen.visible)
	assert_eq(shell.victory_screen.current_detail, VictoryPresenter.TRANSCENDENCE)

# --- Research Board responsivo -------------------------------------------------------

func _board() -> V2ResearchBoard:
	hud._on_research_pressed()
	return hud.v2_research_board

func test_research_board_compact_mode_keeps_names_readable_and_click_targets():
	var board := _board()
	board.set_compact(true)
	var metrics := board.metrics()
	assert_lt(metrics.card.x, V2ResearchBoard.CARD_SIZE.x)
	assert_gte(metrics.name_font, 11, "nunca resolve 1280 com fonte minúscula")
	assert_gte(metrics.meta_font, 10)
	assert_gte(metrics.card.y, 60.0, "alvo de clique preservado")
	board.set_zoom(0.8)
	var zoomed := board.metrics()
	assert_lt(zoomed.card.x, metrics.card.x)
	assert_gte(zoomed.name_font, 11)
	assert_eq(board.card_count(), 55, "zoom não muda o conteúdo")
	board.set_zoom(1.0)
	board.set_compact(false)

func test_research_board_has_sticky_tier_header_and_branch_column_outside_the_card_scroll():
	var board := _board()
	var cards_scroll := board.find_child("CardsScroll", true, false) as ScrollContainer
	var header_scroll := board.find_child("TierHeaderScroll", true, false) as ScrollContainer
	var label_scroll := board.find_child("BranchLabelScroll", true, false) as ScrollContainer
	assert_not_null(cards_scroll)
	assert_false(cards_scroll.is_ancestor_of(header_scroll), "cabeçalho de tiers fica fora da rolagem vertical")
	assert_false(cards_scroll.is_ancestor_of(label_scroll), "coluna de linhas fica fora da rolagem horizontal")
	assert_not_null(header_scroll.find_child("Tier1", true, false))
	assert_eq(label_scroll.find_children("Label_*", "", true, false).size(), V2ResearchDatabase.branches_for_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE).size())
	# Sincronização por sinal (nunca offset por frame): as quatro barras estão ligadas.
	assert_true(cards_scroll.get_h_scroll_bar().value_changed.is_connected(board._on_main_h_scrolled))
	assert_true(cards_scroll.get_v_scroll_bar().value_changed.is_connected(board._on_main_v_scrolled))
	assert_true(label_scroll.get_v_scroll_bar().value_changed.is_connected(board._on_label_v_scrolled))
	assert_true(header_scroll.get_h_scroll_bar().value_changed.is_connected(board._on_header_h_scrolled))
	assert_false(board.has_method("_process"), "sem polling")

func test_research_board_jumps_are_deterministic():
	var board := _board()
	var first := board.first_available_id()
	assert_eq(first, "v2_doctrine_guardian_1", "primeiro disponível da aba atual, em ordem")
	assert_eq(board.first_available_id(), first)
	board.show_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL)
	assert_true(String(board.first_available_id()).begins_with("v2_magic_"), "prefere a aba atual")
	assert_true(board.jump_to_available())
	assert_eq(board.selected_id(), board.first_available_id())
	assert_false(board.jump_to_active(), "sem projeto ativo")
	player.v2_research.select_research("v2_infrastructure_economy_1" if V2ResearchDatabase.get_node("v2_infrastructure_economy_1") != null else V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE)[0].id)
	assert_true(board.jump_to_active())
	assert_eq(board.current_tree(), V2ResearchNode.TreeType.INFRASTRUCTURE)

func test_research_debug_tools_are_collapsed_and_absent_in_release():
	var board := _board()
	assert_true(board.debug_tools_enabled)
	assert_false(board.debug_row_visible(), "Dev recolhido por padrão")
	board.find_child("DevToggle", true, false).pressed.emit()
	assert_true(board.debug_row_visible())
	var release := V2ResearchBoard.new()
	release.debug_tools_enabled = false
	add_child_autofree(release)
	assert_null(release.find_child("DevToggle", true, false))
	assert_null(release.find_child("DevTools", true, false))

# --- Navegação ------------------------------------------------------------------------

func test_strategic_screens_are_exclusive_and_escape_closes_them():
	hud._on_empire_pressed()
	hud._on_diplomacy_pressed()
	assert_false(shell.empire_screen.visible)
	assert_true(shell.diplomacy_screen.visible)
	hud._on_victory_pressed()
	assert_false(shell.diplomacy_screen.visible)
	assert_true(hud.close_topmost_overlay())
	assert_false(shell.victory_screen.visible)
	assert_false(shell.overlay_dimmer.visible)

func test_focus_returns_to_the_control_that_opened_the_screen():
	var opener: Button = shell.global_bar.navigation_row.get_node("EmpireButton")
	opener.grab_focus()
	shell.open_destination(NavigationManager.EMPIRE)
	shell.close_strategic_overlay()
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), opener)

func test_space_never_ends_the_turn_with_a_strategic_screen_open():
	watch_signals(shell)
	shell.open_destination(NavigationManager.DIPLOMACY)
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	hud._unhandled_input(space)
	assert_signal_not_emitted(shell, "end_turn_requested")
	assert_eq(TurnManager.turn_number, 5)

func test_new_ui_state_is_runtime_only():
	for path in ["res://scripts/ui/context/ContextRouter.gd", "res://scripts/ui/presenters/EmpirePresenter.gd", "res://scripts/ui/presenters/DiplomacyPresenter.gd", "res://scripts/ui/presenters/VictoryPresenter.gd", "res://scripts/ui/presenters/CityPresenter.gd", "res://scripts/ui/presenters/UnitPresenter.gd"]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("func to_save") or source.contains("func load_dict") or source.contains("SaveManager"), path)
	var save_source := FileAccess.get_file_as_string("res://scripts/autoload/SaveManager.gd")
	for name in ["ContextRouter", "EmpireScreen", "VictoryScreen", "DiplomacyScreen", "UnitPresenter"]:
		assert_false(save_source.contains(name), "save não conhece %s" % name)
