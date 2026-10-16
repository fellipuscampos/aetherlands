extends Control

## Static pixel corners and a focus ring. Draws only on resize, hover or focus.
var accent := Color.WHITE
var factor := 1.0
var padding := 6.0
var emphasized := false
var focused := false
var hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var card := get_parent() as Control
	card.focus_entered.connect(func(): focused = true; queue_redraw())
	card.focus_exited.connect(func(): focused = false; queue_redraw())
	card.mouse_entered.connect(func(): hovered = true; queue_redraw())
	card.mouse_exited.connect(func(): hovered = false; queue_redraw())

func _draw() -> void:
	var pixel := maxf(2, roundf(2 * factor))
	var ink := Color("fff2d8") if focused else accent
	var distance := 3 * factor
	# PanelContainer places children inside its padding. Decorate the outer frame.
	var bounds := Rect2(-Vector2.ONE * padding * factor, size + Vector2.ONE * padding * 2 * factor)
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.position.x, bounds.end.y), bounds.end]:
		var direction := Vector2(1 if corner.x == bounds.position.x else -1, 1 if corner.y == bounds.position.y else -1)
		var start: Vector2 = corner + direction * distance
		draw_rect(Rect2(start + Vector2(-pixel if direction.x < 0 else 0, 0), Vector2(pixel, direction.y * 4 * factor)).abs(), ink)
		draw_rect(Rect2(start + Vector2(0, -pixel if direction.y < 0 else 0), Vector2(direction.x * 4 * factor, pixel)).abs(), ink)
	if focused or hovered:
		draw_rect(bounds.grow(-pixel * 2), ink if focused else Color(ink, .5), false, pixel)
	if emphasized:
		draw_rect(Rect2(Vector2(bounds.position.x + 10 * factor, bounds.end.y - 3 * factor), Vector2(bounds.size.x - 20 * factor, pixel)), accent)
