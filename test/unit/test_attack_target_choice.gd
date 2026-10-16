extends GutTest

## ESCOLHER O ALVO DO ATAQUE (2026-10-13) — pedido do usuário: "se tem um inimigo em cima de alguma guarnição que tem
## vida, nesse exemplo a cidade, ao tentar atacar aquele tile eu acabo atacando o inimigo, o que pode ser usado como
## técnica para proteger a cidade. Faça que caso tenha uma tropa acima, eu possa escolher em quem estou atacando, a
## cidade ou a tropa".

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var city: City
var garrison: Unit
var attacker: Unit
var _requests: Array = []
var _listener: Callable
var _original := {}

const CITY_COORD := Vector2i(3, 0)
const ATTACKER_COORD := Vector2i(2, 0)

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora")
	rival = _player("Crepúsculo")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 10
	grid.found_city(Vector2i(-6, 0), human, "Capital", true)
	grid.found_city(Vector2i(0, 6), rival, "Refúgio", true) # o rival continua vivo se perder a outra cidade
	city = grid.found_city(CITY_COORD, rival, "Sombria", true)
	garrison = grid.spawn_unit(CITY_COORD, UnitDatabase.create_unit("warrior"), rival)
	attacker = grid.spawn_unit(ATTACKER_COORD, UnitDatabase.create_unit("warrior"), human)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	_requests.clear()
	_listener = func(unit: Unit, coord: Vector2i): _requests.append([unit, coord])

func after_each():
	if EventBus.attack_target_choice_requested.is_connected(_listener):
		EventBus.attack_target_choice_requested.disconnect(_listener)
	SelectionManager.reset()
	for player in [human, rival]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _player(civ_name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	return PlayerData.new(civ)

## Uma interface escutando o pedido de escolha (como o AttackTargetChoicePresenter no jogo).
func _with_ui() -> void:
	EventBus.attack_target_choice_requested.connect(_listener)

func _select_and_attack() -> void:
	SelectionManager._select_unit(attacker)
	SelectionManager._attack_from_selected(CITY_COORD)

# --- A escolha -----------------------------------------------------------------------------------------------------------------

func test_a_garrisoned_city_offers_both_targets():
	var targets := SelectionManager.attack_targets_at(attacker, CITY_COORD, grid)
	assert_eq(targets.unit, garrison)
	assert_eq(targets.city, city)
	SelectionManager._select_unit(attacker)
	assert_has(SelectionManager.attackable, CITY_COORD)
	assert_eq(SelectionManager._attack_target_name(grid, CITY_COORD), "%s ou Sombria" % garrison.unit_data.unit_name, "o hover já avisa que há dois alvos")

func test_attacking_the_tile_asks_before_anything_happens():
	_with_ui()
	var city_hp := city.hp
	var garrison_hp := garrison.hp

	_select_and_attack()

	assert_eq(_requests.size(), 1, "o jogo pergunta em quem bater")
	assert_eq(_requests[0], [attacker, CITY_COORD])
	assert_eq(SelectionManager.attack_choice_coord, CITY_COORD)
	assert_eq(city.hp, city_hp, "nada foi atacado ainda")
	assert_eq(garrison.hp, garrison_hp)
	assert_gt(attacker.movement_left, 0.0, "nem a ação foi gasta")

func test_choosing_the_city_hits_the_city_and_spares_the_garrison():
	_with_ui()
	var city_total := city.hp + city.shield
	var garrison_hp := garrison.hp
	var attacker_hp := attacker.hp
	_select_and_attack()

	assert_true(SelectionManager.choose_attack_target(SelectionManager.ATTACK_TARGET_CITY))

	assert_lt(city.hp + city.shield, city_total, "a cidade leva o golpe")
	assert_eq(garrison.hp, garrison_hp, "a tropa em cima não é tocada: ela não serve mais de escudo")
	assert_eq(attacker.hp, attacker_hp, "a cidade não revida")
	assert_eq(attacker.movement_left, 0.0, "o ataque gasta a ação")
	assert_eq(SelectionManager.attack_choice_coord, City.NO_PENDING_COORD)
	assert_false(SelectionManager.choose_attack_target(SelectionManager.ATTACK_TARGET_CITY), "a escolha vale uma vez")

func test_choosing_the_unit_fights_the_garrison_and_spares_the_city():
	_with_ui()
	var city_total := city.hp + city.shield
	var garrison_hp := garrison.hp
	_select_and_attack()

	assert_true(SelectionManager.choose_attack_target(SelectionManager.ATTACK_TARGET_UNIT))

	assert_true(not is_instance_valid(garrison) or garrison.is_queued_for_deletion() or garrison.hp < garrison_hp, "a tropa leva o golpe")
	assert_eq(city.hp + city.shield, city_total, "a cidade fica intacta")
	assert_eq(attacker.movement_left, 0.0)

func test_cancelling_the_choice_costs_nothing():
	_with_ui()
	var city_total := city.hp + city.shield
	var garrison_hp := garrison.hp
	_select_and_attack()

	assert_true(SelectionManager.decline_attack_target())

	assert_eq(city.hp + city.shield, city_total)
	assert_eq(garrison.hp, garrison_hp)
	assert_gt(attacker.movement_left, 0.0, "a unidade continua com a ação")
	assert_eq(SelectionManager.selected_unit, attacker, "e selecionada")
	assert_false(SelectionManager.decline_attack_target(), "nada pendente")
	assert_false(SelectionManager.choose_attack_target(SelectionManager.ATTACK_TARGET_CITY), "nem para escolher depois de cancelar")

func test_a_single_target_never_asks():
	_with_ui()
	grid.remove_unit(garrison)
	var city_total := city.hp + city.shield
	SelectionManager._select_unit(attacker)
	SelectionManager._attack_from_selected(CITY_COORD)
	assert_true(_requests.is_empty(), "só a cidade: ataca direto, como sempre")
	assert_lt(city.hp + city.shield, city_total)

	var lone := grid.spawn_unit(Vector2i(2, 1), UnitDatabase.create_unit("warrior"), rival)
	var second := grid.spawn_unit(Vector2i(1, 1), UnitDatabase.create_unit("warrior"), human)
	var lone_hp := lone.hp
	SelectionManager._select_unit(second)
	SelectionManager._attack_from_selected(lone.coord)
	assert_true(_requests.is_empty(), "só a tropa: ataca direto")
	assert_true(not is_instance_valid(lone) or lone.is_queued_for_deletion() or lone.hp < lone_hp)

func test_without_an_interface_the_attack_keeps_its_usual_target():
	var city_total := city.hp + city.shield
	var garrison_hp := garrison.hp
	_select_and_attack()
	assert_eq(city.hp + city.shield, city_total, "sem ninguém para perguntar, vale a tropa (comportamento de sempre)")
	assert_true(not is_instance_valid(garrison) or garrison.is_queued_for_deletion() or garrison.hp < garrison_hp)

# --- A cidade cai com a guarnição dentro -----------------------------------------------------------------------------------------

func test_capturing_the_city_makes_the_garrison_fall_back_instead_of_staying_inside():
	_with_ui()
	city.hp = 0.5
	city.shield = 0.0
	var garrison_hp := garrison.hp
	_select_and_attack()

	SelectionManager.choose_attack_target(SelectionManager.ATTACK_TARGET_CITY)

	assert_eq(city.owner_player, human, "pré-condição: a cidade caiu")
	assert_true(is_instance_valid(garrison) and not garrison.is_queued_for_deletion(), "a guarnição sobrevive")
	assert_ne(garrison.coord, CITY_COORD, "mas não fica dentro da cidade que mudou de dono")
	assert_eq(HexMetrics.axial_distance(garrison.coord, CITY_COORD), 1, "recua para o tile livre mais próximo")
	assert_eq(grid.get_unit_at(garrison.coord), garrison)
	assert_null(grid.get_unit_at(CITY_COORD))
	assert_eq(garrison.hp, garrison_hp, "recuar não custa vida")
	assert_eq(garrison.owner_player, rival)

func test_a_garrison_with_nowhere_to_fall_back_is_lost_with_the_city():
	# Um mapa de dois tiles: a cidade e o tile do atacante. Não existe para onde recuar.
	var tiny := HexGrid.new()
	add_child_autofree(tiny)
	GameManager.hex_grid = tiny
	for coord in [Vector2i(0, 0), Vector2i(1, 0)]:
		tiny.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var doomed_city := tiny.found_city(Vector2i(0, 0), rival, "Beco", true)
	var doomed := tiny.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), rival)
	tiny.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), human)

	tiny.capture_city(doomed_city, human)

	assert_true(doomed.is_queued_for_deletion(), "sem tile livre, cai junto")
	assert_null(tiny.get_unit_at(Vector2i(0, 0)))
	assert_false(doomed in rival.units)

func test_the_owner_garrison_stays_when_its_own_side_takes_the_city_back():
	var mine := grid.spawn_unit(Vector2i(-6, 0), UnitDatabase.create_unit("warrior"), human)
	var capital: City = grid.get_city_at(Vector2i(-6, 0))
	grid.capture_city(capital, human) # mesmo dono: nada a retirar
	assert_eq(mine.coord, Vector2i(-6, 0))

# --- A conta e a IA --------------------------------------------------------------------------------------------------------------

func test_the_forecast_is_the_same_arithmetic_as_the_real_attack():
	var forecast := CombatResolver.predict_city_attack(attacker, city)
	var shield_before := city.shield
	var hp_before := city.hp

	CombatResolver.resolve_city_attack(attacker, city, grid)

	assert_almost_eq(shield_before - city.shield, float(forecast.shield_damage), 0.0001)
	assert_almost_eq(hp_before - city.hp, float(forecast.hp_damage), 0.0001)
	assert_almost_eq(float(forecast.damage), float(forecast.shield_damage) + float(forecast.hp_damage), 0.0001)
	assert_false(forecast.captures)
	city.hp = 0.5
	city.shield = 0.0
	assert_true(CombatResolver.predict_city_attack(attacker, city).captures)
	assert_string_contains(AttackTargetChoicePresenter.city_forecast(attacker, city), "captura a cidade")

func test_the_ai_no_longer_lets_a_strong_garrison_shield_the_city():
	# O jogador guarnece a própria capital com uma tropa forte demais para o atacante da IA.
	var capital: City = grid.get_city_at(Vector2i(-6, 0))
	var wall := grid.spawn_unit(capital.coord, UnitDatabase.create_unit("warrior"), human)
	wall.unit_data.defense = 60.0
	wall.unit_data.max_hp = 200.0
	wall.hp = 200.0
	var raider := grid.spawn_unit(capital.coord + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	assert_false(RivalAI.is_favorable_attack(raider, wall, grid), "pré-condição: lutar com a guarnição é mau negócio")
	var city_total := capital.hp + capital.shield

	RivalAI._engage(raider, grid, capital.coord)

	assert_lt(capital.hp + capital.shield, city_total, "a IA bate na cidade em vez de desistir")
	assert_almost_eq(wall.hp, 200.0, 0.0001)

func test_the_ai_takes_the_city_when_one_blow_captures_it_and_fights_a_weak_garrison_otherwise():
	var capital: City = grid.get_city_at(Vector2i(-6, 0))
	var weak := grid.spawn_unit(capital.coord, UnitDatabase.create_unit("warrior"), human)
	weak.hp = 1.0
	var raider := grid.spawn_unit(capital.coord + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	var city_total := capital.hp + capital.shield

	RivalAI._engage(raider, grid, capital.coord)

	assert_eq(capital.hp + capital.shield, city_total, "guarnição fraca e cidade inteira: luta com a tropa")
	assert_true(weak.is_queued_for_deletion() or weak.hp < 1.0)

	var keeper := grid.spawn_unit(capital.coord, UnitDatabase.create_unit("warrior"), human) if grid.get_unit_at(capital.coord) == null else grid.get_unit_at(capital.coord)
	capital.hp = 0.5
	capital.shield = 0.0
	raider.reset_movement()
	grid.found_city(Vector2i(-2, -5), human, "Colônia", true) # o jogador segue vivo depois de perder a capital

	RivalAI._engage(raider, grid, capital.coord)

	assert_eq(capital.owner_player, rival, "um golpe captura: a IA toma a cidade")
	assert_ne(keeper.coord, capital.coord, "e a guarnição recua")

# --- Foco visual: a cidade refaz o visual ao mudar de dono com uma tropa em cima ------------------------------------------------

## Achado na conferência em jogo: capturar uma cidade guarnecida liberava as malhas antigas da cidade (o visual é
## refeito na troca de dono) enquanto o foco visual ainda as tinha como "esmaecidas por causa da tropa em cima"; ao
## devolvê-las, atribuir a instância liberada a uma variável tipada era erro de script e abortava o resto da lista.
func test_visual_focus_skips_freed_meshes_and_still_restores_the_live_ones():
	var freed := MeshInstance3D.new()
	freed.free()
	var alive := MeshInstance3D.new()
	add_child_autofree(alive)
	alive.transparency = 0.6

	grid.visual_focus._set_transparency([[freed, 0.0], [alive, 0.0]], false, false)

	assert_almost_eq(alive.transparency, 0.0, 0.0001, "a malha viva depois da liberada é restaurada do mesmo jeito")

func test_capturing_a_garrisoned_city_leaves_the_visual_focus_consistent():
	grid.visual_focus.refresh() # a tropa em cima da cidade entra no foco
	city.hp = 0.5
	city.shield = 0.0

	CombatResolver.resolve_city_attack(attacker, city, grid)
	grid.visual_focus.refresh()

	assert_eq(city.owner_player, human, "pré-condição: capturada com a guarnição dentro")
	assert_null(grid.get_unit_at(CITY_COORD))
	for pair in grid.visual_focus._applied.get(CITY_COORD, {}).get("structure", []):
		assert_true(is_instance_valid(pair[0]), "nenhuma malha liberada fica registrada no foco")
