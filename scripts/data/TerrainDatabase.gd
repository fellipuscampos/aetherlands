class_name TerrainDatabase
extends RefCounted

## Fabrica de dados de terreno. Em uma proxima etapa isto pode virar
## recursos .tres editaveis no editor, sem mudar quem consome HexTileData.
static func create_tile(terrain_type: int) -> HexTileData:
	var data := HexTileData.new()
	data.terrain_type = terrain_type
	match terrain_type:
		HexTileData.TerrainType.OCEAN:
			data.display_name = "Oceano"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = -0.3
			data.color = Color(0.13, 0.35, 0.62)
		HexTileData.TerrainType.SNOW:
			data.display_name = "Neve"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.05
			data.color = Color(0.92, 0.94, 0.97)
		HexTileData.TerrainType.TUNDRA:
			data.display_name = "Tundra"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.04
			data.color = Color(0.58, 0.6, 0.52)
		HexTileData.TerrainType.TAIGA:
			data.display_name = "Taiga"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.15
			data.color = Color(0.14, 0.32, 0.28)
		HexTileData.TerrainType.DESERT:
			data.display_name = "Deserto"
			data.movement_cost = 1
			data.food_yield = 0
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = 0.0
			data.color = Color(0.82, 0.71, 0.45)
		HexTileData.TerrainType.SAVANNA:
			data.display_name = "Savana"
			data.movement_cost = 1
			data.food_yield = 2
			data.production_yield = 0
			data.gold_yield = 1
			data.base_height = 0.01
			data.color = Color(0.68, 0.62, 0.32)
		HexTileData.TerrainType.JUNGLE:
			data.display_name = "Selva"
			data.movement_cost = 2
			data.food_yield = 2
			data.production_yield = 1
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.1
			data.color = Color(0.08, 0.32, 0.14)
		HexTileData.TerrainType.PLAINS:
			data.display_name = "Estepe"
			data.movement_cost = 1
			data.food_yield = 1
			data.production_yield = 1
			data.gold_yield = 0
			data.base_height = 0.02
			data.color = Color(0.58, 0.56, 0.32)
		HexTileData.TerrainType.GRASSLAND:
			data.display_name = "Planicie"
			data.movement_cost = 1
			data.food_yield = 3
			data.production_yield = 0
			data.gold_yield = 0
			data.base_height = 0.02
			data.color = Color(0.36, 0.62, 0.28)
		HexTileData.TerrainType.FOREST:
			data.display_name = "Floresta"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.25
			data.base_height = 0.12
			data.color = Color(0.16, 0.4, 0.18)
		HexTileData.TerrainType.HILLS:
			data.display_name = "Colinas"
			data.movement_cost = 2
			data.food_yield = 1
			data.production_yield = 2
			data.gold_yield = 0
			data.defense_bonus = 0.5
			data.base_height = 0.3
			data.color = Color(0.55, 0.45, 0.3)
		HexTileData.TerrainType.MOUNTAINS:
			data.display_name = "Montanhas"
			data.movement_cost = 3
			data.food_yield = 0
			data.production_yield = 1
			data.gold_yield = 0
			data.defense_bonus = 1.0
			data.base_height = 0.65
			data.color = Color(0.45, 0.44, 0.46)
	return data
