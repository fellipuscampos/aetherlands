@tool
extends EditorScenePostImport

## glTF has no loop flag. Set the intended clip behavior when Godot imports it.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for name in player.get_animation_list():
			var animation := player.get_animation(name)
			animation.loop_mode = Animation.LOOP_LINEAR if name in ["Wyvern_Idle", "Wyvern_Walk"] else Animation.LOOP_NONE
	return scene
