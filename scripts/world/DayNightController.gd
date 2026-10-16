class_name DayNightController
extends Node

## Aplica DayNightCycle no sol e no WorldEnvironment de Main — SÓ VISUAL, tempo real (nunca por turno).
##
## Corre só durante a partida e com Settings.day_night_cycle_enabled; fora disso fica no meio-dia aprovado (o visual
## de sempre). process_mode padrão (PAUSABLE): o menu de pausa (get_tree().paused) congela o ciclo junto com o resto.
## O turno da IA NÃO pausa o ciclo (é tempo real). A hora não vai para o save: partida nova ou carregada começa no meio
## da manhã (DayNightCycle.START_MINUTE).
##
## CUSTO (medido, docs/PERFORMANCE_GUIDE.md 2.12): reaplicar o sol em TODO quadro custava ~0,3 ms/quadro (~245 -> ~229
## FPS sem V-Sync; congelado no mesmo estado de luz, o custo sumia — era o update, não a luz da manhã/noite). Num ciclo
## de 20 min o sol anda no máximo ~1°/s (à noite, sombra fraca) e ~0,1°/s de dia: passos de SUN_STEP_SECONDS (10 Hz)
## são tão invisíveis quanto 240 Hz. Céu e ambiente mudam em passos de ENVIRONMENT_STEP_SECONDS (mudar o
## ProceduralSkyMaterial recalcula a radiância de onde vem a luz ambiente; cada passo de 2 s muda <0,2% do ciclo). O céu
## usa Sky.PROCESS_MODE_INCREMENTAL para espalhar esse recálculo em vários quadros.

const SUN_STEP_SECONDS := 0.1
const ENVIRONMENT_STEP_SECONDS := 2.0

## ESCURIDÃO da cena (chave `darkness` do DayNightCycle: 0 = dia, 1 = noite profunda, já com o clima) — o que brilha no mapa
## acende conforme ela sobe. Como dono único da luz da cena, este controlador a publica de dois jeitos: o parâmetro
## global de shader `world_darkness` (emissão dos modelos, shaders/glow_prop.gdshader) e este sinal (luzes do
## WorldGlow, ligado em Main). Só quando muda mais que DARKNESS_STEP — nunca por quadro.
signal darkness_changed(value: float)
const DARKNESS_SHADER_PARAM := &"world_darkness"
const DARKNESS_STEP := 0.005
var darkness := 0.0

var sun: DirectionalLight3D
var world_environment: WorldEnvironment
## Fase atual (0..1) do ciclo.
var phase: float = DayNightCycle.noon_phase()
var enabled := true
var running := false
var _sun_timer := 0.0
## Clima na luz, vindo do WeatherController: o "look" do clima ativo (WeatherKinds) e quanto dele (0..1) — composto
## sobre a amostra do ciclo em _apply (DayNightCycle.with_weather).
var weather_look: Dictionary = {}
var weather_amount := 0.0
## DEBUG (painel de Debug da HUD): acelera o ciclo para ver anoitecer/amanhecer em segundos. Volta a 1 em start_match.
const DEBUG_FAST_TIME_SCALE := 20.0
var debug_time_scale := 1.0
var _applied_weather_amount := 0.0
var _environment_timer := 0.0

func setup(light: DirectionalLight3D, environment_node: WorldEnvironment) -> void:
	sun = light
	world_environment = environment_node
	# Cópia própria: Environment/Sky/material são sub-recursos de Main.tscn em cache — mexer neles direto contaminaria
	# outra instância da cena (testes, voltar ao menu e abrir de novo).
	if world_environment != null and world_environment.environment != null:
		world_environment.environment = world_environment.environment.duplicate(true)
	var sky := _sky()
	if sky != null:
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	darkness = -1.0 # o parâmetro global é do processo: publica o valor desta cena mesmo que seja "o mesmo de antes"
	_apply(true)

## Partida nova ou carregada: recomeça no meio da manhã.
func start_match() -> void:
	running = true
	debug_time_scale = 1.0
	phase = DayNightCycle.start_phase()
	_apply(true)

## Fim da partida (volta ao menu): o visual aprovado do meio-dia.
func stop() -> void:
	running = false
	_apply(true)

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_apply(true)

## Clima (WeatherController): o look do clima ativo e quanto dele. O controlador de dia e noite continua o ÚNICO dono do
## sol e do ambiente — o clima só informa como e quanto fechar o tempo, então dia, noite, chuva e neve nunca brigam pela
## mesma luz. Com o ciclo correndo, o valor entra no próximo passo de _apply; parado (desligado/menu), reaplica só
## quando muda o bastante (evita recalcular o céu a cada quadro durante a rampa).
func set_weather_look(look: Dictionary, amount: float) -> void:
	weather_look = look
	weather_amount = clampf(amount, 0.0, 1.0)
	if is_cycling():
		return
	if absf(weather_amount - _applied_weather_amount) >= 0.02 or (weather_amount == 0.0 and _applied_weather_amount != 0.0):
		_apply(true)

## DEBUG: pula para o meio-dia ou para a noite profunda (a partir daí o ciclo segue normalmente).
func debug_jump_to(night: bool) -> void:
	set_phase(0.0 if night else DayNightCycle.noon_phase())

## Fixa a fase (testes, conferência visual).
func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	_apply(true)

func is_cycling() -> bool:
	return running and enabled

## Fase efetivamente mostrada: a do ciclo, ou o meio-dia aprovado quando ele não corre.
func shown_phase() -> float:
	return phase if is_cycling() else DayNightCycle.noon_phase()

func _process(delta: float) -> void:
	if not is_cycling():
		return
	advance(delta * debug_time_scale)

## Avança `seconds` de tempo real (separado de _process para os testes).
func advance(seconds: float) -> void:
	phase = fposmod(phase + seconds / DayNightCycle.CYCLE_SECONDS, 1.0)
	_sun_timer += seconds
	_environment_timer += seconds
	if _sun_timer < SUN_STEP_SECONDS:
		return
	_sun_timer = 0.0
	var environment_due := _environment_timer >= ENVIRONMENT_STEP_SECONDS
	if environment_due:
		_environment_timer = 0.0
	_apply(environment_due)

func _apply(include_environment: bool) -> void:
	var state := DayNightCycle.with_weather(DayNightCycle.sample(shown_phase()), weather_look, weather_amount)
	_applied_weather_amount = weather_amount
	_publish_darkness(float(state.darkness))
	if sun != null:
		sun.rotation_degrees = Vector3(-float(state.elevation), float(state.azimuth), 0.0)
		sun.light_color = state.sun_color
		sun.light_energy = float(state.sun_energy)
		sun.shadow_opacity = float(state.shadow_opacity)
	if not include_environment or world_environment == null or world_environment.environment == null:
		return
	var env := world_environment.environment
	env.ambient_light_energy = float(state.ambient_energy)
	env.fog_light_color = state.fog
	env.tonemap_exposure = float(state.exposure)
	env.adjustment_saturation = float(state.saturation)
	var sky := _sky()
	if sky != null and sky.sky_material is ProceduralSkyMaterial:
		var material := sky.sky_material as ProceduralSkyMaterial
		material.sky_top_color = state.sky_top
		material.sky_horizon_color = state.sky_horizon
		material.ground_horizon_color = state.sky_horizon

func _publish_darkness(value: float) -> void:
	# Os extremos sempre passam: o dia volta exatamente a 0 e a noite chega exatamente a 1.
	if absf(value - darkness) < DARKNESS_STEP and not ((value == 0.0 or value == 1.0) and value != darkness):
		return
	darkness = value
	RenderingServer.global_shader_parameter_set(DARKNESS_SHADER_PARAM, darkness)
	darkness_changed.emit(darkness)

func _sky() -> Sky:
	if world_environment == null or world_environment.environment == null:
		return null
	return world_environment.environment.sky
