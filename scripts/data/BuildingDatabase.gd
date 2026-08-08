class_name BuildingDatabase
extends RefCounted

## Predios de cidade: entram na MESMA fila de producao das unidades —
## City.production_item aceita tanto um kind de UnitDatabase quanto um id
## daqui (ver City.production_cost()/process_turn(), que checam este
## database primeiro). Diferente de unidade, completar um predio nao
## "gasta" nada: fica valendo pra sempre (bonus permanente em
## City.collect_yields(), ou bonus de defesa em CombatResolver.predict()
## pra Muralhas), e cada cidade so constroi cada predio UMA vez
## (City.buildings, Dictionary id->true).
##
## Escopo desta rodada: so a cidade do JOGADOR constroi predios —
## RivalAI.decide_production continua so escolhendo entre unidades. Dar
## predios pra IA tambem exigiria uma heuristica de priorizacao (quando
## vale mais construir Celeiro do que outro Guerreiro?) que esse pass nao
## cobre.

static var _cache: Dictionary = {} # id -> BuildingData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var buildings: Dictionary = {}

	var granary := BuildingData.new()
	granary.id = "granary"
	granary.display_name = "Celeiro"
	granary.production_cost = 20.0
	granary.bonus_food = 2
	buildings[granary.id] = granary

	var workshop := BuildingData.new()
	workshop.id = "workshop"
	workshop.display_name = "Oficina"
	workshop.production_cost = 25.0
	workshop.bonus_production = 2
	buildings[workshop.id] = workshop

	var market := BuildingData.new()
	market.id = "market"
	market.display_name = "Mercado"
	market.production_cost = 25.0
	market.bonus_gold = 2
	buildings[market.id] = market

	var walls := BuildingData.new()
	walls.id = "walls"
	walls.display_name = "Muralhas"
	walls.production_cost = 30.0
	walls.defense_bonus = 0.5
	buildings[walls.id] = walls

	return buildings

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_building(id: String) -> BuildingData:
	return _all().get(id, null)

static func all_buildings() -> Array:
	return _all().values()

## Soma o bonus de TODOS os predios ja construidos (built = City.buildings).
static func total_bonus(built: Dictionary) -> Dictionary:
	var bonus = {"food": 0, "production": 0, "gold": 0}
	for id in built.keys():
		var b: BuildingData = get_building(id)
		if b:
			bonus.food += b.bonus_food
			bonus.production += b.bonus_production
			bonus.gold += b.bonus_gold
	return bonus

static func defense_bonus_for(built: Dictionary) -> float:
	var total := 0.0
	for id in built.keys():
		var b: BuildingData = get_building(id)
		if b:
			total += b.defense_bonus
	return total
