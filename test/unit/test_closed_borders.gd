extends GutTest

## FRONTEIRAS FECHADAS (2026-10-13) — pedido do usuário: "após a primeira evolução da cidade, uma mecânica de
## fronteiras fechadas seja iniciada, você não pode mais entrar nas cidades alheias, nem eles nas suas, com exceção dos
## países que estão em guerra, aí você pode entrar na fronteira deles".
## Regra: o território de uma cidade com City Level >= 2 é fechado a quem não é o dono nem está em guerra com ele
## (HexGrid.closed_tiles_for); quem fica dentro quando a fronteira fecha é retirado (HexGrid.enforce_closed_borders).

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

## Cidade do rival em (6, 0) com o território = a cidade + os 6 vizinhos + mais um anel a leste, no nível pedido.
func _rival_city(level: int = 2) -> City:
	var city := grid.found_city(Vector2i(6, 0), rival, "Sombria", true)
	for coord in HexMetrics.coords_within(city.coord, 2):
		if grid.tiles.has(coord) and not coord in city.owned_tiles:
			city.owned_tiles.append(coord)
	city.city_level = level
	return city

func _inside(city: City) -> Vector2i:
	return city.coord + Vector2i(-1, 0)

func _outside_west(city: City) -> Vector2i:
	return city.coord + Vector2i(-3, 0)

# --- A regra de entrada -------------------------------------------------------------------------------------------------------

func test_a_first_level_city_keeps_its_borders_open():
	var city := _rival_city(1)
	var scout := _unit(_outside_west(city), human)
	assert_false(grid.city_has_closed_borders(city))
	assert_false(grid.is_border_closed_to(_inside(city), human))
	assert_true(grid.unit_reachable(scout).has(city.coord + Vector2i(-2, 0)), "antes de a cidade evoluir, o território é atravessável")
	assert_false(grid.unit_path(scout, _inside(city)).is_empty())

func test_after_the_first_evolution_foreign_units_at_peace_cannot_enter():
	var city := _rival_city(2)
	var scout := _unit(_outside_west(city), human)
	scout.movement_left = 6.0

	assert_true(grid.city_has_closed_borders(city))
	assert_true(grid.is_border_closed_to(_inside(city), human))
	assert_eq(grid.closed_border_city(_inside(city), human), city)
	var reach := grid.unit_reachable(scout)
	for coord in city.owned_tiles:
		assert_false(reach.has(coord), "%s é território fechado" % str(coord))
	assert_true(reach.has(_outside_west(city) + Vector2i(-1, 0)), "fora da fronteira o movimento é o de sempre")
	assert_true(grid.unit_path(scout, _inside(city)).is_empty(), "nem como destino de uma marcha longa")

func test_a_route_goes_around_closed_territory_instead_of_through_it():
	var city := _rival_city(2)
	var scout := _unit(_outside_west(city), human)
	var far_side: Vector2i = city.coord + Vector2i(3, 0)
	assert_false(far_side in city.owned_tiles, "pré-condição: o destino fica do outro lado, fora do território")

	var path := grid.unit_path(scout, far_side)

	assert_false(path.is_empty(), "há caminho: é só dar a volta")
	for step in path:
		assert_false(step in city.owned_tiles, "a rota não corta o território fechado (%s)" % str(step))
	assert_gt(path.size(), HexMetrics.axial_distance(scout.coord, far_side), "contornar custa mais que a linha reta")

func test_the_owner_moves_freely_inside_its_own_closed_borders():
	var city := _rival_city(2)
	var guard := _unit(_inside(city), rival)
	guard.movement_left = 4.0
	assert_false(grid.is_border_closed_to(_inside(city), rival))
	assert_true(grid.unit_reachable(guard).has(city.coord + Vector2i(1, 0)))

func test_war_opens_the_border_for_both_sides_and_peace_closes_it_again():
	var city := _rival_city(2)
	var mine := grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	mine.city_level = 2
	var soldier := _unit(_outside_west(city), human)
	var raider := _unit(mine.coord + Vector2i(2, 0), rival)
	assert_true(grid.is_border_closed_to(_inside(city), human) and grid.is_border_closed_to(mine.coord + Vector2i(1, 0), rival), "pré-condição: em paz, fechado dos dois lados")

	Diplomacy.declare_war(human, rival, "Fronteira", true)

	assert_false(grid.is_border_closed_to(_inside(city), human), "em guerra você entra na fronteira deles")
	assert_false(grid.is_border_closed_to(mine.coord + Vector2i(1, 0), rival), "e eles na sua")
	assert_false(grid.unit_path(soldier, _inside(city)).is_empty())
	assert_false(grid.unit_path(raider, mine.coord + Vector2i(1, 0)).is_empty())
	assert_true(grid.is_border_closed_to(_inside(city), third), "a guerra de dois não abre a fronteira para um terceiro")

	Diplomacy.make_peace(human, rival)

	assert_true(grid.is_border_closed_to(_inside(city), human), "com a paz a fronteira volta a valer")
	assert_true(grid.unit_path(soldier, _inside(city)).is_empty())

func test_monsters_are_never_stopped_by_a_border():
	var city := _rival_city(2)
	var monster := grid.spawn_monster_at(_outside_west(city), "goblin")
	assert_false(grid.is_border_closed_to(_inside(city), null))
	assert_false(grid.compute_path(monster.coord, _inside(city), null).is_empty(), "a ameaça do mundo não respeita fronteira")

## Uma unidade que ainda esteja na borda de dentro (a retirada não achou tile livre) dá o passo para fora, mas não
## anda por dentro do território.
func test_a_unit_on_the_inner_edge_can_step_out_but_not_walk_inside():
	var city := _rival_city(2)
	var edge: Vector2i = city.coord + Vector2i(-2, 0)
	var trapped := _unit(edge, human)
	trapped.movement_left = 6.0

	var reach := grid.unit_reachable(trapped)

	assert_true(reach.has(_outside_west(city)), "o passo para fora é permitido")
	assert_false(reach.has(_inside(city)), "mas não andar por dentro")
	for coord in city.owned_tiles:
		assert_false(reach.has(coord))

func test_flying_and_infiltrating_units_follow_the_same_border():
	var city := _rival_city(2)
	for profile in [UnitData.MovementProfile.FLYING, UnitData.MovementProfile.INFILTRATOR]:
		var unit := _unit(_outside_west(city), human)
		unit.unit_data.movement_profile = profile
		unit.movement_left = 6.0
		var reach := grid.unit_reachable(unit)
		for coord in city.owned_tiles:
			assert_false(reach.has(coord), "perfil %d não termina em território fechado (%s)" % [profile, str(coord)])
		assert_false(reach.is_empty(), "o resto do alcance continua")
		grid.remove_unit(unit)

func test_the_border_follows_the_territory_as_it_grows_and_the_level_as_it_changes():
	var city := _rival_city(1)
	var new_tile: Vector2i = city.coord + Vector2i(-3, 0)
	assert_false(grid.is_border_closed_to(_inside(city), human))

	city.apply_city_level(2)
	assert_true(grid.is_border_closed_to(_inside(city), human), "a evolução fecha na hora, sem nenhum gancho")
	assert_false(grid.is_border_closed_to(new_tile, human), "tile ainda sem dono")

	city.claim_tile(new_tile)
	assert_true(grid.is_border_closed_to(new_tile, human), "o tile anexado entra na fronteira")

# --- Retirada de quem ficou dentro ---------------------------------------------------------------------------------------------

func test_units_inside_are_withdrawn_when_the_city_evolves():
	var city := _rival_city(1)
	var visitor := _unit(_inside(city), human)
	var guest := _unit(city.coord + Vector2i(1, 0), third)
	var guard := _unit(city.coord + Vector2i(0, 1), rival)
	assert_true(grid.enforce_closed_borders().is_empty(), "fronteira aberta: ninguém sai")
	watch_signals(EventBus)

	city.apply_city_level(2)
	var withdrawn := grid.enforce_closed_borders()

	assert_eq(withdrawn.size(), 2, "os dois visitantes em paz")
	for unit in [visitor, guest]:
		assert_false(unit.coord in city.owned_tiles, "saiu do território")
		assert_eq(grid.get_unit_at(unit.coord), unit, "e está de fato no tile novo")
		assert_lte(HexMetrics.axial_distance(unit.coord, city.coord), 3, "o tile livre mais próximo, logo fora da fronteira")
	assert_eq(guard.coord, city.coord + Vector2i(0, 1), "o dono fica")
	assert_signal_emitted(EventBus, "notify", "o jogador é avisado da retirada das unidades dele")
	assert_true(grid.enforce_closed_borders().is_empty(), "idempotente")

func test_peace_withdraws_both_armies_from_each_other_closed_territory():
	var city := _rival_city(2)
	var mine := grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	mine.city_level = 2
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	var invader := _unit(_inside(city), human)
	var raider := _unit(mine.coord + Vector2i(1, 0), rival)
	assert_true(grid.enforce_closed_borders().is_empty(), "em guerra: ninguém é retirado")

	Diplomacy.make_peace(human, rival)

	assert_false(invader.coord in city.owned_tiles, "o exército sai do reino alheio com a paz")
	assert_false(raider.coord in mine.owned_tiles)
	assert_eq(grid.get_unit_at(invader.coord), invader)

func test_withdrawal_never_stacks_units_or_drops_them_in_another_closed_realm():
	var city := _rival_city(2)
	var other := grid.found_city(Vector2i(2, 0), third, "Maré Alta", true)
	other.city_level = 2
	# Um bloqueio de unidades do dono logo fora da fronteira, a oeste: a saída mais próxima está ocupada.
	var visitor := _unit(_inside(city), human)
	_unit(_outside_west(city), rival)

	grid.enforce_closed_borders()

	assert_false(grid.is_border_closed_to(visitor.coord, human), "nunca troca uma fronteira fechada por outra")
	assert_eq(grid.get_unit_at(visitor.coord), visitor, "nunca em cima de outra unidade")
	assert_null(grid.get_city_at(visitor.coord), "nem dentro de uma cidade alheia")

func test_a_captured_closed_city_withdraws_third_parties_but_not_the_enemy_of_the_new_owner():
	var city := _rival_city(2)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	Diplomacy.declare_war(third, rival, "Ambição", true)
	var ally_of_no_one := _unit(_inside(city), third) # em guerra com o dono ANTIGO; em paz com o jogador
	var old_owner_troop := _unit(city.coord + Vector2i(1, 0), rival)
	grid.found_city(Vector2i(0, 9), rival, "Refúgio", true) # o rival continua vivo depois da captura

	grid.capture_city(city, human)

	assert_false(ally_of_no_one.coord in city.owned_tiles, "em paz com o novo dono: retirado")
	assert_eq(old_owner_troop.coord, city.coord + Vector2i(1, 0), "em guerra com o novo dono: pode ficar")

func test_the_turn_cycle_enforces_the_border():
	var city := _rival_city(2)
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	grid.found_city(Vector2i(0, 9), third, "Maré Alta", true)
	var leftover := _unit(_inside(city), human)
	leftover.movement_left = 0.0

	TurnManager.end_turn()

	assert_false(leftover.coord in city.owned_tiles, "ninguém começa o turno dentro de uma fronteira fechada a ele")

# --- Interface ----------------------------------------------------------------------------------------------------------------

func test_the_tile_inspector_and_hover_explain_the_border():
	var city := _rival_city(2)
	assert_eq(TileInspector.closed_border_line(grid, city, human), "Fronteiras fechadas: suas unidades não entram (só em guerra ou com fronteiras abertas).")
	assert_eq(TileInspector.closed_border_line(grid, city, rival), "Fronteiras fechadas: outros reinos só entram em guerra com você.")
	assert_eq(SelectionManager.closed_border_label(grid, _inside(city), human), "FRONTEIRA FECHADA — Crepúsculo")
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	assert_eq(TileInspector.closed_border_line(grid, city, human), "Fronteiras fechadas — em guerra: suas unidades podem entrar.")
	assert_eq(SelectionManager.closed_border_label(grid, _inside(city), human), "", "em guerra não há o que avisar")
	city.city_level = 1
	assert_eq(TileInspector.closed_border_line(grid, city, human), "", "cidade que ainda não evoluiu: fronteira aberta")

func test_ordering_a_march_into_a_closed_border_explains_why_and_gives_no_order():
	var city := _rival_city(2)
	var scout := _unit(_outside_west(city) + Vector2i(-2, 0), human)
	watch_signals(EventBus)

	var queued := SelectionManager._try_queue_move_order(scout, _inside(city))

	assert_false(queued)
	assert_eq(scout.move_order_target, Unit.NO_MOVE_ORDER, "nenhuma ordem de marcha")
	assert_signal_emitted(EventBus, "notify")
	assert_true(String(get_signal_parameters(EventBus, "notify", 0)[0]).contains("Fronteiras fechadas"))

# --- Custo ----------------------------------------------------------------------------------------------------------------------

func test_the_closed_tile_map_is_reused_until_something_changes():
	var city := _rival_city(2)
	var first := grid.closed_tiles_for(human)
	assert_same(grid.closed_tiles_for(human), first, "mesma situação: o mesmo mapa, sem remontar")
	city.claim_tile(city.coord + Vector2i(-3, 0))
	var grown := grid.closed_tiles_for(human)
	assert_ne(grown.size(), first.size(), "território cresceu: mapa novo")
	assert_same(grid.closed_tiles_for(human), grown)
	assert_true(grid.closed_tiles_for(null).is_empty())
	assert_true(grid.closed_tiles_for(rival).is_empty(), "o dono não tem fronteira fechada contra si")
