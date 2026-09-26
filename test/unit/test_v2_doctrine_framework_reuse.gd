extends "res://test/unit/v2_combat_fixture.gd"

## PROVA de reutilização (Aetherlands V2 Fases 7-11): a segunda à sexta Doutrina completas (Guerreiro, Patrulheiro, Cavalaria, Ladino, Cerco) são CONTEÚDO sobre as
## fundações do Guardião — as mesmas verificações genéricas rodam, em laço, sobre as SEIS linhas; nenhuma arquitetura paralela existe; e os
## arquivos das fundações não citam nenhum id concreto de unidade/técnica/prédio de nenhuma Doutrina.

const BRANCHES := {
	"guardian": {
		"base": "v2_unit_shieldbearer", "evolution": "v2_unit_guardian", "elite": "v2_unit_sentinel",
		"hall": "v2_building_guardian_hall", "mastery": "v2_building_guardian_mastery", "legend": "v2_legendary_guardian_champion",
		"techniques": ["v2_technique_shield_wall", "v2_technique_brace_spears"],
		"costs": [20.0, 32.0, 48.0], "legend_cost": 90.0,
	},
	"warrior": {
		"base": "v2_unit_warrior", "evolution": "v2_unit_swordsman", "elite": "v2_unit_weapon_master",
		"hall": "v2_building_warrior_hall", "mastery": "v2_building_warrior_mastery", "legend": "v2_legendary_blade_hero",
		"techniques": ["v2_technique_power_strike", "v2_technique_cleave"],
		"costs": [20.0, 32.0, 48.0], "legend_cost": 90.0,
	},
	"ranger": {
		"base": "v2_unit_archer", "evolution": "v2_unit_hunter", "elite": "v2_unit_elite_marksman",
		"hall": "v2_building_ranger_camp", "mastery": "v2_building_ranger_mastery", "legend": "v2_legendary_legend_hunter",
		"techniques": ["v2_technique_precise_shot", "v2_technique_volley"],
		"costs": [20.0, 32.0, 48.0], "legend_cost": 90.0,
	},
	"cavalry": {
		"base": "v2_unit_cavalier", "evolution": "v2_unit_shock_cavalier", "elite": "v2_unit_armored_cavalier",
		"hall": "v2_building_war_stable", "mastery": "v2_building_cavalry_mastery", "legend": "v2_legendary_griffon_rider",
		"techniques": ["v2_technique_charge", "v2_technique_tactical_retreat"],
		"costs": [24.0, 38.0, 56.0], "legend_cost": 100.0,
	},
	"rogue": {
		"base": "v2_unit_rogue", "evolution": "v2_unit_saboteur", "elite": "v2_unit_assassin",
		"hall": "v2_building_rogue_guild", "mastery": "v2_building_rogue_mastery", "legend": "v2_legendary_shadow_master",
		"techniques": ["v2_technique_sneak_attack", "v2_technique_dismantle"],
		"costs": [20.0, 32.0, 48.0], "legend_cost": 95.0,
	},
	"siege": {
		"base": "v2_unit_catapult", "evolution": "v2_unit_trebuchet", "elite": "v2_unit_bombard",
		"hall": "v2_building_siege_arsenal", "mastery": "v2_building_grand_arsenal", "legend": "v2_legendary_siege_colossus",
		"techniques": ["v2_technique_demolition_ammo", "v2_technique_prepared_bombardment"],
		"costs": [28.0, 44.0, 64.0], "legend_cost": 110.0,
	},
}

## Jogador com `branch` pesquisada até o nível `through` (só essa Doutrina).
func _branch_player(branch: String, through: int) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_%s_%d" % [branch, n])
	return player

# --- As mesmas garantias nas duas linhas ---------------------------------------------------------------------------

func test_the_unit_line_is_derived_from_metadata_for_all_five_doctrines():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		assert_eq(V2UnitLine.unit_ids(branch), [b.base, b.evolution, b.elite], branch)
		for id in [b.base, b.evolution, b.elite]:
			assert_true(V2UnitLine.is_line_unit(id), id)
			assert_eq(V2UnitLine.branch_of(id), branch, id)
			assert_eq(V2UnitLine.doctrine_branch_of(id), branch, id)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(b.base).upgrade_to, b.evolution, branch)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(b.evolution).upgrade_to, b.elite, branch)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(b.elite).upgrade_to, "", "%s: a Elite é o fim da linha" % branch)
		assert_false(V2UnitLine.is_line_unit(b.legend), "%s: o Lendário não é da cadeia" % branch)
		assert_eq(V2UnitLine.doctrine_branch_of(b.legend), branch, "%s: mas é da Doutrina" % branch)

func test_resolve_trainable_form_offers_one_more_advanced_form_at_each_tier_in_all_five_doctrines():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		var expected := {3: b.base, 4: b.base, 5: b.evolution, 6: b.evolution, 7: b.elite, 8: b.elite, 9: b.elite}
		for through in expected:
			var player := _branch_player(branch, through)
			for form in [b.base, b.evolution, b.elite]:
				assert_eq(V2UnitLine.resolve_trainable_form(player, form), expected[through], "%s até N%d (%s)" % [branch, through, form])
		assert_eq(V2UnitLine.resolve_trainable_form(_branch_player(branch, 2), b.base), "", "%s: antes do N3 nada" % branch)

func test_the_hall_trains_the_whole_line_and_the_mastery_building_trains_the_legend_in_all_five_doctrines():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		var hall := BuildingDatabase.get_building(b.hall)
		var mastery := BuildingDatabase.get_building(b.mastery)
		assert_eq(hall.trains_unit, b.base, branch)
		for form in [b.base, b.evolution, b.elite]:
			assert_eq(BuildingDatabase.building_that_trains(form), hall, "%s: %s" % [branch, form])
		assert_eq(BuildingDatabase.building_that_trains(b.legend), mastery, branch)
		assert_eq(mastery.requires_building, b.hall, branch)
		assert_eq(hall.requires_building, "", "%s: o Salão não exige prédio V1" % branch)

func test_all_halls_and_all_masteries_share_the_same_placeholder_scale_and_each_line_its_own_cost_ladder():
	for branch in BRANCHES:
		assert_eq(BuildingDatabase.get_building(BRANCHES[branch].hall).production_cost, 22.0, branch)
		assert_eq(BuildingDatabase.get_building(BRANCHES[branch].mastery).production_cost, 55.0, branch)
		assert_eq(UnitDatabase.create_unit(BRANCHES[branch].legend).production_cost, BRANCHES[branch].legend_cost, branch)
		var ladder := [UnitDatabase.create_unit(BRANCHES[branch].base).production_cost, UnitDatabase.create_unit(BRANCHES[branch].evolution).production_cost, UnitDatabase.create_unit(BRANCHES[branch].elite).production_cost]
		assert_eq(ladder, BRANCHES[branch].costs, "%s: escada de custo N3/N5/N7" % branch)
		assert_true(ladder[0] < ladder[1] and ladder[1] < ladder[2] and ladder[2] < BRANCHES[branch].legend_cost, "%s: cada forma custa mais que a anterior e o Lendário mais que a Elite" % branch)

func test_a_city_trains_only_the_current_form_and_only_with_its_own_hall_in_all_five_doctrines():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		var player := _branch_player(branch, 7)
		var with_hall := _standalone_city(player, [b.hall])
		var offered: Array = [b.base, b.evolution, b.elite].filter(func(k): return player.has_unlocked(k) and with_hall.can_train(k))
		assert_eq(offered, [b.elite], branch)
		var without: Array = [b.base, b.evolution, b.elite].filter(func(k): return _standalone_city(player).can_train(k))
		assert_eq(without, [], "%s: sem o Salão nada treina" % branch)

func test_the_generic_upgrade_walks_all_five_lines_with_the_generic_cost_formula():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		var grid := _world(4)
		var player := _branch_player(branch, 7)
		player.gold = 500.0
		var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
		city.buildings[b.hall] = true
		var unit := _unit(grid, player, b.base, Vector2i(1, 0))
		var id := unit.get_instance_id()
		var gold := player.gold
		for step in [[b.base, b.evolution], [b.evolution, b.elite]]:
			assert_eq(V2UnitUpgrade.get_upgrade_target(unit), step[1], "%s: alvo do passo" % branch)
			var expected_cost := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(step[1]).production_cost - UnitDatabase.create_unit(step[0]).production_cost)
			assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected_cost, "%s: custo pela fórmula" % branch)
			assert_true(V2UnitUpgrade.perform_upgrade(player, unit, grid), "%s: %s -> %s" % [branch, step[0], step[1]])
			gold -= expected_cost
			unit.movement_left = unit.unit_data.movement_points
			TurnManager.turn_number += 1
		assert_eq(unit.get_instance_id(), id, "%s: sempre a mesma unidade" % branch)
		assert_eq(player.gold, gold)
		assert_eq(unit.unit_data.visual_kind, b.elite)
		assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "")
		TurnManager.turn_number = 5

func test_all_five_doctrines_have_two_registered_techniques_inherited_by_every_form_and_the_legend():
	for branch in BRANCHES:
		var b: Dictionary = BRANCHES[branch]
		var techniques := V2DoctrineTechniqueDatabase.for_branch(branch)
		assert_eq(techniques.map(func(t): return t.id), b.techniques, branch)
		var grid := _world()
		var player := _branch_player(branch, 9)
		var coord_index := 0
		for kind in [b.base, b.evolution, b.elite, b.legend]:
			var unit := _unit(grid, player, kind, Vector2i(coord_index, 0))
			coord_index -= 1
			var ids: Array = V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id)
			assert_eq(ids, b.techniques, "%s: %s" % [branch, kind])

func test_techniques_never_cross_doctrines():
	var grid := _world()
	var player := _player(9, 9, 9, 9, 9, 9)
	var guardian_unit := _unit(grid, player, BRANCHES.guardian.base, Vector2i(0, 0))
	var warrior_unit := _unit(grid, player, BRANCHES.warrior.base, Vector2i(-1, 0))
	var ranger_unit := _unit(grid, player, BRANCHES.ranger.base, Vector2i(-2, 0))
	var cavalry_unit := _unit(grid, player, BRANCHES.cavalry.base, Vector2i(-3, 0))
	var rogue_unit := _unit(grid, player, BRANCHES.rogue.base, Vector2i(-4, 0))
	var siege_unit := _unit(grid, player, BRANCHES.siege.base, Vector2i(-5, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(rogue_unit).map(func(t): return t.id), BRANCHES.rogue.techniques)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(cavalry_unit).map(func(t): return t.id), BRANCHES.cavalry.techniques)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(ranger_unit).map(func(t): return t.id), BRANCHES.ranger.techniques)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(guardian_unit).map(func(t): return t.id), BRANCHES.guardian.techniques)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(warrior_unit).map(func(t): return t.id), BRANCHES.warrior.techniques)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(siege_unit).map(func(t): return t.id), BRANCHES.siege.techniques)

func test_the_legendaries_of_all_doctrines_are_recognized_by_the_same_metadata_and_share_one_slot():
	var grid := _world()
	var player := _player(9, 9, 9, 9)
	for branch in BRANCHES:
		var legend: String = BRANCHES[branch].legend
		assert_true(V2LegendarySystem.is_legendary_kind(legend), branch)
		assert_true(UnitDatabase.create_unit(legend).has_trait(UnitData.TRAIT_LEGENDARY), branch)
		assert_eq(V2ResearchDatabase.node_for_unlock_id(legend).unlock_type, "legendary_candidate", branch)
	assert_true(V2LegendarySystem.spawn_allowed(player, BRANCHES.guardian.legend))
	var first := _unit(grid, player, BRANCHES.guardian.legend, Vector2i(0, 0))
	assert_not_null(first)
	for branch in BRANCHES:
		assert_false(V2LegendarySystem.spawn_allowed(player, BRANCHES[branch].legend), "%s: um Lendário ativo bloqueia os cinco candidatos" % branch)

func test_the_unlock_system_connects_all_six_doctrines_by_the_same_type_table():
	for branch in BRANCHES:
		for node in V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch):
			assert_true(node.gameplay_connected, node.id)
			assert_true(node.unlock_type in V2UnlockSystem.CONNECTED_TYPES, "%s (%s)" % [node.id, node.unlock_type])
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55, "9 do Guardião + 9 do Guerreiro + 9 do Patrulheiro + 9 da Cavalaria + 9 do Ladino + 9 do Cerco + 1 capstone (Fase 12)")

func test_each_doctrine_announces_its_unlocks_with_the_same_generic_texts():
	assert_eq(V2UnlockSystem.announcement_text("building", "Salão de Armas"), "Novo prédio disponível: Salão de Armas")
	assert_eq(V2UnlockSystem.announcement_text("unit", "Guerreiro"), "Nova unidade disponível: Guerreiro")
	assert_eq(V2UnlockSystem.announcement_text("technique", "Golpe Poderoso"), "Nova técnica disponível: Golpe Poderoso")
	assert_eq(V2UnlockSystem.announcement_text("unit_upgrade", "Espadachim"), "Nova evolução disponível: Espadachim")
	assert_eq(V2UnlockSystem.announcement_text("mastery_building", "Arena dos Campeões"), "Novo prédio disponível: Arena dos Campeões")
	assert_eq(V2UnlockSystem.announcement_text("legendary_candidate", "Herói da Lâmina"), "Unidade Lendária disponível: Herói da Lâmina")

func test_each_doctrines_tooltips_are_built_by_the_same_generic_effect_text():
	var n8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_warrior_8")).replace("\n", " ")
	var n9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_warrior_9")).replace("\n", " ")
	assert_true(n8.contains("Desbloqueia Arena dos Campeões. Requer Salão de Armas e permite treinar o Herói da Lâmina após sua pesquisa."), n8)
	assert_true(n9.contains("Desbloqueia Herói da Lâmina, a Unidade Lendária da Doutrina. Treinamento em Arena dos Campeões;"), n9)
	var n4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_warrior_4")).replace("\n", " ")
	assert_true(n4.contains("Desbloqueia Golpe Poderoso para unidades da Doutrina do Guerreiro."), n4)
	var n7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_warrior_7")).replace("\n", " ")
	assert_true(n7.contains("Desbloqueia Mestre de Armas. Cidades com Salão de Armas passam a treinar Mestre de Armas diretamente, e cada Espadachim existente pode evoluir em cidades próprias."), n7)
	# Patrulheiro (Fase 8): os mesmos textos genéricos.
	var r4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_ranger_4")).replace("\n", " ")
	var r7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_ranger_7")).replace("\n", " ")
	var r8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_ranger_8")).replace("\n", " ")
	var r9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_ranger_9")).replace("\n", " ")
	assert_true(r4.contains("Desbloqueia Disparo Preciso para unidades da Doutrina do Patrulheiro."), r4)
	assert_true(r7.contains("Desbloqueia Atirador de Elite. Cidades com Campo dos Patrulheiros passam a treinar Atirador de Elite diretamente, e cada Caçador existente pode evoluir em cidades próprias."), r7)
	assert_true(r8.contains("Desbloqueia Torre dos Patrulheiros. Requer Campo dos Patrulheiros e permite treinar o Caçador de Lendas após sua pesquisa."), r8)
	assert_true(r9.contains("Desbloqueia Caçador de Lendas, a Unidade Lendária da Doutrina. Treinamento em Torre dos Patrulheiros;"), r9)
	# Cavalaria (Fase 9): os mesmos textos genéricos, sem uma linha de texto nova no sistema de pesquisa.
	var c4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_cavalry_4")).replace("\n", " ")
	var c6 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_cavalry_6")).replace("\n", " ")
	var c7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_cavalry_7")).replace("\n", " ")
	var c8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_cavalry_8")).replace("\n", " ")
	var c9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_cavalry_9")).replace("\n", " ")
	assert_true(c4.contains("Desbloqueia Carga para unidades da Doutrina da Cavalaria."), c4)
	assert_true(c6.contains("Desbloqueia Retirada Tática para unidades da Doutrina da Cavalaria."), c6)
	assert_true(c7.contains("Desbloqueia Cavaleiro Blindado. Cidades com Estábulo de Guerra passam a treinar Cavaleiro Blindado diretamente, e cada Cavaleiro de Choque existente pode evoluir em cidades próprias."), c7)
	assert_true(c8.contains("Desbloqueia Ordem da Cavalaria. Requer Estábulo de Guerra e permite treinar o Cavaleiro de Grifo após sua pesquisa."), c8)
	assert_true(c9.contains("Desbloqueia Cavaleiro de Grifo, a Unidade Lendária da Doutrina. Treinamento em Ordem da Cavalaria;"), c9)
	# Ladino (Fase 10): os mesmos textos genéricos, sem uma linha de texto nova no sistema de pesquisa.
	var g4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_rogue_4")).replace("\n", " ")
	var g6 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_rogue_6")).replace("\n", " ")
	var g7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_rogue_7")).replace("\n", " ")
	var g8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_rogue_8")).replace("\n", " ")
	var g9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_rogue_9")).replace("\n", " ")
	assert_true(g4.contains("Desbloqueia Ataque Furtivo para unidades da Doutrina do Ladino."), g4)
	assert_true(g7.contains("Desbloqueia Assassino. Cidades com Guilda dos Ladinos passam a treinar Assassino diretamente, e cada Sabotador existente pode evoluir em cidades próprias."), g7)
	assert_true(g8.contains("Desbloqueia Refúgio das Sombras. Requer Guilda dos Ladinos e permite treinar o Mestre das Sombras após sua pesquisa."), g8)
	assert_true(g9.contains("Desbloqueia Mestre das Sombras, a Unidade Lendária da Doutrina. Treinamento em Refúgio das Sombras;"), g9)
	# Cerco (Fase 11): os mesmos textos genéricos, sem uma linha de texto nova no sistema de pesquisa.
	var s4 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_4")).replace("\n", " ")
	var s7 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_7")).replace("\n", " ")
	var s8 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_8")).replace("\n", " ")
	var s9 := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.get_node("v2_doctrine_siege_9")).replace("\n", " ")
	assert_true(s4.contains("Desbloqueia Munição Demolidora para unidades da Doutrina de Cerco."), s4)
	assert_true(s7.contains("Desbloqueia Bombarda. Cidades com Arsenal de Cerco passam a treinar Bombarda diretamente, e cada Trebuchet existente pode evoluir em cidades próprias."), s7)
	assert_true(s8.contains("Desbloqueia Grande Arsenal. Requer Arsenal de Cerco e permite treinar o Colosso de Cerco após sua pesquisa."), s8)
	assert_true(s9.contains("Desbloqueia Colosso de Cerco, a Unidade Lendária da Doutrina. Treinamento em Grande Arsenal;"), s9)
	for text in [n4, n7, n8, n9, r4, r7, r8, r9, c4, c6, c7, c8, c9, g4, g6, g7, g8, g9, s4, s7, s8, s9]:
		assert_false(text.contains(V2ResearchDatabase.GAMEPLAY_NOTICE))
		assert_false(text.contains("Desbloqueio futuro"))

# --- Nenhuma arquitetura paralela ----------------------------------------------------------------------------------------

func _script_files(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			result.append("%s/%s" % [path, file_name])
	for sub in dir.get_directories():
		result.append_array(_script_files("%s/%s" % [path, sub]))
	return result

func test_no_warrior_specific_system_exists_only_shared_frameworks():
	var forbidden := ["warrior", "guerreiro", "swordsman", "weaponmaster", "blade", "cleave", "powerstrike", "ranger", "patrulheiro", "archer", "hunter", "marksman", "volley", "preciseshot", "cavalier", "cavaleiro", "cavalaria", "griffon", "grifo", "retreat", "charge", "flyingcombat", "flightresolver", "rogue", "ladino", "saboteur", "sabotador", "assassin", "assassino", "shadowmaster", "sneakattack", "dismantle", "infiltrator"]
	for path in _script_files("res://scripts"):
		var base := path.get_file().to_lower()
		for word in forbidden:
			assert_false(base.contains(word), "%s parece uma arquitetura paralela do Guerreiro" % path)
	for wanted in ["V2UnlockSystem", "V2DoctrineTechniqueDatabase", "V2TechniqueRuntime", "V2UnitLine", "V2UnitUpgrade", "V2LegendarySystem"]:
		assert_true(FileAccess.file_exists("res://scripts/core/%s.gd" % wanted) or FileAccess.file_exists("res://scripts/data/%s.gd" % wanted), wanted)
	for path in _script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("class_name Warrior"), path)

func test_the_framework_files_name_no_concrete_doctrine_object():
	var framework := [
		"res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd", "res://scripts/core/V2LegendarySystem.gd",
		"res://scripts/core/V2UnlockSystem.gd", "res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitAuras.gd",
		"res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/autoload/SelectionManager.gd",
		"res://scripts/city/City.gd", "res://scripts/autoload/GameManager.gd", "res://scripts/ui/HUD.gd", "res://scripts/ui/TileInspector.gd",
		"res://scripts/data/V2DoctrineTechniqueData.gd", "res://scripts/ui/PauseMenu.gd",
	]
	var concrete := RegEx.create_from_string("\"v2_(unit|technique|building|legendary)_[a-z_]+\"") # só como string (id), não em nomes de função
	for path in framework:
		var code := _code_only(FileAccess.get_file_as_string(path))
		var found := concrete.search(code)
		assert_null(found, "%s cita um objeto concreto de Doutrina: %s" % [path, found.get_string() if found != null else ""])
		for word in ["Guerreiro", "Espadachim", "Mestre de Armas", "Herói da Lâmina", "Golpe Poderoso", "Ataque em Arco", "Escudeiro", "Sentinela", "Campeão", "Patrulheiro", "Arqueiro", "Caçador de Lendas", "Atirador de Elite", "Saraivada", "Disparo Preciso", "Caçada Lendária", "Cavaleiro de Choque", "Cavaleiro Blindado", "Cavaleiro de Grifo", "Estábulo de Guerra", "Ordem da Cavalaria", "Retirada Tática", "Doutrina da Cavalaria", "Ladino", "Sabotador", "Assassino", "Mestre das Sombras", "Guilda dos Ladinos", "Refúgio das Sombras", "Ataque Furtivo", "Desmantelar", "Doutrina do Ladino"]:
			assert_false(code.contains(word), "%s cita '%s'" % [path, word])

func test_the_warrior_needed_only_the_generic_extensions_documented_in_the_phase():
	# As três extensões genéricas da Fase 7 existem como CAMPOS DE DADO, não como código do Guerreiro:
	var technique := V2DoctrineTechniqueData.new()
	assert_true("strike_multiplier" in technique and "strike_targeting" in technique and "strike_max_targets" in technique)
	var data := UnitData.new()
	assert_true("low_hp_attack_threshold" in data and "low_hp_attack_bonus" in data)
	assert_true(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd").contains("static func can_attack_unit"), "regra única de alvo hostil")
	assert_false(V2DoctrineTechniqueData.new().is_strike(), "por padrão uma técnica NÃO é de ataque (Muralha/Preparar Lanças intactas)")
	assert_false(UnitData.new().has_low_hp_attack_bonus(), "por padrão nenhuma unidade tem a passiva")

func test_the_cavalry_needed_only_the_generic_extensions_documented_in_the_phase():
	# As extensões genéricas da Fase 9 existem como CAMPOS DE DADO, não como código da Cavalaria:
	var technique := V2DoctrineTechniqueData.new()
	assert_true("strike_min_range" in technique and "strike_reposition" in technique, "mover-e-atacar")
	assert_true("target_mode" in technique and "relocate_range" in technique and "relocate_flat_cost" in technique, "alvo por tile / reposicionamento")
	var data := UnitData.new()
	assert_true("movement_profile" in data and "ranged_damage_taken_bonus" in data and "visual_template" in data)
	# Por padrão NADA muda: a técnica não move, não reposiciona, a unidade é terrestre e sem vulnerabilidade.
	assert_false(technique.repositions())
	assert_false(technique.is_relocation())
	assert_eq(technique.strike_min_range, 1)
	assert_eq(technique.target_mode, V2DoctrineTechniqueData.TargetMode.UNIT)
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_eq(data.ranged_damage_taken_bonus, 0.0)
	assert_false(data.is_flying())
	var grid_source := FileAccess.get_file_as_string("res://scripts/world/HexGrid.gd")
	assert_true(grid_source.contains("func flight_reachable") and grid_source.contains("func unit_reachable"), "o voo é um PERFIL de movimento do HexGrid")

func test_no_parallel_cavalry_or_flight_system_exists():
	var forbidden_classes := ["CavalryCombatSystem", "CavalryMovementSystem", "CavalryTechniqueRuntime", "CavalryUpgradeSystem", "CavalryLegendarySystem", "FlyingCombatResolver", "CavalryProductionQueue", "CavalryDoctrine"]
	for path in _script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		for name in forbidden_classes:
			assert_false(source.contains("class_name %s" % name), "%s declara %s" % [path, name])
			assert_false(path.get_file().begins_with(name), "%s parece a arquitetura paralela %s" % [path, name])

func test_no_foundation_decides_by_a_cavalry_technique_or_unit_id():
	var foundations := [
		"res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd", "res://scripts/core/V2LegendarySystem.gd",
		"res://scripts/core/V2UnlockSystem.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/world/HexGrid.gd",
		"res://scripts/world/HexMetrics.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd", "res://scripts/data/UnitData.gd",
	]
	for path in foundations:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for concrete in ["technique_charge", "technique_tactical_retreat", "unit_cavalier", "unit_shock_cavalier", "unit_armored_cavalier", "griffon_rider", "war_stable", "cavalry_mastery"]:
			assert_false(code.contains(concrete), "%s cita '%s'" % [path, concrete])
		assert_false(code.contains("== CHARGE") or code.contains("== RETREAT") or code.contains("== GRIFFON"), path)

func test_the_rogue_needed_only_the_generic_extensions_documented_in_the_phase():
	# As extensões genéricas da Fase 10 existem como CAMPOS DE DADO, não como código do Ladino:
	var technique := V2DoctrineTechniqueData.new()
	assert_true("strike_defense_penetration" in technique and "strike_prevents_counterattack" in technique, "penetração de Defesa / sem revide")
	assert_true("basic_attack_target_traits" in technique, "passiva com múltiplos traços (era um único traço até a Fase 9)")
	var data := UnitData.new()
	assert_true("movement_profile" in data, "o perfil de movimento (Fase 9) ganhou o terceiro valor INFILTRATOR nesta fase")
	assert_eq(UnitData.MovementProfile.keys().size(), 3, "GROUND, FLYING, INFILTRATOR")
	# Por padrão NADA muda: sem penetração, com revide, sem traços-alvo, terrestre.
	assert_eq(technique.strike_defense_penetration, 0.0)
	assert_false(technique.strike_prevents_counterattack)
	assert_true(technique.basic_attack_target_traits.is_empty())
	assert_false(technique.has_attack_effect())
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	var grid_source := FileAccess.get_file_as_string("res://scripts/world/HexGrid.gd")
	assert_true(grid_source.contains("func infiltrate_reachable"), "a infiltração é um PERFIL de movimento do HexGrid, irmão do voo")
	var combat_source := _code_only(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd"))
	assert_false(combat_source.contains("if technique_id"), "penetração/sem-revide são parâmetros da MESMA fórmula, nunca um id")

func test_no_parallel_rogue_or_infiltration_system_exists():
	var forbidden_classes := ["RogueCombatSystem", "RogueTechniqueRuntime", "RogueUpgradeSystem", "RogueLegendarySystem", "RogueMovementSystem", "StealthCombatResolver", "RogueProductionQueue", "RogueDoctrine"]
	for path in _script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		for name in forbidden_classes:
			assert_false(source.contains("class_name %s" % name), "%s declara %s" % [path, name])
			assert_false(path.get_file().begins_with(name), "%s parece a arquitetura paralela %s" % [path, name])

func test_no_foundation_decides_by_a_rogue_technique_or_unit_id():
	var foundations := [
		"res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd", "res://scripts/core/V2LegendarySystem.gd",
		"res://scripts/core/V2UnlockSystem.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/world/HexGrid.gd",
		"res://scripts/world/HexMetrics.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd", "res://scripts/data/UnitData.gd",
	]
	for path in foundations:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for concrete in ["technique_sneak_attack", "technique_dismantle", "unit_rogue", "unit_saboteur", "unit_assassin", "shadow_master", "rogue_guild", "rogue_mastery"]:
			assert_false(code.contains(concrete), "%s cita '%s'" % [path, concrete])
		assert_false(code.contains("== SNEAK_ATTACK") or code.contains("== DISMANTLE") or code.contains("== SHADOW_MASTER"), path)

func test_the_siege_needed_only_the_generic_extensions_documented_in_the_phase():
	# As extensões genéricas da Fase 11 existem como CAMPOS DE DADO, não como código do Cerco:
	var technique := V2DoctrineTechniqueData.new()
	assert_true("city_attack_bonus" in technique, "passiva contra cidade/fortificação (Munição Demolidora)")
	assert_true("strike_requires_undisturbed" in technique, "requisito de preparação (Bombardeio Preparado)")
	assert_eq(V2DoctrineTechniqueData.TargetMode.keys().size(), 3, "UNIT, TILE, CITY")
	assert_true(technique.target_mode == V2DoctrineTechniqueData.TargetMode.UNIT, "padrão continua UNIT")
	var data := UnitData.new()
	assert_true("ignores_technique_stationary_requirement" in data, "exceção por dado ao requisito de preparação (Artilharia Andante)")
	# Por padrão NADA muda: sem bônus de cidade, sem requisito de preparação, sem exceção.
	assert_eq(technique.city_attack_bonus, 0.0)
	assert_false(technique.has_city_attack_effect())
	assert_false(technique.strike_requires_undisturbed)
	assert_false(technique.is_city_strike())
	assert_false(data.ignores_technique_stationary_requirement)
	assert_true(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd").contains("static func can_attack_city"), "regra única de alvo hostil urbano, irmã de can_attack_unit")
	var combat_source := _code_only(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd"))
	assert_false(combat_source.contains("if technique_id"), "o multiplicador do golpe urbano é um parâmetro da MESMA fórmula, nunca um id")

func test_no_parallel_siege_system_exists():
	var forbidden_classes := ["SiegeCombatSystem", "SiegeTechniqueRuntime", "SiegeUpgradeSystem", "SiegeLegendarySystem", "SiegeCityCombatResolver", "SiegeProductionQueue", "SiegeDoctrine"]
	for path in _script_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		for name in forbidden_classes:
			assert_false(source.contains("class_name %s" % name), "%s declara %s" % [path, name])
			assert_false(path.get_file().begins_with(name), "%s parece a arquitetura paralela %s" % [path, name])

func test_no_foundation_decides_by_a_siege_technique_or_unit_id():
	var foundations := [
		"res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/core/V2UnitLine.gd", "res://scripts/core/V2UnitUpgrade.gd", "res://scripts/core/V2LegendarySystem.gd",
		"res://scripts/core/V2UnlockSystem.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/world/HexGrid.gd",
		"res://scripts/world/HexMetrics.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/data/V2DoctrineTechniqueData.gd", "res://scripts/data/UnitData.gd",
	]
	for path in foundations:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for concrete in ["technique_demolition_ammo", "technique_prepared_bombardment", "unit_catapult", "unit_trebuchet", "unit_bombard", "siege_colossus", "siege_arsenal", "grand_arsenal"]:
			assert_false(code.contains(concrete), "%s cita '%s'" % [path, concrete])
		assert_false(code.contains("== DEMOLITION_AMMO") or code.contains("== PREPARED_BOMBARDMENT") or code.contains("== COLOSSUS"), path)
