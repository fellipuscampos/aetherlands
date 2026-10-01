class_name BalanceSeedSet
extends RefCounted

## Fase 33B — conjunto VERSIONADO de partidas do Release Balance Lab. Nada aqui é sorteado em tempo
## de execução: a partida `i` é sempre a mesma (seed de mapa, raça por assento, orientação por
## assento), então F33B e F33C comparam exatamente as mesmas configurações.
##
## Assento = índice em GameManager.players = índice de spawn. O assento 0 é o `human_player` formal
## (spawn perto do centro do continente Principal); os assentos 1–3 são os rivais, espalhados em
## ângulos iguais (GameManager._rival_origin). Por isso raça e orientação giram pelos assentos.

const BASELINE_ID := "RELEASE_BALANCE_BASELINE_PRE_TUNING"
const SEED_SET_VERSION := "phase33b-v2"

## Mapa real da partida normal (TitleScreen.MAP_SIZES.large) e 3 rivais — o setup máximo do jogo.
const MAP_WIDTH := 320
const MAP_HEIGHT := 84
const RIVAL_COUNT := 3

const TURN_CAP := 240
const EXTENDED_TURN_CAP := 300

const RACES := ["human", "elf", "dwarf", "orc"]

## 48 seeds da amostra-alvo (Stage 1 = primeiras 12, Stage 2 = primeiras 24, Stage 3 = 48).
## As 16 reservas existem para a validação final de 100+ partidas da F33C sem reescrever a lista.
##
## PARIDADE BALANCEADA (v2): V2AIStrategyState deriva strategy_seed de (seed do mapa, índice) e a IA
## BALANCED usa posmod(strategy_seed, 2) como foco-reserva no T45 — a paridade da seed decide
## Supremacia × Transcendência junto com a paridade do assento. A lista v1 (só ímpares) acoplava o
## foco-reserva ao assento (assentos 0/2 sempre Supremacia, 1/3 sempre Transcendência) e foi
## invalidada. Agora paridade(seed_i) = ((i % 12) + (i / 12)) % 2: cada configuração do ciclo de 12
## aparece 2× com seed par e 2× com ímpar, e cada estágio (12/24/48) tem metade de cada paridade.
const SEEDS: Array[int] = [
	33102, 33109, 33116, 33123, 33130, 33137, 33144, 33151, 33158, 33165, 33172, 33179,
	33185, 33192, 33199, 33206, 33213, 33220, 33227, 33234, 33241, 33248, 33255, 33262,
	33268, 33275, 33282, 33289, 33296, 33303, 33310, 33317, 33324, 33331, 33338, 33345,
	33351, 33358, 33365, 33372, 33379, 33386, 33393, 33400, 33407, 33414, 33421, 33428,
]
const RESERVE_SEEDS: Array[int] = [
	33434, 33441, 33448, 33455, 33462, 33469, 33476, 33483, 33490, 33497, 33504, 33511,
	33517, 33524, 33531, 33538,
]

## Orientação por assento, ciclo de 12 (combinado com o giro de raças de período 4). Em cada ciclo:
## cada assento recebe MILITARY/ARCANE/BALANCED 4× cada; cada raça também 4× cada; a orientação
## repetida é cada uma das três 4×; e o par de assentos que compartilha orientação varia (máx. 2×
## por par). Gerado por busca exaustiva e congelado aqui — nunca derivado da raça.
const ORIENTATION_TEMPLATES := [
	"MBAB", "AMAB", "AAMB", "BAMM", "AAMB", "MBAM",
	"BMAM", "AMBA", "BAMM", "MBBA", "BMBA", "MBBA",
]

static func all_seeds() -> Array[int]:
	var result: Array[int] = []
	result.append_array(SEEDS)
	result.append_array(RESERVE_SEEDS)
	return result

static func match_count() -> int:
	return all_seeds().size()

## Raças por assento na partida `index`: giro de período 4 (cada raça passa por cada assento).
static func races_for(index: int) -> Array[String]:
	var result: Array[String] = []
	for seat in 4:
		result.append(RACES[posmod(seat + index, 4)])
	return result

static func orientations_for(index: int) -> Array[int]:
	var template: String = ORIENTATION_TEMPLATES[posmod(index, ORIENTATION_TEMPLATES.size())]
	var result: Array[int] = []
	for letter in template:
		match letter:
			"M":
				result.append(V2AIStrategyState.Orientation.MILITARY)
			"A":
				result.append(V2AIStrategyState.Orientation.ARCANE)
			_:
				result.append(V2AIStrategyState.Orientation.BALANCED)
	return result

## Configuração completa e serializável da partida `index` (0-based).
static func match_config(index: int, turn_cap: int = TURN_CAP) -> Dictionary:
	var seeds := all_seeds()
	var orientations := orientations_for(index)
	var orientation_names: Array[String] = []
	for value in orientations:
		orientation_names.append(V2AIStrategyState.orientation_name(value))
	return {
		"match_id": "F33B-%03d" % (index + 1),
		"index": index,
		"seed": seeds[index],
		"races": races_for(index),
		"orientations": orientation_names,
		"orientation_template": ORIENTATION_TEMPLATES[posmod(index, ORIENTATION_TEMPLATES.size())],
		"map_width": MAP_WIDTH,
		"map_height": MAP_HEIGHT,
		"rival_count": RIVAL_COUNT,
		"turn_cap": turn_cap,
		"baseline_id": BASELINE_ID,
		"seed_set_version": SEED_SET_VERSION,
	}
