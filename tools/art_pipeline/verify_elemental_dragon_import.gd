extends SceneTree

const MODEL := "res://assets/generated/grand_manifestations/elemental_dragon_v1/elemental_dragon_v1.glb"
var pulsing_core := false
var axial_motion := false
var path_following := false
var distinct_states := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var model_path := args[1] if args.size() > 1 else MODEL
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	assert(meshes.size() == 1 and skeletons.size() == 1)
	var mesh := meshes[0] as MeshInstance3D
	var skeleton := skeletons[0] as Skeleton3D
	assert(mesh.mesh.get_surface_count() == 1 and mesh.skin != null)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture != null and material.emission_texture != null)
	assert(material.emission_enabled and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS)
	for j in range(1, 39):
		assert(skeleton.get_bone_parent(skeleton.find_bone("spine_%02d" % j)) == skeleton.find_bone("spine_%02d" % (j - 1)))
	assert(skeleton.get_bone_parent(skeleton.find_bone("core")) == skeleton.find_bone("root"))
	var animation_count := 0
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animation_count += (node as AnimationPlayer).get_animation_list().size()
	var animated := model_path.contains("_animated")
	path_following = model_path.contains("v9_animated")
	distinct_states = model_path.contains("v10_animated")
	pulsing_core = model_path.contains("v7_animated") or model_path.contains("v8_animated") or path_following or distinct_states
	axial_motion = model_path.contains("v8_animated")
	var full_set := model_path.contains("v6_animated") or pulsing_core
	assert(animation_count == (4 if full_set else (1 if animated else 0)))
	skeleton.force_update_all_bone_transforms()
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stride := int(weights.size() / vertices.size())
	var transforms: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
		assert(bone >= 0)
		transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var maximum_influences := 0
	var maximum_weight_error := 0.0
	for i in vertices.size():
		var point := Vector3.ZERO
		var weight_sum := 0.0
		var count := 0
		for j in stride:
			var index := i * stride + j
			if weights[index] < .00001: continue
			count += 1
			weight_sum += weights[index]
			point += (transforms[bones[index]] * vertices[i]) * weights[index]
		maximum_weight_error = maxf(maximum_weight_error, absf(weight_sum - 1.0))
		# Two half weights can lose one unit of precision in 16-bit mesh packing.
		assert(absf(weight_sum - 1.0) < .00002 and count <= 2)
		maximum_influences = maxi(maximum_influences, count)
		low = low.min(point)
		high = high.max(point)
	assert(absf(high.y - low.y - 3.0) < .0001)
	assert(absf(low.y - .35) < .0001)
	var report := {"status":"PASS", "height_m":high.y - low.y, "ground_clearance_m":low.y,
		"size_m":[high.x-low.x, high.y-low.y, high.z-low.z], "triangles":indices.size()/3,
		"bones":skeleton.get_bone_count(), "spine_bones":39, "meshes":1, "materials":1,
		"animations":animation_count, "maximum_skin_influences":maximum_influences,
		"maximum_weight_packing_error":maximum_weight_error,
		"continuous_spine":true, "independent_core":true, "nearest":true, "emission":true}
	if animated:
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		report["idle"] = _validate_idle(mesh, skeleton, player)
		if full_set: report["actions"] = _validate_actions(mesh,skeleton,player)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ELEMENTAL_DRAGON_VALIDATION " + JSON.stringify(report))
	model.free()
	quit()

func _skin_points(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	skeleton.force_update_all_bone_transforms()
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := int(weights.size() / vertices.size())
	var transforms: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(bind)
		var transform := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind)
		assert(transform.is_finite())
		if pulsing_core and skeleton.get_bone_name(bone)==&"core":
			var scale := transform.basis.get_scale()
			assert(scale.x>.75 and scale.x<1.30 and absf(scale.x-scale.y)<.0001 and absf(scale.y-scale.z)<.0001)
		else: assert(absf(transform.basis.determinant()-1.0)<.0001)
		transforms.append(transform)
	var points: PackedVector3Array = []
	for i in vertices.size():
		var point := Vector3.ZERO
		for j in stride:
			var k := i*stride+j
			if weights[k] > .00001: point += (transforms[bones[k]] * vertices[i]) * weights[k]
		assert(point.is_finite())
		points.append(point)
	return points

func _validate_idle(mesh: MeshInstance3D, skeleton: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	assert(player.has_animation("idle"))
	var animation := player.get_animation("idle")
	var duration := 12.0 if path_following else 6.0
	var sample_count := roundi(duration*60)+1
	assert(absf(animation.length-duration)<.001 and animation.loop_mode==Animation.LOOP_LINEAR)
	var lengths: Array[float] = []
	for j in range(1,39):
		lengths.append(skeleton.get_bone_global_rest(skeleton.find_bone("spine_%02d" % j)).origin.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone("spine_%02d" % (j-1))).origin))
	var first: PackedVector3Array
	var seam := 0.0
	var ground := INF
	var joint_error := 0.0
	var root_low := INF
	var root_high := -INF
	var tail_motion := 0.0
	var first_tail := Vector3.ZERO
	var first_core := Basis.IDENTITY
	var core_turn := 0.0
	var root_bone := skeleton.find_bone("root")
	var tail_bone := skeleton.find_bone("spine_38")
	var core_bone := skeleton.find_bone("core")
	var scale_low := INF
	var scale_high := -INF
	var energy_low := INF
	var energy_high := -INF
	var middle_indices := _middle_body_indices(mesh,skeleton)
	var first_middle: PackedVector3Array
	var body_motion := 0.0
	var average_body_motion := 0.0
	var axial_roll := 0.0
	for sample in range(sample_count):
		player.play("idle",0)
		player.seek(float(sample)/60.0,true)
		player.advance(0)
		player.pause()
		var points := _skin_points(mesh,skeleton)
		if axial_motion: axial_roll=maxf(axial_roll,_axial_roll_degrees(skeleton))
		var root_pose := skeleton.get_bone_global_pose(root_bone)
		var relative_tail := root_pose.affine_inverse() * skeleton.get_bone_global_pose(tail_bone).origin
		var relative_core := (root_pose.basis.inverse() * skeleton.get_bone_global_pose(core_bone).basis).orthonormalized()
		var core_scale := skeleton.get_bone_global_pose(core_bone).basis.get_scale().x
		scale_low=minf(scale_low,core_scale)
		scale_high=maxf(scale_high,core_scale)
		if pulsing_core:
			var material := mesh.material_override as StandardMaterial3D
			assert(material != null)
			energy_low=minf(energy_low,material.emission_energy_multiplier)
			energy_high=maxf(energy_high,material.emission_energy_multiplier)
		var inverse_root := (root_pose*skeleton.get_bone_global_rest(root_bone).affine_inverse()).affine_inverse()
		var middle: PackedVector3Array = []
		for index in middle_indices: middle.append(inverse_root*points[index])
		if sample==0:
			first=points
			first_tail=relative_tail
			first_core=relative_core
			first_middle=middle
		var total_motion := 0.0
		for i in middle.size():
			var motion := middle[i].distance_to(first_middle[i])
			total_motion+=motion
			body_motion=maxf(body_motion,motion)
		average_body_motion=maxf(average_body_motion,total_motion/middle.size())
		tail_motion=maxf(tail_motion,relative_tail.distance_to(first_tail))
		core_turn=maxf(core_turn,(relative_core*first_core.inverse()).get_rotation_quaternion().get_angle())
		root_low=minf(root_low,root_pose.origin.y)
		root_high=maxf(root_high,root_pose.origin.y)
		for j in range(1,39):
			var child := skeleton.get_bone_global_pose(skeleton.find_bone("spine_%02d" % j)).origin
			var parent := skeleton.get_bone_global_pose(skeleton.find_bone("spine_%02d" % (j-1))).origin
			joint_error=maxf(joint_error,absf(child.distance_to(parent)-lengths[j-1]))
		for i in points.size():
			ground=minf(ground,points[i].y)
			if sample==sample_count-1: seam=maxf(seam,points[i].distance_to(first[i]))
	assert(seam<.0001 and ground>(.08 if axial_motion or path_following else .20) and joint_error<.0001)
	assert(root_high-root_low>.03 and root_high-root_low<.05 and tail_motion>.035 and core_turn>2.9)
	if pulsing_core:
		assert(scale_high-scale_low>(.08 if distinct_states else .15) and energy_high-energy_low>(.35 if distinct_states else .7))
		if distinct_states: assert(body_motion>.04 and body_motion<.40)
		else: assert(body_motion>.12 and average_body_motion>.04)
	if axial_motion: assert(axial_roll>15.0)
	return {"duration_s":duration,"loop":true,"samples":sample_count,"loop_seam_m":seam,
		"minimum_ground_clearance_m":ground,"maximum_spine_length_error_m":joint_error,
		"float_range_m":root_high-root_low,"tail_motion_beyond_root_m":tail_motion,
		"independent_core_rotation":true,"unit_scale_preserved":true,
		"body_motion_beyond_root_m":body_motion,"average_middle_body_motion_m":average_body_motion,
		"core_scale_range":[scale_low,scale_high],"core_energy_range":[energy_low,energy_high],"axial_roll_degrees":axial_roll}

func _validate_actions(mesh: MeshInstance3D, skeleton: Skeleton3D, player: AnimationPlayer) -> Dictionary:
	var result := {}
	var head_bone := skeleton.find_bone("head")
	var jaw_bone := skeleton.find_bone("jaw")
	var root_bone := skeleton.find_bone("root")
	var tail_bone := skeleton.find_bone("spine_38")
	var lengths: Array[float] = []
	for j in range(1,39):
		lengths.append(skeleton.get_bone_global_rest(skeleton.find_bone("spine_%02d" % j)).origin.distance_to(skeleton.get_bone_global_rest(skeleton.find_bone("spine_%02d" % (j-1))).origin))
	var specs := {"walk":3.0,"attack":2.4,"spell":4.0}
	if path_following: specs["walk"]=6.0
	if distinct_states:
		specs["walk"]=4.0
		specs["spell"]=8.0
	for clip in specs:
		assert(player.has_animation(clip))
		var animation := player.get_animation(clip)
		var duration: float = specs[clip]
		assert(absf(animation.length-duration)<.001)
		assert(animation.loop_mode == (Animation.LOOP_LINEAR if clip=="walk" else Animation.LOOP_NONE))
		var count := roundi(duration*60)+1
		var first: PackedVector3Array
		var first_head := Vector3.ZERO
		var first_tail := Vector3.ZERO
		var first_jaw := Basis.IDENTITY
		var seam := 0.0
		var ground := INF
		var joint_error := 0.0
		var head_advance := 0.0
		var head_lift := 0.0
		var jaw_angle := 0.0
		var tail_motion := 0.0
		var scale_low := INF
		var scale_high := -INF
		var energy_low := INF
		var energy_high := -INF
		var middle_indices := _middle_body_indices(mesh,skeleton)
		var first_middle: PackedVector3Array
		var body_motion := 0.0
		var average_body_motion := 0.0
		var axial_roll := 0.0
		var head_travel := 0.0
		var previous_head := Vector3.ZERO
		for sample in count:
			player.play(clip,0)
			player.seek(float(sample)/60.0,true)
			player.advance(0)
			player.pause()
			var points := _skin_points(mesh,skeleton)
			if axial_motion: axial_roll=maxf(axial_roll,_axial_roll_degrees(skeleton))
			var head_pose := skeleton.get_bone_global_pose(head_bone)
			if sample>0: head_travel+=head_pose.origin.distance_to(previous_head)
			previous_head=head_pose.origin
			var jaw_basis := head_pose.basis.inverse()*skeleton.get_bone_global_pose(jaw_bone).basis
			var tail := skeleton.get_bone_global_pose(root_bone).affine_inverse()*skeleton.get_bone_global_pose(tail_bone).origin
			var scale := skeleton.get_bone_global_pose(skeleton.find_bone("core")).basis.get_scale().x
			scale_low=minf(scale_low,scale)
			scale_high=maxf(scale_high,scale)
			if pulsing_core:
				var material := mesh.material_override as StandardMaterial3D
				assert(material != null)
				energy_low=minf(energy_low,material.emission_energy_multiplier)
				energy_high=maxf(energy_high,material.emission_energy_multiplier)
			var inverse_root := (skeleton.get_bone_global_pose(root_bone)*skeleton.get_bone_global_rest(root_bone).affine_inverse()).affine_inverse()
			var middle: PackedVector3Array = []
			for index in middle_indices: middle.append(inverse_root*points[index])
			if sample==0:
				first=points
				first_head=head_pose.origin
				first_tail=tail
				first_jaw=jaw_basis
				first_middle=middle
			var total_motion := 0.0
			for i in middle.size():
				var motion := middle[i].distance_to(first_middle[i])
				total_motion+=motion
				body_motion=maxf(body_motion,motion)
			average_body_motion=maxf(average_body_motion,total_motion/middle.size())
			head_advance=maxf(head_advance,head_pose.origin.z-first_head.z)
			head_lift=maxf(head_lift,head_pose.origin.y-first_head.y)
			jaw_angle=maxf(jaw_angle,(jaw_basis*first_jaw.inverse()).get_rotation_quaternion().get_angle())
			tail_motion=maxf(tail_motion,tail.distance_to(first_tail))
			for j in range(1,39):
				var child := skeleton.get_bone_global_pose(skeleton.find_bone("spine_%02d" % j)).origin
				var parent := skeleton.get_bone_global_pose(skeleton.find_bone("spine_%02d" % (j-1))).origin
				joint_error=maxf(joint_error,absf(child.distance_to(parent)-lengths[j-1]))
			for i in points.size():
				ground=minf(ground,points[i].y)
				if sample==count-1: seam=maxf(seam,points[i].distance_to(first[i]))
		assert(seam<.0001 and ground>(.08 if axial_motion or path_following else .20) and joint_error<.0001)
		if clip=="walk": assert(tail_motion>.035)
		elif clip=="attack": assert((head_travel>1.0 if path_following else head_advance>.20) and jaw_angle>.35)
		elif clip=="spell":
			if distinct_states: assert(head_travel>15.0 and body_motion>2.0)
			else: assert((head_travel>1.0 if path_following else head_lift>.15) and jaw_angle>.20)
		if path_following and clip=="walk": assert(head_travel>10.0 and tail_motion>1.0)
		if pulsing_core: assert(scale_high-scale_low>(.18 if distinct_states else .20) and energy_high-energy_low>(.8 if distinct_states else .9) and body_motion>.12 and average_body_motion>.04)
		if axial_motion: assert(axial_roll>15.0)
		result[clip]={"duration_s":duration,"loop":clip=="walk","samples":count,
			"end_pose_difference_m":seam,"minimum_ground_clearance_m":ground,
			"maximum_spine_length_error_m":joint_error,"head_advance_m":head_advance,
			"head_lift_m":head_lift,"jaw_open_degrees":rad_to_deg(jaw_angle),
			"head_travel_m":head_travel,"path_following":path_following,
			"tail_motion_beyond_root_m":tail_motion,"unit_scale_preserved":true,
			"body_motion_beyond_root_m":body_motion,"average_middle_body_motion_m":average_body_motion,
			"core_scale_range":[scale_low,scale_high],"core_energy_range":[energy_low,energy_high],"axial_roll_degrees":axial_roll}
	return result

func _middle_body_indices(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedInt32Array:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var stride := int(weights.size()/vertices.size())
	var names: Array[StringName] = []
	for bind in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(bind)
		if name==&"": name=skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
		names.append(name)
	var result: PackedInt32Array = []
	for i in vertices.size():
		for j in stride:
			var k := i*stride+j
			if weights[k]>.001 and names[bones[k]] in [&"spine_10",&"spine_20",&"spine_30",&"ring_09",&"ring_19",&"ring_29"]:
				result.append(i)
				break
	assert(result.size()>20)
	return result

func _axial_roll_degrees(skeleton: Skeleton3D) -> float:
	var root_bone := skeleton.find_bone("root")
	var ring_bone := skeleton.find_bone("ring_19")
	assert(ring_bone>=0)
	var root_delta := skeleton.get_bone_global_pose(root_bone)*skeleton.get_bone_global_rest(root_bone).affine_inverse()
	var rest_basis := skeleton.get_bone_global_rest(ring_bone).basis.orthonormalized()
	var current_basis := (root_delta.affine_inverse()*skeleton.get_bone_global_pose(ring_bone)).basis.orthonormalized()
	var swing := Basis(Quaternion(rest_basis.y,current_basis.y))
	var twist := (swing.inverse()*current_basis*rest_basis.inverse()).orthonormalized().get_rotation_quaternion()
	var angle := twist.get_angle()
	return rad_to_deg(minf(angle,TAU-angle))
