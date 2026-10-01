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

func _ready() -> void:
	theme_type_variation = &"SurfacePanel"
	# A barra e uma faixa continua de 56 px. O StyleBox de paineis comuns tem
	# 8 px de margem interna em cada lado; aqui o proprio MarginContainer ja
	# fornece o respiro necessario, evitando que o chrome cresca para 72+ px.
	var bar_style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_PANEL, false)
	bar_style.content_margin_top = 0.0
	bar_style.content_margin_bottom = 0.0
	bar_style.content_margin_left = 0.0
	bar_style.content_margin_right = 0.0
	add_theme_stylebox_override("panel", bar_style)
	custom_minimum_size.y = UIThemeTokens.GLOBAL_BAR_HEIGHT
	_build()
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
	margin.add_theme_constant_override("margin_left", UIThemeTokens.SPACE_3)
	margin.add_theme_constant_override("margin_right", UIThemeTokens.SPACE_3)
	margin.add_theme_constant_override("margin_top", UIThemeTokens.SPACE_1)
	margin.add_theme_constant_override("margin_bottom", UIThemeTokens.SPACE_1)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	margin.add_child(row)

	var turn_region := HBoxContainer.new()
	turn_region.name = "TurnRegion"
	turn_region.custom_minimum_size.x = 70
	turn_region.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(turn_region)
	var turn_label := Label.new()
	turn_label.name = "TurnLabel"
	turn_label.theme_type_variation = &"CaptionLabel"
	turn_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_ACCENT)
	turn_label.mouse_filter = Control.MOUSE_FILTER_PASS # tooltip com o nome completo da era
	turn_region.add_child(turn_label)
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
	navigation_row.add_theme_constant_override("separation", 0)
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

func _separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 1
	separator.add_theme_color_override("color", Color(UIThemeTokens.COLOR_BORDER, 0.42))
	return separator

func _add_resource(key: String) -> void:
	var item := HBoxContainer.new()
	item.name = key.capitalize() + "Chip"
	item.custom_minimum_size.y = UIThemeTokens.TARGET_MIN
	item.alignment = BoxContainer.ALIGNMENT_CENTER
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
	item.add_child(label)
	_labels[key] = label
	_glyphs[key] = glyph
	_icons[key] = icon
	_items[key] = item
	if key == "cities":
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.gui_input.connect(_on_cities_chip_input)

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
	button.set_meta("full_label", full_label)
	button.set_meta("compact_label", compact_label)
	button.pressed.connect(func(): navigation_requested.emit(destination))
	navigation_row.add_child(button)

func build_snapshot(player: PlayerData = GameManager.human_player) -> Dictionary:
	if player == null:
		return {"turn": TurnManager.turn_number, "world_phase": WorldEventManager.world_phase, "gold": 0, "gold_net": 0, "supply_used": 0, "supply_capacity": 0, "mana": 0, "mana_income": 0, "knowledge_income": 0, "cities": 0, "units": 0}
	return {
		"turn": TurnManager.turn_number,
		"world_phase": WorldEventManager.world_phase,
		"gold": int(player.gold),
		"gold_net": int(V2EconomyRuntime.player_gold_net_income(player)),
		"supply_used": V2LogisticsRuntime.player_supply_used(player),
		"supply_capacity": int(V2EconomyRuntime.player_supply_capacity(player)),
		"mana": int(player.mana),
		"mana_income": int(V2EconomyRuntime.player_mana_income(player)),
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
	(_labels.knowledge as Label).text = UIFormat.delta(s.knowledge_income)
	(_labels.cities as Label).text = str(s.cities)
	(_labels.units as Label).text = str(s.units)
	_apply_semantic_states(player)
	research_status.bind_player(player)
	strategic_alerts.bind_player(player)
	_on_unread_changed(UIEvents.unread_count() if UIEvents != null else 0)

func set_compact(value: bool) -> void:
	if _compact == value:
		return
	_compact = value
	(_items.units as Control).visible = not value
	(_items.knowledge as Control).visible = not value
	research_status.set_compact(value)
	strategic_alerts.set_compact(value)
	for child in navigation_row.get_children():
		if child is Button and child.has_meta("full_label"):
			child.text = String(child.get_meta("compact_label" if value else "full_label"))
	refresh()

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
	(_items.knowledge as Control).tooltip_text = "Conhecimento por turno."

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

func _on_cities_chip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		city_summary_requested.emit()

func _on_strategic_destination(destination: StringName) -> void:
	if destination == &"city_summary":
		city_summary_requested.emit()
	else:
		navigation_requested.emit(destination)
