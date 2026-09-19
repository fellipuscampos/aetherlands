extends Control

## Tela cheia de Configuracoes — Roadmap "sistema de menu de jogo moderno"
## (pedido do usuario: "o configuracoes deve abrir outra tela com de fato
## as configuracoes do jogo, como volume e nao abrir um dropdown por cima
## do menu atual"). Substitui o antigo SettingsPanel.tscn (painel
## flutuante). Reusada por TitleScreen (show_debug=false, sem partida
## ativa pro Debug mexer) e PauseMenu (show_debug=true).
##
## Debug continua sendo o painel ja existente em HUD.debug_panel (ver
## HUD._on_debug_pressed, com todos os botoes de toggle-debug/revelar-
## mapa/ouro/pesquisa/vitoria-derrota/dragao, ja testados) — so o GATILHO
## mora aqui agora ("la dentro tambem vai o debug, onde ao clicar em
## debug voce abre outra tela habilitando o que quer do debug ativo": essa
## "outra tela" e o debug_panel que ja existe). debug_requested e quem o
## dono (PauseMenu) usa pra chamar hud._on_debug_pressed(), exatamente como
## ja fazia antes desta mudanca.

@export var show_debug: bool = true

signal back_requested
signal debug_requested

@onready var music_slider: HSlider = $CenterBox/Box/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $CenterBox/Box/SfxRow/SfxSlider
@onready var vsync_check_button: CheckButton = $CenterBox/Box/VSyncRow/VSyncCheckButton
@onready var debug_button: Button = $CenterBox/Box/DebugButton
@onready var back_button: Button = $CenterBox/Box/BackButton

func _ready() -> void:
	refresh()
	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	vsync_check_button.toggled.connect(Settings.set_vsync_enabled)
	debug_button.visible = show_debug
	debug_button.pressed.connect(func(): debug_requested.emit())
	back_button.pressed.connect(func(): back_requested.emit())

## Reflete o valor atual de Settings — chamado no _ready() e de novo pelo
## dono antes de navegar pra esta pagina (o valor pode ter mudado em outra
## instancia, ex: TitleScreen vs PauseMenu usando duas instancias
## diferentes desta cena).
func refresh() -> void:
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	vsync_check_button.button_pressed = Settings.vsync_enabled
