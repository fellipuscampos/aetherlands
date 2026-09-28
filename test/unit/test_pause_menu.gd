extends GutTest

## Cobre PauseMenu.gd — Roadmap "sistema de menu de jogo moderno" (pedido
## do usuario: "o menu ter sistema de paginas... carregar jogo deve abrir
## uma tela... o salvar salva de fato o jogo, criando um slot... o
## configuracoes deve abrir outra tela... la dentro tambem vai o debug").
## MainPage/LoadGameScreen/SettingsScreen agora sao 3 paginas geridas por
## um MenuPager (ver test_menu_pager.gd pro helper em si, testado
## isoladamente) — reabrir a pausa sempre volta pra MainPage, Salvar usa
## um slot real (GameManager.current_save_slot), Carregar navega SEM
## fechar a pausa (so fecha + emite load_requested depois de confirmar no
## ConfirmationDialog), e Debug mora dentro de SettingsScreen agora, nao
## mais um botao solto no menu principal da pausa.

var parent: Node
var pause_menu: Control
var hud: Control
var _original_state
var _original_human_player: PlayerData
var _original_hex_grid: HexGrid
var _original_current_save_slot: String
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_state = GameManager.state
	_original_human_player = GameManager.human_player
	_original_hex_grid = GameManager.hex_grid
	_original_current_save_slot = GameManager.current_save_slot
	_original_rival_players = GameManager.rival_players
	GameManager.rival_players = [] # isola o save de rivais deixados por outros arquivos de teste
	GameManager.state = GameManager.GameState.PLAYING
	parent = Node.new()
	add_child_autofree(parent)
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	hud.name = "HUD" # PauseMenu.gd resolve o irmao por esse nome exato ($"../HUD")
	parent.add_child(hud)
	var pause_menu_scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn")
	pause_menu = pause_menu_scene.instantiate()
	parent.add_child(pause_menu)

func after_each():
	GameManager.state = _original_state
	GameManager.rival_players = _original_rival_players
	GameManager.human_player = _original_human_player
	GameManager.hex_grid = _original_hex_grid
	GameManager.current_save_slot = _original_current_save_slot
	get_tree().paused = false

## --- Navegacao de paginas ---

func test_opening_pause_shows_only_main_page():
	pause_menu.open()

	assert_true(pause_menu.main_page.visible)
	assert_false(pause_menu.load_game_screen.visible)
	assert_false(pause_menu.settings_screen.visible)

func test_settings_button_navigates_to_settings_screen_without_closing_pause():
	pause_menu.open()

	pause_menu._on_settings_pressed()

	assert_true(pause_menu.visible, "configuracoes e uma pagina, nao deveria fechar a pausa")
	assert_true(get_tree().paused, "continua pausado dentro de uma sub-pagina do menu")
	assert_true(pause_menu.settings_screen.visible)
	assert_false(pause_menu.main_page.visible)

func test_settings_back_returns_to_main_page():
	pause_menu.open()
	pause_menu._on_settings_pressed()

	pause_menu.settings_screen.back_requested.emit()

	assert_true(pause_menu.main_page.visible)
	assert_false(pause_menu.settings_screen.visible)

## Regressao: reabrir a pausa nunca deveria resumir no meio de
## Configuracoes/Carregar Jogo de uma sessao de pausa ANTERIOR.
func test_reopening_pause_always_shows_main_page_even_after_visiting_settings():
	pause_menu.open()
	pause_menu._on_settings_pressed()
	pause_menu.close()

	pause_menu.open()

	assert_true(pause_menu.main_page.visible)
	assert_false(pause_menu.settings_screen.visible)

## --- Debug (agora dentro de SettingsScreen) ---

func test_developer_tools_has_its_own_debug_only_route():
	assert_false(pause_menu.settings_screen.debug_button.visible)
	assert_eq(pause_menu.developer_tools_button.visible, OS.is_debug_build())

func test_developer_tools_button_closes_pause_and_opens_the_hud_debug_panel():
	pause_menu.open()
	assert_true(pause_menu.visible)

	pause_menu.developer_tools_button.pressed.emit()

	assert_false(pause_menu.visible, "pausa deveria fechar ao abrir o debug")
	assert_false(get_tree().paused, "despausar e obrigatorio, senao o jogo trava atras do painel de debug")
	assert_true(hud.debug_panel.visible)

## --- Salvar (slot real) ---

func test_save_button_creates_a_slot_id_if_the_match_has_none_yet():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	autofree(hex_grid)
	GameManager.hex_grid = hex_grid
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.current_save_slot = ""

	pause_menu._on_save_pressed()

	assert_ne(GameManager.current_save_slot, "", "salvar sem slot ainda deveria criar um novo")
	SaveManager.delete_slot(GameManager.current_save_slot)

func test_save_button_overwrites_the_same_slot_on_repeated_saves():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	autofree(hex_grid)
	GameManager.hex_grid = hex_grid
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.current_save_slot = SaveManager.new_slot_id()
	var slot_id := GameManager.current_save_slot

	pause_menu._on_save_pressed()
	pause_menu._on_save_pressed()
	assert_true(pause_menu.confirm_save_dialog.visible)
	pause_menu.confirm_save_dialog.confirmed.emit()

	assert_eq(GameManager.current_save_slot, slot_id, "salvar de novo nao deveria trocar de slot")
	assert_eq(SaveManager.list_slots().filter(func(s): return s.slot_id == slot_id).size(), 1)
	SaveManager.delete_slot(slot_id)

func test_return_to_main_menu_requires_confirmation():
	pause_menu.open()
	var emitted := [false]
	pause_menu.main_menu_requested.connect(func(): emitted[0] = true)
	pause_menu._on_main_menu_pressed()
	assert_true(pause_menu.confirm_main_menu_dialog.visible)
	assert_false(emitted[0])
	pause_menu.confirm_main_menu_dialog.confirmed.emit()
	assert_true(emitted[0])

## --- Carregar (navega sem fechar; confirma antes de descartar a partida) ---

func test_load_button_navigates_to_load_screen_without_closing_pause():
	pause_menu.open()

	pause_menu._on_load_button_pressed()

	assert_true(pause_menu.visible, "carregar e uma pagina, nao deveria fechar a pausa direto")
	assert_true(pause_menu.load_game_screen.visible)

func test_picking_a_slot_opens_a_confirmation_dialog_instead_of_loading_immediately():
	pause_menu.open()

	pause_menu.load_game_screen.slot_load_requested.emit("algum_slot")

	assert_true(pause_menu.visible, "nao deveria fechar/carregar antes de confirmar")
	assert_true(pause_menu.confirm_load_dialog.visible)

func test_confirming_the_load_dialog_closes_pause_and_emits_load_requested_with_slot_id():
	pause_menu.open()
	pause_menu.load_game_screen.slot_load_requested.emit("slot_confirmado")
	# Array de 1 elemento (nao uma String solta): lambdas em GDScript
	# capturam variaveis locais por VALOR — Array e por referencia, entao
	# mutar received[0] dentro do lambda realmente propaga pra fora.
	var received := [""]
	pause_menu.load_requested.connect(func(slot_id): received[0] = slot_id)

	pause_menu._on_load_confirmed()

	assert_false(pause_menu.visible)
	assert_false(get_tree().paused)
	assert_eq(received[0], "slot_confirmado")
	assert_false(pause_menu.confirm_load_dialog.visible, "o dialogo de confirmacao tem que fechar sozinho, nao pode ficar flutuando por cima da tela seguinte")
