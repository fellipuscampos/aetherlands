class_name DragonEvent
extends WorldEvent

## Fase 5A do roadmap (Fase Macro, "O Mundo Esta Vivo") -- SKELETON: prova
## que o mecanismo generico (FSM/persistencia/determinismo, ver docs/
## WORLD_EVENT_CONTRACT.md) funciona com um tipo CONCRETO de verdade, antes
## de qualquer regra de jogo do Dragao (spawn, alvo, anuncio, janela de
## preparacao, participacao, combate, recompensa, consequencia,
## diplomacia -- tudo isso e Fase 5B, deliberadamente adiado). advance_turn()
## aqui so avanca UMA fase por chamada, sem NENHUM efeito sobre hex_grid/
## players -- a 5B substitui este metodo por regras de jogo de verdade,
## nunca a arquitetura ao redor dele.

const EVENT_TYPE := "dragon"

## Estado especifico minimo (contrato, secao 3) -- placeholder pra 5B
## (onde o Dragao vai afinal aparecer/atacar). Sentinela Vector2i, mesmo
## padrao ja usado por City.NO_PENDING_COORD/PlayerData.NO_RITUAL_CITY_
## COORD, pra nunca confundir "ainda nao escolhido" com uma coordenada
## real (0,0).
const NO_LAIR_COORD := Vector2i(999999, 999999)
var lair_coord: Vector2i = NO_LAIR_COORD

func _init() -> void:
	event_type = EVENT_TYPE

## Skeleton: avanca exatamente UMA fase da ordem fixa por chamada, sem
## efeito nenhum sobre o mundo -- prova o FSM funcionando fim-a-fim com um
## tipo concreto real. Fase 5B substitui isto por regras de jogo de
## verdade (spawn, escolha de alvo, combate, recompensa) por fase.
func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
	var index: int = WorldEvent.PHASES.find(phase)
	if index < WorldEvent.PHASES.size() - 1:
		phase = WorldEvent.PHASES[index + 1]

func to_save_dict() -> Dictionary:
	var data := super.to_save_dict()
	data["lair_coord"] = [lair_coord.x, lair_coord.y]
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var coord: Array = data.get("lair_coord", [NO_LAIR_COORD.x, NO_LAIR_COORD.y])
	lair_coord = Vector2i(int(coord[0]), int(coord[1]))
