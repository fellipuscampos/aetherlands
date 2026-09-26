class_name V2EconomyRuntime
extends RefCounted

## Aetherlands V2, Fase 14 — pipeline ÚNICA e GENÉRICA da Economia V2 (§5 do pedido). Nenhuma
## classe irmã por recurso (GoldSystem/SupplySystem/WorkshopSystem/AcademySystem/ManaSystem não
## existem): toda consulta passa por aqui, orientada pelo dado central (V2InfrastructureEconomyData)
## — nunca `if building_id == "v2_building_market"` (§128 do pedido; a exceção natural é
## BuildingDatabase, que registra conteúdo).
##
## Nada aqui é ESTADO — tudo é DERIVADO a cada chamada, a partir de cidades/prédios/pesquisa já
## existentes (§6 do pedido: não salvar renda derivada). RefCounted estático, mesmo padrão de
## V2UnlockSystem/V2CityLevelData: sem `_process`, sem polling, sem cache próprio (o único cache é
## o de V2ResearchDatabase, que já existia).

## Tier de pesquisa (1..3) que `player` possui para a linha `branch` — SEMPRE pelo menos 1, mesmo
## sem NENHUMA pesquisa da linha: um prédio físico (construído ou CAPTURADO) sempre rende o nível
## básico (§55/§56 do pedido — "eficiência do NOVO dono", nunca 0, nunca infere pelo antigo dono).
## O gate de pesquisa real (pode CONSTRUIR novo?) fica em City._tech_unlocked_for_building, que já
## barra a construção via V2UnlockSystem.is_unlocked(player, unlock_ids[0]) — esta função só decide
## o YIELD de cópias que já existem.
static func infrastructure_tier(player: PlayerData, branch: String) -> int:
	var ids: Array = V2InfrastructureEconomyData.unlock_ids_for_branch(branch)
	if player == null or ids.size() < 3:
		return 1
	if _is_completed(player, ids[2]):
		return 3
	if _is_completed(player, ids[1]):
		return 2
	return 1

static func _is_completed(player: PlayerData, unlock_id: String) -> bool:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	return node != null and player.v2_research.is_completed(node.id)

## Rendimento de UMA cópia de `building_id` pro tier ATUAL do dono (nunca de quem construiu — ver
## infrastructure_tier acima). 0.0 se `building_id` não é um dos cinco prédios econômicos.
static func building_output(player: PlayerData, building_id: String) -> float:
	var branch := V2InfrastructureEconomyData.branch_for_building(building_id)
	if branch == "":
		return 0.0
	return V2InfrastructureEconomyData.yield_per_copy(building_id, infrastructure_tier(player, branch))

## Soma o rendimento de todas as melhorias de recurso (V2ResourceImprovementData) desta cidade que
## afetam `branch` — mesma pipeline que os prédios (§73/§122 do pedido: nunca varre o mapa, só
## City.resource_improvements, que a própria cidade já conhece). Melhorias NUNCA têm upkeep, então
## NUNCA são descontadas por Déficit (§39/§85/§87) — diferente do prédio, cujo desconto entra em
## `_city_branch_income` abaixo. Fase 25: uma melhoria SAQUEADA por Invasores (HexGrid.pillage_tile,
## MonsterAI._maybe_pillage_tile) não rende enquanto o saque durar — o antigo efeito do saque sobre os
## tiles trabalhados V1, trazido para a única fonte de rendimento por tile da V2.
static func _city_improvement_income(city: City, branch: String) -> float:
	if city == null or city.resource_improvements.is_empty():
		return 0.0
	var total := 0.0
	var tier := infrastructure_tier(city.owner_player, branch)
	var grid: HexGrid = GameManager.hex_grid
	for coord in city.resource_improvements:
		if grid != null and grid.is_tile_pillaged(coord, TurnManager.turn_number):
			continue
		var improvement_id: String = city.resource_improvements[coord]
		var resource_id := V2ResourceImprovementData.resource_for_improvement(improvement_id)
		if resource_id == "":
			continue
		for effect in V2ResourceImprovementData.effects_for_resource(resource_id):
			if effect.branch == branch:
				total += V2ResourceImprovementData.yield_for_effect(effect, tier)
	return total

## Soma base-por-cidade + (cópias × rendimento por cópia) do prédio da linha `branch`, MAIS as
## melhorias de recurso que afetam a mesma linha, PARA UMA cidade — helper interno compartilhado
## por todas as consultas city_*_income/city_supply_capacity abaixo (as cinco linhas seguem
## exatamente a mesma forma, só o `branch`/`base` mudam). Fase 15: se a civilização está em Déficit
## de Ouro, a contribuição do PRÉDIO (nunca a base, nunca a melhoria) cai pra metade — mas só se
## esse prédio tem `gold_upkeep > 0` (§37/§38/§39 do pedido; dirigido pelo dado, nunca um `if
## branch == "logistics"` — é por isso que Mercado, sem upkeep, nunca é descontado).
## `deficit` vem PRONTO de quem chama: is_gold_deficit soma todas as cidades do dono, então
## recalculá-lo aqui, cidade a cidade, deixava as agregações por jogador O(cidades²) (medido no
## benchmark da Fase 15 — ver docs/PERFORMANCE_GUIDE.md). Calculado uma vez por consulta, sem cache.
static func _city_branch_income(city: City, branch: String, base: float, deficit: bool) -> float:
	if city == null:
		return 0.0
	var total := base
	var building_id := V2InfrastructureEconomyData.building_id_for_branch(branch)
	if building_id != "":
		var copies: int = city.building_count(building_id)
		if copies > 0:
			var building_total: float = float(copies) * building_output(city.owner_player, building_id)
			if deficit and _building_has_upkeep(building_id):
				building_total *= DEFICIT_OUTPUT_MULTIPLIER
			total += building_total
	total += _city_improvement_income(city, branch)
	return total

## Mesma conta de _city_branch_income pra UMA cidade, com o Déficit do próprio dono.
static func _single_city_branch_income(city: City, branch: String, base: float) -> float:
	if city == null:
		return 0.0
	return _city_branch_income(city, branch, base, is_gold_deficit(city.owner_player))

## Agregação por jogador: o Déficit é decidido UMA vez e vale pra todas as cidades dele.
static func _player_branch_income(player: PlayerData, branch: String, base: float) -> float:
	if player == null:
		return 0.0
	var deficit := is_gold_deficit(player)
	var total := 0.0
	for city in player.cities:
		total += _city_branch_income(city, branch, base, deficit)
	return total

## BALANCE PLACEHOLDER (§37 do pedido): fração da eficiência de um prédio com upkeep enquanto o
## dono está em Déficit de Ouro.
const DEFICIT_OUTPUT_MULTIPLIER := 0.5

static func _building_has_upkeep(building_id: String) -> bool:
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	return building != null and building.gold_upkeep > 0.0

static func _building_output_is_deficit_discounted(building_id: String, player: PlayerData) -> bool:
	return is_gold_deficit(player) and _building_has_upkeep(building_id)

## Ouro/turno que ESTA cidade contribui (base + Mercados) — GLOBAL na agregação (ver
## player_gold_income), mas a consulta em si é sempre por cidade (§72/§73 do pedido: breakdown por
## cidade na UI).
static func city_gold_income(city: City) -> float:
	var base := _single_city_branch_income(city, "economy", V2InfrastructureEconomyData.BASE_GOLD_PER_CITY)
	return base * V2RaceBonusRuntime.gold_income_multiplier(city.owner_player if city != null else null)

## Capacidade de Suprimentos que ESTA cidade contribui (base + Fazendas) — CAPACIDADE, nunca
## estoque (§19 do pedido): não existe "gasto" desta função, só leitura pura, recalculada a cada
## consulta.
static func city_supply_capacity(city: City) -> float:
	var base := _single_city_branch_income(city, "logistics", V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY)
	return base * V2RaceBonusRuntime.supply_capacity_multiplier(city.owner_player if city != null else null)

## Produção/turno LOCAL desta cidade (base + Oficinas) — NUNCA agregada no PlayerData (§86 do
## pedido: Produção é local, não existe production_pool_global). Consumida por City.process_turn().
static func city_production_income(city: City) -> float:
	var base := _single_city_branch_income(city, "industry", V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY)
	return base * V2RaceBonusRuntime.city_production_multiplier(city.owner_player if city != null else null)

## Conhecimento/turno que ESTA cidade contribui (base + Academias) — GLOBAL na agregação.
static func city_knowledge_income(city: City) -> float:
	var base := _single_city_branch_income(city, "academy", V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY)
	return base * V2RaceBonusRuntime.knowledge_income_multiplier(city.owner_player if city != null else null)

## Mana/turno que ESTA cidade contribui (base + Santuários Arcanos) — GLOBAL na agregação.
static func city_mana_income(city: City) -> float:
	var base := _single_city_branch_income(city, "arcane", V2InfrastructureEconomyData.BASE_MANA_PER_CITY)
	return base * V2RaceBonusRuntime.mana_income_multiplier(city.owner_player if city != null else null)

## Versão SEM desconto de Déficit da renda de Ouro de uma cidade — usada SÓ por `is_gold_deficit`
## abaixo, pra decidir se o Déficit está ativo sem reler o próprio resultado que ele mesmo afeta
## (§49 do pedido: nunca recursivo). Nunca chamada por UI/testes normais — `city_gold_income` (que
## JÁ inclui o desconto quando aplicável) é a fonte pública.
static func _nominal_city_gold_income(city: City) -> float:
	if city == null:
		return 0.0
	var total := V2InfrastructureEconomyData.BASE_GOLD_PER_CITY
	var building_id := V2InfrastructureEconomyData.building_id_for_branch("economy")
	var copies: int = city.building_count(building_id)
	if copies > 0:
		total += float(copies) * building_output(city.owner_player, building_id)
	total += _city_improvement_income(city, "economy") # melhorias nunca têm upkeep — igual nos dois cálculos
	return total

static func _nominal_player_gold_income(player: PlayerData) -> float:
	return _sum_cities(player, _nominal_city_gold_income) * V2RaceBonusRuntime.gold_income_multiplier(player)

## Ouro/turno que UM prédio custa de manutenção nesta cidade — soma `gold_upkeep × cópias` de cada
## prédio construído (qualquer um, V1 ou V2 — o campo é genérico em BuildingData; hoje só os cinco
## econômicos e os 12 militares V2 declaram um valor > 0).
static func city_gold_upkeep(city: City) -> float:
	if city == null:
		return 0.0
	var total := 0.0
	for id in city.buildings.keys():
		var building: BuildingData = BuildingDatabase.get_building(id)
		if building != null and building.gold_upkeep > 0.0:
			total += building.gold_upkeep * float(city.building_count(id))
	# Fase 16: a Fortificação paga o upkeep do nível ATUAL (substitui o anterior, nunca soma níveis).
	total += V2FortificationData.gold_upkeep(city.fortification_level)
	return total

## Fração de operação dos componentes ATIVOS mantidos a Ouro (Fase 16: o Ataque da Cidade) — 1.0
## normalmente, DEFICIT_OUTPUT_MULTIPLIER em Déficit. Genérico: nunca decide por id de nada.
static func operational_multiplier(player: PlayerData) -> float:
	return DEFICIT_OUTPUT_MULTIPLIER if is_gold_deficit(player) else 1.0

static func player_gold_upkeep(player: PlayerData) -> float:
	return _sum_cities(player, city_gold_upkeep)

## Renda BRUTA de Ouro (§31 do pedido) — já é a versão EFETIVA (com o desconto de Déficit aplicado
## se ativo, ver `_city_branch_income`): "bruto" aqui significa "antes do upkeep", não "sem
## desconto de crise". `player_gold_income` (Fase 14) e este são o mesmo número; o nome novo só
## bate com o vocabulário do pedido desta fase.
static func player_gold_gross_income(player: PlayerData) -> float:
	return player_gold_income(player)

static func player_gold_net_income(player: PlayerData) -> float:
	return player_gold_gross_income(player) - player_gold_upkeep(player)

## Déficit é DERIVADO, nunca salvo (§35/§131 do pedido): Ouro em caixa já chegou a zero (ou abaixo,
## o que não deveria acontecer — ver apply_turn_income) E a renda NOMINAL (sem o próprio desconto
## de Déficit, quebrando a recursão) líquida de upkeep continua negativa. Só ficar com renda líquida
## negativa e caixa positivo (§36) NÃO é Déficit — o tesouro está financiando a diferença.
static func is_gold_deficit(player: PlayerData) -> bool:
	if player == null or player.gold > 0.0:
		return false
	return (_nominal_player_gold_income(player) - player_gold_upkeep(player)) < 0.0

## Agregação por civilização (§118 do pedido: itera só as cidades do player + os building_count
## necessários — nunca todas as unidades/o mapa/os 128 nós de pesquisa).
static func player_gold_income(player: PlayerData) -> float:
	return _player_branch_income(player, "economy", V2InfrastructureEconomyData.BASE_GOLD_PER_CITY) * V2RaceBonusRuntime.gold_income_multiplier(player)

static func player_supply_capacity(player: PlayerData) -> float:
	return _player_branch_income(player, "logistics", V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY) * V2RaceBonusRuntime.supply_capacity_multiplier(player)

static func player_knowledge_income(player: PlayerData) -> float:
	return _player_branch_income(player, "academy", V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY) * V2RaceBonusRuntime.knowledge_income_multiplier(player)

static func player_mana_income(player: PlayerData) -> float:
	return _player_branch_income(player, "arcane", V2InfrastructureEconomyData.BASE_MANA_PER_CITY) * V2RaceBonusRuntime.mana_income_multiplier(player)

static func _sum_cities(player: PlayerData, city_income: Callable) -> float:
	if player == null:
		return 0.0
	var total := 0.0
	for city in player.cities:
		total += city_income.call(city)
	return total

## Credita Ouro/Mana/Conhecimento ao `player` UMA vez (§51/§103 do pedido — chamado uma vez por
## civilização por turno, ANTES do loop de produção local das cidades, com o snapshot de prédios
## do INÍCIO do turno: nenhuma cidade ainda processou este turno quando isto roda, ver
## GameManager._on_turn_changed). Suprimentos não entra aqui (é consulta pura, nunca creditado/
## acumulado — ver city_supply_capacity/player_supply_capacity). Produção não entra aqui (é local,
## cada City.process_turn() lê city_production_income diretamente).
static func apply_turn_income(player: PlayerData) -> void:
	if player == null:
		return
	# Fase 15 (§33/§34 do pedido): Ouro passa a ser bruto - upkeep, nunca abaixo de 0. `gross` já
	# reflete o desconto de Déficit nos prédios com upkeep, se estiver ativo (ver
	# _building_output_is_deficit_discounted) — o upkeep em si nunca é descontado por Déficit.
	var gross_gold := player_gold_gross_income(player)
	var upkeep := player_gold_upkeep(player)
	var mana := player_mana_income(player)
	var knowledge := player_knowledge_income(player)
	player.gold = maxf(0.0, player.gold + gross_gold - upkeep)
	player.mana += mana
	player.mana_income_per_turn = mana
	player.v2_research.add_knowledge(knowledge)

## Breakdown pra UI/testes (§73 do pedido: "Base da cidade: +2, Mercado ×2: +12, Total: +14") — a
## HUD só formata o texto, os números vêm daqui. `resource` é um dos 5 kinds de
## V2InfrastructureEconomyData.RESOURCE_LABELS ("gold"/"supply"/"production"/"knowledge"/"mana").
static func city_income_breakdown(city: City, resource: String) -> Dictionary:
	var branch := ""
	for candidate in V2InfrastructureEconomyData.branches():
		if V2InfrastructureEconomyData.entry_for_branch(candidate).resource == resource:
			branch = candidate
			break
	var result := {
		"base": 0.0, "building_name": "", "copies": 0, "per_copy": 0.0, "building_total": 0.0,
		"deficit_discounted": false, "improvement_total": 0.0, "pre_racial_total": 0.0,
		"racial_multiplier": 1.0, "racial_bonus": 0.0, "total": 0.0,
	}
	if branch == "" or city == null:
		return result
	var building_id := V2InfrastructureEconomyData.building_id_for_branch(branch)
	var building: BuildingData = BuildingDatabase.get_building(building_id)
	var base_value: float = {
		"gold": V2InfrastructureEconomyData.BASE_GOLD_PER_CITY,
		"supply": V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY,
		"production": V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY,
		"knowledge": V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY,
		"mana": V2InfrastructureEconomyData.BASE_MANA_PER_CITY,
	}.get(resource, 0.0)
	var copies: int = city.building_count(building_id)
	var per_copy := building_output(city.owner_player, building_id)
	var building_total: float = float(copies) * per_copy
	var discounted := _building_output_is_deficit_discounted(building_id, city.owner_player)
	if discounted:
		building_total *= DEFICIT_OUTPUT_MULTIPLIER
	result.base = base_value
	result.building_name = building.display_name if building else ""
	result.copies = copies
	result.per_copy = per_copy
	result.building_total = building_total
	result.deficit_discounted = discounted
	result.improvement_total = _city_improvement_income(city, branch)
	result.pre_racial_total = base_value + building_total + result.improvement_total
	result.racial_multiplier = _race_multiplier_for_resource(city.owner_player, resource)
	result.racial_bonus = result.pre_racial_total * (result.racial_multiplier - 1.0)
	result.total = result.pre_racial_total * result.racial_multiplier
	return result


static func _race_multiplier_for_resource(player: PlayerData, resource: String) -> float:
	match resource:
		"gold":
			return V2RaceBonusRuntime.gold_income_multiplier(player)
		"supply":
			return V2RaceBonusRuntime.supply_capacity_multiplier(player)
		"production":
			return V2RaceBonusRuntime.city_production_multiplier(player)
		"knowledge":
			return V2RaceBonusRuntime.knowledge_income_multiplier(player)
		"mana":
			return V2RaceBonusRuntime.mana_income_multiplier(player)
	return 1.0
