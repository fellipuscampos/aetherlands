extends GutTest

## FRONTEIRAS ABERTAS (2026-10-13) — pedido do usuário: "insira também uma mecânica de diplomacia, solicitar fronteiras
## abertas, aparece pra pessoa que foi solicitada e ambos ficam com fronteiras abertas entre si, mesmo sem estar em
## guerra". Acordo simétrico (PlayerData.open_borders) que suspende, entre os dois, as fronteiras fechadas
## (test_closed_borders.gd); a IA responde na hora por uma regra legível, o jogador responde num modal.

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var third: PlayerData
var _original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-12, 13):
		for r in range(-12, 13):
			if absi(q + r) <= 12:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora")
	rival = _player("Crepúsculo")
	third = _player("Maré")
	GameManager.players = [human, rival, third] as Array[PlayerData]
	GameManager.rival_players = [rival, third] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.debug_mode = false
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 10

func after_each():
	SelectionManager.reset()
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	for player in [human, rival, third]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _player(civ_name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	return PlayerData.new(civ)

func _unit(coord: Vector2i, owner: PlayerData, kind: String = "warrior") -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)

## Cidade evoluída (fronteira fechada) de `owner` em `coord`, com território de raio 2.
func _closed_city(owner: PlayerData, coord: Vector2i, city_name: String) -> City:
	var city := grid.found_city(coord, owner, city_name, true)
	for tile in HexMetrics.coords_within(coord, 2):
		if grid.tiles.has(tile) and not tile in city.owned_tiles:
			city.owned_tiles.append(tile)
	city.city_level = 2
	return city

func _two_realms() -> Array[City]:
	return [_closed_city(human, Vector2i(-6, 0), "Capital"), _closed_city(rival, Vector2i(6, 0), "Sombria")]

# --- O acordo ---------------------------------------------------------------------------------------------------------------

func test_an_agreement_opens_both_borders_without_war_and_only_between_the_two():
	var cities := _two_realms()
	var mine: City = cities[0]
	var theirs: City = cities[1]
	var scout := _unit(theirs.coord + Vector2i(-3, 0), human)
	var envoy := _unit(mine.coord + Vector2i(3, 0), rival)
	assert_true(grid.is_border_closed_to(theirs.coord + Vector2i(-1, 0), human), "pré-condição: em paz, fechado")
	watch_signals(EventBus)

	Diplomacy.make_open_borders(human, rival)

	assert_true(human.has_open_borders_with(rival) and rival.has_open_borders_with(human), "o acordo é dos dois lados")
	assert_false(human.is_at_war_with(rival), "sem guerra nenhuma")
	assert_false(grid.is_border_closed_to(theirs.coord + Vector2i(-1, 0), human), "você entra no reino deles")
	assert_false(grid.is_border_closed_to(mine.coord + Vector2i(1, 0), rival), "e eles no seu")
	assert_false(grid.unit_path(scout, theirs.coord + Vector2i(-1, 0)).is_empty())
	assert_false(grid.unit_path(envoy, mine.coord + Vector2i(1, 0)).is_empty())
	assert_true(grid.is_border_closed_to(theirs.coord + Vector2i(-1, 0), third), "um terceiro continua barrado")
	assert_true(grid.is_border_closed_to(mine.coord + Vector2i(1, 0), third))
	assert_signal_emitted_with_parameters(EventBus, "diplomacy_changed", ["open_borders", human, rival, "Fronteiras abertas"])

func test_ending_the_agreement_closes_the_borders_and_withdraws_both_sides():
	var cities := _two_realms()
	Diplomacy.make_open_borders(human, rival)
	var visitor := _unit(cities[1].coord + Vector2i(-1, 0), human)
	var guest := _unit(cities[0].coord + Vector2i(1, 0), rival)
	assert_true(grid.enforce_closed_borders().is_empty(), "com o acordo ninguém é retirado")

	assert_true(Diplomacy.end_open_borders(human, rival))

	assert_false(human.has_open_borders_with(rival) or rival.has_open_borders_with(human))
	assert_false(visitor.coord in cities[1].owned_tiles, "suas tropas saem do reino deles")
	assert_false(guest.coord in cities[0].owned_tiles, "e as deles do seu")
	assert_true(grid.is_border_closed_to(cities[1].coord + Vector2i(-1, 0), human))
	assert_false(Diplomacy.end_open_borders(human, rival), "sem acordo, nada a encerrar")

## O acordo nunca serve para estacionar um exército ao lado da capital alheia e atacar: declarar guerra o encerra e
## retira as tropas ANTES de a guerra começar.
func test_declaring_war_ends_the_agreement_and_withdraws_the_troops_first():
	var cities := _two_realms()
	Diplomacy.make_open_borders(human, rival)
	var parked := _unit(cities[1].coord + Vector2i(-1, 0), human)

	Diplomacy.declare_war(human, rival, "Traição", true)

	assert_true(human.is_at_war_with(rival))
	assert_false(human.has_open_borders_with(rival) or rival.has_open_borders_with(human), "a guerra encerra o acordo")
	assert_false(parked.coord in cities[1].owned_tiles, "a tropa estacionada lá dentro começa a guerra do lado de fora")
	Diplomacy.make_peace(human, rival)
	assert_false(human.has_open_borders_with(rival), "a paz não devolve o acordo")

func test_an_agreement_cannot_exist_between_civilizations_at_war():
	_two_realms()
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	Diplomacy.make_open_borders(human, rival)
	assert_false(human.has_open_borders_with(rival))
	assert_eq(Diplomacy.request_open_borders(human, rival), Diplomacy.OPEN_BORDERS_UNAVAILABLE)
	assert_string_contains(Diplomacy.open_borders_unavailable_reason(human, rival), "Em guerra")

func test_elimination_dissolves_the_agreement():
	var cities := _two_realms()
	Diplomacy.make_open_borders(third, rival)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	grid.capture_city(cities[1], human)
	assert_false(third.has_open_borders_with(rival), "o reino eliminado não deixa acordo pendurado")
	assert_false(Diplomacy.has_relations(rival, GameManager.players))

# --- A resposta da IA -------------------------------------------------------------------------------------------------------

func test_the_ai_answers_a_request_at_once_and_accepts_by_default():
	_two_realms()
	_unit(Vector2i(-5, 3), human)
	_unit(Vector2i(5, 3), rival)

	assert_eq(Diplomacy.open_borders_refusal_reason(rival, human), "")
	assert_eq(Diplomacy.request_open_borders(human, rival), Diplomacy.OPEN_BORDERS_ACCEPTED)

	assert_true(human.has_open_borders_with(rival))
	assert_eq(Diplomacy.request_open_borders(human, rival), Diplomacy.OPEN_BORDERS_UNAVAILABLE, "já existe")
	assert_string_contains(Diplomacy.open_borders_unavailable_reason(human, rival), "já estão abertas")

func test_the_ai_refuses_during_a_truce_and_the_refusal_starts_a_cooldown():
	_two_realms()
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	Diplomacy.make_peace(human, rival) # trégua em vigor
	watch_signals(EventBus)

	assert_string_contains(Diplomacy.open_borders_refusal_reason(rival, human), "trégua")
	assert_eq(Diplomacy.request_open_borders(human, rival), Diplomacy.OPEN_BORDERS_REFUSED)

	assert_false(human.has_open_borders_with(rival))
	assert_signal_emitted(EventBus, "diplomacy_changed")
	assert_eq(String(get_signal_parameters(EventBus, "diplomacy_changed", 0)[0]), "open_borders_refused")
	assert_false(Diplomacy.can_request_open_borders(human, rival), "espera antes de pedir de novo")
	assert_string_contains(Diplomacy.open_borders_unavailable_reason(human, rival), "%d turno(s)" % Diplomacy.OPEN_BORDERS_COOLDOWN_TURNS)
	TurnManager.turn_number += Diplomacy.OPEN_BORDERS_COOLDOWN_TURNS
	assert_true(Diplomacy.can_request_open_borders(human, rival), "passada a espera, pode pedir de novo")

func test_the_ai_refuses_a_neighbour_whose_army_dwarfs_its_own():
	_two_realms()
	_unit(Vector2i(5, 3), rival)
	for index in 5:
		_unit(Vector2i(-8 + index, 4), human)

	assert_string_contains(Diplomacy.open_borders_refusal_reason(rival, human), "exército")
	assert_eq(Diplomacy.request_open_borders(human, rival), Diplomacy.OPEN_BORDERS_REFUSED)
	assert_eq(Diplomacy.open_borders_refusal_reason(human, rival), "", "o lado mais fraco não assusta ninguém")

# --- O pedido ao jogador ------------------------------------------------------------------------------------------------------

func test_a_request_to_the_player_waits_for_the_players_answer():
	var cities := _two_realms()
	watch_signals(EventBus)

	assert_eq(Diplomacy.request_open_borders(rival, human), Diplomacy.OPEN_BORDERS_OFFERED)

	assert_signal_emitted_with_parameters(EventBus, "open_borders_offered", [rival, human])
	assert_false(human.has_open_borders_with(rival), "nada muda enquanto ele não responde")
	assert_true(grid.is_border_closed_to(cities[0].coord + Vector2i(1, 0), rival))
	assert_eq(Diplomacy.pending_open_borders_offers(human), [rival] as Array[PlayerData])
	assert_eq(Diplomacy.request_open_borders(rival, human), Diplomacy.OPEN_BORDERS_UNAVAILABLE, "um pedido por vez")

	assert_true(Diplomacy.answer_open_borders_offer(human, rival, true))

	assert_true(human.has_open_borders_with(rival) and rival.has_open_borders_with(human))
	assert_true(Diplomacy.pending_open_borders_offers(human).is_empty())
	assert_false(Diplomacy.answer_open_borders_offer(human, rival, true), "já respondido")

func test_the_player_refusing_keeps_everything_closed_and_starts_the_cooldown():
	_two_realms()
	Diplomacy.request_open_borders(rival, human)

	assert_true(Diplomacy.answer_open_borders_offer(human, rival, false))

	assert_false(human.has_open_borders_with(rival))
	assert_false(Diplomacy.can_request_open_borders(rival, human), "eles esperam antes de pedir de novo")
	TurnManager.turn_number += Diplomacy.OPEN_BORDERS_PLAYER_REFUSAL_TURNS - 1
	assert_false(Diplomacy.can_request_open_borders(rival, human), "a recusa do jogador vale por muito tempo: nada de modal a cada poucos turnos")
	TurnManager.turn_number += 1
	assert_true(Diplomacy.can_request_open_borders(rival, human))
	assert_true(Diplomacy.can_request_open_borders(human, rival), "a recusa não impede o jogador de pedir depois")

func test_an_unanswered_request_lapses_when_the_turn_changes():
	_two_realms()
	Diplomacy.request_open_borders(rival, human)
	TurnManager.turn_number += 1
	assert_true(Diplomacy.pending_open_borders_offers(human).is_empty(), "caduca sem contar como recusa")
	assert_true(Diplomacy.can_request_open_borders(rival, human))

# --- A IA também pede ---------------------------------------------------------------------------------------------------------

func test_the_ai_asks_on_its_cadence_and_only_when_there_is_a_closed_border_to_open():
	var mine := _closed_city(human, Vector2i(-6, 0), "Capital")
	grid.found_city(Vector2i(6, 0), rival, "Sombria", true)
	# Cadência do par (rival = índice 1, jogador = 0): turno + 1*5 + 0*3 múltiplo de OPEN_BORDERS_REQUEST_INTERVAL.
	TurnManager.turn_number = RivalAI.OPEN_BORDERS_REQUEST_INTERVAL - 5
	mine.city_level = 1
	assert_eq(RivalAI.decide_open_borders(rival, human), "", "sem fronteira fechada do outro lado, não há o que pedir")
	mine.city_level = 2
	TurnManager.turn_number += 1
	assert_eq(RivalAI.decide_open_borders(rival, human), "", "fora da cadência")
	TurnManager.turn_number -= 1

	assert_eq(RivalAI.decide_open_borders(rival, human), Diplomacy.OPEN_BORDERS_OFFERED)

	assert_eq(Diplomacy.pending_open_borders_offers(human), [rival] as Array[PlayerData], "o jogador recebe o pedido")

func test_two_ai_realms_settle_it_between_themselves_at_once():
	_closed_city(third, Vector2i(0, 8), "Maré Alta")
	grid.found_city(Vector2i(6, 0), rival, "Sombria", true)
	# rival = 1, third = 2: turno + 5 + 6.
	TurnManager.turn_number = RivalAI.OPEN_BORDERS_REQUEST_INTERVAL * 2 - 11

	assert_eq(RivalAI.decide_open_borders(rival, third), Diplomacy.OPEN_BORDERS_ACCEPTED)

	assert_true(rival.has_open_borders_with(third) and third.has_open_borders_with(rival))
	assert_false(human.has_open_borders_with(rival), "só entre os dois")

func test_the_ai_never_asks_for_what_it_would_not_grant():
	_closed_city(human, Vector2i(-6, 0), "Capital")
	grid.found_city(Vector2i(6, 0), rival, "Sombria", true)
	TurnManager.turn_number = RivalAI.OPEN_BORDERS_REQUEST_INTERVAL - 5
	for index in 5:
		_unit(Vector2i(-8 + index, 4), human) # o exército do jogador assusta: ela mesma recusaria
	assert_eq(RivalAI.decide_open_borders(rival, human), "")
	assert_true(Diplomacy.pending_open_borders_offers(human).is_empty())

# --- Interface ---------------------------------------------------------------------------------------------------------------

func test_the_inspector_says_when_a_closed_border_is_open_by_agreement():
	var cities := _two_realms()
	assert_eq(TileInspector.closed_border_line(grid, cities[1], human), "Fronteiras fechadas: suas unidades não entram (só em guerra ou com fronteiras abertas).")
	Diplomacy.make_open_borders(human, rival)
	assert_eq(TileInspector.closed_border_line(grid, cities[1], human), "Fronteiras abertas por acordo: suas unidades podem entrar.")
	assert_eq(SelectionManager.closed_border_label(grid, cities[1].coord + Vector2i(-1, 0), human), "", "nada a avisar no hover")
	assert_eq(TileInspector.closed_border_line(grid, cities[1], third), "Fronteiras fechadas: suas unidades não entram (só em guerra ou com fronteiras abertas).")

func test_the_diplomacy_view_model_offers_the_right_action_and_forecast():
	_two_realms()
	_unit(Vector2i(-5, 3), human)
	_unit(Vector2i(5, 3), rival)
	var detail := DiplomacyPresenter.detail(human, rival)
	assert_true(detail.can_request_open_borders)
	assert_false(detail.has_open_borders)
	assert_eq(String(detail.open_borders_forecast), "", "a regra da IA é pública: devem aceitar")
	assert_true((detail.facts as Array).any(func(fact): return String(fact.caption) == "Fronteiras" and String(fact.text).begins_with("Fechadas")))

	Diplomacy.make_open_borders(human, rival)
	detail = DiplomacyPresenter.detail(human, rival)
	assert_true(detail.has_open_borders and detail.can_end_open_borders)
	assert_false(detail.can_request_open_borders)
	assert_true((detail.facts as Array).any(func(fact): return String(fact.caption) == "Fronteiras" and String(fact.text).begins_with("Abertas")))
	assert_has(DiplomacyPresenter.row(human, rival).alerts, "Fronteiras abertas")

	Diplomacy.declare_war(human, rival, "Fronteira", true)
	detail = DiplomacyPresenter.detail(human, rival)
	assert_false(detail.can_request_open_borders or detail.can_end_open_borders, "em guerra não há acordo a pedir")
