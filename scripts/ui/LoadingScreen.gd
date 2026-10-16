class_name LoadingScreen
extends Control

## Loading no estilo dos menus pixelados: cenário estático, barra em bronze
## e indicador arcano discreto. set_progress continua recebendo etapas reais
## de HexGrid. A restauração síncrona de saves usa indicador indeterminado,
## sem inventar uma porcentagem ou alterar o pipeline de carregamento.
@onready var title_label: Label = $CenterBox/Box/TitleLabel
@onready var detail_label: Label = $CenterBox/Box/DetailLabel
@onready var progress_bar: ProgressBar = $CenterBox/Box/ProgressRow/ProgressBar
@onready var percent_label: Label = $CenterBox/Box/ProgressRow/PercentLabel
@onready var emblem: LoadingSpinner = $Footer/Emblem

const MENU_THEME := preload("res://scripts/ui/LoadingScreenTheme.gd")
var _progress_tween: Tween
var _target_progress := 0.0
var _waiting_for_save := false
var _layout_passes := 0

func _ready() -> void:
	_apply_accessibility()
	Settings.accessibility_changed.connect(_apply_accessibility)
	get_viewport().size_changed.connect(_queue_layout)
	visibility_changed.connect(_on_visibility_changed)
	_queue_layout()

func _queue_layout() -> void:
	# Hidden containers have not shaped wrapped text yet. Reflow over the next
	# two frames, which Main already yields before starting generation.
	_layout_passes = 2
	set_process(true)
	_layout_for_viewport()

func _process(_delta: float) -> void:
	_layout_for_viewport()
	_layout_passes -= 1
	if _layout_passes <= 0:
		set_process(false)

func _on_visibility_changed() -> void:
	if is_node_ready() and is_visible_in_tree():
		_queue_layout()

## "Gerando o Mapa..." (jogo novo) ou "Carregando Partida..." (load) — a
## mesma tela serve pros dois casos. Chamado UMA vez, antes do trabalho
## pesado comecar (ver Main._show_loading_screen); set_progress() abaixo
## assume o texto dali em diante.
func set_message(text: String) -> void:
	_stop_progress_tween()
	title_label.text = text
	_waiting_for_save = "carregando" in text.to_lower()
	detail_label.text = "Restaurando sua partida salva." if _waiting_for_save else "Preparando seu mundo."
	_target_progress = 0.0
	progress_bar.value = 0.0
	progress_bar.indeterminate = _waiting_for_save and not Settings.reduced_motion
	percent_label.text = "AGUARDE" if _waiting_for_save else "0%"
	_queue_layout()

## Callback existente da geração: cada atualização vem de uma etapa real,
## sem avanço por timer. O tween apenas suaviza o salto informado. Saves
## atualmente não publicam porcentagens; um callback futuro pode usar a
## mesma API para substituir o estado indeterminado por progresso conhecido.
func set_progress(fraction: float, phase_text: String) -> void:
	detail_label.text = phase_text
	var target := clampf(fraction, 0.0, 1.0) * 100.0
	_waiting_for_save = false
	progress_bar.indeterminate = false
	_target_progress = target
	_stop_progress_tween()
	if Settings.reduced_motion or is_equal_approx(target, 100.0):
		progress_bar.value = target
	else:
		_progress_tween = create_tween()
		_progress_tween.tween_property(progress_bar, "value", target, Settings.motion_duration(0.18)).set_trans(Tween.TRANS_SINE)
	percent_label.text = "%d%%" % int(round(target))

func _stop_progress_tween() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = null

func _apply_accessibility() -> void:
	theme = MENU_THEME.build(Settings.ui_scale_factor())
	progress_bar.indeterminate = _waiting_for_save and not Settings.reduced_motion
	if Settings.reduced_motion:
		_stop_progress_tween()
		progress_bar.value = _target_progress
	_queue_layout.call_deferred()

func _layout_for_viewport() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var factor := Settings.ui_scale_factor()
	var edge := roundf(clampf(viewport_size.x * .07, 32, 160))
	var width := minf(viewport_size.x - edge * 2, 960 * maxf(1, factor))
	var brand: HBoxContainer = $Brand
	brand.position = Vector2(edge, 28 if viewport_size.y < 800 else 40)
	$Brand/Titles/Name.add_theme_font_size_override("font_size", roundi(minf(48 * factor, (viewport_size.x - edge * 2 - 80) / 6.6)))
	brand.size = Vector2(width, brand.get_combined_minimum_size().y)
	var box: VBoxContainer = $CenterBox/Box
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", roundi(12 * factor))
	title_label.add_theme_font_size_override("font_size", roundi(32 * factor))
	detail_label.custom_minimum_size.y = roundf(52 * factor)
	progress_bar.custom_minimum_size.y = roundf(28 * factor)
	percent_label.add_theme_font_size_override("font_size", roundi((20 if _waiting_for_save else 26) * factor))
	percent_label.custom_minimum_size.x = roundf((120 if _waiting_for_save else 100) * factor)
	var footer: HBoxContainer = $Footer
	emblem.custom_minimum_size = Vector2.ONE * roundf(64 * factor)
	footer.size = Vector2(width, footer.get_combined_minimum_size().y)
	footer.position = Vector2(edge, viewport_size.y - 28 - footer.size.y)
	var center: CenterContainer = $CenterBox
	var box_height := box.get_combined_minimum_size().y
	center.size = Vector2(width, box_height)
	center.position = Vector2(edge, maxf(brand.position.y + brand.size.y + 32, footer.position.y - box_height - 28))
