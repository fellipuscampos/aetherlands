class_name CityContextPanel
extends VBoxContainer

## Painel de contexto de CIDADE (Fase 30 / UI-3) — substitui o TileInfoPanel de
## cidade. Cabeçalho persistente (nível, dono, Vida/Escudo, estados) + abas
## Visão geral / Produção / Estruturas / Território / Defesa; o Ritual aparece
## só quando relevante. Sem População, Comida, Ciência ou tile trabalhado.
## Ações passam por CityCommands (o mesmo caminho do HUD legado).

signal close_requested

const TABS := [
	{"key": "overview", "label": "Geral"},
	{"key": "production", "label": "Produção"},
	{"key": "structures", "label": "Prédios"},
	{"key": "territory", "label": "Território"},
	{"key": "defense", "label": "Defesa"},
]
const CATALOG_TABS := [
	{"key": "units", "label": "Unidades"},
	{"key": "buildings", "label": "Edifícios"},
	{"key": "projects", "label": "Projetos"},
]

var city: City
var view: Dictionary = {}
var current_tab := "overview"
var catalog_category := "units"
var portrait: AEPortrait
var name_label: Label
var subtitle_label: Label
var badge_flow: HFlowContainer
var vitals: VBoxContainer
var tabs: AETabStrip
var scroll: ScrollContainer
var body: VBoxContainer
var catalog_tabs: AETabStrip
var production_items: Array[AEProductionItem] = []
## Lista do catálogo mantida viva entre renders da aba Produção quando a estrutura
## (categoria, ids e ordem) não muda: itens são atualizados no lugar, sem recriar nós.
var _catalog_list: VBoxContainer
var _catalog_signature := ""
var _catalog_by_id: Dictionary = {}
var action_buttons: Dictionary = {}
var render_count := 0
var _last_key := 0

func _ready() -> void:
	name = "CityContextPanel"
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
	name_label.name = "CityName"
	identity.add_child(name_label)
	subtitle_label = ContextUI.caption("")
	subtitle_label.name = "Subtitle"
	identity.add_child(subtitle_label)
	badge_flow = ContextUI.flow()
	badge_flow.name = "Badges"
	identity.add_child(badge_flow)
	var close := ContextUI.close_button("Fechar cidade")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	vitals = VBoxContainer.new()
	vitals.name = "Vitals"
	vitals.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	add_child(vitals)
	tabs = AETabStrip.new()
	tabs.name = "Tabs"
	add_child(tabs)
	tabs.set_tabs(TABS)
	tabs.tab_selected.connect(_on_tab_selected)
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

func show_city(value: City, tab: String = "") -> void:
	var changed := value != city
	city = value
	if not tab.is_empty():
		current_tab = tab
	elif changed:
		current_tab = "overview"
	refresh()

func is_showing(value: City) -> bool:
	return city != null and is_instance_valid(city) and city == value

func is_valid_context() -> bool:
	return city != null and is_instance_valid(city) and not city.is_queued_for_deletion() and GameManager.hex_grid != null and GameManager.hex_grid.get_city_at(city.coord) == city

func select_tab(key: String) -> void:
	current_tab = key
	refresh()

func refresh() -> void:
	_build_chrome()
	if not is_valid_context():
		view = {"valid": false}
		return
	var built := CityPresenter.build(city, GameManager.human_player, GameManager.hex_grid, current_tab)
	var key := str([built, current_tab, catalog_category]).hash()
	view = built
	if key == _last_key and render_count > 0:
		return
	_last_key = key
	var previous_scroll := scroll.scroll_vertical
	_render_header()
	tabs.visible = view.own
	if not view.own:
		current_tab = "public"
	elif current_tab == "public":
		current_tab = "overview"
	if view.own:
		tabs.select(current_tab)
	_render_body()
	scroll.set_deferred("scroll_vertical", previous_scroll)
	render_count += 1

func _render_header() -> void:
	name_label.text = view.name
	subtitle_label.text = "%s · %s" % [view.level_name, view.owner_name if view.own else "%s (%s)" % [view.owner_name, view.relation]]
	portrait.configure(view.level_roman, UIThemeTokens.COLOR_ACCENT, view.owner_color, "Cidade")
	ContextUI.clear(badge_flow)
	for badge in view.badges:
		badge_flow.add_child(ContextUI.chip(badge.text, badge.tone, -1, badge.get("tooltip", "")))
	badge_flow.visible = not view.badges.is_empty()
	ContextUI.clear(vitals)
	var hp_meter := ContextUI.meter("Vida", view.hp, view.max_hp, ContextUI.hp_color(view.hp, view.max_hp))
	hp_meter.name = "HPMeter"
	vitals.add_child(hp_meter)
	if float(view.max_shield) > 0.0:
		var shield_meter := ContextUI.meter("Escudo · %s" % view.fortification_name, view.shield, view.max_shield, UIThemeTokens.COLOR_INFO)
		shield_meter.name = "ShieldMeter"
		vitals.add_child(shield_meter)

func _render_body() -> void:
	var keep_catalog := current_tab == "production" and _catalog_reusable()
	for child in body.get_children():
		if keep_catalog and child == _catalog_list:
			continue
		body.remove_child(child)
		child.queue_free()
	if not keep_catalog:
		_catalog_list = null
		_catalog_signature = ""
		_catalog_by_id.clear()
		production_items.clear()
	action_buttons.clear()
	match current_tab:
		"production":
			_render_production()
		"structures":
			_render_structures()
		"territory":
			_render_territory()
		"defense":
			_render_defense()
		"public":
			_render_public()
		_:
			_render_overview()

# --- Visão geral -------------------------------------------------------------------

func _render_overview() -> void:
	if view.ritual.get("visible", false):
		body.add_child(_ritual_card())
	body.add_child(_current_production_card(true))
	var outputs := ContextUI.section("Rendimento por turno")
	outputs.name = "Outputs"
	body.add_child(outputs)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	grid.add_theme_constant_override("v_separation", UIThemeTokens.SPACE_1)
	outputs.add_child(grid)
	for output in view.overview.outputs:
		var item := AEStatItem.new()
		item.name = "Output_" + String(output.key)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(item)
		item.set_stat(output.caption, output.value, output.glyph, output.tooltip)
	for cost in view.overview.costs:
		var item := AEStatItem.new()
		item.name = "Cost_" + String(cost.key)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(item)
		item.set_stat(cost.caption, cost.value, cost.glyph, cost.tooltip, UIThemeTokens.COLOR_WARNING if String(cost.value) != "-0 Ouro" else UIThemeTokens.COLOR_TEXT_MUTED)
	var capacity := ContextUI.section("Capacidade")
	body.add_child(capacity)
	capacity.add_child(ContextUI.meter("Slots de prédio", view.overview.slots_used, view.overview.slots_max, UIThemeTokens.COLOR_ACCENT, "%d / %d" % [view.overview.slots_used, view.overview.slots_max], 8.0))
	capacity.add_child(ContextUI.key_value("Território", "%d tiles" % view.overview.territory_tiles))
	capacity.add_child(ContextUI.key_value("Anexação", "%d ponto(s)" % view.overview.annex_points, "success" if int(view.overview.annex_points) > 0 else "muted"))
	body.add_child(_development_card())

func _current_production_card(compact: bool) -> Control:
	var production: Dictionary = view.production
	var accent := UIThemeTokens.COLOR_INFO
	match String(production.state):
		"idle":
			accent = UIThemeTokens.COLOR_ACCENT
		"waiting_mana", "waiting_gold":
			accent = UIThemeTokens.COLOR_WARNING
	var card := ContextUI.card(accent)
	card.name = "CurrentProduction"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	card.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	texts.add_child(ContextUI.caption("PRODUZINDO" if production.state != "idle" else "PRODUÇÃO OCIOSA"))
	var title := ContextUI.label(String(production.item_name), UIThemeTokens.FONT_BODY, accent if production.state == "idle" else UIThemeTokens.COLOR_TEXT)
	title.name = "ProductionName"
	texts.add_child(title)
	if compact:
		var change := AEButton.new()
		change.name = "OpenProductionButton"
		change.kind = AEButton.Kind.PRIMARY if production.state == "idle" else AEButton.Kind.GHOST
		change.text = "Escolher" if production.state == "idle" else "Trocar"
		change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		change.pressed.connect(select_tab.bind("production"))
		row.add_child(change)
		action_buttons["open_production"] = change
	if production.state == "idle":
		box.add_child(ContextUI.caption("Nenhum projeto: a Produção desta cidade está sendo desperdiçada."))
		return card
	box.add_child(ContextUI.meter("%s · %s" % [production.item_type, production.eta], production.progress, production.cost, accent, "%s / %s PP" % [_number(production.progress), _number(production.cost)], 8.0))
	var details: Array[String] = ["+%s PP/turno" % _number(production.income)]
	if float(production.mana_cost) > 0.0:
		details.append("%s Mana na conclusão" % _number(production.mana_cost))
	var detail_label := ContextUI.caption(" · ".join(details))
	box.add_child(detail_label)
	if production.state == "waiting_mana":
		box.add_child(ContextUI.label("Produção concluída; aguardando %d Mana. Nada é perdido." % production.missing_mana, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
	elif production.state == "waiting_gold":
		box.add_child(ContextUI.label("Projeto concluído; aguardando %d Ouro." % production.missing_gold, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
	return card

func _development_card() -> Control:
	var development: Dictionary = view.development
	var box := ContextUI.section("Nível da cidade", String(development.level_name))
	box.name = "Development"
	if bool(development.max):
		box.add_child(ContextUI.caption("Nível máximo alcançado."))
		return box
	var card := ContextUI.card(UIThemeTokens.COLOR_BORDER)
	box.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	card.add_child(content)
	content.add_child(ContextUI.label("Próximo: %s" % development.next_name, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	content.add_child(ContextUI.caption(" · ".join(development.benefits)))
	content.add_child(ContextUI.caption("Custo: %s PP + %s Ouro (Ouro na conclusão)" % [_number(development.pp), _number(development.gold)]))
	var reason := String(development.reason)
	var button := AEButton.new()
	button.name = "CityUpgradeButton"
	button.kind = AEButton.Kind.SECONDARY
	if bool(development.in_progress):
		button.text = "Evolução em andamento"
		button.disabled = true
	else:
		button.text = "Iniciar evolução"
		button.disabled = reason != "" or GameManager.is_turn_processing
	button.tooltip_text = AETooltip.compose("Evoluir para %s" % development.next_name, "Projeto local: usa a produção normal da cidade.", [], reason)
	button.pressed.connect(_on_upgrade_pressed)
	content.add_child(button)
	if reason != "" and not bool(development.in_progress):
		content.add_child(ContextUI.label(reason, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
	action_buttons["city_upgrade"] = button
	return box

func _ritual_card() -> Control:
	var ritual: Dictionary = view.ritual
	var state := String(ritual.get("state", ""))
	var accent := UIThemeTokens.COLOR_TARGETING if state.begins_with("active") else UIThemeTokens.COLOR_BORDER
	var box := ContextUI.section("Ritual de Transcendência")
	box.name = "Ritual"
	var card := ContextUI.card(accent)
	box.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	card.add_child(content)
	if bool(ritual.get("public", false)):
		content.add_child(ContextUI.label("Ritual público ativo nesta cidade.", UIThemeTokens.FONT_BODY_SMALL, accent))
		content.add_child(ContextUI.caption("%d rodada(s) restante(s)." % int(ritual.rounds)))
		return box
	match state:
		"active":
			var rounds := int(ritual.rounds)
			var segments: Array = []
			for index in int(ritual.rounds_required):
				segments.append({"filled": index < int(ritual.rounds_required) - rounds, "color": UIThemeTokens.COLOR_TARGETING})
			var bar := AESegmentedBar.new()
			content.add_child(bar)
			bar.set_segments(segments)
			content.add_child(ContextUI.label("ATIVO — %d rodada(s) restante(s)" % rounds, UIThemeTokens.FONT_BODY_SMALL, accent))
			var cancel := AEButton.new()
			cancel.name = "CancelTranscendenceRitualButton"
			cancel.kind = AEButton.Kind.DANGER
			cancel.text = "Interromper Ritual"
			cancel.disabled = String(ritual.get("reason", "")) != ""
			cancel.tooltip_text = AETooltip.compose("Interromper Ritual", "O progresso e a Mana não serão devolvidos.")
			cancel.pressed.connect(_on_cancel_ritual_pressed)
			content.add_child(cancel)
			action_buttons["cancel_ritual"] = cancel
		"active_elsewhere":
			content.add_child(ContextUI.label("Ritual ativo em %s — %d rodada(s)." % [ritual.site_name, int(ritual.rounds)], UIThemeTokens.FONT_BODY_SMALL, accent))
		_:
			content.add_child(ContextUI.caption("Público: dura %d rodadas e pode ser interrompido. Custa %d Mana (não devolvida)." % [int(ritual.rounds_required), int(ritual.mana_cost)]))
			var start := AEButton.new()
			start.name = "StartTranscendenceRitualButton"
			start.kind = AEButton.Kind.PRIMARY
			start.text = "Iniciar Ritual — %d Mana" % int(ritual.mana_cost)
			var reason := String(ritual.get("reason", ""))
			start.disabled = reason != ""
			start.tooltip_text = AETooltip.compose("Ritual de Transcendência", "Ritual Final público.", [], reason)
			start.pressed.connect(_on_start_ritual_pressed)
			content.add_child(start)
			if reason != "":
				content.add_child(ContextUI.label(reason, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
			action_buttons["start_ritual"] = start
	return box

# --- Produção ----------------------------------------------------------------------

func _catalog_items() -> Array:
	var catalog: Dictionary = view.get("catalog", {})
	if not catalog.has(catalog_category):
		catalog_category = "units"
	return catalog.get(catalog_category, [])

func _catalog_signature_for(items: Array) -> String:
	var parts: PackedStringArray = [catalog_category]
	for item in items:
		parts.append("%s@%s" % [item.id, item.subgroup])
	return "|".join(parts)

func _catalog_reusable() -> bool:
	return _catalog_list != null and is_instance_valid(_catalog_list) and _catalog_list.get_parent() == body and not _catalog_signature.is_empty() and _catalog_signature_for(_catalog_items()) == _catalog_signature

func _render_production() -> void:
	var reuse := _catalog_list != null and is_instance_valid(_catalog_list) and _catalog_list.get_parent() == body
	var card := _current_production_card(false)
	body.add_child(card)
	body.move_child(card, 0)
	var catalog: Dictionary = view.catalog
	catalog_tabs = AETabStrip.new()
	catalog_tabs.name = "CatalogTabs"
	body.add_child(catalog_tabs)
	var entries: Array = []
	for entry in CATALOG_TABS:
		var items: Array = catalog.get(entry.key, [])
		entries.append({"key": entry.key, "label": "%s %d" % [entry.label, items.size()]})
	catalog_tabs.set_tabs(entries)
	if not catalog.has(catalog_category):
		catalog_category = "units"
	catalog_tabs.select(catalog_category)
	catalog_tabs.tab_selected.connect(_on_catalog_selected)
	body.move_child(catalog_tabs, 1)
	var items: Array = _catalog_items()
	if reuse:
		for item in items:
			var existing: AEProductionItem = _catalog_by_id.get(String(item.id), null)
			if existing != null:
				existing.configure(item)
		return
	var list := VBoxContainer.new()
	list.name = "CatalogList"
	list.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	body.add_child(list)
	_catalog_list = list
	_catalog_signature = _catalog_signature_for(items)
	_catalog_by_id.clear()
	production_items.clear()
	if items.is_empty():
		list.add_child(ContextUI.empty_state(_empty_catalog_text(catalog_category)))
		return
	var last_subgroup := ""
	for item in items:
		if String(item.subgroup) != last_subgroup:
			last_subgroup = String(item.subgroup)
			var header := ContextUI.caption(last_subgroup.to_upper())
			header.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
			list.add_child(header)
		var button := AEProductionItem.new()
		button.configure(item)
		list.add_child(button)
		button.item_pressed.connect(_on_item_pressed)
		production_items.append(button)
		_catalog_by_id[String(item.id)] = button

func _empty_catalog_text(category: String) -> String:
	match category:
		"units":
			return "Nenhuma unidade liberada pela pesquisa ainda."
		"buildings":
			return "Nenhum edifício disponível: pesquise Infraestrutura, Doutrinas ou Escolas."
	return "Nenhum projeto disponível agora."

func production_item_for(item_id: String) -> AEProductionItem:
	for button in production_items:
		if String(button.item.get("id", "")) == item_id:
			return button
	return null

# --- Estruturas ------------------------------------------------------------------------

func _render_structures() -> void:
	var data: Dictionary = view.structures
	var summary := ContextUI.section("Prédios", "Manutenção -%s Ouro/t" % _number(data.upkeep_total))
	summary.name = "StructuresSummary"
	body.add_child(summary)
	summary.add_child(ContextUI.meter("Slots usados", data.slots_used, data.slots_max, UIThemeTokens.COLOR_ACCENT, "%d / %d" % [data.slots_used, data.slots_max], 8.0))
	if data.groups.is_empty():
		body.add_child(ContextUI.empty_state("Nenhum prédio construído. Escolha um em Produção › Edifícios."))
		return
	for group in data.groups:
		var section := ContextUI.section(String(group.title))
		body.add_child(section)
		for row in group.rows:
			section.add_child(_structure_row(row))

func _structure_row(row: Dictionary) -> Control:
	var card := ContextUI.card(Color(UIThemeTokens.COLOR_BORDER, 0.6))
	card.name = "Structure_" + String(row.id)
	card.tooltip_text = String(row.tooltip)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	card.add_child(line)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	line.add_child(texts)
	var title := String(row.name)
	if bool(row.repeatable):
		title += "  ×%d" % int(row.count)
	texts.add_child(ContextUI.label(title, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false))
	if String(row.summary) != "":
		texts.add_child(ContextUI.caption(String(row.summary)))
	if bool(row.repeatable):
		line.add_child(ContextUI.chip("%d/%d" % [int(row.count), int(row.max_copies)], AEStatusChip.Tone.TRAIT))
	if float(row.upkeep) > 0.0:
		var upkeep := ContextUI.label("-%s Ouro" % _number(row.upkeep), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING, false)
		upkeep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(upkeep)
	return card

# --- Território ----------------------------------------------------------------------------

func _render_territory() -> void:
	var data: Dictionary = view.territory
	var summary := ContextUI.section("Território")
	body.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	summary.add_child(grid)
	for stat in [["Raio máx.", str(data.radius), "◎"], ["Tiles", str(data.owned_tiles), "■"], ["Anexação", str(data.annex_points), "▲"]]:
		var item := AEStatItem.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(item)
		item.set_stat(stat[0], stat[1], stat[2], AETooltip.compose(stat[0], "Território real da cidade (sem tiles trabalhados)."))
	var annex := AEButton.new()
	annex.name = "AnnexButton"
	annex.kind = AEButton.Kind.PRIMARY if String(data.annex_reason) == "" else AEButton.Kind.SECONDARY
	annex.text = "Anexar território (%d)" % int(data.annex_points)
	annex.disabled = String(data.annex_reason) != ""
	annex.tooltip_text = AETooltip.compose("Anexar território", "Escolha um tile elegível no mapa. ESC cancela.", [], String(data.annex_reason))
	annex.pressed.connect(_on_annex_pressed)
	summary.add_child(annex)
	action_buttons["annex"] = annex
	var resources := ContextUI.section("Recursos no território", "%d" % data.resources.size())
	resources.name = "Resources"
	body.add_child(resources)
	if data.resources.is_empty():
		resources.add_child(ContextUI.empty_state("Nenhum recurso dentro do território."))
		return
	for resource in data.resources:
		var card := ContextUI.card(UIThemeTokens.COLOR_SUCCESS if resource.improved and not resource.pillaged else Color(UIThemeTokens.COLOR_BORDER, 0.6))
		card.tooltip_text = String(resource.tooltip)
		var line := HBoxContainer.new()
		card.add_child(line)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		line.add_child(texts)
		texts.add_child(ContextUI.label(String(resource.name), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false))
		var status := "%s — %s" % [resource.improvement, resource.yield_text] if resource.improved else "Sem melhoria · Construtor: %s" % resource.improvement
		if resource.pillaged:
			status = "Saqueada: sem rendimento por enquanto"
		texts.add_child(ContextUI.caption(status))
		line.add_child(ContextUI.chip("Melhorado" if resource.improved else "Bruto", AEStatusChip.Tone.POSITIVE if resource.improved and not resource.pillaged else AEStatusChip.Tone.TRAIT))
		resources.add_child(card)

# --- Defesa --------------------------------------------------------------------------------

func _render_defense() -> void:
	var defense: Dictionary = view.defense
	var summary := ContextUI.section("Fortificação", String(defense.fortification_name))
	body.add_child(summary)
	summary.add_child(ContextUI.key_value("Defesa urbana", "+%d%%" % int(defense.defense_bonus), "success" if int(defense.defense_bonus) > 0 else "muted"))
	summary.add_child(ContextUI.key_value("Escudo", "%s / %s" % [_number(defense.shield), _number(defense.max_shield)] if float(defense.max_shield) > 0.0 else "Sem escudo"))
	body.add_child(_city_attack_card(defense.attack))
	var projects: Array = view.catalog.get("projects", [])
	for item in projects:
		if String(item.category) == "defense":
			var section := ContextUI.section("Próximo nível de Fortificação")
			body.add_child(section)
			var button := AEProductionItem.new()
			section.add_child(button)
			button.configure(item)
			button.item_pressed.connect(_on_item_pressed)
			production_items.append(button)

func _city_attack_card(attack: Dictionary) -> Control:
	var section := ContextUI.section("Ataque da Cidade")
	section.name = "CityAttack"
	if attack.is_empty():
		section.add_child(ContextUI.empty_state("Requer fortificação (Muralhas I ou superior)."))
		return section
	var card := ContextUI.card(UIThemeTokens.COLOR_CRITICAL if String(attack.reason) == "" else UIThemeTokens.COLOR_BORDER)
	section.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	card.add_child(content)
	content.add_child(ContextUI.key_value("Poder", String(attack.power)))
	content.add_child(ContextUI.key_value("Alcance", str(attack.range)))
	content.add_child(ContextUI.key_value("Disparo", "Usado neste turno" if attack.used else "Disponível (1 por turno)", "muted" if attack.used else "success"))
	if view.own:
		var fire := AEButton.new()
		fire.name = "CityAttackButton"
		fire.kind = AEButton.Kind.DANGER
		fire.text = "Ataque da Cidade — Usado neste turno" if attack.used else "Escolher alvo"
		fire.disabled = String(attack.reason) != ""
		fire.tooltip_text = AETooltip.compose("Ataque da Cidade", "Poder %s | Alcance %d. Sem revide." % [attack.power, int(attack.range)], [], String(attack.reason))
		fire.pressed.connect(_on_city_attack_pressed)
		content.add_child(fire)
		if String(attack.reason) != "" and not attack.used:
			content.add_child(ContextUI.label(String(attack.reason), UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_WARNING))
		action_buttons["city_attack"] = fire
	return section

# --- Cidade rival (somente fatos públicos) ------------------------------------------

func _render_public() -> void:
	var defense: Dictionary = view.defense
	var section := ContextUI.section("Informação pública")
	body.add_child(section)
	section.add_child(ContextUI.key_value("Nível", String(view.level_name)))
	section.add_child(ContextUI.key_value("Fortificação", String(defense.fortification_name)))
	section.add_child(ContextUI.key_value("Defesa urbana", "+%d%%" % int(defense.defense_bonus)))
	if not defense.attack.is_empty():
		section.add_child(ContextUI.key_value("Ataque da Cidade", "Poder %s · Alcance %d" % [defense.attack.power, int(defense.attack.range)]))
	if view.ritual.get("visible", false):
		body.add_child(_ritual_card())
	body.add_child(ContextUI.caption("Produção, prédios e economia de cidades rivais não são visíveis."))

# --- Ações -------------------------------------------------------------------------------

func _on_tab_selected(key: String) -> void:
	# Cada aba pede só as seções que mostra ao presenter.
	select_tab(key)

func _on_catalog_selected(key: String) -> void:
	catalog_category = key
	_last_key = 0
	refresh()

func _on_item_pressed(item_id: String) -> void:
	if not is_valid_context() or not view.own:
		return
	CityCommands.produce(city, item_id)
	refresh()

func _on_upgrade_pressed() -> void:
	if is_valid_context():
		CityCommands.start_city_upgrade(city, V2CityLevelData.next_level(city.city_level))
		refresh()

func _on_city_attack_pressed() -> void:
	if is_valid_context():
		CityCommands.start_city_attack(city)

func _on_annex_pressed() -> void:
	if is_valid_context():
		CityCommands.start_annexation(city)

func _on_start_ritual_pressed() -> void:
	if is_valid_context() and CityCommands.start_ritual(city.owner_player, city):
		refresh()

func _on_cancel_ritual_pressed() -> void:
	if is_valid_context() and CityCommands.cancel_ritual(city.owner_player):
		refresh()

func preferred_height() -> float:
	return INF

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
