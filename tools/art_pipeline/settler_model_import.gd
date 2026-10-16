@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for library_name: StringName in player.get_animation_library_list():
			var library := player.get_animation_library(library_name)
			for clip: StringName in library.get_animation_list():
				if String(clip) in ["idle", "walk"]:
					library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return scene
