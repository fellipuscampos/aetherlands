extends GutTest

## Fase 2: conteúdo canônico das Doutrinas Militares V2 — nomes, descrições,
## unlock_type/unlock_id, técnicas, evolução e candidatos a Lendário. É só DADO:
## nenhum teste aqui exercita gameplay, porque nenhum nó altera o jogo.

const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const LINES := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]

const ROLES := ["doctrine_unlock", "training_structure", "base_unit", "technique_1", "evolution_1", "technique_2", "elite_form", "mastery_structure", "legendary_candidate"]
const TYPES := ["doctrine", "building", "unit", "technique", "unit_upgrade", "technique", "unit_upgrade", "mastery_building", "legendary_candidate"]

## Nome canônico e unlock_id de cada tier, por linha (N1..N9) — a tabela do pedido.
const CANON := {
	"guardian": [
		["Doutrina do Guardião", "v2_doctrine_guardian"], ["Salão dos Guardiões", "v2_building_guardian_hall"],
		["Escudeiro", "v2_unit_shieldbearer"], ["Muralha de Escudos", "v2_technique_shield_wall"],
		["Guardião", "v2_unit_guardian"], ["Preparar Lanças", "v2_technique_brace_spears"],
		["Sentinela", "v2_unit_sentinel"], ["Bastião de Maestria", "v2_building_guardian_mastery"],
		["Campeão Guardião", "v2_legendary_guardian_champion"]],
	"warrior": [
		["Doutrina do Guerreiro", "v2_doctrine_warrior"], ["Salão de Armas", "v2_building_warrior_hall"],
		["Guerreiro", "v2_unit_warrior"], ["Golpe Poderoso", "v2_technique_power_strike"],
		["Espadachim", "v2_unit_swordsman"], ["Ataque em Arco", "v2_technique_cleave"],
		["Mestre de Armas", "v2_unit_weapon_master"], ["Arena dos Campeões", "v2_building_warrior_mastery"],
		["Herói da Lâmina", "v2_legendary_blade_hero"]],
	"ranger": [
		["Doutrina do Patrulheiro", "v2_doctrine_ranger"], ["Campo dos Patrulheiros", "v2_building_ranger_camp"],
		["Arqueiro", "v2_unit_archer"], ["Disparo Preciso", "v2_technique_precise_shot"],
		["Caçador", "v2_unit_hunter"], ["Saraivada", "v2_technique_volley"],
		["Atirador de Elite", "v2_unit_elite_marksman"], ["Torre dos Patrulheiros", "v2_building_ranger_mastery"],
		["Caçador de Lendas", "v2_legendary_legend_hunter"]],
	"cavalry": [
		["Doutrina da Cavalaria", "v2_doctrine_cavalry"], ["Estábulo de Guerra", "v2_building_war_stable"],
		["Cavaleiro", "v2_unit_cavalier"], ["Carga", "v2_technique_charge"],
		["Cavaleiro de Choque", "v2_unit_shock_cavalier"], ["Retirada Tática", "v2_technique_tactical_retreat"],
		["Cavaleiro Blindado", "v2_unit_armored_cavalier"], ["Ordem da Cavalaria", "v2_building_cavalry_mastery"],
		["Cavaleiro de Grifo", "v2_legendary_griffon_rider"]],
	"rogue": [
		["Doutrina do Ladino", "v2_doctrine_rogue"], ["Guilda dos Ladinos", "v2_building_rogue_guild"],
		["Ladino", "v2_unit_rogue"], ["Ataque Furtivo", "v2_technique_sneak_attack"],
		["Sabotador", "v2_unit_saboteur"], ["Desmantelar", "v2_technique_dismantle"],
		["Assassino", "v2_unit_assassin"], ["Refúgio das Sombras", "v2_building_rogue_mastery"],
		["Mestre das Sombras", "v2_legendary_shadow_master"]],
	"siege": [
		["Doutrina de Cerco", "v2_doctrine_siege"], ["Arsenal de Cerco", "v2_building_siege_arsenal"],
		["Catapulta", "v2_unit_catapult"], ["Munição Demolidora", "v2_technique_demolition_ammo"],
		["Trebuchet", "v2_unit_trebuchet"], ["Bombardeio Preparado", "v2_technique_prepared_bombardment"],
		["Bombarda", "v2_unit_bombard"], ["Grande Arsenal", "v2_building_grand_arsenal"],
		["Colosso de Cerco", "v2_legendary_siege_colossus"]],
}

func _nodes(line: String) -> Array[V2ResearchNode]:
	return V2ResearchDatabase.nodes_for_branch(MILITARY, line)

# --- Estrutura preservada -----------------------------------------------------------------

func test_military_tree_keeps_its_55_nodes_research_ids_and_tier_roles():
	assert_eq(V2ResearchDatabase.nodes_for_tree(MILITARY).size(), 55)
	for line in LINES:
		var nodes := _nodes(line)
		assert_eq(nodes.size(), 9, line)
		for i in range(9):
			assert_eq(nodes[i].id, "v2_doctrine_%s_%d" % [line, i + 1], "o id de PESQUISA não muda")
			assert_eq(nodes[i].tier, i + 1)
			assert_eq(nodes[i].tier_role, ROLES[i], "%s N%d: tier_role preservado" % [line, i + 1])
	assert_not_null(V2ResearchDatabase.get_node("v2_supreme_army"))

func test_research_costs_follow_the_phase27_balanced_curve():
	for line in LINES:
		assert_eq(_nodes(line).map(func(n): return int(n.cost)), [8, 16, 24, 28, 40, 80, 128, 196, 268], line)
	assert_eq(int(V2ResearchDatabase.get_node("v2_supreme_army").cost), 400)

func test_prerequisites_are_unchanged_linear_chains():
	for line in LINES:
		var nodes := _nodes(line)
		assert_true(nodes[0].prerequisites.is_empty())
		for i in range(1, 9):
			assert_eq(nodes[i].prerequisites, [nodes[i - 1].id])

# --- Nomes canônicos ------------------------------------------------------------------------

func test_every_node_has_its_canonical_name():
	for line in LINES:
		var nodes := _nodes(line)
		for i in range(9):
			assert_eq(nodes[i].display_name, CANON[line][i][0], "%s N%d" % [line, i + 1])

func test_no_normal_doctrine_node_is_still_named_line_plus_numeral():
	var numeral := RegEx.create_from_string("\\s(I|II|III|IV|V|VI|VII|VIII|IX)$")
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		if node.is_universal:
			continue
		assert_null(numeral.search(node.display_name), "%s ainda é placeholder de numeral: %s" % [node.id, node.display_name])

func test_canonical_names_are_unique_within_the_tree():
	var seen := {}
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		assert_false(seen.has(node.display_name), "nome duplicado: %s" % node.display_name)
		seen[node.display_name] = true

# --- Descrição e função --------------------------------------------------------------------------

func test_every_node_has_a_description_and_an_intent_without_numbers():
	var digit := RegEx.create_from_string("(?<!N)[0-9]") # referências de nível ("N9") não são stats
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		assert_gt(node.description.length(), 20, "%s: descrição curta demais" % node.id)
		assert_ne(node.intent, "", "%s precisa de função pretendida" % node.id)
		assert_null(digit.search(node.description), "%s: sem números/stats na descrição" % node.id)
		assert_null(digit.search(node.intent), "%s: sem números/stats na função pretendida" % node.id)
		assert_false(node.description.contains(V2ResearchDatabase.PLACEHOLDER_NOTICE), "%s não é mais placeholder" % node.id)

func test_spec_example_descriptions_are_used_verbatim():
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_guardian_4").description, "Técnica defensiva da linha do Guardião: a unidade assume postura defensiva, melhora sua própria Defesa e protege aliados adjacentes temporariamente.")
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_rogue_6").description, "Técnica PASSIVA da linha do Ladino: treinamento contra alvos técnicos, com Ataque ampliado contra conjuradores e unidades de Cerco.")

func test_descriptions_state_the_role_in_the_composition():
	assert_true(V2ResearchDatabase.get_node("v2_doctrine_guardian_3").description.contains("frontline"))
	assert_true(V2ResearchDatabase.get_node("v2_doctrine_guardian_7").description.contains("Não é uma unidade de dano"), "Sentinela não é DPS")
	assert_true(V2ResearchDatabase.get_node("v2_doctrine_rogue_7").description.contains("Não deve vencer"), "Assassino perde no combate frontal")
	assert_true(V2ResearchDatabase.get_node("v2_doctrine_cavalry_6").description.contains("sem transformar a Cavalaria em tank"))
	assert_true(V2ResearchDatabase.get_node("v2_doctrine_ranger_6").description.contains("inferior"), "Saraivada < AoE mágico")

# --- unlock_type / unlock_id ----------------------------------------------------------------------------

func test_unlock_types_follow_the_canonical_vocabulary_by_tier():
	for line in LINES:
		var nodes := _nodes(line)
		for i in range(9):
			assert_eq(nodes[i].unlock_type, TYPES[i], "%s N%d" % [line, i + 1])

func test_unlock_ids_are_exactly_the_specified_ones():
	for line in LINES:
		var nodes := _nodes(line)
		for i in range(9):
			assert_eq(nodes[i].unlock_id, CANON[line][i][1], "%s N%d" % [line, i + 1])

func test_unlock_ids_are_unique_stable_v2_ids_and_never_research_or_v1_ids():
	var seen := {}
	var research_ids := {}
	for node in V2ResearchDatabase.all_nodes():
		research_ids[node.id] = true
	var prefix_by_type := {
		"doctrine": "v2_doctrine_", "building": "v2_building_", "mastery_building": "v2_building_",
		"unit": "v2_unit_", "unit_upgrade": "v2_unit_", "technique": "v2_technique_",
		"legendary_candidate": "v2_legendary_",
	}
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		assert_ne(node.unlock_id, "", node.id)
		assert_ne(node.unlock_id, "placeholder", node.id)
		assert_false(seen.has(node.unlock_id), "unlock_id duplicado: %s" % node.unlock_id)
		seen[node.unlock_id] = true
		assert_false(research_ids.has(node.unlock_id), "%s colide com um id de PESQUISA" % node.unlock_id)
		assert_true(V2ResearchDatabase.is_v2_id(node.unlock_id), node.unlock_id)
		if prefix_by_type.has(node.unlock_type):
			assert_true(node.unlock_id.begins_with(prefix_by_type[node.unlock_type]), "%s (%s) fora do prefixo esperado" % [node.unlock_id, node.unlock_type])
		# Nenhum id V1 (unidade, prédio, tecnologia) tem este id: nada vaza pro gameplay.
		# Fase 3: só os unlocks CONECTADOS (Guardião N1-N3) ganham objeto real nos
		# bancos de prédio/unidade — todo o resto continua sem existir no jogo.
		if node.unlock_id in V2DoctrineContent.CONNECTED_UNLOCK_IDS:
			continue
		assert_null(BuildingDatabase.get_building(node.unlock_id), node.unlock_id)
		assert_eq(UnitDatabase.create_unit(node.unlock_id).unit_name, "Unidade", "%s não pode existir no UnitDatabase V1 (cai no fallback)" % node.unlock_id)

func test_unlock_ids_resolve_back_to_their_research_node():
	for line in LINES:
		for node in _nodes(line):
			assert_same(V2ResearchDatabase.node_for_unlock_id(node.unlock_id), node)
	assert_null(V2ResearchDatabase.node_for_unlock_id("placeholder"))
	assert_null(V2ResearchDatabase.node_for_unlock_id("v2_unit_inexistente"))

# --- Candidatos a Lendário -------------------------------------------------------------------------------

func test_the_six_n9_nodes_are_legendary_candidates_and_only_them():
	var candidates := V2ResearchDatabase.legendary_candidates()
	assert_eq(candidates.size(), 6)
	for line in LINES:
		var n9 := _nodes(line)[8]
		assert_eq(n9.unlock_type, "legendary_candidate", line)
		assert_true(n9 in candidates)
		assert_true(n9.unlock_id.begins_with("v2_legendary_"))
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		if node.tier != 9:
			assert_ne(node.unlock_type, "legendary_candidate", node.id)

func test_the_one_active_legendary_rule_is_in_every_candidate_and_backed_by_the_global_system():
	assert_eq(V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS, 1)
	assert_eq(V2LegendarySystem.max_active(), V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS, "o sistema lê a constante global")
	for node in V2ResearchDatabase.legendary_candidates():
		assert_true(node.description.contains("só pode ter UMA Unidade Lendária ativa ou em treinamento por vez"), node.id)
		assert_true(V2LegendarySystem.is_legendary_kind(node.unlock_id), "%s é reconhecida pela metadata" % node.id)

# --- Técnicas ---------------------------------------------------------------------------------------------

func test_each_doctrine_has_exactly_two_techniques_at_n4_and_n6():
	var expected := {
		"guardian": ["Muralha de Escudos", "Preparar Lanças"], "warrior": ["Golpe Poderoso", "Ataque em Arco"],
		"ranger": ["Disparo Preciso", "Saraivada"], "cavalry": ["Carga", "Retirada Tática"],
		"rogue": ["Ataque Furtivo", "Desmantelar"], "siege": ["Munição Demolidora", "Bombardeio Preparado"],
	}
	var total := 0
	for line in LINES:
		var techniques := V2ResearchDatabase.techniques_for_branch(line)
		assert_eq(techniques.size(), 2, line)
		assert_eq(techniques.map(func(n): return n.display_name), expected[line], line)
		assert_eq(techniques.map(func(n): return n.tier), [4, 6])
		total += techniques.size()
	assert_eq(total, 12, "12 técnicas no total")

# --- Linha de evolução ------------------------------------------------------------------------------------

func test_each_doctrine_has_a_three_step_unit_line_with_consistent_links():
	var expected := {
		"guardian": ["Escudeiro", "Guardião", "Sentinela"], "warrior": ["Guerreiro", "Espadachim", "Mestre de Armas"],
		"ranger": ["Arqueiro", "Caçador", "Atirador de Elite"], "cavalry": ["Cavaleiro", "Cavaleiro de Choque", "Cavaleiro Blindado"],
		"rogue": ["Ladino", "Sabotador", "Assassino"], "siege": ["Catapulta", "Trebuchet", "Bombarda"],
	}
	for line in LINES:
		var chain := V2ResearchDatabase.unit_line(line)
		assert_eq(chain.map(func(n): return n.display_name), expected[line], line)
		assert_eq([chain[0].tier, chain[1].tier, chain[2].tier], [3, 5, 7])
		assert_eq(chain[0].upgrade_from, "", "a unidade-base não evolui de ninguém")
		assert_eq(chain[0].upgrade_to, chain[1].unlock_id)
		assert_eq(chain[1].upgrade_from, chain[0].unlock_id)
		assert_eq(chain[1].upgrade_to, chain[2].unlock_id)
		assert_eq(chain[2].upgrade_from, chain[1].unlock_id)
		assert_eq(chain[2].upgrade_to, "", "a Elite é o fim da linha")

func test_the_guardian_line_matches_the_specified_relations_exactly():
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_guardian_3").upgrade_to, "v2_unit_guardian")
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_guardian_5").upgrade_from, "v2_unit_shieldbearer")
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_guardian_5").upgrade_to, "v2_unit_sentinel")
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_guardian_7").upgrade_from, "v2_unit_guardian")

func test_only_the_three_unit_nodes_of_each_line_have_evolution_links():
	var linked := 0
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		if node.upgrade_from != "" or node.upgrade_to != "":
			linked += 1
			assert_true(node.tier_role in ["base_unit", "evolution_1", "elite_form"], "%s não é unidade convencional" % node.id)
			for link in [node.upgrade_from, node.upgrade_to]:
				if link != "":
					assert_not_null(V2ResearchDatabase.node_for_unlock_id(link), "link órfão: %s" % link)
	assert_eq(linked, 18, "6 linhas x 3 unidades")

# --- Exército Supremo ----------------------------------------------------------------------------------------

func test_supreme_army_is_a_strategic_capstone_not_a_unit():
	var army := V2ResearchDatabase.get_node("v2_supreme_army")
	assert_eq(army.unlock_type, "victory_capstone")
	assert_eq(army.unlock_id, "v2_military_supremacy_access")
	assert_eq(army.tier_role, "military_victory_capstone")
	assert_true(army.is_universal)
	assert_false(army.is_placeholder)
	assert_true(army.description.contains("O domínio completo de duas tradições militares permite à civilização reivindicar o ápice de sua doutrina de guerra."))
	assert_true(army.description.contains("Exército Supremo é requisito da futura Vitória por Supremacia Militar."))
	assert_true(army.description.contains("Não é uma unidade"))
	assert_eq(army.upgrade_from, "")
	assert_eq(army.upgrade_to, "")

func test_supreme_army_requirement_and_rule_are_unchanged():
	var army := V2ResearchDatabase.get_node("v2_supreme_army")
	assert_eq(army.requirement.branch_count, 2)
	assert_eq(army.requirement.at_tier, 9)
	assert_eq(army.requirement.tree_type, MILITARY)
	var state := V2ResearchState.new()
	state.debug_complete_branch(MILITARY, "guardian")
	assert_false(state.is_available("v2_supreme_army"))
	state.debug_complete_branch(MILITARY, "siege")
	assert_true(state.is_available("v2_supreme_army"))

# --- Nada de stats, nada de gameplay ------------------------------------------------------------------------------

func test_the_node_type_defines_no_combat_or_economy_numbers():
	var forbidden := ["hp", "max_hp", "attack", "defense", "movement", "movement_points", "range", "attack_range", "cooldown", "multiplier", "production_cost", "upkeep", "supply_cost"]
	var names: Array = V2ResearchNode.new().get_property_list().map(func(p): return p.name)
	for stat in forbidden:
		assert_false(stat in names, "V2ResearchNode não pode definir %s nesta fase" % stat)

## Fase 3-11: as SEIS Doutrinas Militares (Guardião, Guerreiro, Patrulheiro, Cavalaria, Ladino e Cerco, N1-N9 cada, completas) têm gameplay real.
## Fase 12: o Exército Supremo (capstone universal) TAMBÉM está conectado (acesso à via de Supremacia Militar).
## Fase 23: as seis Escolas e a Transcendência estão conectadas.
func test_the_six_military_doctrines_and_the_supreme_army_capstone_are_connected_to_gameplay():
	var connected: Array[String] = ["v2_supreme_army"]
	for line in ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]:
		for n in range(1, 10):
			connected.append("v2_doctrine_%s_%d" % [line, n])
	# Fase 13: a linha de Urbanização (Infraestrutura) também está conectada. Fase 14: as cinco
	# linhas econômicas de Infraestrutura também -- juntas, as exceções fora da árvore Militar
	# (ver test_v2_city_level.gd/test_v2_economy_data.gd pra cobertura dedicada).
	connected.append_array(["v2_infrastructure_urbanization_1", "v2_infrastructure_urbanization_2", "v2_infrastructure_urbanization_3"])
	for branch in ["economy", "logistics", "industry", "academy", "arcane"]:
		for n in range(1, 4):
			connected.append("v2_infrastructure_%s_%d" % [branch, n])
	# Fases 17-22: as seis Escolas de Magia (54 nós normais) também estão conectadas.
	for branch in ["sacred", "infernal", "necromancy", "druidism", "arcanism", "elementalism"]:
		for n in range(1, 10):
			connected.append("v2_magic_%s_%d" % [branch, n])
	# Fase 23: o capstone magico deixa de ser a unica excecao; os 128 nos estao conectados.
	connected.append("v2_transcendence")
	for node in V2ResearchDatabase.all_nodes():
		assert_eq(node.gameplay_connected, node.id in connected, node.id)

func test_completing_every_military_node_changes_nothing_outside_the_research_state():
	var player := PlayerData.new(CivilizationData.new())
	var v1_before := [player.units.size(), player.cities.size(), player.gold, player.mana]
	for line in LINES:
		player.v2_research.debug_complete_branch(MILITARY, line)
	player.v2_research.complete_research("v2_supreme_army")

	assert_eq(player.v2_research.completed_ids.size(), 55, "pesquisa V2 conclui normalmente")
	assert_eq([player.units.size(), player.cities.size(), player.gold, player.mana], v1_before)
	player.release_relations()

func test_magic_and_infrastructure_names_and_ids_are_canonical():
	assert_eq(V2ResearchDatabase.get_node("v2_magic_infernal_3").display_name, "Bruxo Infernal")
	assert_eq(V2ResearchDatabase.get_node("v2_magic_elementalism_9").display_name, "Primordial dos Elementos")
	# Infraestrutura e as seis Escolas já têm conteúdo canônico; o capstone mágico segue placeholder.
	assert_eq(V2ResearchDatabase.get_node("v2_infrastructure_economy_1").display_name, "Mercados Locais")
	assert_eq(V2ResearchDatabase.get_node("v2_transcendence").unlock_id, V2TranscendenceSystem.ACCESS_ID)
	assert_false(V2ResearchDatabase.get_node("v2_transcendence").is_placeholder)
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL).size(), 55)
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE).size(), 18)

# --- Runtime e saves da Fase 1 continuam valendo -------------------------------------------------------------------

## Bloco "v2_research" exatamente como a Fase 1 salvava (ids de PESQUISA, que não mudaram).
func test_a_phase_1_save_block_still_loads_with_the_canonical_content():
	var phase_1_block := {
		"active_id": "v2_doctrine_guardian_3",
		"completed_ids": ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2", "v2_magic_sacred_1"],
		"progress_by_id": {"v2_doctrine_guardian_3": 12.5, "v2_doctrine_warrior_1": 4.0},
		"research_overflow": 0.0,
	}
	var state := V2ResearchState.from_variant(JSON.parse_string(JSON.stringify(phase_1_block)))

	assert_eq(state.active_id, "v2_doctrine_guardian_3")
	assert_eq(V2ResearchDatabase.get_node(state.active_id).display_name, "Escudeiro", "o mesmo id agora tem o nome canônico")
	assert_eq(state.get_completed_ids(), ["v2_doctrine_guardian_1", "v2_doctrine_guardian_2", "v2_magic_sacred_1"])
	assert_almost_eq(state.get_progress("v2_doctrine_guardian_3"), 12.5, 0.001)
	assert_almost_eq(state.get_progress("v2_doctrine_warrior_1"), 4.0, 0.001)
	state.add_knowledge(17.5)
	assert_true(state.is_completed("v2_doctrine_guardian_3"), "12.5 + 17.5 = custo 30: continua de onde parou")

func test_the_research_runtime_works_on_canonical_nodes():
	var state := V2ResearchState.new()
	assert_true(state.select_research("v2_doctrine_guardian_1"))
	state.add_knowledge(10.0)
	assert_true(state.select_research("v2_doctrine_guardian_2"))
	state.add_knowledge(20.0)
	assert_true(state.select_research("v2_doctrine_guardian_3"))
	assert_eq(state.node_state("v2_doctrine_guardian_3"), V2ResearchDatabase.NodeState.RESEARCHING)
	assert_true(state.status_text("v2_doctrine_guardian_3").begins_with("Estado: Pesquisando"))
	assert_eq(state.unavailable_reason("v2_doctrine_guardian_4"), "Requer Escudeiro.")
	assert_eq(state.unavailable_reason("v2_doctrine_guardian_5"), "Requer Muralha de Escudos.")

# --- Tooltips ----------------------------------------------------------------------------------------------------

func test_tooltips_are_readable_and_carry_the_unlock_and_the_dev_notice_when_not_connected():
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		var tooltip := V2ResearchDatabase.node_tooltip(node)
		assert_true(tooltip.begins_with(node.display_name), node.id)
		# Fase 25: o tooltip de jogador mostra só o tipo do desbloqueio, nunca o id interno.
		var unlock_line := V2ResearchDatabase.unlock_type_label(node.unlock_type)
		assert_false(tooltip.contains(node.unlock_id), "id interno no tooltip de %s" % node.id)
		if node.gameplay_connected:
			# Fase 3: nó conectado mostra o unlock REAL, sem o aviso de "não conectado".
			assert_true(tooltip.contains("Desbloqueio: " + unlock_line), node.id)
			assert_false(tooltip.contains("Desbloqueio futuro"), node.id)
			assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), node.id)
		else:
			assert_true(tooltip.contains("Desbloqueio futuro: " + unlock_line), node.id)
			assert_true(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), node.id)
		assert_true(tooltip.contains(V2ResearchDatabase.role_label(node.tier_role)), node.id)
		for line in tooltip.split("\n"):
			assert_lt(line.length(), 90, "linha de tooltip longa demais em %s: %s" % [node.id, line])

func test_tooltip_of_a_unit_shows_the_evolution_line_and_the_doctrine_it_belongs_to():
	var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_ranger_5"))
	assert_true(tooltip.contains("Doutrina do Patrulheiro · Nível 5"))
	assert_true(tooltip.contains("Linha de evolução: Arqueiro → [Caçador] → Atirador de Elite"))
	assert_false(tooltip.contains("Requer: Saraivada"), "N5 exige o N4, não o N6")
	assert_true(tooltip.contains("Requer: Disparo Preciso"))
