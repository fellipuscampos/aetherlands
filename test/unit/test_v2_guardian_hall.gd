extends GutTest

## Salão dos Guardiões (v2_building_guardian_hall, Aetherlands V2 Fase 3): o
## prédio de treino da linha do Guardião, liberado pelo nó v2_doctrine_guardian_2.
## Usa a MESMA cadeia de construção dos prédios V1 (City.can_build, slots,
## BuildingDatabase, trains_unit) — só o gate de pesquisa é V2.

const HALL := "v2_building_guardian_hall"

var _owned_players: Array[PlayerData] = []
var _cities: Array[City] = []

func after_each():
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()

func _player(race: String = "human") -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## Só até o N3: com o N5 o Salão passa a oferecer o Guardião no lugar do Escudeiro (Fase 4).
func _research_through(player: PlayerData, tier: int) -> void:
	for n in range(1, tier + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)

func _city_for(player: PlayerData) -> City:
	var city := City.new()
	city.owner_player = player
	# Aetherlands V2, Fase 15 — sem estar em player.cities, a capacidade de Suprimentos seria 0
	# (nunca creditada a nenhuma cidade), bloqueando até o Escudeiro (custo 1); a BASE (4, sem
	# nenhuma Fazenda) já é suficiente pra uma unidade de custo 1, então nada mais precisa mudar
	# aqui -- os testes de limite de SLOT desta fixture continuam com o City Level/prédios como
	# estavam.
	player.cities.append(city)
	_cities.append(city)
	return city

# --- Dados do prédio ---------------------------------------------------------------------------------

func test_the_hall_exists_with_the_canonical_id_and_name():
	var hall := BuildingDatabase.get_building(HALL)
	assert_not_null(hall)
	assert_eq(hall.id, HALL)
	assert_eq(hall.display_name, "Salão dos Guardiões")
	assert_eq(hall.display_name, V2ResearchDatabase.node_for_unlock_id(HALL).display_name, "o nome do prédio é o do nó")

func test_the_hall_trains_the_shieldbearer_and_nothing_else():
	var hall := BuildingDatabase.get_building(HALL)
	assert_eq(hall.trains_unit, "v2_unit_shieldbearer")
	assert_eq(BuildingDatabase.building_that_trains("v2_unit_shieldbearer"), hall)

func test_the_hall_does_not_depend_on_the_v1_barracks():
	var hall := BuildingDatabase.get_building(HALL)
	assert_eq(hall.requires_building, "", "nenhum pré-requisito de prédio")

func test_the_hall_has_a_provisional_cost_and_a_model_that_exists():
	var hall := BuildingDatabase.get_building(HALL)
	assert_gt(hall.production_cost, 0.0)
	assert_true(ResourceLoader.exists(hall.model_scene_path), "modelo provisório reaproveitado: %s" % hall.model_scene_path)

func test_the_hall_is_registered_once_and_v1_buildings_are_untouched():
	var count := 0
	for building in BuildingDatabase.all_buildings():
		if building.id == HALL:
			count += 1
	assert_eq(count, 1)
	assert_null(BuildingDatabase.get_building("barracks"), "Fase 25: o Quartel V1 saiu do catálogo")

func test_race_theme_names_the_hall_for_every_race():
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.building_name(HALL, race), "Salão dos Guardiões", race)

# --- Construir: gate de pesquisa ---------------------------------------------------------------------

func test_cannot_build_without_the_research():
	var city := _city_for(_player())
	assert_false(city.can_build(HALL))
	assert_false(city._research_unlocked_for_building(HALL))

func test_cannot_build_with_only_n1():
	var player := _player()
	var city := _city_for(player)
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_false(city.can_build(HALL))

func test_can_build_once_n2_is_researched():
	var player := _player()
	var city := _city_for(player)
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	player.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_true(city.can_build(HALL))

func test_a_city_without_owner_cannot_build_it():
	var city := City.new()
	_cities.append(city)
	assert_false(city.can_build(HALL))

func test_the_v1_barracks_or_v1_techs_do_not_unlock_the_hall():
	var player := _player()
	var city := _city_for(player)
	city.buildings["barracks"] = true
	assert_false(city.can_build(HALL), "só a pesquisa V2 libera o Salão")

func test_the_hall_does_not_require_the_barracks_once_researched():
	var player := _player()
	var city := _city_for(player)
	_research_through(player, 3)
	assert_false(city.buildings.has("barracks"))
	assert_true(city.can_build(HALL))

func test_the_unlock_belongs_to_the_researching_civilization_only():
	var a := _player()
	var b := _player()
	var city_b := _city_for(b)
	a.v2_research.complete_research("v2_doctrine_guardian_1")
	a.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_false(city_b.can_build(HALL))

func test_building_the_hall_uses_a_normal_building_slot():
	var player := _player()
	var city := _city_for(player)
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	player.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_eq(city.used_building_slots(), 0)
	city.buildings[HALL] = true
	assert_eq(city.used_building_slots(), 1)
	assert_false(city.can_build(HALL), "não constrói duas vezes na mesma cidade")

func test_a_full_city_cannot_build_the_hall_even_with_the_research():
	var player := _player()
	var city := _city_for(player)
	player.v2_research.complete_research("v2_doctrine_guardian_1")
	player.v2_research.complete_research("v2_doctrine_guardian_2")
	city.city_level = 1 # Fase 13: 4 slots (não é mais população)
	for id in ["granary", "workshop", "market", "walls"]:
		city.buildings[id] = true
	assert_false(city.can_build(HALL), "a regra de slots vale igual pro prédio V2")
	city.city_level = 2 # 7 slots
	assert_true(city.can_build(HALL))

func test_building_v1_buildings_is_unchanged_by_the_v2_gate():
	var city := _city_for(_player())
	assert_false(city.can_build("sages_tower"), "Fase 25: prédio V1 nunca é construível")
	assert_false(city.can_build("barracks"))

# --- Treinar: o Salão é o que libera o Escudeiro ----------------------------------------------------------

func test_the_hall_is_the_building_that_makes_the_shieldbearer_trainable():
	var player := _player()
	var city := _city_for(player)
	_research_through(player, 3)
	assert_false(city.can_train("v2_unit_shieldbearer"), "sem o Salão construído")
	city.buildings[HALL] = true
	assert_true(city.can_train("v2_unit_shieldbearer"))

func test_the_hall_in_another_city_does_not_help():
	var player := _player()
	var city_a := _city_for(player)
	var city_b := _city_for(player)
	_research_through(player, 3)
	city_a.buildings[HALL] = true
	assert_true(city_a.can_train("v2_unit_shieldbearer"))
	assert_false(city_b.can_train("v2_unit_shieldbearer"), "o Salão vale só na própria cidade")
