extends SceneTree

## Offline portraits from the game's own buildings, with a transparent pixel background.
const OUTPUT := "res://assets/ui/game_setup/"
var stage: Node3D

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(384, 256)
	root.transparent_bg = true
	root.msaa_3d = Viewport.MSAA_DISABLED
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d5da")
	env.ambient_light_energy = .75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Color("ffdbac")
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.95
	camera.position = Vector3(2.8, 2.1, 4.3)
	camera.look_at(Vector3(0, .40, 0))
	camera.current = true
	for race in ["human", "elf", "dwarf", "orc"]:
		var folder: String = {"human":"humans", "elf":"elves", "dwarf":"dwarves", "orc":"orcs"}[race]
		var city_stem: String = "city_level_1_hex_v1" if race == "human" else race + "_city_level_1_hex_v1"
		var wall_stem: String = race + "_walls_level_2_hex_v1"
		var models: Array[Node] = []
		for stem in [city_stem, wall_stem]:
			var path := "res://assets/generated/%s/buildings/%s/%s.glb" % [folder, stem, stem]
			var model := (load(path) as PackedScene).instantiate()
			stage.add_child(model)
			models.append(model)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUTPUT + "city_" + race + ".png") == OK)
		for model in models:
			model.queue_free()
		await process_frame
	print("SETUP_CITY_PORTRAITS_SAVED: ", OUTPUT)
	quit()
