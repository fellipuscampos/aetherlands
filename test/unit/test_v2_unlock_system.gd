extends GutTest

## V2UnlockSystem (Aetherlands V2, Fase 3): a ponte entre research_completed e o
## gameplay. Cobre o pipeline de unlock (sinal -> unlock_applied), a
## disponibilidade DERIVADA (is_unlocked), a idempotência, a isolação entre
## civilizações e o aviso ao jogador humano. O gameplay em si (Salão, Escudeiro)
## é testado em test_v2_guardian_hall.gd / test_v2_shieldbearer.gd.

const GUARDIAN := "guardian"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE

var _owned_players: Array[PlayerData] = []
var _original_human_player: PlayerData

func before_each():
	_original_human_player = GameManager.human_player

func after_each():
	GameManager.human_player = _original_human_player
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()

func _new_player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_owned_players.append(player)
	return player

func _complete_through(player: PlayerData, tier: int) -> void:
	for n in range(1, tier + 1):
		assert_true(player.v2_research.complete_research("v2_doctrine_guardian_%d" % n), "N%d" % n)

# --- Disponibilidade derivada -------------------------------------------------------------------

func test_nothing_is_unlocked_for_a_fresh_civilization():
	var player := _new_player()
	for unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS:
		assert_false(V2UnlockSystem.is_unlocked(player, unlock_id), unlock_id)
	assert_eq(V2UnlockSystem.unlocked_ids(player), [])

func test_each_connected_unlock_follows_its_own_research_node():
	var player := _new_player()
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_true(V2UnlockSystem.is_unlocked(player, "v2_doctrine_guardian"))
	assert_false(V2UnlockSystem.is_unlocked(player, "v2_building_guardian_hall"))
	assert_false(V2UnlockSystem.is_unlocked(player, "v2_unit_shieldbearer"))

	player.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_true(V2UnlockSystem.is_unlocked(player, "v2_building_guardian_hall"))
	assert_false(V2UnlockSystem.is_unlocked(player, "v2_unit_shieldbearer"), "o Escudeiro é o N3")

	player.v2_research.complete_research("v2_doctrine_guardian_3")
	assert_true(V2UnlockSystem.is_unlocked(player, "v2_unit_shieldbearer"))
	assert_eq(V2UnlockSystem.unlocked_ids(player), ["v2_doctrine_guardian", "v2_building_guardian_hall", "v2_unit_shieldbearer"])

func test_ids_that_are_not_v2_have_no_v2_gate():
	var player := _new_player()
	for kind in ["warrior", "men_at_arms", "barracks", "granary", "settler"]:
		assert_true(V2UnlockSystem.is_unlocked(player, kind), kind)
		assert_null(V2UnlockSystem.node_for_unlock(kind), kind)

func test_a_v2_id_is_fail_closed_for_no_player_and_for_unknown_ids():
	assert_false(V2UnlockSystem.is_unlocked(null, "v2_unit_shieldbearer"))
	assert_false(V2UnlockSystem.is_unlocked(_new_player(), "v2_unit_inexistente"))

func test_unlock_is_per_civilization():
	var a := _new_player()
	var b := _new_player()
	_complete_through(a, 3)
	assert_true(V2UnlockSystem.is_unlocked(a, "v2_unit_shieldbearer"))
	assert_false(V2UnlockSystem.is_unlocked(b, "v2_unit_shieldbearer"), "outra civilização não herda o unlock")
	assert_false(b.has_unlocked("v2_unit_shieldbearer"))

func test_unlock_survives_a_state_round_trip_without_any_extra_saved_state():
	var player := _new_player()
	_complete_through(player, 3)
	var restored := _new_player()
	restored.v2_research.load_dict(player.v2_research.to_dict())
	assert_true(V2UnlockSystem.is_unlocked(restored, "v2_unit_shieldbearer"))
	assert_true(V2UnlockSystem.is_unlocked(restored, "v2_building_guardian_hall"))
	assert_true(restored.has_unlocked("v2_unit_shieldbearer"))

func test_player_has_unlocked_is_fail_closed_for_v2_units_and_v1_kinds():
	var player := _new_player()
	assert_false(player.has_unlocked("v2_unit_shieldbearer"))
	# Fase 25: fora da V2 só o núcleo civil (Colonizador) é liberado; tropa V1 nunca.
	assert_true(player.has_unlocked("settler"))
	assert_false(player.has_unlocked("warrior"))
	assert_false(player.has_unlocked("men_at_arms"))
	_complete_through(player, 3)
	assert_true(player.has_unlocked("v2_unit_shieldbearer"))
	assert_false(player.has_unlocked("warrior"), "pesquisa V2 não libera nada da V1")
	assert_false(player.has_unlocked("men_at_arms"), "pesquisa V2 não libera nada da V1")

# --- Pipeline: research_completed -> unlock_applied ------------------------------------------------

func test_completing_n1_to_n3_emits_unlock_applied_with_the_node_own_unlock_data():
	var player := _new_player()
	watch_signals(player.v2_unlocks)
	_complete_through(player, 3)

	assert_signal_emit_count(player.v2_unlocks, "unlock_applied", 3)
	assert_signal_emitted_with_parameters(player.v2_unlocks, "unlock_applied", ["v2_doctrine_guardian_1", "doctrine", "v2_doctrine_guardian"], 0)
	assert_signal_emitted_with_parameters(player.v2_unlocks, "unlock_applied", ["v2_doctrine_guardian_2", "building", "v2_building_guardian_hall"], 1)
	assert_signal_emitted_with_parameters(player.v2_unlocks, "unlock_applied", ["v2_doctrine_guardian_3", "unit", "v2_unit_shieldbearer"], 2)

func test_unknown_nodes_apply_nothing_now_that_all_128_are_connected():
	var player := _new_player()
	_complete_through(player, 9) # a Doutrina do Guardião (N1-N9) já é toda conectada
	watch_signals(player.v2_unlocks)
	assert_false(player.v2_unlocks.apply_unlock("v2_nao_existe"))
	assert_signal_not_emitted(player.v2_unlocks, "unlock_applied")

func test_apply_unlock_is_idempotent_and_ignores_unknown_or_unconnected_nodes():
	var player := _new_player()
	_complete_through(player, 3)
	watch_signals(player.v2_unlocks)

	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_guardian_3"), "já aplicado quando o nó foi concluído")
	assert_false(player.v2_unlocks.apply_unlock("v2_doctrine_guardian_2"))
	assert_false(player.v2_unlocks.apply_unlock("v2_nao_existe"))
	assert_false(player.v2_unlocks.apply_unlock(""))
	assert_signal_not_emitted(player.v2_unlocks, "unlock_applied")
	assert_true(V2UnlockSystem.is_unlocked(player, "v2_unit_shieldbearer"), "reaplicar não muda a disponibilidade")

func test_completing_an_already_completed_node_does_not_apply_again():
	var player := _new_player()
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	watch_signals(player.v2_unlocks)
	assert_false(player.v2_research.complete_research("v2_doctrine_guardian_1"))
	player.v2_research.select_research("v2_doctrine_guardian_2")
	assert_signal_not_emitted(player.v2_unlocks, "unlock_applied")

func test_research_paid_with_knowledge_applies_the_unlock_too():
	var player := _new_player()
	watch_signals(player.v2_unlocks)
	assert_true(player.v2_research.select_research("v2_doctrine_guardian_1"))
	player.v2_research.add_knowledge(10.0)
	assert_signal_emit_count(player.v2_unlocks, "unlock_applied", 1)

func test_reset_lets_the_unlock_be_announced_again_but_the_state_is_the_only_truth():
	var player := _new_player()
	_complete_through(player, 3)
	player.v2_research.reset()
	assert_false(V2UnlockSystem.is_unlocked(player, "v2_unit_shieldbearer"), "reset da pesquisa remove o unlock")
	watch_signals(player.v2_unlocks)
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_signal_emit_count(player.v2_unlocks, "unlock_applied", 1)

func test_there_is_no_polling_hook_on_the_unlock_system():
	var system := V2UnlockSystem.new()
	assert_false(system.has_method("_process"))
	assert_false(system.has_method("_physics_process"))

# --- Aviso ao jogador humano ---------------------------------------------------------------------

func test_human_player_gets_a_toast_and_a_bus_event_when_an_unlock_lands():
	var human := _new_player()
	GameManager.human_player = human
	watch_signals(EventBus)
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	human.v2_research.complete_research("v2_doctrine_guardian_2")
	human.v2_research.complete_research("v2_doctrine_guardian_3")

	assert_signal_emitted_with_parameters(EventBus, "notify", ["Doutrina desbloqueada: Doutrina do Guardião", "confirm"], 0)
	assert_signal_emitted_with_parameters(EventBus, "notify", ["Novo prédio disponível: Salão dos Guardiões", "confirm"], 1)
	assert_signal_emitted_with_parameters(EventBus, "notify", ["Nova unidade disponível: Escudeiro", "confirm"], 2)
	assert_signal_emit_count(EventBus, "v2_unlock_applied", 3)
	assert_signal_emitted_with_parameters(EventBus, "v2_unlock_applied", [human, "unit", "v2_unit_shieldbearer"], 2)

func test_a_rival_civilization_never_triggers_a_toast():
	var human := _new_player()
	var rival := _new_player()
	GameManager.human_player = human
	watch_signals(EventBus)
	_complete_through(rival, 3)
	assert_signal_not_emitted(EventBus, "notify")
	assert_signal_not_emitted(EventBus, "v2_unlock_applied")
	assert_true(V2UnlockSystem.is_unlocked(rival, "v2_unit_shieldbearer"), "o rival ganha o unlock, só não avisa a HUD")

func test_announcement_text_per_unlock_type():
	assert_eq(V2UnlockSystem.announcement_text("doctrine", "X"), "Doutrina desbloqueada: X")
	assert_eq(V2UnlockSystem.announcement_text("building", "X"), "Novo prédio disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("unit", "X"), "Nova unidade disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("technique", "X"), "Nova técnica disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("unit_upgrade", "X"), "Nova evolução disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("mastery_building", "X"), "Novo prédio disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("legendary_candidate", "X"), "Unidade Lendária disponível: X")
	assert_eq(V2UnlockSystem.announcement_text("victory_capstone", "X"), "Via de vitória desbloqueada: X")

# --- Conteúdo conectado ---------------------------------------------------------------------------

func test_every_connected_unlock_id_belongs_to_a_connected_node_of_a_supported_type():
	for unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS:
		var node := V2UnlockSystem.node_for_unlock(unlock_id)
		assert_not_null(node, unlock_id)
		assert_true(node.gameplay_connected, unlock_id)
		assert_true(node.unlock_type in V2UnlockSystem.CONNECTED_TYPES, unlock_id)

func test_connected_unit_and_building_actually_exist_in_the_game_databases():
	for unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS:
		var node := V2UnlockSystem.node_for_unlock(unlock_id)
		match node.unlock_type:
			"building":
				assert_not_null(BuildingDatabase.get_building(unlock_id), unlock_id)
			"unit":
				assert_true(unlock_id in UnitDatabase.PLAYER_TRAINABLE_KINDS, unlock_id)
				assert_eq(UnitDatabase.create_unit(unlock_id).visual_kind, unlock_id)
