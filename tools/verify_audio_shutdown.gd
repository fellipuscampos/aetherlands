extends SceneTree

## Regressão executada em processo separado: sair durante som de vitória.
## godot --headless --verbose --path . -s tools/verify_audio_shutdown.gd
## Deve retornar 0 sem ObjectDB/Resource still in use no log.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := root.get_node("AudioManager")
	audio.play_sfx("victory")
	await process_frame
	paused = true
	audio.request_quit()
