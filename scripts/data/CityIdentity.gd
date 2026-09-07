class_name CityIdentity
extends RefCounted

## Roadmap "Parte B" (cidade em profundidade), fatia B1+B2 — identidade de
## cidade DERIVADA, nunca armazenada. Achado que fundamenta toda a classe:
## City.buildings (Dictionary id->true) NUNCA perde entrada em lugar
## nenhum do codigo — nenhum .clear()/.erase() existe sobre ele, cada
## predio so e construido uma vez por cidade (City.process_turn(),
## buildings[id]=true na conclusao, City.gd:571), e ATE a captura de
## cidade (HexGrid.capture_city -> City.change_owner, City.gd:433-437)
## preserva buildings de proposito ("Progresso de producao e mantido de
## proposito", comentario no proprio change_owner). Ou seja: uma funcao
## pura sobre buildings.keys() ja e, por construcao, MONOTONICA — so
## cresce, nunca "esquece" um investimento antigo, exatamente a definicao
## de "tendencia persistente" pedida pelo usuario, sem campo novo, sem
## SaveManager, sem UI nova — e de graca tambem pra cidade de IA (RivalAI.
## decide_production so chama City.set_production()/process_turn(), o
## MESMO caminho de sempre, RivalAI.gd:102-124, nenhum bypass).
##
## Especializacao (B2) e SEMPRE um bonus aditivo/multiplicativo MODESTO e
## com teto (mesma filosofia de ResourceDatabase/RaceEconomy), nunca um
## bloqueio, nunca categoria rigida — "a cidade ainda pode fazer outras
## coisas" (pedido do usuario). Uma cidade pode ter forca > 0 em varios
## eixos ao mesmo tempo.
##
## Assimetria de elenco: agricola/industrial/comercial tem 1 unico predio
## possivel cada (binario 0%/100%), militar tem 5, arcana tem 6.
## axis_strength() normaliza cada eixo pelo TAMANHO DO PROPRIO BALDE
## (predios_construidos / tamanho_do_balde) — todo eixo fica 0.0-1.0 igual,
## nenhum eixo fica estruturalmente incapaz de chegar a 1.0 so por ter menos
## predios possiveis. O preco: militar/arcana crescem em degraus MENORES
## (1/5=20%, 1/6=16.7%) enquanto os 3 outros saltam de 0% pra 100% no unico
## predio que tem — inerente ao elenco de predios de hoje, nao um bug desta
## classe.

const AXIS_AGRICOLA := "agricola"
const AXIS_INDUSTRIAL := "industrial"
const AXIS_COMERCIAL := "comercial"
const AXIS_MILITAR := "militar"
const AXIS_ARCANA := "arcana"

## Ordem fixa usada tanto pra iterar todos os eixos quanto como criterio de
## desempate em dominant_axis() (primeiro da lista vence empate) —
## arbitraria mas DETERMINISTICA, evita que dominant_axis() oscile entre
## chamadas com o mesmo estado de buildings so por causa da ordem de
## iteracao de um Dictionary.
const AXES := [AXIS_AGRICOLA, AXIS_INDUSTRIAL, AXIS_COMERCIAL, AXIS_MILITAR, AXIS_ARCANA]

const AXIS_BUILDINGS := {
	AXIS_AGRICOLA: ["granary"],
	AXIS_INDUSTRIAL: ["workshop"],
	AXIS_COMERCIAL: ["market"],
	AXIS_MILITAR: ["walls", "barracks", "archery_range", "stable", "siege_workshop"],
	AXIS_ARCANA: ["sages_tower", "arcane_tower", "griffin_roost", "druid_grove", "runic_anvil", "shadow_crypt", "arcane_sanctuary"],
}

## Pesos de B2 abaixo — NAO calibrados, ponto de partida no mesmo intervalo
## ja usado por RaceEconomy (5%-20%) e ResourceDatabase (teto 30% em
## descontos de 5%/fonte); harness-validate-later, mesma disciplina de
## Parte 1/A: "variavel sistemica pequena -> decisao existente -> formula
## aditiva -> teste comportamental -> harness antes de calibrar".
const AGRICOLA_FOOD_BONUS_MAX := 0.10
const INDUSTRIAL_PRODUCTION_BONUS_MAX := 0.10
const COMERCIAL_GOLD_BONUS_MAX := 0.10
const ARCANA_MANA_BONUS_MAX := 0.15
const MILITAR_UNIT_COST_DISCOUNT_MAX := 0.15

## Forca do eixo NESTA cidade, 0.0-1.0 — ver comentario de topo sobre
## normalizacao por tamanho de balde.
static func axis_strength(city: City, axis: String) -> float:
	var bucket: Array = AXIS_BUILDINGS.get(axis, [])
	if bucket.is_empty():
		return 0.0
	var built := 0
	for id in bucket:
		if city.buildings.has(id):
			built += 1
	return float(built) / float(bucket.size())

## Sinal de identidade CIVILIZACIONAL (Roadmap Parte B, B3) — media simples
## de axis_strength() sobre TODAS as cidades da civ, 0.0 sem cidade
## nenhuma. Continua uma leitura RETROSPECTIVA de dado que ja existe (zero
## campo novo, zero SaveManager) — NAO e uma "personalidade" (isso e B4,
## fora de escopo): personalidade seria um traco PROSPECTIVO/intencional;
## isto e so a media de "o que essas cidades ja construiram", recalculada
## toda vez. Fica aqui (nao em RivalAI.gd) porque ainda e 100% sobre
## identidade de cidade agregada — nunca toca TechData/TechDatabase.
static func civilization_axis_strength(player: PlayerData, axis: String) -> float:
	if player.cities.is_empty():
		return 0.0
	var total := 0.0
	for city in player.cities:
		total += axis_strength(city, axis)
	return total / float(player.cities.size())

## Eixo de maior forca, "" se a cidade nao tem NENHUM predio de eixo
## nenhum (generalista/inicio de jogo, ou uma cidade cheia so de predios
## que nao pertencem a AXIS_BUILDINGS nenhum) — desempate: primeiro de
## AXES na ordem declarada acima (estrito ">", nao ">=").
static func dominant_axis(city: City) -> String:
	var best_axis := ""
	var best_strength := 0.0
	for axis in AXES:
		var strength := axis_strength(city, axis)
		if strength > best_strength:
			best_strength = strength
			best_axis = axis
	return best_axis

## Bonus de yield (B2) — MESMA convencao de RaceEconomy.apply_yield_bonus:
## mutacao in-place de `totals`, chamado de City.collect_yields() logo
## apos o bonus racial. Multiplicacao comuta, entao a ordem entre este
## bonus e o racial nao muda o resultado.
static func apply_yield_bonus(totals: Dictionary, city: City) -> void:
	totals.food *= 1.0 + AGRICOLA_FOOD_BONUS_MAX * axis_strength(city, AXIS_AGRICOLA)
	totals.production *= 1.0 + INDUSTRIAL_PRODUCTION_BONUS_MAX * axis_strength(city, AXIS_INDUSTRIAL)
	totals.gold *= 1.0 + COMERCIAL_GOLD_BONUS_MAX * axis_strength(city, AXIS_COMERCIAL)
	totals.mana *= 1.0 + ARCANA_MANA_BONUS_MAX * axis_strength(city, AXIS_ARCANA)

## Desconto de custo de producao (B2, eixo militar) pra qualquer unidade
## treinada num predio do bucket MILITAR (Quartel/Campo de Tiro/Estabulo/
## Arsenal de Cerco — Muralhas conta pra forca do eixo mas nao treina nada,
## entao nunca aparece como `kind` aqui). Cresce em passos de
## MILITAR_UNIT_COST_DISCOUNT_MAX/5 conforme a cidade acumula predios
## militares, mesmo teto/padrao de ResourceDatabase.heavy_unit_cost_
## multiplier. Diferente dos descontos de ResourceDatabase, NAO depende de
## hex_grid/owner_player (so de buildings LOCAIS desta cidade) — ver
## City.production_cost() pra onde isso muda o comportamento do parametro
## opcional `hex_grid`.
static func militar_unit_cost_multiplier(city: City, kind: String) -> float:
	var trainer: BuildingData = BuildingDatabase.building_that_trains(kind)
	if trainer == null or not (trainer.id in AXIS_BUILDINGS[AXIS_MILITAR]):
		return 1.0
	return 1.0 - MILITAR_UNIT_COST_DISCOUNT_MAX * axis_strength(city, AXIS_MILITAR)
