extends GutTest

## Fase 27: contratos de RELACAO. Valores exatos continuam nas fontes de dados;
## estes testes protegem identidade e monotonicidade sem congelar cada numero.

func test_all_twelve_long_research_lines_are_strictly_monotonic():
	for tree in [V2ResearchNode.TreeType.MILITARY_DOCTRINE, V2ResearchNode.TreeType.MAGIC_SCHOOL]:
		for info in V2ResearchDatabase.branches_for_tree(tree):
			var nodes := V2ResearchDatabase.nodes_for_branch(tree, info.id)
			assert_eq(nodes.size(), 9)
			for i in range(1, nodes.size()):
				assert_gt(nodes[i].cost, nodes[i - 1].cost, "%s N%d > N%d" % [info.id, i + 1, i])
			assert_gt(nodes[8].cost, nodes[6].cost, "%s N9 > N7" % info.id)
	assert_gt(V2ResearchDatabase.CAPSTONE_COST, V2ResearchDatabase.BRANCH_TIER_COSTS.back())

func test_all_six_infrastructure_lines_are_strictly_monotonic():
	for info in V2ResearchDatabase.branches_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE):
		var nodes := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.INFRASTRUCTURE, info.id)
		assert_lt(nodes[0].cost, nodes[1].cost)
		assert_lt(nodes[1].cost, nodes[2].cost)

func test_six_doctrine_unit_lines_gain_cost_and_power_density_without_free_supply():
	for info in V2ResearchDatabase.branches_for_tree(V2ResearchNode.TreeType.MILITARY_DOCTRINE):
		var ids := V2UnitLine.unit_ids(info.id)
		assert_eq(ids.size(), 3, info.id)
		var forms := ids.map(func(id): return UnitDatabase.create_unit(id))
		assert_lt(forms[0].production_cost, forms[1].production_cost, info.id)
		assert_lt(forms[1].production_cost, forms[2].production_cost, info.id)
		assert_lte(forms[0].supply_cost, forms[1].supply_cost, info.id)
		assert_lte(forms[1].supply_cost, forms[2].supply_cost, info.id)
		assert_gt(forms[1].max_hp + forms[1].attack + forms[1].defense, forms[0].max_hp + forms[0].attack + forms[0].defense, info.id)
		assert_gt(forms[2].max_hp + forms[2].attack + forms[2].defense, forms[1].max_hp + forms[1].attack + forms[1].defense, info.id)
		var legendary_node: V2ResearchNode = V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, info.id)[8]
		var legendary := UnitDatabase.create_unit(legendary_node.unlock_id)
		assert_gte(legendary.production_cost, forms[2].production_cost, info.id)
		assert_gt(legendary.production_cost, 0.0, info.id)

func test_economic_and_fortification_curves_never_regress_or_go_negative():
	for branch in V2InfrastructureEconomyData.branches():
		var entry := V2InfrastructureEconomyData.entry_for_branch(branch)
		assert_gt(float(entry.production_cost), 0.0, branch)
		var yields: Array = entry.yields
		assert_gt(float(yields[0]), 0.0, branch)
		assert_lt(float(yields[0]), float(yields[1]), branch)
		assert_lt(float(yields[1]), float(yields[2]), branch)
	for level in range(1, V2FortificationData.MAX_LEVEL + 1):
		assert_gt(V2FortificationData.production_cost(level), V2FortificationData.production_cost(level - 1))
		assert_gt(V2FortificationData.shield_max(level), V2FortificationData.shield_max(level - 1))
		assert_gt(V2FortificationData.city_defense_bonus(level), V2FortificationData.city_defense_bonus(level - 1))
		assert_gte(V2FortificationData.gold_upkeep(level), 0.0)

func test_city_development_costs_and_survivability_grow_together():
	for level in range(2, V2CityLevelData.MAX_LEVEL + 1):
		assert_gt(V2CityLevelData.max_hp(level), V2CityLevelData.max_hp(level - 1))
		assert_gt(V2CityLevelData.max_building_slots(level), V2CityLevelData.max_building_slots(level - 1))
		assert_gt(V2CityLevelData.upgrade_production_cost(level), 0.0)
		assert_gt(V2CityLevelData.upgrade_gold_cost(level), 0.0)
	assert_gt(V2CityLevelData.max_hp(4) + V2FortificationData.shield_max(3), V2CityLevelData.max_hp(1) * 2.0)

func test_all_techniques_and_spells_have_finite_nonnegative_costs_and_cooldowns():
	assert_eq(V2DoctrineTechniqueDatabase.all_techniques().size(), 12)
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_gte(technique.cooldown_turns, 0, technique.id)
		assert_true(is_finite(technique.strike_multiplier) and technique.strike_multiplier >= 0.0, technique.id)
	assert_eq(V2SpellDatabase.all_spells().size(), 24)
	for spell in V2SpellDatabase.all_spells():
		assert_true(is_finite(spell.mana_cost) and spell.mana_cost > 0.0, spell.id)
		assert_gte(spell.cooldown_turns, 0, spell.id)
		assert_lte(spell.cooldown_turns, 5, spell.id)

func test_signature_spells_are_costlier_and_more_impactful_than_their_basic_counterparts():
	var light := V2SpellDatabase.get_spell("v2_spell_restoring_light")
	var miracle := V2SpellDatabase.get_spell("v2_spell_miracle")
	assert_true(miracle.heal_to_full)
	assert_gt(miracle.mana_cost, light.mana_cost)
	var flame := V2SpellDatabase.get_spell("v2_spell_infernal_flame")
	var damnation := V2SpellDatabase.get_spell("v2_spell_damnation")
	assert_gt(damnation.damage_amount, flame.damage_amount)
	assert_gt(damnation.mana_cost, flame.mana_cost)

func test_military_roles_keep_their_cross_line_identity():
	for tier_index in range(3):
		var guardian := UnitDatabase.create_unit(V2UnitLine.unit_ids("guardian")[tier_index])
		var warrior := UnitDatabase.create_unit(V2UnitLine.unit_ids("warrior")[tier_index])
		var ranger := UnitDatabase.create_unit(V2UnitLine.unit_ids("ranger")[tier_index])
		var cavalry := UnitDatabase.create_unit(V2UnitLine.unit_ids("cavalry")[tier_index])
		var rogue := UnitDatabase.create_unit(V2UnitLine.unit_ids("rogue")[tier_index])
		assert_gt(guardian.defense, warrior.defense)
		assert_gt(guardian.max_hp, warrior.max_hp)
		assert_gt(warrior.attack, guardian.attack)
		assert_gt(ranger.attack_range, 1)
		assert_gt(cavalry.movement_points, warrior.movement_points)
		assert_lt(rogue.defense, warrior.defense)
	var siege := UnitDatabase.create_unit(V2UnitLine.unit_ids("siege")[0])
	assert_true(siege.has_trait(UnitData.TRAIT_SIEGE))

func test_each_race_still_has_exactly_two_declared_bonuses():
	assert_eq(V2RaceBonusDatabase.all_profiles().size(), 4)
	for profile in V2RaceBonusDatabase.all_profiles():
		assert_eq(V2RaceBonusDatabase.effect_lines(profile.race_id).size(), 2, profile.race_id)
		for multiplier in [profile.gold_income_multiplier, profile.supply_capacity_multiplier, profile.city_production_multiplier, profile.knowledge_income_multiplier, profile.mana_income_multiplier, profile.unit_attack_multiplier]:
			assert_gt(multiplier, 0.0, profile.race_id)

func test_ritual_and_army_scale_contracts_remain_intact():
	assert_eq(V2TranscendenceSystem.MANA_COST, 120.0)
	assert_eq(V2TranscendenceSystem.ROUNDS_REQUIRED, 4)
	assert_eq(V2TranscendenceSystem.MANIFESTATIONS_REQUIRED, 2)
	assert_eq(V2ResearchDatabase.CAPSTONE_REQUIRED_BRANCHES, 2)
	assert_eq(V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS, 1)
	assert_lte(V2AITuning.NORMAL_TOKEN_CAP, V2AITuning.HARD_TOKEN_CAP)
	assert_eq(V2AITuning.HARD_TOKEN_CAP, 24)
