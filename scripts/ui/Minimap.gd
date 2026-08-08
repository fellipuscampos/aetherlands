extends Control

## Minimapa desenhado a mao (sem viewport extra): projeta as coordenadas
## axiais do HexGrid num retangulo 2D usando a mesma formula de
## HexMetrics.axial_to_world, e redesenha so quando a neblina muda (nao a
## cada frame). Clicar nele reposiciona a camera principal.

const DOT_UNIT := 2.5
const DOT_CITY := 4.5

func _ready() -> void:
	EventBus.fog_updated.connect(queue_redraw)
	EventBus.restart_requested.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.85))

	var hex_grid = GameManager.hex_grid
	if hex_grid == null or hex_grid.tiles.is_empty():
		return

	var half_w = hex_grid.hex_size * sqrt(3.0) * hex_grid.map_radius
	var half_d = hex_grid.hex_size * 1.5 * hex_grid.map_radius
	if half_w <= 0.0 or half_d <= 0.0:
		return

	for coord in hex_grid.tiles.keys():
		var vis = hex_grid.visibility.get(coord, HexGrid.Visibility.UNSEEN)
		if vis == HexGrid.Visibility.UNSEEN:
			continue
		var data: HexTileData = hex_grid.tiles[coord]
		var px = _project(coord, hex_grid.hex_size, half_w, half_d)
		var color = data.color
		if vis == HexGrid.Visibility.EXPLORED:
			color = color * 0.5
		draw_rect(Rect2(px - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), color)

	for coord in hex_grid.units_by_coord.keys():
		var unit: Unit = hex_grid.units_by_coord[coord]
		if not unit.visible:
			continue
		var px = _project(coord, hex_grid.hex_size, half_w, half_d)
		draw_circle(px, DOT_UNIT, unit.owner_player.civ.color)

	for coord in hex_grid.cities_by_coord.keys():
		var city: City = hex_grid.cities_by_coord[coord]
		if not city.visible:
			continue
		var px = _project(coord, hex_grid.hex_size, half_w, half_d)
		draw_circle(px, DOT_CITY, city.owner_player.civ.color)
		draw_arc(px, DOT_CITY + 1.0, 0.0, TAU, 12, Color.WHITE, 1.0)

func _project(coord: Vector2i, hex_size: float, half_w: float, half_d: float) -> Vector2:
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	var nx = (world.x + half_w) / (half_w * 2.0)
	var nz = (world.z + half_d) / (half_d * 2.0)
	return Vector2(nx * size.x, nz * size.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pan_to(event.position)

func _pan_to(local_pos: Vector2) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var half_w = hex_grid.hex_size * sqrt(3.0) * hex_grid.map_radius
	var half_d = hex_grid.hex_size * 1.5 * hex_grid.map_radius
	var world_x = (local_pos.x / size.x) * half_w * 2.0 - half_w
	var world_z = (local_pos.y / size.y) * half_d * 2.0 - half_d
	EventBus.minimap_clicked.emit(Vector3(world_x, 0.0, world_z))
