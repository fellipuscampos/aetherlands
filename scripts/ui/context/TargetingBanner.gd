class_name TargetingBanner
extends Control

## Banner FIXO de mira (Fase 30 / UI-3), hospedado na faixa inferior da shell.
## Enquanto o SelectionManager estiver em qualquer modo de mira mostra: ação,
## alvo válido, alcance, custo, instrução e "ESC cancela". O Unit/City Panel não
## precisa reescrever o próprio texto. Clique inválido gera feedback curto por
## Timer (sem `_process`); nada é gasto — o runtime continua a autoridade.

const FEEDBACK_SECONDS := 1.8

var panel: PanelContainer
var title_label: Label
var detail_flow: HFlowContainer
var instruction_label: Label
var cancel_button: AEButton
var feedback_panel: PanelContainer
var feedback_label: Label
var current: Dictionary = {}
var _timer: Timer
var _stripe: ColorRect

func _ready() -> void:
	name = "TargetingBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	if not EventBus.targeting_changed.is_connected(refresh):
		EventBus.targeting_changed.connect(refresh)
	if not EventBus.targeting_rejected.is_connected(show_feedback):
		EventBus.targeting_rejected.connect(show_feedback)
	if not EventBus.unit_selected.is_connected(_on_selection_changed):
		EventBus.unit_selected.connect(_on_selection_changed)
	refresh()

func _build() -> void:
	if panel != null:
		return
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	add_child(column)
	feedback_panel = PanelContainer.new()
	feedback_panel.name = "Feedback"
	feedback_panel.visible = false
	feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	feedback_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_WARNING.darkened(0.78), UIThemeTokens.COLOR_WARNING, 1, UIThemeTokens.RADIUS_CONTROL, false))
	column.add_child(feedback_panel)
	feedback_label = ContextUI.label("", UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_WARNING, false)
	feedback_panel.add_child(feedback_label)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"ElevatedPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	panel.add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(4, 0)
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_stripe)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	texts.add_child(heading)
	var mode := ContextUI.label("MIRA", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TARGETING, false)
	mode.name = "Mode"
	heading.add_child(mode)
	title_label = ContextUI.label("", UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_TEXT, false)
	title_label.name = "Title"
	heading.add_child(title_label)
	detail_flow = ContextUI.flow()
	detail_flow.name = "Details"
	texts.add_child(detail_flow)
	instruction_label = ContextUI.label("", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED)
	instruction_label.name = "Instruction"
	texts.add_child(instruction_label)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(actions)
	var esc := ContextUI.label("ESC cancela", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED, false)
	esc.name = "EscHint"
	esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(esc)
	cancel_button = AEButton.new()
	cancel_button.name = "CancelButton"
	cancel_button.kind = AEButton.Kind.GHOST
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(func(): SelectionManager.cancel_active_targeting())
	actions.add_child(cancel_button)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = FEEDBACK_SECONDS
	_timer.timeout.connect(_on_feedback_timeout)
	add_child(_timer)

func refresh() -> void:
	_build()
	current = TargetingPresenter.current()
	panel.visible = not current.is_empty()
	if not current.is_empty():
		title_label.text = String(current.title)
		_stripe.color = current.get("color", UIThemeTokens.COLOR_TARGETING)
		ContextUI.clear(detail_flow)
		detail_flow.add_child(ContextUI.chip("Alvo: %s" % current.target, AEStatusChip.Tone.TRAIT))
		if int(current.get("range", 0)) > 0:
			detail_flow.add_child(ContextUI.chip("Alcance %d" % int(current.range), AEStatusChip.Tone.TRAIT))
		if String(current.get("cost", "")) != "":
			detail_flow.add_child(ContextUI.chip(String(current.cost), AEStatusChip.Tone.TRAIT))
		detail_flow.add_child(ContextUI.chip("%d alvo%s válido%s" % [int(current.targets), "" if int(current.targets) == 1 else "s", "" if int(current.targets) == 1 else "s"], AEStatusChip.Tone.NEUTRAL))
		instruction_label.text = String(current.instruction)
	_update_visibility()

func show_feedback(message: String) -> void:
	_build()
	feedback_label.text = message
	feedback_panel.visible = true
	_timer.start()
	_update_visibility()

func is_active() -> bool:
	return panel != null and panel.visible

func _on_feedback_timeout() -> void:
	feedback_panel.visible = false
	_update_visibility()

func _on_selection_changed(_unit: Unit) -> void:
	refresh()

func _update_visibility() -> void:
	visible = panel.visible or feedback_panel.visible
