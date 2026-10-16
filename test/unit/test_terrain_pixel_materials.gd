extends GutTest

## Resource and shader bindings work with the headless renderer too.
## Actual MultiMesh channels require a GPU and are checked separately
## by review_terrain_pixels.gd in the native renderer.
const T := HexTileData.TerrainType
var grid: HexGrid
var coord := Vector2i.ZERO

func before_each() -> void:
	grid = HexGrid.new()
	add_child_autofree(grid)
	grid.tiles[coord] = TerrainDatabase.create_tile(T.GRASSLAND)
	grid._hex_mesh = grid._build_hex_prism_mesh(grid.hex_size, HexGrid.LAND_PRISM_DEPTH_FACTOR)
	var coords: Array[Vector2i] = [coord]
	grid._multimesh_instance = grid._build_terrain_multimesh(coords, grid._coord_to_index)
	grid.add_child(grid._multimesh_instance)

func test_pixel_material_loads_serialized_array_and_rebuild_preserves_bindings() -> void:
	var material := grid._multimesh_instance.material_override as ShaderMaterial
	var array := material.get_shader_parameter("terrain_layers") as Texture2DArray
	assert_not_null(array)
	if array == null: return
	assert_eq(array.get_layers(), 14)
	assert_eq(array.get_width(), 128)
	assert_true(array.has_mipmaps())
	assert_true(material.get_shader_parameter("pixel_terrain_enabled"))
	assert_almost_eq(float(material.get_shader_parameter("pixel_texture_scale")), .5, .00001)
	grid.transform_tile_terrain(coord, T.CRYSTAL_PEAKS)
	var coords: Array[Vector2i] = [coord]
	var rebuilt := grid._build_terrain_multimesh(coords, {})
	var rebuilt_material := rebuilt.material_override as ShaderMaterial
	assert_same(rebuilt_material.get_shader_parameter("terrain_layers"), array)
	assert_true(rebuilt_material.get_shader_parameter("pixel_terrain_enabled"))
	var references: PackedVector3Array = rebuilt_material.get_shader_parameter("surface_reference_colors")
	assert_eq(references.size(), 14)
	var liquid := ShaderMaterial.new()
	liquid.shader = load("res://shaders/water_shader.gdshader")
	TerrainTextureCatalog.apply_liquid(liquid)
	assert_true(liquid.get_shader_parameter("pixel_water_enabled"))
	var water := liquid.get_shader_parameter("pixel_water_tex") as Texture2D
	assert_not_null(water)
	if water != null:
		assert_eq(water.get_width(), array.get_width())
	assert_almost_eq(float(liquid.get_shader_parameter("pixel_water_scale")), float(material.get_shader_parameter("pixel_texture_scale")), .00001)
	assert_almost_eq(float(liquid.get_shader_parameter("pixel_water_mean_luma")), .17769242375132188, .000001)
	rebuilt.free()
	await get_tree().process_frame
