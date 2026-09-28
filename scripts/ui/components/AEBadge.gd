class_name AEBadge
extends Label

func _ready() -> void:
	theme_type_variation = &"CaptionLabel"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(24, 20)
	add_theme_stylebox_override("normal", UITheme.panel_style(UIThemeTokens.COLOR_ACCENT.darkened(0.25), UIThemeTokens.COLOR_ACCENT, 1, 10, false))
