extends Node

enum GameState { MENU, PLAYING, GAME_OVER }

const GARRISON_HEAL_FRACTION := 0.25 # % do HP maximo curado por turno guarnecido
const SCIENCE_PER_POPULATION := 1.0 # "ciencia" por turno = populacao total das cidades

var state: GameState = GameState.MENU
var map_radius: int = 12
var hex_grid: HexGrid

var players: Array[PlayerData] = []
var human_player: PlayerData
var rival_players: Array[PlayerData] = []

## Escolhido na tela de titulo antes de start_new_game(); "" mantem o padrao.
var human_kingdom_name: String = ""
const DEFAULT_KINGDOM_NAME := "Reino de Aldenmark"

## Escolhido na tela de titulo (1 a RIVAL_CIVS.size()); setup_players()
## limita (clamp) pro caso de vir de um save antigo com mais civs do que
## o pool atual suporta.
var rival_count: int = 1

const RIVAL_CIVS := [
	{"name": "Cla Corvo Negro", "leader": "Lorde Vaelkor", "color": Color(0.6, 0.15, 0.15)},
	{"name": "Reino de Ferroeste", "leader": "Rei Bramwell", "color": Color(0.15, 0.5, 0.2)},
	{"name": "Horda das Brumas", "leader": "Xama Skarn", "color": Color(0.5, 0.35, 0.75)},
]

## Escolhido na tela de titulo; so afeta a economia dos RIVAIS (PlayerData.
## yield_multiplier, aplicado em City.collect_yields) — o jogador humano
## fica sempre em 1.0. "normal" preserva o comportamento de sempre.
var difficulty: String = "normal"
const DIFFICULTY_MULTIPLIERS := {"easy": 0.75, "normal": 1.0, "hard": 1.5}

func _ready() -> void:
	TurnManager.turn_changed.connect(_on_turn_changed)

func start_new_game(grid: HexGrid) -> void:
	setup_players(grid)
	_spawn_starting_forces()
	hex_grid.recompute_fog(human_player)

## Monta jogadores/civs do zero, sem povoar unidades/cidades — usado tanto
## por start_new_game() (jogo novo, spawna forcas iniciais em seguida) quanto
## por SaveManager.load_game() (que reconstroi unidades/cidades a partir do
## arquivo salvo em vez de usar o spawn padrao).
func setup_players(grid: HexGrid) -> void:
	hex_grid = grid
	state = GameState.PLAYING
	players.clear()
	rival_players.clear()

	var human_civ := CivilizationData.new()
	human_civ.civ_name = human_kingdom_name if human_kingdom_name != "" else DEFAULT_KINGDOM_NAME
	human_civ.leader_name = "Rainha Elara"
	human_civ.color = Color(0.2, 0.45, 0.85)
	human_player = PlayerData.new(human_civ)
	players.append(human_player)

	var count = clamp(rival_count, 1, RIVAL_CIVS.size())
	var mult: float = DIFFICULTY_MULTIPLIERS.get(difficulty, 1.0)
	for i in range(count):
		var info: Dictionary = RIVAL_CIVS[i]
		var rival_civ := CivilizationData.new()
		rival_civ.civ_name = info.name
		rival_civ.leader_name = info.leader
		rival_civ.color = info.color
		var rival := PlayerData.new(rival_civ)
		rival.yield_multiplier = mult
		players.append(rival)
		rival_players.append(rival)

	# Diplomacia inicial: humano em guerra com todo rival (mesmo
	# comportamento de sempre, so que agora reversivel pela HUD — ver
	# Diplomacy.gd). Rivais nunca brigam entre si.
	for rival in rival_players:
		Diplomacy.declare_war(human_player, rival)

	TurnManager.player_count = 1
	TurnManager.turn_number = 1
	TurnManager.current_player_index = 0

## Unidade parada dentro da PROPRIA cidade recupera vida — vale tanto pro
## jogador quanto pro rival (nao e vantagem so da IA), e da uma razao de
## verdade pra recuar em vez de continuar brigando fraca (ver
## RivalAI._retreat).
func _heal_if_garrisoned(unit: Unit) -> void:
	var city = hex_grid.get_city_at(unit.coord)
	if city and city.owner_player == unit.owner_player and unit.hp < unit.unit_data.max_hp:
		unit.hp = min(unit.hp + unit.unit_data.max_hp * GARRISON_HEAL_FRACTION, unit.unit_data.max_hp)

## Ent (UnitData.regen_fraction): regenera sozinho todo turno, em qualquer
## lugar do mapa — nao depende de estar guarnicionado como o resto do
## exercito. Vale tanto pro jogador quanto pro rival, mesma logica de
## _heal_if_garrisoned.
func _apply_regen(unit: Unit) -> void:
	if unit.unit_data.regen_fraction > 0.0 and unit.hp < unit.unit_data.max_hp:
		unit.hp = min(unit.hp + unit.unit_data.max_hp * unit.unit_data.regen_fraction, unit.unit_data.max_hp)

## Ciencia = soma da populacao das cidades do jogador (simples de proposito,
## sem precisar de mais um tipo de yield em HexTileData). So acumula
## progresso se houver uma pesquisa em andamento — ciencia gerada sem
## nada selecionado e desperdicada, incentiva sempre ter algo na fila
## (RivalAI.decide_research cuida disso pro rival; o jogador escolhe pela
## HUD).
func _process_research(player: PlayerData) -> void:
	if player.current_research == "":
		return
	var tech: TechData = TechDatabase.get_tech(player.current_research)
	if tech == null:
		player.current_research = ""
		return

	var science := 0.0
	for city in player.cities:
		science += city.population * SCIENCE_PER_POPULATION
	player.research_progress += science

	if player.research_progress >= tech.cost:
		player.researched_techs[tech.id] = true
		player.research_progress = 0.0
		player.current_research = ""
		if player == human_player:
			EventBus.notify.emit("Tecnologia pesquisada: %s" % tech.display_name, "confirm")

func _spawn_starting_forces() -> void:
	# claimed_starts impede que duas capitais (do humano ou de rivais
	# diferentes) acabem escolhendo o mesmo tile inicial — ver comentario
	# em WorldSetup.find_start_tile.
	var claimed_starts: Array[Vector2i] = []

	var human_start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0), claimed_starts)
	claimed_starts.append(human_start)
	hex_grid.spawn_unit(human_start, UnitDatabase.create_unit("settler"), human_player)
	var warrior_coord = WorldSetup.find_spawn_tile(hex_grid, human_start)
	hex_grid.spawn_unit(warrior_coord, UnitDatabase.create_unit("warrior"), human_player)

	for i in range(rival_players.size()):
		var rival = rival_players[i]
		var rival_origin = _rival_origin(i, rival_players.size())
		var rival_start = WorldSetup.find_start_tile(hex_grid, rival_origin, claimed_starts)
		claimed_starts.append(rival_start)
		hex_grid.found_city(rival_start, rival, rival.civ.civ_name + " - Capital")
		var guard_coord = WorldSetup.find_spawn_tile(hex_grid, rival_start)
		hex_grid.spawn_unit(guard_coord, UnitDatabase.create_unit("warrior"), rival)

## Espalha os rivais em angulos igualmente espacados ao redor do centro do
## mapa (onde o humano comeca), a uma distancia proporcional ao raio —
## generalizacao da origem unica fixa que existia antes de multiplos
## rivais serem possiveis. O achatamento em r (*0.6) e so pra caber melhor
## no formato hexagonal/losangular do mapa gerado.
func _rival_origin(index: int, count: int) -> Vector2i:
	var angle = TAU * float(index) / float(max(count, 1))
	var dist = float(map_radius) * 0.7
	var q = int(round(cos(angle) * dist))
	var r = int(round(sin(angle) * dist * 0.6))
	return Vector2i(q, r)

func _on_turn_changed(_turn_number: int, _player_index: int) -> void:
	if state == GameState.GAME_OVER:
		return

	for player in players:
		for unit in player.units:
			unit.reset_movement()
			_heal_if_garrisoned(unit)
			_apply_regen(unit)

	for rival in rival_players:
		RivalAI.decide_production(rival)
		RivalAI.decide_research(rival)

	for player in players:
		_process_research(player)
		for city in player.cities.duplicate():
			var result = city.process_turn(hex_grid)
			player.gold += result.gold
			if result.spawn_unit_kind != "":
				var spawn_coord = WorldSetup.find_spawn_tile(hex_grid, city.coord)
				hex_grid.spawn_unit(spawn_coord, UnitDatabase.create_unit(result.spawn_unit_kind), player)
			if result.built_kind != "":
				if result.built_coord != City.NO_PENDING_COORD:
					hex_grid.place_building(result.built_coord, result.built_kind, player)
				if player == human_player:
					var building: BuildingData = BuildingDatabase.get_building(result.built_kind)
					EventBus.notify.emit("%s concluiu: %s" % [city.city_name, building.display_name], "confirm")

	for rival in rival_players:
		RivalAI.take_turn(rival, hex_grid, human_player)

	hex_grid.recompute_fog(human_player)
	check_game_over()

## Publico: tambem chamado logo apos um ataque do jogador (SelectionManager),
## para a vitoria/derrota aparecer na hora em vez de so no fim do turno.
func check_game_over() -> void:
	if state == GameState.GAME_OVER:
		return
	var any_rival_alive = false
	for rival in rival_players:
		if rival.units.size() > 0 or rival.cities.size() > 0:
			any_rival_alive = true
			break
	var human_alive = human_player.units.size() > 0 or human_player.cities.size() > 0
	if not any_rival_alive:
		_end_game(true)
	elif not human_alive:
		_end_game(false)

func _end_game(victory: bool) -> void:
	state = GameState.GAME_OVER
	EventBus.game_over.emit(victory)
