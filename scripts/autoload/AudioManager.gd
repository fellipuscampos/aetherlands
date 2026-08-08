extends Node

## Musica de fundo (loop) + pool de efeitos sonoros, ligados aos mesmos
## sinais que ja existem (EventBus/TurnManager) — nenhum outro sistema
## precisa saber que audio existe. Se os arquivos nao tiverem sido
## baixados, cada som e ignorado silenciosamente (ver _load_or_null) em
## vez de travar o jogo.

const MUSIC_PATH := "res://assets/audio/music/town_theme.mp3"
const MUSIC_BASE_VOLUME_DB := -10.0 # volume "cheio" (Settings.music_volume = 1.0)
const MIN_VOLUME_DB := -80.0 # silencio de verdade, pra nao depender de linear_to_db(0) = -inf

const SFX_PATHS := {
	"click": "res://assets/audio/sfx/click.ogg",
	"confirm": "res://assets/audio/sfx/confirm.ogg",
	"combat": "res://assets/audio/sfx/combat.ogg",
	"city": "res://assets/audio/sfx/city.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
}
const SFX_POOL_SIZE := 4

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)

	var music_stream = _load_or_null(MUSIC_PATH)
	if music_stream:
		if music_stream is AudioStreamMP3:
			music_stream.loop = true
		_music_player.stream = music_stream

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	_apply_music_volume()
	Settings.volume_changed.connect(_apply_music_volume)

	EventBus.notify.connect(_on_notify)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.game_over.connect(_on_game_over)
	# fog_updated dispara no fim de start_new_game/recompute_fog — cobre
	# tanto o inicio da primeira partida quanto o reinicio depois de uma
	# vitoria/derrota (que para a musica).
	EventBus.fog_updated.connect(_start_music)
	TurnManager.turn_changed.connect(_on_turn_changed)

func _apply_music_volume() -> void:
	_music_player.volume_db = MUSIC_BASE_VOLUME_DB + _linear_to_db(Settings.music_volume)

## Converte 0.0-1.0 (Settings.sfx_volume/music_volume) pra dB relativo —
## linear_to_db(0) daria -inf, entao trata silencio total como um numero
## bem baixo mas finito.
func _linear_to_db(value: float) -> float:
	if value <= 0.001:
		return MIN_VOLUME_DB
	return linear_to_db(value)

func play_sfx(kind: String) -> void:
	if not SFX_PATHS.has(kind):
		return
	var path: String = SFX_PATHS[kind]
	if not _sfx_cache.has(path):
		_sfx_cache[path] = _load_or_null(path)
	var stream: AudioStream = _sfx_cache[path]
	if stream == null:
		return
	var player := _next_free_sfx_player()
	player.stream = stream
	player.volume_db = _linear_to_db(Settings.sfx_volume)
	player.play()

func _next_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]

func _start_music() -> void:
	if _music_player.stream and not _music_player.playing:
		_music_player.play()

func _on_turn_changed(_turn_number: int, _player_index: int) -> void:
	play_sfx("confirm")

func _on_unit_selected(unit: Unit) -> void:
	if unit != null:
		play_sfx("click")

func _on_notify(_text: String, sfx_kind: String) -> void:
	if sfx_kind != "":
		play_sfx(sfx_kind)

func _on_game_over(victory: bool) -> void:
	_music_player.stop()
	play_sfx("victory" if victory else "defeat")

func _load_or_null(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	return load(path)
