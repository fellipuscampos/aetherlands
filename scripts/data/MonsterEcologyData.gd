class_name MonsterEcologyData
extends RefCounted

## V3 / Combat Ecology — Etapa 1 (Foundation). Dados PUROS do bestiário ecológico
## (docs/AETHERLANDS_V3_IMPLEMENTATION.md): tier declarado por espécie, tamanho de grupo e ganchos vazios
## para as Etapas 2–4 (habilidades, comportamento, habitat, atividade, população). Nada aqui roda por turno.
##
## Tier ≠ papel. O tier é da ESPÉCIE (Goblin é BASIC em qualquer lugar); o papel é do COVIL/ORIGEM
## (selvagem/ecologia, regional, guardião, evento). Um Troll Guardião é INTERMEDIATE + GUARDIAN; um Troll
## selvagem da ecologia é INTERMEDIATE + ECOLOGY. O tier nunca é inferido do id.
##
## Os stats de combate continuam em MonsterDatabase.KIND_DATA (fonte única de UnitData de monstro).

const TIER_BASIC := "BASIC"
const TIER_INTERMEDIATE := "INTERMEDIATE"
const TIER_ADVANCED := "ADVANCED"
const TIERS: Array[String] = [TIER_BASIC, TIER_INTERMEDIATE, TIER_ADVANCED]
const TIER_DISPLAY := {
	TIER_BASIC: "Básica",
	TIER_INTERMEDIATE: "Intermediária",
	TIER_ADVANCED: "Avançada",
}

## Campos por espécie:
## - tier: TIER_* (explícito, obrigatório).
## - group_size: monstros por sítio ecológico (grupo inicial e de reposição).
## - patrol_radius_cap: teto opcional de TODOS os raios do perfil de atividade (-1 = sem teto) — a forma
##   mínima de "quase imóvel com âncora" da Colmeia Micótica nesta etapa.
## - abilities: ids de MonsterAbilityData (Etapa 2).
## - behavior_profile (Etapa 2): city_hunt (pode fazer raide em cidade quando a era do tier permite),
##   improvement_hunt (procura melhoria para saquear), prey (any/isolated/group/caster — que presa prioriza),
##   avoid_bad_fights (não inicia luta claramente perdida), group_raid (só sai em raide com o bando),
##   chase_bonus (ajuste do raio de perseguição do tier). TIER define a intensidade; a ESPÉCIE, a identidade.
## - habitat_profile / activity_profile / population_profile: ganchos de etapas futuras, vazios de propósito.
const SPECIES := {
	"goblin": {"tier": TIER_BASIC, "group_size": 2, "patrol_radius_cap": -1, "abilities": ["quick_plunder"], "behavior_profile": {"city_hunt": true, "improvement_hunt": true, "prey": "any", "avoid_bad_fights": true}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"skeleton": {"tier": TIER_BASIC, "group_size": 3, "patrol_radius_cap": -1, "abilities": ["rising_horde"], "behavior_profile": {"city_hunt": true, "improvement_hunt": true, "prey": "any", "avoid_bad_fights": true, "group_raid": true}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"worg": {"tier": TIER_BASIC, "group_size": 2, "patrol_radius_cap": -1, "abilities": ["blood_scent"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "isolated", "avoid_bad_fights": true, "chase_bonus": 2}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"giant_spider": {"tier": TIER_BASIC, "group_size": 2, "patrol_radius_cap": -1, "abilities": ["venomous_bite"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any", "avoid_bad_fights": true}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"troll": {"tier": TIER_INTERMEDIATE, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["monstrous_regeneration"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any", "chase_bonus": -2}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"wyvern": {"tier": TIER_INTERMEDIATE, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["flame_breath"], "behavior_profile": {"city_hunt": true, "improvement_hunt": true, "prey": "group"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"minotaur": {"tier": TIER_INTERMEDIATE, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["charge"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"basilisk": {"tier": TIER_INTERMEDIATE, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["petrifying_gaze"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"colossal_worm": {"tier": TIER_ADVANCED, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["burrow"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "group"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"arboreal_ancient": {"tier": TIER_ADVANCED, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["roots_of_the_world"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"mana_devourer": {"tier": TIER_ADVANCED, "group_size": 1, "patrol_radius_cap": -1, "abilities": ["arcane_hunger", "aether_rupture"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "caster"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
	"mycotic_hive": {"tier": TIER_ADVANCED, "group_size": 1, "patrol_radius_cap": 1, "abilities": ["mycotic_contamination"], "behavior_profile": {"city_hunt": false, "improvement_hunt": false, "prey": "any"}, "habitat_profile": "", "activity_profile": "", "population_profile": ""},
}
## Ordem canônica estável (relatórios, round-robin do planner, testes). Nunca SPECIES.keys().
const SPECIES_ORDER: Array[String] = [
	"goblin", "skeleton", "worg", "giant_spider",
	"troll", "wyvern", "minotaur", "basilisk",
	"colossal_worm", "arboreal_ancient", "mana_devourer", "mycotic_hive",
]

# ---------------------------------------------------------------------------
# Colocação (setup) — provisório, ver docs/AETHERLANDS_V3_IMPLEMENTATION.md
# ---------------------------------------------------------------------------

## Distância mínima de QUALQUER capital (ou tile inicial do Colonizador antes da fundação) para um sítio
## ecológico no setup e na reposição. Não é unlock: só impede nascer em cima de uma Cidade I.
const CAPITAL_MIN_DISTANCE := {TIER_BASIC: 7, TIER_INTERMEDIATE: 10, TIER_ADVANCED: 14}
## Espaçamento mínimo entre centros de sítios (par de sítios usa o MAIOR dos dois valores).
const SITE_SPACING := {TIER_BASIC: 4, TIER_INTERMEDIATE: 6, TIER_ADVANCED: 8}
## Distância mínima de um sítio novo a qualquer covil (estrutura) existente — as áreas (raio 1) nunca se tocam.
const LAIR_CLEARANCE := 4
## Faixas de sítios por tier no mapa padrão (320×84). Fórmula: target = round(eligible / TILES_PER_SITE),
## limitado a MAX; o piso MIN só vale quando o mapa tem terra elegível de mapa padrão
## (eligible ≥ STANDARD_MIN_ELIGIBLE). Mapas menores (testes) escalam linearmente abaixo do piso.
const TARGET_MIN := {TIER_BASIC: 24, TIER_INTERMEDIATE: 12, TIER_ADVANCED: 6}
const TARGET_MAX := {TIER_BASIC: 32, TIER_INTERMEDIATE: 16, TIER_ADVANCED: 8}
## Terra elegível medida no mapa padrão (48 seeds do laboratório): ~2.450–2.850 tiles → ~26–30 / 13–15 / 6–7.
const TILES_PER_SITE := {TIER_BASIC: 95, TIER_INTERMEDIATE: 190, TIER_ADVANCED: 380}
const STANDARD_MIN_ELIGIBLE := 2000
## Massa de terra mínima para um sítio terrestre (ilhotas não recebem ecologia).
const MIN_LANDMASS := 40

# ---------------------------------------------------------------------------
# Reposição (runtime) — provisório
# ---------------------------------------------------------------------------

## Uma tentativa de reposição a cada REFILL_INTERVAL rodadas globais (no máximo UM sítio por tentativa).
const REFILL_INTERVAL := 2
## Sítio esvaziado vira memória regional: nenhum sítio novo a REFILL_DEPLETED_RADIUS dele por
## REFILL_DEPLETED_COOLDOWN rodadas (o mundo não repovoa o mesmo lugar logo depois de limpo).
const REFILL_DEPLETED_RADIUS := 8
const REFILL_DEPLETED_COOLDOWN := 20
## Distância mínima de qualquer unidade/cidade de civilização na reposição (nunca adjacente).
const REFILL_MIN_CIV_DISTANCE := 2
## Amostras aleatórias de tiles elegíveis por tentativa (sem varrer o mapa inteiro).
const REFILL_SAMPLE_ATTEMPTS := 96
## Pesos de ERA para escolher o tier de uma reposição NOVA (entre os tiers abaixo do alvo). Não removem
## população existente — só ponderam o que nasce.
const REFILL_WEIGHTS := {
	WorldPhaseRules.Phase.FOUNDATION: {TIER_BASIC: 60, TIER_INTERMEDIATE: 30, TIER_ADVANCED: 10},
	WorldPhaseRules.Phase.ASCENSION: {TIER_BASIC: 30, TIER_INTERMEDIATE: 50, TIER_ADVANCED: 20},
	WorldPhaseRules.Phase.CONVERGENCE: {TIER_BASIC: 15, TIER_INTERMEDIATE: 35, TIER_ADVANCED: 50},
}

## Canal de RNG próprio da ecologia (colocação + reposição + ronda). Nunca o RNG global, o
## monster_turn_rng, o do planner regional, do Dragão ou do Relicário.
const RNG_SALT := 9300

static func is_ecology_species(kind: String) -> bool:
	return SPECIES.has(kind)

## Tier da espécie ("" = fora da ecologia: Dragão, unidades de civilização).
static func tier_of(kind: String) -> String:
	return String(SPECIES.get(kind, {}).get("tier", ""))

static func tier_display(tier: String) -> String:
	return String(TIER_DISPLAY.get(tier, ""))

static func species_of_tier(tier: String) -> Array[String]:
	var result: Array[String] = []
	for kind in SPECIES_ORDER:
		if tier_of(kind) == tier:
			result.append(kind)
	return result

static func group_size(kind: String) -> int:
	return int(SPECIES.get(kind, {}).get("group_size", 1))

static func patrol_radius_cap(kind: String) -> int:
	return int(SPECIES.get(kind, {}).get("patrol_radius_cap", -1))

static func abilities(kind: String) -> Array:
	return (SPECIES.get(kind, {}).get("abilities", []) as Array).duplicate()

## Alvo de sítios por tier a partir da terra elegível (ver TILES_PER_SITE/TARGET_MIN/TARGET_MAX).
static func target_for(tier: String, eligible_tiles: int) -> int:
	var raw := roundi(float(eligible_tiles) / float(TILES_PER_SITE[tier]))
	var target := mini(raw, int(TARGET_MAX[tier]))
	if eligible_tiles >= STANDARD_MIN_ELIGIBLE:
		target = maxi(target, int(TARGET_MIN[tier]))
	return maxi(target, 0)

static func targets_for(eligible_tiles: int) -> Dictionary:
	var result := {}
	for tier in TIERS:
		result[tier] = target_for(tier, eligible_tiles)
	return result

## Perfil de comportamento da espécie (MonsterEcologyData.SPECIES.behavior_profile), com defaults neutros.
static func behavior(kind: String) -> Dictionary:
	var result := {"city_hunt": false, "improvement_hunt": false, "prey": "any", "avoid_bad_fights": false, "group_raid": false, "chase_bonus": 0}
	var profile: Variant = SPECIES.get(kind, {}).get("behavior_profile", {})
	if typeof(profile) == TYPE_DICTIONARY:
		result.merge(profile, true)
	return result
