class_name V2ResearchBoard
extends VBoxContainer

## UI das TRÊS árvores de pesquisa do Aetherlands V2 (Doutrinas, Magia,
## Infraestrutura) ligada ao estado REAL de uma civilização (V2ResearchState).
##
## Fase 0 mostrava o scaffold; a Fase 1 mostra o runtime: bloqueado / disponível /
## pesquisando / parcial (progresso guardado, não é o ativo) / concluído. Clicar
## num nó o seleciona e o rodapé oferece Pesquisar / Continuar / Pausar, ou explica
## por que está bloqueado. A UI NUNCA mexe nos dicionários do estado: só chama a
## API (select_research, cancel_active_research, add_knowledge...).
##
## Não toca o runtime de pesquisa V1. Concluir um nó o marca no V2ResearchState; o
## que isso desbloqueia no jogo (Fase 3: Guardião N1-N3) é responsabilidade do
## V2UnlockSystem, que reage ao sinal do estado — esta UI só chama a API.
##
## Performance: sem _process/polling e sem reconstruir a árvore por qualquer coisa.
##  - Só é construída com o painel VISÍVEL (0 nós montados com o HUD fechado).
##  - Progresso/seleção/pausa atualizam só os cards afetados (troca no lugar).
##  - Conclusão, reset e load reconstroem a aba UMA vez por frame (ligações e
##    disponibilidade mudam): vários eventos no mesmo frame — ex.: completar uma
##    linha inteira — coalescem numa reconstrução só (rebuild_count). Trocar de
##    aba reconstrói só se algo mudou.
## Paleta própria (abaixo, herdada do antigo tabuleiro de tecnologia) + UITheme.panel_style.
##
## Fase 30 (UI-3) — responsivo sem trocar a identidade: abaixo de ~1440 px o quadro
## entra em modo compacto (cards/espaços menores, nome legível, alvo de clique
## preservado); zoom 80%/100%; o cabeçalho de tiers e a coluna de linhas ficam FIXOS
## (ScrollContainers irmãos sincronizados por sinal, nunca por offset por frame);
## esmaecimento + "Mais níveis" indicam conteúdo à direita; "Ir para ativo" e "Ir
## para disponível" são determinísticos; as ferramentas de debug moram numa faixa
## "Dev" recolhível que nem existe em build normal.

signal close_requested
signal tree_shown(tree_type: int)

const TreeType := V2ResearchNode.TreeType
const NodeState := V2ResearchDatabase.NodeState

const MENU_THEME := preload("res://scripts/ui/ResearchMenuTheme.gd")
const CARD_DECORATION := preload("res://scripts/ui/ResearchCardDecoration.gd")
const CARD_SIZE := Vector2(180, 84)
const CAPSTONE_CARD_SIZE := Vector2(440, 94)
const CONNECTOR_WIDTH := 14.0
const ROW_LABEL_WIDTH := 184.0
const ROW_SPACING := 8
const CARD_PADDING := 8.0
## Fase 30: largura de viewport abaixo da qual o quadro entra em modo compacto.
const COMPACT_BREAKPOINT := 1440.0
const COMPACT_CARD_SIZE := Vector2(164, 80)
const COMPACT_CONNECTOR_WIDTH := 12.0
const COMPACT_ROW_LABEL_WIDTH := 164.0
const TIER_HEADER_HEIGHT := 44.0
const SECTION_LABEL_HEIGHT := 22.0
const ZOOM_LEVELS := [0.8, 1.0]
const ROMAN_LEVELS := ["I", "II", "III"]

## Paleta do quadro de pesquisa (Fase 25: era emprestada do tabuleiro de Tecnologia V1, removido).
const BG_LEVEL := Color("0a1b22")
const BG_CARD := Color("193138")
const BORDER_STEEL := Color("5b706b")
const BORDER_STEEL_BRIGHT := Color("c5b48a")
const ACCENT_GOLD := Color("e6bc77")
const COLOR_RESEARCHED := Color("8dccaa")
const TEXT_PRIMARY := Color("f4e9d3")
const TEXT_MUTED := Color("b0bfb4")
const TEXT_LOCKED := Color("a2b0aa")
## Conhecimento GUARDADO (sem projeto ativo, ou sobra de uma pesquisa concluída): cor própria no chip do cabeçalho e
## na prévia dos cards — distinta do dourado de "pesquisando" e do verde de "concluído".
const COLOR_BANKED := Color(0.42, 0.68, 0.86, 1.0)

static func heading_font(embolden: float = 0.6, spacing: int = 1) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = MENU_THEME.PIXEL_FONT
	variation.variation_embolden = embolden
	variation.spacing_glyph = spacing
	return variation

const TAB_LABELS := {
	TreeType.MILITARY_DOCTRINE: "Doutrinas",
	TreeType.MAGIC_SCHOOL: "Magia",
	TreeType.INFRASTRUCTURE: "Infraestrutura",
}

## A pergunta que cada árvore responde (design V2, seção 3).
const TREE_QUESTIONS := {
	TreeType.MILITARY_DOCTRINE: "Que tipo de exército mundano minha civilização consegue formar?",
	TreeType.MAGIC_SCHOOL: "Que capacidades extraordinárias posso adicionar ao meu exército?",
	TreeType.INFRASTRUCTURE: "Como minha civilização sustenta seu exército, sua magia e sua pesquisa?",
}

## Cor de identidade de cada linha (só apresentação; usada no rótulo da linha).
const BRANCH_COLORS := {
	"guardian": Color(0.40, 0.52, 0.68), "warrior": Color(0.72, 0.35, 0.32),
	"ranger": Color(0.42, 0.62, 0.55), "cavalry": Color(0.83, 0.68, 0.32),
	"rogue": Color(0.58, 0.48, 0.68), "siege": Color(0.75, 0.55, 0.35),
	"sacred": Color(0.90, 0.82, 0.55), "infernal": Color(0.85, 0.36, 0.30),
	"necromancy": Color(0.62, 0.45, 0.75), "druidism": Color(0.45, 0.70, 0.42),
	"arcanism": Color(0.45, 0.62, 0.90), "elementalism": Color(0.42, 0.75, 0.78),
	"economy": Color(0.83, 0.68, 0.32), "logistics": Color(0.70, 0.60, 0.45),
	"industry": Color(0.80, 0.52, 0.30), "academy": Color(0.45, 0.62, 0.90),
	"arcane": Color(0.62, 0.45, 0.75), "urbanization": Color(0.55, 0.62, 0.70),
	"colonization": Color(0.52, 0.72, 0.48),
}

## Ferramentas de desenvolvimento (+Conhecimento, completar, resetar): SÓ existem
## em build de Debug/desenvolvimento. Em build normal a barra nem é criada. (Var,
## não const, pra teste conseguir simular o build normal — defina antes do add_child.)
var debug_tools_enabled: bool = OS.is_debug_build()

var _state: V2ResearchState
var _tree_type: int = TreeType.MILITARY_DOCTRINE
var _selected_id := ""
var _dirty := true
var _flush_queued := false
var _built_tree_type := -1
## Quantas vezes a aba foi de fato reconstruída (diagnóstico/teste de coalescência).
var rebuild_count := 0
var _cards: Dictionary = {} # node id -> card Control (só da aba montada)

var _tab_buttons: Dictionary = {}
var _status_label: Label
var _banked_chip: PanelContainer
var _banked_label: Label
var _debug_buttons: Dictionary = {} # "add_10" "add_100" "complete_active" "complete_branch" "reset"
var _scroll: ScrollContainer
var _content: VBoxContainer
var _footer_title: Label
var _footer_detail: Label
var _action_button: Button
## Fase 30 — layout responsivo, cabeçalhos fixos e navegação.
var zoom := 1.0
var compact := false
var _header_scroll: ScrollContainer
var _header_row: HBoxContainer
var _label_scroll: ScrollContainer
var _label_column: VBoxContainer
var _corner: Control
var _heading_box: VBoxContainer
var _main_area: Control
var _right_fade: TextureRect
var _left_fade: TextureRect
var _more_hint: PanelContainer
var _debug_row: HBoxContainer
var _debug_toggle: Button
var _zoom_buttons: Dictionary = {}
var _jump_active_button: Button
var _jump_available_button: Button
var _syncing := false
var _label_pad: Control
var _toolbar: BoxContainer
var _navigation: HBoxContainer
var _navigation_menu: MenuButton
var _footer_scroll: ScrollContainer
var _footer_description: Label
var _scale := 1.0

func _ready() -> void:
	_scale = Settings.ui_scale_percent / 100.0
	theme = MENU_THEME.build(_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override("separation", roundi(6 * _scale))
	_build_header()
	if debug_tools_enabled:
		_build_debug_row()
	_heading_box = VBoxContainer.new()
	_heading_box.name = "TreeHeading"
	_heading_box.add_theme_constant_override("separation", 2)
	add_child(_heading_box)
	_build_board_grid()
	_build_footer()
	if _state == null:
		bind_state(V2ResearchState.new()) # estado local (ninguém ligou uma civilização ainda)
	_sync_tab_buttons()
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_on_resized)
	Settings.accessibility_changed.connect(_on_accessibility_changed)
	_update_layout_mode()
	_rebuild_if_needed()
	_refresh_chrome()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update_layout_mode()
		_rebuild_if_needed()

func _on_resized() -> void:
	if _toolbar != null:
		_update_chrome_layout()
	if _update_layout_mode() and is_visible_in_tree():
		_rebuild_if_needed()
	_update_scroll_affordance()

func _update_chrome_layout() -> void:
	var narrow := get_viewport_rect().size.x / _scale < 1350
	add_theme_constant_override("separation", roundi(6 * _scale))
	_toolbar.vertical = false
	_navigation_menu.visible = narrow
	for child in _navigation.get_children():
		if child != _navigation_menu: child.visible = not narrow
	if _heading_box != null:
		# The selected tab already names the tree. Keep the board space for nodes.
		_heading_box.visible = false

func _on_navigation_menu(id: int) -> void:
	match id:
		0: jump_to_active()
		1: jump_to_available()
		2: set_zoom(.8)
		3: set_zoom(1.0)
		4: _toggle_debug_row()

func _on_accessibility_changed() -> void:
	var factor := Settings.ui_scale_percent / 100.0
	if is_equal_approx(factor, _scale):
		return
	# Rebuild only presentation controls; research state and current zoom survive.
	_scale = factor
	theme = MENU_THEME.build(_scale)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tab_buttons.clear()
	_zoom_buttons.clear()
	_debug_buttons.clear()
	_dirty = true
	_build_header()
	if debug_tools_enabled: _build_debug_row()
	_heading_box = VBoxContainer.new()
	_heading_box.name = "TreeHeading"
	add_child(_heading_box)
	_build_board_grid()
	_build_footer()
	add_theme_constant_override("separation", roundi(6 * _scale))
	_sync_tab_buttons()
	_on_resized()
	_rebuild_if_needed()
	_refresh_chrome()

## Grade de 4 regiões: canto | cabeçalho de tiers (rola só na horizontal, junto com o
## conteúdo) / coluna de linhas (rola só na vertical) | conteúdo principal.
func _build_board_grid() -> void:
	var grid := VBoxContainer.new()
	grid.name = "BoardGrid"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 0)
	add_child(grid)
	var top := HBoxContainer.new()
	top.name = "TierHeaderRow"
	top.add_theme_constant_override("separation", 0)
	grid.add_child(top)
	_corner = Control.new()
	_corner.name = "Corner"
	top.add_child(_corner)
	_header_scroll = ScrollContainer.new()
	_header_scroll.name = "TierHeaderScroll"
	_header_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_header_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top.add_child(_header_scroll)
	_header_row = HBoxContainer.new()
	_header_row.name = "TierHeader"
	_header_row.add_theme_constant_override("separation", 0)
	_header_scroll.add_child(_header_row)
	var bottom := HBoxContainer.new()
	bottom.name = "BoardBody"
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 0)
	grid.add_child(bottom)
	_label_scroll = ScrollContainer.new()
	_label_scroll.name = "BranchLabelScroll"
	_label_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_label_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	bottom.add_child(_label_scroll)
	_label_column = VBoxContainer.new()
	_label_column.name = "BranchLabels"
	_label_column.add_theme_constant_override("separation", roundi(ROW_SPACING * _scale))
	_label_scroll.add_child(_label_column)
	_main_area = Control.new()
	_main_area.name = "MainArea"
	_main_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_area.clip_contents = true
	bottom.add_child(_main_area)
	_scroll = ScrollContainer.new()
	_scroll.name = "CardsScroll"
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main_area.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.name = "Cards"
	_content.add_theme_constant_override("separation", roundi(ROW_SPACING * _scale))
	_scroll.add_child(_content)
	_left_fade = _make_fade(true)
	_main_area.add_child(_left_fade)
	_right_fade = _make_fade(false)
	_main_area.add_child(_right_fade)
	_more_hint = PanelContainer.new()
	_more_hint.name = "MoreTiersHint"
	_more_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := UITheme.panel_style(BG_LEVEL, ACCENT_GOLD.darkened(0.2), 2, 0, false)
	hint_style.content_margin_left = 10
	hint_style.content_margin_right = 10
	hint_style.content_margin_top = 4
	hint_style.content_margin_bottom = 4
	_more_hint.add_theme_stylebox_override("panel", hint_style)
	var hint_label := Label.new()
	hint_label.text = "Mais níveis  ›"
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_font_override("font", MENU_THEME.PIXEL_FONT)
	hint_label.add_theme_font_size_override("font_size", roundi(14 * _scale))
	hint_label.add_theme_color_override("font_color", ACCENT_GOLD)
	_more_hint.add_child(hint_label)
	_corner.add_child(_more_hint)
	_more_hint.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_more_hint.offset_left = 8 * _scale
	_more_hint.offset_right = metrics().label_width - 12 * _scale
	_more_hint.offset_top = -16 * _scale
	_more_hint.offset_bottom = 16 * _scale
	# Sincronização bidirecional por sinal (roda, arraste ou código): nunca offsets por frame.
	_scroll.get_h_scroll_bar().value_changed.connect(_on_main_h_scrolled)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_main_v_scrolled)
	_label_scroll.get_v_scroll_bar().value_changed.connect(_on_label_v_scrolled)
	_header_scroll.get_h_scroll_bar().value_changed.connect(_on_header_h_scrolled)
	_scroll.get_h_scroll_bar().changed.connect(_update_scroll_affordance)
	_scroll.resized.connect(_update_scroll_affordance)
	_content.resized.connect(_align_label_column)

func _make_fade(left: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BG_LEVEL, 0.95) if left else Color(BG_LEVEL, 0.0))
	gradient.set_color(1, Color(BG_LEVEL, 0.0) if left else Color(BG_LEVEL, 0.95))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 4
	var rect := TextureRect.new()
	rect.name = "LeftFade" if left else "RightFade"
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_LEFT_WIDE if left else Control.PRESET_RIGHT_WIDE)
	rect.offset_left = 0 if left else -40
	rect.offset_right = 40 if left else -12
	rect.offset_bottom = -12
	rect.visible = false
	return rect

func _on_main_h_scrolled(value: float) -> void:
	if not _syncing:
		_syncing = true
		_header_scroll.scroll_horizontal = int(value)
		_syncing = false
	_update_scroll_affordance()

func _on_header_h_scrolled(value: float) -> void:
	if not _syncing:
		_syncing = true
		_scroll.scroll_horizontal = int(value)
		_syncing = false

func _on_main_v_scrolled(value: float) -> void:
	if not _syncing:
		_syncing = true
		_label_scroll.scroll_vertical = int(value)
		_syncing = false

func _on_label_v_scrolled(value: float) -> void:
	if not _syncing:
		_syncing = true
		_scroll.scroll_vertical = int(value)
		_syncing = false

## Esmaecimento nas bordas + dica "Mais níveis" quando há conteúdo escondido à direita.
func _update_scroll_affordance() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_h_scroll_bar()
	var max_offset := bar.max_value - bar.page
	var has_right := max_offset > 1.0 and bar.value < max_offset - 1.0
	var has_left := bar.value > 1.0
	_right_fade.visible = has_right
	_more_hint.visible = has_right
	_left_fade.visible = has_left

## Depois do layout real, a coluna fixa ganha exatamente a altura restante do conteúdo
## (+ a barra horizontal), então as duas rolagens têm o mesmo curso até o fim.
func _align_label_column() -> void:
	if _label_pad == null or not is_instance_valid(_label_pad) or _label_column == null:
		return
	var labels_height := 0.0
	var count := 0
	for child in _label_column.get_children():
		if child == _label_pad or child.is_queued_for_deletion():
			continue
		labels_height += (child as Control).get_combined_minimum_size().y
		count += 1
	labels_height += float(roundi(ROW_SPACING * _scale)) * float(count)
	var wanted := maxf(0.0, _content.size.y - labels_height) + _scroll.get_h_scroll_bar().get_combined_minimum_size().y + 4.0
	if not is_equal_approx(_label_pad.custom_minimum_size.y, wanted):
		_label_pad.custom_minimum_size.y = wanted

func has_hidden_content_right() -> bool:
	return _right_fade != null and _right_fade.visible

# --- Modo compacto e zoom ----------------------------------------------------------------

## true se o modo mudou. Lê a largura real do viewport (sem framework de breakpoints).
func _update_layout_mode() -> bool:
	if not is_inside_tree():
		return false
	var wanted := get_viewport_rect().size.x / _scale < COMPACT_BREAKPOINT
	if wanted == compact:
		return false
	set_compact(wanted)
	return true

func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	_dirty = true
	_rebuild_if_needed()

func set_zoom(value: float) -> void:
	value = clampf(value, ZOOM_LEVELS[0], ZOOM_LEVELS[ZOOM_LEVELS.size() - 1])
	if is_equal_approx(value, zoom):
		return
	zoom = value
	for level in _zoom_buttons:
		(_zoom_buttons[level] as Button).set_pressed_no_signal(is_equal_approx(float(level), zoom))
	_dirty = true
	_rebuild_if_needed()
	if _navigation_menu != null:
		var popup := _navigation_menu.get_popup()
		popup.set_item_checked(popup.get_item_index(2), is_equal_approx(zoom, .8))
		popup.set_item_checked(popup.get_item_index(3), is_equal_approx(zoom, 1.0))

## Medidas efetivas (modo + zoom). O nome nunca desce de 11 px; metadado nunca de 10.
func metrics() -> Dictionary:
	var card := COMPACT_CARD_SIZE if compact else CARD_SIZE
	var connector := COMPACT_CONNECTOR_WIDTH if compact else CONNECTOR_WIDTH
	var label_width := COMPACT_ROW_LABEL_WIDTH if compact else ROW_LABEL_WIDTH
	var name_font := 12 if compact else 13
	var meta_font := 11
	if zoom < 1.0:
		card = Vector2(round(card.x * 0.86), round(card.y * 0.94))
		connector = round(connector * 0.7)
		label_width = round(label_width * 0.86)
		name_font = 11
	return {
		"card": card * _scale,
		"capstone": Vector2(maxf(card.x * 2.4, 360.0), CAPSTONE_CARD_SIZE.y) * _scale,
		"connector": connector * _scale,
		"label_width": label_width * _scale,
		"name_font": name_font,
		"meta_font": meta_font,
		"role_font": 11,
	}

# --- Navegação: ir para ativo / disponível ------------------------------------------------

## Projeto ativo: troca de aba se preciso, seleciona e rola até o card. false sem ativo.
func jump_to_active() -> bool:
	if _state == null or _state.active_id == "":
		return false
	_jump_to(_state.active_id)
	return true

## Primeiro nó DISPONÍVEL, determinístico: aba atual (linhas em ordem, tiers em ordem,
## depois o universal); depois as outras abas na ordem das abas. Sem disponível, o
## primeiro PARCIAL. "" se nada pode ser pesquisado.
func first_available_id() -> String:
	if _state == null:
		return ""
	var order: Array[int] = [_tree_type]
	for tree_type in V2ResearchDatabase.tree_types():
		if tree_type != _tree_type:
			order.append(tree_type)
	for wanted in [NodeState.AVAILABLE, NodeState.PARTIAL]:
		for tree_type in order:
			for line in V2ResearchDatabase.branches_for_tree(tree_type):
				for node in V2ResearchDatabase.nodes_for_branch(tree_type, line.id):
					if _state.node_state(node.id) == wanted:
						return node.id
			var capstone := V2ResearchDatabase.capstone_for_tree(tree_type)
			if capstone != null and _state.node_state(capstone.id) == wanted:
				return capstone.id
	return ""

func jump_to_available() -> bool:
	var id := first_available_id()
	if id == "":
		return false
	_jump_to(id)
	return true

func _jump_to(node_id: String) -> void:
	var node := V2ResearchDatabase.get_node(node_id)
	if node == null:
		return
	if node.tree_type != _tree_type:
		show_tree(node.tree_type)
	select_node(node_id)
	call_deferred("_scroll_to_card", node_id)

func _scroll_to_card(node_id: String) -> void:
	var card: Control = _cards.get(node_id, null)
	if card == null or _scroll == null:
		return
	_scroll.ensure_control_visible(card)

## O tooltip padrão do tema é translúcido e fica ilegível sobre os cards; o
## tooltip herda o tema do controle dono, então este tema LOCAL (só do
## tabuleiro V2, o resto do jogo não muda) deixa o fundo opaco.
static func _tooltip_theme() -> Theme:
	var local_theme := Theme.new()
	var panel := UITheme.panel_style(BG_CARD.darkened(0.25), BORDER_STEEL_BRIGHT, 1, 6, false)
	panel.set_content_margin_all(10)
	local_theme.set_stylebox("panel", "TooltipPanel", panel)
	local_theme.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)
	local_theme.set_font_size("font_size", "TooltipLabel", 14)
	return local_theme

# --- API pública ---------------------------------------------------------------------

## Liga o tabuleiro ao estado de UMA civilização (normalmente a humana:
## GameManager.human_player.v2_research). Reconectar o mesmo estado é no-op.
func bind_state(state: V2ResearchState) -> void:
	if state == _state:
		return
	_disconnect_state()
	_state = state
	_connect_state()
	_dirty = true
	_rebuild_if_needed()
	_refresh_chrome()

func get_state() -> V2ResearchState:
	return _state

func current_tree() -> int:
	return _tree_type

func show_tree(tree_type: int) -> void:
	_tree_type = tree_type
	var selected := V2ResearchDatabase.get_node(_selected_id)
	if selected != null and selected.tree_type != tree_type:
		_selected_id = ""
	_sync_tab_buttons()
	_rebuild_if_needed()
	_refresh_chrome()
	tree_shown.emit(tree_type)

## Chamado pelo HUD ao abrir o painel.
func refresh() -> void:
	_rebuild_if_needed()
	_refresh_chrome()

func selected_id() -> String:
	return _selected_id

## Seleciona um nó (o que o clique faz): mostra detalhes/ação no rodapé.
func select_node(node_id: String) -> void:
	var previous := _selected_id
	_selected_id = node_id
	_refresh_cards([previous, node_id])
	_refresh_chrome()

## O botão de ação do rodapé (Pesquisar / Continuar pesquisa / Pausar pesquisa).
func press_action() -> void:
	if _state == null or _selected_id == "":
		return
	match _state.node_state(_selected_id):
		NodeState.AVAILABLE, NodeState.PARTIAL:
			# V3 / Etapa 2: sem cidade, nenhuma pesquisa começa (V2ResearchAccess — mesma regra da IA).
			if V2ResearchAccess.state_blocked_reason(_state) != "":
				return
			_state.select_research(_selected_id)
		NodeState.RESEARCHING:
			_state.cancel_active_research()

func action_text() -> String:
	return _action_button.text if _action_button != null else ""

func action_disabled() -> bool:
	return _action_button == null or _action_button.disabled

func footer_text() -> String:
	return "%s\n%s" % [_footer_title.text, _footer_detail.text] if _footer_title != null else ""

func status_text() -> String:
	return _status_label.text if _status_label != null else ""

## Texto do chip "Guardado" do cabeçalho ("" enquanto não há Conhecimento guardado).
func banked_text() -> String:
	return _banked_label.text if _banked_chip != null and _banked_chip.visible else ""

func banked_tooltip() -> String:
	return _banked_chip.tooltip_text if _banked_chip != null else ""

func debug_button(button_id: String) -> Button:
	return _debug_buttons.get(button_id, null)

func card_for(node_id: String) -> Control:
	return _cards.get(node_id, null)

func card_count() -> int:
	return _cards.size()

func node_state_of(node_id: String) -> int:
	return _state.node_state(node_id) if _state != null else NodeState.LOCKED

# --- Ligação ao estado ------------------------------------------------------------------

func _connect_state() -> void:
	if _state == null:
		return
	_state.research_selected.connect(_on_research_selected)
	_state.research_cancelled.connect(_on_research_cancelled)
	_state.research_progress_changed.connect(_on_research_progress_changed)
	_state.research_completed.connect(_on_structure_changed)
	_state.state_reset.connect(_on_structure_changed)
	_state.research_overflow_changed.connect(_on_overflow_changed)

func _disconnect_state() -> void:
	if _state == null:
		return
	_state.research_selected.disconnect(_on_research_selected)
	_state.research_cancelled.disconnect(_on_research_cancelled)
	_state.research_progress_changed.disconnect(_on_research_progress_changed)
	_state.research_completed.disconnect(_on_structure_changed)
	_state.state_reset.disconnect(_on_structure_changed)
	_state.research_overflow_changed.disconnect(_on_overflow_changed)

func _on_research_selected(id: String, previous_id: String) -> void:
	_refresh_cards([id, previous_id])
	_refresh_chrome()

func _on_research_cancelled(id: String) -> void:
	_refresh_cards([id])
	_refresh_chrome()

func _on_research_progress_changed(id: String, _progress: float, _cost: float) -> void:
	_refresh_cards([id])
	_refresh_chrome()

## O guardado mudou: a prévia "com o guardado" de todo nó que ainda pode ser escolhido muda junto.
func _on_overflow_changed(_amount: float) -> void:
	var selectable: Array = []
	for id in _cards:
		if _state.node_state(id) in [NodeState.AVAILABLE, NodeState.PARTIAL]:
			selectable.append(id)
	_refresh_cards(selectable)
	_refresh_chrome()

## Conclusão/reset/load: conexões e disponibilidade mudam — a aba é reconstruída,
## mas UMA vez por frame (adiado): completar 9 nós de uma linha não custa 9 rebuilds.
## Escondido, só marca sujo (monta ao aparecer).
func _on_structure_changed(_id: String = "") -> void:
	_dirty = true
	_refresh_chrome()
	if is_visible_in_tree() and not _flush_queued:
		_flush_queued = true
		_flush_rebuild.call_deferred()

func _flush_rebuild() -> void:
	_flush_queued = false
	_rebuild_if_needed()
	_refresh_chrome()

# --- Construção ------------------------------------------------------------------------------

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.name = "ResearchHeader"
	header.add_theme_constant_override("separation", roundi(10 * _scale))
	add_child(header)
	var crest := TextureRect.new()
	crest.texture = load("res://assets/ui/title_menu/crest.svg")
	crest.custom_minimum_size = Vector2(32, 32) * _scale
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(crest)
	var title := Label.new()
	title.text = "PESQUISAS"
	title.add_theme_font_override("font", MENU_THEME.PIXEL_FONT)
	title.add_theme_font_size_override("font_size", roundi(28 * _scale))
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_banked_chip = PanelContainer.new()
	_banked_chip.name = "BankedKnowledge"
	_banked_chip.visible = false
	_banked_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banked_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var banked_style := UITheme.panel_style(BG_CARD, COLOR_BANKED, 2, 0, false)
	banked_style.set_content_margin_all(5 * _scale)
	_banked_chip.add_theme_stylebox_override("panel", banked_style)
	_banked_label = _card_label("", 12, COLOR_BANKED.lightened(.25), false)
	_banked_chip.add_child(_banked_label)
	header.add_child(_banked_chip)
	var close_button := _header_button("X", "CloseResearch", close_requested.emit)
	close_button.custom_minimum_size = Vector2(36, 32) * _scale
	close_button.tooltip_text = "Fechar pesquisas (Esc)"
	header.add_child(close_button)
	_toolbar = BoxContainer.new()
	_toolbar.name = "ResearchToolbar"
	_toolbar.vertical = false
	_toolbar.add_theme_constant_override("separation", roundi(12 * _scale))
	add_child(_toolbar)
	var tabs := HBoxContainer.new()
	tabs.name = "ResearchTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", roundi(8 * _scale))
	_toolbar.add_child(tabs)
	var group := ButtonGroup.new()
	for tree_type in V2ResearchDatabase.tree_types():
		var tab := _header_button(TAB_LABELS[tree_type], "ResearchTab%d" % tree_type, show_tree.bind(tree_type))
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(132, 34) * _scale
		tab.add_theme_font_size_override("font_size", roundi(18 * _scale))
		tab.icon = MENU_THEME.icon(["warrior", "arcanism", "urbanization"][tree_type])
		tab.add_theme_constant_override("icon_max_width", roundi(16 * _scale))
		tab.add_theme_constant_override("h_separation", roundi(8 * _scale))
		tabs.add_child(tab)
		_tab_buttons[tree_type] = tab
	var tools := HBoxContainer.new()
	_navigation = tools
	tools.name = "ResearchNavigation"
	tools.add_theme_constant_override("separation", roundi(6 * _scale))
	_toolbar.add_child(tools)
	_jump_active_button = _header_button("Ir para ativo", "JumpActive", jump_to_active)
	tools.add_child(_jump_active_button)
	_jump_available_button = _header_button("Ir para disponível", "JumpAvailable", jump_to_available)
	tools.add_child(_jump_available_button)
	var zoom_group := ButtonGroup.new()
	for level in ZOOM_LEVELS:
		var zoom_button := _header_button("%d%%" % int(round(level * 100)), "Zoom%d" % int(round(level * 100)), set_zoom.bind(level))
		zoom_button.toggle_mode = true
		zoom_button.button_group = zoom_group
		zoom_button.set_pressed_no_signal(is_equal_approx(level, zoom))
		zoom_button.tooltip_text = "Escala do quadro; os textos continuam legíveis."
		tools.add_child(zoom_button)
		_zoom_buttons[level] = zoom_button
	if debug_tools_enabled:
		_debug_toggle = _header_button("Dev", "DevToggle", _toggle_debug_row)
		_debug_toggle.toggle_mode = true
		_debug_toggle.tooltip_text = "Ferramentas de desenvolvimento (só em build de debug)"
		tools.add_child(_debug_toggle)
	_navigation_menu = MenuButton.new()
	_navigation_menu.name = "ResearchNavigationMenu"
	_navigation_menu.text = "Navegar / zoom"
	_navigation_menu.flat = false
	_navigation_menu.focus_mode = Control.FOCUS_ALL
	_navigation_menu.custom_minimum_size.y = 34 * _scale
	_navigation_menu.add_theme_font_size_override("font_size", roundi(14 * _scale))
	_style_chip(_navigation_menu, ACCENT_GOLD)
	tools.add_child(_navigation_menu)
	var popup := _navigation_menu.get_popup()
	popup.add_item("Ir para ativo", 0)
	popup.add_item("Ir para disponível", 1)
	popup.add_separator()
	popup.add_radio_check_item("Zoom: 80%", 2)
	popup.add_radio_check_item("Zoom: 100%", 3)
	if debug_tools_enabled:
		popup.add_separator()
		popup.add_item("Ferramentas de desenvolvimento", 4)
	popup.id_pressed.connect(_on_navigation_menu)
	_update_chrome_layout()
	_status_label = _card_label("", 12, TEXT_PRIMARY, false)
	_status_label.name = "ActiveResearchStatus"
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status_label)

func _header_button(text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 32) * _scale
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", roundi(14 * _scale))
	_style_chip(button, ACCENT_GOLD)
	button.pressed.connect(func(): callback.call())
	return button

func _toggle_debug_row() -> void:
	if _debug_row != null:
		_debug_row.visible = not _debug_row.visible
		_debug_toggle.set_pressed_no_signal(_debug_row.visible)

func debug_row_visible() -> bool:
	return _debug_row != null and _debug_row.visible

## Ferramentas de desenvolvimento — só com debug_tools_enabled (ver acima).
func _build_debug_row() -> void:
	var row := HBoxContainer.new()
	row.name = "DevTools"
	row.add_theme_constant_override("separation", 8)
	# Fase 30: recolhida por padrão; só a faixa "Dev" do cabeçalho a abre.
	row.visible = false
	add_child(row)
	_debug_row = row
	var caption := Label.new()
	caption.text = "Debug (não existe em build normal):"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", TEXT_MUTED)
	row.add_child(caption)
	var entries := [
		["add_10", "+10 Conhecimento", func(): _state.add_knowledge(10.0)],
		["add_100", "+100 Conhecimento", func(): _state.add_knowledge(100.0)],
		["complete_active", "Completar pesquisa ativa", func(): _state.debug_complete_active()],
		["complete_branch", "Completar linha do nó selecionado", _debug_complete_selected_branch],
		["reset", "Resetar pesquisa", func(): _state.reset()],
	]
	for entry in entries:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 28)
		button.add_theme_font_size_override("font_size", 12)
		_style_chip(button, BORDER_STEEL_BRIGHT)
		button.pressed.connect(entry[2])
		row.add_child(button)
		_debug_buttons[entry[0]] = button

func _debug_complete_selected_branch() -> void:
	var node := V2ResearchDatabase.get_node(_selected_id)
	if node != null:
		_state.debug_complete_branch(node.tree_type, node.branch)

func _build_footer() -> void:
	var footer := PanelContainer.new()
	footer.name = "ResearchDetails"
	var frame := MENU_THEME.panel(_scale)
	frame.set_content_margin_all(16 * _scale)
	footer.add_theme_stylebox_override("panel", frame)
	add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(12 * _scale))
	footer.add_child(row)
	_footer_scroll = ScrollContainer.new()
	_footer_scroll.name = "DetailsScroll"
	_footer_scroll.custom_minimum_size.y = minf(56 * _scale, 84)
	_footer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_footer_scroll.follow_focus = true
	row.add_child(_footer_scroll)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", roundi(2 * _scale))
	_footer_scroll.add_child(texts)
	_footer_title = _card_label("", 18, ACCENT_GOLD, false)
	_footer_title.clip_text = true
	_footer_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_footer_title.add_theme_font_override("font", MENU_THEME.PIXEL_FONT)
	texts.add_child(_footer_title)
	_footer_description = _card_label("", 14, TEXT_PRIMARY, true)
	texts.add_child(_footer_description)
	_footer_detail = _card_label("", 11, TEXT_MUTED, true)
	texts.add_child(_footer_detail)
	_action_button = Button.new()
	_action_button.name = "ResearchAction"
	_action_button.custom_minimum_size = Vector2(190, 38) * _scale
	_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action_button.add_theme_font_size_override("font_size", roundi(18 * _scale))
	_style_chip(_action_button, ACCENT_GOLD)
	_action_button.add_theme_stylebox_override("normal", MENU_THEME.BASE.BASE._button("button_bronze", _scale))
	_action_button.add_theme_stylebox_override("hover", MENU_THEME.BASE.BASE._button("button_bronze_hover", _scale))
	_action_button.pressed.connect(press_action)
	row.add_child(_action_button)

func _sync_tab_buttons() -> void:
	for tree_type in _tab_buttons:
		_tab_buttons[tree_type].set_pressed_no_signal(tree_type == _tree_type)

func _rebuild_if_needed() -> void:
	if _content == null or _state == null or not is_visible_in_tree():
		return
	if not _dirty and _built_tree_type == _tree_type:
		return
	_dirty = false
	_built_tree_type = _tree_type
	rebuild_count += 1
	_cards.clear()
	var m := metrics()
	for container in [_content, _label_column, _header_row, _heading_box]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_heading_box.add_child(_tree_heading())
	_corner.custom_minimum_size = Vector2(m.label_width, 0)
	_more_hint.offset_right = m.label_width - 12 * _scale
	_label_scroll.custom_minimum_size.x = m.label_width
	_header_row.add_child(_column_header_row())
	for line in V2ResearchDatabase.branches_for_tree(_tree_type):
		_label_column.add_child(_branch_label(line))
		_content.add_child(_branch_row(line))
	var capstone := V2ResearchDatabase.capstone_for_tree(_tree_type)
	if capstone != null:
		var section := _section_label("NÓ UNIVERSAL")
		section.custom_minimum_size.y = SECTION_LABEL_HEIGHT
		_content.add_child(section)
		_content.add_child(_build_card(capstone))
		var label_spacer := Control.new()
		label_spacer.custom_minimum_size.y = SECTION_LABEL_HEIGHT + ROW_SPACING + m.capstone.y
		_label_column.add_child(label_spacer)
	# A coluna fixa precisa do mesmo curso de rolagem do conteúdo: reserva a altura da
	# barra horizontal no fim (e a largura da vertical no fim do cabeçalho).
	_label_pad = Control.new()
	_label_pad.name = "BottomPad"
	_label_pad.custom_minimum_size.y = _scroll.get_h_scroll_bar().get_combined_minimum_size().y + 4
	_label_column.add_child(_label_pad)
	var right_pad := Control.new()
	right_pad.custom_minimum_size.x = _scroll.get_v_scroll_bar().get_combined_minimum_size().x + 4
	_header_row.add_child(right_pad)
	_header_scroll.scroll_horizontal = _scroll.scroll_horizontal
	_label_scroll.scroll_vertical = _scroll.scroll_vertical
	call_deferred("_update_scroll_affordance")

## Troca no lugar os cards de `ids` (progresso/seleção/pausa mudam só eles).
## Escondido ou com reconstrução pendente: só marca sujo — monta ao aparecer.
func _refresh_cards(ids: Array) -> void:
	if _content == null:
		return
	if _dirty or not is_visible_in_tree():
		_dirty = true
		return
	for id in ids:
		_replace_card(id)

func _replace_card(id: String) -> void:
	var old: Control = _cards.get(id, null)
	var node := V2ResearchDatabase.get_node(id)
	if old == null or node == null:
		return
	var parent := old.get_parent()
	var index := old.get_index()
	var had_focus := old.has_focus()
	var previous_rect := old.get_rect()
	parent.remove_child(old)
	old.queue_free()
	var fresh := _build_card(node)
	parent.add_child(fresh)
	parent.move_child(fresh, index)
	# Preserve geometry until the container sorts its replacement, so a focus
	# event cannot scroll to an unlaid-out card at the origin.
	fresh.position = previous_rect.position
	fresh.size = previous_rect.size
	if had_focus: _restore_card_focus.call_deferred(id)

func _tree_heading() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = V2ResearchDatabase.tree_label(_tree_type).to_upper()
	title.add_theme_font_override("font", heading_font())
	title.add_theme_font_size_override("font_size", roundi(24 * _scale))
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	box.add_child(title)
	var question := Label.new()
	question.text = TREE_QUESTIONS[_tree_type]
	question.add_theme_font_size_override("font_size", roundi(14 * _scale))
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_color_override("font_color", TEXT_MUTED)
	box.add_child(question)
	return box

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	return label

## Cabeçalho de colunas: "N1 / Estrutura de treinamento", "N2 / Unidade-base"... (nível exibido, ver V2ResearchDatabase.display_tier)
## Os papéis dos tiers são idênticos em todas as linhas da árvore, então ficam
## aqui uma vez só em vez de repetidos em cada card.
func _column_header_row() -> Control:
	var m := metrics()
	var row := HBoxContainer.new()
	row.name = "TierCells"
	row.add_theme_constant_override("separation", 0)
	var first_line: Dictionary = V2ResearchDatabase.branches_for_tree(_tree_type)[0]
	var nodes := V2ResearchDatabase.nodes_for_branch(_tree_type, first_line.id)
	for i in nodes.size():
		if i > 0:
			row.add_child(_spacer(m.connector))
		var cell := VBoxContainer.new()
		cell.name = "Tier%d" % (i + 1)
		cell.custom_minimum_size = Vector2(m.card.x, TIER_HEADER_HEIGHT * _scale if _tree_type != TreeType.INFRASTRUCTURE else 28.0 * _scale)
		cell.add_theme_constant_override("separation", 0)
		var level := Label.new()
		level.text = V2ResearchDatabase.tier_label(_tree_type, nodes[i].tier) if _tree_type != TreeType.INFRASTRUCTURE else ROMAN_LEVELS[i]
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level.add_theme_font_override("font", MENU_THEME.PIXEL_FONT)
		level.add_theme_font_size_override("font_size", roundi(16 * _scale))
		level.add_theme_color_override("font_color", ACCENT_GOLD)
		cell.add_child(level)
		if _tree_type != TreeType.INFRASTRUCTURE:
			var role := Label.new()
			role.text = V2ResearchDatabase.role_label(nodes[i].tier_role)
			role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			role.max_lines_visible = 2
			role.custom_minimum_size = Vector2(m.card.x, 0)
			role.add_theme_font_size_override("font_size", roundi(m.role_font * _scale))
			role.add_theme_color_override("font_color", TEXT_MUTED)
			cell.add_child(role)
		row.add_child(cell)
	return row

func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
	return spacer

func _branch_row(line: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_" + String(line.id)
	row.add_theme_constant_override("separation", 0)
	var nodes := V2ResearchDatabase.nodes_for_branch(_tree_type, line.id)
	for i in nodes.size():
		if i > 0:
			row.add_child(_connector(nodes[i - 1], nodes[i]))
		row.add_child(_build_card(nodes[i]))
	return row

## Rótulo da linha na coluna FIXA: mesma altura do card para alinhar com a linha.
func _branch_label(line: Dictionary) -> Control:
	var m := metrics()
	var box := VBoxContainer.new()
	box.name = "Label_" + String(line.id)
	box.custom_minimum_size = Vector2(m.label_width, m.card.y)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.clip_contents = true
	box.add_theme_constant_override("separation", 0)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", roundi(4 * _scale))
	box.add_child(identity)
	var symbol := TextureRect.new()
	symbol.texture = MENU_THEME.icon(String(line.id))
	symbol.custom_minimum_size = Vector2(16, 16) * _scale
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	symbol.modulate = BRANCH_COLORS.get(line.id, ACCENT_GOLD).lightened(.25)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(symbol)
	var name_label := Label.new()
	name_label.text = line.name
	name_label.add_theme_font_override("font", heading_font(0.5, 0))
	name_label.add_theme_font_size_override("font_size", roundi(17 * _scale))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", BRANCH_COLORS.get(line.id, TEXT_PRIMARY))
	identity.add_child(name_label)
	var summary := Label.new()
	summary.text = line.summary
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 2 if compact or zoom < 1.0 else 3
	summary.custom_minimum_size = Vector2(m.label_width - 12, 0)
	summary.add_theme_font_size_override("font_size", roundi(11 * _scale))
	summary.add_theme_color_override("font_color", TEXT_MUTED)
	box.add_child(summary)
	return box

## Linha entre dois tiers consecutivos: verde quando o anterior foi concluído,
## clara quando o próximo já pode ser pesquisado, apagada quando bloqueado.
func _connector(from_node: V2ResearchNode, to_node: V2ResearchNode) -> Control:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(metrics().connector, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _state.is_completed(from_node.id):
		line.color = COLOR_RESEARCHED
	elif _state.is_available(to_node.id):
		line.color = BORDER_STEEL_BRIGHT
	else:
		line.color = BORDER_STEEL.darkened(0.4)
	return line

# --- Cards -------------------------------------------------------------------------------------

func _build_card(node: V2ResearchNode) -> Control:
	return _capstone_card(node) if node.is_universal else _node_card(node)

## Casca comum: estilo por estado, tooltip, clique (seleciona) e registro em _cards.
func _card_shell(node: V2ResearchNode, state: int, min_size: Vector2, separation: int) -> Array:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = "%s\n\n%s" % [V2ResearchDatabase.node_tooltip(node, _state.is_completed(node.id)), _state.status_text(node.id, false)]
	var banked := _banked_sentence(node.id)
	if banked != "":
		card.tooltip_text += "\n" + banked
	var supremacy := _supremacy_lines(node)
	if not supremacy.is_empty():
		card.tooltip_text += "\n\n" + "\n".join(supremacy)
	card.set_meta("node_id", node.id)
	card.add_theme_stylebox_override("panel", _card_style(state, node.id == _selected_id))
	card.gui_input.connect(_on_card_gui_input.bind(node.id))
	card.focus_entered.connect(_scroll_to_card.bind(node.id))
	var grain := MENU_THEME.grain()
	card.add_child(grain)
	var decoration := CARD_DECORATION.new()
	decoration.accent = _state_accent(state)
	decoration.factor = _scale
	decoration.padding = CARD_PADDING
	decoration.emphasized = state == NodeState.RESEARCHING or node.id == _selected_id
	card.add_child(decoration)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	_cards[node.id] = card
	return [card, box]

func _on_card_gui_input(event: InputEvent, node_id: String) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		var card := card_for(node_id)
		if is_instance_valid(card): card.accept_event()
		select_node(node_id)
		_restore_card_focus.call_deferred(node_id)

func _restore_card_focus(node_id: String) -> void:
	var card := card_for(node_id)
	if is_instance_valid(card) and is_visible_in_tree(): card.grab_focus()

func _node_card(node: V2ResearchNode) -> Control:
	var m := metrics()
	var state := _state.node_state(node.id)
	var parts := _card_shell(node, state, m.card, 1)
	var box: VBoxContainer = parts[1]
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", roundi(4 * _scale))
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := TextureRect.new()
	glyph.texture = MENU_THEME.icon(node.branch)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(14, 14) * _scale
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	glyph.modulate = _state_accent(state)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(glyph)
	var title := _card_label(node.display_name, m.name_font, _state_text_color(state), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(title)
	var marker := _card_label({NodeState.LOCKED:"×", NodeState.AVAILABLE:"◇", NodeState.PARTIAL:"◐", NodeState.RESEARCHING:"▶", NodeState.COMPLETED:"✓"}.get(state, ""), 11, _state_accent(state), false)
	marker.tooltip_text = _card_state_label(state)
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity.add_child(marker)
	box.add_child(identity)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var in_progress := state == NodeState.RESEARCHING or state == NodeState.PARTIAL
	var preview := _banked_preview(node.id)
	var metadata := HBoxContainer.new()
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metadata.add_theme_constant_override("separation", roundi(4 * _scale))
	var amount: Label
	if bool(preview.applies):
		# Prévia: até onde o Conhecimento guardado leva esta pesquisa no instante em que for escolhida.
		box.add_child(_progress_bar(float(preview.ratio_after), COLOR_BANKED))
		amount = _card_label(_banked_card_text(preview), m.meta_font, COLOR_BANKED.lightened(0.25), false)
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.clip_text = true
		amount.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	elif in_progress:
		box.add_child(_progress_bar(_state.get_progress_ratio(node.id), _state_accent(state)))
		amount = _card_label("%s / %s" % [V2ResearchState.format_amount(_state.get_progress(node.id)), V2ResearchState.format_amount(node.cost)], m.meta_font, TEXT_PRIMARY, false)
	else:
		amount = _card_label("Custo %s" % V2ResearchState.format_amount(node.cost), m.meta_font, TEXT_MUTED, false)
	metadata.add_child(amount)
	if not bool(preview.applies):
		var status := _card_label(_card_state_label(state), m.meta_font, _state_accent(state), false)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.clip_text = true
		status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		metadata.add_child(status)
	box.add_child(metadata)
	return parts[0]

## V3 / Etapa 2: antes da primeira cidade, nó pesquisável mostra "Requer uma cidade" (a árvore continua visível).
func _card_state_label(state: int) -> String:
	if state in [NodeState.AVAILABLE, NodeState.PARTIAL] and V2ResearchAccess.state_blocked_reason(_state) != "":
		return V2ResearchAccess.STATE_LABEL_REQUIRES_CITY
	return V2ResearchDatabase.state_label(state)

func _capstone_card(node: V2ResearchNode) -> Control:
	var state := _state.node_state(node.id)
	var progress := V2ResearchDatabase.capstone_progress(node.id, _state.completed_ids)
	var parts := _card_shell(node, state, metrics().capstone, 2)
	var card: Control = parts[0]
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = parts[1]
	box.add_child(_card_label(node.display_name, 17, _state_text_color(state), true))
	box.add_child(_card_label(V2ResearchDatabase.role_label(node.tier_role), 11, TEXT_MUTED, false))
	box.add_child(_card_label("%s completas: %d / %d (%s)" % [V2ResearchDatabase.capstone_unit_word(node), progress.x, progress.y, V2ResearchDatabase.tier_label(node.tree_type, node.requirement.at_tier)], 12, TEXT_PRIMARY if state != NodeState.LOCKED else TEXT_LOCKED, false))
	var in_progress := state == NodeState.RESEARCHING or state == NodeState.PARTIAL
	var preview := _banked_preview(node.id)
	if bool(preview.applies):
		box.add_child(_progress_bar(float(preview.ratio_after), COLOR_BANKED))
	elif in_progress:
		box.add_child(_progress_bar(_state.get_progress_ratio(node.id), _state_accent(state)))
	var cost_text := "Custo %s · %s" % [V2ResearchState.format_amount(node.cost), V2ResearchDatabase.state_label(state)]
	if in_progress:
		cost_text = "%s / %s · %s" % [V2ResearchState.format_amount(_state.get_progress(node.id)), V2ResearchState.format_amount(node.cost), V2ResearchDatabase.state_label(state)]
	if bool(preview.applies):
		cost_text = "Custo %s · %s" % [V2ResearchState.format_amount(node.cost), _banked_card_text(preview)]
	box.add_child(_card_label(cost_text, 11, COLOR_BANKED.lightened(0.25) if bool(preview.applies) else _state_accent(state), false))
	return card

# --- Conhecimento guardado: o que ele faz pela pesquisa que for escolhida -------------------------------------------

## V2ResearchState.banked_preview, com a regra da tela por cima: antes da primeira cidade nenhuma pesquisa começa
## (V2ResearchAccess), então não há prévia a mostrar.
func _banked_preview(node_id: String) -> Dictionary:
	var preview := _state.banked_preview(node_id)
	if bool(preview.applies) and V2ResearchAccess.state_blocked_reason(_state) != "":
		preview.applies = false
	return preview

## Linha curta do card: "Com guardado: 40 / 50" ou "Com guardado: conclui".
func _banked_card_text(preview: Dictionary) -> String:
	if bool(preview.completes):
		return "Com guardado: conclui"
	return "Com guardado: %s / %s" % [V2ResearchState.format_amount(float(preview.progress_after)), V2ResearchState.format_amount(float(preview.cost))]

## Frase completa (rodapé e tooltip do card) do efeito do guardado sobre `node_id`; "" se não se aplica.
func _banked_sentence(node_id: String) -> String:
	var preview := _banked_preview(node_id)
	if not bool(preview.applies):
		return ""
	var banked := V2ResearchState.format_amount(float(preview.banked))
	if bool(preview.completes):
		var leftover := float(preview.leftover)
		return "Conhecimento guardado: %s — iniciar conclui esta pesquisa na hora%s." % [banked, " e sobram %s guardados" % V2ResearchState.format_amount(leftover) if leftover > 0.0 else ""]
	var remaining := float(preview.cost) - float(preview.progress_after)
	var income := _knowledge_income()
	var eta := " (≈%d turnos)" % maxi(int(ceil(remaining / income)), 1) if income > 0.0 else ""
	return "Conhecimento guardado: %s — ao iniciar, esta pesquisa vai direto a %s / %s (%d%%); faltam %s%s." % [banked,
		V2ResearchState.format_amount(float(preview.progress_after)), V2ResearchState.format_amount(float(preview.cost)),
		int(round(float(preview.ratio_after) * 100.0)), V2ResearchState.format_amount(remaining), eta]

## Conhecimento por turno da civilização dona deste estado (0 se o estado não pertence a nenhuma — ex.: teste).
func _knowledge_income() -> float:
	for player in GameManager.players:
		if player != null and player.v2_research == _state:
			return V2EconomyRuntime.player_knowledge_income(player)
	return 0.0

func _refresh_banked_chip() -> void:
	if _banked_chip == null:
		return
	var banked := _state.research_overflow
	_banked_chip.visible = banked > 0.0
	if banked <= 0.0:
		return
	var income := _knowledge_income()
	_banked_label.text = "Guardado: %s" % V2ResearchState.format_amount(banked)
	if income > 0.0:
		_banked_label.text += "  ·  +%s por turno" % V2ResearchState.format_amount(snappedf(income, 0.1))
	_banked_chip.tooltip_text = "Conhecimento guardado: %s\nÉ o Conhecimento que entrou enquanto nenhuma pesquisa estava ativa, ou que sobrou de uma pesquisa concluída.\nA próxima pesquisa que você iniciar recebe tudo de uma vez, na hora — pode avançar bastante ou concluir no mesmo instante. O que passar do custo continua guardado.%s" % [
		V2ResearchState.format_amount(banked), "\nRenda atual: +%s Conhecimento por turno." % V2ResearchState.format_amount(snappedf(income, 0.1)) if income > 0.0 else ""]

func _card_label(text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(font_size * _scale))
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _progress_bar(ratio: float, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = ratio
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4 * _scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = BG_LEVEL
	back.set_corner_radius_all(0)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", front)
	return bar

func _card_style(state: int, selected: bool) -> StyleBoxFlat:
	var background := BG_CARD
	var border := BORDER_STEEL
	var border_width := 2
	match state:
		NodeState.LOCKED:
			background = BG_CARD.darkened(0.35)
			border = BORDER_STEEL.darkened(0.45)
		NodeState.AVAILABLE:
			border = BORDER_STEEL_BRIGHT
		NodeState.PARTIAL:
			background = BG_CARD.lerp(ACCENT_GOLD, 0.06)
			border = ACCENT_GOLD.darkened(0.4)
		NodeState.RESEARCHING:
			background = BG_CARD.lightened(0.06)
			border = ACCENT_GOLD
			border_width = 2
		NodeState.COMPLETED:
			background = BG_CARD.lerp(COLOR_RESEARCHED, 0.22)
			border = COLOR_RESEARCHED
	if selected:
		border = TEXT_PRIMARY
		border_width = 2
	var style := UITheme.panel_style(background, border, border_width * roundi(_scale), 0, false)
	style.set_content_margin_all(CARD_PADDING * _scale)
	return style

func _state_text_color(state: int) -> Color:
	return TEXT_LOCKED if state == NodeState.LOCKED else TEXT_PRIMARY

func _state_accent(state: int) -> Color:
	match state:
		NodeState.RESEARCHING, NodeState.PARTIAL:
			return ACCENT_GOLD
		NodeState.COMPLETED:
			return COLOR_RESEARCHED
		NodeState.AVAILABLE:
			return BORDER_STEEL_BRIGHT
	return TEXT_LOCKED

# --- Barra de status, rodapé e ferramentas de debug ---------------------------------------------

## Atualiza o que NÃO são cards: status do projeto ativo, rodapé e botões de debug.
func _refresh_chrome() -> void:
	if _status_label == null or _state == null:
		return
	var parts: Array[String] = []
	var active := V2ResearchDatabase.get_node(_state.active_id)
	var city_gate := V2ResearchAccess.state_blocked_reason(_state)
	if active == null and city_gate != "":
		parts.append("Pesquisa indisponível — %s" % city_gate)
	elif active != null:
		parts.append("Pesquisando: %s — %s / %s (%d%%)" % [active.display_name, V2ResearchState.format_amount(_state.get_progress(active.id)), V2ResearchState.format_amount(active.cost), int(round(_state.get_progress_ratio(active.id) * 100.0))])
	else:
		parts.append("Nenhum projeto ativo")
	# O Conhecimento guardado tem indicador próprio ao lado (_refresh_banked_chip): esta linha é cortada com reticências.
	_status_label.text = "  ·  ".join(parts)
	_status_label.tooltip_text = _status_label.text
	_refresh_banked_chip()
	if _jump_active_button != null:
		_jump_active_button.disabled = _state.active_id == ""
		_jump_available_button.disabled = first_available_id() == ""
		var popup := _navigation_menu.get_popup()
		popup.set_item_disabled(popup.get_item_index(0), _jump_active_button.disabled)
		popup.set_item_disabled(popup.get_item_index(1), _jump_available_button.disabled)
		popup.set_item_checked(popup.get_item_index(2), is_equal_approx(zoom, .8))
		popup.set_item_checked(popup.get_item_index(3), is_equal_approx(zoom, 1.0))
	_refresh_footer()
	if debug_tools_enabled and not _debug_buttons.is_empty():
		var selected := V2ResearchDatabase.get_node(_selected_id)
		_debug_buttons["complete_active"].disabled = _state.active_id == ""
		_debug_buttons["complete_branch"].disabled = selected == null or selected.is_universal

## Aetherlands V2, Fase 16 — progresso da Supremacia Militar V2, só no capstone militar já concluído
## pela civilização deste tabuleiro (derivado, recalculado ao montar/selecionar; nunca por frame).
func _supremacy_lines(node: V2ResearchNode) -> Array[String]:
	var empty: Array[String] = []
	if node == null or not _state.is_completed(node.id):
		return empty
	if node.unlock_id not in [V2VictoryConditions.MILITARY_SUPREMACY_ACCESS, V2VictoryConditions.TRANSCENDENCE_ACCESS]:
		return empty
	for player in GameManager.players:
		if player.v2_research == _state:
			return V2VictoryConditions.military_supremacy_lines(player) if node.unlock_id == V2VictoryConditions.MILITARY_SUPREMACY_ACCESS else V2VictoryConditions.transcendence_lines(player)
	return empty

func _refresh_footer() -> void:
	var node := V2ResearchDatabase.get_node(_selected_id)
	if node == null:
		_footer_title.text = "Nenhum nó selecionado"
		_footer_description.text = ""
		_footer_description.visible = false
		_footer_detail.text = "Clique em um nó para ver detalhes e pesquisar."
		_action_button.text = "—"
		_action_button.disabled = true
		return
	var state := _state.node_state(node.id)
	_footer_description.text = node.intent if node.intent != "" else node.description
	_footer_description.visible = false
	_footer_title.tooltip_text = "%s\n%s" % [node.display_name, _footer_description.text]
	_footer_title.text = "%s · %s" % [node.display_name, V2ResearchDatabase.role_label(node.tier_role)]
	var identity: String
	if node.is_universal:
		var progress := V2ResearchDatabase.capstone_progress(node.id, _state.completed_ids)
		identity = "Nó universal · %s completas: %d / %d (%s)" % [V2ResearchDatabase.capstone_unit_word(node), progress.x, progress.y, V2ResearchDatabase.tier_label(node.tree_type, node.requirement.at_tier)]
	else:
		identity = "%s · Nível %d" % [V2ResearchDatabase.line_label(node), V2ResearchDatabase.display_tier(node.tree_type, node.tier)]
	# Duas linhas (identidade + custo / estado, progresso e motivo) pra caber sem rolar.
	_footer_detail.text = "%s  ·  Custo: %s\n%s" % [identity, V2ResearchState.format_amount(node.cost), _state.status_text(node.id).replace("\n", "  ·  ")]
	var supremacy := _supremacy_lines(node)
	if not supremacy.is_empty():
		_footer_detail.text += "\n" + "  ·  ".join(supremacy)
	var banked := _banked_sentence(node.id)
	if banked != "":
		_footer_detail.text += "\n" + banked
	match state:
		NodeState.AVAILABLE:
			_action_button.text = "Pesquisar"
		NodeState.PARTIAL:
			_action_button.text = "Continuar pesquisa"
		NodeState.RESEARCHING:
			_action_button.text = "Pausar pesquisa"
		NodeState.COMPLETED:
			_action_button.text = "Concluído"
		_:
			_action_button.text = "Bloqueado"
	_action_button.disabled = state == NodeState.COMPLETED or state == NodeState.LOCKED
	# V3 / Etapa 2: estado semântico próprio antes da primeira cidade (não finge que é pré-requisito).
	var city_gate := V2ResearchAccess.state_blocked_reason(_state)
	if city_gate != "" and state in [NodeState.AVAILABLE, NodeState.PARTIAL]:
		_action_button.text = V2ResearchAccess.STATE_LABEL_REQUIRES_CITY
		_action_button.disabled = true
		_action_button.tooltip_text = city_gate
		_footer_detail.text += "\n%s" % city_gate
	else:
		_action_button.tooltip_text = ""

## Mesmo estilo "chip" dos botões das árvores V1 (HUD._style_doutrina_chip_button).
func _style_chip(button: Button, _accent: Color) -> void:
	# Reuse the actual menu sprites and focus outline, scoped to research.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var frame := theme.get_stylebox(state, "SetupSmallButton").duplicate() as StyleBox
		frame.content_margin_left = 8 * _scale
		frame.content_margin_right = 8 * _scale
		frame.content_margin_top = 6 * _scale
		frame.content_margin_bottom = 6 * _scale
		button.add_theme_stylebox_override(state, frame)
