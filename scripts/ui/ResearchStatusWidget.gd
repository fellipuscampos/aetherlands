class_name ResearchStatusWidget
extends PanelContainer

signal pressed

var name_label: Label
var detail_label: Label
var progress: AEProgressBar
var attention_badge: AEBadge
var _compact := false
var _player: PlayerData

func _ready() -> void:
	theme_type_variation = &"SurfacePanel"
	var compact_style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_CONTROL, false)
	compact_style.content_margin_top = 0.0
	compact_style.content_margin_bottom = 0.0
	compact_style.content_margin_left = 0.0
	compact_style.content_margin_right = 0.0
	add_theme_stylebox_override("panel", compact_style)
	custom_minimum_size = Vector2(230, UIThemeTokens.TARGET_MIN)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	gui_input.connect(_on_gui_input)

func bind_player(player: PlayerData) -> void:
	_player = player
	refresh()

func set_compact(value: bool) -> void:
	_compact = value
	custom_minimum_size.x = 178 if value else 250
	refresh()

func refresh() -> void:
	if name_label == null:
		_build()
	if _player == null or _player.v2_research == null:
		name_label.text = "Pesquisa indisponível"
		detail_label.text = "—"
		progress.visible = false
		attention_badge.visible = false
		return
	var state := _player.v2_research
	if state.active_id == "":
		var complete := state.get_completed_ids().size() >= V2ResearchDatabase.all_nodes().size()
		name_label.text = "Pesquisas concluídas" if complete else "Escolher Pesquisa"
		detail_label.text = "128 / 128" if complete else ("%s Conhecimento guardado" % _number(state.research_overflow) if state.research_overflow > 0.0 else "Nenhum projeto ativo")
		progress.visible = false
		attention_badge.visible = not complete
		tooltip_text = detail_label.text
		return
	var node := V2ResearchDatabase.get_node(state.active_id)
	if node == null:
		return
	var current := state.get_progress(state.active_id)
	var remaining := maxf(node.cost - current, 0.0)
	var income := V2EconomyRuntime.player_knowledge_income(_player)
	var eta := "Sem progresso" if income <= 0.0 else "≈%d turnos" % maxi(int(ceil(remaining / income)), 1)
	name_label.text = _truncate(node.display_name, 18 if _compact else 28)
	detail_label.text = "%d%% · %s" % [int(round(state.get_progress_ratio(state.active_id) * 100.0)), eta] if _compact else "%s / %s · faltam %s · %s" % [_number(current), _number(node.cost), _number(remaining), eta]
	progress.visible = true
	progress.set_progress("", current, node.cost)
	progress.title_label.visible = false
	attention_badge.visible = false
	tooltip_text = "%s\nProgresso: %s / %s\nRestante: %s Conhecimento\n%s" % [node.display_name, _number(current), _number(node.cost), _number(remaining), eta]

func _build() -> void:
	if name_label != null:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UIThemeTokens.SPACE_2)
	margin.add_theme_constant_override("margin_right", UIThemeTokens.SPACE_2)
	margin.add_theme_constant_override("margin_top", UIThemeTokens.SPACE_1)
	margin.add_theme_constant_override("margin_bottom", UIThemeTokens.SPACE_1)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	margin.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	name_label = Label.new()
	name_label.theme_type_variation = &"CaptionLabel"
	texts.add_child(name_label)
	detail_label = Label.new()
	detail_label.theme_type_variation = &"CaptionLabel"
	detail_label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
	texts.add_child(detail_label)
	progress = AEProgressBar.new()
	texts.add_child(progress)
	progress._ready()
	progress.progress_bar.custom_minimum_size.y = 5
	attention_badge = AEBadge.new()
	attention_badge.text = "!"
	row.add_child(attention_badge)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()

func _truncate(value: String, limit: int) -> String:
	return value if value.length() <= limit else value.left(limit - 1) + "…"

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
