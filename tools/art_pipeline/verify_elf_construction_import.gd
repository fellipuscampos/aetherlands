extends SceneTree

var problems: Array[String] = []
var max_content_half_plane := 0.0

func half_plane(point: Vector3) -> float:
	var distance := -INF
	for side in range(6):
		var angle := float(side) * PI / 3.0
		distance = maxf(distance, point.x * cos(angle) + point.z * sin(angle))
	return distance

func content_extent(point: Vector3) -> void:
	max_content_half_plane = maxf(max_content_half_plane, half_plane(point))

func check(condition: bool, message: String) -> void:
	if not condition:
		problems.append(message)

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var packed := load("res://assets/generated/elves/buildings/elf_construction_site_hex_v1/elf_construction_site_hex_v1.tscn") as PackedScene
	check(packed != null, "Scene did not import")
	var site := packed.instantiate() as Node3D
	root.add_child(site)
	await process_frame
	var player := site.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	var skeleton := site.find_child("*Skeleton3D*", true, false) as Skeleton3D
	check(player != null and skeleton != null, "Missing worker rig/animation")
	check(player.is_playing() and player.current_animation == "construction", "Construction did not autoplay")
	var animation := player.get_animation("construction")
	check(absf(animation.length - 6.0) < 0.001, "Duration changed")
	check(animation.loop_mode == Animation.LOOP_LINEAR, "Clip does not loop")
	check(site.transform.is_equal_approx(Transform3D.IDENTITY), "Root is offset")
	check(site.find_children("*", "MeshInstance3D", true, false).size() == 2, "Expected two runtime meshes")
	check(not site.find_child("*Camera*", true, false), "Studio camera leaked into export")
	var ground_min := INF
	var largest_ground_triangle := 0.0
	var worker_mesh: MeshInstance3D
	for node: MeshInstance3D in site.find_children("*", "MeshInstance3D", true, false):
		check(node.mesh.get_surface_count() == 1, "Expected one material per mesh")
		var material := node.mesh.surface_get_material(0) as BaseMaterial3D
		check(material.albedo_texture != null, "Missing pixel atlas")
		check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "Wrong texture filter")
		check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Unexpected transparency")
		if node.name.begins_with("Construction_Props"):
			var props_arrays := node.mesh.surface_get_arrays(0)
			var props_vertices: PackedVector3Array = props_arrays[Mesh.ARRAY_VERTEX]
			var props_indices: PackedInt32Array = props_arrays[Mesh.ARRAY_INDEX]
			for vertex: Vector3 in props_vertices:
				var point := node.global_transform * vertex
				ground_min = minf(ground_min, point.y)
				content_extent(point)
			for index in range(0, props_indices.size(), 3):
				var a := props_vertices[props_indices[index]]
				var b := props_vertices[props_indices[index + 1]]
				var c := props_vertices[props_indices[index + 2]]
				if absf(a.y) < 0.0001 and absf(b.y) < 0.0001 and absf(c.y) < 0.0001:
					largest_ground_triangle = maxf(largest_ground_triangle, (b - a).cross(c - a).length() * 0.5)
		else:
			worker_mesh = node
	check(absf(ground_min) < 0.0001, "Props must rest directly on the terrain")
	check(largest_ground_triangle < 0.08, "A ground plate leaked into the model")
	var first: Array[Transform3D] = []
	var max_movement := 0.0
	var first_vertices := PackedVector3Array()
	var max_visual_movement := 0.0
	var max_arm_step := 0.0
	var previous_rotations: Array[Quaternion] = []
	var ground_feet := {"Joiner_body": INF, "Carpenter_body": INF}
	var worker_arrays := worker_mesh.mesh.surface_get_arrays(0)
	var worker_vertices: PackedVector3Array = worker_arrays[Mesh.ARRAY_VERTEX]
	var worker_bones: PackedInt32Array = worker_arrays[Mesh.ARRAY_BONES]
	var worker_weights: PackedFloat32Array = worker_arrays[Mesh.ARRAY_WEIGHTS]
	var worker_skin := worker_mesh.skin
	var skeleton_bones: Array[int] = []
	for bind in worker_skin.get_bind_count():
		var bone_id := worker_skin.get_bind_bone(bind)
		if bone_id < 0:
			bone_id = skeleton.find_bone(worker_skin.get_bind_name(bind))
		check(bone_id >= 0, "Worker skin bind lost its bone")
		skeleton_bones.append(bone_id)
	for index in worker_vertices.size():
		check(absf(worker_weights[index * 4] - 1.0) < 0.0001, "Voxel parts must retain rigid weights")
	for sample in range(181):
		player.seek(float(sample) / 30.0, true)
		player.advance(0.0)
		var skin_transforms: Array[Transform3D] = []
		for bind in worker_skin.get_bind_count():
			skin_transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton_bones[bind]) * worker_skin.get_bind_pose(bind))
		for index in worker_vertices.size():
			var point := skin_transforms[worker_bones[index * 4]] * worker_vertices[index]
			content_extent(point)
			check(point.y >= -0.0001, "Worker penetrates terrain")
			if sample == 0:
				first_vertices.append(point)
				var bone_name := skeleton.get_bone_name(skeleton_bones[worker_bones[index * 4]])
				if ground_feet.has(bone_name):
					ground_feet[bone_name] = minf(ground_feet[bone_name], point.y)
			else:
				max_visual_movement = maxf(max_visual_movement, point.distance_to(first_vertices[index]))
		for bone in skeleton.get_bone_count():
			var transform := skeleton.get_bone_global_pose(bone)
			var rotation := transform.basis.get_rotation_quaternion()
			if sample == 0:
				first.append(transform)
				previous_rotations.append(rotation)
			else:
				var movement := transform.origin.distance_to(first[bone].origin)
				max_movement = maxf(max_movement, movement)
				if skeleton.get_bone_name(bone).ends_with("_body"):
					check(transform.is_equal_approx(first[bone]), "Feet/body drifted")
				if "_upper_" in skeleton.get_bone_name(bone) or "_fore_" in skeleton.get_bone_name(bone):
					max_arm_step = maxf(max_arm_step, rad_to_deg(rotation.angle_to(previous_rotations[bone])))
				previous_rotations[bone] = rotation
				if sample == 180:
					check(transform.is_equal_approx(first[bone]), "Loop does not close")
	# A rotating mallet moves substantially even with little wrist translation.
	check(max_visual_movement > 0.035, "Skinned worker/tool motion was lost during export")
	check(max_arm_step < 6.0, "Arm rotation jumps between frames")
	for bone_name in ground_feet:
		check(absf(ground_feet[bone_name]) < 0.0001, "Ground worker is floating above terrain: " + bone_name)
	check(max_content_half_plane < 0.9 * sqrt(3.0) / 2.0 - 0.035, "Content exceeds the reserved map footprint")
	player.seek(5.95, true)
	player.advance(0.10)
	check(player.is_playing() and player.current_animation_position < 0.10, "Playback stopped at loop boundary")
	var report := {"status": "PASS" if problems.is_empty() else "FAIL", "meshes": 2, "clip": "construction", "seconds": animation.length, "bones": skeleton.get_bone_count(), "max_worker_movement": max_movement, "fixed_feet": true, "ground_plate": false, "ground_workers_feet_y": ground_feet, "footprint_radius": 0.9, "containment_pose_samples": 181, "max_content_half_plane": max_content_half_plane, "footprint_margin": 0.9 * sqrt(3.0) / 2.0 - max_content_half_plane, "max_arm_rotation_step_degrees": max_arm_step, "problems": problems}
	var file := FileAccess.open("res://godot_validation.json", FileAccess.WRITE)
	report["max_visual_worker_movement"] = max_visual_movement
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print(JSON.stringify(report))
	site.free()
	quit(0 if problems.is_empty() else 1)
