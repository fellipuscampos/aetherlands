extends GutTest

## Cobre a arvore de tecnologia MAGICA (ver TechDatabase.gd — pivot pedido
## pelo usuario, substitui a arvore generica/historica anterior):
## disponibilidade por pre-requisito, desbloqueio de unidade, bonus de
## rendimento por bioma (TechDatabase.yield_bonus_for aplicado em
## City.collect_yields), e o processamento de pesquisa por turno
## (GameManager._process_research — ciencia = populacao das cidades, so
## acumula com uma pesquisa escolhida).

var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players

func after_each():
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players

func test_techs_without_prerequisites_are_available_from_start():
	var ids = TechDatabase.available_techs({}).map(func(t): return t.id)
	assert_true("canalizacao_base" in ids)
	assert_true("alquimia_botanica" in ids)
	assert_true("transmutacao_rocha" in ids)
	assert_false("invocacao_espiritos" in ids, "invocacao de espiritos exige canalizacao da trama pesquisada antes")
	assert_false("pacto_florestal" in ids, "pacto florestal exige alquimia botanica pesquisada antes")

func test_tech_with_prerequisite_becomes_available_after_researching_it():
	var ids = TechDatabase.available_techs({"canalizacao_base": true}).map(func(t): return t.id)
	assert_true("invocacao_espiritos" in ids)

func test_researched_tech_is_not_offered_again():
	var ids = TechDatabase.available_techs({"canalizacao_base": true}).map(func(t): return t.id)
	assert_false("canalizacao_base" in ids)

func test_is_unit_unlocked_settler_and_warrior_always_true():
	assert_true(TechDatabase.is_unit_unlocked("settler", {}))
	assert_true(TechDatabase.is_unit_unlocked("warrior", {}))

## Nenhuma tecnologia da nova arvore magica mira Arqueiro/Cavaleiro —
## viraram tropas mundanas sempre disponiveis (mesmo status de Guerreiro),
## so as tropas MAGICAS (Mago, Grifo, Golem, Convocador de Sombras,
## Catapulta Cadenciada, Ent) exigem pesquisa agora. is_unit_unlocked() e
## fail-open pra kind sem tech associada (ver comentario na propria
## funcao), entao isso vale sem nenhuma mudanca de codigo.
func test_archer_and_cavalry_are_always_unlocked_mundane_troops():
	assert_true(TechDatabase.is_unit_unlocked("archer", {}))
	assert_true(TechDatabase.is_unit_unlocked("cavalry", {}))

func test_tech_that_unlocks_finds_the_matching_tech():
	var tech = TechDatabase.tech_that_unlocks("mage")
	assert_not_null(tech)
	assert_eq(tech.id, "invocacao_espiritos")

func test_tech_that_unlocks_returns_null_for_kind_without_a_tech():
	assert_null(TechDatabase.tech_that_unlocks("warrior"), "Guerreiro sempre foi liberado sem pesquisa nenhuma")

## Regressao: TechData.unlocks_unit tambem default pra "" nas tecnologias
## de bioma (Alquimia Botanica, Geomancia...) que nao desbloqueiam unidade
## nenhuma — sem a guarda explicita, tech_that_unlocks("") "encontraria"
## a primeira dessas por acidente em vez de devolver null.
func test_tech_that_unlocks_returns_null_for_empty_kind():
	assert_null(TechDatabase.tech_that_unlocks(""), "predio de rendimento (trains_unit vazio) nao deveria exigir tecnologia nenhuma")

func test_is_unit_unlocked_mage_requires_invocacao_espiritos():
	assert_false(TechDatabase.is_unit_unlocked("mage", {}))
	assert_true(TechDatabase.is_unit_unlocked("mage", {"invocacao_espiritos": true}))

func test_is_unit_unlocked_catapult_requires_constructos_de_guerra():
	assert_false(TechDatabase.is_unit_unlocked("catapult", {}))
	assert_true(TechDatabase.is_unit_unlocked("catapult", {"constructos_de_guerra": true}))

func test_constructos_de_guerra_requires_forja_runica_prerequisite():
	assert_false("constructos_de_guerra" in TechDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("constructos_de_guerra" in TechDatabase.available_techs({"forja_runica": true}).map(func(t): return t.id))

func test_is_unit_unlocked_griffin_requires_lordes_dos_ventos():
	assert_false(TechDatabase.is_unit_unlocked("griffin", {}))
	assert_true(TechDatabase.is_unit_unlocked("griffin", {"lordes_dos_ventos": true}))

func test_lordes_dos_ventos_requires_invocacao_espiritos_prerequisite():
	assert_false("lordes_dos_ventos" in TechDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("lordes_dos_ventos" in TechDatabase.available_techs({"invocacao_espiritos": true}).map(func(t): return t.id))

func test_is_unit_unlocked_treant_requires_pacto_florestal():
	assert_false(TechDatabase.is_unit_unlocked("treant", {}))
	assert_true(TechDatabase.is_unit_unlocked("treant", {"pacto_florestal": true}))

func test_pacto_florestal_requires_alquimia_botanica_prerequisite():
	assert_false("pacto_florestal" in TechDatabase.available_techs({}).map(func(t): return t.id))
	assert_true("pacto_florestal" in TechDatabase.available_techs({"alquimia_botanica": true}).map(func(t): return t.id))

func test_is_unit_unlocked_stone_golem_requires_forja_runica():
	assert_false(TechDatabase.is_unit_unlocked("stone_golem", {}))
	assert_true(TechDatabase.is_unit_unlocked("stone_golem", {"forja_runica": true}))

func test_is_unit_unlocked_shadow_summoner_requires_necromancia_pratica():
	assert_false(TechDatabase.is_unit_unlocked("shadow_summoner", {}))
	assert_true(TechDatabase.is_unit_unlocked("shadow_summoner", {"necromancia_pratica": true}))

func test_yield_bonus_for_sums_matching_researched_techs():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true})
	assert_eq(bonus.food, 1)
	assert_eq(bonus.production, 0)

## Nenhuma tecnologia da arvore atual mira Mana (TechData.bonus_mana, ver
## Ponto 3) ainda — o campo existe so pra manter os 4 tipos de rendimento
## simetricos, pronto pra uma tech futura sem exigir outro passe.
func test_yield_bonus_for_mana_defaults_to_zero_with_no_tech_granting_it():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true})
	assert_eq(bonus.mana, 0)

func test_yield_bonus_for_ignores_unrelated_terrain():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.DESERT, {"alquimia_botanica": true})
	assert_eq(bonus.food, 0, "alquimia botanica afeta floresta/selva/tundra, nao deserto (isso e geomancia)")

## Duas tecnologias diferentes mirando o MESMO bioma (Pacto Florestal +
## Alquimia Botanica, ambas em FOREST) deveriam somar, nao substituir.
func test_yield_bonus_for_stacks_multiple_techs_on_the_same_terrain():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"alquimia_botanica": true, "pacto_florestal": true})
	assert_eq(bonus.food, 2, "1 (alquimia botanica) + 1 (pacto florestal)")
	assert_eq(bonus.production, 1, "so pacto florestal da producao em floresta")

func test_unlocked_spells_for_returns_only_spells_from_researched_techs():
	var spells = TechDatabase.unlocked_spells_for({"invocacao_espiritos": true})
	assert_eq(spells, ["Lança de Arcana"])

func test_unlocked_spells_for_ignores_techs_without_a_spell():
	var spells = TechDatabase.unlocked_spells_for({"alquimia_botanica": true})
	assert_eq(spells, [], "alquimia botanica so da bonus de bioma, nenhum ritual")

func test_unlocked_spells_for_empty_when_nothing_researched():
	assert_eq(TechDatabase.unlocked_spells_for({}), [])

func test_player_data_has_unlocked_delegates_to_tech_database():
	var player = PlayerData.new(CivilizationData.new())
	assert_false(player.has_unlocked("mage"))
	player.researched_techs["invocacao_espiritos"] = true
	assert_true(player.has_unlocked("mage"))

func test_city_collect_yields_applies_tech_bonus():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao base 2

	var player := PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.owner_player = player
	city.coord = coord

	assert_eq(city.collect_yields(hex_grid).production, 2)

	player.researched_techs["transmutacao_rocha"] = true # +1 producao em colinas/montanhas
	assert_eq(city.collect_yields(hex_grid).production, 3)

	hex_grid.queue_free()
	city.queue_free()

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
	assert_false(player.researched_techs.has("canalizacao_base"))

	hex_grid.queue_free()

func test_process_research_completes_tech_when_cost_is_reached():
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

	assert_true(player.researched_techs.has("canalizacao_base"))
	assert_eq(player.current_research, "")
	assert_almost_eq(player.research_progress, 0.0, 0.01)

	hex_grid.queue_free()

func test_process_research_does_nothing_without_a_selected_tech():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 5

	GameManager._process_research(player)

	assert_almost_eq(player.research_progress, 0.0, 0.01, "sem pesquisa selecionada, ciencia gerada e descartada")

	hex_grid.queue_free()

func test_decide_research_picks_an_available_tech_when_idle():
	var player := PlayerData.new(CivilizationData.new())
	RivalAI.decide_research(player)
	assert_ne(player.current_research, "", "IA deveria escolher alguma pesquisa quando esta ociosa")

func test_decide_research_does_not_override_existing_choice():
	var player := PlayerData.new(CivilizationData.new())
	player.current_research = "transmutacao_rocha"
	RivalAI.decide_research(player)
	assert_eq(player.current_research, "transmutacao_rocha")

## Regressao: antes da arvore de tecnologia, a IA sorteava Arqueiro/
## Cavaleiro desde o primeiro turno. Na arvore magica atual, Arqueiro e
## Cavaleiro viraram tropas mundanas sempre liberadas (ver
## test_archer_and_cavalry_are_always_unlocked_mundane_troops) — entao sem
## NENHUMA tecnologia magica pesquisada, so as 3 tropas mundanas
## (Guerreiro/Arqueiro/Cavaleiro) deveriam sair do sorteio, nunca uma
## tropa magica (Catapulta/Mago/Grifo/Ent).
func test_decide_production_never_picks_locked_units_before_researching():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_a = hex_grid.found_city(Vector2i(0, 0), player, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), player, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"

	var mundane_kinds := ["warrior", "archer", "cavalry"]
	for i in range(20): # varias rodadas pra reduzir chance de falso-positivo por sorte
		RivalAI.decide_production(player)
		assert_true(city_a.production_item in mundane_kinds, "sem nenhuma tecnologia magica pesquisada, so tropas mundanas deveriam sair do sorteio")

	hex_grid.queue_free()
