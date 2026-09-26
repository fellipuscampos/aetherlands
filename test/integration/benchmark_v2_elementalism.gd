extends GutTest

## Benchmark reproduzível da Fase 22. Fora de test/unit de propósito.

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var caster: Unit
var _old_grid: HexGrid
var _old_human: PlayerData
var _old_players: Array[PlayerData]
var _old_rivals: Array[PlayerData]
var _old_rival_count: int
var _old_debug: bool
var _old_stagger: bool
var _old_state

func before_each():
	_old_grid = GameManager.hex_grid
	_old_human = GameManager.human_player
	_old_players = GameManager.players
	_old_rivals = GameManager.rival_players
	_old_rival_count = GameManager.rival_count
	_old_debug = GameManager.debug_mode
	_old_stagger = GameManager.stagger_ai_turns
	_old_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-12, 13):
		for r in range(-12, 13):
			if absi(q + r) <= 12:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	for tier in range(1, 10):
		human.v2_research.complete_research("v2_magic_elementalism_%d" % tier)
	caster = grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("v2_unit_elementalist"), human)
	caster.movement_left = caster.unit_data.movement_points
	human.mana = 1000000.0
	grid.recompute_fog(human)

func after_each():
	GameManager.hex_grid = _old_grid
	GameManager.human_player = _old_human
	GameManager.players = _old_players
	GameManager.rival_players = _old_rivals
	GameManager.rival_count = _old_rival_count
	GameManager.debug_mode = _old_debug
	GameManager.stagger_ai_turns = _old_stagger
	GameManager.state = _old_state
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	human.release_relations()
	rival.release_relations()
	grid.queue_free()

func _measure(label: String, iterations: int, operation: Callable) -> float:
	for i in mini(iterations, 20):
		operation.call()
	var started := Time.get_ticks_usec()
	for i in iterations:
		operation.call()
	var per_call := float(Time.get_ticks_usec() - started) / float(iterations)
	print("PHASE22_BENCH %-38s %9.3f us" % [label, per_call])
	return per_call

func _fill_zones(count: int, zone_id: String = "v2_zone_gale", rounds: int = 1000000) -> void:
	grid.v2_environmental_zones.clear()
	var added := 0
	for coord in grid.tiles.keys():
		if added >= count:
			break
		grid.v2_environmental_zones[coord] = {"zone_id": zone_id, "owner_index": 0, "school": "elementalism", "remaining_rounds": rounds}
		added += 1

func test_phase22_environmental_benchmarks():
	var empty_coord := Vector2i(10, 0)
	_measure("zone lookup empty", 100000, func(): V2EnvironmentalZoneSystem.zone_at(empty_coord, grid))
	V2EnvironmentalZoneSystem.apply(grid, empty_coord, "v2_zone_dense_mist", 0, "elementalism", 0, false)
	_measure("zone lookup occupied", 100000, func(): V2EnvironmentalZoneSystem.zone_at(empty_coord, grid))
	_measure("effective vision no zone", 50000, func(): V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid))
	V2EnvironmentalZoneSystem.apply(grid, caster.coord, "v2_zone_dense_mist", 0, "elementalism", 0, false)
	_measure("effective vision with Mist", 50000, func(): V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid))
	var archer := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("archer"), human)
	_measure("ranged multiplier no zone", 50000, func(): V2EnvironmentalZoneSystem.physical_ranged_attack_multiplier(archer, grid))
	V2EnvironmentalZoneSystem.apply(grid, archer.coord, "v2_zone_gale", 0, "elementalism", 0, false)
	_measure("ranged multiplier with Gale", 50000, func(): V2EnvironmentalZoneSystem.physical_ranged_attack_multiplier(archer, grid))

	grid.v2_environmental_zones.clear()
	_measure("round tick 0 zones", 20000, func(): V2EnvironmentalZoneSystem.process_global_round(grid, true))
	_fill_zones(50)
	_measure("round tick 50 zones / 0 victims", 1000, func(): V2EnvironmentalZoneSystem.process_global_round(grid, true))
	_fill_zones(100)
	_measure("round tick 100 zones / 0 victims", 1000, func(): V2EnvironmentalZoneSystem.process_global_round(grid, true))

	for unit in human.units.duplicate():
		if unit != caster and unit != archer:
			grid.remove_unit(unit)
	grid.v2_environmental_zones.clear()
	var victims: Array[Unit] = []
	for coord in grid.tiles.keys():
		if victims.size() >= 50:
			break
		if grid.get_unit_at(coord) != null:
			continue
		var victim := grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), human)
		victim.unit_data.max_hp = 100000.0
		victim.hp = 100000.0
		victims.append(victim)
		grid.v2_environmental_zones[coord] = {"zone_id": "v2_zone_lightning_storm", "owner_index": 0, "school": "elementalism", "remaining_rounds": 1000000}
	_measure("round tick 50 zones / 50 Units", 100, func(): V2EnvironmentalZoneSystem.process_global_round(grid, true))

	for victim in victims:
		grid.remove_unit(victim)
	grid.v2_environmental_zones.clear()
	grid.recompute_fog(human)
	var mist := V2SpellDatabase.get_spell("v2_spell_dense_mist")
	var cataclysm := V2SpellDatabase.get_spell("v2_spell_elemental_cataclysm")
	_measure("target TILE range 4", 2000, func(): V2MagicRuntime.target_tiles(caster, mist, grid))
	_measure("target TILE range 5", 2000, func(): V2MagicRuntime.target_tiles(caster, cataclysm, grid))
	_measure("apply+fog Mist radius 1", 30, func():
		grid.v2_environmental_zones.clear()
		grid.refresh_all_environmental_zone_markers()
		V2EnvironmentalZoneSystem.apply_area(caster, mist.environmental_zone_id, caster.coord, 1, grid)
	)
	_measure("apply+fog Cataclysm radius 2", 30, func():
		grid.v2_environmental_zones.clear()
		grid.refresh_all_environmental_zone_markers()
		V2EnvironmentalZoneSystem.apply_area(caster, cataclysm.environmental_zone_id, caster.coord, 2, grid)
	)
	_measure("Dispel one zone cell", 200, func():
		grid.v2_environmental_zones[caster.coord] = {"zone_id": "v2_zone_dense_mist", "owner_index": 0, "school": "elementalism", "remaining_rounds": 2}
		V2EnvironmentalZoneSystem.remove(grid, caster.coord, true, true)
	)

	_fill_zones(100)
	var saved := V2EnvironmentalZoneSystem.to_save_array(grid)
	_measure("restore 100 markers from save", 20, func(): V2EnvironmentalZoneSystem.load_save_array(saved, grid))

	grid.v2_environmental_zones.clear()
	var path_start := Vector2i.ZERO
	var path_end := Vector2i(8, 0)
	var baseline_path := grid.compute_path(path_start, path_end, human, false, false)
	_measure("compute_path without zones", 500, func(): grid.compute_path(path_start, path_end, human, false, false))
	_fill_zones(100)
	_measure("compute_path with 100 zones", 500, func(): grid.compute_path(path_start, path_end, human, false, false))
	assert_eq(grid.compute_path(path_start, path_end, human, false, false), baseline_path)

	# Turno real, sem reimplementar o loop: mapa normal e três rivais pelo GameManager.
	grid.queue_free()
	grid = HexGrid.new()
	grid._ready()
	grid.generate_map(41, 41, 22022)
	GameManager.rival_count = 3
	GameManager.debug_mode = false
	GameManager.stagger_ai_turns = false
	GameManager.start_new_game(grid)
	var turn_started := Time.get_ticks_usec()
	GameManager._on_turn_changed(0, 0)
	print("PHASE22_BENCH %-38s %9.3f us" % ["full global turn / 3 rivals", float(Time.get_ticks_usec() - turn_started)])
