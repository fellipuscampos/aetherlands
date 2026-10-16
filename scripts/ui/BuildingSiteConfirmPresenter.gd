class_name BuildingSiteConfirmPresenter
extends Node

## CONSTRUIR SOBRE RECURSO DE MAPA (2026-10-12, pedido do usuário: "se tiver algum recurso de mapa e eu construir
## algo em cima, deve aparecer um modal falando que construir um prédio ali destruirá o recurso, e se a pessoa
## aceitar o prédio começa a ser construído e o recurso daquele tile some"). Quando o jogador escolhe, no
## posicionamento de prédio, um tile com recurso (SelectionManager -> EventBus.building_placement_confirmation_
## requested), abre o modal com o que será perdido — o recurso e, se houver, a melhoria do Construtor com o
## rendimento dela — e devolve a resposta ao SelectionManager:
##  - Construir: a obra começa e o recurso é destruído (City.start_building);
##  - Escolher outro tile / fechar / ESC: nada é gasto nem destruído e o posicionamento continua ativo.
## Não guarda regra nem estado de jogo: o tile pendente vive em SelectionManager.placement_confirmation_coord e o que
## se perde vem de City.building_site_loss.

signal confirmation_presented(city: City, coord: Vector2i)

var modal_manager: ModalManager
var _modal: AEModalFrame

func _ready() -> void:
	EventBus.building_placement_confirmation_requested.connect(_on_confirmation_requested)
	if modal_manager != null:
		modal_manager.modal_closed.connect(_on_modal_closed)

func is_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

## O modal aberto agora (null se nenhum) — usado pelos testes e por quem precisar inspecionar.
func current_modal() -> AEModalFrame:
	return _modal if is_open() else null

func confirm() -> void:
	if not is_open():
		return
	_close()
	SelectionManager.confirm_building_placement()

func cancel() -> void:
	if not is_open():
		return
	_close()
	SelectionManager.decline_building_placement()

func _close() -> void:
	_modal = null # antes do dismiss: _on_modal_closed não trata esta saída como um cancelamento por ESC
	modal_manager.dismiss_top(true)

## ESC (ou qualquer outro caminho que feche o modal sem passar pelos botões) vale como "escolher outro tile".
func _on_modal_closed(modal: Control) -> void:
	if _modal != null and modal == _modal:
		_modal = null
		SelectionManager.decline_building_placement()

func _on_confirmation_requested(city: City, building_id: String, coord: Vector2i) -> void:
	var hex_grid := GameManager.hex_grid
	var loss := city.building_site_loss(coord, hex_grid) if hex_grid != null else {}
	if modal_manager == null or loss.is_empty():
		SelectionManager.confirm_building_placement() # sem ter como (ou o que) perguntar: o clique já foi a escolha
		return
	var frame := AEModalFrame.new()
	frame.name = "BuildingSiteConfirmModal"
	frame.custom_minimum_size = Vector2(480, 0)
	if not modal_manager.present(frame, true, true):
		frame.queue_free()
		SelectionManager.decline_building_placement()
		return
	_modal = frame
	var building := BuildingDatabase.get_building(building_id)
	var building_name := building.display_name if building != null else "o prédio"
	var resource_id := String(loss.resource)
	var resource_name := ResourceDatabase.display_name(resource_id)
	frame.set_title("Construir sobre %s?" % resource_name)
	frame.close_requested.connect(cancel)
	var body := frame.body_host
	body.add_child(ContextUI.label("Construir %s neste tile destrói o recurso %s. Ele some do mapa assim que a obra começa e não volta, mesmo que a construção seja cancelada depois." % [building_name, resource_name], UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	if V2ResourceImprovementData.has_resource(resource_id):
		var improvement := "%s: %s" % [V2ResourceImprovementData.display_name_for_resource(resource_id), ", ".join(TileInspector._improvement_yield_lines(resource_id, city.owner_player))]
		if String(loss.improvement) != "":
			body.add_child(ContextUI.key_value("Melhoria perdida", improvement, "critical", "A melhoria deste tile é destruída junto com o recurso e para de render."))
		else:
			body.add_child(ContextUI.key_value("Melhoria possível", improvement, "warning", "Um Construtor ainda poderia erguer esta melhoria aqui. Com o recurso destruído, não mais."))
	body.add_child(ContextUI.label("Para manter o recurso, escolha outro tile destacado.", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	body.add_child(buttons)
	var cancel_button := AEButton.new()
	cancel_button.name = "CancelButton"
	cancel_button.kind = AEButton.Kind.GHOST
	cancel_button.text = "Escolher outro tile"
	cancel_button.pressed.connect(cancel)
	buttons.add_child(cancel_button)
	var confirm_button := AEButton.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.kind = AEButton.Kind.DANGER
	confirm_button.text = "Construir e destruir %s" % resource_name
	confirm_button.pressed.connect(confirm)
	buttons.add_child(confirm_button)
	cancel_button.call_deferred("grab_focus")
	confirmation_presented.emit(city, coord)
