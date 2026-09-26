class_name V2UnitUpgrade
extends RefCounted

## Upgrade físico de unidades V2 (Fase 4): a MESMA unidade ganha a forma seguinte da
## linha (Escudeiro -> Guardião; futuramente -> Sentinela e as equivalentes das outras
## Doutrinas). Genérico e dirigido por metadata: o alvo vem de `upgrade_to` do nó da
## unidade (V2ResearchNode), o custo da fórmula abaixo, o prédio exigido de
## BuildingDatabase.building_that_trains(alvo). Nada aqui conhece "Escudeiro" ou "Guardião".
##
## É instantâneo (não entra na fila da cidade), consome a ação da unidade e o Ouro na
## hora. NÃO é uma tropa nova: o objeto Unit é o mesmo, então dono, posição, kills/
## veterania, serial_id, recargas e estado persistente continuam (ver Unit.apply_form).
## O HP é preservado em PERCENTUAL — nunca cura de graça.

## BALANCE PLACEHOLDER: Ouro por ponto de diferença de custo de produção
## (upgrade = GOLD_PER_PRODUCTION_POINT x (custo novo - custo antigo)).
const GOLD_PER_PRODUCTION_POINT := 2.0

## unlock_id da forma seguinte de `unit`, ou "" se não há evolução com gameplay
## conectado. NÃO exige pesquisa (ver unavailable_reason) — só diz pra onde a unidade vai.
static func get_upgrade_target(unit: Unit) -> String:
	if unit == null or unit.unit_data == null:
		return ""
	var node := V2UnitLine.node_for(unit.unit_data.visual_kind)
	if node == null or node.upgrade_to == "":
		return ""
	var target := V2UnitLine.node_for(node.upgrade_to)
	if target == null or not target.gameplay_connected:
		return ""
	return target.unlock_id

## Custo em Ouro pela fórmula genérica (nunca negativo). 0 se não há alvo.
static func upgrade_cost(unit: Unit) -> float:
	var target_id := get_upgrade_target(unit)
	if target_id == "":
		return 0.0
	var difference := UnitDatabase.create_unit(target_id).production_cost - unit.unit_data.production_cost
	return maxf(0.0, GOLD_PER_PRODUCTION_POINT * difference)

## A cidade PRÓPRIA em cujo território `unit` está, ou null. Usa o helper real de
## território (HexGrid.city_owning_tile) — nenhuma definição nova de "dentro da cidade".
static func city_of(unit: Unit, hex_grid: HexGrid) -> City:
	if unit == null or hex_grid == null or unit.owner_player == null:
		return null
	var city := hex_grid.city_owning_tile(unit.coord)
	if city == null or city.owner_player != unit.owner_player:
		return null
	return city

## O motivo (uma frase) de `unit` não poder evoluir agora, ou "" se pode. Ordem: o que o
## jogador precisa DESENVOLVER (pesquisa, cidade, prédio) antes do que é do turno (ação,
## técnica ativa, Ouro).
static func unavailable_upgrade_reason(player, unit: Unit, hex_grid: HexGrid) -> String:
	var target_id := get_upgrade_target(unit)
	if target_id == "":
		return "Esta unidade não tem evolução disponível."
	if player == null or unit.owner_player != player:
		return "A unidade não é sua."
	var target_node := V2UnitLine.node_for(target_id)
	if not V2UnlockSystem.is_unlocked(player, target_id):
		return "Requer pesquisa: %s." % target_node.display_name
	var city := city_of(unit, hex_grid)
	if city == null:
		return "Precisa estar em uma cidade própria."
	var required: BuildingData = BuildingDatabase.building_that_trains(target_id)
	if required != null and not city.buildings.has(required.id):
		return "Requer %s na cidade." % required.display_name
	if unit.movement_left <= 0.0 or unit.embarked:
		return "A unidade já agiu neste turno."
	var active := V2TechniqueRuntime.active_technique_name(unit)
	if active != "":
		return "Não pode evoluir com %s ativa." % active
	var supply_reason := V2LogisticsRuntime.upgrade_unavailable_reason(player, unit, target_id)
	if supply_reason != "":
		return supply_reason
	var cost := upgrade_cost(unit)
	if player.gold < cost:
		return "Ouro insuficiente (custa %d)." % int(ceil(cost))
	return ""

static func can_upgrade(player, unit: Unit, hex_grid: HexGrid) -> bool:
	return unavailable_upgrade_reason(player, unit, hex_grid) == ""

## Evolui `unit`: desconta o Ouro, troca a forma no próprio objeto (HP em %) e consome a
## ação (movimento restante zerado). false, sem alterar nada, se não puder.
static func perform_upgrade(player, unit: Unit, hex_grid: HexGrid) -> bool:
	if not can_upgrade(player, unit, hex_grid):
		return false
	var target_id := get_upgrade_target(unit)
	var old_name := unit.unit_data.unit_name
	player.gold -= upgrade_cost(unit)
	unit.apply_form(UnitDatabase.create_unit(target_id))
	unit.movement_left = 0.0
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	if player == GameManager.human_player:
		EventBus.notify.emit("%s evoluiu para %s." % [old_name, unit.unit_data.unit_name], "confirm")
	return true
