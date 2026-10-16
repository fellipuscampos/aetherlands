extends PanelContainer

## Result presentation only. The HUD owns outcomes, actions and the frozen snapshot.
const CHROME := preload("res://scripts/ui/HUDChromeTheme.gd")
const MENU := preload("res://scripts/ui/FantasyMenuTheme.gd")
const STAT_NAMES := ["Turnos", "Cidades", "Unidades", "Ouro"]

var _stat_values: Array[Label] = []
var _layout_queued := false

func _ready() -> void:
	for caption in STAT_NAMES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.theme_type_variation = &"ResultValue"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(value)
		_stat_values.append(value)
		var label := Label.new()
		label.text = caption
		label.theme_type_variation = &"MutedLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		%ResultStats.add_child(column)
	_apply_theme()
	Settings.accessibility_changed.connect(_apply_theme)
	get_viewport().size_changed.connect(_queue_layout)
	visibility_changed.connect(_on_visibility_changed)

func present(victory: bool, stats: Array) -> void:
	%GameOverLabel.text = "VITÓRIA" if victory else "DERROTA"
	%GameOverLabel.add_theme_color_override("font_color", Color("f2d19a") if victory else Color("e6aa92"))
	%ResultStats.visible = stats.size() == STAT_NAMES.size()
	for index in mini(stats.size(), _stat_values.size()):
		_stat_values[index].text = str(stats[index])
	%ResultScroll.scroll_vertical = 0
	# A second game must not display the first game's snapshot, even for one frame.
	for child in %GameOverSnapshotRows.get_children():
		%GameOverSnapshotRows.remove_child(child)
		child.queue_free()
	_queue_layout()
	%RestartButton.call_deferred("grab_focus")

func _apply_theme() -> void:
	var factor := Settings.ui_scale_factor()
	theme = CHROME.build(factor)
	for role in ["ResultTitle", "ResultValue"]:
		theme.set_type_variation(role, "PanelTitle")
		theme.set_font_size("font_size", role, roundi((44 if role == "ResultTitle" else 28) * factor))
	theme.set_type_variation("ResultSubtitle", "Label")
	theme.set_font_size("font_size", "ResultSubtitle", roundi(18 * factor))
	var frame := MENU.panel(false, factor)
	frame.set_content_margin_all(22 * factor)
	add_theme_stylebox_override("panel", frame)
	_queue_layout()

func _on_visibility_changed() -> void:
	if visible:
		_queue_layout()

func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree(): return
	_layout_queued = true
	_layout_for_viewport.call_deferred()

## Event driven: no polling, animation, map traversal or progress recalculation.
func _layout_for_viewport() -> void:
	_layout_queued = false
	if not is_node_ready(): return
	var factor := Settings.ui_scale_factor()
	var viewport := get_viewport_rect().size
	var extent := Vector2(minf(860 * factor, maxf(1, viewport.x - 48)), minf(760 * factor, maxf(1, viewport.y - 48)))
	set_anchor(SIDE_LEFT, 0.5)
	set_anchor(SIDE_RIGHT, 0.5)
	set_anchor(SIDE_TOP, 0.5)
	set_anchor(SIDE_BOTTOM, 0.5)
	offset_left = -extent.x * 0.5
	offset_right = extent.x * 0.5
	offset_top = -extent.y * 0.5
	offset_bottom = extent.y * 0.5
	%ResultContent.add_theme_constant_override("separation", roundi(12 * factor))
	%GameOverSnapshotRows.add_theme_constant_override("separation", roundi(8 * factor))
	%ResultActions.add_theme_constant_override("separation", roundi(10 * factor))
	%ResultActions.vertical = viewport.x < 700 * factor
	for row in %GameOverSnapshotRows.get_children():
		if row is HBoxContainer and row.get_child_count() == 3 and row.get_child(1) is ProgressBar:
			row.get_child(1).custom_minimum_size = Vector2(120, 6) * factor
			row.get_child(2).custom_minimum_size.x = 48 * factor
	var buttons: Array[Button] = [%RestartButton, %LoadButton, %MainMenuButton]
	var focusable: Array[Button] = []
	for button in buttons:
		button.custom_minimum_size.y = 44 * factor
		if not button.disabled: focusable.append(button)
	for index in focusable.size():
		var next := focusable[(index + 1) % focusable.size()]
		var previous := focusable[posmod(index - 1, focusable.size())]
		for direction in ["focus_next", "focus_neighbor_right", "focus_neighbor_bottom"]:
			focusable[index].set(direction, focusable[index].get_path_to(next))
		for direction in ["focus_previous", "focus_neighbor_left", "focus_neighbor_top"]:
			focusable[index].set(direction, focusable[index].get_path_to(previous))
