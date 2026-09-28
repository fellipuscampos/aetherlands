class_name AEStatItem
extends PanelContainer

## Stat compacto (ícone/fallback + rótulo curto + valor). Substitui a linha corrida
## "HP 18 | ATK 3 | DEF 4" por blocos escaneáveis; o detalhe mora no tooltip.

var glyph_label: Label
var caption_label: Label
var value_label: Label
var _icon: TextureRect

func _ready() -> void:
	_build()

func _build() -> void:
	if value_label != null:
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 48)
	var style := UITheme.panel_style(UIThemeTokens.COLOR_CANVAS, Color(UIThemeTokens.COLOR_BORDER, 0.6), 1, UIThemeTokens.RADIUS_CONTROL, false)
	style.set_content_margin_all(UIThemeTokens.SPACE_1 + 2)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_1 + 2)
	add_child(row)
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(20, 0)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_box)
	glyph_label = Label.new()
	glyph_label.name = "Glyph"
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY)
	icon_box.add_child(glyph_label)
	_icon = TextureRect.new()
	_icon.visible = false
	_icon.custom_minimum_size = Vector2(18, 18)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	row.add_child(texts)
	caption_label = Label.new()
	caption_label.name = "Caption"
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.theme_type_variation = &"CaptionLabel"
	texts.add_child(caption_label)
	value_label = Label.new()
	value_label.name = "Value"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY)
	texts.add_child(value_label)

func set_stat(caption: String, value: String, glyph: String = "", tooltip: String = "", color: Color = UIThemeTokens.COLOR_TEXT) -> void:
	_build()
	caption_label.text = caption
	value_label.text = value
	value_label.add_theme_color_override("font_color", color)
	glyph_label.text = glyph
	glyph_label.add_theme_color_override("font_color", color if color != UIThemeTokens.COLOR_TEXT else UIThemeTokens.COLOR_ACCENT)
	tooltip_text = tooltip

func set_icon_texture(texture: Texture2D) -> void:
	_build()
	_icon.texture = texture
	_icon.visible = texture != null
	glyph_label.visible = texture == null

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)
