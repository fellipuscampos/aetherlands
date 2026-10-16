extends Node

## Compare only the old/new material setup with identical generation,
## geometry, seed, map dimensions and vegetation. Never modify the grid
## script or project assets to establish the baseline.
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var source := FileAccess.get_file_as_string("res://art_source/terrain_before_pixel_v1/scripts/world/HexGrid.gd")
	var first := source.find("func _build_terrain_multimesh(")
	var last := source.find("func _set_optional_texture(", first)
	var baseline := GDScript.new()
	baseline.source_code = "extends HexGrid\n\n" + source.substr(first, last-first)
	if baseline.reload() != OK: get_tree().quit(1); return
	var samples: Array = []
	var special := "--special-world" in OS.get_cmdline_user_args()
	var profile: Dictionary = WorldProfile.SPECIAL_CONTINENTS if special else WorldProfile.default_size()
	var seed_value := 999 if special else 12345
	for mode in ["photographic", "pixel", "photographic", "pixel"]:
		var started := Time.get_ticks_msec()
		var grid: HexGrid = baseline.new() if mode == "photographic" else HexGrid.new()
		grid._ready()
		grid.generate_map(profile.width, profile.height, seed_value)
		var elapsed := Time.get_ticks_msec()-started
		samples.append({"material":mode,"generation_ms":elapsed,"tiles":grid.tiles.size()})
		print(JSON.stringify(samples.back()))
		grid.free()
		await get_tree().process_frame
	var report := {"status":"MEASURED","renderer":RenderingServer.get_current_rendering_method(),"seed":seed_value,"samples":samples,"comparison":"Same generator; only _build_terrain_multimesh uses the preserved pre-pixel implementation in the photographic baseline","limitations":"CPU measurements under background load; not an FPS benchmark"}
	var suffix := "_special" if special else ""
	var file := FileAccess.open("res://docs/terrain_pixel_generation_comparison"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	get_tree().quit(0)
