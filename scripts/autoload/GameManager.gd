extends Node

enum GameState { MENU, PLAYING, GAME_OVER }

const GARRISON_HEAL_FRACTION := 0.25 # % do HP maximo curado por turno guarnecido
## % do HP maximo curado por turno so por estar Fortificado (Unit.fortified,
## ver SelectionManager.fortify_selected) — mais fraco que guarnicao numa
## cidade de proposito (GARRISON_HEAL_FRACTION), fortificar no campo aberto
## nunca deveria curar tao rapido quanto estar dentro dos proprios muros.
const FORTIFY_HEAL_FRACTION := 0.1
const SCIENCE_PER_POPULATION := 1.0 # "ciencia" por turno = populacao total das cidades

var state: GameState = GameState.MENU
var map_width: int = 25
var map_height: int = 25
var hex_grid: HexGrid

var players: Array[PlayerData] = []
var human_player: PlayerData
var rival_players: Array[PlayerData] = []

## Escolhido na tela de titulo antes de start_new_game(); "" mantem o padrao.
var human_kingdom_name: String = ""
const DEFAULT_KINGDOM_NAME := "Reino de Aldenmark"

## Raca do jogador (CivilizationData.race, ver UnitDatabase.RACE_UNIQUE_
## KIND) — escolhida na tela de titulo (TitleScreen._selected_race),
## pedido do usuario: "crie um sistema onde ao iniciar o game a gente pode
## escolher tambem a raca que vai jogar... elfo, anao, orc e humanos, ai
## as implicacoes disso voce pode criar tambem" (a implicacao escolhida:
## cada raca destrava sua propria tropa de elite exclusiva, ver City.
## can_train). "human" e o padrao — precisa continuar valido pra qualquer
## caminho que pule a tela de titulo (ex: testes que chamam setup_players
## direto sem passar por TitleScreen).
var human_race: String = "human"

## Escolhido na tela de titulo (1 a RIVAL_CIVS.size()); setup_players()
## limita (clamp) pro caso de vir de um save antigo com mais civs do que
## o pool atual suporta.
var rival_count: int = 1

## Cada rival agora e uma civilizacao de fantasia de verdade, nao mais uma
## copia do reino do jogador so trocando nome/cor — pedido do usuario:
## "insira outras civilizacoes de fantasia, tipo os anoes, os orcs, os
## elfos... voce cria tropas especificas pra essas civilizacoes". `race`
## da acesso a uma tropa exclusiva no pool de producao da IA (ver
## RivalAI._military_kinds_for/RACE_UNIQUE_KIND); "Reino de Ferroeste"
## (ja soava a fortaleza de ferro) e "Horda das Brumas" (ja tinha um Xama
## como lider) so precisaram do campo novo, o antigo "Cla Corvo Negro"
## virou o reino elfico pra fechar o trio classico anao/orc/elfo.
const RIVAL_CIVS := [
	{"name": "Reino Elfico de Verdemata", "leader": "Rainha Aelaria", "color": Color(0.25, 0.55, 0.35), "race": "elf"},
	{"name": "Reino de Ferroeste", "leader": "Rei Bramwell", "color": Color(0.55, 0.42, 0.18), "race": "dwarf"},
	{"name": "Horda das Brumas", "leader": "Xama Skarn", "color": Color(0.4, 0.5, 0.25), "race": "orc"},
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
	human_civ.race = human_race
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
		rival_civ.race = info.get("race", "")
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
	if city and city.owner_player == unit.owner_player:
		if unit.hp < unit.unit_data.max_hp:
			unit.hp = min(unit.hp + unit.unit_data.max_hp * GARRISON_HEAL_FRACTION, unit.unit_data.max_hp)
		return
	_heal_if_fortified(unit)

## Cura passiva do modo Fortificar (Unit.fortified) — pedido do usuario:
## "se você tiver ferido, você fica se curando um pouco todo turno". So
## chamada quando a unidade NAO esta guarnicionada (ver _heal_if_garrisoned
## acima) pra nunca curar duas vezes no mesmo turno.
func _heal_if_fortified(unit: Unit) -> void:
	if unit.fortified and unit.hp < unit.unit_data.max_hp:
		unit.hp = min(unit.hp + unit.unit_data.max_hp * FORTIFY_HEAL_FRACTION, unit.unit_data.max_hp)

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
## mapa (onde o humano comeca), numa elipse escalada pela largura/altura
## reais do mapa retangular (nao mais um raio unico com achatamento fixo
## de 0.6 — aquele numero era so pra caber no losango/hexagono antigo,
## ver historico). 0.35 = 70% da METADE de cada dimensao, mesma proporcao
## de distancia do centro que a formula antiga usava.
func _rival_origin(index: int, count: int) -> Vector2i:
	var angle = TAU * float(index) / float(max(count, 1))
	var dist_q = float(map_width) * 0.35
	var dist_r = float(map_height) * 0.35
	var q = int(round(cos(angle) * dist_q))
	var r = int(round(sin(angle) * dist_r))
	return Vector2i(q, r)

func _on_turn_changed(_turn_number: int, _player_index: int) -> void:
	if state == GameState.GAME_OVER:
		return

	for player in players:
		for unit in player.units:
			unit.reset_movement()
			# Continua um pedido de "mover ate" pendente (Unit.move_order_
			# target, ver SelectionManager._try_queue_move_order/HexGrid.
			# continue_move_order) — pedido do usuario: "no civilization eu
			# posso colocar pra ela se mover pra um lugar longe... o
			# movimento fica gravado e todo turno essa tropa vai se
			# movendo". So a IA rival nunca seta esse campo (continua
			# decidindo movimento do proprio jeito, ver RivalAI.
			# move_unit_toward), entao isto e um no-op de graca pros
			# units dela — nao precisa checar humano vs rival aqui.
			hex_grid.continue_move_order(unit)
			# Continua "Explorar" (Unit.exploring) pelo mesmo motivo — so o
			# jogador humano liga isso (SelectionManager.toggle_explore_
			# selected), entao e um no-op pra IA/monstro tambem. Mutuamente
			# exclusivo com move_order_target por construcao (as duas
			# funcoes de toggle desligam uma a outra), entao chamar as duas
			# sempre e seguro.
			hex_grid.explore_step(unit)
			_heal_if_garrisoned(unit)
			_apply_regen(unit)

	# Monstro neutro (owner_player == null, ver MonsterDatabase) tambem
	# precisa repor movimento antes de agir — MonsterAI.take_turn (abaixo)
	# depende disso pra Invasor/Cacador conseguirem se mover. Sem cura por
	# guarnicao/regeneracao passiva aqui de proposito: nenhum dos 5 tipos
	# de monstro tem regen_fraction/guarnicao em cidade propria — extensao
	# futura facil, nao necessaria agora.
	for unit in hex_grid.neutral_units():
		unit.reset_movement()

	for rival in rival_players:
		RivalAI.decide_production(rival)
		RivalAI.decide_research(rival)

	for player in players:
		_process_research(player)
		var mana_income := 0.0
		for city in player.cities.duplicate():
			var result = city.process_turn(hex_grid)
			player.gold += result.gold
			mana_income += result.mana
			if result.spawn_unit_kind != "":
				var spawn_coord = WorldSetup.find_spawn_tile(hex_grid, city.coord)
				hex_grid.spawn_unit(spawn_coord, UnitDatabase.create_unit(result.spawn_unit_kind), player)
			if result.built_kind != "":
				if result.built_coord != City.NO_PENDING_COORD:
					hex_grid.place_building(result.built_coord, result.built_kind, player)
				if player == human_player:
					var building: BuildingData = BuildingDatabase.get_building(result.built_kind)
					EventBus.notify.emit("%s concluiu: %s" % [city.city_name, building.display_name], "confirm")
		player.mana += mana_income
		player.mana_income_per_turn = mana_income

	for rival in rival_players:
		RivalAI.take_turn(rival, hex_grid, human_player)

	# Covis de Monstro reforcam a propria guarda com o tempo (pedido do
	# usuario: "ao redor de um covil de goblin pode spawnar ate 5
	# goblins... tem que ter um limite pra nao spawnar pra sempre") — ver
	# HexGrid.process_monster_lairs. Passa o turno atual pra chance de
	# reforco escalar com o tempo (ver HexGrid._reinforce_chance). Antes de
	# recompute_fog pra qualquer monstro novo ja aparecer/sumir corretamente
	# no fog deste turno.
	hex_grid.process_monster_lairs(TurnManager.turn_number)

	# Acampamentos Barbaros: cada monstro neutro age por conta propria
	# (guardar territorio / marchar sobre a cidade mais proxima / cacar
	# presa isolada — ver MonsterAI.gd). Depois do reforco de proposito:
	# um grupo recem-nascido ja pode agir no mesmo turno em que aparece,
	# mesmo precedente que unidade de rival recem-treinada ja tinha
	# (RivalAI.take_turn acima roda depois da producao de cidade).
	MonsterAI.take_turn(hex_grid, TurnManager.turn_number)

	hex_grid.recompute_fog(human_player)
	hex_grid.refresh_construction_markers() # predios concluidos neste turno somem do "em obra"
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

## --- Debug (HUD.gd, botao "Debug" so em builds de desenvolvimento via
## OS.is_debug_build()) ---

## Forca o fim de jogo na hora, sem esperar eliminar unidade/cidade
## nenhuma de verdade — reaproveita _end_game() (mesmo sinal
## EventBus.game_over que o fim de jogo real usa), so pula a checagem de
## check_game_over(). Util pra testar a tela de vitoria/derrota sem
## precisar jogar uma partida inteira.
func debug_force_game_over(victory: bool) -> void:
	_end_game(victory)

## Completa a pesquisa atual do jogador humano na hora. Reaproveita
## _process_research() de verdade (mesmo toast de "Tecnologia
## pesquisada", mesma logica de completar) — so garante progresso
## suficiente antes de chamar, em vez de duplicar a condicao de
## conclusao aqui.
func debug_complete_current_research() -> void:
	if human_player == null or human_player.current_research == "":
		return
	var tech: TechData = TechDatabase.get_tech(human_player.current_research)
	if tech == null:
		return
	human_player.research_progress = tech.cost
	_process_research(human_player)
