class_name LoadingSpinner
extends Control

## Spinner circular 100% desenhado a mao (mesmo espirito procedural do
## resto do jogo, sem asset externo nenhum) — um arco girando continuamente,
## feedback visual de "ainda trabalhando" pra LoadingScreen (pedido do
## usuario: "tela de loading... pra nao parecer que travou").
const RADIUS := 22.0
const LINE_WIDTH := 5.0
const ARC_LENGTH := TAU * 0.7 # ~252 graus — deixa um "gap" visivel, senao um circulo fechado nao passa sensacao de rotacao
const SPEED := TAU * 0.9 # radianos por segundo (~0.9 volta/s)

var _angle := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + delta * SPEED, TAU)
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	draw_arc(center, RADIUS, _angle, _angle + ARC_LENGTH, 40, UITheme.COLOR_ACCENT, LINE_WIDTH, true)
