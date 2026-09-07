extends Node

## Autoload -- possui a LISTA de eventos mundiais ativos (ver docs/WORLD_
## EVENT_CONTRACT.md, secao 2 "Ownership do estado"). GameManager nao
## conhece detalhes internos de evento nenhum -- so chama advance_turn()
## (ver GameManager._finish_turn(), ordem exata no contrato secao 1) e
## ouve o EventBus.
##
## Escopo deliberadamente MINIMO (Fase Macro, Step 2): so prova que o
## sistema consegue possuir, avancar, concluir, emitir e remover eventos
## de forma deterministica e isolada. Nenhuma logica especifica de Dragao,
## spawn de monstro, selecao de alvo, regra de participacao, UI, chamada a
## GameManager, ou registro generico de tipos multiplos entra aqui ainda
## -- isso e' o proximo passo (DragonEvent), sempre EM CIMA desta
## fundacao, nunca misturado a ela.

var active_events: Array[WorldEvent] = []
var _next_event_id: int = 0

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
			EventBus.world_event_completed.emit(event, event.result)
			remove_event(event)

## Estado MINIMO/reconstruivel (contrato secao 3) -- `_next_event_id`
## precisa ser persistido junto, senao um evento novo criado apos carregar
## um save poderia colidir com o event_id de um evento antigo ainda ativo.
func to_save_dict() -> Dictionary:
	var events: Array = []
	for event in active_events:
		events.append(event.to_save_dict())
	return {
		"next_event_id": _next_event_id,
		"events": events,
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

## Reconstrucao polimorfica por event_type (contrato secao 3) -- um match
## simples e suficiente com um so tipo concreto (DragonEvent); vira uma
## tabela de registro so se/quando o numero de tipos concretos justificar
## (mesma disciplina de nao introduzir mecanismo antes de precisar).
func _construct_event(event_type: String) -> WorldEvent:
	match event_type:
		DragonEvent.EVENT_TYPE:
			return DragonEvent.new()
		_:
			return null
