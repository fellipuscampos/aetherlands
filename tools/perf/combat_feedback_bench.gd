extends Node

## CPU of the new presentation bookkeeping only, not the existing models/VFX/GPU.
## Forced headless path; real headless matches bypass all these batches.
const Feedback := preload("res://scripts/vfx/CombatFeedback.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var grid := HexGrid.new()
	add_child(grid)
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var owner := PlayerData.new(CivilizationData.new())
	var source := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("v2_unit_warrior"), owner)
	source.play_attack_visual(null)
	Feedback.force_in_tests = true
	var results := {}
	for count in [3, 21]:
		var samples: Array[float] = []
		for i in 1000:
			var started := Time.get_ticks_usec()
			var batch := Feedback.begin_attack(source, grid)
			for j in count: Feedback.defer_call(source, &"set_meta", ["bench", j])
			Feedback.finish(batch)
			batch.flush()
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
			batch.free() # teardown outside measurement; do not accumulate queued nodes between samples
		samples.sort()
		var total := 0.0
		for sample in samples: total += sample
		results[str(count)] = {"callbacks": count, "samples": samples.size(), "mean_ms": total / samples.size(), "p95_ms": samples[949], "max_ms": samples[-1]}
	Feedback.force_in_tests = false
	owner.release_relations()
	grid.queue_free()
	await get_tree().process_frame
	var output := "user://combat_feedback_bench.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.substr(6)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print("COMBAT_FEEDBACK_BENCH ", JSON.stringify(results))
	get_tree().quit()
