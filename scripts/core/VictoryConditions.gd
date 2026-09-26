class_name VictoryConditions
extends RefCounted

## Dominação — a condição de vitória fundamental: última civilização major restante. Continua como
## uma das três vitórias finais da Aetherlands ao lado da Supremacia Militar e da Transcendência (as
## duas em V2VictoryConditions); a precedência entre as três fica em GameManager.check_victories.
##
## Fase 25: as condições legadas que moravam aqui (Domínio Territorial e Ascensão Arcana) foram
## removidas junto com a Supremacia/Transcendência V1.5 (VictoryCampaign).
##
## Funções PURAS: leem PlayerData, nunca escrevem nele nem mexem em UI/EventBus.

## Identificadores usados por GameManager.check_victories()/EventBus.victory_achieved.
## VICTORY_TYPE_DEBUG é exclusivo do botão "forçar fim de jogo" (GameManager.debug_force_game_over) —
## nunca produzido por check_victories().
const VICTORY_TYPE_DOMINANCE := "dominance"
const VICTORY_TYPE_DEBUG := "debug"

## Todo jogador ALÉM de `player` (na lista completa, humano+rivais) está sem unidade e sem cidade
## nenhuma — mesma definição de "eliminado" usada por V2VictoryConditions.is_eliminated.
static func is_dominance_achieved(player: PlayerData, players: Array[PlayerData]) -> bool:
	for other in players:
		if other == player:
			continue
		if other.units.size() > 0 or other.cities.size() > 0:
			return false
	return true

## Civilizações major ainda vivas (com unidade ou cidade) — incluindo `player` se ele mesmo estiver
## vivo. Informação simples para o painel de vitórias.
static func civilizations_remaining(players: Array[PlayerData]) -> int:
	var alive := 0
	for other in players:
		if not other.units.is_empty() or not other.cities.is_empty():
			alive += 1
	return alive

## Fração de OUTROS jogadores já eliminados — 0.0 se `players` só tiver `player`.
static func dominance_progress(player: PlayerData, players: Array[PlayerData]) -> float:
	var others := []
	for other in players:
		if other != player:
			others.append(other)
	if others.is_empty():
		return 0.0
	var eliminated := 0
	for other in others:
		if other.units.is_empty() and other.cities.is_empty():
			eliminated += 1
	return float(eliminated) / float(others.size())
