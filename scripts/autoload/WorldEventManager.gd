extends Node

## Autoload -- possui a LISTA de eventos mundiais ativos (ver docs/WORLD_
## EVENT_CONTRACT.md, secao 2 "Ownership do estado"). GameManager nao
## conhece detalhes internos de evento nenhum -- so chama advance_turn()
## (ver GameManager._finish_turn(), ordem exata no contrato secao 1) e
## ouve o EventBus.
##
## Escopo genérico (Fase Macro, Steps 2-4): possuir, avançar, concluir,
## emitir e remover eventos de forma determinística e isolada. A partir do
## Step 5B.1, `maybe_spawn_dragon` cobre EXCLUSIVAMENTE o Blocker #1 do
## contrato comportamental do Dragão (docs/DRAGON_EVENT_DESIGN.md) --
## seleção de alvo, participação, UI, e combate continuam fora daqui.

var active_events: Array[WorldEvent] = []
var _next_event_id: int = 0

## Fase 33D1 — política de repetição por tipo de evento. Sem entrada = pode repetir (comportamento antigo).
## ONCE_PER_GAME: depois que UM evento do tipo conclui (qualquer desfecho), o tipo nunca mais nasce nesta
## partida — corrige o Dragão que voltava a ser sorteado depois de resolvido.
const REPEAT_ONCE_PER_GAME := "ONCE_PER_GAME"
const REPEAT_POLICY := {"dragon": REPEAT_ONCE_PER_GAME, "reliquary": REPEAT_ONCE_PER_GAME}

## Fase 33D3 — AGENDAMENTO dos grandes eventos da Ascensão (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md
## §8). Dragão: só INICIA na Ascensão; elegível DRAGON_ELIGIBLE_AFTER rodadas depois da entrada nela; depois,
## o gatilho probabilístico existente (WorldEventTrigger, 2%/rodada); garantido a partir de
## DRAGON_GUARANTEE_AFTER; na virada para a Convergência, se nunca ocorreu e a Ascensão já durou o bastante,
## é anunciado na mesma rodada da transição. Relicário: elegível RELIQUARY_ELIGIBLE_AFTER rodadas depois da
## Ascensão; o Dragão tem prioridade — com o Dragão ativo o Relicário espera (e depois RELIQUARY_AFTER_DRAGON
## rodadas da resolução); se o Dragão ainda pode começar, o Relicário só é anunciado quando sua duração máxima
## (ReliquaryEvent.MAX_DURATION) termina antes da garantia do Dragão; a Convergência o supersede se ele ainda
## não foi anunciado. No máximo UM grande evento (Dragão/Relicário) ativo; ameaças regionais e
## Guardiões não contam.
const DRAGON_ELIGIBLE_AFTER := 10
const DRAGON_GUARANTEE_AFTER := 35
const RELIQUARY_ELIGIBLE_AFTER := 15
const RELIQUARY_AFTER_DRAGON := 5
const MAJOR_EVENT_TYPES := ["dragon", "reliquary"]
const SCHEDULE_PENDING := "PENDING"
const SCHEDULE_ANNOUNCED := "ANNOUNCED"
const SCHEDULE_RESOLVED := "RESOLVED"
const SCHEDULE_SUPERSEDED := "SUPERSEDED"

## Fase 33D1 — estado do MUNDO desta partida (dono único; ver docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_
## DESIGN.md). `world_phase` é WorldPhaseRules.Phase; `phase_history` guarda {phase, turn, cause} de cada
## entrada em era (INITIAL/PROGRESS/FALLBACK/MIGRATED); `completed_event_types` conta eventos concluídos
## por event_type. Tudo persistido em to_save_dict.
var world_phase: int = WorldPhaseRules.Phase.FOUNDATION
var phase_history: Array[Dictionary] = [{"phase": WorldPhaseRules.Phase.FOUNDATION, "turn": 1, "cause": WorldPhaseRules.CAUSE_INITIAL}]
var completed_event_types: Dictionary = {}
## Fase 33D2 — ameaças do mundo (RegionalThreatSystem; colocação em RegionalThreatPlanner). Só partidas
## novas pós-D2 ligam `regional_threats_enabled` (GameManager._spawn_starting_forces); save antigo carrega
## desligado e nunca ganha ameaça/guardião retroativo.
var regional_threats_enabled := false
var regional_threats: Array[Dictionary] = []
var guardian_sites: Array[Dictionary] = []
var guardians_spawned := false
## Estatística da última escolha de Guardiões (survey/telemetria; não salva).
var guardian_stats: Dictionary = {}
## Fase 33D3 — estado dos agendadores (salvo): {state, eligible_turn, announce_turn, forced, resolution_turn,
## superseded_reason, target_deferred_rounds, phase_at_start}. Ausente num save antigo = derivado no próximo round.
var dragon_schedule: Dictionary = {}
var reliquary_schedule: Dictionary = {}
## Fase 33D3 — marcos públicos já anunciados, por índice de civ: {"supreme_army": turno, "second_manifestation":
## turno}. Cada marco é anunciado UMA vez por civ por partida (PublicVictoryMilestones).
var public_milestones: Dictionary = {}

## Partida nova (GameManager.setup_players — também o primeiro passo do load, que restaura por cima):
## nenhum evento ativo, Era do Despertar desde `turn`, nada concluído.
func reset_for_new_match(turn: int = 1) -> void:
	active_events.clear()
	_next_event_id = 0
	world_phase = WorldPhaseRules.Phase.FOUNDATION
	phase_history = [{"phase": WorldPhaseRules.Phase.FOUNDATION, "turn": turn, "cause": WorldPhaseRules.CAUSE_INITIAL}]
	completed_event_types = {}
	regional_threats_enabled = false
	regional_threats = []
	guardian_sites = []
	guardians_spawned = false
	guardian_stats = {}
	RegionalThreatSystem.defer_planning = false
	MonsterEcologySystem.reset() # V3: registro/alvos/reposição/RNG da ecologia nunca vazam entre partidas
	dragon_schedule = {}
	reliquary_schedule = {}
	public_milestones = {}

func phase_entered_turn() -> int:
	return int(phase_history.back().turn) if not phase_history.is_empty() else 1

## Avalia a era UMA vez por rodada global (GameManager._finish_turn, antes de check_victories). No máximo um
## passo por chamada, nunca regride; emite EventBus.world_phase_changed só quando muda.
func advance_world_phase(players: Array[PlayerData], turn: int) -> bool:
	var transition := WorldPhaseRules.next_transition(world_phase, turn, players)
	if transition.is_empty():
		return false
	if int(transition.phase) == WorldPhaseRules.Phase.CONVERGENCE:
		_close_ascension_events(GameManager.hex_grid, players, turn)
	var old_phase := world_phase
	world_phase = int(transition.phase)
	phase_history.append({"phase": world_phase, "turn": turn, "cause": String(transition.cause)})
	EventBus.world_phase_changed.emit(old_phase, world_phase, turn, String(transition.cause))
	# Fase 33D2: Guardiões Troll nascem uma única vez, na entrada da Ascensão (guardians_spawned barra repetição).
	if world_phase == WorldPhaseRules.Phase.ASCENSION:
		RegionalThreatSystem.spawn_guardians(GameManager.hex_grid, turn)
	return true

## Turno de entrada na Ascensão (-1 se o mundo nunca chegou lá).
func ascension_turn() -> int:
	for entry in phase_history:
		if int(entry.phase) == WorldPhaseRules.Phase.ASCENSION:
			return int(entry.turn)
	return -1

func has_active_major_event() -> bool:
	for event in active_events:
		if event.event_type in MAJOR_EVENT_TYPES and not event.is_completed():
			return true
	return false

func active_event_of_type(event_type: String) -> WorldEvent:
	for event in active_events:
		if event.event_type == event_type:
			return event
	return null

func event_by_id(event_id: int) -> WorldEvent:
	for event in active_events:
		if event.event_id == event_id:
			return event
	return null

## Primeira rodada em que o Dragão ainda pendente é garantido: Ascensão+35 ou a Convergência mais cedo possível
## (o piso dela) — o que vier antes. Um grande evento ativo nessa rodada tomaria o lugar do Dragão.
func dragon_guarantee_deadline() -> int:
	return mini(ascension_turn() + DRAGON_GUARANTEE_AFTER, WorldPhaseRules.CONVERGENCE_FLOOR_TURN)

## O Dragão desta partida ainda pode começar? (nunca concluído, não ativo, não supersedido)
func dragon_still_pending() -> bool:
	return can_start_event_type(DragonEvent.EVENT_TYPE) and String(dragon_schedule.get("state", "")) != SCHEDULE_SUPERSEDED

## Virada Ascensão → Convergência (antes da transição): garante o anúncio do Dragão que nunca ocorreu se a
## Ascensão já durou DRAGON_ELIGIBLE_AFTER rodadas e não há grande evento ativo; senão (ou sem alvo) o registra
## como SUPERSEDED. O Relicário ainda não anunciado é SUPERSEDED (nunca nasce na Convergência).
func _close_ascension_events(hex_grid: HexGrid, players: Array[PlayerData], turn: int) -> void:
	if dragon_still_pending():
		var asc := ascension_turn()
		if asc >= 0 and turn >= asc + DRAGON_ELIGIBLE_AFTER and not has_active_major_event() and hex_grid != null:
			if DragonEvent.eligible_target_indices(players).is_empty():
				_supersede_dragon("NO_VALID_TARGET", turn)
			else:
				var event := _start_dragon(hex_grid, turn, true)
				# Anunciado NESTA rodada (o avanço normal de eventos desta rodada já passou).
				var before := event.phase
				event.advance_turn(hex_grid, players)
				if event.phase != before:
					EventBus.world_event_phase_changed.emit(event, before, event.phase)
				dragon_schedule["convergence_edge"] = true
		else:
			_supersede_dragon("CONVERGENCE", turn)
	if String(reliquary_schedule.get("state", "")) in ["", SCHEDULE_PENDING] and can_start_event_type(ReliquaryEvent.EVENT_TYPE):
		reliquary_schedule["state"] = SCHEDULE_SUPERSEDED
		reliquary_schedule["superseded_turn"] = turn
		reliquary_schedule["superseded_reason"] = "CONVERGENCE"

func _supersede_dragon(reason: String, turn: int) -> void:
	dragon_schedule["state"] = SCHEDULE_SUPERSEDED
	dragon_schedule["superseded_reason"] = reason
	dragon_schedule["superseded_turn"] = turn

## Um evento deste tipo pode nascer agora? Respeita REPEAT_POLICY e nunca dois do mesmo tipo ativos.
func can_start_event_type(event_type: String) -> bool:
	for event in active_events:
		if event.event_type == event_type:
			return false
	if String(REPEAT_POLICY.get(event_type, "")) == REPEAT_ONCE_PER_GAME:
		return int(completed_event_types.get(event_type, 0)) == 0
	return true

## Atribui event_id (contador interno, persistido — ver to_save_dict),
## adiciona a lista e emite world_event_announced. Nao forca fase nenhuma
## -- o proprio WorldEvent decide seu estado inicial antes de ser
## registrado (ver contrato secao 1: WorldEventManager nunca decide
## transicao de fase, so o evento).
func register_event(event: WorldEvent) -> void:
	event.event_id = _next_event_id
	_next_event_id += 1
	active_events.append(event)
	EventBus.world_event_announced.emit(event)

## Remocao explicita/controlada — usada tanto externamente quanto
## internamente por advance_turn() quando um evento conclui.
func remove_event(event: WorldEvent) -> void:
	active_events.erase(event)

## Chamado exatamente uma vez por turno real, so de dentro de
## GameManager._finish_turn() (contrato secao 1) -- NUNCA de UI, preview,
## save/load ou verificacao de vitoria. `events_this_turn` e uma
## fotografia estavel (duplicate()) da lista de proposito: remove_event()
## (chamado abaixo pra eventos concluidos, ou por qualquer coisa externa
## no meio do loop) nunca deveria mutar o Array sendo iterado agora --
## tambem deixa o comportamento bem definido se, no futuro, um evento
## gerar outro evento durante a propria resolucao (o novo evento so entra
## no PROXIMO advance_turn(), nunca no mesmo turno que o gerou).
func advance_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	var events_this_turn := active_events.duplicate()
	for event: WorldEvent in events_this_turn:
		if event.is_completed():
			continue # ja concluido e removido antes deste turno comecar -- defensivo, nao deveria acontecer de verdade
		var phase_before: String = event.phase
		event.advance_turn(hex_grid, players)
		if event.phase != phase_before:
			EventBus.world_event_phase_changed.emit(event, phase_before, event.phase)
		if event.is_completed():
			completed_event_types[event.event_type] = int(completed_event_types.get(event.event_type, 0)) + 1
			var schedule := dragon_schedule if event is DragonEvent else (reliquary_schedule if event is ReliquaryEvent else {})
			if event is DragonEvent or event is ReliquaryEvent:
				schedule["state"] = SCHEDULE_RESOLVED
				schedule["resolution_turn"] = TurnManager.turn_number
				schedule["outcome"] = String(event.result.get("outcome", ""))
			EventBus.world_event_completed.emit(event, event.result)
			remove_event(event)

## Verifica se o mundo deve criar um Dragao-evento neste turno (ver
## WorldEventTrigger, Blocker #1 do contrato comportamental) e, se sim,
## cria+registra o DragonEvent com sua regiao de origem ja definida --
## nunca o tile exato (isso so acontece na transicao pra Active, Blocker
## #3, ainda nao implementado). Nao cria um segundo Dragao-evento enquanto
## um ja estiver ativo -- guarda minima de v1 (decisao de implementacao,
## nao do contrato): evita duas expedicoes de Dragao simultaneas
## competindo pela mesma narrativa; reavaliar se/quando quisermos multiplos
## eventos simultaneos de verdade.
func maybe_spawn_dragon(hex_grid: HexGrid, turn: int) -> void:
	# Fase 33D1: ONCE_PER_GAME (REPEAT_POLICY) — um Dragão já resolvido nesta partida nunca volta.
	if _has_active_dragon() or not dragon_still_pending():
		return
	# Fase 33D3: só inicia na Ascensão, elegível DRAGON_ELIGIBLE_AFTER rodadas depois da entrada nela.
	var asc := ascension_turn()
	if world_phase != WorldPhaseRules.Phase.ASCENSION or asc < 0:
		return
	dragon_schedule["eligible_turn"] = asc + DRAGON_ELIGIBLE_AFTER
	if String(dragon_schedule.get("state", "")) == "":
		dragon_schedule["state"] = SCHEDULE_PENDING
	if turn < asc + DRAGON_ELIGIBLE_AFTER or has_active_major_event():
		return
	var forced := turn >= asc + DRAGON_GUARANTEE_AFTER
	if not forced and not WorldEventTrigger.should_spawn_dragon(hex_grid.map_seed, turn):
		return
	# Nenhuma civ com 2+ cidades: adia (dentro da Ascensão), nunca executa a civ de uma cidade.
	if DragonEvent.eligible_target_indices(GameManager.players).is_empty():
		dragon_schedule["target_deferred_rounds"] = int(dragon_schedule.get("target_deferred_rounds", 0)) + 1
		return
	_start_dragon(hex_grid, turn, forced)

func _start_dragon(hex_grid: HexGrid, turn: int, forced: bool) -> DragonEvent:
	var event := DragonEvent.new()
	event.origin_region = WorldEventTrigger.choose_dragon_origin_region(hex_grid.map_seed, turn, hex_grid)
	dragon_schedule["state"] = SCHEDULE_ANNOUNCED
	dragon_schedule["announce_turn"] = turn
	dragon_schedule["forced"] = forced
	dragon_schedule["phase_at_start"] = WorldPhaseRules.id_name(world_phase)
	register_event(event)
	return event

## Fase 33D3 — Relicário Desperto: uma vez por partida, só anunciado na Ascensão (ver o agendamento no topo).
func maybe_start_reliquary(hex_grid: HexGrid, turn: int) -> void:
	if hex_grid == null or not can_start_event_type(ReliquaryEvent.EVENT_TYPE):
		return
	var state := String(reliquary_schedule.get("state", ""))
	if state not in ["", SCHEDULE_PENDING]:
		return
	var asc := ascension_turn()
	if world_phase != WorldPhaseRules.Phase.ASCENSION or asc < 0:
		return
	reliquary_schedule["eligible_turn"] = asc + RELIQUARY_ELIGIBLE_AFTER
	if turn < asc + RELIQUARY_ELIGIBLE_AFTER:
		return
	reliquary_schedule["state"] = SCHEDULE_PENDING
	# Prioridade do Dragão: com o Dragão ativo, o Relicário espera. Se o Dragão da partida ainda pode começar, o
	# Relicário só é anunciado se terminar (duração máxima fixa) ANTES das DUAS garantias do Dragão: Ascensão+35
	# e a virada para a Convergência (que pode chegar antes, a partir do piso dela) — nunca as atrasa nem as ocupa.
	if _has_active_dragon() or has_active_major_event():
		reliquary_schedule["waited_for_dragon"] = true
		return
	if dragon_still_pending() and turn + ReliquaryEvent.MAX_DURATION >= dragon_guarantee_deadline():
		reliquary_schedule["waited_for_dragon"] = true
		return
	var dragon_resolved := int(dragon_schedule.get("resolution_turn", -1))
	if dragon_resolved >= 0 and turn < dragon_resolved + RELIQUARY_AFTER_DRAGON:
		return
	var site := ReliquaryEvent.choose_site(hex_grid, GameManager.players)
	if site == ReliquaryEvent.NO_COORD:
		reliquary_schedule["state"] = SCHEDULE_SUPERSEDED
		reliquary_schedule["superseded_reason"] = "NO_SITE"
		reliquary_schedule["superseded_turn"] = turn
		return
	var event := ReliquaryEvent.new()
	event.site_coord = site
	reliquary_schedule["state"] = SCHEDULE_ANNOUNCED
	reliquary_schedule["announce_turn"] = turn
	reliquary_schedule["site"] = [site.x, site.y]
	register_event(event)

## Escolha de recompensa do Relicário por quem controla o assento vencedor (painel de evento existente).
func choose_reliquary_reward(player: PlayerData, choice: String) -> bool:
	var event := active_event_of_type(ReliquaryEvent.EVENT_TYPE) as ReliquaryEvent
	if event == null or not event.awaiting_choice_from(GameManager.players.find(player)):
		return false
	return event.apply_reward(GameManager.players, choice)

func _has_active_dragon() -> bool:
	for event in active_events:
		if event is DragonEvent:
			return true
	return false

## SO DEBUG (ver HUD DebugPanel, "Forçar Dragão") -- cria um DragonEvent
## imediatamente, ignorando WorldEventTrigger.should_spawn_dragon por
## completo. NUNCA muda o trigger de producao normal -- so um atalho pra
## playtest manual do vertical slice sem esperar turno minimo/RNG. Mesma
## guarda de maybe_spawn_dragon (nunca dois Dragoes-evento ao mesmo tempo).
## Fase 33D1: continua sendo um override de DESENVOLVEDOR — ignora a política ONCE_PER_GAME de propósito
## (permite testar o Dragão de novo na mesma sessão); o gatilho normal respeita a política.
func debug_force_dragon_event(hex_grid: HexGrid) -> void:
	if _has_active_dragon():
		return
	var event := DragonEvent.new()
	event.origin_region = WorldEventTrigger.choose_dragon_origin_region(hex_grid.map_seed, TurnManager.turn_number, hex_grid)
	register_event(event)

## Estado MINIMO/reconstruivel (contrato secao 3) -- `_next_event_id`
## precisa ser persistido junto, senao um evento novo criado apos carregar
## um save poderia colidir com o event_id de um evento antigo ainda ativo.
func to_save_dict() -> Dictionary:
	var events: Array = []
	for event in active_events:
		events.append(event.to_save_dict())
	var history: Array = []
	for entry in phase_history:
		history.append({"phase": int(entry.phase), "turn": int(entry.turn), "cause": String(entry.cause)})
	return {
		"next_event_id": _next_event_id,
		"events": events,
		"world_phase": world_phase,
		"phase_history": history,
		"completed_event_types": completed_event_types.duplicate(),
		"regional": RegionalThreatSystem.to_save_dict(),
		"dragon_schedule": dragon_schedule.duplicate(true),
		"reliquary_schedule": reliquary_schedule.duplicate(true),
		"public_milestones": public_milestones.duplicate(true),
	}

## Reconstroi cada evento salvo via event_type (ver _construct_event) --
## um tipo desconhecido e ignorado (nunca trava o load inteiro), pra um
## save mais novo com um tipo de evento que uma build mais antiga nao
## conhece ainda degradar sem quebrar o resto do save.
func from_save_dict(data: Dictionary) -> void:
	active_events.clear()
	_next_event_id = data.get("next_event_id", 0)
	for saved in data.get("events", []):
		var event_type: String = saved.get("event_type", "")
		var event := _construct_event(event_type)
		if event == null:
			push_warning("WorldEventManager: tipo de evento desconhecido no save ('%s') -- ignorado" % event_type)
			continue
		event.from_save_dict(saved)
		active_events.append(event)
	_load_world_state(data)

## Save com era (v22+): restaura exatamente. Save antigo sem era: reconstrói a era mais avançada
## justificável pelo estado carregado (WorldPhaseRules.reconstruct), sem emitir sinal nem recompensa;
## o histórico ganha uma única entrada MIGRATED. Eventos concluídos antes do v22 não são inferidos.
func _load_world_state(data: Dictionary) -> void:
	RegionalThreatSystem.load_save_dict(data.get("regional"))
	# Fase 33D3: agendadores e marcos. Ausentes (save ≤ v23): agendadores derivam no PRÓXIMO round (nada nasce
	# no load); marcos já satisfeitos no estado carregado contam como anunciados (sem enxurrada retroativa).
	dragon_schedule = (data.get("dragon_schedule", {}) as Dictionary).duplicate(true) if typeof(data.get("dragon_schedule", {})) == TYPE_DICTIONARY else {}
	reliquary_schedule = (data.get("reliquary_schedule", {}) as Dictionary).duplicate(true) if typeof(data.get("reliquary_schedule", {})) == TYPE_DICTIONARY else {}
	if typeof(data.get("public_milestones")) == TYPE_DICTIONARY:
		public_milestones = (data.public_milestones as Dictionary).duplicate(true)
	else:
		public_milestones = PublicVictoryMilestones.snapshot_already_reached(GameManager.players)
	completed_event_types = {}
	var completed: Variant = data.get("completed_event_types", {})
	if typeof(completed) == TYPE_DICTIONARY:
		for key in completed:
			if typeof(key) == TYPE_STRING and typeof(completed[key]) in [TYPE_INT, TYPE_FLOAT] and int(completed[key]) > 0:
				completed_event_types[key] = int(completed[key])
	if data.has("world_phase") and WorldPhaseRules.is_valid_phase(data.world_phase):
		world_phase = int(data.world_phase)
		phase_history = []
		for entry in data.get("phase_history", []):
			if typeof(entry) == TYPE_DICTIONARY and WorldPhaseRules.is_valid_phase(entry.get("phase")) and typeof(entry.get("turn")) in [TYPE_INT, TYPE_FLOAT]:
				phase_history.append({"phase": int(entry.phase), "turn": int(entry.turn), "cause": String(entry.get("cause", WorldPhaseRules.CAUSE_PROGRESS))})
		if phase_history.is_empty() or int(phase_history.back().phase) != world_phase:
			phase_history.append({"phase": world_phase, "turn": TurnManager.turn_number, "cause": WorldPhaseRules.CAUSE_MIGRATED})
		return
	world_phase = WorldPhaseRules.reconstruct(TurnManager.turn_number, GameManager.players)
	phase_history = [{"phase": world_phase, "turn": TurnManager.turn_number, "cause": WorldPhaseRules.CAUSE_MIGRATED}]

## Reconstrucao polimorfica por event_type (contrato secao 3) -- um match
## simples e suficiente com um so tipo concreto (DragonEvent); vira uma
## tabela de registro so se/quando o numero de tipos concretos justificar
## (mesma disciplina de nao introduzir mecanismo antes de precisar).
func _construct_event(event_type: String) -> WorldEvent:
	match event_type:
		DragonEvent.EVENT_TYPE:
			return DragonEvent.new()
		ReliquaryEvent.EVENT_TYPE:
			return ReliquaryEvent.new()
		_:
			return null
