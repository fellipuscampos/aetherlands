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
@onready var empty_state_label: Label = $Margin/VBox/EmptyStateLabel
@onready var back_button: Button = $Margin/VBox/BackButton
@onready var confirm_delete_dialog: ConfirmationDialog = $ConfirmDeleteDialog

var _pending_delete_slot_id: String = ""
var _pending_delete_dir: String = SaveManager.SAVE_DIR

func _ready() -> void:
	back_button.pressed.connect(func(): back_requested.emit())
	confirm_delete_dialog.title = "Confirmar"
	confirm_delete_dialog.get_ok_button().text = "Excluir"
	confirm_delete_dialog.get_cancel_button().text = "Cancelar"
	confirm_delete_dialog.confirmed.connect(_on_delete_confirmed)

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
	var slots := SaveManager.list_slots(dir)
	# ScrollContainer some quando vazio (nao so o label): senao ele
	# continuaria ocupando o espaco expand-fill vazio, empurrando a
	# mensagem "nenhuma partida salva" pro rodape da tela em vez de
	# centralizada.
	empty_state_label.visible = slots.is_empty()
	scroll_container.visible = not slots.is_empty()
	for s in slots:
		slot_list.add_child(_build_row(s, dir))

func _build_row(s: Dictionary, dir: String = SaveManager.SAVE_DIR) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.COLOR_BG_PANEL_LIGHT, UITheme.COLOR_BORDER, 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [s.kingdom_name, _race_display(s.race)]
	info.add_child(name_label)

	var detail_label := Label.new()
	detail_label.theme_type_variation = &"MutedLabel"
	detail_label.text = "Turno %d — %s" % [s.turn_number, _format_saved_at(s.saved_at)]
	info.add_child(detail_label)

	var load_button := Button.new()
	load_button.text = "Carregar"
	load_button.pressed.connect(func(): slot_load_requested.emit(s.slot_id))
	row.add_child(load_button)

	var delete_button := Button.new()
	delete_button.text = "Excluir"
	delete_button.pressed.connect(func(): _on_delete_pressed(s.slot_id, dir))
	row.add_child(delete_button)

	return panel

func _on_delete_pressed(slot_id: String, dir: String = SaveManager.SAVE_DIR) -> void:
	_pending_delete_slot_id = slot_id
	_pending_delete_dir = dir
	confirm_delete_dialog.dialog_text = "Excluir esta partida salva? Isso não pode ser desfeito."
	confirm_delete_dialog.popup_centered()

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
	var dt := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d/%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
