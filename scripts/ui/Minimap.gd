extends Control

## Minimapa desenhado a mao (sem viewport extra). Clicar OU arrastar nele reposiciona a camera principal
## (EventBus.minimap_clicked).
##
## V3 / Etapa 4 — MODELO CANÔNICO: o MAPA é fixo, só o INDICADOR DA CÂMERA se move.
## - Enquadramento FIXO por mapa: os limites do mundo jogável (retângulo XZ de toda a terra + margem) são calculados
##   UMA vez por mapa (grade/seed/dimensões) e a transformação mundo → minimapa (escala UNIFORME, centrada na área útil)
##   só muda com mapa novo/load/reinício ou com o painel realmente redimensionado. Mover/zoom da câmera, fundar cidade,
##   explorar ou virar o turno NUNCA recalculam o enquadramento. (A Etapa 3 usava um "quadro adaptativo" seguindo as
##   unidades/cidades do humano: no playtest ele parecia congelado numa região e de repente voltava a mostrar o
##   continente inteiro — removido.)
## - Hexágonos de verdade: cada pixel pertence ao hex cujo centro está mais perto (a mesma conta de
##   HexMetrics.world_to_axial), então a geografia é contínua E a costa/transições mostram a borda hexagonal. Contorno
##   muito sutil (só o pixel de fronteira, escurecido) quando o hex tem largura suficiente para ser lido.
## - Cache: o mapa pixel → tile é calculado uma vez por enquadramento; os TILES vivem numa Image persistente. Delta da
##   névoa repinta só os pixels dos tiles que mudaram (HexGrid.last_fog_changed); unidades/cidades/indicador (poucas
##   formas) são desenhados ao vivo em _draw(), que só roda quando a câmera de fato mudou.
## - Indicador: os 4 cantos da tela por raio real da câmera contra o chão, na transformação fixa, recortado ao retângulo
##   do mapa. Câmera totalmente fora do mundo: um marcador na borda mais próxima, apontando para onde ela está.
const DOT_UNIT := 2.5
const DOT_CITY := 4.5
const CONTENT_PADDING := 5.0
## Margem (em hexes) em volta da terra no enquadramento fixo — o mar da costa aparece, o canvas vazio não.
const WORLD_MARGIN_HEXES := 1.5
## Contorno sutil do hex: fator aplicado ao pixel de fronteira entre dois hexes, só com hex de largura >= HEX_EDGE_MIN_PX.
const HEX_EDGE_SHADE := 0.84
const HEX_EDGE_MIN_PX := 3.0
const CAMERA_RECT_COLOR := Color(0.42, 0.66, 0.86, 0.9) # UITheme.COLOR_ACCENT — mesmo azul ja usado pra "foco" em botoes/campos
const CAMERA_MAX_GROUND_DISTANCE := 60.0
const EDGE_MARKER_SIZE := 6.0

## Pedido para ampliar/reduzir o painel (HUD liga ao UIShell.set_minimap_expanded): ampliado, os hexágonos ficam
## nítidos; o enquadramento continua o mesmo mundo inteiro, só em escala maior.
signal expand_toggled(expanded: bool)

var _panel_style: StyleBoxFlat
var _dragging := false
var expanded := false
var expand_button: Button
var _last_cam_position := Vector3.INF
var _last_cam_basis_z := Vector3.INF
var _last_cam_local_pos := Vector3.INF
var _last_screen_size := Vector2.ZERO
var _terrain_image: Image
var _terrain_texture: ImageTexture
var _rgba := PackedByteArray()
var _image_size := Vector2i.ZERO
## Enquadramento fixo: limites do mundo (XZ), retângulo em pixels onde ele é desenhado e escala (px por unidade).
var _world_bounds := Rect2()
var _map_rect := Rect2()
var _scale := 0.0
var _map_key := ""
var _layout_size := Vector2.ZERO
## Mapa pixel → tile do enquadramento atual.
var _tile_pixels: Dictionary = {} # Vector2i -> PackedInt32Array (índices de pixel)
var _edge_pixels := PackedByteArray() # 1 = pixel de fronteira entre hexes
var _hex_edges := false
## Mapas pixel → tile já calculados neste mapa, por tamanho de painel (compacto/ampliado): alternar o botão de ampliar
## não refaz o raster. Limpo quando o mapa muda.
var _layout_cache: Dictionary = {}
const LAYOUT_CACHE_MAX := 3
## Telemetria/testes: quantas vezes o enquadramento (layout) e a imagem inteira foram refeitos.
var layout_rebuilds := 0
var terrain_rebuilds := 0

func _ready() -> void:
	_panel_style = UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_PANEL, false)
	EventBus.fog_updated.connect(_on_fog_updated)
	EventBus.restart_requested.connect(_on_restart)
	resized.connect(_rebuild_terrain)
	_build_expand_button()
	_rebuild_terrain()

func _build_expand_button() -> void:
	expand_button = Button.new()
	expand_button.name = "ExpandButton"
	expand_button.flat = true
	expand_button.focus_mode = Control.FOCUS_NONE
	expand_button.theme_type_variation = &"CaptionLabel"
	expand_button.custom_minimum_size = Vector2(20, 20)
	expand_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	expand_button.offset_left = -22.0
	expand_button.offset_right = -2.0
	expand_button.offset_top = 2.0
	expand_button.offset_bottom = 22.0
	expand_button.pressed.connect(func(): set_expanded(not expanded))
	add_child(expand_button)
	_refresh_expand_button()

func set_expanded(value: bool) -> void:
	expanded = value
	_refresh_expand_button()
	expand_toggled.emit(expanded)

func _refresh_expand_button() -> void:
	if expand_button == null:
		return
	expand_button.text = "−" if expanded else "+"
	expand_button.tooltip_text = "Reduzir minimapa" if expanded else "Ampliar minimapa (hexágonos nítidos)"

# ---------------------------------------------------------------------------
# Enquadramento fixo
# ---------------------------------------------------------------------------

## Limites do mundo jogável em XZ: retângulo de toda a terra (não água) com a meia-largura do hex e WORLD_MARGIN_HEXES
## de margem — calculado do MAPA (nunca da névoa nem da câmera). Mapa sem terra usa todos os tiles.
static func compute_world_bounds(grid: HexGrid) -> Rect2:
	var has_point := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for pass_index in 2:
		for coord in grid.tiles:
			var data: HexTileData = grid.tiles[coord]
			if pass_index == 0 and data.is_water():
				continue
			var world := HexMetrics.axial_to_world(coord.x, coord.y, grid.hex_size)
			var point := Vector2(world.x, world.z)
			if not has_point:
				min_point = point
				max_point = point
				has_point = true
			else:
				min_point = min_point.min(point)
				max_point = max_point.max(point)
		if has_point:
			break
	if not has_point:
		return Rect2()
	var half_hex := Vector2(sqrt(3.0) * 0.5, 1.0) * grid.hex_size
	var margin := Vector2.ONE * grid.hex_size * WORLD_MARGIN_HEXES * sqrt(3.0)
	return Rect2(min_point - half_hex - margin, max_point - min_point + (half_hex + margin) * 2.0)

func _map_identity(grid: HexGrid) -> String:
	return "%d:%d:%d:%d:%d" % [grid.get_instance_id(), grid.map_seed, grid.map_width, grid.map_height, grid.tiles.size()]

func _content_rect() -> Rect2:
	return Rect2(Vector2.ONE * CONTENT_PADDING, size - Vector2.ONE * CONTENT_PADDING * 2.0)

## Recalcula o enquadramento SÓ se o mapa (identidade) ou o tamanho do painel mudou. true = refez.
func _ensure_layout(grid: HexGrid) -> bool:
	var key := _map_identity(grid)
	if key == _map_key and _layout_size == size and _image_size == _image_dims():
		return false
	if key != _map_key:
		_world_bounds = compute_world_bounds(grid)
		_layout_cache.clear()
	_map_key = key
	_layout_size = size
	var size_key := "%dx%d" % [_image_dims().x, _image_dims().y]
	if _layout_cache.has(size_key):
		var cached: Dictionary = _layout_cache[size_key]
		_scale = cached.scale
		_map_rect = cached.map_rect
		_tile_pixels = cached.tile_pixels
		_edge_pixels = cached.edge_pixels
		_hex_edges = cached.hex_edges
		return true
	var content := _content_rect()
	_scale = 0.0
	_map_rect = Rect2()
	if _world_bounds.size.x > 0.0 and _world_bounds.size.y > 0.0 and content.size.x > 0.0 and content.size.y > 0.0:
		_scale = minf(content.size.x / _world_bounds.size.x, content.size.y / _world_bounds.size.y)
		var drawn := _world_bounds.size * _scale
		_map_rect = Rect2(content.position + (content.size - drawn) * 0.5, drawn)
	_tile_pixels = {}
	_compute_pixel_map(grid)
	if _layout_cache.size() >= LAYOUT_CACHE_MAX:
		_layout_cache.clear() # janela redimensionada muitas vezes: não acumula rasters
	_layout_cache[size_key] = {"scale": _scale, "map_rect": _map_rect, "tile_pixels": _tile_pixels, "edge_pixels": _edge_pixels, "hex_edges": _hex_edges}
	layout_rebuilds += 1
	return true

func _image_dims() -> Vector2i:
	return Vector2i(maxi(2, ceili(size.x)), maxi(2, ceili(size.y)))

## Mapa pixel → tile (uma vez por enquadramento): o centro de cada pixel volta ao mundo pela transformação fixa e cai
## no hex mais próximo (arredondamento cúbico de HexMetrics, embutido aqui pelo custo). Marca também os pixels de
## fronteira (vizinho à direita/abaixo pertence a outro hex) para o contorno sutil.
func _compute_pixel_map(grid: HexGrid) -> void:
	_tile_pixels.clear()
	var dims := _image_dims()
	_edge_pixels = PackedByteArray()
	_edge_pixels.resize(dims.x * dims.y)
	if _scale <= 0.0:
		return
	var owner_ids := PackedInt32Array()
	owner_ids.resize(dims.x * dims.y)
	owner_ids.fill(-1)
	var ids: Dictionary = {}
	var building: Dictionary = {}
	var hex_size := grid.hex_size
	var x0 := maxi(0, floori(_map_rect.position.x))
	var y0 := maxi(0, floori(_map_rect.position.y))
	var x1 := mini(dims.x, ceili(_map_rect.end.x))
	var y1 := mini(dims.y, ceili(_map_rect.end.y))
	for y in range(y0, y1):
		var world_z := _world_bounds.position.y + (float(y) + 0.5 - _map_rect.position.y) / _scale
		var r_frac := (2.0 / 3.0 * world_z) / hex_size
		var last_coord := Vector2i(-2147483648, 0)
		var last_id := -1
		for x in range(x0, x1):
			var world_x := _world_bounds.position.x + (float(x) + 0.5 - _map_rect.position.x) / _scale
			var q_frac := (sqrt(3.0) / 3.0 * world_x - 1.0 / 3.0 * world_z) / hex_size
			var s_frac := -q_frac - r_frac
			var rq := roundf(q_frac)
			var rr := roundf(r_frac)
			var rs := roundf(s_frac)
			var dq := absf(rq - q_frac)
			var dr := absf(rr - r_frac)
			var ds := absf(rs - s_frac)
			if dq > dr and dq > ds:
				rq = -rr - rs
			elif dr > ds:
				rr = -rq - rs
			var coord := Vector2i(int(rq), int(rr))
			var index := y * dims.x + x
			if coord == last_coord: # pixels vizinhos na linha quase sempre caem no mesmo hex: sem consultar dicionário
				if last_id >= 0:
					owner_ids[index] = last_id
					(building[coord] as Array).append(index)
				continue
			last_coord = coord
			last_id = -1
			if not grid.tiles.has(coord):
				continue
			var id: int = ids.get(coord, -1)
			if id < 0:
				id = ids.size()
				ids[coord] = id
				building[coord] = []
			last_id = id
			owner_ids[index] = id
			(building[coord] as Array).append(index) # Array (referência); PackedInt32Array no dicionário seria cópia
	for coord in building:
		_tile_pixels[coord] = PackedInt32Array(building[coord])
	for y in range(y0, y1):
		for x in range(x0, x1):
			var index := y * dims.x + x
			var own := owner_ids[index]
			if own < 0:
				continue
			if (x + 1 < x1 and owner_ids[index + 1] >= 0 and owner_ids[index + 1] != own) or (y + 1 < y1 and owner_ids[index + dims.x] >= 0 and owner_ids[index + dims.x] != own):
				_edge_pixels[index] = 1
	_hex_edges = sqrt(3.0) * hex_size * _scale >= HEX_EDGE_MIN_PX

# ---------------------------------------------------------------------------
# Imagem de terreno (cache)
# ---------------------------------------------------------------------------

## Refaz a imagem inteira (mapa novo/carregado, reinício, painel redimensionado, névoa "full"). O enquadramento só é
## recalculado se o mapa ou o tamanho mudou de verdade.
func _rebuild_terrain() -> void:
	var dims := _image_dims()
	if _terrain_image == null or _image_size != dims:
		_image_size = dims
		_terrain_image = Image.create(dims.x, dims.y, false, Image.FORMAT_RGBA8)
		_terrain_texture = null
	_rgba = PackedByteArray()
	_rgba.resize(dims.x * dims.y * 4)
	var grid = GameManager.hex_grid
	if grid != null and not grid.tiles.is_empty():
		_ensure_layout(grid)
		_paint_tiles(_tile_pixels.keys(), grid)
	_terrain_image.set_data(dims.x, dims.y, false, Image.FORMAT_RGBA8, _rgba)
	if _terrain_texture == null:
		_terrain_texture = ImageTexture.create_from_image(_terrain_image)
	else:
		_terrain_texture.update(_terrain_image)
	terrain_rebuilds += 1
	queue_redraw()

func _on_restart() -> void:
	_map_key = ""
	_rebuild_terrain()

## Delta de névoa: repinta só os tiles que mudaram, a menos que a grade tenha recomeçado (mapa novo — a imagem antiga
## não tem como "despintar" o mapa velho) ou o mapa tenha trocado por baixo.
func _on_fog_updated() -> void:
	var grid = GameManager.hex_grid
	if grid == null:
		return
	if _terrain_image == null or grid.last_fog_was_full or _map_identity(grid) != _map_key or _layout_size != size:
		_rebuild_terrain()
		return
	_paint_tiles(grid.last_fog_changed, grid)
	_terrain_image.set_data(_image_size.x, _image_size.y, false, Image.FORMAT_RGBA8, _rgba)
	_terrain_texture.update(_terrain_image)
	queue_redraw()

func _paint_tiles(coords: Array, grid: HexGrid) -> void:
	for coord in coords:
		var pixels: PackedInt32Array = _tile_pixels.get(coord, PackedInt32Array())
		if pixels.is_empty():
			continue
		var vis = grid.visibility.get(coord, HexGrid.Visibility.UNSEEN)
		var data: HexTileData = grid.tiles.get(coord)
		var color := Color(0, 0, 0, 0) if vis == HexGrid.Visibility.UNSEEN or data == null else tile_color(data, vis)
		var edge := Color(color.r * HEX_EDGE_SHADE, color.g * HEX_EDGE_SHADE, color.b * HEX_EDGE_SHADE, color.a)
		# RGBA8 little-endian num só u32 por pixel (4x menos escritas que byte a byte).
		var fill := color.r8 | (color.g8 << 8) | (color.b8 << 16) | (color.a8 << 24)
		var edge_fill := edge.r8 | (edge.g8 << 8) | (edge.b8 << 16) | (edge.a8 << 24)
		if _hex_edges:
			for index in pixels:
				_rgba.encode_u32(index * 4, edge_fill if _edge_pixels[index] == 1 else fill)
		else:
			for index in pixels:
				_rgba.encode_u32(index * 4, fill)

## Cor do tile no minimapa: cor do terreno; lembrado (fora da visão) escurecido e opaco.
static func tile_color(data: HexTileData, vis: int) -> Color:
	var color := data.color
	if vis == HexGrid.Visibility.EXPLORED:
		color = Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1.0)
	color.a = 1.0
	return color

# ---------------------------------------------------------------------------
# Transformação fixa (API pública: testes/validação)
# ---------------------------------------------------------------------------

func world_bounds() -> Rect2:
	return _world_bounds

func map_rect() -> Rect2:
	return _map_rect

func world_to_minimap(world: Vector2) -> Vector2:
	return _map_rect.position + (world - _world_bounds.position) * _scale

func minimap_to_world(local: Vector2) -> Vector2:
	return _world_bounds.position + (local - _map_rect.position) / maxf(_scale, 0.0001)

func _project(coord: Vector2i, hex_size: float) -> Vector2:
	var world := HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	return world_to_minimap(Vector2(world.x, world.z))

## Tile dono de um pixel da imagem de terreno (Vector2i(INT_MIN, ...) se nenhum) — validação do raster hexagonal.
func pixel_tile(pixel: Vector2i) -> Vector2i:
	var index := pixel.y * _image_size.x + pixel.x
	for coord in _tile_pixels:
		if (_tile_pixels[coord] as PackedInt32Array).has(index):
			return coord
	return Vector2i(-2147483648, -2147483648)

# ---------------------------------------------------------------------------
# Desenho ao vivo
# ---------------------------------------------------------------------------

## Só pede redraw quando a câmera de fato mudou (posição/rotação do rig, zoom/posição local da Camera3D, tamanho da
## tela) — parado custa 3 comparações por frame. Nunca refaz terreno nem enquadramento.
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cam: RTSCamera = GameManager.camera_rig
	if cam == null or not is_instance_valid(cam):
		return
	var basis_z := cam.global_transform.basis.z
	var screen_size := cam.camera.get_viewport().get_visible_rect().size
	if cam.global_position != _last_cam_position or basis_z != _last_cam_basis_z or cam.camera.position != _last_cam_local_pos or screen_size != _last_screen_size:
		_last_screen_size = screen_size
		_last_cam_position = cam.global_position
		_last_cam_basis_z = basis_z
		_last_cam_local_pos = cam.camera.position
		queue_redraw()

func _draw() -> void:
	_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var grid = GameManager.hex_grid
	if grid != null and not grid.tiles.is_empty() and (_map_identity(grid) != _map_key or _layout_size != size):
		_rebuild_terrain() # mapa trocado sem sinal (fixtures): refaz uma vez; nunca por câmera
	if _terrain_texture:
		draw_texture(_terrain_texture, Vector2.ZERO)
	if grid == null or grid.tiles.is_empty() or _scale <= 0.0:
		return
	_draw_entities(grid)
	_draw_camera_viewport()

func _draw_entities(hex_grid: HexGrid) -> void:
	for coord in hex_grid.units_by_coord.keys():
		var unit: Unit = hex_grid.units_by_coord[coord]
		if not unit.visible:
			continue
		var px := _project(coord, hex_grid.hex_size)
		if _map_rect.has_point(px):
			draw_circle(px, DOT_UNIT, _unit_dot_color(unit))
	for coord in hex_grid.cities_by_coord.keys():
		var city: City = hex_grid.cities_by_coord[coord]
		if not city.visible:
			continue
		var px := _project(coord, hex_grid.hex_size)
		if _map_rect.has_point(px):
			draw_circle(px, DOT_CITY, city.owner_player.civ.color)
			draw_arc(px, DOT_CITY + 1.0, 0.0, TAU, 12, Color.WHITE, 1.0)

## Contorno do campo de visão real da câmera (TRAPÉZIO: a câmera é inclinada) — só o contorno, nunca preenchido, para
## não esconder o minimapa. Fora do mundo: marcador de borda.
func _draw_camera_viewport() -> void:
	var cam: RTSCamera = GameManager.camera_rig
	if cam == null or not is_instance_valid(cam):
		return
	var viewport := cam.camera.get_viewport()
	if viewport == null:
		return
	var screen_size := viewport.get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var indicator := camera_indicator(cam.camera, screen_size)
	for piece in indicator.polygon:
		draw_polyline(piece + PackedVector2Array([piece[0]]), CAMERA_RECT_COLOR, 1.6, true)
	if indicator.has("edge_marker"):
		draw_colored_polygon(indicator.edge_marker, CAMERA_RECT_COLOR)

## Pontos do chão (XZ) dos 4 cantos da tela por raio REAL da câmera contra o plano Y=0. Raio que não acerta o chão (ou
## acerta além de CAMERA_MAX_GROUND_DISTANCE, perto do horizonte) é limitado a essa distância na direção do raio —
## nunca some nem vira polígono degenerado; nenhum ponto não-finito passa.
static func camera_ground_points(camera3d: Camera3D, screen_size: Vector2) -> PackedVector2Array:
	var ground := Plane(Vector3.UP, 0.0)
	var origin_ground := Vector2(camera3d.global_position.x, camera3d.global_position.z)
	var points := PackedVector2Array()
	for screen_pt in [Vector2.ZERO, Vector2(screen_size.x, 0.0), screen_size, Vector2(0.0, screen_size.y), screen_size * 0.5]:
		var from := camera3d.project_ray_origin(screen_pt)
		var dir := camera3d.project_ray_normal(screen_pt)
		var hit = ground.intersects_ray(from, dir)
		var flat := Vector2(dir.x, dir.z)
		var point := origin_ground
		if hit != null and Vector2(hit.x, hit.z).distance_to(origin_ground) <= CAMERA_MAX_GROUND_DISTANCE:
			point = Vector2(hit.x, hit.z)
		elif flat.length() > 0.0001:
			point = origin_ground + flat.normalized() * CAMERA_MAX_GROUND_DISTANCE
		if not (is_finite(point.x) and is_finite(point.y)):
			return PackedVector2Array()
		points.append(point)
	return points

## Indicador da câmera na transformação FIXA: {"polygon": pedaços recortados ao retângulo do mapa} e, se a câmera está
## inteira fora do mundo, {"edge_marker": triângulo na borda mais próxima apontando para ela}.
func camera_indicator(camera3d: Camera3D, screen_size: Vector2) -> Dictionary:
	var result := {"polygon": [] as Array[PackedVector2Array]}
	if _scale <= 0.0:
		return result
	var ground := camera_ground_points(camera3d, screen_size)
	if ground.size() < 5:
		return result
	var points := PackedVector2Array()
	for i in 4:
		points.append(world_to_minimap(ground[i]))
	var box := PackedVector2Array([_map_rect.position, Vector2(_map_rect.end.x, _map_rect.position.y), _map_rect.end, Vector2(_map_rect.position.x, _map_rect.end.y)])
	if Geometry2D.is_polygon_clockwise(points) != Geometry2D.is_polygon_clockwise(box):
		points.reverse()
	for piece in Geometry2D.intersect_polygons(points, box):
		if piece.size() >= 3:
			result.polygon.append(piece)
	if (result.polygon as Array).is_empty():
		var center := world_to_minimap(ground[4])
		var anchor := Vector2(clampf(center.x, _map_rect.position.x, _map_rect.end.x), clampf(center.y, _map_rect.position.y, _map_rect.end.y))
		var direction := (center - anchor).normalized() if center.distance_to(anchor) > 0.001 else Vector2.UP
		var side := direction.orthogonal() * EDGE_MARKER_SIZE * 0.6
		var base := anchor - direction * EDGE_MARKER_SIZE
		result.edge_marker = PackedVector2Array([anchor, base + side, base - side])
	return result

func _unit_dot_color(unit: Unit) -> Color:
	return unit.owner_player.civ.color if unit.owner_player else Unit.MONSTER_COLOR

# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_pan_to(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_pan_to(event.position)

func _pan_to(local_pos: Vector2) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null or _scale <= 0.0:
		return
	var clamped := Vector2(clampf(local_pos.x, _map_rect.position.x, _map_rect.end.x), clampf(local_pos.y, _map_rect.position.y, _map_rect.end.y))
	var world := minimap_to_world(clamped)
	EventBus.minimap_clicked.emit(Vector3(world.x, 0.0, world.y))
