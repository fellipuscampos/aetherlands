class_name V2ResourceImprovementData
extends RefCounted

## Aetherlands V2, Fase 15 — fonte ÚNICA das cinco melhorias de recurso do mapa (§65-71 do pedido).
## Nenhum `if resource == "iron"` no runtime do Construtor/da Economia — tudo dirigido por este
## dado. Os recursos (`iron`/`horses`/`gems`/`silk`/`mana_node`) são os IDs REAIS já usados pelo
## jogo (`HexTileData.resource`, `ResourceDatabase`, auditados antes de escrever este arquivo —
## §64 do pedido); nenhuma duplicata V2 do recurso foi criada.
##
## Cada melhoria tem uma lista de EFEITOS (a Seda tem dois: Ouro + Conhecimento, §70) — cada efeito
## aponta pra uma `branch` econômica (a MESMA das cinco linhas de Infraestrutura da Fase 14) e três
## yields por tier (1/2/3, mesma regra de "dono atual, nunca de quem construiu" que os prédios já
## seguem — §72). Nenhuma melhoria tem upkeep (§85): não entram em `player_gold_upkeep` e nunca são
## descontadas por Déficit (§39/§87).

const IMPROVEMENTS := {
	"iron": {
		"id": "v2_improvement_iron_mine",
		"display_name": "Mina de Ferro",
		"model_scene_path": "res://assets/models/kaykit/buildings/building_blacksmith_blue.gltf",
		"effects": [
			{"resource": "production", "branch": "industry", "yields": [2.0, 3.0, 4.0]},
		],
	},
	"horses": {
		"id": "v2_improvement_horse_ranch",
		"display_name": "Haras",
		"model_scene_path": "res://assets/models/kaykit/buildings/building_market_blue.gltf",
		"effects": [
			{"resource": "supply", "branch": "logistics", "yields": [4.0, 6.0, 8.0]},
		],
	},
	"gems": {
		"id": "v2_improvement_gem_mine",
		"display_name": "Mina de Gemas",
		"model_scene_path": "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf",
		"effects": [
			{"resource": "gold", "branch": "economy", "yields": [4.0, 6.0, 8.0]},
		],
	},
	"silk": {
		"id": "v2_improvement_silk_post",
		"display_name": "Entreposto de Seda",
		"model_scene_path": "res://assets/models/kaykit/buildings/building_windmill_blue.gltf",
		"effects": [
			{"resource": "gold", "branch": "economy", "yields": [2.0, 3.0, 4.0]},
			{"resource": "knowledge", "branch": "academy", "yields": [1.0, 2.0, 3.0]},
		],
	},
	"mana_node": {
		"id": "v2_improvement_arcane_conduit",
		"display_name": "Conduíte Arcano",
		"model_scene_path": "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf",
		"effects": [
			{"resource": "mana", "branch": "arcane", "yields": [2.0, 3.0, 4.0]},
		],
	},
}

static func resource_ids() -> Array:
	return IMPROVEMENTS.keys()

static func has_resource(resource_id: String) -> bool:
	return IMPROVEMENTS.has(resource_id)

static func entry_for_resource(resource_id: String) -> Dictionary:
	return IMPROVEMENTS.get(resource_id, {})

static func improvement_id_for_resource(resource_id: String) -> String:
	return String(IMPROVEMENTS.get(resource_id, {}).get("id", ""))

## "" se `improvement_id` não é uma das cinco melhorias — busca reversa, só usada pra resolver o
## `resource` a partir do que está salvo em `City.resource_improvements` (que guarda o improvement
## id, não o resource id).
static func resource_for_improvement(improvement_id: String) -> String:
	for resource_id in IMPROVEMENTS:
		if IMPROVEMENTS[resource_id].id == improvement_id:
			return resource_id
	return ""

static func display_name_for_resource(resource_id: String) -> String:
	return String(IMPROVEMENTS.get(resource_id, {}).get("display_name", ""))

static func model_scene_path_for_resource(resource_id: String) -> String:
	return String(IMPROVEMENTS.get(resource_id, {}).get("model_scene_path", ""))

static func effects_for_resource(resource_id: String) -> Array:
	return IMPROVEMENTS.get(resource_id, {}).get("effects", [])

## Rendimento de UM efeito no tier 1..3 (mesma semântica de V2InfrastructureEconomyData.yield_per_copy).
static func yield_for_effect(effect: Dictionary, tier: int) -> float:
	var yields: Array = effect.get("yields", [])
	if yields.is_empty():
		return 0.0
	var index: int = clampi(tier, 1, yields.size()) - 1
	return float(yields[index])

## Todos os ids de melhoria (pra CONNECTED_UNLOCK_IDS-style de outros sistemas, se precisarem).
static func all_improvement_ids() -> Array:
	var result := []
	for resource_id in IMPROVEMENTS:
		result.append(IMPROVEMENTS[resource_id].id)
	return result
