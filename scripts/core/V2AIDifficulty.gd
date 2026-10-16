class_name V2AIDifficulty
extends RefCounted

## Dificuldade das IAs (2026-10-15) — pedido do usuário: "um único nível de inteligência que pode receber fácil,
## e deixar tudo mais leve pra ela, normal pra nenhum buff ou debuff e difícil, deixando tudo mais caro pra ela".
##
## A INTELIGÊNCIA nunca muda: as mesmas decisões de RivalAI/V2StrategicAI/V2AITacticalAI rodam nos três níveis.
## O nível só multiplica a ECONOMIA das civilizações rivais (Ouro, Mana, Conhecimento e Produção por turno), então
## tudo leva mais ou menos turnos para ela: pesquisa, tropas, prédios, feitiços, melhorias. Os nomes descrevem a
## vida DA IA, como o usuário pediu: "Fácil" = tudo mais leve para a IA (rivais mais fortes para você); "Difícil" =
## tudo mais caro para a IA (rivais mais fracos). Suprimentos (capacidade, não renda), o jogador humano e qualquer
## PlayerData fora de GameManager.rival_players (testes, laboratório no assento humano) nunca são tocados.
##
## O valor vive em GameManager.difficulty ("easy"/"normal"/"hard"), escolhido na tela de nova partida e salvo
## desde sempre no save (SaveManager); um save antigo sem o campo carrega "normal".

const EASY := "easy"
const NORMAL := "normal"
const HARD := "hard"
const LEVELS: Array[String] = [EASY, NORMAL, HARD]

## Multiplicador da renda da IA por nível. ±25%: dá para sentir em poucas dezenas de turnos sem desmontar o ritmo
## de 3–4 h do Balance Pass de 2026-10-14 (uma pesquisa de 20 turnos vira 16 no Fácil e ~27 no Difícil).
const ECONOMY_MULTIPLIER := {EASY: 1.25, NORMAL: 1.0, HARD: 0.75}

const LABELS := {EASY: "Fácil", NORMAL: "Normal", HARD: "Difícil"}
const DESCRIPTIONS := {
	EASY: "Tudo mais leve para as IAs: +25% de Ouro, Mana, Conhecimento e Produção. Rivais crescem mais rápido.",
	NORMAL: "Sem bônus nem penalidade: as IAs jogam com a mesma economia que você.",
	HARD: "Tudo mais caro para as IAs: −25% de Ouro, Mana, Conhecimento e Produção. Rivais crescem mais devagar.",
}

static func normalized(level: String) -> String:
	return level if level in LEVELS else NORMAL

static func current_level() -> String:
	return normalized(GameManager.difficulty)

## Multiplicador da renda de `player` — 1.0 para quem não é rival controlado pela IA.
static func economy_multiplier(player: PlayerData) -> float:
	if player == null or player == GameManager.human_player or not GameManager.rival_players.has(player):
		return 1.0
	return float(ECONOMY_MULTIPLIER[current_level()])

static func label(level: String) -> String:
	return String(LABELS[normalized(level)])

static func description(level: String) -> String:
	return String(DESCRIPTIONS[normalized(level)])
