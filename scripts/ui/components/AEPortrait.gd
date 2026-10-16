class_name AEPortrait
extends PanelContainer

## Slot de retrato de unidade/cidade. Sem asset final: mostra um glyph de papel
## sobre fundo escuro com borda de acento. `set_texture` troca pelo
## retrato real sem alterar layout, reservando o espaço para a passagem de arte.
## `set_icon` (2026-10-13) mostra o SELO da unidade — o mesmo que flutua sobre ela no mapa
## (IconCatalog.unit_badge) — no lugar do glyph de texto, mantendo a legenda embaixo.

var glyph_label: Label
var caption_label: Label
var texture_rect: TextureRect
var icon_rect: TextureRect

func _ready() -> void:
	_build()

func _build() -> void:
	if glyph_label != null:
		return
	custom_minimum_size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	texture_rect = TextureRect.new()
	texture_rect.name = "PortraitTexture"
	texture_rect.visible = false
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(texture_rect)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # selo de 128 px reduzido sem serrilhar
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 9
	icon_rect.offset_right = -9
	icon_rect.offset_top = 6
	icon_rect.offset_bottom = -17
	overlay.add_child(icon_rect)
	glyph_label = Label.new()
	glyph_label.name = "Glyph"
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_label.offset_bottom = -12
	glyph_label.add_theme_font_size_override("font_size", 30)
	overlay.add_child(glyph_label)
	caption_label = Label.new()
	caption_label.name = "Caption"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption_label.offset_top = -18
	caption_label.offset_bottom = -2
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
	overlay.add_child(caption_label)

func configure(glyph: String, accent: Color, _owner_color: Color, caption: String = "") -> void:
	_build()
	glyph_label.text = glyph
	glyph_label.add_theme_color_override("font_color", accent)
	caption_label.text = caption.to_upper()
	var style := UITheme.panel_style(UIThemeTokens.COLOR_CANVAS.lerp(accent, 0.12), accent.darkened(0.2), 1, UIThemeTokens.RADIUS_PANEL, false)
	style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style)

func set_texture(texture: Texture2D) -> void:
	_build()
	texture_rect.texture = texture
	texture_rect.visible = texture != null
	glyph_label.visible = texture == null and not icon_rect.visible

## O selo da unidade no lugar do glyph de texto (null volta ao glyph).
func set_icon(texture: Texture2D) -> void:
	_build()
	icon_rect.texture = texture
	icon_rect.visible = texture != null
	glyph_label.visible = texture == null and not texture_rect.visible
