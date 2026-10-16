extends SceneTree
func _initialize() -> void:
	inspect.call_deferred()
func inspect() -> void:
	var model := (load("res://assets/generated/orcs/orc_rogue_v1/orc_rogue_v1.glb") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	for node in [model]+model.find_children("*","Node3D",true,false):
		print(node.name," ",node.transform," GLOBAL ",node.global_transform)
	var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	print("STATIC ",mesh.global_transform * mesh.get_aabb())
	var arrays := mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var low := 1000.0
	var high := -1000.0
	for index in positions.size():
		var transformed := Vector3.ZERO
		for channel in 4:
			var binding := bones[index*4+channel]
			var bone := mesh.skin.get_bind_bone(binding)
			if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(binding))
			transformed += (skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding) * positions[index]) * weights[index*4+channel]
		low = min(low, transformed.y)
		high = max(high, transformed.y)
	print("SKINNED ",low," ",high)
	for name: String in ["head","foot_l","root"]:
		var bone := skeleton.find_bone(name)
		print(name," ",skeleton.get_bone_global_rest(bone)," POSE ",skeleton.get_bone_global_pose(bone))
	quit()
