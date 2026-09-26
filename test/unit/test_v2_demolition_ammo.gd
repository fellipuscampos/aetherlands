extends "res://test/unit/v2_combat_fixture.gd"

## Munição Demolidora (v2_technique_demolition_ammo, Aetherlands V2 Fase 11): a primeira Técnica PASSIVA que generaliza o framework de passivas de
## ATAQUE (Preparar Lanças/Desmantelar, que valem contra UNIDADE) para o ataque de CERCO contra CIDADE/FORTIFICAÇÃO — um campo novo,
## `city_attack_bonus`, consultado por V2TechniqueRuntime.city_attack_multiplier e aplicado dentro da MESMA fórmula de
## CombatResolver.resolve_city_attack. Números (+40%) = BALANCE PLACEHOLDER.

func _catapult_vs_city(through: int = 4) -> Dictionary:
	var grid := _world()
	var me := _siege_player(through)
	var rival := _rival_of(me)
	var unit := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	var city := _enemy_city(grid, rival, Vector2i(2, 0))
	return {"grid": grid, "me": me, "rival": rival, "unit": unit, "city": city}

# --- Dado ------------------------------------------------------------------------------------------------------------------------

func test_demolition_ammo_is_a_passive_with_no_cost_no_cooldown_no_action():
	var technique := _technique(DEMOLITION_AMMO)
	assert_eq(technique.display_name, "Munição Demolidora")
	assert_eq(technique.display_name, V2ResearchDatabase.node_for_unlock_id(DEMOLITION_AMMO).display_name)
	assert_eq(technique.doctrine_branch, "siege")
	assert_true(technique.is_passive())
	assert_eq(technique.cooldown_turns, 0)
	assert_false(technique.consumes_action)
	assert_almost_eq(technique.city_attack_bonus, 0.4, 0.0001, "+40% (placeholder)")
	assert_true(technique.has_city_attack_effect())
	assert_false(technique.has_attack_effect(), "não é bônus de ataque unidade-contra-unidade")
	assert_false(technique.has_defense_effect())

func test_it_generates_no_button_and_the_description_is_built_from_the_data():
	var technique := _technique(DEMOLITION_AMMO)
	assert_true(technique.description.begins_with("Passiva:"), technique.description)
	assert_true(technique.description.contains("+40% de dano de ataque contra cidades e fortificações"), technique.description)
	assert_eq(V2DoctrineTechniqueDatabase.passive_effect_text(technique), "+40% de dano de ataque contra cidades e fortificações")

func test_it_is_registered_next_to_prepared_bombardment():
	assert_true(V2DoctrineTechniqueDatabase.all_techniques().has(_technique(DEMOLITION_AMMO)))
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("siege").map(func(t): return t.id), [DEMOLITION_AMMO, PREPARED_BOMBARDMENT])
	assert_true(DEMOLITION_AMMO in V2DoctrineContent.CONNECTED_UNLOCK_IDS)
	assert_true(V2DoctrineTechniqueDatabase.city_attack_bonus_techniques().has(_technique(DEMOLITION_AMMO)))
	assert_false(V2DoctrineTechniqueDatabase.attack_bonus_techniques().has(_technique(DEMOLITION_AMMO)), "listas SEPARADAS: nunca conta como bônus unidade-contra-unidade")

# --- Disponibilidade -------------------------------------------------------------------------------------------------------------

func test_before_n4_there_is_no_bonus_and_after_it_is_active_for_every_form():
	var d := _catapult_vs_city(3)
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(d.unit), 1.0, 0.0001, "antes do N4")
	d.me.v2_research.complete_research("v2_doctrine_siege_4")
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(d.unit), 1.4, 0.0001)
	assert_true(_technique(DEMOLITION_AMMO) in V2TechniqueRuntime.passive_techniques_for_unit(d.unit))

func test_every_form_of_the_line_and_the_legend_has_it_no_other_branch_does():
	var grid := _world()
	var me := _player(9, 9, 9, 9, 9, 9)
	var index := 0
	for kind in [CATAPULT, TREBUCHET, BOMBARD, COLOSSUS]:
		var unit := _unit(grid, me, kind, Vector2i(index, 0))
		index -= 1
		assert_true(_technique(DEMOLITION_AMMO) in V2TechniqueRuntime.passive_techniques_for_unit(unit), kind)
		assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(unit), 1.4, 0.0001, kind)
	for kind in [WARRIOR, SHIELD, ARCHER, CAVALIER, ROGUE]:
		var other := _unit(grid, me, kind, Vector2i(index, 5))
		index -= 1
		assert_false(_technique(DEMOLITION_AMMO) in V2TechniqueRuntime.passive_techniques_for_unit(other), kind)
		assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(other), 1.0, 0.0001, kind)

func test_a_rival_without_n4_gets_no_bonus_and_research_does_not_leak_between_civilizations():
	var grid := _world()
	var me := _siege_player(4)
	var novice := _siege_player(3)
	var mine := _unit(grid, me, CATAPULT, Vector2i(0, 0))
	var theirs := _unit(grid, novice, CATAPULT, Vector2i(2, 2))
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(mine), 1.4, 0.0001)
	assert_almost_eq(V2TechniqueRuntime.city_attack_multiplier(theirs), 1.0, 0.0001)

# --- Aplicação: só contra cidade/fortificação ------------------------------------------------------------------------------------

func test_against_a_unit_there_is_no_bonus_only_against_a_city():
	var d := _catapult_vs_city(4)
	var foe := _foe(d.grid, d.rival, Vector2i(0, 1))
	assert_almost_eq(UnitAbilities.attack_multiplier(d.unit, foe), 1.0, 0.0001, "Munição Demolidora nunca entra no ataque contra unidade")

func test_the_basic_siege_attack_against_a_city_gets_the_bonus():
	var d := _catapult_vs_city(4)
	var city: City = d.city
	var unit: Unit = d.unit
	var hp_before := city.hp
	var shield_before := city.shield
	var expected := _city_formula_damage(unit, city, 1.0, 1.4)
	CombatResolver.resolve_city_attack(unit, city, d.grid)
	assert_almost_eq(_city_damage_taken(city, hp_before, shield_before), expected, 0.0001, "com N4, o ataque básico de Cerco contra cidade já vem com +40%")

func test_prepared_bombardment_also_gets_the_bonus():
	var d := _catapult_vs_city(6) # N4 e N6 completos
	var unit: Unit = d.unit
	var city: City = d.city
	var hp_before := city.hp
	var shield_before := city.shield
	var expected := _city_formula_damage(unit, city, 1.5, 1.4) # Bombardeio (1,5x) x Munição (1,4x) na MESMA fórmula
	CombatResolver.resolve_city_attack(unit, city, d.grid, 1.0, 1.5)
	assert_almost_eq(_city_damage_taken(city, hp_before, shield_before), expected, 0.0001)

func test_without_n4_the_multiplier_is_exactly_one_a_control_fixture():
	var novice_grid := _world()
	var novice := _siege_player(3) # sem N4
	var novice_unit := _unit(novice_grid, novice, CATAPULT, Vector2i(0, 0))
	var novice_city := _enemy_city(novice_grid, _rival_of(novice), Vector2i(2, 0))
	var hp_before := novice_city.hp
	var shield_before := novice_city.shield
	var expected := _city_formula_damage(novice_unit, novice_city) # demolition == 1.0 (padrão)
	CombatResolver.resolve_city_attack(novice_unit, novice_city, novice_grid)
	assert_almost_eq(_city_damage_taken(novice_city, hp_before, shield_before), expected, 0.0001, "sem N4, o multiplicador é 1.0: idêntico a antes da Fase 11")

func test_never_duplicates_even_with_multiple_defensive_buildings_on_the_target():
	var d := _catapult_vs_city(4)
	var city: City = d.city
	city.buildings["walls"] = true
	city.buildings["imperial_fortress"] = true
	var multiplier_a := V2TechniqueRuntime.city_attack_multiplier(d.unit)
	city.buildings["arcane_sanctuary"] = true
	var multiplier_b := V2TechniqueRuntime.city_attack_multiplier(d.unit)
	assert_almost_eq(multiplier_a, multiplier_b, 0.0001, "o número de prédios da cidade-alvo nunca duplica a técnica do atacante")
	assert_almost_eq(multiplier_a, 1.4, 0.0001)

func test_it_never_affects_lair_damage():
	var d := _catapult_vs_city(4)
	assert_true(_code_only(FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd")).contains("func resolve_lair_attack"))
	var lair_source := FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd").split("func resolve_lair_attack")[1]
	assert_false(lair_source.split("func ")[0].contains("V2TechniqueRuntime"), "Munição Demolidora não entra no ataque a covil")

# --- Save/load por derivação (sem estado guardado) -------------------------------------------------------------------------------

func test_it_is_purely_derived_no_state_is_stored_on_the_unit():
	var d := _catapult_vs_city(4)
	assert_true(d.unit.magic_status.is_empty())
	assert_true(d.unit.magic_cooldowns.is_empty())
	assert_true(V2TechniqueRuntime.status_lines(d.unit).is_empty())
	assert_true(V2TechniqueRuntime.cooldown_lines(d.unit).is_empty())

# --- Nenhum id concreto na lógica -------------------------------------------------------------------------------------------------

func test_no_hardcoded_id_decides_the_bonus():
	for path in ["res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/data/V2DoctrineTechniqueDatabase.gd", "res://scripts/core/CombatResolver.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["unit_catapult", "unit_trebuchet", "unit_bombard", "siege_colossus"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])
