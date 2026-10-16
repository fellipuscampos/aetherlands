extends GutTest

## Ciclo de dia e noite (DayNightCycle + DayNightController): só visual, tempo real, transições graduais, meio-dia =
## visual aprovado de Main.tscn.

const MAIN_SCENE := "res://scenes/main/Main.tscn"

func _main_lighting() -> Dictionary:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var sun := main.get_node("Sun") as DirectionalLight3D
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	var result := {
		"rotation": sun.rotation_degrees, "sun_color": sun.light_color, "sun_energy": sun.light_energy, "shadow_opacity": sun.shadow_opacity,
		"ambient_energy": env.ambient_light_energy, "fog": env.fog_light_color, "exposure": env.tonemap_exposure,
		"saturation": env.adjustment_saturation, "sky_top": sky.sky_top_color, "sky_horizon": sky.sky_horizon_color,
	}
	main.free()
	return result

func _colors_close(a: Color, b: Color, tolerance: float = 0.0005) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance

func _controller() -> Array:
	var sun := DirectionalLight3D.new()
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	world.environment = env
	add_child_autofree(sun)
	add_child_autofree(world)
	var controller := DayNightController.new()
	add_child_autofree(controller)
	controller.setup(sun, world)
	return [controller, sun, world]

func test_noon_is_exactly_the_approved_lighting_of_the_main_scene():
	var noon := DayNightCycle.sample(DayNightCycle.noon_phase())
	var scene := _main_lighting()
	assert_almost_eq(float(noon.elevation), -float(scene.rotation.x), 0.001)
	assert_almost_eq(float(noon.azimuth), float(scene.rotation.y), 0.001)
	assert_true(_colors_close(noon.sun_color, scene.sun_color), "cor do sol")
	assert_almost_eq(float(noon.sun_energy), float(scene.sun_energy), 0.001)
	assert_almost_eq(float(noon.shadow_opacity), float(scene.shadow_opacity), 0.001, "sombra do meio-dia = a da cena")
	assert_almost_eq(float(noon.ambient_energy), float(scene.ambient_energy), 0.001)
	assert_true(_colors_close(noon.fog, scene.fog), "névoa")
	assert_almost_eq(float(noon.exposure), float(scene.exposure), 0.001)
	assert_almost_eq(float(noon.saturation), float(scene.saturation), 0.001)
	assert_true(_colors_close(noon.sky_top, scene.sky_top), "céu topo")
	assert_true(_colors_close(noon.sky_horizon, scene.sky_horizon), "céu horizonte")

## "Não quero que fique de noite do nada, é um fade": nenhuma grandeza salta entre dois instantes vizinhos do ciclo
## (2.400 amostras = uma a cada 0,5 s de jogo), inclusive na volta de 1,0 para 0,0.
func test_the_cycle_never_jumps():
	const SAMPLES := 2400
	var previous := DayNightCycle.sample(0.0)
	var worst := {}
	for i in range(1, SAMPLES + 1):
		var state := DayNightCycle.sample(float(i) / SAMPLES)
		for key in DayNightCycle.FLOAT_KEYS:
			worst[key] = maxf(float(worst.get(key, 0.0)), absf(float(state[key]) - float(previous[key])))
		for key in DayNightCycle.COLOR_KEYS:
			var a: Color = state[key]
			var b: Color = previous[key]
			worst[key] = maxf(float(worst.get(key, 0.0)), maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
		previous = state
	for key in DayNightCycle.COLOR_KEYS + ["sun_energy", "shadow_opacity", "ambient_energy", "exposure", "saturation"]:
		assert_lt(float(worst[key]), 0.01, "%s muda no máximo 1%% a cada 0,5 s" % key)
	assert_lt(float(worst.elevation), 0.5, "elevação do sol: menos de 0,5° a cada 0,5 s")
	assert_lt(float(worst.azimuth), 1.0, "azimute do sol: menos de 1° a cada 0,5 s (sombras giram devagar)")

func test_night_is_darker_but_readable_and_shorter_than_the_day():
	var noon := DayNightCycle.brightness(DayNightCycle.sample(DayNightCycle.noon_phase()))
	var night := DayNightCycle.brightness(DayNightCycle.sample(0.0))
	assert_lt(night, noon * 0.75, "a noite é visivelmente mais escura")
	assert_gt(night, noon * 0.5, "mas continua legível (luar, nunca breu)")
	var day_minutes := DayNightCycle.DAY_END_MINUTE - DayNightCycle.DAY_START_MINUTE
	var night_minutes := fposmod(DayNightCycle.NIGHT_END_MINUTE - DayNightCycle.NIGHT_START_MINUTE, DayNightCycle.CYCLE_MINUTES)
	assert_eq(DayNightCycle.CYCLE_SECONDS, 1200.0, "ciclo de 20 min")
	assert_gt(day_minutes, night_minutes * 2.0, "o dia dura bem mais que a noite")
	for i in 200:
		assert_true(float(DayNightCycle.sample(i / 200.0).elevation) >= DayNightCycle.MIN_ELEVATION_DEGREES - 0.001)

## O fade vai num sentido só: o entardecer escurece até a noite e o amanhecer clareia a partir dela — nenhum instante
## (crepúsculo, hora azul) fica mais escuro que a noite profunda.
func test_no_moment_is_darker_than_deep_night():
	var night := DayNightCycle.brightness(DayNightCycle.sample(0.0))
	var darkest := INF
	var darkest_minute := 0.0
	for i in 1200:
		var b := DayNightCycle.brightness(DayNightCycle.sample(i / 1200.0))
		if b < darkest:
			darkest = b
			darkest_minute = i / 60.0
	assert_gt(darkest, night * 0.97, "mais escuro no minuto %.1f (%.3f) que a noite (%.3f)" % [darkest_minute, darkest, night])

func test_the_controller_advances_in_real_time_only_while_a_match_runs():
	var parts := _controller()
	var controller: DayNightController = parts[0]
	var sun: DirectionalLight3D = parts[1]
	var noon := DayNightCycle.sample(DayNightCycle.noon_phase())
	assert_false(controller.is_cycling(), "fora da partida não corre")
	assert_almost_eq(sun.light_energy, float(noon.sun_energy), 0.001, "fora da partida: meio-dia aprovado")
	controller.advance(600.0)
	assert_almost_eq(controller.shown_phase(), DayNightCycle.noon_phase(), 0.0001)

	controller.start_match()
	assert_almost_eq(controller.phase, DayNightCycle.start_phase(), 0.0001, "partida começa no meio da manhã")
	controller.advance(60.0)
	assert_almost_eq(controller.phase, DayNightCycle.start_phase() + 60.0 / DayNightCycle.CYCLE_SECONDS, 0.0001, "1 min real = 1/20 do ciclo")
	var expected := DayNightCycle.sample(controller.phase)
	assert_almost_eq(sun.light_energy, float(expected.sun_energy), 0.001)
	assert_almost_eq(sun.rotation_degrees.y, float(expected.azimuth), 0.001)

	controller.set_enabled(false)
	assert_false(controller.is_cycling())
	assert_almost_eq(sun.light_energy, float(noon.sun_energy), 0.001, "desligado: meio-dia aprovado")
	controller.set_enabled(true)
	controller.stop()
	assert_almost_eq(sun.light_energy, float(noon.sun_energy), 0.001, "voltar ao menu: meio-dia aprovado")

func test_environment_and_sky_follow_the_cycle_in_coarse_steps():
	var parts := _controller()
	var controller: DayNightController = parts[0]
	var world: WorldEnvironment = parts[2]
	controller.start_match()
	controller.set_phase(0.0) # noite
	var night := DayNightCycle.sample(0.0)
	var env := world.environment
	assert_almost_eq(env.ambient_light_energy, float(night.ambient_energy), 0.001)
	assert_true(_colors_close((env.sky.sky_material as ProceduralSkyMaterial).sky_top_color, night.sky_top))
	assert_eq(env.sky.process_mode, Sky.PROCESS_MODE_INCREMENTAL, "radiância do céu recalculada aos poucos")
	var before := env.ambient_light_energy
	controller.advance(DayNightController.ENVIRONMENT_STEP_SECONDS * 0.4)
	assert_eq(env.ambient_light_energy, before, "ambiente/céu só mudam a cada passo")
	controller.advance(DayNightController.ENVIRONMENT_STEP_SECONDS)
	assert_almost_eq(env.ambient_light_energy, float(DayNightCycle.sample(controller.phase).ambient_energy), 0.001)

## O sol também anda em passos (10 Hz): reaplicar todo quadro custava ~0,3 ms/quadro sem diferença visível.
func test_the_sun_is_updated_in_small_steps_not_every_frame():
	var parts := _controller()
	var controller: DayNightController = parts[0]
	var sun: DirectionalLight3D = parts[1]
	controller.start_match()
	controller.set_phase(DayNightCycle.phase_for_minute(17.0)) # entardecer: o sol se move
	var before := sun.rotation_degrees
	controller.advance(DayNightController.SUN_STEP_SECONDS * 0.3)
	assert_eq(sun.rotation_degrees, before, "quadro dentro do passo não reaplica o sol")
	controller.advance(DayNightController.SUN_STEP_SECONDS)
	assert_almost_eq(sun.rotation_degrees.y, float(DayNightCycle.sample(controller.phase).azimuth), 0.001, "no passo, alcança a fase atual")

func test_the_controller_never_mutates_the_cached_scene_resources():
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	var original := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var controller := DayNightController.new()
	add_child_autofree(controller)
	controller.setup(main.get_node("Sun") as DirectionalLight3D, main.get_node("WorldEnvironment") as WorldEnvironment)
	controller.start_match()
	controller.set_phase(0.0)
	assert_almost_eq(original.ambient_light_energy, 0.2, 0.0001, "o Environment da cena em cache fica intacto")
	main.free()

func test_the_setting_persists_and_resets_to_on():
	var path := "user://test_day_night_settings.cfg"
	var previous := Settings.day_night_cycle_enabled
	Settings.day_night_cycle_enabled = false
	Settings.save_settings(path)
	Settings.day_night_cycle_enabled = true
	Settings.load_settings(path)
	assert_false(Settings.day_night_cycle_enabled, "preferência salva em settings.cfg")
	Settings.day_night_cycle_enabled = false
	var cfg := ConfigFile.new()
	cfg.load(path)
	assert_eq(cfg.get_value("graphics", "day_night_cycle"), false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.day_night_cycle_enabled = previous
	assert_true(Settings.has_method("set_day_night_cycle_enabled"))

## "Enquanto vai anoitecendo as sombras também vão desaparecendo, e enquanto amanhece elas reaparecem": sombra cheia o
## dia inteiro, nenhuma sombra na noite profunda, e o caminho entre os dois é monótono (nunca volta a escurecer a sombra
## no meio do entardecer nem a apagar no meio do amanhecer).
func test_shadows_fade_out_at_dusk_and_back_in_at_dawn():
	for minute in [DayNightCycle.DAY_START_MINUTE, 7.0, DayNightCycle.NOON_MINUTE, 13.0, DayNightCycle.DAY_END_MINUTE]:
		assert_almost_eq(float(DayNightCycle.sample(DayNightCycle.phase_for_minute(minute)).shadow_opacity), 1.0, 0.001, "dia: sombra cheia (min %.1f)" % minute)
	for minute in [19.0, 19.5, 0.0, 0.5, 1.0]:
		assert_almost_eq(float(DayNightCycle.sample(DayNightCycle.phase_for_minute(minute)).shadow_opacity), 0.0, 0.001, "noite: sem sombra (min %.1f)" % minute)
	var previous := 1.0
	for i in range(0, 211): # entardecer: 15,5 -> 19,0, a cada 1 s
		var opacity := float(DayNightCycle.sample(DayNightCycle.phase_for_minute(15.5 + i / 60.0)).shadow_opacity)
		assert_true(opacity <= previous + 0.0001, "entardecer só apaga a sombra (min %.2f)" % (15.5 + i / 60.0))
		previous = opacity
	previous = 0.0
	for i in range(0, 211): # amanhecer: 1,0 -> 4,5
		var opacity := float(DayNightCycle.sample(DayNightCycle.phase_for_minute(1.0 + i / 60.0)).shadow_opacity)
		assert_true(opacity >= previous - 0.0001, "amanhecer só acende a sombra (min %.2f)" % (1.0 + i / 60.0))
		previous = opacity
	var mid_dusk := float(DayNightCycle.sample(DayNightCycle.phase_for_minute(17.5)).shadow_opacity)
	assert_between(mid_dusk, 0.15, 0.85, "no meio do entardecer a sombra está sumindo, não ligada nem desligada")

func test_the_controller_applies_the_shadow_fade_to_the_sun():
	var parts := _controller()
	var controller: DayNightController = parts[0]
	var sun: DirectionalLight3D = parts[1]
	controller.start_match()
	controller.set_phase(0.0)
	assert_almost_eq(sun.shadow_opacity, 0.0, 0.001, "noite sem sombra")
	controller.set_phase(DayNightCycle.phase_for_minute(17.5))
	assert_almost_eq(sun.shadow_opacity, float(DayNightCycle.sample(controller.phase).shadow_opacity), 0.001)
	controller.stop()
	assert_almost_eq(sun.shadow_opacity, 1.0, 0.001, "fora da partida: sombra cheia do meio-dia")
