class_name AttentionPresenter
extends PanelContainer

signal action_requested(action: String, item: AttentionItem)
signal expanded_changed(expanded: bool)

var service: AttentionService
var summary_button: AEButton
var content: VBoxContainer
var _expanded := false

func _ready() -> void:
	theme_type_variation = &"ElevatedPanel"
	_build()

func bind_service(value: AttentionService) -> void:
	if service != null and service.items_changed.is_connected(_on_items_changed):
		service.items_changed.disconnect(_on_items_changed)
	service = value
	if service != null and not service.items_changed.is_connected(_on_items_changed):
		service.items_changed.connect(_on_items_changed)
	refresh()

func is_expanded() -> bool:
	return _expanded

func collapse() -> void:
	if not _expanded:
		return
	_expanded = false
	content.visible = false
	expanded_changed.emit(false)

func refresh() -> void:
	if summary_button == null:
		_build()
	var all_items := service.items() if service != null else ([] as Array[AttentionItem])
	visible = not all_items.is_empty()
	if all_items.is_empty():
		collapse()
		return
	var required := 0
	var warnings := 0
	for item in all_items:
		if item.priority == AttentionItem.Priority.REQUIRED:
			required += 1
		elif item.priority == AttentionItem.Priority.WARNING:
			warnings += 1
	summary_button.text = "%d pendência%s%s" % [required, "" if required == 1 else "s", " · %d aviso%s" % [warnings, "" if warnings == 1 else "s"] if warnings > 0 else ""]
	_rebuild_items(all_items)

func _build() -> void:
	if summary_button != null:
		return
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	add_child(root)
	summary_button = AEButton.new()
	summary_button.kind = AEButton.Kind.PRIMARY
	summary_button.custom_minimum_size.x = 360
	summary_button.pressed.connect(_toggle)
	root.add_child(summary_button)
	content = VBoxContainer.new()
	content.visible = false
	content.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	root.add_child(content)

func _toggle() -> void:
	_expanded = not _expanded
	content.visible = _expanded
	expanded_changed.emit(_expanded)

func _on_items_changed(_items: Array[AttentionItem]) -> void:
	refresh()

func _rebuild_items(all_items: Array[AttentionItem]) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.free()
	for priority in [AttentionItem.Priority.REQUIRED, AttentionItem.Priority.WARNING, AttentionItem.Priority.SUGGESTION]:
		var section_items: Array[AttentionItem] = []
		for item in all_items:
			if item.priority == priority:
				section_items.append(item)
		if section_items.is_empty():
			continue
		var heading := Label.new()
		heading.theme_type_variation = &"CaptionLabel"
		heading.text = ["DECISÕES", "ALERTAS", "SUGESTÕES"][priority]
		content.add_child(heading)
		for item in section_items:
			content.add_child(_make_item_row(item))

func _make_item_row(item: AttentionItem) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	var marker := Label.new()
	marker.text = "◆" if item.priority == AttentionItem.Priority.REQUIRED else ("!" if item.severity == UIEventData.Severity.CRITICAL else "●")
	marker.add_theme_color_override("font_color", _item_color(item))
	row.add_child(marker)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title := Label.new()
	title.text = item.title
	title.theme_type_variation = &"CaptionLabel"
	text_box.add_child(title)
	if not item.description.is_empty():
		var description := Label.new()
		description.text = item.description
		description.theme_type_variation = &"CaptionLabel"
		description.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(description)
	var action := AEButton.new()
	action.kind = AEButton.Kind.GHOST
	action.text = item.primary_action_label
	action.pressed.connect(func(): action_requested.emit(item.primary_action, item))
	row.add_child(action)
	return row

func _item_color(item: AttentionItem) -> Color:
	if item.severity == UIEventData.Severity.CRITICAL:
		return UIThemeTokens.COLOR_CRITICAL
	if item.priority == AttentionItem.Priority.REQUIRED:
		return UIThemeTokens.COLOR_ACCENT
	if item.priority == AttentionItem.Priority.WARNING:
		return UIThemeTokens.COLOR_WARNING
	return UIThemeTokens.COLOR_INFO
