class_name StrategyScreen
extends Control

## Base das telas estratégicas da UI-3 (Império, Diplomacia, Vitória). Moldura
## centralizada com largura máxima (nunca estica em ultrawide), cabeçalho com título
## e fechar, e conteúdo montado SÓ quando a tela fica visível (lazy): escondida,
## nenhuma lista é atualizada. O dimmer/ESC/exclusividade pertencem à shell.

signal close_requested

const MAX_FRAME := Vector2(1320, 860)
const MIN_FRAME := Vector2(720, 360)
const TOP_RESERVED := 64.0

var frame: PanelContainer
var title_label: Label
var subtitle_label: Label
var header_actions: HBoxContainer
var content: VBoxContainer
var close_button: AEIconButton
var refresh_count := 0
var top_reserved := TOP_RESERVED
var _dirty := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1
	_build_frame()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_layout()

func _build_frame() -> void:
	if frame != null:
		return
	frame = PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"ModalPanel"
	add_child(frame)
	# PanelContainer normally adopts the recursive minimum of its only child.
	# This boundary keeps long strategic content from enlarging the frame past
	# the viewport; the scroll region below remains the overflow authority.
	var frame_boundary := Control.new()
	frame_boundary.name = "FrameBoundary"
	frame.add_child(frame_boundary)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, UIThemeTokens.SPACE_4)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, UIThemeTokens.SPACE_3)
	frame_boundary.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = &"HeadingLabel"
	titles.add_child(title_label)
	subtitle_label = ContextUI.caption("")
	subtitle_label.name = "Subtitle"
	titles.add_child(subtitle_label)
	header_actions = HBoxContainer.new()
	header_actions.name = "HeaderActions"
	header_actions.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	header.add_child(header_actions)
	close_button = ContextUI.close_button("Fechar (ESC)")
	close_button.pressed.connect(func(): close_requested.emit())
	header.add_child(close_button)
	# Plain Control is an intentional minimum-size boundary: long lists and
	# comparison grids scroll inside the frame instead of forcing the modal past
	# the viewport safe area.
	var content_host := Control.new()
	content_host.name = "ContentHost"
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content_host)
	var content_scroll := ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_host.add_child(content_scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	content_scroll.add_child(content)

func _layout() -> void:
	if frame == null:
		return
	var margin_x := float(UIThemeTokens.STRATEGIC_SAFE_MARGIN_X)
	var margin_y := float(UIThemeTokens.STRATEGIC_SAFE_MARGIN_Y)
	var available := size - Vector2(margin_x * 2.0, top_reserved + margin_y * 2.0)
	available = available.max(Vector2(320.0, 240.0))
	var desired := Vector2(preferred_frame_width(), preferred_frame_height())
	var frame_size := Vector2(
		clampf(desired.x, minf(MIN_FRAME.x, available.x), minf(MAX_FRAME.x, available.x)),
		clampf(desired.y, minf(MIN_FRAME.y, available.y), minf(MAX_FRAME.y, available.y))
	)
	frame.size = frame_size
	frame.position = Vector2((size.x - frame_size.x) * 0.5, top_reserved + margin_y + maxf(0.0, (available.y - frame_size.y) * 0.5))

## Subclasses only choose their content density. Safe margins and clamping stay
## centralized so every strategy surface obeys the same viewport contract.
func preferred_frame_width() -> float:
	return 1180.0

func preferred_frame_height() -> float:
	return 680.0

func request_layout() -> void:
	call_deferred("_layout")

func is_compact() -> bool:
	return size.x < UIThemeTokens.BREAKPOINT_LARGE

func set_titles(title: String, subtitle: String = "") -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()

func mark_dirty() -> void:
	_dirty = true
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	_dirty = false
	refresh_count += 1
	_rebuild()

## Implementado pelas telas concretas.
func _rebuild() -> void:
	pass

func focus_first() -> void:
	close_button.call_deferred("grab_focus")

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_layout()
		refresh()
		focus_first()
