class_name MarchRouteOverlay
extends Node3D

## ROTA DE MARCHA VISÍVEL (2026-10-13) — pedido do usuário: "às vezes selecionamos uma rota pra um personagem porém a
## gente esquece pra onde ele tá indo; quero que deixe a rota do personagem visível até que ele chegue no ponto de
## destino; a rota só deve ser visível pro dono da tropa".
##
## O QUE DESENHA: para cada unidade do JOGADOR com ordem de marcha pendente (Unit.move_order_target), uma trilha de
## marcas — uma por tile do caminho planejado — e um anel no destino. Some sozinha quando a ordem acaba (chegou, foi
## cancelada, perdeu o caminho): o desenho é só o reflexo de Unit.move_order_target, sem estado próprio de gameplay e
## sem nada salvo. A tropa selecionada tem a trilha mais forte, para destacá-la das outras.
##
## SÓ PARA O DONO: só as unidades de GameManager.human_player, e só quando é uma pessoa que controla o assento
## (GameManager.is_human_controlled) — ordens de outras civilizações nunca são desenhadas. A IA nem usa ordem de
## marcha (decide o movimento a cada turno), então não existe rota alheia para vazar.
##
## A ROTA é a que a unidade vai andar: HexGrid.unit_path, a MESMA função de HexGrid.continue_move_order, replanejada
## quando a unidade anda, o destino muda ou o turno vira (um obstáculo novo desvia a marcha — a trilha acompanha).
##
## CUSTO: orientado a evento, nunca por quadro. Os gatilhos (ordem mudou, unidade removida, névoa recalculada = a
## unidade andou ou o turno virou, seleção mudou) só marcam "sujo"; UMA reconstrução adiada por quadro atende a todos.
## O A* de cada rota fica em cache por (posição, destino, turno). Duas MultiMesh para todas as rotas do mapa.

const DOT_RADIUS_FACTOR := 0.17 # legível também com a câmera no zoom mais afastado
const GOAL_INNER_FACTOR := 0.34
const GOAL_OUTER_FACTOR := 0.46
## Altura acima da superfície do tile (e da camada de névoa, nos tiles nunca vistos).
const LIFT := 0.07
const SELECTED_ALPHA := 0.95
const IDLE_ALPHA := 0.55

var _grid: HexGrid
var _dots: MultiMeshInstance3D
var _goals: MultiMeshInstance3D
var _pending := false
## Unit -> {"from": Vector2i, "to": Vector2i, "turn": int, "path": Array[Vector2i]}
var _plans: Dictionary = {}
## O que está desenhado agora: Unit -> Array[Vector2i] (o caminho, sem o tile da unidade; o último é o destino quando
## há caminho). Para inspeção e testes — o MultiMesh não devolve as instâncias em modo headless.
var _drawn: Dictionary = {}

func _init(grid: HexGrid = null) -> void:
	_grid = grid
	name = "MarchRoutes"

func _ready() -> void:
	if _grid == null:
		_grid = get_parent() as HexGrid
	_dots = _instance("Dots", _dot_mesh())
	_goals = _instance("Goals", _goal_mesh())
	EventBus.unit_move_order_changed.connect(_on_unit_changed)
	EventBus.unit_removed.connect(_on_unit_removed)
	EventBus.unit_selected.connect(_on_unit_changed)
	EventBus.fog_updated.connect(request_refresh)

func _instance(node_name: String, mesh: Mesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = 0
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)
	return instance

func _dot_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	var radius := (_grid.hex_size if _grid != null else 1.0) * DOT_RADIUS_FACTOR
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh

func _goal_mesh() -> Mesh:
	var mesh := TorusMesh.new()
	var size := _grid.hex_size if _grid != null else 1.0
	mesh.inner_radius = size * GOAL_INNER_FACTOR
	mesh.outer_radius = size * GOAL_OUTER_FACTOR
	mesh.rings = 24
	mesh.ring_segments = 6
	return mesh

func _on_unit_changed(_unit = null) -> void:
	request_refresh()

func _on_unit_removed(_former_owner: PlayerData, unit: Unit) -> void:
	_plans.erase(unit)
	request_refresh()

## Marca a trilha como suja; a reconstrução acontece uma vez, no fim do quadro.
func request_refresh() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	_flush.call_deferred()

func _flush() -> void:
	_pending = false
	refresh_now()

func clear() -> void:
	_plans.clear()
	_drawn.clear()
	if _dots != null:
		_dots.multimesh.instance_count = 0
		_goals.multimesh.instance_count = 0

## As rotas desenhadas agora: Unit -> Array[Vector2i].
func routes() -> Dictionary:
	return _drawn

func route_of(unit: Unit) -> Array:
	return _drawn.get(unit, [])

func dot_count() -> int:
	return _dots.multimesh.instance_count if _dots != null else 0

func goal_count() -> int:
	return _goals.multimesh.instance_count if _goals != null else 0

## O dono das rotas: a pessoa que joga. null quando ninguém joga o assento (laboratório) ou não há partida.
func viewer() -> PlayerData:
	var human := GameManager.human_player
	return human if human != null and GameManager.is_human_controlled(human) else null

## A rota que `unit` vai andar para cumprir a ordem de marcha dela, pelo plano atual ([] sem ordem ou sem caminho).
func planned_path(unit: Unit) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if _grid == null or unit == null or not is_instance_valid(unit) or unit.move_order_target == Unit.NO_MOVE_ORDER:
		return empty
	var plan: Dictionary = _plans.get(unit, {})
	if not plan.is_empty() and plan.from == unit.coord and plan.to == unit.move_order_target and int(plan.turn) == TurnManager.turn_number:
		return plan.path
	var path := _grid.unit_path(unit, unit.move_order_target)
	_plans[unit] = {"from": unit.coord, "to": unit.move_order_target, "turn": TurnManager.turn_number, "path": path}
	return path

## Reconstrói a trilha de todas as marchas do jogador. Chamar direto só em teste — o jogo usa request_refresh.
func refresh_now() -> void:
	_drawn.clear()
	if _dots == null:
		return
	var owner := viewer()
	var dot_transforms: Array[Transform3D] = []
	var dot_colors: Array[Color] = []
	var goal_transforms: Array[Transform3D] = []
	var goal_colors: Array[Color] = []
	if owner != null and _grid != null:
		var selected: Unit = SelectionManager.selected_unit
		var tint: Color = owner.civ.color.lightened(0.5) if owner.civ != null else Color(1.0, 0.95, 0.7)
		for unit in owner.units:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.move_order_target == Unit.NO_MOVE_ORDER:
				continue
			var path := planned_path(unit)
			var alpha := SELECTED_ALPHA if unit == selected else IDLE_ALPHA
			var color := Color(tint.r, tint.g, tint.b, alpha)
			var drawn: Array[Vector2i] = []
			for coord in path:
				drawn.append(coord)
				if coord != unit.move_order_target:
					dot_transforms.append(Transform3D(Basis(), _mark_position(coord)))
					dot_colors.append(color)
			# O destino sempre aparece, mesmo que o caminho esteja bloqueado agora (a marcha replaneja no próximo turno).
			if drawn.is_empty():
				drawn.append(unit.move_order_target)
			goal_transforms.append(Transform3D(Basis(), _mark_position(unit.move_order_target)))
			goal_colors.append(color)
			_drawn[unit] = drawn
	for unit in _plans.keys():
		if not _drawn.has(unit):
			_plans.erase(unit) # ordem encerrada (ou unidade liberada): o plano em cache vai junto
	_fill(_dots.multimesh, dot_transforms, dot_colors)
	_fill(_goals.multimesh, goal_transforms, goal_colors)

func _fill(multimesh: MultiMesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])

## Onde a marca de `coord` fica: logo acima da superfície do tile, ou da camada de névoa se ele nunca foi visto.
func _mark_position(coord: Vector2i) -> Vector3:
	var position_on_tile := _grid.world_surface_for_coord(coord)
	if _grid.fog_layer != null and _grid.fog_layer.covers(coord):
		position_on_tile.y = FogLayer.TOP_Y
	position_on_tile.y += LIFT
	return position_on_tile
