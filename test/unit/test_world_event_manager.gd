extends GutTest

## Cobre WorldEventManager (autoload, docs/WORLD_EVENT_CONTRACT.md) --
## escopo do Step 2 (Fase Macro): possuir, avancar, concluir, emitir e
## remover eventos de forma deterministica e isolada. Nenhum evento
## concreto (DragonEvent) existe ainda -- os stubs abaixo sao SO de teste,
## nunca conteudo de jogo real.

class _StubEvent extends WorldEvent:
	var advance_calls: int = 0
	func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
		advance_calls += 1

## Completa no PRIMEIRO advance_turn() -- prova a sequencia phase->
## Completed -> sinal -> remocao, tudo dentro do mesmo turno.
class _ImmediateCompleteEvent extends WorldEvent:
	var advance_calls: int = 0
	func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
		advance_calls += 1
		phase = WorldEvent.PHASE_COMPLETED
		result = {"outcome": "done"}

## Avanca exatamente uma fase da lista fixa por chamada -- usado pra testar
## o sinal phase_changed com old/new corretos.
class _StepPhaseEvent extends WorldEvent:
	func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
		var index: int = WorldEvent.PHASES.find(phase)
		if index < WorldEvent.PHASES.size() - 1:
			phase = WorldEvent.PHASES[index + 1]

## Simula um evento cuja resolucao remove OUTRO evento no MESMO turno --
## prova que advance_turn() itera sobre uma fotografia estavel, nao a
## lista viva sendo mutada.
class _RemovesAnotherEvent extends WorldEvent:
	var target: WorldEvent
	func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
		if target != null:
			WorldEventManager.remove_event(target)

var _players: Array[PlayerData] = []

func before_each():
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0
	_players = []

func after_each():
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0

## --- register_event -------------------------------------------------------

func test_register_event_assigns_incrementing_event_ids():
	var a := _StubEvent.new()
	var b := _StubEvent.new()
	WorldEventManager.register_event(a)
	WorldEventManager.register_event(b)
	assert_eq(a.event_id, 0)
	assert_eq(b.event_id, 1)

func test_register_event_adds_to_active_events():
	var event := _StubEvent.new()
	WorldEventManager.register_event(event)
	assert_true(event in WorldEventManager.active_events)
	assert_eq(WorldEventManager.active_events.size(), 1)

func test_register_event_emits_world_event_announced():
	var event := _StubEvent.new()
	watch_signals(EventBus)
	WorldEventManager.register_event(event)
	assert_signal_emitted_with_parameters(EventBus, "world_event_announced", [event])

## --- advance_turn: chamada basica ------------------------------------------

func test_advance_turn_calls_advance_turn_on_each_active_event_exactly_once():
	var a := _StubEvent.new()
	var b := _StubEvent.new()
	WorldEventManager.register_event(a)
	WorldEventManager.register_event(b)

	WorldEventManager.advance_turn(null, _players)
	assert_eq(a.advance_calls, 1)
	assert_eq(b.advance_calls, 1)

	WorldEventManager.advance_turn(null, _players)
	assert_eq(a.advance_calls, 2)
	assert_eq(b.advance_calls, 2)

func test_advance_turn_emits_phase_changed_when_phase_changes():
	var event := _StepPhaseEvent.new()
	WorldEventManager.register_event(event)
	watch_signals(EventBus)

	WorldEventManager.advance_turn(null, _players)

	assert_signal_emitted_with_parameters(EventBus, "world_event_phase_changed", [event, WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED])

func test_advance_turn_does_not_emit_phase_changed_when_phase_is_unchanged():
	var event := _StubEvent.new() # nunca muda a propria phase
	WorldEventManager.register_event(event)
	watch_signals(EventBus)

	WorldEventManager.advance_turn(null, _players)

	assert_signal_not_emitted(EventBus, "world_event_phase_changed")

## --- Regra 1: evento que termina DURANTE advance_turn() --------------------
## Sequencia exigida: phase -> Completed, DEPOIS o sinal completed, DEPOIS
## a remocao da lista ativa -- tudo no MESMO turno em que ele completou.

func test_event_completing_during_advance_turn_emits_completed_with_its_result():
	var event := _ImmediateCompleteEvent.new()
	WorldEventManager.register_event(event)
	watch_signals(EventBus)

	WorldEventManager.advance_turn(null, _players)

	assert_true(event.is_completed())
	assert_signal_emitted_with_parameters(EventBus, "world_event_completed", [event, {"outcome": "done"}])

func test_event_completing_during_advance_turn_is_removed_from_active_events():
	var event := _ImmediateCompleteEvent.new()
	WorldEventManager.register_event(event)

	WorldEventManager.advance_turn(null, _players)

	assert_false(event in WorldEventManager.active_events, "evento concluido deveria sair da lista ativa")
	assert_eq(WorldEventManager.active_events.size(), 0)

func test_completed_event_is_never_advanced_again_in_a_later_turn():
	var event := _ImmediateCompleteEvent.new()
	WorldEventManager.register_event(event)

	WorldEventManager.advance_turn(null, _players) # completa e remove aqui
	WorldEventManager.advance_turn(null, _players) # turno seguinte

	assert_eq(event.advance_calls, 1, "um evento ja concluido/removido nao deveria ser avancado de novo em turno nenhum depois")

## --- Regra 2: mutacao da lista durante a propria iteracao ------------------

func test_advance_turn_is_safe_when_an_event_removes_another_during_the_same_turn():
	var victim := _StubEvent.new()
	var remover := _RemovesAnotherEvent.new()
	var bystander := _StubEvent.new()
	WorldEventManager.register_event(victim)
	WorldEventManager.register_event(remover)
	WorldEventManager.register_event(bystander)
	remover.target = victim

	WorldEventManager.advance_turn(null, _players)

	assert_false(victim in WorldEventManager.active_events, "victim deveria ter sido removido pelo remover no meio do turno")
	assert_eq(bystander.advance_calls, 1, "bystander (registrado DEPOIS do remover na fotografia do turno) ainda deveria ser processado neste mesmo turno, mesmo com a lista viva mudando no meio do loop")

## --- remove_event -----------------------------------------------------------

func test_remove_event_removes_from_active_events():
	var event := _StubEvent.new()
	WorldEventManager.register_event(event)

	WorldEventManager.remove_event(event)

	assert_eq(WorldEventManager.active_events.size(), 0)

## --- Persistencia (contrato, secao 3) ---------------------------------------

func test_to_save_dict_and_from_save_dict_round_trip_next_event_id():
	WorldEventManager._next_event_id = 5

	var saved := WorldEventManager.to_save_dict()
	WorldEventManager._next_event_id = 0
	WorldEventManager.from_save_dict(saved)

	assert_eq(WorldEventManager._next_event_id, 5, "o contador precisa sobreviver ao save/load, senao um evento novo pos-load poderia colidir com o event_id de um evento antigo")
	assert_eq(WorldEventManager.active_events.size(), 0)

## Fallback pra save antigo/sem este campo -- carregar um dict vazio nunca
## deveria travar (contrato, "Persistencia" -> "Fallback/teste de saves
## antigos").
func test_from_save_dict_defaults_safely_for_a_save_without_events():
	WorldEventManager.from_save_dict({})

	assert_eq(WorldEventManager.active_events.size(), 0)
	assert_eq(WorldEventManager._next_event_id, 0)

## Nenhum tipo concreto existe ainda (Step 2 e generico; DragonEvent vem
## depois) -- um event_type desconhecido no save deveria ser ignorado,
## nunca travar o load inteiro (mesmo se um save futuro tiver "dragon"
## antes desta build conhecer DragonEvent).
func test_from_save_dict_ignores_unknown_event_type_without_crashing():
	WorldEventManager.from_save_dict({"next_event_id": 3, "events": [{"event_type": "dragon", "event_id": 0}]})

	assert_eq(WorldEventManager.active_events.size(), 0, "nenhum tipo concreto existe ainda -- deveria ser ignorado, nao travar o load")
	assert_eq(WorldEventManager._next_event_id, 3)
