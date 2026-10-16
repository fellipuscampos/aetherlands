class_name ToastPresenter
extends VBoxContainer

const MAX_VISIBLE := 3
const DEFAULT_TIMEOUT := 4.2

var _queue: Array[UIEventData] = []
var _visible_by_key: Dictionary = {}
## Integrated shells already show these events in their actionable critical banner.
var use_critical_banner := false
const CHROME := preload("res://scripts/ui/HUDChromeTheme.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	theme = CHROME.build(CHROME.factor())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Settings.accessibility_changed.connect(_on_accessibility_changed)
	if UIEvents != null and not UIEvents.event_published.is_connected(_on_event_published):
		UIEvents.event_published.connect(_on_event_published)

func _on_event_published(event: UIEventData) -> void:
	if use_critical_banner and event.severity == UIEventData.Severity.CRITICAL and event.event_type in CriticalAlertPresenter.ALLOWED_TYPES:
		return
	enqueue(event)

func enqueue(event: UIEventData) -> void:
	var key := event.dedup_key
	if not key.is_empty() and _visible_by_key.has(key):
		var record: Dictionary = _visible_by_key[key]
		record.count = int(record.count) + 1
		(record.label as Label).text = event.title + "  ×%d" % record.count
		(record.message as Label).text = event.message
		(record.message as Label).visible = not event.message.is_empty()
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
	panel.name = "Notice"
	panel.custom_minimum_size = Vector2(0, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("severity", event.severity)
	panel.add_theme_stylebox_override("panel", CHROME.panel(CHROME.factor(), CHROME.tone(event.severity), 12))
	panel.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.name = "NoticeRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(12 * CHROME.factor()))
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.name = "SeverityIcon"
	icon.texture = CHROME.icon(CHROME.tone(event.severity))
	icon.custom_minimum_size = Vector2(20,20) * CHROME.factor()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	var label := Label.new()
	label.theme_type_variation = &"SubheadingLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = event.title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(label)
	var message := Label.new()
	message.text = event.message
	message.visible = not event.message.is_empty()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(message)
	add_child(panel)
	var enter := panel.create_tween()
	enter.tween_property(panel, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST))
	if not event.dedup_key.is_empty():
		_visible_by_key[event.dedup_key] = {"panel": panel, "label": label, "message": message, "count": 1}
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
	var exit_tween := panel.create_tween()
	exit_tween.tween_property(panel, "modulate:a", 0.0, Settings.motion_duration(UIThemeTokens.MOTION_TOAST))
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

func _on_accessibility_changed() -> void:
	theme = CHROME.build(CHROME.factor())
	for child in get_children():
		if child is PanelContainer:
			child.add_theme_stylebox_override("panel", CHROME.panel(CHROME.factor(), CHROME.tone(int(child.get_meta("severity",0))), 12))
			var row := child.get_node("NoticeRow") as HBoxContainer
			row.add_theme_constant_override("separation", roundi(12 * CHROME.factor()))
			(row.get_node("SeverityIcon") as TextureRect).custom_minimum_size = Vector2(20,20) * CHROME.factor()
