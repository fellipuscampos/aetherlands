extends SceneTree

## Reviews the actual HUD overlay, without creating a match or writing saves.
const OUTPUT := "res://docs/previews/research/"
var failures: Array[String] = []
var main: Node
var board: Control
var density_samples: Array[Dictionary] = []

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("PIXEL_RESEARCH_OK: ", message)
	else:
		failures.append(message)
		push_error("PIXEL_RESEARCH_FAIL: " + message)

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

func _check_density(sample: String, expected_rows: int) -> void:
	var scroll := board.find_child("CardsScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 0
	await _settle()
	var rows := 0
	var row_heights: Array[float] = []
	var content := board.find_child("Cards", true, false) as VBoxContainer
	for row in content.get_children():
		if not String(row.name).begins_with("Row_"): continue
		var bounds: Rect2 = row.get_global_rect()
		row_heights.append(bounds.size.y)
		if bounds.position.y >= scroll.global_position.y and bounds.end.y <= scroll.get_global_rect().end.y - scroll.get_h_scroll_bar().size.y:
			rows += 1
	_check(rows >= expected_rows, "%s shows at least %d full branches (actual: %d)" % [sample,expected_rows,rows])
	for height in row_heights:
		_check(absf(height - board.metrics().card.y) <= 1, "Branch row preserves the compact card height")
	density_samples.append({"layout":sample,"full_branches":rows,"row_height":board.metrics().card.y})

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var previous_scale: int = settings.ui_scale_percent
	settings.ui_scale_percent = 100
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600, 900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	main.title_screen.hide()
	main.hud.show()
	main.hud._on_research_pressed()
	board = main.hud.v2_research_board
	var state = board.get_state()
	state.complete_research("v2_doctrine_guardian_2")
	state.complete_research("v2_doctrine_guardian_3")
	state.select_research("v2_doctrine_ranger_2")
	state.add_knowledge(6)
	state.cancel_active_research()
	state.select_research("v2_doctrine_guardian_4")
	state.add_knowledge(10)
	await _settle()
	board.select_node("v2_doctrine_guardian_4")
	_check(main.hud.v2_research_panel.visible and board.card_count() == 49, "HUD opens real research board")
	await _check_density("1600x900", 5)
	await _capture("doctrines_1600x900")
	for tree in [1, 2]:
		board.show_tree(tree)
		board.jump_to_available()
		await _capture("magic_1600x900" if tree == 1 else "infrastructure_1600x900")
	board.jump_to_active()
	await _settle()
	var cards := board.find_child("CardsScroll", true, false) as ScrollContainer
	var tiers := board.find_child("TierHeaderScroll", true, false) as ScrollContainer
	var branches := board.find_child("BranchLabelScroll", true, false) as ScrollContainer
	cards.scroll_horizontal = 220
	cards.scroll_vertical = 120
	await _settle()
	_check(cards.scroll_horizontal == tiers.scroll_horizontal and cards.scroll_vertical == branches.scroll_vertical, "Pinned rows and tiers follow board scrolling")
	await _capture("scrolled_1600x900")
	board.jump_to_active()
	await _settle()
	var card := board.card_for(state.active_id) as Control
	card.grab_focus()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	card.gui_input.emit(accept)
	await _settle()
	_check(root.gui_get_focus_owner() == board.card_for(state.active_id), "Keyboard selection preserves focus after card replacement")
	state.add_knowledge(1)
	await _settle()
	_check(root.gui_get_focus_owner() == board.card_for(state.active_id), "Live progress preserves keyboard focus")
	board.press_action()
	_check(state.active_id == "" and board.action_text() == "Continuar pesquisa", "Pause preserves partial research")
	state.add_knowledge(12)
	await _settle()
	await _capture("banked_1600x900")
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
		board.select_node("v2_doctrine_guardian_4")
		await _settle()
		for name in ["ResearchHeader", "ResearchToolbar", "ResearchDetails", "BoardGrid"]:
			var control := board.find_child(name, true, false) as Control
			_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect()), "%s fits %s" % [name, sample[2]])
		var scroll := board.find_child("CardsScroll", true, false) as ScrollContainer
		_check(scroll.size.y >= board.metrics().card.y, "Research keeps a full card visible at " + sample[2])
		var expected_rows := 2 if sample[1] == 150 else (4 if sample[0].y == 720 or sample[1] == 125 else 5)
		await _check_density(sample[2], expected_rows)
		_check(board.get_global_rect().position.x >= 24 and board.get_global_rect().position.y >= 24, "Page retains comfortable outer padding")
		for button in board.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button.get_global_rect()), "Visible button fits: " + button.name)
		await _capture("doctrines_" + sample[2])
		board.show_tree(2)
		await _capture("infrastructure_" + sample[2])
		board.show_tree(0)
	var navigation := board.find_child("ResearchNavigationMenu", true, false) as MenuButton
	_check(navigation.visible, "Small display exposes the navigation menu")
	navigation.grab_focus()
	await _action("ui_accept")
	_check(navigation.get_popup().visible, "Keyboard opens the real positioned menu")
	await _capture("navigation_1280x720_ui150")
	navigation.get_popup().id_pressed.emit(2)
	navigation.get_popup().hide()
	_check(is_equal_approx(board.zoom, .8) and navigation.get_popup().is_item_checked(navigation.get_popup().get_item_index(2)), "Compact menu changes zoom and reports its selected value")
	await _settle()
	root.size = Vector2i(1600,900)
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	board.set_zoom(1.0)
	var manager = root.get_node("GameManager")
	_check(manager.human_player == null, "Review uses an isolated HUD research state")
	var guardian_nodes = load("res://scripts/data/V2ResearchDatabase.gd").nodes_for_branch(0, "guardian")
	for i in guardian_nodes.size() - 1:
		state.complete_research(guardian_nodes[i].id)
	state.select_research(guardian_nodes.back().id)
	await _settle()
	board.jump_to_active()
	await _settle()
	board.card_for(state.active_id).grab_focus()
	await _settle()
	var far_scroll := board.find_child("CardsScroll", true, false) as ScrollContainer
	var previous_horizontal := far_scroll.scroll_horizontal
	state.add_knowledge(1)
	await _settle()
	_check(previous_horizontal > 0 and far_scroll.scroll_horizontal == previous_horizontal, "Replacing a far-tier card keeps scroll position while focused")
	_check(root.gui_get_focus_owner() == board.card_for(state.active_id), "Far-tier progress keeps focus")
	_check(main.hud.close_topmost_overlay() and not main.hud.v2_research_panel.visible, "Existing Escape route closes overlay")
	settings.ui_scale_percent = previous_scale
	settings.accessibility_changed.emit()
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures,"density":density_samples}, "\t"))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
