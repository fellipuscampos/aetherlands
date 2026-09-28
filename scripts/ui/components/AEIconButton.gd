class_name AEIconButton
extends Button

@export var accessible_name := "Ação":
	set(value):
		accessible_name = value
		tooltip_text = value

func _ready() -> void:
	theme_type_variation = &"IconButton"
	custom_minimum_size = Vector2(UIThemeTokens.TARGET_PREFERRED, UIThemeTokens.TARGET_PREFERRED)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_animate_hover.bind(true))
	mouse_exited.connect(_animate_hover.bind(false))
	pressed.connect(func(): AudioManager.play_sfx("click"))
	resized.connect(_update_pivot)
	_update_pivot()
	if tooltip_text.is_empty():
		tooltip_text = accessible_name

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _animate_hover(entered: bool) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.025 if entered else 1.0), Settings.motion_duration(UIThemeTokens.MOTION_HOVER)).set_trans(Tween.TRANS_SINE)
