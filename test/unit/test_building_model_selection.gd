extends GutTest

const EXPECTED := {
	"v2_building_rogue_guild": "res://assets/generated/humans/buildings/rogue_guild_hex_v1/rogue_guild_hex_v1.glb",
	"v2_building_siege_arsenal": "res://assets/generated/humans/buildings/siege_arsenal_hex_v1/siege_arsenal_hex_v1.glb",
}
var _original_models: Dictionary = {}

func after_each() -> void:
	for id in _original_models:
		var data := BuildingDatabase.get_building(id)
		data.model_scene_path = _original_models[id][0]
		data.model_scale_multiplier = _original_models[id][1]
	_original_models.clear()

func _restore_old_cached_model(id: String) -> BuildingData:
	var data := BuildingDatabase.get_building(id)
	if not _original_models.has(id):
		_original_models[id] = [data.model_scene_path,data.model_scale_multiplier]
	# Simulates a resource retained while an editor reload changes the model definition.
	data.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	data.model_scale_multiplier = .5
	return data

func test_catalogue_refreshes_old_cached_art_without_replacing_gameplay_data() -> void:
	for id in EXPECTED:
		var data := _restore_old_cached_model(id)
		var gameplay := [data.production_cost,data.trains_unit,data.gold_upkeep,data.requires_building]
		var refreshed := BuildingDatabase.get_building(id)
		assert_same(refreshed,data,"Keep the same cached gameplay resource")
		assert_eq(refreshed.model_scene_path,EXPECTED[id],"The current model replaces the old cached reference")
		assert_eq(refreshed.model_scale_multiplier,1.0,"Generated art keeps its native tile scale")
		assert_eq([refreshed.production_cost,refreshed.trains_unit,refreshed.gold_upkeep,refreshed.requires_building],gameplay)
		_restore_old_cached_model(id)
		var listed: BuildingData = BuildingDatabase.all_buildings().filter(func(b): return b.id == id)[0]
		assert_eq(listed.model_scene_path,EXPECTED[id],"Production menu also sees the current model")

func test_map_placement_and_replacement_use_the_generated_scenes_from_a_stale_cache() -> void:
	var grid := HexGrid.new()
	add_child_autofree(grid)
	for q in range(2):
		var coord := Vector2i(q,0)
		var tile := HexTileData.new()
		tile.base_height = .02
		grid.tiles[coord] = tile
	var q := 0
	for id in EXPECTED:
		_restore_old_cached_model(id)
		var coord := Vector2i(q,0)
		var building := grid.place_building(coord,id,null)
		var model := building.get_child(0) as Node3D
		assert_eq(model.scene_file_path,EXPECTED[id],"Actual map placement uses the generated scene")
		assert_eq(model.scale,Vector3.ONE)
		assert_eq(model.find_children("*","MeshInstance3D",true,false).size(),8)
		assert_eq(building.position,grid.world_for_coord(coord))
		_restore_old_cached_model(id)
		var replacement := grid.place_building(coord,id,null,false)
		await get_tree().process_frame
		assert_same(grid.get_building_at(coord),replacement)
		assert_eq(replacement.get_child(0).scene_file_path,EXPECTED[id],"Recreation used by loading/capture also selects the current source")
		q += 1
