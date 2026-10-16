extends GutTest

var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(color: Color) -> PlayerData:
	var civilization := CivilizationData.new()
	civilization.color = color
	var player := PlayerData.new(civilization)
	_players.append(player)
	return player

func _city(player: PlayerData, radius: float = 1.0) -> City:
	var city := City.new()
	add_child_autofree(city)
	city.setup(player,Vector2i.ZERO,"Capital",radius)
	return city

## Jogador de teste sem raça -> arte humana (BuildingArtCatalog.normalize_race).
func _human_center(level: int) -> String:
	return "res://assets/generated/humans/buildings/city_level_%d_hex_v1/city_level_%d_hex_v1.glb" % [level, level]

func _faction(city: City) -> MeshInstance3D:
	return city._buildings_root.find_children("*_Faction","MeshInstance3D",true,false)[0]

func test_center_scales_with_the_actual_tile_and_keeps_fortification_separate() -> void:
	var city := _city(_player(Color.CORNFLOWER_BLUE),2.0)
	var model := city._buildings_root.get_node("CityCenterModel") as Node3D
	assert_eq(model.scale,Vector3(2,2,2))
	assert_eq(model.find_children("*","MeshInstance3D",true,false).size(),8)
	for level in [2,3,4]:
		city.apply_city_level(level)
		await get_tree().process_frame
		model = city._buildings_root.get_node("CityCenterModel") as Node3D
		assert_eq(model.scale,Vector3(2,2,2))
		assert_eq(model.scene_file_path,_human_center(level))
		assert_eq(model.find_children("*","MeshInstance3D",true,false).size(),8)
		assert_eq(city._buildings_root.get_child_count(),1,"The city center has no surrounding fortification")
	assert_gt(city._name_label.position.y,4.8,"The name clears the final castle at tile radius 2")
	city.apply_fortification_level(1)
	city._build_visual_procedural()
	await get_tree().process_frame
	assert_not_null(city._buildings_root.get_node_or_null("CityCenterModel"))
	var walls := city._buildings_root.get_node_or_null("FortificationModel") as Node3D
	assert_not_null(walls,"Fortification uses its separate human model")
	assert_eq(walls.scale,Vector3(2,2,2),"The ring follows the same tile radius as the center")
	assert_eq(city._buildings_root.get_child_count(),2,"Center and fortification remain separate")

func test_capture_recolors_only_that_city_without_mutating_shared_materials() -> void:
	var blue := _player(Color(.12,.32,.78))
	var red := _player(Color(.78,.13,.12))
	var first := _city(blue)
	var second := _city(blue)
	first.apply_city_level(4)
	second.apply_city_level(4)
	await get_tree().process_frame
	var source_material := _faction(first).mesh.surface_get_material(0) as StandardMaterial3D
	var original_color := source_material.albedo_color
	var original_texture := source_material.albedo_texture
	first.change_owner(red)
	await get_tree().process_frame
	assert_eq((_faction(first).material_override as StandardMaterial3D).albedo_color,red.civ.color.lightened(.1))
	assert_eq((_faction(second).material_override as StandardMaterial3D).albedo_color,blue.civ.color.lightened(.1))
	assert_eq(source_material.albedo_color,original_color,"Imported resource stays shared and unchanged")
	assert_same((_faction(first).material_override as StandardMaterial3D).albedo_texture,original_texture)
	for part: MeshInstance3D in first._buildings_root.find_children("*","MeshInstance3D",true,false):
		if not part.name.ends_with("_Faction"):
			assert_null(part.material_override,"Architecture preserves its painted atlas")

func test_upgrading_selects_the_available_model_and_preserves_city_state_and_labels() -> void:
	var city := _city(_player(Color.CORNFLOWER_BLUE))
	city.hp = city.max_hp()*.5
	city.apply_fortification_level(1)
	city._build_visual_procedural()
	city.production_item = "settler"
	city.stored_production = 7.0
	var label := city._name_label
	var life_bar := city._life_bar
	for level in [2,3,4]:
		city.apply_city_level(level)
		await get_tree().process_frame
		var model := city._buildings_root.get_node_or_null("CityCenterModel") as Node3D
		assert_not_null(model,"Every city level uses its own castle")
		assert_eq(model.scene_file_path,_human_center(level))
		assert_almost_eq(city.hp/city.max_hp(),.5,.0001)
		assert_eq(city.fortification_level,1)
		assert_eq(city.production_item,"settler")
		assert_eq(city.stored_production,7.0)
		assert_same(city._name_label,label)
		assert_same(city._life_bar,life_bar)
		assert_eq(label.text,"Capital (%s)"%V2CityLevelData.roman(level))
		assert_eq(city._buildings_root.get_child_count(),2)
		assert_not_null(city._buildings_root.get_node_or_null("FortificationModel"))
		if level == 3:
			assert_gt(label.position.y,1.95,"The name stays above the central donjon")
			assert_almost_eq(life_bar.position.y-label.position.y,City.LIFE_BAR_Y-City.LABEL_HEIGHT,.0001)
			assert_almost_eq(city._shield_bar.position.y-label.position.y,City.SHIELD_BAR_Y-City.LABEL_HEIGHT,.0001)
		elif level == 4:
			assert_gt(label.position.y,2.4,"The name clears the final central banner")
			assert_almost_eq(life_bar.position.y-label.position.y,City.LIFE_BAR_Y-City.LABEL_HEIGHT,.0001)
			assert_almost_eq(city._shield_bar.position.y-label.position.y,City.SHIELD_BAR_Y-City.LABEL_HEIGHT,.0001)
	city.apply_city_level(1)
	await get_tree().process_frame
	assert_eq(city._buildings_root.get_node("CityCenterModel").scene_file_path,_human_center(1))
	assert_lt(label.position.y,1.6,"Restoring the low castle lowers its UI again")
