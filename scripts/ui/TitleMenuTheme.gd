extends RefCounted

## Local to MainPage; other menus continue to inherit the existing UI theme.
const ART := "res://assets/ui/title_menu/"
const PIXEL_FONT := "res://assets/fonts/pixelify_sans/PixelifySans.ttf"

static func build(factor: float) -> Theme:
	var result := Theme.new()
	result.default_font = load(PIXEL_FONT) as Font
	result.default_font_size = roundi(22 * factor)
	result.set_color("font_color", "Label", Color("f4e9d3"))
	result.set_color("font_color", "Button", Color("fff2d8"))
	result.set_color("font_hover_color", "Button", Color("fff8e8"))
	result.set_color("font_pressed_color", "Button", Color("fff0c0"))
	result.set_color("font_focus_color", "Button", Color("fff8e8"))
	result.set_color("font_disabled_color", "Button", Color("929d95"))
	result.set_font_size("font_size", "Button", roundi(24 * factor))
	result.set_constant("h_separation", "Button", roundi(18 * factor))
	result.set_constant("icon_max_width", "Button", roundi(28 * factor))
	for variation in ["Button", "TitlePrimaryButton"]:
		if variation != "Button":
			result.set_type_variation(variation, "Button")
		var prefix := "button_bronze" if variation == "TitlePrimaryButton" else "button_stone"
		result.set_stylebox("normal", variation, _frame(prefix, factor))
		result.set_stylebox("hover", variation, _frame(prefix + "_hover", factor))
		result.set_stylebox("pressed", variation, _frame(prefix + "_pressed", factor))
		result.set_stylebox("hover_pressed", variation, _frame(prefix + "_pressed", factor))
		result.set_stylebox("disabled", variation, _frame("button_disabled", factor))
		result.set_stylebox("focus", variation, _frame("button_focus", factor))
	return result

static func _frame(stem: String, factor: float) -> StyleBoxTexture:
	var frame := StyleBoxTexture.new()
	frame.texture = load(ART + stem + ".svg") as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_texture_margin(side, 16)
		frame.set_content_margin(side, 12 * factor if side in [SIDE_TOP, SIDE_BOTTOM] else 24 * factor)
	return frame
