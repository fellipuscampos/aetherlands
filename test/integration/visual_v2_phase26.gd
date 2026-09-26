extends Node

## Validação visual da Fase 26: seletor real para as quatro raças e resumo racial
## acessível no HUD real. Uma única execução, sem UI ou assets descartáveis.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("VISUAL_OK: ", message)
	else:
		failures.append(message)
		push_error("VISUAL_FAIL: " + message)

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png("user://" + file_name) == OK, "captura %s (%dx%d)" % [file_name, image.get_width(), image.get_height()])

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1017))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var setup: GameSetupScreen = main.get_node("UILayer/GameSetupScreen")
	main.get_node("UILayer/TitleScreen").visible = false
	setup.visible = true
	var race_buttons := {
		"human": setup.human_race_button,
		"elf": setup.elf_race_button,
		"dwarf": setup.dwarf_race_button,
		"orc": setup.orc_race_button,
	}
	for race_id in ["human", "elf", "dwarf", "orc"]:
		race_buttons[race_id].button_pressed = true
		setup._on_race_pressed(race_id)
		await get_tree().process_frame
		var effects := V2RaceBonusDatabase.effect_lines(race_id)
		var visible_text: String = setup.race_specialties_label.text
		_check(effects.size() == 2 and visible_text.contains(effects[0]) and visible_text.contains(effects[1]), "%s mostra exatamente as duas especialidades do banco" % race_id)
		_check(not visible_text.contains("v2_") and not visible_text.contains("placeholder"), "%s não expõe termos internos" % race_id)
		var panel_bottom := setup.race_specialties_label.get_global_rect().end.y
		_check(panel_bottom <= get_viewport().get_visible_rect().end.y, "%s cabe na tela sem corte vertical" % race_id)
		await _capture("phase26_setup_%s.png" % race_id)

	# Inicia pelo fluxo real com a raça Orc e mostra o tooltip real do resumo no top bar.
	GameManager.stagger_ai_turns = false
	await main._on_new_game_requested(40, 24, "Horda de Validação", 3, "normal", "orc")
	await get_tree().create_timer(0.5).timeout # deixa o fade não bloqueante da LoadingScreen terminar
	var hud: Control = main.get_node("UILayer/HUD")
	hud._refresh_stats()
	var tooltip: String = hud.stats_label.tooltip_text
	_check(GameManager.human_player.civ.race == "orc", "nova partida preserva o race id selecionado")
	_check(tooltip.contains("Raça: Horda dos Clãs Primordiais"), "HUD expõe nome visível da raça")
	for line in V2RaceBonusDatabase.effect_lines("orc"):
		_check(tooltip.contains(line), "HUD expõe: %s" % line)
	_check(not tooltip.contains("v2_") and not tooltip.contains("placeholder"), "resumo in-game não expõe termos internos")
	var center: Vector2 = (hud.stats_label as Control).get_global_rect().get_center()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.2)
	Input.warp_mouse(center)
	await get_tree().process_frame
	await get_tree().process_frame
	var hovered := get_viewport().gui_get_hovered_control()
	_check(hovered == hud.stats_label, "cursor alcança o resumo racial no HUD")
	await get_tree().create_timer(1.0).timeout
	await _capture("phase26_ingame_race_summary.png")

	print("VISUAL_SUMMARY: races=4 in_game=orc failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
