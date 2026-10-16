extends GutTest

## Contorno de território estilo Civilization (TerritoryBorder + HexGrid._build_city_border_mesh): só as arestas do
## limite ganham faixa, com junções exatas (convexas e côncavas), borda cheia entre donos diferentes e divisão fina
## entre cidades da mesma civ.

var _players: Array[PlayerData] = []
var _cities: Array[City] = []

func after_each() -> void:
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	return player

func _city(player: PlayerData, tiles: Array) -> City:
	var city := City.new()
	city.owner_player = player
	city.owned_tiles.assign(tiles)
	_cities.append(city)
	return city

func _owners(cities: Array) -> Dictionary:
	var owners := {}
	for city in cities:
		for coord in city.owned_tiles:
			owners[coord] = city
	return owners

func _disc(center: Vector2i) -> Array:
	var tiles: Array = [center]
	for dir in HexGrid.NEIGHBOR_DIRS:
		tiles.append(center + dir)
	return tiles

func _world(coord: Vector2i, local: Vector2) -> Vector2:
	var center := HexMetrics.axial_to_world(coord.x, coord.y, 1.0)
	return Vector2(center.x + local.x, center.z + local.y)

func _key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 1000.0), roundi(point.y * 1000.0))

## Toda ponta (de fora e de dentro) dos segmentos `type` aparece exatamente 2 vezes: contorno fechado, sem fresta.
func _assert_closed(segments: Array, type: int, label: String) -> void:
	var outer := {}
	var inner := {}
	var count := 0
	for segment in segments:
		if int(segment.type) != type:
			continue
		count += 1
		for k in 2:
			var o := _key(_world(segment.coord, segment.outer[k]))
			var i := _key(_world(segment.coord, segment.inner[k]))
			outer[o] = int(outer.get(o, 0)) + 1
			inner[i] = int(inner.get(i, 0)) + 1
	assert_gt(count, 0, "%s: há segmentos" % label)
	for point in outer:
		assert_eq(outer[point], 2, "%s: canto de fora %s fecha com exatamente 2 trechos" % [label, point])
	for point in inner:
		assert_eq(inner[point], 2, "%s: canto de dentro %s fecha com exatamente 2 trechos (junção sem fresta)" % [label, point])

func test_each_neighbor_direction_maps_to_the_edge_that_faces_it():
	for d in HexGrid.NEIGHBOR_DIRS.size():
		var offset: Vector2i = HexGrid.NEIGHBOR_DIRS[d]
		var toward := HexMetrics.axial_to_world(offset.x, offset.y, 1.0)
		var corners := TerritoryBorder.edge_corners(d)
		var a := HexMetrics.corner(1.0, corners.x)
		var b := HexMetrics.corner(1.0, corners.y)
		var mid := Vector2(a.x + b.x, a.z + b.z) * 0.5
		assert_almost_eq(mid.normalized().dot(Vector2(toward.x, toward.z).normalized()), 1.0, 0.001, "direção %d" % d)
		assert_almost_eq(mid.length(), TerritoryBorder.SIN_60, 0.001, "ponto médio da aresta no apótema")

func test_a_single_city_outlines_its_perimeter_and_nothing_inside():
	var city := _city(_player(), _disc(Vector2i.ZERO))
	var segments := TerritoryBorder.segments(city, city.owned_tiles, _owners([city]), 1.0)
	assert_eq(segments.size(), 18, "célula + anel: 18 arestas de limite")
	for segment in segments:
		assert_ne(segment.coord, Vector2i.ZERO, "o tile central não tem borda")
		assert_eq(int(segment.type), TerritoryBorder.Edge.FULL)
	_assert_closed(segments, TerritoryBorder.Edge.FULL, "território convexo")

## Território irregular com reentrâncias (cantos côncavos) e um braço: o contorno continua fechando exatamente.
func test_an_irregular_territory_with_concave_corners_still_closes_exactly():
	var tiles := _disc(Vector2i.ZERO)
	tiles.erase(Vector2i(0, 1)) # abre uma reentrância
	tiles.append_array([Vector2i(2, -1), Vector2i(2, 0), Vector2i(3, -1)]) # braço
	var city := _city(_player(), tiles)
	var segments := TerritoryBorder.segments(city, city.owned_tiles, _owners([city]), 1.0)
	_assert_closed(segments, TerritoryBorder.Edge.FULL, "território irregular")

## A faixa é um trapézio de lados paralelos: o lado de dentro fica a exatamente a largura da aresta, então UV.x
## (0 fora, 1 dentro) é a distância normalizada em todo o trapézio — inclusive nos cantos.
func test_every_band_is_parallel_to_its_edge_at_its_width_and_stays_in_its_tile():
	var tiles := _disc(Vector2i.ZERO)
	tiles.erase(Vector2i(0, 1))
	tiles.append(Vector2i(2, -1))
	var city := _city(_player(), tiles)
	for segment in TerritoryBorder.segments(city, city.owned_tiles, _owners([city]), 1.0):
		var a: Vector2 = segment.outer[0]
		var b: Vector2 = segment.outer[1]
		var normal := Vector2(-(b - a).y, (b - a).x).normalized()
		var width := TerritoryBorder.width_of(segment.type)
		for k in 2:
			var inner: Vector2 = segment.inner[k]
			assert_almost_eq(absf((inner - a).dot(normal)), width, 0.0001, "lado de dentro paralelo, à largura da faixa")
			assert_lt(inner.length(), 1.0, "dentro do próprio hexágono")
			assert_lt(inner.length(), (segment.outer[k] as Vector2).length() + 0.0001, "de dentro é mais perto do centro")

func test_two_cities_of_the_same_civ_share_one_outline_with_a_thin_internal_division():
	var player := _player()
	var a := _city(player, _disc(Vector2i.ZERO))
	var b := _city(player, _disc(Vector2i(3, -1)).filter(func(c): return not (c in a.owned_tiles)))
	var owners := _owners([a, b])
	var segments := TerritoryBorder.segments(a, a.owned_tiles, owners, 1.0) + TerritoryBorder.segments(b, b.owned_tiles, owners, 1.0)
	var internal := segments.filter(func(s): return int(s.type) == TerritoryBorder.Edge.INTERNAL)
	assert_gt(internal.size(), 0, "a divisão entre as duas cidades é desenhada")
	for segment in internal:
		var neighbor: Vector2i = segment.coord + HexGrid.NEIGHBOR_DIRS[segment.dir]
		assert_ne(owners[segment.coord], owners[neighbor], "divisão só entre cidades diferentes")
	_assert_closed(segments, TerritoryBorder.Edge.FULL, "contorno da civ (união das duas cidades)")
	for segment in segments.filter(func(s): return int(s.type) == TerritoryBorder.Edge.FULL):
		var neighbor: Vector2i = segment.coord + HexGrid.NEIGHBOR_DIRS[segment.dir]
		assert_false(owners.has(neighbor), "borda cheia só para fora da civ")

func test_two_civs_side_by_side_each_draw_their_own_full_border():
	var a := _city(_player(), _disc(Vector2i.ZERO))
	var b := _city(_player(), _disc(Vector2i(3, -1)).filter(func(c): return not (c in a.owned_tiles)))
	var owners := _owners([a, b])
	var shared := 0
	for segment in TerritoryBorder.segments(a, a.owned_tiles, owners, 1.0):
		var neighbor: Vector2i = segment.coord + HexGrid.NEIGHBOR_DIRS[segment.dir]
		if owners.get(neighbor) == b:
			shared += 1
			assert_eq(int(segment.type), TerritoryBorder.Edge.FULL, "fronteira entre civs: borda cheia")
	assert_gt(shared, 0, "as duas civs se encostam")
	_assert_closed(TerritoryBorder.segments(b, b.owned_tiles, owners, 1.0), TerritoryBorder.Edge.FULL, "civ B fecha sozinha")

## Integração: a malha fica na altura real do próprio tile (+ folga), nunca na do vizinho mais alto.
func test_the_mesh_sits_on_each_tile_own_surface():
	var grid := HexGrid.new()
	add_child_autofree(grid)
	for coord in _disc(Vector2i.ZERO) + _disc(Vector2i(2, -1)):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	grid.tiles[Vector2i(2, -1)] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # degrau mais alto ao lado
	var player := _player()
	var city := grid.found_city(Vector2i.ZERO, player, "Capital", true)
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var mesh := grid._build_city_border_mesh(city)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var grass_height: float = grid.tiles[Vector2i.ZERO].base_height
	for v in vertices:
		assert_almost_eq(v.y, grass_height + HexGrid.BORDER_ABOVE_OFFSET, 0.0001, "colado no próprio tile (campo), não erguido até a colina vizinha")
	assert_eq(grid._territory_border_material.shader.resource_path, HexGrid.TERRITORY_BORDER_SHADER_PATH)
