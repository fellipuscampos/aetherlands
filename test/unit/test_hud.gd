extends GutTest

## Cobre a correcao dos bugs de sobreposicao que o usuario reportou
## ("alguns [paineis] entram um por cima do outro"): fim de jogo aparecendo
## por cima de um overlay (Tecnologia/Diplomacia/Ajuda) ainda aberto, e
## botoes que deveriam ficar desabilitados depois do fim de jogo pra nao
## dar pra "fechar" a tela de vitoria/derrota sem querer.

var hud: Control
var _original_state
var _original_human_player: PlayerData

func before_each():
	_original_state = GameManager.state
	_original_human_player = GameManager.human_player
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	GameManager.state = _original_state
	GameManager.human_player = _original_human_player

func test_close_topmost_overlay_returns_false_when_nothing_is_open():
	assert_false(hud.close_topmost_overlay())

func test_close_topmost_overlay_closes_tech_panel():
	hud._on_tech_pressed()
	assert_true(hud.tech_panel.visible, "pre-condicao: painel deveria abrir")

	var closed = hud.close_topmost_overlay()

	assert_true(closed)
	assert_false(hud.tech_panel.visible)
	assert_false(hud.overlay_backdrop.visible, "fundo escurecido deveria sumir junto com o painel")

func test_close_topmost_overlay_closes_diplomacy_panel():
	hud._on_diplomacy_pressed()
	assert_true(hud.diplomacy_panel.visible)

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.diplomacy_panel.visible)

## Regressao: abrir Diplomacia enquanto Tecnologia esta aberta precisa
## fechar a primeira — essa regra ja existia antes, so confirmando que
## sobreviveu ao _show_overlay() novo.
func test_opening_a_second_overlay_closes_the_first_one():
	hud._on_tech_pressed()
	hud._on_diplomacy_pressed()

	assert_false(hud.tech_panel.visible, "abrir diplomacia deveria fechar tecnologia")
	assert_true(hud.diplomacy_panel.visible)

## Regressao principal reportada pelo usuario: painel de fim de jogo
## aparecendo POR CIMA de um overlay ainda aberto. _on_game_over() agora
## fecha qualquer overlay ANTES de mostrar o proprio.
func test_game_over_closes_any_open_overlay_panel():
	hud._on_tech_pressed()
	assert_true(hud.tech_panel.visible)

	hud._on_game_over(true)

	assert_false(hud.tech_panel.visible, "painel de tecnologia nao deveria continuar visivel por baixo do fim de jogo")
	assert_true(hud.game_over_panel.visible)
	assert_true(hud.overlay_backdrop.visible)

## Sem isso, o jogador podia clicar "Tecnologia" depois do fim de jogo e
## a tela de vitoria/derrota sumia sem nenhum jeito de trazer ela de volta
## (so o restart limpa esse estado).
func test_game_over_disables_buttons_that_would_dismiss_the_screen():
	hud._on_game_over(true)

	assert_true(hud.tech_button.disabled)
	assert_true(hud.diplomacy_button.disabled)
	assert_true(hud.help_button.disabled)
	assert_true(hud.debug_button.disabled)

func test_restart_reenables_overlay_buttons():
	hud._on_game_over(true)

	hud._on_restart_pressed()

	assert_false(hud.tech_button.disabled)
	assert_false(hud.diplomacy_button.disabled)
	assert_false(hud.help_button.disabled)
	assert_false(hud.debug_button.disabled)
	assert_false(hud.game_over_panel.visible)

## Painel de Debug (pedido do usuario: "adicione opcoes debug onde eu
## posso tirar a fog do mapa e coisas assim") segue a MESMA regra de "so
## um overlay por vez" que Ajuda/Tecnologia/Diplomacia ja tinham.
func test_close_topmost_overlay_closes_debug_panel():
	hud._on_debug_pressed()
	assert_true(hud.debug_panel.visible, "pre-condicao: painel deveria abrir")

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.debug_panel.visible)

func test_opening_debug_panel_closes_an_already_open_overlay():
	hud._on_tech_pressed()

	hud._on_debug_pressed()

	assert_false(hud.tech_panel.visible, "abrir debug deveria fechar tecnologia")
	assert_true(hud.debug_panel.visible)

func test_debug_button_only_visible_in_debug_builds():
	assert_eq(hud.debug_button.visible, OS.is_debug_build(), "botao de Debug nao deveria aparecer num export de release")

func test_debug_gold_button_adds_gold_to_human_player():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.gold = 50.0

	hud._on_debug_gold_pressed()

	assert_almost_eq(GameManager.human_player.gold, 150.0, 0.01)
	assert_eq(hud.gold_label.text, "Ouro: 150")

## Vencer/Perder Agora reaproveitam o MESMO sinal EventBus.game_over que o
## fim de jogo real usa — clicar um dos dois deveria fechar o painel de
## debug e mostrar a tela de fim de jogo, exatamente como um fim de jogo
## de verdade (ver _on_game_over ja testado acima).
func test_debug_win_button_shows_the_game_over_screen():
	GameManager.state = GameManager.GameState.PLAYING
	hud._on_debug_pressed()

	hud._on_debug_win_pressed()

	assert_true(hud.game_over_panel.visible)
	assert_false(hud.debug_panel.visible, "painel de debug deveria fechar junto com o fim de jogo forcado")

func test_debug_lose_button_shows_the_game_over_screen():
	GameManager.state = GameManager.GameState.PLAYING

	hud._on_debug_lose_pressed()

	assert_true(hud.game_over_panel.visible)
