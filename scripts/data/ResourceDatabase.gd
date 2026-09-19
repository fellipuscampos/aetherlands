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
## producao/ouro.
##
## Montanha removida da elegibilidade de Ferro/Nodulo Arcano (pedido do
## usuario: "faca recursos nao nascerem nas montanhas") — Colina continua
## elegivel pros dois.
##
## Roadmap "revisar preferencia de recurso por bioma" (pedido do usuario:
## "avalie seriamente se recursos devem possuir preferencias por bioma...
## bioma preferencial, biomas secundarios, pequena chance global... evite
## 'deserto = cristal garantido', prefira 'deserto aumenta
## significativamente a chance'"). Antes disto ELIGIBILITY era uma lista
## PLANA (elegivel ou nao, sem preferencia nenhuma dentro da lista — ver
## HexGrid._maybe_assign_resource pre-fix, que escolhia entre os elegiveis
## com peso IGUAL). Virou um peso por bioma (0.0..1.0, 1.0 = bioma
## preferencial daquele recurso) — HexGrid._maybe_assign_resource faz um
## sorteio PROPORCIONAL ao peso (deterministico pela map_seed, sem ruido
## extra), nunca uma garantia: um bioma secundario com peso baixo ainda
## pode vencer, so com chance menor. Pensado recurso a recurso (funcao,
## raridade desejada, bioma tematicamente coerente):
##
## - Ferro (producao + desconto de unidade pesada): Colina continua o lar
##   natural (minerio em terreno rochoso elevado, Montanha ja excluida por
##   pedido anterior). Adicionado Tundra como secundario RARO — minerio em
##   terreno rochoso frio tem precedente real (Escudo Canadense/Siberia) e
##   Tundra nunca teve recurso nenhum ate agora (uma das "regioes inteiras
##   sem recurso" observadas).
## - Cavalos (comida+producao+desconto de Cavalaria): antes em 3 biomas
##   com peso IGUAL — a causa raiz de "cavalos abundantes demais no mapa
##   inteiro". Planicie vira o preferencial (estepe aberta classica);
##   Campina/Savana continuam validos, so secundarios.
## - Gemas (ouro + desconto de rush-buy): Selva continua preferencial
##   (tesouro/joia em ruina tropical, tropo de fantasia). Deserto
##   ADICIONADO como secundario forte — "cristais/gemas no deserto" e' o
##   proprio exemplo do usuario, e Deserto tambem nunca teve recurso
##   nenhum. Floresta continua secundaria; Taiga rebaixada a terciaria
##   (gema em floresta gelada e' o encaixe tematico mais fraco dos 4).
## - Seda (ouro + capacidade de rota): Selva preferencial (sericultura
##   exotica/tropical), Floresta secundaria — ja fazia sentido tematico,
##   sem mudanca de biomas, so formalizado como peso.
## - Nodulo Arcano (mana + desconto de feitico): Colina/Floresta como
##   secundarios existentes, mas faltava o encaixe tematico OBVIO —
##   Campos de Cristal (TerrainType.CRYSTAL, bioma arcano dedicado do
##   continente principal, ver comentario dele em HexTileData.gd: "combina
##   com Torre Arcana/Mago") nunca tinha sido incluido. Vira o
##   preferencial: e' um bioma ja RARO por design (so' substitui um bioma
##   plano quando o ruido arcano passa de um limiar raro, ver HexGrid.
##   _maybe_crystal/ARCANE_NOISE_THRESHOLD, mesma familia de raridade da
##   Lava) — recurso raro concentrado num bioma raro, nao virou onipresente.
const BIOME_WEIGHTS := {
	"iron": {
		HexTileData.TerrainType.HILLS: 1.0,
		HexTileData.TerrainType.TUNDRA: 0.35,
	},
	"horses": {
		HexTileData.TerrainType.PLAINS: 1.0,
		HexTileData.TerrainType.GRASSLAND: 0.55,
		HexTileData.TerrainType.SAVANNA: 0.55,
	},
	"gems": {
		HexTileData.TerrainType.JUNGLE: 1.0,
		HexTileData.TerrainType.DESERT: 0.7,
		HexTileData.TerrainType.FOREST: 0.45,
		HexTileData.TerrainType.TAIGA: 0.25,
	},
	"silk": {
		HexTileData.TerrainType.JUNGLE: 1.0,
		HexTileData.TerrainType.FOREST: 0.5,
	},
	"mana_node": {
		HexTileData.TerrainType.CRYSTAL: 1.0,
		HexTileData.TerrainType.HILLS: 0.4,
		HexTileData.TerrainType.FOREST: 0.4,
	},
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

## Mesma assercao de sempre pros chamadores existentes (Array de ids) —
## deriva de BIOME_WEIGHTS pra ter UMA fonte de verdade so (ver comentario
## dela acima), em vez de manter duas tabelas (elegibilidade + peso) que
## pudessem desincronizar.
static func eligible_resources(terrain_type: int) -> Array:
	var result: Array = []
	for resource_id in BIOME_WEIGHTS:
		if BIOME_WEIGHTS[resource_id].has(terrain_type):
			result.append(resource_id)
	return result

## Peso (0.0 = nao elegivel) de `resource_id` no bioma `terrain_type` — ver
## HexGrid._maybe_assign_resource, sorteio proporcional ao peso.
static func weight_for(resource_id: String, terrain_type: int) -> float:
	return BIOME_WEIGHTS.get(resource_id, {}).get(terrain_type, 0.0)

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
