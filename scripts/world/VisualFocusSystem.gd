class_name VisualFocusSystem
extends Node3D

## V3 / Etapa 3 — FOCO VISUAL / TRANSPARÊNCIA POR TILE (render-only).
##
## Problema: unidade parada num tile com floresta, recurso, melhoria, prédio, covil ou cidade some atrás do modelo.
## Regra padrão (FOCO NA UNIDADE): em todo tile com unidade visível, a decoração (árvores, prop de recurso, gelo) e
## as estruturas do tile ficam semitransparentes; a unidade fica opaca. O inspetor muda o foco do tile selecionado:
##  - Unidade   → igual ao padrão;
##  - Estrutura → prédio/cidade/covil/melhoria opacos, a unidade é que fica semitransparente;
##  - Terreno   → tudo em cima do tile (decoração, estrutura, unidade) semitransparente para ler o chão.
##
## Como (sem tocar em material compartilhado — o material das árvores é UM para o mapa inteiro):
##  - nós (prédio, cidade, covil, marcador, unidade): GeometryInstance3D.transparency em cada MeshInstance3D do nó
##    (propriedade da INSTÂNCIA; o valor original é guardado e devolvido);
##  - props em MultiMesh (árvores/recursos/gelo): as instâncias do tile são escondidas (escala zero, transform
##    original guardado) e copiadas para um MultiMeshInstance3D pequeno PRÓPRIO deste tile, que usa o mesmo mesh/
##    material (sem modificar) com `transparency` própria. Ao sair, a instância original volta e o overlay some.
## Dirigido a evento: HexGrid marca sujo em mover/teleportar/criar/remover unidade, fundar cidade, posicionar prédio,
## melhoria, covil e na névoa; o recálculo roda UMA vez no fim do frame (call_deferred), nunca em _process.
## Fade 0.15s; Reduced Motion = instantâneo. Sem tela (lab/testes headless) fica desligado — testes ligam.

const MODE_UNIT := "unit"
const MODE_STRUCTURE := "structure"
const MODE_TERRAIN := "terrain"
const PROP_TRANSPARENCY := 0.65 # alpha ≈ 0.35
const STRUCTURE_TRANSPARENCY := 0.55 # alpha ≈ 0.45
const UNIT_TRANSPARENCY := 0.55
const FADE_TIME := 0.15

static var enabled_in_headless := false

var grid: HexGrid
var focus_coord := Vector2i(-99999, -99999)
var focus_mode := MODE_UNIT
var refresh_count := 0 # observabilidade (testes/benchmark)

## coord -> {"props": Array[{source, indices, transforms, overlay}], "structure": Array[[GeometryInstance3D, float]],
##           "unit": Unit|null, "unit_meshes": Array[[GeometryInstance3D, float]], "want": Dictionary}
var _applied: Dictionary = {}
var _dirty := false
## coord -> Array de props em fade-out (a instância original só volta no fim do fade; concluído na hora se o tile
## voltar a ser focado ou se outro sistema precisar mexer nos props).
var _pending_restore: Dictionary = {}

func _init(owner_grid: HexGrid = null) -> void:
	grid = owner_grid
	name = "VisualFocusSystem"

func active() -> bool:
	return grid != null and is_inside_tree() and (enabled_in_headless or DisplayServer.get_name() != "headless")

# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## Foco do inspetor no tile selecionado (Unidade/Estrutura/Terreno). coord inválido = só a regra padrão.
func set_focus(coord: Vector2i, mode: String) -> void:
	if coord == focus_coord and mode == focus_mode:
		return
	focus_coord = coord
	focus_mode = mode
	mark_dirty()

func clear_focus() -> void:
	set_focus(Vector2i(-99999, -99999), MODE_UNIT)

func mark_dirty() -> void:
	if _dirty or not active():
		return
	_dirty = true
	call_deferred("_flush")

func _flush() -> void:
	if not _dirty:
		return
	_dirty = false
	refresh()

## Mapa novo/carregado/limpo: descarta overlays SEM restaurar (os props de origem estão sendo reconstruídos).
func reset() -> void:
	for coord in _applied.keys():
		var entry: Dictionary = _applied[coord]
		for prop in entry.props:
			if is_instance_valid(prop.overlay):
				prop.overlay.queue_free()
		_set_transparency(entry.structure, false, false)
		_set_transparency(entry.unit_meshes, false, false)
	for coord in _pending_restore.keys():
		for prop in _pending_restore[coord]:
			if is_instance_valid(prop.overlay):
				prop.overlay.queue_free()
	_pending_restore.clear()
	_applied.clear()
	focus_coord = Vector2i(-99999, -99999)
	focus_mode = MODE_UNIT

## Devolve os props escondidos de `coord` antes de outro sistema mexer neles (limpar decoração, reconstruir terreno).
func release_props(coord: Vector2i) -> void:
	_finish_restore(coord)
	if not _applied.has(coord):
		return
	_restore_props(coord, _applied[coord], false)
	(_applied[coord] as Dictionary).want.props = false
	mark_dirty()

func is_focused(coord: Vector2i) -> bool:
	return _applied.has(coord)

func applied_state(coord: Vector2i) -> Dictionary:
	if not _applied.has(coord):
		return {}
	var entry: Dictionary = _applied[coord]
	return {"props": entry.props.size(), "structure": entry.structure.size(), "unit": entry.unit_meshes.size() > 0}

# ---------------------------------------------------------------------------
# Recálculo (O(unidades) por evento, sem varrer o mapa)
# ---------------------------------------------------------------------------

func refresh() -> void:
	if grid == null:
		return
	refresh_count += 1
	var wanted := {}
	for coord in grid.units_by_coord:
		var unit: Unit = grid.units_by_coord[coord]
		if unit == null or not is_instance_valid(unit) or not unit.visible:
			continue
		if _has_props(coord) or not _structure_nodes(coord).is_empty():
			wanted[coord] = {"props": true, "structure": true, "unit": false}
	if grid.tiles.has(focus_coord):
		var unit_here := grid.get_unit_at(focus_coord)
		var has_unit := unit_here != null and unit_here.visible
		match focus_mode:
			MODE_STRUCTURE:
				wanted[focus_coord] = {"props": true, "structure": false, "unit": has_unit}
			MODE_TERRAIN:
				wanted[focus_coord] = {"props": true, "structure": true, "unit": has_unit}
	for coord in _applied.keys():
		if not wanted.has(coord):
			_release(coord)
	for coord in wanted:
		_apply(coord, wanted[coord])

func _apply(coord: Vector2i, want: Dictionary) -> void:
	var entry: Dictionary = _applied.get(coord, {"props": [], "structure": [], "unit": null, "unit_meshes": [], "want": {}})
	_applied[coord] = entry
	entry.want = want
	# Decoração em MultiMesh.
	if bool(want.props) and entry.props.is_empty():
		_hide_props(coord, entry)
	elif not bool(want.props) and not entry.props.is_empty():
		_restore_props(coord, entry, true)
	# Estruturas (recoleta: o conjunto de nós do tile pode ter mudado).
	var structure_meshes: Array = []
	if bool(want.structure):
		for node in _structure_nodes(coord):
			_collect_meshes(node, structure_meshes)
	_swap_set(entry, "structure", structure_meshes, STRUCTURE_TRANSPARENCY)
	# Unidade.
	var unit := grid.get_unit_at(coord)
	var unit_meshes: Array = []
	if bool(want.unit) and unit != null and unit._visual_root != null:
		_collect_meshes(unit._visual_root, unit_meshes)
	entry.unit = unit if bool(want.unit) else null
	_swap_set(entry, "unit_meshes", unit_meshes, UNIT_TRANSPARENCY)
	if entry.props.is_empty() and entry.structure.is_empty() and entry.unit_meshes.is_empty():
		_applied.erase(coord)

func _release(coord: Vector2i) -> void:
	var entry: Dictionary = _applied[coord]
	_restore_props(coord, entry, true)
	_set_transparency(entry.structure, false, true)
	_set_transparency(entry.unit_meshes, false, true)
	_applied.erase(coord)

## Troca o conjunto de malhas semitransparentes: devolve as que saíram, aplica nas que entraram.
func _swap_set(entry: Dictionary, key: String, meshes: Array, amount: float) -> void:
	var keep: Array = []
	var current := {}
	for pair in entry[key]:
		current[pair[0]] = pair
	var incoming := {}
	for mesh in meshes:
		incoming[mesh] = true
	var leaving: Array = []
	for pair in entry[key]:
		if is_instance_valid(pair[0]) and incoming.has(pair[0]):
			keep.append(pair)
		elif is_instance_valid(pair[0]):
			leaving.append(pair)
	_set_transparency(leaving, false, true)
	var arriving: Array = []
	for mesh in meshes:
		if not current.has(mesh):
			arriving.append([mesh, (mesh as GeometryInstance3D).transparency])
	keep.append_array(arriving)
	entry[key] = keep
	_set_transparency(arriving, true, true, amount)

# ---------------------------------------------------------------------------
# Nós
# ---------------------------------------------------------------------------

func _structure_nodes(coord: Vector2i) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for source in [grid.buildings_by_coord, grid.cities_by_coord, grid.lairs_by_coord, grid.improvement_markers_by_coord, grid._construction_markers]:
		var node = source.get(coord)
		if node != null and is_instance_valid(node) and node is Node3D and (node as Node3D).visible:
			nodes.append(node)
	var props := grid._resource_props_manager
	if props != null and props._horse_instances.has(coord) and is_instance_valid(props._horse_instances[coord]):
		nodes.append(props._horse_instances[coord])
	return nodes

## Só malhas (MeshInstance3D/MultiMeshInstance3D) — rótulos/ícones (Label3D/Sprite3D) continuam legíveis.
static func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)

func _set_transparency(pairs: Array, on: bool, animate: bool, amount: float = 0.0) -> void:
	var tween: Tween = null
	for pair in pairs:
		var mesh: GeometryInstance3D = pair[0]
		if not is_instance_valid(mesh):
			continue
		var target: float = amount if on else float(pair[1])
		if animate and _motion():
			if tween == null:
				tween = create_tween().set_parallel(true)
			tween.tween_property(mesh, "transparency", target, FADE_TIME)
		else:
			mesh.transparency = target

func _motion() -> bool:
	return not Settings.reduced_motion and is_inside_tree()

# ---------------------------------------------------------------------------
# Decoração em MultiMesh
# ---------------------------------------------------------------------------

## [MultiMeshInstance3D de origem, índices do tile] para cada fonte de decoração com algo neste tile.
func _prop_sources(coord: Vector2i) -> Array:
	var sources: Array = []
	if grid._props_tree_instance != null and grid._tree_coord_to_index.has(coord):
		sources.append([grid._props_tree_instance, grid._tree_coord_to_index[coord]])
	if grid._changed_tree_props.has(coord) and is_instance_valid(grid._changed_tree_props[coord]):
		sources.append([grid._changed_tree_props[coord], [0, 1, 2]])
	if grid._props_ice_floe_instance != null and grid._ice_floe_coord_to_index.has(coord):
		sources.append([grid._props_ice_floe_instance, grid._ice_floe_coord_to_index[coord]])
	var props := grid._resource_props_manager
	if props != null:
		for kind in props._coord_to_index:
			var map: Dictionary = props._coord_to_index[kind]
			if map.has(coord) and props._instances.has(kind):
				sources.append([props._instances[kind], map[coord]])
	return sources

func _has_props(coord: Vector2i) -> bool:
	if grid._tree_coord_to_index.has(coord) or grid._changed_tree_props.has(coord) or grid._ice_floe_coord_to_index.has(coord):
		return true
	var props := grid._resource_props_manager
	if props != null:
		for kind in props._coord_to_index:
			if (props._coord_to_index[kind] as Dictionary).has(coord):
				return true
		if props._horse_instances.has(coord):
			return true
	return false

func _hide_props(coord: Vector2i, entry: Dictionary) -> void:
	_finish_restore(coord)
	for pair in _prop_sources(coord):
		var source: MultiMeshInstance3D = pair[0]
		if source == null or not is_instance_valid(source) or source.multimesh == null:
			continue
		var mm := source.multimesh
		var indices: Array = (pair[1] as Array).duplicate()
		var transforms: Array = []
		var colors: Array = []
		for index in indices:
			transforms.append(mm.get_instance_transform(int(index)))
			colors.append(mm.get_instance_color(int(index)) if mm.use_colors else Color.WHITE)
		var overlay_mm := MultiMesh.new()
		overlay_mm.transform_format = MultiMesh.TRANSFORM_3D
		overlay_mm.use_colors = mm.use_colors
		overlay_mm.mesh = mm.mesh
		overlay_mm.instance_count = indices.size()
		for i in indices.size():
			overlay_mm.set_instance_transform(i, transforms[i])
			if mm.use_colors:
				overlay_mm.set_instance_color(i, colors[i])
		var overlay := MultiMeshInstance3D.new()
		overlay.name = "FocusProps_%d_%d" % [coord.x, coord.y]
		overlay.multimesh = overlay_mm
		overlay.material_override = source.material_override # MESMO material, sem modificar
		overlay.cast_shadow = source.cast_shadow
		add_child(overlay)
		overlay.global_transform = source.global_transform
		for index in indices:
			mm.set_instance_transform(int(index), Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		entry.props.append({"source": source, "indices": indices, "transforms": transforms, "overlay": overlay})
		if _motion():
			create_tween().tween_property(overlay, "transparency", PROP_TRANSPARENCY, FADE_TIME)
		else:
			overlay.transparency = PROP_TRANSPARENCY

func _restore_props(coord: Vector2i, entry: Dictionary, animate: bool) -> void:
	if entry.props.is_empty():
		return
	var props: Array = entry.props
	entry.props = []
	if not (animate and _motion()):
		_put_back(props)
		return
	_finish_restore(coord)
	_pending_restore[coord] = props
	var tween := create_tween().set_parallel(true)
	for prop in props:
		if is_instance_valid(prop.overlay):
			tween.tween_property(prop.overlay, "transparency", 0.0, FADE_TIME)
	tween.chain().tween_callback(_finish_restore.bind(coord))

func _finish_restore(coord: Vector2i) -> void:
	if not _pending_restore.has(coord):
		return
	var props: Array = _pending_restore[coord]
	_pending_restore.erase(coord)
	_put_back(props)

func _put_back(props: Array) -> void:
	for prop in props:
		var source: MultiMeshInstance3D = prop.source
		if source != null and is_instance_valid(source) and source.multimesh != null:
			for i in prop.indices.size():
				var index := int(prop.indices[i])
				if index < source.multimesh.instance_count:
					source.multimesh.set_instance_transform(index, prop.transforms[i])
		if is_instance_valid(prop.overlay):
			prop.overlay.queue_free()
