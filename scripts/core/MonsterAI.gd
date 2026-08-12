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
## Tres comportamentos (MonsterDatabase.BEHAVIOR_*, default por tipo em
## KIND_DATA, sobrescrito por instancia em Unit.monster_behavior_state):
## - Guardiao: nunca sai do territorio do proprio covil (HexGrid.
##   home_lair_for + GUARD_RADIUS), so briga com quem entra la.
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
## Determinismo: nenhuma chamada a randi()/randf() global aqui — toda
## escolha de alvo e por distancia sobre arrays de ordem estavel
## (GameManager.players/player.units), igual RivalAI ja faz sem RNG
## nenhum. Se algum dia precisar de desempate aleatorio, TEM que vir de
## hex_grid.monster_turn_rng (nunca randf() global), pra nao quebrar a
## garantia de determinismo ja testada do sistema de covil.

const GUARD_RADIUS := 2 # Guardiao nunca se afasta disso do proprio covil (HexGrid.home_lair_for)
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

## Duracao (em turnos) que um tile saqueado fica sem rendimento (ver
## HexGrid.pillage_tile/City.collect_yields) e quanto ouro o dono da
## cidade perde no momento do saque — pedido do usuario: "melhoria
## desativada por X turnos" + "cidade perde uma pequena quantia de ouro".
const PILLAGE_DURATION_TURNS := 6
const PILLAGE_GOLD_LOSS := 15.0

static func take_turn(hex_grid: HexGrid, turn: int = 0) -> void:
	_promote_idle_groups_to_invaders(hex_grid)
	for unit in hex_grid.neutral_units():
		if not is_instance_valid(unit):
			continue
		var behavior = _effective_behavior(unit)
		match behavior:
			MonsterDatabase.BEHAVIOR_INVADER:
				_take_invader_turn(unit, hex_grid, turn)
			MonsterDatabase.BEHAVIOR_HUNTER:
				_take_hunter_turn(unit, hex_grid)
			_:
				_take_guardian_turn(unit, hex_grid)

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

## Guardiao: so briga com quem entra no proprio territorio (raio
## GUARD_RADIUS a partir do CENTRO do covil, nao da posicao atual do
## monstro) e nunca se afasta dali perseguindo. Ataque incondicional (sem
## checar favorabilidade, ao contrario de Cacador) — e ameaca ESTATICA por
## design, nao pesa risco antes de defender o proprio territorio.
static func _take_guardian_turn(unit: Unit, hex_grid: HexGrid) -> void:
	var home = hex_grid.home_lair_for(unit.coord)
	var anchor = home if home != HexGrid.NO_LAIR else unit.coord
	var target_coord = _nearest_hostile_within(anchor, GUARD_RADIUS)
	if target_coord == null:
		return
	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		var defender = hex_grid.get_unit_at(target_coord)
		if defender != null:
			CombatResolver.resolve(unit, defender, hex_grid)
		return
	_move_toward_within_radius(unit, hex_grid, target_coord, anchor, GUARD_RADIUS)

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
	var city = hex_grid.city_working_tile(unit.coord)
	if city == null:
		return
	hex_grid.pillage_tile(unit.coord, turn, PILLAGE_DURATION_TURNS)
	city.owner_player.gold = max(0.0, city.owner_player.gold - PILLAGE_GOLD_LOSS)
	if city.owner_player == GameManager.human_player:
		EventBus.notify.emit("Invasores saquearam um tile trabalhado por %s!" % city.city_name, "combat")

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
## de `unit`, dentro de HUNTER_PATROL_RADIUS.
static func _find_hunter_prey(unit: Unit, hex_grid: HexGrid):
	var best = null
	var best_dist = HUNTER_PATROL_RADIUS + 1
	for player in GameManager.players:
		for other in player.units:
			if not is_instance_valid(other):
				continue
			var d = HexMetrics.axial_distance(unit.coord, other.coord)
			if d > HUNTER_PATROL_RADIUS or d >= best_dist:
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
