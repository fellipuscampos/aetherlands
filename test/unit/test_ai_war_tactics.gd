extends GutTest

## Rodada de IA de 2026-10-15: tática de guerra (AIWarTactics), memória diplomática (DiplomaticMemory), produção de
## guerra (V2StrategicAI.war_production_pressure) e dificuldade econômica das IAs (V2AIDifficulty).

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _owned_players: Array[PlayerData] = []
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rivals: Array[PlayerData]
var _original_players: Array[PlayerData]
var _original_difficulty: String

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rivals = GameManager.rival_players.duplicate()
	_original_players = GameManager.players.duplicate()
	_original_difficulty = GameManager.difficulty
	hex_grid = HexGrid.new()
	hex_grid._ready()
	for q in range(-3, 9):
		for r in range(-4, 5):
			hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _track(CivilizationData.new())
	rival = _track(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human

func after_each():
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rivals
	GameManager.players = _original_players
	GameManager.difficulty = _original_difficulty
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_created_units.clear()
	hex_grid.queue_free()

func _track(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

func _unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

## Civilização sem nada é "eliminada" (V2VictoryConditions.is_eliminated) e fica fora da memória: um Colono basta.
func _keep_alive(players: Array) -> void:
	for i in players.size():
		_unit("settler", players[i], Vector2i(-3, -4 + i))

func _visible_all() -> Dictionary:
	var visible := {}
	for coord in hex_grid.tiles:
		visible[coord] = true
	return visible

# --- foco de fogo ------------------------------------------------------------------------------------------------

func test_best_strike_prefers_the_wounded_enemy_it_can_kill():
	Diplomacy.declare_war(human, rival)
	var attacker := _unit("warrior", rival, Vector2i(0, 0))
	var healthy := _unit("warrior", human, Vector2i(1, 0))
	var wounded := _unit("warrior", human, Vector2i(0, 1))
	wounded.hp = 1.0

	var strike := AIWarTactics.best_strike(attacker, rival, hex_grid, _visible_all())

	assert_eq(strike.get("target"), wounded, "o inimigo que morre neste golpe vale mais que o saudável ao lado")
	assert_ne(strike.get("target"), healthy)

func test_best_strike_never_picks_a_suicidal_attack():
	Diplomacy.declare_war(human, rival)
	var attacker := _unit("warrior", rival, Vector2i(0, 0))
	attacker.hp = 0.5
	_unit("warrior", human, Vector2i(1, 0))

	var strike := AIWarTactics.best_strike(attacker, rival, hex_grid, _visible_all())

	assert_true(strike.is_empty(), "morreria no revide: nenhum golpe")

func test_unit_moves_and_attacks_in_the_same_turn():
	Diplomacy.declare_war(human, rival)
	var attacker := _unit("warrior", rival, Vector2i(0, 0))
	attacker.movement_left = 3.0
	var enemy := _unit("warrior", human, Vector2i(3, 0))
	enemy.hp = 1.0

	RivalAI._handle_attacker(attacker, hex_grid, rival, human, _visible_all())

	assert_false(is_instance_valid(enemy) and enemy.hp > 0.0 and human.units.has(enemy), "andou até o alcance e atacou no mesmo turno")

# --- recuo com histerese -----------------------------------------------------------------------------------------

func test_recovering_unit_does_not_rejoin_the_fight_until_healed():
	var unit := _unit("warrior", rival, Vector2i(0, 0))
	unit.hp = unit.unit_data.max_hp * 0.3
	assert_true(AIWarTactics.update_recovery(unit), "abaixo do limiar: entra em recuo")
	unit.hp = unit.unit_data.max_hp * 0.5
	assert_true(AIWarTactics.update_recovery(unit), "com 50% ainda está curando (antes voltava com 36%)")
	unit.hp = unit.unit_data.max_hp * AIWarTactics.RECOVER_HP_FRACTION
	assert_false(AIWarTactics.update_recovery(unit), "curada: volta à luta")

func test_wounded_unit_without_a_free_city_fortifies_to_heal():
	Diplomacy.declare_war(human, rival)
	var unit := _unit("warrior", rival, Vector2i(4, 0))
	unit.hp = unit.unit_data.max_hp * 0.2
	unit.movement_left = 0.0 # não consegue sair do lugar neste turno

	RivalAI._handle_attacker(unit, hex_grid, rival, human, _visible_all())

	assert_true(unit.fortified, "parada e ferida: Fortificar (cura passiva) em vez de ficar parada sem curar")

# --- defesa contra exércitos -------------------------------------------------------------------------------------

func test_units_near_a_besieged_city_come_back_to_defend_it():
	Diplomacy.declare_war(human, rival)
	var city := hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var defender := _unit("warrior", rival, Vector2i(5, 0))
	defender.movement_left = 2.0
	_unit("warrior", human, Vector2i(1, 1))
	var before := HexMetrics.axial_distance(defender.coord, city.coord)

	assert_true(AIWarTactics.defend_against_invaders(defender, rival, hex_grid, _visible_all()), "a cidade atacada consome o turno da tropa próxima")
	assert_lt(HexMetrics.axial_distance(defender.coord, city.coord), before, "volta para perto da cidade atacada")

func test_the_last_garrison_never_leaves_the_besieged_city():
	Diplomacy.declare_war(human, rival)
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var garrison := _unit("warrior", rival, Vector2i(0, 0))
	garrison.movement_left = 2.0
	var invader := _unit("warrior", human, Vector2i(3, 0))

	AIWarTactics.defend_against_invaders(garrison, rival, hex_grid, _visible_all())

	assert_eq(garrison.coord, Vector2i(0, 0), "a guarnição solitária fica na cidade (sairia e a cidade cairia vazia)")
	assert_true(is_instance_valid(invader))

func test_no_invader_no_defense_turn():
	Diplomacy.declare_war(human, rival)
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var unit := _unit("warrior", rival, Vector2i(2, 0))
	assert_false(AIWarTactics.defend_against_invaders(unit, rival, hex_grid, _visible_all()))

# --- exército agrupado e posicionamento à distância --------------------------------------------------------------

func test_vanguard_waits_for_the_group_in_a_campaign():
	var target := Vector2i(8, 0)
	var vanguard := _unit("warrior", rival, Vector2i(5, 0))
	_unit("warrior", rival, Vector2i(0, 0))
	_unit("warrior", rival, Vector2i(-1, 0))
	assert_true(AIWarTactics.should_hold_for_group(vanguard, rival, target), "5 casas à frente do grupo: espera")
	var follower := rival.units[1]
	assert_false(AIWarTactics.should_hold_for_group(follower, rival, target), "quem está atrás continua andando")

func test_a_lone_unit_never_waits_for_a_group():
	var unit := _unit("warrior", rival, Vector2i(5, 0))
	assert_false(AIWarTactics.should_hold_for_group(unit, rival, Vector2i(8, 0)))

func test_ranged_unit_stops_at_range_instead_of_walking_next_to_the_enemy():
	Diplomacy.declare_war(human, rival)
	var archer := _unit("archer", rival, Vector2i(0, 0))
	archer.movement_left = 4.0
	_unit("warrior", rival, Vector2i(1, -1)) # escolta
	var enemy := _unit("warrior", human, Vector2i(5, 0))

	AIWarTactics.move_ranged(archer, rival, hex_grid, _visible_all(), enemy.coord)

	assert_ne(archer.coord, Vector2i(0, 0), "avançou")
	assert_gt(HexMetrics.axial_distance(archer.coord, enemy.coord), 1, "não encosta no corpo-a-corpo inimigo")

# --- postura sem alvo --------------------------------------------------------------------------------------------

func test_without_a_target_only_two_scouts_explore_and_the_rest_garrison():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var scout_a := _unit("warrior", rival, Vector2i(4, 0))
	var scout_b := _unit("warrior", rival, Vector2i(4, 1))
	var extra := _unit("warrior", rival, Vector2i(5, 0))
	extra.movement_left = 2.0
	assert_true(AIWarTactics.is_designated_scout(scout_a, rival))
	assert_true(AIWarTactics.is_designated_scout(scout_b, rival))
	assert_false(AIWarTactics.is_designated_scout(extra, rival), "a terceira tropa não explora")
	var before := HexMetrics.axial_distance(extra.coord, Vector2i(0, 0))

	RivalAI._handle_attacker(extra, hex_grid, rival, human, _visible_all())

	assert_lt(HexMetrics.axial_distance(extra.coord, Vector2i(0, 0)), before, "sem alvo, volta para guarnecer a cidade")

func test_garrison_fortifies_when_it_reaches_its_post():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	_unit("warrior", rival, Vector2i(6, 0))
	_unit("warrior", rival, Vector2i(6, 1))
	var guard := _unit("warrior", rival, Vector2i(1, 0))

	RivalAI._handle_attacker(guard, hex_grid, rival, human, _visible_all())

	assert_true(guard.fortified, "no posto: fortifica")
	assert_eq(guard.coord, Vector2i(1, 0))

# --- memória diplomática -----------------------------------------------------------------------------------------

func test_war_declaration_is_remembered_by_the_victim_and_witnesses():
	var witness := _track(CivilizationData.new())
	GameManager.players = [human, rival, witness] as Array[PlayerData]
	_keep_alive([human, rival, witness])
	Diplomacy.declare_war(human, rival)
	assert_almost_eq(DiplomaticMemory.value(rival, human, DiplomaticMemory.AGGRESSION), DiplomaticMemory.WAR_DECLARED_ON_ME, 0.01)
	assert_almost_eq(DiplomaticMemory.value(witness, human, DiplomaticMemory.WARMONGER), DiplomaticMemory.WARMONGER_PER_WAR, 0.01, "os outros reinos veem o belicista")
	assert_eq(DiplomaticMemory.value(human, rival, DiplomaticMemory.AGGRESSION), 0.0, "quem declara não guarda rancor por isso")
	assert_eq(DiplomaticMemory.level(rival, human), DiplomaticMemory.LEVEL_WARY)

func test_betrayal_when_declaring_with_open_borders():
	Diplomacy.make_open_borders(human, rival)
	Diplomacy.declare_war(human, rival)
	assert_gt(DiplomaticMemory.value(rival, human, DiplomaticMemory.BETRAYAL), 0.0)

func test_grudges_cool_down_in_peace_and_goodwill_grows():
	GameManager.players = [human, rival] as Array[PlayerData]
	_keep_alive([human, rival])
	Diplomacy.declare_war(human, rival)
	Diplomacy.make_peace(human, rival)
	var start := DiplomaticMemory.attitude(rival, human)
	for i in range(40):
		DiplomaticMemory.process_turn(rival)
	assert_gt(DiplomaticMemory.attitude(rival, human), start + 20.0, "40 turnos de paz: rancor esfria e a paz conta a favor")

func test_combat_between_civs_at_war_is_bloodshed():
	Diplomacy.declare_war(human, rival)
	DiplomaticMemory.on_combat(human, rival, "unit")
	DiplomaticMemory.on_combat(human, rival, "city")
	assert_almost_eq(DiplomaticMemory.value(rival, human, DiplomaticMemory.BLOODSHED), DiplomaticMemory.BLOOD_PER_UNIT_ATTACK + DiplomaticMemory.BLOOD_PER_CITY_ATTACK, 0.01)

func test_shared_enemy_builds_goodwill():
	var common := _track(CivilizationData.new())
	GameManager.players = [human, rival, common] as Array[PlayerData]
	_keep_alive([human, rival, common])
	Diplomacy.declare_war(human, common)
	Diplomacy.declare_war(rival, common)
	DiplomaticMemory.process_turn(rival)
	assert_gt(DiplomaticMemory.value(rival, human, DiplomaticMemory.COMMON_ENEMY), 0.0)

func test_wary_ai_refuses_open_borders():
	Diplomacy.declare_war(human, rival)
	Diplomacy.make_peace(human, rival)
	TurnManager.turn_number += Diplomacy.TRUCE_TURNS + 1
	assert_ne(Diplomacy.open_borders_refusal_reason(rival, human), "", "rancor de guerra: recusa fronteiras abertas")
	TurnManager.turn_number -= Diplomacy.TRUCE_TURNS + 1

func test_memory_survives_save_round_trip_format():
	var players: Array = [human, rival]
	Diplomacy.declare_war(human, rival)
	var saved := DiplomaticMemory.serialize(rival, players)
	var restored := _track(CivilizationData.new())
	DiplomaticMemory.restore(restored, JSON.parse_string(JSON.stringify(saved)), [human, restored])
	assert_almost_eq(DiplomaticMemory.value(restored, human, DiplomaticMemory.AGGRESSION), DiplomaticMemory.WAR_DECLARED_ON_ME, 0.01)
	assert_eq(int(DiplomaticMemory.record(restored, human).war_start), TurnManager.turn_number, "inteiros voltam como inteiros")

# --- produção de guerra ------------------------------------------------------------------------------------------

func test_war_pressure_raises_the_army_target():
	var base := V2AITuning.target_relevant_units(rival)
	assert_eq(V2AITuning.war_target_relevant_units(rival, 0.0, 0), base, "em paz, sem mudança")
	assert_gt(V2AITuning.war_target_relevant_units(rival, 1.0, 0), base, "sob pressão de guerra, quer mais tropas")
	assert_eq(V2AITuning.war_target_relevant_units(rival, 1.0, 100), V2AITuning.HARD_TOKEN_CAP, "nunca acima do teto rígido")

func test_war_production_pressure_levels():
	hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var view := V2AIWorldView.capture(rival, hex_grid)
	assert_eq(V2StrategicAI.war_production_pressure(rival, view), 0.0)
	Diplomacy.declare_war(human, rival)
	view = V2AIWorldView.capture(rival, hex_grid)
	assert_almost_eq(V2StrategicAI.war_production_pressure(rival, view), 0.6, 0.001, "em guerra")

# --- dificuldade das IAs -----------------------------------------------------------------------------------------

func test_difficulty_scales_only_rival_income():
	GameManager.rival_players = [rival] as Array[PlayerData]
	var rival_city := hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	var human_city := hex_grid.found_city(Vector2i(6, 0), human, "Capital")
	GameManager.difficulty = V2AIDifficulty.NORMAL
	var rival_normal := V2EconomyRuntime.city_production_income(rival_city)
	var human_normal := V2EconomyRuntime.city_production_income(human_city)
	var knowledge_normal := V2EconomyRuntime.player_knowledge_income(rival)

	GameManager.difficulty = V2AIDifficulty.EASY
	assert_almost_eq(V2EconomyRuntime.city_production_income(rival_city), rival_normal * 1.25, 0.001, "Fácil: tudo mais leve para a IA")
	assert_almost_eq(V2EconomyRuntime.player_knowledge_income(rival), knowledge_normal * 1.25, 0.001)
	GameManager.difficulty = V2AIDifficulty.HARD
	assert_almost_eq(V2EconomyRuntime.city_production_income(rival_city), rival_normal * 0.75, 0.001, "Difícil: tudo mais caro para a IA")
	assert_almost_eq(V2EconomyRuntime.city_production_income(human_city), human_normal, 0.001, "o jogador nunca é tocado")
	assert_almost_eq(float(V2EconomyRuntime.city_income_breakdown(rival_city, "production").total), V2EconomyRuntime.city_production_income(rival_city), 0.001, "a UI mostra o mesmo número")

func test_unknown_difficulty_falls_back_to_normal():
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.difficulty = "insane"
	assert_eq(V2AIDifficulty.economy_multiplier(rival), 1.0)
