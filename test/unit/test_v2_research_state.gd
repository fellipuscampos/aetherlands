extends GutTest

## Runtime de pesquisa V2 (Fase 1): estado por civilização, seleção, slot único,
## progresso, overflow, capstones, sinais e (de)serialização defensiva.
## Nenhum unlock de gameplay: concluir um nó só o registra e emite o sinal.

const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL
const INFRASTRUCTURE := V2ResearchNode.TreeType.INFRASTRUCTURE
const States := V2ResearchDatabase.NodeState

var state: V2ResearchState

func before_each():
	state = V2ResearchState.new()

## Conclui uma linha inteira usando a própria API (sem atalho de debug).
func _pay_off(id: String) -> void:
	assert_true(state.select_research(id), "pre-condicao: %s selecionável" % id)
	state.add_knowledge(V2ResearchDatabase.get_node(id).cost)
	assert_true(state.is_completed(id), "pre-condicao: %s concluído" % id)

# --- Seleção -----------------------------------------------------------------------

func test_first_level_of_every_branch_starts_available_and_the_rest_locked():
	for tree_type in V2ResearchDatabase.tree_types():
		for line in V2ResearchDatabase.branches_for_tree(tree_type):
			var nodes := V2ResearchDatabase.nodes_for_branch(tree_type, line.id)
			assert_true(state.is_available(nodes[0].id), "%s N1" % line.id)
			assert_eq(state.node_state(nodes[0].id), States.AVAILABLE)
			assert_false(state.is_available(nodes[1].id), "%s N2 exige N1" % line.id)
			assert_eq(state.node_state(nodes[1].id), States.LOCKED)

func test_selecting_an_available_node_makes_it_the_active_project():
	assert_true(state.select_research("v2_doctrine_guardian_1"))
	assert_eq(state.active_id, "v2_doctrine_guardian_1")
	assert_eq(state.node_state("v2_doctrine_guardian_1"), States.RESEARCHING)

func test_selecting_a_locked_node_fails_and_changes_nothing():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)
	var snapshot := state.to_dict()

	assert_false(state.select_research("v2_doctrine_guardian_2"), "N2 sem N1 concluído")

	assert_eq(state.to_dict(), snapshot, "estado intacto")
	assert_eq(state.active_id, "v2_doctrine_guardian_1")

func test_selecting_an_unknown_or_completed_node_fails():
	assert_false(state.select_research("nao_existe"))
	assert_false(state.select_research(""))
	assert_false(state.select_research("guarda"), "id V1 não existe no runtime V2")
	_pay_off("v2_doctrine_guardian_1")
	assert_false(state.select_research("v2_doctrine_guardian_1"), "concluído não pode ser pesquisado de novo")
	assert_eq(state.active_id, "")

func test_unavailable_reason_explains_each_kind_of_block():
	assert_eq(state.unavailable_reason("v2_doctrine_guardian_1"), "")
	assert_eq(state.unavailable_reason("v2_doctrine_guardian_6"), "Requer Guardião.", "N5 se chama Guardião (a unidade)")
	assert_eq(state.unavailable_reason("nao_existe"), "Pesquisa inexistente.")
	assert_eq(state.unavailable_reason("v2_supreme_army"), "Requer 2 Doutrinas completas (N9): 0/2.")
	assert_eq(state.unavailable_reason("v2_transcendence"), "Requer 2 Escolas completas (N9): 0/2.")
	_pay_off("v2_doctrine_guardian_1")
	assert_eq(state.unavailable_reason("v2_doctrine_guardian_1"), "Já concluída.")

func test_a_completed_node_counts_for_its_prerequisite():
	_pay_off("v2_doctrine_guardian_1")
	assert_true(state.is_available("v2_doctrine_guardian_2"))
	assert_true(state.can_research("v2_doctrine_guardian_2"))

# --- Slot único -----------------------------------------------------------------------

func test_switching_project_keeps_the_previous_progress():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(6.0)

	assert_true(state.select_research("v2_magic_infernal_1"))

	assert_eq(state.active_id, "v2_magic_infernal_1", "só UM projeto ativo")
	assert_eq(state.node_state("v2_doctrine_guardian_1"), States.PARTIAL, "o anterior deixa de ser ativo")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 6.0, 0.001, "e mantém o progresso")
	assert_almost_eq(state.get_progress("v2_magic_infernal_1"), 0.0, 0.001)

func test_returning_to_a_paused_project_continues_where_it_stopped():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)
	state.select_research("v2_magic_infernal_1")
	state.add_knowledge(3.0)

	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(2.0)

	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 6.0, 0.001)
	assert_almost_eq(state.get_progress("v2_magic_infernal_1"), 3.0, 0.001, "o outro projeto não mudou")

func test_the_three_trees_compete_for_the_same_slot():
	for id in ["v2_doctrine_ranger_1", "v2_magic_sacred_1", "v2_infrastructure_academy_1"]:
		assert_true(state.select_research(id))
		state.add_knowledge(1.0)
		assert_eq(state.active_id, id)
	for id in ["v2_doctrine_ranger_1", "v2_magic_sacred_1", "v2_infrastructure_academy_1"]:
		assert_almost_eq(state.get_progress(id), 1.0, 0.001, "progresso individual de %s" % id)

func test_cancelling_pauses_without_losing_progress_and_can_stay_idle():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(5.0)

	state.cancel_active_research()

	assert_eq(state.active_id, "")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 5.0, 0.001)
	state.cancel_active_research() # sem ativo: no-op
	assert_eq(state.active_id, "")

func test_selecting_the_already_active_project_is_a_harmless_noop():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(5.0)
	watch_signals(state)

	assert_true(state.select_research("v2_doctrine_guardian_1"))

	assert_signal_not_emitted(state, "research_selected")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 5.0, 0.001)

# --- Progresso e conclusão ----------------------------------------------------------------

func test_knowledge_adds_progress_and_ratio():
	state.select_research("v2_doctrine_guardian_3") # custo 30, mas está bloqueado
	assert_eq(state.active_id, "", "pre-condicao: N3 exige N2")
	_pay_off("v2_doctrine_guardian_1")
	_pay_off("v2_doctrine_guardian_2")
	state.select_research("v2_doctrine_guardian_3")

	var half_cost: float = V2ResearchDatabase.get_node("v2_doctrine_guardian_3").cost * 0.5
	state.add_knowledge(half_cost)

	assert_almost_eq(state.get_progress("v2_doctrine_guardian_3"), half_cost, 0.001)
	assert_almost_eq(state.get_progress_ratio("v2_doctrine_guardian_3"), 0.5, 0.001)
	assert_false(state.is_completed("v2_doctrine_guardian_3"))

func test_reaching_the_cost_completes_and_clears_the_active_slot():
	state.select_research("v2_doctrine_guardian_1")
	var cost: float = V2ResearchDatabase.get_node("v2_doctrine_guardian_1").cost

	state.add_knowledge(cost - 0.1)
	assert_false(state.is_completed("v2_doctrine_guardian_1"))
	state.add_knowledge(0.1)

	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_eq(state.active_id, "", "não escolhe outro projeto sozinho")
	assert_eq(state.get_progress_ratio("v2_doctrine_guardian_1"), 1.0)
	assert_false(state.progress_by_id.has("v2_doctrine_guardian_1"), "progresso deixa de ser guardado")
	assert_eq(state.node_state("v2_doctrine_guardian_1"), States.COMPLETED)
	assert_true(state.is_available("v2_doctrine_guardian_2"), "o próximo tier abre")

func test_get_completed_ids_is_sorted_and_matches_the_set():
	_pay_off("v2_magic_sacred_1")
	_pay_off("v2_doctrine_guardian_1")
	assert_eq(state.get_completed_ids(), ["v2_doctrine_guardian_1", "v2_magic_sacred_1"])

func test_complete_research_needs_the_node_to_be_available():
	assert_false(state.complete_research("v2_doctrine_guardian_5"), "não pula tiers")
	assert_true(state.complete_research("v2_doctrine_guardian_1"))
	assert_false(state.complete_research("v2_doctrine_guardian_1"), "nem conclui duas vezes")
	assert_true(state.is_completed("v2_doctrine_guardian_1"))

func test_completing_the_active_node_clears_it_and_drops_stored_progress():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(4.0)

	assert_true(state.complete_research("v2_doctrine_guardian_1"))

	assert_eq(state.active_id, "")
	assert_false(state.progress_by_id.has("v2_doctrine_guardian_1"))

# --- Overflow ---------------------------------------------------------------------------------

func test_excess_knowledge_on_completion_goes_to_overflow():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(6.0)

	state.add_knowledge(5.0)

	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_almost_eq(state.research_overflow, 3.0, 0.001, "usa 2, sobram 3")
	assert_eq(state.active_id, "", "nenhum projeto novo é escolhido")

func test_knowledge_without_an_active_project_is_banked_not_lost():
	state.add_knowledge(12.0)
	state.add_knowledge(3.0)
	assert_almost_eq(state.research_overflow, 15.0, 0.001)
	assert_eq(state.active_id, "")

func test_banked_knowledge_is_applied_when_a_project_is_selected():
	state.add_knowledge(4.0)

	state.select_research("v2_doctrine_guardian_1")

	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 4.0, 0.001)
	assert_almost_eq(state.research_overflow, 0.0, 0.001)

func test_banked_knowledge_can_complete_the_project_and_leave_the_rest():
	var first_cost: float = V2ResearchDatabase.get_node("v2_doctrine_guardian_1").cost
	var second_cost: float = V2ResearchDatabase.get_node("v2_doctrine_guardian_2").cost
	var second_progress := second_cost * 0.5
	state.add_knowledge(first_cost + second_progress)

	state.select_research("v2_doctrine_guardian_1") # custo 10

	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_almost_eq(state.research_overflow, second_progress, 0.001)
	assert_eq(state.active_id, "")
	# ... e o que sobrou paga o próximo quando o jogador escolher.
	state.select_research("v2_doctrine_guardian_2") # custo 20
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_2"), second_progress, 0.001)
	assert_almost_eq(state.research_overflow, 0.0, 0.001)

func test_no_knowledge_is_ever_lost_across_a_whole_sequence():
	var added := 0.0
	state.add_knowledge(5.0); added += 5.0                 # sem projeto -> overflow
	state.select_research("v2_doctrine_guardian_1")        # aplica os 5 (custo 8)
	state.add_knowledge(1.0); added += 1.0                 # 6/8
	state.select_research("v2_magic_sacred_1")             # troca: guardian_1 fica em 6
	state.add_knowledge(4.0); added += 4.0                 # sacred_1 4/8
	state.select_research("v2_doctrine_guardian_1")        # volta: 6/8
	state.add_knowledge(5.0); added += 5.0                 # conclui, sobram 3
	state.select_research("v2_doctrine_guardian_2")        # aplica os 3 (custo 16)
	state.add_knowledge(30.0); added += 30.0               # conclui, sobram 17
	state.add_knowledge(2.5); added += 2.5                 # sem projeto -> overflow

	var accounted := state.research_overflow
	for id in state.progress_by_id:
		accounted += state.progress_by_id[id]
	for id in state.completed_ids:
		accounted += V2ResearchDatabase.get_node(id).cost
	assert_almost_eq(accounted, added, 0.001, "tudo que entrou está em progresso, concluídos ou overflow")
	assert_almost_eq(state.get_progress("v2_magic_sacred_1"), 4.0, 0.001, "o projeto pausado não perdeu nada")

func test_non_positive_or_invalid_knowledge_is_ignored():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(-5.0)
	state.add_knowledge(0.0)
	state.add_knowledge(NAN)
	state.add_knowledge(INF)
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 0.0, 0.001)
	assert_almost_eq(state.research_overflow, 0.0, 0.001)
	assert_true(state.progress_by_id.is_empty(), "não cria entradas de progresso zeradas")

# --- Capstones ----------------------------------------------------------------------------------

func test_supreme_army_needs_two_doctrines_completed_to_n9():
	assert_false(state.is_available("v2_supreme_army"), "0 Doutrinas")
	state.debug_complete_branch(MILITARY, "guardian")
	assert_false(state.is_available("v2_supreme_army"), "1 Doutrina")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2))
	state.debug_complete_branch(MILITARY, "cavalry")
	assert_true(state.is_available("v2_supreme_army"), "2 Doutrinas distintas")
	assert_eq(state.node_state("v2_supreme_army"), States.AVAILABLE)

func test_transcendence_needs_two_schools_completed_to_n9():
	state.debug_complete_branch(MAGIC, "sacred")
	assert_false(state.is_available("v2_transcendence"))
	state.debug_complete_branch(MAGIC, "arcanism")
	assert_true(state.is_available("v2_transcendence"))

func test_capstone_is_not_unlocked_by_nine_random_nodes_or_by_n8s():
	# Nove nós concluídos que NÃO são duas linhas completas.
	for branch in ["guardian", "warrior", "ranger", "cavalry", "rogue"]:
		for node in V2ResearchDatabase.nodes_for_branch(MILITARY, branch):
			if node.tier <= 8:
				assert_true(state.complete_research(node.id) or state.is_completed(node.id))
	assert_gt(state.completed_ids.size(), 9)
	assert_false(state.is_available("v2_supreme_army"), "40 nós, mas nenhuma Doutrina chegou ao N9")
	# Só uma chega ao N9: ainda bloqueado.
	state.complete_research("v2_doctrine_guardian_9")
	assert_false(state.is_available("v2_supreme_army"))

func test_capstone_counts_only_its_own_tree():
	state.debug_complete_branch(MAGIC, "sacred")
	state.debug_complete_branch(MAGIC, "infernal")
	assert_true(state.is_available("v2_transcendence"))
	assert_false(state.is_available("v2_supreme_army"), "duas Escolas não liberam o Exército Supremo")
	state.debug_complete_branch(MILITARY, "guardian")
	assert_false(state.is_available("v2_supreme_army"), "uma Doutrina + duas Escolas: ainda não")

func test_capstone_still_has_to_be_paid_and_grants_nothing_else():
	state.debug_complete_branch(MILITARY, "guardian")
	state.debug_complete_branch(MILITARY, "warrior")
	assert_false(state.is_completed("v2_supreme_army"), "liberar não conclui")

	assert_true(state.select_research("v2_supreme_army"))
	state.add_knowledge(V2ResearchDatabase.CAPSTONE_COST - 1.0)
	assert_false(state.is_completed("v2_supreme_army"))
	state.add_knowledge(1.0)

	assert_true(state.is_completed("v2_supreme_army"))
	assert_eq(state.active_id, "")

func test_capstone_cannot_be_selected_while_locked():
	assert_false(state.select_research("v2_supreme_army"))
	assert_false(state.select_research("v2_transcendence"))
	assert_eq(state.active_id, "")

# --- Estado por civilização ------------------------------------------------------------------------

func test_each_civilization_has_an_independent_state():
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	assert_not_same(human.v2_research, rival.v2_research)

	human.v2_research.select_research("v2_doctrine_guardian_1")
	human.v2_research.add_knowledge(5.0)
	rival.v2_research.select_research("v2_magic_infernal_1")
	rival.v2_research.add_knowledge(2.0)

	assert_eq(human.v2_research.active_id, "v2_doctrine_guardian_1")
	assert_eq(rival.v2_research.active_id, "v2_magic_infernal_1")
	assert_almost_eq(human.v2_research.get_progress("v2_magic_infernal_1"), 0.0, 0.001)
	assert_almost_eq(rival.v2_research.get_progress("v2_doctrine_guardian_1"), 0.0, 0.001)
	human.release_relations()
	rival.release_relations()

func test_state_can_be_looked_up_by_player_or_by_civilization_index():
	var original_players := GameManager.players
	var first := PlayerData.new(CivilizationData.new())
	var second := PlayerData.new(CivilizationData.new())
	GameManager.players = [first, second]

	assert_same(V2ResearchState.for_player(first), first.v2_research)
	assert_same(V2ResearchState.for_index(1), second.v2_research)
	assert_null(V2ResearchState.for_index(2))
	assert_null(V2ResearchState.for_index(-1))
	assert_null(V2ResearchState.for_player(null))
	GameManager.players = original_players

# --- Sinais ------------------------------------------------------------------------------------------------

func test_selection_progress_and_cancel_emit_their_signals():
	watch_signals(state)

	state.select_research("v2_doctrine_guardian_1")
	assert_signal_emitted_with_parameters(state, "research_selected", ["v2_doctrine_guardian_1", ""])

	state.add_knowledge(4.0)
	assert_signal_emitted_with_parameters(state, "research_progress_changed", ["v2_doctrine_guardian_1", 4.0, V2ResearchDatabase.BRANCH_TIER_COSTS[0]])

	state.select_research("v2_magic_sacred_1")
	assert_signal_emitted_with_parameters(state, "research_selected", ["v2_magic_sacred_1", "v2_doctrine_guardian_1"])

	state.cancel_active_research()
	assert_signal_emitted_with_parameters(state, "research_cancelled", ["v2_magic_sacred_1"])

func test_completion_emits_completed_and_the_newly_available_nodes_once():
	state.select_research("v2_doctrine_guardian_1")
	watch_signals(state)

	state.add_knowledge(10.0)

	assert_signal_emit_count(state, "research_completed", 1)
	assert_signal_emitted_with_parameters(state, "research_completed", ["v2_doctrine_guardian_1"])
	assert_signal_emit_count(state, "research_availability_changed", 1)
	assert_signal_not_emitted(state, "research_progress_changed", "concluir não emite progresso parcial")
	var newly: Array = get_signal_parameters(state, "research_availability_changed")[0]
	assert_true("v2_doctrine_guardian_2" in newly)
	assert_false("v2_doctrine_guardian_1" in newly, "o concluído não é 'novo disponível'")

func test_the_completed_signal_is_emitted_after_the_state_is_final():
	var seen := {}
	state.research_completed.connect(func(id):
		seen["is_completed"] = state.is_completed(id)
		seen["active"] = state.active_id
		seen["next_available"] = state.is_available("v2_doctrine_guardian_2"))
	state.select_research("v2_doctrine_guardian_1")

	state.add_knowledge(10.0)

	assert_true(seen.is_completed)
	assert_eq(seen.active, "")
	assert_true(seen.next_available)

func test_capstone_availability_is_reported_when_the_second_branch_completes():
	state.debug_complete_branch(MILITARY, "guardian")
	for node in V2ResearchDatabase.nodes_for_branch(MILITARY, "warrior"):
		if node.tier < 9:
			state.complete_research(node.id)
	watch_signals(state)

	state.complete_research("v2_doctrine_warrior_9")

	var newly: Array = get_signal_parameters(state, "research_availability_changed")[0]
	assert_true("v2_supreme_army" in newly)

func test_overflow_changes_are_announced():
	watch_signals(state)
	state.add_knowledge(6.0)
	assert_signal_emitted_with_parameters(state, "research_overflow_changed", [6.0])
	state.select_research("v2_doctrine_guardian_1")
	assert_signal_emitted_with_parameters(state, "research_overflow_changed", [0.0])

func test_reset_clears_everything_and_announces_it():
	_pay_off("v2_doctrine_guardian_1")
	state.select_research("v2_doctrine_guardian_2")
	state.add_knowledge(3.0)
	watch_signals(state)

	state.reset()

	assert_signal_emitted(state, "state_reset")
	assert_eq(state.to_dict(), V2ResearchState.new().to_dict())

func test_state_has_no_per_frame_processing():
	assert_false(state.has_method("_process"))
	assert_false(state.has_method("_physics_process"))

# --- Persistência: ida e volta ------------------------------------------------------------------------------------

func _through_json(data: Dictionary) -> Variant:
	return JSON.parse_string(JSON.stringify(data))

func test_dict_round_trip_through_json_preserves_everything():
	_pay_off("v2_doctrine_guardian_1")
	_pay_off("v2_magic_sacred_1")
	state.select_research("v2_doctrine_guardian_2")
	state.add_knowledge(7.5)
	state.select_research("v2_magic_infernal_1")
	state.add_knowledge(2.0)
	state.select_research("v2_infrastructure_academy_1")
	state.cancel_active_research()
	state.add_knowledge(4.0) # overflow

	var loaded := V2ResearchState.from_variant(_through_json(state.to_dict()))

	assert_eq(loaded.active_id, state.active_id)
	assert_eq(loaded.get_completed_ids(), state.get_completed_ids())
	assert_eq(loaded.progress_by_id, state.progress_by_id)
	assert_almost_eq(loaded.research_overflow, state.research_overflow, 0.001)
	assert_almost_eq(loaded.get_progress("v2_doctrine_guardian_2"), 7.5, 0.001)

func test_active_project_survives_a_round_trip_and_can_continue():
	state.select_research("v2_doctrine_guardian_1")
	state.add_knowledge(6.0)

	var loaded := V2ResearchState.from_variant(_through_json(state.to_dict()))
	loaded.add_knowledge(4.0)

	assert_true(loaded.is_completed("v2_doctrine_guardian_1"))

func test_capstone_availability_is_recomputed_after_load():
	state.debug_complete_branch(MAGIC, "sacred")
	state.debug_complete_branch(MAGIC, "druidism")

	var loaded := V2ResearchState.from_variant(_through_json(state.to_dict()))

	assert_true(loaded.is_available("v2_transcendence"))
	assert_false(loaded.is_available("v2_supreme_army"))

func test_load_dict_updates_in_place_and_keeps_signal_connections():
	var other := V2ResearchState.new()
	other.complete_research("v2_doctrine_guardian_1")
	other.select_research("v2_doctrine_guardian_2")
	other.add_knowledge(5.0)
	watch_signals(state)

	state.load_dict(other.to_dict())

	assert_signal_emit_count(state, "state_reset", 1, "um único aviso de estado novo")
	assert_signal_not_emitted(state, "research_completed", "carregar não re-dispara conclusões")
	assert_eq(state.active_id, "v2_doctrine_guardian_2")
	watch_signals(state)
	state.add_knowledge(1.0)
	assert_signal_emitted(state, "research_progress_changed", "a conexão continua viva depois do load")

# --- Persistência: dados ruins --------------------------------------------------------------------------------------------

func test_a_save_without_the_v2_block_loads_as_empty_state():
	state.select_research("v2_doctrine_guardian_1")
	state.load_dict(null)
	assert_eq(state.to_dict(), V2ResearchState.new().to_dict())
	state.load_dict({})
	assert_eq(state.to_dict(), V2ResearchState.new().to_dict())

func test_corrupt_top_level_data_never_crashes_and_yields_empty_state():
	for junk in ["texto", 42, 3.5, [], [1, 2, 3], true]:
		state.load_dict(junk)
		assert_eq(state.to_dict(), V2ResearchState.new().to_dict(), "lixo: %s" % str(junk))

func test_wrongly_typed_fields_are_ignored_field_by_field():
	state.load_dict({
		"active_id": 123,
		"completed_ids": "v2_doctrine_guardian_1",
		"progress_by_id": [1, 2],
		"research_overflow": "muito",
	})
	assert_eq(state.to_dict(), V2ResearchState.new().to_dict())

	state.load_dict({
		"completed_ids": [null, 5, {}, "v2_doctrine_guardian_1"],
		"progress_by_id": {"v2_doctrine_guardian_2": "x", 7: 3.0, "v2_magic_sacred_1": {}},
	})
	assert_eq(state.get_completed_ids(), ["v2_doctrine_guardian_1"], "só o id válido")
	assert_true(state.progress_by_id.is_empty())

func test_unknown_v2_ids_are_ignored():
	state.load_dict({
		"active_id": "v2_doctrine_guardian_99",
		"completed_ids": ["v2_doctrine_guardian_1", "v2_removido_em_outra_versao", "guarda"],
		"progress_by_id": {"v2_removido_em_outra_versao": 5.0, "v2_doctrine_guardian_2": 4.0},
		"research_overflow": 2.0,
	})
	assert_eq(state.get_completed_ids(), ["v2_doctrine_guardian_1"])
	assert_eq(state.progress_by_id, {"v2_doctrine_guardian_2": 4.0})
	assert_eq(state.active_id, "")
	assert_almost_eq(state.research_overflow, 2.0, 0.001)

func test_progress_is_clamped_to_zero_and_to_the_cost():
	state.load_dict({"progress_by_id": {
		"v2_doctrine_guardian_1": -5.0,     # negativo -> descartado
		"v2_magic_sacred_1": 9999.0,        # acima do custo (10) -> limitado
		"v2_magic_infernal_1": 0.0,         # zero -> não guarda
	}})
	assert_false(state.progress_by_id.has("v2_doctrine_guardian_1"))
	assert_false(state.progress_by_id.has("v2_magic_infernal_1"))
	assert_almost_eq(state.get_progress("v2_magic_sacred_1"), V2ResearchDatabase.BRANCH_TIER_COSTS[0], 0.001)

func test_negative_or_non_finite_stored_knowledge_becomes_zero():
	state.load_dict({"research_overflow": -8.0})
	assert_almost_eq(state.research_overflow, 0.0, 0.001)
	state.load_dict({"research_overflow": INF})
	assert_almost_eq(state.research_overflow, 0.0, 0.001)

func test_an_invalid_active_id_is_dropped_but_progress_is_kept():
	# Bloqueado (exige N1 que não está concluído).
	state.load_dict({"active_id": "v2_doctrine_guardian_2", "progress_by_id": {"v2_doctrine_guardian_2": 5.0}})
	assert_eq(state.active_id, "", "N2 sem N1 não pode ser o ativo")
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_2"), 5.0, 0.001, "o progresso é preservado")

func test_a_completed_node_can_never_be_the_active_project_after_load():
	state.load_dict({
		"active_id": "v2_doctrine_guardian_1",
		"completed_ids": ["v2_doctrine_guardian_1"],
		"progress_by_id": {"v2_doctrine_guardian_1": 4.0},
	})
	assert_eq(state.active_id, "")
	assert_false(state.progress_by_id.has("v2_doctrine_guardian_1"), "concluído não guarda progresso")

func test_an_active_project_saved_at_full_cost_completes_on_load():
	state.load_dict({"active_id": "v2_doctrine_guardian_1", "progress_by_id": {"v2_doctrine_guardian_1": 10.0}})
	assert_true(state.is_completed("v2_doctrine_guardian_1"))
	assert_eq(state.active_id, "")

func test_banked_knowledge_with_an_active_project_is_applied_on_load():
	state.load_dict({
		"active_id": "v2_doctrine_guardian_1",
		"progress_by_id": {"v2_doctrine_guardian_1": 3.0},
		"research_overflow": 4.0,
	})
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_1"), 7.0, 0.001)
	assert_almost_eq(state.research_overflow, 0.0, 0.001, "invariante: overflow só existe sem projeto ativo")

func test_completed_ids_of_a_capstone_do_not_require_repairing_its_prerequisites():
	# Não "conserta" estado por mudança de estrutura: o que está salvo e existe, fica.
	state.load_dict({"completed_ids": ["v2_supreme_army"]})
	assert_true(state.is_completed("v2_supreme_army"))
