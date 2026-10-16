class_name WeatherSchedule
extends RefCounted

## Agenda do clima — SÓ COSMÉTICA (pedidos do usuário 2026-10-09/10: chuva e neve "de vez em quando, não é pra ficar
## acontecendo toda hora"; a neve mais rara que a chuva). Máquina de estados pura: diz QUAL clima está acontecendo e
## QUANTO (intensidade 0..1); quem desenha, toca o som, mexe na luz e no chão é o WeatherController. Tempo REAL de
## partida, nunca por turno. Os números de cada clima ficam em WeatherKinds.
##
## UM EVENTO POR VEZ: a cada ROLL_INTERVAL_SECONDS um único sorteio escolhe o tipo (WeatherKinds.kind_for_roll), só
## depois de MIN_MATCH_SECONDS_BEFORE_WEATHER de partida e de COOLDOWN_SECONDS desde o fim do último evento — chuva e
## neve nunca se sobrepõem nem vêm coladas. Pedir outro tipo com um evento em andamento (debug) faz o atual sair em
## SWITCH_FADE_SECONDS e começa o novo em seguida (fila), sem corte seco.
##
## Saídas: intensity(kind) (só o tipo ativo é > 0), wetness() (chuva; seca devagar) e snow_cover() (neve; acumula e
## derrete devagar).
##
## A sorte vem SEMPRE de uma RandomNumberGenerator recebida por parâmetro (a do controlador) — nunca de randf()/randi()
## globais, que a partida usa (paridade por seed): o clima não pode mudar o resultado de nenhum jogo.

enum State { CLEAR, RISING, PEAK, FALLING }

const ROLL_INTERVAL_SECONDS := 240.0
const MIN_MATCH_SECONDS_BEFORE_WEATHER := 300.0
const COOLDOWN_SECONDS := 600.0
const SWITCH_FADE_SECONDS := 3.0
## O chão molha junto com a chuva, mas seca devagar: de totalmente molhado a seco em WETNESS_DRY_SECONDS.
const WETNESS_DRY_SECONDS := 90.0
## A neve assenta aos poucos (cobertura máxima em SNOW_ACCUMULATE_SECONDS de neve plena) e derrete acompanhando o fim
## da nevasca, a no máximo 1/SNOW_MELT_SECONDS por segundo. Era 150 s: o chão ficava inteiramente branco por mais de
## 2 minutos depois que a neve parava (e 2,5 min depois de "Parar neve") — o usuário leu como "nunca volta ao normal".
## Com 45 s a cobertura desce junto com a saída da nevasca e some logo depois dela.
const SNOW_ACCUMULATE_SECONDS := 90.0
const SNOW_MELT_SECONDS := 45.0

var state: int = State.CLEAR
## Tipo do evento atual (WeatherKinds.RAIN/SNOW), "" sem evento.
var kind := ""
var match_seconds := 0.0
var _roll_timer := 0.0
var _last_event_end := -INF
## Evento atual: tempo decorrido e duração total (entrada + pico + saída).
var _event_time := 0.0
var _event_duration := 0.0
## Saída (natural ou forçada): parte de `_fade_from` e chega a 0 em `_fade_total`.
var _fade_from := 0.0
var _fade_total := 1.0
var _fade_left := 0.0
## Troca pedida com outro tipo em andamento: começa quando a saída do atual terminar.
var _queued_kind := ""
var _queued_duration := 0.0
var _wetness := 0.0
var _snow_cover := 0.0
## Eventos começados por tipo (testes/diagnóstico).
var events_started := {}

func reset() -> void:
	state = State.CLEAR
	kind = ""
	match_seconds = 0.0
	_roll_timer = 0.0
	_last_event_end = -INF
	_event_time = 0.0
	_event_duration = 0.0
	_fade_left = 0.0
	_queued_kind = ""
	_wetness = 0.0
	_snow_cover = 0.0

func is_active() -> bool:
	return state != State.CLEAR

## O tipo `which` está acontecendo e ainda não está saindo (rótulos de debug).
func is_running(which: String) -> bool:
	return is_active() and kind == which and state != State.FALLING

func is_raining() -> bool:
	return is_active() and kind == WeatherKinds.RAIN

func is_snowing() -> bool:
	return is_active() and kind == WeatherKinds.SNOW

## Intensidade do tipo `which` agora (0..1), sempre contínua: smoothstep na entrada e na saída. Só o tipo ativo é > 0.
func intensity(which: String) -> float:
	if kind != which:
		return 0.0
	match state:
		State.RISING:
			return smoothstep(0.0, WeatherKinds.fade_in(kind), _event_time)
		State.PEAK:
			return 1.0
		State.FALLING:
			return _fade_from * smoothstep(0.0, _fade_total, _fade_left)
	return 0.0

func current_intensity() -> float:
	return intensity(kind)

func rain_intensity() -> float:
	return intensity(WeatherKinds.RAIN)

func snow_intensity() -> float:
	return intensity(WeatherKinds.SNOW)

## Quanto o chão está molhado (0..1): sobe com a chuva, seca devagar depois.
func wetness() -> float:
	return _wetness

## Quanto de neve assentou (0..1): acumula enquanto neva, derrete devagar depois.
func snow_cover() -> float:
	return _snow_cover

## Avança `seconds` de partida. `allow_new_events` = false (clima desligado): nada novo começa, mas o evento atual
## continua saindo suavemente e o chão continua secando/derretendo.
func advance(seconds: float, rng: RandomNumberGenerator, allow_new_events: bool = true) -> void:
	if seconds <= 0.0:
		return
	match_seconds += seconds
	_advance_event(seconds)
	_roll_timer += seconds
	while _roll_timer >= ROLL_INTERVAL_SECONDS:
		_roll_timer -= ROLL_INTERVAL_SECONDS
		if allow_new_events and _can_start_event():
			var rolled := WeatherKinds.kind_for_roll(rng.randf())
			if rolled != "":
				var span := WeatherKinds.duration_range(rolled)
				start_event(rolled, rng.randf_range(span.x, span.y))
	_wetness = maxf(rain_intensity(), _wetness - seconds / WETNESS_DRY_SECONDS)
	var snow_target := snow_intensity()
	if snow_target > _snow_cover:
		_snow_cover = minf(snow_target, _snow_cover + seconds / SNOW_ACCUMULATE_SECONDS)
	else:
		_snow_cover = maxf(snow_target, _snow_cover - seconds / SNOW_MELT_SECONDS)

func _can_start_event() -> bool:
	return state == State.CLEAR and match_seconds >= MIN_MATCH_SECONDS_BEFORE_WEATHER \
		and match_seconds - _last_event_end >= COOLDOWN_SECONDS

## Começa um evento `which` de `duration` segundos (entrada e saída incluídas) — agenda, debug e testes.
## - mesmo tipo já acontecendo: nada; mesmo tipo saindo: retoma a entrada da intensidade atual (sem salto);
## - outro tipo em andamento: o atual sai em SWITCH_FADE_SECONDS e este começa logo depois (fila).
func start_event(which: String, duration: float) -> void:
	if WeatherKinds.data(which).is_empty():
		return
	if is_active() and kind != which:
		fade_out_now(SWITCH_FADE_SECONDS)
		_queued_kind = which
		_queued_duration = duration
		return
	if is_active() and state != State.FALLING:
		return
	var resume_from := current_intensity() if is_active() else 0.0
	kind = which
	state = State.RISING
	_event_time = _fade_in_time_for(resume_from)
	_event_duration = maxf(duration, WeatherKinds.fade_in(which) + WeatherKinds.fade_out(which))
	events_started[which] = int(events_started.get(which, 0)) + 1

func start_rain(duration: float) -> void:
	start_event(WeatherKinds.RAIN, duration)

## Tempo da entrada em que smoothstep(0, fade_in, t) == intensity (busca binária; a curva é monótona).
func _fade_in_time_for(value: float) -> float:
	var fade := WeatherKinds.fade_in(kind) if kind != "" else 1.0
	if value <= 0.0:
		return 0.0
	var low := 0.0
	var high := fade
	for i in 24:
		var mid := (low + high) * 0.5
		if smoothstep(0.0, fade, mid) < value:
			low = mid
		else:
			high = mid
	return high

## Termina o evento atual com uma saída de `fade_seconds` a partir da intensidade de agora (desligar o clima, parar no
## debug). Cancela uma troca na fila.
func fade_out_now(fade_seconds: float) -> void:
	_queued_kind = ""
	if not is_active():
		return
	if state == State.FALLING and _fade_left <= fade_seconds:
		return # já está saindo mais rápido que isso
	_begin_fade(current_intensity(), fade_seconds)

func _begin_fade(from: float, total: float) -> void:
	state = State.FALLING
	_fade_from = from
	_fade_total = maxf(total, 0.001)
	_fade_left = _fade_total

func _advance_event(seconds: float) -> void:
	if state == State.CLEAR:
		return
	if state == State.FALLING:
		_fade_left -= seconds
		if _fade_left <= 0.0:
			state = State.CLEAR
			kind = ""
			_last_event_end = match_seconds
			if _queued_kind != "":
				var next := _queued_kind
				_queued_kind = ""
				start_event(next, _queued_duration)
		return
	_event_time += seconds
	if state == State.RISING and _event_time >= WeatherKinds.fade_in(kind):
		state = State.PEAK
	if _event_time >= _event_duration - WeatherKinds.fade_out(kind):
		_begin_fade(current_intensity(), WeatherKinds.fade_out(kind))
