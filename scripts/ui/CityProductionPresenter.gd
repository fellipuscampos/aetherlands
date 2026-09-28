class_name CityProductionPresenter
extends PanelContainer

signal close_requested
signal city_requested(city: City)

enum State { PRODUCING, IDLE, WAITING_MANA }

var rows: VBoxContainer
var title_label: Label
var _player: PlayerData

func _ready() -> void:
	theme_type_variation = &"ElevatedPanel"
	_build()

func bind_player(player: PlayerData) -> void:
	_player = player
	refresh()

func refresh() -> void:
	if rows == null:
		_build()
	for child in rows.get_children():
		rows.remove_child(child)
		child.free()
	if _player == null or _player.cities.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma cidade sob seu controle."
		empty.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		rows.add_child(empty)
		return
	for city in _player.cities:
		if city != null and is_instance_valid(city) and city.owner_player == _player:
			rows.add_child(_make_city_row(city))

func preferred_height() -> float:
	var count := _player.cities.size() if _player != null else 0
	return clampf(150.0 + float(mini(count, 6)) * 104.0, 300.0, 700.0)

## Fase 30: a fonte única do estado de produção é CityPresenter.production_snapshot
## (também usada pelo City Panel novo); aqui só se traduz para o enum do drawer.
func snapshot(city: City) -> Dictionary:
	var data := CityPresenter.production_snapshot(city)
	var state := State.IDLE
	match String(data.state):
		"producing", "waiting_gold":
			state = State.PRODUCING
		"waiting_mana":
			state = State.WAITING_MANA
	return {"state": state, "cost": data.cost, "progress": data.progress, "income": data.income, "eta": data.eta, "item_name": data.item_name, "missing_mana": data.missing_mana}

func _build() -> void:
	if rows != null:
		return
	custom_minimum_size = Vector2(360, 300)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	title_label = Label.new()
	title_label.text = "Produção das Cidades"
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close := AEIconButton.new()
	close.text = "×"
	close.tooltip_text = "Fechar produção das cidades"
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	scroll.add_child(rows)

func _make_city_row(city: City) -> Control:
	var data := snapshot(city)
	var panel := PanelContainer.new()
	var accent := UIThemeTokens.COLOR_INFO
	if data.state == State.IDLE:
		accent = UIThemeTokens.COLOR_ACCENT
	elif data.state == State.WAITING_MANA:
		accent = UIThemeTokens.COLOR_WARNING
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, accent, 1, UIThemeTokens.RADIUS_CONTROL, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var city_label := Label.new()
	city_label.text = "%s · %s" % [city.city_name, V2CityLevelData.level_name(city.city_level)]
	city_label.theme_type_variation = &"CaptionLabel"
	text_box.add_child(city_label)
	var item := Label.new()
	item.text = data.item_name
	item.add_theme_color_override("font_color", accent)
	text_box.add_child(item)
	var detail := Label.new()
	if data.state == State.PRODUCING:
		detail.text = "%s / %s PP · %s" % [_number(data.progress), _number(data.cost), data.eta]
	else:
		detail.text = data.eta
		detail.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
	text_box.add_child(detail)
	if data.state != State.IDLE:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.max_value = maxf(data.cost, 1.0)
		bar.value = data.progress
		text_box.add_child(bar)
	var action := AEButton.new()
	action.kind = AEButton.Kind.PRIMARY if data.state == State.IDLE else AEButton.Kind.GHOST
	action.text = "Escolher" if data.state == State.IDLE else "Ver"
	action.pressed.connect(func(): city_requested.emit(city))
	row.add_child(action)
	return panel

func _number(value: float) -> String:
	return UIFormat.number(value, 1)
