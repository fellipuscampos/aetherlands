class_name V2ConstructorRuntime
extends RefCounted

## Aetherlands V2, Fase 15 — o Construtor: unidade CIVIL (§51 do pedido — nunca entra em
## composição militar, slot Lendário, Doutrina ou Suprimentos) que transforma território anexado
## em economia real, melhorando os cinco recursos do mapa (V2ResourceImprovementData). Reconhecido
## por id V2 direto (não há metadata de pesquisa equivalente a um `legendary_candidate` pra
## civis — só o próprio kind "v2_unit_builder"); nada aqui conhece os OUTROS 24 ids militares.

const BUILDER_KIND := "v2_unit_builder"

static func is_builder_kind(kind: String) -> bool:
	return kind == BUILDER_KIND

static func is_builder_unit(unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.unit_data != null and unit.unit_data.visual_kind == BUILDER_KIND

## Cargas de um Construtor RECÉM-NASCIDO (§54-56 do pedido): tier de Indústria do dono NO
## INSTANTE do nascimento (1/2/3 -> 1/2/3 cargas). Pesquisa POSTERIOR nunca recarrega um
## Construtor já existente — a chamada acontece só UMA vez, no spawn (ver GameManager).
static func charges_for_new_builder(player: PlayerData) -> int:
	return V2EconomyRuntime.infrastructure_tier(player, "industry") + V2RaceBonusRuntime.builder_charge_bonus(player)

## "" se `unit` pode melhorar o recurso do próprio tile agora (§58 do pedido); senão o motivo,
## numa frase clara (§81 — nunca "Não pode."). Checa, em ordem: é o Construtor, tem carga, o
## jogador já agiu, o tile tem recurso reconhecido, o tile não tem prédio (§82), o tile pertence a
## uma cidade PRÓPRIA (§62/§83 — território anexado, mas ainda sem melhoria) e o recurso ainda não
## foi melhorado (§61).
static func unavailable_reason(unit: Unit, hex_grid: HexGrid) -> String:
	if not is_builder_unit(unit):
		return "Só o Construtor pode melhorar recursos."
	if unit.work_charges_remaining <= 0:
		return "Sem cargas restantes."
	if unit.movement_left <= 0.0 or unit.embarked:
		return "A unidade já agiu neste turno."
	var tile: HexTileData = hex_grid.get_tile(unit.coord)
	if tile == null or not V2ResourceImprovementData.has_resource(tile.resource):
		return "Não há recurso neste tile."
	if hex_grid.get_building_at(unit.coord) != null:
		return "Este tile já tem uma construção."
	var city := hex_grid.city_owning_tile(unit.coord)
	if city == null or city.owner_player != unit.owner_player:
		return "O recurso precisa estar no território de uma cidade própria."
	if city.resource_improvements.has(unit.coord):
		return "Este recurso já está sendo explorado."
	return ""

static func can_improve(unit: Unit, hex_grid: HexGrid) -> bool:
	return unavailable_reason(unit, hex_grid) == ""

## Melhora o recurso do tile ONDE `unit` está (§58/§59 do pedido): instantâneo (fora da fila de
## produção da cidade), sem Ouro/Mana/Suprimentos, consome a carga e a ação (movimento zerado).
## Se a carga chegar a 0, a unidade é CONSUMIDA (removida do mapa, sem kill/XP/morte — §57): quem
## chama isto precisa checar `is_instance_valid(unit)` depois, ela pode já não existir mais.
## Devolve false, sem alterar nada, se não puder (ver unavailable_reason).
static func improve_resource(unit: Unit, hex_grid: HexGrid) -> bool:
	if not can_improve(unit, hex_grid):
		return false
	var tile: HexTileData = hex_grid.get_tile(unit.coord)
	var city := hex_grid.city_owning_tile(unit.coord)
	var improvement_id := V2ResourceImprovementData.improvement_id_for_resource(tile.resource)
	V2TerrainRuntime.clear_for_construction(hex_grid, unit.coord) # Fase 20: a melhoria (estrutura permanente) limpa a modificação de terreno
	city.resource_improvements[unit.coord] = improvement_id
	hex_grid.refresh_resource_improvement_marker(unit.coord)
	V2PortalSystem.close_pair_at(unit.coord, hex_grid) # Fase 21: só a melhoria efetivamente criada fecha o par
	var owner := unit.owner_player
	var is_human := owner == GameManager.human_player
	var display_name := V2ResourceImprovementData.display_name_for_resource(tile.resource)
	unit.work_charges_remaining -= 1
	unit.movement_left = 0.0
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	var consumed := unit.work_charges_remaining <= 0
	if consumed:
		hex_grid.remove_unit(unit)
	if is_human:
		EventBus.notify.emit("%s construiu: %s." % [city.city_name, display_name], "confirm")
		if consumed:
			EventBus.notify.emit("O Construtor foi consumido pelo trabalho.", "")
	return true
