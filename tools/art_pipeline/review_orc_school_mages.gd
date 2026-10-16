extends Node

## One native rendering session, using the game lighting and pixel terrain.
const WORK := "res://art_source/orc_school_mages_review/"
var failures: Array[String] = []
var camera: Camera3D
var rows: Array = []

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	call_deferred("_run")

func capture(filename: String, target: Vector3, offset: Vector3, size: float) -> void:
	camera.position=target+offset; camera.look_at(target); camera.size=size
	for frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	require(image != null and image.get_size()==Vector2i(1600,900),"Native screenshot dimensions")
	if image: image.save_png(WORK+filename)

func _run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK+"manifest.json"))
	var world := Node3D.new(); get_tree().root.add_child(world)
	var models: Array[Node3D] = []
	for index in range(manifest.assets.size()):
		var row: Dictionary=manifest.assets[index]
		var stem: String=row.stem
		var path: String="res://assets/generated/orcs/"+stem+"/"+stem+".glb"
		var packed := load(path) as PackedScene
		require(packed != null,path+" failed to import")
		if packed == null: continue
		var model := packed.instantiate() as Node3D; world.add_child(model)
		var meshes := model.find_children("*","MeshInstance3D",true,false)
		require(meshes.size()==1,path+" single mesh")
		require(model.find_children("*","Skeleton3D",true,false).is_empty(),path+" static model has a rig")
		require(model.find_children("*","AnimationPlayer",true,false).is_empty(),path+" unexpected animation")
		require(model.scale.is_equal_approx(Vector3.ONE),path+" root scale")
		if meshes.size()!=1: model.free(); continue
		var mesh := meshes[0] as MeshInstance3D
		require(mesh.mesh.get_surface_count()==1,path+" surface count")
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		require(material != null,path+" material type")
		if material:
			require(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,path+" pixel filtering")
			require(material.albedo_texture!=null and material.albedo_texture.get_width()==512,path+" albedo atlas")
			require(material.emission_enabled and material.emission_texture!=null,path+" focus emission atlas")
			require(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK,path+" opaque backface culling")
		var bounds := mesh.mesh.get_aabb()
		require(absf(bounds.position.y)<.00001,path+" feet pivot")
		require(absf(bounds.size.y-float(row.geometry.dimensions[2]))<.0001,path+" native-meter height")
		var arrays := mesh.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		require(indices.size()/3==int(row.geometry.triangles),path+" triangle count")
		model.position=Vector3((index-2.5)*2.1,0,0); models.append(model)
		rows.append({"school":row.school,"meshes":1,"surfaces":1,"triangles":indices.size()/3,"height_m":bounds.size.y,"ground_pivot":true,"nearest_with_mipmaps":true})
	if "--validate-only" not in OS.get_cmdline_user_args() and failures.is_empty():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600,900)); get_tree().root.size=Vector2i(1600,900); get_tree().root.msaa_3d=Viewport.MSAA_2X
		var main: Node=load("res://scenes/main/Main.tscn").instantiate()
		var environment := WorldEnvironment.new()
		environment.environment=(main.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate(); world.add_child(environment)
		world.add_child(main.get_node("Sun").duplicate()); main.free()
		var grid := HexGrid.new(); grid.map_width=17; grid.map_height=9; world.add_child(grid)
		for z in range(-4,5):
			for x in range(-8,9):
				var coord := Vector2i(x-(z-(z&1))/2,z)
				grid.tiles[coord]=TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
				grid.visibility[coord]=HexGrid.Visibility.VISIBLE
		grid._rebuild_multimesh()
		for child in grid.get_children():
			if child is MultiMeshInstance3D and child!=grid._multimesh_instance: child.visible=false
		var level: float=grid.world_surface_for_coord(Vector2i.ZERO).y
		for model in models: model.position.y=level
		var base: Node3D=load("res://assets/generated/orcs/orc_settler_v1/orc_settler_v1.glb").instantiate()
		world.add_child(base); base.position=Vector3(-7.45,level,0)
		camera=Camera3D.new(); world.add_child(camera); camera.current=true; camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		await capture("godot_orc_mages_front.png",Vector3(-.8,level+1.1,0),Vector3(0,4.6,18),9.5)
		await capture("godot_orc_mages_three_quarter.png",Vector3(-.8,level+1.1,0),Vector3(3.8,6,18),9.5)
		for model in models: model.visible=model==models[4]
		base.visible=false
		await capture("godot_arcanist_side.png",models[4].position+Vector3(0,1.16,0),Vector3(5,1.2,1.2),3.05)
		for model in models: model.visible=model==models[0]
		base.visible=true
		await capture("godot_orc_style_comparison.png",Vector3(-6.35,level+1.15,0),Vector3(2,2.4,10),3.8)
		# Compare the approved orc face with the hooded and hatted variants.
		for index in range(models.size()): models[index].visible=index==1 or index==4
		models[1].position.x=0
		models[4].position.x=1.25
		base.position.x=-1.25
		await capture("godot_original_heads_comparison.png",Vector3(0,level+1.80,0),Vector3(0,.35,8),1.95)
	var output := {"status":"PASS" if failures.is_empty() else "FAIL","verified":rows.size(),"renderer":RenderingServer.get_current_rendering_method(),"stage":"static_model_review","game_database_changed":false,"native_screenshots":0 if "--validate-only" in OS.get_cmdline_user_args() else 5,"assets":rows,"failures":failures}
	var filename: String="res://docs/orc_school_mages_godot_import_validation.json" if "--validate-only" in OS.get_cmdline_user_args() else "res://docs/orc_school_mages_godot_validation.json"
	var file := FileAccess.open(filename,FileAccess.WRITE); file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify(output)); get_tree().quit(0 if failures.is_empty() else 1)
