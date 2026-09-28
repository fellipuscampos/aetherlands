class_name DiplomacyScreen
extends StrategyScreen

func preferred_frame_height() -> float:
	return 440.0

## Tela estratégica de DIPLOMACIA (Fase 30 / UI-3): facções à esquerda com estado
## imediato (guerra/paz/trégua/eliminada), detalhe dominante à direita com fatos
## públicos, consequências e ações reais. Declarar guerra pede confirmação no
## ModalManager; propor paz usa a regra existente (pode ser recusada).

var modal_manager: ModalManager
var selected_rival: PlayerData
var pending_selection := ""
var faction_buttons: Array[Button] = []
var last_peace_result := ""
var _list: VBoxContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _confirm_modal: AEModalFrame

func _ready() -> void:
	name = "DiplomacyScreen"
	super._ready()
	set_titles("Diplomacia", "Relações públicas com cada civilização rival.")
	var split := HBoxContainer.new()
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", UIThemeTokens.SPACE_4)
	content.add_child(split)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "FactionScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size.x = 320
	split.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.name = "FactionList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	list_scroll.add_child(_list)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	_detail_scroll.add_child(_detail)

## Deep link (War Alert, Event Center): abre já com a facção certa.
func select_faction_by_name(name_value: String) -> void:
	pending_selection = name_value
	if is_visible_in_tree():
		refresh()

func select_rival(rival: PlayerData) -> void:
	selected_rival = rival
	last_peace_result = ""
	refresh()

func _rebuild() -> void:
	var human := GameManager.human_player
	ContextUI.clear(_list)
	ContextUI.clear(_detail)
	faction_buttons.clear()
	if human == null:
		_detail.add_child(ContextUI.empty_state("Nenhuma partida em andamento."))
		return
	var rows := DiplomacyPresenter.rows(human)
	if not pending_selection.is_empty():
		var found := DiplomacyPresenter.find_rival_by_name(pending_selection)
		if found != null:
			selected_rival = found
		pending_selection = ""
	if selected_rival == null or not GameManager.rival_players.has(selected_rival):
		selected_rival = _default_selection(rows)
	var wars := 0
	for row in rows:
		if row.state == DiplomacyPresenter.STATE_WAR:
			wars += 1
		_list.add_child(_faction_button(row))
	set_titles("Diplomacia", "Em guerra com %d civilização(ões)." % wars if wars > 0 else "Em paz com todas as civilizações.")
	if selected_rival != null:
		_render_detail(DiplomacyPresenter.detail(human, selected_rival))

func _default_selection(rows: Array) -> PlayerData:
	for row in rows:
		if row.state == DiplomacyPresenter.STATE_WAR:
			return row.player
	return rows[0].player if not rows.is_empty() else null

func _faction_button(row: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Faction_%s" % String(row.name).validate_node_name()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 64
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected: bool = row.player == selected_rival
	var tone_color := _state_color(String(row.state))
	var style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED if selected else UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_ACCENT if selected else Color(UIThemeTokens.COLOR_BORDER, 0.7), 2 if selected else 1, UIThemeTokens.RADIUS_CONTROL, false)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED, UIThemeTokens.COLOR_ACCENT, 1, UIThemeTokens.RADIUS_CONTROL, false))
	var rival: PlayerData = row.player
	button.pressed.connect(select_rival.bind(rival))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = UIThemeTokens.SPACE_2
	line.offset_right = -UIThemeTokens.SPACE_2
	line.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	button.add_child(line)
	var swatch := ColorRect.new()
	swatch.color = row.color
	swatch.custom_minimum_size = Vector2(6, 40)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(swatch)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	line.add_child(texts)
	var name_label := ContextUI.label(String(row.name), UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_TEXT, false)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var sub := "Trégua: %d turno(s)" % int(row.truce_remaining) if row.state == DiplomacyPresenter.STATE_TRUCE else ""
	if not row.alerts.is_empty():
		sub = " · ".join(row.alerts) if sub.is_empty() else sub + " · " + " · ".join(row.alerts)
	if not sub.is_empty():
		var sub_label := ContextUI.caption(sub)
		sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(sub_label)
	var state_chip := ContextUI.chip(String(row.state_label).to_upper(), DiplomacyPresenter.state_tone(String(row.state)))
	state_chip.name = "StateChip"
	state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(state_chip)
	line.add_child(_spacer_for(tone_color))
	faction_buttons.append(button)
	return button

func _spacer_for(_color: Color) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 2
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _state_color(state: String) -> Color:
	match state:
		DiplomacyPresenter.STATE_WAR:
			return UIThemeTokens.COLOR_CRITICAL
		DiplomacyPresenter.STATE_TRUCE:
			return UIThemeTokens.COLOR_WARNING
		DiplomacyPresenter.STATE_ELIMINATED:
			return UIThemeTokens.COLOR_TEXT_DISABLED
	return UIThemeTokens.COLOR_SUCCESS

func _render_detail(data: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.name = "DetailHeader"
	header.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	_detail.add_child(header)
	var swatch := ColorRect.new()
	swatch.color = data.color
	swatch.custom_minimum_size = Vector2(8, 48)
	header.add_child(swatch)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := ContextUI.label(String(data.name), UIThemeTokens.FONT_H2, UIThemeTokens.COLOR_TEXT, false)
	title.name = "FactionName"
	titles.add_child(title)
	var state_label := ContextUI.label(String(data.state_label), UIThemeTokens.FONT_BODY, _state_color(String(data.state)), false)
	state_label.name = "StateLabel"
	titles.add_child(state_label)
	var facts_section := ContextUI.section("Situação")
	_detail.add_child(facts_section)
	if data.facts.is_empty():
		facts_section.add_child(ContextUI.caption("Sem conflito ativo."))
	for fact in data.facts:
		facts_section.add_child(ContextUI.key_value(String(fact.caption), String(fact.text), String(fact.get("tone", ""))))
	var consequences := ContextUI.section("Consequências")
	_detail.add_child(consequences)
	for line in data.consequences:
		consequences.add_child(ContextUI.label("· " + String(line), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT_MUTED))
	var actions := ContextUI.section("Ações")
	_detail.add_child(actions)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	actions.add_child(row)
	var rival: PlayerData = data.player
	if String(data.state) == DiplomacyPresenter.STATE_WAR:
		var peace := AEButton.new()
		peace.name = "ProposePeaceButton"
		peace.kind = AEButton.Kind.PRIMARY
		peace.text = "Propor Paz"
		peace.disabled = not data.can_propose_peace
		peace.tooltip_text = AETooltip.compose("Propor Paz", "A civilização pode aceitar ou recusar. Paz aceita inicia %d turnos de trégua." % Diplomacy.TRUCE_TURNS)
		peace.pressed.connect(_on_propose_peace.bind(rival))
		row.add_child(peace)
	elif String(data.state) != DiplomacyPresenter.STATE_ELIMINATED:
		var war := AEButton.new()
		war.name = "DeclareWarButton"
		war.kind = AEButton.Kind.DANGER
		war.text = "Declarar Guerra"
		war.disabled = not data.can_declare_war
		war.tooltip_text = AETooltip.compose("Declarar Guerra", "Pede confirmação antes de mudar o estado.", [], String(data.declare_reason))
		war.pressed.connect(request_declare_war.bind(rival))
		row.add_child(war)
		if String(data.declare_reason) != "" and not data.can_declare_war:
			actions.add_child(ContextUI.label(String(data.declare_reason), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
	else:
		actions.add_child(ContextUI.caption("Nenhuma ação diplomática com uma civilização eliminada."))
	if not last_peace_result.is_empty():
		var result := ContextUI.label(last_peace_result, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_WARNING if last_peace_result.contains("recusou") else UIThemeTokens.COLOR_SUCCESS)
		result.name = "PeaceResult"
		actions.add_child(result)
	var events := ContextUI.section("Eventos recentes desta sessão")
	_detail.add_child(events)
	if data.events.is_empty():
		events.add_child(ContextUI.caption("Nenhum evento diplomático registrado nesta sessão."))
	for event in data.events:
		events.add_child(ContextUI.key_value("Turno %d" % int(event.turn), "%s — %s" % [event.title, event.message]))

func _on_propose_peace(rival: PlayerData) -> void:
	var human := GameManager.human_player
	if human == null or rival == null or GameManager.is_turn_processing:
		return
	var accepted := Diplomacy.propose_peace(human, rival)
	last_peace_result = "%s aceitou a paz." % rival.civ.civ_name if accepted else "%s recusou a paz." % rival.civ.civ_name
	if not accepted:
		# Recusa não gera evento de domínio; o toast legado segue como confirmação curta.
		EventBus.notify.emit(last_peace_result, "")
	refresh()

## Abre a confirmação curta via ModalManager (Cancelar / Declarar Guerra).
func request_declare_war(rival: PlayerData) -> void:
	var human := GameManager.human_player
	if human == null or rival == null or not Diplomacy.can_declare_war(human, rival):
		return
	if modal_manager == null:
		confirm_declare_war(rival)
		return
	_confirm_modal = AEModalFrame.new()
	_confirm_modal.name = "DeclareWarConfirmation"
	_confirm_modal.custom_minimum_size = Vector2(460, 0)
	modal_manager.present(_confirm_modal, true, true)
	_confirm_modal.set_title("Declarar guerra a %s?" % rival.civ.civ_name)
	_confirm_modal.close_requested.connect(func(): modal_manager.dismiss_top())
	var body := _confirm_modal.body_host
	body.add_child(ContextUI.label("Paz → Guerra. As duas civilizações passam a poder atacar unidades e cidades uma da outra.", UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	body.add_child(ContextUI.label("Guerra custa Ouro por unidade militar e acumula cansaço. Paz futura depende da aceitação deles.", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	body.add_child(buttons)
	var cancel := AEButton.new()
	cancel.name = "CancelButton"
	cancel.kind = AEButton.Kind.GHOST
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): modal_manager.dismiss_top())
	buttons.add_child(cancel)
	var confirm := AEButton.new()
	confirm.name = "ConfirmButton"
	confirm.kind = AEButton.Kind.DANGER
	confirm.text = "Declarar Guerra"
	confirm.pressed.connect(func():
		modal_manager.dismiss_top()
		confirm_declare_war(rival))
	buttons.add_child(confirm)
	cancel.call_deferred("grab_focus")

func confirmation_modal() -> AEModalFrame:
	return _confirm_modal if _confirm_modal != null and is_instance_valid(_confirm_modal) else null

## Uma única declaração; o evento estruturado (War) sai do próprio Diplomacy.
func confirm_declare_war(rival: PlayerData) -> void:
	var human := GameManager.human_player
	if human == null or rival == null or not Diplomacy.can_declare_war(human, rival):
		return
	Diplomacy.declare_war(human, rival)
	selected_rival = rival
	last_peace_result = ""
	refresh()
