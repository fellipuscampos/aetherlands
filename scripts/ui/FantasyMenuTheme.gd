extends RefCounted

## Local theme for save/settings screens, including popups and actual input widgets.
const BASE := preload("res://scripts/ui/GameSetupTheme.gd")
const ART := "res://assets/ui/menu_controls/"

static func build(factor: float) -> Theme:
	var result := BASE.build(factor)
	result.set_font("font", "Label", ThemeDB.fallback_font)
	result.set_font_size("font_size", "Label", roundi(16 * factor))
	for variation in ["SetupTitle", "SetupHeading", "SetupKicker", "SetupSmallHeading"]:
		result.set_font("font", variation, result.default_font)
	result.set_stylebox("panel", "SetupPanel", panel(false, factor))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		result.set_stylebox(state, "OptionButton", result.get_stylebox(state, "SetupSmallButton"))
		result.set_stylebox(state, "Button", result.get_stylebox(state, "SetupSmallButton"))
	result.set_font("font", "OptionButton", ThemeDB.fallback_font)
	result.set_font_size("font_size", "OptionButton", roundi(16 * factor))
	result.set_icon("arrow", "OptionButton", load(ART + "arrow.svg"))
	result.set_constant("arrow_margin", "OptionButton", 12)
	result.set_color("font_color", "OptionButton", Color("f4e9d3"))
	result.set_color("font_disabled_color", "OptionButton", Color("8b9d93"))
	result.set_stylebox("panel", "PopupMenu", panel(false, factor))
	result.set_font("font", "PopupMenu", ThemeDB.fallback_font)
	result.set_font_size("font_size", "PopupMenu", roundi(18 * factor))
	result.set_color("font_color", "PopupMenu", Color("f4e9d3"))
	result.set_color("font_hover_color", "PopupMenu", Color("fff2d8"))
	result.set_stylebox("hover", "PopupMenu", BASE._button("button_bronze", factor))
	result.set_constant("v_separation", "PopupMenu", roundi(12 * factor))
	result.set_font("font", "CheckButton", ThemeDB.fallback_font)
	result.set_font_size("font_size", "CheckButton", roundi(16 * factor))
	result.set_color("font_color", "CheckButton", Color("f4e9d3"))
	result.set_color("font_hover_color", "CheckButton", Color("fff0c0"))
	result.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	result.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	result.set_stylebox("hover", "CheckButton", BASE._button("button_stone", factor))
	result.set_stylebox("focus", "CheckButton", BASE._button("button_focus", factor))
	for state in ["checked", "checked_disabled", "unchecked", "unchecked_disabled"]:
		var texture := load(ART + ("switch_off.svg" if state.begins_with("unchecked") else "switch_on.svg")) as Texture2D
		result.set_icon(state, "CheckButton", texture)
	result.set_constant("h_separation", "CheckButton", roundi(16 * factor))
	result.set_constant("icon_max_width", "CheckButton", roundi(64 * factor))
	result.set_icon("grabber", "HSlider", load(ART + "slider_grabber.svg"))
	result.set_icon("grabber_highlight", "HSlider", load(ART + "slider_grabber_focus.svg"))
	result.set_icon("grabber_disabled", "HSlider", load(ART + "slider_grabber.svg"))
	var track := StyleBoxFlat.new()
	track.bg_color = Color("091c22")
	track.border_color = Color("647365")
	track.set_border_width_all(2)
	track.set_content_margin_all(roundi(6 * factor))
	result.set_stylebox("slider", "HSlider", track)
	var progress := track.duplicate() as StyleBoxFlat
	progress.bg_color = Color("b99559")
	result.set_stylebox("grabber_area", "HSlider", progress)
	result.set_stylebox("grabber_area_highlight", "HSlider", progress)
	result.set_stylebox("focus", "HSlider", BASE._button("button_focus", factor))
	result.set_stylebox("panel", "Panel", BASE.panel(false, factor))
	result.set_stylebox("panel", "AcceptDialog", BASE.panel(false, factor))
	var window_border := StyleBoxFlat.new()
	window_border.bg_color = Color("132a30")
	window_border.border_color = Color("9c855d")
	window_border.set_border_width_all(4)
	window_border.expand_margin_top = roundi(36 * factor)
	window_border.expand_margin_left = 4
	window_border.expand_margin_right = 4
	window_border.expand_margin_bottom = 4
	result.set_stylebox("embedded_border", "Window", window_border)
	result.set_stylebox("embedded_unfocused_border", "Window", window_border)
	result.set_color("title_color", "Window", Color("f2d19a"))
	result.set_font("title_font", "Window", result.default_font)
	result.set_font_size("title_font_size", "Window", roundi(20 * factor))
	result.set_constant("title_height", "Window", roundi(36 * factor))
	result.set_type_variation("MenuDangerButton", "SetupSmallButton")
	result.set_color("font_color", "MenuDangerButton", Color("ffc4ad"))
	result.set_stylebox("panel", "TooltipPanel", BASE.panel(false, factor))
	result.set_font("font", "TooltipLabel", ThemeDB.fallback_font)
	result.set_font_size("font_size", "TooltipLabel", roundi(16 * factor))
	result.set_color("font_color", "TooltipLabel", Color("f4e9d3"))
	return result

static func panel(selected: bool, factor: float) -> StyleBoxTexture:
	var result := BASE.panel(selected, factor)
	result.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	result.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return result
