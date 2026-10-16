extends RefCounted

## The live HUD shares the menu's pixel frames, with smaller readable controls.
const MENU := preload("res://scripts/ui/FantasyMenuTheme.gd")
const PIXEL := preload("res://assets/fonts/pixelify_sans/PixelifySans.ttf")
const ART := "res://assets/ui/hud_chrome/"

static func factor() -> float:
	return Settings.ui_scale_percent / 100.0

static func build(scale_factor: float) -> Theme:
	var result := UITheme.build(scale_factor)
	result.default_font = ThemeDB.fallback_font
	result.default_font_size = roundi(14 * scale_factor)
	for variation in ["Label","BodySmallLabel","UIControlLabel","MutedLabel","CaptionLabel"]:
		result.set_font("font", variation, ThemeDB.fallback_font)
	for variation in ["HeadingLabel","SubheadingLabel","SectionLabel","PanelTitle"]:
		result.set_font("font", variation, PIXEL)
		result.set_font_size("font_size", variation, roundi((22 if variation == "HeadingLabel" or variation == "PanelTitle" else 18) * scale_factor))
		result.set_color("font_color", variation, Color("e6bc77"))
	result.set_font_size("font_size", "Label", roundi(14 * scale_factor))
	for variation in ["Button","PrimaryButton","SecondaryButton","GhostButton","DangerButton","IconButton"]:
		result.set_font("font", variation, PIXEL)
		result.set_font_size("font_size", variation, roundi(16 * scale_factor))
		result.set_constant("icon_max_width", variation, roundi(20 * scale_factor))
		result.set_constant("h_separation", variation, roundi(8 * scale_factor))
		result.set_color("font_color", variation, Color("f4e9d3"))
		result.set_color("font_hover_color", variation, Color("fff4d7"))
		result.set_color("font_pressed_color", variation, Color("fff4d7"))
		result.set_color("font_disabled_color", variation, Color("87998f"))
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var stem := "button_bronze" if variation == "PrimaryButton" else "button_stone"
			if state in ["hover","hover_pressed"]: stem += "_hover"
			elif state == "pressed": stem += "_pressed"
			elif state == "disabled": stem = "button_disabled"
			elif state == "focus": stem = "button_focus"
			var style := MENU.BASE._button(stem, scale_factor)
			style.content_margin_left = 10 * scale_factor
			style.content_margin_right = 10 * scale_factor
			style.content_margin_top = 8 * scale_factor
			style.content_margin_bottom = 8 * scale_factor
			result.set_stylebox(state, variation, style)
	result.set_color("font_color", "DangerButton", Color("ffc4a9"))
	for variation in ["PanelContainer","SurfacePanel","ElevatedPanel","ModalPanel","TooltipPanel"]:
		result.set_stylebox("panel", variation, panel(scale_factor, "neutral", 12 if variation == "ModalPanel" else 8))
	result.set_font("font", "TooltipLabel", ThemeDB.fallback_font)
	result.set_font_size("font_size", "TooltipLabel", roundi(14 * scale_factor))
	result.set_stylebox("background", "ProgressBar", meter(Color("081b22")))
	result.set_stylebox("fill", "ProgressBar", meter(Color("e6bc77")))
	for scroll in ["HScrollBar","VScrollBar"]:
		var track := meter(Color("0b2027"))
		track.set_content_margin_all(6 * scale_factor)
		result.set_stylebox("scroll", scroll, track)
		for state in ["grabber","grabber_highlight","grabber_pressed"]:
			result.set_stylebox(state, scroll, meter(Color("b59b6d")))
	return result

static func panel(scale_factor: float, tone: String = "neutral", padding: float = 8) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ART + "panel_" + tone + ".svg")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, padding * scale_factor)
	return style

static func meter(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(0)
	return style

static func tone(severity: int) -> String:
	return "critical" if severity == UIEventData.Severity.CRITICAL else ("warning" if severity == UIEventData.Severity.IMPORTANT else "info")

static func color_tone(color: Color) -> String:
	if color.is_equal_approx(UIThemeTokens.COLOR_CRITICAL): return "critical"
	if color.is_equal_approx(UIThemeTokens.COLOR_WARNING) or color.is_equal_approx(UIThemeTokens.COLOR_ACCENT): return "warning"
	if color.is_equal_approx(UIThemeTokens.COLOR_INFO): return "info"
	if color.is_equal_approx(UIThemeTokens.COLOR_TARGETING): return "target"
	return "neutral"

static func icon(name: String) -> Texture2D:
	return load(ART + name + ".svg") as Texture2D

static func badge(value: Label) -> void:
	value.add_theme_stylebox_override("normal", panel(factor(), "warning", 4))
	value.custom_minimum_size = Vector2(22,22) * factor()

static func style_tab(button: Button, selected: bool, scale_factor: float) -> void:
	var stem := "button_bronze" if selected else "button_stone"
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		var texture_name := stem
		if state in ["hover", "hover_pressed"]: texture_name += "_hover"
		elif state == "pressed": texture_name += "_pressed"
		elif state == "focus": texture_name = "button_focus"
		var frame := MENU.BASE._button(texture_name, scale_factor)
		frame.content_margin_left = 8 * scale_factor
		frame.content_margin_right = 8 * scale_factor
		frame.content_margin_top = 5 * scale_factor
		frame.content_margin_bottom = 5 * scale_factor
		button.add_theme_stylebox_override(state, frame)
	button.add_theme_font_override("font", PIXEL)
	button.add_theme_font_size_override("font_size", roundi(14 * scale_factor))
	button.set_meta("inspector_font_size", 14)
	button.custom_minimum_size.y = 34 * scale_factor
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", Color("f4e9d3") if selected else Color("adbfbd"))
	button.add_theme_color_override("font_pressed_color", Color("f4e9d3"))
