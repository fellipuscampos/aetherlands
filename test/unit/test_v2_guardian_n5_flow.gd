extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Guardião N4-N5 (Aetherlands V2, Fase 4),
## pelos mesmos caminhos do jogo: jogo novo -> N1-N3 -> Salão -> Escudeiro -> N4 -> Muralha
## de Escudos (efeito no combate real, duração, recarga) -> N5 -> a produção passa a
## oferecer o Guardião -> upgrade físico do Escudeiro existente (HP proporcional,
## veterania, recarga) -> salvar -> carregar -> tudo confere -> outro Guardião.
##
## O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_guardian_n5_flow_savegame.json"
const HALL := "v2_building_guardian_hall"
const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const WALL := "v2_technique_shield_wall"
## Mapa grande o bastante pra o Colonizador inicial não nascer perto demais de uma capital rival.
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []

var _original_state
var _original_players: Array[PlayerData]
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_hex_grid: HexGrid
var _original_rival_count: int
var _original_map_width: int
var _original_map_height: int
var _original_turn_number: int
var _original_turn_player_index: int
var _original_difficulty: String
var _original_human_race: String
var _original_debug_mode: bool
var _original_stagger_ai_turns: bool
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int
var _original_current_save_slot: String
var _original_kingdom_name: String

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_hex_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_difficulty = GameManager.difficulty
	_original_human_race = GameManager.human_race
	_original_debug_mode = GameManager.debug_mode
	_original_stagger_ai_turns = GameManager.stagger_ai_turns
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	_original_current_save_slot = GameManager.current_save_slot
	_original_kingdom_name = GameManager.human_kingdom_name
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	GameManager.stagger_ai_turns = false
	GameManager.human_race = "human"
	GameManager.rival_count = 2
	GameManager.map_width = MAP_WIDTH
	GameManager.map_height = MAP_HEIGHT
	GameManager.debug_mode = true

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
	for player in _players_to_release:
		player.release_relations()
	_players_to_release.clear()
	SaveManager.delete_save(TEST_SAVE_PATH)
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.hex_grid = _original_hex_grid
	GameManager.rival_count = _original_rival_count
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height
	TurnManager.turn_number = _original_turn_number
	TurnManager.current_player_index = _original_turn_player_index
	GameManager.difficulty = _original_difficulty
	GameManager.human_race = _original_human_race
	GameManager.debug_mode = _original_debug_mode
	GameManager.stagger_ai_turns = _original_stagger_ai_turns
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	GameManager._ai_batch_timer = 0.0
	GameManager.current_save_slot = _original_current_save_slot
	GameManager.human_kingdom_name = _original_kingdom_name
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id
	for grid in _hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_hex_grids.clear()

# --- Helpers ----------------------------------------------------------------------------------------------

func _new_game() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_WIDTH, MAP_HEIGHT, 555)
	_hex_grids.append(grid)
	GameManager.start_new_game(grid)
	return grid

func _found_human_city(grid: HexGrid) -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			var city := WorldSetup.found_city_from_settler(grid, unit)
			assert_not_null(city, "pré-condição: o Colonizador inicial funda a cidade")
			return city
	fail_test("o humano deveria começar com um Colonizador")
	return null

func _research(state: V2ResearchState, node_id: String) -> void:
	assert_true(state.select_research(node_id), "select %s" % node_id)
	state.add_knowledge(V2ResearchDatabase.get_node(node_id).cost)
	assert_true(state.is_completed(node_id), "concluiu %s" % node_id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")

func _units_of_kind(player: PlayerData, kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in player.units:
		if unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

func _build_hall(grid: HexGrid, city: City) -> void:
	SelectionManager.start_building_placement(city, HALL)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro Salão")
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	_end_turn()
	assert_true(city.buildings.has(HALL), "o Salão foi construído")

## Produz `kind` pelo mesmo gate/fluxo da HUD (has_unlocked + can_train + set_production) e
## fecha o turno. Devolve true se a cidade aceitou.
func _train(city: City, kind: String) -> bool:
	if not GameManager.human_player.has_unlocked(kind) or not city.can_train(kind):
		return false
	city.set_production(kind)
	_end_turn()
	return true

func _save_and_reload() -> HexGrid:
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH), "save_game")
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	_players_to_release.append_array(GameManager.players)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH), "load_game")
	return loaded

## Um atacante rival num tile livre vizinho de `coord` (pra medir o dano real).
func _striker_next_to(grid: HexGrid, rival: PlayerData, coord: Vector2i) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.attack = 15.0
	for n in grid.get_neighbors(coord):
		if WorldSetup._is_valid_spawn(grid, n) and grid.get_city_at(n) == null:
			var striker := grid.spawn_unit(n, data, rival)
			if striker != null:
				return striker
	fail_test("sem tile livre pro atacante")
	return null

## Cenário curto: jogo novo, cidade com Salão, N1-N4 e um Escudeiro vivo (sem passar pela produção).
func _short_setup(through: int = 4) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — Ouro de sobra + uma Fazenda evitam que Déficit/Suprimentos
	# bloqueiem upgrades/produção por um motivo alheio ao que este arquivo verifica (N4-N5).
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(SHIELD), human)
	assert_not_null(unit)
	return {"grid": grid, "human": human, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_guardian_n4_n5_flow_from_the_wall_to_an_upgraded_guardian_across_save_and_load():
	# 1-3. Jogo novo, N1-N3, Salão e Escudeiro treinado.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — este fluxo chega a ter 3 Guardiões vivos (N5, 2 Suprimentos cada =
	# 6), acima da base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo
	# pré-existente tropece num gate que não é o assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	for id in ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2"]:
		_research(state, id)
	_build_hall(grid, city)
	_research(state, "v2_doctrine_guardian_3")
	assert_true(_train(city, SHIELD), "4. Escudeiro em treino")
	var unit: Unit = _units_of_kind(human, SHIELD)[0]
	assert_eq(unit.unit_data.unit_name, "Escudeiro")

	# 5-6. Sem N4 a Muralha não existe; com N4 aparece pra unidade selecionada.
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit), [], "antes do N4")
	_research(state, "v2_doctrine_guardian_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).size(), 1, "depois do N4")

	# 7. Usa a Muralha pelo caminho da HUD (SelectionManager).
	var mana := human.mana
	var gold := human.gold
	var used_turn := TurnManager.turn_number
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(WALL)
	assert_true(V2TechniqueRuntime.is_active(unit, WALL), "7. Muralha ativa")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação e o movimento")
	assert_eq(human.mana, mana, "zero Mana")
	assert_eq(human.gold, gold, "zero Ouro")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 3)
	assert_not_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "feedback visual no mapa")

	# 8. Efeito defensivo real, no cálculo de combate.
	var rival: PlayerData = GameManager.rival_players[0]
	var striker := _striker_next_to(grid, rival, unit.coord)
	var walled: float = CombatResolver.predict(striker, unit, grid).damage_to_defender
	unit.magic_status.erase(WALL)
	var plain: float = CombatResolver.predict(striker, unit, grid).damage_to_defender
	unit.magic_status[WALL] = used_turn + V2TechniqueRuntime.ACTIVE_TURNS
	assert_lt(walled, plain, "8. a Muralha reduz o dano recebido")
	var hp_before := unit.hp
	CombatResolver.resolve(striker, unit, grid)
	assert_almost_eq(hp_before - unit.hp, walled, 0.0001, "o modificador chegou à resolução real do combate")
	unit.hp = unit.unit_data.max_hp
	grid.remove_unit(striker)

	# 9-10. Passa o turno: a Muralha termina sozinha; a recarga continua.
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(unit, WALL), "9. expirou no início do turno seguinte")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 2, "10. recarga contando")
	assert_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "o anel some junto")
	unit.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(unit, WALL), "ainda em recarga")

	# 11-12. N5: a produção passa a oferecer o Guardião e não mais o Escudeiro.
	assert_true(city.can_train(SHIELD), "antes do N5")
	_research(state, "v2_doctrine_guardian_5")
	assert_false(city.can_train(SHIELD), "12. o Escudeiro deixou de ser produção normal")
	assert_true(city.can_train(GUARDIAN))
	assert_true(_train(city, GUARDIAN), "Guardião em treino")
	assert_eq(_units_of_kind(human, GUARDIAN).size(), 1, "nasceu um Guardião")
	assert_eq(_units_of_kind(human, SHIELD).size(), 1, "o Escudeiro antigo continua existindo")

	# 13-15. Escudeiro dentro do território da cidade, Ouro garantido, HP/veterania preparados.
	assert_eq(V2UnitUpgrade.city_of(unit, grid), city, "13. Escudeiro em cidade própria com Salão")
	human.gold = 100.0
	unit.hp = 9.0 # 9/18 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	var remaining := V2TechniqueRuntime.cooldown_remaining(unit, WALL)
	assert_gt(remaining, 0, "pré-condição: ainda em recarga")
	var unit_id := unit.get_instance_id()
	var unit_serial := unit.serial_id
	var unit_count := human.units.size()
	var upgrade_cost := V2UnitUpgrade.upgrade_cost(unit)
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")

	# 15-17. Upgrade pelo caminho da HUD.
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, GUARDIAN, "16. agora é Guardião")
	assert_eq(unit.get_instance_id(), unit_id, "é a mesma unidade")
	assert_eq(unit.serial_id, unit_serial)
	assert_eq(human.units.size(), unit_count, "nada duplicado")
	assert_eq(_units_of_kind(human, SHIELD).size(), 0, "sem Escudeiro fantasma")
	assert_eq(human.gold, 100.0 - upgrade_cost, "Ouro descontado")
	assert_almost_eq(unit.hp, 12.0, 0.0001, "17. 50% de 24")
	assert_eq(unit.kills, 3)
	assert_eq(unit.veterancy_level, 2, "veterania preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), remaining, "recarga preservada")

	# 18-20. Salva, carrega e confere.
	var unit_coord := unit.coord
	var loaded_grid := _save_and_reload()
	var loaded_human := GameManager.human_player
	assert_not_same(loaded_human, human)
	assert_eq(loaded_human.v2_research.get_completed_ids(), ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2", "v2_doctrine_guardian_3", "v2_doctrine_guardian_4", "v2_doctrine_guardian_5"])
	var loaded_city: City = loaded_human.cities[0]
	assert_true(loaded_city.buildings.has(HALL), "Salão restaurado")
	assert_eq(_units_of_kind(loaded_human, SHIELD).size(), 0)
	var loaded_guardians := _units_of_kind(loaded_human, GUARDIAN)
	assert_eq(loaded_guardians.size(), 2, "o evoluído e o treinado")
	var evolved: Unit = null
	for g in loaded_guardians:
		if g.coord == unit_coord:
			evolved = g
	assert_not_null(evolved, "o Guardião evoluído voltou no mesmo tile")
	assert_almost_eq(evolved.hp, 12.0, 0.0001, "HP proporcional restaurado")
	assert_eq(evolved.kills, 3)
	assert_eq(evolved.veterancy_level, 2)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(evolved, WALL), remaining, "recarga preservada no save")
	assert_eq(loaded_grid.get_unit_at(unit_coord), evolved)

	# ...e a produção continua oferecendo Guardião depois de carregar.
	assert_true(loaded_city.can_train(GUARDIAN))
	assert_false(loaded_city.can_train(SHIELD))
	assert_true(_train(loaded_city, GUARDIAN), "produz outro Guardião")
	assert_eq(_units_of_kind(loaded_human, GUARDIAN).size(), 3)

# --- Save / load da Técnica -------------------------------------------------------------------------------------

func test_case_a_a_cooldown_survives_save_and_load():
	var c := _short_setup()
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.activate(unit, WALL))
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(unit, WALL))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), 2)

	_save_and_reload()
	var loaded: Unit = _units_of_kind(GameManager.human_player, SHIELD)[0]
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded, WALL), 2, "recarga preservada")
	assert_false(V2TechniqueRuntime.is_active(loaded, WALL))
	loaded.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(loaded, WALL))
	_end_turn()
	_end_turn()
	loaded.movement_left = 2.0
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded, WALL), 0)
	assert_true(V2TechniqueRuntime.can_use(loaded, WALL), "depois de 3 turnos volta a poder usar")

func test_case_b_an_active_wall_survives_save_and_load_and_expires_on_time():
	var c := _short_setup()
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.activate(unit, WALL))
	var turn := TurnManager.turn_number

	_save_and_reload()
	assert_eq(TurnManager.turn_number, turn)
	var loaded: Unit = _units_of_kind(GameManager.human_player, SHIELD)[0]
	assert_true(V2TechniqueRuntime.is_active(loaded, WALL), "estado ativo restaurado")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded, WALL), 3)
	assert_not_null(loaded.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "o anel volta junto")
	assert_eq(loaded.movement_left, 0.0, "a ação continua gasta")

	# Ainda protege na fase de IA do turno seguinte e termina quando o dono volta a jogar.
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(loaded, WALL), "expirou no turno certo")
	assert_null(loaded.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded, WALL), 2)

func test_a_guardian_saved_after_the_upgrade_loads_as_a_guardian_not_as_a_shieldbearer():
	var c := _short_setup(5)
	var human: PlayerData = c.human
	human.gold = 100.0
	var unit: Unit = c.unit
	assert_true(V2UnitUpgrade.perform_upgrade(human, unit, c.grid))
	var coord := unit.coord
	_save_and_reload()
	var loaded_human := GameManager.human_player
	assert_eq(_units_of_kind(loaded_human, SHIELD).size(), 0)
	var guardians := _units_of_kind(loaded_human, GUARDIAN)
	assert_eq(guardians.size(), 1)
	assert_eq(guardians[0].coord, coord)
	assert_eq(guardians[0].unit_data.max_hp, 24.0)

# --- Real game turn hook ----------------------------------------------------------------------------------------

func test_the_real_turn_flow_expires_the_wall_of_every_player():
	var c := _short_setup()
	var unit: Unit = c.unit
	assert_true(V2TechniqueRuntime.activate(unit, WALL))
	assert_true(V2TechniqueRuntime.is_active(unit, WALL))
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(unit, WALL), "GameManager._finish_turn chamou expire_finished")

func test_ai_civilizations_keep_playing_with_the_new_content_present():
	var c := _short_setup(5)
	var grid: HexGrid = c.grid
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(HALL))
			assert_ne(rival_city.production_item, GUARDIAN)
			assert_ne(rival_city.production_item, SHIELD)
		assert_eq(_units_of_kind(rival, GUARDIAN).size() + _units_of_kind(rival, SHIELD).size(), 0)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(grid))
