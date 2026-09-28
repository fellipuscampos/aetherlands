class_name NavigationManager
extends Node

signal destination_opened(destination: StringName)
signal destination_closed(destination: StringName)
signal overlay_visibility_changed(visible: bool)

const RESEARCH: StringName = &"research"
const EMPIRE: StringName = &"empire"
const DIPLOMACY: StringName = &"diplomacy"
const VICTORY: StringName = &"victory"
const PAUSE: StringName = &"pause"

var active_destination: StringName = &""
var _overlays: Dictionary = {}
var _before_open: Dictionary = {}
var _actions: Dictionary = {}
## Fase 30: foco de quem abriu a tela estratégica, devolvido ao fechar.
var _focus_before: Control

func register_overlay(destination: StringName, panel: Control, before_open: Callable = Callable()) -> void:
	_overlays[destination] = panel
	_before_open[destination] = before_open
	panel.visible = false

func register_action(destination: StringName, action: Callable) -> void:
	_actions[destination] = action

func open(destination: StringName) -> bool:
	if _actions.has(destination):
		(_actions[destination] as Callable).call()
		destination_opened.emit(destination)
		return true
	if not _overlays.has(destination):
		return false
	if active_destination == destination and (_overlays[destination] as Control).visible:
		close_active()
		return true
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	close_all()
	_focus_before = focused
	var callback: Callable = _before_open.get(destination, Callable())
	if callback.is_valid():
		callback.call()
	var panel: Control = _overlays[destination]
	panel.visible = true
	active_destination = destination
	overlay_visibility_changed.emit(true)
	destination_opened.emit(destination)
	return true

func open_panel(panel: Control) -> bool:
	for destination in _overlays:
		if _overlays[destination] == panel:
			return open(destination)
	return false

func close_active() -> bool:
	if active_destination == &"":
		return false
	var closing := active_destination
	if _overlays.has(closing):
		(_overlays[closing] as Control).visible = false
	active_destination = &""
	overlay_visibility_changed.emit(false)
	destination_closed.emit(closing)
	_restore_focus()
	return true

func _restore_focus() -> void:
	var target := _focus_before
	_focus_before = null
	if target != null and is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.call_deferred("grab_focus")

func close_all() -> void:
	var closing := active_destination
	for panel in _overlays.values():
		(panel as Control).visible = false
	active_destination = &""
	overlay_visibility_changed.emit(false)
	if closing != &"":
		destination_closed.emit(closing)

func is_overlay_open() -> bool:
	return active_destination != &""

func registered_destinations() -> Array:
	return _overlays.keys()
