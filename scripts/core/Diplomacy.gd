class_name Diplomacy
extends RefCounted

## Relações simétricas entre quaisquer civilizações. A IA pode declarar
## guerra, propor paz e negociar comércio com o humano e com outros rivais.
## Paz aceita inicia trégua; motivos e cansaço aparecem na interface.
## Não há negociação de tributos, cessão de território ou alianças.

const TRUCE_TURNS := 10

static func truce_remaining(a: PlayerData, b: PlayerData) -> int:
	return maxi(0, int(a.truces.get(b, 0)) - TurnManager.turn_number)

static func can_declare_war(a: PlayerData, b: PlayerData) -> bool:
	return a != b and truce_remaining(a, b) == 0 and truce_remaining(b, a) == 0

static func declare_war(a: PlayerData, b: PlayerData, reason: String = "Disputa territorial") -> void:
	if not can_declare_war(a, b):
		return
	a.enemies[b] = true
	b.enemies[a] = true
	a.war_reasons[b] = reason
	b.war_reasons[a] = reason

## `proposer` costuma ser o jogador humano; `other` o rival sendo
## abordado. Retorna true (e ja aplica a paz nos dois lados) se aceita.
## Se os dois ja estao em paz, conta como sucesso trivial.
## Roadmap "Parte E" E1 -- UNICO ponto de entrada que encerra guerra: por
## isso e aqui (e nao em HUD.gd nem em RivalAI.decide_peace, os dois
## chamadores) que RivalAI.end_campaigns_on_peace roda, cobrindo humano->
## rival e rival->humano sem duplicar a logica em nenhum dos dois. Diplomacy
## de proposito NAO sabe o formato de war_campaigns (isso pertence ao
## sistema de campanha, C3/C4) -- so chama o helper e segue.
static func propose_peace(proposer: PlayerData, other: PlayerData) -> bool:
	if not proposer.is_at_war_with(other):
		return true
	if not _accepts_peace(other, proposer):
		return false
	proposer.enemies.erase(other)
	other.enemies.erase(proposer)
	proposer.truces[other] = TurnManager.turn_number + TRUCE_TURNS
	other.truces[proposer] = TurnManager.turn_number + TRUCE_TURNS
	RivalAI.end_campaigns_on_peace(proposer, other)
	return true

static func relation_description(a: PlayerData, b: PlayerData) -> String:
	if a.is_at_war_with(b):
		return "%s. Cansaço: %d/100; aceita paz com desvantagem numérica ou cansaço ≥ 40." % [a.war_reasons.get(b, "Disputa territorial"), int(b.war_weariness)]
	var truce := truce_remaining(a, b)
	return "Em paz. Trégua: %d turnos." % truce if truce > 0 else "Em paz."

## Aceita se estiver em desvantagem numerica (menos unidades que quem
## propos) ou sem exercito nenhum — uma IA "perdendo" a guerra faz as
## pazes, uma IA "ganhando" ou empatada prefere continuar brigando. Desde
## a Fase 2 do roadmap, TAMBEM aceita se estiver muito cansada de guerra
## (war_weariness), independente de quem esta "ganhando" numericamente —
## uma guerra arrastada demais cansa mesmo o lado mais forte.
static func _accepts_peace(ai_player: PlayerData, proposer: PlayerData) -> bool:
	return ai_player.units.size() <= proposer.units.size() or ai_player.war_weariness >= WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD

## Cansaco de guerra e manutencao de ouro em guerra (roadmap de gameplay
## Fase 2) — pedido do usuario: "guerra custando ouro... nunca gera
## divida nem bloqueia nada, so trava em gold=0" (primeiro *sink* de ouro
## alem do rush-buy). Cresce/decai por PLAYER inteiro (esta em guerra com
## QUALQUER rival conta), nao por par — simplificacao deliberada, igual a
## de _military_deficit em RivalAI.gd, pra manter o numero explicavel numa
## frase so.
const WAR_WEARINESS_GAIN_PER_TURN := 1.0
const WAR_WEARINESS_DECAY_PER_TURN := 2.0 # decai MAIS RAPIDO que cresce: um conflito breve nao deixa cicatriz permanente
const WAR_WEARINESS_MAX := 100.0
const WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD := 40.0
const WAR_UPKEEP_GOLD_PER_MILITARY_UNIT := 0.5

static func process_war_weariness_and_upkeep(player: PlayerData) -> void:
	if player.enemies.is_empty():
		player.war_weariness = max(player.war_weariness - WAR_WEARINESS_DECAY_PER_TURN, 0.0)
		return
	player.war_weariness = min(player.war_weariness + WAR_WEARINESS_GAIN_PER_TURN, WAR_WEARINESS_MAX)
	var military_units := 0
	for unit in player.units:
		if unit.unit_data.attack > 0.0:
			military_units += 1
	var upkeep := military_units * WAR_UPKEEP_GOLD_PER_MILITARY_UNIT
	# max(0.0, ...) de proposito (pedido do usuario): sink puro, NUNCA
	# divida — sem ouro suficiente, so nao paga o resto, sem punicao extra
	# nenhuma (sem perder unidade, sem bloquear producao/combate).
	player.gold = max(0.0, player.gold - upkeep)
