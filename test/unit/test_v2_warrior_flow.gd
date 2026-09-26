extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina do Guerreiro N1-N9 (Aetherlands V2, Fase 7), pelos mesmos caminhos do jogo (HUD/
## SelectionManager/produção/save): jogo novo -> N1 -> N2 -> Salão de Armas -> N3 -> Guerreiro -> N4 -> Golpe Poderoso (mira, ESC,
## clique) -> N5 -> Espadachim (upgrade) -> N6 -> Ataque em Arco (vários inimigos) -> N7 -> Mestre de Armas -> N8 -> Arena dos Campeões
## -> N9 -> Herói da Lâmina -> Execução -> salvar -> carregar -> Guardião N9 também: Exército Supremo 2 / 2 (pesquisável, SEM efeito e
## SEM vitória). O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_warrior_flow_savegame.json"
const HALL := "v2_building_warrior_hall"
const WARRIOR := "v2_unit_warrior"
const SWORDSMAN := "v2_unit_swordsman"
const MASTER := "v2_unit_weapon_master"
const ARENA := "v2_building_warrior_mastery"
const HERO := "v2_legendary_blade_hero"
const POWER := "v2_technique_power_strike"
const CLEAVE := "v2_technique_cleave"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
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

# --- Helpers do Guerreiro ------------------------------------------------------------------------------------

## Constrói `building_id` na cidade pelo fluxo normal (posicionamento de tile + fim de turno).
func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

func _trainable_forms(city: City) -> Array:
	return [WARRIOR, SWORDSMAN, MASTER].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

## Inimigos do rival (em guerra) nos primeiros vizinhos livres e válidos de `coord`; devolve os que conseguiu criar.
func _surround(grid: HexGrid, rival: PlayerData, coord: Vector2i, count: int, hp: float = 40.0, defense: float = 3.0) -> Array[Unit]:
	var foes: Array[Unit] = []
	for n in grid.get_neighbors(coord):
		if foes.size() >= count:
			break
		if WorldSetup._is_valid_spawn(grid, n) and grid.get_city_at(n) == null:
			var data := UnitDatabase.create_unit("warrior")
			data.max_hp = hp
			data.defense = defense
			var foe := grid.spawn_unit(n, data, rival)
			if foe != null:
				foes.append(foe)
	return foes

func _clear_foes(grid: HexGrid, foes: Array[Unit]) -> void:
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

## Cenário curto: jogo novo, cidade com Salão de Armas, Guerreiro pesquisado até `through` e um Guerreiro vivo, em guerra com o rival.
func _short_setup(through: int = 4) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Salão/Arena (upkeep de Ouro)
	# e chegam a treinar o Herói da Lâmina (5 Suprimentos, acima da capacidade base de uma cidade
	# sozinha). Ouro de sobra + uma Fazenda evitam que Déficit/Suprimentos bloqueiem por um motivo
	# alheio ao que cada teste realmente verifica.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(WARRIOR), human)
	assert_not_null(unit)
	return {"grid": grid, "human": human, "rival": rival, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_warrior_n1_to_n9_flow_from_the_weapons_hall_to_the_blade_hero_across_save_and_load():
	# 1. Nova partida (em guerra com o rival, pra os golpes terem alvo).
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — o Guerreiro (N3, 1 Suprimento) vivo mais o Mestre de Armas (N7, 3)
	# já somam 4, e mais adiante o Herói (N9, 5) sozinho já passa a base de uma cidade sozinha (4) --
	# Fazenda desde o início evita que este fluxo pré-existente (Fase 7) tropece num gate que não é o
	# assunto dele. 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o
	# upkeep) -- Ouro de sobra evita que isso sozinho derrube a cidade em Déficit assim que o Salão
	# (também com upkeep) é construído, antes de qualquer Mercado existir.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	human.gold = 1000.0
	assert_false(V2UnlockSystem.is_unlocked(human, "v2_doctrine_warrior"))

	# 2. N1: estabelece a linha, sem bônus global nem passivo; só o N2 fica disponível.
	_research(state, "v2_doctrine_warrior_1")
	assert_true(V2UnlockSystem.is_unlocked(human, "v2_doctrine_warrior"), "2. Doutrina do Guerreiro")
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_warrior"], "o N1 não libera nada além da Doutrina")
	assert_false(city.can_build(HALL), "o Salão é do N2")
	assert_true(state.is_available("v2_doctrine_warrior_2"))
	assert_false(state.is_available("v2_doctrine_warrior_3"))

	# 3. N2 e o Salão de Armas (construção normal da cidade).
	_research(state, "v2_doctrine_warrior_2")
	assert_true(city.can_build(HALL), "3. N2 libera o Salão de Armas")
	_build(grid, city, HALL)
	assert_true(city.buildings.has(HALL))

	# 4-5. N3 e o Guerreiro (treinado pela produção normal).
	assert_false(city.can_train(WARRIOR), "sem N3 não treina")
	_research(state, "v2_doctrine_warrior_3")
	assert_true(_train(city, WARRIOR), "5. Guerreiro em treino")
	var warriors := _units_of_kind(human, WARRIOR)
	assert_eq(warriors.size(), 1)
	var unit: Unit = warriors[0]
	assert_eq(unit.unit_data.max_hp, 16.0)

	# 6-8. N4 e o Golpe Poderoso: mira (nada é gasto), ESC cancela, o clique no alvo resolve.
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "antes do N4 não há técnica")
	_research(state, "v2_doctrine_warrior_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [POWER], "7. Golpe Poderoso")
	unit.movement_left = unit.unit_data.movement_points
	var foe := _surround(grid, rival, unit.coord, 1)[0]
	SelectionManager._select_unit(unit)
	var predicted: float = CombatResolver.predict(unit, foe, grid, 1.6).damage_to_defender
	SelectionManager.use_technique_selected(POWER)
	assert_eq(SelectionManager.technique_targeting_id, POWER, "8. entrou no modo de mira")
	assert_eq(SelectionManager.technique_target_coords, [foe.coord])
	assert_eq(unit.movement_left, unit.unit_data.movement_points, "a mira não gasta a ação")
	assert_false(unit.magic_cooldowns.has(POWER), "nem a recarga")
	assert_true(SelectionManager.cancel_technique_targeting(), "ESC cancela")
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_eq(unit.movement_left, unit.unit_data.movement_points)
	assert_false(unit.magic_cooldowns.has(POWER))
	SelectionManager.use_technique_selected(POWER)
	var foe_hp := foe.hp
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_almost_eq(foe_hp - foe.hp, predicted, 0.0001, "o golpe real bate com a previsão de 1,60x")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, POWER), 3, "recarga de 3 turnos")
	assert_eq(SelectionManager.technique_targeting_id, "", "a mira terminou")
	_clear_foes(grid, [foe])

	# 9-11. N5 e o Espadachim: a produção passa a oferecer só ele e o Guerreiro evolui pelo V2UnitUpgrade.
	_research(state, "v2_doctrine_warrior_5")
	assert_eq(_trainable_forms(city), [SWORDSMAN], "11. a produção oferece só o Espadachim — 32 PP")
	city.set_production(SWORDSMAN)
	assert_eq(city.production_cost(), 32.0)
	city.set_production("")
	_end_turn() # a ação volta; a recarga do Golpe continua contando
	human.gold = 100.0
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, SWORDSMAN, "10. evoluiu para Espadachim")
	assert_eq(human.gold, 100.0 - 24.0, "2 x (32 - 20) = 24 Ouro")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, POWER), 2, "a recarga do Golpe foi preservada pela evolução")

	# 12-14. N6 e o Ataque em Arco: cercado por vários inimigos, um único comando atinge todos (até 3).
	_research(state, "v2_doctrine_warrior_6")
	_end_turn()
	unit.movement_left = unit.unit_data.movement_points
	var surrounding := _surround(grid, rival, unit.coord, 4)
	assert_gte(surrounding.size(), 3, "13. cercado por vários inimigos")
	SelectionManager._select_unit(unit)
	var expected: Dictionary = {}
	for target in V2TechniqueRuntime.strike_targets(unit, V2DoctrineTechniqueDatabase.get_technique(CLEAVE), grid):
		expected[target] = CombatResolver.predict(unit, target, grid, 0.75).damage_to_defender
	assert_eq(expected.size(), 3, "no máximo 3 alvos")
	var hp_before: Dictionary = {}
	for target in expected:
		hp_before[target] = target.hp
	SelectionManager.use_technique_selected(CLEAVE) # sem mira: resolve na hora
	assert_eq(SelectionManager.technique_targeting_id, "", "o Arco não entra em modo de mira")
	for target in expected:
		assert_almost_eq(hp_before[target] - target.hp, expected[target], 0.0001, "14. cada alvo com a sua defesa, a 0,75x")
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE), 4)
	_clear_foes(grid, surrounding)

	# 15-17. N7 e o Mestre de Armas.
	_research(state, "v2_doctrine_warrior_7")
	assert_eq(_trainable_forms(city), [MASTER], "17. a produção oferece só o Mestre de Armas — 48 PP")
	_end_turn()
	human.gold = 100.0
	SelectionManager._select_unit(unit)
	assert_true(V2UnitUpgrade.can_upgrade(human, unit, grid), V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid))
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, MASTER, "16. evoluiu para Mestre de Armas")
	assert_eq(human.gold, 100.0 - 32.0, "2 x (48 - 32) = 32 Ouro")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [POWER, CLEAVE], "herda as duas técnicas")
	assert_eq(unit.kills, 0)

	# 18-19. N8 e a Arena dos Campeões (exige o Salão de Armas).
	assert_false(city.can_build(ARENA), "antes do N8 não constrói")
	_research(state, "v2_doctrine_warrior_8")
	assert_true(city.can_build(ARENA), "18. N8 libera a Arena")
	_build(grid, city, ARENA)
	assert_true(city.buildings.has(HALL), "a Arena não substitui o Salão")
	assert_false(city.can_train(HERO), "sem N9 o Herói ainda não treina")

	# 20-22. N9 e o Herói da Lâmina: produzido separadamente; o Mestre de Armas segue treinável.
	_research(state, "v2_doctrine_warrior_9")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "só o Guerreiro completo: 1 / 2")
	assert_true(city.can_train(HERO), "21. o Herói está disponível")
	assert_true(city.can_train(MASTER), "o Mestre continua treinável")
	assert_true(_train(city, HERO), "22. Herói em treino")
	var heroes := _units_of_kind(human, HERO)
	assert_eq(heroes.size(), 1)
	var hero: Unit = heroes[0]
	assert_true(V2LegendarySystem.is_legendary_unit(hero))
	assert_same(V2LegendarySystem.active_legendary(human), hero)
	assert_eq(_trainable_forms(city), [MASTER], "a cadeia convencional segue intacta")

	# 23. Execução: alvo em exatamente 50% recebe +30% de Ataque; a previsão bate com a resolução; e ela combina com o Golpe.
	hero.movement_left = hero.unit_data.movement_points
	var weak := _surround(grid, rival, hero.coord, 1, 100.0, 3.0)[0]
	weak.hp = 50.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(hero, weak), 1.3, "23. alvo em 50%: Execução")
	var weak_predicted: float = CombatResolver.predict(hero, weak, grid).damage_to_defender
	weak.hp = 51.0
	assert_lt(CombatResolver.predict(hero, weak, grid).damage_to_defender, weak_predicted, "51%: sem o bônus")
	weak.hp = 50.0
	var weak_hp := weak.hp
	CombatResolver.resolve(hero, weak, grid)
	assert_almost_eq(weak_hp - weak.hp, weak_predicted, 0.0001, "previsão == resolução")
	weak.hp = 50.0
	hero.movement_left = hero.unit_data.movement_points
	var combined: float = CombatResolver.predict(hero, weak, grid, 1.6).damage_to_defender
	SelectionManager._select_unit(hero)
	SelectionManager.use_technique_selected(POWER)
	SelectionManager._handle_technique_targeting_click(weak.coord)
	assert_almost_eq(50.0 - weak.hp, combined, 0.0001, "Golpe Poderoso + Execução combinam")
	_clear_foes(grid, [weak])

	# 24-26. Salva e carrega: pesquisa, prédios, formas, recargas e a Execução (derivada) conferem.
	var hero_coord := hero.coord
	var master_cooldown := V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE)
	var hero_cooldown := V2TechniqueRuntime.cooldown_remaining(hero, POWER)
	assert_gt(hero_cooldown, 0, "pré-condição: o Golpe do Herói está em recarga")
	var loaded_grid := _save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.v2_research.get_completed_ids().size(), 9, "26. as 9 pesquisas do Guerreiro")
	var loaded_city: City = loaded.cities[0]
	assert_true(loaded_city.buildings.has(HALL) and loaded_city.buildings.has(ARENA), "Salão de Armas e Arena restaurados")
	var loaded_masters := _units_of_kind(loaded, MASTER)
	assert_eq(loaded_masters.size(), 1)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_masters[0], CLEAVE), master_cooldown, "a recarga do Arco persistiu")
	var loaded_heroes := _units_of_kind(loaded, HERO)
	assert_eq(loaded_heroes.size(), 1)
	var loaded_hero: Unit = loaded_heroes[0]
	assert_eq(loaded_hero.coord, hero_coord)
	assert_eq(loaded_hero.unit_data.max_hp, 38.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_hero, POWER), hero_cooldown, "a recarga do Golpe do Herói persistiu")
	assert_true(V2LegendarySystem.has_active_legendary(loaded), "o slot Lendário continua ocupado")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(loaded_hero).map(func(t): return t.id), [POWER, CLEAVE])
	assert_eq(_trainable_forms(loaded_city), [MASTER])
	var loaded_rival: PlayerData = GameManager.rival_players[0]
	var loaded_foe := _surround(loaded_grid, loaded_rival, loaded_hero.coord, 1, 100.0, 3.0)[0]
	loaded_foe.hp = 50.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(loaded_hero, loaded_foe), 1.3, "a Execução vale depois do load (derivada do tipo)")
	_clear_foes(loaded_grid, [loaded_foe])

	# 27-28. Com o Guardião N9 também: Exército Supremo 2 / 2 e pesquisável — SEM efeito e SEM vitória.
	var loaded_state := loaded.v2_research
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", loaded_state.completed_ids), Vector2i(1, 2))
	assert_false(loaded_state.is_available("v2_supreme_army"), "com uma só Doutrina não")
	for n in range(1, 10):
		loaded_state.complete_research("v2_doctrine_guardian_%d" % n)
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", loaded_state.completed_ids), Vector2i(2, 2), "27. Doutrinas completas: 2 / 2")
	assert_true(loaded_state.is_available("v2_supreme_army"), "Exército Supremo pesquisável")
	# Os dois slots Lendários disputados na cidade carregada: o Campeão não pode enquanto o Herói vive.
	loaded_city.buildings[G_HALL] = true
	loaded_city.buildings[G_MASTERY] = true
	assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON, "o Herói ocupa o slot que o Campeão disputaria")
	watch_signals(EventBus)
	assert_true(loaded_state.select_research("v2_supreme_army"))
	loaded_state.add_knowledge(V2ResearchDatabase.get_node("v2_supreme_army").cost)
	assert_true(loaded_state.is_completed("v2_supreme_army"), "pesquisa registrada")
	# Fase 12: o capstone agora É conectado — mas concluí-lo só desbloqueia o ACESSO
	# à via de Supremacia Militar (derivado da pesquisa), nunca uma vitória em si.
	assert_true(V2ResearchDatabase.get_node("v2_supreme_army").gameplay_connected, "Fase 12: conectado")
	assert_true("v2_military_supremacy_access" in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true("v2_military_supremacy_access" in V2UnlockSystem.unlocked_ids(loaded), "acesso desbloqueado por derivação da pesquisa")
	assert_true(loaded.has_unlocked("v2_military_supremacy_access"))
	assert_false("researched_techs" in loaded, "Fase 25: estado V1 removido")
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "28. nenhuma vitória disparou, mesmo com o acesso desbloqueado")
	assert_signal_not_emitted(EventBus, "victory_achieved")

# --- Casos isolados ------------------------------------------------------------------------------------------

func test_cancelling_the_targeting_by_any_means_consumes_nothing():
	var c := _short_setup(4)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _surround(grid, c.rival, unit.coord, 1)[0]
	SelectionManager._select_unit(unit)
	var hp := foe.hp
	# (a) clique em outro tile
	SelectionManager.use_technique_selected(POWER)
	assert_eq(SelectionManager.technique_targeting_id, POWER)
	var elsewhere := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if coord != foe.coord and coord != unit.coord:
			elsewhere = coord
			break
	SelectionManager._handle_technique_targeting_click(elsewhere)
	assert_eq(SelectionManager.technique_targeting_id, "", "clicar fora cancela")
	assert_eq(foe.hp, hp)
	assert_gt(unit.movement_left, 0.0)
	assert_false(unit.magic_cooldowns.has(POWER))
	assert_same(SelectionManager.selected_unit, unit, "a unidade continua selecionada")
	# (b) limpar a seleção
	SelectionManager.use_technique_selected(POWER)
	SelectionManager._clear_selection()
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false(unit.magic_cooldowns.has(POWER))
	# (c) ESC sem mira não faz nada
	assert_false(SelectionManager.cancel_technique_targeting())
	# (d) depois de tudo, o golpe ainda funciona
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(POWER)
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_lt(foe.hp, hp)

func test_a_power_strike_without_an_adjacent_enemy_never_enters_the_targeting():
	var c := _short_setup(4)
	SelectionManager._select_unit(c.unit)
	SelectionManager.use_technique_selected(POWER)
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false((c.unit as Unit).magic_cooldowns.has(POWER))

func test_the_targeting_only_highlights_valid_enemies_and_ignores_a_peaceful_neighbor():
	var c := _short_setup(4)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var enemies := _surround(grid, c.rival, unit.coord, 1)
	assert_eq(enemies.size(), 1)
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(POWER)
	assert_eq(SelectionManager.technique_target_coords, [enemies[0].coord])
	SelectionManager.cancel_technique_targeting()
	Diplomacy.propose_peace(c.human, c.rival) # paz: o vizinho deixa de ser alvo
	if c.human.is_at_war_with(c.rival):
		c.human.enemies.erase(c.rival)
		c.rival.enemies.erase(c.human)
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(POWER)
	assert_eq(SelectionManager.technique_targeting_id, "", "sem guerra não há alvo")

func test_the_arc_resolves_at_once_from_the_selection_and_can_kill_the_attacker_safely():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foes := _surround(grid, c.rival, unit.coord, 3, 80.0, 30.0) # Defesa 30: o revide é forte
	assert_gte(foes.size(), 1)
	unit.hp = 1.0
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(CLEAVE)
	assert_true(unit.hp <= 0.0 or not is_instance_valid(unit) or unit.is_queued_for_deletion(), "caiu no contra-ataque")
	assert_null(SelectionManager.selected_unit, "a seleção foi limpa com a queda")
	assert_eq(SelectionManager.technique_targeting_id, "")

func test_the_cooldowns_of_both_strike_techniques_survive_save_and_load():
	var c := _short_setup(6)
	var unit: Unit = c.unit
	var grid: HexGrid = c.grid
	var foes := _surround(grid, c.rival, unit.coord, 2)
	assert_true(V2TechniqueRuntime.perform_strike(unit, POWER, foes[0], grid))
	unit.movement_left = unit.unit_data.movement_points
	assert_true(V2TechniqueRuntime.perform_strike(unit, CLEAVE, null, grid))
	var power_left := V2TechniqueRuntime.cooldown_remaining(unit, POWER)
	var cleave_left := V2TechniqueRuntime.cooldown_remaining(unit, CLEAVE)
	assert_eq([power_left, cleave_left], [3, 4])
	_save_and_reload()
	var loaded_units := _units_of_kind(GameManager.human_player, WARRIOR)
	assert_eq(loaded_units.size(), 1)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_units[0], POWER), power_left)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_units[0], CLEAVE), cleave_left)
	assert_false(loaded_units[0].magic_status.has(POWER) or loaded_units[0].magic_status.has(CLEAVE), "nenhum efeito guardado")

func test_a_hero_in_production_survives_save_and_load_and_blocks_a_champion_in_the_other_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	var city: City = c.city
	city.buildings[ARENA] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY])
	assert_true(second.can_train(CHAMPION), "antes da reserva")
	city.set_production(HERO)
	assert_false(second.can_train(CHAMPION), "o Herói em produção reserva o slot único")
	_save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.cities.size(), 2)
	var producing: City = loaded.cities.filter(func(x): return x.production_item == HERO)[0]
	var other: City = loaded.cities.filter(func(x): return x != producing)[0]
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded))
	assert_false(other.can_train(CHAMPION), "a reserva vem da ordem de produção salva")
	producing.set_production("")
	assert_true(other.can_train(CHAMPION), "cancelar libera")

func test_a_hero_and_a_champion_finishing_in_the_same_turn_never_create_two_legendaries():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	var city: City = c.city
	city.buildings[ARENA] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY])
	# Estado forçado (o gate normal impediria): duas ordens Lendárias prontas no mesmo turno.
	city.set_production(HERO)
	second.set_production(CHAMPION)
	_end_turn()
	assert_push_error("não nasceu")
	var legends := 0
	for unit in human.units:
		if V2LegendarySystem.is_legendary_unit(unit):
			legends += 1
	assert_eq(legends, 1, "jamais duas Lendárias ativas, de Doutrinas diferentes")
	assert_eq(V2LegendarySystem.active_legendary_units(human).size(), 1)

func test_the_conventional_weapon_master_production_is_untouched_by_the_legendary_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[ARENA] = true
	city.set_production(HERO)
	assert_true(city.can_train(MASTER))
	city.set_production(MASTER)
	_end_turn()
	assert_eq(_units_of_kind(human, MASTER).size(), 1)
	assert_eq(_units_of_kind(human, HERO).size(), 0)

func test_ai_civilizations_keep_playing_with_the_warrior_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(HALL))
			assert_false(rival_city.buildings.has(ARENA))
			assert_ne(rival_city.production_item, HERO)
		assert_eq(_units_of_kind(rival, HERO).size(), 0)
		assert_eq(_units_of_kind(rival, WARRIOR).size(), 0, "a IA não usa conteúdo V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))

func test_an_ai_civilization_given_the_research_by_debug_trains_the_right_form_and_respects_the_slot():
	var c := _short_setup(3)
	var rival: PlayerData = c.rival
	for n in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	var rival_city: City = rival.cities[0]
	rival_city.city_level = 3
	rival_city.buildings[HALL] = true
	rival_city.buildings[ARENA] = true
	# Aetherlands V2, Fase 15 — o Herói da Lâmina custa 5 Suprimentos (acima da base de 4) e
	# Salão+Arena têm gold_upkeep sem Mercado -- Fazenda + Ouro de sobra evitam que Suprimentos/
	# Déficit bloqueiem o que este teste verifica (RivalAI resolve a forma certa e respeita o slot).
	rival_city.buildings["v2_building_farm"] = true
	rival_city.repeatable_building_counts["v2_building_farm"] = 1
	if rival.gold <= 0.0:
		rival.gold = 1000.0
	var offered: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and rival_city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(MASTER), "produz a forma correta")
	assert_false(offered.has(WARRIOR))
	assert_false(offered.has(SWORDSMAN))
	assert_true(offered.has(HERO), "e o Lendário respeita o slot: livre, pode")
	rival_city.set_production(HERO)
	for i in 3:
		_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "não crasha")
