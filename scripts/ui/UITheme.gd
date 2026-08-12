class_name UITheme
extends RefCounted

## Sistema de visual unico pro jogo inteiro (paleta + fontes + estilo de
## painel/botao) — antes disso NENHUMA tela tinha nenhum Theme, tudo
## renderizava no cinza padrao do Godot, cada painel com espacamento/
## tamanho de fonte proprios sem nenhuma consistencia. build() monta um
## Theme na hora (sem precisar de um arquivo .tres pra manter em sincronia
## manualmente) — HUD/TitleScreen/PauseMenu setam `theme = UITheme.build()`
## no proprio _ready(), e todo Control filho (incluindo os paineis
## instanciados dentro deles, como SettingsPanel) herda automaticamente.
##
## Paleta "pergaminho antigo": fundo marrom bem escuro quase preto, texto
## cor de pergaminho, contorno dourado/bronze — combina com o tema
## medieval-fantasia sem precisar de nenhum asset externo (mesma filosofia
## "procedural com fallback" usada em todo o resto do projeto).

const COLOR_BG_PANEL := Color(0.11, 0.09, 0.07, 0.97)
const COLOR_BG_PANEL_LIGHT := Color(0.17, 0.14, 0.10, 0.98)
const COLOR_BORDER := Color(0.5, 0.38, 0.18, 1.0)
const COLOR_BORDER_BRIGHT := Color(0.8, 0.63, 0.28, 1.0)
const COLOR_TEXT := Color(0.92, 0.87, 0.76, 1.0)
const COLOR_TEXT_MUTED := Color(0.58, 0.53, 0.44, 1.0)
const COLOR_ACCENT := Color(0.42, 0.66, 0.86, 1.0)
const COLOR_SUCCESS := Color(0.47, 0.72, 0.36, 1.0)
const COLOR_DANGER := Color(0.8, 0.36, 0.3, 1.0)

const FONT_SIZE_BODY := 16
const FONT_SIZE_SMALL := 13
const FONT_SIZE_SECTION := 19
const FONT_SIZE_TITLE := 26

static func build() -> Theme:
	var theme := Theme.new()
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

	var btn_normal := panel_style(COLOR_BG_PANEL_LIGHT, COLOR_BORDER, 1)
	var btn_hover := panel_style(COLOR_BG_PANEL_LIGHT.lightened(0.08), COLOR_BORDER_BRIGHT, 2)
	var btn_pressed := panel_style(COLOR_BG_PANEL.darkened(0.15), COLOR_BORDER_BRIGHT, 2)
	var btn_disabled := panel_style(COLOR_BG_PANEL.darkened(0.25), Color(COLOR_TEXT_MUTED, 0.35), 1)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", panel_style(Color(0, 0, 0, 0), COLOR_ACCENT, 2))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", COLOR_BORDER_BRIGHT)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_font_size("font_size", "Button", FONT_SIZE_BODY)

	theme.set_stylebox("panel", "PanelContainer", panel_style(COLOR_BG_PANEL, COLOR_BORDER, 2, 10))

	theme.set_stylebox("normal", "LineEdit", panel_style(COLOR_BG_PANEL.darkened(0.1), COLOR_BORDER, 1))
	theme.set_stylebox("focus", "LineEdit", panel_style(COLOR_BG_PANEL.darkened(0.1), COLOR_BORDER_BRIGHT, 2))
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_MUTED)

	theme.set_stylebox("background", "ProgressBar", panel_style(COLOR_BG_PANEL.darkened(0.2), COLOR_BORDER, 1, 4))
	theme.set_stylebox("fill", "ProgressBar", panel_style(COLOR_ACCENT, COLOR_ACCENT, 0, 4))
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)

	return theme

## Compartilhado entre build() e quem monta paineis dinamicos na hora (ex:
## TechTree.gd desenhando um "card" por tecnologia) — mesma receita de
## StyleBoxFlat em todo canto, sem duplicar os numeros.
static func panel_style(bg: Color, border: Color, border_width: int, corner_radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.set_content_margin_all(8)
	return sb
