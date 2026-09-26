class_name V2CityLevelData
extends RefCounted

## Aetherlands V2, Fase 13 — fonte ÚNICA dos números de City Level (I–IV). Nenhuma outra classe
## (City, HUD, SelectionManager, SaveManager, V2ResearchDatabase) deve hardcodar slots/limite
## repetível/raio/Pontos de Anexação/custo — todos consultam aqui (§6/§99 do pedido: consulta
## O(1), nunca varrer os 18 nós de Infraestrutura pra descobrir slots).
##
## BALANCE PLACEHOLDER: nenhum destes números foi balanceado, só representam progressão
## consistente (mesmo espírito de V2ResearchDatabase.BRANCH_TIER_COSTS).

const MIN_LEVEL := 1
const MAX_LEVEL := 4
## A partir daqui `City.is_developed_v2()` é true — única fonte da regra (§20).
const DEVELOPED_MIN_LEVEL := 3

const ROMAN := {1: "I", 2: "II", 3: "III", 4: "IV"}

## level -> {slots, repeatable_limit, territory_radius, annexation_grant, research_required}.
## `research_required` = "" no nível I (toda cidade nasce nele, sem exigir pesquisa nenhuma).
const LEVELS := {
	1: {"slots": 4, "repeatable_limit": 1, "territory_radius": 1, "annexation_grant": 0, "research_required": ""},
	2: {"slots": 7, "repeatable_limit": 2, "territory_radius": 2, "annexation_grant": 4, "research_required": "v2_infrastructure_urbanization_1"},
	3: {"slots": 10, "repeatable_limit": 3, "territory_radius": 3, "annexation_grant": 5, "research_required": "v2_infrastructure_urbanization_2"},
	4: {"slots": 13, "repeatable_limit": 4, "territory_radius": 4, "annexation_grant": 6, "research_required": "v2_infrastructure_urbanization_3"},
}

## Custo do PROJETO local (produção da própria cidade) pra alcançar `target_level` (2, 3 ou 4).
const UPGRADE_COSTS := {
	2: {"production": 60.0, "gold": 30.0},
	3: {"production": 120.0, "gold": 70.0},
	4: {"production": 220.0, "gold": 140.0},
}

## unlock_id (o que a PESQUISA desbloqueia) — nunca confundir com o id do PROJETO abaixo (§15).
const UNLOCK_ID_FOR_LEVEL := {2: "v2_city_level_2", 3: "v2_city_level_3", 4: "v2_city_level_4"}
const LEVEL_FOR_UNLOCK_ID := {"v2_city_level_2": 2, "v2_city_level_3": 3, "v2_city_level_4": 4}
## id do PROJETO de PRODUÇÃO local (entra em City.production_item, compete pelo mesmo slot que
## qualquer unidade/prédio — §13/§15).
const PROJECT_ID_FOR_LEVEL := {2: "v2_city_upgrade_2", 3: "v2_city_upgrade_3", 4: "v2_city_upgrade_4"}
const LEVEL_FOR_PROJECT_ID := {"v2_city_upgrade_2": 2, "v2_city_upgrade_3": 3, "v2_city_upgrade_4": 4}

static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)

static func _entry(level: int) -> Dictionary:
	return LEVELS.get(clamp_level(level), LEVELS[MIN_LEVEL])

static func level_name(level: int) -> String:
	return "Cidade %s" % roman(level)

## Numeral romano do nível (I..IV) — o rótulo da cidade no mapa usa só o numeral.
static func roman(level: int) -> String:
	return String(ROMAN.get(clamp_level(level), "I"))

## Aetherlands V2, Fase 16 — HP máximo da cidade por City Level (BALANCE PLACEHOLDER): resistência
## urbana vem do nível de desenvolvimento.
const MAX_HP_BY_LEVEL := {1: 24.0, 2: 30.0, 3: 36.0, 4: 44.0}

static func max_hp(level: int) -> float:
	return float(MAX_HP_BY_LEVEL[clamp_level(level)])

static func max_building_slots(level: int) -> int:
	return int(_entry(level).slots)

static func repeatable_building_limit(level: int) -> int:
	return int(_entry(level).repeatable_limit)

static func max_territory_radius(level: int) -> int:
	return int(_entry(level).territory_radius)

## Pontos de Anexação recebidos AO CHEGAR em `level` (0 pro nível I, que nenhuma cidade "chega
## a", ela já nasce nele).
static func annexation_grant(level: int) -> int:
	return int(_entry(level).annexation_grant)

## Id de pesquisa (v2_infrastructure_urbanization_N) exigido pra alcançar `level`, ou "" pro
## nível I (sempre disponível).
static func research_required_for_level(level: int) -> String:
	return String(_entry(level).research_required)

static func is_developed(level: int) -> bool:
	return level >= DEVELOPED_MIN_LEVEL

static func has_next_level(level: int) -> bool:
	return level < MAX_LEVEL

## O próximo nível de `level`, ou 0 se já está no máximo (Cidade IV não tem upgrade — §46).
static func next_level(level: int) -> int:
	return level + 1 if has_next_level(level) else 0

static func upgrade_production_cost(target_level: int) -> float:
	return float(UPGRADE_COSTS.get(target_level, {}).get("production", -1.0))

static func upgrade_gold_cost(target_level: int) -> float:
	return float(UPGRADE_COSTS.get(target_level, {}).get("gold", -1.0))

## O unlock_id que a pesquisa concede pra permitir `target_level` (2..4), ou "" fora do intervalo.
static func unlock_id_for_level(target_level: int) -> String:
	return String(UNLOCK_ID_FOR_LEVEL.get(target_level, ""))

static func target_level_for_unlock(unlock_id: String) -> int:
	return int(LEVEL_FOR_UNLOCK_ID.get(unlock_id, 0))

## "v2_city_level_2" -> "Cidade II" (toast/tooltip de pesquisa) — nunca o nome do NÓ de pesquisa
## ("Planejamento Urbano"), o mesmo cuidado da Fase 12 com "Exército Supremo" x "Supremacia Militar".
static func level_name_for_unlock(unlock_id: String) -> String:
	return level_name(target_level_for_unlock(unlock_id))

## id do PROJETO de produção local que leva a cidade a `target_level` (2..4), ou "" fora do intervalo.
static func project_id_for_level(target_level: int) -> String:
	return String(PROJECT_ID_FOR_LEVEL.get(target_level, ""))

## `production_item` é um City Project (v2_city_upgrade_2/3/4)? O nível-alvo, ou 0 se não for —
## é a checagem que City.production_cost()/process_turn() usam pra desviar da fila normal de
## unidade/prédio sem criar uma segunda fila (§13/§14).
static func target_level_for_project(project_id: String) -> int:
	return int(LEVEL_FOR_PROJECT_ID.get(project_id, 0))

static func is_city_project(project_id: String) -> bool:
	return target_level_for_project(project_id) > 0
