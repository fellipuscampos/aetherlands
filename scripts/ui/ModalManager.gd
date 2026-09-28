class_name ModalManager
extends Control

signal modal_opened(modal: Control)
signal modal_closed(modal: Control)

const MAX_STACK := 3

@onready var dimmer: ColorRect = $Dimmer
@onready var content_host: CenterContainer = $ContentHost

var _stack: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func present(modal: Control, cancelable: bool = true, take_ownership: bool = false) -> bool:
	if modal == null or _stack.size() >= MAX_STACK:
		return false
	var previous_focus := get_viewport().gui_get_focus_owner()
	if modal.get_parent() != null:
		modal.reparent(content_host, false)
	else:
		content_host.add_child(modal)
	for entry in _stack:
		(entry.modal as Control).visible = false
	_stack.append({"modal": modal, "cancelable": cancelable, "owned": take_ownership, "focus": previous_focus})
	modal.visible = true
	# Um frame modal precisa sempre aceitar foco para que teclado/controle
	# fiquem presos na camada correta, mesmo quando o conteúdo legado não
	# declarou focus_mode explicitamente.
	if modal.focus_mode == Control.FOCUS_NONE:
		modal.focus_mode = Control.FOCUS_ALL
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.98, 0.98)
	modal.pivot_offset = modal.size * 0.5
	visible = true
	var tween := modal.create_tween().set_parallel(true)
	tween.tween_property(modal, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_MODAL)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(modal, "scale", Vector2.ONE, Settings.motion_duration(UIThemeTokens.MOTION_MODAL)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	modal_opened.emit(modal)
	modal.call_deferred("grab_focus")
	return true

func dismiss_top(force: bool = false) -> bool:
	if _stack.is_empty():
		return false
	var entry: Dictionary = _stack.back()
	if not force and not bool(entry.cancelable):
		return false
	_stack.pop_back()
	var modal: Control = entry.modal
	modal.visible = false
	if bool(entry.owned):
		modal.queue_free()
	modal_closed.emit(modal)
	if _stack.is_empty():
		visible = false
	else:
		(_stack.back().modal as Control).visible = true
	var previous_focus: Control = entry.focus
	if is_instance_valid(previous_focus):
		previous_focus.call_deferred("grab_focus")
	return true

func clear(force: bool = true) -> void:
	while not _stack.is_empty():
		if not dismiss_top(force):
			break

func is_modal_open() -> bool:
	return not _stack.is_empty()

func modal_count() -> int:
	return _stack.size()

func top_is_cancelable() -> bool:
	return not _stack.is_empty() and bool(_stack.back().cancelable)

func blocks_gameplay_input(event: InputEvent) -> bool:
	return is_modal_open() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion)

func handle_escape() -> bool:
	if not is_modal_open():
		return false
	dismiss_top(false)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if event.is_action_pressed("ui_cancel"):
		handle_escape()
		get_viewport().set_input_as_handled()
		return
	if blocks_gameplay_input(event):
		get_viewport().set_input_as_handled()
