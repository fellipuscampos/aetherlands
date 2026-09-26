class_name MonsterAI
extends RefCounted

## IA de monstro neutro (owner_player == null, ver MonsterDatabase) — mesmo
## formato estatico de RivalAI.gd, chamada uma vez por turno
## (GameManager._on_turn_changed, logo apos HexGrid.process_monster_lairs).
## Diferente de RivalAI: monstro nao tem PlayerData/fog-of-war proprio
## (sem `known_enemy_cities`), entao Invasor/Cacador usam conhecimento
## TOTAL do mapa via GameManager.players — simplificacao deliberada
## ("barbaro sabe onde fica o assentamento"), assimetria real vs RivalAI
## que vale documentar aqui.
##
## Quatro comportamentos (MonsterDatabase.BEHAVIOR_*, default por tipo em
## KIND_DATA, sobrescrito por instancia em Unit.monster_behavior_state) —
## rodada "COMPORTAMENTO DOS MONSTROS" (pedido do usuario: "muitos
## monstros parecem extremamente passivos... nao quero 'todo monstro
## corre pra cidade mais proxima'... cada tipo pode possuir comportamento
## proprio"):
## - Guardiao: nunca sai do territorio do proprio covil (HexGrid.
##   home_lair_for + raio, ver _guard_radius_for), so briga com quem entra
##   la OU se aproxima como cidade inimiga (ver _nearest_threat_within) —
##   ataque incondicional, sem pesar risco (ameaca ESTATICA por design).
##   Troll usa um raio bem maior que o padrao (KIND_DATA.guard_radius) —
##   "defende uma regiao", nao so' o proprio tile.
## - Saqueador: default do Goblin — BUSCA ATIVAMENTE presa fraca/isolada
##   (reusa a mesma logica do Cacador) dentro de um raio preso ao proprio
##   covil (maior que o do Guardiao, bem menor que o mapa inteiro); sem
##   presa a vista, se aproxima da cidade mais proxima DENTRO do raio pra
##   ameacar os arredores, e ainda saqueia tile trabalhado como o Invasor
##   (_maybe_pillage_tile). Nunca sai do proprio territorio sozinho — um
##   GRUPO que cresce o bastante continua virando Invasor de verdade (ver
##   _promote_idle_groups_to_invaders), a escalada natural de "bando vira
##   exercito".
## - Invasor: marcha sobre a cidade inimiga mais proxima entre TODOS os
##   jogadores, brigando so com quem encontra no caminho, e saqueia
##   qualquer tile TRABALHADO por cidade em que termine o turno (ver
##   _maybe_pillage_tile) — mas nunca CAPTURA a cidade em si
##   (HexGrid.compute_reachable ja bloqueia todo tile de cidade pra
##   owner=null, entao o invasor so consegue ficar ADJACENTE; nenhuma
##   chamada a hex_grid.capture_city em lugar nenhum deste arquivo, de
##   proposito).
## - Cacador: patrulha uma area larga cacando presa isolada ou fraca,
##   ataca so se favoravel (reusa RivalAI.is_favorable_attack).
##
## Nenhum comportamento novo ataca CIDADE diretamente — essa capacidade
## simplesmente nao existe pra monstro em lugar nenhum do jogo (so
## jogador/rival via SelectionManager/CombatResolver.resolve_city_attack);
## "reagir a cidade proxima" sempre significa SE APROXIMAR dela (ameaca de
## presenca, briga com quem estiver no caminho/guarnicao), nunca dano
## direto na cidade.
##
## AGGRO / TERRITORIO DE AMEACA (rodada seguinte -- pedido do usuario:
## "monstros precisam perceber que a civilizacao esta invadindo seu
## espaco... um covil pode reagir quando: unidades entram numa regiao;
## uma cidade e fundada perto; melhorias aparecem proximas; o jogador
## ataca membros do covil"). Os 4 gatilhos:
## 1. Unidade dentro do raio -- ja coberto (Guardiao/Saqueador, ver acima).
## 2. Cidade fundada perto -- ja coberto: Guardiao/Saqueador reavaliam
##    ameaca TODO turno (nao so' uma vez), entao uma cidade nova dentro
##    do raio e' detectada no proximo turno do monstro, sem gatilho
##    especial de "evento de fundacao" nenhum.
## 3. Melhoria (predio) proxima -- NOVO: _nearest_settlement_within agora
##    tambem conta predio (HexGrid.buildings_by_coord), nao so' cidade.
## 4. Jogador ataca um membro do covil -- NOVO: HexGrid.alert_lair_near
##    (chamado por CombatResolver sempre que um ataque de jogador acerta
##    um monstro neutro) marca o covil como ALERTADO por
##    LAIR_ALERT_DURATION_TURNS turnos, somando ALERT_RADIUS_BONUS ao
##    raio de deteccao de Guardiao/Saqueador enquanto durar -- o
##    territorio INTEIRO fica mais vigilante depois que um membro apanha,
##    nao so' quem foi atacado.
## Determinismo: nenhuma chamada a randi()/randf() global aqui — toda
## escolha de alvo e por distancia sobre arrays de ordem estavel
## (GameManager.players/player.units), igual RivalAI ja faz sem RNG
## nenhum. Se algum dia precisar de desempate aleatorio, TEM que vir de
## hex_grid.monster_turn_rng (nunca randf() global), pra nao quebrar a
## garantia de determinismo ja testada do sistema de covil.

const GUARD_RADIUS := 2 # Guardiao nunca se afasta disso do proprio covil (HexGrid.home_lair_for) -- override por kind em KIND_DATA.guard_radius (Troll), ver _guard_radius_for
## COMPORTAMENTO DOS MONSTROS: raio do Saqueador (Goblin) — maior que
## GUARD_RADIUS (o Goblin default NAO fica so' esperando na porta do
## covil), bem menor que HUNTER_PATROL_RADIUS/mapa inteiro (nunca vira um
## Invasor sozinho, so' em grupo, ver INVADER_GROUP_THRESHOLD).
const RAIDER_RADIUS := 4
## AGGRO / TERRITORIO DE AMEACA: bonus somado ao raio de deteccao
## (Guardiao/Saqueador) enquanto o proprio covil estiver ALERTADO (ver
## HexGrid.alert_lair_near/is_lair_alerted) -- valor de referencia inicial
## do proprio pedido do usuario ("valores como cinco tiles podem servir
## de referencia"): Troll alertado chega a 5+3=8, Goblin (Saqueador)
## alertado chega a 4+3=7 -- ambos ficam bem mais vigilantes sem virar
## detector de mapa inteiro (HUNTER_PATROL_RADIUS=6 pro Cacador, que ja
## nao tem territorio nenhum, continua sendo o teto natural de "alcance
## alto" do arquivo).
const ALERT_RADIUS_BONUS := 3
const HUNTER_PATROL_RADIUS := 6 # Cacador so enxerga presa dentro deste raio
const HUNTER_ISOLATION_RADIUS := 2 # presa com aliado do mesmo dono ate esta distancia NAO conta como isolada
const HUNTER_WEAK_HP_FRACTION := 0.5 # presa abaixo desta fracao de HP conta como "fraca" mesmo escoltada
## Grupo minimo de monstros OCIOSOS (ainda no comportamento default) num
## mesmo covil pra serem promovidos a Invasor — pedido do usuario: "se
## reunirem 2+ unidades, passam a marchar". Promocao e POR INSTANCIA
## (Unit.monster_behavior_state) e permanente/sem volta; so tipos com
## MonsterDatabase.KIND_DATA[kind].invader_promotable (Goblin) participam
## — Esqueleto ja nasce Invasor por padrao, nao precisa de gatilho.
const INVADER_GROUP_THRESHOLD := 2

## Duracao (em turnos) que uma melhoria saqueada fica sem rendimento (ver
## HexGrid.pillage_tile/V2EconomyRuntime) e quanto ouro o dono da
## cidade perde no momento do saque — pedido do usuario: "melhoria
## desativada por X turnos" + "cidade perde uma pequena quantia de ouro".
const PILLAGE_DURATION_TURNS := 6
const PILLAGE_GOLD_LOSS := 15.0

## So a parte de "preparar" o turno dos monstros (promover grupo ocioso a
## Invasor), sem mover nenhum ainda — extraido de take_turn() pra
## GameManager poder chamar isto UMA VEZ e depois processar cada monstro
## aos poucos, em frames diferentes (ver GameManager._build_monster_turn_
## items/stagger_ai_turns, mesmo motivo de RivalAI.begin_turn).
static func begin_turn(hex_grid: HexGrid) -> void:
	_promote_idle_groups_to_invaders(hex_grid)

## Acao de UM monstro — extraida de take_turn() pelo mesmo motivo de
## begin_turn() acima, pra poder ser chamada monstro-por-monstro em frames
## diferentes.
##
## Pedido explicito do usuario: "os monstros do mapa param de atacar
## durante o evento do dragao, e voltam pra ficar ao redor dos seus
## covis... so voltam a agir normalmente quando acabar o evento" -- checado
## AQUI (nao em take_turn) pra cobrir os DOIS caminhos reais de chamada
## (sincrono E GameManager._build_monster_turn_items/stagger_ai_turns,
## mesmo motivo de world_event_managed ja ser checado assim em vez de so
## em take_turn). Reusa WorldEventManager.active_events (mesmo autoload que
## RivalAI.decide_world_event_participation ja consulta) -- "o evento"
## cobre Announced/Preparation/Active/Resolution (existe na lista ate'
## Completed remover), nao so' o Dragao fisicamente presente.
static func act_for_unit(unit: Unit, hex_grid: HexGrid, turn: int) -> void:
	if _is_dragon_event_active():
		_take_recalled_turn(unit, hex_grid)
		return
	var behavior = _effective_behavior(unit)
	match behavior:
		MonsterDatabase.BEHAVIOR_INVADER:
			_take_invader_turn(unit, hex_grid, turn)
		MonsterDatabase.BEHAVIOR_HUNTER:
			_take_hunter_turn(unit, hex_grid)
		MonsterDatabase.BEHAVIOR_RAIDER:
			_take_raider_turn(unit, hex_grid, turn)
		_:
			_take_guardian_turn(unit, hex_grid, turn)

static func _is_dragon_event_active() -> bool:
	for event in WorldEventManager.active_events:
		if event is DragonEvent:
			return true
	return false

## Recolhido: nunca ataca, saqueia ou persegue -- so' anda de volta pro
## covil mais proximo (sem rastro de "de qual covil eu vim", entao o mais
## proximo por distancia e' a melhor aproximacao disponivel, mesmo
## principio determinista-por-distancia ja usado no resto do arquivo) e
## fica parado assim que chegar. Nao interrompe o combate de OUTRA unidade
## que ataque este monstro (isso e' turno de quem ataca, nao deste); so'
## garante que o monstro em si nunca INICIA agressao enquanto recolhido.
static func _take_recalled_turn(unit: Unit, hex_grid: HexGrid) -> void:
	var lair_coord := _nearest_lair_coord(unit.coord, hex_grid)
	if lair_coord == HexGrid.NO_LAIR:
		return # mapa sem covil nenhum (nao deveria acontecer, defensivo)
	if unit.coord in hex_grid._lair_area(lair_coord):
		return # ja em casa -- so' fica parado
	RivalAI.move_unit_toward(unit, hex_grid, lair_coord)

static func _nearest_lair_coord(from: Vector2i, hex_grid: HexGrid) -> Vector2i:
	var best := HexGrid.NO_LAIR
	var best_dist := INF
	for lair_coord in hex_grid.lair_coords:
		var distance: float = HexMetrics.axial_distance(from, lair_coord)
		if distance < best_dist:
			best_dist = distance
			best = lair_coord
	return best

## Turno dos monstros inteiro DE UMA VEZ, no MESMO frame — continua sendo o
## caminho usado quando GameManager.stagger_ai_turns esta desligado (o
## padrao, inclusive em TODO teste GUT), agora so delegando pra
## begin_turn()/act_for_unit() acima em vez de duplicar a logica.
static func take_turn(hex_grid: HexGrid, turn: int = 0) -> void:
	begin_turn(hex_grid)
	for unit in hex_grid.neutral_units():
		if not is_instance_valid(unit):
			continue
		# Roadmap "Fase Macro" 5B.3-D -- Unit.world_event_managed (ex.: o
		# Dragao de DragonEvent) ja tem IA propria em outro lugar; deixar
		# a IA generica de monstro TAMBEM agir nela causava movimento/
		# combate erratico e imprevisivel, independente do que o proprio
		# evento decidia (ver comentario do campo em Unit.gd).
		if unit.world_event_managed:
			continue
		act_for_unit(unit, hex_grid, turn)

static func _effective_behavior(unit: Unit) -> String:
	if unit.monster_behavior_state != "":
		return unit.monster_behavior_state
	var info: Dictionary = MonsterDatabase.KIND_DATA.get(unit.unit_data.visual_kind, {})
	return info.get("behavior", MonsterDatabase.BEHAVIOR_GUARDIAN)

## Por covil elegivel (invader_promotable), conta ocupantes vivos ainda
## OCIOSOS (monster_behavior_state == "") — o boss original (is_camp_boss)
## fica de fora de proposito: ele guarda o covil pra sempre, nunca faz
## parte de um grupo que "marcha embora" (na pratica isso ja seria
## impossivel de qualquer forma, ja que o boss tem movement_points == 0
## travado — mas exclui aqui tambem por clareza semantica, nao so por
## consequencia indireta de outro campo). Ao bater o limiar, promove TODOS
## os ociosos daquele covil de uma vez.
static func _promote_idle_groups_to_invaders(hex_grid: HexGrid) -> void:
	for lair_coord in hex_grid.lair_coords:
		var kind = hex_grid.lair_kind_by_coord.get(lair_coord, "")
		if kind == "":
			continue
		var info: Dictionary = MonsterDatabase.KIND_DATA.get(kind, {})
		if not info.get("invader_promotable", false):
			continue
		var idle: Array[Unit] = []
		for coord in hex_grid._lair_area(lair_coord):
			var unit = hex_grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.is_camp_boss and unit.monster_behavior_state == "":
				idle.append(unit)
		if idle.size() >= INVADER_GROUP_THRESHOLD:
			for unit in idle:
				unit.monster_behavior_state = MonsterDatabase.BEHAVIOR_INVADER

## COMPORTAMENTO DOS MONSTROS: raio do Guardiao e' por KIND (Troll
## "defende uma regiao maior", ver KIND_DATA.guard_radius) — ausente pra
## qualquer outro kind (Goblin default mudou pra Saqueador, mas Guardiao
## continua disponivel via override manual/futuro) cai no GUARD_RADIUS
## generico de sempre. AGGRO/TERRITORIO: soma ALERT_RADIUS_BONUS enquanto
## o proprio covil estiver alertado (ver HexGrid.alert_lair_near).
static func _guard_radius_for(unit: Unit, hex_grid: HexGrid, turn: int) -> int:
	var info: Dictionary = MonsterDatabase.KIND_DATA.get(unit.unit_data.visual_kind, {})
	var radius: int = int(info.get("guard_radius", GUARD_RADIUS))
	var home := hex_grid.home_lair_for(unit.coord)
	if home != HexGrid.NO_LAIR and hex_grid.is_lair_alerted(home, turn):
		radius += ALERT_RADIUS_BONUS
	return radius

## Guardiao: so briga com quem entra no proprio territorio (raio a partir
## do CENTRO do covil, nao da posicao atual do monstro, ver
## _guard_radius_for) e nunca se afasta dali perseguindo. Ataque
## incondicional (sem checar favorabilidade, ao contrario de Cacador) — e
## ameaca ESTATICA por design, nao pesa risco antes de defender o proprio
## territorio. _nearest_threat_within (nao so _nearest_hostile_within)
## tambem reage a CIDADE/PREDIO inimigo que se aproximar do territorio —
## pedido do usuario: "se uma cidade, unidade ou territorio estiver
## suficientemente proximo ao covil, podem reagir agressivamente" /
## "melhorias aparecem proximas". Se o alvo mais proximo for a cidade/
## predio em si (sem unidade nele), o guardiao so se aproxima e para —
## nenhum monstro ataca estrutura diretamente (ver nota de arquitetura no
## topo do arquivo).
static func _take_guardian_turn(unit: Unit, hex_grid: HexGrid, turn: int) -> void:
	var home = hex_grid.home_lair_for(unit.coord)
	var anchor = home if home != HexGrid.NO_LAIR else unit.coord
	var radius = _guard_radius_for(unit, hex_grid, turn)
	var target_coord = _nearest_threat_within(anchor, radius, hex_grid)
	if target_coord == null:
		return
	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		var defender = hex_grid.get_unit_at(target_coord)
		if defender != null:
			CombatResolver.resolve(unit, defender, hex_grid)
		return
	_move_toward_within_radius(unit, hex_grid, target_coord, anchor, radius)

## Invasor: briga so com quem encontra pelo caminho (sem escolher alvo
## fora do proprio alcance de ataque atual) e marcha sobre a cidade
## inimiga mais proxima quando nao ha ninguem pra brigar — nunca CAPTURA
## uma cidade (ver nota de arquitetura no topo do arquivo), mas agora
## SAQUEIA um tile trabalhado se terminar o turno em cima de um (ver
## _maybe_pillage_tile) — tanto parado brigando quanto depois de marchar,
## as duas contam como "terminar o turno" no tile atual.
static func _take_invader_turn(unit: Unit, hex_grid: HexGrid, turn: int) -> void:
	var immediate = _hostile_in_attack_range(unit, hex_grid)
	if immediate != null:
		CombatResolver.resolve(unit, immediate, hex_grid)
	else:
		var target_coord = _nearest_city_coord(unit.coord)
		if target_coord != null:
			RivalAI.move_unit_toward(unit, hex_grid, target_coord)
	_maybe_pillage_tile(unit, hex_grid, turn)

## Cobre Esqueleto (Invasor por padrao) e Goblin promovido a Invasor
## (invader_promotable) automaticamente — o comportamento ja e a fonte de
## verdade aqui, sem checar `kind`. Um tile ja pilhado nao "acumula" perda
## de ouro todo turno que o Invasor fica parado nele (is_tile_pillaged
## guarda), so quando a pilhagem anterior ja expirou.
static func _maybe_pillage_tile(unit: Unit, hex_grid: HexGrid, turn: int) -> void:
	if hex_grid.is_tile_pillaged(unit.coord, turn):
		return
	# Fase 25: o alvo é uma melhoria de recurso V2 (a única fonte de rendimento POR TILE da economia
	# V2 — os tiles trabalhados V1 não existem mais). Tile de território sem melhoria não é saqueado.
	var city: City = hex_grid.city_owning_tile(unit.coord)
	if city == null or city.owner_player == null or not city.resource_improvements.has(unit.coord):
		return
	hex_grid.pillage_tile(unit.coord, turn, PILLAGE_DURATION_TURNS)
	city.owner_player.gold = max(0.0, city.owner_player.gold - PILLAGE_GOLD_LOSS)
	if city.owner_player == GameManager.human_player:
		var improvement_name := V2ResourceImprovementData.display_name_for_resource(V2ResourceImprovementData.resource_for_improvement(String(city.resource_improvements[unit.coord])))
		EventBus.notify.emit("Invasores saquearam %s de %s!" % [improvement_name, city.city_name], "combat")

## Saqueador (Goblin por padrao, ver COMPORTAMENTO DOS MONSTROS no topo do
## arquivo): BUSCA ATIVAMENTE presa fraca/isolada (mesmo criterio do
## Cacador, _is_isolated_or_weak) dentro de RAIDER_RADIUS do proprio
## covil -- pondera risco antes de atacar igual o Cacador (nunca
## incondicional como Guardiao/Invasor, "oportunista" implica escolher
## bem a briga). Sem presa a vista, se aproxima da cidade mais proxima
## DENTRO do raio (ameaca de presenca nos arredores, nunca ataque a
## cidade em si) e sempre tenta saquear o tile onde termina o turno
## (_maybe_pillage_tile, mesma mecanica do Invasor) -- e assim que
## "ameacar melhorias" acontece na pratica. Nunca sai do proprio
## territorio: um Goblin sozinho incomoda localmente, um GRUPO que cresce
## o bastante e' promovido a Invasor de verdade (_promote_idle_groups_to_
## invaders), virando uma invasao real.
## AGGRO/TERRITORIO: raio do Saqueador tambem soma ALERT_RADIUS_BONUS
## enquanto o proprio covil estiver alertado, mesmo espirito de
## _guard_radius_for.
static func _raider_radius_for(unit: Unit, hex_grid: HexGrid, turn: int) -> int:
	var radius := RAIDER_RADIUS
	var home := hex_grid.home_lair_for(unit.coord)
	if home != HexGrid.NO_LAIR and hex_grid.is_lair_alerted(home, turn):
		radius += ALERT_RADIUS_BONUS
	return radius

static func _take_raider_turn(unit: Unit, hex_grid: HexGrid, turn: int) -> void:
	var home = hex_grid.home_lair_for(unit.coord)
	var anchor = home if home != HexGrid.NO_LAIR else unit.coord
	var radius = _raider_radius_for(unit, hex_grid, turn)
	var target_coord = _find_weak_or_isolated_target_within(anchor, radius)
	if target_coord != null:
		if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
			var defender = hex_grid.get_unit_at(target_coord)
			if defender != null and RivalAI.is_favorable_attack(unit, defender, hex_grid):
				CombatResolver.resolve(unit, defender, hex_grid)
		else:
			_move_toward_within_radius(unit, hex_grid, target_coord, anchor, radius)
	else:
		# "Melhorias aparecem proximas" -- cidade OU predio, o que estiver
		# mais perto (ver _nearest_settlement_within).
		var settlement_coord = _nearest_settlement_within(anchor, radius, hex_grid)
		if settlement_coord != null:
			_move_toward_within_radius(unit, hex_grid, settlement_coord, anchor, radius)
	_maybe_pillage_tile(unit, hex_grid, turn)

## Cacador: patrulha livre (sem restricao de territorio, ao contrario do
## Guardiao) atras de presa isolada/fraca, mas so ataca se
## RivalAI.is_favorable_attack aprovar — diferente do Guardiao/Invasor
## (que atacam incondicionalmente o que encontram), o Cacador PONDERA risco
## antes de se comprometer, igual a IA rival ja faz.
static func _take_hunter_turn(unit: Unit, hex_grid: HexGrid) -> void:
	var target_coord = _find_hunter_prey(unit, hex_grid)
	if target_coord == null:
		return
	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		var defender = hex_grid.get_unit_at(target_coord)
		if defender != null and RivalAI.is_favorable_attack(unit, defender, hex_grid):
			CombatResolver.resolve(unit, defender, hex_grid)
		return
	RivalAI.move_unit_toward(unit, hex_grid, target_coord)

## Unidade de jogador/rival mais proxima de `anchor` dentro de `radius` —
## monstro e hostil a TODOS os jogadores por igual, sem checar guerra
## (GameManager.players ja exclui qualquer outro monstro neutro, que nao e
## PlayerData, entao monstro nunca briga com monstro por aqui).
static func _nearest_hostile_within(anchor: Vector2i, radius: int):
	var best = null
	var best_dist = radius + 1
	for player in GameManager.players:
		for other in player.units:
			if not is_instance_valid(other):
				continue
			var d = HexMetrics.axial_distance(anchor, other.coord)
			if d <= radius and d < best_dist:
				best_dist = d
				best = other.coord
	return best

## Coordenada da cidade (de QUALQUER jogador) mais proxima de `anchor`
## DENTRO de `radius` -- mesmo espirito de _nearest_city_coord (usado pelo
## Invasor), so com teto de distancia (Guardiao/Saqueador nunca podem sair
## do proprio territorio atras de uma cidade).
static func _nearest_city_within(anchor: Vector2i, radius: int):
	var best = null
	var best_dist = radius + 1
	for player in GameManager.players:
		for city in player.cities:
			var d = HexMetrics.axial_distance(anchor, city.coord)
			if d <= radius and d < best_dist:
				best_dist = d
				best = city.coord
	return best

## AGGRO/TERRITORIO (pedido do usuario: "melhorias aparecem proximas" e'
## um dos gatilhos de reacao): predio (melhoria rural, ver Building.gd)
## mais proximo de `anchor` DENTRO de `radius` -- todo predio no jogo
## pertence a algum jogador (nunca neutro), entao nenhum filtro de dono e'
## necessario aqui, ao contrario de _nearest_hostile_within.
static func _nearest_building_within(anchor: Vector2i, radius: int, hex_grid: HexGrid):
	var best = null
	var best_dist = radius + 1
	for coord in hex_grid.buildings_by_coord.keys():
		var d = HexMetrics.axial_distance(anchor, coord)
		if d <= radius and d < best_dist:
			best_dist = d
			best = coord
	return best

## Cidade OU predio mais proximo de `anchor` dentro do `radius`, o que
## estiver mais perto -- as DUAS formas de "presenca civilizada" que um
## Guardiao/Saqueador sem alvo de unidade tenta se aproximar/ameacar
## (nunca ataca a estrutura em si -- nenhum monstro tem essa capacidade).
static func _nearest_settlement_within(anchor: Vector2i, radius: int, hex_grid: HexGrid):
	var best = _nearest_city_within(anchor, radius)
	var best_dist: int = HexMetrics.axial_distance(anchor, best) if best != null else radius + 1
	var building_coord = _nearest_building_within(anchor, radius, hex_grid)
	if building_coord != null:
		var building_dist: int = HexMetrics.axial_distance(anchor, building_coord)
		if building_dist < best_dist:
			best = building_coord
	return best

## Ver _take_guardian_turn -- alvo mais proximo de `anchor` dentro do
## `radius`, unidade OU cidade/predio (o que estiver mais perto), pedido
## do usuario: "se uma cidade, unidade ou territorio estiver
## suficientemente proximo ao covil, podem reagir agressivamente" /
## "melhorias aparecem proximas". Unidade continua tendo prioridade em
## empate (`<`, nao `<=`, na comparacao com o assentamento) porque e'
## quem o Guardiao realmente consegue combater.
static func _nearest_threat_within(anchor: Vector2i, radius: int, hex_grid: HexGrid):
	var best = _nearest_hostile_within(anchor, radius)
	var best_dist: int = HexMetrics.axial_distance(anchor, best) if best != null else radius + 1
	var settlement_coord = _nearest_settlement_within(anchor, radius, hex_grid)
	if settlement_coord != null:
		var settlement_dist: int = HexMetrics.axial_distance(anchor, settlement_coord)
		if settlement_dist < best_dist:
			best = settlement_coord
	return best

## Mesma ideia de RivalAI.move_unit_toward, so com um filtro extra: nunca aceita
## um tile reachable fora de `radius` de `anchor` — e o que impede o
## Guardiao de perseguir um alvo pra fora do proprio territorio (RivalAI.
## move_unit_toward puro nao tem esse conceito, por isso nao e reusado aqui).
static func _move_toward_within_radius(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i, anchor: Vector2i, radius: int) -> void:
	var reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	var best_coord = null
	var best_dist = HexMetrics.axial_distance(unit.coord, target_coord)
	for coord in reachable.keys():
		if HexMetrics.axial_distance(anchor, coord) > radius:
			continue
		var d = HexMetrics.axial_distance(coord, target_coord)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	if best_coord != null:
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

static func _hostile_in_attack_range(unit: Unit, hex_grid: HexGrid) -> Unit:
	for coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		var other = hex_grid.get_unit_at(coord)
		if other != null and other.owner_player != null:
			return other
	return null

## Cidade (de QUALQUER jogador — humano ou rival, monstro nao escolhe lado)
## mais proxima de `from`.
static func _nearest_city_coord(from: Vector2i):
	var best = null
	var best_dist = 999999
	for player in GameManager.players:
		for city in player.cities:
			var d = HexMetrics.axial_distance(from, city.coord)
			if d < best_dist:
				best_dist = d
				best = city.coord
	return best

## Presa valida (isolada OU fraca, ver _is_isolated_or_weak) mais proxima
## de `unit`, dentro de HUNTER_PATROL_RADIUS -- Cacador patrulha livre,
## entao ancora na PROPRIA posicao atual (nao num covil).
static func _find_hunter_prey(unit: Unit, hex_grid: HexGrid):
	return _find_weak_or_isolated_target_within(unit.coord, HUNTER_PATROL_RADIUS)

## Generalizacao de _find_hunter_prey (COMPORTAMENTO DOS MONSTROS): mesmo
## criterio de presa valida, mas com `anchor`/`radius` configuraveis pra
## tambem servir o Saqueador (ancorado no proprio covil, RAIDER_RADIUS, ver
## _take_raider_turn) sem duplicar a busca.
static func _find_weak_or_isolated_target_within(anchor: Vector2i, radius: int):
	var best = null
	var best_dist = radius + 1
	for player in GameManager.players:
		for other in player.units:
			if not is_instance_valid(other):
				continue
			var d = HexMetrics.axial_distance(anchor, other.coord)
			if d > radius or d >= best_dist:
				continue
			if _is_isolated_or_weak(other, player):
				best_dist = d
				best = other.coord
	return best

static func _is_isolated_or_weak(target: Unit, target_player: PlayerData) -> bool:
	if target.hp < target.unit_data.max_hp * HUNTER_WEAK_HP_FRACTION:
		return true
	for ally in target_player.units:
		if ally == target or not is_instance_valid(ally):
			continue
		if HexMetrics.axial_distance(ally.coord, target.coord) <= HUNTER_ISOLATION_RADIUS:
			return false
	return true
