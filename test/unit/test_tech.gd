extends GutTest

## Cobre a arvore de TECNOLOGIA MUNDANA (ver TechDatabase.gd — redesenho de
## 10 niveis com portao "2 de N", ver test_magic.gd pra arvore de Magia,
## que continua no modelo antigo de pre-requisito em cadeia): a regra de
## progressao por NIVEL (TechDatabase.available_techs/is_tier_unlocked),
## desbloqueio de unidade/predio, e o processamento de pesquisa por turno
## (GameManager._process_research — ciencia = populacao das cidades, so
## acumula com uma pesquisa escolhida). PlayerData.researched_techs guarda
## SO ids de TechDatabase; ids de MagicDatabase vao em researched_magic.

var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players

func after_each():
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players

## --- Portao "2 de N" (regra de progressao por nivel) -----------------------

func test_tier_1_techs_are_all_available_from_the_start():
	var ids = TechDatabase.available_techs({}).map(func(t): return t.id)
	for id in ["quartel", "celeiro", "guarda", "batedor"]:
		assert_true(id in ids, "%s e Nivel 1, deveria estar sempre disponivel" % id)

func test_tier_2_is_locked_with_zero_or_one_tier_1_researched():
	var ids0 = TechDatabase.available_techs({}).map(func(t): return t.id)
	assert_false("oficina" in ids0, "Nivel 2 nao deveria abrir sem nenhuma tech do Nivel 1")

	var ids1 = TechDatabase.available_techs({"quartel": true}).map(func(t): return t.id)
	assert_false("oficina" in ids1, "1 tech do Nivel 1 nao basta, precisa de 2")

func test_tier_2_unlocks_after_any_two_tier_1_technologies():
	var ids = TechDatabase.available_techs({"quartel": true, "celeiro": true}).map(func(t): return t.id)
	for id in ["campo_de_tiro", "oficina", "arqueiro", "homem_de_armas"]:
		assert_true(id in ids, "%s e Nivel 2, deveria abrir com 2 techs quaisquer do Nivel 1" % id)

## Nao importa QUAIS 2 — qualquer combinacao de 2 techs do Nivel 1 libera o
## Nivel 2 inteiro (pedido do usuario: "nao sao cumulativas... voce escolhe
## seu proprio caminho").
func test_tier_2_unlocks_with_a_different_pair_of_tier_1_technologies():
	var ids = TechDatabase.available_techs({"guarda": true, "batedor": true}).map(func(t): return t.id)
	assert_true("oficina" in ids, "guarda+batedor tambem sao 2 techs do Nivel 1, deveriam abrir o Nivel 2")

## Desbloquear o nivel seguinte NAO torna o anterior obsoleto — pedido
## explicito do usuario, corrigido na revisao do plano.
func test_tier_1_techs_remain_available_after_tier_2_unlocks():
	var ids = TechDatabase.available_techs({"quartel": true, "celeiro": true}).map(func(t): return t.id)
	assert_true("guarda" in ids, "tech de Nivel 1 ainda nao pesquisada deveria continuar disponivel")
	assert_true("batedor" in ids, "tech de Nivel 1 ainda nao pesquisada deveria continuar disponivel")

func test_tier_3_needs_two_tier_2_technologies_researched():
	var researched := {"quartel": true, "celeiro": true, "oficina": true} # so 1 do Nivel 2
	assert_false(TechDatabase.is_tier_unlocked(3, researched))
	researched["arqueiro"] = true # 2 do Nivel 2 agora
	assert_true(TechDatabase.is_tier_unlocked(3, researched))

func test_is_tier_unlocked_matches_available_techs():
	assert_true(TechDatabase.is_tier_unlocked(1, {}), "Nivel 1 sempre liberado")
	assert_false(TechDatabase.is_tier_unlocked(2, {}))
	assert_false(TechDatabase.is_tier_unlocked(2, {"quartel": true}), "1 tech nao basta")
	assert_true(TechDatabase.is_tier_unlocked(2, {"quartel": true, "celeiro": true}))

func test_researched_tech_is_not_offered_again():
	var ids = TechDatabase.available_techs({"celeiro": true}).map(func(t): return t.id)
	assert_false("celeiro" in ids)

func test_is_unit_unlocked_settler_and_warrior_always_true():
	assert_true(TechDatabase.is_unit_unlocked("settler", {}))
	# is_unit_unlocked (metodo de baixo nivel) so tem o hardcode "settler" —
	# "warrior" passa pelo loop normal desde a arvore de 10 niveis (ver
	# tech "guarda" abaixo), entao SEM a tech fica false aqui.
	assert_false(TechDatabase.is_unit_unlocked("warrior", {}))
	assert_true(TechDatabase.is_unit_unlocked("warrior", {"guarda": true}))

## Guarda e Batedor deixaram de ser sempre-liberados (fail-open hardcoded
## de antes) — viraram escolhas de Nivel 1 de verdade, pedido do usuario no
## desenho novo.
func test_warrior_requires_researching_guarda():
	assert_false(TechDatabase.is_unit_unlocked("warrior", {}))
	assert_true(TechDatabase.is_unit_unlocked("warrior", {"guarda": true}))

func test_scout_requires_researching_batedor():
	assert_false(TechDatabase.is_unit_unlocked("scout", {}))
	assert_true(TechDatabase.is_unit_unlocked("scout", {"batedor": true}))

func test_archer_requires_researching_arqueiro():
	assert_false(TechDatabase.is_unit_unlocked("archer", {}))
	assert_true(TechDatabase.is_unit_unlocked("archer", {"arqueiro": true}))

func test_cavalry_requires_researching_cavaleiro():
	assert_false(TechDatabase.is_unit_unlocked("cavalry", {}))
	assert_true(TechDatabase.is_unit_unlocked("cavalry", {"cavaleiro": true}))

## "batedor_montado" (unidade NOVA e distinta de "scout") exige a PROPRIA
## tech, nao so "estabulo" (predio) — mesmo espirito do antigo "Batedor
## exige Batedor Montado especificamente".
func test_batedor_montado_unit_requires_its_own_tech():
	assert_false(TechDatabase.is_unit_unlocked("batedor_montado", {}))
	assert_false(TechDatabase.is_unit_unlocked("batedor_montado", {"estabulo": true}), "so o predio Estabulo nao deveria liberar a unidade")
	assert_true(TechDatabase.is_unit_unlocked("batedor_montado", {"estabulo": true, "batedor_montado": true}))

func test_tech_that_unlocks_finds_cavaleiro_for_cavalry():
	var tech = TechDatabase.tech_that_unlocks("cavalry")
	assert_not_null(tech)
	assert_eq(tech.id, "cavaleiro")

func test_tech_that_unlocks_finds_arqueiro_for_archer():
	var tech = TechDatabase.tech_that_unlocks("archer")
	assert_not_null(tech)
	assert_eq(tech.id, "arqueiro")

func test_tech_that_unlocks_finds_batedor_for_scout():
	var tech = TechDatabase.tech_that_unlocks("scout")
	assert_not_null(tech)
	assert_eq(tech.id, "batedor")

func test_tech_that_unlocks_finds_batedor_montado_for_the_new_unit():
	var tech = TechDatabase.tech_that_unlocks("batedor_montado")
	assert_not_null(tech)
	assert_eq(tech.id, "batedor_montado")

## men_at_arms (Homem de Armas) e warrior (Guarda) agora tem CADA UM sua
## propria tech (homem_de_armas/guarda) — "quartel" virou puramente a tech
## do PREDIO (unlocks_building), sem unidade propria mais.
func test_tech_that_unlocks_finds_homem_de_armas_for_men_at_arms():
	var tech = TechDatabase.tech_that_unlocks("men_at_arms")
	assert_not_null(tech)
	assert_eq(tech.id, "homem_de_armas")

func test_tech_that_unlocks_finds_guarda_for_warrior():
	var tech = TechDatabase.tech_that_unlocks("warrior")
	assert_not_null(tech)
	assert_eq(tech.id, "guarda")

## Regressao: TechData.unlocks_unit tambem default pra "" em techs sem
## unidade nenhuma associada — sem a guarda explicita, tech_that_unlocks("")
## "encontraria" a primeira dessas por acidente em vez de devolver null.
func test_tech_that_unlocks_returns_null_for_empty_kind():
	assert_null(TechDatabase.tech_that_unlocks(""), "predio de rendimento (trains_unit vazio) nao deveria exigir tecnologia nenhuma")

## Desde a arvore de 10 niveis, praticamente todo predio de treino ganhou
## sua PROPRIA tech de unlocks_building (antes so Muralhas/Celeiro/Oficina/
## Mercado tinham isso) — "quartel"/"estabulo"/"campo_de_tiro"/"arsenal_de_
## cerco" agora tambem.
func test_tech_that_unlocks_building_finds_quartel_for_barracks():
	var tech = TechDatabase.tech_that_unlocks_building("barracks")
	assert_not_null(tech)
	assert_eq(tech.id, "quartel")

func test_tech_that_unlocks_building_finds_estabulo_for_stable():
	var tech = TechDatabase.tech_that_unlocks_building("stable")
	assert_not_null(tech)
	assert_eq(tech.id, "estabulo")

func test_tech_that_unlocks_building_finds_campo_de_tiro_for_archery_range():
	var tech = TechDatabase.tech_that_unlocks_building("archery_range")
	assert_not_null(tech)
	assert_eq(tech.id, "campo_de_tiro")

func test_tech_that_unlocks_building_finds_arsenal_de_cerco_for_siege_workshop():
	var tech = TechDatabase.tech_that_unlocks_building("siege_workshop")
	assert_not_null(tech)
	assert_eq(tech.id, "arsenal_de_cerco")

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

## Predios de upgrade (Nivel 4+) tambem tem tech propria — cadeia
## Quartel -> Quartel II -> Quartel III -> Quartel de Elite.
func test_tech_that_unlocks_building_finds_the_upgrade_chain():
	assert_eq(TechDatabase.tech_that_unlocks_building("barracks_2").id, "quartel_2")
	assert_eq(TechDatabase.tech_that_unlocks_building("barracks_3").id, "quartel_3")
	assert_eq(TechDatabase.tech_that_unlocks_building("barracks_elite").id, "quartel_de_elite")

func test_tech_that_unlocks_building_returns_null_for_a_building_without_its_own_tech():
	assert_null(TechDatabase.tech_that_unlocks_building("sages_tower"), "Torre dos Sabios nao tem tecnologia propria nenhuma")

func test_tech_that_unlocks_building_returns_null_for_empty_id():
	assert_null(TechDatabase.tech_that_unlocks_building(""))

## Nenhuma tech de Tecnologia concede feitico — TechDatabase.tech_that_
## unlocks_spell existe so pra manter a API simetrica com MagicDatabase
## (a fonte real, ver test_magic.gd).
func test_tech_that_unlocks_spell_always_returns_null():
	assert_null(TechDatabase.tech_that_unlocks_spell("Metamorfose de Gaia"))
	assert_null(TechDatabase.tech_that_unlocks_spell("Feitiço Que Não Existe"))

func test_tech_that_unlocks_spell_returns_null_for_empty_name():
	assert_null(TechDatabase.tech_that_unlocks_spell(""))

## Nenhuma tech de Tecnologia tem bonus_terrain_types hoje — mesma logica de
## soma de MagicDatabase.yield_bonus_for (ver test_magic.gd), so que sempre
## zero aqui por falta de dado, nao por bug na funcao.
func test_yield_bonus_for_is_zero_for_mundane_techs_without_terrain_bonus():
	var bonus = TechDatabase.yield_bonus_for(HexTileData.TerrainType.FOREST, {"celeiro": true, "quartel": true})
	assert_eq(bonus.food, 0)
	assert_eq(bonus.production, 0)
	assert_eq(bonus.gold, 0)
	assert_eq(bonus.mana, 0)

func test_unlocked_spells_for_empty_when_nothing_researched():
	assert_eq(TechDatabase.unlocked_spells_for({}), [])

## PlayerData.has_unlocked tenta TechDatabase primeiro, MagicDatabase
## depois — este teste cobre a metade mundana (kind gateado por
## TechDatabase); ver test_magic.gd pra metade magica.
func test_player_data_has_unlocked_delegates_to_tech_database():
	var player = PlayerData.new(CivilizationData.new())
	assert_false(player.has_unlocked("archer"))
	player.researched_techs["arqueiro"] = true
	assert_true(player.has_unlocked("archer"))

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

	player.researched_magic["transmutacao_rocha"] = true # +1 producao em colinas/montanhas (arvore de Magia)
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
	player.current_research = "celeiro" # custo 15

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_almost_eq(player.research_progress, 3.0, 0.01)
	assert_false(player.researched_techs.has("celeiro"))

	hex_grid.queue_free()

func test_process_research_completes_tech_when_cost_is_reached():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city = hex_grid.found_city(coord, player, "Capital")
	city.population = 30 # bem mais que o custo (15) num turno so
	player.current_research = "celeiro"

	GameManager.human_player = player
	GameManager._process_research(player)

	assert_true(player.researched_techs.has("celeiro"))
	assert_false(player.researched_magic.has("celeiro"), "celeiro e tech de TechDatabase, nao deveria cair em researched_magic")
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
	player.current_research = "quartel"
	RivalAI.decide_research(player)
	assert_eq(player.current_research, "quartel")

## Roadmap "arvore de 10 niveis": com "celeiro" + "batedor" pesquisadas (2
## techs do Nivel 1, nenhuma delas militar), o Nivel 2 abre e SO "oficina"
## continua uma cadeia (ancora cosmetica em "celeiro", ver TechDatabase.gd)
## — as outras 3 techs do Nivel 2 ancoram em "quartel", que NAO foi
## pesquisada aqui, entao ficam sem continuidade.
func test_decide_research_prioritizes_continuing_an_already_started_chain():
	var player := PlayerData.new(CivilizationData.new())
	player.researched_techs["celeiro"] = true
	player.researched_techs["batedor"] = true

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "com Celeiro pronto, deveria priorizar Oficina sobre as demais techs de Nivel 2 sem continuidade")

## Roadmap "Parte B" B3 — prova que identidade e SO uma preferencia, nunca
## um bloqueio nem uma prioridade mais forte que continuar uma cadeia ja
## comecada: mesmo com a civ tendo forca MAXIMA (1.0) no eixo militar
## (bate perfeito com "homem_de_armas"/"campo_de_tiro", ancoradas em
## "quartel", NAO pesquisada), a IA ainda prioriza "oficina" (continuacao
## de cadeia, eixo industrial, identidade ZERO).
func test_decide_research_identity_never_overrides_stronger_continuation():
	var player := PlayerData.new(CivilizationData.new())
	player.researched_techs["celeiro"] = true
	player.researched_techs["batedor"] = true

	var city := City.new()
	for id in ["walls", "barracks", "archery_range", "stable", "siege_workshop"]:
		city.buildings[id] = true # eixo militar em 1.0 -- identidade perfeita, mas pras techs SEM continuidade
	player.cities.append(city)

	RivalAI.decide_research(player)

	assert_eq(player.current_research, "oficina", "continuacao de cadeia deve vencer mesmo com identidade militar em 1.0 batendo perfeito noutras techs sem continuidade")
	city.queue_free()

## Roadmap "Parte B" B3 — prova de monotonicidade: aumentar a forca do
## eixo militar da civ so pode AUMENTAR a pontuacao de uma tech militar
## (quartel, gateando o predio "barracks"), nunca diminuir nem travar nada.
## A segunda metade prova "nunca inalcancavel": mesmo no auge da identidade
## militar, uma tech de outro eixo (celeiro/agricola) continua no pool
## disponivel normalmente (as duas sao Nivel 1, sempre disponiveis).
func test_decide_research_score_increases_monotonically_with_matching_identity_and_never_excludes_others():
	var player := PlayerData.new(CivilizationData.new())
	var quartel: TechData = TechDatabase.get_tech("quartel") # unlocks_building "barracks" -> eixo militar

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
## "warrior" ENTROU na lista de travados (Roadmap arvore de 10 niveis:
## Guarda deixou de ser sempre-liberado, agora exige a tech "guarda") — sem
## pesquisa nenhuma (nem Tecnologia nem Magia), so predios sem gate de tech
## (ex: Torre dos Sabios) chegam a ser candidatos.
func test_decide_production_never_picks_locked_units_before_researching():
	var player := PlayerData.new(CivilizationData.new())
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city_a = hex_grid.found_city(Vector2i(0, 0), player, "Cidade A")
	hex_grid.found_city(Vector2i(5, 0), player, "Cidade B") # 2 cidades: sai do ramo "sempre colonizador"

	var locked_kinds := ["warrior", "archer", "cavalry", "catapult", "mage", "griffin", "treant"]
	var opponent := PlayerData.new(CivilizationData.new())
	for i in range(20): # varias rodadas pra reduzir chance de falso-positivo por sorte
		RivalAI.decide_production(player, hex_grid, opponent)
		assert_false(city_a.production_item in locked_kinds, "sem nenhuma tecnologia pesquisada, tropa travada por tech nao deveria sair da pontuacao")

	hex_grid.queue_free()

## Testes obrigatorios da separacao estrutural (ver plano de tech/magic):
## nenhuma tech aparece nas duas arvores ao mesmo tempo. O total mundano
## mudou de 21 (9 mundanas + 12 magicas) pra 60 (48 do redesenho de 10
## niveis) e agora pra 67 (55 do rebalanceamento "polimento definitivo V1"
## — 3 reclassificadas + 7 novas, nenhuma removida — + 12 magicas, que
## continuam intocadas).
func test_tech_database_and_magic_database_never_share_an_id():
	var tech_ids := {}
	for tech in TechDatabase.all_techs():
		tech_ids[tech.id] = true
	for tech in MagicDatabase.all_techs():
		assert_false(tech_ids.has(tech.id), "%s nao deveria existir nas duas arvores" % tech.id)

## Explicito em vez de so confiar na contagem de 55 bater (que ja pegaria um
## id duplicado de forma indireta, ja que Dictionary sobrescreve em vez de
## crescer) — mais direto de ler o que esta sendo garantido.
func test_every_tech_id_is_unique():
	var seen := {}
	for tech in TechDatabase.all_techs():
		assert_false(seen.has(tech.id), "id duplicado: %s" % tech.id)
		seen[tech.id] = true

func test_tech_database_has_55_technologies_across_10_tiers():
	assert_eq(TechDatabase.all_techs().size(), 55)
	for tier in range(1, 11):
		var count := 0
		for tech in TechDatabase.all_techs():
			if tech.tier == tier:
				count += 1
		assert_gt(count, 0, "Nivel %d deveria ter pelo menos uma tecnologia" % tier)

func test_tech_database_and_magic_database_together_total_110_technologies():
	assert_eq(TechDatabase.all_techs().size() + MagicDatabase.all_techs().size(), 110)

## --- Roadmap "polimento definitivo V1" (dado de familia/effect_text) ------

## Toda tech MUNDANA precisa de uma display_family valida (um dos 4
## FAMILY_* de TechData) — Magia continua sem familia (default "").
func test_every_mundane_technology_has_a_valid_display_family():
	var valid := [TechData.FAMILY_MILITAR, TechData.FAMILY_ECONOMIA, TechData.FAMILY_DEFESA, TechData.FAMILY_EXPLORACAO_UTILIDADE]
	for tech in TechDatabase.all_techs():
		assert_true(tech.display_family in valid, "%s tem display_family invalida: '%s'" % [tech.id, tech.display_family])

func test_magic_database_never_sets_display_family():
	for tech in MagicDatabase.all_techs():
		assert_eq(tech.display_family, "", "%s (Magia) nao deveria ter display_family — campo e so pra Tecnologia" % tech.id)

## Toda tech MUNDANA precisa de um effect_text honesto e nao-vazio — pedido
## explicito: o jogador tem que conseguir olhar pro card e saber o que
## ganha, sem adivinhar.
func test_every_mundane_technology_has_a_non_empty_effect_text():
	for tech in TechDatabase.all_techs():
		assert_true(tech.effect_text.length() > 0, "%s deveria ter effect_text" % tech.id)

## --- Roadmap "polimento e coesao" (item 16 do pedido) ----------------------

## Item 1: cada tecnologia tem exatamente um tier valido (1..10) — nenhum
## default esquecido (TechData.tier default e 1, entao esquecer de setar
## silenciosamente empurraria a tech pro Nivel 1 sem ninguem notar).
## Toda tech precisa continuar ALCANCAVEL: cada nivel (exceto o 10, que nao
## libera nada depois) precisa ter pelo menos TIER_UNLOCK_THRESHOLD techs —
## senao seria estruturalmente impossivel juntar as 2 pesquisas necessarias
## pra abrir o proximo nivel, travando a arvore pra sempre a partir dali.
func test_every_tier_has_enough_technologies_to_meet_the_unlock_threshold():
	var counts := {}
	for tech in TechDatabase.all_techs():
		counts[tech.tier] = counts.get(tech.tier, 0) + 1
	for tier in range(1, 10):
		assert_gte(counts.get(tier, 0), TechDatabase.TIER_UNLOCK_THRESHOLD, "Nivel %d precisa de pelo menos %d techs pra nao travar a arvore" % [tier, TechDatabase.TIER_UNLOCK_THRESHOLD])

func test_every_technology_has_a_valid_tier():
	for tech in TechDatabase.all_techs():
		assert_true(tech.tier >= 1 and tech.tier <= 10, "%s tem tier invalido: %d" % [tech.id, tech.tier])

## Item 2: os 10 niveis aparecem, na ordem 1..10, sem buraco.
func test_all_10_tiers_are_present_in_order():
	var tiers_seen := {}
	for tech in TechDatabase.all_techs():
		tiers_seen[tech.tier] = true
	for tier in range(1, 11):
		assert_true(tiers_seen.has(tier), "Nivel %d deveria ter pelo menos uma tecnologia" % tier)

## Item 16: nenhum ciclo na cadeia cosmetica de prerequisites (DFS simples)
## — mesmo NAO sendo mais o mecanismo de liberacao, um ciclo aqui ainda
## quebraria a UI (TechTierBoard "liga-se a" e o RivalAI.continues_chain),
## entao vale continuar garantindo que o grafo cosmetico e uma DAG de
## verdade.
var _cycle_visiting: Dictionary
var _cycle_visited: Dictionary
var _cycle_found: bool

## Nao usa lambda recursiva de proposito: uma lambda GDScript que tenta
## chamar a si mesma via uma variavel local ("var dfs: Callable; dfs =
## func(): ... dfs.call(...)") captura `dfs` POR VALOR no instante em que a
## lambda e CRIADA — antes da atribuicao terminar, entao a captura interna
## fica null e a chamada recursiva quebra ("Attempt to call function
## 'null::null' on a null instance"). Metodo de instancia de verdade
## evita essa armadilha.
func _dfs_check_cycle(tech_id: String) -> void:
	if _cycle_found or _cycle_visited.has(tech_id):
		return
	if _cycle_visiting.has(tech_id):
		_cycle_found = true
		return
	_cycle_visiting[tech_id] = true
	var tech: TechData = TechDatabase.get_tech(tech_id)
	if tech:
		for p in tech.prerequisites:
			_dfs_check_cycle(p)
	_cycle_visiting.erase(tech_id)
	_cycle_visited[tech_id] = true

func test_prerequisite_anchors_have_no_cycle():
	_cycle_visiting = {}
	_cycle_visited = {}
	_cycle_found = false

	for tech in TechDatabase.all_techs():
		_dfs_check_cycle(tech.id)

	assert_false(_cycle_found, "cadeia cosmetica de prerequisites nao deveria ter ciclo nenhum")

## Item 15: a IA continua avancando pelos tiers de verdade — simula varias
## rodadas de RivalAI.decide_research + conclusao manual (sem depender do
## harness pesado de integracao) e confirma que o tier maximo desbloqueado
## (entre as techs de TechDatabase que ela concluiu) cresce ao longo do
## tempo, nunca trava no Nivel 1.
func test_ai_advances_through_multiple_tiers_over_successive_research_rounds():
	var player := PlayerData.new(CivilizationData.new())
	var max_tier_seen := 1
	for round_index in range(30): # bem mais que o suficiente pra passar de varios niveis (2 pesquisas por nivel)
		if player.current_research == "":
			RivalAI.decide_research(player)
		if player.current_research == "":
			break # nada mais disponivel -- nao deveria acontecer antes do Nivel 10
		var completed_id: String = player.current_research
		var tech: TechData = TechDatabase.get_tech(completed_id)
		if tech != null:
			player.researched_techs[completed_id] = true
			max_tier_seen = max(max_tier_seen, tech.tier)
		else:
			player.researched_magic[completed_id] = true
		player.current_research = ""

	assert_gt(max_tier_seen, 1, "apos 30 pesquisas concluidas, a IA deveria ter avancado alem do Nivel 1 da arvore de Tecnologia")
