extends Control

## Menu de pausa: ESC ou o botao "Menu" da HUD (via EventBus.pause_requested)
## abre isto por cima do jogo e congela tudo com get_tree().paused = true —
## camera, IA, animacoes de unidade etc. param sozinhos (process_mode padrao
## deles e PAUSABLE/INHERIT). So este Control roda com PROCESS_MODE_ALWAYS,
## senao os proprios botoes do menu de pausa parariam de responder.
## Salvar/Sair/Continuar sao resolvidos aqui mesmo; Carregar e Voltar ao
## Menu exigem coordenar hex_grid/HUD/tela de titulo, entao so emitem
## sinal pro Main.gd cuidar disso (e sempre despausam antes de emitir).

signal load_requested
signal main_menu_requested

@onready var resume_button: Button = $CenterBox/Box/ResumeButton
@onready var save_button: Button = $CenterBox/Box/SaveButton
@onready var load_button: Button = $CenterBox/Box/LoadButton
@onready var settings_button: Button = $CenterBox/Box/SettingsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var main_menu_button: Button = $CenterBox/Box/MainMenuButton
@onready var quit_button: Button = $CenterBox/Box/QuitButton
@onready var status_label: Label = $CenterBox/Box/StatusLabel

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(settings_panel.toggle)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	EventBus.pause_requested.connect(toggle)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and GameManager.state == GameManager.GameState.PLAYING:
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
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	settings_panel.close()
	get_tree().paused = false

func _on_save_pressed() -> void:
	if SaveManager.save_game(GameManager.hex_grid):
		status_label.text = "Jogo salvo."
	else:
		status_label.text = "Falha ao salvar."

func _on_load_pressed() -> void:
	close()
	load_requested.emit()

func _on_main_menu_pressed() -> void:
	close()
	main_menu_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
