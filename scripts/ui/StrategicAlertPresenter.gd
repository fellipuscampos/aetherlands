class_name StrategicAlertPresenter
extends HBoxContainer

signal destination_requested(destination: StringName)
## Fase 33D2: chip de objetivo do mundo com alvo no mapa (ex.: "Ameaça regional").
signal location_requested(coord: Vector2i)
## Fase 33D3: teto de chips de objetivo do mundo (arquitetura aprovada na F33C).
const MAX_OBJECTIVE_CHIPS := 2

var _player: PlayerData
var _compact := false

func _ready() -> void:
	add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	mouse_filter = Control.MOUSE_FILTER_PASS

func bind_player(player: PlayerData) -> void:
	_player = player
	refresh()

func set_compact(value: bool) -> void:
	_compact = value
	refresh()

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	if _player == null:
		return
	var definitions: Array[Dictionary] = []
	var wars := 0
	for rival in GameManager.rival_players:
		if _player.is_at_war_with(rival):
			wars += 1
	if wars > 0:
		definitions.append({"text": "Em guerra · %d" % wars, "color": UIThemeTokens.COLOR_CRITICAL, "destination": NavigationManager.DIPLOMACY, "rank": 2})
	if V2EconomyRuntime.is_gold_deficit(_player):
		definitions.append({"text": "Déficit", "color": UIThemeTokens.COLOR_CRITICAL, "destination": &"city_summary", "rank": 3})
	if V2LogisticsRuntime.is_logistically_strained(_player):
		definitions.append({"text": "Tensão", "color": UIThemeTokens.COLOR_WARNING, "destination": &"city_summary", "rank": 4})
	for rival in GameManager.rival_players:
		if V2TranscendenceSystem.has_active_ritual(rival):
			var rounds := V2TranscendenceSystem.ritual_rounds_remaining(rival)
			definitions.append({"text": "Ritual %dT" % rounds, "color": UIThemeTokens.COLOR_CRITICAL if rounds <= 1 else UIThemeTokens.COLOR_WARNING, "destination": NavigationManager.VICTORY, "rank": 1 if rounds <= 1 else 5})
	# Fases 33D2/33D3: chips de OBJETIVO do mundo — no máximo MAX_OBJECTIVE_CHIPS, e um Ritual rival (emergência)
	# ocupa vaga antes deles. Ordem: Relicário ativo, ameaça regional descoberta, próximo passo (só na Convergência).
	var objectives: Array[Dictionary] = []
	var reliquary := WorldEventManager.active_event_of_type(ReliquaryEvent.EVENT_TYPE) as ReliquaryEvent
	if reliquary != null and reliquary.is_open() and reliquary.phase != WorldEvent.PHASE_DORMANT:
		objectives.append({"text": "Relicário Desperto", "color": UIThemeTokens.COLOR_WARNING, "destination": &"reliquary", "rank": 6, "coord": reliquary.site_coord})
	for objective in RegionalThreatSystem.objectives_for(_player):
		if String(objective.status) == "active":
			objectives.append({"text": String(objective.title), "color": UIThemeTokens.COLOR_WARNING, "destination": &"world_threat", "rank": 6, "coord": objective.target})
			break
	if WorldEventManager.world_phase == WorldPhaseRules.Phase.CONVERGENCE:
		var headline := StrategicImperatives.headline(_player)
		if not headline.is_empty() and String(headline.get("step", "")) != "done":
			var chip := {"text": "Próximo passo", "color": UIThemeTokens.COLOR_ACCENT, "destination": NavigationManager.VICTORY, "rank": 7, "tooltip": String(headline.next)}
			objectives.append(chip)
	var emergencies := definitions.filter(func(d: Dictionary) -> bool: return String(d.text).begins_with("Ritual")).size()
	for objective in objectives.slice(0, maxi(0, MAX_OBJECTIVE_CHIPS - emergencies)):
		definitions.append(objective)
	if _compact and not definitions.is_empty():
		definitions.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.rank) < int(b.rank))
		var primary: Dictionary = definitions[0]
		_add_alert("Alertas · %d" % definitions.size(), primary.color, primary.destination, primary.get("coord", null))
		return
	for definition in definitions:
		_add_alert(definition.text, definition.color, definition.destination, definition.get("coord", null))
		if definition.has("tooltip"):
			(get_child(get_child_count() - 1) as Control).tooltip_text = String(definition.tooltip)

func _add_alert(text_value: String, color: Color, destination: StringName, coord: Variant = null) -> void:
	var button := AEButton.new()
	button.kind = AEButton.Kind.GHOST
	button.text = text_value
	button.add_theme_color_override("font_color", color)
	if coord is Vector2i:
		var target: Vector2i = coord
		button.pressed.connect(func(): location_requested.emit(target))
	else:
		button.pressed.connect(func(): destination_requested.emit(destination))
	add_child(button)
