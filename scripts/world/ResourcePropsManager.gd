class_name ResourcePropsManager
extends RefCounted

## Props 3D pros recursos estrategicos/luxo do mapa (ver ResourceDatabase/
## HexTileData.resource) — pedido do usuario: "Instancie props/icones 3D
## visiveis nos tiles que possuem recursos". Classe separada (nao mais
## codigo dentro de HexGrid._rebuild_props, que ja estava enorme) pra
## isolar a responsabilidade, mas segue EXATAMENTE o mesmo padrao ja
## estabelecido pra arvores/pedras/picos de montanha: 1 MultiMeshInstance3D
## por "tipo" (aqui, por tipo de RECURSO em vez de bioma) + Dictionary
## coord -> Array[indice] pra tingir por fog-of-war depois. Guarda uma
## referencia pro HexGrid dono (nao extends Node — nao precisa de posicao
## propria na arvore de cena, so usa hex_grid pra ler tiles/world_for_coord
## e pra `add_child()` os MultiMeshInstance3D, e pra reusar
## HexGrid._sepia_prop_color no fog, evitando duplicar aquela formula).
var _hex_grid: HexGrid

## 1 malha composta por recurso (SurfaceTool, varias formas simples numa
## unica superficie com cor por vertice — mesma tecnica de HexGrid.
## _build_tree_mesh), construida so UMA VEZ (geometria e sempre a mesma,
## independente de quantos tiles tem aquele recurso).
var _meshes: Dictionary = {} # resource_kind (String) -> ArrayMesh

var _instances: Dictionary = {} # resource_kind -> MultiMeshInstance3D
var _coord_to_index: Dictionary = {} # resource_kind -> Dictionary[Vector2i, Array[int]]

func _init(hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	_meshes["iron"] = _build_iron_mesh()
	_meshes["horses"] = _build_horses_mesh()
	_meshes["gems"] = _build_gems_mesh()
	_meshes["silk"] = _build_silk_mesh()

## Reconstroi todos os MultiMeshInstance3D de recurso do zero a partir do
## mapa atual — chamado de HexGrid._rebuild_props(), mesma cadencia de
## arvores/pedras/picos (regeneracao de mapa inteira, nao por turno).
func rebuild(tiles: Dictionary) -> void:
	for kind in _instances.keys():
		var instance: MultiMeshInstance3D = _instances[kind]
		if instance:
			instance.queue_free()
	_instances.clear()
	_coord_to_index.clear()

	var coords_by_kind: Dictionary = {}
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.resource == "" or not _meshes.has(data.resource):
			continue
		if not coords_by_kind.has(data.resource):
			coords_by_kind[data.resource] = []
		coords_by_kind[data.resource].append(coord)

	for kind in coords_by_kind.keys():
		_build_instance_for_kind(kind, coords_by_kind[kind])

func _build_instance_for_kind(kind: String, coords: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _meshes[kind]
	mm.instance_count = coords.size()

	var coord_to_index := {}
	for i in range(coords.size()):
		var coord: Vector2i = coords[i]
		var pos = _hex_grid.world_for_coord(coord)
		# Leve jitter de posicao/rotacao (mesmo espirito da pedra de Colina
		# em HexGrid._rebuild_props) — sem isso todo tile do mesmo recurso
		# ficaria com o prop cravado EXATAMENTE no centro, lendo como
		# grade repetida em vez de algo organico.
		pos.x += randf_range(-0.12, 0.12)
		pos.z += randf_range(-0.12, 0.12)
		var basis = Basis(Vector3.UP, randf() * TAU)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_color(i, Color.WHITE) # cor ja vem embutida por vertice na malha, ver _build_*_mesh
		coord_to_index[coord] = [i]

	_coord_to_index[kind] = coord_to_index

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Nevoa de guerra (pedido do usuario, requisito 2: "respeitar o sistema
	# de Nevoa de Guerra... visibilidade zerada se UNEXPLORED") — mesmo
	# SCISSOR binario 0/1 usado pros outros props (ver HexGrid._rebuild_props
	# tree_mat/rock_mat/spike_mat), nunca alfa fracionario.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	instance.material_override = mat
	_hex_grid.add_child(instance)
	_instances[kind] = instance

## Chamado de HexGrid._apply_prop_fog(), mesma cadencia de _tint_props pras
## arvores/pedras/picos — reusa HexGrid._sepia_prop_color (nao duplica a
## formula) porque, ao contrario dos shaders (arquivos isolados sem
## compartilhamento de codigo entre si), aqui e so uma chamada de metodo
## normal do GDScript pela referencia _hex_grid ja guardada.
func apply_fog(visibility: Dictionary) -> void:
	for kind in _instances.keys():
		var instance: MultiMeshInstance3D = _instances[kind]
		var coord_to_index: Dictionary = _coord_to_index[kind]
		for coord in coord_to_index.keys():
			var indices: Array = coord_to_index[coord]
			var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
			var color := Color.WHITE
			match vis:
				HexGrid.Visibility.UNSEEN:
					color = Color(1.0, 1.0, 1.0, 0.0)
				HexGrid.Visibility.EXPLORED:
					color = _hex_grid._sepia_prop_color(Color.WHITE)
				HexGrid.Visibility.VISIBLE:
					pass
			for idx in indices:
				instance.multimesh.set_instance_color(idx, color)

## Cone simples (base circular jitterizada por `sides`, apice no eixo Y) —
## mesma tecnica generica de HexGrid._add_cone, duplicada aqui de proposito
## (cada malha de recurso e uma composicao de 2-3 destes, e essa classe e
## propositalmente autocontida, sem depender de metodos privados de
## HexGrid alem do _sepia_prop_color acima). cull_disabled no material
## (ver _build_instance_for_kind) cobre qualquer duvida de ordem de
## vertice, entao a winding aqui nao precisa ser perfeita.
func _add_cone(st: SurfaceTool, base_center: Vector3, radius: float, height: float, color: Color, sides: int = 6) -> void:
	var apex = base_center + Vector3(0, height, 0)
	for i in range(sides):
		var a0 = (TAU / sides) * i
		var a1 = (TAU / sides) * (i + 1)
		var p0 = base_center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 = base_center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var normal = (p1 - apex).cross(p0 - apex).normalized()
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(apex)
		st.set_color(color)
		st.add_vertex(p0)
		st.set_color(color)
		st.add_vertex(p1)

## Minerio de Ferro: pilha baixa de pedras angulosas cinza-azulado, com um
## fragmento mais claro por cima simulando o brilho do metal exposto.
func _build_iron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(-0.05, 0.0, 0.03), 0.14, 0.16, Color(0.4, 0.42, 0.46), 6)
	_add_cone(st, Vector3(0.08, 0.0, -0.05), 0.1, 0.12, Color(0.34, 0.36, 0.4), 6)
	_add_cone(st, Vector3(0.0, 0.12, 0.06), 0.06, 0.08, Color(0.62, 0.64, 0.68), 5)
	return st.commit()

## Cavalos: 3 fardos de feno baixos e largos (cones achatados) simbolizando
## pastagem/curral — sem modelar um cavalo de verdade (fora de escopo pra
## um icone de recurso de mapa).
func _build_horses_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(-0.1, 0.0, 0.0), 0.13, 0.11, Color(0.76, 0.63, 0.28), 8)
	_add_cone(st, Vector3(0.09, 0.0, 0.06), 0.12, 0.1, Color(0.8, 0.68, 0.32), 8)
	_add_cone(st, Vector3(0.02, 0.0, -0.09), 0.11, 0.1, Color(0.72, 0.58, 0.24), 8)
	return st.commit()

## Gemas: cluster de 3 cristais finos e altos em tons de ametista, alturas
## e rotacoes diferentes pra silhueta irregular (nao 3 conees identicos).
func _build_gems_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(0.0, 0.0, 0.0), 0.07, 0.28, Color(0.68, 0.32, 0.82), 5)
	_add_cone(st, Vector3(-0.08, 0.0, 0.04), 0.05, 0.18, Color(0.78, 0.45, 0.9), 5)
	_add_cone(st, Vector3(0.07, 0.0, -0.05), 0.045, 0.15, Color(0.6, 0.28, 0.75), 5)
	return st.commit()

## Seda: pequena moita/amoreira (2 cones achatados empilhados) em verde
## desbotado — tematicamente ligado ao bicho-da-seda em vez de tentar
## desenhar um tear em miniatura.
func _build_silk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(0.0, 0.0, 0.0), 0.22, 0.14, Color(0.4, 0.56, 0.36), 8)
	_add_cone(st, Vector3(0.0, 0.1, 0.0), 0.15, 0.13, Color(0.46, 0.62, 0.4), 8)
	return st.commit()
