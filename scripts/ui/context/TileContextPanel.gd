class_name TileContextPanel
extends VBoxContainer

## Painel de contexto de TILE (Fase 30 / UI-3) — componentiza o Tile Inspector
## textual. Camadas separadas: TERRENO-BASE, MODIFICAÇÃO (Druidismo), AMBIENTE
## (zona temporária) e CARACTERÍSTICAS (recurso/melhoria, Portal, covil, obra).
## Só mostra o que existe; névoa e segredo vêm do TileInspector.

signal close_requested

var coord := Vector2i(999999, 999999)
var view: Dictionary = {}
var title_label: Label
var subtitle_label: Label
var portrait: AEPortrait
var body: VBoxContainer
var render_count := 0
var _last_key := 0

func _ready() -> void:
	name = "TileContextPanel"
	add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_chrome()

func _build_chrome() -> void:
	if body != null:
		return
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	add_child(header)
	portrait = AEPortrait.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(52, 52)
	header.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	header.add_child(identity)
	title_label = ContextUI.label("", UIThemeTokens.FONT_H3, UIThemeTokens.COLOR_TEXT)
	title_label.name = "TileTitle"
	identity.add_child(title_label)
	subtitle_label = ContextUI.caption("")
	subtitle_label.name = "Subtitle"
	identity.add_child(subtitle_label)
	var close := ContextUI.close_button("Fechar")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIThemeTokens.SPACE_3)
	scroll.add_child(body)

func show_tile(value: Vector2i) -> void:
	coord = value
	refresh()

func refresh() -> void:
	_build_chrome()
	var built := TilePresenter.build(GameManager.hex_grid, coord, GameManager.human_player)
	var key := str(built).hash()
	view = built
	if key == _last_key and render_count > 0:
		return
	_last_key = key
	ContextUI.clear(body)
	if not view.get("valid", false):
		return
	title_label.text = view.title
	var state_text := "Visível agora"
	if view.state == TileInspector.STATE_EXPLORED:
		state_text = "Lembrado — fora da visão"
	elif view.state == TileInspector.STATE_UNSEEN:
		state_text = "Inexplorado"
	subtitle_label.text = "%s · %s" % [view.subtitle, state_text]
	portrait.configure("◇" if view.state != TileInspector.STATE_UNSEEN else "?", UIThemeTokens.COLOR_INFO if view.state == TileInspector.STATE_VISIBLE else UIThemeTokens.COLOR_TEXT_MUTED, UIThemeTokens.COLOR_BORDER, "Tile")
	if view.state == TileInspector.STATE_UNSEEN:
		body.add_child(ContextUI.empty_state("Região inexplorada: envie uma unidade para revelar."))
		render_count += 1
		return
	body.add_child(_terrain_section())
	if not view.modification.is_empty():
		body.add_child(_modification_section())
	if not view.environment.is_empty():
		body.add_child(_environment_section())
	if not view.features.is_empty():
		body.add_child(_features_section())
	if view.remembered:
		body.add_child(ContextUI.caption("Informação lembrada: o estado atual pode ter mudado."))
	render_count += 1

func _terrain_section() -> Control:
	var terrain: Dictionary = view.terrain
	var section := ContextUI.section("Terreno-base")
	section.name = "Terrain"
	section.tooltip_text = String(terrain.tooltip)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIThemeTokens.SPACE_1)
	section.add_child(grid)
	var movement := AEStatItem.new()
	movement.name = "MovementCost"
	movement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(movement)
	movement.set_stat("Custo de movimento", str(terrain.movement_cost), "➤", AETooltip.compose("Custo de movimento", "Pontos gastos para entrar neste terreno-base."))
	var defense := AEStatItem.new()
	defense.name = "DefenseModifier"
	defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(defense)
	defense.set_stat("Defesa física", "+%d%%" % int(terrain.defense_pct), "■", AETooltip.compose("Defesa física", "Bônus do terreno-base para quem defende aqui."))
	if String(terrain.territory) != "":
		section.add_child(ContextUI.key_value("Território", String(terrain.territory)))
	return section

func _modification_section() -> Control:
	var modification: Dictionary = view.modification
	var section := ContextUI.section("Modificação de terreno", "Druidismo")
	section.name = "Modification"
	var card := ContextUI.card(V2MagicContent.school_color("druidism"))
	card.tooltip_text = String(modification.tooltip)
	section.add_child(card)
	var content := VBoxContainer.new()
	card.add_child(content)
	content.add_child(ContextUI.label(String(modification.name), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false))
	content.add_child(ContextUI.caption("Movimento +%d · Defesa física +%d%% (sobre o terreno-base)" % [int(modification.movement_delta), int(modification.defense_pct)]))
	return section

func _environment_section() -> Control:
	var environment: Dictionary = view.environment
	var section := ContextUI.section("Ambiente temporário")
	section.name = "Environment"
	var card := ContextUI.card(UIThemeTokens.COLOR_WARNING)
	card.tooltip_text = String(environment.tooltip)
	section.add_child(card)
	var content := VBoxContainer.new()
	card.add_child(content)
	content.add_child(ContextUI.label(String(environment.title), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false))
	for line in environment.lines:
		content.add_child(ContextUI.caption(String(line)))
	return section

func _features_section() -> Control:
	var section := ContextUI.section("Neste tile")
	section.name = "Features"
	for feature in view.features:
		var accent := UIThemeTokens.COLOR_BORDER
		match String(feature.kind):
			"portal":
				accent = UIThemeTokens.COLOR_TARGETING
			"resource":
				accent = UIThemeTokens.COLOR_SUCCESS
			"lair":
				accent = UIThemeTokens.COLOR_CRITICAL
			"hazard":
				accent = UIThemeTokens.COLOR_WARNING
			"territory":
				accent = UIThemeTokens.COLOR_INFO
		var card := ContextUI.card(accent)
		card.name = "Feature_" + String(feature.kind)
		card.tooltip_text = String(feature.tooltip)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 0)
		card.add_child(content)
		content.add_child(ContextUI.label(String(feature.title), UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT, false))
		for line in feature.lines:
			content.add_child(ContextUI.caption(String(line)))
		section.add_child(card)
	return section

func preferred_height() -> float:
	var header := get_node("Header") as Control
	return header.get_combined_minimum_size().y + body.get_combined_minimum_size().y + UIThemeTokens.SPACE_2 * 3
