class_name WeatherController
extends Node

## Clima COSMÉTICO (pedidos do usuário 2026-10-09/10): chuva e neve de vez em quando, no mapa todo,
## com partículas que não atrapalham a visão, som próprio, luz mais fechada e efeito no chão (molhado /
## levemente esbranquiçado). Nuvens sobre unidades são exclusivas das magias elementais (EnvironmentalZoneFX).
## Nenhuma regra de jogo lê nada daqui.
##
## A agenda (WeatherSchedule) diz qual clima e quanto; os números de cada clima estão em WeatherKinds. Para cada tipo
## este nó monta UM efeito (partículas + som) a partir dos dados; todos derivam da intensidade do próprio tipo (só o
## ativo é > 0). A luz vai pelo DayNightController (o único dono do sol/ambiente), via set_weather_look. O chão vai por
## parâmetros GLOBAIS de shader (project.godot [shader_globals]): `weather_wetness` (chuva, terrain.gdshader) e
## `weather_snow_cover` (neve, terrain.gdshader e nature_kit.gdshader), enviados só quando mudam.
##
## Ciclo de vida igual ao DayNightController: criado em Main._ready; start_match() (partida nova/carregada/reiniciada,
## sempre começa sem clima), stop() (volta ao menu: zera tudo na hora), set_enabled() (Configurações -> Vídeo, um
## interruptor para todo clima; desligar faz o evento atual sair em DISABLE_FADE_SECONDS e impede novos).
## process_mode padrão: o menu de pausa congela agenda, partículas e som. A sorte é uma RandomNumberGenerator PRÓPRIA
## (nunca randf()/randi() globais da partida). Nada no save.

const DISABLE_FADE_SECONDS := 3.0
const WETNESS_SHADER_PARAM := &"weather_wetness"
const SNOW_COVER_SHADER_PARAM := &"weather_snow_cover"

## Partículas caem numa faixa PERTO DO CHÃO (nunca entre a câmera e o tabuleiro, o que viraria riscos/manchas enormes
## na frente da visão). A caixa de emissão acompanha o ponto focado (filha do CameraRig) e cresce com o zoom para cobrir
## o chão visível; a densidade por área fica constante (amount_ratio também escala com a área coberta).
const FALL_HEIGHT_PER_ZOOM := 0.3
const FALL_HEIGHT_RANGE := Vector2(1.5, 8.0)
const COVER_HALF_WIDTH_PER_ZOOM := 1.25
const COVER_HALF_DEPTH_PER_ZOOM := 0.95

var schedule := WeatherSchedule.new()
var rng := RandomNumberGenerator.new()
var enabled := true
var running := false

var camera_rig: Node3D
var day_night: DayNightController
## kind -> {particles: GPUParticles3D, process: ParticleProcessMaterial, sound: AudioStreamPlayer}
var effects: Dictionary = {}
var _last_zoom := -1.0
## Últimos valores enviados aos parâmetros globais (o RenderingServer não devolve globais fora do editor).
var wetness_sent := 0.0
var snow_cover_sent := 0.0

func setup(rig: Node3D, day_night_controller: DayNightController) -> void:
	camera_rig = rig
	day_night = day_night_controller
	for kind in WeatherKinds.ORDER:
		effects[kind] = {"particles": null, "process": null, "sound": _build_sound(kind)}
		_build_particles(kind)
	_fit_to_zoom(true)
	_apply()

## Partida nova/carregada/reiniciada: começa sem clima, com sorte nova.
func start_match() -> void:
	rng.randomize()
	schedule.reset()
	running = true
	_apply()

## Volta ao menu: tudo zerado na hora (o mapa já está escondido).
func stop() -> void:
	running = false
	schedule.reset()
	_apply()

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		schedule.fade_out_now(DISABLE_FADE_SECONDS)

## Ferramenta (debug/conferência visual): começa um clima agora, se o clima estiver ligado. Com outro tipo em andamento,
## ele sai suavemente e este começa em seguida (WeatherSchedule.start_event).
func force(kind: String, duration: float = -1.0) -> void:
	if not (running and enabled):
		return
	var span := WeatherKinds.duration_range(kind)
	schedule.start_event(kind, duration if duration > 0.0 else span.y)
	_apply()

func force_rain(duration: float = -1.0) -> void:
	force(WeatherKinds.RAIN, duration)

func force_snow(duration: float = -1.0) -> void:
	force(WeatherKinds.SNOW, duration)

## DEBUG (painel de Debug da HUD): começa o tipo pedido ou, se ele já está acontecendo, para com saída suave.
func debug_toggle(kind: String) -> void:
	if schedule.is_running(kind):
		schedule.fade_out_now(DISABLE_FADE_SECONDS)
	else:
		force(kind)

func rain_intensity() -> float:
	return schedule.rain_intensity()

func particles_of(kind: String) -> GPUParticles3D:
	return effects.get(kind, {}).get("particles")

func sound_of(kind: String) -> AudioStreamPlayer:
	return effects.get(kind, {}).get("sound")

func _process(delta: float) -> void:
	if not running:
		return
	advance(delta)

## Avança `seconds` de partida (separado de _process para os testes).
func advance(seconds: float) -> void:
	schedule.advance(seconds, rng, enabled)
	_apply()

func _apply() -> void:
	_fit_to_zoom()
	for kind in effects:
		var amount := schedule.intensity(kind)
		_apply_particles(kind, amount)
		_apply_sound(kind, amount)
	_send_global(WETNESS_SHADER_PARAM, schedule.wetness(), "wetness_sent")
	_send_global(SNOW_COVER_SHADER_PARAM, schedule.snow_cover(), "snow_cover_sent")
	if day_night != null:
		day_night.set_weather_look(WeatherKinds.look(schedule.kind), schedule.current_intensity())

## Só quando muda (seco/sem neve = nada a enviar por quadro).
func _send_global(param: StringName, value: float, sent_field: String) -> void:
	if value != float(get(sent_field)):
		RenderingServer.global_shader_parameter_set(param, value)
		set(sent_field, value)

# --- Partículas --------------------------------------------------------------------------------------------------------

func _build_particles(kind: String) -> void:
	if camera_rig == null:
		return
	var spec := WeatherKinds.particles(kind)
	var particles := GPUParticles3D.new()
	particles.name = "Weather_%s" % kind
	particles.amount = int(spec.max)
	particles.local_coords = false # caem no MUNDO; o emissor só acompanha o pan da câmera
	particles.emitting = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-60.0, -20.0, -60.0), Vector3(120.0, 40.0, 120.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.direction = (Vector3.DOWN + (spec.wind as Vector3)).normalized()
	process.spread = float(spec.spread)
	process.initial_velocity_min = float(spec.speed) * 0.9
	process.initial_velocity_max = float(spec.speed) * 1.1
	process.gravity = Vector3.ZERO
	if bool(spec.streak):
		process.particle_flag_align_y = true # o comprimento da gota segue a direção da queda
	if float(spec.turbulence) > 0.0:
		process.turbulence_enabled = true # flocos flutuando em vez de cair reto
		process.turbulence_noise_strength = float(spec.turbulence)
		process.turbulence_noise_scale = 4.0
		process.turbulence_influence_min = 0.05
		process.turbulence_influence_max = 0.15
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = spec.size
	quad.material = _particle_material(spec)
	particles.draw_pass_1 = quad
	camera_rig.add_child(particles)
	effects[kind].particles = particles
	effects[kind].process = process

## Material SOMBREADO (à noite as partículas escurecem junto com a cena) com emissão mínima para continuarem legíveis.
## Gota: quad fino em billboard em volta do eixo da queda. Floco: billboard com textura radial suave (gerada, sem arquivo).
func _particle_material(spec: Dictionary) -> StandardMaterial3D:
	var color: Color = spec.color
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = float(spec.emission)
	material.billboard_keep_scale = true
	if bool(spec.streak):
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_texture = _soft_flake_texture()
	return material

static var _flake_texture: Texture2D

static func _soft_flake_texture() -> Texture2D:
	if _flake_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.85))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 32
		texture.height = 32
		_flake_texture = texture
	return _flake_texture

## Reajusta caixa de emissão, altura de queda, tempo de vida e tamanho ao zoom da câmera (só quando o zoom muda).
func _fit_to_zoom(force_fit: bool = false) -> void:
	var zoom := _zoom_distance()
	if not force_fit and is_equal_approx(zoom, _last_zoom):
		return
	_last_zoom = zoom
	var fall := clampf(zoom * FALL_HEIGHT_PER_ZOOM, FALL_HEIGHT_RANGE.x, FALL_HEIGHT_RANGE.y)
	var scale := maxf(zoom / 15.0, 0.6) # partícula maior de longe para não sumir em menos de um pixel
	for kind in effects:
		var particles: GPUParticles3D = effects[kind].particles
		var process: ParticleProcessMaterial = effects[kind].process
		if particles == null:
			continue
		var speed := float(WeatherKinds.particles(kind).speed)
		particles.position = Vector3(0.0, fall, 0.0)
		particles.lifetime = fall / speed + 0.05
		process.emission_box_extents = Vector3(zoom * COVER_HALF_WIDTH_PER_ZOOM, 0.4, zoom * COVER_HALF_DEPTH_PER_ZOOM)
		process.scale_min = scale
		process.scale_max = scale * 1.15

func _zoom_distance() -> float:
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D if camera_rig != null else null
	return camera.position.length() if camera != null else 15.0

## Área coberta relativa ao zoom máximo: de perto a caixa é menor, então menos partículas mantêm a MESMA densidade.
func _coverage_ratio() -> float:
	return clampf(pow(_zoom_distance() / 30.0, 2.0), 0.15, 1.0)

func _apply_particles(kind: String, amount: float) -> void:
	var particles: GPUParticles3D = effects[kind].particles
	if particles == null:
		return
	var showing := amount > 0.001
	particles.amount_ratio = clampf(amount * _coverage_ratio(), 0.0, 1.0)
	if particles.emitting != showing:
		particles.emitting = showing

# --- Som ---------------------------------------------------------------------------------------------------------------

func _build_sound(kind: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "WeatherSound_%s" % kind
	add_child(player)
	AudioManager.register_ambient_player(player)
	var path := String(WeatherKinds.data(kind).get("sound_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return player # sem o arquivo: clima em silêncio, sem erro
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	return player

## Volume = efeitos (Settings.sfx_volume) x intensidade, em dB, a partir do pico do tipo. Abaixo de quase nada o player
## PARA (não gasta mixer).
func _apply_sound(kind: String, amount: float) -> void:
	var player: AudioStreamPlayer = effects[kind].sound
	if player == null or player.stream == null:
		return
	var level := amount * Settings.sfx_volume
	if level <= 0.001:
		if player.playing:
			player.stop()
		return
	player.volume_db = float(WeatherKinds.data(kind).sound_peak_db) + linear_to_db(level)
	if not player.playing:
		player.play()

func _exit_tree() -> void:
	for kind in effects:
		var player: AudioStreamPlayer = effects[kind].sound
		if player != null:
			player.stop()
			player.stream = null
