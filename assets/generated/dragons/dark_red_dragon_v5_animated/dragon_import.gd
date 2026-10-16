@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material: material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for node: AnimationPlayer in scene.find_children("*","AnimationPlayer",true,false):
		for clip in node.get_animation_list():
			var animation := node.get_animation(clip)
			animation.loop_mode=Animation.LOOP_NONE if "Attack" in clip else Animation.LOOP_LINEAR
	return scene
