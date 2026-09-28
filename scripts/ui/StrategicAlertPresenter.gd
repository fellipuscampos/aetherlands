class_name StrategicAlertPresenter
extends HBoxContainer

signal destination_requested(destination: StringName)

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
	if _compact and not definitions.is_empty():
		definitions.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.rank) < int(b.rank))
		var primary: Dictionary = definitions[0]
		_add_alert("Alertas · %d" % definitions.size(), primary.color, primary.destination)
		return
	for definition in definitions:
		_add_alert(definition.text, definition.color, definition.destination)

func _add_alert(text_value: String, color: Color, destination: StringName) -> void:
	var button := AEButton.new()
	button.kind = AEButton.Kind.GHOST
	button.text = text_value
	button.add_theme_color_override("font_color", color)
	button.pressed.connect(func(): destination_requested.emit(destination))
	add_child(button)
