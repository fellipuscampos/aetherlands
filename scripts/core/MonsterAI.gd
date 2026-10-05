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
	# V3 / Etapa 2: o Dragão NÃO pausa o ecossistema — só o selvagem LEGADO (covil da seed sem papel, fora da
	# ecologia) mantém a regra antiga de recolher; ecologia, ameaça regional, Guardião e guardiões de evento seguem.
	if _is_dragon_event_active() and _recalled_by_dragon(unit, hex_grid):
		_take_recalled_turn(unit, hex_grid)
		return
	# Fase 33D3: guardião de evento mundial (Relicário) guarda o próprio local; nunca vira invasor.
	if unit.source_event_id >= 0:
		var event := WorldEventManager.event_by_id(unit.source_event_id)
		if event is ReliquaryEvent:
			_take_anchored_guard_turn(unit, hex_grid, (event as ReliquaryEvent).site_coord, GUARD_RADIUS)
			return
	# V3 / Combat Ecology: monstro de sítio ecológico segue o perfil de atividade da Era (tier × era).
	var ecology := MonsterEcologySystem.monster_directive(unit)
	if not ecology.is_empty():
		_take_ecology_turn(unit, hex_grid, turn, ecology)
		return
	# Fase 33D2: monstro de covil com PAPEL (ameaça regional / Guardião Troll) segue a diretiva do papel.
	var directive := RegionalThreatSystem.monster_directive(unit, hex_grid)
	if not directive.is_empty():
		_take_directed_turn(unit, hex_grid, turn, directive)
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

static func _recalled_by_dragon(unit: Unit, hex_grid: HexGrid) -> bool:
	return unit.ecology_site_id < 0 and unit.source_event_id < 0 and not hex_grid.is_bound_to_role_lair(unit)

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
		# Fase 33D2: ameaça regional não vira invasão de mapa no Despertar; Guardião nunca.
		if RegionalThreatSystem.blocks_invader_promotion(hex_grid, lair_coord):
			continue
		if hex_grid.lair_role(lair_coord) == HexGrid.LAIR_ROLE_ECOLOGY:
			continue # V3: covil adotado pela ecologia nunca vira invasão legada de mapa inteiro
		var info: Dictionary = MonsterDatabase.KIND_DATA.get(kind, {})
		if not info.get("invader_promotable", false):
			continue
		var idle: Array[Unit] = []
		for coord in hex_grid._lair_area(lair_coord):
			var unit = hex_grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.is_camp_boss and unit.monster_behavior_state == "" and unit.ecology_site_id < 0:
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
	_take_anchored_guard_turn(unit, hex_grid, anchor, _guard_radius_for(unit, hex_grid, turn))

## Guardião com âncora/raio explícitos (Fase 33D2: covil com papel ancora no PRÓPRIO covil de origem, não
## no covil do tile atual).
static func _take_anchored_guard_turn(unit: Unit, hex_grid: HexGrid, anchor: Vector2i, radius: int) -> void:
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
static func _maybe_pillage_tile(unit: Unit, hex_grid: HexGrid, turn: int) -> bool:
	if hex_grid.is_tile_pillaged(unit.coord, turn):
		return false
	# Fase 25: o alvo é uma melhoria de recurso V2 (a única fonte de rendimento POR TILE da economia
	# V2 — os tiles trabalhados V1 não existem mais). Tile de território sem melhoria não é saqueado.
	var city: City = hex_grid.city_owning_tile(unit.coord)
	if city == null or city.owner_player == null or not city.resource_improvements.has(unit.coord):
		return false
	hex_grid.pillage_tile(unit.coord, turn, PILLAGE_DURATION_TURNS)
	city.owner_player.gold = max(0.0, city.owner_player.gold - PILLAGE_GOLD_LOSS)
	EventBus.tile_pillaged.emit(city.owner_player, unit.coord) # Fase 33D1: observabilidade
	if city.owner_player == GameManager.human_player:
		var improvement_name := V2ResourceImprovementData.display_name_for_resource(V2ResourceImprovementData.resource_for_improvement(String(city.resource_improvements[unit.coord])))
		EventBus.notify.emit("Invasores saquearam %s de %s!" % [improvement_name, city.city_name], "combat")
	return true

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
	_take_anchored_raider_turn(unit, hex_grid, turn, anchor, _raider_radius_for(unit, hex_grid, turn))

## Saqueador com âncora/raio explícitos (Fase 33D2: teatro regional).
static func _take_anchored_raider_turn(unit: Unit, hex_grid: HexGrid, turn: int, anchor: Vector2i, radius: int) -> void:
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

## Fase 33D2 — diretiva de covil com papel (RegionalThreatSystem.monster_directive):
## - dormant: guarda a porta do próprio covil (raio de Guardião), nunca saqueia nem invade;
## - regional (desperto, Era do Despertar): Goblin = Saqueador preso ao teatro regional (âncora no covil,
##   raio até os arredores da capital); Esqueleto = pressão numérica no MESMO teatro (briga com quem estiver
##   ao alcance, avança sobre cidade/construção do teatro e saqueia), nunca a marcha de mapa inteiro;
## - guardian: Guardião Troll ancorado no próprio covil (raio do tipo).
static func _take_directed_turn(unit: Unit, hex_grid: HexGrid, turn: int, directive: Dictionary) -> void:
	var anchor: Vector2i = directive.anchor
	var radius := int(directive.radius)
	match String(directive.mode):
		"dormant", "guardian":
			_take_anchored_guard_turn(unit, hex_grid, anchor, radius)
		"regional":
			if _effective_behavior(unit) == MonsterDatabase.BEHAVIOR_INVADER:
				_take_theater_invader_turn(unit, hex_grid, turn, anchor, radius)
			else:
				_take_anchored_raider_turn(unit, hex_grid, turn, anchor, radius)

static func _take_theater_invader_turn(unit: Unit, hex_grid: HexGrid, turn: int, anchor: Vector2i, radius: int) -> void:
	var immediate = _hostile_in_attack_range(unit, hex_grid)
	if immediate != null:
		CombatResolver.resolve(unit, immediate, hex_grid)
	else:
		var target_coord = _nearest_threat_within(anchor, radius, hex_grid)
		if target_coord != null:
			_move_toward_within_radius(unit, hex_grid, target_coord, anchor, radius)
	if is_instance_valid(unit) and unit.hp > 0.0:
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
	if best_coord == null and MonsterEcologySystem.is_ecology_unit(unit):
		best_coord = _ecology_detour_step(unit, hex_grid, target_coord, anchor, radius, reachable)
	if best_coord != null:
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

## V3 / Etapa 4 — desvio quando o passo guloso não acha tile mais perto (mínimo local: cidade, água ou montanha no meio
## do caminho). Usa o A* do HexGrid até o destino (ou, ocupado, até o primeiro vizinho livre dele) e avança o máximo que
## o Movimento do turno permite dentro do raio. Só roda nesse caso travado — antes o monstro ficava parado (ex.: Goblin
## "voltando para casa" ao lado de uma cidade por 9 turnos). Só criaturas da ecologia.
static func _ecology_detour_step(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i, anchor: Vector2i, radius: int, reachable: Dictionary):
	var goals: Array[Vector2i] = [target_coord]
	goals.append_array(MonsterEcologyPlanner.sorted_coords(hex_grid.get_neighbors(target_coord)))
	for goal in goals.slice(0, DETOUR_GOALS):
		if goal == unit.coord:
			continue
		var path := hex_grid.compute_path(unit.coord, goal, unit.owner_player, unit.unit_data.flies)
		var step = null
		for coord in path:
			if not reachable.has(coord) or HexMetrics.axial_distance(anchor, coord) > radius:
				break
			step = coord
		if step != null:
			return step
		if not path.is_empty():
			return null # caminho existe, mas o primeiro passo sai do raio: fica
	return null

## Destinos tentados pelo desvio (o alvo e até 3 vizinhos dele) — limita o custo do A* no caso travado.
const DETOUR_GOALS := 4

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

# ---------------------------------------------------------------------------
# V3 / Combat Ecology — atividade por Era (MonsterActivityProfile via MonsterEcologySystem.monster_directive)
# Etapa 2: TIER define a intensidade (perfil da era); ESPÉCIE define a identidade (MonsterEcologyData.behavior +
# MonsterAbilityData via MonsterAbilitySystem). Uma única IA genérica — nenhum planner por monstro.
# ---------------------------------------------------------------------------

## Fração máxima do HP ATUAL de uma cidade que UM golpe de monstro da ecologia tira (mesmo mecanismo do raid
## do Dragão em CombatResolver.resolve_city_attack; atacante neutro nunca captura — a cidade fica em >= 1 HP).
## V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER.
const ECOLOGY_CITY_RAID_FRACTION := 0.25

## Um turno de monstro da ecologia. Uma ação por turno (ou move, ou ataca/usa habilidade), em ordem:
## 0. passivas de início de turno (Regeneração Monstruosa); Verme subterrâneo/recém-emergido não age;
## 1. habilidade ativa da espécie, se pronta e com alvo legítimo dentro da zona da era;
## 2. unidade de civilização ao alcance de ataque → ataca (a melhor; BASIC nunca inicia luta claramente perdida —
##    o Esqueleto, sem chance, recua para o bando);
## 3. presa dentro do território (raio de patrulha; presas especiais — grupo/conjurador — até o raio de interesse
##    da era) → persegue sem sair da zona; o Worg caça o isolado com +1 Movimento e golpeia no mesmo turno;
## 4. raide de cidade só para espécies city_hunt, na era em que o tier caça cidades (Goblin no máximo 2 por cidade;
##    Esqueleto só sai com o bando de 3+); um golpe por raide e depois descanso;
## 5. melhoria (só espécies improvement_hunt);
## 6. fora do território → volta; ocioso → ronda (RNG da ecologia).
## Alvos por distância/estado com desempate por coordenada — nunca por ordem de jogador/identidade humana.
static func _take_ecology_turn(unit: Unit, hex_grid: HexGrid, turn: int, directive: Dictionary) -> void:
	if MonsterAbilitySystem.skips_turn(unit, turn):
		return
	MonsterAbilitySystem.on_turn_start(unit, hex_grid)
	var anchor: Vector2i = directive.anchor
	var profile: Dictionary = directive.profile
	var kind := unit.unit_data.visual_kind
	var behavior := MonsterEcologyData.behavior(kind)
	var ranges := ecology_ranges(kind, profile)
	var patrol := int(ranges.patrol)
	var chase := int(ranges.leash)
	var interest := int(ranges.interest)
	var prey_mode := String(behavior.prey)
	var zone := int(ranges.zone)
	var search := int(ranges.search)
	# Etapa 3: habilidade ofensiva respeita o mesmo alcance de interesse do aggro (ou o alvo já perseguido).
	MonsterAbilitySystem.engage_reach = maxi(int(profile.aggro_radius), interest if prey_mode in ["group", "caster"] and interest > 0 else 0)
	var used_active := MonsterAbilitySystem.try_active(unit, hex_grid, anchor, zone)
	MonsterAbilitySystem.engage_reach = -1
	if used_active:
		return
	var attack := _ecology_attack_choice(unit, hex_grid, behavior)
	if attack.has("target"):
		_ecology_attack(unit, hex_grid, attack.target, turn, behavior)
		return
	if bool(attack.get("regroup", false)) and bool(behavior.get("group_raid", false)):
		_ecology_regroup(unit, hex_grid, anchor, zone)
		return
	# Etapa 3 — RETORNANDO: depois de desistir de um alvo, volta para a âncora sem readquirir alvo distante (só se
	# defende de quem encostar, passo 2 acima); chegando perto de casa, o aggro normal volta.
	if _ecology_returning_step(unit, hex_grid, anchor, chase):
		return
	var raiding := unit.ecology_rest_until <= turn
	if not raiding:
		unit.ability_state.erase("raid_target")
	# Raide primeiro para quem tem o raide como identidade (Goblin, Esqueleto, Wyvern) quando a era do tier caça
	# cidades: a caça a unidades no território vem depois. Um golpe por raide e depois descanso.
	var city_radius := int(profile.city_radius)
	# Etapa 3: a Wyvern só faz raide oportunista dentro do próprio leash (nunca cerco a partir de 12 tiles).
	if bool(behavior.get("local_raid", false)) and city_radius > 0:
		city_radius = mini(city_radius, chase)
	if raiding and bool(behavior.city_hunt) and city_radius > 0 and turn >= int(profile.get("city_from_turn", 0)):
		var city := _ecology_raid_target(unit, anchor, city_radius, behavior, hex_grid)
		if city != null:
			if _ecology_press_city(unit, hex_grid, city, anchor, city_radius + 1):
				unit.ecology_rest_until = turn + int(profile.get("raid_rest_turns", 0))
				unit.ability_state.erase("raid_target")
			return
	# Etapa 3 — AGGRO / PERSEGUIÇÃO / LEASH: intruso a aggro_radius do monstro vira alvo; persegue enquanto ele estiver
	# a pursuit_radius e dentro do leash (chase_radius da âncora); fora disso desiste e entra em RETORNO.
	var aggro := int(profile.aggro_radius)
	var interest_aggro := interest if prey_mode in ["group", "caster"] and interest > 0 else 0
	var prey := _ecology_aggro_target(unit, hex_grid, anchor, aggro, interest_aggro, int(profile.pursuit_radius), chase, zone, prey_mode, behavior)
	if prey != null:
		_ecology_hunt(unit, hex_grid, prey, anchor, zone, behavior, turn)
		return
	if bool(unit.ability_state.get("returning", false)):
		_ecology_returning_step(unit, hex_grid, anchor, chase)
		return
	var improvement_radius := int(profile.improvement_radius) if raiding and bool(behavior.improvement_hunt) else 0
	if improvement_radius > 0:
		var improvement = _ecology_improvement_target(unit, anchor, improvement_radius, hex_grid, turn)
		if improvement != null:
			if unit.coord != improvement:
				_ecology_move(unit, hex_grid, improvement, anchor, improvement_radius, "improvement")
			if _ecology_pillage(unit, hex_grid, turn):
				unit.ecology_rest_until = turn + int(profile.get("raid_rest_turns", 0))
			return
	# Espécie de bando (Esqueleto) ociosa fica junta na âncora — a horda se reúne em vez de se espalhar rondando.
	# Depois de um raide (descanso) o monstro RECUA para a âncora, em vez de ficar rondando perto da cidade atingida.
	var home_radius := 1 if bool(behavior.get("group_raid", false)) or not raiding else patrol
	if HexMetrics.axial_distance(unit.coord, anchor) > home_radius:
		_ecology_move(unit, hex_grid, anchor, anchor, HexMetrics.axial_distance(unit.coord, anchor), "return")
	elif home_radius == patrol and _next_to_city(hex_grid, unit.coord):
		_ecology_roam(unit, hex_grid, anchor, patrol) # Etapa 4: ocioso colado numa cidade sempre sai dali (sem sorteio)
	elif home_radius == patrol and float(profile.roam_chance) > 0.0 and MonsterEcologySystem.rng.randf() < float(profile.roam_chance):
		_ecology_roam(unit, hex_grid, anchor, patrol)
	if improvement_radius > 0 and _ecology_pillage(unit, hex_grid, turn):
		unit.ecology_rest_until = turn + int(profile.get("raid_rest_turns", 0))

## Raios efetivos de uma espécie no perfil da era: patrulha, LEASH (chase_radius + bônus da espécie), interesse
## (city_radius), ZONA (leash, ou o interesse para quem caça presa especial — grupo/conjurador) e busca. Fonte única
## para a IA e para a telemetria do gate de leash.
static func ecology_ranges(kind: String, profile: Dictionary) -> Dictionary:
	var behavior := MonsterEcologyData.behavior(kind)
	var patrol := int(profile.patrol_radius)
	var chase := maxi(int(profile.chase_radius) + int(behavior.chase_bonus), patrol)
	if int(behavior.chase_bonus) > 0:
		patrol += int(behavior.chase_bonus)
		chase = maxi(chase, patrol)
	var interest := int(profile.city_radius)
	var zone := chase
	var search := patrol
	if String(behavior.prey) in ["group", "caster"] and interest > 0:
		zone = maxi(zone, interest)
		search = maxi(search, interest)
	return {"patrol": patrol, "leash": chase, "interest": interest, "zone": zone, "search": search}

## Etapa 3 — raio da âncora em que o monstro conta como "em casa" e volta a adquirir alvos normalmente.
const RETURN_HOME_RADIUS := 1

## Passo de RETORNO (estado salvo em ability_state.returning). true = o turno foi gasto voltando.
static func _ecology_returning_step(unit: Unit, hex_grid: HexGrid, anchor: Vector2i, leash: int) -> bool:
	if not bool(unit.ability_state.get("returning", false)):
		return false
	if HexMetrics.axial_distance(unit.coord, anchor) <= RETURN_HOME_RADIUS:
		unit.ability_state.erase("returning")
		MonsterEcologySystem.emit_unit_event("return_home", unit, {})
		return false
	_ecology_move(unit, hex_grid, anchor, anchor, maxi(leash, HexMetrics.axial_distance(unit.coord, anchor)), "return")
	if is_instance_valid(unit) and HexMetrics.axial_distance(unit.coord, anchor) <= RETURN_HOME_RADIUS:
		unit.ability_state.erase("returning")
		MonsterEcologySystem.emit_unit_event("return_home", unit, {})
	return true

## Alvo de aggro do turno (estado salvo em ability_state: aggro_target = serial, aggro_coord = último tile visto):
## mantém o alvo atual enquanto ele estiver a `pursuit` do monstro e dentro do leash da âncora; senão desiste
## (leash_disengage → RETORNO). Sem alvo, adquire o intruso a `aggro` (ou presa especial — grupo/conjurador — a
## `interest`) pela prioridade da espécie. Busca LIMITADA ao raio (tiles em volta do monstro), nunca o mapa todo.
static func _ecology_aggro_target(unit: Unit, hex_grid: HexGrid, anchor: Vector2i, aggro: int, interest: int, pursuit: int, leash: int, zone: int, mode: String, behavior: Dictionary) -> Unit:
	var state := unit.ability_state
	if state.has("aggro_target"):
		var current := _ecology_find_by_serial(hex_grid, int(state.aggro_target), MonsterAbilitySystem._coord(state.get("aggro_coord")), maxi(pursuit, interest) + 2)
		var limit := maxi(pursuit, interest)
		var limit_zone := maxi(leash, zone)
		if current != null and _ecology_unpursuable(unit, current, hex_grid, behavior):
			# Etapa 4: alvo entrou numa cidade (guarnição — cidade só se enfrenta em raide) ou virou luta claramente
			# perdida para quem evita: perde o interesse e volta para casa, em vez de ficar parado colado na cidade.
			state.erase("aggro_target")
			state.erase("aggro_coord")
			state.returning = true
			MonsterEcologySystem.emit_unit_event("aggro_drop", unit, {"target": GameManager.players.find(current.owner_player)})
			return null
		if current != null and HexMetrics.axial_distance(unit.coord, current.coord) <= limit and HexMetrics.axial_distance(anchor, current.coord) <= limit_zone + 1:
			state.aggro_coord = [current.coord.x, current.coord.y]
			return current
		state.erase("aggro_target")
		state.erase("aggro_coord")
		state.returning = true
		MonsterEcologySystem.emit_unit_event("leash_disengage", unit, {"anchor_distance": HexMetrics.axial_distance(unit.coord, anchor)})
		return null
	var radius := maxi(aggro, interest)
	var best: Unit = null
	var best_key: Array = []
	for coord in HexMetrics.coords_within(unit.coord, radius):
		var other := hex_grid.get_unit_at(coord)
		if other == null or other.owner_player == null or other.hp <= 0.0:
			continue
		var d := HexMetrics.axial_distance(unit.coord, coord)
		if HexMetrics.axial_distance(anchor, coord) > maxi(leash, zone):
			continue
		var special := 0
		match mode:
			"isolated":
				special = 1 if _ecology_isolated(other, hex_grid) or _ecology_wounded(other) else 0
			"group":
				special = MonsterAbilitySystem._civ_units_near(hex_grid, other.coord, 1).size()
			"caster":
				special = 1 if MonsterAbilitySystem._is_caster(other) else 0
		var special_target := mode in ["group", "caster"] and (special >= (2 if mode == "group" else 1))
		if d > aggro and not (special_target and d <= interest):
			continue
		if _ecology_unpursuable(unit, other, hex_grid, behavior):
			continue
		var key := [special, -d, -coord.x, -coord.y]
		if best == null or _key_greater(key, best_key):
			best = other
			best_key = key
	if best != null:
		state.aggro_target = best.serial_id
		state.aggro_coord = [best.coord.x, best.coord.y]
		MonsterEcologySystem.emit_unit_event("aggro_acquire", unit, {"target": GameManager.players.find(best.owner_player), "distance": HexMetrics.axial_distance(unit.coord, best.coord), "target_coord": [best.coord.x, best.coord.y], "source": [unit.coord.x, unit.coord.y]})
	return best

## Etapa 4 — alvo que o aggro não persegue: unidade dentro de uma cidade (a guarnição só é enfrentada pelo raide; a
## perseguição terminava com o monstro parado ao lado da cidade sem atacar — bug do playtest) ou, para quem evita lutas
## perdidas (BASIC), luta claramente perdida. O ataque a quem já está ao alcance (_ecology_attack_choice) não muda.
static func _ecology_unpursuable(unit: Unit, target: Unit, hex_grid: HexGrid, behavior: Dictionary) -> bool:
	if hex_grid.get_city_at(target.coord) != null:
		return true
	return bool(behavior.get("avoid_bad_fights", false)) and _ecology_clearly_bad(unit, target, hex_grid, _ecology_strike(unit, target, hex_grid, behavior))

static func _ecology_find_by_serial(hex_grid: HexGrid, serial: int, last: Vector2i, radius: int) -> Unit:
	var at_last := hex_grid.get_unit_at(last) if last != HexGrid.NO_LAIR else null
	if at_last != null and at_last.serial_id == serial:
		return at_last
	if last == HexGrid.NO_LAIR:
		return null
	for coord in HexMetrics.coords_within(last, radius):
		var other := hex_grid.get_unit_at(coord)
		if other != null and other.serial_id == serial:
			return other
	return null

## Luta claramente perdida: o atacante morreria e o alvo sobreviveria (estimador existente, CombatResolver.predict).
static func _ecology_clearly_bad(unit: Unit, target: Unit, hex_grid: HexGrid, strike: float = 1.0) -> bool:
	var prediction := CombatResolver.predict(unit, target, hex_grid, strike)
	return bool(prediction.attacker_dies) and not bool(prediction.defender_dies)

static func _ecology_isolated(target: Unit, hex_grid: HexGrid) -> bool:
	for neighbor in hex_grid.get_neighbors(target.coord):
		var other := hex_grid.get_unit_at(neighbor)
		if other != null and other != target and other.owner_player == target.owner_player:
			return false
	return true

static func _ecology_wounded(target: Unit) -> bool:
	return target.hp < target.unit_data.max_hp * float(MonsterAbilityData.param(MonsterAbilityData.BLOOD_SCENT, "wounded_fraction", 0.5))

## Melhor alvo AO ALCANCE agora: {target} | {regroup: true} (só havia luta perdida e o monstro evita) | {}.
static func _ecology_attack_choice(unit: Unit, hex_grid: HexGrid, behavior: Dictionary) -> Dictionary:
	var best: Unit = null
	var best_key: Array = []
	var saw_bad := false
	for coord in MonsterEcologyPlanner.sorted_coords(hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range)):
		var other := hex_grid.get_unit_at(coord)
		if other == null or other.owner_player == null or other.hp <= 0.0:
			continue
		var strike := _ecology_strike(unit, other, hex_grid, behavior)
		if bool(behavior.avoid_bad_fights) and _ecology_clearly_bad(unit, other, hex_grid, strike):
			saw_bad = true
			continue
		var prediction := CombatResolver.predict(unit, other, hex_grid, strike)
		var priority := 0
		if String(behavior.prey) == "isolated" and (_ecology_isolated(other, hex_grid) or _ecology_wounded(other)):
			priority = 1
		var key := [priority, 1 if bool(prediction.defender_dies) else 0, -other.hp]
		if best == null or _key_greater(key, best_key):
			best = other
			best_key = key
	if best != null:
		return {"target": best}
	return {"regroup": true} if saw_bad else {}

static func _key_greater(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false

## Faro de Sangue (Worg): +25% no primeiro golpe do turno contra alvo isolado. Nunca contra cidade.
static func _ecology_strike(unit: Unit, target: Unit, hex_grid: HexGrid, behavior: Dictionary) -> float:
	if MonsterAbilitySystem.has(unit, MonsterAbilityData.BLOOD_SCENT) and _ecology_isolated(target, hex_grid) and int(unit.ability_state.get("hunt_strike_turn", -1)) != TurnManager.turn_number:
		return 1.0 + float(MonsterAbilityData.param(MonsterAbilityData.BLOOD_SCENT, "attack_bonus", 0.25))
	return 1.0

static func _ecology_attack(unit: Unit, hex_grid: HexGrid, target: Unit, turn: int, behavior: Dictionary) -> void:
	var target_index := GameManager.players.find(target.owner_player)
	var strike := _ecology_strike(unit, target, hex_grid, behavior)
	if strike > 1.0:
		unit.ability_state["hunt_strike_turn"] = turn
		MonsterEcologySystem.emit_unit_event("ability", unit, {"ability": MonsterAbilityData.BLOOD_SCENT, "hits": 1, "hunt_bonus_attack": 1, "target": target_index, "source": [unit.coord.x, unit.coord.y], "target_coord": [target.coord.x, target.coord.y]})
	var hp_before := target.hp
	CombatResolver.resolve(unit, target, hex_grid, strike)
	MonsterEcologySystem.emit_unit_event("attack", unit, {"target": target_index})
	if is_instance_valid(unit) and unit.hp > 0.0:
		MonsterAbilitySystem.after_attack(unit, target, hp_before)

## Esqueleto (ou BASIC) diante de luta perdida: recua para perto do bando/âncora em vez de se jogar.
static func _ecology_regroup(unit: Unit, hex_grid: HexGrid, anchor: Vector2i, zone: int) -> void:
	var rally := anchor
	var best := 999999
	for other in hex_grid.neutral_units():
		if other != unit and other.ecology_site_id >= 0 and other.unit_data.visual_kind == unit.unit_data.visual_kind:
			var d := HexMetrics.axial_distance(unit.coord, other.coord)
			if d > 1 and d < best and HexMetrics.axial_distance(anchor, other.coord) <= zone:
				best = d
				rally = other.coord
	_ecology_move(unit, hex_grid, rally, anchor, maxi(zone, HexMetrics.axial_distance(unit.coord, anchor)), "regroup")

## Presa no território: unidade de civilização a ≤ `radius` da âncora, escolhida pelo modo da espécie:
## any (mais perto da âncora), isolated (isolada/ferida primeiro), group (mais aliados colados), caster (conjurador
## primeiro). Desempate por coordenada. Nunca fora do raio legítimo da era.
static func _ecology_select_prey(unit: Unit, anchor: Vector2i, radius: int, mode: String, hex_grid: HexGrid, behavior: Dictionary = {}) -> Unit:
	var best: Unit = null
	var best_key: Array = []
	for player in GameManager.players:
		for other in player.units:
			if not is_instance_valid(other) or other.hp <= 0.0:
				continue
			var d := HexMetrics.axial_distance(anchor, other.coord)
			if d > radius:
				continue
			var special := 0
			match mode:
				"isolated":
					special = 1 if _ecology_isolated(other, hex_grid) or _ecology_wounded(other) else 0
				"group":
					special = MonsterAbilitySystem._civ_units_near(hex_grid, other.coord, 1).size()
				"caster":
					special = 1 if MonsterAbilitySystem._is_caster(other) else 0
			if mode in ["group", "caster"] and special == 0 and d > int(MonsterEcologySystem.monster_directive(unit).profile.patrol_radius):
				continue # presa comum além da patrulha: o raio de interesse vale só para a presa especial
			if bool(behavior.get("avoid_bad_fights", false)) and _ecology_clearly_bad(unit, other, hex_grid, _ecology_strike(unit, other, hex_grid, behavior)):
				continue # BASIC não persegue presa que claramente o mataria
			var key := [special, -d, -other.coord.x, -other.coord.y]
			if best == null or _key_greater(key, best_key):
				best = other
				best_key = key
	return best

static func _ecology_hunt(unit: Unit, hex_grid: HexGrid, prey: Unit, anchor: Vector2i, zone: int, behavior: Dictionary, turn: int) -> void:
	var worg_hunt := MonsterAbilitySystem.has(unit, MonsterAbilityData.BLOOD_SCENT) and _ecology_isolated(prey, hex_grid)
	if worg_hunt and int(unit.ability_state.get("hunt_move_turn", -1)) != turn:
		unit.ability_state["hunt_move_turn"] = turn
		unit.movement_left += float(MonsterAbilityData.param(MonsterAbilityData.BLOOD_SCENT, "movement_bonus", 1.0))
		MonsterEcologySystem.emit_unit_event("ability", unit, {"ability": MonsterAbilityData.BLOOD_SCENT, "hits": 1, "isolated_hunted": 1, "target": GameManager.players.find(prey.owner_player), "source": [unit.coord.x, unit.coord.y], "target_coord": [prey.coord.x, prey.coord.y]})
	var before := HexMetrics.axial_distance(unit.coord, prey.coord)
	_ecology_move(unit, hex_grid, prey.coord, anchor, zone, "chase")
	# Etapa 4: perseguição sem progresso (alvo inalcançável — atrás de uma cidade, água, bloqueio) por PURSUIT_STUCK_TURNS
	# turnos seguidos → perde o interesse e volta para casa; nunca fica parado ao lado do alvo/da cidade indefinidamente.
	if is_instance_valid(unit) and is_instance_valid(prey):
		var after := HexMetrics.axial_distance(unit.coord, prey.coord)
		if after >= before and after > unit.unit_data.attack_range:
			var stuck := int(unit.ability_state.get("pursuit_stuck", 0)) + 1
			unit.ability_state["pursuit_stuck"] = stuck
			if stuck >= PURSUIT_STUCK_TURNS:
				unit.ability_state.erase("pursuit_stuck")
				unit.ability_state.erase("aggro_target")
				unit.ability_state.erase("aggro_coord")
				unit.ability_state.returning = true
				MonsterEcologySystem.emit_unit_event("aggro_drop", unit, {"target": GameManager.players.find(prey.owner_player), "reason": "unreachable"})
				return
		else:
			unit.ability_state.erase("pursuit_stuck")
	# O caçador fecha a distância e golpeia no mesmo turno quando alcança o isolado.
	if worg_hunt and is_instance_valid(prey) and is_instance_valid(unit) and HexMetrics.axial_distance(unit.coord, prey.coord) <= unit.unit_data.attack_range:
		if not (bool(behavior.avoid_bad_fights) and _ecology_clearly_bad(unit, prey, hex_grid, _ecology_strike(unit, prey, hex_grid, behavior))):
			_ecology_attack(unit, hex_grid, prey, turn, behavior)

## Turnos seguidos de perseguição sem chegar mais perto até desistir do alvo (Etapa 4).
const PURSUIT_STUCK_TURNS := 2

## Cidade alvo de raide: a já combinada (raid_target) ou a mais próxima da âncora no raio; o Goblin respeita o teto
## de 2 por cidade e o Esqueleto só parte com o bando (3+ Esqueletos da ecologia a ≤ 2 dele).
static func _ecology_raid_target(unit: Unit, anchor: Vector2i, radius: int, behavior: Dictionary, hex_grid: HexGrid) -> City:
	var committed := MonsterAbilitySystem._coord(unit.ability_state.get("raid_target"))
	if committed != HexGrid.NO_LAIR:
		var existing := hex_grid.get_city_at(committed)
		if existing != null and existing.owner_player != null and HexMetrics.axial_distance(anchor, committed) <= radius:
			return existing
		unit.ability_state.erase("raid_target")
	var city := _ecology_city_target(anchor, radius)
	if city == null:
		return null
	if MonsterAbilitySystem.has(unit, MonsterAbilityData.QUICK_PLUNDER):
		var raiders := 0
		for other in hex_grid.neutral_units():
			if other != unit and MonsterAbilitySystem._coord(other.ability_state.get("raid_target")) == city.coord:
				raiders += 1
		if raiders >= int(MonsterAbilityData.param(MonsterAbilityData.QUICK_PLUNDER, "max_raiders", 2)):
			return null
	if bool(behavior.get("group_raid", false)):
		var band := 0
		var group_radius := int(MonsterAbilityData.param(MonsterAbilityData.RISING_HORDE, "group_radius", 2))
		for other in hex_grid.neutral_units():
			if other.ecology_site_id >= 0 and other.unit_data.visual_kind == unit.unit_data.visual_kind and HexMetrics.axial_distance(unit.coord, other.coord) <= group_radius:
				band += 1
		if band < int(MonsterAbilityData.param(MonsterAbilityData.RISING_HORDE, "group_min", 3)):
			return null
	unit.ability_state["raid_target"] = [city.coord.x, city.coord.y]
	return city

static func _ecology_move(unit: Unit, hex_grid: HexGrid, target: Vector2i, anchor: Vector2i, radius: int, reason: String) -> void:
	var before := unit.coord
	_move_toward_within_radius(unit, hex_grid, target, anchor, radius)
	if is_instance_valid(unit) and unit.coord != before:
		MonsterEcologySystem.emit_unit_event("move", unit, {"reason": reason, "anchor_distance": HexMetrics.axial_distance(unit.coord, anchor), "from": [before.x, before.y], "to": [unit.coord.x, unit.coord.y]})

## true = o raide terminou neste turno (golpeou a cidade/guarnição ou, Goblin, desistiu sem conseguir se aproximar);
## false = só se aproximou.
static func _ecology_press_city(unit: Unit, hex_grid: HexGrid, city: City, anchor: Vector2i, radius: int) -> bool:
	if HexMetrics.axial_distance(unit.coord, city.coord) <= unit.unit_data.attack_range:
		_ecology_strike_city(unit, hex_grid, city, anchor)
		return true
	var before := HexMetrics.axial_distance(unit.coord, city.coord)
	_ecology_move(unit, hex_grid, city.coord, anchor, radius, "city")
	if not is_instance_valid(unit) or not MonsterAbilitySystem.has(unit, MonsterAbilityData.QUICK_PLUNDER):
		return false
	# Etapa 4 — Goblin: chegou à posição de ataque → golpeia na MESMA ação. Antes ele terminava o turno colado na cidade
	# (dentro do território) e só golpeava na fase dos monstros seguinte: o jogador via um Goblin parado na cidade.
	if HexMetrics.axial_distance(unit.coord, city.coord) <= unit.unit_data.attack_range:
		_ecology_strike_city(unit, hex_grid, city, anchor)
		return true
	# Posições de ataque ocupadas/inalcançáveis: sem progresso por RAID_STUCK_TURNS turnos, desiste e volta para casa.
	if HexMetrics.axial_distance(unit.coord, city.coord) >= before:
		var stuck := int(unit.ability_state.get("raid_stuck", 0)) + 1
		if stuck >= RAID_STUCK_TURNS:
			unit.ability_state.erase("raid_stuck")
			MonsterEcologySystem.emit_unit_event("raid_abandoned", unit, {"target": GameManager.players.find(city.owner_player)})
			return true
		unit.ability_state["raid_stuck"] = stuck
	else:
		unit.ability_state.erase("raid_stuck")
	return false

## Turnos seguidos sem chegar mais perto da cidade alvo até o Goblin desistir do raide (nunca fica rondando colado).
const RAID_STUCK_TURNS := 2

## Um golpe de raide: na guarnição (combate normal) ou na própria cidade (dano limitado + Saque Rápido do Goblin).
## Goblin recua no mesmo turno depois do golpe (bate-e-foge); Esqueleto/Wyvern ficam como antes.
static func _ecology_strike_city(unit: Unit, hex_grid: HexGrid, city: City, anchor: Vector2i) -> void:
	var target_index := GameManager.players.find(city.owner_player)
	var garrison := hex_grid.get_unit_at(city.coord)
	if garrison != null and garrison.owner_player != null:
		CombatResolver.resolve(unit, garrison, hex_grid)
		MonsterEcologySystem.emit_unit_event("city_attack", unit, {"target": target_index, "garrison": true})
	else:
		CombatResolver.resolve_city_attack(unit, city, hex_grid, ECOLOGY_CITY_RAID_FRACTION)
		MonsterEcologySystem.emit_unit_event("city_attack", unit, {"target": target_index, "garrison": false, "city_hp": city.hp})
		MonsterAbilitySystem.on_city_hit(unit, city) # Saque Rápido (Goblin)
	if not is_instance_valid(unit):
		return
	unit.ability_state.erase("raid_stuck")
	if unit.hp > 0.0 and MonsterAbilitySystem.has(unit, MonsterAbilityData.QUICK_PLUNDER):
		_ecology_raid_retreat(unit, hex_grid, city.coord, anchor)

## Etapa 4 — Saque Rápido "rouba e recua": depois do golpe o Goblin sai do entorno da cidade no MESMO turno — até
## `retreat_steps` tiles com o Movimento base, sempre para mais longe da cidade e, no empate, mais perto de casa
## (desempate por coordenada). Sem tile que afaste, fica onde está (o descanso o leva para a âncora no turno seguinte).
static func _ecology_raid_retreat(unit: Unit, hex_grid: HexGrid, city_coord: Vector2i, anchor: Vector2i) -> void:
	var steps := int(MonsterAbilityData.param(MonsterAbilityData.QUICK_PLUNDER, "retreat_steps", 2))
	var reachable := hex_grid.compute_reachable(unit.coord, unit.unit_data.movement_points, unit.owner_player, unit.unit_data.flies)
	var here := HexMetrics.axial_distance(unit.coord, city_coord)
	var best = null
	var best_key: Array = []
	for coord in reachable.keys():
		if HexMetrics.axial_distance(unit.coord, coord) > steps:
			continue
		var away := HexMetrics.axial_distance(coord, city_coord)
		if away <= here:
			continue
		var key := [away, -HexMetrics.axial_distance(coord, anchor), -coord.x, -coord.y]
		if best == null or _key_greater(key, best_key):
			best = coord
			best_key = key
	if best != null:
		var from := unit.coord
		hex_grid.move_unit(unit, best, reachable[best])
		MonsterEcologySystem.emit_unit_event("move", unit, {"reason": "raid_retreat", "from": [from.x, from.y], "to": [unit.coord.x, unit.coord.y]})
	if is_instance_valid(unit):
		unit.movement_left = 0.0

static func _ecology_pillage(unit: Unit, hex_grid: HexGrid, turn: int) -> bool:
	if not is_instance_valid(unit) or unit.hp <= 0.0:
		return false
	var city: City = hex_grid.city_owning_tile(unit.coord)
	var owner_index := GameManager.players.find(city.owner_player) if city != null else -1
	if not _maybe_pillage_tile(unit, hex_grid, turn):
		return false
	MonsterEcologySystem.emit_unit_event("pillage", unit, {"target": owner_index})
	return true

## Ronda: um tile alcançável do próprio território (patrol_radius da âncora), sorteado pelo RNG da ecologia
## sobre as chaves ORDENADAS (determinismo independente da ordem interna do dicionário).
static func _ecology_roam(unit: Unit, hex_grid: HexGrid, anchor: Vector2i, patrol: int) -> void:
	var reachable := hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	var options: Array[Vector2i] = []
	for coord in reachable.keys():
		if coord != unit.coord and HexMetrics.axial_distance(anchor, coord) <= patrol and not _next_to_city(hex_grid, coord):
			options.append(coord)
	if options.is_empty():
		return
	options = MonsterEcologyPlanner.sorted_coords(options)
	var dest: Vector2i = options[MonsterEcologySystem.rng.randi_range(0, options.size() - 1)]
	hex_grid.move_unit(unit, dest, reachable[dest])
	MonsterEcologySystem.emit_unit_event("move", unit, {"reason": "roam"})

## Etapa 4: a ronda ociosa nunca escolhe um tile colado numa cidade (lia como monstro parado "dentro" da cidade).
static func _next_to_city(hex_grid: HexGrid, coord: Vector2i) -> bool:
	for neighbor in hex_grid.get_neighbors(coord):
		if hex_grid.get_city_at(neighbor) != null:
			return true
	return false

static func _coord_before(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y

## Unidade de QUALQUER civilização mais próxima da âncora dentro do raio (desempate por coordenada).
static func _ecology_nearest_civ_unit(anchor: Vector2i, radius: int):
	var best = null
	var best_dist := radius + 1
	for player in GameManager.players:
		for other in player.units:
			if not is_instance_valid(other):
				continue
			var d := HexMetrics.axial_distance(anchor, other.coord)
			if d > radius:
				continue
			if d < best_dist or (d == best_dist and _coord_before(other.coord, best)):
				best_dist = d
				best = other.coord
	return best

## Cidade de QUALQUER civilização ativa mais próxima da âncora dentro do raio (desempate por coordenada).
static func _ecology_city_target(anchor: Vector2i, radius: int) -> City:
	var best: City = null
	var best_dist := radius + 1
	for player in GameManager.players:
		for city in player.cities:
			var d := HexMetrics.axial_distance(anchor, city.coord)
			if d > radius:
				continue
			if d < best_dist or (d == best_dist and _coord_before(city.coord, best.coord)):
				best_dist = d
				best = city
	return best

## Melhoria de recurso (de qualquer civilização) não saqueada, livre ou já ocupada pelo próprio monstro, dentro
## do raio da âncora — a mais próxima do MONSTRO (desempate por coordenada).
static func _ecology_improvement_target(unit: Unit, anchor: Vector2i, radius: int, hex_grid: HexGrid, turn: int):
	var best = null
	var best_dist := 999999
	for player in GameManager.players:
		for city in player.cities:
			for coord in city.resource_improvements:
				if HexMetrics.axial_distance(anchor, coord) > radius or hex_grid.is_tile_pillaged(coord, turn):
					continue
				var occupant := hex_grid.get_unit_at(coord)
				if occupant != null and occupant != unit:
					continue
				var d := HexMetrics.axial_distance(unit.coord, coord)
				if d < best_dist or (d == best_dist and _coord_before(coord, best)):
					best_dist = d
					best = coord
	return best
