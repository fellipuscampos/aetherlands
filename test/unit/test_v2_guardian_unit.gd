extends GutTest

## Guardião (v2_unit_guardian, Aetherlands V2 Fase 4): definição da unidade e a resolução
## da forma treinável da linha (V2UnitLine) — com N5 o Salão dos Guardiões oferece o
## Guardião NO LUGAR do Escudeiro. Números = BALANCE PLACEHOLDER; os testes fixam também
## as RELAÇÕES com o Escudeiro, que são o que importa.

const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const HALL := "v2_building_guardian_hall"

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
	if with_hall:
		city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — sem estar em player.cities, a capacidade de Suprimentos seria 0; a
	# BASE (4, sem Fazenda) já cobre o Guardião (custo 2).
	player.cities.append(city)
	_cities.append(city)
	return city

# --- Definição -----------------------------------------------------------------------------------

func test_the_guardian_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(GUARDIAN)
	assert_eq(data.unit_name, "Guardião")
	assert_eq(data.max_hp, 24.0)
	assert_eq(data.attack, 4.0)
	assert_eq(data.defense, 6.0)
	assert_eq(data.movement_points, 2.0)
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.production_cost, 32.0)
	assert_false(data.can_found_city)
	assert_false(data.flies)

func test_the_guardian_is_clearly_tankier_than_the_shieldbearer_but_not_a_dps_unit():
	var shield := UnitDatabase.create_unit(SHIELD)
	var guardian := UnitDatabase.create_unit(GUARDIAN)
	assert_gt(guardian.max_hp, shield.max_hp * 1.25, "resiste claramente mais")
	assert_gt(guardian.defense, shield.defense * 1.25)
	assert_gt(guardian.attack, shield.attack, "ataque ligeiramente maior")
	assert_lt(guardian.attack, guardian.defense, "continua tank: defende mais do que ataca")
	assert_lt(guardian.attack, UnitDatabase.create_unit("men_at_arms").attack, "não vira DPS")
	assert_eq(guardian.movement_points, shield.movement_points, "não ganha mobilidade")
	assert_eq(guardian.vision_range, shield.vision_range)
	assert_gt(guardian.production_cost, shield.production_cost)

func test_more_power_per_tile_it_is_worth_more_than_the_shieldbearer():
	var shield := UnitDatabase.create_unit(SHIELD)
	var guardian := UnitDatabase.create_unit(GUARDIAN)
	var power := func(d: UnitData): return d.attack + d.defense + d.max_hp * 0.15
	assert_gt(power.call(guardian), power.call(shield))

func test_no_upkeep_and_no_special_economy_fields():
	var data := UnitDatabase.create_unit(GUARDIAN)
	assert_eq(data.regen_fraction, 0.0)

func test_the_visual_kind_is_the_id_so_save_and_load_recreate_it():
	assert_eq(UnitDatabase.create_unit(GUARDIAN).visual_kind, GUARDIAN)

func test_it_is_registered_as_a_trainable_kind_once():
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(GUARDIAN), 1)
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count("v2_unit_sentinel"), 1, "Sentinela (N7) também é treinável")

func test_it_belongs_to_the_guardian_line_and_the_provisional_model_exists():
	assert_eq(V2UnitLine.branch_of(GUARDIAN), "guardian")
	var data := UnitDatabase.create_unit(GUARDIAN)
	assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
	assert_true(ResourceLoader.exists(data.animation_scene_path), data.animation_scene_path)
	assert_gt(data.model_scale_multiplier, UnitDatabase.create_unit(SHIELD).model_scale_multiplier, "provisório: maior que o Escudeiro pra distinguir")

func test_race_theme_and_the_v1_units_are_untouched():
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.unit_name(GUARDIAN, race), "Guardião", race)
	assert_eq(UnitDatabase.create_unit(SHIELD).max_hp, 18.0, "o Escudeiro continua igual")
	assert_eq(UnitDatabase.create_unit("warrior").unit_name, "Guarda")
	assert_eq(UnitDatabase.create_unit("homem_de_escudo").unit_name, "Homem de Escudo")

func test_the_hall_is_the_training_building_of_the_guardian_too():
	assert_eq(BuildingDatabase.building_that_trains(GUARDIAN), BuildingDatabase.get_building(HALL))
	assert_eq(BuildingDatabase.building_that_trains(SHIELD), BuildingDatabase.get_building(HALL))

# --- Resolução da forma treinável (genérica) -------------------------------------------------------

func test_highest_unlocked_form_walks_the_line():
	assert_eq(V2UnitLine.highest_unlocked_form(_player(0), "guardian"), "")
	assert_eq(V2UnitLine.highest_unlocked_form(_player(2), "guardian"), "", "N2 não libera unidade")
	assert_eq(V2UnitLine.highest_unlocked_form(_player(3), "guardian"), SHIELD)
	assert_eq(V2UnitLine.highest_unlocked_form(_player(4), "guardian"), SHIELD, "N4 é técnica")
	assert_eq(V2UnitLine.highest_unlocked_form(_player(5), "guardian"), GUARDIAN)

func test_resolve_trainable_form_starts_from_any_form_of_the_line():
	var player := _player(5)
	for id in [SHIELD, GUARDIAN, "v2_unit_sentinel"]:
		assert_eq(V2UnitLine.resolve_trainable_form(player, id), GUARDIAN, id)
	assert_eq(V2UnitLine.resolve_trainable_form(player, "warrior"), "", "unidade V1 não tem linha")
	assert_eq(V2UnitLine.resolve_trainable_form(player, "v2_unit_warrior"), "", "outra Doutrina: nada liberado")

func test_researching_the_mastery_and_legendary_nodes_never_offers_another_form():
	var player := _player(7)
	assert_eq(V2UnitLine.highest_unlocked_form(player, "guardian"), "v2_unit_sentinel")
	# N8/N9 (fora do escopo) não são formas de unidade convencionais: nada muda.
	for n in range(8, 10):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	assert_eq(V2UnitLine.highest_unlocked_form(player, "guardian"), "v2_unit_sentinel")

func test_only_the_current_form_is_trainable():
	var player := _player(3)
	assert_true(V2UnitLine.is_current_trainable_form(player, SHIELD))
	assert_false(V2UnitLine.is_current_trainable_form(player, GUARDIAN))
	player.v2_research.complete_research("v2_doctrine_guardian_4")
	player.v2_research.complete_research("v2_doctrine_guardian_5")
	assert_false(V2UnitLine.is_current_trainable_form(player, SHIELD))
	assert_true(V2UnitLine.is_current_trainable_form(player, GUARDIAN))

# --- Produção (o Salão oferece a forma mais avançada) -----------------------------------------------------

func test_n3_without_n5_the_hall_offers_the_shieldbearer():
	var player := _player(4)
	var city := _city(player)
	assert_true(city.can_train(SHIELD))
	assert_false(city.can_train(GUARDIAN))
	assert_true(player.has_unlocked(SHIELD))
	assert_false(player.has_unlocked(GUARDIAN))

func test_n5_the_hall_offers_the_guardian_and_not_the_shieldbearer():
	var player := _player(5)
	var city := _city(player)
	assert_true(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD), "o Escudeiro deixa de ser produção normal")
	assert_true(player.has_unlocked(SHIELD), "continua pesquisado (existentes evoluem)")
	assert_true(player.has_unlocked(GUARDIAN))

func test_the_guardian_still_needs_the_hall_in_the_city():
	var player := _player(5)
	var city := _city(player, false)
	assert_false(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD))

func test_the_guardian_needs_n5_even_with_a_hall():
	var player := _player(4)
	assert_false(_city(player).can_train(GUARDIAN))

func test_the_v1_barracks_never_trains_the_guardian():
	var player := _player(5)
	var city := _city(player, false)
	city.buildings["barracks"] = true
	assert_false(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD))

func test_production_is_per_civilization():
	var researcher := _player(5)
	var other := _player(3)
	var city := _city(other)
	assert_true(city.can_train(SHIELD), "quem parou no N3 continua no Escudeiro")
	assert_false(city.can_train(GUARDIAN))
	assert_true(_city(researcher).can_train(GUARDIAN))

func test_production_cost_comes_from_the_unit_data():
	var player := _player(5)
	var city := _city(player)
	city.set_production(GUARDIAN)
	assert_eq(city.production_cost(), 32.0)

func test_debug_reset_keeps_existing_content_but_production_follows_the_research():
	var player := _player(5)
	var city := _city(player)
	player.v2_research.reset()
	assert_true(city.buildings.has(HALL), "o prédio existente não é destruído")
	assert_false(city.can_train(GUARDIAN), "sem N5 não treina Guardião")
	assert_false(city.can_train(SHIELD), "sem N3 nem Escudeiro")
	for n in range(1, 4):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	assert_true(city.can_train(SHIELD), "a produção volta a respeitar a pesquisa atual")

func test_an_ai_civilization_with_n5_resolves_the_guardian_without_breaking():
	var rival := _player(5)
	var city := _city(rival)
	assert_true(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD))
	# Mesmo filtro da decisão de produção da IA (RivalAI._production_candidates).
	var kinds := UnitDatabase.PLAYER_TRAINABLE_KINDS
	var offered := kinds.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(GUARDIAN), "a IA passa a considerar a forma mais avançada")
	assert_false(offered.has(SHIELD))

func test_a_civilization_without_v2_never_sees_either_form():
	var player := _player(0)
	var city := _city(player)
	assert_false(city.can_train(SHIELD))
	assert_false(city.can_train(GUARDIAN))
