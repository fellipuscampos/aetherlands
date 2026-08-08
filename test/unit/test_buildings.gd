extends GutTest

## Cobre BuildingDatabase: consulta por id, soma de bonus de yield e de
## defesa de VARIOS predios construidos ao mesmo tempo (City.buildings).

func test_get_building_returns_known_building():
	var granary = BuildingDatabase.get_building("granary")
	assert_not_null(granary)
	assert_eq(granary.display_name, "Celeiro")

func test_get_building_returns_null_for_unknown_id():
	assert_null(BuildingDatabase.get_building("nao_existe"))

func test_total_bonus_sums_multiple_buildings():
	var built = {"granary": true, "workshop": true, "market": true}
	var bonus = BuildingDatabase.total_bonus(built)
	assert_eq(bonus.food, 2, "so o Celeiro da comida")
	assert_eq(bonus.production, 2, "so a Oficina da producao")
	assert_eq(bonus.gold, 2, "so o Mercado da ouro")

func test_total_bonus_ignores_walls_yield():
	var built = {"walls": true}
	var bonus = BuildingDatabase.total_bonus(built)
	assert_eq(bonus.food, 0)
	assert_eq(bonus.production, 0)
	assert_eq(bonus.gold, 0)

func test_defense_bonus_for_sums_walls():
	var built = {"walls": true, "granary": true} # granary nao contribui pra defesa
	assert_almost_eq(BuildingDatabase.defense_bonus_for(built), 0.5, 0.01)

func test_defense_bonus_for_empty_dict_is_zero():
	assert_almost_eq(BuildingDatabase.defense_bonus_for({}), 0.0, 0.01)

func test_all_buildings_have_unique_ids():
	var ids := []
	for b in BuildingDatabase.all_buildings():
		assert_false(b.id in ids, "cada predio deveria ter um id unico")
		ids.append(b.id)
