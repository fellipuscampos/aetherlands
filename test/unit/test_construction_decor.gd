extends GutTest

const SITE := Vector2i(1, 0)
const NEIGHBOR := Vector2i(2, 0)
const HALL := "v2_building_guardian_hall"
var grid: HexGrid
var player: PlayerData
var city: City
var _original_focus: bool
var _original_motion: bool

func before_each() -> void:
	_original_focus = VisualFocusSystem.enabled_in_headless
	_original_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	grid = HexGrid.new()
	add_child_autofree(grid)
	grid.map_seed = 5150
	for coord in [Vector2i.ZERO, SITE, NEIGHBOR]:
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)
	var civ := CivilizationData.new()
	civ.race = "human"
	player = PlayerData.new(civ)
	city = grid.found_city(Vector2i.ZERO, player, "Capital")
	grid._rebuild_props()
	assert_true(grid.nature_decor.has_decor(SITE), "Fixture starts with nature props on the building tile")
	assert_true(grid.nature_decor.has_decor(NEIGHBOR), "An adjacent tile also has vegetation")

func after_each() -> void:
	VisualFocusSystem.enabled_in_headless = _original_focus
	Settings.reduced_motion = _original_motion
	grid.visual_focus.reset()
	player.release_relations()

func _start() -> void:
	city.start_building(HALL, SITE, grid)
	grid.refresh_construction_markers()

func test_starting_each_racial_site_removes_existing_props_and_preserves_neighbors() -> void:
	for race in ["human", "elf", "orc", "dwarf"]:
		city.set_production("")
		grid.refresh_construction_markers()
		grid.nature_decor.refresh_tile(SITE)
		assert_true(grid.nature_decor.has_decor(SITE), "Fixture replants the free tile for " + race)
		player.civ.race = race
		var neighbor_sources := grid.nature_decor.sources_at(NEIGHBOR)
		_start()
		assert_true(grid._construction_markers[SITE].has_node("ConstructionSite"), "The real racial model exists: " + race)
		assert_false(grid.nature_decor.has_decor(SITE), "The site replaces existing vegetation: " + race)
		assert_eq(grid.nature_decor.sources_at(NEIGHBOR), neighbor_sources, "Clearing does not rebuild neighboring batches")

func test_restored_construction_clears_props_without_requiring_a_new_production_order() -> void:
	# SaveManager restores pending coordinates, then calls this same refresh after map generation.
	city.production_item = HALL
	city.pending_building_coord = SITE
	grid.refresh_construction_markers()
	assert_false(grid.nature_decor.has_decor(SITE), "Restored sites clear the seed's vegetation too")
	var marker: Node3D = grid._construction_markers[SITE]
	grid.refresh_construction_markers()
	assert_eq(grid._construction_markers[SITE], marker, "Progress updates reuse the existing site")
	grid.nature_decor.refresh_tile(SITE)
	assert_false(grid.nature_decor.has_decor(SITE), "Terrain refresh cannot plant over an active site")
	grid._rebuild_props()
	assert_false(grid.nature_decor.has_decor(SITE), "A full rebuild also respects the active site")

func test_completed_building_stays_clear_after_marker_retirement_and_rebuild() -> void:
	_start()
	grid.place_building(SITE, HALL, player)
	assert_false(grid._construction_markers.has(SITE))
	assert_false(grid.nature_decor.has_decor(SITE))
	grid._rebuild_props()
	assert_false(grid.nature_decor.has_decor(SITE), "Finished building continues to reserve the tile")
	assert_true(grid.nature_decor.has_decor(NEIGHBOR))

func test_destroying_a_focused_resource_releases_cached_props_before_removing_them() -> void:
	grid.get_tile(SITE).resource = "iron"
	grid._rebuild_props()
	VisualFocusSystem.enabled_in_headless = true
	grid.visual_focus.set_focus(SITE, VisualFocusSystem.MODE_TERRAIN)
	grid.visual_focus.refresh()
	assert_gt(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0, "The inspection effect cached the resource")
	city.start_building(HALL, SITE, grid)
	assert_eq(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0, "No cached transform can resurrect the destroyed resource")
	assert_false(grid.visual_focus._pending_restore.has(SITE))
	grid.refresh_construction_markers()
	grid.visual_focus.clear_focus()
	grid.visual_focus.refresh()
	assert_false(grid._resource_props_manager._coord_to_index.get("iron", {}).has(SITE))
	assert_false(grid._resource_icon_manager._sprites.has(SITE))
	assert_eq(grid.get_tile(SITE).resource, "", "The existing resource destruction rule is preserved")
	assert_false(grid.nature_decor.has_decor(SITE))

func test_site_clearing_releases_the_nature_inspection_overlay_too() -> void:
	VisualFocusSystem.enabled_in_headless = true
	grid.visual_focus.set_focus(SITE, VisualFocusSystem.MODE_TERRAIN)
	grid.visual_focus.refresh()
	assert_gt(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0)
	_start()
	assert_eq(int(grid.visual_focus.applied_state(SITE).get("props", 0)), 0)
	grid.visual_focus.clear_focus()
	grid.visual_focus.refresh()
	assert_false(grid.nature_decor.has_decor(SITE), "Leaving inspection cannot restore cleared nature")
	assert_true(grid.nature_decor.has_decor(NEIGHBOR))

func test_resource_removal_also_finishes_an_already_running_restore_fade() -> void:
	grid.get_tile(SITE).resource = "iron"
	grid._rebuild_props()
	VisualFocusSystem.enabled_in_headless = true
	Settings.reduced_motion = false
	grid.visual_focus.set_focus(SITE, VisualFocusSystem.MODE_TERRAIN)
	grid.visual_focus.refresh()
	grid.visual_focus.clear_focus()
	grid.visual_focus.refresh()
	assert_true(grid.visual_focus._pending_restore.has(SITE), "The old inspection overlay is fading out")
	_start()
	assert_false(grid.visual_focus._pending_restore.has(SITE), "The fade cannot restore a removed resource later")
	grid.visual_focus._finish_restore(SITE)
	assert_false(grid._resource_props_manager._coord_to_index.get("iron", {}).has(SITE))
