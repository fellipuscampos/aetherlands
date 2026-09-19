extends GutTest

var grid: HexGrid
var player: PlayerData
var enemy: PlayerData

func before_each():
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-5, 6):
		for r in range(-5, 6):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	player = PlayerData.new(CivilizationData.new())
	enemy = PlayerData.new(CivilizationData.new())

func after_each():
	for p in [player, enemy]:
		p.enemies.clear()
		p.trade_routes.clear()
		p.war_campaigns.clear()

func test_research_switching_keeps_progress_attached_to_its_project():
	assert_true(player.select_research("quartel"))
	player.research_progress = 10.0
	assert_true(player.select_research("arcanismo_1"))
	assert_eq(player.research_progress, 0.0)
	player.research_progress = 4.0
	assert_true(player.select_research("quartel"))
	assert_eq(player.research_progress, 10.0)
	assert_false(player.select_research("colosso_de_cerco"))
	assert_eq(player.current_research, "quartel")

func test_general_aura_requires_proximity_and_does_not_stack():
	var soldier := grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("warrior"), player)
	assert_eq(UnitAbilities.command_multiplier(soldier), 1.0)
	grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("general"), player)
	grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("general"), player)
	assert_eq(UnitAbilities.command_multiplier(soldier), 1.25)
	soldier.coord = Vector2i(5, 5)
	assert_eq(UnitAbilities.command_multiplier(soldier), 1.0)

func test_engineers_repair_siege_once_per_turn_and_do_not_heal_infantry():
	grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("engenheiro_de_cerco"), player)
	grid.spawn_unit(Vector2i(0, 1), UnitDatabase.create_unit("engenheiro_de_cerco"), player)
	var siege := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("catapult"), player)
	var soldier := grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("warrior"), player)
	siege.hp = 1.0
	soldier.hp = 1.0
	UnitAbilities.process_turn(player, grid)
	assert_eq(siege.hp, 1.0 + siege.unit_data.max_hp * 0.25)
	assert_eq(soldier.hp, 1.0)

func test_advanced_building_has_a_usable_city_button():
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	for building in BuildingDatabase.all_buildings():
		assert_not_null(hud._build_button_for(building.id), building.id)

func test_building_upgrade_reuses_a_full_city_footprint():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	city.buildings["barracks"] = true
	city.building_coords["barracks"] = Vector2i(1, 0)
	player.researched_techs["quartel_2"] = true
	assert_true(city.can_build("barracks_2"))
	city.set_production("barracks_2")
	assert_eq(city.pending_building_coord, Vector2i(1, 0))
	city.buildings["barracks_2"] = true
	assert_eq(city.used_building_slots(), 1)

func test_merchant_creates_real_trade_and_cannot_duplicate_a_route():
	var a := grid.found_city(Vector2i(-3, 0), player, "Origem")
	var b := grid.found_city(Vector2i(3, 0), enemy, "Destino")
	a.buildings["market"] = true
	b.buildings["market"] = true
	var merchant := grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("mercador"), player)
	UnitAbilities.process_turn(player, grid)
	assert_eq(player.trade_routes.size(), 1)
	assert_eq(player.gold, 25.0)
	assert_false(merchant in player.units)
	assert_null(TradeManager.propose_route(a, b, grid))

func test_blocked_recruitment_waits_without_overwriting_a_unit():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	for coord in [Vector2i.ZERO] + grid.get_neighbors(Vector2i.ZERO):
		grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), player)
	city.set_production("warrior")
	city.stored_production = city.production_cost(grid)
	var result := city.process_turn(grid)
	assert_eq(result.spawn_unit_kind, "")
	assert_eq(city.production_item, "warrior")
	assert_eq(player.units.size(), 7)
	var released := grid.get_neighbors(Vector2i.ZERO)[0]
	grid.remove_unit(grid.get_unit_at(released))
	result = city.process_turn(grid)
	assert_eq(result.spawn_unit_kind, "warrior")
	assert_eq(WorldSetup.find_spawn_tile(grid, city.coord), released)

func test_growing_city_can_work_owned_land_beyond_first_ring():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	city.population = 7
	city.claim_tile(Vector2i(2, 0))
	city.auto_assign_worked_tiles(grid)
	assert_eq(city.worked_tiles.size(), 7)
	assert_has(city.worked_tiles, Vector2i(2, 0))

func test_ai_assigns_a_real_building_site():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	city.set_production("granary")
	RivalAI._assign_building_site(city, "granary", grid)
	assert_ne(city.pending_building_coord, City.NO_PENDING_COORD)
	assert_true(city.is_valid_building_tile(city.pending_building_coord, grid))

func test_dragon_rewards_are_proportional_and_not_repeated_after_loading():
	var event := DragonEvent.new()
	event.result = {"outcome": "defeated"}
	event.participants = {0: {"decision": true}, 1: {"decision": true}}
	event.damage_by_civ = {0: 75.0, 1: 25.0}
	event.award_contribution_rewards([player, enemy])
	assert_eq(player.gold, 250.0)
	assert_eq(enemy.gold, 100.0)
	var loaded := DragonEvent.new()
	loaded.from_save_dict(JSON.parse_string(JSON.stringify(event.to_save_dict())))
	loaded.award_contribution_rewards([player, enemy])
	assert_eq(player.gold, 250.0)
	assert_eq(enemy.gold, 100.0)
