class_name PublicVictoryMilestones
extends RefCounted

## Fase 33D3 — MARCOS PÚBLICOS de vitória (decisão de produto Q2 da F33C): quando uma civilização conclui o
## Exército Supremo, ou passa a ter duas Grandes Manifestações de Escolas distintas ativas ao mesmo tempo, o
## FATO vira conhecimento público do mundo — exceção deliberada à informação privada que expõe só o marco:
## nunca Doutrina/Escola, unidades, posição, cidade de origem, HP ou tamanho de exército.
##
## Avaliado uma vez por rodada global (GameManager._finish_turn), sobre 4 PlayerData — nada por frame. Cada
## marco é anunciado UMA vez por civ por partida (WorldEventManager.public_milestones, salvo): perder uma
## Manifestação e voltar a duas não anuncia de novo. A IA lê o fato por V2AIWorldView.public_milestones.

const SUPREME_ARMY := "supreme_army"
const SECOND_MANIFESTATION := "second_manifestation"
const MILESTONES := [SUPREME_ARMY, SECOND_MANIFESTATION]

static func is_reached(player: PlayerData, milestone: String) -> bool:
	if player == null or V2VictoryConditions.is_eliminated(player):
		return false
	match milestone:
		SUPREME_ARMY:
			return player.has_unlocked(V2VictoryConditions.MILITARY_SUPREMACY_ACCESS)
		SECOND_MANIFESTATION:
			return V2ManifestationSystem.active_manifestation_count(player) >= V2TranscendenceSystem.MANIFESTATIONS_REQUIRED
	return false

static func announced(index: int, milestone: String) -> bool:
	return (WorldEventManager.public_milestones.get(str(index), {}) as Dictionary).has(milestone)

## Fim de rodada: anuncia (EventBus.public_milestone_reached) cada marco novo, uma vez.
static func evaluate_round(players: Array[PlayerData], turn: int) -> void:
	for index in range(players.size()):
		for milestone in MILESTONES:
			if announced(index, milestone) or not is_reached(players[index], milestone):
				continue
			_mark(index, milestone, turn)
			EventBus.public_milestone_reached.emit(players[index], milestone)

## Migração (save sem o bloco): marcos já satisfeitos no estado carregado contam como anunciados, sem evento.
static func snapshot_already_reached(players: Array[PlayerData]) -> Dictionary:
	var result := {}
	for index in range(players.size()):
		for milestone in MILESTONES:
			if is_reached(players[index], milestone):
				if not result.has(str(index)):
					result[str(index)] = {}
				result[str(index)][milestone] = -1
	return result

## Fatos públicos por civ (índice → [marcos]); o que a IA e a UI podem saber de um rival.
static func public_facts() -> Dictionary:
	var result := {}
	for key in WorldEventManager.public_milestones:
		result[int(key)] = (WorldEventManager.public_milestones[key] as Dictionary).keys()
	return result

static func message_for(player: PlayerData, milestone: String) -> Dictionary:
	var name := player.civ.civ_name if player != null and player.civ != null else "Um reino"
	match milestone:
		SUPREME_ARMY:
			return {"title": "%s concluiu o Exército Supremo." % name, "body": "Seus exércitos agora podem disputar a Supremacia Militar."}
		SECOND_MANIFESTATION:
			return {"title": "Duas grandes Manifestações servem a %s." % name, "body": "O reino reúne o que é preciso para tentar a Transcendência."}
	return {"title": name, "body": ""}

static func _mark(index: int, milestone: String, turn: int) -> void:
	var key := str(index)
	if not WorldEventManager.public_milestones.has(key):
		WorldEventManager.public_milestones[key] = {}
	WorldEventManager.public_milestones[key][milestone] = turn
