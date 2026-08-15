class_name PlayerData
extends RefCounted

## Estado de jogo de uma civilizacao (jogador humano ou rival). Diferente de
## CivilizationData (Resource estatico com nome/cor), isto guarda estado que
## muda durante a partida: tesouro, unidades e cidades vivas.

var civ: CivilizationData
var gold: float = 0.0

## Economia arcana (Ponto 3): saldo gasto pra conjurar feiticos do Grimorio
## (ver SpellManager.gd) — cresce todo turno com o mana rendido pelas
## cidades (Nodulo Arcano trabalhado + predios como a Torre dos Sabios, ver
## City.collect_yields), mesmo padrao de `gold` acima. mana_income_per_turn
## e so o ULTIMO valor calculado (nao acumula) — puramente informativo pra
## HUD mostrar "Mana: X (+Y)" sem precisar recalcular a soma de todas as
## cidades toda vez que a barra superior redesenha.
var mana: float = 0.0
var mana_income_per_turn: float = 0.0

var units: Array[Unit] = []
var cities: Array[City] = []

## Multiplicador de rendimento de tile aplicado em City.collect_yields() —
## so difere de 1.0 pra rivais, de acordo com a dificuldade escolhida na
## tela de titulo (GameManager.DIFFICULTY_MULTIPLIERS). O jogador humano
## fica sempre em 1.0, dificuldade so afeta a economia da IA.
var yield_multiplier: float = 1.0

## Memoria de fog of war: coords de cidade inimiga ja escoutadas ao menos
## uma vez. Cidade nao anda, entao continua sendo um alvo valido pra
## RivalAI mesmo fora da visao atual — diferente de unidades inimigas, que
## so contam se estiverem VISIVEIS agora (ver HexGrid.compute_visible_tiles
## e RivalAI._choose_target). So a IA rival usa isso por enquanto.
var known_enemy_cities: Dictionary = {} # Vector2i -> true

## Arvore de tecnologia (ver TechDatabase). research_progress acumula
## "ciencia" (soma da populacao das cidades por turno — GameManager) ate
## bater o custo de current_research; so entao entra em researched_techs e
## current_research volta a "" pra escolher a proxima.
var researched_techs: Dictionary = {} # id -> true
var current_research: String = ""
var research_progress: float = 0.0

## Recarga de feiticos/rituais (ver SpellDatabase/SpellManager): nome do
## feitico -> numero do turno em que volta a ficar disponivel. Ausencia da
## chave == disponivel agora (nunca conjurado, ou recarga ja passou e
## nunca foi limpa — SpellManager.can_cast compara direto contra o turno
## atual em vez de precisar "expirar" a entrada).
var spell_cooldowns: Dictionary = {} # String -> int

## Diplomacia (ver Diplomacy.gd): presenca de `other` aqui significa "em
## guerra com other" — ausencia significa paz. Simetrico por construcao
## (Diplomacy sempre atualiza os dois lados juntos), nunca deve ser
## mutado direto fora dali.
var enemies: Dictionary = {} # PlayerData -> true

func _init(civ_data: CivilizationData) -> void:
	civ = civ_data

func has_unlocked(kind: String) -> bool:
	return TechDatabase.is_unit_unlocked(kind, researched_techs)

func is_at_war_with(other: PlayerData) -> bool:
	return enemies.has(other)
