extends Node

## Actual autonomous orders + CombatResolver, not a replacement combat formula.
## godot --headless --path . res://tools/balance/BoundManifestationProbe.tscn -- --out=user://bound_manifestations.json
## Controlled arena: flat terrain, no veterancy, military techniques or city fire.
## Reassigns the attack to a surviving opponent when its previous target dies.
var action_us: Array[int] = []
var orders: GDScript = preload("res://scripts/core/V2ManifestationOrders.gd")

func _ready():
	# Optional isolated pre-tuning controller; never replace live project files
	# while another agent/editor may be using them.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--orders-source="):
			var baseline := GDScript.new()
			baseline.source_code = FileAccess.get_file_as_string(arg.substr(16)).replace("class_name V2ManifestationOrders","")
			assert(baseline.reload() == OK,"baseline controller must compile")
			orders = baseline
	run.call_deferred()

func make_grid(width: int, height: int) -> HexGrid:
	var grid := HexGrid.new()
	add_child(grid)
	for q in range(-width/2,width/2):
		for r in range(-height/2,height/2):
			var coord := Vector2i(q,r)
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	return grid

func player() -> PlayerData:
	return PlayerData.new(CivilizationData.new())

func arena(kind: String, soldier_kind: String, count: int) -> Dictionary:
	var grid := make_grid(32,24)
	var own := player()
	var foe := player()
	GameManager.players = [own,foe]
	GameManager.human_player = own
	GameManager.rival_players = [foe]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 40
	Diplomacy.declare_war(own,foe)
	var entity := grid.spawn_unit(Vector2i.ZERO,UnitDatabase.create_unit(kind),own)
	for tier in range(2,10): own.v2_research.complete_research("v2_magic_%s_%d" % [entity.unit_data.v2_magic_school,tier])
	entity.manifestation_ready_turn = 40
	own.mana = 80.0 # host creation consumes the same treasury as mortal necromancy.
	var original_hp := entity.hp
	var soldiers: Array[Unit] = []
	var starts := [Vector2i(2,0),Vector2i(0,2),Vector2i(-2,2)]
	for index in count: soldiers.append(grid.spawn_unit(starts[index],UnitDatabase.create_unit(soldier_kind),foe))
	var rounds := 0
	var total_enemy_hp := 0.0
	for soldier in soldiers: total_enemy_hp += soldier.hp
	var alive := count
	while rounds < 20 and entity.hp > 0 and grid.get_unit_at(entity.coord) == entity and alive > 0:
		rounds += 1
		TurnManager.turn_number += 1
		for owned in own.units: owned.movement_left = owned.unit_data.movement_points
		for soldier in soldiers:
			if soldier.hp > 0 and grid.get_unit_at(soldier.coord) == soldier:
				orders.assign(entity,"attack_unit",soldier.coord,grid)
				break
		var visible := grid.compute_visible_tiles(own)
		var started := Time.get_ticks_usec()
		orders.act(entity,grid,visible)
		action_us.append(Time.get_ticks_usec()-started)
		# Existing hosts use normal troop AI here; newborn hosts have zero movement.
		for host in own.units.duplicate():
			if host != entity and host.movement_left > 0: RivalAI.act_for_unit(host,grid,own,foe,visible)
		# The opposing force concentrates fire, without advantageous retreat or skills.
		for soldier in soldiers:
			if soldier.hp <= 0 or grid.get_unit_at(soldier.coord) != soldier or entity.hp <= 0: continue
			soldier.movement_left = soldier.unit_data.movement_points
			if HexMetrics.axial_distance(soldier.coord,entity.coord) > soldier.unit_data.attack_range: RivalAI.move_unit_toward(soldier,grid,entity.coord)
			if soldier.movement_left > 0 and HexMetrics.axial_distance(soldier.coord,entity.coord) <= soldier.unit_data.attack_range and CombatResolver.can_attack_unit(soldier,entity,grid): CombatResolver.resolve(soldier,entity,grid)
		V2EnvironmentalZoneSystem.process_global_round(grid,true)
		alive = 0
		for soldier in soldiers:
			if soldier.hp > 0 and grid.get_unit_at(soldier.coord) == soldier: alive += 1
	var remaining := 0.0
	for soldier in soldiers: remaining += maxf(0,soldier.hp)
	var row := {"entity":kind,"enemy":soldier_kind,"count":count,"rounds":rounds,"entity_hp":maxf(0,entity.hp),"initial_hp":original_hp,"survivors":alive,"enemy_hp_lost":total_enemy_hp-remaining,"mana_spent":80-own.mana,"hosts":own.units.size()-int(entity in own.units),"limit_reached":rounds==20}
	V2AITacticalAI.clear_views()
	own.release_relations()
	foe.release_relations()
	grid.queue_free()
	return row

func stress() -> Dictionary:
	var grid := make_grid(128,72)
	var own := player()
	GameManager.players = [own]
	GameManager.human_player = own
	GameManager.rival_players = []
	GameManager.hex_grid = grid
	grid.found_city(Vector2i.ZERO,own,"Guard",true)
	var entities: Array[Unit] = []
	var index := 0
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		var entity := grid.spawn_unit(Vector2i(index,1),UnitDatabase.create_unit(kind),own)
		own.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL,entity.unit_data.v2_magic_school)
		entities.append(entity)
		index += 1
	var batches: Array[int] = []
	var first_round_ms := 0.0
	for round_index in 220:
		TurnManager.turn_number += 1
		for entity in entities: entity.movement_left = entity.unit_data.movement_points
		var started := Time.get_ticks_usec()
		for item in GameManager._build_manifestation_turn_items(): orders.act(item.unit,grid,item.visible)
		var elapsed := Time.get_ticks_usec()-started
		if round_index == 0: first_round_ms = elapsed/1000.0
		if round_index >= 20: batches.append(elapsed)
	batches.sort()
	var result := {"tiles":grid.tiles.size(),"entities":entities.size(),"rounds":batches.size(),"warmup_rounds":20,"first_round_ms":first_round_ms,"owner_visibility_scans_per_round":1,"median_ms":batches[batches.size()/2]/1000.0,"p95_ms":batches[int(ceil(batches.size()*.95))-1]/1000.0,"max_ms":batches[-1]/1000.0,"scenario":"idle protection, full repertoires; includes owner visibility and the six actions"}
	own.release_relations()
	grid.queue_free()
	return result

func run():
	var rows := []
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		for scenario in [["v2_unit_elite_marksman",1],["v2_unit_elite_marksman",3],["v2_legendary_blade_hero",1],["v2_unit_guardian",3],["v2_legendary_blade_hero",2]]:
			rows.append(arena(kind,scenario[0],scenario[1]))
			await get_tree().process_frame
	var performance := stress()
	action_us.sort()
	performance["combat_action_count"] = action_us.size()
	performance["combat_action_median_ms"] = action_us[action_us.size()/2]/1000.0
	performance["combat_action_p95_ms"] = action_us[int(action_us.size()*.95)]/1000.0
	var path := "user://bound_manifestations.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): path = arg.substr(6)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"profiles":V2ManifestationBalance.PROFILES,"arenas":rows,"performance":performance,"method":"Real orders, spells, HP costs and cooldowns; flat focus-fire arena without starting veterancy or military techniques. Earned veterancy and its healing remain. Existing hosts use normal troop AI. No city fire, healing between rounds or optimized formation. Not a full match balance verdict."},"  "))
	file.close()
	print("BOUND_MANIFESTATION_PROBE ",JSON.stringify(performance)," ",ProjectSettings.globalize_path(path))
	GameManager.players = []
	GameManager.human_player = null
	GameManager.rival_players = []
	GameManager.hex_grid = null
	V2AITacticalAI.clear_views()
	V2MagicRuntime._summon_data_cache.clear()
	await get_tree().process_frame
	get_tree().quit()
