class_name WorldPhaseRules
extends RefCounted

## Fase 33D1 — regras PURAS das três eras do mundo (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md,
## seções 4–5). Recebe o estado da partida e responde se a era deve avançar; não guarda estado, não fala
## com UI, não salva e não roda por frame. O dono do estado é o WorldEventManager, que chama
## next_transition() uma vez por rodada global.
##
## A era governa só o ritmo do mundo: nenhum bônus de dano/Ouro/Produção/pesquisa, nenhum unlock.

enum Phase { FOUNDATION, ASCENSION, CONVERGENCE }

const CAUSE_INITIAL := "INITIAL"
const CAUSE_PROGRESS := "PROGRESS"
const CAUSE_FALLBACK := "FALLBACK"
const CAUSE_MIGRATED := "MIGRATED"

## Despertar → Ascensão: a partir do piso, quando MAJORITY_REQUIRED civs ativas têm >= 2 cidades.
const ASCENSION_FLOOR_TURN := 35
const ASCENSION_FALLBACK_TURN := 70
const ASCENSION_MIN_CITIES := 2
## Ascensão → Convergência: a partir do piso, quando MAJORITY_REQUIRED civs ativas têm um N9 (qualquer
## árvore) OU uma civ ativa concluiu um capstone de vitória (Exército Supremo/Transcendência).
const CONVERGENCE_FLOOR_TURN := 100
const CONVERGENCE_FALLBACK_TURN := 150
## "2 civs" e não "a primeira": uma civ adiantada não arrasta o mundo. Com só 2 ativas, ambas.
const MAJORITY_REQUIRED := 2

const DISPLAY_NAMES := {
	Phase.FOUNDATION: "Era do Despertar",
	Phase.ASCENSION: "Era da Ascensão",
	Phase.CONVERGENCE: "Era da Convergência",
}
const SHORT_NAMES := {
	Phase.FOUNDATION: "Despertar",
	Phase.ASCENSION: "Ascensão",
	Phase.CONVERGENCE: "Convergência",
}
const ID_NAMES := {
	Phase.FOUNDATION: "FOUNDATION",
	Phase.ASCENSION: "ASCENSION",
	Phase.CONVERGENCE: "CONVERGENCE",
}

static var _n9_ids: Array[String] = []

static func display_name(phase: int) -> String:
	return String(DISPLAY_NAMES.get(phase, DISPLAY_NAMES[Phase.FOUNDATION]))

static func short_name(phase: int) -> String:
	return String(SHORT_NAMES.get(phase, SHORT_NAMES[Phase.FOUNDATION]))

static func id_name(phase: int) -> String:
	return String(ID_NAMES.get(phase, "FOUNDATION"))

static func is_valid_phase(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and int(value) in [Phase.FOUNDATION, Phase.ASCENSION, Phase.CONVERGENCE] and float(value) == floor(float(value))

## Civilizações ativas pela definição canônica de eliminação (sem unidades e sem cidades).
static func active_players(players: Array) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player in players:
		if player != null and not V2VictoryConditions.is_eliminated(player):
			result.append(player)
	return result

static func required_count(active_count: int) -> int:
	return clampi(active_count, 1, MAJORITY_REQUIRED)

## Os 12 nós N9 das árvores de Doutrina e Escola (capstones não contam como N9).
static func n9_ids() -> Array[String]:
	if _n9_ids.is_empty():
		for tree in [V2ResearchNode.TreeType.MILITARY_DOCTRINE, V2ResearchNode.TreeType.MAGIC_SCHOOL]:
			for node in V2ResearchDatabase.nodes_for_tree(tree):
				if node.tier == 9 and not node.is_universal:
					_n9_ids.append(node.id)
	return _n9_ids

static func has_n9(player: PlayerData) -> bool:
	for id in n9_ids():
		if player.v2_research.is_completed(id):
			return true
	return false

static func has_victory_capstone(player: PlayerData) -> bool:
	return player.v2_research.is_completed(V2ResearchDatabase.SUPREME_ARMY_ID) or player.v2_research.is_completed(V2ResearchDatabase.TRANSCENDENCE_ID)

## Próximo passo a partir de `phase` neste `turn`: {} se a era não muda, senão {"phase", "cause"}.
## Avança no máximo UMA era por chamada; nunca regride.
static func next_transition(phase: int, turn: int, players: Array) -> Dictionary:
	var active := active_players(players)
	var required := required_count(active.size())
	match phase:
		Phase.FOUNDATION:
			if turn < ASCENSION_FLOOR_TURN:
				return {}
			var expanded := 0
			for player in active:
				if player.cities.size() >= ASCENSION_MIN_CITIES:
					expanded += 1
			if expanded >= required:
				return {"phase": Phase.ASCENSION, "cause": CAUSE_PROGRESS}
			if turn >= ASCENSION_FALLBACK_TURN:
				return {"phase": Phase.ASCENSION, "cause": CAUSE_FALLBACK}
		Phase.ASCENSION:
			if turn < CONVERGENCE_FLOOR_TURN:
				return {}
			var with_n9 := 0
			for player in active:
				if has_victory_capstone(player):
					return {"phase": Phase.CONVERGENCE, "cause": CAUSE_PROGRESS}
				if has_n9(player):
					with_n9 += 1
			if with_n9 >= required:
				return {"phase": Phase.CONVERGENCE, "cause": CAUSE_PROGRESS}
			if turn >= CONVERGENCE_FALLBACK_TURN:
				return {"phase": Phase.CONVERGENCE, "cause": CAUSE_FALLBACK}
	return {}

## Era mais avançada justificável pelo estado atual (migração de save antigo sem era). Aplica as mesmas
## regras em sequência, sem emitir nada.
static func reconstruct(turn: int, players: Array) -> int:
	var phase := Phase.FOUNDATION
	for step in 2:
		var transition := next_transition(phase, turn, players)
		if transition.is_empty():
			break
		phase = int(transition.phase)
	return phase
