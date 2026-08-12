extends GutTest

## Regressao do bug relatado pelo usuario: atacar uma unidade inimiga e
## continuar podendo clicar nela pra atacar de novo, sem fim, no mesmo
## turno. Causa: _select_unit() recalculava "attackable" so olhando o
## alcance da unidade, sem checar se ela ainda tinha movimento/acao
## disponivel — depois de atacar (que zera movement_left), o mesmo alvo
## continuava marcado como atacavel.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_created_units = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival) # attackable agora exige guerra (Diplomacy.gd)
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
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

func test_attacking_removes_target_from_attackable_afterwards():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, defender_coord)

	SelectionManager._select_unit(attacker)
	assert_true(defender_coord in SelectionManager.attackable, "alvo deveria estar atacavel antes do primeiro ataque")

	SelectionManager._attack_from_selected(defender_coord)

	assert_eq(attacker.movement_left, 0.0, "atacar deveria zerar o movimento")
	assert_false(defender_coord in SelectionManager.attackable, "alvo nao deveria continuar atacavel depois que a unidade ja agiu")

func test_unit_with_zero_movement_has_no_attackable_tiles_on_reselect():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	attacker.movement_left = 0.0

	SelectionManager._select_unit(attacker)

	assert_eq(SelectionManager.attackable.size(), 0, "unidade sem movimento/acao restante nao deveria ter nenhum alvo atacavel")

## Diplomacia (Diplomacy.gd): unidade/cidade de um jogador em paz nao
## deveria nunca aparecer como atacavel, mesmo dentro do alcance.
func test_peaceful_units_and_cities_are_never_attackable():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var enemy_unit_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, enemy_unit_coord)
	var third = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, third)
	var enemy_city_coord = Vector2i(-1, 0)
	var city = hex_grid.found_city(enemy_city_coord, third, "Cidade C")

	Diplomacy.propose_peace(human, rival) # 1 unidade cada lado, empate aceita a paz

	SelectionManager._select_unit(attacker)

	assert_false(enemy_unit_coord in SelectionManager.attackable, "unidade de um jogador em paz nao deveria ser atacavel")
	assert_true(enemy_city_coord in SelectionManager.attackable, "cidade de um jogador AINDA em guerra deveria continuar atacavel")

## Guardiao de Covil de Monstro (owner_player == null, ver MonsterDatabase)
## nao tem diplomacia — e hostil a todo mundo sempre, mesmo sem nenhuma
## guerra declarada contra ele (nao ha "ele" pra declarar guerra contra).
func test_neutral_monster_is_always_attackable_without_any_diplomacy():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var monster_coord = Vector2i(1, 0)
	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("goblin"), null, monster_coord)
	hex_grid.units_by_coord[monster_coord] = monster
	_created_units.append(monster)

	SelectionManager._select_unit(attacker)

	assert_true(monster_coord in SelectionManager.attackable, "guardiao neutro deveria estar sempre atacavel")

## Nome do alvo no hover "ATACAR X" (SelectionManager.handle_world_hover)
## — sem isso o jogador so descobre o que esta guardando um Covil de
## Monstro DEPOIS de atacar as cegas.
func test_attack_target_name_returns_unit_name():
	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("troll"), null, Vector2i(1, 0))
	hex_grid.units_by_coord[Vector2i(1, 0)] = monster
	_created_units.append(monster)

	assert_eq(SelectionManager._attack_target_name(hex_grid, Vector2i(1, 0)), "Troll")

func test_attack_target_name_returns_city_name():
	var city = hex_grid.found_city(Vector2i(-1, 0), rival, "Forte Rival")

	assert_eq(SelectionManager._attack_target_name(hex_grid, Vector2i(-1, 0)), "Forte Rival")

## Posicionamento de predio (SelectionManager.start_building_placement):
## o jogador escolhe o tile no mapa, do mesmo jeito que fundar uma cidade.

func test_start_building_placement_lists_only_valid_neighbor_tiles():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var occupied = HexGrid.NEIGHBOR_DIRS[0]
	_make_unit("warrior", human, occupied) # um vizinho ocupado, nao deveria entrar na lista

	SelectionManager.start_building_placement(city, "granary")

	assert_false(occupied in SelectionManager.placeable_coords, "vizinho ocupado por unidade nao deveria ser um destino valido")
	assert_eq(SelectionManager.placeable_coords.size(), HexGrid.NEIGHBOR_DIRS.size() - 1)

func test_clicking_a_valid_tile_confirms_building_placement():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var target = HexGrid.NEIGHBOR_DIRS[0]
	SelectionManager.start_building_placement(city, "granary")

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(target.x, target.y, hex_grid.hex_size))

	assert_eq(city.production_item, "granary")
	assert_eq(city.pending_building_coord, target)
	assert_null(SelectionManager.placing_city, "modo de posicionamento deveria encerrar apos confirmar")

func test_clicking_an_invalid_tile_cancels_building_placement():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	SelectionManager.start_building_placement(city, "granary")

	# Vector2i(0,0) e a propria cidade — nunca esta em placeable_coords
	# (so vizinhos entram), entao clicar nela deveria cancelar.
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(0, 0, hex_grid.hex_size))

	assert_eq(city.production_item, "settler", "producao nao deveria ter mudado quando o posicionamento e cancelado")
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	assert_null(SelectionManager.placing_city)
