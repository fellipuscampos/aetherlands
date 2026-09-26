extends GutTest

## Aetherlands V2, Fase 13 — Fundação Urbana: V2CityLevelData (fonte única dos números),
## City.city_level (nova cidade, slots, prédios repetíveis) e o City Project de upgrade urbano
## (produção local, Ouro cobrado só na conclusão, uma pesquisa não sobe todas as cidades).
## Território/anexação ficam em test_v2_city_annexation.gd; o fluxo principal ponta a ponta e
## captura ficam em test_v2_city_level_flow.gd.

const URBANIZATION_1 := "v2_infrastructure_urbanization_1"
const URBANIZATION_2 := "v2_infrastructure_urbanization_2"
const URBANIZATION_3 := "v2_infrastructure_urbanization_3"

var _owned_players: Array[PlayerData] = []
var _cities: Array[City] = []
var _grids: Array[HexGrid] = []

func after_each():
	BuildingDatabase._cache.erase(FIXTURE_REPEATABLE_ID)
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_owned_players.append(player)
	return player

func _city(owner_player: PlayerData = null) -> City:
	var city := City.new()
	if owner_player != null:
		city.owner_player = owner_player
	_cities.append(city)
	return city

func _grid(radius: int = 6) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _founded_city(owner_player: PlayerData, grid: HexGrid, coord: Vector2i = Vector2i.ZERO) -> City:
	var city := grid.found_city(coord, owner_player, "Capital")
	_cities.append(city)
	return city

## Empurra `city` até completar o custo do projeto atual, chamando process_turn repetidamente
## (um HexGrid mínimo sem terreno especial é suficiente -- yields cruas não importam aqui).
func _finish_current_production(city: City, grid: HexGrid, max_turns: int = 400) -> Dictionary:
	var result := {}
	for i in max_turns:
		result = city.process_turn(grid)
		if city.production_item == "" or result.get("city_level_up", 0) > 0:
			break
	return result

# --- §75: V2CityLevelData -- fonte única dos números -----------------------------------------

func test_the_four_levels_have_the_documented_baseline_numbers():
	assert_eq([V2CityLevelData.max_building_slots(1), V2CityLevelData.max_building_slots(2), V2CityLevelData.max_building_slots(3), V2CityLevelData.max_building_slots(4)], [4, 7, 10, 13])
	assert_eq([V2CityLevelData.repeatable_building_limit(1), V2CityLevelData.repeatable_building_limit(2), V2CityLevelData.repeatable_building_limit(3), V2CityLevelData.repeatable_building_limit(4)], [1, 2, 3, 4])
	assert_eq([V2CityLevelData.max_territory_radius(1), V2CityLevelData.max_territory_radius(2), V2CityLevelData.max_territory_radius(3), V2CityLevelData.max_territory_radius(4)], [1, 2, 3, 4])
	assert_eq([V2CityLevelData.annexation_grant(1), V2CityLevelData.annexation_grant(2), V2CityLevelData.annexation_grant(3), V2CityLevelData.annexation_grant(4)], [0, 4, 5, 6])

func test_upgrade_costs_are_the_documented_baseline():
	assert_eq([V2CityLevelData.upgrade_production_cost(2), V2CityLevelData.upgrade_gold_cost(2)], [60.0, 30.0])
	assert_eq([V2CityLevelData.upgrade_production_cost(3), V2CityLevelData.upgrade_gold_cost(3)], [120.0, 70.0])
	assert_eq([V2CityLevelData.upgrade_production_cost(4), V2CityLevelData.upgrade_gold_cost(4)], [220.0, 140.0])

func test_research_requirement_per_level():
	assert_eq(V2CityLevelData.research_required_for_level(1), "", "nível I nunca exige pesquisa")
	assert_eq(V2CityLevelData.research_required_for_level(2), URBANIZATION_1)
	assert_eq(V2CityLevelData.research_required_for_level(3), URBANIZATION_2)
	assert_eq(V2CityLevelData.research_required_for_level(4), URBANIZATION_3)

func test_invalid_levels_clamp_to_the_valid_range():
	assert_eq(V2CityLevelData.max_building_slots(0), V2CityLevelData.max_building_slots(1))
	assert_eq(V2CityLevelData.max_building_slots(-5), V2CityLevelData.max_building_slots(1))
	assert_eq(V2CityLevelData.max_building_slots(5), V2CityLevelData.max_building_slots(4))
	assert_eq(V2CityLevelData.max_building_slots(99), V2CityLevelData.max_building_slots(4))

func test_next_level_and_has_next_level():
	assert_eq(V2CityLevelData.next_level(1), 2)
	assert_eq(V2CityLevelData.next_level(2), 3)
	assert_eq(V2CityLevelData.next_level(3), 4)
	assert_eq(V2CityLevelData.next_level(4), 0, "Cidade IV não tem próximo nível")
	assert_false(V2CityLevelData.has_next_level(4))

func test_is_developed_threshold_is_level_3():
	assert_false(V2CityLevelData.is_developed(1))
	assert_false(V2CityLevelData.is_developed(2))
	assert_true(V2CityLevelData.is_developed(3))
	assert_true(V2CityLevelData.is_developed(4))

func test_project_and_unlock_ids_are_distinct_concepts():
	assert_eq(V2CityLevelData.unlock_id_for_level(2), "v2_city_level_2")
	assert_eq(V2CityLevelData.project_id_for_level(2), "v2_city_upgrade_2")
	assert_ne(V2CityLevelData.unlock_id_for_level(2), V2CityLevelData.project_id_for_level(2), "unlock (pesquisa) e projeto (produção) nunca são o mesmo id")
	assert_eq(V2CityLevelData.target_level_for_project("v2_city_upgrade_3"), 3)
	assert_eq(V2CityLevelData.target_level_for_unlock("v2_city_level_3"), 3)
	assert_eq(V2CityLevelData.target_level_for_project("warrior"), 0, "id que não é projeto -> 0")
	assert_false(V2CityLevelData.is_city_project("v2_building_guardian_hall"))

# --- §57-65/§76: conteúdo canônico das 18 pesquisas de Infraestrutura --------------------------

func test_infrastructure_has_six_branches_of_three_nodes_each_eighteen_total():
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE).size(), 18)
	for branch in ["economy", "logistics", "industry", "academy", "arcane", "urbanization"]:
		assert_eq(V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, branch).size(), 3, branch)

func test_all_eighteen_nodes_have_canonical_names_and_costs_but_are_not_placeholders():
	for branch in ["economy", "logistics", "industry", "academy", "arcane", "urbanization"]:
		var nodes := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, branch)
		var expected_costs := [16, 48, 120]
		for i in nodes.size():
			var node: V2ResearchNode = nodes[i]
			assert_false(node.is_placeholder, node.id)
			assert_ne(node.display_name, "%s %s" % [branch.capitalize(), ["I", "II", "III"][i]], "%s: nome canônico, não o rótulo estrutural" % node.id)
			assert_ne(node.description, "", node.id)
			assert_eq(int(node.cost), expected_costs[i], node.id)

## Aetherlands V2, Fase 14: as cinco linhas econômicas de Infraestrutura deixaram de ser inertes
## (§92 do pedido -- 18/18 pesquisas de Infraestrutura conectadas). A cobertura completa de N1
## "building"/N2-N3 "infrastructure_upgrade"/ids exatos vive em test_v2_economy_data.gd; aqui só
## confirma que Urbanização continua com o tipo "city_level" próprio, nunca confundido com o das
## linhas econômicas.
func test_urbanization_keeps_its_own_unlock_type_distinct_from_the_economy_lines():
	for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, "urbanization"):
		assert_true(node.gameplay_connected, node.id)
		assert_eq(node.unlock_type, "city_level", node.id)
		assert_ne(node.unlock_id, "placeholder", node.id)
	for branch in ["economy", "logistics", "industry", "academy", "arcane"]:
		for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, branch):
			assert_true(node.gameplay_connected, node.id)
			assert_ne(node.unlock_type, "city_level", "%s: só Urbanização usa city_level" % node.id)

func test_urbanization_chain_and_unlock_ids():
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_1).display_name, "Planejamento Urbano")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_1).unlock_id, "v2_city_level_2")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_2).display_name, "Cidade Fortificada")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_2).unlock_id, "v2_city_level_3")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_3).display_name, "Metrópole")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_3).unlock_id, "v2_city_level_4")
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_2).prerequisites, [URBANIZATION_1])
	assert_eq(V2ResearchDatabase.get_node(URBANIZATION_3).prerequisites, [URBANIZATION_2])

## Fase 16: a Fortificação foi conectada — cada nível de Urbanização desbloqueia Cidade N e Muralhas N-1,
## e nenhuma nota de "fortificações futuras" sobra no tooltip.
func test_urbanization_tooltip_never_shows_gameplay_not_connected_and_names_the_fortification_it_unlocks():
	for id in [URBANIZATION_1, URBANIZATION_2, URBANIZATION_3]:
		var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(id)).replace("\n", " ")
		assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), id)
	var n2 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(URBANIZATION_2)).replace("\n", " ")
	assert_true(n2.contains("Cidade III"), n2)
	assert_true(n2.contains("Desbloqueia Cidade III e Muralhas II."), n2)
	assert_false(n2.contains("posteriormente"), n2)
	assert_false(n2.contains("fase posterior"), n2)
	var n1 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(URBANIZATION_1)).replace("\n", " ")
	assert_true(n1.contains("Desbloqueia Cidade II e Muralhas I."), n1)
	var n3 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node(URBANIZATION_3)).replace("\n", " ")
	assert_true(n3.contains("Desbloqueia Cidade IV e Fortaleza."), n3)

## Aetherlands V2, Fase 14: v2_infrastructure_economy_1 passou a ser gameplay_connected (§92 do
## pedido) -- este teste cobria a Fase 13 (nó canônico mas ainda sem endereço estável). A cobertura
## equivalente pra Fase 14 (nenhum dos 18 nós mostra V2ResearchDatabase.GAMEPLAY_NOTICE) vive em
## test_v2_economy_data.gd; aqui só confirma que o literal "(placeholder)" nunca aparece, mesmo
## conectado.
func test_infrastructure_node_tooltip_never_prints_the_literal_placeholder_word():
	var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_infrastructure_economy_1"))
	assert_false(tooltip.contains("(placeholder)"), tooltip)

func test_urbanization_research_is_connected_through_the_same_v2unlocksystem_pipeline():
	assert_true("city_level" in V2UnlockSystem.CONNECTED_TYPES)
	assert_true("v2_city_level_2" in V2InfrastructureContent.CONNECTED_UNLOCK_IDS)
	assert_false(FileAccess.file_exists("res://scripts/core/UrbanizationUnlockSystem.gd"))

func test_researching_urbanization_unlocks_the_next_level_and_announces_it():
	var player := _player()
	GameManager.human_player = player
	watch_signals(EventBus)
	player.v2_research.complete_research(URBANIZATION_1)
	assert_true(player.has_unlocked("v2_city_level_2"))
	assert_signal_emitted(EventBus, "notify")
	var params = get_signal_parameters(EventBus, "notify", 0)
	assert_true(String(params[0]).contains("Cidade II"), params[0])
	assert_true(String(params[0]).begins_with("Desenvolvimento urbano disponível"), params[0])
	GameManager.human_player = null

func test_researching_urbanization_never_upgrades_any_city_by_itself():
	var player := _player()
	var grid := _grid()
	var a := _founded_city(player, grid, Vector2i(0, 0))
	var b := _founded_city(player, grid, Vector2i(-4, 0))
	player.v2_research.complete_research(URBANIZATION_1)
	assert_eq(a.city_level, 1, "§1/§72 do pedido: pesquisar NUNCA sobe uma cidade sozinha")
	assert_eq(b.city_level, 1)

# --- §77: nova cidade ---------------------------------------------------------------------------

func test_a_freshly_founded_city_starts_at_level_1_with_zero_annexation_points():
	var player := _player()
	var grid := _grid()
	var city := _founded_city(player, grid)
	assert_eq(city.city_level, 1)
	assert_eq(city.annexation_points, 0)
	assert_eq(city.max_building_slots(), 4)
	assert_eq(city.max_copies_for_building(BuildingData.new()), 1)

func test_bare_city_new_also_defaults_to_level_1():
	var city := _city()
	assert_eq(city.city_level, 1)
	assert_eq(city.annexation_points, 0)
	assert_eq(city.repeatable_building_counts, {})

# --- §12/§16/§78-81: o projeto de upgrade urbano é produção local, Ouro só na conclusão --------

func test_city_upgrade_is_blocked_without_the_research_even_with_gold():
	var player := _player()
	player.gold = 1000.0
	var city := _city(player)
	var reason := city.city_upgrade_unavailable_reason()
	assert_ne(reason, "")
	assert_true(reason.contains("Planejamento Urbano"), reason)
	assert_false(city.can_start_city_upgrade())

func test_city_upgrade_becomes_available_once_researched_and_gold_is_on_hand():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 100.0
	var city := _city(player)
	assert_eq(city.city_upgrade_unavailable_reason(), "")
	assert_true(city.can_start_city_upgrade())

func test_city_upgrade_requires_gold_on_hand_to_start_not_just_to_finish():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 10.0 # menos que os 30 exigidos
	var city := _city(player)
	var reason := city.city_upgrade_unavailable_reason()
	assert_true(reason.contains("30"), reason)
	assert_false(city.can_start_city_upgrade())

func test_starting_the_upgrade_does_not_deduct_gold_immediately():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 100.0
	var city := _city(player)
	city.set_production("v2_city_upgrade_2")
	assert_eq(player.gold, 100.0, "§16 do pedido: Ouro não é reservado ao selecionar")

func test_full_upgrade_flow_level_1_to_2():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 100.0
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.set_production("v2_city_upgrade_2")
	var result := _finish_current_production(city, grid)
	assert_eq(city.city_level, 2)
	assert_eq(city.max_building_slots(), 7)
	assert_eq(city.max_copies_for_building(BuildingData.new()), 1) # UNIQUE não muda, mas o CAP repetível (repeatable_building_limit) sim -- ver teste dedicado
	assert_eq(V2CityLevelData.repeatable_building_limit(city.city_level), 2)
	assert_eq(city.annexation_points, 4)
	assert_eq(player.gold, 70.0, "100 - 30 do custo de Cidade II")
	assert_eq(city.production_item, "", "projeto concluído deixa a cidade ociosa, como qualquer produção")
	assert_eq(result.city_level_up, 2)

func test_full_upgrade_flow_level_2_to_3_requires_n2_not_just_n1():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 2
	city.annexation_points = 0
	player.gold = 200.0
	assert_true(city.city_upgrade_unavailable_reason().contains("Cidade Fortificada"), "N1 sozinho não basta pra Cidade III")
	player.v2_research.complete_research(URBANIZATION_2)
	city.set_production("v2_city_upgrade_3")
	_finish_current_production(city, grid)
	assert_eq(city.city_level, 3)
	assert_eq(city.max_building_slots(), 10)
	assert_eq(V2CityLevelData.repeatable_building_limit(3), 3)
	assert_eq(city.annexation_points, 5)
	assert_eq(player.gold, 130.0, "200 - 70 do custo de Cidade III")
	assert_true(city.is_developed_v2(), "Cidade III já é 'Desenvolvida'")

func test_full_upgrade_flow_level_3_to_4_has_no_further_upgrade_after():
	var player := _player()
	for id in [URBANIZATION_1, URBANIZATION_2, URBANIZATION_3]:
		player.v2_research.complete_research(id)
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.city_level = 3
	player.gold = 300.0
	city.set_production("v2_city_upgrade_4")
	_finish_current_production(city, grid)
	assert_eq(city.city_level, 4)
	assert_eq(city.max_building_slots(), 13)
	assert_eq(V2CityLevelData.repeatable_building_limit(4), 4)
	assert_eq(city.annexation_points, 6)
	assert_eq(player.gold, 160.0, "300 - 140 do custo de Cidade IV")
	assert_eq(city.city_upgrade_unavailable_reason(), "Cidade já está no nível máximo.")
	assert_false(city.can_start_city_upgrade())

## §81 do pedido: cenário exato -- PP completo, Ouro insuficiente NA conclusão (o jogador gastou
## depois de iniciar). O upgrade fica esperando, sem perder PP nem zerar Ouro.
func test_insufficient_gold_at_completion_waits_without_losing_production_points():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 100.0
	var grid := _grid()
	var city := _founded_city(player, grid)
	city.set_production("v2_city_upgrade_2")
	player.gold = 5.0 # o jogador gastou o Ouro depois de iniciar -- menos que os 30 exigidos
	var result := city.process_turn(grid)
	for i in 60:
		if city.stored_production >= city.production_cost():
			break
		result = city.process_turn(grid)
	assert_eq(city.city_level, 1, "não conclui sem Ouro suficiente")
	assert_almost_eq(city.stored_production, city.production_cost(), 0.001, "PP fica travado no custo total, nunca perde")
	assert_eq(player.gold, 5.0, "Ouro nunca fica negativo nem é descontado parcialmente")
	assert_eq(result.city_level_up, 0)
	assert_gt(city.city_upgrade_waiting_for_gold(), 0)
	# Ao recuperar o Ouro, conclui e cobra EXATAMENTE uma vez.
	player.gold = 100.0
	result = city.process_turn(grid)
	assert_eq(city.city_level, 2)
	assert_eq(player.gold, 70.0, "cobrado exatamente uma vez (100 - 30), nunca duas")
	assert_eq(result.city_level_up, 2)

func test_city_project_competes_for_the_same_local_production_slot_as_units_and_buildings():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 100.0
	var city := _city(player)
	city.set_production("v2_city_upgrade_2")
	assert_true(city.city_upgrade_unavailable_reason() == "", "a própria cidade produzindo o projeto não se bloqueia")
	city.set_production("warrior") # troca -- abandona o projeto, como trocar qualquer produção
	assert_eq(city.production_item, "warrior")
	assert_true(city.city_upgrade_unavailable_reason().contains("ocupada"), "produção da cidade ocupada por outra coisa")

## §82 do pedido: três cidades, uma pesquisa, upgrade concluído só numa delas.
func test_one_research_does_not_upgrade_every_city_only_the_one_that_completes_its_own_project():
	var player := _player()
	player.v2_research.complete_research(URBANIZATION_1)
	player.gold = 1000.0
	var grid := _grid(10)
	var a := _founded_city(player, grid, Vector2i(0, 0))
	var b := _founded_city(player, grid, Vector2i(-8, 0))
	var c := _founded_city(player, grid, Vector2i(8, -4))
	for city in [a, b, c]:
		assert_true(city.can_start_city_upgrade(), "as três podem INICIAR")
	b.set_production("v2_city_upgrade_2")
	_finish_current_production(b, grid)
	assert_eq(a.city_level, 1)
	assert_eq(b.city_level, 2)
	assert_eq(c.city_level, 1)

func test_city_levels_are_isolated_per_civilization_not_per_research():
	var human := _player()
	var rival := _player()
	human.v2_research.complete_research(URBANIZATION_1)
	human.gold = 100.0
	var grid := _grid()
	var human_city := _founded_city(human, grid, Vector2i(0, 0))
	var rival_city := _founded_city(rival, grid, Vector2i(-4, 0))
	human_city.set_production("v2_city_upgrade_2")
	_finish_current_production(human_city, grid)
	assert_eq(human_city.city_level, 2)
	assert_eq(rival_city.city_level, 1, "o rival não pesquisou nem produziu nada -- não sobe")
	assert_false(rival.has_unlocked("v2_city_level_2"), "unlock é por PlayerData/V2ResearchState, não global")

# --- §20/§94: API semântica "Cidade Desenvolvida" -- nunca conecta vitória --------------------

func test_is_developed_v2_follows_the_level_3_threshold_and_never_touches_victory():
	var city := _city()
	city.city_level = 1
	assert_false(city.is_developed_v2())
	city.city_level = 2
	assert_false(city.is_developed_v2())
	city.city_level = 3
	assert_true(city.is_developed_v2())
	city.city_level = 4
	assert_true(city.is_developed_v2())

# --- §22-24/§83: slots -- independentes de população, save legado over-cap preservado ----------

func test_the_nth_plus_one_building_is_blocked_at_every_level():
	var city := _city()
	var ids := ["granary", "workshop", "market", "walls", "sages_tower", "barracks", "archery_range", "stable", "siege_workshop", "arcane_tower", "griffin_roost", "druid_grove", "runic_anvil", "shadow_crypt"]
	for level in [1, 2, 3, 4]:
		city.city_level = level
		city.buildings.clear()
		var cap := V2CityLevelData.max_building_slots(level)
		for i in cap:
			city.buildings[ids[i]] = true
		assert_eq(city.used_building_slots(), cap, "level %d" % level)
		assert_false(city.can_build(ids[cap]), "level %d: o (cap+1)-ésimo prédio deve ser bloqueado" % level)

func test_legacy_save_above_the_current_cap_keeps_every_building_new_ones_still_blocked():
	var player := _player()
	var city := _city(player)
	city.city_level = 1 # 4 slots
	# Fixture de save legado: 6 prédios V2 (acima do cap atual de 4). Fase 25: prédios V1 de saves
	# antigos são removidos na sanitização do load (SaveManager), não chegam aqui.
	for id in ["v2_building_guardian_hall", "v2_building_warrior_hall", "v2_building_ranger_camp", "v2_building_war_stable", "v2_building_rogue_guild", "v2_building_siege_arsenal"]:
		city.buildings[id] = true
	assert_eq(city.used_building_slots(), 6, "nenhum prédio existente é apagado -- §24 do pedido")
	var fixture := _register_fixture_repeatable_building()
	assert_false(city.can_build(fixture.id), "novo prédio bloqueado enquanto acima do cap")
	city.city_level = 2 # 7 slots: agora cabe 1 a mais
	assert_true(city.can_build(fixture.id), "subir de nível eventualmente aumenta o limite")

func test_population_alone_never_changes_slots_repeatable_cap_annex_points_or_radius():
	var city := _city()
	city.city_level = 2
	var before := [city.max_building_slots(), V2CityLevelData.repeatable_building_limit(city.city_level), city.annexation_points, V2CityLevelData.max_territory_radius(city.city_level)]
	var at_1 := [city.max_building_slots(), V2CityLevelData.repeatable_building_limit(city.city_level), city.annexation_points, V2CityLevelData.max_territory_radius(city.city_level)]
	var at_50 := [city.max_building_slots(), V2CityLevelData.repeatable_building_limit(city.city_level), city.annexation_points, V2CityLevelData.max_territory_radius(city.city_level)]
	assert_eq(before, at_1)
	assert_eq(at_1, at_50)

# --- §25-28/§85-87: CopyLimitMode (mecanismo genérico, com fixture -- nenhum prédio real) -------

const FIXTURE_REPEATABLE_ID := "test_v2_repeatable_fixture"

func _register_fixture_repeatable_building() -> BuildingData:
	var building := BuildingData.new()
	building.id = FIXTURE_REPEATABLE_ID
	building.display_name = "Fixture Repetível"
	building.production_cost = 10.0
	building.copy_limit_mode = BuildingData.CopyLimitMode.CITY_LEVEL
	BuildingDatabase._cache[FIXTURE_REPEATABLE_ID] = building
	return building

func test_every_existing_building_defaults_to_unique_v1_and_military_v2_untouched():
	for id in ["granary", "workshop", "market", "walls", "barracks", "v2_building_guardian_hall", "v2_building_guardian_mastery", "v2_unit_shieldbearer"]:
		var building := BuildingDatabase.get_building(id)
		if building == null:
			continue # v2_unit_* não é building; ignorado -- só os prédios reais importam aqui
		assert_eq(building.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE, id)

func test_unique_building_never_allows_a_second_copy_even_at_city_level_4():
	var city := _city()
	city.city_level = 4
	city.buildings["v2_building_guardian_hall"] = true
	assert_false(city.can_build("v2_building_guardian_hall"), "UNIQUE: no máximo 1, em qualquer City Level")
	assert_eq(city.max_copies_for_building(BuildingDatabase.get_building("v2_building_guardian_hall")), 1)

func test_city_level_copy_limit_mode_scales_with_the_level_via_fixture():
	var fixture := _register_fixture_repeatable_building()
	var city := _city()
	for level in [1, 2, 3, 4]:
		city.city_level = level
		city.repeatable_building_counts.clear()
		city.buildings.erase(FIXTURE_REPEATABLE_ID)
		assert_eq(city.max_copies_for_building(fixture), level, "cap repetível == nível (baseline 1/2/3/4)")
		for i in level:
			assert_true(city.can_build(FIXTURE_REPEATABLE_ID), "level %d cópia %d" % [level, i + 1])
			city.buildings[FIXTURE_REPEATABLE_ID] = true
			city.repeatable_building_counts[FIXTURE_REPEATABLE_ID] = i + 1
		assert_false(city.can_build(FIXTURE_REPEATABLE_ID), "level %d: além do cap, bloqueado" % level)
		assert_eq(city.building_count(FIXTURE_REPEATABLE_ID), level)

func test_repeatable_building_still_respects_the_total_slot_cap_independent_of_its_own_copy_limit():
	var fixture := _register_fixture_repeatable_building()
	var city := _city()
	city.city_level = 2 # 7 slots totais, cap repetível 2 (o fixture cabe 2x)
	city.buildings["granary"] = true
	city.buildings["workshop"] = true
	city.buildings["market"] = true
	city.buildings["walls"] = true
	city.buildings["sages_tower"] = true
	city.buildings[FIXTURE_REPEATABLE_ID] = true
	city.repeatable_building_counts[FIXTURE_REPEATABLE_ID] = 1
	assert_eq(city.used_building_slots(), 6, "5 únicos + 1 cópia do repetível")
	assert_true(city.can_build(FIXTURE_REPEATABLE_ID), "ainda cabe 1 slot (7º) e o cap repetível (2) permite outra cópia")
	city.buildings["barracks"] = true # ocupa o 7º e último slot
	assert_false(city.can_build(FIXTURE_REPEATABLE_ID), "cap repetível permitiria, mas os SLOTS acabaram -- §26 do pedido")

func test_requires_building_still_means_at_least_one_copy_exists_regardless_of_repeatable_support():
	var fixture := _register_fixture_repeatable_building()
	var dependent := BuildingData.new()
	dependent.id = "test_v2_repeatable_dependent"
	dependent.display_name = "Depende do Fixture"
	dependent.requires_building = FIXTURE_REPEATABLE_ID
	BuildingDatabase._cache[dependent.id] = dependent
	var city := _city()
	city.city_level = 4
	assert_false(city.can_build(dependent.id), "sem nenhuma cópia do fixture, bloqueado")
	city.buildings[FIXTURE_REPEATABLE_ID] = true
	city.repeatable_building_counts[FIXTURE_REPEATABLE_ID] = 1
	assert_true(city.can_build(dependent.id), "UMA cópia já satisfaz -- não exige todas as permitidas")
	BuildingDatabase._cache.erase(dependent.id)

func test_building_count_helper_never_needs_only_has_building():
	var fixture := _register_fixture_repeatable_building()
	var city := _city()
	assert_eq(city.building_count(FIXTURE_REPEATABLE_ID), 0, "nenhuma cópia ainda")
	city.buildings[FIXTURE_REPEATABLE_ID] = true
	city.repeatable_building_counts[FIXTURE_REPEATABLE_ID] = 3
	assert_eq(city.building_count(FIXTURE_REPEATABLE_ID), 3, "buildings.has() sozinho não diria '3'")

# --- §107: anti-hardcode ------------------------------------------------------------------------

func test_city_gd_never_hardcodes_level_numbers_it_only_calls_v2citylveldata():
	var code := FileAccess.get_file_as_string("res://scripts/city/City.gd")
	# Procura por atribuições literais de slots que NÃO passem por V2CityLevelData (checagem leve:
	# os números 4/7/10/13 só devem aparecer dentro de V2CityLevelData.gd, nunca em City.gd).
	for literal in ["return 4\n", "return 7\n", "return 10\n", "return 13\n"]:
		assert_false(code.contains(literal), "City.gd parece hardcodar um slot: %s" % literal)
	assert_true(code.contains("V2CityLevelData.max_building_slots(city_level)"))

func test_no_scattered_if_city_level_equals_logic_in_the_main_files():
	for path in ["res://scripts/city/City.gd", "res://scripts/ui/HUD.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/autoload/SaveManager.gd"]:
		var code := FileAccess.get_file_as_string(path)
		for bad in ["if city_level == 2", "if city.city_level == 2", "if city_level==2"]:
			assert_false(code.contains(bad), "%s: %s" % [path, bad])
