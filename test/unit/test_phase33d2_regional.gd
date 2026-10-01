extends GutTest

## Fase 33D2 — ameaças regionais: colocação (anel 7–10, componente, reuso, criação, realocação de covil
## selvagem perto demais, mundo observado preservado, corredor, desempate determinístico), capital real do
## humano que atrasa a fundação, exatamente uma por civ, ciclo DORMANT → AWAKE → RESOLVED, população própria
## fora do teto global, recompensas por papel, resolução por outro reino, IA (desconhecido/descoberto/
## reunir/atacar/pressão), ataque a covil compartilhado humano × IA sem teleporte, Bug #6 (CitySite) e #7
## (CityDefense) e superfícies de UI (Event Center, chip, TileInspector).

const RADIUS := 17

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _signals: Array = []
var _connections: Array = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	_signals.clear()

func after_each():
	for entry in _connections:
		if (entry[0] as Signal).is_connected(entry[1]):
			(entry[0] as Signal).disconnect(entry[1])
	_connections.clear()
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

# --- Fixture ------------------------------------------------------------------------------------

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

## Hexágono de grama de raio RADIUS; `water` = coords que viram oceano. Ameaças regionais ligadas.
func _world(water: Array = [], map_seed: int = 0) -> void:
	grid = HexGrid.new()
	grid._ready()
	grid.map_seed = map_seed
	for q in range(-RADIUS, RADIUS + 1):
		for r in range(-RADIUS, RADIUS + 1):
			if absi(q + r) <= RADIUS:
				var coord := Vector2i(q, r)
				grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN if coord in water else HexTileData.TerrainType.GRASSLAND)
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

func _record(index: int) -> Dictionary:
	return RegionalThreatSystem.record_for_index(index)

func _members(lair: Vector2i) -> Array[Unit]:
	return grid.lair_members(lair)

func _wild_lairs_within(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for lair in grid.lair_coords:
		if grid.lair_role(lair) == HexGrid.LAIR_ROLE_WILD and HexMetrics.axial_distance(center, lair) <= radius:
			result.append(lair)
	return result

func _capture(signal_name: String) -> void:
	var sig: Signal = EventBus.get(signal_name)
	var callable := func(a = null, b = null, c = null, d = null): _signals.append([signal_name, a, b, c, d])
	sig.connect(callable)
	_connections.append([sig, callable])

func _count_signals(signal_name: String) -> int:
	return _signals.filter(func(entry): return entry[0] == signal_name).size()

## Mata os monstros do covil e ataca a estrutura com `attacker_owner` até destruí-la.
func _destroy_lair(lair: Vector2i, attacker_owner: PlayerData) -> void:
	for member in _members(lair):
		grid.remove_unit(member)
	var coord := WorldSetup.find_spawn_tile(grid, lair)
	var soldier := grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), attacker_owner)
	var hits := 0
	while grid.lairs_by_coord.has(lair) and hits < 20:
		soldier.movement_left = soldier.unit_data.movement_points
		CombatResolver.resolve_lair_attack(soldier, lair, grid)
		hits += 1
	grid.remove_unit(soldier)

# --- Colocação ----------------------------------------------------------------------------------

func test_created_threat_is_7_to_10_on_the_capital_landmass():
	# Metade leste do anel vira uma ilha separada por um fosso de oceano: nunca pode receber a ameaça.
	var water: Array = []
	for coord in HexMetrics.coords_within(Vector2i.ZERO, RADIUS):
		if coord.x >= 5 and coord.x <= 6:
			water.append(coord)
	_world(water)
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := _record(0)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_DORMANT)
	assert_eq(String(record.source), "created")
	var distance := HexMetrics.axial_distance(Vector2i.ZERO, record.coord)
	assert_between(distance, RegionalThreatPlanner.RING_MIN, RegionalThreatPlanner.RING_MAX, "anel 7–10")
	grid._ensure_land_components()
	assert_eq(grid._land_components[record.coord], grid._land_components[Vector2i.ZERO], "mesmo componente terrestre")
	assert_eq(grid.lair_role(record.coord), HexGrid.LAIR_ROLE_REGIONAL)
	assert_eq(String(record.kind), RegionalThreatPlanner.GOBLIN, "grama → Goblin")
	var members := _members(record.coord)
	assert_eq(members.size(), 1, "só o chefe na criação")
	assert_true(members[0].is_camp_boss)
	assert_eq(HexMetrics.axial_distance(members[0].coord, record.coord), 1, "chefe ao redor da estrutura, nunca em cima")
	assert_false(bool(record.visible_at_creation), "fora da visão inicial")
	assert_between(int(record.wake_turn) - int(record.created_turn), 8, 12)

func test_existing_compatible_wild_lair_is_promoted_instead_of_creating_one():
	_world()
	var existing := Vector2i(0, -8)
	grid.create_lair(existing, "skeleton", HexGrid.LAIR_ROLE_WILD, existing + Vector2i(1, 0))
	var lairs_before := grid.lair_coords.size()
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := _record(0)
	assert_eq(String(record.source), "reused")
	assert_eq(record.coord, existing)
	assert_eq(String(record.kind), "skeleton")
	assert_eq(grid.lair_role(existing), HexGrid.LAIR_ROLE_REGIONAL)
	assert_eq(grid.lair_coords.size(), lairs_before, "nenhum covil novo: densidade preservada")
	assert_eq(_members(existing).size(), 1, "o chefe existente passa a pertencer ao covil regional")

func test_wild_lair_too_close_is_relocated_or_removed():
	_world()
	var close := Vector2i(3, 0)
	grid.create_lair(close, "goblin", HexGrid.LAIR_ROLE_WILD, close + Vector2i(1, 0))
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := _record(0)
	assert_true(_wild_lairs_within(Vector2i.ZERO, 6).is_empty(), "nenhum covil selvagem a < 7 da capital nova")
	assert_eq(int(record.relocated), 1)
	var moved := false
	for lair in grid.lair_coords:
		var distance := HexMetrics.axial_distance(Vector2i.ZERO, lair)
		if grid.lair_role(lair) == HexGrid.LAIR_ROLE_WILD and distance >= RegionalThreatPlanner.RELOCATE_MIN and distance <= RegionalThreatPlanner.RELOCATE_MAX:
			moved = true
			assert_eq(String(grid.lair_kind_by_coord[lair]), "goblin", "mesmo tipo")
	assert_true(moved, "realocado para o anel 11–16")
	# Sem espaço para realocar (mapa pequeno): removido.
	grid.queue_free()
	var water: Array = []
	for coord in HexMetrics.coords_within(Vector2i.ZERO, RADIUS):
		if HexMetrics.axial_distance(Vector2i.ZERO, coord) > 10:
			water.append(coord)
	_world(water)
	grid.create_lair(close, "goblin", HexGrid.LAIR_ROLE_WILD, close + Vector2i(1, 0))
	grid.found_city(Vector2i.ZERO, human, "Capital")
	assert_eq(int(_record(0).removed), 1)
	assert_false(close in grid.lair_coords)
	assert_false(close in grid.cleared_lair_coords, "remoção do planner não é 'covil destruído'")

func test_observed_wild_lair_is_never_moved():
	_world()
	var close := Vector2i(-4, 0)
	grid.create_lair(close, "goblin", HexGrid.LAIR_ROLE_WILD, close + Vector2i(-1, 0))
	rival.explored_tiles[close] = true # outra civilização já o viu
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := _record(0)
	assert_true(close in grid.lair_coords, "mundo observado não é teletransportado")
	assert_eq(int(record.preserved_close), 1)
	assert_ne(record.coord, close, "a ameaça regional é outro site")
	assert_between(HexMetrics.axial_distance(Vector2i.ZERO, record.coord), 7, 10)

func test_threat_avoids_the_corridor_to_a_close_rival_capital():
	_world()
	var neighbor := Vector2i(13, 0)
	grid.found_city(neighbor, rival, "Vizinha", true) # silenciosa: sem ameaça própria, só âncora
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := _record(0)
	assert_eq(RegionalThreatPlanner.corridor_relation(Vector2i.ZERO, neighbor, record.coord), 0, "hemisfério oposto ao vizinho a < 16")
	assert_false(bool(record.corridor_violation))
	assert_eq(int(record.corridor_neighbors), 1)
	assert_gte(HexMetrics.axial_distance(record.coord, neighbor), RegionalThreatPlanner.OTHER_CAPITAL_MIN)
	# Classificação geométrica usada pelo survey.
	assert_eq(RegionalThreatPlanner.corridor_relation(Vector2i.ZERO, neighbor, Vector2i(6, 0)), 2)
	assert_eq(RegionalThreatPlanner.corridor_relation(Vector2i.ZERO, neighbor, Vector2i(-6, 0)), 0)

func test_placement_is_deterministic_for_the_same_seed_capital_and_seat():
	var results: Array = []
	for attempt in 2:
		if grid != null:
			grid.queue_free()
		_world([], 4242)
		grid.found_city(Vector2i(1, -1), human, "Capital")
		var record := _record(0)
		results.append([record.coord, String(record.kind), int(record.wake_turn), _members(record.coord)[0].coord])
	assert_eq(results[0], results[1], "mesmo local, tipo, despertar e chefe")

# --- Capital real / exatamente uma ----------------------------------------------------------------

func test_delayed_human_capital_anchors_the_threat_to_the_real_city():
	_world()
	var settler := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("settler"), human)
	grid.found_city(Vector2i(-13, 0), rival, "Rival", true)
	assert_true(_record(0).is_empty(), "nada antes de a capital existir")
	for step in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, -1), Vector2i(4, -1)]:
		TurnManager.turn_number += 1
		grid.move_unit(settler, step, 1.0)
	var city := WorldSetup.found_city_from_settler(grid, settler)
	assert_not_null(city)
	var record := _record(0)
	assert_eq(record.anchor, Vector2i(4, -1), "âncora = cidade real, não a origem")
	assert_between(HexMetrics.axial_distance(city.coord, record.coord), 7, 10)
	assert_eq(int(record.created_turn), TurnManager.turn_number)
	assert_between(int(record.wake_turn) - TurnManager.turn_number, 8, 12, "despertar relativo à fundação")

func test_exactly_one_threat_per_civilization():
	_world()
	grid.found_city(Vector2i.ZERO, human, "Capital")
	grid.found_city(Vector2i(-6, 6), human, "Segunda")
	assert_eq(WorldEventManager.regional_threats.size(), 1, "segunda cidade não cria outra")
	var enemy_city := grid.found_city(Vector2i(0, 14), rival, "Rival", true)
	grid.capture_city(enemy_city, human)
	assert_eq(WorldEventManager.regional_threats.size(), 1, "captura não cria ameaça")
	var own := grid.get_city_at(Vector2i(-6, 6))
	grid.capture_city(own, rival)
	assert_true(_record(1).is_empty(), "a civ que só capturou continua sem ameaça")
	WorldEventManager.reset_for_new_match()
	assert_true(WorldEventManager.regional_threats.is_empty() and not WorldEventManager.regional_threats_enabled, "partida nova começa limpa")

func test_old_or_disabled_matches_never_create_threats():
	_world()
	WorldEventManager.regional_threats_enabled = false
	grid.found_city(Vector2i.ZERO, human, "Capital")
	assert_true(WorldEventManager.regional_threats.is_empty())
	assert_true(grid.lair_coords.is_empty())

# --- Ciclo de vida --------------------------------------------------------------------------------

func _awake_setup() -> Dictionary:
	_world()
	grid.monster_turn_rng.seed = 7
	var city := grid.found_city(Vector2i.ZERO, human, "Capital")
	return {"city": city, "record": _record(0)}

func test_dormant_threat_never_reinforces_or_pillages_but_can_be_found_and_destroyed():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	var lair: Vector2i = record.coord
	for turn in range(1, int(record.wake_turn)):
		TurnManager.turn_number = turn
		grid.process_monster_lairs(turn)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_DORMANT)
	assert_eq(grid.lair_population(lair), 1, "reforço 0 enquanto dormente")
	# Um monstro do covil em cima de uma melhoria do reino: dormente não saqueia.
	var raider := _bound_monster_on_improvement(setup.city, lair)
	MonsterAI.act_for_unit(raider, grid, TurnManager.turn_number)
	assert_false(grid.is_tile_pillaged(raider.coord, TurnManager.turn_number), "dormente nunca saqueia")
	assert_eq(String(RegionalThreatSystem.monster_directive(raider, grid).mode), "dormant")
	_capture("world_threat_discovered")
	human.explored_tiles[lair] = true
	RegionalThreatSystem.note_observation(grid, human)
	assert_true(0 in record.discovered_by, "descoberto dormindo")
	assert_eq(_count_signals("world_threat_discovered"), 1)
	RegionalThreatSystem.note_observation(grid, human)
	assert_eq(_count_signals("world_threat_discovered"), 1, "descoberta é única")
	grid.remove_unit(raider)
	_destroy_lair(lair, human)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_RESOLVED, "o jogador proativo resolve dormindo")

func _bound_monster_on_improvement(city: City, lair: Vector2i) -> Unit:
	var coord := Vector2i(1, 0)
	grid.get_tile(coord).resource = "iron"
	city.resource_improvements[coord] = V2ResourceImprovementData.improvement_id_for_resource("iron")
	var monster := grid.spawn_monster_at(coord, String(grid.lair_kind_by_coord[lair]))
	monster.source_lair_coord = lair
	monster.movement_left = 0.0
	return monster

func test_wake_happens_once_and_then_reinforces_up_to_the_regional_cap():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	var lair: Vector2i = record.coord
	_capture("regional_threat_awakened")
	var max_population := 0
	for turn in range(1, 90):
		TurnManager.turn_number = turn
		grid.process_monster_lairs(turn)
		if turn < int(record.wake_turn):
			assert_eq(String(record.state), RegionalThreatSystem.STATE_DORMANT)
		max_population = maxi(max_population, grid.lair_population(lair))
	assert_eq(String(record.state), RegionalThreatSystem.STATE_AWAKE)
	assert_eq(_count_signals("regional_threat_awakened"), 1, "despertar acontece uma vez")
	assert_eq(max_population, RegionalThreatSystem.REGIONAL_POPULATION_CAP, "chefe + 2, nunca mais")
	# Desperto na Era do Despertar: saqueia dentro do teatro regional, sem virar Invasor de mapa.
	var raider := _bound_monster_on_improvement(setup.city, lair)
	var directive := RegionalThreatSystem.monster_directive(raider, grid)
	assert_eq(String(directive.mode), "regional")
	assert_eq(int(directive.radius), HexMetrics.axial_distance(lair, Vector2i.ZERO) + RegionalThreatSystem.THEATER_MARGIN)
	MonsterAI.act_for_unit(raider, grid, TurnManager.turn_number)
	assert_true(grid.is_tile_pillaged(raider.coord, TurnManager.turn_number), "desperto saqueia a melhoria")
	MonsterAI.begin_turn(grid)
	for member in _members(lair):
		assert_eq(member.monster_behavior_state, "", "sem promoção a Invasor no Despertar")
	# Ascensão: comportamento normal do tipo volta (sem stats novos, sem covil regional novo).
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	assert_true(RegionalThreatSystem.monster_directive(raider, grid).is_empty())
	assert_eq(WorldEventManager.regional_threats.size(), 1)

func test_four_regional_lairs_keep_their_own_population_and_the_wild_cap_still_holds():
	_world()
	grid.monster_turn_rng.seed = 11
	var extra_players: Array[PlayerData] = [human, rival, _player("Assento 2"), _player("Assento 3")]
	GameManager.players = extra_players
	var capitals := [Vector2i(-12, 0), Vector2i(12, 0), Vector2i(0, -12), Vector2i(0, 12)]
	for index in 4:
		grid.found_city(capitals[index], extra_players[index], "Capital %d" % index, true)
	for index in 4:
		RegionalThreatSystem._plan_for(grid, extra_players[index], index, capitals[index])
	var regional: Array[Vector2i] = []
	for record in WorldEventManager.regional_threats:
		record.kind = "goblin"
		grid.lair_kind_by_coord[record.coord] = "goblin"
		record.state = RegionalThreatSystem.STATE_AWAKE
		regional.append(record.coord)
	# Um covil selvagem de Goblin + 5 Goblins selvagens soltos: teto global dos selvagens cheio.
	var wild := Vector2i(-3, 3)
	for lair in regional:
		assert_gt(HexMetrics.axial_distance(lair, wild), 2)
	grid.create_lair(wild, "goblin", HexGrid.LAIR_ROLE_WILD)
	for offset in [Vector2i(5, -5), Vector2i(6, -5), Vector2i(5, -6), Vector2i(7, -6), Vector2i(6, -7)]:
		grid.spawn_monster_at(offset, "goblin")
	for turn in range(1, 120):
		grid.process_monster_lairs(turn)
	for lair in regional:
		assert_eq(grid.lair_population(lair), RegionalThreatSystem.REGIONAL_POPULATION_CAP, "cada regional mantém a própria população")
	assert_eq(grid.lair_population(wild), 0, "o covil selvagem continua barrado pelo teto global")
	assert_eq(grid._count_alive_of_kind("goblin"), MonsterDatabase.KIND_DATA.goblin.global_cap, "regionais fora do teto global")

func test_resolution_pays_the_regional_reward_once_and_never_respawns():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	var lair: Vector2i = record.coord
	human.explored_tiles[lair] = true
	RegionalThreatSystem.note_observation(grid, human)
	_capture("world_threat_resolved")
	var gold_before := human.gold
	var mana_before := human.mana
	_destroy_lair(lair, human)
	assert_almost_eq(human.gold - gold_before, 40.0, 0.001, "Goblin regional: 40 Ouro (substitui os 75 do covil selvagem)")
	assert_almost_eq(human.mana - mana_before, 0.0, 0.001)
	assert_eq(String(record.state), RegionalThreatSystem.STATE_RESOLVED)
	assert_eq(int(record.resolved_by), 0)
	assert_eq(_count_signals("world_threat_resolved"), 1)
	var objectives := RegionalThreatSystem.objectives_for(human)
	assert_eq(String(objectives[0].status), "resolved")
	var lairs_after := grid.lair_coords.size()
	for turn in range(TurnManager.turn_number, TurnManager.turn_number + 40):
		grid.process_monster_lairs(turn)
	assert_eq(grid.lair_coords.size(), lairs_after, "nunca respawna nem é substituída")
	assert_false(lair in grid.lair_coords)
	assert_eq(WorldEventManager.regional_threats.size(), 1)
	grid.found_city(Vector2i(-7, 7), human, "Outra")
	assert_eq(WorldEventManager.regional_threats.size(), 1, "sem ameaça de compensação")

func test_skeleton_regional_reward_includes_mana_and_no_knowledge():
	var reward := RegionalThreatSystem.role_clear_reward(HexGrid.LAIR_ROLE_REGIONAL, "skeleton")
	assert_eq(reward, {"gold": 40.0, "mana": 5.0})
	assert_eq(RegionalThreatSystem.role_clear_reward(HexGrid.LAIR_ROLE_GUARDIAN, "troll"), {"gold": 75.0, "mana": 0.0})
	assert_true(RegionalThreatSystem.role_clear_reward(HexGrid.LAIR_ROLE_WILD, "goblin").is_empty(), "selvagem usa a recompensa do tipo")
	for value in [reward, RegionalThreatSystem.GUARDIAN_REWARD]:
		assert_false(value.has("knowledge"), "nunca Conhecimento")

func test_resolution_by_another_civilization_rewards_only_the_resolver():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	human.explored_tiles[record.coord] = true
	RegionalThreatSystem.note_observation(grid, human)
	var owner_gold := human.gold
	var rival_gold := rival.gold
	_destroy_lair(record.coord, rival)
	assert_almost_eq(rival.gold - rival_gold, 40.0, 0.001, "quem destruiu recebe")
	assert_almost_eq(human.gold, owner_gold, 0.001, "dono sem compensação")
	assert_eq(int(record.resolved_by), 1)
	assert_eq(String(RegionalThreatSystem.objectives_for(human)[0].status), "resolved_by_other")

# --- IA ------------------------------------------------------------------------------------------

func _ai_setup() -> Dictionary:
	_world()
	grid.found_city(Vector2i(-12, 0), human, "Humano", true)
	var city := grid.found_city(Vector2i(6, 0), rival, "Capital IA")
	return {"city": city, "record": _record(1)}

func test_ai_does_not_react_to_an_undiscovered_regional_lair():
	var setup := _ai_setup()
	var view := V2AIWorldView.capture(rival, grid)
	assert_false(view.is_lair_known(setup.record.coord), "a própria ameaça não é conhecida magicamente")
	var plan := V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(String(plan.mode), "none")
	assert_eq(String(plan.reason), "no_known_threat")
	assert_eq(V2StrategicAI.lair_response_production_bonus(rival, view), 0.0)

func test_ai_discovers_then_gathers_then_attacks():
	var setup := _ai_setup()
	var lair: Vector2i = setup.record.coord
	rival.explored_tiles[lair] = true
	var view := V2AIWorldView.capture(rival, grid)
	var known := view.known_lair(lair)
	assert_eq(String(known.role), HexGrid.LAIR_ROLE_REGIONAL, "papel visível para quem conhece o covil")
	var plan := V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(plan.target, lair)
	assert_eq(String(plan.mode), "gather", "sem força local: produzir/reunir")
	assert_gt(plan.required, 0.0, "defesa estimada pelo chefe típico, sem ler a população real")
	assert_eq(V2StrategicAI.lair_response_production_bonus(rival, view), V2StrategicAI.LAIR_RESPONSE_PRODUCTION_BONUS)
	var near: Vector2i = lair + (setup.city.coord - lair) / 2
	var spawned := 0
	while V2StrategicAI.local_lair_force(rival, lair) < float(plan.required) and spawned < 8:
		var coord := WorldSetup.find_spawn_tile(grid, near)
		grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), rival)
		near = coord
		spawned += 1
	view = V2AIWorldView.capture(rival, grid)
	plan = V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(String(plan.mode), "attack", "força ≥ OVERMATCH × defesa conhecida")
	assert_eq(V2StrategicAI.lair_response_production_bonus(rival, view), 0.0, "exército relevante já cobre a resposta mínima")

func test_severe_pressure_makes_the_regional_threat_secondary():
	var setup := _ai_setup()
	rival.explored_tiles[setup.record.coord] = true
	Diplomacy.declare_war(rival, human, "Teste", true)
	grid.spawn_unit(setup.city.coord + Vector2i(0, 2), UnitDatabase.create_unit("warrior"), human)
	var view := V2AIWorldView.capture(rival, grid)
	var plan := V2StrategicAI.lair_response_plan(rival, view)
	assert_eq(String(plan.mode), "none")
	assert_eq(String(plan.reason), "pressure")

func test_ai_attacks_the_structure_through_the_same_rule_as_the_human_without_teleporting():
	_world()
	grid.found_city(Vector2i(-12, 0), human, "Humano", true)
	grid.found_city(Vector2i(8, 0), rival, "IA", true)
	var human_lair := Vector2i(-6, 4)
	var ai_lair := Vector2i(4, 4)
	grid.create_lair(human_lair, "goblin", HexGrid.LAIR_ROLE_WILD)
	grid.create_lair(ai_lair, "goblin", HexGrid.LAIR_ROLE_WILD)
	var human_unit := grid.spawn_unit(human_lair + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), human)
	for structure_coord in [human_lair, ai_lair]:
		grid.lairs_by_coord[structure_coord].max_hp = 10.0
		grid.lairs_by_coord[structure_coord].hp = 10.0
	var far_unit := grid.spawn_unit(ai_lair + Vector2i(0, -5), UnitDatabase.create_unit("warrior"), rival)
	# Força local suficiente contra a defesa ESTIMADA (área do covil fora da vista: chefe típico).
	grid.spawn_unit(Vector2i(7, 1), UnitDatabase.create_unit("warrior"), rival)
	grid.spawn_unit(Vector2i(7, 2), UnitDatabase.create_unit("warrior"), rival)
	rival.explored_tiles[ai_lair] = true
	# Sem teleporte: longe demais para atacar; a IA anda, a estrutura fica intacta.
	assert_false(CombatResolver.can_attack_lair(far_unit, ai_lair, grid))
	var start := far_unit.coord
	assert_true(StrategicAI.respond_to_lair(far_unit, rival, grid))
	assert_ne(far_unit.coord, start, "aproximou-se por movimento normal")
	assert_lt(HexMetrics.axial_distance(far_unit.coord, ai_lair), HexMetrics.axial_distance(start, ai_lair))
	assert_eq(grid.lairs_by_coord[ai_lair].hp, grid.lairs_by_coord[ai_lair].max_hp)
	grid.remove_unit(far_unit)
	var ai_unit := grid.spawn_unit(ai_lair + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	V2AITacticalAI.clear_views()
	assert_true(CombatResolver.can_attack_lair(human_unit, human_lair, grid), "regra canônica (humano)")
	assert_true(CombatResolver.can_attack_lair(ai_unit, ai_lair, grid), "regra canônica (IA)")
	CombatResolver.resolve_lair_attack(human_unit, human_lair, grid)
	assert_true(StrategicAI.respond_to_lair(ai_unit, rival, grid))
	assert_lt(grid.lairs_by_coord[ai_lair].hp, 10.0, "a IA atacou a estrutura")
	assert_almost_eq(grid.lairs_by_coord[ai_lair].hp, grid.lairs_by_coord[human_lair].hp, 0.001, "mesmo dano")
	assert_eq(ai_unit.movement_left, 0.0, "consome a ação")
	var human_gold := human.gold
	var rival_gold := rival.gold
	_destroy_lair(human_lair, human)
	_destroy_lair(ai_lair, rival)
	assert_almost_eq(human.gold - human_gold, rival.gold - rival_gold, 0.001, "mesma recompensa pela mesma fonte")

func test_structure_with_a_live_defender_is_never_attackable():
	_world()
	var lair := Vector2i(0, -8)
	grid.create_lair(lair, "goblin", HexGrid.LAIR_ROLE_WILD, lair + Vector2i(1, 0))
	var unit := grid.spawn_unit(lair + Vector2i(-1, 0), UnitDatabase.create_unit("warrior"), human)
	assert_false(CombatResolver.can_attack_lair(unit, lair, grid))
	CombatResolver.resolve_lair_attack(unit, lair, grid)
	assert_eq(grid.lairs_by_coord[lair].hp, grid.lairs_by_coord[lair].max_hp)

func test_global_army_targets_are_untouched():
	assert_eq(V2AITuning.NORMAL_TOKEN_CAP, 20)
	assert_eq(V2AITuning.HARD_TOKEN_CAP, 24)

# --- Bug #6: CitySite só com informação conhecida ---------------------------------------------------

func _site_setup() -> Dictionary:
	_world()
	var ai_capital := grid.found_city(Vector2i(-10, 0), rival, "IA", true)
	var hidden_city := grid.found_city(Vector2i(2, 0), human, "Escondida", true)
	for coord in HexMetrics.coords_within(Vector2i(-10, 0), 14):
		if grid.tiles.has(coord):
			rival.explored_tiles[coord] = true # território explorado ANTES de a cidade existir
	return {"ai": ai_capital, "hidden": hidden_city}

func test_hidden_enemy_city_never_enters_the_ai_site_context():
	var setup := _site_setup()
	var context := CitySite.build_context(grid, rival, rival.explored_tiles)
	assert_false(setup.hidden in context.foreign_cities, "cidade não descoberta fora do contexto")
	assert_false(context.owner_of.has(Vector2i(2, 0)), "território dela também")
	rival.known_enemy_cities[Vector2i(2, 0)] = true
	context = CitySite.build_context(grid, rival, rival.explored_tiles)
	assert_true(setup.hidden in context.foreign_cities, "descoberta: aparece")
	var full := CitySite.build_context(grid, rival)
	assert_true(setup.hidden in full.foreign_cities, "sem filtro (HUD/diagnóstico) continua completo")

func test_hidden_monster_never_affects_the_score_but_a_visible_one_does():
	_site_setup()
	var candidate := Vector2i(-5, 0)
	var base: float = CitySite.evaluate(grid, candidate, CitySite.build_context(grid, rival, rival.explored_tiles)).parts.security
	var hidden_monster := grid.spawn_monster_at(Vector2i(-2, 1), "goblin")
	var with_hidden: float = CitySite.evaluate(grid, candidate, CitySite.build_context(grid, rival, rival.explored_tiles)).parts.security
	assert_almost_eq(with_hidden, base, 0.0001, "monstro na névoa não pesa")
	grid.remove_unit(hidden_monster)
	grid.spawn_monster_at(Vector2i(-7, 0), "goblin")
	var with_visible: float = CitySite.evaluate(grid, candidate, CitySite.build_context(grid, rival, rival.explored_tiles)).parts.security
	assert_lt(with_visible, base, "monstro visível pesa")

func test_runtime_still_blocks_illegal_founding_without_revealing_the_city():
	var setup := _site_setup()
	var coord := Vector2i(0, 1)
	var context := CitySite.build_context(grid, rival, rival.explored_tiles)
	assert_eq(CitySite.known_rejection_reason(grid, coord, context), "", "pela informação da IA o local parece livre")
	assert_eq(CitySite.rejection_reason(grid, coord, rival), CitySite.REASON_TOO_CLOSE, "a regra real vê a cidade escondida")
	var settler := grid.spawn_unit(coord, UnitDatabase.create_unit("settler"), rival)
	assert_null(WorldSetup.found_city_from_settler(grid, settler), "o runtime recusa")
	assert_true(is_instance_valid(settler) and settler.get_parent() != null, "Colonizador não é consumido")
	settler.settle_rejected_sites[coord] = true
	for entry in CitySite.rank_sites(grid, rival, context, settler):
		assert_ne(entry.coord, coord, "tile recusado sai da busca deste Colonizador")
	assert_false(setup.hidden in context.foreign_cities, "a recusa não revela a cidade ao contexto")

# --- Bug #7: CityDefense sem covil escondido --------------------------------------------------------

func test_ai_city_threat_only_counts_lairs_the_owner_knows():
	_world()
	var city := grid.found_city(Vector2i.ZERO, rival, "IA", true)
	var lair := Vector2i(0, -5)
	grid.create_lair(lair, "goblin", HexGrid.LAIR_ROLE_WILD, lair + Vector2i(1, 0))
	grid.spawn_monster_at(Vector2i(0, -3), "goblin")
	var visible := grid.compute_visible_tiles(rival)
	var unknown: float = CityDefense.assess(city, grid, visible).threat_power
	rival.explored_tiles[lair] = true
	var known: float = CityDefense.assess(city, grid, visible).threat_power
	assert_gt(known, unknown, "pressão de covil só depois de conhecido")

# --- UI -------------------------------------------------------------------------------------------

func test_event_center_announces_only_what_the_owner_legitimately_knows():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	var published: Array = []
	var capture := func(event: UIEventData): published.append(event)
	UIEvents.event_published.connect(capture)
	# Desperta antes da descoberta: nada anunciado, covil não revelado.
	for turn in range(1, int(record.wake_turn) + 1):
		TurnManager.turn_number = turn
		grid.process_monster_lairs(turn)
	assert_eq(published.filter(func(e): return e.event_type.begins_with("regional")).size(), 0, "despertar desconhecido não revela nada")
	assert_true(RegionalThreatSystem.objectives_for(human).is_empty(), "objetivo invisível antes da descoberta")
	grid.recompute_fog(human) # visão normal ainda não alcança o covil
	assert_false(0 in record.discovered_by)
	human.explored_tiles[record.coord] = true
	RegionalThreatSystem.note_observation(grid, human)
	var discovered := published.filter(func(e): return e.event_type == "regional_threat_discovered")
	assert_eq(discovered.size(), 1)
	assert_eq(discovered[0].title, "Ameaça regional")
	assert_eq(discovered[0].message, "Um covil hostil ameaça os arredores de seu reino.")
	assert_eq(discovered[0].category, UIEventData.Category.WORLD)
	assert_ne(discovered[0].severity, UIEventData.Severity.CRITICAL, "nunca alerta crítico")
	assert_true(discovered[0].has_target_coord and discovered[0].target_coord == record.coord, "foco no covil")
	assert_eq(String(RegionalThreatSystem.objectives_for(human)[0].status), "active")
	_destroy_lair(record.coord, human)
	assert_eq(published.filter(func(e): return e.event_type == "regional_threat_resolved" and e.message == "A ameaça regional foi eliminada.").size(), 1)
	UIEvents.event_published.disconnect(capture)
	assert_false(FileAccess.get_file_as_string("res://scripts/ui/AttentionService.gd").contains("RegionalThreat"), "ameaça regional nunca vira Attention (não bloqueia o fim de turno)")

func test_strategic_chip_and_tile_inspector_show_the_discovered_threat():
	var setup := _awake_setup()
	var record: Dictionary = setup.record
	var chips := StrategicAlertPresenter.new()
	add_child_autofree(chips)
	chips.bind_player(human)
	assert_false(_chip_texts(chips).has("Ameaça regional"), "sem chip antes da descoberta")
	human.explored_tiles[record.coord] = true
	RegionalThreatSystem.note_observation(grid, human)
	chips.refresh()
	assert_true(_chip_texts(chips).has("Ameaça regional"))
	var focused: Array = []
	chips.location_requested.connect(func(coord: Vector2i): focused.append(coord))
	for child in chips.get_children():
		if child is Button and child.text == "Ameaça regional":
			child.pressed.emit()
	assert_eq(focused, [record.coord], "chip foca o covil")
	grid.visibility[record.coord] = HexGrid.Visibility.EXPLORED
	var entry := TileInspector._lair_entry(grid.lairs_by_coord[record.coord], record.coord, grid, TileInspector.STATE_EXPLORED)
	assert_true(entry.lines.has("Papel: Ameaça regional"))
	assert_true(entry.lines.has("Ameaça: Adormecido"))
	assert_true(entry.lines.has("Recompensa ao destruir: 40 ouro"))
	for line in entry.lines:
		assert_false(String(line).contains(str(record.wake_turn)) and String(line).contains("T"), "turno de despertar nunca aparece")
	record.state = RegionalThreatSystem.STATE_AWAKE
	entry = TileInspector._lair_entry(grid.lairs_by_coord[record.coord], record.coord, grid, TileInspector.STATE_EXPLORED)
	assert_true(entry.lines.has("Ameaça: Desperto"))

func _chip_texts(chips: StrategicAlertPresenter) -> Array:
	var texts: Array = []
	for child in chips.get_children():
		if child is Button:
			texts.append(child.text)
	return texts
