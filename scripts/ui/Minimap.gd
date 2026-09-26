extends Control

## Minimapa desenhado a mao (sem viewport extra): projeta as coordenadas
## axiais do HexGrid num retangulo 2D usando a mesma formula de
## HexMetrics.axial_to_world. Clicar OU arrastar nele reposiciona a camera
## principal (EventBus.minimap_clicked).
##
## Pedido do usuario ("minimapa... aparencia pouco refinada, bordas pretas
## indesejadas, posicionamento estranho, nao mostra a posicao da camera"):
## - Painel/borda agora reusam UITheme.panel_style (mesma moldura bronze
##   arredondada de QUALQUER outro painel do jogo) em vez de um
##   `draw_rect` preto chapado sem contorno nenhum — o "fundo preto" que
##   sobrava era so a ausencia de nevoa explorada aparecendo por baixo de
##   um retangulo sem moldura, lendo como um placeholder sem estilo.
## - CONTENT_PADDING mantem os quadrados/circulos de tile/unidade/cidade
##   sempre dentro da area RETA do painel, nunca por cima do canto
##   arredondado do StyleBox (evita esquinas quadradas vazando por cima da
##   moldura curva).
## - Tamanho/posicao (ver HUD.tscn) foram ajustados pra (a) encostar de
##   verdade no canto inferior esquerdo com a MESMA margem de 8px que
##   ActionBar ja usa no canto oposto, e (b) ter uma proporcao largura:
##   altura mais parecida com a do mapa de verdade (~4.9:1 num mapa Grande
##   320x84, ver HexGrid.get_world_half_extents) em vez do quase-quadrado
##   de antes, que espremia o mapa verticalmente e prejudicava a leitura
##   espacial.
## - Os TILES vivem numa Image persistente (_terrain_image): o mapa Grande
##   tem ~27 mil tiles e desenha-los (draw_rect um a um) custava ~60ms por
##   redraw com o mapa revelado — a cada passo de unidade (fog_updated) E a
##   cada frame de camera em movimento. Agora fog_updated pinta SO os tiles
##   que HexGrid.last_fog_changed diz que mudaram (dezenas, nao 27 mil) e a
##   textura e' so' reenviada; a imagem inteira so' e' refeita quando a
##   grade recomeca (last_fog_was_full), o painel muda de tamanho ou a
##   partida reinicia. Unidades/cidades/indicador de camera (poucas dezenas
##   de formas) continuam desenhados ao vivo em _draw(), que so' roda quando
##   a camera de fato mudou (_process, mesmo espirito de RTSCamera._process,
##   ver PERFORMANCE_GUIDE.md secao 3: nunca fazer trabalho quando nada mudou).
const DOT_UNIT := 2.5
const DOT_CITY := 4.5
const CONTENT_PADDING := 5.0
const CAMERA_RECT_COLOR := Color(0.42, 0.66, 0.86, 0.9) # UITheme.COLOR_ACCENT — mesmo azul ja usado pra "foco" em botoes/campos

var _panel_style: StyleBoxFlat
var _dragging := false
var _last_cam_position := Vector3.INF
var _last_cam_basis_z := Vector3.INF
var _last_cam_local_pos := Vector3.INF
var _terrain_image: Image
var _terrain_texture: ImageTexture
var _last_screen_size := Vector2.ZERO

func _ready() -> void:
	_panel_style = UITheme.panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_BORDER, 2, 8)
	EventBus.fog_updated.connect(_on_fog_updated)
	EventBus.restart_requested.connect(_rebuild_terrain)
	resized.connect(_rebuild_terrain)
	_rebuild_terrain()

## Refaz a imagem de tiles do zero (mapa novo/carregado, reinicio, painel
## redimensionado). Caro (~27 mil tiles) — so' nesses eventos raros.
func _rebuild_terrain() -> void:
	_terrain_image = Image.create(maxi(2, ceili(size.x)), maxi(2, ceili(size.y)), false, Image.FORMAT_RGBA8)
	var grid = GameManager.hex_grid
	if grid != null and not grid.tiles.is_empty():
		_paint_tiles(grid.tiles.keys(), grid)
	_terrain_texture = ImageTexture.create_from_image(_terrain_image)
	queue_redraw()

## Delta de fog: pinta so' os tiles que mudaram, a menos que a grade tenha
## recomecado (a imagem antiga nao tem como "despintar" tiles do mapa velho).
func _on_fog_updated() -> void:
	var grid = GameManager.hex_grid
	if grid == null:
		return
	if _terrain_image == null or grid.last_fog_was_full:
		_rebuild_terrain()
		return
	_paint_tiles(grid.last_fog_changed, grid)
	_terrain_texture.update(_terrain_image)
	queue_redraw()

func _paint_tiles(coords: Array, grid: HexGrid) -> void:
	var half_extents: Vector2 = grid.get_world_half_extents()
	if half_extents.x <= 0.0 or half_extents.y <= 0.0:
		return
	var content := _content_rect()
	for coord in coords:
		var vis = grid.visibility.get(coord, HexGrid.Visibility.UNSEEN)
		if vis == HexGrid.Visibility.UNSEEN:
			continue
		var data: HexTileData = grid.tiles.get(coord)
		if data == null:
			continue
		var px := _project(coord, grid.hex_size, half_extents.x, half_extents.y, content)
		var color := data.color
		if vis == HexGrid.Visibility.EXPLORED:
			color = color * 0.5
		_terrain_image.fill_rect(Rect2i(roundi(px.x - 1.2), roundi(px.y - 1.2), 2, 2), color)

## So pede redraw quando a camera de fato mudou (posicao do rig, rotacao do
## rig, ou zoom/posicao local da Camera3D dentro dele) — parado (jogador
## olhando um painel, por exemplo) custa 3 comparacoes de Vector3 por
## frame, nada mais.
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

func _content_rect() -> Rect2:
	return Rect2(Vector2.ONE * CONTENT_PADDING, size - Vector2.ONE * CONTENT_PADDING * 2.0)

func _draw() -> void:
	_panel_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if _terrain_texture:
		draw_texture(_terrain_texture, Vector2.ZERO)
	var grid = GameManager.hex_grid
	if grid == null or grid.tiles.is_empty():
		return
	var extents: Vector2 = grid.get_world_half_extents()
	if extents.x <= 0.0 or extents.y <= 0.0:
		return
	var content := _content_rect()
	_draw_entities(grid, extents.x, extents.y, content)
	_draw_camera_viewport(extents.x, extents.y, content)

func _draw_entities(hex_grid: HexGrid, half_w: float, half_d: float, content: Rect2) -> void:
	for coord in hex_grid.units_by_coord.keys():
		var unit: Unit = hex_grid.units_by_coord[coord]
		if not unit.visible:
			continue
		var px = _project(coord, hex_grid.hex_size, half_w, half_d, content)
		draw_circle(px, DOT_UNIT, _unit_dot_color(unit))

	for coord in hex_grid.cities_by_coord.keys():
		var city: City = hex_grid.cities_by_coord[coord]
		if not city.visible:
			continue
		var px = _project(coord, hex_grid.hex_size, half_w, half_d, content)
		draw_circle(px, DOT_CITY, city.owner_player.civ.color)
		draw_arc(px, DOT_CITY + 1.0, 0.0, TAU, 12, Color.WHITE, 1.0)

## Pedido do usuario: "quero um retangulo ou forma equivalente que
## represente o viewport/campo atual da camera sobre o mapa". A RTSCamera
## fica inclinada (pitch fixo, ver Main.tscn Camera3D rotation_degrees),
## entao a area do chao que ela realmente enxerga e' um TRAPEZIO (base
## perto menor, base longe maior), nao um retangulo de verdade — projetar
## os 4 cantos da tela via raycast contra o plano Y=0 (mesma referencia que
## RTSCamera ja usa pra posicao/pan, ver reset_view/_on_minimap_clicked)
## da a forma REAL, mais fiel que aproximar por um retangulo generico
## centrado na posicao da camera. So' desenha o CONTORNO (nunca preenchido)
## pra nunca esconder o conteudo do minimapa por baixo, pedido explicito do
## usuario ("nao esconder completamente o minimapa").
func _draw_camera_viewport(half_w: float, half_d: float, content: Rect2) -> void:
	var cam: RTSCamera = GameManager.camera_rig
	if cam == null or not is_instance_valid(cam):
		return
	var camera3d := cam.camera
	var viewport := camera3d.get_viewport()
	if viewport == null:
		return
	var screen_size := viewport.get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return

	var ground := Plane(Vector3.UP, 0.0)
	var corners_screen := [Vector2.ZERO, Vector2(screen_size.x, 0.0), screen_size, Vector2(0.0, screen_size.y)]
	var points := PackedVector2Array()
	for screen_pt in corners_screen:
		var from := camera3d.project_ray_origin(screen_pt)
		var dir := camera3d.project_ray_normal(screen_pt)
		var hit = ground.intersects_ray(from, dir)
		if hit == null:
			return # camera olhando pra cima (nao deveria acontecer com o pitch fixo do jogo) -- sem indicador em vez de um poligono garbage
		points.append(_project_world(hit.x, hit.z, half_w, half_d, content))

	draw_polyline(points + PackedVector2Array([points[0]]), CAMERA_RECT_COLOR, 1.6, true)

func _unit_dot_color(unit: Unit) -> Color:
	return unit.owner_player.civ.color if unit.owner_player else Unit.MONSTER_COLOR

func _project(coord: Vector2i, hex_size: float, half_w: float, half_d: float, content: Rect2) -> Vector2:
	var world = HexMetrics.axial_to_world(coord.x, coord.y, hex_size)
	return _project_world(world.x, world.z, half_w, half_d, content)

func _project_world(world_x: float, world_z: float, half_w: float, half_d: float, content: Rect2) -> Vector2:
	var nx = (world_x + half_w) / (half_w * 2.0)
	var nz = (world_z + half_d) / (half_d * 2.0)
	return content.position + Vector2(nx * content.size.x, nz * content.size.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_pan_to(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_pan_to(event.position)

func _pan_to(local_pos: Vector2) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var half_extents = hex_grid.get_world_half_extents()
	var half_w = half_extents.x
	var half_d = half_extents.y
	var content := _content_rect()
	var rel := local_pos - content.position
	var world_x = (rel.x / content.size.x) * half_w * 2.0 - half_w
	var world_z = (rel.y / content.size.y) * half_d * 2.0 - half_d
	EventBus.minimap_clicked.emit(Vector3(world_x, 0.0, world_z))
