extends SceneTree

const OUTPUT := "res://docs/previews/natural_vfx/"
const KINDS := {"sacred":"v2_unit_sacred_cleric","infernal":"v2_unit_infernal_warlock","necromancy":"v2_unit_necromancer","druidism":"v2_unit_druid","arcanism":"v2_unit_arcanist","elementalism":"v2_unit_elementalist"}
const NAMES := {"sacred":"Sagrada","infernal":"Infernal","necromancy":"Necromancia","druidism":"Druidismo","arcanism":"Arcanismo","elementalism":"Elementalismo"}
var failures: Array[String] = []
var casts: Array[Dictionary] = []
var main: Node
var player: RefCounted
var rival: RefCounted
var center := Vector2i.ZERO
var frame_index := 0
var record := false
var label: Label

func _initialize() -> void: _review.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: print("SCHOOL_OK: ",message)
	else:
		failures.append(message)
		push_error("SCHOOL_FAIL: "+message)

func _settle(count: int = 8) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("res://art_source/natural_vfx_review/frames/")
	Engine.max_fps = 30
	root.size = Vector2i(1120,840)
	record = OS.get_cmdline_user_args().has("--record")
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	await main.hex_grid.generate_map(24,20,2026)
	var civ_script = load("res://scripts/data/CivilizationData.gd")
	var player_script = load("res://scripts/core/PlayerData.gd")
	var civ = civ_script.new()
	civ.race = "human"
	civ.civ_name = "Aurora"
	civ.color = Color("688fb3")
	player = player_script.new(civ)
	var enemy_civ = civ_script.new()
	enemy_civ.race = "orc"
	enemy_civ.civ_name = "Rival"
	rival = player_script.new(enemy_civ)
	var manager := root.get_node("GameManager")
	manager.players.assign([player,rival])
	manager.human_player = player
	manager.rival_players.assign([rival])
	manager.hex_grid = main.hex_grid
	manager.state = manager.GameState.PLAYING
	load("res://scripts/core/Diplomacy.gd").declare_war(player,rival,"VFX",true)
	player.mana = 2000
	root.get_node("TurnManager").turn_number = 20
	for school in KINDS:
		for tier in range(2,10): player.v2_research.complete_research("v2_magic_%s_%d" % [school,tier])
	var best := INF
	for coord in main.hex_grid.tiles:
		var usable: bool = main.hex_grid.get_neighbors(coord).size()==6
		for cell in [coord,coord+Vector2i(-1,0),coord+Vector2i(1,0),coord+Vector2i(0,1),coord+Vector2i(0,-1)]:
			usable = usable and main.hex_grid.tiles.has(cell) and main.hex_grid.get_unit_at(cell)==null and main.hex_grid.get_city_at(cell)==null and not main.hex_grid.lairs_by_coord.has(cell)
			if usable: usable = main.hex_grid.get_tile(cell).terrain_type in [5,7,8]
		var distance := float(coord.x*coord.x+coord.y*coord.y)
		if usable and distance<best:
			center = coord
			best = distance
	_check(best<INF,"An open patch of the real map")
	main.hex_grid.debug_fog_disabled = true
	main.hex_grid.recompute_fog(player)
	main.hex_grid.visible = true
	main._enter_gameplay()
	main.hud.visible = false
	var camera: Camera3D = main.camera_rig.camera
	var focus: Vector3 = main.hex_grid.world_surface_for_coord(center)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.global_position = focus+Vector3(5,7,10)
	camera.look_at(focus+Vector3(0,.6,0))
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	label = Label.new()
	canvas.add_child(label)
	label.position = Vector2(24,22)
	label.add_theme_font_override("font",load("res://assets/fonts/pixelify_sans/PixelifySans.ttf"))
	label.add_theme_font_size_override("font_size",28)
	label.add_theme_color_override("font_color",Color("fff1c2"))
	label.add_theme_color_override("font_outline_color",Color("182526"))
	label.add_theme_constant_override("outline_size",8)
	var db = load("res://scripts/data/UnitDatabase.gd")
	var spells = load("res://scripts/data/V2SpellDatabase.gd")
	var runtime = load("res://scripts/core/V2MagicRuntime.gd")
	var registry = load("res://scripts/vfx/SpellVFX.gd")
	var terrain = load("res://scripts/core/V2TerrainRuntime.gd")
	var schools: Array = registry.SCHOOLS.keys()
	var validation_name := "validation.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--school="):
			var only := arg.trim_prefix("--school=")
			schools = [only]
			frame_index = registry.SCHOOLS.keys().find(only)*52
			validation_name = "validation_"+only+".json"
	if OS.get_cmdline_user_args().has("--ambient"): schools = []
	for school in schools:
		for spell in spells.for_school(school):
			for owner in [player,rival]:
				for unit in owner.units.duplicate(): main.hex_grid.remove_unit(unit)
			for coord in main.hex_grid.v2_terrain_modifications.keys(): terrain.remove(main.hex_grid,coord)
			main.hex_grid.v2_environmental_zones.clear()
			main.hex_grid.refresh_all_environmental_zone_markers()
			main.hex_grid.v2_portal_pairs.clear()
			main.hex_grid.v2_portal_endpoint_index.clear()
			main.hex_grid.v2_portal_owner_school_index.clear()
			main.hex_grid.refresh_v2_portal_markers()
			await _settle()
			var mage: Node3D = main.hex_grid.spawn_unit(center+Vector2i(-1,0),db.create_unit(KINDS[school]),player)
			if school=="sacred":
				for cell in [center,center+Vector2i(1,0),center+Vector2i(0,1)]:
					var ally: Node3D = main.hex_grid.spawn_unit(cell,db.create_unit("warrior"),player)
					ally.hp = 3
			elif school=="infernal":
				for cell in [center,center+Vector2i(1,0),center+Vector2i(0,1)]:
					var enemy: Node3D = main.hex_grid.spawn_unit(cell,db.create_unit("v2_unit_shieldbearer"),rival)
					if spell.id=="v2_spell_devouring_fire": enemy.hp = 5
			elif school=="necromancy" and not spell.is_summon():
				var host: Node3D = main.hex_grid.spawn_unit(center,db.create_unit("v2_unit_skeleton_host"),player)
				if spell.is_heal(): host.hp -= 7
			elif spell.silences_spellcasting:
				main.hex_grid.spawn_unit(center,db.create_unit(KINDS.infernal),rival)
			elif spell.dispel_at_tile:
				var protected: Node3D = main.hex_grid.spawn_unit(center,db.create_unit("warrior"),rival)
				protected.magic_status["v2_spell_sacred_aegis"] = 22
				protected.refresh_technique_marker()
			elif spell.remove_terrain_modification:
				terrain.apply(main.hex_grid,center,"v2_terrain_dense_grove")
			elif school=="elementalism":
				for cell in [center,center+Vector2i(1,0),center+Vector2i(0,1)]: main.hex_grid.spawn_unit(cell,db.create_unit("warrior"),rival)
			label.text = "%s · %s" % [NAMES[school],spell.display_name]
			await _settle(15)
			var before_mana: float = player.mana
			var cast_ok: bool = runtime.cast(mage,spell.id,center,main.hex_grid)
			_check(cast_ok,"Real cast "+spell.id)
			if not cast_ok:
				push_error(runtime.tile_reason(mage,spell,center,main.hex_grid) if spell.targets_tile() else runtime.unavailable_reason(mage,spell.id,main.hex_grid))
				continue
			_check(player.mana==before_mana-spell.mana_cost,"Unchanged cost "+spell.id)
			_check(not get_nodes_in_group("spell_vfx").is_empty(),"Presentation created "+spell.id)
			if school=="sacred":
				var effect: Node3D = get_nodes_in_group("spell_vfx")[0]
				_check(not effect.recipients.is_empty(),"Sacred recipients "+spell.id)
			for frame in 104:
				await process_frame
				await RenderingServer.frame_post_draw
				var charge_frame := 3 if spell.teleport_caster else 23
				var impact_frame := 12 if spell.teleport_caster else 51
				var record_frame: bool = record and spell.id==spells.for_school(school).back().id and frame%2==0
				if frame in [charge_frame,impact_frame] or record_frame:
					var screenshot := root.get_texture().get_image()
					if frame==charge_frame: screenshot.save_png(OUTPUT+spell.id+"_charge.png")
					if frame==impact_frame: screenshot.save_png(OUTPUT+spell.id+".png")
					if record_frame:
						screenshot.save_png("res://art_source/natural_vfx_review/frames/%05d.png" % frame_index)
						frame_index += 1
			_check(get_nodes_in_group("spell_vfx").is_empty(),"Transient cleanup "+spell.id)
			if school=="elementalism" and spell.id in ["v2_spell_lightning_storm","v2_spell_elemental_cataclysm"]:
				var summary: Dictionary = load("res://scripts/core/V2EnvironmentalZoneSystem.gd").process_global_round(main.hex_grid)
				_check(int(summary.damaged_units)>0,"Actual environmental damage "+spell.id)
				for frame in 7: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT+spell.id+"_tick.png")
				if record and spell.id==spells.for_school(school).back().id:
					for frame in 20:
						await process_frame
						await RenderingServer.frame_post_draw
						if frame%2==0:
							root.get_texture().get_image().save_png("res://art_source/natural_vfx_review/frames/%05d.png" % frame_index)
							frame_index += 1
				await create_timer(1.1).timeout
			casts.append({"spell":spell.id,"school":school,"cost":spell.mana_cost})
	if not schools.is_empty():
		FileAccess.open(OUTPUT+validation_name,FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"casts":casts,"video_frames":frame_index},"\t"))
	if OS.get_cmdline_user_args().has("--ambient") or schools.size()==6:
		main.hex_grid.v2_environmental_zones.clear()
		main.hex_grid.refresh_all_environmental_zone_markers()
		for owner in [player,rival]:
			for unit in owner.units.duplicate(): main.hex_grid.remove_unit(unit)
		await _settle()
		for cell in [center,center+Vector2i(1,0),center+Vector2i(-1,0)]: main.hex_grid.spawn_unit(cell,db.create_unit(KINDS.elementalism),player)
		label.text = "Chuva - nuvens acima das unidades"
		main.weather.set_enabled(true)
		main.weather.start_match()
		main.weather.force_rain(30)
		main.weather.advance(8)
		await _settle(80)
		_check(not main.weather.rain_clouds.banks.is_empty(),"Ordinary rain forms overhead clouds")
		root.get_texture().get_image().save_png(OUTPUT+"weather_rain.png")
		main.weather.stop()
		_check(main.weather.rain_clouds.banks.is_empty(),"Stopping rain clears clouds")
	root.get_node("SelectionManager").reset()
	for owner in [player,rival]: owner.release_relations()
	manager.human_player = null
	manager.players.clear()
	manager.rival_players.clear()
	manager.hex_grid = null
	main.queue_free()
	canvas.queue_free()
	await _settle()
	quit(0 if failures.is_empty() else 1)
