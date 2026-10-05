@tool
extends EditorScenePostImport

## glTF has no standard loop flag. Preserve the intended action behavior on import.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			animation.loop_mode = Animation.LOOP_LINEAR if clip in ["ManaDevourer_Idle", "ManaDevourer_Walk"] else Animation.LOOP_NONE
	return scene
