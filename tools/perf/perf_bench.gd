extends Node

## Benchmark reproduzível de desempenho (rodada de otimização de 14/10/2026, ver docs/PERFORMANCE_GUIDE.md §6).
## Ferramenta de desenvolvimento: não é referenciada pelo jogo.
##
## Janela (GPU + CPU por quadro, memória de vídeo, draw calls):
##   godot --path . res://tools/perf/PerfBench.tscn -- --out=user://perf_baseline.json
## Headless (só CPU: geração, névoa, turnos):
##   godot --headless --path . res://tools/perf/PerfBench.tscn -- --out=user://perf_cpu.json
##
## Opções (depois de `--`): --out=<arquivo> --seed=<n> --size=<id do WorldProfile> --rivals=<n>
## --late_turns=<n> (turnos jogados pela IA em todos os assentos antes do cenário "late") --frames=<n>
## --scenarios=a,b,c (padrão: todos).

const MAIN_SCENE := "res://scenes/main/Main.tscn"

var _opts := {
	"out": "user://perf_bench.json",
	"seed": "4242",
	"size": "large",
	"rivals": "3",
	"late_turns": "40",
	"frames": "300",
	"scenarios": "",
	"feat_zoom": "max",
	"feat_reveal": "1",
}
var _results := {}
var _main: Node3D
var _grid: HexGrid
var _headless := false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
	# Watchdog: um erro de script aborta _run antes do quit e a janela ficaria aberta.
	get_tree().create_timer(900.0).timeout.connect(func(): push_error("perf_bench watchdog"); get_tree().quit(2))
	_run.call_deferred()

func _wanted(name: String) -> bool:
	var list := String(_opts.scenarios)
	return list.is_empty() or name in list.split(",")

func _run() -> void:
	if not _headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_results["machine"] = {
		"renderer": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"headless": _headless,
	}
	var t0 := Time.get_ticks_usec()
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(_main)
	_results["main_instantiate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	_main.get_node("UILayer/TitleScreen").visible = false
	_main.get_node("UILayer/GameSetupScreen").visible = false
	_grid = _main.get_node("HexGrid")

	var profile := WorldProfile.by_id(String(_opts.size))
	if profile.is_empty():
		profile = WorldProfile.default_size()
	GameManager.map_width = int(profile.width)
	GameManager.map_height = int(profile.height)
	GameManager.rival_count = int(_opts.rivals)
	GameManager.human_race = "human"
	GameManager.difficulty = "normal"
	GameManager.stagger_ai_turns = false
	_results["map"] = "%dx%d seed %s rivals %s" % [GameManager.map_width, GameManager.map_height, _opts.seed, _opts.rivals]

	t0 = Time.get_ticks_usec()
	_grid.visible = true
	_grid.generate_map(GameManager.map_width, GameManager.map_height, int(_opts.seed))
	_results["generate_map_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	GameManager.start_new_game(_grid)
	_results["start_new_game_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	SelectionManager.reset()
	var cam: RTSCamera = _main.camera_rig
	cam.reset_view(_main._human_camera_focus())
	_main._enter_gameplay()
	# Visual determinístico: meio-dia (ciclo desligado) e sem clima aleatório durante a medição.
	_main.day_night.set_enabled(false)
	_main.weather.set_enabled(false)

	_measure_cpu_fog("fog_early")
	if _wanted("start_default"):
		await _scenario("start_default", func(): cam.reset_view(_main._human_camera_focus()))
	if _wanted("start_zoom_max"):
		await _scenario("start_zoom_max", func(): _set_zoom(cam, cam.max_zoom))
	if _wanted("start_zoom_min"):
		await _scenario("start_zoom_min", func(): _set_zoom(cam, cam.min_zoom))
	if _wanted("revealed_zoom_max"):
		await _scenario("revealed_zoom_max", func():
			_grid.set_debug_fog_disabled(true)
			_set_zoom(cam, cam.max_zoom))
		_grid.set_debug_fog_disabled(false)
	if _wanted("features"):
		await _feature_costs(cam)

	var late := int(_opts.late_turns)
	if late > 0 and (_wanted("late_default") or _wanted("late_revealed") or _wanted("late_night")):
		GameManager.ai_controls_human_seat = true
		var turn_times: Array = []
		for i in range(late):
			if GameManager.state != GameManager.GameState.PLAYING:
				break
			var tt := Time.get_ticks_usec()
			TurnManager.end_turn()
			turn_times.append((Time.get_ticks_usec() - tt) / 1000.0)
			if not _headless:
				await get_tree().process_frame
		GameManager.ai_controls_human_seat = false
		_results["late_turns"] = _stats(turn_times)
		_results["late_turn_count"] = turn_times.size()
		_results["late_units"] = _count_units()
		_measure_cpu_fog("fog_late")
		if _wanted("turn_spikes") and not _headless:
			await _turn_spikes(5)
		if _wanted("late_default"):
			await _scenario("late_default", func(): cam.reset_view(_main._human_camera_focus()))
		if _wanted("late_revealed"):
			await _scenario("late_revealed", func():
				_grid.set_debug_fog_disabled(true)
				cam.reset_view(_main._human_camera_focus())
				_set_zoom(cam, cam.max_zoom))
		if _wanted("late_night"):
			await _scenario("late_night", func():
				_main.day_night.set_enabled(true)
				_main.day_night.set_phase(DayNightCycle.phase_for_minute(0.0))
				_set_zoom(cam, cam.max_zoom), 2.8)
	_results["memory_end"] = _memory()
	_results["census"] = _texture_usage()
	var f := FileAccess.open(String(_opts.out), FileAccess.WRITE)
	f.store_string(JSON.stringify(_results, "  "))
	f.close()
	print("PERF_BENCH_DONE ", ProjectSettings.globalize_path(String(_opts.out)))
	print(JSON.stringify(_results, "  "))
	get_tree().quit(0)

## Custo de cada efeito no cenário pesado (mapa revelado, zoom máximo): desliga um de cada vez e mede de novo.
## Só diagnóstico — o jogo nunca passa por aqui.
func _feature_costs(cam: RTSCamera) -> void:
	_grid.set_debug_fog_disabled(String(_opts.feat_reveal) == "1")
	cam.reset_view(_main._human_camera_focus())
	if String(_opts.feat_zoom) == "max":
		_set_zoom(cam, cam.max_zoom)
	var env: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := _main.get_node("Sun") as DirectionalLight3D
	var vp := get_viewport()
	var nature: Array = _grid.find_children("Nature_*", "MultiMeshInstance3D", true, false)
	var toggles := {
		"ssao": [func(): env.ssao_enabled = false, func(): env.ssao_enabled = true],
		"ssr": [func(): env.ssr_enabled = false, func(): env.ssr_enabled = true],
		"glow": [func(): env.glow_enabled = false, func(): env.glow_enabled = true],
		"env_fog": [func(): env.fog_enabled = false, func(): env.fog_enabled = true],
		"shadows": [func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true],
		"msaa": [func(): vp.msaa_3d = Viewport.MSAA_DISABLED, func(): GraphicsQuality.apply_anti_aliasing(vp, Settings.anti_aliasing)],
		"nature_shadows": [
			func(): for n in nature: n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			func(): for n in nature: n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON],
		"nature": [func(): for n in nature: n.visible = false, func(): for n in nature: n.visible = true],
		"hud": [func(): _main.get_node("UILayer").visible = false, func(): _main.get_node("UILayer").visible = true],
		"anim": [func(): _set_mixers_active(false), func(): _set_mixers_active(true)],
		# Comparação A/B: alcance fixo do perfil (o comportamento anterior a 2026-10-14) contra o ajustado à vista.
		"shadow_fit": [func(): GraphicsQuality.apply_shadows(sun, Settings.shadow_quality), func(): _main._fit_shadows_to_view()],
	}
	await _scenario("feat_all_on", func(): pass)
	for key in toggles:
		await _scenario("feat_no_" + key, toggles[key][0])
		toggles[key][1].call()
	_grid.set_debug_fog_disabled(false)

## O que o jogador sente ao Encerrar Turno no jogo real (IA espalhada por quadros, stagger_ai_turns): o quadro do
## clique (fase síncrona: estratégia, cidades, economia) e os quadros seguintes enquanto a fila de IA drena.
func _turn_spikes(turns: int) -> void:
	GameManager.stagger_ai_turns = true
	var first: Array = []
	var during: Array = []
	for i in turns:
		if GameManager.state != GameManager.GameState.PLAYING:
			break
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		TurnManager.end_turn()
		first.append((Time.get_ticks_usec() - t) / 1000.0)
		var last := Time.get_ticks_usec()
		var guard := 0
		while GameManager.is_turn_processing and guard < 5000:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			during.append((now - last) / 1000.0)
			last = now
			guard += 1
	GameManager.stagger_ai_turns = false
	_results["turn_click_ms"] = _stats(first)
	_results["turn_drain_frame_ms"] = _stats(during)
	print("turn_spikes click avg %.1f max %.1f | drain frames %d p95 %.1f max %.1f" % [
		_results.turn_click_ms.avg, _results.turn_click_ms.max, during.size(), _results.turn_drain_frame_ms.p95, _results.turn_drain_frame_ms.max])

func _set_mixers_active(active: bool) -> void:
	for m in get_tree().root.find_children("*", "AnimationMixer", true, false):
		(m as AnimationMixer).active = active

func _set_zoom(cam: RTSCamera, distance: float) -> void:
	cam._zoom(distance - cam._zoom_distance) # caminho real: emite zoom_changed (alcance das sombras)

func _count_units() -> Dictionary:
	var units := 0
	var cities := 0
	for p in GameManager.players:
		units += p.units.size()
		cities += p.cities.size()
	return {"units": units, "cities": cities, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}

func _measure_cpu_fog(label: String) -> void:
	var best := 1e18
	for i in range(5):
		var t := Time.get_ticks_usec()
		_grid.recompute_fog(GameManager.human_player)
		best = min(best, Time.get_ticks_usec() - t)
	_results[label + "_recompute_ms"] = best / 1000.0

func _scenario(name: String, setup: Callable, settle: float = 0.6) -> void:
	setup.call()
	if _headless:
		return
	await get_tree().create_timer(settle).timeout
	for i in range(60):
		await get_tree().process_frame
	var rid := get_viewport().get_viewport_rid()
	var frame: Array = []
	var gpu: Array = []
	var cpu_render: Array = []
	var process: Array = []
	var draw := 0.0
	var prims := 0.0
	var objs := 0.0
	var n := int(_opts.frames)
	var last := Time.get_ticks_usec()
	for i in range(n):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu_render.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_results[name] = {
		"frame_ms": _stats(frame),
		"fps_avg": 1000.0 / float(_stats(frame).avg),
		"gpu_ms": _stats(gpu),
		"cpu_render_ms": _stats(cpu_render),
		"process_ms": _stats(process),
		"draw_calls": draw / n,
		"primitives": prims / n,
		"objects": objs / n,
		"shadow_max_distance": (_main.get_node("Sun") as DirectionalLight3D).directional_shadow_max_distance,
		"memory": _memory(),
	}
	print("%-20s fps %6.1f  frame %5.2f ms  gpu %5.2f  cpu_render %5.2f  process %5.2f  draws %6.0f  prims %8.0f" % [
		name, _results[name].fps_avg, _results[name].frame_ms.avg, _results[name].gpu_ms.avg,
		_results[name].cpu_render_ms.avg, _results[name].process_ms.avg, draw / n, prims / n])

func _memory() -> Dictionary:
	return {
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
	}

## Censo da árvore de cena: texturas usadas pelos materiais vivos (tamanho estimado na GPU) e triângulos por malha
## (triângulos da malha × instâncias desenhadas), dos maiores aos menores.
func _texture_usage() -> Dictionary:
	var textures := {}
	var meshes := {}
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var mats: Array = [gi.material_override, gi.material_overlay]
		var mesh: Mesh = null
		var count := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
			for s in (gi as MeshInstance3D).get_surface_override_material_count():
				mats.append((gi as MeshInstance3D).get_surface_override_material(s))
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			count = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh != null:
			for s in mesh.get_surface_count():
				mats.append(mesh.surface_get_material(s))
			var key := mesh.resource_path if not mesh.resource_path.is_empty() else "%s:%s" % [gi.get_class(), gi.name.rstrip("0123456789")]
			var tris := 0
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				var idx = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var row: Dictionary = meshes.get(key, {"tris": tris, "instances": 0, "nodes": 0, "shadow": 0})
			row.instances += count
			row.nodes += 1
			if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				row.shadow += 1
			meshes[key] = row
		for m in mats:
			_collect_textures(m, textures)
	var tex_rows: Array = []
	var total := 0.0
	for t in textures:
		var layers: int = t.get_layers() if t is TextureLayered else 1
		var mb: float = t.get_width() * t.get_height() * layers * 4 * 1.333 / 1048576.0
		total += mb
		tex_rows.append([mb, "%7.2f MB %4dx%-4d x%d %s" % [mb, t.get_width(), t.get_height(), layers, t.resource_path]])
	tex_rows.sort_custom(func(a, b): return a[0] > b[0])
	var mesh_rows: Array = []
	var total_tris := 0
	for key in meshes:
		var r: Dictionary = meshes[key]
		var t := int(r.tris) * int(r.instances)
		total_tris += t
		mesh_rows.append([t, "%9d tris = %6d x %5d inst (%d nodes, %d shadow) %s" % [t, r.tris, r.instances, r.nodes, r.shadow, key]])
	mesh_rows.sort_custom(func(a, b): return a[0] > b[0])
	var mixers := {}
	for m in get_tree().root.find_children("*", "AnimationMixer", true, false):
		var owner_node: Node = m
		while owner_node != null and not (owner_node is Unit or owner_node is City or owner_node is Building or owner_node is LairStructure):
			owner_node = owner_node.get_parent()
		var key := (owner_node.get_class() + ":" + str(owner_node.get_script().get_global_name())) if owner_node != null else "other:" + str(m.get_path())
		var row: Array = mixers.get(key, [0, 0, 0])
		row[0] += 1
		if (m as AnimationMixer).active and (m as Node).can_process():
			row[1] += 1
		if m.get_parent() is Node3D and (m.get_parent() as Node3D).is_visible_in_tree():
			row[2] += 1
		mixers[key] = row
	return {
		"mixers_total_active_visible": mixers,
		"texture_count": tex_rows.size(), "texture_rgba8_mb": total,
		"textures": tex_rows.slice(0, 60).map(func(r): return r[1]),
		"scene_tris": total_tris,
		"meshes": mesh_rows.slice(0, 60).map(func(r): return r[1]),
	}

func _collect_textures(material, out: Dictionary) -> void:
	if material == null:
		return
	if material is BaseMaterial3D:
		for p in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, BaseMaterial3D.TEXTURE_ORM]:
			var t: Texture2D = (material as BaseMaterial3D).get_texture(p)
			if t != null:
				out[t] = true
	elif material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		for u in (material as ShaderMaterial).shader.get_shader_uniform_list():
			var v = (material as ShaderMaterial).get_shader_parameter(u.name)
			if v is Texture2D:
				out[v] = true
			elif v is Texture2DArray:
				out[v] = true
	if material is Material and (material as Material).next_pass != null:
		_collect_textures((material as Material).next_pass, out)

func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += float(v)
	return {
		"avg": total / sorted.size(),
		"p50": sorted[int(sorted.size() * 0.5)],
		"p95": sorted[min(sorted.size() - 1, int(sorted.size() * 0.95))],
		"max": sorted[-1],
	}
