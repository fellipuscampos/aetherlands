extends GutTest

## Task 23 -- integracao da HUD com o TileInspector: entidade principal +
## secao de terreno + abas, segredo de producao rival, entidade destruida,
## painel de unidade propria e a convivencia com a selecao/comandos.

var hud: Control
var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_players: Array[PlayerData]
var _original_state
var _original_turn: int

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_players = GameManager.players
	_original_state = GameManager.state
	_original_turn = TurnManager.turn_number
	_created_units = []
	hex_grid = HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			var coord := Vector2i(q, r)
			if HexMetrics.axial_distance(coord, Vector2i.ZERO) <= 6:
				hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.JUNGLE)
				hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	human = _player("Humanos", "human")
	rival = _player("Elfos", "elf")
	human.enemies[rival] = true
	rival.enemies[human] = true
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human
	GameManager.players = [human, rival]
	TurnManager.turn_number = 10
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	SelectionManager.selected_unit = null
	SelectionManager.reachable.clear()
	SelectionManager.attackable.clear()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.players = _original_players
	GameManager.state = _original_state
	GameManager.is_turn_processing = false
	TurnManager.turn_number = _original_turn
	human.enemies.clear()
	rival.enemies.clear()
	hex_grid.free()
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.free()

func _player(civ_name: String, race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	civ.race = race
	return PlayerData.new(civ)

func _unit(kind: String, owner_player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), owner_player, coord)
	unit.reset_movement()
	owner_player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func _select(coord: Vector2i) -> void:
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

func _tab_labels() -> Array:
	return hud._inspect_tabs.get_children().map(func(b): return b.text)

# --- Painel de tile ----------------------------------------------------------

func test_clicking_an_enemy_caster_shows_the_caster_not_just_the_terrain():
	_unit("elementalist", rival, Vector2i(2, 0))
	_select(Vector2i(2, 0))
	assert_true(hud.tile_info_panel.visible)
	var text: String = hud.tile_info_label.text
	assert_string_contains(text, "Elementalista")
	assert_string_contains(text, "Elfos (em guerra)")
	assert_string_contains(text, "Terreno: Selva", "o terreno continua consultavel como secao")
	assert_ne(text.split("\n")[0], "Terreno: Selva (2, 0)", "o terreno nao substitui a entidade principal")

func test_clicking_a_monster_shows_a_monster_and_not_a_lair_label():
	hex_grid.spawn_monster_at(Vector2i(2, 2), "skeleton", false)
	_select(Vector2i(2, 2))
	assert_string_contains(hud.tile_info_label.text, "Esqueleto")
	assert_false("Covil de Monstro" in hud.tile_info_label.text)

func test_clicking_a_boss_and_a_lair_structure_are_both_identified():
	var lair_coord := Vector2i(3, -3)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "troll"
	var structure := LairStructure.new()
	structure.build("troll", hex_grid)
	hex_grid.add_child(structure)
	hex_grid.lairs_by_coord[lair_coord] = structure
	hex_grid.spawn_monster_at(lair_coord + HexGrid.NEIGHBOR_DIRS[0], "troll", true)
	_select(lair_coord)
	assert_string_contains(hud.tile_info_label.text, "Covil de Troll")
	_select(lair_coord + HexGrid.NEIGHBOR_DIRS[0])
	assert_string_contains(hud.tile_info_label.text, "Chefe")

func test_building_and_resource_tiles_are_identified():
	hex_grid.place_building(Vector2i(1, 1), "granary", human)
	_select(Vector2i(1, 1))
	assert_string_contains(hud.tile_info_label.text, "Efeitos:")
	hex_grid.tiles[Vector2i(3, 0)].resource = "gems"
	_select(Vector2i(3, 0))
	assert_string_contains(hud.tile_info_label.text, "Recurso: Gemas")

func test_empty_tile_shows_terrain_without_tabs():
	_select(Vector2i(4, 0))
	assert_string_contains(hud.tile_info_label.text, "Terreno: Selva (4, 0)")
	assert_false(hud._inspect_tabs.visible)

func test_multiple_entities_get_one_tab_each_and_tabs_switch_the_text():
	hex_grid.tiles[Vector2i(1, 0)].resource = "horses"
	hex_grid.place_building(Vector2i(1, 0), "granary", rival)
	_unit("warrior", rival, Vector2i(1, 0))
	_select(Vector2i(1, 0))
	assert_true(hud._inspect_tabs.visible)
	assert_eq(hud._inspect_tabs.get_child_count(), 3)
	assert_string_contains(hud.tile_info_label.text, RaceTheme.unit_name("warrior", "elf"))
	hud._on_inspect_tab_pressed("resource")
	assert_string_contains(hud.tile_info_label.text, "Recurso: Cavalos")
	assert_string_contains(hud.tile_info_label.text, "Terreno: Selva", "o terreno acompanha qualquer aba")
	hud._on_inspect_tab_pressed("building")
	assert_string_contains(hud.tile_info_label.text, "Efeitos:")

func test_selected_tab_survives_a_reclick_of_the_same_tile_but_resets_on_another_tile():
	hex_grid.tiles[Vector2i(1, 0)].resource = "horses"
	_unit("warrior", rival, Vector2i(1, 0))
	_select(Vector2i(1, 0))
	hud._on_inspect_tab_pressed("resource")
	_select(Vector2i(1, 0))
	assert_eq(hud._inspect_key, "resource")
	_select(Vector2i(2, 0))
	assert_eq(hud._inspect_key, "", "tile sem entidade nenhuma nao herda a aba")
	_select(Vector2i(1, 0))
	assert_eq(hud._inspect_key, "unit", "tile novo volta pra entidade principal")

func test_unseen_tile_shows_only_the_unexplored_message():
	hex_grid.visibility[Vector2i(5, 0)] = HexGrid.Visibility.UNSEEN
	hex_grid.spawn_monster_at(Vector2i(5, 0), "goblin", false)
	_select(Vector2i(5, 0))
	assert_string_contains(hud.tile_info_label.text, "Região inexplorada")
	assert_false("Goblin" in hud.tile_info_label.text)

# --- Segredo -----------------------------------------------------------------

func test_rival_city_never_shows_production_progress():
	var city := hex_grid.found_city(Vector2i(3, 0), rival, "Silvana")
	city.set_production("warrior")
	city.stored_production = 5.0
	_select(Vector2i(3, 0))
	assert_string_contains(hud.tile_info_label.text, "Silvana")
	assert_false(hud.production_progress_label.visible, "producao da cidade rival e' segredo")
	assert_false(hud.production_tabs.visible)

func test_own_city_still_shows_production_progress_and_panel():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	city.set_production("warrior")
	_select(Vector2i(0, 0))
	assert_true(hud.production_progress_label.visible)
	assert_true(hud.production_tabs.visible)
	assert_string_contains(hud.tile_info_label.text, "Alvorada")

func test_own_city_with_a_garrison_lists_city_first_and_the_unit_as_a_tab():
	hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	_unit("warrior", human, Vector2i(0, 0))
	_select(Vector2i(0, 0))
	assert_eq(_tab_labels().size(), 2)
	assert_eq(hud._inspect_key, "city")
	hud._on_inspect_tab_pressed("unit")
	assert_string_contains(hud.tile_info_label.text, "Guarda")
	assert_true(hud.production_tabs.visible, "trocar de aba de leitura nao desmonta a gestao da cidade")

# --- Estado, destruicao, save/load -------------------------------------------

func test_destroyed_entity_updates_the_panel_without_stale_references():
	var monster := hex_grid.spawn_monster_at(Vector2i(2, 2), "skeleton", false)
	_select(Vector2i(2, 2))
	assert_string_contains(hud.tile_info_label.text, "Esqueleto")
	hex_grid.remove_unit(monster)
	hud._refresh_inspection()
	assert_false("Esqueleto" in hud.tile_info_label.text)
	assert_string_contains(hud.tile_info_label.text, "Terreno: Selva (2, 2)")
	assert_false(hud._inspect_tabs.visible)

func test_captured_own_city_resets_the_city_panel():
	var city := hex_grid.found_city(Vector2i(0, 0), human, "Alvorada")
	_select(Vector2i(0, 0))
	assert_true(hud.production_tabs.visible)
	hex_grid.capture_city(city, rival)
	hud._refresh_inspection()
	assert_false(hud.production_tabs.visible, "cidade capturada nao pode continuar com o painel de gestao aberto")
	assert_null(hud._viewed_city)

func test_refresh_after_the_map_was_replaced_is_safe():
	_unit("warrior", rival, Vector2i(2, 0))
	_select(Vector2i(2, 0))
	var previous_grid := hex_grid
	# Simula "carregar um save": outro HexGrid (sem aquele tile) assume o jogo.
	var loaded := HexGrid.new()
	loaded._ready()
	loaded.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = loaded
	hud._refresh_inspection()
	assert_true(true, "sem erro/crash")
	GameManager.hex_grid = previous_grid
	loaded.free()

func test_deselecting_clears_tabs_and_state():
	hex_grid.tiles[Vector2i(1, 0)].resource = "horses"
	_unit("warrior", rival, Vector2i(1, 0))
	_select(Vector2i(1, 0))
	assert_true(hud._inspect_tabs.visible)
	hud._on_tile_selected(Vector2i(1, 0), null)
	assert_false(hud._inspect_tabs.visible)
	assert_eq(hud._inspect_coord, hud.NO_INSPECT_COORD)
	assert_false(hud.tile_info_panel.visible)

# --- Painel de unidade propria ------------------------------------------------

func test_own_caster_panel_shows_class_action_cooldown_and_tile_summary():
	var mage := _unit("elementalist", human, Vector2i(1, 0))
	mage.magic_cooldowns["Onda Glacial"] = TurnManager.turn_number + 2
	hex_grid.tiles[Vector2i(1, 0)].resource = "iron"
	hud._on_unit_selected(mage)
	var text: String = hud.unit_info_label.text
	assert_string_contains(text, "Classe: Conjurador — Elementalismo")
	assert_string_contains(text, "Ação: pronto para conjurar")
	assert_string_contains(text, "Recarga: Onda Glacial (2)")
	assert_string_contains(text, "Neste tile: Selva (1, 0)")
	assert_string_contains(text, "também aqui: Ferro")

func test_own_unit_without_city_keeps_the_tile_panel_hidden():
	_unit("warrior", human, Vector2i(1, 0))
	_select(Vector2i(1, 0))
	assert_false(hud.tile_info_panel.visible)

# --- Selecao x inspecao ---------------------------------------------------------

func _click(coord: Vector2i) -> void:
	var world := hex_grid.world_for_coord(coord)
	SelectionManager.handle_world_click(world)

func test_click_selects_own_units_and_inspects_everything_else_predictably():
	var own := _unit("warrior", human, Vector2i(-3, 0))
	var enemy := _unit("warrior", rival, Vector2i(4, 0))
	watch_signals(EventBus)
	_click(Vector2i(-3, 0))
	assert_eq(SelectionManager.selected_unit, own, "clicar em unidade propria seleciona")
	# Inimigo fora do alcance de ataque: nao ataca, so' inspeciona (desseleciona).
	_click(Vector2i(4, 0))
	assert_null(SelectionManager.selected_unit)
	assert_signal_emitted(EventBus, "tile_selected")
	assert_true(is_instance_valid(enemy) and enemy.hp == enemy.unit_data.max_hp, "inspecionar nunca ataca")

func test_click_on_an_empty_tile_still_works_and_shows_terrain():
	_click(Vector2i(0, 4))
	assert_string_contains(hud.tile_info_label.text, "Terreno: Selva (0, 4)")
