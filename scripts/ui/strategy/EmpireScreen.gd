class_name EmpireScreen
extends StrategyScreen

## Tela estratégica IMPÉRIO (Fase 30 / UI-3): uma única tela com abas Visão geral,
## Cidades e Unidades — Empire Overview, City List e Unit List sem fragmentar a
## navegação. Responde "o que meu reino possui e onde preciso olhar?"; cada bloco
## leva à superfície onde a decisão acontece. Construída só quando aberta.

signal city_requested(city: City)
signal unit_requested(unit: Unit)
signal destination_requested(destination: StringName)
signal attention_requested(item: AttentionItem)
signal victory_detail_requested(detail: String)

const UNIT_FILTERS := [
	{"key": EmpirePresenter.FILTER_ALL, "label": "Todas"},
	{"key": EmpirePresenter.FILTER_MILITARY, "label": "Militares"},
	{"key": EmpirePresenter.FILTER_CASTER, "label": "Conjuradores"},
	{"key": EmpirePresenter.FILTER_SPECIAL, "label": "Especiais"},
]
const CITY_SORTS := [
	{"key": EmpirePresenter.SORT_ATTENTION, "label": "Atenção"},
	{"key": EmpirePresenter.SORT_NAME, "label": "Nome"},
	{"key": EmpirePresenter.SORT_LEVEL, "label": "Nível"},
	{"key": EmpirePresenter.SORT_PRODUCTION, "label": "Produção"},
]

var tabs: AETabStrip
var current_tab := "overview"
var city_sort := EmpirePresenter.SORT_ATTENTION
var unit_filter := EmpirePresenter.FILTER_ALL
var attention_source: AttentionService
var city_row_buttons: Array[Button] = []
var unit_row_buttons: Array[Button] = []
var overview_data: Dictionary = {}
var _scroll: ScrollContainer
var _body: VBoxContainer

func _ready() -> void:
	name = "EmpireScreen"
	super._ready()
	set_titles("Império", "O que o seu reino possui e onde é preciso olhar.")
	tabs = AETabStrip.new()
	tabs.name = "EmpireTabs"
	tabs.custom_minimum_size.x = 420
	content.add_child(tabs)
	tabs.tab_selected.connect(_on_tab_selected)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	_scroll.add_child(_body)

func open_tab(tab: String, filter: String = "") -> void:
	current_tab = tab
	if not filter.is_empty():
		unit_filter = filter
	if is_visible_in_tree():
		refresh()

func _rebuild() -> void:
	var player := GameManager.human_player
	var city_count := player.cities.size() if player != null else 0
	var unit_count := player.units.size() if player != null else 0
	tabs.set_tabs([
		{"key": "overview", "label": "Visão geral"},
		{"key": "cities", "label": "Cidades %d" % city_count},
		{"key": "units", "label": "Unidades %d" % unit_count},
	])
	tabs.select(current_tab)
	ContextUI.clear(_body)
	city_row_buttons.clear()
	unit_row_buttons.clear()
	if player == null:
		_body.add_child(ContextUI.empty_state("Nenhuma partida em andamento."))
		return
	match current_tab:
		"cities":
			_render_cities(player)
		"units":
			_render_units(player)
		_:
			_render_overview(player)

func focus_first() -> void:
	var button := tabs.button_for(current_tab) if tabs != null else null
	if button != null:
		button.call_deferred("grab_focus")
	else:
		super.focus_first()

func _on_tab_selected(key: String) -> void:
	current_tab = key
	request_layout()
	refresh()

func preferred_frame_height() -> float:
	return 560.0 if current_tab == "overview" else 760.0

# --- Visão geral ---------------------------------------------------------------------

func _render_overview(player: PlayerData) -> void:
	overview_data = EmpirePresenter.overview(player, attention_source.items() if attention_source != null else [])
	var grid := GridContainer.new()
	grid.name = "OverviewGrid"
	grid.columns = 2 if is_compact() else 3
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_3)
	grid.add_theme_constant_override("v_separation", UIThemeTokens.SPACE_3)
	_body.add_child(grid)
	var resources: Dictionary = overview_data.resources
	var economy := _block(grid, "Economia", UIThemeTokens.COLOR_CRITICAL if resources.deficit or resources.tension else UIThemeTokens.COLOR_BORDER)
	economy.add_child(ContextUI.key_value("Ouro", "%d (%+d/turno)" % [resources.gold, resources.gold_net], "critical" if resources.deficit else ("warning" if int(resources.gold_net) < 0 else "")))
	economy.add_child(ContextUI.key_value("Mana", "%d (+%d/turno)" % [resources.mana, resources.mana_income]))
	economy.add_child(ContextUI.key_value("Conhecimento", "+%d/turno" % resources.knowledge_income))
	economy.add_child(ContextUI.key_value("Suprimentos", "%d / %d" % [resources.supply_used, resources.supply_capacity], "critical" if resources.tension else ""))
	var flags := ContextUI.flow()
	if resources.deficit:
		flags.add_child(ContextUI.chip("Déficit", AEStatusChip.Tone.NEGATIVE, -1, AETooltip.compose("Déficit de Ouro", "Prédios com manutenção operam a 50%.")))
	if resources.tension:
		flags.add_child(ContextUI.chip("Tensão Logística", AEStatusChip.Tone.NEGATIVE, -1, AETooltip.compose("Tensão Logística", "-15% Ataque e Defesa das unidades com custo de Suprimentos.")))
	if flags.get_child_count() > 0:
		economy.add_child(flags)
	var cities: Dictionary = overview_data.cities
	var city_block := _block(grid, "Cidades · %d" % cities.count, UIThemeTokens.COLOR_ACCENT if int(cities.idle) > 0 else UIThemeTokens.COLOR_BORDER)
	city_block.add_child(ContextUI.key_value("Ociosas", str(cities.idle), "warning" if int(cities.idle) > 0 else "muted"))
	city_block.add_child(ContextUI.key_value("Aguardando Mana", str(cities.waiting_mana), "warning" if int(cities.waiting_mana) > 0 else "muted"))
	city_block.add_child(ContextUI.key_value("Ameaçadas", str(cities.threatened), "critical" if int(cities.threatened) > 0 else "muted"))
	city_block.add_child(_link("Ver cidades", func(): open_tab("cities"), "OverviewCitiesLink"))
	var units: Dictionary = overview_data.units
	var unit_block := _block(grid, "Exército · %d" % units.count, UIThemeTokens.COLOR_CRITICAL if int(units.uncommanded) > 0 else UIThemeTokens.COLOR_BORDER)
	unit_block.add_child(ContextUI.key_value("Militares", str(units.military)))
	unit_block.add_child(ContextUI.key_value("Conjuradores", str(units.caster)))
	unit_block.add_child(ContextUI.key_value("Especiais", str(units.special)))
	unit_block.add_child(ContextUI.key_value("Podem agir", str(units.ready), "success" if int(units.ready) > 0 else "muted"))
	if int(units.uncommanded) > 0:
		unit_block.add_child(ContextUI.key_value("Sem comando", str(units.uncommanded), "critical"))
		unit_block.add_child(_link("Ver Hostes sem comando", func(): open_tab("units", EmpirePresenter.FILTER_SPECIAL), "OverviewRetinueLink"))
	else:
		unit_block.add_child(_link("Ver unidades", func(): open_tab("units"), "OverviewUnitsLink"))
	var research: Dictionary = overview_data.research
	var research_block := _block(grid, "Pesquisa", UIThemeTokens.COLOR_INFO if research.active else UIThemeTokens.COLOR_ACCENT)
	research_block.add_child(ContextUI.label(String(research.name), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT if research.active else UIThemeTokens.COLOR_ACCENT))
	if research.active:
		research_block.add_child(ContextUI.meter("Progresso", float(research.ratio) * 100.0, 100.0, UIThemeTokens.COLOR_INFO, "%d%%" % int(round(float(research.ratio) * 100.0)), 8.0))
	research_block.add_child(_link("Abrir Pesquisa" if research.active else "Escolher Pesquisa", func(): destination_requested.emit(NavigationManager.RESEARCH), "OverviewResearchLink"))
	var wars: Array = overview_data.wars
	var diplomacy_block := _block(grid, "Diplomacia", UIThemeTokens.COLOR_CRITICAL if not wars.is_empty() else UIThemeTokens.COLOR_BORDER)
	if wars.is_empty():
		diplomacy_block.add_child(ContextUI.label("Em paz com todas as civilizações.", UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_SUCCESS))
	else:
		diplomacy_block.add_child(ContextUI.label("Em guerra com: %s" % ", ".join(wars), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_CRITICAL))
	diplomacy_block.add_child(_link("Abrir Diplomacia", func(): destination_requested.emit(NavigationManager.DIPLOMACY), "OverviewDiplomacyLink"))
	var victory: Dictionary = overview_data.victory
	var victory_block := _block(grid, "Vitória", UIThemeTokens.COLOR_CRITICAL if victory.get("tone", "") == "critical" else UIThemeTokens.COLOR_BORDER)
	if victory.is_empty():
		victory_block.add_child(ContextUI.label("Nenhuma rota de vitória em estado crítico.", UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT_MUTED))
		victory_block.add_child(_link("Ver progresso", func(): destination_requested.emit(NavigationManager.VICTORY), "OverviewVictoryLink"))
	else:
		victory_block.add_child(ContextUI.label(String(victory.text), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_CRITICAL if victory.tone == "critical" else UIThemeTokens.COLOR_SUCCESS))
		var detail := String(victory.detail)
		victory_block.add_child(_link("Ver detalhes", func(): victory_detail_requested.emit(detail), "OverviewVictoryLink"))
	var warnings: Array = overview_data.warnings
	var attention := ContextUI.section("Onde olhar agora", "%d" % warnings.size())
	attention.name = "AttentionList"
	_body.add_child(attention)
	if warnings.is_empty():
		attention.add_child(ContextUI.empty_state("Nenhuma pendência ou alerta ativo."))
	for warning in warnings.slice(0, 6):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
		var chip := ContextUI.chip("Obrigatório" if warning.required else "Alerta", AEStatusChip.Tone.WARNING if warning.required else AEStatusChip.Tone.NEGATIVE)
		row.add_child(chip)
		var text := ContextUI.label("%s — %s" % [warning.title, warning.description], UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var item: AttentionItem = warning.item
		var action := AEButton.new()
		action.kind = AEButton.Kind.GHOST
		action.text = String(warning.label)
		action.pressed.connect(func(): attention_requested.emit(item))
		row.add_child(action)
		attention.add_child(row)

func _block(parent: Control, title: String, accent: Color) -> VBoxContainer:
	var card := ContextUI.card(accent, UIThemeTokens.COLOR_SURFACE)
	card.name = "Block_" + title.get_slice(" ", 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 150
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	card.add_child(box)
	var heading := ContextUI.label(title.to_upper(), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_ACCENT, false)
	box.add_child(heading)
	return box

func _link(text: String, callback: Callable, node_name: String = "") -> AEButton:
	var button := AEButton.new()
	if not node_name.is_empty():
		button.name = node_name
	button.kind = AEButton.Kind.GHOST
	button.text = text + "  →"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(callback)
	return button

# --- Cidades -------------------------------------------------------------------------

func _render_cities(player: PlayerData) -> void:
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	_body.add_child(controls)
	controls.add_child(_control_label("Ordenar por"))
	var sorts := AETabStrip.new()
	sorts.name = "CitySorts"
	sorts.custom_minimum_size.x = 420
	controls.add_child(sorts)
	sorts.set_tabs(CITY_SORTS)
	sorts.select(city_sort)
	sorts.tab_selected.connect(func(key: String): city_sort = key; refresh())
	var rows := EmpirePresenter.city_rows(player, city_sort)
	if rows.is_empty():
		_body.add_child(ContextUI.empty_state("Nenhuma cidade. Funde uma com um Colonizador."))
		return
	var list := VBoxContainer.new()
	list.name = "CityList"
	list.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	_body.add_child(list)
	for row in rows:
		list.add_child(_city_row(row))

func _city_row(row: Dictionary) -> Control:
	var button := _row_button("CityRow_%s" % String(row.name).validate_node_name())
	var city: City = row.city
	button.pressed.connect(func(): city_requested.emit(city))
	var line: HBoxContainer = button.get_node("Line")
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 220
	identity.add_theme_constant_override("separation", 0)
	line.add_child(identity)
	identity.add_child(ContextUI.label(String(row.name), UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_TEXT, false))
	identity.add_child(ContextUI.caption("%s%s" % [row.level_name, " · %s" % row.fortification if String(row.fortification) != "" else ""]))
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 170
	line.add_child(vitals)
	vitals.add_child(ContextUI.meter("Vida", row.hp, row.max_hp, ContextUI.hp_color(row.hp, row.max_hp), "", 6.0))
	var production := VBoxContainer.new()
	production.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	production.add_theme_constant_override("separation", 0)
	line.add_child(production)
	var idle := String(row.production_state) == "idle"
	production.add_child(ContextUI.label("Sem produção — escolher" if idle else String(row.production_name), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_ACCENT if idle else UIThemeTokens.COLOR_TEXT, false))
	if not idle:
		production.add_child(ContextUI.caption(String(row.production_eta)))
	var alerts := ContextUI.flow()
	alerts.custom_minimum_size.x = 150
	line.add_child(alerts)
	for alert in row.alerts:
		var tone := AEStatusChip.Tone.WARNING
		if alert == "Ameaçada":
			tone = AEStatusChip.Tone.NEGATIVE
		elif alert == "Ritual":
			tone = AEStatusChip.Tone.NEUTRAL
		alerts.add_child(ContextUI.chip(alert, tone))
	_ignore_mouse(line)
	city_row_buttons.append(button)
	return button

# --- Unidades ------------------------------------------------------------------------

func _render_units(player: PlayerData) -> void:
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	_body.add_child(controls)
	controls.add_child(_control_label("Filtrar"))
	var filters := AETabStrip.new()
	filters.name = "UnitFilters"
	filters.custom_minimum_size.x = 460
	controls.add_child(filters)
	var entries: Array = []
	for entry in UNIT_FILTERS:
		entries.append({"key": entry.key, "label": "%s %d" % [entry.label, EmpirePresenter.unit_rows(player, entry.key).size()]})
	filters.set_tabs(entries)
	filters.select(unit_filter)
	filters.tab_selected.connect(func(key: String): unit_filter = key; refresh())
	var rows := EmpirePresenter.unit_rows(player, unit_filter)
	if rows.is_empty():
		_body.add_child(ContextUI.empty_state("Nenhuma unidade neste filtro."))
		return
	var list := VBoxContainer.new()
	list.name = "UnitList"
	list.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	_body.add_child(list)
	for row in rows:
		list.add_child(_unit_row(row))

func _unit_row(row: Dictionary) -> Control:
	var button := _row_button("UnitRow_%d" % int(row.serial_id))
	var unit: Unit = row.unit
	button.pressed.connect(func(): unit_requested.emit(unit))
	var line: HBoxContainer = button.get_node("Line")
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 250
	identity.add_theme_constant_override("separation", 0)
	line.add_child(identity)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	identity.add_child(name_row)
	name_row.add_child(ContextUI.label(String(row.name), UIThemeTokens.FONT_BODY, UIThemeTokens.COLOR_TEXT, false))
	if String(row.badge) != "":
		name_row.add_child(ContextUI.chip(String(row.badge), AEStatusChip.Tone.WARNING if row.badge != "Hoste" else AEStatusChip.Tone.NEUTRAL))
	identity.add_child(ContextUI.caption(String(row.role)))
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 150
	line.add_child(vitals)
	vitals.add_child(ContextUI.meter("Vida", row.hp, row.max_hp, ContextUI.hp_color(row.hp, row.max_hp), "", 6.0))
	var action := VBoxContainer.new()
	action.custom_minimum_size.x = 150
	action.add_theme_constant_override("separation", 0)
	line.add_child(action)
	action.add_child(ContextUI.label("Pode agir" if row.can_act else "Sem ação", UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_SUCCESS if row.can_act else UIThemeTokens.COLOR_TEXT_MUTED, false))
	action.add_child(ContextUI.caption("Mov. %s/%s" % [_number(row.movement), _number(row.max_movement)]))
	var location := ContextUI.label(String(row.location), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT_MUTED, false)
	location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(location)
	var extras := ContextUI.flow()
	extras.custom_minimum_size.x = 170
	line.add_child(extras)
	if String(row.status) != "":
		extras.add_child(ContextUI.chip(String(row.status), AEStatusChip.Tone.NEGATIVE if row.uncommanded else AEStatusChip.Tone.NEUTRAL))
	if int(row.charges) >= 0:
		extras.add_child(ContextUI.chip("%d carga%s" % [int(row.charges), "" if int(row.charges) == 1 else "s"], AEStatusChip.Tone.TRAIT))
	if row.upgrade:
		extras.add_child(ContextUI.chip("Upgrade", AEStatusChip.Tone.POSITIVE, -1, AETooltip.compose("Upgrade disponível", "Evolua na cidade com o Salão da linha.")))
	_ignore_mouse(line)
	unit_row_buttons.append(button)
	return button

func _control_label(text: String) -> Label:
	var value := ContextUI.label(text, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED, false)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return value

func _row_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"SecondaryButton"
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = UIThemeTokens.SPACE_3
	line.offset_right = -UIThemeTokens.SPACE_3
	line.add_theme_constant_override("separation", UIThemeTokens.SPACE_4)
	button.add_child(line)
	return button

## A linha inteira é UM botão (foco, Enter, clique); filhos não podem roubar o clique.
static func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
