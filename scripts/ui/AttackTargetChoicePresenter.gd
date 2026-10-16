class_name AttackTargetChoicePresenter
extends Node

## ESCOLHER O ALVO DO ATAQUE (2026-10-13, pedido do usuário: "se tem um inimigo em cima de alguma guarnição que tem
## vida, nesse exemplo a cidade, ao tentar atacar aquele tile eu acabo atacando o inimigo, o que pode ser usado como
## técnica para proteger a cidade. Faça que caso tenha uma tropa acima, eu possa escolher em quem estou atacando, a
## cidade ou a tropa"). Quando o jogador ataca um tile que tem uma tropa E uma cidade atacáveis
## (SelectionManager -> EventBus.attack_target_choice_requested), abre um modal com os dois alvos e o resultado
## estimado de cada golpe, e devolve a escolha ao SelectionManager:
##  - Atacar a tropa / Atacar a cidade: o ataque acontece contra o alvo escolhido;
##  - Cancelar / fechar / ESC: nada acontece e a unidade continua com a ação.
## Não guarda regra nem estado de jogo: o tile pendente vive em SelectionManager.attack_choice_coord e as estimativas
## vêm de CombatResolver.predict / predict_city_attack (as mesmas contas do ataque de verdade).

signal choice_presented(attacker: Unit, coord: Vector2i)

var modal_manager: ModalManager
var _modal: AEModalFrame

func _ready() -> void:
	EventBus.attack_target_choice_requested.connect(_on_choice_requested)
	if modal_manager != null:
		modal_manager.modal_closed.connect(_on_modal_closed)

func is_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func current_modal() -> AEModalFrame:
	return _modal if is_open() else null

func choose_unit() -> void:
	_choose(SelectionManager.ATTACK_TARGET_UNIT)

func choose_city() -> void:
	_choose(SelectionManager.ATTACK_TARGET_CITY)

func cancel() -> void:
	if not is_open():
		return
	_close()
	SelectionManager.decline_attack_target()

func _choose(target: String) -> void:
	if not is_open():
		return
	_close()
	SelectionManager.choose_attack_target(target)

func _close() -> void:
	_modal = null # antes do dismiss: _on_modal_closed não trata esta saída como um cancelamento por ESC
	modal_manager.dismiss_top(true)

## ESC (ou qualquer outro caminho que feche o modal sem passar pelos botões) vale como cancelar o ataque.
func _on_modal_closed(modal: Control) -> void:
	if _modal != null and modal == _modal:
		_modal = null
		SelectionManager.decline_attack_target()

func _on_choice_requested(attacker: Unit, coord: Vector2i) -> void:
	var hex_grid := GameManager.hex_grid
	var targets := SelectionManager.attack_targets_at(attacker, coord, hex_grid) if hex_grid != null else {}
	if modal_manager == null or targets.is_empty() or targets.unit == null or targets.city == null:
		SelectionManager.choose_attack_target("") # sem ter como (ou o que) perguntar: vale o alvo de sempre
		return
	var frame := AEModalFrame.new()
	frame.name = "AttackTargetChoiceModal"
	frame.custom_minimum_size = Vector2(500, 0)
	if not modal_manager.present(frame, true, true):
		frame.queue_free()
		SelectionManager.decline_attack_target()
		return
	_modal = frame
	var unit: Unit = targets.unit
	var city: City = targets.city
	frame.set_title("Atacar quem?")
	frame.close_requested.connect(cancel)
	var body := frame.body_host
	body.add_child(ContextUI.label("%s está guarnecendo %s. Escolha o alvo deste ataque de %s." % [unit.unit_data.unit_name, city.city_name, attacker.unit_data.unit_name], UIThemeTokens.FONT_BODY_SMALL, UIThemeTokens.COLOR_TEXT))
	body.add_child(ContextUI.key_value("Tropa — %s" % unit.unit_data.unit_name, unit_forecast(attacker, unit, hex_grid)))
	body.add_child(ContextUI.key_value("Cidade — %s" % city.city_name, city_forecast(attacker, city)))
	body.add_child(ContextUI.label("A cidade não revida. Se ela cair com a tropa dentro, a guarnição recua para o tile livre mais próximo.", UIThemeTokens.FONT_CAPTION, UIThemeTokens.COLOR_TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	body.add_child(buttons)
	var cancel_button := AEButton.new()
	cancel_button.name = "CancelButton"
	cancel_button.kind = AEButton.Kind.GHOST
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(cancel)
	buttons.add_child(cancel_button)
	var unit_button := AEButton.new()
	unit_button.name = "AttackUnitButton"
	unit_button.kind = AEButton.Kind.DANGER
	unit_button.text = "Atacar a tropa"
	unit_button.pressed.connect(choose_unit)
	buttons.add_child(unit_button)
	var city_button := AEButton.new()
	city_button.name = "AttackCityButton"
	city_button.kind = AEButton.Kind.DANGER
	city_button.text = "Atacar a cidade"
	city_button.pressed.connect(choose_city)
	buttons.add_child(city_button)
	cancel_button.call_deferred("grab_focus")
	choice_presented.emit(attacker, coord)

## "Vida 12/18 · golpe causa 6 · você sofre 2" (+ o desfecho, quando alguém morre) — CombatResolver.predict.
static func unit_forecast(attacker: Unit, unit: Unit, hex_grid: HexGrid) -> String:
	var result := CombatResolver.predict(attacker, unit, hex_grid)
	var text := "Vida %d/%d · golpe causa %d" % [int(ceil(unit.hp)), int(unit.unit_data.max_hp), int(round(float(result.damage_to_defender)))]
	if bool(result.defender_dies):
		return text + " · derrota a tropa"
	if float(result.damage_to_attacker) > 0.0:
		text += " · você sofre %d" % int(round(float(result.damage_to_attacker)))
	if bool(result.attacker_dies):
		text += " · sua unidade morre"
	return text

## "Escudo 4/10 · Vida 20/30 · golpe causa 6" (+ "captura a cidade") — CombatResolver.predict_city_attack.
static func city_forecast(attacker: Unit, city: City) -> String:
	var result := CombatResolver.predict_city_attack(attacker, city)
	var parts: Array[String] = []
	if city.max_shield() > 0.0:
		parts.append("Escudo %d/%d" % [int(ceil(city.shield)), int(city.max_shield())])
	parts.append("Vida %d/%d" % [int(ceil(city.hp)), int(city.max_hp())])
	parts.append("golpe causa %d" % int(round(float(result.damage))))
	if bool(result.captures):
		parts.append("captura a cidade")
	return " · ".join(parts)
