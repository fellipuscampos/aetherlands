extends Node

enum GameState { MENU, PLAYING, GAME_OVER }

const GARRISON_HEAL_FRACTION := 0.25 # % do HP maximo curado por turno guarnecido
## % do HP maximo curado por turno so por estar Fortificado (Unit.fortified,
## ver SelectionManager.fortify_selected) — mais fraco que guarnicao numa
## cidade de proposito (GARRISON_HEAL_FRACTION), fortificar no campo aberto
## nunca deveria curar tao rapido quanto estar dentro dos proprios muros.
const FORTIFY_HEAL_FRACTION := 0.1
const SCIENCE_PER_POPULATION := 1.0 # "ciencia" por turno = populacao total das cidades

## Pedido do usuario: "o Civilization nao faz tudo acontecer no mapa ao
## mesmo tempo, as pecas e acoes... se movem em fila... em pequenos
## grupos... assim diminui o lag na passada de turnos". `false` por padrao
## (preserva 100% do comportamento SINCRONO de sempre — critico pros
## testes GUT, que chamam _on_turn_changed() direto e checam o resultado
## na MESMA linha seguinte, sem passar frame nenhum; NENHUM teste liga este
## flag). Main.gd liga pra `true` uma vez, so na partida de verdade (ver
## comentario de stagger_ai_turns em _on_turn_changed) — GUT nunca passa
## por Main.gd (constroi HexGrid/PlayerData/GameManager na mao), entao o
## flag nunca acidentalmente vira true durante um teste.
var stagger_ai_turns: bool = false

## Quantas ACOES de IA (uma unidade rival OU um monstro decidindo/se
## movendo) processar por LOTE — pequeno de proposito ("pequenos grupos").
const AI_ACTIONS_PER_BATCH := 2

## Intervalo MINIMO (segundos) entre um lote de acoes de IA e o proximo,
## enquanto a fila (_ai_turn_queue) esta drenando — pedido do usuario numa
## rodada seguinte: "faca tambem as animacoes, as movimentacoes, ao inves
## de dar proximo e tudo se mover de uma vez, o que tambem causa lag...
## nao tudo ao mesmo tempo mas em fila". So espalhar a DECISAO por frame
## (a versao anterior, drenando direto em _process() sem pausa nenhuma)
## ainda deixava varias animacoes de movimento (Unit.slide_to,
## MOVE_DURATION = 0.35s) comecando quase juntas — a cada poucos frames um
## lote novo nascia e se somava aos Tweens ja em andamento, entao o pico
## de animacoes simultaneas continuava alto mesmo com a DECISAO
## espalhada. Pausar AI_BATCH_INTERVAL segundos entre lotes (bem menor que
## MOVE_DURATION, mas o bastante pra nao empilhar tudo) garante que so
## alguns poucos Tweens tocam ao mesmo tempo — visualmente perto do "uma
## tropa (ou um pequeno grupo) de cada vez" que o Civilization faz.
const AI_BATCH_INTERVAL := 0.12

## true enquanto a fila de acoes de IA do turno atual (rivais + monstros)
## ainda esta sendo drenada por _process() — HUD usa isto pra desabilitar
## E trocar o texto de "Encerrar Turno" nesse meio-tempo (ver HUD._process),
## evitando clicar de novo em cima de um turno que ainda nao terminou de
## verdade, e deixando claro pro jogador que a IA ainda esta "pensando".
var is_turn_processing: bool = false

var _ai_turn_queue: Array = [] # ver _build_rival_turn_items/_build_monster_turn_items/_process
var _ai_batch_timer: float = 0.0 # acumula delta ate AI_BATCH_INTERVAL, ver _process
## Coords de predios concluidos NESTE turno (ver loop de City.process_turn
## abaixo), consumido e limpo por _finish_turn() ao chamar hex_grid.
## refresh_construction_markers() — precisa ser campo (nao variavel local)
## porque _finish_turn() pode rodar em um frame POSTERIOR ao loop, quando
## stagger_ai_turns esta ligado (ver _process).
var _completed_building_coords_this_turn: Array[Vector2i] = []

var state: GameState = GameState.MENU
var map_width: int = 25
var map_height: int = 25
var hex_grid: HexGrid

var players: Array[PlayerData] = []
var human_player: PlayerData
var rival_players: Array[PlayerData] = []

## Escolhido na tela de titulo antes de start_new_game(); "" mantem o padrao
## (nome de reino da RACA escolhida, ver _default_kingdom_name_for_race —
## NAO mais um unico nome fixo humano, ver comentario la pro bug que isso
## corrigiu).
var human_kingdom_name: String = ""

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

## Nome de reino padrao quando o jogador deixa o campo de nome em branco na
## tela de configuracao — pedido/bug relatado pelo usuario: "escolhi outro
## reino e iniciei com o reino humano" (o campo mostrava so o PLACEHOLDER
## "Reino de Aldenmark", e antes disso o fallback aqui tambem so conhecia
## esse UNICO nome, fixo, do reino humano — entao qualquer jogador que
## escolhesse Elfo/Anao/Orc e nao digitasse um nome proprio acabava com o
## reino chamado "Reino de Aldenmark" mesmo assim, dando a impressao de
## estar jogando de humano mesmo com CivilizationData.race correto por
## baixo). Agora cada raca cai no proprio nome de reino (GameSetupScreen.
## RACE_INFO, mesma fonte usada pela tela de configuracao — sem duplicar
## os 4 nomes numa tabela separada aqui).
func _default_kingdom_name_for_race(race: String) -> String:
	var info: Dictionary = GameSetupScreen.RACE_INFO.get(race, GameSetupScreen.RACE_INFO.human)
	return info.display_name

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
	human_civ.civ_name = human_kingdom_name if human_kingdom_name != "" else _default_kingdom_name_for_race(human_race)
	human_civ.leader_name = "Rainha Elara"
	human_civ.color = Color(0.2, 0.45, 0.85)
	human_civ.race = human_race
	human_player = PlayerData.new(human_civ)
	# Roadmap "Parte B" B4 — personalidade DERIVADA de grid.map_seed, nunca
	# de randi() proprio (ver CivilizationPersonality.gd, comentario de
	# topo, pra por que isso dispensa SaveManager por completo). Slot 0
	# reservado pro humano; cada rival abaixo usa slot i+1 — nunca colidem
	# entre si nem com o humano.
	human_player.personality = CivilizationPersonality.generate(human_civ.race, hex_grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET)
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
		rival.personality = CivilizationPersonality.generate(rival_civ.race, hex_grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET + i + 1)
		players.append(rival)
		rival_players.append(rival)

	# Diplomacia inicial: todo mundo comeca em PAZ (pedido do usuario: "vamos
	# fazer com que todos comecem o jogo em paz, ao inves de comecar em
	# guerra") — antes disso o humano nascia automaticamente em guerra com
	# TODO rival, sem nenhuma escolha. PlayerData.enemies ja comeca vazio por
	# padrao (ver comentario do campo), entao basta NAO chamar Diplomacy.
	# declare_war aqui; guerra agora so acontece se o jogador humano
	# declarar de proposito pela HUD (ver HUD._on_declare_war_pressed) — a
	# IA nunca declara guerra por conta propria (RivalAI._choose_target ja
	# respeita is_at_war_with, ver comentario la).
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
	# Roadmap de gameplay Fase 3: ciencia era a UNICA "yield" que nunca
	# passava por multiplicador nenhum (nem o de dificuldade que ja existe
	# pra IA, nem agora o racial do elfo) — pipeline paralela desde sempre
	# desconectada de City.collect_yields(), ver comentario da funcao. Fix
	# minimo: aplicar os MESMOS dois multiplicadores aqui tambem, sem
	# precisar mover ciencia pra dentro de collect_yields de verdade.
	var race: String = player.civ.race if player.civ else ""
	var mult := player.yield_multiplier * RaceEconomy.science_multiplier_for(race)
	player.research_progress += science * mult

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
## da pegada FIXA do continente Principal (TitleScreen.MAIN_ZONE_SIZE, nao
## mais map_width/map_height ao vivo — pedido do usuario: "expandir o
## tamanho fixo do mapa pra acomodar dois novos continentes especiais").
## Sem essa trava, os rivais se espalhariam pelo canvas TOTAL (agora bem
## maior, pra caber os continentes Vulcanico/de Cristal), caindo no
## oceano de separacao ou dentro de um dos continentes especiais em vez
## de sempre nascerem dentro do continente Principal, igual sempre foi.
## 0.35 = 70% da METADE de cada dimensao, mesma proporcao de distancia do
## centro que a formula antiga usava.
func _rival_origin(index: int, count: int) -> Vector2i:
	var angle = TAU * float(index) / float(max(count, 1))
	var dist_q = float(TitleScreen.MAIN_ZONE_SIZE.width) * 0.35
	var dist_r = float(TitleScreen.MAIN_ZONE_SIZE.height) * 0.35
	var q = int(round(cos(angle) * dist_q))
	var r = int(round(sin(angle) * dist_r))
	return Vector2i(q, r)

func _on_turn_changed(_turn_number: int, _player_index: int) -> void:
	if state == GameState.GAME_OVER:
		return
	# Defensivo: nao deveria acontecer de verdade (HUD desabilita "Encerrar
	# Turno" enquanto is_turn_processing, ver HUD._process), mas TurnManager.
	# end_turn() nao tem trava propria nenhuma — se alguem chamar de novo no
	# meio da fila ainda drenando, ignora em vez de embaralhar _ai_turn_queue
	# com dois turnos ao mesmo tempo.
	if is_turn_processing:
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
		RivalAI.decide_production(rival, hex_grid, human_player)
		RivalAI.decide_research(rival)
		RivalAI.decide_war(rival, hex_grid, human_player)
		# Roadmap "Parte C" C3 — logo apos decide_war de proposito: uma
		# guerra recem-declarada ja ganha campanha (objetivo+alvo
		# persistentes) antes do take_turn/combate deste mesmo turno rodar
		# mais abaixo (ver RivalAI.decide_campaign).
		RivalAI.decide_campaign(rival, hex_grid, human_player)
		RivalAI.decide_trade(rival, hex_grid, human_player)

	for player in players:
		_process_research(player)
		var mana_income := 0.0
		for city in player.cities.duplicate():
			# Modo debug (ver set_debug_mode acima): "o tempo de fazer
			# qualquer unidade e 1 turno" — completa a producao atual
			# (unidade OU predio, mesmo criterio de City.process_turn) so
			# pra cidade do jogador HUMANO, antes de processar o turno de
			# verdade, em vez de duplicar a logica de spawn/construcao aqui.
			if debug_mode and player == human_player:
				city.stored_production = max(city.stored_production, city.production_cost())
			var result = city.process_turn(hex_grid)
			player.gold += result.gold
			mana_income += result.mana
			if result.spawn_unit_kind != "":
				var spawn_coord = WorldSetup.find_spawn_tile(hex_grid, city.coord)
				hex_grid.spawn_unit(spawn_coord, UnitDatabase.create_unit(result.spawn_unit_kind), player)
			if result.built_kind != "":
				if result.built_coord != City.NO_PENDING_COORD:
					hex_grid.place_building(result.built_coord, result.built_kind, player)
					_completed_building_coords_this_turn.append(result.built_coord)
				if player == human_player:
					var building: BuildingData = BuildingDatabase.get_building(result.built_kind)
					EventBus.notify.emit("%s concluiu: %s" % [city.city_name, building.display_name], "confirm")
		player.mana += mana_income
		player.mana_income_per_turn = mana_income
		Diplomacy.process_war_weariness_and_upkeep(player)

	# Roadmap de gameplay Fase 4A — FORA do loop `for player in players`
	# acima de proposito: cada rota conecta 2 jogadores, processar dentro
	# do loop por-jogador dessincronizaria a limpeza de rotas invalidas
	# (a MESMA TradeRoute aparece nas listas dos dois lados). Ver
	# TradeManager.process_all_routes.
	TradeManager.process_all_routes(players)

	# Pedido do usuario: "Civilization nao faz tudo acontecer no mapa ao
	# mesmo tempo... em pequenos grupos... diminui o lag na passada de
	# turnos". stagger_ai_turns DESLIGADO (padrao/todo teste GUT): rivais e
	# monstros agem tudo de uma vez, no MESMO frame, exatamente como
	# sempre. LIGADO (Main.gd, so na partida de verdade): monta a fila de
	# ACOES (uma por unidade rival + uma por monstro, ver
	# _build_rival_turn_items/_build_monster_turn_items) mas so a EXECUTA
	# aos poucos em _process() (AI_ACTIONS_PER_BATCH a cada AI_BATCH_
	# INTERVAL segundos) — o resto do turno (producao/pesquisa/predio
	# acima) continua rodando tudo de uma vez aqui, so a parte que ESCALA
	# com o numero de unidades (a fonte real do travamento, ver comentario
	# de stagger_ai_turns) e que fica espalhada. hex_grid.process_monster_
	# lairs continua rodando ANTES de montar a fila de monstros nos dois
	# casos (mesma ordem de sempre — um monstro recem-nascido ainda
	# precisa poder agir no mesmo turno em que aparece).
	if stagger_ai_turns:
		_ai_turn_queue.append_array(_build_rival_turn_items())
		hex_grid.process_monster_lairs(TurnManager.turn_number)
		_ai_turn_queue.append_array(_build_monster_turn_items())
		if _ai_turn_queue.is_empty():
			_finish_turn()
		else:
			_ai_batch_timer = 0.0
			is_turn_processing = true
	else:
		for rival in rival_players:
			RivalAI.take_turn(rival, hex_grid, human_player)
		hex_grid.process_monster_lairs(TurnManager.turn_number)
		MonsterAI.take_turn(hex_grid, TurnManager.turn_number)
		_finish_turn()

## Uma acao pendente por unidade rival ainda viva, com o "contexto" dela
## (visibilidade atual, ja calculada UMA vez por rival, nao por unidade —
## ver RivalAI.begin_turn) pronto pra _process() so chamar RivalAI.
## act_for_unit() aos poucos depois.
func _build_rival_turn_items() -> Array:
	var items: Array = []
	for rival in rival_players:
		var visible := RivalAI.begin_turn(rival, hex_grid, human_player)
		for unit in rival.units.duplicate():
			if is_instance_valid(unit):
				items.append({"kind": "rival", "unit": unit, "player": rival, "opponent": human_player, "visible": visible})
	return items

## Mesma ideia de _build_rival_turn_items, pros monstros neutros (ver
## MonsterAI.begin_turn/act_for_unit) — chamado DEPOIS de
## hex_grid.process_monster_lairs (ver _on_turn_changed), entao ja inclui
## qualquer reforco recem-spawnado neste mesmo turno.
func _build_monster_turn_items() -> Array:
	var items: Array = []
	MonsterAI.begin_turn(hex_grid)
	var turn := TurnManager.turn_number
	for unit in hex_grid.neutral_units():
		if is_instance_valid(unit):
			items.append({"kind": "monster", "unit": unit, "turn": turn})
	return items

## Drena ate AI_ACTIONS_PER_BATCH itens de _ai_turn_queue, no MAXIMO uma vez
## a cada AI_BATCH_INTERVAL segundos (nao todo frame — ver comentario da
## constante), enquanto is_turn_processing. So faz alguma coisa quando ha
## uma fila de verdade sendo processada (o resto do tempo e um `if` vazio,
## custo desprezivel) e quando o intervalo ja passou.
func _process(delta: float) -> void:
	if not is_turn_processing:
		return
	_ai_batch_timer += delta
	if _ai_batch_timer < AI_BATCH_INTERVAL:
		return
	_ai_batch_timer = 0.0

	var processed := 0
	while processed < AI_ACTIONS_PER_BATCH and not _ai_turn_queue.is_empty():
		var item: Dictionary = _ai_turn_queue.pop_front()
		processed += 1
		var unit: Unit = item.unit
		if not is_instance_valid(unit):
			continue
		if item.kind == "rival":
			RivalAI.act_for_unit(unit, hex_grid, item.player, item.opponent, item.visible)
		else:
			MonsterAI.act_for_unit(unit, hex_grid, item.turn)
	if _ai_turn_queue.is_empty():
		is_turn_processing = false
		_finish_turn()

## Ultimo passo do turno, rodado so DEPOIS que toda IA (rival + monstro) ja
## agiu — sincrono (branch `else` acima) ou no fim da fila drenar (ver
## _process acima), nunca no meio, senao recompute_fog/check_game_over
## reagiriam a um estado do mapa so PARCIALMENTE atualizado.
func _finish_turn() -> void:
	# predios concluidos neste turno ganham uma "volta de graca" com a barra
	# travada em 100% antes de sumir do "em obra" (ver comentario de
	# just_completed em refresh_construction_markers). Roda ANTES de
	# recompute_fog de proposito: recompute_fog e quem aplica a nevoa a
	# CADA marcador (ver _apply_fog_to_entities) — se rodasse antes, um
	# marcador criado/atualizado NESTE refresh so seria gateado corretamente
	# no PROXIMO turno, deixando uma obra inimiga vazando visivel por um
	# turno inteiro sempre que comecava ou terminava.
	hex_grid.refresh_construction_markers(_completed_building_coords_this_turn)
	_completed_building_coords_this_turn.clear()
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

## --- Debug (HUD.gd, botao "Debug" so em builds de desenvolvimento via
## OS.is_debug_build()) ---

## Liga/desliga o modo debug — pedido do usuario: "libere no modo debug,
## quando eu ativar, tudo liberado, tudo fica disponivel todas as
## pesquisas ficam feitas, e o tempo de fazer qualquer unidade e 1 turno
## pra eu estar tudo". Dois efeitos, so pro jogador HUMANO (mesmo escopo
## de debug_gold/debug_complete_current_research, nunca a IA rival):
## 1) LIGAR marca TODAS as tecnologias como pesquisadas na hora (mesmo
##    Dictionary id->true que _process_research usa de verdade, ver
##    TechDatabase.all_techs) — efeito imediato, nao precisa esperar turno
##    nenhum. Limpa current_research/research_progress junto (nao ha mais
##    nada pra pesquisar, uma selecao antiga ali so confundiria a TechTree
##    mostrando "Pesquisando: X" pra algo ja concluido).
## 2) Enquanto LIGADO, toda cidade do jogador completa a producao atual
##    (unidade OU predio, mesma condicao `stored_production >= cost` de
##    sempre) no PROPRIO turno em vez de acumular aos poucos — aplicado em
##    _on_turn_changed(), ver o `if debug_mode` logo antes de
##    city.process_turn(). DESLIGAR so para esse efeito daqui pra frente;
##    nao "desfaz" pesquisas ja marcadas (seria um cheat sem desfazer
##    limpo possivel, e nem faz sentido — um dev usando isso pra testar
##    conteudo tardio nao quer perder o progresso ao desligar por engano).
var debug_mode: bool = false

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	if enabled and human_player != null:
		for tech in TechDatabase.all_techs():
			human_player.researched_techs[tech.id] = true
		human_player.current_research = ""
		human_player.research_progress = 0.0

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
