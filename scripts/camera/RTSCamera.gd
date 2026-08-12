class_name RTSCamera
extends Node3D

@export var pan_speed: float = 20.0
@export var zoom_speed: float = 2.0
@export var rotate_speed: float = 90.0
@export var min_zoom: float = 6.0
@export var max_zoom: float = 30.0
## Mapa agora e retangular (largura != altura em geral), entao o limite de
## pan tambem precisa ser por eixo — um unico `pan_bounds` simetrico
## deixaria sobrar/faltar espaco dependendo do eixo. Mesma proporcao da
## formula antiga (`map_radius * 1.8`): como largura/altura antigas eram
## sempre ~2*raio, `largura * 0.9` cai exatamente no mesmo valor pro caso
## simetrico, so agora calculado por eixo.
@export var pan_bounds_x: float = 40.0
@export var pan_bounds_z: float = 40.0

@onready var camera: Camera3D = $Camera3D

var _zoom_distance: float = 15.0
var _default_camera_position: Vector3
var _default_camera_rotation: Vector3

func _ready() -> void:
	_default_camera_position = camera.position
	_default_camera_rotation = camera.rotation_degrees
	_zoom_distance = camera.position.length()
	pan_bounds_x = float(GameManager.map_width) * 0.9
	pan_bounds_z = float(GameManager.map_height) * 0.9
	EventBus.minimap_clicked.connect(_on_minimap_clicked)

func _on_minimap_clicked(world_pos: Vector3) -> void:
	position.x = clamp(world_pos.x, -pan_bounds_x, pan_bounds_x)
	position.z = clamp(world_pos.z, -pan_bounds_z, pan_bounds_z)

## Chamado ao reiniciar a partida: volta a camera pra posicao/zoom inicial
## em vez de manter onde o jogador da partida anterior deixou.
func reset_view() -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.position = _default_camera_position
	camera.rotation_degrees = _default_camera_rotation
	_zoom_distance = _default_camera_position.length()
	pan_bounds_x = float(GameManager.map_width) * 0.9
	pan_bounds_z = float(GameManager.map_height) * 0.9

func _process(delta: float) -> void:
	_handle_pan(delta)
	_handle_rotate(delta)

func _handle_pan(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	if input_dir == Vector3.ZERO:
		return

	input_dir = input_dir.normalized()
	var forward = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var move = (right * input_dir.x + forward * -input_dir.z) * pan_speed * delta
	position += move
	position.x = clamp(position.x, -pan_bounds_x, pan_bounds_x)
	position.z = clamp(position.z, -pan_bounds_z, pan_bounds_z)

func _handle_rotate(delta: float) -> void:
	var rotate_dir := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		rotate_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		rotate_dir += 1.0
	if rotate_dir != 0.0:
		rotate_y(deg_to_rad(rotate_speed * rotate_dir * delta))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var result = _raycast_ground(event.position)
			if result:
				SelectionManager.handle_world_click(result.position)
	elif event is InputEventMouseMotion:
		# So faz sentido raycastar isso com uma unidade selecionada (previa
		# de trajeto) — evita raycast a cada pixel de movimento do mouse
		# so pra olhar em volta da camera, que e o caso comum.
		if SelectionManager.selected_unit != null:
			var result = _raycast_ground(event.position)
			if result:
				SelectionManager.handle_world_hover(result.position)

func _zoom(amount: float) -> void:
	_zoom_distance = clamp(_zoom_distance + amount, min_zoom, max_zoom)
	var dir = camera.position.normalized()
	camera.position = dir * _zoom_distance

func _raycast_ground(screen_pos: Vector2) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)
