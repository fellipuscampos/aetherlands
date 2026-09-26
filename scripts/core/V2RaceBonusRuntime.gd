class_name V2RaceBonusRuntime
extends RefCounted

## Camada semântica única entre os consumidores e o registro racial. Todas as consultas são
## derivadas do race id canônico do PlayerData; null, vazio ou desconhecido são sempre neutros.

static func profile_for(player: PlayerData) -> V2RaceBonusData:
	if player == null or player.civ == null:
		return null
	return profile_for_race(player.civ.race)


static func profile_for_race(race_id: String) -> V2RaceBonusData:
	return V2RaceBonusDatabase.get_profile(race_id)


static func gold_income_multiplier(player: PlayerData) -> float:
	var profile := profile_for(player)
	return profile.gold_income_multiplier if profile != null else 1.0


static func supply_capacity_multiplier(player: PlayerData) -> float:
	var profile := profile_for(player)
	return profile.supply_capacity_multiplier if profile != null else 1.0


static func city_production_multiplier(player: PlayerData) -> float:
	var profile := profile_for(player)
	return profile.city_production_multiplier if profile != null else 1.0


static func knowledge_income_multiplier(player: PlayerData) -> float:
	var profile := profile_for(player)
	return profile.knowledge_income_multiplier if profile != null else 1.0


static func mana_income_multiplier(player: PlayerData) -> float:
	var profile := profile_for(player)
	return profile.mana_income_multiplier if profile != null else 1.0


static func builder_charge_bonus(player: PlayerData) -> int:
	var profile := profile_for(player)
	return profile.builder_charge_bonus if profile != null else 0


static func annexation_point_bonus(player: PlayerData) -> int:
	var profile := profile_for(player)
	return profile.annexation_point_bonus if profile != null else 0


static func combat_attack_multiplier(unit: Unit) -> float:
	if unit == null or not is_instance_valid(unit):
		return 1.0
	var profile := profile_for(unit.owner_player)
	return profile.unit_attack_multiplier if profile != null else 1.0


static func effect_lines(player: PlayerData) -> Array[String]:
	if player == null or player.civ == null:
		return [] as Array[String]
	return V2RaceBonusDatabase.effect_lines(player.civ.race)


static func summary(player: PlayerData) -> String:
	if player == null or player.civ == null:
		return ""
	return V2RaceBonusDatabase.summary(player.civ.race)
