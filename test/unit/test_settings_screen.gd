extends GutTest

## Cobre SettingsScreen.gd — Roadmap "sistema de menu de jogo moderno"
## (pedido do usuario: "o configuracoes deve abrir outra tela com de fato
## as configuracoes do jogo, como volume... la dentro tambem vai o
## debug"). Substitui o antigo SettingsPanel.gd (painel flutuante,
## removido nesta rodada) — mesmo conteudo de volume, tela cheia de
## verdade, mais o botao condicional de Debug.

var screen: Control
var _original_music_volume: float
var _original_sfx_volume: float
var _original_vsync_enabled: bool
var _original_ui_scale: int
var _original_reduced_motion: bool

func before_each():
	_original_music_volume = Settings.music_volume
	_original_sfx_volume = Settings.sfx_volume
	_original_vsync_enabled = Settings.vsync_enabled
	_original_ui_scale = Settings.ui_scale_percent
	_original_reduced_motion = Settings.reduced_motion
	screen = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	add_child_autofree(screen)

func after_each():
	Settings.music_volume = _original_music_volume
	Settings.sfx_volume = _original_sfx_volume
	Settings.vsync_enabled = _original_vsync_enabled
	Settings.ui_scale_percent = _original_ui_scale
	Settings.reduced_motion = _original_reduced_motion

func test_music_slider_updates_settings_music_volume():
	screen.music_slider.value = 0.35

	assert_almost_eq(Settings.music_volume, 0.35, 0.001)

func test_sfx_slider_updates_settings_sfx_volume():
	screen.sfx_slider.value = 0.6

	assert_almost_eq(Settings.sfx_volume, 0.6, 0.001)

func test_refresh_reflects_current_settings_values():
	Settings.music_volume = 0.2
	Settings.sfx_volume = 0.9
	Settings.vsync_enabled = false

	screen.refresh()

	assert_almost_eq(screen.music_slider.value, 0.2, 0.001)
	assert_almost_eq(screen.sfx_slider.value, 0.9, 0.001)
	assert_false(screen.vsync_check_button.button_pressed)

func test_vsync_check_button_updates_settings_vsync_enabled():
	screen.vsync_check_button.button_pressed = false
	screen.vsync_check_button.toggled.emit(false)

	assert_false(Settings.vsync_enabled)

	screen.vsync_check_button.button_pressed = true
	screen.vsync_check_button.toggled.emit(true)

	assert_true(Settings.vsync_enabled)

## show_debug e @export, aplicado ANTES de _ready() quando setado logo
## apos instantiate() (mesmo momento em que uma sobrescrita de instancia
## num .tscn seria aplicada, ver TitleScreen.tscn/PauseMenu.tscn) — usa
## uma instancia PROPRIA em vez do fixture `screen` (que ja rodou _ready()
## com o valor padrao da cena) pra testar os dois valores de verdade.
func test_debug_button_stays_hidden_when_legacy_show_debug_is_true():
	var s: Control = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	s.show_debug = true
	add_child_autofree(s)

	assert_false(s.debug_button.visible, "Developer Tools tem rota propria")

func test_debug_button_hidden_when_show_debug_false():
	var s: Control = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	s.show_debug = false
	add_child_autofree(s)

	assert_false(s.debug_button.visible)

func test_hidden_debug_button_does_not_emit_debug_requested():
	# Caixa de 1 elemento, nao um bool solto: lambdas em GDScript capturam
	# variaveis locais por VALOR — mutar "emitted" direto dentro do lambda
	# so mudaria a copia dele. Array e passado por referencia.
	var emitted := [false]
	screen.debug_requested.connect(func(): emitted[0] = true)

	screen.debug_button.pressed.emit()

	assert_false(emitted[0])

func test_ui_scale_and_reduced_motion_controls_update_real_settings():
	var scale_index := Settings.UI_SCALE_OPTIONS.find(125)
	screen.ui_scale_option.select(scale_index)
	screen.ui_scale_option.item_selected.emit(scale_index)
	screen.reduced_motion_check.button_pressed = true
	screen.reduced_motion_check.toggled.emit(true)

	assert_eq(Settings.ui_scale_percent, 125)
	assert_true(Settings.reduced_motion)

func test_back_button_emits_back_requested():
	var emitted := [false] # ver comentario acima
	screen.back_requested.connect(func(): emitted[0] = true)

	screen.back_button.pressed.emit()

	assert_true(emitted[0])
