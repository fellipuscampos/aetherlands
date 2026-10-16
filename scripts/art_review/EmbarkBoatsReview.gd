extends Node3D

var clip := "idle"

func _ready() -> void:
	if "--walk" in OS.get_cmdline_user_args():
		clip = "walk"
	play_clip()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		clip = "walk" if clip == "idle" else "idle"
		play_clip()

func play_clip() -> void:
	for node: Node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player.has_animation(clip):
			player.play(clip)
