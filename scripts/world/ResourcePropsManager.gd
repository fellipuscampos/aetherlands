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
## HexGrid._memory_prop_color no fog, evitando duplicar aquela formula).
var _hex_grid: HexGrid

## Uma malha por recurso, preparada uma vez a partir dos GLBs do Blender,
## conservando os atlas pixelados dos modelos.
var _meshes: Dictionary = {} # resource_kind (String) -> ArrayMesh

var _instances: Dictionary = {} # resource_kind -> MultiMeshInstance3D
var _coord_to_index: Dictionary = {} # resource_kind -> Dictionary[Vector2i, Array[int]]

## Cavalos conservam uma instância de cena por tile e seus materiais
## originais. Sua névoa usa overrides por superfície; os demais recursos
## usam uma malha texturizada em MultiMesh, com cor por instância.
const HORSE_SCENE_PATH := "res://assets/generated/resources/horses/horse_resource_v1/horse_resource_v1.glb"
const CRYSTAL_SCENE_PATH := "res://assets/generated/resources/crystals/crystal_cluster_v1/crystal_cluster_v1.glb"
const MANA_NODE_SCENE_PATH := "res://assets/generated/resources/arcane_node/arcane_node_v1/arcane_node_v1.glb"
const IRON_SCENE_PATH := "res://assets/generated/resources/iron/iron_outcrop_v1/iron_outcrop_v1.glb"
const SILK_SCENE_PATH := "res://assets/generated/resources/silk/silk_mulberry_v1/silk_mulberry_v1.glb"
## Recursos que BRILHAM (pedido do usuário 2026-10-12: "ponha o cristal e o nódulo arcano para terem um certo brilho,
## que ilumine inclusive o mapa"): recurso -> perfil de GlowProfiles. Todo o efeito vem de HexGrid.world_glow
## (WorldGlow) — a luz de cada tile (grupo GLOW_GROUP, chave = coord) e o material com emissão; aqui só se decide QUEM
## brilha e quando aparece (névoa de guerra, apply_fog). Para outro recurso brilhar, basta uma linha nesta tabela.
const GLOW_PROFILE_BY_KIND := {
	"gems": GlowProfiles.AMETHYST,
	"mana_node": GlowProfiles.ARCANE,
}
const GLOW_GROUP := &"resources"
## Cavalo do Cavaleiro humano, já reduzido a 35% no asset de recurso.
const HORSE_SCALE := 1.0
var _horse_scene: PackedScene
var _horse_instances: Dictionary = {} # Vector2i -> Node3D
## Vector2i -> Array[{mesh: MeshInstance3D, surface: int, memory: Material}]
## -- precomputado UMA vez no spawn (nao a cada apply_fog) pra so trocar
## o material override na hora de tingir, nunca duplicar material em
## tempo real durante o jogo.
var _horse_memory_overrides: Dictionary = {}

func _init(hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	_meshes["iron"] = _load_resource_mesh(IRON_SCENE_PATH)
	_meshes["gems"] = _load_resource_mesh(CRYSTAL_SCENE_PATH)
	_meshes["silk"] = _load_resource_mesh(SILK_SCENE_PATH)
	_meshes["mana_node"] = _load_resource_mesh(MANA_NODE_SCENE_PATH)
	_horse_scene = load(HORSE_SCENE_PATH)

## Bake the GLB node transforms once, keeping its painted atlas and one
## surface. Painted resources reuse the existing batching, fog and focus.
func _load_resource_mesh(scene_path: String) -> ArrayMesh:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var source := packed.instantiate() as Node3D
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_resource_mesh(source, Transform3D.IDENTITY, st)
	var mesh := st.commit()
	source.free()
	return mesh

func _append_resource_mesh(node: Node3D, parent_transform: Transform3D, st: SurfaceTool) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		for surface in range(source.mesh.get_surface_count()):
			st.append_from(source.mesh, surface, transform)
			st.set_material(source.get_active_material(surface))
	for child in node.get_children():
		if child is Node3D:
			_append_resource_mesh(child, transform, st)

## Reconstroi todos os MultiMeshInstance3D de recurso do zero a partir do
## mapa atual — chamado de HexGrid._rebuild_props(), mesma cadencia de
## arvores/pedras/picos (regeneracao de mapa inteira, nao por turno).
func rebuild(tiles: Dictionary) -> void:
	if _hex_grid != null and _hex_grid.visual_focus != null:
		_hex_grid.visual_focus.reset() # V3 / Etapa 3: os MultiMesh de recurso vão ser recriados
	for kind in _instances.keys():
		var instance: MultiMeshInstance3D = _instances[kind]
		if instance:
			instance.queue_free()
	_instances.clear()
	_coord_to_index.clear()
	_glow_shown.clear()
	if _glow() != null:
		_glow().clear_group(GLOW_GROUP)

	for node in _horse_instances.values():
		if node:
			node.queue_free()
	_horse_instances.clear()
	_horse_memory_overrides.clear()

	var coords_by_kind: Dictionary = {}
	for coord in tiles.keys():
		if _hex_grid.lairs_by_coord.has(coord):
			continue
		var data: HexTileData = tiles[coord]
		var improvement: Node3D = _hex_grid.improvement_markers_by_coord.get(coord)
		if is_instance_valid(improvement) and bool(improvement.get_meta("replaces_resource_prop", false)):
			continue # native installation already includes this resource; do not duplicate it on rebuild
		if data.resource == "horses":
			_spawn_horse_instance(coord)
			continue
		if data.resource == "" or not _meshes.has(data.resource) or _meshes[data.resource] == null:
			continue
		if not coords_by_kind.has(data.resource):
			coords_by_kind[data.resource] = []
		coords_by_kind[data.resource].append(coord)

	for kind in coords_by_kind.keys():
		_build_instance_for_kind(kind, coords_by_kind[kind])

## Instancia de verdade (nao MultiMesh, ver comentario de _horse_scene
## acima) do cavalo adaptado em horse_resource_v1.glb, uma por tile com o
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
	_horse_memory_overrides[coord] = _precompute_horse_memory_overrides(instance)

## Duplica CADA material de superficie encontrado em `instance` uma vez
## (com o filtro de memoria de HexGrid._memory_prop_color, igual aos
## outros props) e guarda a lista pra apply_fog so trocar o override na
## hora, sem duplicar material nenhum durante o jogo de verdade.
func _precompute_horse_memory_overrides(instance: Node3D) -> Array:
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
			var memory: StandardMaterial3D = original.duplicate()
			memory.albedo_color = _hex_grid._memory_prop_color(original.albedo_color)
			overrides.append({"mesh": mesh_instance, "surface": surface, "memory": memory})
	return overrides

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

func _glow() -> WorldGlow:
	return _hex_grid.world_glow if _hex_grid != null else null

## coord -> true: tiles cujo brilho (luz + emissão da instância) está aceso agora. Só para apply_fog reenviar o que
## MUDOU, não todo recurso do mapa a cada recálculo de névoa.
var _glow_shown: Dictionary = {}

func _build_instance_for_kind(kind: String, coords: Array) -> void:
	var glow_profile: StringName = GLOW_PROFILE_BY_KIND.get(kind, &"")
	var glows := glow_profile != &"" and _glow() != null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	# Dado por instância (r = brilho ligado) para a névoa apagar o brilho de um tile só; precisa vir ANTES de
	# instance_count. Nasce 0 (apagado), como a luz: apply_fog acende o que está visível.
	mm.use_custom_data = glows
	mm.mesh = _meshes[kind]
	mm.instance_count = coords.size()

	var coord_to_index := {}
	for i in range(coords.size()):
		var coord: Vector2i = coords[i]
		var pos = _hex_grid.world_for_coord(coord)
		# BUG real (reportado pelo usuario com screenshot: minerio de ferro e
		# Nodulo Arcano "nao tem nada na celula") — world_for_coord() so da
		# base_height, MAS terrain.gdshader eleva o CENTRO visual de Colina/
		# Montanha num pico (ate +MOUNTAIN_PEAK_HEIGHT; Colina tinha domo ate 2026-10-09, ver
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
		mm.set_instance_color(i, Color.WHITE) # cor vem do atlas ou dos vertices
		coord_to_index[coord] = [i]
		if glows:
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
			_glow().add_light(GLOW_GROUP, coord, pos, glow_profile)

	_coord_to_index[kind] = coord_to_index

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	if glows:
		# Mesma aparência do material do GLB (o shader de brilho a reproduz, inclusive o recorte de alfa da névoa),
		# mais a emissão do perfil.
		instance.material_override = WorldGlow.prop_material(mm.mesh.surface_get_material(0) as BaseMaterial3D, glow_profile, true)
		_hex_grid.add_child(instance)
		_instances[kind] = instance
		return
	var mat := mm.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
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
## arvores/pedras/picos — reusa HexGrid._memory_prop_color (nao duplica a
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
	# O prop saiu do tile: a luz dele sai junto (senão ficaria um clarão sem nada no lugar).
	_glow_shown.erase(coord)
	if _glow() != null:
		_glow().remove_light(GLOW_GROUP, coord)
	if _horse_instances.has(coord):
		_horse_instances[coord].queue_free()
		_horse_instances.erase(coord)
		_horse_memory_overrides.erase(coord)

func refresh_height(coord: Vector2i) -> void:
	for kind in _coord_to_index:
		for index in _coord_to_index[kind].get(coord, []):
			var mm: MultiMesh = _instances[kind].multimesh
			var transform := mm.get_instance_transform(index)
			transform.origin.y = _hex_grid._tile_surface_height(coord)
			mm.set_instance_transform(index, transform)
			if _glow() != null:
				_glow().move_light(GLOW_GROUP, coord, transform.origin)
	if _horse_instances.has(coord):
		_horse_instances[coord].position.y = _hex_grid._tile_surface_height(coord)

func apply_fog(visibility: Dictionary) -> void:
	for kind in _instances.keys():
		var instance: MultiMeshInstance3D = _instances[kind]
		var coord_to_index: Dictionary = _coord_to_index[kind]
		var glows: bool = instance.multimesh.use_custom_data
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
					color = _hex_grid._memory_prop_color(Color.WHITE)
				HexGrid.Visibility.VISIBLE:
					pass
			for idx in indices:
				instance.multimesh.set_instance_color(idx, color)
			# Brilho só em tile VISÍVEL agora: em tile explorado o prop é uma lembrança em sépia (sem emissão), e uma
			# luz acesa na névoa entregaria o que há ali. Só reenvia o que mudou.
			if glows:
				var lit: bool = vis == HexGrid.Visibility.VISIBLE
				if lit != _glow_shown.has(coord):
					if lit:
						_glow_shown[coord] = true
					else:
						_glow_shown.erase(coord)
					for idx in indices:
						instance.multimesh.set_instance_custom_data(idx, Color(1.0 if lit else 0.0, 0, 0, 0))
					_glow().set_light_shown(GLOW_GROUP, coord, lit)

	# "Cavalos": instancia de cena de verdade, nao MultiMesh (ver
	# _horse_scene acima) -- sem cor por instancia disponivel, entao
	# UNSEEN esconde o node inteiro (mesma convencao de Unit/City/
	# Building, ver HexGrid._apply_fog_to_entities) e EXPLORED troca pra
	# um material override com o filtro de memoria, pre-computado no spawn (ver
	# _precompute_horse_memory_overrides) em vez de tingir por vertice.
	for coord in _horse_instances.keys():
		var instance: Node3D = _horse_instances[coord]
		var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
		if _hex_grid.get_tile(coord).resource != "horses":
			vis = HexGrid.Visibility.UNSEEN
		instance.visible = vis != HexGrid.Visibility.UNSEEN
		var use_memory = vis == HexGrid.Visibility.EXPLORED
		for entry in _horse_memory_overrides.get(coord, []):
			var mesh_instance: MeshInstance3D = entry["mesh"]
			mesh_instance.set_surface_override_material(entry["surface"], entry["memory"] if use_memory else null)
