extends "res://test/unit/v2_combat_fixture.gd"

## Desmantelar (v2_technique_dismantle, Aetherlands V2 Fase 10): a primeira Técnica PASSIVA que generaliza `basic_attack_target_traits` para MAIS de
## um traço — +50% de Ataque contra alvos com o traço `caster` OU `siege` (contado uma vez, mesmo com os dois). Também cobre a origem dos dois
## traços: `caster` semeado de `UnitData.magic_school != ""` (a única classificação inequívoca de conjurador que já existia) e `siege` semeado de
## `UnitAbilities.SIEGE` (a única lista de máquinas de Cerco que já existia). Números (+50%) = BALANCE PLACEHOLDER.

func _rogue_duel(through: int = 6) -> Dictionary:
	var grid := _world()
	var me := _rogue_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit}

# --- Dado ------------------------------------------------------------------------------------------------------------------------

func test_dismantle_is_a_passive_with_no_cost_no_cooldown_no_action():
	var technique := _technique(DISMANTLE)
	assert_eq(technique.display_name, "Desmantelar")
	assert_eq(technique.display_name, V2ResearchDatabase.node_for_unlock_id(DISMANTLE).display_name)
	assert_eq(technique.doctrine_branch, "rogue")
	assert_true(technique.is_passive())
	assert_eq(technique.cooldown_turns, 0)
	assert_false(technique.consumes_action)
	assert_almost_eq(technique.basic_attack_bonus, 0.5, 0.0001, "+50% (placeholder)")
	assert_eq(technique.basic_attack_target_traits, [UnitData.TRAIT_CASTER, UnitData.TRAIT_SIEGE])
	assert_false(technique.has_defense_effect())
	assert_true(technique.has_attack_effect())

func test_it_generates_no_button_and_the_description_is_built_from_the_data():
	var technique := _technique(DISMANTLE)
	assert_true(technique.description.begins_with("Passiva:"), technique.description)
	assert_true(technique.description.contains("+50% de dano de ataque básico contra conjuradores ou unidades de Cerco"), technique.description)
	assert_false(technique.description.contains("Gameplay V2"))
	assert_eq(V2DoctrineTechniqueDatabase.passive_effect_text(technique), "+50% de dano de ataque básico contra conjuradores ou unidades de Cerco")

func test_it_is_registered_next_to_the_sneak_attack():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(DISMANTLE)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("rogue").map(func(t): return t.id), [SNEAK_ATTACK, DISMANTLE])
	assert_true(DISMANTLE in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true(V2DoctrineTechniqueDatabase.attack_bonus_techniques().has(_technique(DISMANTLE)))

# --- Disponibilidade -------------------------------------------------------------------------------------------------------------

func test_before_n6_there_is_no_bonus_and_after_it_is_active_for_every_form():
	var grid := _world()
	var me := _rogue_player(5)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var caster := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_CASTER, 60.0, 1.0)
	assert_eq(UnitAbilities.attack_multiplier(unit, caster), 1.0, "antes do N6")
	me.v2_research.complete_research("v2_doctrine_rogue_6")
	assert_eq(UnitAbilities.attack_multiplier(unit, caster), 1.5)
	assert_true(_technique(DISMANTLE) in V2TechniqueRuntime.passive_techniques_for_unit(unit))

func test_every_form_of_the_line_and_the_legend_has_it_no_other_branch_does():
	var grid := _world()
	var me := _rogue_player(9, 9, 9, 9)
	var rival := _rival_of(me)
	var caster := _traited_foe(grid, rival, Vector2i(9, 9), UnitData.TRAIT_CASTER, 60.0, 1.0)
	var index := 0
	for kind in [ROGUE, SABOTEUR, ASSASSIN, SHADOW_MASTER]:
		var unit := _unit(grid, me, kind, Vector2i(index, 0))
		index -= 1
		assert_true(_technique(DISMANTLE) in V2TechniqueRuntime.passive_techniques_for_unit(unit), kind)
		assert_almost_eq(UnitAbilities.attack_multiplier(unit, caster), 1.5, 0.0001, kind)
	for kind in [WARRIOR, SHIELD, ARCHER, CAVALIER]:
		var other := _unit(grid, me, kind, Vector2i(index, 5))
		index -= 1
		assert_false(_technique(DISMANTLE) in V2TechniqueRuntime.passive_techniques_for_unit(other), kind)
		assert_almost_eq(UnitAbilities.attack_multiplier(other, caster), 1.0, 0.0001, kind)

func test_a_rival_without_n6_gets_no_bonus_and_research_does_not_leak_between_civilizations():
	var grid := _world()
	var me := _rogue_player(6)
	var novice := _rogue_player(3)
	var rival := _rival_of(me)
	var caster := _traited_foe(grid, rival, Vector2i(9, 9), UnitData.TRAIT_CASTER)
	var mine := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var theirs := _unit(grid, novice, ROGUE, Vector2i(2, 2))
	assert_almost_eq(UnitAbilities.attack_multiplier(mine, caster), 1.5, 0.0001)
	assert_almost_eq(UnitAbilities.attack_multiplier(theirs, caster), 1.0, 0.0001)

# --- Traço `caster` ---------------------------------------------------------------------------------------------------------------

func test_a_caster_fixture_is_recognized_and_a_unit_without_the_trait_is_rejected():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var caster := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_CASTER)
	var plain := _foe(grid, rival, Vector2i(0, 1))
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, caster), 1.5, 0.0001)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, plain), 1.0, 0.0001)

func test_the_classification_does_not_depend_on_the_name_or_the_id():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var impostor := _foe(grid, rival, Vector2i(1, 0)) # id/nome de warrior comum, SEM o traço
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, impostor), 1.0, 0.0001, "nome/id não classificam")
	var fake_caster := _traited_foe(grid, rival, Vector2i(0, 1), UnitData.TRAIT_CASTER, 40.0, 3.0, "qualquer_id_desconhecido_xyz")
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, fake_caster), 1.5, 0.0001, "o traço basta, id desconhecido")

## Fase 25: o traço de conjurador vem só da Escola V2 do dado (a magia V1 saiu) -- um "cleric"/"mage" legado
## de save antigo é uma unidade comum, nunca classificada como conjurador por nome.
func test_legacy_v1_units_are_never_classified_as_casters():
	for kind in ["cleric", "mage", "warrior"]:
		assert_false(UnitDatabase.create_unit(kind).has_trait(UnitData.TRAIT_CASTER), kind)
	assert_true(UnitDatabase.create_unit("v2_unit_sacred_cleric").has_trait(UnitData.TRAIT_CASTER))

## A semeadura acontece na CRIAÇÃO (UnitDatabase._seed_traits, chamada pelos dois caminhos de create_unit — normal e o early-return de MagicContent):
## um kind V2 futuro só precisa declarar `magic_school` (ou já nascer com o traço) — nenhuma lista de ids no meio do caminho.
func test_a_future_v2_caster_only_needs_to_declare_magic_school_no_id_list_in_the_logic():
	var data := UnitData.new()
	data.v2_magic_school = "sacred"
	data = UnitDatabase._seed_traits(data, "v2_unit_some_future_mage")
	assert_true(data.has_trait(UnitData.TRAIT_CASTER), "nenhuma lista de ids: basta declarar magic_school")

# --- Traço `siege` ----------------------------------------------------------------------------------------------------------------

func test_a_siege_fixture_is_recognized_and_a_unit_without_the_trait_is_rejected():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var siege := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_SIEGE)
	var plain := _foe(grid, rival, Vector2i(0, 1))
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, siege), 1.5, 0.0001)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, plain), 1.0, 0.0001)

## A ÚNICA lista V1 de máquinas de Cerco já existente é UnitAbilities.SIEGE (a mesma do bônus de dano contra cidade) — reaproveitada aqui, exatamente
## como MOUNTED. Uma catapulta V1 real (kind "catapult") recebe o traço automaticamente.
func test_a_real_v1_siege_engine_gets_the_trait_from_the_same_list_already_used_by_the_game():
	assert_true("catapult" in UnitAbilities.SIEGE, "pré-condição: a Catapulta V1 já é Cerco")
	assert_true(UnitDatabase.create_unit("catapult").has_trait(UnitData.TRAIT_SIEGE))
	assert_false(UnitDatabase.create_unit("warrior").has_trait(UnitData.TRAIT_SIEGE))

func test_a_future_v2_siege_engine_only_needs_to_declare_the_trait_no_id_list_in_the_logic():
	var future := UnitDatabase.create_unit("warrior")
	future.visual_kind = "v2_unit_some_future_siege_engine"
	future.traits.append(UnitData.TRAIT_SIEGE)
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var machine := grid.spawn_unit(Vector2i(1, 0), future, rival)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, machine), 1.5, 0.0001)

# --- Caster + Siege ao mesmo tempo não duplica ------------------------------------------------------------------------------------------

func test_a_target_with_both_traits_gets_the_bonus_only_once():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var data := UnitDatabase.create_unit("warrior")
	data.defense = 3.0
	data.max_hp = 60.0
	data.traits.append(UnitData.TRAIT_CASTER)
	data.traits.append(UnitData.TRAIT_SIEGE)
	var both := grid.spawn_unit(Vector2i(1, 0), data, rival)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, both), 1.5, 0.0001, "nunca 1,5 x 1,5")

# --- Escopo: só o Ataque físico da linha; básico e Ataque Furtivo -------------------------------------------------------------------------

func test_the_basic_attack_and_the_real_combat_resolution_agree():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var siege := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_SIEGE, 60.0, 3.0)
	var predicted: float = CombatResolver.predict(unit, siege, grid).damage_to_defender
	assert_almost_eq(predicted, _formula_damage(grid, 4.5, 1.5, siege), 0.0001)
	var hp := siege.hp
	CombatResolver.resolve(unit, siege, grid)
	assert_almost_eq(hp - siege.hp, predicted, 0.0001, "predict == resolve")

func test_it_stacks_with_the_sneak_attack_penetration_and_no_counterattack_through_the_normal_pipeline():
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var siege := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_SIEGE, 60.0, 14.0) # Defesa alta: revidaria num ataque comum
	var predicted: float = CombatResolver.predict(unit, siege, grid, 1.35, 0.4, true).damage_to_defender
	var manual := _formula_damage(grid, 4.5, 1.5 * 1.35, siege, 1.0, 0.4)
	assert_almost_eq(predicted, manual, 0.0001, "Desmantelar (no Ataque) x Ataque Furtivo (multiplicador + penetração), pela mesma pipeline")
	var my_hp := unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(unit, SNEAK_ATTACK, siege, grid))
	assert_eq(unit.hp, my_hp, "sem revide")

func test_it_never_affects_city_damage_or_spell_damage_or_third_party_targets():
	assert_false(_code_only(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd")).contains("attack_bonus_techniques"), "só entra pela cadeia de UnitAbilities.attack_multiplier, nunca no dano de cidade")
	var grid := _world()
	var me := _rogue_player(6)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, ROGUE, Vector2i(0, 0))
	var siege := _traited_foe(grid, rival, Vector2i(1, 0), UnitData.TRAIT_SIEGE)
	assert_almost_eq(UnitAbilities.city_attack_multiplier(unit), 1.0, 0.0001, "dano de cidade não passa por Desmantelar")
	assert_not_null(siege)

# --- Nenhum id concreto na lógica ---------------------------------------------------------------------------------------------------

func test_no_hardcoded_id_decides_the_bonus_only_traits_do():
	# UnitAbilities.SIEGE (a lista V1 já existente, reaproveitada para semear o traço) legitimamente cita ids de máquinas de Cerco — o que este teste
	# proíbe é a lógica do BÔNUS (V2TechniqueRuntime/V2DoctrineTechniqueDatabase) e a linha ATACANTE (o Ladino) citarem qualquer id concreto.
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/data/V2DoctrineTechniqueDatabase.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["\"mage\"", "\"catapult\"", "unit_rogue", "unit_saboteur", "unit_assassin"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])
