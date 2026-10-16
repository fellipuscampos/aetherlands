extends GutTest

## Clima cosmético, rodada 1: chuva (WeatherSchedule + WeatherController + luz nublada no DayNightController + chão
## molhado no terrain.gdshader). Só visual/som: de vez em quando, com rampas suaves, RNG próprio, nada no save.

## Simula `hours` de partida em passos de 1 s e devolve as chuvas: [{start, end, peak}] em segundos de partida.
func _simulate(seed_value: int, hours: float) -> Array:
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rains: Array = []
	var current := {}
	for second in int(hours * 3600.0):
		schedule.advance(1.0, rng)
		var raining := schedule.is_raining()
		if raining and current.is_empty():
			current = {"start": schedule.match_seconds, "peak": 0.0}
		if raining:
			current.peak = maxf(float(current.peak), schedule.rain_intensity())
		if not raining and not current.is_empty():
			current["end"] = schedule.match_seconds
			rains.append(current)
			current = {}
	return rains

func test_rain_happens_now_and_then_never_back_to_back():
	var all_rains: Array = []
	for seed_value in [11, 22, 33, 44, 55]:
		var rains := _simulate(seed_value, 10.0)
		assert_gt(rains.size(), 10, "seed %d: chove de vez em quando em 10 h" % seed_value)
		var previous_end := -INF
		for rain in rains:
			assert_true(float(rain.start) >= WeatherSchedule.MIN_MATCH_SECONDS_BEFORE_WEATHER, "não chove nos primeiros 5 min")
			var duration := float(rain.end) - float(rain.start)
			assert_between(duration, WeatherKinds.duration_range(WeatherKinds.RAIN).x - 2.0, WeatherKinds.duration_range(WeatherKinds.RAIN).y + 2.0, "dura de 2 a 4 min")
			assert_true(float(rain.start) - previous_end >= WeatherSchedule.COOLDOWN_SECONDS - 1.0, "nunca duas chuvas seguidas (≥ 10 min entre elas)")
			assert_almost_eq(float(rain.peak), 1.0, 0.001, "chega à chuva plena")
			previous_end = float(rain.end)
		all_rains.append_array(rains)
	# A neve (rodada 2) divide o mesmo tempo de intervalo: a chuva fica em ~1 a cada 25–30 min, ainda o clima mais comum.
	var average_gap_minutes := (10.0 * 60.0 * 5.0) / float(all_rains.size())
	assert_between(average_gap_minutes, 18.0, 40.0, "em média uma chuva a cada ~25–30 min (medido: %.1f)" % average_gap_minutes)

func test_same_seed_same_schedule():
	assert_eq(_simulate(77, 3.0), _simulate(77, 3.0))

func test_intensity_ramps_smoothly_and_the_ground_dries_slowly():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_rain(180.0)
	var previous := 0.0
	var worst := 0.0
	var dried_at := -1.0
	var stopped_at := -1.0
	for i in 400 * 10:
		schedule.advance(0.1, rng, false)
		var now := schedule.rain_intensity()
		worst = maxf(worst, absf(now - previous))
		previous = now
		if stopped_at < 0.0 and not schedule.is_raining():
			stopped_at = schedule.match_seconds
		if stopped_at >= 0.0 and dried_at < 0.0 and schedule.wetness() <= 0.0:
			dried_at = schedule.match_seconds
	assert_lt(worst, 0.01, "a intensidade nunca salta (≤ 1% a cada 0,1 s)")
	assert_gt(stopped_at, 0.0)
	assert_gt(dried_at, stopped_at + 30.0, "o chão continua molhado depois que a chuva para")

func test_turning_weather_off_fades_the_rain_out_quickly_and_prevents_new_rain():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_rain(240.0)
	for i in 600:
		schedule.advance(0.1, rng)
	assert_almost_eq(schedule.rain_intensity(), 1.0, 0.001)
	schedule.fade_out_now(WeatherController.DISABLE_FADE_SECONDS)
	var previous := schedule.rain_intensity()
	for i in 10:
		schedule.advance(0.1, rng, false)
		assert_true(schedule.rain_intensity() <= previous + 0.0001, "só diminui")
		previous = schedule.rain_intensity()
	assert_gt(previous, 0.0, "sem corte seco: ainda chovendo 1 s depois")
	for i in 30:
		schedule.advance(0.1, rng, false)
	assert_false(schedule.is_raining(), "acabou em ~3 s")
	for i in 3600 * 2:
		schedule.advance(1.0, rng, false)
	assert_false(schedule.is_raining(), "desligado: nunca começa outra")

## O clima nunca mexe no RNG global da partida (paridade por seed).
func test_weather_never_touches_the_global_rng():
	seed(4242)
	var expected := randf()
	seed(4242)
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	# Fix the private RNG too: this test must exercise rain on every run.
	rng.seed = 11
	for i in 3600:
		schedule.advance(1.0, rng)
	assert_gt(int(schedule.events_started.get(WeatherKinds.RAIN, 0)), 0)
	assert_eq(randf(), expected)

# --- Controlador --------------------------------------------------------------------------------------------------------

func _setup() -> Array:
	var rig := Node3D.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 15.0, 12.0)
	rig.add_child(camera)
	add_child_autofree(rig)
	var sun := DirectionalLight3D.new()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.sky = Sky.new()
	world.environment.sky.sky_material = ProceduralSkyMaterial.new()
	add_child_autofree(sun)
	add_child_autofree(world)
	var day_night := DayNightController.new()
	add_child_autofree(day_night)
	day_night.setup(sun, world)
	var weather := WeatherController.new()
	add_child_autofree(weather)
	weather.setup(rig, day_night)
	return [weather, day_night, sun]

func test_the_controller_drives_drops_sound_light_and_wet_ground_from_one_intensity():
	var parts := _setup()
	var weather: WeatherController = parts[0]
	var day_night: DayNightController = parts[1]
	var rain_particles := weather.particles_of(WeatherKinds.RAIN)
	var rain_sound := weather.sound_of(WeatherKinds.RAIN)
	assert_not_null(rain_particles)
	assert_eq(rain_particles.get_parent(), weather.camera_rig, "gotas acompanham o pan da câmera")
	assert_false(rain_particles.local_coords, "gotas caem no mundo")
	weather.force_rain()
	assert_false(weather.schedule.is_raining(), "fora da partida não chove")
	weather.start_match()
	assert_false(weather.schedule.is_raining(), "partida começa seca")
	assert_eq(weather.wetness_sent, 0.0)
	weather.force_rain(200.0)
	weather.advance(60.0)
	var intensity := weather.rain_intensity()
	assert_almost_eq(intensity, 1.0, 0.001)
	assert_true(rain_particles.emitting)
	assert_gt(rain_particles.amount_ratio, 0.0)
	assert_almost_eq(day_night.weather_amount, intensity, 0.001, "luz nublada = intensidade")
	assert_eq(day_night.weather_look, WeatherKinds.look(WeatherKinds.RAIN), "com o look da chuva")
	assert_almost_eq(weather.wetness_sent, weather.schedule.wetness(), 0.001, "chão molhado acompanha a chuva")
	assert_gt(weather.wetness_sent, 0.9)
	if rain_sound.stream != null:
		assert_true(rain_sound.playing, "som de chuva tocando")
		assert_true(rain_sound.stream is AudioStreamOggVorbis and (rain_sound.stream as AudioStreamOggVorbis).loop, "som em loop")
	weather.stop()
	assert_false(weather.schedule.is_raining())
	assert_false(rain_particles.emitting)
	assert_eq(day_night.weather_amount, 0.0)
	assert_eq(weather.wetness_sent, 0.0, "volta ao menu: chão seco")
	if rain_sound.stream != null:
		assert_false(rain_sound.playing)

func test_drops_stay_near_the_ground_and_scale_with_zoom():
	var parts := _setup()
	var weather: WeatherController = parts[0]
	var camera := weather.camera_rig.get_node("Camera3D") as Camera3D
	for zoom in [6.0, 15.0, 30.0]:
		camera.position = Vector3(0.0, 15.0, 12.0).normalized() * zoom
		weather.start_match()
		var drop_top := weather.particles_of(WeatherKinds.RAIN).position.y + 0.4
		assert_lt(drop_top, camera.position.y * 0.6, "zoom %.0f: as gotas nunca passam na frente da câmera" % zoom)
		var box: Vector3 = (weather.particles_of(WeatherKinds.RAIN).process_material as ParticleProcessMaterial).emission_box_extents
		assert_almost_eq(box.x, zoom * WeatherController.COVER_HALF_WIDTH_PER_ZOOM, 0.001, "cobre o chão visível")

func test_overcast_dims_the_sun_and_softens_shadows_and_zero_is_the_plain_cycle():
	var state := DayNightCycle.sample(DayNightCycle.noon_phase())
	var look := WeatherKinds.look(WeatherKinds.RAIN)
	assert_eq(DayNightCycle.with_weather(state, look, 0.0), state, "sem chuva: o ciclo puro")
	var rainy := DayNightCycle.with_weather(state, look, 1.0)
	assert_almost_eq(float(rainy.sun_energy), float(state.sun_energy) * float(look.sun_energy), 0.001)
	assert_lt(float(rainy.shadow_opacity), float(state.shadow_opacity), "sombras suaves")
	assert_lt(float(rainy.saturation), float(state.saturation))
	var night := DayNightCycle.sample(0.0)
	var rainy_night := DayNightCycle.with_weather(night, look, 1.0)
	assert_lt((rainy_night.fog as Color).get_luminance(), 0.3, "noite chuvosa continua noite (névoa não clareia)")
	var parts := _setup()
	var day_night: DayNightController = parts[1]
	var sun: DirectionalLight3D = parts[2]
	day_night.set_weather_look(look, 1.0) # ciclo parado (fora da partida): reaplica sobre o meio-dia fixo
	assert_almost_eq(sun.light_energy, float(rainy.sun_energy), 0.001)
	day_night.set_weather_look({}, 0.0)
	assert_almost_eq(sun.light_energy, float(state.sun_energy), 0.001, "parou de chover: meio-dia aprovado de novo")

func test_the_setting_persists_and_resets_to_on():
	var path := "user://test_weather_settings.cfg"
	var previous := Settings.weather_enabled
	Settings.weather_enabled = false
	Settings.save_settings(path)
	Settings.weather_enabled = true
	Settings.load_settings(path)
	assert_false(Settings.weather_enabled, "preferência salva em settings.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.weather_enabled = previous

func test_the_terrain_shader_wets_the_ground_before_the_memory_filter():
	var shader := FileAccess.get_file_as_string("res://shaders/terrain.gdshader")
	assert_true(shader.contains("global uniform float weather_wetness;"))
	var wet_at := shader.find("ALBEDO *= mix(1.0, WET_ALBEDO_DARKEN, wet);")
	var fog_at := shader.find("float memory = 1.0 - smoothstep(0.5, 1.0, fog_level);")
	assert_gt(wet_at, 0)
	assert_lt(wet_at, fog_at, "molha antes do filtro de memória: chão explorado molhado também escurece")
	assert_true(ProjectSettings.has_setting("shader_globals/weather_wetness"), "parâmetro global declarado no projeto")

## Recomeçar a chuva durante a saída (debug ou agenda) retoma da intensidade atual, sem salto.
func test_restarting_during_the_fade_out_resumes_without_a_jump():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_rain(200.0)
	for i in 400:
		schedule.advance(0.1, rng, false)
	schedule.fade_out_now(10.0)
	for i in 40:
		schedule.advance(0.1, rng, false)
	var before := schedule.rain_intensity()
	assert_between(before, 0.05, 0.95, "no meio da saída")
	schedule.start_rain(200.0)
	assert_eq(schedule.state, WeatherSchedule.State.RISING)
	assert_almost_eq(schedule.rain_intensity(), before, 0.01, "retoma do mesmo ponto")
	schedule.advance(0.1, rng, false)
	assert_true(schedule.rain_intensity() >= before, "e volta a engrossar")

