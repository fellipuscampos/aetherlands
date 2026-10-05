class_name ContextRouter
extends Node

## Roteador do ContextHost (Fase 30 / UI-3). Seleção produz EXATAMENTE um contexto
## principal — Tile, Unidade ou Cidade — e, quando o tile tem mais de um ocupante
## apresentável, um seletor compacto troca entre eles (nunca três painéis
## empilhados). Todos os sinais do mundo são coalescidos num único reconcile por
## frame (call_deferred); não há `_process` nem polling.

signal context_changed(mode: String)
signal layout_changed

const MODE_NONE := ""
const MODE_TILE := "tile"
const MODE_UNIT := "unit"
const MODE_CITY := "city"
## V3 / Etapa 3: unidade em tile com prédio/covil/melhoria/obra — o inspetor oferece "Estrutura" (painel do tile
## com a estrutura opaca e a unidade semitransparente no mapa).
const MODE_STRUCTURE := "structure"
const NO_COORD := Vector2i(999999, 999999)

var host: PanelContainer
var root: VBoxContainer
var selector: HBoxContainer
var slot: VBoxContainer
var unit_panel: UnitContextPanel
var city_panel: CityContextPanel
var tile_panel: TileContextPanel
var mode := MODE_NONE
var coord := NO_COORD
var options: Array[String] = []
var reconcile_count := 0
var _suppressed := false

var _unit: Unit
var _city: City
var _preferred_mode := ""
var _preferred_coord := NO_COORD
var _pending_tile := false
var _pending_tile_coord := NO_COORD
var _pending_tile_data_null := false
var _pending_unit := false
var _pending_unit_value: Unit
var _pending_refresh := false
var _queued := false
var _pending_city_tab := ""
var _signals_connected := false

func setup(context_host: PanelContainer) -> void:
	host = context_host
	root = VBoxContainer.new()
	root.name = "ContextRoot"
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	host.add_child(root)
	selector = HBoxContainer.new()
	selector.name = "OccupantSelector"
	selector.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	selector.visible = false
	root.add_child(selector)
	slot = VBoxContainer.new()
	slot.name = "Slot"
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(slot)
	unit_panel = (load("res://scenes/ui/context/UnitContextPanel.tscn") as PackedScene).instantiate()
	city_panel = (load("res://scenes/ui/context/CityContextPanel.tscn") as PackedScene).instantiate()
	tile_panel = (load("res://scenes/ui/context/TileContextPanel.tscn") as PackedScene).instantiate()
	for panel in [unit_panel, city_panel, tile_panel]:
		(panel as Control).visible = false
		slot.add_child(panel)
		panel.close_requested.connect(close_context)
		# Texto com quebra só tem altura final depois do layout: o conteúdo avisa e a
		# shell reajusta a altura do host (coalescido, sem polling).
		(panel.get_node("Scroll/Body") as Control).minimum_size_changed.connect(_on_content_resized)
	selector.minimum_size_changed.connect(_on_content_resized)
	host.visible = false
	_connect_signals()

func _exit_tree() -> void:
	_disconnect_signals()

func _signal_map() -> Array:
	return [
		[EventBus.tile_selected, _on_tile_selected],
		[EventBus.unit_selected, _on_unit_selected],
		[EventBus.fog_updated, queue_refresh],
		[EventBus.ui_state_changed, _on_state_changed],
		[EventBus.targeting_changed, queue_refresh],
		[EventBus.v2_unlock_applied, _on_unlock_applied],
		[EventBus.v2_transcendence_started, _on_ritual_changed],
		[EventBus.v2_transcendence_progressed, _on_ritual_changed],
		[EventBus.v2_transcendence_interrupted, _on_ritual_interrupted],
		[EventBus.city_captured, _on_city_captured],
		[EventBus.diplomacy_changed, _on_diplomacy_changed],
		[TurnManager.turn_changed, _on_turn_changed],
		[EventBus.unit_status_changed, _on_unit_status_changed],
	]

func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	for entry in _signal_map():
		var source: Signal = entry[0]
		if not source.is_connected(entry[1]):
			source.connect(entry[1])

func _disconnect_signals() -> void:
	if not _signals_connected:
		return
	for entry in _signal_map():
		var source: Signal = entry[0]
		if source.is_connected(entry[1]):
			source.disconnect(entry[1])
	_signals_connected = false

# --- API pública ------------------------------------------------------------------

func primary_panel() -> Control:
	match mode:
		MODE_UNIT:
			return unit_panel
		MODE_CITY:
			return city_panel
		MODE_TILE, MODE_STRUCTURE:
			return tile_panel
	return null

## Abre a cidade (deep links: City Summary, Attention, Event Center, City List).
func open_city(city: City, tab: String = "") -> void:
	if city == null or not is_instance_valid(city):
		return
	_preferred_mode = MODE_CITY
	_preferred_coord = city.coord
	_pending_city_tab = tab
	# Um deep link explícito vence seleção/refresh pendentes do mesmo frame
	# (ex.: cancelar a mira reseleciona a unidade logo antes).
	_pending_tile = false
	_pending_unit = false
	_pending_refresh = false
	# Mesmo roteamento do clique no tile: ocupantes/seletor sempre recalculados.
	_route_tile(city.coord)

func open_unit(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.owner_player == GameManager.human_player:
		_preferred_mode = MODE_UNIT
		_preferred_coord = unit.coord
		SelectionManager.select_unit(unit)
		flush()
	else:
		_show_unit(unit)

func close_context() -> void:
	SelectionManager.cancel_active_targeting()
	SelectionManager.clear_selection()
	_pending_tile = false
	_pending_unit = false
	_hide()

func reset() -> void:
	_unit = null
	_city = null
	_preferred_mode = ""
	_preferred_coord = NO_COORD
	_pending_tile = false
	_pending_unit = false
	_pending_refresh = false
	_hide()

func queue_refresh(_a = null, _b = null, _c = null, _d = null) -> void:
	_pending_refresh = true
	_queue()

## Processa imediatamente o que estiver pendente (testes e deep links).
func flush() -> void:
	_queued = false
	_reconcile()

func is_open() -> bool:
	return mode != MODE_NONE and host != null and host.visible

## Drawers and higher-priority surfaces hide the presentation, not the
## selection. Releasing suppression restores the same routed context.
func set_suppressed(value: bool) -> void:
	_suppressed = value
	if host == null:
		return
	host.visible = not value and mode != MODE_NONE
	if not value and mode != MODE_NONE:
		layout_changed.emit()

func is_suppressed() -> bool:
	return _suppressed

# --- Sinais -------------------------------------------------------------------------

func _on_tile_selected(target: Vector2i, data: HexTileData) -> void:
	_pending_tile = true
	_pending_tile_coord = target
	_pending_tile_data_null = data == null
	_queue()

func _on_unit_selected(unit: Unit) -> void:
	_pending_unit = true
	_pending_unit_value = unit
	_queue()

func _on_state_changed(_reason: String) -> void:
	if mode == MODE_CITY or mode == MODE_UNIT:
		queue_refresh()

func _on_unlock_applied(player: PlayerData, _type: String, _id: String) -> void:
	if player == GameManager.human_player:
		queue_refresh()

func _on_ritual_changed(_player: PlayerData, _coord: Vector2i, _remaining: int) -> void:
	if mode == MODE_CITY:
		queue_refresh()

func _on_ritual_interrupted(_player: PlayerData, _coord: Vector2i, _reason: String) -> void:
	if mode == MODE_CITY:
		queue_refresh()

func _on_city_captured(_old: PlayerData, _new: PlayerData, _name: String, _coord: Vector2i) -> void:
	queue_refresh()

func _on_diplomacy_changed(_type: String, _source: PlayerData, _target: PlayerData, _reason: String) -> void:
	if mode != MODE_NONE:
		queue_refresh()

func _on_turn_changed(_turn: int, _index: int) -> void:
	queue_refresh()

## V3 / Etapa 4: estado da unidade em foco mudou (aplicado/renovado/tick/expirou) → chips atualizam já.
func _on_unit_status_changed(unit: Unit) -> void:
	if mode == MODE_UNIT and unit == _unit:
		queue_refresh()

var _layout_queued := false

func _on_content_resized() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_emit_layout")

func _emit_layout() -> void:
	_layout_queued = false
	if mode != MODE_NONE:
		layout_changed.emit()

func _queue() -> void:
	if _queued:
		return
	_queued = true
	call_deferred("_deferred_reconcile")

func _deferred_reconcile() -> void:
	if not _queued:
		return
	_queued = false
	_reconcile()

# --- Decisão -------------------------------------------------------------------------

func _reconcile() -> void:
	reconcile_count += 1
	var tile_pending := _pending_tile
	var unit_pending := _pending_unit
	var refresh_pending := _pending_refresh
	_pending_tile = false
	_pending_unit = false
	_pending_refresh = false
	if tile_pending:
		if _pending_tile_data_null:
			_hide()
		else:
			_route_tile(_pending_tile_coord)
		return
	if unit_pending:
		var unit := _pending_unit_value
		if unit != null and is_instance_valid(unit):
			_preferred_mode = MODE_UNIT
			_preferred_coord = unit.coord
			_route_tile(unit.coord)
			return
		if mode == MODE_UNIT and (_unit == null or not is_instance_valid(_unit) or _unit.owner_player == GameManager.human_player):
			# Seleção limpa sem novo tile (dissolver, load, nova partida): fecha o contexto.
			_hide()
			return
	if refresh_pending:
		_refresh_current()

func _route_tile(target: Vector2i) -> void:
	var grid := GameManager.hex_grid
	if grid == null or not grid.tiles.has(target):
		_hide()
		return
	if target != _preferred_coord:
		_preferred_mode = ""
	coord = target
	var human := GameManager.human_player
	var state := TileInspector.visibility_state(grid, target)
	var city: City = grid.get_city_at(target)
	var city_visible := city != null and (city.owner_player == human or state == TileInspector.STATE_VISIBLE)
	var unit: Unit = grid.get_unit_at(target)
	var unit_visible := unit != null and is_instance_valid(unit) and (unit.owner_player == human or unit.always_visible or state == TileInspector.STATE_VISIBLE)
	options.clear()
	if city_visible:
		options.append(MODE_CITY)
	if unit_visible:
		options.append(MODE_UNIT)
	if unit_visible and not city_visible and _has_structure(grid, target, state):
		options.append(MODE_STRUCTURE)
	options.append(MODE_TILE)
	var own_selected := unit_visible and unit.owner_player == human and SelectionManager.selected_unit == unit
	var wanted := _preferred_mode
	if wanted == "" or not wanted in options or (wanted == MODE_UNIT and unit_visible and unit.owner_player == human and not own_selected):
		if city_visible:
			wanted = MODE_CITY
		elif unit_visible and (unit.owner_player != human or own_selected):
			wanted = MODE_UNIT
		else:
			wanted = MODE_TILE
	match wanted:
		MODE_CITY:
			_show_city(city, _pending_city_tab)
		MODE_UNIT:
			_show_unit(unit)
		MODE_STRUCTURE:
			_show_tile(target, MODE_STRUCTURE)
		_:
			_show_tile(target)
	_pending_city_tab = ""
	_rebuild_selector(city if city_visible else null, unit if unit_visible else null)

func _show_city(city: City, tab: String) -> void:
	_city = city
	coord = city.coord
	_activate(MODE_CITY)
	city_panel.show_city(city, tab)
	if not city_panel.is_valid_context():
		_hide()
		return
	layout_changed.emit()

func _show_unit(unit: Unit) -> void:
	_unit = unit
	coord = unit.coord
	_activate(MODE_UNIT)
	unit_panel.show_unit(unit)
	if not unit_panel.is_valid_context():
		_show_tile(coord)
		return
	layout_changed.emit()

func _show_tile(target: Vector2i, as_mode: String = MODE_TILE) -> void:
	coord = target
	_activate(as_mode)
	tile_panel.show_tile(target)
	layout_changed.emit()

func _activate(new_mode: String) -> void:
	var changed := mode != new_mode
	mode = new_mode
	unit_panel.visible = mode == MODE_UNIT
	city_panel.visible = mode == MODE_CITY
	tile_panel.visible = mode == MODE_TILE or mode == MODE_STRUCTURE
	_sync_visual_focus()
	if not host.visible and not _suppressed:
		host.visible = true
		host.modulate.a = 0.0
		host.create_tween().tween_property(host, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_PANEL))
	if changed:
		context_changed.emit(mode)

func _hide() -> void:
	var was_open := mode != MODE_NONE
	mode = MODE_NONE
	coord = NO_COORD
	options.clear()
	if unit_panel != null:
		unit_panel.visible = false
		city_panel.visible = false
		tile_panel.visible = false
		selector.visible = false
	if host != null:
		host.visible = false
	_sync_visual_focus()
	if was_open:
		context_changed.emit(mode)

## V3 / Etapa 3 — foco visual do tile inspecionado: Unidade (decoração/estrutura transparentes), Cidade/Estrutura
## (estrutura opaca, unidade transparente), Terreno escolhido no seletor (tudo transparente para ler o chão).
func _sync_visual_focus() -> void:
	var grid := GameManager.hex_grid
	if grid == null or not is_instance_valid(grid) or grid.visual_focus == null:
		return
	match mode:
		MODE_UNIT:
			grid.visual_focus.set_focus(coord, VisualFocusSystem.MODE_UNIT)
		MODE_CITY, MODE_STRUCTURE:
			grid.visual_focus.set_focus(coord, VisualFocusSystem.MODE_STRUCTURE)
		MODE_TILE:
			if options.size() > 1:
				grid.visual_focus.set_focus(coord, VisualFocusSystem.MODE_TERRAIN)
			else:
				grid.visual_focus.clear_focus()
		_:
			grid.visual_focus.clear_focus()

static func _has_structure(grid: HexGrid, target: Vector2i, state: String) -> bool:
	if state == TileInspector.STATE_UNSEEN:
		return false
	var building: Building = grid.buildings_by_coord.get(target)
	if building != null and (building.owner_player == GameManager.human_player or state == TileInspector.STATE_VISIBLE):
		return true
	return grid.lairs_by_coord.has(target) or grid.improvement_markers_by_coord.has(target) or (state == TileInspector.STATE_VISIBLE and grid._construction_markers.has(target))

func _refresh_current() -> void:
	match mode:
		MODE_UNIT:
			if unit_panel.is_valid_context() and _unit.coord != coord:
				_route_tile(_unit.coord)
				return
			if not unit_panel.is_valid_context():
				if coord != NO_COORD and GameManager.hex_grid != null and GameManager.hex_grid.tiles.has(coord):
					_route_tile(coord)
				else:
					_hide()
				return
			unit_panel.refresh()
		MODE_CITY:
			if not city_panel.is_valid_context():
				if coord != NO_COORD and GameManager.hex_grid != null and GameManager.hex_grid.tiles.has(coord):
					_route_tile(coord)
				else:
					_hide()
				return
			if city_panel.city.owner_player != GameManager.human_player and TileInspector.visibility_state(GameManager.hex_grid, coord) != TileInspector.STATE_VISIBLE:
				_route_tile(coord)
				return
			city_panel.refresh()
		MODE_TILE, MODE_STRUCTURE:
			if GameManager.hex_grid == null or not GameManager.hex_grid.tiles.has(coord):
				_hide()
				return
			_route_tile(coord)
	layout_changed.emit()

# --- Seletor de ocupantes -----------------------------------------------------------

func _rebuild_selector(city: City, unit: Unit) -> void:
	ContextUI.clear(selector)
	selector.visible = options.size() > 1
	if not selector.visible:
		return
	var group := ButtonGroup.new()
	for option in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.theme_type_variation = &"GhostButton"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
		button.custom_minimum_size.y = 32
		button.clip_text = true
		match option:
			MODE_CITY:
				button.name = "Select_city"
				button.text = "Cidade · %s" % city.city_name
			MODE_UNIT:
				button.name = "Select_unit"
				button.text = "Unidade · %s" % (unit.unit_data.unit_name if unit.owner_player == null else RaceTheme.unit_name(unit.unit_data.visual_kind, unit.owner_player.civ.race if unit.owner_player.civ != null else "human"))
			MODE_STRUCTURE:
				button.name = "Select_structure"
				button.text = "Estrutura"
			_:
				button.name = "Select_tile"
				button.text = "Terreno"
		button.set_pressed_no_signal(option == mode)
		var accent := UIThemeTokens.COLOR_ACCENT if option == mode else Color(UIThemeTokens.COLOR_BORDER, 0.7)
		var style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE_RAISED if option == mode else Color(0, 0, 0, 0), accent, 1, UIThemeTokens.RADIUS_CONTROL, false)
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(_on_selector_pressed.bind(option))
		selector.add_child(button)

func _on_selector_pressed(option: String) -> void:
	_preferred_mode = option
	_preferred_coord = coord
	var grid := GameManager.hex_grid
	if option == MODE_UNIT and grid != null:
		var unit: Unit = grid.get_unit_at(coord)
		if unit != null and unit.owner_player == GameManager.human_player and SelectionManager.selected_unit != unit:
			SelectionManager.select_unit(unit)
			flush()
			return
	_route_tile(coord)

func selector_button(option: String) -> Button:
	return selector.get_node_or_null("Select_" + option) as Button

## Altura desejada do conteúdo (a shell limita à área útil).
func preferred_height() -> float:
	var panel := primary_panel()
	if panel == null:
		return 0.0
	var extra := selector.get_combined_minimum_size().y + UIThemeTokens.SPACE_2 if selector.visible else 0.0
	return float(panel.call("preferred_height")) + extra
