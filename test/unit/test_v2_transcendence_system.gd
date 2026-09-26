extends GutTest

const SACRED_RITUAL := "v2_building_sacred_ritual"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var city: City
var _original_state
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_turn: int

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 40
	city = grid.found_city(Vector2i.ZERO, human, "Aetéria", true)
	grid.found_city(Vector2i(6, 0), rival, "Rival", true)

func after_each():
	for player in GameManager.players:
		player.release_relations()
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	if is_instance_valid(grid):
		grid.queue_free()

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	return PlayerData.new(civ)

func _complete_branch(player: PlayerData, branch: String) -> void:
	assert_eq(player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, branch), 9)

func _unlock_transcendence(player: PlayerData = human) -> void:
	_complete_branch(player, "sacred")
	_complete_branch(player, "infernal")
	assert_true(player.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))

func _manifestation(kind: String, coord: Vector2i, owner: PlayerData = human) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)

func _make_ready() -> void:
	_unlock_transcendence()
	city.buildings[SACRED_RITUAL] = true
	_manifestation(SERAPH, Vector2i(1, 0))
	_manifestation(ARCHDEMON, Vector2i(-1, 0))
	human.mana = 300.0

func test_capstone_is_connected_and_all_128_nodes_are_connected():
	var node := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	assert_true(node.gameplay_connected)
	assert_false(node.is_placeholder)
	assert_eq(node.unlock_type, "victory_capstone")
	assert_eq(node.unlock_id, V2TranscendenceSystem.ACCESS_ID)
	assert_eq(node.cost, V2ResearchDatabase.CAPSTONE_COST)
	assert_eq(node.requirement.branch_count, 2)
	assert_eq(node.requirement.at_tier, 9)
	assert_eq(V2UnlockSystem.announcement_text(node.unlock_type, node.display_name), "Via de vitória desbloqueada: Transcendência")
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE).filter(func(n): return n.gameplay_connected).size(), 55)
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL).filter(func(n): return n.gameplay_connected).size(), 55)
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE).filter(func(n): return n.gameplay_connected).size(), 18)
	assert_eq(V2ResearchDatabase.all_nodes().filter(func(n): return n.gameplay_connected).size(), 128)

func test_access_is_derived_only_from_capstone_research_and_reset_removes_it():
	assert_false(V2TranscendenceSystem.has_access(human))
	_unlock_transcendence()
	assert_true(V2TranscendenceSystem.has_access(human))
	human.v2_research.reset()
	assert_false(V2TranscendenceSystem.has_access(human))

func test_capstone_still_requires_two_n9s_and_progress_saturates_two_of_two():
	_complete_branch(human, "sacred")
	assert_false(human.v2_research.is_available(V2ResearchDatabase.TRANSCENDENCE_ID))
	for branch in ["infernal", "necromancy", "druidism", "arcanism", "elementalism"]:
		_complete_branch(human, branch)
	assert_eq(V2ResearchDatabase.capstone_progress(V2ResearchDatabase.TRANSCENDENCE_ID, human.v2_research.completed_ids), Vector2i(2, 2))

func test_manifestation_count_is_live_distinct_school_and_excludes_production_legendary_and_caster():
	_manifestation(SERAPH, Vector2i(1, 0))
	_manifestation(SERAPH, Vector2i(2, 0)) # corrupt duplicate school
	_manifestation("v2_legendary_guardian_champion", Vector2i(3, 0))
	_manifestation("v2_unit_sacred_cleric", Vector2i(4, 0))
	city.production_item = ARCHDEMON
	assert_eq(V2ManifestationSystem.active_manifestation_schools(human), ["sacred"])
	assert_eq(V2ManifestationSystem.active_manifestation_count(human), 1)
	_manifestation(ARCHDEMON, Vector2i(-1, 0))
	assert_eq(V2ManifestationSystem.active_manifestation_count(human), 2)

func test_ritual_structure_is_data_driven_physical_and_researched():
	city.buildings[SACRED_RITUAL] = true
	assert_false(V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, human))
	_complete_branch(human, "sacred")
	assert_eq(V2TranscendenceSystem.eligible_ritual_structures(city, human), [SACRED_RITUAL])
	assert_true(V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, human))

func test_start_validation_reasons_and_failure_are_transactional():
	human.mana = 119.99
	assert_eq(V2TranscendenceSystem.start_unavailable_reason(human, city), "Requer a pesquisa Transcendência.")
	_unlock_transcendence()
	assert_eq(V2TranscendenceSystem.start_unavailable_reason(human, city), "Esta cidade precisa de uma Estrutura Ritual pesquisada.")
	city.buildings[SACRED_RITUAL] = true
	assert_eq(V2TranscendenceSystem.start_unavailable_reason(human, city), "Requer 2 Grandes Manifestações ativas (0 / 2).")
	_manifestation(SERAPH, Vector2i(1, 0))
	_manifestation(ARCHDEMON, Vector2i(-1, 0))
	assert_true(V2TranscendenceSystem.start_unavailable_reason(human, city).begins_with("Mana insuficiente"))
	assert_false(V2TranscendenceSystem.start_ritual(human, city))
	assert_almost_eq(human.mana, 119.99, 0.001)
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	assert_true(grid._v2_transcendence_markers.is_empty())

func test_success_charges_once_creates_public_state_and_marker_without_fog_reveal():
	_make_ready()
	grid.visibility[city.coord] = HexGrid.Visibility.UNSEEN
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_eq(human.mana, 180.0)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 4)
	assert_eq(human.v2_transcendence_ritual.last_progress_turn, 40)
	assert_eq(V2TranscendenceSystem.public_rituals().size(), 1)
	assert_true(grid._v2_transcendence_markers.has(0))
	assert_true(grid._v2_transcendence_markers[0].visible)
	assert_eq(grid.visibility[city.coord], HexGrid.Visibility.UNSEEN)
	assert_false(V2TranscendenceSystem.start_ritual(human, city), "uma civilização só mantém um Ritual")
	assert_eq(human.mana, 180.0, "a segunda tentativa não cobra de novo")

func test_ritual_is_parallel_to_production_and_gold_deficit_and_never_changes_the_queue():
	_make_ready()
	city.production_item = "warrior"
	city.stored_production = 11.5
	city.buildings["v2_building_sacred_temple"] = true # upkeep total 3 > renda-base 2
	human.gold = -500.0
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_eq(city.production_item, "warrior")
	assert_eq(city.stored_production, 11.5)
	assert_true(V2EconomyRuntime.is_gold_deficit(human))

func test_silence_status_and_low_hp_do_not_stop_a_live_manifestation_from_counting():
	_make_ready()
	var seraph: Unit = grid.get_unit_at(Vector2i(1, 0))
	seraph.hp = 1.0
	seraph.magic_status["v2_spell_arcane_silence"] = V2OwnerTurnEffect.expiry_for_now()
	assert_eq(V2TranscendenceSystem.active_manifestation_count(human), 2)
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_true(V2TranscendenceSystem.validate_active_ritual(human))

func test_losing_the_usable_structure_interrupts_and_zero_can_no_longer_win():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 0
	city.buildings.erase(SACRED_RITUAL)
	assert_false(V2TranscendenceSystem.victory_ready(human, grid))
	assert_false(V2TranscendenceSystem.validate_active_ritual(human))
	assert_false(V2TranscendenceSystem.has_active_ritual(human))

func test_tick_is_once_per_turn_and_reaches_ready_without_deleting_state():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	V2TranscendenceSystem.process_global_round(grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 4)
	for expected in [3, 2, 1, 0]:
		TurnManager.turn_number += 1
		V2TranscendenceSystem.process_global_round(grid)
		assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), expected)
		V2TranscendenceSystem.process_global_round(grid)
		assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), expected, "sem double tick")
	assert_true(V2TranscendenceSystem.victory_ready(human, grid))
	assert_true(V2TranscendenceSystem.has_active_ritual(human))

func test_manifestation_death_below_two_interrupts_immediately_without_refund():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	var mana_after_start := human.mana
	grid.remove_unit(grid.get_unit_at(Vector2i(1, 0)))
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	assert_eq(human.mana, mana_after_start)
	assert_true(grid._v2_transcendence_markers.is_empty())

func test_losing_one_of_three_manifestations_does_not_interrupt():
	_make_ready()
	_manifestation("v2_manifestation_lich_sovereign", Vector2i(0, 2))
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	grid.remove_unit(grid.get_unit_at(Vector2i(1, 0)))
	assert_true(V2TranscendenceSystem.has_active_ritual(human))

func test_after_an_interruption_rebuilding_a_manifestation_requires_a_new_full_payment_and_countdown():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	TurnManager.turn_number += 2
	V2TranscendenceSystem.process_global_round(grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)
	grid.remove_unit(grid.get_unit_at(Vector2i(1, 0)))
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	_manifestation(SERAPH, Vector2i(1, 0))
	human.mana = 120.0
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_eq(human.mana, 0.0)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 4)

func test_capture_interrupts_immediately_and_recapture_does_not_restore():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	grid.capture_city(city, rival)
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	grid.capture_city(city, human)
	assert_false(V2TranscendenceSystem.has_active_ritual(human))

func test_a_captured_ritual_building_is_usable_only_with_the_new_owners_own_research():
	city.buildings[SACRED_RITUAL] = true
	grid.capture_city(city, rival)
	assert_false(V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, rival))
	_complete_branch(rival, "sacred")
	assert_true(V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, rival))

func test_research_reset_and_manual_cancel_interrupt_without_refund_or_destroying_entities():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	var mana_after_start := human.mana
	human.v2_research.reset()
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	assert_eq(human.units.size(), 2)
	assert_true(city.buildings.has(SACRED_RITUAL))
	assert_eq(human.mana, mana_after_start)
	_unlock_transcendence()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_true(V2TranscendenceSystem.cancel_ritual(human))
	assert_false(V2TranscendenceSystem.has_active_ritual(human))

func test_save_helpers_restore_valid_state_and_same_turn_does_not_tick():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	TurnManager.turn_number += 1
	V2TranscendenceSystem.process_global_round(grid)
	var saved := V2TranscendenceSystem.to_save_array()
	assert_eq(saved[0].remaining_rounds, 3)
	V2TranscendenceSystem.load_save_array(saved, grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)
	V2TranscendenceSystem.process_global_round(grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)
	assert_true(grid._v2_transcendence_markers.has(0))

func test_two_civilizations_can_progress_independent_public_rituals_in_the_same_round():
	_make_ready()
	var rival_city: City = rival.cities[0]
	_unlock_transcendence(rival)
	rival_city.buildings[SACRED_RITUAL] = true
	_manifestation(SERAPH, Vector2i(5, 0), rival)
	_manifestation(ARCHDEMON, Vector2i(7, 0), rival)
	rival.mana = 200.0
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	assert_true(V2TranscendenceSystem.start_ritual(rival, rival_city))
	assert_eq(V2TranscendenceSystem.public_rituals().size(), 2)
	assert_eq(grid._v2_transcendence_markers.size(), 2)
	TurnManager.turn_number += 1
	V2TranscendenceSystem.process_global_round(grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(rival), 3)
	assert_true(V2TranscendenceSystem.cancel_ritual(human))
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(rival), 3)
	assert_eq(grid._v2_transcendence_markers.size(), 1)

func test_last_round_public_warning_and_progress_event_emit_once_despite_duplicate_processing():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 2
	watch_signals(EventBus)
	TurnManager.turn_number += 1
	V2TranscendenceSystem.process_global_round(grid)
	V2TranscendenceSystem.process_global_round(grid)
	assert_signal_emit_count(EventBus, "v2_transcendence_progressed", 1)
	assert_signal_emit_count(EventBus, "notify", 1, "o alerta urgente de uma rodada não duplica")

func test_game_over_freezes_the_global_tick_and_never_rewrites_the_winner():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	GameManager.state = GameManager.GameState.GAME_OVER
	TurnManager.turn_number += 1
	V2TranscendenceSystem.process_global_round(grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 4)

func test_environmental_fatal_damage_resolves_before_the_ritual_can_reach_zero():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	var seraph: Unit = grid.get_unit_at(Vector2i(1, 0))
	seraph.hp = 4.0
	human.v2_transcendence_ritual.remaining_rounds = 1
	assert_true(V2EnvironmentalZoneSystem.apply(grid, seraph.coord, "v2_zone_lightning_storm", 0, "elementalism"))
	TurnManager.turn_number += 1
	GameManager._finish_turn()
	assert_false(is_instance_valid(seraph) and seraph in human.units)
	assert_false(V2TranscendenceSystem.has_active_ritual(human), "a morte interrompe antes do decremento final")
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)

func test_environmental_death_from_three_to_two_keeps_and_progresses_the_ritual():
	_make_ready()
	var lich := _manifestation("v2_manifestation_lich_sovereign", Vector2i(0, 2))
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	lich.hp = 4.0
	human.v2_transcendence_ritual.remaining_rounds = 2
	assert_true(V2EnvironmentalZoneSystem.apply(grid, lich.coord, "v2_zone_lightning_storm", 0, "elementalism"))
	TurnManager.turn_number += 1
	GameManager._finish_turn()
	assert_eq(V2TranscendenceSystem.active_manifestation_count(human), 2)
	assert_true(V2TranscendenceSystem.has_active_ritual(human))
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 1)
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)

func test_corrupt_and_duplicate_save_entries_are_ignored_fail_safe():
	_make_ready()
	var valid := {"owner_index": 0, "site": [0, 0], "remaining_rounds": 2, "last_progress_turn": 39}
	V2TranscendenceSystem.load_save_array([
		{"owner_index": "0", "site": [0, 0], "remaining_rounds": 2, "last_progress_turn": 39},
		{"owner_index": 0, "site": ["0", 0], "remaining_rounds": 2, "last_progress_turn": 39},
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": "2", "last_progress_turn": 39},
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": 2, "last_progress_turn": INF},
		{"owner_index": 9, "site": [0, 0], "remaining_rounds": 2, "last_progress_turn": 39},
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": 0, "last_progress_turn": 39},
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": -1, "last_progress_turn": 39},
		{"owner_index": 0, "site": [999, 999], "remaining_rounds": 2, "last_progress_turn": 39},
		valid,
		{"owner_index": 0, "site": [0, 0], "remaining_rounds": 1, "last_progress_turn": 39},
	], grid)
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 2)
	V2TranscendenceSystem.load_save_array([], grid)
	assert_false(V2TranscendenceSystem.has_active_ritual(human))

func test_zero_state_never_wins_after_a_requirement_is_lost():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 0
	assert_true(V2TranscendenceSystem.victory_ready(human, grid))
	human.units.erase(grid.get_unit_at(Vector2i(1, 0)))
	assert_false(V2TranscendenceSystem.victory_ready(human, grid))

func test_game_manager_awards_v2_transcendence_after_existing_victories():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 0
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE])

func test_existing_domination_precedence_is_preserved_when_transcendence_is_ready_too():
	_make_ready()
	assert_true(V2TranscendenceSystem.start_ritual(human, city))
	human.v2_transcendence_ritual.remaining_rounds = 0
	rival.units.clear()
	rival.cities.clear()
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, VictoryConditions.VICTORY_TYPE_DOMINANCE])

func test_research_or_manifestations_without_ritual_never_win():
	_make_ready()
	assert_false(V2VictoryConditions.transcendence_achieved(human))
	assert_false("arcane_ritual_active" in human, "Fase 25: o Ritual Arcano V1 não existe mais")

func test_transcendence_foundations_do_not_hardcode_a_school_building_or_manifestation_id():
	var files := [
		"res://scripts/core/V2TranscendenceSystem.gd",
		"res://scripts/core/V2VictoryConditions.gd",
		"res://scripts/autoload/GameManager.gd",
		"res://scripts/world/HexGrid.gd",
	]
	var forbidden := [
		"v2_building_sacred_ritual", "v2_building_infernal_ritual", "v2_building_necromancy_ritual",
		"v2_building_druidism_ritual", "v2_building_arcanism_ritual", "v2_building_elementalism_ritual",
		"v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_lich_sovereign",
		"v2_manifestation_nature_avatar", "v2_manifestation_archon", "v2_manifestation_primordial",
	]
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		for concrete_id in forbidden:
			assert_false(source.contains(concrete_id), "%s não pode conhecer %s" % [path, concrete_id])
