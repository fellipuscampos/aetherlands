extends Node

## Configuracoes persistentes do jogador (volume de musica/efeitos por
## enquanto) — separado do save de partida de proposito, porque essas
## preferencias devem sobreviver mesmo sem nenhuma partida salva/em
## andamento. Guardado em user://settings.cfg via ConfigFile (formato
## simples de texto, dispensa JSON pra um punhado de numeros).

signal volume_changed

const SETTINGS_PATH := "user://settings.cfg"

var music_volume: float = 0.8 # 0.0 a 1.0
var sfx_volume: float = 1.0

func _ready() -> void:
	load_settings()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

## path e parametrizavel so pros testes GUT usarem um arquivo isolado, sem
## tocar nas configuracoes de verdade do jogador — o jogo em si sempre usa
## SETTINGS_PATH (ver SaveManager.save_game/load_game, mesmo padrao).
func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(path)

func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return # sem arquivo ainda (primeira vez rodando) — mantem os padroes
	music_volume = clamp(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clamp(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
