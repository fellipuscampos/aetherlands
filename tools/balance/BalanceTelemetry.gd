class_name BalanceTelemetry
extends RefCounted

## Fase 33B — TELEMETRY OBSERVER do Release Balance Lab.
##
## Separação obrigatória: este observador pode ler o GameManager inteiro (todas as civilizações,
## cidades, filas, pesquisa, Mana), mas NUNCA escreve estado de gameplay e NUNCA é consultado pela
## IA — o único insumo de decisão da IA continua sendo V2AIWorldView. Ele só escuta sinais do
## EventBus/V2ResearchState e lê estado depois de cada turno processado.
##
## Convenção de turno: eventos emitidos enquanto o turno T é processado (dentro de
## TurnManager.end_turn → GameManager._on_turn_changed) são registrados com T =
## TurnManager.turn_number; `on_turn_end()` roda depois do processamento completo do turno T.
## Todo marco (milestone) é ONE-SHOT: o primeiro turno em que a condição vale.

const SNAPSHOT_INTERVAL := 5
const EXPANSION_CHECKPOINTS := [30, 50, 75, 100, 150]
## Diagnóstico (não regra): guerra com >= 20 turnos consecutivos sem captura e sem nenhuma morte de
## unidade de qualquer lado.
const STALEMATE_QUIET_TURNS := 20
## Diagnóstico: capstone concluído e 30 turnos sem progresso prático na rota.
const NO_PURSUIT_TURNS := 30
const RITUAL_LOOP_INTERRUPTIONS := 3
const ACADEMY_ID := "v2_building_academy"

const ROLE_KEYS := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege", "caster", "legendary", "manifestation", "retinue", "starting_guard", "other"]
const PRODUCTION_CATEGORIES := ["settler", "economic_building", "training_mastery", "other_building", "unit", "caster", "builder", "city_project", "fortification", "legendary", "manifestation"]
const TREE_KEYS := ["military", "magic", "infrastructure"]

## Fase 33D1 — engagement. Marcos one-shot por civ (mesmo dicionário `milestones`). Fase 33D2: os de ameaça
## regional passam a ser emitidos (RegionalThreatSystem); objetivos de D3 continuam no schema com 0.
const ENGAGEMENT_MILESTONES := [
	"first_player_contact", "first_pvp_combat", "first_city_attack", "first_capture", "first_unit_use",
	"first_unit_use_after_production", "first_hostile_monster_contact", "first_monster_attack",
	"first_lair_discovered", "first_lair_cleared", "regional_threat_discovered",
	"regional_threat_first_response", "regional_threat_cleared",
]
const PHASE_KEYS := ["FOUNDATION", "ASCENSION", "CONVERGENCE"]
## Contato hostil com monstro: monstro visível pela civ a até este raio de uma cidade própria.
const MONSTER_CONTACT_RADIUS := 6
## LOW_ACTIVITY_WAR: até este número de combates diretos entre o par, sem ataque a cidade nem captura.
const LOW_ACTIVITY_WAR_MAX_ENGAGEMENTS := 3
## Fase 33D2 — primeira resposta regional: unidade própria de combate a até este raio do covil regional,
## depois da descoberta (ou ataque a monstro/covil associado antes disso, raio de ENGAGE).
const REGIONAL_RESPONSE_RADIUS := 3
const REGIONAL_ENGAGE_RADIUS := 2
## Turnos em que se conta quantas ameaças regionais seguem vivas (sobrevivência do mini-arco).
const REGIONAL_ALIVE_CHECKPOINTS := [30, 50, 75, 100]

## Mapeia o motivo interno de V2TranscendenceSystem para a taxonomia do relatório. Só motivos que a
## fonte real emite; nada é inferido.
const INTERRUPT_REASON_MAP := {
	"site_lost": "city_lost",
	"structure_lost": "structure_lost",
	"manifestations_lost": "manifestation_lost",
	"access_lost": "requirement_lost",
	"eliminated": "eliminated",
	"cancelled": "manual_cancel",
}

var config: Dictionary = {}
var civs: Array = []
var wars: Array = []
var rituals: Array = []
var victory: Dictionary = {}
var elimination_order: Array = []
var match_counters := {"city_captures": 0, "recaptures": 0, "engagements": 0, "city_attacks": 0, "unit_deaths": 0, "turns_any_war": 0, "turns_observed": 0}
var geography: Dictionary = {}
var world_phase_timeline: Dictionary = {}
## Fase 33D2 — ameaças do mundo no nível da partida (Guardiões e sobrevivência das regionais).
var world_threats: Dictionary = {}
## Fase 33D3 — grandes eventos (Dragão/Relicário) e sobreposição de pressões na Ascensão.
var dragon: Dictionary = {}
var reliquary: Dictionary = {}
var overlap: Dictionary = {}
## V3 / Combat Ecology — Etapa 1: seção "combat_ecology" (observador próprio, ver EcologyTelemetry).
var ecology := EcologyTelemetry.new()

var _players: Array = []
var _active_wars: Dictionary = {}
var _active_ritual_by_owner: Dictionary = {}
var _city_owner_history: Dictionary = {}
var _connections: Array = []
var _player_connections: Array = []
var _finished := false

# --- Ciclo de vida ------------------------------------------------------------------------------

func start(match_config: Dictionary) -> void:
	config = match_config.duplicate(true)
	_players = GameManager.players.duplicate()
	civs.clear()
	for index in _players.size():
		var player: PlayerData = _players[index]
		civs.append(_new_civ(index, player))
		for city in player.cities:
			_remember_owner(city.coord, index)
		_connect_player(player, index)
	_connect(EventBus.victory_achieved, _on_victory_achieved)
	_connect(EventBus.diplomacy_changed, _on_diplomacy_changed)
	_connect(EventBus.city_founded, _on_city_founded)
	_connect(EventBus.city_captured, _on_city_captured)
	_connect(EventBus.ui_production_completed, _on_unit_spawned)
	_connect(EventBus.city_production_processed, _on_city_processed)
	_connect(EventBus.unit_removed, _on_unit_removed)
	_connect(EventBus.combat_engagement, _on_combat_engagement)
	_connect(EventBus.v2_transcendence_started, _on_ritual_started)
	_connect(EventBus.v2_transcendence_interrupted, _on_ritual_interrupted)
	_connect(EventBus.v2_transcendence_progressed, _on_ritual_progressed)
	_connect(EventBus.world_phase_changed, _on_world_phase_changed)
	_connect(EventBus.world_event_phase_changed, _on_world_event_phase_changed)
	_connect(EventBus.lair_cleared, _on_lair_cleared)
	_connect(EventBus.tile_pillaged, _on_tile_pillaged)
	_connect(EventBus.regional_threat_awakened, _on_regional_threat_awakened)
	_connect(EventBus.world_threat_discovered, _on_world_threat_discovered)
	_connect(EventBus.world_threat_resolved, _on_world_threat_resolved)
	_connect(EventBus.guardian_site_spawned, _on_guardian_site_spawned)
	_connect(EventBus.public_milestone_reached, _on_public_milestone_reached)
	_connect(EventBus.world_event_announced, _on_world_event_announced)
	_connect(EventBus.world_event_completed, _on_world_event_completed)
	dragon = {"announced": false, "eligible_turn": -1, "forced": false, "announce_turn": -1, "target": -1, "participants": {}, "damage_by_civ": {}, "resolution_turn": -1, "result": "", "reward_by_civ": {}, "superseded_reason": "", "phase_at_start": "", "phase_at_end": "", "convergence_edge": false}
	reliquary = {"announced": false, "eligible_turn": -1, "announce_turn": -1, "active_turn": -1, "site": [], "responders": {}, "guardian_clear_turn": -1, "max_control_progress": 0, "contested_rounds": 0, "resolved_turn": -1, "winner": -1, "reward_choice": "", "superseded_reason": "", "waited_for_dragon": false}
	overlap = {"ascension_rounds": 0, "rounds_by_count": {"0": 0, "1": 0, "2": 0, "3": 0, "4": 0}, "all_four_turns": []}
	world_threats = {"regional_alive_at": {}, "regional_total": 0, "guardian_sites_spawned": 0, "guardian_resources": {}, "guardian_resolved": 0, "guardian_spawn_turn": -1, "guardian_stats": {}}
	for record in WorldEventManager.regional_threats:
		_init_regional(record)
	world_phase_timeline = {
		"foundation_start": WorldEventManager.phase_entered_turn() if WorldEventManager.world_phase == WorldPhaseRules.Phase.FOUNDATION else -1,
		"ascension_turn": -1, "ascension_cause": "",
		"convergence_turn": -1, "convergence_cause": "",
	}
	_capture_geography()
	ecology.start(GameManager.hex_grid)
	# Estado inicial (T1): capital de cada assento já fundada, antes do primeiro turno processado.
	for civ in civs:
		_mark(civ, "first_city_founded", TurnManager.turn_number)
		_snapshot(civ)

## Chamado pelo runner depois que TurnManager.end_turn() processou o turno inteiro.
func on_turn_end() -> void:
	if _finished:
		return
	var turn := TurnManager.turn_number
	match_counters.turns_observed += 1
	var any_war := false
	for civ in civs:
		var player: PlayerData = civ.player
		if not player.enemies.is_empty():
			any_war = true
		_observe_civ_turn(civ, player, turn)
	if any_war:
		match_counters.turns_any_war += 1
	_observe_wars_turn(turn)
	var phase_key := WorldPhaseRules.id_name(WorldEventManager.world_phase)
	for civ in civs:
		_observe_engagement(civ, civ.player, turn)
		_observe_regional(civ, civ.player, turn)
		_update_inactivity(civ, phase_key)
	_observe_d3_round(turn)
	ecology.on_turn_end(GameManager.hex_grid, turn)
	if turn in REGIONAL_ALIVE_CHECKPOINTS:
		var alive := 0
		for record in WorldEventManager.regional_threats:
			if String(record.state) in [RegionalThreatSystem.STATE_DORMANT, RegionalThreatSystem.STATE_AWAKE]:
				alive += 1
		world_threats.regional_alive_at[str(turn)] = alive
	if turn % SNAPSHOT_INTERVAL == 0:
		for civ in civs:
			_snapshot(civ)

## Encerra a coleta: desconecta sinais, fecha guerras/rituais abertos e devolve o registro da partida.
func finish(end_info: Dictionary) -> Dictionary:
	if _finished:
		return {}
	_finished = true
	var turn := TurnManager.turn_number
	for civ in civs:
		if civ.snapshots.is_empty() or int(civ.snapshots.back().turn) != turn:
			_snapshot(civ)
	for key in _active_wars.keys():
		var war: Dictionary = wars[_active_wars[key]]
		war.end_turn = turn
		war.end_reason = "ongoing_at_game_end"
		war.duration = turn - int(war.start_turn)
		war.merge(classify_war_activity(war), true)
	_active_wars.clear()
	for owner in _active_ritual_by_owner.keys():
		var ritual: Dictionary = rituals[_active_ritual_by_owner[owner]]
		var won := not victory.is_empty() and int(victory.winner_index) == int(owner) and String(victory.victory_type) == V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE
		ritual.completed = won
		ritual.completion_turn = turn if won else -1
		ritual.active_at_game_end = not won
		ritual.rounds_remaining = V2TranscendenceSystem.ritual_rounds_remaining(_players[owner])
	_active_ritual_by_owner.clear()
	var timeout_report: Array = []
	if bool(end_info.get("timeout", false)):
		for civ in civs:
			timeout_report.append(_timeout_entry(civ, turn))
	for civ in civs:
		_finalize_civ(civ, turn)
	_disconnect_all()
	var result := {
		"config": config,
		"geography": geography,
		"victory": victory.duplicate(true),
		"elimination_order": elimination_order.duplicate(true),
		"wars": wars.duplicate(true),
		"rituals": rituals.duplicate(true),
		"counters": match_counters.duplicate(true),
		"timeout_report": timeout_report,
		"world_phase": world_phase_timeline.duplicate(),
		"world_threats": world_threats.duplicate(true),
		"dragon": _finish_dragon(),
		"reliquary": _finish_reliquary(),
		"event_overlap": overlap.duplicate(true),
		"combat_ecology": ecology.finish(GameManager.hex_grid),
		"civs": [],
	}
	for civ in civs:
		var copy: Dictionary = civ.duplicate(true)
		copy.erase("player")
		for key in copy.keys():
			if String(key).begins_with("_"):
				copy.erase(key)
		result.civs.append(copy)
	_players.clear()
	for civ in civs:
		civ.erase("player")
	return result

func _connect_player(player: PlayerData, index: int) -> void:
	var completed := _on_research_completed.bind(index)
	var selected := _on_research_selected.bind(index)
	player.v2_research.research_completed.connect(completed)
	player.v2_research.research_selected.connect(selected)
	_player_connections.append([player.v2_research.research_completed, completed])
	_player_connections.append([player.v2_research.research_selected, selected])

## SaveManager.load_game recria os PlayerData (GameManager.setup_players). Troca as referências do
## observador pelos objetos novos sem perder nenhum marco já registrado.
func rebind_players() -> void:
	_disconnect_players()
	_players = GameManager.players.duplicate()
	for index in _players.size():
		civs[index].player = _players[index]
		_connect_player(_players[index], index)

func _disconnect_players() -> void:
	for entry in _player_connections:
		var sig: Signal = entry[0]
		if sig.is_connected(entry[1]):
			sig.disconnect(entry[1])
	_player_connections.clear()

func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
	_connections.append([sig, callable])

func _disconnect_all() -> void:
	_disconnect_players()
	for entry in _connections:
		var sig: Signal = entry[0]
		if sig.is_connected(entry[1]):
			sig.disconnect(entry[1])
	_connections.clear()

func connected_signal_count() -> int:
	return _connections.size() + _player_connections.size() + ecology.connected_signal_count()

# --- Estado por civilização ---------------------------------------------------------------------

func _new_civ(index: int, player: PlayerData) -> Dictionary:
	var production_zero := {}
	var production_pp := {}
	for category in PRODUCTION_CATEGORIES:
		production_zero[category] = 0
		production_pp[category] = 0.0
	var supremacy := {}
	for other in _players.size():
		if other != index:
			supremacy[str(other)] = {"first_qualifying_capture": -1, "first_satisfied": -1, "unsatisfied_again": [], "satisfied_by_elimination": -1, "satisfied_at_end": false}
	return {
		"player": player,
		"index": index,
		"seat": index,
		"race": player.civ.race,
		"orientation": V2AIStrategyState.orientation_name(player.v2_ai_strategy.orientation),
		"initial_focus": V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus),
		"milestones": {},
		"milestone_context": {},
		"research": {"switches": 0, "idle_turns": 0, "idle_turns_available": 0, "completed_count": 0, "n9_branches": {"military": [], "magic": []}},
		"focus_changes": [],
		"deficit": _streak(), "negative_net": _streak(), "tension": _streak(),
		"max_supply_ratio": 0.0,
		"low_mana_turns": 0,
		"war_turns": 0,
		"city_turns": 0, "idle_city_turns": 0, "waiting_mana_city_turns": 0, "waiting_gold_city_turns": 0,
		"idle_breakdown": {"no_startable_option": 0, "only_settler_startable": 0, "options_not_chosen": 0},
		"manifestation_gate_turns": {},
		"supremacy_pursuit": {"turns_after_access": 0, "turns_at_war_with_pending_rival": 0},
		"production_turns": production_zero.duplicate(),
		"production_pp": production_pp,
		"production_completed": production_zero.duplicate(),
		"first_production": {},
		"first_non_settler_production": {},
		"settlers": {"produced": 0, "city_turns": 0, "cities_founded": 0, "lost": 0, "consumed": 0, "unit_turns": 0, "unused_at_end": 0},
		"manifestations": {"produced": [], "deaths": [], "schools_ever": []},
		"legendary_produced": 0,
		"combat": {"engagements": 0, "engagements_received": 0, "city_attacks": 0, "developed_city_attacks": 0, "unit_deaths": 0, "cities_captured": 0, "cities_lost": 0, "recaptures": 0, "qualifying_captures": 0},
		"max_city_count": player.cities.size(),
		"max_relevant_units": 0,
		"city_count_at": {},
		"supremacy_rivals": supremacy,
		"eliminated_turn": -1,
		"snapshots": [],
		"series": {"knowledge_generated": [], "mana": [], "cities": [], "relevant_units": []},
		"first_war_turn": -1,
		"first_war_declared_turn": -1,
		"wars_declared": 0,
		"mana_at_first_manifestation": -1.0,
		"mana_at_ritual_ready": -1.0,
		"inactivity": {"max_by_phase": {"FOUNDATION": 0, "ASCENSION": 0, "CONVERGENCE": 0}, "max_overall": 0, "meaningful_turns": 0, "current": 0},
		"objectives": {"issued": 0, "resolved": 0, "resolved_by_other": 0, "superseded": 0},
		"units_without_purpose_lag": -1,
		"regional_threat": {
			"exists": false, "type": "", "source": "", "distance": -1, "created_turn": -1, "wake_turn": -1, "awake_turn": -1,
			"discovered_turn": -1, "first_response_turn": -1, "cleared_turn": -1, "resolved_by": "", "resolved_by_index": -1,
			"visible_at_creation": false, "corridor_violation": false, "unresolved_at_first_war": -1, "war_while_awake_turns": 0,
		},
		"lairs": {"cleared": 0, "cleared_regional_own": 0, "cleared_regional_other": 0, "cleared_guardian": 0, "cleared_wild": 0, "structure_attacks": 0, "structure_attacks_unknown": 0},
		"guardian": {"discovered_turn": -1, "engaged_turn": -1, "resolved": 0},
		"_regional_coord": HexGrid.NO_LAIR,
		"public_milestones": {},
		"imperatives_at_convergence": {},
		"imperatives_at_end": {},
		"_meaningful": false,
		"_known_lairs": 0,
		"_last_focus": player.v2_ai_strategy.victory_focus,
		"_completed_this_turn": false,
		"_seen_units": {},
	}

func _streak() -> Dictionary:
	return {"first": -1, "total": 0, "longest": 0, "current": 0}

func _update_streak(streak: Dictionary, active: bool, turn: int) -> void:
	if active:
		if int(streak.first) < 0:
			streak.first = turn
		streak.total = int(streak.total) + 1
		streak.current = int(streak.current) + 1
		streak.longest = maxi(int(streak.longest), int(streak.current))
	else:
		streak.current = 0

func _mark(civ: Dictionary, key: String, turn: int, context: Dictionary = {}) -> bool:
	if civ.milestones.has(key):
		return false
	civ.milestones[key] = turn
	if not context.is_empty():
		civ.milestone_context[key] = context
	return true

func milestone(civ_index: int, key: String) -> int:
	return int(civs[civ_index].milestones.get(key, -1))

# --- Observação por turno -----------------------------------------------------------------------

func _observe_civ_turn(civ: Dictionary, player: PlayerData, turn: int) -> void:
	var alive := not V2VictoryConditions.is_eliminated(player)
	if not alive and int(civ.eliminated_turn) < 0:
		civ.eliminated_turn = turn
		elimination_order.append({"index": civ.index, "race": civ.race, "turn": turn})
		_close_wars_of(civ.index, turn, "elimination")
	# Pesquisa ociosa: sem projeto ao fim do turno, nada concluído neste turno (o que explicaria o
	# vazio até o próximo planejamento) e havia pesquisa disponível. O Conhecimento não se perde
	# (vai para research_overflow), mas atrasa.
	if alive and player.v2_research.active_id == "" and not bool(civ._completed_this_turn):
		civ.research.idle_turns += 1
		if _any_research_available(player):
			civ.research.idle_turns_available += 1
	civ._completed_this_turn = false
	var net := V2EconomyRuntime.player_gold_net_income(player)
	_update_streak(civ.deficit, alive and V2EconomyRuntime.is_gold_deficit(player), turn)
	_update_streak(civ.negative_net, alive and net < 0.0, turn)
	_update_streak(civ.tension, alive and V2LogisticsRuntime.is_logistically_strained(player), turn)
	var capacity := V2EconomyRuntime.player_supply_capacity(player)
	if capacity > 0.0:
		civ.max_supply_ratio = maxf(float(civ.max_supply_ratio), float(V2LogisticsRuntime.player_supply_used(player)) / capacity)
	if alive and player.mana < V2StrategicAI.strategic_mana_reserve(player):
		civ.low_mana_turns += 1
	if not player.enemies.is_empty():
		civ.war_turns += 1
	var focus := int(player.v2_ai_strategy.victory_focus)
	if focus != int(civ._last_focus):
		civ.focus_changes.append({"turn": turn, "from": V2AIStrategyState.focus_name(civ._last_focus), "to": V2AIStrategyState.focus_name(focus)})
		civ._last_focus = focus
		_mark(civ, "focus_resolved", turn)
	var city_count := player.cities.size()
	civ.max_city_count = maxi(int(civ.max_city_count), city_count)
	for count in [2, 3, 4]:
		if city_count >= count:
			_mark(civ, "city_count_%d" % count, turn)
	if turn in EXPANSION_CHECKPOINTS:
		civ.city_count_at[str(turn)] = city_count
	var relevant := V2StrategicAI.relevant_unit_count(player)
	civ.max_relevant_units = maxi(int(civ.max_relevant_units), relevant)
	for city in player.cities:
		if city.city_level >= 2:
			_mark(civ, "city_level_2", turn)
		if city.city_level >= 3:
			_mark(civ, "city_level_3", turn)
		if city.city_level >= 4:
			_mark(civ, "city_level_4", turn)
		for level in [1, 2, 3]:
			if city.fortification_level >= level:
				_mark(civ, "fortification_%d" % level, turn)
	var settlers_alive := 0
	for unit in player.units:
		if not is_instance_valid(unit):
			continue
		var kind := unit.unit_data.visual_kind
		if unit.unit_data.can_found_city:
			settlers_alive += 1
		var node := V2ResearchDatabase.node_for_unlock_id(kind)
		if node != null and V2UnitLine.is_line_unit(kind):
			if node.tier >= 5:
				_mark(civ, "first_n5_form", turn)
			if node.tier >= 7:
				_mark(civ, "first_n7_form", turn)
	civ.settlers.unit_turns += settlers_alive
	if V2ManifestationSystem.active_manifestation_count(player) >= V2TranscendenceSystem.MANIFESTATIONS_REQUIRED:
		_mark(civ, "two_active_manifestations", turn)
	_observe_victory_paths(civ, player, turn)
	civ.series.knowledge_generated.append(snappedf(_knowledge_generated(player), 0.01))
	civ.series.mana.append(snappedf(player.mana, 0.01))
	civ.series.cities.append(city_count)
	civ.series.relevant_units.append(relevant)

func _observe_victory_paths(civ: Dictionary, player: PlayerData, turn: int) -> void:
	var doctrine_n9: int = civ.research.n9_branches.military.size()
	var school_n9: int = civ.research.n9_branches.magic.size()
	if doctrine_n9 >= 2 and player.v2_research.is_completed(V2ResearchDatabase.SUPREME_ARMY_ID):
		_mark(civ, "supremacy_research_ready", turn, _research_context(player))
	if school_n9 >= 2 and player.v2_research.is_completed(V2ResearchDatabase.TRANSCENDENCE_ID):
		_mark(civ, "transcendence_research_ready", turn, _research_context(player))
	# Prontidão do Ritual: o runtime canônico decide (V2TranscendenceSystem.can_start_ritual). Nada
	# aqui reimplementa a regra; só registra o primeiro turno em que alguma cidade a satisfaz.
	if not civ.milestones.has("transcendence_ritual_ready") and V2TranscendenceSystem.has_access(player):
		for city in player.cities:
			if V2TranscendenceSystem.can_start_ritual(player, city):
				_mark(civ, "transcendence_ritual_ready", turn)
				civ.mana_at_ritual_ready = snappedf(player.mana, 0.01)
				break
	var status := V2VictoryConditions.military_supremacy_status(player)
	for rival in status.rivals:
		var entry: Dictionary = civ.supremacy_rivals.get(str(int(rival.player_id)), {})
		if entry.is_empty():
			continue
		var satisfied := bool(rival.satisfied)
		if rival.reason == V2VictoryConditions.REASON_CAPTURED and int(entry.first_qualifying_capture) < 0:
			entry.first_qualifying_capture = turn
		if rival.reason == V2VictoryConditions.REASON_ELIMINATED and int(entry.satisfied_by_elimination) < 0:
			entry.satisfied_by_elimination = turn
		if satisfied and int(entry.first_satisfied) < 0:
			entry.first_satisfied = turn
		if not satisfied and bool(entry.satisfied_at_end):
			entry.unsatisfied_again.append(turn)
		entry.satisfied_at_end = satisfied
	if bool(status.access) and not V2VictoryConditions.is_eliminated(player):
		civ.supremacy_pursuit.turns_after_access += 1
		for rival in status.rivals:
			if not bool(rival.satisfied) and player.is_at_war_with(GameManager.players[int(rival.player_id)]):
				civ.supremacy_pursuit.turns_at_war_with_pending_rival += 1
				break
	if V2TranscendenceSystem.has_access(player) and not V2TranscendenceSystem.has_active_ritual(player) and not V2VictoryConditions.is_eliminated(player):
		var gate := manifestation_gate(player)
		civ.manifestation_gate_turns[gate] = int(civ.manifestation_gate_turns.get(gate, 0)) + 1

func _observe_wars_turn(turn: int) -> void:
	for key in _active_wars.keys():
		var war: Dictionary = wars[_active_wars[key]]
		if bool(war._activity_this_turn):
			war._quiet = 0
		else:
			war._quiet = int(war._quiet) + 1
			war.max_quiet_streak = maxi(int(war.max_quiet_streak), int(war._quiet))
		war._activity_this_turn = false

func _any_research_available(player: PlayerData) -> bool:
	for node in V2ResearchDatabase.all_nodes():
		if player.v2_research.is_available(node.id):
			return true
	return false

## Conhecimento total já gerado: tudo o que entrou foi para progresso de nós (concluídos pelo custo
## inteiro, parciais pelo progresso) ou para o overflow — nenhuma outra fonte/sumidouro existe.
func _knowledge_generated(player: PlayerData) -> float:
	var invested := knowledge_invested_by_tree(player)
	return float(invested.military) + float(invested.magic) + float(invested.infrastructure) + player.v2_research.research_overflow

static func knowledge_invested_by_tree(player: PlayerData) -> Dictionary:
	var result := {"military": 0.0, "magic": 0.0, "infrastructure": 0.0}
	for id in player.v2_research.completed_ids:
		var node := V2ResearchDatabase.get_node(id)
		if node != null:
			result[TREE_KEYS[node.tree_type]] += node.cost
	for id in player.v2_research.progress_by_id:
		var node := V2ResearchDatabase.get_node(id)
		if node != null:
			result[TREE_KEYS[node.tree_type]] += float(player.v2_research.progress_by_id[id])
	return result

func _research_context(player: PlayerData) -> Dictionary:
	var academies := 0
	for city in player.cities:
		academies += city.building_count(ACADEMY_ID)
	return {
		"cities": player.cities.size(),
		"knowledge_per_turn": snappedf(V2EconomyRuntime.player_knowledge_income(player), 0.01),
		"academies": academies,
		"knowledge_invested": snappedf(_knowledge_generated(player) - player.v2_research.research_overflow, 0.01),
	}

# --- Engagement (Fase 33D1) ---------------------------------------------------------------------

## Conhecimento da PRÓPRIA civ, lido sem efeito colateral: a visão que a IA já capturou neste turno
## (V2AITacticalAI._turn_views, nunca recapturada aqui) e os covis nos tiles que ela explorou.
func _observe_engagement(civ: Dictionary, player: PlayerData, turn: int) -> void:
	if not player.known_enemy_cities.is_empty():
		_mark(civ, "first_player_contact", turn)
	var entry: Dictionary = V2AITacticalAI._turn_views.get(player, {})
	if int(entry.get("turn", -1)) == turn and entry.get("view") != null:
		var view: V2AIWorldView = entry.view
		for unit in view.visible_enemy_units:
			if not is_instance_valid(unit):
				continue
			if unit.owner_player != null:
				_mark(civ, "first_player_contact", turn)
			elif _near_own_city(player, unit.coord, MONSTER_CONTACT_RADIUS):
				_mark(civ, "first_hostile_monster_contact", turn)
	var known := 0
	var grid: HexGrid = GameManager.hex_grid
	if grid != null:
		for lair_coord in grid.lair_coords:
			if player.explored_tiles.has(lair_coord):
				known += 1
	if known > int(civ._known_lairs):
		_mark(civ, "first_lair_discovered", turn)
		civ._meaningful = true
	civ._known_lairs = known

static func _near_own_city(player: PlayerData, coord: Vector2i, radius: int) -> bool:
	for city in player.cities:
		if HexMetrics.axial_distance(city.coord, coord) <= radius:
			return true
	return false

## Maior sequência de turnos SEM interação significativa, por era (ver _meaningful nos sinais).
func _update_inactivity(civ: Dictionary, phase_key: String) -> void:
	var inactivity: Dictionary = civ.inactivity
	if int(civ.eliminated_turn) >= 0:
		civ._meaningful = false
		return
	if bool(civ._meaningful):
		inactivity.meaningful_turns = int(inactivity.meaningful_turns) + 1
		inactivity.current = 0
	else:
		inactivity.current = int(inactivity.current) + 1
		inactivity.max_overall = maxi(int(inactivity.max_overall), int(inactivity.current))
		inactivity.max_by_phase[phase_key] = maxi(int(inactivity.max_by_phase.get(phase_key, 0)), int(inactivity.current))
	civ._meaningful = false

func _set_meaningful(player: PlayerData) -> void:
	var civ := _civ_of(player)
	if not civ.is_empty():
		civ._meaningful = true

static func classify_war_activity(war: Dictionary) -> Dictionary:
	var captures := 0
	for key in war.cities_captured:
		captures += int(war.cities_captured[key])
	var engagements := int(war.get("pair_engagements", 0))
	var city_attacks := int(war.get("pair_city_attacks", 0))
	var ended_quietly: bool = String(war.end_reason) in ["peace", "ongoing_at_game_end"]
	return {
		"empty_war": ended_quietly and engagements == 0 and city_attacks == 0 and captures == 0,
		"low_activity_war": ended_quietly and engagements <= LOW_ACTIVITY_WAR_MAX_ENGAGEMENTS and city_attacks == 0 and captures == 0,
	}

# --- Snapshots ----------------------------------------------------------------------------------

func _snapshot(civ: Dictionary) -> void:
	var player: PlayerData = civ.player
	var roles := {}
	for key in ROLE_KEYS:
		roles[key] = 0
	var forms := {"n3": 0, "n5": 0, "n7": 0}
	for unit in player.units:
		if not is_instance_valid(unit):
			continue
		var role := unit_role(unit)
		if roles.has(role):
			roles[role] += 1
		var kind := unit.unit_data.visual_kind
		var node := V2ResearchDatabase.node_for_unlock_id(kind)
		if node != null and V2UnitLine.is_line_unit(kind) and node.tier in [3, 5, 7]:
			forms["n%d" % node.tier] += 1
	var production_total := 0.0
	var level_sum := 0
	var developed := 0
	for city in player.cities:
		production_total += V2EconomyRuntime.city_production_income(city)
		level_sum += city.city_level
		developed += 1 if city.is_developed_v2() else 0
	var max_tier := {"military": 0, "magic": 0, "infrastructure": 0}
	for id in player.v2_research.completed_ids:
		var node := V2ResearchDatabase.get_node(id)
		if node != null and not node.is_universal:
			var key: String = TREE_KEYS[node.tree_type]
			max_tier[key] = maxi(int(max_tier[key]), node.tier)
	var invested := knowledge_invested_by_tree(player)
	for key in invested:
		invested[key] = snappedf(float(invested[key]), 0.01)
	var supremacy := V2VictoryConditions.military_supremacy_status(player)
	var enemies: Array = []
	for enemy in player.enemies:
		enemies.append(GameManager.players.find(enemy))
	enemies.sort()
	var city_count := player.cities.size()
	civ.snapshots.append({
		"turn": TurnManager.turn_number,
		"alive": not V2VictoryConditions.is_eliminated(player),
		"cities": city_count,
		"mean_city_level": snappedf(float(level_sum) / maxf(city_count, 1), 0.01),
		"developed_cities": developed,
		"gold": snappedf(player.gold, 0.01),
		"gold_gross": snappedf(V2EconomyRuntime.player_gold_gross_income(player), 0.01),
		"gold_upkeep": snappedf(V2EconomyRuntime.player_gold_upkeep(player), 0.01),
		"gold_net": snappedf(V2EconomyRuntime.player_gold_net_income(player), 0.01),
		"deficit": V2EconomyRuntime.is_gold_deficit(player),
		"supply_used": V2LogisticsRuntime.player_supply_used(player),
		"supply_capacity": snappedf(V2EconomyRuntime.player_supply_capacity(player), 0.01),
		"tension": V2LogisticsRuntime.is_logistically_strained(player),
		"mana": snappedf(player.mana, 0.01),
		"mana_income": snappedf(V2EconomyRuntime.player_mana_income(player), 0.01),
		"knowledge_income": snappedf(V2EconomyRuntime.player_knowledge_income(player), 0.01),
		"knowledge_generated": snappedf(_knowledge_generated(player), 0.01),
		"knowledge_invested": invested,
		"research_active": player.v2_research.active_id,
		"research_completed": player.v2_research.completed_ids.size(),
		"max_tier": max_tier,
		"production_total": snappedf(production_total, 0.01),
		"production_mean": snappedf(production_total / maxf(city_count, 1), 0.01),
		"relevant_units": V2StrategicAI.relevant_unit_count(player),
		"units_total": player.units.size(),
		"roles": roles,
		"forms": forms,
		"enemies": enemies,
		"supremacy": {"access": supremacy.access, "satisfied": supremacy.satisfied_count, "rivals": supremacy.rival_count},
		"transcendence": {
			"access": V2TranscendenceSystem.has_access(player),
			"manifestations": V2ManifestationSystem.active_manifestation_count(player),
			"ritual_active": V2TranscendenceSystem.has_active_ritual(player),
			"ritual_remaining": V2TranscendenceSystem.ritual_rounds_remaining(player),
		},
		"focus": V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus),
	})

## Papel de composição de exército (relatório; não é o `role_of` estratégico da IA).
static func unit_role(unit: Unit) -> String:
	var kind := unit.unit_data.visual_kind
	if V2ManifestationSystem.is_manifestation_kind(kind):
		return "manifestation"
	if V2LegendarySystem.is_legendary_unit(unit):
		return "legendary"
	if unit.unit_data.has_trait(UnitData.TRAIT_RETINUE):
		return "retinue"
	if unit.unit_data.is_v2_caster():
		return "caster"
	var branch := V2UnitLine.doctrine_branch_of(kind)
	if branch != "":
		return branch
	if unit.unit_data.can_found_city:
		return "settler"
	if V2ConstructorRuntime.is_builder_unit(unit):
		return "builder"
	if kind == "warrior":
		return "starting_guard"
	return "other"

## Categoria de produção de um item da fila local.
static func production_category(item_id: String) -> String:
	if item_id == "":
		return ""
	if V2CityLevelData.is_city_project(item_id):
		return "city_project"
	if V2FortificationData.is_fortification_project(item_id):
		return "fortification"
	var building := BuildingDatabase.get_building(item_id)
	if building != null:
		if V2InfrastructureEconomyData.branch_for_building(item_id) != "":
			return "economic_building"
		var node := V2ResearchDatabase.node_for_unlock_id(item_id)
		if node != null and node.tier_role in ["training_structure", "school_building", "mastery_structure", "ritual_structure"]:
			return "training_mastery"
		return "other_building"
	if V2ManifestationSystem.is_manifestation_kind(item_id):
		return "manifestation"
	if V2LegendarySystem.is_legendary_kind(item_id):
		return "legendary"
	if V2ConstructorRuntime.is_builder_kind(item_id):
		return "builder"
	var data := UnitDatabase.create_unit(item_id)
	if data.can_found_city:
		return "settler"
	if data.is_v2_caster():
		return "caster"
	return "unit"

## Agrupamento pedido no relatório da primeira produção (seção 40).
static func first_production_group(category: String) -> String:
	match category:
		"settler":
			return "settler"
		"economic_building":
			return "economic_building"
		"training_mastery":
			return "training_building"
		"unit", "caster", "builder", "legendary", "manifestation":
			return "other_unit"
	return "other_project"

## Por que a cidade ficou ociosa? Lê o catálogo canônico da UI (CityPresenter.startable_production_items,
## o mesmo usado pelo Attention da F33A.2) logo após o processamento: "no_startable_option" = gate de
## catálogo (nada iniciável); "only_settler_startable" = só o Colonizador; "options_not_chosen" = havia
## opção real e a IA não escolheu (nenhum candidato com score > 0). Aproximação: o estado é o do fim do
## processamento da cidade, não o do instante do planejamento (mesmo turno).
static func _idle_reason(city: City) -> String:
	var items := CityPresenter.startable_production_items(city)
	if items.is_empty():
		return "no_startable_option"
	if items.size() == 1 and CityPresenter.is_settler_production_item(items[0]):
		return "only_settler_startable"
	return "options_not_chosen"

## Gate da próxima Grande Manifestação de quem já tem acesso à Transcendência e ainda não mantém duas
## ativas. Usa os gates reais (City.can_train e os motivos de V2LogisticsRuntime/V2ManifestationSystem);
## nunca reimplementa a regra. Separa "gargalo de conteúdo/economia" de "a IA não escolheu".
static func manifestation_gate(player: PlayerData) -> String:
	if V2ManifestationSystem.active_manifestation_count(player) >= V2TranscendenceSystem.MANIFESTATIONS_REQUIRED:
		return _ritual_start_gate(player)
	for city in player.cities:
		if V2ManifestationSystem.is_manifestation_kind(city.production_item):
			return "in_production"
	var active_schools := V2ManifestationSystem.active_manifestation_schools(player)
	var candidates: Array[String] = []
	for node in V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL):
		if node.tier_role == "grand_manifestation" and V2UnlockSystem.is_unit_unlocked(player, node.unlock_id) and V2ManifestationSystem.school_of_kind(node.unlock_id) not in active_schools:
			candidates.append(node.unlock_id)
	if candidates.is_empty():
		return "no_unlocked_free_school"
	var trainable_idle := false
	var trainable_busy := false
	var has_trainer := false
	var mana_blocked := false
	var logistics_blocked := false
	for kind in candidates:
		var trainer := BuildingDatabase.building_that_trains(kind)
		for city in player.cities:
			if trainer != null and city.buildings.has(trainer.id):
				has_trainer = true
			if city.can_train(kind):
				if city.production_item == "":
					trainable_idle = true
				else:
					trainable_busy = true
			elif trainer == null or city.buildings.has(trainer.id):
				if V2ManifestationSystem.production_mana_reason(player, city, kind) != "":
					mana_blocked = true
				elif not V2LogisticsRuntime.can_afford_training(player, city, kind):
					logistics_blocked = true
	if trainable_idle:
		return "trainable_idle_city_not_chosen"
	if trainable_busy:
		return "trainable_cities_busy"
	if not has_trainer:
		return _ritual_structure_gate(player, candidates)
	if mana_blocked:
		return "blocked_mana"
	if logistics_blocked:
		return "blocked_supply_or_deficit"
	return "blocked_other"

## Duas Manifestações ativas: o que ainda separa a civilização do Ritual Final, pelo runtime canônico.
static func _ritual_start_gate(player: PlayerData) -> String:
	var has_structure := false
	for city in player.cities:
		if V2TranscendenceSystem.can_start_ritual(player, city):
			return "ritual_ready_not_started"
		has_structure = has_structure or V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, player)
	if not has_structure:
		return "ritual_no_structure_city"
	if player.mana < V2TranscendenceSystem.MANA_COST:
		return "ritual_blocked_mana"
	return "ritual_blocked_other"

## A Manifestação é treinada pela Estrutura Ritual N8 da Escola (BuildingData.trains_unit). Quando
## nenhuma cidade a possui: alguém já a constrói, ela é construível e não foi escolhida (IA), ou o
## gate real que a bloqueia (sem slot livre, falta o prédio-escola exigido, Déficit).
static func _ritual_structure_gate(player: PlayerData, candidates: Array[String]) -> String:
	var any_buildable := false
	var buildable_in_idle_city := false
	var any_free_slot := false
	var needs_prerequisite := false
	var deficit_blocked := false
	for kind in candidates:
		var trainer := BuildingDatabase.building_that_trains(kind)
		if trainer == null:
			continue
		for city in player.cities:
			if city.production_item == trainer.id:
				return "ritual_structure_in_production"
			if city.can_build(trainer.id):
				any_buildable = true
				buildable_in_idle_city = buildable_in_idle_city or city.production_item == ""
				continue
			if city.used_building_slots() < city.max_building_slots():
				any_free_slot = true
				if trainer.requires_building != "" and not city.buildings.has(trainer.requires_building):
					needs_prerequisite = true
				elif city.deficit_build_reason(trainer.id) != "":
					deficit_blocked = true
	if buildable_in_idle_city:
		return "ritual_structure_buildable_idle_city_not_chosen"
	if any_buildable:
		return "ritual_structure_buildable_cities_busy"
	if not any_free_slot:
		return "ritual_structure_no_free_slot"
	if needs_prerequisite:
		return "ritual_structure_needs_school_building"
	if deficit_blocked:
		return "ritual_structure_deficit"
	return "ritual_structure_blocked_other"

# --- Sinais -------------------------------------------------------------------------------------

func _civ_of(player: PlayerData) -> Dictionary:
	var index := _players.find(player)
	return civs[index] if index >= 0 and index < civs.size() else {}

func _on_research_completed(research_id: String, index: int) -> void:
	var civ: Dictionary = civs[index]
	var player: PlayerData = civ.player
	var turn := TurnManager.turn_number
	civ._completed_this_turn = true
	civ.research.completed_count += 1
	var node := V2ResearchDatabase.get_node(research_id)
	if node == null:
		return
	if node.is_universal or (node.tree_type != V2ResearchNode.TreeType.INFRASTRUCTURE and node.tier in [3, 5, 7, 9]):
		civ._meaningful = true
	if node.is_universal:
		if research_id == V2ResearchDatabase.SUPREME_ARMY_ID:
			_mark(civ, "supreme_army", turn, _research_context(player))
		elif research_id == V2ResearchDatabase.TRANSCENDENCE_ID:
			_mark(civ, "transcendence", turn, _research_context(player))
		return
	if node.tree_type == V2ResearchNode.TreeType.INFRASTRUCTURE:
		for level in range(1, node.tier + 1):
			_mark(civ, "infra_%d" % level, turn)
		return
	for level in [1, 3, 5, 7]:
		if node.tier >= level:
			_mark(civ, "n%d" % level, turn)
	if node.tier != 9:
		return
	var tree_key: String = TREE_KEYS[node.tree_type]
	var branches: Array = civ.research.n9_branches[tree_key]
	if node.branch not in branches:
		branches.append(node.branch)
	var total_n9: int = civ.research.n9_branches.military.size() + civ.research.n9_branches.magic.size()
	var context := _research_context(player)
	if total_n9 >= 1:
		_mark(civ, "n9_first", turn, context)
	if total_n9 >= 2:
		_mark(civ, "n9_second", turn, context)
	if branches.size() >= 1:
		_mark(civ, "%s_n9_first" % tree_key, turn, context)
	if branches.size() >= 2:
		_mark(civ, "%s_n9_second" % tree_key, turn, context)

func _on_research_selected(_id: String, previous_id: String, index: int) -> void:
	if previous_id != "":
		civs[index].research.switches += 1
	# V3 / Etapa 2: gate do opening — a primeira pesquisa nunca antes da primeira cidade.
	_mark(civs[index], "first_research_selected", TurnManager.turn_number, {"cities": (civs[index].player as PlayerData).cities.size()})

func _on_victory_achieved(winner: PlayerData, victory_type: String) -> void:
	victory = {
		"winner_index": _players.find(winner) if winner != null else -1,
		"winner_race": winner.civ.race if winner != null else "",
		"winner_orientation": V2AIStrategyState.orientation_name(winner.v2_ai_strategy.orientation) if winner != null else "",
		"victory_type": victory_type,
		"victory_turn": TurnManager.turn_number,
	}

func _pair_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]

func _on_diplomacy_changed(change_type: String, source: PlayerData, target: PlayerData, reason: String) -> void:
	var a := _players.find(source)
	var b := _players.find(target)
	if a < 0 or b < 0:
		return
	var turn := TurnManager.turn_number
	var key := _pair_key(a, b)
	civs[a]._meaningful = true
	civs[b]._meaningful = true
	if change_type == "war" and not _active_wars.has(key):
		var war := {
			"war_id": wars.size() + 1,
			"start_turn": turn,
			"end_turn": -1,
			"duration": 0,
			"initiator": a,
			"target": b,
			"reason": reason,
			"cities_captured": {str(a): 0, str(b): 0},
			"unit_losses": {str(a): 0, str(b): 0},
			"end_reason": "",
			"max_quiet_streak": 0,
			"possible_stalemate": false,
			"pair_engagements": 0,
			"pair_city_attacks": 0,
			"empty_war": false,
			"low_activity_war": false,
			"_quiet": 0,
			"_activity_this_turn": false,
		}
		_active_wars[key] = wars.size()
		wars.append(war)
		civs[a].wars_declared += 1
		if int(civs[a].first_war_declared_turn) < 0:
			civs[a].first_war_declared_turn = turn
		for index in [a, b]:
			if int(civs[index].first_war_turn) < 0:
				civs[index].first_war_turn = turn
				# Fase 33D2 (vigia de guerra precoce): a ameaça regional ainda estava viva quando a 1ª guerra começou?
				var regional: Dictionary = civs[index].regional_threat
				if bool(regional.exists):
					regional.unresolved_at_first_war = 1 if int(regional.cleared_turn) < 0 else 0
	elif change_type == "peace" and _active_wars.has(key):
		_close_war(key, turn, "peace")

func _close_war(key: String, turn: int, reason: String) -> void:
	var war: Dictionary = wars[_active_wars[key]]
	war.end_turn = turn
	war.end_reason = reason
	war.duration = turn - int(war.start_turn)
	war.merge(classify_war_activity(war), true)
	_active_wars.erase(key)

func _close_wars_of(index: int, turn: int, reason: String) -> void:
	for key in _active_wars.keys():
		var war: Dictionary = wars[_active_wars[key]]
		if int(war.initiator) == index or int(war.target) == index:
			_close_war(key, turn, reason)

func _remember_owner(coord: Vector2i, index: int) -> void:
	var history: Dictionary = _city_owner_history.get(coord, {})
	history[index] = true
	_city_owner_history[coord] = history

func _on_city_founded(player: PlayerData, _city_name: String, coord: Vector2i) -> void:
	var civ := _civ_of(player)
	if civ.is_empty():
		return
	civ.settlers.cities_founded += 1
	civ._meaningful = true
	_remember_owner(coord, int(civ.index))
	var founded: int = civ.settlers.cities_founded
	if founded == 1:
		_mark(civ, "second_city_founded", TurnManager.turn_number)
	elif founded == 2:
		_mark(civ, "third_city_founded", TurnManager.turn_number)
	elif founded == 3:
		_mark(civ, "fourth_city_founded", TurnManager.turn_number)

func _on_city_captured(old_owner: PlayerData, new_owner: PlayerData, _city_name: String, coord: Vector2i) -> void:
	var old_index := _players.find(old_owner)
	var new_index := _players.find(new_owner)
	if new_index < 0:
		return
	match_counters.city_captures += 1
	var civ: Dictionary = civs[new_index]
	civ.combat.cities_captured += 1
	civ._meaningful = true
	_mark(civ, "first_capture", TurnManager.turn_number)
	var history: Dictionary = _city_owner_history.get(coord, {})
	if history.has(new_index):
		civ.combat.recaptures += 1
		match_counters.recaptures += 1
	_remember_owner(coord, new_index)
	var city := GameManager.hex_grid.get_city_at(coord) if GameManager.hex_grid != null else null
	if city != null and city.v2_supremacy_captured_from >= 0:
		civ.combat.qualifying_captures += 1
	if old_index >= 0:
		civs[old_index].combat.cities_lost += 1
		civs[old_index]._meaningful = true
		var key := _pair_key(old_index, new_index)
		if _active_wars.has(key):
			var war: Dictionary = wars[_active_wars[key]]
			war.cities_captured[str(new_index)] = int(war.cities_captured[str(new_index)]) + 1
			war._activity_this_turn = true

func _on_unit_spawned(player: PlayerData, _city_name: String, item_id: String, _display: String, _coord: Vector2i) -> void:
	if BuildingDatabase.get_building(item_id) != null:
		return # prédios só são anunciados para o humano; a contagem vem de city_production_processed
	var civ := _civ_of(player)
	if civ.is_empty():
		return
	var turn := TurnManager.turn_number
	var data := UnitDatabase.create_unit(item_id)
	if data.can_found_city:
		civ.settlers.produced += 1
		_mark(civ, "first_trained_settler", turn)
		return
	if V2ConstructorRuntime.is_builder_kind(item_id):
		_mark(civ, "first_builder", turn)
		return
	var spawned_node := V2ResearchDatabase.node_for_unlock_id(item_id)
	if V2ManifestationSystem.is_manifestation_kind(item_id) or V2LegendarySystem.is_legendary_kind(item_id) or data.is_v2_caster() or (spawned_node != null and V2UnitLine.is_line_unit(item_id) and spawned_node.tier >= 3):
		civ._meaningful = true
	if V2ManifestationSystem.is_manifestation_kind(item_id):
		var school := V2ManifestationSystem.school_of_kind(item_id)
		civ.manifestations.produced.append({"turn": turn, "school": school, "mana_before_spawn": snappedf(player.mana + data.production_mana_cost, 0.01)})
		if _mark(civ, "first_manifestation", turn):
			civ.mana_at_first_manifestation = snappedf(player.mana + data.production_mana_cost, 0.01)
		if school not in civ.manifestations.schools_ever:
			civ.manifestations.schools_ever.append(school)
			if civ.manifestations.schools_ever.size() >= 2:
				_mark(civ, "second_distinct_manifestation", turn)
	if V2LegendarySystem.is_legendary_kind(item_id):
		civ.legendary_produced += 1
		_mark(civ, "first_legendary", turn)
	if data.is_v2_caster():
		_mark(civ, "first_caster", turn)
	if data.attack > 0.0:
		_mark(civ, "first_combat_unit", turn)
	var node := V2ResearchDatabase.node_for_unlock_id(item_id)
	if node != null and V2UnitLine.is_line_unit(item_id):
		if node.tier == 3:
			_mark(civ, "first_n3_unit", turn)
		if node.tier >= 5:
			_mark(civ, "first_n5_form", turn)
		if node.tier >= 7:
			_mark(civ, "first_n7_form", turn)

func _on_city_processed(player: PlayerData, city: City, item_id: String, result: Dictionary) -> void:
	var civ := _civ_of(player)
	if civ.is_empty():
		return
	var turn := TurnManager.turn_number
	civ.city_turns += 1
	if item_id == "":
		civ.idle_city_turns += 1
		civ.idle_breakdown[_idle_reason(city)] += 1
		return
	var category := production_category(item_id)
	civ.production_turns[category] += 1
	civ.production_pp[category] += V2EconomyRuntime.city_production_income(city)
	if category == "settler":
		civ.settlers.city_turns += 1
	if civ.first_production.is_empty():
		civ.first_production = {"turn": turn, "item": item_id, "category": category, "group": first_production_group(category)}
		_mark(civ, "first_production", turn)
	if category != "settler" and civ.first_non_settler_production.is_empty():
		civ.first_non_settler_production = {"turn": turn, "item": item_id, "category": category}
		_mark(civ, "first_non_settler_production", turn)
	var completed := false
	if String(result.get("spawn_unit_kind", "")) != "" or String(result.get("built_kind", "")) != "":
		completed = true
	if int(result.get("city_level_up", 0)) > 0 or int(result.get("fortification_level_up", 0)) > 0:
		completed = true
	if int(result.get("city_level_up", 0)) > 0 or int(result.get("fortification_level_up", 0)) > 0:
		civ._meaningful = true
	if completed:
		civ.production_completed[category] += 1
		if category == "settler":
			_mark(civ, "first_settler_produced", turn)
	elif city.production_item == item_id:
		if city.production_waiting_for_mana() > 0 and city.stored_production >= city.production_cost():
			civ.waiting_mana_city_turns += 1
		elif city.city_upgrade_waiting_for_gold() > 0:
			civ.waiting_gold_city_turns += 1

func _on_unit_removed(former_owner: PlayerData, unit: Unit) -> void:
	var civ := _civ_of(former_owner)
	if civ.is_empty() or unit == null:
		return
	var turn := TurnManager.turn_number
	var died := unit.hp <= 0.0
	if unit.unit_data.can_found_city:
		if died:
			civ.settlers.lost += 1
		else:
			civ.settlers.consumed += 1
		return
	if not died:
		return
	civ._meaningful = true
	civ.combat.unit_deaths += 1
	match_counters.unit_deaths += 1
	if V2ManifestationSystem.is_manifestation_unit(unit):
		civ.manifestations.deaths.append({"turn": turn, "school": V2ManifestationSystem.school_of_kind(unit.unit_data.visual_kind)})
	var index := int(civ.index)
	for key in _active_wars.keys():
		var war: Dictionary = wars[_active_wars[key]]
		if int(war.initiator) == index or int(war.target) == index:
			war.unit_losses[str(index)] = int(war.unit_losses[str(index)]) + 1
			war._activity_this_turn = true

func _on_combat_engagement(attacker_owner: PlayerData, defender_owner: PlayerData, target_kind: String, target_coord: Vector2i) -> void:
	match_counters.engagements += 1
	var attacker := _civ_of(attacker_owner)
	var defender := _civ_of(defender_owner)
	var turn := TurnManager.turn_number
	# Fase 33D1: engagement por lado (civ × civ separado de civ × monstro) e uso de unidade.
	for side in [attacker, defender]:
		if not side.is_empty():
			side._meaningful = true
	if not attacker.is_empty() and not defender.is_empty():
		_mark(attacker, "first_pvp_combat", turn)
		_mark(defender, "first_pvp_combat", turn)
		var key := _pair_key(int(attacker.index), int(defender.index))
		if _active_wars.has(key):
			var war: Dictionary = wars[_active_wars[key]]
			if target_kind == "city":
				war.pair_city_attacks = int(war.pair_city_attacks) + 1
			else:
				war.pair_engagements = int(war.pair_engagements) + 1
	elif attacker_owner == null and not defender.is_empty():
		_mark(defender, "first_monster_attack", turn)
	elif defender_owner == null and not attacker.is_empty():
		_mark(attacker, "first_monster_attack", turn)
	if not attacker.is_empty():
		_mark_unit_use(attacker, turn)
		if target_kind == "city":
			_mark(attacker, "first_city_attack", turn)
		# Fase 33D2 (auditoria anti-onisciência): ataque a ESTRUTURA de covil fora do conhecimento do atacante
		# (explored_tiles) seria vazamento — o laboratório exige 0.
		if target_kind == "lair":
			attacker.lairs.structure_attacks = int(attacker.lairs.structure_attacks) + 1
			if not (attacker.player as PlayerData).explored_tiles.has(target_coord):
				attacker.lairs.structure_attacks_unknown = int(attacker.lairs.structure_attacks_unknown) + 1
		# Fase 33D2: ataque a monstro/estrutura do próprio covil regional conta como primeira resposta;
		# ataque junto a um Guardião, como engajamento do Guardião.
		if defender_owner == null:
			if bool(attacker.regional_threat.exists) and int(attacker.regional_threat.cleared_turn) < 0 and HexMetrics.axial_distance(target_coord, attacker._regional_coord) <= REGIONAL_ENGAGE_RADIUS:
				_regional_response(attacker, turn)
			for site in WorldEventManager.guardian_sites:
				if HexMetrics.axial_distance(target_coord, site.coord) <= 1 and int(attacker.guardian.engaged_turn) < 0:
					attacker.guardian.engaged_turn = turn
	if not defender.is_empty() and target_kind == "unit":
		_mark_unit_use(defender, turn)
	if not attacker.is_empty():
		attacker.combat.engagements += 1
		if target_kind == "city":
			attacker.combat.city_attacks += 1
			match_counters.city_attacks += 1
			var city := GameManager.hex_grid.get_city_at(target_coord) if GameManager.hex_grid != null else null
			if city != null and city.is_developed_v2():
				attacker.combat.developed_city_attacks += 1
	if not defender.is_empty():
		defender.combat.engagements_received += 1

## Primeiro uso de uma unidade própria em combate (atacando, defendendo ou contra covil) e, à parte, o
## primeiro uso DEPOIS da primeira unidade de combate produzida (base do units_without_purpose_lag).
func _mark_unit_use(civ: Dictionary, turn: int) -> void:
	_mark(civ, "first_unit_use", turn)
	if civ.milestones.has("first_combat_unit"):
		_mark(civ, "first_unit_use_after_production", turn)

func _on_world_phase_changed(_old_phase: int, new_phase: int, turn: int, cause: String) -> void:
	match new_phase:
		WorldPhaseRules.Phase.ASCENSION:
			world_phase_timeline.ascension_turn = turn
			world_phase_timeline.ascension_cause = cause
		WorldPhaseRules.Phase.CONVERGENCE:
			world_phase_timeline.convergence_turn = turn
			world_phase_timeline.convergence_cause = cause

## Fase de evento mundial que envolve a civ: participante ou alvo anunciado.
func _on_world_event_phase_changed(event: WorldEvent, _old_phase: String, _new_phase: String) -> void:
	for index in civs.size():
		var involved: bool = event.participants.has(index)
		if "target_civ_index" in event and int(event.get("target_civ_index")) == index:
			involved = true
		if involved:
			civs[index]._meaningful = true

func _on_lair_cleared(player: PlayerData, lair_coord: Vector2i, _kind: String) -> void:
	var civ := _civ_of(player)
	if civ.is_empty():
		return
	civ._meaningful = true
	_mark(civ, "first_lair_cleared", TurnManager.turn_number)
	civ.lairs.cleared = int(civ.lairs.cleared) + 1
	var record := RegionalThreatSystem.record_for_lair(lair_coord)
	if not record.is_empty():
		if int(record.owner) == int(civ.index):
			civ.lairs.cleared_regional_own = int(civ.lairs.cleared_regional_own) + 1
		else:
			civ.lairs.cleared_regional_other = int(civ.lairs.cleared_regional_other) + 1
	elif not RegionalThreatSystem.guardian_for_lair(lair_coord).is_empty():
		civ.lairs.cleared_guardian = int(civ.lairs.cleared_guardian) + 1
	else:
		civ.lairs.cleared_wild = int(civ.lairs.cleared_wild) + 1

# --- Fase 33D2: ameaças regionais / Guardiões ------------------------------------------------------

func _init_regional(record: Dictionary) -> void:
	var index := int(record.owner)
	if index < 0 or index >= civs.size() or String(record.state) == RegionalThreatSystem.STATE_NONE:
		return
	var civ: Dictionary = civs[index]
	var regional: Dictionary = civ.regional_threat
	regional.exists = true
	regional.type = String(record.kind)
	regional.source = String(record.source)
	regional.distance = HexMetrics.axial_distance(record.anchor, record.coord)
	regional.created_turn = int(record.created_turn)
	regional.wake_turn = int(record.wake_turn)
	regional.visible_at_creation = bool(record.visible_at_creation)
	regional.corridor_violation = bool(record.get("corridor_violation", false))
	civ._regional_coord = record.coord
	world_threats.regional_total = int(world_threats.regional_total) + 1

## Primeira resposta: unidade de combate própria a ≤ REGIONAL_RESPONSE_RADIUS do covil depois da descoberta.
## Guerra + ameaça desperta: turnos contados para a vigia de guerra precoce.
func _observe_regional(civ: Dictionary, player: PlayerData, turn: int) -> void:
	var regional: Dictionary = civ.regional_threat
	if not bool(regional.exists) or int(regional.cleared_turn) >= 0:
		return
	var record := RegionalThreatSystem.record_for_index(int(civ.index))
	if not player.enemies.is_empty() and String(record.get("state", "")) == RegionalThreatSystem.STATE_AWAKE:
		regional.war_while_awake_turns = int(regional.war_while_awake_turns) + 1
	if int(regional.discovered_turn) < 0 or int(regional.first_response_turn) >= 0:
		return
	for unit in player.units:
		if is_instance_valid(unit) and V2StrategicAI.is_lair_responder(unit) and HexMetrics.axial_distance(unit.coord, civ._regional_coord) <= REGIONAL_RESPONSE_RADIUS:
			_regional_response(civ, turn)
			return

func _regional_response(civ: Dictionary, turn: int) -> void:
	var regional: Dictionary = civ.regional_threat
	if int(regional.first_response_turn) >= 0:
		return
	regional.first_response_turn = turn
	_mark(civ, "regional_threat_first_response", turn)
	civ._meaningful = true

func _on_regional_threat_awakened(owner_player: PlayerData, _lair_coord: Vector2i, _kind: String) -> void:
	var civ := _civ_of(owner_player)
	if not civ.is_empty():
		civ.regional_threat.awake_turn = TurnManager.turn_number

func _on_world_threat_discovered(player: PlayerData, lair_coord: Vector2i, role: String) -> void:
	var civ := _civ_of(player)
	if civ.is_empty():
		return
	var turn := TurnManager.turn_number
	if role == HexGrid.LAIR_ROLE_GUARDIAN:
		if int(civ.guardian.discovered_turn) < 0:
			civ.guardian.discovered_turn = turn
		civ._meaningful = true
		return
	if lair_coord != civ._regional_coord:
		return
	civ.regional_threat.discovered_turn = turn
	civ.objectives.issued = int(civ.objectives.issued) + 1
	_mark(civ, "regional_threat_discovered", turn)
	civ._meaningful = true

func _on_world_threat_resolved(role: String, owner_player: PlayerData, lair_coord: Vector2i, resolver: PlayerData) -> void:
	var turn := TurnManager.turn_number
	if role == HexGrid.LAIR_ROLE_GUARDIAN:
		world_threats.guardian_resolved = int(world_threats.guardian_resolved) + 1
		var resolver_civ := _civ_of(resolver)
		if not resolver_civ.is_empty():
			resolver_civ.guardian.resolved = int(resolver_civ.guardian.resolved) + 1
		return
	var civ := _civ_of(owner_player)
	if civ.is_empty() or lair_coord != civ._regional_coord:
		return
	var regional: Dictionary = civ.regional_threat
	regional.cleared_turn = turn
	regional.resolved_by_index = _players.find(resolver)
	regional.resolved_by = "self" if resolver == owner_player else "other"
	if resolver == owner_player:
		_mark(civ, "regional_threat_cleared", turn)
		if int(regional.discovered_turn) >= 0:
			civ.objectives.resolved = int(civ.objectives.resolved) + 1
	elif int(regional.discovered_turn) >= 0:
		civ.objectives.resolved_by_other = int(civ.objectives.resolved_by_other) + 1

# --- Fase 33D3: grandes eventos, marcos públicos, imperativos, sobreposição ---------------------------

## Uma vez por rodada: progresso do Relicário (respondentes a ≤ 3 do local, contestação) e, na Ascensão, a
## sobreposição de pressões simultâneas (ameaça regional viva, Guardião ativo, grande evento ativo, guerra).
func _observe_d3_round(turn: int) -> void:
	var active_reliquary := WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE) as ReliquaryEvent
	if active_reliquary != null:
		_track_reliquary(active_reliquary, turn)
	var active_dragon := WorldEventManager.active_event_of_type(DragonEvent.EVENT_TYPE) as DragonEvent
	if active_dragon != null:
		_track_dragon(active_dragon)
	if WorldEventManager.world_phase == WorldPhaseRules.Phase.CONVERGENCE:
		for civ in civs:
			if (civ.imperatives_at_convergence as Dictionary).is_empty():
				civ.imperatives_at_convergence = _imperative_steps(civ.player)
	if WorldEventManager.world_phase != WorldPhaseRules.Phase.ASCENSION:
		return
	var regional := false
	for record in WorldEventManager.regional_threats:
		regional = regional or String(record.state) in [RegionalThreatSystem.STATE_DORMANT, RegionalThreatSystem.STATE_AWAKE]
	var guardian := false
	for site in WorldEventManager.guardian_sites:
		guardian = guardian or String(site.state) == RegionalThreatSystem.GUARDIAN_ACTIVE
	var war := false
	for civ in civs:
		war = war or not (civ.player as PlayerData).enemies.is_empty()
	var count := int(regional) + int(guardian) + int(WorldEventManager.has_active_major_event()) + int(war)
	overlap.ascension_rounds = int(overlap.ascension_rounds) + 1
	overlap.rounds_by_count[str(count)] = int(overlap.rounds_by_count[str(count)]) + 1
	if count == 4:
		overlap.all_four_turns.append(turn)

func _track_dragon(event: DragonEvent) -> void:
	dragon.target = event.target_civ_index
	for index in event.participants:
		dragon.participants[str(index)] = {"decision": bool(event.participants[index].get("decision", false)), "reason": String(event.participants[index].get("reason", ""))}
	for index in event.damage_by_civ:
		dragon.damage_by_civ[str(index)] = snappedf(float(event.damage_by_civ[index]), 0.01)

func _track_reliquary(event: ReliquaryEvent, turn: int) -> void:
	if event.phase == WorldEvent.PHASE_ACTIVE and int(reliquary.active_turn) < 0:
		reliquary.active_turn = turn
	reliquary.site = [event.site_coord.x, event.site_coord.y]
	reliquary.guardian_clear_turn = event.guardians_cleared_turn
	reliquary.max_control_progress = maxi(int(reliquary.max_control_progress), event.max_control_rounds)
	reliquary.contested_rounds = event.contested_rounds
	for civ in civs:
		if (reliquary.responders as Dictionary).has(str(civ.index)):
			continue
		for unit in (civ.player as PlayerData).units:
			if is_instance_valid(unit) and V2StrategicAI.is_lair_responder(unit) and HexMetrics.axial_distance(unit.coord, event.site_coord) <= 3:
				reliquary.responders[str(civ.index)] = turn
				civ._meaningful = true
				break

func _on_world_event_announced(event: WorldEvent) -> void:
	var turn := TurnManager.turn_number
	if event is DragonEvent:
		dragon.announced = true
		dragon.announce_turn = turn
		dragon.phase_at_start = WorldPhaseRules.id_name(WorldEventManager.world_phase)
		for civ in civs:
			civ.objectives.issued = int(civ.objectives.issued) + 1
	elif event is ReliquaryEvent:
		reliquary.announced = true
		reliquary.announce_turn = turn
		reliquary.site = [(event as ReliquaryEvent).site_coord.x, (event as ReliquaryEvent).site_coord.y]
		for civ in civs:
			civ.objectives.issued = int(civ.objectives.issued) + 1

func _on_world_event_completed(event: WorldEvent, result: Dictionary) -> void:
	var turn := TurnManager.turn_number
	if event is DragonEvent:
		_track_dragon(event as DragonEvent)
		dragon.resolution_turn = turn
		dragon.result = String(result.get("outcome", ""))
		dragon.phase_at_end = WorldPhaseRules.id_name(WorldEventManager.world_phase)
		for index in result.get("rewards", {}):
			dragon.reward_by_civ[str(index)] = result.rewards[index].duplicate()
		for civ in civs:
			if dragon.result == "defeated" and float(dragon.damage_by_civ.get(str(civ.index), 0.0)) > 0.0:
				civ.objectives.resolved = int(civ.objectives.resolved) + 1
			elif dragon.result == "defeated":
				civ.objectives.resolved_by_other = int(civ.objectives.resolved_by_other) + 1
	elif event is ReliquaryEvent:
		var reliquary_event := event as ReliquaryEvent
		_track_reliquary(reliquary_event, turn)
		reliquary.resolved_turn = int(result.get("resolved_turn", turn))
		reliquary.result = String(result.get("outcome", ""))
		reliquary.winner = reliquary_event.winner_index
		reliquary.reward_choice = reliquary_event.reward_choice
		for civ in civs:
			if int(civ.index) == reliquary_event.winner_index:
				civ.objectives.resolved = int(civ.objectives.resolved) + 1
			else:
				civ.objectives.resolved_by_other = int(civ.objectives.resolved_by_other) + 1

func _on_public_milestone_reached(player: PlayerData, milestone: String) -> void:
	var civ := _civ_of(player)
	if not civ.is_empty():
		civ.public_milestones[milestone] = TurnManager.turn_number
		civ._meaningful = true

func _finish_dragon() -> Dictionary:
	var schedule := WorldEventManager.dragon_schedule
	dragon.eligible_turn = int(schedule.get("eligible_turn", -1))
	dragon.forced = bool(schedule.get("forced", false))
	dragon.convergence_edge = bool(schedule.get("convergence_edge", false))
	if String(schedule.get("state", "")) == WorldEventManager.SCHEDULE_SUPERSEDED:
		dragon.superseded_reason = String(schedule.get("superseded_reason", ""))
	var active := WorldEventManager.active_event_of_type(DragonEvent.EVENT_TYPE) as DragonEvent
	if active != null:
		_track_dragon(active)
		dragon.result = "active_at_end:%s" % active.phase
	return dragon.duplicate(true)

func _finish_reliquary() -> Dictionary:
	var schedule := WorldEventManager.reliquary_schedule
	reliquary.eligible_turn = int(schedule.get("eligible_turn", -1))
	reliquary.waited_for_dragon = bool(schedule.get("waited_for_dragon", false))
	if String(schedule.get("state", "")) == WorldEventManager.SCHEDULE_SUPERSEDED:
		reliquary.superseded_reason = String(schedule.get("superseded_reason", ""))
		for civ in civs:
			civ.objectives.superseded = int(civ.objectives.superseded) + 1
	var active := WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE) as ReliquaryEvent
	if active != null:
		_track_reliquary(active, TurnManager.turn_number)
		reliquary.result = "active_at_end:%s" % active.phase
	return reliquary.duplicate(true)

static func _imperative_steps(player: PlayerData) -> Dictionary:
	var result := {}
	for imperative in StrategicImperatives.for_player(player):
		result[String(imperative.route)] = String(imperative.step)
	return result

func _on_guardian_site_spawned(_lair_coord: Vector2i, _resource_coord: Vector2i, resource: String) -> void:
	world_threats.guardian_sites_spawned = int(world_threats.guardian_sites_spawned) + 1
	world_threats.guardian_resources[resource] = int(world_threats.guardian_resources.get(resource, 0)) + 1
	world_threats.guardian_spawn_turn = TurnManager.turn_number
	world_threats.guardian_stats = WorldEventManager.guardian_stats.duplicate(true)

func _on_tile_pillaged(owner_player: PlayerData, _coord: Vector2i) -> void:
	_set_meaningful(owner_player)

func _on_ritual_progressed(player: PlayerData, _site_coord: Vector2i, _remaining_rounds: int) -> void:
	_set_meaningful(player)

func _on_ritual_started(player: PlayerData, site_coord: Vector2i, remaining_rounds: int) -> void:
	var index := _players.find(player)
	if index < 0:
		return
	var turn := TurnManager.turn_number
	var city := GameManager.hex_grid.get_city_at(site_coord) if GameManager.hex_grid != null else null
	_active_ritual_by_owner[index] = rituals.size()
	rituals.append({
		"owner": index,
		"race": civs[index].race,
		"orientation": civs[index].orientation,
		"start_turn": turn,
		"city": city.city_name if city != null else "",
		"site": [site_coord.x, site_coord.y],
		"rounds_at_start": remaining_rounds,
		"rounds_remaining": remaining_rounds,
		"interrupted": false,
		"interruption_turn": -1,
		"interruption_reason": "",
		"interruption_reason_raw": "",
		"completed": false,
		"completion_turn": -1,
		"active_at_game_end": false,
	})
	_mark(civs[index], "first_ritual_start", turn)
	civs[index]._meaningful = true

func _on_ritual_interrupted(player: PlayerData, _site_coord: Vector2i, reason: String) -> void:
	var index := _players.find(player)
	if index < 0 or not _active_ritual_by_owner.has(index):
		return
	var ritual: Dictionary = rituals[_active_ritual_by_owner[index]]
	ritual.interrupted = true
	ritual.interruption_turn = TurnManager.turn_number
	ritual.interruption_reason_raw = reason
	ritual.interruption_reason = String(INTERRUPT_REASON_MAP.get(reason, "other"))
	ritual.rounds_remaining = -1
	_active_ritual_by_owner.erase(index)

# --- Finalização --------------------------------------------------------------------------------

func _finalize_civ(civ: Dictionary, turn: int) -> void:
	var player: PlayerData = civ.player
	civ.final_status = "eliminated" if int(civ.eliminated_turn) >= 0 else ("winner" if not victory.is_empty() and int(victory.winner_index) == int(civ.index) else "alive")
	civ.final_turn = turn
	civ.final_city_count = player.cities.size()
	var developed := 0
	for city in player.cities:
		developed += 1 if city.is_developed_v2() else 0
	civ.developed_city_count = developed
	civ.final_unit_count = player.units.size()
	civ.final_relevant_units = V2StrategicAI.relevant_unit_count(player)
	civ.final_gold = snappedf(player.gold, 0.01)
	civ.final_gold_net = snappedf(V2EconomyRuntime.player_gold_net_income(player), 0.01)
	civ.final_mana = snappedf(player.mana, 0.01)
	civ.final_knowledge_income = snappedf(V2EconomyRuntime.player_knowledge_income(player), 0.01)
	civ.final_supply_used = V2LogisticsRuntime.player_supply_used(player)
	civ.final_supply_capacity = snappedf(V2EconomyRuntime.player_supply_capacity(player), 0.01)
	civ.final_focus = V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus)
	civ.research.partial_nodes = player.v2_research.progress_by_id.size()
	civ.research.completed_count = player.v2_research.completed_ids.size()
	civ.research.invested = knowledge_invested_by_tree(player)
	civ.research.knowledge_generated = snappedf(_knowledge_generated(player), 0.01)
	civ.research.overflow = snappedf(player.v2_research.research_overflow, 0.01)
	civ.research.active_at_end = player.v2_research.active_id
	civ.settlers.unused_at_end = player.units.filter(func(u): return is_instance_valid(u) and u.unit_data.can_found_city).size()
	civ.war_fraction = snappedf(float(civ.war_turns) / maxf(float(match_counters.turns_observed), 1.0), 0.001)
	var produced := int(civ.milestones.get("first_combat_unit", -1))
	var used := int(civ.milestones.get("first_unit_use_after_production", -1))
	civ.units_without_purpose_lag = used - produced if produced >= 0 and used >= 0 else -1
	civ.imperatives_at_end = _imperative_steps(player)
	civ.ritual_attempts = rituals.filter(func(r): return int(r.owner) == int(civ.index)).size()
	civ.ritual_interruptions = rituals.filter(func(r): return int(r.owner) == int(civ.index) and bool(r.interrupted)).size()
	civ.ritual_interruption_loop = int(civ.ritual_interruptions) >= RITUAL_LOOP_INTERRUPTIONS
	# Diagnóstico NO-VICTORY-PURSUIT (seção 82): acesso de vitória obtido e, NO_PURSUIT_TURNS turnos
	# depois, nenhum progresso prático registrado na rota.
	var flags := {}
	var sup_ready := int(civ.milestones.get("supremacy_research_ready", -1))
	if sup_ready >= 0 and turn - sup_ready >= NO_PURSUIT_TURNS:
		var qualifying_after := 0
		for rival in civ.supremacy_rivals.values():
			if int(rival.first_qualifying_capture) >= sup_ready:
				qualifying_after += 1
		flags.supremacy_no_pursuit = qualifying_after == 0 and int(civ.combat.developed_city_attacks) == 0
	var tr_ready := int(civ.milestones.get("transcendence_research_ready", -1))
	if tr_ready >= 0 and turn - tr_ready >= NO_PURSUIT_TURNS:
		var produced_after: int = civ.manifestations.produced.filter(func(m): return int(m.turn) >= tr_ready).size()
		flags.transcendence_no_pursuit = produced_after == 0 and int(civ.ritual_attempts) == 0
	var ritual_ready := int(civ.milestones.get("transcendence_ritual_ready", -1))
	if ritual_ready >= 0 and turn - ritual_ready >= NO_PURSUIT_TURNS:
		flags.ritual_ready_never_started = int(civ.ritual_attempts) == 0
	civ.diagnostic_flags = flags
	for war in wars:
		war.possible_stalemate = int(war.max_quiet_streak) >= STALEMATE_QUIET_TURNS
		war.erase("_quiet")
		war.erase("_activity_this_turn")

func _timeout_entry(civ: Dictionary, turn: int) -> Dictionary:
	var player: PlayerData = civ.player
	var entry := {"index": civ.index, "race": civ.race, "orientation": civ.orientation, "alive": not V2VictoryConditions.is_eliminated(player)}
	var sup := V2VictoryConditions.military_supremacy_status(player)
	var doctrine_n9: int = civ.research.n9_branches.military.size()
	var school_n9: int = civ.research.n9_branches.magic.size()
	var sup_gates := [doctrine_n9 >= 1, doctrine_n9 >= 2, bool(sup.access)]
	var sup_missing: Array = []
	if doctrine_n9 < 2:
		sup_missing.append({"requirement": "two_doctrine_n9", "have": doctrine_n9, "missing_turns": turn - 1})
	if not sup.access:
		sup_missing.append({"requirement": "supreme_army", "missing_turns": turn - maxi(1, int(civ.milestones.get("military_n9_second", 1)))})
	var access_turn := int(civ.milestones.get("supremacy_research_ready", -1))
	for rival in sup.rivals:
		sup_gates.append(bool(rival.satisfied))
		if not bool(rival.satisfied):
			sup_missing.append({"requirement": "rival_%d_satisfied" % int(rival.player_id), "missing_turns": (turn - access_turn) if access_turn >= 0 else turn - 1, "since": "access" if access_turn >= 0 else "match_start"})
	var has_structure := false
	for city in player.cities:
		if V2TranscendenceSystem.city_has_usable_magic_ritual_structure(city, player):
			has_structure = true
			break
	var manifestations := V2ManifestationSystem.active_manifestation_count(player)
	var tr_access := V2TranscendenceSystem.has_access(player)
	var tr_gates := [school_n9 >= 1, school_n9 >= 2, tr_access, has_structure, manifestations >= 1, manifestations >= 2, player.mana >= V2TranscendenceSystem.MANA_COST, V2TranscendenceSystem.has_active_ritual(player)]
	var tr_missing: Array = []
	var tr_access_turn := int(civ.milestones.get("transcendence_research_ready", -1))
	var since := (turn - tr_access_turn) if tr_access_turn >= 0 else turn - 1
	if school_n9 < 2:
		tr_missing.append({"requirement": "two_school_n9", "have": school_n9, "missing_turns": turn - 1})
	if not tr_access:
		tr_missing.append({"requirement": "transcendence_research", "missing_turns": turn - maxi(1, int(civ.milestones.get("magic_n9_second", 1)))})
	if not has_structure:
		tr_missing.append({"requirement": "ritual_structure_city", "missing_turns": since})
	if manifestations < 2:
		tr_missing.append({"requirement": "two_active_manifestations", "have": manifestations, "missing_turns": since})
	if player.mana < V2TranscendenceSystem.MANA_COST:
		tr_missing.append({"requirement": "mana_%d" % int(V2TranscendenceSystem.MANA_COST), "have": snappedf(player.mana, 0.01), "missing_turns": since})
	var eliminated_rivals := 0
	for other in _players:
		if other != player and V2VictoryConditions.is_eliminated(other):
			eliminated_rivals += 1
	var dom_gates := []
	for i in _players.size() - 1:
		dom_gates.append(i < eliminated_rivals)
	var paths := {
		"MILITARY_SUPREMACY": {"gates_passed": sup_gates.count(true), "gates_total": sup_gates.size(), "missing": sup_missing, "satisfied_rivals": sup.satisfied_count},
		"TRANSCENDENCE": {"gates_passed": tr_gates.count(true), "gates_total": tr_gates.size(), "missing": tr_missing, "manifestations": manifestations, "has_ritual_structure": has_structure, "mana": snappedf(player.mana, 0.01)},
		"DOMINATION": {"gates_passed": dom_gates.count(true), "gates_total": dom_gates.size(), "missing": [{"requirement": "rivals_eliminated", "have": eliminated_rivals, "need": _players.size() - 1}]},
	}
	# "Mais próxima" = maior fração de gates ordenados já cumpridos (ordem da regra real; não é score).
	var closest := ""
	var best := -1.0
	for path in paths:
		var fraction := float(paths[path].gates_passed) / maxf(float(paths[path].gates_total), 1.0)
		if fraction > best:
			best = fraction
			closest = path
	entry.closest_path = closest
	entry.paths = paths
	var active_wars: Array = []
	for enemy in player.enemies:
		active_wars.append(GameManager.players.find(enemy))
	entry.active_wars = active_wars
	entry.ritual_history = rituals.filter(func(r): return int(r.owner) == int(civ.index))
	entry.capstones = {"supreme_army": player.v2_research.is_completed(V2ResearchDatabase.SUPREME_ARMY_ID), "transcendence": player.v2_research.is_completed(V2ResearchDatabase.TRANSCENDENCE_ID)}
	entry.focus = V2AIStrategyState.focus_name(player.v2_ai_strategy.victory_focus)
	return entry

# --- Geografia (proxies baratos) ----------------------------------------------------------------

func _capture_geography() -> void:
	var grid: HexGrid = GameManager.hex_grid
	if grid == null:
		return
	grid._ensure_land_components()
	var capitals := []
	for index in _players.size():
		var player: PlayerData = _players[index]
		var coord := Vector2i(999999, 999999)
		if not player.cities.is_empty():
			coord = player.cities[0].coord
		capitals.append(coord)
	var seats := []
	for index in capitals.size():
		var nearest := 999999
		var same_landmass := 0
		var component: int = grid._land_components.get(capitals[index], -1)
		for other in capitals.size():
			if other == index:
				continue
			nearest = mini(nearest, HexMetrics.axial_distance(capitals[index], capitals[other]))
			if component >= 0 and grid._land_components.get(capitals[other], -2) == component:
				same_landmass += 1
		seats.append({
			"index": index,
			"race": _players[index].civ.race,
			"capital": [capitals[index].x, capitals[index].y],
			"nearest_rival_distance": nearest,
			"land_component": component,
			"rivals_same_landmass": same_landmass,
		})
	geography = {"seats": seats}
