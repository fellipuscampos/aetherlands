class_name FogLayer
extends Node3D

## CAMADA DE NÉVOA DE GUERRA — a parte "nunca visto" da névoa como uma camada física por cima do mapa (só visual; a
## regra de visão continua em HexGrid.visibility). Pedido do usuário 2026-10-12: "a fog foi feita de forma errada por
## ser uma textura sobre a superfície... ela devia ser algo acima do mapa cobrindo o chão, assim não dá pra ver nada do
## que tem embaixo, como se fosse uma camada realmente".
##
## O QUE É: um bloco hexagonal opaco por tile (tampa em TOP_Y, paredes até BOTTOM_Y, abaixo do plano de água), desenhado
## só onde o tile nunca foi visto. Terra e mar ficam sob a MESMA superfície na MESMA altura — relevo, costa, ondas e
## sombras de baixo deixam de existir na tela (o terreno nunca visto nem é desenhado, ver terrain.gdshader). Antes a
## névoa era uma cor pintada pelos shaders do terreno e da água, cada um na sua altura, e a costa aparecia pelo degrau
## e pela sombra entre os dois.
##
## POR QUE NÃO UMA CAMADA ALTA cobrindo tropas e castelos: a câmera olha o mapa inclinada; uma camada na altura de um
## castelo esconderia também os tiles VISÍVEIS atrás dela (cerca de 2 tiles para cada 3 de altura). Por isso a camada
## fica baixa (cobre o chão e o mar) e o que é alto simplesmente NÃO É DESENHADO em tile nunca visto: props com alfa 0,
## entidades com visible = false, decididos na hora em que nascem ou se movem (HexGrid.shown_through_fog).
##
## LEVE POR CONSTRUÇÃO:
##  - nada por quadro em GDScript; o estado vem de UMA textura de 1 texel por tile (HexGrid._fog_state_texture) lida
##    no vértice — mudar a névoa de N tiles reenvia só essa textura, sem tocar em instância nenhuma;
##  - blocos em pedaços de CHUNK×CHUNK tiles (um MultiMesh por pedaço): o motor descarta os que estão fora da câmera,
##    e um pedaço sem nenhum tile nunca visto é desligado de vez (visible = false) — o custo cai conforme o mapa é
##    explorado e chega a zero;
##  - bloco de tile explorado/visível é recolhido a um ponto no vértice (nenhum pixel); sem sombra projetada.

const TOP_Y := 0.42
const BOTTOM_Y := -0.75
const CHUNK := 16
const SHADER := preload("res://shaders/fog_layer.gdshader")

var _grid: HexGrid
var _material: ShaderMaterial
var _chunks: Dictionary = {} # Vector2i(pedaço) -> MultiMeshInstance3D
var _chunk_of: Dictionary = {} # coord -> Vector2i(pedaço)
var _covered: Dictionary = {} # coord -> true (tile nunca visto)
var _covered_per_chunk: Dictionary = {} # Vector2i(pedaço) -> int

func _init(owner_grid: HexGrid = null) -> void:
	_grid = owner_grid
	name = "FogLayer"
	_material = ShaderMaterial.new()
	_material.shader = SHADER

## O material (para quem atribui a textura de estado: HexGrid._sync_fog_state_uniforms).
func material() -> ShaderMaterial:
	return _material

## Reconstrói os blocos para o mapa atual (uma vez por geração/carregamento). Todo tile começa coberto: a névoa de uma
## partida nova é o mapa inteiro nunca visto; apply() descobre o que o jogador já viu.
func rebuild(tiles: Dictionary, hex_size: float) -> void:
	for chunk in _chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunks.clear()
	_chunk_of.clear()
	_covered.clear()
	_covered_per_chunk.clear()
	if tiles.is_empty():
		return
	var mesh := _build_block_mesh(hex_size)
	var coords_by_chunk := {}
	for coord in tiles:
		var key := _chunk_key(coord)
		_chunk_of[coord] = key
		_covered[coord] = true
		if not coords_by_chunk.has(key):
			coords_by_chunk[key] = []
		coords_by_chunk[key].append(coord)
	for key in coords_by_chunk:
		var coords: Array = coords_by_chunk[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = coords.size()
		for i in coords.size():
			var world := HexMetrics.axial_to_world(coords[i].x, coords[i].y, hex_size)
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(world.x, TOP_Y, world.z)))
		var instance := MultiMeshInstance3D.new()
		instance.name = "FogChunk_%d_%d" % [key.x, key.y]
		instance.multimesh = mm
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_chunks[key] = instance
		_covered_per_chunk[key] = coords.size()

## Aplica a visibilidade: `changed` = tiles cujo estado mudou (null = todos). Só contabilidade por pedaço — quem
## esconde/mostra cada bloco é o shader, pela textura de estado.
func apply(visibility: Dictionary, changed: Variant = null) -> void:
	var coords: Array = _chunk_of.keys() if changed == null else changed
	for coord in coords:
		if not _chunk_of.has(coord):
			continue
		var covered: bool = visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.UNSEEN
		if covered == _covered.has(coord):
			continue
		var key: Vector2i = _chunk_of[coord]
		if covered:
			_covered[coord] = true
			_covered_per_chunk[key] = int(_covered_per_chunk[key]) + 1
		else:
			_covered.erase(coord)
			_covered_per_chunk[key] = int(_covered_per_chunk[key]) - 1
		(_chunks[key] as MultiMeshInstance3D).visible = int(_covered_per_chunk[key]) > 0

## O tile está sob a camada (nunca visto)?
func covers(coord: Vector2i) -> bool:
	return _covered.has(coord)

func covered_count() -> int:
	return _covered.size()

func chunk_count() -> int:
	return _chunks.size()

## Pedaços ainda ligados (com pelo menos um tile nunca visto).
func active_chunk_count() -> int:
	var count := 0
	for chunk in _chunks.values():
		if (chunk as MultiMeshInstance3D).visible:
			count += 1
	return count

static func _chunk_key(coord: Vector2i) -> Vector2i:
	var col := coord.x + (coord.y - (coord.y & 1)) / 2 # mesma coluna "odd-r" da textura de estado
	return Vector2i(floori(float(col) / CHUNK), floori(float(coord.y) / CHUNK))

## Tampa (leque de 6 triângulos) + 6 paredes, indexado: 31 vértices e 18 triângulos por bloco. Origem na tampa.
## Faces com a frente para FORA (sentido horário visto de fora, a convenção do Godot), porque o shader usa cull_back.
## Atenção ao copiar de HexGrid._build_hex_prism_mesh: lá a TAMPA está na ordem contrária (só aparece porque
## terrain.gdshader é cull_disabled); as paredes já estão certas.
static func _build_block_mesh(hex_size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = []
	for i in 6:
		corners.append(HexMetrics.corner(hex_size, i))
	for i in 6:
		for vertex in [Vector3.ZERO, corners[i], corners[(i + 1) % 6]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	var drop := Vector3(0.0, BOTTOM_Y - TOP_Y, 0.0)
	for i in 6:
		var c1 := corners[i]
		var c2 := corners[(i + 1) % 6]
		var normal := ((c1 + c2) * 0.5).normalized()
		for vertex in [c1, c1 + drop, c2, c2, c1 + drop, c2 + drop]:
			st.set_normal(normal)
			st.add_vertex(vertex)
	st.index()
	return st.commit()
