class_name CriticalAlertPresenter
extends PanelContainer

signal action_requested(event: UIEventData)

const AUTO_DISMISS_SECONDS := 8.0
const ALLOWED_TYPES := ["war_declared", "city_lost", "ritual_critical", "ritual_critical_state", "city_threatened"]

var title_label: Label
var message_label: Label
var action_button: AEButton
var _queue: Array[UIEventData] = []
var _current: UIEventData
var _timer: Timer
var _known_keys: Dictionary = {}

func _ready() -> void:
	visible = false
	theme_type_variation = &"ElevatedPanel"
	_build()
	if UIEvents != null and not UIEvents.event_published.is_connected(_on_event):
		UIEvents.event_published.connect(_on_event)

func enqueue(event: UIEventData) -> void:
	if event == null or event.severity != UIEventData.Severity.CRITICAL or event.event_type not in ALLOWED_TYPES:
		return
	var key := event.dedup_key if not event.dedup_key.is_empty() else "%s:%s" % [event.event_type, event.title]
	if _known_keys.has(key):
		return
	_known_keys[key] = true
	_queue.append(event)
	_show_next()

func queued_count() -> int:
	return _queue.size()

func current_event() -> UIEventData:
	return _current

func dismiss() -> void:
	if _timer != null:
		_timer.stop()
	_current = null
	visible = false
	_show_next()

func _build() -> void:
	if title_label != null:
		return
	add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED, UIThemeTokens.COLOR_CRITICAL, 2, UIThemeTokens.RADIUS_PANEL, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	add_child(row)
	var marker := Label.new()
	marker.text = "!"
	marker.add_theme_font_size_override("font_size", UIThemeTokens.FONT_H2)
	marker.add_theme_color_override("font_color", UIThemeTokens.COLOR_CRITICAL)
	row.add_child(marker)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeadingLabel"
	texts.add_child(title_label)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(message_label)
	action_button = AEButton.new()
	action_button.kind = AEButton.Kind.PRIMARY
	action_button.text = "Ver"
	action_button.pressed.connect(func():
		if _current != null:
			action_requested.emit(_current)
		dismiss()
	)
	row.add_child(action_button)
	var close := AEButton.new()
	close.kind = AEButton.Kind.GHOST
	close.text = "×"
	close.pressed.connect(dismiss)
	row.add_child(close)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = AUTO_DISMISS_SECONDS
	_timer.timeout.connect(dismiss)
	add_child(_timer)

func _on_event(event: UIEventData) -> void:
	enqueue(event)

func _show_next() -> void:
	if _current != null or _queue.is_empty():
		return
	_current = _queue.pop_front()
	title_label.text = _current.title
	message_label.text = _current.message
	action_button.visible = _current.has_target_coord or not _current.focus_action.is_empty()
	visible = true
	modulate.a = 0.0
	position.y = -10.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_PANEL))
	tween.tween_property(self, "position:y", 0.0, Settings.motion_duration(UIThemeTokens.MOTION_PANEL))
	_timer.start()
