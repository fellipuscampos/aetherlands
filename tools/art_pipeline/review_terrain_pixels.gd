extends Node

## One native Godot session: compile the texture array, validate real
## bindings, then capture the terrain with the game's light and models.
var failures: Array[String] = []
var grid: HexGrid
var world: Node3D
var camera: Camera3D
const WORK := "res://art_source/terrain_pixel_review/"

func _ready() -> void:
	call_deferred("_run")

func require(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func center_coord(index: int) -> Vector2i:
	var col: int = -7 + (index % 5) * 3 + 1
	var row: int = -7 + (index / 5) * 3 + 1
	return Vector2i(col - (row - (row & 1)) / 2, row)

func view(target: Vector3, offset: Vector3) -> void:
	camera.position=target+offset; camera.look_at(target)

func capture(filename: String) -> void:
	for frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	require(image!=null and image.get_size()==Vector2i(1600,1000),"Invalid native viewport screenshot")
	if image!=null: image.save_png(WORK+filename)

func _run() -> void:
	if "--parse-runtime-only" in OS.get_cmdline_user_args():
		print("TERRAIN_REVIEW_RUNTIME_PARSE_PASS"); get_tree().quit(0); return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	get_tree().root.size=Vector2i(1600,1000); get_tree().root.msaa_3d=Viewport.MSAA_2X
	var build: Dictionary = load("res://tools/art_pipeline/build_terrain_pixel_array.gd").build()
	if build.status!="PASS": get_tree().quit(1); return
	world=Node3D.new(); get_tree().root.add_child(world)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	var environment := WorldEnvironment.new()
	environment.environment=(main.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate()
	world.add_child(environment)
	world.add_child(main.get_node("Sun").duplicate())
	main.free()
	camera=Camera3D.new(); world.add_child(camera); camera.current=true; camera.fov=50
	grid=HexGrid.new(); grid.map_width=15; grid.map_height=15; world.add_child(grid)
	var types: Array = HexTileData.TerrainType.values()
	require(types.size()==25,"Terrain inventory changed")
	for row in range(-7,8):
		for col in range(-7,8):
			var coord := Vector2i(col - (row - (row & 1)) / 2,row)
			var index: int = ((col+7)/3) + ((row+7)/3)*5
			grid.tiles[coord]=TerrainDatabase.create_tile(types[index])
			grid.visibility[coord]=HexGrid.Visibility.VISIBLE
	grid._rebuild_multimesh()
	var mm := grid._multimesh_instance.multimesh
	var material := grid._multimesh_instance.material_override as ShaderMaterial
	var array := material.get_shader_parameter("terrain_layers") as Texture2DArray
	require(array!=null and array.get_layers()==14,"Ground texture array missing")
	require(material.get_shader_parameter("pixel_terrain_enabled")==true,"Pixel ground disabled")
	var covered: Dictionary = {}
	for coord: Vector2i in grid._coord_to_index:
		var index: int=grid._coord_to_index[coord]
		var data: HexTileData=grid.tiles[coord]
		var custom := mm.get_instance_custom_data(index)
		require(int(round(custom.b))==TerrainTextureCatalog.surface_for(data.terrain_type),"Wrong surface at "+str(coord))
		require(absf(custom.a-grid._material_kind_for(data.terrain_type))<.001,"Special effects changed")
		require(absf(mm.get_instance_transform(index).origin.y-data.base_height)<.0001,"Terrain height changed")
		covered[data.terrain_type]=true
	require(covered.size()==21,"Not all land surfaces exercised")
	# Exercise a real magic/terraform update; this previously updated only
	# effect and elevation channels, which would leave the old texture.
	var coord := center_coord(HexTileData.TerrainType.GRASSLAND)
	grid.transform_tile_terrain(coord,HexTileData.TerrainType.DESERT)
	var changed := mm.get_instance_custom_data(grid._coord_to_index[coord])
	require(int(round(changed.b))==7,"Terraform did not switch grass to sand")
	grid.transform_tile_terrain(coord,HexTileData.TerrainType.GRASSLAND)
	await get_tree().process_frame
	grid._rebuild_biome_overlay()
	var refs := TerrainTextureCatalog.reference_colors()
	require(refs.size()==14,"Missing surface color references")
	var liquid := grid._liquid_plane_instance.material_override as ShaderMaterial
	require(liquid.get_shader_parameter("pixel_water_enabled")==true,"Pixel water disabled")
	var water := liquid.get_shader_parameter("pixel_water_tex") as Texture2D
	require(water!=null and water.get_width()==128,"Pixel water texture missing")
	for child in grid.get_children():
		if child is MultiMeshInstance3D and child!=grid._multimesh_instance: child.visible=false
	view(Vector3(0,0,0),Vector3(0,25,25))
	# Capture the same geometry with the original photographed materials.
	var legacy := material.duplicate() as ShaderMaterial
	var old_shader := Shader.new()
	old_shader.code=FileAccess.get_file_as_string("res://art_source/terrain_before_pixel_v1/shaders/terrain.gdshader")
	legacy.shader=old_shader
	for pair in [["albedo_tex","ground"],["snow_tex","snow"],["desert_tex","desert"],["lava_tex","lava"],["crystal_tex","crystal"]]:
		legacy.set_shader_parameter(pair[0],load("res://assets/textures/terrain/"+pair[1]+"_albedo.jpg"))
	grid._multimesh_instance.material_override=legacy
	await capture("terrain_before.png")
	grid._multimesh_instance.material_override=material
	await capture("terrain_pixel_biomes.png")
	for child in grid.get_children():
		if child is MultiMeshInstance3D: child.visible=true
	await capture("terrain_pixel_with_nature.png")
	# Reference characters share the game's terrain and shadow lighting.
	var target := grid.world_surface_for_coord(coord)
	var references := Node3D.new(); world.add_child(references)
	var races := ["human","elf","dwarf","orc"]
	var folders := ["humans","elves","dwarves","orcs"]
	for index in range(4):
		var path: String="res://assets/generated/"+folders[index]+"/"+races[index]+"_settler_v1/"+races[index]+"_settler_v1.glb"
		var character: Node3D=(load(path) as PackedScene).instantiate()
		references.add_child(character); character.scale=Vector3.ONE*.32
		character.position=target+Vector3((index-1.5)*.55,0,.15)
		var players := character.find_children("*","AnimationPlayer",true,false)
		if not players.is_empty(): (players[0] as AnimationPlayer).play("idle")
	view(target+Vector3(0,.22,0),Vector3(2.2,3.6,4.4))
	await capture("terrain_pixel_characters.png")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"inventory_types":types.size(),"land_types_exercised":covered.size(),"terrain_instances":mm.instance_count,"array_layers":14,"source_pixels_preserved":build.source_pixels_preserved,"pixel_density":64,"terraform_texture_update":true,"geometry_and_effects_preserved":true,"native_screenshots":4,"failures":failures}
	var file := FileAccess.open("res://docs/terrain_pixel_godot_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
