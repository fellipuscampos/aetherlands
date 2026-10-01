class_name V2ResearchAccess
extends RefCounted

## V3 / Etapa 2 — regra ÚNICA de "esta civilização pode INICIAR/TROCAR de pesquisa agora": só depois de
## possuir pelo menos uma cidade (`player.cities`, a fonte canônica de posse). A primeira cidade é o momento
## em que o reino começa a se desenvolver.
##
## Onde vale: em todo caminho que ESCOLHE pesquisa — Research Board (humano) e V2StrategicAI (IA) — e em
## toda superfície que convida a escolher (widget global, Attention). V2ResearchState continua um modelo puro
## por civilização (sem saber de cidades); o gate fica na camada de decisão, a mesma para humano e IA.
##
## Não muda Conhecimento, custos, árvore, slot único nem timings. Uma pesquisa já ativa NÃO é cancelada se a
## civilização perder todas as cidades: o Conhecimento só vem de cidades, então ela apenas para de progredir;
## sem cidade a civilização só não pode iniciar nem trocar de projeto (pausar continua permitido).

const REASON_REQUIRES_CITY := "Funde sua primeira cidade para iniciar uma pesquisa."
const STATE_LABEL_REQUIRES_CITY := "Requer uma cidade"

## "" = pode iniciar/trocar; senão o motivo player-facing.
static func start_blocked_reason(player) -> String:
	if player == null:
		return ""
	return REASON_REQUIRES_CITY if player.cities.is_empty() else ""

static func can_start(player) -> bool:
	return start_blocked_reason(player) == ""

## Dono do estado de pesquisa (o Research Board só conhece o V2ResearchState).
static func owner_of(state: V2ResearchState) -> PlayerData:
	if state == null:
		return null
	for player in GameManager.players:
		if player != null and player.v2_research == state:
			return player
	return null

static func state_blocked_reason(state: V2ResearchState) -> String:
	return start_blocked_reason(owner_of(state))
