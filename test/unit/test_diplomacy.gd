extends GutTest

## Cobre diplomacia (Diplomacy.gd + PlayerData.is_at_war_with): jogadores
## comecam em paz por padrao, guerra e sempre imediata e simetrica, e paz
## so se aplica se a IA "aceitar" — heuristica simples (Diplomacy._accepts_peace):
## aceita se estiver em desvantagem numerica ou empatada.

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
