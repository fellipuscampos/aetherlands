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
	assert_eq(event.result.get("outcome"), "defeated", "dragon_unit nulo e' tratado como 'ja nao esta mais aqui', mesmo caminho de uma morte em combate fora do tick")

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
## Roadmap "Fase Macro" 5B.3-C -- achado do usuario jogando manualmente:
## "o Dragão nunca aparece". origin_region e' sorteada entre TODOS os tiles
## do mapa (WorldEventTrigger.choose_dragon_origin_region), quase sempre
## fora da area ja explorada -- sem isto, HexGrid._apply_fog_to_entities
## escondia a Unit pra sempre (ver test_hexgrid_fog.gd pro comportamento
## generico de always_visible).
func test_spawned_dragon_unit_is_always_visible_regardless_of_fog():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)

	_advance_to_active(event, grid, [])

	assert_true(event.dragon_unit.always_visible, "sem isto o Dragao fica escondido pra sempre a menos que alguem explore o tile exato onde nasceu")

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

## Roadmap "Fase Macro" 5B.3-D, item 2 -- pedido EXPLICITO do usuario apos
## o playtest ("nascer sobre agua NAO deve ser tratado como bug... o Dragao
## voa, entao nascer sobre agua e' aceitavel"). Substitui o teste antigo
## (pre-5B.3-D) que esperava o oposto -- agua/lava agora sao tiles VALIDOS
## de spawn, sem nenhuma expansao de anel necessaria.
func test_choose_spawn_coord_accepts_ocean_as_a_valid_spawn_tile():
	var grid := _make_hex_grid()
	var origin := Vector2i(0, 0)
	grid.tiles[origin] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

	var event := DragonEvent.new()
	event.origin_region = origin
	var chosen := event._choose_spawn_coord(grid)

	assert_eq(chosen, origin, "agua e' um tile valido pro Dragao (ele voa) -- nao deveria expandir em busca de terra firme")

## Ainda existe um motivo real pra expandir em aneis: o tile estar OCUPADO
## por outra unidade/cidade, nunca terreno.
func test_choose_spawn_coord_expands_past_a_tile_occupied_by_a_city():
	var grid := _make_hex_grid()
	var origin := Vector2i(0, 0)
	var player := PlayerData.new(CivilizationData.new())
	grid.found_city(origin, player, "No Caminho")

	var event := DragonEvent.new()
	event.origin_region = origin
	var chosen := event._choose_spawn_coord(grid)

	assert_ne(chosen, origin, "tile ocupado por uma cidade, deveria ter escolhido outro")
	assert_null(grid.get_city_at(chosen), "pre-condicao do teste: o tile escolhido precisa estar livre de verdade")

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
	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE, "1 raid < CIV_VISIT_TARGET, ainda deveria continuar ativo")
	assert_not_null(event.dragon_unit, "o Dragao continua vivo depois de raidar")

## Depois de CIV_VISIT_TARGET raids bem-sucedidos contra a UNICA civ viva,
## o evento se resolve sozinho (outcome "devastated") -- unica civ-alvo,
## unica cidade, entao cada tick em Active volta a escolher e raidar a
## mesma cidade (5B.3-G: cobertura continental, substitui DEVASTATION_
## RAID_LIMIT).
func test_reaching_the_civ_visit_target_resolves_the_event():
	var grid := _make_hex_grid(6)
	var target_player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), target_player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [target_player])

	for i in range(DragonEvent.CIV_VISIT_TARGET):
		event.advance_turn(grid, [target_player])

	assert_eq(event.raids_done, DragonEvent.CIV_VISIT_TARGET)
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)
	assert_eq(event.result.get("outcome"), "devastated")

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
	for i in range(DragonEvent.CIV_VISIT_TARGET):
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
	assert_eq(event.result.get("outcome"), "defeated")

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
	assert_eq(event.result.get("outcome"), "no_target")

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

	for i in range(DragonEvent.CIV_VISIT_TARGET + 5): # folga generosa, o break abaixo cobre o timing exato
		if event.is_completed():
			break
		event.dragon_unit.reset_movement() # GameManager._on_turn_changed faz isto todo turno de verdade
		event.advance_turn(grid, [target_player, other_player])
		assert_false(target_player.units.has(event.dragon_unit), "Dragao nunca deveria aparecer em player.units")
		assert_false(other_player.units.has(event.dragon_unit))

	assert_eq(event.result.get("outcome"), "devastated")

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

## --- Persistencia de cobertura continental (5B.3-G, secao 3/15/16) --------
## SaveManager serializa em JSON (so' tem chave string) -- civ_visits
## precisa sobreviver o round-trip com chave INT de volta, senao civ_
## visits.get(indice_int, 0) nunca bateria com uma chave string
## sobrevivente do load (perderia todo o progresso de cobertura em
## silencio a cada save/load).

func test_to_save_dict_and_from_save_dict_round_trip_civ_visits():
	var event := DragonEvent.new()
	event.civ_visits = {0: 2, 1: 1, 3: 0}

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.civ_visits.get(0, -1), 2)
	assert_eq(loaded.civ_visits.get(1, -1), 1)
	assert_eq(loaded.civ_visits.get(3, -1), 0)
	assert_eq(loaded.civ_visits.size(), 3, "nenhuma chave deveria ter sobrevivido como STRING (o que faria .get(int) falhar silenciosamente)")

func test_from_save_dict_defaults_civ_visits_to_empty_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({}) # simula um dict incompleto/de outro tipo de evento
	assert_eq(event.civ_visits, {})

func test_civ_visits_progress_survives_a_save_load_round_trip_mid_active():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	event.advance_turn(grid, [player]) # 1o raid de verdade
	assert_eq(event.civ_visits.get(0, 0), 1, "pre-condicao: a civ 0 recebeu 1 visita")

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	loaded.relink_unit(grid)

	assert_eq(loaded.civ_visits.get(0, 0), 1, "progresso de cobertura nao pode se perder num save/load em pleno Active")
	loaded.dragon_unit.reset_movement()
	loaded.advance_turn(grid, [player]) # continua normalmente, 2o raid
	assert_eq(loaded.civ_visits.get(0, 0), 2, "deveria continuar contando a partir de onde parou, nao reiniciar do zero")

## --- Roadmap "Dragon Event v1 fechado": ranking de dano (damage_by_civ) ---
## "Ranking de dano... dano real causado ao Dragao... isso também deixa
## preparado o terreno para o 5B.4: recompensa proporcional à contribuição."

func test_record_damage_accumulates_per_civ_for_the_active_dragon():
	var grid := _make_hex_grid(6)
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	WorldEventManager.active_events.append(event)

	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, 0, 12.0)
	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, 0, 7.0)
	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, 1, 29.0)

	assert_almost_eq(event.damage_by_civ.get(0, 0.0), 19.0, 0.01, "dano da MESMA civ deveria acumular")
	assert_almost_eq(event.damage_by_civ.get(1, 0.0), 29.0, 0.01)
	WorldEventManager.active_events.clear()

func test_record_damage_ignores_zero_or_negative_damage():
	var grid := _make_hex_grid(6)
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	WorldEventManager.active_events.append(event)

	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, 0, 0.0)
	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, 0, -5.0)

	assert_false(event.damage_by_civ.has(0), "'se dá 0, não conta' -- pedido explicito do usuario")
	WorldEventManager.active_events.clear()

func test_record_damage_ignores_an_invalid_civ_index():
	var grid := _make_hex_grid(6)
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	WorldEventManager.active_events.append(event)

	DragonEvent.record_damage_if_target_is_the_active_dragon(event.dragon_unit, -1, 10.0) # unidade sem dono (ex.: outro monstro)

	assert_true(event.damage_by_civ.is_empty())
	WorldEventManager.active_events.clear()

func test_record_damage_ignores_a_unit_that_is_not_the_active_dragon():
	var grid := _make_hex_grid(6)
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	WorldEventManager.active_events.append(event)
	var some_other_unit := grid.spawn_monster_at(Vector2i(2, 0), "goblin")

	DragonEvent.record_damage_if_target_is_the_active_dragon(some_other_unit, 0, 10.0)

	assert_true(event.damage_by_civ.is_empty(), "so' dano contra a Unit do Dragao de verdade deveria contar")
	WorldEventManager.active_events.clear()

func test_to_save_dict_and_from_save_dict_round_trip_damage_by_civ():
	var event := DragonEvent.new()
	event.damage_by_civ = {0: 19.0, 1: 29.0}

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_almost_eq(loaded.damage_by_civ.get(0, -1.0), 19.0, 0.01)
	assert_almost_eq(loaded.damage_by_civ.get(1, -1.0), 29.0, 0.01)
	assert_eq(loaded.damage_by_civ.size(), 2, "nenhuma chave deveria ter sobrevivido como STRING")

func test_from_save_dict_defaults_damage_by_civ_to_empty_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({})
	assert_eq(event.damage_by_civ, {})

## --- Roadmap "Fase Macro" 5B.3-D: FLYING vs GROUND (item 1) ---------------
## FLYING (longe do alvo, ~DRAGON_FLYING_TILES_PER_TURN/turno, atravessa
## qualquer terreno) vs GROUND (perto, movimento normal ~2/turno, ver
## MonsterDatabase). Reusa RivalAI.move_unit_toward/HexGrid.compute_
## reachable -- so' um movement_left maior nesse tick, nunca um pathfind
## novo.

func test_flying_travel_mode_crosses_ocean_tiles():
	var grid := _make_hex_grid(12)
	for y in range(-2, 3): # "rio" de oceano entre o Dragao e o alvo
		grid.tiles[Vector2i(3, y)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(6, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	var distance_before: float = HexMetrics.axial_distance(event.dragon_unit.coord, city.coord)

	event.advance_turn(grid, [player])

	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_FLYING, "distancia > DRAGON_GROUND_ENGAGE_RANGE, deveria estar voando")
	var distance_after: float = HexMetrics.axial_distance(event.dragon_unit.coord, city.coord)
	assert_lt(distance_after, distance_before, "deveria ter atravessado o oceano em direcao ao alvo, nao ficado parado por nao voar")

func test_flying_travel_mode_covers_the_full_flying_budget_in_one_turn():
	var grid := _make_hex_grid(12)
	var player := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(11, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])

	event.advance_turn(grid, [player])

	var distance_traveled: float = HexMetrics.axial_distance(Vector2i(0, 0), event.dragon_unit.coord)
	assert_almost_eq(distance_traveled, float(DragonEvent.DRAGON_FLYING_TILES_PER_TURN), 0.01, "mapa livre, sem obstaculo -- deveria ter avancado exatamente o orcamento de voo")

func test_ground_travel_mode_when_close_to_the_target():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(2, 0), player, "Alvo") # distancia 2, dentro de DRAGON_GROUND_ENGAGE_RANGE (3)
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])

	event.advance_turn(grid, [player])

	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_GROUND)

func test_transitions_from_flying_to_ground_as_it_approaches():
	var grid := _make_hex_grid(12)
	var player := PlayerData.new(CivilizationData.new())
	# Distancia = orcamento de voo + 1: um unico salto de voo cobre o
	# orcamento inteiro, deixando so' 1 tile de sobra (dentro de
	# DRAGON_GROUND_ENGAGE_RANGE) -- escolhido pra funcionar independente
	# do valor exato do orcamento (nao trava num numero magico se mudar de
	# novo, ver item 1 do pedido do usuario: reduzido de 10 pra 6 aqui).
	var target_distance := DragonEvent.DRAGON_FLYING_TILES_PER_TURN + 1
	grid.found_city(Vector2i(target_distance, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])

	event.advance_turn(grid, [player]) # primeiro salto de voo, ainda fora do alcance de GROUND
	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_FLYING, "ainda longe do alvo no inicio deste tick")

	event.advance_turn(grid, [player]) # segundo salto -- agora dentro de DRAGON_GROUND_ENGAGE_RANGE
	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_GROUND)

func test_transitions_from_ground_back_to_flying_after_switching_to_a_distant_city():
	var grid := _make_hex_grid(12)
	var player := PlayerData.new(CivilizationData.new())
	var near_city := grid.found_city(Vector2i(1, 0), player, "Perto")
	grid.found_city(Vector2i(11, 0), player, "Longe")
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	event.last_raided_city_coord = near_city.coord # forca a exclusao da cidade perto

	event.advance_turn(grid, [player])

	assert_eq(event.travel_mode, DragonEvent.TRAVEL_MODE_FLYING, "unica alternativa restante (excluindo a ultima raidada) e' a cidade longe")

func test_flying_movement_is_deterministic_for_the_same_state():
	var grid_a := _make_hex_grid(12)
	var player_a := PlayerData.new(CivilizationData.new())
	grid_a.found_city(Vector2i(11, 0), player_a, "Alvo")
	var event_a := DragonEvent.new()
	event_a.origin_region = Vector2i(0, 0)
	_advance_to_active(event_a, grid_a, [player_a])
	event_a.advance_turn(grid_a, [player_a])

	var grid_b := _make_hex_grid(12)
	var player_b := PlayerData.new(CivilizationData.new())
	grid_b.found_city(Vector2i(11, 0), player_b, "Alvo")
	var event_b := DragonEvent.new()
	event_b.origin_region = Vector2i(0, 0)
	_advance_to_active(event_b, grid_b, [player_b])
	event_b.advance_turn(grid_b, [player_b])

	assert_eq(event_a.dragon_unit.coord, event_b.dragon_unit.coord, "o MESMO estado inicial deveria produzir o MESMO deslocamento -- sem RNG no movimento")

## --- Dano em area durante um tick real de combate (item 4) ----------------

func test_active_combat_deals_splash_damage_to_a_nearby_enemy():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	var primary_coord: Vector2i = grid.get_neighbors(event.dragon_unit.coord)[0]
	var secondary_coord := Vector2i(999999, 999999)
	for candidate in grid.get_neighbors(primary_coord):
		if candidate != event.dragon_unit.coord:
			secondary_coord = candidate
			break
	grid.spawn_unit(primary_coord, UnitDatabase.create_unit("warrior"), player)
	var secondary := grid.spawn_unit(secondary_coord, UnitDatabase.create_unit("warrior"), player)
	var secondary_hp_before := secondary.hp

	event.advance_turn(grid, [player])

	assert_lt(secondary.hp, secondary_hp_before, "unidade proxima ao alvo primario deveria ter tomado dano em area tambem")

## --- Roadmap "Fase Macro" 5B.3-D, correcao pos-playtest: BUG real ---------
## Achado do usuario jogando manualmente: "Dragão desaparece ao atacar
## cidade sem tropas". Causa raiz identificada por leitura de codigo (nao
## precisou de instrumentacao temporaria): esta Unit e' NEUTRA (owner_
## player == null), o MESMO criterio usado por qualquer monstro de covil
## comum -- sem marcacao nenhuma, MonsterAI.take_turn() E' GameManager.
## _build_monster_turn_items() (o caminho de VERDADE usado no jogo real,
## stagger_ai_turns == true) processavam esta MESMA Unit de novo com a IA
## GENERICA de monstro (MonsterDatabase.KIND_DATA["dragon"].behavior ==
## BEHAVIOR_HUNTER -- MonsterAI._take_hunter_turn), COMPLETAMENTE
## independente do proprio DragonEvent: perseguia "presa" propria (raio 6,
## sem relacao nenhuma com a cidade-alvo do evento) e podia ate matar a
## Unit via CombatResolver.resolve() comum (nunca resolve_with_splash) --
## tudo isso ANTES do proprio DragonEvent._take_dragon_turn() rodar no
## MESMO turno (ver GameManager._on_turn_changed/_finish_turn: MonsterAI
## sempre roda antes de WorldEventManager.advance_turn). Fix: Unit.
## world_event_managed, aplicado no spawn E' no relink_unit() (pos save/
## load) via DragonEvent._mark_dragon_unit(), checado por MonsterAI.
## take_turn()/GameManager._build_monster_turn_items().
##
## Estes testes chamam MonsterAI.take_turn() JUNTO com DragonEvent.
## advance_turn(), na MESMA ORDEM do jogo real -- provando que o conflito
## nao acontece mais, nunca so' testando DragonEvent isolado (que jamais
## teria pego este bug, exatamente o alerta do usuario).

func test_dragon_unit_is_marked_as_world_event_managed_when_it_spawns():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [])
	assert_true(event.dragon_unit.world_event_managed, "sem isto, MonsterAI processaria esta Unit de novo com IA generica de monstro")

func test_relink_unit_reapplies_the_world_event_managed_and_always_visible_flags():
	var grid := _make_hex_grid()
	var spawn_coord := Vector2i(2, 2)
	# Simula exatamente o que o save generico de monstros neutros faz --
	# reconstroi a Unit do ZERO, sem nenhuma das duas flags (elas nao sao
	# dado persistido, sao propriedades da Unit -- ver comentario do campo
	# em Unit.gd).
	var restored_unit := grid.spawn_monster_at(spawn_coord, "dragon")
	assert_false(restored_unit.always_visible, "pre-condicao: a Unit recem-reconstruida NUNCA vem com a flag ja ligada")
	assert_false(restored_unit.world_event_managed, "pre-condicao")
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.spawn_coord = spawn_coord
	event.dragon_unit = null # como viria de from_save_dict

	event.relink_unit(grid)

	assert_true(event.dragon_unit.always_visible, "sem reaplicar aqui, um save/load reintroduziria o bug do Dragao invisivel sob nevoa")
	assert_true(event.dragon_unit.world_event_managed, "sem reaplicar aqui, um save/load reintroduziria o bug desta secao (MonsterAI processando a Unit de novo)")

func test_monster_ai_take_turn_never_moves_the_dragon_unit():
	var grid := _make_hex_grid(8)
	var player := PlayerData.new(CivilizationData.new())
	# "Presa" em potencial pro comportamento Cacador generico -- se o fix
	# nao estivesse aplicado, o Dragao seria atraido pra perto dela em vez
	# de perseguir a cidade-alvo que o DragonEvent escolheu.
	grid.spawn_unit(Vector2i(0, 3), UnitDatabase.create_unit("warrior"), player)
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	var coord_before := event.dragon_unit.coord

	MonsterAI.take_turn(grid, TurnManager.turn_number)

	assert_eq(event.dragon_unit.coord, coord_before, "MonsterAI.take_turn nunca deveria mover a Unit do Dragao -- ela tem IA propria em DragonEvent")

func test_monster_ai_take_turn_never_fights_using_the_dragon_unit():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	var enemy_coord: Vector2i = grid.get_neighbors(event.dragon_unit.coord)[0]
	var enemy := grid.spawn_unit(enemy_coord, UnitDatabase.create_unit("warrior"), player)
	var enemy_hp_before := enemy.hp

	MonsterAI.take_turn(grid, TurnManager.turn_number)

	assert_almost_eq(enemy.hp, enemy_hp_before, 0.01, "MonsterAI.take_turn nunca deveria colocar a Unit do Dragao em combate -- isso e' responsabilidade exclusiva de DragonEvent._take_dragon_turn")
	assert_true(is_instance_valid(event.dragon_unit) and event.dragon_unit.hp > 0.0, "o Dragao deveria continuar vivo e intacto")

func test_build_monster_turn_items_excludes_the_dragon_unit():
	# Mesma exclusao, agora no caminho de VERDADE usado no jogo real
	# (stagger_ai_turns == true) -- ver GameManager._build_monster_turn_items.
	# Um goblin comum tambem no grid garante que a fila nao fica vazia so'
	# porque o Dragao foi excluido -- sem isto, o teste passaria vazio
	# (GUT ja pegou essa versao anterior como "Risky: Did not assert").
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [])
	var goblin := grid.spawn_monster_at(Vector2i(2, 2), "goblin")
	var original_hex_grid = GameManager.hex_grid
	GameManager.hex_grid = grid

	var items: Array = GameManager._build_monster_turn_items()

	GameManager.hex_grid = original_hex_grid
	assert_false(items.is_empty(), "pre-condicao: o goblin comum precisa continuar aparecendo na fila")
	var included_units: Array = []
	for item in items:
		included_units.append(item.unit)
	assert_true(goblin in included_units, "monstro comum continua sendo processado normalmente")
	assert_false(event.dragon_unit in included_units, "a fila de turnos de monstro (caminho real do jogo) nunca deveria incluir a Unit do Dragao")

## Reproducao EXATA do cenario relatado pelo usuario: cidade valida SEM
## nenhuma unidade defensora, Dragao raidando repetidamente, na MESMA
## ordem de chamadas do jogo real (MonsterAI.take_turn ANTES de
## DragonEvent.advance_turn, todo turno). Precisa terminar com uma
## resolucao EXPLICITA (devastated), nunca desaparecer sem result nenhum.
func test_dragon_never_disappears_silently_while_raiding_an_undefended_city():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "Sem Guarnicao") # NENHUMA unidade nela
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])

	var turn := TurnManager.turn_number
	for i in range(10): # bem mais que o suficiente pra atingir CIV_VISIT_TARGET
		if event.is_completed():
			break
		turn += 1
		TurnManager.turn_number = turn
		event.dragon_unit.reset_movement()
		MonsterAI.take_turn(grid, turn) # MESMA ordem do jogo real -- ANTES do proprio evento
		event.advance_turn(grid, [player])

	assert_true(event.is_completed(), "o evento precisa ter chegado a uma resolucao, nunca ter ficado preso em Active pra sempre")
	assert_eq(event.result.get("outcome", ""), "devastated", "cidade sem guarnicao nenhuma -- o Dragao deveria conseguir devastar normalmente")
	assert_null(event.dragon_unit, "a Unit precisa ter sido removida ao terminar")

## --- Item 6 do pedido do usuario: testes de regressao nomeados A-F --------

## Caso A: cidade COM tropas -- Dragao ataca, causa dano, evento continua.
func test_regression_case_a_city_with_troops_is_engaged_and_event_continues():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "Guarnecida")
	var guard_coord: Vector2i = grid.get_neighbors(origin)[0]
	var guard := grid.spawn_unit(guard_coord, UnitDatabase.create_unit("warrior"), player)
	var guard_hp_before := guard.hp
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])

	MonsterAI.take_turn(grid, TurnManager.turn_number)
	event.advance_turn(grid, [player])

	assert_lt(guard.hp, guard_hp_before, "o guarda adjacente deveria ter sido engajado em combate")
	assert_false(event.is_completed(), "um unico combate nao deveria terminar o evento sozinho")

## Caso B: cidade SEM tropas -- Dragao causa dano, continua existindo, nao
## desaparece silenciosamente so' depois de UM raid (bem antes do limite).
func test_regression_case_b_undefended_city_takes_damage_without_disappearing():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	var city := grid.found_city(origin + Vector2i(1, 0), player, "Sem Guarnicao")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	var hp_before := city.hp

	MonsterAI.take_turn(grid, TurnManager.turn_number)
	event.advance_turn(grid, [player])

	assert_lt(city.hp, hp_before, "a cidade deveria ter sofrido dano do raid")
	assert_false(event.is_completed(), "1 raid < CIV_VISIT_TARGET -- o evento deveria continuar")
	assert_not_null(event.dragon_unit, "o Dragao nao deveria ter desaparecido depois de so' 1 raid")

## Caso C: cidade sem tropas + cobertura continental atingida -- devastated,
## Resolution, Completed, Unit removida. 5B.3-G: o desfecho NAO usa mais
## toast (EventBus.notify) nenhum -- vira MODAL bloqueante em HUD, ver
## secao "Nenhum desaparecimento silencioso" abaixo -- so' o result/fase
## explicitos importam aqui, nunca um result silencioso.
func test_regression_case_c_undefended_city_reaches_devastation_with_explicit_resolution():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "Sem Guarnicao")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])

	var turn := TurnManager.turn_number
	for i in range(10):
		if event.is_completed():
			break
		turn += 1
		TurnManager.turn_number = turn
		event.dragon_unit.reset_movement()
		MonsterAI.take_turn(grid, turn)
		event.advance_turn(grid, [player])

	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)
	assert_eq(event.result.get("outcome", ""), "devastated")
	assert_null(event.dragon_unit)

## Caso D: cidade sem tropas + outra cidade disponivel -- NAO resolve, NAO
## remove, escolhe o novo alvo e continua (falta de tropas nunca e'
## condicao de fim -- so' o limite de devastacao/derrota/sem-alvo sao).
func test_regression_case_d_switches_to_another_city_instead_of_ending_the_event():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "A")
	var city_b := grid.found_city(origin + Vector2i(1, -1), player, "B")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])

	MonsterAI.take_turn(grid, TurnManager.turn_number)
	event.advance_turn(grid, [player]) # raida A (1o raid, ainda < limite)

	assert_false(event.is_completed(), "1 raid (< CIV_VISIT_TARGET) nunca deveria terminar o evento so' por falta de tropas na cidade")
	assert_not_null(event.dragon_unit)
	var next_target := event._choose_target_city([player])
	assert_eq(next_target, city_b, "deveria escolher a OUTRA cidade valida em vez de travar/terminar so' porque a ultima nao tinha tropas")

## Caso E: Dragao morto por unidade -- defeated, remocao, Resolution,
## Completed (confirma que o fix nao quebrou a deteccao legitima de morte).
func test_regression_case_e_dragon_killed_by_a_unit_resolves_as_defeated():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	event.dragon_unit.hp = 0.0
	grid.remove_unit(event.dragon_unit)

	MonsterAI.take_turn(grid, TurnManager.turn_number)
	event.advance_turn(grid, [player])

	assert_eq(event.result.get("outcome", ""), "defeated")
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)

## Caso F: nenhuma cidade valida -- no_target, resolucao explicita.
func test_regression_case_f_no_valid_city_resolves_as_no_target():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new()) # sem cidade nenhuma
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])

	MonsterAI.take_turn(grid, TurnManager.turn_number)
	event.advance_turn(grid, [player])

	assert_eq(event.result.get("outcome", ""), "no_target")
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)

## --- Roadmap "Fase Macro" 5B.3-E: relink apos o Dragao ja ter se movido ---
## BUG real: spawn_coord fica CONGELADO no tile de nascimento pra sempre
## (nunca reescrito em lugar nenhum) -- usa-lo pra relink_unit() depois de
## um save/load com o Dragao ja longe dali procurava a Unit no lugar
## ERRADO (geralmente vazio), retornando null. O tick seguinte lia
## dragon_unit == null e resolvia "defeated" por engano, mesmo com a Unit
## de verdade ainda viva e presente no mapa -- so' ORFA, sem always_
## visible/world_event_managed reaplicados (voltava a ficar invisivel sob
## nevoa E' processavel pela IA generica de monstro de novo). Fix:
## last_unit_coord, capturado a partir da posicao ATUAL da Unit no exato
## momento do save.

func test_relink_unit_finds_the_dragon_after_it_has_moved_away_from_its_spawn_tile():
	var grid := _make_hex_grid(8)
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [])
	var spawn_coord := event.spawn_coord
	# Simula o Dragao tendo voado bem longe do spawn (5B.3-D) antes de um
	# save acontecer.
	grid.move_unit(event.dragon_unit, Vector2i(5, 0), 0.0)
	assert_ne(event.dragon_unit.coord, spawn_coord, "pre-condicao: precisa estar longe do spawn original")

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	# Simula o save generico de monstros neutros ja tendo reconstruido a
	# Unit na posicao ATUAL (nao no spawn) -- exatamente o que SaveManager
	# ja faz de verdade (serializa/restaura por unit.coord, ver
	# SaveManager._serialize_neutral_units/_deserialize_neutral_units).
	var restored_unit := grid.spawn_monster_at(Vector2i(5, 0), "dragon")

	loaded.relink_unit(grid)

	assert_eq(loaded.dragon_unit, restored_unit, "relink precisa achar a Unit onde ela REALMENTE esta agora, nao onde nasceu")
	assert_true(loaded.dragon_unit.always_visible)
	assert_true(loaded.dragon_unit.world_event_managed)

## Compatibilidade com saves ANTIGOS (de antes de last_unit_coord existir)
## -- from_save_dict() ja tem fallback seguro (NO_COORD), relink_unit()
## precisa continuar funcionando pro caso mais simples (Dragao ainda no
## proprio tile de spawn, comportamento identico a antes de 5B.3-E).
func test_relink_unit_falls_back_to_spawn_coord_when_last_unit_coord_is_missing():
	var grid := _make_hex_grid()
	var spawn_coord := Vector2i(2, 2)
	var restored_unit := grid.spawn_monster_at(spawn_coord, "dragon")
	var original := DragonEvent.new()
	original.phase = WorldEvent.PHASE_ACTIVE
	original.spawn_coord = spawn_coord
	# original.dragon_unit continua null -- to_save_dict() naturalmente
	# omite last_unit_coord nesse caso, mesmo formato de um save de antes
	# deste campo existir.
	var saved := original.to_save_dict()

	var event := DragonEvent.new()
	event.from_save_dict(saved)
	event.relink_unit(grid)

	assert_eq(event.dragon_unit, restored_unit, "sem last_unit_coord, deveria cair de volta pro spawn_coord")

func test_to_save_dict_and_from_save_dict_round_trip_last_unit_coord():
	var grid := _make_hex_grid()
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(3, -1), "dragon")

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.last_unit_coord, Vector2i(3, -1))

func test_to_save_dict_omits_last_unit_coord_when_the_dragon_has_not_spawned_yet():
	var event := DragonEvent.new() # dragon_unit continua null
	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	assert_eq(loaded.last_unit_coord, DragonEvent.NO_COORD)

## --- Anti-estagnacao: nao fica parado pra sempre combatendo (item 3) ------

func test_dragon_repositions_after_too_many_consecutive_combat_turns_in_the_same_spot():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	var enemy_coord: Vector2i = grid.get_neighbors(event.dragon_unit.coord)[0]
	var enemy := grid.spawn_unit(enemy_coord, UnitDatabase.create_unit("warrior"), player)
	enemy.hp = 999999.0 # nunca morre, forca o combate a se repetir todo tick
	var dragon_start_coord := event.dragon_unit.coord

	for i in range(DragonEvent.GROUND_COMBAT_STREAK_LIMIT):
		event.advance_turn(grid, [player])
		assert_eq(event.dragon_unit.coord, dragon_start_coord, "ainda dentro do limite de turnos seguidos -- deveria continuar lutando no mesmo lugar")

	event.advance_turn(grid, [player]) # o turno QUE estoura o limite

	assert_ne(event.dragon_unit.coord, dragon_start_coord, "depois do limite de turnos seguidos no mesmo lugar, deveria ter se reposicionado em vez de continuar parado")

## Roadmap "Fase Macro" 5B.3-F -- BUG real encontrado apos o usuario
## reportar "desaparece" DE NOVO, reproduzido com instrumentacao temporaria
## num playtest real: um rival em guerra de verdade PRODUZ reforcos sem
## parar, entao o break-off antigo (so' 1 vizinho) so' trocava o Dragao pro
## PROXIMO defensor da MESMA fileira -- ficava preso lutando contra um
## exercito inteiro por dezenas de turnos seguidos, raids_done travado,
## NUNCA voltando a perseguir a cidade (o evento continuava Active pra
## sempre, tecnicamente sem "sumir", mas indistinguivel disso pro
## jogador). Fix: o break-off agora e' um salto GRANDE (orcamento de
## FLYING) em direcao a cidade-alvo, nao um vizinho -- simula EXATAMENTE
## esse cenario (um defensor NOVO e DIFERENTE a cada tick, nunca o mesmo).
func test_dragon_breaks_off_with_a_large_jump_toward_the_target_when_facing_endless_reinforcements():
	var grid := _make_hex_grid(10)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(6, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	var dragon_start_coord := event.dragon_unit.coord
	var neighbors := grid.get_neighbors(dragon_start_coord)

	for i in range(DragonEvent.GROUND_COMBAT_STREAK_LIMIT + 1):
		var enemy := grid.spawn_unit(neighbors[i % neighbors.size()], UnitDatabase.create_unit("warrior"), player)
		enemy.hp = 999999.0 # nunca morre -- um defensor NOVO a cada tick, nunca o mesmo
		event.advance_turn(grid, [player])

	assert_ne(event.dragon_unit.coord, dragon_start_coord, "depois do limite, o Dragao precisa ter se AFASTADO de verdade, nao continuar preso trocando de adversario")
	var distance_moved: float = HexMetrics.axial_distance(dragon_start_coord, event.dragon_unit.coord)
	assert_gt(distance_moved, 1.0, "o break-off precisa ser um salto GRANDE em direcao ao alvo (orcamento de FLYING), nunca so' 1 tile -- 1 tile so' troca pro proximo defensor da mesma fileira, sem nunca progredir")

## Fecha o ciclo: uma vez que os reforcos PARAM de aparecer (guerra
## acabou, exercito exaurido, etc.), o Dragao precisa conseguir continuar
## progredindo normalmente (Flying/Ground/raid) ate um desfecho de
## verdade -- nao ficar preso mesmo depois do break-off funcionar.
func test_dragon_eventually_completes_the_event_after_breaking_off_from_reinforcements():
	var grid := _make_hex_grid(10)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(6, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	var neighbors := grid.get_neighbors(event.dragon_unit.coord)
	for i in range(DragonEvent.GROUND_COMBAT_STREAK_LIMIT + 1):
		var enemy := grid.spawn_unit(neighbors[i % neighbors.size()], UnitDatabase.create_unit("warrior"), player)
		enemy.hp = 999999.0
		event.advance_turn(grid, [player]) # a ultima chamada ja quebra o combate com o salto grande

	# Sem MAIS reforcos novos a partir daqui.
	for i in range(20):
		if event.is_completed():
			break
		event.advance_turn(grid, [player])

	assert_true(event.is_completed(), "sem reforcos infinitos, o Dragao deveria conseguir terminar o evento normalmente depois de quebrar o combate estagnado")

## --- 5B.3-G: cerco total (achado por reproducao de LONGA duracao em jogo
## real, apos a IA rival ganhar reacao militar/producao de emergencia) ------
## Com os 6 vizinhos do Dragao SEMPRE ocupados (reforcos repostos assim que
## um morre ou some), _break_off_toward (pathfind + _reposition_nearby de 1
## anel) podia falhar TODA VEZ -- um teste real chegou a 194 turnos seguidos
## sem o Dragao se mover 1 tile sequer, com o exercito rival crescendo sem
## parar (producao de emergencia sem teto). Fix: _reposition_escaping_siege
## (aneis crescentes) + rede de seguranca geral em _take_dragon_turn
## (DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD ticks sem progresso NENHUM --
## posicao OU raids_done -- forca a fuga, nao so' quando lutando).

func test_reposition_escaping_siege_finds_a_free_tile_beyond_a_full_ring_of_enemies():
	var grid := _make_hex_grid(10)
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	var player := PlayerData.new(CivilizationData.new())
	for neighbor in grid.get_neighbors(Vector2i(0, 0)):
		grid.spawn_unit(neighbor, UnitDatabase.create_unit("warrior"), player) # cerca TODOS os 6 vizinhos

	event._reposition_escaping_siege(grid)

	assert_ne(event.dragon_unit.coord, Vector2i(0, 0), "cercado nos 6 vizinhos, precisa ter escapado pra ALEM do 1o anel")
	assert_gt(HexMetrics.axial_distance(Vector2i(0, 0), event.dragon_unit.coord), 1.0, "a fuga de cerco precisa alcancar um tile fora do anel imediato, nao so' o vizinho (esse ja falhou)")

## Integracao real de ponta a ponta: uma UNICA posicao (a vizinhanca da
## cidade-alvo) permanece cercada/reabastecida turno apos turno -- uma
## guarnicao muito forte NUM lugar so', nao um exercito onisciente que
## persegue o Dragao pra qualquer lugar que ele va (isso exigiria producao
## instantanea e infinita em qualquer ponto do mapa, fora do alcance real
## da economia de qualquer civ). Uma vez que a rede de seguranca o tire
## dali, o Dragao precisa conseguir progredir e terminar o evento
## normalmente -- nao travar pra sempre so' porque UM ponto do mapa nunca
## para de defender.
func test_dragon_eventually_escapes_and_completes_when_one_location_stays_permanently_besieged():
	var grid := _make_hex_grid(10)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(6, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	var besieged_coord := event.dragon_unit.coord

	for turn in range(40):
		if event.is_completed():
			break
		event.dragon_unit.reset_movement()
		# So' a vizinhanca do ponto ORIGINAL fica permanentemente
		# guarnecida -- nao acompanha o Dragao se ele conseguir sair dali.
		for neighbor in grid.get_neighbors(besieged_coord):
			if grid.get_unit_at(neighbor) == null and grid.get_city_at(neighbor) == null:
				var reinforcement := grid.spawn_unit(neighbor, UnitDatabase.create_unit("warrior"), player)
				reinforcement.hp = 999999.0
		event.advance_turn(grid, [player])

	assert_true(event.is_completed(), "com uma guarnicao permanente num so' lugar, a rede de seguranca geral (DRAGON_STUCK_TURNS_ESCAPE_THRESHOLD) precisa ter tirado o Dragao dali a tempo de terminar o evento")

## Roadmap 5B.3-G v3 -- pedido explicito do usuario apos playtest real: "ele
## foi pra uma cidade que tinha muitas tropas e ficou infinito lá... o
## correto é ele estabelecer uma meta... e ir embora pra outra cidade, se
## não ele vai ficar preso pra sempre". Com DUAS civs disponiveis (ao
## contrario do teste anterior, que so' tinha uma e nao tinha pra onde ir),
## confirma que o Dragao realmente ABANDONA a cidade permanentemente
## cercada e vai RAIDAR a outra civ de verdade (nao so' se mexe local).
func test_dragon_abandons_a_permanently_besieged_target_and_raids_a_different_civ_instead():
	var grid := _make_hex_grid(10)
	var civ_a := PlayerData.new(CivilizationData.new())
	var civ_b := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(6, 0), civ_a, "A") # sera' permanentemente cercada
	grid.found_city(Vector2i(-6, 0), civ_b, "B") # livre, alcancavel
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var players: Array[PlayerData] = [civ_a, civ_b]
	_advance_to_active(event, grid, players)

	for turn in range(60):
		if event.is_completed() or event.civ_visits.get(1, 0) > 0:
			break
		event.dragon_unit.reset_movement()
		# So' a vizinhanca da CIDADE A fica permanentemente guarnecida.
		for neighbor in grid.get_neighbors(Vector2i(6, 0)):
			if grid.get_unit_at(neighbor) == null and grid.get_city_at(neighbor) == null:
				var reinforcement := grid.spawn_unit(neighbor, UnitDatabase.create_unit("warrior"), civ_a)
				reinforcement.hp = 999999.0
		event.advance_turn(grid, players)

	assert_gt(event.civ_visits.get(1, 0), 0, "depois de esgotar o orcamento de engajamento contra A (permanentemente cercada), o Dragao deveria ter ido raidar B de verdade")

## --- Alternancia entre multiplos alvos (item 7) ---------------------------

func test_choose_target_city_excludes_the_last_raided_city_when_an_alternative_exists():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var city_a := grid.found_city(Vector2i(1, 0), player, "A")
	var city_b := grid.found_city(Vector2i(2, 0), player, "B") # mais longe que A seria, se A nao estivesse excluida
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.last_raided_city_coord = city_a.coord

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, city_b, "cidade A acabou de ser raidada e existe alternativa (B) -- nao deveria escolher A de novo")

func test_choose_target_city_makes_the_previous_city_eligible_again_after_a_different_one_is_raided():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var city_a := grid.found_city(Vector2i(1, 0), player, "A")
	var city_b := grid.found_city(Vector2i(2, 0), player, "B")
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.last_raided_city_coord = city_b.coord # A -> B ja aconteceu, B e' a ultima agora

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, city_a, "B foi a ultima raidada -- A (mais perto) volta a ser elegivel")

func test_choose_target_city_falls_back_to_the_only_city_even_if_it_was_the_last_raided():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(1, 0), player, "Unica")
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.last_raided_city_coord = city.coord

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, city, "sem alternativa nenhuma, a unica cidade continua sendo escolhida (identico a antes de 5B.3-D)")

func test_choose_target_city_falls_back_to_nearest_when_the_current_pursuit_no_longer_exists():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(1, 0), player, "Sobrevivente")
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.current_target_city_coord = Vector2i(99, 99) # "cidade" que nao existe mais na lista

	var chosen := event._choose_target_city([player])

	assert_eq(chosen, city, "perseguicao invalida deveria cair pro fallback de mais proxima, nunca travar retornando null")

## Integracao real (nao so' _choose_target_city isolado): raidar A de
## verdade, atraves de um tick de advance_turn(), deveria mudar a proxima
## escolha pra B.
func test_active_pursues_a_different_city_after_one_successful_raid_when_an_alternative_is_closer():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	var city_a := grid.found_city(origin + Vector2i(1, 0), player, "A") # adjacente ao spawn
	var city_b := grid.found_city(origin + Vector2i(1, -1), player, "B") # tambem adjacente ao spawn
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])

	event.advance_turn(grid, [player]) # raida a primeira escolha (A, empate de distancia desfeito pela ordem)
	assert_eq(event.last_raided_city_coord, city_a.coord, "pre-condicao: A foi a primeira raidada")

	var chosen := event._choose_target_city([player])
	assert_eq(chosen, city_b, "A acabou de ser raidada -- B (tambem adjacente) deveria ser a proxima escolha")

## --- 5B.3-G: cobertura continental (Blocker #3 revisado DE NOVO) ----------
## Pedido do usuario apos o playtest de ponta a ponta: "o Dragao e' uma
## ameaca CONTINENTAL" -- a garantia antiga ("civ anunciada sempre a
## primeira raidada, trava nela ate' devastar") deixou de existir: "a ordem
## NAO deve ser fixa". No lugar, toda civ VIVA precisa ser visitada
## ~CIV_VISIT_TARGET vezes antes do evento poder terminar por "devastated"
## -- _choose_target_city prioriza civs com MENOS visitas, desempatando por
## distancia.

func test_choose_target_city_prefers_an_unvisited_civ_over_a_closer_already_visited_one():
	var grid := _make_hex_grid(6)
	var visited_civ := PlayerData.new(CivilizationData.new())
	var unvisited_civ := PlayerData.new(CivilizationData.new())
	grid.found_city(Vector2i(1, 0), visited_civ, "Ja Visitada") # mais perto
	var unvisited_city := grid.found_city(Vector2i(4, 0), unvisited_civ, "Nunca Visitada") # mais longe
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.civ_visits = {0: 1} # visited_civ ja tem 1/CIV_VISIT_TARGET, unvisited_civ tem 0

	var chosen := event._choose_target_city([visited_civ, unvisited_civ])

	assert_eq(chosen, unvisited_city, "civ com MENOS visitas tem prioridade, mesmo com uma cidade mais proxima pertencendo a uma civ ja tocada")

func test_choose_target_city_returns_to_any_city_once_every_living_civ_reached_the_visit_target():
	var grid := _make_hex_grid(6)
	var civ_a := PlayerData.new(CivilizationData.new())
	var civ_b := PlayerData.new(CivilizationData.new())
	var city_a := grid.found_city(Vector2i(1, 0), civ_a, "A") # mais perto
	grid.found_city(Vector2i(4, 0), civ_b, "B")
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.civ_visits = {0: DragonEvent.CIV_VISIT_TARGET, 1: DragonEvent.CIV_VISIT_TARGET}

	var chosen := event._choose_target_city([civ_a, civ_b])

	assert_eq(chosen, city_a, "depois que TODAS as civs vivas atingiram o alvo de visitas, a busca volta a ser so' 'mais proxima'")

func test_choose_target_city_ignores_a_dead_civ_with_no_cities_when_computing_coverage_priority():
	var grid := _make_hex_grid(6)
	var living_civ := PlayerData.new(CivilizationData.new())
	var dead_civ := PlayerData.new(CivilizationData.new()) # sem cidade nenhuma -- eliminada
	var only_city := grid.found_city(Vector2i(1, 0), living_civ, "Unica")
	var event := DragonEvent.new()
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")

	var chosen := event._choose_target_city([living_civ, dead_civ])

	assert_eq(chosen, only_city, "civ sem cidade nenhuma nunca deveria contar como 'nao coberta' nem travar a busca")

## Integracao real de ponta a ponta: com 2 civs de 1 cidade cada, o Dragao
## precisa tocar AS DUAS ate' o alvo de visitas antes de desaparecer, nunca
## martelar so' uma delas (bug original relatado pelo usuario, agora
## generalizado pra cobertura continental: "causa dano na cidade ate' ela
## ficar low ou zerada e o dragao desaparece ao inves de... ir pra outros
## alvos").
func test_active_covers_both_civs_up_to_the_visit_target_before_devastation_ends_the_event():
	var grid := _make_hex_grid(8)
	var civ_a := PlayerData.new(CivilizationData.new())
	var civ_b := PlayerData.new(CivilizationData.new())
	var city_a := grid.found_city(Vector2i(1, 0), civ_a, "Capital A")
	city_a.population = 1
	city_a.hp = city_a.max_hp()
	var city_b := grid.found_city(Vector2i(4, 0), civ_b, "Capital B")
	city_b.population = 1
	city_b.hp = city_b.max_hp()
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var players: Array[PlayerData] = [civ_a, civ_b]
	_advance_to_active(event, grid, players)

	for turn in range(60):
		event.dragon_unit.reset_movement() # GameManager._on_turn_changed faz isto todo turno de verdade
		event.advance_turn(grid, players)
		if event.phase == WorldEvent.PHASE_RESOLUTION or event.phase == WorldEvent.PHASE_COMPLETED:
			break

	assert_eq(event.result.get("outcome"), "devastated", "com as duas civs cobertas, o evento deveria terminar por devastacao, nao travar")
	assert_eq(event.civ_visits.get(0, 0), DragonEvent.CIV_VISIT_TARGET, "civ A precisa ter recebido exatamente o alvo de visitas")
	assert_eq(event.civ_visits.get(1, 0), DragonEvent.CIV_VISIT_TARGET, "civ B precisa ter recebido exatamente o alvo de visitas -- nunca ficar de fora")

## --- Nenhum desaparecimento silencioso (item 8/9) --------------------------
## O FSM ja transicionava certo pra Resolution/Completed -- o problema
## reportado pelo usuario era a AUSENCIA de qualquer aviso alem do texto de
## 1-tick do Event Tracker. Todo desfecho agora precisa emitir um toast
## CLARAMENTE distinguivel (_resolve_with_outcome/_outcome_message).

## 5B.3-G: o playtest revelou que o toast de 1-tick era UX fraca demais pra
## um evento continental de varios turnos -- "o jogador viu apenas um texto
## minusculo e interpretou como bug/desaparecimento". _resolve_with_outcome
## deixou de emitir EventBus.notify pro desfecho -- vira um MODAL bloqueante
## em HUD (ver test_hud.gd), disparado pela transicao de fase (world_event_
## phase_changed, ja emitida por WorldEventManager.advance_turn de graca).
## Estes testes confirmam a AUSENCIA do toast dedicado, nunca a presenca.

func test_defeated_outcome_sets_result_without_emitting_a_toast():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	watch_signals(EventBus)

	event.advance_turn(null, []) # dragon_unit ainda null -> "defeated"

	assert_eq(event.result.get("outcome"), "defeated")
	assert_signal_not_emitted(EventBus, "notify", "resultado do Dragao agora e' MODAL (HUD), nunca mais toast")

func test_no_target_outcome_sets_result_without_emitting_a_toast():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new()) # sem cidade nenhuma
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	_advance_to_active(event, grid, [player])
	watch_signals(EventBus)

	event.advance_turn(grid, [player])

	assert_eq(event.result.get("outcome"), "no_target")
	assert_signal_not_emitted(EventBus, "notify", "resultado do Dragao agora e' MODAL (HUD), nunca mais toast")

func test_devastated_outcome_sets_result_without_emitting_a_dedicated_toast():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var origin := Vector2i(0, 0)
	grid.found_city(origin + Vector2i(1, 0), player, "Alvo")
	var event := DragonEvent.new()
	event.origin_region = origin
	_advance_to_active(event, grid, [player])
	for i in range(DragonEvent.CIV_VISIT_TARGET - 1):
		event.dragon_unit.reset_movement()
		event.advance_turn(grid, [player])
	watch_signals(EventBus)

	event.advance_turn(grid, [player]) # o raid final, atinge o alvo de visitas

	assert_eq(event.result.get("outcome"), "devastated")
	# O raid em si ainda emite seu aviso informativo de dano generico ("Seu
	# Dragao enfraqueceu Alvo!", CombatResolver -- inalterado) -- so' o
	# toast ESPECIFICO de desfecho ("devastou"/"saciado") precisa ter
	# desaparecido daqui em diante.
	for i in range(get_signal_emit_count(EventBus, "notify")):
		var params = get_signal_parameters(EventBus, "notify", i)
		assert_false("devastou" in String(params[0]).to_lower(), "nao deveria mais existir um toast dedicado de devastacao -- isso agora e' um MODAL")

func test_defeated_and_devastated_modal_messages_are_distinguishable_from_each_other():
	assert_ne(DragonEvent._outcome_message("defeated"), DragonEvent._outcome_message("devastated"))
	assert_ne(DragonEvent._outcome_message("defeated"), DragonEvent._outcome_message("no_target"))
	assert_ne(DragonEvent._outcome_message("devastated"), DragonEvent._outcome_message("no_target"))

## --- Persistencia da exclusao de alvo (item 12) ---------------------------

func test_to_save_dict_and_from_save_dict_round_trip_last_raided_city():
	var event := DragonEvent.new()
	event.last_raided_city_coord = Vector2i(7, -2)

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.last_raided_city_coord, Vector2i(7, -2))

func test_from_save_dict_defaults_last_raided_city_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({})
	assert_eq(event.last_raided_city_coord, DragonEvent.NO_COORD)

## Continuar Active depois de um save/load sem perder o estado que importa
## pra escolha de alvo -- exatamente o cenario que save/load precisa
## suportar (item 12/13 do pedido do usuario).
func test_reconstructed_event_continues_excluding_the_last_raided_city_after_load():
	var grid := _make_hex_grid(6)
	var player := PlayerData.new(CivilizationData.new())
	var city_a := grid.found_city(Vector2i(1, 0), player, "A")
	var city_b := grid.found_city(Vector2i(2, 0), player, "B")
	grid.spawn_monster_at(Vector2i(0, 0), "dragon")

	var original := DragonEvent.new()
	original.phase = WorldEvent.PHASE_ACTIVE
	original.target_civ_index = 0
	original.spawn_coord = Vector2i(0, 0)
	original.last_raided_city_coord = city_a.coord

	var saved := original.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	loaded.relink_unit(grid)

	var chosen := loaded._choose_target_city([player])

	assert_eq(chosen, city_b, "depois do load, a exclusao da ultima cidade raidada deveria continuar valendo")
