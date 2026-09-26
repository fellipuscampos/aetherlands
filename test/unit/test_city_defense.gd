extends GutTest

## Task 21 -- CIDADES: REACAO E DEFESA CONTRA MONSTROS (CityDefense.gd).
## Cobre: (1) nivel de ameaca PROPORCIONAL (assess), (2) producao emergencial
## da IA (RivalAI.decide_production), (3) mobilizacao de unidades (defend_turn
## via RivalAI.act_for_unit), (4) defesa propria da cidade -- Aetherlands V2,
## Fase 16: a milicia AUTOMATICA saiu; agora e' o Ataque da Cidade (acao
## explicita, cidade fortificada, IA com paridade tatica minima), (5) aviso ao jogador e (6) cenarios de ponta a ponta com
## esqueletos/goblins/troll/vivern. Harness espelha test_monster_ai.gd (grade
## plana + GameManager.players trocados).

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_players: Array[PlayerData]
var _original_world_events: Array[WorldEvent]
var _original_turn: int

func before_each():
	_original_turn = TurnManager.turn_number
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_players = GameManager.players
	_original_world_events = WorldEventManager.active_events
	WorldEventManager.active_events = []
	_created_units = []

	hex_grid = _build_flat_grid(12)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human
	GameManager.players = [human, rival]

func after_each():
	TurnManager.turn_number = _original_turn
	hex_grid.queue_free()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.players = _original_players
	WorldEventManager.active_events = _original_world_events
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()

func _build_flat_grid(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord = Vector2i(q, r)
			if HexMetrics.axial_distance(coord, Vector2i.ZERO) <= radius:
				grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return grid

func _make_monster(kind: String, coord: Vector2i, behavior: String = "") -> Unit:
	var monster := hex_grid.spawn_monster_at(coord, kind, false)
	monster.reset_movement()
	if behavior != "":
		monster.monster_behavior_state = behavior
	return monster

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	unit.reset_movement()
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func _all_visible() -> Dictionary:
	var visible := {}
	for coord in hex_grid.tiles.keys():
		visible[coord] = true
	return visible

func _assess(city: City) -> Dictionary:
	return CityDefense.assess(city, hex_grid)

# ---------------------------------------------------------------------------
# (1) Nivel de ameaca proporcional
# ---------------------------------------------------------------------------

func test_no_monsters_means_no_threat():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var assessment := _assess(city)
	assert_eq(assessment.level, 0.0)
	assert_eq(assessment.deficit, 0.0)
	assert_null(assessment.nearest)

func test_a_single_distant_goblin_stays_below_the_mobilize_level():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("goblin", Vector2i(5, 0))
	var assessment := _assess(city)
	assert_gt(assessment.level, 0.0, "um goblin no radio ainda e' percebido")
	assert_lt(assessment.gross_level, CityDefense.LEVEL_MOBILIZE, "um goblin solitario e distante nao deveria mobilizar tropas")
	assert_lt(assessment.level, CityDefense.LEVEL_EMERGENCY)

func test_several_skeletons_marching_on_the_city_are_an_emergency():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(3, 0), Vector2i(3, -1), Vector2i(4, -1)]:
		_make_monster("skeleton", coord)
	var assessment := _assess(city)
	assert_true(CityDefense.is_emergency(assessment), "3 esqueletos marchando a 3-4 tiles sem nenhuma guarnicao: emergencia. level=%.2f" % assessment.level)

func test_monsters_beyond_the_threat_radius_are_ignored():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(CityDefense.THREAT_RADIUS + 1, 0))
	assert_eq(_assess(city).level, 0.0)

func test_closer_monsters_are_more_threatening_than_far_ones():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var monster := _make_monster("skeleton", Vector2i(6, 0))
	var far_level: float = _assess(city).level
	hex_grid.move_unit(monster, Vector2i(2, 0), 0.0)
	assert_gt(_assess(city).level, far_level)

func test_stronger_monsters_are_more_threatening_than_weaker_ones_at_the_same_distance():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var monster := _make_monster("goblin", Vector2i(3, 0), MonsterDatabase.BEHAVIOR_INVADER)
	var goblin_level: float = _assess(city).level
	hex_grid.remove_unit(monster)
	_make_monster("troll", Vector2i(3, 0), MonsterDatabase.BEHAVIOR_INVADER)
	assert_gt(_assess(city).level, goblin_level, "mesmo comportamento e distancia: troll (mais forte) deveria pesar mais que goblin")

func test_more_monsters_are_more_threatening_than_one():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	var one: float = _assess(city).level
	_make_monster("skeleton", Vector2i(3, -1))
	assert_gt(_assess(city).level, one)

func test_own_garrison_lowers_the_net_level_but_not_the_gross_level():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	_make_monster("skeleton", Vector2i(3, -1))
	var alone := _assess(city)
	_make_unit("warrior", rival, Vector2i(1, 0))
	_make_unit("warrior", rival, Vector2i(0, 1))
	var garrisoned := _assess(city)
	assert_lt(garrisoned.level, alone.level)
	assert_lt(garrisoned.deficit, alone.deficit)
	assert_eq(garrisoned.gross_level, alone.gross_level, "a ameaca em si nao muda so' porque ha guarnicao")

func test_a_wounded_city_raises_the_level_of_the_same_threat():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	var healthy: float = _assess(city).level
	city.hp = city.max_hp() * 0.2
	assert_gt(_assess(city).level, healthy)

func test_a_nearby_live_lair_adds_pressure():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	var without_lair: float = _assess(city).level
	var lair_coord := Vector2i(0, -4)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "skeleton"
	_make_monster("skeleton", Vector2i(0, -5)) # guardiao vivo na area do covil
	assert_gt(_assess(city).level, without_lair)

func test_monsters_outside_the_visible_tiles_are_not_counted():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	assert_eq(CityDefense.assess(city, hex_grid, {}).level, 0.0, "monstro fora da nevoa nao deveria ser percebido")
	assert_gt(CityDefense.assess(city, hex_grid, _all_visible()).level, 0.0)

func test_stationary_camp_bosses_and_event_managed_monsters_are_not_mobile_threats():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var boss := hex_grid.spawn_monster_at(Vector2i(3, 0), "troll", true)
	assert_false(CityDefense.is_mobile_threat(boss), "boss do covil nunca sai de la'")
	var roaming := _make_monster("skeleton", Vector2i(3, -1))
	roaming.world_event_managed = true
	assert_false(CityDefense.is_mobile_threat(roaming), "o Dragao tem sistema proprio")
	assert_eq(_assess(city).level, 0.0)

# ---------------------------------------------------------------------------
# (2) Producao emergencial da IA
# ---------------------------------------------------------------------------

## Fase 25: a producao emergencial V1 (RivalAI.decide_production + compra rapida) saiu com o
## decisor V1; a IA V2 pesa a ameaca local na propria pontuacao (monstro visivel = hostil).
func test_v2_ai_sees_nearby_monsters_as_a_local_threat():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var calm := V2StrategicAI._city_threat_score(city, V2AIWorldView.capture(rival, hex_grid))
	for coord in [Vector2i(2, 0), Vector2i(2, -1), Vector2i(1, 1)]:
		_make_monster("skeleton", coord)
	assert_gt(V2StrategicAI._city_threat_score(city, V2AIWorldView.capture(rival, hex_grid)), calm)

func test_a_well_garrisoned_city_does_not_enter_emergency_production():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_monster("skeleton", Vector2i(3, 0))
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_make_unit("warrior", rival, coord)
	assert_false(CityDefense.is_emergency(_assess(city)))

# ---------------------------------------------------------------------------
# (3) Mobilizacao de unidades
# ---------------------------------------------------------------------------

func test_garrison_unit_sallies_out_and_attacks_an_approaching_skeleton():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	var skeleton := _make_monster("skeleton", Vector2i(3, 0))
	var hp_before := skeleton.hp
	RivalAI.act_for_unit(warrior, hex_grid, rival, human, _all_visible())
	assert_lt(skeleton.hp, hp_before, "a guarnicao deveria ir ao encontro do esqueleto e atacar no mesmo turno")
	assert_eq(city.owner_player, rival)

func test_defend_turn_ignores_a_lone_distant_goblin():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	_make_monster("goblin", Vector2i(5, 0))
	assert_false(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()), "goblin solitario e distante nao mobiliza o exercito")

func test_defend_turn_does_nothing_without_monsters():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	assert_false(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()))

func test_far_unit_is_called_as_reinforcement_when_the_garrison_is_not_enough():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(3, 0), Vector2i(3, -1), Vector2i(4, -1)]:
		_make_monster("skeleton", coord)
	var warrior := _make_unit("warrior", rival, Vector2i(7, 0))
	var before := HexMetrics.axial_distance(warrior.coord, Vector2i(3, 0))
	assert_true(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()))
	assert_lt(HexMetrics.axial_distance(warrior.coord, Vector2i(3, 0)), before, "reforco deveria se aproximar da ameaca")

func test_far_unit_is_not_called_when_the_garrison_already_covers_the_threat():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_make_unit("warrior", rival, coord)
	_make_monster("skeleton", Vector2i(3, 0))
	var reserve := _make_unit("warrior", rival, Vector2i(7, 0))
	assert_false(CityDefense.defend_turn(reserve, rival, hex_grid, _all_visible()), "guarnicao suficiente: o resto do exercito segue a vida normal")

func test_unit_beyond_the_mobilize_radius_is_never_called():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(3, 0), Vector2i(3, -1), Vector2i(4, -1)]:
		_make_monster("skeleton", coord)
	var warrior := _make_unit("warrior", rival, Vector2i(CityDefense.MOBILIZE_RADIUS + 2, 0))
	assert_false(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()))

func test_war_raises_the_bar_for_mobilizing_against_monsters():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	_make_monster("skeleton", Vector2i(3, 0))
	assert_true(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()), "pre-condicao: em paz, 1 esqueleto a 3 tiles mobiliza")
	Diplomacy.declare_war(human, rival)
	var warrior2 := _make_unit("warrior", rival, Vector2i(0, 1))
	assert_false(CityDefense.defend_turn(warrior2, rival, hex_grid, _all_visible()), "em guerra, uma ameaca pequena de monstro nao desvia a guarnicao")
	_make_monster("skeleton", Vector2i(3, -1))
	_make_monster("skeleton", Vector2i(2, 1))
	assert_true(CityDefense.defend_turn(warrior2, rival, hex_grid, _all_visible()), "em guerra, varios monstros ainda viram prioridade")

func test_badly_wounded_units_are_left_to_the_normal_retreat_logic():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	warrior.hp = warrior.unit_data.max_hp * 0.1
	_make_monster("skeleton", Vector2i(3, 0))
	assert_false(CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible()))

func test_non_combat_units_never_take_part():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var settler := _make_unit("settler", rival, Vector2i(1, 0))
	_make_monster("skeleton", Vector2i(3, 0))
	assert_false(CityDefense.defend_turn(settler, rival, hex_grid, _all_visible()))

func test_units_only_chase_monsters_within_the_engage_radius_of_the_city():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	var warrior := _make_unit("warrior", rival, Vector2i(1, 0))
	# Ameaca forte (varios) mas TODOS alem do ENGAGE_RADIUS: espera na cidade.
	for coord in [Vector2i(6, 0), Vector2i(6, -1), Vector2i(5, 1), Vector2i(5, 0)]:
		_make_monster("skeleton", coord, MonsterDatabase.BEHAVIOR_INVADER)
	CityDefense.defend_turn(warrior, rival, hex_grid, _all_visible())
	assert_lte(HexMetrics.axial_distance(warrior.coord, Vector2i.ZERO), CityDefense.GARRISON_RADIUS, "nunca persegue longe da cidade")

# ---------------------------------------------------------------------------
# (4) Defesa propria da cidade (Fase 16: a milicia automatica saiu)
# ---------------------------------------------------------------------------

## Cidade fortificada (Muralhas I: poder 3, alcance 2) sem passar pela producao.
func _fortified(city: City, level: int = 1) -> City:
	city.city_level = 2
	city.fortification_level = level
	return city

func test_the_automatic_militia_no_longer_exists():
	var defense := CityDefense.new()
	assert_false(defense.has_method("militia_strike"), "o dano automatico V1 foi substituido pelo Ataque da Cidade")
	assert_false(defense.has_method("militia_damage"))

func test_an_unfortified_city_never_damages_an_adjacent_monster_on_its_own():
	var city := hex_grid.found_city(Vector2i.ZERO, human, "Cidade")
	var skeleton := _make_monster("skeleton", Vector2i(1, 0))
	assert_eq(CityDefense.city_attack_targets(city, hex_grid), [] as Array[Unit], "sem fortificação, sem ação defensiva")
	assert_eq(CityDefense.ai_city_defense_turn(city, hex_grid), null)
	assert_eq(skeleton.hp, skeleton.unit_data.max_hp)

func test_the_ai_fortified_city_shoots_an_adjacent_monster_once_per_turn():
	var city := _fortified(hex_grid.found_city(Vector2i.ZERO, rival, "Cidade IA"))
	var skeleton := _make_monster("skeleton", Vector2i(1, 0))
	TurnManager.turn_number = 40
	assert_eq(CityDefense.ai_city_defense_turn(city, hex_grid), skeleton)
	assert_almost_eq(skeleton.unit_data.max_hp - skeleton.hp, 3.0, 0.001, "poder 3, dano fixo como a milícia antiga")
	assert_null(CityDefense.ai_city_defense_turn(city, hex_grid), "uma vez por turno")

func test_the_city_attack_never_touches_event_managed_monsters():
	var city := _fortified(hex_grid.found_city(Vector2i.ZERO, rival, "Cidade IA"))
	var dragonlike := _make_monster("skeleton", Vector2i(1, 0))
	dragonlike.world_event_managed = true
	assert_null(CityDefense.ai_city_defense_turn(city, hex_grid))

func test_the_city_attack_grants_no_reward():
	var city := _fortified(hex_grid.found_city(Vector2i.ZERO, rival, "Cidade IA"))
	rival.gold = 50.0
	var skeleton := _make_monster("skeleton", Vector2i(1, 0))
	skeleton.hp = 2.0
	TurnManager.turn_number = 41
	CityDefense.ai_city_defense_turn(city, hex_grid)
	assert_null(hex_grid.get_unit_at(Vector2i(1, 0)))
	assert_eq(rival.gold, 50.0, "sem recompensa: não é fonte de farm")

# ---------------------------------------------------------------------------
# (5) Aviso ao jogador
# ---------------------------------------------------------------------------

func test_warn_player_notifies_once_per_cooldown_window():
	var city := hex_grid.found_city(Vector2i.ZERO, human, "Cidade")
	for coord in [Vector2i(3, 0), Vector2i(3, -1), Vector2i(4, -1)]:
		_make_monster("skeleton", coord)
	watch_signals(EventBus)
	CityDefense.warn_player(human, hex_grid, _all_visible(), 10)
	assert_signal_emit_count(EventBus, "notify", 1)
	CityDefense.warn_player(human, hex_grid, _all_visible(), 11)
	assert_signal_emit_count(EventBus, "notify", 1, "nao repete o aviso dentro do cooldown")
	CityDefense.warn_player(human, hex_grid, _all_visible(), 10 + CityDefense.WARNING_COOLDOWN_TURNS)
	assert_signal_emit_count(EventBus, "notify", 2)
	assert_eq(city.last_monster_warning_turn, 10 + CityDefense.WARNING_COOLDOWN_TURNS)

func test_warn_player_stays_quiet_for_a_minor_threat():
	hex_grid.found_city(Vector2i.ZERO, human, "Cidade")
	_make_monster("goblin", Vector2i(5, 0))
	watch_signals(EventBus)
	CityDefense.warn_player(human, hex_grid, _all_visible(), 10)
	assert_signal_not_emitted(EventBus, "notify")

func test_warn_player_stays_quiet_when_the_garrison_covers_the_threat():
	hex_grid.found_city(Vector2i.ZERO, human, "Cidade")
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_make_unit("warrior", human, coord)
	_make_monster("skeleton", Vector2i(3, 0))
	watch_signals(EventBus)
	CityDefense.warn_player(human, hex_grid, _all_visible(), 10)
	assert_signal_not_emitted(EventBus, "notify")

# ---------------------------------------------------------------------------
# (6) Cenarios de ponta a ponta -- um turno completo simplificado:
# reset de movimento, IA rival, milicia das cidades, monstros.
# ---------------------------------------------------------------------------

func _run_turn(turn: int) -> void:
	for player in [human, rival]:
		for unit in player.units:
			unit.reset_movement()
	for unit in hex_grid.neutral_units():
		unit.reset_movement()
	TurnManager.turn_number = 1000 + turn
	RivalAI.take_turn(rival, hex_grid, human)
	# Fase 16: só a IA tem a paridade tática automática; o humano dispara explicitamente
	# (ver o cenário da cidade humana abaixo).
	for city in rival.cities.duplicate():
		CityDefense.ai_city_defense_turn(city, hex_grid)
	MonsterAI.take_turn(hex_grid, turn)

func _live_monsters() -> int:
	var count := 0
	for unit in hex_grid.neutral_units():
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			count += 1
	return count

func _scenario_report(label: String, turns: int) -> void:
	var monster_hp := []
	for unit in hex_grid.neutral_units():
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			monster_hp.append(snappedf(unit.hp, 0.1))
	print("[Task21] %s -> monstros vivos: %d (hp %s), tropas da IA vivas: %d, apos %d turnos" % [label, _live_monsters(), str(monster_hp), rival.units.size(), turns])

func test_scenario_skeleton_pack_against_a_defended_ai_city_is_repelled():
	var city := hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_unit("warrior", rival, Vector2i(1, 0))
	_make_unit("warrior", rival, Vector2i(0, 1))
	for coord in [Vector2i(6, 0), Vector2i(6, -1), Vector2i(5, 1)]:
		_make_monster("skeleton", coord)
	var turns := 0
	while turns < 12 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("3 esqueletos vs cidade com 2 guardas", turns)
	assert_eq(_live_monsters(), 0, "esqueletos avancando numa cidade guarnecida deveriam ser eliminados")
	assert_eq(city.owner_player, rival)

func test_scenario_skeleton_pack_against_an_ai_city_without_troops_is_worn_down_by_its_walls():
	var city := _fortified(hex_grid.found_city(Vector2i.ZERO, rival, "Cidade"))
	for coord in [Vector2i(5, 0), Vector2i(5, -1), Vector2i(4, 1)]:
		_make_monster("skeleton", coord)
	var turns := 0
	while turns < 20 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("3 esqueletos vs cidade sem tropa (so' Muralhas I)", turns)
	assert_lt(_live_monsters(), 3, "mesmo sem tropa a cidade deveria reduzir o cerco")
	assert_eq(city.owner_player, rival)

func test_scenario_goblin_raiders_are_engaged_by_the_garrison():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	_make_unit("warrior", rival, Vector2i(1, 0))
	_make_unit("warrior", rival, Vector2i(0, 1))
	_make_monster("goblin", Vector2i(4, 0), MonsterDatabase.BEHAVIOR_INVADER)
	_make_monster("goblin", Vector2i(4, -1), MonsterDatabase.BEHAVIOR_INVADER)
	var turns := 0
	while turns < 12 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("2 goblins invasores vs 2 guardas", turns)
	assert_eq(_live_monsters(), 0)

func test_scenario_troll_marching_on_a_garrisoned_city_is_fought():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_make_unit("warrior", rival, coord)
	var troll := _make_monster("troll", Vector2i(5, 0), MonsterDatabase.BEHAVIOR_INVADER)
	var turns := 0
	while turns < 15 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("troll invasor vs 3 guardas", turns)
	assert_true(_live_monsters() == 0 or troll.hp < troll.unit_data.max_hp, "a guarnicao deveria pelo menos ferir o troll")

func test_scenario_wyvern_hunter_near_a_garrisoned_city_is_fought():
	hex_grid.found_city(Vector2i.ZERO, rival, "Cidade")
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		_make_unit("warrior", rival, coord)
	var wyvern := _make_monster("wyvern", Vector2i(4, 0))
	var turns := 0
	while turns < 15 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("vivern vs 3 guardas", turns)
	assert_true(_live_monsters() == 0 or wyvern.hp < wyvern.unit_data.max_hp)

func test_scenario_two_ai_cities_each_defend_against_their_own_threat():
	var city_a := hex_grid.found_city(Vector2i(-8, 0), rival, "Cidade A")
	var city_b := hex_grid.found_city(Vector2i(8, 0), rival, "Cidade B")
	_make_unit("warrior", rival, Vector2i(-7, 0))
	_make_unit("warrior", rival, Vector2i(9, 0))
	_make_monster("skeleton", Vector2i(-5, 0))
	_make_monster("skeleton", Vector2i(5, 0))
	var turns := 0
	while turns < 12 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
	_scenario_report("duas cidades, um esqueleto cada", turns)
	assert_eq(_live_monsters(), 0)
	assert_eq(city_a.owner_player, rival)
	assert_eq(city_b.owner_player, rival)

func test_scenario_a_human_fortified_city_firing_each_turn_ends_a_lone_skeleton_siege():
	var city := _fortified(hex_grid.found_city(Vector2i.ZERO, human, "Cidade Humana"))
	var skeleton := _make_monster("skeleton", Vector2i(3, 0))
	var turns := 0
	while turns < 15 and _live_monsters() > 0:
		turns += 1
		_run_turn(turns)
		# O jogador usa o Ataque da Cidade explicitamente (sem dano automático).
		var targets := CityDefense.city_attack_targets(city, hex_grid)
		if not targets.is_empty():
			CityDefense.resolve_city_defense_attack(city, targets[0], hex_grid)
	_scenario_report("cidade do jogador, 1 esqueleto, sem tropas", turns)
	assert_eq(_live_monsters(), 0, "o Ataque da Cidade usado a cada turno deveria acabar com um esqueleto solitario")
	assert_eq(city.owner_player, human)
	assert_false(is_instance_valid(skeleton) and not skeleton.is_queued_for_deletion())
