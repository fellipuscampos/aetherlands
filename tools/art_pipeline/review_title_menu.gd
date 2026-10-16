extends SceneTree

## Native visual/input smoke check, isolated from saves and gameplay state.
var title: Control
var failures: Array[String] = []
const OUTPUT := "res://docs/previews/title_menu/"

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TITLE_MENU_FAIL: " + message)
	else:
		print("TITLE_MENU_OK: ", message)

func _settle() -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw

func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()

func _fits(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect())

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var original_scale: int = settings.ui_scale_percent
	settings.ui_scale_percent = 100
	root.size = Vector2i(1600, 900)
	title = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await _settle()
	var new_button: Button = title.new_game_button
	var settings_button: Button = title.settings_button
	var quit_button: Button = title.quit_button
	# Make the no-save case deterministic without creating or deleting any save.
	title.load_game_button.disabled = true
	title._rebuild_focus_order()
	new_button.grab_focus()
	await _action("ui_down")
	_check(root.gui_get_focus_owner() == settings_button, "Down skips unavailable load")
	await _action("ui_down")
	_check(root.gui_get_focus_owner() == quit_button, "Down follows the visible order")
	await _action("ui_down")
	_check(root.gui_get_focus_owner() == new_button, "Last item wraps to first")
	await _action("ui_up")
	_check(root.gui_get_focus_owner() == quit_button, "First item wraps to last")
	var emitted := [false]
	title.new_game_setup_requested.connect(func(): emitted[0] = true)
	new_button.grab_focus()
	await _action("ui_accept")
	_check(emitted[0], "Enter emits new-game setup request")
	settings_button.grab_focus()
	await _action("ui_accept")
	_check(title.settings_screen.visible and not title.main_page.visible, "Settings opens existing full page")
	await _action("ui_cancel")
	_check(title.main_page.visible and root.gui_get_focus_owner() == settings_button, "Escape returns and restores focus")
	title.load_game_button.disabled = false
	title._rebuild_focus_order()
	new_button.grab_focus()
	await _action("ui_down")
	_check(root.gui_get_focus_owner() == title.load_game_button, "Load is reachable when enabled")
	await _action("ui_accept")
	_check(title.load_game_screen.visible, "Load opens existing save page")
	title.load_game_screen.back_requested.emit()
	await _settle()
	_check(title.main_page.visible, "Save page back returns to main")
	title.refresh_load_button()
	new_button.grab_focus()
	for sample in [
		[Vector2i(1600, 900), 100, "main_1600x900"],
		[Vector2i(1280, 720), 100, "main_1280x720"],
		[Vector2i(1280, 720), 150, "main_1280x720_ui150"],
		[Vector2i(1920, 1080), 100, "main_1920x1080"],
		[Vector2i(3440, 1440), 100, "main_ultrawide"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		title._apply_accessibility_theme()
		await _settle()
		for control in [title.brand_panel, title.center_box, new_button, title.load_game_button, settings_button, quit_button]:
			_check(_fits(control), "%s fits %s" % [control.name, sample[2]])
		_check(title.brand_panel.get_global_rect().end.y < new_button.get_global_rect().position.y, "Brand does not overlap actions: " + sample[2])
		_check(quit_button.get_global_rect().end.y < title.get_node("MainPage/NavigationHint").position.y, "Actions stay above footer: " + sample[2])
		_check(title.get_node("MainPage/CenterBox/Box/ContextLabel").get_global_rect().end.y < title.get_node("MainPage/NavigationHint").position.y, "Context stays above footer: " + sample[2])
		_check(root.get_texture().get_image().save_png(OUTPUT + sample[2] + ".png") == OK, "Screenshot saved: " + sample[2])
	settings.ui_scale_percent = original_scale
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "failures": failures}
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	title.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
