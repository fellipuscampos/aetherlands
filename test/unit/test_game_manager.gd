extends GutTest

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
	GameManager.human_race = _original_human_race
	GameManager.debug_mode = _original_debug_mode
	GameManager.stagger_ai_turns = _original_stagger_ai_turns
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id
	GameManager._ai_batch_timer = 0.0

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

## Roadmap "Parte B" B4 — setup_players() gera personalidade (Civilization
## Personality.generate) pra humano e todo rival, derivada de hex_grid.
## map_seed. O valor exato bate com generate(race, map_seed+OFFSET[+slot])
## — este UNICO teste ja protege o contrato de nao-colisao de slot (humano
## =+0, rival no indice i=+i+1): se dois slots colidissem, a igualdade
## exata falharia.
func test_setup_players_personality_matches_civilization_personality_generate_for_the_grids_map_seed():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.map_seed = 4242
	GameManager.rival_count = 3

	GameManager.setup_players(hex_grid)

	var human := GameManager.human_player
	assert_eq(human.personality, CivilizationPersonality.generate(human.civ.race, hex_grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET))
	for i in range(GameManager.rival_players.size()):
		var rival := GameManager.rival_players[i]
		assert_eq(rival.personality, CivilizationPersonality.generate(rival.civ.race, hex_grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET + i + 1))

	hex_grid.queue_free()

func test_setup_players_assigns_a_personality_with_all_five_axes_to_everyone():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.rival_count = 3

	GameManager.setup_players(hex_grid)

	assert_eq(GameManager.human_player.personality.size(), 5)
	for rival in GameManager.rival_players:
		assert_eq(rival.personality.size(), 5)

	hex_grid.queue_free()

## Guarda de regressao da propriedade central de B4: regenerar com o MESMO
## map_seed reproduz a personalidade IDENTICA — e o que garante que um
## save/load nunca muda a personalidade de ninguem, sem precisar guardar
## campo nenhum (ver test_save_manager.gd pro fluxo real de save/load).
func test_setup_players_personality_is_deterministic_for_the_same_map_seed():
	var hex_grid_a := HexGrid.new()
	hex_grid_a._ready()
	hex_grid_a.map_seed = 777
	GameManager.rival_count = 3
	GameManager.setup_players(hex_grid_a)
	var human_personality_a := GameManager.human_player.personality.duplicate()
	var rival_personalities_a := []
	for rival in GameManager.rival_players:
		rival_personalities_a.append(rival.personality.duplicate())

	var hex_grid_b := HexGrid.new()
	hex_grid_b._ready()
	hex_grid_b.map_seed = 777
	GameManager.setup_players(hex_grid_b)

	assert_eq(GameManager.human_player.personality, human_personality_a)
	for i in range(GameManager.rival_players.size()):
		assert_eq(GameManager.rival_players[i].personality, rival_personalities_a[i])

	hex_grid_a.queue_free()
	hex_grid_b.queue_free()

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

## Roadmap "Fase F" F3 -- check_game_over() virou check_victories(),
## autoridade unica das 3 vitorias (antes so Dominacao). Nome do teste
## atualizado, comportamento identico pro caso de Dominacao.
func test_check_victories_requires_all_rivals_eliminated_for_dominance():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null) # humano ainda vivo

	var alive_rival = PlayerData.new(CivilizationData.new())
	alive_rival.units.append(null)
	var dead_rival = PlayerData.new(CivilizationData.new())
	GameManager.rival_players = [alive_rival, dead_rival]

	GameManager.check_victories()

	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "ainda tem 1 rival vivo, o jogo nao deveria terminar")

func test_check_victories_declares_dominance_when_every_rival_is_eliminated():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)

	var dead_rival_a = PlayerData.new(CivilizationData.new())
	var dead_rival_b = PlayerData.new(CivilizationData.new())
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

func test_update_territorial_streak_increments_when_threshold_met():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owned_tiles = [Vector2i(0, 0)] # 100% do mapa (1 de 1 tile habitavel)

	player.cities.append(city)

	GameManager._update_territorial_streak(player)

	assert_eq(player.territorial_streak, 1)
	city.queue_free()
	hex_grid.queue_free()

func test_update_territorial_streak_resets_below_threshold():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	player.territorial_streak = 3 # ja vinha sustentando -- deveria zerar, nao so parar de crescer
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owned_tiles = [Vector2i(0, 0)] # 1 de 3 tiles = 33%, abaixo do limiar de 50%
	player.cities.append(city)

	GameManager._update_territorial_streak(player)

	assert_eq(player.territorial_streak, 0)
	city.queue_free()
	hex_grid.queue_free()

func _make_ritual_grid_with_three_nodes() -> HexGrid:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for i in range(3):
		var coord := Vector2i(i, 0)
		hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
		hex_grid.tiles[coord].resource = "mana_node"
	return hex_grid

func test_update_arcane_ritual_does_nothing_when_inactive():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())

	GameManager._update_arcane_ritual(player)

	assert_false(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_streak, 0)
	hex_grid.queue_free()

func test_update_arcane_ritual_increments_streak_and_pays_upkeep_when_sustained():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owner_player = player
	city.owned_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	hex_grid.cities_by_coord[city.coord] = city
	player.cities.append(city)
	player.arcane_ritual_active = true
	player.arcane_ritual_city_coord = city.coord
	player.arcane_ritual_streak = 2
	player.mana = 50.0

	GameManager._update_arcane_ritual(player)

	assert_true(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_streak, 3)
	assert_almost_eq(player.mana, 50.0 - VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN, 0.001)
	city.queue_free()
	hex_grid.queue_free()

func test_update_arcane_ritual_interrupts_when_sanctuary_city_is_lost():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	player.arcane_ritual_active = true
	player.arcane_ritual_city_coord = Vector2i(0, 0) # nenhuma cidade registrada nesse coord -- capturada/destruida
	player.arcane_ritual_streak = 4
	player.mana = 1000.0

	GameManager._update_arcane_ritual(player)

	assert_false(player.arcane_ritual_active, "cidade-sede perdida deveria interromper por completo, nao so pausar")
	assert_eq(player.arcane_ritual_streak, 0)
	hex_grid.queue_free()

func test_update_arcane_ritual_interrupts_when_nodes_drop_below_three():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	hex_grid.tiles[Vector2i(2, 0)].resource = "" # perdeu 1 Nodulo -- so 2 restam
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owner_player = player
	city.owned_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	hex_grid.cities_by_coord[city.coord] = city
	player.cities.append(city)
	player.arcane_ritual_active = true
	player.arcane_ritual_city_coord = city.coord
	player.arcane_ritual_streak = 4
	player.mana = 1000.0

	GameManager._update_arcane_ritual(player)

	assert_false(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_streak, 0)
	city.queue_free()
	hex_grid.queue_free()

func test_update_arcane_ritual_interrupts_when_mana_insufficient_for_upkeep():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owner_player = player
	city.owned_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	hex_grid.cities_by_coord[city.coord] = city
	player.cities.append(city)
	player.arcane_ritual_active = true
	player.arcane_ritual_city_coord = city.coord
	player.arcane_ritual_streak = 4
	player.mana = VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN - 1.0 # insuficiente por pouco

	GameManager._update_arcane_ritual(player)

	assert_false(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_streak, 0)
	assert_eq(player.mana, VictoryConditions.ARCANE_RITUAL_UPKEEP_COST_PER_TURN - 1.0, "manutencao nao paga NAO deveria descontar nada (nunca deixar mana negativa)")
	city.queue_free()
	hex_grid.queue_free()

func _make_activation_ready_player(hex_grid: HexGrid) -> PlayerData:
	var player = PlayerData.new(CivilizationData.new())
	for tech_id in ["canalizacao_base", "alquimia_botanica", "transmutacao_rocha", "geomancia"]:
		player.researched_techs[tech_id] = true
	var city := City.new()
	city.coord = Vector2i(0, 0)
	city.owned_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	player.cities.append(city)
	return player

func test_activate_arcane_ritual_fails_without_prerequisites():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var player = PlayerData.new(CivilizationData.new())
	player.mana = 1000.0

	assert_false(GameManager.activate_arcane_ritual(player))
	assert_false(player.arcane_ritual_active)
	hex_grid.queue_free()

func test_activate_arcane_ritual_fails_without_sanctuary():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player := _make_activation_ready_player(hex_grid)
	player.mana = 1000.0
	# pre-requisitos batidos, mas NENHUMA cidade tem o Santuario construido

	assert_false(GameManager.activate_arcane_ritual(player))
	player.cities[0].queue_free()
	hex_grid.queue_free()

func test_activate_arcane_ritual_fails_without_enough_mana():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player := _make_activation_ready_player(hex_grid)
	player.cities[0].buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	player.mana = VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST - 1.0

	assert_false(GameManager.activate_arcane_ritual(player))
	assert_false(player.arcane_ritual_active)
	assert_eq(player.mana, VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST - 1.0, "ativacao falha NAO deveria descontar mana nenhuma")
	player.cities[0].queue_free()
	hex_grid.queue_free()

func test_activate_arcane_ritual_succeeds_and_pays_initial_cost():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player := _make_activation_ready_player(hex_grid)
	player.cities[0].buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	player.mana = 1000.0

	var activated := GameManager.activate_arcane_ritual(player)

	assert_true(activated)
	assert_true(player.arcane_ritual_active)
	assert_eq(player.arcane_ritual_city_coord, player.cities[0].coord)
	assert_eq(player.arcane_ritual_streak, 0)
	assert_almost_eq(player.mana, 1000.0 - VictoryConditions.ARCANE_RITUAL_ACTIVATION_COST, 0.001)
	player.cities[0].queue_free()
	hex_grid.queue_free()

func test_activate_arcane_ritual_fails_if_already_active():
	var hex_grid := _make_ritual_grid_with_three_nodes()
	GameManager.hex_grid = hex_grid
	var player := _make_activation_ready_player(hex_grid)
	player.cities[0].buildings[VictoryConditions.SANCTUARY_BUILDING_ID] = true
	player.mana = 1000.0
	player.arcane_ritual_active = true # ja ativo de antes

	assert_false(GameManager.activate_arcane_ritual(player), "nao deveria ser possivel reativar/pagar de novo um ritual ja ativo")
	player.cities[0].queue_free()
	hex_grid.queue_free()

func test_check_victories_declares_territorial_dominance_and_emits_both_signals():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null) # vivo -- Dominacao nao deveria disparar primeiro
	var rival = PlayerData.new(CivilizationData.new())
	rival.units.append(null)
	GameManager.rival_players = [rival]
	GameManager.human_player.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS
	watch_signals(EventBus)

	GameManager.check_victories()

	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "game_over", [true])
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [GameManager.human_player, VictoryConditions.VICTORY_TYPE_TERRITORIAL])

func test_check_victories_declares_arcane_ascension():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)
	var rival = PlayerData.new(CivilizationData.new())
	rival.units.append(null)
	GameManager.rival_players = [rival]
	GameManager.human_player.arcane_ritual_active = true
	GameManager.human_player.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS
	watch_signals(EventBus)

	GameManager.check_victories()

	assert_eq(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [GameManager.human_player, VictoryConditions.VICTORY_TYPE_ARCANE])

## Desempate FIXO combinado com o usuario: ordem tecnica, nunca prioridade
## estrategica entre vitorias (ver comentario de check_victories).

func test_check_victories_resolves_same_player_multiple_conditions_by_fixed_type_order():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)
	var rival = PlayerData.new(CivilizationData.new())
	rival.units.append(null)
	GameManager.rival_players = [rival]
	GameManager.human_player.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS
	GameManager.human_player.arcane_ritual_active = true
	GameManager.human_player.arcane_ritual_streak = VictoryConditions.ARCANE_SUSTAIN_TURNS
	watch_signals(EventBus)

	GameManager.check_victories()

	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [GameManager.human_player, VictoryConditions.VICTORY_TYPE_TERRITORIAL]) # Territorial vem antes de Arcana na ordem fixa de tipos

func test_check_victories_resolves_different_players_by_fixed_player_order():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)
	var rival = PlayerData.new(CivilizationData.new())
	rival.units.append(null)
	GameManager.rival_players = [rival]
	GameManager.human_player.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS
	rival.territorial_streak = VictoryConditions.TERRITORIAL_SUSTAIN_TURNS # os dois batem ao mesmo tempo
	watch_signals(EventBus)

	GameManager.check_victories()

	assert_signal_emitted_with_parameters(EventBus, "victory_achieved", [GameManager.human_player, VictoryConditions.VICTORY_TYPE_TERRITORIAL]) # humano vem primeiro na ordem fixa de jogadores ([human]+rivals)

func test_check_victories_never_mutates_streak_state():
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.units.append(null)
	var rival = PlayerData.new(CivilizationData.new())
	rival.units.append(null)
	GameManager.rival_players = [rival]
	GameManager.human_player.territorial_streak = 2 # abaixo do limiar -- nao deveria disparar nem mudar

	GameManager.check_victories()
	GameManager.check_victories() # MESMA cadencia de SelectionManager/SaveManager chamando 2x

	assert_eq(GameManager.human_player.territorial_streak, 2, "check_victories nunca deveria escrever streak, so ler")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)

## Debug: completa a pesquisa atual na hora, reaproveitando
## _process_research() de verdade (mesmo efeito colateral de marcar
## researched_techs e limpar current_research).
func test_debug_complete_current_research_finishes_the_selected_tech():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.current_research = "canalizacao_base"

	GameManager.debug_complete_current_research()

	assert_true(GameManager.human_player.researched_techs.has("canalizacao_base"))
	assert_eq(GameManager.human_player.current_research, "")

func test_debug_complete_current_research_does_nothing_without_a_selected_tech():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.current_research = ""

	GameManager.debug_complete_current_research() # nao deveria travar nem levantar erro nenhum

	assert_eq(GameManager.human_player.current_research, "")

## Debug: pedido do usuario "libere no modo debug, quando eu ativar, tudo
## liberado, tudo fica disponivel todas as pesquisas ficam feitas" — ligar
## marca TODA tecnologia como pesquisada na hora (nao so a que estava
## selecionada, diferente de debug_complete_current_research) e limpa
## qualquer selecao/progresso de pesquisa em andamento.
func test_set_debug_mode_true_marks_every_tech_as_researched():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.current_research = "canalizacao_base"
	GameManager.human_player.research_progress = 5.0

	GameManager.set_debug_mode(true)

	for tech in TechDatabase.all_techs():
		assert_true(GameManager.human_player.researched_techs.has(tech.id), "%s deveria estar marcada como pesquisada" % tech.id)
	assert_eq(GameManager.human_player.current_research, "")
	assert_eq(GameManager.human_player.research_progress, 0.0)
	assert_true(GameManager.debug_mode)

func test_set_debug_mode_false_turns_off_the_flag_without_unresearching_anything():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.set_debug_mode(true)

	GameManager.set_debug_mode(false)

	assert_false(GameManager.debug_mode)
	assert_true(GameManager.human_player.researched_techs.has("canalizacao_base"), "desligar nao deveria desfazer pesquisas ja concedidas")

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
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # so o piso minimo de producao (City.CITY_CENTER_MIN_PRODUCTION), sem debug 1 turno nao seria nem perto do suficiente
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	var city = hex_grid.found_city(coord, GameManager.human_player, "Capital")
	city.set_production("warrior") # 15 producao, Guarda nao depende de predio nenhum
	GameManager.set_debug_mode(true)

	GameManager._on_turn_changed(0, 0)

	var spawned := false
	for unit in GameManager.human_player.units:
		if unit.unit_data.visual_kind == "warrior":
			spawned = true
	assert_true(spawned, "com modo debug ligado, o Guarda deveria ter sido produzido no mesmo turno")

	hex_grid.queue_free()

func test_debug_mode_off_does_not_speed_up_production():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var rival_coord := Vector2i(10, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	hex_grid.tiles[rival_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.rival_players = [rival]
	GameManager.players = [GameManager.human_player, rival]
	hex_grid.found_city(rival_coord, rival, "Capital Rival")
	var city = hex_grid.found_city(coord, GameManager.human_player, "Capital")
	city.set_production("warrior")
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
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = PlayerData.new(CivilizationData.new())
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
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = PlayerData.new(CivilizationData.new())
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
