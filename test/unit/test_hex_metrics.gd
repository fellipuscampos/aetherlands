extends GutTest

## Matematica pura do grid hexagonal — nao depende de scene tree, entao
## roda rapido e sem setup nenhum.

func test_axial_to_world_origin_is_world_origin():
	var world = HexMetrics.axial_to_world(0, 0, 1.0)
	assert_almost_eq(world.x, 0.0, 0.0001)
	assert_almost_eq(world.z, 0.0, 0.0001)

func test_world_to_axial_round_trip():
	for q in range(-3, 4):
		for r in range(-3, 4):
			var world = HexMetrics.axial_to_world(q, r, 1.0)
			var back = HexMetrics.world_to_axial(world.x, world.z, 1.0)
			assert_eq(back, Vector2i(q, r), "round trip falhou pra (%d,%d)" % [q, r])

func test_axial_distance_same_tile_is_zero():
	assert_eq(HexMetrics.axial_distance(Vector2i(2, -1), Vector2i(2, -1)), 0)

func test_axial_distance_direct_neighbor_is_one():
	var origin = Vector2i(0, 0)
	for dir in HexGrid.NEIGHBOR_DIRS:
		assert_eq(HexMetrics.axial_distance(origin, dir), 1, "vizinho %s deveria estar a distancia 1" % dir)

func test_axial_distance_is_symmetric():
	var a = Vector2i(3, -2)
	var b = Vector2i(-1, 4)
	assert_eq(HexMetrics.axial_distance(a, b), HexMetrics.axial_distance(b, a))

func test_corner_returns_six_distinct_points():
	var seen := {}
	for i in range(6):
		var c = HexMetrics.corner(1.0, i)
		seen[c] = true
	assert_eq(seen.size(), 6, "os 6 cantos do hexagono deveriam ser todos diferentes")
