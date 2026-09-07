class_name WorldEvent
extends RefCounted

## Representacao ABSTRATA de um evento mundial (ver docs/WORLD_EVENT_
## CONTRACT.md) -- ciclo de vida generico aqui, comportamento e dados
## especificos de cada evento concreto entram por heranca (ver DragonEvent,
## quando existir). WorldEventManager (autoload) possui a LISTA de eventos
## ativos; esta classe possui o proprio estado de UM evento -- nunca o
## contrario (contrato, secao 2 "Ownership do estado"). Nao ha enforcement
## de classe abstrata em GDScript; advance_turn()/to_save_dict()/
## from_save_dict() aqui sao a implementacao BASE (campos comuns), sempre
## chamada via super() por quem estende, nunca pensada pra uso direto como
## evento de verdade.

const PHASE_DORMANT := "dormant"
const PHASE_ANNOUNCED := "announced"
const PHASE_PREPARATION := "preparation"
const PHASE_ACTIVE := "active"
const PHASE_RESOLUTION := "resolution"
const PHASE_COMPLETED := "completed"

## Ordem fixa do FSM (ver contrato, secao 1) -- puramente documentacional:
## nenhum codigo aqui FORCA uma transicao sequencial. Cada evento concreto
## decide sua propria transicao em advance_turn(), inclusive pulando fases
## ou terminando antecipadamente (decisao explicita do usuario).
const PHASES := [PHASE_DORMANT, PHASE_ANNOUNCED, PHASE_PREPARATION, PHASE_ACTIVE, PHASE_RESOLUTION, PHASE_COMPLETED]

## Atribuido por WorldEventManager na criacao (contador incremental
## persistido, ver WorldEventManager) -- int em vez de String de proposito:
## combina com map_seed/turno por aritmetica simples em event_rng() abaixo,
## sem depender do hash() interno do Godot (nao garantido estavel entre
## versoes do engine) pra algo que precisa ser reproduzivel pra sempre.
var event_id: int = -1
## Identifica a subclasse concreta pra reconstrucao polimorfica no save/
## load (ver contrato, secao 3) -- ex.: "dragon". Vazio so na instancia
## base, nunca em um evento real.
var event_type: String = ""
var phase: String = PHASE_DORMANT
var turn_started: int = -1
var turn_deadline: int = -1
## civ_index (int, posicao em GameManager.players -- ver contrato secao 2)
## -> Dictionary de dados especificos da participacao daquela civ, formato
## livre por evento concreto (ex.: {"decision": "joined"}).
var participants: Dictionary = {}
## Resultado FINAL do evento (ver contrato, secao 5 "EventBus" -- o mesmo
## dict repassado no sinal world_event_completed) -- nunca um snapshot
## permanente do evento inteiro, so o suficiente pra quem ouviu o sinal
## saber o desfecho. Vazio ate o evento concreto preenche-lo, tipicamente
## na fase Resolution, antes de transicionar pra Completed.
var result: Dictionary = {}

func is_completed() -> bool:
	return phase == PHASE_COMPLETED

## Avalia e aplica a evolucao DESTE evento neste turno (ver contrato,
## secao 1) -- chamado exatamente uma vez por turno real, so de dentro de
## WorldEventManager.advance_turn(). Base nao faz nada; todo evento
## concreto sobrescreve.
func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
	pass

## Estado MINIMO/reconstruivel (ver contrato, secao 3) -- nunca serializa
## o objeto inteiro. Subclasses chamam super() e acrescentam so o proprio
## estado especifico por cima do dict retornado aqui.
func to_save_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"phase": phase,
		"turn_started": turn_started,
		"turn_deadline": turn_deadline,
		"participants": participants,
		"result": result,
	}

## Espelha to_save_dict() -- subclasses chamam super() primeiro, depois
## leem seus proprios campos do mesmo `data`.
func from_save_dict(data: Dictionary) -> void:
	event_id = data.get("event_id", -1)
	event_type = data.get("event_type", "")
	phase = data.get("phase", PHASE_DORMANT)
	turn_started = data.get("turn_started", -1)
	turn_deadline = data.get("turn_deadline", -1)
	participants = data.get("participants", {})
	result = data.get("result", {})

## RNG deterministico do evento (ver contrato, secao 4) -- SEM ESTADO
## proprio a persistir: sempre re-derivado de (map_seed, event_id, turno),
## nunca compartilhado com o RNG global de decisao de IA (RivalAI.
## decide_war/decide_trade). Multiplicadores arbitrarios (nao primos
## "magicos", so espalham os 3 eixos o bastante pra reduzir colisao) --
## mesmo estilo de combinacao manual ja usado por HexGrid._maybe_assign_
## resource (coord.x*31 + coord.y*17), evitando depender do hash() interno
## do Godot para algo que precisa ser reproduzivel entre versoes do engine.
func event_rng(map_seed: int, turn: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed * 1000003 + event_id * 9973 + turn
	return rng
