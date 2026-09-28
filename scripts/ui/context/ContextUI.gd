class_name ContextUI
extends RefCounted

## Blocos visuais compartilhados pelos painéis de contexto e telas estratégicas da
## UI-3 (cabeçalho de seção, linha chave/valor, barra com valor, card, estado
## vazio). Um único vocabulário evita que cada tela invente sua própria linguagem.

static func section(title: String, trailing: String = "") -> Control:
	var box := VBoxContainer.new()
	box.name = "Section_" + title.to_pascal_case()
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	box.add_child(row)
	var label := Label.new()
	label.name = "Title"
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
	label.add_theme_color_override("font_color", UIThemeTokens.COLOR_ACCENT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if not trailing.is_empty():
		var extra := Label.new()
		extra.name = "Trailing"
		extra.text = trailing
		extra.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
		extra.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		row.add_child(extra)
	var rule := ColorRect.new()
	rule.color = Color(UIThemeTokens.COLOR_BORDER, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	return box

static func label(text: String, size: int = UIThemeTokens.FONT_BODY_SMALL, color: Color = UIThemeTokens.COLOR_TEXT, wrap: bool = true) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	if wrap:
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return value

static func caption(text: String) -> Label:
	return label(text, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED)

## Linha "Legenda ........ valor" usada em rodapés e detalhes.
static func key_value(key: String, value: String, tone: String = "", tooltip: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	row.tooltip_text = tooltip
	var key_label := label(key, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED, false)
	key_label.custom_minimum_size.x = 104
	key_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(key_label)
	var color := UIThemeTokens.COLOR_TEXT
	match tone:
		"warning":
			color = UIThemeTokens.COLOR_WARNING
		"critical":
			color = UIThemeTokens.COLOR_CRITICAL
		"success":
			color = UIThemeTokens.COLOR_SUCCESS
		"muted":
			color = UIThemeTokens.COLOR_TEXT_MUTED
	var value_label := label(value, UIThemeTokens.FONT_BODY_SMALL, color)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return row

## Barra com título e valor numérico à direita (Vida, Escudo, Produção...).
static func meter(title: String, value: float, maximum: float, color: Color, value_text: String = "", height: float = 10.0) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	box.add_child(row)
	var title_label := label(title, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED, false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var number := label(value_text if not value_text.is_empty() else "%s / %s" % [_number(value), _number(maximum)], UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false)
	number.name = "Value"
	row.add_child(number)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.max_value = maxf(maximum, 0.001)
	bar.value = clampf(value, 0.0, bar.max_value)
	var back := UITheme.panel_style(UIThemeTokens.COLOR_CANVAS, Color(UIThemeTokens.COLOR_BORDER, 0.6), 1, 3, false)
	back.set_content_margin_all(0)
	var fill := UITheme.panel_style(color, color, 0, 3, false)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box

static func hp_color(value: float, maximum: float) -> Color:
	var ratio := value / maxf(maximum, 0.001)
	if ratio > 0.6:
		return UIThemeTokens.COLOR_SUCCESS
	if ratio > 0.3:
		return UIThemeTokens.COLOR_WARNING
	return UIThemeTokens.COLOR_CRITICAL

## Surface interna (card) com borda de acento opcional.
static func card(accent: Color = UIThemeTokens.COLOR_BORDER, fill: Color = UIThemeTokens.COLOR_CANVAS) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UITheme.panel_style(fill, accent, 1, UIThemeTokens.RADIUS_CONTROL, false)
	style.set_content_margin_all(UIThemeTokens.SPACE_2)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func chip(text: String, tone: int = AEStatusChip.Tone.NEUTRAL, turns: int = -1, tooltip: String = "") -> AEStatusChip:
	var value := AEStatusChip.new()
	value.set_status(text, tone, turns)
	value.tooltip_text = tooltip
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return value

static func flow(separation: int = UIThemeTokens.SPACE_1) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", separation)
	box.add_theme_constant_override("v_separation", separation)
	return box

static func empty_state(text: String) -> Label:
	var value := label(text, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT_MUTED)
	value.name = "EmptyState"
	return value

static func close_button(tooltip: String = "Fechar") -> AEIconButton:
	var button := AEIconButton.new()
	button.name = "CloseButton"
	button.text = "×"
	button.accessible_name = tooltip
	button.custom_minimum_size = Vector2(UIThemeTokens.TARGET_MIN, UIThemeTokens.TARGET_MIN)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return button

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
