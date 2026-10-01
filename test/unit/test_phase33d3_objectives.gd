extends GutTest

## Fase 33D3 — nova regra territorial da Supremacia (A–J), Strategic Imperatives (derivados) e marcos públicos
## (Exército Supremo, segunda Manifestação distinta).

const SAVE_PATH := "user://test_phase33d3_objectives.json"
const SMALL_MAP := 61
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"
const SACRED_RITUAL := "v2_building_sacred_ritual"

var _original := {}
var grid: HexGrid
var attacker: PlayerData
var rival: PlayerData
var _real_grid: HexGrid
var _published: Array = []
var _capture_callable: Callable

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	_published.clear()
	_capture_callable = func(event: UIEventData): _published.append(event)
	UIEvents.event_published.connect(_capture_callable)

func after_each():
	if UIEvents.event_published.is_connected(_capture_callable):
		UIEvents.event_published.disconnect(_capture_callable)
	if _real_grid != null and is_instance_valid(_real_grid):
		await BalanceMatchRunner.teardown_match(self, _real_grid)
	_real_grid = null
	V2AITacticalAI.clear_views()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

func _world() -> void:
	grid = HexGrid.new()
	grid._ready()
	for q in range(-16, 17):
		for r in range(-16, 17):
			if absi(q + r) <= 16:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	attacker = _player("Conquistador")
	rival = _player("Elenor")
	GameManager.players = [attacker, rival] as Array[PlayerData]
	GameManager.human_player = attacker
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 90
	grid.found_city(Vector2i(-12, 0), attacker, "Base", true)

## Cidades do rival com os níveis dados (a primeira é a capital dele).
func _rival_cities(levels: Array) -> Array[City]:
	var cities: Array[City] = []
	var coords := [Vector2i(8, 0), Vector2i(4, 8), Vector2i(12, -8), Vector2i(0, -10)]
	for i in levels.size():
		var city := grid.found_city(coords[i], rival, "Cidade %d" % (i + 1), true)
		city.city_level = int(levels[i])
		cities.append(city)
	return cities

func _satisfied() -> bool:
	return V2VictoryConditions.rival_satisfied_by_conquest(attacker, rival)

# --- Supremacia: regra nova --------------------------------------------------------------------------

func test_a_b_capturing_the_highest_level_qualifies_and_a_lower_one_does_not():
	_world()
	var cities := _rival_cities([3, 2, 1])
	grid.capture_city(cities[1], attacker)
	assert_false(_satisfied(), "B: Cidade II com Cidade III no reino não qualifica")
	grid.capture_city(cities[0], attacker)
	assert_true(_satisfied(), "A: Cidade III = maior nível → qualifica")

func test_c_d_ties_all_qualify_and_the_capital_is_not_the_only_valid_one():
	_world()
	var cities := _rival_cities([2, 2, 1])
	grid.capture_city(cities[1], attacker)
	assert_true(_satisfied(), "C/D: a Cidade II que não é capital qualifica no empate")
	_world()
	cities = _rival_cities([2, 2, 1])
	grid.capture_city(cities[0], attacker)
	assert_true(_satisfied(), "D: a capital II também qualifica")

func test_e_a_rival_with_only_city_i_is_satisfiable():
	_world()
	var cities := _rival_cities([1, 1])
	grid.capture_city(cities[1], attacker)
	assert_true(_satisfied(), "E: sem Cidade III no reino, a maior (I) qualifica — antes era impossível")

func test_f_later_development_never_invalidates_a_capture():
	_world()
	var cities := _rival_cities([2, 2, 1])
	grid.capture_city(cities[0], attacker)
	cities[2].city_level = 3
	assert_true(_satisfied(), "F: o máximo posterior do rival não reavalia a captura")

func test_g_recapture_keeps_the_existing_ownership_semantics():
	_world()
	var cities := _rival_cities([3, 1])
	grid.capture_city(cities[0], attacker)
	assert_true(_satisfied())
	grid.capture_city(cities[0], rival)
	assert_false(_satisfied(), "G: perder a cidade qualificada desfaz a condição (semântica da Fase 16)")
	grid.capture_city(cities[0], attacker)
	assert_true(_satisfied(), "G: reconquistá-la volta a satisfazer se ela ainda for o maior nível do rival")

func test_h_elimination_satisfies():
	_world()
	var cities := _rival_cities([1])
	grid.capture_city(cities[0], attacker)
	var status := V2VictoryConditions.military_supremacy_status(attacker)
	assert_true(bool(status.rivals[0].satisfied))
	assert_eq(String(status.rivals[0].reason), V2VictoryConditions.REASON_ELIMINATED, "H: rival sem cidades nem unidades = eliminado")

func test_i_hidden_city_is_never_a_suggested_target():
	_world()
	var cities := _rival_cities([2, 3])
	# O jogador só viu a Cidade II; a Cidade III existe mas nunca foi observada.
	attacker.remember_enemy_city(cities[0])
	var targets := V2VictoryConditions.known_supremacy_targets(attacker, rival, grid)
	assert_eq(targets.size(), 1)
	assert_eq(targets[0].coord, cities[0].coord, "I: só a cidade conhecida")
	for player in [attacker]:
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
		assert_true(player.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	var imperative := StrategicImperatives.supremacy(attacker, grid)
	assert_eq(String(imperative.next), "Alvo relevante conhecido: %s (%s)." % [cities[0].city_name, rival.civ.civ_name])
	assert_false(String(imperative.next).contains(cities[1].city_name), "a cidade escondida mais desenvolvida nunca aparece")
	Diplomacy.declare_war(attacker, rival, "Teste", true)
	var view := V2AIWorldView.capture(attacker, grid)
	assert_eq(V2StrategicAI.supremacy_target_coord(attacker, view), cities[0].coord, "IA: alvo = maior nível CONHECIDO")
	attacker.known_enemy_cities.clear()
	attacker.known_enemy_city_levels.clear()
	imperative = StrategicImperatives.supremacy(attacker, grid)
	assert_eq(String(imperative.next), "Explore o território de %s para identificar um centro estratégico." % rival.civ.civ_name)

func test_j_supremacy_progress_and_known_levels_survive_save_and_load():
	var config := BalanceSeedSet.match_config(1, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	_real_grid = BalanceMatchRunner.setup_match(self, config)
	var a: PlayerData = GameManager.players[0]
	var b: PlayerData = GameManager.players[1]
	var city: City = b.cities[0]
	a.remember_enemy_city(city)
	_real_grid.capture_city(city, a)
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(a, b))
	var c: PlayerData = GameManager.players[2]
	a.remember_enemy_city(c.cities[0])
	var level_before := int(a.known_enemy_city_levels[c.cities[0].coord])
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH))
	a = GameManager.players[0]
	b = GameManager.players[1]
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(a, b), "J: progresso mantido")
	assert_eq(int(a.known_enemy_city_levels.get(GameManager.players[2].cities[0].coord, -1)), level_before, "nível observado mantido")

func test_the_capital_breaks_ties_between_known_cities_of_the_same_level():
	_world()
	var cities := _rival_cities([2, 2])
	attacker.remember_enemy_city(cities[1])
	attacker.remember_enemy_city(cities[0])
	var targets := V2VictoryConditions.known_supremacy_targets(attacker, rival, grid)
	assert_eq(targets[0].coord, cities[0].coord, "capital conhecida primeiro no empate")
	assert_true(bool(targets[0].capital))

func test_the_rule_is_centralized():
	var hex := FileAccess.get_file_as_string("res://scripts/world/HexGrid.gd")
	assert_true(hex.contains("V2VictoryConditions.is_supremacy_qualifying_city(city, old_owner)"))
	for path in ["res://scripts/core/V2StrategicAI.gd", "res://scripts/core/StrategicImperatives.gd", "res://scripts/ui/presenters/VictoryPresenter.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("max_city_level("), "%s não reimplementa a regra" % path)

# --- Imperativos ---------------------------------------------------------------------------------

func test_supremacy_imperative_lists_every_rival_state():
	_world()
	var third := _player("Clãs de Ferro")
	GameManager.players = [attacker, rival, third] as Array[PlayerData]
	var cities := _rival_cities([1])
	grid.found_city(Vector2i(0, 12), third, "Forja", true)
	grid.spawn_unit(Vector2i(1, 12), UnitDatabase.create_unit("warrior"), third)
	grid.capture_city(cities[0], attacker)
	var imperative := StrategicImperatives.supremacy(attacker, grid)
	assert_eq(String(imperative.title), "Prove sua supremacia")
	assert_true((imperative.lines as Array).has("Elenor — eliminado"))
	assert_true((imperative.lines as Array).has("Clãs de Ferro — alvo militar pendente"))
	assert_eq(String(imperative.step), "research", "sem Exército Supremo, o próximo passo é a pesquisa")

func test_transcendence_imperative_returns_the_next_real_gate():
	_world()
	var steps: Array = []
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	attacker.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	attacker.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	assert_true(attacker.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	var city: City = attacker.cities[0]
	city.buildings[SACRED_RITUAL] = true
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	grid.spawn_unit(Vector2i(-11, 2), UnitDatabase.create_unit(SERAPH), attacker)
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	grid.spawn_unit(Vector2i(-11, 3), UnitDatabase.create_unit(ARCHDEMON), attacker)
	attacker.mana = 0.0
	steps.append(String(StrategicImperatives.transcendence(attacker).step))
	attacker.mana = V2TranscendenceSystem.MANA_COST
	var start := StrategicImperatives.transcendence(attacker)
	steps.append(String(start.step))
	assert_eq(steps, ["schools", "research", "structure", "first_manifestation", "second_manifestation", "mana", "start"], "ordem real do runtime")
	assert_eq(V2TranscendenceSystem.start_unavailable_reason(attacker, city), "", "o 'iniciar' do imperativo bate com o runtime")
	assert_true(V2TranscendenceSystem.start_ritual(attacker, city))
	assert_eq(String(StrategicImperatives.transcendence(attacker).step), "maintain")

func test_domination_imperative_counts_remaining_kingdoms():
	_world()
	_rival_cities([1])
	assert_eq(String(StrategicImperatives.domination(attacker).next), "Restam 1 reino(s) rival(is).")

func test_imperatives_are_derived_and_identical_after_save_and_load():
	var config := BalanceSeedSet.match_config(2, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	_real_grid = BalanceMatchRunner.setup_match(self, config)
	var player: PlayerData = GameManager.players[0]
	player.remember_enemy_city(GameManager.players[1].cities[0])
	var before := StrategicImperatives.for_player(player, _real_grid)
	assert_true(SaveManager.save_game(_real_grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_false(JSON.stringify(data).contains("Prove sua supremacia"), "nada do imperativo é salvo")
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(_real_grid, SAVE_PATH))
	BalanceMatchRunner.apply_seat_identity(config) # o save do jogo não guarda os nomes de assento do laboratório
	var after := StrategicImperatives.for_player(GameManager.players[0], _real_grid)
	for i in before.size():
		assert_eq(JSON.stringify(after[i]), JSON.stringify(before[i]), "imperativo %d igual após o load" % i)
	assert_false(FileAccess.get_file_as_string("res://scripts/core/StrategicImperatives.gd").contains("var "+"_"), "sem estado")

# --- Marcos públicos ------------------------------------------------------------------------------

func _four_civs() -> Array[PlayerData]:
	_world()
	var extra: Array[PlayerData] = [attacker, rival, _player("Clãs de Ferro"), _player("Clãs Primordiais")]
	GameManager.players = extra
	for index in extra.size():
		if extra[index].cities.is_empty():
			grid.found_city(Vector2i(-12 + 8 * index, 10), extra[index], "Capital %d" % index, true)
	return extra

func test_supreme_army_is_announced_once_to_everyone_without_location():
	var players := _four_civs()
	var city := rival.cities[0]
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
	assert_true(rival.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	PublicVictoryMilestones.evaluate_round(players, 90)
	PublicVictoryMilestones.evaluate_round(players, 91)
	var events := _published.filter(func(e): return e.event_type == "public_milestone")
	assert_eq(events.size(), 1, "uma vez")
	assert_eq(events[0].title, "Elenor concluiu o Exército Supremo.")
	assert_eq(events[0].message, "Seus exércitos agora podem disputar a Supremacia Militar.")
	assert_false(events[0].has_target_coord, "sem localização")
	for word in ["Guardião", "Guerreiro", city.city_name]:
		assert_false(String(events[0].title + events[0].message).contains(word), "sem Doutrina/cidade: %s" % word)
	var view := V2AIWorldView.capture(attacker, grid)
	assert_true(view.has_public_milestone(1, PublicVictoryMilestones.SUPREME_ARMY), "fato público para a IA")
	assert_true(SaveManager._valid_world_events(JSON.parse_string(JSON.stringify(WorldEventManager.to_save_dict()))))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(WorldEventManager.to_save_dict()))
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(saved)
	PublicVictoryMilestones.evaluate_round(players, 92)
	assert_eq(_published.filter(func(e): return e.event_type == "public_milestone").size(), 1, "sem repetição após save/load")

func test_second_manifestation_is_announced_once_even_if_one_dies_and_returns():
	var players := _four_civs()
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "sacred")
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "infernal")
	grid.spawn_unit(Vector2i(5, 2), UnitDatabase.create_unit(SERAPH), rival)
	PublicVictoryMilestones.evaluate_round(players, 90)
	assert_eq(_published.filter(func(e): return e.event_type == "public_milestone").size(), 0, "uma Manifestação não é marco")
	var demon := grid.spawn_unit(Vector2i(5, 3), UnitDatabase.create_unit(ARCHDEMON), rival)
	PublicVictoryMilestones.evaluate_round(players, 91)
	var events := _published.filter(func(e): return e.event_type == "public_milestone")
	assert_eq(events.size(), 1)
	assert_eq(events[0].title, "Duas grandes Manifestações servem a Elenor.")
	for word in ["Sagrada", "Infernal", "Serafim", "Arquidemônio"]:
		assert_false(String(events[0].title + events[0].message).contains(word), "sem Escola/unidade")
	grid.remove_unit(demon)
	PublicVictoryMilestones.evaluate_round(players, 92)
	grid.spawn_unit(Vector2i(5, 3), UnitDatabase.create_unit(ARCHDEMON), rival)
	PublicVictoryMilestones.evaluate_round(players, 93)
	assert_eq(_published.filter(func(e): return e.event_type == "public_milestone").size(), 1, "voltar a duas não anuncia de novo")

func test_migrated_save_marks_reached_milestones_without_announcing():
	var players := _four_civs()
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	rival.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
	assert_true(rival.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(WorldEventManager.to_save_dict()))
	saved.erase("public_milestones") # save v23
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(saved)
	assert_true(PublicVictoryMilestones.announced(1, PublicVictoryMilestones.SUPREME_ARMY), "marco já satisfeito conta como conhecido")
	PublicVictoryMilestones.evaluate_round(players, 95)
	assert_eq(_published.filter(func(e): return e.event_type == "public_milestone").size(), 0, "nenhum anúncio retroativo")
