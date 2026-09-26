extends GutTest

## Aetherlands V2, Fase 13 — UI do painel de cidade: botão "Evoluir para Cidade N — X PP + Y
## Ouro" e botão "Anexar território (N)" (HUD._refresh_v2_city_actions, container dinâmico,
## mesmo padrão de _refresh_v2_unit_actions da Fase 4).

var hud: Control
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _owned_players: Array[PlayerData] = []
var _grids: Array[HexGrid] = []
var _cities: Array[City] = []

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_owned_players.append(player)
	return player

func _grid() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _v2_city_actions_row() -> Node:
	return hud.tile_info_panel.get_node("TileInfoBox").get_node_or_null("V2CityActions")

func test_upgrade_button_shows_the_pp_and_gold_cost_when_available():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	player.gold = 100.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var row := _v2_city_actions_row()
	assert_not_null(row, "painel de cidade deveria ter o container V2CityActions")
	var button: Button = row.get_node("CityUpgradeButton")
	assert_eq(button.text, "Evoluir para Cidade II — 60 PP + 30 Ouro")
	assert_false(button.disabled)

func test_upgrade_button_is_disabled_with_the_reason_in_the_tooltip_without_research():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.gold = 100.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = _v2_city_actions_row().get_node("CityUpgradeButton")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Planejamento Urbano"), button.tooltip_text)

func test_no_upgrade_button_at_city_level_4():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	city.city_level = 4
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var row := _v2_city_actions_row()
	assert_null(row.get_node_or_null("CityUpgradeButton"), "Cidade IV não tem upgrade (§46 do pedido)")

func test_clicking_the_upgrade_button_starts_the_city_project():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	player.gold = 100.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = _v2_city_actions_row().get_node("CityUpgradeButton")
	button.pressed.emit()
	assert_eq(city.production_item, "v2_city_upgrade_2")

func test_annex_button_shows_the_point_count_and_is_disabled_at_zero():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = _v2_city_actions_row().get_node("AnnexButton")
	assert_eq(button.text, "Anexar território (0)")
	assert_true(button.disabled)

func test_annex_button_enabled_with_points_and_clicking_it_enters_the_selection_manager_mode():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	city.city_level = 2
	city.annexation_points = 4
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = _v2_city_actions_row().get_node("AnnexButton")
	assert_eq(button.text, "Anexar território (4)")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(SelectionManager.annexing_city, city)
	SelectionManager.reset()

func test_upgrade_button_shows_waiting_for_gold_once_production_points_are_full():
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	player.gold = 100.0
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	city.set_production("v2_city_upgrade_2")
	city.stored_production = city.production_cost()
	player.gold = 5.0
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = _v2_city_actions_row().get_node("CityUpgradeButton")
	assert_eq(button.text, "Aguardando 30 Ouro.")

func test_other_v2_doctrine_buildings_remain_unaffected_by_the_new_city_actions_row():
	# Regressão: a linha V2CityActions não deveria interferir com os botões de prédio/unidade
	# já existentes no painel de produção (mesmo container pai, TileInfoBox).
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	assert_true(hud.production_tabs.visible)
	assert_not_null(_v2_city_actions_row())

# --- Aetherlands V2, Fase 16: botões de Fortificação e Ataque da Cidade -----------------------------

func _phase16_city(level: int, fortification: int) -> Dictionary:
	var player := _player()
	var grid := _grid()
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	_cities.append(city)
	city.city_level = level
	city.fortification_level = fortification
	return {"player": player, "grid": grid, "city": city}

func test_fortification_button_names_the_next_level_and_its_cost():
	var s := _phase16_city(2, 0)
	s.player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	var button: Button = _v2_city_actions_row().get_node("FortificationButton")
	assert_eq(button.text, "Construir Muralhas I — 40 PP")
	assert_false(button.disabled)
	assert_string_contains(button.tooltip_text, "Manutenção: 1 Ouro/turno")

func test_fortification_button_is_disabled_with_the_reason_without_research():
	var s := _phase16_city(2, 0)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	var button: Button = _v2_city_actions_row().get_node("FortificationButton")
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Requer Planejamento Urbano.")

func test_pressing_the_fortification_button_queues_the_project():
	var s := _phase16_city(2, 0)
	s.player.v2_research.complete_research("v2_infrastructure_urbanization_1")
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	_v2_city_actions_row().get_node("FortificationButton").pressed.emit()
	assert_eq(s.city.production_item, "v2_city_fortification_1")
	var button: Button = _v2_city_actions_row().get_node("FortificationButton")
	assert_eq(button.text, "Construir Muralhas I — 40 PP (em progresso)")

func test_no_fortification_button_at_the_fortress():
	var s := _phase16_city(4, 3)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	assert_null(_v2_city_actions_row().get_node_or_null("FortificationButton"))

func test_city_attack_button_only_exists_with_fortification():
	var s := _phase16_city(2, 0)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	assert_null(_v2_city_actions_row().get_node_or_null("CityAttackButton"))

func test_city_attack_button_states():
	var s := _phase16_city(2, 1)
	var original_turn := TurnManager.turn_number
	TurnManager.turn_number = 7
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	var button: Button = _v2_city_actions_row().get_node("CityAttackButton")
	assert_eq(button.text, "Ataque da Cidade")
	assert_true(button.disabled, "sem alvo")
	assert_eq(button.tooltip_text, "Nenhum alvo hostil visível ao alcance.")
	var monster: Unit = s.grid.spawn_monster_at(Vector2i(1, 0), "skeleton", false)
	s.grid.recompute_fog(s.player)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	button = _v2_city_actions_row().get_node("CityAttackButton")
	assert_false(button.disabled)
	assert_eq(button.tooltip_text, "Poder 3 | Alcance 2. Sem revide.")
	button.pressed.emit()
	assert_same(SelectionManager.city_attack_city, s.city, "entrou na mira")
	SelectionManager._handle_city_attack_click(monster.coord)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	button = _v2_city_actions_row().get_node("CityAttackButton")
	assert_eq(button.text, "Ataque da Cidade — Usado neste turno")
	assert_true(button.disabled)
	TurnManager.turn_number = original_turn

## Achado da validação visual da Fase 16: selecionar um tile sem cidade depois de ver a própria cidade
## deixava a fileira de ações (Evoluir/Fortificar/Ataque da Cidade/Anexar) na tela e clicável.
func test_selecting_a_non_city_tile_clears_the_previous_city_actions():
	var s := _phase16_city(2, 1)
	hud._on_tile_selected(s.city.coord, s.grid.get_tile(s.city.coord))
	assert_not_null(_v2_city_actions_row(), "pré-condição: ações da cidade na tela")
	hud._on_tile_selected(Vector2i(4, 0), s.grid.get_tile(Vector2i(4, 0)))
	var row := _v2_city_actions_row()
	assert_true(row == null or row.is_queued_for_deletion(), "a fileira da cidade anterior some")
