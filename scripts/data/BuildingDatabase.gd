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
## Duas familias: predios de RENDIMENTO/DEFESA (Celeiro/Oficina/Mercado/
## Muralhas, `trains_unit` vazio) e predios de TREINO (Quartel em diante,
## `trains_unit` preenchido) — cada tropa de combate so pode ser produzida
## se a cidade ja tiver o predio de treino correspondente (City.can_train(),
## pedido do usuario: "cada tropa e feita numa construcao... so pode
## treinar as tropas na sua respectiva construcao"). Colonizador fica de
## fora dessa regra (nao e uma tropa de combate, sempre disponivel).
##
## Cadeia de 3 passos pro resto do elenco (pedido do usuario, rodada
## seguinte: "so posso construir esses predios especiais quando pesquisar
## a tecnologia, ai aparece disponivel pra construir, e consequentemente
## as tropas poderao ser treinadas nela"): pesquisar a tecnologia que
## desbloqueia a tropa (TechData.unlocks_unit) e o que libera CONSTRUIR o
## predio de treino correspondente (City._tech_unlocked_for_building,
## derivado achando `TechDatabase.tech_that_unlocks(building.trains_unit)`
## — sem precisar duplicar o mapeamento tropa->tecnologia aqui), so entao
## o predio (uma vez construido) libera TREINAR a tropa (City.can_train()).
## Quartel fica de fora do primeiro passo porque Guerreiro nunca exigiu
## pesquisa nenhuma (tech_that_unlocks("warrior") == null).
##
## Escopo desta rodada: so a cidade do JOGADOR constroi predios —
## RivalAI.decide_production continua so escolhendo entre unidades
## direto (ver MILITARY_KINDS), sem passar pelo gate de predio de treino;
## dar essa mesma restricao pra IA exigiria ensinar ela a priorizar QUAL
## predio construir primeiro, o que esse pass nao cobre.

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

	var barracks := BuildingData.new()
	barracks.id = "barracks"
	barracks.display_name = "Quartel"
	barracks.production_cost = 20.0
	barracks.trains_unit = "warrior"
	buildings[barracks.id] = barracks

	var archery_range := BuildingData.new()
	archery_range.id = "archery_range"
	archery_range.display_name = "Campo de Tiro"
	archery_range.production_cost = 22.0
	archery_range.trains_unit = "archer"
	buildings[archery_range.id] = archery_range

	var stable := BuildingData.new()
	stable.id = "stable"
	stable.display_name = "Estabulo"
	stable.production_cost = 26.0
	stable.trains_unit = "cavalry"
	buildings[stable.id] = stable

	var siege_workshop := BuildingData.new()
	siege_workshop.id = "siege_workshop"
	siege_workshop.display_name = "Arsenal de Cerco"
	siege_workshop.production_cost = 32.0
	siege_workshop.trains_unit = "catapult"
	buildings[siege_workshop.id] = siege_workshop

	var arcane_tower := BuildingData.new()
	arcane_tower.id = "arcane_tower"
	arcane_tower.display_name = "Torre Arcana"
	arcane_tower.production_cost = 30.0
	arcane_tower.trains_unit = "mage"
	buildings[arcane_tower.id] = arcane_tower

	var griffin_roost := BuildingData.new()
	griffin_roost.id = "griffin_roost"
	griffin_roost.display_name = "Poleiro de Grifos"
	griffin_roost.production_cost = 38.0
	griffin_roost.trains_unit = "griffin"
	buildings[griffin_roost.id] = griffin_roost

	var druid_grove := BuildingData.new()
	druid_grove.id = "druid_grove"
	druid_grove.display_name = "Bosque Druida"
	druid_grove.production_cost = 32.0
	druid_grove.trains_unit = "treant"
	buildings[druid_grove.id] = druid_grove

	return buildings

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_building(id: String) -> BuildingData:
	return _all().get(id, null)

static func all_buildings() -> Array:
	return _all().values()

## Predio de treino cujo trains_unit bate com `kind` (ex: "warrior" ->
## Quartel), ou null se `kind` nao exige nenhum predio especifico (ex:
## "settler") — ver City.can_train().
static func building_that_trains(kind: String) -> BuildingData:
	for b in all_buildings():
		if b.trains_unit == kind:
			return b
	return null

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
