class_name TerrainTextureCatalog
extends RefCounted

## Pixel terrain surfaces. IDs are stored in INSTANCE_CUSTOM.b; gameplay
## terrain IDs, elevation and the special effects in .a stay independent.
const DIR := "res://assets/textures/terrain/pixel_v1/"
const ARRAY_PATH := DIR + "terrain_surfaces.res"
const SIZE := 128
const PIXELS_PER_WORLD_UNIT := 64.0
const SURFACES := ["grass", "dry_grass", "forest_floor", "tundra", "dirt", "snow", "ice", "sand", "rock", "basalt", "ash", "crystal", "mystic_soil", "magma"]
const ROCK_LAYER := 8
const SNOW_LAYER := 5
const ICE_LAYER := 6
const MAGMA_LAYER := 13
const WATER_MEAN_LUMA := 0.17769242375132188 # linear mean measured from water_albedo.png
const REFERENCES := [
	HexTileData.TerrainType.GRASSLAND, HexTileData.TerrainType.PLAINS,
	HexTileData.TerrainType.FOREST, HexTileData.TerrainType.TUNDRA,
	HexTileData.TerrainType.HILLS, HexTileData.TerrainType.SNOW,
	HexTileData.TerrainType.ICE, HexTileData.TerrainType.DESERT,
	HexTileData.TerrainType.MOUNTAINS, HexTileData.TerrainType.VOLCANIC_ROCK,
	HexTileData.TerrainType.VOLCANIC_ASH, HexTileData.TerrainType.CRYSTAL,
	HexTileData.TerrainType.MYSTIC_SOIL, HexTileData.TerrainType.LAVA,
]
const LAYERS := {
	HexTileData.TerrainType.GRASSLAND: 0,
	HexTileData.TerrainType.PLAINS: 1, HexTileData.TerrainType.SAVANNA: 1,
	HexTileData.TerrainType.FOREST: 2, HexTileData.TerrainType.TAIGA: 2, HexTileData.TerrainType.JUNGLE: 2,
	HexTileData.TerrainType.TUNDRA: 3, HexTileData.TerrainType.HILLS: 4,
	HexTileData.TerrainType.SNOW: 5, HexTileData.TerrainType.ICE: 6,
	HexTileData.TerrainType.DESERT: 7, HexTileData.TerrainType.MOUNTAINS: 8,
	HexTileData.TerrainType.VOLCANIC_ROCK: 9, HexTileData.TerrainType.VOLCANIC_HILLS: 9, HexTileData.TerrainType.VOLCANIC_PEAKS: 9,
	HexTileData.TerrainType.VOLCANIC_ASH: 10,
	HexTileData.TerrainType.CRYSTAL: 11, HexTileData.TerrainType.CRYSTAL_PEAKS: 11, HexTileData.TerrainType.MYSTIC_SPRING: 11,
	HexTileData.TerrainType.MYSTIC_SOIL: 12, HexTileData.TerrainType.LAVA: 13,
}

static func surface_for(terrain_type: int) -> int:
	return LAYERS.get(terrain_type, 0)

static func reference_colors() -> PackedVector3Array:
	var colors := PackedVector3Array()
	for terrain_type in REFERENCES:
		var color := TerrainDatabase.create_tile(terrain_type).color
		colors.append(Vector3(color.r, color.g, color.b))
	return colors

static func apply_terrain(material: ShaderMaterial) -> bool:
	if not ResourceLoader.exists(ARRAY_PATH):
		material.set_shader_parameter("texture_strength", 0.0)
		return false
	var array := load(ARRAY_PATH) as Texture2DArray
	if array == null or array.get_layers() != SURFACES.size():
		material.set_shader_parameter("texture_strength", 0.0)
		return false
	material.set_shader_parameter("terrain_layers", array)
	material.set_shader_parameter("surface_reference_colors", reference_colors())
	material.set_shader_parameter("pixel_texture_scale", PIXELS_PER_WORLD_UNIT / SIZE)
	material.set_shader_parameter("pixel_terrain_enabled", true)
	return true

static func apply_liquid(material: ShaderMaterial) -> void:
	var path := DIR + "water_albedo.png"
	if not ResourceLoader.exists(path): return
	material.set_shader_parameter("pixel_water_tex", load(path))
	material.set_shader_parameter("pixel_water_scale", PIXELS_PER_WORLD_UNIT / SIZE)
	material.set_shader_parameter("pixel_water_mean_luma", WATER_MEAN_LUMA)
	material.set_shader_parameter("pixel_water_enabled", true)
