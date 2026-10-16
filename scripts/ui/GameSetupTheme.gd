extends RefCounted

const TITLE_THEME := preload("res://scripts/ui/TitleMenuTheme.gd")
const ART := "res://assets/ui/game_setup/"

static func build(factor: float) -> Theme:
	var result := TITLE_THEME.build(factor)
	result.set_font("font", "LineEdit", ThemeDB.fallback_font)
	result.set_font_size("font_size", "LineEdit", roundi(18 * factor))
	result.set_color("font_color", "LineEdit", Color("fff2d8"))
	result.set_color("font_placeholder_color", "LineEdit", Color("aebbb2"))
	result.set_color("caret_color", "LineEdit", Color("ffe0a2"))
	result.set_color("selection_color", "LineEdit", Color("4f6664"))
	result.set_stylebox("normal", "LineEdit", _button("button_stone_pressed", factor))
	result.set_stylebox("focus", "LineEdit", _button("button_stone_hover", factor))
	result.set_font("normal_font", "RichTextLabel", ThemeDB.fallback_font)
	result.set_font("bold_font", "RichTextLabel", ThemeDB.fallback_font)
	result.set_font_size("normal_font_size", "RichTextLabel", roundi(16 * factor))
	result.set_font_size("bold_font_size", "RichTextLabel", roundi(16 * factor))
	result.set_color("default_color", "RichTextLabel", Color("f4e9d3"))
	result.set_constant("line_separation", "RichTextLabel", roundi(6 * factor))
	for variation in ["SetupBody", "SetupMuted", "SetupKicker", "SetupHeading", "SetupTitle"]:
		result.set_type_variation(variation, "Label")
		var text_size: int = {"SetupBody":16, "SetupMuted":14, "SetupKicker":16, "SetupHeading":26, "SetupTitle":44}[variation]
		result.set_font_size("font_size", variation, roundi(text_size * factor))
		if variation in ["SetupBody", "SetupMuted"]:
			result.set_font("font", variation, ThemeDB.fallback_font)
		result.set_color("font_color", variation, Color("b5c3b8") if variation == "SetupMuted" else Color("f4e9d3"))
	result.set_color("font_color", "SetupTitle", Color("f2d19a"))
	result.set_color("font_color", "SetupKicker", Color("d8bc87"))
	result.set_type_variation("SetupPanel", "PanelContainer")
	result.set_stylebox("panel", "SetupPanel", panel(false, factor))
	for variation in ["SetupSmallButton", "SetupMapButton"]:
		result.set_type_variation(variation, "Button")
		result.set_font_size("font_size", variation, roundi(18 * factor))
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var stem: String = {"normal":"button_stone", "hover":"button_stone_hover", "pressed":"button_bronze_pressed",
				"hover_pressed":"button_bronze", "disabled":"button_disabled", "focus":"button_focus"}[state]
			result.set_stylebox(state, variation, _button(stem, factor))
	result.set_type_variation("SetupRaceCard", "Button")
	result.set_font_size("font_size", "SetupRaceCard", roundi(24 * factor))
	result.set_type_variation("SetupSmallHeading", "SetupHeading")
	result.set_font_size("font_size", "SetupSmallHeading", roundi(22 * factor))
	var separator := StyleBoxLine.new()
	separator.color = Color("627365")
	separator.thickness = 2
	result.set_stylebox("separator", "HSeparator", separator)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("142c32")
	track.set_content_margin_all(4)
	var grabber := track.duplicate() as StyleBoxFlat
	grabber.bg_color = Color("a08d62")
	result.set_stylebox("scroll", "VScrollBar", track)
	result.set_stylebox("grabber", "VScrollBar", grabber)
	result.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	result.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	return result

static func _button(stem: String, factor: float) -> StyleBoxTexture:
	var result := TITLE_THEME._frame(stem, factor)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		result.set_content_margin(side, 12 * factor)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		result.set_content_margin(side, 8 * factor)
	return result

static func panel(selected: bool, factor: float) -> StyleBoxTexture:
	var frame := StyleBoxTexture.new()
	frame.texture = load(ART + ("selected.svg" if selected else "panel.svg")) as Texture2D
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_texture_margin(side, 16)
		frame.set_content_margin(side, 16 * factor)
	return frame
