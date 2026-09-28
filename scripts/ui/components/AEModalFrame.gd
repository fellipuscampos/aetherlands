class_name AEModalFrame
extends PanelContainer

signal close_requested

var title_label: Label
var body_host: VBoxContainer
var close_button: AEIconButton

func _ready() -> void:
	theme_type_variation = &"ModalPanel"
	custom_minimum_size = Vector2(420, 220)
	if body_host != null:
		return
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_4)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = AEIconButton.new()
	close_button.text = "×"
	close_button.accessible_name = "Fechar"
	close_button.pressed.connect(func(): close_requested.emit())
	header.add_child(close_button)
	body_host = VBoxContainer.new()
	body_host.name = "Body"
	body_host.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	root.add_child(body_host)

func set_title(value: String) -> void:
	if title_label == null:
		_ready()
	title_label.text = value
