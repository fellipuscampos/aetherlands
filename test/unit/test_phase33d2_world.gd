extends GutTest

## Fase 33D2 — Guardiões Troll (Ascensão), persistência (DORMANT/AWAKE/RESOLVED, Guardião, migração v22),
## gate de fairness em mundos reais, determinismo e custo.

const SAVE_PATH := "user://test_phase33d2_world.json"
const SMALL_MAP := 61
const RADIUS := 20

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _real_grid: HexGrid

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false

func after_each():
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

# --- Fixture manual (Guardiões) ----------------------------------------------------------------------

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

func _world() -> void:
	grid = HexGrid.new()
	grid._ready()
	for q in range(-RADIUS, RADIUS + 1):
		for r in range(-RADIUS, RADIUS + 1):
			if absi(q + r) <= RADIUS:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Assento 0")
	rival = _player("Assento 1")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 1
	WorldEventManager.reset_for_new_match(1)
	WorldEventManager.regional_threats_enabled = true
	grid.found_city(Vector2i.ZERO, human, "Capital", true)

func _resource(coord: Vector2i, resource: String) -> void:
	grid.get_tile(coord).resource = resource

func _enter_ascension(turn: int = WorldPhaseRules.ASCENSION_FALLBACK_TURN) -> bool:
	return WorldEventManager.advance_world_phase(GameManager.players, turn)

func test_guardians_appear_once_on_ascension_on_existing_free_resources():
	_world()
	_resource(Vector2i(15, 0), "iron")
	_resource(Vector2i(0, 16), "iron")
	var tiles_with_resource := 0
	for tile in grid.tiles.values():
		tiles_with_resource += 1 if tile.resource != "" else 0
	assert_true(WorldEventManager.guardian_sites.is_empty(), "Despertar: nenhum Guardião")
	grid.process_monster_lairs(10)
	assert_true(WorldEventManager.guardian_sites.is_empty())
	assert_true(_enter_ascension(), "fallback do Despertar")
	assert_eq(WorldEventManager.guardian_sites.size(), 1, "até 1 por civilização ativa")
	var site: Dictionary = WorldEventManager.guardian_sites[0]
	assert_eq(String(site.resource), "iron")
	assert_between(HexMetrics.axial_distance(Vector2i.ZERO, site.resource_coord), 12, 20)
	assert_eq(grid.lair_role(site.coord), HexGrid.LAIR_ROLE_GUARDIAN)
	assert_eq(String(grid.lair_kind_by_coord[site.coord]), "troll")
	var troll := grid.get_unit_at(site.resource_coord)
	assert_not_null(troll, "o Troll fica em cima do recurso")
	assert_true(troll.is_camp_boss and troll.source_lair_coord == site.coord)
	var created := 0
	for tile in grid.tiles.values():
		created += 1 if tile.resource != "" else 0
	assert_eq(created, tiles_with_resource, "nenhum recurso criado")
	# Reavaliação da era (e chamada direta repetida) nunca duplica.
	assert_false(_enter_ascension(WorldPhaseRules.ASCENSION_FALLBACK_TURN + 1))
	RegionalThreatSystem.spawn_guardians(grid, 80)
	assert_eq(WorldEventManager.guardian_sites.size(), 1)
	assert_eq(grid.lair_coords.filter(func(c): return grid.lair_role(c) == HexGrid.LAIR_ROLE_GUARDIAN).size(), 1)

func test_owned_or_improved_resources_are_never_guarded():
	_world()
	var city := grid.get_city_at(Vector2i.ZERO)
	_resource(Vector2i(15, 0), "gems")
	_resource(Vector2i(0, 16), "gems")
	_resource(Vector2i(-16, 16), "gems")
	city.owned_tiles.append(Vector2i(15, 0)) # território consolidado
	var other := grid.found_city(Vector2i(-13, 13), rival, "Outra", true)
	other.resource_improvements[Vector2i(-16, 16)] = V2ResourceImprovementData.improvement_id_for_resource("gems")
	other.owned_tiles.append(Vector2i(-16, 16))
	_enter_ascension()
	for site in WorldEventManager.guardian_sites:
		assert_ne(site.resource_coord, Vector2i(15, 0), "recurso com dono nunca")
		assert_ne(site.resource_coord, Vector2i(-16, 16), "recurso melhorado nunca")
	assert_eq(WorldEventManager.guardian_sites.map(func(s): return s.resource_coord), [Vector2i(0, 16)])

func test_the_sole_copy_in_a_theater_is_never_guarded():
	_world()
	_resource(Vector2i(15, 0), "horses")
	_enter_ascension()
	assert_true(WorldEventManager.guardian_sites.is_empty(), "única cópia no teatro: sem gate econômico artificial")
	assert_gte(int(WorldEventManager.guardian_stats.skipped_sole), 1)
	assert_true(0 in WorldEventManager.guardian_stats.no_candidate, "civ sem candidato justo: 0 Guardiões, reportado")

func test_guardian_stays_put_and_resolution_keeps_the_resource():
	_world()
	_resource(Vector2i(15, 0), "iron")
	_resource(Vector2i(0, 16), "iron")
	_enter_ascension()
	var site: Dictionary = WorldEventManager.guardian_sites[0]
	var troll := grid.get_unit_at(site.resource_coord)
	assert_eq(String(RegionalThreatSystem.monster_directive(troll, grid).mode), "guardian")
	var intruder := grid.spawn_unit(site.resource_coord + Vector2i(0, -3), UnitDatabase.create_unit("warrior"), human)
	troll.reset_movement()
	MonsterAI.act_for_unit(troll, grid, 71)
	assert_eq(troll.coord, site.resource_coord, "Guardião não marcha")
	assert_true(RegionalThreatSystem.blocks_invader_promotion(grid, site.coord))
	grid.remove_unit(intruder)
	var gold_before := human.gold
	var hunter := grid.spawn_unit(_free_neighbor(site.resource_coord, site.coord), UnitDatabase.create_unit("warrior"), human)
	CombatResolver.apply_direct_unit_damage(hunter, troll, 999.0, grid)
	assert_almost_eq(human.gold - gold_before, MonsterDatabase.KIND_DATA.troll.gold_reward, 0.001, "recompensa normal de combate preservada")
	var structure_gold := human.gold
	var hits := 0
	grid.remove_unit(hunter)
	var sapper := grid.spawn_unit(_free_neighbor(site.coord, site.coord), UnitDatabase.create_unit("warrior"), human)
	while grid.lairs_by_coord.has(site.coord) and hits < 20:
		sapper.movement_left = sapper.unit_data.movement_points
		CombatResolver.resolve_lair_attack(sapper, site.coord, grid)
		hits += 1
	assert_almost_eq(human.gold - structure_gold, 75.0, 0.001, "Guardião: 75 Ouro no lugar dos 100 do covil de Troll")
	assert_eq(String(site.state), RegionalThreatSystem.STATE_RESOLVED)
	assert_eq(String(grid.get_tile(site.resource_coord).resource), "iron", "o recurso continua exatamente como antes")
	assert_null(grid.city_owning_tile(site.resource_coord), "anexar/melhorar continua pelas regras normais")
	_enter_ascension(90)
	assert_eq(WorldEventManager.guardian_sites.size(), 1, "sem reposição")

func _free_neighbor(center: Vector2i, avoid: Vector2i) -> Vector2i:
	for neighbor in RegionalThreatPlanner._sorted(grid.get_neighbors(center)):
		if neighbor != avoid and grid.get_unit_at(neighbor) == null and not grid.lairs_by_coord.has(neighbor) and grid.get_city_at(neighbor) == null:
			return neighbor
	return HexGrid.NO_LAIR

func test_ai_only_considers_a_known_guardian_with_enough_force_and_no_war():
	_world()
	var ai_city := grid.found_city(Vector2i(10, -3), rival, "IA", true)
	# Site criado pelo mesmo caminho do planner, a 9 da cidade da IA (a decisão é o que se testa aqui).
	var resource_coord := Vector2i(10, -12)
	_resource(resource_coord, "iron")
	var lair := Vector2i(11, -13)
	grid.create_lair(lair, "troll", HexGrid.LAIR_ROLE_GUARDIAN, resource_coord)
	WorldEventManager.guardian_sites.append({"coord": lair, "resource_coord": resource_coord, "resource": "iron", "kind": "troll", "for_players": [1], "created_turn": 70, "state": RegionalThreatSystem.GUARDIAN_ACTIVE, "resolved_turn": -1, "resolved_by": -1, "discovered_by": []})
	var site: Dictionary = WorldEventManager.guardian_sites[0]
	var view := V2AIWorldView.capture(rival, grid)
	assert_false(view.is_lair_known(site.coord), "Guardião fora da exploração não é conhecido")
	rival.explored_tiles[site.coord] = true
	view = V2AIWorldView.capture(rival, grid)
	var plan := V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(String(plan.mode), "none", "sem força: nunca 'objetivo obrigatório'")
	assert_eq(String(plan.reason), "guardian_insufficient_force")
	assert_eq(V2StrategicAI.lair_response_production_bonus(rival, view), 0.0, "Guardião não gera urgência de produção")
	var spawned := 0
	while V2StrategicAI.local_lair_force(rival, lair) < float(plan.required) and spawned < 10:
		grid.spawn_unit(ai_city.coord + Vector2i(0, -2 - spawned % 3) + Vector2i(spawned / 3, 0), UnitDatabase.create_unit("warrior"), rival)
		spawned += 1
	view = V2AIWorldView.capture(rival, grid)
	plan = V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(String(plan.mode), "attack", "força suficiente e sem guerra: pode atacar o Guardião")
	Diplomacy.declare_war(rival, human, "Teste", true)
	view = V2AIWorldView.capture(rival, grid)
	plan = V2StrategicAI.lair_response_plan(rival, view)
	assert_ne(plan.target, lair, "em guerra, o Guardião sai da lista (conflito mais urgente)")

# --- Persistência (mundo real pequeno) -------------------------------------------------------------

func _small_match(index: int = 1) -> HexGrid:
	var config := BalanceSeedSet.match_config(index, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	_real_grid = BalanceMatchRunner.setup_match(self, config)
	return _real_grid

func _snapshot(target: HexGrid) -> Dictionary:
	var threats: Array = []
	for record in WorldEventManager.regional_threats:
		threats.append([int(record.owner), record.anchor, record.coord, String(record.kind), int(record.wake_turn), String(record.state), int(record.resolved_by), record.discovered_by.duplicate()])
	var roles := {}
	for coord in target.lair_roles:
		roles[coord] = target.lair_roles[coord]
	var population := {}
	for coord in target.lair_coords:
		population[coord] = target.lair_population(coord)
	var monsters: Array = []
	for unit in target.neutral_units():
		monsters.append([unit.coord, unit.unit_data.visual_kind, unit.source_lair_coord, unit.is_camp_boss, snappedf(unit.hp, 0.01)])
	monsters.sort()
	var lairs := target.lair_coords.duplicate()
	lairs.sort()
	var guardians: Array = []
	for site in WorldEventManager.guardian_sites:
		guardians.append([site.coord, site.resource_coord, String(site.resource), site.for_players.duplicate(), String(site.state)])
	return {"threats": threats, "roles": roles, "population": population, "monsters": monsters, "lairs": lairs, "guardians": guardians, "enabled": WorldEventManager.regional_threats_enabled, "guardians_spawned": WorldEventManager.guardians_spawned}

func _save_and_reload(target: HexGrid) -> Dictionary:
	var before := _snapshot(target)
	assert_true(SaveManager.save_game(target, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(target, SAVE_PATH))
	return before

func test_regional_state_survives_save_and_load_dormant_awake_and_resolved():
	var target := _small_match()
	assert_eq(WorldEventManager.regional_threats.size(), GameManager.players.size(), "uma por civilização")
	var record: Dictionary = RegionalThreatSystem.record_for_index(0)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_DORMANT)
	var lair: Vector2i = record.coord
	# DORMANT
	var before := _save_and_reload(target)
	assert_eq(_snapshot(target), before, "dormente: mesmo local, tipo, despertar, população e papéis")
	# AWAKE (com reforço)
	target.monster_turn_rng.seed = 5
	for turn in range(1, int(record.wake_turn) + 25):
		TurnManager.turn_number = turn
		target.process_monster_lairs(turn)
	record = RegionalThreatSystem.record_for_index(0)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_AWAKE)
	var neutral_before := target.neutral_units().size()
	before = _save_and_reload(target)
	assert_eq(_snapshot(target), before, "desperto: nada duplicado nem perdido")
	assert_eq(target.neutral_units().size(), neutral_before, "sem monstros duplicados")
	assert_true(RegionalThreatSystem.is_regional_lair_awake(lair))
	# RESOLVED
	for member in target.lair_members(lair):
		target.remove_unit(member)
	for area_coord in target._lair_area(lair):
		var occupant := target.get_unit_at(area_coord)
		if occupant != null and occupant.owner_player == null:
			target.remove_unit(occupant)
	var soldier := target.spawn_unit(WorldSetup.find_spawn_tile(target, lair), UnitDatabase.create_unit("warrior"), GameManager.players[0])
	var hits := 0
	while target.lairs_by_coord.has(lair) and hits < 20:
		soldier.movement_left = soldier.unit_data.movement_points
		CombatResolver.resolve_lair_attack(soldier, lair, target)
		hits += 1
	target.remove_unit(soldier)
	before = _save_and_reload(target)
	assert_eq(_snapshot(target), before)
	assert_false(lair in target.lair_coords, "resolvido não respawna no load")
	assert_false(target.lairs_by_coord.has(lair))
	assert_eq(String(RegionalThreatSystem.record_for_index(0).state), RegionalThreatSystem.STATE_RESOLVED)
	for turn in range(TurnManager.turn_number, TurnManager.turn_number + 20):
		target.process_monster_lairs(turn)
	assert_false(lair in target.lair_coords)

func test_guardian_survives_save_and_load_identically():
	var target := _small_match(2)
	# Site criado pelo caminho real de criação (planner) num recurso livre escolhido à mão.
	var resource_coord := HexGrid.NO_LAIR
	for coord in RegionalThreatPlanner._sorted(target.tiles.keys()):
		var tile: HexTileData = target.tiles[coord]
		if tile.blocks_land_units() or target.get_unit_at(coord) != null or target.city_owning_tile(coord) != null:
			continue
		var far := true
		for player in GameManager.players:
			if not player.cities.is_empty() and HexMetrics.axial_distance(player.cities[0].coord, coord) < 12:
				far = false
		if far and RegionalThreatPlanner._guardian_lair_tile(target, coord, RandomNumberGenerator.new()) != HexGrid.NO_LAIR:
			resource_coord = coord
			break
	assert_ne(resource_coord, HexGrid.NO_LAIR)
	var lair := RegionalThreatPlanner._guardian_lair_tile(target, resource_coord, RandomNumberGenerator.new())
	target.create_lair(lair, "troll", HexGrid.LAIR_ROLE_GUARDIAN, resource_coord)
	WorldEventManager.guardian_sites.append({"coord": lair, "resource_coord": resource_coord, "resource": "iron", "kind": "troll", "for_players": [0], "created_turn": 50, "state": RegionalThreatSystem.GUARDIAN_ACTIVE, "resolved_turn": -1, "resolved_by": -1, "discovered_by": [1]})
	WorldEventManager.guardians_spawned = true
	var before := _save_and_reload(target)
	assert_eq(_snapshot(target), before, "Guardião idêntico após o load")
	assert_eq(target.lair_role(lair), HexGrid.LAIR_ROLE_GUARDIAN)
	RegionalThreatSystem.spawn_guardians(target, 80)
	assert_eq(WorldEventManager.guardian_sites.size(), 1, "nenhum outro recurso escolhido após o load")

func test_v22_save_loads_without_retroactive_threats_or_guardians():
	var target := _small_match(3)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	assert_true(SaveManager.save_game(target, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data.version = 22
	data.erase("lair_state")
	data.world_events.erase("regional")
	for unit in data.neutral_units:
		unit.erase("source_lair")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(target, SAVE_PATH), "save D1 carrega")
	assert_false(WorldEventManager.regional_threats_enabled)
	assert_true(WorldEventManager.regional_threats.is_empty(), "sem ameaça retroativa")
	assert_true(target.lair_roles.is_empty())
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.FOUNDATION, "era preservada")
	var settler := target.spawn_unit(WorldSetup.find_spawn_tile(target, GameManager.players[0].cities[0].coord), UnitDatabase.create_unit("settler"), GameManager.players[0])
	target.found_city(settler.coord, GameManager.players[0], "Nova", false)
	assert_true(WorldEventManager.regional_threats.is_empty(), "fundar depois do load antigo não cria ameaça")
	assert_true(WorldEventManager.advance_world_phase(GameManager.players, WorldPhaseRules.ASCENSION_FALLBACK_TURN))
	assert_true(WorldEventManager.guardian_sites.is_empty(), "sem Guardião retroativo na Ascensão")

# --- Mundo real: gate, determinismo, custo -----------------------------------------------------------

func _full_match_state(index: int) -> Dictionary:
	_real_grid = BalanceMatchRunner.setup_match(self, BalanceSeedSet.match_config(index))
	var capitals: Array = []
	for player in GameManager.players:
		capitals.append(player.cities[0].coord)
	var survey := BalanceWorldSurvey.survey_regional(_real_grid, capitals)
	RegionalThreatSystem.spawn_guardians(_real_grid, 1)
	var guardians: Array = []
	for site in WorldEventManager.guardian_sites:
		guardians.append([site.coord, site.resource_coord, String(site.resource), site.for_players.duplicate()])
	var threats: Array = []
	for record in WorldEventManager.regional_threats:
		threats.append([int(record.owner), record.coord, String(record.kind), int(record.wake_turn), String(record.source)])
	await BalanceMatchRunner.teardown_match(self, _real_grid)
	_real_grid = null
	return {"survey": survey, "guardians": guardians, "threats": threats, "capitals": capitals}

func test_real_worlds_pass_the_regional_gate_deterministically():
	for index in [0, 3]:
		var first: Dictionary = await _full_match_state(index)
		var second: Dictionary = await _full_match_state(index)
		assert_eq(first.threats, second.threats, "match %d: ameaças idênticas" % index)
		assert_eq(first.guardians, second.guardians, "match %d: Guardiões idênticos" % index)
		assert_eq(first.survey.size(), 4)
		for entry in first.survey:
			assert_true(bool(entry.exists), "assento %d tem ameaça" % entry.seat)
			assert_between(int(entry.distance), 7, 10)
			assert_true(bool(entry.same_component))
			assert_true(bool(entry.anchor_is_capital))
			assert_eq(int(entry.in_corridor), 0, "fora do corredor")
			assert_eq(int(entry.wild_lairs_under_7), 0, "nenhum covil selvagem a < 7")

func test_regional_systems_cost_nothing_per_frame_and_little_per_turn():
	_real_grid = BalanceMatchRunner.setup_match(self, BalanceSeedSet.match_config(0))
	var target := _real_grid
	var player: PlayerData = GameManager.players[1]
	for record in WorldEventManager.regional_threats:
		player.explored_tiles[record.coord] = true
	# Planner por capital (colocação num mundo já cheio: pior caso de busca).
	var started := Time.get_ticks_usec()
	var placed := RegionalThreatPlanner.place_regional(target, player, 1, player.cities[0].coord + Vector2i(0, 0), [GameManager.players[0].cities[0].coord], 1)
	var planner_us := Time.get_ticks_usec() - started
	# WorldView: captura + defesa conhecida.
	started = Time.get_ticks_usec()
	var view: V2AIWorldView
	for i in 20:
		view = V2AIWorldView.capture(player, target)
	var capture_us := (Time.get_ticks_usec() - started) / 20
	started = Time.get_ticks_usec()
	for i in 200:
		for record in view.known_lairs:
			view.known_lair_defense(record.coord)
		V2StrategicAI.lair_response_plan(player, view)
	var plan_us := (Time.get_ticks_usec() - started) / 200
	# Diretiva de monstro por turno (todos os monstros) e despertar.
	started = Time.get_ticks_usec()
	for i in 50:
		for unit in target.neutral_units():
			RegionalThreatSystem.monster_directive(unit, target)
		RegionalThreatSystem.process_turn(target, 5)
	var directive_us := (Time.get_ticks_usec() - started) / 50
	# Guardiões na transição.
	started = Time.get_ticks_usec()
	RegionalThreatSystem.spawn_guardians(target, 45)
	var guardian_us := Time.get_ticks_usec() - started
	gut.p("[D2 perf] planner=%d us/capital | worldview capture=%d us | known defense + plan=%d us | directives+wake=%d us/turn | guardians=%d us (once)" % [planner_us, capture_us, plan_us, directive_us, guardian_us])
	assert_true(bool(placed.ok))
	assert_lt(planner_us, 250000, "colocação rara: poucos ms")
	assert_lt(plan_us, 5000)
	assert_lt(directive_us, 5000, "custo por turno pequeno")
	assert_lt(guardian_us, 500000)
	assert_false(FileAccess.get_file_as_string("res://scripts/core/RegionalThreatSystem.gd").contains("_process"), "zero custo por frame")
	assert_false(FileAccess.get_file_as_string("res://scripts/core/RegionalThreatPlanner.gd").contains("_process"))
