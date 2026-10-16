extends Control

## Tela cheia de "Carregar Jogo" — Roadmap "sistema de menu de jogo
## moderno" (pedido do usuario: "carregar jogo deve abrir uma tela com os
## jogos possiveis de carregar, ai voce escolhe um e ele de fato e
## carregado"). Reusada por TitleScreen (nenhuma partida em andamento, sem
## risco) E PauseMenu (carregar substitui a partida atual — ver
## slot_load_requested, quem escuta decide se pede confirmacao antes de
## emitir). Nao toca em HexGrid/GameManager diretamente — so repassa qual
## slot foi escolhido pro dono (Main.gd de fato carrega).

signal slot_load_requested(slot_id: String)
signal back_requested

@onready var scroll_container: ScrollContainer = $Margin/VBox/ScrollContainer
@onready var slot_list: VBoxContainer = $Margin/VBox/ScrollContainer/SlotList
@onready var empty_state_label: Label = $Margin/VBox/EmptyState/EmptyBox/EmptyStateLabel
@onready var back_button: Button = $Margin/VBox/Footer/BackButton
@onready var confirm_delete_dialog: ConfirmationDialog = $ConfirmDeleteDialog

var _pending_delete_slot_id: String = ""
var _pending_delete_dir: String = SaveManager.SAVE_DIR
var _delete_focus_return: Button
var _delete_display_name := ""
const MENU_THEME := preload("res://scripts/ui/FantasyMenuTheme.gd")

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	get_viewport().size_changed.connect(_layout_for_viewport)
	visibility_changed.connect(_layout_for_viewport)
	back_button.pressed.connect(func(): back_requested.emit())
	confirm_delete_dialog.title = "Excluir partida"
	confirm_delete_dialog.get_ok_button().text = "Excluir"
	confirm_delete_dialog.get_cancel_button().text = "Cancelar"
	confirm_delete_dialog.confirmed.connect(_on_delete_confirmed)
	confirm_delete_dialog.canceled.connect(_on_delete_canceled)
	_layout_for_viewport.call_deferred()

func _apply_accessibility_theme() -> void:
	theme = MENU_THEME.build(Settings.ui_scale_factor())
	_layout_for_viewport.call_deferred()

func _layout_for_viewport() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var factor := Settings.ui_scale_factor()
	var edge := roundi(maxf(32, (viewport_size.x - 1160 * maxf(1, factor)) / 2))
	var vertical := 24 if viewport_size.y < 800 else 36
	for side in ["left", "right"]:
		$Margin.add_theme_constant_override("margin_" + side, edge)
	for side in ["top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, vertical)
	$Margin/VBox/Header/Titles/Title.add_theme_font_size_override("font_size", roundi((36 if viewport_size.y < 800 else 44) * factor))
	back_button.custom_minimum_size = Vector2(160 * factor, 52 * factor)
	for panel in slot_list.get_children():
		var row: HBoxContainer = panel.get_node("Row")
		row.get_node("Portrait").custom_minimum_size = Vector2(120, 84) * factor
		row.get_node("Actions/Carregar").custom_minimum_size = Vector2(140, 48) * factor
		row.get_node("Actions/Excluir").custom_minimum_size = Vector2(110, 44) * factor
		panel.add_theme_stylebox_override("panel", MENU_THEME.panel(false, factor))
	_configure_focus()

func _configure_focus() -> void:
	var buttons: Array[Button] = []
	for panel in slot_list.get_children():
		for button: Button in panel.get_node("Row/Actions").get_children():
			if not button.disabled:
				buttons.append(button)
	buttons.append(back_button)
	for i in buttons.size():
		var button := buttons[i]
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		button.focus_neighbor_bottom = button.focus_next
		button.focus_neighbor_top = button.focus_previous

## Chamado pelo dono (TitleScreen/PauseMenu) sempre ANTES de navegar pra
## esta pagina — nunca so em _ready(), senao um save feito nesta mesma
## sessao de pausa nao apareceria ao reabrir "Carregar Jogo" depois.
## `dir` parametrizavel so pros testes GUT usarem um diretorio isolado
## (mesmo padrao de SaveManager.gd) — o jogo em si sempre usa o padrao.
func refresh(dir: String = SaveManager.SAVE_DIR) -> void:
	# remove_child() ANTES de queue_free() de proposito: queue_free() so
	# desliga o node no fim do frame, entao um refresh() chamado duas vezes
	# no MESMO frame (ex: excluir um slot -> refresh) ainda contaria as
	# linhas antigas em get_child_count() se so' queue_free() fosse chamado.
	for c in slot_list.get_children():
		slot_list.remove_child(c)
		c.queue_free()
	var slots := SaveManager.inspect_slots(dir)
	# ScrollContainer some quando vazio (nao so o label): senao ele
	# continuaria ocupando o espaco expand-fill vazio, empurrando a
	# mensagem "nenhuma partida salva" pro rodape da tela em vez de
	# centralizada.
	empty_state_label.visible = slots.is_empty()
	$Margin/VBox/EmptyState.visible = slots.is_empty()
	scroll_container.visible = not slots.is_empty()
	$Margin/VBox/ListHeading/CountLabel.text = "%d %s" % [slots.size(), "PARTIDA SALVA" if slots.size() == 1 else "PARTIDAS SALVAS"] if not slots.is_empty() else ""
	for s in slots:
		slot_list.add_child(_build_row(s, dir))
	_focus_first_available.call_deferred()
	_layout_for_viewport.call_deferred()

func _focus_first_available() -> void:
	if not is_visible_in_tree():
		return
	var target := _first_enabled_load_button(slot_list)
	if target == null: target = back_button
	target.grab_focus()

func _first_enabled_load_button(root: Node) -> Button:
	for child in root.get_children():
		if child is Button and child.text == "Carregar" and not child.disabled:
			return child
		var nested := _first_enabled_load_button(child)
		if nested != null:
			return nested
	return null

func _build_row(s: Dictionary, dir: String = SaveManager.SAVE_DIR) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SetupPanel"

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var status := String(s.get("status", "valid"))
	var race := String(s.get("race", "human"))
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(120, 84)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path := "res://assets/ui/game_setup/city_%s.png" % race
	portrait.texture = load(portrait_path if status == "valid" and ResourceLoader.exists(portrait_path) else "res://assets/ui/title_menu/crest.svg") as Texture2D
	portrait.modulate = Color.WHITE if status == "valid" else Color("bc988a")
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	var kicker := Label.new()
	kicker.theme_type_variation = &"SetupKicker"
	kicker.text = "%s  ·  TURNO %d" % [GameSetupScreen.RACE_INFO.get(race, GameSetupScreen.RACE_INFO.human).race_name.to_upper(), int(s.get("turn_number", 0))] if status == "valid" else _status_title(status).to_upper()
	kicker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(kicker)

	var name_label := Label.new()
	var kingdom_name := String(s.get("kingdom_name", "")).strip_edges()
	var known_name := not kingdom_name.is_empty() and kingdom_name != "?"
	name_label.theme_type_variation = &"SetupHeading"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = kingdom_name if known_name else ("Partida sem nome" if status == "valid" else "Arquivo indisponível")
	name_label.tooltip_text = "%s\n%s" % [kingdom_name, _race_display(race)] if status == "valid" else String(s.slot_id)
	info.add_child(name_label)

	var detail_label := Label.new()
	detail_label.theme_type_variation = &"SetupMuted"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = _slot_detail(s)
	if status != "valid":
		detail_label.add_theme_color_override("font_color", Color("ffc4ad"))
	info.add_child(detail_label)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)

	var load_button := Button.new()
	load_button.text = "Carregar"
	load_button.name = "Carregar"
	load_button.theme_type_variation = &"TitlePrimaryButton"
	load_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	load_button.pressed.connect(func(): slot_load_requested.emit(s.slot_id))
	load_button.disabled = status != "valid"
	load_button.tooltip_text = _status_reason(status)
	actions.add_child(load_button)

	var delete_button := Button.new()
	delete_button.text = "Excluir"
	delete_button.name = "Excluir"
	delete_button.theme_type_variation = &"MenuDangerButton"
	delete_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_button.pressed.connect(func():
		_delete_focus_return = delete_button
		_delete_display_name = kingdom_name if known_name else "%s (%s)" % [_status_title(status), String(s.slot_id)]
		_on_delete_pressed(s.slot_id, dir))
	actions.add_child(delete_button)

	return panel

func _slot_detail(s: Dictionary) -> String:
	var status := String(s.get("status", "valid"))
	if status != "valid":
		return _status_reason(status)
	var saved_at := _format_saved_at(int(s.get("saved_at", 0)))
	return "Salvo em %s" % saved_at if not saved_at.is_empty() else "Data de salvamento indisponível."

func _status_title(status: String) -> String:
	return "Partida incompatível" if status == "incompatible" else "Partida corrompida"

func _status_reason(status: String) -> String:
	match status:
		"incompatible": return "Criada por uma versão do jogo não suportada."
		"corrupt": return "Não foi possível ler esta partida salva."
	return ""

func _on_delete_pressed(slot_id: String, dir: String = SaveManager.SAVE_DIR) -> void:
	_pending_delete_slot_id = slot_id
	_pending_delete_dir = dir
	confirm_delete_dialog.dialog_text = "Excluir \"%s\"?\nEsta partida será removida permanentemente." % _delete_display_name if not _delete_display_name.is_empty() else "Excluir esta partida salva? Isso não pode ser desfeito."
	confirm_delete_dialog.popup_centered()
	# Safe default: Enter must not accidentally confirm a destructive action.
	confirm_delete_dialog.get_cancel_button().call_deferred("grab_focus")

func _on_delete_canceled() -> void:
	_pending_delete_slot_id = ""
	_delete_display_name = ""
	if is_instance_valid(_delete_focus_return):
		_delete_focus_return.call_deferred("grab_focus")

func _on_delete_confirmed() -> void:
	# hide() explicito, mesmo motivo de PauseMenu._on_load_confirmed().
	confirm_delete_dialog.hide()
	SaveManager.delete_slot(_pending_delete_slot_id, _pending_delete_dir)
	_pending_delete_slot_id = ""
	refresh(_pending_delete_dir)

func _race_display(race: String) -> String:
	var info: Dictionary = GameSetupScreen.RACE_INFO.get(race, {})
	return info.get("display_name", race.capitalize())

func _format_saved_at(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	# Saves use UTC timestamps; show the date in the player's local timezone.
	var local_unix := unix_time + int(Time.get_time_zone_from_system().bias) * 60
	var dt := Time.get_datetime_dict_from_unix_time(local_unix)
	return "%02d/%02d/%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
