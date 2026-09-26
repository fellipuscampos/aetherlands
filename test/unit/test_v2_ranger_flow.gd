extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Patrulheiro N1-N9 (Aetherlands V2, Fase 8), pelos mesmos caminhos do jogo (HUD/SelectionManager/produção/save/neblina):
## jogo novo -> N1 -> N2 -> Campo dos Patrulheiros -> N3 -> Arqueiro -> ataque básico a 2 tiles (sem revide) -> N4 -> Disparo Preciso a 3 tiles (mira, ESC, clique)
## -> N5 -> Caçador (upgrade) -> N6 -> Saraivada em agrupamento (até 3 alvos) -> N7 -> Atirador de Elite (alcance 3; Disparo Preciso a 4) -> N8 -> Torre -> N9 ->
## Caçador de Lendas -> Caçada Lendária -> salvar -> carregar -> slot Lendário compartilhado com as outras duas Doutrinas. O modo debug (GameManager.debug_mode)
## só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_ranger_flow_savegame.json"
const HALL := "v2_building_ranger_camp"
const ARCHER := "v2_unit_archer"
const HUNTER := "v2_unit_hunter"
const MARKSMAN := "v2_unit_elite_marksman"
const TOWER := "v2_building_ranger_mastery"
const LEGEND_HUNTER := "v2_legendary_legend_hunter"
const PRECISE := "v2_technique_precise_shot"
const VOLLEY := "v2_technique_volley"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const W_HALL := "v2_building_warrior_hall"
const ARENA := "v2_building_warrior_mastery"
const CHAMPION := "v2_legendary_guardian_champion"
const HERO := "v2_legendary_blade_hero"
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
	_clear_wandering_monsters_next_to_human_cities()

## Aetherlands V2, Fase 16 — a milícia AUTOMÁTICA (que abatia monstros neutros colados às cidades todo
## turno) saiu; a defesa própria agora é o Ataque da Cidade, explícito e só com fortificação. Este
## fluxo verifica a Doutrina, não pressão de monstros: remove os monstros errantes do mapa gerado que
## encostarem numa cidade humana (o que a milícia antiga fazia de graça), pra não ocuparem os tiles
## de construção/treino.
func _clear_wandering_monsters_next_to_human_cities() -> void:
	var grid: HexGrid = GameManager.hex_grid
	for city in GameManager.human_player.cities:
		for coord in grid.get_neighbors(city.coord):
			var unit := grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.world_event_managed:
				grid.remove_unit(unit)

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

# --- Helpers do Patrulheiro ------------------------------------------------------------------------------------

## Constrói `building_id` na cidade pelo fluxo normal (posicionamento de tile + fim de turno).
func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

func _trainable_forms(city: City) -> Array:
	return [ARCHER, HUNTER, MARKSMAN].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

## Um tile de terra livre a EXATAMENTE `distance` de `center` (ordem fixa), fora de `avoid`.
func _free_at(grid: HexGrid, center: Vector2i, distance: int, avoid: Array = []) -> Vector2i:
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and grid.tiles.has(coord) and not (coord in avoid) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile livre a distância %d de %s" % [distance, str(center)])
	return Vector2i(999, 999)

func _spawn_foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, hp: float = 100.0, defense: float = 3.0) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.max_hp = hp
	data.defense = defense
	var foe := grid.spawn_unit(coord, data, owner)
	assert_not_null(foe, "inimigo em %s" % str(coord))
	return foe

func _clear_foes(grid: HexGrid, foes: Array) -> void:
	for foe in foes:
		if is_instance_valid(foe) and foe.hp > 0.0:
			grid.remove_unit(foe)

## Uma SEGUNDA cidade do humano (com os prédios `buildings`) num tile válido distante da primeira.
func _second_city(grid: HexGrid, human: PlayerData, buildings: Array[String]) -> City:
	for coord in grid.tiles.keys():
		if CitySite.rejection_reason(grid, coord, human) == "" and grid.get_unit_at(coord) == null:
			var city := grid.found_city(coord, human, "Segunda Cidade", true)
			for id in buildings:
				city.buildings[id] = true
			return city
	fail_test("sem tile válido pra a segunda cidade")
	return null

## Cenário curto: jogo novo, cidade com Campo, Patrulheiro pesquisado até `through` e um Arqueiro vivo, em guerra com o rival.
func _short_setup(through: int = 4) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Campo/Torre (upkeep de Ouro)
	# e chegam a treinar o Caçador de Lendas (5 Suprimentos, acima da capacidade base de uma
	# cidade sozinha). Ouro de sobra + uma Fazenda evitam bloqueio alheio ao teste.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(ARCHER), human)
	assert_not_null(unit)
	grid.recompute_fog(human)
	return {"grid": grid, "human": human, "rival": rival, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_ranger_n1_to_n9_flow_from_the_camp_to_the_legend_hunter_across_save_and_load():
	# 1. Nova partida (em guerra com o rival, pra os tiros terem alvo).
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — a forma viva (N5, 2) mais o Atirador de Elite (N7, 3) já somam 5,
	# acima da base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo
	# pré-existente tropece num gate que não é o assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o upkeep) -- Ouro
	# de sobra evita que isso sozinho derrube a cidade em Déficit assim que o Campo é construído.
	human.gold = 1000.0
	assert_false(V2UnlockSystem.is_unlocked(human, "v2_doctrine_ranger"))

	# 2. N1: estabelece a linha, sem bônus; só o N2 fica disponível.
	_research(state, "v2_doctrine_ranger_1")
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_ranger"], "2. o N1 não libera nada além da Doutrina")
	assert_false(city.can_build(HALL))
	assert_true(state.is_available("v2_doctrine_ranger_2"))

	# 3-4. N2 e o Campo dos Patrulheiros (construção normal).
	_research(state, "v2_doctrine_ranger_2")
	assert_true(city.can_build(HALL), "3. N2 libera o Campo")
	_build(grid, city, HALL)

	# 5-6. N3 e o Arqueiro.
	assert_false(city.can_train(ARCHER), "sem N3 não treina")
	_research(state, "v2_doctrine_ranger_3")
	assert_true(_train(city, ARCHER), "6. Arqueiro em treino")
	var archers := _units_of_kind(human, ARCHER)
	assert_eq(archers.size(), 1)
	var unit: Unit = archers[0]
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack_range], [13.0, 2])

	# 7. Ataque básico ranged a 2 tiles: hostil, no alcance, sem revide; a 3 tiles fica fora.
	unit.movement_left = unit.unit_data.movement_points
	var near := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 2), 100.0, 14.0)
	var out_of_reach := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 3))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_true(near.coord in SelectionManager.attackable, "7. alvo a 2 tiles")
	assert_false(out_of_reach.coord in SelectionManager.attackable, "a 3 tiles fica fora do alcance básico")
	var basic: Dictionary = CombatResolver.predict(unit, near, grid)
	assert_false(basic.is_melee_range)
	assert_eq(basic.damage_to_attacker, 0.0, "sem revide a distância")
	var near_hp := near.hp
	var my_hp := unit.hp
	SelectionManager._attack_from_selected(near.coord)
	assert_almost_eq(near_hp - near.hp, basic.damage_to_defender, 0.0001, "previsão == resolução")
	assert_eq(unit.hp, my_hp)
	assert_eq(unit.movement_left, 0.0)
	_clear_foes(grid, [near, out_of_reach])

	# 8-10. N4 e o Disparo Preciso a 3 tiles: mira, cancelamento sem gastar nada, clique.
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "antes do N4 não há técnica")
	_research(state, "v2_doctrine_ranger_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [PRECISE], "8. Disparo Preciso")
	unit.movement_left = unit.unit_data.movement_points
	var shot_target := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 3))
	var too_far := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 4))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	var predicted: float = CombatResolver.predict(unit, shot_target, grid, 1.4).damage_to_defender
	SelectionManager.use_technique_selected(PRECISE)
	assert_eq(SelectionManager.technique_targeting_id, PRECISE, "9. entrou no modo de mira")
	assert_true(shot_target.coord in SelectionManager.technique_target_coords, "o alvo válido a 3 tiles está destacado")
	assert_false(too_far.coord in SelectionManager.technique_target_coords, "o de 4 tiles fica fora")
	for coord in SelectionManager.technique_target_coords:
		assert_lte(HexMetrics.axial_distance(unit.coord, coord), 3, "nada além do alcance básico + 1")
	assert_eq(unit.movement_left, unit.unit_data.movement_points, "a mira não gasta a ação")
	assert_false(unit.magic_cooldowns.has(PRECISE))
	assert_true(SelectionManager.cancel_technique_targeting(), "10. ESC cancela")
	assert_eq(unit.movement_left, unit.unit_data.movement_points)
	assert_false(unit.magic_cooldowns.has(PRECISE), "cancelar não inicia a recarga")
	SelectionManager.use_technique_selected(PRECISE)
	var shot_hp := shot_target.hp
	SelectionManager._handle_technique_targeting_click(shot_target.coord)
	assert_almost_eq(shot_hp - shot_target.hp, predicted, 0.0001, "o tiro real bate com a previsão de 1,40x")
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, PRECISE), 3)
	_clear_foes(grid, [shot_target, too_far])

	# 11-13. N5 e o Caçador: a produção oferece só ele e o Arqueiro evolui pelo V2UnitUpgrade (24 Ouro).
	_research(state, "v2_doctrine_ranger_5")
	assert_eq(_trainable_forms(city), [HUNTER], "13. a produção oferece só o Caçador — 32 PP")
	_end_turn()
	human.gold = 100.0
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, HUNTER, "12. evoluiu para Caçador")
	assert_eq(human.gold, 100.0 - 24.0, "2 x (32 - 20) = 24 Ouro")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, PRECISE), 2, "a recarga do Disparo foi preservada pela evolução")

	# 14-17. N6 e a Saraivada: um agrupamento hostil, até 3 alvos, dano individual.
	_research(state, "v2_doctrine_ranger_6")
	_end_turn()
	unit.movement_left = unit.unit_data.movement_points
	var primary_coord := _free_at(grid, unit.coord, 2)
	var primary := _spawn_foe(grid, rival, primary_coord)
	var cluster: Array = [primary]
	var taken: Array = [primary_coord, unit.coord]
	for n in grid.get_neighbors(primary_coord):
		if cluster.size() >= 4:
			break
		if n != unit.coord and WorldSetup._is_valid_spawn(grid, n) and grid.get_city_at(n) == null and not (n in taken):
			cluster.append(_spawn_foe(grid, rival, n))
			taken.append(n)
	assert_gte(cluster.size(), 3, "15. agrupamento hostil")
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	var volley := V2DoctrineTechniqueDatabase.get_technique(VOLLEY)
	var victims := V2TechniqueRuntime.strike_victims(unit, volley, primary, grid)
	assert_eq(victims.size(), 3, "17. até 3 alvos, primário incluso")
	assert_eq(victims[0], primary, "o primário sempre entra")
	var volley_before: Dictionary = {}
	var volley_expected: Dictionary = {}
	for victim in victims:
		volley_before[victim] = victim.hp
		volley_expected[victim] = CombatResolver.predict(unit, victim, grid, 0.7).damage_to_defender
	SelectionManager.use_technique_selected(VOLLEY) # 16. mira do primário
	assert_eq(SelectionManager.technique_targeting_id, VOLLEY, "a Saraivada tem mira (não é o Arco do Guerreiro)")
	assert_true(primary.coord in SelectionManager.technique_target_coords)
	SelectionManager._handle_technique_targeting_click(primary.coord)
	for victim in victims:
		assert_almost_eq(volley_before[victim] - victim.hp, volley_expected[victim], 0.0001, "dano individual a 0,70x por alvo")
	var untouched := 0
	for other in cluster:
		if not (other in victims):
			assert_eq(other.hp, 100.0, "quem passou do teto de 3 não é atingido")
			untouched += 1
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY), 4)
	assert_eq(unit.movement_left, 0.0)
	_clear_foes(grid, cluster)

	# 18-22. N7 e o Atirador de Elite: alcance básico 3, Disparo Preciso a 4.
	_research(state, "v2_doctrine_ranger_7")
	assert_eq(_trainable_forms(city), [MARKSMAN], "20. a produção oferece só o Atirador de Elite — 48 PP")
	_end_turn()
	human.gold = 100.0
	SelectionManager._select_unit(unit)
	assert_true(V2UnitUpgrade.can_upgrade(human, unit, grid), V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid))
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, MARKSMAN, "19. evoluiu para Atirador de Elite")
	assert_eq(human.gold, 100.0 - 32.0, "2 x (48 - 32) = 32 Ouro")
	assert_eq(unit.unit_data.attack_range, 3)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [PRECISE, VOLLEY], "herda as duas técnicas")
	unit.movement_left = unit.unit_data.movement_points
	var at_three := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 3))
	var at_four := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 4))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_true(at_three.coord in SelectionManager.attackable, "21. ataque básico a 3 tiles")
	assert_false(at_four.coord in SelectionManager.attackable, "a 4 tiles o ataque básico não chega")
	unit.magic_cooldowns.erase(PRECISE)
	SelectionManager.use_technique_selected(PRECISE)
	assert_true(at_four.coord in SelectionManager.technique_target_coords, "22. Disparo Preciso a 4 tiles (alcance 3 + 1)")
	assert_true(at_three.coord in SelectionManager.technique_target_coords)
	SelectionManager.cancel_technique_targeting()
	_clear_foes(grid, [at_three, at_four])

	# 23-25. N8 e a Torre dos Patrulheiros (exige o Campo).
	assert_false(city.can_build(TOWER), "antes do N8 não constrói")
	_research(state, "v2_doctrine_ranger_8")
	assert_true(city.can_build(TOWER), "23. N8 libera a Torre")
	_build(grid, city, TOWER)
	assert_true(city.buildings.has(HALL), "a Torre não substitui o Campo")
	assert_false(city.can_train(LEGEND_HUNTER), "sem N9 o Caçador de Lendas ainda não treina")

	# 25-27. N9 e o Caçador de Lendas: produção separada; o Atirador segue disponível no Campo.
	_research(state, "v2_doctrine_ranger_9")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "só o Patrulheiro completo: 1 / 2")
	assert_true(city.can_train(LEGEND_HUNTER))
	assert_true(_train(city, LEGEND_HUNTER), "26. Caçador de Lendas em treino")
	var legends := _units_of_kind(human, LEGEND_HUNTER)
	assert_eq(legends.size(), 1)
	var hunter: Unit = legends[0]
	assert_true(V2LegendarySystem.is_legendary_unit(hunter))
	assert_same(V2LegendarySystem.active_legendary(human), hunter)
	assert_eq(_trainable_forms(city), [MARKSMAN], "27. o Atirador de Elite continua disponível no Campo")

	# 28-30. Caçada Lendária: unidade comum sem bônus; Lendária inimiga com +40%; previsão == resolução.
	hunter.movement_left = hunter.unit_data.movement_points
	var common := _spawn_foe(grid, rival, _free_at(grid, hunter.coord, 2), 100.0, 3.0)
	var legend_data := UnitDatabase.create_unit(CHAMPION)
	var legend_foe := grid.spawn_unit(_free_at(grid, hunter.coord, 3), legend_data, rival)
	assert_not_null(legend_foe)
	grid.recompute_fog(human)
	assert_eq(UnitAbilities.trait_attack_multiplier(hunter, common), 1.0, "28. unidade comum: sem bônus")
	assert_eq(UnitAbilities.trait_attack_multiplier(hunter, legend_foe), 1.4, "29. Campeão Guardião: +40%")
	var legend_predicted: float = CombatResolver.predict(hunter, legend_foe, grid).damage_to_defender
	var legend_hp := legend_foe.hp
	CombatResolver.resolve(hunter, legend_foe, grid)
	assert_almost_eq(legend_hp - legend_foe.hp, legend_predicted, 0.0001, "30. Caçada Lendária: previsão == resolução")
	_clear_foes(grid, [common, legend_foe])

	# 31-38. Salva e carrega: pesquisas, prédios, unidades, recargas, a Caçada (derivada) e o slot global.
	var hunter_coord := hunter.coord
	var precise_left := V2TechniqueRuntime.cooldown_remaining(unit, PRECISE)
	var volley_left := V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY)
	assert_gt(volley_left, 0, "pré-condição: a Saraivada está em recarga")
	var loaded_grid := _save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.v2_research.get_completed_ids().size(), 9, "33. as 9 pesquisas do Patrulheiro")
	var loaded_city: City = loaded.cities[0]
	assert_true(loaded_city.buildings.has(HALL) and loaded_city.buildings.has(TOWER), "34. Campo e Torre restaurados")
	var loaded_marksmen := _units_of_kind(loaded, MARKSMAN)
	assert_eq(loaded_marksmen.size(), 1, "35. o Atirador de Elite voltou")
	var loaded_hunters := _units_of_kind(loaded, LEGEND_HUNTER)
	assert_eq(loaded_hunters.size(), 1, "35. o Caçador de Lendas voltou")
	var loaded_hunter: Unit = loaded_hunters[0]
	assert_eq(loaded_hunter.coord, hunter_coord)
	assert_eq([loaded_hunter.unit_data.max_hp, loaded_hunter.unit_data.attack_range], [30.0, 3])
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_marksmen[0], PRECISE), precise_left, "36. recarga do Disparo Preciso")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_marksmen[0], VOLLEY), volley_left, "36. recarga da Saraivada")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(loaded_hunter).map(func(t): return t.id), [PRECISE, VOLLEY])
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var loaded_legend := loaded_grid.spawn_unit(_free_at(loaded_grid, loaded_hunter.coord, 2), UnitDatabase.create_unit(HERO), loaded_rival)
	var loaded_common := _spawn_foe(loaded_grid, loaded_rival, _free_at(loaded_grid, loaded_hunter.coord, 3))
	assert_eq(UnitAbilities.trait_attack_multiplier(loaded_hunter, loaded_legend), 1.4, "37. a Caçada vale depois do load (derivada do traço)")
	assert_eq(UnitAbilities.trait_attack_multiplier(loaded_hunter, loaded_common), 1.0)
	_clear_foes(loaded_grid, [loaded_legend, loaded_common])
	# 38. Slot global: com o Caçador vivo, o Campeão e o Herói estão bloqueados, mesmo com os prédios e as pesquisas das outras Doutrinas.
	assert_true(V2LegendarySystem.has_active_legendary(loaded), "38. o slot continua ocupado")
	for n in range(1, 10):
		loaded.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	for id in [G_HALL, G_MASTERY, W_HALL, ARENA]:
		loaded_city.buildings[id] = true
	assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)
	assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, HERO), V2LegendarySystem.SLOT_TAKEN_REASON)
	# E as três Doutrinas completas mostram o Exército Supremo 3 / 2 (>= 2): pesquisável, inerte, sem vitória.
	assert_true(loaded.v2_research.is_available("v2_supreme_army"))
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória disparou")

# --- Casos isolados ------------------------------------------------------------------------------------------

func test_cancelling_the_ranged_targeting_by_any_means_consumes_nothing():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 3))
	grid.recompute_fog(c.human)
	SelectionManager._select_unit(unit)
	var hp := foe.hp
	# (a) clique em outro tile (que não é um alvo)
	SelectionManager.use_technique_selected(PRECISE)
	assert_eq(SelectionManager.technique_targeting_id, PRECISE)
	var elsewhere := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if coord != foe.coord and coord != unit.coord and not (coord in SelectionManager.technique_target_coords):
			elsewhere = coord
			break
	SelectionManager._handle_technique_targeting_click(elsewhere)
	assert_eq(SelectionManager.technique_targeting_id, "", "clicar fora cancela")
	assert_eq(foe.hp, hp)
	assert_gt(unit.movement_left, 0.0)
	assert_false(unit.magic_cooldowns.has(PRECISE))
	assert_same(SelectionManager.selected_unit, unit, "a unidade continua selecionada")
	# (b) limpar a seleção
	SelectionManager.use_technique_selected(PRECISE)
	SelectionManager._clear_selection()
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false(unit.magic_cooldowns.has(PRECISE))
	SelectionManager._select_unit(unit)
	# (c) ESC (o mesmo caminho do PauseMenu): cancela a mira da Saraivada, se houver, sem gastar nada; sem mira não faz nada
	SelectionManager.use_technique_selected(VOLLEY)
	var was_targeting: bool = SelectionManager.technique_targeting_id != ""
	assert_eq(SelectionManager.cancel_technique_targeting(), was_targeting)
	assert_false(unit.magic_cooldowns.has(VOLLEY))
	assert_false(SelectionManager.cancel_technique_targeting(), "sem mira o ESC não faz nada")
	# (d) depois de tudo, o tiro ainda funciona
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(PRECISE)
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_lt(foe.hp, hp)

func test_the_precise_shot_only_highlights_visible_enemies_in_range_and_the_volley_starts_from_the_basic_range():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var at_two := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 2))
	var at_three := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 3, [at_two.coord]))
	var at_four := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 4))
	grid.recompute_fog(c.human)
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(PRECISE)
	assert_true(at_two.coord in SelectionManager.technique_target_coords and at_three.coord in SelectionManager.technique_target_coords)
	assert_false(at_four.coord in SelectionManager.technique_target_coords)
	SelectionManager.cancel_technique_targeting()
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(VOLLEY)
	assert_true(at_two.coord in SelectionManager.technique_target_coords)
	assert_false(at_three.coord in SelectionManager.technique_target_coords, "a Saraivada só mira dentro do alcance básico (2)")
	for coord in SelectionManager.technique_target_coords:
		assert_lte(HexMetrics.axial_distance(unit.coord, coord), 2)
	SelectionManager.cancel_technique_targeting()

func test_a_target_in_the_fog_cannot_be_shot_by_the_human():
	var c := _short_setup(4)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 3))
	grid.recompute_fog(c.human)
	grid.visibility[foe.coord] = HexGrid.Visibility.EXPLORED # fora da visão agora
	SelectionManager._select_unit(unit)
	var technique := V2DoctrineTechniqueDatabase.get_technique(PRECISE)
	assert_false(foe in V2TechniqueRuntime.strike_targets(unit, technique, grid), "fora da visão agora: não é alvo")
	SelectionManager.use_technique_selected(PRECISE)
	assert_false(foe.coord in SelectionManager.technique_target_coords, "nem destacado")
	SelectionManager.cancel_technique_targeting()
	grid.visibility[foe.coord] = HexGrid.Visibility.VISIBLE
	assert_true(foe in V2TechniqueRuntime.strike_targets(unit, technique, grid), "visível: é alvo")

func test_the_cooldowns_of_both_ranged_techniques_survive_save_and_load():
	var c := _short_setup(6)
	var unit: Unit = c.unit
	var grid: HexGrid = c.grid
	var target := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 2))
	grid.recompute_fog(c.human)
	assert_true(V2TechniqueRuntime.perform_strike(unit, PRECISE, target, grid))
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2TechniqueRuntime.perform_strike(unit, VOLLEY, target, grid))
	var left := [V2TechniqueRuntime.cooldown_remaining(unit, PRECISE), V2TechniqueRuntime.cooldown_remaining(unit, VOLLEY)]
	assert_eq(left, [3, 4])
	_save_and_reload()
	var loaded_units := _units_of_kind(GameManager.human_player, ARCHER)
	assert_eq(loaded_units.size(), 1)
	assert_eq([V2TechniqueRuntime.cooldown_remaining(loaded_units[0], PRECISE), V2TechniqueRuntime.cooldown_remaining(loaded_units[0], VOLLEY)], left)
	assert_false(loaded_units[0].magic_status.has(PRECISE) or loaded_units[0].magic_status.has(VOLLEY), "nenhum efeito guardado")

func test_a_legend_hunter_in_production_survives_save_and_load_and_blocks_the_other_two_in_another_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	var city: City = c.city
	city.buildings[TOWER] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY, W_HALL, ARENA])
	assert_true(second.can_train(CHAMPION) and second.can_train(HERO))
	city.set_production(LEGEND_HUNTER)
	assert_false(second.can_train(CHAMPION), "o Caçador de Lendas em produção reserva o slot único")
	assert_false(second.can_train(HERO))
	_save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.cities.size(), 2)
	var producing: City = loaded.cities.filter(func(x): return x.production_item == LEGEND_HUNTER)[0]
	var other: City = loaded.cities.filter(func(x): return x != producing)[0]
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded))
	assert_false(other.can_train(CHAMPION), "a reserva vem da ordem de produção salva")
	assert_false(other.can_train(HERO))
	producing.set_production("")
	assert_true(other.can_train(CHAMPION) and other.can_train(HERO), "cancelar libera")

func test_a_legend_hunter_and_a_champion_finishing_in_the_same_turn_never_create_two_legendaries():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	var city: City = c.city
	city.buildings[TOWER] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY])
	# Estado forçado (o gate normal impediria): duas ordens Lendárias prontas no mesmo turno, de Doutrinas diferentes.
	city.set_production(LEGEND_HUNTER)
	second.set_production(CHAMPION)
	_end_turn()
	assert_push_error("não nasceu")
	var legends := 0
	for unit in human.units:
		if V2LegendarySystem.is_legendary_unit(unit):
			legends += 1
	assert_eq(legends, 1, "jamais duas Lendárias ativas")
	assert_eq(V2LegendarySystem.active_legendary_units(human).size(), 1)

func test_the_conventional_marksman_production_is_untouched_by_the_legendary_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[TOWER] = true
	city.set_production(LEGEND_HUNTER)
	assert_true(city.can_train(MARKSMAN))
	city.set_production(MARKSMAN)
	_end_turn()
	assert_eq(_units_of_kind(human, MARKSMAN).size(), 1)
	assert_eq(_units_of_kind(human, LEGEND_HUNTER).size(), 0)

func test_ai_civilizations_keep_playing_with_the_ranger_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(HALL))
			assert_false(rival_city.buildings.has(TOWER))
			assert_ne(rival_city.production_item, LEGEND_HUNTER)
		assert_eq(_units_of_kind(rival, LEGEND_HUNTER).size(), 0)
		assert_eq(_units_of_kind(rival, ARCHER).size(), 0, "a IA não usa conteúdo V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))

func test_an_ai_civilization_given_the_research_by_debug_builds_trains_shoots_and_respects_the_slot():
	var c := _short_setup(3)
	var rival: PlayerData = c.rival
	for n in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	var rival_city: City = rival.cities[0]
	rival_city.city_level = 3
	rival_city.buildings[HALL] = true
	rival_city.buildings[TOWER] = true
	# Aetherlands V2, Fase 15 — o Caçador de Lendas custa 5 Suprimentos (acima da base de 4) e
	# Campo+Torre têm gold_upkeep sem Mercado -- Fazenda + Ouro de sobra evitam que Suprimentos/
	# Déficit bloqueiem o que este teste verifica (RivalAI resolve a forma certa e respeita o slot).
	rival_city.buildings["v2_building_farm"] = true
	rival_city.repeatable_building_counts["v2_building_farm"] = 1
	if rival.gold <= 0.0:
		rival.gold = 1000.0
	var offered: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and rival_city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(MARKSMAN), "resolve a forma correta")
	assert_false(offered.has(ARCHER) or offered.has(HUNTER))
	assert_true(offered.has(LEGEND_HUNTER), "e o Lendário respeita o slot: livre, pode")
	# A técnica funciona sem crash quando a civilização de IA a usa (sem estratégia: só o runtime).
	var grid: HexGrid = c.grid
	var shooter := grid.spawn_unit(_free_at(grid, rival_city.coord, 2), UnitDatabase.create_unit(MARKSMAN), rival)
	var victim := _spawn_foe(grid, c.human, _free_at(grid, shooter.coord, 3))
	assert_true(V2TechniqueRuntime.can_use(shooter, PRECISE, grid), V2TechniqueRuntime.unavailable_reason(shooter, PRECISE, grid))
	assert_true(V2TechniqueRuntime.perform_strike(shooter, PRECISE, victim, grid))
	rival_city.set_production(LEGEND_HUNTER)
	for i in 3:
		_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "não crasha")
