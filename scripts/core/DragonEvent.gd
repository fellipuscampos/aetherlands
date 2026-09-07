class_name DragonEvent
extends WorldEvent

## Fase 5B.3-A do roadmap (Fase Macro, "O Mundo Esta Vivo"): o Dragao ganha
## presenca FISICA real no mundo -- Announced/Preparation (5B.2) ja tinham
## comportamento real; agora a transicao pra Active cria uma `Unit` de
## verdade no mapa. Escopo desta fatia e' SO nascimento/presenca (spawn
## deterministico, ownership neutro, visual, selecao/inspecao via sistemas
## ja existentes, save/load, remocao ao terminar) -- movimento, combate e
## escolha de proximo alvo (5B.3-B) ainda NAO existem aqui. Reusa
## HexGrid.spawn_monster_at/MonsterDatabase (mesma base de stats/visual do
## Dragao-monstro comum) SEM tocar em lair_coords/global_cap/qualquer
## bookkeeping de ecologia -- essa funcao ja e' pura o bastante pra isso
## (confirmado lendo HexGrid.gd: so cria a Unit, nunca mexe em lair).

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

## Quantos "aneis" de vizinhos a busca por um tile de spawn valido tenta
## antes de desistir e cair de volta em origin_region mesmo assim (caso
## degenerado, raro) -- regra MINIMA proposital (contrato: "nao precisamos
## decidir hoje uma formula perfeita de qual e' o melhor tile").
const SPAWN_SEARCH_MAX_RINGS := 6

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
## e sorteado na transicao pra Active"), sorteado deterministicamente
## (event_rng -- event_id ja existe neste ponto, diferente do trigger) na
## transicao Preparation->Active.
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

## A Unit FISICA do Dragao -- NUNCA persistida diretamente (e' um Node, nao
## dado puro). spawn_coord (esse sim persistido) e' o suficiente pra
## reencontrar a MESMA Unit que o save generico de monstros neutros
## (HexGrid.neutral_units/SaveManager) ja reconstroi sozinho -- ver
## relink_unit() abaixo, chamado pelo SaveManager depois do load.
## owner_player desta Unit e' SEMPRE null (HexGrid.spawn_monster_at ja
## garante isso) -- nunca conta como unidade de civilizacao nenhuma
## (player.units, upkeep de guerra, contagem de Dominacao, producao) por
## construcao, nao por um cuidado especial aqui.
var dragon_unit: Unit = null

func _init() -> void:
	event_type = EVENT_TYPE

## Announced/Preparation (5B.2) e a criacao fisica na entrada de Active
## (5B.3-A) tem comportamento real. Active em si (mover, atacar, escolher
## proximo alvo) e Resolution (desfecho de verdade) continuam o skeleton
## da 5A -- 5B.3-B/5B.4 substituem isso, nunca a arquitetura ao redor.
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
				spawn_coord = _choose_spawn_coord(hex_grid)
				dragon_unit = hex_grid.spawn_monster_at(spawn_coord, "dragon")
				phase = WorldEvent.PHASE_ACTIVE
				EventBus.notify.emit("O Dragão despertou! As montanhas estremecem quando a criatura surge dos céus.", "")
		WorldEvent.PHASE_ACTIVE:
			# 5B.3-A: so nascimento/presenca fisica -- movimento, combate e
			# escolha de proximo alvo (5B.3-B) ainda nao existem. Skeleton:
			# um tick de presenca e' suficiente pra provar o ciclo
			# nascer->existir->terminar antes de 5B.3-B substituir isto por
			# comportamento de verdade.
			phase = WorldEvent.PHASE_RESOLUTION
		WorldEvent.PHASE_RESOLUTION:
			# Desfecho de verdade (derrotado/fugiu/devastou) e' 5B.4 --
			# placeholder MINIMO aqui so pra fechar o ciclo e remover a
			# Unit do mapa (contrato: "remover a Unit quando o evento
			# termina").
			result = {"outcome": "vanished"}
			_remove_dragon_unit(hex_grid)
			phase = WorldEvent.PHASE_COMPLETED

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

## Regra MINIMA proposital (docs/DRAGON_EVENT_DESIGN.md, Blocker #1):
## considera origin_region primeiro, depois expande em aneis de vizinhos
## ate achar um tile valido (nao bloqueia unidade terrestre, sem
## cidade/unidade em cima) ou esgotar SPAWN_SEARCH_MAX_RINGS -- nesse caso
## degenerado (raro), cai de volta em origin_region mesmo assim. Formulas
## melhores (montanha, distancia do alvo, fog of war) ficam pra depois.
## Deterministico -- nao usa event_rng aqui porque a busca em si e' uma
## varredura fixa por distancia crescente, sem decisao aleatoria nenhuma
## (o ponto de partida, origin_region, ja veio do RNG do trigger).
func _choose_spawn_coord(hex_grid: HexGrid) -> Vector2i:
	if _is_valid_spawn_tile(hex_grid, origin_region):
		return origin_region
	var visited := {origin_region: true}
	var frontier: Array[Vector2i] = [origin_region]
	for ring in range(SPAWN_SEARCH_MAX_RINGS):
		var next_frontier: Array[Vector2i] = []
		for coord in frontier:
			for neighbor in hex_grid.get_neighbors(coord):
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				if _is_valid_spawn_tile(hex_grid, neighbor):
					return neighbor
				next_frontier.append(neighbor)
		frontier = next_frontier
	return origin_region # degenerado -- nenhum tile valido na busca inteira

func _is_valid_spawn_tile(hex_grid: HexGrid, coord: Vector2i) -> bool:
	var data: HexTileData = hex_grid.get_tile(coord)
	if data == null or data.blocks_land_units():
		return false
	if hex_grid.get_unit_at(coord) != null or hex_grid.get_city_at(coord) != null:
		return false
	return true

func _remove_dragon_unit(hex_grid: HexGrid) -> void:
	if dragon_unit != null and is_instance_valid(dragon_unit):
		hex_grid.remove_unit(dragon_unit)
	dragon_unit = null

## Chamado pelo SaveManager DEPOIS de restaurar os monstros neutros (que ja
## inclui esta Unit, ver HexGrid.neutral_units/_deserialize_neutral_units)
## e DEPOIS de WorldEventManager.from_save_dict reconstruir este evento --
## dragon_unit e' um Node, nunca serializado diretamente; spawn_coord (que
## E' persistido) e' o suficiente pra reencontrar a MESMA Unit que o save
## generico de monstros neutros ja recriou. No-op segura se o Dragao ainda
## nao tinha nascido (spawn_coord == NO_COORD).
func relink_unit(hex_grid: HexGrid) -> void:
	if spawn_coord == NO_COORD:
		return
	dragon_unit = hex_grid.get_unit_at(spawn_coord)

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
