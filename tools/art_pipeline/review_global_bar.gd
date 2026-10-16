extends SceneTree

## Live Main/HUD review with a disposable map and real economy/research state.
const OUTPUT := "res://docs/previews/global_bar/"
var failures: Array[String] = []
var main: Node
var bar: Control
var player: RefCounted
var samples: Array[Dictionary] = []

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("PIXEL_GLOBAL_BAR_OK: ", message)
	else:
		failures.append(message)
		push_error("PIXEL_GLOBAL_BAR_FAIL: " + message)

func _settle() -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	main.hud.ui_shell.toast_presenter.dismiss_all()
	await _settle()
	_check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, "Screenshot: " + name)

func _action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()

func _check_layout(name: String) -> void:
	await _settle()
	_check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(bar.get_global_rect()), "Bar fits " + name)
	_check(bar.size.y <= 92, "Bar preserves map space at " + name)
	_check(bar._margin.get_global_rect().position.x + 12 <= bar._row.get_global_rect().position.x, "Content retains horizontal padding")
	for key in ["gold","supply","mana","knowledge"]:
		var item := bar._items[key] as Control
		_check(item.visible and bar.get_global_rect().encloses(item.get_global_rect()), "Visible economic resource: " + key)
		_check((bar._icons[key] as TextureRect).visible and (bar._icons[key] as TextureRect).texture != null, "Real pixel icon: " + key)
	for button in bar.navigation_row.get_children():
		if button is Button and button.visible:
			_check(bar.get_global_rect().encloses(button.get_global_rect()), "Navigation fits: " + button.name)
	samples.append({"layout":name,"height":bar.size.y,"mode":bar._layout_mode,"minimum_width":bar.get_combined_minimum_size().x})

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var previous_scale: int = settings.ui_scale_percent
	settings.ui_scale_percent = 100
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	await main.hex_grid.generate_map(32,24,2026)
	var civ = load("res://scripts/data/CivilizationData.gd").new()
	civ.race = "human"
	civ.civ_name = "Aurora"
	civ.color = Color("688fb3")
	player = load("res://scripts/core/PlayerData.gd").new(civ)
	var manager = root.get_node("GameManager")
	manager.players.assign([player])
	manager.human_player = player
	manager.state = manager.GameState.PLAYING
	var origin := Vector2i.ZERO
	var shortest := INF
	for coord in main.hex_grid.tiles:
		var tile = main.hex_grid.tiles[coord]
		if int(tile.terrain_type) not in [7,8]: continue
		var distance := float(coord.x * coord.x + coord.y * coord.y)
		if distance < shortest:
			shortest = distance
			origin = coord
	main.hex_grid.found_city(origin, player, "Aurora", true)
	var warrior = load("res://scripts/data/UnitDatabase.gd").create_unit("warrior")
	main.hex_grid.spawn_unit(origin + Vector2i(1,0), warrior, player)
	player.gold = 784
	player.mana = 126
	player.v2_research.add_knowledge(8)
	player.v2_research.select_research("v2_doctrine_guardian_2")
	root.get_node("TurnManager").turn_number = 62
	root.get_node("WorldEventManager").world_phase = 1
	main.hex_grid.debug_fog_disabled = true
	main.hex_grid.recompute_fog(player)
	main.hex_grid.visible = true
	main.camera_rig.reset_view(main._human_camera_focus())
	main._enter_gameplay()
	bar = main.hud.ui_shell.global_bar
	bar.refresh(player)
	await _check_layout("1600x900")
	await _capture("top_bar_1600x900")
	player.v2_research.cancel_active_research()
	player.v2_research.add_knowledge(18)
	await _settle()
	_check(bar.last_snapshot().knowledge_banked == 18 and bar._labels.knowledge.text.begins_with("18"), "Banked Knowledge follows real state immediately")
	await _capture("banked_1600x900")
	player.v2_research.select_research("v2_doctrine_guardian_2")
	await _settle()
	_check(bar.last_snapshot().knowledge_banked < 18, "Choosing research spends banked Knowledge")
	player.v2_research.select_research("v2_doctrine_guardian_3")
	for sample in [
		[Vector2i(1280,720),100,"1280x720"],
		[Vector2i(1600,900),125,"1600x900_ui125"],
		[Vector2i(1920,1080),100,"1920x1080"],
		[Vector2i(3440,1440),100,"ultrawide"],
		[Vector2i(1280,720),150,"1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		settings.accessibility_changed.emit()
		await _settle()
		bar.refresh(player)
		await _check_layout(sample[2])
		await _capture("top_bar_" + sample[2])
	var menu := bar.get_node("BarPadding/BarRow/Navigation/MoreNavigation") as MenuButton
	menu.grab_focus()
	await _action("ui_accept")
	_check(menu.get_popup().visible, "Keyboard opens the overflow menu")
	await _capture("navigation_1280x720_ui150")
	menu.get_popup().hide()
	menu.get_popup().id_pressed.emit(0)
	await _settle()
	_check(main.hud.v2_research_panel.visible, "Overflow Research uses the actual HUD route")
	main.hud.close_topmost_overlay()
	await _settle()
	menu.get_popup().id_pressed.emit(5)
	await _settle()
	_check(main.hud.ui_shell.city_summary.visible, "Overflow Cities opens production summary")
	main.hud.ui_shell.close_auxiliary_drawer()
	root.size = Vector2i(1600,900)
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	await _settle()
	bar.research_status.grab_focus()
	await _action("ui_accept")
	_check(main.hud.v2_research_panel.visible, "Keyboard opens research through the status widget")
	main.hud.close_topmost_overlay()
	await _settle()
	player.gold = 1234567
	player.mana = 234567
	bar.refresh(player)
	await _check_layout("large_values")
	_check(bar._items.gold.tooltip_text.contains("1234567"), "Tooltip retains exact large resource totals")
	await _capture("large_values_1600x900")
	# Exercise the real warning states without changing their calculation rules.
	var added := 0
	for coord in main.hex_grid.tiles:
		if added >= 6: break
		var tile = main.hex_grid.tiles[coord]
		if tile.blocks_land_units() or coord == origin or main.hex_grid.units_by_coord.has(coord): continue
		main.hex_grid.spawn_unit(coord, load("res://scripts/data/UnitDatabase.gd").create_unit("v2_unit_warrior"), player)
		added += 1
	player.gold = 0
	# Building upkeep, rather than troop supply, is the source of a Gold deficit.
	var workshop_id: String = load("res://scripts/data/V2InfrastructureEconomyData.gd").building_id_for_branch("industry")
	player.cities[0].buildings[workshop_id] = true
	player.cities[0].repeatable_building_counts[workshop_id] = 6
	bar.refresh(player)
	await _check_layout("economic_pressure")
	_check(bar._labels.gold.get_theme_color("font_color") == load("res://scripts/ui/UIThemeTokens.gd").COLOR_CRITICAL, "Gold deficit remains visually critical")
	_check(bar._labels.supply.get_theme_color("font_color") == load("res://scripts/ui/UIThemeTokens.gd").COLOR_CRITICAL, "Supply pressure remains visually critical")
	await _capture("economic_pressure_1600x900")
	root.size = Vector2i(1280,720)
	settings.ui_scale_percent = 150
	settings.accessibility_changed.emit()
	await _check_layout("economic_pressure_ui150")
	await _capture("economic_pressure_1280x720_ui150")
	settings.ui_scale_percent = previous_scale
	settings.accessibility_changed.emit()
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures, "layouts":samples}, "\t"))
	player.release_relations()
	manager.human_player = null
	manager.players.clear()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
