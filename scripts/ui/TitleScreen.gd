class_name TitleScreen
extends Control

## Menu Principal: Novo Jogo / Carregar Jogo / Configuracoes / Sair —
## pedido do usuario: "reestruturação nos huds, nos menus... baseando em
## deixar parecido com os de civilization 6 a nivel de organização". No
## Civilization o Menu Principal so tem essas acoes; a configuracao de uma
## partida nova (nome do reino/raca/rivais/dificuldade) mora numa tela
## PROPRIA e dedicada (ver GameSetupScreen.gd), aberta so depois de clicar
## "Novo Jogo" aqui — antes tudo (menu + formulario inteiro) vivia
## amontoado numa coluna so nesta MESMA tela. Main.gd escuta os sinais e
## decide o que fazer — esta tela nao mexe em HexGrid/GameManager
## diretamente. `class_name` exposto pra MAP_SIZES poder ser referenciado
## por outros scripts/testes (ex: test_game_manager.gd) e por
## GameSetupScreen.gd (dono de verdade da tela que hoje LE esse tamanho)
## sem duplicar os numeros.

signal new_game_setup_requested
signal load_game_requested

## Mapa retangular de verdade (ver HexGrid.generate_map). Pequeno/Medio
## removidos do seletor (pedido do usuario: "elimine a criacao do mapa
## medio e pequeno, vamos a partir de agora usar so o grande") — sem UI
## nem outro codigo pedindo esses dois tamanhos, so o Grande continua
## aqui. Fica nesta classe (nao em GameSetupScreen, quem de fato consome)
## so pra nao quebrar quem ja referencia TitleScreen.MAP_SIZES.
## Canvas TOTAL (96x60 originais + Continente Vulcanico + Continente de
## Cristal + oceano de separacao, ver MAIN_ZONE_SIZE abaixo e
## HexGrid._zone_for) — pedido do usuario: "expandir o tamanho fixo do
## mapa pra acomodar dois novos continentes especiais".
const MAP_SIZES := {
	"large": {"width": 320, "height": 84},
}

## Pegada HISTORICA do continente principal — os 96x60 originais ("Grande
## (Large): 96 x 60 celulas, totalizando 5.760 hexagonos", os numeros do
## Civilization pro tamanho Grande de mapa) — permanece FIXA pra sempre,
## independente de quanto MAP_SIZES.large cresca pra caber os continentes
## especiais. HexGrid usa isto (nao MAP_SIZES.large) pra travar forma/
## clima/posicao do continente principal exatamente como sempre foram;
## GameManager usa pra travar a elipse de origem dos rivais no mesmo
## lugar de sempre. Sem isso, o continente principal se espalharia pra
## preencher o canvas novo maior e o gradiente de clima se comprimiria,
## mudando o continente principal sem nenhum pedido nesse sentido.
const MAIN_ZONE_SIZE := {"width": 96, "height": 60}

@onready var new_game_button: Button = $CenterBox/Box/NewGameButton
@onready var load_game_button: Button = $CenterBox/Box/LoadGameButton
@onready var settings_button: Button = $CenterBox/Box/SettingsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var quit_button: Button = $CenterBox/Box/QuitButton
@onready var status_label: Label = $CenterBox/Box/StatusLabel

func _ready() -> void:
	theme = UITheme.build()
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

func _on_new_game_pressed() -> void:
	new_game_setup_requested.emit()

func _on_load_game_pressed() -> void:
	load_game_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
