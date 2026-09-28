class_name AEStatDisplay
extends VBoxContainer

var value_label: Label
var caption_label: Label

func _ready() -> void:
	if value_label != null:
		return
	add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	value_label = Label.new()
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(value_label)
	caption_label = Label.new()
	caption_label.name = "Caption"
	caption_label.theme_type_variation = &"CaptionLabel"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption_label)

func set_stat(caption: String, value: String, detail: String = "") -> void:
	if value_label == null:
		_ready()
	value_label.text = value
	caption_label.text = caption
	tooltip_text = detail
