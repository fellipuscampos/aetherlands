extends Node3D

var output_path: String
var camera: Camera3D
var unit: Unit
var model: Node3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.size = Vector2i(1000, 1000)
	var data := UnitDatabase.create_unit("v2_manifestation_elemental_primordial")
	var model_path := data.model_scene_path
	output_path = model_path.get_base_dir() + "/"
	assert(model_path.contains("elemental_dragon_") and data.model_scale_multiplier == 1.0)
	assert(data.is_flying() and data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert(not data.can_basic_attack and data.attack == 0 and data.max_hp == 40)
	assert(data.defense == 6.5 and data.movement_points == 4.0)
	assert(data.production_cost == 110 and data.production_mana_cost == 75)
	unit = Unit.new()
	add_child(unit)
	unit.setup(data, null, Vector2i.ZERO)
	for child in unit.find_children("*", "Node3D", true, false):
		if child is Node3D and child.scene_file_path == model_path:
			model = child
			break
	assert(model != null and model.scale.is_equal_approx(Vector3.ONE))
	var animated := model_path.contains("_animated")
	var full_set := model_path.contains("v6_animated") or model_path.contains("v9_animated") or model_path.contains("v10_animated")
	if animated:
		assert(data.animation_scene_path == model_path and data.idle_animation_override == "idle")
		assert(unit._anim_player != null and unit._anim_player.has_animation("idle"))
		assert(unit._anim_player.is_playing() and unit._anim_player.current_animation == "idle")
		assert(unit._anim_player.get_animation("idle").loop_mode == Animation.LOOP_LINEAR)
		for child in model.find_children("*", "AnimationPlayer", true, false):
			if child != unit._anim_player: (child as AnimationPlayer).stop()
	if full_set:
		assert(data.walk_animation_override == "walk" and data.attack_animation_override == "attack")
		assert(data.cast_animation_override == "spell" and data.pose_transition_time > 0.0)
		assert(unit.moving_animation == "walk" and unit.attack_animation == "attack" and unit.cast_animation == "spell")
		for clip in ["walk", "attack", "spell"]: assert(unit._anim_player.has_animation(clip))
		assert(unit._anim_player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR)
		assert(unit._anim_player.get_animation("attack").loop_mode == Animation.LOOP_NONE)
		assert(unit._anim_player.get_animation("spell").loop_mode == Animation.LOOP_NONE)
	for child in unit.find_children("*", "Node3D", true, false):
		if child is Sprite3D or child is Label3D: child.visible = false
	if unit._hp_bar_bg: unit._hp_bar_bg.visible = false
	if unit._hp_bar_fg: unit._hp_bar_fg.visible = false
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30, 30)
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.17, .22, .26)
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	add_child(floor_node)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.10, .13, .18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.85, .92, 1.0)
	environment.ambient_light_energy = .65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3
	camera.position = Vector3(5, 4.4, 9)
	camera.look_at(Vector3(0, 1.8, .1))
	camera.current = true
	for frame in range(10): await get_tree().process_frame
	if model_path.contains("v9_animated") and "--validate" in OS.get_cmdline_user_args():
		assert(_validate_path_transitions())
	if full_set and "--validate" in OS.get_cmdline_user_args():
		# The real gameplay hooks select the requested clips and restore the current rest/movement cycle.
		unit.walk_path([Vector3(0, 0, .2)])
		assert(unit._walking and unit._anim_player.current_animation == "walk")
		unit.play_attack_visual(null)
		assert(unit._anim_player.current_animation == "attack")
		unit._anim_player.advance(2.45)
		assert(unit._anim_player.current_animation == "walk")
		await unit._walk_tween.finished
		assert(not unit._walking and unit._anim_player.current_animation == "idle")
		unit.position = Vector3.ZERO
		unit._stop_facing_turn()
		unit.rotation = Vector3.ZERO
		unit.play_attack_visual(null)
		assert(unit._anim_player.current_animation == "attack")
		unit._anim_player.advance(2.45)
		assert(unit._anim_player.current_animation == "idle")
		unit.play_cast_visual(Vector3(0, 0, 2))
		assert(unit._anim_player.current_animation == "spell")
		unit._anim_player.advance(unit._anim_player.get_animation("spell").length+.05)
		assert(unit._anim_player.current_animation == "idle")
		unit._stop_facing_turn()
		unit.rotation = Vector3.ZERO
	if "--capture-idle" in OS.get_cmdline_user_args():
		assert(animated)
		get_tree().root.size = Vector2i(720, 720)
		var directory := output_path + "previews/idle_frames"
		assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
		var ignore := FileAccess.open(directory + "/.gdignore", FileAccess.WRITE)
		ignore.close()
		for sample in range(roundi(unit._anim_player.get_animation("idle").length*20)):
			unit._anim_player.play("idle", 0)
			unit._anim_player.seek(float(sample)/20.0,true)
			unit._anim_player.advance(0)
			unit._anim_player.pause()
			await RenderingServer.frame_post_draw
			assert(get_tree().root.get_texture().get_image().save_png(directory + "/%03d.png" % sample)==OK)
		unit._anim_player.play("idle", 0)
	if "--capture-actions" in OS.get_cmdline_user_args():
		assert(full_set)
		get_tree().root.size = Vector2i(720, 720)
		var specs := {"walk":3.0, "attack":2.4, "spell":4.0}
		for clip in specs: specs[clip]=unit._anim_player.get_animation(clip).length
		for clip in specs:
			if model_path.contains("v10_animated") and clip=="walk":
				camera.size=8.0
				camera.position=Vector3(6,6,10)
				camera.look_at(Vector3(.5,2.2,-2.3))
			else:
				camera.size=4.3
				camera.position=Vector3(5,4.4,9)
				camera.look_at(Vector3(0,1.8,.1))
			var directory: String = output_path + "previews/" + String(clip) + "_frames"
			assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
			var ignore := FileAccess.open(directory + "/.gdignore", FileAccess.WRITE)
			ignore.close()
			var duration: float = specs[clip]
			var count := roundi(duration*20) + (0 if clip=="walk" else 10)
			for sample in count:
				unit._anim_player.play(clip, 0)
				unit._anim_player.seek(minf(duration,float(sample)/20.0),true)
				unit._anim_player.advance(0)
				unit._anim_player.pause()
				await RenderingServer.frame_post_draw
				assert(get_tree().root.get_texture().get_image().save_png(directory + "/%03d.png" % sample)==OK)
		unit._anim_player.play("idle", 0)
		camera.size=4.3
	if "--validate" not in OS.get_cmdline_user_args(): return
	var views := {"godot_three_quarter":Vector3(5, 4.4, 9),
		"godot_front":Vector3(0, 2.1, 9),"godot_side":Vector3(9, 3.4, .3),
		"godot_back":Vector3(-5, 4.3, -9),"godot_game_view":Vector3(6, 9, 7)}
	for view in views:
		camera.position = views[view]
		camera.look_at(Vector3(0, 1.8, .1))
		for frame in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_tree().root.get_texture().get_image().save_png(output_path + "previews/" + view + ".png") == OK)
	var report := {"status":"PASS", "real_unit_setup":true, "flying":true,
		"grand_manifestation":true,"gameplay_preserved":true,"runtime_scale":model.scale.x,
		"idle_playing_on_real_unit":animated,"walk_attack_spell_hooks":full_set,
		"path_transition_continuity":model_path.contains("v9_animated"),
		"distinct_animation_states":model_path.contains("v10_animated"),
		"one_shots_return_to_idle_or_walk":full_set,"views":views.keys()}
	var file := FileAccess.open(output_path + "unit_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ELEMENTAL_DRAGON_UNIT_VALIDATION " + JSON.stringify(report))
	get_tree().quit()

func _validate_path_transitions() -> bool:
	var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	unit._anim_player.play("idle",0)
	unit._anim_player.seek(4.32,true)
	unit._anim_player.advance(0)
	skeleton.force_update_all_bone_transforms()
	var reference := {}
	for name in ["head","ring_09","ring_19","ring_29"]:
		reference[name]=skeleton.get_bone_global_pose(skeleton.find_bone(name))
	for clip in ["walk","attack","spell"]:
		if clip=="spell": unit.play_cast_visual(Vector3(0,0,2))
		else: unit._play_animation(clip)
		unit._anim_player.advance(0)
		skeleton.force_update_all_bone_transforms()
		for name in reference:
			var before: Transform3D=reference[name]
			var after := skeleton.get_bone_global_pose(skeleton.find_bone(name))
			assert(before.origin.distance_to(after.origin)<.01,str([clip,name,before.origin,after.origin]))
			assert(before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())<.025)
		if clip in ["attack","spell"]:
			unit._anim_player.advance(unit._anim_player.current_animation_length+.01)
			assert(unit._anim_player.current_animation=="idle")
			unit._anim_player.advance(0)
			skeleton.force_update_all_bone_transforms()
			for name in reference:
				var before: Transform3D=reference[name]
				assert(before.origin.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)<.01)
	unit._anim_player.play("idle",0)
	unit._anim_player.seek(0,true)
	unit._anim_player.advance(0)
	unit._stop_facing_turn()
	unit.rotation=Vector3.ZERO
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and model:
		if event.keycode == KEY_LEFT: model.rotate_y(deg_to_rad(-15))
		elif event.keycode == KEY_RIGHT: model.rotate_y(deg_to_rad(15))
		elif event.keycode == KEY_R: model.rotation = Vector3.ZERO
