extends RefCounted

## Pixel menu identity scoped to the live top bar and its popup.
const BASE := preload("res://scripts/ui/FantasyMenuTheme.gd")
const PIXEL := preload("res://assets/fonts/pixelify_sans/PixelifySans.ttf")
const ART := "res://assets/ui/global_bar/"

static func build(factor: float) -> Theme:
	var result := BASE.build(factor)
	result.set_type_variation("CaptionLabel", "Label")
	result.set_font("font", "CaptionLabel", ThemeDB.fallback_font)
	result.set_font_size("font_size", "CaptionLabel", roundi(12 * factor))
	result.set_color("font_color", "CaptionLabel", Color("f4e9d3"))
	result.set_type_variation("GhostButton", "Button")
	result.set_font("font", "GhostButton", PIXEL)
	result.set_font_size("font_size", "GhostButton", roundi(16 * factor))
	result.set_constant("icon_max_width", "GhostButton", roundi(18 * factor))
	result.set_constant("h_separation", "GhostButton", roundi(6 * factor))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var frame := result.get_stylebox(state, "SetupSmallButton").duplicate() as StyleBox
		frame.set_content_margin_all(6 * factor)
		result.set_stylebox(state, "GhostButton", frame)
	var separator := StyleBoxLine.new()
	separator.vertical = true
	separator.color = Color("657d70")
	separator.thickness = 1
	result.set_stylebox("separator", "VSeparator", separator)
	return result

static func surface() -> StyleBoxTexture:
	var frame := BASE.panel(false, 1)
	frame.set_content_margin_all(0)
	return frame

static func icon(name: String) -> Texture2D:
	return load(ART + name + ".svg") as Texture2D

static func progress_track(fill: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e0b877") if fill else Color("081a21")
	return style
