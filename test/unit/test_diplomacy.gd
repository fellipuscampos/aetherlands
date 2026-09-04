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
