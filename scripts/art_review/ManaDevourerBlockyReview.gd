extends Node3D

const MODEL := preload("res://assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb")
var player: AnimationPlayer
var model: Node3D
var camera: Camera3D

func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	player.animation_finished.connect(func(_clip): player.play("ManaDevourer_Idle"))
	player.play("ManaDevourer_Idle")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("18202b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3c4e6")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_node.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("252d38")
	ground.roughness = 1
	floor_node.material_override = ground
	floor_node.position.y = -0.01
	add_child(floor_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	add_child(camera)
	camera.position = Vector3(2.7, 3.5, 5)
	camera.look_at(Vector3(0, 1.03, 0))
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "DEVORADOR DE MANA\n1 — Espera   2 — Movimento   3 — Ataque\nSetas — Girar   Espaço — Pausar"
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode in [KEY_1, KEY_2, KEY_3]:
		player.play(["ManaDevourer_Idle", "ManaDevourer_Walk", "ManaDevourer_Attack"][key_event.keycode - KEY_1])
	elif key_event.keycode == KEY_SPACE:
		if player.is_playing(): player.pause()
		else: player.play()
	elif key_event.keycode == KEY_LEFT:
		model.rotate_y(PI / 8)
	elif key_event.keycode == KEY_RIGHT:
		model.rotate_y(-PI / 8)
