extends PanelContainer

## Painel de configuracoes reutilizavel — instanciado tanto na TitleScreen
## quanto no PauseMenu (mesma cena, dois lugares), pra ajustar volume sem
## precisar duplicar a logica de slider em cada tela. So mexe em
## Settings.gd; quem o abre/fecha decide (toggle()/close() publicos).

@onready var music_slider: HSlider = $Box/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Box/SfxRow/SfxSlider
@onready var close_button: Button = $Box/CloseButton

func _ready() -> void:
	visible = false
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	close_button.pressed.connect(close)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	# Reflete o valor atual (pode ter mudado em outra tela, ex: TitleScreen
	# vs PauseMenu usando duas instancias diferentes deste painel).
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	visible = true

func close() -> void:
	visible = false
