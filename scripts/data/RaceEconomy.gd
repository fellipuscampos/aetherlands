class_name RaceEconomy
extends RefCounted

## Identidade economica MODESTA por raca (roadmap de gameplay Fase 3 —
## decisao ja validada com o usuario: "bonus modestos de yield/
## crescimento", explicitamente NAO assimetria estrutural forte tipo
## "orc constroi predio mais devagar"). Reaproveita a lore ja escrita em
## GameSetupScreen.RACE_INFO em vez de inventar do zero:
## - Anao: "Liga dos Clas de Ferro... armas e minerios indispensaveis
##   para o comercio de TODAS as civilizacoes" -> bonus de ouro/producao
##   em Colinas e no recurso Ferro.
## - Elfo: "maestria inigualavel na Magia" -> bonus de mana e de ciencia.
## - Orc: "uma taxa de multiplicacao assustadora" + horda guerreira ->
##   bonus de producao e crescimento populacional mais rapido.
## - Humano: "compensam a falta de magia inata refinando taticas de
##   guerra" -> sem hook tematico especifico de yield, entao ganha um
##   bonus PEQUENO e parelho em tudo — baseline "sem graca" de proposito,
##   ainda assim mecanicamente relevante (nao fica pra tras so por nao
##   ter um nicho).
##
## Pontos de encaixe (cada um documentado no proprio chamador):
## - City.collect_yields() — mult ja existente pra dificuldade de IA
##   (owner_player.yield_multiplier) ganha esta MESMA logica de "segundo
##   multiplicador" por raca, sem reestruturar a funcao.
## - City.process_turn() — teto de comida pra crescer (food_storage_cap)
##   dividido pelo bonus de crescimento orc, ao inves de mexer no yield de
##   comida em si (mantém "bonus de yield" e "cresce mais rapido"
##   conceitualmente separados, cada um com seu proprio numero legivel).
## - GameManager._process_research() — mesma ideia pro multiplicador de
##   ciencia do elfo (ciencia nao passa por collect_yields, ver comentario
##   la sobre a pipeline paralela que este pass tambem unifica).

const DWARF_GOLD_PRODUCTION_BONUS := 1.10
const ELF_MANA_BONUS := 1.20
const ELF_SCIENCE_BONUS := 1.10
const ORC_PRODUCTION_BONUS := 1.10
const ORC_GROWTH_BONUS := 1.15 # ver growth_multiplier_for — divide o teto de comida, nao multiplica o yield
const HUMAN_ALL_YIELDS_BONUS := 1.05

const HILLS_TERRAIN_TYPES := [
	HexTileData.TerrainType.HILLS,
	HexTileData.TerrainType.VOLCANIC_HILLS,
]

## Aplica o bonus racial aos 4 totais de yield de UMA cidade, em cima do
## que ja foi calculado (multiplicativo, mesma convencao do multiplicador
## de dificuldade que ja existe ao lado). `worked_has_hills`/
## `worked_has_iron` sao passados pelo CHAMADOR (City.collect_yields ja
## percorre os tiles trabalhados de qualquer forma pra somar yield —
## calcular aqui de novo seria uma segunda varredura redundante).
static func apply_yield_bonus(totals: Dictionary, race: String, worked_has_hills: bool, worked_has_iron: bool) -> void:
	match race:
		"dwarf":
			if worked_has_hills or worked_has_iron:
				totals.gold *= DWARF_GOLD_PRODUCTION_BONUS
				totals.production *= DWARF_GOLD_PRODUCTION_BONUS
		"elf":
			totals.mana *= ELF_MANA_BONUS
		"orc":
			totals.production *= ORC_PRODUCTION_BONUS
		"human":
			totals.food *= HUMAN_ALL_YIELDS_BONUS
			totals.production *= HUMAN_ALL_YIELDS_BONUS
			totals.gold *= HUMAN_ALL_YIELDS_BONUS
			totals.mana *= HUMAN_ALL_YIELDS_BONUS

## Multiplicador de ciencia (GameManager._process_research) — so o elfo
## tem hook de ciencia, todo o resto fica em 1.0 (inclusive raca
## desconhecida/"").
static func science_multiplier_for(race: String) -> float:
	return ELF_SCIENCE_BONUS if race == "elf" else 1.0

## Divide o TETO de comida pra crescer (City.food_storage_cap()) — um
## numero menor enche mais rapido com o mesmo yield de comida, ou seja,
## "cresce mais rapido" sem tocar no yield de comida em si. So o orc tem
## hook de crescimento, todo o resto fica em 1.0 (divisor neutro).
static func growth_multiplier_for(race: String) -> float:
	return ORC_GROWTH_BONUS if race == "orc" else 1.0
