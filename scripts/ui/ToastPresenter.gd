class_name ToastPresenter
extends VBoxContainer

const MAX_VISIBLE := 3
const DEFAULT_TIMEOUT := 4.2

var _queue: Array[UIEventData] = []
var _visible_by_key: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	if UIEvents != null and not UIEvents.event_published.is_connected(_on_event_published):
		UIEvents.event_published.connect(_on_event_published)

func _on_event_published(event: UIEventData) -> void:
	enqueue(event)

func enqueue(event: UIEventData) -> void:
	var key := event.dedup_key
	if not key.is_empty() and _visible_by_key.has(key):
		var record: Dictionary = _visible_by_key[key]
		record.count = int(record.count) + 1
		(record.label as Label).text = _event_text(event) + "  ×%d" % record.count
		_visible_by_key[key] = record
		return
	_queue.append(event)
	_drain_queue()

func visible_toast_count() -> int:
	return get_child_count()

func queued_count() -> int:
	return _queue.size()

func dismiss_all() -> void:
	_queue.clear()
	_visible_by_key.clear()
	for child in get_children():
		child.queue_free()

func _drain_queue() -> void:
	while get_child_count() < MAX_VISIBLE and not _queue.is_empty():
		_show_event(_queue.pop_front())

func _show_event(event: UIEventData) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := _severity_color(event.severity)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED, accent, 2, UIThemeTokens.RADIUS_PANEL))
	panel.modulate.a = 0.0
	panel.position.y = -8.0
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _event_text(event)
	panel.add_child(label)
	add_child(panel)
	var enter := panel.create_tween().set_parallel(true)
	enter.tween_property(panel, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST))
	enter.tween_property(panel, "position:y", 0.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not event.dedup_key.is_empty():
		_visible_by_key[event.dedup_key] = {"panel": panel, "label": label, "count": 1}
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = DEFAULT_TIMEOUT + float(event.severity) * 1.0
	panel.add_child(timer)
	timer.timeout.connect(_dismiss.bind(panel, event.dedup_key))
	timer.start()

func _dismiss(panel: Control, key: String) -> void:
	if not key.is_empty():
		_visible_by_key.erase(key)
	if not is_instance_valid(panel):
		call_deferred("_drain_queue")
		return
	var exit_tween := panel.create_tween().set_parallel(true)
	exit_tween.tween_property(panel, "modulate:a", 0.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST))
	exit_tween.tween_property(panel, "position:y", -6.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST))
	exit_tween.chain().tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		call_deferred("_drain_queue")
	)

func _event_text(event: UIEventData) -> String:
	var prefix := "ℹ"
	if event.severity == UIEventData.Severity.IMPORTANT:
		prefix = "◆"
	elif event.severity == UIEventData.Severity.CRITICAL:
		prefix = "!"
	return "%s  %s%s" % [prefix, event.title, "\n%s" % event.message if not event.message.is_empty() else ""]

func _severity_color(severity: UIEventData.Severity) -> Color:
	if severity == UIEventData.Severity.CRITICAL:
		return UIThemeTokens.COLOR_CRITICAL
	if severity == UIEventData.Severity.IMPORTANT:
		return UIThemeTokens.COLOR_WARNING
	return UIThemeTokens.COLOR_INFO
