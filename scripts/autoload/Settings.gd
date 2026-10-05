extends Node

## Configuracoes persistentes do jogador (volume de musica/efeitos por
## enquanto) — separado do save de partida de proposito, porque essas
## preferencias devem sobreviver mesmo sem nenhuma partida salva/em
## andamento. Guardado em user://settings.cfg via ConfigFile (formato
## simples de texto, dispensa JSON pra um punhado de numeros).

signal volume_changed
signal video_changed
signal accessibility_changed
## V3 / Etapa 4: anti-aliasing / qualidade das sombras mudaram (Main reaplica no Viewport e no sol).
signal graphics_changed

const SETTINGS_PATH := "user://settings.cfg"
const UI_SCALE_OPTIONS: Array[int] = [80, 90, 100, 110, 125, 150]
const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const WINDOWED := "windowed"
const BORDERLESS := "borderless"
const FULLSCREEN := "fullscreen"

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
var window_mode: String = WINDOWED
var window_resolution: Vector2i = Vector2i(1600, 900)
var ui_scale_percent: int = 100
var reduced_motion: bool = false
## V3 / Etapa 4 — opções gráficas reais (GraphicsQuality): preferência do jogador, aplicada ao vivo.
var anti_aliasing: String = GraphicsQuality.DEFAULT_ANTI_ALIASING
var shadow_quality: String = GraphicsQuality.DEFAULT_SHADOW_QUALITY

func _ready() -> void:
	load_settings()
	apply_video_settings()

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
	video_changed.emit()
	save_settings()

func set_window_mode(value: String) -> void:
	window_mode = value if value in [WINDOWED, BORDERLESS, FULLSCREEN] else WINDOWED
	_apply_window_mode()
	video_changed.emit()
	save_settings()

func set_window_resolution(value: Vector2i) -> void:
	window_resolution = value if value in RESOLUTION_OPTIONS else Vector2i(1600, 900)
	_apply_resolution()
	video_changed.emit()
	save_settings()

func set_anti_aliasing(value: String) -> void:
	anti_aliasing = GraphicsQuality.valid_anti_aliasing(value)
	graphics_changed.emit()
	save_settings()

func set_shadow_quality(value: String) -> void:
	shadow_quality = GraphicsQuality.valid_shadow_quality(value)
	graphics_changed.emit()
	save_settings()

## "Restaurar padrões" da página Vídeo: só as opções gráficas (janela/resolução/V-Sync ficam como o jogador deixou).
func reset_graphics_to_defaults() -> void:
	anti_aliasing = GraphicsQuality.DEFAULT_ANTI_ALIASING
	shadow_quality = GraphicsQuality.DEFAULT_SHADOW_QUALITY
	graphics_changed.emit()
	save_settings()

func set_ui_scale_percent(value: int) -> void:
	ui_scale_percent = value if value in UI_SCALE_OPTIONS else 100
	accessibility_changed.emit()
	save_settings()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	accessibility_changed.emit()
	save_settings()

func ui_scale_factor() -> float:
	return float(ui_scale_percent) / 100.0

func motion_duration(base_duration: float) -> float:
	return 0.0 if reduced_motion else base_duration

func build_ui_theme() -> Theme:
	return UITheme.build(ui_scale_factor())

func apply_video_settings() -> void:
	_apply_vsync()
	_apply_window_mode()
	_apply_resolution()

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

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match window_mode:
		FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func _apply_resolution() -> void:
	if DisplayServer.get_name() == "headless" or window_mode == FULLSCREEN:
		return
	DisplayServer.window_set_size(window_resolution)

## path e parametrizavel so pros testes GUT usarem um arquivo isolado, sem
## tocar nas configuracoes de verdade do jogador — o jogo em si sempre usa
## SETTINGS_PATH (ver SaveManager.save_game/load_game, mesmo padrao).
func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "vsync_enabled", vsync_enabled)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution_width", window_resolution.x)
	cfg.set_value("video", "resolution_height", window_resolution.y)
	cfg.set_value("graphics", "anti_aliasing", anti_aliasing)
	cfg.set_value("graphics", "shadow_quality", shadow_quality)
	cfg.set_value("accessibility", "ui_scale_percent", ui_scale_percent)
	cfg.set_value("accessibility", "reduced_motion", reduced_motion)
	cfg.save(path)

func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return # sem arquivo ainda (primeira vez rodando) — mantem os padroes
	music_volume = clamp(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clamp(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	vsync_enabled = bool(cfg.get_value("video", "vsync_enabled", vsync_enabled))
	window_mode = String(cfg.get_value("video", "window_mode", window_mode))
	if window_mode not in [WINDOWED, BORDERLESS, FULLSCREEN]:
		window_mode = WINDOWED
	var loaded_resolution := Vector2i(
		int(cfg.get_value("video", "resolution_width", window_resolution.x)),
		int(cfg.get_value("video", "resolution_height", window_resolution.y))
	)
	window_resolution = loaded_resolution if loaded_resolution in RESOLUTION_OPTIONS else Vector2i(1600, 900)
	var loaded_scale := int(cfg.get_value("accessibility", "ui_scale_percent", ui_scale_percent))
	ui_scale_percent = loaded_scale if loaded_scale in UI_SCALE_OPTIONS else 100
	reduced_motion = bool(cfg.get_value("accessibility", "reduced_motion", reduced_motion))
	# Valor inválido/corrompido volta ao padrão (nunca uma opção inexistente).
	anti_aliasing = GraphicsQuality.valid_anti_aliasing(str(cfg.get_value("graphics", "anti_aliasing", anti_aliasing)))
	shadow_quality = GraphicsQuality.valid_shadow_quality(str(cfg.get_value("graphics", "shadow_quality", shadow_quality)))
