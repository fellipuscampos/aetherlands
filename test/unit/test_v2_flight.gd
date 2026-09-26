extends "res://test/unit/v2_combat_fixture.gd"

## Perfil de movimento FLYING (voo tático) e a vulnerabilidade a ataques à distância — Aetherlands V2 Fase 9. O Cavaleiro de Grifo é a primeira unidade FLYING:
## atravessa qualquer terreno e qualquer unidade no meio do caminho (até o Movimento, em distância geométrica), mas TERMINA só num tile de terra livre (o mesmo
## que uma unidade terrestre poderia ocupar). A Carga e a Retirada Tática usam o perfil aéreo sem código específico. A unidade terrestre segue EXATAMENTE como
## antes. Números = BALANCE PLACEHOLDER.

func _rival_with_ranger(me: PlayerData) -> PlayerData:
	var rival := _ranger_player(9)
	Diplomacy.declare_war(me, rival)
	assert_true(me.is_at_war_with(rival), "pré-condição: em guerra")
	return rival

## Cavaleiro de Grifo (N9) em (0,0) e um rival em guerra.
func _sky() -> Dictionary:
	var grid := _world()
	var me := _cavalry_player(9)
	var rival := _rival_of(me)
	var griffon := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	return {"grid": grid, "me": me, "rival": rival, "unit": griffon}

func _wall_of(grid: HexGrid, q: int, terrain: HexTileData.TerrainType) -> void:
	for r in range(-6, 7):
		if grid.tiles.has(Vector2i(q, r)):
			_set_terrain(grid, Vector2i(q, r), terrain)

# --- O perfil é dado da unidade; o terrestre não muda -------------------------------------------------------------------------------------

func test_only_the_griffon_has_the_flying_profile_and_every_other_kind_is_ground_or_infiltrator():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var data := UnitDatabase.create_unit(kind)
		if kind in [GRIFFON, "v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_veil_archon", "v2_manifestation_elemental_primordial"]:
			assert_eq(data.movement_profile, UnitData.MovementProfile.FLYING)
			assert_true(data.has_trait(UnitData.TRAIT_FLYING), "o traço semântico acompanha o perfil")
		else:
			# Fase 10: o Mestre das Sombras é INFILTRATOR (Passo Sombrio); nenhuma outra forma é FLYING nem INFILTRATOR.
			var expected := UnitData.MovementProfile.INFILTRATOR if kind == "v2_legendary_shadow_master" else UnitData.MovementProfile.GROUND
			assert_eq(data.movement_profile, expected, kind)
			# o traço "voa" só acompanha o perfil FLYING; o voo V1 (`flies`: grifo/elemental de tempestade) segue como sempre (is_flying() cobre os dois)
			assert_false(data.has_trait(UnitData.TRAIT_FLYING), kind)
			assert_eq(data.is_flying(), data.flies, kind)

func test_the_flying_trait_is_seeded_from_the_profile_not_from_the_id():
	var data := UnitDatabase.create_unit("warrior")
	assert_false(data.has_trait(UnitData.TRAIT_FLYING))
	data.movement_profile = UnitData.MovementProfile.FLYING
	assert_true(data.is_flying(), "is_flying lê o perfil, não um id")

func test_a_ground_unit_takes_exactly_the_old_reachable_call():
	var grid := _world()
	var me := _cavalry_player(9)
	_set_costly(grid, Vector2i(1, 0), 2)
	_set_terrain(grid, Vector2i(0, 2), HexTileData.TerrainType.OCEAN)
	_unit(grid, me, WARRIOR, Vector2i(-1, 1))
	for kind in [CAVALIER, WARRIOR, ARMORED]:
		var unit := _unit(grid, me, kind, Vector2i(-2 if kind == CAVALIER else (2 if kind == WARRIOR else 3), -2))
		var old := grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies, unit.embarked)
		assert_eq(grid.unit_reachable(unit), old, kind)
	var v1_flat := grid.compute_reachable(Vector2i(0, 0), 3.0, me, false, false, false)
	var flat_off := grid.compute_reachable(Vector2i(0, 0), 3.0, me)
	assert_eq(v1_flat, flat_off, "flat_cost desligado é o comportamento de sempre")

func test_the_v1_flyer_is_unchanged_it_keeps_the_free_flight_it_always_had():
	var grid := _world()
	var me := _cavalry_player(0)
	_set_terrain(grid, Vector2i(1, 0), HexTileData.TerrainType.OCEAN)
	_set_terrain(grid, Vector2i(2, 0), HexTileData.TerrainType.MOUNTAINS)
	var monster := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("griffin"), me)
	assert_true(monster.unit_data.flies)
	assert_eq(monster.unit_data.movement_profile, UnitData.MovementProfile.GROUND, "o voo V1 não passa pelo perfil novo")
	var reach := grid.unit_reachable(monster)
	assert_eq(reach, grid.compute_reachable(monster.coord, monster.movement_left, me, true, false))
	assert_true(reach.has(Vector2i(1, 0)), "o voo V1 segue podendo pousar no oceano")

# --- O alcance do voo -------------------------------------------------------------------------------------------------------------------

func test_the_griffon_reaches_every_free_land_tile_within_its_movement_by_geometric_distance():
	var s := _sky()
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_eq(reach.size(), HexMetrics.coords_within(Vector2i(0, 0), 5).size(), "todos os tiles do raio 5 (coords_within já exclui o centro)")
	for coord in reach:
		assert_eq(reach[coord], float(HexMetrics.axial_distance(Vector2i(0, 0), coord)), "custo = distância")
	assert_false(reach.has(Vector2i(0, 0)))
	assert_false(reach.has(Vector2i(6, 0)), "6 passos: além do movimento 5")

func test_it_flies_over_water_mountains_and_units_in_the_middle_of_the_route():
	var s := _sky()
	_wall_of(s.grid, 1, HexTileData.TerrainType.OCEAN)
	_wall_of(s.grid, 2, HexTileData.TerrainType.MOUNTAINS)
	_foe(s.grid, s.rival, Vector2i(3, 0))
	_foe(s.grid, s.rival, Vector2i(3, -1))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(4, 0)), "atravessa oceano, montanha e inimigos")
	assert_true(reach.has(Vector2i(5, 0)))
	var ground := _unit(s.grid, s.me, CAVALIER, Vector2i(0, 3))
	assert_false(s.grid.unit_reachable(ground).has(Vector2i(4, 0)), "a unidade terrestre não")

func test_it_never_ends_on_water_lava_mountain_or_an_occupied_tile():
	var s := _sky()
	_set_terrain(s.grid, Vector2i(2, 0), HexTileData.TerrainType.OCEAN)
	_set_terrain(s.grid, Vector2i(0, 2), HexTileData.TerrainType.MOUNTAINS)
	_set_terrain(s.grid, Vector2i(-2, 0), HexTileData.TerrainType.LAVA)
	_set_terrain(s.grid, Vector2i(-2, 2), HexTileData.TerrainType.FROZEN_OCEAN)
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 1))
	_foe(s.grid, s.rival, Vector2i(3, -1))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	for coord in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(-2, 2), Vector2i(1, 1), Vector2i(3, -1)]:
		assert_false(reach.has(coord), "%s não é pouso legal" % str(coord))
	for coord in reach:
		assert_false(s.grid.get_tile(coord).blocks_land_units(), "todo pouso é um tile que uma unidade terrestre ocuparia")
		assert_null(s.grid.get_unit_at(coord))

func test_an_enemy_city_is_never_a_landing_but_an_own_city_is():
	var s := _sky()
	var enemy_city: City = s.grid.found_city(Vector2i(3, 0), s.rival, "Rival", true)
	var own_city: City = s.grid.found_city(Vector2i(-3, 0), s.me, "Minha", true)
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_false(reach.has(Vector2i(3, 0)), "cidade inimiga")
	assert_true(reach.has(Vector2i(-3, 0)), "cidade própria")
	assert_not_null(enemy_city)
	assert_not_null(own_city)

func test_the_reach_shrinks_with_the_movement_left_and_is_empty_without_it():
	var s := _sky()
	s.unit.movement_left = 2.0
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(2, 0)))
	assert_false(reach.has(Vector2i(3, 0)))
	s.unit.movement_left = 0.0
	assert_true(s.grid.unit_reachable(s.unit).is_empty())
	assert_true(s.grid.unit_reachable(s.unit, 0.4).is_empty(), "frações não dão passo")

func test_an_explicit_budget_overrides_the_movement_left_and_ignores_the_flat_cost_flag():
	var s := _sky()
	var three: Dictionary = s.grid.unit_reachable(s.unit, 3.0)
	assert_eq(three.size(), HexMetrics.coords_within(Vector2i(0, 0), 3).size())
	assert_eq(three, s.grid.unit_reachable(s.unit, 3.0, true), "o voo já custa 1 por passo: a flag é irrelevante")

func test_flight_looks_only_at_the_movement_radius_never_at_the_whole_map():
	var source := _code_only(FileAccess.get_file_as_string("res://scripts/world/HexGrid.gd"))
	var start := source.find("func flight_reachable")
	var body := source.substr(start, source.find("func infiltrate_reachable") - start) # o vizinho de baixo (Fase 10) É um Dijkstra por dado, de propósito
	assert_true(body.contains("coords_within"))
	assert_false(body.contains("compute_reachable"))
	assert_false(body.contains("tiles.keys"), "sem varrer o mapa")
	assert_false(body.contains("frontier"), "sem BFS global")

# --- Mover de verdade -------------------------------------------------------------------------------------------------------------------

func test_the_unit_really_moves_spends_the_distance_and_the_grid_registers_it():
	var s := _sky()
	_wall_of(s.grid, 1, HexTileData.TerrainType.OCEAN)
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	s.grid.move_unit(s.unit, Vector2i(3, 0), reach[Vector2i(3, 0)])
	assert_eq(s.unit.coord, Vector2i(3, 0))
	assert_eq(s.unit.movement_left, 2.0, "5 - 3")
	assert_eq(s.grid.get_unit_at(Vector2i(3, 0)), s.unit)
	assert_null(s.grid.get_unit_at(Vector2i(0, 0)))

func test_the_flight_path_is_a_straight_line_with_the_right_length_ending_at_the_target():
	var s := _sky()
	for target in [Vector2i(4, 0), Vector2i(3, -2), Vector2i(-2, 3), Vector2i(0, -5), Vector2i(5, -5)]:
		var line: Array[Vector2i] = s.grid.flight_path(Vector2i(0, 0), target)
		assert_eq(line.size(), HexMetrics.axial_distance(Vector2i(0, 0), target), str(target))
		assert_eq(line[line.size() - 1], target)
		var previous := Vector2i(0, 0)
		for coord in line:
			assert_eq(HexMetrics.axial_distance(previous, coord), 1, "passos contíguos")
			previous = coord

func test_the_animation_uses_the_straight_line_for_the_flyer_and_never_crashes_over_water():
	var s := _sky()
	_wall_of(s.grid, 2, HexTileData.TerrainType.OCEAN)
	var waypoints: Array[Vector3] = s.grid._animation_waypoints(Vector2i(0, 0), Vector2i(4, 0), s.unit, false)
	assert_eq(waypoints.size(), 4)
	var ground := _unit(s.grid, s.me, CAVALIER, Vector2i(0, 3))
	assert_true(s.grid._animation_waypoints(Vector2i(0, 3), Vector2i(1, 3), ground, false).size() <= 1)

# --- Carga aérea ---------------------------------------------------------------------------------------------------------------------------

func test_ground_cavalry_is_stopped_by_a_water_barrier_and_the_griffon_charges_across_it():
	var grid := _world()
	var me := _cavalry_player(9)
	var rival := _rival_of(me)
	_wall_of(grid, 2, HexTileData.TerrainType.OCEAN)
	var ground := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	var griffon := _unit(grid, me, GRIFFON, Vector2i(0, 1))
	var foe := _foe(grid, rival, Vector2i(4, 0))
	assert_false(V2TechniqueRuntime.can_use(ground, CHARGE, grid), "a cavalaria terrestre não atravessa o mar")
	assert_eq(V2TechniqueRuntime.unavailable_reason(ground, CHARGE, grid), "Sem rota até um tile adjacente ao alvo.")
	assert_true(V2TechniqueRuntime.can_use(griffon, CHARGE, grid), "o Grifo voa por cima")
	var before := foe.hp
	assert_true(V2TechniqueRuntime.perform_strike(griffon, CHARGE, foe, grid))
	assert_eq(HexMetrics.axial_distance(griffon.coord, foe.coord), 1, "termina adjacente")
	assert_false(grid.get_tile(griffon.coord).blocks_land_units(), "num tile de terra")
	assert_eq(griffon.coord, Vector2i(3, 0), "o tile adjacente legal de menor custo")
	assert_almost_eq(before - foe.hp, _formula_damage(grid, 10.0, 1.5, foe), 0.0001, "10,0 x 1,5 - 3,0 x 0,5")

func test_the_aerial_charge_crosses_units_in_the_middle_of_the_route():
	var s := _sky()
	for coord in [Vector2i(1, 0), Vector2i(2, 0)]:
		_foe(s.grid, s.rival, coord)
	var foe := _foe(s.grid, s.rival, Vector2i(4, 0))
	assert_true(V2TechniqueRuntime.perform_strike(s.unit, CHARGE, foe, s.grid))
	assert_eq(HexMetrics.axial_distance(s.unit.coord, foe.coord), 1)

func test_the_aerial_charge_never_lands_on_water_it_needs_a_free_land_tile_next_to_the_target():
	var s := _sky()
	var foe := _foe(s.grid, s.rival, Vector2i(3, 0))
	for coord in s.grid.get_neighbors(foe.coord):
		if coord != Vector2i(2, 0):
			_set_terrain(s.grid, coord, HexTileData.TerrainType.OCEAN)
	_set_terrain(s.grid, Vector2i(2, 0), HexTileData.TerrainType.MOUNTAINS)
	assert_true(V2TechniqueRuntime.strike_targets(s.unit, _technique(CHARGE), s.grid).is_empty())
	assert_eq(V2TechniqueRuntime.unavailable_reason(s.unit, CHARGE, s.grid), "Sem rota até um tile adjacente ao alvo.")
	assert_false(V2TechniqueRuntime.perform_strike(s.unit, CHARGE, foe, s.grid))
	assert_eq(s.unit.coord, Vector2i(0, 0), "sem movimento parcial")
	assert_false(s.unit.magic_cooldowns.has(CHARGE))
	_set_terrain(s.grid, Vector2i(2, 0), HexTileData.TerrainType.GRASSLAND)
	assert_true(V2TechniqueRuntime.can_use(s.unit, CHARGE, s.grid), "com um pouso legal volta a valer")

func test_the_aerial_approach_tile_tie_is_broken_by_the_stable_coordinate():
	var s := _sky()
	var foe := _foe(s.grid, s.rival, Vector2i(3, -1))
	var movable: Dictionary = s.grid.unit_reachable(s.unit)
	assert_eq(V2TechniqueRuntime._approach_tile(s.unit, foe, movable, s.grid), Vector2i(2, -1), "menor q, depois menor r")

func test_the_aerial_charge_keeps_the_same_multiplier_cooldown_and_action_rules():
	var s := _sky()
	var foe := _foe(s.grid, s.rival, Vector2i(3, 0))
	assert_true(V2TechniqueRuntime.perform_strike(s.unit, CHARGE, foe, s.grid))
	assert_eq(int(s.unit.magic_cooldowns[CHARGE]), 5 + 3)
	assert_eq(s.unit.movement_left, 0.0)
	s.me.gold = 50.0
	s.me.mana = 20.0
	s.unit.movement_left = 5.0
	s.unit.magic_cooldowns.erase(CHARGE)
	var second := _foe(s.grid, s.rival, _coord_at(s.grid, s.unit.coord, 3))
	assert_true(V2TechniqueRuntime.perform_strike(s.unit, CHARGE, second, s.grid))
	assert_eq([s.me.gold, s.me.mana], [50.0, 20.0], "zero Ouro e zero Mana")

func test_the_charge_window_is_still_2_to_4_for_the_flyer():
	var adjacent := _sky()
	_foe(adjacent.grid, adjacent.rival, Vector2i(1, 0))
	assert_eq(V2TechniqueRuntime.unavailable_reason(adjacent.unit, CHARGE, adjacent.grid), "Requer espaço para realizar a Carga.")
	var far := _sky()
	_foe(far.grid, far.rival, Vector2i(5, 0))
	assert_eq(V2TechniqueRuntime.unavailable_reason(far.unit, CHARGE, far.grid), "Nenhum inimigo ao alcance.", "o alcance da Carga é 4 mesmo com movimento 5")

# --- Retirada aérea ------------------------------------------------------------------------------------------------------------------------

func test_a_walled_in_griffon_still_retreats_ground_cavalry_would_have_nowhere_to_go():
	var grid := _world()
	var me := _cavalry_player(9)
	var ground := _unit(grid, me, CAVALIER, Vector2i(0, 0))
	for coord in grid.get_neighbors(Vector2i(0, 0)):
		_set_terrain(grid, coord, HexTileData.TerrainType.MOUNTAINS)
	assert_eq(V2TechniqueRuntime.unavailable_reason(ground, RETREAT, grid), "Nenhum tile livre ao alcance.")
	grid.remove_unit(ground)
	var griffon := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	var tiles := V2TechniqueRuntime.relocation_tiles(griffon, _technique(RETREAT), grid)
	assert_eq(tiles.size(), 30, "36 do raio 3, menos os 6 da montanha")
	assert_true(Vector2i(2, 0) in tiles and Vector2i(-3, 0) in tiles)
	assert_false(Vector2i(1, 0) in tiles, "nunca pousa na montanha")
	assert_true(V2TechniqueRuntime.relocate(griffon, RETREAT, Vector2i(3, 0), grid))
	assert_eq(griffon.coord, Vector2i(3, 0))

func test_the_aerial_retreat_ignores_water_and_units_but_lands_only_on_legal_tiles():
	var s := _sky()
	_wall_of(s.grid, 1, HexTileData.TerrainType.OCEAN)
	_unit(s.grid, s.me, WARRIOR, Vector2i(2, 0))
	_foe(s.grid, s.rival, Vector2i(2, -1))
	var tiles := V2TechniqueRuntime.relocation_tiles(s.unit, _technique(RETREAT), s.grid)
	assert_true(Vector2i(3, 0) in tiles, "por cima do oceano e das unidades")
	assert_false(Vector2i(1, 0) in tiles, "oceano")
	assert_false(Vector2i(2, 0) in tiles, "ocupado")
	assert_false(Vector2i(4, 0) in tiles, "o alcance da técnica é 3, não o movimento 5")
	for coord in tiles:
		assert_false(s.grid.get_tile(coord).blocks_land_units())

func test_the_aerial_retreat_grants_the_same_defense_bonus_and_costs_the_same():
	var s := _sky()
	assert_true(V2TechniqueRuntime.relocate(s.unit, RETREAT, Vector2i(-2, 1), s.grid))
	assert_eq(V2TechniqueRuntime.defense_multiplier(s.unit, s.grid), 1.2)
	assert_eq(s.unit.movement_left, 0.0)
	assert_eq(int(s.unit.magic_cooldowns[RETREAT]), 5 + 4)

# --- Vulnerabilidade a ataques à distância -----------------------------------------------------------------------------------------------

func test_the_griffon_takes_25_percent_more_from_a_basic_ranged_attack():
	var s := _sky()
	var rival := _rival_with_ranger(s.me)
	var archer := _unit(s.grid, rival, ARCHER, Vector2i(2, 0))
	var attack := UnitDatabase.create_unit(ARCHER).attack
	var prediction: Dictionary = CombatResolver.predict(archer, s.unit, s.grid)
	assert_almost_eq(prediction.damage_to_defender, _formula_damage(s.grid, attack, 1.0, s.unit) * 1.25, 0.0001)
	assert_gt(prediction.damage_to_defender, _formula_damage(s.grid, attack, 1.0, s.unit))

func test_melee_attacks_never_get_the_vulnerability_bonus():
	var s := _sky()
	var brute_data := UnitDatabase.create_unit("warrior")
	brute_data.attack = 12.0
	var brute: Unit = s.grid.spawn_unit(Vector2i(1, 0), brute_data, s.rival)
	assert_eq(brute.unit_data.attack_range, 1)
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(brute, s.unit), 1.0)
	assert_almost_eq(CombatResolver.predict(brute, s.unit, s.grid).damage_to_defender, _formula_damage(s.grid, 12.0, 1.0, s.unit), 0.0001)

func test_a_melee_strike_technique_is_not_ranged_either():
	var s := _sky()
	var warrior_owner := _player(9)
	Diplomacy.declare_war(s.me, warrior_owner)
	var warrior := _unit(s.grid, warrior_owner, WARRIOR, Vector2i(1, 0))
	var before: float = s.unit.hp
	var predicted: float = CombatResolver.predict(warrior, s.unit, s.grid, _technique(POWER).strike_multiplier).damage_to_defender
	assert_almost_eq(predicted, _formula_damage(s.grid, 5.0, 1.6, s.unit), 0.0001, "Golpe Poderoso é corpo a corpo: sem +25%")
	assert_eq(s.unit.hp, before)

func test_precise_shot_gets_the_bonus_only_against_the_griffon_and_predict_equals_resolve():
	var s := _sky()
	var rival := _rival_with_ranger(s.me)
	var archer := _unit(s.grid, rival, ARCHER, Vector2i(3, 0))
	var attack := UnitDatabase.create_unit(ARCHER).attack
	var multiplier := _technique(PRECISE).strike_multiplier
	var predicted: float = CombatResolver.predict(archer, s.unit, s.grid, multiplier).damage_to_defender
	assert_almost_eq(predicted, _formula_damage(s.grid, attack, multiplier, s.unit) * 1.25, 0.0001)
	var other := _unit(s.grid, s.me, CAVALIER, Vector2i(0, 3))
	var normal: float = CombatResolver.predict(archer, other, s.grid, multiplier).damage_to_defender
	assert_almost_eq(normal, _formula_damage(s.grid, attack, multiplier, other), 0.0001, "o Cavaleiro comum não é vulnerável")
	var hp: float = s.unit.hp
	assert_true(V2TechniqueRuntime.perform_strike(archer, PRECISE, s.unit, s.grid))
	assert_almost_eq(hp - s.unit.hp, predicted, 0.0001, "predict == resolve")

func test_volley_applies_the_bonus_to_each_victim_that_is_vulnerable_and_only_to_it():
	var s := _sky()
	var rival := _rival_with_ranger(s.me)
	var archer := _unit(s.grid, rival, ARCHER, Vector2i(2, 0))
	var neighbor := _unit(s.grid, s.me, CAVALIER, Vector2i(1, 0)) # vizinho do Grifo: também é vítima da Saraivada
	var griffon_before: float = s.unit.hp
	var cavalier_before := neighbor.hp
	var multiplier := _technique(VOLLEY).strike_multiplier
	var attack := UnitDatabase.create_unit(ARCHER).attack
	assert_true(V2TechniqueRuntime.perform_strike(archer, VOLLEY, s.unit, s.grid))
	assert_almost_eq(griffon_before - s.unit.hp, _formula_damage(s.grid, attack, multiplier, s.unit) * 1.25, 0.0001, "o Grifo leva +25%")
	assert_almost_eq(cavalier_before - neighbor.hp, _formula_damage(s.grid, attack, multiplier, neighbor), 0.0001, "o vizinho não")

func test_the_bonus_is_data_not_the_id_a_fake_flyer_with_the_same_data_gets_it_and_a_griffon_without_it_does_not():
	var grid := _world()
	var me := _cavalry_player(9)
	var rival := _rival_with_ranger(me)
	var fake_data := UnitDatabase.create_unit("warrior")
	fake_data.movement_profile = UnitData.MovementProfile.FLYING
	fake_data.ranged_damage_taken_bonus = 0.25
	fake_data.visual_kind = "qualquer_id_xyz"
	var fake := grid.spawn_unit(Vector2i(0, 0), fake_data, me)
	var griffon := _unit(grid, me, GRIFFON, Vector2i(0, 3))
	var archer := _unit(grid, rival, ARCHER, Vector2i(2, 0))
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(archer, fake), 1.25)
	var original := griffon.unit_data.ranged_damage_taken_bonus
	griffon.unit_data.ranged_damage_taken_bonus = 0.0
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(archer, griffon), 1.0, "sem o dado, sem o bônus")
	griffon.unit_data.ranged_damage_taken_bonus = original
	var fake_predicted: float = CombatResolver.predict(archer, fake, grid).damage_to_defender
	assert_almost_eq(fake_predicted, _formula_damage(grid, UnitDatabase.create_unit(ARCHER).attack, 1.0, fake) * 1.25, 0.0001)

func test_the_vulnerability_text_and_the_environment_paths_are_built_from_the_data():
	var data := UnitDatabase.create_unit(GRIFFON)
	assert_eq(UnitAbilities.ranged_vulnerability_text(data), "Vulnerável a ataques à distância: +25% de dano recebido.")
	assert_eq(UnitAbilities.ranged_vulnerability_text(UnitDatabase.create_unit(CAVALIER)), "")
	assert_eq(UnitAbilities.ranged_vulnerability_text(null), "")
	var users: Array[String] = []
	for path in ["res://scripts/core/CombatResolver.gd", "res://scripts/core/MagicRuntime.gd", "res://scripts/city/City.gd", "res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/world/HexGrid.gd"]:
		if FileAccess.file_exists(path) and _code_only(FileAccess.get_file_as_string(path)).contains("ranged_vulnerability_multiplier"):
			users.append(path.get_file())
	assert_eq(users, ["CombatResolver.gd"], "só o combate unidade contra unidade (predict): feitiço, cidade e ambiente não passam por aqui")

func test_the_ranged_bonus_leaves_the_counterattack_and_the_griffons_own_attacks_alone():
	var s := _sky()
	var rival := _rival_with_ranger(s.me)
	var archer := _unit(s.grid, rival, ARCHER, Vector2i(1, 0))
	var griffon_hit := CombatResolver.predict(s.unit, archer, s.grid)
	assert_almost_eq(griffon_hit.damage_to_defender, _formula_damage(s.grid, 10.0, 1.0, archer), 0.0001, "o ataque do Grifo não muda")
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(s.unit, archer), 1.0)

func test_the_griffon_is_still_mounted_so_the_brace_spears_counter_stacks_with_the_vulnerability_sources_separately():
	var grid := _world()
	var me := _cavalry_player(9)
	var guardian_owner := _player(0, 9)
	Diplomacy.declare_war(me, guardian_owner)
	var griffon := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	var guardian := _unit(grid, guardian_owner, SHIELD, Vector2i(1, 0))
	assert_eq(V2TechniqueRuntime.attack_multiplier(guardian, griffon), 1.0 + _technique(BRACE).basic_attack_bonus)
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(guardian, griffon), 1.0, "o Escudeiro é corpo a corpo: só o anti-montado vale")

# --- O código genérico não conhece a unidade -------------------------------------------------------------------------------------------------

func test_no_griffon_id_and_no_name_appears_in_the_movement_and_combat_foundations():
	for path in ["res://scripts/world/HexGrid.gd", "res://scripts/world/HexMetrics.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/data/UnitData.gd", "res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/autoload/SelectionManager.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["griffon_rider", "Cavaleiro de Grifo", "v2_legendary_"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])

func test_the_flight_text_comes_from_the_profile_and_only_the_griffon_has_it():
	assert_eq(UnitAbilities.flight_text(UnitDatabase.create_unit(GRIFFON)), "Voo tático: atravessa terreno e unidades; pousa só em terra livre.")
	for kind in [CAVALIER, SHOCK, ARMORED, WARRIOR, "griffin", "cavalry"]:
		assert_eq(UnitAbilities.flight_text(UnitDatabase.create_unit(kind)), "", kind)
	assert_eq(UnitAbilities.flight_text(null), "")
