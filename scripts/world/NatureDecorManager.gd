class_name NatureDecorManager
extends RefCounted

## Vegetação do mapa (kit temperate_forest_v1): desenha o que NatureComposer compõe por tile. Mesmo molde do
## ResourcePropsManager (RefCounted com referência ao HexGrid dono, sem nó próprio no mundo).
##
## RENDER: um MultiMeshInstance3D por (asset, região do mapa) — a malha de cada asset é compartilhada por todas as suas
## instâncias, e a divisão em regiões de REGION_TILES x REGION_TILES deixa o culling por AABB útil em mapa grande (um
## MultiMesh do mapa inteiro nunca sai de vista). Material único do kit com recorte de alfa (NatureKitCatalog).
##
## ÍNDICE: tile -> [[chave do grupo, índices]] — a névoa tinge só as instâncias do tile, a limpeza zera só elas, e o
## foco visual (VisualFocusSystem.sources_at) esconde exatamente a vegetação do tile ocupado. A cor-base (tintura do
## bioma) fica guardada por instância: a névoa parte dela (visível = tintura, explorado = sépia dela, oculto = alfa 0).
##
## TILE ALTERADO DEPOIS DA GERAÇÃO (magia de terreno): refresh_tile() zera a composição antiga e cria um grupo pequeno
## só para o tile com a composição do terreno NOVO — determinística, a mesma que o tile teria se o mapa fosse gerado assim.

const REGION_TILES := 12

var _grid: HexGrid
var _fields: Dictionary = {}
## chave -> {instance: MultiMeshInstance3D, base_colors: PackedColorArray}
var _groups: Dictionary = {}
## Vector2i -> Array de [chave, Array[int]] (Array comum, por referência: PackedInt32Array é copiado ao ser lido)
var _by_coord: Dictionary = {}
## Vector2i -> Array de chaves de grupos exclusivos do tile (refresh_tile)
var _tile_groups: Dictionary = {}
## Vector2i -> última Visibility aplicada por apply_fog
var _fog_state: Dictionary = {}
## Tiles com vegetação que ainda não receberam névoa (mapa novo, tile recomposto): o caminho por delta de apply_fog
## sempre os inclui. Otimização de 2026-10-14 (docs/PERFORMANCE_GUIDE.md §6).
var _unfogged: Dictionary = {}
## Direções unitárias (XZ) para os vizinhos de HexGrid.NEIGHBOR_DIRS (constantes da malha; ver _neighbor_dirs)
static var _dirs_cache: PackedVector2Array = PackedVector2Array()

func _init(grid: HexGrid) -> void:
	_grid = grid

# --- Construção -----------------------------------------------------------------------------------------------------------

## Reconstrói toda a vegetação a partir do mapa atual (chamado por HexGrid._rebuild_props, na geração/carga do mapa).
func rebuild(tiles: Dictionary) -> void:
	clear_all()
	_fields = NatureComposer.make_fields(_grid.map_seed)
	# (chave do grupo) -> {asset, entries: Array de [coord, transform, tint]}
	var batches: Dictionary = {}
	var coords: Array = tiles.keys()
	coords.sort()
	for coord in coords:
		for item in compose(coord):
			var key := "%s@%d,%d" % [item.asset, floori(float(coord.x) / REGION_TILES), floori(float(coord.y) / REGION_TILES)]
			if not batches.has(key):
				batches[key] = {"asset": item.asset, "entries": []}
			batches[key].entries.append([coord, _transform_for(coord, item), item.tint])
	for key in batches:
		_build_group(key, batches[key].asset, batches[key].entries)
	for coord in _by_coord:
		_unfogged[coord] = true

## A composição atual de `coord` (pura, sem desenhar) — usada pela construção e pelos testes.
func compose(coord: Vector2i) -> Array[Dictionary]:
	# A limpeza inicial não basta: magia/rebuild/load podem recompor o mesmo tile.
	# Consultas O(1), sem varrer cidades ou o mapa a cada instância de vegetação.
	if _grid.lairs_by_coord.has(coord) or _grid.cities_by_coord.has(coord) or _grid.buildings_by_coord.has(coord) or _grid.improvement_markers_by_coord.has(coord) or _grid._construction_markers.has(coord) or _grid.units_by_coord.has(coord):
		return [] as Array[Dictionary]
	if _fields.is_empty():
		_fields = NatureComposer.make_fields(_grid.map_seed)
	var tile: HexTileData = _grid.get_tile(coord)
	if tile == null or not NatureBiomeProfiles.has_vegetation(tile.terrain_type):
		return [] as Array[Dictionary]
	return NatureComposer.compose_tile(context_for(coord), _fields)

## Contexto do compositor: bioma, recurso, posição no mundo e os vizinhos com a direção de cada um.
## A direção para cada vizinho axial é constante da malha (não depende do tile nem do hex_size): calculada uma vez
## (_neighbor_dirs) — refazer world_for_coord + get_neighbors por tile custava ~40 µs/tile, mais que a composição.
func context_for(coord: Vector2i) -> Dictionary:
	var tile: HexTileData = _grid.get_tile(coord)
	var center := HexMetrics.axial_to_world(coord.x, coord.y, _grid.hex_size)
	var neighbors: Array = []
	var dirs := _neighbor_dirs()
	for i in HexGrid.NEIGHBOR_DIRS.size():
		var neighbor_tile: HexTileData = _grid.tiles.get(coord + HexGrid.NEIGHBOR_DIRS[i])
		if neighbor_tile != null:
			neighbors.append({"terrain": neighbor_tile.terrain_type, "dir": dirs[i]})
	return {
		"coord": coord, "terrain": tile.terrain_type, "has_resource": tile.resource != "",
		"world_xz": Vector2(center.x, center.z), "hex_size": _grid.hex_size, "neighbors": neighbors,
	}

## Direção unitária (XZ) do centro do tile para cada vizinho de HexGrid.NEIGHBOR_DIRS, na mesma ordem.
static func _neighbor_dirs() -> PackedVector2Array:
	if _dirs_cache.is_empty():
		for offset in HexGrid.NEIGHBOR_DIRS:
			var delta := HexMetrics.axial_to_world(offset.x, offset.y, 1.0)
			_dirs_cache.append(Vector2(delta.x, delta.z).normalized())
	return _dirs_cache

func _transform_for(coord: Vector2i, item: Dictionary) -> Transform3D:
	var center := _grid.world_for_coord(coord)
	var local: Vector2 = item.local
	var position := Vector3(center.x + local.x, _grid.surface_height_at(coord, local), center.z + local.y)
	return Transform3D(Basis(Vector3.UP, float(item.angle)).scaled(Vector3.ONE * float(item.scale)), position)

func _build_group(key: String, asset: String, entries: Array) -> void:
	var mesh := NatureKitCatalog.mesh(asset)
	if mesh == null or entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = entries.size()
	var base_colors := PackedColorArray()
	base_colors.resize(entries.size())
	for i in entries.size():
		var coord: Vector2i = entries[i][0]
		mm.set_instance_transform(i, entries[i][1])
		base_colors[i] = entries[i][2]
		mm.set_instance_color(i, entries[i][2])
		_index(coord, key, i)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Nature_%s" % key.replace("@", "_").replace(",", "_").replace("-", "m")
	instance.multimesh = mm
	instance.material_override = NatureKitCatalog.map_material()
	_grid.add_child(instance)
	# shown = instâncias que não estão sob névoa total (alfa > 0); nascem com a cor-base, todas aparecem.
	_groups[key] = {"instance": instance, "base_colors": base_colors, "shown": entries.size()}

func _index(coord: Vector2i, key: String, index: int) -> void:
	if not _by_coord.has(coord):
		_by_coord[coord] = []
	for pair in _by_coord[coord]:
		if pair[0] == key:
			(pair[1] as Array).append(index)
			return
	_by_coord[coord].append([key, [index]])

# --- Mudanças pontuais ------------------------------------------------------------------------------------------------------

## Remove a vegetação de `coord` (cidade, prédio, covil, unidade nascendo, recurso). Nunca recompõe.
func clear_at(coord: Vector2i) -> void:
	var was_shown := int(_fog_state.get(coord, -1)) != HexGrid.Visibility.UNSEEN
	for pair in _by_coord.get(coord, []):
		var group: Dictionary = _groups.get(pair[0], {})
		if group.is_empty() or not is_instance_valid(group.instance):
			continue
		for index in pair[1]:
			(group.instance as MultiMeshInstance3D).multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		if was_shown:
			group.shown = int(group.shown) - (pair[1] as Array).size()
			_sync_group_visibility(group)
	_by_coord.erase(coord)
	_fog_state.erase(coord)
	_unfogged.erase(coord)
	for key in _tile_groups.get(coord, []):
		var group: Dictionary = _groups.get(key, {})
		if not group.is_empty() and is_instance_valid(group.instance):
			group.instance.free()
		_groups.erase(key)
	_tile_groups.erase(coord)

## O terreno de `coord` mudou depois da geração: troca a vegetação pela composição do terreno atual.
func refresh_tile(coord: Vector2i) -> void:
	clear_at(coord)
	var by_asset: Dictionary = {}
	for item in compose(coord):
		if not by_asset.has(item.asset):
			by_asset[item.asset] = []
		by_asset[item.asset].append([coord, _transform_for(coord, item), item.tint])
	var keys: Array = []
	for asset in by_asset:
		var key := "%s@tile_%d_%d" % [asset, coord.x, coord.y]
		_build_group(key, asset, by_asset[asset])
		if _groups.has(key):
			keys.append(key)
	if not keys.is_empty():
		_tile_groups[coord] = keys
	if _by_coord.has(coord):
		_unfogged[coord] = true

func clear_all() -> void:
	for key in _groups:
		var instance = _groups[key].instance
		if instance != null and is_instance_valid(instance):
			instance.queue_free()
	_groups.clear()
	_by_coord.clear()
	_tile_groups.clear()
	_fog_state.clear()
	_unfogged.clear()

# --- Névoa e foco -------------------------------------------------------------------------------------------------------------

## Mesma convenção dos outros props (HexGrid._tint_props): oculto = alfa 0, explorado = sépia da cor-base, visível = cor-base.
## INCREMENTAL: só toca tiles cuja visibilidade mudou desde a última aplicação (`_fog_state`). recompute_fog roda a cada
## passo do humano; repintar todas as instâncias do mapa a cada passo custava ~15–20 ms no mapa padrão. Tile novo ou
## recomposto (rebuild/refresh_tile/clear_at apagam o estado dele) não tem estado e sempre recebe a névoa — nada vaza.
##
## `changed` (opcional, otimização de 2026-10-14): os tiles cuja visibilidade mudou desde o último recompute_fog. Com
## ele, só esses (e os ainda sem névoa, _unfogged) são percorridos — o resultado é o mesmo do laço por todos os tiles
## decorados, porque os demais já estão no estado aplicado. null = laço completo (chamadas fora do recompute_fog).
##
## GRUPO TODO SOB NÉVOA TOTAL: quando nenhuma instância de um grupo aparece (todas com alfa 0, recortadas pelo shader
## em todos os passes), o MultiMeshInstance3D fica `visible = false` — mesma imagem, sem os draw calls do pré-passe,
## da cor e de cada cascata de sombra. Num mapa pouco explorado é a maior parte dos ~300 grupos.
func apply_fog(visibility: Dictionary, changed: Variant = null) -> void:
	var touched := {}
	if changed is Array:
		for coord in changed:
			if _by_coord.has(coord):
				_apply_tile_fog(coord, visibility, touched)
		for coord in _unfogged.keys():
			_apply_tile_fog(coord, visibility, touched)
	else:
		for coord in _by_coord:
			_apply_tile_fog(coord, visibility, touched)
	for group in touched.values():
		_sync_group_visibility(group)

func _apply_tile_fog(coord: Vector2i, visibility: Dictionary, touched: Dictionary) -> void:
	_unfogged.erase(coord)
	var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
	var old = _fog_state.get(coord, -1)
	if old == vis:
		return
	var shown_delta := (1 if vis != HexGrid.Visibility.UNSEEN else 0) - (1 if old != HexGrid.Visibility.UNSEEN else 0)
	for pair in _by_coord[coord]:
		var group: Dictionary = _groups.get(pair[0], {})
		if group.is_empty() or not is_instance_valid(group.instance):
			continue
		var mm: MultiMesh = (group.instance as MultiMeshInstance3D).multimesh
		var base_colors: PackedColorArray = group.base_colors
		for index in pair[1]:
			mm.set_instance_color(index, fog_color(base_colors[index], vis))
		if shown_delta != 0:
			group.shown = int(group.shown) + shown_delta * (pair[1] as Array).size()
			touched[pair[0]] = group
	_fog_state[coord] = vis

func _sync_group_visibility(group: Dictionary) -> void:
	if is_instance_valid(group.instance):
		(group.instance as MultiMeshInstance3D).visible = int(group.shown) > 0

## Cor de uma instância sob a névoa, a partir da cor-base (tintura do bioma).
func fog_color(base: Color, vis: int) -> Color:
	match vis:
		HexGrid.Visibility.UNSEEN:
			return Color(base.r, base.g, base.b, 0.0)
		HexGrid.Visibility.EXPLORED:
			return _grid._memory_prop_color(base)
	return base

## Última visibilidade aplicada ao tile (diagnóstico/testes: o RenderingServer headless não devolve cores de MultiMesh).
func fog_state(coord: Vector2i) -> int:
	return int(_fog_state.get(coord, -1))

## [MultiMeshInstance3D, índices] de cada grupo com vegetação neste tile (VisualFocusSystem esconde exatamente estes).
func sources_at(coord: Vector2i) -> Array:
	var sources: Array = []
	for pair in _by_coord.get(coord, []):
		var group: Dictionary = _groups.get(pair[0], {})
		if not group.is_empty() and is_instance_valid(group.instance):
			sources.append([group.instance, (pair[1] as Array).duplicate()])
	return sources

func has_decor(coord: Vector2i) -> bool:
	return _by_coord.has(coord)

func decorated_coords() -> Array:
	return _by_coord.keys()

func instance_count() -> int:
	var total := 0
	for coord in _by_coord:
		for pair in _by_coord[coord]:
			total += (pair[1] as Array).size()
	return total

func group_count() -> int:
	return _groups.size()
