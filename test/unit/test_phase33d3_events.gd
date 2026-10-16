extends GutTest

## Fase 33D3 — grande evento da Ascensão: agendamento/garantia/alvo/participação/recompensa/UI do Dragão, save e
## migração v23. O Relicário Desperto, que também era testado aqui, foi removido do jogo em 2026-10-12; sobrou só a
## garantia de que um save que ainda o traga carrega sem ele.

const SAVE_PATH := "user://test_phase33d3_events.json"
const SMALL_MAP := 61
const ASC := 40

var _original := {}
var grid: HexGrid
var players: Array[PlayerData] = []
var _real_grid: HexGrid
var _published: Array = []
var _capture_callable: Callable

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	_published.clear()
	_capture_callable = func(event: UIEventData): _published.append(event)
	UIEvents.event_published.connect(_capture_callable)

func after_each():
	if UIEvents.event_published.is_connected(_capture_callable):
		UIEvents.event_published.disconnect(_capture_callable)
	if _real_grid != null and is_instance_valid(_real_grid):
		await BalanceMatchRunner.teardown_match(self, _real_grid)
	_real_grid = null
	V2AITacticalAI.clear_views()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

## Mundo manual com 4 civs; `cities_per_civ[i]` cidades para a civ i. Ascensão desde o turno ASC.
func _world(cities_per_civ: Array = [2, 2, 2, 2], map_seed: int = 1) -> void:
	grid = HexGrid.new()
	grid._ready()
	grid.map_seed = map_seed
	for q in range(-22, 23):
		for r in range(-22, 23):
			if absi(q + r) <= 22:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	players = [_player("Aurora"), _player("Brasa"), _player("Cinza"), _player("Dunas")] as Array[PlayerData]
	GameManager.players = players
	GameManager.human_player = players[0]
	GameManager.rival_players = [players[1], players[2], players[3]] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.ai_controls_human_seat = true
	var anchors := [Vector2i(-16, 0), Vector2i(16, 0), Vector2i(0, -16), Vector2i(0, 16)]
	for index in players.size():
		for n in int(cities_per_civ[index]):
			grid.found_city(anchors[index] + Vector2i(0, 5 * n) * (1 if anchors[index].y <= 0 else -1), players[index], "C%d-%d" % [index, n], true)
	WorldEventManager.reset_for_new_match(1)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": ASC, "cause": "PROGRESS"})

func _seed_where(predicate: Callable) -> int:
	for candidate in range(1, 5000):
		if predicate.call(candidate):
			return candidate
	return -1

func _dragon() -> DragonEvent:
	return WorldEventManager.active_event_of_type(DragonEvent.EVENT_TYPE) as DragonEvent

func _round(turn: int) -> void:
	TurnManager.turn_number = turn
	WorldEventManager.maybe_spawn_dragon(grid, turn)
	WorldEventManager.advance_turn(grid, players)

# --- Dragão: agendamento ---------------------------------------------------------------------------

func test_dragon_only_starts_in_ascension_after_ten_rounds():
	var hit_at := func(turn: int) -> Callable: return func(s: int) -> bool: return WorldEventTrigger.should_spawn_dragon(s, turn)
	var seed_early := _seed_where(hit_at.call(ASC + 9))
	_world([2, 2, 2, 2], seed_early)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 40)
	assert_null(_dragon(), "Despertar: impossível, mesmo depois da garantia")
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 9)
	assert_null(_dragon(), "Ascensão+9: impossível mesmo com o gatilho sorteado")
	assert_eq(int(WorldEventManager.dragon_schedule.eligible_turn), ASC + 10)
	var seed_ten := _seed_where(hit_at.call(ASC + 10))
	grid.map_seed = seed_ten
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 10)
	assert_not_null(_dragon(), "Ascensão+10: elegível e o gatilho 2% existente decide")
	assert_false(bool(WorldEventManager.dragon_schedule.forced))
	assert_almost_eq(WorldEventTrigger.DRAGON_TRIGGER_CHANCE_PER_TURN, 0.02, 0.0001, "gatilho preservado")

func test_dragon_is_guaranteed_at_ascension_plus_35_without_rng():
	var no_hit := func(s: int) -> bool:
		for turn in range(ASC + 10, ASC + DRAGON_GUARANTEE()):
			if WorldEventTrigger.should_spawn_dragon(s, turn):
				return false
		return true
	_world([2, 2, 2, 2], _seed_where(no_hit))
	for turn in range(ASC + 10, ASC + DRAGON_GUARANTEE()):
		WorldEventManager.maybe_spawn_dragon(grid, turn)
	assert_null(_dragon(), "sem sorteio, nada antes da garantia")
	WorldEventManager.maybe_spawn_dragon(grid, ASC + DRAGON_GUARANTEE())
	assert_not_null(_dragon(), "garantido na primeira oportunidade válida")
	assert_true(bool(WorldEventManager.dragon_schedule.forced))
	assert_eq(int(WorldEventManager.dragon_schedule.announce_turn), ASC + DRAGON_GUARANTEE())

func DRAGON_GUARANTEE() -> int:
	return WorldEventManager.DRAGON_GUARANTEE_AFTER

func test_convergence_edge_announces_the_dragon_in_the_transition_round():
	var no_hit := func(s: int) -> bool:
		for turn in range(ASC + 10, ASC + 30):
			if WorldEventTrigger.should_spawn_dragon(s, turn):
				return false
		return true
	_world([2, 2, 2, 2], _seed_where(no_hit))
	TurnManager.turn_number = WorldPhaseRules.CONVERGENCE_FALLBACK_TURN
	var changed := WorldEventManager.advance_world_phase(players, WorldPhaseRules.CONVERGENCE_FALLBACK_TURN)
	assert_true(changed)
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.CONVERGENCE)
	var dragon := _dragon()
	assert_not_null(dragon, "Dragão nunca ocorrido é garantido na virada")
	assert_eq(dragon.phase, WorldEvent.PHASE_ANNOUNCED, "anunciado na MESMA rodada da transição")
	assert_true(bool(WorldEventManager.dragon_schedule.convergence_edge))
	dragon.advance_turn(grid, players)
	assert_eq(dragon.phase, WorldEvent.PHASE_PREPARATION, "segue ativo na Convergência")

func test_convergence_without_valid_target_supersedes_the_dragon():
	_world([1, 1, 1, 1])
	TurnManager.turn_number = WorldPhaseRules.CONVERGENCE_FALLBACK_TURN
	WorldEventManager.advance_world_phase(players, WorldPhaseRules.CONVERGENCE_FALLBACK_TURN)
	assert_null(_dragon())
	assert_eq(String(WorldEventManager.dragon_schedule.state), WorldEventManager.SCHEDULE_SUPERSEDED)
	assert_eq(String(WorldEventManager.dragon_schedule.superseded_reason), "NO_VALID_TARGET")
	WorldEventManager.maybe_spawn_dragon(grid, 400)
	assert_null(_dragon(), "nunca começa na Convergência")

func test_dragon_never_targets_a_one_city_civilization_and_defers_without_targets():
	_world([1, 1, 1, 1])
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 40)
	assert_null(_dragon(), "todas com uma cidade: adia")
	assert_gt(int(WorldEventManager.dragon_schedule.target_deferred_rounds), 0)
	grid.found_city(Vector2i(16, 8), players[1], "Extra", true)
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 41)
	var dragon := _dragon()
	assert_not_null(dragon)
	dragon.origin_region = Vector2i(-16, 0) # ao lado da civ 0 (uma cidade só)
	dragon.phase = WorldEvent.PHASE_ANNOUNCED
	dragon.advance_turn(grid, players)
	assert_eq(dragon.target_civ_index, 1, "a civ de uma cidade nunca é alvo; a elegível é")
	assert_eq(DragonEvent.eligible_target_indices(players), [1])

func test_resolved_dragon_never_returns():
	_world()
	WorldEventManager.maybe_spawn_dragon(grid, ASC + DRAGON_GUARANTEE())
	var dragon := _dragon()
	dragon._resolve_with_outcome("defeated")
	dragon.phase = WorldEvent.PHASE_RESOLUTION
	WorldEventManager.advance_turn(grid, players)
	assert_null(_dragon())
	for turn in range(ASC + 36, ASC + 90):
		WorldEventManager.maybe_spawn_dragon(grid, turn)
	assert_null(_dragon(), "ONCE_PER_GAME (D1) preservado")

# --- Dragão: participação --------------------------------------------------------------------------

func _preparing_dragon(origin: Vector2i, target: int) -> DragonEvent:
	var dragon := DragonEvent.new()
	dragon.origin_region = origin
	dragon.target_civ_index = target
	dragon.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(dragon)
	return dragon

func test_ai_participation_is_a_decision_not_automatic():
	_world()
	var dragon := _preparing_dragon(Vector2i(10, 0), 1)
	# Alvo: sempre defende.
	RivalAI.decide_world_event_participation(players[1], 1, dragon)
	assert_true(bool(dragon.participants[1].decision))
	# Longe e sem força: recusa.
	RivalAI.decide_world_event_participation(players[2], 2, dragon)
	assert_false(bool(dragon.participants[2].decision), "civ fraca/remota recusa")
	# Perto e com força livre: aceita.
	for offset in [Vector2i(2, 0), Vector2i(3, 0)]:
		grid.spawn_unit(Vector2i(0, 0) + offset, UnitDatabase.create_unit("warrior"), players[3])
	grid.found_city(Vector2i(4, 4), players[3], "Perto", true)
	V2AITacticalAI.clear_views()
	RivalAI.decide_world_event_participation(players[3], 3, dragon)
	assert_true(bool(dragon.participants[3].decision), "força livre perto pode aceitar")
	# Perdendo guerra (inimigo em guerra junto às cidades): recusa, mesmo com força.
	for offset in [Vector2i(-12, 1), Vector2i(-12, 2)]:
		grid.spawn_unit(offset, UnitDatabase.create_unit("warrior"), players[0])
	Diplomacy.declare_war(players[1], players[0], "Teste", true)
	grid.spawn_unit(Vector2i(-15, 1), UnitDatabase.create_unit("warrior"), players[1])
	V2AITacticalAI.clear_views()
	RivalAI.decide_world_event_participation(players[0], 0, dragon)
	assert_false(bool(dragon.participants[0].decision), "guerra defensiva: recusa")
	assert_eq(String(dragon.participants[0].reason), "war_pressure")

# --- Dragão: recompensa ----------------------------------------------------------------------------

func test_dragon_reward_pool_splits():
	assert_eq(DragonEvent.split_pool({2: 10.0}, 175, 15), {2: 175}, "1 participante: pool inteiro")
	var two := DragonEvent.split_pool({0: 30.0, 1: 10.0}, 175, 15)
	assert_eq(int(two[0]) + int(two[1]), 175)
	assert_gte(int(two[1]), 15, "piso")
	assert_gt(int(two[0]), int(two[1]), "resto pelo dano")
	var four := DragonEvent.split_pool({0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0}, 80, 5)
	var total := 0
	for civ in four:
		total += int(four[civ])
	assert_eq(total, 80)
	assert_eq(four, {0: 20, 1: 20, 2: 20, 3: 20}, "arredondamento determinístico")
	var odd := DragonEvent.split_pool({0: 1.0, 1: 1.0, 2: 1.0}, 175, 15)
	assert_eq(odd, {0: 59, 1: 58, 2: 58}, "sobra pelo menor índice no empate")
	assert_true(DragonEvent.split_pool({}, 175, 15).is_empty(), "sem dano, sem recompensa")

func test_dragon_rewards_apply_once_and_only_to_damage_dealers():
	_world()
	var dragon := _preparing_dragon(Vector2i(10, 0), 1)
	dragon.damage_by_civ = {1: 30.0, 2: 10.0, 3: 0.0}
	dragon._resolve_with_outcome("defeated")
	var gold := players.map(func(p): return p.gold)
	var mana := players.map(func(p): return p.mana)
	dragon.award_contribution_rewards(players)
	dragon.award_contribution_rewards(players)
	var gained_gold := 0.0
	var gained_mana := 0.0
	for index in players.size():
		gained_gold += players[index].gold - gold[index]
		gained_mana += players[index].mana - mana[index]
	assert_almost_eq(gained_gold, 175.0, 0.001)
	assert_almost_eq(gained_mana, 80.0, 0.001)
	assert_almost_eq(players[3].gold, gold[3], 0.001, "sem dano: nada")
	assert_almost_eq(players[0].gold, gold[0], 0.001)

func test_dragon_resolution_goes_to_the_event_center_without_a_modal():
	_world()
	var dragon := _preparing_dragon(Vector2i(10, 0), 1)
	dragon.damage_by_civ = {1: 20.0}
	dragon._resolve_with_outcome("defeated")
	dragon.award_contribution_rewards(players)
	EventBus.world_event_phase_changed.emit(dragon, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)
	var resolved := _published.filter(func(e): return e.event_type == "dragon_resolved")
	assert_eq(resolved.size(), 1)
	assert_eq(resolved[0].title, "O Dragão foi derrotado")
	assert_true(resolved[0].message.contains("+175 ouro"), "resumo de contribuição")
	var hud := FileAccess.get_file_as_string("res://scripts/ui/HUD.gd")
	assert_false(hud.contains("_show_overlay(dragon_resolution_panel)"), "nenhum modal bloqueante de resultado")
	for event in _published:
		assert_false(String(event.title + event.message).contains("DragonEvent"), "sem nome de classe")

func test_the_dragon_never_creates_an_attention_item():
	var source := FileAccess.get_file_as_string("res://scripts/ui/AttentionService.gd")
	assert_false(source.contains("world_event_decision") or source.contains("\"world_event\""), "o jogador não é perguntado sobre o Dragão: nenhum item de decisão")
	assert_false(source.contains("StrategicImperatives") or source.contains("PublicVictoryMilestones"), "imperativos e marcos nunca viram Attention")

# --- Persistência -----------------------------------------------------------------------------------

func _small_match(index: int = 1) -> HexGrid:
	var config := BalanceSeedSet.match_config(index, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	_real_grid = BalanceMatchRunner.setup_match(self, config)
	grid = null
	players = GameManager.players
	return _real_grid

## Segunda cidade para cada civ (alvo elegível do Dragão), num tile livre perto da capital.
func _ensure_two_cities() -> void:
	for index in players.size():
		if players[index].cities.size() >= 2 or players[index].cities.is_empty():
			continue
		var capital: Vector2i = players[index].cities[0].coord
		for coord in RegionalThreatPlanner._sorted(HexMetrics.coords_within(capital, 7)):
			if HexMetrics.axial_distance(capital, coord) >= 5 and CitySite.rejection_reason(_real_grid, coord, players[index]) == "" and _real_grid.get_unit_at(coord) == null:
				_real_grid.found_city(coord, players[index], "Extra %d" % index, true)
				break

static func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func _event_snapshot() -> Dictionary:
	var events: Array = []
	for event in WorldEventManager.active_events:
		events.append(event.to_save_dict())
	return {"events": _norm(events), "dragon": _norm(WorldEventManager.dragon_schedule), "milestones": _norm(WorldEventManager.public_milestones)}

func _reload() -> Dictionary:
	var before := _event_snapshot()
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH))
	players = GameManager.players
	return before

func test_dragon_state_survives_save_and_load_in_every_phase():
	_small_match()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": ASC, "cause": "PROGRESS"})
	_ensure_two_cities()
	TurnManager.turn_number = ASC + DRAGON_GUARANTEE()
	WorldEventManager.maybe_spawn_dragon(_real_grid, TurnManager.turn_number)
	WorldEventManager.advance_turn(_real_grid, players) # anunciado
	TurnManager.turn_number += 1
	WorldEventManager.advance_turn(_real_grid, players) # preparação
	assert_eq(_dragon().phase, WorldEvent.PHASE_PREPARATION)
	var before := _reload()
	assert_eq(_event_snapshot(), before, "Dragão em preparação idêntico")
	TurnManager.turn_number = _dragon().turn_deadline + 1
	WorldEventManager.advance_turn(_real_grid, players) # ativo
	assert_eq(_dragon().phase, WorldEvent.PHASE_ACTIVE)
	var neutral := _real_grid.neutral_units().size()
	before = _reload()
	assert_eq(_event_snapshot(), before, "Dragão ativo idêntico")
	assert_eq(_real_grid.neutral_units().size(), neutral, "sem Dragão duplicado")
	_dragon()._resolve_with_outcome("defeated")
	WorldEventManager.advance_turn(_real_grid, players)
	before = _reload()
	assert_null(_dragon(), "resolvido não volta")
	assert_eq(String(WorldEventManager.dragon_schedule.state), WorldEventManager.SCHEDULE_RESOLVED)
	assert_false(WorldEventManager.can_start_event_type(DragonEvent.EVENT_TYPE), "uma vez por partida")

## O Relicário Desperto foi removido do jogo (WorldEventManager.RETIRED_EVENT_TYPES). Um save que ainda o traga —
## evento ativo, agendador e guardiões no mapa — carrega normalmente, sem o evento e sem os guardiões dele; o resto
## do save (os outros monstros, o Dragão) não muda.
func test_a_save_with_the_retired_reliquary_loads_without_the_event_and_its_guardians():
	_small_match()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": ASC, "cause": "PROGRESS"})
	TurnManager.turn_number = ASC + 20
	var neutral_before := _real_grid.neutral_units().size()
	assert_gt(neutral_before, 1, "pré-condição: há monstros no mapa")
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	# Como o save ficava com o Relicário ATIVO: o evento, o agendador dele e um guardião ligado ao evento.
	data.world_events.events.append({"event_type": "reliquary", "event_id": 7, "phase": "active", "turn_started": ASC + 15, "turn_deadline": ASC + 30,
		"participants": {}, "result": {}, "site_coord": [0, 0], "control_owner": -1, "control_rounds": 0, "winner_index": -1, "reward_choice": ""})
	data.world_events["reliquary_schedule"] = {"state": "ANNOUNCED", "announce_turn": ASC + 15, "site": [0, 0]}
	data.world_events["next_event_id"] = 8
	var guardian: Dictionary = data.neutral_units[0]
	guardian["source_event"] = 7
	var guardian_coord := Vector2i(int(guardian.coord[0]), int(guardian.coord[1]))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	WorldEventManager.reset_for_new_match()

	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH), "o save com o evento removido continua carregando")

	assert_true(WorldEventManager.active_events.is_empty(), "o Relicário não volta")
	assert_null(_real_grid.get_unit_at(guardian_coord), "o guardião do evento some com ele")
	assert_eq(_real_grid.neutral_units().size(), neutral_before - 1, "os outros monstros do save continuam")
	assert_eq(WorldEventManager._next_event_id, 8, "o contador de eventos do save é respeitado")
	assert_false(WorldEventManager.has_active_major_event())
	# A partida segue: o Dragão continua agendável e o save seguinte não traz mais nada do Relicário.
	players = GameManager.players
	_ensure_two_cities()
	WorldEventManager.maybe_spawn_dragon(_real_grid, ASC + DRAGON_GUARANTEE())
	assert_not_null(_dragon(), "o Dragão não é barrado por um evento que não existe mais")
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	var resaved := FileAccess.get_file_as_string(SAVE_PATH)
	assert_false(resaved.contains("reliquary") or resaved.contains("source_event"), "nada do Relicário é regravado")

func test_v23_save_loads_and_schedulers_start_only_on_the_next_round():
	_small_match(2)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": 1, "cause": "PROGRESS"})
	_ensure_two_cities()
	TurnManager.turn_number = 80
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data.version = 23
	for key in ["dragon_schedule", "public_milestones"]:
		data.world_events.erase(key)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH), "save v23 carrega")
	assert_true(WorldEventManager.active_events.is_empty(), "nada nasce dentro do load")
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.ASCENSION, "era preservada")
	assert_false(WorldEventManager.regional_threats.is_empty(), "ameaças regionais preservadas")
	assert_true(WorldEventManager.dragon_schedule.is_empty())
	WorldEventManager.maybe_spawn_dragon(_real_grid, 80)
	assert_not_null(_dragon(), "agendador age no próximo round, pela idade real da Ascensão (garantia já vencida)")

# --- Custo ------------------------------------------------------------------------------------------

func test_d3_systems_cost_nothing_per_frame_and_little_per_round():
	_real_grid = BalanceMatchRunner.setup_match(self, BalanceSeedSet.match_config(0))
	players = GameManager.players
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": 1, "cause": "PROGRESS"})
	for player in players:
		for other in players:
			if other != player:
				player.remember_enemy_city(other.cities[0])
	var view := V2AIWorldView.capture(players[1], _real_grid)
	var started := Time.get_ticks_usec()
	for i in 200:
		V2StrategicAI.strategic_target_coord(players[1], view)
	var ai_us := (Time.get_ticks_usec() - started) / 200
	started = Time.get_ticks_usec()
	for i in 100:
		for player in players:
			StrategicImperatives.for_player(player, _real_grid)
	var imperative_us := (Time.get_ticks_usec() - started) / 100
	started = Time.get_ticks_usec()
	for turn in range(2, 102):
		WorldEventManager.maybe_spawn_dragon(_real_grid, turn)
		PublicVictoryMilestones.evaluate_round(players, turn)
	var round_us := (Time.get_ticks_usec() - started) / 100
	gut.p("[D3 perf] AI strategic target=%d us/call | imperatives (4 civs)=%d us | milestones+scheduler=%d us/round" % [ai_us, imperative_us, round_us])
	assert_lt(ai_us, 5000)
	assert_lt(imperative_us, 5000)
	assert_lt(round_us, 2000)
	for path in ["res://scripts/core/StrategicImperatives.gd", "res://scripts/core/PublicVictoryMilestones.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("func _process"), "zero custo por frame: %s" % path)
