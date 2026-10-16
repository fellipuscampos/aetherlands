class_name Diplomacy
extends RefCounted

## Relações simétricas entre quaisquer civilizações. A IA pode declarar
## guerra, propor paz e negociar comércio com o humano e com outros rivais.
## Paz aceita inicia trégua; motivos e cansaço aparecem na interface.
## Não há negociação de tributos, cessão de território ou alianças.
## Quem RESPONDE a uma proposta de paz: a IA, na hora, por heurística (_accepts_peace); o jogador humano, por
## decisão própria — a proposta fica pendente (offer_peace) até ele aceitar ou recusar (answer_peace_offer).

const TRUCE_TURNS := 10

static func truce_remaining(a: PlayerData, b: PlayerData) -> int:
	return maxi(0, int(a.truces.get(b, 0)) - TurnManager.turn_number)

static func can_declare_war(a: PlayerData, b: PlayerData) -> bool:
	return a != b and truce_remaining(a, b) == 0 and truce_remaining(b, a) == 0

static func declare_war(a: PlayerData, b: PlayerData, reason: String = "Disputa territorial", silent: bool = false) -> void:
	if not can_declare_war(a, b):
		return
	# Um acordo de fronteiras abertas acaba ANTES de a guerra começar: as tropas que estavam dentro do reino alheio por
	# causa dele são retiradas primeiro — o acordo nunca serve para estacionar um exército ao lado da capital e atacar.
	var had_open_borders := a.open_borders.has(b)
	if had_open_borders:
		_clear_open_borders(a, b)
		_enforce_borders()
	a.enemies[b] = true
	b.enemies[a] = true
	a.war_reasons[b] = reason
	b.war_reasons[a] = reason
	if not silent:
		# `silent` = restauração de save/estado inicial: não é uma guerra NOVA, a memória já veio do arquivo.
		DiplomaticMemory.on_war_declared(a, b, had_open_borders)
		EventBus.diplomacy_changed.emit("war", a, b, reason)

## `proposer` costuma ser o jogador humano; `other` o rival sendo
## abordado. Retorna true (e ja aplica a paz nos dois lados) se aceita.
## Se os dois ja estao em paz, conta como sucesso trivial.
## Roadmap "Parte E" E1 -- UNICO ponto de entrada que encerra guerra: por
## isso e aqui (e nao em HUD.gd nem em RivalAI.decide_peace, os dois
## chamadores) que RivalAI.end_campaigns_on_peace roda, cobrindo humano->
## rival e rival->humano sem duplicar a logica em nenhum dos dois. Diplomacy
## de proposito NAO sabe o formato de war_campaigns (isso pertence ao
## sistema de campanha, C3/C4) -- so chama o helper e segue.
## 2026-10-10 (relato do usuario: "quando alguem pede paz a voce, ela e aceita automaticamente"): quando `other` e o
## jogador HUMANO de verdade (GameManager.is_human_controlled), ninguem decide por ele — a proposta vira uma oferta
## pendente (offer_peace) e isto devolve false: ainda nao ha paz. A heuristica _accepts_peace so responde pela IA
## (rivais e o assento humano automatizado do laboratorio de balanceamento).
static func propose_peace(proposer: PlayerData, other: PlayerData) -> bool:
	if not proposer.is_at_war_with(other):
		return true
	if GameManager.is_human_controlled(other):
		offer_peace(proposer, other)
		return false
	if not _accepts_peace(other, proposer):
		DiplomaticMemory.on_peace_refused(proposer, other)
		return false
	make_peace(proposer, other)
	return true

## Encerra a guerra entre `a` e `b` e começa a trégua — o ÚNICO ponto que encerra uma guerra, venha a paz de onde
## vier (IA aceitando por heurística, jogador aceitando uma oferta). Sem efeito se já estão em paz.
static func make_peace(a: PlayerData, b: PlayerData) -> void:
	if not a.is_at_war_with(b):
		return
	a.enemies.erase(b)
	b.enemies.erase(a)
	a.truces[b] = TurnManager.turn_number + TRUCE_TURNS
	b.truces[a] = TurnManager.turn_number + TRUCE_TURNS
	a.peace_offers.erase(b)
	b.peace_offers.erase(a)
	DiplomaticMemory.on_peace(a, b)
	RivalAI.end_campaigns_on_peace(a, b)
	# Fronteiras fechadas: com a paz, cada lado deixa o território fechado do outro (HexGrid.enforce_closed_borders).
	_enforce_borders()
	EventBus.diplomacy_changed.emit("peace", a, b, "Acordo de paz")

## Civilização ELIMINADA (HexGrid.eliminate_civilization): encerra tudo que a ligava às outras — guerras, tréguas,
## propostas de paz, recusas e campanhas, dos dois lados. Sem isto quem a conquistou continuaria "em guerra" com
## ninguém (pagando manutenção de guerra e acumulando cansaço para sempre, sem ter com quem fazer paz) e uma proposta
## de paz dela ainda poderia abrir o modal. Não é um acordo de paz: nenhuma trégua, nenhum evento de paz.
static func dissolve_relations(eliminated: PlayerData, players: Array) -> void:
	if eliminated == null:
		return
	for other in players:
		if other == null or other == eliminated:
			continue
		RivalAI.end_campaigns_on_peace(eliminated, other)
		for relations: Dictionary in [other.enemies, other.truces, other.war_reasons, other.peace_offers, other.peace_refusals, other.war_campaigns, other.open_borders, other.open_border_offers, other.open_border_refusals, other.diplomatic_memory]:
			relations.erase(eliminated)
	eliminated.release_relations()

## Ainda existe alguma relação ligando `player` às outras civilizações (de qualquer um dos dois lados)? O que
## dissolve_relations encerraria — usado por HexGrid.reconcile_eliminations para saber se há algo a acertar.
static func has_relations(player: PlayerData, players: Array) -> bool:
	if player == null:
		return false
	for own: Dictionary in [player.enemies, player.truces, player.war_reasons, player.peace_offers, player.peace_refusals, player.war_campaigns, player.open_borders, player.open_border_offers, player.open_border_refusals]:
		if not own.is_empty():
			return true
	for other in players:
		if other == null or other == player:
			continue
		for relations: Dictionary in [other.enemies, other.truces, other.war_reasons, other.peace_offers, other.peace_refusals, other.war_campaigns, other.open_borders, other.open_border_offers, other.open_border_refusals]:
			if relations.has(player):
				return true
	return false

## --- Proposta de paz pendente (a resposta é do jogador) ------------------------------------------------------------
## Depois de uma recusa, quem propôs espera estes turnos antes de propor de novo — sem isso uma IA cansada da guerra
## reabriria o mesmo modal em todo turno.
const PEACE_OFFER_COOLDOWN_TURNS := 5

## `proposer` pode propor paz a `receiver` agora? Em guerra, sem proposta dele já pendente e fora da espera de uma
## recusa anterior.
static func can_offer_peace(proposer: PlayerData, receiver: PlayerData) -> bool:
	if proposer == null or receiver == null or not proposer.is_at_war_with(receiver):
		return false
	return not has_pending_peace_offer(receiver, proposer) and TurnManager.turn_number >= int(receiver.peace_refusals.get(proposer, 0))

## Registra a proposta e avisa a UI (EventBus.peace_offered). A guerra CONTINUA até a resposta. false se não pode
## propor agora (can_offer_peace).
static func offer_peace(proposer: PlayerData, receiver: PlayerData) -> bool:
	if not can_offer_peace(proposer, receiver):
		return false
	receiver.peace_offers[proposer] = TurnManager.turn_number
	EventBus.peace_offered.emit(proposer, receiver)
	return true

## A proposta vale durante o turno em que chegou: ainda em guerra e feita neste turno. Uma proposta que ficou sem
## resposta até a troca de turno caduca sozinha (sem contar como recusa), e quem propôs pode propor de novo.
static func has_pending_peace_offer(receiver: PlayerData, proposer: PlayerData) -> bool:
	return receiver != null and proposer != null and receiver.peace_offers.has(proposer) \
		and receiver.is_at_war_with(proposer) and int(receiver.peace_offers[proposer]) == TurnManager.turn_number

## Quem tem proposta de paz aguardando a resposta de `receiver`, na ordem em que as propostas chegaram. Descarta as
## que caducaram (a guerra acabou por outro caminho, o turno virou).
static func pending_peace_offers(receiver: PlayerData) -> Array[PlayerData]:
	var pending: Array[PlayerData] = []
	if receiver == null:
		return pending
	for proposer in receiver.peace_offers.keys():
		if has_pending_peace_offer(receiver, proposer):
			pending.append(proposer)
		else:
			receiver.peace_offers.erase(proposer)
	return pending

## A resposta de `receiver` à proposta de `proposer`. Aceitar = make_peace (trégua). Recusar = a guerra continua e
## `proposer` só volta a propor depois de PEACE_OFFER_COOLDOWN_TURNS. false, sem mudar nada, se não há proposta
## pendente dele.
static func answer_peace_offer(receiver: PlayerData, proposer: PlayerData, accept: bool) -> bool:
	if not has_pending_peace_offer(receiver, proposer):
		return false
	receiver.peace_offers.erase(proposer)
	if accept:
		make_peace(proposer, receiver)
	else:
		receiver.peace_refusals[proposer] = TurnManager.turn_number + PEACE_OFFER_COOLDOWN_TURNS
		DiplomaticMemory.on_peace_refused(proposer, receiver)
		EventBus.diplomacy_changed.emit("peace_refused", proposer, receiver, "Proposta de paz recusada")
	return true

# --- FRONTEIRAS ABERTAS ------------------------------------------------------------------------------------------------------
## Pedido do usuário 2026-10-13: "insira também uma mecânica de diplomacia, solicitar fronteiras abertas, aparece pra
## pessoa que foi solicitada e ambos ficam com fronteiras abertas entre si, mesmo sem estar em guerra".
##
## Um acordo SIMÉTRICO entre duas civilizações em paz: enquanto vale, as unidades de cada uma entram no território de
## fronteira fechada da outra (HexGrid.closed_tiles_for consulta PlayerData.open_borders). Quem RESPONDE ao pedido: a IA,
## na hora, por uma regra que o jogador consegue ler (open_borders_refusal_reason); o jogador humano, por decisão
## própria — o pedido fica pendente e a UI abre o modal de Aceitar/Recusar (OpenBordersOfferPresenter). O acordo acaba
## quando um dos lados o encerra (end_open_borders) ou quando há guerra entre os dois (declare_war); nos dois casos as
## tropas que estavam dentro do reino alheio são retiradas (HexGrid.enforce_closed_borders).

## Depois de uma recusa, quem pediu espera estes turnos antes de pedir de novo.
const OPEN_BORDERS_COOLDOWN_TURNS := 5
## Quando quem recusa é o JOGADOR, a espera é bem maior: a IA pede pela cadência dela (RivalAI.decide_open_borders) e,
## com vários rivais, uma espera curta viraria um modal a cada poucos turnos para quem já disse não.
const OPEN_BORDERS_PLAYER_REFUSAL_TURNS := 30
## A IA recusa quando o exército de quem pede é pelo menos o DOBRO do dela e tem pelo menos esta diferença em unidades
## — abrir a fronteira a um vizinho muito mais forte é convidar a invasão.
const OPEN_BORDERS_ARMY_GAP := 4
## Atitude mínima (DiplomaticMemory.attitude) para a IA abrir as fronteiras: abaixo de "Neutro" ela recusa.
const OPEN_BORDERS_MIN_ATTITUDE := -8.0
const OPEN_BORDERS_ACCEPTED := "accepted"
const OPEN_BORDERS_REFUSED := "refused"
const OPEN_BORDERS_OFFERED := "offered" # pendente da resposta do jogador humano
const OPEN_BORDERS_UNAVAILABLE := "unavailable"

static func has_open_borders(a: PlayerData, b: PlayerData) -> bool:
	return a != null and b != null and a.open_borders.has(b)

## Por que `proposer` NÃO pode pedir fronteiras abertas a `receiver` agora ("" = pode).
static func open_borders_unavailable_reason(proposer: PlayerData, receiver: PlayerData) -> String:
	if proposer == null or receiver == null or proposer == receiver:
		return "Pedido inválido."
	if proposer.is_at_war_with(receiver):
		return "Em guerra as fronteiras já estão abertas para os dois lados."
	if has_open_borders(proposer, receiver):
		return "As fronteiras já estão abertas entre vocês."
	if has_pending_open_borders_offer(receiver, proposer):
		return "Pedido enviado: aguardando a resposta."
	var retry := int(receiver.open_border_refusals.get(proposer, 0)) - TurnManager.turn_number
	if retry > 0:
		return "Pedido recusado há pouco: tente de novo em %d turno(s)." % retry
	return ""

static func can_request_open_borders(proposer: PlayerData, receiver: PlayerData) -> bool:
	return open_borders_unavailable_reason(proposer, receiver) == ""

## `proposer` pede fronteiras abertas a `receiver`. Devolve OPEN_BORDERS_*: a IA responde na hora (ACCEPTED/REFUSED);
## o jogador humano recebe o pedido como oferta pendente (OFFERED) e responde por answer_open_borders_offer.
static func request_open_borders(proposer: PlayerData, receiver: PlayerData) -> String:
	if not can_request_open_borders(proposer, receiver):
		return OPEN_BORDERS_UNAVAILABLE
	if GameManager.is_human_controlled(receiver):
		receiver.open_border_offers[proposer] = TurnManager.turn_number
		EventBus.open_borders_offered.emit(proposer, receiver)
		return OPEN_BORDERS_OFFERED
	var reason := open_borders_refusal_reason(receiver, proposer)
	if reason != "":
		_refuse_open_borders(proposer, receiver, reason)
		return OPEN_BORDERS_REFUSED
	make_open_borders(proposer, receiver)
	return OPEN_BORDERS_ACCEPTED

## Por que a IA `ai_player` recusaria fronteiras abertas com `proposer` ("" = aceita). É a regra inteira, e a tela de
## Diplomacia a mostra: trégua em vigor (a guerra entre os dois é recente) ou um exército muito maior do lado de lá.
static func open_borders_refusal_reason(ai_player: PlayerData, proposer: PlayerData) -> String:
	if truce_remaining(ai_player, proposer) > 0 or truce_remaining(proposer, ai_player) > 0:
		return "a guerra entre vocês é recente demais (trégua em vigor)"
	# Memória diplomática (2026-10-15): quem guarda rancor não abre o reino.
	if DiplomaticMemory.attitude(ai_player, proposer) < OPEN_BORDERS_MIN_ATTITUDE:
		return "eles desconfiam de você (%s)" % DiplomaticMemory.level_label(ai_player, proposer)
	var theirs := _military_unit_count(ai_player)
	var yours := _military_unit_count(proposer)
	if yours >= theirs * 2 and yours - theirs >= OPEN_BORDERS_ARMY_GAP:
		return "o exército de quem pede é grande demais para confiarem"
	return ""

static func _military_unit_count(player: PlayerData) -> int:
	var count := 0
	for unit in player.units:
		if unit != null and is_instance_valid(unit) and unit.unit_data != null and unit.unit_data.attack > 0.0:
			count += 1
	return count

## Fecha o acordo entre `a` e `b` (sem efeito se já existe ou se estão em guerra).
static func make_open_borders(a: PlayerData, b: PlayerData) -> void:
	if a == null or b == null or a == b or a.is_at_war_with(b) or has_open_borders(a, b):
		return
	a.open_borders[b] = true
	b.open_borders[a] = true
	for pair in [[a, b], [b, a]]:
		pair[0].open_border_offers.erase(pair[1])
		pair[0].open_border_refusals.erase(pair[1])
	EventBus.diplomacy_changed.emit("open_borders", a, b, "Fronteiras abertas")

## `ended_by` encerra o acordo com `other`: as fronteiras fechadas voltam a valer e as tropas de cada lado saem do
## território do outro. false, sem mudar nada, se não havia acordo.
static func end_open_borders(ended_by: PlayerData, other: PlayerData) -> bool:
	if not has_open_borders(ended_by, other):
		return false
	_clear_open_borders(ended_by, other)
	_enforce_borders()
	EventBus.diplomacy_changed.emit("open_borders_ended", ended_by, other, "Fronteiras abertas encerradas")
	return true

static func _clear_open_borders(a: PlayerData, b: PlayerData) -> void:
	a.open_borders.erase(b)
	b.open_borders.erase(a)

static func _refuse_open_borders(proposer: PlayerData, receiver: PlayerData, reason: String, wait_turns: int = OPEN_BORDERS_COOLDOWN_TURNS) -> void:
	receiver.open_border_refusals[proposer] = TurnManager.turn_number + wait_turns
	EventBus.diplomacy_changed.emit("open_borders_refused", proposer, receiver, reason)

static func _enforce_borders() -> void:
	if GameManager.hex_grid != null and is_instance_valid(GameManager.hex_grid):
		GameManager.hex_grid.enforce_closed_borders()

## O pedido vale durante o turno em que chegou (mesma regra da proposta de paz): sem resposta até a troca de turno, ele
## caduca sozinho, sem contar como recusa.
static func has_pending_open_borders_offer(receiver: PlayerData, proposer: PlayerData) -> bool:
	return receiver != null and proposer != null and receiver.open_border_offers.has(proposer) \
		and not receiver.is_at_war_with(proposer) and not has_open_borders(receiver, proposer) \
		and int(receiver.open_border_offers[proposer]) == TurnManager.turn_number

## Quem tem pedido de fronteiras abertas aguardando a resposta de `receiver`, na ordem de chegada. Descarta os caducos.
static func pending_open_borders_offers(receiver: PlayerData) -> Array[PlayerData]:
	var pending: Array[PlayerData] = []
	if receiver == null:
		return pending
	for proposer in receiver.open_border_offers.keys():
		if has_pending_open_borders_offer(receiver, proposer):
			pending.append(proposer)
		else:
			receiver.open_border_offers.erase(proposer)
	return pending

## A resposta de `receiver` ao pedido de `proposer`. false, sem mudar nada, se não há pedido pendente dele.
static func answer_open_borders_offer(receiver: PlayerData, proposer: PlayerData, accept: bool) -> bool:
	if not has_pending_open_borders_offer(receiver, proposer):
		return false
	receiver.open_border_offers.erase(proposer)
	if accept:
		make_open_borders(proposer, receiver)
	else:
		_refuse_open_borders(proposer, receiver, "Pedido recusado", OPEN_BORDERS_PLAYER_REFUSAL_TURNS)
	return true

static func relation_description(a: PlayerData, b: PlayerData) -> String:
	if a.is_at_war_with(b):
		return "%s. Cansaço: %d/100; %s" % [a.war_reasons.get(b, "Disputa territorial"), int(b.war_weariness), "aceitariam paz agora." if _accepts_peace(b, a) else "recusariam paz agora."]
	var truce := truce_remaining(a, b)
	return "Em paz. Trégua: %d turnos." % truce if truce > 0 else "Em paz."

## --- Aceitar paz (2026-10-15) -------------------------------------------------------------------------------------
## Antes: "aceita se tiver menos unidades OU cansaço ≥ 40" — um número cru de unidades (colono conta) e nenhuma
## memória, então a paz parecia sorteio. Agora é uma conta pública em termos legíveis (peace_outlook), a mesma para
## IA×IA e IA×jogador: aceita quando a soma chega a PEACE_ACCEPT_SCORE.
##   + cansaço de guerra / 30            (30 de cansaço = 1 ponto; cansaço 100 vence até uma guerra que vai bem)
##   + desvantagem militar × 2            (−1…+1; força = Ataque × fração de Vida, ver RivalAI._total_military_strength)
##   + 1 se está perdendo feio (força abaixo da metade da dele)
##   − guerra jovem (< PEACE_MIN_WAR_TURNS turnos) 1 ponto — ninguém declara e pede paz logo depois
##   − rancor / boa vontade (DiplomaticMemory.hostility, −1 … +1)
## Sem exército nenhum (e com alguém para atacá-la), aceita sempre: continuar seria só perder cidades.
const PEACE_ACCEPT_SCORE := 1.0
const PEACE_MIN_WAR_TURNS := 8
const PEACE_WEARINESS_SCALE := 30.0
const PEACE_STRENGTH_WEIGHT := 2.0
const PEACE_LOSING_BADLY_RATIO := 0.5

## {accept: bool, score: float, reasons: Array[String]} — o que `ai_player` responderia a uma proposta de paz de
## `proposer` agora, e por quê. A tela de Diplomacia mostra isso ao jogador antes de ele propor.
static func peace_outlook(ai_player: PlayerData, proposer: PlayerData) -> Dictionary:
	var reasons: Array[String] = []
	var own_strength := RivalAI._total_military_strength(ai_player)
	var their_strength := RivalAI._total_military_strength(proposer)
	if own_strength <= 0.0 and their_strength > 0.0:
		return {"accept": true, "score": 99.0, "reasons": ["estão sem exército"] as Array[String]}
	if ai_player.cities.is_empty() and V2VictoryConditions.has_fallen(ai_player):
		return {"accept": true, "score": 99.0, "reasons": ["perderam todas as cidades"] as Array[String]}
	var score := ai_player.war_weariness / PEACE_WEARINESS_SCALE
	if ai_player.war_weariness >= 20.0:
		reasons.append("cansados da guerra (%d/100)" % int(ai_player.war_weariness))
	var balance := clampf((their_strength - own_strength) / maxf(own_strength + their_strength, 1.0), -1.0, 1.0)
	score += balance * PEACE_STRENGTH_WEIGHT
	if own_strength < their_strength * PEACE_LOSING_BADLY_RATIO:
		score += 1.0
		reasons.append("estão perdendo a guerra")
	elif balance >= 0.15:
		reasons.append("o seu exército é mais forte")
	elif balance <= -0.15:
		reasons.append("o exército deles é mais forte")
	var turns := DiplomaticMemory.turns_at_war(ai_player, proposer)
	if turns < PEACE_MIN_WAR_TURNS and DiplomaticMemory.record(ai_player, proposer).get("war_start", -1) >= 0:
		score -= 1.0
		reasons.append("a guerra começou há pouco (%d turno(s))" % turns)
	var hostility := DiplomaticMemory.hostility(ai_player, proposer)
	score -= hostility
	if hostility >= 0.25:
		reasons.append("guardam rancor (%s)" % DiplomaticMemory.level_label(ai_player, proposer))
	elif hostility <= -0.25:
		reasons.append("têm boa vontade com você (%s)" % DiplomaticMemory.level_label(ai_player, proposer))
	return {"accept": score >= PEACE_ACCEPT_SCORE, "score": score, "reasons": reasons}

static func _accepts_peace(ai_player: PlayerData, proposer: PlayerData) -> bool:
	return bool(peace_outlook(ai_player, proposer).accept)

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
	# Memória diplomática esfria/cresce no mesmo passo de fim de turno de cada civilização (DiplomaticMemory.process_turn).
	DiplomaticMemory.process_turn(player)
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
