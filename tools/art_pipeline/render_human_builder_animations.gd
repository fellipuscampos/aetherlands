extends Node3D

var model_path := "res://assets/generated/humans/human_builder_v1/human_builder_v1.glb"
var frames_path := "res://art_source/human_builder_review/animation_frames/"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--race=elf" in OS.get_cmdline_user_args():
		model_path = "res://assets/generated/elves/elf_builder_v1/elf_builder_v1.glb"
		frames_path = "res://art_source/elf_builder_review/animation_frames/"
	elif "--race=orc" in OS.get_cmdline_user_args():
		model_path = "res://assets/generated/orcs/orc_builder_v1/orc_builder_v1.glb"
		frames_path = "res://art_source/orc_builder_review/animation_frames/"
	elif "--race=dwarf" in OS.get_cmdline_user_args():
		model_path = "res://assets/generated/dwarves/dwarf_builder_v1/dwarf_builder_v1.glb"
		frames_path = "res://art_source/dwarf_builder_review/animation_frames/"
	get_tree().root.size = Vector2i(640, 640)
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	floor_node.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.27, 0.20)
	floor_node.material_override = material
	add_child(floor_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.13, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.90, 1.0)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(2.3, 2.3, 5)
	camera.look_at(Vector3(0, 0.93, 0))
	if "--race=dwarf" in OS.get_cmdline_user_args():
		camera.size = 2.0
		camera.position = Vector3(2.3, 1.95, 5)
		camera.look_at(Vector3(0, 0.67, 0))
	camera.current = true
	for i in range(8): await get_tree().process_frame
	for clip in ["idle", "walk", "work"]:
		assert(player.has_animation(clip))
		var directory: String = frames_path + String(clip)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var length := player.get_animation(clip).length
		var count := int(round(length * 24))
		player.play(clip)
		player.pause()
		for frame in range(count):
			player.seek(frame / 24.0, true)
			player.advance(0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			assert(get_tree().root.get_texture().get_image().save_png(directory + "/%03d.png" % frame) == OK)
		print("BUILDER_ANIMATION_CAPTURE " + clip + " " + str(count))
	get_tree().quit()
