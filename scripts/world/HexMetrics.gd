class_name HexMetrics
extends RefCounted

## Hexagonos "pointy-top" em coordenadas axiais (q, r), no plano XZ.
## Referencia do algoritmo: redblobgames.com/grids/hexagons

static func corner(size: float, i: int) -> Vector3:
	var angle_deg = 60.0 * i - 30.0
	var angle_rad = deg_to_rad(angle_deg)
	return Vector3(size * cos(angle_rad), 0.0, size * sin(angle_rad))

static func axial_to_world(q: int, r: int, size: float) -> Vector3:
	var x = size * sqrt(3.0) * (float(q) + float(r) / 2.0)
	var z = size * 1.5 * float(r)
	return Vector3(x, 0.0, z)

## Coordenadas a distância 1..`radius` de `center` (sem o próprio centro), por aritmética axial: sem BFS, sem alocar
## vizinhos e sem consultar o grid (quem chama filtra por tile/ocupação). O(área) = 3r(r+1). Usada pelas técnicas de
## ataque de longo alcance (V2TechniqueRuntime), que só precisam do alcance exato da técnica.
static func coords_within(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			if dq != 0 or dr != 0:
				result.append(center + Vector2i(dq, dr))
	return result

## Os hexágonos da linha reta de `a` até `b` (sem `a`, com `b`): interpolação em coordenadas cúbicas com um desempate estável.
## Usada para animar o deslocamento em linha do voo (HexGrid.flight_path) — o voo não segue rota de terreno.
static func axial_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps := axial_distance(a, b)
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		result.append(_round_axial(lerpf(float(a.x), float(b.x), t) + 0.000001, lerpf(float(a.y), float(b.y), t) + 0.000002))
	return result

static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var ax = a.x
	var az = a.y
	var ay = -ax - az
	var bx = b.x
	var bz = b.y
	var by = -bx - bz
	return int((abs(ax - bx) + abs(ay - by) + abs(az - bz)) / 2)

static func world_to_axial(x: float, z: float, size: float) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * x - 1.0 / 3.0 * z) / size
	var r = (2.0 / 3.0 * z) / size
	return _round_axial(q, r)

static func _round_axial(q: float, r: float) -> Vector2i:
	var x = q
	var z = r
	var y = -x - z
	var rx = round(x)
	var ry = round(y)
	var rz = round(z)
	var x_diff = abs(rx - x)
	var y_diff = abs(ry - y)
	var z_diff = abs(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))
