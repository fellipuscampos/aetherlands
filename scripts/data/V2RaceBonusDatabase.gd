class_name V2RaceBonusDatabase
extends RefCounted

## Fonte única dos bônus raciais da Fase 26. As magnitudes são BALANCE PLACEHOLDER.
## IDs concretos de raça ficam somente neste registro e no roster/setup visual preexistente.

static var _by_race: Dictionary = {}


static func _profile(race_id: String, summary: String, values: Dictionary) -> V2RaceBonusData:
	var profile := V2RaceBonusData.new()
	profile.race_id = race_id
	profile.summary = summary
	for key in values:
		profile.set(key, values[key])
	return profile


static func _ensure_built() -> void:
	if not _by_race.is_empty():
		return
	var profiles := [
		_profile("human", "Organização e expansão disciplinada.", {
			"builder_charge_bonus": 1,
			"annexation_point_bonus": 1,
		}),
		_profile("elf", "Erudição e afinidade com o Aether.", {
			"knowledge_income_multiplier": 1.10,
			"mana_income_multiplier": 1.10,
		}),
		_profile("dwarf", "Prosperidade mineral e indústria eficiente.", {
			"gold_income_multiplier": 1.10,
			"city_production_multiplier": 1.10,
		}),
		_profile("orc", "Hordas numerosas e força ofensiva.", {
			"supply_capacity_multiplier": 1.10,
			"unit_attack_multiplier": 1.05,
		}),
	]
	for profile in profiles:
		_by_race[profile.race_id] = profile


static func get_profile(race_id: String) -> V2RaceBonusData:
	_ensure_built()
	return _by_race.get(race_id, null)


static func race_ids() -> Array[String]:
	_ensure_built()
	var result: Array[String] = []
	for race_id in _by_race.keys():
		result.append(String(race_id))
	result.sort()
	return result


static func all_profiles() -> Array[V2RaceBonusData]:
	_ensure_built()
	var result: Array[V2RaceBonusData] = []
	for race_id in race_ids():
		result.append(_by_race[race_id])
	return result


static func effect_lines(race_id: String) -> Array[String]:
	var profile := get_profile(race_id)
	var lines: Array[String] = []
	if profile == null:
		return lines
	if not is_equal_approx(profile.gold_income_multiplier, 1.0):
		lines.append("+%d%% de Ouro gerado por cidades e melhorias." % _bonus_percent(profile.gold_income_multiplier))
	if not is_equal_approx(profile.supply_capacity_multiplier, 1.0):
		lines.append("+%d%% de capacidade total de Suprimentos." % _bonus_percent(profile.supply_capacity_multiplier))
	if not is_equal_approx(profile.city_production_multiplier, 1.0):
		lines.append("+%d%% de Produção local das cidades." % _bonus_percent(profile.city_production_multiplier))
	if not is_equal_approx(profile.knowledge_income_multiplier, 1.0):
		lines.append("+%d%% de Conhecimento gerado por turno." % _bonus_percent(profile.knowledge_income_multiplier))
	if not is_equal_approx(profile.mana_income_multiplier, 1.0):
		lines.append("+%d%% de Mana gerada por turno." % _bonus_percent(profile.mana_income_multiplier))
	if not is_equal_approx(profile.unit_attack_multiplier, 1.0):
		lines.append("+%d%% de Ataque para todas as unidades." % _bonus_percent(profile.unit_attack_multiplier))
	if profile.builder_charge_bonus != 0:
		lines.append("+%d carga para novos Construtores." % profile.builder_charge_bonus)
	if profile.annexation_point_bonus != 0:
		lines.append("+%d Ponto de Anexação ao evoluir uma cidade." % profile.annexation_point_bonus)
	return lines


static func summary(race_id: String) -> String:
	var profile := get_profile(race_id)
	return profile.summary if profile != null else ""


static func _bonus_percent(multiplier: float) -> int:
	return int(round((multiplier - 1.0) * 100.0))
