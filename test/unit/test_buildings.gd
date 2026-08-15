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
	assert_eq(bonus.mana, 0)

## Torre dos Sabios (Ponto 3, "Economia Arcana"): da vida numerica ao "Ergue
## a Torre dos Sabios" que a descricao de canalizacao_base ja promete (ver
## TechDatabase.gd) — pedido do usuario: "bonus de predios arcanos (ex:
## Torre dos Sabios)".
func test_total_bonus_sums_mana_from_the_sages_tower():
	var built = {"sages_tower": true}
	var bonus = BuildingDatabase.total_bonus(built)
	assert_eq(bonus.mana, 3)
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

## Predios de treino (Quartel em diante): cada um libera exatamente uma
## tropa de combate — ver City.can_train().
func test_building_that_trains_finds_the_matching_training_building():
	var barracks = BuildingDatabase.building_that_trains("warrior")
	assert_not_null(barracks)
	assert_eq(barracks.id, "barracks")

func test_building_that_trains_returns_null_for_kind_without_a_building():
	assert_null(BuildingDatabase.building_that_trains("settler"), "Colonizador nao deveria exigir predio nenhum")

## Tropa racial exclusiva (UnitDatabase.RACE_UNIQUE_KIND) nao tem
## BuildingData proprio com trains_unit == kind — cai no Quartel, o mesmo
## predio que ja treina o Guerreiro comum (ver comentario de
## building_that_trains).
func test_building_that_trains_falls_back_to_barracks_for_racial_units():
	for kind in ["human_knight", "dwarf_axeguard", "orc_berserker", "elf_ranger"]:
		var building = BuildingDatabase.building_that_trains(kind)
		assert_not_null(building, "%s deveria cair no Quartel" % kind)
		assert_eq(building.id, "barracks")

## Regressao: predios de RENDIMENTO/DEFESA (Celeiro, Muralhas...) nao tem
## trains_unit preenchido — nao deveriam aparecer como "predio de treino"
## de kind nenhum.
func test_yield_buildings_do_not_train_any_unit():
	for b in BuildingDatabase.all_buildings():
		if b.id in ["granary", "workshop", "market", "walls", "sages_tower"]:
			assert_eq(b.trains_unit, "", "%s nao deveria travar producao de unidade nenhuma" % b.display_name)

## Cada tropa de combate (todo kind de UnitDatabase.PLAYER_TRAINABLE_KINDS
## exceto Colonizador) precisa ter exatamente um predio de treino
## correspondente, senao ficaria impossivel de produzir depois do pivot
## (nenhum predio libera esse kind). Deriva o roster de UnitDatabase em vez
## de listar os kinds a mao aqui — um kind novo la (ex: stone_golem/
## shadow_summoner ao entrar no jogo) so passa a ser coberto automatico.
## Tropa RACIAL exclusiva (UnitDatabase.RACE_UNIQUE_KIND) fica de fora de
## proposito: as 4 nao ganharam um BuildingData proprio, elas caem no
## Quartel por fallback (ver BuildingDatabase.building_that_trains e
## test_building_that_trains_falls_back_to_barracks_for_racial_units
## acima) — bater 0 aqui e o resultado ESPERADO pra elas, nao uma falha.
func test_every_combat_unit_kind_has_exactly_one_training_building():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind == "settler" or UnitDatabase.race_for_unique_kind(kind) != "":
			continue
		var matches := 0
		for b in BuildingDatabase.all_buildings():
			if b.trains_unit == kind:
				matches += 1
		assert_eq(matches, 1, "%s deveria ter exatamente um predio de treino" % kind)
