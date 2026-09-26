extends GutTest

## Aetherlands V2, Fase 14 — Economia V2: V2InfrastructureEconomyData (fonte única dos números,
## §91 do pedido) e a auditoria de conexão das 18 pesquisas de Infraestrutura (§92). Os prédios em
## si (construção/yield real) ficam em test_v2_economy_buildings.gd; o runtime/turno fica em
## test_v2_economy_turn.gd.

# --- §91: dado central --------------------------------------------------------------------------

func test_base_yields_per_city_match_the_documented_baseline():
	assert_eq(V2InfrastructureEconomyData.BASE_GOLD_PER_CITY, 2.0)
	assert_eq(V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY, 4.0)
	assert_eq(V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY, 4.0)
	assert_eq(V2InfrastructureEconomyData.BASE_KNOWLEDGE_PER_CITY, 2.0)
	assert_eq(V2InfrastructureEconomyData.BASE_MANA_PER_CITY, 1.0)

func test_the_five_buildings_have_the_documented_ids_resources_and_costs():
	assert_eq(V2InfrastructureEconomyData.building_id_for_branch("economy"), "v2_building_market")
	assert_eq(V2InfrastructureEconomyData.resource_for_building("v2_building_market"), "gold")
	assert_eq(V2InfrastructureEconomyData.production_cost_for_branch("economy"), 20.0)

	assert_eq(V2InfrastructureEconomyData.building_id_for_branch("logistics"), "v2_building_farm")
	assert_eq(V2InfrastructureEconomyData.resource_for_building("v2_building_farm"), "supply")
	assert_eq(V2InfrastructureEconomyData.production_cost_for_branch("logistics"), 20.0)

	assert_eq(V2InfrastructureEconomyData.building_id_for_branch("industry"), "v2_building_workshop")
	assert_eq(V2InfrastructureEconomyData.resource_for_building("v2_building_workshop"), "production")
	assert_eq(V2InfrastructureEconomyData.production_cost_for_branch("industry"), 24.0)

	assert_eq(V2InfrastructureEconomyData.building_id_for_branch("academy"), "v2_building_academy")
	assert_eq(V2InfrastructureEconomyData.resource_for_building("v2_building_academy"), "knowledge")
	assert_eq(V2InfrastructureEconomyData.production_cost_for_branch("academy"), 24.0)

	assert_eq(V2InfrastructureEconomyData.building_id_for_branch("arcane"), "v2_building_arcane_shrine")
	assert_eq(V2InfrastructureEconomyData.resource_for_building("v2_building_arcane_shrine"), "mana")
	assert_eq(V2InfrastructureEconomyData.production_cost_for_branch("arcane"), 24.0)

func test_yields_per_copy_match_the_documented_baseline():
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_market", 1), 4.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_market", 2), 6.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_market", 3), 8.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_farm", 1), 4.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_farm", 2), 6.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_farm", 3), 8.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_workshop", 1), 2.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_workshop", 2), 3.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_workshop", 3), 4.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", 1), 3.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", 2), 4.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", 3), 5.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_arcane_shrine", 1), 2.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_arcane_shrine", 2), 3.0)
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_arcane_shrine", 3), 4.0)

func test_yield_per_copy_clamps_out_of_range_tiers():
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_market", 0), 4.0, "tier 0 grampeia em 1")
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("v2_building_market", 99), 8.0, "tier alto grampeia em 3")
	assert_eq(V2InfrastructureEconomyData.yield_per_copy("not_a_building", 1), 0.0)

func test_unlock_ids_match_the_exact_documented_strings():
	assert_eq(V2InfrastructureEconomyData.unlock_ids_for_branch("economy"), ["v2_building_market", "v2_market_efficiency_2", "v2_market_efficiency_3"])
	assert_eq(V2InfrastructureEconomyData.unlock_ids_for_branch("logistics"), ["v2_building_farm", "v2_farm_efficiency_2", "v2_farm_efficiency_3"])
	assert_eq(V2InfrastructureEconomyData.unlock_ids_for_branch("industry"), ["v2_building_workshop", "v2_workshop_efficiency_2", "v2_workshop_efficiency_3"])
	assert_eq(V2InfrastructureEconomyData.unlock_ids_for_branch("academy"), ["v2_building_academy", "v2_academy_efficiency_2", "v2_academy_efficiency_3"])
	assert_eq(V2InfrastructureEconomyData.unlock_ids_for_branch("arcane"), ["v2_building_arcane_shrine", "v2_arcane_shrine_efficiency_2", "v2_arcane_shrine_efficiency_3"])

func test_branch_and_tier_for_unlock_round_trips():
	assert_eq(V2InfrastructureEconomyData.branch_and_tier_for_unlock("v2_market_efficiency_2"), ["economy", 2])
	assert_eq(V2InfrastructureEconomyData.branch_and_tier_for_unlock("v2_building_farm"), ["logistics", 1])
	assert_eq(V2InfrastructureEconomyData.branch_and_tier_for_unlock("v2_arcane_shrine_efficiency_3"), ["arcane", 3])
	assert_eq(V2InfrastructureEconomyData.branch_and_tier_for_unlock("not_an_id"), ["", 0])

func test_five_branches_no_more_no_less():
	var branches := V2InfrastructureEconomyData.branches()
	assert_eq(branches.size(), 5)
	for expected in ["economy", "logistics", "industry", "academy", "arcane"]:
		assert_true(expected in branches, expected)
	assert_false(V2InfrastructureEconomyData.has_branch("urbanization"), "Urbanização não é econômica -- não vive nesta tabela")

func test_all_unlock_ids_totals_fifteen():
	assert_eq(V2InfrastructureEconomyData.all_unlock_ids().size(), 15)

# --- §92: as 18 pesquisas de Infraestrutura ficam conectadas -------------------------------------

func _all_infrastructure_nodes() -> Array:
	var nodes: Array = []
	for branch in ["economy", "logistics", "industry", "academy", "arcane", "urbanization"]:
		nodes.append_array(V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, branch))
	return nodes

func test_all_eighteen_infrastructure_nodes_are_gameplay_connected():
	var infra_nodes := _all_infrastructure_nodes()
	assert_eq(infra_nodes.size(), 18)
	for node in infra_nodes:
		assert_true(node.gameplay_connected, "%s deveria estar conectado" % node.id)
		assert_false(node.is_placeholder, node.id)

func test_unlock_type_distribution_matches_the_spec():
	var buildings := 0
	var upgrades := 0
	var city_levels := 0
	for node in _all_infrastructure_nodes():
		match node.unlock_type:
			"building": buildings += 1
			"infrastructure_upgrade": upgrades += 1
			"city_level": city_levels += 1
	assert_eq(buildings, 5, "um N1 'building' por linha econômica")
	assert_eq(upgrades, 10, "N2+N3 'infrastructure_upgrade' por linha econômica (5 linhas x 2)")
	assert_eq(city_levels, 3, "as 3 pesquisas de Urbanização continuam city_level")

func test_economy_nodes_use_the_exact_unlock_ids():
	var n1 := V2ResearchDatabase.get_node("v2_infrastructure_economy_1")
	var n2 := V2ResearchDatabase.get_node("v2_infrastructure_economy_2")
	var n3 := V2ResearchDatabase.get_node("v2_infrastructure_economy_3")
	assert_eq(n1.unlock_id, "v2_building_market")
	assert_eq(n2.unlock_id, "v2_market_efficiency_2")
	assert_eq(n3.unlock_id, "v2_market_efficiency_3")
	assert_eq(n1.unlock_type, "building")
	assert_eq(n2.unlock_type, "infrastructure_upgrade")
	assert_eq(n3.unlock_type, "infrastructure_upgrade")

func test_no_tooltip_says_gameplay_not_connected_for_any_infrastructure_node():
	for node in _all_infrastructure_nodes():
		var tooltip := V2ResearchDatabase.node_tooltip(node)
		assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), "%s: %s" % [node.id, tooltip])

func test_unlock_effect_text_has_the_real_numbers_for_n1_and_n2():
	var n1 := V2ResearchDatabase.get_node("v2_infrastructure_economy_1")
	var text1 := V2ResearchDatabase.unlock_effect_text(n1)
	assert_true(text1.contains("Mercado"), text1)
	assert_true(text1.contains("4"), text1)
	var n2 := V2ResearchDatabase.get_node("v2_infrastructure_economy_2")
	var text2 := V2ResearchDatabase.unlock_effect_text(n2)
	assert_true(text2.contains("6"), text2)

func test_logistics_tooltip_clarifies_capacity_not_stock():
	var n1 := V2ResearchDatabase.get_node("v2_infrastructure_logistics_1")
	var text := V2ResearchDatabase.unlock_effect_text(n1)
	assert_true(text.contains("capacidade"), text)
	assert_true(text.contains("não é") or text.contains("não estoque") or text.contains("nunca"), text)

## Aetherlands V2, Fase 15 — a Oficina passou a treinar o Construtor de verdade (§53 do pedido);
## a descrição da N1 de Indústria (Fase 14) já prometia isso, e agora a promessa está cumprida.
func test_industry_n1_description_mentions_the_builder_which_the_workshop_now_trains():
	var n1 := V2ResearchDatabase.get_node("v2_infrastructure_industry_1")
	assert_true(n1.description.contains("Construtor"), n1.description)
	assert_eq(BuildingDatabase.get_building("v2_building_workshop").trains_unit, "v2_unit_builder", "Oficina treina o Construtor")
	assert_eq(BuildingDatabase.building_that_trains("v2_unit_builder"), BuildingDatabase.get_building("v2_building_workshop"), "só a Oficina treina o Construtor")

func test_no_infrastructure_unlock_id_collides_with_a_doctrine_or_magic_id():
	var seen := {}
	for node in _all_infrastructure_nodes():
		assert_false(seen.has(node.unlock_id), node.unlock_id)
		seen[node.unlock_id] = true

# --- Anti-hardcode -------------------------------------------------------------------------------

## Mesma convenção das varreduras anti-hardcode já usadas desde a Fase 7 (ver
## test_v2_doctrine_framework_reuse.gd/v2_combat_fixture._code_only): remove tudo depois de "#" em
## cada linha antes de procurar, pra um COMENTÁRIO explicando a regra (como o desta própria função,
## que cita os ids como exemplo do que NÃO fazer) não disparar um falso positivo.
func _code_only(source: String) -> String:
	var lines: Array[String] = []
	for line in source.split("\n"):
		var index := line.find("#")
		lines.append(line if index < 0 else line.substr(0, index))
	return "\n".join(lines)

func test_v2_economy_runtime_source_has_no_literal_building_ids_besides_the_database():
	var source := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2EconomyRuntime.gd"))
	for bad in ["v2_building_market", "v2_building_farm", "v2_building_workshop", "v2_building_academy", "v2_building_arcane_shrine"]:
		assert_false(source.contains(bad), "V2EconomyRuntime não deveria citar %s -- deve vir de V2InfrastructureEconomyData" % bad)
