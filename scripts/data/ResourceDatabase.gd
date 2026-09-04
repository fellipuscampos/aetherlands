class_name ResourceDatabase
extends RefCounted

## Recursos estrategicos/luxo espalhados nos tiles durante a geracao do
## mapa (ver HexGrid._maybe_assign_resource) — dao bonus de rendimento
## quando um cidadao trabalha aquele tile (City.collect_yields).
##
## Roadmap de gameplay Fase 3 — pedido do usuario: "controla N recursos
## estrategicos do tipo X = tem N fontes disponiveis pro bonus daquele
## tipo", versao objetiva de proposito (sem camada de estoque/consumo/
## comercio — isso fica pra uma fase futura de comercio, se fizer
## sentido). count_controlled() conta ladrilhos POSSUIDOS (City.
## owned_tiles), nao so os TRABALHADOS que ja rendem yield normal, dando
## ao recurso um valor minimo mesmo fora do limite de trabalhadores da
## cidade — primeiro efeito "estrategico" de um recurso alem do yield
## puro (Cavalos reduz custo de Cavalaria, ver cavalry_cost_multiplier).
## Continua NAO bloqueando producao nenhuma (so mais barato com o
## recurso, nunca impossivel sem ele) — mantem o padrao do resto do jogo
## de nunca criar trava permanente.

## "mana_node" (Nodulo Arcano, pedido do usuario — Ponto 3, "Economia
## Arcana"): mesmo mecanismo dos recursos estrategicos de sempre (bonus so
## quando o tile e trabalhado), so que rendendo MANA em vez de comida/
## producao/ouro. Elegivel em Colinas/Floresta — reusa a mesma dispersao
## por ruido+hash ja existente em HexGrid._maybe_assign_resource, nenhuma
## logica de geracao de mapa nova precisou ser escrita, so essa entrada de
## elegibilidade.
##
## Montanha removida da elegibilidade de Ferro/Nodulo Arcano (pedido do
## usuario: "faca recursos nao nascerem nas montanhas") — Colina continua
## elegivel pros dois.
const ELIGIBILITY := {
	HexTileData.TerrainType.HILLS: ["iron", "mana_node"],
	HexTileData.TerrainType.GRASSLAND: ["horses"],
	HexTileData.TerrainType.PLAINS: ["horses"],
	HexTileData.TerrainType.SAVANNA: ["horses"],
	HexTileData.TerrainType.FOREST: ["silk", "gems", "mana_node"],
	HexTileData.TerrainType.JUNGLE: ["silk", "gems"],
	HexTileData.TerrainType.TAIGA: ["gems"],
}

const DISPLAY_NAMES := {
	"iron": "Ferro",
	"horses": "Cavalos",
	"gems": "Gemas",
	"silk": "Seda",
	"mana_node": "Nódulo Arcano",
}

const YIELDS := {
	"iron": {"food": 0, "production": 2, "gold": 0, "mana": 0},
	"horses": {"food": 1, "production": 1, "gold": 0, "mana": 0},
	"gems": {"food": 0, "production": 0, "gold": 3, "mana": 0},
	"silk": {"food": 0, "production": 0, "gold": 2, "mana": 0},
	"mana_node": {"food": 0, "production": 0, "gold": 0, "mana": 2},
}

static func eligible_resources(terrain_type: int) -> Array:
	return ELIGIBILITY.get(terrain_type, [])

static func display_name(resource: String) -> String:
	return DISPLAY_NAMES.get(resource, "")

static func yield_for(resource: String) -> Dictionary:
	return YIELDS.get(resource, {"food": 0, "production": 0, "gold": 0, "mana": 0})

## Ladrilhos POSSUIDOS (nao so trabalhados) de UMA cidade que tem o recurso
## `resource_id` — mesmo dedupe de count_controlled abaixo (owned_tiles
## pode ou nao ja incluir o proprio coord da cidade, dependendo de como o
## City foi montado). Extraido de count_controlled pra ser reusado por
## efeitos calculados POR CIDADE (ex: capacidade de rota de Seda), nao so
## por jogador inteiro.
static func count_controlled_for_city(city: City, hex_grid: HexGrid, resource_id: String) -> int:
	var unique_coords := {}
	unique_coords[city.coord] = true
	for owned in city.owned_tiles:
		unique_coords[owned] = true
	var count := 0
	for coord in unique_coords.keys():
		var data: HexTileData = hex_grid.get_tile(coord)
		if data and data.resource == resource_id:
			count += 1
	return count

## Ladrilhos POSSUIDOS (nao so trabalhados) por qualquer cidade do jogador
## que tem o recurso `resource_id` — ver comentario de topo do arquivo.
static func count_controlled(player: PlayerData, hex_grid: HexGrid, resource_id: String) -> int:
	var count := 0
	for city in player.cities:
		count += count_controlled_for_city(city, hex_grid, resource_id)
	return count

const CAVALRY_COST_DISCOUNT_PER_HORSE_SOURCE := 0.05
const CAVALRY_COST_DISCOUNT_MAX := 0.30

## Multiplicador (nunca > 1.0) pro custo de producao de Cavalaria — cada
## fonte de Cavalos controlada desconta um pouco, ate um teto modesto.
static func cavalry_cost_multiplier(player: PlayerData, hex_grid: HexGrid) -> float:
	var sources := count_controlled(player, hex_grid, "horses")
	var discount: float = min(sources * CAVALRY_COST_DISCOUNT_PER_HORSE_SOURCE, CAVALRY_COST_DISCOUNT_MAX)
	return 1.0 - discount

## Roadmap 2.0 Parte 1 (B1) — identidade de Ferro: desconto de producao em
## unidades PESADAS terrestres, mesmo padrao/teto de cavalry_cost_
## multiplier acima. NUNCA inclui unidade de Cavalaria (essa identidade e
## de Cavalos, ver cima) — human_knight fica de fora apesar de "pesado"
## porque usa Estabulo e e tematicamente Cavalaria, nao Ferro; incluir os
## dois duplicaria a mesma identidade em dois recursos.
const IRON_DISCOUNT_KINDS := ["men_at_arms", "catapult", "stone_golem", "dwarf_axeguard", "orc_berserker"]
const IRON_COST_DISCOUNT_PER_SOURCE := 0.05
const IRON_COST_DISCOUNT_MAX := 0.30

static func heavy_unit_cost_multiplier(player: PlayerData, hex_grid: HexGrid) -> float:
	var sources := count_controlled(player, hex_grid, "iron")
	var discount: float = min(sources * IRON_COST_DISCOUNT_PER_SOURCE, IRON_COST_DISCOUNT_MAX)
	return 1.0 - discount

## Roadmap 2.0 Parte 1 (B1) — identidade de Nodulo Arcano: desconto no
## custo de MANA de feitiços, mesmo padrao/teto dos outros descontos.
const MANA_COST_DISCOUNT_PER_SOURCE := 0.05
const MANA_COST_DISCOUNT_MAX := 0.30

static func spell_mana_cost_multiplier(player: PlayerData, hex_grid: HexGrid) -> float:
	var sources := count_controlled(player, hex_grid, "mana_node")
	var discount: float = min(sources * MANA_COST_DISCOUNT_PER_SOURCE, MANA_COST_DISCOUNT_MAX)
	return 1.0 - discount

## Roadmap 2.0 Parte 1 (B1) — identidade de Gemas: desconto no custo de
## rush-buy (comprar producao com ouro), mesmo padrao/teto dos outros.
const GEMS_RUSH_BUY_DISCOUNT_PER_SOURCE := 0.05
const GEMS_RUSH_BUY_DISCOUNT_MAX := 0.30

static func rush_buy_cost_multiplier(player: PlayerData, hex_grid: HexGrid) -> float:
	var sources := count_controlled(player, hex_grid, "gems")
	var discount: float = min(sources * GEMS_RUSH_BUY_DISCOUNT_PER_SOURCE, GEMS_RUSH_BUY_DISCOUNT_MAX)
	return 1.0 - discount

## Roadmap 2.0 Parte 1 (B1) — identidade de Seda: capacidade EXTRA de rota
## de comercio por cidade. Diferente dos 4 descontos acima (grandeza
## continua, 0.0-1.0): rota e uma grandeza DISCRETA, entao a formula e uma
## escada (+1 rota a cada 2 fontes controladas NESTA cidade, teto +2), nao
## um percentual — um desconto percentual nao faria sentido pra "numero de
## rotas". A divisao por 2 evita que uma cidade com muitos tiles de Seda
## vire uma potencia comercial so por acumulo passivo.
const SILK_SOURCES_PER_ROUTE_BONUS := 2
const SILK_ROUTE_CAPACITY_BONUS_MAX := 2

static func extra_trade_route_capacity(city: City, hex_grid: HexGrid) -> int:
	var sources := count_controlled_for_city(city, hex_grid, "silk")
	return mini(sources / SILK_SOURCES_PER_ROUTE_BONUS, SILK_ROUTE_CAPACITY_BONUS_MAX)
