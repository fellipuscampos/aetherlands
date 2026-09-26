extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## Cobre a generalizacao do GameManager pra multiplos rivais: setup_players()
## cria o numero certo de civs (cada uma em guerra com o humano por
## padrao, nunca entre si), e check_game_over() so declara vitoria quando
## TODOS os rivais forem eliminados — nao mais um unico rival fixo.

## Stub SO de teste (Roadmap Fase Macro, World Event System Step 4) -- conta
## quantas vezes advance_turn() foi chamado e guarda o ultimo hex_grid/
## players recebidos, pra provar a integracao generica com GameManager sem
## nenhum evento concreto (DragonEvent) existir ainda.
class _StubWorldEvent extends WorldEvent:
	var advance_calls: int = 0
	var last_hex_grid: HexGrid = null
	var last_players: Array[PlayerData] = []
	func advance_turn(received_hex_grid: HexGrid, received_players: Array[PlayerData]) -> void:
		advance_calls += 1
		last_hex_grid = received_hex_grid
		last_players = received_players

## Elimina `target` (unidades + cidades) durante o proprio advance_turn() --
## simula um evento cuja consequencia deveria ja valer pra checagem de
## vitoria do MESMO turno (ver GameManager._finish_turn(), ordem exigida
## pelo contrato).
class _EliminatesPlayerEvent extends WorldEvent:
	var target: PlayerData
	func advance_turn(_hex_grid: HexGrid, _players: Array[PlayerData]) -> void:
		target.units.clear()
		target.cities.clear()

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
var _original_human_race: String
var _original_debug_mode: bool
var _original_stagger_ai_turns: bool
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int
var _original_current_save_slot: String

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
	_original_human_race = GameManager.human_race
	_original_debug_mode = GameManager.debug_mode
	_original_stagger_ai_turns = GameManager.stagger_ai_turns
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	_original_current_save_slot = GameManager.current_save_slot

func after_each():
	for player in GameManager.players:
		if not player in _original_players:
			player.release_relations()
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
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
	GameManager.human_race = _original_human_race
	GameManager.debug_mode = _original_debug_mode
	GameManager.stagger_ai_turns = _original_stagger_ai_turns
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id
	GameManager._ai_batch_timer = 0.0
	GameManager.current_save_slot = _original_current_save_slot

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

## Pedido do usuario: "vamos fazer com que todos comecem o jogo em paz, ao
## inves de comecar em guerra" — antes disso o humano nascia automaticamente
## em guerra com todo rival, sem escolha nenhuma. Guerra agora so acontece
## se o jogador declarar de proposito (ver HUD._on_declare_war_pressed).
func test_setup_players_starts_everyone_at_peace():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 2

	GameManager.setup_players(hex_grid)

	for rival in GameManager.rival_players:
		assert_false(GameManager.human_player.is_at_war_with(rival))
		assert_false(rival.is_at_war_with(GameManager.human_player))

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

## GameManager.human_race defaults pra "human" (ex: um teste que chama
## setup_players() direto, sem passar pela tela de titulo) — mesmo padrao
## de human_kingdom_name == "" caindo pro nome de reino padrao da raca
## (ver _default_kingdom_name_for_race, testado separadamente abaixo).
func test_setup_players_human_defaults_to_human_race():
	var hex_grid := HexGrid.new()
	hex_grid._ready()

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.civ.race, "human")

	hex_grid.queue_free()

## Pedido do usuario: "crie um sistema onde ao iniciar o game a gente pode
## escolher tambem a raca que vai jogar" — a raca escolhida na tela de
## titulo (GameManager.human_race, ver TitleScreen._on_new_game_pressed)
## precisa chegar ate CivilizationData.race do jogador humano.
func test_setup_players_gives_human_the_chosen_race():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.human_race = "elf"

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.civ.race, "elf")

	hex_grid.queue_free()

## Bug relatado pelo usuario: "escolhi outro reino e iniciei com o reino
## humano" — a raca (civ.race) sempre chegava certa (ver teste acima), mas
## o NOME do reino, quando o campo de configuracao ficava em branco, caia
## sempre em "Reino de Aldenmark" (o nome humano, fixo), fazendo o jogo
## parecer ter iniciado como humano mesmo escolhendo outra raca. Agora o
## fallback usa o nome de reino da PROPRIA raca escolhida (GameSetupScreen.
## RACE_INFO, mesma fonte da tela de configuracao).
func test_setup_players_defaults_kingdom_name_to_the_chosen_races_own_kingdom():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var original_kingdom_name := GameManager.human_kingdom_name
	GameManager.human_kingdom_name = ""
	GameManager.human_race = "elf"

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.civ.civ_name, GameSetupScreen.RACE_INFO.elf.display_name)
	assert_ne(GameManager.human_player.civ.civ_name, GameSetupScreen.RACE_INFO.human.display_name, "nao deveria mais cair no nome de reino humano pra uma raca diferente")

	hex_grid.queue_free()
	GameManager.human_kingdom_name = original_kingdom_name

## Nome digitado pelo jogador sempre tem prioridade sobre o padrao da raca,
## nao importa qual raca foi escolhida.
func test_setup_players_prefers_the_typed_kingdom_name_over_the_race_default():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var original_kingdom_name := GameManager.human_kingdom_name
	GameManager.human_kingdom_name = "Reino Personalizado"
	GameManager.human_race = "orc"

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.civ.civ_name, "Reino Personalizado")

	hex_grid.queue_free()
	GameManager.human_kingdom_name = original_kingdom_name

## Roadmap "Fase F" F3 -- check_game_over() virou check_victories(),
## autoridade unica das 3 vitorias (antes so Dominacao). Nome do teste
## atualizado, comportamento identico pro caso de Dominacao.
func test_check_victories_requires_all_rivals_eliminated_for_dominance():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.human_player.units.append(null) # humano ainda vivo

	var alive_rival = _track_player(CivilizationData.new())
	alive_rival.units.append(null)
	var dead_rival = _track_player(CivilizationData.new())
	GameManager.rival_players = [alive_rival, dead_rival]

	GameManager.check_victories()

	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "ainda tem 1 rival vivo, o jogo nao deveria terminar")

func test_check_victories_declares_dominance_when_every_rival_is_eliminated():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.human_player.units.append(null)

	var dead_rival_a = _track_player(CivilizationData.new())
	var dead_rival_b = _track_player(CivilizationData.new())
	GameManager.rival_players = [dead_rival_a, dead_rival_b]

	GameManager.check_victories()

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

## Roadmap "Fase F" F3 -- estado temporal das duas vitorias de
## sustentacao (_update_victory_state/_update_territorial_streak/
## _update_arcane_ritual), a acao explicita de ativacao
## (activate_arcane_ritual) e a autoridade unificada de deteccao
## (check_victories). Nenhum destes testes passa por _finish_turn() de
## verdade -- chama as funcoes direto, mesmo padrao do resto do arquivo.

func _make_ritual_grid_with_three_nodes() -> HexGrid:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for i in range(3):
		var coord := Vector2i(i, 0)
		hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		hex_grid.tiles[coord].resource = "mana_node"
	return hex_grid

## Desempate FIXO combinado com o usuario: ordem tecnica, nunca prioridade
## estrategica entre vitorias (ver comentario de check_victories).

## Fase 25: ligar o modo debug só liga a flag -- não concede pesquisa nenhuma (as ferramentas de
## pesquisa ficam no próprio quadro, só em build de debug).
func test_set_debug_mode_only_toggles_the_flag_and_never_touches_research():
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.set_debug_mode(true)
	assert_true(GameManager.debug_mode)
	assert_true(GameManager.human_player.v2_research.get_completed_ids().is_empty())
	GameManager.set_debug_mode(false)
	assert_false(GameManager.debug_mode)

func test_debug_complete_current_research_finishes_the_active_research():
	GameManager.human_player = _track_player(CivilizationData.new())
	assert_true(GameManager.human_player.v2_research.select_research("v2_doctrine_guardian_1"))
	GameManager.debug_complete_current_research()
	assert_true(GameManager.human_player.v2_research.is_completed("v2_doctrine_guardian_1"))
	assert_eq(GameManager.human_player.v2_research.active_id, "")

func test_debug_complete_current_research_does_nothing_without_an_active_research():
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.debug_complete_current_research()
	assert_true(GameManager.human_player.v2_research.get_completed_ids().is_empty())

func test_set_debug_mode_does_not_crash_without_a_human_player():
	GameManager.human_player = null

	GameManager.set_debug_mode(true) # nao deveria travar nem levantar erro nenhum

	assert_true(GameManager.debug_mode)

## Pedido do usuario: "o tempo de fazer qualquer unidade e 1 turno" —
## enquanto ligado, a cidade do jogador HUMANO completa a producao atual
## (unidade OU predio) no proprio turno, independente do custo real. Rival
## com uma cidade propria so pra check_game_over() (chamado no fim de
## _on_turn_changed) nao declarar vitoria automatica por falta de
## adversario — irrelevante pro que este teste cobre.
func test_debug_mode_completes_city_production_in_one_turn():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var rival_coord := Vector2i(10, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # so a producao base V2 da cidade, sem debug 1 turno nao seria nem perto do suficiente
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := _track_player(CivilizationData.new())
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	var city = hex_grid.found_city(coord, GameManager.human_player, "Capital")
	city.set_production("settler") # Colonizador nao depende de predio nenhum
	GameManager.set_debug_mode(true)

	GameManager._on_turn_changed(0, 0)

	var spawned := false
	for unit in GameManager.human_player.units:
		if unit.unit_data.can_found_city:
			spawned = true
	assert_true(spawned, "com modo debug ligado, o Colonizador deveria ter sido produzido no mesmo turno")

	hex_grid.queue_free()

func test_debug_mode_off_does_not_speed_up_production():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var rival_coord := Vector2i(10, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := _track_player(CivilizationData.new())
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	var city = hex_grid.found_city(coord, GameManager.human_player, "Capital")
	city.set_production("settler")
	GameManager.debug_mode = false

	GameManager._on_turn_changed(0, 0)

	assert_eq(GameManager.human_player.units.size(), 0, "sem modo debug, producao sem rendimento de producao nao deveria completar num turno so")

	hex_grid.queue_free()

## Cobre o pedido do usuario: "Civilization nao faz tudo acontecer no mapa
## ao mesmo tempo... em pequenos grupos... diminui o lag na passada de
## turnos" — ver GameManager.stagger_ai_turns/_process/_finish_turn.
func _setup_hex_grid_with_rival_units(unit_count: int) -> Dictionary:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var human_coord := Vector2i(0, 0)
	var rival_coord := Vector2i(20, 0)
	hex_grid.tiles[human_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := _track_player(CivilizationData.new())
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(human_coord, GameManager.human_player, "Capital")
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	for i in range(unit_count):
		hex_grid.spawn_unit(Vector2i(20 + i, 5), UnitDatabase.create_unit("warrior"), rival)
	return {"hex_grid": hex_grid, "rival": rival}

## Com stagger_ai_turns DESLIGADO (o padrao, mesmo comportamento de sempre),
## o turno inteiro resolve no mesmo frame — is_turn_processing nunca chega
## a ficar true, e a fila fica sempre vazia.
func test_on_turn_changed_without_staggering_finishes_synchronously():
	var setup = _setup_hex_grid_with_rival_units(5)
	GameManager.stagger_ai_turns = false

	GameManager._on_turn_changed(0, 0)

	assert_false(GameManager.is_turn_processing, "sem staggering, o turno deveria terminar tudo no mesmo frame")
	assert_true(GameManager._ai_turn_queue.is_empty())

	setup.hex_grid.queue_free()

## Com stagger_ai_turns LIGADO e unidades suficientes pra IA agir, o turno
## NAO termina no mesmo frame — fica "processando" ate _process() drenar a
## fila aos poucos.
func test_on_turn_changed_with_staggering_leaves_the_turn_processing():
	var setup = _setup_hex_grid_with_rival_units(8)
	GameManager.stagger_ai_turns = true

	GameManager._on_turn_changed(0, 0)

	assert_true(GameManager.is_turn_processing, "com fila nao-vazia, o turno deveria continuar 'processando' ate _process() drenar")
	assert_false(GameManager._ai_turn_queue.is_empty())

	setup.hex_grid.queue_free()

## Um _process() com delta MENOR que AI_BATCH_INTERVAL nao deveria drenar
## nada ainda — o acumulo por tempo (nao por frame) e o proprio ponto do
## pedido do usuario: "as animacoes, as movimentacoes... nao tudo ao mesmo
## tempo mas em fila" (drenar direto todo frame, sem pausa nenhuma, ainda
## deixava varias animacoes de movimento comecando quase juntas).
func test_process_does_not_drain_before_the_batch_interval_elapses():
	var setup = _setup_hex_grid_with_rival_units(8)
	GameManager.stagger_ai_turns = true
	GameManager._on_turn_changed(0, 0)
	var initial_size: int = GameManager._ai_turn_queue.size()

	GameManager._process(GameManager.AI_BATCH_INTERVAL * 0.5)

	assert_eq(GameManager._ai_turn_queue.size(), initial_size, "delta menor que AI_BATCH_INTERVAL nao deveria drenar nenhum item ainda")
	setup.hex_grid.queue_free()

func test_process_drains_the_ai_queue_in_small_batches():
	var setup = _setup_hex_grid_with_rival_units(8)
	GameManager.stagger_ai_turns = true
	GameManager._on_turn_changed(0, 0)
	var initial_size: int = GameManager._ai_turn_queue.size()
	assert_gt(initial_size, GameManager.AI_ACTIONS_PER_BATCH, "precondicao: fila maior que um lote so, senao o teste nao cobre nada")

	GameManager._process(GameManager.AI_BATCH_INTERVAL)

	assert_eq(GameManager._ai_turn_queue.size(), initial_size - GameManager.AI_ACTIONS_PER_BATCH, "um _process() apos o intervalo so deveria drenar AI_ACTIONS_PER_BATCH itens, nao a fila inteira")
	assert_true(GameManager.is_turn_processing, "ainda deveria sobrar fila depois de um lote so")

	setup.hex_grid.queue_free()

## Drenar a fila inteira (varias chamadas a _process(), como aconteceria em
## varios frames reais espacados por AI_BATCH_INTERVAL) precisa terminar o
## turno de verdade — mesmo efeito final de sempre (is_turn_processing
## volta a false, check_game_over roda via _finish_turn), so espalhado ao
## longo do tempo em vez de tudo num frame so.
func test_process_finishes_the_turn_once_the_queue_is_empty():
	var setup = _setup_hex_grid_with_rival_units(8)
	GameManager.stagger_ai_turns = true
	GameManager._on_turn_changed(0, 0)

	var safety := 0
	while GameManager.is_turn_processing and safety < 100:
		GameManager._process(GameManager.AI_BATCH_INTERVAL)
		safety += 1

	assert_false(GameManager.is_turn_processing, "a fila deveria terminar de drenar em poucas chamadas a _process()")
	assert_true(GameManager._ai_turn_queue.is_empty())

	setup.hex_grid.queue_free()

## Defensivo: chamar _on_turn_changed de novo enquanto o turno anterior
## ainda esta processando (nao deveria acontecer de verdade, HUD desabilita
## o botao — ver HUD._process) nao deveria embaralhar a fila com um
## segundo turno em cima do primeiro.
func test_on_turn_changed_is_a_no_op_while_still_processing():
	var setup = _setup_hex_grid_with_rival_units(8)
	GameManager.stagger_ai_turns = true
	GameManager._on_turn_changed(0, 0)
	var queue_size_before: int = GameManager._ai_turn_queue.size()

	GameManager._on_turn_changed(0, 0)

	assert_eq(GameManager._ai_turn_queue.size(), queue_size_before, "chamar de novo no meio do processamento nao deveria mexer na fila")

	setup.hex_grid.queue_free()

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
## civs) precisa continuar funcionando no tamanho Grande (96x60, 5760
## tiles — pedido do usuario com as dimensoes exatas do Civilization, e
## desde "elimine a criacao do mapa medio e pequeno, vamos a partir de
## agora usar so o grande" o UNICO tamanho que o jogo de verdade usa),
## nao so nos mapas pequenos que o resto da suite ja cobre.
func test_start_new_game_works_at_the_large_map_size():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.map_width = TitleScreen.MAP_SIZES.large.width
	GameManager.map_height = TitleScreen.MAP_SIZES.large.height
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

## Continentes Vulcanico/de Cristal (pedido do usuario) ficam FORA da zona
## Principal, num canvas total bem maior — civs (humano + rivais) sempre
## precisam nascer dentro da zona Principal mesmo assim, nunca no gap de
## oceano nem dentro de um continente especial. GameManager._rival_origin
## trava na pegada FIXA (TitleScreen.MAIN_ZONE_SIZE), nao no canvas total.
func test_start_new_game_at_large_size_keeps_civs_inside_the_main_zone():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.map_width = TitleScreen.MAP_SIZES.large.width
	GameManager.map_height = TitleScreen.MAP_SIZES.large.height
	GameManager.rival_count = 3

	GameManager.start_new_game(hex_grid)

	for player in GameManager.players:
		for city in player.cities:
			assert_eq(hex_grid._zone_for(city.coord), hex_grid._Zone.MAIN, "cidade de %s em %s deveria estar na zona Principal" % [player.civ.civ_name, str(city.coord)])
		for unit in player.units:
			assert_eq(hex_grid._zone_for(unit.coord), hex_grid._Zone.MAIN, "unidade de %s em %s deveria estar na zona Principal" % [player.civ.civ_name, str(unit.coord)])

	hex_grid.queue_free()

## --- World Event System (Roadmap Fase Macro, Step 4) -----------------------
## Testa a integracao GENERICA com GameManager (docs/WORLD_EVENT_CONTRACT.md,
## secao 1 e 6) -- nenhum evento concreto (DragonEvent) existe ainda.

func _setup_minimal_hex_grid_with_one_rival() -> Dictionary:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var human_coord := Vector2i(0, 0)
	var rival_coord := Vector2i(10, 0)
	hex_grid.tiles[human_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := _track_player(CivilizationData.new())
	GameManager.human_player = _track_player(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(human_coord, GameManager.human_player, "Capital")
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	return {"hex_grid": hex_grid, "rival": rival}

## Regra temporal do contrato: eventos avancam exatamente uma vez por turno
## REAL, so de dentro de _finish_turn().
func test_finish_turn_advances_world_events_exactly_once_per_real_turn():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := _StubWorldEvent.new()
	WorldEventManager.register_event(event)

	GameManager._on_turn_changed(0, 0)
	assert_eq(event.advance_calls, 1)

	GameManager._on_turn_changed(0, 0)
	assert_eq(event.advance_calls, 2)

	setup.hex_grid.queue_free()

## Contrato, secao 6: "GameManager orquestra... reusa o campo players que ja
## mantem, sem reconstruir a lista" -- confirma que o MESMO hex_grid/array
## players do GameManager chegam ao evento, nao uma copia reconstruida.
func test_finish_turn_passes_the_real_hex_grid_and_players_to_world_events():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := _StubWorldEvent.new()
	WorldEventManager.register_event(event)

	GameManager._on_turn_changed(0, 0)

	assert_eq(event.last_hex_grid, GameManager.hex_grid)
	assert_eq(event.last_players, GameManager.players)

	setup.hex_grid.queue_free()

## Regra temporal do contrato: "Nenhuma chamada de UI, preview, save/load ou
## verificacao de vitoria pode avancar um evento" -- check_victories() e o
## ponto compartilhado pelos outros 3 call sites (SelectionManager x2,
## SaveManager.load_game), entao provar que ELE sozinho nunca avanca nenhum
## evento cobre os 3 de uma vez, sem precisar simular cada um.
func test_check_victories_alone_never_advances_world_events():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := _StubWorldEvent.new()
	WorldEventManager.register_event(event)

	GameManager.check_victories()

	assert_eq(event.advance_calls, 0, "check_victories() sozinho nunca deveria avancar evento nenhum -- so _finish_turn() pode")

	setup.hex_grid.queue_free()

## Motivo exato da ordem escolhida no contrato (secao 1): uma consequencia
## que um evento aplica NESTE turno (aqui, "elimina o rival") precisa estar
## refletida na checagem de vitoria do MESMO turno -- prova concreta via
## Dominacao, nao so uma alegacao de ordem de chamadas.
func test_finish_turn_reflects_a_world_events_consequences_in_the_same_turns_victory_check():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var rival: PlayerData = setup.rival
	var event := _EliminatesPlayerEvent.new()
	event.target = rival
	WorldEventManager.register_event(event)

	GameManager._on_turn_changed(0, 0)

	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER, "a eliminacao do rival pelo evento deveria ja valer pra checagem de vitoria do MESMO turno")

	setup.hex_grid.queue_free()

## Determinismo (contrato secao 4), agora em INTEGRACAO: o RNG proprio do
## evento continua reproduzivel pro mesmo turno mesmo com RivalAI de
## verdade consumindo o RNG global de decisao por caminhos DIFERENTES --
## nao so em isolamento (ja provado em test_world_event.gd).
func test_event_rng_stays_reproducible_regardless_of_ai_rng_activity_in_real_turns():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := _StubWorldEvent.new()
	WorldEventManager.register_event(event)

	seed(111)
	GameManager._on_turn_changed(0, 0) # RivalAI.decide_war/decide_trade ja consomem o RNG global aqui
	var turn_after_run: int = TurnManager.turn_number
	var roll_a := event.event_rng(setup.hex_grid.map_seed, turn_after_run).randi()

	seed(999) # reseed BEM diferente -- simula uma sequencia de decisoes de IA totalmente diferente
	for i in range(20):
		randi()
	var roll_b := event.event_rng(setup.hex_grid.map_seed, turn_after_run).randi()

	assert_eq(roll_a, roll_b, "o roll do evento pro mesmo turno nao deveria mudar so porque o RNG global de IA seguiu um caminho diferente")

	setup.hex_grid.queue_free()

## --- Roadmap "Fase Macro" 5B.2: participacao (humano + IA) ---------------

func test_respond_to_world_event_records_the_humans_decision():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)

	var recorded := GameManager.respond_to_world_event(true)

	assert_true(recorded)
	var human_index: int = GameManager.players.find(GameManager.human_player)
	assert_eq(event.participants.get(human_index), {"decision": true})
	setup.hex_grid.queue_free()

func test_respond_to_world_event_returns_false_without_an_eligible_event():
	var setup := _setup_minimal_hex_grid_with_one_rival()
	assert_false(GameManager.respond_to_world_event(true), "sem evento nenhum em Preparation, nao deveria haver nada pra responder")
	setup.hex_grid.queue_free()

func test_respond_to_world_event_does_not_overwrite_an_existing_decision():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)
	var human_index: int = GameManager.players.find(GameManager.human_player)
	event.participants[human_index] = {"decision": false}

	assert_false(GameManager.respond_to_world_event(true), "ja havia uma decisao registrada -- nao deveria haver nada NOVO pra responder")
	assert_eq(event.participants[human_index], {"decision": false})
	setup.hex_grid.queue_free()

## Integracao: _finish_turn() precisa consultar RivalAI.decide_world_event_
## participation pra cada rival, nao so o humano via UI futura.
func test_finish_turn_collects_rival_participation_during_preparation():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)

	GameManager._on_turn_changed(0, 0)

	var rival_index: int = GameManager.players.find(setup.rival)
	assert_eq(event.participants.get(rival_index), {"decision": true})
	setup.hex_grid.queue_free()

## Blocker #1 do contrato comportamental do Dragao (docs/DRAGON_EVENT_
## DESIGN.md) integrado de verdade: _finish_turn() precisa consultar o
## trigger (WorldEventManager.maybe_spawn_dragon), nao so avancar eventos
## ja existentes.
func test_finish_turn_spawns_a_dragon_event_once_the_trigger_condition_is_met():
	var setup = _setup_minimal_hex_grid_with_one_rival()
	setup.hex_grid.map_seed = 54321

	var turn := WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN
	while not WorldEventTrigger.should_spawn_dragon(setup.hex_grid.map_seed, turn):
		turn += 1
		assert_lt(turn, WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN + 5000, "nenhum turno disparou o trigger num intervalo razoavel")
	TurnManager.turn_number = turn

	GameManager._on_turn_changed(0, 0)

	assert_eq(WorldEventManager.active_events.size(), 1, "_finish_turn() deveria ter consultado o trigger e criado o Dragao-evento")
	assert_true(WorldEventManager.active_events[0] is DragonEvent)

	setup.hex_grid.queue_free()

## Roadmap "sistema de menu de jogo moderno" -- pedido do usuario: "voltar
## pro menu principal de fato volta pro menu principal, atualmente ele
## continua na partida mas mostrando as opcoes de menu". end_match() e o
## fix: encerra a partida de verdade (nao so a apresentacao, que continua
## responsabilidade de Main.gd) -- estado, fila de IA em andamento,
## eventos de mundo, entidades do mapa e referencias de jogador.

func test_end_match_resets_state_to_menu():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.setup_players(hex_grid)
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "pre-condicao")

	GameManager.end_match()

	assert_eq(GameManager.state, GameManager.GameState.MENU)
	hex_grid.queue_free()

## A causa raiz do bug relatado: GameManager._process() so e gateado por
## is_turn_processing, nunca por `state` -- uma IA no meio de um turno
## espalhado continuava sendo drenada em segundo plano mesmo depois de
## "voltar ao menu", antes deste fix.
func test_end_match_stops_turn_processing_and_clears_ai_queue():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.setup_players(hex_grid)
	GameManager.is_turn_processing = true
	GameManager._ai_turn_queue = [{"kind": "rival"}, {"kind": "monster"}]
	GameManager._ai_batch_timer = 0.05

	GameManager.end_match()

	assert_false(GameManager.is_turn_processing)
	assert_true(GameManager._ai_turn_queue.is_empty())
	assert_eq(GameManager._ai_batch_timer, 0.0)
	hex_grid.queue_free()

func test_end_match_clears_players_and_current_save_slot():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 2
	GameManager.setup_players(hex_grid)
	GameManager.current_save_slot = "slot_em_andamento"
	assert_false(GameManager.players.is_empty(), "pre-condicao")

	GameManager.end_match()

	assert_true(GameManager.players.is_empty())
	assert_true(GameManager.rival_players.is_empty())
	assert_null(GameManager.human_player)
	assert_eq(GameManager.current_save_slot, "")
	hex_grid.queue_free()

func test_end_match_clears_world_events():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.setup_players(hex_grid)
	WorldEventManager.active_events = [_StubWorldEvent.new()]
	WorldEventManager._next_event_id = 3

	GameManager.end_match()

	assert_true(WorldEventManager.active_events.is_empty())
	assert_eq(WorldEventManager._next_event_id, 0)
	hex_grid.queue_free()

## HexGrid.reset_to_empty() (novo wrapper publico em torno do mesmo
## _clear_entities() que generate_map() ja chama no inicio de toda
## partida nova) e quem de fato libera unidades/cidades do mapa.
func test_end_match_calls_hex_grid_reset_to_empty():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.setup_players(hex_grid)
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), GameManager.human_player, Vector2i(0, 0))
	hex_grid.units_by_coord[Vector2i(0, 0)] = unit
	assert_false(hex_grid.units_by_coord.is_empty(), "pre-condicao")

	GameManager.end_match()

	assert_true(hex_grid.units_by_coord.is_empty(), "end_match() deveria ter liberado as entidades do mapa abandonado")
	hex_grid.queue_free()
	if is_instance_valid(unit):
		unit.queue_free()
