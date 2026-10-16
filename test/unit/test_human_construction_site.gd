extends GutTest

var players: Array[PlayerData] = []

func after_each() -> void:
	for player in players:
		player.release_relations()
	players.clear()

func _pending(race: String, tile_size: float = 1.0) -> HexGrid:
	var grid := HexGrid.new()
	grid.hex_size = tile_size
	add_child_autofree(grid)
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	players.append(player)
	var city := grid.found_city(Vector2i.ZERO, player, "Obra")
	city.pending_building_coord = Vector2i(1, 0)
	grid.refresh_construction_markers()
	return grid

func test_human_site_loops_and_stays_on_the_building_tile() -> void:
	var grid := _pending("human")
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node_or_null("ConstructionSite") as Node3D
	assert_not_null(site)
	assert_null(marker.get_node_or_null("Crane"))
	var player := site.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	assert_true(player.is_playing())
	assert_eq(player.current_animation, "construction")
	assert_eq(player.get_animation("construction").loop_mode, Animation.LOOP_LINEAR)
	var before := marker.transform
	grid._process(0.25)
	assert_eq(marker.transform, before, "Workers and ground must not float or rotate")
	assert_eq(marker.position, grid.world_for_coord(Vector2i(1, 0)))
	assert_gt((marker.get_node("ProgressBar") as Sprite3D).position.y, 0.75)

func test_site_rests_on_terrain_and_fits_the_tile_at_map_scale() -> void:
	var grid := _pending("human", 1.7)
	_assert_site_on_terrain_and_inside_tile(grid)

func _assert_site_on_terrain_and_inside_tile(grid: HexGrid) -> void:
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node("ConstructionSite") as Node3D
	var props := site.find_child("Construction_Props*", true, false) as MeshInstance3D
	assert_not_null(props)
	var vertices: PackedVector3Array = props.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest := INF
	var tile_origin := grid.world_for_coord(Vector2i(1, 0))
	for vertex in vertices:
		lowest = minf(lowest, (props.global_transform * vertex - tile_origin).y)
	assert_almost_eq(lowest, 0.0, 0.0002, "Supports sit on terrain without the old ground plate")
	for i in range(6):
		var normal := (HexMetrics.corner(1.0, i) + HexMetrics.corner(1.0, (i + 1) % 6)).normalized()
		var maximum := -INF
		for vertex in vertices:
			maximum = maxf(maximum, normal.dot(props.global_transform * vertex - tile_origin))
		assert_lt(maximum, grid.hex_size * (0.9 * sqrt(3.0) / 2.0 - 0.035), "Props stay inside map edge %d" % i)

func test_other_races_retain_their_marker_until_their_art_is_created() -> void:
	for race in [""]:
		var grid := _pending(race)
		var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
		assert_not_null(marker.get_node_or_null("Crane"), race)
		assert_null(marker.get_node_or_null("ConstructionSite"), race)
		grid._process(0.25)

func test_elf_site_uses_its_own_art_loops_and_is_removed_on_completion() -> void:
	var grid := _pending("elf", 1.7)
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node("ConstructionSite") as Node3D
	assert_eq(site.get_meta("race"), "elf")
	assert_true(site.scene_file_path.contains("elves/buildings/elf_construction_site"))
	assert_null(marker.get_node_or_null("Crane"))
	var player := site.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	assert_true(player.is_playing())
	assert_eq(player.current_animation, "construction")
	assert_eq(player.get_animation("construction").loop_mode, Animation.LOOP_LINEAR)
	_assert_site_on_terrain_and_inside_tile(grid)
	var before := marker.transform
	grid._process(0.25)
	assert_eq(marker.transform, before)
	assert_eq(marker.position, grid.world_for_coord(Vector2i(1, 0)))
	var city: City = grid.cities_by_coord[Vector2i.ZERO]
	city.pending_building_coord = City.NO_PENDING_COORD
	grid.place_building(Vector2i(1, 0), "v2_building_market", city.owner_player) # obra concluída: o prédio nasce
	assert_false(site.visible)
	assert_true(site.is_queued_for_deletion())
	assert_false(grid._construction_markers.has(Vector2i(1, 0)), "o canteiro sai do tile no instante em que o prédio nasce")

func test_human_site_is_removed_after_completion_or_cancellation() -> void:
	var grid := _pending("human")
	var city: City = grid.cities_by_coord[Vector2i.ZERO]
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node("ConstructionSite") as Node3D
	# Conclusão: o prédio nasce (place_building) e o canteiro sai do tile no mesmo instante — nunca os dois juntos.
	city.pending_building_coord = City.NO_PENDING_COORD
	grid.place_building(Vector2i(1, 0), "v2_building_market", city.owner_player)
	assert_false(grid._construction_markers.has(Vector2i(1, 0)), "The site leaves the tile the moment the building exists")
	assert_false(site.visible, "Do not overlap the completed building with a construction site")
	assert_true(site.is_queued_for_deletion())
	grid.refresh_construction_markers()
	assert_false(grid._construction_markers.has(Vector2i(1, 0)), "A tile with a building never gets a site again")
	# Cancelamento (em outro tile): some na hora, sem aceno de conclusão.
	grid.tiles[Vector2i(0, 1)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	city.pending_building_coord = Vector2i(0, 1)
	grid.refresh_construction_markers()
	assert_true(grid._construction_markers.has(Vector2i(0, 1)))
	city.pending_building_coord = City.NO_PENDING_COORD
	grid.refresh_construction_markers()
	assert_false(grid._construction_markers.has(Vector2i(0, 1)), "Cancelled construction is removed immediately")

func test_orc_site_uses_its_own_art_loops_and_is_removed_on_completion() -> void:
	var grid := _pending("orc", 1.7)
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node("ConstructionSite") as Node3D
	assert_eq(site.get_meta("race"), "orc")
	assert_true(site.scene_file_path.contains("orcs/buildings/orc_construction_site"))
	assert_null(marker.get_node_or_null("Crane"))
	var player := site.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	assert_true(player.is_playing())
	assert_eq(player.current_animation, "construction")
	assert_eq(player.get_animation("construction").loop_mode, Animation.LOOP_LINEAR)
	_assert_site_on_terrain_and_inside_tile(grid)
	var before := marker.transform
	grid._process(0.25)
	assert_eq(marker.transform, before)
	assert_eq(marker.position, grid.world_for_coord(Vector2i(1, 0)))
	var city: City = grid.cities_by_coord[Vector2i.ZERO]
	city.pending_building_coord = City.NO_PENDING_COORD
	grid.place_building(Vector2i(1, 0), "v2_building_market", city.owner_player) # obra concluída: o prédio nasce
	assert_false(site.visible)
	assert_true(site.is_queued_for_deletion())
	assert_false(grid._construction_markers.has(Vector2i(1, 0)), "o canteiro sai do tile no instante em que o prédio nasce")

func test_dwarf_site_uses_its_own_art_loops_and_is_removed_on_completion() -> void:
	var grid := _pending("dwarf", 1.7)
	var marker: Node3D = grid._construction_markers[Vector2i(1, 0)]
	var site := marker.get_node("ConstructionSite") as Node3D
	assert_eq(site.get_meta("race"), "dwarf")
	assert_true(site.scene_file_path.contains("dwarves/buildings/dwarf_construction_site"))
	assert_null(marker.get_node_or_null("Crane"))
	var player := site.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	assert_true(player.is_playing())
	assert_eq(player.current_animation, "construction")
	assert_eq(player.get_animation("construction").loop_mode, Animation.LOOP_LINEAR)
	_assert_site_on_terrain_and_inside_tile(grid)
	var before := marker.transform
	grid._process(0.25)
	assert_eq(marker.transform, before)
	assert_eq(marker.position, grid.world_for_coord(Vector2i(1, 0)))
	var city: City = grid.cities_by_coord[Vector2i.ZERO]
	city.pending_building_coord = City.NO_PENDING_COORD
	grid.place_building(Vector2i(1, 0), "v2_building_market", city.owner_player) # obra concluída: o prédio nasce
	assert_false(site.visible)
	assert_true(site.is_queued_for_deletion())
	assert_false(grid._construction_markers.has(Vector2i(1, 0)), "o canteiro sai do tile no instante em que o prédio nasce")
