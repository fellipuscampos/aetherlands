extends GutTest

## V3 / Combat Ecology — Etapa 1 (Foundation): roster 4/4/4 com tier explícito, stats legados preservados,
## tier ≠ papel, placeholders, colocação (zona de segurança por tier, espaçamento, tiles legais, cobertura
## das 12 espécies, adoção de covil legado sem duplicar), atividade REAL por Era (cenário controlado com
## cidade + BASIC + INTERMEDIATE + ADVANCED nas três eras), raide sem captura, alvo por posição (nunca por
## identidade humana), reposição (fora de visão, sem substituição instantânea, cadência, peso da Era),
## inspector e hostilidade/ocupação para a IA.

const RADIUS := 27

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _events: Array = []
var _connections: Array = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "combat_ecology_on_new_match"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	_events.clear()
	var callable := func(action: String, info: Dictionary): _events.append([action, info.duplicate()])
	EventBus.combat_ecology_event.connect(callable)
	_connections.append([EventBus.combat_ecology_event, callable])

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

## Hexágono de grama de raio `radius`, humano + rival, sem cidades. Ecologia resetada (desligada).
func _world(radius: int = RADIUS, map_seed: int = 777) -> void:
	grid = HexGrid.new()
	grid._ready()
	grid.map_seed = map_seed
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
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

## Mundo grande (terra de mapa padrão, alvos cheios) com duas capitais e a ecologia populada.
func _populated_world(map_seed: int = 777) -> void:
	_world(RADIUS, map_seed)
	grid.found_city(Vector2i(-12, 0), human, "Capital A", true)
	grid.found_city(Vector2i(12, 0), rival, "Capital B", true)
	MonsterEcologySystem.populate_new_match(grid, true)

## Sítio manual (cenário controlado) com um membro na âncora; liga a ecologia.
func _site(kind: String, anchor: Vector2i) -> Unit:
	MonsterEcologySystem.enabled = true
	var site := MonsterEcologySystem._create_site(grid, kind, anchor, HexGrid.NO_LAIR, MonsterEcologySystem.SOURCE_INITIAL, TurnManager.turn_number, [anchor] as Array[Vector2i])
	return grid.get_unit_at(anchor) if int(site.id) > 0 else null

func _act(unit: Unit, turn: int) -> void:
	if not is_instance_valid(unit):
		return
	TurnManager.turn_number = turn
	unit.reset_movement()
	MonsterAI.act_for_unit(unit, grid, turn)

func _count(action: String, tier: String = "") -> int:
	return _events.filter(func(e): return e[0] == action and (tier == "" or String(e[1].tier) == tier)).size()

func _ecology_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in grid.neutral_units():
		if unit.ecology_site_id >= 0:
			result.append(unit)
	return result

# --- Roster / dados ------------------------------------------------------------------------------

func test_roster_is_4_4_4_with_explicit_tiers_and_no_dragon():
	var expected := {
		MonsterEcologyData.TIER_BASIC: ["goblin", "skeleton", "worg", "giant_spider"],
		MonsterEcologyData.TIER_INTERMEDIATE: ["troll", "wyvern", "minotaur", "basilisk"],
		MonsterEcologyData.TIER_ADVANCED: ["colossal_worm", "arboreal_ancient", "mana_devourer", "corrupted_hero"],
	}
	for tier in expected:
		assert_eq(Array(MonsterEcologyData.species_of_tier(tier)), expected[tier], "tier %s" % tier)
		for kind in expected[tier]:
			assert_eq(String(MonsterEcologyData.SPECIES[kind].tier), tier, "%s declara o tier explicitamente" % kind)
			assert_true(MonsterDatabase.KIND_DATA.has(kind), "%s tem UnitData" % kind)
	assert_eq(MonsterEcologyData.SPECIES_ORDER.size(), 12)
	assert_eq(MonsterEcologyData.tier_of("dragon"), "", "Dragão fica fora da ecologia")
	assert_false("dragon" in MonsterEcologyData.SPECIES_ORDER)
	# Espécies novas nunca entram no sorteio legado dos covis da seed.
	for kind in ["worg", "giant_spider", "minotaur", "basilisk", "colossal_worm", "arboreal_ancient", "mana_devourer", "corrupted_hero"]:
		assert_false(kind in MonsterDatabase.KINDS, "%s fora de KINDS" % kind)
	assert_eq(MonsterDatabase.KINDS, ["goblin", "troll", "wyvern", "skeleton", "dragon"])

func test_existing_monster_stats_are_preserved():
	var legacy := {
		"goblin": [3.0, 2.0, 8.0, 1.0, 15.0], "skeleton": [4.0, 1.0, 6.0, 2.0, 10.0],
		"troll": [6.0, 4.0, 20.0, 1.0, 35.0], "wyvern": [8.0, 3.0, 16.0, 3.0, 70.0],
	}
	for kind in legacy:
		var data := MonsterDatabase.create_monster(kind)
		assert_eq([data.attack, data.defense, data.max_hp, data.movement_points, data.gold_reward], legacy[kind], "%s inalterado" % kind)
	assert_true(MonsterDatabase.create_monster("wyvern").flies, "Vivern continua voando")

func test_new_species_bands_follow_the_tier():
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var data := MonsterDatabase.create_monster(kind)
		assert_eq(data.visual_kind, kind)
		assert_gt(data.max_hp, 0.0)
		assert_gt(data.attack, 0.0)
		assert_true(data.can_basic_attack, "%s ataca com ataque básico" % kind)
	var dragon := MonsterDatabase.create_monster("dragon")
	for kind in MonsterEcologyData.species_of_tier(MonsterEcologyData.TIER_ADVANCED):
		var data := MonsterDatabase.create_monster(kind)
		assert_gt(data.attack + data.defense + data.max_hp, MonsterDatabase.create_monster("troll").attack + 4.0 + 20.0, "%s claramente acima de INTERMEDIATE" % kind)
		assert_lt(data.max_hp, dragon.max_hp, "%s sem HP absurdo (abaixo do Dragão)" % kind)
	for kind in MonsterEcologyData.species_of_tier(MonsterEcologyData.TIER_BASIC):
		assert_lte(MonsterDatabase.create_monster(kind).max_hp, 10.0, "%s na banda de Goblin/Esqueleto" % kind)

func test_every_species_spawns_with_a_distinct_visual_moves_fights_and_dies():
	_world(12)
	var soldier := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), human)
	var index := 0
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var coord := Vector2i(-8 + (index % 6) * 3, -3 + (index / 6) * 6)
		var monster := grid.spawn_monster_at(coord, kind)
		assert_eq(monster.unit_data.visual_kind, kind)
		assert_gt(monster.get_child_count(), 0, "%s tem corpo visual" % kind)
		# move
		var reachable := grid.compute_reachable(monster.coord, monster.unit_data.movement_points, null, monster.unit_data.flies)
		var dest := HexGrid.NO_LAIR
		for option in MonsterEcologyPlanner.sorted_coords(reachable.keys()):
			if option != monster.coord:
				dest = option
				break
		assert_ne(dest, HexGrid.NO_LAIR, "%s consegue se mover" % kind)
		grid.move_unit(monster, dest, reachable[dest])
		assert_eq(monster.coord, dest)
		# luta (ataque básico contra um Guarda adjacente) e morre
		grid.teleport_unit(soldier, grid.get_neighbors(monster.coord).filter(func(c): return grid.get_unit_at(c) == null)[0])
		soldier.hp = soldier.unit_data.max_hp
		var monster_hp := monster.hp
		CombatResolver.resolve(monster, soldier, grid)
		assert_true(not is_instance_valid(soldier) or soldier.hp < soldier.unit_data.max_hp or monster.hp < monster_hp, "%s luta" % kind)
		if not is_instance_valid(soldier):
			soldier = grid.spawn_unit(Vector2i(0, 0) if grid.get_unit_at(Vector2i(0, 0)) == null else Vector2i(1, 0), UnitDatabase.create_unit("warrior"), human)
		monster.hp = 0.0
		grid.remove_unit(monster)
		assert_null(grid.get_unit_at(dest), "%s morre e sai do mapa" % kind)
		index += 1
	for kind in MonsterPlaceholderVisuals.KINDS:
		assert_true(MonsterEcologyData.is_ecology_species(kind))
		assert_true(Unit.MONSTER_KIND_COLORS.has(kind), "%s tem cor própria" % kind)

func test_tier_is_independent_from_the_lair_role():
	_world(20)
	WorldEventManager.regional_threats_enabled = true
	grid.found_city(Vector2i.ZERO, human, "Capital")
	var record := RegionalThreatSystem.record_for_index(0)
	assert_false(record.is_empty())
	assert_eq(grid.lair_role(record.coord), HexGrid.LAIR_ROLE_REGIONAL, "papel continua REGIONAL")
	assert_eq(MonsterEcologyData.tier_of(String(record.kind)), MonsterEcologyData.TIER_BASIC, "Goblin/Esqueleto regional = BASIC + REGIONAL")
	for member in grid.lair_members(record.coord):
		assert_eq(member.ecology_site_id, -1, "monstro regional não pertence à ecologia")
		assert_true(RegionalThreatSystem.monster_directive(member, grid).size() > 0, "diretiva regional intacta")
	var guardian := grid.create_lair(Vector2i(0, 15), "troll", HexGrid.LAIR_ROLE_GUARDIAN, Vector2i(1, 15))
	assert_eq(MonsterEcologyData.tier_of(guardian.unit_data.visual_kind), MonsterEcologyData.TIER_INTERMEDIATE, "Troll Guardião = INTERMEDIATE + GUARDIAN")
	assert_eq(grid.lair_role(Vector2i(0, 15)), HexGrid.LAIR_ROLE_GUARDIAN)
	assert_true(MonsterEcologySystem.monster_directive(guardian).is_empty(), "Guardião não recebe diretiva ecológica")
	var lines: Array = TileInspector._monster_entry(guardian, grid).lines
	assert_true("Criatura Intermediária" in lines, "inspector mostra o tier do Guardião")

# --- Colocação -----------------------------------------------------------------------------------

func test_initial_population_fills_every_tier_safely_and_covers_all_species():
	_populated_world()
	var targets := MonsterEcologySystem.targets
	assert_between(int(targets[MonsterEcologyData.TIER_BASIC]), 24, 32)
	assert_between(int(targets[MonsterEcologyData.TIER_INTERMEDIATE]), 12, 16)
	assert_between(int(targets[MonsterEcologyData.TIER_ADVANCED]), 6, 8)
	var by_tier := MonsterEcologySystem.sites_by_tier()
	for tier in MonsterEcologyData.TIERS:
		assert_eq(int(by_tier[tier]), int(targets[tier]), "%s preenchido" % tier)
	var species := {}
	var anchors: Array[Vector2i] = [Vector2i(-12, 0), Vector2i(12, 0)]
	for unit in _ecology_units():
		var tier := MonsterEcologyData.tier_of(unit.unit_data.visual_kind)
		species[unit.unit_data.visual_kind] = true
		for capital in anchors:
			assert_gte(HexMetrics.axial_distance(capital, unit.coord), int(MonsterEcologyData.CAPITAL_MIN_DISTANCE[tier]), "%s fora da zona de segurança" % unit.unit_data.visual_kind)
		var tile := grid.get_tile(unit.coord)
		assert_false(tile.blocks_land_units(), "terra firme")
		assert_null(grid.get_city_at(unit.coord))
		assert_null(grid.city_owning_tile(unit.coord), "fora de território")
		assert_false(grid.lairs_by_coord.has(unit.coord))
		assert_eq(unit.movement_left, unit.unit_data.movement_points)
		assert_false(unit.is_camp_boss, "sítio novo não cria chefe imóvel")
	assert_eq(species.size(), 12, "as 12 espécies presentes")
	for a in MonsterEcologySystem.sites:
		for b in MonsterEcologySystem.sites:
			if int(a.id) < int(b.id):
				var needed := maxi(int(MonsterEcologyData.SITE_SPACING[MonsterEcologyData.tier_of(String(a.species))]), int(MonsterEcologyData.SITE_SPACING[MonsterEcologyData.tier_of(String(b.species))]))
				assert_gte(HexMetrics.axial_distance(a.anchor, b.anchor), needed, "espaçamento entre sítios")

func test_population_is_spread_across_the_map_not_clustered():
	_populated_world()
	var west := 0
	var north := 0
	var units := _ecology_units()
	for unit in units:
		var point := RegionalThreatPlanner.cartesian(unit.coord)
		west += 1 if point.x < 0.0 else 0
		north += 1 if point.y < 0.0 else 0
	assert_lt(float(west) / units.size(), 0.8)
	assert_gt(float(west) / units.size(), 0.2)
	assert_lt(float(north) / units.size(), 0.8)
	assert_gt(float(north) / units.size(), 0.2)

func test_placement_is_deterministic_for_the_same_world():
	_populated_world(4242)
	var first := _placement_signature()
	grid.queue_free()
	_populated_world(4242)
	assert_eq(_placement_signature(), first, "mesma seed + capitais → mesma ecologia")
	grid.queue_free()
	_populated_world(4243)
	assert_ne(_placement_signature(), first, "seed diferente → ecologia diferente")

func _placement_signature() -> Array:
	var result: Array = []
	for site in MonsterEcologySystem.sites:
		result.append([String(site.species), site.anchor, String(site.source)])
	var units: Array = []
	for unit in _ecology_units():
		units.append([unit.coord, unit.unit_data.visual_kind, unit.ecology_site_id])
	units.sort()
	result.append(units)
	return result

func test_ecology_uses_its_own_rng_and_never_the_monster_or_global_channel():
	_world()
	grid.found_city(Vector2i(-12, 0), human, "Capital A", true)
	grid.found_city(Vector2i(12, 0), rival, "Capital B", true)
	grid.monster_turn_rng.seed = 99
	var monster_state := grid.monster_turn_rng.state
	seed(12345)
	var global_probe := randi()
	seed(12345)
	MonsterEcologySystem.populate_new_match(grid, true)
	assert_eq(grid.monster_turn_rng.state, monster_state, "monster_turn_rng intocado")
	assert_eq(randi(), global_probe, "RNG global intocado")

func test_legacy_wild_lair_is_adopted_not_duplicated_and_close_one_is_removed():
	_world()
	grid.found_city(Vector2i(-12, 0), human, "Capital A", true)
	grid.found_city(Vector2i(12, 0), rival, "Capital B", true)
	var far := Vector2i(0, 16)
	var close := Vector2i(-12, 5)
	grid.create_lair(far, "goblin", HexGrid.LAIR_ROLE_WILD, Vector2i(1, 16))
	grid.create_lair(close, "goblin", HexGrid.LAIR_ROLE_WILD, Vector2i(-11, 5))
	MonsterEcologySystem.populate_new_match(grid, true)
	assert_eq(grid.lair_role(far), HexGrid.LAIR_ROLE_ECOLOGY, "covil válido vira sítio ecológico")
	var adopted: Array = MonsterEcologySystem.sites.filter(func(s): return s.lair == far)
	assert_eq(adopted.size(), 1)
	assert_eq(String(adopted[0].source), MonsterEcologySystem.SOURCE_ADOPTED)
	var members := grid.lair_members(far)
	assert_eq(members.size(), MonsterEcologyData.group_size("goblin"), "chefe legado + complemento até o grupo")
	for member in members:
		assert_eq(member.ecology_site_id, int(adopted[0].id))
	for site in MonsterEcologySystem.sites:
		if site.lair != far:
			assert_gte(HexMetrics.axial_distance(site.anchor, far), MonsterEcologyData.SITE_SPACING[MonsterEcologyData.TIER_BASIC], "nenhum sítio novo colado no covil adotado")
	assert_false(close in grid.lair_coords, "covil legado a < 7 da capital sai no setup")
	# Covil adotado não reforça pelo caminho legado nem promove Invasor.
	var before := grid.lair_population(far)
	grid.monster_turn_rng.seed = 1
	for turn in range(2, 30):
		grid.process_monster_lairs(turn)
		MonsterAI.begin_turn(grid)
	assert_eq(grid.lair_population(far), before, "sem reforço legado")
	for member in grid.lair_members(far):
		assert_eq(member.monster_behavior_state, "", "sem promoção legada a Invasor")

func test_flag_off_leaves_the_map_without_ecology():
	_world()
	grid.found_city(Vector2i(-12, 0), human, "Capital A", true)
	MonsterEcologySystem.populate_new_match(grid, false)
	assert_false(MonsterEcologySystem.enabled)
	assert_true(MonsterEcologySystem.sites.is_empty())
	assert_true(_ecology_units().is_empty())
	MonsterEcologySystem.process_round(grid, 10)
	assert_true(grid.neutral_units().is_empty(), "desligada: nenhuma reposição")

func test_new_match_reset_clears_all_ecology_state():
	_populated_world()
	MonsterEcologySystem.depleted.append({"coord": Vector2i.ZERO, "turn": 1})
	WorldEventManager.reset_for_new_match(1)
	assert_false(MonsterEcologySystem.enabled)
	assert_true(MonsterEcologySystem.sites.is_empty())
	assert_true(MonsterEcologySystem.targets.is_empty())
	assert_true(MonsterEcologySystem.depleted.is_empty())
	assert_eq(MonsterEcologySystem.next_site_id, 1)
	assert_eq(MonsterEcologySystem.next_refill_turn, 0)
	assert_true(MonsterEcologySystem.initial_stats.is_empty())

# --- Atividade por Era (cenário controlado) ------------------------------------------------------

## Cidade humana no centro; BASIC a 9, INTERMEDIATE a 11 e ADVANCED a 11 (manual, fora da regra de setup).
## Etapa 2: o INTERMEDIATE do cenário é a Wyvern (a espécie intermediária que ainda faz raide de cidade) e o
## ADVANCED é o Verme Colossal (nenhum avançado caça cidade; a Convergência amplia a caça a unidades).
func _era_scenario() -> Dictionary:
	_world(22)
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	return {
		"city": city,
		"basic": _site("goblin", Vector2i(9, 0)), "basic_anchor": Vector2i(9, 0),
		# Etapa 3: a Wyvern só faz raide dentro do próprio leash (9 na Ascensão) — fica a 8 da capital.
		"intermediate": _site("wyvern", Vector2i(0, 8)), "intermediate_anchor": Vector2i(0, 8),
		"advanced": _site("colossal_worm", Vector2i(-11, 0)), "advanced_anchor": Vector2i(-11, 0),
	}

func _max_distance_from_anchor(anchor: Vector2i, samples: Array) -> int:
	var best := 0
	for coord in samples:
		best = maxi(best, HexMetrics.axial_distance(anchor, coord))
	return best

func test_foundation_basic_presses_the_city_while_higher_tiers_stay_territorial():
	var s := _era_scenario()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	var trail := {"intermediate": [], "advanced": []}
	for turn in range(12, 32):
		for key in ["basic", "intermediate", "advanced"]:
			_act(s[key], turn)
		trail.intermediate.append(s.intermediate.coord)
		trail.advanced.append(s.advanced.coord)
	assert_gt(_count("city_attack", MonsterEcologyData.TIER_BASIC), 0, "BASIC chega e golpeia a cidade no Despertar")
	assert_eq(s.city.owner_player, human, "monstro nunca captura")
	assert_gte(s.city.hp, 1.0)
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_INTERMEDIATE), 0, "INTERMEDIATE não caça cidade no Despertar")
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_ADVANCED), 0, "ADVANCED não caça cidade no Despertar")
	assert_lte(_max_distance_from_anchor(s.intermediate_anchor, trail.intermediate), 5, "INTERMEDIATE patrulha curta (4–5)")
	assert_lte(_max_distance_from_anchor(s.advanced_anchor, trail.advanced), 3, "ADVANCED fortemente territorial (2–4)")
	for event in _events:
		assert_eq(String(event[1].phase), "FOUNDATION")

func test_foundation_city_pressure_waits_for_the_opening_turn():
	var s := _era_scenario()
	var opening := int(MonsterActivityProfile.for_tier(MonsterEcologyData.TIER_BASIC, WorldPhaseRules.Phase.FOUNDATION).city_from_turn)
	assert_gt(opening, 1)
	for turn in range(1, opening):
		_act(s.basic, turn)
	assert_eq(_count("city_attack"), 0)
	assert_lte(HexMetrics.axial_distance(s.basic.coord, s.basic_anchor), 6, "antes da abertura, só o território")

func test_basic_raid_rests_then_returns_instead_of_sieging():
	var s := _era_scenario()
	var struck_turn := -1
	for turn in range(12, 40):
		_act(s.basic, turn)
		if struck_turn < 0 and _count("city_attack") > 0:
			struck_turn = turn
	assert_gt(struck_turn, 0)
	var rest := int(MonsterActivityProfile.for_tier(MonsterEcologyData.TIER_BASIC, WorldPhaseRules.Phase.FOUNDATION).raid_rest_turns)
	assert_gte(s.basic.ecology_rest_until, struck_turn + 1, "descanso marcado após o raide")
	var strikes_in_rest := 0
	_events.clear()
	for turn in range(struck_turn + 1, struck_turn + rest):
		_act(s.basic, turn)
	strikes_in_rest = _count("city_attack")
	assert_eq(strikes_in_rest, 0, "não golpeia de novo durante o descanso (sem cerco permanente)")
	assert_gt(HexMetrics.axial_distance(s.basic.coord, s.city.coord), 1, "saiu da porta da cidade")

func test_ascension_basic_stops_city_hunt_but_still_attacks_a_passing_unit_and_intermediate_presses():
	var s := _era_scenario()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	var basic_trail: Array = []
	var advanced_trail: Array = []
	for turn in range(40, 62):
		for key in ["basic", "intermediate", "advanced"]:
			_act(s[key], turn)
		basic_trail.append(s.basic.coord)
		advanced_trail.append(s.advanced.coord)
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_BASIC), 0, "BASIC deixa de caçar cidade na Ascensão")
	assert_lte(_max_distance_from_anchor(s.basic_anchor, basic_trail), 5, "BASIC local")
	assert_gt(_count("city_attack", MonsterEcologyData.TIER_INTERMEDIATE), 0, "INTERMEDIATE pressiona a cidade próxima")
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_ADVANCED), 0, "ADVANCED ainda sem city-hunt")
	assert_lte(_max_distance_from_anchor(s.advanced_anchor, advanced_trail), 6, "ADVANCED patrulha maior, ainda territorial")
	# Unidade passando dentro do raio local do BASIC → ataque.
	var passer_coord: Vector2i = s.basic.coord + Vector2i(0, 1) if grid.get_unit_at(s.basic.coord + Vector2i(0, 1)) == null else s.basic.coord + Vector2i(1, -1)
	grid.spawn_unit(passer_coord, UnitDatabase.create_unit("warrior"), human)
	_events.clear()
	_act(s.basic, 70)
	assert_eq(_count("attack", MonsterEcologyData.TIER_BASIC), 1, "BASIC ataca quem passa perto")

func test_convergence_advanced_becomes_active_without_city_siege():
	var s := _era_scenario()
	# Intruso a 8 da âncora do ADVANCED: fora do território dele no Despertar, dentro do raio de interesse na Convergência.
	var intruder := grid.spawn_unit(Vector2i(-11, 8), UnitDatabase.create_unit("warrior"), human)
	intruder.unit_data.max_hp = 500.0
	intruder.hp = 500.0
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	for turn in range(60, 66):
		_act(s.advanced, turn)
	var foundation_activity := _events.filter(func(e): return String(e[1].tier) == MonsterEcologyData.TIER_ADVANCED and e[0] in ["move", "ability", "attack"]).size()
	assert_eq(foundation_activity, 0, "Despertar: ADVANCED ignora quem está fora do território")
	_events.clear()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.CONVERGENCE
	var basic_trail: Array = []
	for turn in range(100, 130):
		for key in ["basic", "intermediate", "advanced"]:
			_act(s[key], turn)
		basic_trail.append(s.basic.coord)
	assert_gt(_events.filter(func(e): return String(e[1].tier) == MonsterEcologyData.TIER_ADVANCED and e[0] in ["move", "ability", "attack"]).size(), 0, "Convergência: ADVANCED caça a unidade dentro do raio de interesse")
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_ADVANCED), 0, "atividade avançada não é cerco de cidade")
	assert_eq(_count("city_attack", MonsterEcologyData.TIER_BASIC), 0, "BASIC baixa pressão")
	assert_lte(_max_distance_from_anchor(s.basic_anchor, basic_trail), 4, "BASIC local e oportunista")
	assert_eq(s.city.owner_player, human, "nunca captura")
	var foundation := MonsterActivityProfile.for_tier(MonsterEcologyData.TIER_ADVANCED, WorldPhaseRules.Phase.FOUNDATION)
	var convergence := MonsterActivityProfile.for_tier(MonsterEcologyData.TIER_ADVANCED, WorldPhaseRules.Phase.CONVERGENCE)
	assert_gt(int(convergence.patrol_radius), int(foundation.patrol_radius))
	assert_gt(int(convergence.chase_radius), int(foundation.chase_radius))
	assert_gt(float(convergence.roam_chance), float(foundation.roam_chance))

func test_era_never_removes_or_protects_a_creature():
	var s := _era_scenario()
	for phase in [WorldPhaseRules.Phase.FOUNDATION, WorldPhaseRules.Phase.ASCENSION, WorldPhaseRules.Phase.CONVERGENCE]:
		WorldEventManager.world_phase = phase
		_act(s.advanced, 50)
		assert_true(is_instance_valid(s.advanced), "continua existindo")
		assert_false(MonsterEcologySystem.monster_directive(s.basic).is_empty(), "continua com diretiva")
	var soldier := grid.spawn_unit(s.advanced.coord + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), human)
	assert_true(CombatResolver.is_hostile_unit_target(human, s.advanced, grid), "continua vulnerável")
	assert_not_null(soldier)

## 2026-10-04: o Herói Corrompido substitui a Colmeia Micótica — ADVANCED padrão (sem o teto "quase imóvel" da
## Colmeia nem a infecção), mesmo ataque, modelo próprio; save antigo com "mycotic_hive" vira o Herói.
func test_corrupted_hero_replaces_the_hive_with_the_standard_advanced_profile():
	assert_false(MonsterEcologyData.is_ecology_species("mycotic_hive"), "a Colmeia saiu do bestiário")
	assert_eq(MonsterEcologyData.tier_of("corrupted_hero"), MonsterEcologyData.TIER_ADVANCED)
	assert_eq(MonsterEcologyData.patrol_radius_cap("corrupted_hero"), -1, "sem o teto de raio da Colmeia")
	assert_false(MonsterAbilityData.species_has("corrupted_hero", MonsterAbilityData.MYCOTIC_CONTAMINATION), "sem infecção")
	assert_true(MonsterAbilityData.species_has("corrupted_hero", MonsterAbilityData.SHIELD_BLOCK), "habilidade própria: Bloqueio com Escudo")
	for phase in [WorldPhaseRules.Phase.FOUNDATION, WorldPhaseRules.Phase.ASCENSION, WorldPhaseRules.Phase.CONVERGENCE]:
		assert_eq(MonsterActivityProfile.for_species("corrupted_hero", phase), MonsterActivityProfile.for_tier(MonsterEcologyData.TIER_ADVANCED, phase), "perfil ADVANCED padrão")
	var data := MonsterDatabase.create_monster("corrupted_hero")
	assert_eq(data.unit_name, "Herói Corrompido")
	assert_eq(data.attack, 8.0, "mesmo ataque da Colmeia")
	assert_eq(data.idle_animation_override, "Hero_Idle")
	assert_eq(data.walk_animation_override, "Hero_Walk")
	assert_eq(data.attack_animation_override, "Hero_Attack")
	assert_eq(data.block_animation_override, "Hero_Block")
	assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
	assert_eq(MonsterDatabase.create_monster("mycotic_hive").visual_kind, "corrupted_hero", "save antigo carrega o Herói")

func test_corrupted_hero_leaves_its_anchor_only_in_its_era():
	_world(16)
	var hero := _site("corrupted_hero", Vector2i(5, 5))
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	for turn in 20:
		_act(hero, 100 + turn)
		assert_lte(HexMetrics.axial_distance(hero.coord, Vector2i(5, 5)), int(MonsterActivityProfile.for_species("corrupted_hero", WorldPhaseRules.Phase.FOUNDATION).chase_radius), "Despertar: fica na região")

# --- Fairness -----------------------------------------------------------------------------------

func test_target_selection_depends_on_position_never_on_human_identity():
	_world(22)
	var west := grid.found_city(Vector2i(-6, 0), human, "Oeste", true)
	var east := grid.found_city(Vector2i(6, 0), rival, "Leste", true)
	assert_eq(MonsterAI._ecology_city_target(Vector2i.ZERO, 12), west, "empate → coordenada")
	# Troca os donos: a MESMA cidade (mesma posição) continua escolhida.
	grid.capture_city(west, rival)
	grid.capture_city(east, human)
	assert_eq(MonsterAI._ecology_city_target(Vector2i.ZERO, 12), west, "dono humano/IA não muda o alvo")
	# Distância manda: a mais próxima vence, seja de quem for.
	assert_eq(MonsterAI._ecology_city_target(Vector2i(2, 0), 12), east)
	assert_eq(MonsterAI._ecology_city_target(Vector2i(-2, 0), 12), west)
	# Unidades equidistantes: mesma regra.
	var a := grid.spawn_unit(Vector2i(0, 4), UnitDatabase.create_unit("warrior"), human)
	var b := grid.spawn_unit(Vector2i(0, -4), UnitDatabase.create_unit("warrior"), rival)
	var chosen = MonsterAI._ecology_nearest_civ_unit(Vector2i.ZERO, 6)
	assert_eq(chosen, Vector2i(0, -4), "desempate por coordenada")
	grid.remove_unit(a)
	grid.remove_unit(b)
	grid.spawn_unit(Vector2i(0, 4), UnitDatabase.create_unit("warrior"), rival)
	grid.spawn_unit(Vector2i(0, -4), UnitDatabase.create_unit("warrior"), human)
	assert_eq(MonsterAI._ecology_nearest_civ_unit(Vector2i.ZERO, 6), Vector2i(0, -4), "trocar o dono não muda a escolha")

func test_ai_sees_ecology_monsters_as_hostile_blocking_and_only_when_visible():
	_world(20)
	var city := grid.found_city(Vector2i.ZERO, rival, "IA", true)
	var near := _site("minotaur", Vector2i(3, 0))
	var hidden := _site("basilisk", Vector2i(15, 0))
	var soldier := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	assert_true(CombatResolver.is_hostile_unit_target(rival, near, grid))
	assert_true(CombatResolver.can_attack_unit(soldier, near, grid) or soldier.movement_left <= 0.0)
	var reachable := grid.compute_reachable(soldier.coord, 5.0, rival)
	assert_false(reachable.has(near.coord), "tile do monstro não é livre para a IA")
	var context := CitySite.build_context(grid, rival, rival.explored_tiles)
	assert_false(hidden.coord in context.monsters, "monstro escondido fora do score (sem onisciência)")
	assert_true(near.coord in context.monsters, "monstro visível entra no score")
	assert_not_null(city)

# --- Reposição -----------------------------------------------------------------------------------

func _kill_site(site: Dictionary) -> void:
	for unit in grid.neutral_units():
		if unit.ecology_site_id == int(site.id):
			unit.hp = 0.0
			grid.remove_unit(unit)

func test_refill_restores_population_out_of_vision_and_never_on_top_of_players():
	_populated_world()
	# Olhos espalhados de ambas as civs: tudo visto por elas fica proibido.
	for coord in [Vector2i(-20, 8), Vector2i(0, -20), Vector2i(20, -8), Vector2i(0, 20), Vector2i(0, 0)]:
		if grid.get_unit_at(coord) == null:
			grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), human if coord.x <= 0 else rival)
	var killed: Array = MonsterEcologySystem.sites.slice(0, 6)
	var killed_anchors: Array = []
	for site in killed:
		killed_anchors.append(site.anchor)
		_kill_site(site)
	var before := MonsterEcologySystem.sites.size()
	var refills: Array = []
	for turn in range(2, 90):
		MonsterEcologySystem.process_round(grid, turn)
		var visible := {}
		for player in GameManager.players:
			visible.merge(grid.compute_visible_tiles(player))
		for site in MonsterEcologySystem.sites:
			if String(site.source) == MonsterEcologySystem.SOURCE_REFILL and not site in refills:
				refills.append(site)
				assert_false(visible.has(site.anchor), "reposição fora de toda visão")
				for player in GameManager.players:
					for unit in player.units:
						assert_gte(HexMetrics.axial_distance(unit.coord, site.anchor), MonsterEcologyData.REFILL_MIN_CIV_DISTANCE, "nunca adjacente a unidade")
					for city in player.cities:
						assert_gt(HexMetrics.axial_distance(city.coord, site.anchor), 1, "nunca adjacente a cidade")
				assert_true(MonsterEcologyPlanner.capital_distance_ok(site.anchor, MonsterEcologyData.tier_of(String(site.species)), MonsterEcologySystem.capital_anchors()))
				for old in killed_anchors:
					if turn - 2 < MonsterEcologyData.REFILL_DEPLETED_COOLDOWN:
						assert_gt(HexMetrics.axial_distance(old, site.anchor), MonsterEcologyData.REFILL_DEPLETED_RADIUS, "não repovoa o lugar recém-limpo")
	assert_eq(MonsterEcologySystem.sites.size(), before, "população volta ao alvo")
	assert_eq(refills.size(), 6)
	assert_eq(_count("refill"), 6)
	assert_eq(_count("site_depleted"), 6)

func test_no_instant_replacement_and_one_site_per_cadence():
	_populated_world()
	# Um BASIC (o tier mais fácil de repor) morre: na MESMA rodada nada renasce naquele lugar.
	var site: Dictionary = MonsterEcologySystem.sites.filter(func(x): return MonsterEcologyData.tier_of(String(x.species)) == MonsterEcologyData.TIER_BASIC)[0]
	var anchor: Vector2i = site.anchor
	var total := MonsterEcologySystem.sites.size()
	_kill_site(site)
	MonsterEcologySystem.next_refill_turn = 5
	MonsterEcologySystem.process_round(grid, 5)
	assert_lte(_count("refill"), 1, "no máximo UM sítio por rodada")
	for other in MonsterEcologySystem.sites:
		assert_gt(HexMetrics.axial_distance(other.anchor, anchor), 0, "o sítio limpo saiu do registro")
		if String(other.source) == MonsterEcologySystem.SOURCE_REFILL:
			assert_gt(HexMetrics.axial_distance(other.anchor, anchor), MonsterEcologyData.REFILL_DEPLETED_RADIUS, "nunca no mesmo lugar")
	# Cadência: vários sítios mortos de uma vez → reposições espaçadas por >= REFILL_INTERVAL rodadas.
	for dead in MonsterEcologySystem.sites.filter(func(x): return MonsterEcologyData.tier_of(String(x.species)) == MonsterEcologyData.TIER_BASIC).slice(0, 3):
		_kill_site(dead)
	var refill_turns: Array = []
	for turn in range(6, 60):
		var before := _count("refill")
		MonsterEcologySystem.process_round(grid, turn)
		if _count("refill") > before:
			refill_turns.append(turn)
	for i in range(1, refill_turns.size()):
		assert_gte(int(refill_turns[i]) - int(refill_turns[i - 1]), MonsterEcologyData.REFILL_INTERVAL, "uma oportunidade por intervalo")
	assert_eq(MonsterEcologySystem.sites.size(), total, "reposto gradualmente até o alvo")

func test_refill_tier_follows_the_era_weights_and_only_tiers_in_deficit():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var all_deficit := {MonsterEcologyData.TIER_BASIC: 5, MonsterEcologyData.TIER_INTERMEDIATE: 5, MonsterEcologyData.TIER_ADVANCED: 5}
	for phase in MonsterEcologyData.REFILL_WEIGHTS:
		var counts := {}
		for i in 6000:
			var tier := MonsterEcologyPlanner.choose_refill_tier(phase, all_deficit, rng)
			counts[tier] = int(counts.get(tier, 0)) + 1
		for tier in MonsterEcologyData.TIERS:
			var expected := float(MonsterEcologyData.REFILL_WEIGHTS[phase][tier]) / 100.0
			assert_almost_eq(float(counts.get(tier, 0)) / 6000.0, expected, 0.03, "era %d, %s" % [phase, tier])
	var only_basic := {MonsterEcologyData.TIER_BASIC: 1, MonsterEcologyData.TIER_INTERMEDIATE: 0, MonsterEcologyData.TIER_ADVANCED: 0}
	for i in 50:
		assert_eq(MonsterEcologyPlanner.choose_refill_tier(WorldPhaseRules.Phase.CONVERGENCE, only_basic, rng), MonsterEcologyData.TIER_BASIC)
	assert_eq(MonsterEcologyPlanner.choose_refill_tier(WorldPhaseRules.Phase.FOUNDATION, {}, rng), "")

func test_dragon_event_never_marches_ecology_monsters_to_a_foreign_lair():
	# Etapa 2: o Dragão não recolhe a ecologia (ver test_v3_e2_abilities); ela nunca atravessa o mapa até covil alheio.
	_world(22)
	var worg := _site("worg", Vector2i(10, 0))
	grid.teleport_unit(worg, Vector2i(0, 0))
	grid.create_lair(Vector2i(-15, 0), "goblin", HexGrid.LAIR_ROLE_WILD)
	var dragon := DragonEvent.new()
	WorldEventManager.active_events.append(dragon)
	for turn in 6:
		_act(worg, 40 + turn)
	WorldEventManager.active_events.erase(dragon)
	assert_lte(HexMetrics.axial_distance(worg.coord, Vector2i(10, 0)), 8, "fica no próprio território")
	assert_gt(HexMetrics.axial_distance(worg.coord, Vector2i(-15, 0)), 8, "não marcha até o covil selvagem")

# --- UI / telemetria -----------------------------------------------------------------------------

func test_inspector_shows_name_tier_stats_and_the_species_abilities():
	# Etapa 2: as habilidades existem — cada espécie mostra as próprias (nome + descrição curta).
	_world(12)
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var unit := _site(kind, Vector2i(MonsterEcologyData.SPECIES_ORDER.find(kind) - 6, 3))
		var entry := TileInspector._monster_entry(unit, grid)
		assert_eq(String(entry.title), String(MonsterDatabase.KIND_DATA[kind].unit_name))
		var text := "
".join(entry.lines)
		assert_true(text.contains("Criatura %s" % MonsterEcologyData.tier_display(MonsterEcologyData.tier_of(kind))), kind)
		assert_true(text.contains("HP "), kind)
		assert_true(text.contains("Comportamento:"), kind)
		for ability_id in MonsterAbilityData.for_species(kind):
			assert_true(text.contains(String(MonsterAbilityData.get_ability(ability_id).name)), "%s mostra %s" % [kind, ability_id])

func test_ecology_events_carry_species_tier_phase_and_target_seat():
	var s := _era_scenario()
	WorldEventManager.world_phase = WorldPhaseRules.Phase.FOUNDATION
	for turn in range(12, 30):
		_act(s.basic, turn)
	var strikes := _events.filter(func(e): return e[0] == "city_attack")
	assert_false(strikes.is_empty())
	var info: Dictionary = strikes[0][1]
	assert_eq(String(info.species), "goblin")
	assert_eq(String(info.tier), MonsterEcologyData.TIER_BASIC)
	assert_eq(String(info.phase), "FOUNDATION")
	assert_eq(int(info.target), 0, "assento do dono da cidade")
	assert_true(bool(info.ecology))

func test_debug_summary_lists_counts_and_finds_an_example():
	_populated_world()
	var summary := MonsterEcologySystem.debug_summary(grid)
	assert_true(summary.contains("Básica"))
	for kind in MonsterEcologyData.SPECIES_ORDER:
		assert_true(summary.contains(String(MonsterDatabase.KIND_DATA[kind].unit_name)), kind)
		assert_ne(MonsterEcologySystem.debug_example_coord(grid, kind), HexGrid.NO_LAIR, "%s localizável" % kind)
