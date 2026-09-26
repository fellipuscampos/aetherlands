class_name V2RaceBonusData
extends Resource

## Perfil mecânico racial. Só os campos usados pela Fase 26 existem aqui; 1.0/0 são neutros.
## O objeto é conteúdo imutável compartilhado. Nenhum valor efetivo é gravado em PlayerData.
@export var race_id: String = ""
@export var summary: String = ""
@export var gold_income_multiplier: float = 1.0
@export var supply_capacity_multiplier: float = 1.0
@export var city_production_multiplier: float = 1.0
@export var knowledge_income_multiplier: float = 1.0
@export var mana_income_multiplier: float = 1.0
@export var unit_attack_multiplier: float = 1.0
@export var builder_charge_bonus: int = 0
@export var annexation_point_bonus: int = 0


func active_bonus_keys() -> Array[String]:
	var result: Array[String] = []
	if not is_equal_approx(gold_income_multiplier, 1.0):
		result.append("gold_income")
	if not is_equal_approx(supply_capacity_multiplier, 1.0):
		result.append("supply_capacity")
	if not is_equal_approx(city_production_multiplier, 1.0):
		result.append("city_production")
	if not is_equal_approx(knowledge_income_multiplier, 1.0):
		result.append("knowledge_income")
	if not is_equal_approx(mana_income_multiplier, 1.0):
		result.append("mana_income")
	if not is_equal_approx(unit_attack_multiplier, 1.0):
		result.append("unit_attack")
	if builder_charge_bonus != 0:
		result.append("builder_charges")
	if annexation_point_bonus != 0:
		result.append("annexation_points")
	return result
