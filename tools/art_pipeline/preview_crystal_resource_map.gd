extends Node

const ASSET_DIRS := {
	"gems": "res://assets/generated/resources/crystals/crystal_cluster_v1/",
	"mana_node": "res://assets/generated/resources/arcane_node/arcane_node_v1/",
	"iron": "res://assets/generated/resources/iron/iron_outcrop_v1/",
	"silk": "res://assets/generated/resources/silk/silk_mulberry_v1/",
	"horses": "res://assets/generated/resources/horses/horse_resource_v1/"
}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var resource_id: String = args[0] if not args.is_empty() else "gems"
	assert(ASSET_DIRS.has(resource_id))
	var out: String = ASSET_DIRS[resource_id]
	seed(122026)
	get_tree().root.size = Vector2i(1200, 800)
	var grid := HexGrid.new()
	add_child(grid)
	grid.generate_map(48, 36, 122026)
	var gems: Array[Vector2i] = []
	for coord in grid.tiles:
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
		if grid.tiles[coord].resource == resource_id:
			gems.append(coord)
	assert(not gems.is_empty(), "Expected resource in the generated map")
	grid._apply_prop_fog()
	grid._rebuild_biome_overlay()
	var props := grid._resource_props_manager
	if resource_id == "horses":
		assert(props._horse_instances.size() == gems.size())
		var meshes := (props._horse_instances[gems[0]] as Node).find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1)
		assert((meshes[0] as MeshInstance3D).get_active_material(0).albedo_texture != null)
	else:
		assert(props._instances.has(resource_id))
		assert(props._instances[resource_id].multimesh.instance_count == gems.size())
		# Recurso que brilha usa o shader de brilho (WorldGlow.prop_material), com o atlas no parâmetro albedo_texture.
		var material: Material = props._instances[resource_id].material_override
		assert((material.get_shader_parameter("albedo_texture") if material is ShaderMaterial else (material as StandardMaterial3D).albedo_texture) != null)
	var target := grid.world_for_coord(gems[0])
	target.y = grid._tile_surface_height(gems[0]) + 0.25
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.16, 0.21)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.90, 1.0)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	grid.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	grid.add_child(sun)
	var camera := Camera3D.new()
	grid.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	camera.position = target + Vector3(2, 6.5, 8)
	camera.look_at(target)
	camera.current = true
	for i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	assert(image.save_png(out + "previews/in_game_map.png") == OK)
	var report := {"status": "PASS", "real_hex_grid": true, "seed": 122026,
		"generated_map": [48, 36], "resource": resource_id, "resource_tiles": gems.size(),
		"target_coord": [gems[0].x, gems[0].y], "painted_atlas": true}
	var file := FileAccess.open(out + "map_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("RESOURCE_MAP_VALIDATION " + JSON.stringify(report))
	grid.queue_free()
	await get_tree().process_frame
	get_tree().quit()
