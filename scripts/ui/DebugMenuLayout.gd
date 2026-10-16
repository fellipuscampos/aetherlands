extends RefCounted

const Chrome := preload("res://scripts/ui/HUDChromeTheme.gd")
const TABS := [["mages","Magos e VFX"],["manifestations","Manifestações"],["ambience","Ambiente"],["match","Partida"]]

## Reuses the live HUD controls and signals; only their presentation changes.
static func build(hud: Control) -> Dictionary:
	var panel: PanelContainer = hud.debug_panel
	var old: Control = hud.debug_force_dragon_button.get_parent()
	var body := VBoxContainer.new()
	body.name = "DebugLayout"
	panel.add_child(body)
	var menu := {"panel":panel,"body":body,"pages":{},"tabs":{},"grids":[],"cards":[],"current":"mages"}
	var header: HBoxContainer = old.get_node("DebugHeader")
	header.reparent(body,false)
	var title: Label = header.get_node("DebugTitleLabel")
	title.text = "Ferramentas de debug"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.debug_close_button.text = "×"
	hud.debug_close_button.tooltip_text = "Fechar ferramentas de debug"
	menu.header = header
	menu.close = hud.debug_close_button
	var subtitle := _label(body,"Invocações, efeitos e controles da partida.","MutedLabel")
	menu.subtitle = subtitle
	var nav := GridContainer.new()
	nav.name = "DebugTabs"
	nav.columns = 4
	body.add_child(nav)
	menu.nav = nav
	var scroll := ScrollContainer.new()
	scroll.name = "DebugScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	menu.scroll = scroll
	var content := VBoxContainer.new()
	content.name = "DebugPages"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	for entry in TABS:
		var page := VBoxContainer.new()
		page.name = String(entry[0]).to_pascal_case()+"Page"
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(page)
		menu.pages[entry[0]] = page
		var tab := Button.new()
		tab.name = "DebugTab_"+String(entry[0])
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_page.bind(menu,String(entry[0])))
		nav.add_child(tab)
		menu.tabs[entry[0]] = tab

	var mages: VBoxContainer = menu.pages.mages
	var invocations := _section(menu,mages,"Invocar magos","Escolha uma escola para criar o conjurador no mapa. Nenhum edifício é necessário.")
	menu.mage_hint = invocations.get_child(1)
	var options := HBoxContainer.new()
	options.name = "DebugMageOptions"
	invocations.add_child(options)
	var count_row: HBoxContainer = old.get_node("DebugMageCountRow")
	(count_row.get_child(0) as Label).text = "Quantidade"
	_move(count_row,options)
	_move(hud._debug_prepare_magic,options)
	menu.mage_options = options
	_move(old.get_node("DebugMageGrid"),invocations)
	menu.grids.append(invocations.get_node("DebugMageGrid"))
	_move(hud._debug_spawn_label,invocations)
	var vfx := _section(menu,mages,"Repetir os testes","Renove o conjurador após lançar uma magia. Para efeitos de cura, prepare uma unidade própria ferida.")
	_grid(menu,vfx,[hud._debug_renew_magic_button,hud._debug_wound_button])
	menu.mage_count = hud._debug_mage_count

	var manifestations: VBoxContainer = menu.pages.manifestations
	var grand := _section(menu,manifestations,"Grandes manifestações","Invocação direta, sem ritual, mana ou limite de uma criatura por escola.")
	_move(old.get_node("DebugSummonCountRow"),grand)
	_move(old.get_node("DebugSummonGrid"),grand)
	menu.grids.append(grand.get_node("DebugSummonGrid"))
	menu.grand_count = hud._debug_summon_count

	var ambience: VBoxContainer = menu.pages.ambience
	var weather := _section(menu,ambience,"Clima","Teste a formação das nuvens, a chuva e a neve. A troca entre climas ocorre com transição suave.")
	_grid(menu,weather,[hud._debug_rain_button,hud._debug_snow_button])
	var lighting := _section(menu,ambience,"Iluminação","Compare os efeitos durante o dia e a noite ou acelere o ciclo. Estes controles respeitam as configurações de vídeo.")
	_grid(menu,lighting,[hud._debug_day_night_button,hud._debug_fast_cycle_button])

	var match: VBoxContainer = menu.pages.match
	var cheats := _section(menu,match,"Mapa e progressão","Modo debug acelera a produção e permite teletransportar a unidade selecionada para tiles livres.")
	_grid(menu,cheats,[hud.debug_mode_button,hud.debug_reveal_map_button,hud.debug_gold_button,hud.debug_complete_research_button])
	var events := _section(menu,match,"Eventos e criaturas","Dispare o evento do dragão ou percorra as espécies presentes no mapa.")
	_grid(menu,events,[hud.debug_force_dragon_button,old.get_node("DebugEcologyButton")])
	var endings := _section(menu,match,"Encerrar a partida","Estes botões abrem imediatamente a tela de vitória ou derrota.","critical")
	_grid(menu,endings,[hud.debug_win_button,hud.debug_lose_button])
	hud.debug_win_button.theme_type_variation = &"DangerButton"
	hud.debug_lose_button.theme_type_variation = &"DangerButton"
	hud.debug_reveal_map_button.text = "Revelar mapa"
	hud.debug_complete_research_button.text = "Completar pesquisa atual"
	hud.debug_force_dragon_button.text = "Forçar evento do dragão"

	var footer_frame := PanelContainer.new()
	footer_frame.name = "DebugAnimationFooter"
	footer_frame.set_meta("debug_tone","neutral")
	menu.cards.append(footer_frame)
	body.add_child(footer_frame)
	var footer := VBoxContainer.new()
	footer_frame.add_child(footer)
	_move(hud._debug_selection_label,footer)
	_move(old.get_node("DebugAnimationRow"),footer)
	for button in hud._debug_animation_buttons.values():
		button.tooltip_text = "Toca apenas o clipe da seleção. Para ver os VFX, feche o painel e lance a magia no mapa."
	menu.footer = footer.get_parent()
	var status := _label(body,"Ferramentas de desenvolvimento","MutedLabel")
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.status = status
	panel.remove_child(old)
	old.queue_free()
	show_page(menu,"mages")
	return menu

static func _label(parent: Node, text: String, variation: String = "Label") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func _section(menu: Dictionary, parent: Node, title: String, hint: String, tone: String = "neutral") -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.name = title.validate_node_name()
	frame.set_meta("debug_tone",tone)
	parent.add_child(frame)
	menu.cards.append(frame)
	var box := VBoxContainer.new()
	frame.add_child(box)
	_label(box,title,"SectionLabel")
	_label(box,hint,"MutedLabel")
	return box

static func _move(control: Control, parent: Node) -> void:
	control.reparent(parent,false)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is Button:
		control.clip_text = true
		control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

static func _grid(menu: Dictionary, parent: Node, controls: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	menu.grids.append(grid)
	for control in controls: _move(control,grid)

static func show_page(menu: Dictionary, id: String) -> void:
	if not menu.pages.has(id): return
	menu.current = id
	for key in menu.pages:
		menu.pages[key].visible = key==id
		menu.tabs[key].set_pressed_no_signal(key==id)
		Chrome.style_tab(menu.tabs[key],key==id,Chrome.factor())
	menu.scroll.scroll_vertical = 0

static func menu_size(screen: Vector2, scale: float) -> Vector2:
	return Vector2(minf(800*scale,maxf(1,screen.x-48)),minf(680*scale,maxf(1,screen.y-72)))

static func fit(menu: Dictionary, screen: Vector2, scale: float) -> void:
	var panel: PanelContainer = menu.panel
	var bounds := menu_size(screen,scale)
	panel.add_theme_stylebox_override("panel",Chrome.panel(scale,"neutral",18))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -bounds.x*.5
	panel.offset_right = bounds.x*.5
	panel.offset_top = -bounds.y*.5
	panel.offset_bottom = bounds.y*.5
	menu.body.add_theme_constant_override("separation",roundi(10*scale))
	menu.subtitle.visible = not (screen.y<=720 and scale>1.25)
	menu.mage_hint.visible = menu.subtitle.visible
	menu.mage_options.add_theme_constant_override("separation",roundi(12*scale))
	menu.nav.columns = 2 if bounds.x<680*scale else 4
	menu.nav.add_theme_constant_override("h_separation",roundi(8*scale))
	menu.nav.add_theme_constant_override("v_separation",roundi(6*scale))
	menu.close.custom_minimum_size = Vector2(38,38)*scale
	for page in menu.pages.values(): page.add_theme_constant_override("separation",roundi(12*scale))
	for grid in menu.grids:
		grid.columns = 1 if bounds.x<520*scale else 2
		grid.add_theme_constant_override("h_separation",roundi(10*scale))
		grid.add_theme_constant_override("v_separation",roundi(8*scale))
	for card in menu.cards:
		card.add_theme_stylebox_override("panel",Chrome.panel(scale,String(card.get_meta("debug_tone")),12))
		card.get_child(0).add_theme_constant_override("separation",roundi(8*scale))
	for button in panel.find_children("*","Button",true,false):
		if button==menu.close or button.get_parent()==menu.nav: continue
		button.custom_minimum_size.y = 42*scale
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	menu.mage_count.custom_minimum_size.x = 100*scale
	menu.grand_count.custom_minimum_size.x = 100*scale
	show_page(menu,String(menu.current))
