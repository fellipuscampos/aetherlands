extends GutTest

## ROTA CANÔNICA E CAMINHADA (2026-10-10, relato do usuário: "às vezes ele faz rodopios estranhos, gira e faz
## movimentos meio aleatórios"). Todo terreno custa 1, então entre dois tiles há muitas rotas de mesmo custo: o
## desempate era a ordem do heap (zigue-zague, o corpo virando 60° a cada tile) e a prévia vinha de uma busca diferente
## da animação. Agora HexGrid._find_route escolhe, entre as rotas de menor custo, a de MENOS CURVAS (contando o rumo
## atual da unidade), a prévia e a animação usam a mesma função (HexGrid.unit_route) e reposicionar a unidade direto
## (Unit.place_at) cancela a caminhada em andamento.

var _players: Array[PlayerData] = []

func after_each():
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String = "human") -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

## Campo aberto de grama (raio `radius`), na árvore: as unidades animam de verdade.
func _field(radius: int = 8) -> HexGrid:
	var grid := HexGrid.new()
	add_child_autofree(grid)
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return grid

func _terrain(grid: HexGrid, coord: Vector2i, terrain: HexTileData.TerrainType) -> void:
	grid.tiles[coord] = TerrainDatabase.create_tile(terrain)

func _spawn(grid: HexGrid, kind: String, owner: PlayerData, coord: Vector2i, movement: float = 6.0) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = movement
	return unit

## Quantas vezes a rota muda de direção (o primeiro passo não conta: `heading` = rumo antes dele, ZERO = sem rumo).
func _turns(origin: Vector2i, route: Array[Vector2i], heading: Vector2i = Vector2i.ZERO) -> int:
	var turns := 0
	var previous := origin
	var direction := heading
	for step in route:
		var step_direction: Vector2i = step - previous
		if direction != Vector2i.ZERO and step_direction != direction:
			turns += 1
		direction = step_direction
		previous = step
	return turns

func _is_contiguous(origin: Vector2i, route: Array[Vector2i]) -> bool:
	var previous := origin
	for step in route:
		if HexMetrics.axial_distance(previous, step) != 1:
			return false
		previous = step
	return true

# --- Menos curvas, mesmo custo -----------------------------------------------------------------------------------------

func test_in_open_field_every_route_turns_at_most_once_and_costs_what_the_range_said():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0), 5.0)
	var reach := grid.unit_reachable(unit)
	assert_eq(reach.size(), 90, "pré-condição: raio 5 inteiro")
	for dest in reach:
		var route := grid.unit_route(unit, dest)
		assert_true(_is_contiguous(unit.coord, route), "passos vizinhos até %s" % dest)
		assert_eq(route[-1], dest)
		assert_eq(float(route.size()), float(reach[dest]), "a rota custa o que o alcance validou (%s)" % dest)
		var aligned: bool = dest.x == 0 or dest.y == 0 or dest.x + dest.y == 0
		assert_eq(_turns(unit.coord, route), 0 if aligned else 1, "reta num eixo, uma curva fora dele (%s): %s" % [dest, route])

func test_the_long_leg_comes_first_and_the_answer_is_deterministic():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)]
	for attempt in 3:
		assert_eq(grid.unit_route(unit, Vector2i(3, 1)), expected, "3 a leste, depois 1 a sudeste")

func test_the_route_around_a_wall_is_still_the_cheapest_one():
	var grid := _field()
	for r in range(-2, 3):
		_terrain(grid, Vector2i(2, r), HexTileData.TerrainType.MOUNTAINS)
	var me := _player()
	var cheapest: float = grid.compute_reachable(Vector2i(0, 0), 99.0, me)[Vector2i(4, 0)] # a busca de alcance, independente do roteador
	var route := grid.compute_path(Vector2i(0, 0), Vector2i(4, 0), me)
	assert_true(_is_contiguous(Vector2i(0, 0), route))
	assert_eq(route[-1], Vector2i(4, 0))
	assert_eq(float(route.size()), cheapest, "contornar a parede custa o mínimo")
	assert_eq(route.size(), 8)
	for step in route:
		assert_false(grid.tiles[step].blocks_land_units(), "nunca por cima da montanha")
	# Passar pela ponta da parede em (2, -3) exige 4 direções (ir: norte + nordeste; voltar: leste + sudeste) = 3 curvas.
	assert_eq(_turns(Vector2i(0, 0), route), 3, "contorna com o mínimo de curvas, sem serpentear")

func test_the_current_heading_is_kept_so_replanning_continues_the_same_leg():
	var grid := _field()
	var me := _player()
	var dest := Vector2i(2, 4) # 2 a leste + 4 a sudeste: sem rumo, a perna longa (sudeste) viria primeiro
	assert_eq(grid.compute_path(Vector2i(0, 0), dest, me)[0], Vector2i(0, 1), "sem rumo: perna longa primeiro")
	var heading_east := grid.compute_path(Vector2i(0, 0), dest, me, false, false, Vector2i(1, 0))
	assert_eq(heading_east.slice(0, 2), [Vector2i(1, 0), Vector2i(2, 0)], "já indo para leste: termina a perna leste antes de virar")
	assert_eq(_turns(Vector2i(0, 0), heading_east, Vector2i(1, 0)), 1)

func test_a_march_walks_the_route_planned_at_the_click_turn_after_turn():
	var grid := _field(10)
	var origin := Vector2i(-6, 0)
	var dest := Vector2i(1, 5) # 7 a leste + 5 a sudeste
	var unit := _spawn(grid, "v2_unit_warrior", _player(), origin, 2.0)
	var planned := grid.unit_path(unit, dest)
	assert_eq(planned.size(), 12)
	assert_eq(_turns(origin, planned), 1, "a rota planejada tem uma curva só")
	unit.move_order_target = dest
	# Recalculada do zero a cada turno (2 tiles por vez), a marcha pisa exatamente nos tiles planejados no clique:
	# o rumo da unidade segura a perna em vez de trocá-la quando as duas empatam.
	for turn in range(1, 7):
		unit.movement_left = 2.0
		grid.continue_move_order(unit)
		assert_eq(unit.coord, planned[turn * 2 - 1], "turno %d" % turn)
	assert_eq(unit.coord, dest)
	assert_eq(unit.move_order_target, Unit.NO_MOVE_ORDER)
	unit.place_at(grid.world_surface_for_coord(dest))

# --- A prévia é a animação ----------------------------------------------------------------------------------------------

func test_the_previewed_route_is_the_animated_route_for_every_reachable_tile():
	var grid := _field()
	for coord in [Vector2i(2, -1), Vector2i(1, 2), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(3, 0)]:
		_terrain(grid, coord, HexTileData.TerrainType.MOUNTAINS)
	var me := _player()
	_spawn(grid, "v2_unit_warrior", me, Vector2i(1, 1)) # um aliado no meio também bloqueia
	var unit := _spawn(grid, "v2_unit_warrior", me, Vector2i(0, 0), 4.0)
	var reach := grid.unit_reachable(unit)
	assert_gt(reach.size(), 30)
	for dest in reach:
		var preview := grid.unit_route(unit, dest)
		# O que move_unit faz: tira a unidade do tile de origem e pede os passos da animação.
		grid.units_by_coord.erase(unit.coord)
		var animated := grid._animation_steps(unit.coord, dest, unit)
		grid.units_by_coord[unit.coord] = unit
		assert_eq(animated, preview, "prévia = animação até %s" % dest)
		assert_eq(float(preview.size()), float(reach[dest]), "e custa o que o alcance disse")

func test_a_land_only_technique_route_never_takes_the_water_shortcut():
	var grid := _field()
	for r in range(-3, 4): # um "lago" em q = 2 que a rota normal atravessaria de barco
		_terrain(grid, Vector2i(2, r), HexTileData.TerrainType.OCEAN)
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0), 12.0)
	assert_true(Vector2i(2, 0) in grid.unit_route(unit, Vector2i(4, 0)), "movimento normal: atravessa a água")
	var land_reach := grid.unit_reachable(unit, -1.0, false, false)
	var land_route := grid.unit_route(unit, Vector2i(4, 0), false, false)
	assert_false(land_route.is_empty())
	assert_eq(float(land_route.size()), float(land_reach[Vector2i(4, 0)]), "a rota por terra custa o que o alcance por terra disse")
	for step in land_route:
		assert_false(grid.tiles[step].can_be_embarked_on(), "só por terra")

func test_an_explicit_route_is_the_one_the_unit_walks():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	var route: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	grid.move_unit(unit, Vector2i(3, 1), 4.0, "", route)
	# O primeiro trecho já saiu da fila; os outros três são os tiles da rota passada, na ordem.
	assert_eq(unit._walk_queue.size(), 3)
	for i in 3:
		assert_almost_eq(unit._walk_queue[i].x, grid.world_surface_for_coord(route[i + 1]).x, 0.001)
		assert_almost_eq(unit._walk_queue[i].z, grid.world_surface_for_coord(route[i + 1]).z, 0.001)
	assert_eq(unit.travel_dir, Vector2i(1, 0), "o rumo é o do último passo")
	unit.place_at(grid.world_surface_for_coord(unit.coord))

func test_a_move_without_any_route_still_walks_tile_by_tile_never_one_straight_jump():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	for coord in grid.get_neighbors(Vector2i(4, 0)): # destino emparedado: o roteador não acha rota
		_terrain(grid, coord, HexTileData.TerrainType.MOUNTAINS)
	assert_true(grid.unit_route(unit, Vector2i(4, 0)).is_empty())
	var steps := grid._animation_steps(Vector2i(0, 0), Vector2i(4, 0), unit)
	assert_eq(steps.size(), 4)
	assert_true(_is_contiguous(Vector2i(0, 0), steps))

func test_tactical_flight_flies_the_true_straight_line():
	var grid := _field()
	var data := UnitDatabase.create_unit("v2_unit_warrior")
	data.movement_profile = UnitData.MovementProfile.FLYING
	var flyer := grid.spawn_unit(Vector2i(0, 0), data, _player())
	var dest := Vector2i(-5, 2) # fora dos eixos: a linha de hexágonos serpenteia
	var from := grid.world_surface_for_coord(Vector2i(0, 0))
	var to := grid.world_surface_for_coord(dest)
	var waypoints := grid._animation_waypoints(Vector2i(0, 0), dest, flyer)
	assert_eq(waypoints.size(), 5, "um ponto por tile: mesma duração de sempre")
	var heading := atan2(to.x - from.x, to.z - from.z)
	var previous := from
	for point in waypoints:
		assert_almost_eq(atan2(point.x - previous.x, point.z - previous.z), heading, 0.001, "rumo constante")
		previous = point
	assert_almost_eq(waypoints[-1].x, to.x, 0.001)
	assert_almost_eq(waypoints[-1].z, to.z, 0.001)

# --- O corpo não rodopia ------------------------------------------------------------------------------------------------

func test_a_real_walk_turns_the_body_once_not_at_every_tile():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	var dest := Vector2i(-5, 2)
	var reach := grid.unit_reachable(unit)
	unit.rotation.y = deg_to_rad(-90.0) # já olhando para oeste, o rumo da primeira perna
	grid.move_unit(unit, dest, reach[dest])
	var turned := 0.0
	var last := unit.rotation.y
	while unit._walking:
		await wait_process_frames(1)
		turned += absf(unit.rotation.y - last)
		last = unit.rotation.y
	assert_almost_eq(rad_to_deg(turned), 60.0, 1.0, "5 tiles fora do eixo: uma curva de 60° (antes: 60° a cada tile)")
	assert_almost_eq(unit.position.x, grid.world_surface_for_coord(dest).x, 0.001)
	assert_almost_eq(unit.position.z, grid.world_surface_for_coord(dest).z, 0.001)

# --- Reposicionar cancela a caminhada -----------------------------------------------------------------------------------

func test_place_at_cancels_the_walk_and_the_unit_stays_where_it_was_put():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	grid.move_unit(unit, Vector2i(4, 0), 4.0)
	await wait_seconds(Unit.MOVE_DURATION * 0.5)
	assert_true(unit._walking)
	var spot := grid.world_surface_for_coord(Vector2i(-3, 3))
	unit.place_at(spot)
	assert_false(unit._walking)
	assert_true(unit._walk_queue.is_empty())
	assert_eq(String(unit._anim_player.current_animation), unit.idle_animation, "volta ao repouso")
	await wait_seconds(Unit.MOVE_DURATION * 2.0)
	assert_eq(unit.position, spot, "nenhum Tween antigo puxa a unidade de volta")

func test_a_move_out_of_sight_in_the_middle_of_a_walk_ends_on_the_logical_tile():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	grid.move_unit(unit, Vector2i(3, 0), 3.0)
	await wait_seconds(Unit.MOVE_DURATION * 0.5)
	# A neblina cobre a unidade no meio da caminhada: quem observa é outro jogador e o destino está fora da visão dele
	# (move_unit decide a visibilidade pelo tile de destino, HexGrid.shown_through_fog).
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.EXPLORED
	grid._fog_viewer = _player()
	grid.move_unit(unit, Vector2i(3, 3), 3.0)
	assert_false(unit.visible, "saiu da visão do observador")
	await wait_seconds(Unit.MOVE_DURATION * 4.0)
	assert_eq(unit.position, grid.world_surface_for_coord(Vector2i(3, 3)), "o corpo está no tile lógico, não no destino da caminhada antiga")
	assert_false(unit._walking)

func test_teleport_in_the_middle_of_a_walk_clears_the_heading_and_stays_put():
	var grid := _field()
	var unit := _spawn(grid, "v2_unit_warrior", _player(), Vector2i(0, 0))
	grid.move_unit(unit, Vector2i(3, 0), 3.0)
	assert_eq(unit.travel_dir, Vector2i(1, 0))
	await wait_seconds(Unit.MOVE_DURATION * 0.5)
	grid.teleport_unit(unit, Vector2i(-2, -2))
	assert_eq(unit.travel_dir, Vector2i.ZERO)
	await wait_seconds(Unit.MOVE_DURATION * 4.0)
	assert_eq(unit.position, grid.world_surface_for_coord(Vector2i(-2, -2)))
