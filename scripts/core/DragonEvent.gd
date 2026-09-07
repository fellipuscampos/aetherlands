class_name DragonEvent
extends WorldEvent

## Fase 5B.2 do roadmap (Fase Macro, "O Mundo Esta Vivo"): primeiro vertical
## slice jogavel do Dragao — Announced e Preparation ganham comportamento
## REAL (alvo travado, prazo de decisao contando turnos de verdade), com
## valores propositalmente PROVISORIOS (ver PREPARATION_DURATION_TURNS
## abaixo) em vez de mais uma rodada de especificacao (decisao explicita do
## usuario: "fazer o primeiro Dragon Event existir de ponta a ponta, mesmo
## que os numeros sejam provisorios. Depois jogamos, observamos e
## calibramos"). Active/combate/recompensa (Blocker #3/5B.3+) continuam
## fora de escopo -- a fase Active daqui so avanca pra Resolution/Completed
## sem efeito nenhum, mesmo skeleton da 5A, ate 5B.3 substituir isto por
## jogo de verdade.

const EVENT_TYPE := "dragon"

## Sentinela Vector2i (mesmo padrao ja usado por City.NO_PENDING_COORD/
## PlayerData.NO_RITUAL_CITY_COORD) -- nunca confundir "ainda nao
## escolhido" com uma coordenada real (0,0).
const NO_COORD := Vector2i(999999, 999999)

## PROVISORIO/NAO CALIBRADO (mesma disciplina de WorldEventTrigger.
## DRAGON_TRIGGER_MIN_TURN/CHANCE_PER_TURN) -- so o suficiente pra existir
## um prazo real de decisao. Calibrar depois do primeiro playtest, nunca
## adivinhar agora.
const PREPARATION_DURATION_TURNS := 3

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

## civ_index (posicao em GameManager.players, mesma convencao do contrato)
## da civilizacao-alvo -- travado na transicao Announced->Preparation
## (docs/DRAGON_EVENT_DESIGN.md, Blocker #3: "o alvo e determinado antes
## ou durante a transicao Announced -> Preparation, e permanece imutavel
## durante Preparation e Active"). -1 = ainda nao travado. Formula
## PROVISORIA (civ com a cidade mais proxima de origin_region) -- formula
## definitiva ainda em aberto (Blocker #3), mas precisa de ALGUMA regra
## real pra existir um vertical slice jogavel.
var target_civ_index: int = -1

func _init() -> void:
	event_type = EVENT_TYPE

## Announced e Preparation tem comportamento real agora; Active/Resolution
## continuam o skeleton da 5A (avancam sozinhos, sem efeito sobre o mundo)
## ate 5B.3/5B.4 existirem -- nunca combate/spawn fisico aqui.
func advance_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	match phase:
		WorldEvent.PHASE_DORMANT:
			phase = WorldEvent.PHASE_ANNOUNCED
			EventBus.notify.emit("Rumores do Oeste: mercadores e aldeões relatam uma criatura colossal cruzando os céus durante a noite. Ainda não há confirmação, mas os relatos são numerosos demais para serem ignorados.", "")
		WorldEvent.PHASE_ANNOUNCED:
			# Alvo travado AQUI, nunca depois (Blocker #3) -- formula
			# provisoria: civ com a cidade mais proxima da regiao.
			target_civ_index = _find_nearest_civ_index(players)
			turn_deadline = TurnManager.turn_number + PREPARATION_DURATION_TURNS
			phase = WorldEvent.PHASE_PREPARATION
			_notify_preparation_started(players)
		WorldEvent.PHASE_PREPARATION:
			# turn_deadline e' o ULTIMO turno em que uma decisao ainda pode
			# ser registrada (Blocker #2) -- so avanca no processamento do
			# turno SEGUINTE ao prazo.
			if TurnManager.turn_number > turn_deadline:
				phase = WorldEvent.PHASE_ACTIVE
		WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION:
			# Skeleton ainda (5A) -- 5B.3 (Active: spawn/combate real) e
			# 5B.4 (Resolution: desfecho/recompensa real) substituem isto,
			# nunca a arquitetura ao redor.
			var index: int = WorldEvent.PHASES.find(phase)
			phase = WorldEvent.PHASES[index + 1]

## Civilizacao com a cidade mais proxima de origin_region -- formula
## PROVISORIA (Blocker #3 continua aberto pra formula definitiva). -1 se
## nenhuma civ tiver cidade nenhuma (mapa vazio/todos eliminados).
func _find_nearest_civ_index(players: Array[PlayerData]) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(players.size()):
		for city in players[i].cities:
			var distance: float = HexMetrics.axial_distance(origin_region, city.coord)
			if distance < best_distance:
				best_distance = distance
				best_index = i
	return best_index

func _notify_preparation_started(players: Array[PlayerData]) -> void:
	var target_name := "uma civilização desconhecida"
	if target_civ_index >= 0 and target_civ_index < players.size():
		target_name = players[target_civ_index].civ.civ_name
	EventBus.notify.emit("O Dragão se aproxima. Os relatos foram confirmados: uma criatura de poder incomum deverá surgir na região em breve. Ele provavelmente atacará %s primeiro. Faltam %d turnos para sua chegada — deseja participar da expedição para detê-lo?" % [target_name, PREPARATION_DURATION_TURNS], "")

func to_save_dict() -> Dictionary:
	var data := super.to_save_dict()
	data["origin_region"] = [origin_region.x, origin_region.y]
	data["spawn_coord"] = [spawn_coord.x, spawn_coord.y]
	data["target_civ_index"] = target_civ_index
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var origin: Array = data.get("origin_region", [NO_COORD.x, NO_COORD.y])
	origin_region = Vector2i(int(origin[0]), int(origin[1]))
	var spawn: Array = data.get("spawn_coord", [NO_COORD.x, NO_COORD.y])
	spawn_coord = Vector2i(int(spawn[0]), int(spawn[1]))
	target_civ_index = int(data.get("target_civ_index", -1))
