class_name AEPanel
extends PanelContainer

enum Surface { STANDARD, ELEVATED, MODAL }

@export var surface: Surface = Surface.STANDARD:
	set(value):
		surface = value
		_apply_surface()

func _ready() -> void:
	_apply_surface()

func _apply_surface() -> void:
	match surface:
		Surface.ELEVATED:
			theme_type_variation = &"ElevatedPanel"
		Surface.MODAL:
			theme_type_variation = &"ModalPanel"
		_:
			theme_type_variation = &"SurfacePanel"
