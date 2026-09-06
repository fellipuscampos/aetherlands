extends GutTest

## Cobre diplomacia (Diplomacy.gd + PlayerData.is_at_war_with): jogadores
## comecam em paz por padrao, guerra e sempre imediata e simetrica, e paz
## so se aplica se a IA "aceitar" — heuristica simples (Diplomacy._accepts_peace):
## aceita se estiver em desvantagem numerica, empatada, ou muito cansada
## de guerra (roadmap de gameplay Fase 2, ver process_war_weariness_and_upkeep).

var _created_units: Array[Unit] = []

func after_each():
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
	var a = PlayerData.new(CivilizationData.new())
	var b = PlayerData.new(CivilizationData.new())

	assert_false(a.is_at_war_with(b))
	assert_false(b.is_at_war_with(a))

func test_declare_war_is_immediate_and_symmetric():
	var a = PlayerData.new(CivilizationData.new())
	var b = PlayerData.new(CivilizationData.new())

	Diplomacy.declare_war(a, b)

	assert_true(a.is_at_war_with(b))
	assert_true(b.is_at_war_with(a))

func test_propose_peace_when_already_at_peace_is_a_trivial_success():
	var a = PlayerData.new(CivilizationData.new())
	var b = PlayerData.new(CivilizationData.new())

	assert_true(Diplomacy.propose_peace(a, b))
	assert_false(a.is_at_war_with(b))

func test_propose_peace_is_accepted_when_ai_is_outnumbered():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_fake_units(proposer, 3)
	_add_fake_units(ai_player, 1)

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_true(accepted)
	assert_false(proposer.is_at_war_with(ai_player))
	assert_false(ai_player.is_at_war_with(proposer))

func test_propose_peace_is_accepted_on_a_tie():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_fake_units(proposer, 2)
	_add_fake_units(ai_player, 2)

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

func test_propose_peace_is_refused_when_ai_is_winning():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_fake_units(proposer, 1)
	_add_fake_units(ai_player, 3)

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_false(accepted)
	assert_true(proposer.is_at_war_with(ai_player), "recusado: os dois continuam em guerra")
	assert_true(ai_player.is_at_war_with(proposer))

## So o tamanho de player.units importa pra heuristica (Diplomacy._accepts_peace)
## — null "preenche" a contagem sem o custo de construir Unit de verdade.
func _add_fake_units(player: PlayerData, count: int) -> void:
	for i in range(count):
		player.units.append(null)

## Roadmap de gameplay Fase 2: mesmo "ganhando" numericamente (mais
## unidades que quem propos), uma IA MUITO cansada de guerra agora aceita
## paz mesmo assim — antes disto so a contagem crua de unidades decidia.
func test_propose_peace_is_accepted_when_ai_is_very_war_weary_even_if_winning():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_fake_units(proposer, 1)
	_add_fake_units(ai_player, 3) # ai_player "ganhando" em contagem crua
	ai_player.war_weariness = Diplomacy.WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD

	var accepted = Diplomacy.propose_peace(proposer, ai_player)

	assert_true(accepted, "cansaco de guerra deveria bastar pra aceitar paz mesmo estando na frente numericamente")

func test_process_war_weariness_and_upkeep_increases_weariness_while_at_war():
	var player = PlayerData.new(CivilizationData.new())
	var enemy = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.war_weariness, Diplomacy.WAR_WEARINESS_GAIN_PER_TURN, 0.01)

func test_process_war_weariness_and_upkeep_decays_weariness_at_peace():
	var player = PlayerData.new(CivilizationData.new())
	player.war_weariness = 10.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.war_weariness, 10.0 - Diplomacy.WAR_WEARINESS_DECAY_PER_TURN, 0.01)

func test_process_war_weariness_and_upkeep_decay_never_goes_below_zero():
	var player = PlayerData.new(CivilizationData.new())
	player.war_weariness = 0.5 # menos que WAR_WEARINESS_DECAY_PER_TURN

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_eq(player.war_weariness, 0.0)

## Pedido do usuario: manutencao de guerra e um SINK puro, nunca gera
## divida — sem ouro suficiente pra pagar, so trava em 0.0, sem punicao
## extra nenhuma (sem perder unidade, sem bloquear nada).
func test_process_war_weariness_and_upkeep_charges_gold_per_military_unit_while_at_war():
	var player = PlayerData.new(CivilizationData.new())
	var enemy = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)
	_make_unit("warrior", player)
	_make_unit("warrior", player)
	_make_unit("settler", player) # settler tem ataque 0, nao deveria contar como militar
	player.gold = 100.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_almost_eq(player.gold, 100.0 - 2 * Diplomacy.WAR_UPKEEP_GOLD_PER_MILITARY_UNIT, 0.01)

func test_process_war_weariness_and_upkeep_never_creates_debt():
	var player = PlayerData.new(CivilizationData.new())
	var enemy = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(player, enemy)
	_make_unit("warrior", player)
	player.gold = 0.0

	Diplomacy.process_war_weariness_and_upkeep(player)

	assert_eq(player.gold, 0.0, "sem ouro suficiente, a manutencao deveria so travar em 0.0, nunca ficar negativa")

func test_process_war_weariness_and_upkeep_charges_nothing_at_peace():
	var player = PlayerData.new(CivilizationData.new())
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
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player) # nenhum dos dois com unidades -- empate (0<=0) ja e o suficiente pra _accepts_peace aceitar, ver test_propose_peace_is_accepted_on_a_tie acima
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

func test_propose_peace_abandons_active_campaign_of_receiver():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	ai_player.war_campaigns[proposer] = {
		"objective": RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES,
		"target_coord": Vector2i(7, 2),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(ai_player.war_campaigns[proposer].status, RivalAI.CAMPAIGN_STATUS_ABANDONED)

func test_propose_peace_abandons_active_campaigns_in_both_directions_at_once():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
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
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_COMPLETED,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_COMPLETED, "objetivo ja cumprido -- paz nao deveria reescrever um desfecho diferente")

func test_propose_peace_leaves_already_abandoned_campaign_untouched():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ABANDONED,
	}

	assert_true(Diplomacy.propose_peace(proposer, ai_player))

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ABANDONED, "ja abandonada -- so um no-op, nunca um segundo abandono")

func test_propose_peace_refused_leaves_active_campaign_intact():
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(proposer, ai_player)
	_add_fake_units(proposer, 1)
	_add_fake_units(ai_player, 3) # ai_player "ganhando" -- recusa
	proposer.war_campaigns[ai_player] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	assert_false(Diplomacy.propose_peace(proposer, ai_player), "pre-condicao: recusada")

	assert_eq(proposer.war_campaigns[ai_player].status, RivalAI.CAMPAIGN_STATUS_ACTIVE, "paz recusada nao deveria mexer em campanha nenhuma -- guerra continua de verdade")

func test_propose_peace_when_already_at_peace_does_not_touch_campaigns():
	var a = PlayerData.new(CivilizationData.new())
	var b = PlayerData.new(CivilizationData.new())
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
	var proposer = PlayerData.new(CivilizationData.new())
	var ai_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player = proposer # proposer "recebe" a campanha do ai_player, ver comentario acima
	Diplomacy.declare_war(proposer, ai_player)
	ai_player.war_campaigns[proposer] = {
		"objective": RivalAI.WAR_OBJECTIVE_CONQUER,
		"target_coord": Vector2i(3, 3),
		"status": RivalAI.CAMPAIGN_STATUS_ACTIVE,
	}

	watch_signals(EventBus)
	Diplomacy.propose_peace(proposer, ai_player)

	assert_signal_emit_count(EventBus, "notify", 1, "uma campanha ACTIVE abandonada -- exatamente um toast, sem duplicar")
	GameManager.human_player = original_human_player
