class_name PlayerData
extends RefCounted

## Estado de jogo de uma civilizacao (jogador humano ou rival). Diferente de
## CivilizationData (Resource estatico com nome/cor), isto guarda estado que
## muda durante a partida: tesouro, unidades e cidades vivas.

var civ: CivilizationData

## Personalidade civilizacional (Roadmap Parte B, B4) — eixo
## (CityIdentity.AXIS_*) -> forca 0.0-1.0, sorteada UMA VEZ por
## GameManager.setup_players() (ver CivilizationPersonality.generate) e
## depois estavel a partida inteira — diferente de CityIdentity.
## civilization_axis_strength(), que e recalculada toda chamada a partir de
## City.buildings. NUNCA serializada em SaveManager.gd de proposito: e
## re-derivada de HexGrid.map_seed toda vez que setup_players() roda (jogo
## novo OU load), ver comentario de topo de CivilizationPersonality.gd.
## Dicionario vazio == sem personalidade ainda gerada (nunca acontece em
## jogo real pos-setup_players, mas e o estado de todo PlayerData de teste
## construido direto via PlayerData.new(...), mesma convencao de "" em
## CityIdentity.dominant_axis() pra "generalista/sem sinal").
var personality: Dictionary = {} # String (CityIdentity.AXIS_*) -> float

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

## Cansaco de guerra (roadmap de gameplay Fase 2, ver
## Diplomacy.process_war_weariness_and_upkeep) — cresce enquanto em guerra
## com alguem, decai em paz total. Alimenta Diplomacy._accepts_peace (quem
## esta mais cansado aceita paz mais facil) alem da propria contagem crua
## de unidades que ja existia.
var war_weariness: float = 0.0

## Memoria PERSISTENTE do objetivo de guerra contra `opponent` (Roadmap
## "Parte C", C3) -- diferente de RivalAI._best_war_objective (C2), sempre
## TRANSIENTE. Ausencia de chave == nenhuma campanha. So RivalAI escreve
## aqui (decide_campaign) -- so rivais chamam isso, sempre contra
## human_player (Diplomacy.gd: rivais nunca guerreiam entre si). Cada
## entrada tem 3 campos: "objective" (String), "target_coord" (Vector2i,
## nunca referencia a City -- ver comentario de RivalAI._advance_campaign),
## "status" (RivalAI.CAMPAIGN_STATUS_*).
var war_campaigns: Dictionary = {} # PlayerData (opponent) -> Dictionary

## Rotas de comercio ativas que este jogador participa (roadmap de
## gameplay Fase 4A, ver TradeManager.gd/TradeRoute.gd) — cada TradeRoute
## aparece nesta lista PROS DOIS lados envolvidos (mesmo objeto
## compartilhado por referencia, nao duplicado).
var trade_routes: Array[TradeRoute] = []

## Roadmap "Fase F" F1/F2 -- estado persistente das duas vitorias
## alternativas de SUSTENTACAO (Dominacao nao precisa de estado novo: e so
## ausencia de units/cities de todo rival, ja coberto por
## GameManager.check_game_over). Os dois streaks sao HISTORICO acumulado
## (turnos consecutivos), atualizados UMA vez por turno real -- nunca na
## chamada extra de check_game_over que roda logo apos um ataque do
## jogador humano, que so DETECTA uma vitoria ja atingida sem avancar
## tempo (F2, ponto explicito do usuario: duas cadencias de chamada nao
## podem incrementar o streak duas vezes no mesmo turno).
const NO_RITUAL_CITY_COORD := Vector2i(999999, 999999) # mesmo padrao de City.NO_PENDING_COORD/SelectionManager._hovered_coord -- Vector2i nao tem null

## Turnos consecutivos com territorio >= X% do mundo habitavel (Dominio
## Territorial) -- zera assim que o percentual cai abaixo do limiar em
## qualquer turno (nenhuma pausa/reserva de progresso, decisao de F1).
var territorial_streak: int = 0

## Ritual do Nodulo (Ascensao Arcana): `arcane_ritual_active` vira true
## quando o custo INICIAL de mana e pago (sustentacao comeca a contar
## dali). `arcane_ritual_city_coord` aponta pra cidade-sede por
## COORDENADA, nunca referencia de City (MESMO principio de
## war_campaigns.target_coord acima, decisao explicita de F2) -- resolver
## a cidade atual naquele coord na hora de verificar deixa captura/
## destruicao invalidar o ritual naturalmente, sem precisar de um sinal
## separado de "cidade perdida". `arcane_ritual_streak` e turnos
## consecutivos sustentados desde a ativacao -- zera se a cidade-sede cai
## OU os Nodulos controlados ficam abaixo de 3 (decisao de F1).
var arcane_ritual_active: bool = false
var arcane_ritual_city_coord: Vector2i = NO_RITUAL_CITY_COORD
var arcane_ritual_streak: int = 0

func _init(civ_data: CivilizationData) -> void:
	civ = civ_data

func has_unlocked(kind: String) -> bool:
	return TechDatabase.is_unit_unlocked(kind, researched_techs)

func is_at_war_with(other: PlayerData) -> bool:
	return enemies.has(other)
