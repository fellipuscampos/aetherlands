extends GutTest

## Roadmap 2.0 Parte 1 (A2) — HexGrid.is_under_rival_pressure: proxy MINIMO
## de "tile sob pressao de cidade rival", puramente distancia hexagonal ate
## a cidade rival mais perto, sem nenhuma camada de cultura/influencia.
##
## Roadmap 2.0 (fecha Parte A) — HexGrid.get_lair_danger_at: mesma familia
## de consulta de proximidade, agora pra covil de monstro em vez de cidade
## rival — ver comentario da funcao em HexGrid.gd.

func test_is_under_rival_pressure_true_within_radius_of_rival_city():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var rival_coord := Vector2i(0, 0)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(rival_coord, rival, "Capital Rival")

	var nearby_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS, 0)
	assert_true(hex_grid.is_under_rival_pressure(nearby_coord, human))

	hex_grid.queue_free()

func test_is_under_rival_pressure_false_outside_radius():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var rival_coord := Vector2i(0, 0)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(rival_coord, rival, "Capital Rival")

	var far_coord := Vector2i(HexGrid.RIVAL_PRESSURE_RADIUS + 1, 0)
	assert_false(hex_grid.is_under_rival_pressure(far_coord, human))

	hex_grid.queue_free()

## Uma cidade PROPRIA perto nao conta como "pressao rival" — so cidade de
## OUTRO jogador.
func test_is_under_rival_pressure_false_for_own_city():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var own_coord := Vector2i(0, 0)
	hex_grid.tiles[own_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var human := PlayerData.new(CivilizationData.new())
	hex_grid.found_city(own_coord, human, "Capital")

	var nearby_coord := Vector2i(1, 0)
	assert_false(hex_grid.is_under_rival_pressure(nearby_coord, human))

	hex_grid.queue_free()

func test_get_lair_danger_at_zero_outside_radius():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "goblin"
	hex_grid.spawn_monster_at(lair_coord, "goblin", true)

	var far_coord := Vector2i(HexGrid.LAIR_DANGER_RADIUS + 1, 0)
	assert_eq(hex_grid.get_lair_danger_at(far_coord), 0.0)

	hex_grid.queue_free()

func test_get_lair_danger_at_positive_within_radius_of_active_lair():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "goblin"
	hex_grid.spawn_monster_at(lair_coord, "goblin", true)

	var nearby_coord := Vector2i(1, 0)
	assert_gt(hex_grid.get_lair_danger_at(nearby_coord), 0.0)

	hex_grid.queue_free()

## Testa a fronteira EXATA do raio (distancia == LAIR_DANGER_RADIUS, nao so
## dentro/fora dele) — protecao barata contra alguem trocar `>` por `>=`
## na condicao de corte sem querer numa refatoracao futura.
func test_get_lair_danger_at_positive_exactly_at_radius_boundary():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "goblin"
	hex_grid.spawn_monster_at(lair_coord, "goblin", true)

	var boundary_coord := Vector2i(HexGrid.LAIR_DANGER_RADIUS, 0)
	assert_gt(hex_grid.get_lair_danger_at(boundary_coord), 0.0)

	hex_grid.queue_free()

## Regressao da nuance central do design: um covil cujo guardiao ja morreu
## (sem unidade viva no coord) nao e mais perigoso, mesmo continuando em
## lair_coords ate alguem andar em cima pra destroy_lair() de verdade —
## aqui simulado simplesmente NAO chamando spawn_monster_at.
func test_get_lair_danger_at_ignores_lair_with_dead_defender():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var lair_coord := Vector2i(0, 0)
	hex_grid.lair_coords.append(lair_coord)
	hex_grid.lair_kind_by_coord[lair_coord] = "dragon"

	var nearby_coord := Vector2i(1, 0)
	assert_eq(hex_grid.get_lair_danger_at(nearby_coord), 0.0, "covil sem defensor vivo nao deveria pontuar perigo nenhum")

	hex_grid.queue_free()

func test_get_lair_danger_at_scales_with_monster_kind_strength():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var goblin_lair := Vector2i(0, 0)
	hex_grid.lair_coords.append(goblin_lair)
	hex_grid.lair_kind_by_coord[goblin_lair] = "goblin"
	hex_grid.spawn_monster_at(goblin_lair, "goblin", true)
	var goblin_danger = hex_grid.get_lair_danger_at(Vector2i(1, 0))
	hex_grid.queue_free()

	var hex_grid_2 := HexGrid.new()
	hex_grid_2._ready()
	var dragon_lair := Vector2i(0, 0)
	hex_grid_2.lair_coords.append(dragon_lair)
	hex_grid_2.lair_kind_by_coord[dragon_lair] = "dragon"
	hex_grid_2.spawn_monster_at(dragon_lair, "dragon", true)
	var dragon_danger = hex_grid_2.get_lair_danger_at(Vector2i(1, 0))
	hex_grid_2.queue_free()

	assert_gt(dragon_danger, goblin_danger, "covil de Dragao deveria pontuar mais perigo que covil de Goblin, a mesma distancia")

## MAX entre covis qualificados, NUNCA soma — dois covis fracos proximos
## nao deveriam somar mais perigo que um unico covil daquele mesmo tipo.
func test_get_lair_danger_at_returns_max_not_sum_of_multiple_lairs():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var single_lair := Vector2i(0, 0)
	hex_grid.lair_coords.append(single_lair)
	hex_grid.lair_kind_by_coord[single_lair] = "goblin"
	hex_grid.spawn_monster_at(single_lair, "goblin", true)
	var single_danger = hex_grid.get_lair_danger_at(Vector2i(2, 0))
	hex_grid.queue_free()

	var hex_grid_2 := HexGrid.new()
	hex_grid_2._ready()
	var lair_a := Vector2i(0, 0)
	var lair_b := Vector2i(4, 0)
	hex_grid_2.lair_coords.append(lair_a)
	hex_grid_2.lair_coords.append(lair_b)
	hex_grid_2.lair_kind_by_coord[lair_a] = "goblin"
	hex_grid_2.lair_kind_by_coord[lair_b] = "goblin"
	hex_grid_2.spawn_monster_at(lair_a, "goblin", true)
	hex_grid_2.spawn_monster_at(lair_b, "goblin", true)
	var double_danger = hex_grid_2.get_lair_danger_at(Vector2i(2, 0)) # dentro do raio dos dois covis
	hex_grid_2.queue_free()

	assert_almost_eq(double_danger, single_danger, 0.001, "dois covis de Goblin proximos nao deveriam somar mais perigo que um unico covil de Goblin")
