class_name EventCenterPresenter
extends PanelContainer

signal close_requested
signal action_requested(event: UIEventData)

enum Filter { ALL, IMPORTANT, CRITICAL }

var rows: VBoxContainer
var unread_badge: AEBadge
var _filter: Filter = Filter.ALL
var _filter_buttons: Dictionary = {}

func _ready() -> void:
	theme_type_variation = &"ElevatedPanel"
	_build()
	if UIEvents != null:
		if not UIEvents.history_changed.is_connected(refresh):
			UIEvents.history_changed.connect(refresh)
		if not UIEvents.unread_changed.is_connected(_on_unread_changed):
			UIEvents.unread_changed.connect(_on_unread_changed)
	refresh()

func opened() -> void:
	if UIEvents != null:
		UIEvents.mark_all_read()
	refresh()

func set_filter(value: Filter) -> void:
	_filter = value
	for key in _filter_buttons:
		(_filter_buttons[key] as BaseButton).set_pressed_no_signal(int(key) == int(value))
	refresh()

func preferred_height() -> float:
	var count := UIEvents.get_history().size() if UIEvents != null else 0
	return clampf(180.0 + float(mini(count, 5)) * 76.0, 300.0, 560.0)

func refresh() -> void:
	if rows == null:
		_build()
	for child in rows.get_children():
		rows.remove_child(child)
		child.free()
	var history := UIEvents.get_history() if UIEvents != null else ([] as Array[UIEventData])
	history.reverse()
	for event in history:
		if _accepts(event):
			rows.add_child(_make_event_row(event))
	if rows.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Nenhum evento neste filtro."
		empty.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		rows.add_child(empty)
	_on_unread_changed(UIEvents.unread_count() if UIEvents != null else 0)

func _build() -> void:
	if rows != null:
		return
	custom_minimum_size = Vector2(360, 300)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Central de Eventos"
	title.theme_type_variation = &"HeadingLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	unread_badge = AEBadge.new()
	header.add_child(unread_badge)
	var close := AEIconButton.new()
	close.text = "×"
	close.tooltip_text = "Fechar Central de Eventos"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	# Em escala de UI alta os tres filtros quebram em mais de uma linha, em
	# vez de aumentar a largura minima do drawer alem do breakpoint compacto.
	var filters := HFlowContainer.new()
	root.add_child(filters)
	for definition in [["Todos", Filter.ALL], ["Importantes", Filter.IMPORTANT], ["Críticos", Filter.CRITICAL]]:
		var button := AEButton.new()
		button.kind = AEButton.Kind.GHOST
		button.text = definition[0]
		button.toggle_mode = true
		button.set_pressed_no_signal(int(definition[1]) == int(_filter))
		button.pressed.connect(set_filter.bind(definition[1]))
		filters.add_child(button)
		_filter_buttons[int(definition[1])] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	scroll.add_child(rows)

func _accepts(event: UIEventData) -> bool:
	if _filter == Filter.CRITICAL:
		return event.severity == UIEventData.Severity.CRITICAL
	if _filter == Filter.IMPORTANT:
		return event.severity >= UIEventData.Severity.IMPORTANT
	return true

func _make_event_row(event: UIEventData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, _severity_color(event.severity), 1, UIThemeTokens.RADIUS_CONTROL, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title := Label.new()
	title.text = "%s · T%d" % [event.title, event.turn]
	title.theme_type_variation = &"CaptionLabel"
	text_box.add_child(title)
	if not event.message.is_empty():
		var message := Label.new()
		message.text = event.message
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		text_box.add_child(message)
	if event.has_target_coord or not event.focus_action.is_empty():
		var action := AEButton.new()
		action.kind = AEButton.Kind.GHOST
		action.text = "Ir para" if event.has_target_coord else "Abrir"
		action.pressed.connect(func(): action_requested.emit(event))
		row.add_child(action)
	return panel

func _on_unread_changed(count: int) -> void:
	if unread_badge == null:
		return
	unread_badge.visible = count > 0
	unread_badge.text = str(count)

func _severity_color(value: UIEventData.Severity) -> Color:
	if value == UIEventData.Severity.CRITICAL:
		return UIThemeTokens.COLOR_CRITICAL
	if value == UIEventData.Severity.IMPORTANT:
		return UIThemeTokens.COLOR_WARNING
	return UIThemeTokens.COLOR_INFO
