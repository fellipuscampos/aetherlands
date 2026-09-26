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
	_make_unit("warrior", human, Vector2i(0, 0)) # vision_range 3 (ver UnitDatabase.gd)

	var visible = hex_grid.compute_visible_tiles(human)

	assert_true(visible.has(Vector2i(3, 0)), "tile a 3 de distancia deveria estar dentro do alcance de visao do guerreiro")
	assert_false(visible.has(Vector2i(4, 0)), "tile a 4 de distancia deveria estar fora do alcance de visao do guerreiro")

func test_compute_visible_tiles_includes_city_vision():
	hex_grid.found_city(Vector2i(0, 0), human, "Capital") # cidade sempre enxerga HexGrid.CITY_VISION_RANGE (4) tiles

	var visible = hex_grid.compute_visible_tiles(human)

	assert_true(visible.has(Vector2i(4, 0)))
	assert_false(visible.has(Vector2i(5, 0)))

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

	hex_grid.move_unit(scout, Vector2i(5, 0), 5.0) # afasta o unico observador humano pra fora do vision_range (3) dele
	hex_grid.recompute_fog(human)

	assert_false(enemy.visible, "unidade inimiga fora de visao atual nao deveria continuar aparecendo so por ja ter sido vista")

## Roadmap "Fase Macro" 5B.3-C -- achado do usuario jogando manualmente:
## "o Dragão nunca aparece". Causa raiz: WorldEventTrigger.choose_dragon_
## origin_region sorteia a origem entre TODOS os tiles do mapa, entao a
## Unit quase sempre nasce fora da area ja explorada -- sem always_visible,
## ficava escondida pra sempre (Boss Bar ja anuncia HP/alvo independente
## de nevoa, entao esconder o modelo fisico contradiz isso). Nenhum tile
## precisa estar visivel/explorado nenhum -- always_visible ignora a regra
## de nevoa por completo, diferente do scout de teste acima.
func test_unit_with_always_visible_ignores_fog_even_never_seen():
	var far_unit = _make_unit("warrior", rival, Vector2i(4, 0))
	far_unit.always_visible = true

	hex_grid.recompute_fog(human) # nenhuma unidade humana existe pra enxergar nada

	assert_true(far_unit.visible, "always_visible deveria ignorar a regra normal de nevoa")

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
	var building = hex_grid.place_building(Vector2i(0, 0), "v2_building_market", rival)

	hex_grid.recompute_fog(human)
	assert_true(building.visible, "predio inimigo em tile visivel deveria aparecer")

	hex_grid.move_unit(scout, Vector2i(4, 0), 4.0)
	hex_grid.recompute_fog(human)

	assert_false(building.visible, "predio inimigo fora de visao atual nao deveria continuar aparecendo")

## Marcador de obra (guindaste + barra, HexGrid._construction_markers)
## segue a MESMA regra de unidade/cidade/predio acima — sem isso, a barra
## de progresso de uma cidade inimiga vazava visivel mesmo debaixo da
## nevoa, entregando "essa cidade esta construindo algo ali" de graca, na
## contramao do que o usuario pediu explicitamente na saga de fog-of-war
## ("eu quero que so seja possivel ver nevoa, sem relevos").
func test_enemy_construction_marker_only_visible_when_tile_is_currently_visible():
	var scout = _make_unit("warrior", human, Vector2i(1, 0))
	var city = hex_grid.found_city(Vector2i(0, 0), rival, "Capital Rival")
	city.pending_building_coord = Vector2i(0, 0)
	hex_grid.refresh_construction_markers()
	var marker: Node3D = hex_grid._construction_markers[Vector2i(0, 0)]

	hex_grid.recompute_fog(human)
	assert_true(marker.visible, "obra inimiga em tile visivel deveria aparecer")

	hex_grid.move_unit(scout, Vector2i(4, 0), 4.0)
	hex_grid.recompute_fog(human)

	assert_false(marker.visible, "obra inimiga fora de visao atual nao deveria continuar aparecendo")

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

## PERFORMANCE: recompute_fog expoe o delta (Minimap e as texturas de fog
## pintam so' o que mudou em vez de refazer o mapa inteiro a cada passo).
func test_recompute_fog_reports_only_the_tiles_that_changed():
	var unit := _make_unit("warrior", human, Vector2i(0, 0)) # vision_range 3

	hex_grid.recompute_fog(human)
	assert_true(hex_grid.last_fog_was_full, "o primeiro recompute de um mapa novo recomeca do zero")
	assert_true(hex_grid.last_fog_changed.has(Vector2i(3, 0)))

	hex_grid.recompute_fog(human)
	assert_false(hex_grid.last_fog_was_full)
	assert_true(hex_grid.last_fog_changed.is_empty(), "nada mudou de visibilidade")

	hex_grid.units_by_coord.erase(unit.coord)
	unit.coord = Vector2i(3, 0)
	hex_grid.units_by_coord[unit.coord] = unit
	hex_grid.recompute_fog(human)
	assert_true(hex_grid.last_fog_changed.has(Vector2i(5, 0)), "tile novo entrou na visao")
	assert_true(hex_grid.last_fog_changed.has(Vector2i(-1, 0)), "tile antigo saiu da visao (VISIBLE -> EXPLORED)")
	assert_false(hex_grid.last_fog_changed.has(Vector2i(2, 0)), "tile que continua visivel nao entra no delta")

## As texturas de fog agora sao atualizadas por delta (`changed`) em cima do
## buffer anterior. O resultado tem que ser byte a byte o de uma
## reconstrucao completa a partir de `visibility`, passando por UNSEEN ->
## VISIBLE, VISIBLE -> EXPLORED e pela revelacao total do modo Debug.
func test_incremental_fog_textures_match_a_full_rebuild():
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 555)
	var player := PlayerData.new(CivilizationData.new())
	var land: Array = grid.tiles.keys().filter(func(c): return not grid.tiles[c].blocks_land_units() and grid.get_unit_at(c) == null and not grid.lairs_by_coord.has(c))
	land.sort()
	var scout_a := grid.spawn_unit(land[0], UnitDatabase.create_unit("warrior"), player)
	var scout_b := grid.spawn_unit(land[land.size() - 1], UnitDatabase.create_unit("warrior"), player)
	assert_not_null(scout_a, "pre-condicao: batedor A nasceu")
	assert_not_null(scout_b, "pre-condicao: batedor B nasceu")
	assert_gt(HexMetrics.axial_distance(scout_a.coord, scout_b.coord), 9, "pre-condicao: batedores distantes")
	player.units.erase(scout_b) # so' A enxerga no primeiro recompute
	grid.recompute_fog(player)
	player.units.append(scout_b)
	grid.recompute_fog(player) # B aparece: delta UNSEEN -> VISIBLE
	player.units.erase(scout_a)
	grid.recompute_fog(player) # A some: delta VISIBLE -> EXPLORED

	_assert_fog_textures_match_full_rebuild(grid, "depois de VISIBLE -> EXPLORED")

	assert_gt(grid.visibility.values().count(HexGrid.Visibility.EXPLORED), 0, "pre-condicao: houve transicao VISIBLE -> EXPLORED")
	assert_gt(grid.visibility.values().count(HexGrid.Visibility.VISIBLE), 0, "pre-condicao: B continua enxergando")

	grid.debug_fog_disabled = true
	grid.recompute_fog(player)
	_assert_fog_textures_match_full_rebuild(grid, "com o mapa todo revelado (Debug)")

	grid.debug_fog_disabled = false
	grid.recompute_fog(player)
	_assert_fog_textures_match_full_rebuild(grid, "ao religar a neblina")
	grid.queue_free()

func _assert_fog_textures_match_full_rebuild(grid: HexGrid, context: String) -> void:
	var liquid_incremental := grid._liquid_fog_bytes.duplicate()
	var biome_incremental := grid._biome_fog_bytes.duplicate()
	assert_gt(liquid_incremental.size(), 0, "pre-condicao (%s): buffer de fog da agua existe" % context)
	grid._rebuild_liquid_type_texture()
	grid._rebuild_biome_overlay()
	assert_true(liquid_incremental == grid._liquid_fog_bytes, "fog da agua por delta difere da reconstrucao completa (%s)" % context)
	assert_true(biome_incremental == grid._biome_fog_bytes, "fog do bioma por delta difere da reconstrucao completa (%s)" % context)
