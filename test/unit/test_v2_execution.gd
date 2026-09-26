extends "res://test/unit/v2_combat_fixture.gd"

## Execução (Aetherlands V2 Fase 7): a passiva INTRÍNSECA Lendária do Herói da Lâmina — +30% de Ataque contra unidades com
## 50% de HP ou menos. É dado de UnitData (`low_hp_attack_*`), avaliada por ALVO em UnitAbilities.attack_multiplier (a mesma
## cadeia de multiplicadores do combate); nenhum id do Herói na lógica de combate. Números = BALANCE PLACEHOLDER.

const RING := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

## O Herói em (0,0) e `count` inimigos nos vizinhos, todos com 40 HP máx. e Defesa 3.
func _hero_vs(count: int = 1, target_def: float = 3.0) -> Dictionary:
	var grid := _world()
	var me := _player(9)
	var rival := _rival_of(me)
	var hero := _unit(grid, me, HERO, Vector2i(0, 0))
	var foes: Array[Unit] = []
	for i in count:
		foes.append(_foe(grid, rival, RING[i], 40.0, target_def))
	return {"grid": grid, "me": me, "rival": rival, "hero": hero, "foes": foes}

# --- Dado ----------------------------------------------------------------------------------------------------

func test_the_passive_is_data_on_the_hero_and_only_on_the_hero():
	var hero := UnitDatabase.create_unit(HERO)
	assert_true(hero.has_low_hp_attack_bonus())
	assert_eq(hero.low_hp_attack_name, "Execução")
	assert_eq(hero.low_hp_attack_threshold, 0.5)
	assert_eq(hero.low_hp_attack_bonus, 0.3)
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind != HERO:
			assert_false(UnitDatabase.create_unit(kind).has_low_hp_attack_bonus(), "%s não tem Execução" % kind)

func test_it_is_intrinsic_not_a_research_and_not_a_technique():
	assert_null(V2DoctrineTechniqueDatabase.get_technique("v2_passive_execution"))
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_ne(technique.display_name, "Execução", "não é uma técnica de Doutrina")
	for node in V2ResearchDatabase.all_nodes():
		assert_ne(node.display_name, "Execução", "não é uma pesquisa independente")

# --- O limiar (por alvo) -------------------------------------------------------------------------------------

func test_a_target_above_half_hp_gives_no_bonus():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var foe: Unit = d.foes[0]
	foe.hp = 21.0 # 52,5%
	assert_eq(UnitAbilities.low_hp_attack_multiplier(hero, foe), 1.0)
	foe.hp = 40.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(hero, foe), 1.0)

func test_exactly_half_hp_gets_the_bonus():
	var d := _hero_vs()
	var foe: Unit = d.foes[0]
	foe.hp = 20.0 # exatamente 50%
	assert_eq(UnitAbilities.low_hp_attack_multiplier(d.hero, foe), 1.3)

func test_below_half_hp_gets_the_bonus():
	var d := _hero_vs()
	var foe: Unit = d.foes[0]
	for hp in [19.0, 10.0, 1.0]:
		foe.hp = hp
		assert_eq(UnitAbilities.low_hp_attack_multiplier(d.hero, foe), 1.3, "HP %d" % int(hp))

func test_the_threshold_uses_the_targets_own_max_hp():
	var d := _hero_vs()
	var big := _foe(d.grid, d.rival, Vector2i(2, 0), 100.0, 3.0)
	big.hp = 50.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(d.hero, big), 1.3, "50 de 100 = 50%")
	big.hp = 51.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(d.hero, big), 1.0)

# --- Ataque básico, técnicas e previsão -----------------------------------------------------------------------

func test_the_basic_attack_gets_the_bonus_and_prediction_matches_the_real_resolution():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var foe: Unit = d.foes[0]
	foe.hp = 18.0
	var expected := _formula_damage(d.grid, 12.0, 1.3, foe)
	assert_almost_eq(expected, 12.0 * 1.3 - 1.5, 0.0001)
	var predicted: float = CombatResolver.predict(hero, foe, d.grid).damage_to_defender
	assert_almost_eq(predicted, expected, 0.0001)
	var before := foe.hp
	CombatResolver.resolve(hero, foe, d.grid)
	assert_almost_eq(before - foe.hp, predicted, 0.0001, "predict == resolve")

func test_a_healthy_target_takes_the_plain_basic_attack():
	var d := _hero_vs()
	var foe: Unit = d.foes[0]
	assert_almost_eq(CombatResolver.predict(d.hero, foe, d.grid).damage_to_defender, _formula_damage(d.grid, 12.0, 1.0, foe), 0.0001)

func test_the_power_strike_combines_with_the_execution_multiplicatively():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var foe: Unit = d.foes[0]
	var strike := _technique(POWER).strike_multiplier
	# Alvo saudável: só o 1,60x. Alvo <= 50%: 1,60x E o +30% (nada do valor combinado escrito à mão).
	assert_almost_eq(CombatResolver.predict(hero, foe, d.grid, strike).damage_to_defender, _formula_damage(d.grid, 12.0, strike, foe), 0.0001)
	foe.hp = 20.0
	var execution := 1.0 + hero.unit_data.low_hp_attack_bonus # lido do dado, não escrito à mão
	var combined := _formula_damage(d.grid, 12.0, strike * execution, foe)
	assert_almost_eq(CombatResolver.predict(hero, foe, d.grid, strike).damage_to_defender, combined, 0.0001)
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(hero, POWER, foe, d.grid))
	assert_almost_eq(before - foe.hp, combined, 0.0001, "o golpe real usa os dois")
	assert_almost_eq(combined, 12.0 * 1.6 * 1.3 - 1.5, 0.0001, "12 x 1,6 x 1,3 - 3/2")

func test_the_cleave_evaluates_the_execution_per_victim():
	var d := _hero_vs(3)
	var foes: Array = d.foes
	foes[0].hp = 12.0 # 30% -> Execução
	foes[1].hp = 32.0 # 80% -> sem
	foes[2].hp = 18.0 # 45% -> Execução
	var arc := _technique(CLEAVE).strike_multiplier
	var expected_low_a := _formula_damage(d.grid, 12.0, arc * 1.3, foes[0])
	var expected_healthy := _formula_damage(d.grid, 12.0, arc, foes[1])
	var expected_low_c := _formula_damage(d.grid, 12.0, arc * 1.3, foes[2])
	assert_gt(expected_low_a, expected_healthy)
	assert_true(V2TechniqueRuntime.perform_strike(d.hero, CLEAVE, null, d.grid))
	assert_almost_eq(12.0 - foes[0].hp, expected_low_a, 0.0001, "alvo A (30%): Execução")
	assert_almost_eq(32.0 - foes[1].hp, expected_healthy, 0.0001, "alvo B (80%): sem")
	assert_almost_eq(18.0 - foes[2].hp, expected_low_c, 0.0001, "alvo C (45%): Execução")

func test_the_condition_is_read_at_each_attack_so_a_target_weakened_by_the_first_hit_counts_after_it():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var foe: Unit = d.foes[0]
	foe.hp = 25.0 # 62,5%: sem bônus agora
	assert_eq(UnitAbilities.low_hp_attack_multiplier(hero, foe), 1.0)
	foe.hp -= 6.0 # 47,5%
	assert_eq(UnitAbilities.low_hp_attack_multiplier(hero, foe), 1.3)

# --- Quem NÃO recebe -----------------------------------------------------------------------------------------

func test_other_warriors_and_other_legendaries_do_not_get_it():
	var grid := _world()
	var me := _player(9, 9)
	var rival := _rival_of(me)
	var foe := _foe(grid, rival, Vector2i(1, 0), 40.0, 3.0)
	foe.hp = 5.0
	var master := _unit(grid, me, MASTER, Vector2i(0, 0))
	var champion := _unit(grid, me, CHAMPION, Vector2i(0, 1))
	assert_eq(UnitAbilities.low_hp_attack_multiplier(master, foe), 1.0, "outro Guerreiro não recebe")
	assert_eq(UnitAbilities.low_hp_attack_multiplier(champion, foe), 1.0, "outro Lendário não recebe automaticamente")
	var fake_data := UnitDatabase.create_unit("warrior")
	fake_data.traits.append(UnitData.TRAIT_LEGENDARY)
	var fake := grid.spawn_unit(Vector2i(2, 0), fake_data, me)
	assert_eq(UnitAbilities.low_hp_attack_multiplier(fake, foe), 1.0, "o traço Lendário sozinho não dá Execução")

func test_it_does_not_apply_when_the_hero_is_the_defender():
	var grid := _world()
	var me := _player(9)
	var rival := _rival_of(me)
	var hero := _unit(grid, me, HERO, Vector2i(0, 0))
	var attacker := _foe(grid, rival, Vector2i(1, 0), 40.0, 3.0)
	attacker.hp = 5.0 # o atacante está fraco: a Execução é de quem ATACA, não de quem apanha
	var with_passive: float = CombatResolver.predict(attacker, hero, grid).damage_to_defender
	var plain_data := UnitDatabase.create_unit(HERO)
	plain_data.low_hp_attack_bonus = 0.0
	hero.unit_data = plain_data
	var without_passive: float = CombatResolver.predict(attacker, hero, grid).damage_to_defender
	assert_eq(with_passive, without_passive, "dano recebido pelo Herói não muda")

func test_it_does_not_apply_to_cities():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var master := _unit(d.grid, d.me, MASTER, Vector2i(-2, 0))
	assert_eq(UnitAbilities.city_attack_multiplier(hero), UnitAbilities.city_attack_multiplier(master), "o multiplicador de cidade não conhece a Execução")
	# A passiva só entra em attack_multiplier (unidade contra unidade): nada em resolve_city_attack a menciona.
	var source := FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd")
	var city_part := source.substr(source.find("static func resolve_city_attack"))
	assert_false(city_part.contains("low_hp_attack"))

func test_the_bonus_does_not_reach_damage_dealt_by_third_parties():
	var d := _hero_vs()
	var hero: Unit = d.hero
	var foe: Unit = d.foes[0]
	foe.hp = 10.0
	var ally := _unit(d.grid, d.me, WARRIOR, Vector2i(2, 0)) # aliado do Herói, adjacente ao alvo, com o próprio ataque
	assert_eq(UnitAbilities.low_hp_attack_multiplier(ally, foe), 1.0, "o dano do aliado nunca ganha a Execução do Herói")
	# Único bônus do aliado: o flanco (+15%, o Herói também está adjacente ao alvo) — nenhum +30%.
	var flank := 1.0 + CombatResolver.FLANKING_BONUS_PER_ALLY
	assert_almost_eq(CombatResolver.predict(ally, foe, d.grid).damage_to_defender, _formula_damage(d.grid, 5.0, flank, foe), 0.0001)
	assert_true(hero.unit_data.has_low_hp_attack_bonus())

# --- Generalidade (dado, não código) ---------------------------------------------------------------------------

func test_the_effect_is_driven_by_the_data_any_unit_can_carry_it():
	var d := _hero_vs()
	var foe: Unit = d.foes[0]
	foe.hp = 8.0
	var data := UnitDatabase.create_unit("warrior")
	data.low_hp_attack_name = "Golpe de Misericórdia"
	data.low_hp_attack_threshold = 0.25
	data.low_hp_attack_bonus = 0.5
	var custom: Unit = d.grid.spawn_unit(Vector2i(-1, 0), data, d.me)
	foe.hp = 10.0 # 25%: no limiar
	assert_eq(UnitAbilities.low_hp_attack_multiplier(custom, foe), 1.5)
	foe.hp = 11.0
	assert_eq(UnitAbilities.low_hp_attack_multiplier(custom, foe), 1.0)

func test_no_hero_id_or_name_appears_in_the_combat_logic():
	for path in ["res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/core/V2TechniqueRuntime.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["blade_hero", "Herói da Lâmina", "v2_legendary_blade"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

# --- UI ------------------------------------------------------------------------------------------------------

func test_the_owner_panel_lines_and_the_public_inspector_fact():
	var d := _hero_vs()
	var hero: Unit = d.hero
	assert_eq(UnitAbilities.low_hp_attack_lines(hero), ["Passiva Lendária — Execução", "+30% de Ataque contra unidades com 50% de HP ou menos."])
	assert_true(UnitAbilities.low_hp_attack_lines(_unit(d.grid, d.me, MASTER, Vector2i(-2, 0))).is_empty())
	var traits := TileInspector.unit_traits(hero)
	assert_true("Lendária" in traits)
	assert_true(traits.any(func(t): return t.begins_with("Execução (+30% Ataque")), str(traits))
