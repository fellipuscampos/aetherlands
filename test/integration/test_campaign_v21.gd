extends GutTest

## Execução isolada: -gconfig= -gtest=res://test/integration/test_campaign_v21.gd
## Partidas naturais, sem conceder pesquisas/recursos. Não mede duração humana.
var original := {}
var outcome := ""

func record_outcome(winner: PlayerData, kind: String):
	outcome = "%s:%s" % [winner.civ.race if winner else "none", kind]

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "victory_rules_version", "debug_mode"]:
		original[key] = GameManager.get(key)
	original["turn"] = TurnManager.turn_number
	original["events"] = WorldEventManager.active_events.duplicate()
	original["event_id"] = WorldEventManager._next_event_id
	GameManager.players = []
	GameManager.rival_players = []
	GameManager.human_player = null
	GameManager.hex_grid = null
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	WorldEventManager.active_events.clear()
	EventBus.victory_achieved.connect(record_outcome)

func after_each():
	EventBus.victory_achieved.disconnect(record_outcome)
	for key in original:
		if not key in ["turn", "events", "event_id"]:
			GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	WorldEventManager.active_events.assign(original.events)
	WorldEventManager._next_event_id = original.event_id

func test_real_map_campaign():
	await run_campaign(4242, 320, 84, 100)

func test_distinct_strategies_to_campaign_end():
	var isolated_seed := OS.get_environment("AETHERLANDS_CAMPAIGN_SEED").to_int()
	if isolated_seed > 0:
		await run_campaign(isolated_seed, 61, 61, 240)
		return
	for seed_value in [1709, 2718, 3141]:
		await run_campaign(seed_value, 61, 61, 240)

func run_campaign(seed_value: int, width: int, height: int, turns: int):
	outcome = "unfinished"
	var grid := HexGrid.new()
	add_child(grid)
	GameManager.map_width = width
	GameManager.map_height = height
	GameManager.rival_count = 3
	GameManager.human_race = "human"
	grid.generate_map(width, height, seed_value)
	GameManager.start_new_game(grid)
	var start := Time.get_ticks_msec()
	var worst_turn := 0
	var first_war := -1
	var captures := 0
	for step in range(turns):
		if GameManager.state == GameManager.GameState.GAME_OVER:
			break
		var tick := Time.get_ticks_msec()
		var player := GameManager.human_player
		var other := GameManager.rival_players[0]
		RivalAI.decide_production(player, grid, other)
		RivalAI.decide_research(player)
		for opponent in GameManager.rival_players:
			RivalAI.decide_war(player, grid, opponent)
			RivalAI.decide_campaign(player, grid, opponent)
			RivalAI.decide_peace(player, opponent)
			RivalAI.decide_trade(player, grid, opponent)
		StrategicAI.cast_spells(player, grid)
		RivalAI.take_turn(player, grid, other)
		TurnManager.end_turn()
		for p in GameManager.players:
			assert_true(is_finite(p.gold) and p.gold >= 0 and is_finite(p.mana) and p.mana >= 0, "Economia válida")
			if first_war == -1 and not p.enemies.is_empty():
				first_war = TurnManager.turn_number
		worst_turn = maxi(worst_turn, Time.get_ticks_msec() - tick)
		# Libera queue_free e evita acumular todos os exércitos/mapas no harness.
		await get_tree().process_frame
		if step % 20 == 19:
			print("[campaign-v21] seed=%d turn=%d elapsed_ms=%d players=%s" % [seed_value, TurnManager.turn_number, Time.get_ticks_msec() - start, snapshot()])
	for p in GameManager.players:
		captures += p.cities.filter(func(c): return c.captured_developed).size()
	print("[campaign-v21-final] seed=%d map=%dx%d turn=%d ended=%s first_war=%d developed_captures=%d elapsed_ms=%d worst_turn_ms=%d players=%s" % [seed_value, width, height, TurnManager.turn_number, GameManager.state == GameManager.GameState.GAME_OVER, first_war, captures, Time.get_ticks_msec() - start, worst_turn, snapshot()])
	print("[campaign-v21-outcome] seed=%d result=%s" % [seed_value, outcome])
	for p in GameManager.players:
		print("[campaign-v21-preparations] race=%s missing=%s" % [p.civ.race, VictoryCampaign.preparations(p, grid)])
	GameManager.end_match()
	await AudioManager.drain_audio()
	grid.free()
	GameManager.hex_grid = null
	await get_tree().process_frame

func snapshot() -> String:
	var result := []
	for p in GameManager.players:
		result.append({"race": p.civ.race, "strategy": StrategicAI.strategy(p), "cities": p.cities.size(), "units": p.units.size(), "tech": p.researched_techs.size(), "magic": p.researched_magic.size(), "rituals": p.completed_rituals.size(), "nodes": VictoryConditions.arcane_nodes_controlled(p, GameManager.hex_grid), "mana": int(p.mana), "gold": int(p.gold)})
	return JSON.stringify(result)
