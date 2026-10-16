extends SceneTree

const MANIFEST := "res://assets/generated/embark_boats_manifest.json"
var problems: Array[String] = []
var verified: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		problems.append(message)

func inspect_meshes(node: Node, race: String, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		state["meshes"] += 1
		check(instance.mesh != null, race + " missing mesh")
		for i in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(i) as StandardMaterial3D
			check(material != null, race + " invalid material")
			if material:
				check(material.albedo_texture != null, race + " missing embedded texture")
				check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, race + " texture filter changed")
				check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, race + " unexpected transparency")
				check(material.cull_mode == BaseMaterial3D.CULL_BACK, race + " face culling changed")
			var aabb := instance.get_aabb()
			state["min_y"] = minf(state["min_y"], aabb.position.y)
			state["max_y"] = maxf(state["max_y"], aabb.end.y)
	for child in node.get_children():
		inspect_meshes(child, race, state)

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for entry: Dictionary in manifest["assets"]:
		var path := "res://" + str(entry["godot_scene"])
		var scene := load(path) as PackedScene
		check(scene != null, str(entry["race"]) + " failed to import")
		if not scene:
			continue
		var instance := scene.instantiate() as Node3D
		root.add_child(instance)
		var state := {"meshes": 0, "min_y": 0.0, "max_y": 0.0}
		inspect_meshes(instance, entry["race"], state)
		check(state["meshes"] == int(entry["game_meshes"]), str(entry["race"]) + " incorrect mesh count")
		check(state["min_y"] < 0.0 and state["max_y"] > 1.0, str(entry["race"]) + " waterline pivot incorrect")
		check(instance.transform.is_equal_approx(Transform3D.IDENTITY), str(entry["race"]) + " root was offset")
		var visual := instance.get_node("Visual") as Node3D
		check(visual.scale.is_equal_approx(Vector3.ONE * 0.52), str(entry["race"]) + " map scale incorrect")
		check(not instance.find_child("*Camera*", true, false), str(entry["race"]) + " exported a studio camera")
		var clips: Array[Dictionary] = []
		if entry.get("sail_revision", 1) == 2:
			var player := instance.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
			var motion := instance.find_child("BoatMotion", true, false) as Node3D
			check(player != null and motion != null, str(entry["race"]) + " missing animation nodes")
			if player and motion:
				check(player.autoplay == "idle", str(entry["race"]) + " idle autoplay missing")
				for clip: String in ["idle", "walk"]:
					check(player.has_animation(clip), str(entry["race"]) + " missing " + clip)
					if not player.has_animation(clip):
						continue
					var animation := player.get_animation(clip)
					var duration := 4.0 if clip == "idle" else 2.0
					check(absf(animation.length - duration) < 0.001, str(entry["race"]) + " clip duration changed")
					check(animation.loop_mode == Animation.LOOP_LINEAR, str(entry["race"]) + " clip is not a loop")
					player.play(clip)
					var min_y := 0.0
					var first := Transform3D.IDENTITY
					for sample in range(121):
						player.seek(duration * float(sample) / 120.0, true)
						player.advance(0.0)
						if sample == 0:
							first = motion.transform
						check(absf(motion.position.x) + absf(motion.position.z) < 0.00001, str(entry["race"]) + " animation translates horizontally")
						check(motion.position.y <= 0.00001, str(entry["race"]) + " animation rises out of flat water")
						min_y = minf(min_y, motion.position.y)
					check(min_y < -0.009, str(entry["race"]) + " heave was not imported")
					check(motion.transform.is_equal_approx(first), str(entry["race"]) + " loop does not close")
					clips.append({"clip": clip, "duration": animation.length, "loop": true, "heave_native": min_y, "in_place": true, "flat_water": true})
				player.stop()
		verified.append({"race": entry["race"], "meshes": state["meshes"], "map_scale": 0.52, "nearest": true, "waterline": true, "clips": clips})
		instance.free()
	var report := {"status": "PASS" if problems.is_empty() else "FAIL", "assets": verified, "problems": problems}
	var output := FileAccess.open("res://godot_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t")); output.close()
	print(JSON.stringify(report))
	quit(0 if problems.is_empty() else 1)
