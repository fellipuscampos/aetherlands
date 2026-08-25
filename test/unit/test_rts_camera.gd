extends GutTest

## Cobre RTSCamera.reset_view() — pedido do usuario: "faça ao começar o
## game a camera começar centralizada na sua tropa inicial, atualmente a
## camera começa em um lugar e a tropa nao necessariamente naquele lugar,
## ai voce tem que tentar achar seu boneco". Antes reset_view() sempre
## voltava pra Vector3.ZERO (a origem do mundo), sem relacao nenhuma com
## onde a partida de verdade colocou o settler/guarda do jogador humano
## (ver Main._human_camera_focus, que agora passa essa posicao aqui).

var rig: RTSCamera
var _original_map_width: int
var _original_map_height: int

func before_each():
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	rig = RTSCamera.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 15, 12)
	rig.add_child(cam)
	add_child_autofree(rig)

func after_each():
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height

func test_reset_view_without_argument_defaults_to_world_origin():
	rig.reset_view()
	assert_eq(rig.position, Vector3.ZERO)

func test_reset_view_centers_the_rig_on_the_given_focus_position():
	rig.reset_view(Vector3(5.0, 0.0, -3.0))
	assert_eq(rig.position, Vector3(5.0, 0.0, -3.0))

func test_reset_view_ignores_the_y_component_of_the_focus_position():
	rig.reset_view(Vector3(1.0, 42.0, 2.0))
	assert_eq(rig.position.y, 0.0)

func test_reset_view_clamps_the_focus_position_to_the_pan_bounds():
	GameManager.map_width = 10
	GameManager.map_height = 10

	rig.reset_view(Vector3(9999.0, 0.0, -9999.0))

	assert_eq(rig.position.x, rig.pan_bounds_x)
	assert_eq(rig.position.z, -rig.pan_bounds_z)

func test_reset_view_resets_zoom_and_rotation_regardless_of_focus():
	rig.rotation = Vector3(0.3, 0.5, 0.1)
	rig._zoom_distance = rig.max_zoom

	rig.reset_view(Vector3(5.0, 0.0, 5.0))

	assert_eq(rig.rotation, Vector3.ZERO)
	assert_eq(rig.camera.position, rig._default_camera_position)
