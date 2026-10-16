class_name ContextPanelStyle
extends RefCounted

## Local inspector styling; strategic screens keep their own density and theme.
const CHROME := preload("res://scripts/ui/HUDChromeTheme.gd")

static func apply(panel: Control) -> void:
	var factor := CHROME.factor()
	panel.theme = CHROME.build(factor)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_constant_override("separation", roundi((8 if is_compact(panel) else 10) * factor))
	var header := panel.get_node_or_null("Header") as HBoxContainer
	if header != null:
		header.add_theme_constant_override("separation", roundi(10 * factor))
		var portrait := header.get_node_or_null("Portrait") as AEPortrait
		if portrait != null:
			portrait.custom_minimum_size = Vector2(56,56) * factor
			portrait.add_theme_stylebox_override("panel", CHROME.panel(factor, "neutral", 0))
			portrait.caption_label.visible = false
			portrait.glyph_label.offset_bottom = 0
			portrait.icon_rect.offset_left = 6 * factor
			portrait.icon_rect.offset_right = -6 * factor
			portrait.icon_rect.offset_top = 6 * factor
			portrait.icon_rect.offset_bottom = -6 * factor
	var scroll := panel.get_node_or_null("Scroll") as ScrollContainer
	if scroll != null:
		scroll.follow_focus = true
		scroll.custom_minimum_size.y = 80 * factor
		scroll.add_theme_constant_override("h_separation", roundi(8 * factor))
	var body := panel.get_node_or_null("Scroll/Body") as VBoxContainer
	if body != null:
		body.add_theme_constant_override("separation", roundi(12 * factor))
	_apply_children(panel, factor)
	for label_name in ["CityName", "UnitName", "TileTitle", "Subtitle"]:
		var label := panel.find_child(label_name, true, false) as Label
		if label != null:
			label.max_lines_visible = 1 if is_compact(panel) else 2
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = label.text
	layout(panel)

static func _apply_children(node: Node, factor: float) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if label.has_theme_font_size_override("font_size"):
				if not label.has_meta("inspector_font_size"):
					label.set_meta("inspector_font_size", label.get_theme_font_size("font_size"))
				label.add_theme_font_size_override("font_size", roundi(float(label.get_meta("inspector_font_size")) * factor))
			if label.name in ["CityName", "UnitName", "TileTitle"]:
				label.add_theme_font_override("font", CHROME.PIXEL)
				label.add_theme_font_size_override("font_size", roundi(22 * factor))
				label.add_theme_color_override("font_color", Color("f4e9d3"))
			elif label.name == "Title" and label.get_parent() is HBoxContainer:
				label.set_meta("inspector_font_size", 14)
				label.add_theme_font_override("font", CHROME.PIXEL)
				label.add_theme_font_size_override("font_size", roundi(14 * factor))
			if label.custom_minimum_size.x > 0:
				if not label.has_meta("inspector_min_width"):
					label.set_meta("inspector_min_width", label.custom_minimum_size.x)
				label.custom_minimum_size.x = float(label.get_meta("inspector_min_width")) * factor
		if child is AEStatItem:
			var stat := child as AEStatItem
			stat.custom_minimum_size.y = 48 * factor
			var surface := CHROME.meter(Color("10262c"))
			surface.border_color = Color("36565a")
			surface.set_border_width_all(1)
			surface.set_content_margin_all(6 * factor)
			stat.add_theme_stylebox_override("panel", surface)
			stat.caption_label.clip_text = true
			stat.caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if child is AEAbilityButton:
			(child as AEAbilityButton).set_context_style(factor)
		if child is AECommandButton:
			(child as AECommandButton).set_context_style(factor)
		if child is AEProductionItem:
			(child as AEProductionItem).set_context_style(factor)
		if child is AETabStrip:
			(child as AETabStrip).set_context_style(factor)
		if child is AEIconButton and child.name == "CloseButton":
			(child as Control).custom_minimum_size = Vector2(36,36) * factor
		if child is HFlowContainer:
			child.add_theme_constant_override("h_separation", roundi(6 * factor))
			child.add_theme_constant_override("v_separation", roundi(4 * factor))
		_apply_children(child, factor)

static func grid(grid: GridContainer, cell_width: float, maximum: int) -> void:
	grid.set_meta("inspector_cell_width", cell_width)
	grid.set_meta("inspector_columns", maximum)
	grid.add_theme_constant_override("h_separation", roundi(6 * CHROME.factor()))
	grid.add_theme_constant_override("v_separation", roundi(6 * CHROME.factor()))
	grid.resized.connect(func(): _layout_grid(grid))

static func is_compact(panel: Control) -> bool:
	return panel.get_viewport_rect().size.y / CHROME.factor() < 560

static func _layout_grid(grid: GridContainer, fallback_width: float = 0) -> void:
	var factor := CHROME.factor()
	var available := grid.size.x if grid.size.x > 0 else fallback_width
	if available <= 0:
		return
	var gap := 6 * factor
	var cell := float(grid.get_meta("inspector_cell_width")) * factor
	var columns := clampi(floori((available + gap) / (cell + gap)), 1, int(grid.get_meta("inspector_columns")))
	if columns != grid.columns:
		grid.columns = columns

static func layout(panel: Control) -> void:
	var factor := CHROME.factor()
	for node in panel.find_children("*", "PanelContainer", true, false):
		if not node is AEStatusChip:
			continue
		var chip := node as AEStatusChip
		chip.label.clip_text = true
		chip.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var font := chip.label.get_theme_font("font")
		var width := font.get_string_size(chip.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip.label.get_theme_font_size("font_size")).x + 18 * factor
		chip.custom_minimum_size.x = minf(width, maxf(200 * factor, panel.size.x - 12 * factor))
	for node in panel.find_children("*", "GridContainer", true, false):
		var grid := node as GridContainer
		if not grid.has_meta("inspector_columns"):
			continue
		_layout_grid(grid, maxf(240, panel.size.x))

static func tab(button: Button, selected: bool, factor: float) -> void:
	CHROME.style_tab(button, selected, factor)
