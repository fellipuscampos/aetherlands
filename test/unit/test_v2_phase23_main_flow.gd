extends GutTest

## Fase 23 — fluxo principal no pipeline real: nova partida, pesquisas,
## estruturas/Manifestações pela produção normal, Ritual público, interrupção,
## reinício, save em 1 rodada e vitória pelo check_victories canônico.

const SAVE_PATH := "user://test_v2_phase23_main_flow.json"
const SACRED_TEMPLE := "v2_building_sacred_temple"
const SACRED_RITUAL := "v2_building_sacred_ritual"
const INFERNAL_SANCTUM := "v2_building_infernal_sanctum"
const INFERNAL_RITUAL := "v2_building_infernal_ritual"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"

var grid: HexGrid
var _original_state
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_rival_count: int
var _original_debug: bool
var _original_stagger: bool
var _original_turn: int
var _original_turn_player: int

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_debug = GameManager.debug_mode
	_original_stagger = GameManager.stagger_ai_turns
	_original_turn = TurnManager.turn_number
	_original_turn_player = TurnManager.current_player_index
	GameManager.rival_count = 1
	GameManager.debug_mode = true
	GameManager.stagger_ai_turns = false
	grid = HexGrid.new()
	grid._ready()
	grid.generate_map(25, 25, 230023)
	GameManager.start_new_game(grid)

func after_each():
	SelectionManager.reset()
	SaveManager.delete_save(SAVE_PATH)
	for player in GameManager.players:
		player.release_relations()
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	GameManager.rival_count = _original_rival_count
	GameManager.debug_mode = _original_debug
	GameManager.stagger_ai_turns = _original_stagger
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	TurnManager.turn_number = _original_turn
	TurnManager.current_player_index = _original_turn_player
	if is_instance_valid(grid):
		grid.queue_free()

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing)

func _found_city() -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			return WorldSetup.found_city_from_settler(grid, unit)
	return null

func _learn_branch(player: PlayerData, branch: String) -> void:
	for tier in range(1, 10):
		var id := "v2_magic_%s_%d" % [branch, tier]
		if not player.v2_research.is_completed(id):
			assert_true(player.v2_research.complete_research(id), id)

func _clear_ring(city: City) -> void:
	for unit in city.owner_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) <= 1:
			for coord in HexMetrics.coords_within(city.coord, 10):
				var tile := grid.get_tile(coord)
				if tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.get_building_at(coord) == null:
					grid.teleport_unit(unit, coord)
					break

func _build(city: City, building_id: String) -> void:
	_clear_ring(city)
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	_end_turn()
	assert_true(city.buildings.has(building_id), building_id)

func _find(kind: String, player: PlayerData = GameManager.human_player) -> Unit:
	for unit in player.units:
		if is_instance_valid(unit) and unit.unit_data.visual_kind == kind:
			return unit
	return null

func _produce(city: City, kind: String) -> Unit:
	_clear_ring(city)
	city.set_production(kind)
	_end_turn()
	var unit := _find(kind)
	assert_not_null(unit, kind)
	return unit

func test_transcendence_end_to_end_interrupt_restart_save_and_normal_victory_pipeline():
	var human := GameManager.human_player
	var ritual_city := _found_city()
	assert_not_null(ritual_city, "1. cidade fundada no jogo real")
	ritual_city.city_level = 4
	_learn_branch(human, "sacred")
	_learn_branch(human, "infernal")
	assert_eq(V2ResearchDatabase.capstone_progress(V2ResearchDatabase.TRANSCENDENCE_ID, human.v2_research.completed_ids), Vector2i(2, 2))
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	assert_true(human.has_unlocked(V2TranscendenceSystem.ACCESS_ID))
	_build(ritual_city, SACRED_TEMPLE)
	_build(ritual_city, SACRED_RITUAL)
	_build(ritual_city, INFERNAL_SANCTUM)
	_build(ritual_city, INFERNAL_RITUAL)
	human.mana = 1000.0
	var seraph := _produce(ritual_city, SERAPH)
	var archdemon := _produce(ritual_city, ARCHDEMON)
	assert_eq(V2TranscendenceSystem.active_manifestation_count(human), 2)
	assert_ne(seraph.unit_data.v2_magic_school, archdemon.unit_data.v2_magic_school)

	# A fila comum não participa nem é apagada; o site e countdown são públicos.
	ritual_city.production_item = "warrior"
	var before_start := human.mana
	watch_signals(EventBus)
	assert_true(V2TranscendenceSystem.start_ritual(human, ritual_city))
	assert_eq(human.mana, before_start - 120.0)
	assert_eq(ritual_city.production_item, "warrior")
	assert_eq(V2TranscendenceSystem.public_rituals()[0].remaining_rounds, 4)
	assert_true(grid._v2_transcendence_markers.has(0))
	_end_turn()
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 3)

	# Contraplay real: morte canônica interrompe, não devolve Mana nem ressuscita progresso.
	var mana_after_start := human.mana
	grid.remove_unit(seraph)
	assert_false(V2TranscendenceSystem.has_active_ritual(human))
	assert_eq(human.mana, mana_after_start)
	assert_true(grid._v2_transcendence_markers.is_empty())
	ritual_city.production_item = ""
	seraph = _produce(ritual_city, SERAPH)
	human.mana = 500.0
	assert_true(V2TranscendenceSystem.start_ritual(human, ritual_city))
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 4)

	for expected in [3, 2, 1]:
		_end_turn()
		assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), expected)
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 1)
	assert_true(grid._v2_transcendence_markers.has(0))
	assert_eq(V2TranscendenceSystem.active_manifestation_count(human), 2)

	watch_signals(EventBus)
	_end_turn()
	assert_eq(V2TranscendenceSystem.ritual_rounds_remaining(human), 0)
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE])
	assert_false("arcane_ritual_active" in human, "Fase 25: estado V1 removido")
	assert_false("researched_magic" in human, "Fase 25: estado V1 removido")
