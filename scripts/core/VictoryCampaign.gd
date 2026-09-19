class_name VictoryCampaign
extends RefCounted

const SUPREMACY := "supremacy"
const TRANSCENDENCE := "transcendence"
const CHANNEL_TURNS := 7
const START_MANA := 400.0
const TURN_MANA := 40.0

static func developed(city: City) -> bool:
	return city.population >= 3 and city.used_building_slots() >= 2

static func supremacy_progress(player: PlayerData, players: Array[PlayerData]) -> float:
	var fulfilled := 0
	var total := maxi(1, players.size() - 1)
	for other in players:
		if other == player:
			continue
		var index := players.find(other)
		if (other.cities.is_empty() and other.units.is_empty()) or player.cities.any(func(c): return c.original_owner_index == index and c.captured_developed):
			fulfilled += 1
	var knowledge := 1.0 if player.researched_techs.has("exercito_supremo") else float(TechDatabase._researched_count_in_tier(9, player.researched_techs)) / 4.0
	return (minf(1, knowledge) + float(fulfilled) / total) / 2.0

static func supremacy_achieved(player: PlayerData, players: Array[PlayerData]) -> bool:
	if not player.researched_techs.has("exercito_supremo"):
		return false
	var conquered := player.cities.filter(func(c): return c.original_owner_index >= 0 and c.original_owner_index != players.find(player) and c.captured_developed).size()
	if conquered < 2 and not VictoryConditions.is_dominance_achieved(player, players):
		return false
	for other in players:
		if other == player or (other.cities.is_empty() and other.units.is_empty()):
			continue
		var index := players.find(other)
		if not player.cities.any(func(c): return c.original_owner_index == index and c.captured_developed):
			return false
	return true

static func supremacy_threat(player: PlayerData, players: Array[PlayerData]) -> bool:
	return player.researched_techs.has("exercito_supremo") and supremacy_progress(player, players) >= 0.8

static func announce_supremacy(player: PlayerData, players: Array[PlayerData]) -> void:
	if supremacy_threat(player, players) and not player.supremacy_announced:
		player.supremacy_announced = true
		EventBus.notify.emit("%s está perto da Supremacia Militar! Retomar suas cidades desenvolvidas conquistadas impede essa vitória." % player.civ.civ_name, "combat")

static func sanctuary(player: PlayerData) -> City:
	var best: City = null
	var best_score := -1
	for city in player.cities:
		if city.buildings.has(VictoryConditions.SANCTUARY_BUILDING_ID):
			var units := candidates(player, city)
			var schools := {}
			for unit in units:
				schools[unit.unit_data.magic_school] = true
			var score := mini(5, units.size()) + (10 if schools.size() >= 2 else 0)
			if score > best_score:
				best_score = score
				best = city
	return best

static func candidates(player: PlayerData, city: City) -> Array[Unit]:
	var result: Array[Unit] = []
	if city:
		for unit in player.units:
			if unit.hp > 0 and unit.unit_data.magic_school != "" and unit.ritual_id == "" and not MagicRuntime.status_active(unit, "silence") and HexMetrics.axial_distance(unit.coord, city.coord) <= 2:
				result.append(unit)
	return result

static func preparations(player: PlayerData, grid: HexGrid) -> Array[String]:
	var missing: Array[String] = []
	if not player.researched_magic.has("transcendencia_arcana"):
		missing.append("Pesquisar Transcendência (duas escolas no N9)")
	if player.completed_rituals.size() < 2:
		missing.append("Concluir dois Grandes Rituais diferentes (%d/2)" % player.completed_rituals.size())
	if VictoryConditions.arcane_nodes_controlled(player, grid) < 3:
		missing.append("Controlar 3 Nódulos Arcanos")
	if player.mana_income_per_turn < 30:
		missing.append("Gerar 30 mana por turno")
	var city := sanctuary(player)
	if city == null:
		missing.append("Construir o Santuário da Transcendência")
	var units := candidates(player, city)
	var schools := {}
	for unit in units:
		schools[unit.unit_data.magic_school] = true
	if units.size() < 5 or schools.size() < 2:
		missing.append("Reunir 5 conjuradores de pelo menos 2 escolas a até 2 hexágonos do Santuário")
	if player.mana < START_MANA:
		missing.append("Reservar 400 mana inicial e 40 por turno")
	return missing

static func transcendence_progress(player: PlayerData, grid: HexGrid) -> float:
	var mastery := 0
	for school in MagicContent.SCHOOLS:
		if MagicDatabase.school_level(school, player.researched_magic) >= 9:
			mastery += 1
	var knowledge := 1.0 if player.researched_magic.has("transcendencia_arcana") else minf(0.8, mastery * 0.4)
	return (knowledge + minf(1, player.completed_rituals.size() / 2.0) + minf(1, VictoryConditions.arcane_nodes_controlled(player, grid) / 3.0) + minf(1, player.mana_income_per_turn / 30.0) + (1.0 if sanctuary(player) else 0.0) + minf(1, player.arcane_ritual_streak / float(CHANNEL_TURNS))) / 6.0

static func start(player: PlayerData, grid: HexGrid) -> bool:
	if player.arcane_ritual_active or not preparations(player, grid).is_empty():
		return false
	var city := sanctuary(player)
	var units := candidates(player, city)
	# Garante diversidade mesmo se os cinco primeiros forem da mesma escola.
	var chosen: Array[Unit] = [units[0]]
	for unit in units:
		if unit.unit_data.magic_school != chosen[0].unit_data.magic_school:
			chosen.append(unit)
			break
	for unit in units:
		if not unit in chosen and chosen.size() < 5:
			chosen.append(unit)
	player.arcane_ritual_units.clear()
	for unit in chosen:
		unit.ritual_id = "transcendence"
		unit.movement_left = 0
		unit.exploring = false
		unit.move_order_target = Unit.NO_MOVE_ORDER
		player.arcane_ritual_units.append(unit.serial_id)
	player.mana -= START_MANA
	player.arcane_ritual_active = true
	player.arcane_ritual_city_coord = city.coord
	player.arcane_ritual_streak = 0
	player.arcane_last_tick = TurnManager.turn_number
	EventBus.notify.emit("%s iniciou a Transcendência em %s (%d, %d). Vitória em 7 turnos se o ritual não for interrompido!" % [player.civ.civ_name, city.city_name, city.coord.x, city.coord.y], "magic")
	return true

static func advance(player: PlayerData, grid: HexGrid) -> void:
	if not player.arcane_ritual_active or player.arcane_last_tick >= TurnManager.turn_number:
		return
	player.arcane_last_tick = TurnManager.turn_number
	var city := grid.get_city_at(player.arcane_ritual_city_coord)
	var failure := ""
	if city == null or city.owner_player != player or not city.buildings.has(VictoryConditions.SANCTUARY_BUILDING_ID):
		failure = "Santuário perdido"
	elif VictoryConditions.arcane_nodes_controlled(player, grid) < 3:
		failure = "Nódulos insuficientes"
	elif player.mana < TURN_MANA:
		failure = "mana insuficiente"
	elif player.arcane_ritual_units.size() != 5:
		failure = "ritualistas insuficientes"
	for id in player.arcane_ritual_units:
		var unit := MagicRuntime.unit_by_id(player, id)
		if unit == null or MagicRuntime.status_active(unit, "silence") or HexMetrics.axial_distance(unit.coord, player.arcane_ritual_city_coord) > 2:
			failure = "ritualista perdido ou silenciado"
	if failure != "":
		player.arcane_ritual_active = false
		player.arcane_ritual_streak = 0
		for unit in player.units:
			if unit.ritual_id == "transcendence":
				unit.ritual_id = ""
		player.arcane_ritual_units.clear()
		EventBus.notify.emit("Transcendência de %s interrompida: %s." % [player.civ.civ_name, failure], "magic")
		return
	player.mana -= TURN_MANA
	player.arcane_ritual_streak += 1
	EventBus.notify.emit("Transcendência de %s: faltam %d turnos." % [player.civ.civ_name, maxi(0, CHANNEL_TURNS - player.arcane_ritual_streak)], "magic")
