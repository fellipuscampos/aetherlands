extends GutTest

## UI das três árvores V2 (Fase 1) ligada ao estado REAL (V2ResearchState): estados
## visuais, clique/seleção, rodapé de ação, progresso, Conhecimento guardado e
## ferramentas de debug. A UI só chama a API do estado.

const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL
const INFRASTRUCTURE := V2ResearchNode.TreeType.INFRASTRUCTURE
const States := V2ResearchDatabase.NodeState

var board: V2ResearchBoard
var state: V2ResearchState

func before_each():
	state = V2ResearchState.new()
	board = V2ResearchBoard.new()
	add_child_autofree(board)
	board.bind_state(state)

func _click(node_id: String) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	board.card_for(node_id).gui_input.emit(event)

# --- Estrutura das abas (herdada da Fase 0) ---------------------------------------------------

func test_starts_on_the_doctrine_tab_with_all_55_nodes():
	assert_eq(board.current_tree(), MILITARY)
	assert_eq(board.card_count(), 55, "6 x 9 + Exército Supremo")
	assert_not_null(board.card_for("v2_supreme_army"))

func test_each_tab_shows_its_own_tree():
	board.show_tree(MAGIC)
	assert_eq(board.card_count(), 55, "6 x 9 + Transcendência")
	assert_not_null(board.card_for("v2_transcendence"))
	assert_null(board.card_for("v2_supreme_army"), "só a árvore da aba aparece")
	board.show_tree(INFRASTRUCTURE)
	assert_eq(board.card_count(), 18)
	board.show_tree(MILITARY)
	assert_eq(board.card_count(), 55)

func test_every_branch_row_shows_all_of_its_tiers_in_order():
	for tree_type in V2ResearchDatabase.tree_types():
		board.show_tree(tree_type)
		for line in V2ResearchDatabase.branches_for_tree(tree_type):
			var previous_index := -1
			for node in V2ResearchDatabase.nodes_for_branch(tree_type, line.id):
				var card := board.card_for(node.id)
				assert_not_null(card, node.id)
				assert_gt(card.get_index(), previous_index, "%s fora de ordem" % node.id)
				previous_index = card.get_index()

func test_cards_carry_a_tooltip_with_structure_and_real_state():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)
	board.show_tree(MILITARY)
	var tooltip := board.card_for("v2_doctrine_guardian_1").tooltip_text
	for fragment in ["Doutrina do Guardião", "Doutrina do Guardião · Nível 1", "Custo: 8", "Estado: Pesquisando", "Progresso: 4 / 8 (50%)"]:
		assert_true(tooltip.contains(fragment), "tooltip sem '%s':\n%s" % [fragment, tooltip])
	assert_eq(board.card_for("v2_doctrine_guardian_1").mouse_filter, Control.MOUSE_FILTER_STOP)

# --- Estados reais ------------------------------------------------------------------------------

func test_cards_reflect_locked_available_researching_partial_and_completed():
	state.complete_research("v2_doctrine_guardian_1")
	state.select_research("v2_doctrine_guardian_2")
	state.add_knowledge(5.0)
	state.select_research("v2_doctrine_warrior_1")
	state.add_knowledge(2.0)

	assert_eq(board.node_state_of("v2_doctrine_guardian_1"), States.COMPLETED)
	assert_eq(board.node_state_of("v2_doctrine_guardian_2"), States.PARTIAL, "tem progresso guardado, não é o ativo")
	assert_eq(board.node_state_of("v2_doctrine_warrior_1"), States.RESEARCHING)
	assert_eq(board.node_state_of("v2_doctrine_ranger_1"), States.AVAILABLE)
	assert_eq(board.node_state_of("v2_doctrine_guardian_3"), States.LOCKED)

func test_partial_card_shows_its_stored_progress():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(6.0)
	state.select_research("v2_magic_sacred_1")

	var card := board.card_for("v2_doctrine_guardian_1")

	assert_true(card.tooltip_text.contains("Estado: Parcial"))
	assert_true(card.tooltip_text.contains("Progresso: 6 / 8 (75%)"))

## PERFORMANCE: progresso/seleção/pausa trocam SÓ os cards afetados.
func test_progress_updates_only_the_affected_card_in_place():
	state.select_research("v2_doctrine_guardian_1")
	var active_card := board.card_for("v2_doctrine_guardian_1")
	var other_card := board.card_for("v2_doctrine_warrior_1")
	var index_before := active_card.get_index()

	state.add_knowledge(3.0)

	assert_ne(board.card_for("v2_doctrine_guardian_1"), active_card, "o card do projeto foi refeito")
	assert_eq(board.card_for("v2_doctrine_guardian_1").get_index(), index_before, "na mesma posição")
	assert_same(board.card_for("v2_doctrine_warrior_1"), other_card, "os outros 54 cards não foram tocados")

func test_completion_rebuilds_the_tab_once_on_the_next_frame_and_opens_the_next_tier():
	state.select_research("v2_doctrine_guardian_1")
	var untouched := board.card_for("v2_doctrine_warrior_1")

	state.add_knowledge(10.0)

	assert_eq(board.node_state_of("v2_doctrine_guardian_1"), States.COMPLETED, "o estado muda na hora")
	assert_eq(board.node_state_of("v2_doctrine_guardian_2"), States.AVAILABLE)
	assert_same(board.card_for("v2_doctrine_warrior_1"), untouched, "a UI só reconstrói no frame seguinte")
	await get_tree().process_frame
	assert_ne(board.card_for("v2_doctrine_warrior_1"), untouched, "conclusão reconstrói a aba (ligações mudam)")
	assert_eq(board.card_count(), 55)

## PERFORMANCE: completar linhas inteiras (18 conclusões no mesmo frame) = UM rebuild.
func test_many_completions_in_one_frame_rebuild_the_tab_only_once():
	var before := board.rebuild_count

	state.debug_complete_branch(MILITARY, "guardian")
	state.debug_complete_branch(MILITARY, "warrior")
	await get_tree().process_frame

	assert_eq(board.rebuild_count, before + 1, "18 conclusões, 1 reconstrução")
	assert_eq(board.node_state_of("v2_doctrine_warrior_9"), States.COMPLETED)
	assert_eq(board.node_state_of("v2_supreme_army"), States.AVAILABLE)

func test_reopening_or_reselecting_the_same_tab_does_not_rebuild():
	var card := board.card_for("v2_doctrine_guardian_1")
	board.refresh()
	board.show_tree(MILITARY)
	assert_same(board.card_for("v2_doctrine_guardian_1"), card)

# --- Status ---------------------------------------------------------------------------------------

func test_status_line_shows_the_active_project_and_banked_knowledge():
	assert_eq(board.status_text(), "Nenhum projeto ativo")
	state.add_knowledge(3.0)
	assert_eq(board.status_text(), "Nenhum projeto ativo  ·  Conhecimento guardado: 3")
	state.select_research("v2_doctrine_guardian_1")
	assert_eq(board.status_text(), "Pesquisando: Doutrina do Guardião — 3 / 8 (38%)")
	state.add_knowledge(2.5)
	assert_eq(board.status_text(), "Pesquisando: Doutrina do Guardião — 5.5 / 8 (69%)")

# --- Clique, rodapé e ação -------------------------------------------------------------------------

func test_clicking_a_card_selects_it_and_fills_the_footer():
	_click("v2_doctrine_guardian_1")

	assert_eq(board.selected_id(), "v2_doctrine_guardian_1")
	var footer := board.footer_text()
	assert_true(footer.contains("Doutrina do Guardião · Doutrina"))
	assert_true(footer.contains("Custo: 8"))
	assert_true(footer.contains("Estado: Disponível"))

func test_selection_is_highlighted_and_moves_with_the_click():
	_click("v2_doctrine_guardian_1")
	var first := board.card_for("v2_doctrine_guardian_1")
	assert_eq((first.get_theme_stylebox("panel") as StyleBoxFlat).border_color, V2ResearchBoard.TEXT_PRIMARY)

	_click("v2_doctrine_warrior_1")

	assert_eq(board.selected_id(), "v2_doctrine_warrior_1")
	assert_ne((board.card_for("v2_doctrine_guardian_1").get_theme_stylebox("panel") as StyleBoxFlat).border_color, V2ResearchBoard.TEXT_PRIMARY, "a seleção anterior some")

func test_available_node_offers_research_and_pressing_it_starts_the_project():
	board.select_node("v2_doctrine_guardian_1")
	assert_eq(board.action_text(), "Pesquisar")
	assert_false(board.action_disabled())

	board.press_action()

	assert_eq(state.active_id, "v2_doctrine_guardian_1")
	assert_eq(board.action_text(), "Pausar pesquisa")

func test_researching_node_can_be_paused():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)
	board.select_node("v2_doctrine_guardian_1")
	assert_eq(board.action_text(), "Pausar pesquisa")
	assert_true(board.footer_text().contains("Progresso: 4 / 8 (50%)"))

	board.press_action()

	assert_eq(state.active_id, "")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 4.0, 0.001, "pausar mantém o progresso")
	assert_eq(board.action_text(), "Continuar pesquisa")

func test_partial_node_offers_to_continue_and_resumes_where_it_stopped():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)
	state.select_research("v2_magic_sacred_1")
	board.select_node("v2_doctrine_guardian_1")
	assert_eq(board.action_text(), "Continuar pesquisa")

	board.press_action()

	assert_eq(state.active_id, "v2_doctrine_guardian_1")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 4.0, 0.001)

func test_locked_node_explains_why_and_cannot_be_started():
	board.select_node("v2_doctrine_guardian_6")

	assert_eq(board.action_text(), "Bloqueado")
	assert_true(board.action_disabled())
	assert_true(board.footer_text().contains("Requer Guardião."))
	board.press_action()
	assert_eq(state.active_id, "", "não inicia um nó bloqueado")

func test_completed_node_shows_completed_and_is_inert():
	state.complete_research("v2_doctrine_guardian_1")
	board.select_node("v2_doctrine_guardian_1")

	assert_eq(board.action_text(), "Concluído")
	assert_true(board.action_disabled())
	board.press_action()
	assert_eq(state.active_id, "")

func test_footer_starts_empty_and_switching_trees_clears_a_selection_from_another_tree():
	assert_true(board.footer_text().contains("Nenhum nó selecionado"))
	board.select_node("v2_doctrine_guardian_1")
	board.show_tree(MAGIC)
	assert_eq(board.selected_id(), "", "o nó selecionado era de outra árvore")

# --- Capstones ------------------------------------------------------------------------------------------

func test_capstone_card_and_footer_show_the_completed_branches_counter():
	var card := board.card_for("v2_supreme_army")
	assert_eq(board.node_state_of("v2_supreme_army"), States.LOCKED)
	board.select_node("v2_supreme_army")
	assert_true(board.footer_text().contains("Doutrinas completas: 0 / 2 (N9)"))
	assert_true(board.footer_text().contains("Requer 2 Doutrinas completas (N9): 0/2."))

	state.debug_complete_branch(MILITARY, "guardian")
	assert_true(board.footer_text().contains("Doutrinas completas: 1 / 2 (N9)"), "o rodapé atualiza na hora")
	assert_eq(board.node_state_of("v2_supreme_army"), States.LOCKED)
	await get_tree().process_frame
	assert_ne(board.card_for("v2_supreme_army"), card, "e o card no frame seguinte")

func test_capstone_becomes_researchable_with_two_branches_and_still_costs_knowledge():
	state.debug_complete_branch(MILITARY, "guardian")
	state.debug_complete_branch(MILITARY, "rogue")
	board.select_node("v2_supreme_army")

	assert_eq(board.node_state_of("v2_supreme_army"), States.AVAILABLE)
	assert_eq(board.action_text(), "Pesquisar")
	board.press_action()
	assert_eq(state.active_id, "v2_supreme_army")
	assert_false(state.is_completed("v2_supreme_army"), "ainda precisa pagar o próprio custo")

func test_transcendence_counts_schools():
	board.show_tree(MAGIC)
	board.select_node("v2_transcendence")
	assert_true(board.footer_text().contains("Escolas completas: 0 / 2 (N9)"))
	state.debug_complete_branch(MAGIC, "sacred")
	state.debug_complete_branch(MAGIC, "infernal")
	assert_eq(board.node_state_of("v2_transcendence"), States.AVAILABLE)

# --- Ferramentas de debug (só em build de desenvolvimento) ---------------------------------------------------

func test_debug_tools_exist_in_a_debug_build():
	assert_true(board.debug_tools_enabled, "GUT roda em build de debug")
	for button_id in ["add_10", "add_100", "complete_active", "complete_branch", "reset"]:
		assert_not_null(board.debug_button(button_id), button_id)

func test_debug_tools_are_not_created_in_a_normal_build():
	var release_like := V2ResearchBoard.new()
	release_like.debug_tools_enabled = false
	add_child_autofree(release_like)
	for button_id in ["add_10", "add_100", "complete_active", "complete_branch", "reset"]:
		assert_null(release_like.debug_button(button_id), "%s não pode existir em build normal" % button_id)

func test_debug_add_knowledge_feeds_the_bank_and_then_the_active_project():
	board.debug_button("add_10").pressed.emit()
	assert_almost_eq(state.research_overflow, 10.0, 0.001, "sem projeto: fica guardado")

	var first_cost := V2ResearchDatabase.get_node("v2_doctrine_guardian_1").cost
	var second_cost := V2ResearchDatabase.get_node("v2_doctrine_guardian_2").cost
	state.select_research("v2_doctrine_guardian_1")
	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_almost_eq(state.research_overflow, 10.0 - first_cost, 0.001)

	state.select_research("v2_doctrine_guardian_2")
	board.debug_button("add_100").pressed.emit()
	assert_true(state.is_completed("v2_doctrine_guardian_2"))
	assert_almost_eq(state.research_overflow, 110.0 - first_cost - second_cost, 0.001, "o Conhecimento excedente é conservado")

func test_debug_complete_active_and_complete_branch_and_reset():
	assert_true(board.debug_button("complete_active").disabled, "sem projeto ativo")
	state.select_research("v2_doctrine_guardian_1")
	assert_false(board.debug_button("complete_active").disabled)
	board.debug_button("complete_active").pressed.emit()
	assert_true(state.is_completed("v2_doctrine_guardian_1"))

	assert_true(board.debug_button("complete_branch").disabled, "sem nó selecionado")
	board.select_node("v2_doctrine_warrior_4")
	board.debug_button("complete_branch").pressed.emit()
	assert_eq(V2ResearchDatabase.completed_branches(MILITARY, state.completed_ids), ["warrior"])

	board.debug_button("reset").pressed.emit()
	assert_true(state.completed_ids.is_empty())
	assert_eq(board.node_state_of("v2_doctrine_warrior_1"), States.AVAILABLE, "a UI refletiu o reset")

func test_debug_complete_branch_is_disabled_for_the_universal_node():
	board.select_node("v2_supreme_army")
	assert_true(board.debug_button("complete_branch").disabled)

# --- Ligação ao estado ------------------------------------------------------------------------------------------

func test_rebinding_to_another_civilization_switches_the_view():
	state.complete_research("v2_doctrine_guardian_1")
	var other := V2ResearchState.new()

	board.bind_state(other)

	assert_same(board.get_state(), other)
	assert_eq(board.node_state_of("v2_doctrine_guardian_1"), States.AVAILABLE, "o outro estado não concluiu nada")
	state.complete_research("v2_doctrine_warrior_1") # mudança no estado antigo
	assert_eq(board.node_state_of("v2_doctrine_warrior_1"), States.AVAILABLE, "o tabuleiro já não escuta o estado antigo")

func test_loading_into_the_bound_state_refreshes_the_view_in_place():
	var saved := V2ResearchState.new()
	saved.debug_complete_branch(MILITARY, "siege")
	saved.select_research("v2_magic_sacred_1")
	saved.add_knowledge(3.0)

	state.load_dict(saved.to_dict())

	assert_eq(board.node_state_of("v2_doctrine_siege_9"), States.COMPLETED)
	assert_eq(board.node_state_of("v2_magic_sacred_1"), States.RESEARCHING)
	assert_eq(board.status_text(), "Pesquisando: Escola Sagrada — 3 / 8 (38%)") # Fase 17: nome canônico da Escola Sagrada

## PERFORMANCE: o HUD cria o painel V2 escondido — ele não pode montar 55 cards
## no _ready nem reagir a cada sinal; só monta quando fica visível.
func test_hidden_board_builds_nothing_until_it_is_shown():
	var hidden := V2ResearchBoard.new()
	hidden.visible = false
	add_child_autofree(hidden)
	var hidden_state := V2ResearchState.new()
	hidden.bind_state(hidden_state)
	assert_eq(hidden.card_count(), 0)

	hidden_state.select_research("v2_doctrine_guardian_1")
	hidden_state.add_knowledge(4.0)
	hidden.show_tree(MAGIC)
	assert_eq(hidden.card_count(), 0, "escondido, nem estado nem aba montam nada")

	hidden.show()

	assert_eq(hidden.card_count(), 55)
	assert_eq(hidden.node_state_of("v2_doctrine_guardian_1"), States.RESEARCHING, "reflete o estado acumulado enquanto escondido")

func test_board_has_no_per_frame_processing():
	assert_false(board.has_method("_process"))
	assert_false(board.has_method("_physics_process"))
	assert_false(board.is_processing())

func test_close_button_requests_closing():
	watch_signals(board)
	var header := board.get_child(0) as HBoxContainer
	var close_button := header.get_child(header.get_child_count() - 1) as Button
	assert_eq(close_button.text, "X")
	close_button.pressed.emit()
	assert_signal_emitted(board, "close_requested")

func test_tab_buttons_switch_trees_and_keep_a_single_one_pressed():
	var header := board.get_child(0) as HBoxContainer
	var magic_tab := header.get_child(1) as Button
	assert_eq(magic_tab.text, "Magia")
	magic_tab.pressed.emit()
	assert_eq(board.current_tree(), MAGIC)
	assert_true(magic_tab.button_pressed)
	assert_false((header.get_child(0) as Button).button_pressed)
