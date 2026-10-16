extends "res://test/unit/test_human_wall_models.gd"

func _art_race() -> String:
	return "dwarf"

func _atlas_city_level() -> int:
	return 1

func test_all_four_races_replace_wall_art_on_capture_without_changing_level_or_shield():
	var dwarf := _player("dwarf")
	var human := _player("human")
	var elf := _player("elf")
	var orc := _player("orc")
	var city := _city(dwarf)
	for level in [1,2,3]:
		city.apply_fortification_level(level)
		city._build_visual_procedural()
		city.shield=4.0
		for owner in [human,elf,orc,dwarf]:
			city.change_owner(owner)
			await get_tree().process_frame
			assert_eq(_walls(city).scene_file_path,BuildingArtCatalog.fortification_model_path(level,owner.civ.race))
			assert_eq(city.fortification_level,level)
			assert_eq(city.shield,4.0)
			assert_eq(city._buildings_root.get_child_count(),2)
