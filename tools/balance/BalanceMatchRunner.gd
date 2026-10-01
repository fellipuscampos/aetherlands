class_name BalanceMatchRunner
extends RefCounted

## Fase 33B — executa UMA partida completa AI × AI × AI × AI pelo pipeline real do jogo:
## HexGrid.generate_map (mapa real), GameManager.setup_players/_spawn_starting_forces, e cada turno
## por TurnManager.end_turn() → GameManager._on_turn_changed (economia, pesquisa, produção,
## diplomacia, combate, IA estratégica e tática, eventos de mundo, Ritual, check_victories).
##
## O que o runner faz além do jogo normal (fixture, nunca regra):
##   * liga GameManager.ai_controls_human_seat — o `human_player` formal passa pelo MESMO stack V2
##     dos rivais (sem IA simplificada de teste);
##   * atribui raça e orientação por assento a partir de BalanceSeedSet (o jogo normal fixa os
##     rivais em elf/dwarf/orc e sorteia a orientação ciclicamente);
##   * dá ao assento 0 a capital pelo MESMO mecanismo que os rivais recebem no spawn
##     (GameManager._spawn_starting_forces: HexGrid.found_city no tile inicial escolhido por
##     WorldSetup.find_start_tile) no lugar do Colonizador inicial. Assim os quatro assentos começam
##     idênticos (capital + Guarda). Fundar pelo Colonizador era rejeitado por CitySite em ~17% dos
##     mapas (covil/prédio/distância), atrasando só o assento 0 em 1–2 turnos;
##   * semeia o RNG global com a seed da partida (determinismo);
##   * roda síncrono (stagger_ai_turns = false, igual a todo teste GUT), sem UI/render/áudio.
## Nada disso concede recurso, unidade, pesquisa, produção ou visão a ninguém.

const END_DOMINATION := "DOMINATION"
const END_SUPREMACY := "MILITARY_SUPREMACY"
const END_TRANSCENDENCE := "TRANSCENDENCE"
const END_TIMEOUT := "TIMEOUT"
const END_UNKNOWN := "UNKNOWN_END_REASON"

const FRAME_YIELD_INTERVAL := 10

## `options`:
##   turn_cap (int)        — padrão config.turn_cap;
##   save_load_turn (int)  — >0: salva e recarrega logo após processar esse turno (subconjunto F33B §155);
##   save_path (String)    — arquivo temporário do save/load;
##   collect_turn_times (bool) — padrão true.
static func run_match(host: Node, config: Dictionary, options: Dictionary = {}) -> Dictionary:
	var turn_cap := int(options.get("turn_cap", config.get("turn_cap", BalanceSeedSet.TURN_CAP)))
	var save_load_turn := int(options.get("save_load_turn", 0))
	var save_path := String(options.get("save_path", "user://balance/tmp_save_load_%s.json" % String(config.get("match_id", "match"))))
	var monitors_before := monitor_snapshot()
	var setup_started := Time.get_ticks_usec()
	var grid := setup_match(host, config)
	var setup_usec := Time.get_ticks_usec() - setup_started
	var telemetry := BalanceTelemetry.new()
	var run_config := config.duplicate(true)
	run_config.turn_cap = turn_cap
	run_config.human_capital_founded = not GameManager.human_player.cities.is_empty()
	if save_load_turn > 0:
		run_config.save_load_turn = save_load_turn
	telemetry.start(run_config)
	var turn_usec: Array[int] = []
	var loop_started := Time.get_ticks_usec()
	var save_load_info := {}
	while TurnManager.turn_number < turn_cap and GameManager.state != GameManager.GameState.GAME_OVER:
		var started := Time.get_ticks_usec()
		TurnManager.end_turn()
		turn_usec.append(Time.get_ticks_usec() - started)
		telemetry.on_turn_end()
		if save_load_turn > 0 and TurnManager.turn_number == save_load_turn and GameManager.state != GameManager.GameState.GAME_OVER:
			save_load_info = _save_and_reload(grid, config, telemetry, save_path)
		if TurnManager.turn_number % FRAME_YIELD_INTERVAL == 0:
			await host.get_tree().process_frame
	var loop_usec := Time.get_ticks_usec() - loop_started
	var end := classify_end(telemetry.victory, GameManager.state == GameManager.GameState.GAME_OVER, TurnManager.turn_number, turn_cap)
	var record := telemetry.finish(end)
	record.end = end
	record.save_load = save_load_info
	record.performance = {
		"setup_ms": snappedf(setup_usec / 1000.0, 0.01),
		"loop_ms": snappedf(loop_usec / 1000.0, 0.01),
		"turns_processed": turn_usec.size(),
		"turn_ms": _distribution_ms(turn_usec),
	}
	await teardown_match(host, grid)
	record.performance.monitors_before = monitors_before
	record.performance.monitors_after = monitor_snapshot()
	return record

## Monta o mundo da partida `config` e devolve o HexGrid (filho de `host`).
static func setup_match(host: Node, config: Dictionary) -> HexGrid:
	GameManager.end_match()
	V2AITacticalAI.clear_views()
	var match_seed := int(config.seed)
	seed(match_seed)
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	GameManager.map_width = int(config.map_width)
	GameManager.map_height = int(config.map_height)
	GameManager.rival_count = int(config.rival_count)
	var races: Array = config.races
	GameManager.human_race = String(races[0])
	GameManager.human_kingdom_name = ""
	var grid := HexGrid.new()
	host.add_child(grid)
	grid.generate_map(int(config.map_width), int(config.map_height), match_seed)
	GameManager.ai_controls_human_seat = true
	GameManager.setup_players(grid)
	apply_seat_identity(config)
	for seat in GameManager.players.size():
		assign_orientation(GameManager.players[seat], seat, _orientation_value(String(config.orientations[seat])), match_seed)
	GameManager._spawn_starting_forces()
	_found_human_capital(grid)
	grid.recompute_fog(GameManager.human_player)
	return grid

## Raça/nome por assento. Também reaplicado depois de um load (o save do jogo normal não guarda a
## raça dos rivais, que no jogo normal é fixa por índice em GameManager.RIVAL_CIVS).
static func apply_seat_identity(config: Dictionary) -> void:
	var races: Array = config.races
	for seat in GameManager.players.size():
		var player: PlayerData = GameManager.players[seat]
		player.civ.race = String(races[seat])
		player.civ.civ_name = "Assento %d (%s)" % [seat, String(races[seat])]

## Mesma construção de V2AIStrategyState.initialize, com a orientação vinda da matriz de rotação em
## vez do ciclo (índice + seed) % 3. Foco inicial idêntico ao do jogo: MILITARY → Supremacia,
## ARCANE → Transcendência, BALANCED → indefinido (resolve em V2StrategicAI._resolve_balanced_focus).
static func assign_orientation(player: PlayerData, seat: int, orientation: int, world_seed: int) -> void:
	var state: V2AIStrategyState = player.v2_ai_strategy
	state._clear()
	state.strategy_seed = V2AIStrategyState._stable_seed(world_seed, seat)
	state.orientation = orientation
	match orientation:
		V2AIStrategyState.Orientation.MILITARY:
			state.victory_focus = V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY
		V2AIStrategyState.Orientation.ARCANE:
			state.victory_focus = V2AIStrategyState.VictoryFocus.TRANSCENDENCE
		_:
			state.victory_focus = V2AIStrategyState.VictoryFocus.UNDECIDED
	state.last_strategy_review_turn = -1
	V2StrategicAI._ensure_preferences(player)

static func _orientation_value(name: String) -> int:
	match name:
		"MILITARY":
			return V2AIStrategyState.Orientation.MILITARY
		"ARCANE":
			return V2AIStrategyState.Orientation.ARCANE
	return V2AIStrategyState.Orientation.BALANCED

static func _found_human_capital(grid: HexGrid) -> void:
	var human: PlayerData = GameManager.human_player
	for unit in human.units.duplicate():
		if unit.unit_data.can_found_city:
			var coord: Vector2i = unit.coord
			grid.remove_unit(unit)
			grid.found_city(coord, human, human.civ.civ_name + " - Capital")
			return

## Tipo de fim a partir do evento real de vitória. Sem vencedor + motivo + tipo reconhecido depois
## de um GAME_OVER, o fim é UNKNOWN_END_REASON (falha de observabilidade, nunca ignorada).
static func classify_end(victory: Dictionary, game_over: bool, turn: int, turn_cap: int) -> Dictionary:
	var result := {"end_reason": "", "timeout": false, "turn": turn, "turn_cap": turn_cap, "victory_type_raw": String(victory.get("victory_type", ""))}
	if not victory.is_empty():
		var winner := int(victory.get("winner_index", -1))
		match String(victory.get("victory_type", "")):
			VictoryConditions.VICTORY_TYPE_DOMINANCE:
				result.end_reason = END_DOMINATION
			V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY:
				result.end_reason = END_SUPREMACY
			V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE:
				result.end_reason = END_TRANSCENDENCE
			_:
				result.end_reason = END_UNKNOWN
		if winner < 0:
			result.end_reason = END_UNKNOWN
		return result
	if game_over:
		result.end_reason = END_UNKNOWN
		return result
	if turn >= turn_cap:
		result.end_reason = END_TIMEOUT
		result.timeout = true
		return result
	result.end_reason = END_UNKNOWN
	return result

static func teardown_match(host: Node, grid: HexGrid) -> void:
	GameManager.end_match()
	GameManager.ai_controls_human_seat = false
	V2AITacticalAI.clear_views()
	if grid != null and is_instance_valid(grid):
		host.remove_child(grid)
		grid.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame

static func _save_and_reload(grid: HexGrid, config: Dictionary, telemetry: BalanceTelemetry, path: String) -> Dictionary:
	var human_strategy := GameManager.human_player.v2_ai_strategy.to_dict()
	var turn := TurnManager.turn_number
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_started := Time.get_ticks_usec()
	var saved := SaveManager.save_game(grid, path)
	var save_usec := Time.get_ticks_usec() - save_started
	var load_started := Time.get_ticks_usec()
	var loaded := saved and SaveManager.load_game(grid, path)
	var load_usec := Time.get_ticks_usec() - load_started
	SaveManager.delete_save(path)
	if loaded:
		apply_seat_identity(config)
		# O save do jogo só persiste a estratégia dos rivais; o assento humano automatizado é fixture.
		GameManager.human_player.v2_ai_strategy.load_dict(human_strategy, 0, grid.map_seed, GameManager.rival_players.size())
		V2AITacticalAI.clear_views()
		telemetry.rebind_players()
	return {"turn": turn, "saved": saved, "loaded": loaded, "save_ms": snappedf(save_usec / 1000.0, 0.01), "load_ms": snappedf(load_usec / 1000.0, 0.01)}

static func monitor_snapshot() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
	}

static func _distribution_ms(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value in sorted:
		total += value
	return {
		"n": sorted.size(),
		"mean": snappedf(total / 1000.0 / sorted.size(), 0.01),
		"p50": snappedf(sorted[int(sorted.size() * 0.5)] / 1000.0, 0.01),
		"p95": snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))] / 1000.0, 0.01),
		"max": snappedf(sorted.back() / 1000.0, 0.01),
		"first": snappedf(values[0] / 1000.0, 0.01),
	}
