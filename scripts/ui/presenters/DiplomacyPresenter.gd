class_name DiplomacyPresenter
extends RefCounted

## View model da tela de DIPLOMACIA (Fase 30 / UI-3). Mostra SOMENTE o que já era
## público no jogo: estado paz/guerra/trégua/eliminado, trégua restante, motivo
## público da guerra (`war_reasons`), cansaço de guerra (já exibido pelo legado) e
## Ritual público. Nunca lê pesquisa, estoque, fila de produção, campanha ou pesos
## internos da IA (`war_campaigns`, `v2_ai_strategy`).

const STATE_WAR := "war"
const STATE_PEACE := "peace"
const STATE_TRUCE := "truce"
const STATE_ELIMINATED := "eliminated"
const STATE_LABELS := {"war": "Em guerra", "peace": "Em paz", "truce": "Trégua", "eliminated": "Eliminada"}

static func rows(human: PlayerData) -> Array:
	var result: Array = []
	if human == null:
		return result
	for rival in GameManager.rival_players:
		if rival == null or rival == human:
			continue
		result.append(row(human, rival))
	return result

static func row(human: PlayerData, rival: PlayerData) -> Dictionary:
	var state := relation_state(human, rival)
	var alerts: Array[String] = []
	if V2TranscendenceSystem.has_active_ritual(rival):
		alerts.append("Ritual · %d" % V2TranscendenceSystem.ritual_rounds_remaining(rival))
	return {
		"player": rival,
		"name": rival.civ.civ_name if rival.civ != null else "Civilização",
		"color": rival.civ.color if rival.civ != null else UIThemeTokens.COLOR_BORDER,
		"state": state,
		"state_label": String(STATE_LABELS[state]),
		"truce_remaining": maxi(Diplomacy.truce_remaining(human, rival), Diplomacy.truce_remaining(rival, human)),
		"alerts": alerts,
	}

static func relation_state(human: PlayerData, rival: PlayerData) -> String:
	if V2VictoryConditions.is_eliminated(rival):
		return STATE_ELIMINATED
	if human.is_at_war_with(rival):
		return STATE_WAR
	if Diplomacy.truce_remaining(human, rival) > 0 or Diplomacy.truce_remaining(rival, human) > 0:
		return STATE_TRUCE
	return STATE_PEACE

static func state_tone(state: String) -> int:
	match state:
		STATE_WAR:
			return AEStatusChip.Tone.NEGATIVE
		STATE_TRUCE:
			return AEStatusChip.Tone.WARNING
		STATE_ELIMINATED:
			return AEStatusChip.Tone.TRAIT
	return AEStatusChip.Tone.POSITIVE

static func detail(human: PlayerData, rival: PlayerData) -> Dictionary:
	var base := row(human, rival)
	var state: String = base.state
	var facts: Array = []
	var consequences: Array[String] = []
	if state == STATE_WAR:
		facts.append({"caption": "Motivo público", "text": String(human.war_reasons.get(rival, rival.war_reasons.get(human, "Disputa territorial")))})
		facts.append({"caption": "Cansaço deles", "text": "%d / %d" % [int(rival.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]})
		facts.append({"caption": "Seu cansaço", "text": "%d / %d" % [int(human.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]})
		consequences.append("Guerra custa %s Ouro por unidade militar por turno e acumula cansaço." % str(Diplomacy.WAR_UPKEEP_GOLD_PER_MILITARY_UNIT))
		consequences.append("Paz aceita inicia %d turnos de trégua." % Diplomacy.TRUCE_TURNS)
	elif state == STATE_TRUCE:
		facts.append({"caption": "Trégua", "text": "%d turno(s) restante(s)" % int(base.truce_remaining)})
		consequences.append("Durante a trégua nenhuma das partes pode declarar guerra.")
	elif state == STATE_PEACE:
		consequences.append("Declarar guerra encerra a paz e o comércio; ambos passam a poder atacar.")
	else:
		consequences.append("Civilização eliminada: sem cidades nem unidades.")
	if V2TranscendenceSystem.has_active_ritual(rival):
		facts.append({"caption": "Ritual público", "text": "%d rodada(s) restante(s)" % V2TranscendenceSystem.ritual_rounds_remaining(rival), "tone": "critical"})
	base["facts"] = facts
	base["consequences"] = consequences
	base["can_declare_war"] = state == STATE_PEACE and Diplomacy.can_declare_war(human, rival) and not GameManager.is_turn_processing
	base["declare_reason"] = "" if base.can_declare_war else _declare_reason(human, rival, state)
	base["can_propose_peace"] = state == STATE_WAR and not GameManager.is_turn_processing
	base["events"] = recent_events(String(base.name))
	return base

static func _declare_reason(human: PlayerData, rival: PlayerData, state: String) -> String:
	match state:
		STATE_WAR:
			return "Já em guerra."
		STATE_ELIMINATED:
			return "Civilização eliminada."
		STATE_TRUCE:
			return "Trégua ativa: %d turno(s)." % maxi(Diplomacy.truce_remaining(human, rival), Diplomacy.truce_remaining(rival, human))
	if GameManager.is_turn_processing:
		return "Aguarde o fim do processamento do turno."
	return "Guerra não permitida agora."

## Até 5 eventos da sessão ligados à facção, lidos do MESMO histórico do Event Center.
static func recent_events(rival_name: String, limit: int = 5) -> Array:
	var result: Array = []
	if UIEvents == null or rival_name.is_empty():
		return result
	var history := UIEvents.get_history()
	for index in range(history.size() - 1, -1, -1):
		var event: UIEventData = history[index]
		if event.category != UIEventData.Category.WAR and event.category != UIEventData.Category.DIPLOMACY:
			continue
		if event.source_player != rival_name and event.target_entity != rival_name:
			continue
		result.append({"turn": event.turn, "title": event.title, "message": event.message})
		if result.size() >= limit:
			break
	return result

static func find_rival_by_name(name: String) -> PlayerData:
	for rival in GameManager.rival_players:
		if rival != null and rival.civ != null and rival.civ.civ_name == name:
			return rival
	return null
