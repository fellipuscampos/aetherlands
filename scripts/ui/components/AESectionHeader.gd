class_name AESectionHeader
extends HBoxContainer

var title_label: Label
var action_host: HBoxContainer

func _ready() -> void:
	if title_label != null:
		return
	add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = &"SectionLabel"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(title_label)
	action_host = HBoxContainer.new()
	action_host.name = "Actions"
	action_host.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	add_child(action_host)

func set_title(value: String) -> void:
	if title_label == null:
		_ready()
	title_label.text = value
