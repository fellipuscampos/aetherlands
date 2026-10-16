extends SceneTree

const FAMILIES := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]
const CLIPS := ["idle", "walk", "attack"]
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func player_of(model: Node) -> AnimationPlayer:
	return model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

func skeleton_of(model: Node) -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func is_constant(animation: Animation, track: int) -> bool:
	if animation.track_get_key_count(track) < 2: return true
	var first: Variant = animation.track_get_key_value(track, 0)
	for key in range(1, animation.track_get_key_count(track)):
		var value: Variant = animation.track_get_key_value(track, key)
		if first is Vector3 and (first as Vector3).distance_to(value) > 0.00001: return false
		if first is Quaternion and (first as Quaternion).angle_to(value) > 0.0001: return false
	return true

func shared_library(model: Node, family: String) -> AnimationLibrary:
	var player := player_of(model)
	var library := AnimationLibrary.new()
	for clip in CLIPS:
		require(player.has_animation(clip), "%s missing %s" % [family, clip])
		if not player.has_animation(clip): continue
		var animation := player.get_animation(clip).duplicate(true) as Animation
		# glTF includes constant bind translations in sampled channels. Remove
		# those so different rest joints (larger hammer clearance, siege pivots)
		# remain in the destination skeleton. Moving channels are shared verbatim.
		for track in range(animation.get_track_count()-1, -1, -1):
			var type := animation.track_get_type(track)
			var path := String(animation.track_get_path(track))
			if type == Animation.TYPE_POSITION_3D and is_constant(animation, track):
				animation.remove_track(track)
			elif family == "siege" and (path.ends_with(":recoil") or path.ends_with(":recoil_axis")) and type == Animation.TYPE_ROTATION_3D:
				require(is_constant(animation, track), "Recoil rotation must remain in each cannon's bind rest")
				animation.remove_track(track)
		animation.loop_mode = Animation.LOOP_NONE if clip == "attack" else Animation.LOOP_LINEAR
		library.add_animation(clip, animation)
	return library

func poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	skeleton.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()): result.append(skeleton.get_bone_global_pose(bone))
	return result

func difference(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var maximum := 0.0
	for bone in range(a.size()):
		maximum = maxf(maximum, a[bone].origin.distance_to(b[bone].origin))
		for axis in range(3): maximum = maxf(maximum, a[bone].basis[axis].distance_to(b[bone].basis[axis]))
	return maximum

func min_skin_y(model: Node, skeleton: Skeleton3D) -> float:
	var minimum := INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var skin := mesh_node.skin
		require(skin != null, "Unskinned dwarf mesh")
		if skin == null: continue
		for surface in range(mesh_node.mesh.get_surface_count()):
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influence_count := weights.size()/vertices.size()
			for vertex in range(vertices.size()):
				var point := Vector3.ZERO
				for slot in range(influence_count):
					var weight := weights[vertex*influence_count+slot]
					if weight < 0.0001: continue
					var bind := indices[vertex*influence_count+slot]
					var bone := skin.get_bind_bone(bind)
					if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
					point += (skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind)*vertices[vertex])*weight
				minimum = minf(minimum, point.y)
	return minimum

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var requested: Array[String] = []
	for index in range(1, args.size()): requested.append(args[index])
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/dwarves/dwarf_troops_manifest.json"))
	var results: Array = []
	DirAccess.make_dir_recursive_absolute("res://assets/generated/dwarves/animations")
	for family: String in FAMILIES:
		if not requested.is_empty() and not requested.has(family): continue
		var selected: Array = rows.filter(func(row: Dictionary) -> bool: return row.family == family)
		var reference := (load(selected[0].path) as PackedScene).instantiate()
		root.add_child(reference)
		var library := shared_library(reference, family)
		var library_path := "res://assets/generated/dwarves/animations/%s.tres" % family
		require(ResourceSaver.save(library, library_path) == OK, "Failed saving "+library_path)
		reference.free()
		var contract: Array[String] = []
		for row: Dictionary in selected:
			var model := (load(row.path) as PackedScene).instantiate()
			root.add_child(model)
			var player := player_of(model)
			var skeleton := skeleton_of(model)
			var bone_names: Array[String] = []
			for bone in range(skeleton.get_bone_count()): bone_names.append(skeleton.get_bone_name(bone))
			bone_names.sort() # glTF import may reorder siblings; tracks resolve by name.
			if contract.is_empty(): contract = bone_names
			require(contract == bone_names, "Incompatible skeleton: "+row.stem)
			player.stop()
			for name in player.get_animation_library_list(): player.remove_animation_library(name)
			player.add_animation_library("", library)
			require(player.get_animation_library("") == library, "Library was duplicated")
			var checks: Dictionary = {}
			for clip: String in CLIPS:
				skeleton.reset_bone_poses()
				player.play(clip); player.seek(0.0, true); player.advance(0.0)
				var first := poses(skeleton)
				var animation := library.get_animation(clip)
				for track in range(animation.get_track_count()):
					var path := animation.track_get_path(track)
					var base: Node = player.get_node(player.root_node)
					var target: Node = base.get_node_or_null(NodePath(path.get_concatenated_names()))
					require(target is Skeleton3D, "Unresolved shared track %s on %s" % [path, row.stem])
					if target is Skeleton3D:
						require((target as Skeleton3D).find_bone(path.get_subname(0)) >= 0, "Unknown shared bone")
				var max_motion := 0.0
				var minimum := INF
				for step in range(13):
					player.seek(animation.length*float(step)/12.0, true); player.advance(0.0)
					max_motion = maxf(max_motion, difference(first, poses(skeleton)))
					minimum = minf(minimum, min_skin_y(model, skeleton))
				player.seek(animation.length, true); player.advance(0.0)
				var seam := difference(first, poses(skeleton))
				require(seam < 0.001, "%s %s does not recover/loop: %f" % [row.stem, clip, seam])
				require(minimum > -0.025, "%s %s below ground: %f" % [row.stem, clip, minimum])
				require(max_motion < 0.0001 if family == "siege" and clip == "idle" else max_motion > 0.001, "%s %s incorrect motion" % [row.stem, clip])
				checks[clip] = {"length":animation.length, "loop":animation.loop_mode != Animation.LOOP_NONE,
					"max_motion":max_motion, "min_skin_y":minimum, "loop_or_recovery_error":seam}
			results.append({"stem":row.stem, "family":family, "shared_library":library_path,
				"bones":skeleton.get_bone_count(), "clips":checks})
			model.free()
		print("DWARF_SHARED_FAMILY_PASS ", family)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL",
		"variants":results, "failures":failures}, "\t"))
	print("DWARF_SHARED_ANIMATIONS_", "PASS" if failures.is_empty() else "FAIL", ": ", results.size(), " variants")
	quit(0 if failures.is_empty() else 1)
