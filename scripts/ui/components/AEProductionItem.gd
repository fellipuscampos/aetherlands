class_name AEProductionItem
extends Button

## Item do catálogo de produção: nome, categoria, custo/ETA e UMA linha de
## requisito/motivo. Recebe o dicionário montado por CityPresenter; nunca decide
## se o item pode ser produzido.

signal item_pressed(item_id: String)

const CATEGORY_GLYPHS := {"units": "◆", "buildings": "■", "development": "▲", "defense": "◈", "special": "✦"}

var item: Dictionary = {}
var glyph_label: Label
var title_label: Label
var meta_label: Label
var reason_label: Label
var state_label: Label
var _texts: VBoxContainer
var _row: HBoxContainer
var _style_state := ""

## Motivo e estado só existem quando há o que dizer (Label é o custo dominante).
func _ensure_reason() -> void:
	if reason_label != null:
		return
	reason_label = Label.new()
	reason_label.name = "Reason"
	reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reason_label.clip_text = true
	reason_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
	reason_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_WARNING)
	_texts.add_child(reason_label)

func _ensure_state() -> void:
	if state_label != null:
		return
	state_label = Label.new()
	state_label.name = "State"
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
	_row.add_child(state_label)

func _ready() -> void:
	_build()

func _build() -> void:
	if title_label != null:
		return
	theme_type_variation = &"SecondaryButton"
	custom_minimum_size = Vector2(0, 58)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UIThemeTokens.SPACE_2
	row.offset_right = -UIThemeTokens.SPACE_2
	row.offset_top = UIThemeTokens.SPACE_1
	row.offset_bottom = -UIThemeTokens.SPACE_1
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	add_child(row)
	var slot := PanelContainer.new()
	slot.name = "IconSlot"
	slot.custom_minimum_size = Vector2(34, 34)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_CANVAS, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_CONTROL, false))
	row.add_child(slot)
	glyph_label = Label.new()
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(glyph_label)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
	texts.add_child(title_label)
	meta_label = Label.new()
	meta_label.name = "Meta"
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.theme_type_variation = &"CaptionLabel"
	texts.add_child(meta_label)
	_texts = texts
	_row = row
	pressed.connect(func(): item_pressed.emit(String(item.get("id", ""))))

func configure(value: Dictionary) -> void:
	_build()
	item = value
	name = "Production_" + String(value.get("id", ""))
	glyph_label.text = String(CATEGORY_GLYPHS.get(String(value.get("category", "")), "◆"))
	title_label.text = String(value.get("name", ""))
	meta_label.text = String(value.get("meta", ""))
	var state := String(value.get("state", "available"))
	var reason := String(value.get("reason", ""))
	if not reason.is_empty() and state == "blocked":
		_ensure_reason()
	if reason_label != null:
		reason_label.text = reason
		reason_label.visible = not reason.is_empty() and state == "blocked"
	disabled = state == "blocked" or state == "current"
	tooltip_text = String(value.get("tooltip", ""))
	# Estilo só muda quando o estado muda: atualizar no lugar fica quase gratuito.
	if state == _style_state:
		return
	_style_state = state
	var accent := UIThemeTokens.COLOR_ACCENT
	if state == "current":
		_ensure_state()
	elif state_label != null:
		state_label.text = ""
	match state:
		"current":
			state_label.text = "Em produção"
			state_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_INFO)
			add_theme_stylebox_override("disabled", UITheme.panel_style(UIThemeTokens.COLOR_INFO.darkened(0.75), UIThemeTokens.COLOR_INFO, 1, UIThemeTokens.RADIUS_CONTROL, false))
			accent = UIThemeTokens.COLOR_INFO
		"blocked":
			accent = UIThemeTokens.COLOR_TEXT_DISABLED
			remove_theme_stylebox_override("disabled")
			title_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_DISABLED)
		_:
			remove_theme_stylebox_override("disabled")
			title_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT)
	glyph_label.add_theme_color_override("font_color", accent)

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)
