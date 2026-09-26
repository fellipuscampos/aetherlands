extends GutTest

## Cobre RaceTheme.gd -- camada de APRESENTACAO por raca: nome tematico das tropas mundanas que ainda
## podem existir (Guarda inicial e unidades legadas de save antigo) e o kit de estilo visual.
##
## Fase 25: os nomes/descricoes tematicos das techs V1 (Quartel/Estabulo/Arqueiro/Batedor Montado) e
## dos predios de treino V1 sairam junto com eles; so' sobram os nomes de unidade e o kit visual.

const THEMED_UNIT_KINDS := ["warrior", "men_at_arms", "cavalry", "archer", "scout"]
const NON_HUMAN_RACES := ["dwarf", "orc", "elf"]

func test_human_unit_names_match_the_original_unit_database_data():
	for kind in THEMED_UNIT_KINDS:
		assert_eq(RaceTheme.unit_name(kind, "human"), UnitDatabase.create_unit(kind).unit_name)

func test_unknown_race_falls_back_to_the_original_data_same_as_human():
	assert_eq(RaceTheme.unit_name("cavalry", "gnome"), UnitDatabase.create_unit("cavalry").unit_name)
	assert_eq(RaceTheme.style_kit("gnome"), RaceTheme.style_kit("human"))

func test_each_themed_race_has_a_distinct_name_for_every_scoped_unit():
	for race in NON_HUMAN_RACES:
		for kind in THEMED_UNIT_KINDS:
			var themed := RaceTheme.unit_name(kind, race)
			assert_ne(themed, UnitDatabase.create_unit(kind).unit_name, "%s/%s deveria ter nome proprio" % [race, kind])
			assert_ne(themed, "")

## Unidade V2 e predio V2 nunca sao tematizados: a raca e' neutra na progressao V2.
func test_v2_units_and_buildings_are_never_themed():
	for race in NON_HUMAN_RACES:
		assert_eq(RaceTheme.unit_name("v2_unit_shieldbearer", race), UnitDatabase.create_unit("v2_unit_shieldbearer").unit_name)
		assert_eq(RaceTheme.building_name("v2_building_market", race), BuildingDatabase.get_building("v2_building_market").display_name)

func test_style_kit_returns_a_distinct_kit_per_themed_race():
	var seen_scales := {}
	for race in ["human"] + NON_HUMAN_RACES:
		var kit: Dictionary = RaceTheme.style_kit(race)
		assert_true(kit.has("metal_color"))
		assert_true(kit.has("mount_color"))
		assert_true(kit.has("scale"))
		assert_false(seen_scales.values().has(kit.scale), "cada raca deveria ter sua propria escala")
		seen_scales[race] = kit.scale

func test_style_kit_human_matches_the_original_hardcoded_visual_values():
	var kit: Dictionary = RaceTheme.style_kit("human")
	assert_eq(kit.metal_color, Color(0.65, 0.66, 0.68), "aco do Homem de Armas/etc, valor original")
	assert_eq(kit.mount_color, Color(0.5, 0.36, 0.22), "pelagem do Batedor, valor original")
	assert_eq(kit.scale, Vector3(1.0, 1.0, 1.0))
