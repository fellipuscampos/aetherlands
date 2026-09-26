extends GutTest

## Bastião de Maestria (v2_building_guardian_mastery, Aetherlands V2 Fase 6): a estrutura de
## Maestria da linha do Guardião (nó N8, `mastery_building`). Prédio REAL pelo mesmo caminho dos
## demais (BuildingData, City.can_build, slots, save) — só o gate de pesquisa é V2. Única função:
## habilitar o treino do candidato Lendário. Custo (55 PP) = BALANCE PLACEHOLDER.

const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"
const CHAMPION := "v2_legendary_guardian_champion"

var _players: Array[PlayerData] = []
var _cities: Array[City] = []

func after_each():
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(through: int) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

func _city(player: PlayerData, with_hall: bool = true) -> City:
	var city := City.new()
	city.owner_player = player
	city.city_level = 3 # slots de sobra (Fazenda ×4 sozinha já ocupa os 4 do City Level I -- §26 da Fase 13): aqui o assunto não é o limite de prédios
	if with_hall:
		city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — o Campeão custa 5 Suprimentos, acima até da base de uma cidade
	# sozinha (4); sem estar em player.cities e sem Fazenda, o treino ficaria sempre bloqueado por
	# capacidade, mesmo com prédio/pesquisa/slot corretos (o assunto deste arquivo é o Bastião).
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	# Prédios de treino/Maestria/Fazenda têm gold_upkeep e não há Mercado nesta cidade -- sem Ouro
	# de sobra a civilização entraria em Déficit sozinha, bloqueando o treino do Campeão por um
	# motivo alheio ao Bastião (o assunto deste arquivo).
	if player.gold <= 0.0:
		player.gold = 1000.0
	player.cities.append(city)
	_cities.append(city)
	return city

# --- Dados ---------------------------------------------------------------------------------------------

func test_the_mastery_building_exists_with_the_canonical_id_and_name():
	var building := BuildingDatabase.get_building(MASTERY)
	assert_not_null(building)
	assert_eq(building.id, MASTERY)
	assert_eq(building.display_name, "Bastião de Maestria")
	assert_eq(building.display_name, V2ResearchDatabase.node_for_unlock_id(MASTERY).display_name, "o nome do prédio é o do nó")

func test_its_only_function_is_to_enable_the_legendary_candidate():
	var building := BuildingDatabase.get_building(MASTERY)
	assert_eq(building.trains_unit, CHAMPION)
	assert_eq(BuildingDatabase.building_that_trains(CHAMPION), building)

func test_it_requires_the_hall_and_does_not_replace_it():
	var building := BuildingDatabase.get_building(MASTERY)
	assert_eq(building.requires_building, HALL)
	assert_eq(BuildingDatabase.get_building(HALL).trains_unit, "v2_unit_shieldbearer", "o Salão continua treinando a linha convencional")
	assert_true(BuildingDatabase.get_building(HALL) != building)

func test_the_cost_is_a_clear_step_above_the_hall_and_below_the_champion():
	var cost := BuildingDatabase.get_building(MASTERY).production_cost
	assert_eq(cost, 55.0)
	assert_gt(cost, BuildingDatabase.get_building(HALL).production_cost * 2.0, "significativamente mais caro que o Salão")
	assert_lt(cost, UnitDatabase.create_unit(CHAMPION).production_cost, "e ainda construível antes da Lendária")

func test_it_has_no_v1_tech_gate_and_no_upkeep_field():
	var names: Array = BuildingDatabase.get_building(MASTERY).get_property_list().map(func(p): return p.name)
	assert_false("upkeep" in names)

func test_the_provisional_model_exists_and_the_name_is_themed_for_every_race():
	var building := BuildingDatabase.get_building(MASTERY)
	assert_true(ResourceLoader.exists(building.model_scene_path), building.model_scene_path)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(MASTERY, race), "Bastião de Maestria", race)

func test_it_is_registered_once_and_the_hall_is_untouched():
	var count := BuildingDatabase.all_buildings().filter(func(b): return b.id == MASTERY).size()
	assert_eq(count, 1)
	assert_eq(BuildingDatabase.get_building(HALL).production_cost, 22.0)
	assert_null(BuildingDatabase.get_building("barracks"), "Fase 25: o Quartel V1 saiu do catálogo")

# --- Construir -----------------------------------------------------------------------------------------

func test_it_cannot_be_built_before_n8():
	var player := _player(7)
	var city := _city(player)
	assert_false(city.can_build(MASTERY))
	assert_false(city._research_unlocked_for_building(MASTERY))

func test_it_can_be_built_after_n8_in_a_city_with_the_hall():
	var player := _player(8)
	var city := _city(player)
	assert_true(city.can_build(MASTERY))

func test_a_city_without_the_hall_cannot_build_it_even_with_n8():
	var player := _player(8)
	var city := _city(player, false)
	assert_true(city._research_unlocked_for_building(MASTERY), "a pesquisa está ok...")
	assert_false(city._prerequisite_building_present(MASTERY), "...falta o Salão")
	assert_false(city.can_build(MASTERY))
	city.buildings[HALL] = true
	assert_true(city.can_build(MASTERY))

func test_the_barracks_and_v1_techs_do_not_unlock_or_replace_the_hall_requirement():
	var player := _player(7)
	var city := _city(player, false)
	city.buildings["barracks"] = true
	assert_false(city.can_build(MASTERY))

func test_it_uses_a_normal_building_slot_and_is_built_only_once():
	var player := _player(8)
	var city := _city(player)
	var used := city.used_building_slots()
	city.buildings[MASTERY] = true
	assert_eq(city.used_building_slots(), used + 1)
	assert_false(city.can_build(MASTERY), "não constrói duas vezes na mesma cidade")

func test_a_full_city_cannot_build_it_even_with_the_research():
	var player := _player(8)
	var city := _city(player)
	city.city_level = 1 # Fase 13: 4 slots (não é mais população) -- Salão + 3 mais enche
	for id in ["granary", "workshop", "market"]:
		city.buildings[id] = true
	assert_false(city.can_build(MASTERY), "a regra de slots é a de sempre")
	city.city_level = 2 # 7 slots
	assert_true(city.can_build(MASTERY))

func test_the_unlock_belongs_to_the_researching_civilization_only():
	var researcher := _player(8)
	var other := _player(7)
	var other_city := _city(other)
	assert_true(_city(researcher).can_build(MASTERY))
	assert_false(other_city.can_build(MASTERY))

func test_v1_buildings_are_not_affected():
	var city := _city(_player(0))
	assert_false(city.can_build("sages_tower"), "Fase 25: prédio V1 nunca é construível")
	assert_false(city.can_build("barracks"))

func test_it_goes_through_the_normal_production_queue():
	var player := _player(8)
	var city := _city(player)
	city.set_production(MASTERY)
	assert_eq(city.production_item, MASTERY)
	assert_eq(city.production_cost(), 55.0)

# --- Efeito: habilita o Campeão, não a linha convencional -------------------------------------------------------

func test_the_champion_needs_the_mastery_building_the_hall_is_not_enough():
	var player := _player(9)
	var city := _city(player) # só o Salão
	assert_false(city.can_train(CHAMPION))
	city.buildings[MASTERY] = true
	assert_true(city.can_train(CHAMPION))

func test_the_mastery_building_needs_n9_to_train_the_champion():
	var player := _player(8)
	var city := _city(player)
	city.buildings[MASTERY] = true
	assert_false(city.can_train(CHAMPION), "N8 dá o prédio; o Campeão é do N9")
	assert_false(player.has_unlocked(CHAMPION))

func test_the_sentinel_does_not_need_the_mastery_building():
	var player := _player(7)
	var city := _city(player)
	assert_true(city.can_train("v2_unit_sentinel"), "a linha convencional é do Salão")
	assert_false(city.buildings.has(MASTERY))

func test_the_mastery_building_does_not_train_the_conventional_chain():
	var player := _player(9)
	var city := _city(player, false)
	city.buildings[MASTERY] = true # sem o Salão (situação forçada)
	assert_false(city.can_train("v2_unit_sentinel"), "o Bastião não treina a cadeia convencional")
	assert_false(city.can_train("v2_unit_guardian"))
	assert_false(city.can_train("v2_unit_shieldbearer"))
