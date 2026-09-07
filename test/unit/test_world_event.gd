extends GutTest

## Cobre WorldEvent (docs/WORLD_EVENT_CONTRACT.md): a classe BASE do ciclo
## de vida generico de eventos mundiais -- fases, save/load minimo, e o RNG
## proprio do sistema de eventos (independente do RNG global de IA).
## Nenhum evento concreto (DragonEvent) existe ainda -- ver contrato,
## ordem de implementacao: WorldEvent -> WorldEventManager -> persistencia
## -> testes -> DragonEvent.

func test_new_event_starts_dormant():
	var event := WorldEvent.new()
	assert_eq(event.phase, WorldEvent.PHASE_DORMANT)

func test_is_completed_false_by_default():
	var event := WorldEvent.new()
	assert_false(event.is_completed())

func test_is_completed_true_when_phase_is_completed():
	var event := WorldEvent.new()
	event.phase = WorldEvent.PHASE_COMPLETED
	assert_true(event.is_completed())

## Base nao e pensada pra uso direto como evento de verdade, mas nao deve
## travar se chamada -- garante que subclasses que esquecerem de
## sobrescrever advance_turn() falham por INACAO (evento nunca avanca),
## nunca por erro de execucao.
func test_advance_turn_on_base_class_does_nothing_and_does_not_crash():
	var event := WorldEvent.new()
	var players: Array[PlayerData] = []
	event.advance_turn(null, players)
	assert_eq(event.phase, WorldEvent.PHASE_DORMANT, "base nao muda fase nenhuma sozinha")

func test_to_save_dict_round_trips_all_base_fields():
	var event := WorldEvent.new()
	event.event_id = 7
	event.event_type = "test_stub"
	event.phase = WorldEvent.PHASE_ACTIVE
	event.turn_started = 12
	event.turn_deadline = 20
	event.participants = {0: {"decision": "joined"}, 2: {"decision": "declined"}}
	event.result = {"outcome": "success"}

	var saved := event.to_save_dict()
	var loaded := WorldEvent.new()
	loaded.from_save_dict(saved)

	assert_eq(loaded.event_id, 7)
	assert_eq(loaded.event_type, "test_stub")
	assert_eq(loaded.phase, WorldEvent.PHASE_ACTIVE)
	assert_eq(loaded.turn_started, 12)
	assert_eq(loaded.turn_deadline, 20)
	assert_eq(loaded.participants, {0: {"decision": "joined"}, 2: {"decision": "declined"}})
	assert_eq(loaded.result, {"outcome": "success"})

## Fallback pra save antigo/incompleto (contrato, "Persistencia" ->
## "Fallback/teste de saves antigos") -- um dict vazio nunca deveria travar
## a reconstrucao, so cair nos defaults seguros da classe.
func test_from_save_dict_defaults_missing_fields_safely():
	var event := WorldEvent.new()
	event.from_save_dict({})

	assert_eq(event.event_id, -1)
	assert_eq(event.event_type, "")
	assert_eq(event.phase, WorldEvent.PHASE_DORMANT)
	assert_eq(event.turn_started, -1)
	assert_eq(event.turn_deadline, -1)
	assert_eq(event.participants, {})
	assert_eq(event.result, {})

## --- event_rng (contrato, secao 4: determinismo) -------------------------

func test_event_rng_is_deterministic_for_the_same_inputs():
	var event := WorldEvent.new()
	event.event_id = 3
	var first := event.event_rng(12345, 10).randi()
	var second := event.event_rng(12345, 10).randi()
	assert_eq(first, second, "mesmo map_seed+event_id+turno deveria sempre produzir o mesmo primeiro roll")

func test_event_rng_differs_when_turn_differs():
	var event := WorldEvent.new()
	event.event_id = 3
	var turn_10 := event.event_rng(12345, 10).randi()
	var turn_11 := event.event_rng(12345, 11).randi()
	assert_ne(turn_10, turn_11, "turnos diferentes deveriam produzir sequencias diferentes")

func test_event_rng_differs_when_event_id_differs():
	var event_a := WorldEvent.new()
	event_a.event_id = 1
	var event_b := WorldEvent.new()
	event_b.event_id = 2
	assert_ne(event_a.event_rng(12345, 10).randi(), event_b.event_rng(12345, 10).randi(), "dois eventos diferentes no mesmo turno nao deveriam compartilhar a mesma sequencia")

func test_event_rng_differs_when_map_seed_differs():
	var event := WorldEvent.new()
	event.event_id = 3
	assert_ne(event.event_rng(111, 10).randi(), event.event_rng(222, 10).randi(), "mapas diferentes nao deveriam compartilhar a mesma sequencia de evento")

## O requisito mais importante do contrato: o RNG de evento NUNCA deveria
## ser afetado por quanto o RNG global (o mesmo que RivalAI.decide_war/
## decide_trade consome) ja rodou antes -- consumir numeros do RNG global
## nao pode mudar o proximo roll de evento, senao uma decisao de IA sem
## nenhuma relacao com o evento mudaria o resultado dele.
func test_event_rng_is_independent_of_global_rng_state():
	var event := WorldEvent.new()
	event.event_id = 5
	var baseline := event.event_rng(999, 42).randi()

	randomize()
	for i in range(50):
		randi() # simula RivalAI consumindo o RNG global normalmente

	var after_global_rng_usage := event.event_rng(999, 42).randi()
	assert_eq(baseline, after_global_rng_usage, "consumir o RNG global nao deveria alterar o roll do RNG proprio do evento")
