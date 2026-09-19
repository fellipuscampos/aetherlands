class_name TechFamilyIcon
extends Control

## Icone geometrico simples pra cada familia de apresentacao da Arvore de
## Tecnologia (Roadmap "polimento definitivo V1") — pedido explicito do
## usuario: "sem emojis... se precisar de icones, reusar assets existentes
## ou formas vetoriais simples e coerentes, uma iconografia consistente por
## familia". Sem asset externo equivalente no projeto (KayKit e pra
## predios/unidades 3D, nao pra icones de UI 2D) — 4 formas basicas
## desenhadas via _draw(), uma por familia, na cor de destaque da propria
## familia (ver TechTierBoard.FAMILY_COLOR).

@export var family: String = "":
	set(value):
		family = value
		queue_redraw()
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()

func _draw() -> void:
	var size := Vector2(get_rect().size)
	var c := size / 2.0
	var r: float = min(c.x, c.y) - 1.0
	if r <= 0.0:
		return
	# Roadmap "so o essencial" (revisao): as 4 formas tinham area MUITO
	# diferente dentro da MESMA caixa (a lamina antiga ocupava ~0.47*r²,
	# o circulo ~3.14*r² — quase 7x mais "peso" visual), pedido explicito:
	# "alguns estao de tamanhos distintos, deixe todos do mesmo tamanho".
	# Cada forma abaixo foi recalibrada (raio/largura proprios) pra ocupar
	# uma area parecida (~1.5-1.8*r²) mantendo a silhueta distinta.
	match family:
		TechData.FAMILY_MILITAR:
			# Lamina (arma) — mais larga que antes, mesmo peso visual dos
			# outros 3 icones agora.
			var w := r * 0.8
			draw_colored_polygon([
				c + Vector2(0, -r), c + Vector2(w, r * 0.15), c + Vector2(0, r * 0.85), c + Vector2(-w, r * 0.15),
			], icon_color)
		TechData.FAMILY_ECONOMIA:
			# Circulo (moeda) — raio reduzido (era r inteiro, o maior dos 4).
			draw_circle(c, r * 0.75, icon_color)
		TechData.FAMILY_DEFESA:
			# Pentagono (escudo) — raio levemente reduzido.
			var pr := r * 0.85
			var pts: PackedVector2Array = []
			for i in range(5):
				var ang := -PI / 2.0 + i * TAU / 5.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * pr)
			draw_colored_polygon(pts, icon_color)
		TechData.FAMILY_EXPLORACAO_UTILIDADE:
			# Losango (bussola/estrada) — raio levemente reduzido.
			var dr := r * 0.9
			draw_colored_polygon([
				c + Vector2(0, -dr), c + Vector2(dr, 0), c + Vector2(0, dr), c + Vector2(-dr, 0),
			], icon_color)
