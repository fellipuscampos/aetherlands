class_name LoadingSpinner
extends Control

## Emblema arcano 100% desenhado a mao (mesmo espirito procedural do resto
## do jogo, sem asset externo nenhum): anel externo fixo com marcas de runa
## + dois aneis girando em sentidos opostos + nucleo pulsante. Evolucao do
## spinner original (um unico arco) — pedido do usuario: tela de loading
## "digna de um jogo moderno... simbolo arcano animado... runas...
## indicador circular", combinando com a paleta pergaminho/bronze de
## UITheme. Continua sendo SO desenho: a responsividade de verdade vem de
## HexGrid.generate_map() ceder frames entre etapas (ver Main.gd
## _show_loading_screen/_report_generation_progress em HexGrid.gd), nao
## desta animacao.
const OUTER_RADIUS := 52.0
const MID_RADIUS := 39.0
const INNER_RADIUS := 26.0
const CORE_RADIUS := 6.0

const RING_WIDTH := 3.0
const ARC_WIDTH := 4.0

const MID_ARC_LENGTH := TAU * 0.62
const INNER_ARC_LENGTH := TAU * 0.45

const MID_SPEED := TAU * 0.5 # ~meia volta/s, sentido horario
const INNER_SPEED := TAU * 0.75 # mais rapido, sentido anti-horario — "engrenagens dentro de engrenagens"

const RUNE_COUNT := 8
const RUNE_INNER_OFFSET := 7.0
const RUNE_OUTER_OFFSET := 8.0

var _mid_angle := 0.0
var _inner_angle := 0.0
var _pulse_time := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_mid_angle = fmod(_mid_angle + delta * MID_SPEED, TAU)
	_inner_angle = fmod(_inner_angle - delta * INNER_SPEED, TAU)
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5

	# Anel externo fixo + marcas de runa: moldura estatica que ancora a
	# composicao — sem ela os dois arcos girando pareceriam flutuar soltos
	# no ar em vez de "dentro" de um circulo arcano.
	draw_arc(center, OUTER_RADIUS, 0.0, TAU, 64, UITheme.COLOR_BORDER, RING_WIDTH, true)
	for i in range(RUNE_COUNT):
		var angle := (TAU / RUNE_COUNT) * i
		var dir := Vector2(cos(angle), sin(angle))
		var inner_point: Vector2 = center + dir * (OUTER_RADIUS - RUNE_INNER_OFFSET)
		var outer_point: Vector2 = center + dir * (OUTER_RADIUS + RUNE_OUTER_OFFSET)
		draw_line(inner_point, outer_point, UITheme.COLOR_BORDER_BRIGHT, 2.0, true)

	# Anel do meio, horario — mesma tecnica do spinner original (arco com
	# "gap" visivel, senao um circulo fechado nao passa sensacao de rotacao).
	draw_arc(center, MID_RADIUS, _mid_angle, _mid_angle + MID_ARC_LENGTH, 32, UITheme.COLOR_ACCENT, ARC_WIDTH, true)

	# Anel interno, anti-horario, mais rapido — reforca a leitura de
	# mecanismo arcano ativo (dois aneis independentes, nao um so girando).
	draw_arc(center, INNER_RADIUS, _inner_angle, _inner_angle + INNER_ARC_LENGTH, 24, UITheme.COLOR_BORDER_BRIGHT, ARC_WIDTH, true)

	# Nucleo com respiracao lenta — terceiro sinal de "vivo", independente
	# da rotacao dos aneis (fica visivel mesmo num frame onde os arcos
	# quase nao mudaram de posicao entre um redraw e outro).
	var pulse := 0.6 + 0.4 * sin(_pulse_time * TAU * 0.5)
	draw_circle(center, CORE_RADIUS * (1.4 + 0.5 * pulse), Color(UITheme.COLOR_ACCENT, 0.22 * pulse))
	draw_circle(center, CORE_RADIUS * 0.55, Color(UITheme.COLOR_ACCENT, 0.9))
