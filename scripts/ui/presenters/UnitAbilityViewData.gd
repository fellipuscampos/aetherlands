class_name UnitAbilityViewData
extends RefCounted

## Dado de apresentação de UMA ação de unidade (comando básico ou habilidade).
## Montado por UnitPresenter a partir dos runtimes; nunca guarda Node nem decide
## disponibilidade — `blocked_reason` é copiado do helper real de cada sistema.

enum State { READY, TARGETING, ACTIVE, COOLDOWN, BLOCKED, PASSIVE }
enum Category { COMMAND, TECHNIQUE, SPELL, PORTAL, RETINUE, UPGRADE, BUILDER, SPECIAL }

var id := ""
var display_name := ""
var description := ""
var category: Category = Category.SPECIAL
var icon_path := ""
var glyph := ""
var accent_color := Color(0, 0, 0, 0)
var state: State = State.READY
var cost_text := ""
var cooldown_current := 0
var cooldown_max := 0
var target_type := ""
var range_value := 0
var hotkey := ""
var blocked_reason := ""
var is_passive := false
var is_toggle := false
var toggled := false
var action_kind := ""
## V3 / Etapa 2: ação primária semântica da unidade (ex.: Fundar Cidade num tile válido) — o botão usa o
## estilo PrimaryButton do design system.
var is_primary := false
var action_arg := ""
var details: Array[String] = []

static func create(ability_id: String, name_value: String, ability_category: Category) -> UnitAbilityViewData:
	var view := UnitAbilityViewData.new()
	view.id = ability_id
	view.display_name = name_value
	view.category = ability_category
	return view

func is_clickable() -> bool:
	return state == State.READY or state == State.TARGETING or (is_toggle and state == State.ACTIVE)

func tooltip() -> String:
	var lines: Array = []
	if not cost_text.is_empty():
		lines.append("Custo: %s" % cost_text)
	if not target_type.is_empty():
		lines.append("Alvo: %s" % target_type)
	if range_value > 0:
		lines.append("Alcance: %d" % range_value)
	if cooldown_max > 0:
		lines.append("Recarga: %d turno%s" % [cooldown_max, "" if cooldown_max == 1 else "s"])
	lines.append_array(details)
	var reason := blocked_reason
	if state == State.COOLDOWN and reason.is_empty():
		reason = "Em recarga: %d turno(s)." % cooldown_current
	return AETooltip.compose(display_name, description, lines, reason if state in [State.BLOCKED, State.COOLDOWN] else "", hotkey)

func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "category": category, "state": state,
		"cost_text": cost_text, "cooldown_current": cooldown_current, "cooldown_max": cooldown_max,
		"target_type": target_type, "range": range_value, "blocked_reason": blocked_reason,
		"is_passive": is_passive, "action_kind": action_kind, "action_arg": action_arg,
	}
