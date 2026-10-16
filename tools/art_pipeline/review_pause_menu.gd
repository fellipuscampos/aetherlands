extends SceneTree

## UI-only review: the real pause scene over a previous frozen map capture.
## No live map generation or 3D benchmark competes with the performance work.
const OUTPUT := "res://docs/previews/pause_menu/"
var pause: Control
var hud: Control
var backdrop: TextureRect
var player: RefCounted
var failures: Array[String] = []
var captures: Array[String] = []

func _initialize() -> void: _review.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: print("PAUSE_OK: ",message)
	else:
		failures.append(message)
		push_error("PAUSE_FAIL: "+message)

func _settle() -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw

func _snapshot(name: String) -> void:
	await _settle()
	var screen := Rect2(Vector2.ZERO,Vector2(root.size))
	var card: Rect2 = pause.pause_card.get_global_rect()
	_check(screen.encloses(card),"Card stays within viewport "+name)
	_check(card.encloses(pause.resume_button.get_global_rect()),"Resume remains accessible "+name)
	_check(card.encloses(pause.session_label.get_global_rect()),"Session summary fits "+name)
	_check(card.encloses(pause.pause_content.get_node("NavigationHint").get_global_rect()),"Navigation hint fits "+name)
	_check(pause.actions_scroll.get_child(0).get_combined_minimum_size().x<=pause.actions_scroll.size.x+1,"No horizontal scrolling "+name)
	_check(pause.actions_scroll.size.y>=100,"Actions remain usable "+name)
	if name.contains("100"):
		for button in [pause.save_button,pause.load_button,pause.settings_button,pause.developer_tools_button,pause.main_menu_button,pause.quit_button]:
			_check(pause.actions_scroll.get_global_rect().encloses(button.get_global_rect()),"Action fits at standard scale: "+button.name)
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
	captures.append(name)

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	FileAccess.open(OUTPUT+".gdignore",FileAccess.WRITE).close()
	Engine.max_fps = 30
	var settings := root.get_node("Settings")
	settings.ui_scale_percent = 100
	backdrop = TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(Image.load_from_file("res://docs/previews/natural_vfx/v2_spell_veil_portal.png"))
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var civ = load("res://scripts/data/CivilizationData.gd").new()
	civ.civ_name = "Reino da Aurora"
	civ.race = "human"
	player = load("res://scripts/core/PlayerData.gd").new(civ)
	var manager := root.get_node("GameManager")
	manager.state = manager.GameState.PLAYING
	manager.human_player = player
	root.get_node("TurnManager").turn_number = 42
	hud = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	hud.visible = false
	pause = (load("res://scenes/ui/PauseMenu.tscn") as PackedScene).instantiate()
	root.add_child(pause)
	pause.open()
	_check(paused,"Opening the real pause scene freezes the tree")
	for scenario in [[1600,900,125],[1280,720,100],[1280,720,150],[960,720,100]]:
		root.size = Vector2i(scenario[0],scenario[1])
		backdrop.position = -Vector2(root.size)*Vector2(.10,.15)
		backdrop.size = Vector2(root.size)*Vector2(1.20,1.30)
		settings.ui_scale_percent = scenario[2]
		settings.accessibility_changed.emit()
		await _snapshot("pause_%dx%d_%d" % [scenario[0],scenario[1],scenario[2]])
	root.size = Vector2i(1280,720)
	settings.ui_scale_percent = 100
	settings.accessibility_changed.emit()
	pause.status_label.text = "Jogo salvo neste slot."
	pause.status_label.visible = true
	await _snapshot("saved_1280x720_100")
	pause._on_main_menu_pressed()
	await _settle()
	_check(pause.confirm_main_menu_dialog.visible and paused,"Existing exit confirmation keeps the match paused")
	root.get_texture().get_image().save_png(OUTPUT+"confirm_exit.png")
	pause.confirm_main_menu_dialog.hide()
	pause._on_settings_pressed()
	await _settle()
	_check(pause.settings_screen.visible and paused,"Current settings screen remains available while paused")
	pause.settings_screen.back_requested.emit()
	await _settle()
	_check(pause.main_page.visible,"Back returns to the themed pause surface")
	pause._on_load_button_pressed()
	await _settle()
	_check(pause.load_game_screen.visible and paused,"Loading page remains available while paused")
	pause.load_game_screen.back_requested.emit()
	pause.close()
	_check(not paused,"Resume unpauses the same tree")
	FileAccess.open(OUTPUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"captures":captures,"mode":"real UI over frozen map capture; no live 3D world"},"\t"))
	player.release_relations()
	manager.human_player = null
	pause.queue_free()
	hud.queue_free()
	backdrop.queue_free()
	await _settle()
	quit(0 if failures.is_empty() else 1)
