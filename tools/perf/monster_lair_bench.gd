extends Node

## CPU do controlador de covis isolado da IA/render. Usa um mundo real Grande e uma conquista
## no meio da amostra para exercitar déficit/reposição. Não é medição de FPS ou balanceamento.
## godot --headless --path . res://tools/perf/MonsterLairBench.tscn
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := BalanceSeedSet.match_config(0, 100)
	config.map_width = 128
	config.map_height = 72
	var grid := BalanceMatchRunner.setup_match(self, config)
	var samples: Array[float] = []
	for turn in range(2, 102):
		TurnManager.turn_number = turn
		if turn == 42:
			var victim: Dictionary = MonsterEcologySystem.sites[0]
			var coord: Vector2i = victim.lair
			for member in grid.lair_members(coord):
				grid.remove_unit(member)
			grid.destroy_lair(coord)
		var started := Time.get_ticks_usec()
		grid.process_monster_lairs(turn)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		if turn % 10 == 0:
			await get_tree().process_frame
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var result := {"map": "128x72", "seed": config.seed, "rounds": samples.size(),
		"controller_ms": {"min": samples[0], "mean": total / samples.size(), "p95": samples[94], "max": samples[-1]},
		"sites": MonsterEcologySystem.sites_by_tier(), "neutrals": grid.neutral_units().size()}
	var file := FileAccess.open("user://lair_round_bench.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("LAIR_ROUND_BENCH ", JSON.stringify(result))
	await BalanceMatchRunner.teardown_match(self, grid)
	get_tree().quit()
