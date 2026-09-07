extends GutTest

## Cobre DragonEvent: o skeleton generico (FSM/persistencia/determinismo,
## Step 5A) e, a partir daqui, o Blocker #1 do contrato comportamental
## (docs/DRAGON_EVENT_DESIGN.md) -- identidade e a distincao origin_region
## (publica desde Announced) vs. spawn_coord (so sorteado na transicao pra
## Active, ainda nao implementado -- fica NO_COORD ate o Blocker #3/5B.3
## existir). Trigger/spawn em si (WorldEventTrigger) tem seu proprio
## arquivo de teste.

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

func test_new_dragon_event_has_event_type_dragon():
	var event := DragonEvent.new()
	assert_eq(event.event_type, DragonEvent.EVENT_TYPE)
	assert_eq(event.event_type, "dragon")

func test_new_dragon_event_starts_dormant_with_no_region_or_spawn_coord():
	var event := DragonEvent.new()
	assert_eq(event.phase, WorldEvent.PHASE_DORMANT)
	assert_eq(event.origin_region, DragonEvent.NO_COORD)
	assert_eq(event.spawn_coord, DragonEvent.NO_COORD, "tile exato so deveria existir a partir da transicao pra Active (Blocker #3/5B.3, ainda nao implementado)")

## Skeleton: cada chamada avanca EXATAMENTE uma fase da ordem fixa, sem
## pular nem repetir -- prova o FSM inteiro fim-a-fim com um tipo real.
func test_advance_turn_walks_through_every_phase_in_order():
	var event := DragonEvent.new()
	var expected_order := [
		WorldEvent.PHASE_ANNOUNCED,
		WorldEvent.PHASE_PREPARATION,
		WorldEvent.PHASE_ACTIVE,
		WorldEvent.PHASE_RESOLUTION,
		WorldEvent.PHASE_COMPLETED,
	]
	for expected_phase in expected_order:
		event.advance_turn(null, [])
		assert_eq(event.phase, expected_phase)

func test_advance_turn_does_nothing_once_completed():
	var event := DragonEvent.new()
	for i in range(WorldEvent.PHASES.size()): # avanca ate Completed e alem
		event.advance_turn(null, [])
	assert_eq(event.phase, WorldEvent.PHASE_COMPLETED)
	assert_true(event.is_completed())

## --- Persistencia (contrato, secao 3) ---------------------------------------

func test_to_save_dict_and_from_save_dict_round_trip_region_and_spawn_coord():
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.origin_region = Vector2i(7, -3)
	event.spawn_coord = Vector2i(8, -2)

	var saved := event.to_save_dict()
	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.phase, WorldEvent.PHASE_ACTIVE)
	assert_eq(loaded.origin_region, Vector2i(7, -3))
	assert_eq(loaded.spawn_coord, Vector2i(8, -2))

func test_from_save_dict_defaults_region_and_spawn_coord_when_missing():
	var event := DragonEvent.new()
	event.from_save_dict({}) # simula um dict incompleto/de outro tipo de evento
	assert_eq(event.origin_region, DragonEvent.NO_COORD)
	assert_eq(event.spawn_coord, DragonEvent.NO_COORD)

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
