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
##
## Roadmap "sistema de menu de jogo moderno" — pedido do usuario: "carregar
## jogo deve abrir uma tela com os jogos possiveis de carregar... o
## configuracoes deve abrir outra tela... o menu ter sistema de paginas".
## MainPage/LoadGameScreen/SettingsScreen agora sao 3 paginas irmas
## gerenciadas por um MenuPager (ver scripts/ui/MenuPager.gd) — o antigo
## SettingsPanel.tscn (painel flutuante por cima do menu) foi removido, o
## conteudo dele virou SettingsScreen.tscn (tela cheia de verdade).

signal new_game_setup_requested
signal load_game_requested(slot_id: String)

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

@onready var main_page: Control = $MainPage
@onready var new_game_button: Button = $MainPage/CenterBox/Box/NewGameButton
@onready var load_game_button: Button = $MainPage/CenterBox/Box/LoadGameButton
@onready var settings_button: Button = $MainPage/CenterBox/Box/SettingsButton
@onready var quit_button: Button = $MainPage/CenterBox/Box/QuitButton
@onready var status_label: Label = $MainPage/CenterBox/Box/StatusLabel
@onready var load_game_screen: Control = $LoadGameScreen
@onready var settings_screen: Control = $SettingsScreen

var _pager: MenuPager

func _ready() -> void:
	theme = UITheme.build()
	_pager = MenuPager.new([main_page, load_game_screen, settings_screen])
	_pager.reset_to(main_page)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	load_game_screen.back_requested.connect(_pager.back)
	load_game_screen.slot_load_requested.connect(_on_slot_load_requested)
	settings_screen.back_requested.connect(_pager.back)
	refresh_load_button()

func refresh_load_button() -> void:
	load_game_button.disabled = not SaveManager.has_any_slots()

## Usado pelo Main.gd quando carregar falha (save corrompido/versao velha)
## — nesse ponto a HUD ainda esta escondida, entao o toast normal de
## EventBus.notify nao apareceria pra ninguem ver.
func show_error(text: String) -> void:
	status_label.text = text

func _on_new_game_pressed() -> void:
	new_game_setup_requested.emit()

func _on_load_game_pressed() -> void:
	load_game_screen.refresh()
	_pager.go_to(load_game_screen)

func _on_settings_pressed() -> void:
	settings_screen.refresh()
	_pager.go_to(settings_screen)

## Carregar da tela de titulo nunca tem partida em andamento pra perder —
## repassa direto, sem confirmacao nenhuma (diferente de PauseMenu, ver
## PauseMenu._on_slot_load_requested).
func _on_slot_load_requested(slot_id: String) -> void:
	load_game_requested.emit(slot_id)

func _on_quit_pressed() -> void:
	AudioManager.request_quit()
