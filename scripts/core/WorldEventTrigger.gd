class_name WorldEventTrigger
extends RefCounted

## Decide QUANDO o mundo deve criar um evento novo -- separado de propósito
## da lógica comportamental de qualquer evento concreto (ver docs/DRAGON_
## EVENT_DESIGN.md, Blocker #1: "trigger é separado do comportamento do
## evento"). `WorldEventManager` consulta isto; nenhum `WorldEvent` conhece
## esta classe, e esta classe nunca conhece o FSM de fases de evento
## nenhum -- só decide SE/ONDE um evento nasce, nunca o que ele faz depois.
##
## Sem tabela de registro de múltiplos tipos de evento ainda (só Dragão
## existe) -- mesma disciplina de não introduzir mecanismo antes de
## precisar já usada em WorldEventManager._construct_event.

## Valores iniciais NÃO calibrados -- só o suficiente para existir uma
## condição real de spawn (ver docs/DRAGON_EVENT_DESIGN.md, Blocker #1:
## "condição de spawn em si... ainda não decidida — só a FORMA está
## fechada aqui").
const DRAGON_TRIGGER_MIN_TURN := 30
const DRAGON_TRIGGER_CHANCE_PER_TURN := 0.02

## RNG determinístico do TRIGGER -- família SEPARADA do RNG de evento
## (`WorldEvent.event_rng`, que precisa de `event_id`) porque o trigger
## acontece ANTES de qualquer evento existir (contrato comportamental,
## Blocker #1, "consequência de determinismo"). Combinação manual por
## aritmética (nunca o `hash()` interno do Godot, não garantido estável
## entre versões do engine) -- mesmo estilo já usado em `WorldEvent.
## event_rng`/`HexGrid._maybe_assign_resource`. `_fold_string` evita
## depender de `String.hash()` pelo mesmo motivo.
static func _fold_string(s: String) -> int:
	var total := 0
	for i in range(s.length()):
		total += s.unicode_at(i) * (i + 1)
	return total

static func trigger_rng(map_seed: int, event_type: String, turn: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed * 1000003 + _fold_string(event_type) * 9973 + turn
	return rng

## Condição de spawn do Dragão -- deliberadamente simples pra v1 (chance
## fixa por turno, depois de um turno mínimo), nunca um `if turn == 50`
## fixo. Pode ficar mais sofisticada depois sem mudar a FORMA (continua
## sendo só esta função, consultada pelo `WorldEventManager`).
static func should_spawn_dragon(map_seed: int, turn: int) -> bool:
	if turn < DRAGON_TRIGGER_MIN_TURN:
		return false
	return trigger_rng(map_seed, DragonEvent.EVENT_TYPE, turn).randf() < DRAGON_TRIGGER_CHANCE_PER_TURN

## Região de origem do Dragão -- só uma coordenada ampla, NUNCA o tile
## exato de spawn (ver docs/DRAGON_EVENT_DESIGN.md, "cadeia de origem/
## spawn": só a região é pública em Announced/Preparation, o tile exato só
## é sorteado na transição pra Active — isso ainda não é implementado
## aqui, é responsabilidade do Blocker #3/5B.3). Sorteada com o MESMO
## `trigger_rng` do momento do spawn (ainda sem `event_id`), nunca o RNG
## de evento.
static func choose_dragon_origin_region(map_seed: int, turn: int, hex_grid: HexGrid) -> Vector2i:
	var coords: Array = hex_grid.tiles.keys()
	var index: int = trigger_rng(map_seed, DragonEvent.EVENT_TYPE, turn).randi() % coords.size()
	return coords[index]
