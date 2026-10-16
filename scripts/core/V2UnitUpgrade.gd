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
## A troca de forma preserva o HP em PERCENTUAL (Unit.apply_form); por cima disso a evolução CURA uma parte fixa da
## Vida máxima nova (UPGRADE_HEAL_FRACTION, abaixo).

## BALANCE PLACEHOLDER: Ouro por ponto de diferença de custo de produção
## (upgrade = GOLD_PER_PRODUCTION_POINT x (custo novo - custo antigo)).
const GOLD_PER_PRODUCTION_POINT := 2.0

## CURA DA EVOLUÇÃO (2026-10-12, pedido do usuário: "quando evoluo um personagem, ele continua com a mesma vida;
## seria justo, por gastar ouro nisso, o personagem recuperar um pouco da vida... veja qual a melhor forma de
## balancear isso, fixo ou %"). Evoluir recupera esta fração da Vida MÁXIMA DA FORMA NOVA, somada ao percentual que a
## troca de forma já preserva e limitada ao máximo (sem cura além do teto).
##
## Por que fração do MÁXIMO, e não um número fixo nem % da vida que falta:
##  - % da vida que FALTA cura muito quem está quase morto e quase nada quem está quase cheio — vira botão de
##    emergência e não recompensa quem evolui uma tropa em bom estado;
##  - número FIXO (ex.: +8) não acompanha os tiers: é 44% da vida de um Escudeiro (18) e bem menos de uma Lendária;
##  - fração do máximo dá a MESMA quantidade esteja a tropa com 10% ou 70% de vida (o comportamento de "valor fixo"
##    que se quer) e cresce junto com a tropa. É o modelo que o jogo já usa em toda cura: guarnição 25% por turno,
##    Fortificar 10% por turno, promoção de veterania 20% (GameManager.GARRISON_HEAL_FRACTION / FORTIFY_HEAL_FRACTION,
##    Unit.PROMOTION_HEAL_FRACTION) — e o da promoção do Civilization VI (50 de 100).
## Por que 30%: evoluir custa Ouro (24–40 nas linhas atuais) e a ação inteira da unidade, só é possível em território
## de cidade própria com o prédio da linha e acontece no máximo duas vezes na vida de uma tropa. Precisa valer mais
## que um turno parado na guarnição (25%, de graça) — senão evoluir ferido seria um turno pior que descansar — e mais
## que a promoção gratuita (20%), sem virar cura completa.
## Exemplo (Escudeiro 18 -> Guardião 24): 9/18 vira 12/24 pela forma e 19,2/24 com a cura; 4,5/18 vira 13,2/24.
const UPGRADE_HEAL_FRACTION := 0.3

## Vida que `unit` recuperaria ao evoluir AGORA (além do percentual preservado): a fração acima do máximo da forma
## nova, com a mesma penalidade de cura do tile que toda cura respeita (infecção micótica), sem passar do teto.
## 0 se não há evolução ou a tropa já está cheia.
static func upgrade_heal_amount(unit: Unit) -> float:
	var target_id := get_upgrade_target(unit)
	if target_id == "" or unit.unit_data.max_hp <= 0.0:
		return 0.0
	var new_max: float = UnitDatabase.create_unit(target_id).max_hp
	var kept := clampf(unit.hp / unit.unit_data.max_hp, 0.0, 1.0) * new_max
	return minf(new_max * UPGRADE_HEAL_FRACTION * MonsterHazardSystem.heal_multiplier(unit), new_max - kept)

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

## Evolui `unit`: desconta o Ouro, troca a forma no próprio objeto (HP em %), cura a fração da evolução
## (UPGRADE_HEAL_FRACTION) e consome a ação (movimento restante zerado). false, sem alterar nada, se não puder.
static func perform_upgrade(player, unit: Unit, hex_grid: HexGrid) -> bool:
	if not can_upgrade(player, unit, hex_grid):
		return false
	var target_id := get_upgrade_target(unit)
	var old_name := unit.unit_data.unit_name
	var healed := upgrade_heal_amount(unit) # calculado na forma antiga: o percentual preservado sai dela
	player.gold -= upgrade_cost(unit)
	unit.apply_form(UnitDatabase.create_unit(target_id))
	if healed > 0.0:
		unit.hp = minf(unit.unit_data.max_hp, unit.hp + healed)
	unit.movement_left = 0.0
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	if player == GameManager.human_player:
		var recovered := " Recuperou %d de Vida." % roundi(healed) if healed >= 0.5 else ""
		EventBus.notify.emit("%s evoluiu para %s.%s" % [old_name, unit.unit_data.unit_name, recovered], "confirm")
	return true
