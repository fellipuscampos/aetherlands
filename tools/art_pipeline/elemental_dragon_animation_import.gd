@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(index) as BaseMaterial3D
			if material: material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip in ["idle", "walk"]:
			if player.has_animation(clip): player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		for clip in ["attack", "spell"]:
			if player.has_animation(clip): player.get_animation(clip).loop_mode = Animation.LOOP_NONE
		if get_source_file().contains("v7_animated") or get_source_file().contains("v8_animated") or get_source_file().contains("v9_animated") or get_source_file().contains("v10_animated"):
			var meshes := scene.find_children("*", "MeshInstance3D", true, false)
			assert(meshes.size()==1)
			_add_heart_pulse(player, meshes[0] as MeshInstance3D)
	return scene

func _add_heart_pulse(player: AnimationPlayer, mesh: MeshInstance3D) -> void:
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	material.resource_local_to_scene = true
	mesh.material_override = material
	var animation_root := player.get_node(player.root_node)
	var path_parts: Array[String] = []
	var cursor: Node = mesh
	while cursor != animation_root:
		assert(cursor != null)
		path_parts.push_front(String(cursor.name))
		cursor=cursor.get_parent()
	var property_path := NodePath("/".join(PackedStringArray(path_parts)) + ":material_override:emission_energy_multiplier")
	for clip in ["idle","walk","attack","spell"]:
		var animation := player.get_animation(clip)
		var scale_track := -1
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			if animation.track_get_type(track)==Animation.TYPE_SCALE_3D and path.get_subname_count()>0 and path.get_subname(0)==&"core":
				scale_track=track
				break
		assert(scale_track>=0)
		var pulse_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(pulse_track,property_path)
		animation.value_track_set_update_mode(pulse_track,Animation.UPDATE_CONTINUOUS)
		for key in animation.track_get_key_count(scale_track):
			var scale: Vector3 = animation.track_get_key_value(scale_track,key)
			animation.track_insert_key(pulse_track,animation.track_get_key_time(scale_track,key),maxf(.35,1+(scale.x-1)*5))
