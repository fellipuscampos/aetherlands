class_name AESegmentedBar
extends HBoxContainer

## Progresso discreto por segmentos (rivais satisfeitos, rodadas de Ritual,
## requisitos). Evita reduzir estados heterogêneos a uma porcentagem opaca.

func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_PASS

## `segments`: [{filled: bool, color: Color (opcional), tooltip: String (opcional)}]
func set_segments(segments: Array, height: float = 10.0) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for segment in segments:
		var rect := PanelContainer.new()
		rect.custom_minimum_size = Vector2(0, height)
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rect.mouse_filter = Control.MOUSE_FILTER_PASS
		var filled := bool(segment.get("filled", false))
		var color: Color = segment.get("color", UIThemeTokens.COLOR_SUCCESS)
		var style := UITheme.panel_style(color if filled else UIThemeTokens.COLOR_CANVAS, color if filled else UIThemeTokens.COLOR_BORDER, 1, 2, false)
		style.set_content_margin_all(0)
		rect.add_theme_stylebox_override("panel", style)
		rect.tooltip_text = String(segment.get("tooltip", ""))
		add_child(rect)

func filled_count() -> int:
	var count := 0
	for child in get_children():
		var style := (child as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if style != null and style.bg_color != UIThemeTokens.COLOR_CANVAS:
			count += 1
	return count
