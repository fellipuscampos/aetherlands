extends SceneTree

## Native visual/input review. Synthetic cards; deletion uses one isolated temporary file.
const OUTPUT := "res://docs/previews/auxiliary_menus/"
var failures: Array[String] = []
var main: Node
var settings_screen: Control
var load_screen: Control
var settings: Node
var original_values: Dictionary = {}
var original_config: PackedByteArray
var config_existed := false
var test_dir: String

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("PIXEL_MENUS_OK: ", message)
	else:
		failures.append(message)
		push_error("PIXEL_MENUS_FAIL: " + message)

func _settle() -> void:
	for i in 8: await process_frame
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

func _capture(name: String) -> void:
	await _settle()
	_check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, "Screenshot: " + name)

func _fits(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect())

func _synthetic_cards() -> void:
	for child in load_screen.slot_list.get_children():
		load_screen.slot_list.remove_child(child)
		child.queue_free()
	var now := 1791900000
	for entry in [
		{"slot_id":"preview_human", "kingdom_name":"Reino de Aldenmark", "race":"human", "turn_number":48, "saved_at":now, "status":"valid"},
		{"slot_id":"preview_elf", "kingdom_name":"Império de Elenor", "race":"elf", "turn_number":126, "saved_at":now-86400, "status":"valid"},
		{"slot_id":"preview_dwarf", "kingdom_name":"Liga dos Clãs de Ferro", "race":"dwarf", "turn_number":73, "saved_at":now-172800, "status":"valid"},
		{"slot_id":"preview_bad", "status":"incompatible", "version":999}]:
		load_screen.slot_list.add_child(load_screen._build_row(entry, test_dir))
	load_screen.get_node("Margin/VBox/EmptyState").visible = false
	load_screen.empty_state_label.visible = false
	load_screen.scroll_container.visible = true
	load_screen.get_node("Margin/VBox/ListHeading/CountLabel").text = "4 PARTIDAS SALVAS"
	load_screen._layout_for_viewport()
	load_screen._first_enabled_load_button(load_screen.slot_list).grab_focus()

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	settings = root.get_node("Settings")
	for key in ["music_volume", "sfx_volume", "ui_scale_percent", "reduced_motion"]:
		original_values[key] = settings.get(key)
	config_existed = FileAccess.file_exists(settings.SETTINGS_PATH)
	if config_existed: original_config = FileAccess.get_file_as_bytes(settings.SETTINGS_PATH)
	test_dir = "user://pixel_menu_review_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(test_dir)
	settings.ui_scale_percent = 100
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600, 900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	settings_screen = main.title_screen.settings_screen
	load_screen = main.title_screen.load_game_screen
	main.title_screen.settings_button.grab_focus()
	await _action("ui_accept")
	_check(settings_screen.visible and not main.title_screen.main_page.visible, "Settings opens through title")
	_check(root.gui_get_focus_owner() == settings_screen.music_slider, "Audio opens with focus on a usable control")
	await _capture("settings_audio_1600x900")
	var before: float = settings.music_volume
	await _action("ui_right")
	_check(is_equal_approx(settings.music_volume, settings_screen.music_slider.value), "Slider changes real volume")
	_check(settings_screen.get_node("%MusicValue").text == "%d%%" % roundi(settings.music_volume * 100), "Volume readout follows slider")
	settings.music_volume = before
	settings_screen.refresh()
	for index in 5:
		settings_screen._show_page(index)
		await _capture("settings_%s_1600x900" % ["audio", "video", "interface", "controls", "help"][index])
	settings_screen._show_page(2)
	await _settle()
	settings_screen.reduced_motion_check.grab_focus()
	var motion_before: bool = settings.reduced_motion
	await _action("ui_accept")
	_check(settings.reduced_motion != motion_before, "Pixel switch toggles real reduced-motion setting")
	settings_screen._show_page(1)
	settings_screen.window_mode_option.grab_focus()
	await _action("ui_accept")
	_check(settings_screen.window_mode_option.get_popup().visible, "Option opens real themed popup")
	await _capture("settings_dropdown")
	await _action("ui_cancel")
	_check(settings_screen.visible, "Escape closes popup before leaving settings")
	settings_screen.back_button.pressed.emit()
	await _settle()
	_check(main.title_screen.main_page.visible and root.gui_get_focus_owner() == main.title_screen.settings_button, "Back restores title focus")
	main.title_screen._on_load_game_pressed()
	load_screen.refresh(test_dir)
	await _capture("load_empty_1600x900")
	_check(load_screen.empty_state_label.visible and root.gui_get_focus_owner() == load_screen.back_button, "Empty state has usable back focus")
	_synthetic_cards()
	await _capture("load_games_1600x900")
	_check(load_screen.slot_list.get_child(3).get_node("Row/Actions/Carregar").disabled, "Incompatible save cannot be loaded")
	var received := [""]
	load_screen.slot_load_requested.disconnect(main.title_screen._on_slot_load_requested)
	load_screen.slot_load_requested.connect(func(slot): received[0] = slot)
	load_screen.slot_list.get_child(0).get_node("Row/Actions/Carregar").grab_focus()
	await _action("ui_accept")
	_check(received[0] == "preview_human", "Load button sends correct slot")
	# One disposable corrupt file tests both cancel and confirmed deletion.
	var test_file := test_dir.path_join("delete_me.json")
	var file := FileAccess.open(test_file, FileAccess.WRITE)
	file.store_string("{}"); file.close()
	load_screen.refresh(test_dir)
	await _settle()
	load_screen.slot_list.get_child(0).get_node("Row/Actions/Excluir").pressed.emit()
	await _settle()
	_check(load_screen.confirm_delete_dialog.get_cancel_button().has_focus(), "Delete confirmation defaults to cancel")
	await _capture("load_delete_confirmation")
	load_screen.confirm_delete_dialog.get_cancel_button().pressed.emit()
	await _settle()
	_check(FileAccess.file_exists(test_file), "Cancel preserves save")
	load_screen.slot_list.get_child(0).get_node("Row/Actions/Excluir").pressed.emit()
	load_screen.confirm_delete_dialog.confirmed.emit()
	await _settle()
	_check(not FileAccess.file_exists(test_file) and load_screen.slot_list.get_child_count() == 0, "Confirm deletes only disposable file and refreshes list")
	_synthetic_cards()
	for sample in [
		[Vector2i(1280, 720), 100, "1280x720"],
		[Vector2i(1920, 1080), 100, "1920x1080"],
		[Vector2i(3440, 1440), 100, "ultrawide"],
		[Vector2i(1280, 720), 150, "1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		load_screen._apply_accessibility_theme()
		await _settle()
		_check(_fits(load_screen.back_button), "Load back stays visible: " + sample[2])
		_check(load_screen.scroll_container.get_global_rect().end.y < load_screen.back_button.get_global_rect().position.y, "Load scroll remains above footer")
		await _capture("load_games_" + sample[2])
		main.title_screen._on_settings_pressed()
		settings_screen._apply_accessibility_theme()
		await _settle()
		for index in [0, 1, 2]:
			settings_screen._show_page(index)
			await _settle()
			_check(_fits(settings_screen.back_button), "Settings back stays visible: " + sample[2])
			_check(_fits(settings_screen.get_node("Margin/Layout/Body/PagePanel")), "Settings panel fits: " + sample[2])
			await _capture("settings_%s_%s" % [["audio", "video", "interface"][index], sample[2]])
		main.title_screen._return_to_main()
		main.title_screen._on_load_game_pressed()
		_synthetic_cards()
	main.title_screen._return_to_main()
	main.title_screen._on_settings_pressed()
	settings_screen._show_page(1)
	await _settle()
	settings_screen.reset_graphics_button.grab_focus()
	await _settle()
	_check(settings_screen.get_node("Margin/Layout/Body/PagePanel/PageScroll").get_global_rect().encloses(settings_screen.reset_graphics_button.get_global_rect()), "Enlarged settings scroll follows keyboard focus to last option")
	await _capture("settings_video_ui150_scrolled")
	# Restore every preference touched by this review, including exact on-disk bytes.
	for key in original_values: settings.set(key, original_values[key])
	if config_existed:
		file = FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(original_config); file.close()
	else:
		DirAccess.remove_absolute(settings.SETTINGS_PATH)
	DirAccess.remove_absolute(test_dir)
	file = FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures}, "\t"))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
