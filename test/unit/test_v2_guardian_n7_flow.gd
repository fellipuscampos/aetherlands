extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Guardião N6-N7 (Aetherlands V2, Fase 5), pelos
## mesmos caminhos do jogo: jogo novo -> N1-N5 -> Salão -> Guardião -> ataque contra montado
## ANTES do N6 -> N6 (Preparar Lanças, passiva) -> ataque contra montado e não montado (previsão
## e resolução real) -> N7 (a produção passa a oferecer a Sentinela) -> Guardião evolui pra
## Sentinela (custo por fórmula, HP proporcional, veterania, recarga) -> salvar -> carregar ->
## tudo confere -> outra Sentinela.
##
## O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_guardian_n7_flow_savegame.json"
const HALL := "v2_building_guardian_hall"
const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const WALL := "v2_technique_shield_wall"
const SENTINEL := "v2_unit_sentinel"
const BRACE := "v2_technique_brace_spears"
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
	# bloqueiem upgrades/produção por um motivo alheio ao que este arquivo verifica (N4-N7).
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(SHIELD), human)
	assert_not_null(unit)
	return {"grid": grid, "human": human, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

## Um alvo MONTADO real da V1 (Cavaleiro) num tile livre vizinho de `coord`.
func _cavalry_next_to(grid: HexGrid, rival: PlayerData, coord: Vector2i) -> Unit:
	for n in grid.get_neighbors(coord):
		if WorldSetup._is_valid_spawn(grid, n) and grid.get_city_at(n) == null:
			var cavalry := grid.spawn_unit(n, UnitDatabase.create_unit("cavalry"), rival)
			if cavalry != null:
				return cavalry
	fail_test("sem tile livre pro Cavaleiro")
	return null

func _predicted(grid: HexGrid, attacker: Unit, defender: Unit) -> float:
	return CombatResolver.predict(attacker, defender, grid).damage_to_defender

func test_guardian_n6_n7_flow_from_brace_spears_to_a_sentinel_across_save_and_load():
	# 1-4. Jogo novo, N1-N5, Salão e um Guardião treinado pela produção normal.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — este fluxo chega a ter formas N5 (2)/N7 (3) vivas ao mesmo tempo,
	# acima da base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo
	# pré-existente tropece num gate que não é o assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	for id in ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2"]:
		_research(state, id)
	_build_hall(grid, city)
	for id in ["v2_doctrine_guardian_3", "v2_doctrine_guardian_4", "v2_doctrine_guardian_5"]:
		_research(state, id)
	assert_true(_train(city, GUARDIAN), "Guardião em treino")
	var unit: Unit = _units_of_kind(human, GUARDIAN)[0]
	assert_eq(unit.unit_data.unit_name, "Guardião")
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit), [], "sem N6 não há passiva")

	# 5-6. Alvos: um Cavaleiro (montado, V1 real) e um Guarda (não montado). Ataque ANTES do N6.
	var rival: PlayerData = GameManager.rival_players[0]
	var cavalry := _cavalry_next_to(grid, rival, unit.coord)
	var guard := grid.spawn_unit(WorldSetup.find_spawn_tile(grid, unit.coord), UnitDatabase.create_unit("warrior"), rival)
	assert_not_null(guard)
	assert_true(UnitAbilities.is_mounted(cavalry.unit_data), "o Cavaleiro V1 é montado pelo traço")
	assert_false(UnitAbilities.is_mounted(guard.unit_data))
	var before_mounted := _predicted(grid, unit, cavalry)
	var before_plain := _predicted(grid, unit, guard)
	assert_eq(UnitAbilities.attack_multiplier(unit, cavalry), 1.0, "6. antes do N6: sem bônus")

	# 7-8. N6: Preparar Lanças aparece no painel (passiva, sem botão).
	_research(state, "v2_doctrine_guardian_6")
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).map(func(t): return t.id), [BRACE])
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).map(func(t): return t.id), [WALL], "só a Muralha é ação")
	assert_true(TileInspector.own_unit_lines(unit).any(func(l): return l.begins_with("Passiva — Preparar Lanças")), "8. passiva no painel")
	assert_false(V2TechniqueRuntime.can_use(unit, BRACE))
	assert_eq(unit.magic_status.size() + unit.magic_cooldowns.size(), 0, "nenhum estado guardado pra passiva")

	# 9-10. Ataque contra o montado: bônus na previsão e no HP real.
	var after_mounted := _predicted(grid, unit, cavalry)
	var bonus := V2DoctrineTechniqueDatabase.get_technique(BRACE).basic_attack_bonus
	var flank: float = CombatResolver._flanking_multiplier(unit, cavalry, grid) # outros bônus de ataque multiplicam juntos
	assert_almost_eq(after_mounted - before_mounted, unit.unit_data.attack * flank * bonus, 0.0001, "+50% do ATAQUE 4,0 (mais o flanco, se houver)")
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, cavalry), 1.0 + bonus, 0.0001)
	assert_almost_eq(_predicted(grid, unit, guard), before_plain, 0.0001, "11-12. não montado: dano igual ao de antes")
	var cavalry_hp := cavalry.hp
	CombatResolver.resolve(unit, cavalry, grid)
	assert_almost_eq(cavalry_hp - cavalry.hp, after_mounted, 0.0001, "10. o HP real bate com a previsão")
	unit.movement_left = 2.0
	var guard_hp := guard.hp
	CombatResolver.resolve(unit, guard, grid)
	assert_almost_eq(guard_hp - guard.hp, before_plain, 0.0001, "12. sem bônus contra o não montado")
	grid.remove_unit(cavalry)
	grid.remove_unit(guard)

	# 13-14. N7: a produção passa a oferecer a Sentinela (e não mais o Guardião).
	assert_true(city.can_train(GUARDIAN), "antes do N7")
	_research(state, "v2_doctrine_guardian_7")
	assert_false(city.can_train(GUARDIAN), "14. o Guardião deixou de ser produção normal")
	assert_true(city.can_train(SENTINEL))
	assert_false(city.can_train(SHIELD))

	# 15-17. Muralha usada agora (recarga que a evolução deve preservar), Guardião em cidade própria
	# com HP baixo e veterania, Ouro garantido; evolui pelo caminho da HUD.
	unit.movement_left = 2.0
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(WALL)
	assert_true(V2TechniqueRuntime.is_active(unit, WALL))
	_end_turn() # a Muralha expira; a recarga segue
	assert_false(V2TechniqueRuntime.is_active(unit, WALL))
	assert_eq(V2UnitUpgrade.city_of(unit, grid), city, "15. Guardião em cidade própria com Salão")
	human.gold = 100.0
	unit.hp = 12.0 # 12/24 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	var remaining := V2TechniqueRuntime.cooldown_remaining(unit, WALL)
	assert_gt(remaining, 0, "pré-condição: Muralha em recarga")
	var unit_id := unit.get_instance_id()
	var unit_serial := unit.serial_id
	var unit_count := human.units.size()
	var cost := V2UnitUpgrade.upgrade_cost(unit)
	assert_eq(cost, 2.0 * (UnitDatabase.create_unit(SENTINEL).production_cost - UnitDatabase.create_unit(GUARDIAN).production_cost), "custo pela fórmula")
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()

	assert_eq(unit.unit_data.visual_kind, SENTINEL, "16. agora é Sentinela")
	assert_eq(unit.get_instance_id(), unit_id)
	assert_eq(unit.serial_id, unit_serial)
	assert_eq(human.units.size(), unit_count)
	assert_eq(_units_of_kind(human, GUARDIAN).size(), 0, "sem Guardião fantasma")
	assert_eq(human.gold, 100.0 - cost, "17. custo descontado")
	assert_almost_eq(unit.hp, 16.0, 0.0001, "12/24 -> 16/32")
	assert_eq(unit.veterancy_level, 2)
	assert_eq(unit.kills, 3)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), remaining, "recarga preservada")

	# 18-19. A Sentinela herda a Muralha (ação) e Preparar Lanças (passiva) pela linha.
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).map(func(t): return t.id), [WALL], "18.")
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).map(func(t): return t.id), [BRACE], "19.")
	var second_cavalry := _cavalry_next_to(grid, rival, unit.coord)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, second_cavalry), 1.0 + bonus, 0.0001, "a Sentinela também contra-ataca montados")
	grid.remove_unit(second_cavalry)

	# 20-22. Salva, carrega e confere.
	var unit_coord := unit.coord
	var loaded_grid := _save_and_reload()
	var loaded_human := GameManager.human_player
	assert_not_same(loaded_human, human)
	assert_eq(loaded_human.v2_research.get_completed_ids().size(), 7)
	for n in range(1, 8):
		assert_true(loaded_human.v2_research.is_completed("v2_doctrine_guardian_%d" % n), "N%d" % n)
	var loaded_city: City = loaded_human.cities[0]
	assert_true(loaded_city.buildings.has(HALL))
	assert_eq(_units_of_kind(loaded_human, GUARDIAN).size(), 0)
	var sentinels := _units_of_kind(loaded_human, SENTINEL)
	assert_eq(sentinels.size(), 1)
	var loaded_unit: Unit = sentinels[0]
	assert_eq(loaded_unit.coord, unit_coord)
	assert_almost_eq(loaded_unit.hp, 16.0, 0.0001)
	assert_eq(loaded_unit.kills, 3)
	assert_eq(loaded_unit.veterancy_level, 2)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_unit, WALL), remaining, "recarga da Muralha preservada")
	# A passiva é DERIVADA: existe depois do load sem nada salvo pra ela.
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(loaded_unit).map(func(t): return t.id), [BRACE])
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var loaded_cavalry := _cavalry_next_to(loaded_grid, loaded_rival, loaded_unit.coord)
	assert_almost_eq(UnitAbilities.attack_multiplier(loaded_unit, loaded_cavalry), 1.0 + bonus, 0.0001, "o efeito sobrevive ao load por derivação")
	loaded_grid.remove_unit(loaded_cavalry)
	# ...e a produção continua oferecendo Sentinela.
	assert_true(loaded_city.can_train(SENTINEL))
	assert_false(loaded_city.can_train(GUARDIAN))
	assert_true(_train(loaded_city, SENTINEL), "produz outra Sentinela")
	assert_eq(_units_of_kind(loaded_human, SENTINEL).size(), 2)

func test_a_sentinel_saved_after_the_second_upgrade_loads_as_a_sentinel():
	var c := _short_setup(7)
	var human: PlayerData = c.human
	human.gold = 100.0
	var shield: Unit = c.unit
	# A cadeia inteira na mesma unidade antes de salvar.
	assert_true(V2UnitUpgrade.perform_upgrade(human, shield, c.grid))
	shield.movement_left = 2.0
	assert_true(V2UnitUpgrade.perform_upgrade(human, shield, c.grid))
	var coord := shield.coord
	_save_and_reload()
	var loaded_human := GameManager.human_player
	assert_eq(_units_of_kind(loaded_human, SHIELD).size(), 0)
	assert_eq(_units_of_kind(loaded_human, GUARDIAN).size(), 0)
	var sentinels := _units_of_kind(loaded_human, SENTINEL)
	assert_eq(sentinels.size(), 1)
	assert_eq(sentinels[0].coord, coord)
	assert_eq(sentinels[0].unit_data.max_hp, 32.0)

func test_reset_after_loading_removes_the_derived_passive_and_the_production_upgrade():
	var c := _short_setup(7)
	_save_and_reload()
	var loaded_human := GameManager.human_player
	var unit: Unit = _units_of_kind(loaded_human, SHIELD)[0]
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).size(), 1)
	loaded_human.v2_research.reset()
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit), [])
	assert_eq(unit.unit_data.visual_kind, SHIELD, "nada é destruído")

func test_two_civilizations_at_different_levels_keep_their_own_effects():
	var c := _short_setup(6)
	var rival: PlayerData = GameManager.rival_players[0]
	for n in range(1, 6):
		rival.v2_research.complete_research("v2_doctrine_guardian_%d" % n) # rival sem N6
	var mine: Unit = c.unit
	var rival_unit: Unit = c.grid.spawn_unit(WorldSetup.find_spawn_tile(c.grid, rival.cities[0].coord), UnitDatabase.create_unit(GUARDIAN), rival)
	assert_not_null(rival_unit)
	var cavalry: Unit = c.grid.spawn_unit(WorldSetup.find_spawn_tile(c.grid, mine.coord), UnitDatabase.create_unit("cavalry"), rival)
	assert_not_null(cavalry)
	assert_gt(UnitAbilities.attack_multiplier(mine, cavalry), 1.0, "quem pesquisou o N6 tem o efeito")
	assert_eq(UnitAbilities.attack_multiplier(rival_unit, cavalry), 1.0, "o rival sem N6 não")

func test_ai_civilizations_keep_playing_with_the_new_content_present():
	var c := _short_setup(7)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(HALL))
			assert_ne(rival_city.production_item, SENTINEL)
		assert_eq(_units_of_kind(rival, SENTINEL).size() + _units_of_kind(rival, GUARDIAN).size() + _units_of_kind(rival, SHIELD).size(), 0)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))
