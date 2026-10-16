extends GutTest

## Clima cosmético, rodada 2: neve (WeatherKinds + WeatherSchedule generalizada + WeatherController com um efeito por
## tipo + look da neve na luz + terreno e vegetação levemente esbranquiçados por shader). A chuva continua a mesma.

## Simula `hours` de partida em passos de 1 s: lista de eventos [{kind, start, end}].
func _simulate(seed_value: int, hours: float) -> Array:
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var events: Array = []
	var current := {}
	for second in int(hours * 3600.0):
		schedule.advance(1.0, rng)
		if schedule.is_active() and current.is_empty():
			current = {"kind": schedule.kind, "start": schedule.match_seconds}
		if schedule.is_active():
			assert_true(schedule.kind == current.kind, "um evento nunca troca de tipo no meio")
			var other := WeatherKinds.SNOW if schedule.kind == WeatherKinds.RAIN else WeatherKinds.RAIN
			if schedule.intensity(other) > 0.0:
				assert_true(false, "dois climas ao mesmo tempo")
		if not schedule.is_active() and not current.is_empty():
			current["end"] = schedule.match_seconds
			events.append(current)
			current = {}
	return events

func test_snow_is_rarer_than_rain_and_never_overlaps():
	var rains := 0
	var snows := 0
	for seed_value in [3, 14, 15, 92, 65]:
		var previous_end := -INF
		for event in _simulate(seed_value, 10.0):
			assert_true(float(event.start) >= WeatherSchedule.MIN_MATCH_SECONDS_BEFORE_WEATHER, "nada nos primeiros 5 min")
			assert_true(float(event.start) - previous_end >= WeatherSchedule.COOLDOWN_SECONDS - 1.0, "≥ 10 min entre quaisquer climas")
			previous_end = float(event.end)
			var duration := float(event.end) - float(event.start)
			var span := WeatherKinds.duration_range(event.kind)
			assert_between(duration, span.x - 2.0, span.y + 2.0, "%s dura o previsto" % event.kind)
			if event.kind == WeatherKinds.RAIN:
				rains += 1
			else:
				snows += 1
	assert_gt(snows, 5, "neva de vez em quando em 50 h")
	assert_gt(rains, snows * 2, "a chuva é bem mais comum que a neve (%d chuvas, %d neves)" % [rains, snows])
	var snow_gap_minutes := (50.0 * 60.0) / float(snows)
	assert_between(snow_gap_minutes, 45.0, 140.0, "neve a cada ~1 h–1 h 30 em média (medido: %.0f min)" % snow_gap_minutes)

func test_the_rain_chance_is_unchanged_by_snow():
	assert_eq(WeatherKinds.kind_for_roll(0.0), WeatherKinds.RAIN)
	assert_eq(WeatherKinds.kind_for_roll(0.2999), WeatherKinds.RAIN, "chuva continua em 30%")
	assert_eq(WeatherKinds.kind_for_roll(0.3), WeatherKinds.SNOW)
	assert_eq(WeatherKinds.kind_for_roll(0.3999), WeatherKinds.SNOW, "neve 10%")
	assert_eq(WeatherKinds.kind_for_roll(0.4), "", "resto: tempo limpo")
	assert_lt(WeatherKinds.chance(WeatherKinds.SNOW), WeatherKinds.chance(WeatherKinds.RAIN))

func test_snow_settles_slowly_and_clears_soon_after_it_stops():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_event(WeatherKinds.SNOW, 240.0)
	var previous := 0.0
	var worst := 0.0
	var full_at := -1.0
	var ended_at := -1.0
	var melted_at := -1.0
	for i in 600 * 10:
		schedule.advance(0.1, rng, false)
		var cover := schedule.snow_cover()
		worst = maxf(worst, absf(cover - previous))
		previous = cover
		if full_at < 0.0 and cover >= 0.999:
			full_at = schedule.match_seconds
		if ended_at < 0.0 and not schedule.is_active():
			ended_at = schedule.match_seconds
		if ended_at >= 0.0 and melted_at < 0.0 and cover <= 0.0:
			melted_at = schedule.match_seconds
	assert_lt(worst, 0.01, "cobertura sem saltos")
	assert_gt(full_at, WeatherKinds.fade_in(WeatherKinds.SNOW), "a neve assenta aos poucos, depois que a nevasca firmou")
	assert_gt(melted_at, 0.0, "o chão volta ao normal")
	assert_lt(melted_at - ended_at, 60.0, "em menos de 1 min depois que a nevasca acaba (era > 2 min: parecia travado)")
	assert_eq(schedule.wetness(), 0.0, "neve não molha o chão como chuva")

func test_switching_kind_fades_the_current_one_out_then_starts_the_new():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_event(WeatherKinds.RAIN, 240.0)
	for i in 400:
		schedule.advance(0.1, rng, false)
	assert_almost_eq(schedule.rain_intensity(), 1.0, 0.001)
	schedule.start_event(WeatherKinds.SNOW, 240.0)
	assert_eq(schedule.kind, WeatherKinds.RAIN, "a chuva primeiro sai")
	assert_eq(schedule.state, WeatherSchedule.State.FALLING)
	var previous := schedule.rain_intensity()
	for i in 20:
		schedule.advance(0.1, rng, false)
		assert_true(schedule.rain_intensity() <= previous + 0.0001, "saída suave")
		previous = schedule.rain_intensity()
	assert_gt(previous, 0.0, "sem corte seco")
	for i in 20:
		schedule.advance(0.1, rng, false)
	assert_eq(schedule.kind, WeatherKinds.SNOW, "depois a neve começa")
	assert_eq(schedule.rain_intensity(), 0.0)
	assert_lt(schedule.snow_intensity(), 0.2, "começando como garoa de neve, não de uma vez")

func test_turning_weather_off_stops_snow_and_a_queued_switch():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_event(WeatherKinds.RAIN, 240.0)
	for i in 100:
		schedule.advance(0.1, rng, false)
	schedule.start_event(WeatherKinds.SNOW, 240.0) # troca na fila
	schedule.fade_out_now(WeatherController.DISABLE_FADE_SECONDS) # desligar cancela a troca
	for i in 3600:
		schedule.advance(1.0, rng, false)
	assert_false(schedule.is_active(), "desligado: nem a troca na fila nem um novo clima")

func test_weather_never_touches_the_global_rng():
	seed(777)
	var expected := randf()
	seed(777)
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 3600 * 4:
		schedule.advance(1.0, rng)
	assert_gt(schedule.events_started.size(), 0)
	assert_eq(randf(), expected)

# --- Controlador, luz e shaders ----------------------------------------------------------------------------------------

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

func test_each_kind_has_its_own_effect_and_only_the_active_one_shows():
	var parts := _setup()
	var weather: WeatherController = parts[0]
	var day_night: DayNightController = parts[1]
	for kind in WeatherKinds.ORDER:
		assert_not_null(weather.particles_of(kind), "%s: partículas" % kind)
		assert_not_null(weather.sound_of(kind), "%s: som" % kind)
	var snow := weather.particles_of(WeatherKinds.SNOW)
	assert_false((snow.process_material as ParticleProcessMaterial).particle_flag_align_y, "floco não é risco")
	assert_true((snow.process_material as ParticleProcessMaterial).turbulence_enabled, "floco flutua")
	assert_eq((snow.draw_pass_1.surface_get_material(0) as StandardMaterial3D).billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED)
	weather.start_match()
	weather.force_snow(300.0)
	weather.advance(60.0)
	assert_true(snow.emitting)
	assert_false(weather.particles_of(WeatherKinds.RAIN).emitting, "só o clima ativo")
	assert_eq(day_night.weather_look, WeatherKinds.look(WeatherKinds.SNOW), "luz com o look da neve")
	assert_almost_eq(day_night.weather_amount, weather.schedule.snow_intensity(), 0.001)
	assert_gt(weather.snow_cover_sent, 0.3, "neve assentando no chão")
	assert_eq(weather.wetness_sent, 0.0)
	var snow_sound := weather.sound_of(WeatherKinds.SNOW)
	if snow_sound.stream != null:
		assert_true(snow_sound.playing, "som de neve (vento de inverno)")
		assert_true((snow_sound.stream as AudioStreamOggVorbis).loop, "em loop")
	var rain_sound := weather.sound_of(WeatherKinds.RAIN)
	if rain_sound.stream != null:
		assert_false(rain_sound.playing)
	weather.stop()
	assert_false(snow.emitting)
	assert_eq(weather.snow_cover_sent, 0.0, "volta ao menu: sem neve no chão")

func test_the_snow_look_is_softer_than_rain_and_keeps_night_as_night():
	var noon := DayNightCycle.sample(DayNightCycle.noon_phase())
	var snow_look := WeatherKinds.look(WeatherKinds.SNOW)
	assert_eq(DayNightCycle.with_weather(noon, snow_look, 0.0), noon)
	var snowy := DayNightCycle.with_weather(noon, snow_look, 1.0)
	var rainy := DayNightCycle.with_weather(noon, WeatherKinds.look(WeatherKinds.RAIN), 1.0)
	assert_lt(float(snowy.sun_energy), float(noon.sun_energy))
	assert_gt(float(snowy.sun_energy), float(rainy.sun_energy), "neve fecha menos o tempo que a chuva")
	assert_lt(float(snowy.shadow_opacity), float(noon.shadow_opacity))
	var night := DayNightCycle.sample(0.0)
	assert_lt((DayNightCycle.with_weather(night, snow_look, 1.0).fog as Color).get_luminance(), 0.3, "noite com neve continua noite")

func test_terrain_and_vegetation_whiten_by_shader_not_by_new_textures():
	assert_true(ProjectSettings.has_setting("shader_globals/weather_snow_cover"))
	var terrain := FileAccess.get_file_as_string("res://shaders/terrain.gdshader")
	assert_true(terrain.contains("global uniform float weather_snow_cover;"))
	var snow_at := terrain.find("ALBEDO = mix(ALBEDO, SNOW_TINT, snow);")
	assert_gt(snow_at, 0)
	assert_lt(snow_at, terrain.find("float memory = 1.0 - smoothstep(0.5, 1.0, fog_level);"), "antes do filtro de memória da névoa de guerra")
	assert_true(terrain.contains("smoothstep(0.55, 0.85, v_world_normal.y)"), "só nas faces viradas para cima")
	var nature := FileAccess.get_file_as_string("res://shaders/nature_kit.gdshader")
	assert_true(nature.contains("global uniform float weather_snow_cover;"))
	assert_eq(NatureKitCatalog.map_material().shader.resource_path, NatureKitCatalog.MAP_SHADER_PATH, "vegetação usa o shader com neve")

## "Parar neve" (debug) ou desligar o clima com o chão coberto: a neve some em poucos segundos e o chão derrete em
## ~SNOW_MELT_SECONDS, voltando exatamente a 0 (nada fica esbranquiçado para sempre).
func test_stopping_snow_clears_the_ground_in_under_a_minute():
	var schedule := WeatherSchedule.new()
	var rng := RandomNumberGenerator.new()
	schedule.start_event(WeatherKinds.SNOW, 300.0)
	for i in 200:
		schedule.advance(1.0, rng, false)
	assert_almost_eq(schedule.snow_cover(), 1.0, 0.001, "chão todo coberto")
	schedule.fade_out_now(WeatherController.DISABLE_FADE_SECONDS)
	for i in 30:
		schedule.advance(1.0, rng, false)
	assert_between(schedule.snow_cover(), 0.05, 0.9, "derretendo visivelmente")
	for i in 30:
		schedule.advance(1.0, rng, false)
	assert_eq(schedule.snow_cover(), 0.0, "voltou ao normal")

