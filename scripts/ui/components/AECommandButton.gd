class_name AECommandButton
extends Button

## Comando básico de unidade (Mover, Fortificar, Explorar, Fundar Cidade,
## Construir melhoria, Atravessar Portal). Visualmente distinto das habilidades:
## compacto, uma linha, sem custo/recarga em destaque; alternâncias ficam acesas.

signal command_pressed(view: UnitAbilityViewData)

var view: UnitAbilityViewData
const CHROME := preload("res://scripts/ui/HUDChromeTheme.gd")

func _init() -> void:
	theme_type_variation = &"GhostButton"
	custom_minimum_size = Vector2(0, UIThemeTokens.TARGET_MIN)
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pressed.connect(_on_pressed)

func configure_view(value: UnitAbilityViewData) -> void:
	view = value
	name = "Command_" + value.id
	text = "%s  %s" % [value.glyph, value.display_name]
	toggle_mode = value.is_toggle
	set_pressed_no_signal(value.toggled or value.state == UnitAbilityViewData.State.TARGETING)
	disabled = value.state == UnitAbilityViewData.State.BLOCKED
	tooltip_text = value.tooltip()
	for style in ["normal", "pressed", "hover_pressed"]:
		remove_theme_stylebox_override(style)
	add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT)
	add_theme_color_override("font_pressed_color", UIThemeTokens.COLOR_TEXT)
	# Founding keeps its primary emphasis within the same pixel button family.
	if value.is_primary and not disabled:
		theme_type_variation = &"PrimaryButton"
		for style in ["normal", "pressed", "hover_pressed"]:
			remove_theme_stylebox_override(style)
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_pressed_color")
	else:
		theme_type_variation = &"GhostButton"
	if value.hotkey != "":
		text = "%s  %s  [%s]" % [value.glyph, value.display_name, value.hotkey]
	set_context_style(CHROME.factor())

func set_context_style(factor: float) -> void:
	custom_minimum_size.y = 44 * factor
	if view == null:
		return
	var lit := view.toggled or view.state == UnitAbilityViewData.State.TARGETING
	var stem := "button_bronze" if view.is_primary and not disabled else "button_stone"
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var texture_name := stem
		if state == "disabled": texture_name = "button_disabled"
		elif state == "focus": texture_name = "button_focus"
		elif state in ["hover", "hover_pressed"]: texture_name += "_hover"
		elif state == "pressed" or lit: texture_name += "_pressed"
		var frame := CHROME.MENU.BASE._button(texture_name, factor)
		frame.content_margin_left = 8 * factor
		frame.content_margin_right = 8 * factor
		frame.content_margin_top = 8 * factor
		frame.content_margin_bottom = 8 * factor
		add_theme_stylebox_override(state, frame)
	add_theme_color_override("font_color", Color("c4e6a3") if lit else Color("f4e9d3"))
	add_theme_color_override("font_pressed_color", Color("c4e6a3") if lit else Color("fff2cd"))

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)

func _on_pressed() -> void:
	if view != null:
		command_pressed.emit(view)
