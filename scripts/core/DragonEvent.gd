class_name DragonEvent
extends WorldEvent

## Fase 5B.3-B do roadmap (Fase Macro, "O Mundo Esta Vivo"): o Dragao agora
## se MOVE, LUTA e RAIDA cidades durante Active -- 5B.3-A ja cobria
## nascimento/presenca fisica (spawn, ownership neutro, save/load,
## remocao). IA deliberadamente MINIMA (decisao explicita do usuario:
## "não tentar resolver ainda uma IA inteligente"): sem avaliar risco,
## sem fugir de combate desfavoravel, sem contribuicao de participantes
## ainda (isso e' um passo futuro). Reusa o MAXIMO possivel do que ja
## existe -- RivalAI.move_unit_toward (movimento, ja usado por MonsterAI
## pra monstros neutros), MonsterAI._hostile_in_attack_range (deteccao de
## alvo inimigo), CombatResolver.resolve/resolve_city_attack (combate de
## verdade, com contra-ataque/morte/regras de terreno de graca) -- nunca
## um "dragon_damage_city()" paralelo. A UNICA mudanca no combate
## compartilhado foi um guard em CombatResolver.resolve_city_attack pra
## nunca capturar uma cidade quando o atacante e' neutro (ver esse
## arquivo) -- decisao explicita: raid, nunca conquista.

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

## PROVISORIO/NAO CALIBRADO -- quantos raids bem-sucedidos ate o Dragao
## "terminar sozinho" (Resolution: "devastated"), pra existir uma condicao
## de termino alem de "foi derrotado". Numero exato e' tuning, nao design
## -- decisao explicita do usuario: nao calibrar antes do primeiro
## playtest.
const DEVASTATION_RAID_LIMIT := 3

## Quantos raids bem-sucedidos ja aconteceram nesta incursao -- persistido
## (ver to_save_dict) pra sobreviver a um save/load em pleno Active.
var raids_done: int = 0

## Cidade que o Dragao esta perseguindo AGORA (dentro da civ travada em
## target_civ_index) -- NO_COORD quando ainda nao escolheu ou acabou de
## raidar uma e precisa escolher de novo (docs/DRAGON_EVENT_DESIGN.md:
## "depois de uma incursao, ele precisa continuar procurando outro
## destino" -- limpar isto e' o mecanismo exato disso). Guarda so a
## COORDENADA (nunca a City, mesmo principio de "coordenada, nao
## referencia" ja usado em todo o resto do save).
var current_target_city_coord: Vector2i = NO_COORD

func _init() -> void:
	event_type = EVENT_TYPE

## Announced/Preparation (5B.2), nascimento fisico (5B.3-A) e agora
## movimento/combate/raid (5B.3-B) tem comportamento real. Resolution
## ainda so fecha o ciclo (remove a Unit) -- desfecho detalhado
## (recompensas, consequencias persistentes) e' 5B.4.
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
			_take_dragon_turn(hex_grid, players)
		WorldEvent.PHASE_RESOLUTION:
			# Desfecho DETALHADO (recompensas, consequencias persistentes)
			# e' 5B.4 -- result.outcome ja foi decidido em _take_dragon_turn
			# ("defeated"/"devastated"/"no_target"). Aqui so fecha o ciclo:
			# remove a Unit do mapa se ainda estiver viva (se morreu em
			# combate, CombatResolver.resolve ja chamou hex_grid.remove_unit
			# sozinho -- _remove_dragon_unit e' seguro contra dupla remocao).
			_remove_dragon_unit(hex_grid)
			phase = WorldEvent.PHASE_COMPLETED

## Um "turno" do Dragao: luta se tiver inimigo em alcance; senao escolhe
## uma cidade-alvo (dentro da civ travada) e ou raida (se em alcance) ou
## avanca em direcao a ela. IA deliberadamente MINIMA -- sem avaliar
## favorabilidade de combate (RivalAI.is_favorable_attack de proposito NAO
## usado aqui: o Dragao e' uma ameaca que nao foge), sem escolher entre
## multiplas cidades por qualquer criterio alem de distancia.
func _take_dragon_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
	if dragon_unit == null or dragon_unit.hp <= 0.0:
		# Morreu em combate ANTES deste tick (uma unidade interceptou o
		# Dragao durante o turno de outro jogador) -- CombatResolver.
		# resolve ja removeu a Unit do mapa sozinho quando isso aconteceu.
		result = {"outcome": "defeated"}
		phase = WorldEvent.PHASE_RESOLUTION
		return

	var enemy: Unit = MonsterAI._hostile_in_attack_range(dragon_unit, hex_grid)
	if enemy != null:
		CombatResolver.resolve(dragon_unit, enemy, hex_grid)
		if dragon_unit.hp <= 0.0:
			result = {"outcome": "defeated"}
			phase = WorldEvent.PHASE_RESOLUTION
		return

	var target_city := _choose_target_city(players)
	if target_city == null:
		# Civ-alvo sem cidade nenhuma (todas destruidas/civ eliminada) --
		# nao ha mais o que fazer. Caso raro, nao previsto no contrato
		# original; tratado aqui como fim do evento em vez de travar.
		result = {"outcome": "no_target"}
		phase = WorldEvent.PHASE_RESOLUTION
		return
	current_target_city_coord = target_city.coord

	if _city_in_attack_range(hex_grid, target_city):
		CombatResolver.resolve_city_attack(dragon_unit, target_city, hex_grid)
		raids_done += 1
		# "Depois de uma incursao, ele precisa continuar procurando outro
		# destino" -- limpa a perseguicao atual; o PROXIMO tick escolhe de
		# novo (pode ser a mesma cidade, se for a unica que resta).
		current_target_city_coord = NO_COORD
		if raids_done >= DEVASTATION_RAID_LIMIT:
			result = {"outcome": "devastated"}
			phase = WorldEvent.PHASE_RESOLUTION
		return

	RivalAI.move_unit_toward(dragon_unit, hex_grid, target_city.coord)

## Prioridade 1: a MESMA cidade ja sendo perseguida (persiste enquanto ela
## continuar existindo e pertencendo a civ-alvo). Prioridade 2: a cidade
## mais proxima do Dragao AGORA, dentro da MESMA civ-alvo (target_civ_index
## nunca muda, Blocker #3) -- formula provisoria, igual ao resto desta
## fase. null se a civ-alvo nao tiver cidade nenhuma.
func _choose_target_city(players: Array[PlayerData]) -> City:
	if target_civ_index < 0 or target_civ_index >= players.size():
		return null
	var target_player: PlayerData = players[target_civ_index]
	if current_target_city_coord != NO_COORD:
		for city in target_player.cities:
			if city.coord == current_target_city_coord:
				return city
	var best: City = null
	var best_distance := INF
	for city in target_player.cities:
		var distance: float = HexMetrics.axial_distance(dragon_unit.coord, city.coord)
		if distance < best_distance:
			best_distance = distance
			best = city
	return best

func _city_in_attack_range(hex_grid: HexGrid, city: City) -> bool:
	return city.coord in hex_grid.tiles_in_range(dragon_unit.coord, dragon_unit.unit_data.attack_range)

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

## Segura contra dupla remocao: se o Dragao morreu em combate (outcome
## "defeated"), CombatResolver.resolve JA chamou hex_grid.remove_unit --
## checar hex_grid.get_unit_at(...) == dragon_unit antes de remover de novo
## evita operar numa Unit ja removida do mapa (ainda valida como objeto,
## queue_free() e' adiado, mas nao deveria ser tratada como presente).
func _remove_dragon_unit(hex_grid: HexGrid) -> void:
	if dragon_unit != null and is_instance_valid(dragon_unit) and hex_grid.get_unit_at(dragon_unit.coord) == dragon_unit:
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
	data["raids_done"] = raids_done
	data["current_target_city_coord"] = [current_target_city_coord.x, current_target_city_coord.y]
	return data

func from_save_dict(data: Dictionary) -> void:
	super.from_save_dict(data)
	var origin: Array = data.get("origin_region", [NO_COORD.x, NO_COORD.y])
	origin_region = Vector2i(int(origin[0]), int(origin[1]))
	var spawn: Array = data.get("spawn_coord", [NO_COORD.x, NO_COORD.y])
	spawn_coord = Vector2i(int(spawn[0]), int(spawn[1]))
	target_civ_index = int(data.get("target_civ_index", -1))
	raids_done = int(data.get("raids_done", 0))
	var target_city: Array = data.get("current_target_city_coord", [NO_COORD.x, NO_COORD.y])
	current_target_city_coord = Vector2i(int(target_city[0]), int(target_city[1]))
