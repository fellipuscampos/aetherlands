extends Node3D

@export var art_race: String = "human"
var output_path: String
var camera: Camera3D
var cities: Array[City] = []
var player: PlayerData

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.size = Vector2i(1440, 900)
	output_path = "res://docs/previews/%s_walls/" % art_race
	DirAccess.make_dir_recursive_absolute(output_path)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.13,.18,.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.88,.93,1.0)
	environment.ambient_light_energy = .7
	environment.ssao_enabled = true
	environment.ssao_radius = .35
	environment.ssao_intensity = 1.3
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52,-28,0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 16.0
	light.shadow_normal_bias = .025
	add_child(light)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(100,100)
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.21,.27,.30)
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	floor_node.position.y = -.013
	add_child(floor_node)
	var civ := CivilizationData.new()
	civ.race = art_race
	civ.color = Color(.18,.53,.39) if art_race == "elf" else Color(.20,.36,.68)
	if art_race == "orc": civ.color=Color(.65,.23,.14)
	if art_race == "dwarf": civ.color=Color(.27,.41,.62)
	player = PlayerData.new(civ)
	var report := {"status":"PASS", "race":art_race, "levels":[], "native_city_integration":true}
	for level in [1,2,3]:
		var city := City.new()
		add_child(city)
		city.setup(player, Vector2i(level,0), "Muralhas", 1.0)
		city.position.x = (level-2)*2.35
		city.apply_city_level(level+1)
		city.apply_fortification_level(level)
		city._build_visual_procedural()
		for node in city.get_children():
			if node is Label3D or node is Sprite3D: node.visible=false
		cities.append(city)
		var wall := city._buildings_root.get_node("FortificationModel") as Node3D
		assert(wall.scene_file_path == BuildingArtCatalog.fortification_model_path(level,art_race))
		assert(wall.scale.is_equal_approx(Vector3.ONE))
		var highest := 0.0
		var maximum := 0.0
		var minimum := INF
		var triangles := 0
		for part: MeshInstance3D in wall.find_children("*","MeshInstance3D",true,false):
			var relative := wall.global_transform.affine_inverse()*part.global_transform
			for surface in part.mesh.get_surface_count():
				var arrays := part.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size()/3
				for vertex in vertices:
					var point := relative*vertex
					highest=maxf(highest,point.y)
					var city_plane := -INF
					for edge in range(6):
						var angle := deg_to_rad(float(edge)*60)
						var projection := point.x*cos(angle)+point.z*sin(angle)
						maximum=maxf(maximum,projection)
						city_plane=maxf(city_plane,projection)
					minimum=minf(minimum,city_plane-.84*sqrt(3.0)/2.0)
				var material := part.mesh.surface_get_material(surface) as StandardMaterial3D
				assert(material!=null and material.albedo_texture!=null)
				assert(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS])
		assert(maximum < sqrt(3.0)/2.0 and highest < .40 and minimum > .006)
		report.levels.append({"level":level,"height":highest,"triangles":triangles,"maximum_half_plane":maximum,"minimum_city_clearance":minimum,"tile_radius":city.tile_radius,"model":wall.scene_file_path})
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	await get_tree().process_frame
	var caption := CanvasLayer.new()
	add_child(caption)
	for index in range(3):
		var label := Label.new()
		label.text = ["I · MURALHAS I", "II · MURALHAS II", "III · FORTALEZA"][index]
		label.position = Vector2(35+index*470,790)
		label.size = Vector2(430,50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",24)
		caption.add_child(label)
	# Real City instances, with and without their separate city-center mesh.
	camera.size=4.95
	camera.position=Vector3(0,5.3,8.4)
	camera.look_at(Vector3(0,.50,0))
	await _capture("cities_three_quarter")
	for city in cities: city._buildings_root.get_node("CityCenterModel").visible=false
	camera.size=4.6
	camera.position=Vector3(0,5.2,7.0)
	camera.look_at(Vector3(0,.10,0))
	await _capture("walls_three_quarter")
	camera.size=4.6
	camera.position=Vector3(0,7,.001)
	camera.look_at(Vector3.ZERO)
	await _capture("walls_top")
	caption.visible=false
	for index in range(3):
		for other in range(3): cities[other].visible=other==index
		var city := cities[index]
		var center := city.position
		camera.size=2.5
		camera.position=center+Vector3(2.1,2.5,3.8)
		camera.look_at(center+Vector3(0,.10,0))
		get_tree().root.size=Vector2i(1000,1000)
		var stem := "%s_walls_level_%d_hex_v1" % [art_race,index+1]
		var preview := "res://assets/generated/%s/buildings/%s/previews/" % [BuildingArtCatalog.RACE_FOLDERS[art_race],stem]
		DirAccess.make_dir_recursive_absolute(preview)
		await _capture("three_quarter",preview)
		camera.position=center+Vector3(0,5,.001)
		camera.look_at(center)
		camera.size=2.20
		await _capture("top",preview)
		city._buildings_root.get_node("CityCenterModel").visible=true
		camera.size=3.15
		camera.position=center+Vector3(2.2,2.8,4.1)
		camera.look_at(center+Vector3(0,.55,0))
		await _capture("with_city",preview)
	FileAccess.open("res://docs/%s_walls_godot_validation.json" % art_race,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(art_race.to_upper()+"_WALLS_REVIEW "+JSON.stringify(report))
	player.release_relations()
	get_tree().quit()

func _capture(name: String, directory: String="") -> void:
	if directory.is_empty(): directory=output_path
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(directory+name+".png")==OK)
