extends SceneTree

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var script=load("res://tools/art_pipeline/review_school_mage_animations.gd")
	if script==null or not script.can_instantiate():
		quit(1)
		return
	root.add_child(script.new())
