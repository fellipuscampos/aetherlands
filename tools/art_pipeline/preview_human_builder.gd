extends Node3D

var review_race := "human"
var out_path := "res://assets/generated/humans/human_builder_v1/"
var model_path := out_path + "human_builder_v1.glb"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--race=elf" in OS.get_cmdline_user_args():
		review_race = "elf"
		out_path = "res://assets/generated/elves/elf_builder_v1/"
		model_path = out_path + "elf_builder_v1.glb"
	elif "--race=orc" in OS.get_cmdline_user_args():
		review_race = "orc"
		out_path = "res://assets/generated/orcs/orc_builder_v1/"
		model_path = out_path + "orc_builder_v1.glb"
	elif "--race=dwarf" in OS.get_cmdline_user_args():
		review_race = "dwarf"
		out_path = "res://assets/generated/dwarves/dwarf_builder_v1/"
		model_path = out_path + "dwarf_builder_v1.glb"
	get_tree().root.size = Vector2i(1200, 850)
	var base := UnitDatabase.create_unit("v2_unit_builder")
	var civilization := CivilizationData.new()
	civilization.race = review_race
	var owner := PlayerData.new(civilization)
	var themed := UnitArtCatalog.for_owner(base, owner)
	assert(themed.model_scene_path == model_path)
	assert(themed.production_cost == base.production_cost and themed.attack == 0.0)
	assert(not themed.can_found_city and not themed.merge_shared_walk_animation)
	for race in ["human", "elf", "orc", "dwarf"]:
		var other_civ := CivilizationData.new()
		other_civ.race = race
		var other_owner := PlayerData.new(other_civ)
		var other_art := UnitArtCatalog.for_owner(base, other_owner)
		assert(other_art.model_scene_path == UnitArtCatalog.model_path("v2_unit_builder", race))
		assert(other_art.production_cost == base.production_cost and other_art.work_animation_override == "work")
		other_owner.release_relations()
	var builder := Unit.new()
	add_child(builder)
	builder.setup(base, owner, Vector2i.ZERO)
	builder.position = Vector3(0.9, 0, 0)
	assert(builder.unit_data.model_scene_path == model_path)
	assert(builder._anim_player != null)
	assert(builder.idle_animation == "idle" and builder.moving_animation == "walk")
	assert(builder._anim_player.has_animation("idle") and builder._anim_player.has_animation("walk"))
	assert(builder._anim_player.has_animation("work") and builder.unit_data.work_animation_override == "work")
	builder.play_work_visual()
	assert(builder._anim_player.current_animation == "work")
	builder._anim_player.advance(3.1)
	await get_tree().process_frame
	assert(builder._anim_player.current_animation == "idle")
	var children_before := get_child_count()
	builder.play_work_visual(true)
	assert(get_child_count() == children_before + 1)
	var ghost := get_child(get_child_count() - 1) as Node3D
	var ghost_player := ghost.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert(ghost_player.current_animation == "work")
	ghost_player.advance(3.1)
	await get_tree().process_frame
	assert(not is_instance_valid(ghost))
	builder._anim_player.play("walk")
	builder._anim_player.advance(0.4)
	builder._anim_player.play("idle")
	builder._anim_player.advance(0.2)
	var settler := Unit.new()
	add_child(settler)
	settler.setup(UnitDatabase.create_unit("settler"), owner, Vector2i.ZERO)
	settler.position = Vector3(-0.9, 0, 0)
	for unit in [builder, settler]:
		var label := Label3D.new()
		label.text = {"human": "Construtor humano", "elf": "Construtor elfo", "orc": "Construtor orc", "dwarf": "Construtor anão"}[review_race] if unit == builder else "Colono (base)"
		label.position.y = 2.05
		label.font_size = 36
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		unit.add_child(label)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(7, 6)
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.28, 0.39, 0.22)
	floor_node.material_override = floor_material
	add_child(floor_node)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.15, 0.19)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.90, 1.0)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(2.4, 2.9, 6)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.current = true
	for i in range(15):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_tree().root.get_texture().get_image().save_png(out_path + "previews/godot_comparison.png") == OK)
	var report := {"status": "PASS", "real_unit_setup": true, "race": review_race, "builder_path": model_path,
		"idle_walk_work": true, "work_returns_to_idle": true, "consumed_visual_cleanup": true,
		"all_race_models_registered": true, "mechanics_preserved": true}
	var file := FileAccess.open(out_path + "unit_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BUILDER_VALIDATION " + JSON.stringify(report))
	builder.free()
	settler.free()
	owner.release_relations()
	get_tree().quit()
