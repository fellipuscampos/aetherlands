extends Node

## Medicao simples e reproduzivel dos caminhos novos da UI-4. Nao contem
## thresholds dependentes de hardware; imprime medias para a documentacao.

const SETTINGS_SCENE := preload("res://scenes/ui/SettingsScreen.tscn")
const TITLE_SCENE := preload("res://scenes/ui/TitleScreen.tscn")

func _ready() -> void:
	call_deferred("_run")

func _average_usec(iterations: int, callable: Callable) -> float:
	var started := Time.get_ticks_usec()
	for _i in iterations:
		callable.call()
	return float(Time.get_ticks_usec() - started) / float(iterations)

func _run() -> void:
	var original_scale := Settings.ui_scale_percent
	Settings.ui_scale_percent = 100
	var theme_100 := _average_usec(300, func(): Settings.build_ui_theme())
	Settings.ui_scale_percent = 150
	var theme_150 := _average_usec(300, func(): Settings.build_ui_theme())
	Settings.ui_scale_percent = original_scale

	var title_instantiation := _average_usec(100, func():
		var screen := TITLE_SCENE.instantiate()
		screen.free()
	)
	var settings := SETTINGS_SCENE.instantiate() as SettingsScreen
	add_child(settings)
	var category_switch := _average_usec(1000, func():
		settings._show_page(1)
		settings._show_page(0)
	) / 2.0
	var slot_inspection := _average_usec(300, func(): SaveManager.inspect_slots())

	print("UI4_PERF theme100_us=%.2f theme150_us=%.2f title_instantiate_us=%.2f category_switch_us=%.2f inspect_slots_us=%.2f slots=%d" % [
		theme_100, theme_150, title_instantiation, category_switch, slot_inspection, SaveManager.inspect_slots().size(),
	])
	get_tree().quit()
