extends GutTest

var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players: player.release_relations()
	_players.clear()

func _art_race() -> String:
	return "human"

func _atlas_city_level() -> int:
	return 4

func _player(race: String="", color: Color=Color.CORNFLOWER_BLUE) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race=_art_race() if race.is_empty() else race
	civ.color=color
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _city(player: PlayerData, radius: float=1.0) -> City:
	var city := City.new()
	add_child_autofree(city)
	city.setup(player,Vector2i.ZERO,"Capital",radius)
	return city

func _walls(city: City) -> Node3D:
	return city._buildings_root.get_node_or_null("FortificationModel") as Node3D

func test_actual_upgrades_replace_the_ring_at_native_tile_scale_without_touching_production():
	var city := _city(_player(),2.0)
	assert_null(_walls(city),"No ring before fortification is built")
	city.production_item="settler"
	city.stored_production=7.0
	var previous_height := 0.0
	for level in [1,2,3]:
		city.apply_fortification_level(level)
		city._build_visual_procedural()
		await get_tree().process_frame
		var walls := _walls(city)
		assert_not_null(walls)
		assert_eq(walls.scale,Vector3(2,2,2))
		assert_eq(walls.scene_file_path,BuildingArtCatalog.fortification_model_path(level,_art_race()))
		assert_eq(city._buildings_root.get_child_count(),2,"Previous ring is replaced")
		assert_eq(city.production_item,"settler")
		assert_eq(city.stored_production,7.0)
		var highest := 0.0
		for part: MeshInstance3D in walls.find_children("*","MeshInstance3D",true,false):
			var relative := walls.global_transform.affine_inverse()*part.global_transform
			for surface in part.mesh.get_surface_count():
				var vertices: PackedVector3Array=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var point := relative*vertex
					highest=maxf(highest,point.y)
					var outside_city := -INF
					for edge in range(6):
						var angle := deg_to_rad(float(edge)*60.0)
						var projection := point.x*cos(angle)+point.z*sin(angle)
						assert_lte(projection,.985*sqrt(3.0)/2.0+.0001,"Within the tile's six actual edges")
						outside_city=maxf(outside_city,projection)
					assert_gt(outside_city,.84*sqrt(3.0)/2.0+.006,"No vertices enter the existing city footprint")
		assert_gt(highest,previous_height)
		assert_lt(highest,.40,"Remains a low decorative perimeter")
		previous_height=highest

func test_wall_texture_pixels_are_the_approved_city_atlas():
	var city := _city(_player())
	var center := city._buildings_root.get_node("CityCenterModel") as Node3D
	# The race's approved source city supplies the atlas for all three rings.
	city.apply_city_level(_atlas_city_level())
	center=city._buildings_root.get_node("CityCenterModel") as Node3D
	var reference := center.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var approved := (reference.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture.get_image().get_data()
	for level in [1,2,3]:
		city.apply_fortification_level(level)
		city._build_visual_procedural()
		var part := _walls(city).find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var material := part.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS])
		assert_true(material.albedo_texture.get_image().get_data()==approved,"Approved paint is reused, without recoloring stone or roof")

func test_capture_rebuilds_racial_art_and_tints_only_the_new_owners_gate():
	var blue := _player()
	var red := _player(_art_race(),Color.FIREBRICK)
	var new_owner := _player("dwarf" if _art_race() != "dwarf" else "elf")
	var first := _city(blue)
	var other := _city(blue)
	for city in [first,other]:
		city.apply_fortification_level(3)
		city._build_visual_procedural()
	first.change_owner(red)
	await get_tree().process_frame
	var red_gate := _walls(first).find_children("*_Faction","MeshInstance3D",true,false)[0] as MeshInstance3D
	var blue_gate := _walls(other).find_children("*_Faction","MeshInstance3D",true,false)[0] as MeshInstance3D
	assert_eq((red_gate.material_override as StandardMaterial3D).albedo_color,red.civ.color.lightened(.1))
	assert_eq((blue_gate.material_override as StandardMaterial3D).albedo_color,blue.civ.color.lightened(.1))
	assert_eq((red_gate.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color,Color.WHITE,"Shared painted material stays neutral")
	first.change_owner(new_owner)
	await get_tree().process_frame
	assert_not_null(_walls(first),"Every race now has its own fortification art")
	assert_eq(_walls(first).scene_file_path,BuildingArtCatalog.fortification_model_path(3,new_owner.civ.race))
	assert_eq(first._buildings_root.get_child_count(),2)
	assert_eq(first.fortification_level,3,"Only the visual changes on capture")
