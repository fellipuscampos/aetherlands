class_name LoadingScreen
extends Control

## Pedido original do usuario: "ta tendo um certo delay ao dar play, acho
## que a geração do mapa ta demorando um pouco, vamos colocar uma tela de
## loading, igual o civilization tem enquanto carrega o mapa, pra nao
## parecer que travou". Mesmo padrao "tela cheia" de TitleScreen/
## GameSetupScreen (Control root com tema proprio via UITheme.build()).
##
## Sessao seguinte, pedido do usuario: a tela "aparenta congelar" durante o
## carregamento e "nao combina mais com a identidade do jogo" — visual
## refeito (emblema arcano em vez de spinner simples, glow + poeira mágica
## de fundo, ver LoadingSpinner.gd e LoadingScreen.tscn) e progresso real:
## set_progress() e' chamado por HexGrid.generate_map()/SaveManager.
## load_from_slot() entre CADA etapa pesada da geracao (ver
## _report_generation_progress em HexGrid.gd), nao e' uma barra decorativa
## avancando sozinha.
@onready var title_label: Label = $CenterBox/Box/TitleLabel
@onready var detail_label: Label = $CenterBox/Box/DetailLabel
@onready var progress_bar: ProgressBar = $CenterBox/Box/ProgressRow/ProgressBar
@onready var percent_label: Label = $CenterBox/Box/ProgressRow/PercentLabel
@onready var motes: CPUParticles2D = $Motes

func _ready() -> void:
	_apply_accessibility()
	Settings.accessibility_changed.connect(_apply_accessibility)
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()

## "Gerando o Mapa..." (jogo novo) ou "Carregando Partida..." (load) — a
## mesma tela serve pros dois casos. Chamado UMA vez, antes do trabalho
## pesado comecar (ver Main._show_loading_screen); set_progress() abaixo
## assume o texto dali em diante.
func set_message(text: String) -> void:
	title_label.text = text
	detail_label.text = "Preparando os sistemas da partida."
	progress_bar.value = 0.0
	percent_label.text = "0%"

## Callable passada direto pra HexGrid.generate_map()/SaveManager.
## load_from_slot() (ver Main.gd) — chamada entre cada etapa REAL da
## geracao, nunca em timer/animacao falsa. Tween curto na barra so pra
## suavizar o salto entre uma etapa e outra, sem esconder o valor real.
func set_progress(fraction: float, phase_text: String) -> void:
	detail_label.text = phase_text
	var target := clampf(fraction, 0.0, 1.0) * 100.0
	var tween := create_tween()
	tween.tween_property(progress_bar, "value", target, Settings.motion_duration(0.25)).set_trans(Tween.TRANS_SINE)
	percent_label.text = "%d%%" % int(round(target))

func _apply_accessibility() -> void:
	theme = Settings.build_ui_theme()
	motes.emitting = not Settings.reduced_motion

func _layout_for_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	motes.position = viewport_size * 0.5
	motes.emission_rect_extents = viewport_size * 0.45
