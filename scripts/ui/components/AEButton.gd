class_name AEButton
extends Button

enum Kind { PRIMARY, SECONDARY, DANGER, GHOST }

@export var kind: Kind = Kind.SECONDARY:
	set(value):
		kind = value
		_apply_kind()

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, UIThemeTokens.TARGET_MIN)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_animate_hover.bind(true))
	mouse_exited.connect(_animate_hover.bind(false))
	pressed.connect(func(): AudioManager.play_sfx("click"))
	resized.connect(_update_pivot)
	_update_pivot()
	_apply_kind()

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _animate_hover(entered: bool) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.015 if entered else 1.0), Settings.motion_duration(UIThemeTokens.MOTION_HOVER)).set_trans(Tween.TRANS_SINE)

func _apply_kind() -> void:
	match kind:
		Kind.PRIMARY:
			theme_type_variation = &"PrimaryButton"
		Kind.DANGER:
			theme_type_variation = &"DangerButton"
		Kind.GHOST:
			theme_type_variation = &"GhostButton"
		_:
			theme_type_variation = &"SecondaryButton"
