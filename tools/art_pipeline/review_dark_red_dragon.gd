extends SceneTree

const MODEL_PATH := "res://assets/generated/dragons/dark_red_dragon_v4/dark_red_dragon_v4.glb"
const OUTPUT := "res://assets/generated/dragons/dark_red_dragon_v4/"

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	root.size = Vector2i(1100,1100)
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Dragon GLB failed to import")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var model := packed.instantiate() as Node3D
	stage.add_child(model)
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	var issues: Array[String] = []
	if skeletons.size()!=1 or skeletons[0].get_bone_count()!=52:
		issues.append("Expected one skeleton with 52 prepared bones")
	if meshes.size()!=1: issues.append("Expected one runtime mesh")
	var bounds := AABB()
	var first := true
	var triangle_count := 0
	for part: MeshInstance3D in meshes:
		if part.skin==null: issues.append("Missing skin")
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangle_count += indices.size()/3
			for v in vertices:
				if not v.is_finite(): issues.append("Non-finite vertex")
			var material := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if material==null or material.albedo_texture==null or material.emission_texture==null:
				issues.append("Missing pixel atlas or emission atlas")
			else:
				if material.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_NEAREST:
					issues.append("Pixel texture filtering was not imported correctly")
				if material.albedo_texture.get_width()!=1024: issues.append("Incorrect atlas size")
		var box := part.global_transform * part.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	if absf(bounds.size.y-3.0)>.01: issues.append("Incorrect native height")
	if absf(bounds.position.y-.25)>.01: issues.append("Incorrect flight clearance")
	var report := {"status":"PASS" if issues.is_empty() else "FAIL", "issues":issues,
		"model":MODEL_PATH,"meshes":meshes.size(),"bones":skeletons[0].get_bone_count(),
		"triangles":triangle_count,"height_m":bounds.size.y,"flight_clearance_m":bounds.position.y,
		"gameplay_changed":false}
	FileAccess.open(OUTPUT+"godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DARK_RED_DRAGON "+JSON.stringify(report))
	if not issues.is_empty():
		quit(1)
		return
	if "--validate-only" in OS.get_cmdline_user_args():
		quit()
		return
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.42,.37,.33)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.95,.90,.87)
	environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment=environment
	stage.add_child(world)
	for entry in [[Vector3(-48,-28,0),1.0],[Vector3(-38,145,0),.65]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees=entry[0]
		light.light_energy=entry[1]
		stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.5
	camera.current=true
	stage.add_child(camera)
	var views := {"godot_three_quarter":Vector3(6,5.8,10),"godot_game_top":Vector3(5,9,8)}
	for label in views:
		camera.position=views[label]
		camera.look_at(Vector3(.18,1.73,-.04))
		await process_frame
		await RenderingServer.frame_post_draw
		var err := root.get_texture().get_image().save_png(OUTPUT+"previews/"+label+".png")
		if err!=OK:
			push_error("Unable to save dragon preview")
			quit(1)
			return
	quit()
