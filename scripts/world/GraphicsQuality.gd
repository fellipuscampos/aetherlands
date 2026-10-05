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
