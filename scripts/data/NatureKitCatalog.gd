class_name NatureKitCatalog
extends RefCounted

## Kit de natureza "temperate_forest_v1" (assets/generated/nature/temperate_forest_v1, criado no Blender MCP): os dez
## assets que compõem a vegetação do mapa (NatureComposer decide ONDE; NatureDecorManager desenha). Dado puro.
##
## Os números vêm do manifest.json do kit (raio conservador da copa = `footprint_radius`, altura = dimensão Z do
## Blender, escala nativa 1.0 no tile de raio 1). test_nature_composition.gd cruza esta tabela com o manifesto, então
## um asset reexportado com outra medida falha no teste em vez de invadir o tile vizinho em jogo.

const KIT_DIR := "res://assets/generated/nature/temperate_forest_v1"
const MATERIAL_PATH := KIT_DIR + "/godot/forest_pixel_material.tres"

## Categorias ecológicas (a ordem de composição de NatureComposer segue esta hierarquia).
const MAIN_TREE := "main_tree"   # copa dominante
const SMALL_TREE := "small_tree" # regeneração / árvores jovens
const SHRUB := "shrub"           # sub-bosque
const FALLEN_LOG := "fallen_log" # chão de floresta madura
const DECORATION := "decoration" # pedras/raízes

## asset -> {category, species, footprint (raio da copa em unidades do mapa), height}
const ASSETS := {
	"tree_oak_a": {"category": MAIN_TREE, "species": "oak", "footprint": 0.344093, "height": 0.92},
	"tree_oak_b": {"category": MAIN_TREE, "species": "oak", "footprint": 0.322490, "height": 1.04},
	"tree_beech_a": {"category": MAIN_TREE, "species": "beech", "footprint": 0.282843, "height": 1.08},
	"tree_pine_a": {"category": MAIN_TREE, "species": "pine", "footprint": 0.256125, "height": 1.16},
	"tree_oak_young": {"category": SMALL_TREE, "species": "oak", "footprint": 0.200000, "height": 0.64},
	"tree_pine_young": {"category": SMALL_TREE, "species": "pine", "footprint": 0.200000, "height": 0.76},
	"shrub_hazel": {"category": SHRUB, "species": "hazel", "footprint": 0.200000, "height": 0.28},
	"shrub_bracken": {"category": SHRUB, "species": "underbrush", "footprint": 0.203961, "height": 0.20},
	"fallen_log": {"category": FALLEN_LOG, "species": "oak", "footprint": 0.329848, "height": 0.16},
	"rock_root_small": {"category": DECORATION, "species": "stone_root", "footprint": 0.178885, "height": 0.20},
}

static var _meshes: Dictionary = {}
static var _material: Material = null

static func mesh_path(asset: String) -> String:
	return "%s/godot/%s.res" % [KIT_DIR, asset]

static func category(asset: String) -> String:
	return String(ASSETS[asset].category)

static func species(asset: String) -> String:
	return String(ASSETS[asset].species)

static func footprint(asset: String) -> float:
	return float(ASSETS[asset].footprint)

## Assets de uma categoria (ordem estável, pela tabela).
static func assets_in(category_id: String) -> Array[String]:
	var result: Array[String] = []
	for asset in ASSETS:
		if ASSETS[asset].category == category_id:
			result.append(asset)
	return result

## Malha compartilhada (uma por asset, em cache): o MultiMesh de cada asset reaproveita a mesma.
static func mesh(asset: String) -> Mesh:
	if not _meshes.has(asset):
		_meshes[asset] = load(mesh_path(asset)) as Mesh if ResourceLoader.exists(mesh_path(asset)) else null
	return _meshes[asset]

## Material do mapa: `shaders/nature_kit.gdshader`, que reproduz o material do kit (atlas pixelado × cor por
## vértice/instância, recorte de alfa 0,5 — a névoa de guerra zera o alfa da cor de instância, mesma convenção binária
## dos outros props) e acrescenta a neve cosmética do clima (`weather_snow_cover`). Atlas e rugosidade vêm do .tres do
## kit, que nunca é modificado. Instância única, compartilhada por todos os MultiMesh da vegetação.
const MAP_SHADER_PATH := "res://shaders/nature_kit.gdshader"

static func map_material() -> Material:
	if _material == null:
		var base := load(MATERIAL_PATH) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = load(MAP_SHADER_PATH) as Shader
		if base != null:
			material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("roughness", base.roughness)
		_material = material
	return _material
