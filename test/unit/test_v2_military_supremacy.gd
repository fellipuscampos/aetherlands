extends GutTest

## Aetherlands V2, Fase 16 — Supremacia Militar V2 (V2VictoryConditions). Acesso pelo Exército
## Supremo; para CADA rival major: eliminado (mesma definição da Dominação) OU o jogador mantém
## agora uma cidade que era Cidade III+ no instante em que foi capturada daquele rival
## (City.v2_supremacy_captured_from, id estável = índice em GameManager.players). Tudo derivado,
## sem polling; independente da Supremacia V1.5. Save/load em test_save_manager.gd.

const CAPSTONE := "v2_supreme_army"
const ACCESS_ID := "v2_military_supremacy_access"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE

var grid: HexGrid
var human: PlayerData
var a: PlayerData
var b: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_turn: int
var _original_state

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-14, 15):
		for r in range(-14, 15):
			if absi(q + r) <= 14:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	a = _player("Reino A")
	b = _player("Reino B")
	_set_majors([human, a, b])
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, a)
	Diplomacy.declare_war(human, b)
	TurnManager.turn_number = 30

func after_each():
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	GameManager.state = _original_state
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _set_majors(list: Array) -> void:
	var majors: Array[PlayerData] = []
	majors.assign(list)
	GameManager.players = majors
	GameManager.human_player = majors[0]
	var rivals: Array[PlayerData] = []
	rivals.assign(majors.slice(1))
	GameManager.rival_players = rivals

func _grant_access(player: PlayerData) -> void:
	player.v2_research.debug_complete_branch(MILITARY, "guardian")
	player.v2_research.debug_complete_branch(MILITARY, "warrior")
	assert_true(player.v2_research.complete_research(CAPSTONE))
	assert_true(player.has_unlocked(ACCESS_ID))

var _next_coord := 0
func _city_of(owner: PlayerData, level: int) -> City:
	var coord := Vector2i(-9 + (_next_coord % 7) * 3, -6 + (_next_coord / 7) * 4)
	_next_coord += 1
	var city := grid.found_city(coord, owner, "%s %d" % [owner.civ.civ_name, _next_coord], true)
	city.city_level = level
	return city

## Cada rival mantém uma cidade "de reserva" pra não ser eliminado nem disparar a Dominação.
func _keep_alive(player: PlayerData) -> City:
	return _city_of(player, 1)

# --- Acesso ---------------------------------------------------------------------------------------------

func test_without_the_capstone_conquests_never_win():
	_keep_alive(a)
	_keep_alive(b)
	grid.capture_city(_city_of(a, 3), human)
	grid.capture_city(_city_of(b, 3), human)
	var status := V2VictoryConditions.military_supremacy_status(human)
	assert_eq(status.satisfied_count, 2, "o progresso existe")
	assert_false(status.access)
	assert_false(V2VictoryConditions.military_supremacy_achieved(human), "sem Exército Supremo, sem vitória")

# --- Qualificação no instante da captura ----------------------------------------------------------------

func test_capturing_a_city_ii_does_not_count():
	_grant_access(human)
	_keep_alive(a)
	var small := _city_of(a, 2)
	grid.capture_city(small, human)
	assert_eq(small.v2_supremacy_captured_from, -1)
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, a))

func test_developing_a_captured_small_city_afterwards_still_does_not_count():
	_grant_access(human)
	_keep_alive(a)
	var small := _city_of(a, 2)
	grid.capture_city(small, human)
	small.apply_city_level(4)
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, a), "vale o nível no momento da captura")

func test_capturing_city_iii_or_iv_counts():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	var iii := _city_of(a, 3)
	var iv := _city_of(b, 4)
	grid.capture_city(iii, human)
	grid.capture_city(iv, human)
	assert_eq(iii.v2_supremacy_captured_from, GameManager.players.find(a))
	assert_eq(iv.v2_supremacy_captured_from, GameManager.players.find(b))
	assert_true(V2VictoryConditions.military_supremacy_achieved(human))

func test_capturing_a_small_city_resets_a_stale_credit_field():
	_keep_alive(a)
	var city := _city_of(a, 2)
	city.v2_supremacy_captured_from = 2 # resto antigo
	grid.capture_city(city, human)
	assert_eq(city.v2_supremacy_captured_from, -1, "sempre reescrito na captura")

func test_the_capture_toast_names_the_rival_once():
	_grant_access(human)
	_keep_alive(a)
	watch_signals(EventBus)
	grid.capture_city(_city_of(a, 3), human)
	grid.capture_city(_city_of(a, 3), human)
	var count := 0
	for i in get_signal_emit_count(EventBus, "notify"):
		if String(get_signal_parameters(EventBus, "notify", i)[0]) == "Supremacia: conquista válida contra Reino A.":
			count += 1
	assert_eq(count, 1, "segunda conquista do mesmo rival não repete o aviso")

# --- Manter a cidade ---------------------------------------------------------------------------------------

func test_losing_the_captured_city_loses_the_credit():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	var iii := _city_of(a, 3)
	grid.capture_city(iii, human)
	grid.capture_city(_city_of(b, 3), human)
	assert_true(V2VictoryConditions.military_supremacy_achieved(human))
	grid.capture_city(iii, b)
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, a))
	assert_false(V2VictoryConditions.military_supremacy_achieved(human))

func test_recapture_by_the_player_restores_the_credit():
	_grant_access(human)
	_keep_alive(a)
	var iii := _city_of(a, 3)
	grid.capture_city(iii, human)
	grid.capture_city(iii, a)
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, a))
	grid.capture_city(iii, human)
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(human, a), "reconquistada ainda como Cidade III")

func test_two_cities_from_the_same_rival_count_once_and_one_is_enough():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	var first := _city_of(a, 3)
	var second := _city_of(a, 4)
	grid.capture_city(first, human)
	grid.capture_city(second, human)
	var status := V2VictoryConditions.military_supremacy_status(human)
	assert_eq(status.satisfied_count, 1, "um rival, um crédito")
	grid.capture_city(first, a)
	assert_true(V2VictoryConditions.rival_satisfied_by_conquest(human, a), "a outra ainda mantém")

# --- Eliminação -------------------------------------------------------------------------------------------

func test_an_eliminated_rival_is_satisfied():
	_grant_access(human)
	_keep_alive(b)
	grid.capture_city(_city_of(b, 3), human)
	assert_true(V2VictoryConditions.is_eliminated(a), "a nunca teve cidade nem unidade")
	var status := V2VictoryConditions.military_supremacy_status(human)
	assert_eq(status.rivals[0].reason, V2VictoryConditions.REASON_ELIMINATED)
	assert_true(V2VictoryConditions.military_supremacy_achieved(human))

func test_a_living_settler_keeps_the_rival_alive():
	_grant_access(human)
	grid.spawn_unit(Vector2i(8, -4), UnitDatabase.create_unit("settler"), a)
	assert_false(V2VictoryConditions.is_eliminated(a), "mesma definição da Dominação")
	assert_false(V2VictoryConditions.rival_satisfied_by_conquest(human, a))

# --- Contagem de rivais ----------------------------------------------------------------------------------

func test_with_no_rival_the_victory_is_never_vacuous():
	_set_majors([human])
	_grant_access(human)
	assert_eq(V2VictoryConditions.military_supremacy_status(human).rival_count, 0)
	assert_false(V2VictoryConditions.military_supremacy_achieved(human))

func test_three_rivals_progress_two_of_three_then_three_of_three():
	var c := _player("Reino C")
	_set_majors([human, a, b, c])
	Diplomacy.declare_war(human, c)
	_grant_access(human)
	for rival in [a, b, c]:
		_keep_alive(rival)
	grid.capture_city(_city_of(a, 3), human)
	grid.capture_city(_city_of(b, 4), human)
	var lines := V2VictoryConditions.military_supremacy_lines(human)
	assert_eq(lines[0], "Supremacia Militar: 2 / 3 rivais satisfeitos")
	assert_true("Reino A — Conquista mantida" in lines)
	assert_true("Reino C — Pendente" in lines)
	assert_false(V2VictoryConditions.military_supremacy_achieved(human))
	grid.capture_city(_city_of(c, 3), human)
	assert_eq(V2VictoryConditions.military_supremacy_lines(human)[0], "Supremacia Militar: 3 / 3 rivais satisfeitos")
	assert_true(V2VictoryConditions.military_supremacy_achieved(human))

func test_the_eliminated_label_is_shown():
	_grant_access(human)
	_keep_alive(b)
	assert_true("Reino A — Eliminado" in V2VictoryConditions.military_supremacy_lines(human))

func test_a_rival_can_win_against_the_human_too():
	_grant_access(a)
	Diplomacy.declare_war(a, b)
	_keep_alive(human)
	_keep_alive(b)
	grid.capture_city(_city_of(human, 3), a)
	grid.capture_city(_city_of(b, 3), a)
	assert_true(V2VictoryConditions.military_supremacy_achieved(a))

func test_non_major_players_never_win():
	var outsider := _player("Fora")
	_grant_access(outsider)
	assert_false(V2VictoryConditions.military_supremacy_achieved(outsider))

# --- Independência da V1.5 -----------------------------------------------------------------------------------

func test_v2_supremacy_never_touches_the_v1_5_path():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	grid.capture_city(_city_of(a, 3), human)
	grid.capture_city(_city_of(b, 3), human)
	assert_true(V2VictoryConditions.military_supremacy_achieved(human))
	assert_false("researched_techs" in human, "Fase 25: não existe mais estado de pesquisa V1 para gravar")

func test_v1_5_research_never_grants_v2_access():
	assert_false(V2VictoryConditions.military_supremacy_status(human).access)

# --- check_victories ----------------------------------------------------------------------------------------

func test_check_victories_ends_the_game_with_the_v2_type():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	grid.capture_city(_city_of(a, 3), human)
	grid.capture_city(_city_of(b, 3), human)
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [human, V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY])
	assert_signal_emitted_with_parameters(EventBus, "game_over", [true])

func test_check_victories_does_nothing_while_pending():
	_grant_access(human)
	_keep_alive(a)
	_keep_alive(b)
	grid.capture_city(_city_of(a, 3), human)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)

func test_victory_screen_texts():
	var hud_script: GDScript = load("res://scripts/ui/HUD.gd")
	assert_eq(hud_script.format_victory_title(human, V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY), "Vitória por Supremacia Militar — Reino Humano")
	assert_eq(hud_script.format_victory_summary(V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY), "Seu império provou sua supremacia conquistando os centros desenvolvidos de seus rivais.")
