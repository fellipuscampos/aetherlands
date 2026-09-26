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

	var minimap: Control = hud.get_node("Minimap")
	var color = minimap._unit_dot_color(monster)

	assert_eq(color, Unit.MONSTER_COLOR)

func test_unit_dot_color_uses_civilization_color_when_owned():
	var human := PlayerData.new(CivilizationData.new())
	human.civ.color = Color(0.1, 0.2, 0.3)
	var warrior := _make_unit("warrior", human)

	var minimap: Control = hud.get_node("Minimap")
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
	var extents: Vector2 = grid.get_world_half_extents()
	var px: Vector2 = minimap._project(coord, grid.hex_size, extents.x, extents.y, minimap._content_rect())
	# canto superior esquerdo do bloco 2x2 pintado por _paint_tiles
	return minimap._terrain_image.get_pixelv(Vector2i(roundi(px.x - 1.2), roundi(px.y - 1.2))).a

func test_fog_update_paints_only_the_changed_tiles_into_the_terrain_image():
	var original_grid: HexGrid = GameManager.hex_grid
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(21, 21, 555)
	GameManager.hex_grid = grid
	var minimap: Control = hud.get_node("Minimap")
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
	var minimap: Control = hud.get_node("Minimap")
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
