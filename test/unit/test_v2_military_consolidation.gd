extends "res://test/unit/v2_combat_fixture.gd"

## Aetherlands V2, Fase 12 — consolidação da árvore militar completa: auditoria estrutural das
## seis Doutrinas (54 nós normais), totais finais, interações cruzadas entre Doutrinas, as seis
## Lendárias, um exército misto de seis funções coexistindo e a conclusão real das 54 pesquisas
## numa civilização de teste. Nenhuma Doutrina nova é criada; nenhum balanceamento é feito.

const BRANCHES := ["guardian", "warrior", "ranger", "cavalry", "rogue", "siege"]
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE

var _original_hex_grid: HexGrid

func before_each():
	super.before_each()
	_original_hex_grid = GameManager.hex_grid

func after_each():
	GameManager.hex_grid = _original_hex_grid
	super.after_each()

## branch -> {hall, mastery, base, evolution, elite, legend, techniques[2]}
const CATALOG := {
	"guardian": {"hall": "v2_building_guardian_hall", "mastery": "v2_building_guardian_mastery",
		"base": "v2_unit_shieldbearer", "evolution": "v2_unit_guardian", "elite": "v2_unit_sentinel",
		"legend": "v2_legendary_guardian_champion", "techniques": ["v2_technique_shield_wall", "v2_technique_brace_spears"]},
	"warrior": {"hall": "v2_building_warrior_hall", "mastery": "v2_building_warrior_mastery",
		"base": "v2_unit_warrior", "evolution": "v2_unit_swordsman", "elite": "v2_unit_weapon_master",
		"legend": "v2_legendary_blade_hero", "techniques": ["v2_technique_power_strike", "v2_technique_cleave"]},
	"ranger": {"hall": "v2_building_ranger_camp", "mastery": "v2_building_ranger_mastery",
		"base": "v2_unit_archer", "evolution": "v2_unit_hunter", "elite": "v2_unit_elite_marksman",
		"legend": "v2_legendary_legend_hunter", "techniques": ["v2_technique_precise_shot", "v2_technique_volley"]},
	"cavalry": {"hall": "v2_building_war_stable", "mastery": "v2_building_cavalry_mastery",
		"base": "v2_unit_cavalier", "evolution": "v2_unit_shock_cavalier", "elite": "v2_unit_armored_cavalier",
		"legend": "v2_legendary_griffon_rider", "techniques": ["v2_technique_charge", "v2_technique_tactical_retreat"]},
	"rogue": {"hall": "v2_building_rogue_guild", "mastery": "v2_building_rogue_mastery",
		"base": "v2_unit_rogue", "evolution": "v2_unit_saboteur", "elite": "v2_unit_assassin",
		"legend": "v2_legendary_shadow_master", "techniques": ["v2_technique_sneak_attack", "v2_technique_dismantle"]},
	"siege": {"hall": "v2_building_siege_arsenal", "mastery": "v2_building_grand_arsenal",
		"base": "v2_unit_catapult", "evolution": "v2_unit_trebuchet", "elite": "v2_unit_bombard",
		"legend": "v2_legendary_siege_colossus", "techniques": ["v2_technique_demolition_ammo", "v2_technique_prepared_bombardment"]},
}

# --- §29: auditoria estrutural das seis Doutrinas (9 nós cada, papéis fixos, linha, técnicas) -----

func test_each_of_the_six_branches_has_exactly_nine_nodes_with_the_fixed_tier_roles():
	var expected_roles := ["doctrine_unlock", "training_structure", "base_unit", "technique_1", "evolution_1", "technique_2", "elite_form", "mastery_structure", "legendary_candidate"]
	for branch in BRANCHES:
		var nodes := V2ResearchDatabase.nodes_for_branch(MILITARY, branch)
		assert_eq(nodes.size(), 9, branch)
		assert_eq(nodes.map(func(n): return n.tier_role), expected_roles, branch)
		assert_eq(nodes.map(func(n): return n.tier), [1, 2, 3, 4, 5, 6, 7, 8, 9], branch)

func test_n3_n5_n7_form_a_line_and_n9_belongs_to_the_branch_but_not_to_the_chain():
	for branch in BRANCHES:
		var c: Dictionary = CATALOG[branch]
		assert_eq(V2UnitLine.unit_ids(branch), [c.base, c.evolution, c.elite], branch)
		assert_false(V2UnitLine.is_line_unit(c.legend), "%s: Lendária fora da cadeia" % branch)
		assert_eq(V2UnitLine.doctrine_branch_of(c.legend), branch, "%s: mas pertence à Doutrina" % branch)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(c.legend).tier, 9)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(c.legend).branch, branch)

func test_each_branch_has_exactly_two_techniques_a_training_building_and_a_mastery_building():
	for branch in BRANCHES:
		var c: Dictionary = CATALOG[branch]
		assert_eq(V2ResearchDatabase.techniques_for_branch(branch).map(func(n): return n.unlock_id), c.techniques, branch)
		assert_not_null(BuildingDatabase.get_building(c.hall), "%s: prédio de treino existe" % branch)
		assert_not_null(BuildingDatabase.get_building(c.mastery), "%s: prédio de Maestria existe" % branch)
		assert_not_null(UnitDatabase.create_unit(c.legend), "%s: Lendária existe" % branch)

func test_gameplay_connected_covers_exactly_the_54_normal_nodes_plus_the_capstone():
	var connected := 0
	for node in V2ResearchDatabase.nodes_for_tree(MILITARY):
		if node.gameplay_connected:
			connected += 1
	assert_eq(connected, 55, "54 nós normais (6x9) + o capstone (Fase 12)")

func test_all_six_magic_schools_and_transcendence_are_connected():
	# Fase 14: TODA a Infraestrutura está conectada agora (18/18, ver test_v2_economy_data.gd) --
	# Magia inteira (e a Transcendência) continua a única árvore/capstone fora da Militar que
	# permanece inerte.
	# Fase 23: as seis Escolas e a Transcendência foram conectadas (ver test_v2_magic_content.gd).
	for node in V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.MAGIC_SCHOOL):
		if not node.is_universal:
			assert_true(node.gameplay_connected, node.id)
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)

func test_all_infrastructure_nodes_are_connected_since_phase_14():
	for node in V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE):
		assert_true(node.gameplay_connected, node.id)

# --- §48: totais finais da árvore militar ----------------------------------------------------------

func test_final_totals_of_the_military_tree():
	assert_eq(BRANCHES.size(), 6)
	assert_eq(V2ResearchDatabase.nodes_for_tree(MILITARY).size(), 55, "54 normais + 1 capstone")
	var techniques := 0
	var conventional_units := 0
	var legendaries := 0
	var halls := 0
	var masteries := 0
	for branch in BRANCHES:
		techniques += V2DoctrineTechniqueDatabase.for_branch(branch).size()
		conventional_units += V2UnitLine.unit_ids(branch).size()
		legendaries += 1
		halls += 1
		masteries += 1
	assert_eq(techniques, 12, "6 x 2")
	assert_eq(conventional_units, 18, "6 x 3 (N3/N5/N7)")
	assert_eq(legendaries, 6)
	assert_eq(conventional_units + legendaries, 24, "unidades V2 militares totais")
	assert_eq(halls + masteries, 12, "prédios militares V2 totais")
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55, "54 unlocks normais + o do capstone")

# --- §44: as seis Lendárias --------------------------------------------------------------------

func test_all_six_legendary_candidates_share_the_same_shape():
	for branch in BRANCHES:
		var c: Dictionary = CATALOG[branch]
		var node := V2ResearchDatabase.node_for_unlock_id(c.legend)
		assert_eq(node.unlock_type, "legendary_candidate", branch)
		assert_eq(node.branch, branch, branch)
		assert_true(V2LegendarySystem.is_legendary_kind(c.legend), branch)
		assert_true(UnitDatabase.create_unit(c.legend).has_trait(UnitData.TRAIT_LEGENDARY), branch)
		assert_eq(BuildingDatabase.building_that_trains(c.legend), BuildingDatabase.get_building(c.mastery), "%s: produção separada, no prédio de Maestria" % branch)
		assert_ne(BuildingDatabase.building_that_trains(c.legend), BuildingDatabase.get_building(c.hall), "%s: nunca no Salão" % branch)
		assert_false(V2UnitLine.is_line_unit(c.legend), "%s: fora da cadeia N3/N5/N7" % branch)

func test_the_six_legendaries_have_the_correct_role_via_v2unitline():
	const ROLES := {"guardian": "tank_frontline", "warrior": "melee_damage", "ranger": "ranged_combat", "cavalry": "mobility_shock", "rogue": "sabotage_assassination", "siege": "city_conquest"}
	for branch in BRANCHES:
		assert_eq(V2UnitLine.role_of(CATALOG[branch].legend), ROLES[branch], branch)

# --- §45: slot Lendário global -- qualquer uma das seis bloqueia as outras cinco -------------------

func test_any_of_the_six_active_legendaries_blocks_the_other_five_v2legendarysystem_untouched():
	var grid := _world(10)
	var player := _player(9, 9, 9, 9, 9, 9)
	var q := -9
	for active_branch in BRANCHES:
		var active := _unit(grid, player, CATALOG[active_branch].legend, Vector2i(q, 0))
		q += 1
		assert_true(V2LegendarySystem.has_active_legendary(player))
		for other_branch in BRANCHES:
			assert_false(V2LegendarySystem.spawn_allowed(player, CATALOG[other_branch].legend), "%s ativa bloqueia %s" % [active_branch, other_branch])
		grid.remove_unit(active)
		assert_true(V2LegendarySystem.spawn_allowed(player, CATALOG[active_branch].legend), "morta/removida -- slot livre de novo")

# --- §43: interações cruzadas entre Doutrinas (amostra pequena, não repete os testes unitários) ----

## Guardião x Cavalaria: Preparar Lanças (passiva do Guardião) reconhece o traço `mounted` de uma
## unidade REAL da Cavalaria (não uma fixture sintética) e só vale com o N6 pesquisado.
func test_brace_spears_guardian_recognizes_a_real_cavalry_unit_by_trait():
	var grid := _world()
	var guardian := _player(0, 6, 0, 0, 0, 0) # guarda o Guardião até N6 (Preparar Lanças)
	var attacker := _unit(grid, guardian, CATALOG.guardian.base, Vector2i(0, 0))
	var rival := _rival_of(guardian)
	var cavalier := _unit(grid, rival, CATALOG.cavalry.base, Vector2i(1, 0)) # Cavalaria REAL, sem precisar o rival tê-la pesquisado
	assert_true(cavalier.unit_data.has_trait(UnitData.TRAIT_MOUNTED))
	assert_almost_eq(UnitAbilities.attack_multiplier(attacker, cavalier), 1.5, 0.0001, "Preparar Lanças: +50% contra montado")

func test_brace_spears_does_nothing_without_the_n6_research_even_against_a_real_mounted_unit():
	var grid := _world()
	var guardian := _player(0, 5, 0, 0, 0, 0) # só até N5: sem Preparar Lanças
	var attacker := _unit(grid, guardian, CATALOG.guardian.evolution, Vector2i(0, 0))
	var rival := _rival_of(guardian)
	var cavalier := _unit(grid, rival, CATALOG.cavalry.base, Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(attacker, cavalier), 1.0, 0.0001)

## Ladino x Cerco: Desmantelar (passiva do Ladino) reconhece o traço `siege` de uma unidade REAL do Cerco.
func test_dismantle_rogue_recognizes_a_real_siege_unit_by_trait():
	var grid := _world()
	var rogue := _rogue_player(6) # N6: Desmantelar
	var attacker := _unit(grid, rogue, CATALOG.rogue.base, Vector2i(0, 0))
	var rival := _rival_of(rogue)
	var catapult := _unit(grid, rival, CATALOG.siege.base, Vector2i(1, 0))
	assert_true(catapult.unit_data.has_trait(UnitData.TRAIT_SIEGE))
	assert_almost_eq(UnitAbilities.attack_multiplier(attacker, catapult), 1.5, 0.0001, "Desmantelar: +50% contra Cerco")

## Patrulheiro x Lendária: Caçada Lendária (passiva intrínseca do Caçador de Lendas) reconhece o traço
## `legendary` de uma Lendária de OUTRA Doutrina (Campeão Guardião), não pelo nome/id.
func test_legend_hunt_ranger_legendary_recognizes_another_branchs_legendary_by_trait():
	var grid := _world()
	var hunter_owner := _player()
	var hunter := _unit(grid, hunter_owner, CATALOG.ranger.legend, Vector2i(0, 0))
	var rival := _rival_of(hunter_owner)
	var champion := _unit(grid, rival, CATALOG.guardian.legend, Vector2i(1, 0))
	assert_true(champion.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_almost_eq(UnitAbilities.trait_attack_multiplier(hunter, champion), 1.4, 0.0001, "Caçada Lendária: +40% contra Lendária, de qualquer Doutrina")

## Mestre das Sombras (Ladino, INFILTRATOR) x Cavaleiro de Grifo (Cavalaria, FLYING): duas Lendárias de
## Doutrinas diferentes com perfis de movimento diferentes, coexistindo sem interferir uma na outra.
## A prova exaustiva de INFILTRATOR != FLYING já existe (test_v2_infiltration.gd); aqui só confirmamos
## que os dois perfis continuam distintos quando as DUAS Lendárias de Doutrinas diferentes estão vivas
## ao mesmo tempo no mesmo grid.
func test_shadow_master_infiltrator_stays_distinct_from_griffon_rider_flying_when_both_coexist():
	var grid := _world(6)
	var me := _player(9, 9, 9, 9, 9, 9)
	for r in range(-3, 4):
		if grid.tiles.has(Vector2i(1, r)):
			_unit(grid, me, CATALOG.warrior.base, Vector2i(1, r)) # parede de unidades
	_set_terrain(grid, Vector2i(3, 0), HexTileData.TerrainType.OCEAN) # água mais além

	var shadow_master := _unit(grid, me, CATALOG.rogue.legend, Vector2i(0, 0))
	assert_eq(shadow_master.unit_data.movement_profile, UnitData.MovementProfile.INFILTRATOR)
	var shadow_reach: Dictionary = grid.unit_reachable(shadow_master)
	assert_true(shadow_reach.has(Vector2i(2, 0)), "INFILTRATOR atravessa a parede de unidades")
	assert_false(shadow_reach.has(Vector2i(3, 0)), "mas não a água")
	grid.remove_unit(shadow_master)

	var griffon := _unit(grid, me, CATALOG.cavalry.legend, Vector2i(0, 0))
	assert_eq(griffon.unit_data.movement_profile, UnitData.MovementProfile.FLYING)
	var griffon_reach: Dictionary = grid.unit_reachable(griffon)
	assert_true(griffon_reach.has(Vector2i(2, 0)), "FLYING também atravessa a parede de unidades")
	assert_false(griffon_reach.has(Vector2i(3, 0)), "nunca POUSA na água (regra de pouso legal), mas...")
	assert_true(griffon_reach.has(Vector2i(4, 0)), "...voa POR CIMA dela e pousa do outro lado -- diferente do Mestre das Sombras, barrado na água")

## Cerco: Munição Demolidora é EXCLUSIVA de cidade -- nunca entra no combate unidade-contra-unidade,
## mesmo com o atacante do Cerco totalmente pesquisado e o alvo sendo uma unidade real.
func test_demolition_ammo_never_applies_to_unit_versus_unit_combat():
	var grid := _world()
	var siege_owner := _siege_player(4) # N4: Munição Demolidora
	var attacker := _unit(grid, siege_owner, CATALOG.siege.base, Vector2i(0, 0))
	var rival := _rival_of(siege_owner)
	var defender := _foe(grid, rival, Vector2i(2, 0), 40.0, 3.0) # unidade, não cidade
	var predicted := CombatResolver.predict(attacker, defender, grid)
	var plain := _formula_damage(grid, attacker.unit_data.attack, 1.0, defender)
	assert_almost_eq(predicted.damage_to_defender, plain, 0.0001, "sem nenhum bônus de Munição Demolidora contra unidade")
	# Confirmação já existente (Fase 11, test_v2_demolition_ammo.gd): resolve_lair_attack nunca chama
	# o multiplicador de Cerco -- repetida aqui porque a interação cruzada é o assunto desta fase.
	var lair_source := FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd").split("func resolve_lair_attack")[1]
	assert_false(lair_source.split("func ")[0].contains("V2TechniqueRuntime"), "Munição Demolidora não entra no ataque a covil")

# --- §46: smoke test de exército misto (seis funções diferentes coexistindo) ----------------------

func test_a_mixed_army_of_six_different_roles_coexists_selects_moves_attacks_and_keeps_its_own_techniques():
	var grid := _world(10)
	GameManager.hex_grid = grid # SelectionManager._select_unit precisa do grid ativo pra calcular o alcance de movimento
	var me := _player(9, 9, 9, 9, 9, 9)
	var rival := _rival_of(me)
	var units: Dictionary = {} # branch -> Unit
	var q := -6
	for branch in BRANCHES:
		units[branch] = _unit(grid, me, CATALOG[branch].elite, Vector2i(q, 0))
		q += 2

	# Coexistem: seis unidades distintas, cada uma no seu próprio tile.
	assert_eq(me.units.size(), 6)
	for branch in BRANCHES:
		assert_same(grid.get_unit_at(units[branch].coord), units[branch], branch)

	# Selecionam.
	for branch in BRANCHES:
		SelectionManager._select_unit(units[branch])
		assert_same(SelectionManager.selected_unit, units[branch], branch)

	# Movem (um passo livre).
	for branch in BRANCHES:
		var unit: Unit = units[branch]
		var start := unit.coord
		var dest := start + Vector2i(0, 1)
		if grid.tiles.has(dest) and grid.get_unit_at(dest) == null:
			grid.move_unit(unit, dest, 1.0)
			assert_eq(unit.coord, dest, branch)

	# Atacam (previsão de combate contra um alvo comum -- não muda o HP de ninguém, cada unidade é avaliada isoladamente).
	for branch in BRANCHES:
		var unit: Unit = units[branch]
		var near := _coord_at(grid, unit.coord, 1)
		var foe := _foe(grid, rival, near, 30.0, 2.0)
		var predicted := CombatResolver.predict(unit, foe, grid)
		assert_gt(predicted.damage_to_defender, 0.0, "%s ataca" % branch)
		grid.remove_unit(foe)

	# Nenhuma branch vaza técnica pra outra -- cada unidade continua só com as DUAS da sua própria Doutrina.
	for branch in BRANCHES:
		var ids := V2TechniqueRuntime.techniques_for_unit(units[branch]).map(func(t): return t.id)
		assert_eq(ids, CATALOG[branch].techniques, branch)

# --- §47: teste completo das 54 pesquisas numa civilização de teste -------------------------------

func test_completing_all_54_normal_researches_unlocks_everything_and_leaves_the_capstone_available():
	var player := _player(9, 9, 9, 9, 9, 9)
	assert_eq(player.v2_research.completed_ids.size(), 54, "as 54 pesquisas normais, sem o capstone")

	var unlocked := V2UnlockSystem.unlocked_ids(player)
	assert_eq(unlocked.size(), 54, "todos os 54 unlocks normais consultáveis (o capstone ainda não foi pesquisado)")

	var techniques := 0
	for branch in BRANCHES:
		for technique_id in CATALOG[branch].techniques:
			assert_true(player.has_unlocked(technique_id), technique_id)
			techniques += 1
	assert_eq(techniques, 12)

	for branch in BRANCHES:
		var c: Dictionary = CATALOG[branch]
		for form in [c.base, c.evolution, c.elite]:
			assert_true(player.has_unlocked(form), form)
		assert_true(player.has_unlocked(c.hall), c.hall)
		assert_true(player.has_unlocked(c.mastery), c.mastery)
		assert_true(player.has_unlocked(c.legend), c.legend)
		assert_eq(V2UnitLine.highest_unlocked_form(player, branch), c.elite, "%s: a forma mais avançada oferecida é a Elite" % branch)

	assert_true(player.v2_research.is_available("v2_supreme_army"), "capstone disponível (2/2, na verdade 6/6 contados como 2)")
	assert_false(player.v2_research.is_completed("v2_supreme_army"), "mas ainda não foi pesquisado")

# --- §49 (extensão): nenhuma extensão desta fase cita um nome/id concreto de Doutrina --------------

func test_the_new_phase_12_helpers_cite_no_concrete_doctrine_name_or_id():
	var files := [
		"res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnlockSystem.gd", "res://scripts/ui/TileInspector.gd",
		"res://scripts/data/V2ResearchDatabase.gd",
	]
	var concrete_ids := RegEx.create_from_string("\"v2_(unit|technique|building|legendary)_[a-z_]+\"")
	for path in files:
		var code := _code_only(FileAccess.get_file_as_string(path))
		var found := concrete_ids.search(code)
		assert_null(found, "%s cita um objeto concreto de Doutrina: %s" % [path, found.get_string() if found != null else ""])
	# V2UnitLine.role_of / TileInspector.unit_class_label decidem pelo branch_role dos dados, nunca por nome.
	var unit_line_code := _code_only(FileAccess.get_file_as_string("res://scripts/core/V2UnitLine.gd"))
	for word in ["Guardião", "Guerreiro", "Patrulheiro", "Cavalaria", "Ladino", "Cerco", "tank_frontline", "melee_damage"]:
		assert_false(unit_line_code.contains(word), "V2UnitLine cita '%s'" % word)
