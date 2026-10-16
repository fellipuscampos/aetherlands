extends SceneTree

const OUTPUT := "res://docs/previews/orc_face_uv/"

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1800, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("28353b")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 0.8
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.4
	camera.position = Vector3(0, 2.05, 12)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.78, 0))
	camera.current = true
	var args := OS.get_cmdline_user_args()
	var version := args[0] if not args.is_empty() else "after"
	var groups := [
		["orc_squire_v1", "orc_warrior_v1", "orc_archer_v1", "orc_rogue_v1"],
		["orc_guardian_v1", "orc_sentinel_v1", "orc_weapon_master_v1", "orc_legend_hunter_v1"]
	]
	for group_index in groups.size():
		var models := Node3D.new()
		stage.add_child(models)
		for index in groups[group_index].size():
			var stem: String = groups[group_index][index]
			var model := (load("res://assets/generated/orcs/%s/%s.glb" % [stem, stem]) as PackedScene).instantiate() as Node3D
			model.position.x = (index - 1.5) * 0.77
			models.add_child(model)
		for frame in 16: await process_frame
		await RenderingServer.frame_post_draw
		var path := OUTPUT + "%s_%d.png" % [version, group_index]
		var error := root.get_texture().get_image().save_png(path)
		assert(error == OK)
		print("ORC_FACE_CAPTURE: ", path)
		models.free()
	stage.free()
	await process_frame
	quit()
