extends GutTest

## Aetherlands V2, Fase 12 — conexão do capstone universal Exército Supremo. O requisito
## estrutural (duas Doutrinas completas em N9) já existia desde a Fase 0/1 e NÃO muda aqui
## (ver test_v2_doctrine_content.gd:test_supreme_army_requirement_and_rule_are_unchanged);
## esta fase só faz o nó, ao ser concluído, desbloquear de verdade o ACESSO à via de
## Supremacia Militar — pelo MESMO pipeline (V2ResearchState -> V2UnlockSystem) dos 54
## nós normais, sem sistema paralelo, sem estado novo salvo e sem buff/unidade/vitória.

const CAPSTONE := "v2_supreme_army"
const ACCESS_ID := "v2_military_supremacy_access"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE

var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]

func before_each():
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players

func after_each():
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	return player

## Um rival de teste com uma cidade real -- necessário pra check_victories() não achar
## "só sobrou uma civilização" (VictoryConditions.is_dominance_achieved é vacuamente
## verdadeiro sem NENHUM outro jogador com cidade/unidade — caso degenerado documentado
## no próprio VictoryConditions, não uma condição real de vitória).
func _rival_with_a_city() -> PlayerData:
	var rival := _player()
	var city := City.new()
	city.owner_player = rival
	rival.cities.append(city)
	_cities.append(city)
	return rival

func _complete_two_branches(player: PlayerData, a: String, b: String) -> void:
	player.v2_research.debug_complete_branch(MILITARY, a)
	player.v2_research.debug_complete_branch(MILITARY, b)

# --- O capstone está conectado pelo mesmo mecanismo dos 54 nós normais --------------------------

func test_the_capstone_node_is_gameplay_connected():
	var node := V2ResearchDatabase.get_node(CAPSTONE)
	assert_true(node.gameplay_connected)
	assert_eq(node.unlock_type, "victory_capstone")
	assert_eq(node.unlock_id, ACCESS_ID)

func test_the_capstone_unlock_id_is_in_the_single_connected_list_no_parallel_mechanism():
	assert_true(ACCESS_ID in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true("victory_capstone" in V2UnlockSystem.CONNECTED_TYPES)
	# Nenhuma classe "MilitaryCapstoneUnlockSystem" ou equivalente existe.
	assert_false(FileAccess.file_exists("res://scripts/core/MilitaryCapstoneUnlockSystem.gd"))

func test_gameplay_connected_is_structural_not_per_civilization():
	# É metadata do NÓ (compartilhado, estático) -- vale mesmo pra uma civilização que
	# nunca pesquisou nada, ao contrário de "acesso desbloqueado", que É por civilização.
	var fresh := _player()
	assert_true(V2ResearchDatabase.get_node(CAPSTONE).gameplay_connected)
	assert_false(fresh.has_unlocked(ACCESS_ID), "sem pesquisar, o ACESSO continua bloqueado")

# --- Acesso é DERIVADO da pesquisa, nunca um segundo estado -------------------------------------

func test_access_is_false_before_research_and_true_only_after_completing_the_capstone():
	var player := _player()
	assert_false(player.has_unlocked(ACCESS_ID))
	assert_false(V2UnlockSystem.is_unlocked(player, ACCESS_ID))
	_complete_two_branches(player, "guardian", "warrior")
	assert_true(player.v2_research.is_available(CAPSTONE))
	assert_false(player.has_unlocked(ACCESS_ID), "disponível != concluído")
	player.v2_research.complete_research(CAPSTONE)
	assert_true(player.has_unlocked(ACCESS_ID))
	assert_true(V2UnlockSystem.is_unlocked(player, ACCESS_ID))
	assert_true(ACCESS_ID in V2UnlockSystem.unlocked_ids(player))

func test_access_query_has_two_equivalent_forms():
	var player := _player()
	_complete_two_branches(player, "ranger", "cavalry")
	player.v2_research.complete_research(CAPSTONE)
	assert_eq(player.has_unlocked(ACCESS_ID), V2UnlockSystem.is_unlocked(player, ACCESS_ID))
	assert_true(player.has_unlocked(ACCESS_ID))

func test_access_never_leaks_between_civilizations():
	var a := _player()
	var b := _player()
	_complete_two_branches(a, "guardian", "warrior")
	a.v2_research.complete_research(CAPSTONE)
	assert_true(a.has_unlocked(ACCESS_ID))
	assert_false(b.has_unlocked(ACCESS_ID), "cada civilização tem o seu v2_research")

func test_no_new_persistent_field_the_pipeline_reuses_v2research_state():
	# Nenhum campo "military_supremacy_unlocked" ou equivalente existe em PlayerData/V2ResearchState.
	assert_false("military_supremacy_unlocked" in _player())
	assert_false("military_supremacy_unlocked" in V2ResearchState.new())

# --- Requisito de pesquisa (2 Doutrinas em N9) -- inalterado nesta fase --------------------------

func test_capstone_progress_0_of_2_1_of_2_and_2_of_2():
	var player := _player()
	assert_eq(V2ResearchDatabase.capstone_progress(CAPSTONE, player.v2_research.completed_ids), Vector2i(0, 2))
	assert_false(player.v2_research.is_available(CAPSTONE))
	player.v2_research.debug_complete_branch(MILITARY, "rogue")
	assert_eq(V2ResearchDatabase.capstone_progress(CAPSTONE, player.v2_research.completed_ids), Vector2i(1, 2))
	assert_false(player.v2_research.is_available(CAPSTONE))
	player.v2_research.debug_complete_branch(MILITARY, "siege")
	assert_eq(V2ResearchDatabase.capstone_progress(CAPSTONE, player.v2_research.completed_ids), Vector2i(2, 2))
	assert_true(player.v2_research.is_available(CAPSTONE))

func test_completing_the_same_branch_twice_never_counts_as_two():
	var player := _player()
	player.v2_research.debug_complete_branch(MILITARY, "guardian")
	player.v2_research.debug_complete_branch(MILITARY, "guardian") # no-op: já concluída
	assert_eq(V2ResearchDatabase.capstone_progress(CAPSTONE, player.v2_research.completed_ids), Vector2i(1, 2))
	assert_false(player.v2_research.is_available(CAPSTONE))

func test_any_pair_of_the_six_doctrines_unlocks_the_capstone():
	var branches := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]
	for i in branches.size():
		for j in range(i + 1, branches.size()):
			var player := _player()
			_complete_two_branches(player, branches[i], branches[j])
			assert_true(player.v2_research.is_available(CAPSTONE), "%s + %s" % [branches[i], branches[j]])

func test_all_six_complete_still_shows_2_of_2_not_6_of_2():
	var player := _player()
	for branch in ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]:
		player.v2_research.debug_complete_branch(MILITARY, branch)
	assert_eq(V2ResearchDatabase.capstone_progress(CAPSTONE, player.v2_research.completed_ids), Vector2i(2, 2), "o requisito continua sendo 2, mesmo com as 6 completas")

func test_capstone_does_not_require_producing_or_keeping_the_legendary_alive():
	# Concluir o N9 (pesquisa) conta como Doutrina completa -- não exige a Lendária viva/em produção.
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	assert_true(player.v2_research.is_available(CAPSTONE))
	assert_false(V2LegendarySystem.has_active_legendary(player))

func test_capstone_requirement_is_unchanged_and_cost_is_balanced():
	var node := V2ResearchDatabase.get_node(CAPSTONE)
	assert_eq(node.requirement, {"type": "complete_branches", "tree_type": MILITARY, "branch_count": 2, "at_tier": 9})
	assert_eq(node.cost, V2ResearchDatabase.CAPSTONE_COST)

# --- Pesquisa real do capstone (fluxo completo) --------------------------------------------------

func test_researching_the_capstone_end_to_end_applies_the_unlock():
	var player := _player()
	_complete_two_branches(player, "guardian", "cavalry")
	assert_true(player.v2_research.select_research(CAPSTONE))
	assert_eq(player.v2_research.active_id, CAPSTONE)
	player.v2_research.add_knowledge(V2ResearchDatabase.CAPSTONE_COST - 1.0)
	assert_false(player.v2_research.is_completed(CAPSTONE), "ainda falta 1")
	assert_false(player.has_unlocked(ACCESS_ID))
	player.v2_research.add_knowledge(1.0)
	assert_true(player.v2_research.is_completed(CAPSTONE))
	assert_true(player.has_unlocked(ACCESS_ID), "unlock aplicado ao concluir o custo integral")

func test_the_capstone_competes_for_the_same_single_research_slot():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	assert_true(player.v2_research.select_research(CAPSTONE))
	assert_true(player.v2_research.select_research("v2_magic_sacred_1"), "troca de projeto -- sem slot especial de capstone")
	assert_eq(player.v2_research.active_id, "v2_magic_sacred_1")
	assert_true(player.v2_research.select_research(CAPSTONE), "volta e continua de onde parou")

# --- Toast / feedback (só o humano, sem cinemática/tela de vitória) ------------------------------

func test_completing_the_capstone_emits_a_toast_for_the_human_player_only():
	var player := _player()
	GameManager.human_player = player
	_complete_two_branches(player, "guardian", "warrior")
	watch_signals(EventBus)
	player.v2_research.complete_research(CAPSTONE)
	assert_signal_emitted(EventBus, "notify")
	var params = get_signal_parameters(EventBus, "notify", 0)
	assert_true(String(params[0]).contains("Exército Supremo"), params[0])
	assert_true(String(params[0]).begins_with("Via de vitória desbloqueada"), params[0])

func test_completing_the_capstone_does_not_notify_for_a_rival():
	var rival := _player()
	GameManager.human_player = _player()
	_complete_two_branches(rival, "guardian", "warrior")
	watch_signals(EventBus)
	rival.v2_research.complete_research(CAPSTONE)
	assert_signal_not_emitted(EventBus, "notify")

func test_announcement_text_is_generic_reusable_by_transcendence_later():
	assert_eq(V2UnlockSystem.announcement_text("victory_capstone", "Exército Supremo"), "Via de vitória desbloqueada: Exército Supremo")
	assert_eq(V2UnlockSystem.announcement_text("victory_capstone", "Transcendência"), "Via de vitória desbloqueada: Transcendência", "mesma função, outro display_name -- sem novo mecanismo")

# --- Tooltip: requisito/progresso antes, "desbloqueia acesso" disponível, "desbloqueado" concluído ----

func test_tooltip_before_completion_explains_the_requirement_and_cost():
	var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(CAPSTONE), false)
	assert_true(tooltip.contains("Requer: 2 Doutrinas completas (N9)"))
	assert_true(tooltip.contains("Custo: %d" % int(V2ResearchDatabase.CAPSTONE_COST)))
	assert_true(tooltip.contains("Desbloqueia o acesso à Supremacia Militar."))
	assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))

func test_tooltip_after_completion_shows_the_access_as_unlocked():
	var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(CAPSTONE), true)
	assert_true(tooltip.contains("Acesso à Supremacia Militar desbloqueado."))
	assert_false(tooltip.contains("Desbloqueia o acesso"), "não mostra as duas frases ao mesmo tempo")

## Fase 16: a condição territorial foi conectada (V2VictoryConditions) — o tooltip agora diz a regra real.
func test_tooltip_always_states_the_connected_territorial_rule():
	for completed in [false, true]:
		var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(CAPSTONE), completed).replace("\n", " ")
		assert_true(tooltip.contains("Vitória: para cada rival, mantenha uma Cidade III+ conquistada dele (ou elimine-o)."), "completed=%s" % completed)
		assert_false(tooltip.contains("será conectada"), "completed=%s" % completed)

func test_tooltip_lines_stay_within_the_readable_width_like_every_other_node():
	for completed in [false, true]:
		var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(CAPSTONE), completed)
		for line in tooltip.split("\n"):
			assert_lt(line.length(), 90, "completed=%s: %s" % [completed, line])

func test_research_board_passes_the_real_completion_state_into_the_tooltip():
	var board := V2ResearchBoard.new()
	add_child_autofree(board)
	var state := V2ResearchState.new()
	board.bind_state(state)
	state.debug_complete_branch(MILITARY, "guardian")
	state.debug_complete_branch(MILITARY, "warrior")
	await get_tree().process_frame
	var card: Control = board.card_for(CAPSTONE)
	assert_true(card.tooltip_text.contains("Desbloqueia o acesso à Supremacia Militar."), card.tooltip_text)
	state.complete_research(CAPSTONE)
	await get_tree().process_frame
	card = board.card_for(CAPSTONE)
	assert_true(card.tooltip_text.contains("Acesso à Supremacia Militar desbloqueado."), card.tooltip_text)

# --- Não é unidade/prédio/técnica/Lendária/buff; não altera slot/combate -------------------------

func test_capstone_gives_no_combat_bonus_researching_it_changes_no_unit_stats():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	var before := UnitDatabase.create_unit("v2_unit_sentinel")
	player.v2_research.complete_research(CAPSTONE)
	var after := UnitDatabase.create_unit("v2_unit_sentinel")
	assert_eq([before.attack, before.defense, before.max_hp, before.movement_points], [after.attack, after.defense, after.max_hp, after.movement_points])

func test_capstone_does_not_touch_the_legendary_slot():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	var before := V2LegendarySystem.max_active()
	player.v2_research.complete_research(CAPSTONE)
	assert_eq(V2LegendarySystem.max_active(), before, "1 continua sendo o limite")
	assert_false(V2LegendarySystem.is_legendary_kind(ACCESS_ID))

func test_capstone_is_not_a_unit_building_technique_or_legendary_candidate():
	var node := V2ResearchDatabase.get_node(CAPSTONE)
	assert_ne(node.unlock_type, "unit")
	assert_ne(node.unlock_type, "building")
	assert_ne(node.unlock_type, "technique")
	assert_ne(node.unlock_type, "legendary_candidate")
	assert_false(ACCESS_ID in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	assert_null(BuildingDatabase.get_building(ACCESS_ID))

# --- check_victories: NUNCA dispara vitória, e nunca toca a Supremacia V1 (VictoryCampaign) -------

func test_check_victories_stays_playing_after_researching_the_capstone():
	var player := _rival_with_a_city() # também precisa de uma cidade, senão vira o "outro lado" da vitória vazia
	GameManager.human_player = player
	GameManager.rival_players = [_rival_with_a_city()]
	_complete_two_branches(player, "guardian", "warrior")
	watch_signals(EventBus)
	player.v2_research.complete_research(CAPSTONE)
	assert_true(player.has_unlocked(ACCESS_ID))
	var before_state := GameManager.state
	GameManager.check_victories()
	assert_eq(GameManager.state, before_state, "nenhuma transição de estado")
	assert_signal_not_emitted(EventBus, "victory_achieved")

func test_the_v2_capstone_never_touches_the_v1_supremacy_tech_or_researched_techs():
	# VictoryCampaign.supremacy_achieved (V1, "victory_rules_version >= 2") lê
	# player.researched_techs.has("exercito_supremo") -- um id e um dicionário TOTALMENTE
	# diferentes de v2_research/v2_supreme_army. As duas nunca devem se confundir.
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	player.v2_research.complete_research(CAPSTONE)
	assert_false("researched_techs" in player, "Fase 25: estado V1 removido")

# --- Save / load: acesso é derivado, sem novo campo de save --------------------------------------

func test_save_load_round_trip_preserves_partial_progress_and_then_completes():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	player.v2_research.select_research(CAPSTONE)
	player.v2_research.add_knowledge(250.0)
	var block := player.v2_research.to_dict()
	var reloaded := V2ResearchState.from_variant(JSON.parse_string(JSON.stringify(block)))
	assert_almost_eq(reloaded.get_progress(CAPSTONE), 250.0, 0.001)
	assert_eq(reloaded.active_id, CAPSTONE)
	assert_false(reloaded.is_completed(CAPSTONE))
	reloaded.add_knowledge(350.0)
	assert_true(reloaded.is_completed(CAPSTONE))
	var reloaded_player := PlayerData.new(CivilizationData.new())
	_players.append(reloaded_player)
	reloaded_player.v2_research.load_dict(reloaded.to_dict())
	assert_true(reloaded_player.has_unlocked(ACCESS_ID), "acesso continua true por derivação, sem campo novo")

func test_an_old_save_without_the_capstone_completed_keeps_access_false():
	var old_block := {
		"active_id": "",
		"completed_ids": ["v2_doctrine_guardian_1"],
		"progress_by_id": {},
		"research_overflow": 0.0,
	}
	var player := _player()
	player.v2_research.load_dict(JSON.parse_string(JSON.stringify(old_block)))
	assert_false(player.has_unlocked(ACCESS_ID))

func test_save_format_has_no_new_field_for_the_capstone():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	player.v2_research.complete_research(CAPSTONE)
	var block := player.v2_research.to_dict()
	assert_eq(block.keys(), ["active_id", "completed_ids", "progress_by_id", "research_overflow"], "mesmas 4 chaves da Fase 1 -- capstone concluído vive em completed_ids, como qualquer nó")

# --- Reset de debug -------------------------------------------------------------------------------

func test_debug_reset_removes_the_derived_access_without_destroying_anything_else():
	var player := _player()
	_complete_two_branches(player, "guardian", "warrior")
	player.v2_research.complete_research(CAPSTONE)
	assert_true(player.has_unlocked(ACCESS_ID))
	player.v2_research.reset()
	assert_false(player.has_unlocked(ACCESS_ID), "reset limpa completed_ids -> a pesquisa não existe mais -> acesso derivado some")
	assert_true(V2ResearchDatabase.get_node(CAPSTONE).gameplay_connected, "a conexão estrutural do nó não é afetada por reset de UMA civilização")
