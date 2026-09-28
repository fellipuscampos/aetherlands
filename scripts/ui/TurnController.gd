class_name TurnController
extends PanelContainer

signal action_requested(action: String, item: AttentionItem)
signal end_turn_requested

var service: AttentionService
var modal_manager: ModalManager
var primary_button: AEButton
var override_button: AEButton
var warning_badge: AEBadge
var _processing := false

func _ready() -> void:
	theme_type_variation = &"ElevatedPanel"
	_build()

func bind(value: AttentionService, manager: ModalManager) -> void:
	if service != null and service.items_changed.is_connected(_on_items_changed):
		service.items_changed.disconnect(_on_items_changed)
	service = value
	modal_manager = manager
	if service != null and not service.items_changed.is_connected(_on_items_changed):
		service.items_changed.connect(_on_items_changed)
	refresh()

func set_processing(value: bool) -> void:
	if _processing == value:
		return
	_processing = value
	refresh()

func request_primary_action() -> void:
	if _processing or GameManager.state != GameManager.GameState.PLAYING:
		return
	var next := service.next_required() if service != null else null
	if next != null:
		action_requested.emit(next.primary_action, next)
	else:
		end_turn_requested.emit()

func request_override() -> void:
	if _processing or service == null or service.required_items().is_empty():
		return
	_show_override_modal(service.required_items())

func refresh() -> void:
	if primary_button == null:
		_build()
	if _processing:
		primary_button.text = "Processando Turno…"
		primary_button.disabled = true
		override_button.visible = false
		warning_badge.visible = false
		return
	primary_button.disabled = GameManager.state != GameManager.GameState.PLAYING
	var next := service.next_required() if service != null else null
	var warnings := service.warning_items().size() if service != null else 0
	if next != null:
		primary_button.text = next.title
		override_button.visible = true
		warning_badge.visible = false
	else:
		primary_button.text = "Finalizar Turno"
		override_button.visible = false
		warning_badge.visible = warnings > 0
		warning_badge.text = str(warnings)

func _build() -> void:
	if primary_button != null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	add_child(row)
	primary_button = AEButton.new()
	primary_button.kind = AEButton.Kind.PRIMARY
	primary_button.custom_minimum_size.x = 220
	primary_button.pressed.connect(request_primary_action)
	row.add_child(primary_button)
	warning_badge = AEBadge.new()
	warning_badge.tooltip_text = "Avisos não bloqueiam o fim do turno."
	row.add_child(warning_badge)
	override_button = AEButton.new()
	override_button.kind = AEButton.Kind.GHOST
	override_button.text = "Encerrar mesmo assim"
	override_button.pressed.connect(request_override)
	row.add_child(override_button)

func _on_items_changed(_items: Array[AttentionItem]) -> void:
	refresh()

func _show_override_modal(required: Array[AttentionItem]) -> void:
	if modal_manager == null or modal_manager.is_modal_open():
		return
	var frame := AEModalFrame.new()
	frame.name = "EndTurnOverrideDialog"
	frame.set_title("Decisões pendentes")
	var description := Label.new()
	description.text = "Existem decisões pendentes:"
	frame.body_host.add_child(description)
	for item in required:
		var line := Label.new()
		line.text = "• %s" % item.title
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		frame.body_host.add_child(line)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var back := AEButton.new()
	back.text = "Voltar às pendências"
	back.pressed.connect(func(): modal_manager.dismiss_top(true))
	actions.add_child(back)
	var confirm := AEButton.new()
	confirm.kind = AEButton.Kind.DANGER
	confirm.text = "Encerrar turno mesmo assim"
	confirm.pressed.connect(func():
		modal_manager.dismiss_top(true)
		end_turn_requested.emit()
	)
	actions.add_child(confirm)
	frame.body_host.add_child(actions)
	frame.close_requested.connect(func(): modal_manager.dismiss_top(true))
	modal_manager.present(frame, true, true)
