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

## V-Sync (pedido do usuario apos medir FPS: "adicione nas configuracoes
## poder ativar ou desativar o vsync" — com V-Sync ligado o jogo trava no
## teto de atualizacao do monitor mesmo sobrando CPU/GPU, ~142fps medidos
## contra ~178fps com V-Sync desligado no mesmo estado; ver DisplayServer.
## window_set_vsync_mode). true (ligado) preserva o comportamento padrao
## do motor/projeto ate agora — ninguem perde a tela sem tearing so por
## essa opcao existir.
var vsync_enabled: bool = true

func _ready() -> void:
	load_settings()
	_apply_vsync()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	volume_changed.emit()
	save_settings()

func set_vsync_enabled(value: bool) -> void:
	vsync_enabled = value
	_apply_vsync()
	save_settings()

## So mexe no DisplayServer de verdade quando existe uma janela de verdade
## pra mexer (headless/GUT usa o DisplayServerHeadless, sem modo de vsync
## nenhum pra alternar) -- sem essa guarda, cada teste que muda
## vsync_enabled chamaria uma API que nao existe nesse contexto.
func _apply_vsync() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

## path e parametrizavel so pros testes GUT usarem um arquivo isolado, sem
## tocar nas configuracoes de verdade do jogador — o jogo em si sempre usa
## SETTINGS_PATH (ver SaveManager.save_game/load_game, mesmo padrao).
func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "vsync_enabled", vsync_enabled)
	cfg.save(path)

func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return # sem arquivo ainda (primeira vez rodando) — mantem os padroes
	music_volume = clamp(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clamp(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	vsync_enabled = bool(cfg.get_value("video", "vsync_enabled", vsync_enabled))
