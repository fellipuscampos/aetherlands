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
	assert_true("quartel" in ids, "quartel e tier 0, sem pre-requisito")
	assert_true("muralhas" in ids, "muralhas e tier 0, sem pre-requisito — irma solta de quartel, nao filha dele")
	assert_false("invocacao_espiritos" in ids, "invocacao de espiritos exige canalizacao da trama pesquisada antes")
	assert_false("pacto_florestal" in ids, "pacto florestal exige alquimia botanica pesquisada antes")
	assert_false("batedor_montado" in ids, "batedor montado exige estabulo pesquisada antes")
	assert_false("estabulo" in ids, "correcao do usuario: estabulo exige quartel pesquisada antes, nao e mais tier 0")
	assert_false("arquearia" in ids, "correcao do usuario: arquearia TAMBEM exige quartel pesquisada antes, nao e mais tier 0")

func test_tech_with_prerequisite_becomes_available_after_researching_it():
	var ids = TechDatabase.available_techs({"canalizacao_base": true}).map(func(t): return t.id)
	assert_true("invocacao_espiritos" in ids)

## Diagrama exato do pedido do usuario: "quartel -> estabulo -> batedor
## montado, \/ arquearia... o quartel libera a pesquisa de estabulo e
## arquearia" — Quartel e raiz das DUAS, nao so de Estabulo.
func test_quartel_unlocks_both_estabulo_and_arquearia():
	var ids = TechDatabase.available_techs({"quartel": true}).map(func(t): return t.id)
	assert_true("estabulo" in ids, "quartel deveria liberar a pesquisa de estabulo")
	assert_true("arquearia" in ids, "quartel deveria liberar a pesquisa de arquearia")

func test_batedor_montado_becomes_available_after_researching_estabulo():
	var ids = TechDatabase.available_techs({"estabulo": true}).map(func(t): return t.id)
	assert_true("batedor_montado" in ids)

func test_researched_tech_is_not_offered_again():
	var ids = TechDatabase.available_techs({"canalizacao_base": true}).map(func(t): return t.id)
	assert_false("canalizacao_base" in ids)

func test_is_unit_unlocked_settler_and_warrior_always_true():
	assert_true(TechDatabase.is_unit_unlocked("settler", {}))
	assert_true(TechDatabase.is_unit_unlocked("warrior", {}))

## Arqueiro passou a exigir pesquisa de verdade — pedido do usuario:
## "introduza a pesquisa em arqueria... nela voce libera a construcao que
## atualmente temos pra treinar arqueiros". "Arquearia" tem unlocks_unit
## == "archer", entao cai no loop normal de is_unit_unlocked e fica
## bloqueado ate pesquisar (deixou de ser fail-open).
func test_archer_requires_researching_arquearia():
	assert_false(TechDatabase.is_unit_unlocked("archer", {}))
	assert_true(TechDatabase.is_unit_unlocked("archer", {"arquearia": true}))

## Cavaleiro (comum) passou a exigir pesquisa de verdade — pedido do
## usuario: "voce precisa pesquisar[,] o estabulo [pra poder] construir".
## Diferente do Guarda (que preserva um hardcode antigo em
## is_unit_unlocked so pra "warrior"), Cavaleiro nao tem excecao nenhuma:
## "Estabulo" tem unlocks_unit == "cavalry", entao cai no loop normal da
## funcao e fica bloqueado ate pesquisar.
func test_cavalry_requires_researching_estabulo():
	assert_false(TechDatabase.is_unit_unlocked("cavalry", {}))
	assert_true(TechDatabase.is_unit_unlocked("cavalry", {"estabulo": true}))

## Batedor exige a PROPRIA tech ("Batedor Montado"), nao so "Estabulo" —
## pedido do usuario: "uma pesquisa seguinte ao estabulo... o batedor
## montado, que libera a construcao do batedor". Ter so "estabulo"
## pesquisada NAO basta.
func test_scout_requires_researching_batedor_montado_specifically():
	assert_false(TechDatabase.is_unit_unlocked("scout", {}))
	assert_false(TechDatabase.is_unit_unlocked("scout", {"estabulo": true}), "so a tech Estabulo nao deveria liberar o Batedor")
	assert_true(TechDatabase.is_unit_unlocked("scout", {"estabulo": true, "batedor_montado": true}))

func test_tech_that_unlocks_finds_estabulo_for_cavalry():
	var tech = TechDatabase.tech_that_unlocks("cavalry")
	assert_not_null(tech)
	assert_eq(tech.id, "estabulo")

func test_tech_that_unlocks_finds_arquearia_for_archer():
	var tech = TechDatabase.tech_that_unlocks("archer")
	assert_not_null(tech)
	assert_eq(tech.id, "arquearia")

func test_tech_that_unlocks_finds_batedor_montado_for_scout():
	var tech = TechDatabase.tech_that_unlocks("scout")
	assert_not_null(tech)
	assert_eq(tech.id, "batedor_montado")

func test_tech_that_unlocks_finds_the_matching_tech():
	var tech = TechDatabase.tech_that_unlocks("mage")
	assert_not_null(tech)
	assert_eq(tech.id, "invocacao_espiritos")

## men_at_arms (Homem de Armas) tem a tecnologia associada ("Quartel"), NAO
## warrior (Guarda) — pedido do usuario numa rodada seguinte: "o guarda
## comum nao precisa de quartel pra ser feito", que moveu
## BuildingDatabase.barracks.trains_unit de "warrior" pra "men_at_arms" (e
## quartel.unlocks_unit junto, pros dois continuarem batendo).
func test_tech_that_unlocks_finds_quartel_for_men_at_arms():
	var tech = TechDatabase.tech_that_unlocks("men_at_arms")
	assert_not_null(tech)
	assert_eq(tech.id, "quartel")

func test_tech_that_unlocks_returns_null_for_warrior():
	assert_null(TechDatabase.tech_that_unlocks("warrior"), "Guarda nao depende de tecnologia nenhuma")

## Regressao: TechData.unlocks_unit tambem default pra "" nas tecnologias
## de bioma (Alquimia Botanica, Geomancia...) que nao desbloqueiam unidade
## nenhuma — sem a guarda explicita, tech_that_unlocks("") "encontraria"
## a primeira dessas por acidente em vez de devolver null.
func test_tech_that_unlocks_returns_null_for_empty_kind():
	assert_null(TechDatabase.tech_that_unlocks(""), "predio de rendimento (trains_unit vazio) nao deveria exigir tecnologia nenhuma")

## Mesma ideia de tech_that_unlocks, so que pra predios SEM trains_unit
## (TechData.unlocks_building, nao unlocks_unit) — Muralhas e o unico caso
## hoje: "a muralha nao faz tanto sentido... vamos remover ela, e
## adicionar como pesquisa".
func test_tech_that_unlocks_building_finds_muralhas_for_walls():
	var tech = TechDatabase.tech_that_unlocks_building("walls")
	assert_not_null(tech)
	assert_eq(tech.id, "muralhas")

func test_tech_that_unlocks_building_finds_celeiro_for_granary():
	var tech = TechDatabase.tech_that_unlocks_building("granary")
	assert_not_null(tech)
	assert_eq(tech.id, "celeiro")

func test_tech_that_unlocks_building_finds_oficina_for_workshop():
	var tech = TechDatabase.tech_that_unlocks_building("workshop")
	assert_not_null(tech)
	assert_eq(tech.id, "oficina")

func test_tech_that_unlocks_building_finds_mercado_for_market():
	var tech = TechDatabase.tech_that_unlocks_building("market")
	assert_not_null(tech)
	assert_eq(tech.id, "mercado")

func test_tech_that_unlocks_building_returns_null_for_a_building_without_its_own_tech():
	assert_null(TechDatabase.tech_that_unlocks_building("sages_tower"), "Torre dos Sabios nao tem tecnologia propria nenhuma")

func test_tech_that_unlocks_building_returns_null_for_empty_id():
	assert_null(TechDatabase.tech_that_unlocks_building(""))

## Roadmap de gameplay Fase 5 — usado por SpellManager pra achar de volta
## o terrain_transform de uma tech so tendo o nome do feitico em maos.
func test_tech_that_unlocks_spell_finds_transcendencia_florestal_for_gaia_metamorphosis():
	var tech = TechDatabase.tech_that_unlocks_spell("Metamorfose de Gaia")
	assert_not_null(tech)
	assert_eq(tech.id, "transcendencia_florestal")

func test_tech_that_unlocks_spell_returns_null_for_unknown_spell():
	assert_null(TechDatabase.tech_that_unlocks_spell("Feitiço Que Não Existe"))

func test_tech_that_unlocks_spell_returns_null_for_empty_name():
	assert_null(TechDatabase.tech_that_unlocks_spell(""))

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

## Roadmap de gameplay Fase 4A — achado do harness de simulacao (Fase 0):
## sorteio uniforme entre TODAS as disponiveis fazia Mercado (cadeia de 3
## pesquisas em sequencia) nunca ser alcancado nem em 200 turnos. Fix:
## tech cujo pre-requisito ja foi cumprido ganha prioridade sobre tech de
## raiz sem pre-requisito (sempre disponivel, nunca urgente).
func test_decide_research_prioritizes_continuing_an_already_started_chain():
	var player := PlayerData.new(CivilizationData.new())
	player.researched_techs["celeiro"] = true # abre "oficina" (prerequisites = ["celeiro"])

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "com Celeiro pronto, deveria priorizar Oficina sobre qualquer tech de raiz sem pre-requisito")

## Roadmap "Parte B" B3 — prova que identidade e SO uma preferencia, nunca
## um bloqueio nem uma prioridade mais forte que a estrutura da arvore:
## mesmo com a civ tendo forca MAXIMA (1.0) no eixo militar (bate perfeito
## com "quartel", tech de raiz), a IA ainda prioriza "oficina" (continuacao
## de cadeia, eixo industrial, identidade ZERO) — RESEARCH_WEIGHT_
## CONTINUATION (1.0) > RESEARCH_WEIGHT_IDENTITY (0.2) mesmo no auge da
## identidade garante isso por construcao.
func test_decide_research_identity_never_overrides_stronger_continuation():
	var player := PlayerData.new(CivilizationData.new())
	player.researched_techs["celeiro"] = true # abre "oficina" (industrial), unica continuacao disponivel

	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true # eixo militar em 1.0 -- identidade perfeita, mas pra OUTRA tech (quartel)
	player.cities.append(city)

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "continuacao de cadeia deve vencer mesmo com identidade militar em 1.0 batendo perfeito noutra tech de raiz")
	city.queue_free()

## Roadmap "Parte B" B3 — prova de monotonicidade: aumentar a forca do
## eixo militar da civ so pode AUMENTAR a pontuacao de uma tech militar
## (quartel), nunca diminuir nem travar nada. A segunda metade prova
## "nunca inalcancavel": mesmo no auge da identidade militar, uma tech de
## outro eixo (celeiro/agricola) continua no pool disponivel normalmente.
func test_decide_research_score_increases_monotonically_with_matching_identity_and_never_excludes_others():
	var player := PlayerData.new(CivilizationData.new())
	var quartel: TechData = TechDatabase.get_tech("quartel") # unlocks_unit "men_at_arms" -> barracks -> eixo militar

	var score_with_no_identity := RivalAI._score_research_candidate(quartel, player)

	var city := City.new()
	city.buildings["barracks"] = true # militar 1/5 = 0.2
	player.cities.append(city)
	var score_with_partial_identity := RivalAI._score_research_candidate(quartel, player)

	for id in ["walls", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true # militar 5/5 = 1.0
	var score_with_full_identity := RivalAI._score_research_candidate(quartel, player)

	assert_lt(score_with_no_identity, score_with_partial_identity, "identidade militar parcial deve aumentar a pontuacao de uma tech militar")
	assert_lt(score_with_partial_identity, score_with_full_identity, "identidade militar mais forte ainda -> pontuacao ainda maior, sempre crescente")

	var available_ids := []
	for t in TechDatabase.available_techs(player.researched_techs):
		available_ids.append(t.id)
	assert_true("celeiro" in available_ids, "tech de outro eixo (agricola) continua disponivel mesmo com identidade militar no maximo -- preferencia nunca remove opcoes")

	city.queue_free()

## Regressao: antes da arvore de tecnologia, a IA sorteava Arqueiro/
## Cavaleiro desde o primeiro turno. Desde a Fase 1 do roadmap de gameplay
## (RivalAI.decide_production pontuado, respeitando City.can_build/
## can_train de verdade — antes pulava os dois gates), uma tropa travada
## por TECH nunca vira sequer candidata na pontuacao (player.has_unlocked
## continua fazendo esse corte em _production_candidates), entao nem
## precisa aparecer sorteada por acaso pra este teste continuar valendo —
## so confirma que a lista final de candidatos nunca inclui as travadas.
## Sem pesquisa nenhuma, so "warrior" (sem tech propria — ver comentario
## de is_unit_unlocked) e predios sem gate de tech (ex: Torre dos Sabios)
## chegam a ser candidatos.
func test_decide_production_never_picks_locked_units_before_researching():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_a = hex_grid.found_city(Vector2i(0, 0), player, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), player, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"

	var locked_kinds := ["archer", "cavalry", "catapult", "mage", "griffin", "treant"]
	var opponent := PlayerData.new(CivilizationData.new())
	for i in range(20): # varias rodadas pra reduzir chance de falso-positivo por sorte
		RivalAI.decide_production(player, hex_grid, opponent)
		assert_false(city_a.production_item in locked_kinds, "sem nenhuma tecnologia pesquisada, tropa travada por tech nao deveria sair da pontuacao")

	hex_grid.queue_free()
