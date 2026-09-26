extends GutTest

## Aetherlands V2, Fase 16 — FLUXOS PRINCIPAIS num jogo REAL (mapa gerado, pesquisa por
## Conhecimento, projetos pela fila de produção + fim de turno, Ataque da Cidade pela mira da
## SelectionManager, IA rival pelo turno de verdade, save/load de verdade).
## §127 Infraestrutura defensiva: Urbanização N1..N3 -> Cidade II..IV -> Muralhas I..Fortaleza,
##      escudo, upkeep, Déficit, Ataque da Cidade (mira/ESC/uma vez por turno/save), paridade da IA.
## §128 Supremacia Militar V2: acesso, conquistas de Cidade III+, progresso, perda, vitória.
## §129 Cerco x Fortaleza x vitória: a Munição e o Bombardeio atravessam a Fortaleza (escudo
##      primeiro), a captura mantém a fortificação e fecha a vitória.
## Atalhos DECLARADOS: debug_mode acelera só a PRODUÇÃO humana pra 1 turno; o Ouro dos projetos de
## City Level (Fase 13) é concedido; cidades rivais de teste são fundadas num terreno limpo
## ("arena") e as unidades militares de teste nascem direto (não é o assunto destes fluxos).

const TEST_SAVE_PATH := "user://test_v2_phase16_main_flow_savegame.json"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const BOMBARD := "v2_unit_bombard"
const BOMBARDMENT := "v2_technique_prepared_bombardment"
const CAPSTONE := "v2_supreme_army"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _arena_centers: Array[Vector2i] = []

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
	_arena_centers.clear()

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
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

# --- Helpers ---------------------------------------------------------------------------------------

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

func _research_unlock(state: V2ResearchState, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	if state.is_completed(node.id):
		return
	assert_true(state.select_research(node.id), "select %s" % node.id)
	state.add_knowledge(node.cost)
	assert_true(state.is_completed(node.id), "concluiu %s" % node.id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")
	_clear_wandering_monsters_near_human_cities()

## Mesma razão dos fluxos das Doutrinas: sem a milícia automática, monstros errantes do mapa gerado
## podem encostar na cidade humana e roubar tiles/ser alvos que este fluxo não controla.
func _clear_wandering_monsters_near_human_cities() -> void:
	var grid: HexGrid = GameManager.hex_grid
	for city in GameManager.human_player.cities:
		for coord in HexMetrics.coords_within(city.coord, 3):
			var unit := grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.world_event_managed:
				grid.remove_unit(unit)

func _notified(text: String) -> bool:
	for i in get_signal_emit_count(EventBus, "notify"):
		if String(get_signal_parameters(EventBus, "notify", i)[0]) == text:
			return true
	return false

## Projeto local pela fila (mesmo gate do botão da HUD) + fim de turno.
func _run_city_project(city: City, project_id: String) -> void:
	_clear_city_ring(city)
	city.set_production(project_id)
	assert_eq(city.production_item, project_id)
	_end_turn()

func _clear_city_ring(city: City) -> void:
	var grid: HexGrid = GameManager.hex_grid
	for unit in GameManager.human_player.units.duplicate():
		if not is_instance_valid(unit) or HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		for coord in HexMetrics.coords_within(city.coord, 6):
			if HexMetrics.axial_distance(coord, city.coord) >= 4 and grid.tiles.has(coord) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
				grid.teleport_unit(unit, coord)
				break

func _upgrade_city(city: City, level: int) -> void:
	GameManager.human_player.gold += V2CityLevelData.upgrade_gold_cost(level) + 50.0 # Ouro concedido (atalho declarado)
	assert_true(city.can_start_city_upgrade(), city.city_upgrade_unavailable_reason())
	_run_city_project(city, V2CityLevelData.project_id_for_level(level))
	assert_eq(city.city_level, level, "Cidade %d" % level)

func _fortify(city: City, level: int) -> void:
	assert_true(city.can_start_fortification(), city.fortification_unavailable_reason())
	_run_city_project(city, V2FortificationData.project_id(level))
	assert_eq(city.fortification_level, level, V2FortificationData.display_name(level))

## Um disco de grama limpo (sem unidades), longe de toda cidade existente e de outras arenas.
func _arena(grid: HexGrid, radius: int = 3) -> Vector2i:
	for coord in grid.tiles.keys():
		var ok := true
		for c in HexMetrics.coords_within(coord, radius + 1):
			if not grid.tiles.has(c):
				ok = false
				break
		if not ok:
			continue
		for other in grid.cities_by_coord.keys():
			if HexMetrics.axial_distance(coord, other) <= radius + 4:
				ok = false
				break
		for other in _arena_centers:
			if HexMetrics.axial_distance(coord, other) <= 2 * radius + 4:
				ok = false
		if not ok:
			continue
		for c in HexMetrics.coords_within(coord, radius):
			grid.tiles[c] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			var occupant := grid.get_unit_at(c)
			if occupant != null:
				grid.remove_unit(occupant)
		_arena_centers.append(coord)
		return coord
	fail_test("sem espaço pra uma arena de raio %d" % radius)
	return Vector2i(999, 999)

func _rival_city(grid: HexGrid, owner: PlayerData, level: int, fortification: int = 0) -> City:
	var center := _arena(grid)
	var city := grid.found_city(center, owner, "Centro de %s" % owner.civ.civ_name, true)
	city.city_level = level
	city.fortification_level = fortification
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	return city

func _spawn(grid: HexGrid, kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var occupant := grid.get_unit_at(coord)
	if occupant != null:
		grid.remove_unit(occupant) # tile de teste: sai quem sobrou de um passo anterior
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

## Ataque básico real (seleção + clique) até a cidade trocar de dono.
func _capture_with(grid: HexGrid, attacker: Unit, city: City) -> void:
	var owner := attacker.owner_player
	for i in 40:
		if city.owner_player == owner:
			return
		attacker.movement_left = attacker.unit_data.movement_points
		attacker.hp = attacker.unit_data.max_hp
		SelectionManager._select_unit(attacker)
		SelectionManager._attack_from_selected(city.coord)
	assert_eq(city.owner_player, owner, "capturou %s" % city.city_name)

func _save_and_load() -> HexGrid:
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH))
	GameManager.hex_grid = loaded
	return loaded

func _city_named(player: PlayerData, city_name: String) -> City:
	for city in player.cities:
		if city.city_name == city_name:
			return city
	return null

# --- §127 Fluxo principal de infraestrutura defensiva -------------------------------------------------

func test_127_defensive_infrastructure_flow_from_city_i_to_the_fortress():
	# 1-2. Nova partida; a cidade nasce Cidade I (24 de vida), sem fortificação, escudo nem disparo.
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var state := human.v2_research
	var city := _found_human_city(grid)
	assert_eq([city.city_level, city.max_hp(), city.fortification_level, city.max_shield()], [1, 24.0, 0, 0.0], "1-2. Cidade I sem muralha")
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Requer fortificação (Muralhas I ou superior).")
	# 3. Sem Urbanização N1, Muralhas I é bloqueada pela pesquisa.
	assert_eq(city.fortification_unavailable_reason(), "Requer Planejamento Urbano.", "3")
	# 4. Pesquisa N1 por Conhecimento: o toast menciona Cidade II e Muralhas I.
	watch_signals(EventBus)
	_research_unlock(state, "v2_city_level_2")
	assert_true(_notified("Desenvolvimento urbano disponível: Cidade II e Muralhas I."), "4. toast")
	# 5. Ainda Cidade I: falta o nível urbano.
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade II.", "5")
	# 6. Projeto de Cidade II pela fila: vida máxima 30, fração preservada (cheia).
	_upgrade_city(city, 2)
	assert_eq([city.max_hp(), city.hp], [30.0, 30.0], "6")
	# 7. Muralhas I pela MESMA fila, sem ocupar slot.
	var slots_before := city.used_building_slots()
	var upkeep_before := V2EconomyRuntime.city_gold_upkeep(city)
	_fortify(city, 1)
	assert_eq(city.used_building_slots(), slots_before, "7. sem slot")
	assert_false(city.buildings.has("walls"), "7. fora de City.buildings")
	# 8. Escudo cheio, defesa +10%, disparo 3 | 2.
	assert_eq([city.shield, city.max_shield()], [8.0, 8.0], "8. escudo")
	assert_almost_eq(city.defense_bonus(), 0.10, 0.0001)
	assert_eq([CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [3.0, 2])
	# 9. Upkeep de 1 Ouro/turno entra na manutenção da cidade.
	assert_almost_eq(V2EconomyRuntime.city_gold_upkeep(city) - upkeep_before, 1.0, 0.0001, "9")
	# 10. Painel: bloco de fortificação.
	var panel := "\n".join(TileInspector._city_entry(city, grid, human).lines)
	for line in ["Muralhas I", "Escudo: 8 / 8", "Defesa urbana: +10%", "Ataque da Cidade: 3 | Alcance 2"]:
		assert_string_contains(panel, line)
	# 11. Um inimigo visível a 2: a mira destaca, ESC cancela sem gastar.
	var arena_coord := Vector2i(999, 999)
	for coord in HexMetrics.coords_within(city.coord, 2):
		if HexMetrics.axial_distance(coord, city.coord) == 2 and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			arena_coord = coord
			break
	assert_ne(arena_coord, Vector2i(999, 999), "pré-condição: tile livre a 2")
	var raider := _spawn(grid, "warrior", rival, arena_coord)
	grid.recompute_fog(human)
	var raider_hp := raider.hp
	SelectionManager.start_city_attack_targeting(city)
	assert_true(raider.coord in SelectionManager.city_attack_coords, "11. alvo destacado")
	assert_true(SelectionManager.cancel_city_attack_targeting(), "11. ESC")
	assert_eq([raider.hp, city.last_city_attack_turn], [raider_hp, -1], "11. nada gasto")
	# 12. Clique válido: 3 de dano fixo, sem revide; o disparo do turno acabou.
	var city_hp := city.hp
	SelectionManager.start_city_attack_targeting(city)
	SelectionManager._handle_city_attack_click(raider.coord)
	assert_eq(raider.hp, raider_hp - 3.0, "12. dano fixo")
	assert_eq(city.hp, city_hp, "12. sem revide")
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Ataque da Cidade já usado neste turno.")
	# 13. Save/load no MESMO turno: continua usado; fortificação e escudo sobrevivem.
	var loaded := _save_and_load()
	human = GameManager.human_player
	rival = GameManager.rival_players[0]
	state = human.v2_research
	city = human.cities[0]
	grid = loaded
	assert_eq(city.fortification_level, 1, "13")
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "Ataque da Cidade já usado neste turno.", "13. continua usado")
	# 14. Próximo turno: disponível de novo.
	for unit in rival.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) <= 3:
			grid.remove_unit(unit) # o invasor de teste sai de cena (a IA rival poderia atacar com ele)
	_end_turn()
	assert_eq(CityDefense.city_attack_unavailable_reason(city), "", "14. novo turno")
	# 15. Paridade da IA: uma cidade rival fortificada dispara sozinha no turno dela.
	var rival_city := _rival_city(grid, rival, 2, 1)
	var scout := _spawn(grid, "warrior", human, rival_city.coord + Vector2i(2, 0))
	var scout_hp := scout.hp
	_end_turn()
	assert_true(is_instance_valid(scout) and scout.hp <= scout_hp - 3.0, "15. a cidade da IA disparou (3)")
	# 16. Urbanização N2: Cidade III e Muralhas II.
	_research_unlock(state, "v2_city_level_3")
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade III.", "16")
	_upgrade_city(city, 3)
	# 17. Déficit bloqueia o INÍCIO de Muralhas II.
	var saved_gold := human.gold
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "17. pré-condição")
	assert_eq(city.fortification_unavailable_reason(), "Déficit de Ouro: estabilize a economia antes de ampliar a fortificação.", "17")
	assert_eq(CityDefense.city_attack_power(city), 1.5, "17. Déficit reduz só o disparo")
	city.buildings.erase(G_HALL)
	city.buildings.erase(G_MASTERY)
	human.gold = saved_gold
	# 18. Escudo danificado (5/8) -> Muralhas II preserva o dano absoluto: 11/14.
	city.shield = 5.0
	_fortify(city, 2)
	assert_gt(city.shield, 10.99, "18. 14 - 3 (+ regeneração normal do turno)")
	assert_lt(city.shield, 14.0, "18. nunca cura cheio no upgrade")
	assert_eq([CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [5.0, 2])
	# 19-20. N3 -> Cidade IV (44) -> Fortaleza (22 | +30% | 7 | 3).
	_research_unlock(state, "v2_city_level_4")
	_upgrade_city(city, 4)
	assert_eq(city.max_hp(), 44.0, "19")
	_fortify(city, 3)
	assert_eq([city.max_shield(), CityDefense.city_attack_power(city), CityDefense.city_attack_range(city)], [22.0, 7.0, 3], "20")
	assert_almost_eq(city.defense_bonus(), 0.30, 0.0001)
	# 21. Topo: nenhum nível adiante; upkeep total da Fortaleza é 3 (não 6).
	assert_eq(city.fortification_unavailable_reason(), "Fortificação já está no nível máximo.", "21")
	assert_almost_eq(V2EconomyRuntime.city_gold_upkeep(city) - upkeep_before, 3.0, 0.0001, "21. só o nível atual")

# --- §128 Fluxo principal da Supremacia Militar V2 ---------------------------------------------------

func test_128_military_supremacy_flow_to_victory():
	# 1-2. Nova partida com dois rivais major, em guerra com ambos.
	var grid := _new_game()
	var human := GameManager.human_player
	var rival_a: PlayerData = GameManager.rival_players[0]
	var rival_b: PlayerData = GameManager.rival_players[1]
	Diplomacy.declare_war(human, rival_a)
	Diplomacy.declare_war(human, rival_b)
	var capital := _found_human_city(grid)
	assert_not_null(capital)
	assert_eq(V2VictoryConditions.military_supremacy_status(human).rival_count, 2, "1-2")
	# 3. Sem o Exército Supremo: sem acesso.
	assert_false(V2VictoryConditions.military_supremacy_status(human).access, "3")
	# 4. Capturar uma Cidade II de A NÃO vale.
	var small := _rival_city(grid, rival_a, 2)
	small.city_name = "Vila de A" # nome distinto do centro desenvolvido de A (usado depois do load)
	var knight := _spawn(grid, "warrior", human, small.coord + Vector2i(1, 0))
	knight.unit_data.attack = 30.0
	watch_signals(EventBus)
	_capture_with(grid, knight, small)
	assert_eq(small.v2_supremacy_captured_from, -1, "4. Cidade II não qualifica")
	assert_false(_notified("Supremacia: conquista válida contra %s." % rival_a.civ.civ_name))
	# 5. Desenvolvê-la depois continua não valendo.
	small.apply_city_level(3)
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, rival_a), "5")
	# 6. Capturar uma Cidade III de A vale (toast) — mesmo sem acesso, o progresso existe.
	var center_a := _rival_city(grid, rival_a, 3)
	_place(grid, knight, center_a.coord + Vector2i(1, 0))
	_capture_with(grid, knight, center_a)
	assert_eq(center_a.v2_supremacy_captured_from, GameManager.players.find(rival_a), "6. id estável")
	assert_true(_notified("Supremacia: conquista válida contra %s." % rival_a.civ.civ_name), "6. toast")
	var lines := V2VictoryConditions.military_supremacy_lines(human)
	assert_eq(lines[0], "Supremacia Militar: 1 / 2 rivais satisfeitos", "6. progresso")
	# 7. Pesquisa do Exército Supremo (duas Doutrinas completas + capstone).
	human.v2_research.debug_complete_branch(MILITARY, "guardian")
	human.v2_research.debug_complete_branch(MILITARY, "warrior")
	assert_true(human.v2_research.complete_research(CAPSTONE))
	assert_true(V2VictoryConditions.military_supremacy_status(human).access, "7")
	# 8. Ainda pendente (B): o turno não encerra a partida.
	_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "8")
	# 9. Save/load preserva o crédito (id estável) sem salvar progresso.
	_save_and_load()
	grid = GameManager.hex_grid
	human = GameManager.human_player
	rival_a = GameManager.rival_players[0]
	rival_b = GameManager.rival_players[1]
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(human, rival_a), "9")
	# 10. Perder a cidade qualificada perde o crédito...
	var held := _city_named(human, center_a.city_name)
	assert_not_null(held)
	var raider := _spawn(grid, "warrior", rival_a, held.coord + Vector2i(-1, 0))
	raider.unit_data.attack = 60.0
	Diplomacy.declare_war(rival_a, human)
	for i in 20:
		if held.owner_player == rival_a:
			break
		CombatResolver.resolve_city_attack(raider, held, grid)
	assert_eq(held.owner_player, rival_a, "10. retomada")
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, rival_a), "10. crédito perdido")
	# 11. ...e reconquistá-la (ainda Cidade III) devolve.
	grid.remove_unit(raider)
	var knight2 := _spawn(grid, "warrior", human, held.coord + Vector2i(1, 0))
	knight2.unit_data.attack = 30.0
	_capture_with(grid, knight2, held)
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(human, rival_a), "11")
	# 12. Cidade IV de B capturada: 2 / 2 e a própria ação encerra a partida (check_victories).
	var center_b := _rival_city(grid, rival_b, 4)
	_place(grid, knight2, center_b.coord + Vector2i(1, 0))
	watch_signals(EventBus)
	_capture_with(grid, knight2, center_b)
	assert_eq(V2VictoryConditions.military_supremacy_lines(human)[0], "Supremacia Militar: 2 / 2 rivais satisfeitos", "12")
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "12. vitória")
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY])
	# 13. A V1.5 continua intocada.
	assert_false("researched_techs" in human, "Fase 25: estado V1 removido")

func _place(grid: HexGrid, unit: Unit, coord: Vector2i) -> void:
	var occupant := grid.get_unit_at(coord)
	if occupant != null and occupant != unit:
		grid.remove_unit(occupant)
	grid.teleport_unit(unit, coord)
	unit.movement_left = unit.unit_data.movement_points

# --- §129 Cerco x Fortaleza x vitória ------------------------------------------------------------------

func test_129_siege_breaks_a_fortress_and_the_capture_closes_the_victory():
	var grid := _new_game()
	var human := GameManager.human_player
	var rival_a: PlayerData = GameManager.rival_players[0]
	var rival_b: PlayerData = GameManager.rival_players[1]
	Diplomacy.declare_war(human, rival_a)
	Diplomacy.declare_war(human, rival_b)
	_found_human_city(grid)
	human.v2_research.debug_complete_branch(MILITARY, "guardian")
	human.v2_research.debug_complete_branch(MILITARY, "warrior")
	assert_true(human.v2_research.complete_research(CAPSTONE))
	for n in range(1, 7):
		human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	# B já está satisfeito por uma Cidade III conquistada antes.
	var center_b := _rival_city(grid, rival_b, 3)
	var knight := _spawn(grid, "warrior", human, center_b.coord + Vector2i(1, 0))
	knight.unit_data.attack = 30.0
	_capture_with(grid, knight, center_b)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "A ainda pendente")
	# A: Cidade IV com Fortaleza (escudo 22, +30%).
	var fortress := _rival_city(grid, rival_a, 4, 3)
	assert_eq([fortress.shield, fortress.defense_bonus()], [22.0, 0.30])
	var bombard := _spawn(grid, BOMBARD, human, fortress.coord + Vector2i(2, 0))
	grid.recompute_fog(human) # a mira humana exige ver a cidade
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(bombard), 1.4, 0.0001, "Munição")
	var expected: float = bombard.unit_data.attack * bombard.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(bombard) * V2TechniqueRuntime.city_attack_multiplier(bombard) / 1.3
	# Bombardeio Preparado (N6, x1,5, parado): atravessa a Fortaleza — escudo primeiro, vida intacta.
	var hp_before := fortress.hp
	assert_true(V2TechniqueRuntime.perform_city_strike(bombard, BOMBARDMENT, fortress, grid), V2TechniqueRuntime.unavailable_reason(bombard, BOMBARDMENT, grid))
	assert_almost_eq(fortress.shield, 22.0 - expected * 1.5, 0.0001, "Bombardeio x1,5 com Munição, dividido por 1,3")
	assert_eq(fortress.hp, hp_before, "a vida só depois do escudo")
	# Munição Demolidora (N4) no ataque básico: o que sobra do escudo cai, o excedente vai pra vida.
	_end_turn()
	bombard.movement_left = bombard.unit_data.movement_points
	var basic: float = bombard.unit_data.attack * bombard.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(bombard) * V2TechniqueRuntime.city_attack_multiplier(bombard) / 1.3
	var total_before := fortress.shield + fortress.hp
	CombatResolver.resolve_city_attack(bombard, fortress, grid)
	assert_almost_eq(total_before - (fortress.shield + fortress.hp), basic, 0.0001, "ataque básico com Munição contra a Fortaleza")
	# Termina de derrubar e captura com o ataque básico.
	for i in 40:
		if fortress.owner_player == human:
			break
		bombard.movement_left = bombard.unit_data.movement_points
		bombard.hp = bombard.unit_data.max_hp
		SelectionManager._select_unit(bombard)
		SelectionManager._attack_from_selected(fortress.coord)
	assert_eq(fortress.owner_player, human, "capturada")
	# A Fortaleza sobrevive à captura (escudo NÃO reconstruído), o disparo do turno está gasto, e a
	# captura da Cidade IV fecha a vitória V2.
	assert_eq(fortress.fortification_level, 3)
	assert_eq(fortress.shield, 0.0, "nunca reconstruída de graça")
	assert_eq(CityDefense.city_attack_unavailable_reason(fortress), "Ataque da Cidade já usado neste turno.")
	assert_eq(fortress.v2_supremacy_captured_from, GameManager.players.find(rival_a))
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "vitória por Supremacia Militar V2")
