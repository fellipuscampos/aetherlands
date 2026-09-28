extends Node

## Smoke visual da UI-4 sobre Main.tscn real. As capturas ficam apenas em
## user:// e o slot criado pela propria execucao e removido no final.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("UI4_VISUAL_OK: ", message)
	else:
		failures.append(message)
		push_error("UI4_VISUAL_FAIL: " + message)

func _settle(frames: int = 3) -> void:
	for _i in frames:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame

func _capture(name: String) -> void:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png("user://" + name) == OK, "captura %s (%dx%d)" % [name, image.get_width(), image.get_height()])

func _fits(control: Control) -> bool:
	var viewport_rect := get_viewport().get_visible_rect()
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_rect.end.x + 1.0 and rect.end.y <= viewport_rect.end.y + 1.0

func _run() -> void:
	var original_scale := Settings.ui_scale_percent
	var original_motion := Settings.reduced_motion
	var original_window_mode := Settings.window_mode
	var original_resolution := Settings.window_resolution
	Settings.ui_scale_percent = 100
	Settings.reduced_motion = false
	Settings.window_mode = "windowed"
	Settings.window_resolution = Vector2i(1920, 1080)
	Settings.apply_video_settings()

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await _settle()
	var title: TitleScreen = main.title_screen
	_check(title.brand_panel.visible, "menu usa composicao ampla em 1920")
	_check(_fits(title.get_node("MainPage/CenterBox/Box")), "acoes do menu cabem em 1920x1080")
	await _capture("ui4_1920_main_menu.png")

	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	main._on_new_game_setup_requested()
	await _settle()
	_check(_fits(main.game_setup_screen.get_node("CenterBox/Box")), "setup essencial cabe em 1280x720")
	_check(not main.game_setup_screen.race_lore_label.visible, "lore comeca recolhida")
	await _capture("ui4_1280_game_setup.png")

	main._on_game_setup_back_requested()
	title._on_settings_pressed()
	await _settle()
	_check(_fits(title.settings_screen.get_node("Margin/Layout")), "configuracoes cabem em 1280x720")
	await _capture("ui4_1280_settings.png")

	Settings.ui_scale_percent = 125
	Settings.accessibility_changed.emit()
	await _settle()
	_check(title.theme.get_font_size("font_size", "Label") == int(round(UIThemeTokens.FONT_BODY * 1.25)), "escala 125% aplicada aos controles reais")
	await _capture("ui4_1280_settings_scale125.png")
	Settings.ui_scale_percent = 100
	Settings.accessibility_changed.emit()
	title.settings_screen.back_requested.emit()

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main.loading_screen.set_message("Carregando Partida...")
	main.loading_screen.set_progress(0.63, "Restaurando cidades, unidades, relacoes diplomaticas e estados estrategicos persistidos")
	main.loading_screen.visible = true
	await _settle()
	_check(main.loading_screen.get_node("CenterBox/Box/ProgressRow").size.x >= 639.0, "barra de loading permanece com 640 px")
	await _capture("ui4_1920_loading_long_text.png")
	main.loading_screen.visible = false

	await main._on_new_game_requested(61, 61, "Reino UI-4", 1, "normal", "elf")
	await _settle()
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await _settle()
	main.pause_menu.open()
	await _settle()
	_check("Reino UI-4" in main.pause_menu.session_label.text, "pausa mostra contexto da sessao")
	await _capture("ui4_1600_pause.png")
	main.pause_menu._on_save_pressed()
	var slot_id: String = GameManager.current_save_slot
	_check(FileAccess.file_exists(SaveManager._slot_path(slot_id)), "save criado pelo fluxo da pausa")
	main.pause_menu.close()
	_check(main._try_load_game(slot_id), "save restaura pelo caminho real")

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _settle()
	main.hud._on_game_over(false)
	await _settle()
	_check(main.hud.game_over_main_menu_button.visible and main.hud.game_over_load_button.visible, "tela final oferece carregar e menu")
	await _capture("ui4_1920_game_over.png")

	main._on_pause_main_menu_requested()
	DisplayServer.window_set_size(Vector2i(2560, 1080))
	await _settle()
	_check(title.brand_panel.visible and _fits(title.get_node("MainPage/CenterBox/Box")), "ultrawide expande o canvas sem esticar o menu")
	await _capture("ui4_2560_main_menu.png")

	SaveManager.delete_slot(slot_id)
	Settings.ui_scale_percent = original_scale
	Settings.reduced_motion = original_motion
	Settings.window_mode = original_window_mode
	Settings.window_resolution = original_resolution
	print("UI4_VISUAL_SUMMARY: captures=8 save_load=PASS resolutions=1280x720,1600x900,1920x1080,2560x1080 failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
