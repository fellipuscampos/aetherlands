@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for node: Node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip: String in ["idle", "walk", "spell"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip == "spell" else Animation.LOOP_LINEAR
	return scene
