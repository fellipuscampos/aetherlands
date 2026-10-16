extends Node3D

const MODEL := preload("res://assets/generated/grand_manifestations/elemental_primordial_blocky_v6/elemental_primordial_blocky_v6.glb")
var model: Node3D
var camera: Camera3D
var canvas: CanvasLayer

func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("26303e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ccd6e8")
	env.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	add_child(light)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_node.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("303946")
	ground.roughness = 1
	floor_node.material_override = ground
	floor_node.position.y = -0.01
	add_child(floor_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	add_child(camera)
	camera.position = Vector3(2, 3.2, 10)
	camera.look_at(Vector3(0, 1.50, 0))
	camera.current = true
	canvas = CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "PRIMORDIAL DOS ELEMENTOS — GRANDE INVOCAÇÃO DO ELEMENTALISMO\nModelo · 3 metros · Núcleo ciano\nSetas: girar · R: restaurar vista"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.is_echo(): return
	if key.keycode == KEY_LEFT: model.rotate_y(PI / 8)
	elif key.keycode == KEY_RIGHT: model.rotate_y(-PI / 8)
	elif key.keycode == KEY_R: model.rotation.y = 0
