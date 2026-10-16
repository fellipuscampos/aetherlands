extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var scene = (load("res://_dwarf_troop_models_review.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var results: Array = []
	for family in range(6):
		scene._select(family)
		await process_frame
		require(scene.players.size() == 4, "Review must have four animation players")
		for player: AnimationPlayer in scene.players:
			require(player.get_animation_library("") != null, "Review lost native library")
		for clip: String in ["idle", "walk", "attack"]:
			scene._play(clip)
			for player: AnimationPlayer in scene.players:
				var animation := player.get_animation(clip)
				require(animation.loop_mode == (Animation.LOOP_NONE if clip == "attack" else Animation.LOOP_LINEAR), "Incorrect loop mode")
				player.seek(animation.length*0.45, true)
				player.advance(0.0)
				require(player.current_animation == clip, "Review did not play "+clip)
		scene.repeat_attack = false
		scene._play("attack")
		scene.players[0].advance(scene.players[0].current_animation_length+0.01)
		await process_frame
		await process_frame
		require(scene.selected_animation == "idle", "Attack did not return to idle")
		scene.paused = true
		scene._play("walk")
		for player: AnimationPlayer in scene.players: require(player.speed_scale == 0.0, "Pause did not stop playback")
		scene.paused = false
		scene.show_human = true
		scene._display()
		await process_frame
		require(scene.models.get_child_count() == 10, "Human comparison must show five models and labels")
		scene.show_human = false
		results.append({"family":scene.FAMILIES[family], "variants":4, "native_libraries":true,
			"idle_walk_attack":true, "pause":true, "attack_recovery":true, "human_reference":true})
	var output := OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL",
		"families":results, "failures":failures}, "\t"))
	scene.queue_free()
	print("DWARF_ANIMATION_PROJECT_", "PASS" if failures.is_empty() else "FAIL", ": 24 variants, native skill libraries")
	quit(0 if failures.is_empty() else 1)
