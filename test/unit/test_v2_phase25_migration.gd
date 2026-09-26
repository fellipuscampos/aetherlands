extends GutTest

## Fase 25 — Migração final V1→V2: contratos do caminho ativo depois da remoção da V1.
## Complementa os testes de área (save legado em test_save_manager, painel/tela de vitória e botão
## "Pesquisa" em test_hud, catálogo de prédios em test_buildings, roster em test_unit_database).

const RACES := ["human", "elf", "dwarf", "orc"]

var grid: HexGrid
var _players: Array[PlayerData] = []
var _original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "debug_mode"]:
		_original[key] = GameManager.get(key)
	_original["turn"] = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-6, 7):
		for r in range(-6, 7):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = grid

func after_each():
	for player in _players:
		player.release_relations()
	_players.clear()
	for key in _original:
		if key == "turn":
			TurnManager.turn_number = _original[key]
		else:
			GameManager.set(key, _original[key])

func _player(race: String = "human") -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	civ.civ_name = "Reino %s" % race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

# --- Estado canônico: nenhum campo V1 sobrevive -----------------------------------------------------

func test_player_has_only_the_v2_research_state():
	var player := _player()
	for field in ["researched_techs", "researched_magic", "current_research", "research_progress", "personality", "yield_multiplier", "trade_routes", "magic_effects", "spell_cooldowns", "arcane_ritual_active", "territorial_streak"]:
		assert_false(field in player, field)
	assert_not_null(player.v2_research)

func test_city_has_no_population_food_or_worked_tiles():
	var city := grid.found_city(Vector2i.ZERO, _player(), "Capital")
	for field in ["population", "stored_food", "worked_tiles", "food_storage_cap", "max_trade_routes", "captured_developed"]:
		assert_false(field in city, field)
	for method in ["collect_yields", "auto_assign_worked_tiles", "rush_buy", "can_rush_buy", "effective_tile_yield"]:
		assert_false(city.has_method(method), method)

func test_game_manager_has_no_v1_science_difficulty_or_victory_rules():
	for member in ["SCIENCE_PER_POPULATION", "DIFFICULTY_MULTIPLIERS", "victory_rules_version"]:
		assert_false(member in GameManager, member)
	for method in ["science_per_turn_for", "_process_research", "activate_arcane_ritual", "_update_victory_state"]:
		assert_false(GameManager.has_method(method), method)

# --- Cidade ao longo de muitos turnos: só V2 --------------------------------------------------------

func test_a_city_over_100_turns_only_accumulates_v2_production_and_keeps_its_territory():
	var player := _player()
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	var owned_before := city.owned_tiles.size()
	var per_turn := V2EconomyRuntime.city_production_income(city)
	assert_gt(per_turn, 0.0)
	var incomes := {}
	for i in 100:
		city.process_turn(grid)
		incomes[V2EconomyRuntime.city_production_income(city)] = true
	assert_eq(incomes.keys(), [per_turn], "sem crescimento populacional: a renda de Produção só muda por prédio/pesquisa V2")
	assert_eq(city.owned_tiles.size(), owned_before, "território só cresce por anexação")
	assert_eq(city.max_building_slots(), 4, "slots vêm do Nível de Cidade, nunca de população")
	assert_almost_eq(city.hp, city.max_hp(), 0.01)

func test_city_turn_never_credits_gold_or_mana_directly():
	var player := _player()
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	var result: Dictionary = city.process_turn(grid)
	assert_false(result.has("gold"))
	assert_false(result.has("mana"))
	assert_eq(player.gold, 0.0)
	V2EconomyRuntime.apply_turn_income(player)
	assert_almost_eq(player.gold, V2EconomyRuntime.city_gold_income(city), 0.01, "o Ouro vem só da economia V2")

# --- Neutralidade racial --------------------------------------------------------------------------

func test_races_keep_shared_costs_and_units_after_mechanical_identity_returns():
	for race in RACES:
		var player := _player(race)
		var city := grid.found_city(Vector2i(RACES.find(race) * 3 - 5, -5), player, "Cidade %s" % race)
		assert_eq([city.max_hp(), city.max_building_slots(), city.production_cost(), UnitDatabase.create_unit("settler").production_cost], [24.0, 4, 0.0, 25.0], race)
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			assert_eq(city.can_train(kind), kind == "settler", "%s/%s: sem tropa racial nem atalho de raça" % [race, kind])

func test_no_racial_unique_unit_or_economy_module_remains():
	assert_false("RACE_UNIQUE_KIND" in UnitDatabase)
	assert_false(UnitDatabase.new().has_method("race_for_unique_kind"))
	for path in ["res://scripts/data/RaceEconomy.gd", "res://scripts/data/CityIdentity.gd", "res://scripts/data/CivilizationPersonality.gd"]:
		assert_false(FileAccess.file_exists(path), path)

# --- Recursos: só a semântica V2 ------------------------------------------------------------------

func test_tile_inspector_resource_shows_only_the_v2_improvement():
	var player := _player()
	GameManager.human_player = player
	grid.found_city(Vector2i.ZERO, player, "Capital")
	var coord := Vector2i(1, 0)
	grid.tiles[coord].resource = "iron"
	grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var text := TileInspector.render(TileInspector.inspect(grid, coord, player), "")
	assert_string_contains(text, "Melhoria")
	for legacy in ["trabalhado", "Cavalaria", "desconto", "rota", "Comida", "V1", "V2"]:
		assert_false(text.contains(legacy), "%s em: %s" % [legacy, text])

# --- Vitórias: só três, com precedência fixa --------------------------------------------------------

func test_only_three_victory_types_exist_with_fixed_precedence():
	var source := FileAccess.get_file_as_string("res://scripts/autoload/GameManager.gd")
	var body := source.substr(source.find("func check_victories()"))
	body = body.substr(0, body.find("\nfunc ", 10))
	var dominance := body.find("is_dominance_achieved")
	var supremacy := body.find("military_supremacy_achieved")
	var transcendence := body.find("transcendence_achieved")
	assert_true(dominance > 0 and dominance < supremacy and supremacy < transcendence, "Dominação -> Supremacia Militar -> Transcendência")
	for legacy in ["territorial", "arcane", "VictoryCampaign"]:
		assert_false(body.contains(legacy), legacy)
	assert_false(FileAccess.file_exists("res://scripts/core/VictoryCampaign.gd"))
	for constant in ["VICTORY_TYPE_TERRITORIAL", "VICTORY_TYPE_ARCANE"]:
		assert_false(constant in VictoryConditions, constant)

func test_dominance_is_declared_when_the_human_is_the_last_civilization():
	var human := _player()
	var rival := _player("orc")
	human.units.append(null)
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.state = GameManager.GameState.PLAYING
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, VictoryConditions.VICTORY_TYPE_DOMINANCE])
	human.units.clear()

# --- Pesquisa: ferramentas de debug só em build de debug -------------------------------------------

func test_research_board_debug_tools_only_exist_in_a_debug_build():
	var release_board := V2ResearchBoard.new()
	release_board.debug_tools_enabled = false
	add_child_autofree(release_board)
	assert_true(release_board._debug_buttons.is_empty(), "build normal: nenhuma ferramenta de debug")
	var debug_board := V2ResearchBoard.new()
	debug_board.debug_tools_enabled = true
	add_child_autofree(debug_board)
	assert_false(debug_board._debug_buttons.is_empty())
	assert_eq(V2ResearchBoard.new().debug_tools_enabled, OS.is_debug_build())

func test_debug_mode_flag_never_grants_research():
	var player := _player()
	GameManager.human_player = player
	GameManager.set_debug_mode(true)
	assert_true(player.v2_research.get_completed_ids().is_empty())
	GameManager.set_debug_mode(false)

# --- HUD: barra superior só com a economia V2 -------------------------------------------------------

func test_top_bar_shows_gold_supply_mana_knowledge_in_order_without_internal_labels():
	var hud: Control = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	var player := _player()
	grid.found_city(Vector2i.ZERO, player, "Capital")
	GameManager.human_player = player
	hud._refresh_stats()
	var texts: Array[String] = []
	for child in hud.gold_label.get_parent().get_children():
		if child is Label and child.visible and child.text != "":
			texts.append(child.text)
	var joined := " | ".join(texts)
	var order := ["Ouro:", "Suprimentos:", "Mana:", "Conhecimento:"]
	var last := -1
	for prefix in order:
		var at := joined.find(prefix)
		assert_gt(at, last, "%s fora de ordem em: %s" % [prefix, joined])
		last = at
	for forbidden in ["Comida", "População", "Ciência", "V1", "V2", "scaffold", "placeholder"]:
		assert_false(joined.contains(forbidden), "%s em: %s" % [forbidden, joined])

# --- Forças iniciais e produção -------------------------------------------------------------------

func test_new_game_starting_forces_are_the_shared_core():
	var source := FileAccess.get_file_as_string("res://scripts/autoload/GameManager.gd")
	var body := source.substr(source.find("func _spawn_starting_forces()"))
	body = body.substr(0, body.find("\nfunc ", 10))
	var kinds := []
	for m in RegEx.create_from_string("create_unit\\(\"(\\w+)\"\\)").search_all(body):
		if not m.get_string(1) in kinds:
			kinds.append(m.get_string(1))
	kinds.sort()
	assert_eq(kinds, ["settler", "warrior"])

func test_legacy_production_items_are_rejected_by_the_central_sanitizer():
	for item in ["granary", "barracks", "walls", "warrior", "archer", "mercador", "human_knight"]:
		assert_false(SaveManager._is_valid_production_item(item), item)
	for item in ["", "settler", "v2_building_market", "v2_unit_shieldbearer"]:
		assert_true(SaveManager._is_valid_production_item(item), item)

func test_legacy_walls_map_to_fortification_and_v1_buildings_are_dropped():
	var sanitized := SaveManager._sanitize_legacy_city({"buildings": ["walls", "granary", "v2_building_market"], "production_item": "walls_2", "stored_production": 7.0})
	assert_eq(sanitized.fortification_level, 1)
	assert_eq(sanitized.buildings, ["v2_building_market"])
	assert_eq(sanitized.production_item, "")
	assert_eq(sanitized.stored_production, 0.0)
