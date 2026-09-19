extends Node3D

@onready var hex_grid: HexGrid = $HexGrid
@onready var camera_rig: RTSCamera = $CameraRig
@onready var hud: Control = $UILayer/HUD
@onready var title_screen: Control = $UILayer/TitleScreen
@onready var game_setup_screen: Control = $UILayer/GameSetupScreen
@onready var pause_menu: Control = $UILayer/PauseMenu
@onready var loading_screen: LoadingScreen = $UILayer/LoadingScreen

## O jogo so comeca (mapa novo ou carregado) depois de uma escolha na tela
## de titulo — antes disso a HUD fica escondida e so a tela de titulo
## responde a cliques (ver mouse_filter padrao dela, que bloqueia o mundo
## por baixo). O menu de pausa (ESC ou botao "Menu" da HUD) cuida de si
## mesmo via get_tree().paused — so escuta daqui os pedidos que exigem
## coordenar hex_grid/HUD/tela de titulo/tela de configuracao: abrir a
## configuracao de partida nova (pedido do usuario: fluxo em 2 telas tipo
## Civilization, ver TitleScreen.gd/GameSetupScreen.gd), carregar e voltar
## ao menu.
func _ready() -> void:
	# Liga o processamento de IA ESPALHADO por frame (pedido do usuario:
	# "Civilization... em pequenos grupos... diminui o lag na passada de
	# turnos", ver GameManager.stagger_ai_turns) — so aqui, na cena real do
	# jogo, nunca em teste GUT (que nunca instancia Main.gd, constroi
	# HexGrid/GameManager na mao e depende do comportamento SINCRONO
	# antigo continuar valendo).
	GameManager.stagger_ai_turns = true
	GameManager.camera_rig = camera_rig # ver GameManager.gd — Minimap (HUD) usa isso pro indicador de viewport
	EventBus.restart_requested.connect(_on_restart_requested)
	title_screen.new_game_setup_requested.connect(_on_new_game_setup_requested)
	title_screen.load_game_requested.connect(_on_title_load_requested)
	game_setup_screen.new_game_requested.connect(_on_new_game_requested)
	game_setup_screen.back_requested.connect(_on_game_setup_back_requested)
	pause_menu.load_requested.connect(_on_pause_load_requested)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu_requested)
	hud.visible = false
	game_setup_screen.visible = false

func _on_new_game_setup_requested() -> void:
	title_screen.visible = false
	game_setup_screen.reset_to_defaults()
	game_setup_screen.visible = true

func _on_game_setup_back_requested() -> void:
	game_setup_screen.visible = false
	title_screen.visible = true

func _on_new_game_requested(width: int, height: int, kingdom_name: String, rival_count: int, difficulty: String, race: String) -> void:
	GameManager.map_width = width
	GameManager.map_height = height
	GameManager.human_kingdom_name = kingdom_name
	GameManager.rival_count = rival_count
	GameManager.difficulty = difficulty
	GameManager.human_race = race
	game_setup_screen.visible = false
	await _show_loading_screen("Gerando o Mapa...")
	await _start_game()
	_hide_loading_screen()
	_enter_gameplay()

func _on_title_load_requested(slot_id: String) -> void:
	await _show_loading_screen("Carregando Partida...")
	var success := _try_load_game(slot_id)
	_hide_loading_screen()
	if success:
		_enter_gameplay()
	else:
		title_screen.show_error("Nao foi possivel carregar a partida salva (arquivo ausente ou corrompido).")

## Carregar durante uma partida em andamento (a partir do menu de pausa,
## que ja se despausou/escondeu antes de emitir este sinal, apos o
## jogador confirmar no ConfirmationDialog de PauseMenu.gd — ver
## PauseMenu._on_slot_load_requested) substitui o jogo atual pelo save —
## HUD/titulo ja estao no estado certo, so precisa garantir isso de novo
## caso o load venha a acontecer antes de qualquer _enter_gameplay()
## anterior (defensivo, nao deveria ocorrer na pratica).
func _on_pause_load_requested(slot_id: String) -> void:
	await _show_loading_screen("Carregando Partida...")
	var success := _try_load_game(slot_id)
	_hide_loading_screen()
	if success:
		_enter_gameplay()
	else:
		EventBus.notify.emit("Nao foi possivel carregar a partida salva.", "")

## Restaurar apos "Vencer/Perder Agora" (Debug) ou o botao "Jogar de Novo"
## da tela de fim de jogo — HUD ja fica visivel (a tela de fim de jogo e
## so mais um overlay por cima dela), entao nao precisa de _enter_gameplay()
## de novo aqui, so regenerar o mapa com a tela de loading no meio.
func _on_restart_requested() -> void:
	await _show_loading_screen("Gerando o Mapa...")
	await _start_game()
	_hide_loading_screen()

## Roadmap "sistema de menu de jogo moderno" — pedido do usuario: "voltar
## pro menu principal de fato volta pro menu principal, atualmente ele
## continua na partida mas mostrando as opcoes de menu, o que nao faz
## sentido, o comportamento correto e fechar a partida". Antes so mudava
## `state`/visibilidade de tela; GameManager.end_match() agora encerra a
## partida de verdade (ver comentario la — inclusive corta uma fila de IA
## que continuaria sendo processada em segundo plano). hex_grid.visible
## = false evita o mapa 3D continuar renderizado (parado, mas visivel)
## atras da tela de titulo.
func _on_pause_main_menu_requested() -> void:
	GameManager.end_match()
	hex_grid.visible = false
	hud.visible = false
	title_screen.visible = true
	title_screen.refresh_load_button()

## Pedido do usuario: "ta tendo um certo delay ao dar play... vamos colocar
## uma tela de loading, igual o civilization tem enquanto carrega o mapa,
## pra nao parecer que travou". Mostra a LoadingScreen e espera ela CHEGAR
## a ser desenhada antes de devolver o controle pro chamador — sem os
## `await`s, `visible = true` so mudaria o ESTADO nesse frame, mas o
## trabalho pesado comecaria ANTES do frame seguinte renderizar de verdade
## essa mudanca, e a tela de loading nunca chegaria a aparecer antes do
## travamento. Dois `process_frame` em vez de um (margem de seguranca:
## processamento e apresentacao do frame nem sempre andam juntos no mesmo
## ciclo).
##
## Sessao seguinte, pedido do usuario: "a tela de loading aparenta
## congelar". Causa: generate_map() sendo 100% sincrono, a tela chegava a
## SER DESENHADA (graças ao paragrafo acima) mas nunca mais se REDESENHAVA
## durante os ~2.5-2.8s de trabalho (mapa Grande, ver PERFORMANCE_GUIDE.md
## secao 5) — spinner parado, janela podendo ate aparentar "Not Responding"
## pro Windows, porque nada processava a fila de mensagens do SO nesse
## meio-tempo. Rodar generate_map() numa Thread separada nao e' opcao segura
## aqui (Godot nao permite mexer em Node/MultiMesh fora da thread principal
## sem cuidado extra — ver _rebuild_multimesh). Fix: HexGrid.generate_map()
## ganhou um `progress_callback` OPCIONAL (default Callable() invalido, todo
## teste/benchmark continua 100% sincrono e inalterado) que, quando valido,
## reporta fase+fracao e cede um `await get_tree().process_frame` entre cada
## etapa pesada — o loop principal do Godot re-renderiza (spinner/barra de
## progresso da LoadingScreen se movem de verdade) e processa mensagens do
## SO entre uma etapa e outra, sem paralelismo real nenhum. `loading_screen.
## set_progress` (Callable por referencia de metodo) e' passado direto pra
## generate_map() em _start_game() abaixo.
##
## Limitacao conhecida: SO o fluxo de Novo Jogo/Reiniciar (_start_game, que
## chama generate_map() direto) ganhou isso. _try_load_game() (Carregar
## Partida) continua chamando SaveManager.load_from_slot()/load_game() 100%
## sincrono, sem progress_callback — tentei propagar o callback tambem por
## ali, mas load_game() vira coroutine ao dar `await` em generate_map(), e
## GDScript exige `await` em TODO call site de uma funcao coroutine que
## devolve valor (nao só void); load_game()/load_from_slot() sao chamados
## SEM await em ~80 lugares em test_save_manager.gd/test_magic_v1.gd
## (confirmado rodando a suite: os dois arquivos falharam no parse e foram
## SILENCIOSAMENTE ignorados pelo GUT). Corrigir isso exigiria editar todos
## esses call sites — refatoracao ampla desproporcional a uma tela de
## loading. Carregar Partida continua com o visual novo (emblema/glow/
## poeira), mas volta a "congelar" durante o load em si, mesmo bug de antes.
func _show_loading_screen(message: String) -> void:
	loading_screen.set_message(message)
	loading_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_screen.modulate.a = 1.0
	loading_screen.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

## Fade curto e NAO bloqueante (chamado sem `await` nos handlers acima) — o
## mapa/HUD ja ficam clicaveis imediatamente (mouse_filter solto antes do
## tween comecar), o fade e' so cosmetico por cima, a "transicao suave"
## pedida pelo usuario em vez do corte seco de antes (visible = false direto).
func _hide_loading_screen() -> void:
	loading_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(loading_screen, "modulate:a", 0.0, 0.35)
	await tween.finished
	loading_screen.visible = false

func _try_load_game(slot_id: String) -> bool:
	if not SaveManager.load_from_slot(hex_grid, slot_id):
		return false
	hex_grid.visible = true
	GameManager.current_save_slot = slot_id
	SelectionManager.reset()
	camera_rig.reset_view(_human_camera_focus())
	return true

func _enter_gameplay() -> void:
	title_screen.visible = false
	hud.visible = true

func _start_game() -> void:
	hex_grid.visible = true
	await hex_grid.generate_map(GameManager.map_width, GameManager.map_height, -1, loading_screen.set_progress)
	GameManager.start_new_game(hex_grid)
	GameManager.current_save_slot = SaveManager.new_slot_id()
	SelectionManager.reset()
	camera_rig.reset_view(_human_camera_focus())

## Posicao no mundo pra centralizar a camera: cidade do jogador humano se
## ja tiver uma (partida carregada, ou apos fundar a capital), senao a
## primeira unidade dele (settler/warrior recem-spawnados numa partida
## nova, ver GameManager._spawn_starting_forces) — pedido do usuario:
## "faça ao começar o game a camera começar centralizada na sua tropa
## inicial... voce tem que tentar achar seu boneco". Vector3.ZERO (o
## comportamento antigo, sempre a origem do mundo) so sobra como fallback
## defensivo pro caso de nao haver unidade/cidade nenhuma, o que nao
## deveria acontecer na pratica logo apos _start_game()/_try_load_game().
func _human_camera_focus() -> Vector3:
	var player := GameManager.human_player
	if player == null:
		return Vector3.ZERO
	if not player.cities.is_empty():
		var coord: Vector2i = player.cities[0].coord
		return HexMetrics.axial_to_world(coord.x, coord.y, hex_grid.hex_size)
	if not player.units.is_empty():
		var coord: Vector2i = player.units[0].coord
		return HexMetrics.axial_to_world(coord.x, coord.y, hex_grid.hex_size)
	return Vector3.ZERO
