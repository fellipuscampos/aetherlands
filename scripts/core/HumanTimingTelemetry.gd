class_name HumanTimingTelemetry
extends Node

## Fase 33B — ferramenta DEV-ONLY de tempo humano para a calibração da F33D (turnos → horas).
##
## DESLIGADA por padrão: o jogo normal não cria este nó (Main só o adiciona quando is_enabled()), então
## release/normal = zero arquivos, zero UI, zero custo. Liga somente em build de desenvolvimento com
## o argumento de usuário `--human-timing` (godot ... -- --human-timing) ou com a ProjectSetting
## `debug/balance_human_timing = true`.
##
## Local e privado: nenhum acesso à rede; grava só números em
## user://balance/human_timing/session_<n>.json (turno, segundos ativos/pausados/fora de foco/espera
## da IA). Nada de texto digitado, nome do reino, caminhos, dados do SO ou identificador de hardware.
##
## Tempo ATIVO = partida em andamento (GameState.PLAYING), árvore não pausada e janela com foco —
## inclui olhar o mapa e pensar, e inclui a espera da IA no turno (registrada também à parte).
## Excluídos do ativo: Pause, Menu Principal/Game Over, Loading (estado != PLAYING) e janela sem foco.

const SETTING := "debug/balance_human_timing"
const CLI_FLAG := "--human-timing"
const OUTPUT_DIR := "user://balance/human_timing"
const TURN_BUCKETS := [[1, 30], [31, 80], [81, 130], [131, 100000]]

var output_path := ""
var session_start_unix := 0
var turns: Array[Dictionary] = []
var _current: Dictionary = {}
var _focused := true
var _match_index := 0
var _last_turn := 0

static func is_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	return CLI_FLAG in OS.get_cmdline_user_args() or bool(ProjectSettings.get_setting(SETTING, false))

func _init(path: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_start_unix = int(Time.get_unix_time_from_system())
	output_path = path if path != "" else "%s/session_%d.json" % [OUTPUT_DIR, session_start_unix]

func _ready() -> void:
	if not TurnManager.turn_changed.is_connected(_on_turn_changed):
		TurnManager.turn_changed.connect(_on_turn_changed)

func _exit_tree() -> void:
	if TurnManager.turn_changed.is_connected(_on_turn_changed):
		TurnManager.turn_changed.disconnect(_on_turn_changed)
	close_turn()
	write_file()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true

func _process(delta: float) -> void:
	accumulate(delta, current_bucket())

## Em qual balde o tempo deste frame cai.
func current_bucket() -> String:
	if GameManager.state != GameManager.GameState.PLAYING:
		return "outside_match"
	if get_tree() != null and get_tree().paused:
		return "paused"
	if not _focused:
		return "unfocused"
	if GameManager.is_turn_processing:
		return "ai_wait"
	return "active"

func accumulate(delta: float, bucket: String) -> void:
	if bucket == "outside_match":
		return
	if _current.is_empty():
		_open_turn(TurnManager.turn_number)
	_current[bucket] = float(_current.get(bucket, 0.0)) + delta

func _on_turn_changed(turn_number: int, _player_index: int) -> void:
	close_turn()
	if turn_number < _last_turn:
		_match_index += 1 # nova partida/load para um turno anterior na mesma sessão
	_open_turn(turn_number)
	write_file()

func _open_turn(turn_number: int) -> void:
	_last_turn = turn_number
	_current = {"match": _match_index, "turn": turn_number, "active": 0.0, "ai_wait": 0.0, "paused": 0.0, "unfocused": 0.0}

func close_turn() -> void:
	if _current.is_empty():
		return
	var record := _current.duplicate()
	record.active_seconds = snappedf(float(record.active) + float(record.ai_wait), 0.01)
	record.ai_wait_seconds = snappedf(float(record.ai_wait), 0.01)
	record.paused_seconds = snappedf(float(record.paused), 0.01)
	record.unfocused_seconds = snappedf(float(record.unfocused), 0.01)
	for key in ["active", "ai_wait", "paused", "unfocused"]:
		record.erase(key)
	turns.append(record)
	_current = {}

func summary() -> Dictionary:
	var total_active := 0.0
	var total_paused := 0.0
	var total_unfocused := 0.0
	var total_ai := 0.0
	var final_turn := 0
	var buckets := {}
	for range_pair in TURN_BUCKETS:
		buckets["%d-%s" % [range_pair[0], "+" if range_pair[1] >= 100000 else str(range_pair[1])]] = {"turns": 0, "active_seconds": 0.0}
	for record in turns:
		total_active += float(record.active_seconds)
		total_paused += float(record.paused_seconds)
		total_unfocused += float(record.unfocused_seconds)
		total_ai += float(record.ai_wait_seconds)
		final_turn = maxi(final_turn, int(record.turn))
		for range_pair in TURN_BUCKETS:
			if int(record.turn) >= int(range_pair[0]) and int(record.turn) <= int(range_pair[1]):
				var bucket: Dictionary = buckets["%d-%s" % [range_pair[0], "+" if range_pair[1] >= 100000 else str(range_pair[1])]]
				bucket.turns += 1
				bucket.active_seconds += float(record.active_seconds)
	for key in buckets:
		var bucket: Dictionary = buckets[key]
		bucket.active_seconds = snappedf(bucket.active_seconds, 0.01)
		bucket.seconds_per_turn = snappedf(bucket.active_seconds / maxf(float(bucket.turns), 1.0), 0.01)
	return {
		"session_start_unix": session_start_unix,
		"final_turn": final_turn,
		"final_active_seconds": snappedf(total_active, 0.01),
		"paused_seconds": snappedf(total_paused, 0.01),
		"unfocused_seconds": snappedf(total_unfocused, 0.01),
		"ai_wait_seconds": snappedf(total_ai, 0.01),
		"turn_buckets": buckets,
	}

func write_file() -> void:
	if output_path == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"schema": "aetherlands-human-timing-v1", "summary": summary(), "turns": turns}, "\t"))
	file.close()
