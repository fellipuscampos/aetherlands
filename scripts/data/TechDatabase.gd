class_name TechDatabase
extends RefCounted

## Arvore de tecnologia pequena mas de verdade: 11 tecnologias, algumas com
## pre-requisito (Equitacao pede Pecuaria; Irrigacao pede Agricultura;
## Metalurgia pede Mineracao; Engenharia pede Metalurgia; Adestramento de
## Grifos pede Equitacao). Cada uma desbloqueia uma unidade (Arqueiro/
## Cavaleiro/Catapulta/Mago/Grifo/Ent, antes disponiveis desde o inicio sem
## custar nada) ou da bonus de rendimento em
## biomas especificos — assim pesquisar continua valendo a pena mesmo
## depois de ja ter as unidades novas. Pesquisa e paga com "ciencia" = soma
## da populacao das cidades por turno (ver GameManager._process_research) —
## simples de proposito, sem introduzir mais um tipo de yield em
## HexTileData.

static var _cache: Dictionary = {} # id -> TechData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var techs: Dictionary = {}

	var agriculture := TechData.new()
	agriculture.id = "agriculture"
	agriculture.display_name = "Agricultura"
	agriculture.cost = 20.0
	agriculture.bonus_terrain_types = [HexTileData.TerrainType.GRASSLAND, HexTileData.TerrainType.PLAINS]
	agriculture.bonus_food = 1
	techs[agriculture.id] = agriculture

	var mining := TechData.new()
	mining.id = "mining"
	mining.display_name = "Mineracao"
	mining.cost = 25.0
	mining.bonus_terrain_types = [HexTileData.TerrainType.HILLS, HexTileData.TerrainType.MOUNTAINS]
	mining.bonus_production = 1
	techs[mining.id] = mining

	var archery := TechData.new()
	archery.id = "archery"
	archery.display_name = "Tiro com Arco"
	archery.cost = 25.0
	archery.unlocks_unit = "archer"
	techs[archery.id] = archery

	var animal_husbandry := TechData.new()
	animal_husbandry.id = "animal_husbandry"
	animal_husbandry.display_name = "Pecuaria"
	animal_husbandry.cost = 20.0
	animal_husbandry.bonus_terrain_types = [HexTileData.TerrainType.SAVANNA, HexTileData.TerrainType.TUNDRA]
	animal_husbandry.bonus_food = 1
	techs[animal_husbandry.id] = animal_husbandry

	var horseback_riding := TechData.new()
	horseback_riding.id = "horseback_riding"
	horseback_riding.display_name = "Equitacao"
	horseback_riding.cost = 35.0
	horseback_riding.prerequisites = ["animal_husbandry"]
	horseback_riding.unlocks_unit = "cavalry"
	techs[horseback_riding.id] = horseback_riding

	var irrigation := TechData.new()
	irrigation.id = "irrigation"
	irrigation.display_name = "Irrigacao"
	irrigation.cost = 40.0
	irrigation.prerequisites = ["agriculture"]
	irrigation.bonus_terrain_types = [HexTileData.TerrainType.DESERT]
	irrigation.bonus_food = 1
	techs[irrigation.id] = irrigation

	var metalworking := TechData.new()
	metalworking.id = "metalworking"
	metalworking.display_name = "Metalurgia"
	metalworking.cost = 45.0
	metalworking.prerequisites = ["mining"]
	metalworking.bonus_terrain_types = [
		HexTileData.TerrainType.FOREST, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.JUNGLE,
	]
	metalworking.bonus_production = 1
	techs[metalworking.id] = metalworking

	var engineering := TechData.new()
	engineering.id = "engineering"
	engineering.display_name = "Engenharia"
	engineering.cost = 50.0
	engineering.prerequisites = ["metalworking"]
	engineering.unlocks_unit = "catapult"
	techs[engineering.id] = engineering

	var arcane_studies := TechData.new()
	arcane_studies.id = "arcane_studies"
	arcane_studies.display_name = "Arcanismo"
	arcane_studies.cost = 45.0
	arcane_studies.unlocks_unit = "mage"
	techs[arcane_studies.id] = arcane_studies

	var griffin_training := TechData.new()
	griffin_training.id = "griffin_training"
	griffin_training.display_name = "Adestramento de Grifos"
	griffin_training.cost = 55.0
	griffin_training.prerequisites = ["horseback_riding"]
	griffin_training.unlocks_unit = "griffin"
	techs[griffin_training.id] = griffin_training

	var druidism := TechData.new()
	druidism.id = "druidism"
	druidism.display_name = "Druidismo"
	druidism.cost = 40.0
	druidism.unlocks_unit = "treant"
	techs[druidism.id] = druidism

	return techs

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_tech(id: String) -> TechData:
	return _all().get(id, null)

static func all_techs() -> Array:
	return _all().values()

## Tecnologias ainda nao pesquisadas cujos pre-requisitos ja foram TODOS
## cumpridos — e o que aparece pra escolher como proxima pesquisa.
static func available_techs(researched: Dictionary) -> Array:
	var result := []
	for tech in all_techs():
		if researched.has(tech.id):
			continue
		var ok := true
		for prereq in tech.prerequisites:
			if not researched.has(prereq):
				ok = false
				break
		if ok:
			result.append(tech)
	return result

## Guerreiro/Colonizador sempre liberados; o resto depende de qual
## tecnologia declara `unlocks_unit == kind` ter sido pesquisada. Kind sem
## nenhuma tecnologia associada tambem fica liberado por padrao (fail-open
## — nao trava um tipo de unidade novo que ainda nao ganhou tech propria).
static func is_unit_unlocked(kind: String, researched: Dictionary) -> bool:
	if kind == "settler" or kind == "warrior":
		return true
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return researched.has(tech.id)
	return true

## Tecnologia cujo unlocks_unit bate com `kind`, ou null se nenhuma
## tecnologia trava esse kind (Colonizador/Guerreiro) — usado so pra
## mostrar qual pesquisa falta num tooltip (HUD._production_lock_reason)
## e por City._tech_unlocked_for_building() pra saber se um predio de
## treino ja pode ser construido. kind == "" tem que devolver null
## explicitamente ANTES do loop: `TechData.unlocks_unit` tambem default
## pra "" nas tecnologias que nao desbloqueiam unidade nenhuma
## (Agricultura, Mineracao...), entao sem essa guarda
## `tech_that_unlocks("")` "encontraria" a primeira tech de bioma da
## lista por acidente (ex: exigiria Agricultura pra construir o Celeiro,
## que nao trava tropa nenhuma — BuildingData.trains_unit == "").
static func tech_that_unlocks(kind: String) -> TechData:
	if kind == "":
		return null
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return tech
	return null

## Soma os bonus de TODAS as tecnologias pesquisadas que afetam este bioma
## — varias tecnologias podem mirar o mesmo terreno.
static func yield_bonus_for(terrain_type: int, researched: Dictionary) -> Dictionary:
	var bonus = {"food": 0, "production": 0, "gold": 0}
	for id in researched.keys():
		var tech: TechData = get_tech(id)
		if tech and terrain_type in tech.bonus_terrain_types:
			bonus.food += tech.bonus_food
			bonus.production += tech.bonus_production
			bonus.gold += tech.bonus_gold
	return bonus
