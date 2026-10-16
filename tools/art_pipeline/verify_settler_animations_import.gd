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
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://settlers_manifest.json"))
	var results: Array=[]
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
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		require(mesh.mesh.get_surface_count()==1 and mesh.skin!=null,path+" skinned single surface")
		require(skeleton.get_bone_count()==16,path+" skeleton size")
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		require(material!=null and material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,path+" pixel texture filter")
		var clips: Dictionary={}
		for clip: String in ["idle","walk"]:
			require(player.has_animation(clip),path+" missing "+clip)
			if not player.has_animation(clip): continue
			var animation := player.get_animation(clip)
			var duration := 3.0 if clip=="idle" else 1.5
			require(absf(animation.length-duration)<.0001,path+" clip duration "+clip)
			require(animation.loop_mode==Animation.LOOP_LINEAR,path+" non-looping "+clip)
			player.play(clip); player.seek(0,true); player.advance(0)
			var first := matrices(skeleton)
			var maximum_motion := 0.0
			var minimum_floor := INF
			var minimum_elbow_behind_wrist := INF
			var minimum_wrist_forward := INF
			var root_bone := skeleton.find_bone("root")
			for sample in range(25):
				player.seek(duration*sample/24.0,true); player.advance(0)
				var current := matrices(skeleton)
				maximum_motion=maxf(maximum_motion,difference(first,current))
				minimum_floor=minf(minimum_floor,skin_floor(mesh,skeleton))
				require(current[root_bone].origin.length()<.0001,path+" root drift "+clip)
				if row.race=="elf":
					# Blender front -Y becomes +Z in the exported glTF.
					var shoulder := current[skeleton.find_bone("upper_arm_r")].origin
					var elbow := current[skeleton.find_bone("forearm_r")].origin
					var wrist := current[skeleton.find_bone("hand_r")].origin
					minimum_elbow_behind_wrist=minf(minimum_elbow_behind_wrist,wrist.z-elbow.z)
					minimum_wrist_forward=minf(minimum_wrist_forward,wrist.z-shoulder.z)
			player.seek(duration,true); player.advance(0)
			var loop_error := difference(first,matrices(skeleton))
			require(loop_error<.0001,path+" discontinuous loop "+clip)
			require(minimum_floor>-.0001,path+" floor penetration "+clip+": "+str(minimum_floor))
			require(maximum_motion>.002,path+" motion missing "+clip)
			clips[clip]={"seconds":animation.length,"loop":true,"loop_error":loop_error,"minimum_floor":minimum_floor,"motion":maximum_motion,"pose_samples":25}
			if row.race=="elf":
				require(minimum_elbow_behind_wrist>.05 and minimum_wrist_forward>.10,path+" backwards staff arm "+clip)
				clips[clip]["minimum_elbow_behind_wrist"]=minimum_elbow_behind_wrist
				clips[clip]["minimum_wrist_forward"]=minimum_wrist_forward
		results.append({"asset":row.stem,"clips":clips,"mesh_count":1,"surface_count":1,"bones":16})
		model.free()
	var output: Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","verified":results.size(),"clips":results.size()*2,"pose_samples":results.size()*50,"assets":results,"failures":failures}
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify(output))
	quit(0 if failures.is_empty() else 1)
