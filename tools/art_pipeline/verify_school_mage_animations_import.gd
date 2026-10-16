extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func matrices(skeleton: Skeleton3D) -> Array[Transform3D]:
	skeleton.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()): result.append(skeleton.get_bone_global_pose(bone))
	return result

func difference(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var value := 0.0
	for index in range(a.size()):
		value=maxf(value,a[index].origin.distance_to(b[index].origin))
		for axis in range(3): value=maxf(value,a[index].basis[axis].distance_to(b[index].basis[axis]))
	return value

func skin_floor(mesh_node: MeshInstance3D, skeleton: Skeleton3D) -> float:
	var skin := mesh_node.skin
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influence_count := weights.size()/vertices.size()
	var minimum := INF
	for vertex in range(vertices.size()):
		var point := Vector3.ZERO
		for slot in range(influence_count):
			var weight := weights[vertex*influence_count+slot]
			if weight < .00001: continue
			var bind := indices[vertex*influence_count+slot]
			var bone := skin.get_bind_bone(bind)
			if bone < 0: bone=skeleton.find_bone(skin.get_bind_name(bind))
			point+=(skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind)*vertices[vertex])*weight
		minimum=minf(minimum,point.y)
	return minimum

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art_source/school_mages_animation_review/manifest.json"))
	var results: Array=[]
	require(manifest.assets.size()==24,"Expected 24 mages")
	for row: Dictionary in manifest.assets:
		var path: String="res://"+row.glb
		var packed := load(path) as PackedScene
		require(packed!=null,path+" failed to load")
		if packed==null: continue
		var model := packed.instantiate()
		root.add_child(model)
		var meshes := model.find_children("*","MeshInstance3D",true,false)
		var skeletons := model.find_children("*","Skeleton3D",true,false)
		var players := model.find_children("*","AnimationPlayer",true,false)
		require(meshes.size()==1 and skeletons.size()==1 and players.size()==1,path+" runtime structure")
		if meshes.size()!=1 or skeletons.size()!=1 or players.size()!=1:
			model.free(); continue
		var mesh := meshes[0] as MeshInstance3D
		require(model.scale.is_equal_approx(Vector3.ONE),path+" native scale")
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		require(mesh.mesh.get_surface_count()==1 and mesh.skin!=null,path+" skinned single surface")
		require(skeleton.get_bone_count()==16,path+" skeleton size")
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		require(material!=null and material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,path+" pixel texture filter")
		var clips: Dictionary={}
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in ["idle","walk","spell"]:
			require(player.has_animation(clip),path+" missing "+clip)
			if not player.has_animation(clip): continue
			var animation := player.get_animation(clip)
			var duration := 1.5 if clip=="walk" else 3.0
			require(absf(animation.length-duration)<.0001,path+" clip duration "+clip)
			require(animation.loop_mode==(Animation.LOOP_NONE if clip=="spell" else Animation.LOOP_LINEAR),path+" loop mode "+clip)
			player.play(clip); player.seek(0,true); player.advance(0)
			var first := matrices(skeleton)
			var maximum_motion := 0.0
			var minimum_floor := INF
			var minimum_elbow_behind_wrist := INF
			var minimum_wrist_forward := INF
			var root_bone := skeleton.find_bone("root")
			var hinge_error := 0.0
			var wrist_limits: Dictionary={"l":0.0,"r":0.0}
			for sample in range(25):
				player.seek(duration*sample/24.0,true); player.advance(0)
				var current := matrices(skeleton)
				maximum_motion=maxf(maximum_motion,difference(first,current))
				minimum_floor=minf(minimum_floor,skin_floor(mesh,skeleton))
				require(current[root_bone].origin.length()<.0001,path+" root drift "+clip)
				for side: String in ["l","r"]:
					var upper_bone := skeleton.find_bone("upper_arm_"+side)
					var fore_bone := skeleton.find_bone("forearm_"+side)
					var hand_bone := skeleton.find_bone("hand_"+side)
					var upper_rest := skeleton.get_bone_global_rest(upper_bone)
					var fore_rest := skeleton.get_bone_global_rest(fore_bone)
					var hand_rest := skeleton.get_bone_global_rest(hand_bone)
					var axis := (hand_rest.origin-fore_rest.origin).normalized()
					var hinge := (hand_rest.origin-fore_rest.origin).cross(fore_rest.origin-upper_rest.origin)
					if hinge.length()<.00001: hinge=Vector3.RIGHT-axis*axis.x
					hinge=hinge.normalized()
					var upper_delta := current[upper_bone].basis*upper_rest.basis.inverse()
					var fore_delta := current[fore_bone].basis*fore_rest.basis.inverse()
					var hand_delta := current[hand_bone].basis*hand_rest.basis.inverse()
					hinge_error=maxf(hinge_error,((upper_delta.inverse()*fore_delta)*hinge-hinge).length())
					var wrist := (fore_delta.inverse()*hand_delta).get_rotation_quaternion().get_angle()
					wrist=minf(wrist,TAU-wrist)
					wrist_limits[side]=maxf(wrist_limits[side],rad_to_deg(wrist))
			player.seek(duration,true); player.advance(0)
			var loop_error := difference(first,matrices(skeleton))
			require(loop_error<.0001,path+" discontinuous loop "+clip)
			require(minimum_floor>-.0001,path+" floor penetration "+clip+": "+str(minimum_floor))
			require(maximum_motion>.002,path+" motion missing "+clip)
			require(hinge_error<.01,path+" elbow plane rolls "+clip)
			require(wrist_limits.l<6 and wrist_limits.r<(1 if clip=="spell" else 25),path+" wrist orientation "+clip)
			clips[clip]={"seconds":animation.length,"loop":clip!="spell","loop_error":loop_error,"minimum_floor":minimum_floor,"motion":maximum_motion,"pose_samples":25,"maximum_elbow_hinge_error":hinge_error,"maximum_wrist_angles_degrees":wrist_limits}
		results.append({"asset":row.stem,"clips":clips,"mesh_count":1,"surface_count":1,"bones":16})
		model.free()
	var output: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","verified":results.size(),"clips":results.size()*3,"pose_samples":results.size()*75,"assets":results,"failures":failures}
	var file := FileAccess.open("res://docs/school_mages_animation_godot_import_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
