class_name SettingsScreen
extends Control

## Front-end final: tela reutilizada pelo titulo e pela pausa, organizada em
## categorias. Toda opcao altera estado real; Developer Tools tem rota propria.

@export var show_debug: bool = false # Compatibilidade; deliberadamente ignorado.

signal back_requested
signal debug_requested # Compatibilidade para consumidores antigos; nunca emitido.

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var vsync_check_button: CheckButton = %VSyncCheckButton
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var anti_aliasing_option: OptionButton = %AntiAliasingOption
@onready var shadow_quality_option: OptionButton = %ShadowQualityOption
@onready var render_scale_option: OptionButton = %RenderScaleOption
@onready var screen_effects_check: CheckButton = %ScreenEffectsCheck
@onready var day_night_check: CheckButton = %DayNightCheck
@onready var weather_check: CheckButton = %WeatherCheck
@onready var map_lighting_check: CheckButton = %MapLightingCheck
@onready var creature_lighting_check: CheckButton = %CreatureLightingCheck
@onready var reset_graphics_button: Button = %ResetGraphicsButton
@onready var ui_scale_option: OptionButton = %UIScaleOption
@onready var reduced_motion_check: CheckButton = %ReducedMotionCheck
@onready var controls_text: RichTextLabel = %ControlsText
@onready var glossary_text: RichTextLabel = %GlossaryText
@onready var back_button: Button = %BackButton
@onready var debug_button: Button = %DebugButton

var _pages: Array[Control] = []
var _category_buttons: Array[Button] = []
var _refreshing := false
var _current_page := 0
const MENU_THEME := preload("res://scripts/ui/FantasyMenuTheme.gd")

func _ready() -> void:
	_pages.assign([%AudioPage, %VideoPage, %AccessibilityPage, %ControlsPage, %HelpPage])
	_category_buttons.assign([%AudioCategory, %VideoCategory, %AccessibilityCategory, %ControlsCategory, %HelpCategory])
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	get_viewport().size_changed.connect(_layout_for_viewport)
	visibility_changed.connect(_on_visibility_changed)
	for index in _category_buttons.size():
		_category_buttons[index].pressed.connect(_show_page.bind(index))
	_populate_options()
	_populate_controls()
	_populate_glossary()
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	vsync_check_button.toggled.connect(_on_vsync_toggled)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	anti_aliasing_option.item_selected.connect(_on_anti_aliasing_selected)
	shadow_quality_option.item_selected.connect(_on_shadow_quality_selected)
	render_scale_option.item_selected.connect(_on_render_scale_selected)
	screen_effects_check.toggled.connect(_on_screen_effects_toggled)
	day_night_check.toggled.connect(_on_day_night_toggled)
	weather_check.toggled.connect(_on_weather_toggled)
	map_lighting_check.toggled.connect(_on_map_lighting_toggled)
	creature_lighting_check.toggled.connect(_on_creature_lighting_toggled)
	reset_graphics_button.pressed.connect(_on_reset_graphics_pressed)
	ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	back_button.pressed.connect(func(): back_requested.emit())
	debug_button.visible = false
	refresh()
	_show_page(0)
	for i in _category_buttons.size():
		_category_buttons[i].icon = load(MENU_THEME.ART + ["icon_audio.svg", "icon_video.svg", "icon_interface.svg", "icon_controls.svg", "icon_help.svg"][i]) as Texture2D
		var marker := Label.new()
		marker.name = "SelectedMark"
		marker.text = "✓"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_theme_font_override("font", ThemeDB.fallback_font)
		marker.add_theme_font_size_override("font_size", 16)
		_category_buttons[i].add_child(marker)
		marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		marker.offset_left = -28
		marker.offset_right = -8
		marker.offset_top = -12
		marker.offset_bottom = 12
	_layout_for_viewport.call_deferred()

func _apply_accessibility_theme() -> void:
	theme = MENU_THEME.build(Settings.ui_scale_factor())
	_layout_for_viewport.call_deferred()

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and is_node_ready():
		_layout_for_viewport.call_deferred()

func _layout_for_viewport() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var factor := Settings.ui_scale_factor()
	var compact := viewport_size.y < 800
	var edge := roundi(maxf(32, (viewport_size.x - 1084 * maxf(1, factor)) / 2))
	for side in ["left", "right"]:
		$Margin.add_theme_constant_override("margin_" + side, edge)
	for side in ["top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, 24 if compact else 36)
	$Margin/Layout.add_theme_constant_override("separation", 12 if compact else 20)
	$Margin/Layout/Header/Titles/Title.add_theme_font_size_override("font_size", roundi((36 if compact else 44) * factor))
	$Margin/Layout/Body/CategoryScroll.custom_minimum_size.x = 220 * factor
	$Margin/Layout/Body/CategoryScroll/Categories/Hint.visible = not (compact and factor > 1.1)
	$Margin/Layout/Footer/Status.visible = factor <= 1.1 and viewport_size.x >= 1280
	back_button.custom_minimum_size = Vector2(160, 52) * factor
	for i in _category_buttons.size():
		_category_buttons[i].custom_minimum_size.y = 52 * factor
		_style_category(_category_buttons[i], i == _current_page)
	for control in [music_slider, sfx_slider]:
		control.custom_minimum_size = Vector2(480, 44) * factor
	for control in [window_mode_option, resolution_option, anti_aliasing_option, shadow_quality_option, render_scale_option, screen_effects_check, ui_scale_option,
			vsync_check_button, day_night_check, weather_check, map_lighting_check, creature_lighting_check, reduced_motion_check, reset_graphics_button]:
		control.custom_minimum_size.y = 44 * factor
	for prefix in ["WindowMode", "Resolution", "AntiAliasing", "ShadowQuality"]:
		%VideoPage.get_node(prefix + "Row/" + prefix + "Label").custom_minimum_size.x = 220 * factor
	_configure_focus()

func _focusable_controls(root_node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root_node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE and not (child is BaseButton and child.disabled):
			result.append(child)
		result.append_array(_focusable_controls(child))
	return result

func _configure_focus() -> void:
	if _pages.is_empty():
		return
	var controls := _focusable_controls(_pages[_current_page])
	var linear: Array[Control] = []
	linear.assign(_category_buttons)
	linear.append_array(controls)
	linear.append(back_button)
	for i in linear.size():
		linear[i].focus_next = linear[i].get_path_to(linear[(i + 1) % linear.size()])
		linear[i].focus_previous = linear[i].get_path_to(linear[posmod(i - 1, linear.size())])
	for i in _category_buttons.size():
		var button := _category_buttons[i]
		button.focus_neighbor_top = button.get_path_to(_category_buttons[posmod(i - 1, _category_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(_category_buttons[(i + 1) % _category_buttons.size()])
		button.focus_neighbor_right = button.get_path_to(controls[0] if not controls.is_empty() else back_button)
	for i in controls.size():
		var control := controls[i]
		control.focus_neighbor_top = control.get_path_to(controls[i - 1] if i > 0 else _category_buttons[_current_page])
		control.focus_neighbor_bottom = control.get_path_to(controls[i + 1] if i + 1 < controls.size() else back_button)
		if not control is HSlider:
			control.focus_neighbor_left = control.get_path_to(_category_buttons[_current_page])
	back_button.focus_neighbor_top = back_button.get_path_to(controls.back() if not controls.is_empty() else _category_buttons[_current_page])

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		var scroll: ScrollContainer = $Margin/Layout/Body/PagePanel/PageScroll
		var direction := 1 if event.is_action_pressed("ui_page_down") else -1
		scroll.scroll_vertical += roundi(scroll.size.y * .75) * direction
		get_viewport().set_input_as_handled()

func refresh() -> void:
	_refreshing = true
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	vsync_check_button.button_pressed = Settings.vsync_enabled
	reduced_motion_check.button_pressed = Settings.reduced_motion
	_select_by_metadata(window_mode_option, Settings.window_mode)
	_select_by_metadata(resolution_option, Settings.window_resolution)
	resolution_option.disabled = Settings.window_mode == Settings.FULLSCREEN
	_select_by_metadata(ui_scale_option, Settings.ui_scale_percent)
	_select_by_metadata(anti_aliasing_option, Settings.anti_aliasing)
	_select_by_metadata(shadow_quality_option, Settings.shadow_quality)
	_select_by_metadata(render_scale_option, Settings.render_scale_percent)
	screen_effects_check.button_pressed = Settings.screen_effects_enabled
	day_night_check.button_pressed = Settings.day_night_cycle_enabled
	weather_check.button_pressed = Settings.weather_enabled
	map_lighting_check.button_pressed = Settings.map_lighting_enabled
	creature_lighting_check.button_pressed = Settings.creature_lighting_enabled
	_refreshing = false
	_update_volume_values()
	_configure_focus()

func _update_volume_values() -> void:
	%MusicValue.text = "%d%%" % roundi(music_slider.value * 100)
	%SfxValue.text = "%d%%" % roundi(sfx_slider.value * 100)

func _populate_options() -> void:
	window_mode_option.clear()
	for entry in [
		{"label": "Janela", "value": Settings.WINDOWED},
		{"label": "Janela sem bordas", "value": Settings.BORDERLESS},
		{"label": "Tela cheia", "value": Settings.FULLSCREEN},
	]:
		window_mode_option.add_item(entry.label)
		window_mode_option.set_item_metadata(window_mode_option.item_count - 1, entry.value)
	resolution_option.clear()
	for size in Settings.RESOLUTION_OPTIONS:
		resolution_option.add_item("%d x %d" % [size.x, size.y])
		resolution_option.set_item_metadata(resolution_option.item_count - 1, size)
	anti_aliasing_option.clear()
	for id in GraphicsQuality.ANTI_ALIASING_OPTIONS:
		anti_aliasing_option.add_item(String(GraphicsQuality.AA_LABELS[id]) + (" (padrão)" if id == GraphicsQuality.DEFAULT_ANTI_ALIASING else ""))
		anti_aliasing_option.set_item_metadata(anti_aliasing_option.item_count - 1, id)
	shadow_quality_option.clear()
	for id in GraphicsQuality.SHADOW_QUALITY_OPTIONS:
		shadow_quality_option.add_item(String(GraphicsQuality.SHADOW_LABELS[id]) + (" (padrão)" if id == GraphicsQuality.DEFAULT_SHADOW_QUALITY else ""))
		shadow_quality_option.set_item_metadata(shadow_quality_option.item_count - 1, id)
	render_scale_option.clear()
	for percent in GraphicsQuality.RENDER_SCALE_OPTIONS:
		render_scale_option.add_item(GraphicsQuality.render_scale_label(percent) + (" (padrão)" if percent == GraphicsQuality.DEFAULT_RENDER_SCALE else ""))
		render_scale_option.set_item_metadata(render_scale_option.item_count - 1, percent)
	ui_scale_option.clear()
	for value in Settings.UI_SCALE_OPTIONS:
		ui_scale_option.add_item("%d%%" % value)
		ui_scale_option.set_item_metadata(ui_scale_option.item_count - 1, value)

func _populate_controls() -> void:
	var lines: Array[String] = ["[b]Nos menus[/b]", "Tab / Shift + Tab — próximo controle / controle anterior", "Setas ou direcional — navegar e ajustar controles", ""]
	for action in [&"ui_cancel", &"ui_accept"]:
		var labels: Array[String] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var text := event.as_text()
				if not labels.has(text): labels.append(text)
		lines.append("%s — %s" % [_action_label(action), ", ".join(labels) if not labels.is_empty() else "sem tecla atribuída"])
	lines.append("")
	lines.append("[b]Durante a partida[/b]")
	lines.append("Espaço — finalizar turno quando o mapa está em foco")
	lines.append("Mouse — selecionar, mover, mirar e acionar controles")
	lines.append("")
	lines.append("[color=#b5c3b8]Remapeamento ainda não é suportado nesta versão.[/color]")
	controls_text.text = "\n".join(lines)

func _populate_glossary() -> void:
	glossary_text.text = "[b]Conhecimento[/b] — recurso usado para pesquisar novas tecnologias.\n\n[b]Suprimentos[/b] — capacidade logística do império; exceder o limite gera tensão.\n\n[b]PP / Produção[/b] — progresso que a cidade aplica ao item atual.\n\n[b]Doutrina[/b] — linha militar de pesquisa e suas unidades, técnicas e edifícios.\n\n[b]Lendária[/b] — unidade especial com limite global por civilização.\n\n[b]Manifestação[/b] — entidade mágica maior ligada à Transcendência.\n\n[b]ESC[/b] — cancela a mira, fecha a camada superior e só então abre a pausa."

func _show_page(index: int) -> void:
	_current_page = clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		_pages[i].visible = i == _current_page
		_category_buttons[i].button_pressed = i == _current_page
		_style_category(_category_buttons[i], i == _current_page)
	$Margin/Layout/Body/PagePanel/PageScroll.scroll_vertical = 0
	_configure_focus()
	var focus_target := _first_focusable(_pages[_current_page])
	if focus_target != null and is_visible_in_tree():
		focus_target.call_deferred("grab_focus")

func _style_category(button: Button, selected: bool) -> void:
	var style := MENU_THEME.BASE._button("button_bronze" if selected else "button_stone", Settings.ui_scale_factor())
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	if button.has_node("SelectedMark"):
		button.get_node("SelectedMark").visible = selected

func _first_focusable(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			return child
		var nested := _first_focusable(child)
		if nested != null:
			return nested
	return null

func _select_by_metadata(option: OptionButton, value: Variant) -> void:
	for i in option.item_count:
		if option.get_item_metadata(i) == value:
			option.select(i)
			return

func _action_label(action: StringName) -> String:
	return "Voltar / cancelar" if action == &"ui_cancel" else "Confirmar / ativar foco"

func _on_music_changed(value: float) -> void:
	if not _refreshing: Settings.set_music_volume(value)
	_update_volume_values()

func _on_sfx_changed(value: float) -> void:
	if not _refreshing: Settings.set_sfx_volume(value)
	_update_volume_values()

func _on_vsync_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_vsync_enabled(value)

func _on_window_mode_selected(index: int) -> void:
	if not _refreshing:
		Settings.set_window_mode(String(window_mode_option.get_item_metadata(index)))
		resolution_option.disabled = Settings.window_mode == Settings.FULLSCREEN
		_configure_focus()

func _on_resolution_selected(index: int) -> void:
	if not _refreshing: Settings.set_window_resolution(resolution_option.get_item_metadata(index))

func _on_anti_aliasing_selected(index: int) -> void:
	if not _refreshing: Settings.set_anti_aliasing(String(anti_aliasing_option.get_item_metadata(index)))

func _on_shadow_quality_selected(index: int) -> void:
	if not _refreshing: Settings.set_shadow_quality(String(shadow_quality_option.get_item_metadata(index)))

func _on_render_scale_selected(index: int) -> void:
	if not _refreshing: Settings.set_render_scale_percent(int(render_scale_option.get_item_metadata(index)))

func _on_screen_effects_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_screen_effects_enabled(value)

func _on_day_night_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_day_night_cycle_enabled(value)

func _on_weather_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_weather_enabled(value)

func _on_map_lighting_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_map_lighting_enabled(value)

func _on_creature_lighting_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_creature_lighting_enabled(value)

func _on_reset_graphics_pressed() -> void:
	Settings.reset_graphics_to_defaults()
	refresh()

func _on_ui_scale_selected(index: int) -> void:
	if not _refreshing: Settings.set_ui_scale_percent(int(ui_scale_option.get_item_metadata(index)))

func _on_reduced_motion_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_reduced_motion(value)
