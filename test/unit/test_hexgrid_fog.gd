extends GutTest

## Cobre fog of war (HexGrid.compute_visible_tiles/recompute_fog) — nunca
## tinha teste proprio, apesar de ser a base tanto do fog do jogador humano
## quanto do "fog of war propria" da IA rival (RivalAI.take_turn). Uniao de
## visao de unidades+cidades, tile ja visto nunca volta a NAO VISTO (so
## escurece pra EXPLORADO quando sai de visao), e unidade/cidade inimiga so
## aparece em tile ATUALMENTE visivel — nao basta ja ter sido explorado.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []

func before_each():
	_created_units = []
	hex_grid = HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	# Linha extra de tiles pra testes que precisam de distancias maiores
	# que 1 (o anel de vizinhos acima so alcanca ate 1 tile do centro).
	for i in range(2, 6):
		hex_grid.tiles[Vector2i(i, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

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

func test_compute_visible_tiles_includes_unit_vision_range():
	_make_unit("warrior", human, Vector2i(0, 0)) # vision_range 2

	var visible = hex_grid.compute_visible_tiles(human)

	assert_true(visible.has(Vector2i(2, 0)), "tile a 2 de distancia deveria estar dentro do alcance de visao do guerreiro")
	assert_false(visible.has(Vector2i(3, 0)), "tile a 3 de distancia deveria estar fora do alcance de visao do guerreiro")

func test_compute_visible_tiles_includes_city_vision():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital") # cidade sempre enxerga 2 tiles

	var visible = hex_grid.compute_visible_tiles(human)

	assert_true(visible.has(Vector2i(2, 0)))
	assert_false(visible.has(Vector2i(3, 0)))

func test_recompute_fog_marks_currently_visible_tiles():
	_make_unit("warrior", human, Vector2i(0, 0))

	hex_grid.recompute_fog(human)

	assert_eq(hex_grid.visibility[Vector2i(0, 0)], HexGrid.Visibility.VISIBLE)

func test_recompute_fog_downgrades_no_longer_visible_to_explored_not_unseen():
	var unit = _make_unit("warrior", human, Vector2i(0, 0))
	hex_grid.recompute_fog(human)
	assert_eq(hex_grid.visibility[Vector2i(0, 0)], HexGrid.Visibility.VISIBLE)

	hex_grid.move_unit(unit, Vector2i(4, 0), 4.0) # a unica unidade se afasta
	hex_grid.recompute_fog(human)

	assert_eq(
		hex_grid.visibility[Vector2i(0, 0)], HexGrid.Visibility.EXPLORED,
		"tile que ja foi visto deveria so escurecer pra EXPLORADO, nunca voltar a nao-visto"
	)

func test_enemy_unit_only_visible_when_tile_is_currently_visible():
	var scout = _make_unit("warrior", human, Vector2i(0, 0))
	var enemy = _make_unit("warrior", rival, Vector2i(1, 0)) # dentro do alcance de visao do scout

	hex_grid.recompute_fog(human)
	assert_true(enemy.visible, "unidade inimiga em tile visivel deveria aparecer")

	hex_grid.move_unit(scout, Vector2i(4, 0), 4.0) # afasta o unico observador humano
	hex_grid.recompute_fog(human)

	assert_false(enemy.visible, "unidade inimiga fora de visao atual nao deveria continuar aparecendo so por ja ter sido vista")

func test_enemy_city_only_visible_when_tile_is_currently_visible():
	var scout = _make_unit("warrior", human, Vector2i(1, 0))
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")

	hex_grid.recompute_fog(human)
	assert_true(city.visible, "cidade inimiga em tile visivel deveria aparecer")

	hex_grid.move_unit(scout, Vector2i(4, 0), 4.0)
	hex_grid.recompute_fog(human)

	assert_false(city.visible, "cidade inimiga fora de visao atual nao deveria continuar aparecendo")

## Predios posicionados (Building.gd, HexGrid.place_building) seguem a
## MESMA regra de cidade/unidade — mesma logica, so testando um tipo de
## entidade que ainda nao tinha cobertura.
func test_enemy_building_only_visible_when_tile_is_currently_visible():
	var scout = _make_unit("warrior", human, Vector2i(1, 0))
	var building = hex_grid.place_building(Vector2i(0, 0), "granary", rival)

	hex_grid.recompute_fog(human)
	assert_true(building.visible, "predio inimigo em tile visivel deveria aparecer")

	hex_grid.move_unit(scout, Vector2i(4, 0), 4.0)
	hex_grid.recompute_fog(human)

	assert_false(building.visible, "predio inimigo fora de visao atual nao deveria continuar aparecendo")

## Debug: com debug_fog_disabled ligado, recompute_fog() para de calcular
## visao de verdade e so marca tudo como VISIVEL — pedido do usuario:
## "adicione opcoes debug onde eu posso tirar a fog do mapa e coisas
## assim".
func test_recompute_fog_reveals_everything_when_debug_fog_disabled():
	hex_grid.debug_fog_disabled = true

	hex_grid.recompute_fog(human)

	for coord in hex_grid.tiles.keys():
		assert_eq(hex_grid.visibility[coord], HexGrid.Visibility.VISIBLE, "tile %s deveria estar visivel com debug_fog_disabled" % coord)

## Enemy visibility segue o mesmo _apply_fog_to_entities de sempre — com
## tudo VISIVEL, ate unidade inimiga nunca vista de verdade aparece.
func test_debug_fog_disabled_reveals_enemy_units_never_actually_seen():
	var enemy = _make_unit("warrior", rival, Vector2i(4, 0)) # bem longe, fora de qualquer visao real do humano
	hex_grid.debug_fog_disabled = true

	hex_grid.recompute_fog(human)

	assert_true(enemy.visible, "com debug_fog_disabled, unidade inimiga deveria aparecer mesmo sem nunca ter sido vista de verdade")

## set_debug_fog_disabled() e o metodo publico que a HUD chama (botao de
## Debug) — liga a flag E reaplica na hora, sem esperar o proximo turno.
func test_set_debug_fog_disabled_toggles_flag_and_applies_immediately():
	var original_human_player = GameManager.human_player
	GameManager.human_player = human

	hex_grid.set_debug_fog_disabled(true)

	assert_true(hex_grid.debug_fog_disabled)
	assert_eq(hex_grid.visibility[Vector2i(4, 0)], HexGrid.Visibility.VISIBLE, "reveal deveria aplicar na hora, sem esperar o proximo turno")

	hex_grid.set_debug_fog_disabled(false)
	assert_false(hex_grid.debug_fog_disabled)

	GameManager.human_player = original_human_player
