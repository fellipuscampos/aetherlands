@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material:
				material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return scene
