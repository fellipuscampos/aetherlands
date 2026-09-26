class_name V2UnitLine
extends RefCounted

## Linhas de unidade das Doutrinas Militares V2 (Fase 4): unidade-base (N3) ->
## evolução (N5) -> Elite (N7), ex.: Escudeiro -> Guardião -> Sentinela. Só CONSULTAS,
## derivadas da metadata que já existe (V2ResearchDatabase.unit_line, upgrade_from/
## upgrade_to) e da pesquisa da civilização — nenhuma lista de ids escrita à mão, então
## a Sentinela (N7) já é reconhecida como parte da linha do Guardião antes de existir.
##
## "Forma" = um unlock_id de unidade da linha. Só forma com gameplay conectado
## (`gameplay_connected`) conta como jogável: metadata de fase futura nunca é
## oferecida, mesmo que a pesquisa V2 dela tenha sido concluída (ex.: por debug).

const LINE_ROLES := ["base_unit", "evolution_1", "elite_form"]

## Os unlock_ids da linha `branch`, em ordem de evolução. [] se a linha não existe.
static func unit_ids(branch: String) -> Array[String]:
	var result: Array[String] = []
	for node in V2ResearchDatabase.unit_line(branch):
		result.append(node.unlock_id)
	return result

## O nó de pesquisa de uma forma de unidade V2, ou null se `unit_id` não é da linha
## de nenhuma Doutrina.
static func node_for(unit_id: String) -> V2ResearchNode:
	if not V2ResearchDatabase.is_v2_id(unit_id):
		return null
	var node := V2ResearchDatabase.node_for_unlock_id(unit_id)
	if node == null or not (node.tier_role in LINE_ROLES):
		return null
	return node

static func is_line_unit(unit_id: String) -> bool:
	return node_for(unit_id) != null

## Linha de Doutrina de `unit_id` ("guardian"...), ou "" se não é unidade de linha.
static func branch_of(unit_id: String) -> String:
	var node := node_for(unit_id)
	return node.branch if node != null else ""

## Doutrina a que `unit_id` PERTENCE, incluindo a Unidade Lendária (que NÃO é forma da cadeia): "guardian"
## pro Escudeiro, o Guardião, a Sentinela e o Campeão Guardião. É o que as Técnicas de Doutrina usam pra
## saber se a unidade as tem (elegibilidade por Doutrina, não por cadeia de upgrade). "" se não é de nenhuma.
## `branch_of`/`resolve_trainable_form` continuam sendo só a CADEIA convencional: o Campeão nunca entra neles.
static func doctrine_branch_of(unit_id: String) -> String:
	var line_branch := branch_of(unit_id)
	if line_branch != "":
		return line_branch
	if V2LegendarySystem.is_legendary_kind(unit_id):
		var node := V2ResearchDatabase.node_for_unlock_id(unit_id)
		return node.branch if node != null else ""
	return ""

## Fase 12: o papel estratégico ("tank_frontline", "melee_damage", "ranged_combat",
## "mobility_shock", "sabotage_assassination", "city_conquest"...) da Doutrina de
## `unit_id`, incluindo a Unidade Lendária (N9, que doctrine_branch_of já reconhece
## mesmo fora da cadeia). "" se `unit_id` não é de nenhuma Doutrina Militar V2. A
## MESMA identidade em toda forma da linha (N3/N5/N7/N9) — vem de branch_info().role,
## já a fonte canônica (V2ResearchDatabase.DOCTRINE_BRANCHES), sem lista nova. É a
## consulta "qual é o papel desta unidade?" que uma futura IA poderá usar sem
## inferir por nome/movimento/alcance/prédio V1 (ver ArmyComposition, que continua
## intocada e serve só a V1).
static func role_of(unit_id: String) -> String:
	var branch := doctrine_branch_of(unit_id)
	if branch == "":
		return ""
	return V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch).get("role", "")

## A unidade-base (N3) da linha de `unit_id`, ou "".
static func base_of(unit_id: String) -> String:
	var ids := unit_ids(branch_of(unit_id))
	return ids[0] if not ids.is_empty() else ""

## A forma mais avançada da linha `branch` que `player` já pode usar (pesquisada E com
## gameplay conectado), ou "" se nenhuma. É "highest_unlocked_unit_form".
static func highest_unlocked_form(player, branch: String) -> String:
	var nodes := V2ResearchDatabase.unit_line(branch)
	for i in range(nodes.size() - 1, -1, -1):
		var node: V2ResearchNode = nodes[i]
		if node.gameplay_connected and V2UnlockSystem.is_unlocked(player, node.unlock_id):
			return node.unlock_id
	return ""

## A forma que uma cidade de `player` treina no lugar de `unit_id`: a mais avançada da
## MESMA linha. Ex.: com N5, resolve_trainable_form(p, "v2_unit_shieldbearer") ==
## "v2_unit_guardian". "" se `unit_id` não é de linha ou nada da linha está liberado.
static func resolve_trainable_form(player, unit_id: String) -> String:
	var branch := branch_of(unit_id)
	return highest_unlocked_form(player, branch) if branch != "" else ""

## `unit_id` é a forma que `player` treina AGORA? Formas superadas (Escudeiro depois de
## N5) deixam de ser produção normal — quem já existe continua existindo e é evoluído.
static func is_current_trainable_form(player, unit_id: String) -> bool:
	return resolve_trainable_form(player, unit_id) == unit_id
