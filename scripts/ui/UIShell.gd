class_name UIShell
extends Control

signal pause_requested
signal destination_requested(destination: StringName)
signal attention_action_requested(action: String, item: AttentionItem)
signal event_action_requested(event: UIEventData)
signal city_requested(city: City)
signal end_turn_requested
## Fase 30: pedidos das telas estratégicas que precisam de câmera/seleção (HUD orquestra).
signal empire_city_requested(city: City)
signal empire_unit_requested(unit: Unit)
signal empire_attention_requested(item: AttentionItem)
signal victory_detail_requested(detail: String)
signal map_location_requested(coord: Vector2i)

@onready var map_pass_through: Control = $MapPassThrough
@onready var global_bar: GlobalBarPresenter = $GlobalBar
@onready var context_host: PanelContainer = $ContextHost
@onready var bottom_host: Control = $BottomHost
@onready var attention_host: HBoxContainer = $BottomHost/AttentionHost
@onready var turn_controller_host: HBoxContainer = $BottomHost/TurnControllerHost
@onready var minimap_host: PanelContainer = $MinimapHost
@onready var auxiliary_host: Control = $AuxiliaryHost
@onready var critical_alert_host: CenterContainer = $CriticalAlertHost
@onready var strategic_overlay_host: Control = $StrategicOverlayHost
@onready var overlay_dimmer: ColorRect = $StrategicOverlayHost/Dimmer
@onready var modal_manager: ModalManager = $ModalManager
@onready var toast_presenter: ToastPresenter = $ToastPresenter
@onready var tooltip_host: AETooltipHost = $TooltipHost
@onready var debug_host: Control = $DebugHost
@onready var navigation_manager: NavigationManager = $NavigationManager

var attention_service := AttentionService.new()
var attention_presenter: AttentionPresenter
var turn_controller: TurnController
var city_summary: CityProductionPresenter
var event_center: EventCenterPresenter
var critical_alerts: CriticalAlertPresenter
var context_router: ContextRouter
var targeting_banner: TargetingBanner
var empire_screen: EmpireScreen
var diplomacy_screen: DiplomacyScreen
var victory_screen: VictoryScreen
var current_breakpoint := "medium"
var _viewport_size := Vector2(1280, 720)
var context_width := float(UIThemeTokens.CONTEXT_WIDTH_MEDIUM)
var _active_drawer: Control
var _system_surface_active := false

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	overlay_dimmer.visible = false
	_build_live_hud()
	global_bar.navigation_requested.connect(_on_navigation_requested)
	global_bar.city_summary_requested.connect(toggle_city_summary)
	global_bar.location_requested.connect(func(coord: Vector2i): map_location_requested.emit(coord))
	global_bar.event_center_requested.connect(toggle_event_center)
	navigation_manager.overlay_visibility_changed.connect(_on_overlay_visibility_changed)
	resized.connect(_on_resized)
	call_deferred("_on_resized")

func _apply_accessibility_theme() -> void:
	theme = Settings.build_ui_theme()

func _exit_tree() -> void:
	attention_service.dispose()

func _build_live_hud() -> void:
	attention_presenter = AttentionPresenter.new()
	attention_presenter.name = "AttentionPresenter"
	attention_presenter.bind_service(attention_service)
	attention_presenter.action_requested.connect(_on_attention_action)
	attention_presenter.expanded_changed.connect(_on_attention_expanded)
	attention_presenter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attention_presenter.size_flags_vertical = Control.SIZE_SHRINK_END
	attention_host.add_child(attention_presenter)
	turn_controller = TurnController.new()
	turn_controller.name = "TurnController"
	turn_controller.bind(attention_service, modal_manager)
	turn_controller.action_requested.connect(_on_attention_action)
	turn_controller.end_turn_requested.connect(func(): end_turn_requested.emit())
	turn_controller_host.add_child(turn_controller)
	city_summary = CityProductionPresenter.new()
	city_summary.name = "CityProductionSummary"
	city_summary.visible = false
	city_summary.close_requested.connect(close_auxiliary_drawer)
	city_summary.city_requested.connect(func(city: City): city_requested.emit(city))
	auxiliary_host.add_child(city_summary)
	event_center = EventCenterPresenter.new()
	event_center.name = "EventCenter"
	event_center.visible = false
	event_center.close_requested.connect(close_auxiliary_drawer)
	event_center.action_requested.connect(func(event: UIEventData): event_action_requested.emit(event))
	auxiliary_host.add_child(event_center)
	critical_alerts = CriticalAlertPresenter.new()
	critical_alerts.name = "CriticalAlerts"
	critical_alerts.custom_minimum_size.x = 620
	critical_alerts.action_requested.connect(func(event: UIEventData): event_action_requested.emit(event))
	critical_alert_host.add_child(critical_alerts)
	_build_context_layer()
	_build_strategy_screens()

## Fase 30: o ContextHost passa a hospedar os painéis reais de Tile/Unidade/Cidade
## e a faixa inferior ganha o banner fixo de mira.
func _build_context_layer() -> void:
	var context_style := UITheme.panel_style(UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_PANEL, true)
	context_style.shadow_size = UIThemeTokens.ELEVATION_DOCK
	context_style.set_content_margin_all(UIThemeTokens.SPACE_3)
	context_host.add_theme_stylebox_override("panel", context_style)
	context_host.anchor_top = 1.0
	context_router = ContextRouter.new()
	context_router.name = "ContextRouter"
	add_child(context_router)
	context_router.setup(context_host)
	context_router.layout_changed.connect(_fit_context_host)
	context_router.context_changed.connect(func(_mode: String): _fit_context_host())
	targeting_banner = TargetingBanner.new()
	targeting_banner.z_index = 12
	add_child(targeting_banner)

## Império, Diplomacia e Vitória: cenas próprias, registradas na navegação central e
## construídas só quando abertas (StrategyScreen é lazy).
func _build_strategy_screens() -> void:
	empire_screen = (load("res://scenes/ui/strategy/EmpireScreen.tscn") as PackedScene).instantiate()
	diplomacy_screen = (load("res://scenes/ui/strategy/DiplomacyScreen.tscn") as PackedScene).instantiate()
	victory_screen = (load("res://scenes/ui/strategy/VictoryScreen.tscn") as PackedScene).instantiate()
	for screen in [empire_screen, diplomacy_screen, victory_screen]:
		strategic_overlay_host.add_child(screen)
		(screen as StrategyScreen).close_requested.connect(close_strategic_overlay)
	empire_screen.attention_source = attention_service
	diplomacy_screen.modal_manager = modal_manager
	empire_screen.city_requested.connect(func(city: City): empire_city_requested.emit(city))
	empire_screen.unit_requested.connect(func(unit: Unit): empire_unit_requested.emit(unit))
	empire_screen.destination_requested.connect(func(destination: StringName): open_destination(destination))
	empire_screen.attention_requested.connect(func(item: AttentionItem): empire_attention_requested.emit(item))
	empire_screen.victory_detail_requested.connect(func(detail: String): victory_detail_requested.emit(detail))
	victory_screen.ritual_location_requested.connect(func(coord: Vector2i): map_location_requested.emit(coord))
	navigation_manager.register_overlay(NavigationManager.EMPIRE, empire_screen)
	navigation_manager.register_overlay(NavigationManager.DIPLOMACY, diplomacy_screen)
	navigation_manager.register_overlay(NavigationManager.VICTORY, victory_screen)

func bind_player(player: PlayerData) -> void:
	attention_service.bind_player(player)
	global_bar.refresh(player)
	# O drawer deriva seu conteudo ao abrir; montar todas as linhas escondidas
	# em cada troca de estado faria o mapa pagar pelo que o jogador nao ve.
	if city_summary.visible:
		city_summary.bind_player(player)
	turn_controller.refresh()
	_show_current_critical_states()

func refresh_live_state() -> void:
	attention_service.bind_player(GameManager.human_player)
	global_bar.refresh(GameManager.human_player)
	if city_summary.visible:
		city_summary.bind_player(GameManager.human_player)
	if event_center.visible:
		event_center.refresh()
	turn_controller.set_processing(GameManager.is_turn_processing)
	_show_current_critical_states()

func _show_current_critical_states() -> void:
	for index in GameManager.players.size():
		var rival: PlayerData = GameManager.players[index]
		if rival == null or rival == GameManager.human_player or not V2TranscendenceSystem.has_active_ritual(rival):
			continue
		if V2TranscendenceSystem.ritual_rounds_remaining(rival) != 1:
			continue
		var name_value := rival.civ.civ_name if rival.civ != null else "Civilização rival"
		var event := UIEventData.create("ritual_critical_state", UIEventData.Category.VICTORY, UIEventData.Severity.CRITICAL, "Transcendência iminente", "%s concluirá o Ritual em 1 rodada." % name_value)
		event.dedup_key = "ritual_state:%d:%s" % [index, str(rival.v2_transcendence_ritual.get("last_progress_turn", -1))]
		event.focus_action = "victory"
		event.with_target(V2TranscendenceSystem.ritual_site_coord(rival), "ritual")
		critical_alerts.enqueue(event)

func register_strategic_overlay(destination: StringName, panel: Control, before_open: Callable = Callable()) -> void:
	navigation_manager.register_overlay(destination, panel, before_open)

func register_pause_action(action: Callable) -> void:
	navigation_manager.register_action(NavigationManager.PAUSE, action)

func open_destination(destination: StringName) -> bool:
	close_auxiliary_drawer()
	attention_presenter.collapse()
	return navigation_manager.open(destination)

func close_strategic_overlay() -> bool:
	return navigation_manager.close_active()

func toggle_city_summary() -> void:
	if _active_drawer == city_summary:
		close_auxiliary_drawer()
		return
	city_summary.bind_player(GameManager.human_player)
	_open_drawer(city_summary)

func toggle_event_center() -> void:
	if _active_drawer == event_center:
		close_auxiliary_drawer()
		return
	event_center.opened()
	_open_drawer(event_center)

func close_auxiliary_drawer() -> void:
	if _active_drawer != null:
		_active_drawer.visible = false
	_active_drawer = null
	_sync_surface_visibility()

## Pause, Settings and Load own the interaction while open. The game chrome is
## hidden as a unit, preventing context, turn and event controls from leaking
## through the system surface.
func set_system_surface_active(value: bool) -> void:
	_system_surface_active = value
	if value:
		close_auxiliary_drawer()
		attention_presenter.collapse()
		navigation_manager.close_active()
		SelectionManager.cancel_active_targeting()
	_sync_surface_visibility()

func handle_escape() -> bool:
	if modal_manager.is_modal_open():
		return modal_manager.handle_escape()
	if _active_drawer != null:
		close_auxiliary_drawer()
		return true
	if attention_presenter.is_expanded():
		attention_presenter.collapse()
		return true
	if navigation_manager.close_active():
		return true
	return false

func apply_viewport_size(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	current_breakpoint = UIThemeTokens.breakpoint_name(viewport_size.x)
	context_width = UIThemeTokens.context_width_for(viewport_size.x)
	context_host.offset_left = -context_width - UIThemeTokens.HUD_EDGE_MARGIN
	context_host.offset_right = -UIThemeTokens.HUD_EDGE_MARGIN
	# 1600 e a baseline intermediaria, nao uma tela larga: a barra completa
	# ainda estoura quando os quatro estados estrategicos coexistem.
	global_bar.set_compact(viewport_size.x < UIThemeTokens.BREAKPOINT_LARGE)
	var toast_width := minf(420.0, viewport_size.x - 2.0 * UIThemeTokens.SPACE_4)
	toast_presenter.offset_left = -toast_width * 0.5
	toast_presenter.offset_right = toast_width * 0.5
	var drawer_width := 420.0 if viewport_size.x >= UIThemeTokens.BREAKPOINT_LARGE else clampf(viewport_size.x * 0.32, 340.0, 400.0)
	for drawer in [city_summary, event_center]:
		_layout_drawer(drawer, drawer_width)
	_layout_minimap(viewport_size)
	turn_controller_host.offset_right = -UIThemeTokens.HUD_EDGE_MARGIN
	turn_controller_host.offset_bottom = -UIThemeTokens.HUD_EDGE_MARGIN
	turn_controller_host.offset_top = -UIThemeTokens.HUD_EDGE_MARGIN - 56.0
	attention_host.offset_bottom = -UIThemeTokens.HUD_EDGE_MARGIN
	attention_host.offset_top = -UIThemeTokens.HUD_EDGE_MARGIN - 56.0
	_fit_context_host()
	_layout_targeting_banner(viewport_size)
	for screen in [empire_screen, diplomacy_screen, victory_screen]:
		if screen != null:
			(screen as StrategyScreen).top_reserved = top_reserved()
			(screen as StrategyScreen).call_deferred("_layout")
	_place_toasts(navigation_manager.is_overlay_open())

## V3 / Etapa 4 — tamanho do minimapa. Compacto: o maior que cabe à esquerda da faixa de atenção (centro − 400 px)
## sem tocar nela; ampliado (botão no próprio minimapa): ~2,2× para ler os hexágonos, limitado à área entre a barra
## global e o painel de contexto. O minimapa só recalcula o enquadramento quando este tamanho muda de verdade.
var minimap_expanded := false

static func minimap_size_for(viewport_size: Vector2, expanded: bool, context_width_px: float) -> Vector2:
	# Proporção ~2:1 do mundo padrão (144×76, terra + calotas) — sem faixas vazias grandes no letterbox.
	var compact := Vector2(216.0, 116.0) if viewport_size.x <= UIThemeTokens.BREAKPOINT_MEDIUM else Vector2(368.0, 186.0)
	if not expanded:
		return compact
	var max_size := Vector2(viewport_size.x - context_width_px - UIThemeTokens.HUD_EDGE_MARGIN * 3.0, viewport_size.y - float(UIThemeTokens.GLOBAL_BAR_HEIGHT) - 96.0)
	return Vector2(minf(compact.x * 2.2, max_size.x), minf(compact.y * 2.2, max_size.y)).max(compact)

func _layout_minimap(viewport_size: Vector2) -> void:
	var minimap_size := minimap_size_for(viewport_size, minimap_expanded, context_width)
	minimap_host.offset_left = UIThemeTokens.HUD_EDGE_MARGIN
	minimap_host.offset_right = UIThemeTokens.HUD_EDGE_MARGIN + minimap_size.x
	minimap_host.offset_top = -UIThemeTokens.HUD_EDGE_MARGIN - minimap_size.y
	minimap_host.offset_bottom = -UIThemeTokens.HUD_EDGE_MARGIN

func set_minimap_expanded(value: bool) -> void:
	minimap_expanded = value
	_layout_minimap(_viewport_size)

func toggle_minimap_expanded() -> void:
	set_minimap_expanded(not minimap_expanded)

## Toast é confirmação curta: com tela estratégica aberta ele desce para a base
## da tela, para nunca cobrir abas e títulos da tela.
func _place_toasts(overlay_open: bool) -> void:
	var top := 188.0
	if overlay_open:
		top = maxf(188.0, _viewport_size.y - 300.0)
	toast_presenter.offset_top = top
	toast_presenter.offset_bottom = top + 242.0

## Base da barra global REAL (no modo compacto ela é mais alta que 72 px).
func top_reserved() -> float:
	var bar_bottom := global_bar.position.y + global_bar.size.y if global_bar != null else 72.0
	return maxf(float(UIThemeTokens.GLOBAL_BAR_HEIGHT), bar_bottom) + float(UIThemeTokens.SPACE_2)

## Altura do contexto = conteúdo desejado, limitada à área útil entre a barra global
## e a faixa inferior. Tile compacto não ocupa a lateral inteira; cidade usa tudo.
func _fit_context_host() -> void:
	if context_router == null:
		return
	var bottom_reserved := float(UIThemeTokens.HUD_EDGE_MARGIN + 56)
	var available := _viewport_size.y - top_reserved() - bottom_reserved
	var wanted := context_router.preferred_height() + float(UIThemeTokens.SPACE_3) * 2.0
	var height := clampf(wanted, 140.0, available)
	context_host.anchor_top = 1.0
	context_host.anchor_bottom = 1.0
	context_host.offset_bottom = -bottom_reserved
	context_host.offset_top = -bottom_reserved - height

## O banner fica centrado na área do MAPA (entre minimapa e contexto), logo acima
## da faixa de Attention/Turn Controller.
func _layout_targeting_banner(viewport_size: Vector2) -> void:
	if targeting_banner == null:
		return
	var left := minimap_host.offset_right + float(UIThemeTokens.SPACE_3)
	var right := viewport_size.x - context_width - float(UIThemeTokens.SPACE_4)
	var width := minf(600.0, maxf(320.0, right - left))
	var x := left + maxf(0.0, (right - left - width) * 0.5)
	targeting_banner.position = Vector2(x, viewport_size.y - 76.0 - 170.0)
	targeting_banner.size = Vector2(width, 170.0)

func layer_order() -> Dictionary:
	return {"map": map_pass_through.z_index, "chrome": global_bar.z_index, "auxiliary": auxiliary_host.z_index, "strategic": strategic_overlay_host.z_index, "critical": critical_alert_host.z_index, "modal": modal_manager.z_index, "toast": toast_presenter.z_index, "tooltip": tooltip_host.z_index, "debug": debug_host.z_index}

func _open_drawer(drawer: Control) -> void:
	close_auxiliary_drawer()
	attention_presenter.collapse()
	drawer.visible = true
	_active_drawer = drawer
	var drawer_width := 420.0 if _viewport_size.x >= UIThemeTokens.BREAKPOINT_LARGE else clampf(_viewport_size.x * 0.32, 340.0, 400.0)
	_layout_drawer(drawer, drawer_width)
	# PanelContainer recalcula offsets uma vez ao sair de `visible = false`.
	# Reaplicar no frame seguinte faz a altura adaptativa vencer esse primeiro
	# layout sem polling e sem manter uma altura fixa para todos os historicos.
	call_deferred("_layout_drawer", drawer, drawer_width)
	_sync_surface_visibility()
	drawer.modulate.a = 0.0
	var final_x := drawer.position.x
	drawer.position.x += 18.0
	var tween := drawer.create_tween().set_parallel(true)
	tween.tween_property(drawer, "modulate:a", 1.0, Settings.motion_duration(UIThemeTokens.MOTION_PANEL))
	tween.tween_property(drawer, "position:x", final_x, Settings.motion_duration(UIThemeTokens.MOTION_PANEL))

func _layout_drawer(drawer: Control, drawer_width: float) -> void:
	var wanted_height: float = float(drawer.call("preferred_height")) if drawer.has_method("preferred_height") else 520.0
	var drawer_height := minf(wanted_height, _viewport_size.y - top_reserved() - UIThemeTokens.HUD_EDGE_MARGIN * 2.0)
	drawer.custom_minimum_size = Vector2.ZERO
	# Offsets explicitos evitam que um Control dinamico preserve o antigo
	# offset_bottom quando troca de preset. Isso fazia o drawer pedir 408 px,
	# mas continuar com os 700 px herdados do primeiro layout do viewport.
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_top = 0.0
	drawer.anchor_bottom = 0.0
	drawer.offset_left = -drawer_width - UIThemeTokens.HUD_EDGE_MARGIN
	drawer.offset_right = -UIThemeTokens.HUD_EDGE_MARGIN
	drawer.offset_top = top_reserved()
	drawer.offset_bottom = top_reserved() + drawer_height

func _on_navigation_requested(destination: StringName) -> void:
	close_auxiliary_drawer()
	attention_presenter.collapse()
	destination_requested.emit(destination)

func _on_attention_action(action: String, item: AttentionItem) -> void:
	attention_presenter.collapse()
	attention_action_requested.emit(action, item)

func _on_attention_expanded(value: bool) -> void:
	if value:
		close_auxiliary_drawer()
		attention_host.offset_top = -440.0
	else:
		attention_host.offset_top = -UIThemeTokens.HUD_EDGE_MARGIN - 56.0
	_sync_surface_visibility()

func _on_overlay_visibility_changed(value: bool) -> void:
	overlay_dimmer.visible = value
	if value:
		close_auxiliary_drawer()
		attention_presenter.collapse()
		# Tela estratégica aberta encerra qualquer mira sem gastar nada (§50).
		SelectionManager.cancel_active_targeting()
	_place_toasts(value)
	_sync_surface_visibility()

func _sync_surface_visibility() -> void:
	var strategic_open := navigation_manager != null and navigation_manager.is_overlay_open()
	var attention_open := attention_presenter != null and attention_presenter.is_expanded()
	var suppress_context := _system_surface_active or _active_drawer != null or strategic_open or attention_open
	if context_router != null:
		context_router.set_suppressed(suppress_context)
	bottom_host.visible = not _system_surface_active and not strategic_open
	auxiliary_host.visible = not _system_surface_active
	critical_alert_host.visible = not _system_surface_active and not strategic_open
	strategic_overlay_host.visible = not _system_surface_active
	global_bar.visible = not _system_surface_active
	minimap_host.visible = not _system_surface_active
	toast_presenter.visible = not _system_surface_active
	if targeting_banner != null:
		if _system_surface_active or strategic_open:
			targeting_banner.visible = false
		else:
			targeting_banner.refresh()

func _on_resized() -> void:
	apply_viewport_size(size)
