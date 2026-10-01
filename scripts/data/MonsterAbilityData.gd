class_name MonsterAbilityData
extends RefCounted

## V3 / Etapa 2 — habilidades das 12 espécies da Combat Ecology, data-driven (nome, descrição, passiva/ativa,
## recarga, alcance, alvo, quando a IA usa e números). Quem decide é a MonsterAI; quem executa é o
## MonsterAbilitySystem; dano físico passa por CombatResolver.predict/apply_direct_unit_damage. Nada aqui
## infere comportamento pelo nome do monstro: a espécie lista os ids em MonsterEcologyData.SPECIES.abilities.
##
## Todos os números: V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER.

const QUICK_PLUNDER := "quick_plunder"
const RISING_HORDE := "rising_horde"
const BLOOD_SCENT := "blood_scent"
const VENOMOUS_BITE := "venomous_bite"
const MONSTROUS_REGENERATION := "monstrous_regeneration"
const FLAME_BREATH := "flame_breath"
const CHARGE := "charge"
const PETRIFYING_GAZE := "petrifying_gaze"
const BURROW := "burrow"
const ROOTS_OF_THE_WORLD := "roots_of_the_world"
const ARCANE_HUNGER := "arcane_hunger"
const AETHER_RUPTURE := "aether_rupture"
const MYCOTIC_CONTAMINATION := "mycotic_contamination"

## Campos comuns: name, description, passive, cooldown (turnos próprios; 0 = sem recarga), min_range, max_range,
## targeting (unit/city/self/area/caster), ai (quando a IA usa). Os demais são parâmetros da própria habilidade.
const ABILITIES := {
	QUICK_PLUNDER: {
		"name": "Saque Rápido", "passive": true, "cooldown": 0, "min_range": 1, "max_range": 1, "targeting": "city",
		"description": "Ao golpear uma cidade num raide, rouba até 8 Ouro e recua. No máximo 2 Goblins por raide.",
		"ai": "raide de cidade (só no Despertar), depois descanso", "gold": 8.0, "max_raiders": 2,
	},
	RISING_HORDE: {
		"name": "Horda Crescente", "passive": true, "cooldown": 0, "min_range": 1, "max_range": 1, "targeting": "self",
		"description": "Ao matar uma unidade, ergue um novo Esqueleto ao lado (1 por covil por rodada, até 6 por covil). Ataca em grupo.",
		"ai": "agrupa 3+ antes de pressionar; evita luta claramente perdida", "per_round": 1, "site_cap": 6, "group_min": 3, "group_radius": 2,
	},
	BLOOD_SCENT: {
		"name": "Faro de Sangue", "passive": true, "cooldown": 0, "min_range": 1, "max_range": 1, "targeting": "unit",
		"description": "Caça unidades isoladas ou feridas: contra alvo isolado ganha +1 Movimento na perseguição e +25% de Ataque no primeiro golpe do turno. Nunca ataca cidades.",
		"ai": "prioriza alvo sem aliado adjacente ou com < 50% de Vida", "movement_bonus": 1.0, "attack_bonus": 0.25, "wounded_fraction": 0.5,
	},
	VENOMOUS_BITE: {
		"name": "Picada Venenosa", "passive": true, "cooldown": 0, "min_range": 1, "max_range": 1, "targeting": "unit",
		"description": "Golpe corpo a corpo envenena por 3 turnos (4% da Vida máxima por turno, 1–4). Não acumula; renova.",
		"ai": "em todo ataque corpo a corpo", "status": UnitStatusEffects.POISON, "turns": 3,
	},
	MONSTROUS_REGENERATION: {
		"name": "Regeneração Monstruosa", "passive": true, "cooldown": 0, "min_range": 0, "max_range": 0, "targeting": "self",
		"description": "No início do turno, se não sofreu dano desde o turno anterior, recupera 10% da Vida máxima.",
		"ai": "automática", "fraction": 0.1,
	},
	FLAME_BREATH: {
		"name": "Sopro Incendiário", "passive": false, "cooldown": 3, "min_range": 1, "max_range": 2, "targeting": "unit",
		"description": "Cone de fogo a até 2 tiles: alvo + até 2 tiles atrás dele (90% / 60% do dano) e Em Chamas por 2 turnos.",
		"ai": "quando atinge 2+ unidades, ou 1 de alto valor", "primary": 0.9, "secondary": 0.6, "status": UnitStatusEffects.BURNING, "turns": 2,
	},
	CHARGE: {
		"name": "Investida", "passive": false, "cooldown": 3, "min_range": 2, "max_range": 4, "targeting": "unit",
		"description": "Corre em linha reta 2–4 tiles até o alvo e golpeia com 150%; empurra 1 tile ou, se bloqueado, deixa Abalado.",
		"ai": "alvo a 2–4 tiles com linha livre", "multiplier": 1.5, "status": UnitStatusEffects.STAGGERED, "turns": 1,
	},
	PETRIFYING_GAZE: {
		"name": "Olhar Petrificante", "passive": false, "cooldown": 4, "min_range": 1, "max_range": 2, "targeting": "unit",
		"description": "Petrificação Parcial até o fim do próximo turno do alvo: Movimento 0 e −20% Defesa (ainda ataca).",
		"ai": "o alvo de maior Ataque ao alcance", "status": UnitStatusEffects.PETRIFIED, "turns": 1,
	},
	BURROW: {
		"name": "Escavar", "passive": false, "cooldown": 4, "min_range": 1, "max_range": 6, "targeting": "area",
		"description": "Mergulha sob a terra (intocável, deixa um Rastro Subterrâneo no destino) e emerge no turno seguinte: 120% no impacto, 80% ao redor.",
		"ai": "grupo de unidades a até 6 tiles", "impact": 1.2, "splash": 0.8,
	},
	ROOTS_OF_THE_WORLD: {
		"name": "Raízes do Mundo", "passive": false, "cooldown": 4, "min_range": 0, "max_range": 2, "targeting": "area",
		"description": "Ergue até 4 tiles de raízes a até 2 tiles (3 rodadas): +2 custo de movimento; quem estiver em cima fica Enraizado.",
		"ai": "unidade a até 2 tiles", "zones": 4, "rounds": 3, "move_cost": 2.0, "status": UnitStatusEffects.ROOTED, "turns": 1,
	},
	ARCANE_HUNGER: {
		"name": "Fome Arcana", "passive": true, "cooldown": 0, "min_range": 0, "max_range": 3, "targeting": "caster",
		"description": "Uma vez por rodada, o primeiro feitiço inimigo a até 3 tiles funciona normalmente, mas drena até 6 Mana do reino e vira Barreira Arcana (até 15% da Vida).",
		"ai": "automática", "mana": 6.0, "barrier_cap": 0.15,
	},
	AETHER_RUPTURE: {
		"name": "Ruptura Etérea", "passive": false, "cooldown": 4, "min_range": 1, "max_range": 2, "targeting": "caster",
		"description": "Dano mágico (80% do Ataque) a até 2 tiles; um conjurador atingido fica Silenciado por 1 turno.",
		"ai": "só contra conjurador", "multiplier": 0.8, "status": UnitStatusEffects.SILENCED, "turns": 1,
	},
	MYCOTIC_CONTAMINATION: {
		"name": "Contaminação Micótica", "passive": true, "cooldown": 0, "min_range": 0, "max_range": 2, "targeting": "area",
		"description": "Infecta o entorno (até raio 2, máx. 12 tiles, +1 por rodada): quem entra ou começa o turno ali perde 3% da Vida (1–3) e recebe só metade da cura.",
		"ai": "automática enquanto a Colmeia vive", "max_radius": 2, "max_tiles": 12, "damage_fraction": 0.03, "damage_min": 1.0, "damage_max": 3.0, "heal_multiplier": 0.5,
	},
}

static func get_ability(id: String) -> Dictionary:
	return ABILITIES.get(id, {})

static func param(id: String, key: String, fallback: Variant = 0.0) -> Variant:
	return (ABILITIES.get(id, {}) as Dictionary).get(key, fallback)

static func for_species(kind: String) -> Array[String]:
	var result: Array[String] = []
	for id in MonsterEcologyData.abilities(kind):
		result.append(String(id))
	return result

static func species_has(kind: String, id: String) -> bool:
	return id in MonsterEcologyData.abilities(kind)
