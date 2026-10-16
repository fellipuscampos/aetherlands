extends SceneTree

## Actual Main → HUD. Disposable game state; no player save or preferences written.
const OUTPUT := "res://docs/previews/hud_chrome/"
var failures: Array[String] = []
var main: Node
var shell: Control
var player: RefCounted
var origin := Vector2i.ZERO
var unit: Node
var layouts: Array[Dictionary] = []

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("PIXEL_HUD_OK: ", message)
	else:
		failures.append(message)
		push_error("PIXEL_HUD_FAIL: " + message)

func _settle() -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
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
	var turn: Rect2 = shell.turn_controller.get_global_rect()
	var pending: Rect2 = shell.attention_presenter.get_global_rect()
	var minimap: Rect2 = shell.minimap_host.get_global_rect()
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	_check(bounds.encloses(turn), "Turn controller fits " + name)
	_check(bounds.encloses(minimap), "Minimap fits " + name)
	_check(turn.position.x >= pending.end.x + 8, "Pending and turn controls have a gap at " + name)
	if not shell.minimap_expanded:
		_check(pending.position.x >= minimap.end.x + 8, "Minimap and pending controls have a gap at " + name)
	_check(turn.end.x <= root.size.x - 16 and turn.end.y <= root.size.y - 16, "Footer keeps outer padding")
	_check(shell.turn_controller.primary_button.get_global_rect().position.x > turn.position.x, "Turn button retains internal padding")
	layouts.append({"layout":name,"turn":str(turn),"pending":str(pending),"minimap":str(minimap)})

func _clear_notices() -> void:
	shell.toast_presenter.dismiss_all()
	while shell.critical_alerts.current_event() != null: shell.critical_alerts.dismiss()
	await _settle()

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var previous_scale: int = settings.ui_scale_percent
	var previous_motion: bool = settings.reduced_motion
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
	manager.hex_grid = main.hex_grid
	manager.state = manager.GameState.PLAYING
	var shortest := INF
	for coord in main.hex_grid.tiles:
		var tile = main.hex_grid.tiles[coord]
		if int(tile.terrain_type) not in [7,8]: continue
		var distance := float(coord.x * coord.x + coord.y * coord.y)
		if distance < shortest:
			shortest = distance
			origin = coord
	var city = main.hex_grid.found_city(origin,player,"Aurora",true)
	city.production_item = "warrior"
	unit = main.hex_grid.spawn_unit(origin + Vector2i(1,0),load("res://scripts/data/UnitDatabase.gd").create_unit("warrior"),player)
	player.gold = 784
	player.mana = 126
	player.v2_research.select_research("v2_doctrine_guardian_2")
	player.v2_research.add_knowledge(8)
	root.get_node("TurnManager").turn_number = 62
	main.hex_grid.debug_fog_disabled = true
	main.hex_grid.recompute_fog(player)
	main.hex_grid.visible = true
	main.camera_rig.reset_view(main._human_camera_focus())
	main._enter_gameplay()
	shell = main.hud.ui_shell
	await _clear_notices()
	await _check_layout("1600x900_ready")
	_check(shell.turn_controller.primary_button.text == "Finalizar Turno", "Normal end-turn action is preserved")
	await _capture("hud_ready_1600x900")
	# Minimap is the actual terrain raster, with a fixed transform.
	var minimap: Control = main.hud.minimap
	_check(minimap._terrain_texture != null and minimap._scale > 0, "Minimap renders live terrain")
	var fixed_bounds: Rect2 = minimap.world_bounds()
	var rebuilds: int = minimap.layout_rebuilds
	main.camera_rig.position.x += 2
	await _settle()
	_check(minimap.layout_rebuilds == rebuilds and minimap.world_bounds() == fixed_bounds, "Moving the camera does not reframe or rebuild the map")
	minimap.expand_button.grab_focus()
	await _action("ui_accept")
	_check(shell.minimap_expanded and minimap.expanded, "Keyboard expands the real minimap")
	await _capture("minimap_expanded_1600x900")
	minimap.set_expanded(false)
	await _settle()
	# Pending decisions keep their original routing and override confirmation.
	player.v2_research.cancel_active_research()
	city.production_item = ""
	shell.refresh_live_state()
	await _settle()
	_check(shell.turn_controller.override_button.visible, "Skipping pending decisions remains explicit")
	shell.attention_presenter.summary_button.grab_focus()
	await _action("ui_accept")
	_check(shell.attention_presenter.is_expanded(), "Keyboard opens pending decisions")
	await _check_layout("1600x900_pending")
	await _capture("pending_expanded_1600x900")
	shell.attention_presenter.collapse()
	shell.turn_controller.request_override()
	await _settle()
	_check(shell.modal_manager.is_modal_open(), "Skipping pending decisions opens confirmation")
	await _capture("skip_confirmation_1600x900")
	var turn_before: int = root.get_node("TurnManager").turn_number
	shell.modal_manager.dismiss_top(true)
	_check(root.get_node("TurnManager").turn_number == turn_before, "Cancelling confirmation never advances the turn")
	for sample in [[Vector2i(1280,720),100,"1280x720"],[Vector2i(1600,900),125,"1600x900_ui125"],[Vector2i(1920,1080),100,"1920x1080"],[Vector2i(3440,1440),100,"ultrawide"],[Vector2i(1280,720),150,"1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		settings.accessibility_changed.emit()
		await _settle()
		await _check_layout(sample[2])
		await _capture("hud_pending_" + sample[2])
		shell.attention_presenter._toggle()
		await _check_layout(sample[2] + "_expanded")
		await _capture("pending_expanded_" + sample[2])
		shell.attention_presenter.collapse()
	root.size = Vector2i(1600,900)
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	await _settle()
	var event_type = load("res://scripts/ui/UIEventData.gd")
	var events = root.get_node("UIEvents")
	events.publish(event_type.create("preview_info",event_type.Category.PRODUCTION,event_type.Severity.INFO,"Obra concluída","As oficinas de Aurora estão prontas para produzir."))
	events.publish(event_type.create("preview_warning",event_type.Category.ECONOMY,event_type.Severity.IMPORTANT,"Suprimentos próximos do limite","Confira a capacidade antes de treinar novas tropas."))
	await _capture("notices_1600x900")
	var notices: Array = shell.toast_presenter.get_children()
	for i in range(1,notices.size()):
		_check(notices[i].get_global_rect().position.y >= notices[i-1].get_global_rect().end.y, "Notifications stack without overlap")
	await _clear_notices()
	var critical = event_type.create("city_threatened",event_type.Category.CITY,event_type.Severity.CRITICAL,"Aurora está sob ameaça","Uma força hostil se aproxima. Confira as defesas da cidade.")
	critical.with_target(origin,"city")
	events.publish(critical)
	await _capture("critical_alert_1600x900")
	_check(shell.critical_alerts.visible and shell.critical_alerts.current_event() == critical, "Critical banner retains the real event and action")
	_check(shell.toast_presenter.visible_toast_count() == 0, "Critical banner is not duplicated as a toast")
	root.size = Vector2i(1280,720)
	settings.ui_scale_percent = 150
	settings.accessibility_changed.emit()
	await _settle()
	_check(shell.critical_alerts.get_global_rect().position.y >= shell.global_bar.get_global_rect().end.y + 8, "Critical banner clears enlarged top bar")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(shell.critical_alerts.get_global_rect()), "Enlarged critical banner fits viewport")
	events.publish(event_type.create("preview_parallel",event_type.Category.PRODUCTION,event_type.Severity.INFO,"Obra concluída","Uma oficina está pronta."))
	await _capture("critical_alert_1280x720_ui150")
	_check(shell.toast_presenter.get_child(0).get_global_rect().position.y >= shell.critical_alerts.get_global_rect().end.y + 8, "Notification clears critical banner at 150 percent")
	await _clear_notices()
	root.size = Vector2i(1600,900)
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	root.get_node("SelectionManager")._select_unit(unit)
	await _settle()
	await _capture("unit_context_1600x900")
	shell.turn_controller.set_processing(true)
	_check(shell.turn_controller.primary_button.disabled and not shell.turn_controller.override_button.visible, "Processing disables turn controls")
	await _capture("processing_1600x900")
	shell.turn_controller.set_processing(false)
	settings.reduced_motion = true
	var minimap_rebuilds: int = minimap.terrain_rebuilds
	settings.accessibility_changed.emit()
	events.publish(event_type.create("preview_motion",event_type.Category.SYSTEM,event_type.Severity.INFO,"Aviso","Movimento reduzido respeitado."))
	await _capture("reduced_motion_1600x900")
	_check(minimap.terrain_rebuilds == minimap_rebuilds, "Reduced motion does not rebuild minimap terrain")
	settings.ui_scale_percent = previous_scale
	settings.reduced_motion = previous_motion
	settings.accessibility_changed.emit()
	var file := FileAccess.open(OUTPUT + "validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"layouts":layouts},"\t"))
	root.get_node("SelectionManager").reset()
	player.release_relations()
	manager.human_player = null
	manager.players.clear()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
