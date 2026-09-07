class_name DragonEvent
extends WorldEvent

## Fase 5B.1 do roadmap (Fase Macro, "O Mundo Esta Vivo") -- responde
## EXCLUSIVAMENTE o Blocker #1 do contrato comportamental (docs/DRAGON_
## EVENT_DESIGN.md): identidade, origem/spawn e o campo que a cadeia de
## trigger precisa preencher no `_init()`. advance_turn() continua o
## skeleton da 5A (avanca uma fase por chamada, sem efeito sobre o mundo)
## -- Preparation real (contagem de turnos, Blocker #2), alvo travado
## (Blocker #3) e Active/combate (spawn de Unit neutra, Blocker #1 "ownership
## da Unit" aplicado de verdade) continuam fora de escopo até os passos
## correspondentes.

const EVENT_TYPE := "dragon"

## Sentinela Vector2i (mesmo padrao ja usado por City.NO_PENDING_COORD/
## PlayerData.NO_RITUAL_CITY_COORD) -- nunca confundir "ainda nao
## escolhido" com uma coordenada real (0,0).
const NO_COORD := Vector2i(999999, 999999)

## Regiao aproximada de origem -- conhecida desde a criacao (preenchida por
## WorldEventTrigger.choose_dragon_origin_region no momento do spawn),
## publica desde Announced. NOTA pra 5B.3: hoje isto e' semanticamente uma
## COORDENADA REPRESENTATIVA da regiao (um tile), nao uma regiao/area de
## verdade -- suficiente pra "regiao aproximada, nunca o tile exato" por
## enquanto, mas se precisarmos de regiao como area/cluster de verdade
## depois, o campo pode precisar evoluir (ex.: origin_region_coord +
## definicao explicita de raio/area), sem quebrar o principio "so a
## origem, nunca o spawn exato". NUNCA o tile exato de spawn -- ver spawn_coord
## abaixo e docs/DRAGON_EVENT_DESIGN.md, "cadeia de origem/spawn".
var origin_region: Vector2i = NO_COORD

## Tile EXATO de spawn da Unit do Dragao -- permanece NO_COORD durante
## Dormant/Announced/Preparation de proposito (contrato: "o tile exato so
## e sorteado na transicao pra Active"). Sorteio real dentro da regiao
## ainda NAO implementado aqui -- pertence ao passo Active/5B.3.
var spawn_coord: Vector2i = NO_COORD

func _init() -> void:
	event_type = EVENT_TYPE

## Skeleton (heranca da 5A, ainda sem mudanca nesta fatia): avanca
## exatamente UMA fase da ordem fixa por chamada, sem efeito nenhum sobre
## o mundo. Preparation ganhar contagem real de turnos (Blocker #2) e
## Active ganhar o sorteio de spawn_coord + spawn da Unit (Blocker #3/
## ownership) substituem isto nos proximos passos, nunca a arquitetura ao
## redor.
func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
	var index: int = WorldEvent.PHASES.find(phase)
	if index < WorldEvent.PHASES.size() - 1:
		phase = WorldEvent.PHASES[index + 1]

func to_save_dict() -> Dictionary:
	var data := super.to_save_dict()
	data["origin_region"] = [origin_region.x, origin_region.y]
	data["spawn_coord"] = [spawn_coord.x, spawn_coord.y]
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var origin: Array = data.get("origin_region", [NO_COORD.x, NO_COORD.y])
	origin_region = Vector2i(int(origin[0]), int(origin[1]))
	var spawn: Array = data.get("spawn_coord", [NO_COORD.x, NO_COORD.y])
	spawn_coord = Vector2i(int(spawn[0]), int(spawn[1]))
