extends GutTest

## Cobre a arvore de MAGIA (ver MagicDatabase.gd — as 7 escolas magicas,
## separadas estruturalmente da arvore de Tecnologia mundana desde a
## refatoracao que criou este arquivo; ver test_tech.gd pros casos
## mundanos equivalentes/pre-existentes): disponibilidade por pre-
## requisito, desbloqueio de unidade, bonus de rendimento por bioma
## (MagicDatabase.yield_bonus_for aplicado em City.collect_yields),
## feiticos desbloqueados, e o processamento de pesquisa por turno
## (GameManager._process_research — mesmo slot unico compartilhado com a
## arvore de Tecnologia, ver PlayerData.current_research). PlayerData.
## researched_magic guarda SO ids de MagicDatabase; ids de TechDatabase
## vao em researched_techs (ver test_tech.gd).

var _original_human_player: PlayerData

func before_each():
	_original_human_player = GameManager.human_player

func after_each():
	GameManager.human_player = _original_human_player

func test_techs_without_prerequisites_are_available_from_start():
	var ids = MagicDatabase.available_techs({}).map(func(t): return t.id)
	for school in MagicContent.SCHOOLS:
		assert_true(school + "_1" in ids)
	assert_false("invocacao_espiritos" in ids, "invocacao de espiritos exige canalizacao da trama pesquisada antes")
	assert_false("pacto_florestal" in ids, "pacto florestal exige alquimia botanica pesquisada antes")

func test_tech_with_prerequisite_becomes_available_after_researching_it():
	var ids = MagicDatabase.available_techs({"arcanismo_1": true}).map(func(t): return t.id)
	assert_true("arcanismo_2" in ids)

func test_researched_tech_is_not_offered_again():
	var ids = MagicDatabase.available_techs({"canalizacao_base": true}).map(func(t): return t.id)
	assert_false("canalizacao_base" in ids)

func test_tech_that_unlocks_finds_the_matching_tech():
	var tech = MagicDatabase.tech_that_unlocks("mage")
	assert_not_null(tech)
	assert_eq(tech.id, "invocacao_espiritos")

func test_tech_that_unlocks_returns_null_for_empty_kind():
	assert_null(MagicDatabase.tech_that_unlocks(""))

## Roadmap de gameplay Fase 5 — usado por SpellManager pra achar de volta
## o terrain_transform de uma tech so tendo o nome do feitico em maos.
func test_tech_that_unlocks_spell_finds_transcendencia_florestal_for_gaia_metamorphosis():
	var tech = MagicDatabase.tech_that_unlocks_spell("Metamorfose de Gaia")
	assert_not_null(tech)
	assert_eq(tech.id, "transcendencia_florestal")

func test_tech_that_unlocks_spell_returns_null_for_unknown_spell():
	assert_null(MagicDatabase.tech_that_unlocks_spell("Feitiço Que Não Existe"))

func test_tech_that_unlocks_spell_returns_null_for_empty_name():
	assert_null(MagicDatabase.tech_that_unlocks_spell(""))

func test_is_unit_unlocked_mage_requires_invocacao_espiritos():
	assert_false(MagicDatabase.is_unit_unlocked("mage", {}))
	assert_true(MagicDatabase.is_unit_unlocked("mage", {"invocacao_espiritos": true}))

func test_is_unit_unlocked_catapult_requires_constructos_de_guerra():
	assert_false(MagicDatabase.is_unit_unlocked("catapult", {}))
	assert_true(MagicDatabase.is_unit_unlocked("catapult", {"constructos_de_guerra": true}))

func test_constructos_de_guerra_requires_forja_runica_prerequisite():
	assert_false("constructos_de_guerra" in MagicDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("constructos_de_guerra" in MagicDatabase.available_legacy_techs({"forja_runica": true}).map(func(t): return t.id))

func test_is_unit_unlocked_griffin_requires_lordes_dos_ventos():
	assert_false(MagicDatabase.is_unit_unlocked("griffin", {}))
	assert_true(MagicDatabase.is_unit_unlocked("griffin", {"lordes_dos_ventos": true}))

func test_lordes_dos_ventos_requires_invocacao_espiritos_prerequisite():
	assert_false("lordes_dos_ventos" in MagicDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("lordes_dos_ventos" in MagicDatabase.available_legacy_techs({"invocacao_espiritos": true}).map(func(t): return t.id))

func test_is_unit_unlocked_treant_requires_pacto_florestal():
	assert_false(MagicDatabase.is_unit_unlocked("treant", {}))
	assert_true(MagicDatabase.is_unit_unlocked("treant", {"pacto_florestal": true}))

func test_pacto_florestal_requires_alquimia_botanica_prerequisite():
	assert_false("pacto_florestal" in MagicDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("pacto_florestal" in MagicDatabase.available_legacy_techs({"alquimia_botanica": true}).map(func(t): return t.id))

func test_is_unit_unlocked_stone_golem_requires_forja_runica():
	assert_false(MagicDatabase.is_unit_unlocked("stone_golem", {}))
	assert_true(MagicDatabase.is_unit_unlocked("stone_golem", {"forja_runica": true}))

func test_is_unit_unlocked_shadow_summoner_requires_necromancia_pratica():
	assert_false(MagicDatabase.is_unit_unlocked("shadow_summoner", {}))
	assert_true(MagicDatabase.is_unit_unlocked("shadow_summoner", {"necromancia_pratica": true}))

func test_yield_bonus_for_sums_matching_researched_techs():
	var bonus = MagicDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true})
	assert_eq(bonus.food, 1)
	assert_eq(bonus.production, 0)

## Nenhuma tecnologia da arvore atual mira Mana (TechData.bonus_mana, ver
## Ponto 3) ainda — o campo existe so pra manter os 4 tipos de rendimento
## simetricos, pronto pra uma tech futura sem exigir outro passe.
func test_yield_bonus_for_mana_defaults_to_zero_with_no_tech_granting_it():
	var bonus = MagicDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true})
	assert_eq(bonus.mana, 0)

func test_yield_bonus_for_ignores_unrelated_terrain():
	var bonus = MagicDatabase.yield_bonus_for(HexTileData.TerrainType.DESERT, {"alquimia_botanica": true})
	assert_eq(bonus.food, 0, "alquimia botanica afeta floresta/selva/tundra, nao deserto (isso e geomancia)")

## Duas tecnologias diferentes mirando o MESMO bioma (Pacto Florestal +
## Alquimia Botanica, ambas em FOREST) deveriam somar, nao substituir.
func test_yield_bonus_for_stacks_multiple_techs_on_the_same_terrain():
	var bonus = MagicDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true, "pacto_florestal": true})
	assert_eq(bonus.food, 2, "1 (alquimia botanica) + 1 (pacto florestal)")
	assert_eq(bonus.production, 1, "so pacto florestal da producao em floresta")

func test_unlocked_spells_for_returns_only_spells_from_researched_techs():
	var spells = MagicDatabase.unlocked_spells_for({"invocacao_espiritos": true})
	assert_eq(spells, ["Lança de Arcana"])

func test_unlocked_spells_for_ignores_techs_without_a_spell():
	var spells = MagicDatabase.unlocked_spells_for({"alquimia_botanica": true})
	assert_eq(spells, [], "alquimia botanica so da bonus de bioma, nenhum ritual")

func test_unlocked_spells_for_empty_when_nothing_researched():
	assert_eq(MagicDatabase.unlocked_spells_for({}), [])

## PlayerData.has_unlocked tenta TechDatabase primeiro, MagicDatabase
## depois — este teste cobre a metade magica (kind gateado por
## MagicDatabase); ver test_tech.gd pra metade mundana.
func test_player_data_has_unlocked_delegates_to_the_matching_database():
	var player = PlayerData.new(CivilizationData.new())
	assert_false(player.has_unlocked("mage"))
	player.researched_magic["invocacao_espiritos"] = true
	assert_true(player.has_unlocked("mage"))

func test_process_research_accumulates_progress_from_city_population():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 3
	player.current_research = "canalizacao_base" # custo 25

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_almost_eq(player.research_progress, 3.0, 0.01)
	assert_false(player.researched_magic.has("canalizacao_base"))

	hex_grid.queue_free()

## Confirma que uma pesquisa MAGICA concluida cai em researched_magic, NAO
## em researched_techs — o ponto central da separacao estrutural das duas
## arvores dentro de GameManager._process_research.
func test_process_research_completes_a_magic_tech_into_researched_magic():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 30 # bem mais que o custo (25) num turno so
	player.current_research = "canalizacao_base"

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_true(player.researched_magic.has("canalizacao_base"))
	assert_false(player.researched_techs.has("canalizacao_base"), "canalizacao_base e tech de MagicDatabase, nao deveria cair em researched_techs")
	assert_eq(player.current_research, "")
	assert_almost_eq(player.research_progress, 0.0, 0.01)

	hex_grid.queue_free()
