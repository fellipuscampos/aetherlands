class_name TitleScreen
extends Control

## Menu Principal: Novo Jogo / Carregar Jogo / Configuracoes / Sair —
## pedido do usuario: "reestruturação nos huds, nos menus... baseando em
## deixar parecido com os de civilization 6 a nivel de organização". No
## Civilization o Menu Principal so tem essas acoes; a configuracao de uma
## partida nova (nome do reino/raca/rivais/dificuldade) mora numa tela
## PROPRIA e dedicada (ver GameSetupScreen.gd), aberta so depois de clicar
## "Novo Jogo" aqui — antes tudo (menu + formulario inteiro) vivia
## amontoado numa coluna so nesta MESMA tela. Main.gd escuta os sinais e
## decide o que fazer — esta tela nao mexe em HexGrid/GameManager
## diretamente. `class_name` exposto pra MAP_SIZES poder ser referenciado
## por outros scripts/testes (ex: test_game_manager.gd) e por
## GameSetupScreen.gd (dono de verdade da tela que hoje LE esse tamanho)
## sem duplicar os numeros.
##
## Roadmap "sistema de menu de jogo moderno" — pedido do usuario: "carregar
## jogo deve abrir uma tela com os jogos possiveis de carregar... o
## configuracoes deve abrir outra tela... o menu ter sistema de paginas".
## MainPage/LoadGameScreen/SettingsScreen agora sao 3 paginas irmas
## gerenciadas por um MenuPager (ver scripts/ui/MenuPager.gd) — o antigo
## SettingsPanel.tscn (painel flutuante por cima do menu) foi removido, o
## conteudo dele virou SettingsScreen.tscn (tela cheia de verdade).

signal new_game_setup_requested
signal load_game_requested(slot_id: String)

## Tamanhos de mapa da partida nova (2026-10-10): Pequeno/Médio/Grande voltam, agora como versões do MESMO continente
## em escala (ver WorldProfile — grade, área reservada e escala do ruído). Fica nesta classe só para não quebrar quem
## já referencia TitleScreen.MAP_SIZES; a fonte é o WorldProfile. A antiga MAIN_ZONE_SIZE (pegada fixa 96×60) saiu: a
## área reservada agora é por tamanho (WorldProfile.main_frame).
const MAP_SIZES := {
	"small": {"width": WorldProfile.MAP_SMALL.width, "height": WorldProfile.MAP_SMALL.height},
	"medium": {"width": WorldProfile.MAP_MEDIUM.width, "height": WorldProfile.MAP_MEDIUM.height},
	"large": {"width": WorldProfile.MAP_LARGE.width, "height": WorldProfile.MAP_LARGE.height},
}

@onready var main_page: Control = $MainPage
@onready var new_game_button: Button = $MainPage/CenterBox/Box/NewGameButton
@onready var load_game_button: Button = $MainPage/CenterBox/Box/LoadGameButton
@onready var settings_button: Button = $MainPage/CenterBox/Box/SettingsButton
@onready var quit_button: Button = $MainPage/CenterBox/Box/QuitButton
@onready var status_label: Label = $MainPage/CenterBox/Box/StatusLabel
@onready var load_game_screen: Control = $LoadGameScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var confirm_quit_dialog: ConfirmationDialog = $ConfirmQuitDialog
@onready var build_label: Label = $MainPage/BuildLabel
@onready var brand_panel: MarginContainer = $MainPage/BrandPanel
@onready var center_box: CenterContainer = $MainPage/CenterBox

var _pager: MenuPager
var _last_button: Button
const MENU_THEME := preload("res://scripts/ui/TitleMenuTheme.gd")

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	_pager = MenuPager.new([main_page, load_game_screen, settings_screen])
	_pager.reset_to(main_page)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	load_game_screen.back_requested.connect(_return_to_main)
	load_game_screen.slot_load_requested.connect(_on_slot_load_requested)
	settings_screen.back_requested.connect(_return_to_main)
	confirm_quit_dialog.confirmed.connect(AudioManager.request_quit)
	confirm_quit_dialog.canceled.connect(func(): quit_button.grab_focus())
	build_label.text = "EM DESENVOLVIMENTO" if OS.is_debug_build() else "ESTRATÉGIA 4X · FANTASIA MEDIEVAL"
	main_page.visibility_changed.connect(_restore_main_focus)
	visibility_changed.connect(_restore_main_focus)
	for button in [new_game_button, load_game_button, settings_button, quit_button]:
		button.focus_entered.connect(_update_context.bind(button))
		button.mouse_entered.connect(_update_context.bind(button))
		button.mouse_exited.connect(_restore_context)
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()
	refresh_load_button()
	new_game_button.call_deferred("grab_focus")

func _apply_accessibility_theme() -> void:
	theme = Settings.build_ui_theme()
	main_page.theme = MENU_THEME.build(Settings.ui_scale_factor())
	# Pixel lettering for the wordmark/buttons, smooth readable text for explanations.
	for label in [status_label, build_label, $MainPage/NavigationHint,
			$MainPage/CenterBox/Box/ContextLabel, $MainPage/BrandPanel/BrandBox/Description]:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_font_size_override("font_size", roundi(16 * Settings.ui_scale_factor()))
	_layout_for_viewport.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _pager.current() != main_page:
		_return_to_main()
		get_viewport().set_input_as_handled()

func _layout_for_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := Settings.ui_scale_factor()
	var compact := viewport_size.y < 800 or factor > 1.1
	var edge := roundf(clampf(viewport_size.x * .07, 32, 160))
	var menu_width := minf(roundf(400 * factor), viewport_size.x - edge * 2)
	var logo: Label = $MainPage/BrandPanel/BrandBox/Brand
	logo.add_theme_font_size_override("font_size", roundi(minf(64 * factor, menu_width / 6.6)))
	$MainPage/BrandPanel/BrandBox/Heraldry.visible = not compact
	$MainPage/BrandPanel/BrandBox/Description.visible = viewport_size.y >= 600 and not (compact and factor > 1.1)
	$MainPage/BrandPanel/BrandBox/Heraldry/Kicker.add_theme_font_size_override("font_size", roundi(16 * factor))
	var box: VBoxContainer = $MainPage/CenterBox/Box
	box.custom_minimum_size.x = menu_width
	box.add_theme_constant_override("separation", roundi(12 * factor))
	for button in [new_game_button, load_game_button, settings_button, quit_button]:
		button.custom_minimum_size.y = roundf((60 if compact else 64) * factor)
	new_game_button.custom_minimum_size.y += 8
	var brand_height := brand_panel.get_combined_minimum_size().y
	var menu_height := box.get_combined_minimum_size().y
	var gap := 24.0 if compact else 36.0
	var top := maxf(24, roundf((viewport_size.y - brand_height - gap - menu_height - 32) / 2))
	brand_panel.position = Vector2(edge, top)
	brand_panel.size = Vector2(menu_width + 32, brand_height)
	center_box.position = Vector2(edge, top + brand_height + gap)
	center_box.size = Vector2(menu_width, menu_height)
	var caption: Label = $MainPage/WorldCaption
	caption.visible = viewport_size.x >= 1100 and menu_width < viewport_size.x * .5
	caption.add_theme_font_size_override("font_size", roundi(24 * minf(factor, 1.25)))
	caption.position = Vector2(roundf(viewport_size.x * .61), viewport_size.y - 160)
	caption.size = Vector2(viewport_size.x * .35, 64)
	var hint: Label = $MainPage/NavigationHint
	hint.position = Vector2(edge, viewport_size.y - 42)
	hint.size = Vector2(menu_width, 24)
	build_label.position = Vector2(viewport_size.x - edge - 400, viewport_size.y - 42)
	build_label.size = Vector2(400, 24)
	build_label.visible = viewport_size.x >= 1100

func refresh_load_button() -> void:
	load_game_button.disabled = not SaveManager.has_any_slots()
	load_game_button.tooltip_text = "Nenhuma partida salva ainda." if load_game_button.disabled else "Escolha uma partida salva para continuar."
	_rebuild_focus_order()
	_restore_context()

func _rebuild_focus_order() -> void:
	var buttons: Array[Button] = [new_game_button, settings_button, quit_button]
	if not load_game_button.disabled:
		buttons.insert(1, load_game_button)
	for i in buttons.size():
		var button := buttons[i]
		var previous := button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		var next := button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_neighbor_top = previous
		button.focus_previous = previous
		button.focus_neighbor_bottom = next
		button.focus_next = next
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)

func _update_context(button: Button) -> void:
	var context: Label = $MainPage/CenterBox/Box/ContextLabel
	if button == new_game_button:
		context.text = "Escolha seu povo e funde um novo reino."
	elif button == load_game_button:
		context.text = "Nenhuma partida salva ainda." if button.disabled else "Retome a história de um reino salvo."
	elif button == settings_button:
		context.text = "Áudio, vídeo, controles e acessibilidade."
	else:
		context.text = "Encerrar Aetherlands."

func _restore_context() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	_update_context(focused if focused is Button and main_page.is_ancestor_of(focused) else new_game_button)

func _return_to_main() -> void:
	_pager.back()
	refresh_load_button()
	_restore_main_focus()

func _restore_main_focus() -> void:
	if is_visible_in_tree() and main_page.visible:
		var target := _last_button if is_instance_valid(_last_button) and not _last_button.disabled else new_game_button
		target.call_deferred("grab_focus")

## Usado pelo Main.gd quando carregar falha (save corrompido/versao velha)
## — nesse ponto a HUD ainda esta escondida, entao o toast normal de
## EventBus.notify nao apareceria pra ninguem ver.
func show_error(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()
	_layout_for_viewport.call_deferred()

func _on_new_game_pressed() -> void:
	new_game_setup_requested.emit()

func _on_load_game_pressed() -> void:
	_last_button = load_game_button
	load_game_screen.refresh()
	_pager.go_to(load_game_screen)

func _on_settings_pressed() -> void:
	_last_button = settings_button
	settings_screen.refresh()
	_pager.go_to(settings_screen)
	settings_screen._show_page(0)

## Carregar da tela de titulo nunca tem partida em andamento pra perder —
## repassa direto, sem confirmacao nenhuma (diferente de PauseMenu, ver
## PauseMenu._on_slot_load_requested).
func _on_slot_load_requested(slot_id: String) -> void:
	load_game_requested.emit(slot_id)

func _on_quit_pressed() -> void:
	confirm_quit_dialog.popup_centered()
