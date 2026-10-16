extends SceneTree

const OUTPUT := "res://docs/previews/context_panels/"
var failures: Array[String] = []
var main: Node
var shell: Control
var city: Node
var origin := Vector2i.ZERO
var player: RefCounted
var settlers: Array[Node] = []
var soldier: Node
var mage: Node
var monster: Node
var builder: Node
var champion: Node
var resource_coord := Vector2i.ZERO
var captures: Array[Dictionary] = []

func _initialize() -> void:
	_review.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition: print("CONTEXT_OK: ", message)
	else:
		failures.append(message)
		push_error("CONTEXT_FAIL: " + message)

func _settle() -> void:
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	await _settle()
	var host: Rect2 = shell.context_host.get_global_rect()
	var panel: Control = shell.context_router.primary_panel()
	var scroll: ScrollContainer = panel.get_node("Scroll")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(host), "Inspector fits " + name)
	_check(host.position.y >= shell.global_bar.get_global_rect().end.y + 8, "Inspector clears top bar " + name)
	_check(host.end.y <= shell.turn_controller.get_global_rect().position.y - 8, "Inspector clears footer " + name)
	_check(panel.get_combined_minimum_size().x <= host.size.x + 1, "Content width fits " + name)
	_check(scroll.size.y >= 79 * root.get_node("Settings").ui_scale_percent / 100.0, "Scrollable content remains usable " + name)
	if panel == shell.context_router.city_panel and panel.current_tab == "production":
		_check(panel.production_summary.get_global_rect().end.y <= scroll.get_global_rect().position.y, "Production summary and categories are pinned " + name)
	if panel == shell.context_router.unit_panel:
		_check(panel.get_node("VitalsHost").get_global_rect().end.y <= scroll.get_global_rect().position.y, "Health and attributes are pinned " + name)
	_check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, "Capture " + name)
	captures.append({"name":name,"host":str(host),"scroll_height":scroll.size.y})

func _unit_coord(far: bool = false) -> Vector2i:
	var city_site = load("res://scripts/core/CitySite.gd")
	for coord in main.hex_grid.tiles:
		var tile = main.hex_grid.get_tile(coord)
		if tile.terrain_type not in [7,8] or main.hex_grid.get_unit_at(coord) != null or main.hex_grid.get_city_at(coord) != null: continue
		if far and city_site.rejection_reason(main.hex_grid, coord, player) != "": continue
		return coord
	return origin

func _select_unit(unit: Node) -> void:
	shell.context_router.open_unit(unit)
	await _settle()

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var settings := root.get_node("Settings")
	var previous_scale: int = settings.ui_scale_percent
	settings.ui_scale_percent = 100
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,900)
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	await main.hex_grid.generate_map(32,24,2026)
	var civ = load("res://scripts/data/CivilizationData.gd").new()
	civ.race = "human"
	civ.civ_name = "Aurora"
	civ.color = Color("688fb3")
	player = load("res://scripts/core/PlayerData.gd").new(civ)
	var manager := root.get_node("GameManager")
	manager.players.assign([player])
	manager.human_player = player
	manager.hex_grid = main.hex_grid
	manager.state = manager.GameState.PLAYING
	var nearest := INF
	for coord in main.hex_grid.tiles:
		if main.hex_grid.get_tile(coord).terrain_type not in [7,8]: continue
		var distance := float(coord.x*coord.x + coord.y*coord.y)
		if distance < nearest:
			nearest = distance
			origin = coord
	city = main.hex_grid.found_city(origin, player, "Aurora", true)
	city.apply_city_level(3)
	city.apply_fortification_level(2)
	city.annexation_points = 2
	for branch in ["v2_doctrine_guardian", "v2_doctrine_warrior", "v2_doctrine_ranger", "v2_magic_sacred"]:
		for tier in range(1,7): player.v2_research.complete_research("%s_%d" % [branch,tier])
	for branch in ["economy", "logistics", "industry", "academy", "arcane", "urbanization", "colonization"]:
		for tier in range(1,4): player.v2_research.complete_research("v2_infrastructure_%s_%d" % [branch,tier])
	for building in ["v2_building_market", "v2_building_workshop", "v2_building_guardian_hall", "v2_building_sacred_temple"]:
		city.buildings[building] = true
	city.production_item = "v2_unit_shieldbearer"
	city.stored_production = 8
	player.gold = 784
	player.mana = 126
	resource_coord = main.hex_grid.get_neighbors(origin)[0]
	main.hex_grid.get_tile(resource_coord).resource = "iron"
	city.resource_improvements[resource_coord] = load("res://scripts/data/V2ResourceImprovementData.gd").improvement_id_for_resource("iron")
	main.hex_grid.refresh_resource_improvement_marker(resource_coord)
	var unit_database = load("res://scripts/data/UnitDatabase.gd")
	soldier = main.hex_grid.spawn_unit(_unit_coord(), unit_database.create_unit("v2_unit_shieldbearer"), player)
	mage = main.hex_grid.spawn_unit(_unit_coord(), unit_database.create_unit("v2_unit_sacred_cleric"), player)
	var far_coord := _unit_coord(true)
	settlers.append(main.hex_grid.spawn_unit(far_coord, unit_database.create_unit("settler"), player))
	settlers.append(main.hex_grid.spawn_unit(resource_coord, unit_database.create_unit("settler"), player))
	monster = main.hex_grid.spawn_monster_at(_unit_coord(), "goblin", true)
	var builder_coord: Vector2i = main.hex_grid.get_neighbors(origin)[1]
	main.hex_grid.get_tile(builder_coord).resource = "gems"
	builder = main.hex_grid.spawn_unit(builder_coord, unit_database.create_unit("v2_unit_builder"), player)
	champion = main.hex_grid.spawn_unit(_unit_coord(), unit_database.create_unit("v2_legendary_guardian_champion"), player)
	root.get_node("TurnManager").turn_number = 62
	main.hex_grid.debug_fog_disabled = true
	main.hex_grid.recompute_fog(player)
	main.hex_grid.visible = true
	main.camera_rig.reset_view(main._human_camera_focus())
	main._enter_gameplay()
	shell = main.hud.ui_shell
	if shell.context_router.city_panel == null:
		push_error("CONTEXT_FAIL: City inspector could not load")
		quit(1)
		return
	shell.toast_presenter.dismiss_all()
	root.get_node("UIEvents").clear_session()
	while shell.critical_alerts.current_event() != null: shell.critical_alerts.dismiss()
	for tab in ["overview", "production", "structures", "territory", "defense"]:
		shell.context_router.open_city(city, tab)
		await _capture("city_" + tab + "_1600x900")
	shell.context_router.city_panel.catalog_category = "buildings"
	shell.context_router.open_city(city, "production")
	await _capture("city_buildings_1600x900")
	shell.context_router.city_panel.catalog_category = "units"
	await _select_unit(settlers[0])
	var unit_panel = shell.context_router.unit_panel
	_check(not unit_panel.button_for("found_city").disabled, "Valid settler keeps founding available")
	_check(unit_panel.button_for("move").size.y == unit_panel.button_for("found_city").size.y, "Settler controls have matching height")
	_check(unit_panel.button_for("move").get_theme_stylebox("normal") is StyleBoxTexture and unit_panel.button_for("found_city").get_theme_stylebox("normal") is StyleBoxTexture, "Settler controls share pixel frames")
	await _capture("settler_1600x900")
	await _select_unit(settlers[1])
	_check(unit_panel.button_for("found_city").disabled and not unit_panel.button_for("found_city").tooltip_text.is_empty(), "Invalid founding retains runtime reason")
	await _capture("settler_blocked_1600x900")
	await _select_unit(soldier)
	await _capture("troop_1600x900")
	await _select_unit(mage)
	await _capture("mage_1600x900")
	await _select_unit(builder)
	await _capture("builder_1600x900")
	await _select_unit(champion)
	await _capture("legendary_1600x900")
	await _select_unit(monster)
	_check(not unit_panel.view.own and unit_panel.command_buttons.is_empty(), "Monster inspection remains read-only")
	await _capture("monster_1600x900")
	root.get_node("EventBus").tile_selected.emit(resource_coord, main.hex_grid.get_tile(resource_coord))
	shell.context_router.flush()
	await _capture("resource_1600x900")
	for sample in [[Vector2i(1280,720),100,"1280x720"],[Vector2i(1600,900),125,"1600x900_ui125"],[Vector2i(1920,1080),100,"1920x1080"],[Vector2i(3440,1440),100,"ultrawide"],[Vector2i(1280,720),150,"1280x720_ui150"]]:
		root.size = sample[0]
		settings.ui_scale_percent = sample[1]
		settings.accessibility_changed.emit()
		shell.context_router.open_city(city, "overview")
		await _capture("city_overview_" + sample[2])
		shell.context_router.open_city(city, "production")
		await _capture("city_production_" + sample[2])
		await _select_unit(settlers[0])
		await _capture("settler_" + sample[2])
		await _select_unit(mage)
		await _capture("mage_" + sample[2])
	city.city_name = "Fortaleza da Alvorada Antiga"
	shell.context_router.open_city(city, "production")
	await _capture("city_long_name_1280x720_ui150")
	settings.ui_scale_percent = previous_scale
	settings.accessibility_changed.emit()
	var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"captures":captures}, "\t"))
	root.get_node("SelectionManager").reset()
	player.release_relations()
	manager.human_player = null
	manager.players.clear()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
