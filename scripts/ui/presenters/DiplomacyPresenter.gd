class_name DiplomacyPresenter
extends RefCounted

## View model da tela de DIPLOMACIA (Fase 30 / UI-3). Mostra SOMENTE o que já era
## público no jogo: estado paz/guerra/trégua/eliminado, trégua restante, motivo
## público da guerra (`war_reasons`), cansaço de guerra (já exibido pelo legado) e
## Ritual público. Nunca lê pesquisa, estoque, fila de produção, campanha ou pesos
## internos da IA (`war_campaigns`, `v2_ai_strategy`).
## 2026-10-15: também a ATITUDE deles com você (DiplomaticMemory) com cada motivo, a previsão da resposta a uma
## proposta de paz (Diplomacy.peace_outlook — a mesma regra que eles usam) e o aviso de que estão se armando contra
## você (o mesmo fato já anunciado por notificação quando a preparação começa).

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
	if Diplomacy.has_open_borders(human, rival):
		alerts.append("Fronteiras abertas")
	if state != STATE_ELIMINATED:
		alerts.append(DiplomaticMemory.level_label(rival, human))
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
	if state != STATE_ELIMINATED:
		facts.append_array(attitude_facts(human, rival))
	if state == STATE_WAR:
		facts.append({"caption": "Motivo público", "text": String(human.war_reasons.get(rival, rival.war_reasons.get(human, "Disputa territorial")))})
		facts.append({"caption": "Cansaço deles", "text": "%d / %d" % [int(rival.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]})
		facts.append({"caption": "Seu cansaço", "text": "%d / %d" % [int(human.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]})
		if Diplomacy.has_pending_peace_offer(human, rival):
			facts.append({"caption": "Proposta de paz", "text": "Aguardando a sua resposta", "tone": "warning"})
		elif int(human.peace_refusals.get(rival, 0)) > TurnManager.turn_number:
			facts.append({"caption": "Proposta de paz", "text": "Recusada por você — eles só propõem de novo em %d turno(s)" % (int(human.peace_refusals[rival]) - TurnManager.turn_number)})
		var outlook := Diplomacy.peace_outlook(rival, human)
		var why: Array[String] = outlook.reasons
		facts.append({"caption": "Se propuser paz", "text": ("Aceitariam" if outlook.accept else "Recusariam") + (" — " + ", ".join(why) if not why.is_empty() else ""), "tone": "success" if outlook.accept else "warning"})
		consequences.append("Guerra e conquistas viram rancor: eles lembram, e os outros reinos também (fama de belicista).")
		consequences.append("Guerra custa %s Ouro por unidade militar por turno e acumula cansaço." % str(Diplomacy.WAR_UPKEEP_GOLD_PER_MILITARY_UNIT))
		consequences.append("Paz aceita inicia %d turnos de trégua." % Diplomacy.TRUCE_TURNS)
		consequences.append("Com a paz, as unidades de cada lado são retiradas do território de fronteira fechada do outro.")
	elif state == STATE_TRUCE:
		facts.append({"caption": "Trégua", "text": "%d turno(s) restante(s)" % int(base.truce_remaining)})
		consequences.append("Durante a trégua nenhuma das partes pode declarar guerra.")
	elif state == STATE_PEACE:
		consequences.append("Declarar guerra encerra a paz e o comércio; ambos passam a poder atacar.")
		consequences.append("Eles guardam rancor de quem os ataca (mais ainda com fronteiras abertas), e os outros reinos passam a ver você como belicista.")
		consequences.append("Fronteiras fechadas (cidades que já evoluíram): em paz ninguém entra no território do outro sem acordo; em guerra, os dois entram.")
	else:
		consequences.append("Civilização eliminada: sem cidades nem unidades.")
	if V2TranscendenceSystem.has_active_ritual(rival):
		facts.append({"caption": "Ritual público", "text": "%d rodada(s) restante(s)" % V2TranscendenceSystem.ritual_rounds_remaining(rival), "tone": "critical"})
	# Fronteiras abertas: só faz sentido em paz/trégua (em guerra a fronteira já não existe; eliminada não tem território).
	var borders_apply := state == STATE_PEACE or state == STATE_TRUCE
	var open := Diplomacy.has_open_borders(human, rival)
	var request_reason := Diplomacy.open_borders_unavailable_reason(human, rival) if borders_apply and not open else ""
	if borders_apply:
		facts.append({"caption": "Fronteiras", "text": "Abertas por acordo — as unidades dos dois reinos entram no território um do outro." if open else "Fechadas nas cidades que já evoluíram (só entra quem está em guerra ou tem acordo)."})
		if Diplomacy.has_pending_open_borders_offer(human, rival):
			facts.append({"caption": "Pedido de fronteiras abertas", "text": "Aguardando a sua resposta", "tone": "warning"})
		consequences.append("Fronteiras abertas: acordo dos dois lados, sem prazo; qualquer um pode encerrar, e uma guerra entre vocês o encerra. Ao acabar, as tropas saem do território alheio.")
	base["has_open_borders"] = open
	base["can_request_open_borders"] = borders_apply and not open and request_reason == "" and not GameManager.is_turn_processing
	base["can_end_open_borders"] = borders_apply and open and not GameManager.is_turn_processing
	base["open_borders_reason"] = request_reason
	## O que a IA responderia agora — a regra é pública, o jogador vê antes de pedir.
	base["open_borders_forecast"] = "" if not borders_apply or open else Diplomacy.open_borders_refusal_reason(rival, human)
	base["facts"] = facts
	base["consequences"] = consequences
	base["can_declare_war"] = state == STATE_PEACE and Diplomacy.can_declare_war(human, rival) and not GameManager.is_turn_processing
	base["declare_reason"] = "" if base.can_declare_war else _declare_reason(human, rival, state)
	base["can_propose_peace"] = state == STATE_WAR and not GameManager.is_turn_processing
	base["events"] = recent_events(String(base.name))
	return base

## Atitude deles com você + os maiores motivos (até 4) + aviso de preparação de guerra.
static func attitude_facts(human: PlayerData, rival: PlayerData) -> Array:
	var facts: Array = []
	var value := DiplomaticMemory.attitude(rival, human)
	var level := DiplomaticMemory.level(rival, human)
	var tone := ""
	if level in [DiplomaticMemory.LEVEL_FRIENDLY, DiplomaticMemory.LEVEL_CORDIAL]:
		tone = "success"
	elif level == DiplomaticMemory.LEVEL_WARY:
		tone = "warning"
	elif level in [DiplomaticMemory.LEVEL_HOSTILE, DiplomaticMemory.LEVEL_SWORN]:
		tone = "critical"
	facts.append({"caption": "Atitude deles", "text": "%s (%+d)" % [DiplomaticMemory.level_label(rival, human), int(round(value))], "tone": tone})
	var lines := DiplomaticMemory.breakdown(rival, human)
	for i in mini(4, lines.size()):
		var line: Dictionary = lines[i]
		facts.append({"caption": "Motivo" if i == 0 else "", "text": "%s (%+d)" % [String(line.label), int(round(float(line.value)))], "tone": "success" if float(line.value) > 0.0 else "muted"})
	if not rival.is_at_war_with(human) and int(DiplomaticMemory.value(rival, human, "war_plan")) > 0:
		facts.append({"caption": "Tensão", "text": "Estão reunindo tropas — uma guerra contra você parece próxima.", "tone": "critical"})
	return facts

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
