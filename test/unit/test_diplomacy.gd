extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## Cobre diplomacia (Diplomacy.gd + PlayerData.is_at_war_with): jogadores
## comecam em paz por padrao, guerra e sempre imediata e simetrica, e paz
## so se aplica se a IA "aceitar" — heuristica simples (Diplomacy._accepts_peace):
## aceita se estiver em desvantagem numerica, empatada, ou muito cansada
## de guerra (roadmap de gameplay Fase 2, ver process_war_weariness_and_upkeep).

var _created_units: Array[Unit] = []

func after_each():
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_created_units = []

func _make_unit(kind: String, player: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, Vector2i(0, 0))
	player.units.append(unit)
	_created_units.append(unit)
	return unit

func test_players_start_at_peace():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())

	assert_false(a.is_at_war_with(b))
	assert_false(b.is_at_war_with(a))

func test_declare_war_is_immediate_and_symmetric():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())

	Diplomacy.declare_war(a, b)

	assert_true(a.is_at_war_with(b))
	assert_true(b.is_at_war_with(a))

func test_propose_peace_when_already_at_peace_is_a_trivial_success():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())

	assert_true(Diplomacy.propose_peace(a, b))
	assert_false(a.is_at_war_with(b))

## 2026-10-15 — aceitar paz é uma conta (Diplomacy.peace_outlook): cansaço, força, guerra jovem e rancor. Antes era
## "menos unidades OU cansaço ≥ 40" (empate aceitava na hora).
func test_propose_peace_is_accepted_when_ai_is_losing_badly():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 3)
	_add_warriors(ai_player, 1)
	_age_war(ai_player, proposer)

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_true(accepted, "perdendo 3 contra 1 numa guerra que já dura, aceita mesmo atacada (rancor de 1 guerra)")
	assert_false(proposer.is_at_war_with(ai_player))
	assert_false(ai_player.is_at_war_with(proposer))

func test_propose_peace_on_a_tie_is_refused_right_after_the_declaration():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 2)
	_add_warriors(ai_player, 2)

	assert_false(Diplomacy.propose_peace(proposer, ai_player), "quem declarou não pede paz no mesmo turno com o placar empatado")
	var outlook := Diplomacy.peace_outlook(ai_player, proposer)
	assert_false(outlook.accept)
	assert_true(", ".join(outlook.reasons).contains("começou há pouco"), "o motivo da recusa é legível: %s" % [outlook.reasons])

func test_propose_peace_on_a_tie_is_accepted_after_a_long_tiring_war():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 2)
	_add_warriors(ai_player, 2)
	_age_war(ai_player, proposer)
	ai_player.war_weariness = 60.0

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

func test_propose_peace_is_refused_when_ai_is_winning():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 1)
	_add_warriors(ai_player, 3)
	_age_war(ai_player, proposer)

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_false(accepted)
	assert_true(proposer.is_at_war_with(ai_player), "recusado: os dois continuam em guerra")
	assert_true(ai_player.is_at_war_with(proposer))
	assert_gt(DiplomaticMemory.value(proposer, ai_player, DiplomaticMemory.REFUSALS), 0.0, "quem propôs guarda a recusa")

func _add_warriors(player: PlayerData, count: int) -> void:
	for i in range(count):
		_make_unit("warrior", player)

## A guerra entre os dois começou há 20 turnos (sem a penalidade de guerra jovem).
func _age_war(holder: PlayerData, other: PlayerData) -> void:
	DiplomaticMemory.record(holder, other).war_start = TurnManager.turn_number - 20
	DiplomaticMemory.record(other, holder).war_start = TurnManager.turn_number - 20

## IA disposta a aceitar a paz de qualquer jeito (guerra velha, cansaço no teto) — para os testes de campanha abaixo,
## que só olham o efeito da paz, não a regra de aceitar.
func _ripe_for_peace(ai_player: PlayerData, proposer: PlayerData) -> void:
	_age_war(ai_player, proposer)
	ai_player.war_weariness = Diplomacy.WAR_WEARINESS_MAX

## Mesmo "ganhando" (3 contra 1), uma IA no teto de cansaço aceita paz.
func test_propose_peace_is_accepted_when_ai_is_very_war_weary_even_if_winning():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 1)
	_add_warriors(ai_player, 3)
	_ripe_for_peace(ai_player, proposer)

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_true(accepted, "cansaco de guerra no teto deveria bastar pra aceitar paz mesmo estando na frente")

func test_grudge_from_conquest_makes_peace_harder():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 2)
	_add_warriors(ai_player, 2)
	_age_war(ai_player, proposer)
	ai_player.war_weariness = 55.0
	assert_true(Diplomacy.peace_outlook(ai_player, proposer).accept, "pre-condicao: sem conquista, aceitaria")

	DiplomaticMemory.on_city_captured(ai_player, proposer)
	DiplomaticMemory.on_city_captured(ai_player, proposer)

	assert_false(Diplomacy.peace_outlook(ai_player, proposer).accept, "duas cidades tomadas: o rancor segura a guerra")

func test_process_war_weariness_and_upkeep_increases_weariness_while_at_war():
	var player = _track_player(CivilizationData.new())
	var enemy = _track_player(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.war_weariness, Diplomacy.WAR_WEARINESS_GAIN_PER_TURN, 0.01)

func test_process_war_weariness_and_upkeep_decays_weariness_at_peace():
	var player = _track_player(CivilizationData.new())
	player.war_weariness = 10.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.war_weariness, 10.0 - Diplomacy.WAR_WEARINESS_DECAY_PER_TURN, 0.01)

func test_process_war_weariness_and_upkeep_decay_never_goes_below_zero():
	var player = _track_player(CivilizationData.new())
	player.war_weariness = 0.5 # menos que WAR_WEARINESS_DECAY_PER_TURN

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_eq(player.war_weariness, 0.0)

## Pedido do usuario: manutencao de guerra e um SINK puro, nunca gera
## divida — sem ouro suficiente pra pagar, so trava em 0.0, sem punicao
## extra nenhuma (sem perder unidade, sem bloquear nada).
func test_process_war_weariness_and_upkeep_charges_gold_per_military_unit_while_at_war():
	var player = _track_player(CivilizationData.new())
	var enemy = _track_player(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)
	_make_unit("warrior", player)
	_make_unit("warrior", player)
	_make_unit("settler", player) # settler tem ataque 0, nao deveria contar como militar
	player.gold = 100.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.gold, 100.0 - 2 * Diplomacy.WAR_UPKEEP_GOLD_PER_MILITARY_UNIT, 0.01)

func test_process_war_weariness_and_upkeep_never_creates_debt():
	var player = _track_player(CivilizationData.new())
	var enemy = _track_player(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)
	_make_unit("warrior", player)
	player.gold = 0.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_eq(player.gold, 0.0, "sem ouro suficiente, a manutencao deveria so travar em 0.0, nunca ficar negativa")

func test_process_war_weariness_and_upkeep_charges_nothing_at_peace():
	var player = _track_player(CivilizationData.new())
	_make_unit("warrior", player)
	player.gold = 50.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_eq(player.gold, 50.0, "em paz, nao deveria haver manutencao de guerra nenhuma")

## Roadmap "Parte E" E1 -- ponte entre paz e war_campaigns (RivalAI.gd C3/
## C4). Testado aqui, via Diplomacy.propose_peace() DIRETAMENTE (nao so
## RivalAI.decide_peace nem HUD.gd), porque este e o UNICO ponto que
## precisa carregar o contrato "paz resolvida encerra campanha ACTIVE" --
## os dois chamadores (decide_peace, HUD) so herdam o efeito.
func test_propose_peace_abandons_active_campaign_of_proposer():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer) # guerra velha e cansaço no teto: a IA aceita (a regra em si é testada acima)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

func test_propose_peace_abandons_active_campaign_of_receiver():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer)
	ai_player.war_campaigns[proposer] = {
		"objective": RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES,
		"target_coord": Vector2i(7, 2),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(ai_player.war_campaigns[proposer].status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

func test_propose_peace_abandons_active_campaigns_in_both_directions_at_once():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}
	ai_player.war_campaigns[proposer] = {
		"objective": RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES,
		"target_coord": Vector2i(7, 2),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "direcao proposer->ai_player")
	assert_eq(ai_player.war_campaigns[proposer].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "direcao ai_player->proposer")

func test_propose_peace_leaves_completed_campaign_untouched():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_COMPLETED,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_COMPLETED, "objetivo ja cumprido -- paz nao deveria reescrever um desfecho diferente")

func test_propose_peace_leaves_already_abandoned_campaign_untouched():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "ja abandonada -- so um no-op, nunca um segundo abandono")

func test_propose_peace_refused_leaves_active_campaign_intact():
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_warriors(proposer, 1)
	_add_warriors(ai_player, 3) # ai_player "ganhando" -- recusa
	_age_war(ai_player, proposer)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_false(Diplomacy.propose_peace(proposer, ai_player), "pre-condicao: recusada")

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ACTIVE, "paz recusada nao deveria mexer em campanha nenhuma -- guerra continua de verdade")

func test_propose_peace_when_already_at_peace_does_not_touch_campaigns():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())
	# Estado artificial (uma campanha ACTIVE nunca deveria sobreviver ate
	# aqui em paz de verdade, ver end_campaigns_on_peace) so pra confirmar
	# que o atalho trivial (linha 28 de Diplomacy.gd) continua sem tocar em
	# nada alem de guerra -- comportamento existente preservado por E1.
	a.war_campaigns[b] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(a, b))

	assert_eq(a.war_campaigns[b].status, RivalAI.CAMPAIGN_STATUS_ACTIVE, "atalho de ja-em-paz nao deveria ter side effect nenhum em campanha")

## Confirma que o abandono de campanha gera exatamente UM toast por
## campanha ACTIVE encerrada (nunca zero, nunca dois) -- ver
## RivalAI._abandon_campaign_if_active/_notify_campaign_abandoned.
## GameManager.human_player precisa apontar pra quem RECEBE a notificacao
## (ver RivalAI._notify_human) -- salvo/restaurado manualmente porque este
## arquivo normalmente nao mexe em autoloads.
func test_propose_peace_emits_exactly_one_notify_per_abandoned_campaign():
	var original_human_player: PlayerData = GameManager.human_player
	var proposer = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	GameManager.human_player = proposer # proposer "recebe" a campanha do ai_player, ver comentario acima
	Diplomacy.declare_war(proposer, ai_player)
	_ripe_for_peace(ai_player, proposer)
	ai_player.war_campaigns[proposer] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	watch_signals(EventBus)
	Diplomacy.propose_peace(proposer, ai_player)

	assert_signal_emit_count(EventBus, "notify", 1, "uma campanha ACTIVE abandonada -- exatamente um toast, sem duplicar")
	GameManager.human_player = original_human_player

## PROPOSTA DE PAZ AO JOGADOR HUMANO (2026-10-10, relato do usuario: "quando alguem pede paz a voce, ela e aceita
## automaticamente"). propose_peace nunca decide pelo humano de verdade: registra a oferta e a guerra continua ate
## answer_peace_offer. So a IA (rival, ou o assento humano automatizado do laboratorio) responde pela heuristica.
func test_propose_peace_to_the_human_player_never_decides_for_them():
	var original_human := GameManager.human_player
	var human = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	GameManager.human_player = human
	Diplomacy.declare_war(human, ai_player)
	_make_unit("warrior", ai_player) # IA mais forte: a heuristica aceitaria pelo humano
	watch_signals(EventBus)

	var accepted = Diplomacy.propose_peace(ai_player, human)

	assert_false(accepted, "ainda nao ha paz: a resposta e do jogador")
	assert_true(human.is_at_war_with(ai_player))
	assert_true(Diplomacy.has_pending_peace_offer(human, ai_player))
	assert_eq(Diplomacy.pending_peace_offers(human), [ai_player] as Array[PlayerData])
	assert_signal_emit_count(EventBus, "peace_offered", 1)
	assert_signal_emit_count(EventBus, "diplomacy_changed", 0)
	GameManager.human_player = original_human

func test_the_automated_human_seat_of_the_balance_lab_still_answers_by_heuristic():
	var original_human := GameManager.human_player
	var original_seat := GameManager.ai_controls_human_seat
	var human = _track_player(CivilizationData.new())
	var ai_player = _track_player(CivilizationData.new())
	GameManager.human_player = human
	GameManager.ai_controls_human_seat = true
	Diplomacy.declare_war(human, ai_player)
	_make_unit("warrior", ai_player)

	assert_true(Diplomacy.propose_peace(ai_player, human), "sem jogador na cadeira, a heuristica responde na hora")
	assert_false(human.is_at_war_with(ai_player))
	assert_true(human.peace_offers.is_empty())
	GameManager.ai_controls_human_seat = original_seat
	GameManager.human_player = original_human

func test_answering_without_a_pending_offer_changes_nothing():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())
	Diplomacy.declare_war(a, b)

	assert_false(Diplomacy.answer_peace_offer(a, b, true))
	assert_true(a.is_at_war_with(b))
	assert_false(Diplomacy.offer_peace(a, a), "nem consigo mesmo")
	Diplomacy.make_peace(a, b)
	assert_false(Diplomacy.offer_peace(b, a), "nem em paz")

func test_make_peace_clears_pending_offers_in_both_directions():
	var a = _track_player(CivilizationData.new())
	var b = _track_player(CivilizationData.new())
	Diplomacy.declare_war(a, b)
	assert_true(Diplomacy.offer_peace(b, a))

	Diplomacy.make_peace(a, b)

	assert_true(a.peace_offers.is_empty())
	assert_eq(Diplomacy.truce_remaining(a, b), Diplomacy.TRUCE_TURNS)
	assert_eq(Diplomacy.pending_peace_offers(a).size(), 0)
