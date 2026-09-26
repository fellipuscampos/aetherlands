extends Node

## Validação visual descartável da Fase 22. Instancia a cena principal real,
## monta um estado determinístico e salva duas capturas em user://.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ELEMENTALIST := "v2_unit_elementalist"
const PRIMORDIAL := "v2_manifestation_elemental_primordial"

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("VISUAL_OK: ", message)
	else:
		_failures.append(message)
		push_error("VISUAL_FAIL: " + message)

func _free_coord(grid: HexGrid, center: Vector2i, min_distance: int = 0) -> Vector2i:
	for coord in HexMetrics.coords_within(center, 8):
		var tile := grid.get_tile(coord)
		if HexMetrics.axial_distance(center, coord) >= min_distance and tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.get_building_at(coord) == null and not grid.lairs_by_coord.has(coord):
			return coord
	return Vector2i(9999, 9999)

func _learn_branch(player: PlayerData, branch: String) -> void:
	for tier in range(1, 10):
		var research_id := "v2_magic_%s_%d" % [branch, tier]
		if not player.v2_research.is_completed(research_id):
			_check(player.v2_research.complete_research(research_id), research_id)

func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("user://" + file_name)
	_check(error == OK, "captura %s (%dx%d)" % [file_name, image.get_width(), image.get_height()])

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1017))
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var grid: HexGrid = main.get_node("HexGrid")
	var hud = main.get_node("UILayer/HUD")
	var title = main.get_node("UILayer/TitleScreen")
	var setup = main.get_node("UILayer/GameSetupScreen")
	GameManager.map_width = 25
	GameManager.map_height = 25
	GameManager.rival_count = 1
	GameManager.debug_mode = true
	GameManager.stagger_ai_turns = false
	grid.generate_map(25, 25, 22022)
	GameManager.start_new_game(grid)
	title.visible = false
	setup.visible = false
	hud.visible = true
	grid.set_debug_fog_disabled(true)

	var human := GameManager.human_player
	_learn_branch(human, "elementalism")
	var origin := _free_coord(grid, Vector2i.ZERO)
	var elementalista := grid.spawn_unit(origin, UnitDatabase.create_unit(ELEMENTALIST), human)
	var primordial_coord := _free_coord(grid, origin, 1)
	var primordial := grid.spawn_unit(primordial_coord, UnitDatabase.create_unit(PRIMORDIAL), human)
	_check(elementalista != null and primordial != null, "Elementalista e Primordial materializados no mapa real")

	var nearby := HexMetrics.coords_within(origin, 3)
	var zone_ids := ["v2_zone_dense_mist", "v2_zone_gale", "v2_zone_lightning_storm", "v2_zone_elemental_cataclysm"]
	var zone_coords: Array[Vector2i] = []
	for coord in nearby:
		if zone_coords.size() >= zone_ids.size():
			break
		var tile := grid.get_tile(coord)
		if coord == origin or tile == null or tile.blocks_land_units():
			continue
		if grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or grid.get_building_at(coord) != null or grid.lairs_by_coord.has(coord):
			continue
		zone_coords.append(coord)
	for index in range(zone_ids.size()):
		_check(V2EnvironmentalZoneSystem.apply(grid, zone_coords[index], zone_ids[index], 0, "elementalism", primordial.unit_data.environmental_zone_duration_bonus), "zona %s aplicada" % zone_ids[index])

	# As três camadas mágicas coexistem no mesmo recorte: ambiente, Bosque e Portal.
	_check(V2TerrainRuntime.apply(grid, zone_coords[2], "v2_terrain_dense_grove"), "Bosque Denso coexiste com Tempestade")
	_check(V2PortalSystem.create_or_replace_pair(human, "arcanism", zone_coords[1], zone_coords[3], grid), "Portal coexiste com Vendaval/Cataclismo")
	grid.recompute_fog(human)
	main.get_node("CameraRig").reset_view(HexMetrics.axial_to_world(origin.x, origin.y, grid.hex_size))
	SelectionManager._select_unit(primordial)
	await get_tree().process_frame

	var inspector := TileInspector.render(TileInspector.inspect(grid, zone_coords[3], human))
	_check(grid._v2_environmental_zone_markers.size() == 4, "quatro marcadores ambientais visíveis e sem polling")
	_check(inspector.contains("Cataclismo Elemental") and inspector.contains(human.civ.civ_name), "inspetor identifica zona e criador")
	_check(hud.unit_info_label.text.contains("Coração Elemental"), "painel do Primordial mostra Coração Elemental")
	_check(hud.unit_info_label.text.contains("Elementalismo"), "painel do Primordial mostra sua Escola")
	await _capture("phase22_environment_map.png")

	# Quadro real: 54 nós mágicos + Transcendência; Elementalismo N1-N9 concluído.
	hud._on_debug_v2_trees_pressed()
	hud.v2_research_board.show_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL)
	hud.v2_research_board.select_node("v2_magic_elementalism_9")
	await get_tree().process_frame
	_check(hud.v2_research_board.card_count() == 55, "aba Magia contém 54 nós normais e Transcendência")
	_check(hud.v2_research_board.card_for("v2_magic_elementalism_9") != null, "Primordial dos Elementos aparece no N9")
	_check(not V2ResearchDatabase.get_node("v2_magic_elementalism_9").is_placeholder, "Elementalismo N1-N9 sem placeholder")
	_check(not V2ResearchDatabase.get_node("v2_magic_elementalism_9").display_name.contains(" IX"), "nome canônico substitui Elementalismo IX")
	_check(not V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected, "Transcendência permanece inerte")
	await _capture("phase22_magic_board.png")

	print("VISUAL_SUMMARY: zones=", grid.v2_environmental_zones.size(), " cards=", hud.v2_research_board.card_count(), " failures=", _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
