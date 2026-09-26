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
		p.war_campaigns.clear()

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
		assert_true(hud._building_buttons.has(building.id), building.id)

func test_blocked_recruitment_waits_without_overwriting_a_unit():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	for coord in [Vector2i.ZERO] + grid.get_neighbors(Vector2i.ZERO):
		grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), player)
	city.set_production("settler")
	city.stored_production = city.production_cost()
	var result := city.process_turn(grid)
	assert_eq(result.spawn_unit_kind, "")
	assert_eq(city.production_item, "settler")
	assert_eq(player.units.size(), 7)
	var released := grid.get_neighbors(Vector2i.ZERO)[0]
	grid.remove_unit(grid.get_unit_at(released))
	result = city.process_turn(grid)
	assert_eq(result.spawn_unit_kind, "settler")
	assert_eq(WorldSetup.find_spawn_tile(grid, city.coord), released)

func test_ai_assigns_a_real_building_site():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	var site := V2StrategicAI._building_site(city, grid)
	assert_ne(site, City.NO_PENDING_COORD)
	assert_true(city.is_valid_building_tile(site, grid))

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
