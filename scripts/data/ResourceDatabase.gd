class_name ResourceDatabase
extends RefCounted

## Recursos estrategicos/luxo espalhados nos tiles durante a geracao do
## mapa (ver HexGrid._maybe_assign_resource) — dao bonus de rendimento
## quando um cidadao trabalha aquele tile (City.collect_yields). Limitacao
## conhecida (documentada no README): so afetam yield por enquanto, nao
## bloqueiam producao de nenhuma unidade — um recurso "estrategico" de
## verdade (tipo Cavalos liberando Cavaleiro) exigiria rastrear acesso por
## cidade/jogador, escopo maior que essa rodada cobriu.

const ELIGIBILITY := {
	HexTileData.TerrainType.HILLS: ["iron"],
	HexTileData.TerrainType.MOUNTAINS: ["iron"],
	HexTileData.TerrainType.GRASSLAND: ["horses"],
	HexTileData.TerrainType.PLAINS: ["horses"],
	HexTileData.TerrainType.SAVANNA: ["horses"],
	HexTileData.TerrainType.FOREST: ["silk", "gems"],
	HexTileData.TerrainType.JUNGLE: ["silk", "gems"],
	HexTileData.TerrainType.TAIGA: ["gems"],
}

const DISPLAY_NAMES := {
	"iron": "Ferro",
	"horses": "Cavalos",
	"gems": "Gemas",
	"silk": "Seda",
}

const YIELDS := {
	"iron": {"food": 0, "production": 2, "gold": 0},
	"horses": {"food": 1, "production": 1, "gold": 0},
	"gems": {"food": 0, "production": 0, "gold": 3},
	"silk": {"food": 0, "production": 0, "gold": 2},
}

static func eligible_resources(terrain_type: int) -> Array:
	return ELIGIBILITY.get(terrain_type, [])

static func display_name(resource: String) -> String:
	return DISPLAY_NAMES.get(resource, "")

static func yield_for(resource: String) -> Dictionary:
	return YIELDS.get(resource, {"food": 0, "production": 0, "gold": 0})
