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
## Torre dos Sabios/Muralhas, `trains_unit` vazio) e predios de TREINO
## (Quartel em diante, `trains_unit` preenchido) — cada tropa de combate so
## pode ser produzida
## se a cidade ja tiver o predio de treino correspondente (City.can_train(),
## pedido do usuario: "cada tropa e feita numa construcao... so pode
## treinar as tropas na sua respectiva construcao"). Colonizador E Guarda
## ficam de fora dessa regra (Guarda voltou a nao exigir predio nenhum,
## pedido do usuario numa rodada seguinte: "o guarda comum nao precisa de
## quartel pra ser feito").
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
## Quartel, Estabulo e Campo de Tiro passam por esse primeiro passo tambem:
## as techs "Quartel"/"Estabulo"/"Arquearia" sao quem liberam CONSTRUIR
## cada predio, o que atrasa Homem de Armas, Cavaleiro/Cavaleiro Real/
## Batedor e Arqueiro ate elas serem pesquisadas. Batedor tem um QUINTO
## gate por cima (a propria tech "Batedor Montado", prerequisito
## "estabulo") — Estabulo construido libera Cavaleiro/Cavaleiro Real, mas
## Batedor so destrava depois de pesquisar as DUAS techs (Estabulo E
## Batedor Montado), ver TechData.unlocks_unit.
##
## `requires_building` (BuildingData) e um QUARTO gate independente, so pro
## Estabulo por enquanto: alem da tech propria, tambem exige o Quartel
## FISICAMENTE construido nesta cidade antes (pedido do usuario: "faca o
## estabulo ser uma coisa que so pode ser feita depois do quartel") — ver
## City.can_build().
##
## Muralhas, Celeiro, Oficina e Mercado sao as EXCECOES na familia de
## RENDIMENTO/DEFESA: mesmo sem `trains_unit`, os quatro tem tech propria
## travando a construcao (tech "muralhas"/"celeiro"/"oficina"/"mercado",
## ver TechData.unlocks_building/TechDatabase.tech_that_unlocks_building) —
## pedido do usuario: "a muralha nao faz tanto sentido [como predio sempre
## liberado, sem tech nenhuma]... vamos remover ela, e adicionar como
## pesquisa", estendido depois pro resto dos predios: "precisamos fazer
## pesquisa de cada uma dessas coisas, tudo deve ter pesquisa". So Torre
## dos Sabios continua sem tech nenhuma. Muralhas tambem e o UNICO predio
## com `self_placed = true`
## (ver BuildingData.self_placed) — nao ganha um Building.gd separado num
## tile vizinho escolhido, vira o anel de muralha da PROPRIA cidade
## (City._add_walls, acionado por City.buildings.has("walls")).
##
## Desde o roadmap de gameplay Fase 1, a cidade RIVAL tambem constroi
## predios de verdade: RivalAI.decide_production pontua predio E unidade
## juntos (ver SCORE_WEIGHT_* em RivalAI.gd) e so escolhe entre o que
## City.can_build()/can_train() ja libera — mesmo gate do jogador, sem
## bypass. Antes disso a IA pulava esse gate inteiramente (nunca construia
## nada, mas ainda treinava tropa avancada de graca).

static var _cache: Dictionary = {} # id -> BuildingData, montada uma vez por sessao

static func _build_all() -> Dictionary:
	var buildings: Dictionary = {}

	# Redesenho do sistema de comida (pedido do usuario): antes o Celeiro so
	# somava um bonus fixo de comida/turno pra sempre. Agora toda cidade tem
	# um teto de armazenamento (City.FOOD_STORAGE_BASE) que a populacao
	# consome todo turno (City.FOOD_CONSUMPTION_PER_POP) — o Celeiro AUMENTA
	# esse teto (storage_bonus, ver BuildingData.gd/City.food_storage_cap()),
	# alem de manter um bonus pequeno de comida bruta (bonus_food, era 2,
	# reduzido pra 1 — o efeito principal migrou pro storage_bonus). Ganhou
	# tech propria tambem (ver TechDatabase "celeiro") — deixou de ser o
	# unico predio de rendimento sem pesquisa nenhuma associada (essa vaga
	# agora e so da Oficina/Mercado/Torre dos Sabios).
	var granary := BuildingData.new()
	granary.id = "granary"
	granary.display_name = "Celeiro"
	granary.production_cost = 20.0
	granary.bonus_food = 1
	granary.storage_bonus = 10.0
	# Identidade visual (pedido do usuario: "substitua tudo... use todos os
	# gratuitos" da KayKit) — sem "silo/celeiro" literal no pack, o Moinho
	# (windmill) e o modelo mais associado a graos/comida disponivel.
	granary.model_scene_path = "res://assets/models/kaykit/buildings/building_windmill_blue.gltf"
	buildings[granary.id] = granary

	# Ganhou tech propria (ver TechDatabase "oficina") — pedido do usuario:
	# "a oficina precisa de uma pesquisa, depois de ser pesquisado[,] p[oder]
	# ser construida". Mecanica em si sem mudanca nesta rodada de proposito
	# ("vamos fazer assim, depois deixamos mais complexo") — bonus_production
	# continua um bonus FIXO somado a producao bruta todo turno (ver
	# City.collect_yields()), que ja acumula em stored_production sozinho.
	var workshop := BuildingData.new()
	workshop.id = "workshop"
	workshop.display_name = "Oficina"
	workshop.production_cost = 25.0
	workshop.bonus_production = 2
	# Identidade visual (KayKit) — Ferreiro (blacksmith) e o oficio mais
	# proximo de "Oficina" no pack.
	workshop.model_scene_path = "res://assets/models/kaykit/buildings/building_blacksmith_blue.gltf"
	buildings[workshop.id] = workshop

	# Ganhou tech propria (ver TechDatabase "mercado") e um efeito NOVO alem
	# do bonus_gold fixo de sempre: uma vez construido, libera COMPRAR o
	# resto da producao do item atual com ouro (rush-buy) — pedido do
	# usuario: "o mercado pode servir pra [dar um uso real pro ouro]"/"é uma
	# boa, faça isso". Esse efeito de rush-buy vive em City.can_rush_buy()/
	# rush_buy_cost()/rush_buy() (checa buildings.has("market") direto, nao
	# tem campo dedicado aqui em BuildingData — nao ha outro predio que
	# precise de um campo booleano generico "libera rush-buy" ainda).
	var market := BuildingData.new()
	market.id = "market"
	market.display_name = "Mercado"
	market.production_cost = 25.0
	market.bonus_gold = 2
	# Identidade visual (KayKit) — combinacao literal.
	market.model_scene_path = "res://assets/models/kaykit/buildings/building_market_blue.gltf"
	buildings[market.id] = market

	# self_placed = true — sem tile pra escolher no mapa (ver BuildingData.
	# self_placed), a producao vira o anel de muralha da PROPRIA cidade
	# (City._add_walls) assim que completa. Gated pela tech "muralhas" (ver
	# TechData.unlocks_building/TechDatabase.tech_that_unlocks_building) —
	# pedido do usuario: "a muralha nao faz tanto sentido [como predio
	# generico]... adiciona como pesquisa... libera a construção da
	# muralha, mas essa muralha simplesmente adiciona esteticamente uma
	# muralha ao redor do tile da cidade... dando um shield a ela".
	var walls := BuildingData.new()
	walls.id = "walls"
	walls.display_name = "Muralhas"
	walls.production_cost = 30.0
	walls.defense_bonus = 0.5
	walls.self_placed = true
	buildings[walls.id] = walls

	# Predio de RENDIMENTO (mesma familia de Celeiro/Oficina/Mercado —
	# trains_unit vazio, nunca exige tecnologia pra construir, ver
	# City._tech_unlocked_for_building) que da vida numerica ao "Ergue a
	# Torre dos Sabios" que a descricao de canalizacao_base ja promete
	# (ver TechDatabase.gd) — sem isso a tech ficava so com lore, nenhum
	# efeito de bioma NEM de predio.
	var sages_tower := BuildingData.new()
	sages_tower.id = "sages_tower"
	sages_tower.display_name = "Torre dos Sábios"
	sages_tower.production_cost = 28.0
	sages_tower.bonus_mana = 3
	# Identidade visual (KayKit) — torre A (a torre B fica pra Torre Arcana,
	# ver mais abaixo, pra nao repetir o mesmo modelo nas duas).
	sages_tower.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_A_blue.gltf"
	buildings[sages_tower.id] = sages_tower

	# trains_unit = "men_at_arms" (NAO "warrior") — pedido do usuario:
	# "o guarda comum nao precisa de quartel pra ser feito", revertendo a
	# decisao anterior desta mesma sessao. Guarda volta a ser o unico kind
	# de COMBATE sem predio nenhum (ver building_that_trains abaixo, cai no
	# `return null` no fim por nao bater em nada); Homem de Armas fica
	# sozinho dependendo do Quartel.
	var barracks := BuildingData.new()
	barracks.id = "barracks"
	barracks.display_name = "Quartel"
	barracks.production_cost = 20.0
	barracks.trains_unit = "men_at_arms"
	# Identidade visual (pedido do usuario, ver BuildingData.model_scene_
	# path) — modelo real (KayKit Medieval Hexagon Pack, CC0) em vez do
	# prisma procedural de sempre. Combinacao literal.
	barracks.model_scene_path = "res://assets/models/kaykit/buildings/building_barracks_blue.gltf"
	buildings[barracks.id] = barracks

	var archery_range := BuildingData.new()
	archery_range.id = "archery_range"
	archery_range.display_name = "Campo de Tiro"
	archery_range.production_cost = 22.0
	archery_range.trains_unit = "archer"
	# Identidade visual (KayKit) — combinacao literal.
	archery_range.model_scene_path = "res://assets/models/kaykit/buildings/building_archeryrange_blue.gltf"
	buildings[archery_range.id] = archery_range

	# requires_building = "barracks" — pedido do usuario: "faca o estabulo
	# ser uma coisa que so pode ser feita depois do quartel". Isso ja
	# implica transitivamente que a tech "Quartel" tambem precisa estar
	# pesquisada antes (Quartel construido => tech Quartel pesquisada),
	# sem precisar duplicar esse gate na propria tech "Estabulo".
	var stable := BuildingData.new()
	stable.id = "stable"
	stable.display_name = "Estabulo"
	stable.production_cost = 26.0
	stable.trains_unit = "cavalry"
	stable.requires_building = "barracks"
	buildings[stable.id] = stable

	var siege_workshop := BuildingData.new()
	siege_workshop.id = "siege_workshop"
	siege_workshop.display_name = "Arsenal de Cerco"
	siege_workshop.production_cost = 32.0
	siege_workshop.trains_unit = "catapult"
	# Identidade visual (KayKit) — torre com catapulta, o modelo mais
	# proximo de "arsenal de cerco" no pack.
	siege_workshop.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_catapult_blue.gltf"
	buildings[siege_workshop.id] = siege_workshop

	var arcane_tower := BuildingData.new()
	arcane_tower.id = "arcane_tower"
	arcane_tower.display_name = "Torre Arcana"
	arcane_tower.production_cost = 30.0
	arcane_tower.trains_unit = "mage"
	# Identidade visual (KayKit) — torre B (a torre A ja foi pra Torre dos
	# Sabios acima, pra as duas torres nao ficarem identicas no mapa).
	arcane_tower.model_scene_path = "res://assets/models/kaykit/buildings/building_tower_B_blue.gltf"
	buildings[arcane_tower.id] = arcane_tower

	# Sem modelo KayKit equivalente nos pacotes gratuitos baixados (nenhum
	# "poleiro"/estrutura de treino de criatura voadora) — continua
	# procedural (Building._build_griffin_roost) ate aparecer um asset
	# gratuito que faca sentido.
	var griffin_roost := BuildingData.new()
	griffin_roost.id = "griffin_roost"
	griffin_roost.display_name = "Poleiro de Grifos"
	griffin_roost.production_cost = 38.0
	griffin_roost.trains_unit = "griffin"
	buildings[griffin_roost.id] = griffin_roost

	# Idem — sem "bosque/arvore ritual" na Hexagon Pack (a Forest Nature
	# Pack tem arvores soltas, mas nao um PREDIO de bosque druida); continua
	# procedural.
	var druid_grove := BuildingData.new()
	druid_grove.id = "druid_grove"
	druid_grove.display_name = "Bosque Druida"
	druid_grove.production_cost = 32.0
	druid_grove.trains_unit = "treant"
	buildings[druid_grove.id] = druid_grove

	# Predios de treino da arvore de tecnologia magica (ver TechDatabase:
	# forja_runica/necromancia_pratica) — fecham a mesma cadeia de 3 passos
	# do resto do elenco (pesquisar -> construir -> treinar).
	#
	# Sem modelo KayKit equivalente pra "bigorna runica" alem do ferreiro ja
	# usado pela Oficina (repetir o mesmo modelo confundiria os dois
	# predios) — continua procedural.
	var runic_anvil := BuildingData.new()
	runic_anvil.id = "runic_anvil"
	runic_anvil.display_name = "Bigorna Rúnica"
	runic_anvil.production_cost = 34.0
	runic_anvil.trains_unit = "stone_golem"
	buildings[runic_anvil.id] = runic_anvil

	# Sem "cripta/tumulo" na Hexagon Pack; continua procedural.
	var shadow_crypt := BuildingData.new()
	shadow_crypt.id = "shadow_crypt"
	shadow_crypt.display_name = "Cripta Sombria"
	shadow_crypt.production_cost = 34.0
	shadow_crypt.trains_unit = "shadow_summoner"
	buildings[shadow_crypt.id] = shadow_crypt

	# Predio de RENDIMENTO (mesma familia da Torre dos Sabios acima — sem
	# trains_unit, sem tech nenhuma associada, ver City.can_build) que
	# habilita o Ritual do Nodulo (ver VictoryConditions.SANCTUARY_BUILDING_ID
	# / has_arcane_sanctuary). Custo e bonus de mana sao valores iniciais de
	# gameplay (ainda NAO calibrados, ver Roadmap Fase F) — so o suficiente
	# pra existir e o F7 poder medir o efeito real. Sem "santuario/nodulo"
	# na Hexagon Pack; continua procedural (Building._build_arcane_sanctuary).
	var arcane_sanctuary := BuildingData.new()
	arcane_sanctuary.id = "arcane_sanctuary"
	arcane_sanctuary.display_name = "Santuário do Nódulo"
	arcane_sanctuary.production_cost = 45.0
	arcane_sanctuary.bonus_mana = 2
	buildings[arcane_sanctuary.id] = arcane_sanctuary

	return buildings

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_building(id: String) -> BuildingData:
	return _all().get(id, null)

static func all_buildings() -> Array:
	return _all().values()

## Predio de treino cujo trains_unit bate com `kind` (ex: "men_at_arms" ->
## Quartel), ou null se `kind` nao exige nenhum predio especifico (ex:
## "settler" E "warrior" — Guarda nao tem predio nenhum, pedido do usuario:
## "o guarda comum nao precisa de quartel pra ser feito") — ver
## City.can_train(). Tropa racial exclusiva (UnitDatabase.RACE_UNIQUE_KIND
## — dwarf_axeguard/orc_berserker/elf_ranger) nao tem `trains_unit` proprio
## em NENHUM BuildingData (nao ganhou predio dedicado), mas ainda precisa
## de UM predio pra treinar: cai no Quartel por padrao — tematicamente sua
## tropa de elite continua treinando no mesmo lugar que o resto do
## exercito, sem exigir um predio novo so pra isso. Cavaleiro Real
## (human_knight) e a UNICA excecao — pedido do usuario: "apos construido
## no estabulo voce pode fazer o cavaleiro real", cai no Estabulo em vez
## do Quartel (faz sentido tematico: cavalaria pesada treina onde os
## cavalos estao), checado ANTES do fallback racial generico abaixo.
## Batedor (scout) tambem cai no Estabulo pelo mesmo motivo tematico — um
## batedor MONTADO tambem sai de onde os cavalos estao, sem exigir predio
## proprio so pra uma tropa de baixo dano (pedido do usuario: "o batedor
## montado... libera a construcao do batedor").
static func building_that_trains(kind: String) -> BuildingData:
	for b in all_buildings():
		if b.trains_unit == kind:
			return b
	if kind == "human_knight" or kind == "scout":
		return get_building("stable")
	if UnitDatabase.race_for_unique_kind(kind) != "":
		return get_building("barracks")
	return null

## Soma o bonus de TODOS os predios ja construidos (built = City.buildings).
## "storage" (ver BuildingData.storage_bonus/City.food_storage_cap()) so o
## Celeiro usa hoje, incluido aqui pra manter uma unica funcao de soma em
## vez de duplicar este loop so pra esse campo.
static func total_bonus(built: Dictionary) -> Dictionary:
	var bonus = {"food": 0, "production": 0, "gold": 0, "mana": 0, "storage": 0.0}
	for id in built.keys():
		var b: BuildingData = get_building(id)
		if b:
			bonus.food += b.bonus_food
			bonus.production += b.bonus_production
			bonus.gold += b.bonus_gold
			bonus.mana += b.bonus_mana
			bonus.storage += b.storage_bonus
	return bonus

static func defense_bonus_for(built: Dictionary) -> float:
	var total := 0.0
	for id in built.keys():
		var b: BuildingData = get_building(id)
		if b:
			total += b.defense_bonus
	return total
