extends GutTest

## Fase 33D3 — grandes eventos da Ascensão: agendamento/garantia/alvo/participação/recompensa/UI do Dragão,
## Relicário Desperto (agendamento, supersessão, local justo, guardiões, disputa, recompensa, save), exclusividade
## e migração v23.

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
	for event in WorldEventManager.active_events:
		if event is ReliquaryEvent:
			(event as ReliquaryEvent)._remove_marker()
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

func _reliquary() -> ReliquaryEvent:
	return WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE) as ReliquaryEvent

func _round(turn: int) -> void:
	TurnManager.turn_number = turn
	WorldEventManager.maybe_spawn_dragon(grid, turn)
	WorldEventManager.maybe_start_reliquary(grid, turn)
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

func test_optional_participation_is_not_required_attention():
	var source := FileAccess.get_file_as_string("res://scripts/ui/AttentionService.gd")
	assert_false(source.contains("\"world_event_decision:%s\" % stable_id, AttentionItem.Priority.REQUIRED"), "participação opcional nunca bloqueia o fim de turno")
	assert_false(source.contains("StrategicImperatives") or source.contains("PublicVictoryMilestones"), "imperativos e marcos nunca viram Attention")

# --- Relicário: agendamento -------------------------------------------------------------------------

func test_reliquary_scheduler_respects_era_eligibility_and_dragon_priority():
	_world()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	WorldEventManager.maybe_start_reliquary(grid, ASC + 20)
	assert_null(_reliquary(), "Despertar: não")
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.maybe_start_reliquary(grid, ASC + 14)
	assert_null(_reliquary(), "antes de +15: não")
	# Dragão ativo: pendente.
	WorldEventManager.maybe_spawn_dragon(grid, ASC + DRAGON_GUARANTEE())
	var dragon := _dragon()
	WorldEventManager.maybe_start_reliquary(grid, ASC + 36)
	assert_null(_reliquary(), "Dragão ativo: PENDING")
	assert_eq(String(WorldEventManager.reliquary_schedule.state), WorldEventManager.SCHEDULE_PENDING)
	dragon._resolve_with_outcome("defeated")
	TurnManager.turn_number = ASC + 40
	WorldEventManager.advance_turn(grid, players)
	assert_null(_dragon())
	for turn in range(ASC + 40, ASC + 45):
		WorldEventManager.maybe_start_reliquary(grid, turn)
		assert_null(_reliquary(), "espera %d rodadas depois do Dragão" % WorldEventManager.RELIQUARY_AFTER_DRAGON)
	WorldEventManager.maybe_start_reliquary(grid, ASC + 45)
	assert_not_null(_reliquary(), "anunciado depois da espera")
	WorldEventManager.maybe_spawn_dragon(grid, ASC + 90)
	assert_null(_dragon(), "nunca Dragão + Relicário ativos juntos")

func test_early_reliquary_only_when_it_ends_before_the_dragon_guarantee():
	var no_hit := func(s: int) -> bool:
		for turn in range(ASC + 10, ASC + 17):
			if WorldEventTrigger.should_spawn_dragon(s, turn):
				return false
		return true
	_world([2, 2, 2, 2], _seed_where(no_hit))
	for turn in range(ASC + 10, ASC + 15):
		WorldEventManager.maybe_spawn_dragon(grid, turn)
	WorldEventManager.maybe_start_reliquary(grid, ASC + 15)
	var reliquary := _reliquary()
	assert_not_null(reliquary, "+15 com o Dragão ainda por vir: cabe antes da garantia")
	assert_lt(ASC + 15 + ReliquaryEvent.MAX_DURATION, ASC + DRAGON_GUARANTEE(), "duração máxima termina antes da garantia")
	# Simula a partida: o Relicário expira sem vencedor; a garantia do Dragão nunca é adiada.
	for turn in range(ASC + 15, ASC + DRAGON_GUARANTEE() + 1):
		_round(turn)
	assert_null(_reliquary(), "expirou dentro da janela")
	assert_not_null(_dragon(), "Dragão garantido no prazo")
	assert_true(WorldEventManager.can_start_event_type(ReliquaryEvent.EVENT_TYPE) == false, "Relicário uma vez por partida")

func test_reliquary_is_superseded_by_convergence_before_announcement():
	_world()
	WorldEventManager.maybe_spawn_dragon(grid, ASC + DRAGON_GUARANTEE())
	WorldEventManager.maybe_start_reliquary(grid, ASC + 36)
	assert_eq(String(WorldEventManager.reliquary_schedule.state), WorldEventManager.SCHEDULE_PENDING)
	TurnManager.turn_number = WorldPhaseRules.CONVERGENCE_FALLBACK_TURN
	WorldEventManager.advance_world_phase(players, WorldPhaseRules.CONVERGENCE_FALLBACK_TURN)
	assert_eq(String(WorldEventManager.reliquary_schedule.state), WorldEventManager.SCHEDULE_SUPERSEDED)
	_dragon()._resolve_with_outcome("defeated")
	WorldEventManager.advance_turn(grid, players)
	for turn in range(WorldPhaseRules.CONVERGENCE_FALLBACK_TURN, WorldPhaseRules.CONVERGENCE_FALLBACK_TURN + 20):
		WorldEventManager.maybe_start_reliquary(grid, turn)
	assert_null(_reliquary(), "nunca nasce na Convergência; sem local nem recompensa")

# --- Relicário: local -------------------------------------------------------------------------------

func test_reliquary_site_is_valid_fair_and_deterministic():
	_world()
	var site := ReliquaryEvent.choose_site(grid, players)
	assert_ne(site, ReliquaryEvent.NO_COORD)
	assert_true(ReliquaryEvent.is_valid_site(grid, site))
	assert_null(grid.city_owning_tile(site))
	var nearest: Array = []
	for player in players:
		var best := 999999
		for city in player.cities:
			best = mini(best, HexMetrics.axial_distance(city.coord, site))
		nearest.append(best)
	nearest.sort()
	assert_gte(int(nearest[0]), ReliquaryEvent.SITE_MIN_CITY_DISTANCE, "fora do interior imediato de um reino")
	assert_lte(absi(int(nearest[1]) - int(nearest[0])), 1, "distância competitiva para as duas civs mais próximas")
	assert_eq(ReliquaryEvent.choose_site(grid, players), site, "determinístico")
	# Terreno de melhoria/território/covil nunca é local.
	grid.create_lair(site, "goblin", HexGrid.LAIR_ROLE_WILD)
	assert_ne(ReliquaryEvent.choose_site(grid, players), site)

# --- Relicário: guardiões e disputa -----------------------------------------------------------------

func _active_reliquary() -> ReliquaryEvent:
	var reliquary := ReliquaryEvent.new()
	reliquary.site_coord = Vector2i(0, 0)
	WorldEventManager.register_event(reliquary)
	TurnManager.turn_number = ASC + 20
	reliquary.advance_turn(grid, players) # anunciado
	TurnManager.turn_number = reliquary.turn_deadline
	reliquary.advance_turn(grid, players) # ativo
	return reliquary

func _clear_guardians(reliquary: ReliquaryEvent) -> void:
	for unit in grid.units_by_coord.values().duplicate():
		if unit.source_event_id == reliquary.event_id:
			grid.remove_unit(unit)

func test_guardians_are_real_and_must_die_before_progress():
	_world()
	var reliquary := _active_reliquary()
	assert_eq(reliquary.phase, WorldEvent.PHASE_ACTIVE)
	assert_eq(reliquary.live_guardian_count(grid), ReliquaryEvent.GUARDIAN_COUNT)
	for unit in grid.units_by_coord.values():
		if unit.source_event_id == reliquary.event_id:
			assert_eq(unit.unit_data.visual_kind, "skeleton", "monstro existente, stats intactos")
			assert_false(grid.lair_roles.has(unit.source_lair_coord), "fora do sistema de covil")
	var claimant := grid.spawn_unit(Vector2i(2, 2), UnitDatabase.create_unit("warrior"), players[0])
	reliquary.evaluate_control(grid, players, 70)
	assert_eq(reliquary.control_rounds, 0, "guardião vivo: sem progresso")
	_clear_guardians(reliquary)
	grid.move_unit(claimant, Vector2i(0, 0), 0.0)
	reliquary.evaluate_control(grid, players, 71)
	assert_eq(reliquary.control_rounds, 1)
	assert_eq(reliquary.guardians_cleared_turn, 71)

func test_two_consecutive_rounds_resolve_and_the_reward_is_applied_once():
	_world()
	players[0].v2_ai_strategy.orientation = V2AIStrategyState.Orientation.MILITARY
	players[0].mana = 500.0
	var reliquary := _active_reliquary()
	_clear_guardians(reliquary)
	grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), players[0])
	grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), players[0])
	var gold := players[0].gold
	reliquary.evaluate_control(grid, players, 70)
	assert_eq(reliquary.control_rounds, 1, "rodada 1 → 1/2 (mais unidades não aceleram)")
	reliquary.evaluate_control(grid, players, 71)
	assert_eq(reliquary.phase, WorldEvent.PHASE_RESOLUTION, "rodada 2 → resolvido")
	assert_eq(reliquary.winner_index, 0)
	assert_eq(reliquary.reward_choice, ReliquaryEvent.CHOICE_GOLD, "IA com Mana de sobra e não Arcana escolhe Ouro")
	assert_almost_eq(players[0].gold - gold, ReliquaryEvent.REWARD_GOLD, 0.001)
	assert_false(reliquary.apply_reward(players, ReliquaryEvent.CHOICE_MANA), "exatamente uma vez")
	assert_eq(ReliquaryEvent.ai_reward_choice(_arcane()), ReliquaryEvent.CHOICE_MANA, "Arcana prefere Mana")

func _arcane() -> PlayerData:
	var arcane := _player("Arcana")
	arcane.v2_ai_strategy.orientation = V2AIStrategyState.Orientation.ARCANE
	arcane.mana = 500.0
	return arcane

func test_hostile_adjacent_contests_and_switching_restarts_the_count():
	_world()
	var reliquary := _active_reliquary()
	_clear_guardians(reliquary)
	var a := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), players[0])
	reliquary.evaluate_control(grid, players, 70)
	assert_eq([reliquary.control_owner, reliquary.control_rounds], [0, 1])
	Diplomacy.declare_war(players[0], players[1], "Teste", true)
	var b := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), players[1])
	reliquary.evaluate_control(grid, players, 71)
	assert_eq(reliquary.control_rounds, 0, "hostil adjacente: zera")
	assert_eq(reliquary.contested_rounds, 1)
	grid.remove_unit(a)
	grid.move_unit(b, Vector2i(0, 0), 0.0)
	reliquary.evaluate_control(grid, players, 72)
	assert_eq([reliquary.control_owner, reliquary.control_rounds], [1, 1], "B começa em 1/2")
	grid.remove_unit(b)
	reliquary.evaluate_control(grid, players, 73)
	assert_eq(reliquary.control_rounds, 0, "ninguém no local: sem progresso")

func test_human_reward_choice_uses_the_existing_decision_path():
	_world()
	GameManager.ai_controls_human_seat = false
	var reliquary := _active_reliquary()
	_clear_guardians(reliquary)
	grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), players[0])
	reliquary.evaluate_control(grid, players, 70)
	reliquary.evaluate_control(grid, players, 71)
	assert_true(reliquary.awaiting_choice_from(0), "pessoa escolhe")
	var mana := players[0].mana
	assert_true(WorldEventManager.choose_reliquary_reward(players[0], ReliquaryEvent.CHOICE_MANA))
	assert_almost_eq(players[0].mana - mana, ReliquaryEvent.REWARD_MANA, 0.001)
	assert_false(WorldEventManager.choose_reliquary_reward(players[0], ReliquaryEvent.CHOICE_GOLD), "uma vez")
	assert_false(FileAccess.get_file_as_string("res://scripts/ui/AttentionService.gd").contains("\"world_event_reward:%d\" % event.event_id, AttentionItem.Priority.REQUIRED"), "escolha não bloqueia o fim de turno")

func test_unchosen_human_reward_defaults_to_gold_after_the_window():
	_world()
	GameManager.ai_controls_human_seat = false
	var reliquary := _active_reliquary()
	_clear_guardians(reliquary)
	grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), players[0])
	reliquary.evaluate_control(grid, players, 70)
	reliquary.evaluate_control(grid, players, 71)
	var gold := players[0].gold
	TurnManager.turn_number = reliquary.choice_deadline
	reliquary.advance_turn(grid, players)
	assert_eq(reliquary.phase, WorldEvent.PHASE_COMPLETED)
	assert_almost_eq(players[0].gold - gold, ReliquaryEvent.REWARD_GOLD, 0.001)

func test_ai_decides_whether_to_answer_the_reliquary():
	_world()
	var reliquary := _active_reliquary()
	var view := V2AIWorldView.capture(players[1], grid)
	var plan := V2StrategicAI.reliquary_plan(players[1], view)
	assert_eq(String(plan.mode), "none", "sem força móvel: não vai")
	for offset in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 0), Vector2i(4, 1)]:
		grid.spawn_unit(offset, UnitDatabase.create_unit("warrior"), players[1])
	V2AITacticalAI.clear_views()
	view = V2AIWorldView.capture(players[1], grid)
	plan = V2StrategicAI.reliquary_plan(players[1], view)
	assert_eq(String(plan.mode), "go", "força livre perto: vai")
	assert_eq((plan.units as Array).size(), V2StrategicAI.RELIQUARY_MAX_RESPONDERS, "manda só uma força pequena")
	var mover: Unit = plan.units[0]
	var start := mover.coord
	assert_true(StrategicAI.respond_to_reliquary(mover, players[1], grid))
	assert_true(mover.coord != start or HexMetrics.axial_distance(mover.coord, reliquary.site_coord) <= 1, "anda ou luta, sem teleporte")

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
	var guardians: Array = []
	for unit in _real_grid.neutral_units():
		if unit.source_event_id >= 0:
			guardians.append([unit.coord, unit.source_event_id])
	guardians.sort()
	return {"events": _norm(events), "dragon": _norm(WorldEventManager.dragon_schedule), "reliquary": _norm(WorldEventManager.reliquary_schedule), "milestones": _norm(WorldEventManager.public_milestones), "guardians": guardians}

func _reload() -> Dictionary:
	var before := _event_snapshot()
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH))
	players = GameManager.players
	return before

func test_dragon_and_reliquary_state_survive_save_and_load_in_every_phase():
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
	# Relicário: preparação, ativo com guardiões, 1/2, resolvido.
	var site := ReliquaryEvent.choose_site(_real_grid, players)
	assert_ne(site, ReliquaryEvent.NO_COORD)
	var reliquary := ReliquaryEvent.new()
	reliquary.site_coord = site
	WorldEventManager.register_event(reliquary)
	WorldEventManager.advance_turn(_real_grid, players)
	before = _reload()
	assert_eq(_event_snapshot(), before, "Relicário em preparação")
	TurnManager.turn_number = _reliquary().turn_deadline
	WorldEventManager.advance_turn(_real_grid, players)
	assert_eq(_reliquary().live_guardian_count(_real_grid), ReliquaryEvent.GUARDIAN_COUNT)
	before = _reload()
	assert_eq(_event_snapshot(), before, "guardiões ligados ao evento após o load")
	assert_eq(_reliquary().live_guardian_count(_real_grid), ReliquaryEvent.GUARDIAN_COUNT)
	for unit in _real_grid.neutral_units():
		if unit.source_event_id == _reliquary().event_id:
			_real_grid.remove_unit(unit)
	_real_grid.spawn_unit(site, UnitDatabase.create_unit("warrior"), players[2])
	TurnManager.turn_number += 1
	WorldEventManager.advance_turn(_real_grid, players)
	assert_eq(_reliquary().control_rounds, 1)
	before = _reload()
	assert_eq(_reliquary().control_rounds, 1, "1/2 preservado")
	TurnManager.turn_number += 1
	WorldEventManager.advance_turn(_real_grid, players)
	assert_true(_reliquary() == null or _reliquary().phase in [WorldEvent.PHASE_RESOLUTION, WorldEvent.PHASE_COMPLETED])
	var gold := players[2].gold
	_reload()
	for turn in range(TurnManager.turn_number, TurnManager.turn_number + 6):
		TurnManager.turn_number = turn
		WorldEventManager.advance_turn(_real_grid, players)
	assert_almost_eq(players[2].gold, gold, 0.001, "recompensa não reaplicada depois do load")
	assert_false(WorldEventManager.can_start_event_type(ReliquaryEvent.EVENT_TYPE), "uma vez por partida")

func test_v23_save_loads_and_schedulers_start_only_on_the_next_round():
	_small_match(2)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": 1, "cause": "PROGRESS"})
	_ensure_two_cities()
	TurnManager.turn_number = 80
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data.version = 23
	for key in ["dragon_schedule", "reliquary_schedule", "public_milestones"]:
		data.world_events.erase(key)
	for unit in data.neutral_units:
		unit.erase("source_event")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH), "save v23 carrega")
	assert_true(WorldEventManager.active_events.is_empty(), "nada nasce dentro do load")
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.ASCENSION, "era preservada")
	assert_false(WorldEventManager.regional_threats.is_empty(), "ameaças regionais preservadas")
	assert_true(WorldEventManager.dragon_schedule.is_empty() and WorldEventManager.reliquary_schedule.is_empty())
	WorldEventManager.maybe_spawn_dragon(_real_grid, 80)
	assert_not_null(_dragon(), "agendador age no próximo round, pela idade real da Ascensão (garantia já vencida)")

# --- Custo ------------------------------------------------------------------------------------------

func test_d3_systems_cost_nothing_per_frame_and_little_per_round():
	_real_grid = BalanceMatchRunner.setup_match(self, BalanceSeedSet.match_config(0))
	players = GameManager.players
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": 1, "cause": "PROGRESS"})
	var started := Time.get_ticks_usec()
	var site := ReliquaryEvent.choose_site(_real_grid, players)
	var site_us := Time.get_ticks_usec() - started
	var reliquary := ReliquaryEvent.new()
	reliquary.site_coord = site
	WorldEventManager.register_event(reliquary)
	for player in players:
		for other in players:
			if other != player:
				player.remember_enemy_city(other.cities[0])
	var view := V2AIWorldView.capture(players[1], _real_grid)
	started = Time.get_ticks_usec()
	for i in 200:
		V2StrategicAI.reliquary_plan(players[1], view)
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
		WorldEventManager.maybe_start_reliquary(_real_grid, turn)
	var round_us := (Time.get_ticks_usec() - started) / 100
	gut.p("[D3 perf] reliquary site=%d us (once) | AI reliquary plan + strategic target=%d us/call | imperatives (4 civs)=%d us | milestones+scheduler=%d us/round" % [site_us, ai_us, imperative_us, round_us])
	assert_ne(site, ReliquaryEvent.NO_COORD)
	assert_lt(site_us, 1000000, "escolha rara do local")
	assert_lt(ai_us, 5000)
	assert_lt(imperative_us, 5000)
	assert_lt(round_us, 2000)
	for path in ["res://scripts/core/ReliquaryEvent.gd", "res://scripts/core/StrategicImperatives.gd", "res://scripts/core/PublicVictoryMilestones.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("func _process"), "zero custo por frame: %s" % path)
