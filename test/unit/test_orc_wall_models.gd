extends "res://test/unit/test_human_wall_models.gd"

func _art_race() -> String:
	return "orc"

func _atlas_city_level() -> int:
	return 1

func test_capture_selects_orc_human_and_elf_wall_art_at_every_existing_level():
	var orc := _player("orc")
	var human := _player("human")
	var elf := _player("elf")
	var city := _city(orc)
	for level in [1,2,3]:
		city.apply_fortification_level(level)
		city._build_visual_procedural()
		city.shield=3.0
		for owner in [human,elf,orc]:
			city.change_owner(owner)
			await get_tree().process_frame
			assert_eq(_walls(city).scene_file_path,BuildingArtCatalog.fortification_model_path(level,owner.civ.race))
			assert_eq(city.fortification_level,level)
			assert_eq(city.shield,3.0)
			assert_eq(city._buildings_root.get_child_count(),2)
