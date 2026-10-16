extends GutTest

const SITE := Vector2i(1, 0)
const ART := "res://assets/generated/improvements/arcane_conduit_v2/arcane_conduit_v2.glb"
var grid: HexGrid
var player: PlayerData
var viewer: PlayerData
var city: City
var builder: Unit
var _original := {}
var _old_focus: bool

func before_each() -> void:
	for key in ["hex_grid", "human_player", "players", "rival_players", "state"]:
		_original[key] = GameManager.get(key)
	_old_focus = VisualFocusSystem.enabled_in_headless
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var civ := CivilizationData.new()
	civ.race = "human"
	player = PlayerData.new(civ)
	viewer = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = grid
	GameManager.human_player = player
	GameManager.players = [player, viewer]
	GameManager.rival_players = [viewer]
	GameManager.state = GameManager.GameState.PLAYING
	city = grid.found_city(Vector2i.ZERO, player, "Capital", true)
	grid.get_tile(SITE).resource = "mana_node"
	builder = grid.spawn_unit(SITE, UnitDatabase.create_unit(V2ConstructorRuntime.BUILDER_KIND), player)
	builder.work_charges_remaining = 3
	grid._rebuild_props()
	grid.visibility[SITE] = HexGrid.Visibility.VISIBLE
	grid._apply_prop_fog()

func after_each() -> void:
	grid.visual_focus.reset()
	VisualFocusSystem.enabled_in_headless = _old_focus
	player.release_relations()
	viewer.release_relations()
	for key in _original: GameManager.set(key, _original[key])
	await AudioManager.drain_audio()

func _improve() -> Node3D:
	assert_true(V2ConstructorRuntime.improve_resource(builder, grid))
	return grid.improvement_markers_by_coord[SITE]

func test_asset_has_one_surface_ground_origin_and_a_bounded_tile_footprint() -> void:
	assert_eq(V2ResourceImprovementData.model_scene_path_for_resource("mana_node"), ART)
	var model := (load(ART) as PackedScene).instantiate()
	add_child_autofree(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1)
	var mesh: Mesh = meshes[0].mesh
	assert_eq(mesh.get_surface_count(), 1)
	assert_lte(mesh.get_faces().size() / 3, 1100, "Shared improvement stays within its geometry budget")
	var bounds := mesh.get_aabb()
	assert_almost_eq(bounds.position.y, 0.0, 0.001)
	assert_gte(bounds.size.y, 0.65)
	assert_lte(bounds.size.y, 0.85, "Silhouette stays below the existing resource icon")
	assert_lte(maxf(bounds.size.x, bounds.size.z), 1.45)
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	assert_not_null(material.albedo_texture)
	assert_true(material.emission_enabled)
	assert_not_null(material.emission_texture)
	assert_true(model.find_children("*", "AnimationPlayer", true, false).is_empty())

func test_improvement_replaces_the_raw_prop_but_preserves_resource_icon_and_income() -> void:
	var before := V2EconomyRuntime.city_mana_income(city)
	assert_true(grid._resource_props_manager._coord_to_index["mana_node"].has(SITE))
	var marker := _improve()
	assert_eq(grid.get_tile(SITE).resource, "mana_node")
	assert_true(grid._resource_icon_manager._sprites.has(SITE))
	assert_false(grid._resource_props_manager._coord_to_index["mana_node"].has(SITE))
	assert_eq(marker.find_children("*", "MeshInstance3D", true, false).size(), 1, "Complete installation has no extra procedural badge")
	assert_almost_eq(V2EconomyRuntime.city_mana_income(city) - before, 2.0, 0.001)
	assert_eq(builder.work_charges_remaining, 2)
	assert_eq(grid.world_glow.light_count(), 1, "The installation replaces the resource light, rather than adding a second one")

func test_prop_rebuild_and_marker_refresh_do_not_duplicate_the_node_or_light() -> void:
	var marker := _improve()
	grid._rebuild_props()
	grid.refresh_resource_improvement_marker(SITE)
	assert_eq(grid.improvement_markers_by_coord[SITE], marker)
	assert_false(grid._resource_props_manager._coord_to_index.get("mana_node", {}).has(SITE))
	assert_eq(grid.world_glow.light_count(), 1)
	assert_true(grid._resource_icon_manager._sprites.has(SITE))

func test_inspection_cannot_restore_the_raw_resource_inside_the_complete_model() -> void:
	VisualFocusSystem.enabled_in_headless = true
	grid.visual_focus.set_focus(SITE, VisualFocusSystem.MODE_TERRAIN)
	grid.visual_focus.refresh()
	assert_gt(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0)
	_improve()
	assert_eq(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0)
	grid.visual_focus.clear_focus()
	grid.visual_focus.refresh()
	assert_false(grid._resource_props_manager._coord_to_index["mana_node"].has(SITE))

func test_model_and_light_obey_fog_and_the_map_lighting_setting() -> void:
	var marker := _improve()
	grid.world_glow.set_darkness(1.0)
	var light := grid.world_glow.get_light(HexGrid.IMPROVEMENT_GLOW_GROUP, SITE)
	for visibility in [HexGrid.Visibility.UNSEEN, HexGrid.Visibility.EXPLORED, HexGrid.Visibility.VISIBLE]:
		grid.visibility[SITE] = visibility
		grid._apply_fog_to_entities(viewer)
		assert_eq(marker.visible, visibility == HexGrid.Visibility.VISIBLE)
		assert_eq(light.visible, visibility == HexGrid.Visibility.VISIBLE)
	grid.world_glow.set_layer_enabled(WorldGlow.LAYER_MAP, false)
	assert_false(light.visible)
	grid.world_glow.set_layer_enabled(WorldGlow.LAYER_MAP, true)
	assert_true(light.visible)

func test_native_model_sits_on_hills_at_its_authored_scale() -> void:
	grid.tiles[SITE] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	grid.get_tile(SITE).resource = "mana_node"
	grid.hex_size = 1.5
	var marker := _improve()
	assert_almost_eq(marker.position.y, grid._tile_surface_height(SITE), 0.001)
	assert_eq(marker.get_child(0).scale, Vector3.ONE * 1.5)

func test_destroying_the_resource_removes_the_installation_light_and_bonus() -> void:
	_improve()
	assert_eq(grid.destroy_resource_at(SITE), "mana_node")
	assert_false(grid.improvement_markers_by_coord.has(SITE))
	assert_false(grid.world_glow.has_light(HexGrid.IMPROVEMENT_GLOW_GROUP, SITE))
	assert_false(city.resource_improvements.has(SITE))
	assert_almost_eq(V2EconomyRuntime.city_mana_income(city), V2InfrastructureEconomyData.BASE_MANA_PER_CITY, 0.001)

func test_restoring_a_saved_improvement_replaces_the_seed_prop_again() -> void:
	var previous := _improve()
	grid.visual_focus.reset()
	grid.improvement_markers_by_coord.erase(SITE)
	grid.world_glow.remove_light(HexGrid.IMPROVEMENT_GLOW_GROUP, SITE)
	previous.queue_free()
	# Map generation has raw props; SaveManager restores the city's saved
	# improvement dictionary, then invokes this same marker creation method.
	grid._rebuild_props()
	assert_true(grid._resource_props_manager._coord_to_index["mana_node"].has(SITE))
	grid.refresh_resource_improvement_marker(SITE)
	assert_ne(grid.improvement_markers_by_coord[SITE], previous)
	assert_false(grid._resource_props_manager._coord_to_index["mana_node"].has(SITE))
	assert_eq(grid.world_glow.light_count(), 1)
	assert_almost_eq(V2EconomyRuntime.city_mana_income(city), 3.0, 0.001)

func test_new_map_cleanup_releases_the_improvement_lighting_group() -> void:
	_improve()
	grid._clear_entities()
	assert_false(grid.improvement_markers_by_coord.has(SITE))
	assert_eq(grid.world_glow.light_count(HexGrid.IMPROVEMENT_GLOW_GROUP), 0)
