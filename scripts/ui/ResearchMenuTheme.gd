extends RefCounted

## Theme scoped to the in-game research overlay.
const BASE := preload("res://scripts/ui/FantasyMenuTheme.gd")
const PIXEL_FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans.ttf")
const ICONS := {
	"guardian":"shield", "warrior":"sword", "ranger":"bow", "cavalry":"horse",
	"rogue":"hood", "siege":"catapult", "sacred":"sun", "infernal":"flame",
	"necromancy":"skull", "druidism":"leaf", "arcanism":"gem", "elementalism":"bolt",
	"economy":"gem", "logistics":"horseshoe", "industry":"anvil", "academy":"star",
	"arcane":"crystals", "urbanization":"hammer", "colonization":"tent", "universal":"helm",
}

static func build(factor: float) -> Theme:
	var result := BASE.build(factor)
	for scrollbar in ["HScrollBar", "VScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("091d24")
		track.set_content_margin_all(7 * factor)
		var handle := track.duplicate() as StyleBoxFlat
		handle.bg_color = Color("a48a5f")
		handle.border_color = Color("e3c18a")
		handle.set_border_width_all(2)
		result.set_stylebox("scroll", scrollbar, track)
		result.set_stylebox("grabber", scrollbar, handle)
		var hover := handle.duplicate() as StyleBoxFlat
		hover.bg_color = Color("d2b27b")
		result.set_stylebox("grabber_highlight", scrollbar, hover)
		result.set_stylebox("grabber_pressed", scrollbar, hover)
	return result

static func icon(branch: String) -> Texture2D:
	return load("res://assets/icons/glyphs/%s.png" % ICONS.get(branch, "star")) as Texture2D

static func grain() -> TextureRect:
	var texture := TextureRect.new()
	texture.name = "PixelGrain"
	texture.texture = load("res://assets/ui/research/grain.svg")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_TILE
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture

static func panel(factor: float) -> StyleBoxTexture:
	return BASE.panel(false, factor)
