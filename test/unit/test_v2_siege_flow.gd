extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina de Cerco N1-N9 (Aetherlands V2, Fase 11), pelos mesmos caminhos do jogo (HUD/SelectionManager/produção/save/neblina):
## jogo novo -> N1 -> N2 -> Arsenal de Cerco -> N3 -> Catapulta (ataque a distância) -> N4 -> Munição Demolidora (passiva, bônus contra cidade) ->
## N5 -> Trebuchet (upgrade, alcance 3) -> N6 -> Bombardeio Preparado (mira de CIDADE, exige não ter se movido, ESC, ×1.5 + Munição) -> mover e
## confirmar que fica indisponível -> N7 -> Bombarda -> N8 -> Grande Arsenal -> N9 -> Colosso de Cerco (Artilharia Andante: move e ainda bombardeia) ->
## Desmantelar do Ladino e Caçada Lendária do Caçador de Lendas contra o Colosso -> salvar -> carregar -> slot Lendário compartilhado com as
## outras CINCO Doutrinas. O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_siege_flow_savegame.json"
const ARSENAL := "v2_building_siege_arsenal"
const CATAPULT := "v2_unit_catapult"
const TREBUCHET := "v2_unit_trebuchet"
const BOMBARD := "v2_unit_bombard"
const GRAND_ARSENAL := "v2_building_grand_arsenal"
const COLOSSUS := "v2_legendary_siege_colossus"
const DEMOLITION := "v2_technique_demolition_ammo"
const BOMBARDMENT := "v2_technique_prepared_bombardment"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const W_HALL := "v2_building_warrior_hall"
const ARENA := "v2_building_warrior_mastery"
const R_CAMP := "v2_building_ranger_camp"
const R_TOWER := "v2_building_ranger_mastery"
const C_STABLE := "v2_building_war_stable"
const C_ORDER := "v2_building_cavalry_mastery"
const ROGUE_GUILD := "v2_building_rogue_guild"
const ROGUE_MASTERY := "v2_building_rogue_mastery"
const ROGUE := "v2_unit_rogue"
const LEGEND_HUNTER := "v2_legendary_legend_hunter"
const CHAMPION := "v2_legendary_guardian_champion"
const HERO := "v2_legendary_blade_hero"
const GRIFFON := "v2_legendary_griffon_rider"
const SHADOW := "v2_legendary_shadow_master"
## Mapa grande o bastante pra o Colonizador inicial não nascer perto demais de uma capital rival.
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []
var _standalone_cities: Array[City] = []

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
	for city in _standalone_cities:
		if is_instance_valid(city):
			city.free()
	_standalone_cities.clear()

# --- Helpers ----------------------------------------------------------------------------------------------

func _new_game() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_WIDTH, MAP_HEIGHT, 777)
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

func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

func _free_at(grid: HexGrid, center: Vector2i, distance: int, avoid: Array = []) -> Vector2i:
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and grid.tiles.has(coord) and not (coord in avoid) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile livre a distância %d de %s" % [distance, str(center)])
	return Vector2i(999, 999)

func _place(grid: HexGrid, unit: Unit, coord: Vector2i) -> void:
	grid.teleport_unit(unit, coord)
	unit.movement_left = unit.unit_data.movement_points

func _trainable_forms(city: City) -> Array:
	return [CATAPULT, TREBUCHET, BOMBARD].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

## Uma cidade INIMIGA real (registrada no grid, hp/shield cheios) exatamente em `coord`.
func _enemy_city_here(grid: HexGrid, owner: PlayerData, coord: Vector2i) -> City:
	var city := City.new()
	city.owner_player = owner
	city.coord = coord
	city.city_name = "Cidade Inimiga"
	city.city_level = 4 # Fase 16: a vida vem do City Level (Cidade IV = 44), não mais da população
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	grid.cities_by_coord[coord] = city
	_standalone_cities.append(city)
	return city

## Uma cidade INIMIGA real a EXATAMENTE `distance` de `center`, num pedaço do mapa sem outra cidade/covil.
func _enemy_city_at(grid: HexGrid, owner: PlayerData, center: Vector2i, distance: int) -> City:
	return _enemy_city_here(grid, owner, _free_at(grid, center, distance))

## Limpa um disco de `radius` ao redor de `center` pra grama plana, sem unidade nenhuma — evita que o mapa GERADO (água/montanha/monstro/rival)
## atrapalhe um cenário que precisa de conectividade e distâncias garantidas (Artilharia Andante).
func _clear_disc(grid: HexGrid, center: Vector2i, radius: int) -> void:
	for coord in HexMetrics.coords_within(center, radius):
		if grid.tiles.has(coord):
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			var occupant := grid.get_unit_at(coord)
			if occupant != null:
				grid.remove_unit(occupant)

func _traited_foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, trait_id: String, hp: float = 40.0, defense: float = 3.0) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.max_hp = hp
	data.defense = defense
	data.traits.append(trait_id)
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit)
	return unit

## Cenário curto: jogo novo, cidade com Arsenal, Cerco pesquisado até `through` e uma unidade `kind` viva, em guerra com o rival.
func _short_setup(through: int = 4, kind: String = CATAPULT) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	city.buildings[ARSENAL] = true
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Arsenal/Grande Arsenal
	# (upkeep de Ouro) e chegam a treinar o Colosso de Cerco (5 Suprimentos, acima da capacidade
	# base de uma cidade sozinha). Ouro de sobra + uma Fazenda evitam bloqueio alheio ao teste.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(kind), human)
	assert_not_null(unit)
	grid.recompute_fog(human)
	return {"grid": grid, "human": human, "rival": rival, "city": city, "unit": unit}

func _technique(id: String) -> V2DoctrineTechniqueData:
	return V2DoctrineTechniqueDatabase.get_technique(id)

func _city_formula_damage(attacker: Unit, city: City, strike_multiplier: float = 1.0, demolition: float = 1.0) -> float:
	var defense_bonus := city.defense_bonus() # Fase 16: prédios não-muralha + Fortificação V2
	return max(1.0, (attacker.unit_data.attack * attacker.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(attacker) * strike_multiplier * demolition) / (1.0 + defense_bonus))

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_siege_n1_to_n9_flow_from_the_arsenal_to_the_colossus_across_save_and_load():
	# 1-2. Nova partida (em guerra com o rival), cidade com população suficiente pro Arsenal e o Grande Arsenal.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — a forma viva (N5, 2) mais a Bombarda (N7, 3) já somam 5, acima da
	# base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo pré-existente
	# tropece num gate que não é o assunto dele.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o upkeep) -- Ouro
	# de sobra evita que isso sozinho derrube a cidade em Déficit assim que o Arsenal é construído.
	human.gold = 1000.0
	assert_false(V2UnlockSystem.is_unlocked(human, "v2_doctrine_siege"))

	# N1: estabelece a linha, sem bônus; só o N2 fica disponível.
	_research(state, "v2_doctrine_siege_1")
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_siege"], "o N1 não libera nada além da Doutrina")
	assert_false(city.can_build(ARSENAL))
	assert_true(state.is_available("v2_doctrine_siege_2"))

	# N2 e o Arsenal de Cerco (construção normal, sem depender de outra Doutrina nem do arsenal V1).
	_research(state, "v2_doctrine_siege_2")
	assert_true(city.can_build(ARSENAL), "N2 libera o Arsenal de Cerco")
	_build(grid, city, ARSENAL)

	# N3 e a Catapulta: ataque à distância normal.
	assert_false(city.can_train(CATAPULT), "sem N3 não treina")
	_research(state, "v2_doctrine_siege_3")
	assert_true(_train(city, CATAPULT), "Catapulta em treino")
	var catapults := _units_of_kind(human, CATAPULT)
	assert_eq(catapults.size(), 1)
	var unit: Unit = catapults[0]
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.defense, unit.unit_data.movement_points, unit.unit_data.attack_range], [16.0, 3.5, 2.5, 2.0, 2])
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)

	# 3. Um alvo real a distância 2: dano normal, sem revide.
	var foe := UnitDatabase.create_unit("warrior")
	foe.max_hp = 40.0
	foe.defense = 3.0
	var target_unit := grid.spawn_unit(_free_at(grid, unit.coord, 2), foe, rival)
	grid.recompute_fog(human)
	var unit_predicted: float = CombatResolver.predict(unit, target_unit, grid).damage_to_defender
	var unit_hp_before := target_unit.hp
	CombatResolver.resolve(unit, target_unit, grid)
	assert_almost_eq(unit_hp_before - target_unit.hp, unit_predicted, 0.0001, "ataque básico ranged normal: previsão == resolução")
	assert_eq(CombatResolver.predict(unit, target_unit, grid).damage_to_attacker, 0.0, "sem revide a distância 2")
	if target_unit.hp > 0.0:
		grid.remove_unit(target_unit)
	unit.movement_left = unit.unit_data.movement_points

	# 4-6. Uma cidade inimiga real: ataque básico de Cerco (bônus INATO, sem N4 ainda).
	var enemy_city := _enemy_city_at(grid, rival, unit.coord, 2)
	var pre_n4_expected := _city_formula_damage(unit, enemy_city)
	var pre_n4_hp := enemy_city.hp
	CombatResolver.resolve_city_attack(unit, enemy_city, grid)
	assert_almost_eq(pre_n4_hp - enemy_city.hp, pre_n4_expected, 0.0001, "bônus inato de Cerco (1,5x) já vale antes do N4")
	unit.movement_left = unit.unit_data.movement_points

	# N4: Munição Demolidora — o MESMO ataque básico contra cidade agora sai 40% mais forte.
	_research(state, "v2_doctrine_siege_4")
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(unit), 1.4, 0.0001)
	var post_n4_expected := _city_formula_damage(unit, enemy_city, 1.0, 1.4)
	var post_n4_hp := enemy_city.hp
	CombatResolver.resolve_city_attack(unit, enemy_city, grid)
	assert_almost_eq(post_n4_hp - enemy_city.hp, post_n4_expected, 0.0001, "Munição Demolidora: +40% no ataque de Cerco contra cidade")
	unit.movement_left = unit.unit_data.movement_points

	# N5 e o Trebuchet: a produção oferece só ele e a Catapulta evolui pelo V2UnitUpgrade (32 Ouro), alcance 3.
	_research(state, "v2_doctrine_siege_5")
	assert_eq(_trainable_forms(city), [TREBUCHET], "a produção oferece só o Trebuchet — 44 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, TREBUCHET, "evoluiu para Trebuchet")
	assert_eq(human.gold, 100.0 - 32.0, "2 x (44 - 28) = 32 Ouro")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.attack_range], [20.0, 5.0, 3], "mais alcance (o ganho principal) e poder")

	# N6: Bombardeio Preparado — mira de CIDADE, ESC sem gastar nada, exige não ter se movido, ×1.5 + Munição.
	_research(state, "v2_doctrine_siege_6")
	_end_turn()
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [DEMOLITION, BOMBARDMENT], "herda as duas")
	var original_hex_grid_for_selection := GameManager.hex_grid
	GameManager.hex_grid = grid
	assert_true(V2TechniqueRuntime.city_strike_targets(unit, _technique(BOMBARDMENT), grid).has(enemy_city), "cidade ao alcance (2+1=3)")
	var bombardment_predicted := _city_formula_damage(unit, enemy_city, 1.5, 1.4)
	SelectionManager.use_technique_selected(BOMBARDMENT)
	assert_eq(SelectionManager.technique_targeting_id, BOMBARDMENT, "entrou no modo de mira")
	assert_true(enemy_city.coord in SelectionManager.technique_target_coords, "a cidade hostil está destacada")
	assert_true(SelectionManager.cancel_technique_targeting(), "ESC cancela")
	assert_eq(unit.movement_left, unit.unit_data.movement_points, "cancelar não gasta a ação")
	assert_false(unit.magic_cooldowns.has(BOMBARDMENT), "cancelar não inicia a recarga")
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(BOMBARDMENT)
	var city_hp_before := enemy_city.hp
	SelectionManager._handle_technique_targeting_click(enemy_city.coord)
	assert_almost_eq(city_hp_before - enemy_city.hp, bombardment_predicted, 0.0001, "o golpe real bate com a previsão (1,5x, com Munição)")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, BOMBARDMENT), 4, "recarga de 4 turnos")

	# Limpa a recarga direto (sem rodar turnos reais de IA, que arriscam ocupar tiles do mapa gerado) e move o Trebuchet: confirma que o
	# Bombardeio fica indisponível especificamente por causa do movimento (não mais por recarga) — e que o ataque básico contra a
	# cidade segue funcionando mesmo assim.
	unit.magic_cooldowns.erase(BOMBARDMENT)
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2TechniqueRuntime.can_use(unit, BOMBARDMENT, grid), "pré-condição: fora de recarga, parado")
	SelectionManager._select_unit(unit)
	var destination := _free_at(grid, unit.coord, 1)
	SelectionManager._move_selected_to(destination)
	assert_lt(unit.movement_left, unit.unit_data.movement_points, "pré-condição: moveu uma parte")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, BOMBARDMENT, grid), "Bombardeio Preparado exige que a unidade não tenha se movido neste turno.")
	if HexMetrics.axial_distance(unit.coord, enemy_city.coord) <= unit.unit_data.attack_range and CombatResolver.can_attack_city(unit, enemy_city):
		var basic_hp_before := enemy_city.hp
		CombatResolver.resolve_city_attack(unit, enemy_city, grid)
		assert_lt(enemy_city.hp, basic_hp_before, "o ataque básico normal continua disponível mesmo com o Bombardeio indisponível")
	GameManager.hex_grid = original_hex_grid_for_selection

	# N7 e a Bombarda: a produção oferece só ela e o Trebuchet evolui (40 Ouro).
	_research(state, "v2_doctrine_siege_7")
	assert_eq(_trainable_forms(city), [BOMBARD], "a produção oferece só a Bombarda — 64 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_true(V2UnitUpgrade.can_upgrade(human, unit, grid), V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid))
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, BOMBARD, "evoluiu para Bombarda")
	assert_eq(human.gold, 100.0 - 40.0, "2 x (64 - 44) = 40 Ouro")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.defense], [26.0, 4.0])
	assert_lt(unit.unit_data.attack, UnitDatabase.create_unit("v2_unit_elite_marksman").attack, "continua inferior ao Patrulheiro equivalente em anti-unidade")

	# N8 e o Grande Arsenal (exige o Arsenal de Cerco).
	assert_false(city.can_build(GRAND_ARSENAL), "antes do N8 não constrói")
	_research(state, "v2_doctrine_siege_8")
	assert_true(city.can_build(GRAND_ARSENAL), "N8 libera o Grande Arsenal")
	_clear_disc(grid, city.coord, 2) # o mapa GERADO pode ter posto um monstro/batedor rival adjacente nos turnos que já se passaram
	_place(grid, unit, _free_at(grid, city.coord, 3))
	_build(grid, city, GRAND_ARSENAL)
	assert_true(city.buildings.has(ARSENAL), "o Grande Arsenal não substitui o Arsenal")
	assert_false(city.can_train(COLOSSUS), "sem N9 o Colosso ainda não treina")

	# N9 e o Colosso de Cerco: produção separada; a Bombarda segue disponível no Arsenal.
	_research(state, "v2_doctrine_siege_9")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "só o Cerco completo: 1 / 2")
	assert_true(city.can_train(COLOSSUS))
	assert_true(_train(city, COLOSSUS), "Colosso de Cerco em treino")
	var colossi := _units_of_kind(human, COLOSSUS)
	assert_eq(colossi.size(), 1)
	var colossus: Unit = colossi[0]
	assert_true(V2LegendarySystem.is_legendary_unit(colossus))
	assert_same(V2LegendarySystem.active_legendary(human), colossus)
	assert_true(colossus.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(colossus.unit_data.has_trait(UnitData.TRAIT_SIEGE))
	assert_true(colossus.unit_data.ignores_technique_stationary_requirement)
	assert_eq(_trainable_forms(city), [BOMBARD], "a Bombarda continua disponível no Arsenal")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(colossus).map(func(t): return t.id), [DEMOLITION, BOMBARDMENT], "herda as duas")

	# Artilharia Andante: move de verdade e AINDA assim bombardeia (as formas convencionais não conseguiriam) — cenário controlado
	# (disco de grama limpo) pra garantir a conectividade e as distâncias exatas, longe do que o mapa gerado colocou ao redor.
	var siege_center := _free_at(grid, city.coord, 15)
	_clear_disc(grid, siege_center, 6)
	var colossus_city := _enemy_city_here(grid, rival, siege_center)
	_place(grid, colossus, siege_center + Vector2i(5, 0)) # distância 5: fora do alcance do Bombardeio (3+1=4) antes de mover
	grid.recompute_fog(human)
	assert_false(V2TechniqueRuntime.city_strike_targets(colossus, _technique(BOMBARDMENT), grid).has(colossus_city), "pré-condição: fora de alcance parado")
	SelectionManager._select_unit(colossus)
	var reachable_step: Vector2i = Vector2i(999, 999)
	for coord in SelectionManager.reachable:
		if HexMetrics.axial_distance(coord, colossus_city.coord) <= colossus.unit_data.attack_range + 1 and coord != colossus.coord:
			reachable_step = coord
			break
	assert_ne(reachable_step, Vector2i(999, 999), "pré-condição: existe um passo que deixa a cidade ao alcance do Bombardeio")
	SelectionManager._move_selected_to(reachable_step)
	assert_eq(colossus.coord, reachable_step, "moveu de verdade")
	assert_lt(colossus.movement_left, colossus.unit_data.movement_points, "pré-condição: gastou parte do movimento")
	assert_true(V2TechniqueRuntime.can_use(colossus, BOMBARDMENT, grid), "Artilharia Andante: ainda pode bombardear mesmo tendo se movido")
	var colossus_predicted := _city_formula_damage(colossus, colossus_city, 1.5, 1.4)
	var colossus_city_hp_before := colossus_city.hp
	assert_true(V2TechniqueRuntime.perform_city_strike(colossus, BOMBARDMENT, colossus_city, grid))
	assert_almost_eq(colossus_city_hp_before - colossus_city.hp, colossus_predicted, 0.0001, "o golpe real bate com a previsão mesmo pós-movimento")
	assert_eq(colossus.movement_left, 0.0, "a Técnica ainda zera o movimento — sem ação extra")

	# Desmantelar (Ladino, N6) e Caçada Lendária (Caçador de Lendas, N9) contra o Colosso: origens DIFERENTES (siege x legendary).
	var ladino := UnitDatabase.create_unit(ROGUE)
	human.v2_research.complete_research("v2_doctrine_rogue_1")
	for n in range(2, 7):
		human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	var ladino_unit := grid.spawn_unit(_free_at(grid, colossus.coord, 1), ladino, human)
	assert_almost_eq(UnitAbilities.attack_multiplier(ladino_unit, colossus), 1.5, 0.0001, "Desmantelar reconhece o traço siege")
	human.v2_research.complete_research("v2_doctrine_ranger_1")
	for n in range(2, 10):
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	var hunter_unit := grid.spawn_unit(_free_at(grid, colossus.coord, 2), UnitDatabase.create_unit(LEGEND_HUNTER), human)
	assert_almost_eq(UnitAbilities.attack_multiplier(hunter_unit, colossus), 1.4, 0.0001, "Caçada Lendária reconhece o traço legendary")

	# Slot Lendário: com o Colosso vivo, nenhuma outra Lendária nasce nesta civilização.
	assert_true(V2LegendarySystem.has_active_legendary(human))
	assert_false(city.can_train(CHAMPION))

	# Salva e carrega: pesquisas, prédios, formas, recarga, traits, Artilharia Andante e o slot global.
	var colossus_coord := colossus.coord
	var colossus_bombardment_left := V2TechniqueRuntime.cooldown_remaining(colossus, BOMBARDMENT)
	var bombard_coord := unit.coord
	assert_gt(colossus_bombardment_left, 0, "pré-condição: o Bombardeio do Colosso está em recarga")
	var loaded_grid := _save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.v2_research.get_completed_ids().size(), 9 + 6 + 9, "as 9 pesquisas do Cerco + 6 do Ladino + 9 do Patrulheiro")
	var loaded_city: City = loaded.cities[0]
	assert_true(loaded_city.buildings.has(ARSENAL) and loaded_city.buildings.has(GRAND_ARSENAL), "Arsenal e Grande Arsenal restaurados")
	var loaded_bombards := _units_of_kind(loaded, BOMBARD)
	assert_eq(loaded_bombards.size(), 1, "a Bombarda voltou")
	assert_eq(loaded_bombards[0].coord, bombard_coord)
	var loaded_colossi := _units_of_kind(loaded, COLOSSUS)
	assert_eq(loaded_colossi.size(), 1, "o Colosso de Cerco voltou")
	var loaded_colossus: Unit = loaded_colossi[0]
	assert_eq(loaded_colossus.coord, colossus_coord)
	assert_eq([loaded_colossus.unit_data.max_hp, loaded_colossus.unit_data.attack_range], [44.0, 3])
	assert_true(loaded_colossus.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(loaded_colossus.unit_data.has_trait(UnitData.TRAIT_SIEGE))
	assert_true(loaded_colossus.unit_data.ignores_technique_stationary_requirement, "Artilharia Andante vem do dado")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_colossus, BOMBARDMENT), colossus_bombardment_left, "recarga do Bombardeio")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(loaded_colossus).map(func(t): return t.id), [DEMOLITION, BOMBARDMENT])
	# Slot global: com o Colosso vivo, as outras cinco Lendárias estão bloqueadas, mesmo com os prédios e as pesquisas das outras Doutrinas.
	assert_true(V2LegendarySystem.has_active_legendary(loaded), "o slot continua ocupado")
	for n in range(1, 10):
		loaded.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	for n in range(7, 10):
		loaded.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	for id in [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER, ROGUE_GUILD, ROGUE_MASTERY]:
		loaded_city.buildings[id] = true
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON, SHADOW, COLOSSUS]:
		assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, kind), V2LegendarySystem.SLOT_TAKEN_REASON, kind)
	# E as SEIS Doutrinas completas mostram o Exército Supremo no teto (2 / 2): pesquisável, inerte, sem vitória.
	assert_true(loaded.v2_research.is_available("v2_supreme_army"))
	assert_true(V2ResearchDatabase.get_node("v2_supreme_army").gameplay_connected, "Fase 12: conectado (acesso a Supremacia Militar), mas ainda não pesquisado por esta civilização")
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória disparou")

# --- Casos isolados ------------------------------------------------------------------------------------------

func test_cancelling_the_prepared_bombardment_targeting_by_any_means_consumes_nothing():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var city := _enemy_city_at(grid, c.rival, unit.coord, 3)
	var hp := city.hp
	grid.recompute_fog(c.human)
	var original_hex_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = grid
	GameManager.human_player = c.human
	SelectionManager._select_unit(unit)
	# (a) clique em outro tile (que não é um alvo)
	SelectionManager.use_technique_selected(BOMBARDMENT)
	assert_eq(SelectionManager.technique_targeting_id, BOMBARDMENT)
	var elsewhere := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if coord != city.coord and coord != unit.coord and not (coord in SelectionManager.technique_target_coords):
			elsewhere = coord
			break
	SelectionManager._handle_technique_targeting_click(elsewhere)
	assert_eq(SelectionManager.technique_targeting_id, "", "clicar fora cancela")
	assert_eq(city.hp, hp)
	assert_gt(unit.movement_left, 0.0)
	assert_false(unit.magic_cooldowns.has(BOMBARDMENT))
	assert_same(SelectionManager.selected_unit, unit, "a unidade continua selecionada")
	# (b) limpar a seleção
	SelectionManager.use_technique_selected(BOMBARDMENT)
	SelectionManager._clear_selection()
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false(unit.magic_cooldowns.has(BOMBARDMENT))
	SelectionManager._select_unit(unit)
	# (c) ESC (o mesmo caminho do PauseMenu)
	SelectionManager.use_technique_selected(BOMBARDMENT)
	var was_targeting: bool = SelectionManager.technique_targeting_id != ""
	assert_eq(SelectionManager.cancel_technique_targeting(), was_targeting)
	assert_false(unit.magic_cooldowns.has(BOMBARDMENT))
	assert_false(SelectionManager.cancel_technique_targeting(), "sem mira o ESC não faz nada")
	# (d) depois de tudo, o golpe ainda funciona
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(BOMBARDMENT)
	SelectionManager._handle_technique_targeting_click(city.coord)
	assert_lt(city.hp, hp)
	SelectionManager.reset()
	GameManager.hex_grid = original_hex_grid
	GameManager.human_player = original_human

func test_a_city_hidden_by_fog_cannot_be_bombarded_by_the_human():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var city := _enemy_city_at(grid, c.rival, unit.coord, 3)
	grid.recompute_fog(c.human)
	grid.visibility[city.coord] = HexGrid.Visibility.UNSEEN
	var original_human := GameManager.human_player
	GameManager.human_player = c.human
	assert_false(city in V2TechniqueRuntime.city_strike_targets(unit, _technique(BOMBARDMENT), grid), "cidade não vista: fora de alcance pro humano")
	GameManager.human_player = original_human

func test_the_cooldown_and_the_demolition_bonus_survive_save_and_load():
	var c := _short_setup(6)
	var unit: Unit = c.unit
	var grid: HexGrid = c.grid
	var city := _enemy_city_at(grid, c.rival, unit.coord, 3)
	assert_true(V2TechniqueRuntime.perform_city_strike(unit, BOMBARDMENT, city, grid))
	var left := V2TechniqueRuntime.cooldown_remaining(unit, BOMBARDMENT)
	assert_eq(left, 4)
	var coord := unit.coord
	_save_and_reload()
	var loaded_units := _units_of_kind(GameManager.human_player, CATAPULT)
	assert_eq(loaded_units.size(), 1)
	assert_eq(loaded_units[0].coord, coord)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_units[0], BOMBARDMENT), left)
	assert_false(loaded_units[0].magic_status.has(BOMBARDMENT), "o Bombardeio não guarda efeito")
	# Munição Demolidora é derivada da pesquisa, não salva — continua funcionando depois do load.
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(loaded_units[0]), 1.4, 0.0001)

func test_a_colossus_in_production_survives_save_and_load_and_blocks_the_others_in_another_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	var city: City = c.city
	city.buildings[GRAND_ARSENAL] = true
	var second: City = null
	for coord in c.grid.tiles.keys():
		if CitySite.rejection_reason(c.grid, coord, human) == "" and c.grid.get_unit_at(coord) == null:
			second = c.grid.found_city(coord, human, "Segunda Cidade", true)
			break
	assert_not_null(second, "pré-condição: tile válido pra segunda cidade")
	for id in [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER, C_STABLE, C_ORDER]:
		second.buildings[id] = true
	assert_true(second.can_train(CHAMPION) and second.can_train(HERO) and second.can_train(LEGEND_HUNTER) and second.can_train(GRIFFON))
	city.set_production(COLOSSUS)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(second.can_train(kind), "o Colosso em produção reserva o slot único (%s)" % kind)
	_save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.cities.size(), 2)
	var producing: City = loaded.cities.filter(func(x): return x.production_item == COLOSSUS)[0]
	var other: City = loaded.cities.filter(func(x): return x != producing)[0]
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_false(other.can_train(kind), "a reserva vem da ordem de produção salva (%s)" % kind)
	producing.set_production("")
	assert_true(other.can_train(CHAMPION) and other.can_train(HERO) and other.can_train(LEGEND_HUNTER) and other.can_train(GRIFFON), "cancelar libera")

func test_the_conventional_bombard_production_is_untouched_by_the_legendary_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[GRAND_ARSENAL] = true
	city.set_production(COLOSSUS)
	assert_true(city.can_train(BOMBARD))
	city.set_production(BOMBARD)
	_end_turn()
	assert_eq(_units_of_kind(human, BOMBARD).size(), 1)
	assert_eq(_units_of_kind(human, COLOSSUS).size(), 0)

func test_ai_civilizations_keep_playing_with_the_siege_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(ARSENAL))
			assert_false(rival_city.buildings.has(GRAND_ARSENAL))
			assert_ne(rival_city.production_item, COLOSSUS)
		assert_eq(_units_of_kind(rival, COLOSSUS).size(), 0)
		assert_eq(_units_of_kind(rival, CATAPULT).size(), 0, "a IA não usa conteúdo V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))

func test_an_ai_civilization_given_the_research_by_debug_builds_bombards_and_respects_the_slot():
	var c := _short_setup(3)
	var rival: PlayerData = c.rival
	for n in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	var rival_city: City = rival.cities[0]
	rival_city.city_level = 3
	rival_city.buildings[ARSENAL] = true
	rival_city.buildings[GRAND_ARSENAL] = true
	# Aetherlands V2, Fase 15 — o Colosso de Cerco custa 5 Suprimentos (acima da base de 4) e
	# Arsenal+Grande Arsenal têm gold_upkeep sem Mercado -- Fazenda + Ouro de sobra evitam que
	# Suprimentos/Déficit bloqueiem o que este teste verifica (RivalAI resolve a forma certa e
	# respeita o slot).
	rival_city.buildings["v2_building_farm"] = true
	rival_city.repeatable_building_counts["v2_building_farm"] = 1
	if rival.gold <= 0.0:
		rival.gold = 1000.0
	var offered: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and rival_city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(BOMBARD), "resolve a forma correta")
	assert_false(offered.has(CATAPULT) or offered.has(TREBUCHET))
	assert_true(offered.has(COLOSSUS), "e o Lendário respeita o slot: livre, pode")
	# A técnica funciona sem crash quando a civilização de IA a usa (sem estratégia: só o runtime), inclusive contra cidade.
	var grid: HexGrid = c.grid
	var attacker := grid.spawn_unit(_free_at(grid, rival_city.coord, 2), UnitDatabase.create_unit(BOMBARD), rival)
	var human_city: City = c.city
	human_city.buildings.erase("walls")
	assert_true(CombatResolver.can_attack_city(attacker, human_city))
	var city_hp: float = human_city.hp
	CombatResolver.resolve_city_attack(attacker, human_city, grid)
	assert_lt(human_city.hp, city_hp, "ataque de Cerco da IA funciona sem crash")
	var colossus := grid.spawn_unit(_free_at(grid, rival_city.coord, 3), UnitDatabase.create_unit(COLOSSUS), rival)
	assert_not_null(colossus)
	assert_false(rival_city.can_train(COLOSSUS), "com o Colosso da IA vivo o slot dela está tomado")
	for i in 3:
		_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "não crasha com o Colosso no jogo da IA")
	assert_true(is_instance_valid(colossus))
