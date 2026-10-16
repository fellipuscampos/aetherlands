class_name DayNightCycle
extends RefCounted

## Ciclo de dia e noite — SÓ VISUAL (pedido do usuário 2026-10-09: tempo real, não por turno, nenhuma mecânica, e
## "não quero que fique de noite do nada, é um fade"). Dado puro: keyframes de iluminação ao longo de um ciclo e a
## amostragem suave entre eles. Quem aplica no sol/ambiente é DayNightController; nada de regra de jogo lê isto.
##
## DURAÇÃO (decisão registrada em docs/GRAPHICS_SETTINGS.md): 20 min — dia 11 min, entardecer 2,5, noite 4 (2 de noite
## profunda), amanhecer 2,5. Num 4X o turno dura de 30 s a 2 min: com 10 min a noite voltaria a cada poucos turnos; com
## 20 ela vira clima de fundo. A noite é luar legível (nunca escura de verdade) porque o jogador lê o mapa o tempo todo.
##
## MEIO-DIA = o visual aprovado de scenes/main/Main.tscn (docs/GRAPHICS_SETTINGS.md, "Iluminação padrão"): com o ciclo
## desligado, ou fora da partida, o jogo fica exatamente como antes.
##
## FADE MONÓTONO: nenhum momento é mais escuro que a noite profunda (o crepúsculo e a hora azul ficam entre o dia e a
## noite em brilho — a primeira versão tinha crepúsculo mais escuro que a noite, o que "escurecia e clareava de novo").
## SEM SALTOS por construção: a amostra entre dois keyframes é smoothstep (derivada zero nas pontas) e a tabela é
## cíclica (o último keyframe emenda no primeiro). A direção do sol é UMA luz contínua: de dia varre de leste a oeste;
## à noite a mesma luz vira "lua" (azul e fraca) e volta devagar para o leste — nunca há troca brusca de sombra nem
## duas luzes direcionais com sombra (que dobrariam o custo).

const CYCLE_MINUTES := 20.0
const CYCLE_SECONDS := CYCLE_MINUTES * 60.0
## Partida nova/carregada começa no meio da manhã (o primeiro entardecer chega ~8,5 min depois).
const START_MINUTE := 7.0
const NOON_MINUTE := 10.0
## Elevação mínima do sol/lua: abaixo disso as sombras viram riscos enormes no tabuleiro.
const MIN_ELEVATION_DEGREES := 25.0

## Fronteiras das fases (minutos), para documentação/testes: o dia vai do fim do amanhecer ao início do entardecer.
const DAY_START_MINUTE := 4.5
const DAY_END_MINUTE := 15.5
const NIGHT_START_MINUTE := 18.0
const NIGHT_END_MINUTE := 2.0

## Estado de iluminação de um keyframe. Cores lineares do Godot (as mesmas do .tscn).
## sun_*: DirectionalLight3D "Sun" (elevation = -rotation.x, azimuth = rotation.y, em graus).
## shadow_opacity: DirectionalLight3D.shadow_opacity — pedido do usuário 2026-10-09 ("é complicado ter sombras bem fortes
## à noite"): as sombras somem enquanto anoitece (hora dourada 0,8 -> crepúsculo 0,2 -> noite 0) e reaparecem enquanto
## amanhece (hora azul 0,1 -> nascer 0,6 -> manhã 1). O dia inteiro tem sombra cheia (1,0 = padrão da cena).
## ambient_energy: Environment.ambient_light_energy (a luz ambiente vem do céu — ambient_light_source = SKY).
## sky_top / sky_horizon: ProceduralSkyMaterial (o horizonte também é o ground_horizon).
## fog: Environment.fog_light_color. exposure: tonemap_exposure. saturation: adjustment_saturation.
## darkness: ESCURIDÃO da cena para o que brilha no mapa (WorldGlow e shaders com `world_darkness`) — 0 no dia
## inteiro, 1 na noite profunda, subindo enquanto anoitece (hora dourada 0,35 -> crepúsculo 0,85) e descendo enquanto
## amanhece. Valor de ARTE, não medida física: a noite do jogo é um luar legível (~55% do brilho do meio-dia), então
## derivar isto do brilho fazia uma manhã chuvosa contar quase como noite. O clima soma o seu (WeatherKinds
## look.darkness): tempo fechado deixa o brilho um pouco mais evidente.
const KEYFRAMES := [
	{"minute": 1.0, "name": "noite", "shadow_opacity": 0.0, "sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 0.5, "elevation": 48.0, "azimuth": 0.0,
		"ambient_energy": 0.55, "sky_top": Color(0.06, 0.09, 0.2), "sky_horizon": Color(0.16, 0.2, 0.32),
		"fog": Color(0.2, 0.25, 0.38), "exposure": 1.05, "saturation": 0.85, "darkness": 1.0},
	{"minute": 2.0, "name": "hora azul", "shadow_opacity": 0.1, "sun_color": Color(0.6, 0.66, 0.95), "sun_energy": 0.48, "elevation": 35.0, "azimuth": -20.0,
		"ambient_energy": 0.6, "sky_top": Color(0.15, 0.2, 0.38), "sky_horizon": Color(0.42, 0.42, 0.58),
		"fog": Color(0.35, 0.38, 0.52), "exposure": 1.0, "saturation": 0.9, "darkness": 0.85},
	{"minute": 3.3, "name": "nascer do sol", "shadow_opacity": 0.6, "sun_color": Color(1.0, 0.76, 0.6), "sun_energy": 0.7, "elevation": 25.0, "azimuth": -18.0,
		"ambient_energy": 0.3, "sky_top": Color(0.32, 0.4, 0.62), "sky_horizon": Color(0.92, 0.74, 0.64),
		"fog": Color(0.78, 0.72, 0.7), "exposure": 0.97, "saturation": 1.05, "darkness": 0.35},
	{"minute": DAY_START_MINUTE, "name": "manhã", "shadow_opacity": 1.0, "sun_color": Color(1.0, 0.9, 0.78), "sun_energy": 0.88, "elevation": 32.0, "azimuth": -10.0,
		"ambient_energy": 0.21, "sky_top": Color(0.3, 0.46, 0.72), "sky_horizon": Color(0.78, 0.78, 0.8),
		"fog": Color(0.7, 0.74, 0.8), "exposure": 0.95, "saturation": 1.08, "darkness": 0.0},
	# O visual aprovado (Main.tscn) — não mudar sem mudar a cena e docs/GRAPHICS_SETTINGS.md junto.
	{"minute": NOON_MINUTE, "name": "meio-dia", "shadow_opacity": 1.0, "sun_color": Color(1.0, 0.97, 0.93), "sun_energy": 0.95, "elevation": 42.0, "azimuth": 35.0,
		"ambient_energy": 0.2, "sky_top": Color(0.3, 0.47, 0.72), "sky_horizon": Color(0.7, 0.77, 0.84),
		"fog": Color(0.65, 0.75, 0.85), "exposure": 0.95, "saturation": 1.08, "darkness": 0.0},
	{"minute": DAY_END_MINUTE, "name": "tarde", "shadow_opacity": 1.0, "sun_color": Color(1.0, 0.92, 0.8), "sun_energy": 0.9, "elevation": 32.0, "azimuth": 80.0,
		"ambient_energy": 0.21, "sky_top": Color(0.3, 0.46, 0.7), "sky_horizon": Color(0.8, 0.78, 0.76),
		"fog": Color(0.72, 0.74, 0.78), "exposure": 0.95, "saturation": 1.1, "darkness": 0.0},
	{"minute": 16.7, "name": "hora dourada", "shadow_opacity": 0.8, "sun_color": Color(1.0, 0.74, 0.5), "sun_energy": 0.82, "elevation": 25.0, "azimuth": 95.0,
		"ambient_energy": 0.25, "sky_top": Color(0.32, 0.38, 0.6), "sky_horizon": Color(0.95, 0.72, 0.52),
		"fog": Color(0.82, 0.72, 0.62), "exposure": 0.96, "saturation": 1.08, "darkness": 0.35},
	{"minute": NIGHT_START_MINUTE, "name": "crepúsculo", "shadow_opacity": 0.2, "sun_color": Color(0.82, 0.62, 0.75), "sun_energy": 0.5, "elevation": 35.0, "azimuth": 100.0,
		"ambient_energy": 0.5, "sky_top": Color(0.2, 0.22, 0.42), "sky_horizon": Color(0.62, 0.45, 0.55),
		"fog": Color(0.42, 0.38, 0.52), "exposure": 1.03, "saturation": 0.92, "darkness": 0.85},
	{"minute": 19.0, "name": "noite", "shadow_opacity": 0.0, "sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 0.5, "elevation": 48.0, "azimuth": 80.0,
		"ambient_energy": 0.55, "sky_top": Color(0.06, 0.09, 0.2), "sky_horizon": Color(0.16, 0.2, 0.32),
		"fog": Color(0.2, 0.25, 0.38), "exposure": 1.05, "saturation": 0.85, "darkness": 1.0},
]

const COLOR_KEYS := ["sun_color", "sky_top", "sky_horizon", "fog"]
const FLOAT_KEYS := ["sun_energy", "shadow_opacity", "elevation", "azimuth", "ambient_energy", "exposure", "saturation", "darkness"]

## Fase "escura" (do início do entardecer ao fim do amanhecer) — rótulo do botão de Debug "Ir para o dia/noite".
static func is_dark_phase(phase: float) -> bool:
	var minute := fposmod(phase, 1.0) * CYCLE_MINUTES
	return minute >= DAY_END_MINUTE or minute < DAY_START_MINUTE

static func phase_for_minute(minute: float) -> float:
	return fposmod(minute / CYCLE_MINUTES, 1.0)

static func start_phase() -> float:
	return phase_for_minute(START_MINUTE)

static func noon_phase() -> float:
	return phase_for_minute(NOON_MINUTE)

## Estado de iluminação na fase `phase` (0..1, cíclica). Smoothstep entre os dois keyframes vizinhos.
static func sample(phase: float) -> Dictionary:
	var minute := fposmod(phase, 1.0) * CYCLE_MINUTES
	var count := KEYFRAMES.size()
	var from: Dictionary = KEYFRAMES[count - 1]
	var to: Dictionary = KEYFRAMES[0]
	for i in count:
		if minute < float(KEYFRAMES[i].minute):
			to = KEYFRAMES[i]
			from = KEYFRAMES[(i - 1 + count) % count]
			break
		if i == count - 1:
			from = KEYFRAMES[i]
			to = KEYFRAMES[0]
	var start := float(from.minute)
	var span := fposmod(float(to.minute) - start, CYCLE_MINUTES)
	var t := smoothstep(0.0, 1.0, fposmod(minute - start, CYCLE_MINUTES) / maxf(span, 0.0001))
	var state := {}
	for key in COLOR_KEYS:
		state[key] = (from[key] as Color).lerp(to[key], t)
	for key in FLOAT_KEYS:
		state[key] = lerpf(float(from[key]), float(to[key]), t)
	state.elevation = maxf(float(state.elevation), MIN_ELEVATION_DEGREES)
	return state

## Brilho aproximado da cena (só para testes/ajuste): luz direta no chão (luminância × energia × seno da elevação) mais
## a ambiente (energia × luminância média do céu), vezes a exposição. Não é física — serve para comparar estados.
static func brightness(state: Dictionary) -> float:
	var sun: Color = state.sun_color
	var sky := ((state.sky_top as Color) + (state.sky_horizon as Color)) * 0.5
	var direct := sun.get_luminance() * float(state.sun_energy) * sin(deg_to_rad(float(state.elevation)))
	var ambient := float(state.ambient_energy) * sky.get_luminance()
	return (direct + ambient) * float(state.exposure)

## CLIMA NA LUZ (WeatherController -> DayNightController.set_weather_look): sem nuvens desenhadas, o tempo fechado
## aparece na luz. `look` vem de WeatherKinds (cada clima tem o seu); `amount` 0 devolve o estado intacto, 1 = clima
## pleno: sol e sombra multiplicados, saturação menor, exposição ajustada e a névoa indo para o cinza da PRÓPRIA
## luminância (tingido por `fog_tint`) — a noite continua noite durante a chuva ou a neve.
static func with_weather(state: Dictionary, look: Dictionary, amount: float) -> Dictionary:
	var a := clampf(amount, 0.0, 1.0)
	if a <= 0.0 or look.is_empty():
		return state
	var result := state.duplicate()
	result.sun_energy = float(state.sun_energy) * lerpf(1.0, float(look.get("sun_energy", 1.0)), a)
	result.shadow_opacity = float(state.shadow_opacity) * lerpf(1.0, float(look.get("shadow_opacity", 1.0)), a)
	result.saturation = float(state.saturation) - float(look.get("saturation_drop", 0.0)) * a
	result.exposure = float(state.exposure) * lerpf(1.0, float(look.get("exposure", 1.0)), a)
	result.darkness = clampf(float(state.get("darkness", 0.0)) + float(look.get("darkness", 0.0)) * a, 0.0, 1.0)
	var fog: Color = state.fog
	var grey := fog.get_luminance()
	var tint: Color = look.get("fog_tint", Color(1.0, 1.0, 1.0))
	var target := Color(grey * tint.r, grey * tint.g, grey * tint.b)
	result.fog = fog.lerp(target, float(look.get("fog_grey", 0.0)) * a)
	return result
