extends Node

## Centraliza a interacao do jogador com o mundo: selecionar unidade,
## mover, atacar e fundar cidade. A camera so faz raycast e repassa a
## posicao clicada para ca; a UI so escuta os sinais do EventBus.

var selected_unit: Unit = null
var reachable: Dictionary = {} # Vector2i -> custo de movimento
var attackable: Array[Vector2i] = []
var _hovered_coord := Vector2i(999999, 999999) # sentinela: nunca bate com um tile real

## Modo de posicionamento de predio (HUD.gd chama start_building_placement
## ao clicar um botao de predio): enquanto placing_city != null, o PROXIMO
## clique no mundo escolhe o tile do predio em vez de mover/atacar/
## selecionar unidade — mesma ideia de "fundar cidade" (escolhe onde),
## mas o predio nao consome nenhuma unidade.
var placing_city: City = null
var placing_building_id: String = ""
var placeable_coords: Array[Vector2i] = []

func reset() -> void:
	_clear_selection()
	cancel_building_placement()

## Previa do trajeto tipo Civilization: enquanto uma unidade esta
## selecionada, mostra o caminho ate o tile sob o mouse (se alcancavel) ou
## "ATACAR" (se for um alvo no alcance), com o highlight de destaque por
## cima do verde/vermelho ja existente.
func handle_world_hover(world_pos: Vector3) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if placing_city != null:
		_handle_building_placement_hover(world_pos)
		return
	if selected_unit == null:
		return
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord == _hovered_coord:
		return
	_hovered_coord = coord

	if not hex_grid.tiles.has(coord):
		hex_grid.set_highlight(reachable.keys(), attackable)
		hex_grid.hide_hover_label()
		return

	if reachable.has(coord):
		var path = hex_grid.reconstruct_path(selected_unit.coord, coord)
		hex_grid.set_highlight(reachable.keys(), attackable, path)
		hex_grid.show_hover_label(coord, "%.0f PM" % ceil(reachable[coord]), Color(1.0, 1.0, 0.5))
	elif coord in attackable:
		hex_grid.set_highlight(reachable.keys(), attackable)
		hex_grid.show_hover_label(coord, "ATACAR %s" % _attack_target_name(hex_grid, coord), Color(1.0, 0.4, 0.35))
	else:
		hex_grid.set_highlight(reachable.keys(), attackable)
		hex_grid.hide_hover_label()

func handle_world_click(world_pos: Vector3) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if not hex_grid.tiles.has(coord):
		return

	if placing_city != null:
		_handle_building_placement_click(coord)
		return

	if selected_unit != null and reachable.has(coord):
		_move_selected_to(coord)
	elif selected_unit != null and coord in attackable:
		_attack_from_selected(coord)
	else:
		var unit_here = hex_grid.get_unit_at(coord)
		if unit_here != null and unit_here.owner_player == GameManager.human_player:
			_select_unit(unit_here)
		else:
			_clear_selection()

	hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

func found_city_with_selected() -> void:
	if selected_unit == null or not selected_unit.unit_data.can_found_city:
		return
	var hex_grid = GameManager.hex_grid
	var coord = selected_unit.coord
	if hex_grid.get_city_at(coord) != null:
		return

	WorldSetup.found_city_from_settler(hex_grid, selected_unit)
	hex_grid.recompute_fog(GameManager.human_player)
	_clear_selection()
	hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

## Chamado pela HUD ao clicar um botao de predio (ex: "Celeiro") — em vez
## de comecar a produzir na hora, entra em modo de escolha de tile:
## destaca os vizinhos validos da cidade (City.is_valid_building_tile) em
## azul, e espera o proximo clique no mundo confirmar ou cancelar.
func start_building_placement(city: City, building_id: String) -> void:
	_clear_selection() # nao faz sentido mover/atacar enquanto posiciona um predio
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	placing_city = city
	placing_building_id = building_id
	placeable_coords.clear()
	for n in hex_grid.get_neighbors(city.coord):
		if city.is_valid_building_tile(n, hex_grid):
			placeable_coords.append(n)
	hex_grid.set_highlight([], [], [], placeable_coords)

func cancel_building_placement() -> void:
	placing_city = null
	placing_building_id = ""
	placeable_coords.clear()
	if GameManager.hex_grid:
		GameManager.hex_grid.clear_highlight()

func _handle_building_placement_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord in placeable_coords:
		var building_name = BuildingDatabase.get_building(placing_building_id).display_name
		hex_grid.show_hover_label(coord, "CONSTRUIR %s" % building_name, Color(0.4, 0.75, 1.0))
	else:
		hex_grid.hide_hover_label()

## Confirma no tile clicado (se for um dos destacados em azul) ou cancela
## o posicionamento (qualquer outro clique) — mesma logica de escape hatch
## que _clear_selection ja usa pra unidades. Nos dois casos, volta o foco
## pro painel da propria cidade (era o que estava sendo visto antes de
## comecar a posicionar), em vez de deixar o painel desatualizado ou
## pulando pro tile clicado.
func _handle_building_placement_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var city = placing_city
	if coord in placeable_coords:
		var building_id = placing_building_id
		city.set_production(building_id)
		city.pending_building_coord = coord
		hex_grid.refresh_construction_markers()
		var building_name = BuildingDatabase.get_building(building_id).display_name
		EventBus.notify.emit("Construcao de %s iniciada em %s" % [building_name, city.city_name], "confirm")
	cancel_building_placement()
	hex_grid.show_selection_marker(city.coord)
	EventBus.tile_selected.emit(city.coord, hex_grid.get_tile(city.coord))

func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	_hovered_coord = Vector2i(999999, 999999)
	var hex_grid = GameManager.hex_grid
	reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	attackable.clear()
	# unit.movement_left > 0 e o que garante que uma unidade so age uma vez
	# por turno: atacar zera o movimento (CombatResolver.resolve()), entao
	# sem essa checagem aqui o alvo continuava marcado como "atacavel" e
	# clicar de novo disparava outro ataque de graca, sem fim.
	if unit.unit_data.attack > 0.0 and unit.movement_left > 0.0:
		for n in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
			var occ_unit = hex_grid.get_unit_at(n)
			var occ_city = hex_grid.get_city_at(n)
			# Fora de guerra (Diplomacy.gd), nem unidade nem cidade contam como
			# atacaveis — ver PlayerData.is_at_war_with. Monstro neutro guardando
			# um Covil (Unit com owner_player == null, ver MonsterDatabase) e
			# hostil a TODO MUNDO, sempre — nao existe diplomacia com ele.
			if occ_unit and occ_unit.owner_player != unit.owner_player and (occ_unit.owner_player == null or unit.owner_player.is_at_war_with(occ_unit.owner_player)):
				attackable.append(n)
			elif occ_city and occ_city.owner_player != unit.owner_player and unit.owner_player.is_at_war_with(occ_city.owner_player):
				attackable.append(n)
	hex_grid.set_highlight(reachable.keys(), attackable)
	EventBus.unit_selected.emit(unit)

func _clear_selection() -> void:
	selected_unit = null
	reachable.clear()
	attackable.clear()
	_hovered_coord = Vector2i(999999, 999999)
	if GameManager.hex_grid:
		GameManager.hex_grid.clear_highlight()
	EventBus.unit_selected.emit(null)

func _move_selected_to(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var cost = reachable[coord]
	var unit = selected_unit
	hex_grid.move_unit(unit, coord, cost)
	hex_grid.recompute_fog(GameManager.human_player)
	# Mantem o mesmo unit selecionado apos mover: recalcula alcance (pode
	# ficar vazio se acabou o movimento, o que e o esperado).
	_select_unit(unit)

## Nome mostrado no aviso "ATACAR" ao passar o mouse — deixa claro o que
## esta no alcance ANTES de clicar, principalmente pros Covis de Monstro
## (Goblin/Troll/Vivern tem risco bem diferente entre si).
func _attack_target_name(hex_grid: HexGrid, coord: Vector2i) -> String:
	var target_unit = hex_grid.get_unit_at(coord)
	if target_unit:
		return target_unit.unit_data.unit_name
	var target_city = hex_grid.get_city_at(coord)
	if target_city:
		return target_city.city_name
	return ""

func _attack_from_selected(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var attacker = selected_unit
	var defender_unit = hex_grid.get_unit_at(coord)
	if defender_unit:
		CombatResolver.resolve(attacker, defender_unit, hex_grid)
	else:
		var defender_city = hex_grid.get_city_at(coord)
		if defender_city:
			hex_grid.capture_city(defender_city, attacker.owner_player)
			attacker.movement_left = 0.0

	hex_grid.recompute_fog(GameManager.human_player)
	GameManager.check_game_over()

	if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
		_select_unit(attacker)
	else:
		_clear_selection()
