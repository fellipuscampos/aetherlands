extends Node3D

## The reusable construction scene also works when instantiated outside HexGrid.
func _ready() -> void:
	for node: Node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player.has_animation("construction"):
			player.get_animation("construction").loop_mode = Animation.LOOP_LINEAR
			player.play("construction")
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
