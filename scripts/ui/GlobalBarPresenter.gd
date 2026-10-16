class_name GlobalBarPresenter
extends PanelContainer

signal navigation_requested(destination: StringName)
signal city_summary_requested
## Fase 33D2: chip estratégico com alvo no mapa (objetivo do mundo).
signal location_requested(coord: Vector2i)
signal event_center_requested

const RESOURCE_GLYPHS := {
	"gold": "◆", "supply": "▣", "mana": "✦", "knowledge": "◇",
	"cities": "⌂", "units": "♟",
}
const BAR_THEME := preload("res://scripts/ui/GlobalBarTheme.gd")
const RESOURCE_NAMES := {"gold":"Ouro", "supply":"Suprimentos", "mana":"Mana", "knowledge":"Conhecimento", "cities":"Cidades", "units":"Unidades"}
const NAV_ICONS := {"ResearchButton":"research", "EmpireButton":"empire", "DiplomacyButton":"diplomacy", "VictoryButton":"victory", "EventCenterButton":"events"}

var resource_row: HBoxContainer
var navigation_row: HBoxContainer
var research_status: ResearchStatusWidget
var strategic_alerts: StrategicAlertPresenter
var event_button: AEButton
var event_badge: AEBadge
var _labels: Dictionary = {}
var _glyphs: Dictionary = {}
var _icons: Dictionary = {}
var _items: Dictionary = {}
var _compact := false
var _last_snapshot: Dictionary = {}
## Estado de pesquisa cujo Conhecimento guardado a barra está mostrando (o do jogador do último refresh).
var _bound_research: V2ResearchState
var _captions: Dictionary = {}
var _margin: MarginContainer
var _row: HBoxContainer
var _more_menu: MenuButton
var _turn_crest: TextureRect
var _scale := 1.0
var _requested_compact := false
var _layout_mode := -1
var _presentation_queued := false
var _research_focus: Control

func _ready() -> void:
	_scale = Settings.ui_scale_percent / 100.0
	theme = BAR_THEME.build(_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# A barra e uma faixa continua de 56 px. O StyleBox de paineis comuns tem
	# 8 px de margem interna em cada lado; aqui o proprio MarginContainer ja
	# fornece o respiro necessario, evitando que o chrome cresca para 72+ px.
	var bar_style := BAR_THEME.surface()
	bar_style.content_margin_top = 0.0
	bar_style.content_margin_bottom = 0.0
	bar_style.content_margin_left = 0.0
	bar_style.content_margin_right = 0.0
	add_theme_stylebox_override("panel", bar_style)
	custom_minimum_size.y = UIThemeTokens.GLOBAL_BAR_HEIGHT
	_build()
	_apply_pixel_styles()
	resized.connect(_queue_presentation)
	Settings.accessibility_changed.connect(_on_accessibility_changed)
	if not TurnManager.turn_changed.is_connected(_on_turn_changed):
		TurnManager.turn_changed.connect(_on_turn_changed)
	if not EventBus.fog_updated.is_connected(_on_world_changed):
		EventBus.fog_updated.connect(_on_world_changed)
	if not EventBus.world_phase_changed.is_connected(_on_world_phase_changed):
		EventBus.world_phase_changed.connect(_on_world_phase_changed)
	# V3 / Etapa 2: a primeira cidade libera a pesquisa — o widget atualiza na hora.
	if not EventBus.city_founded.is_connected(_on_city_founded):
		EventBus.city_founded.connect(_on_city_founded)
	if not EventBus.notify.is_connected(_on_legacy_changed):
		EventBus.notify.connect(_on_legacy_changed)
	if UIEvents != null and not UIEvents.event_published.is_connected(_on_structured_event):
		UIEvents.event_published.connect(_on_structured_event)
	if UIEvents != null and not UIEvents.unread_changed.is_connected(_on_unread_changed):
		UIEvents.unread_changed.connect(_on_unread_changed)
	refresh()

func _build() -> void:
	if resource_row != null:
		return
	var margin := MarginContainer.new()
	_margin = margin
	margin.name = "BarPadding"
	margin.add_theme_constant_override("margin_left", UIThemeTokens.SPACE_3)
	margin.add_theme_constant_override("margin_right", UIThemeTokens.SPACE_3)
	margin.add_theme_constant_override("margin_top", UIThemeTokens.SPACE_1)
	margin.add_theme_constant_override("margin_bottom", UIThemeTokens.SPACE_1)
	add_child(margin)
	var row := HBoxContainer.new()
	_row = row
	row.name = "BarRow"
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	margin.add_child(row)

	var turn_region := HBoxContainer.new()
	turn_region.name = "TurnRegion"
	turn_region.custom_minimum_size.x = 70
	turn_region.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(turn_region)
	_turn_crest = TextureRect.new()
	_turn_crest.texture = load("res://assets/ui/title_menu/crest.svg")
	_turn_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_turn_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_turn_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_region.add_child(_turn_crest)
	var turn_texts := VBoxContainer.new()
	turn_texts.add_theme_constant_override("separation", 0)
	turn_region.add_child(turn_texts)
	var caption := _resource_caption("Turno / era")
	caption.name = "TurnCaption"
	turn_texts.add_child(caption)
	var turn_label := Label.new()
	turn_label.name = "TurnLabel"
	turn_label.theme_type_variation = &"CaptionLabel"
	turn_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_ACCENT)
	turn_label.mouse_filter = Control.MOUSE_FILTER_PASS # tooltip com o nome completo da era
	turn_texts.add_child(turn_label)
	_labels.turn = turn_label
	row.add_child(_separator())

	resource_row = HBoxContainer.new()
	resource_row.name = "Resources"
	resource_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	row.add_child(resource_row)
	for key in ["gold", "supply", "mana", "knowledge", "cities", "units"]:
		_add_resource(key)
		if key != "units":
			resource_row.add_child(_separator())

	research_status = ResearchStatusWidget.new()
	research_status.name = "ResearchStatus"
	research_status.pressed.connect(func(): navigation_requested.emit(NavigationManager.RESEARCH))
	row.add_child(research_status)
	strategic_alerts = StrategicAlertPresenter.new()
	strategic_alerts.name = "StrategicAlerts"
	strategic_alerts.destination_requested.connect(_on_strategic_destination)
	strategic_alerts.location_requested.connect(func(coord: Vector2i): location_requested.emit(coord))
	row.add_child(strategic_alerts)
	row.add_child(_separator())

	navigation_row = HBoxContainer.new()
	navigation_row.name = "Navigation"
	navigation_row.add_theme_constant_override("separation", 4)
	row.add_child(navigation_row)
	_add_nav("ResearchButton", "Pesquisa", "P", NavigationManager.RESEARCH)
	_add_nav("EmpireButton", "Império", "I", NavigationManager.EMPIRE)
	_add_nav("DiplomacyButton", "Diplomacia", "D", NavigationManager.DIPLOMACY)
	_add_nav("VictoryButton", "Vitória", "V", NavigationManager.VICTORY)
	event_button = AEButton.new()
	event_button.name = "EventCenterButton"
	event_button.kind = AEButton.Kind.GHOST
	event_button.text = "Eventos"
	event_button.tooltip_text = "Central de Eventos"
	event_button.set_meta("full_label", "Eventos")
	event_button.set_meta("compact_label", "E")
	event_button.pressed.connect(func(): event_center_requested.emit())
	navigation_row.add_child(event_button)
	event_badge = AEBadge.new()
	event_badge.name = "EventUnreadBadge"
	event_badge.visible = false
	navigation_row.add_child(event_badge)
	_more_menu = MenuButton.new()
	_more_menu.name = "MoreNavigation"
	_more_menu.icon = BAR_THEME.icon("more")
	_more_menu.theme_type_variation = &"GhostButton"
	_more_menu.flat = false
	_more_menu.focus_mode = Control.FOCUS_ALL
	_more_menu.tooltip_text = "Mais opções e resumo do reino"
	navigation_row.add_child(_more_menu)
	var popup := _more_menu.get_popup()
	for entry in [["Pesquisa",0],["Império",1],["Diplomacia",2],["Vitória",3],["Central de Eventos",4]]:
		popup.add_icon_item(BAR_THEME.icon(["research","empire","diplomacy","victory","events"][entry[1]]), entry[0], entry[1])
	popup.add_separator()
	popup.add_item("Cidades", 5)
	popup.add_item("Unidades", 6)
	popup.id_pressed.connect(_on_more_navigation)

func _resource_caption(text_value: String) -> Label:
	var caption := Label.new()
	caption.text = text_value.to_upper()
	caption.add_theme_font_override("font", BAR_THEME.PIXEL)
	caption.add_theme_font_size_override("font_size", roundi(10 * _scale))
	caption.add_theme_color_override("font_color", Color("b5b6a0"))
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caption

func _separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 1
	separator.custom_minimum_size.y = 28
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_theme_color_override("color", Color(UIThemeTokens.COLOR_BORDER, 0.42))
	return separator

func _add_resource(key: String) -> void:
	var item := HBoxContainer.new()
	item.name = key.capitalize() + "Chip"
	item.custom_minimum_size.y = UIThemeTokens.TARGET_MIN
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	resource_row.add_child(item)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	item.add_child(icon)
	var glyph := Label.new()
	glyph.name = "Glyph"
	glyph.text = String(RESOURCE_GLYPHS.get(key, "•"))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.custom_minimum_size.x = 16
	glyph.theme_type_variation = &"CaptionLabel"
	item.add_child(glyph)
	var label := Label.new()
	label.name = "Value"
	label.theme_type_variation = &"CaptionLabel"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(texts)
	var caption := _resource_caption(RESOURCE_NAMES[key])
	texts.add_child(caption)
	texts.add_child(label)
	_captions[key] = caption
	_labels[key] = label
	_glyphs[key] = glyph
	_icons[key] = icon
	_items[key] = item
	set_resource_icon(key, BAR_THEME.icon(key))
	if key == "cities":
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.gui_input.connect(_on_cities_chip_input)
		item.focus_mode = Control.FOCUS_ALL

func set_resource_icon(key: String, texture: Texture2D) -> void:
	if not _icons.has(key):
		return
	var icon: TextureRect = _icons[key]
	icon.texture = texture
	icon.visible = texture != null
	(_glyphs[key] as Label).visible = texture == null

func _add_nav(node_name: String, full_label: String, compact_label: String, destination: StringName) -> void:
	var button := AEButton.new()
	button.name = node_name
	button.kind = AEButton.Kind.GHOST
	button.text = full_label
	button.tooltip_text = full_label
	button.icon = BAR_THEME.icon(NAV_ICONS[node_name])
	button.set_meta("full_label", full_label)
	button.set_meta("compact_label", compact_label)
	button.pressed.connect(func(): navigation_requested.emit(destination))
	navigation_row.add_child(button)

func build_snapshot(player: PlayerData = GameManager.human_player) -> Dictionary:
	if player == null:
		return {"turn": TurnManager.turn_number, "world_phase": WorldEventManager.world_phase, "gold": 0, "gold_net": 0, "supply_used": 0, "supply_capacity": 0, "mana": 0, "mana_income": 0, "knowledge_banked": 0, "knowledge_income": 0, "cities": 0, "units": 0}
	return {
		"turn": TurnManager.turn_number,
		"world_phase": WorldEventManager.world_phase,
		"gold": int(player.gold),
		"gold_net": int(V2EconomyRuntime.player_gold_net_income(player)),
		"supply_used": V2LogisticsRuntime.player_supply_used(player),
		"supply_capacity": int(V2EconomyRuntime.player_supply_capacity(player)),
		"mana": int(player.mana),
		"mana_income": int(V2EconomyRuntime.player_mana_income(player)),
		# Conhecimento GUARDADO (sem pesquisa ativa, ou sobra de uma concluída): entra inteiro na próxima escolhida.
		"knowledge_banked": int(player.v2_research.research_overflow) if player.v2_research != null else 0,
		"knowledge_income": int(V2EconomyRuntime.player_knowledge_income(player)),
		"cities": player.cities.size(),
		"units": player.units.size(),
	}

func refresh(player: PlayerData = GameManager.human_player) -> void:
	if resource_row == null:
		_build()
	_last_snapshot = build_snapshot(player)
	var s := _last_snapshot
	# Fase 33D1: turno + era do mundo, no mesmo rótulo (prioridade: o número do turno).
	(_labels.turn as Label).text = turn_text(int(s.turn), int(s.world_phase))
	(_labels.turn as Label).tooltip_text = "Turno %d · %s" % [s.turn, WorldPhaseRules.display_name(int(s.world_phase))]
	(_labels.gold as Label).text = "%d  %s" % [s.gold, UIFormat.delta(s.gold_net)]
	(_labels.supply as Label).text = "%d/%d" % [s.supply_used, s.supply_capacity]
	(_labels.mana as Label).text = "%d  %s" % [s.mana, UIFormat.delta(s.mana_income)]
	# Mesmo formato do Ouro e da Mana: o que há acumulado e o que entra por turno (pedido do usuário 2026-10-13:
	# "mostre logo na barra superior onde fica a ciência o acúmulo e a ciência por turno").
	(_labels.knowledge as Label).text = "%d  %s" % [s.knowledge_banked, UIFormat.delta(s.knowledge_income)]
	_bind_research(player)
	(_labels.cities as Label).text = str(s.cities)
	(_labels.units as Label).text = str(s.units)
	_apply_semantic_states(player)
	for key in _items:
		var information := (_items[key] as Control).tooltip_text
		(_items[key] as Control).tooltip_text = "%s: %s\n%s" % [RESOURCE_NAMES[key], (_labels[key] as Label).text, information]
	research_status.bind_player(player)
	strategic_alerts.bind_player(player)
	_on_unread_changed(UIEvents.unread_count() if UIEvents != null else 0)
	_more_menu.get_popup().set_item_text(_more_menu.get_popup().get_item_index(5), "Cidades: %d · resumo de produção" % s.cities)
	_more_menu.get_popup().set_item_text(_more_menu.get_popup().get_item_index(6), "Unidades: %d · abrir Império" % s.units)
	_queue_presentation()

func set_compact(value: bool) -> void:
	_requested_compact = value
	_apply_presentation()

func _on_more_navigation(id: int) -> void:
	match id:
		0: navigation_requested.emit(NavigationManager.RESEARCH)
		1, 6: navigation_requested.emit(NavigationManager.EMPIRE)
		2: navigation_requested.emit(NavigationManager.DIPLOMACY)
		3: navigation_requested.emit(NavigationManager.VICTORY)
		4: event_center_requested.emit()
		5: city_summary_requested.emit()

func _queue_presentation() -> void:
	if not _presentation_queued:
		_presentation_queued = true
		_apply_presentation.call_deferred()

func _apply_presentation() -> void:
	_presentation_queued = false
	if _row == null: return
	var width := size.x if size.x > 0 else get_viewport_rect().size.x
	var logical_width := width / _scale
	var mode := 0 if logical_width >= 1850 else (1 if logical_width >= 1350 else (2 if logical_width >= 1000 else 3))
	if _requested_compact: mode = maxi(mode, 1)
	if mode == _layout_mode: return
	_layout_mode = mode
	var previous_focus := get_viewport().gui_get_focus_owner()
	_compact = mode > 0
	# The four economic resources, including banked Knowledge, stay visible.
	(_items.units as Control).visible = mode < 2
	(_items.cities as Control).visible = mode < 2
	for child in resource_row.get_children():
		if child is VSeparator: child.visible = mode < 2
	for key in _captions:
		(_captions[key] as Label).text = ("Supr." if key == "supply" and mode >= 2 else ("Ciência" if key == "knowledge" and mode >= 2 else RESOURCE_NAMES[key])).to_upper()
		(_labels[key] as Label).add_theme_font_size_override("font_size", roundi((12 if mode >= 2 else 14) * _scale))
	research_status.set_compact(_compact)
	research_status.custom_minimum_size.x = (148 if mode == 3 else (188 if _compact else 250)) * _scale
	strategic_alerts.set_compact(_compact)
	for child in navigation_row.get_children():
		if child is Button and child.has_meta("full_label"):
			child.text = "" if _compact else String(child.get_meta("full_label"))
			child.visible = mode < 2 or (mode == 2 and child.name in ["ResearchButton","EmpireButton"])
	_more_menu.visible = mode >= 2
	if previous_focus != null and is_ancestor_of(previous_focus) and not previous_focus.is_visible_in_tree() and _more_menu.visible:
		_more_menu.call_deferred("grab_focus")
	_turn_crest.visible = mode < 3
	_row.add_theme_constant_override("separation", roundi((6 if mode >= 2 else 12) * _scale))
	resource_row.add_theme_constant_override("separation", roundi((6 if mode >= 2 else 8) * _scale))

func _on_accessibility_changed() -> void:
	var factor := Settings.ui_scale_percent / 100.0
	if is_equal_approx(factor, _scale): return
	_scale = factor
	theme = BAR_THEME.build(_scale)
	_apply_pixel_styles()
	_layout_mode = -1
	_apply_presentation()

func _apply_pixel_styles() -> void:
	for side in ["left","right"]: _margin.add_theme_constant_override("margin_" + side, roundi(12 * _scale))
	for side in ["top","bottom"]: _margin.add_theme_constant_override("margin_" + side, roundi(6 * _scale))
	_turn_crest.custom_minimum_size = Vector2(24,24) * _scale
	(_labels.turn.get_parent().get_node("TurnCaption") as Label).add_theme_font_size_override("font_size", roundi(10 * _scale))
	for caption in _captions.values(): caption.add_theme_font_size_override("font_size", roundi(10 * _scale))
	for key in _icons:
		(_icons[key] as TextureRect).custom_minimum_size = Vector2(20,20) * _scale
		(_items[key] as Control).custom_minimum_size.y = 36 * _scale
	for child in navigation_row.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(36,36) * _scale
			if child.name == "EventCenterButton": child.icon = BAR_THEME.icon("events")
	var research_frame := BAR_THEME.surface()
	# Its own margin supplies the content padding.
	research_status.add_theme_stylebox_override("panel", research_frame)
	if _research_focus == null:
		_research_focus = preload("res://scripts/ui/ResearchCardDecoration.gd").new()
		_research_focus.name = "ResearchFocus"
		_research_focus.padding = 0
		_research_focus.accent = Color("e6bc77")
		research_status.add_child(_research_focus)
	_research_focus.factor = _scale
	_research_focus.queue_redraw()
	research_status.name_label.add_theme_font_override("font", BAR_THEME.PIXEL)
	research_status.name_label.add_theme_font_size_override("font_size", roundi(14 * _scale))
	research_status.name_label.add_theme_color_override("font_color", Color("e6bc77"))
	research_status.name_label.clip_text = true
	research_status.detail_label.clip_text = true
	research_status.progress.add_theme_constant_override("separation", 0)
	research_status.progress.progress_bar.custom_minimum_size.y = 4 * _scale
	research_status.progress.progress_bar.add_theme_stylebox_override("background", BAR_THEME.progress_track(false))
	research_status.progress.progress_bar.add_theme_stylebox_override("fill", BAR_THEME.progress_track(true))
	for badge in [event_badge, research_status.attention_badge]:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("5b4530")
		frame.border_color = Color("e6bc77")
		frame.set_border_width_all(1)
		frame.set_content_margin_all(3 * _scale)
		badge.add_theme_stylebox_override("normal", frame)
		badge.custom_minimum_size = Vector2(18,18) * _scale

static func turn_text(turn: int, phase: int) -> String:
	return "T%d · %s" % [turn, WorldPhaseRules.short_name(phase)]

func _on_world_phase_changed(_old_phase: int, _new_phase: int, _turn: int, _cause: String) -> void:
	refresh()

func _on_city_founded(_player: PlayerData, _city_name: String, _coord: Vector2i) -> void:
	refresh()

func last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate()

func _apply_semantic_states(player: PlayerData) -> void:
	if player == null:
		for key in _items:
			(_items[key] as Control).tooltip_text = RESOURCE_NAMES[key]
			_set_item_color(key, UIThemeTokens.COLOR_TEXT)
		return
	var gold_net := V2EconomyRuntime.player_gold_net_income(player)
	var deficit := V2EconomyRuntime.is_gold_deficit(player)
	_set_item_color("gold", UIThemeTokens.COLOR_CRITICAL if deficit else (UIThemeTokens.COLOR_WARNING if gold_net < 0.0 else UIThemeTokens.COLOR_TEXT))
	(_items.gold as Control).tooltip_text = "Déficit real: renda líquida negativa com tesouro esgotado." if deficit else ("Saldo por turno negativo; o tesouro ainda cobre a diferença." if gold_net < 0.0 else "Tesouro e renda líquida por turno.")
	var used := V2LogisticsRuntime.player_supply_used(player)
	var capacity := int(V2EconomyRuntime.player_supply_capacity(player))
	var tension := V2LogisticsRuntime.is_logistically_strained(player)
	var near_cap := capacity > 0 and float(used) / float(capacity) >= UIThemeTokens.SUPPLY_NEAR_CAP_RATIO
	_set_item_color("supply", UIThemeTokens.COLOR_CRITICAL if tension else (UIThemeTokens.COLOR_WARNING if near_cap else UIThemeTokens.COLOR_TEXT))
	(_items.supply as Control).tooltip_text = "Tensão Logística ativa." if tension else ("Próximo do limite de Suprimentos." if near_cap else "Suprimentos usados / capacidade.")
	var waiting := 0
	var idle := 0
	for city in player.cities:
		if city == null or not is_instance_valid(city) or city.owner_player != player:
			continue
		if city.production_item == "":
			idle += 1
		elif city.stored_production >= city.production_cost() and city.production_waiting_for_mana() > 0:
			waiting += 1
	_set_item_color("mana", UIThemeTokens.COLOR_WARNING if waiting > 0 else UIThemeTokens.COLOR_TEXT)
	(_items.mana as Control).tooltip_text = "%d cidade(s) aguardando Mana." % waiting if waiting > 0 else "Mana disponível e renda por turno."
	_set_item_color("cities", UIThemeTokens.COLOR_ACCENT if idle > 0 else UIThemeTokens.COLOR_TEXT)
	(_items.cities as Control).tooltip_text = "%d cidade(s) sem produção. Clique para abrir o resumo." % idle if idle > 0 else "Cidades. Clique para abrir o resumo de produção."
	(_items.units as Control).tooltip_text = "Unidades sob seu comando."
	(_items.knowledge as Control).tooltip_text = knowledge_tooltip(player)

## Tooltip do chip de Conhecimento: guardado e renda exatos, e para onde a renda está indo.
static func knowledge_tooltip(player: PlayerData) -> String:
	if player == null or player.v2_research == null:
		return "Conhecimento guardado e por turno."
	var research := player.v2_research
	var income := "+%s por turno" % V2ResearchState.format_amount(snappedf(V2EconomyRuntime.player_knowledge_income(player), 0.1))
	if research.research_overflow > 0.0:
		return "Conhecimento guardado: %s · %s.\nO guardado entra inteiro, na hora, na próxima pesquisa que você iniciar." % [V2ResearchState.format_amount(snappedf(research.research_overflow, 0.1)), income]
	if research.active_id != "":
		return "Conhecimento: %s, indo direto para a pesquisa ativa. Nada guardado." % income
	return "Conhecimento: %s. Sem pesquisa ativa, ele fica guardado para a próxima que você iniciar." % income

## A barra acompanha o Conhecimento guardado do jogador exibido: ele muda fora da virada de turno (escolher uma
## pesquisa gasta tudo na hora), então o chip escuta o próprio estado de pesquisa em vez de esperar o próximo turno.
func _bind_research(player: PlayerData) -> void:
	var research: V2ResearchState = player.v2_research if player != null else null
	if research == _bound_research:
		return
	if _bound_research != null:
		_bound_research.research_overflow_changed.disconnect(_on_research_overflow_changed)
		_bound_research.research_selected.disconnect(_on_research_selected)
		_bound_research.research_cancelled.disconnect(_on_research_cancelled)
		_bound_research.research_completed.disconnect(_on_research_cancelled)
		_bound_research.research_progress_changed.disconnect(_on_research_progress_changed)
		_bound_research.state_reset.disconnect(_on_research_changed)
	_bound_research = research
	if research != null:
		research.research_overflow_changed.connect(_on_research_overflow_changed)
		research.research_selected.connect(_on_research_selected)
		research.research_cancelled.connect(_on_research_cancelled)
		research.research_completed.connect(_on_research_cancelled)
		# O guardado é aplicado DEPOIS de research_selected e de research_overflow_changed(0): sem o sinal de progresso o
		# widget de pesquisa ao lado ficaria em "0 / custo" até a próxima virada de turno.
		research.research_progress_changed.connect(_on_research_progress_changed)
		research.state_reset.connect(_on_research_changed)

func _on_research_overflow_changed(_amount: float) -> void:
	_on_research_changed()

func _on_research_selected(_id: String, _previous_id: String) -> void:
	_on_research_changed()

func _on_research_cancelled(_id: String) -> void:
	_on_research_changed()

func _on_research_progress_changed(_id: String, _progress: float, _cost: float) -> void:
	_on_research_changed()

func _on_research_changed() -> void:
	if is_inside_tree():
		refresh()

func _set_item_color(key: String, color: Color) -> void:
	(_labels[key] as Label).add_theme_color_override("font_color", color)
	(_glyphs[key] as Label).add_theme_color_override("font_color", color)

func _on_turn_changed(_turn: int, _index: int) -> void:
	refresh()

func _on_world_changed() -> void:
	refresh()

func _on_legacy_changed(_text: String, _kind: String) -> void:
	refresh()

func _on_structured_event(_event: UIEventData) -> void:
	refresh()

func _on_unread_changed(count: int) -> void:
	if event_badge == null:
		return
	event_badge.visible = count > 0
	event_badge.text = str(count)
	event_badge.tooltip_text = "%d evento(s) não lido(s)" % count
	if _more_menu != null:
		var popup := _more_menu.get_popup()
		popup.set_item_text(popup.get_item_index(4), "Central de Eventos (%d)" % count if count > 0 else "Central de Eventos")

func _on_cities_chip_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
		(_items.cities as Control).accept_event()
		city_summary_requested.emit()

func _on_strategic_destination(destination: StringName) -> void:
	if destination == &"city_summary":
		city_summary_requested.emit()
	else:
		navigation_requested.emit(destination)
