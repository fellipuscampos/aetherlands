extends SceneTree

const OUTPUT := "res://docs/previews/sacred_vfx/"
const FRAMES := "res://art_source/sacred_vfx_review/frames/"
var failures: Array[String] = []
var main: Node
var player: RefCounted
var mage: Node3D
var allies: Array[Node3D] = []
var center := Vector2i.ZERO
var frame_index := 0
var label: Label
var validation: Array[Dictionary] = []
var write_frames := true

func _initialize() -> void:
	_review.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: print("SACRED_OK: ",message)
	else:
		failures.append(message)
		push_error("SACRED_FAIL: " + message)

func _settle(frames: int = 8) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw

func _review() -> void:
	write_frames = not OS.get_cmdline_user_args().has("--stills-only")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(FRAMES)
	Engine.max_fps = 30
	root.size = Vector2i(1280,900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	await main.hex_grid.generate_map(20,16,2026)
	var civ = load("res://scripts/data/CivilizationData.gd").new()
	civ.race = "human"
	civ.civ_name = "Aurora"
	civ.color = Color("688fb3")
	player = load("res://scripts/core/PlayerData.gd").new(civ)
	player.mana = 400
	for tier in range(2,10): player.v2_research.complete_research("v2_magic_sacred_%d" % tier)
	var manager := root.get_node("GameManager")
	manager.players.assign([player])
	manager.human_player = player
	manager.hex_grid = main.hex_grid
	manager.state = manager.GameState.PLAYING
	root.get_node("TurnManager").turn_number = 20
	# A flat, open patch of the real generated map; same terrain/surface renderer as gameplay.
	for coord in main.hex_grid.tiles:
		var flat: bool = main.hex_grid.get_neighbors(coord).size()==6
		for neighbor in [coord,coord+Vector2i(-1,0),coord+Vector2i(1,0),coord+Vector2i(0,1)]:
			flat = flat and main.hex_grid.tiles.has(neighbor) and main.hex_grid.get_unit_at(neighbor)==null
			if flat: flat = main.hex_grid.get_tile(neighbor).terrain_type in [5,7,8]
		if flat:
			center = coord
			break
	var db = load("res://scripts/data/UnitDatabase.gd")
	mage = main.hex_grid.spawn_unit(center + Vector2i(-1,0),db.create_unit("v2_unit_sacred_cleric"),player)
	for coord in [center,center+Vector2i(1,0),center+Vector2i(0,1)]:
		allies.append(main.hex_grid.spawn_unit(coord,db.create_unit("v2_unit_shieldbearer"),player))
	main.hex_grid.debug_fog_disabled = true
	main.hex_grid.recompute_fog(player)
	main.hex_grid.visible = true
	main._enter_gameplay()
	main.hud.visible = false
	var camera: Camera3D = main.camera_rig.camera
	var focus: Vector3 = main.hex_grid.world_surface_for_coord(center)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	camera.global_position = focus + Vector3(5,7,10)
	camera.look_at(focus + Vector3(.0,.6,.0))
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	label = Label.new()
	canvas.add_child(label)
	label.position = Vector2(32,24)
	label.add_theme_font_override("font",load("res://assets/fonts/pixelify_sans/PixelifySans.ttf"))
	label.add_theme_font_size_override("font_size",30)
	label.add_theme_color_override("font_color",Color("fff1c2"))
	label.add_theme_color_override("font_outline_color",Color("182526"))
	label.add_theme_constant_override("outline_size",8)
	await _settle(20)
	var runtime = load("res://scripts/core/V2MagicRuntime.gd")
	for sample in [["v2_spell_restoring_light","Luz Restauradora", "restoring_light"],["v2_spell_sacred_aegis","Égide Sagrada","sacred_aegis"],["v2_spell_healing_wave","Onda de Cura","healing_wave"],["v2_spell_miracle","Milagre","miracle"]]:
		mage.movement_left = mage.unit_data.movement_points
		mage.magic_cooldowns.clear()
		for ally in allies:
			ally.magic_status.clear()
			ally.refresh_technique_marker()
			ally.hp = ally.unit_data.max_hp - 10
		await _settle(15) # let the existing damage reaction finish before casting
		label.text = "ESCOLA SAGRADA · " + sample[1]
		var before_mana: float = player.mana
		_check(runtime.cast(mage,sample[0],center,main.hex_grid),"Real cast " + sample[0])
		var effect: Node3D = get_nodes_in_group("spell_vfx").back()
		_check(effect.recipients.size()==(3 if sample[2]=="healing_wave" else 1),"Actual recipients " + sample[2])
		_check(effect.ground.size()==(7 if sample[2]=="healing_wave" else 1),"Ground footprint " + sample[2])
		var focus_start: Vector3 = effect.charge.global_position
		var cost: float = before_mana-player.mana
		for frame in 104:
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			if write_frames: screenshot.save_png(FRAMES + "%05d.png" % frame_index)
			frame_index += 1
			if frame==23: screenshot.save_png(OUTPUT + sample[2] + "_charge.png")
			if frame==51: screenshot.save_png(OUTPUT + sample[2] + ".png")
		_check(get_nodes_in_group("spell_vfx").is_empty(),"Transient cleanup " + sample[2])
		validation.append({"spell":sample[0],"mana_spent":cost,"focus":str(focus_start),"hp":allies.map(func(u):return u.hp)})
	_check(allies[0].hp==allies[0].unit_data.max_hp,"Miracle reaches maximum life")
	# Check each race's glowing staff with the same shared effect and actual native rig.
	for race in ["elf","orc","dwarf"]:
		main.hex_grid.remove_unit(mage)
		await _settle()
		player.civ.race = race
		mage = main.hex_grid.spawn_unit(center+Vector2i(-1,0),db.create_unit("v2_unit_sacred_cleric"),player)
		allies[0].hp -= 8
		await _settle(15)
		label.text = "ESCOLA SAGRADA · " + race
		_check(runtime.cast(mage,"v2_spell_restoring_light",center,main.hex_grid),"Shared effect on " + race)
		await create_timer(.75).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + "focus_" + race + ".png")
		await create_timer(2.9).timeout
	# Same pipeline for the great sacred manifestation and its moving core.
	main.hex_grid.remove_unit(mage)
	await _settle()
	mage = main.hex_grid.spawn_unit(center+Vector2i(-1,0),db.create_unit("v2_manifestation_seraph"),player)
	allies[0].hp -= 8
	await _settle(15)
	label.text = "ESCOLA SAGRADA · Serafim"
	_check(runtime.cast(mage,"v2_spell_restoring_light",center,main.hex_grid),"Shared effect on Seraph")
	await create_timer(.75).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "focus_seraph.png")
	await create_timer(2.9).timeout
	# Native night / reduced-motion review, using in-memory settings only.
	var settings := root.get_node("Settings")
	var original_motion: bool = settings.reduced_motion
	var original_lighting: bool = settings.creature_lighting_enabled
	settings.reduced_motion = true
	settings.creature_lighting_enabled = false
	main.day_night.debug_jump_to(true)
	label.text = "ESCOLA SAGRADA · movimento reduzido / noite"
	mage.movement_left = mage.unit_data.movement_points
	allies[0].hp -= 6
	await _settle(15)
	_check(runtime.cast(mage,"v2_spell_healing_wave",center,main.hex_grid),"Native reduced motion / night")
	await create_timer(1.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "reduced_motion_night.png")
	await create_timer(1.7).timeout
	settings.reduced_motion = original_motion
	settings.creature_lighting_enabled = original_lighting
	FileAccess.open(OUTPUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"casts":validation,"video_frames":frame_index},"\t"))
	root.get_node("SelectionManager").reset()
	player.release_relations()
	manager.human_player = null
	manager.players.clear()
	manager.hex_grid = null
	main.queue_free()
	canvas.queue_free()
	await _settle()
	quit(0 if failures.is_empty() else 1)
