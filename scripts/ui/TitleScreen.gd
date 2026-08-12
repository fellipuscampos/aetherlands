class_name TitleScreen
extends Control

## Tela de titulo: nome do reino + tamanho do mapa antes de um jogo novo, ou
## carregar a partida salva. Main.gd escuta os sinais e decide o que fazer —
## esta tela nao mexe em HexGrid/GameManager diretamente. `class_name`
## exposto pra MAP_SIZES poder ser referenciado por outros scripts/testes
## (ex: test_game_manager.gd) sem duplicar os numeros.

signal new_game_requested(width: int, height: int, kingdom_name: String, rival_count: int, difficulty: String)
signal load_game_requested

## Mapa retangular de verdade (nao mais losango hexagonal de raio unico —
## ver HexGrid.generate_map) com as dimensoes EXATAS pedidas pelo
## usuario: "Pequeno (Small): 74 x 46 celulas, totalizando 3.404
## hexagonos. Medio/Padrao (Standard): 84 x 54 celulas, totalizando 4.536
## hexagonos. Grande (Large): 96 x 60 celulas, totalizando 5.760
## hexagonos." — os proprios numeros do Civilization pro tamanho do mapa
## (grade retangular la tambem), agora batendo exatamente em vez de so
## aproximado como a versao anterior baseada em raio.
const MAP_SIZES := {
	"small": {"width": 74, "height": 46},
	"medium": {"width": 84, "height": 54},
	"large": {"width": 96, "height": 60},
}

@onready var kingdom_name_edit: LineEdit = $CenterBox/Box/KingdomNameEdit
@onready var small_button: Button = $CenterBox/Box/MapSizeRow/SmallButton
@onready var medium_button: Button = $CenterBox/Box/MapSizeRow/MediumButton
@onready var large_button: Button = $CenterBox/Box/MapSizeRow/LargeButton
@onready var one_rival_button: Button = $CenterBox/Box/RivalCountRow/OneRivalButton
@onready var two_rivals_button: Button = $CenterBox/Box/RivalCountRow/TwoRivalsButton
@onready var three_rivals_button: Button = $CenterBox/Box/RivalCountRow/ThreeRivalsButton
@onready var easy_button: Button = $CenterBox/Box/DifficultyRow/EasyButton
@onready var normal_button: Button = $CenterBox/Box/DifficultyRow/NormalButton
@onready var hard_button: Button = $CenterBox/Box/DifficultyRow/HardButton
@onready var new_game_button: Button = $CenterBox/Box/NewGameButton
@onready var load_game_button: Button = $CenterBox/Box/LoadGameButton
@onready var settings_button: Button = $CenterBox/Box/SettingsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var quit_button: Button = $CenterBox/Box/QuitButton
@onready var status_label: Label = $CenterBox/Box/StatusLabel

var _selected_size := "medium"
var _selected_rival_count := 1
var _selected_difficulty := "normal"

func _ready() -> void:
	theme = UITheme.build()
	small_button.pressed.connect(_on_size_pressed.bind("small"))
	medium_button.pressed.connect(_on_size_pressed.bind("medium"))
	large_button.pressed.connect(_on_size_pressed.bind("large"))
	one_rival_button.pressed.connect(_on_rival_count_pressed.bind(1))
	two_rivals_button.pressed.connect(_on_rival_count_pressed.bind(2))
	three_rivals_button.pressed.connect(_on_rival_count_pressed.bind(3))
	easy_button.pressed.connect(_on_difficulty_pressed.bind("easy"))
	normal_button.pressed.connect(_on_difficulty_pressed.bind("normal"))
	hard_button.pressed.connect(_on_difficulty_pressed.bind("hard"))
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(settings_panel.toggle)
	quit_button.pressed.connect(_on_quit_pressed)
	refresh_load_button()

func refresh_load_button() -> void:
	load_game_button.disabled = not SaveManager.has_save()

## Usado pelo Main.gd quando carregar falha (save corrompido/versao velha)
## — nesse ponto a HUD ainda esta escondida, entao o toast normal de
## EventBus.notify nao apareceria pra ninguem ver.
func show_error(text: String) -> void:
	status_label.text = text

func _on_size_pressed(size_key: String) -> void:
	_selected_size = size_key

func _on_rival_count_pressed(count: int) -> void:
	_selected_rival_count = count

func _on_difficulty_pressed(difficulty: String) -> void:
	_selected_difficulty = difficulty

func _on_new_game_pressed() -> void:
	var size: Dictionary = MAP_SIZES[_selected_size]
	new_game_requested.emit(
		size.width, size.height, kingdom_name_edit.text.strip_edges(), _selected_rival_count, _selected_difficulty
	)

func _on_load_game_pressed() -> void:
	load_game_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
