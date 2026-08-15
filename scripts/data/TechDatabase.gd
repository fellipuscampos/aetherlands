class_name TechDatabase
extends RefCounted

## Arvore de tecnologia MAGICA (pivot pedido pelo usuario: "deixe de ser uma
## arvore Generica/Historica... e se torne um sistema focado em MAGIA,
## FANTASIA E MANIPULACAO DO MUNDO" — substitui a arvore anterior de
## Agricultura/Mineracao/Irrigacao inteira). 12 tecnologias em 4 tiers:
##
## TIER 0 (bases elementares, sem pre-requisito): Canalizacao da Trama
## (arcanismo puro, raiz de Invocacao de Espiritos), Alquimia Botanica
## (vegetacao encantada) e Transmutacao de Rochas (forja elemental) — as
## duas ultimas sao a raiz das duas "escolas" de bioma (floresta/gelo vs.
## colina/deserto) que se ramificam no Tier 1.
## TIER 1 (especializacoes): Invocacao de Espiritos (Mago Arcano), Pacto
## Florestal (Ent), Forja Runica (Golem de Pedra) e Geomancia (bonus de
## deserto/savana).
## TIER 2 (avancadas): Lordes dos Ventos (Grifo), Necromancia Pratica
## (Convocador de Sombras) e Constructos de Guerra (Catapulta Cadenciada).
## TIER 3 (rituais supremos): Cataclismo Elemental e Transcendencia
## Florestal — puramente rituais/feiticos por enquanto (ver TechData.
## unlocks_spell/terrain_transform), sem unidade nem bonus de bioma novo.
##
## Limitacao conhecida (documentada de proposito em vez de fingir que
## funciona): "Canalizacao da Trama" e descrita no pedido original como
## "+1 Comida/Producao na CAPITAL", mas o mecanismo de bonus existente
## (bonus_terrain_types, ver yield_bonus_for) so sabe mirar um BIOMA, nao
## um tile especifico — implementar bonus exclusivo da capital exigiria
## logica nova em City.gd, fora do escopo desta rodada (so TechData/
## TechDatabase/TechTree). Por ora essa tech fica sem bonus_food/
## bonus_production numerico — o valor dela hoje e ser a raiz de
## Invocacao de Espiritos. unlocks_spell e terrain_transform (Tier 3) sao
## registros de DADOS pro mesmo motivo: nenhuma logica de HexGrid/City
## consome isso ainda, fica pronto pra um passe futuro ligar de verdade.
##
## Pesquisa e paga com "ciencia" = soma da populacao das cidades por turno
## (ver GameManager._process_research) — simples de proposito, sem
## introduzir mais um tipo de yield em HexTileData. Isso nao mudou.

static var _cache: Dictionary = {} # id -> TechData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var techs: Dictionary = {}

	var canalizacao_base := TechData.new()
	canalizacao_base.id = "canalizacao_base"
	canalizacao_base.display_name = "Canalização da Trama"
	canalizacao_base.cost = 25.0
	canalizacao_base.school = "Arcanismo"
	canalizacao_base.description = "Os primeiros sábios aprendem a sentir os fios invisíveis que tecem o mundo — a Trama — e a puxá-los sem se queimar. Ergue a Torre dos Sábios, primeiro posto de estudo arcano da civilização."
	techs[canalizacao_base.id] = canalizacao_base

	var alquimia_botanica := TechData.new()
	alquimia_botanica.id = "alquimia_botanica"
	alquimia_botanica.display_name = "Alquimia Botânica"
	alquimia_botanica.cost = 20.0
	alquimia_botanica.bonus_terrain_types = [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.JUNGLE, HexTileData.TerrainType.TUNDRA]
	alquimia_botanica.bonus_food = 1
	alquimia_botanica.school = "Alquimia"
	alquimia_botanica.description = "Poções e enzimas alquímicas aceleram a seiva das plantas e prolongam o verão nas folhas — florestas, selvas e até a tundra gelada aprendem a florescer fora de época."
	techs[alquimia_botanica.id] = alquimia_botanica

	var transmutacao_rocha := TechData.new()
	transmutacao_rocha.id = "transmutacao_rocha"
	transmutacao_rocha.display_name = "Transmutação de Rochas"
	transmutacao_rocha.cost = 25.0
	transmutacao_rocha.bonus_terrain_types = [HexTileData.TerrainType.HILLS, HexTileData.TerrainType.MOUNTAINS]
	transmutacao_rocha.bonus_production = 1
	transmutacao_rocha.school = "Transmutação"
	transmutacao_rocha.description = "A pedra bruta é convencida, átomo a átomo, a ceder seus veios de minério — colinas e montanhas rendem mais sob o cinzel de um transmutador treinado."
	techs[transmutacao_rocha.id] = transmutacao_rocha

	var invocacao_espiritos := TechData.new()
	invocacao_espiritos.id = "invocacao_espiritos"
	invocacao_espiritos.display_name = "Invocação de Espíritos"
	invocacao_espiritos.cost = 40.0
	invocacao_espiritos.prerequisites = ["canalizacao_base"]
	invocacao_espiritos.unlocks_unit = "mage"
	invocacao_espiritos.unlocks_spell = "Lança de Arcana"
	invocacao_espiritos.school = "Arcanismo"
	invocacao_espiritos.description = "Rasgar um véu fino entre planos e vincular um espírito à vontade do invocador — a base de todo combate arcano, e o primeiro passo rumo aos rituais mais sombrios."
	techs[invocacao_espiritos.id] = invocacao_espiritos

	var pacto_florestal := TechData.new()
	pacto_florestal.id = "pacto_florestal"
	pacto_florestal.display_name = "Pacto Florestal"
	pacto_florestal.cost = 35.0
	pacto_florestal.prerequisites = ["alquimia_botanica"]
	pacto_florestal.unlocks_unit = "treant"
	pacto_florestal.bonus_terrain_types = [HexTileData.TerrainType.FOREST]
	pacto_florestal.bonus_food = 1
	pacto_florestal.bonus_production = 1
	pacto_florestal.school = "Naturalismo"
	pacto_florestal.description = "Um juramento antigo entre os druidas e o coração da floresta desperta os Ents guardiões — e faz cada árvore do território render mais madeira e fruto."
	techs[pacto_florestal.id] = pacto_florestal

	var forja_runica := TechData.new()
	forja_runica.id = "forja_runica"
	forja_runica.display_name = "Forja Rúnica"
	forja_runica.cost = 40.0
	forja_runica.prerequisites = ["transmutacao_rocha"]
	forja_runica.unlocks_unit = "stone_golem"
	forja_runica.bonus_terrain_types = [HexTileData.TerrainType.HILLS]
	forja_runica.bonus_production = 1
	forja_runica.school = "Transmutação"
	forja_runica.description = "Runas de poder gravadas a fogo na bigorna dão vida à pedra e ao metal — o nascimento do Golem de Pedra, guardião incansável que nunca sente o próprio peso."
	techs[forja_runica.id] = forja_runica

	var geomancia := TechData.new()
	geomancia.id = "geomancia"
	geomancia.display_name = "Geomancia"
	geomancia.cost = 35.0
	geomancia.prerequisites = ["transmutacao_rocha"]
	geomancia.bonus_terrain_types = [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.SAVANNA]
	geomancia.bonus_food = 1
	geomancia.school = "Geomancia"
	geomancia.description = "Ouvir o pulso lento da terra e persuadi-la a liberar água presa nas profundezas — o solo árido do deserto e da savana aprende a nutrir novamente."
	techs[geomancia.id] = geomancia

	var lordes_dos_ventos := TechData.new()
	lordes_dos_ventos.id = "lordes_dos_ventos"
	lordes_dos_ventos.display_name = "Lordes dos Ventos"
	lordes_dos_ventos.cost = 55.0
	lordes_dos_ventos.prerequisites = ["invocacao_espiritos"]
	lordes_dos_ventos.unlocks_unit = "griffin"
	lordes_dos_ventos.school = "Elementalismo"
	lordes_dos_ventos.description = "Um pacto sussurrado ao vento convoca os grandes grifos das alturas, que aceitam carregar um cavaleiro digno em troca de um ninho seguro no topo da torre mais alta."
	techs[lordes_dos_ventos.id] = lordes_dos_ventos

	var necromancia_pratica := TechData.new()
	necromancia_pratica.id = "necromancia_pratica"
	necromancia_pratica.display_name = "Necromancia Prática"
	necromancia_pratica.cost = 55.0
	necromancia_pratica.prerequisites = ["invocacao_espiritos"]
	necromancia_pratica.unlocks_unit = "shadow_summoner"
	necromancia_pratica.unlocks_spell = "Reanimar"
	necromancia_pratica.school = "Necromancia"
	necromancia_pratica.description = "A fronteira entre a vida e a sombra se mostra mais fina do que qualquer sábio ortodoxo admitiria — o Convocador de Sombras aprende a puxar ecos do outro lado para lutar por ele."
	techs[necromancia_pratica.id] = necromancia_pratica

	var constructos_de_guerra := TechData.new()
	constructos_de_guerra.id = "constructos_de_guerra"
	constructos_de_guerra.display_name = "Constructos de Guerra"
	constructos_de_guerra.cost = 55.0
	constructos_de_guerra.prerequisites = ["forja_runica"]
	constructos_de_guerra.unlocks_unit = "catapult"
	constructos_de_guerra.school = "Transmutação"
	constructos_de_guerra.description = "A mesma runa que dá vida ao Golem de Pedra, gravada num braço de arremesso em vez de um corpo, nasce a Catapulta Cadenciada — cada disparo cronometrado por um pulso arcano constante."
	techs[constructos_de_guerra.id] = constructos_de_guerra

	var cataclismo_elemental := TechData.new()
	cataclismo_elemental.id = "cataclismo_elemental"
	cataclismo_elemental.display_name = "Cataclismo Elemental"
	cataclismo_elemental.cost = 75.0
	cataclismo_elemental.prerequisites = ["constructos_de_guerra"]
	cataclismo_elemental.unlocks_spell = "Ruína Ígnea"
	cataclismo_elemental.school = "Elementalismo"
	cataclismo_elemental.description = "O ritual supremo da escola elemental: convocar fogo, pedra e tempestade ao mesmo tempo sobre um único ponto do mapa, o bastante para reduzir uma fortificação inteira a cinzas."
	techs[cataclismo_elemental.id] = cataclismo_elemental

	var transcendencia_florestal := TechData.new()
	transcendencia_florestal.id = "transcendencia_florestal"
	transcendencia_florestal.display_name = "Transcendência Florestal"
	transcendencia_florestal.cost = 70.0
	transcendencia_florestal.prerequisites = ["pacto_florestal"]
	transcendencia_florestal.unlocks_spell = "Metamorfose de Gaia"
	transcendencia_florestal.terrain_transform = {
		"from": [HexTileData.TerrainType.TUNDRA, HexTileData.TerrainType.DESERT],
		"to": HexTileData.TerrainType.GRASSLAND,
	}
	transcendencia_florestal.school = "Naturalismo"
	transcendencia_florestal.description = "O ápice do Pacto Florestal: em vez de apenas pedir à terra que floresça, o ritual reescreve o próprio bioma — tundra e deserto cedem lugar a pradarias férteis sob o toque dos druidas mais experientes."
	techs[transcendencia_florestal.id] = transcendencia_florestal

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
## — nao trava um tipo de unidade novo que ainda nao ganhou tech propria;
## e por isso que Arqueiro e Cavaleiro, que nao tem mais nenhuma tech
## magica associada nesta arvore, ficam liberados desde o inicio junto
## com Guerreiro — tropas mundanas nao exigem pesquisa arcana nenhuma).
static func is_unit_unlocked(kind: String, researched: Dictionary) -> bool:
	if kind == "settler" or kind == "warrior":
		return true
	for tech in all_techs():
		if tech.unlocks_unit == kind:
			return researched.has(tech.id)
	return true

## Tecnologia cujo unlocks_unit bate com `kind`, ou null se nenhuma
## tecnologia trava esse kind (Colonizador/Guerreiro, e agora tambem
## Arqueiro/Cavaleiro — ver comentario de is_unit_unlocked) — usado so pra
## mostrar qual pesquisa falta num tooltip (HUD._production_lock_reason)
## e por City._tech_unlocked_for_building() pra saber se um predio de
## treino ja pode ser construido. kind == "" tem que devolver null
## explicitamente ANTES do loop: `TechData.unlocks_unit` tambem default
## pra "" nas tecnologias que nao desbloqueiam unidade nenhuma
## (Alquimia Botanica, Geomancia...), entao sem essa guarda
## `tech_that_unlocks("")` "encontraria" a primeira tech de bioma da
## lista por acidente (ex: exigiria Alquimia Botanica pra construir o
## Celeiro, que nao trava tropa nenhuma — BuildingData.trains_unit == "").
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
	var bonus = {"food": 0, "production": 0, "gold": 0, "mana": 0}
	for id in researched.keys():
		var tech: TechData = get_tech(id)
		if tech and terrain_type in tech.bonus_terrain_types:
			bonus.food += tech.bonus_food
			bonus.production += tech.bonus_production
			bonus.gold += tech.bonus_gold
			bonus.mana += tech.bonus_mana
	return bonus

## Nomes de todos os feiticos/rituais (TechData.unlocks_spell) concedidos
## pelas tecnologias ja pesquisadas — usado pra um futuro painel "meus
## feiticos" ou tooltip, sem precisar varrer a arvore inteira toda vez.
## Ignora tecnologias sem feitico (unlocks_spell == "").
static func unlocked_spells_for(researched: Dictionary) -> Array[String]:
	var spells: Array[String] = []
	for tech in all_techs():
		if tech.unlocks_spell != "" and researched.has(tech.id):
			spells.append(tech.unlocks_spell)
	return spells
