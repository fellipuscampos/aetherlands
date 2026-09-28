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
@onready var ui_scale_option: OptionButton = %UIScaleOption
@onready var reduced_motion_check: CheckButton = %ReducedMotionCheck
@onready var controls_text: RichTextLabel = %ControlsText
@onready var glossary_text: RichTextLabel = %GlossaryText
@onready var back_button: Button = %BackButton
@onready var debug_button: Button = %DebugButton

var _pages: Array[Control] = []
var _category_buttons: Array[Button] = []
var _refreshing := false

func _ready() -> void:
	_pages.assign([%AudioPage, %VideoPage, %AccessibilityPage, %ControlsPage, %HelpPage])
	_category_buttons.assign([%AudioCategory, %VideoCategory, %AccessibilityCategory, %ControlsCategory, %HelpCategory])
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
	ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	back_button.pressed.connect(func(): back_requested.emit())
	debug_button.visible = false
	refresh()
	_show_page(0)

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
	_refreshing = false

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
	ui_scale_option.clear()
	for value in Settings.UI_SCALE_OPTIONS:
		ui_scale_option.add_item("%d%%" % value)
		ui_scale_option.set_item_metadata(ui_scale_option.item_count - 1, value)

func _populate_controls() -> void:
	var lines: Array[String] = ["[b]Controles ativos[/b]"]
	for action in [&"ui_cancel", &"ui_accept"]:
		var labels: Array[String] = []
		for event in InputMap.action_get_events(action):
			labels.append(event.as_text())
		lines.append("%s — %s" % [_action_label(action), ", ".join(labels) if not labels.is_empty() else "sem tecla atribuída"])
	lines.append("Finalizar turno — Espaço (quando mapa e HUD aceitam atalhos)")
	lines.append("Mouse — selecionar, mover, mirar e acionar controles")
	lines.append("")
	lines.append("[color=#aab4c2]Remapeamento ainda não é suportado. Esta página descreve apenas entradas que o jogo realmente processa.[/color]")
	controls_text.text = "\n".join(lines)

func _populate_glossary() -> void:
	glossary_text.text = "[b]Conhecimento[/b] — recurso usado pela pesquisa V2.\n\n[b]Suprimentos[/b] — capacidade logística do império; exceder o limite gera tensão.\n\n[b]PP / Produção[/b] — progresso que a cidade aplica ao item atual.\n\n[b]Doutrina[/b] — linha militar de pesquisa e suas unidades, técnicas e edifícios.\n\n[b]Lendária[/b] — unidade especial limitada pelo slot global da civilização.\n\n[b]Manifestação[/b] — entidade mágica maior ligada à Transcendência.\n\n[b]ESC[/b] — cancela mira, fecha a camada superior e só então abre a pausa."

func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_category_buttons[i].button_pressed = i == index
		_style_category(_category_buttons[i], i == index)
	var focus_target := _first_focusable(_pages[index])
	if focus_target != null and is_visible_in_tree():
		focus_target.call_deferred("grab_focus")

func _style_category(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIThemeTokens.COLOR_SURFACE_RAISED if selected else Color(0, 0, 0, 0)
	style.border_width_left = 3 if selected else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = UIThemeTokens.COLOR_ACCENT if selected else Color(UIThemeTokens.COLOR_BORDER, 0.45)
	style.corner_radius_top_left = UIThemeTokens.RADIUS_CONTROL
	style.corner_radius_top_right = UIThemeTokens.RADIUS_CONTROL
	style.corner_radius_bottom_left = UIThemeTokens.RADIUS_CONTROL
	style.corner_radius_bottom_right = UIThemeTokens.RADIUS_CONTROL
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)

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

func _on_sfx_changed(value: float) -> void:
	if not _refreshing: Settings.set_sfx_volume(value)

func _on_vsync_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_vsync_enabled(value)

func _on_window_mode_selected(index: int) -> void:
	if not _refreshing:
		Settings.set_window_mode(String(window_mode_option.get_item_metadata(index)))
		resolution_option.disabled = Settings.window_mode == Settings.FULLSCREEN

func _on_resolution_selected(index: int) -> void:
	if not _refreshing: Settings.set_window_resolution(resolution_option.get_item_metadata(index))

func _on_ui_scale_selected(index: int) -> void:
	if not _refreshing: Settings.set_ui_scale_percent(int(ui_scale_option.get_item_metadata(index)))

func _on_reduced_motion_toggled(value: bool) -> void:
	if not _refreshing: Settings.set_reduced_motion(value)
