extends Node

## Fase 33A.2 — prova executável do bind canônico do UIShell nos quatro
## ciclos que substituem PlayerData: nova partida, load, restart e menu→nova.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []
var slot_id := ""

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PHASE33A2_OK: ", message)
	else:
		failures.append(message)
		push_error("PHASE33A2_FAIL: " + message)

func _settle(frames: int = 3) -> void:
	for _i in frames:
		await get_tree().process_frame

func _assert_bound(main: Node, expected: PlayerData, label: String) -> void:
	var shell: UIShell = main.hud.ui_shell
	_check(shell.attention_service.player() == expected, "%s liga Attention ao PlayerData humano atual" % label)
	_check(shell.attention_service.next_required() != null and shell.attention_service.next_required().id == "research_idle", "%s expõe pesquisa ociosa sem bind manual" % label)

func _run() -> void:
	seed(33002)
	var main := MAIN_SCENE.instantiate()
	main.name = "Main"
	add_child(main)
	await _settle()
	await main._on_new_game_requested(41, 41, "Lifecycle F33A2", 1, "normal", "human")
	GameManager.stagger_ai_turns = false
	var new_player := GameManager.human_player
	_assert_bound(main, new_player, "Nova partida")

	var settler: Unit = new_player.units.filter(func(unit): return unit.unit_data.can_found_city)[0]
	var city := WorldSetup.found_city_from_settler(GameManager.hex_grid, settler)
	_check(city != null, "capital criada antes do save de lifecycle")
	slot_id = "phase33a2_lifecycle_%d" % Time.get_ticks_msec()
	_check(SaveManager.save_to_slot(GameManager.hex_grid, slot_id), "save temporário de lifecycle criado")

	await main._on_restart_requested()
	var restarted_player := GameManager.human_player
	_check(restarted_player != new_player, "restart substitui PlayerData")
	_assert_bound(main, restarted_player, "Restart")

	await main._on_pause_load_requested(slot_id)
	var loaded_player := GameManager.human_player
	_check(loaded_player != restarted_player, "load substitui PlayerData")
	_assert_bound(main, loaded_player, "Load")

	main._on_pause_main_menu_requested()
	_check(main.title_screen.visible and not main.hud.visible, "retorno ao menu encerra a superfície da partida")
	await main._on_new_game_requested(41, 41, "Lifecycle F33A2 B", 1, "normal", "human")
	var menu_new_player := GameManager.human_player
	_check(menu_new_player != loaded_player, "menu→nova partida substitui PlayerData")
	_assert_bound(main, menu_new_player, "Menu→nova partida")

	SaveManager.delete_slot(slot_id)
	print("PHASE33A2_LIFECYCLE: failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
