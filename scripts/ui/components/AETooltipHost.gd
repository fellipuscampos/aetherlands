class_name AETooltipHost
extends PanelContainer

## Camada de tooltip da shell. Usa o mesmo schema de `AETooltip` dos tooltips
## nativos dos componentes, para foco por teclado e hover lerem igual.

var text_label: Label
var _card: Control

func _ready() -> void:
	theme_type_variation = &"ElevatedPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if text_label == null:
		text_label = Label.new()
		text_label.name = "Text"
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size.x = 240
		text_label.visible = false
		add_child(text_label)

func show_tooltip_text(value: String, screen_position: Vector2) -> void:
	if text_label == null:
		_ready()
	text_label.text = value
	if _card != null:
		remove_child(_card)
		_card.queue_free()
		_card = null
	_card = AETooltip.make_card(value)
	if _card != null:
		add_child(_card)
	position = screen_position
	visible = not value.is_empty()

func hide_tooltip() -> void:
	visible = false
