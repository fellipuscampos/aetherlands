extends Node

enum GameState { MENU, PLAYING, GAME_OVER }

const GARRISON_HEAL_FRACTION := 0.25 # % do HP maximo curado por turno guarnecido
## % do HP maximo curado por turno so por estar Fortificado (Unit.fortified,
## ver SelectionManager.fortify_selected) — mais fraco que guarnicao numa
## cidade de proposito (GARRISON_HEAL_FRACTION), fortificar no campo aberto
## nunca deveria curar tao rapido quanto estar dentro dos proprios muros.
const FORTIFY_HEAL_FRACTION := 0.1

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

var state: GameState = GameState.MENU
var map_width: int = 25
var map_height: int = 25
var hex_grid: HexGrid
## Setado por Main._ready() (mesmo padrao de hex_grid, ver setup_players) —
## pedido do usuario: "minimapa... mostrar um indicador da regiao
## atualmente visivel pela camera". Minimap.gd (HUD, cena irma de Main) nao
## tem referencia direta a Main/CameraRig por nenhum outro caminho, mesma
## situacao que ja existia pra hex_grid antes desta mudanca.
var camera_rig: RTSCamera
## Ciclo de dia e noite e clima cosméticos (setados por Main._ready, mesmo motivo do camera_rig: a HUD — painel de
## Debug — não tem outro caminho até eles). null fora da cena real (testes GUT).
var day_night: DayNightController
var weather: WeatherController

var players: Array[PlayerData] = []
var human_player: PlayerData
var rival_players: Array[PlayerData] = []

## Fase 33B (Release Balance Lab): fixture DEV-ONLY, nunca salva e nunca ligada pelo jogo normal.
## Ligada, o assento formal `human_player` continua existindo, mas suas decisões passam pelo MESMO
## stack V2 dos rivais (V2StrategicAI, RivalAI, V2AITacticalAI, defesa de cidade da IA) e ele
## deixa de ser tratado como "humano com UI" nas regras de visibilidade de mira. Desligada (padrão),
## todo caminho abaixo é idêntico ao anterior.
var ai_controls_human_seat: bool = false

## `player` é o humano de verdade, operando pela UI? Falso para rivais e para o assento humano
## automatizado do laboratório (ai_controls_human_seat).
func is_human_controlled(player: PlayerData) -> bool:
	return player != null and player == human_player and not ai_controls_human_seat

## Civilizações cujas decisões vêm do stack de IA, na ordem de GameManager.players.
func ai_controlled_players() -> Array[PlayerData]:
	if ai_controls_human_seat and human_player != null:
		return ([human_player] as Array[PlayerData]) + rival_players
	return rival_players

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

## Escolhido na tela de titulo (1 a MAX_RIVALS); setup_players()
## limita (clamp) pro caso de vir de um save antigo com mais civs do que
## o pool atual suporta.
var rival_count: int = 1

## As raças jogáveis, na ordem canônica — a ordem em que os rivais entram na partida (rival_races_for).
const RACES: Array[String] = ["human", "elf", "dwarf", "orc"]

## A civilização de IA de CADA raça — pedido do usuario: "insira outras civilizacoes de fantasia, tipo os anoes, os
## orcs, os elfos...". `race` (a chave) é a identidade canônica (nome/estilo visual) e, desde a Fase 26, também a
## chave única do perfil sistêmico derivado por V2RaceBonusRuntime.
## A humana entrou em 2026-10-12 (relato do usuário: "os jogadores inimigos nunca são humanos... se escolho orc tem 2
## orcs, 1 elfo e 1 anão, nunca tem humanos, eles devem ser a IA também, pra nunca repetir uma civ"): antes a lista
## era só elfo/anão/orc, escolhida por índice sem olhar a raça do jogador.
## Cores: nenhuma repete o azul do jogador (setup_players) nem o vermelho-escuro dos monstros (Unit.MONSTER_COLOR).
const AI_CIVS := {
	"human": {"name": "Reino de Valmere", "leader": "Rei Aldric", "color": Color(0.52, 0.32, 0.72)},
	"elf": {"name": "Reino Elfico de Verdemata", "leader": "Rainha Aelaria", "color": Color(0.25, 0.55, 0.35)},
	"dwarf": {"name": "Reino de Ferroeste", "leader": "Rei Bramwell", "color": Color(0.55, 0.42, 0.18)},
	"orc": {"name": "Horda das Brumas", "leader": "Xama Skarn", "color": Color(0.4, 0.5, 0.25)},
}

## Uma civilização por raça e o jogador ocupa uma: no máximo as outras três.
const MAX_RIVALS := 3

## O elenco FIXO de antes de 2026-10-12 (elfo, anão, orc por índice, qualquer que fosse a raça do jogador). Só para
## carregar um save daquela época exatamente como foi jogado (SaveManager.load_game) — nunca em partida nova.
const LEGACY_RIVAL_RACES: Array[String] = ["elf", "dwarf", "orc"]

## As raças dos rivais de um jogador de `player_race`: todas as OUTRAS, na ordem canônica — nenhuma civilização se
## repete na partida. Com menos de MAX_RIVALS rivais entram as primeiras da lista (jogador humano: elfo, anão, orc,
## como sempre foi; jogador elfo: humano, anão, orc).
func rival_races_for(player_race: String) -> Array[String]:
	var result: Array[String] = []
	for race in RACES:
		if race != player_race:
			result.append(race)
	return result.slice(0, MAX_RIVALS)

## Dificuldade das IAs ("easy"/"normal"/"hard", 2026-10-15): multiplica só a economia dos rivais — a inteligência
## é a mesma nos três (V2AIDifficulty). Escolhida na tela de nova partida; salva no save desde sempre.
var difficulty: String = "normal"

## Id do slot desta partida (ver SaveManager.new_slot_id/save_to_slot) --
## atribuido por Main.gd toda vez que uma partida NOVA comeca ou um save e
## CARREGADO; "Salvar Jogo" sempre sobrescreve este MESMO slot. "" fora de
## uma partida (menu principal, ver end_match()).
var current_save_slot: String = ""

func _ready() -> void:
	TurnManager.turn_changed.connect(_on_turn_changed)
	# Memória diplomática (DiplomaticMemory): cidade tomada e ataque entre civilizações em guerra viram rancor.
	EventBus.city_captured.connect(func(old_owner: PlayerData, new_owner: PlayerData, _city_name: String, _coord: Vector2i) -> void: DiplomaticMemory.on_city_captured(old_owner, new_owner))
	EventBus.combat_engagement.connect(func(attacker_owner: PlayerData, defender_owner: PlayerData, target_kind: String, _coord: Vector2i) -> void: DiplomaticMemory.on_combat(attacker_owner, defender_owner, target_kind))

func start_new_game(grid: HexGrid) -> void:
	setup_players(grid)
	_spawn_starting_forces()
	hex_grid.recompute_fog(human_player)

## Roadmap "sistema de menu de jogo moderno" -- pedido explicito do usuario:
## "voltar pro menu principal de fato volta pro menu principal, atualmente
## ele continua na partida mas mostrando as opcoes de menu, o que nao faz
## sentido... o comportamento correto e fechar a partida". Antes disso,
## "Voltar ao Menu Principal" (Main.gd) so escondia a HUD e mostrava a tela
## de titulo -- a partida em si continuava viva por tras, incluindo um bug
## real: _process() abaixo so e gateado por is_turn_processing, nunca por
## `state`, entao uma IA no meio de um turno espalhado (stagger_ai_turns,
## ver _ai_turn_queue) continuava sendo processada em segundo plano mesmo
## depois do jogador "sair". end_match() encerra tudo de proposito, na
## ordem: `state` primeiro (qualquer coisa que reaja ao encerramento ja ve
## MENU), corta o dreno assincrono de IA ANTES de mexer nos dados que ele
## esta iterando, depois eventos de mundo, depois entidades do mapa (ver
## HexGrid.reset_to_empty(), mesmo teardown que generate_map() ja roda no
## inicio de toda partida nova), so DEPOIS libera as referencias de
## jogador (reset_to_empty() nao mexe nelas), e SelectionManager por
## ultimo (limpa qualquer selecao apontando pra unidade/cidade que acabou
## de sumir). Nao mexe em nos de cena (hud.visible, title_screen.visible)
## de proposito -- isso continua responsabilidade exclusiva de Main.gd,
## mesma divisao ja usada por start_new_game()/setup_players() (dados vs.
## apresentacao).
func end_match() -> void:
	state = GameState.MENU
	AudioManager.stop_match_audio()
	is_turn_processing = false
	_ai_turn_queue.clear()
	_ai_batch_timer = 0.0
	WorldEventManager.reset_for_new_match()
	if hex_grid != null:
		hex_grid.reset_to_empty()
	_release_player_relations()
	players.clear()
	rival_players.clear()
	human_player = null
	current_save_slot = ""
	SelectionManager.reset()

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
## `rival_races`: o elenco de rivais a recriar, uma raça por rival, na ordem — só o load passa (o que estava no save).
## Vazio (partida nova) = as raças que o jogador NÃO escolheu (rival_races_for).
func setup_players(grid: HexGrid, rival_races: Array[String] = []) -> void:
	_release_player_relations()
	is_turn_processing = false
	_ai_turn_queue.clear()
	hex_grid = grid
	state = GameState.PLAYING
	players.clear()
	rival_players.clear()

	var human_civ := CivilizationData.new()
	human_civ.civ_name = human_kingdom_name if human_kingdom_name != "" else _default_kingdom_name_for_race(human_race)
	human_civ.leader_name = "Rainha Elara"
	human_civ.color = Color(0.2, 0.45, 0.85)
	human_civ.race = human_race if human_race in RACES else "human"
	human_player = PlayerData.new(human_civ)
	players.append(human_player)

	var roster: Array[String] = rival_races if not rival_races.is_empty() else rival_races_for(human_civ.race)
	var count = clamp(rival_count, 1, mini(MAX_RIVALS, roster.size()))
	for i in range(count):
		var info: Dictionary = AI_CIVS[roster[i]]
		var rival_civ := CivilizationData.new()
		rival_civ.civ_name = info.name
		rival_civ.leader_name = info.leader
		rival_civ.color = info.color
		rival_civ.race = roster[i]
		var rival := PlayerData.new(rival_civ)
		players.append(rival)
		rival_players.append(rival)
	for i in range(players.size()):
		players[i].ai_rng.seed = hex_grid.map_seed + 83071 + i * 104729
	for i in range(rival_players.size()):
		V2StrategicAI.initialize_player(rival_players[i], i, hex_grid.map_seed, rival_players.size())

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
	# Fase 33D1: estado de mundo sempre nasce limpo (inclusive em "Jogar de Novo", que não passa por
	# end_match); o load restaura por cima logo depois (WorldEventManager.from_save_dict).
	WorldEventManager.reset_for_new_match(TurnManager.turn_number)

func _release_player_relations() -> void:
	for player in players:
		player.release_relations()
	for player in rival_players:
		player.release_relations()
	if human_player:
		human_player.release_relations()

func _exit_tree() -> void:
	_release_player_relations()

## Unidade parada dentro da PROPRIA cidade recupera vida — vale tanto pro
## jogador quanto pro rival (nao e vantagem so da IA), e da uma razao de
## verdade pra recuar em vez de continuar brigando fraca (ver
## RivalAI._retreat).
func _heal_if_garrisoned(unit: Unit) -> void:
	var city = hex_grid.get_city_at(unit.coord)
	if city and city.owner_player == unit.owner_player:
		if unit.hp < unit.unit_data.max_hp:
			unit.hp = min(unit.hp + unit.unit_data.max_hp * GARRISON_HEAL_FRACTION * MonsterHazardSystem.heal_multiplier(unit), unit.unit_data.max_hp)
		return
	_heal_if_fortified(unit)

## Cura passiva do modo Fortificar (Unit.fortified) — pedido do usuario:
## "se você tiver ferido, você fica se curando um pouco todo turno". So
## chamada quando a unidade NAO esta guarnicionada (ver _heal_if_garrisoned
## acima) pra nunca curar duas vezes no mesmo turno.
func _heal_if_fortified(unit: Unit) -> void:
	if unit.fortified and unit.hp < unit.unit_data.max_hp:
		unit.hp = min(unit.hp + unit.unit_data.max_hp * FORTIFY_HEAL_FRACTION * MonsterHazardSystem.heal_multiplier(unit), unit.unit_data.max_hp)

## Ent (UnitData.regen_fraction): regenera sozinho todo turno, em qualquer
## lugar do mapa — nao depende de estar guarnicionado como o resto do
## exercito. Vale tanto pro jogador quanto pro rival, mesma logica de
## _heal_if_garrisoned.
func _apply_regen(unit: Unit) -> void:
	if unit.unit_data.regen_fraction > 0.0 and unit.hp < unit.unit_data.max_hp:
		unit.hp = min(unit.hp + unit.unit_data.max_hp * unit.unit_data.regen_fraction * MonsterHazardSystem.heal_multiplier(unit), unit.unit_data.max_hp)

## Fase 33D2 — partidas novas recebem ameaças regionais (sempre no jogo). Só fixtures de teste de CONTEÚDO que
## dependem do layout exato do mapa gerado desligam (e restauram) isto.
var regional_threats_on_new_match := true
## V3 / Combat Ecology — partidas novas recebem a população ecológica completa (MonsterEcologySystem) e saves
## anteriores à V3 ligam a reposição gradual. Flag de FIXTURE de teste (default true, nunca salva, sem UI): só
## testes de conteúdo que dependem do mapa sem monstros desligam e restauram no after_each.
var combat_ecology_on_new_match := true

## Escolta inicial de toda civilização (UnitDatabase.STARTING_ESCORT_KINDS), no tile livre mais próximo.
## Flag de FIXTURE de teste (default true, nunca salva, sem UI), no mesmo molde das duas acima: só testes de
## conteúdo que contam unidades/Suprimentos exatos de uma linha de Doutrina desligam e restauram no after_each.
var starting_escort_on_new_match := true

func _spawn_starting_escort(origin: Vector2i, player: PlayerData) -> void:
	if not starting_escort_on_new_match:
		return
	for kind in UnitDatabase.STARTING_ESCORT_KINDS:
		var spawn_coord := WorldSetup.find_spawn_tile(hex_grid, origin)
		if spawn_coord == WorldSetup.NO_SPAWN_COORD:
			push_warning("GameManager: sem tile livre para a escolta inicial (%s) de %s." % [kind, player.civ.civ_name])
			return
		hex_grid.spawn_unit(spawn_coord, UnitDatabase.create_unit(kind), player)

func _spawn_starting_forces() -> void:
	# claimed_starts impede que duas capitais (do humano ou de rivais
	# diferentes) acabem escolhendo o mesmo tile inicial — ver comentario
	# em WorldSetup.find_start_tile.
	var claimed_starts: Array[Vector2i] = []
	# Fase 33D2: só partidas NOVAS recebem ameaças regionais. As capitais do setup são planejadas juntas no
	# fim (todas as âncoras conhecidas); a do humano, quando o Colonizador fundar (HexGrid.found_city).
	WorldEventManager.regional_threats_enabled = regional_threats_on_new_match
	RegionalThreatSystem.defer_planning = true

	# Forças iniciais: o Colonizador e a escolta STARTING_ESCORT_KINDS. O rival funda a capital com o
	# próprio Colonizador já no setup; o humano funda quando quiser.
	var human_start = WorldSetup.find_start_tile(hex_grid, Vector2i(0, 0), claimed_starts)
	claimed_starts.append(human_start)
	hex_grid.spawn_unit(human_start, UnitDatabase.create_unit("settler"), human_player)
	_spawn_starting_escort(human_start, human_player)

	for i in range(rival_players.size()):
		var rival = rival_players[i]
		var rival_origin = _rival_origin(i, rival_players.size())
		var rival_start = WorldSetup.find_start_tile(hex_grid, rival_origin, claimed_starts)
		claimed_starts.append(rival_start)
		hex_grid.found_city(rival_start, rival, rival.civ.civ_name + " - Capital")
		_spawn_starting_escort(rival_start, rival)
	RegionalThreatSystem.defer_planning = false
	RegionalThreatSystem.plan_pending(hex_grid)
	# V3 / Combat Ecology: mapa, capitais/tiles iniciais e ameaças regionais do setup já existem — a ecologia
	# completa nasce agora, antes do primeiro turno (nunca em _process).
	MonsterEcologySystem.populate_new_match(hex_grid, combat_ecology_on_new_match)

## Espalha os rivais em angulos igualmente espacados ao redor do centro do
## mapa (onde o humano comeca), numa elipse escalada pela largura/altura
## da AREA RESERVADA do continente Principal (WorldProfile.main_frame do tamanho, nao
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
	# 2026-10-10: a área reservada vem do perfil do tamanho do mapa (Pequeno/Médio/Grande ou legado). Fixtures de teste
	# continuam com a pegada histórica 96×60 (comportamento de sempre — WorldSetup acha o tile válido mais perto).
	var profile := WorldProfile.for_dimensions(map_width, map_height)
	var frame: Vector2i = profile.main_frame if bool(profile.fixed_main_frame) else WorldProfile.MAP_LARGE.main_frame
	var dist_q = float(frame.x) * 0.35
	var dist_r = float(frame.y) * 0.35
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

	# Antes de qualquer coisa agir: civilização que já caiu (sem cidade depois de ter tido) não entra na rodada com
	# tropas, guerras ou propostas de paz penduradas (HexGrid.reconcile_eliminations).
	hex_grid.reconcile_eliminations()
	# Fronteiras fechadas: ninguém começa a rodada dentro de um território onde não pode estar (HexGrid.enforce_closed_borders).
	hex_grid.enforce_closed_borders()

	for player in players:
		for unit in player.units:
			# Ordens permanentes (marcha "mover ate" e Explorar — pedido do
			# usuario: "no civilization eu posso colocar pra ela se mover pra
			# um lugar longe... o movimento fica gravado e todo turno essa
			# tropa vai se movendo") andam com o movimento que SOBROU do turno
			# que esta acabando, por isso ANTES de reset_movement(): no turno
			# do jogador a unidade esta inteira e ele pode atacar/redirecionar
			# em vez de encontra-la sempre com 0 de movimento (ver HexGrid.
			# run_standing_orders). So o jogador humano liga essas ordens (a IA
			# rival decide movimento do proprio jeito, RivalAI.move_unit_toward),
			# entao isto e um no-op de graca pros units dela.
			hex_grid.run_standing_orders(unit)
			unit.reset_movement()
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

	for rival in ai_controlled_players():
		# Civilização eliminada (HexGrid.eliminate_civilization) não joga mais: não pesquisa, não declara guerra, não
		# propõe paz. No turno 1 ninguém está eliminado (todos têm o Colono).
		if V2VictoryConditions.is_eliminated(rival):
			continue
		var rival_civ_index: int = players.find(rival)
		# Roadmap "Fase Macro" 5B.3-G -- "Preparation = tempo de preparacao
		# militar" / "IA precisa reagir ao Dragao". Calculado UMA vez aqui
		# (nao dentro do planejamento de producao) pra tambem reutilizar embaixo na
		# interceptacao (RivalAI.defend_against_dragon), sem duplicar a
		# checagem de ameaca. Generico o bastante pra qualquer DragonEvent
		# ativo -- civ_threatened concentra a regra (Preparation: so a civ
		# anunciada; Active: ja raidada ou com cidade perto do Dragao AGORA,
		# ver DragonEvent.is_civ_threatened).
		var threatening_dragon: DragonEvent = null
		for event in WorldEventManager.active_events:
			if event is DragonEvent and (event as DragonEvent).is_civ_threatened(rival_civ_index, players):
				threatening_dragon = event as DragonEvent
				break
		# Fase 24/25: pesquisa, economia, filas e objetivos de vitória de todo rival major vêm de
		# V2StrategicAI — os decisores V1 (produção/pesquisa/ritual/feitiços) foram removidos.
		V2StrategicAI.plan_turn(rival, hex_grid)
		RivalAI.decide_war(rival, hex_grid, human_player)
		# Roadmap "Parte C" C3 — logo apos decide_war de proposito: uma
		# guerra recem-declarada ja ganha campanha (objetivo+alvo
		# persistentes) antes do take_turn/combate deste mesmo turno rodar
		# mais abaixo (ver RivalAI.decide_campaign).
		RivalAI.decide_campaign(rival, hex_grid, human_player)
		# Roadmap "Parte D" D1 — depois de decide_campaign de proposito: le o
		# war_weariness ACUMULADO ATE O FIM DO TURNO ANTERIOR (Diplomacy.
		# process_war_weariness_and_upkeep so atualiza mais abaixo, na fase
		# economica deste MESMO turno) — mesma disciplina temporal de
		# "decisao ve o mundo ate o fim do turno anterior" que decide_war/
		# decide_campaign ja seguem.
		RivalAI.decide_peace(rival, human_player)
		RivalAI.decide_open_borders(rival, human_player)
		for other in players:
			# Nenhuma decisão diplomática contra uma civilização que já saiu da partida.
			if other == rival or other == human_player or V2VictoryConditions.is_eliminated(other):
				continue
			RivalAI.decide_war(rival, hex_grid, other)
			RivalAI.decide_campaign(rival, hex_grid, other)
			RivalAI.decide_peace(rival, other)
			RivalAI.decide_open_borders(rival, other)
		# Roadmap "Fase Macro" 5B.2 -- generico por proposito (qualquer
		# WorldEvent em Preparation, nao so DragonEvent especificamente).
		for event in WorldEventManager.active_events:
			RivalAI.decide_world_event_participation(rival, rival_civ_index, event)
		# 5B.3-G, "interceptacao real" -- so' quando o Dragao ja nasceu
		# (Active) e esta civ esta ameacada; Preparation so' antecipa
		# producao (acima), nao ha Unit nenhuma pra interceptar ainda.
		if threatening_dragon != null and threatening_dragon.dragon_unit != null:
			RivalAI.defend_against_dragon(rival, hex_grid, threatening_dragon.dragon_unit)
		else:
			# Fase 33D3: participante que decidiu entrar na caçada (não-alvo) desloca uma força pequena.
			for event in WorldEventManager.active_events:
				if event is DragonEvent and event.phase == WorldEvent.PHASE_ACTIVE and bool(event.participants.get(rival_civ_index, {}).get("decision", false)) and (event as DragonEvent).dragon_unit != null:
					RivalAI.join_dragon_hunt(rival, hex_grid, (event as DragonEvent).dragon_unit)

	for player in players:
		UnitAbilities.process_turn(player, hex_grid)
		# Task 21 -- avisa o jogador humano ANTES de a milicia atuar (a
		# posicao dos monstros ainda e' a do fim do turno anterior).
		if player == human_player:
			CityDefense.warn_player(player, hex_grid, hex_grid.compute_visible_tiles(player), TurnManager.turn_number)
		# Ouro/Mana/Conhecimento globais vêm só da Economia V2 (V2EconomyRuntime), creditados UMA
		# vez por civilização por turno, ANTES do loop de produção local das cidades abaixo (snapshot
		# do início do turno). O Conhecimento alimenta a pesquisa (V2ResearchState) dentro deste
		# mesmo crédito. Suprimentos não é creditado: é capacidade pura, consultada sob demanda.
		V2EconomyRuntime.apply_turn_income(player)
		for city in player.cities.duplicate():
			# Aetherlands V2, Fase 16 -- a milicia AUTOMATICA (CityDefense.militia_strike) foi
			# removida: a defesa ativa da cidade agora e' o Ataque da Cidade, uma acao explicita
			# (o humano mira pelo SelectionManager). A IA tem so' a paridade tatica minima: sua
			# cidade fortificada dispara uma vez no alvo mais ferido ao alcance.
			if not is_human_controlled(player):
				CityDefense.ai_city_defense_turn(city, hex_grid)
			# Modo debug (ver set_debug_mode acima): "o tempo de fazer
			# qualquer unidade e 1 turno" — completa a producao atual
			# (unidade OU predio, mesmo criterio de City.process_turn) so
			# pra cidade do jogador HUMANO, antes de processar o turno de
			# verdade, em vez de duplicar a logica de spawn/construcao aqui.
			if debug_mode and player == human_player:
				city.stored_production = max(city.stored_production, city.production_cost())
			var item_before_turn: String = city.production_item
			var result = city.process_turn(hex_grid)
			# Fase 33B: observabilidade pura para o Release Balance Lab (ninguém conecta no jogo normal).
			EventBus.city_production_processed.emit(player, city, item_before_turn, result)
			if result.spawn_unit_kind != "":
				var spawn_mana_cost := UnitDatabase.create_unit(result.spawn_unit_kind).production_mana_cost
				if not V2LegendarySystem.spawn_allowed(player, result.spawn_unit_kind):
					# Fail-closed (Fase 6): jamais duas Lendárias ativas — não nasce, o custo volta pra cidade.
					V2LegendarySystem.refuse_spawn(city, result.spawn_unit_kind, player == human_player)
				elif not V2ManifestationSystem.spawn_allowed(player, result.spawn_unit_kind):
					# Fail-closed (Fase 17): jamais duas Grandes Manifestações da MESMA Escola — não nasce, os PP voltam, Mana intacta.
					V2ManifestationSystem.refuse_spawn(city, result.spawn_unit_kind, player == human_player)
				elif not V2ColonizationRuntime.spawn_allowed(player, result.spawn_unit_kind):
					# Fail-closed (2026-10-09): nunca passa do limite de Colonos da linha de Colonização — os PP voltam.
					V2ColonizationRuntime.refuse_spawn(city, result.spawn_unit_kind, player == human_player)
				elif spawn_mana_cost > 0.0 and player.mana < spawn_mana_cost:
					# Fase 17: a Mana mudou entre a checagem da cidade e o nascimento (duas conclusões no mesmo ciclo):
					# volta a ESPERAR completa, sem perder PP e sem Mana negativa.
					city.production_item = result.spawn_unit_kind
					city.stored_production += city.production_cost()
				else:
					# Fase 17: Mana de produção (UnitData.production_mana_cost) cobrada UMA vez, na conclusão, antes de nascer.
					if spawn_mana_cost > 0.0:
						player.mana -= spawn_mana_cost
					var spawn_coord = WorldSetup.find_spawn_tile(hex_grid, city.coord)
					var spawned := hex_grid.spawn_unit(spawn_coord, UnitDatabase.create_unit(result.spawn_unit_kind), player)
					if spawned != null:
						V2ColonizationRuntime.record_trained(player, result.spawn_unit_kind)
						EventBus.ui_production_completed.emit(player, city.city_name, result.spawn_unit_kind, spawned.unit_data.unit_name, city.coord)
					if spawned != null and player == human_player and V2LegendarySystem.is_legendary_unit(spawned):
						EventBus.notify.emit("Unidade Lendária pronta: %s" % spawned.unit_data.unit_name, "confirm")
					if spawned != null and player == human_player and V2ManifestationSystem.is_manifestation_unit(spawned):
						EventBus.notify.emit("Grande Manifestação pronta: %s" % spawned.unit_data.unit_name, "confirm")
					# Aetherlands V2, Fase 15 (§54-56 do pedido) — cargas do Construtor são setadas UMA
					# vez, ao nascer, pelo tier de Indústria do dono NESTE instante; pesquisa posterior
					# nunca recarrega um Construtor já existente.
					if spawned != null and V2ConstructorRuntime.is_builder_unit(spawned):
						spawned.work_charges_remaining = V2ConstructorRuntime.charges_for_new_builder(player)
			if result.built_kind != "":
				if result.built_coord != City.NO_PENDING_COORD:
					# O prédio nasce e o canteiro sai do tile no mesmo passo (HexGrid.place_building).
					hex_grid.place_building(result.built_coord, result.built_kind, player)
				if player == human_player:
					var building: BuildingData = BuildingDatabase.get_building(result.built_kind)
					EventBus.notify.emit("%s concluiu: %s" % [city.city_name, building.display_name], "confirm")
					EventBus.ui_production_completed.emit(player, city.city_name, result.built_kind, building.display_name, city.coord)
			# Aetherlands V2, Fase 13 — City Project concluído (City.city_level já mudou dentro
			# de process_turn; aqui só o feedback, mesmo padrão de built_kind acima).
			if result.city_level_up > 0 and player == human_player:
				EventBus.notify.emit("%s alcançou %s." % [city.city_name, V2CityLevelData.level_name(result.city_level_up)], "confirm")
				if int(result.city_level_up) == HexGrid.CLOSED_BORDERS_FROM_LEVEL:
					EventBus.notify.emit("%s fechou as fronteiras: unidades de outros reinos só entram no território dela em guerra." % city.city_name, "city")
			if result.get("fortification_level_up", 0) > 0 and player == human_player:
				EventBus.notify.emit("%s concluiu %s." % [city.city_name, V2FortificationData.display_name(result.fortification_level_up)], "confirm")
		Diplomacy.process_war_weariness_and_upkeep(player)

	# A produção de todas as cidades já andou: os canteiros mostram o progresso NOVO agora, junto com os prédios que
	# acabaram de nascer — não só depois da fase da IA (que pode levar segundos com stagger_ai_turns).
	hex_grid.refresh_construction_markers()
	# Cidades evoluíram e territórios cresceram neste passo: quem ficou dentro de uma fronteira que acabou de fechar sai
	# antes de a IA agir.
	hex_grid.enforce_closed_borders()

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
		_ai_turn_queue.append_array(_build_manifestation_turn_items())
		_ai_turn_queue.append_array(_build_rival_turn_items())
		hex_grid.process_monster_lairs(TurnManager.turn_number)
		_ai_turn_queue.append_array(_build_monster_turn_items())
		if _ai_turn_queue.is_empty():
			_finish_turn()
		else:
			_ai_batch_timer = 0.0
			is_turn_processing = true
	else:
		for item in _build_manifestation_turn_items():
			V2ManifestationOrders.act(item.unit, hex_grid, item.visible)
		for rival in ai_controlled_players():
			RivalAI.take_turn(rival, hex_grid, human_player)
		hex_grid.process_monster_lairs(TurnManager.turn_number)
		MonsterAI.take_turn(hex_grid, TurnManager.turn_number)
		_finish_turn()

## Human-owned bound entities share the existing turn queue. Vision is
## computed only for owners who have entities, once per owner, not per unit.
func _build_manifestation_turn_items() -> Array:
	var items: Array = []
	var rivals := ai_controlled_players()
	for player in players:
		if player in rivals or V2VictoryConditions.is_eliminated(player): continue
		var entities: Array[Unit] = []
		for unit in player.units:
			if is_instance_valid(unit) and V2ManifestationOrders.is_bound(unit): entities.append(unit)
		if entities.is_empty(): continue
		var visible := hex_grid.compute_visible_tiles(player)
		for unit in entities: items.append({"kind":"manifestation", "unit":unit, "visible":visible})
	return items

## One item per rival unit; RivalAI.begin_turn builds owner visibility once.
func _build_rival_turn_items() -> Array:
	var items: Array = []
	for rival in ai_controlled_players():
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
		if not is_instance_valid(unit):
			continue
		# Roadmap "Fase Macro" 5B.3-D -- mesma exclusao de MonsterAI.
		# take_turn (ver comentario de Unit.world_event_managed): este e' o
		# caminho de verdade usado no jogo real (stagger_ai_turns == true),
		# entao o Dragao de DragonEvent NUNCA pode entrar nesta fila.
		if unit.world_event_managed:
			continue
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
		# Removida (morta, ou a civilização dela foi eliminada) neste mesmo lote: queue_free só libera no fim do quadro.
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.get_meta("feedback_retired", false):
			continue
		if item.kind == "manifestation":
			V2ManifestationOrders.act(unit, hex_grid, item.visible)
		elif item.kind == "rival":
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
	# A IA e os monstros já agiram: uma cidade capturada nesta fase pode ter perdido a obra (HexGrid.capture_city
	# revalida a fila). Reconciliação pura — a conclusão de prédio não depende deste ponto (ver _on_turn_changed).
	hex_grid.refresh_construction_markers()
	# Paz e anexações da fase da IA: o jogador recebe o turno com as fronteiras fechadas já respeitadas.
	hex_grid.enforce_closed_borders()
	# V2 (Fase 4): o mundo já agiu (IA/monstros) — é o "início do próximo turno do dono",
	# quando as Técnicas Militares ativadas no turno anterior terminam.
	for player in players:
		V2TechniqueRuntime.expire_finished(player)
		V2MagicRuntime.expire_finished(player) # Fase 17: estados de feitiço (Égide) pela MESMA regra de V2OwnerTurnEffect
	# Fase 22: UMA vez por rodada global, depois de humano + IAs + monstros. O
	# sistema aplica dano, decrementa e expira antes do único refresh de fog abaixo.
	V2EnvironmentalZoneSystem.process_global_round(hex_grid, true)
	# Fase 23: valida e avança Rituais só DEPOIS do dano ambiental — uma
	# Manifestação morta nesta rodada interrompe antes de o countdown chegar a zero.
	V2TranscendenceSystem.process_global_round(hex_grid)
	# V3 / Etapa 2: início do próximo turno das vítimas — dano de Veneno/Chamas, fim dos estados de criatura e dano
	# de quem começa o turno em infecção micótica. Uma vez por rodada global, nunca por frame.
	UnitStatusEffects.process_round(players, hex_grid, TurnManager.turn_number)
	MonsterHazardSystem.process_turn_start(players, hex_grid)
	hex_grid.recompute_fog(human_player)
	# World Event System (docs/WORLD_EVENT_CONTRACT.md, secao 1) -- ordem
	# exata do contrato: DEPOIS que o mapa deste turno ja esta final (fog/
	# marcadores) e ANTES da checagem de vitoria, pra qualquer consequencia
	# que um evento aplique neste turno (cidade destruida, territorio
	# alterado, recurso concedido) ja estar refletida na checagem de
	# vitoria do MESMO turno. Reusa GameManager.players (ja mantido por
	# setup_players()) em vez de reconstruir a lista aqui. maybe_spawn_dragon
	# roda ANTES de advance_turn de proposito -- um Dragao recem-criado ja
	# ganha seu primeiro tick de FSM (Dormant->Announced) neste MESMO
	# turno, em vez de ficar Dormant um turno inteiro sem motivo: o turno em
	# que o trigger dispara e' o mesmo turno em que o mundo anuncia o
	# evento, sem um estado "criado mas ainda invisivel" por perder um
	# tick. DECISAO TEMPORAL DE IMPLEMENTACAO (nao do contrato) -- fica
	# registrada aqui porque precisa ser consistente com o que
	# turn_started/turn_deadline (Blocker #2, 5B.2) vierem a assumir sobre
	# "em que turno o relogio do evento comeca a contar".
	WorldEventManager.maybe_spawn_dragon(hex_grid, TurnManager.turn_number)
	WorldEventManager.advance_turn(hex_grid, players)
	# Fase 33D1: era do mundo avaliada UMA vez por rodada global, depois dos eventos e antes da vitória.
	WorldEventManager.advance_world_phase(players, TurnManager.turn_number)
	PublicVictoryMilestones.evaluate_round(players, TurnManager.turn_number) # Fase 33D3: fatos públicos, uma vez
	check_victories()
	EventBus.ui_state_changed.emit("turn_finished")

## Autoridade ÚNICA de vitória (Fase 25). Só três condições encerram uma partida normal, verificadas
## nesta ordem FIXA de precedência — a primeira verdadeira vence e uma única chamada nunca produz duas
## telas (_end_game muda o estado para GAME_OVER e check_victories sai cedo depois disso):
##   1. Dominação — última civilização major restante (VictoryConditions.is_dominance_achieved);
##   2. Supremacia Militar (V2VictoryConditions.military_supremacy_achieved);
##   3. Transcendência (V2VictoryConditions.transcendence_achieved, Ritual Final concluído).
## Em cada condição os jogadores são testados na ordem [humano] + rivais (desempate técnico). Por
## fim, o humano sem cidades e sem unidades perde. Nunca escreve estado de progresso — só detecta; o
## Ritual Final avança em V2TranscendenceSystem.process_global_round, antes daqui no _finish_turn.
func check_victories() -> void:
	if state == GameState.GAME_OVER:
		return
	var players_in_order: Array[PlayerData] = ([human_player] as Array[PlayerData]) + rival_players
	for player in players_in_order:
		if VictoryConditions.is_dominance_achieved(player, players_in_order):
			_end_game(player, VictoryConditions.VICTORY_TYPE_DOMINANCE)
			return
	for player in players_in_order:
		if V2VictoryConditions.military_supremacy_achieved(player):
			_end_game(player, V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY)
			return
	for player in players_in_order:
		if V2VictoryConditions.transcendence_achieved(player):
			_end_game(player, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE)
			return
	# No laboratório 4-IA o assento humano é só mais uma civilização: sua eliminação conta para a
	# Dominação dos outros, mas não encerra a partida sozinha.
	if human_player and not ai_controls_human_seat and human_player.cities.is_empty() and human_player.units.is_empty():
		_end_game(null, "eliminated")

## `winner` pode ser QUALQUER jogador (humano ou rival) desde F3 -- antes
## so existia vitoria/derrota do lado humano. `victory` (EventBus.
## game_over, sinal ANTIGO) continua servindo os consumidores legados
## (HUD/AudioManager/botao de debug/testes ja existentes, todos so
## perguntam "o humano ganhou?"), calculado aqui a partir de `winner` pra
## nao duplicar essa logica em cada chamador. victory_achieved (sinal
## NOVO) carrega o contexto completo pra quem precisar dele (F1/F2 passo
## 7, tela de resultado detalhada) -- os dois sinais sao emitidos JUNTOS,
## nunca um sem o outro.
func _end_game(winner: PlayerData, victory_type: String) -> void:
	state = GameState.GAME_OVER
	var victory := winner == human_player
	EventBus.game_over.emit(victory)
	EventBus.victory_achieved.emit(winner, victory_type)

## --- Debug (HUD.gd, botao "Debug" so em builds de desenvolvimento via
## OS.is_debug_build()) ---

## Liga/desliga o modo debug (só pro jogador HUMANO, nunca a IA): enquanto LIGADO, toda cidade do
## jogador completa a producao atual (unidade OU predio) no PROPRIO turno — aplicado em
## _on_turn_changed(), ver o `if debug_mode` logo antes de city.process_turn(). A pesquisa tem as
## próprias ferramentas de debug dentro do quadro de Pesquisa (V2ResearchBoard, só em debug build).
var debug_mode: bool = false

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled

## Forca o fim de jogo na hora, sem esperar eliminar unidade/cidade
## nenhuma de verdade — reaproveita _end_game() (mesmo sinal
## EventBus.game_over que o fim de jogo real usa), so pula a checagem de
## check_victories(). Util pra testar a tela de vitoria/derrota sem
## precisar jogar uma partida inteira. `winner` sintetico (humano se
## `victory`, senao o primeiro rival se houver algum) so pra _end_game
## ter alguem pra apontar -- VICTORY_TYPE_DEBUG deixa claro pra qualquer
## consumidor de victory_achieved que isso NUNCA veio de check_victories.
func debug_force_game_over(victory: bool) -> void:
	var winner: PlayerData = human_player if victory else (rival_players[0] if not rival_players.is_empty() else null)
	_end_game(winner, VictoryConditions.VICTORY_TYPE_DEBUG)

## Completa na hora a pesquisa ATIVA do jogador humano (V2ResearchState) — mesmo caminho de conclusão
## da pesquisa real (sinais, unlocks, toasts). Sem projeto ativo, não faz nada.
func debug_complete_current_research() -> void:
	if human_player == null:
		return
	human_player.v2_research.debug_complete_active()
