class_name AEAbilityButton
extends Button

## Botão único de habilidade (Técnica, feitiço, Portal, Hoste, upgrade, ação
## especial). Não conhece id concreto de nada: recebe `UnitAbilityViewData` ou os
## parâmetros legados de `configure`. Recarga é lida NO próprio botão (sombra +
## número grande), bloqueio mostra o motivo curto na linha de metadado e passiva
## não tem aparência de controle clicável.

enum AbilityState { AVAILABLE, HOVERED, SELECTED, DISABLED, COOLDOWN, COST, PASSIVE, ACTIVE }

const CATEGORY_GLYPHS := {
	UnitAbilityViewData.Category.COMMAND: "●",
	UnitAbilityViewData.Category.TECHNIQUE: "◆",
	UnitAbilityViewData.Category.SPELL: "✦",
	UnitAbilityViewData.Category.PORTAL: "◎",
	UnitAbilityViewData.Category.RETINUE: "✚",
	UnitAbilityViewData.Category.UPGRADE: "▲",
	UnitAbilityViewData.Category.BUILDER: "■",
	UnitAbilityViewData.Category.SPECIAL: "◇",
}

signal ability_pressed(view: UnitAbilityViewData)

var ability_state: AbilityState = AbilityState.AVAILABLE
var cooldown_turns := 0
var cost_text := ""
var icon_fallback := "◆"
var accent := UIThemeTokens.COLOR_ACCENT
var meta_text := ""
var view: UnitAbilityViewData
var title_label: Label
var meta_label: Label
var glyph_panel: PanelContainer
var glyph_label: Label
var _cooldown_badge: Label
var _cost_badge: Label
var _cooldown_shade: ColorRect
var _cooldown_big: Label
var _texture_rect: TextureRect
var _applied := false

## Tudo que é estático nasce no construtor: configurar antes de entrar na árvore
## evita propagação de tema repetida (medido na Fase 30: ~5x mais barato).
func _init() -> void:
	theme_type_variation = &"SecondaryButton"
	custom_minimum_size = Vector2(152, 64)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	pressed.connect(_on_pressed)

func _ready() -> void:
	_build_overlays()
	if not _applied:
		_apply_state()

func configure(title: String, state: AbilityState = AbilityState.AVAILABLE, cooldown: int = 0, cost: String = "", fallback: String = "◆") -> void:
	icon_fallback = fallback
	ability_state = state
	cooldown_turns = cooldown
	cost_text = cost
	meta_text = cost
	_build_overlays()
	_ensure_cost_badge()
	title_label.text = title
	tooltip_text = AETooltip.compose(title, "", [], "", "")
	_apply_state()

## Integração real (UI-3): um descriptor genérico vindo do UnitPresenter.
func configure_view(value: UnitAbilityViewData) -> void:
	view = value
	_build_overlays()
	name = "Ability_" + value.id if not value.id.is_empty() else name
	icon_fallback = value.glyph if not value.glyph.is_empty() else String(CATEGORY_GLYPHS.get(value.category, "◆"))
	accent = value.accent_color if value.accent_color.a > 0.0 else _category_color(value.category)
	cost_text = value.cost_text
	cooldown_turns = value.cooldown_current
	meta_text = value.cost_text
	match value.state:
		UnitAbilityViewData.State.TARGETING:
			ability_state = AbilityState.SELECTED
		UnitAbilityViewData.State.ACTIVE:
			ability_state = AbilityState.ACTIVE
		UnitAbilityViewData.State.COOLDOWN:
			ability_state = AbilityState.COOLDOWN
		UnitAbilityViewData.State.BLOCKED:
			ability_state = AbilityState.DISABLED
			meta_text = _short_reason(value.blocked_reason)
		UnitAbilityViewData.State.PASSIVE:
			ability_state = AbilityState.PASSIVE
			meta_text = "Passiva"
		_:
			ability_state = AbilityState.AVAILABLE
	if value.is_toggle and value.toggled:
		ability_state = AbilityState.ACTIVE
	title_label.text = value.display_name
	tooltip_text = value.tooltip()
	if not value.icon_path.is_empty() and ResourceLoader.exists(value.icon_path):
		set_icon_texture(load(value.icon_path) as Texture2D)
	_apply_state()

func set_ability_state(state: AbilityState) -> void:
	ability_state = state
	_apply_state()

## Slot de ícone final: quando houver arte, substitui o glyph sem mudar layout.
func set_icon_texture(texture: Texture2D) -> void:
	_build_overlays()
	if _texture_rect == null:
		_texture_rect = TextureRect.new()
		_texture_rect.name = "IconTexture"
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph_panel.add_child(_texture_rect)
		glyph_panel.move_child(_texture_rect, 1)
	_texture_rect.texture = texture
	_texture_rect.visible = texture != null
	glyph_label.visible = texture == null

func _make_custom_tooltip(for_text: String) -> Object:
	return AETooltip.make_card(for_text)

## Só o essencial nasce sempre (slot, glyph, nome, metadado); recarga, textura e
## o badge de custo legado são criados sob demanda — cada Label custa ~0,13 ms ao
## entrar na árvore (medido na Fase 30).
func _build_overlays() -> void:
	if title_label != null:
		return
	var row := HBoxContainer.new()
	row.name = "Content"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UIThemeTokens.SPACE_2
	row.offset_right = -UIThemeTokens.SPACE_2
	row.offset_top = UIThemeTokens.SPACE_1
	row.offset_bottom = -UIThemeTokens.SPACE_1
	row.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	add_child(row)
	glyph_panel = PanelContainer.new()
	glyph_panel.name = "IconSlot"
	glyph_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_panel.custom_minimum_size = Vector2(40, 40)
	glyph_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph_panel)
	glyph_label = Label.new()
	glyph_label.name = "Glyph"
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", 20)
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_panel.add_child(glyph_label)
	var texts := VBoxContainer.new()
	texts.name = "Texts"
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
	texts.add_child(title_label)
	meta_label = Label.new()
	meta_label.name = "Meta"
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
	texts.add_child(meta_label)

func _ensure_cooldown_nodes() -> void:
	if _cooldown_badge != null:
		return
	_cooldown_shade = ColorRect.new()
	_cooldown_shade.name = "CooldownShade"
	_cooldown_shade.color = Color(0.02, 0.03, 0.05, 0.72)
	_cooldown_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_panel.add_child(_cooldown_shade)
	_cooldown_big = Label.new()
	_cooldown_big.name = "CooldownNumber"
	_cooldown_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_big.add_theme_font_size_override("font_size", 22)
	_cooldown_big.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT)
	_cooldown_big.add_theme_constant_override("outline_size", 4)
	_cooldown_big.add_theme_color_override("font_outline_color", Color.BLACK)
	_cooldown_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_panel.add_child(_cooldown_big)
	# Badge legado mantido pelo contrato da Fase 28B (testes e consumidores).
	_cooldown_badge = Label.new()
	_cooldown_badge.name = "CooldownBadge"
	_cooldown_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cooldown_badge.position = Vector2(-30, 4)
	_cooldown_badge.size = Vector2(26, 22)
	_cooldown_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_badge.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
	_cooldown_badge.add_theme_stylebox_override("normal", UITheme.panel_style(UIThemeTokens.COLOR_CRITICAL.darkened(0.35), UIThemeTokens.COLOR_CRITICAL, 1, 10, false))
	add_child(_cooldown_badge)

func _ensure_cost_badge() -> void:
	if _cost_badge != null:
		return
	_cost_badge = Label.new()
	_cost_badge.name = "CostBadge"
	_cost_badge.visible = false
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)

func _apply_state() -> void:
	if title_label == null:
		return
	_applied = true
	var passive := ability_state == AbilityState.PASSIVE
	var active := ability_state == AbilityState.ACTIVE
	var cooldown := ability_state == AbilityState.COOLDOWN
	var blocked := ability_state in [AbilityState.DISABLED, AbilityState.COST]
	var toggle_active := active and view != null and view.is_toggle
	disabled = cooldown or passive or blocked or (active and not toggle_active)
	focus_mode = Control.FOCUS_NONE if passive else Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	# Em mira o botão fica "aceso" (toggle); o próximo clique cancela a mira.
	toggle_mode = ability_state == AbilityState.SELECTED
	set_pressed_no_signal(ability_state == AbilityState.SELECTED)
	var show_cooldown := cooldown_turns > 0 or cooldown
	if show_cooldown:
		_ensure_cooldown_nodes()
	if _cooldown_badge != null:
		_cooldown_badge.visible = show_cooldown
		_cooldown_badge.text = str(maxi(1, cooldown_turns)) if show_cooldown else ""
		_cooldown_shade.visible = show_cooldown
		_cooldown_big.visible = show_cooldown
		_cooldown_big.text = _cooldown_badge.text
	if _cost_badge != null:
		_cost_badge.text = cost_text
	glyph_label.text = icon_fallback
	var glyph_color := accent
	var meta_color := UIThemeTokens.COLOR_TEXT_MUTED
	var title_color := UIThemeTokens.COLOR_TEXT
	var meta := meta_text
	if passive:
		theme_type_variation = &"GhostButton"
		glyph_color = UIThemeTokens.COLOR_TEXT_MUTED
		title_color = UIThemeTokens.COLOR_TEXT_MUTED
		if meta.is_empty():
			meta = "Passiva"
		if tooltip_text.is_empty():
			tooltip_text = "Passiva — age automaticamente."
	elif ability_state == AbilityState.SELECTED:
		theme_type_variation = &"PrimaryButton"
		glyph_color = UIThemeTokens.COLOR_TARGETING
		title_color = UIThemeTokens.COLOR_CANVAS
		meta_color = UIThemeTokens.COLOR_CANVAS
		meta = "Escolha o alvo"
	elif active:
		theme_type_variation = &"SecondaryButton"
		glyph_color = UIThemeTokens.COLOR_SUCCESS
		meta_color = UIThemeTokens.COLOR_SUCCESS
		meta = "Ativa" if view == null or not view.is_toggle else "Ligado"
	elif cooldown:
		theme_type_variation = &"SecondaryButton"
		glyph_color = accent.darkened(0.5)
		title_color = UIThemeTokens.COLOR_TEXT_DISABLED
		meta = "Recarga %dT" % maxi(1, cooldown_turns)
	elif blocked:
		theme_type_variation = &"SecondaryButton"
		glyph_color = accent.darkened(0.45)
		title_color = UIThemeTokens.COLOR_TEXT_DISABLED
		meta_color = UIThemeTokens.COLOR_WARNING
	else:
		theme_type_variation = &"SecondaryButton"
	meta_label.text = meta
	meta_label.visible = not meta.is_empty()
	meta_label.add_theme_color_override("font_color", meta_color)
	title_label.add_theme_color_override("font_color", title_color)
	glyph_label.add_theme_color_override("font_color", glyph_color)
	var slot_border := glyph_color if not passive else UIThemeTokens.COLOR_BORDER
	var slot_bg := UIThemeTokens.COLOR_CANVAS if not passive else Color(0, 0, 0, 0)
	glyph_panel.add_theme_stylebox_override("panel", UITheme.panel_style(slot_bg, slot_border, 1, UIThemeTokens.RADIUS_CONTROL, false))
	if passive:
		add_theme_stylebox_override("disabled", UITheme.panel_style(Color(0, 0, 0, 0), Color(UIThemeTokens.COLOR_BORDER, 0.5), 1, UIThemeTokens.RADIUS_CONTROL, false))
	elif active:
		add_theme_stylebox_override("disabled", UITheme.panel_style(UIThemeTokens.COLOR_SUCCESS.darkened(0.72), UIThemeTokens.COLOR_SUCCESS, 1, UIThemeTokens.RADIUS_CONTROL, false))
		add_theme_stylebox_override("normal", UITheme.panel_style(UIThemeTokens.COLOR_SUCCESS.darkened(0.72), UIThemeTokens.COLOR_SUCCESS, 1, UIThemeTokens.RADIUS_CONTROL, false))
	else:
		remove_theme_stylebox_override("disabled")
		remove_theme_stylebox_override("normal")

func _on_pressed() -> void:
	if view != null:
		ability_pressed.emit(view)

static func _short_reason(reason: String) -> String:
	var text := reason.strip_edges().trim_suffix(".")
	var colon := text.find(":")
	if colon > 0 and colon < 26:
		text = text.substr(0, colon)
	return text

static func _category_color(category: int) -> Color:
	match category:
		UnitAbilityViewData.Category.SPELL:
			return UIThemeTokens.COLOR_INFO
		UnitAbilityViewData.Category.PORTAL:
			return UIThemeTokens.COLOR_TARGETING
		UnitAbilityViewData.Category.UPGRADE:
			return UIThemeTokens.COLOR_SUCCESS
		UnitAbilityViewData.Category.RETINUE:
			return UIThemeTokens.COLOR_TEXT_MUTED
		UnitAbilityViewData.Category.BUILDER, UnitAbilityViewData.Category.COMMAND:
			return UIThemeTokens.COLOR_INFO
	return UIThemeTokens.COLOR_ACCENT
