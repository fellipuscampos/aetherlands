extends SceneTree

## Offline title art: the actual game buildings, photographed at pixel resolution.
## Run with Godot --path . --script tools/art_pipeline/render_title_landscape.gd.
var stage: Node3D
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}

func _initialize() -> void:
	_render.call_deferred()

func _box(position: Vector3, dimensions: Vector3, color: Color, casts_shadow: bool = true) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	if not casts_shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		materials[color] = material
	node.material_override = materials[color]
	node.position = position
	stage.add_child(node)

func _model(path: String, position: Vector3, factor: float) -> void:
	var packed := load(path) as PackedScene
	assert(packed != null, "Title landscape model missing: " + path)
	var model := packed.instantiate() as Node3D
	stage.add_child(model)
	model.position = position
	model.scale = Vector3.ONE * factor

func _height(x: float, z: float) -> float:
	return snappedf(0.08 + 0.10 * sin(x * 0.6) + 0.08 * cos(z * 0.7), 0.08)

func _building_path(race: String, stem: String) -> String:
	return "res://assets/generated/%s/buildings/%s/%s.glb" % [race, stem, stem]

func _river(z: float) -> float:
	return 0.0 + sin(z * 0.32) * 2.4

func _pine(x: float, z: float, factor: float) -> void:
	var ground := _height(x, z)
	_box(Vector3(x, ground + factor * 0.5, z), Vector3(.18, factor, .18), Color("413f32"))
	for i in 3:
		var width := factor * (1.02 - i * .22)
		_box(Vector3(x, ground + factor * (.72 + i * .3), z), Vector3(width, factor * .48, width), Color("254b43").lightened(i * .04))

func _render() -> void:
	rng.seed = 703114
	root.size = Vector2i(960, 540)
	root.msaa_3d = Viewport.MSAA_DISABLED
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("253e52")
	sky_material.sky_horizon_color = Color("d6b18a")
	sky_material.ground_horizon_color = Color("c2a283")
	sky_material.ground_bottom_color = Color("22363b")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a6bcc8")
	env.ambient_light_energy = .4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("899698")
	env.fog_density = .004
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -42, 0)
	light.light_color = Color("ffd1a0")
	light.light_energy = 1.5
	light.shadow_enabled = true
	light.shadow_normal_bias = .5
	light.directional_shadow_max_distance = 45.0
	stage.add_child(light)
	# The valley is made of square blocks, with a winding river and stone banks.
	for ix in range(-40, 41):
		for iz in range(-32, 33):
			var x := ix * .5
			var z := iz * .5
			var river_distance := absf(x - _river(z))
			if river_distance < 1.25:
				_box(Vector3(x, -.22, z), Vector3(.5, .12, .5), Color("315e6b").lightened(rng.randf_range(-.018, .018)), false)
				continue
			var h := _height(x, z)
			var color := Color("45614a") if river_distance > 1.65 else Color("78735d")
			_box(Vector3(x, h - .52, z), Vector3(.5, 1.04, .5), color.lightened(rng.randf_range(-.012, .012)), false)
	# Distant terraced peaks: a quiet backdrop behind the miniature kingdoms.
	for peak in [Vector3(-12, 5, -13), Vector3(-5, 7, -16), Vector3(4, 6, -15), Vector3(12, 8, -15)]:
		for tier in 8:
			var width := 8.0 - tier * .85
			_box(Vector3(peak.x + tier * .12, tier * .65 + .1, peak.z), Vector3(width, .7, width * .65), Color("52656a").lightened(tier * .018))
		_box(Vector3(peak.x + .84, 5.4, peak.z), Vector3(1.5, .2, 1.1), Color("b4beb5"))
	# Hero human fortress, using precisely the same walls and pixel atlas as in game.
	var castle_position := Vector3(5.0, .34, -.4)
	_box(castle_position + Vector3(0, -.34, 0), Vector3(5.8, .64, 5.6), Color("66785a"))
	_model(_building_path("humans", "city_level_4_hex_v1"), castle_position, 2.8)
	_model(_building_path("humans", "human_walls_level_3_hex_v1"), castle_position, 2.8)
	_model(_building_path("elves", "elf_city_level_1_hex_v1"), Vector3(-3, .4, -6), 2.0)
	_model(_building_path("dwarves", "dwarf_city_level_1_hex_v1"), Vector3(10, .35, -7), 2.0)
	_model(_building_path("orcs", "orc_city_level_1_hex_v1"), Vector3(-9, .25, -3), 2.0)
	# Road and block-built bridge lead the eye towards the fortress gate.
	for z in range(3, 11):
		_box(Vector3(5, _height(5, z) + .035, z), Vector3(.9, .10, 1), Color("aba28b"))
	for x in range(-1, 6):
		_box(Vector3(x, .20, 8), Vector3(1, .16, .95), Color("a49c88"))
	for x in [0, 2, 4]:
		_box(Vector3(x, -.1, 8), Vector3(.22, .65, .72), Color("746f61"))
	# Forests stay away from roads, castles and river; foreground silhouettes frame the art.
	for i in 145:
		var x := rng.randf_range(-17, 18)
		var z := rng.randf_range(-10, 13)
		if absf(x - _river(z)) < 2.0 or (x > 1.6 and x < 8.2 and z > -4 and z < 11):
			continue
		if Vector2(x + 3, z + 6).length() < 2.2 or Vector2(x - 10, z + 7).length() < 2.2:
			continue
		_pine(x, z, rng.randf_range(.55, 1.4))
	for point in [Vector2(9, 10), Vector2(11, 9), Vector2(13, 11), Vector2(-7, 11)]:
		_pine(point.x, point.y, 2.5)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.8
	camera.position = Vector3(0, 6.4, 19)
	camera.look_at(Vector3(0, 1.7, -1))
	camera.current = true
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://assets/ui/title_menu/kingdom_landscape.png"
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("TITLE_LANDSCAPE_SAVED: ", output)
	quit()
