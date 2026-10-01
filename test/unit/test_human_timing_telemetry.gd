extends GutTest

## Fase 33B — ferramenta local de tempo humano (DEV-ONLY, desligada por padrão).

const PATH := "user://balance/test_human_timing.json"

func after_each():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func test_disabled_by_default():
	assert_false(HumanTimingTelemetry.CLI_FLAG in OS.get_cmdline_user_args())
	assert_false(bool(ProjectSettings.get_setting(HumanTimingTelemetry.SETTING, false)))
	assert_false(HumanTimingTelemetry.is_enabled(), "sem flag explícita, nenhum nó/arquivo")

func test_active_time_excludes_pause_menu_loading_and_unfocused():
	var timing := HumanTimingTelemetry.new(PATH)
	timing.accumulate(2.0, "outside_match") # menu principal / loading / game over
	timing.accumulate(10.0, "active") # olhando o mapa e pensando conta
	timing.accumulate(1.5, "ai_wait")
	timing.accumulate(4.0, "paused")
	timing.accumulate(3.0, "unfocused")
	timing._on_turn_changed(2, 0)
	timing.accumulate(6.0, "active")
	timing.close_turn()
	assert_eq(timing.turns.size(), 2)
	assert_almost_eq(float(timing.turns[0].active_seconds), 11.5, 0.001, "ativo inclui a espera da IA")
	assert_almost_eq(float(timing.turns[0].ai_wait_seconds), 1.5, 0.001)
	assert_almost_eq(float(timing.turns[0].paused_seconds), 4.0, 0.001, "pausa fica fora do ativo")
	assert_almost_eq(float(timing.turns[0].unfocused_seconds), 3.0, 0.001, "janela sem foco fica fora do ativo")
	assert_eq(int(timing.turns[1].turn), 2)
	var summary := timing.summary()
	assert_almost_eq(float(summary.final_active_seconds), 17.5, 0.001)
	assert_eq(int(summary.final_turn), 2)
	assert_eq(int(summary.turn_buckets["1-30"].turns), 2)
	assert_almost_eq(float(summary.turn_buckets["1-30"].seconds_per_turn), 8.75, 0.001)
	timing.free()

func test_file_is_local_numeric_only():
	var timing := HumanTimingTelemetry.new(PATH)
	timing.accumulate(5.0, "active")
	timing._on_turn_changed(2, 0)
	assert_true(FileAccess.file_exists(PATH), "grava só em user://balance")
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(data.schema, "aetherlands-human-timing-v1")
	for record in data.turns:
		for key in record:
			assert_true(typeof(record[key]) in [TYPE_INT, TYPE_FLOAT], "registro sem texto/dados pessoais: %s" % key)
	timing.free()
