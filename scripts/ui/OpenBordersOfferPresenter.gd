class_name OpenBordersOfferPresenter
extends Node

## PEDIDO DE FRONTEIRAS ABERTAS AO JOGADOR (2026-10-13, pedido do usuário: "solicitar fronteiras abertas, aparece pra
## pessoa que foi solicitada e ambos ficam com fronteiras abertas entre si, mesmo sem estar em guerra"). Quando uma
## civilização pede fronteiras abertas ao jogador humano (Diplomacy.request_open_borders), abre um modal com Aceitar /
## Recusar — aceitar abre a fronteira dos dois lados, recusar mantém tudo como está. Mesmo desenho do modal da proposta
## de paz (PeaceOfferPresenter): sem "fechar", sem fila própria (a fonte da verdade são os pedidos pendentes em
## Diplomacy.pending_open_borders_offers), espera o turno do jogador começar e qualquer outro modal fechar, mostra um
## pedido por vez, e o _process só fica ligado enquanto há pedido esperando.

signal offer_presented(proposer: PlayerData)
signal offer_answered(proposer: PlayerData, accepted: bool)

var modal_manager: ModalManager
var _modal: AEModalFrame
var _proposer: PlayerData

func _ready() -> void:
	EventBus.open_borders_offered.connect(_on_open_borders_offered)
	set_process(true) # uma checagem: pedido que já existia antes de a interface nascer (save carregado)

func _on_open_borders_offered(_proposer_player: PlayerData, receiver: PlayerData) -> void:
	if GameManager.is_human_controlled(receiver):
		set_process(true)

func _process(_delta: float) -> void:
	if modal_manager == null or is_offer_open():
		return
	var pending := Diplomacy.pending_open_borders_offers(GameManager.human_player) if GameManager.is_human_controlled(GameManager.human_player) else ([] as Array[PlayerData])
	if pending.is_empty():
		set_process(false)
		return
	if GameManager.state != GameManager.GameState.PLAYING or GameManager.is_turn_processing or modal_manager.is_modal_open():
		return
	_present(pending[0])

func is_offer_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func current_modal() -> AEModalFrame:
	return _modal if is_offer_open() else null

func current_proposer() -> PlayerData:
	return _proposer if is_offer_open() else null

func accept() -> void:
	_answer(true)

func refuse() -> void:
	_answer(false)

func _present(proposer: PlayerData) -> void:
	var frame := AEModalFrame.new()
	frame.name = "OpenBordersOfferModal"
	frame.custom_minimum_size = Vector2(480, 0)
	if not modal_manager.present(frame, false, true): # não cancelável: só Aceitar ou Recusar fecham
		frame.queue_free()
		return
	_modal = frame
	_proposer = proposer
	var realm: String = proposer.civ.civ_name
	frame.set_title("%s pede fronteiras abertas" % realm)
	frame.close_button.visible = false
	var body := frame.body_host
	body.add_child(ContextUI.label("%s quer abrir as fronteiras entre os dois reinos. A decisão é sua." % realm, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	body.add_child(ContextUI.label("Aceitar: as unidades de cada reino passam a entrar no território do outro mesmo em paz (inclusive nas cidades que já fecharam a fronteira). Qualquer um dos dois pode encerrar o acordo depois, na Diplomacia; uma guerra entre vocês também o encerra.", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	body.add_child(ContextUI.label("Recusar: nada muda. %s só volta a pedir daqui a %d turnos." % [realm, Diplomacy.OPEN_BORDERS_PLAYER_REFUSAL_TURNS], UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	body.add_child(buttons)
	var refuse_button := AEButton.new()
	refuse_button.name = "RefuseButton"
	refuse_button.kind = AEButton.Kind.GHOST
	refuse_button.text = "Recusar"
	refuse_button.pressed.connect(refuse)
	buttons.add_child(refuse_button)
	var accept_button := AEButton.new()
	accept_button.name = "AcceptButton"
	accept_button.kind = AEButton.Kind.PRIMARY
	accept_button.text = "Abrir as fronteiras"
	accept_button.pressed.connect(accept)
	buttons.add_child(accept_button)
	offer_presented.emit(proposer)

func _answer(accepted: bool) -> void:
	if not is_offer_open():
		return
	var proposer := _proposer
	_modal = null
	_proposer = null
	modal_manager.dismiss_top(true)
	# A resposta só vale se o pedido ainda existir (uma guerra pode ter começado com o modal aberto).
	if Diplomacy.answer_open_borders_offer(GameManager.human_player, proposer, accepted):
		offer_answered.emit(proposer, accepted)
	set_process(true) # próximo pedido da fila, se houver
