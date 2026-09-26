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

## Modo de mira de TÉCNICA DE ATAQUE V2 de alvo único (Golpe Poderoso, Fase 7): o botão da técnica NÃO gasta nada —
## só entra neste modo e destaca os inimigos adjacentes válidos; o PRÓXIMO clique num deles resolve o golpe (recarga +
## ação só aqui), qualquer outro clique ou ESC (PauseMenu -> cancel_technique_targeting) cancela sem consumir nada.
var technique_targeting_id: String = ""
var technique_targeting_unit: Unit = null
var technique_target_coords: Array[Vector2i] = []

## Aetherlands V2, Fase 13 — modo de anexação de território (HUD chama start_city_annexation ao
## clicar "Anexar território"): enquanto annexing_city != null, o PRÓXIMO clique no mundo anexa o
## tile clicado (se elegível) em vez de mover/atacar/selecionar/posicionar. Estado genérico de
## CIDADE, irmão de placing_city — nunca misturado com TargetMode de Técnica (que pertence a
## unidades, ver §49 do pedido). Diferente de start_building_placement: um clique VÁLIDO não sai
## do modo sozinho (continua enquanto houver Pontos de Anexação — §50); só ESC ou ficar sem
## pontos encerra.
var annexing_city: City = null
var annexable_coords: Array[Vector2i] = []

## Aetherlands V2, Fase 16 — mira do Ataque da Cidade (HUD chama start_city_attack_targeting). Ação da
## CIDADE, não uma Técnica de Doutrina (essas pertencem a unidades): estado próprio, irmão de
## annexing_city. Enquanto ativo, o próximo clique num alvo destacado dispara; clique inválido não
## consome nada; ESC (PauseMenu) cancela sem gastar.
const CITY_ATTACK_HINT := "Escolha o alvo do Ataque da Cidade (ESC cancela)"
var city_attack_city: City = null
var city_attack_coords: Array[Vector2i] = []

## Aetherlands V2, Fase 17 — mira de FEITIÇO V2 (V2MagicRuntime). Estado PRÓPRIO, irmão da mira de Técnica mas
## separado de propósito (feitiço custa Mana; Técnica não): o botão só entra na mira (nada gasto), os alvos
## válidos ficam verdes (OWN_UNIT) ou vermelhos (HOSTILE_UNIT), o próximo clique conjura; clique inválido
## ou ESC (PauseMenu) cancela sem gastar Mana, recarga nem ação. Mutuamente exclusivo com os outros modos.
var v2_spell_targeting_id: String = ""
var v2_spell_targeting_unit: Unit = null
var v2_spell_target_coords: Array[Vector2i] = []

func reset() -> void:
	_clear_selection()
	cancel_building_placement()
	cancel_city_annexation()
	cancel_city_attack_targeting()
	cancel_v2_spell_targeting()

## Previa do trajeto tipo Civilization: enquanto uma unidade esta
## selecionada, mostra o caminho ate o tile sob o mouse (se alcancavel) ou
## "ATACAR" (se for um alvo no alcance), com o highlight de destaque por
## cima do verde/vermelho ja existente.
func handle_world_hover(world_pos: Vector3) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		return
	if technique_targeting_id != "":
		_handle_technique_targeting_hover(world_pos)
		return
	if v2_spell_targeting_id != "":
		_handle_v2_spell_targeting_hover(world_pos)
		return
	if placing_city != null:
		_handle_building_placement_hover(world_pos)
		return
	if annexing_city != null:
		_handle_city_annexation_hover(world_pos)
		return
	if city_attack_city != null:
		_handle_city_attack_hover(world_pos)
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
	elif move_mode and hex_grid.get_unit_at(coord) == null and selected_unit.unit_data.movement_profile == UnitData.MovementProfile.GROUND:
		# Previa de "mover ate" tipo Civilization pra destino FORA do
		# alcance deste turno (pedido do usuario: "quero que apareça o
		# rastro mesmo antes de clicar, pra ver qual que é o caminho que
		# vai ser tomado até onde o mouse tá em cima"). compute_path e um
		# Dijkstra SEM teto de movimento (ver HexGrid.compute_path) — mais
		# caro que reconstruct_path acima, mas so roda quando o mouse muda
		# de TILE (ja debounced por _hovered_coord no topo desta funcao),
		# nunca por frame.
		var long_path = hex_grid.compute_path(selected_unit.coord, coord, selected_unit.owner_player, selected_unit.unit_data.flies, selected_unit.embarked)
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
	if GameManager.state == GameManager.GameState.GAME_OVER or GameManager.is_turn_processing:
		return
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if not hex_grid.tiles.has(coord):
		return

	if technique_targeting_id != "":
		_handle_technique_targeting_click(coord)
		return

	if v2_spell_targeting_id != "":
		_handle_v2_spell_targeting_click(coord)
		return

	if placing_city != null:
		_handle_building_placement_click(coord)
		return

	if annexing_city != null:
		_handle_city_annexation_click(coord)
		return

	if city_attack_city != null:
		_handle_city_attack_click(coord)
		return

	if GameManager.debug_mode and selected_unit != null and move_mode and hex_grid.get_unit_at(coord) == null:
		_debug_teleport_selected_to(coord)
	elif selected_unit != null and move_mode and reachable.has(coord):
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

## Aetherlands V2, Fase 15 — mesmo espírito de found_city_with_selected acima: a ação usa a
## unidade SELECIONADA e a posição ONDE ELA JÁ ESTÁ (§60 do pedido: nunca à distância). O
## Construtor pode ser CONSUMIDO pela própria chamada (última carga, §57) — por isso não reusa
## `selected_unit` depois de chamar improve_resource, só a cópia local `unit`.
func improve_resource_with_selected() -> void:
	if GameManager.is_turn_processing:
		return
	var unit := selected_unit
	if unit == null:
		return
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var reason := V2ConstructorRuntime.unavailable_reason(unit, hex_grid)
	if reason != "":
		EventBus.notify.emit(reason, "")
		return
	var coord := unit.coord
	V2ConstructorRuntime.improve_resource(unit, hex_grid)
	_clear_selection()
	if is_instance_valid(unit) and unit.hp > 0.0:
		hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

func found_city_with_selected() -> void:
	if GameManager.is_turn_processing:
		return
	if selected_unit == null or not selected_unit.unit_data.can_found_city:
		return
	if selected_unit.embarked: # Roadmap 2.0 Parte 1 (C2) — unidade em transito nao funda cidade
		return
	var hex_grid = GameManager.hex_grid
	var coord = selected_unit.coord
	var reason := CitySite.rejection_reason(hex_grid, coord, selected_unit.owner_player)
	if reason != "":
		if reason != CitySite.REASON_CITY:
			EventBus.notify.emit(CitySite.reason_text(reason), "")
		return

	if WorldSetup.found_city_from_settler(hex_grid, selected_unit) == null:
		return
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
	cancel_city_annexation()
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	placing_city = city
	placing_building_id = building_id
	placeable_coords.clear()
	var candidates := hex_grid.get_neighbors(city.coord)
	for owned in city.owned_tiles:
		if owned not in candidates:
			candidates.append(owned)
	for n in candidates:
		if city.is_valid_building_tile(n, hex_grid):
			placeable_coords.append(n)
	if placeable_coords.is_empty():
		cancel_building_placement()
		EventBus.notify.emit("Nenhum terreno livre para construir. Expanda a cidade ou libere um terreno ocupado.", "")
		return
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

## Aetherlands V2, Fase 13 — HUD chama isto ao clicar "Anexar território (N)" no painel da
## cidade. `city.eligible_annexation_tiles` já é bounded pelo raio territorial (nunca varre o
## mapa inteiro — §98/§99 do pedido); recalculado só aqui (ao entrar no modo), a cada anexação
## bem-sucedida e quando level/pontos mudam — nunca por frame (§100).
func start_city_annexation(city: City) -> void:
	if GameManager.is_turn_processing or city == null or city.annexation_points <= 0:
		return
	_clear_selection() # nao faz sentido mover/atacar enquanto aneza territorio
	cancel_building_placement()
	cancel_city_attack_targeting()
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	annexing_city = city
	_refresh_annexable_coords()
	if annexable_coords.is_empty():
		cancel_city_annexation()
		EventBus.notify.emit("Nenhum tile elegível para anexação agora.", "")
		return
	hex_grid.set_highlight([], [], [], annexable_coords)

## true se havia um modo de anexação ativo (mesma convenção de cancel_technique_targeting, usada
## pelo ESC em PauseMenu.gd). Sai do modo sem gastar Ponto de Anexação nem mudar território.
func cancel_city_annexation() -> bool:
	if annexing_city == null:
		return false
	annexing_city = null
	annexable_coords.clear()
	if GameManager.hex_grid:
		GameManager.hex_grid.clear_highlight()
	return true

func _refresh_annexable_coords() -> void:
	annexable_coords.clear()
	var hex_grid = GameManager.hex_grid
	if annexing_city == null or hex_grid == null:
		return
	annexable_coords = annexing_city.eligible_annexation_tiles(hex_grid)

func _handle_city_annexation_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord in annexable_coords:
		hex_grid.show_hover_label(coord, "ANEXAR", Color(0.5, 0.85, 0.4))
	else:
		hex_grid.hide_hover_label()

## Clique num tile elegível anexa e, se ainda sobrarem Pontos de Anexação, continua no modo
## (§50 do pedido: preferência por continuar enquanto o painel da cidade estiver aberto — ESC é
## quem encerra). Clique fora dos tiles elegíveis não gasta nada e não sai do modo.
func _handle_city_annexation_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var city = annexing_city
	if not coord in annexable_coords:
		return
	if not city.annex_tile(coord, hex_grid):
		return
	hex_grid.recompute_fog(city.owner_player)
	EventBus.notify.emit("%s anexou um novo tile ao território." % city.city_name, "confirm")
	EventBus.tile_selected.emit(city.coord, hex_grid.get_tile(city.coord)) # HUD atualiza Anexação: N
	if city.annexation_points > 0:
		_refresh_annexable_coords()
		hex_grid.set_highlight([], [], [], annexable_coords)
	else:
		cancel_city_annexation()
		hex_grid.show_selection_marker(city.coord)

## --- Ataque da Cidade (Fase 16) ----------------------------------------------------------------

func start_city_attack_targeting(city: City) -> void:
	if GameManager.is_turn_processing or city == null:
		return
	var hex_grid = GameManager.hex_grid
	if hex_grid == null or CityDefense.city_attack_unavailable_reason(city) != "":
		return
	_clear_selection()
	cancel_building_placement()
	cancel_city_annexation()
	city_attack_city = city
	city_attack_coords.clear()
	for target in CityDefense.city_attack_targets(city, hex_grid):
		city_attack_coords.append(target.coord)
	if city_attack_coords.is_empty():
		cancel_city_attack_targeting()
		EventBus.notify.emit("Nenhum alvo hostil visível ao alcance do Ataque da Cidade.", "")
		return
	hex_grid.set_highlight([], city_attack_coords)
	EventBus.notify.emit(CITY_ATTACK_HINT, "")

## true se havia uma mira do Ataque da Cidade ativa (mesma convenção de cancel_city_annexation, usada
## pelo ESC). Não consome o disparo nem causa dano.
func cancel_city_attack_targeting() -> bool:
	if city_attack_city == null:
		return false
	city_attack_city = null
	city_attack_coords.clear()
	if GameManager.hex_grid:
		GameManager.hex_grid.clear_highlight()
	return true

func _handle_city_attack_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord in city_attack_coords:
		hex_grid.show_hover_label(coord, "ATAQUE DA CIDADE %s" % _attack_target_name(hex_grid, coord), Color(1.0, 0.4, 0.35))
	else:
		hex_grid.hide_hover_label()

## Clique num alvo destacado dispara uma vez e encerra a mira; clique em qualquer outro tile não
## consome nada e continua mirando.
func _handle_city_attack_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var city := city_attack_city
	if not coord in city_attack_coords:
		return
	var target: Unit = hex_grid.get_unit_at(coord)
	if target == null or not CityDefense.resolve_city_defense_attack(city, target, hex_grid):
		return
	cancel_city_attack_targeting()
	EventBus.tile_selected.emit(city.coord, hex_grid.get_tile(city.coord)) # HUD mostra "Usado neste turno"

func _select_unit(unit: Unit) -> void:
	_end_technique_targeting()
	_end_v2_spell_targeting()
	selected_unit = unit
	move_mode = false
	_hovered_coord = Vector2i(999999, 999999)
	var hex_grid = GameManager.hex_grid
	reachable = hex_grid.unit_reachable(unit) # pelo PERFIL de movimento (voo tático ou o Dijkstra de sempre — igual ao de antes p/ terrestres)
	attackable.clear()
	# unit.movement_left > 0 e o que garante que uma unidade so age uma vez
	# por turno: atacar zera o movimento (CombatResolver.resolve()), entao
	# sem essa checagem aqui o alvo continuava marcado como "atacavel" e
	# clicar de novo disparava outro ataque de graca, sem fim. `not unit.
	# embarked` (Roadmap 2.0 Parte 1, C2) — unidade em transito nao ataca;
	# `attackable` ficar vazio tambem bloqueia capturar cidade de graca,
	# ja que aqui captura so acontece via CombatResolver.resolve_city_
	# attack (efeito colateral de reduzir a vida da cidade a zero atacando,
	# nao uma acao propria) — sem alvo atacavel, nao ha como capturar.
	# Fase 17: `can_basic_attack` (Clérigo/Serafim = false) é a semântica EXPLÍCITA de "esta unidade ataca"; Ataque > 0 continua valendo.
	if _accepts_manual_orders(unit) and unit.unit_data.can_basic_attack and unit.unit_data.attack > 0.0 and unit.movement_left > 0.0 and not unit.embarked:
		for n in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
			var occ_unit = hex_grid.get_unit_at(n)
			var occ_city = hex_grid.get_city_at(n)
			# Fora de guerra (Diplomacy.gd), nem unidade nem cidade contam como
			# atacaveis — ver PlayerData.is_at_war_with. Monstro neutro guardando
			# um Covil (Unit com owner_player == null, ver MonsterDatabase) e
			# hostil a TODO MUNDO, sempre — nao existe diplomacia com ele.
			if occ_unit and CombatResolver.can_attack_unit(unit, occ_unit, hex_grid):
				attackable.append(n)
			elif occ_city and CombatResolver.can_attack_city(unit, occ_city): # Fase 11: mesma regra agora também usada por Bombardeio Preparado
				attackable.append(n)
			# COVIS DE MONSTROS -- DESTRUICAO: a estrutura (sem dono, hostil a
			# todo mundo igual o guardiao que ela abrigava) so vira alvo de
			# ataque depois de genuinamente indefesa (nenhum monstro vivo na
			# area, ver HexGrid._count_live_monsters_near_lair) -- enquanto
			# defendida, occ_unit acima ja cobre o guardiao/reforco de verdade,
			# nunca a propria estrutura.
			elif occ_unit == null and occ_city == null and hex_grid.lairs_by_coord.has(n) and hex_grid._count_live_monsters_near_lair(n) == 0:
				attackable.append(n)
	hex_grid.set_highlight(reachable.keys(), attackable)
	EventBus.unit_selected.emit(unit)

func _clear_selection() -> void:
	_end_technique_targeting()
	_end_v2_spell_targeting()
	cancel_city_annexation()
	selected_unit = null
	move_mode = false
	reachable.clear()
	attackable.clear()
	_hovered_coord = Vector2i(999999, 999999)
	if GameManager.hex_grid:
		GameManager.hex_grid.clear_highlight()
	EventBus.unit_selected.emit(null)

## SO MODO DEBUG (GameManager.debug_mode) -- pedido do usuario: "eu nao
## tenho limite de andar e ao clicar num lugar com a movimentacao meu
## boneco teletransporte pra aquele lugar pra facilitar eu comparar os
## tamanhos in game". Ignora `reachable`/`attackable`/custo de movimento
## de proposito -- checado ANTES desses em handle_world_click, entao so
## roda quando o modo debug esta ligado e o tile clicado esta vazio
## (clicar um tile OCUPADO ainda cai no fluxo normal de ataque/selecao
## logo abaixo, mesmo em debug).
func _debug_teleport_selected_to(coord: Vector2i) -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	var hex_grid = GameManager.hex_grid
	var unit = selected_unit
	unit.move_order_target = Unit.NO_MOVE_ORDER
	unit.fortified = false
	unit.exploring = false
	hex_grid.teleport_unit(unit, coord)
	hex_grid.recompute_fog(GameManager.human_player)
	_select_unit(unit)

func _move_selected_to(coord: Vector2i) -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
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
	if not _accepts_manual_orders(unit):
		return false
	var hex_grid = GameManager.hex_grid
	if hex_grid.get_unit_at(coord) != null or unit.unit_data.movement_profile != UnitData.MovementProfile.GROUND:
		return false # (voo tático/infiltração, Fases 9-10: sem ordens de vários turnos — só destinos alcançáveis NESTE turno, pelo perfil da unidade)
	var path = hex_grid.compute_path(unit.coord, coord, unit.owner_player, unit.unit_data.flies, unit.embarked)
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
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
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
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	var unit = selected_unit
	if unit.embarked: # Roadmap 2.0 Parte 1 (C2) — unidade em transito nao fortifica
		return
	unit.fortified = not unit.fortified
	if unit.fortified:
		unit.exploring = false
		unit.move_order_target = Unit.NO_MOVE_ORDER
	move_mode = false
	EventBus.unit_selected.emit(unit)

## Botao de Tecnica Militar de Doutrina V2 (ex.: Muralha de Escudos, Fase 4) — usa a
## tecnica na unidade selecionada. Zero Mana/Ouro; gasta a acao da unidade (ver
## V2TechniqueRuntime.activate). Recalcula alcance/ataque (movimento agora 0) e avisa a
## HUD pelo mesmo unit_selected de qualquer outra acao.
func use_technique_selected(technique_id: String) -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	var unit = selected_unit
	if unit.owner_player != GameManager.human_player:
		return
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if technique != null and (technique.is_strike() or technique.is_relocation()):
		# Técnica de ATAQUE (Fase 7) ou de REPOSICIONAMENTO (Fase 9): sem estado guardado — resolvida pelo combate/movimento normal. Com escolha (unidade
		# ou tile) entra no modo de mira (nada é gasto ainda); "em arco" (sem mira) resolve na hora.
		if not V2TechniqueRuntime.can_use(unit, technique_id, GameManager.hex_grid):
			return
		if technique.needs_target():
			start_technique_targeting(unit, technique_id)
		else:
			_perform_technique(unit, technique_id, V2TechniqueRuntime.NO_TILE)
		return
	if V2TechniqueRuntime.activate(unit, technique_id):
		_select_unit(unit)

## Entra no modo de mira da técnica `technique_id` de `unit` (alvo = unidade ou tile, pelo `target_mode` do dado). Não gasta ação nem recarga.
func start_technique_targeting(unit: Unit, technique_id: String) -> void:
	var hex_grid: HexGrid = GameManager.hex_grid
	var technique := V2DoctrineTechniqueDatabase.get_technique(technique_id)
	if unit == null or hex_grid == null or technique == null or not technique.needs_target() or GameManager.is_turn_processing:
		return
	if not V2TechniqueRuntime.can_use(unit, technique_id, hex_grid):
		return
	cancel_building_placement()
	cancel_city_annexation()
	cancel_city_attack_targeting()
	_end_v2_spell_targeting()
	technique_targeting_id = technique_id
	technique_targeting_unit = unit
	technique_target_coords.clear()
	technique_target_coords.append_array(V2TechniqueRuntime.target_coords(unit, technique, hex_grid))
	# Só os alvos válidos ficam destacados: vermelho para uma unidade a atacar, verde para um tile de destino.
	if technique.target_mode == V2DoctrineTechniqueData.TargetMode.TILE:
		hex_grid.set_highlight(technique_target_coords, [])
	else:
		hex_grid.set_highlight([], technique_target_coords)
	EventBus.unit_selected.emit(unit) # a HUD mostra a dica "escolha o alvo (ESC cancela)"

## Cancela a mira SEM consumir ação nem recarga e restaura a seleção normal da unidade. true se havia mira.
func cancel_technique_targeting() -> bool:
	if technique_targeting_id == "":
		return false
	var unit := technique_targeting_unit
	_end_technique_targeting()
	if GameManager.hex_grid:
		GameManager.hex_grid.hide_hover_label()
	if unit != null and is_instance_valid(unit) and unit.hp > 0.0:
		_select_unit(unit)
	return true

## Só zera o estado da mira (sem tocar na seleção/realce) — usado por _select_unit/_clear_selection.
func _end_technique_targeting() -> void:
	technique_targeting_id = ""
	technique_targeting_unit = null
	technique_target_coords.clear()

func _handle_technique_targeting_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord in technique_target_coords:
		var technique := V2DoctrineTechniqueDatabase.get_technique(technique_targeting_id)
		if technique.target_mode == V2DoctrineTechniqueData.TargetMode.TILE:
			hex_grid.show_hover_label(coord, technique.display_name.to_upper(), Color(0.55, 0.85, 0.5))
		else:
			hex_grid.show_hover_label(coord, "%s: %s" % [technique.display_name.to_upper(), _attack_target_name(hex_grid, coord)], Color(1.0, 0.55, 0.3))
	else:
		hex_grid.hide_hover_label()

## Confirma no alvo clicado (um dos destacados) ou cancela a mira (qualquer outro clique) — mesmo escape hatch dos
## outros modos de mira. Cancelar não consome nada.
func _handle_technique_targeting_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var unit := technique_targeting_unit
	var technique_id := technique_targeting_id
	if not (coord in technique_target_coords):
		cancel_technique_targeting()
		return
	_end_technique_targeting()
	hex_grid.hide_hover_label()
	if unit == null or not is_instance_valid(unit) or not _perform_technique(unit, technique_id, coord):
		if unit != null and is_instance_valid(unit) and unit.hp > 0.0:
			_select_unit(unit) # o alvo deixou de ser válido: nada foi gasto
	hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

## Executa a técnica escolhida (V2TechniqueRuntime.perform_targeted: golpe ou reposicionamento) e fecha o turno da unidade como uma ação comum:
## recalcula a neblina, checa vitórias e reseleciona (ou limpa, se ela caiu no contra-ataque).
func _perform_technique(unit: Unit, technique_id: String, coord: Vector2i) -> bool:
	var hex_grid: HexGrid = GameManager.hex_grid
	if not V2TechniqueRuntime.perform_targeted(unit, technique_id, coord, hex_grid):
		return false
	hex_grid.recompute_fog(GameManager.human_player)
	GameManager.check_victories()
	if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0.0:
		_select_unit(unit)
	else:
		_clear_selection()
	return true

# --- Feitiços V2 (Fase 17) ------------------------------------------------------------------------------

## Botão de um feitiço V2 no painel da unidade selecionada: entra na mira (nada é gasto ainda).
func use_v2_spell_selected(spell_id: String) -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	if selected_unit.owner_player != GameManager.human_player:
		return
	start_v2_spell_targeting(selected_unit, spell_id)

## Entra na mira do feitiço `spell_id` de `unit`. Não gasta Mana, recarga nem ação.
func start_v2_spell_targeting(unit: Unit, spell_id: String) -> void:
	var hex_grid: HexGrid = GameManager.hex_grid
	var spell := V2SpellDatabase.get_spell(spell_id)
	if unit == null or hex_grid == null or spell == null or GameManager.is_turn_processing:
		return
	if not V2MagicRuntime.can_cast(unit, spell_id, hex_grid):
		return
	cancel_building_placement()
	cancel_city_annexation()
	cancel_city_attack_targeting()
	_end_technique_targeting()
	v2_spell_targeting_id = spell_id
	v2_spell_targeting_unit = unit
	v2_spell_target_coords.clear()
	v2_spell_target_coords.append_array(V2MagicRuntime.target_coords(unit, spell, hex_grid))
	if spell.target_mode == V2SpellData.TargetMode.HOSTILE_UNIT:
		hex_grid.set_highlight([], v2_spell_target_coords)
	elif spell.targets_tile():
		# Fase 19/20: tile (livre ou não) usa o canal AZUL utilitário (o mesmo do posicionamento de prédio) — nem vermelho de hostil
		# nem verde de unidade amiga. Estado exclusivo como os outros modos de mira.
		hex_grid.set_highlight([], [], [], v2_spell_target_coords)
	else:
		hex_grid.set_highlight(v2_spell_target_coords, [])
	EventBus.unit_selected.emit(unit) # a HUD mostra a dica "Escolha o alvo de ... (ESC cancela)"

## Cancela a mira do feitiço SEM gastar nada e restaura a seleção da unidade. true se havia mira.
func cancel_v2_spell_targeting() -> bool:
	if v2_spell_targeting_id == "":
		return false
	var unit := v2_spell_targeting_unit
	_end_v2_spell_targeting()
	if GameManager.hex_grid:
		GameManager.hex_grid.hide_hover_label()
	if unit != null and is_instance_valid(unit) and unit.hp > 0.0 and selected_unit == unit:
		_select_unit(unit)
	return true

func _end_v2_spell_targeting() -> void:
	v2_spell_targeting_id = ""
	v2_spell_targeting_unit = null
	v2_spell_target_coords.clear()

func _handle_v2_spell_targeting_hover(world_pos: Vector3) -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	var coord = HexMetrics.world_to_axial(world_pos.x, world_pos.z, hex_grid.hex_size)
	if coord in v2_spell_target_coords:
		var spell := V2SpellDatabase.get_spell(v2_spell_targeting_id)
		if spell.targets_tile():
			hex_grid.show_hover_label(coord, "%s: %s" % [spell.display_name.to_upper(), V2MagicRuntime.tile_target_label(spell, coord, hex_grid)], Color(0.4, 0.75, 1.0))
			return
		var color := Color(1.0, 0.35, 0.3) if spell.target_mode == V2SpellData.TargetMode.HOSTILE_UNIT else Color(0.55, 0.95, 0.6)
		hex_grid.show_hover_label(coord, "%s: %s" % [spell.display_name.to_upper(), _attack_target_name(hex_grid, coord)], color)
	else:
		hex_grid.hide_hover_label()

## Clique num alvo destacado conjura; qualquer outro clique cancela a mira sem gastar nada.
func _handle_v2_spell_targeting_click(coord: Vector2i) -> void:
	var hex_grid = GameManager.hex_grid
	var unit := v2_spell_targeting_unit
	var spell_id := v2_spell_targeting_id
	if not (coord in v2_spell_target_coords):
		cancel_v2_spell_targeting()
		return
	_end_v2_spell_targeting()
	hex_grid.hide_hover_label()
	if unit != null and is_instance_valid(unit) and V2MagicRuntime.cast(unit, spell_id, coord, hex_grid):
		EventBus.notify.emit("%s conjurou %s." % [unit.unit_data.unit_name, V2SpellDatabase.get_spell(spell_id).display_name], "magic")
		hex_grid.recompute_fog(GameManager.human_player) # atualiza a Mana na barra superior (a HUD ouve fog_updated)
	if unit != null and is_instance_valid(unit) and unit.hp > 0.0:
		_select_unit(unit)
	hex_grid.show_selection_marker(coord)
	EventBus.tile_selected.emit(coord, hex_grid.get_tile(coord))

## Fase 21 — ação EXPLÍCITA de travessia. Não é spellcast: Silêncio, Mana e cooldowns
## não participam. O runtime valida dono, comando, movimento, visão e landing novamente.
func traverse_selected_portal() -> void:
	if selected_unit == null or selected_unit.owner_player != GameManager.human_player or GameManager.is_turn_processing:
		return
	var unit := selected_unit
	if V2PortalSystem.traverse(unit, GameManager.hex_grid):
		GameManager.hex_grid.recompute_fog(GameManager.human_player)
		_select_unit(unit)
		GameManager.hex_grid.show_selection_marker(unit.coord)
		EventBus.tile_selected.emit(unit.coord, GameManager.hex_grid.get_tile(unit.coord))

## Botao "Evoluir para ..." (upgrade V2, Fase 4) — ver V2UnitUpgrade. Instantaneo, gasta
## o Ouro e a acao da unidade. recompute_fog atualiza o Ouro na barra superior (a HUD
## ouve fog_updated) e a visao, caso a forma nova enxergue diferente.
func upgrade_selected() -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	var unit = selected_unit
	if unit.owner_player != GameManager.human_player:
		return
	if V2UnitUpgrade.perform_upgrade(unit.owner_player, unit, GameManager.hex_grid):
		GameManager.hex_grid.recompute_fog(GameManager.human_player)
		_select_unit(unit)

## Botao "Explorar" — alterna Unit.exploring (pedido do usuario: "uma
## função que fica ativada... que se baseie em ficar andando por
## territórios que ainda não foram explorados"). Ligar cancela Fortificar
## e qualquer ordem de "mover ate" pendente, e ja anda o quanto der NESTE
## turno (reusa HexGrid.explore_step, a MESMA funcao que roda nas trocas
## de turno seguintes) — mesma UX de _try_queue_move_order, nao espera o
## proximo turno pra comecar.
func toggle_explore_selected() -> void:
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
	var unit = selected_unit
	if unit.embarked: # Roadmap 2.0 Parte 1 (C2) — unidade em transito nao explora
		return
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
	if selected_unit == null or not _accepts_manual_orders(selected_unit):
		return
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
			# Cidade indefesa NAO captura mais num unico ataque — ver
			# CombatResolver.resolve_city_attack (desconta do escudo/vida
			# da cidade, so captura quando a vida zera).
			CombatResolver.resolve_city_attack(attacker, defender_city, hex_grid)
		elif hex_grid.lairs_by_coord.has(coord):
			# COVIS DE MONSTROS -- DESTRUICAO: mesmo espirito de cidade acima —
			# reduz o HP da estrutura, so destroi/paga recompensa quando zera
			# (ver CombatResolver.resolve_lair_attack).
			CombatResolver.resolve_lair_attack(attacker, coord, hex_grid)

	hex_grid.recompute_fog(GameManager.human_player)
	GameManager.check_victories()

	if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
		_select_unit(attacker)
	else:
		_clear_selection()

func _accepts_manual_orders(unit: Unit) -> bool:
	# Fase 19: Unit.can_receive_orders (retinue sem comando = false; caminho rápido true para o resto) — o gate real
	# também está em HexGrid.move_unit / CombatResolver; aqui só evita oferecer a ordem.
	return not GameManager.is_turn_processing and unit.can_receive_orders()

## Fase 19 — botão "Dissolver Hoste": remove a retinue SELECIONADA do humano (V2RetinueSystem.dissolve: sem abate,
## XP, saque nem Mana; a capacidade volta por derivação). Vale MESMO sem comando — é justamente o jeito de liberar
## capacidade num overload —, por isso não passa por _accepts_manual_orders.
func dissolve_selected_retinue() -> void:
	var unit := selected_unit
	if unit == null or not is_instance_valid(unit) or GameManager.is_turn_processing:
		return
	if unit.owner_player != GameManager.human_player or not V2RetinueSystem.is_retinue_unit(unit):
		return
	var unit_name := unit.unit_data.unit_name
	if not V2RetinueSystem.dissolve(unit, GameManager.hex_grid):
		return
	_clear_selection()
	EventBus.notify.emit("%s dissolvida." % unit_name, "")
	GameManager.hex_grid.recompute_fog(GameManager.human_player)
