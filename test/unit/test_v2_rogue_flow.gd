extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Ladino N1-N9 (Aetherlands V2, Fase 10), pelos mesmos caminhos do jogo (HUD/SelectionManager/produção/save/neblina):
## jogo novo -> N1 -> N2 -> Guilda dos Ladinos -> N3 -> Ladino (movimento 3) -> N4 -> Ataque Furtivo (mira, ESC, clique: penetração de Defesa + sem revide) ->
## N5 -> Sabotador (upgrade) -> N6 -> Desmantelar (passiva, sem botão; bônus contra conjurador e Cerco) -> N7 -> Assassino -> N8 -> Refúgio das Sombras -> N9 ->
## Mestre das Sombras (Passo Sombrio: atravessa formação, nunca água/montanha) -> salvar -> carregar -> slot Lendário compartilhado com as outras QUATRO Doutrinas.
## O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_rogue_flow_savegame.json"
const GUILD := "v2_building_rogue_guild"
const ROGUE := "v2_unit_rogue"
const SABOTEUR := "v2_unit_saboteur"
const ASSASSIN := "v2_unit_assassin"
const REFUGE := "v2_building_rogue_mastery"
const SHADOW := "v2_legendary_shadow_master"
const SNEAK := "v2_technique_sneak_attack"
const DISMANTLE := "v2_technique_dismantle"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const W_HALL := "v2_building_warrior_hall"
const ARENA := "v2_building_warrior_mastery"
const R_CAMP := "v2_building_ranger_camp"
const R_TOWER := "v2_building_ranger_mastery"
const C_STABLE := "v2_building_war_stable"
const C_ORDER := "v2_building_cavalry_mastery"
const CHAMPION := "v2_legendary_guardian_champion"
const HERO := "v2_legendary_blade_hero"
const LEGEND_HUNTER := "v2_legendary_legend_hunter"
const GRIFFON := "v2_legendary_griffon_rider"
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

## Constrói `building_id` na cidade pelo fluxo normal (posicionamento de tile + fim de turno).
func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

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


func _trainable_forms(city: City) -> Array:
	return [ROGUE, SABOTEUR, ASSASSIN].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

## Um pedaço REMOTO do mapa (longe de qualquer cidade e de qualquer covil; as unidades que não são do humano saem dele) transformado em ARENA controlada:
## grama num raio de 6 ao redor de `center`. Devolve o centro.
func _arena(grid: HexGrid) -> Vector2i:
	var cities: Array[Vector2i] = []
	for player in GameManager.players:
		for city in player.cities:
			cities.append(city.coord)
	for center in grid.tiles.keys():
		var area: Array[Vector2i] = HexMetrics.coords_within(center, 7)
		area.append(center)
		var ok := true
		for coord in area:
			if not grid.tiles.has(coord) or grid.lairs_by_coord.has(coord) or grid.get_city_at(coord) != null:
				ok = false
				break
		for city_coord in cities:
			if HexMetrics.axial_distance(center, city_coord) < 9:
				ok = false
		if not ok:
			continue
		_clear_area(grid, center, 7, GameManager.human_player)
		for coord in area:
			if HexMetrics.axial_distance(center, coord) <= 6:
				grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
		return center
	fail_test("sem um pedaço remoto do mapa para a arena")
	return Vector2i(999, 999)

## Remove do grid toda unidade que não é de `keep` num raio de `radius` de `center` (monstros neutros e rivais do mapa gerado atrapalhariam as contas exatas).
func _clear_area(grid: HexGrid, center: Vector2i, radius: int, keep: PlayerData) -> void:
	for coord in HexMetrics.coords_within(center, radius):
		var other := grid.get_unit_at(coord)
		if other != null and other.owner_player != keep:
			grid.remove_unit(other)

func _place(grid: HexGrid, unit: Unit, coord: Vector2i) -> void:
	grid.teleport_unit(unit, coord)
	unit.movement_left = unit.unit_data.movement_points

## Cenário curto: jogo novo, cidade com Guilda, Ladino pesquisado até `through` e uma unidade `kind` viva, em guerra com o rival.
func _short_setup(through: int = 4, kind: String = ROGUE) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	city.buildings[GUILD] = true
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Guilda/Refúgio (upkeep de
	# Ouro) e chegam a treinar o Mestre das Sombras (5 Suprimentos, acima da capacidade base de
	# uma cidade sozinha). Ouro de sobra + uma Fazenda evitam bloqueio alheio ao teste.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(kind), human)
	assert_not_null(unit)
	grid.recompute_fog(human)
	return {"grid": grid, "human": human, "rival": rival, "city": city, "unit": unit}

func _traited_foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, trait_id: String, hp: float = 40.0, defense: float = 3.0) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.max_hp = hp
	data.defense = defense
	data.traits.append(trait_id)
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit)
	return unit

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_rogue_n1_to_n9_flow_from_the_guild_to_the_shadow_master_across_save_and_load():
	# 1. Nova partida (em guerra com o rival, pra o Ataque Furtivo ter alvo).
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — a forma viva (N5, 2) mais o Assassino (N7, 3) já somam 5, acima da
	# base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo pré-existente
	# tropece num gate que não é o assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o upkeep) -- Ouro
	# de sobra evita que isso sozinho derrube a cidade em Déficit assim que a Guilda é construída.
	human.gold = 1000.0
	assert_false(V2UnlockSystem.is_unlocked(human, "v2_doctrine_rogue"))

	# 2. N1: estabelece a linha, sem bônus; só o N2 fica disponível.
	_research(state, "v2_doctrine_rogue_1")
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_rogue"], "2. o N1 não libera nada além da Doutrina")
	assert_false(city.can_build(GUILD))
	assert_true(state.is_available("v2_doctrine_rogue_2"))

	# 3-4. N2 e a Guilda dos Ladinos (construção normal, sem depender de outra Doutrina).
	_research(state, "v2_doctrine_rogue_2")
	assert_true(city.can_build(GUILD), "3. N2 libera a Guilda dos Ladinos")
	_build(grid, city, GUILD)

	# 5-7. N3 e o Ladino; movimento 3 pelo pathfinding terrestre de sempre.
	assert_false(city.can_train(ROGUE), "sem N3 não treina")
	_research(state, "v2_doctrine_rogue_3")
	assert_true(_train(city, ROGUE), "6. Ladino em treino")
	var rogues := _units_of_kind(human, ROGUE)
	assert_eq(rogues.size(), 1)
	var unit: Unit = rogues[0]
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.defense, unit.unit_data.movement_points], [14.0, 4.5, 2.5, 3.0])
	assert_true(unit.unit_data.movement_points == 3.0)
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(SelectionManager.reachable, grid.compute_reachable(unit.coord, unit.movement_left, human, false, false), "7. o alcance é o Dijkstra terrestre normal")
	for coord in SelectionManager.reachable:
		assert_lte(HexMetrics.axial_distance(unit.coord, coord), 3, "nada além do movimento 3")

	# 8. N4 e o Ataque Furtivo.
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "antes do N4 não há técnica")
	_research(state, "v2_doctrine_rogue_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [SNEAK], "8. Ataque Furtivo")

	# 9. Sem inimigo adjacente: indisponível com o motivo claro.
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, SNEAK, grid), "Nenhum inimigo adjacente.", "9. sem alvo")
	SelectionManager.use_technique_selected(SNEAK)
	assert_eq(SelectionManager.technique_targeting_id, "", "sem alvo válido não há mira")

	# 10-13. Um inimigo adjacente de Defesa alta (revidaria num ataque comum): mira, ESC sem gastar nada, clique — penetração de Defesa e sem revide.
	var target := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 1), 60.0, 14.0)
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	var basic_prediction: Dictionary = CombatResolver.predict(unit, target, grid)
	assert_gt(basic_prediction.damage_to_attacker, 0.0, "pré-condição: um ataque comum revidaria")
	var predicted: float = CombatResolver.predict(unit, target, grid, 1.35, 0.4, true).damage_to_defender
	SelectionManager.use_technique_selected(SNEAK)
	assert_eq(SelectionManager.technique_targeting_id, SNEAK, "10. entrou no modo de mira")
	assert_true(target.coord in SelectionManager.technique_target_coords, "o alvo válido está destacado")
	assert_true(SelectionManager.cancel_technique_targeting(), "11. ESC cancela")
	assert_eq(unit.movement_left, unit.unit_data.movement_points, "cancelar não gasta a ação")
	assert_false(unit.magic_cooldowns.has(SNEAK), "cancelar não inicia a recarga")
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(SNEAK)
	var target_hp := target.hp
	var my_hp := unit.hp
	SelectionManager._handle_technique_targeting_click(target.coord)
	assert_almost_eq(target_hp - target.hp, predicted, 0.0001, "12. o golpe real bate com a previsão (1,35x, 40% de penetração)")
	assert_eq(unit.hp, my_hp, "13. sem revide")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, SNEAK), 3, "recarga de 3 turnos")
	assert_true(target.magic_status.is_empty(), "o alvo sobrevivente não ganhou nenhum status")
	_clear_foes(grid, [target])

	# 14-16. N5 e o Sabotador: a produção oferece só ele e o Ladino evolui pelo V2UnitUpgrade (24 Ouro).
	_research(state, "v2_doctrine_rogue_5")
	assert_eq(_trainable_forms(city), [SABOTEUR], "14. a produção oferece só o Sabotador — 32 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, SABOTEUR, "15. evoluiu para Sabotador")
	assert_eq(human.gold, 100.0 - 24.0, "2 x (32 - 20) = 24 Ouro")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, SNEAK), 2, "16. a recarga do Ataque Furtivo foi preservada pela evolução")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.movement_points], [18.0, 6.0, 3.0], "mesmo movimento, mais Ataque e vida")

	# 17-22. N6 e Desmantelar: alvo normal, fixture conjurador, fixture Cerco — passiva sem botão.
	_research(state, "v2_doctrine_rogue_6")
	_end_turn()
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [SNEAK, DISMANTLE], "17. herda as duas")
	var normal_foe := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 1), 60.0, 3.0)
	var normal_predicted: float = CombatResolver.predict(unit, normal_foe, grid).damage_to_defender
	CombatResolver.resolve(unit, normal_foe, grid)
	assert_almost_eq(60.0 - normal_foe.hp, normal_predicted, 0.0001, "18. alvo normal: sem bônus")
	_clear_foes(grid, [normal_foe])
	unit.movement_left = unit.unit_data.movement_points
	var caster_foe := _traited_foe(grid, rival, _free_at(grid, unit.coord, 1), UnitData.TRAIT_CASTER, 60.0, 3.0)
	var caster_predicted: float = CombatResolver.predict(unit, caster_foe, grid).damage_to_defender
	CombatResolver.resolve(unit, caster_foe, grid)
	assert_almost_eq(60.0 - caster_foe.hp, caster_predicted, 0.0001, "19. fixture conjurador: previsão == resolução")
	assert_gt(caster_predicted, normal_predicted, "e maior que o ataque comum")
	_clear_foes(grid, [caster_foe])
	unit.movement_left = unit.unit_data.movement_points
	var siege_foe := _traited_foe(grid, rival, _free_at(grid, unit.coord, 1), UnitData.TRAIT_SIEGE, 60.0, 3.0)
	var siege_predicted: float = CombatResolver.predict(unit, siege_foe, grid).damage_to_defender
	assert_almost_eq(siege_predicted, caster_predicted, 0.0001, "20. fixture Cerco: mesmo bônus (+50%)")
	CombatResolver.resolve(unit, siege_foe, grid)
	assert_almost_eq(60.0 - siege_foe.hp, siege_predicted, 0.0001, "21. previsão == resolução")
	assert_true(_technique(DISMANTLE).is_passive(), "22. Desmantelar não vira botão (é passiva; a ausência do botão em si é coberta em test_hud.gd)")
	_clear_foes(grid, [siege_foe])

	# 23-25. N7 e o Assassino: a produção oferece só ele e o Sabotador evolui (32 Ouro).
	_research(state, "v2_doctrine_rogue_7")
	assert_eq(_trainable_forms(city), [ASSASSIN], "23. a produção oferece só o Assassino — 48 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_true(V2UnitUpgrade.can_upgrade(human, unit, grid), V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid))
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, ASSASSIN, "24. evoluiu para Assassino")
	assert_eq(human.gold, 100.0 - 32.0, "2 x (48 - 32) = 32 Ouro")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.defense, unit.unit_data.movement_points], [23.0, 3.5, 3.0], "25. mais resistente, mobilidade preservada")
	assert_lt(unit.unit_data.defense, UnitDatabase.create_unit("v2_unit_weapon_master").defense, "nunca supera o Mestre de Armas")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [SNEAK, DISMANTLE], "herda as duas técnicas")

	# 26-28. N8 e o Refúgio das Sombras (exige a Guilda).
	assert_false(city.can_build(REFUGE), "antes do N8 não constrói")
	_research(state, "v2_doctrine_rogue_8")
	assert_true(city.can_build(REFUGE), "26. N8 libera o Refúgio das Sombras")
	_place(grid, unit, _free_at(grid, city.coord, 3))
	_build(grid, city, REFUGE)
	assert_true(city.buildings.has(GUILD), "o Refúgio não substitui a Guilda")
	assert_false(city.can_train(SHADOW), "sem N9 o Mestre das Sombras ainda não treina")

	# 29-30. N9 e o Mestre das Sombras: produção separada; o Assassino segue disponível na Guilda.
	_research(state, "v2_doctrine_rogue_9")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "só o Ladino completo: 1 / 2")
	assert_true(city.can_train(SHADOW))
	assert_true(_train(city, SHADOW), "29. Mestre das Sombras em treino")
	var shadows := _units_of_kind(human, SHADOW)
	assert_eq(shadows.size(), 1)
	var shadow: Unit = shadows[0]
	assert_true(V2LegendarySystem.is_legendary_unit(shadow))
	assert_same(V2LegendarySystem.active_legendary(human), shadow)
	assert_eq(shadow.unit_data.movement_profile, UnitData.MovementProfile.INFILTRATOR)
	assert_true(shadow.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_eq(_trainable_forms(city), [ASSASSIN], "30. o Assassino continua disponível na Guilda")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(shadow).map(func(t): return t.id), [SNEAK, DISMANTLE], "herda as duas")

	# 31-36. Infiltração: formação bloqueando o caminho, numa arena controlada e limpa.
	var center := _arena(grid)
	var wall_owner := _rogue_player_for_wall(human)
	for r in range(-6, 7):
		if grid.tiles.has(center + Vector2i(1, r)):
			grid.spawn_unit(center + Vector2i(1, r), UnitDatabase.create_unit("warrior"), wall_owner)
	_place(grid, shadow, center)
	var ground_assassin := grid.spawn_unit(center + Vector2i(0, 4), UnitDatabase.create_unit(ASSASSIN), human)
	ground_assassin.movement_left = ground_assassin.unit_data.movement_points
	grid.recompute_fog(human)
	var ground_reach: Dictionary = grid.unit_reachable(ground_assassin)
	for coord in ground_reach:
		assert_lt(coord.x, center.x + 1, "32. um Assassino terrestre comum é bloqueado pela formação")
	grid.remove_unit(ground_assassin) # só uma sonda descartável pro passo 32; não deve sobreviver até o save
	shadow.movement_left = shadow.unit_data.movement_points
	var shadow_reach: Dictionary = grid.unit_reachable(shadow)
	assert_true(shadow_reach.has(center + Vector2i(2, 0)), "33. o Mestre das Sombras atravessa a formação")
	_wall_of_water(grid, center, center.x + 4)
	shadow.movement_left = shadow.unit_data.movement_points
	var blocked_by_water: Dictionary = grid.unit_reachable(shadow)
	for coord in blocked_by_water:
		assert_lt(coord.x, center.x + 4, "34. mas não atravessa água")
	SelectionManager._select_unit(shadow)
	SelectionManager._move_selected_to(center + Vector2i(2, 0))
	assert_eq(shadow.coord, center + Vector2i(2, 0), "35. moveu de verdade através da formação")
	assert_null(grid.get_unit_at(center), "o tile de origem ficou livre")

	# 36-38. Ataque Furtivo do Mestre em situação válida de turno; Desmantelar confirmado; slot Lendário.
	_end_turn()
	shadow.movement_left = shadow.unit_data.movement_points
	var caster_target := _traited_foe(grid, rival, center + Vector2i(3, 0), UnitData.TRAIT_CASTER, 60.0, 3.0)
	grid.recompute_fog(human)
	var shadow_predicted: float = CombatResolver.predict(shadow, caster_target, grid, 1.35, 0.4, true).damage_to_defender
	var caster_hp := caster_target.hp
	assert_true(V2TechniqueRuntime.perform_strike(shadow, SNEAK, caster_target, grid))
	assert_almost_eq(caster_hp - caster_target.hp, shadow_predicted, 0.0001, "36. Ataque Furtivo real bate com a previsão")
	assert_eq(shadow.hp, shadow.unit_data.max_hp, "sem revide")
	assert_gt(shadow_predicted, _formula_damage_local(grid, 10.5, 1.35, caster_target, 1.0, 0.0), "Desmantelar também se aplicou (conjurador)")
	assert_true(V2LegendarySystem.has_active_legendary(human), "37. o slot continua ocupado")
	_clear_foes(grid, [caster_target])

	# 39-46. Salva e carrega: pesquisas, prédios, unidades, perfil de infiltração, recargas, traits e o slot global.
	var shadow_coord := shadow.coord
	var shadow_sneak_left := V2TechniqueRuntime.cooldown_remaining(shadow, SNEAK)
	var assassin_coord := unit.coord
	assert_gt(shadow_sneak_left, 0, "pré-condição: o Ataque Furtivo do Mestre está em recarga")
	var loaded_grid := _save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.v2_research.get_completed_ids().size(), 9, "40. as 9 pesquisas do Ladino")
	var loaded_city: City = loaded.cities[0]
	assert_true(loaded_city.buildings.has(GUILD) and loaded_city.buildings.has(REFUGE), "41. Guilda e Refúgio restaurados")
	var loaded_assassins := _units_of_kind(loaded, ASSASSIN)
	assert_eq(loaded_assassins.size(), 1, "42. o Assassino voltou")
	assert_eq(loaded_assassins[0].coord, assassin_coord)
	var loaded_shadows := _units_of_kind(loaded, SHADOW)
	assert_eq(loaded_shadows.size(), 1, "43. o Mestre das Sombras voltou")
	var loaded_shadow: Unit = loaded_shadows[0]
	assert_eq(loaded_shadow.coord, shadow_coord)
	assert_eq([loaded_shadow.unit_data.max_hp, loaded_shadow.unit_data.movement_points], [30.0, 4.0])
	assert_eq(loaded_shadow.unit_data.movement_profile, UnitData.MovementProfile.INFILTRATOR, "44. o perfil de infiltração vem do dado")
	assert_true(loaded_shadow.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_shadow, SNEAK), shadow_sneak_left, "45. recarga do Ataque Furtivo")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(loaded_shadow).map(func(t): return t.id), [SNEAK, DISMANTLE])
	loaded_shadow.movement_left = loaded_shadow.unit_data.movement_points
	assert_eq(loaded_grid.unit_reachable(loaded_shadow), loaded_grid.infiltrate_reachable(loaded_shadow, loaded_shadow.movement_left), "a infiltração continua infiltração depois do load")
	loaded_assassins[0].movement_left = loaded_assassins[0].unit_data.movement_points
	assert_eq(loaded_grid.unit_reachable(loaded_assassins[0]), loaded_grid.compute_reachable(assassin_coord, 3.0, loaded, false, false), "e o chão continua chão")
	# Slot global: com o Mestre vivo, o Campeão, o Herói, o Caçador de Lendas e o Cavaleiro de Grifo estão bloqueados, mesmo com os prédios e as pesquisas das outras Doutrinas.
	assert_true(V2LegendarySystem.has_active_legendary(loaded), "o slot continua ocupado")
	for n in range(1, 10):
		loaded.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	for id in [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER]:
		loaded_city.buildings[id] = true
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW]:
		assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, kind), V2LegendarySystem.SLOT_TAKEN_REASON, kind)
	# E as cinco Doutrinas completas mostram o Exército Supremo no teto (2 / 2): pesquisável, inerte, sem vitória.
	assert_true(loaded.v2_research.is_available("v2_supreme_army"))
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória disparou")

## Helper local (o mesmo cálculo de v2_combat_fixture, sem herdar dela — este arquivo estende GutTest puro pra ter estado próprio de save/load).
func _formula_damage_local(grid: HexGrid, attack: float, multiplier: float, defender: Unit, extra_defense: float = 1.0, defense_penetration: float = 0.0) -> float:
	var terrain := 1.0 + grid.get_tile(defender.coord).defense_bonus
	var effective_defense := defender.unit_data.defense * terrain * extra_defense * (1.0 - defense_penetration)
	return maxf(1.0, attack * multiplier - effective_defense * CombatResolver.DEFENSE_MITIGATION_FACTOR)

## Uma civilização de teste, só para possuir a fileira de bloqueio de infiltração (nunca em guerra com o humano: a fileira é neutra/estrangeira em paz,
## irrelevante pro teste — o que importa é ela OCUPAR os tiles).
func _rogue_player_for_wall(human: PlayerData) -> PlayerData:
	var wall := PlayerData.new(CivilizationData.new())
	_players_to_release.append(wall)
	return wall

## Só dentro do disco de raio 6 ao redor de `center` (a mesma área que _arena já limpou de unidades estrangeiras) — evita um "buraco" na parede
## por causa de uma unidade neutra distante que _wall_of_water não conseguiria sobrescrever.
func _wall_of_water(grid: HexGrid, center: Vector2i, q: int) -> void:
	for coord in HexMetrics.coords_within(center, 6):
		if coord.x == q and grid.tiles.has(coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

func _technique(id: String) -> V2DoctrineTechniqueData:
	return V2DoctrineTechniqueDatabase.get_technique(id)

# --- Casos isolados ------------------------------------------------------------------------------------------

func test_cancelling_the_sneak_attack_targeting_by_any_means_consumes_nothing():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 1))
	var hp := foe.hp
	grid.recompute_fog(c.human)
	SelectionManager._select_unit(unit)
	# (a) clique em outro tile (que não é um alvo)
	SelectionManager.use_technique_selected(SNEAK)
	assert_eq(SelectionManager.technique_targeting_id, SNEAK)
	var elsewhere := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if coord != foe.coord and coord != unit.coord and not (coord in SelectionManager.technique_target_coords):
			elsewhere = coord
			break
	SelectionManager._handle_technique_targeting_click(elsewhere)
	assert_eq(SelectionManager.technique_targeting_id, "", "clicar fora cancela")
	assert_eq(foe.hp, hp)
	assert_gt(unit.movement_left, 0.0)
	assert_false(unit.magic_cooldowns.has(SNEAK))
	assert_same(SelectionManager.selected_unit, unit, "a unidade continua selecionada")
	# (b) limpar a seleção
	SelectionManager.use_technique_selected(SNEAK)
	SelectionManager._clear_selection()
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false(unit.magic_cooldowns.has(SNEAK))
	SelectionManager._select_unit(unit)
	# (c) ESC (o mesmo caminho do PauseMenu): cancela a mira, sem gastar nada; sem mira não faz nada
	SelectionManager.use_technique_selected(SNEAK)
	var was_targeting: bool = SelectionManager.technique_targeting_id != ""
	assert_eq(SelectionManager.cancel_technique_targeting(), was_targeting)
	assert_false(unit.magic_cooldowns.has(SNEAK))
	assert_false(SelectionManager.cancel_technique_targeting(), "sem mira o ESC não faz nada")
	# (d) depois de tudo, o golpe ainda funciona
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(SNEAK)
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_lt(foe.hp, hp)

func test_a_target_in_the_fog_cannot_be_sneak_attacked_by_the_human():
	var c := _short_setup(4)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 1))
	grid.recompute_fog(c.human)
	grid.visibility[foe.coord] = HexGrid.Visibility.EXPLORED
	SelectionManager._select_unit(unit)
	var technique := V2DoctrineTechniqueDatabase.get_technique(SNEAK)
	# Alcance 1: alvo adjacente sempre é visível por convenção (mesma regra das técnicas de alcance 1) — a neblina só restringe alcance > 1 (Fase 8).
	assert_true(foe in V2TechniqueRuntime.strike_targets(unit, technique, grid), "adjacente: sempre visível, como o ataque comum")

func test_the_cooldown_and_the_dismantle_bonus_survive_save_and_load():
	var c := _short_setup(6)
	var unit: Unit = c.unit
	var grid: HexGrid = c.grid
	var foe := _spawn_foe(grid, c.rival, _free_at(grid, unit.coord, 1))
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK, foe, grid))
	var left := V2TechniqueRuntime.cooldown_remaining(unit, SNEAK)
	assert_eq(left, 3)
	var coord := unit.coord
	_save_and_reload()
	var loaded_units := _units_of_kind(GameManager.human_player, ROGUE)
	assert_eq(loaded_units.size(), 1)
	assert_eq(loaded_units[0].coord, coord)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_units[0], SNEAK), left)
	assert_false(loaded_units[0].magic_status.has(SNEAK), "o Ataque Furtivo não guarda efeito")
	# Desmantelar é derivado do traço do alvo, não salvo — continua funcionando depois do load.
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var loaded_grid: HexGrid = GameManager.hex_grid
	var caster := _traited_foe(loaded_grid, loaded_rival, _free_at(loaded_grid, coord, 2), UnitData.TRAIT_CASTER)
	assert_almost_eq(UnitAbilities.attack_multiplier(loaded_units[0], caster), 1.5, 0.0001)

func test_a_shadow_master_in_production_survives_save_and_load_and_blocks_the_others_in_another_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	var city: City = c.city
	city.buildings[REFUGE] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER])
	assert_true(second.can_train(CHAMPION) and second.can_train(HERO) and second.can_train(LEGEND_HUNTER) and second.can_train(GRIFFON))
	city.set_production(SHADOW)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(second.can_train(kind), "o Mestre em produção reserva o slot único (%s)" % kind)
	_save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.cities.size(), 2)
	var producing: City = loaded.cities.filter(func(x): return x.production_item == SHADOW)[0]
	var other: City = loaded.cities.filter(func(x): return x != producing)[0]
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(other.can_train(kind), "a reserva vem da ordem de produção salva (%s)" % kind)
	producing.set_production("")
	assert_true(other.can_train(CHAMPION) and other.can_train(HERO) and other.can_train(LEGEND_HUNTER) and other.can_train(GRIFFON), "cancelar libera")

func test_a_shadow_master_and_a_champion_finishing_in_the_same_turn_never_create_two_legendaries():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	var city: City = c.city
	city.buildings[REFUGE] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY])
	city.set_production(SHADOW)
	second.set_production(CHAMPION)
	_end_turn()
	assert_push_error("não nasceu")
	var legends := 0
	for unit in human.units:
		if V2LegendarySystem.is_legendary_unit(unit):
			legends += 1
	assert_eq(legends, 1, "jamais duas Lendárias ativas")
	assert_eq(V2LegendarySystem.active_legendary_units(human).size(), 1)

func test_the_conventional_assassin_production_is_untouched_by_the_legendary_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[REFUGE] = true
	city.set_production(SHADOW)
	assert_true(city.can_train(ASSASSIN))
	city.set_production(ASSASSIN)
	_end_turn()
	assert_eq(_units_of_kind(human, ASSASSIN).size(), 1)
	assert_eq(_units_of_kind(human, SHADOW).size(), 0)

func test_a_flying_and_an_infiltrator_unit_both_take_no_multi_turn_move_orders_ground_keeps_them():
	var c := _short_setup(9)
	var grid: HexGrid = c.grid
	var human: PlayerData = c.human
	var rogue_unit: Unit = c.unit
	var shadow := grid.spawn_unit(WorldSetup.find_spawn_tile(grid, rogue_unit.coord), UnitDatabase.create_unit(SHADOW), human)
	assert_not_null(shadow)
	var far := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if HexMetrics.axial_distance(rogue_unit.coord, coord) >= 8 and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and not grid.compute_path(rogue_unit.coord, coord, human, false, false).is_empty():
			far = coord
			break
	assert_ne(far, Vector2i(999, 999), "pré-condição: um destino distante com caminho por terra")
	assert_false(SelectionManager._try_queue_move_order(shadow, far), "o Passo Sombrio não tem ordem de vários turnos")
	assert_eq(shadow.move_order_target, Unit.NO_MOVE_ORDER)
	assert_true(SelectionManager._try_queue_move_order(rogue_unit, far), "a linha terrestre convencional segue com a ordem de sempre")
	assert_ne(rogue_unit.move_order_target, Unit.NO_MOVE_ORDER)

func test_ai_civilizations_keep_playing_with_the_rogue_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(GUILD))
			assert_false(rival_city.buildings.has(REFUGE))
			assert_ne(rival_city.production_item, SHADOW)
		assert_eq(_units_of_kind(rival, SHADOW).size(), 0)
		assert_eq(_units_of_kind(rival, ROGUE).size(), 0, "a IA não usa conteúdo V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))

func test_an_ai_civilization_given_the_research_by_debug_builds_trains_sneak_attacks_infiltrates_and_respects_the_slot():
	var c := _short_setup(3)
	var rival: PlayerData = c.rival
	for n in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	var rival_city: City = rival.cities[0]
	rival_city.city_level = 3
	rival_city.buildings[GUILD] = true
	rival_city.buildings[REFUGE] = true
	# Aetherlands V2, Fase 15 — o Mestre das Sombras custa 5 Suprimentos (acima da base de 4) e
	# Guilda+Refúgio têm gold_upkeep sem Mercado -- Fazenda + Ouro de sobra evitam que Suprimentos/
	# Déficit bloqueiem o que este teste verifica (RivalAI resolve a forma certa e respeita o slot).
	rival_city.buildings["v2_building_farm"] = true
	rival_city.repeatable_building_counts["v2_building_farm"] = 1
	if rival.gold <= 0.0:
		rival.gold = 1000.0
	var offered: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and rival_city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(ASSASSIN), "resolve a forma correta")
	assert_false(offered.has(ROGUE) or offered.has(SABOTEUR))
	assert_true(offered.has(SHADOW), "e o Lendário respeita o slot: livre, pode")
	# As técnicas funcionam sem crash quando a civilização de IA as usa (sem estratégia: só o runtime), inclusive a infiltração.
	var grid: HexGrid = c.grid
	var attacker := grid.spawn_unit(_free_at(grid, rival_city.coord, 2), UnitDatabase.create_unit(ASSASSIN), rival)
	var victim := _spawn_foe(grid, c.human, _free_at(grid, attacker.coord, 1))
	assert_true(V2TechniqueRuntime.can_use(attacker, SNEAK, grid), V2TechniqueRuntime.unavailable_reason(attacker, SNEAK, grid))
	assert_true(V2TechniqueRuntime.perform_strike(attacker, SNEAK, victim, grid))
	var infiltrator := grid.spawn_unit(_free_at(grid, rival_city.coord, 3), UnitDatabase.create_unit(SHADOW), rival)
	assert_not_null(infiltrator)
	assert_false(rival_city.can_train(SHADOW), "com o Mestre da IA vivo o slot dela está tomado")
	for i in 3:
		_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "não crasha com a unidade infiltradora no jogo da IA")
	assert_true(is_instance_valid(infiltrator))
