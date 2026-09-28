class_name UIThemeTokens
extends RefCounted

## Fonte unica dos valores visuais da fundacao UI/UX. Componentes e telas
## consomem estes tokens; numeros locais ficam reservados para layout de
## conteudo especifico, nunca para reinventar paleta ou estados.

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_6 := 24
const SPACE_8 := 32

const RADIUS_CONTROL := 4
const RADIUS_PANEL := 6
const RADIUS_MODAL := 8
const TARGET_MIN := 40
const TARGET_PREFERRED := 44
const HUD_EDGE_MARGIN := 16
const GLOBAL_BAR_HEIGHT := 56
const STRATEGIC_SAFE_MARGIN_X := 32
const STRATEGIC_SAFE_MARGIN_Y := 24

const FONT_DISPLAY := 34
const FONT_H1 := 26
const FONT_H2 := 22
const FONT_H3 := 19
const FONT_BODY := 16
const FONT_BODY_SMALL := 14
const FONT_LABEL := 14
const FONT_CAPTION := 12

# Aliases de transição para consumidores anteriores à hierarquia completa.
const FONT_TITLE := FONT_H1
const FONT_SECTION := FONT_H3
const FONT_SECONDARY := FONT_BODY_SMALL

const COLOR_CANVAS := Color("12161b")
const COLOR_SURFACE := Color("1b2026")
const COLOR_SURFACE_RAISED := Color("252c34")
const COLOR_SURFACE_MODAL := Color("101419")
const COLOR_BORDER := Color("465362")
const COLOR_BORDER_STRONG := Color("b58a45")
const COLOR_TEXT := Color("f1eadb")
const COLOR_TEXT_MUTED := Color("aab4c2")
const COLOR_TEXT_DISABLED := Color("687586")
const COLOR_ACCENT := Color("d2a85b")
const COLOR_INFO := Color("5ea7df")
const COLOR_SUCCESS := Color("73b96b")
const COLOR_WARNING := Color("dfa94f")
const COLOR_CRITICAL := Color("df655d")
const COLOR_TARGETING := Color("c987e8")
const COLOR_DIMMER := Color(0.02, 0.03, 0.05, 0.76)

const ELEVATION_DOCK := 1
const ELEVATION_OVERLAY := 3
const ELEVATION_MODAL := 5

const MOTION_HOVER := 0.10
const MOTION_PANEL := 0.18
const MOTION_MODAL := 0.24
const MOTION_TOAST := 0.18

const BREAKPOINT_LARGE := 1600
const BREAKPOINT_MEDIUM := 1280
const CONTEXT_WIDTH_LARGE := 440
const CONTEXT_WIDTH_MEDIUM := 400
const CONTEXT_WIDTH_SMALL := 360
const SUPPLY_NEAR_CAP_RATIO := 0.80

static func context_width_for(viewport_width: float) -> float:
	if viewport_width >= BREAKPOINT_LARGE:
		return CONTEXT_WIDTH_LARGE
	if viewport_width >= BREAKPOINT_MEDIUM:
		return CONTEXT_WIDTH_MEDIUM
	return minf(CONTEXT_WIDTH_SMALL, maxf(300.0, viewport_width * 0.32))

static func breakpoint_name(viewport_width: float) -> String:
	if viewport_width >= BREAKPOINT_LARGE:
		return "large"
	if viewport_width >= BREAKPOINT_MEDIUM:
		return "medium"
	return "small"
