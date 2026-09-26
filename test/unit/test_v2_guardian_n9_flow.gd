extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Guardião N8-N9 (Aetherlands V2, Fase 6), pelos mesmos
## caminhos do jogo: jogo novo -> N1-N7 -> Salão -> Sentinela -> N8 -> Bastião de Maestria -> (sem N9 o
## Campeão não treina) -> N9 (capstone militar 1/2, inerte) -> o Bastião oferece o Campeão -> uma cidade
## inicia, a outra é bloqueada -> o Campeão nasce (Sentinela segue no Salão) -> Comando Defensivo em
## combate real -> salvar -> carregar (slot continua ocupado) -> o Campeão morre -> slot livre -> novo Campeão.
##
## O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_guardian_n9_flow_savegame.json"
const HALL := "v2_building_guardian_hall"
const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const WALL := "v2_technique_shield_wall"
const SENTINEL := "v2_unit_sentinel"
const BRACE := "v2_technique_brace_spears"
const MASTERY := "v2_building_guardian_mastery"
const CHAMPION := "v2_legendary_guardian_champion"
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
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Salão/Bastião (upkeep de
	# Ouro) e chegam a treinar o Campeão Guardião (5 Suprimentos, acima da capacidade base de uma
	# cidade sozinha). Ouro de sobra + uma Fazenda evitam bloqueio alheio ao teste.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(SHIELD), human)
	assert_not_null(unit)
	return {"grid": grid, "human": human, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

## Constrói `building_id` na cidade pelo fluxo normal (posicionamento de tile + fim de turno).
func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

## Uma SEGUNDA cidade do humano (já com Salão e Bastião) num tile válido distante da primeira.
func _second_city(grid: HexGrid, human: PlayerData) -> City:
	for coord in grid.tiles.keys():
		if CitySite.rejection_reason(grid, coord, human) == "" and grid.get_unit_at(coord) == null:
			var city := grid.found_city(coord, human, "Segunda Cidade", true)
			city.city_level = 3
			city.buildings[HALL] = true
			city.buildings[MASTERY] = true
			city.buildings["v2_building_farm"] = true
			city.repeatable_building_counts["v2_building_farm"] = 1
			return city
	fail_test("sem tile válido pra a segunda cidade")
	return null

func _ally_at_distance(grid: HexGrid, human: PlayerData, center: Vector2i, distance: int) -> Unit:
	for coord in grid.tiles_in_range(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and WorldSetup._is_valid_spawn(grid, coord) and grid.get_city_at(coord) == null:
			var ally := grid.spawn_unit(coord, UnitDatabase.create_unit("archer"), human)
			if ally != null:
				return ally
	fail_test("sem tile livre a distância %d" % distance)
	return null

func test_guardian_n8_n9_flow_from_the_mastery_building_to_a_legendary_champion_across_save_and_load():
	# 1-4. Jogo novo, Guardião N1-N7, Salão e uma Sentinela treinada pela produção normal.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — este fluxo chega a ter a Sentinela (N7, 3) viva mais o Campeão (N9,
	# 5, Lendária) em produção ao mesmo tempo, muito acima da base de uma cidade sozinha (4) --
	# Fazenda desde o início evita que este fluxo pré-existente tropece num gate que não é o
	# assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o upkeep), e este
	# fluxo ainda constrói o Salão e o Bastião (upkeep 1+2) -- Ouro de sobra evita que isso sozinho
	# derrube a cidade em Déficit sem nenhum Mercado.
	human.gold = 1000.0
	for id in ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2"]:
		_research(state, id)
	_build(grid, city, HALL)
	for n in range(3, 8):
		_research(state, "v2_doctrine_guardian_%d" % n)
	assert_true(_train(city, SENTINEL), "Sentinela em treino")
	assert_eq(_units_of_kind(human, SENTINEL).size(), 1, "4. Sentinela presente")
	assert_false(V2LegendarySystem.has_active_legendary(human))

	# 5-6. N8 e o Bastião (só depois do N8; exige o Salão que a cidade já tem).
	assert_false(city.can_build(MASTERY), "antes do N8 não constrói")
	_research(state, "v2_doctrine_guardian_8")
	assert_true(city.can_build(MASTERY), "5. N8 libera o Bastião")
	_build(grid, city, MASTERY)
	assert_true(city.buildings.has(HALL), "o Bastião não substitui o Salão")

	# 7. Sem N9 o Campeão ainda não pode ser treinado.
	assert_false(city.can_train(CHAMPION), "7. sem N9")
	assert_false(human.has_unlocked(CHAMPION))

	# 8-9. N9: o capstone militar mostra 1/2 (Doutrina do Guardião completa), inerte.
	_research(state, "v2_doctrine_guardian_9")
	assert_true(human.has_unlocked(CHAMPION))
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "9. Doutrinas completas: 1 / 2")
	assert_true(V2ResearchDatabase.get_node("v2_supreme_army").gameplay_connected, "Fase 12: o Exército Supremo está conectado (estrutural, vale mesmo com 1/2)")
	assert_true("v2_military_supremacy_access" in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true(V2ResearchDatabase.get_node("v2_magic_elementalism_1").gameplay_connected, "Fase 22: as seis Escolas de Magia estão conectadas")

	# 10-12. O Bastião oferece o Campeão; a cidade A inicia; a cidade B (também com Bastião) não pode.
	assert_true(city.can_train(CHAMPION), "10. o Bastião oferece o Campeão")
	var second := _second_city(grid, human)
	assert_true(second.can_train(CHAMPION), "antes da reserva, a B poderia")
	city.set_production(CHAMPION)
	assert_eq(city.production_item, CHAMPION, "11. iniciada")
	assert_false(V2LegendarySystem.has_active_legendary(human), "ainda não há unidade")
	assert_false(second.can_train(CHAMPION), "12. a segunda cidade não inicia outra Lendária")
	assert_eq(V2LegendarySystem.unavailable_reason(human, second, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)

	# 13-15. A produção conclui: o Campeão nasce, o slot passa de "em treinamento" a "ativa", a Sentinela segue no Salão.
	_end_turn()
	var champions := _units_of_kind(human, CHAMPION)
	assert_eq(champions.size(), 1, "14. o Campeão nasceu")
	var champion: Unit = champions[0]
	assert_eq(city.production_item, "")
	assert_same(V2LegendarySystem.active_legendary(human), champion)
	assert_false(second.can_train(CHAMPION), "o slot está ocupado por uma unidade ativa")
	assert_true(city.can_train(SENTINEL), "15. a Sentinela continua disponível no Salão")
	assert_false(city.can_train(GUARDIAN))
	assert_false(V2UnitLine.is_line_unit(CHAMPION))

	# 16-17. Selecionado: Lendário, Muralha, Preparar Lanças e Comando Defensivo.
	SelectionManager._select_unit(champion)
	assert_true(V2LegendarySystem.is_legendary_unit(champion))
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(champion).map(func(t): return t.id), [WALL])
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(champion).map(func(t): return t.id), [BRACE])
	assert_eq(V2UnitAuras.lines(champion)[0], "Passiva Lendária — Comando Defensivo")

	# 18-20. Aliado no raio 2 e combate real: a aura chega à resolução.
	var rival: PlayerData = GameManager.rival_players[0]
	var ally := _ally_at_distance(grid, human, champion.coord, 2)
	var striker := _striker_next_to(grid, rival, ally.coord)
	assert_almost_eq(V2UnitAuras.defense_multiplier(ally), 1.2, 0.0001, "18. aliado a distância 2")
	var predicted: float = CombatResolver.predict(striker, ally, grid).damage_to_defender
	var terrain := 1.0 + grid.get_tile(ally.coord).defense_bonus
	assert_almost_eq(predicted, maxf(1.0, 15.0 - ally.unit_data.defense * terrain * 1.2 * CombatResolver.DEFENSE_MITIGATION_FACTOR), 0.0001, "19-20. a previsão inclui +20%")
	var ally_hp := ally.hp
	CombatResolver.resolve(striker, ally, grid)
	assert_almost_eq(ally_hp - ally.hp, predicted, 0.0001, "o HP real bate com a previsão")
	grid.remove_unit(striker)
	grid.remove_unit(ally)

	# 21-23. Salva, carrega: Bastião, Campeão e slot conferem.
	var champion_coord := champion.coord
	var loaded_grid := _save_and_reload()
	var loaded_human := GameManager.human_player
	assert_eq(loaded_human.v2_research.get_completed_ids().size(), 9)
	var loaded_city: City = loaded_human.cities[0]
	assert_true(loaded_city.buildings.has(MASTERY), "Bastião restaurado")
	assert_true(loaded_city.buildings.has(HALL))
	var loaded_champions := _units_of_kind(loaded_human, CHAMPION)
	assert_eq(loaded_champions.size(), 1)
	var loaded_champion: Unit = loaded_champions[0]
	assert_eq(loaded_champion.coord, champion_coord)
	assert_eq(loaded_champion.unit_data.max_hp, 44.0)
	assert_true(V2LegendarySystem.is_legendary_unit(loaded_champion), "o status Lendário é derivado do tipo")
	assert_true(V2LegendarySystem.has_active_legendary(loaded_human), "22. o slot continua ocupado depois do load")
	assert_false(loaded_city.can_train(CHAMPION), "23. outra Lendária bloqueada")
	assert_true(loaded_city.can_train(SENTINEL))
	var loaded_ally := _ally_at_distance(loaded_grid, loaded_human, loaded_champion.coord, 2)
	assert_almost_eq(V2UnitAuras.defense_multiplier(loaded_ally), 1.2, 0.0001, "a aura funciona depois do load")
	loaded_grid.remove_unit(loaded_ally)

	# 24-26. O Campeão morre: o slot libera e um novo Campeão pode ser treinado.
	loaded_grid.remove_unit(loaded_champion)
	assert_false(V2LegendarySystem.has_active_legendary(loaded_human), "25. slot liberado")
	assert_true(loaded_city.can_train(CHAMPION))
	assert_true(_train(loaded_city, CHAMPION), "26. novo Campeão em produção")
	assert_eq(_units_of_kind(loaded_human, CHAMPION).size(), 1, "nasceu outro")

func test_a_champion_in_production_survives_save_and_load_and_still_blocks_the_second_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[MASTERY] = true
	var second := _second_city(c.grid, human)
	assert_true(second.can_train(CHAMPION))
	city.set_production(CHAMPION)
	assert_false(second.can_train(CHAMPION))

	_save_and_reload()
	var loaded_human := GameManager.human_player
	assert_eq(loaded_human.cities.size(), 2)
	var producing: City = loaded_human.cities.filter(func(x): return x.production_item == CHAMPION)[0]
	var other: City = loaded_human.cities.filter(func(x): return x != producing)[0]
	assert_eq(producing.production_item, CHAMPION, "a produção persistiu")
	assert_false(V2LegendarySystem.has_active_legendary(loaded_human), "ainda em treinamento")
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded_human))
	assert_false(other.can_train(CHAMPION), "a reserva vem da ordem de produção salva — nenhum estado extra")
	producing.set_production("") # cancelar
	assert_true(other.can_train(CHAMPION))

func test_two_cities_finishing_a_champion_in_the_same_turn_never_create_two_legendaries():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[MASTERY] = true
	var second := _second_city(c.grid, human)
	# Estado forçado (o gate normal impediria): as DUAS cidades com a mesma ordem, prontas no mesmo turno.
	city.set_production(CHAMPION)
	second.set_production(CHAMPION)
	_end_turn() # debug_mode conclui as ordens do humano; a 2ª deve ser recusada pela defesa final
	assert_push_error("não nasceu")
	assert_eq(_units_of_kind(human, CHAMPION).size(), 1, "jamais duas Lendárias ativas")
	assert_eq(V2LegendarySystem.active_legendary_units(human).size(), 1)
	assert_gte(second.stored_production + city.stored_production, UnitDatabase.create_unit(CHAMPION).production_cost, "o custo da recusada voltou pra cidade")

func test_the_sentinel_stays_trainable_and_normal_production_is_untouched_by_the_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[MASTERY] = true
	city.set_production(CHAMPION)
	assert_true(city.can_train(SENTINEL))
	city.set_production(SENTINEL)
	_end_turn()
	assert_eq(_units_of_kind(human, SENTINEL).size(), 1)
	assert_eq(_units_of_kind(human, CHAMPION).size(), 0)

func test_ai_civilizations_keep_playing_with_the_legendary_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(MASTERY))
			assert_ne(rival_city.production_item, CHAMPION)
		assert_eq(_units_of_kind(rival, CHAMPION).size(), 0)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))
