class_name V2AITuning
extends RefCounted

## Fonte central dos pesos comportamentais da IA V2. A Fase 27 auditou estes
## valores em 36 partidas determinísticas; eles não alteram regras, custos ou
## rendimentos do jogo e nunca compensam raça/orientação individualmente.

const PRESSURE_MEMORY := 0.80
const PRESSURE_SAMPLE := 0.20
const RESEARCH_SWITCH_MAX_PROGRESS := 0.50
const RESEARCH_SWITCH_MARGIN := 18.0
const SUPPLY_WARNING_RATIO := 0.80
const SUPPLY_FREE_RATIO := 0.20
const SUPPLY_FREE_MIN := 2
const GOLD_RESERVE_BASE := 20.0
const GOLD_RESERVE_PER_CITY := 10.0
const NORMAL_TOKEN_CAP := 20
const HARD_TOKEN_CAP := 24
const PORTAL_MIN_DISTANCE_GAIN := 3
const SPECIAL_ACTION_UTILITY := 10.0
const SPECIAL_ACTION_GAIN := 1.10
const FRIENDLY_FIRE_PENALTY := 1.25
const LOCAL_THREAT_RADIUS := 6
const CITY_SLOT_PRESSURE := 0.70
const INFRA_FOUNDATION_BRANCHES := 2
const INFRA_FOUNDATION_BONUS := 55.0
## Fase 27: prioridade economica geral de Conhecimento, medida no balance lab.
## Nao depende de raca/orientacao e continua competindo com necessidades urgentes.
const KNOWLEDGE_RESEARCH_URGENCY := 32.0
const RITUAL_WAR_PRESSURE := {4: 0.25, 3: 0.75, 2: 1.25, 1: 2.0}

const ORIENTATION_RESEARCH := {
	"MILITARY": {"military": 34.0, "magic": 8.0, "infrastructure": 18.0},
	"ARCANE": {"military": 8.0, "magic": 34.0, "infrastructure": 20.0},
	"BALANCED": {"military": 22.0, "magic": 22.0, "infrastructure": 24.0},
}

static func gold_reserve(player: PlayerData) -> float:
	return GOLD_RESERVE_BASE + GOLD_RESERVE_PER_CITY * player.cities.size()

static func target_relevant_units(player: PlayerData) -> int:
	var completed_primary := 0
	for tree in [V2ResearchNode.TreeType.MILITARY_DOCTRINE, V2ResearchNode.TreeType.MAGIC_SCHOOL]:
		for branch in V2ResearchDatabase.completed_branches(tree, player.v2_research.completed_ids):
			completed_primary += 1
	var max_city_level := 1
	for city in player.cities:
		max_city_level = maxi(max_city_level, city.city_level)
	return clampi(5 + 2 * player.cities.size() + completed_primary + max_city_level, 8, NORMAL_TOKEN_CAP)
