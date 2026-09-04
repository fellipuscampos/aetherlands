extends GutTest

## Roadmap "Parte B" (cidade em profundidade), fatia B1+B2 — identidade de
## cidade DERIVADA (CityIdentity.gd). Cobre so as funcoes puras aqui;
## integracao real com City.collect_yields()/production_cost() fica em
## test_city.gd. Usa o atalho ja estabelecido em test_city.gd (city.
## buildings["x"] = true) em vez de rodar process_turn() em loop.

func test_axis_strength_is_zero_with_no_buildings():
	var city := City.new()
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_AGRICOLA), 0.0)
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_MILITAR), 0.0)
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_ARCANA), 0.0)
	city.queue_free()

func test_axis_strength_binary_axis_is_zero_or_one():
	var city := City.new()
	city.buildings["granary"] = true
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_AGRICOLA), 1.0)
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_INDUSTRIAL), 0.0, "workshop nao foi construido, industrial deveria continuar zero")
	city.queue_free()

func test_axis_strength_militar_is_normalized_per_bucket_size():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_almost_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_MILITAR), 1.0 / 5.0, 0.001)
	city.buildings["archery_range"] = true
	assert_almost_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_MILITAR), 2.0 / 5.0, 0.001)
	city.queue_free()

func test_axis_strength_arcana_is_normalized_per_bucket_size():
	var city := City.new()
	city.buildings["sages_tower"] = true
	assert_almost_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_ARCANA), 1.0 / 6.0, 0.001)
	city.buildings["arcane_tower"] = true
	assert_almost_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_ARCANA), 2.0 / 6.0, 0.001)
	city.queue_free()

func test_axis_strength_militar_full_bucket_reaches_one():
	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true
	assert_almost_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_MILITAR), 1.0, 0.001)
	city.queue_free()

## Documenta a propriedade arquitetural central (nao so a matematica):
## identidade nao regride nem se dilui com predios de OUTRO eixo.
func test_axis_strength_is_monotonic_and_unaffected_by_other_axes():
	var city := City.new()
	city.buildings["granary"] = true
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_AGRICOLA), 1.0)

	city.buildings["barracks"] = true
	city.buildings["market"] = true
	assert_eq(CityIdentity.axis_strength(city, CityIdentity.AXIS_AGRICOLA), 1.0, "forca agricola nao deveria mudar so porque outros predios (de outros eixos) foram construidos")
	city.queue_free()

func test_dominant_axis_is_empty_string_with_no_buildings():
	var city := City.new()
	assert_eq(CityIdentity.dominant_axis(city), "")
	city.queue_free()

func test_dominant_axis_picks_the_single_highest_strength_axis():
	var city := City.new()
	city.buildings["granary"] = true
	assert_eq(CityIdentity.dominant_axis(city), CityIdentity.AXIS_AGRICOLA)
	city.queue_free()

func test_dominant_axis_tie_break_uses_fixed_axes_order():
	var city := City.new()
	city.buildings["granary"] = true # agricola 1/1
	city.buildings["workshop"] = true # industrial 1/1, empate
	assert_eq(CityIdentity.dominant_axis(city), CityIdentity.AXIS_AGRICOLA, "empate deveria ser resolvido pela ordem fixa de AXES (agricola vem antes de industrial)")
	city.queue_free()

## Confirma que a normalizacao por tamanho de balde funciona como
## pretendido: um balde PEQUENO completo (agricola 1/1=1.0) vence um
## balde GRANDE parcial (militar 1/5=0.2).
func test_dominant_axis_prefers_higher_strength_over_bucket_completeness():
	var city := City.new()
	city.buildings["walls"] = true # militar 1/5 = 0.2
	city.buildings["granary"] = true # agricola 1/1 = 1.0
	assert_eq(CityIdentity.dominant_axis(city), CityIdentity.AXIS_AGRICOLA)
	city.queue_free()

## Protecao contra alguem adicionar um predio novo ao BuildingDatabase no
## futuro e presumir automaticamente que ele conta pra alguma
## especializacao — so predios listados em AXIS_BUILDINGS contam.
func test_dominant_axis_ignores_buildings_outside_any_axis():
	var city := City.new()
	city.buildings["some_future_building_not_mapped_to_any_axis"] = true
	assert_eq(CityIdentity.dominant_axis(city), "")
	city.queue_free()

func test_apply_yield_bonus_does_nothing_with_no_buildings():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	var city := City.new()
	CityIdentity.apply_yield_bonus(totals, city)
	assert_eq(totals, {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0})
	city.queue_free()

func test_apply_yield_bonus_agricola_only_affects_food():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	var city := City.new()
	city.buildings["granary"] = true
	CityIdentity.apply_yield_bonus(totals, city)
	assert_almost_eq(totals.food, 10.0 * (1.0 + CityIdentity.AGRICOLA_FOOD_BONUS_MAX), 0.01)
	assert_almost_eq(totals.production, 10.0, 0.01)
	assert_almost_eq(totals.gold, 10.0, 0.01)
	assert_almost_eq(totals.mana, 10.0, 0.01)
	city.queue_free()

func test_apply_yield_bonus_industrial_only_affects_production():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	var city := City.new()
	city.buildings["workshop"] = true
	CityIdentity.apply_yield_bonus(totals, city)
	assert_almost_eq(totals.production, 10.0 * (1.0 + CityIdentity.INDUSTRIAL_PRODUCTION_BONUS_MAX), 0.01)
	assert_almost_eq(totals.food, 10.0, 0.01)
	city.queue_free()

func test_apply_yield_bonus_comercial_only_affects_gold():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	var city := City.new()
	city.buildings["market"] = true
	CityIdentity.apply_yield_bonus(totals, city)
	assert_almost_eq(totals.gold, 10.0 * (1.0 + CityIdentity.COMERCIAL_GOLD_BONUS_MAX), 0.01)
	assert_almost_eq(totals.production, 10.0, 0.01)
	city.queue_free()

func test_apply_yield_bonus_arcana_scales_with_partial_strength():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	var city := City.new()
	city.buildings["sages_tower"] = true # arcana 1/6
	CityIdentity.apply_yield_bonus(totals, city)
	assert_almost_eq(totals.mana, 10.0 * (1.0 + CityIdentity.ARCANA_MANA_BONUS_MAX * (1.0 / 6.0)), 0.01)
	city.queue_free()

func test_militar_unit_cost_multiplier_is_one_without_barracks():
	var city := City.new()
	assert_eq(CityIdentity.militar_unit_cost_multiplier(city, "men_at_arms"), 1.0)
	city.queue_free()

func test_militar_unit_cost_multiplier_scales_with_militar_strength():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_almost_eq(
		CityIdentity.militar_unit_cost_multiplier(city, "men_at_arms"),
		1.0 - CityIdentity.MILITAR_UNIT_COST_DISCOUNT_MAX * (1.0 / 5.0), 0.001
	)
	for id in ["walls", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true
	assert_almost_eq(
		CityIdentity.militar_unit_cost_multiplier(city, "men_at_arms"),
		1.0 - CityIdentity.MILITAR_UNIT_COST_DISCOUNT_MAX, 0.001
	)
	city.queue_free()

func test_militar_unit_cost_multiplier_is_one_for_non_militar_unit():
	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true
	assert_eq(CityIdentity.militar_unit_cost_multiplier(city, "settler"), 1.0, "Colonizador nao tem predio treinador, nunca deveria receber desconto militar")
	city.queue_free()

func test_militar_unit_cost_multiplier_applies_to_racial_unique_and_stable_units_too():
	var city := City.new()
	city.buildings["barracks"] = true
	assert_lt(CityIdentity.militar_unit_cost_multiplier(city, "dwarf_axeguard"), 1.0, "unidade racial exclusiva treina no Quartel (BuildingDatabase.building_that_trains), deveria receber o desconto")

	var city2 := City.new()
	city2.buildings["stable"] = true
	assert_lt(CityIdentity.militar_unit_cost_multiplier(city2, "human_knight"), 1.0, "human_knight treina no Estabulo, deveria receber o desconto")
	city.queue_free()
	city2.queue_free()

## Roadmap "Parte B" (B3) — CityIdentity.civilization_axis_strength: media
## simples de axis_strength() sobre player.cities, ainda cega a tecnologia
## (essa funcao so agrega dado de cidade, nunca toca TechData/TechDatabase).
func test_civilization_axis_strength_is_zero_with_no_cities():
	var player := PlayerData.new(CivilizationData.new())
	assert_eq(CityIdentity.civilization_axis_strength(player, CityIdentity.AXIS_AGRICOLA), 0.0)

func test_civilization_axis_strength_averages_across_cities():
	var player := PlayerData.new(CivilizationData.new())
	var city_with_granary := City.new()
	city_with_granary.buildings["granary"] = true # agricola 1.0
	var city_without := City.new()
	player.cities.append(city_with_granary)
	player.cities.append(city_without)

	assert_almost_eq(CityIdentity.civilization_axis_strength(player, CityIdentity.AXIS_AGRICOLA), 0.5, 0.001)

	city_with_granary.queue_free()
	city_without.queue_free()
