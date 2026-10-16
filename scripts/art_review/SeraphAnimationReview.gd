extends Node3D

const MODEL := preload("res://assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.glb")
const CLIPS := ["Idle", "Walk", "Attack", "Spell"]
var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var canvas: CanvasLayer
var label: Label
var selected := 0

func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("18202b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ccd6e8")
	env.ambient_light_energy = 0.35
	var environment := WorldEnvironment.new()
	environment.environment = env
	add_child(environment)
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
	camera.size = 6.8
	add_child(camera)
	camera.position = Vector3(3, 4.2, 10)
	camera.look_at(Vector3(0, 1.8, 0))
	camera.current = true
	canvas = CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(label)
	player.animation_finished.connect(_animation_finished)
	select_clip(0)

func select_clip(index: int) -> void:
	selected = index
	player.play(CLIPS[index], 0.15)
	label.text = "SERAFIM · " + CLIPS[index] + "\n1 Idle · 2 Walk · 3 Attack · 4 Spell\nSetas: girar · Espaço: pausar · R: repetir"

func _animation_finished(_clip: StringName) -> void:
	if selected in [2, 3]:
		player.play("Idle", 0.20)
		label.text += "\nConcluído — repouso. R repete a ação selecionada."

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.is_echo(): return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		select_clip(key.keycode-KEY_1)
	elif key.keycode == KEY_R: select_clip(selected)
	elif key.keycode == KEY_LEFT: model.rotate_y(PI/8)
	elif key.keycode == KEY_RIGHT: model.rotate_y(-PI/8)
	elif key.keycode == KEY_SPACE:
		if player.is_playing(): player.pause()
		else: player.play()
