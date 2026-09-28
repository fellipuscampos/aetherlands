extends Node

## Fase 32: smoke visual final sobre Main.tscn real. Nenhum asset ou estado
## de save é criado; a unidade distante existe só nesta execução de validação.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const TITLE_SCENE := preload("res://scenes/ui/TitleScreen.tscn")
const SETUP_SCENE := preload("res://scenes/ui/GameSetupScreen.tscn")

var failures: Array[String] = []
var captures := 0

func _ready() -> void:
	call_deferred("_run")

func _settle(frames: int = 4) -> void:
	for _i in frames:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		print("UI5_VISUAL_OK: ", message)
	else:
		failures.append(message)
		push_error("UI5_VISUAL_FAIL: " + message)

func _average_usec(iterations: int, callable: Callable) -> float:
	var started := Time.get_ticks_usec()
	for _i in iterations:
		callable.call()
	return float(Time.get_ticks_usec() - started) / float(iterations)

func _capture(name: String) -> void:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png("user://" + name)
	_check(err == OK, "captura %s (%dx%d)" % [name, image.get_width(), image.get_height()])
	captures += 1

func _fits(control: Control) -> bool:
	var viewport_rect := get_viewport().get_visible_rect()
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_rect.end.x + 1.0 and rect.end.y <= viewport_rect.end.y + 1.0

func _run() -> void:
	var original_scale := Settings.ui_scale_percent
	var original_motion := Settings.reduced_motion
	Settings.ui_scale_percent = 100
	Settings.reduced_motion = false
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await _settle()
	_check(main.title_screen.brand_panel is MarginContainer, "marca editorial não usa card")
	await _capture("ui5_1920_main_menu.png")

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	main._on_new_game_setup_requested()
	await _settle()
	_check(_fits(main.game_setup_screen.get_node("CenterBox/Box")), "setup cabe em 1920x1080")
	_check(main.game_setup_screen.get_node("CenterBox/Box/RaceSection/RaceListColumn").get_child_count() == 4, "setup mostra quatro facções comparáveis")
	await _capture("ui5_1920_game_setup.png")

	await main._on_new_game_requested(61, 61, "Reino UI-5", 1, "normal", "dwarf")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _settle(6)
	var shell: UIShell = main.hud.ui_shell
	_check(shell.global_bar.size.y <= 60.0, "barra global permanece entre 48 e 60 px")
	await _capture("ui5_1920_global_bar.png")

	var player := GameManager.human_player
	if player != null and not player.units.is_empty():
		var initial_unit: Unit = player.units[0]
		SelectionManager.select_unit(initial_unit)
		shell.context_router.flush()
		await _capture("ui5_1920_unit_context.png")
		shell.context_router._show_tile(initial_unit.coord)
		await _capture("ui5_1920_tile_context.png")
		var city := WorldSetup.found_city_from_settler(GameManager.hex_grid, initial_unit) if initial_unit.unit_data.can_found_city else null
		if city != null:
			shell.context_router.open_city(city)
			await _capture("ui5_1920_city_context.png")
	await _capture("ui5_1920_minimap_early.png")
	await _capture("ui5_1920_bottom_hud.png")

	shell.open_destination(NavigationManager.EMPIRE)
	await _settle()
	_check(_fits(shell.empire_screen.frame), "Império respeita margens seguras")
	await _capture("ui5_1920_empire.png")
	shell.close_strategic_overlay()
	shell.open_destination(NavigationManager.DIPLOMACY)
	await _settle()
	_check(_fits(shell.diplomacy_screen.frame), "Diplomacia respeita margens seguras")
	await _capture("ui5_1920_diplomacy.png")
	shell.close_strategic_overlay()
	shell.victory_screen.show_summary()
	shell.open_destination(NavigationManager.VICTORY)
	await _settle()
	_check(shell.victory_screen.frame.size.y <= 540.0, "resumo de Vitória não vira modal gigante")
	await _capture("ui5_1920_victory_summary.png")
	shell.victory_screen.show_detail("domination")
	await _capture("ui5_1920_victory_detail.png")
	shell.close_strategic_overlay()

	for definition in [
		["Cidade fundada", "A fronteira do reino avançou.", UIEventData.Severity.IMPORTANT],
		["Pesquisa concluída", "Uma nova doutrina está disponível.", UIEventData.Severity.INFO],
		["Atenção estratégica", "Uma ameaça foi avistada perto da fronteira.", UIEventData.Severity.CRITICAL],
	]:
		UIEvents.publish(UIEventData.create("ui5_visual", UIEventData.Category.SYSTEM, definition[2], definition[0], definition[1]))
	shell.toggle_event_center()
	await _settle()
	_check(shell.context_router.is_suppressed(), "Event Center suprime o contexto sem apagar seleção")
	_check(shell.event_center.size.y <= 580.0, "Event Center adapta a altura ao histórico curto (%.0f px; preferido %.0f px; mínimo %.0f px; anchors %.1f/%.1f; offsets %.0f/%.0f)" % [shell.event_center.size.y, shell.event_center.preferred_height(), shell.event_center.get_combined_minimum_size().y, shell.event_center.anchor_top, shell.event_center.anchor_bottom, shell.event_center.offset_top, shell.event_center.offset_bottom])
	await _capture("ui5_1920_event_center.png")
	shell.close_auxiliary_drawer()
	await _settle()
	_check(not shell.context_router.is_suppressed() and shell.context_router.mode != ContextRouter.MODE_NONE, "fechar Event Center restaura o contexto atual")
	await _capture("ui5_1920_context_restored.png")

	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _settle()
	_check(shell.global_bar._compact, "barra usa navegação compacta em 1280")
	await _capture("ui5_1280_hud.png")
	main.pause_menu.open()
	await _capture("ui5_1280_pause.png")
	main.pause_menu._on_settings_pressed()
	await _settle()
	_check(not shell.bottom_host.visible and shell.context_router.is_suppressed(), "Settings é exclusiva sobre HUD e contexto")
	await _capture("ui5_1280_settings.png")
	main.pause_menu.close()

	DisplayServer.window_set_size(Vector2i(1600, 900))
	await _settle()
	_check(shell.global_bar.size.y <= 60.0 and shell.context_width <= 460.0, "baseline intermediária preserva barra e mapa")
	await _capture("ui5_1600_hud.png")

	DisplayServer.window_set_size(Vector2i(2560, 1080))
	await _settle()
	_check(shell.context_width <= 460.0, "ultrawide expande mapa sem esticar contexto")
	await _capture("ui5_2560_hud.png")

	# Exercita a expansão real do frame, com uma unidade própria que permanece
	# distante por duas viradas lógicas. O mapa e a neblina continuam reais.
	var grid := GameManager.hex_grid
	if grid != null and player != null:
		var candidates: Array = grid.tiles.keys().filter(func(coord): return not grid.tiles[coord].blocks_land_units() and grid.get_unit_at(coord) == null and not grid.lairs_by_coord.has(coord))
		candidates.sort()
		if not candidates.is_empty():
			var far_coord: Vector2i = candidates[candidates.size() - 1]
			var distant := grid.spawn_unit(far_coord, UnitDatabase.create_unit("warrior"), player)
			if distant != null:
				main.hud.minimap._update_adaptive_frame(grid, false, true)
				main.hud.minimap._update_adaptive_frame(grid, false, true)
				grid.recompute_fog(player)
				main.hud.minimap._rebuild_terrain()
	await _capture("ui5_2560_minimap_expanded.png")

	# Medicoes simples e reproduziveis dos caminhos refinados. Nao ha thresholds
	# dependentes de hardware: os numeros servem para comparacao documental.
	var title_instantiation := _average_usec(100, func():
		var screen := TITLE_SCENE.instantiate()
		screen.free()
	)
	var setup_instantiation := _average_usec(100, func():
		var screen := SETUP_SCENE.instantiate()
		screen.free()
	)
	var global_bar_refresh := _average_usec(500, func(): shell.global_bar.refresh(player))
	var strategic_layout := _average_usec(1000, func(): shell.empire_screen._layout())
	var context_switch := 0.0
	if not player.cities.is_empty() and not player.units.is_empty():
		context_switch = _average_usec(100, func():
			shell.context_router._show_tile(player.cities[0].coord)
			shell.context_router.open_city(player.cities[0])
		) / 2.0
	var minimap_frame := _average_usec(500, func(): main.hud.minimap._update_adaptive_frame(GameManager.hex_grid, false, false))
	var shell_refresh := _average_usec(100, func(): shell.refresh_live_state())
	UIEvents.clear_session()
	for i in 200:
		var event := UIEventData.create("ui5_benchmark", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Evento %03d" % i, "Linha de histórico para medir o layout final.")
		event.order = i + 1
		UIEvents._history.append(event)
	var event_center_200 := _average_usec(10, func(): shell.event_center.refresh())
	print("UI5_PERF title_us=%.2f setup_us=%.2f global_bar_refresh_us=%.2f strategic_layout_us=%.2f event_center_200_us=%.2f context_switch_us=%.2f minimap_frame_us=%.2f shell_refresh_us=%.2f" % [
		title_instantiation, setup_instantiation, global_bar_refresh, strategic_layout,
		event_center_200, context_switch, minimap_frame, shell_refresh,
	])

	Settings.ui_scale_percent = original_scale
	Settings.reduced_motion = original_motion
	print("UI5_VISUAL_SUMMARY: captures=", captures, " resolutions=1280x720,1600x900,1920x1080,2560x1080 failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
