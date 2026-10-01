class_name AECommandButton
extends Button

## Comando básico de unidade (Mover, Fortificar, Explorar, Fundar Cidade,
## Construir melhoria, Atravessar Portal). Visualmente distinto das habilidades:
## compacto, uma linha, sem custo/recarga em destaque; alternâncias ficam acesas.

signal command_pressed(view: UnitAbilityViewData)

var view: UnitAbilityViewData

func _init() -> void:
	theme_type_variation = &"GhostButton"
	custom_minimum_size = Vector2(0, UIThemeTokens.TARGET_MIN)
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
	pressed.connect(_on_pressed)

func configure_view(value: UnitAbilityViewData) -> void:
	view = value
	name = "Command_" + value.id
	text = "%s  %s" % [value.glyph, value.display_name]
	toggle_mode = value.is_toggle
	set_pressed_no_signal(value.toggled or value.state == UnitAbilityViewData.State.TARGETING)
	disabled = value.state == UnitAbilityViewData.State.BLOCKED
	tooltip_text = value.tooltip()
	var accent := UIThemeTokens.COLOR_INFO
	if value.state == UnitAbilityViewData.State.TARGETING:
		accent = UIThemeTokens.COLOR_TARGETING
	elif value.toggled:
		accent = UIThemeTokens.COLOR_SUCCESS
	var normal := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_CONTROL, false)
	var lit := UITheme.panel_style(accent.darkened(0.7), accent, 1, UIThemeTokens.RADIUS_CONTROL, false)
	add_theme_stylebox_override("normal", lit if button_pressed else normal)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT)
	add_theme_color_override("font_pressed_color", UIThemeTokens.COLOR_TEXT)
	# V3 / Etapa 2: ação primária semântica (Fundar Cidade válida) usa a variação PrimaryButton do tema — sem
	# os overrides de superfície, para o acento do design system aparecer.
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

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)

func _on_pressed() -> void:
	if view != null:
		command_pressed.emit(view)
