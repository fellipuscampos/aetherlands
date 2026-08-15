extends Node

## Centraliza a interacao do jogador com o mundo: selecionar unidade,
## mover, atacar e fundar cidade. A camera so faz raycast e repassa a
## posicao clicada para ca; a UI so escuta os sinais do EventBus.

var selected_unit: Unit = null
var reachable: Dictionary = {} # Vector2i -> custo de movimento
var attackable: Array[Vector2i] = []
var _hovered_coord := Vector2i(999999, 999999) # sentinela: nunca bate com um tile real

## Pedido do usuario (relato de bug): "o caminho até uma célula tá sempre
## ligado mesmo sem eu clicar no mover, e clicando de volta isso não sai,
## fica assim pra sempre" — a previa de trajeto/clique-pra-mover ficava
## ativa toda vez que uma unidade era selecionada, mesmo sem apertar o
## botao "Mover" antes (o botao so cancelava Fortificar/Explorar, nao
## "ligava" nada). Agora move_mode comeca DESLIGADO em toda selecao nova
## (ver _select_unit) e so o botao Mover (wake_selected_for_move) liga —
## handle_world_hover/handle_world_click so mostram/aceitam movimento com
## isso true; ATACAR continua sempre disponivel independente disso (e uma
## acao separada de Mover). Desliga sozinho depois de um movimento
## (_select_unit roda de novo e reseta) ou ao trocar pra Fortificar/
## Explorar.
var move_mode: bool = false

## Modo de posicionamento de predio (HUD.gd chama start_building_placement
## ao clicar um botao de predio): enquanto placing_city != null, o PROXIMO
## clique no mundo escolhe o tile do predio em vez de mover/atacar/
## selecionar unidade — mesma ideia de "fundar cidade" (escolhe onde),
## mas o predio nao consome nenhuma unidade.
var placing_city: City = null
var placing_building_id: String = ""
var placeable_coords: Array[Vector2i] = []

## Modo de mira de feitico (HUD.gd chama start_spell_targeting ao clicar
## "Conjurar" no Grimorio): enquanto casting_spell_name != "", o PROXIMO
## clique no mundo escolhe o ALVO do feitico em vez de mover/atacar/
## selecionar unidade/posicionar predio — mesma ideia de start_building_
## placement, so que aqui o alvo e validado na hora do clique (ver
## _valid_spell_target) em vez de uma lista fixa de coords pre-calculada,
## porque "unidade inimiga visivel agora" muda a cada movimento, diferente
## dos vizinhos fixos de uma cidade.
var casting_spell_name: String = ""

func reset() -> void:
	_clear_selection()
	cancel_building_placement()
	cancel_spell_targeting()

## Previa do trajeto tipo Civilization: enquanto uma unidade esta
## selecionada, mostra o caminho ate o tile sob o mouse (se alcancavel) ou
## "ATACAR" (se for um alvo no alcance), com o highlight de destaque por
## cima do verde/vermelho ja existente.
func handle_world_hover(world_pos: Vector3) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if casting_spell_name != "":
		_handle_spell_targeting_hover(world_pos)
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

	if move_mode and reachable.has(coord):
		var path = hex_grid.reconstruct_path(selected_unit.coord, coord)
		hex_grid.set_highlight(reachable.keys(), attackable, path)
		hex_grid.show_hover_label(coord, "%.0f PM" % ceil(reachable[coord]), Color(1.0, 1.0, 0.5))
	elif coord in attackable:
		hex_grid.set_highlight(reachable.keys(), attackable)
		hex_grid.show_hover_label(coord, "ATACAR %s" % _attack_target_name(hex_grid, coord), Color(1.0, 0.4, 0.35))
	elif move_mode and hex_grid.get_unit_at(coord) == null:
		# Previa de "mover ate" tipo Civilization pra destino FORA do
		# alcance deste turno (pedido do usuario: "quero que apareça o
		# rastro mesmo antes de clicar, pra ver qual que é o caminho que
		# vai ser tomado até onde o mouse tá em cima"). compute_path e um
		# Dijkstra SEM teto de movimento (ver HexGrid.compute_path) — mais
		# caro que reconstruct_path acima, mas so roda quando o mouse muda
		# de TILE (ja debounced por _hovered_coord no topo desta funcao),
		# nunca por frame.
		var long_path = hex_grid.compute_path(selected_unit.coord, coord, selected_unit.owner_player, selected_unit.unit_data.flies)
		if long_path.is_empty():
			hex_grid.set_highlight(reachable.keys(), attackable)
			hex_grid.hide_hover_label()
		else:
			hex_grid.set_highlight(reachable.keys(), attackable, long_path)
			hex_grid.show_hover_label(coord, "MOVER (%d hexágonos)" % long_path.size(), Color(0.6, 0.85, 1.0))
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

	if casting_spell_name != "":
		_handle_spell_targeting_click(coord)
		return

	if placing_city != null:
		_handle_building_placement_click(coord)
		return

	if selected_unit != null and move_mode and reachable.has(coord):
		_move_selected_to(coord)
	elif selected_unit != null and coord in attackable:
		_attack_from_selected(coord)
	elif selected_unit != null and move_mode and _try_queue_move_order(selected_unit, coord):
		pass
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

## Chamado pela HUD ao clicar "Conjurar" num feitico do Grimorio — entra em
## modo de mira em vez de aplicar o efeito na hora, esperando o proximo
## clique no mundo escolher o alvo (mesma UX de start_building_placement).
func start_spell_targeting(spell_name: String) -> void:
	_clear_selection() # nao faz sentido mover/atacar enquanto mira um feitico
	cancel_building_placement()
	casting_spell_name = spell_name

func cancel_spell_targeting() -> void:
	casting_spell_name = ""
	if GameManager.hex_grid:
		GameManager.hex_grid.hide_hover_label()

func _handle_spell_targeting_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	var target = _valid_spell_target(hex_grid, casting_spell_name, coord)
	if target:
		hex_grid.show_hover_label(coord, "CONJURAR %s" % casting_spell_name, Color(0.7, 0.4, 0.9))
	else:
		hex_grid.hide_hover_label()

## Confirma no alvo clicado (se for valido pro feitico atual) ou cancela a
## mira (qualquer outro clique) — mesmo escape hatch de _handle_building_
## placement_click. Nos dois casos, volta o foco pro tile clicado.
func _handle_spell_targeting_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var spell_name = casting_spell_name
	var target = _valid_spell_target(hex_grid, spell_name, coord)
	cancel_spell_targeting()
	if target != null:
		var message = SpellManager.cast(GameManager.human_player, spell_name, target, hex_grid, TurnManager.turn_number)
		EventBus.notify.emit(message, "combat")
		hex_grid.recompute_fog(GameManager.human_player)
		GameManager.check_game_over()
	hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

## Unidade sob `coord` que e um alvo valido pro feitico `spell_name`, ou
## null se nao houver nenhuma (feitico sem efeito cadastrado, tile vazio,
## ou unidade que nao bate com o target_kind do feitico). "enemy_unit_in_
## vision" aceita tanto civ rival em guerra quanto monstro neutro
## (owner_player == null e sempre hostil, mesma regra de _select_unit),
## desde que o tile esteja VISIVEL agora pro jogador humano — nao da pra
## mirar algo so lembrado (PlayerData.known_enemy_cities e so pra
## cidade, que nem se move).
func _valid_spell_target(hex_grid: HexGrid, spell_name: String, coord: Vector2i) -> Unit:
	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	if spell == null:
		return null
	var unit = hex_grid.get_unit_at(coord)
	if unit == null:
		return null
	var human = GameManager.human_player
	match spell.target_kind:
		"enemy_unit_in_vision":
			if unit.owner_player == human:
				return null
			if unit.owner_player != null and not human.is_at_war_with(unit.owner_player):
				return null
			if not hex_grid.compute_visible_tiles(human).has(coord):
				return null
			return unit
		"friendly_unit":
			return unit if unit.owner_player == human else null
	return null

func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	move_mode = false
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
	move_mode = false
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
	# Comando manual NOVO cancela qualquer ordem/modo automatico pendente
	# (ver Unit.move_order_target/fortified/exploring) — senao a unidade
	# ia mais uma vez pro destino ANTIGO no proximo turno, ou continuava
	# fortificada/explorando por cima de onde o jogador acabou de manda-la
	# de proposito.
	unit.move_order_target = Unit.NO_MOVE_ORDER
	unit.fortified = false
	unit.exploring = false
	hex_grid.move_unit(unit, coord, cost)
	hex_grid.recompute_fog(GameManager.human_player)
	# Mantem o mesmo unit selecionado apos mover: recalcula alcance (pode
	# ficar vazio se acabou o movimento, o que e o esperado).
	_select_unit(unit)

## "Mover ate" tipo Civilization (pedido do usuario: "no civilization eu
## posso colocar pra ela se mover pra um lugar longe... o movimento fica
## gravado e todo turno essa tropa vai se movendo") — so dispara se o
## clique NAO foi um destino alcancavel NESTE turno (reachable, ja
## checado antes) nem um alvo de ataque (attackable, idem), e existe
## algum caminho de verdade ate `coord` (HexGrid.compute_path aplica as
## MESMAS regras de passagem de compute_reachable — sem empilhar unidade,
## sem entrar em cidade inimiga, terreno bloqueado so pra quem nao voa —
## so sem o teto de movimento de UM turno). Devolve false (deixa
## handle_world_click cair no fallback de selecionar/desselecionar) se o
## clique nao for um destino valido — ex: tile com outra unidade, que
## deveria tentar SELECIONAR aquela unidade em vez de virar ordem de
## movimento.
func _try_queue_move_order(unit: Unit, coord: Vector2i) -> bool:
	var hex_grid = GameManager.hex_grid
	if hex_grid.get_unit_at(coord) != null:
		return false
	var path = hex_grid.compute_path(unit.coord, coord, unit.owner_player, unit.unit_data.flies)
	if path.is_empty():
		return false
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = coord
	# Anda o quanto der JA neste turno (reusa continue_move_order, a MESMA
	# funcao que roda nas trocas de turno seguintes) em vez de esperar o
	# proximo turno pra comecar — clicar longe deveria mover a unidade na
	# hora, so continuar nos turnos seguintes se nao coube tudo de uma vez.
	hex_grid.continue_move_order(unit)
	hex_grid.recompute_fog(GameManager.human_player)
	if unit.move_order_target != Unit.NO_MOVE_ORDER:
		EventBus.notify.emit("%s vai continuar se movendo nos próximos turnos." % unit.unit_data.unit_name, "")
	_select_unit(unit)
	return true

## Botao "Mover" do painel de unidade (pedido do usuario: "as opções...
## que se me recordo civilization é mover, fortificar e explorar", e
## depois um relato de bug: "o caminho até uma célula tá sempre ligado
## mesmo sem eu clicar no mover") — LIGA move_mode, que e o que de fato
## habilita clicar no mapa pra mover/ver a previa de trajeto (ver
## handle_world_hover/handle_world_click). Tambem cancela Fortificar/
## Explorar/qualquer ordem pendente, pra unidade ficar livre pra receber
## um comando novo.
func wake_selected_for_move() -> void:
	if selected_unit == null:
		return
	var unit = selected_unit
	unit.fortified = false
	unit.exploring = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	move_mode = true
	_hovered_coord = Vector2i(999999, 999999) # forca o hover recalcular na proxima posicao do mouse, mesmo sem o tile mudar
	EventBus.unit_selected.emit(unit) # so refresca os botoes da HUD, unidade nao se move nem desseleciona

## Botao "Fortificar" — alterna Unit.fortified (pedido do usuario: "o
## fortificar é um estado de alerta, ele fica parado, se curando... ao
## ativar o estado de fortificado ele deve cancelar as outras ações").
## Ligar CANCELA TUDO que faria a unidade se mexer sozinha — Explorar E
## qualquer ordem de "mover ate" pendente (Unit.move_order_target). BUG
## relatado pelo usuario ("se ele tiver movendo e eu ativar o fortificar
## ele não para"): antes so cancelava Explorar, deixando uma ordem de
## movimento em andamento livre pra continuar no proximo turno por cima
## do Fortificar — agora as DUAS saidas de "a unidade anda sozinha"
## (Explorar E move_order_target) sao limpas juntas, sem excecao.
func fortify_selected() -> void:
	if selected_unit == null:
		return
	var unit = selected_unit
	unit.fortified = not unit.fortified
	if unit.fortified:
		unit.exploring = false
		unit.move_order_target = Unit.NO_MOVE_ORDER
	move_mode = false
	EventBus.unit_selected.emit(unit)

## Botao "Explorar" — alterna Unit.exploring (pedido do usuario: "uma
## função que fica ativada... que se baseie em ficar andando por
## territórios que ainda não foram explorados"). Ligar cancela Fortificar
## e qualquer ordem de "mover ate" pendente, e ja anda o quanto der NESTE
## turno (reusa HexGrid.explore_step, a MESMA funcao que roda nas trocas
## de turno seguintes) — mesma UX de _try_queue_move_order, nao espera o
## proximo turno pra comecar.
func toggle_explore_selected() -> void:
	if selected_unit == null:
		return
	var unit = selected_unit
	unit.exploring = not unit.exploring
	move_mode = false
	if not unit.exploring:
		EventBus.unit_selected.emit(unit)
		return
	unit.fortified = false
	unit.move_order_target = Unit.NO_MOVE_ORDER
	var hex_grid = GameManager.hex_grid
	hex_grid.explore_step(unit)
	hex_grid.recompute_fog(GameManager.human_player)
	if is_instance_valid(unit) and not unit.is_queued_for_deletion():
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
	# Atacar cancela qualquer ordem/modo automatico pendente (ver
	# Unit.move_order_target/fortified/exploring, _move_selected_to acima,
	# mesmo motivo) — nao faz sentido continuar "Explorar" depois de
	# escolher lutar, e Fortificar so deveria sobreviver a SER atacado
	# (defender), nao a atacar por conta propria.
	attacker.move_order_target = Unit.NO_MOVE_ORDER
	attacker.fortified = false
	attacker.exploring = false
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
