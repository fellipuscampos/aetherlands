class_name VictoryScreen
extends StrategyScreen

## Tela estratégica de VITÓRIA (Fase 30 / UI-3). SUMMARY: três cards comparáveis
## (Dominação, Supremacia Militar, Transcendência) com estado, progresso
## segmentado, próximo requisito e ameaça pública. DETAIL: checklist, rivais e
## "Como vencer". Explicação longa só no detalhe, nunca no resumo.

signal ritual_location_requested(coord: Vector2i)

var current_detail := ""
var summary_cards: Dictionary = {}
var _body: VBoxContainer
var _back_button: AEIconButton

func _ready() -> void:
	name = "VictoryScreen"
	super._ready()
	set_titles("Vitória", "Três rotas; a primeira condição cumprida encerra a partida.")
	_back_button = AEIconButton.new()
	_back_button.name = "BackToSummary"
	_back_button.text = "←"
	_back_button.tooltip_text = "Voltar ao resumo"
	_back_button.visible = false
	_back_button.pressed.connect(show_summary)
	header_actions.add_child(_back_button)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	scroll.add_child(_body)

func show_summary() -> void:
	current_detail = ""
	request_layout()
	refresh()
	focus_first()

## Deep link (alerta de Ritual, Event Center): abre direto no detalhe da rota.
func show_detail(key: String) -> void:
	current_detail = key
	request_layout()
	if is_visible_in_tree():
		refresh()

func preferred_frame_height() -> float:
	return 390.0 if current_detail.is_empty() else 480.0

func _rebuild() -> void:
	ContextUI.clear(_body)
	summary_cards.clear()
	var player := GameManager.human_player
	_back_button.visible = not current_detail.is_empty()
	if player == null:
		_body.add_child(ContextUI.empty_state("Nenhuma partida em andamento."))
		return
	if current_detail.is_empty():
		_render_summary(player)
	else:
		_render_detail(VictoryPresenter.detail(player, current_detail))

func focus_first() -> void:
	if not current_detail.is_empty() and _back_button != null:
		call_deferred("_focus_if_valid", _back_button)
		return
	var first: Control = summary_cards.get(VictoryPresenter.DOMINATION, null)
	if first != null:
		call_deferred("_focus_if_valid", first.get_node("Content/DetailsButton") as Control)
	else:
		super.focus_first()

func _focus_if_valid(control: Control) -> void:
	if control != null and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func _render_summary(player: PlayerData) -> void:
	set_titles("Vitória", "Três rotas; a primeira condição cumprida encerra a partida.")
	var grid := GridContainer.new()
	grid.name = "SummaryGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_3)
	_body.add_child(grid)
	for card_data in VictoryPresenter.summary(player):
		grid.add_child(_summary_card(card_data))
	var threats := VictoryPresenter.rival_public_rituals(player)
	if not threats.is_empty():
		var section := ContextUI.section("Ameaças públicas")
		_body.add_child(section)
		for ritual in threats:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
			var text := ContextUI.label("%s conduz o Ritual Final — %d rodada(s) restante(s)." % [ritual.owner_name, int(ritual.remaining_rounds)], UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_CRITICAL)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var coord: Vector2i = ritual.site_coord
			var go := AEButton.new()
			go.kind = AEButton.Kind.GHOST
			go.text = "Ir para o local"
			go.pressed.connect(func(): ritual_location_requested.emit(coord))
			row.add_child(go)
			section.add_child(row)

func _summary_card(data: Dictionary) -> Control:
	var threat := String(data.threat) != ""
	var card := ContextUI.card(UIThemeTokens.COLOR_CRITICAL if threat else UIThemeTokens.COLOR_BORDER, UIThemeTokens.COLOR_SURFACE)
	card.name = "Card_" + String(data.key)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 210)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	card.add_child(box)
	var title := ContextUI.label(String(data.title), UIThemeTokens.FONT_H3, UIThemeTokens.COLOR_TEXT, false)
	title.name = "RouteTitle"
	box.add_child(title)
	var state := ContextUI.chip(String(data.state).to_upper(), AEStatusChip.Tone.POSITIVE if String(data.state) in ["Concluída", "Ritual ativo", "Acesso liberado"] else AEStatusChip.Tone.TRAIT)
	state.name = "StateChip"
	state.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(state)
	var bar := AESegmentedBar.new()
	bar.name = "Progress"
	box.add_child(bar)
	bar.set_segments(data.segments, 12.0)
	var progress := ContextUI.label(String(data.progress_text), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT)
	progress.name = "ProgressText"
	box.add_child(progress)
	var next := ContextUI.label(String(data.next), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED)
	next.name = "NextRequirement"
	box.add_child(next)
	if threat:
		var threat_label := ContextUI.label(String(data.threat), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_CRITICAL)
		threat_label.name = "Threat"
		box.add_child(threat_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var details := AEButton.new()
	details.name = "DetailsButton"
	details.kind = AEButton.Kind.SECONDARY
	details.text = "Detalhes"
	var key := String(data.key)
	details.pressed.connect(func(): show_detail(key))
	box.add_child(details)
	summary_cards[key] = card
	return card

func _render_detail(data: Dictionary) -> void:
	set_titles("Vitória — %s" % data.title, "Requisitos, rivais e regras desta rota.")
	var checklist := ContextUI.section("Requisitos")
	checklist.name = "Checklist"
	_body.add_child(checklist)
	for row in data.checklist:
		checklist.add_child(_check_row(row))
	for section_data in data.sections:
		var section := ContextUI.section(String(section_data.title))
		_body.add_child(section)
		for row in section_data.rows:
			section.add_child(_check_row(row))
	var how := ContextUI.section("Como vencer")
	how.name = "HowToWin"
	_body.add_child(how)
	for line in data.how_to:
		how.add_child(ContextUI.label("· " + String(line), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT_MUTED))

func _check_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	var done := bool(row.get("done", false))
	var critical := String(row.get("tone", "")) == "critical"
	var mark := ContextUI.label("●" if done else "○", UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_SUCCESS if done else (UIThemeTokens.COLOR_CRITICAL if critical else UIThemeTokens.COLOR_TEXT_MUTED), false)
	mark.custom_minimum_size.x = 18
	line.add_child(mark)
	var label := ContextUI.label(String(row.label), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false)
	label.custom_minimum_size.x = 280
	line.add_child(label)
	var status := ContextUI.label(String(row.status), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_SUCCESS if done else (UIThemeTokens.COLOR_CRITICAL if critical else UIThemeTokens.COLOR_TEXT_MUTED))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(status)
	return line
