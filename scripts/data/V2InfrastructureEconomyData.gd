class_name V2InfrastructureEconomyData
extends RefCounted

## Aetherlands V2, Fase 14 — fonte ÚNICA dos números da Economia V2 (§4 do pedido). Nenhuma outra
## classe hardcoda base yields, custo de prédio econômico ou yield por tier — City/GameManager/HUD/
## V2EconomyRuntime consultam aqui. Fase 27 balanceou a Academia; os demais
## valores foram auditados e preservados por falta de evidência para mudança.
##
## Modelo (§1-§2): cinco recursos funcionais (Ouro, Suprimentos, Produção, Conhecimento, Mana).
## Ouro/Mana/Conhecimento são fluxos GLOBAIS (creditados ao PlayerData inteiro); Suprimentos é
## CAPACIDADE global (nunca estoque, nunca consumida ainda — ver V2EconomyRuntime); Produção é
## fluxo LOCAL por cidade (creditada a City.stored_production, nunca agregada no PlayerData). Não
## existe Comida V2 — a Fazenda desta versão produz Capacidade de Suprimentos, não comida.

## Toda cidade fornece isto TODO turno, mesmo Cidade I sem prédio nenhum — nunca depende de
## City Level/território/recursos do mapa (§3). (Fase 25: população/tiles trabalhados não existem mais.)
const BASE_GOLD_PER_CITY := 2.0
const BASE_SUPPLY_PER_CITY := 4.0
const BASE_PRODUCTION_PER_CITY := 4.0
const BASE_KNOWLEDGE_PER_CITY := 2.0
const BASE_MANA_PER_CITY := 1.0

const RESOURCE_LABELS := {
	"gold": "Ouro",
	"supply": "Capacidade de Suprimentos",
	"production": "Produção",
	"knowledge": "Conhecimento",
	"mana": "Mana",
}

## Uma entrada por linha econômica (as 5 restantes de Infraestrutura — Urbanização NÃO entra
## aqui, ela não é econômica, ver V2CityLevelData). `unlock_ids` é [N1, N2, N3] na ordem exata do
## pedido (§65) — únicos endereços estáveis, nunca alterados depois de implementados. `yields[i]`
## é o rendimento POR CÓPIA do prédio quando o dono tem o tier (i+1) pesquisado (índice 0 = só N1,
## ou prédio capturado sem pesquisa nenhuma do novo dono — ver V2EconomyRuntime.infrastructure_tier).
const BUILDINGS := {
	"economy": {
		"building_id": "v2_building_market",
		"building_name_plural": "Mercados",
		"resource": "gold",
		"production_cost": 20.0,
		"yields": [4.0, 6.0, 8.0],
		"unlock_ids": ["v2_building_market", "v2_market_efficiency_2", "v2_market_efficiency_3"],
	},
	"logistics": {
		"building_id": "v2_building_farm",
		"building_name_plural": "Fazendas",
		"resource": "supply",
		"production_cost": 20.0,
		"yields": [4.0, 6.0, 8.0],
		"unlock_ids": ["v2_building_farm", "v2_farm_efficiency_2", "v2_farm_efficiency_3"],
	},
	"industry": {
		"building_id": "v2_building_workshop",
		"building_name_plural": "Oficinas",
		"resource": "production",
		"production_cost": 24.0,
		"yields": [2.0, 3.0, 4.0],
		"unlock_ids": ["v2_building_workshop", "v2_workshop_efficiency_2", "v2_workshop_efficiency_3"],
	},
	"academy": {
		"building_id": "v2_building_academy",
		"building_name_plural": "Academias",
		"resource": "knowledge",
		"production_cost": 24.0,
		"yields": [3.0, 4.0, 5.0],
		"unlock_ids": ["v2_building_academy", "v2_academy_efficiency_2", "v2_academy_efficiency_3"],
	},
	"arcane": {
		"building_id": "v2_building_arcane_shrine",
		"building_name_plural": "Santuários Arcanos",
		"resource": "mana",
		"production_cost": 24.0,
		"yields": [2.0, 3.0, 4.0],
		"unlock_ids": ["v2_building_arcane_shrine", "v2_arcane_shrine_efficiency_2", "v2_arcane_shrine_efficiency_3"],
	},
}

static func branches() -> Array:
	return BUILDINGS.keys()

static func has_branch(branch: String) -> bool:
	return BUILDINGS.has(branch)

static func entry_for_branch(branch: String) -> Dictionary:
	return BUILDINGS.get(branch, {})

## "" se `building_id` não é um dos cinco prédios econômicos.
static func branch_for_building(building_id: String) -> String:
	for branch in BUILDINGS:
		if BUILDINGS[branch].building_id == building_id:
			return branch
	return ""

static func is_economy_building(building_id: String) -> bool:
	return branch_for_building(building_id) != ""

static func resource_for_building(building_id: String) -> String:
	var branch := branch_for_building(building_id)
	return BUILDINGS.get(branch, {}).get("resource", "")

static func resource_label(resource: String) -> String:
	return RESOURCE_LABELS.get(resource, resource)

## Rendimento de UMA cópia de `building_id`, dado o tier de pesquisa (1..3) que o DONO ATUAL da
## cidade possui para a linha correspondente — nunca o tier de quem construiu (§56 do pedido: a
## eficiência é sempre do dono atual). tier <= 0 ou > 3 é grampeado ao intervalo válido.
static func yield_per_copy(building_id: String, tier: int) -> float:
	var branch := branch_for_building(building_id)
	if branch == "":
		return 0.0
	var yields: Array = BUILDINGS[branch].yields
	var index: int = clampi(tier, 1, yields.size()) - 1
	return float(yields[index])

## branch -> [unlock_id N1, unlock_id N2, unlock_id N3] (§65 do pedido — únicos ids definitivos).
static func unlock_ids_for_branch(branch: String) -> Array:
	return BUILDINGS.get(branch, {}).get("unlock_ids", [])

## unlock_id -> (branch, tier 1..3), ou ("", 0) se não é um unlock econômico.
static func branch_and_tier_for_unlock(unlock_id: String) -> Array:
	for branch in BUILDINGS:
		var ids: Array = BUILDINGS[branch].unlock_ids
		var i := ids.find(unlock_id)
		if i != -1:
			return [branch, i + 1]
	return ["", 0]

static func production_cost_for_branch(branch: String) -> float:
	return float(BUILDINGS.get(branch, {}).get("production_cost", 0.0))

static func building_id_for_branch(branch: String) -> String:
	return String(BUILDINGS.get(branch, {}).get("building_id", ""))

## Plural em português do prédio da linha (ex.: "Santuário Arcano" -> "Santuários Arcanos", onde a
## simples concatenação de "s" erraria o primeiro termo) — usado só por texto de UI/tooltip.
static func building_name_plural(branch: String) -> String:
	return String(BUILDINGS.get(branch, {}).get("building_name_plural", ""))

## Todos os unlock_ids das cinco linhas econômicas, nas 3 posições — usado por
## V2InfrastructureContent.CONNECTED_UNLOCK_IDS (§65) sem repetir a lista à mão.
static func all_unlock_ids() -> Array[String]:
	var result: Array[String] = []
	for branch in BUILDINGS:
		for id in BUILDINGS[branch].unlock_ids:
			result.append(id)
	return result
