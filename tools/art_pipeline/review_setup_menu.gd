extends SceneTree

## Checks the actual Title -> Setup -> Title flow and captures native Godot UI.
const OUTPUT := "res://docs/previews/game_setup/"
var failures: Array[String] = []
var main: Node
var setup: Control

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("SETUP_MENU_OK: ", message)
	else:
		failures.append(message)
		push_error("SETUP_MENU_FAIL: " + message)

func _settle() -> void:
	for i in 8:
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

func _capture(name: String) -> void:
	await _settle()
	_check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, "Screenshot: " + name)

func _fits(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect())

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var original_scale: int = settings.ui_scale_percent
	settings.ui_scale_percent = 100
	root.size = Vector2i(1600, 900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	setup = main.game_setup_screen
	main.title_screen.new_game_button.grab_focus()
	await _action("ui_accept")
	_check(setup.visible and not main.title_screen.visible, "New game opens real lobby")
	_check(root.gui_get_focus_owner() == setup.human_race_button, "Opening focuses initial faction")
	await _action("ui_right")
	_check(root.gui_get_focus_owner() == setup.elf_race_button, "Right follows faction row")
	await _action("ui_accept")
	_check(setup._selected_race == "elf" and setup.elf_race_button.button_pressed, "Accept selects elf")
	await _action("ui_cancel")
	_check(main.title_screen.visible and not setup.visible, "Escape returns to real title")
	main._on_new_game_setup_requested()
	await _settle()
	_check(setup._selected_race == "human", "Reopening restores defaults")
	for race in ["human", "elf", "dwarf", "orc"]:
		setup._on_race_pressed(race)
		setup._race_cards[race].grab_focus()
		for effect in V2RaceBonusDatabase.effect_lines(race):
			_check(setup.race_specialties_label.text.contains(effect), "Real specialty shown: " + race)
		await _capture("lobby_" + race + "_1600x900")
	setup._on_lore_pressed()
	await _capture("lobby_lore_expanded")
	setup._on_race_pressed("human")
	# Prevent actual world generation; independently observe the exact emitted setup parameters.
	setup.new_game_requested.disconnect(main._on_new_game_requested)
	var received: Array = []
	setup.new_game_requested.connect(func(w, h, n, rivals, difficulty, race): received.assign([w, h, n, rivals, difficulty, race]))
	setup.kingdom_name_edit.text = "X"
	setup.kingdom_name_edit.text_changed.emit("X")
	_check(setup.start_game_button.disabled and setup.status_label.visible, "Invalid name blocks start with inline reason")
	setup._on_start_game_pressed()
	_check(received.is_empty(), "Invalid name does not emit start")
	setup.reset_to_defaults()
	_check(not setup.start_game_button.disabled, "Reopen clears invalid-name state")
	setup._on_race_pressed("dwarf")
	setup._on_map_size_pressed("small")
	setup._on_rival_count_pressed(3)
	setup.kingdom_name_edit.text = "Meu Reino"
	setup._on_start_game_pressed()
	var profile: Dictionary = setup.selected_map_profile()
	_check(received == [profile.width, profile.height, "Meu Reino", 3, "normal", "dwarf"], "Lobby emits chosen map, name, rivals and faction")
	setup.reset_to_defaults()
	for sample in [
		[Vector2i(1280, 720), 100, "lobby_1280x720"],
		[Vector2i(1920, 1080), 100, "lobby_1920x1080"],
		[Vector2i(3440, 1440), 100, "lobby_ultrawide"],
		[Vector2i(1280, 720), 150, "lobby_1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		setup._apply_accessibility_theme()
		await _settle()
		for control in [setup.get_node("Header"), setup.get_node("CenterBox"), setup.get_node("Footer"), setup.start_game_button, setup.back_button]:
			_check(_fits(control), "%s fits %s" % [control.name, sample[2]])
		_check(setup.get_node("CenterBox").get_global_rect().end.y < setup.get_node("Footer").position.y, "Scroll area stays above persistent footer")
		setup._race_cards[setup._selected_race].grab_focus()
		await _capture(sample[2])
	# Keyboard traversal also reaches controls which require scrolling at enlarged text sizes.
	setup.kingdom_name_edit.grab_focus()
	await _settle()
	_check(setup.get_node("CenterBox").get_global_rect().encloses(setup.kingdom_name_edit.get_global_rect()), "Enlarged UI follows keyboard focus to name field")
	await _capture("lobby_1280x720_ui150_configuration")
	settings.ui_scale_percent = original_scale
	var report := {"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures}
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
