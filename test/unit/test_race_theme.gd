extends GutTest

## Cobre RaceTheme.gd — a camada de APRESENTACAO por raca pro ramo militar
## mundano da arvore de tecnologia (Quartel/Estabulo/Arquearia/Batedor
## Montado + as 4 tropas que elas liberam + os 3 predios de treino
## correspondentes). Pedido do usuario: "essa arvore de tecnologia humana
## que fizemos, eu quero que faca uma equivalente pra cada civilizacao...
## mudando o nome das tropas e aparencia das tropas e edificios em
## questao" (escopo confirmado como so esse ramo, nao a arvore de magia
## inteira).

const THEMED_TECH_IDS := ["quartel", "estabulo", "arqueiro", "batedor_montado"]
const THEMED_UNIT_KINDS := ["warrior", "men_at_arms", "cavalry", "archer", "scout"]
const THEMED_BUILDING_IDS := ["barracks", "stable", "archery_range"]
const NON_HUMAN_RACES := ["dwarf", "orc", "elf"]

## "human" (ou qualquer raca desconhecida) NUNCA deve divergir do dado cru
## que TechDatabase/UnitDatabase/BuildingDatabase ja devolvia ANTES desta
## mudanca — trava de regressao garantindo que o jogador humano nao
## percebe NENHUMA diferenca.
func test_human_tech_names_match_the_original_tech_database_data():
	for id in THEMED_TECH_IDS:
		assert_eq(RaceTheme.tech_name(id, "human"), TechDatabase.get_tech(id).display_name)
		assert_eq(RaceTheme.tech_description(id, "human"), TechDatabase.get_tech(id).description)

func test_human_unit_names_match_the_original_unit_database_data():
	for kind in THEMED_UNIT_KINDS:
		assert_eq(RaceTheme.unit_name(kind, "human"), UnitDatabase.create_unit(kind).unit_name)

func test_human_building_names_match_the_original_building_database_data():
	for id in THEMED_BUILDING_IDS:
		assert_eq(RaceTheme.building_name(id, "human"), BuildingDatabase.get_building(id).display_name)

func test_unknown_race_falls_back_to_the_original_data_same_as_human():
	assert_eq(RaceTheme.tech_name("quartel", "gnome"), TechDatabase.get_tech("quartel").display_name)
	assert_eq(RaceTheme.unit_name("cavalry", "gnome"), UnitDatabase.create_unit("cavalry").unit_name)
	assert_eq(RaceTheme.building_name("stable", "gnome"), BuildingDatabase.get_building("stable").display_name)
	assert_eq(RaceTheme.style_kit("gnome"), RaceTheme.style_kit("human"))

## Cada raca tematizada precisa ter um nome PROPRIO, diferente do humano,
## pros 11 ids escopados — senao o reskin nao aconteceu de verdade.
func test_each_themed_race_has_a_distinct_name_for_every_scoped_tech():
	for race in NON_HUMAN_RACES:
		for id in THEMED_TECH_IDS:
			var themed := RaceTheme.tech_name(id, race)
			assert_ne(themed, TechDatabase.get_tech(id).display_name, "%s/%s deveria ter nome proprio" % [race, id])
			assert_ne(themed, "")

func test_each_themed_race_has_a_distinct_name_for_every_scoped_unit():
	for race in NON_HUMAN_RACES:
		for kind in THEMED_UNIT_KINDS:
			var themed := RaceTheme.unit_name(kind, race)
			assert_ne(themed, UnitDatabase.create_unit(kind).unit_name, "%s/%s deveria ter nome proprio" % [race, kind])
			assert_ne(themed, "")

func test_each_themed_race_has_a_distinct_name_for_every_scoped_building():
	for race in NON_HUMAN_RACES:
		for id in THEMED_BUILDING_IDS:
			var themed := RaceTheme.building_name(id, race)
			assert_ne(themed, BuildingDatabase.get_building(id).display_name, "%s/%s deveria ter nome proprio" % [race, id])
			assert_ne(themed, "")

## Cada raca tematizada tambem precisa de uma descricao propria (nao so
## reusar a lore humana) pras 4 techs do ramo militar.
func test_each_themed_race_has_a_distinct_description_for_every_scoped_tech():
	for race in NON_HUMAN_RACES:
		for id in THEMED_TECH_IDS:
			var themed := RaceTheme.tech_description(id, race)
			assert_ne(themed, TechDatabase.get_tech(id).description, "%s/%s deveria ter descricao propria" % [race, id])
			assert_ne(themed, "")

## Tech/predio da MESMA "estacao" compartilham o nome tematico SO pros
## slots onde o dado ORIGINAL humano ja fazia isso (tech "Quartel" ==
## predio "Quartel", tech "Estábulo" == predio "Estabulo") — mantido de
## proposito nas tabelas novas do RaceTheme pras 3 racas tematizadas.
## "arqueiro"/"archery_range" fica de fora aqui porque ja NAO combinam
## (tech "Arqueiro" vs predio "Campo de Tiro" — nomes sem nenhuma relacao
## entre si, desde a separacao predio/unidade da arvore de 10 niveis),
## entao os nomes tematicos tambem foram escritos como duas coisas
## distintas pra cada raca (ver _TECH_NAMES/_BUILDING_NAMES em
## RaceTheme.gd), no mesmo espirito do original.
func test_tech_and_building_names_match_for_the_same_slot():
	var tech_to_building := {
		"quartel": "barracks",
		"estabulo": "stable",
	}
	for race in NON_HUMAN_RACES:
		for tech_id in tech_to_building:
			var building_id: String = tech_to_building[tech_id]
			assert_eq(RaceTheme.tech_name(tech_id, race), RaceTheme.building_name(building_id, race))

## Um id fora do escopo militar (tech de magia, unidade nao ligada ao ramo
## mundano, predio de rendimento) devolve o nome cru original nao importa
## a raca — confirma o fallback universal (RaceTheme so tem entrada pros
## 11 ids escopados).
func test_ids_outside_the_military_branch_are_never_themed():
	for race in NON_HUMAN_RACES:
		assert_eq(RaceTheme.tech_name("canalizacao_base", race), MagicDatabase.get_tech("canalizacao_base").display_name)
		assert_eq(RaceTheme.unit_name("mage", race), UnitDatabase.create_unit("mage").unit_name)
		assert_eq(RaceTheme.building_name("granary", race), BuildingDatabase.get_building("granary").display_name)

## style_kit() sempre devolve um Dictionary utilizavel (nunca null), com um
## kit DISTINTO por raca tematizada e fallback pro kit "human" pra raca
## desconhecida.
func test_style_kit_returns_a_distinct_kit_per_themed_race():
	var seen_scales := {}
	for race in ["human"] + NON_HUMAN_RACES:
		var kit: Dictionary = RaceTheme.style_kit(race)
		assert_true(kit.has("metal_color"))
		assert_true(kit.has("mount_color"))
		assert_true(kit.has("barracks_color"))
		assert_true(kit.has("stable_color"))
		assert_true(kit.has("archery_range_color"))
		assert_true(kit.has("scale"))
		assert_false(seen_scales.values().has(kit.scale), "cada raca deveria ter sua propria escala")
		seen_scales[race] = kit.scale

func test_style_kit_human_matches_the_original_hardcoded_visual_values():
	var kit: Dictionary = RaceTheme.style_kit("human")
	assert_eq(kit.metal_color, Color(0.65, 0.66, 0.68), "aco do Homem de Armas/etc, valor original")
	assert_eq(kit.mount_color, Color(0.5, 0.36, 0.22), "pelagem do Batedor, valor original")
	assert_eq(kit.barracks_color, Color(0.42, 0.4, 0.38), "pedra do Quartel, valor original")
	assert_eq(kit.stable_color, Color(0.55, 0.42, 0.28), "madeira do Estabulo, valor original")
	assert_eq(kit.archery_range_color, Color(0.4, 0.28, 0.18), "poste do Campo de Tiro, valor original")
	assert_eq(kit.scale, Vector3(1.0, 1.0, 1.0))
