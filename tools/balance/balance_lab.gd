extends Node

## Fase 33B — entrada de linha de comando do Release Balance Lab (fora da suíte GUT de propósito).
##
## Partidas (JSON bruto por partida em user://balance/<run>/<tag>/, nunca versionado):
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --matches=0-11 --tag=baseline
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --matches=5 --cap=300 --tag=extension
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --matches=0 --save-load-turn=60 --tag=saveload
## Relatório agregado (CSV + JSON + markdown) a partir dos JSON de um diretório:
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --report --tag=baseline
## Survey somente leitura do mundo inicial (covis por capital, gatilho do Dragão), Fase 33C:
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --world-survey --matches=0-47
## V3 / Combat Ecology — A/B de custo sem a ecologia (dev): acrescente `--no-ecology` a qualquer comando.
## Baseline numérica lida do código-fonte (custos/rendimentos/regras atuais):
##   godot --headless --path . res://tools/balance/BalanceLab.tscn -- --dump-baseline
##
## `--run=<nome>` escolhe o diretório (padrão phase33b). Várias instâncias podem rodar em paralelo
## com faixas de partidas disjuntas; cada partida grava o próprio arquivo.

const DEFAULT_RUN := "phase33b"

func _ready() -> void:
	call_deferred("_main")

func _main() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	# V3 / Combat Ecology: `--no-ecology` (DEV/benchmark A/B) roda sem a população ecológica. Fixture de CLI,
	# nunca salva nem exposta na UI; restaurada ao sair.
	GameManager.combat_ecology_on_new_match = not args.has("no-ecology")
	var run := String(args.get("run", DEFAULT_RUN))
	var tag := String(args.get("tag", "baseline"))
	var base_dir := "user://balance/%s" % run
	var exit_code := 0
	if args.has("dump-baseline"):
		var path := "%s/numeric_baseline.json" % base_dir
		_write_json(path, BalanceReport.numeric_baseline())
		print("[balance-lab] numeric baseline -> %s" % ProjectSettings.globalize_path(path))
	elif args.has("world-survey"):
		# Fase 33C: análise somente leitura do mundo inicial (covis perto de cada capital, gatilho do Dragão).
		var surveys := []
		for index in _parse_indices(String(args.get("matches", "0-47"))):
			surveys.append(await BalanceWorldSurvey.survey_match(self, BalanceSeedSet.match_config(index)))
		var path := "%s/world_survey.json" % base_dir
		_write_json(path, surveys)
		print("[balance-lab] world survey (%d matches) -> %s" % [surveys.size(), ProjectSettings.globalize_path(path)])
		# V3 / Combat Ecology — Etapa 1: agregado dos gates (cobertura, segurança, inválidos, distribuição).
		var ecology_path := "%s/world_survey_ecology.json" % base_dir
		var ecology_summary := BalanceWorldSurvey.summarize_ecology(surveys)
		_write_json(ecology_path, ecology_summary)
		print("[balance-lab] ecology survey -> %s" % ProjectSettings.globalize_path(ecology_path))
		print(JSON.stringify(ecology_summary, "  "))
	elif args.has("report"):
		var dir := "%s/%s" % [base_dir, tag]
		var summary := BalanceReport.build_report(dir, int(args.get("cap", BalanceSeedSet.TURN_CAP)))
		# V3 / Combat Ecology — Etapa 1: agregado da seção combat_ecology (ações por tier/era, população, alvos).
		_write_json("%s/ecology_summary.json" % dir, EcologyTelemetry.summarize(BalanceReport.load_records(dir)))
		print("[balance-lab] report -> %s (%d matches)" % [ProjectSettings.globalize_path(dir), int(summary.get("matches", 0))])
	else:
		exit_code = await _run_matches(args, base_dir, tag)
	GameManager.combat_ecology_on_new_match = true
	get_tree().quit(exit_code)

func _run_matches(args: Dictionary, base_dir: String, tag: String) -> int:
	var indices := _parse_indices(String(args.get("matches", "0")))
	var cap := int(args.get("cap", BalanceSeedSet.TURN_CAP))
	var save_load_turn := int(args.get("save-load-turn", 0))
	var out_dir := "%s/%s" % [base_dir, tag]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var batch_started := Time.get_ticks_msec()
	for index in indices:
		var config := BalanceSeedSet.match_config(index, cap)
		var started := Time.get_ticks_msec()
		var options := {"turn_cap": cap}
		if save_load_turn > 0:
			options.save_load_turn = save_load_turn
			options.save_path = "%s/tmp_%s.json" % [out_dir, config.match_id]
		var record: Dictionary = await BalanceMatchRunner.run_match(self, config, options)
		record.tag = tag
		record.performance.wall_ms = Time.get_ticks_msec() - started
		var path := "%s/%s.json" % [out_dir, config.match_id]
		_write_json(path, record)
		var victory: Dictionary = record.victory
		print("[balance-lab] %s seed=%d end=%s turn=%d winner=%s/%s wall=%.1fs turn_p95=%.0fms" % [
			config.match_id, config.seed, record.end.end_reason, int(record.end.turn),
			String(victory.get("winner_race", "-")), String(victory.get("winner_orientation", "-")),
			record.performance.wall_ms / 1000.0, float(record.performance.turn_ms.get("p95", 0.0))])
	print("[balance-lab] batch done: %d matches in %.1fs" % [indices.size(), (Time.get_ticks_msec() - batch_started) / 1000.0])
	return 0

func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in raw:
		var text := String(arg)
		if not text.begins_with("--"):
			continue
		text = text.substr(2)
		var eq := text.find("=")
		if eq < 0:
			result[text] = true
		else:
			result[text.substr(0, eq)] = text.substr(eq + 1)
	return result

## "0-11", "3", "0,5,9" ou combinações ("0-3,7").
func _parse_indices(spec: String) -> Array[int]:
	var result: Array[int] = []
	for part in spec.split(",", false):
		if part.contains("-"):
			var bounds := part.split("-")
			for i in range(int(bounds[0]), int(bounds[1]) + 1):
				result.append(i)
		else:
			result.append(int(part))
	return result

func _write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
