extends SceneTree

## Native loading visual/input check, with one tiny real terrain generation.
const OUTPUT := "res://docs/previews/loading/"
var failures: Array[String] = []
var main: Node
var loading: Control

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("PIXEL_LOADING_OK: ", message)
	else:
		failures.append(message)
		push_error("PIXEL_LOADING_FAIL: " + message)

func _settle() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	await _settle()
	_check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, "Screenshot: " + name)

func _fits(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect())

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var original_scale: int = settings.ui_scale_percent
	var original_motion: bool = settings.reduced_motion
	settings.ui_scale_percent = 100
	settings.reduced_motion = false
	root.size = Vector2i(1600,900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	loading = main.loading_screen
	await main._show_loading_screen("Gerando o Mapa...")
	_check(loading.visible and loading.mouse_filter == Control.MOUSE_FILTER_STOP, "Main shows loading and blocks world input")
	loading.set_progress(.55, "Semeando biomas...")
	await create_timer(.25).timeout
	_check(is_equal_approx(loading.progress_bar.value, 55) and loading.percent_label.text == "55%", "Percentage follows actual callback target")
	await _capture("loading_generation_1600x900")
	await create_timer(.25).timeout
	_check(is_equal_approx(loading.progress_bar.value, 55), "Progress does not advance on its own")
	loading.set_progress(.20, "Relevo...")
	loading.set_progress(.35, "Litorais...")
	loading.set_progress(.70, "Montanhas...")
	await create_timer(.25).timeout
	_check(is_equal_approx(loading.progress_bar.value, 70), "New update cancels previous progress tween")
	loading.set_message("Carregando Partida...")
	_check(loading.progress_bar.indeterminate and loading.percent_label.text == "AGUARDE", "Save restoration has no invented percentage")
	await _capture("loading_save_1600x900")
	settings.reduced_motion = true
	settings.accessibility_changed.emit()
	await _settle()
	_check(not loading.progress_bar.indeterminate and not loading.emblem.is_processing(), "Reduced motion freezes decorative indicators")
	loading.set_message("Gerando o Mapa...")
	loading.set_progress(.63, "Distribuindo recursos estratégicos por todos os continentes do mundo")
	_check(is_equal_approx(loading.progress_bar.value, 63), "Reduced-motion progress is immediate")
	await _capture("loading_reduced_motion")
	settings.reduced_motion = false
	for sample in [
		[Vector2i(1280,720),100,"1280x720"],
		[Vector2i(1920,1080),100,"1920x1080"],
		[Vector2i(3440,1440),100,"ultrawide"],
		[Vector2i(1280,720),150,"1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		settings.accessibility_changed.emit()
		loading.set_message("Gerando o Mapa...")
		loading.set_progress(.63, "Distribuindo recursos estratégicos por todos os continentes do mundo")
		await create_timer(.25).timeout
		await _settle()
		for control in [loading.get_node("Brand"), loading.get_node("CenterBox"), loading.progress_bar, loading.detail_label, loading.get_node("Footer")]:
			_check(_fits(control), "%s fits %s" % [control.name,sample[2]])
		_check(loading.get_node("Brand").get_global_rect().end.y < loading.get_node("CenterBox").position.y, "Brand and loading remain separate")
		_check(loading.get_node("CenterBox").get_global_rect().end.y < loading.get_node("Footer").position.y, "Loading remains above footer")
		var rect: Rect2 = loading.progress_bar.get_global_rect()
		loading.set_progress(.63, "Preparando as unidades e as cidades...")
		await _settle()
		_check(loading.progress_bar.get_global_rect() == rect, "Phase text does not move progress bar")
		await _capture("loading_generation_" + sample[2])
		loading.set_message("Carregando Partida...")
		await _capture("loading_save_" + sample[2])
	# Exercise the existing real generation callback without starting or saving a match.
	var callbacks := [0]
	loading.set_message("Gerando o Mapa...")
	await main.hex_grid.generate_map(12, 8, 2026, func(fraction, phase):
		callbacks[0] += 1
		loading.set_progress(fraction, phase))
	_check(callbacks[0] >= 7 and loading.percent_label.text == "100%" and is_equal_approx(loading.progress_bar.value,100), "Real terrain generation reaches 100 percent through callbacks")
	await _capture("loading_complete")
	await main._hide_loading_screen()
	_check(not loading.visible and loading.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Main hides loading and releases input")
	settings.ui_scale_percent = original_scale
	settings.reduced_motion = original_motion
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures}, "\t"))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
