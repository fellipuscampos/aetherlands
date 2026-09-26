extends "res://test/unit/v2_combat_fixture.gd"

## Caçada Lendária (Aetherlands V2 Fase 8): a passiva INTRÍNSECA Lendária do Caçador de Lendas — +40% de Ataque contra alvos com o TRAÇO `legendary`. É dado de
## UnitData (`trait_attack_*`), avaliada por ALVO em UnitAbilities.attack_multiplier (a mesma cadeia da Execução e dos demais fatores); identifica o alvo pelo traço,
## nunca por id/nome, e a lista de traços aceita vários. Números (+40%) = BALANCE PLACEHOLDER.

func _hunt(distance: int = 2, target_kind: String = "") -> Dictionary:
	var grid := _world()
	var me := _ranger_player(9, 9, 9)
	var rival := _rival_of(me)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var target: Unit = null
	if target_kind == "":
		target = _foe_at(grid, rival, hunter, distance, 60.0, 3.0)
	else:
		target = _unit(grid, rival, target_kind, _coord_at(grid, hunter.coord, distance))
	return {"grid": grid, "me": me, "rival": rival, "hunter": hunter, "target": target}

# --- Dado --------------------------------------------------------------------------------------------------------------------

func test_the_passive_is_data_on_the_legend_hunter_and_only_on_it():
	var hunter := UnitDatabase.create_unit(LEGEND_HUNTER)
	assert_true(hunter.has_trait_attack_bonus())
	assert_eq(hunter.trait_attack_name, "Caçada Lendária")
	assert_eq(hunter.trait_attack_target_traits, [UnitData.TRAIT_LEGENDARY] as Array[String])
	assert_eq(hunter.trait_attack_bonus, 0.4)
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if kind != LEGEND_HUNTER:
			assert_false(UnitDatabase.create_unit(kind).has_trait_attack_bonus(), "%s não tem Caçada Lendária" % kind)

func test_it_is_intrinsic_not_a_research_and_not_a_technique():
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		assert_ne(technique.display_name, "Caçada Lendária")
	for node in V2ResearchDatabase.all_nodes():
		assert_ne(node.display_name, "Caçada Lendária", "não é uma pesquisa independente")

# --- O alvo é reconhecido pelo TRAÇO -------------------------------------------------------------------------------------------

func test_a_normal_target_gives_no_bonus():
	var d := _hunt(2)
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, d.target), 1.0)
	for kind in [SENTINEL, SHIELD, MASTER, MARKSMAN]:
		var grid := _world()
		var me := _player(9, 9, 9)
		var rival := _rival_of(me)
		var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
		var target := _unit(grid, rival, kind, Vector2i(2, 0))
		assert_eq(UnitAbilities.trait_attack_multiplier(hunter, target), 1.0, "%s: unidade convencional, sem bônus" % kind)

func test_the_champion_the_hero_and_another_legend_hunter_get_the_bonus():
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		var d := _hunt(2, kind)
		assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, d.target), 1.4, "%s: Lendária" % kind)

func test_the_target_is_identified_by_trait_not_by_id_or_name():
	var d := _hunt(2)
	var fake_data := UnitDatabase.create_unit("warrior")
	fake_data.visual_kind = "qualquer_id_xyz"
	fake_data.unit_name = "Coisa Qualquer"
	fake_data.traits.append(UnitData.TRAIT_LEGENDARY)
	var fake: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 1), fake_data, d.rival)
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, fake), 1.4, "o traço basta, mesmo com id desconhecido")
	var impostor_data := UnitDatabase.create_unit("warrior")
	impostor_data.visual_kind = CHAMPION
	impostor_data.unit_name = "Campeão Guardião"
	var impostor: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 3), impostor_data, d.rival)
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, impostor), 1.0, "nome/id do Campeão sem o traço não valem")

func test_the_bonus_applies_once_even_when_several_listed_traits_match():
	var d := _hunt(2)
	var data := UnitDatabase.create_unit("warrior")
	data.trait_attack_bonus = 0.5
	data.trait_attack_target_traits.append(UnitData.TRAIT_MOUNTED)
	data.trait_attack_target_traits.append(UnitData.TRAIT_LEGENDARY)
	var custom: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 1), data, d.me)
	var both_data := UnitDatabase.create_unit("warrior")
	both_data.traits.append(UnitData.TRAIT_MOUNTED)
	both_data.traits.append(UnitData.TRAIT_LEGENDARY)
	var both: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 3), both_data, d.rival)
	assert_eq(UnitAbilities.trait_attack_multiplier(custom, both), 1.5, "uma vez só, não 1,5 x 1,5")
	var mounted_only_data := UnitDatabase.create_unit("cavalry")
	var mounted: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 4), mounted_only_data, d.rival)
	assert_eq(UnitAbilities.trait_attack_multiplier(custom, mounted), 1.5, "a lista aceita OUTROS traços (futuras categorias)")
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, mounted), 1.0, "o Caçador de Lendas só lista `legendary`")

func test_the_effect_is_driven_by_the_data_any_unit_can_carry_it():
	var d := _hunt(2, CHAMPION)
	var data := UnitDatabase.create_unit("warrior")
	data.trait_attack_name = "Caçada a Monstros"
	data.trait_attack_bonus = 0.25
	data.trait_attack_target_traits.append(UnitData.TRAIT_LEGENDARY)
	var custom: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 1), data, d.me)
	assert_eq(UnitAbilities.trait_attack_multiplier(custom, d.target), 1.25)

func test_no_hunter_id_or_name_appears_in_the_combat_logic():
	for path in ["res://scripts/core/CombatResolver.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/core/V2TechniqueRuntime.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["legend_hunter", "Caçador de Lendas", "v2_legendary_", "v2_unit_archer", "Arqueiro", "Saraivada", "Disparo Preciso"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

# --- Ataque básico, Disparo Preciso e Saraivada ----------------------------------------------------------------------------------------

func test_the_basic_attack_gets_the_bonus_and_prediction_matches_the_real_resolution():
	var d := _hunt(2, CHAMPION)
	var hunter: Unit = d.hunter
	var target: Unit = d.target
	var expected := _formula_damage(d.grid, 11.0, 1.4, target)
	assert_almost_eq(CombatResolver.predict(hunter, target, d.grid).damage_to_defender, expected, 0.0001)
	assert_gt(expected, _formula_damage(d.grid, 11.0, 1.0, target))
	var hp := target.hp
	CombatResolver.resolve(hunter, target, d.grid)
	assert_almost_eq(hp - target.hp, expected, 0.0001, "predict == resolve")

func test_a_normal_target_takes_the_plain_basic_attack():
	var d := _hunt(2)
	assert_almost_eq(CombatResolver.predict(d.hunter, d.target, d.grid).damage_to_defender, _formula_damage(d.grid, 11.0, 1.0, d.target), 0.0001)

func test_the_precise_shot_combines_with_the_hunt_multiplicatively():
	var d := _hunt(4, HERO) # a 4 tiles: só o Disparo Preciso (alcance básico 3 + 1) chega
	var hunter: Unit = d.hunter
	var target: Unit = d.target
	var shot := _technique(PRECISE).strike_multiplier
	var hunt := 1.0 + hunter.unit_data.trait_attack_bonus # lido do dado
	var combined := _formula_damage(d.grid, 11.0, shot * hunt, target)
	assert_almost_eq(CombatResolver.predict(hunter, target, d.grid, shot).damage_to_defender, combined, 0.0001)
	var hp := target.hp
	assert_true(V2TechniqueRuntime.perform_strike(hunter, PRECISE, target, d.grid))
	assert_almost_eq(hp - target.hp, combined, 0.0001, "o disparo real usa os dois")
	assert_almost_eq(combined, 11.0 * 1.4 * 1.4 - target.unit_data.defense * 0.5, 0.0001, "11 x 1,4 x 1,4 - Def/2 (valor não escrito em lugar nenhum)")

func test_the_volley_evaluates_the_hunt_per_victim():
	var grid := _world()
	var me := _ranger_player(9)
	var rival := _rival_of(me)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var champion := _unit(grid, rival, CHAMPION, Vector2i(2, 0)) # primário: Lendária
	var sentinel := _unit(grid, rival, SENTINEL, Vector2i(3, 0)) # vizinho: convencional
	var hero := _unit(grid, rival, HERO, Vector2i(3, -1)) # vizinho: Lendária
	var volley := _technique(VOLLEY).strike_multiplier
	var hunt := 1.0 + hunter.unit_data.trait_attack_bonus
	# A aura do Campeão (raio 2) protege os aliados a <= 2 dele: o Sentinela (1) e o Herói (1); o próprio Campeão não.
	var aura: float = 1.0 + UnitDatabase.create_unit(CHAMPION).aura_defense_bonus
	var expected_champion := _formula_damage(grid, 11.0, volley * hunt, champion)
	var expected_sentinel := _formula_damage(grid, 11.0, volley, sentinel, aura)
	var expected_hero := _formula_damage(grid, 11.0, volley * hunt, hero, aura)
	var hp := {champion: champion.hp, sentinel: sentinel.hp, hero: hero.hp}
	assert_true(V2TechniqueRuntime.perform_strike(hunter, VOLLEY, champion, grid))
	assert_almost_eq(hp[champion] - champion.hp, expected_champion, 0.0001, "Campeão Guardião: bônus")
	assert_almost_eq(hp[sentinel] - sentinel.hp, expected_sentinel, 0.0001, "Sentinela: sem bônus")
	assert_almost_eq(hp[hero] - hero.hp, expected_hero, 0.0001, "Herói da Lâmina: bônus")

# --- Quem NÃO recebe / não vale ---------------------------------------------------------------------------------------------------------------

func test_other_units_never_get_the_hunt_even_against_a_legendary():
	var d := _hunt(2, CHAMPION)
	var marksman: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 1), UnitDatabase.create_unit(MARKSMAN), d.me)
	var hero_data := UnitDatabase.create_unit(HERO)
	var hero_unit: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 3), hero_data, d.me)
	assert_eq(UnitAbilities.trait_attack_multiplier(marksman, d.target), 1.0)
	assert_eq(UnitAbilities.trait_attack_multiplier(hero_unit, d.target), 1.0, "outra Lendária não recebe automaticamente")

func test_it_does_not_apply_when_the_legend_hunter_is_the_defender():
	var grid := _world()
	var me := _ranger_player(9, 9)
	var rival := _rival_of(me)
	var hunter := _unit(grid, me, LEGEND_HUNTER, Vector2i(0, 0))
	var champion := _unit(grid, rival, CHAMPION, Vector2i(1, 0))
	var with_passive: float = CombatResolver.predict(champion, hunter, grid).damage_to_defender
	var plain := UnitDatabase.create_unit(LEGEND_HUNTER)
	plain.trait_attack_bonus = 0.0
	hunter.unit_data = plain
	assert_eq(with_passive, CombatResolver.predict(champion, hunter, grid).damage_to_defender, "o dano recebido não muda")

func test_it_does_not_apply_to_cities():
	var d := _hunt(2)
	var marksman: Unit = d.grid.spawn_unit(_coord_at(d.grid, d.hunter.coord, 1), UnitDatabase.create_unit(MARKSMAN), d.me)
	assert_eq(UnitAbilities.city_attack_multiplier(d.hunter), UnitAbilities.city_attack_multiplier(marksman))
	var source := FileAccess.get_file_as_string("res://scripts/core/CombatResolver.gd")
	assert_false(source.substr(source.find("static func resolve_city_attack")).contains("trait_attack"))

func test_a_rival_civilization_with_a_legend_hunter_works_the_same():
	var grid := _world()
	var me := _player(9, 9, 9)
	var rival := _rival_of(me)
	var enemy_hunter := _unit(grid, rival, LEGEND_HUNTER, Vector2i(0, 0))
	var my_champion := _unit(grid, me, CHAMPION, Vector2i(2, 0))
	var expected := _formula_damage(grid, 11.0, 1.4, my_champion)
	assert_almost_eq(CombatResolver.predict(enemy_hunter, my_champion, grid).damage_to_defender, expected, 0.0001)
	var hp := my_champion.hp
	CombatResolver.resolve(enemy_hunter, my_champion, grid)
	assert_almost_eq(hp - my_champion.hp, expected, 0.0001)

func test_the_hunt_is_read_at_each_attack_from_the_targets_trait():
	var d := _hunt(2)
	var target: Unit = d.target
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, target), 1.0)
	target.unit_data.traits.append(UnitData.TRAIT_LEGENDARY)
	assert_eq(UnitAbilities.trait_attack_multiplier(d.hunter, target), 1.4)

# --- UI ---------------------------------------------------------------------------------------------------------------------------------------------

func test_the_owner_panel_lines_and_the_public_inspector_fact():
	var d := _hunt(2)
	var hunter: Unit = d.hunter
	assert_eq(UnitAbilities.trait_attack_lines(hunter), ["Passiva Lendária — Caçada Lendária", "+40% de Ataque contra Unidades Lendárias."])
	assert_eq(UnitAbilities.intrinsic_attack_lines(hunter), UnitAbilities.trait_attack_lines(hunter), "sem Execução, só a Caçada")
	var hero: Unit = d.grid.spawn_unit(_coord_at(d.grid, hunter.coord, 1), UnitDatabase.create_unit(HERO), d.me)
	assert_eq(UnitAbilities.intrinsic_attack_lines(hero), UnitAbilities.low_hp_attack_lines(hero), "o Herói só tem a Execução")
	assert_true(UnitAbilities.trait_attack_lines(hero).is_empty())
	var traits := TileInspector.unit_traits(hunter)
	assert_true("Lendária" in traits)
	assert_true(traits.any(func(t): return t.begins_with("Caçada Lendária (+40% de Ataque contra Unidades Lendárias")), str(traits))
