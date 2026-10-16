class_name PeaceOfferPresenter
extends Node

## PROPOSTA DE PAZ AO JOGADOR (2026-10-10, relato do usuário: "quando alguém pede paz a você, ela é aceita
## automaticamente"). Quando uma civilização propõe paz ao jogador humano (Diplomacy.offer_peace), abre um modal com
## Aceitar / Recusar — aceitar começa a trégua, recusar mantém a guerra. O modal não tem "fechar": a proposta só some
## com uma resposta, e enquanto ele está aberto o turno não pode ser encerrado (ModalManager bloqueia a jogada).
##
## Não guarda fila própria: a fonte da verdade são as propostas pendentes em Diplomacy.pending_peace_offers, então
## carregar um save, trocar de partida ou a guerra acabar por outro caminho nunca deixa um modal órfão. As propostas
## nascem no meio do processamento do turno; o modal espera o turno do jogador começar (e qualquer outro modal fechar)
## e mostra uma proposta por vez. O _process só fica ligado enquanto há proposta esperando.

signal offer_presented(proposer: PlayerData)
signal offer_answered(proposer: PlayerData, accepted: bool)

var modal_manager: ModalManager
var _modal: AEModalFrame
var _proposer: PlayerData

func _ready() -> void:
	EventBus.peace_offered.connect(_on_peace_offered)
	set_process(true) # uma checagem: proposta que já existia antes de a interface nascer (save carregado)

func _on_peace_offered(_proposer_player: PlayerData, receiver: PlayerData) -> void:
	if GameManager.is_human_controlled(receiver):
		set_process(true)

func _process(_delta: float) -> void:
	if modal_manager == null or is_offer_open():
		return
	var pending := Diplomacy.pending_peace_offers(GameManager.human_player) if GameManager.is_human_controlled(GameManager.human_player) else ([] as Array[PlayerData])
	if pending.is_empty():
		set_process(false)
		return
	if GameManager.state != GameManager.GameState.PLAYING or GameManager.is_turn_processing or modal_manager.is_modal_open():
		return
	_present(pending[0])

func is_offer_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

## O modal aberto agora (null se nenhum) e de quem é a proposta — usados pelos testes e por quem precisar inspecionar.
func current_modal() -> AEModalFrame:
	return _modal if is_offer_open() else null

func current_proposer() -> PlayerData:
	return _proposer if is_offer_open() else null

func accept() -> void:
	_answer(true)

func refuse() -> void:
	_answer(false)

func _present(proposer: PlayerData) -> void:
	var human := GameManager.human_player
	var frame := AEModalFrame.new()
	frame.name = "PeaceOfferModal"
	frame.custom_minimum_size = Vector2(480, 0)
	if not modal_manager.present(frame, false, true): # não cancelável: só Aceitar ou Recusar fecham
		frame.queue_free()
		return
	_modal = frame
	_proposer = proposer
	frame.set_title("%s propõe paz" % proposer.civ.civ_name)
	frame.close_button.visible = false
	var body := frame.body_host
	body.add_child(ContextUI.label("%s quer encerrar a guerra com você. A decisão é sua." % proposer.civ.civ_name, UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	body.add_child(ContextUI.key_value("Motivo da guerra", String(human.war_reasons.get(proposer, proposer.war_reasons.get(human, "Disputa territorial")))))
	body.add_child(ContextUI.key_value("Cansaço deles", "%d / %d" % [int(proposer.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]))
	body.add_child(ContextUI.key_value("Seu cansaço", "%d / %d" % [int(human.war_weariness), int(Diplomacy.WAR_WEARINESS_MAX)]))
	body.add_child(ContextUI.key_value("Unidades", "você %d · eles %d" % [human.units.size(), proposer.units.size()]))
	body.add_child(ContextUI.label("Aceitar: a guerra acaba e começa uma trégua de %d turnos, em que nenhum dos dois pode declarar guerra." % Diplomacy.TRUCE_TURNS, UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	body.add_child(ContextUI.label("Recusar: a guerra continua. %s só volta a propor paz daqui a %d turnos." % [proposer.civ.civ_name, Diplomacy.PEACE_OFFER_COOLDOWN_TURNS], UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	body.add_child(buttons)
	var refuse_button := AEButton.new()
	refuse_button.name = "RefuseButton"
	refuse_button.kind = AEButton.Kind.DANGER
	refuse_button.text = "Recusar — continuar a guerra"
	refuse_button.pressed.connect(refuse)
	buttons.add_child(refuse_button)
	var accept_button := AEButton.new()
	accept_button.name = "AcceptButton"
	accept_button.kind = AEButton.Kind.PRIMARY
	accept_button.text = "Aceitar a paz"
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
	# A resposta só vale se a proposta ainda existir (a guerra pode ter acabado por outro caminho com o modal aberto).
	if Diplomacy.answer_peace_offer(GameManager.human_player, proposer, accepted):
		offer_answered.emit(proposer, accepted)
	set_process(true) # próxima proposta da fila, se houver
