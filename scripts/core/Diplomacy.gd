class_name Diplomacy
extends RefCounted

## Diplomacia bem simples de proposito: cada PlayerData guarda quem
## considera inimigo (PlayerData.enemies). Civs rivais nunca declaram
## guerra ENTRE SI nem propoem paz sozinhas (fora do escopo desta rodada:
## uma guerra de todos contra todos seria bem mais dificil de acompanhar e
## balancear) — so o jogador humano propoe paz ativamente pela HUD. Por
## padrao, GameManager.setup_players() comeca todo mundo em PAZ (mudanca
## posterior — antes o humano nascia automaticamente em guerra com todo
## rival); desde o roadmap de gameplay Fase 1, RivalAI.decide_war() pode
## fazer um rival declarar guerra sozinho contra o humano quando a
## avaliacao de oportunidade (forca relativa, proximidade, vulnerabilidade
## do alvo) justificar — o humano continua sendo o unico que PROPOE paz.
##
## Sem negociacao de termos (sem tributo, cessao de territorio, alianca):
## so guerra/paz, e a IA aceita ou recusa uma proposta de paz com uma
## heuristica bem direta (ver _accepts_peace).

static func declare_war(a: PlayerData, b: PlayerData) -> void:
	a.enemies[b] = true
	b.enemies[a] = true

## `proposer` costuma ser o jogador humano; `other` o rival sendo
## abordado. Retorna true (e ja aplica a paz nos dois lados) se aceita.
## Se os dois ja estao em paz, conta como sucesso trivial.
static func propose_peace(proposer: PlayerData, other: PlayerData) -> bool:
	if not proposer.is_at_war_with(other):
		return true
	if not _accepts_peace(other, proposer):
		return false
	proposer.enemies.erase(other)
	other.enemies.erase(proposer)
	return true

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
