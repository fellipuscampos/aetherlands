class_name AETabStrip
extends HBoxContainer

## Abas segmentadas simples (grupo exclusivo de botões). Foco por teclado e
## ui_accept vêm do próprio Button; nenhuma lógica de conteúdo mora aqui.

signal tab_selected(key: String)

var current_key := ""
var _group := ButtonGroup.new()
var _buttons: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", UIThemeTokens.SPACE_1)

func set_tabs(entries: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	for entry in entries:
		var key := String(entry.get("key", ""))
		var button := Button.new()
		button.name = "Tab_" + key
		button.text = String(entry.get("label", key))
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_ALL
		button.theme_type_variation = &"GhostButton"
		button.custom_minimum_size = Vector2(0, UIThemeTokens.TARGET_MIN - 4)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
		button.tooltip_text = String(entry.get("tooltip", ""))
		if entry.get("badge", "") != "":
			button.text += "  " + String(entry.badge)
		button.pressed.connect(_on_pressed.bind(key))
		add_child(button)
		_buttons[key] = button
	_style_buttons()

func select(key: String, emit: bool = false) -> void:
	if not _buttons.has(key):
		return
	current_key = key
	(_buttons[key] as Button).set_pressed_no_signal(true)
	_style_buttons()
	if emit:
		tab_selected.emit(key)

func button_for(key: String) -> Button:
	return _buttons.get(key, null)

func keys() -> Array:
	return _buttons.keys()

func _on_pressed(key: String) -> void:
	current_key = key
	_style_buttons()
	tab_selected.emit(key)

func _style_buttons() -> void:
	for key in _buttons:
		var button: Button = _buttons[key]
		var selected: bool = key == current_key
		var border := UIThemeTokens.COLOR_ACCENT if selected else Color(0, 0, 0, 0)
		var style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED if selected else Color(0, 0, 0, 0), border, 0, UIThemeTokens.RADIUS_CONTROL, false)
		style.border_width_bottom = 2 if selected else 0
		style.content_margin_left = UIThemeTokens.SPACE_2
		style.content_margin_right = UIThemeTokens.SPACE_2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT if selected else UIThemeTokens.COLOR_TEXT_MUTED)
		button.add_theme_color_override("font_pressed_color", UIThemeTokens.COLOR_TEXT)
