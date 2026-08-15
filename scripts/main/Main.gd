extends Node3D

@onready var hex_grid: HexGrid = $HexGrid
@onready var camera_rig: RTSCamera = $CameraRig
@onready var hud: Control = $UILayer/HUD
@onready var title_screen: Control = $UILayer/TitleScreen
@onready var game_setup_screen: Control = $UILayer/GameSetupScreen
@onready var pause_menu: Control = $UILayer/PauseMenu

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
	EventBus.restart_requested.connect(_start_game)
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
	_start_game()
	_enter_gameplay()

func _on_title_load_requested() -> void:
	if _try_load_game():
		_enter_gameplay()
	else:
		title_screen.show_error("Nao foi possivel carregar a partida salva (arquivo ausente ou corrompido).")

## Carregar durante uma partida em andamento (a partir do menu de pausa,
## que ja se despausou/escondeu antes de emitir este sinal) substitui o
## jogo atual pelo save — HUD/titulo ja estao no estado certo, so precisa
## garantir isso de novo caso o load venha a acontecer antes de qualquer
## _enter_gameplay() anterior (defensivo, nao deveria ocorrer na pratica).
func _on_pause_load_requested() -> void:
	if _try_load_game():
		_enter_gameplay()
	else:
		EventBus.notify.emit("Nao foi possivel carregar a partida salva.", "")

func _on_pause_main_menu_requested() -> void:
	GameManager.state = GameManager.GameState.MENU
	hud.visible = false
	title_screen.visible = true
	title_screen.refresh_load_button()

func _try_load_game() -> bool:
	if not SaveManager.load_game(hex_grid):
		return false
	SelectionManager.reset()
	camera_rig.reset_view()
	return true

func _enter_gameplay() -> void:
	title_screen.visible = false
	hud.visible = true

func _start_game() -> void:
	hex_grid.generate_map(GameManager.map_width, GameManager.map_height)
	GameManager.start_new_game(hex_grid)
	SelectionManager.reset()
	camera_rig.reset_view()
