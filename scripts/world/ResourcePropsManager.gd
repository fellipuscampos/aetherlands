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
	_meshes["mana_node"] = _build_mana_node_mesh()

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
		# BUG real (reportado pelo usuario com screenshot: minerio de ferro e
		# Nodulo Arcano "nao tem nada na celula") — world_for_coord() so da
		# base_height, MAS terrain.gdshader eleva o CENTRO visual de Colina/
		# Montanha num domo/pico (ate +HILL_HEIGHT/+MOUNTAIN_PEAK_HEIGHT, ver
		# elevation_height() no shader) que o GDScript nunca via. Ferro e
		# Nodulo Arcano sao os UNICOS recursos elegiveis em Colina/Montanha
		# (ver ResourceDatabase.ELIGIBILITY) — o prop inteiro nascia enterrado
		# DENTRO do proprio terreno, invisivel, exatamente os 2 recursos que o
		# usuario reportou como "sem nada". Gemas/Seda/Cavalos nunca caem em
		# Colina/Montanha, entao nunca bateram nesse bug. _tile_surface_height
		# (mesma funcao que ja resolve isso pros picos de Montanha e pro
		# contorno de territorio da cidade) da a altura VISUAL real do centro
		# do tile — usar ela aqui garante que o prop sempre nasce EM CIMA da
		# superficie de verdade, nao so da base crua.
		pos.y = _hex_grid._tile_surface_height(coord)
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

## Minerio de Ferro: reportado pelo usuario como "nao tem nada na celula" —
## causa raiz de verdade era outra (ver _tile_surface_height acima, o prop
## nascia enterrado), mas a cor tambem nao ajudava: o marrom-acinzentado
## anterior era proximo DEMAIS do proprio tom de terra/Savana por baixo,
## somando contraste ruim em cima de invisibilidade total. Boulders agora
## cinza-carvao BEM mais escuro (contraste forte contra qualquer bioma —
## Savana clara, Floresta verde, neve branca) com veios de minerio expostos
## em laranja-ferrugem MUITO mais vivo/saturado por cima — sao os veios,
## nao os boulders, que fazem o olho reconhecer "ferro" a distancia.
func _build_iron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(-0.12, 0.0, 0.06), 0.26, 0.3, Color(0.22, 0.2, 0.19), 6)
	_add_cone(st, Vector3(0.14, 0.0, -0.08), 0.2, 0.24, Color(0.17, 0.155, 0.145), 6)
	_add_cone(st, Vector3(0.0, 0.0, 0.16), 0.15, 0.18, Color(0.19, 0.17, 0.16), 5)
	_add_cone(st, Vector3(-0.1, 0.16, 0.05), 0.065, 0.11, Color(0.82, 0.4, 0.14), 5)
	_add_cone(st, Vector3(0.12, 0.15, -0.06), 0.05, 0.1, Color(0.9, 0.55, 0.2), 5)
	_add_cone(st, Vector3(0.02, 0.11, 0.14), 0.045, 0.08, Color(0.78, 0.36, 0.12), 4)
	return st.commit()

## Cavalos: pedido do usuario ("cavalos nas celulas de cavalo") — os fardos
## de feno antigos eram so pastagem generica, nao liam como o recurso em
## si. Agora sao 2 cavalos de verdade em silhueta low-poly (corpo+pescoco/
## cabeca+4 pernas+rabo, ver _add_horse), cores diferentes (castanho e
## quase-preto) e rotacoes/escalas diferentes — le como uma pequena
## manada, nao 2 copias identicas do mesmo objeto.
func _build_horses_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_horse(st, Vector3(-0.13, 0.0, 0.05), 0.4, 1.0, Color(0.55, 0.36, 0.18), Color(0.32, 0.2, 0.1))
	_add_horse(st, Vector3(0.14, 0.0, -0.08), -0.9, 0.85, Color(0.16, 0.12, 0.09), Color(0.08, 0.06, 0.05))
	return st.commit()

## Gemas: pedido do usuario ("cristais pode por grandes veias de cristal")
## — cada cristal agora e 2 cones empilhados (base grossa/escura + ponta
## fina/clara, nao mais 1 cone de cor unica), simulando faceta pegando luz
## na ponta. 4 cristais (era 3) e bem mais altos (ate 0.46 de altura total,
## era 0.28) pra ler como uma veia bem maior irrompendo do chao.
func _build_gems_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(0.0, 0.0, 0.0), 0.09, 0.24, Color(0.42, 0.16, 0.55), 5)
	_add_cone(st, Vector3(0.0, 0.22, 0.0), 0.045, 0.22, Color(0.82, 0.5, 0.95), 5)
	_add_cone(st, Vector3(-0.11, 0.0, 0.05), 0.065, 0.16, Color(0.38, 0.14, 0.5), 5)
	_add_cone(st, Vector3(-0.11, 0.15, 0.05), 0.03, 0.14, Color(0.78, 0.46, 0.92), 5)
	_add_cone(st, Vector3(0.1, 0.0, -0.06), 0.055, 0.13, Color(0.35, 0.13, 0.46), 5)
	_add_cone(st, Vector3(0.1, 0.12, -0.06), 0.028, 0.11, Color(0.75, 0.42, 0.9), 5)
	_add_cone(st, Vector3(0.03, 0.0, -0.13), 0.04, 0.09, Color(0.32, 0.12, 0.42), 4)
	return st.commit()

## Seda: moita/amoreira bem maior que antes (raio 0.3, era 0.22) MAIS
## flores/frutos claros no topo (pedido do usuario: props "muito simples"
## em geral) — sem os pontinhos claros a moita lia como um arbusto
## generico qualquer, nao especificamente ligado a seda/amoreira.
func _build_silk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(0.0, 0.0, 0.0), 0.3, 0.2, Color(0.36, 0.52, 0.32), 8)
	_add_cone(st, Vector3(0.1, 0.12, 0.08), 0.18, 0.16, Color(0.42, 0.58, 0.36), 8)
	_add_cone(st, Vector3(-0.12, 0.1, -0.06), 0.16, 0.15, Color(0.4, 0.56, 0.35), 8)
	_add_cone(st, Vector3(0.14, 0.24, 0.1), 0.025, 0.05, Color(0.92, 0.85, 0.6), 4)
	_add_cone(st, Vector3(-0.08, 0.22, -0.1), 0.02, 0.04, Color(0.88, 0.8, 0.55), 4)
	_add_cone(st, Vector3(0.0, 0.18, 0.15), 0.02, 0.04, Color(0.9, 0.82, 0.58), 4)
	return st.commit()

## Nodulo Arcano: reportado pelo usuario como "nao tem nada na celula" — a
## versao anterior existia mas era pequena DEMAIS (cristal principal so
## 0.22 de altura) pra notar no jogo de verdade. Disco baixo assentado no
## chao como ancora visual, cristal principal bem mais alto (0.34, quase o
## dobro) partindo de uma base JA ELEVADA (_add_cone so cresce pra cima a
## partir do base_center, entao elevar o base_center separa a forma do
## disco embaixo, dando leitura de "levitando"), mais 2 fragmentos
## menores orbitando em alturas diferentes pra silhueta assimetrica.
func _build_mana_node_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, Vector3(0.0, 0.0, 0.0), 0.24, 0.045, Color(0.14, 0.2, 0.28), 8)
	_add_cone(st, Vector3(0.0, 0.22, 0.0), 0.08, 0.34, Color(0.38, 0.82, 0.9), 6)
	_add_cone(st, Vector3(0.13, 0.16, 0.08), 0.05, 0.2, Color(0.5, 0.9, 0.95), 5)
	_add_cone(st, Vector3(-0.12, 0.28, -0.09), 0.04, 0.16, Color(0.32, 0.75, 0.86), 5)
	_add_cone(st, Vector3(0.05, 0.4, -0.03), 0.03, 0.12, Color(0.6, 0.95, 0.98), 5)
	return st.commit()

## Gira um vetor no plano XZ (eixo Y fica intacto) — usado tanto pra
## orientar CADA parte de um cavalo (_add_box y_rotation) quanto pro
## OFFSET de cada parte relativo ao centro do cavalo (senao as pernas/
## cabeca ficariam sempre nos MESMOS eixos mundiais, nao acompanhando a
## rotacao do corpo — 2 cavalos girados ficariam com as pernas apontando
## pro mesmo lugar em vez de cada um pra frente do proprio corpo).
func _rotate_xz(v: Vector3, angle: float) -> Vector3:
	var c = cos(angle)
	var s = sin(angle)
	return Vector3(v.x * c - v.z * s, v.y, v.x * s + v.z * c)

## Caixa retangular simples (6 faces, normal fixa e explicita por face —
## nao depende da ordem de winding pra iluminar certo, ver comentario de
## _add_cone sobre cull_disabled). Rotaciona em torno de Y antes de
## transladar pro `center`, mesma convencao de _add_cone (that recebe o
## centro ja em espaco de mundo local ao prop).
func _add_box(st: SurfaceTool, center: Vector3, half_extents: Vector3, color: Color, y_rotation: float = 0.0) -> void:
	var local_corners = [
		Vector3(-half_extents.x, -half_extents.y, -half_extents.z),
		Vector3(half_extents.x, -half_extents.y, -half_extents.z),
		Vector3(half_extents.x, half_extents.y, -half_extents.z),
		Vector3(-half_extents.x, half_extents.y, -half_extents.z),
		Vector3(-half_extents.x, -half_extents.y, half_extents.z),
		Vector3(half_extents.x, -half_extents.y, half_extents.z),
		Vector3(half_extents.x, half_extents.y, half_extents.z),
		Vector3(-half_extents.x, half_extents.y, half_extents.z),
	]
	var world_corners: Array[Vector3] = []
	for c in local_corners:
		world_corners.append(center + _rotate_xz(c, y_rotation))

	var local_normals = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
	var faces = [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0],
	]
	for f in range(faces.size()):
		var normal = _rotate_xz(local_normals[f], y_rotation)
		var idx = faces[f]
		var quad = [world_corners[idx[0]], world_corners[idx[1]], world_corners[idx[2]], world_corners[idx[3]]]
		for p in [quad[0], quad[1], quad[2]]:
			st.set_normal(normal)
			st.set_color(color)
			st.add_vertex(p)
		for p in [quad[0], quad[2], quad[3]]:
			st.set_normal(normal)
			st.set_color(color)
			st.add_vertex(p)

## Cavalo em silhueta low-poly (corpo + bloco de pescoco/cabeca + 4 pernas
## finas + rabo, todos _add_box) — mesma familia visual "procedural, sem
## assets externos" que o resto do prop system (e das unidades do jogo,
## ver README: "voltei pra forma procedural (box+prisma)"). `body_color`
## pras partes grandes, `dark_color` (mais escuro) pras pernas/rabo, pra
## dar uma sombra de contato barata sem geometria extra.
func _add_horse(st: SurfaceTool, base_center: Vector3, y_rotation: float, scale: float, body_color: Color, dark_color: Color) -> void:
	var parts = [
		{"offset": Vector3(0.0, 0.11, 0.0), "half": Vector3(0.15, 0.065, 0.055), "color": body_color},
		{"offset": Vector3(0.19, 0.17, 0.0), "half": Vector3(0.06, 0.1, 0.045), "color": body_color},
		{"offset": Vector3(0.1, 0.045, 0.045), "half": Vector3(0.025, 0.09, 0.025), "color": dark_color},
		{"offset": Vector3(0.1, 0.045, -0.045), "half": Vector3(0.025, 0.09, 0.025), "color": dark_color},
		{"offset": Vector3(-0.1, 0.045, 0.045), "half": Vector3(0.025, 0.09, 0.025), "color": dark_color},
		{"offset": Vector3(-0.1, 0.045, -0.045), "half": Vector3(0.025, 0.09, 0.025), "color": dark_color},
		{"offset": Vector3(-0.17, 0.13, 0.0), "half": Vector3(0.02, 0.05, 0.02), "color": dark_color},
	]
	for part in parts:
		var rotated_offset = _rotate_xz(part["offset"] * scale, y_rotation)
		_add_box(st, base_center + rotated_offset, part["half"] * scale, part["color"], y_rotation)
