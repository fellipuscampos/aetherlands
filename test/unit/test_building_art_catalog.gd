extends GutTest

## Arte de prédios/centros por raça (BuildingArtCatalog): o catálogo precisa apontar para assets
## reais, do prédio certo, na escala do tile, e o mapa precisa usar a arte do dono ATUAL.

const RACES := ["human", "dwarf", "elf", "orc"]
const ECONOMY := ["v2_building_market", "v2_building_farm", "v2_building_workshop", "v2_building_academy", "v2_building_arcane_shrine"]
## Base pointy-top de raio 0,92 dentro do tile de raio 1 (apótema 0,866): 1,5935 × 1,84.
const MAX_FOOTPRINT := Vector2(1.6, 1.85)

## Estes testes verificam prédios; a árvore KayKit usada pelo mapa é um recurso independente.
class BuildingTestGrid extends HexGrid:
	func _load_tree_mesh() -> Mesh:
		var primitive := BoxMesh.new()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.surface_get_arrays(0))
		return mesh

var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String, color: Color = Color(.7, .2, .2)) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	civ.color = color
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _grid(width: int) -> HexGrid:
	var grid := BuildingTestGrid.new()
	add_child_autofree(grid)
	for q in range(width):
		var tile := HexTileData.new()
		tile.base_height = .02
		grid.tiles[Vector2i(q, 0)] = tile
	return grid

func _report(path: String) -> Dictionary:
	var report_path := path.get_basename() + "_report.json"
	if not FileAccess.file_exists(report_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	return parsed if parsed is Dictionary else {}

func _footprint(model: Node3D) -> AABB:
	var total := AABB()
	var first := true
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var relative := part.transform
		var ancestor := part.get_parent() as Node3D
		while ancestor != null and ancestor != model:
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent() as Node3D
		var bounds: AABB = relative * part.get_aabb()
		total = bounds if first else total.merge(bounds)
		first = false
	return total

func test_every_doctrine_and_magic_building_has_art_for_every_race() -> void:
	for building: BuildingData in BuildingDatabase.all_buildings():
		assert_true(BuildingArtCatalog.BUILDING_ART.has(building.id), "%s sem arte no catálogo" % building.id)
		for race in RACES:
			assert_true(BuildingArtCatalog.BUILDING_ART[building.id].has(race), "%s sem arte %s" % [building.id, race])
	for id in BuildingArtCatalog.BUILDING_ART:
		assert_not_null(BuildingDatabase.get_building(id), "catálogo cita prédio inexistente: %s" % id)

func test_catalogue_paths_load_match_their_report_and_fit_the_tile() -> void:
	var checked := 0
	for id in BuildingArtCatalog.BUILDING_ART:
		for race in RACES:
			var path := BuildingArtCatalog.building_model_path(id, race)
			assert_true(path.contains("/%s/" % BuildingArtCatalog.RACE_FOLDERS[race]), "%s/%s cai na pasta da raça" % [id, race])
			var scene := load(path) as PackedScene
			assert_not_null(scene, path)
			if scene == null:
				continue
			assert_eq(_report(path).get("gameplay_building_id", ""), id, "o asset é do prédio certo: %s" % path)
			var model := scene.instantiate() as Node3D
			var bounds := _footprint(model)
			model.free()
			assert_lte(bounds.size.x, MAX_FOOTPRINT.x, "largura dentro do tile: %s" % path)
			assert_lte(bounds.size.z, MAX_FOOTPRINT.y, "profundidade dentro do tile: %s" % path)
			assert_almost_eq(bounds.position.y, 0.0, .02, "apoiado no chão: %s" % path)
			checked += 1
	for race in RACES:
		for level in BuildingArtCatalog.CITY_ART[race]:
			var path := BuildingArtCatalog.city_model_path(level, race)
			assert_not_null(load(path) as PackedScene, path)
			assert_eq(_report(path).get("gameplay_building_id", ""), "city_center_level_%d" % level, path)
	assert_eq(checked, BuildingArtCatalog.BUILDING_ART.size() * RACES.size())

## Pega o asset exportado e esquecido: todo *_report.json de prédio de jogo precisa estar no catálogo
## (versões substituídas da mesma raça contam como cobertas pelo id).
func test_every_exported_race_building_is_registered() -> void:
	for race in RACES:
		var root := "res://assets/generated/%s/buildings" % BuildingArtCatalog.RACE_FOLDERS[race]
		for folder in DirAccess.get_directories_at(root):
			var report := _report("%s/%s/%s.glb" % [root, folder, folder])
			var id: String = report.get("gameplay_building_id", "")
			if id.begins_with("city_center_level_"):
				var level := int(id.trim_prefix("city_center_level_"))
				assert_true(BuildingArtCatalog.CITY_ART[race].has(level), "centro %s nível %d não registrado" % [race, level])
			elif id != "":
				assert_true(BuildingArtCatalog.BUILDING_ART.get(id, {}).has(race), "%s exportado mas não registrado (%s)" % [folder, race])

func test_unknown_or_missing_race_uses_human_art() -> void:
	var human := BuildingArtCatalog.building_model_path("v2_building_warrior_hall", "human")
	assert_eq(BuildingArtCatalog.race_of(null), "human")
	assert_eq(BuildingArtCatalog.race_of(_player("")), "human")
	assert_eq(BuildingArtCatalog.building_model_path("v2_building_warrior_hall", "goblin"), human)
	assert_eq(BuildingDatabase.get_building("v2_building_warrior_hall").model_scene_path, human, "padrão do BuildingData = humano")
	assert_ne(BuildingDatabase.model_path_for("v2_building_market", "dwarf"), BuildingDatabase.get_building("v2_building_market").model_scene_path)
	assert_eq(BuildingDatabase.model_path_for("id_inexistente", "dwarf"), "")

func test_city_levels_without_race_art_keep_the_race_identity() -> void:
	for race in ["dwarf", "elf", "orc"]:
		var own_first := BuildingArtCatalog.city_model_path(1, race)
		assert_true(own_first.contains("/%s/" % BuildingArtCatalog.RACE_FOLDERS[race]))
		for level in [2, 3, 4]:
			if not BuildingArtCatalog.CITY_ART[race].has(level):
				assert_eq(BuildingArtCatalog.city_model_path(level, race), BuildingArtCatalog.city_model_path(level - 1, race), "%s %d usa o maior nível próprio" % [race, level])
	assert_true(BuildingArtCatalog.city_model_path(4, "human").ends_with("city_level_4_hex_v1.glb"))

func test_map_buildings_use_the_owner_race_and_follow_capture() -> void:
	var grid := _grid(1)
	var coord := Vector2i.ZERO
	var orc := _player("orc", Color(.8, .15, .1))
	var building := grid.place_building(coord, "v2_building_arcane_conclave", orc)
	var model := building.get_child(0) as Node3D
	var orc_path := BuildingArtCatalog.building_model_path("v2_building_arcane_conclave", "orc")
	assert_eq(model.scene_file_path, orc_path)
	assert_eq(model.scale, Vector3.ONE, "arte própria em escala nativa do tile")
	var faction := model.find_children("*_Faction", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var shared := faction.mesh.surface_get_material(0) as StandardMaterial3D
	var shared_color := shared.albedo_color
	assert_eq((faction.material_override as StandardMaterial3D).albedo_color, orc.civ.color.lightened(.1))
	assert_eq(shared.albedo_color, shared_color, "material importado compartilhado intacto")
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not part.name.ends_with("_Faction"):
			assert_null(part.material_override, "arquitetura mantém o atlas pintado")
	# Captura e load recriam o prédio via place_building com o novo dono.
	var dwarf := _player("dwarf", Color(.2, .4, .8))
	var recreated := grid.place_building(coord, "v2_building_arcane_conclave", dwarf, false)
	await get_tree().process_frame
	assert_eq(recreated.get_child(0).scene_file_path, BuildingArtCatalog.building_model_path("v2_building_arcane_conclave", "dwarf"))

func test_infrastructure_uses_owner_architecture_and_native_scale_for_every_race() -> void:
	var grid := _grid(1)
	for race in RACES:
		var owner := _player(race)
		for id in ECONOMY:
			var building := grid.place_building(Vector2i.ZERO, id, owner, false)
			var model := building.get_child(0) as Node3D
			var path := BuildingArtCatalog.building_model_path(id, race)
			assert_true(BuildingArtCatalog.is_generated(path))
			assert_eq(model.scene_file_path, path)
			assert_eq(model.scale, Vector3.ONE)
			var report := _report(path)
			assert_eq(report.get("civilization"), race)
			assert_true(report.get("infrastructure", {}).get("single_version", false))
			assert_eq(report.get("infrastructure", {}).get("evolutions", ["missing"]), [])
			assert_eq(BuildingDatabase.get_building(id).copy_limit_mode, BuildingData.CopyLimitMode.CITY_LEVEL)
			var faction := model.find_children("*_Faction", "MeshInstance3D", true, false)
			assert_eq(faction.size(), 1)
			if not faction.is_empty():
				assert_eq((faction[0].material_override as StandardMaterial3D).albedo_color, owner.civ.color.lightened(.1))
			await get_tree().process_frame

func test_city_center_uses_owner_race_and_switches_on_capture() -> void:
	var elf := _player("elf", Color(.2, .7, .3))
	var city := City.new()
	add_child_autofree(city)
	city.setup(elf, Vector2i.ZERO, "Elenor", 1.0)
	var center := city._buildings_root.get_node("CityCenterModel") as Node3D
	assert_eq(center.scene_file_path, BuildingArtCatalog.city_model_path(1, "elf"))
	city.change_owner(_player("orc", Color(.8, .1, .1)))
	await get_tree().process_frame
	center = city._buildings_root.get_node("CityCenterModel") as Node3D
	assert_eq(center.scene_file_path, BuildingArtCatalog.city_model_path(1, "orc"), "a cidade capturada adota a arte do novo dono")
	city.apply_city_level(4)
	await get_tree().process_frame
	center = city._buildings_root.get_node("CityCenterModel") as Node3D
	assert_eq(center.scene_file_path, city.city_center_model_path())
	assert_true(center.scene_file_path.contains("/orcs/"), "nível sem arte orc continua orc, nunca castelo humano")
