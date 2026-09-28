class_name AEProgressBar
extends VBoxContainer

var title_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
	if progress_bar != null:
		return
	title_label = Label.new()
	title_label.theme_type_variation = &"CaptionLabel"
	add_child(title_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 12
	progress_bar.show_percentage = false
	add_child(progress_bar)

func set_progress(title: String, value: float, maximum: float) -> void:
	if progress_bar == null:
		_ready()
	title_label.text = title
	progress_bar.max_value = maxf(maximum, 1.0)
	progress_bar.value = clampf(value, 0.0, progress_bar.max_value)
