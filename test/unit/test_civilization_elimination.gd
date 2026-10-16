extends GutTest

## Eliminação de civilização (2026-10-12) — relato do usuário: "se eu derrotar uma civilização conquistando todas as
## cidades dela, as tropas dela continuam vivas, faça desaparecerem".
## Regra: perder a ÚLTIMA cidade elimina a civilização — as unidades que restavam somem do mapa, as relações
## diplomáticas dela acabam e ela não joga mais (HexGrid.eliminate_civilization, chamado por capture_city).

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var third: PlayerData
var _original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-10, 11):
		for r in range(-10, 11):
			if absi(q + r) <= 10:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora")
	rival = _player("Crepúsculo")
	third = _player("Maré")
	GameManager.players = [human, rival, third] as Array[PlayerData]
	GameManager.rival_players = [rival, third] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.debug_mode = false
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 10
	for player in [human, rival, third]:
		player.gold = 500.0

func after_each():
	SelectionManager.reset()
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	for player in [human, rival, third]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _player(civ_name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	return PlayerData.new(civ)

func _unit(coord: Vector2i, owner: PlayerData, kind: String = "warrior") -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)

## Um reino rival com `cities` cidades e três tropas espalhadas pelo mapa.
func _rival_realm(cities: int) -> Array[City]:
	var result: Array[City] = []
	for index in cities:
		result.append(grid.found_city(Vector2i(6, -4 + index * 4), rival, "Rival %d" % index, true))
	_unit(Vector2i(8, -6), rival)
	_unit(Vector2i(-8, 6), rival)
	_unit(Vector2i(2, 7), rival, "settler")
	return result

## O estado de uma partida SALVA ANTES da regra: a última cidade do rival já é de `captor`, mas ninguém o eliminou —
## as tropas continuam no mapa e a guerra continua aberta.
func _fallen_without_elimination(captor: PlayerData) -> City:
	var city: City = _rival_realm(1)[0]
	Diplomacy.declare_war(captor, rival, "Fronteira", true)
	rival.cities.erase(city)
	city.change_owner(captor)
	captor.cities.append(city)
	return city

# --- A regra ----------------------------------------------------------------------------------------------------------

func test_capturing_the_last_city_makes_the_remaining_troops_disappear():
	var cities := _rival_realm(1)
	var troops: Array = rival.units.duplicate()
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	watch_signals(EventBus)

	grid.capture_city(cities[0], human)

	assert_true(rival.units.is_empty(), "nenhuma tropa da civilização conquistada continua viva (nem o Colono)")
	for unit in troops:
		assert_true(unit.is_queued_for_deletion(), "a tropa saiu do mapa")
		assert_ne(grid.get_unit_at(unit.coord), unit, "e o tile dela ficou livre")
	assert_true(V2VictoryConditions.is_eliminated(rival))
	assert_signal_emit_count(EventBus, "civilization_eliminated", 1)
	assert_eq(get_signal_parameters(EventBus, "civilization_eliminated", 0), [rival, human], "quem caiu e quem conquistou")
	assert_signal_emit_count(EventBus, "unit_removed", troops.size(), "cada tropa passa pelo caminho normal de remoção")
	assert_eq(human.cities.size(), 2, "a cidade conquistada fica com o conquistador")

func test_losing_a_city_that_is_not_the_last_keeps_the_troops():
	var cities := _rival_realm(2)
	var troop_count := rival.units.size()
	watch_signals(EventBus)
	grid.capture_city(cities[0], human)
	assert_eq(rival.units.size(), troop_count, "ainda tem cidade: as tropas continuam")
	assert_false(V2VictoryConditions.is_eliminated(rival))
	assert_signal_not_emitted(EventBus, "civilization_eliminated")
	grid.capture_city(cities[1], human)
	assert_true(rival.units.is_empty(), "a segunda era a última")
	assert_signal_emit_count(EventBus, "civilization_eliminated", 1)

func test_a_civilization_that_has_not_founded_its_first_city_is_not_eliminated():
	# Todo reino começa assim: só unidades, nenhuma cidade.
	_unit(Vector2i(5, 0), rival, "settler")
	_unit(Vector2i(-5, 0), human, "settler")
	_unit(Vector2i(0, 5), third, "settler")
	for player in [human, rival, third]:
		assert_false(V2VictoryConditions.is_eliminated(player))
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_eq(rival.units.size(), 1, "nada some sozinho: a regra só dispara na captura da última cidade")

func test_the_rule_is_the_same_between_two_rival_civilizations():
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	var mine := _unit(Vector2i(-5, 0), human)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	grid.capture_city(cities[0], third)
	assert_true(rival.units.is_empty(), "conquistada por outra IA: mesma coisa")
	assert_true(V2VictoryConditions.is_eliminated(rival))
	assert_true(is_instance_valid(mine) and not mine.is_queued_for_deletion(), "ninguém mais é afetado")
	assert_eq(third.cities.size(), 2)

# --- Pelo caminho real: combate, vitória, derrota -------------------------------------------------------------------------

func test_conquering_the_last_city_of_the_last_rival_wins_by_domination():
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	var attacker := _unit(cities[0].coord + Vector2i(-1, 0), human)
	Diplomacy.declare_war(human, rival, "Teste", true)
	cities[0].hp = 0.5
	cities[0].shield = 0.0

	CombatResolver.resolve_city_attack(attacker, cities[0], grid)
	GameManager.check_victories()

	assert_eq(cities[0].owner_player, human, "pré-condição: o ataque capturou a cidade")
	assert_true(rival.units.is_empty())
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "sem ter de caçar as tropas restantes pelo mapa")

func test_the_player_losing_the_last_city_is_defeated():
	var capital := grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	var guard := _unit(Vector2i(-7, 0), human)
	grid.found_city(Vector2i(6, 0), rival, "Rival", true)
	_unit(Vector2i(5, 0), rival)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	watch_signals(EventBus)

	grid.capture_city(capital, rival)
	GameManager.check_victories()

	assert_true(human.units.is_empty() and guard.is_queued_for_deletion(), "a regra vale para o jogador também")
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "game_over", [false])

# --- O que não pode ficar pendurado -----------------------------------------------------------------------------------------

func test_every_diplomatic_tie_with_the_eliminated_civilization_ends():
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	Diplomacy.declare_war(third, rival, "Ambição", true)
	assert_true(Diplomacy.offer_peace(rival, human), "pré-condição: proposta de paz pendente do rival")
	human.peace_refusals[rival] = TurnManager.turn_number + 5

	grid.capture_city(cities[0], human)

	for other in [human, third]:
		assert_false(other.is_at_war_with(rival), "%s não fica em guerra com um reino que não existe" % other.civ.civ_name)
		for relations in [other.enemies, other.truces, other.war_reasons, other.peace_offers, other.peace_refusals, other.war_campaigns]:
			assert_false((relations as Dictionary).has(rival))
	assert_true(rival.enemies.is_empty() and rival.peace_offers.is_empty())
	assert_true(Diplomacy.pending_peace_offers(human).is_empty(), "nenhum modal de paz de uma civilização eliminada")
	assert_eq(Diplomacy.truce_remaining(human, rival), 0, "não é um acordo de paz: sem trégua")

func test_an_eliminated_civilization_takes_no_more_turns():
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_unit(Vector2i(-5, 0), human)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	_unit(Vector2i(0, -7), third)
	grid.capture_city(cities[0], human)
	watch_signals(EventBus)
	var research_before: Dictionary = rival.v2_research.completed_ids.duplicate()

	for turn in 3:
		TurnManager.end_turn()

	assert_true(rival.units.is_empty() and rival.cities.is_empty(), "nada dela volta a nascer")
	assert_eq(rival.v2_research.completed_ids, research_before, "não pesquisa mais")
	assert_false(human.is_at_war_with(rival), "não declara guerra depois de eliminada")
	assert_true(Diplomacy.pending_peace_offers(human).is_empty())
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "a partida segue com as civilizações que restam")

func test_units_removed_in_the_middle_of_the_ai_phase_do_not_act():
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	var doomed: Array = rival.units.duplicate()
	# A fila da fase da IA já tinha uma ação para cada tropa do rival quando a última cidade dele caiu.
	for unit in doomed:
		GameManager._ai_turn_queue.append({"kind": "rival", "unit": unit, "player": rival, "opponent": human, "visible": {}})
	GameManager.is_turn_processing = true
	grid.capture_city(cities[0], human)
	var positions := doomed.map(func(unit): return unit.coord)

	var guard := 0
	while GameManager.is_turn_processing and guard < 50:
		GameManager._process(1.0)
		guard += 1

	assert_false(GameManager.is_turn_processing, "a fila esvazia normalmente")
	assert_eq(doomed.map(func(unit): return unit.coord), positions, "tropa eliminada no mesmo quadro não age")
	for unit in doomed:
		assert_null(grid.get_unit_at(unit.coord), "e não volta a ocupar o mapa")

# --- A regra como ESTADO: partida salva antes dela, ou qualquer caminho que não passe pela captura ---------------------
# Relato do usuário: "quando uma civilização que tava em guerra comigo é eliminada, a gente continua em guerra e mesmo
# após estar morta e eliminada, ela pede paz".

func test_a_fallen_civilization_left_on_the_map_is_settled_by_reconciliation():
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_fallen_without_elimination(human)
	var troops: Array = rival.units.duplicate()
	rival.war_weariness = 80.0
	assert_true(V2VictoryConditions.has_fallen(rival), "pré-condição: já teve cidade e não tem mais")
	assert_false(V2VictoryConditions.is_eliminated(rival), "pré-condição: as tropas ainda a mantinham na partida")
	assert_eq(RivalAI.decide_peace(rival, human), RivalAI.PEACE_DECISION_OFFERED, "pré-condição: era ela que pedia paz depois de conquistada")
	watch_signals(EventBus)

	var settled := grid.reconcile_eliminations()

	assert_eq(settled.size(), 1)
	assert_eq(settled[0], rival)
	assert_true(rival.units.is_empty(), "as tropas somem")
	for unit in troops:
		assert_true(unit.is_queued_for_deletion())
	assert_false(human.is_at_war_with(rival), "a guerra acaba")
	assert_true(Diplomacy.pending_peace_offers(human).is_empty(), "e a proposta de paz dela também")
	assert_false(Diplomacy.has_relations(rival, GameManager.players))
	assert_true(V2VictoryConditions.is_eliminated(rival))
	assert_eq(get_signal_parameters(EventBus, "civilization_eliminated", 0), [rival, human], "o conquistador é quem tem a cidade dela")
	# Idempotente: nada a acertar na segunda passada, nenhum aviso repetido.
	assert_true(grid.reconcile_eliminations().is_empty())
	assert_signal_emit_count(EventBus, "civilization_eliminated", 1)

func test_a_fallen_civilization_does_not_ask_for_peace_when_the_turn_passes():
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_unit(Vector2i(-5, 0), human)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	_unit(Vector2i(0, -7), third)
	_fallen_without_elimination(human)
	rival.war_weariness = 80.0 # acima de RivalAI.WAR_WEARINESS_OFFER_PEACE_THRESHOLD: proporia paz neste turno
	watch_signals(EventBus)

	TurnManager.end_turn()

	assert_signal_not_emitted(EventBus, "peace_offered")
	assert_true(Diplomacy.pending_peace_offers(human).is_empty())
	assert_false(human.is_at_war_with(rival), "o jogador não segue em guerra com um reino conquistado")
	assert_false(human.enemies.has(rival) or human.war_reasons.has(rival))
	assert_true(rival.units.is_empty(), "as tropas que tinham ficado para trás somem na virada")
	assert_signal_emit_count(EventBus, "civilization_eliminated", 1)

func test_a_fallen_civilization_with_no_troops_left_still_has_its_wars_closed():
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_fallen_without_elimination(human)
	for unit in rival.units.duplicate():
		grid.remove_unit(unit)
	assert_true(human.is_at_war_with(rival), "pré-condição: morta, mas a guerra ficou aberta")

	assert_eq(grid.reconcile_eliminations().size(), 1)

	assert_false(human.is_at_war_with(rival))
	assert_false(Diplomacy.has_relations(rival, GameManager.players))

func test_reconciliation_leaves_a_civilization_that_never_had_a_city_alone():
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_unit(Vector2i(5, 0), rival, "settler")
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	watch_signals(EventBus)

	assert_true(grid.reconcile_eliminations().is_empty())

	assert_false(V2VictoryConditions.has_fallen(rival), "ainda vai fundar a primeira cidade")
	assert_eq(rival.units.size(), 1)
	assert_true(human.is_at_war_with(rival))
	assert_signal_not_emitted(EventBus, "civilization_eliminated")

func test_reconciliation_leaves_a_civilization_that_still_has_a_city_alone():
	var cities := _rival_realm(2)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	grid.capture_city(cities[0], human)
	var troop_count := rival.units.size()

	assert_true(grid.reconcile_eliminations().is_empty())

	assert_false(V2VictoryConditions.has_fallen(rival))
	assert_eq(rival.units.size(), troop_count)
	assert_true(human.is_at_war_with(rival), "perdeu uma cidade, não a guerra")

func test_living_rivals_make_no_diplomatic_move_against_an_eliminated_civilization():
	var cities := _rival_realm(1)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	_unit(Vector2i(-5, 0), human)
	grid.found_city(Vector2i(0, -8), third, "Maré Alta", true)
	_unit(Vector2i(0, -7), third)
	grid.capture_city(cities[0], human)

	for turn in 3:
		TurnManager.end_turn()

	assert_false(third.is_at_war_with(rival), "ninguém declara guerra a quem saiu da partida")
	assert_false(Diplomacy.has_relations(rival, GameManager.players), "nem guerra, nem campanha, nem proposta")
