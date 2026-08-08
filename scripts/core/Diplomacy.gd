class_name Diplomacy
extends RefCounted

## Diplomacia bem simples de proposito: cada PlayerData guarda quem
## considera inimigo (PlayerData.enemies). So o jogador humano negocia
## ativamente pela HUD — civs rivais nunca declaram guerra entre si nem
## propoem paz sozinhas (fora do escopo desta rodada: uma guerra de todos
## contra todos seria bem mais dificil de acompanhar e balancear). Por
## padrao, GameManager.setup_players() coloca o humano em guerra com todo
## rival — mesmo comportamento de sempre, so que agora reversivel.
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
## pazes, uma IA "ganhando" ou empatada prefere continuar brigando.
static func _accepts_peace(ai_player: PlayerData, proposer: PlayerData) -> bool:
	return ai_player.units.size() <= proposer.units.size()
