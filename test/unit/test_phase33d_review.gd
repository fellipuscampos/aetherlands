extends GutTest

## Fase 33D-R — regressões das correções da revisão pós-implementação da camada de Strategic Pacing &
## Objectives (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md, "F33D Post-Implementation Review").

var _original := {}
var grid: HexGrid
var players: Array[PlayerData] = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()

func after_each():
	for event in WorldEventManager.active_events:
		if event is ReliquaryEvent:
			(event as ReliquaryEvent)._remove_marker()
	for player in players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

## Mesmo mundo manual dos testes D3: 4 civs com duas cidades, Ascensão desde `ascension`.
func _world(ascension: int, map_seed: int = 1) -> void:
	grid = HexGrid.new()
	grid._ready()
	grid.map_seed = map_seed
	for q in range(-22, 23):
		for r in range(-22, 23):
			if absi(q + r) <= 22:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	players = [_player("Aurora"), _player("Brasa"), _player("Cinza"), _player("Dunas")] as Array[PlayerData]
	GameManager.players = players
	GameManager.human_player = players[0]
	GameManager.rival_players = [players[1], players[2], players[3]] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.ai_controls_human_seat = true
	var anchors := [Vector2i(-16, 0), Vector2i(16, 0), Vector2i(0, -16), Vector2i(0, 16)]
	for index in players.size():
		for n in 2:
			grid.found_city(anchors[index] + Vector2i(0, 5 * n) * (1 if anchors[index].y <= 0 else -1), players[index], "C%d-%d" % [index, n], true)
	WorldEventManager.reset_for_new_match(1)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": ascension, "cause": "PROGRESS"})

func _seed_without_dragon_roll(from_turn: int, to_turn: int) -> int:
	for candidate in range(1, 5000):
		var hit := false
		for turn in range(from_turn, to_turn + 1):
			if WorldEventTrigger.should_spawn_dragon(candidate, turn):
				hit = true
				break
		if not hit:
			return candidate
	return -1

func _round(turn: int) -> void:
	TurnManager.turn_number = turn
	WorldEventManager.maybe_spawn_dragon(grid, turn)
	WorldEventManager.maybe_start_reliquary(grid, turn)
	WorldEventManager.advance_turn(grid, players)

# --- Relicário × virada para a Convergência -----------------------------------------------------------

func test_dragon_guarantee_deadline_is_the_earlier_of_ascension_35_and_the_convergence_floor():
	_world(40)
	assert_eq(WorldEventManager.dragon_guarantee_deadline(), 40 + WorldEventManager.DRAGON_GUARANTEE_AFTER)
	WorldEventManager.phase_history[-1].turn = 68
	assert_eq(WorldEventManager.dragon_guarantee_deadline(), WorldPhaseRules.CONVERGENCE_FLOOR_TURN, "Ascensão tardia: a Convergência pode chegar antes de +35")

## Sem a correção: Ascensão no T68, Relicário anunciado no T83 (83+18 < 103) e ainda ativo quando a Convergência
## chega no piso (T100) — o Dragão pendente era SUPERSEDED pela exclusividade, nunca acontecia na partida.
func test_pre_dragon_reliquary_never_occupies_the_convergence_edge():
	var asc := 68
	_world(asc, _seed_without_dragon_roll(asc + WorldEventManager.DRAGON_ELIGIBLE_AFTER, WorldPhaseRules.CONVERGENCE_FLOOR_TURN))
	for turn in range(asc + WorldEventManager.DRAGON_ELIGIBLE_AFTER, WorldPhaseRules.CONVERGENCE_FLOOR_TURN):
		_round(turn)
	assert_null(WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE), "não cabe antes da Convergência mais cedo: espera o Dragão")
	assert_true(bool(WorldEventManager.reliquary_schedule.get("waited_for_dragon", false)))
	TurnManager.turn_number = WorldPhaseRules.CONVERGENCE_FLOOR_TURN
	WorldEventManager._close_ascension_events(grid, players, WorldPhaseRules.CONVERGENCE_FLOOR_TURN)
	assert_not_null(WorldEventManager.active_event_of_type(DragonEvent.EVENT_TYPE), "a virada anuncia o Dragão")
	assert_eq(String(WorldEventManager.dragon_schedule.state), WorldEventManager.SCHEDULE_ANNOUNCED)
	assert_eq(String(WorldEventManager.reliquary_schedule.state), WorldEventManager.SCHEDULE_SUPERSEDED)

func test_pre_dragon_reliquary_that_fits_before_the_convergence_floor_still_happens():
	var asc := 66
	_world(asc, _seed_without_dragon_roll(asc + WorldEventManager.DRAGON_ELIGIBLE_AFTER, WorldPhaseRules.CONVERGENCE_FLOOR_TURN))
	for turn in range(asc + WorldEventManager.DRAGON_ELIGIBLE_AFTER, asc + WorldEventManager.RELIQUARY_ELIGIBLE_AFTER + 1):
		_round(turn)
	var reliquary := WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE)
	assert_not_null(reliquary, "81 + 18 < 100: cabe inteiro antes da Convergência")
	for turn in range(asc + WorldEventManager.RELIQUARY_ELIGIBLE_AFTER + 1, WorldPhaseRules.CONVERGENCE_FLOOR_TURN):
		_round(turn)
	assert_null(WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE), "terminou antes da virada")
	WorldEventManager._close_ascension_events(grid, players, WorldPhaseRules.CONVERGENCE_FLOOR_TURN)
	assert_not_null(WorldEventManager.active_event_of_type(DragonEvent.EVENT_TYPE), "o Dragão continua garantido")

# --- Dragão: a perseguição respeita a elegibilidade -----------------------------------------------------

func test_dragon_drops_a_chase_when_the_owner_falls_to_one_city():
	_world(40)
	var dragon := DragonEvent.new()
	dragon.dragon_unit = grid.spawn_monster_at(Vector2i(10, 0), "dragon")
	var chased: City = players[1].cities[0]
	dragon.current_target_city_coord = chased.coord
	assert_eq(dragon._choose_target_city(players), chased, "dono elegível: a perseguição continua")
	players[1].cities.erase(players[1].cities[1]) # perdeu a segunda cidade no meio da perseguição
	var retarget := dragon._choose_target_city(players)
	assert_not_null(retarget)
	assert_ne(retarget.owner_player, players[1], "civ com uma cidade nunca é alvo de incursão")
	for other in [players[0], players[2], players[3]]:
		other.cities.resize(1)
	assert_null(dragon._choose_target_city(players), "nenhuma civ elegível: sem alvo (o evento fecha como no_target)")

# --- Ciclo de vida: marcador do Relicário -------------------------------------------------------------

func test_reliquary_marker_never_survives_a_map_reset():
	_world(40)
	var reliquary := ReliquaryEvent.new()
	reliquary.site_coord = Vector2i(0, 0)
	WorldEventManager.register_event(reliquary)
	TurnManager.turn_number = 60
	reliquary.advance_turn(grid, players) # anunciado: marcador público
	var marker := reliquary._marker
	assert_not_null(marker)
	assert_true(marker.is_in_group(HexGrid.WORLD_EVENT_MARKER_GROUP))
	# Novo jogo / load / volta ao menu: o evento é descartado sem _remove_marker; o reset do mapa o limpa.
	WorldEventManager.reset_for_new_match()
	grid.reset_to_empty()
	assert_true(marker.is_queued_for_deletion(), "nenhum pilar fantasma na partida seguinte")
