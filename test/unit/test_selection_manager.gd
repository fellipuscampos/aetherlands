extends GutTest

## Regressao do bug relatado pelo usuario: atacar uma unidade inimiga e
## continuar podendo clicar nela pra atacar de novo, sem fim, no mesmo
## turno. Causa: _select_unit() recalculava "attackable" so olhando o
## alcance da unidade, sem checar se ela ainda tinha movimento/acao
## disponivel — depois de atacar (que zera movement_left), o mesmo alvo
## continuava marcado como atacavel.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_turn_number: int

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_turn_number = TurnManager.turn_number
	_created_units = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival) # attackable agora exige guerra (Diplomacy.gd)
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	TurnManager.turn_number = _original_turn_number
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_attacking_removes_target_from_attackable_afterwards():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, defender_coord)

	SelectionManager._select_unit(attacker)
	assert_true(defender_coord in SelectionManager.attackable, "alvo deveria estar atacavel antes do primeiro ataque")

	SelectionManager._attack_from_selected(defender_coord)

	assert_eq(attacker.movement_left, 0.0, "atacar deveria zerar o movimento")
	assert_false(defender_coord in SelectionManager.attackable, "alvo nao deveria continuar atacavel depois que a unidade ja agiu")

func test_unit_with_zero_movement_has_no_attackable_tiles_on_reselect():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	_make_unit("warrior", rival, Vector2i(1, 0))
	attacker.movement_left = 0.0

	SelectionManager._select_unit(attacker)

	assert_eq(SelectionManager.attackable.size(), 0, "unidade sem movimento/acao restante nao deveria ter nenhum alvo atacavel")

## Diplomacia (Diplomacy.gd): unidade/cidade de um jogador em paz nao
## deveria nunca aparecer como atacavel, mesmo dentro do alcance.
func test_peaceful_units_and_cities_are_never_attackable():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var enemy_unit_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, enemy_unit_coord)
	var third = PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, third)
	var enemy_city_coord = Vector2i(-1, 0)
	var city = hex_grid.found_city(enemy_city_coord, third, "Cidade C")

	Diplomacy.propose_peace(human, rival) # 1 unidade cada lado, empate aceita a paz

	SelectionManager._select_unit(attacker)

	assert_false(enemy_unit_coord in SelectionManager.attackable, "unidade de um jogador em paz nao deveria ser atacavel")
	assert_true(enemy_city_coord in SelectionManager.attackable, "cidade de um jogador AINDA em guerra deveria continuar atacavel")

## Guardiao de Covil de Monstro (owner_player == null, ver MonsterDatabase)
## nao tem diplomacia — e hostil a todo mundo sempre, mesmo sem nenhuma
## guerra declarada contra ele (nao ha "ele" pra declarar guerra contra).
func test_neutral_monster_is_always_attackable_without_any_diplomacy():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var monster_coord = Vector2i(1, 0)
	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("goblin"), null, monster_coord)
	hex_grid.units_by_coord[monster_coord] = monster
	_created_units.append(monster)

	SelectionManager._select_unit(attacker)

	assert_true(monster_coord in SelectionManager.attackable, "guardiao neutro deveria estar sempre atacavel")

## Nome do alvo no hover "ATACAR X" (SelectionManager.handle_world_hover)
## — sem isso o jogador so descobre o que esta guardando um Covil de
## Monstro DEPOIS de atacar as cegas.
func test_attack_target_name_returns_unit_name():
	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("troll"), null, Vector2i(1, 0))
	hex_grid.units_by_coord[Vector2i(1, 0)] = monster
	_created_units.append(monster)

	assert_eq(SelectionManager._attack_target_name(hex_grid, Vector2i(1, 0)), "Troll")

func test_attack_target_name_returns_city_name():
	var city = hex_grid.found_city(Vector2i(-1, 0), rival, "Forte Rival")

	assert_eq(SelectionManager._attack_target_name(hex_grid, Vector2i(-1, 0)), "Forte Rival")

## Regressao/relato de bug do usuario: "o caminho até uma célula tá sempre
## ligado mesmo sem eu clicar no mover, e clicando de volta isso não sai,
## fica assim pra sempre" — clicar-pra-mover (e a previa de trajeto no
## hover) precisam ficar DESLIGADOS ate o jogador clicar "Mover"
## (SelectionManager.wake_selected_for_move -> move_mode = true),
## nao ativos direto so por selecionar a unidade.

func test_clicking_a_reachable_tile_does_nothing_without_move_mode_armed():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(1, 0, hex_grid.hex_size))

	assert_eq(warrior.coord, Vector2i(0, 0), "sem apertar Mover antes, clicar no mapa nao deveria mover a unidade")

func test_wake_selected_for_move_arms_move_mode():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)
	assert_false(SelectionManager.move_mode, "pre-condicao: move_mode comeca desligado numa selecao nova")

	SelectionManager.wake_selected_for_move()

	assert_true(SelectionManager.move_mode)

func test_clicking_a_reachable_tile_moves_once_move_mode_is_armed():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)
	SelectionManager.wake_selected_for_move()

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(1, 0, hex_grid.hex_size))

	assert_eq(warrior.coord, Vector2i(1, 0), "com Mover armado, o clique deveria mover a unidade normalmente")

func test_selecting_a_new_unit_resets_move_mode():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	var other = _make_unit("warrior", human, Vector2i(1, 0))
	SelectionManager._select_unit(warrior)
	SelectionManager.wake_selected_for_move()
	assert_true(SelectionManager.move_mode)

	SelectionManager._select_unit(other)

	assert_false(SelectionManager.move_mode, "trocar de selecao deveria desarmar Mover de novo")

func test_fortify_selected_disarms_move_mode():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)
	SelectionManager.wake_selected_for_move()

	SelectionManager.fortify_selected()

	assert_false(SelectionManager.move_mode, "fortificar deveria desarmar Mover")

func test_toggle_explore_selected_disarms_move_mode():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)
	SelectionManager.wake_selected_for_move()

	SelectionManager.toggle_explore_selected()

	assert_false(SelectionManager.move_mode, "explorar deveria desarmar Mover")

## Atacar continua sempre disponivel independente de move_mode — e uma
## acao SEPARADA de Mover, nao deveria exigir apertar "Mover" antes.
func test_attacking_works_without_move_mode_armed():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, defender_coord)
	SelectionManager._select_unit(attacker)
	assert_false(SelectionManager.move_mode, "pre-condicao: move_mode comeca desligado")

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(defender_coord.x, defender_coord.y, hex_grid.hex_size))

	assert_eq(attacker.movement_left, 0.0, "atacar deveria funcionar mesmo sem Mover armado")

## "Mover ate" tipo Civilization (pedido do usuario: "no civilization eu
## posso colocar pra ela se mover pra um lugar longe... o movimento fica
## gravado e todo turno essa tropa vai se movendo") — clicar um tile fora
## do alcance do turno atual (mas com caminho de verdade ate la) deveria
## mover o quanto der JA e guardar o resto como ordem pendente (Unit.
## move_order_target), ver HexGrid.compute_path/continue_move_order.

func test_clicking_a_far_tile_queues_a_move_order_and_moves_partially():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(4, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0)) # 2 de movimento, destino a 4 tiles
	SelectionManager._select_unit(warrior)
	SelectionManager.move_mode = true # botao "Mover" precisa ser clicado antes do mapa aceitar mover (pedido do usuario, relato de bug)

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(4, 0, hex_grid.hex_size))

	assert_eq(warrior.coord, Vector2i(2, 0), "deveria ter andado o quanto o movimento do turno permitiu")
	assert_eq(warrior.move_order_target, Vector2i(4, 0), "resto do caminho deveria ficar como ordem pendente")

func test_clicking_a_tile_with_a_unit_does_not_queue_a_move_order():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	var other = _make_unit("warrior", human, Vector2i(3, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(3, 0, hex_grid.hex_size))

	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "clicar um tile ocupado deveria tentar SELECIONAR a unidade la, nao virar ordem de movimento")
	assert_eq(SelectionManager.selected_unit, other, "deveria ter trocado a selecao pra unidade clicada")

func test_manually_moving_a_unit_cancels_its_pending_move_order():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.move_order_target = Vector2i(2, 0) # ordem pendente antiga (ex: de um turno anterior)
	SelectionManager._select_unit(warrior)
	SelectionManager.move_mode = true

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(1, 0, hex_grid.hex_size)) # comando manual pra outro destino

	assert_eq(warrior.coord, Vector2i(1, 0))
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "comando manual deveria cancelar a ordem antiga")

func test_attacking_cancels_a_pending_move_order():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	attacker.move_order_target = Vector2i(3, 0) # ordem pendente qualquer
	var defender_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, defender_coord)
	SelectionManager._select_unit(attacker)

	SelectionManager._attack_from_selected(defender_coord)

	assert_eq(attacker.move_order_target, Unit.NO_MOVE_ORDER, "atacar deveria cancelar qualquer ordem de movimento pendente")

## Fortificar/Explorar (pedido do usuario: "as opções... mover,
## fortificar e explorar"), ver SelectionManager.fortify_selected/
## toggle_explore_selected/wake_selected_for_move.

func test_fortify_selected_toggles_the_flag():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.fortify_selected()
	assert_true(warrior.fortified)

	SelectionManager.fortify_selected()
	assert_false(warrior.fortified, "clicar Fortificar de novo deveria desligar")

func test_fortify_selected_cancels_exploring():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.exploring = true
	SelectionManager._select_unit(warrior)

	SelectionManager.fortify_selected()

	assert_true(warrior.fortified)
	assert_false(warrior.exploring, "fortificar deveria desligar explorar")

## Regressao/relato de bug do usuario: "se ele tiver movendo e eu ativar
## o fortificar ele não para, eu quero que ele pare... ao ativar o estado
## de fortificado ele deve cancelar as outras ações" — fortificar so
## cancelava Explorar, deixando uma ordem de "mover ate" (Unit.
## move_order_target) livre pra continuar no proximo turno por cima do
## Fortificar.
func test_fortify_selected_cancels_a_pending_move_order():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.move_order_target = Vector2i(5, 0) # ordem de "mover ate" em andamento
	SelectionManager._select_unit(warrior)

	SelectionManager.fortify_selected()

	assert_true(warrior.fortified)
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "fortificar deveria cancelar a ordem de movimento em andamento, nao so Explorar")

func test_toggle_explore_selected_moves_toward_nearest_unseen_tile():
	hex_grid.visibility[Vector2i(0, 0)] = HexGrid.Visibility.VISIBLE
	for dir in HexGrid.NEIGHBOR_DIRS:
		if dir != Vector2i(1, 0):
			hex_grid.visibility[dir] = HexGrid.Visibility.VISIBLE
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_explore_selected()

	assert_true(warrior.exploring)
	assert_eq(warrior.coord, Vector2i(1, 0), "deveria ja ter andado na direcao do UNICO tile UNSEEN por perto, no mesmo clique")

func test_toggle_explore_selected_off_again_stops_without_moving():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.exploring = true
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_explore_selected()

	assert_false(warrior.exploring)
	assert_eq(warrior.coord, Vector2i(0, 0), "desligar Explorar nao deveria mover a unidade")

func test_toggle_explore_selected_cancels_fortified_and_pending_move_order():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.fortified = true
	warrior.move_order_target = Vector2i(5, 0)
	SelectionManager._select_unit(warrior)

	SelectionManager.toggle_explore_selected()

	assert_true(warrior.exploring)
	assert_false(warrior.fortified)
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER)

func test_wake_selected_for_move_clears_all_pending_orders():
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.fortified = true
	SelectionManager._select_unit(warrior)

	SelectionManager.wake_selected_for_move()

	assert_false(warrior.fortified)
	assert_false(warrior.exploring)
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER)
	assert_eq(warrior.coord, Vector2i(0, 0), "acordar pra mover nao deveria mover a unidade sozinho")

func test_manually_moving_cancels_fortified_and_exploring():
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var warrior = _make_unit("warrior", human, Vector2i(0, 0))
	warrior.fortified = true
	SelectionManager._select_unit(warrior)
	SelectionManager.move_mode = true

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(1, 0, hex_grid.hex_size))

	assert_false(warrior.fortified, "mover manualmente deveria cancelar Fortificar")

func test_attacking_cancels_fortified_and_exploring():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	attacker.fortified = true
	var defender_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, defender_coord)
	SelectionManager._select_unit(attacker)

	SelectionManager._attack_from_selected(defender_coord)

	assert_false(attacker.fortified, "atacar deveria cancelar Fortificar")

## Posicionamento de predio (SelectionManager.start_building_placement):
## o jogador escolhe o tile no mapa, do mesmo jeito que fundar uma cidade.

func test_start_building_placement_lists_only_valid_neighbor_tiles():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var occupied = HexGrid.NEIGHBOR_DIRS[0]
	_make_unit("warrior", human, occupied) # um vizinho ocupado, nao deveria entrar na lista

	SelectionManager.start_building_placement(city, "granary")

	assert_false(occupied in SelectionManager.placeable_coords, "vizinho ocupado por unidade nao deveria ser um destino valido")
	assert_eq(SelectionManager.placeable_coords.size(), HexGrid.NEIGHBOR_DIRS.size() - 1)

func test_clicking_a_valid_tile_confirms_building_placement():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	var target = HexGrid.NEIGHBOR_DIRS[0]
	SelectionManager.start_building_placement(city, "granary")

	SelectionManager.handle_world_click(HexMetrics.axial_to_world(target.x, target.y, hex_grid.hex_size))

	assert_eq(city.production_item, "granary")
	assert_eq(city.pending_building_coord, target)
	assert_null(SelectionManager.placing_city, "modo de posicionamento deveria encerrar apos confirmar")

func test_clicking_an_invalid_tile_cancels_building_placement():
	var city = hex_grid.found_city(Vector2i(0, 0), human, "Capital")
	SelectionManager.start_building_placement(city, "granary")

	# Vector2i(0,0) e a propria cidade — nunca esta em placeable_coords
	# (so vizinhos entram), entao clicar nela deveria cancelar.
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(0, 0, hex_grid.hex_size))

	assert_eq(city.production_item, "settler", "producao nao deveria ter mudado quando o posicionamento e cancelado")
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	assert_null(SelectionManager.placing_city)

## Mira de feitico (SelectionManager.start_spell_targeting/Grimorio da
## HUD): "Lança de Arcana" (enemy_unit_in_vision) so aceita unidade
## inimiga/monstro ATUALMENTE VISIVEL, "Reanimar" (friendly_unit) so
## aceita unidade do proprio jogador.

func test_valid_spell_target_accepts_a_visible_enemy_for_enemy_unit_in_vision():
	human.researched_techs["invocacao_espiritos"] = true
	var enemy_coord = Vector2i(1, 0)
	var enemy = _make_unit("warrior", rival, enemy_coord)
	_make_unit("warrior", human, Vector2i(0, 0)) # vision vem das PROPRIAS unidades/cidades (HexGrid.compute_visible_tiles) — sem uma aqui perto, nada fica visivel
	hex_grid.recompute_fog(human) # sem isso nenhum tile fica VISIBLE, ver HexGrid.compute_visible_tiles

	var target = SelectionManager._valid_spell_target(hex_grid, "Lança de Arcana", enemy_coord)

	assert_eq(target, enemy)

func test_valid_spell_target_rejects_own_unit_for_enemy_unit_in_vision():
	human.researched_techs["invocacao_espiritos"] = true
	var own_coord = Vector2i(0, 0)
	_make_unit("warrior", human, own_coord)
	hex_grid.recompute_fog(human)

	assert_null(SelectionManager._valid_spell_target(hex_grid, "Lança de Arcana", own_coord))

## Regressao: sem recompute_fog nenhum, nenhum tile esta VISIBLE ainda —
## um inimigo tecnicamente no mapa mas nunca "visto" nao deveria ser
## mirável, mesma regra que ja vale pra ataque normal (so alcance nao
## basta, ver requisito "em alcance de visão" do pedido original).
func test_valid_spell_target_rejects_enemy_not_currently_visible():
	var enemy_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, enemy_coord)

	assert_null(SelectionManager._valid_spell_target(hex_grid, "Lança de Arcana", enemy_coord))

func test_valid_spell_target_accepts_own_unit_for_friendly_unit():
	var own_coord = Vector2i(0, 0)
	var ally = _make_unit("warrior", human, own_coord)

	assert_eq(SelectionManager._valid_spell_target(hex_grid, "Reanimar", own_coord), ally)

func test_valid_spell_target_rejects_enemy_for_friendly_unit():
	var enemy_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, enemy_coord)

	assert_null(SelectionManager._valid_spell_target(hex_grid, "Reanimar", enemy_coord))

func test_valid_spell_target_returns_null_for_spell_without_spelldata():
	var enemy_coord = Vector2i(1, 0)
	_make_unit("warrior", rival, enemy_coord)
	hex_grid.recompute_fog(human)

	assert_null(SelectionManager._valid_spell_target(hex_grid, "Ruína Ígnea", enemy_coord))

func test_clicking_a_valid_target_casts_the_spell_and_clears_targeting_mode():
	human.researched_techs["invocacao_espiritos"] = true
	human.mana = 100.0 # Lança de Arcana custa 25 (ver SpellDatabase)
	var enemy_coord = Vector2i(1, 0)
	var enemy = _make_unit("warrior", rival, enemy_coord)
	_make_unit("warrior", human, Vector2i(0, 0)) # vision vem das PROPRIAS unidades/cidades
	hex_grid.recompute_fog(human)
	TurnManager.turn_number = 1

	SelectionManager.start_spell_targeting("Lança de Arcana")
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(enemy_coord.x, enemy_coord.y, hex_grid.hex_size))

	assert_almost_eq(enemy.hp, enemy.unit_data.max_hp - 6.0, 0.01, "clicar o alvo deveria ter aplicado o dano do feitico")
	assert_eq(SelectionManager.casting_spell_name, "", "modo de mira deveria encerrar apos o clique, alvo valido ou nao")

func test_clicking_an_invalid_target_cancels_spell_targeting_without_casting():
	human.researched_techs["invocacao_espiritos"] = true
	SelectionManager.start_spell_targeting("Lança de Arcana")

	# (0,0) esta vazio nesse fixture — nenhuma unidade la, alvo invalido.
	SelectionManager.handle_world_click(HexMetrics.axial_to_world(0, 0, hex_grid.hex_size))

	assert_eq(SelectionManager.casting_spell_name, "", "clique invalido deveria cancelar a mira mesmo sem conjurar nada")
