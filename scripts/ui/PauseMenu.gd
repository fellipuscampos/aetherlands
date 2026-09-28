extends Control

## Menu de pausa: SO a tecla ESC abre isto (pedido do usuario: "tire o meu
## das opções tambem, o menu é o proprio esc... nao precisa de um botao
## escrito menu" — o botao "Menu" da HUD e o EventBus.pause_requested que
## ele emitia foram removidos, ESC ja bastava sozinho) por cima do jogo,
## congelando tudo com get_tree().paused = true — camera, IA, animacoes de
## unidade etc. param sozinhos (process_mode padrao deles e PAUSABLE/
## INHERIT). So este Control roda com PROCESS_MODE_ALWAYS, senao os
## proprios botoes do menu de pausa parariam de responder.
##
## Roadmap "sistema de menu de jogo moderno" — pedido do usuario: "o menu
## ter sistema de paginas... todas as funcionalidades dele devem
## funcionar e poder navegar indo e voltando entre paginas... carregar
## jogo deve abrir uma tela... configuracoes deve abrir outra tela... o
## debug tambem fica no menu [dentro de configuracoes]". MainPage/
## LoadGameScreen/SettingsScreen sao 3 paginas irmas geridas por um
## MenuPager (ver scripts/ui/MenuPager.gd); reabrir a pausa (open()) sempre
## reseta pra MainPage, nunca resume no meio de uma sub-pagina de uma
## sessao anterior. Salvar/Carregar agora usam slots de verdade (ver
## SaveManager.gd/GameManager.current_save_slot) em vez do arquivo unico
## antigo. Debug nao e mais um botao solto aqui — mora dentro de
## SettingsScreen (debug_requested), mas continua chamando exatamente
## hud._on_debug_pressed() como sempre fez (o debug_panel em si, com todos
## os botoes de debug, e 100% intocado).
##
## Voltar ao Menu Principal e Sair sao resolvidos por Main.gd (o primeiro
## agora encerra a partida de verdade via GameManager.end_match(), ver
## comentario la); Salvar e resolvido aqui mesmo. Carregar (dentro da
## pausa) pede confirmacao antes de descartar a partida em andamento — a
## tela de titulo NAO pede (nunca ha partida em andamento pra perder la,
## ver TitleScreen._on_slot_load_requested).

signal load_requested(slot_id: String)
signal main_menu_requested

@onready var hud: Control = $"../HUD"
@onready var main_page: Control = $MainPage
@onready var resume_button: Button = $MainPage/CenterBox/Box/ResumeButton
@onready var save_button: Button = $MainPage/CenterBox/Box/SaveButton
@onready var load_button: Button = $MainPage/CenterBox/Box/LoadButton
@onready var settings_button: Button = $MainPage/CenterBox/Box/SettingsButton
@onready var developer_tools_button: Button = $MainPage/CenterBox/Box/DeveloperToolsButton
@onready var main_menu_button: Button = $MainPage/CenterBox/Box/MainMenuButton
@onready var quit_button: Button = $MainPage/CenterBox/Box/QuitButton
@onready var status_label: Label = $MainPage/CenterBox/Box/StatusLabel
@onready var session_label: Label = $MainPage/CenterBox/Box/SessionLabel
@onready var load_game_screen: Control = $LoadGameScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var confirm_load_dialog: ConfirmationDialog = $ConfirmLoadDialog
@onready var confirm_save_dialog: ConfirmationDialog = $ConfirmSaveDialog
@onready var confirm_main_menu_dialog: ConfirmationDialog = $ConfirmMainMenuDialog
@onready var confirm_quit_dialog: ConfirmationDialog = $ConfirmQuitDialog

var _pager: MenuPager
var _pending_load_slot_id: String = ""

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	visible = false
	_pager = MenuPager.new([main_page, load_game_screen, settings_screen])
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	developer_tools_button.pressed.connect(_on_debug_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	load_game_screen.back_requested.connect(_pager.back)
	load_game_screen.slot_load_requested.connect(_on_slot_load_requested)
	settings_screen.back_requested.connect(_pager.back)
	developer_tools_button.visible = OS.is_debug_build()
	confirm_load_dialog.title = "Confirmar"
	confirm_load_dialog.get_ok_button().text = "Carregar"
	confirm_load_dialog.get_cancel_button().text = "Cancelar"
	confirm_load_dialog.confirmed.connect(_on_load_confirmed)
	confirm_save_dialog.confirmed.connect(_perform_save)
	confirm_main_menu_dialog.confirmed.connect(_confirm_main_menu)
	confirm_quit_dialog.confirmed.connect(AudioManager.request_quit)
	if hud.ui_shell != null:
		hud.ui_shell.register_pause_action(open)

## Regressao: ESC abria o menu de pausa POR CIMA de um overlay da HUD
## (Tecnologia/Diplomacia/Grimorio) que estivesse aberto, deixando os dois
## empilhados (o overlay continuava visivel=true por baixo, reaparecendo
## assim que a pausa fechasse). Fecha o overlay da HUD primeiro, se tiver
## um aberto — so abre a pausa de verdade se nao tinha nenhum.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and GameManager.state == GameManager.GameState.PLAYING:
		if visible and _pager.current() != main_page:
			_pager.back()
			resume_button.call_deferred("grab_focus")
			get_viewport().set_input_as_handled()
			return
		if hud.ui_shell != null and hud.ui_shell.modal_manager.is_modal_open():
			hud.ui_shell.modal_manager.handle_escape()
			get_viewport().set_input_as_handled()
			return
		if SelectionManager.cancel_technique_targeting(): # Fase 7: ESC cancela a mira do Golpe Poderoso, sem pausar
			get_viewport().set_input_as_handled()
			return
		if SelectionManager.cancel_city_annexation(): # Fase 13: ESC cancela o modo de anexação de território, sem pausar
			get_viewport().set_input_as_handled()
			return
		if SelectionManager.cancel_city_attack_targeting(): # Fase 16: ESC cancela a mira do Ataque da Cidade, sem gastar o disparo
			get_viewport().set_input_as_handled()
			return
		if SelectionManager.cancel_v2_spell_targeting(): # Fase 17: ESC cancela a mira do feitiço V2, sem gastar Mana/recarga/ação
			get_viewport().set_input_as_handled()
			return
		if SelectionManager.cancel_building_placement(): # Fase 30: o banner de mira promete "ESC cancela" também no posicionamento
			get_viewport().set_input_as_handled()
			return
		if hud.close_topmost_overlay():
			get_viewport().set_input_as_handled()
			return
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if GameManager.state != GameManager.GameState.PLAYING and not visible:
		return
	if visible:
		close()
	else:
		open()

func open() -> void:
	status_label.text = ""
	_refresh_session_summary()
	_pager.reset_to(main_page)
	if hud.ui_shell != null:
		hud.ui_shell.set_system_surface_active(true)
	visible = true
	get_tree().paused = true
	resume_button.call_deferred("grab_focus")

func _apply_accessibility_theme() -> void:
	theme = Settings.build_ui_theme()

func close() -> void:
	visible = false
	if hud.ui_shell != null:
		hud.ui_shell.set_system_surface_active(false)
	get_tree().paused = false

func _on_save_pressed() -> void:
	if GameManager.current_save_slot == "":
		GameManager.current_save_slot = SaveManager.new_slot_id()
		_perform_save()
		return
	if SaveManager.list_slots().any(func(slot): return slot.slot_id == GameManager.current_save_slot):
		confirm_save_dialog.popup_centered()
		return
	_perform_save()

func _perform_save() -> void:
	confirm_save_dialog.hide()
	if SaveManager.save_to_slot(GameManager.hex_grid, GameManager.current_save_slot):
		status_label.text = "Jogo salvo neste slot."
		_refresh_session_summary()
	else:
		status_label.text = "Falha ao salvar."

func _on_load_button_pressed() -> void:
	load_game_screen.refresh()
	_pager.go_to(load_game_screen)

func _on_settings_pressed() -> void:
	settings_screen.refresh()
	_pager.go_to(settings_screen)
	settings_screen._show_page(0)

## Carregar de dentro da pausa descarta a partida em andamento sem aviso
## nenhum na tela — pede confirmacao antes (diferente da tela de titulo,
## que nunca tem partida nenhuma pra perder).
func _on_slot_load_requested(slot_id: String) -> void:
	_pending_load_slot_id = slot_id
	confirm_load_dialog.popup_centered()

func _on_load_confirmed() -> void:
	# hide() explicito (nao confiar so no auto-hide do AcceptDialog ao
	# clicar OK): garante o dialogo fechado mesmo se "confirmed" disparar
	# por outro caminho que nao o clique do proprio botao.
	confirm_load_dialog.hide()
	var slot_id := _pending_load_slot_id
	_pending_load_slot_id = ""
	close()
	load_requested.emit(slot_id)

## Fecha a pausa ANTES de abrir o painel de debug (mesmo padrao de
## _on_main_menu_pressed abaixo) — abrir um overlay da HUD por baixo da
## pausa ainda visivel deixaria os dois empilhados.
func _on_debug_pressed() -> void:
	close()
	hud._on_debug_pressed()

func _on_main_menu_pressed() -> void:
	confirm_main_menu_dialog.popup_centered()

func _confirm_main_menu() -> void:
	confirm_main_menu_dialog.hide()
	close()
	main_menu_requested.emit()

func _on_quit_pressed() -> void:
	confirm_quit_dialog.popup_centered()

func _refresh_session_summary() -> void:
	var player := GameManager.human_player
	if player == null:
		session_label.text = "Partida em andamento"
		return
	session_label.text = "%s · Turno %d · %d cidades · %d unidades" % [
		player.civ.civ_name, TurnManager.turn_number, player.cities.size(), player.units.size()
	]
