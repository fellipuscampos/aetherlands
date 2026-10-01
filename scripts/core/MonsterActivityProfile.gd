class_name MonsterActivityProfile
extends RefCounted

## V3 / Combat Ecology — Etapa 1. Atividade por TIER × ERA, data-driven. A Era não desbloqueia nem
## remove criatura: ela muda só o COMPORTAMENTO (raios, alvo de cidade/melhoria, ronda) e o peso de
## reposição (MonsterEcologyData.REFILL_WEIGHTS). Consumido pela MonsterAI (_take_ecology_turn); não tem
## estado, não salva e não roda por frame.
##
## Campos (todos em tiles, medidos a partir da ÂNCORA do sítio, nunca da posição atual do monstro):
## - patrol_radius: território vigiado — unidade de civilização dentro dele vira alvo de perseguição;
##   fora dele o monstro ocioso volta para casa.
## - chase_radius: até onde persegue/ataca um intruso (>= patrol_radius).
## - city_radius: 0 = nunca procura cidade; >0 = pode escolher a cidade ativa mais próxima dentro deste
##   raio como objetivo (aproximar → atacar; nunca captura).
## - improvement_radius: 0 = ignora melhorias; >0 = procura melhoria de recurso não saqueada neste raio.
## - roam_chance: chance por rodada de rondar um tile do próprio território quando ocioso (RNG da ecologia).
## - raid_rest_turns: depois de um RAIDE (golpe numa cidade/guarnição ou saque de melhoria) o monstro volta
##   para casa e só escolhe outro objetivo de cidade/melhoria depois disto — pressão periódica, nunca cerco
##   permanente na porta da cidade.
## - city_from_turn: turno global a partir do qual o tier procura cidades (carência de abertura para a
##   primeira Cidade I erguer defesa; a ameaça regional já cobre o começo).
##
## Números PROVISÓRIOS (V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER). A leitura esperada:
## Despertar = BASIC domina (caça cidade a até 12); Ascensão = INTERMEDIATE domina (10–12);
## Convergência = ADVANCED domina (10–12). Quem não domina continua hostil e territorial.

const PROFILES := {
	WorldPhaseRules.Phase.FOUNDATION: {
		MonsterEcologyData.TIER_BASIC: {"patrol_radius": 6, "chase_radius": 8, "city_radius": 12, "improvement_radius": 12, "roam_chance": 0.35, "raid_rest_turns": 8, "city_from_turn": 10},
		MonsterEcologyData.TIER_INTERMEDIATE: {"patrol_radius": 4, "chase_radius": 5, "city_radius": 0, "improvement_radius": 0, "roam_chance": 0.1, "raid_rest_turns": 0, "city_from_turn": 0},
		MonsterEcologyData.TIER_ADVANCED: {"patrol_radius": 3, "chase_radius": 4, "city_radius": 0, "improvement_radius": 0, "roam_chance": 0.0, "raid_rest_turns": 0, "city_from_turn": 0},
	},
	WorldPhaseRules.Phase.ASCENSION: {
		MonsterEcologyData.TIER_BASIC: {"patrol_radius": 4, "chase_radius": 5, "city_radius": 0, "improvement_radius": 4, "roam_chance": 0.2, "raid_rest_turns": 8, "city_from_turn": 0},
		MonsterEcologyData.TIER_INTERMEDIATE: {"patrol_radius": 7, "chase_radius": 9, "city_radius": 12, "improvement_radius": 12, "roam_chance": 0.35, "raid_rest_turns": 8, "city_from_turn": 0},
		MonsterEcologyData.TIER_ADVANCED: {"patrol_radius": 4, "chase_radius": 6, "city_radius": 0, "improvement_radius": 0, "roam_chance": 0.15, "raid_rest_turns": 0, "city_from_turn": 0},
	},
	WorldPhaseRules.Phase.CONVERGENCE: {
		MonsterEcologyData.TIER_BASIC: {"patrol_radius": 3, "chase_radius": 4, "city_radius": 0, "improvement_radius": 3, "roam_chance": 0.1, "raid_rest_turns": 8, "city_from_turn": 0},
		MonsterEcologyData.TIER_INTERMEDIATE: {"patrol_radius": 5, "chase_radius": 6, "city_radius": 0, "improvement_radius": 5, "roam_chance": 0.2, "raid_rest_turns": 8, "city_from_turn": 0},
		MonsterEcologyData.TIER_ADVANCED: {"patrol_radius": 7, "chase_radius": 9, "city_radius": 12, "improvement_radius": 12, "roam_chance": 0.35, "raid_rest_turns": 8, "city_from_turn": 0},
	},
}

## Perfil do tier na era (cópia). Tier/era desconhecidos caem no perfil mais conservador (ADVANCED no Despertar).
static func for_tier(tier: String, phase: int) -> Dictionary:
	var by_tier: Dictionary = PROFILES.get(phase, PROFILES[WorldPhaseRules.Phase.FOUNDATION])
	return (by_tier.get(tier, by_tier[MonsterEcologyData.TIER_ADVANCED]) as Dictionary).duplicate()

## Perfil efetivo de uma ESPÉCIE: o do tier, com o teto de raio da espécie (MonsterEcologyData.
## patrol_radius_cap) quando existir. Gancho das Etapas 2–4 para perfis próprios por espécie.
static func for_species(kind: String, phase: int) -> Dictionary:
	var profile := for_tier(MonsterEcologyData.tier_of(kind), phase)
	var cap := MonsterEcologyData.patrol_radius_cap(kind)
	if cap >= 0:
		profile.patrol_radius = mini(int(profile.patrol_radius), cap)
		profile.chase_radius = mini(int(profile.chase_radius), cap + 1)
		profile.city_radius = mini(int(profile.city_radius), cap + 1) if int(profile.city_radius) > 0 else 0
		profile.improvement_radius = mini(int(profile.improvement_radius), cap + 1) if int(profile.improvement_radius) > 0 else 0
	return profile

## Peso de reposição do tier na era (MonsterEcologyData.REFILL_WEIGHTS).
static func reinforcement_weight(tier: String, phase: int) -> int:
	var weights: Dictionary = MonsterEcologyData.REFILL_WEIGHTS.get(phase, MonsterEcologyData.REFILL_WEIGHTS[WorldPhaseRules.Phase.FOUNDATION])
	return int(weights.get(tier, 0))

## Rótulo curto do comportamento REAL do perfil (TileInspector) — nunca menciona habilidade futura.
static func label(profile: Dictionary) -> String:
	if int(profile.get("city_radius", 0)) > 0:
		return "Agressivo — ronda e ataca cidades próximas"
	if int(profile.get("patrol_radius", 0)) >= 5:
		return "Patrulha ampla"
	return "Territorial"
