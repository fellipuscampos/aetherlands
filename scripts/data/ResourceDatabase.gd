class_name ResourceDatabase
extends RefCounted

## Recursos estrategicos/luxo espalhados nos tiles durante a geracao do
## mapa (ver HexGrid._maybe_assign_resource) — dao bonus de rendimento
## quando um cidadao trabalha aquele tile (City.collect_yields). Limitacao
## conhecida (documentada no README): so afetam yield por enquanto, nao
## bloqueiam producao de nenhuma unidade — um recurso "estrategico" de
## verdade (tipo Cavalos liberando Cavaleiro) exigiria rastrear acesso por
## cidade/jogador, escopo maior que essa rodada cobriu.

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
