class_name PlayerData
extends RefCounted

## Estado de jogo de uma civilizacao (jogador humano ou rival). Diferente de
## CivilizationData (Resource estatico com nome/cor), isto guarda estado que
## muda durante a partida: tesouro, unidades e cidades vivas.

var civ: CivilizationData

var gold: float = 0.0

## Mana: gasta em feitiços V2 e na produção de Grandes Manifestações; creditada uma vez por turno
## por V2EconomyRuntime.apply_turn_income (Santuários Arcanos, Conduítes, base por cidade).
## mana_income_per_turn é só o ÚLTIMO valor creditado (informativo, não acumula).
var mana: float = 0.0
var mana_income_per_turn: float = 0.0

var units: Array[Unit] = []
var cities: Array[City] = []

## Memoria de fog of war: coords de cidade inimiga ja escoutadas ao menos
## uma vez. Cidade nao anda, entao continua sendo um alvo valido pra
## RivalAI mesmo fora da visao atual — diferente de unidades inimigas, que
## so contam se estiverem VISIVEIS agora (ver HexGrid.compute_visible_tiles
## e RivalAI._choose_target). So a IA rival usa isso por enquanto.
var known_enemy_cities: Dictionary = {} # Vector2i -> true
var explored_tiles: Dictionary = {} # conhecimento individual da IA
## Task 22 -- IA: ate que turno nao adianta procurar local de cidade de novo (ver RivalAI._has_settle_site). Estado de sessao, nao salvo.
var settle_search_blocked_until: int = -1

## Pesquisa desta civilização (um projeto ativo, concluídos, progresso por nó, overflow de
## Conhecimento) — ver V2ResearchState. É a ÚNICA progressão do jogo desde a Fase 25 (a pesquisa
## Tecnologia/Magia V1 foi removida). Persistido pelo SaveManager no bloco "v2_research".
var v2_research: V2ResearchState = V2ResearchState.new()
## Fase 3: reage a v2_research.research_completed e aplica os unlocks conectados
## (V2UnlockSystem). Sem estado próprio de jogo: a disponibilidade é derivada de
## v2_research, então nada aqui entra no save.
var v2_unlocks: V2UnlockSystem = V2UnlockSystem.new(v2_research)
## Fase 23: estado mínimo do Ritual Final. Só V2TranscendenceSystem muta este
## dicionário; referências de City/Unit e requisitos nunca são persistidos.
var v2_transcendence_ritual: Dictionary = {}
## Fase 24: personalidade/memória estratégica da IA V2. O objeto existe em
## todos os PlayerData para manter o tipo simples, mas só rivais major são
## inicializados e executados por V2StrategicAI.
var v2_ai_strategy: V2AIStrategyState = V2AIStrategyState.new()

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

## Remove os ciclos PlayerData -> inimigo/campanha -> PlayerData ao encerrar.
func release_relations() -> void:
	enemies.clear()
	war_campaigns.clear()
	truces.clear()
	war_reasons.clear()

var ai_rng := RandomNumberGenerator.new()
var truces: Dictionary = {} # PlayerData -> primeiro turno em que guerra volta a ser permitida
var war_reasons: Dictionary = {} # PlayerData -> motivo público

func _init(civ_data: CivilizationData) -> void:
	civ = civ_data
	v2_unlocks.unlock_applied.connect(_on_v2_unlock_applied)
	v2_research.state_reset.connect(_on_v2_research_state_reset)

func _on_v2_research_state_reset() -> void:
	# load_dict também emite state_reset, mas SaveManager limpa o estado antes de
	# reconstruí-lo; sem ritual ativo isto é um no-op e não gera toast falso.
	if not v2_transcendence_ritual.is_empty():
		V2TranscendenceSystem.validate_active_ritual(self)

## Um unlock V2 conectado acabou de valer pra esta civilização: avisa a HUD (toast +
## atualização do painel de cidade) via EventBus — só pro jogador humano.
func _on_v2_unlock_applied(_node_id: String, unlock_type: String, unlock_id: String) -> void:
	if GameManager.human_player != self:
		return
	var node := V2UnlockSystem.node_for_unlock(unlock_id)
	if node == null:
		return
	EventBus.notify.emit(V2UnlockSystem.announcement_text(unlock_type, node.display_name, unlock_id), "confirm")
	EventBus.v2_unlock_applied.emit(self, unlock_type, unlock_id)

## `kind` (unidade) ou unlock id V2 liberado para esta civilização. Unidade/unlock V2 é liberado pela
## pesquisa V2 (fail-closed); fora da V2 só o núcleo civil compartilhado (UnitDatabase.
## CORE_TRAINABLE_KINDS — o Colonizador) está sempre liberado. Fase 25: não existe gate V1.
func has_unlocked(kind: String) -> bool:
	if V2ResearchDatabase.is_v2_id(kind):
		return V2UnlockSystem.is_unit_unlocked(self, kind)
	return kind in UnitDatabase.CORE_TRAINABLE_KINDS

func is_at_war_with(other: PlayerData) -> bool:
	return enemies.has(other)
