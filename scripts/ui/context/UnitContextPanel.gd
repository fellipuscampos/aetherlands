class_name UnitContextPanel
extends VBoxContainer

## Painel de contexto de UNIDADE (Fase 30 / UI-3) — substitui o UnitPanel legado.
## Hierarquia: cabeçalho de identidade → vitais → comandos → habilidades →
## passivas/traços → efeitos ativos → rodapé. Dados vêm do UnitPresenter; cada
## clique entra no MESMO caminho do SelectionManager usado pelo mapa (nenhum
## handler paralelo). Unidade de outro dono é somente leitura.

signal close_requested

var unit: Unit
var view: Dictionary = {}
var portrait: AEPortrait
var name_label: Label
var subtitle_label: Label
var badge_flow: HFlowContainer
var body: VBoxContainer
var scroll: ScrollContainer
var warning_panel: PanelContainer
var hp_meter: Control
var stat_items: Array[AEStatItem] = []
var command_buttons: Array[AECommandButton] = []
var ability_buttons: Array[AEAbilityButton] = []
var passive_chips: Array[AEStatusChip] = []
var status_chips: Array[AEStatusChip] = []
const MAX_STATUS_CHIPS := 6
var render_count := 0
## Assinatura da última visão desenhada: sinais repetidos (névoa, turno, mira de
## outra unidade) que não mudam nada visível não remontam o painel.
var _last_key := 0

func _ready() -> void:
	name = "UnitContextPanel"
	add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_chrome()

func _build_chrome() -> void:
	if body != null:
		return
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	add_child(header)
	portrait = AEPortrait.new()
	portrait.name = "Portrait"
	header.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	header.add_child(identity)
	name_label = ContextUI.label("", UIThemeTokens.FONT_H3, UIThemeTokens.COLOR_TEXT)
	name_label.name = "UnitName"
	identity.add_child(name_label)
	subtitle_label = ContextUI.caption("")
	subtitle_label.name = "Subtitle"
	identity.add_child(subtitle_label)
	badge_flow = ContextUI.flow()
	badge_flow.name = "Badges"
	identity.add_child(badge_flow)
	var close := ContextUI.close_button("Fechar seleção")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	scroll.add_child(body)

func show_unit(value: Unit) -> void:
	unit = value
	refresh()

func is_showing(value: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit == value

func is_valid_context() -> bool:
	return unit != null and is_instance_valid(unit) and unit.hp > 0.0 and not unit.is_queued_for_deletion()

func refresh() -> void:
	_build_chrome()
	if not is_valid_context():
		view = {"valid": false}
		return
	var built := UnitPresenter.build(unit, GameManager.human_player, GameManager.hex_grid)
	var key := view_key(built)
	view = built
	if key == _last_key and render_count > 0:
		return
	_last_key = key
	var previous_scroll := scroll.scroll_vertical
	_render()
	scroll.set_deferred("scroll_vertical", previous_scroll)
	render_count += 1

static func view_key(data: Dictionary) -> int:
	var copy := data.duplicate()
	for list_key in ["commands", "abilities"]:
		var flattened: Array = []
		for entry in data.get(list_key, []):
			flattened.append([(entry as UnitAbilityViewData).to_dict(), (entry as UnitAbilityViewData).tooltip()])
		copy[list_key] = flattened
	return str(copy).hash()

func _render() -> void:
	name_label.text = view.name
	subtitle_label.text = "%s · %s" % [view.subtitle, view.owner_name if view.own else "%s (%s)" % [view.owner_name, view.relation]]
	portrait.configure(view.portrait_glyph, view.portrait_accent, view.owner_color, view.portrait_caption)
	ContextUI.clear(badge_flow)
	for badge in view.badges:
		badge_flow.add_child(ContextUI.chip(badge.text, badge.tone, -1, badge.get("tooltip", "")))
	badge_flow.visible = not view.badges.is_empty()
	ContextUI.clear(body)
	stat_items.clear()
	command_buttons.clear()
	ability_buttons.clear()
	passive_chips.clear()
	status_chips.clear()
	warning_panel = null
	if not view.warning.is_empty():
		body.add_child(_warning_block(view.warning))
	body.add_child(_vitals())
	if view.own and not view.commands.is_empty():
		body.add_child(_commands())
	if view.own and (not view.abilities.is_empty() or not String(view.ability_empty_text).is_empty()):
		body.add_child(_abilities())
	if not view.passives.is_empty():
		body.add_child(_passives())
	if not view.statuses.is_empty():
		body.add_child(_statuses())
	if not view.footer.is_empty():
		body.add_child(_footer())

func _warning_block(warning: Dictionary) -> Control:
	warning_panel = ContextUI.card(UIThemeTokens.COLOR_CRITICAL, UIThemeTokens.COLOR_CRITICAL.darkened(0.78))
	warning_panel.name = "CommandWarning"
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 2)
	warning_panel.add_child(box)
	var title := ContextUI.label(String(warning.title), UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_CRITICAL, false)
	title.name = "WarningTitle"
	box.add_child(title)
	box.add_child(ContextUI.label(String(warning.body), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	if String(warning.get("hint", "")) != "":
		box.add_child(ContextUI.caption(String(warning.hint)))
	return warning_panel

func _vitals() -> Control:
	var box := VBoxContainer.new()
	box.name = "Vitals"
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	hp_meter = ContextUI.meter("Vida", view.hp, view.max_hp, ContextUI.hp_color(view.hp, view.max_hp), "", 12.0)
	hp_meter.name = "HPMeter"
	box.add_child(hp_meter)
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = mini(4, view.stats.size())
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	grid.add_theme_constant_override("v_separation", UIThemeTokens.SPACE_1)
	box.add_child(grid)
	for stat in view.stats:
		var item := AEStatItem.new()
		item.name = "Stat_" + String(stat.key)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(item)
		item.set_stat(stat.caption, stat.value, stat.get("glyph", ""), stat.get("tooltip", ""), stat.get("color", UIThemeTokens.COLOR_TEXT))
		stat_items.append(item)
	return box

func _commands() -> Control:
	var box := ContextUI.section("Comandos")
	box.name = "Commands"
	var grid := GridContainer.new()
	grid.name = "CommandStrip"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	grid.add_theme_constant_override("v_separation", UIThemeTokens.SPACE_1)
	box.add_child(grid)
	for command in view.commands:
		var button := AECommandButton.new()
		grid.add_child(button)
		button.configure_view(command)
		button.command_pressed.connect(_execute)
		command_buttons.append(button)
	return box

func _abilities() -> Control:
	var box := ContextUI.section(String(view.ability_title), "%d" % view.abilities.size() if not view.abilities.is_empty() else "")
	box.name = "Abilities"
	if view.abilities.is_empty():
		box.add_child(ContextUI.empty_state(String(view.ability_empty_text)))
		return box
	var grid := GridContainer.new()
	grid.name = "AbilityGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	grid.add_theme_constant_override("v_separation", UIThemeTokens.SPACE_1)
	box.add_child(grid)
	for ability in view.abilities:
		var button := AEAbilityButton.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		button.configure_view(ability)
		button.ability_pressed.connect(_execute)
		ability_buttons.append(button)
	return box

func _passives() -> Control:
	var box := ContextUI.section("Passivas e traços")
	box.name = "Passives"
	var flow := ContextUI.flow()
	box.add_child(flow)
	for passive in view.passives:
		var chip := ContextUI.chip(passive.title, AEStatusChip.Tone.TRAIT, -1, passive.tooltip)
		flow.add_child(chip)
		passive_chips.append(chip)
	return box

func _statuses() -> Control:
	var box := ContextUI.section("Efeitos ativos")
	box.name = "Statuses"
	var flow := ContextUI.flow()
	box.add_child(flow)
	# V3 / Etapa 4: chips quebram linha (flow); acima de MAX_STATUS_CHIPS os demais viram um chip "+N" cujo tooltip
	# lista os ocultos — o card nunca explode em resolução pequena.
	var shown: Array = view.statuses if view.statuses.size() <= MAX_STATUS_CHIPS else view.statuses.slice(0, MAX_STATUS_CHIPS - 1)
	for status in shown:
		var chip := ContextUI.chip(status.title, status.tone, int(status.turns), status.tooltip)
		flow.add_child(chip)
		status_chips.append(chip)
	if shown.size() < view.statuses.size():
		var hidden: Array = view.statuses.slice(shown.size())
		var names: Array[String] = []
		for status in hidden:
			names.append("%s%s" % [status.title, (" · %dt" % int(status.turns)) if int(status.turns) >= 0 else ""])
		var more := ContextUI.chip("+%d" % hidden.size(), AEStatusChip.Tone.NEUTRAL, -1, AETooltip.compose("Outros efeitos", "", names))
		more.name = "MoreStatuses"
		flow.add_child(more)
	return box

func _footer() -> Control:
	var box := ContextUI.section("Contexto")
	box.name = "Footer"
	for entry in view.footer:
		box.add_child(ContextUI.key_value(String(entry.caption), String(entry.text), String(entry.get("tone", ""))))
	return box

## Todos os comandos entram na mesma API usada pelo clique no mapa e pelo HUD
## legado; clicar de novo numa habilidade em mira cancela a mira (como ESC).
func _execute(action: UnitAbilityViewData) -> void:
	if action == null or not is_valid_context() or SelectionManager.selected_unit != unit:
		return
	if action.state == UnitAbilityViewData.State.TARGETING and action.action_kind in ["technique", "spell"]:
		SelectionManager.cancel_active_targeting()
		return
	match action.action_kind:
		"move":
			SelectionManager.wake_selected_for_move()
		"fortify":
			SelectionManager.fortify_selected()
		"explore":
			SelectionManager.toggle_explore_selected()
		"found_city":
			SelectionManager.found_city_with_selected()
		"improve_resource":
			SelectionManager.improve_resource_with_selected()
		"traverse_portal":
			SelectionManager.traverse_selected_portal()
		"technique":
			SelectionManager.use_technique_selected(action.action_arg)
		"spell":
			SelectionManager.use_v2_spell_selected(action.action_arg)
		"upgrade":
			SelectionManager.upgrade_selected()
		"dissolve":
			SelectionManager.dissolve_selected_retinue()

func button_for(action_id: String) -> Control:
	for button in command_buttons:
		if button.view != null and button.view.id == action_id:
			return button
	for button in ability_buttons:
		if button.view != null and button.view.id == action_id:
			return button
	return null

func preferred_height() -> float:
	if body == null:
		return 0.0
	var header := get_node("Header") as Control
	return header.get_combined_minimum_size().y + body.get_combined_minimum_size().y + UIThemeTokens.SPACE_2 * 2
