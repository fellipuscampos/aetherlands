extends SceneTree

const OUTPUT := "res://docs/previews/debug_menu/"
var main: Node
var player: RefCounted
var failures: Array[String] = []

func _initialize() -> void: _review.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: print("DEBUG_OK: ",message)
	else:
		failures.append(message)
		push_error("DEBUG_FAIL: "+message)

func _settle() -> void:
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	await _settle()
	var hud: Control = main.hud
	var panel: Rect2 = hud.debug_panel.get_global_rect()
	var scroll: ScrollContainer = hud._debug_scroll
	_check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(panel),"Panel fits "+name)
	_check(panel.encloses(hud.debug_close_button.get_global_rect()),"Close remains accessible "+name)
	_check(panel.encloses(hud._debug_animation_buttons.idle.get_global_rect()),"Animation footer fits "+name)
	_check(scroll.get_child(0).get_combined_minimum_size().x<=scroll.size.x+1,"No horizontal overflow "+name)
	_check(scroll.size.y>=100,"Useful scroll area "+name)
	root.get_texture().get_image().save_png(OUTPUT+name+".png")

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	FileAccess.open(OUTPUT+".gdignore",FileAccess.WRITE).close()
	root.size = Vector2i(1600,900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	await main.hex_grid.generate_map(24,20,2026)
	var civ = load("res://scripts/data/CivilizationData.gd").new()
	civ.race = "human"
	civ.civ_name = "Aurora"
	civ.color = Color("688fb3")
	player = load("res://scripts/core/PlayerData.gd").new(civ)
	var manager := root.get_node("GameManager")
	manager.players.assign([player])
	manager.rival_players.clear()
	manager.human_player = player
	manager.hex_grid = main.hex_grid
	manager.state = manager.GameState.PLAYING
	main.hex_grid.debug_fog_disabled = true
	var debug = load("res://scripts/core/DebugSummon.gd")
	var origin := Vector2i.ZERO
	for coord in main.hex_grid.tiles:
		if debug.is_free_tile(main.hex_grid,coord):
			origin = coord
			break
	main._enter_gameplay()
	main.hex_grid.visible = true
	main.hud.visible = true
	main.hex_grid.recompute_fog(player)
	var hud: Control = main.hud
	hud._on_debug_pressed()
	for kind in debug.mage_kinds():
		var before: int = player.units.size()
		hud._debug_mage_buttons[kind].pressed.emit()
		_check(player.units.size()==before+1,"Button spawns "+kind)
		var unit: Node3D = player.units.back()
		_check(load("res://scripts/core/V2MagicRuntime.gd").spells_for_unit(unit).size()==4,"Four spells ready "+kind)
		_check(unit._anim_player!=null,"Real animated model "+kind)
	await _settle()
	_check(hud.debug_panel.visible,"Summoning keeps the tools open")
	for id in ["mages","manifestations","ambience","match"]:
		hud._debug_menu.tabs[id].pressed.emit()
		await _capture(id+"_1600x900")
	var settings := root.get_node("Settings")
	for scenario in [[1280,720,100],[1280,720,150],[960,720,100]]:
		root.size = Vector2i(scenario[0],scenario[1])
		settings.ui_scale_percent = scenario[2]
		settings.accessibility_changed.emit()
		for id in ["mages","ambience"]:
			hud._debug_menu.tabs[id].pressed.emit()
			await _capture("%s_%dx%d_%d" % [id,scenario[0],scenario[1],scenario[2]])
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	var selection := root.get_node("SelectionManager")
	var mage: Node3D = player.units.back()
	selection.select_unit(mage)
	var spell = load("res://scripts/data/V2SpellDatabase.gd").get_spell("v2_spell_dense_mist")
	var runtime = load("res://scripts/core/V2MagicRuntime.gd")
	var targets: Array = runtime.target_tiles(mage,spell,main.hex_grid)
	_check(not targets.is_empty(),"Spawned mage has real cast targets")
	if not targets.is_empty():
		_check(runtime.cast(mage,spell.id,targets[0],main.hex_grid),"Spawned mage casts through real VFX path")
		_check(not get_nodes_in_group("spell_vfx").is_empty(),"VFX presentation created")
		mage.magic_cooldowns[spell.id] = 999
		mage.movement_left = 0
		hud._debug_renew_magic_button.pressed.emit()
		_check(mage.magic_cooldowns.is_empty() and mage.movement_left>0,"Repeated casts need no turn advance")
	FileAccess.open(OUTPUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures},"\t"))
	selection.reset()
	player.release_relations()
	manager.players.clear()
	manager.human_player = null
	manager.hex_grid = null
	main.queue_free()
	await _settle()
	quit(0 if failures.is_empty() else 1)
