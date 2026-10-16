@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
    for node in scene.find_children("*", "AnimationPlayer", true, false):
        var player := node as AnimationPlayer
        for name in player.get_animation_list():
            var loops := String(name).ends_with("_Idle") or String(name).ends_with("_Walk")
            player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
    return scene
