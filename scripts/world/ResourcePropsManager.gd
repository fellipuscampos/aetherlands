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

## "Cavalos": pedido do usuario ("faça um modelo de cavalo pra usar nos
## tiles com o recurso cavalo", explicitamente pela pipeline de verdade
## em vez do box cru direto em GDScript que os outros recursos usam) —
## unico recurso cujo modelo vem de um .glb exportado pela Asset Factory
## (tools/asset_factory/generate_horse.py), nao de SurfaceTool aqui. Nao
## da pra reusar o MultiMeshInstance3D dos outros recursos (_instances
## acima): aquele caminho troca o material do mesh INTEIRO por um so
## flat (`vertex_color_use_as_albedo`), que apagaria as cores/materiais
## de verdade exportados no .glb. Uma instancia de cena de verdade por
## tile (mesmo padrao de Unit/City/Building) preserva os materiais
## originais -- ver _spawn_horse_instance/apply_fog abaixo pro
## equivalente de fog-of-war feito na mao (sepia via material override
## por superficie, ja que um Node3D comum nao tem "modulate" como um
## MultiMesh tem cor por instancia).
const HORSE_SCENE_PATH := "res://assets/generated/resources/horses/horses.glb"
## Modelo exportado em escala REAL de cavalo (~1.7m) pra ficar facil de
## modelar certo no Blender -- decoracao de tile precisa ser bem menor
## que isso (do tamanho das outras, gemas/minerio/seda ocupam so uma
## fracao pequena do tile), daí o downscale aqui em vez de remodelar
## tudo em escala de brinquedo desde o inicio.
const HORSE_SCALE := 0.35
var _horse_scene: PackedScene
var _horse_instances: Dictionary = {} # Vector2i -> Node3D
## Vector2i -> Array[{mesh: MeshInstance3D, surface: int, sepia: Material}]
## -- precomputado UMA vez no spawn (nao a cada apply_fog) pra so trocar
## o material override na hora de tingir, nunca duplicar material em
## tempo real durante o jogo.
var _horse_sepia_overrides: Dictionary = {}

func _init(hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	_meshes["iron"] = _build_iron_mesh()
	_meshes["gems"] = _build_gems_mesh()
	_meshes["silk"] = _build_silk_mesh()
	_meshes["mana_node"] = _build_mana_node_mesh()
	_horse_scene = load(HORSE_SCENE_PATH)

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

	for node in _horse_instances.values():
		if node:
			node.queue_free()
	_horse_instances.clear()
	_horse_sepia_overrides.clear()

	var coords_by_kind: Dictionary = {}
	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.resource == "horses":
			_spawn_horse_instance(coord)
			continue
		if data.resource == "" or not _meshes.has(data.resource):
			continue
		if not coords_by_kind.has(data.resource):
			coords_by_kind[data.resource] = []
		coords_by_kind[data.resource].append(coord)

	for kind in coords_by_kind.keys():
		_build_instance_for_kind(kind, coords_by_kind[kind])

## Instancia de verdade (nao MultiMesh, ver comentario de _horse_scene
## acima) do cavalo exportado em horses.glb, uma por tile com o
## recurso "horses". Mesmo tratamento de altura/jitter que
## _build_instance_for_kind da aos MultiMesh (_tile_surface_height pra
## nao afundar em Colina/Montanha, pequeno jitter de posicao/rotacao pra
## nao ficar identico tile a tile).
func _spawn_horse_instance(coord: Vector2i) -> void:
	if _horse_scene == null:
		return
	var instance: Node3D = _horse_scene.instantiate()
	var pos = _hex_grid.world_for_coord(coord)
	pos.y = _hex_grid._tile_surface_height(coord)
	pos.x += randf_range(-0.08, 0.08)
	pos.z += randf_range(-0.08, 0.08)
	instance.position = pos
	instance.rotation.y = randf() * TAU
	instance.scale = Vector3.ONE * HORSE_SCALE
	_hex_grid.add_child(instance)
	_horse_instances[coord] = instance
	_horse_sepia_overrides[coord] = _precompute_horse_sepia_overrides(instance)

## Duplica CADA material de superficie encontrado em `instance` uma vez
## (sepia via HexGrid._sepia_prop_color, mesma formula/aparencia dos
## outros props) e guarda a lista pra apply_fog so trocar o override na
## hora, sem duplicar material nenhum durante o jogo de verdade.
func _precompute_horse_sepia_overrides(instance: Node3D) -> Array:
	var overrides: Array = []
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(instance, mesh_instances)
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var original: Material = mesh_instance.get_active_material(surface)
			if original == null or not (original is StandardMaterial3D):
				continue
			var sepia: StandardMaterial3D = original.duplicate()
			sepia.albedo_color = _hex_grid._sepia_prop_color(original.albedo_color)
			overrides.append({"mesh": mesh_instance, "surface": surface, "sepia": sepia})
	return overrides

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

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
## Ver ARVORES E RECURSOS (pedido do usuario: "evite sobreposicao ruim
## entre recursos... estruturas; cidades"): remove o prop decorativo de UM
## tile quando uma cidade/predio passa a ocupar aquele tile — confirmado
## visualmente antes do fix (cristal/minerio flutuando dentro do patio da
## cidade). NAO mexe no `.resource` do tile (o bonus de yield continua
## valendo, ver City.effective_tile_yield) — so o objeto 3D que ficaria
## visualmente atras/dentro da estrutura nova.
func clear_prop_at(coord: Vector2i) -> void:
	for kind in _coord_to_index.keys():
		var coord_to_index: Dictionary = _coord_to_index[kind]
		if coord_to_index.has(coord):
			var instance: MultiMeshInstance3D = _instances[kind]
			for index in coord_to_index[coord]:
				instance.multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			coord_to_index.erase(coord)
	if _horse_instances.has(coord):
		_horse_instances[coord].queue_free()
		_horse_instances.erase(coord)
		_horse_sepia_overrides.erase(coord)

func refresh_height(coord: Vector2i) -> void:
	for kind in _coord_to_index:
		for index in _coord_to_index[kind].get(coord, []):
			var mm: MultiMesh = _instances[kind].multimesh
			var transform := mm.get_instance_transform(index)
			transform.origin.y = _hex_grid._tile_surface_height(coord)
			mm.set_instance_transform(index, transform)
	if _horse_instances.has(coord):
		_horse_instances[coord].position.y = _hex_grid._tile_surface_height(coord)

func apply_fog(visibility: Dictionary) -> void:
	for kind in _instances.keys():
		var instance: MultiMeshInstance3D = _instances[kind]
		var coord_to_index: Dictionary = _coord_to_index[kind]
		for coord in coord_to_index.keys():
			var indices: Array = coord_to_index[coord]
			var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
			if _hex_grid.get_tile(coord).resource != kind:
				vis = HexGrid.Visibility.UNSEEN
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

	# "Cavalos": instancia de cena de verdade, nao MultiMesh (ver
	# _horse_scene acima) -- sem cor por instancia disponivel, entao
	# UNSEEN esconde o node inteiro (mesma convencao de Unit/City/
	# Building, ver HexGrid._apply_fog_to_entities) e EXPLORED troca pra
	# um material override sepia pre-computado no spawn (ver
	# _precompute_horse_sepia_overrides) em vez de tingir por vertice.
	for coord in _horse_instances.keys():
		var instance: Node3D = _horse_instances[coord]
		var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
		if _hex_grid.get_tile(coord).resource != "horses":
			vis = HexGrid.Visibility.UNSEEN
		instance.visible = vis != HexGrid.Visibility.UNSEEN
		var use_sepia = vis == HexGrid.Visibility.EXPLORED
		for entry in _horse_sepia_overrides.get(coord, []):
			var mesh_instance: MeshInstance3D = entry["mesh"]
			mesh_instance.set_surface_override_material(entry["surface"], entry["sepia"] if use_sepia else null)

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
