extends GutTest

## Cobre Minimap.gd — bug reportado pelo usuario: "quando tiro a neblina
## crasha o jogo ele travou". Guardiao de Covil de Monstro (Unit sem
## owner_player, ver MonsterDatabase) virava visivel de uma vez ao
## desligar a neblina de guerra (Debug > Revelar Mapa), e _draw() lia
## `unit.owner_player.civ.color` sem checar null — um guardiao visivel no
## minimapa derrubava o redesenho inteiro (rodando pelo editor, isso pausa
## o jogo no debugger de erro de script, sensacao de "travou").

var hud: Control
var _units: Array[Unit] = []

func before_each():
	_units = []
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()

func _make_unit(kind: String, player: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind) if player else MonsterDatabase.create_monster(kind), player, Vector2i(0, 0))
	_units.append(unit)
	return unit

func test_unit_dot_color_falls_back_to_monster_color_without_an_owner():
	var monster := _make_unit("goblin", null)

	var minimap: Control = hud.minimap
	var color = minimap._unit_dot_color(monster)

	assert_eq(color, Unit.MONSTER_COLOR)

func test_unit_dot_color_uses_civilization_color_when_owned():
	var human := PlayerData.new(CivilizationData.new())
	human.civ.color = Color(0.1, 0.2, 0.3)
	var warrior := _make_unit("warrior", human)

	var minimap: Control = hud.minimap
	var color = minimap._unit_dot_color(warrior)

	assert_eq(color, Color(0.1, 0.2, 0.3))

## PERFORMANCE: os tiles vivem numa Image persistente e fog_updated pinta so'
## o delta (HexGrid.last_fog_changed) -- antes cada passo de unidade
## redesenhava ~27 mil retangulos (~60ms com o mapa revelado).
func _land_coords(grid: HexGrid) -> Array:
	var coords: Array = grid.tiles.keys().filter(func(c): return not grid.tiles[c].blocks_land_units() and grid.get_unit_at(c) == null and not grid.lairs_by_coord.has(c))
	coords.sort()
	return coords

func _terrain_alpha_at(minimap: Control, grid: HexGrid, coord: Vector2i) -> float:
	var px: Vector2 = minimap._project(coord, grid.hex_size)
	# pixel que contém o centro do hex (Etapa 4: raster hexagonal — pertence sempre a este tile)
	return minimap._terrain_image.get_pixelv(Vector2i(floori(px.x), floori(px.y))).a

func test_fog_update_paints_only_the_changed_tiles_into_the_terrain_image():
	var original_grid: HexGrid = GameManager.hex_grid
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 555)
	GameManager.hex_grid = grid
	var minimap: Control = hud.minimap
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.size = Vector2(300, 80)
	var player := PlayerData.new(CivilizationData.new())
	var land := _land_coords(grid)
	var first: Vector2i = land[0]
	var second: Vector2i = land[land.size() - 1]
	assert_gt(HexMetrics.axial_distance(first, second), 9, "pre-condicao: os dois batedores nao se enxergam")
	assert_not_null(grid.spawn_unit(first, UnitDatabase.create_unit("warrior"), player), "pre-condicao: batedor nasceu")

	grid.recompute_fog(player)

	assert_gt(_terrain_alpha_at(minimap, grid, first), 0.0, "tile visto aparece no minimapa")
	assert_eq(_terrain_alpha_at(minimap, grid, second), 0.0, "tile nunca visto continua transparente")

	assert_not_null(grid.spawn_unit(second, UnitDatabase.create_unit("warrior"), player), "pre-condicao: segundo batedor nasceu")
	var image_before: Image = minimap._terrain_image
	grid.recompute_fog(player)

	assert_false(grid.last_fog_was_full)
	assert_same(minimap._terrain_image, image_before, "delta pinta a MESMA imagem, nao a refaz")
	assert_gt(_terrain_alpha_at(minimap, grid, second), 0.0, "tile revelado pelo delta aparece")
	assert_gt(_terrain_alpha_at(minimap, grid, first), 0.0, "tile antigo continua pintado")

	GameManager.hex_grid = original_grid
	grid.queue_free()

func test_terrain_image_restarts_when_the_grid_restarts():
	var original_grid: HexGrid = GameManager.hex_grid
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 555)
	GameManager.hex_grid = grid
	var minimap: Control = hud.minimap
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.size = Vector2(300, 80)
	var player := PlayerData.new(CivilizationData.new())
	var first: Vector2i = _land_coords(grid)[0]
	assert_not_null(grid.spawn_unit(first, UnitDatabase.create_unit("warrior"), player), "pre-condicao: batedor nasceu")
	grid.recompute_fog(player)
	assert_gt(_terrain_alpha_at(minimap, grid, first), 0.0, "pre-condicao")

	# Mapa novo na mesma grade (restart/load): o primeiro recompute e' "full"
	# e a imagem antiga, com tiles do mapa velho, tem que ser refeita.
	grid.generate_map(21, 21, 999)
	var other_player := PlayerData.new(CivilizationData.new())
	var other_land := _land_coords(grid)
	var scouted: Vector2i = other_land[other_land.size() - 1]
	var untouched: Vector2i = other_land[0]
	assert_gt(HexMetrics.axial_distance(scouted, untouched), 9, "pre-condicao")
	assert_not_null(grid.spawn_unit(scouted, UnitDatabase.create_unit("warrior"), other_player), "pre-condicao: batedor nasceu")
	grid.recompute_fog(other_player)

	assert_true(grid.last_fog_was_full)
	assert_gt(_terrain_alpha_at(minimap, grid, scouted), 0.0)
	assert_eq(_terrain_alpha_at(minimap, grid, untouched), 0.0, "nada do mapa antigo sobra pintado")

	GameManager.hex_grid = original_grid
	grid.queue_free()

## V3 / Etapa 4: o enquadramento é FIXO (mundo jogável inteiro) — unidade distante, turnos e névoa nunca o mudam.
func test_fixed_frame_covers_all_land_and_never_follows_units_or_turns():
	var original_grid: HexGrid = GameManager.hex_grid
	var original_human: PlayerData = GameManager.human_player
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(61, 61, 777)
	var player := PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = grid
	GameManager.human_player = player
	var land := _land_coords(grid)
	assert_not_null(grid.spawn_unit(land[0], UnitDatabase.create_unit("warrior"), player))
	var minimap: Control = hud.minimap
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.size = Vector2(300, 120)
	minimap._on_restart()
	var bounds: Rect2 = minimap.world_bounds()
	var rect: Rect2 = minimap.map_rect()
	var layouts: int = minimap.layout_rebuilds
	for coord in grid.tiles:
		if not grid.tiles[coord].is_water():
			var world := HexMetrics.axial_to_world(coord.x, coord.y, grid.hex_size)
			assert_true(bounds.has_point(Vector2(world.x, world.z)), "toda a terra cabe no enquadramento")
	var far_unit := grid.spawn_unit(land[land.size() - 1], UnitDatabase.create_unit("warrior"), player)
	assert_not_null(far_unit)
	grid.recompute_fog(player)
	grid.recompute_fog(player)
	assert_eq(minimap.world_bounds(), bounds, "limites fixos")
	assert_eq(minimap.map_rect(), rect, "transformação fixa")
	assert_eq(minimap.layout_rebuilds, layouts, "nenhum recálculo de enquadramento")
	GameManager.human_player = original_human
	GameManager.hex_grid = original_grid
	grid.queue_free()

func test_minimap_click_maps_through_the_fixed_transform():
	var original_grid: HexGrid = GameManager.hex_grid
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(41, 41, 778)
	GameManager.hex_grid = grid
	var minimap: Control = hud.minimap
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.size = Vector2(300, 120)
	minimap._on_restart()
	var received: Array[Vector3] = []
	var callback := func(world: Vector3): received.append(world)
	EventBus.minimap_clicked.connect(callback)
	minimap._pan_to(minimap.map_rect().get_center())
	minimap._pan_to(Vector2(-50, -50)) # fora do mapa: limitado à borda, nunca fora do mundo
	EventBus.minimap_clicked.disconnect(callback)
	assert_eq(received.size(), 2)
	assert_almost_eq(received[0].x, minimap.world_bounds().get_center().x, 0.05)
	assert_almost_eq(received[0].z, minimap.world_bounds().get_center().y, 0.05)
	assert_almost_eq(received[1].x, minimap.world_bounds().position.x, 0.05)
	assert_almost_eq(received[1].z, minimap.world_bounds().position.y, 0.05)
	GameManager.hex_grid = original_grid
	grid.queue_free()
