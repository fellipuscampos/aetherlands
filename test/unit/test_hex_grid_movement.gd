extends GutTest

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []

func before_each():
	_created_units = []
	hex_grid = HexGrid.new()
	# HexGrid so cria _units_root/_cities_root em _ready(), que o motor so
	# chama quando o node entra na scene tree. Nao adicionamos a arvore
	# real aqui (teste isolado), entao chamamos manualmente — nada dentro
	# de _ready() depende de estar parentado, so cria meshes/nodes filhos.
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())

func after_each():
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

## Regressao do bug relatado pelo usuario: atacar uma cidade inimiga sem
## defensor estava so movendo a unidade pra cima dela em vez de capturar,
## porque compute_reachable() nao excluia tiles de cidade inimiga — o tile
## entrava tanto em "alcancavel" quanto em "atacavel", e o movimento
## ganhava prioridade no clique. Ver SelectionManager.handle_world_click().
func test_enemy_city_is_not_reachable_by_movement():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.found_city(Vector2i(1, 0), rival, "Cidade Inimiga")

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_false(reachable.has(Vector2i(1, 0)), "cidade inimiga nao deveria ser destino de movimento — so de ataque/captura")

func test_own_city_is_still_reachable_for_garrisoning():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.found_city(Vector2i(1, 0), human, "Minha Cidade")

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_true(reachable.has(Vector2i(1, 0)), "unidade deveria poder guarnecer a propria cidade")

func test_tile_occupied_by_any_unit_blocks_movement():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", human, Vector2i(1, 0)) # mesmo dono, ainda bloqueia (sem empilhar)

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	assert_false(reachable.has(Vector2i(1, 0)))

func test_capturing_undefended_city_transfers_ownership():
	hex_grid.found_city(Vector2i(1, 0), rival, "Cidade Inimiga")
	var city = hex_grid.get_city_at(Vector2i(1, 0))

	hex_grid.capture_city(city, human)

	assert_eq(city.owner_player, human)
	assert_true(human.cities.has(city))
	assert_false(rival.cities.has(city))

## Predio POSICIONADO no mapa (Building.gd, ver City.building_coords) —
## registrado igual unidade/cidade (units_by_coord/cities_by_coord).
func test_place_building_registers_it_at_the_right_coord():
	var building = hex_grid.place_building(Vector2i(1, 0), "granary", human)

	assert_eq(hex_grid.get_building_at(Vector2i(1, 0)), building)
	assert_eq(building.building_id, "granary")
	assert_eq(building.owner_player, human)

func test_is_tile_building_site_reflects_placed_building():
	assert_false(hex_grid.is_tile_building_site(Vector2i(1, 0)))
	hex_grid.place_building(Vector2i(1, 0), "granary", human)
	assert_true(hex_grid.is_tile_building_site(Vector2i(1, 0)))

## "Limite da cidade" visivel no mapa (pedido do usuario): tinge o
## territorio da cidade sendo vista — show_city_territory()/
## clear_city_territory() so guardam o conjunto de coords que
## _apply_fog_colors() usa pra tingir (rendering em si nao e testado aqui,
## so o estado que controla o que vai ser tingido).
func test_show_city_territory_sets_the_highlighted_coords():
	hex_grid.show_city_territory([Vector2i(0, 0), Vector2i(1, 0)])
	assert_eq(hex_grid._city_territory_coords, [Vector2i(0, 0), Vector2i(1, 0)])

func test_clear_city_territory_empties_the_highlighted_coords():
	hex_grid.show_city_territory([Vector2i(0, 0)])
	hex_grid.clear_city_territory()
	assert_eq(hex_grid._city_territory_coords.size(), 0)

## Base da previa de trajeto (estilo Civilization) mostrada ao passar o
## mouse sobre um tile alcancavel — ver SelectionManager.handle_world_hover().
func test_reconstruct_path_returns_correct_step_sequence():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.movement_left = 2.0 # grama custa 1 por tile, guerreiro alcanca 2 tiles

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)
	assert_true(reachable.has(Vector2i(2, 0)), "com 2 pontos de movimento devia alcancar 2 tiles de grama a frente")

	var path = hex_grid.reconstruct_path(warrior.coord, Vector2i(2, 0))
	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0)], "caminho deveria passar pelo tile intermediario")

func test_reconstruct_path_to_unreachable_tile_is_empty():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player)

	var path = hex_grid.reconstruct_path(warrior.coord, Vector2i(50, 50))

	assert_eq(path.size(), 0)

## Base do alcance de ataque (SelectionManager/RivalAI) — nunca tinha
## teste proprio, so cobertura indireta via esses chamadores.
func test_tiles_in_range_returns_immediate_neighbors_for_range_1():
	var center := Vector2i(0, 0)
	var result = hex_grid.tiles_in_range(center, 1)

	assert_eq(result.size(), 6, "raio 1 deveria devolver exatamente os 6 vizinhos imediatos")
	for dir in HexGrid.NEIGHBOR_DIRS:
		assert_true(center + dir in result)

func test_tiles_in_range_excludes_the_center_tile():
	var center := Vector2i(0, 0)
	var result = hex_grid.tiles_in_range(center, 1)

	assert_false(center in result, "o proprio tile central nao deveria entrar no resultado")

func test_tiles_in_range_includes_tiles_two_steps_away():
	var center := Vector2i(0, 0)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var result = hex_grid.tiles_in_range(center, 2)

	assert_true(Vector2i(2, 0) in result, "tile a 2 passos deveria entrar no alcance 2")

## Grifo (UnitData.flies): atravessa oceano onde qualquer outra unidade
## fica presa — reforca o tema de fantasia (montaria voadora ignora o
## limite geografico que trava o resto do exercito).
func test_flying_unit_can_cross_ocean():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(griffin.coord, griffin.movement_left, griffin.owner_player, griffin.unit_data.flies)

	assert_true(reachable.has(Vector2i(1, 0)), "unidade voadora deveria conseguir atravessar oceano")

func test_non_flying_unit_cannot_cross_ocean():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))

	var reachable = hex_grid.compute_reachable(warrior.coord, warrior.movement_left, warrior.owner_player, warrior.unit_data.flies)

	assert_false(reachable.has(Vector2i(1, 0)), "unidade terrestre nao deveria atravessar oceano")

## Regressao: voar "por cima" do terreno significa ignorar o CUSTO dele
## tambem, nao so a restricao de oceano — senao colina/floresta ainda
## atrasariam o grifo como qualquer outra unidade.
func test_flying_unit_ignores_terrain_movement_cost():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS) # custo alto
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))
	griffin.movement_left = 2.0

	var reachable = hex_grid.compute_reachable(griffin.coord, griffin.movement_left, griffin.owner_player, griffin.unit_data.flies)

	assert_true(reachable.has(Vector2i(2, 0)), "com custo 1/tile (voando), 2 pontos de movimento deveriam alcancar 2 montanhas")

func test_tiles_in_range_does_not_include_tiles_beyond_range():
	var center := Vector2i(0, 0)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	var result = hex_grid.tiles_in_range(center, 1)

	assert_false(Vector2i(2, 0) in result, "tile a 2 passos nao deveria entrar no alcance 1")
