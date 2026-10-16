class_name GraphicsQuality
extends RefCounted

## V3 / Etapa 4 — opções gráficas REAIS (Forward+, Godot 4.7). Tabelas puras + aplicação no Viewport/DirectionalLight3D
## /RenderingServer. Quem guarda a escolha é o Settings (user://settings.cfg, preferência do jogador — nunca o save de
## partida); quem chama apply_* é o Main (no início e a cada Settings.graphics_changed). Tudo vale ao vivo, sem reiniciar.
##
## Anti-aliasing (Viewport): FXAA e MSAA são mutuamente exclusivos aqui — escolher um zera o outro (nunca uma
## combinação escondida). MSAA 3D cobre as bordas da geometria (voxels/hexes); FXAA é pós-processo barato que também
## suaviza bordas de shader/alpha, com leve desfoque. TAA não é exposto (rastro em unidades que se movem).
## Sombras (luz do sol + RenderingServer): ligado/desligado, resolução do atlas direcional, filtro suave (PCF) e
## distância/cascatas — cada nível muda parâmetros reais diferentes (ver SHADOW_PROFILES).

const AA_OFF := "off"
const AA_FXAA := "fxaa"
const AA_MSAA_2X := "msaa_2x"
const AA_MSAA_4X := "msaa_4x"
const ANTI_ALIASING_OPTIONS: Array[String] = [AA_OFF, AA_FXAA, AA_MSAA_2X, AA_MSAA_4X]
const AA_LABELS := {AA_OFF: "Desativado", AA_FXAA: "FXAA", AA_MSAA_2X: "MSAA 2x", AA_MSAA_4X: "MSAA 4x"}
const AA_PROFILES := {
	AA_OFF: {"msaa_3d": Viewport.MSAA_DISABLED, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED},
	AA_FXAA: {"msaa_3d": Viewport.MSAA_DISABLED, "screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA},
	AA_MSAA_2X: {"msaa_3d": Viewport.MSAA_2X, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED},
	AA_MSAA_4X: {"msaa_3d": Viewport.MSAA_4X, "screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED},
}

const SHADOW_OFF := "off"
const SHADOW_LOW := "low"
const SHADOW_MEDIUM := "medium"
const SHADOW_HIGH := "high"
const SHADOW_QUALITY_OPTIONS: Array[String] = [SHADOW_OFF, SHADOW_LOW, SHADOW_MEDIUM, SHADOW_HIGH]
const SHADOW_LABELS := {SHADOW_OFF: "Desativadas", SHADOW_LOW: "Baixa", SHADOW_MEDIUM: "Média", SHADOW_HIGH: "Alta"}
## atlas = lado do atlas de sombra direcional (px); filter = RenderingServer.ShadowQuality do filtro suave; mode =
## cascatas (DirectionalLight3D.ShadowMode); max_distance = alcance das sombras a partir da câmera (o zoom máximo da
## RTSCamera é 30, o chão visível chega a ~60–70). Média = o visual que o jogo já tinha (atlas 4096, 4 cascatas, filtro
## muito baixo do project.godot), com alcance encurtado para nitidez.
const SHADOW_PROFILES := {
	SHADOW_OFF: {"enabled": false},
	SHADOW_LOW: {"enabled": true, "atlas": 2048, "filter": RenderingServer.SHADOW_QUALITY_HARD, "mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "max_distance": 60.0},
	SHADOW_MEDIUM: {"enabled": true, "atlas": 4096, "filter": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "max_distance": 80.0},
	SHADOW_HIGH: {"enabled": true, "atlas": 8192, "filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "max_distance": 100.0},
}

## Padrões (medidos na Etapa 4, ver docs/GRAPHICS_SETTINGS.md): MSAA 2x limpa as bordas dos voxels/hexes com custo
## pequeno; sombras Médias = o visual atual.
const DEFAULT_ANTI_ALIASING := AA_MSAA_2X
const DEFAULT_SHADOW_QUALITY := SHADOW_MEDIUM

static func valid_anti_aliasing(id: String) -> String:
	return id if id in ANTI_ALIASING_OPTIONS else DEFAULT_ANTI_ALIASING

static func valid_shadow_quality(id: String) -> String:
	return id if id in SHADOW_QUALITY_OPTIONS else DEFAULT_SHADOW_QUALITY

static func apply_anti_aliasing(viewport: Viewport, id: String) -> void:
	if viewport == null:
		return
	var profile: Dictionary = AA_PROFILES[valid_anti_aliasing(id)]
	viewport.msaa_3d = int(profile.msaa_3d)
	viewport.screen_space_aa = int(profile.screen_space_aa)
	viewport.use_taa = false

static func apply_shadows(light: DirectionalLight3D, id: String) -> void:
	var profile: Dictionary = SHADOW_PROFILES[valid_shadow_quality(id)]
	if light != null:
		light.shadow_enabled = bool(profile.enabled)
		if bool(profile.enabled):
			light.directional_shadow_mode = int(profile.mode)
			light.directional_shadow_max_distance = float(profile.max_distance)
	if bool(profile.enabled):
		RenderingServer.directional_shadow_atlas_set_size(int(profile.atlas), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(int(profile.filter))

## --- Máquinas fracas (2026-10-14) ---------------------------------------------------------------------------------
## Resolução 3D: o mundo é desenhado em `percent` da janela e ampliado com AMD FSR 1.0 (nitidez embutida); a interface
## continua na resolução nativa. 100 = desenho nativo, exatamente o de sempre (BILINEAR em escala 1, o padrão do
## Viewport). É a alavanca mais forte de GPU: 75 % desenha ~56 % dos pixels.
const RENDER_SCALE_OPTIONS: Array[int] = [100, 85, 75, 67, 50]
const DEFAULT_RENDER_SCALE := 100

static func valid_render_scale(percent: int) -> int:
	return percent if percent in RENDER_SCALE_OPTIONS else DEFAULT_RENDER_SCALE

static func render_scale_label(percent: int) -> String:
	return "%d %%" % percent if percent >= 100 else "%d %% (FSR)" % percent

static func apply_render_scale(viewport: Viewport, percent: int) -> void:
	if viewport == null:
		return
	var value := valid_render_scale(percent)
	if value >= 100:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = value / 100.0

## Oclusão de ambiente (SSAO) e reflexos de tela (SSR) do WorldEnvironment. Ligado = o que a cena define (Main.tscn);
## desligado poupa dois passes de tela inteira. Nunca mexe no glow (o brilho de lava, cristais e magia é parte da arte).
static func apply_screen_effects(environment: Environment, enabled: bool) -> void:
	if environment == null:
		return
	environment.ssao_enabled = enabled
	environment.ssr_enabled = enabled

## --- Sombras do tamanho da vista (otimização, 2026-10-14; docs/PERFORMANCE_GUIDE.md §6) ----------------------------
## A câmera tem ângulo fixo: o chão mais distante na tela depende só do zoom (~31 de profundidade no zoom padrão, ~50
## no máximo). Com o alcance fixo do perfil (80 na Média), a ÚLTIMA cascata (40–80) desenhava centenas de objetos que
## nunca aparecem — a maior parte dos draw calls do quadro. Aqui o alcance encolhe até a borda da tela + folga, mas as
## cascatas mantêm as MESMAS distâncias absolutas de antes (8/16/40 na Média: as frações de split são recalculadas), e o
## esmaecimento (fade_start do sol) começa além do que se vê. Resultado: as sombras visíveis ficam visualmente iguais
## (bordas deslocam menos de 1 texel, conferido lado a lado); só some o
## trabalho fora da tela. Chamado pelo Main ao aplicar as opções e a cada zoom da RTSCamera.
## Splits padrão do DirectionalLight3D (frações do alcance do perfil) — a referência das distâncias absolutas.
const PROFILE_SPLITS := [0.1, 0.2, 0.5]
## Altura mínima do chão que pode aparecer (fundo do mar); o raio do topo da tela é intersectado aqui.
const VIEW_GROUND_Y := -0.5
## Folga além do chão visível: o topo de árvores/castelos/montanhas logo depois da borda ainda aparece.
const VIEW_DEPTH_MARGIN := 6.0

static func fit_shadows_to_view(light: DirectionalLight3D, id: String, camera: Camera3D) -> void:
	if light == null or camera == null or not camera.is_inside_tree():
		return
	var profile: Dictionary = SHADOW_PROFILES[valid_shadow_quality(id)]
	if not bool(profile.enabled):
		return
	var full := float(profile.max_distance)
	var absolute: Array[float] = []
	for fraction in PROFILE_SPLITS:
		absolute.append(full * float(fraction))
	var last_split: float = absolute[2] if int(profile.mode) == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else absolute[0]
	var depth := visible_ground_depth(camera)
	var fade := maxf(light.directional_shadow_fade_start, 0.05)
	var distance := full if depth <= 0.0 else clampf((depth + VIEW_DEPTH_MARGIN) / fade, last_split * 1.05, full)
	light.directional_shadow_max_distance = distance
	light.directional_shadow_split_1 = absolute[0] / distance
	light.directional_shadow_split_2 = absolute[1] / distance
	light.directional_shadow_split_3 = absolute[2] / distance

## Profundidade (no eixo da câmera) do chão mais distante na tela: o raio da borda de cima intersectado com o plano
## VIEW_GROUND_Y. 0 = o raio não desce (câmera olhando o horizonte): sem redução.
static func visible_ground_depth(camera: Camera3D) -> float:
	var size := camera.get_viewport().get_visible_rect().size
	var forward := -camera.global_transform.basis.z
	var deepest := 0.0
	for screen_x in [0.0, size.x * 0.5, size.x]:
		var origin := camera.project_ray_origin(Vector2(screen_x, 0.0))
		var direction := camera.project_ray_normal(Vector2(screen_x, 0.0))
		if direction.y >= -0.001:
			return 0.0
		var t := (VIEW_GROUND_Y - origin.y) / direction.y
		deepest = maxf(deepest, (origin + direction * t - camera.global_position).dot(forward))
	return deepest
