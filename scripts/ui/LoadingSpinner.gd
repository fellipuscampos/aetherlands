class_name LoadingSpinner
extends Control

## Eight square gems advance around the menu crest on an integer pixel grid.
## This indicates activity; generation callbacks remain the source of progress.
const CREST := preload("res://assets/ui/title_menu/crest.svg")
const GEMS := [Vector2(16, 2), Vector2(25, 7), Vector2(30, 16), Vector2(25, 25),
	Vector2(16, 30), Vector2(7, 25), Vector2(2, 16), Vector2(7, 7)]

var _elapsed := 0.0
var _active_gem := 0

func _ready() -> void:
	Settings.accessibility_changed.connect(_apply_motion_preference)
	_apply_motion_preference()

func _apply_motion_preference() -> void:
	set_process(not Settings.reduced_motion)
	if Settings.reduced_motion:
		_elapsed = 0.0
		_active_gem = 0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	var next_gem := floori(_elapsed * 4.0) % GEMS.size()
	if next_gem != _active_gem:
		_active_gem = next_gem
		queue_redraw()

func _draw() -> void:
	var pixel := maxf(1, floorf(minf(size.x, size.y) / 32.0))
	var origin := ((size - Vector2.ONE * 32 * pixel) * .5).floor()
	draw_texture_rect(CREST, Rect2(origin + Vector2.ONE * 8 * pixel, Vector2.ONE * 16 * pixel), false)
	for i in GEMS.size():
		var age := posmod(_active_gem - i, GEMS.size())
		var color := Color("ffdca0") if age == 0 else (Color("ae8c55") if age <= 2 else Color("486057"))
		draw_rect(Rect2(origin + (GEMS[i] - Vector2.ONE) * pixel, Vector2.ONE * 2 * pixel), color)
