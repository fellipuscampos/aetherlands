class_name HexTileData
extends Resource

enum TerrainType {
	OCEAN, SNOW, TUNDRA, TAIGA, DESERT, SAVANNA, JUNGLE, PLAINS,
	GRASSLAND, FOREST, HILLS, MOUNTAINS,
}

@export var terrain_type: TerrainType = TerrainType.GRASSLAND
@export var display_name: String = "Planicie"
@export var movement_cost: int = 1
@export var defense_bonus: float = 0.0
@export var food_yield: int = 0
@export var production_yield: int = 0
@export var gold_yield: int = 0
@export var base_height: float = 0.0
@export var color: Color = Color.WHITE

## "" = sem recurso. Ver ResourceDatabase — recurso estrategico/luxo
## espalhado deterministicamente por HexGrid durante a geracao do mapa, da
## bonus de rendimento quando o tile e trabalhado (City.collect_yields).
@export var resource: String = ""
