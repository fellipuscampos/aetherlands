extends GutTest

## Fase 33D1 — núcleo das três eras do mundo: regras puras (WorldPhaseRules), estado/histórico no
## WorldEventManager, sinal único, save/load e migração de save antigo, Event Center, Attention e o rótulo
## "T62 · Ascensão" na barra global.

const SMALL_MAP := 61
const SAVE_PATH := "user://test_phase33d1_world_phase.json"

var _original := {}
var _cities: Array[City] = []
var _signals: Array = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	_signals.clear()
	WorldEventManager.reset_for_new_match()
	if not EventBus.world_phase_changed.is_connected(_on_phase_changed):
		EventBus.world_phase_changed.connect(_on_phase_changed)

func after_each():
	if EventBus.world_phase_changed.is_connected(_on_phase_changed):
		EventBus.world_phase_changed.disconnect(_on_phase_changed)
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	SaveManager.delete_save(SAVE_PATH)
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)

func _on_phase_changed(old_phase: int, new_phase: int, turn: int, cause: String) -> void:
	_signals.append({"old": old_phase, "new": new_phase, "turn": turn, "cause": cause})

func _civ(city_count: int, n9: bool = false, capstone: bool = false) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = "Civ %d" % _cities.size()
	var player := PlayerData.new(civ)
	for i in city_count:
		var city := City.new()
		_cities.append(city)
		player.cities.append(city)
	if n9 or capstone:
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	if capstone:
		player.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
		assert_true(player.v2_research.complete_research(V2ResearchDatabase.SUPREME_ARMY_ID))
	return player

func _eliminated() -> PlayerData:
	return PlayerData.new(CivilizationData.new())

# --- Regras puras --------------------------------------------------------------------------------

func test_foundation_to_ascension_rules():
	var F := WorldPhaseRules.Phase.FOUNDATION
	var four := [_civ(2), _civ(2), _civ(2), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(F, 34, four), {}, "T34: piso não atingido")
	var one := [_civ(2), _civ(1), _civ(1), _civ(1)]
	assert_eq(WorldPhaseRules.next_transition(F, 35, one), {}, "T35 com só 1 civ expandida")
	var two := [_civ(2), _civ(3), _civ(1), _civ(1)]
	assert_eq(WorldPhaseRules.next_transition(F, 35, two), {"phase": WorldPhaseRules.Phase.ASCENSION, "cause": "PROGRESS"})
	assert_eq(WorldPhaseRules.next_transition(F, 69, one), {}, "sem progresso antes do fallback")
	assert_eq(WorldPhaseRules.next_transition(F, 70, one), {"phase": WorldPhaseRules.Phase.ASCENSION, "cause": "FALLBACK"})

func test_ascension_to_convergence_rules():
	var A := WorldPhaseRules.Phase.ASCENSION
	var many_n9 := [_civ(2, true), _civ(2, true), _civ(2, true), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(A, 99, many_n9), {}, "T99: piso não atingido")
	var one_n9 := [_civ(2, true), _civ(2), _civ(2), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(A, 100, one_n9), {}, "1 N9 não basta")
	var two_n9 := [_civ(2, true), _civ(2, true), _civ(2), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(A, 100, two_n9), {"phase": WorldPhaseRules.Phase.CONVERGENCE, "cause": "PROGRESS"})
	var capstone := [_civ(2, false, true), _civ(2), _civ(2), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(A, 100, capstone), {"phase": WorldPhaseRules.Phase.CONVERGENCE, "cause": "PROGRESS"}, "um capstone sozinho basta")
	var none := [_civ(2), _civ(2), _civ(2), _civ(2)]
	assert_eq(WorldPhaseRules.next_transition(A, 149, none), {})
	assert_eq(WorldPhaseRules.next_transition(A, 150, none), {"phase": WorldPhaseRules.Phase.CONVERGENCE, "cause": "FALLBACK"})
	assert_eq(WorldPhaseRules.next_transition(WorldPhaseRules.Phase.CONVERGENCE, 999, none), {}, "Convergência é a última era")

func test_two_active_civs_both_must_satisfy_but_capstone_still_counts():
	var F := WorldPhaseRules.Phase.FOUNDATION
	var A := WorldPhaseRules.Phase.ASCENSION
	assert_eq(WorldPhaseRules.next_transition(F, 40, [_civ(2), _civ(1), _eliminated(), _eliminated()]), {}, "com 2 ativas, as duas precisam de 2 cidades")
	assert_eq(int(WorldPhaseRules.next_transition(F, 40, [_civ(2), _civ(2), _eliminated(), _eliminated()]).phase), WorldPhaseRules.Phase.ASCENSION)
	assert_eq(WorldPhaseRules.next_transition(A, 110, [_civ(2, true), _civ(2), _eliminated(), _eliminated()]), {}, "com 2 ativas, as duas precisam de N9")
	assert_eq(int(WorldPhaseRules.next_transition(A, 110, [_civ(2, false, true), _civ(2), _eliminated(), _eliminated()]).phase), WorldPhaseRules.Phase.CONVERGENCE, "capstone continua valendo")

func test_reconstruct_picks_the_most_advanced_justified_phase():
	assert_eq(WorldPhaseRules.reconstruct(20, [_civ(3), _civ(3)]), WorldPhaseRules.Phase.FOUNDATION)
	assert_eq(WorldPhaseRules.reconstruct(80, [_civ(1), _civ(1)]), WorldPhaseRules.Phase.ASCENSION)
	assert_eq(WorldPhaseRules.reconstruct(120, [_civ(2, true), _civ(2, true), _civ(1)]), WorldPhaseRules.Phase.CONVERGENCE)

# --- Estado no WorldEventManager -----------------------------------------------------------------

func test_single_transition_signal_history_and_no_regression():
	var players: Array[PlayerData] = [_civ(2), _civ(2), _civ(1), _civ(1)]
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.FOUNDATION, "partida nova nasce no Despertar")
	assert_false(WorldEventManager.advance_world_phase(players, 30))
	assert_true(WorldEventManager.advance_world_phase(players, 46))
	assert_false(WorldEventManager.advance_world_phase(players, 47), "sem alerta repetido")
	assert_eq(_signals.size(), 1)
	assert_eq(_signals[0], {"old": WorldPhaseRules.Phase.FOUNDATION, "new": WorldPhaseRules.Phase.ASCENSION, "turn": 46, "cause": "PROGRESS"})
	assert_eq(WorldEventManager.phase_history.size(), 2)
	assert_eq(WorldEventManager.phase_history[0].cause, "INITIAL")
	assert_eq(int(WorldEventManager.phase_history[1].turn), 46)
	# Eliminar civs nunca devolve o mundo à era anterior.
	for player in players:
		player.cities.clear()
	assert_false(WorldEventManager.advance_world_phase(players, 60))
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.ASCENSION)

func test_no_gameplay_rule_reads_the_world_phase():
	# A era é contexto de ritmo: nenhum script de regra (combate, economia, cidade, unidade, mundo, IA)
	# consulta o estado da era — só WorldEventManager (dono), UI e telemetria. Fase 33D2: a única exceção
	# é RegionalThreatSystem, onde a era decide só o comportamento dos MONSTROS regionais (teatro no
	# Despertar); nenhum bônus/custo de civilização depende dela. V3 / Combat Ecology (Etapa 1): a era passa
	# a mudar a ATIVIDADE dos monstros da ecologia (MonsterActivityProfile/MonsterEcologySystem) — de novo só
	# comportamento neutro e peso de reposição, nunca bônus de civilização.
	var readers: Array[String] = []
	for dir_path in ["res://scripts/core", "res://scripts/city", "res://scripts/units", "res://scripts/world"]:
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".gd") or file_name in ["WorldPhaseRules.gd", "RegionalThreatSystem.gd", "MonsterActivityProfile.gd", "MonsterEcologySystem.gd"]:
				continue
			var source := FileAccess.get_file_as_string("%s/%s" % [dir_path, file_name])
			if source.contains("world_phase") or source.contains("WorldPhaseRules"):
				readers.append(file_name)
	assert_eq(readers, [] as Array[String], "nenhuma regra de jogo depende da era (sem bônus)")

func test_world_state_round_trips_in_every_phase():
	for phase in [WorldPhaseRules.Phase.FOUNDATION, WorldPhaseRules.Phase.ASCENSION, WorldPhaseRules.Phase.CONVERGENCE]:
		WorldEventManager.reset_for_new_match()
		WorldEventManager.world_phase = phase
		WorldEventManager.phase_history = [
			{"phase": WorldPhaseRules.Phase.FOUNDATION, "turn": 1, "cause": "INITIAL"},
			{"phase": phase, "turn": 50 + phase, "cause": "FALLBACK" if phase == WorldPhaseRules.Phase.CONVERGENCE else "PROGRESS"},
		]
		WorldEventManager.completed_event_types = {"dragon": 1}
		var saved: Dictionary = JSON.parse_string(JSON.stringify(WorldEventManager.to_save_dict()))
		WorldEventManager.reset_for_new_match()
		WorldEventManager.from_save_dict(saved)
		assert_eq(WorldEventManager.world_phase, phase)
		assert_eq(WorldEventManager.phase_history.size(), 2)
		assert_eq(String(WorldEventManager.phase_history[1].cause), "FALLBACK" if phase == WorldPhaseRules.Phase.CONVERGENCE else "PROGRESS")
		assert_eq(WorldEventManager.completed_event_types, {"dragon": 1})
	assert_true(_signals.is_empty(), "load nunca dispara transição")

func test_real_save_load_and_old_save_migration():
	var config := BalanceSeedSet.match_config(1, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	var grid := BalanceMatchRunner.setup_match(self, config)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	WorldEventManager.phase_history.append({"phase": WorldPhaseRules.Phase.ASCENSION, "turn": 1, "cause": "PROGRESS"})
	WorldEventManager.completed_event_types = {"dragon": 1}
	# Covis conhecidos são derivados de explored_tiles (já salvo): nenhum campo novo precisa persistir.
	assert_false(grid.lair_coords.is_empty(), "mapa de teste com covis")
	var known_lair: Vector2i = grid.lair_coords[0]
	GameManager.players[1].explored_tiles[known_lair] = true
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_eq(int(data.version), SaveManager.SAVE_VERSION, "save grava a versão atual (D1: 22; D2: 23)")
	assert_true(21 in SaveManager.MIGRATABLE_SAVE_VERSIONS and 22 in SaveManager.MIGRATABLE_SAVE_VERSIONS, "saves 21 e 22 continuam migráveis")
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(grid, SAVE_PATH))
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.Phase.ASCENSION, "era restaurada")
	assert_eq(WorldEventManager.phase_history.size(), 2)
	assert_eq(WorldEventManager.completed_event_types, {"dragon": 1}, "Dragão concluído sobrevive ao load")
	assert_true(V2AIWorldView.capture(GameManager.players[1], grid).is_lair_known(known_lair), "covil conhecido continua conhecido após o load")
	# Save antigo (v21): sem estado de mundo -> era reconstruída pelo estado, sem sinal nem recompensa.
	data.version = 21
	for key in ["world_phase", "phase_history", "completed_event_types"]:
		data.world_events.erase(key)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_signals.clear()
	assert_true(SaveManager.load_game(grid, SAVE_PATH), "save v21 continua carregando")
	assert_eq(WorldEventManager.world_phase, WorldPhaseRules.reconstruct(TurnManager.turn_number, GameManager.players))
	assert_eq(WorldEventManager.phase_history.size(), 1)
	assert_eq(String(WorldEventManager.phase_history[0].cause), "MIGRATED")
	assert_eq(WorldEventManager.completed_event_types, {}, "nada inferido")
	assert_true(_signals.is_empty(), "migração não dispara era retroativa")
	await BalanceMatchRunner.teardown_match(self, grid)

# --- Apresentação --------------------------------------------------------------------------------

func test_phase_change_publishes_one_world_event_and_no_attention():
	var player := _civ(2)
	var attention := AttentionService.new()
	attention.bind_player(player)
	var required_before := attention.required_items().size()
	# Captura pelo sinal (o histórico do Event Center tem teto e pode estar cheio na suíte completa).
	var collected: Array = []
	var collect := func(event: UIEventData): collected.append(event)
	UIEvents.event_published.connect(collect)
	var players: Array[PlayerData] = [player, _civ(2)]
	assert_true(WorldEventManager.advance_world_phase(players, 40))
	WorldEventManager.advance_world_phase(players, 41)
	UIEvents.event_published.disconnect(collect)
	var published: Array = collected.filter(func(e): return e.event_type == "world_phase_changed")
	assert_eq(published.size(), 1, "um único evento WORLD por transição")
	var event: UIEventData = published[0]
	assert_eq(event.category, UIEventData.Category.WORLD)
	assert_eq(event.severity, UIEventData.Severity.IMPORTANT)
	assert_eq(event.title, "A Era da Ascensão começou")
	assert_true(event.message.begins_with("Os reinos deixaram de ser pequenos enclaves"))
	for forbidden in ["FALLBACK", "PROGRESS", "ASCENSION", "WorldPhase"]:
		assert_false((event.title + event.message).contains(forbidden), "sem termo interno: %s" % forbidden)
	attention.refresh()
	assert_eq(attention.required_items().size(), required_before, "era nunca é Attention Required")
	attention.dispose()

func test_global_bar_shows_turn_and_era_without_clipping_at_1280():
	var shell := (load("res://scenes/ui/UIShell.tscn") as PackedScene).instantiate() as UIShell
	add_child_autofree(shell)
	shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shell.size = Vector2(1280, 720)
	TurnManager.turn_number = 62
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	shell.global_bar.refresh(null)
	var label: Label = shell.global_bar._labels.turn
	assert_eq(label.text, "T62 · Ascensão")
	assert_eq(label.tooltip_text, "Turno 62 · Era da Ascensão")
	for compact in [false, true]:
		shell.global_bar.set_compact(compact)
		shell.apply_viewport_size(Vector2(1280, 720))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_gte(label.size.x + 0.5, label.get_minimum_size().x, "rótulo de turno/era sem corte (compact=%s)" % compact)
		assert_lte(shell.global_bar.get_combined_minimum_size().x, 1280.0, "barra cabe em 1280 (compact=%s)" % compact)
	WorldEventManager.world_phase = WorldPhaseRules.Phase.CONVERGENCE
	EventBus.world_phase_changed.emit(WorldPhaseRules.Phase.ASCENSION, WorldPhaseRules.Phase.CONVERGENCE, 62, "PROGRESS")
	assert_eq(label.text, "T62 · Convergência", "rótulo atualiza no sinal de era")

# --- Performance ---------------------------------------------------------------------------------

func test_phase_rule_and_known_lair_query_are_cheap():
	var players: Array[PlayerData] = [_civ(3, true), _civ(2, true), _civ(2), _civ(1)]
	var iterations := 2000
	var started := Time.get_ticks_usec()
	for i in iterations:
		WorldPhaseRules.next_transition(WorldPhaseRules.Phase.ASCENSION, 149, players)
	var phase_us := float(Time.get_ticks_usec() - started) / iterations
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-20, 21):
		for r in range(-20, 21):
			if absi(q + r) <= 20:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var known := {}
	for i in 16:
		var lair := Vector2i(-18 + i * 2, (i % 5) - 2)
		grid.lair_coords.append(lair)
		grid.lair_kind_by_coord[lair] = "goblin"
		if i % 2 == 0:
			known[lair] = true
	started = Time.get_ticks_usec()
	for i in iterations:
		grid.get_lair_danger_at(Vector2i(i % 30 - 15, 0), known)
	var lair_us := float(Time.get_ticks_usec() - started) / iterations
	grid.free()
	print("[phase33d1-perf] next_transition=%.2f us/call known_lair_danger=%.2f us/call" % [phase_us, lair_us])
	assert_lt(phase_us, 1000.0, "avaliação de era << 1 ms por rodada")
	assert_lt(lair_us, 200.0, "consulta de covil conhecido sem varrer o mapa")
