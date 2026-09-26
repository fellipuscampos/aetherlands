class_name V2FortificationData
extends RefCounted

## Aetherlands V2, Fase 16 — fonte ÚNICA dos números de Fortificação urbana (nível 0..3). Nenhuma
## outra classe (City, HUD, CombatResolver, CityDefense, GameManager, V2EconomyRuntime) hardcoda
## custo, upkeep, escudo, bônus de defesa, poder/alcance do Ataque da Cidade ou requisito — todas
## consultam aqui, O(1). BALANCE PLACEHOLDER: nada balanceado.
##
## Fortificação é um DESENVOLVIMENTO LOCAL da cidade (City.fortification_level), construído como
## PROJETO na mesma fila de produção (production_item), nunca um BuildingData: não ocupa slot, não
## entra em City.buildings, não usa CopyLimitMode. Cada nível SUBSTITUI o anterior (o upkeep da
## Fortaleza é 3, não 1 + 2 + 3).

const MIN_LEVEL := 0
const MAX_LEVEL := 3

## level -> dados. `research_unlock` = o unlock_id da pesquisa de Urbanização que libera o nível —
## o MESMO nó que libera o City Level correspondente (§11/§12 do pedido: um segundo efeito da mesma
## pesquisa, nunca um nó novo).
const LEVELS := {
	0: {"name": "Nenhuma", "production": 0.0, "upkeep": 0.0, "shield": 0.0, "defense": 0.0, "attack": 0.0, "range": 0, "city_level": 1, "research_unlock": ""},
	1: {"name": "Muralhas I", "production": 40.0, "upkeep": 1.0, "shield": 8.0, "defense": 0.10, "attack": 3.0, "range": 2, "city_level": 2, "research_unlock": "v2_city_level_2"},
	2: {"name": "Muralhas II", "production": 70.0, "upkeep": 2.0, "shield": 14.0, "defense": 0.20, "attack": 5.0, "range": 2, "city_level": 3, "research_unlock": "v2_city_level_3"},
	3: {"name": "Fortaleza", "production": 110.0, "upkeep": 3.0, "shield": 22.0, "defense": 0.30, "attack": 7.0, "range": 3, "city_level": 4, "research_unlock": "v2_city_level_4"},
}

## id do PROJETO de produção local que leva a cidade ao nível (1..3) — nunca um BuildingData.
const PROJECT_ID_FOR_LEVEL := {1: "v2_city_fortification_1", 2: "v2_city_fortification_2", 3: "v2_city_fortification_3"}
const LEVEL_FOR_PROJECT_ID := {"v2_city_fortification_1": 1, "v2_city_fortification_2": 2, "v2_city_fortification_3": 3}

static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)

static func _entry(level: int) -> Dictionary:
	return LEVELS[clamp_level(level)]

static func display_name(level: int) -> String:
	return String(_entry(level).name)

static func production_cost(level: int) -> float:
	return float(_entry(level).production)

static func gold_upkeep(level: int) -> float:
	return float(_entry(level).upkeep)

static func shield_max(level: int) -> float:
	return float(_entry(level).shield)

static func city_defense_bonus(level: int) -> float:
	return float(_entry(level).defense)

static func city_attack_power(level: int) -> float:
	return float(_entry(level).attack)

static func city_attack_range(level: int) -> int:
	return int(_entry(level).range)

static func has_city_attack(level: int) -> bool:
	return city_attack_power(level) > 0.0

static func required_city_level(level: int) -> int:
	return int(_entry(level).city_level)

## O unlock_id da pesquisa exigida (o mesmo de V2CityLevelData.UNLOCK_ID_FOR_LEVEL do nível urbano
## correspondente), "" pro nível 0.
static func required_research_id(level: int) -> String:
	return String(_entry(level).research_unlock)

static func project_id(level: int) -> String:
	return String(PROJECT_ID_FOR_LEVEL.get(level, ""))

## production_item é um projeto de fortificação? O nível-alvo, ou 0.
static func target_level_for_project(id: String) -> int:
	return int(LEVEL_FOR_PROJECT_ID.get(id, 0))

static func is_fortification_project(id: String) -> bool:
	return target_level_for_project(id) > 0

static func next_level(level: int) -> int:
	return level + 1 if level < MAX_LEVEL else 0

## O nível de fortificação que a MESMA pesquisa de Urbanização libera (0 se nenhum) — o toast e o
## tooltip do nó dizem "Cidade II e Muralhas I" a partir disto, sem três textos fixos.
static func level_for_research_unlock(unlock_id: String) -> int:
	for level in LEVELS:
		if int(level) > 0 and LEVELS[level].research_unlock == unlock_id:
			return int(level)
	return 0
