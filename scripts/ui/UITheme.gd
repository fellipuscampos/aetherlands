class_name UITheme
extends RefCounted

## Sistema de visual unico pro jogo inteiro (paleta + fontes + estilo de
## painel/botao) — antes disso NENHUMA tela tinha nenhum Theme, tudo
## renderizava no cinza padrao do Godot, cada painel com espacamento/
## tamanho de fonte proprios sem nenhuma consistencia. build() monta um
## Theme na hora (sem precisar de um arquivo .tres pra manter em sincronia
## manualmente) — HUD/TitleScreen/PauseMenu setam `theme = UITheme.build()`
## no proprio _ready(), e todo Control filho (incluindo os paineis
## instanciados dentro deles, como SettingsScreen) herda automaticamente.
##
## Paleta "pergaminho antigo": fundo marrom bem escuro quase preto, texto
## cor de pergaminho, contorno dourado/bronze — combina com o tema
## medieval-fantasia sem precisar de nenhum asset externo (mesma filosofia
## "procedural com fallback" usada em todo o resto do projeto).

## Alfa 1.0 (era 0.97/0.98 — quase opaco, mas nao de verdade): pedido do
## usuario, "torne o fundo do painel modal 100% OPACO... sem deixar o
## mapa/minimapa vazar por tras dos cards". Modal com alfa < 1.0 sobre o
## mundo 3D em movimento deixava um leve "fantasma" do terreno/labels de
## cidade por baixo, pior ainda quando um elemento brilhante (minimapa)
## ficava atras. Afeta TODOS os paineis (Tecnologia, Grimorio, Diplomacia,
## Debug, Fim de Jogo) de uma vez, ja que todos usam o mesmo
## stylebox global de PanelContainer — de proposito, nenhum modal deveria
## ser translucido.
const THEME_PATH := "res://ui/themes/aetherlands_theme.tres"

## Aliases preservam os consumidores legados enquanto a fonte oficial passa
## a ser UIThemeTokens. Assim a migracao nao duplica valores nem quebra os
## paineis existentes nesta fase de fundacao.
const COLOR_BG_PANEL := UIThemeTokens.COLOR_SURFACE
const COLOR_BG_PANEL_LIGHT := UIThemeTokens.COLOR_SURFACE_RAISED
const COLOR_BORDER := UIThemeTokens.COLOR_BORDER
const COLOR_BORDER_BRIGHT := UIThemeTokens.COLOR_BORDER_STRONG
const COLOR_TEXT := UIThemeTokens.COLOR_TEXT
const COLOR_TEXT_MUTED := UIThemeTokens.COLOR_TEXT_MUTED
const COLOR_ACCENT := UIThemeTokens.COLOR_INFO
const COLOR_SUCCESS := UIThemeTokens.COLOR_SUCCESS
const COLOR_DANGER := UIThemeTokens.COLOR_CRITICAL

const FONT_SIZE_BODY := UIThemeTokens.FONT_BODY
const FONT_SIZE_SMALL := UIThemeTokens.FONT_SECONDARY
const FONT_SIZE_SECTION := UIThemeTokens.FONT_SECTION
const FONT_SIZE_TITLE := UIThemeTokens.FONT_TITLE

static func build(base_scale: float = 1.0) -> Theme:
	var safe_scale := clampf(base_scale, 0.8, 1.5)
	var loaded := load(THEME_PATH) as Theme
	if loaded != null:
		var duplicated := loaded.duplicate(true) as Theme
		_scale_theme_metrics(duplicated, safe_scale)
		return duplicated
	var theme := Theme.new()
	configure(theme)
	_scale_theme_metrics(theme, safe_scale)
	return theme

## Theme.default_base_scale e uma referencia para assets com densidades
## distintas; sozinho ele nao redimensiona os valores explicitos do nosso
## tema. A preferencia de acessibilidade precisa portanto escalar fontes,
## constantes e StyleBoxes reais. Isso altera somente Controls/CanvasLayer:
## viewport 3D, Camera3D e coordenadas do mundo permanecem intactos.
static func _scale_theme_metrics(theme: Theme, factor: float) -> void:
	theme.default_base_scale = 1.0
	if is_equal_approx(factor, 1.0):
		return
	theme.default_font_size = maxi(1, int(round(float(theme.default_font_size) * factor)))
	var scaled_styles: Dictionary = {}
	for type_name in theme.get_type_list():
		for font_size_name in theme.get_font_size_list(type_name):
			var size := theme.get_font_size(font_size_name, type_name)
			theme.set_font_size(font_size_name, type_name, maxi(1, int(round(float(size) * factor))))
		for constant_name in theme.get_constant_list(type_name):
			var value := theme.get_constant(constant_name, type_name)
			theme.set_constant(constant_name, type_name, int(round(float(value) * factor)))
		for style_name in theme.get_stylebox_list(type_name):
			var style := theme.get_stylebox(style_name, type_name)
			if style == null or scaled_styles.has(style.get_instance_id()):
				continue
			scaled_styles[style.get_instance_id()] = true
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				var margin := style.get_content_margin(side)
				if margin >= 0.0:
					style.set_content_margin(side, margin * factor)
			if style is StyleBoxFlat:
				_scale_flat_style(style as StyleBoxFlat, factor)

static func _scale_flat_style(style: StyleBoxFlat, factor: float) -> void:
	style.border_width_left = int(round(float(style.border_width_left) * factor))
	style.border_width_top = int(round(float(style.border_width_top) * factor))
	style.border_width_right = int(round(float(style.border_width_right) * factor))
	style.border_width_bottom = int(round(float(style.border_width_bottom) * factor))
	style.corner_radius_top_left = int(round(float(style.corner_radius_top_left) * factor))
	style.corner_radius_top_right = int(round(float(style.corner_radius_top_right) * factor))
	style.corner_radius_bottom_left = int(round(float(style.corner_radius_bottom_left) * factor))
	style.corner_radius_bottom_right = int(round(float(style.corner_radius_bottom_right) * factor))
	style.shadow_size = int(round(float(style.shadow_size) * factor))
	style.shadow_offset *= factor

static func configure(theme: Theme) -> void:
	theme.default_font_size = FONT_SIZE_BODY

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_font_size("font_size", "Label", FONT_SIZE_BODY)

	# Variacoes de Label pra cabecalho de painel e sub-secao — usadas via
	# `label.theme_type_variation = "PanelTitle"` nos nos que precisam,
	# sem precisar redefinir cor/tamanho em cada um na mao.
	theme.set_type_variation("PanelTitle", "Label")
	theme.set_color("font_color", "PanelTitle", COLOR_BORDER_BRIGHT)
	theme.set_font_size("font_size", "PanelTitle", FONT_SIZE_TITLE)

	theme.set_type_variation("SectionLabel", "Label")
	theme.set_color("font_color", "SectionLabel", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "SectionLabel", FONT_SIZE_SECTION)

	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "MutedLabel", FONT_SIZE_SMALL)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_color("font_color", "HeadingLabel", COLOR_BORDER_BRIGHT)
	theme.set_font_size("font_size", "HeadingLabel", UIThemeTokens.FONT_H1)
	theme.set_type_variation("SubheadingLabel", "Label")
	theme.set_color("font_color", "SubheadingLabel", COLOR_TEXT)
	theme.set_font_size("font_size", "SubheadingLabel", UIThemeTokens.FONT_H2)
	theme.set_type_variation("BodySmallLabel", "Label")
	theme.set_color("font_color", "BodySmallLabel", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "BodySmallLabel", UIThemeTokens.FONT_BODY_SMALL)
	theme.set_type_variation("UIControlLabel", "Label")
	theme.set_color("font_color", "UIControlLabel", COLOR_TEXT)
	theme.set_font_size("font_size", "UIControlLabel", UIThemeTokens.FONT_LABEL)
	theme.set_type_variation("CaptionLabel", "Label")
	theme.set_color("font_color", "CaptionLabel", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "CaptionLabel", UIThemeTokens.FONT_CAPTION)

	var btn_normal := panel_style(COLOR_BG_PANEL_LIGHT, COLOR_BORDER, 1)
	var btn_hover := panel_style(COLOR_BG_PANEL_LIGHT.lightened(0.08), COLOR_BORDER_BRIGHT, 2)
	var btn_pressed := panel_style(COLOR_BG_PANEL.darkened(0.15), COLOR_BORDER_BRIGHT, 2)
	var btn_disabled := panel_style(COLOR_BG_PANEL.darkened(0.25), Color(COLOR_TEXT_MUTED, 0.35), 1)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", panel_style(Color(0, 0, 0, 0), COLOR_ACCENT, 2, 6, false))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", COLOR_BORDER_BRIGHT)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "Button", FONT_SIZE_BODY)

	_configure_button_variation(theme, "PrimaryButton", UIThemeTokens.COLOR_ACCENT, UIThemeTokens.COLOR_CANVAS)
	_configure_button_variation(theme, "SecondaryButton", UIThemeTokens.COLOR_SURFACE_RAISED, COLOR_TEXT)
	_configure_button_variation(theme, "DangerButton", UIThemeTokens.COLOR_CRITICAL.darkened(0.18), COLOR_TEXT)
	_configure_button_variation(theme, "GhostButton", Color(0, 0, 0, 0), COLOR_TEXT)
	_configure_button_variation(theme, "IconButton", UIThemeTokens.COLOR_SURFACE, COLOR_TEXT)

	theme.set_stylebox("panel", "PanelContainer", panel_style(COLOR_BG_PANEL, COLOR_BORDER, 1, UIThemeTokens.RADIUS_PANEL))
	_configure_panel_variation(theme, "SurfacePanel", UIThemeTokens.COLOR_SURFACE, UIThemeTokens.COLOR_BORDER, UIThemeTokens.ELEVATION_DOCK)
	_configure_panel_variation(theme, "ElevatedPanel", UIThemeTokens.COLOR_SURFACE_RAISED, UIThemeTokens.COLOR_BORDER_STRONG, UIThemeTokens.ELEVATION_OVERLAY)
	_configure_panel_variation(theme, "ModalPanel", UIThemeTokens.COLOR_SURFACE_MODAL, UIThemeTokens.COLOR_BORDER_STRONG, UIThemeTokens.ELEVATION_MODAL, UIThemeTokens.RADIUS_MODAL)

	theme.set_stylebox("normal", "LineEdit", panel_style(COLOR_BG_PANEL.darkened(0.1), COLOR_BORDER, 1))
	theme.set_stylebox("focus", "LineEdit", panel_style(COLOR_BG_PANEL.darkened(0.1), COLOR_BORDER_BRIGHT, 2, 6, false))
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_MUTED)

	# Trilho fino e discreto: sliders continuam acessíveis sem se transformar
	# em grandes faixas de formulário ao ocupar uma coluna larga.
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = UIThemeTokens.COLOR_CANVAS
	slider_track.set_corner_radius_all(2)
	slider_track.set_content_margin_all(2)
	theme.set_stylebox("slider", "HSlider", slider_track)
	var slider_highlight := slider_track.duplicate() as StyleBoxFlat
	slider_highlight.bg_color = UIThemeTokens.COLOR_INFO.darkened(0.15)
	theme.set_stylebox("grabber_area", "HSlider", slider_highlight)

	theme.set_stylebox("background", "ProgressBar", panel_style(COLOR_BG_PANEL.darkened(0.2), COLOR_BORDER, 1, 4))
	theme.set_stylebox("fill", "ProgressBar", panel_style(COLOR_ACCENT, COLOR_ACCENT, 0, 4, false))
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)

	# TabContainer (City Inspector Panel: abas "Unidades"/"Construções", ver
	# HUD.tscn ProductionTabs) — sem isto renderizava no cinza padrao do
	# Godot, quebrando a identidade visual "pergaminho antigo" bem na tela
	# mais usada do jogo.
	theme.set_stylebox("panel", "TabContainer", panel_style(COLOR_BG_PANEL_LIGHT, COLOR_BORDER, 2, 8))
	theme.set_stylebox("tab_selected", "TabContainer", panel_style(COLOR_BG_PANEL_LIGHT, COLOR_BORDER_BRIGHT, 2, 6))
	theme.set_stylebox("tab_unselected", "TabContainer", panel_style(COLOR_BG_PANEL.darkened(0.15), COLOR_BORDER, 1, 6))
	theme.set_stylebox("tab_hovered", "TabContainer", panel_style(COLOR_BG_PANEL_LIGHT.lightened(0.05), COLOR_BORDER_BRIGHT, 1, 6))
	theme.set_color("font_selected_color", "TabContainer", COLOR_BORDER_BRIGHT)
	theme.set_color("font_unselected_color", "TabContainer", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "TabContainer", FONT_SIZE_BODY)

	# VSeparator (divisorias finas entre indicadores na barra superior, ver
	# HUD.tscn TopBar/TopBarRow/StatusGroup) e HSeparator (divisoria entre
	# grupos de botao no ActionBar do canto inferior direito, ver HUD.tscn
	# ActionBar/ActionBarBox) — cor default do Godot destoava da paleta
	# bronze/dourada do resto do jogo.
	theme.set_color("color", "VSeparator", COLOR_BORDER)
	theme.set_color("color", "HSeparator", COLOR_BORDER)

	# Fase 30: tooltip opaco e único para todos os consumidores (AETooltip desenha
	# o conteúdo; este painel é a moldura comum).
	var tooltip_panel := panel_style(UIThemeTokens.COLOR_SURFACE_MODAL, UIThemeTokens.COLOR_BORDER_STRONG, 1, UIThemeTokens.RADIUS_PANEL, false)
	tooltip_panel.set_content_margin_all(UIThemeTokens.SPACE_3)
	theme.set_stylebox("panel", "TooltipPanel", tooltip_panel)
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT)
	theme.set_font_size("font_size", "TooltipLabel", UIThemeTokens.FONT_BODY_SMALL)


static func _configure_button_variation(theme: Theme, variation: String, bg: Color, text_color: Color) -> void:
	theme.set_type_variation(variation, "Button")
	theme.set_stylebox("normal", variation, panel_style(bg, UIThemeTokens.COLOR_BORDER, 1, UIThemeTokens.RADIUS_CONTROL))
	theme.set_stylebox("hover", variation, panel_style(bg.lightened(0.08), UIThemeTokens.COLOR_BORDER_STRONG, 2, UIThemeTokens.RADIUS_CONTROL))
	theme.set_stylebox("pressed", variation, panel_style(bg.darkened(0.12), UIThemeTokens.COLOR_ACCENT, 2, UIThemeTokens.RADIUS_CONTROL))
	theme.set_stylebox("disabled", variation, panel_style(UIThemeTokens.COLOR_CANVAS, UIThemeTokens.COLOR_TEXT_DISABLED, 1, UIThemeTokens.RADIUS_CONTROL))
	theme.set_stylebox("focus", variation, panel_style(Color(0, 0, 0, 0), UIThemeTokens.COLOR_INFO, 2, UIThemeTokens.RADIUS_CONTROL, false))
	theme.set_color("font_color", variation, text_color)
	theme.set_color("font_hover_color", variation, UIThemeTokens.COLOR_TEXT)
	theme.set_color("font_pressed_color", variation, UIThemeTokens.COLOR_TEXT)
	theme.set_color("font_disabled_color", variation, UIThemeTokens.COLOR_TEXT_DISABLED)

static func _configure_panel_variation(theme: Theme, variation: String, bg: Color, border: Color, elevation: int, radius: int = UIThemeTokens.RADIUS_PANEL) -> void:
	theme.set_type_variation(variation, "PanelContainer")
	var style := panel_style(bg, border, 1, radius, elevation > 0)
	style.shadow_size = elevation
	theme.set_stylebox("panel", variation, style)

## Compartilhado entre build() e quem monta paineis dinamicos na hora (ex:
## TechTree.gd desenhando um "card" por tecnologia) — mesma receita de
## StyleBoxFlat em todo canto, sem duplicar os numeros.
##
## Melhoria grafica (pedido do usuario: "trabalhe em melhorias graficas" na
## UI/HUD): antes disso todo painel/botao/card era um retangulo 100% chapado
## — sem sombra nenhuma (lia como "colado" na tela, sem profundidade) e sem
## anti-aliasing nos cantos arredondados (serrilhado visivel em qualquer
## corner_radius > 0, screenshot confirmou isso na tela de Nova Partida).
## anti_aliasing() da o contorno liso de graca; a sombra suave por baixo (leve
## deslocamento pra baixo-direita, cor preta translucida) e o mesmo truque
## usado em qualquer UI "flat design com profundidade" — nao muda nenhuma cor
## de fundo/borda/tamanho ja calibrada, so acrescenta a sensacao de camada
## flutuando sobre o fundo em vez de pintada nele.
## with_shadow = false pros casos onde uma sombra ficaria errada: overlay de
## FOCO (bg transparente por cima do stylebox normal — a sombra apareceria
## flutuando sozinha, sem caixa visivel por baixo dela) e o "fill" fino da
## ProgressBar (barra estreita redesenhada toda hora, sombra so sujaria).
static func panel_style(bg: Color, border: Color, border_width: int, corner_radius: int = 6, with_shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.set_content_margin_all(8)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	if with_shadow:
		# Tamanho/offset PEQUENOS de proposito — botoes em grade (ex:
		# BuildingsRow em HUD.tscn, h/v_separation=6) ficam bem proximos uns
		# dos outros; uma sombra maior encostaria na sombra do vizinho e
		# sujaria a leitura da grade em vez de dar profundidade.
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0.0, 1.0)
	return sb
