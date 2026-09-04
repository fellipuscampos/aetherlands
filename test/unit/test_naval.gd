extends GutTest

## Roadmap 2.0 Parte 1 — acesso naval: tech "Navegação" (TechDatabase.
## is_navigation_researched), terrenos elegiveis pra embarque (HexTileData.
## can_be_embarked_on), pre-condicao espacial (HexGrid.is_coastal_tile),
## o toggle do jogador (SelectionManager.toggle_embark_selected) e as
## acoes bloqueadas enquanto embarcado (C2). Pathfinding em si (compute_
## reachable/compute_path/move_unit com embarked=true) fica em
## test_hex_grid_movement.gd, junto dos outros testes de movimento.

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
	Diplomacy.declare_war(human, rival)
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

## --- TechDatabase.is_navigation_researched -------------------------------

func test_is_navigation_researched_false_by_default():
	assert_false(TechDatabase.is_navigation_researched({}))

func test_is_navigation_researched_true_once_researched():
	assert_true(TechDatabase.is_navigation_researched({"navegacao": true}))

## --- HexTileData.can_be_embarked_on ---------------------------------------

func test_can_be_embarked_on_true_for_ocean_frozen_ocean_and_coast():
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN).can_be_embarked_on())
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.FROZEN_OCEAN).can_be_embarked_on())
	assert_true(TerrainDatabase.create_tile(HexTileData.TerrainType.COAST).can_be_embarked_on())

func test_can_be_embarked_on_false_for_lava_and_land():
	assert_false(TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA).can_be_embarked_on())
	assert_false(TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA_SEA).can_be_embarked_on())
	assert_false(TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND).can_be_embarked_on())

## --- HexGrid.is_coastal_tile ----------------------------------------------

func test_is_coastal_tile_true_with_a_water_neighbor():
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

	assert_true(hex_grid.is_coastal_tile(coord))

func test_is_coastal_tile_false_without_a_water_neighbor():
	assert_false(hex_grid.is_coastal_tile(Vector2i(0, 0)), "before_each cerca o centro so de Planicie, sem agua")

## --- SelectionManager.toggle_embark_selected -------------------------------

func test_toggle_embark_selected_noop_without_the_tech():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_embark_selected()

	assert_false(warrior.embarked, "sem Navegação pesquisada, embarcar nao deveria fazer nada")

func test_toggle_embark_selected_noop_for_a_flying_unit():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	human.researched_techs["navegacao"] = true
	var griffin = _make_unit("griffin", human, Vector2i(0, 0))
	SelectionManager._select_unit(griffin)

	SelectionManager.toggle_embark_selected()

	assert_false(griffin.embarked, "Grifo ja atravessa oceano voando, embarcar nao deveria se aplicar")

func test_toggle_embark_selected_noop_outside_a_coastal_tile():
	human.researched_techs["navegacao"] = true
	var warrior = _make_unit("warrior", human, Vector2i(0, 0)) # before_each: so Planicie ao redor, sem agua
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_embark_selected()

	assert_false(warrior.embarked, "fora de um tile adjacente a agua, embarcar nao deveria fazer nada")

func test_toggle_embark_selected_succeeds_when_eligible():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	human.researched_techs["navegacao"] = true
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_embark_selected()

	assert_true(warrior.embarked)

func test_toggle_embark_selected_is_one_way_and_never_manually_disembarks():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	human.researched_techs["navegacao"] = true
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)
	SelectionManager.toggle_embark_selected()
	assert_true(warrior.embarked, "pre-condicao: deveria ter embarcado")

	SelectionManager.toggle_embark_selected()

	assert_true(warrior.embarked, "toggle e mao unica — clicar de novo enquanto ja embarcada nao deveria desembarcar manualmente")

func test_toggle_embark_selected_cancels_fortified_exploring_and_move_order():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	human.researched_techs["navegacao"] = true
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.fortified = true
	warrior.exploring = true
	warrior.move_order_target = Vector2i(5, 5)
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_embark_selected()

	assert_false(warrior.fortified)
	assert_false(warrior.exploring)
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER)

## --- Acoes bloqueadas enquanto embarcado (C2) ------------------------------

func test_embarked_unit_has_no_attackable_tiles():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	attacker.embarked = true

	SelectionManager._select_unit(attacker)

	assert_true(SelectionManager.attackable.is_empty(), "unidade embarcada nao deveria ter nenhum alvo atacavel — tambem bloqueia captura de cidade, que so acontece via ataque")

func test_found_city_with_selected_noop_while_embarked():
	var settler = _make_unit("settler", human, Vector2i(0, 0))
	settler.embarked = true
	SelectionManager._select_unit(settler)

	SelectionManager.found_city_with_selected()

	assert_null(hex_grid.get_city_at(Vector2i(0, 0)), "colonizador embarcado nao deveria conseguir fundar cidade")

func test_fortify_selected_noop_while_embarked():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.embarked = true
	SelectionManager._select_unit(warrior)

	SelectionManager.fortify_selected()

	assert_false(warrior.fortified, "unidade embarcada nao deveria conseguir fortificar")

func test_toggle_explore_selected_noop_while_embarked():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.embarked = true
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_explore_selected()

	assert_false(warrior.exploring, "unidade embarcada nao deveria conseguir explorar")

## --- C7: garantia estrutural (nao mecanica nova) ---------------------------

## A IA nunca embarca nesta fase — como `compute_reachable`/`compute_path`
## pra uma unidade NAO-embarcada continuam bloqueando 100% dos tiles de
## agua exatamente como antes de C, um assentador de IA fisicamente nao
## consegue alcancar terra do outro lado de um vao de oceano, mesmo com
## pontuacao de recursos favoravel do outro lado — nao e uma mecanica nova,
## e uma garantia estrutural do proprio pathfinding. Este teste e uma
## regressao: se uma mudanca futura em C acidentalmente desse embarque
## "de graca" pra unidades sem o campo setado, isto quebraria.
func test_non_embarked_ai_settler_cannot_reach_land_across_an_ocean_gap():
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var far_land := Vector2i(3, 0)
	hex_grid.tiles[far_land] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	# Vizinho de far_land com recurso — deliberadamente atraente (ver
	# RivalAI._score_settle_candidate, que pontua os VIZINHOS do candidato,
	# nao o proprio tile) — nao deveria importar, e inalcancavel de qualquer jeito.
	var resource_neighbor: Vector2i = far_land + HexGrid.NEIGHBOR_DIRS[0]
	var resource_tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	resource_tile.resource = "iron"
	hex_grid.tiles[resource_neighbor] = resource_tile

	var settler = _make_unit("settler", rival, Vector2i(0, 0))
	settler.movement_left = 50.0

	var reachable = hex_grid.compute_reachable(settler.coord, settler.movement_left, settler.owner_player, settler.unit_data.flies)
	var path = hex_grid.compute_path(settler.coord, far_land, settler.owner_player, settler.unit_data.flies)

	assert_false(reachable.has(far_land), "assentador de IA (nao-embarcado) nao deveria conseguir alcancar terra do outro lado do oceano")
	assert_eq(path.size(), 0, "compute_path tambem nao deveria achar rota nenhuma")
	assert_gt(RivalAI._score_settle_candidate(far_land, hex_grid, rival), 0.0, "confirma que o destino SERIA atraente (vizinho de recurso) se fosse alcancavel — a garantia vem do pathfinding, nao da pontuacao")
