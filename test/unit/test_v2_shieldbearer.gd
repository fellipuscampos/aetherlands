extends GutTest

## Escudeiro (v2_unit_shieldbearer, Aetherlands V2 Fase 3): a unidade-base da
## Doutrina do Guardião, liberada pelo nó v2_doctrine_guardian_3 e treinada só no
## Salão dos Guardiões. Os números são BALANCE PLACEHOLDER — estes testes fixam
## as RELAÇÕES com as tropas V1 (mais resistente e menos ofensivo que o Guarda),
## não os valores absolutos.

const KIND := "v2_unit_shieldbearer"
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

func _city_for(player: PlayerData) -> City:
	var city := City.new()
	city.owner_player = player
	# Aetherlands V2, Fase 15 — sem estar em player.cities, a capacidade de Suprimentos seria 0
	# pro runtime; a BASE (4, sem nenhuma Fazenda) já cobre o Escudeiro (custo 1).
	player.cities.append(city)
	_cities.append(city)
	return city

func _research_guardian(player: PlayerData, through_tier: int) -> void:
	for n in range(1, through_tier + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)

# --- Dados da unidade ------------------------------------------------------------------------------

func test_the_unit_exists_with_the_canonical_id_and_name():
	var data := UnitDatabase.create_unit(KIND)
	assert_eq(data.unit_name, "Escudeiro")
	assert_eq(data.unit_name, V2ResearchDatabase.node_for_unlock_id(KIND).display_name, "o nome da unidade é o do nó")

func test_the_visual_kind_is_the_id_so_save_and_load_can_recreate_it():
	assert_eq(UnitDatabase.create_unit(KIND).visual_kind, KIND)

func test_it_is_a_trainable_kind_exactly_once():
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(KIND), 1)

func test_shieldbearer_is_tankier_but_hits_softer_than_the_guard():
	var shield := UnitDatabase.create_unit(KIND)
	var guard := UnitDatabase.create_unit("warrior")
	assert_gt(shield.max_hp, guard.max_hp, "mais vida")
	assert_gt(shield.defense, guard.defense, "mais defesa")
	assert_lt(shield.attack, guard.attack, "ataque menor")
	assert_gt(shield.attack, 0.0, "ainda ataca")

func test_shieldbearer_does_not_eclipse_the_v1_men_at_arms():
	var shield := UnitDatabase.create_unit(KIND)
	var men := UnitDatabase.create_unit("men_at_arms")
	assert_lt(shield.attack, men.attack)
	assert_lte(shield.defense, men.defense)

func test_movement_vision_and_range_are_normal_for_infantry():
	var shield := UnitDatabase.create_unit(KIND)
	var guard := UnitDatabase.create_unit("warrior")
	assert_eq(shield.movement_points, guard.movement_points, "movimento normal")
	assert_eq(shield.vision_range, guard.vision_range)
	assert_eq(shield.attack_range, 1, "corpo a corpo")
	assert_false(shield.can_found_city)
	assert_false(shield.flies)

func test_no_upkeep_and_no_special_economy_fields():
	var shield := UnitDatabase.create_unit(KIND)
	assert_eq(shield.gold_reward, 0.0)
	assert_eq(shield.regen_fraction, 0.0)

func test_cost_sits_between_the_guard_and_the_men_at_arms():
	var cost := UnitDatabase.create_unit(KIND).production_cost
	assert_gt(cost, UnitDatabase.create_unit("warrior").production_cost)
	assert_lt(cost, UnitDatabase.create_unit("men_at_arms").production_cost + 0.01)

func test_the_provisional_model_exists():
	var data := UnitDatabase.create_unit(KIND)
	assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
	assert_true(ResourceLoader.exists(data.animation_scene_path), data.animation_scene_path)

func test_race_theme_names_it_for_every_race():
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.unit_name(KIND, race), "Escudeiro", race)

func test_v1_units_are_untouched():
	assert_eq(UnitDatabase.create_unit("warrior").unit_name, "Guarda")
	assert_eq(UnitDatabase.create_unit("warrior").attack, 4.0)
	assert_eq(UnitDatabase.create_unit("men_at_arms").unit_name, "Homem de Armas")
	assert_eq(UnitDatabase.create_unit("homem_de_escudo").unit_name, "Homem de Escudo")

# --- Treinar: pesquisa N3 + Salão, nunca o Quartel ------------------------------------------------------

func test_cannot_train_with_nothing():
	assert_false(_city_for(_player()).can_train(KIND))

func test_cannot_train_with_the_hall_but_without_n3():
	var player := _player()
	var city := _city_for(player)
	_research_guardian(player, 2)
	city.buildings[HALL] = true
	assert_false(city.can_train(KIND), "o Escudeiro exige o N3, mesmo com o Salão")
	assert_false(player.has_unlocked(KIND))

func test_cannot_train_with_n3_but_without_the_hall():
	var player := _player()
	var city := _city_for(player)
	_research_guardian(player, 3)
	assert_true(player.has_unlocked(KIND))
	assert_false(city.can_train(KIND), "o Escudeiro exige o Salão na cidade")

func test_can_train_with_n3_and_the_hall():
	var player := _player()
	var city := _city_for(player)
	_research_guardian(player, 3)
	city.buildings[HALL] = true
	assert_true(player.has_unlocked(KIND))
	assert_true(city.can_train(KIND))

func test_the_v1_barracks_is_neither_required_nor_enough():
	var player := _player()
	var city := _city_for(player)
	_research_guardian(player, 3)
	city.buildings["barracks"] = true
	assert_false(city.can_train(KIND), "Quartel não substitui o Salão")
	city.buildings.erase("barracks")
	city.buildings[HALL] = true
	assert_true(city.can_train(KIND), "e o Salão não precisa do Quartel")

func test_the_hall_alone_does_not_train_any_v1_unit():
	var player := _player()
	var city := _city_for(player)
	_research_guardian(player, 3)
	city.buildings[HALL] = true
	assert_false(city.can_train("men_at_arms"), "o Salão não treina o Homem de Armas")
	assert_false(city.can_train("archer"))

func test_it_is_not_a_racial_unit_so_every_race_can_train_it():
	for race in ["human", "elf", "dwarf", "orc"]:
		var player := _player(race)
		var city := _city_for(player)
		_research_guardian(player, 3)
		city.buildings[HALL] = true
		assert_true(city.can_train(KIND), race)

func test_a_civilization_without_the_research_cannot_train_even_in_a_city_with_the_hall():
	var researcher := _player()
	var other := _player()
	_research_guardian(researcher, 3)
	var city := _city_for(other)
	city.buildings[HALL] = true # ex.: cidade conquistada com o Salão
	assert_false(city.can_train(KIND), "o unlock é da civilização, não da cidade")

## Fase 25: fora da V2 só o Colonizador é treinável; nenhuma tropa V1 abre fila, nem com o Quartel vestigial.
func test_only_the_settler_is_trainable_outside_the_v2_lines():
	var city := _city_for(_player())
	assert_true(city.can_train("settler"))
	assert_false(city.can_train("warrior"))
	assert_false(city.can_train("men_at_arms"))
	city.buildings["barracks"] = true
	assert_false(city.can_train("men_at_arms"))

# --- Produção pelo pipeline normal -------------------------------------------------------------------

func test_it_is_produced_through_the_normal_city_production_queue():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(7, 7, 4242)
	var player := _player()
	var city := _city_for(player)
	for coord in hex_grid.tiles:
		if not hex_grid.tiles[coord].blocks_land_units() and WorldSetup.find_spawn_tile(hex_grid, coord) != WorldSetup.NO_SPAWN_COORD:
			city.coord = coord
			break
	_research_guardian(player, 3)
	city.buildings[HALL] = true

	city.set_production(KIND)
	assert_eq(city.production_item, KIND)
	assert_eq(city.production_cost(), UnitDatabase.create_unit(KIND).production_cost)
	city.stored_production = city.production_cost()
	var result: Dictionary = city.process_turn(hex_grid)

	assert_eq(result.spawn_unit_kind, KIND, "process_turn devolve o kind pra GameManager spawnar")
	assert_eq(city.production_item, "", "cidade fica ociosa depois, como com qualquer unidade")
	hex_grid.free()
