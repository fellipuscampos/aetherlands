extends GutTest

## Cobre DragonEvent: skeleton generico (FSM/persistencia/determinismo,
## Step 5A), Blocker #1 (identidade/origem/spawn, Step 5B.1), Announced/
## Preparation reais (Step 5B.2), e agora nascimento/presenca fisica real
## do Dragao como Unit (Step 5B.3-A, docs/DRAGON_EVENT_DESIGN.md) --
## spawn_coord deterministico, ownership neutro, remocao ao terminar.
## Movimento/combate/proximo alvo (5B.3-B) e desfecho de verdade (5B.4)
## continuam fora de escopo. Trigger/spawn de REGIAO (WorldEventTrigger)
## tem seu proprio arquivo de teste; participacao (RivalAI/GameManager)
## tambem tem os seus.

## Spy SO de teste -- conta chamadas a advance_turn() enquanto ainda se
## comporta como um DragonEvent de verdade (chama super()). Existe so pra
## provar que from_save_dict() NUNCA aciona advance_turn() como efeito
## colateral -- protege a CAUSA (a chamada em si nunca aconteceu), nao so
## o EFEITO (a fase por acaso ficou igual).
class _DragonEventAdvanceSpy extends DragonEvent:
	var advance_calls: int = 0
	func advance_turn(hex_grid: HexGrid, players: Array[PlayerData]) -> void:
		advance_calls += 1
		super.advance_turn(hex_grid, players)

var _original_turn_number: int
var _created_cities: Array[City] = []
var _created_hex_grids: Array[HexGrid] = []

func before_each():
	_original_turn_number = TurnManager.turn_number
	_created_cities = []
	_created_hex_grids = []

func after_each():
	TurnManager.turn_number = _original_turn_number
	for city in _created_cities:
		if is_instance_valid(city):
			city.queue_free()
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()

func _make_city(coord: Vector2i) -> City:
	var city := City.new()
	city.coord = coord
	_created_cities.append(city)
	return city

## Grid pequeno, todo GRASSLAND (nunca bloqueia unidade terrestre) -- valido
## como tile de spawn em qualquer coordenada dele por padrao, a menos que
## um teste especifico ocupe/bloqueie um tile de proposito.
func _make_hex_grid(radius: int = 3) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			grid.tiles[Vector2i(x, y)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_created_hex_grids.append(grid)
	return grid

func test_new_dragon_event_has_event_type_dragon():
	var event := DragonEvent.new()
	assert_eq(event.event_type, DragonEvent.EVENT_TYPE)
	assert_eq(event.event_type, "dragon")

func test_new_dragon_event_starts_dormant_with_no_region_spawn_or_target():
	var event := DragonEvent.new()
	assert_eq(event.phase, WorldEvent.PHASE_DORMANT)
	assert_eq(event.origin_region, DragonEvent.NO_COORD)
	assert_eq(event.spawn_coord, DragonEvent.NO_COORD, "tile exato so deveria existir a partir da transicao pra Active (Blocker #3/5B.3, ainda nao implementado)")
	assert_eq(event.target_civ_index, -1)

## --- FSM: Announced/Preparation reais, Active/Resolution ainda skeleton ----

func test_advance_turn_moves_dormant_to_announced_immediately():
	var event := DragonEvent.new()
	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_ANNOUNCED)

## A transicao Announced->Preparation e' onde o alvo trava e o prazo
## (turn_deadline) e' fixado (docs/DRAGON_EVENT_DESIGN.md, Blocker #2/#3).
func test_advance_turn_locks_target_and_deadline_on_announced_to_preparation():
	TurnManager.turn_number = 10
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var player := PlayerData.new(CivilizationData.new())
	player.cities.append(_make_city(Vector2i(1, 0)))
	var players: Array[PlayerData] = [player]

	event.advance_turn(null, players) # Dormant -> Announced
	event.advance_turn(null, players) # Announced -> Preparation

	assert_eq(event.phase, WorldEvent.PHASE_PREPARATION)
	assert_eq(event.target_civ_index, 0)
	assert_eq(event.turn_deadline, 10 + DragonEvent.PREPARATION_DURATION_TURNS)

## Formula PROVISORIA (Blocker #3 continua aberto): civ com a cidade mais
## proxima da regiao de origem.
func test_target_is_the_civ_with_the_nearest_city_to_the_origin_region():
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var near_player := PlayerData.new(CivilizationData.new())
	near_player.cities.append(_make_city(Vector2i(2, 0)))
	var far_player := PlayerData.new(CivilizationData.new())
	far_player.cities.append(_make_city(Vector2i(10, 0)))
	var players: Array[PlayerData] = [far_player, near_player] # ordem de proposito diferente do "mais perto"

	event.advance_turn(null, players) # -> Announced
	event.advance_turn(null, players) # -> Preparation, trava alvo

	assert_eq(event.target_civ_index, 1, "civ_index 1 (near_player) tem a cidade mais proxima, mesmo estando depois na lista")

func test_target_stays_minus_one_when_no_player_has_any_city():
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var players: Array[PlayerData] = [PlayerData.new(CivilizationData.new())]

	event.advance_turn(null, players)
	event.advance_turn(null, players)

	assert_eq(event.target_civ_index, -1, "sem cidade nenhuma no mapa, nao ha alvo pra travar -- nao deveria travar em 0 por acidente")

## Regra exata do Blocker #2: turn_deadline e' o ULTIMO turno em que uma
## decisao ainda pode acontecer -- Preparation so vira Active no
## PROCESSAMENTO do turno seguinte ao prazo, nunca no proprio turno do
## prazo.
func test_preparation_only_advances_to_active_the_turn_after_the_deadline():
	TurnManager.turn_number = 10
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var players: Array[PlayerData] = []
	event.advance_turn(grid, players) # -> Announced
	event.advance_turn(grid, players) # -> Preparation, deadline = 13

	for turn in range(11, DragonEvent.PREPARATION_DURATION_TURNS + 11):
		TurnManager.turn_number = turn
		event.advance_turn(grid, players)
		assert_eq(event.phase, WorldEvent.PHASE_PREPARATION, "turno %d ainda deveria estar dentro do prazo (deadline=%d)" % [turn, event.turn_deadline])

	TurnManager.turn_number = event.turn_deadline + 1
	event.advance_turn(grid, players)
	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE)

## Active/Resolution continuam avancando uma fase por chamada (5B.3-B
## substituiu o CONTEUDO dessas fases -- movimento/combate/raid reais --
## nunca a arquitetura ao redor). Sem hex_grid/dragon_unit real aqui de
## proposito -- dragon_unit == null e' tratado por _take_dragon_turn como
## "ja morreu/nunca chegou a existir" (mesmo caminho de "defeated" usado
## quando uma unidade mata o Dragao fora do proprio tick, ver secao 5B.3-B
## abaixo) -- so confirma a transicao de fase em si; o nascimento/remocao
## de verdade da Unit tem sua propria secao de testes abaixo.
func test_active_and_resolution_still_advance_one_phase_per_call():
	TurnManager.turn_number = 10
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE

	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)
	assert_eq(event.result, {"outcome": "defeated"}, "dragon_unit nulo e' tratado como 'ja nao esta mais aqui', mesmo caminho de uma morte em combate fora do tick")

	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)

func test_advance_turn_does_nothing_once_completed():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_COMPLETED
	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)
	assert_true(event.is_completed())

## --- 5B.3-A: nascimento e presenca fisica do Dragao -------------------------

## Chega ate o exato instante em que Preparation vira Active, sem passar
## por ele -- pra isolar o teste no momento do spawn.
func _advance_to_active(event: DragonEvent, grid: HexGrid, players: Array[PlayerData]) -> void:
	TurnManager.turn_number = 10
	event.advance_turn(grid, players) # -> Announced
	event.advance_turn(grid, players) # -> Preparation, deadline = 13
	TurnManager.turn_number = event.turn_deadline + 1
	event.advance_turn(grid, players) # -> Active, spawna a Unit

func test_preparation_to_active_spawns_a_real_unit_at_a_valid_tile():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)

	_advance_to_active(event, grid, [])

	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE)
	assert_eq(event.spawn_coord, Vector2i(0, 0), "origin_region ja e' valido, deveria nascer exatamente ali")
	assert_not_null(event.dragon_unit)
	assert_eq(grid.get_unit_at(event.spawn_coord), event.dragon_unit)

## Ownership neutro (contrato: "nao pertence a nenhuma civilizacao") --
## HexGrid.spawn_monster_at ja garante isso, este teste protege contra
## regressao se alguem trocar spawn_monster_at por spawn_unit por engano.
func test_spawned_dragon_unit_belongs_to_no_civilization():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)

	_advance_to_active(event, grid, [])

	assert_null(event.dragon_unit.owner_player)

func test_spawned_dragon_unit_uses_the_shared_monster_database_stats():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)

	_advance_to_active(event, grid, [])

	var expected := MonsterDatabase.create_monster("dragon", false)
	assert_eq(event.dragon_unit.unit_data.attack, expected.attack)
	assert_eq(event.dragon_unit.unit_data.defense, expected.defense)
	assert_eq(event.dragon_unit.hp, expected.max_hp)

## O requisito mais importante desta secao: nascer/existir/remover o
## Dragao NUNCA deveria alterar player.units nem qualquer colecao de
## civilizacao -- ele nao e' "a unidade do jogador 0" por acidente.
func test_spawning_the_dragon_never_touches_any_players_units():
	var grid := _make_hex_grid()
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	var human_units_before := human.units.duplicate()
	var rival_units_before := rival.units.duplicate()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)

	_advance_to_active(event, grid, [human, rival])

	assert_eq(human.units, human_units_before)
	assert_eq(rival.units, rival_units_before)

func test_choose_spawn_coord_prefers_origin_region_when_valid():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(1, 1)
	assert_eq(event._choose_spawn_coord(grid), Vector2i(1, 1))

## Regiao ocupada por outra Unit -- deveria expandir pra um vizinho valido
## em vez de nascer em cima de uma unidade ja existente.
func test_choose_spawn_coord_avoids_a_tile_already_occupied_by_a_unit():
	var grid := _make_hex_grid()
	var origin := Vector2i(0, 0)
	grid.spawn_monster_at(origin, "goblin")

	var event := DragonEvent.new()
	event.origin_region = origin
	var chosen := event._choose_spawn_coord(grid)

	assert_ne(chosen, origin, "tile ja ocupado, deveria ter escolhido outro")
	assert_null(grid.get_unit_at(chosen), "pre-condicao do teste: o tile escolhido precisa estar livre de verdade")

## Regiao bloqueada por terreno (ex.: oceano) -- deveria expandir em aneis
## ate achar um tile de terra firme valido.
func test_choose_spawn_coord_expands_past_terrain_that_blocks_land_units():
	var grid := _make_hex_grid()
	var origin := Vector2i(0, 0)
	grid.tiles[origin] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

	var event := DragonEvent.new()
	event.origin_region = origin
	var chosen := event._choose_spawn_coord(grid)

	assert_ne(chosen, origin)
	var data: HexTileData = grid.get_tile(chosen)
	assert_false(data.blocks_land_units(), "o tile escolhido precisa ser valido pra unidade terrestre")

func test_choose_spawn_coord_is_deterministic_for_the_same_grid():
	var grid := _make_hex_grid()
	var origin := Vector2i(0, 0)
	grid.tiles[origin] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var event := DragonEvent.new()
	event.origin_region = origin

	assert_eq(event._choose_spawn_coord(grid), event._choose_spawn_coord(grid))

## Active -> Resolution -> Completed precisa remover a Unit do mapa
## (contrato: "remover a Unit quando o evento termina").
func test_resolution_removes_the_dragon_unit_from_the_map():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [])
	var spawn_coord := event.spawn_coord
	assert_not_null(grid.get_unit_at(spawn_coord), "pre-condicao: a Unit deveria existir em Active")

	event.advance_turn(grid, []) # Active -> Resolution
	event.advance_turn(grid, []) # Resolution -> Completed, remove a Unit

	assert_null(grid.get_unit_at(spawn_coord), "a Unit deveria ter sido removida do mapa")
	assert_null(event.dragon_unit)

## --- Re-link pos save/load (SaveManager.relink_unit) ------------------------

func test_relink_unit_finds_the_unit_the_generic_neutral_save_already_restored():
	var grid := _make_hex_grid()
	var spawn_coord := Vector2i(2, 2)
	var restored_unit := grid.spawn_monster_at(spawn_coord, "dragon") # simula o que _deserialize_neutral_units ja fez antes de relink_unit rodar
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.spawn_coord = spawn_coord
	event.dragon_unit = null # como viria de from_save_dict -- nunca serializado

	event.relink_unit(grid)

	assert_eq(event.dragon_unit, restored_unit)

func test_relink_unit_is_a_safe_no_op_before_the_dragon_ever_spawned():
	var grid := _make_hex_grid()
	var event := DragonEvent.new() # spawn_coord ainda e' NO_COORD (Dormant/Announced/Preparation)

	event.relink_unit(grid)

	assert_null(event.dragon_unit)

## --- Notificacoes (texto minimo, ver docs/DRAGON_EVENT_DESIGN.md) ----------

func test_announced_transition_emits_a_notification():
	var event := DragonEvent.new()
	watch_signals(EventBus)
	event.advance_turn(null, [])
	assert_signal_emitted(EventBus, "notify")

func test_preparation_transition_emits_a_notification_naming_the_target():
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = "Reino de Teste"
	player.cities.append(_make_city(Vector2i(1, 0)))
	var players: Array[PlayerData] = [player]

	event.advance_turn(null, players) # -> Announced
	watch_signals(EventBus)
	event.advance_turn(null, players) # -> Preparation

	assert_signal_emitted(EventBus, "notify")
	var params = get_signal_parameters(EventBus, "notify", 0)
	assert_true(("Reino de Teste" in params[0]), "a notificacao deveria nomear a civilizacao-alvo")

func test_preparation_to_active_transition_emits_a_notification():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	TurnManager.turn_number = 10
	event.advance_turn(grid, []) # -> Announced
	event.advance_turn(grid, []) # -> Preparation
	TurnManager.turn_number = event.turn_deadline + 1

	watch_signals(EventBus)
	event.advance_turn(grid, []) # -> Active, nasce a Unit

	assert_signal_emitted(EventBus, "notify")

## --- Persistencia (contrato, secao 3) ---------------------------------------

func test_to_save_dict_and_from_save_dict_round_trip_region_spawn_and_target():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.origin_region = Vector2i(7, -3)
	event.spawn_coord = Vector2i(8, -2)
	event.target_civ_index = 2

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.phase, WorldEvent.PHASE_ACTIVE)
	assert_eq(loaded.origin_region, Vector2i(7, -3))
	assert_eq(loaded.spawn_coord, Vector2i(8, -2))
	assert_eq(loaded.target_civ_index, 2)

func test_from_save_dict_defaults_region_spawn_and_target_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({}) # simula um dict incompleto/de outro tipo de evento
	assert_eq(event.origin_region, DragonEvent.NO_COORD)
	assert_eq(event.spawn_coord, DragonEvent.NO_COORD)
	assert_eq(event.target_civ_index, -1)

## O requisito mais importante deste arquivo: from_save_dict() nunca deveria
## acionar advance_turn(), nem uma vez -- ver contrato, "Persistencia" e a
## regra temporal ("nenhuma chamada de... save/load... pode avancar um
## evento").
func test_from_save_dict_never_triggers_advance_turn_as_a_side_effect():
	var spy := _DragonEventAdvanceSpy.new()
	spy.phase = WorldEvent.PHASE_ACTIVE
	spy.origin_region = Vector2i(1, 1)
	var saved := spy.to_save_dict()

	var loaded := _DragonEventAdvanceSpy.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.advance_calls, 0, "from_save_dict() nao deveria acionar advance_turn() nenhuma vez -- protege a causa, nao so o efeito (fase)")
	assert_eq(loaded.phase, WorldEvent.PHASE_ACTIVE, "efeito tambem confirmado: fase preservada exatamente")

## --- Reconstrucao polimorfica via WorldEventManager -------------------------

func test_world_event_manager_reconstructs_a_dragon_event_from_save_dict():
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0

	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	event.origin_region = Vector2i(2, 9)
	event.target_civ_index = 1
	WorldEventManager.register_event(event)

	var saved := WorldEventManager.to_save_dict()
	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0
	WorldEventManager.from_save_dict(saved)

	assert_eq(WorldEventManager.active_events.size(), 1)
	var reconstructed: WorldEvent = WorldEventManager.active_events[0]
	assert_true(reconstructed is DragonEvent)
	assert_eq(reconstructed.event_id, event.event_id)
	assert_eq(reconstructed.phase, WorldEvent.PHASE_PREPARATION)
	assert_eq((reconstructed as DragonEvent).origin_region, Vector2i(2, 9))
	assert_eq((reconstructed as DragonEvent).target_civ_index, 1)

	WorldEventManager.active_events.clear()
	WorldEventManager._next_event_id = 0

## --- Determinismo (contrato, secao 4) ---------------------------------------
## Ja provado genericamente em WorldEvent (test_world_event.gd) e em
## integracao real (test_game_manager.gd) -- aqui so confirma que
## DragonEvent (subclasse) herda o mesmo event_rng() sem reimplementar
## nada, e que o estado do evento (origin_region) nao interfere no RNG.
func test_dragon_event_rng_is_deterministic_and_independent_of_its_own_state():
	var event_a := DragonEvent.new()
	event_a.event_id = 4
	event_a.origin_region = Vector2i(1, 1)
	var event_b := DragonEvent.new()
	event_b.event_id = 4
	event_b.origin_region = Vector2i(50, 50) # estado especifico diferente, mesmo event_id

	assert_eq(event_a.event_rng(777, 10).randi(), event_b.event_rng(777, 10).randi(), "o RNG do evento depende so de map_seed+event_id+turno, nunca do proprio estado especifico (origin_region)")

## --- 5B.3-B: movimento, combate e raid ---------------------------------
## IA deliberadamente MINIMA (decisao explicita do usuario): luta se tiver
## inimigo em alcance, senao avanca/raida a cidade-alvo. attack_range do
## Dragao e' 1 (corpo-a-corpo -- MonsterDatabase.KIND_DATA["dragon"] nunca
## sobrescreve UnitData.attack_range, que default e' 1), entao "em alcance"
## aqui sempre significa "adjacente". Vector2i(1, 0) e' uma direcao de
## vizinho valida (HexGrid.NEIGHBOR_DIRS) -- mesma convencao ja usada em
## test_combat_resolver.gd.

## Funda a cidade-alvo ANTES de nascer o Dragao (precisa existir a tempo da
## trava de alvo em Announced->Preparation) numa coordenada distante o
## bastante pra garantir que precisa de mais de um turno de movimento.
func test_active_moves_the_dragon_closer_to_the_target_city_each_turn():
	var grid := _make_hex_grid(8)
	var target_player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(6, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [target_player])
	var distance_before: float = HexMetrics.axial_distance(event.dragon_unit.coord, city.coord)

	event.advance_turn(grid, [target_player])

	var distance_after: float = HexMetrics.axial_distance(event.dragon_unit.coord, city.coord)
	assert_lt(distance_after, distance_before, "o Dragao deveria ter avancado em direcao a cidade-alvo")
	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE, "ainda longe demais pra raidar ou terminar")

## Inimigo em alcance tem prioridade sobre perseguir a cidade -- o Dragao
## luta em vez de se mover, mesmo tendo uma cidade-alvo definida.
func test_active_fights_an_enemy_unit_in_range_instead_of_moving_toward_the_city():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(5, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [target_player])
	var dragon_coord := event.dragon_unit.coord
	var enemy := grid.spawn_unit(dragon_coord + Vector2i(1, 0), UnitDatabase.create_unit("warrior"), target_player)
	var enemy_hp_before := enemy.hp

	event.advance_turn(grid, [target_player])

	assert_eq(event.dragon_unit.coord, dragon_coord, "deveria ter lutado, nao se movido")
	assert_lt(enemy.hp, enemy_hp_before, "o inimigo adjacente deveria ter sido atacado")

## Cidade-alvo adjacente desde o nascimento -- o primeiro tick em Active ja
## deveria raidar em vez de tentar se mover (contrato: raid, nunca
## conquista -- ver CombatResolver.resolve_city_attack).
func test_active_raids_the_city_when_the_dragon_is_already_in_range():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	var city := grid.found_city(origin + Vector2i(1, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [target_player])
	var hp_before := city.hp

	event.advance_turn(grid, [target_player])

	assert_lt(city.hp, hp_before, "a cidade deveria ter sofrido dano do raid")
	assert_eq(city.owner_player, target_player, "raid nunca captura (contrato: Dragao nao e' uma unidade de conquista)")
	assert_eq(event.raids_done, 1)
	assert_eq(event.current_target_city_coord, DragonEvent.NO_COORD, "depois de raidar, precisa voltar a procurar um alvo (mesmo que seja a mesma cidade de novo)")
	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE, "1 raid < DEVASTATION_RAID_LIMIT, ainda deveria continuar ativo")
	assert_not_null(event.dragon_unit, "o Dragao continua vivo depois de raidar")

## Depois de DEVASTATION_RAID_LIMIT raids bem-sucedidos, o evento se
## resolve sozinho (outcome "devastated") -- unica civ-alvo, unica cidade,
## entao cada tick em Active volta a escolher e raidar a mesma cidade.
func test_reaching_the_devastation_raid_limit_resolves_the_event():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [target_player])

	for i in range(DragonEvent.DEVASTATION_RAID_LIMIT):
		event.advance_turn(grid, [target_player])

	assert_eq(event.raids_done, DragonEvent.DEVASTATION_RAID_LIMIT)
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)
	assert_eq(event.result, {"outcome": "devastated"})

## Resolution ainda fecha o ciclo removendo a Unit do mapa, mesmo quando o
## desfecho foi "devastated" em vez do skeleton generico de 5B.3-A.
func test_resolution_removes_the_dragon_after_devastation():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [target_player])
	for i in range(DragonEvent.DEVASTATION_RAID_LIMIT):
		event.advance_turn(grid, [target_player])
	var spawn_coord := event.spawn_coord

	event.advance_turn(grid, [target_player]) # Resolution -> Completed

	assert_null(grid.get_unit_at(spawn_coord))
	assert_null(event.dragon_unit)
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)

## Se uma unidade matar o Dragao durante o turno de outro jogador (fora do
## controle do proprio DragonEvent), CombatResolver.resolve ja removeu a
## Unit do mapa sozinho -- o proximo tick em Active precisa detectar isso
## (hp <= 0.0 ou a Unit ja sumida) e se resolver como "defeated" sem
## crashar tentando usar dragon_unit.coord de uma Unit ja removida.
func test_active_resolves_as_defeated_when_the_dragon_was_already_killed():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [target_player])
	event.dragon_unit.hp = 0.0
	grid.remove_unit(event.dragon_unit) # simula o que CombatResolver.resolve ja teria feito

	event.advance_turn(grid, [target_player])

	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)
	assert_eq(event.result, {"outcome": "defeated"})

	event.advance_turn(grid, [target_player]) # Resolution -> Completed, nao deveria tentar remover de novo

	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)
	assert_null(event.dragon_unit)

## Caso raro nao previsto no contrato original: a civ-alvo perde todas as
## cidades (destruidas/civ eliminada) enquanto o Dragao ainda esta Active.
## Tratado como fim do evento em vez de travar procurando um alvo que nunca
## vai aparecer.
func test_active_resolves_as_no_target_when_the_target_civ_has_no_cities():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new()) # sem cidade nenhuma
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [target_player])

	event.advance_turn(grid, [target_player])

	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)
	assert_eq(event.result, {"outcome": "no_target"})

## --- _choose_target_city em isolamento ----------------------------------

func test_choose_target_city_keeps_pursuing_the_same_city_over_a_closer_one():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var far_city := grid.found_city(Vector2i(5, 0), player, "Longe")
	grid.found_city(Vector2i(1, 0), player, "Perto")
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.current_target_city_coord = far_city.coord

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, far_city, "deveria continuar perseguindo a cidade ja escolhida, mesmo existindo uma mais proxima")

func test_choose_target_city_falls_back_to_nearest_when_not_pursuing_anything():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(5, 0), player, "Longe")
	var near_city := grid.found_city(Vector2i(1, 0), player, "Perto")
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, near_city)

## --- Contaminacao de ownership atraves de movimento/combate/raid --------
## Extensao do requisito ja coberto em 5B.3-A (spawn): o Dragao tambem
## nunca deveria aparecer em player.units ao se mover, lutar ou raidar --
## nao so ao nascer.
func test_dragon_never_appears_in_any_players_units_through_movement_combat_and_raid():
	var grid := _make_hex_grid(8)
	var target_player := PlayerData.new(CivilizationData.new())
	var other_player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	var city := grid.found_city(origin + Vector2i(1, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [target_player, other_player])

	for i in range(DragonEvent.DEVASTATION_RAID_LIMIT + 1):
		if event.is_completed():
			break
		event.advance_turn(grid, [target_player, other_player])
		assert_false(target_player.units.has(event.dragon_unit), "Dragao nunca deveria aparecer em player.units")
		assert_false(other_player.units.has(event.dragon_unit))

	assert_eq(event.result, {"outcome": "devastated"})

## --- Persistencia de progresso de raid (contrato, secao 3) --------------

func test_to_save_dict_and_from_save_dict_round_trip_raid_progress():
	var event := DragonEvent.new()
	event.raids_done = 2
	event.current_target_city_coord = Vector2i(4, 4)

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.raids_done, 2)
	assert_eq(loaded.current_target_city_coord, Vector2i(4, 4))

func test_from_save_dict_defaults_raid_progress_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({}) # simula um dict incompleto/de outro tipo de evento
	assert_eq(event.raids_done, 0)
	assert_eq(event.current_target_city_coord, DragonEvent.NO_COORD)
