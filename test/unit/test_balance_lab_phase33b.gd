extends GutTest

## Fase 33B — Release Balance Lab. Cobre o harness 4-IA (assento humano automatizado pelo mesmo
## stack V2), no-cheat, anti-onisciência, separação observador × entrada da IA, marcos one-shot,
## prontidão exata de Supremacia/Transcendência, fim de partida, rotação raça/orientação, reset entre
## partidas e um smoke determinístico curto. O batch completo roda fora da suíte:
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --matches=0-47 --tag=baseline

const SMOKE_TURNS := 8
const SMALL_MAP := 61
const SACRED_RITUAL := "v2_building_sacred_ritual"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"

var _original := {}
var _manual_grid: HexGrid

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "human_kingdom_name", "debug_mode", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.player_index = TurnManager.current_player_index
	_original.player_count = TurnManager.player_count
	_original.events = WorldEventManager.active_events.duplicate()
	_original.event_id = WorldEventManager._next_event_id
	GameManager.players = []
	GameManager.rival_players = []
	GameManager.human_player = null
	GameManager.hex_grid = null
	GameManager.ai_controls_human_seat = false
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0

func after_each():
	V2AITacticalAI.clear_views()
	if GameManager.hex_grid != null or not GameManager.players.is_empty():
		GameManager.end_match()
	if _manual_grid != null and is_instance_valid(_manual_grid):
		_manual_grid.queue_free()
	_manual_grid = null
	for key in _original:
		if key not in ["turn", "player_index", "player_count", "events", "event_id"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	TurnManager.current_player_index = _original.player_index
	TurnManager.player_count = _original.player_count
	WorldEventManager.active_events.assign(_original.events)
	WorldEventManager._next_event_id = _original.event_id

# --- Fixtures ------------------------------------------------------------------------------------

func _small_config(index: int, turn_cap: int = SMOKE_TURNS) -> Dictionary:
	var config := BalanceSeedSet.match_config(index, turn_cap)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	return config

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

## Mundo pequeno montado à mão (mesmo padrão de test_v2_transcendence_system): humano no centro e um
## rival distante, para cenários exatos de pesquisa/ritual/visão.
func _manual_world(ai_seat: bool) -> Array[PlayerData]:
	_manual_grid = HexGrid.new()
	_manual_grid._ready()
	for q in range(-10, 11):
		for r in range(-10, 11):
			if absi(q + r) <= 10:
				_manual_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := _player("Assento 0")
	var rival := _player("Assento 1")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = _manual_grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.ai_controls_human_seat = ai_seat
	TurnManager.turn_number = 40
	_manual_grid.found_city(Vector2i.ZERO, human, "Centro", true)
	_manual_grid.found_city(Vector2i(10, -5), rival, "Distante", true)
	for player in GameManager.players:
		V2StrategicAI.initialize_player(player, GameManager.players.find(player), 1, 1)
	return [human, rival] as Array[PlayerData]

func _complete_branch(player: PlayerData, tree: int, branch: String) -> void:
	assert_eq(player.v2_research.debug_complete_branch(tree, branch), 9)

# --- Seed set / rotação ------------------------------------------------------------------------

func test_seed_set_is_explicit_versioned_and_reproducible():
	assert_eq(BalanceSeedSet.SEEDS.size(), 48, "amostra-alvo explícita de 48 partidas")
	var seen := {}
	for value in BalanceSeedSet.all_seeds():
		assert_false(seen.has(value), "seed única: %d" % value)
		seen[value] = true
	assert_eq(BalanceSeedSet.match_count(), 64, "48 + 16 reservas para a validação de 100+ da F33C")
	var first := BalanceSeedSet.match_config(7)
	assert_eq(first, BalanceSeedSet.match_config(7), "mesma partida => mesma configuração")
	assert_eq(first.match_id, "F33B-008")
	assert_eq(first.baseline_id, "RELEASE_BALANCE_BASELINE_PRE_TUNING")
	# V3 / Etapa 3: o laboratório mede o mundo padrão 1.0 (só o continente principal; 320x84 = perfil especial).
	assert_eq(first.map_width, WorldProfile.STANDARD_1_0.width)
	assert_eq(first.map_height, WorldProfile.STANDARD_1_0.height)
	assert_eq(first.turn_cap, 240)
	for key in ["seed", "races", "orientations", "seed_set_version"]:
		assert_true(first.has(key), "config registra %s" % key)

func test_seed_parity_is_balanced_per_configuration_and_stage():
	# A IA BALANCED escolhe o foco-reserva por posmod(strategy_seed, 2), derivado da seed do mapa e do
	# índice do assento: a paridade das seeds não pode ficar acoplada ao assento/configuração.
	var seeds := BalanceSeedSet.all_seeds()
	for config in 12:
		var odd := 0
		for block in 4:
			odd += seeds[config + 12 * block] % 2
		assert_eq(odd, 2, "configuração %d aparece 2× com seed ímpar e 2× com par" % config)
	for stage in [12, 24, 48]:
		var odd := 0
		for i in stage:
			odd += seeds[i] % 2
		assert_eq(odd, stage / 2, "estágio de %d partidas com metade de cada paridade" % stage)

func test_race_rotation_puts_every_race_in_every_seat():
	var counts := {}
	for index in 48:
		var races := BalanceSeedSet.races_for(index)
		var sorted := races.duplicate()
		sorted.sort()
		assert_eq(sorted, ["dwarf", "elf", "human", "orc"], "as quatro raças jogam toda partida")
		for seat in 4:
			var key := "%s@%d" % [races[seat], seat]
			counts[key] = int(counts.get(key, 0)) + 1
	for race in BalanceSeedSet.RACES:
		for seat in 4:
			assert_eq(int(counts.get("%s@%d" % [race, seat], 0)), 12, "%s ocupa o assento %d 12 vezes" % [race, seat])

func test_orientation_rotation_is_balanced_and_never_bound_to_race():
	var by_race := {}
	var by_seat := {}
	for index in 48:
		var races := BalanceSeedSet.races_for(index)
		var orientations := BalanceSeedSet.orientations_for(index)
		var distinct := {}
		for seat in 4:
			distinct[orientations[seat]] = true
			var race_key := "%s|%d" % [races[seat], orientations[seat]]
			by_race[race_key] = int(by_race.get(race_key, 0)) + 1
			var seat_key := "%d|%d" % [seat, orientations[seat]]
			by_seat[seat_key] = int(by_seat.get(seat_key, 0)) + 1
		assert_eq(distinct.size(), 3, "toda partida tem MILITARY, ARCANE e BALANCED")
	for orientation in [V2AIStrategyState.Orientation.MILITARY, V2AIStrategyState.Orientation.ARCANE, V2AIStrategyState.Orientation.BALANCED]:
		for race in BalanceSeedSet.RACES:
			assert_eq(int(by_race.get("%s|%d" % [race, orientation], 0)), 16, "raça %s não fica presa a uma orientação" % race)
		for seat in 4:
			assert_eq(int(by_seat.get("%d|%d" % [seat, orientation], 0)), 16, "assento %d recebe cada orientação" % seat)

# --- Assento humano automatizado ----------------------------------------------------------------

func test_default_flag_keeps_the_normal_game_semantics():
	var players := _manual_world(false)
	var human := players[0]
	var rival := players[1]
	assert_eq(GameManager.ai_controlled_players(), GameManager.rival_players, "sem fixture, só os rivais são IA")
	assert_true(GameManager.is_human_controlled(human))
	assert_false(GameManager.is_human_controlled(rival))
	assert_false(V2StrategicAI.is_enabled_for(human), "o humano real nunca recebe decisões da IA")
	assert_true(V2StrategicAI.is_enabled_for(rival))
	assert_eq(V2StrategicAI.plan_turn(human, _manual_grid), {})

func test_automated_human_seat_uses_the_rival_stack_and_ai_visibility_rules():
	var players := _manual_world(true)
	var human := players[0]
	var rival := players[1]
	assert_eq(GameManager.ai_controlled_players(), [human, rival], "o assento formal entra no MESMO loop de IA")
	assert_false(GameManager.is_human_controlled(human))
	assert_true(V2StrategicAI.is_enabled_for(human))
	var report := V2StrategicAI.plan_turn(human, _manual_grid)
	assert_false(report.is_empty(), "V2StrategicAI planeja o assento humano como planeja um rival")
	assert_ne(human.v2_research.active_id, "", "pesquisa escolhida pelo mesmo planejador")
	# Regra de mira de UI (alvo precisa estar VISÍVEL na neblina do humano) não vale para a IA.
	var unit := _manual_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), human)
	var hidden := Vector2i(8, -4)
	_manual_grid.visibility[hidden] = HexGrid.Visibility.UNSEEN
	_manual_grid.visibility[Vector2i.ZERO] = HexGrid.Visibility.VISIBLE
	assert_true(V2TechniqueRuntime._visible_to_owner(unit, hidden, _manual_grid), "assento automatizado segue a regra da IA")
	GameManager.ai_controls_human_seat = false
	assert_false(V2TechniqueRuntime._visible_to_owner(unit, hidden, _manual_grid), "humano real continua limitado pela neblina")
	assert_false(V2MagicRuntime._visible_to_owner(unit, hidden, _manual_grid))

func test_human_seat_elimination_does_not_end_the_four_ai_match():
	var players := _manual_world(true)
	var human := players[0]
	for city in human.cities.duplicate():
		human.cities.erase(city)
	GameManager.check_victories()
	# O rival ainda não é o último de pé (humano sem nada = eliminado => Dominação do rival).
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "eliminação conta para a Dominação do rival")
	GameManager.state = GameManager.GameState.PLAYING
	var third := _player("Assento 2")
	GameManager.players.append(third)
	GameManager.rival_players.append(third)
	_manual_grid.found_city(Vector2i(-8, 4), third, "Terceiro", true)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "no laboratório, o assento humano eliminado não encerra a partida")
	GameManager.ai_controls_human_seat = false
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "no jogo normal, o humano eliminado continua perdendo")

# --- No-cheat -----------------------------------------------------------------------------------

func test_setup_grants_nothing_and_first_turn_resources_come_only_from_runtime():
	var grid := BalanceMatchRunner.setup_match(self, _small_config(3))
	assert_eq(GameManager.players.size(), 4, "quatro civilizações inicializadas")
	var before := []
	for player in GameManager.players:
		assert_eq(player.gold, 0.0, "sem Ouro grátis")
		assert_eq(player.mana, 0.0, "sem Mana grátis")
		assert_eq(player.v2_research.completed_ids.size(), 0, "sem pesquisa grátis")
		assert_eq(player.cities.size(), 1, "exatamente a capital do spawn")
		assert_eq(player.units.size(), 1, "exatamente o Guarda inicial")
		assert_eq(player.units[0].unit_data.visual_kind, "warrior")
		assert_eq(player.cities[0].stored_production, 0.0, "sem Produção grátis")
		assert_eq(player.cities[0].production_item, "")
		before.append({
			"gold": player.gold,
			"gross": V2EconomyRuntime.player_gold_gross_income(player),
			"upkeep": V2EconomyRuntime.player_gold_upkeep(player),
			"mana": player.mana,
			"mana_income": V2EconomyRuntime.player_mana_income(player),
			"knowledge_income": V2EconomyRuntime.player_knowledge_income(player),
		})
	TurnManager.end_turn()
	for index in GameManager.players.size():
		var player: PlayerData = GameManager.players[index]
		var expected: Dictionary = before[index]
		assert_almost_eq(player.gold, maxf(0.0, expected.gold + expected.gross - expected.upkeep), 0.0001, "Ouro só pelo runtime (assento %d)" % index)
		assert_almost_eq(player.mana, expected.mana + expected.mana_income, 0.0001, "Mana só pelo runtime (assento %d)" % index)
		var generated := 0.0
		for id in player.v2_research.completed_ids:
			generated += V2ResearchDatabase.get_node(id).cost
		for id in player.v2_research.progress_by_id:
			generated += float(player.v2_research.progress_by_id[id])
		generated += player.v2_research.research_overflow
		assert_almost_eq(generated, expected.knowledge_income, 0.0001, "Conhecimento só pela renda (assento %d)" % index)
		assert_true(player.v2_research.active_id != "" or not player.v2_research.completed_ids.is_empty(), "todo assento recebeu o turno e escolheu pesquisa")
	await BalanceMatchRunner.teardown_match(self, grid)

# --- Anti-onisciência / observador ------------------------------------------------------------

func test_worldview_hides_enemy_units_and_observer_does_not_feed_the_ai():
	var players := _manual_world(true)
	var human := players[0]
	var rival := players[1]
	var far_unit := _manual_grid.spawn_unit(Vector2i(9, -3), UnitDatabase.create_unit("warrior"), rival)
	var view := V2AIWorldView.capture(human, _manual_grid)
	assert_false(view.visible_enemy_units.has(far_unit), "a IA do assento humano não vê unidade escondida")
	assert_true(view.known_enemy_cities.is_empty(), "cidade nunca vista não é conhecida")
	var known_before := human.known_enemy_cities.duplicate()
	var explored_before := human.explored_tiles.size()
	var telemetry := BalanceTelemetry.new()
	telemetry.start({"match_id": "observer"})
	telemetry.on_turn_end()
	var rival_snapshot: Dictionary = telemetry.civs[1].snapshots.back()
	assert_eq(int(rival_snapshot.units_total), 1, "o OBSERVADOR vê o estado completo do rival")
	assert_eq(human.known_enemy_cities, known_before, "observar não escoteia para a IA")
	assert_eq(human.explored_tiles.size(), explored_before, "observar não revela mapa para a IA")
	var view_after := V2AIWorldView.capture(human, _manual_grid)
	assert_eq(view_after.visible_enemy_units, view.visible_enemy_units, "entrada de decisão da IA idêntica com o observador ligado")
	telemetry.finish({"timeout": false})
	assert_eq(telemetry.connected_signal_count(), 0, "observador desconecta tudo ao terminar")

# --- Marcos -------------------------------------------------------------------------------------

func test_milestones_are_one_shot():
	var telemetry := BalanceTelemetry.new()
	var civ := {"milestones": {}, "milestone_context": {}}
	assert_true(telemetry._mark(civ, "n9_first", 110, {"cities": 3}))
	assert_false(telemetry._mark(civ, "n9_first", 150, {"cities": 7}), "segundo registro é ignorado")
	assert_eq(int(civ.milestones.n9_first), 110)
	assert_eq(int(civ.milestone_context.n9_first.cities), 3)

func test_supremacy_research_ready_is_exact():
	var players := _manual_world(true)
	var human := players[0]
	var telemetry := BalanceTelemetry.new()
	telemetry.start({"match_id": "supremacy"})
	_complete_branch(human, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	_complete_branch(human, V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "n9_second"), 40, "duas N9 quaisquer")
	assert_eq(telemetry.milestone(0, "supremacy_research_ready"), -1, "uma Doutrina N9 não basta")
	TurnManager.turn_number = 41
	_complete_branch(human, V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "military_n9_second"), 41)
	assert_eq(telemetry.milestone(0, "supremacy_research_ready"), -1, "duas Doutrinas N9 sem Exército Supremo não é pronto")
	TurnManager.turn_number = 42
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "supremacy_research_ready"), 42, "duas Doutrinas N9 + Exército Supremo")
	assert_eq(telemetry.milestone(0, "supreme_army"), 42)
	telemetry.finish({"timeout": false})

func test_transcendence_research_and_ritual_ready_use_the_canonical_runtime():
	var players := _manual_world(true)
	var human := players[0]
	var city: City = human.cities[0]
	var telemetry := BalanceTelemetry.new()
	telemetry.start({"match_id": "transcendence"})
	_complete_branch(human, V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	_complete_branch(human, V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "transcendence_research_ready"), -1, "duas Escolas N9 sem o capstone não é pronto")
	TurnManager.turn_number = 41
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	city.buildings[SACRED_RITUAL] = true
	_manual_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SERAPH), human)
	_manual_grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit(ARCHDEMON), human)
	human.mana = 0.0
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "transcendence_research_ready"), 41)
	assert_false(V2TranscendenceSystem.can_start_ritual(human, city))
	assert_eq(telemetry.milestone(0, "transcendence_ritual_ready"), -1, "sem Mana o runtime diz não")
	assert_eq(BalanceTelemetry.manifestation_gate(human), "ritual_blocked_mana")
	TurnManager.turn_number = 42
	human.mana = V2TranscendenceSystem.MANA_COST
	assert_true(V2TranscendenceSystem.can_start_ritual(human, city))
	telemetry.on_turn_end()
	assert_eq(telemetry.milestone(0, "transcendence_ritual_ready"), 42, "primeiro turno em que can_start_ritual é verdadeiro")
	assert_eq(float(telemetry.civs[0].mana_at_ritual_ready), V2TranscendenceSystem.MANA_COST)
	telemetry.finish({"timeout": false})

# --- Fim de partida ----------------------------------------------------------------------------

func test_end_reason_classification_covers_every_outcome():
	var cases := [
		[{"winner_index": 1, "victory_type": VictoryConditions.VICTORY_TYPE_DOMINANCE}, true, 150, "DOMINATION"],
		[{"winner_index": 2, "victory_type": V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY}, true, 170, "MILITARY_SUPREMACY"],
		[{"winner_index": 0, "victory_type": V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE}, true, 180, "TRANSCENDENCE"],
		[{}, false, 240, "TIMEOUT"],
		[{}, true, 120, "UNKNOWN_END_REASON"],
		[{"winner_index": 1, "victory_type": VictoryConditions.VICTORY_TYPE_DEBUG}, true, 90, "UNKNOWN_END_REASON"],
		[{"winner_index": -1, "victory_type": V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE}, true, 90, "UNKNOWN_END_REASON"],
		[{}, false, 100, "UNKNOWN_END_REASON"],
	]
	for entry in cases:
		var result := BalanceMatchRunner.classify_end(entry[0], entry[1], entry[2], 240)
		assert_eq(result.end_reason, entry[3], "fim %s" % str(entry))
		assert_eq(bool(result.timeout), entry[3] == "TIMEOUT")

# --- Reset entre partidas / smoke determinístico -----------------------------------------------

func test_batch_reset_leaves_no_state_for_the_next_match():
	var first_grid := BalanceMatchRunner.setup_match(self, _small_config(0))
	var first_players := GameManager.players.duplicate()
	for step in 3:
		TurnManager.end_turn()
	await BalanceMatchRunner.teardown_match(self, first_grid)
	assert_true(GameManager.players.is_empty(), "players limpos")
	assert_true(GameManager.rival_players.is_empty())
	assert_null(GameManager.human_player)
	assert_false(GameManager.ai_controls_human_seat, "fixture desligada após a partida")
	assert_eq(GameManager.state, GameManager.GameState.MENU)
	assert_true(WorldEventManager.active_events.is_empty(), "eventos limpos")
	assert_true(V2AITacticalAI._turn_views.is_empty(), "cache tático limpo")
	for player in first_players:
		assert_true(player.enemies.is_empty() and player.war_campaigns.is_empty(), "relações liberadas")
	var second_grid := BalanceMatchRunner.setup_match(self, _small_config(1))
	assert_eq(TurnManager.turn_number, 1, "a próxima partida começa no T1")
	for player in GameManager.players:
		assert_false(player in first_players, "PlayerData novo")
		assert_eq(player.v2_research.completed_ids.size(), 0, "pesquisa não é herdada")
		assert_true(player.v2_transcendence_ritual.is_empty(), "ritual não é herdado")
		assert_true(player.enemies.is_empty(), "guerras não são herdadas")
	assert_true(second_grid.v2_portal_pairs.is_empty(), "portais não são herdados")
	await BalanceMatchRunner.teardown_match(self, second_grid)

func test_quick_four_ai_smoke_is_deterministic():
	var config := _small_config(2)
	var first: Dictionary = await BalanceMatchRunner.run_match(self, config)
	var second: Dictionary = await BalanceMatchRunner.run_match(self, config)
	assert_eq(first.civs.size(), 4, "quatro civilizações observadas")
	assert_eq(first.end.end_reason, "TIMEOUT", "smoke curto termina pelo cap")
	assert_eq(int(first.end.turn), SMOKE_TURNS)
	for index in 4:
		var a: Dictionary = first.civs[index]
		var b: Dictionary = second.civs[index]
		assert_gt(int(a.city_turns), 0, "assento %d recebeu turnos" % index)
		assert_eq(a.milestones, b.milestones, "marcos idênticos (assento %d)" % index)
		assert_eq(a.series, b.series, "séries idênticas (assento %d)" % index)
		assert_eq(a.final_gold, b.final_gold)
		assert_eq(a.production_turns, b.production_turns)
	assert_eq(first.geography, second.geography)
