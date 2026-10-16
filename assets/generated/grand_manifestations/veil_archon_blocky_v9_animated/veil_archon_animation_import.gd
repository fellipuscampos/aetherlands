@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for clip in ["Idle", "Walk", "Attack", "Spell"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE
		# Unit creates its own controller; avoid two players driving the same bones.
		player.autoplay = ""
	return scene
