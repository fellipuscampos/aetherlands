extends GutTest

## Cobre BuildingDatabase: consulta por id, unicidade e o mapeamento prédio -> tropa treinada.
##
## Fase 25: o catálogo passou a ter só os prédios V2 (Doutrinas, Escolas, economia). Os contratos V1
## que viviam aqui (soma de bônus de comida/ouro/produção/mana por prédio, bônus de defesa de
## Muralhas, Celeiro/Mercado/Guarnição/Entreposto, fallback de tropa racial no Quartel, Estábulo do
## Batedor Montado, Mercado treinando Mercador) deixaram de existir junto com o próprio prédio.

func test_get_building_returns_known_building():
	var market = BuildingDatabase.get_building("v2_building_market")
	assert_not_null(market)
	assert_eq(market.id, "v2_building_market")
	assert_ne(market.display_name, "")

func test_get_building_returns_null_for_unknown_id():
	assert_null(BuildingDatabase.get_building("nao_existe"))

func test_v1_building_ids_are_no_longer_in_the_catalog():
	for id in ["granary", "granary_2", "market", "market_2", "walls", "walls_2", "fortress", "barracks", "stable", "garrison", "trading_post", "sages_tower", "arcane_sanctuary", "watchtower"]:
		assert_null(BuildingDatabase.get_building(id), id)

func test_every_building_is_a_v2_id():
	for b in BuildingDatabase.all_buildings():
		assert_true(V2ResearchDatabase.is_v2_id(b.id), b.id)

func test_all_buildings_have_unique_ids():
	var ids := []
	for b in BuildingDatabase.all_buildings():
		assert_false(b.id in ids, "cada predio deveria ter um id unico")
		ids.append(b.id)

func test_building_that_trains_finds_the_matching_training_building():
	var hall = BuildingDatabase.building_that_trains("v2_unit_shieldbearer")
	assert_not_null(hall)
	assert_eq(hall.id, "v2_building_guardian_hall")

func test_line_evolutions_train_in_the_base_form_building():
	assert_eq(BuildingDatabase.building_that_trains("v2_unit_sentinel").id, "v2_building_guardian_hall")
	assert_eq(BuildingDatabase.building_that_trains("v2_unit_bombard").id, "v2_building_siege_arsenal")

func test_building_that_trains_returns_null_for_the_settler_and_the_starter_guard():
	assert_null(BuildingDatabase.building_that_trains("settler"), "Colonizador nao exige predio")
	assert_null(BuildingDatabase.building_that_trains("warrior"), "o Guarda inicial nao tem linha de producao")

func test_requires_building_always_points_to_an_existing_building():
	for b in BuildingDatabase.all_buildings():
		if b.requires_building != "":
			assert_not_null(BuildingDatabase.get_building(b.requires_building), "%s exige %s" % [b.id, b.requires_building])

func test_mastery_buildings_require_the_line_building():
	assert_eq(BuildingDatabase.get_building("v2_building_guardian_mastery").requires_building, "v2_building_guardian_hall")
	assert_eq(BuildingDatabase.get_building("v2_building_grand_arsenal").requires_building, "v2_building_siege_arsenal")

## Todo kind treinável (exceto o Colonizador) precisa resolver para ALGUM prédio -- direto
## (trains_unit literal) ou pelo fallback de linha -- senão seria impossível produzi-lo.
func test_every_trainable_kind_except_the_settler_resolves_to_a_training_building():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind == "settler":
			continue
		assert_not_null(BuildingDatabase.building_that_trains(kind), "%s deveria resolver pra algum predio de treino" % kind)

func test_every_trains_unit_is_a_known_unit_kind():
	for b in BuildingDatabase.all_buildings():
		if b.trains_unit != "":
			assert_true(UnitDatabase.is_known_kind(b.trains_unit), "%s treina %s" % [b.id, b.trains_unit])

func test_fallback_trainers_point_to_existing_buildings():
	for kind in BuildingDatabase.UNIT_TRAINER_FALLBACK:
		assert_not_null(BuildingDatabase.get_building(BuildingDatabase.UNIT_TRAINER_FALLBACK[kind]), kind)
