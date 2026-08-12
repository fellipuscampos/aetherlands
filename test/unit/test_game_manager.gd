extends GutTest

## Cobre a generalizacao do GameManager pra multiplos rivais: setup_players()
## cria o numero certo de civs (cada uma em guerra com o humano por
## padrao, nunca entre si), e check_game_over() so declara vitoria quando
## TODOS os rivais forem eliminados — nao mais um unico rival fixo.

var _original_state
var _original_players: Array[PlayerData]
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_hex_grid: HexGrid
var _original_rival_count: int
var _original_map_width: int
var _original_map_height: int
var _original_turn_number: int
var _original_turn_player_index: int
var _original_difficulty: String

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_hex_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_difficulty = GameManager.difficulty

func after_each():
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.hex_grid = _original_hex_grid
	GameManager.rival_count = _original_rival_count
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height
	TurnManager.turn_number = _original_turn_number
	TurnManager.current_player_index = _original_turn_player_index
	GameManager.difficulty = _original_difficulty

func test_setup_players_creates_requested_number_of_rivals():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 3

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.rival_players.size(), 3)
	assert_eq(GameManager.players.size(), 4, "humano + 3 rivais")

	hex_grid.queue_free()

func test_setup_players_clamps_rival_count_to_available_civs():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 99

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.rival_players.size(), GameManager.RIVAL_CIVS.size())

	hex_grid.queue_free()

func test_setup_players_starts_human_at_war_with_every_rival():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 2

	GameManager.setup_players(hex_grid)

	for rival in GameManager.rival_players:
		assert_true(GameManager.human_player.is_at_war_with(rival))
		assert_true(rival.is_at_war_with(GameManager.human_player))

	hex_grid.queue_free()

func test_setup_players_gives_each_rival_a_distinct_civ_name():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 3

	GameManager.setup_players(hex_grid)

	var names := []
	for rival in GameManager.rival_players:
		assert_false(rival.civ.civ_name in names, "cada rival deveria ter um nome de civ diferente")
		names.append(rival.civ.civ_name)

	hex_grid.queue_free()

## Cada rival e uma civilizacao de fantasia de verdade (anao/orc/elfo, ver
## GameManager.RIVAL_CIVS), nao mais uma copia generica do reino do
## jogador — setup_players() precisa copiar o campo `race` novo pro
## CivilizationData de cada rival, senao RivalAI nunca desbloquearia a
## tropa exclusiva de ninguem.
func test_setup_players_gives_each_rival_the_race_from_rival_civs():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 3

	GameManager.setup_players(hex_grid)

	for i in range(GameManager.rival_players.size()):
		assert_eq(GameManager.rival_players[i].civ.race, GameManager.RIVAL_CIVS[i].race)
		assert_ne(GameManager.rival_players[i].civ.race, "", "todo rival do pool atual deveria ter uma raca de fantasia")

	hex_grid.queue_free()

## O jogador humano continua sem raca de fantasia nesta rodada (so os
## rivais ganharam, ver CivilizationData.race) — escolher a propria raca
## fica pra depois.
func test_setup_players_human_has_no_race():
	var hex_grid := HexGrid.new()
	hex_grid._ready()

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.civ.race, "")

	hex_grid.queue_free()

## Dificuldade so deveria afetar a economia dos RIVAIS (PlayerData.
## yield_multiplier, aplicado em City.collect_yields) — o humano fica
## sempre em 1.0, senao "facil"/"dificil" tambem mudariam o jogador.
func test_setup_players_applies_difficulty_multiplier_to_rivals_only():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 2
	GameManager.difficulty = "hard"

	GameManager.setup_players(hex_grid)

	assert_almost_eq(GameManager.human_player.yield_multiplier, 1.0, 0.01, "dificuldade nao deveria afetar o jogador humano")
	for rival in GameManager.rival_players:
		assert_almost_eq(rival.yield_multiplier, GameManager.DIFFICULTY_MULTIPLIERS.hard, 0.01)

	hex_grid.queue_free()

func test_setup_players_defaults_to_normal_multiplier():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 1
	GameManager.difficulty = "normal"

	GameManager.setup_players(hex_grid)

	assert_almost_eq(GameManager.rival_players[0].yield_multiplier, 1.0, 0.01)

	hex_grid.queue_free()

func test_check_game_over_requires_all_rivals_eliminated_for_victory():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null) # humano ainda vivo

	var alive_rival = PlayerData.new(CivilizationData.new())
	alive_rival.units.append(null)
	var dead_rival = PlayerData.new(CivilizationData.new())
	GameManager.rival_players = [alive_rival, dead_rival]

	GameManager.check_game_over()

	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "ainda tem 1 rival vivo, o jogo nao deveria terminar")

func test_check_game_over_declares_victory_when_every_rival_is_eliminated():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)

	var dead_rival_a = PlayerData.new(CivilizationData.new())
	var dead_rival_b = PlayerData.new(CivilizationData.new())
	GameManager.rival_players = [dead_rival_a, dead_rival_b]

	GameManager.check_game_over()

	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)

## Debug (HUD.gd, botao "Debug"): forca fim de jogo sem eliminar unidade/
## cidade nenhuma de verdade, reaproveitando o mesmo _end_game()/sinal
## EventBus.game_over do fim de jogo real — util pra testar a tela de
## vitoria/derrota sem jogar uma partida inteira.
func test_debug_force_game_over_sets_state_and_emits_signal():
	GameManager.state = GameManager.GameState.PLAYING
	watch_signals(EventBus)

	GameManager.debug_force_game_over(true)

	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "game_over", [true])

## Debug: completa a pesquisa atual na hora, reaproveitando
## _process_research() de verdade (mesmo efeito colateral de marcar
## researched_techs e limpar current_research).
func test_debug_complete_current_research_finishes_the_selected_tech():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.current_research = "agriculture"

	GameManager.debug_complete_current_research()

	assert_true(GameManager.human_player.researched_techs.has("agriculture"))
	assert_eq(GameManager.human_player.current_research, "")

func test_debug_complete_current_research_does_nothing_without_a_selected_tech():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.current_research = ""

	GameManager.debug_complete_current_research() # nao deveria travar nem levantar erro nenhum

	assert_eq(GameManager.human_player.current_research, "")

func test_rival_origin_spreads_rivals_around_the_map():
	GameManager.map_width = 25
	GameManager.map_height = 25
	var origin_0 = GameManager._rival_origin(0, 3)
	var origin_1 = GameManager._rival_origin(1, 3)
	var origin_2 = GameManager._rival_origin(2, 3)

	assert_ne(origin_0, origin_1, "rivais diferentes deveriam comecar em lugares diferentes")
	assert_ne(origin_1, origin_2)
	assert_ne(origin_0, origin_2)

## Regressao: num mapa Pequeno com varios rivais, a busca por "planicie
## mais proxima" de origens diferentes podia convergir pro mesmo tile — a
## segunda HexGrid.found_city() sobrescrevia a primeira em
## cities_by_coord, deixando a primeira capital existindo (ainda gerando
## producao) mas invisivel/inatacavel. WorldSetup.find_start_tile agora
## recebe as coordenadas ja reivindicadas (GameManager._spawn_starting_forces).
func test_spawn_starting_forces_never_places_two_civs_on_the_same_tile():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(13, 13, 555) # mapa pequeno, semente fixa
	GameManager.map_width = 13
	GameManager.map_height = 13
	GameManager.rival_count = 3

	GameManager.start_new_game(hex_grid)

	var human_settler: Unit = null
	for unit in GameManager.human_player.units:
		if unit.unit_data.can_found_city:
			human_settler = unit
			break
	assert_true(human_settler != null, "pre-condicao: humano deveria comecar com um colonizador")

	var start_coords := {}
	start_coords[human_settler.coord] = true

	for rival in GameManager.rival_players:
		assert_eq(rival.cities.size(), 1, "pre-condicao: cada rival deveria comecar com exatamente 1 capital")
		var capital_coord = rival.cities[0].coord
		assert_false(start_coords.has(capital_coord), "duas civs nao deveriam comecar na mesma coordenada")
		start_coords[capital_coord] = true

	hex_grid.queue_free()

## O pipeline inteiro de comecar um jogo novo (gerar mapa + espalhar
## civs) precisa continuar funcionando no tamanho Medio (84x54, 4536
## tiles — pedido do usuario com as dimensoes exatas do Civilization),
## nao so nos mapas pequenos que o resto da suite ja cobre.
func test_start_new_game_works_at_the_new_medium_map_size():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.map_width = TitleScreen.MAP_SIZES.medium.width
	GameManager.map_height = TitleScreen.MAP_SIZES.medium.height
	GameManager.rival_count = 3

	GameManager.start_new_game(hex_grid)

	var human_settler: Unit = null
	for unit in GameManager.human_player.units:
		if unit.unit_data.can_found_city:
			human_settler = unit
			break
	assert_true(human_settler != null, "humano deveria comecar com um colonizador mesmo no mapa maior")

	for rival in GameManager.rival_players:
		assert_eq(rival.cities.size(), 1, "cada rival deveria comecar com exatamente 1 capital mesmo no mapa maior")

	hex_grid.queue_free()
