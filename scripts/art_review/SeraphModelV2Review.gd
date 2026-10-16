extends Node3D

const MODEL := preload("res://assets/generated/grand_manifestations/seraph_blocky_v2/seraph_blocky_v2.glb")
var model: Node3D
var camera: Camera3D
var canvas: CanvasLayer

func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("18202b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ccd6e8")
	env.ambient_light_energy = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_energy = 0.70
	light.shadow_enabled = true
	add_child(light)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_node.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("252d38")
	ground.roughness = 1
	floor_node.material_override = ground
	floor_node.position.y = -0.01
	add_child(floor_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	add_child(camera)
	camera.position = Vector3(3, 4.2, 10)
	camera.look_at(Vector3(0, 1.72, 0))
	camera.current = true
	canvas = CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "SERAFIM — GRANDE MANIFESTAÇÃO SAGRADA\nModelo · 3 metros · Comum às civilizações\nSetas — Girar"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode == KEY_LEFT:
		model.rotate_y(PI / 8)
	elif key_event.keycode == KEY_RIGHT:
		model.rotate_y(-PI / 8)
