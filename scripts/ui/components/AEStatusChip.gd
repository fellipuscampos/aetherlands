class_name AEStatusChip
extends PanelContainer

## Chip único de estado: status temporário (positivo/negativo + duração), aviso e
## traço permanente (TRAIT: contorno sem preenchimento, nunca parece botão).

enum Tone { POSITIVE, NEGATIVE, NEUTRAL, WARNING, TRAIT }

var label: Label
var tone: Tone = Tone.NEUTRAL
var duration_turns := -1

var _applied := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_ensure_label()
	if not _applied:
		_apply_tone()

func _ensure_label() -> void:
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.theme_type_variation = &"CaptionLabel"
		add_child(label)

func set_status(title: String, value_tone: Tone = Tone.NEUTRAL, turns: int = -1, icon_text: String = "") -> void:
	_ensure_label()
	tone = value_tone
	duration_turns = turns
	var parts: Array[String] = []
	if not icon_text.is_empty():
		parts.append(icon_text)
	parts.append(title)
	if turns >= 0:
		parts.append("%dT" % turns)
	label.text = " ".join(parts)
	_apply_tone()

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)

func _apply_tone() -> void:
	_applied = true
	var color := UIThemeTokens.COLOR_INFO
	var fill_factor := 0.62
	match tone:
		Tone.POSITIVE:
			color = UIThemeTokens.COLOR_SUCCESS
		Tone.NEGATIVE:
			color = UIThemeTokens.COLOR_CRITICAL
		Tone.WARNING:
			color = UIThemeTokens.COLOR_WARNING
		Tone.TRAIT:
			color = UIThemeTokens.COLOR_BORDER
	var style := UITheme.panel_style(color.darkened(fill_factor), color, 1, UIThemeTokens.RADIUS_CONTROL, false)
	if tone == Tone.TRAIT:
		style.bg_color = Color(0, 0, 0, 0)
	style.content_margin_left = UIThemeTokens.SPACE_2
	style.content_margin_right = UIThemeTokens.SPACE_2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	if label != null:
		label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT if tone != Tone.TRAIT else UIThemeTokens.COLOR_TEXT_MUTED)
