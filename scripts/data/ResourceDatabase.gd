class_name ResourceDatabase
extends RefCounted

## Recursos espalhados nos tiles durante a geracao do mapa (ver
## HexGrid._maybe_assign_resource): ids, elegibilidade/peso por bioma, nome
## exibido e visual.
##
## Fase 25 (migracao final V1->V2): o recurso nao tem mais NENHUMA semantica
## economica propria aqui. O rendimento vem so' da Melhoria de Recurso V2
## (V2ResourceImprovementData, construida pelo Construtor em territorio
## proprio). Os efeitos V1 -- bonus de rendimento ao trabalhar o tile,
## descontos de Cavalaria (Cavalos), unidade pesada (Ferro), feitico (Nodulo
## Arcano), compra rapida (Gemas) e capacidade de rota de comercio (Seda) --
## sairam junto com cidadaos, compra rapida, magia V1 e comercio.

## "mana_node" (Nodulo Arcano, pedido do usuario — Ponto 3, "Economia
## Arcana"): a Melhoria V2 dele rende Mana.
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
## - Ferro: Colina continua o lar
##   natural (minerio em terreno rochoso elevado, Montanha ja excluida por
##   pedido anterior). Adicionado Tundra como secundario RARO — minerio em
##   terreno rochoso frio tem precedente real (Escudo Canadense/Siberia) e
##   Tundra nunca teve recurso nenhum ate agora (uma das "regioes inteiras
##   sem recurso" observadas).
## - Cavalos: antes em 3 biomas
##   com peso IGUAL — a causa raiz de "cavalos abundantes demais no mapa
##   inteiro". Planicie vira o preferencial (estepe aberta classica);
##   Campina/Savana continuam validos, so secundarios.
## - Gemas: Selva continua preferencial
##   (tesouro/joia em ruina tropical, tropo de fantasia). Deserto
##   ADICIONADO como secundario forte — "cristais/gemas no deserto" e' o
##   proprio exemplo do usuario, e Deserto tambem nunca teve recurso
##   nenhum. Floresta continua secundaria; Taiga rebaixada a terciaria
##   (gema em floresta gelada e' o encaixe tematico mais fraco dos 4).
## - Seda: Selva preferencial (sericultura
##   exotica/tropical), Floresta secundaria — ja fazia sentido tematico,
##   sem mudanca de biomas, so formalizado como peso.
## - Nodulo Arcano: Colina/Floresta como
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

## Ladrilhos POSSUIDOS (nao so trabalhados) de UMA cidade que tem o recurso
## `resource_id` — mesmo dedupe de count_controlled abaixo (owned_tiles
## pode ou nao ja incluir o proprio coord da cidade, dependendo de como o
## City foi montado).
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
## que tem o recurso `resource_id` (usado pela avaliacao de local de
## cidade, CitySite).
static func count_controlled(player: PlayerData, hex_grid: HexGrid, resource_id: String) -> int:
	var count := 0
	for city in player.cities:
		count += count_controlled_for_city(city, hex_grid, resource_id)
	return count
