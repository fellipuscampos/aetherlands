extends GutTest

## Cobre TitleScreen.gd — Roadmap "sistema de menu de jogo moderno" (pedido
## do usuario: "carregar jogo deve abrir uma tela com os jogos possiveis
## de carregar... o configuracoes deve abrir outra tela... nao abrir um
## dropdown por cima do menu atual"). Nao existia teste nenhum pra esta
## tela antes desta rodada.

var title_screen: Control
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	title_screen = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	add_child_autofree(title_screen)

func after_each():
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players

func test_settings_button_opens_a_full_screen_page_not_a_dropdown():
	title_screen._on_settings_pressed()

	assert_true(title_screen.settings_screen.visible)
	assert_false(title_screen.main_page.visible)
	# Tela cheia de verdade: mesmas ancoras full-rect do resto da tela,
	# nao um PanelContainer pequeno flutuando por cima (o antigo
	# SettingsPanel.tscn, removido nesta rodada).
	assert_eq(title_screen.settings_screen.anchor_right, 1.0)
	assert_eq(title_screen.settings_screen.anchor_bottom, 1.0)

func test_settings_screen_on_title_has_no_debug_button():
	assert_false(title_screen.settings_screen.show_debug, "tela de titulo nunca tem partida ativa pro Debug mexer")
	assert_false(title_screen.settings_screen.debug_button.visible)

func test_settings_back_returns_to_main_page():
	title_screen._on_settings_pressed()

	title_screen.settings_screen.back_requested.emit()

	assert_true(title_screen.main_page.visible)
	assert_false(title_screen.settings_screen.visible)

func test_load_game_button_navigates_to_load_screen():
	title_screen._on_load_game_pressed()

	assert_true(title_screen.load_game_screen.visible)
	assert_false(title_screen.main_page.visible)

func test_picking_a_slot_forwards_load_game_requested_with_slot_id_without_confirmation():
	# Array de 1 elemento (nao uma String solta): lambdas em GDScript
	# capturam variaveis locais por VALOR, entao mutar a variavel direto
	# dentro do lambda nao propagaria pra fora — Array e por referencia.
	var received := [""]
	title_screen.load_game_requested.connect(func(slot_id): received[0] = slot_id)

	title_screen.load_game_screen.slot_load_requested.emit("um_slot_qualquer")

	assert_eq(received[0], "um_slot_qualquer", "titulo nunca tem partida em andamento pra perder, repassa direto sem dialogo")

## Cria e apaga um slot DE VERDADE (SaveManager.SAVE_DIR real — TitleScreen
## nao tem parametro de diretorio pra isolar, diferente dos testes de
## SaveManager) so pra confirmar que refresh_load_button() reage a um slot
## existir; nunca afirma o oposto (desabilitado sem slot nenhum), porque
## este ambiente pode ja ter saves reais de sessoes de jogo anteriores.
func test_load_game_button_enables_once_a_slot_exists():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.civ.civ_name = "Reino de Teste do Titulo"
	GameManager.rival_players = []
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	autofree(hex_grid)
	var slot_id := SaveManager.new_slot_id()

	SaveManager.save_to_slot(hex_grid, slot_id)
	title_screen.refresh_load_button()
	var enabled_with_slot: bool = not title_screen.load_game_button.disabled

	SaveManager.delete_slot(slot_id)

	assert_true(enabled_with_slot, "botao deveria habilitar assim que existe pelo menos 1 slot")
