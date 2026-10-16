extends "res://test/unit/test_human_wall_models.gd"

## The same runtime scale, footprint, texture and ownership checks as humans.
func _art_race() -> String:
	return "elf"

func _atlas_city_level() -> int:
	return 1

func test_capture_between_humans_and_elves_replaces_architecture_at_the_existing_wall_level():
	var elf := _player("elf")
	var human := _player("human")
	var city := _city(elf)
	city.apply_fortification_level(3)
	city._build_visual_procedural()
	assert_eq(_walls(city).scene_file_path,BuildingArtCatalog.fortification_model_path(3,"elf"))
	city.shield=9.0
	city.change_owner(human)
	await get_tree().process_frame
	assert_eq(_walls(city).scene_file_path,BuildingArtCatalog.fortification_model_path(3,"human"))
	assert_eq(city.fortification_level,3)
	assert_eq(city.shield,9.0)
	city.change_owner(elf)
	await get_tree().process_frame
	assert_eq(_walls(city).scene_file_path,BuildingArtCatalog.fortification_model_path(3,"elf"))
	assert_eq(city._buildings_root.get_child_count(),2)
