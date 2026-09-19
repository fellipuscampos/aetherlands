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
	assert_eq(bonus.food, 1, "so o Celeiro da comida")
	assert_eq(bonus.production, 2, "so a Oficina da producao")
	assert_eq(bonus.gold, 2, "so o Mercado da ouro")
	assert_almost_eq(bonus.storage, 10.0, 0.01, "so o Celeiro aumenta o teto de armazenamento")

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

## Santuario do Nodulo (Roadmap Fase F, F1): habilita o Ritual do Nodulo
## (VictoryConditions.has_arcane_sanctuary) — custo e bonus de mana sao
## valores iniciais de gameplay, ainda NAO calibrados (ver F7).
func test_total_bonus_sums_mana_from_the_arcane_sanctuary():
	var built = {"arcane_sanctuary": true}
	var bonus = BuildingDatabase.total_bonus(built)
	assert_eq(bonus.mana, 2)
	assert_eq(bonus.food, 0)
	assert_eq(bonus.production, 0)
	assert_eq(bonus.gold, 0)

func test_arcane_sanctuary_has_no_tech_gate_and_baseline_cost():
	var sanctuary = BuildingDatabase.get_building("arcane_sanctuary")
	assert_not_null(sanctuary)
	assert_eq(sanctuary.display_name, "Santuário do Nódulo")
	assert_almost_eq(sanctuary.production_cost, 45.0, 0.01)
	assert_eq(sanctuary.trains_unit, "", "Santuario e predio de rendimento, nao treina tropa")
	assert_eq(sanctuary.requires_building, "", "sem pre-requisito de predio, ver tech gate = nenhum")
	assert_null(TechDatabase.tech_that_unlocks_building("arcane_sanctuary"), "sem tech gate, pedido explicito do usuario")

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
	var barracks = BuildingDatabase.building_that_trains("men_at_arms")
	assert_not_null(barracks)
	assert_eq(barracks.id, "barracks")

func test_building_that_trains_returns_null_for_kind_without_a_building():
	assert_null(BuildingDatabase.building_that_trains("settler"), "Colonizador nao deveria exigir predio nenhum")

## Pedido do usuario numa rodada seguinte: "o guarda comum nao precisa de
## quartel pra ser feito" — warrior deixou de ter trains_unit em QUALQUER
## BuildingData (o Quartel passou a treinar "men_at_arms" no lugar dele).
func test_building_that_trains_returns_null_for_warrior():
	assert_null(BuildingDatabase.building_that_trains("warrior"), "Guarda nao deveria exigir predio nenhum")

## Tropa racial exclusiva (UnitDatabase.RACE_UNIQUE_KIND) nao tem
## BuildingData proprio com trains_unit == kind — cai no Quartel, o mesmo
## predio que ja treina o Guarda comum (ver comentario de
## building_that_trains). human_knight NAO entra nesta lista (ver teste
## dedicado abaixo, cai no Estabulo em vez do Quartel).
func test_building_that_trains_falls_back_to_barracks_for_racial_units():
	for kind in ["dwarf_axeguard", "orc_berserker", "elf_ranger"]:
		var building = BuildingDatabase.building_that_trains(kind)
		assert_not_null(building, "%s deveria cair no Quartel" % kind)
		assert_eq(building.id, "barracks")

## Cavaleiro Real (human_knight) e a UNICA tropa racial que nao cai no
## Quartel — pedido do usuario: "voce precisa pesquisar[,] o estabulo
## construir, e apos construido no estabulo voce pode fazer o cavaleiro
## real".
func test_building_that_trains_routes_human_knight_to_the_stable():
	var building = BuildingDatabase.building_that_trains("human_knight")
	assert_not_null(building)
	assert_eq(building.id, "stable")

## Roadmap "arvore de 10 niveis": Batedor (scout) deixou de cair no
## Estabulo — virou a opcao de exploracao barata do Nivel 1, sem predio
## nenhum, igual Guarda/Colonizador. Quem agora usa o Estabulo (fallback)
## e "batedor_montado", a unidade NOVA e mais forte do Nivel 3.
func test_building_that_trains_returns_null_for_scout():
	assert_null(BuildingDatabase.building_that_trains("scout"), "Batedor nao deveria exigir predio nenhum")

func test_building_that_trains_routes_batedor_montado_to_the_stable():
	var building = BuildingDatabase.building_that_trains("batedor_montado")
	assert_not_null(building)
	assert_eq(building.id, "stable")

## Pedido do usuario: "faca o estabulo ser uma coisa que so pode ser feita
## depois do quartel" — ver City.can_build()/_prerequisite_building_present
## pra onde este campo e de fato aplicado.
func test_stable_requires_the_barracks_building():
	var stable = BuildingDatabase.get_building("stable")
	assert_eq(stable.requires_building, "barracks")

func test_barracks_has_no_building_prerequisite_of_its_own():
	var barracks = BuildingDatabase.get_building("barracks")
	assert_eq(barracks.requires_building, "", "Quartel deveria continuar sendo o primeiro passo da cadeia militar, sem pre-requisito de predio")

## self_placed = true so pra Muralhas — pedido do usuario: "essa muralha no
## caso simplesmente adiciona esteticamente uma muralha ao redor do tile da
## cidade, o tile principal da cidade". Nao faz sentido escolher "onde"
## cercar uma cidade que so tem um tile, entao Muralhas pula o fluxo normal
## de escolher um tile VIZINHO (SelectionManager.start_building_placement)
## que todo outro predio usa.
func test_only_walls_is_self_placed():
	for b in BuildingDatabase.all_buildings():
		if b.id == "walls":
			assert_true(b.self_placed, "Muralhas deveria ser self_placed")
		else:
			assert_false(b.self_placed, "%s nao deveria ser self_placed" % b.display_name)

## Regressao: predios de RENDIMENTO/DEFESA (Celeiro, Muralhas...) nao tem
## trains_unit preenchido — nao deveriam aparecer como "predio de treino"
## de kind nenhum.
## "market" SAIU desta lista (Roadmap "arvore de 10 niveis": o Mercado
## passou a treinar "mercador" tambem, ver BuildingDatabase.gd) — os outros
## continuam predios de RENDIMENTO puro.
func test_yield_buildings_do_not_train_any_unit():
	for b in BuildingDatabase.all_buildings():
		if b.id in ["granary", "workshop", "workshop_2", "walls", "sages_tower", "arcane_sanctuary", "watchtower", "fortress", "grand_market", "imperial_fortress", "grand_emporium"]:
			assert_eq(b.trains_unit, "", "%s nao deveria travar producao de unidade nenhuma" % b.display_name)

func test_market_trains_mercador():
	assert_eq(BuildingDatabase.get_building("market").trains_unit, "mercador")

## Cada tropa de combate (todo kind de UnitDatabase.PLAYER_TRAINABLE_KINDS
## exceto Colonizador/Guarda) precisa ter exatamente um predio de treino
## correspondente, senao ficaria impossivel de produzir depois do pivot
## (nenhum predio libera esse kind). Deriva o roster de UnitDatabase em vez
## de listar os kinds a mao aqui — um kind novo la (ex: stone_golem/
## shadow_summoner ao entrar no jogo) so passa a ser coberto automatico.
## Tropa RACIAL exclusiva (UnitDatabase.RACE_UNIQUE_KIND) fica de fora de
## proposito: nenhuma das 4 ganhou um BuildingData proprio com trains_unit
## == kind, todas caem em algum predio existente por FALLBACK (Quartel pra
## 3 delas, Estabulo pra human_knight — ver BuildingDatabase.
## building_that_trains e os testes dedicados acima) — bater 0 aqui e o
## resultado ESPERADO pra elas, nao uma falha. Guarda (warrior) tambem fica
## de fora pelo mesmo motivo — mesmo status do Colonizador agora (ver
## test_building_that_trains_returns_null_for_warrior). Batedor (scout)
## fica de fora pelo MESMO motivo das raciais (fallback pro Estabulo, sem
## trains_unit proprio), mesmo nao sendo tropa racial de verdade.
## Roadmap "arvore de 10 niveis": um predio so tem UM trains_unit (String),
## entao boa parte do elenco novo cai em BuildingDatabase.
## UNIT_TRAINER_FALLBACK em vez de ganhar predio dedicado (ver comentario
## la) — a checagem "exatamente um trains_unit literal" so vale pra quem
## NAO esta no fallback.
func test_every_combat_unit_kind_has_exactly_one_training_building():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind == "settler" or kind == "warrior" or kind == "scout" or UnitDatabase.race_for_unique_kind(kind) != "":
			continue
		if BuildingDatabase.UNIT_TRAINER_FALLBACK.has(kind):
			continue
		var matches := 0
		for b in BuildingDatabase.all_buildings():
			if b.trains_unit == kind:
				matches += 1
		assert_eq(matches, 1, "%s deveria ter exatamente um predio de treino" % kind)

## Todo kind treinavel (exceto Colonizador/Guarda/Batedor, sempre sem
## predio) precisa resolver pra ALGUM predio via building_that_trains —
## direto (trains_unit literal) ou por fallback (UNIT_TRAINER_FALLBACK/
## racial) — senao ficaria impossivel de produzir de verdade.
func test_every_combat_unit_kind_resolves_to_a_training_building():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind == "settler" or kind == "warrior" or kind == "scout":
			continue
		assert_not_null(BuildingDatabase.building_that_trains(kind), "%s deveria resolver pra algum predio de treino" % kind)

## --- Roadmap "polimento definitivo V1" (5 predios novos) -------------------

func test_new_buildings_exist_with_expected_prerequisites():
	var expected_requires := {
		"garrison": "",
		"granary_2": "granary",
		"market_2": "market",
		"walls_2": "walls",
		"trading_post": "grand_market",
	}
	for id in expected_requires.keys():
		var b := BuildingDatabase.get_building(id)
		assert_not_null(b, "%s deveria existir em BuildingDatabase" % id)
		assert_eq(b.requires_building, expected_requires[id], "%s tem requires_building inesperado" % id)

## Nenhum dos 5 predios novos treina unidade nenhuma — sao todos de
## rendimento/defesa puro (mesma familia de Celeiro/Muralhas/Torre de
## Vigia), nenhuma tech nova desta rodada desbloqueia unidade junto com
## predio.
func test_new_buildings_do_not_train_any_unit():
	for id in ["garrison", "granary_2", "market_2", "walls_2", "trading_post"]:
		assert_eq(BuildingDatabase.get_building(id).trains_unit, "", "%s nao deveria treinar unidade nenhuma" % id)
