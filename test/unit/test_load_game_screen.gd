extends GutTest

## Cobre LoadGameScreen.gd — Roadmap "sistema de menu de jogo moderno"
## (pedido do usuario: "carregar jogo deve abrir uma tela com os jogos
## possiveis de carregar, ai voce escolhe um e ele de fato e carregado...
## ai voce pode ver seus jogos ao clicar em carregar jogo"). Usa
## refresh(dir)/list_slots(dir) parametrizados (mesmo padrao de
## SaveManager.gd) pra nunca tocar em user://saves/ de verdade — este
## ambiente pode ja ter saves reais de sessoes de jogo anteriores.

const TEST_SAVE_DIR := "user://test_load_game_screen_saves/"

var screen: Control
var hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]

func before_each():
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.civ.civ_name = "Reino de Teste"
	GameManager.rival_players = []

	hex_grid = HexGrid.new()
	hex_grid._ready()
	autofree(hex_grid)

	screen = load("res://scenes/ui/LoadGameScreen.tscn").instantiate()
	add_child_autofree(screen)

func after_each():
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	_clear_test_save_dir()

func _clear_test_save_dir() -> void:
	var da := DirAccess.open(TEST_SAVE_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			da.remove(fname)
		fname = da.get_next()
	da.list_dir_end()

func test_empty_state_shown_when_no_slots_exist():
	screen.refresh(TEST_SAVE_DIR)

	assert_true(screen.empty_state_label.visible)
	assert_eq(screen.slot_list.get_child_count(), 0)

func test_refresh_lists_one_row_per_slot():
	SaveManager.save_to_slot(hex_grid, "slot_um", TEST_SAVE_DIR)
	SaveManager.save_to_slot(hex_grid, "slot_dois", TEST_SAVE_DIR)

	screen.refresh(TEST_SAVE_DIR)

	assert_false(screen.empty_state_label.visible)
	assert_eq(screen.slot_list.get_child_count(), 2)

func test_carregar_button_emits_slot_load_requested_with_correct_id():
	SaveManager.save_to_slot(hex_grid, "slot_alvo", TEST_SAVE_DIR)
	screen.refresh(TEST_SAVE_DIR)
	# Caixa de 1 elemento (nao uma String solta): lambdas em GDScript capturam
	# variaveis locais por VALOR, entao "received_slot_id = slot_id" dentro
	# do lambda mudaria so a copia dele, nunca a variavel de fora — um Array
	# e passado por REFERENCIA, entao mutar received[0] realmente propaga.
	var received := [""]
	screen.slot_load_requested.connect(func(slot_id): received[0] = slot_id)

	var row: Control = screen.slot_list.get_child(0)
	var load_button: Button = _find_button(row, "Carregar")
	load_button.pressed.emit()

	assert_eq(received[0], "slot_alvo")

func test_excluir_button_deletes_slot_after_confirmation_and_refreshes_list():
	SaveManager.save_to_slot(hex_grid, "slot_pra_excluir", TEST_SAVE_DIR)
	screen.refresh(TEST_SAVE_DIR)
	var row: Control = screen.slot_list.get_child(0)
	var delete_button: Button = _find_button(row, "Excluir")

	delete_button.pressed.emit()
	assert_true(screen.confirm_delete_dialog.visible, "excluir nao deveria apagar sem confirmar antes")
	screen.confirm_delete_dialog.confirmed.emit()

	assert_true(SaveManager.list_slots(TEST_SAVE_DIR).is_empty())
	assert_eq(screen.slot_list.get_child_count(), 0, "a lista deveria se atualizar sozinha apos excluir")
	assert_false(screen.confirm_delete_dialog.visible, "o dialogo de confirmacao tem que fechar sozinho apos excluir")

func test_back_button_emits_back_requested():
	var emitted := [false] # ver comentario em test_carregar_button_... acima
	screen.back_requested.connect(func(): emitted[0] = true)

	screen.back_button.pressed.emit()

	assert_true(emitted[0])

func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
