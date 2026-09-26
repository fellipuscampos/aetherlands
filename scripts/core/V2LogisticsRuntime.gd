class_name V2LogisticsRuntime
extends RefCounted

## Aetherlands V2, Fase 15 — o lado do CONSUMO de Suprimentos (a Fase 14 só construiu a
## CAPACIDADE). Suprimentos continuam capacidade pura, nunca estoque (§3/§19 herdados da Fase 14):
## não existe `player.supplies`. Tudo aqui é DERIVADO a cada chamada — unidades vivas com
## `UnitData.supply_cost > 0` e a produção EM ANDAMENTO de cada cidade (a própria
## `City.production_item`, sem um segundo estado "reservado", mesmo princípio de
## V2LegendarySystem.slots_used na Fase 6). RefCounted estático, sem `_process`.

## BALANCE PLACEHOLDER (§17 do pedido).
const TENSION_MULTIPLIER := 0.85

## Suprimentos de todas as unidades VIVAS do jogador com supply_cost > 0 (§7-A do pedido).
static func _living_supply_used(player: PlayerData) -> int:
	if player == null:
		return 0
	var total := 0
	for unit in player.units:
		if is_instance_valid(unit) and unit.hp > 0.0 and unit.unit_data != null:
			total += unit.unit_data.supply_cost
	return total

## `kind` é um id de produção de UNIDADE com Suprimentos > 0? 0 pra prédio, City Project ou
## qualquer unidade sem custo (V1, Colonizador, Construtor) — nunca por nome/id, só pelo dado.
static func _supply_cost_for_kind(kind: String) -> int:
	if kind == "" or BuildingDatabase.get_building(kind) != null or V2CityLevelData.is_city_project(kind) or V2FortificationData.is_fortification_project(kind):
		return 0
	return UnitDatabase.create_unit(kind).supply_cost

## Suprimentos reservados pela produção EM ANDAMENTO de cada cidade do jogador (§7-B/§8 do pedido)
## — a própria fila de produção JÁ é a reserva, sem um segundo campo. `excluding_city` tira a
## PRÓPRIA cidade da conta (§9/§11: quem está decidindo se pode iniciar não compete consigo mesma).
static func _production_supply_reserved(player: PlayerData, excluding_city: City = null) -> int:
	if player == null:
		return 0
	var total := 0
	for city in player.cities:
		if city == excluding_city or not is_instance_valid(city):
			continue
		total += _supply_cost_for_kind(city.production_item)
	return total

## Suprimentos usados AGORA: unidades vivas + produção em andamento (§7). Cancelar/trocar produção,
## a unidade morrer ou a cidade ser perdida libera a reserva na consulta SEGUINTE, sem nenhum hook
## de "refund" (§9/§10 do pedido) — é tudo recalculado do zero a cada chamada.
static func player_supply_used(player: PlayerData, excluding_city: City = null) -> int:
	return _living_supply_used(player) + _production_supply_reserved(player, excluding_city)

## Tensão Logística: usar mais Suprimentos do que a capacidade permite (§16 do pedido) — derivada,
## nunca salva. Excesso de reserva/unidades NUNCA destrói nada (§12); só ativa a penalidade abaixo.
static func is_logistically_strained(player: PlayerData) -> bool:
	if player == null:
		return false
	return player_supply_used(player) > int(V2EconomyRuntime.player_supply_capacity(player))

## Multiplicador de Ataque OU Defesa por Tensão Logística (§17-20 do pedido) — a MESMA função serve
## os dois lados de CombatResolver.predict (o efeito é idêntico: 0,85 se a unidade tem
## supply_cost > 0 e o DONO dela está em Tensão). Civis, unidades V1, Construtor e Colonizador
## (supply_cost == 0 por dado) nunca são afetados (§19); cidades não passam por aqui (§19); nunca
## um `if unit.visual_kind == "..."` — dirigido pelo dado e pelo estado derivado do dono.
static func combat_multiplier(unit: Unit) -> float:
	if unit == null or unit.unit_data == null or unit.unit_data.supply_cost <= 0 or unit.owner_player == null:
		return 1.0
	return TENSION_MULTIPLIER if is_logistically_strained(unit.owner_player) else 1.0

const DEFICIT_TRAINING_REASON := "Déficit de Ouro: estabilize a economia antes de treinar novas tropas."
const SUPPLY_REASON_PREFIX := "Suprimentos insuficientes"

## "" se `city` pode INICIAR o treino de `kind` agora quanto a Déficit/Suprimentos (§11/§41 do
## pedido); senão o motivo. Só tem algo a dizer pra um kind de unidade com supply_cost > 0 — as
## demais produções (prédio, City Project, unidade sem custo) sempre devolvem "".
static func training_unavailable_reason(player: PlayerData, city: City, kind: String) -> String:
	var cost := _supply_cost_for_kind(kind)
	if cost <= 0:
		return ""
	# §41: Déficit bloqueia INICIAR uma unidade com custo — produção já em andamento continua
	# (city.production_item só muda quando o jogador troca, nunca por causa do Déficit sozinho).
	if V2EconomyRuntime.is_gold_deficit(player):
		return DEFICIT_TRAINING_REASON
	var used_excluding := player_supply_used(player, city)
	var capacity := int(V2EconomyRuntime.player_supply_capacity(player))
	if used_excluding + cost > capacity:
		return "%s: requer %d, disponíveis %d." % [SUPPLY_REASON_PREFIX, cost, maxi(capacity - used_excluding, 0)]
	return ""

static func can_afford_training(player: PlayerData, city: City, kind: String) -> bool:
	return training_unavailable_reason(player, city, kind) == ""

## Só o mesmo motivo acima, mas ISOLADO pra quando ele é o ÚNICO impedimento (pesquisa/prédio/raça/
## slot Lendário já OK) — mesmo espírito de V2LegendarySystem.slot_only_reason: a HUD usa isto pra
## manter o botão VISÍVEL e desabilitado com o motivo, em vez de escondê-lo sem explicar (§15 do
## pedido: nunca esconder "Suprimentos insuficientes"/Déficit atrás de um motivo genérico).
static func training_soft_reason(player: PlayerData, city: City, kind: String) -> String:
	if player == null or city == null:
		return ""
	if not V2ResearchDatabase.is_v2_id(kind):
		return ""
	if not V2UnlockSystem.is_unit_unlocked(player, kind):
		return ""
	if V2UnitLine.is_line_unit(kind) and not V2UnitLine.is_current_trainable_form(player, kind):
		return ""
	if V2LegendarySystem.is_legendary_kind(kind) and not V2LegendarySystem.legendary_slot_available(player, city):
		return "" # V2LegendarySystem.slot_only_reason já cobre este caso, não duplica aqui
	var required: BuildingData = BuildingDatabase.building_that_trains(kind)
	if required != null and not city.buildings.has(required.id):
		return ""
	return training_unavailable_reason(player, city, kind)

## Delta de Suprimentos exigido por um upgrade (§13 do pedido): só a DIFERENÇA entre a forma nova e
## a atual precisa estar livre — a unidade atual já está contada em `player_supply_used` (ela
## continua viva durante o upgrade, ver V2UnitUpgrade.gd), então cobrar o custo total de novo
## dobraria a conta.
static func upgrade_supply_delta(current_kind: String, target_kind: String) -> int:
	return maxi(_supply_cost_for_kind(target_kind) - _supply_cost_for_kind(current_kind), 0)

## "" se o upgrade de `unit` para `target_kind` cabe nos Suprimentos livres agora; senão o motivo.
static func upgrade_unavailable_reason(player: PlayerData, unit: Unit, target_kind: String) -> String:
	var delta := upgrade_supply_delta(unit.unit_data.visual_kind, target_kind)
	if delta <= 0:
		return ""
	var used := player_supply_used(player)
	var capacity := int(V2EconomyRuntime.player_supply_capacity(player))
	if used + delta > capacity:
		return "%s: requer %d, disponíveis %d." % [SUPPLY_REASON_PREFIX, delta, maxi(capacity - used, 0)]
	return ""

static func can_afford_upgrade(player: PlayerData, unit: Unit, target_kind: String) -> bool:
	return upgrade_unavailable_reason(player, unit, target_kind) == ""
