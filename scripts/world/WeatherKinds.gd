class_name WeatherKinds
extends RefCounted

## Tipos de clima cosmético — DADOS (chance, duração, som, partículas e o "visual" da luz). A agenda (WeatherSchedule),
## o controlador (WeatherController) e a luz (DayNightCycle.with_weather) leem daqui; acrescentar um clima novo é
## acrescentar uma entrada (e, se ele tiver efeito próprio no chão, o parâmetro de shader correspondente).
##
## Chances (rolagem a cada WeatherSchedule.ROLL_INTERVAL_SECONDS, sorteio único em intervalo acumulado na ordem de
## ORDER): chuva 30% (a mesma de quando só havia chuva), neve 10% — a chuva é bem mais comum (pedido do usuário).
##
## Partículas:
##   max            — teto de partículas (amount do GPUParticles3D; amount_ratio = intensidade x área coberta)
##   speed          — velocidade de queda (u/s); a faixa de queda perto do chão é a mesma para todos
##   size           — tamanho do quad (chuva: fino e longo, alinhado à queda; neve: floco quadrado em billboard)
##   color/emission — cor (alfa = transparência) e brilho próprio mínimo (legível à noite; material é sombreado)
##   wind/spread    — inclinação e espalhamento da queda
##   turbulence     — 0 = queda reta; > 0 = flocos flutuando (turbulência do ParticleProcessMaterial)
##   streak         — true: quad alinhado à direção da queda (gota); false: billboard redondo (floco)
## Som: sound_peak_db é o volume com o clima pleno e efeitos no máximo, calibrado pela loudness de cada arquivo para os
## dois soarem no mesmo nível: ~−40 LUFS no pico, uma ambientação de FUNDO (2026-10-10, pedido do usuário: "50% mais
## baixo... do jeito que tá é um barulho extremamente alto" -> −10 dB, o que o ouvido percebe como metade do volume).
## Chuva −21,5 LUFS -> −18,5 dB; vento −18,0 LUFS -> −22 dB. Os dois são SINTETIZADOS (tools/audio/generate_*_loop.py):
## a gravação de chuva soava como "água caindo na água" e o arquivo baixado como "Winter Wind" era música.
## Partículas: alfa 0,15 (chuva) e 0,45 (neve) — metade do que era (pedido: "mais transparentes").
## Look (luz, DayNightCycle.with_weather): multiplicadores do sol/sombra/exposição, queda de saturação, quanto a névoa
## vai para o cinza da própria luminância e um tom multiplicado nesse cinza (neve: levemente azulado).

const RAIN := "rain"
const SNOW := "snow"
const ORDER := [RAIN, SNOW]

const KINDS := {
	RAIN: {
		"name": "Chuva", "chance": 0.3, "duration": Vector2(120.0, 240.0), "fade_in": 30.0, "fade_out": 45.0,
		"sound_path": "res://assets/audio/sfx/rain_loop.ogg", "sound_peak_db": -18.5,
		"particles": {"max": 6000, "speed": 22.0, "size": Vector2(0.018, 0.42), "color": Color(0.78, 0.84, 0.95, 0.15),
			"emission": 0.15, "wind": Vector3(0.18, 0.0, 0.06), "spread": 3.0, "turbulence": 0.0, "streak": true},
		"look": {"sun_energy": 0.7, "shadow_opacity": 0.45, "saturation_drop": 0.1, "exposure": 0.96,
			"fog_grey": 0.35, "fog_tint": Color(1.0, 1.0, 1.0), "darkness": 0.25},
	},
	SNOW: {
		"name": "Neve", "chance": 0.1, "duration": Vector2(180.0, 300.0), "fade_in": 45.0, "fade_out": 60.0,
		"sound_path": "res://assets/audio/sfx/snow_wind_loop.ogg", "sound_peak_db": -22.0,
		"particles": {"max": 3000, "speed": 3.5, "size": Vector2(0.07, 0.07), "color": Color(1.0, 1.0, 1.0, 0.45),
			"emission": 0.25, "wind": Vector3(0.35, 0.0, 0.12), "spread": 14.0, "turbulence": 0.6, "streak": false},
		"look": {"sun_energy": 0.85, "shadow_opacity": 0.6, "saturation_drop": 0.12, "exposure": 1.0,
			"fog_grey": 0.3, "fog_tint": Color(0.95, 0.98, 1.05), "darkness": 0.12},
	},
}

static func data(kind: String) -> Dictionary:
	return KINDS.get(kind, {})

static func chance(kind: String) -> float:
	return float(data(kind).get("chance", 0.0))

static func duration_range(kind: String) -> Vector2:
	return data(kind).get("duration", Vector2.ZERO)

static func fade_in(kind: String) -> float:
	return float(data(kind).get("fade_in", 1.0))

static func fade_out(kind: String) -> float:
	return float(data(kind).get("fade_out", 1.0))

static func look(kind: String) -> Dictionary:
	return data(kind).get("look", {})

static func particles(kind: String) -> Dictionary:
	return data(kind).get("particles", {})

## Sorteio de UMA rolagem: `roll` (0..1) cai no intervalo acumulado de um tipo, ou em nenhum ("" = sem clima).
static func kind_for_roll(roll: float) -> String:
	var cumulative := 0.0
	for kind in ORDER:
		cumulative += chance(kind)
		if roll < cumulative:
			return kind
	return ""
