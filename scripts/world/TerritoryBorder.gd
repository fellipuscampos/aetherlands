class_name TerritoryBorder
extends RefCounted

## Contorno de território estilo Civilization (pedido do usuário 2026-10-10): em vez de pintar o hexágono inteiro na
## cor da civilização (escondia o terreno e ficava "fluorescente" à noite), a área é CIRCULADA por uma faixa na cor da
## civ, seguindo as arestas retas dos hexágonos. Geometria pura (sem nós): HexGrid._build_city_border_mesh só converte
## os segmentos daqui em malha, com cor/névoa por tile.
##
## TIPOS DE ARESTA de um tile do território de `city` (vizinho n):
##   NONE     — n é da MESMA cidade: aresta interna, nada a desenhar;
##   INTERNAL — n é de OUTRA cidade do MESMO jogador: linha fina e discreta (divisão entre cidades da mesma civ);
##   FULL     — n é de outro jogador, sem dono ou fora do mapa: a borda de verdade.
## Duas civs vizinhas: cada uma desenha a SUA faixa do próprio lado da aresta — as duas cores lado a lado, como no Civ.
##
## JUNÇÕES EXATAS (o contorno antigo, removido, tinha "problemas de junção": retângulos por aresta sem tratar os cantos,
## altura do vizinho mais alto e, como se descobriu agora, a aresta errada para metade das direções). Cada faixa é um
## trapézio DENTRO do próprio tile, entre a aresta (lado de fora, UV.x = 0) e uma linha paralela a `largura` dela
## (lado de dentro, UV.x = 1). O ponto interno de cada canto C, com e2 = a OUTRA aresta do tile em C:
##   - e2 do mesmo tipo (canto convexo): na bissetriz, a largura / sen 60° de C (as duas faixas do tile o compartilham);
##   - e2 sem faixa do mesmo tipo (canto côncavo / emenda entre tiles): SOBRE e2, a largura / sen 60° de C — o tile
##     vizinho do outro lado de e2 calcula exatamente o mesmo ponto, então o contorno fecha sem fresta nem sobreposição.
##   (sen 60° = sen 120°: as duas regras dão a mesma distância, só a direção muda.)
## Linha interna encontrando uma borda cheia no mesmo canto: começa onde a faixa cheia termina sobre ela.
## Como o lado de dentro é sempre paralelo ao de fora a `largura`, UV.x é a distância normalizada até a aresta em todo
## o trapézio — o degradê do shader fica perfeito também nos cantos.

enum Edge { NONE, FULL, INTERNAL }

## Larguras (fração de hex_size): a faixa cheia carrega linha + brilho; a interna é só um fio de cada lado. Com 0,2 e
## a linha sólida em 28% dela (~0,056 hex, poucos pixels) a cor da civ se perdia no terreno claro (conferência visual).
const FULL_WIDTH := 0.26
const INTERNAL_WIDTH := 0.035
const SIN_60 := 0.8660254037844386

static var _edge_corners_cache: Array = []

## Cantos (índices de HexMetrics.corner) da aresta voltada para o vizinho HexGrid.NEIGHBOR_DIRS[dir]: os dois cantos
## mais alinhados com a direção do vizinho — calculado da geometria, nunca suposto (corner i está a 60i−30°, e a
## aresta do vizinho i NÃO é (i, i+1) para todas as direções).
static func edge_corners(dir: int) -> Vector2i:
	if _edge_corners_cache.is_empty():
		for d in HexGrid.NEIGHBOR_DIRS.size():
			var offset: Vector2i = HexGrid.NEIGHBOR_DIRS[d]
			var toward := HexMetrics.axial_to_world(offset.x, offset.y, 1.0)
			var target := Vector2(toward.x, toward.z).normalized()
			var best := -1
			var best_dot := -INF
			for i in 6:
				var a := HexMetrics.corner(1.0, i)
				var b := HexMetrics.corner(1.0, (i + 1) % 6)
				var mid := Vector2(a.x + b.x, a.z + b.z).normalized()
				if mid.dot(target) > best_dot:
					best_dot = mid.dot(target)
					best = i
			_edge_corners_cache.append(Vector2i(best, (best + 1) % 6))
	return _edge_corners_cache[dir]

## Direção (índice de NEIGHBOR_DIRS) cuja aresta contém os cantos a e b.
static func _dir_of_edge(a: int, b: int) -> int:
	for d in HexGrid.NEIGHBOR_DIRS.size():
		var e := edge_corners(d)
		if (e.x == a and e.y == b) or (e.x == b and e.y == a):
			return d
	return -1

## Tipo da aresta entre um tile de `city` e o vizinho `neighbor`, dado o mapa coord -> City de todo o território.
static func edge_type(city, neighbor: Vector2i, owners: Dictionary) -> int:
	var other = owners.get(neighbor)
	if other == city:
		return Edge.NONE
	if other != null and city != null and city.owner_player != null and other.owner_player == city.owner_player:
		return Edge.INTERNAL
	return Edge.FULL

static func width_of(type: int) -> float:
	return FULL_WIDTH if type == Edge.FULL else INTERNAL_WIDTH

## Segmentos do contorno de `city` (posições XZ locais ao centro de cada tile; `hex_size` em unidades do mapa):
## [{coord, dir, type, outer: [A, B], inner: [A', B']}], na ordem dos tiles/direções. `territory` = coords da cidade.
static func segments(city, territory: Array, owners: Dictionary, hex_size: float) -> Array:
	var result: Array = []
	for coord in territory:
		var types: Array[int] = []
		for d in HexGrid.NEIGHBOR_DIRS.size():
			types.append(edge_type(city, coord + HexGrid.NEIGHBOR_DIRS[d], owners))
		for d in HexGrid.NEIGHBOR_DIRS.size():
			if types[d] == Edge.NONE:
				continue
			var corners := edge_corners(d)
			var outer: Array[Vector2] = []
			var inner: Array[Vector2] = []
			for k in 2:
				var here := corners.x if k == 0 else corners.y
				var there := corners.y if k == 0 else corners.x
				var other_end := _other_corner_at(here, there)
				var other_dir := _dir_of_edge(here, other_end)
				var points := _endpoint(here, there, other_end, types[d], types[other_dir], hex_size)
				outer.append(points[0])
				inner.append(points[1])
			result.append({"coord": coord, "dir": d, "type": types[d], "outer": outer, "inner": inner})
	return result

## O outro canto da aresta vizinha que também toca `here` (não a aresta here–there).
static func _other_corner_at(here: int, there: int) -> int:
	var prev := (here + 5) % 6
	var next := (here + 1) % 6
	return prev if next == there else next

static func _corner2(i: int, hex_size: float) -> Vector2:
	var c := HexMetrics.corner(hex_size, i)
	return Vector2(c.x, c.z)

## Ponto de fora e de dentro da faixa `type` (aresta here–there) no canto `here`, conforme a outra aresta do tile ali
## (here–other_end, do tipo `other_type`).
static func _endpoint(here: int, there: int, other_end: int, type: int, other_type: int, hex_size: float) -> Array:
	var c := _corner2(here, hex_size)
	var along_edge := (_corner2(there, hex_size) - c).normalized()
	var along_other := (_corner2(other_end, hex_size) - c).normalized()
	var inward_bisector := (-c).normalized() # o centro do tile é a origem local
	var width := width_of(type) * hex_size
	if type == Edge.INTERNAL and other_type == Edge.FULL:
		# A linha interna começa onde a faixa cheia (da outra aresta) termina sobre esta aresta.
		var start := c + along_edge * (FULL_WIDTH * hex_size / SIN_60)
		var inward := Vector2(-along_edge.y, along_edge.x)
		if inward.dot(-c) < 0.0:
			inward = -inward
		return [start, start + inward * width]
	if other_type == type:
		return [c, c + inward_bisector * (width / SIN_60)]
	return [c, c + along_other * (width / SIN_60)]
