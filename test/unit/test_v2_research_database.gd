extends GutTest

## Invariantes ESTRUTURAIS das três árvores V2 (Fase 0, scaffold) — ver
## docs/AETHERLANDS_V2_IMPLEMENTATION.md. Nenhum teste de gameplay: os nós V2
## ainda não desbloqueiam nada, não entram no fluxo de pesquisa V1 e não são
## salvos.

const DOCTRINE_BRANCH_IDS := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]
const MAGIC_BRANCH_IDS := ["sacred", "infernal", "necromancy", "druidism", "arcanism", "elementalism"]
const INFRASTRUCTURE_BRANCH_IDS := ["economy", "logistics", "industry", "academy", "arcane", "urbanization"]

const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL
const INFRASTRUCTURE := V2ResearchNode.TreeType.INFRASTRUCTURE

func _branch_ids(tree_type: int) -> Array:
	return V2ResearchDatabase.branches_for_tree(tree_type).map(func(b): return b.id)

func _complete_branch(tree_type: int, branch: String, completed: Dictionary) -> void:
	for node in V2ResearchDatabase.nodes_for_branch(tree_type, branch):
		completed[node.id] = true

# --- Doutrinas ---------------------------------------------------------------

func test_doctrine_tree_has_six_branches_of_nine_nodes_plus_supreme_army():
	assert_eq(_branch_ids(MILITARY), DOCTRINE_BRANCH_IDS)
	var normal := 0
	for branch in DOCTRINE_BRANCH_IDS:
		var nodes := V2ResearchDatabase.nodes_for_branch(MILITARY, branch)
		assert_eq(nodes.size(), 9, "%s deveria ter 9 níveis" % branch)
		normal += nodes.size()
	assert_eq(normal, 54)
	assert_eq(V2ResearchDatabase.nodes_for_tree(MILITARY).size(), 55, "6 x 9 + Exército Supremo")
	assert_eq(V2ResearchDatabase.nodes_for_branch(MILITARY, V2ResearchNode.UNIVERSAL_BRANCH).size(), 1)

func test_doctrine_tier_roles_are_the_fixed_design_roles_in_every_branch():
	var expected := ["doctrine_unlock", "training_structure", "base_unit", "technique_1", "evolution_1", "technique_2", "elite_form", "mastery_structure", "legendary_candidate"]
	for branch in DOCTRINE_BRANCH_IDS:
		var nodes := V2ResearchDatabase.nodes_for_branch(MILITARY, branch)
		for i in range(9):
			assert_eq(nodes[i].tier, i + 1)
			assert_eq(nodes[i].tier_role, expected[i], "%s N%d" % [branch, i + 1])
			assert_eq(nodes[i].id, "v2_doctrine_%s_%d" % [branch, i + 1])

## Fase 2: as Doutrinas têm nomes canônicos (o conteúdo completo é coberto por
## test_v2_doctrine_content.gd); aqui só a amostra estrutural.
func test_doctrine_display_names_are_canonical_not_line_plus_numeral():
	var guardian := V2ResearchDatabase.nodes_for_branch(MILITARY, "guardian")
	assert_eq(guardian.map(func(n): return n.display_name), ["Doutrina do Guardião", "Salão dos Guardiões", "Escudeiro", "Muralha de Escudos", "Guardião", "Preparar Lanças", "Sentinela", "Bastião de Maestria", "Campeão Guardião"])
	assert_eq(V2ResearchDatabase.get_node("v2_doctrine_siege_1").display_name, "Doutrina de Cerco")

# --- Magia ---------------------------------------------------------------------

func test_magic_tree_has_six_schools_of_nine_nodes_plus_transcendence():
	assert_eq(_branch_ids(MAGIC), MAGIC_BRANCH_IDS)
	for branch in MAGIC_BRANCH_IDS:
		assert_eq(V2ResearchDatabase.nodes_for_branch(MAGIC, branch).size(), 9, "%s deveria ter 9 níveis" % branch)
	assert_eq(V2ResearchDatabase.nodes_for_tree(MAGIC).size(), 55, "6 x 9 + Transcendência")

func test_magic_tier_roles_are_the_fixed_design_roles_in_every_school():
	var expected := ["school_unlock", "school_building", "caster", "basic_spell", "intermediate_spell", "advanced_spell", "greater_spell", "ritual_structure", "grand_manifestation"]
	for branch in MAGIC_BRANCH_IDS:
		var nodes := V2ResearchDatabase.nodes_for_branch(MAGIC, branch)
		for i in range(9):
			assert_eq(nodes[i].tier_role, expected[i], "%s N%d" % [branch, i + 1])
			assert_eq(nodes[i].id, "v2_magic_%s_%d" % [branch, i + 1])

func test_each_school_keeps_its_conceptual_function_in_metadata():
	var expected := {
		"sacred": "sustain", "infernal": "magical_damage", "necromancy": "undead_summoning",
		"druidism": "terrain_manipulation", "arcanism": "mobility_utility", "elementalism": "environmental_control",
	}
	for branch in expected:
		for node in V2ResearchDatabase.nodes_for_branch(MAGIC, branch):
			assert_eq(node.branch_role, expected[branch], node.id)

# --- Infraestrutura ---------------------------------------------------------------

func test_infrastructure_scaffold_has_six_branches_of_three_levels():
	assert_eq(_branch_ids(INFRASTRUCTURE), INFRASTRUCTURE_BRANCH_IDS)
	for branch in INFRASTRUCTURE_BRANCH_IDS:
		var nodes := V2ResearchDatabase.nodes_for_branch(INFRASTRUCTURE, branch)
		assert_eq(nodes.size(), 3, branch)
		for i in range(3):
			assert_eq(nodes[i].id, "v2_infrastructure_%s_%d" % [branch, i + 1])
	assert_eq(V2ResearchDatabase.nodes_for_tree(INFRASTRUCTURE).size(), 18)
	assert_null(V2ResearchDatabase.capstone_for_tree(INFRASTRUCTURE), "Infraestrutura não tem vitória nem capstone")

func test_each_infrastructure_line_points_at_its_future_system():
	var expected := {
		"economy": "gold", "logistics": "supplies", "industry": "production",
		"academy": "knowledge", "arcane": "mana", "urbanization": "city_fortification",
	}
	for branch in expected:
		for node in V2ResearchDatabase.nodes_for_branch(INFRASTRUCTURE, branch):
			assert_eq(node.branch_role, expected[branch], node.id)

## Fase 13: a Infraestrutura trocou o rótulo estrutural "Linha X" pelo conteúdo canônico
## (V2InfrastructureContent) -- os nomes reais não seguem mais o padrão de numeral romano.
func test_infrastructure_names_are_canonical_since_phase_13():
	assert_eq(V2ResearchDatabase.nodes_for_branch(INFRASTRUCTURE, "economy").map(func(n): return n.display_name), ["Mercados Locais", "Contabilidade", "Rede Mercantil"])

# --- IDs ---------------------------------------------------------------------------

func test_total_node_count_and_unique_prefixed_ids():
	var all := V2ResearchDatabase.all_nodes()
	assert_eq(all.size(), 128, "55 + 55 + 18")
	var seen := {}
	for node in all:
		assert_true(node.id.begins_with("v2_"), node.id)
		assert_true(V2ResearchDatabase.is_v2_id(node.id))
		assert_false(seen.has(node.id), "id duplicado: %s" % node.id)
		seen[node.id] = true
		assert_same(V2ResearchDatabase.get_node(node.id), node, "get_node devolve o mesmo nó")

func test_legacy_and_unknown_ids_are_not_research_nodes():
	assert_null(V2ResearchDatabase.get_node("guarda"), "id V1 não existe no banco V2")
	assert_null(V2ResearchDatabase.get_node("v2_doctrine_guardian_10"))

# --- Pré-requisitos ------------------------------------------------------------------

func test_every_branch_is_a_strict_linear_chain():
	var trees := {MILITARY: DOCTRINE_BRANCH_IDS, MAGIC: MAGIC_BRANCH_IDS, INFRASTRUCTURE: INFRASTRUCTURE_BRANCH_IDS}
	for tree_type in trees:
		for branch in trees[tree_type]:
			var nodes := V2ResearchDatabase.nodes_for_branch(tree_type, branch)
			assert_true(nodes[0].prerequisites.is_empty(), "%s: o primeiro nível não exige nada" % branch)
			for i in range(1, nodes.size()):
				assert_eq(nodes[i].prerequisites, [nodes[i - 1].id], "%s N%d exige N%d" % [branch, i + 1, i])

func test_prerequisites_always_reference_existing_nodes_of_the_same_branch():
	for node in V2ResearchDatabase.all_nodes():
		for prerequisite in node.prerequisites:
			var required := V2ResearchDatabase.get_node(prerequisite)
			assert_not_null(required, "%s exige um nó inexistente: %s" % [node.id, prerequisite])
			assert_eq(required.branch, node.branch)
			assert_eq(required.tree_type, node.tree_type)

# --- Custos provisórios -----------------------------------------------------------------

func test_balanced_costs_follow_the_central_table():
	var branch_costs := [8, 16, 24, 28, 40, 80, 128, 196, 268]
	for tree_type in [MILITARY, MAGIC]:
		for info in V2ResearchDatabase.branches_for_tree(tree_type):
			var nodes := V2ResearchDatabase.nodes_for_branch(tree_type, info.id)
			for i in range(9):
				assert_eq(int(nodes[i].cost), branch_costs[i], "%s N%d" % [info.id, i + 1])
	for info in V2ResearchDatabase.branches_for_tree(INFRASTRUCTURE):
		var nodes := V2ResearchDatabase.nodes_for_branch(INFRASTRUCTURE, info.id)
		assert_eq(nodes.map(func(n): return int(n.cost)), [16, 48, 120], info.id)

# --- Metadata de unlock (só dados: nada é desbloqueado) -----------------------------------

## Magia segue placeholder estrutural. Doutrinas Militares (Fase 2) e Infraestrutura (Fases 13-14)
## ganharam conteúdo canônico -- Fase 14: TODA a Infraestrutura passou a alterar gameplay (18/18,
## ver test_v2_economy_data.gd), não só Urbanização.
func test_connected_trees_and_two_magic_schools_are_canonical():
	for node in V2ResearchDatabase.all_nodes():
		assert_ne(node.tier_role, "", node.id)
		var is_infrastructure := node.tree_type == V2ResearchNode.TreeType.INFRASTRUCTURE
		var is_urbanization := is_infrastructure and node.branch == "urbanization"
		if not is_infrastructure:
			assert_eq(node.unlock_type, V2ResearchDatabase.TIER_ROLE_UNLOCK_TYPES[node.tier_role], node.id)
		elif is_urbanization:
			assert_eq(node.unlock_type, "city_level", "%s: Urbanização troca o tipo estrutural" % node.id)
		else:
			# Fase 14: as cinco linhas econômicas -- N1 vira "building", N2/N3 "infrastructure_upgrade" (§66).
			var expected_type := "building" if node.tier == 1 else "infrastructure_upgrade"
			assert_eq(node.unlock_type, expected_type, node.id)
		# Fase 3-11: as SEIS Doutrinas Militares (Guardião, Guerreiro, Patrulheiro, Cavalaria, Ladino e Cerco, N1-N9) estão ligadas ao gameplay.
		# Fase 12: o capstone universal v2_supreme_army TAMBÉM está (acesso à via de Supremacia Militar).
		# Fase 13/14: a árvore de Infraestrutura INTEIRA TAMBÉM está (Urbanização desde a Fase 13, as cinco linhas econômicas desde a Fase 14).
		# Fase 23: as seis Escolas e a Transcendência estão conectadas.
		var is_connected_magic := node.tree_type == V2ResearchNode.TreeType.MAGIC_SCHOOL and node.branch in ["sacred", "infernal", "necromancy", "druidism", "arcanism", "elementalism"]
		var expected_connected: bool = (node.branch in ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"] and node.tree_type == V2ResearchNode.TreeType.MILITARY_DOCTRINE and node.id.begins_with("v2_doctrine_")) or node.id in ["v2_supreme_army", "v2_transcendence"] or is_infrastructure or is_connected_magic
		assert_eq(node.gameplay_connected, expected_connected, "%s: gameplay_connected inesperado" % node.id)
		var canonical := node.tree_type == MILITARY or is_infrastructure or is_connected_magic or node.id == "v2_transcendence"
		assert_eq(node.is_placeholder, not canonical, node.id)
		if canonical:
			assert_ne(node.unlock_id, "placeholder", node.id)
		else:
			assert_eq(node.unlock_id, "placeholder", node.id)
			assert_true(node.description.contains(V2ResearchDatabase.PLACEHOLDER_NOTICE), "%s deve avisar que ainda não está implementado" % node.id)

func test_elementalism_caster_node_is_canonical_and_connected():
	var node := V2ResearchDatabase.get_node("v2_magic_elementalism_3")
	assert_eq(node.unlock_type, "caster")
	assert_eq(node.display_name, "Elementalista")
	assert_eq(node.unlock_id, "v2_unit_elementalist")
	assert_true(node.gameplay_connected)
	assert_false(node.is_placeholder)

# --- Capstones ----------------------------------------------------------------------------------

func test_supreme_army_and_transcendence_are_universal_capstones():
	var army := V2ResearchDatabase.get_node("v2_supreme_army")
	assert_eq(army.tier_role, "military_victory_capstone")
	assert_eq(army.tree_type, MILITARY)
	assert_true(army.is_universal)
	assert_eq(army.branch, V2ResearchNode.UNIVERSAL_BRANCH)
	assert_same(V2ResearchDatabase.capstone_for_tree(MILITARY), army)
	var transcendence := V2ResearchDatabase.get_node("v2_transcendence")
	assert_eq(transcendence.tier_role, "magic_victory_capstone")
	assert_eq(transcendence.tree_type, MAGIC)
	assert_true(transcendence.is_universal)
	assert_same(V2ResearchDatabase.capstone_for_tree(MAGIC), transcendence)

func test_supreme_army_recognizes_the_two_completed_doctrines_rule():
	var army := V2ResearchDatabase.get_node("v2_supreme_army")
	assert_eq(army.requirement.branch_count, 2)
	assert_eq(army.requirement.at_tier, 9)
	assert_eq(army.requirement.tree_type, MILITARY)
	var completed := {}
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_supreme_army", completed))
	_complete_branch(MILITARY, "guardian", completed)
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_supreme_army", completed), "uma Doutrina não basta")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", completed), Vector2i(1, 2))
	_complete_branch(MILITARY, "cavalry", completed)
	assert_true(V2ResearchDatabase.capstone_requirement_met("v2_supreme_army", completed))
	assert_true(V2ResearchDatabase.is_available("v2_supreme_army", completed))

func test_transcendence_recognizes_the_two_completed_schools_rule():
	var completed := {}
	_complete_branch(MAGIC, "sacred", completed)
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_transcendence", completed))
	_complete_branch(MAGIC, "necromancy", completed)
	assert_true(V2ResearchDatabase.capstone_requirement_met("v2_transcendence", completed))

func test_capstone_rule_needs_n9_and_only_counts_its_own_tree():
	var completed := {}
	for branch in ["guardian", "warrior"]:
		_complete_branch(MILITARY, branch, completed)
		completed.erase("v2_doctrine_%s_9" % branch) # N8 concluído, N9 não
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_supreme_army", completed), "só o N9 completa a Doutrina")
	var magic_only := {}
	_complete_branch(MAGIC, "sacred", magic_only)
	_complete_branch(MAGIC, "infernal", magic_only)
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_supreme_army", magic_only), "Escolas não contam pro Exército Supremo")
	assert_true(V2ResearchDatabase.capstone_requirement_met("v2_transcendence", magic_only))

func test_capstone_helpers_ignore_non_capstone_nodes():
	assert_eq(V2ResearchDatabase.capstone_progress("v2_doctrine_guardian_1", {}), Vector2i.ZERO)
	assert_false(V2ResearchDatabase.capstone_requirement_met("v2_doctrine_guardian_1", {}))
	assert_false(V2ResearchDatabase.capstone_requirement_met("nao_existe", {}))

# --- Estados visuais ---------------------------------------------------------------------------------

func test_node_state_covers_locked_available_researching_and_completed():
	var completed := {"v2_doctrine_guardian_1": true}
	var states := V2ResearchDatabase.NodeState
	assert_eq(V2ResearchDatabase.node_state("v2_doctrine_guardian_1", completed), states.COMPLETED)
	assert_eq(V2ResearchDatabase.node_state("v2_doctrine_guardian_2", completed), states.AVAILABLE)
	assert_eq(V2ResearchDatabase.node_state("v2_doctrine_guardian_3", completed), states.LOCKED)
	assert_eq(V2ResearchDatabase.node_state("v2_doctrine_guardian_2", completed, "v2_doctrine_guardian_2"), states.RESEARCHING)
	assert_eq(V2ResearchDatabase.node_state("v2_doctrine_warrior_1", {}), states.AVAILABLE, "o N1 de toda linha começa disponível")
	assert_eq(V2ResearchDatabase.node_state("v2_supreme_army", {}), states.LOCKED)

# --- Consultas -----------------------------------------------------------------------------------------

func test_queries_return_independent_copies():
	var nodes := V2ResearchDatabase.nodes_for_tree(MILITARY)
	nodes.clear()
	assert_eq(V2ResearchDatabase.nodes_for_tree(MILITARY).size(), 55)
	var all := V2ResearchDatabase.all_nodes()
	all.clear()
	assert_eq(V2ResearchDatabase.all_nodes().size(), 128)

func test_tooltip_shows_name_branch_tier_role_cost_prerequisite_and_description():
	var tooltip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_3")).replace("\n", " ") # o texto longo quebra linha
	for fragment in ["Escudeiro", "Doutrina do Guardião · Nível 3", "Unidade-base", "Custo: %d" % int(V2ResearchDatabase.BRANCH_TIER_COSTS[2]), "Requer: Salão dos Guardiões", "Linha de evolução: [Escudeiro] → Guardião → Sentinela", "Desbloqueio: Unidade", "Desbloqueia Escudeiro. Requer Salão dos Guardiões para treinamento."]:
		assert_true(tooltip.contains(fragment), "tooltip sem '%s':\n%s" % [fragment, tooltip])
	assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), "N3 está conectado desde a Fase 3")

## Fase 3: N1-N3 mostram o unlock real; N4-N9 seguem avisando que o gameplay não existe.
func test_tooltip_unlock_line_of_connected_and_unconnected_guardian_nodes():
	var n1 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_1"))
	var n2 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_2"))
	assert_true(n1.contains("Desbloqueia a Doutrina do Guardião."), n1)
	assert_true(n2.contains("Desbloqueia Salão dos Guardiões."), n2)
	# Fase 4: N4 (técnica) e N5 (evolução) também mostram o unlock real.
	var n4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_4")).replace("\n", " ")
	var n5 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_5")).replace("\n", " ")
	assert_true(n4.contains("Desbloqueia Muralha de Escudos para unidades da Doutrina do Guardião."), n4)
	assert_true(n5.contains("Desbloqueia Guardião. Cidades com Salão dos Guardiões passam a treinar Guardião diretamente, e cada Escudeiro existente pode evoluir em cidades próprias."), n5)
	# Fase 5: N6 (técnica passiva) e N7 (forma Elite) também mostram o unlock real.
	var n6 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_6")).replace("\n", " ")
	var n7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_7")).replace("\n", " ")
	assert_true(n6.contains("Desbloqueia Preparar Lanças para unidades da Doutrina do Guardião."), n6)
	assert_true(n6.contains("ataques básicos das unidades da linha causam dano adicional contra unidades montadas"), n6)
	assert_true(n7.contains("Desbloqueia Sentinela. Cidades com Salão dos Guardiões passam a treinar Sentinela diretamente, e cada Guardião existente pode evoluir em cidades próprias."), n7)
	for text in [n4, n5, n6, n7]:
		assert_false(text.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))
		assert_false(text.contains("Desbloqueio futuro"))
	# Fase 6: N8 (estrutura de Maestria) e N9 (candidato Lendário) também mostram o unlock real.
	var n8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_8")).replace("\n", " ")
	var n9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_guardian_9")).replace("\n", " ")
	assert_true(n8.contains("Desbloqueia Bastião de Maestria. Requer Salão dos Guardiões e permite treinar o Campeão Guardião após sua pesquisa."), n8)
	assert_true(n9.contains("Desbloqueia Campeão Guardião, a Unidade Lendária da Doutrina. Treinamento em Bastião de Maestria; cada civilização só pode ter uma Unidade Lendária ativa ou em treinamento."), n9)
	for text in [n8, n9]:
		assert_false(text.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))
		assert_false(text.contains("Desbloqueio futuro"))
	# Fase 11: a Doutrina de Cerco (última das seis) também mostra o unlock real.
	var s1 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_1"))
	var s9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_9")).replace("\n", " ")
	assert_true(s1.contains("Desbloqueia a Doutrina de Cerco."), s1)
	assert_true(s9.contains("Desbloqueia Colosso de Cerco, a Unidade Lendária da Doutrina. Treinamento em Grande Arsenal;"), s9)
	assert_false(s1.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))
	assert_false(s9.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))
	# Fase 22: as seis Escolas também exibem seus desbloqueios reais; nenhum nó normal
	# de Doutrina, Magia ou Infraestrutura continua placeholder.
	var elementalism := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_magic_elementalism_1"))
	assert_true(elementalism.contains("Desbloqueia a Escola do Elementalismo."), elementalism)
	assert_false(elementalism.contains(V2ResearchDatabase.PLACEHOLDER_NOTICE))
	assert_false(elementalism.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))

func test_tooltip_of_first_level_and_capstone_explain_their_requirement():
	assert_true(V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_magic_sacred_1")).contains("Requer: nenhum"))
	var army := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_supreme_army"))
	assert_true(army.contains("Nó universal"))
	assert_true(army.contains("Requer: 2 Doutrinas completas (N9)"))
	assert_true(V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_transcendence")).contains("Requer: 2 Escolas completas (N9)"))
