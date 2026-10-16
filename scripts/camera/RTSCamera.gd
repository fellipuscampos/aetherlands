class_name RTSCamera
extends Node3D

## Ângulo FIXO (2026-10-09): o rig nunca gira — a câmera fica sempre na orientação inicial da cena (rig sem
## rotação, Camera3D inclinada em Main.tscn). Só pan (WASD/setas, minimapa) e zoom (roda do mouse, que aproxima
## ao longo da MESMA direção da câmera e por isso não muda o ângulo). O giro por Q/E foi removido.

@export var pan_speed: float = 20.0
@export var zoom_speed: float = 2.0
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

## Distância da câmera mudou (roda do mouse ou reset_view). O Main ajusta o alcance das sombras ao chão visível
## (GraphicsQuality.fit_shadows_to_view) — evento discreto, nada por quadro.
signal zoom_changed

var _zoom_distance: float = 15.0
var _default_camera_position: Vector3
var _default_camera_rotation: Vector3

func _ready() -> void:
	rotation = Vector3.ZERO # orientação fixa: nada gira o rig
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
## em vez de manter onde o jogador da partida anterior deixou. `focus_
## position` (mundo, Y ignorado) centraliza o rig ali em vez de sempre
## Vector3.ZERO — pedido do usuario: "faça ao começar o game a camera
## começar centralizada na sua tropa inicial, atualmente a camera começa
## em um lugar e a tropa nao necessariamente naquele lugar, ai voce tem
## que tentar achar seu boneco". Vector3.ZERO como default preserva o
## comportamento antigo pra quem chamar sem argumento nenhum. Clamp pelos
## MESMOS pan_bounds do clique no minimapa (_on_minimap_clicked) — precisa
## calcular os bounds ANTES do clamp, ao contrario da ordem antiga (que so
## setava bounds no fim, sem problema enquanto o alvo era sempre o
## origem).
func reset_view(focus_position: Vector3 = Vector3.ZERO) -> void:
	pan_bounds_x = float(GameManager.map_width) * 0.9
	pan_bounds_z = float(GameManager.map_height) * 0.9
	position = Vector3(clamp(focus_position.x, -pan_bounds_x, pan_bounds_x), 0.0, clamp(focus_position.z, -pan_bounds_z, pan_bounds_z))
	rotation = Vector3.ZERO
	camera.position = _default_camera_position
	camera.rotation_degrees = _default_camera_rotation
	_zoom_distance = _default_camera_position.length()
	zoom_changed.emit()

func _process(delta: float) -> void:
	_handle_pan(delta)

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

	# Com o ângulo fixo, "frente" da tela é sempre -Z do mundo e "direita" é +X: pan direto nos eixos do mundo.
	position += input_dir.normalized() * pan_speed * delta
	position.x = clamp(position.x, -pan_bounds_x, pan_bounds_x)
	position.z = clamp(position.z, -pan_bounds_z, pan_bounds_z)

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
	zoom_changed.emit()

func _raycast_ground(screen_pos: Vector2) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)
