extends "res://test/unit/v2_combat_fixture.gd"

## Aetherlands V2, Fase 12 — classificação semântica das unidades das seis Doutrinas. Corrige a
## dívida documentada nas Fases 10-11: o painel da unidade usava ArmyComposition.roles_for_kind
## (heurística V1 por movimento/alcance/prédio de treino) mesmo pra unidades V2, e por isso o
## Ladino (Movimento 3, acima da baseline) virava "Classe: Cavalaria" e o Cerco (alcance > 1,
## treinado num prédio V2 que a heurística não reconhece) virava só "Classe: À distância".
##
## A correção é semântica/UI, preparação pra IA futura — NÃO reequilibra combate: nenhum teste
## aqui olha Ataque/Defesa/targeting/movimento/Técnica/bônus.

const ROLES := {
	"guardian": "tank_frontline",
	"warrior": "melee_damage",
	"ranger": "ranged_combat",
	"cavalry": "mobility_shock",
	"rogue": "sabotage_assassination",
	"siege": "city_conquest",
}

## branch -> [N3, N5, N7, N9] (unlock_ids, não ids de pesquisa).
const FORMS := {
	"guardian": ["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel", "v2_legendary_guardian_champion"],
	"warrior": ["v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero"],
	"ranger": ["v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter"],
	"cavalry": ["v2_unit_cavalier", "v2_unit_shock_cavalier", "v2_unit_armored_cavalier", "v2_legendary_griffon_rider"],
	"rogue": ["v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master"],
	"siege": ["v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus"],
}

# --- V2UnitLine.role_of: a fonte canônica ---------------------------------------------------------

func test_role_of_matches_the_canonical_branch_role_for_every_form_of_every_branch():
	for branch in ROLES:
		for unit_id in FORMS[branch]:
			assert_eq(V2UnitLine.role_of(unit_id), ROLES[branch], "%s (%s)" % [unit_id, branch])

func test_role_of_is_the_same_across_n3_n5_n7_and_the_legendary_n9():
	for branch in FORMS:
		var roles: Array = FORMS[branch].map(func(id): return V2UnitLine.role_of(id))
		assert_eq(roles, [ROLES[branch], ROLES[branch], ROLES[branch], ROLES[branch]], "%s: mesma identidade em toda forma" % branch)

func test_role_of_returns_empty_for_v1_ids_and_unknown_ids():
	for kind in ["warrior", "archer", "human_knight", "settler", "scout", ""]:
		assert_eq(V2UnitLine.role_of(kind), "", kind)
	assert_eq(V2UnitLine.role_of("v2_building_guardian_hall"), "", "prédio, não unidade -- doctrine_branch_of não reconhece")
	assert_eq(V2UnitLine.role_of("v2_technique_shield_wall"), "", "técnica, não unidade")

func test_role_of_never_infers_from_name_movement_or_range():
	# Um Assassino V2 com Movimento 3 (mobilidade alta, como o Cavaleiro) continua sabotage_assassination.
	assert_eq(V2UnitLine.role_of("v2_unit_assassin"), "sabotage_assassination")
	assert_gt(UnitDatabase.create_unit("v2_unit_assassin").movement_points, 2.0)
	# O Colosso de Cerco tem alcance 3 (ranged) mas continua city_conquest, não ranged_combat.
	assert_eq(V2UnitLine.role_of("v2_legendary_siege_colossus"), "city_conquest")
	assert_gt(UnitDatabase.create_unit("v2_legendary_siege_colossus").attack_range, 1)

# --- Traits continuam ortogonais (role != trait) --------------------------------------------------

func test_role_and_traits_are_orthogonal_griffon_rider_example():
	var griffon := UnitDatabase.create_unit("v2_legendary_griffon_rider")
	assert_eq(V2UnitLine.role_of("v2_legendary_griffon_rider"), "mobility_shock")
	assert_true(griffon.has_trait(UnitData.TRAIT_MOUNTED))
	assert_true(griffon.is_flying())
	assert_true(griffon.has_trait(UnitData.TRAIT_LEGENDARY))

func test_role_and_traits_are_orthogonal_colossus_example():
	var colossus := UnitDatabase.create_unit("v2_legendary_siege_colossus")
	assert_eq(V2UnitLine.role_of("v2_legendary_siege_colossus"), "city_conquest")
	assert_true(colossus.has_trait(UnitData.TRAIT_SIEGE))
	assert_true(colossus.has_trait(UnitData.TRAIT_LEGENDARY))

# --- UI: TileInspector.unit_class_label usa a identidade V2, nunca a heurística V1 -----------------

func test_unit_class_label_uses_the_v2_branch_summary_for_every_form_of_every_branch():
	var grid := _world(15)
	var player := _player()
	var coord := Vector2i(-14, 0)
	for branch in FORMS:
		for unit_id in FORMS[branch]:
			var unit := _unit(grid, player, unit_id, coord)
			var label := TileInspector.unit_class_label(unit)
			var expected: String = V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MILITARY_DOCTRINE, branch).summary
			assert_eq(label, expected, "%s (%s)" % [unit_id, branch])
			unit.queue_free()
			coord += Vector2i(1, 0)

func test_the_rogue_is_never_labeled_cavalry_even_though_it_has_high_movement():
	var grid := _world()
	var player := _player()
	for unit_id in FORMS.rogue:
		var unit := _unit(grid, player, unit_id, Vector2i(0, FORMS.rogue.find(unit_id)))
		var label := TileInspector.unit_class_label(unit)
		assert_false(label.contains("Cavalaria"), "%s: %s" % [unit_id, label])
		unit.queue_free()

func test_siege_units_are_never_labeled_only_ranged_they_keep_the_city_conquest_identity():
	var grid := _world()
	var player := _player()
	for unit_id in FORMS.siege:
		var unit := _unit(grid, player, unit_id, Vector2i(0, FORMS.siege.find(unit_id)))
		var label := TileInspector.unit_class_label(unit)
		assert_ne(label, "À distância", "%s: %s" % [unit_id, label])
		assert_true(label.contains("Cerco") or label.contains("cidades"), "%s: %s" % [unit_id, label])
		unit.queue_free()

func test_legacy_units_fall_back_to_data_traits_and_range_only():
	# Fase 25: unidade legada de save antigo (fora das Doutrinas) é classificada só por alcance e pelos
	# TRAÇOS do dado (montado/cerco, semeados de UnitAbilities.MOUNTED/SIEGE) -- nunca mais por movimento.
	var grid := _world()
	var player := _player()
	var legacy_cavalry := _unit(grid, player, "cavalry", Vector2i(0, 0))
	assert_eq(ArmyComposition.roles_for_kind("cavalry"), [ArmyComposition.ROLE_MELEE, ArmyComposition.ROLE_CAVALRY] as Array[String])
	assert_true(TileInspector.unit_class_label(legacy_cavalry).contains(TileInspector.ROLE_LABELS["cavalry"]))
	var legacy_catapult := _unit(grid, player, "catapult", Vector2i(1, 0))
	assert_true(TileInspector.unit_class_label(legacy_catapult).contains(TileInspector.ROLE_LABELS["siege"]))

func test_army_composition_keeps_its_public_signature():
	assert_true(FileAccess.get_file_as_string("res://scripts/data/ArmyComposition.gd").contains("static func roles_for_kind(kind: String) -> Array[String]:"))

func test_army_composition_classifies_v2_kinds_by_their_doctrine_role():
	# Fase 25: a IA V2 conta papéis pela identidade da Doutrina -- o Ladino (movimento alto) é
	# sabotagem/assassinato (corpo a corpo), não cavalaria; o Cerco V2 é cerco.
	assert_true("v2_unit_rogue" in UnitDatabase.PLAYER_TRAINABLE_KINDS)
	var roles := ArmyComposition.roles_for_kind("v2_unit_rogue")
	assert_false(roles.has(ArmyComposition.ROLE_CAVALRY))
	assert_true(roles.has(ArmyComposition.ROLE_MELEE))
	assert_true(ArmyComposition.roles_for_kind("v2_legendary_siege_colossus").has(ArmyComposition.ROLE_SIEGE))
	assert_true(ArmyComposition.roles_for_kind("v2_unit_infernal_warlock").is_empty(), "conjurador não é linha de combate")
