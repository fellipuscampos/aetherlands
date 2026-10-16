extends GutTest

var viewport: SubViewport
var panel: PanelContainer
var _original_scale: int

func before_each() -> void:
	_original_scale = Settings.ui_scale_percent
	Settings.ui_scale_percent = 100
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	add_child_autofree(viewport)
	panel = preload("res://scenes/ui/GameOverPanel.tscn").instantiate()
	viewport.add_child(panel)
	panel.show()
	panel.present(true, [142, 12, 36, 15890])

func after_each() -> void:
	Settings.ui_scale_percent = _original_scale

func _settle() -> void:
	for frame in 5:
		await get_tree().process_frame

func _assert_accessible() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_true(screen.encloses(panel.get_global_rect()), "The complete frame fits inside the viewport")
	for button_name in ["RestartButton", "LoadButton", "MainMenuButton"]:
		assert_true(panel.get_global_rect().encloses(panel.get_node("%" + button_name).get_global_rect()), "Action remains visible: " + button_name)
	var scroll: ScrollContainer = panel.get_node("%ResultScroll")
	assert_gt(scroll.size.y, 100.0, "Content retains a usable scrolling area")
	assert_lte(scroll.get_child(0).get_combined_minimum_size().x, scroll.size.x + 1, "Text wraps without horizontal overflow")

func test_result_actions_and_long_content_fit_720p_at_150_percent() -> void:
	viewport.size = Vector2i(1280, 720)
	Settings.ui_scale_percent = 150
	Settings.accessibility_changed.emit()
	panel.get_node("%GameOverTitleLabel").text = "Vitória por Supremacia Militar — Reino das Montanhas e das Terras Distantes"
	panel.get_node("%GameOverSummaryLabel").text = "Seu império provou sua supremacia conquistando os centros desenvolvidos de seus rivais."
	for index in 12:
		var line := Label.new()
		line.text = "Um resumo extenso da partida que continua disponível por rolagem."
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.get_node("%GameOverSnapshotRows").add_child(line)
	await _settle()
	_assert_accessible()
	var scroll: ScrollContainer = panel.get_node("%ResultScroll")
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y, "Long results can actually scroll")
	var before: Rect2 = panel.get_node("%RestartButton").get_global_rect()
	scroll.scroll_vertical = 10000
	await _settle()
	assert_eq(panel.get_node("%RestartButton").get_global_rect(), before, "Scrolling never moves the result actions offscreen")

func test_result_actions_reflow_in_a_narrow_viewport() -> void:
	viewport.size = Vector2i(640, 720)
	await _settle()
	_assert_accessible()
	assert_gt(panel.get_node("%MainMenuButton").position.y, panel.get_node("%RestartButton").position.y, "Narrow layouts stack their actions")

func test_disabled_load_is_skipped_by_keyboard_navigation() -> void:
	var load_button: Button = panel.get_node("%LoadButton")
	load_button.disabled = true
	panel.present(false, [80, 0, 0, 12])
	await _settle()
	var restart: Button = panel.get_node("%RestartButton")
	var menu: Button = panel.get_node("%MainMenuButton")
	assert_eq(restart.get_node(restart.focus_next), menu)
	assert_eq(menu.get_node(menu.focus_next), restart)
	assert_eq(restart.get_node(restart.focus_previous), menu)

func test_new_result_resets_scroll_and_discards_the_previous_snapshot() -> void:
	var rows: VBoxContainer = panel.get_node("%GameOverSnapshotRows")
	rows.add_child(Label.new())
	panel.present(false, [])
	await _settle()
	assert_eq(rows.get_child_count(), 0, "A previous match cannot leak its progress into a new result")
	assert_false(panel.get_node("%ResultStats").visible, "A result without a player has no invented statistics")
	assert_eq(panel.get_node("%ResultScroll").scroll_vertical, 0)
