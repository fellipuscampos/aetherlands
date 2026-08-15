extends GutTest

## Cobre UnitDatabase.PLAYER_TRAINABLE_KINDS (roster que a HUD usa pra
## montar os botoes de producao dinamicamente, ver HUD._build_production_
## buttons) e os dados das duas tropas magicas mais novas (Golem de Pedra/
## Convocador de Sombras, desbloqueadas por forja_runica/necromancia_
## pratica em TechDatabase).

func test_player_trainable_kinds_includes_every_magic_troop():
	assert_true("stone_golem" in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	assert_true("shadow_summoner" in UnitDatabase.PLAYER_TRAINABLE_KINDS)

## Tropa racial exclusiva de civilizacao de fantasia (ver RACE_UNIQUE_KIND)
## — desde que o jogador ganhou raca propria escolhivel na tela de titulo
## (CivilizationData.race), as 4 aparecem no roster que a HUD usa pra
## montar botoes; City.can_train()/HUD._on_tile_selected e que decidem se
## cada uma fica visivel/treinavel pra UM jogador especifico (so a raca
## dona).
func test_player_trainable_kinds_includes_every_racial_exclusive_troop():
	assert_true("human_knight" in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	assert_true("dwarf_axeguard" in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	assert_true("orc_berserker" in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	assert_true("elf_ranger" in UnitDatabase.PLAYER_TRAINABLE_KINDS)

func test_race_for_unique_kind_matches_race_unique_kind_mapping():
	assert_eq(UnitDatabase.race_for_unique_kind("human_knight"), "human")
	assert_eq(UnitDatabase.race_for_unique_kind("dwarf_axeguard"), "dwarf")
	assert_eq(UnitDatabase.race_for_unique_kind("orc_berserker"), "orc")
	assert_eq(UnitDatabase.race_for_unique_kind("elf_ranger"), "elf")
	assert_eq(UnitDatabase.race_for_unique_kind("warrior"), "", "warrior nao e tropa racial de ninguem")

func test_player_trainable_kinds_has_no_duplicates():
	var seen := []
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		assert_false(kind in seen, "%s apareceu duplicado no roster" % kind)
		seen.append(kind)

func test_create_unit_stone_golem_has_the_highest_defense_in_the_roster():
	var golem = UnitDatabase.create_unit("stone_golem")
	assert_eq(golem.unit_name, "Golem de Pedra")
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var other = UnitDatabase.create_unit(kind)
		assert_true(golem.defense >= other.defense, "Golem deveria ter a maior (ou igual) defesa do elenco, %s tem %s" % [kind, other.defense])

func test_create_unit_shadow_summoner_is_a_ranged_caster():
	var summoner = UnitDatabase.create_unit("shadow_summoner")
	assert_eq(summoner.unit_name, "Convocador de Sombras")
	assert_eq(summoner.attack_range, 2)
	assert_true(summoner.ignores_terrain_defense, "conjurador deveria ignorar fortificacao, mesmo padrao do Mago")

func test_create_unit_human_knight_exists_and_is_melee():
	var knight = UnitDatabase.create_unit("human_knight")
	assert_eq(knight.unit_name, "Cavaleiro Real")
	assert_eq(knight.attack_range, 1, "Cavaleiro Real e corpo-a-corpo (1 = sem alcance a distancia)")
	assert_false(knight.can_found_city)
