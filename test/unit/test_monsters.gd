extends GutTest

## Cobre MonsterDatabase (dados dos guardioes de Covil de Monstro) e a
## geracao deterministica de covis no mapa (HexGrid._spawn_monster_lairs).

func test_create_monster_returns_positive_gold_reward():
	for kind in MonsterDatabase.KINDS:
		var data = MonsterDatabase.create_monster(kind)
		assert_gt(data.gold_reward, 0.0, "%s deveria ter recompensa de ouro > 0" % kind)

func test_create_monster_never_moves():
	var data = MonsterDatabase.create_monster("troll")
	assert_eq(data.movement_points, 0.0, "guardiao nunca deveria sair do proprio tile")

func test_random_kind_always_returns_a_known_kind():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(50):
		assert_true(MonsterDatabase.random_kind(rng) in MonsterDatabase.KINDS)

func test_random_kind_is_deterministic_for_same_seed():
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	var sequence_a := []
	var sequence_b := []
	for i in range(10):
		sequence_a.append(MonsterDatabase.random_kind(rng_a))
		sequence_b.append(MonsterDatabase.random_kind(rng_b))
	assert_eq(sequence_a, sequence_b)

func test_generate_map_spawns_monster_lairs_with_neutral_owner():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(12, 321)

	assert_gt(hex_grid.lair_coords.size(), 0, "um mapa medio deveria ter pelo menos um covil")
	for coord in hex_grid.lair_coords:
		var guardian = hex_grid.get_unit_at(coord)
		assert_not_null(guardian, "todo lair_coords deveria ter um guardiao vivo logo apos gerar o mapa")
		assert_null(guardian.owner_player, "guardiao de covil deveria ser neutro (owner_player nulo)")

	hex_grid.queue_free()

func test_monster_lairs_never_spawn_on_ocean():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(14, 4242)

	for coord in hex_grid.lair_coords:
		var data: HexTileData = hex_grid.get_tile(coord)
		assert_ne(data.terrain_type, HexTileData.TerrainType.OCEAN)

	hex_grid.queue_free()

## Regressao: um covil em cima do tile inicial do humano (perto do centro
## do mapa) tornaria o comeco de jogo injusto/impossivel — ver
## HexGrid.LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION.
func test_monster_lairs_never_spawn_too_close_to_map_center():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(16, 99)

	var min_dist = float(hex_grid.map_radius) * HexGrid.LAIR_MIN_DISTANCE_FROM_CENTER_FRACTION
	for coord in hex_grid.lair_coords:
		assert_true(HexMetrics.axial_distance(coord, Vector2i.ZERO) >= min_dist)

	hex_grid.queue_free()

func test_generate_map_lair_placement_is_deterministic_for_same_seed():
	var grid_a := HexGrid.new()
	grid_a._ready()
	grid_a.generate_map(10, 555)

	var grid_b := HexGrid.new()
	grid_b._ready()
	grid_b.generate_map(10, 555)

	assert_eq(grid_a.lair_coords, grid_b.lair_coords, "a mesma semente deveria colocar os covis nos mesmos tiles")

	grid_a.queue_free()
	grid_b.queue_free()
