extends GutTest

## Cobre DragonEvent: skeleton generico (FSM/persistencia/determinismo,
## Step 5A), Blocker #1 (identidade/origem/spawn, Step 5B.1), e agora o
## primeiro vertical slice jogavel (Step 5B.2, docs/DRAGON_EVENT_DESIGN.md)
## -- Announced e Preparation com comportamento real (alvo travado, prazo
## de turnos de verdade), valores deliberadamente PROVISORIOS. Active/
## Resolution continuam o skeleton da 5A (5B.3/5B.4 substituem depois).
## Trigger/spawn em si (WorldEventTrigger) tem seu proprio arquivo de
## teste; participacao (RivalAI/GameManager) tambem tem os seus.

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

func before_each():
	_original_turn_number = TurnManager.turn_number
	_created_cities = []

func after_each():
	TurnManager.turn_number = _original_turn_number
	for city in _created_cities:
		if is_instance_valid(city):
			city.queue_free()

func _make_city(coord: Vector2i) -> City:
	var city := City.new()
	city.coord = coord
	_created_cities.append(city)
	return city

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
	var event := DragonEvent.new()
	event.origin_region = Vector2i(0, 0)
	var players: Array[PlayerData] = []
	event.advance_turn(null, players) # -> Announced
	event.advance_turn(null, players) # -> Preparation, deadline = 13

	for turn in range(11, DragonEvent.PREPARATION_DURATION_TURNS + 11):
		TurnManager.turn_number = turn
		event.advance_turn(null, players)
		assert_eq(event.phase, WorldEvent.PHASE_PREPARATION, "turno %d ainda deveria estar dentro do prazo (deadline=%d)" % [turn, event.turn_deadline])

	TurnManager.turn_number = event.turn_deadline + 1
	event.advance_turn(null, players)
	assert_eq(event.phase, WorldEvent.PHASE_ACTIVE)

## Active/Resolution continuam o skeleton da 5A (sem efeito sobre o mundo)
## ate 5B.3/5B.4 existirem.
func test_active_and_resolution_still_advance_one_phase_per_call_as_a_skeleton():
	TurnManager.turn_number = 10
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE

	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_RESOLUTION)

	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)

func test_advance_turn_does_nothing_once_completed():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_COMPLETED
	event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)
	assert_true(event.is_completed())

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
