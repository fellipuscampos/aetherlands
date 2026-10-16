extends SceneTree

## Load the review after autoload singletons have initialized.
## Early SceneTree parsing cannot resolve the grid's singleton dependencies.
func _initialize() -> void:
	call_deferred("_start_review")

func _start_review() -> void:
	var path := "res://tools/art_pipeline/review_terrain_pixels.gd"
	if "--compare-generation" in OS.get_cmdline_user_args():
		path = "res://tools/art_pipeline/compare_terrain_pixel_generation.gd"
	var script = load(path)
	if script == null or not script.can_instantiate():
		quit(1)
		return
	root.add_child(script.new())
