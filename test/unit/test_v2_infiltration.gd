extends "res://test/unit/v2_combat_fixture.gd"

## Perfil de movimento INFILTRATOR / Passo Sombrio (Aetherlands V2 Fase 10): o Mestre das Sombras é a primeira unidade INFILTRATOR — atravessa
## unidades (aliadas OU inimigas) no meio do caminho, cada passo atravessável custa 1 (ignora o custo do terreno), mas NUNCA atravessa terreno
## realmente impassável (água/montanha) e NUNCA termina num tile ocupado. Diferente de FLYING (Fase 9), que atravessa TUDO incluindo terreno.
## GROUND e FLYING precisam continuar EXATAMENTE como antes desta fase (regressão das Fases 5-9). Números = BALANCE PLACEHOLDER.

## Mestre das Sombras (N9) em (0,0), sem ninguém por perto.
func _shadow() -> Dictionary:
	var grid := _world()
	var me := _rogue_player(9)
	var rival := _rival_of(me)
	var shadow := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	return {"grid": grid, "me": me, "rival": rival, "unit": shadow}

func _wall_of(grid: HexGrid, q: int, terrain: HexTileData.TerrainType) -> void:
	for r in range(-6, 7):
		if grid.tiles.has(Vector2i(q, r)):
			_set_terrain(grid, Vector2i(q, r), terrain)

# --- O perfil é dado da unidade; GROUND e FLYING não regridem -------------------------------------------------------------------------------

func test_only_the_shadow_master_has_the_infiltrator_profile_and_every_other_kind_is_ground_or_flying_as_before():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var data := UnitDatabase.create_unit(kind)
		if kind == SHADOW_MASTER:
			assert_eq(data.movement_profile, UnitData.MovementProfile.INFILTRATOR)
		elif kind in ["v2_legendary_griffon_rider", "v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_veil_archon", "v2_manifestation_elemental_primordial"]:
			assert_eq(data.movement_profile, UnitData.MovementProfile.FLYING)
		else:
			assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND, kind)

func test_a_ground_unit_reachable_call_is_byte_identical_to_before_this_phase():
	var grid := _world()
	var me := _rogue_player(9)
	_set_costly(grid, Vector2i(1, 0), 2)
	_set_terrain(grid, Vector2i(0, 2), HexTileData.TerrainType.OCEAN)
	_unit(grid, me, WARRIOR, Vector2i(-1, 1))
	for kind in [ROGUE, WARRIOR, ASSASSIN]:
		var unit := _unit(grid, me, kind, Vector2i(-2 if kind == ROGUE else (2 if kind == WARRIOR else 3), -2))
		var old := grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies, unit.embarked)
		assert_eq(grid.unit_reachable(unit), old, kind)

func test_the_v1_and_griffon_flight_are_unchanged_by_the_new_profile():
	var grid := _world()
	var me := _rogue_player(0)
	_set_terrain(grid, Vector2i(1, 0), HexTileData.TerrainType.OCEAN)
	var monster := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("griffin"), me)
	assert_true(monster.unit_data.flies)
	var reach := grid.unit_reachable(monster)
	assert_eq(reach, grid.compute_reachable(monster.coord, monster.movement_left, me, true, false))
	var griffon := grid.spawn_unit(Vector2i(0, 3), UnitDatabase.create_unit(GRIFFON), me)
	_set_terrain(grid, Vector2i(1, 3), HexTileData.TerrainType.MOUNTAINS)
	assert_eq(grid.unit_reachable(griffon), grid.flight_reachable(griffon, griffon.movement_left), "o voo tático continua flight_reachable")

# --- Passo Sombrio: alcance e regras de travessia --------------------------------------------------------------------------------------------

func test_within_movement_a_free_ground_tile_is_reachable_at_a_flat_cost_of_one_per_step():
	var s := _shadow()
	_set_costly(s.grid, Vector2i(1, 0), 5) # se o custo de terreno contasse, isto bloquearia o caminho
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(4, 0)), "4 passos, mov. 4, ignorando o terreno caro")
	assert_eq(reach[Vector2i(4, 0)], 4.0)
	assert_false(reach.has(Vector2i(5, 0)), "5 passos: além do movimento")

func test_it_crosses_allied_and_enemy_units_in_the_middle_of_the_route():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 0)) # aliado colado
	_foe(s.grid, s.rival, Vector2i(2, 0)) # inimigo no meio do caminho
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(3, 0)), "atravessa os dois")
	assert_true(reach.has(Vector2i(4, 0)))
	var ground := _unit(s.grid, s.me, ASSASSIN, Vector2i(0, 3))
	assert_false(s.grid.unit_reachable(ground).has(Vector2i(4, 3)), "um Assassino terrestre comum não atravessaria essa fileira")

func test_it_never_ends_on_an_occupied_tile_even_though_it_can_pass_through():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(2, 0))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_false(reach.has(Vector2i(2, 0)), "ocupado: nunca um destino")
	assert_true(reach.has(Vector2i(1, 0)) and reach.has(Vector2i(3, 0)), "mas passa por cima")

func test_water_and_mountain_tiles_are_never_a_destination():
	var s := _shadow()
	_set_terrain(s.grid, Vector2i(2, 0), HexTileData.TerrainType.OCEAN)
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_false(reach.has(Vector2i(2, 0)), "água nunca é destino")
	assert_true(reach.has(Vector2i(1, 0)))
	var s2 := _shadow()
	_set_terrain(s2.grid, Vector2i(1, 1), HexTileData.TerrainType.MOUNTAINS)
	var reach2: Dictionary = s2.grid.unit_reachable(s2.unit)
	assert_false(reach2.has(Vector2i(1, 1)), "montanha nunca é destino")

## Uma PAREDE de água (não um único tile: um único tile pode ser contornado, exatamente como o chão faria) barra o Passo Sombrio por completo —
## a diferença real com FLYING é coberta em test_ground_infiltrator_and_flying_behave_differently_against_the_same_obstacle_course.
func test_a_water_wall_fully_blocks_the_infiltrator_same_as_it_would_block_the_ground():
	var s := _shadow()
	_wall_of(s.grid, 2, HexTileData.TerrainType.OCEAN)
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	for coord in reach:
		assert_lt(coord.x, 2, "nenhum tile do outro lado da parede de água é alcançável")

func test_an_enemy_city_still_blocks_and_an_own_city_is_a_legal_destination():
	var s := _shadow()
	var enemy_city: City = s.grid.found_city(Vector2i(2, 0), s.rival, "Rival", true)
	var own_city: City = s.grid.found_city(Vector2i(-2, 0), s.me, "Minha", true)
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_false(reach.has(Vector2i(2, 0)), "cidade inimiga")
	assert_true(reach.has(Vector2i(-2, 0)), "cidade própria")
	assert_not_null(enemy_city)
	assert_not_null(own_city)

func test_the_reach_shrinks_with_the_movement_left_and_is_empty_without_it():
	var s := _shadow()
	s.unit.movement_left = 2.0
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(2, 0)))
	assert_false(reach.has(Vector2i(3, 0)))
	s.unit.movement_left = 0.0
	assert_true(s.grid.unit_reachable(s.unit).is_empty())

func test_infiltration_looks_only_at_a_bounded_dijkstra_never_at_the_whole_map():
	var source := _code_only(FileAccess.get_file_as_string("res://scripts/world/HexGrid.gd"))
	var start := source.find("func infiltrate_reachable")
	var body := source.substr(start, source.find("func unit_reachable") - start)
	assert_true(body.contains("frontier"), "Dijkstra por dado, como compute_reachable")
	assert_false(body.contains("tiles.keys"), "sem varrer o mapa inteiro")

# --- Mover de verdade ------------------------------------------------------------------------------------------------------------------

func test_the_unit_really_moves_spends_the_distance_and_the_grid_registers_it():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 0)) # aliado no meio do caminho
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	s.grid.move_unit(s.unit, Vector2i(3, 0), reach[Vector2i(3, 0)])
	assert_eq(s.unit.coord, Vector2i(3, 0))
	assert_eq(s.unit.movement_left, 1.0, "4 - 3")
	assert_eq(s.grid.get_unit_at(Vector2i(3, 0)), s.unit)
	assert_null(s.grid.get_unit_at(Vector2i(0, 0)))

func test_the_animation_route_really_passes_through_the_occupied_tile_not_a_straight_jump():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 0))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	var waypoints: Array[Vector3] = s.grid._animation_waypoints(Vector2i(0, 0), Vector2i(2, 0), s.unit, false)
	assert_eq(waypoints.size(), 2, "dois passos reais, não um salto direto")
	assert_true(reach.has(Vector2i(2, 0)))

func test_a_ground_unit_animation_is_unaffected_still_uses_compute_path():
	var grid := _world()
	var me := _rogue_player(9)
	var ground := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	assert_true(grid._animation_waypoints(Vector2i(0, 0), Vector2i(1, 0), ground, false).size() <= 1)

# --- Nenhuma ordem de vários turnos / pré-visualização longa para INFILTRATOR (mesma decisão do voo, Fase 9) ------------------------------------

func test_no_multi_turn_move_order_and_ground_assassin_keeps_them():
	var s := _shadow()
	var original_grid := GameManager.hex_grid
	var original_human := GameManager.human_player
	GameManager.hex_grid = s.grid
	GameManager.human_player = s.me
	var far := Vector2i(999, 999)
	for coord in s.grid.tiles.keys():
		if HexMetrics.axial_distance(s.unit.coord, coord) >= 5 and s.grid.get_unit_at(coord) == null and s.grid.get_city_at(coord) == null and not s.grid.compute_path(s.unit.coord, coord, s.me, false, false).is_empty():
			far = coord
			break
	assert_ne(far, Vector2i(999, 999), "pré-condição: um destino distante com caminho por terra")
	assert_false(SelectionManager._try_queue_move_order(s.unit, far), "sem ordens de vários turnos para INFILTRATOR")
	assert_eq(s.unit.move_order_target, Unit.NO_MOVE_ORDER)
	var ground := _unit(s.grid, s.me, ASSASSIN, Vector2i(0, 3))
	assert_true(SelectionManager._try_queue_move_order(ground, far), "a linha terrestre convencional segue com a ordem de sempre")
	assert_ne(ground.move_order_target, Unit.NO_MOVE_ORDER)
	GameManager.hex_grid = original_grid
	GameManager.human_player = original_human

# --- Diferença semântica: GROUND × INFILTRATOR × FLYING (cenário obrigatório) ---------------------------------------------------------------

## Parede de unidades (q=1): bloqueia GROUND por completo; INFILTRATOR atravessa. Parede de ÁGUA (q=3, mais além): também bloqueia GROUND e
## INFILTRATOR por completo (nenhum dos dois cruza terreno impassável); FLYING atravessa as duas. Isso prova semanticamente que os três perfis
## são distintos, não variações do mesmo código — cada unidade parte do MESMO tile (0,0), testada em separado no mesmo grid.
func test_ground_infiltrator_and_flying_behave_differently_against_the_same_obstacle_course():
	var grid := _world(8)
	var me := _rogue_player(9)
	for r in range(-6, 7):
		if grid.tiles.has(Vector2i(1, r)):
			_unit(grid, me, WARRIOR, Vector2i(1, r)) # parede de unidades cobrindo toda a extensão do mapa em q=1
	_wall_of(grid, 3, HexTileData.TerrainType.OCEAN) # parede de água mais além, em q=3

	var ground := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	var ground_reach: Dictionary = grid.unit_reachable(ground)
	for coord in ground_reach:
		assert_lt(coord.x, 1, "GROUND: a parede de unidades bloqueia por completo (nenhum tile com q >= 1 é alcançável)")
	grid.remove_unit(ground)

	var infiltrator := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 0))
	var infiltrator_reach: Dictionary = grid.unit_reachable(infiltrator)
	assert_true(infiltrator_reach.has(Vector2i(2, 0)), "INFILTRATOR atravessa a parede de unidades")
	for coord in infiltrator_reach:
		assert_lt(coord.x, 3, "mas a parede de água, mais além, continua bloqueando por completo")
	grid.remove_unit(infiltrator)

	var flyer := _unit(grid, me, GRIFFON, Vector2i(0, 0))
	var flyer_reach: Dictionary = grid.unit_reachable(flyer)
	assert_true(flyer_reach.has(Vector2i(2, 0)), "FLYING atravessa a parede de unidades")
	assert_true(flyer_reach.has(Vector2i(4, 0)), "e também a parede de água (dentro do alcance de movimento)")

## O mesmo obstáculo (só a formação, sem terreno) separado num teste dedicado e mais direto, como o cenário pedido: uma parede de unidades
## bloqueia GROUND por completo; o Mestre das Sombras atravessa; nenhum dos dois atravessa água/montanha.
func test_the_required_scenario_wall_of_units_water_and_mountain():
	var grid := _world(6)
	var me := _rogue_player(9)
	for r in range(-3, 4):
		if grid.tiles.has(Vector2i(1, r)):
			_unit(grid, me, WARRIOR, Vector2i(1, r))
	_set_terrain(grid, Vector2i(1, 4) if grid.tiles.has(Vector2i(1, 4)) else Vector2i(1, -4), HexTileData.TerrainType.OCEAN)

	var ground := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	var infiltrator := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 1))

	var ground_reach: Dictionary = grid.unit_reachable(ground)
	for r in range(-3, 4):
		assert_false(ground_reach.has(Vector2i(2, r)), "GROUND: a parede inteira bloqueia a passagem")

	var infiltrator_reach: Dictionary = grid.unit_reachable(infiltrator)
	assert_true(infiltrator_reach.has(Vector2i(2, 1)), "INFILTRATOR: atravessa a mesma parede")
	for coord in infiltrator_reach:
		assert_false(grid.get_tile(coord).blocks_land_units(), "nunca termina em terreno impassável")

# --- Infiltração até a backline (cenário obrigatório) -----------------------------------------------------------------------------------

func test_infiltrating_past_a_front_line_to_reach_a_caster_in_the_backline():
	var grid := _world(6)
	var me := _rogue_player(9)
	var rival := _rival_of(me)
	# Linha de frente inimiga ocupando uma coluna inteira; atrás dela, um conjurador fixture.
	for r in range(-3, 4):
		if grid.tiles.has(Vector2i(2, r)):
			_foe(grid, rival, Vector2i(2, r))
	var backline_caster := _traited_foe(grid, rival, Vector2i(3, 0), UnitData.TRAIT_CASTER, 40.0, 2.0)

	var assassin := _unit(grid, me, ASSASSIN, Vector2i(0, 0))
	assert_true(grid.unit_reachable(assassin).is_empty() or not grid.unit_reachable(assassin).has(Vector2i(3, -1)), "o Assassino convencional não tem rota através da linha ocupada")

	var shadow := _unit(grid, me, SHADOW_MASTER, Vector2i(0, 1))
	var reach: Dictionary = grid.unit_reachable(shadow)
	var landing := Vector2i(3, 1)
	assert_true(reach.has(landing), "o Mestre atravessa a linha e chega perto da backline")
	shadow.movement_left = reach[landing]
	grid.move_unit(shadow, landing, reach[landing])
	assert_eq(shadow.coord, landing)
	assert_eq(HexMetrics.axial_distance(shadow.coord, backline_caster.coord), 1, "adjacente ao conjurador")
	# Sem teleporte: a rota real passou por dentro da linha ocupada (não por cima, não ao redor por fora do raio).
	var waypoints := grid._animation_waypoints(Vector2i(0, 1), landing, shadow, false)
	assert_gt(waypoints.size(), 1, "vários passos reais")

	# Em situação válida de turno (movimento não usado ainda), o Mestre usa o Ataque Furtivo contra o conjurador.
	shadow.movement_left = shadow.unit_data.movement_points
	var predicted: float = CombatResolver.predict(shadow, backline_caster, grid, 1.35, 0.4, true).damage_to_defender
	var before := backline_caster.hp
	assert_true(V2TechniqueRuntime.perform_strike(shadow, SNEAK_ATTACK, backline_caster, grid))
	assert_almost_eq(before - backline_caster.hp, predicted, 0.0001)
	assert_gt(predicted, _formula_damage(grid, 10.5, 1.35, backline_caster, 1.0, 0.4) * 0.99, "Desmantelar (conjurador) também se aplica")

func test_no_teleport_is_used_the_move_is_a_real_sequence_of_tiles():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 0))
	_unit(s.grid, s.me, WARRIOR, Vector2i(2, 0))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	assert_true(reach.has(Vector2i(3, 0)))
	var path: Array[Vector2i] = s.grid.reconstruct_path(Vector2i(0, 0), Vector2i(3, 0))
	assert_eq(path.size(), 3, "três passos reais: (1,0), (2,0), (3,0)")
	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])

# --- Ação após movimento: regra normal, sem ataque extra grátis --------------------------------------------------------------------------

func test_moving_through_units_consumes_movement_normally_no_free_extra_action():
	var s := _shadow()
	_unit(s.grid, s.me, WARRIOR, Vector2i(1, 0))
	_unit(s.grid, s.me, WARRIOR, Vector2i(2, 0))
	var reach: Dictionary = s.grid.unit_reachable(s.unit)
	s.grid.move_unit(s.unit, Vector2i(4, 0), reach[Vector2i(4, 0)])
	assert_eq(s.unit.movement_left, 0.0, "gastou todo o movimento (4 passos, mov. 4)")
	assert_eq(V2TechniqueRuntime.unavailable_reason(s.unit, SNEAK_ATTACK, s.grid), "A unidade já agiu neste turno.", "sem ação extra grátis")

# --- UI: texto do painel, nunca menciona voo ------------------------------------------------------------------------------------------------

func test_the_panel_text_never_mentions_flight_for_the_infiltrator():
	var data := UnitDatabase.create_unit(SHADOW_MASTER)
	assert_eq(UnitAbilities.infiltration_text(data), "Passo Sombrio: atravessa unidades e ignora custo extra de terreno terrestre; não atravessa terreno impassável.")
	assert_false(UnitAbilities.infiltration_text(data).to_lower().contains("voo"))
	assert_eq(UnitAbilities.flight_text(data), "", "não é o perfil de voo")
	assert_eq(UnitAbilities.infiltration_text(UnitDatabase.create_unit(GRIFFON)), "", "o Grifo é FLYING, não INFILTRATOR")
	for kind in [ROGUE, SABOTEUR, ASSASSIN, WARRIOR]:
		assert_eq(UnitAbilities.infiltration_text(UnitDatabase.create_unit(kind)), "", kind)
	assert_eq(UnitAbilities.infiltration_text(null), "")

func test_no_shadow_master_id_appears_in_the_movement_and_combat_foundations():
	for path in ["res://scripts/world/HexGrid.gd", "res://scripts/world/HexMetrics.gd", "res://scripts/core/UnitAbilities.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/data/UnitData.gd", "res://scripts/core/V2TechniqueRuntime.gd", "res://scripts/autoload/SelectionManager.gd"]:
		var source := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["shadow_master", "Mestre das Sombras", "v2_legendary_"]:
			assert_false(source.contains(forbidden), "%s cita '%s'" % [path, forbidden])
