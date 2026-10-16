extends GutTest

## Vegetação do mapa com o kit temperate_forest_v1: catálogo x manifesto, composição ecológica por bioma (NatureComposer)
## e o desenho/névoa/limpeza no mapa (NatureDecorManager).

const T := HexTileData.TerrainType
const MANIFEST := "res://assets/generated/nature/temperate_forest_v1/manifest.json"
const SAMPLES := 160

var _grids: Array[HexGrid] = []

func after_each() -> void:
	for grid in _grids:
		if is_instance_valid(grid):
			grid.free()
	_grids.clear()

func _fields(map_seed: int = 4242) -> Dictionary:
	return NatureComposer.make_fields(map_seed)

## Seis vizinhos nas direções pointy-top; `terrains` = bioma de cada lado (mesma ordem de `dirs`).
func _neighbors(terrains: Array) -> Array:
	var result: Array = []
	for i in 6:
		var angle := deg_to_rad(30.0 + 60.0 * i)
		result.append({"terrain": terrains[i], "dir": Vector2(cos(angle), sin(angle))})
	return result

func _context(terrain: int, coord: Vector2i, neighbor_terrains: Array = [], extra: Dictionary = {}) -> Dictionary:
	var context := {
		"coord": coord, "terrain": terrain, "has_resource": false, "world_xz": Vector2(coord.x * 1.73, coord.y * 1.5),
		"hex_size": 1.0, "neighbors": _neighbors(neighbor_terrains if not neighbor_terrains.is_empty() else [terrain, terrain, terrain, terrain, terrain, terrain]),
	}
	context.merge(extra, true)
	return context

func _compose_many(terrain: int, neighbor_terrains: Array = [], extra: Dictionary = {}) -> Array:
	var all: Array = []
	var fields := _fields()
	for i in SAMPLES:
		all.append(NatureComposer.compose_tile(_context(terrain, Vector2i(i % 40, i / 40), neighbor_terrains, extra), fields))
	return all

func _count_category(tiles: Array, category: String) -> int:
	var total := 0
	for items in tiles:
		for item in items:
			if NatureKitCatalog.category(item.asset) == category:
				total += 1
	return total

# --- Catálogo -----------------------------------------------------------------------------------------------------------

func test_the_catalog_matches_the_kit_manifest_and_every_mesh_loads():
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var listed := {}
	for entry in manifest.assets:
		listed[entry.asset] = true
		assert_true(NatureKitCatalog.ASSETS.has(entry.asset), "asset do manifesto fora do catálogo: %s" % entry.asset)
		var data: Dictionary = NatureKitCatalog.ASSETS[entry.asset]
		assert_eq(data.category, entry.category, entry.asset)
		assert_eq(data.species, entry.species, entry.asset)
		assert_almost_eq(float(data.footprint), float(entry.footprint_radius), 0.001, "raio de copa = manifesto: %s" % entry.asset)
		assert_almost_eq(float(data.height), float(entry.dimensions[2]), 0.01, entry.asset)
		assert_not_null(NatureKitCatalog.mesh(entry.asset), entry.asset)
	assert_eq(listed.size(), NatureKitCatalog.ASSETS.size(), "nenhum asset do catálogo sem entrada no manifesto")
	# Shader próprio (neve cosmética) que reproduz o material do kit: atlas e rugosidade do .tres, cor de instância
	# multiplicando o atlas e entrando no recorte de alfa (névoa).
	var material := NatureKitCatalog.map_material() as ShaderMaterial
	assert_not_null(material)
	var kit := load(NatureKitCatalog.MATERIAL_PATH) as StandardMaterial3D
	assert_eq(material.get_shader_parameter("albedo_texture"), kit.albedo_texture, "mesmo atlas do kit")
	assert_almost_eq(float(material.get_shader_parameter("roughness")), kit.roughness, 0.0001)
	var code := material.shader.code
	assert_true(code.contains("ALBEDO = albedo;") and code.contains("texel.rgb * COLOR.rgb"), "cor de instância (tintura/névoa) multiplica o atlas")
	assert_true(code.contains("ALPHA *= texel.a * COLOR.a;") and code.contains("ALPHA_SCISSOR_THRESHOLD = 0.5;"), "névoa: recorte de alfa; foco visual: multiplica a transparência da instância")
	assert_true(code.contains("filter_nearest_mipmap"), "pixel art: filtro nearest como o .tres (texture_filter 2)")
	assert_true(code.contains("global uniform float weather_snow_cover;"), "neve cosmética nas copas")
	var original := load(NatureKitCatalog.MATERIAL_PATH) as StandardMaterial3D
	assert_ne(original, material, "o material do kit nunca é modificado")
	assert_eq(original.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)

# --- Regras gerais da composição ----------------------------------------------------------------------------------------

func test_composition_is_deterministic_per_seed_and_tile():
	var context := _context(T.FOREST, Vector2i(7, 3))
	var first := NatureComposer.compose_tile(context, _fields(99))
	var again := NatureComposer.compose_tile(context, _fields(99))
	assert_eq(first.size(), again.size())
	for i in first.size():
		assert_eq([first[i].asset, first[i].local, first[i].angle, first[i].scale], [again[i].asset, again[i].local, again[i].angle, again[i].scale])
	var differs := false
	for map_seed in [1, 2, 3, 4, 5]:
		var other := NatureComposer.compose_tile(context, _fields(map_seed))
		differs = differs or other.size() != first.size() or (not other.is_empty() and not first.is_empty() and other[0].local != first[0].local)
	assert_true(differs, "outra seed, outra floresta")

func test_every_piece_fits_inside_the_hexagon_keeps_spacing_and_leaves_the_center_free():
	for terrain in NatureBiomeProfiles.PROFILES:
		for items in _compose_many(terrain):
			for i in items.size():
				var item: Dictionary = items[i]
				var radius := NatureKitCatalog.footprint(item.asset) * float(item.scale)
				assert_lte(item.local.length() + radius, NatureComposer.SQRT3_HALF - NatureComposer.EDGE_MARGIN + 0.0001, "dentro do tile: %s" % item.asset)
				var category := NatureKitCatalog.category(item.asset)
				if category in [NatureKitCatalog.MAIN_TREE, NatureKitCatalog.FALLEN_LOG]:
					assert_gte(item.local.length(), NatureComposer.CENTER_CLEARING - 0.0001, "copa/tronco fora do miolo da unidade")
				for j in range(i + 1, items.size()):
					var other: Dictionary = items[j]
					var other_radius := NatureKitCatalog.footprint(other.asset) * float(other.scale)
					assert_gte(item.local.distance_to(other.local), (radius + other_radius) * NatureComposer.UNDERSTORY_SPACING - 0.0001, "sem peças atravessadas")

func test_biomes_without_a_profile_and_resource_tiles_stay_bare():
	var fields := _fields()
	for terrain in [T.DESERT, T.SNOW, T.ICE, T.MOUNTAINS, T.OCEAN, T.VOLCANIC_ROCK, T.CRYSTAL, T.MYSTIC_SOIL, T.COAST]:
		assert_true(NatureComposer.compose_tile(_context(terrain, Vector2i(1, 1)), fields).is_empty(), "sem vegetação temperada: %d" % terrain)
	for i in 30:
		assert_true(NatureComposer.compose_tile(_context(T.FOREST, Vector2i(i, 0), [], {"has_resource": true}), fields).is_empty(), "o prop do recurso fica legível")

# --- Ecologia por bioma -------------------------------------------------------------------------------------------------

func test_taiga_is_a_pine_forest_and_jungle_is_broadleaf_only():
	var taiga := _compose_many(T.TAIGA)
	var pines := 0
	var trees := 0
	for items in taiga:
		for item in items:
			if NatureKitCatalog.category(item.asset) in [NatureKitCatalog.MAIN_TREE, NatureKitCatalog.SMALL_TREE]:
				trees += 1
				pines += 1 if NatureKitCatalog.species(item.asset) == "pine" else 0
	assert_gt(float(pines) / maxf(trees, 1), 0.8, "taiga: pinheiral")
	for items in _compose_many(T.JUNGLE):
		for item in items:
			assert_ne(NatureKitCatalog.species(item.asset), "pine", "selva sem coníferas")

func test_forests_are_dense_and_open_land_is_sparse():
	var forest := _compose_many(T.FOREST)
	var grassland := _compose_many(T.GRASSLAND)
	var forest_trees := _count_category(forest, NatureKitCatalog.MAIN_TREE) + _count_category(forest, NatureKitCatalog.SMALL_TREE)
	var grass_trees := _count_category(grassland, NatureKitCatalog.MAIN_TREE) + _count_category(grassland, NatureKitCatalog.SMALL_TREE)
	assert_gt(forest_trees, grass_trees * 4, "floresta >> campo aberto")
	var bare := grassland.filter(func(items): return items.is_empty()).size()
	assert_gt(bare, SAMPLES / 2, "a maior parte da planície é campo aberto")
	assert_eq(_count_category(_compose_many(T.PLAINS), NatureKitCatalog.MAIN_TREE), 0, "estepe seca: sem árvore de copa")
	assert_gt(_count_category(_compose_many(T.HILLS), NatureKitCatalog.DECORATION), 0, "colinas: afloramentos de pedra")

func test_low_density_forest_becomes_a_clearing():
	var clearing := _compose_many(T.FOREST, [], {"density": 0.05})
	var dense := _compose_many(T.FOREST, [], {"density": 0.95})
	assert_eq(_count_category(clearing, NatureKitCatalog.MAIN_TREE), 0, "clareira: sem copas")
	assert_gt(_count_category(clearing, NatureKitCatalog.SHRUB), 0, "clareira mantém sub-bosque")
	assert_gt(_count_category(dense, NatureKitCatalog.MAIN_TREE), SAMPLES * 2, "bosque fechado")

func test_species_noise_forms_coherent_conifer_and_beech_stands_in_mixed_forest():
	var conifer := _compose_many(T.FOREST, [], {"species": 0.9, "density": 0.8})
	var beech := _compose_many(T.FOREST, [], {"species": 0.1, "density": 0.8})
	var share := func(tiles: Array, wanted: String) -> float:
		var hits := 0
		var total := 0
		for items in tiles:
			for item in items:
				if NatureKitCatalog.category(item.asset) == NatureKitCatalog.MAIN_TREE:
					total += 1
					hits += 1 if NatureKitCatalog.species(item.asset) == wanted else 0
		return float(hits) / maxf(total, 1)
	assert_gt(share.call(conifer, "pine"), 0.5, "talhão de pinheiro")
	assert_gt(share.call(beech, "beech"), share.call(conifer, "beech"), "faial onde o ruído de espécie é baixo")

func test_the_forest_fringe_grows_young_trees_toward_the_woods():
	# Planície com floresta só do lado leste (direções 0 e 5 apontam para +X).
	var east_forest := [T.FOREST, T.GRASSLAND, T.GRASSLAND, T.GRASSLAND, T.GRASSLAND, T.FOREST]
	var fringe := _compose_many(T.GRASSLAND, east_forest)
	var isolated := _compose_many(T.GRASSLAND)
	assert_gt(fringe.filter(func(items): return not items.is_empty()).size(), isolated.filter(func(items): return not items.is_empty()).size(), "a borda da mata tem mais vegetação")
	var toward := 0.0
	var young := 0
	for items in fringe:
		for item in items:
			if NatureKitCatalog.category(item.asset) == NatureKitCatalog.SMALL_TREE:
				young += 1
				toward += item.local.x
	assert_gt(young, 0, "regeneração na borda")
	assert_gt(toward / maxf(young, 1), 0.05, "as árvores jovens ficam do lado da floresta")
	var taiga_fringe := _compose_many(T.GRASSLAND, [T.TAIGA, T.GRASSLAND, T.GRASSLAND, T.GRASSLAND, T.GRASSLAND, T.TAIGA])
	var young_pines := 0
	var young_oaks := 0
	for items in taiga_fringe:
		for item in items:
			if NatureKitCatalog.category(item.asset) == NatureKitCatalog.SMALL_TREE:
				young_pines += 1 if item.asset == "tree_pine_young" else 0
				young_oaks += 1 if item.asset == "tree_oak_young" else 0
	assert_gt(young_pines, young_oaks, "a borda herda a família da mata vizinha: taiga -> pinheiros jovens")

func test_forest_edges_thin_out_and_retreat_from_open_land():
	var edge := _compose_many(T.FOREST, [T.GRASSLAND, T.GRASSLAND, T.GRASSLAND, T.FOREST, T.FOREST, T.GRASSLAND], {"density": 0.8})
	var interior := _compose_many(T.FOREST, [], {"density": 0.8})
	assert_lt(_count_category(edge, NatureKitCatalog.MAIN_TREE), _count_category(interior, NatureKitCatalog.MAIN_TREE), "menos copas na borda")
	var side := 0.0
	var count := 0
	for items in edge:
		for item in items:
			if NatureKitCatalog.category(item.asset) == NatureKitCatalog.MAIN_TREE:
				side += item.local.x
				count += 1
	assert_lt(side / maxf(count, 1), 0.0, "as copas recuam para o lado da mata (oeste)")

# --- Mapa -----------------------------------------------------------------------------------------------------------------

func _grid(map_seed: int = 5150) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	_grids.append(grid)
	grid.generate_map(25, 25, map_seed)
	return grid

func test_the_map_uses_the_kit_and_every_instance_sits_on_its_tile_surface():
	var grid := _grid()
	var decor := grid.nature_decor
	assert_gt(decor.instance_count(), 0, "o mapa tem vegetação")
	var assets := {}
	for coord in decor.decorated_coords():
		var tile := grid.get_tile(coord)
		assert_true(NatureBiomeProfiles.has_vegetation(tile.terrain_type), "vegetação só em bioma com perfil")
		assert_eq(tile.resource, "", "nunca sobre recurso")
		var expected := decor.compose(coord)
		var placed := 0
		for pair in decor.sources_at(coord):
			placed += (pair[1] as Array).size()
			assets[(pair[0] as MultiMeshInstance3D).multimesh.mesh] = true
			assert_eq((pair[0] as MultiMeshInstance3D).material_override, NatureKitCatalog.map_material())
		assert_eq(placed, expected.size(), "o desenho é exatamente a composição do tile")
		assert_lte(placed, 12, "orçamento de instâncias por tile")
	assert_gt(assets.size(), 3, "várias espécies/props do kit em uso, não uma árvore repetida")
	var hill := Vector2i(-999, -999)
	for coord in grid.tiles:
		if grid.get_tile(coord).terrain_type == T.HILLS:
			hill = coord
			break
	if hill != Vector2i(-999, -999):
		assert_almost_eq(grid.surface_height_at(hill, Vector2.ZERO), grid.surface_height_at(hill, Vector2(0.8, 0.0)), 0.0001, "colina tem topo plano: a vegetação fica na mesma altura do centro à borda")

func test_fog_clearing_and_terrain_change_follow_the_tile():
	var grid := _grid()
	var decor := grid.nature_decor
	var coord: Vector2i = decor.decorated_coords()[0]
	# (RenderingServer headless não devolve cores de MultiMesh: verifica a regra e o estado aplicado por tile.)
	var tint := Color(0.86, 0.94, 0.92)
	assert_eq(decor.fog_color(tint, HexGrid.Visibility.UNSEEN).a, 0.0, "não explorado: invisível")
	assert_eq(decor.fog_color(tint, HexGrid.Visibility.VISIBLE), tint, "visível: a tintura do bioma")
	assert_eq(decor.fog_color(tint, HexGrid.Visibility.EXPLORED), grid._memory_prop_color(tint), "explorado: a tintura sob o filtro de memória")
	decor.apply_fog({})
	assert_eq(decor.fog_state(coord), HexGrid.Visibility.UNSEEN)
	decor.apply_fog({coord: HexGrid.Visibility.EXPLORED})
	assert_eq(decor.fog_state(coord), HexGrid.Visibility.EXPLORED, "a névoa alcança o tile inteiro")
	grid._clear_tree_props_at(coord)
	assert_false(decor.has_decor(coord), "cidade/prédio/unidade limpam a vegetação do tile")
	# Terreno transformado por magia: a vegetação vira a do bioma novo, determinística.
	var target := Vector2i(-999, -999)
	for other in grid.tiles:
		if grid.get_tile(other).resource == "" and grid.get_tile(other).is_usable_land() and not grid.get_tile(other).blocks_land_units() and not decor.has_decor(other):
			target = other
			break
	assert_ne(target, Vector2i(-999, -999))
	grid.tiles[target] = TerrainDatabase.create_tile(T.JUNGLE)
	var expected := decor.compose(target)
	decor.refresh_tile(target)
	var placed := 0
	for source in decor.sources_at(target):
		placed += (source[1] as Array).size()
		assert_ne(NatureKitCatalog.species(_asset_of((source[0] as MultiMeshInstance3D).multimesh.mesh)), "pine", "selva nova sem pinheiro")
	assert_eq(placed, expected.size())
	decor.refresh_tile(target)
	var again := 0
	for source in decor.sources_at(target):
		again += (source[1] as Array).size()
	assert_eq(again, expected.size(), "recompor de novo não duplica")

func _asset_of(mesh: Mesh) -> String:
	for asset in NatureKitCatalog.ASSETS:
		if NatureKitCatalog.mesh(asset) == mesh:
			return asset
	return ""

func test_lair_clearing_survives_terrain_refresh_rebuild_and_reoccupation():
	var grid := _grid()
	var decor := grid.nature_decor
	var coord: Vector2i = decor.decorated_coords()[0]
	var original_count := decor.compose(coord).size()
	assert_gt(original_count, 0)
	grid.create_lair(coord, "goblin", HexGrid.LAIR_ROLE_ECOLOGY)
	assert_false(decor.has_decor(coord), "criar estrutura limpa a vegetação existente")
	decor.refresh_tile(coord)
	assert_false(decor.has_decor(coord), "atualizar terreno não replanta em cima")
	decor.rebuild(grid.tiles)
	assert_false(decor.has_decor(coord), "reconstrução completa respeita o covil")
	grid.remove_lair_silently(coord, false)
	decor.refresh_tile(coord)
	assert_eq(decor.compose(coord).size(), original_count, "tile liberado volta a poder ter vegetação")
	assert_true(decor.has_decor(coord))
	grid.create_lair(coord, "skeleton", HexGrid.LAIR_ROLE_ECOLOGY)
	assert_false(decor.has_decor(coord), "reocupação limpa novamente")

func test_seed_lairs_never_keep_trees_in_the_structure_tile():
	var grid := _grid(5150)
	for coord in grid.lairs_by_coord:
		assert_false(grid.nature_decor.has_decor(coord), "covil original também passa pela limpeza central")

func test_resource_prop_and_badge_do_not_reappear_inside_a_lair_on_rebuild():
	var grid := _grid()
	var coord: Vector2i = grid.nature_decor.decorated_coords()[0]
	grid.get_tile(coord).resource = "iron"
	grid._rebuild_props()
	assert_true(grid._resource_props_manager._coord_to_index.get("iron", {}).has(coord))
	assert_true(grid._resource_icon_manager._sprites.has(coord))
	grid.create_lair(coord, "goblin", HexGrid.LAIR_ROLE_REGIONAL)
	grid._rebuild_props()
	grid._resource_icon_manager.refresh_tile(coord)
	assert_false(grid.nature_decor.has_decor(coord))
	assert_false(grid._resource_props_manager._coord_to_index.get("iron", {}).has(coord))
	assert_false(grid._resource_icon_manager._sprites.has(coord))
	assert_eq(grid.get_tile(coord).resource, "iron", "o recurso lógico não é apagado pela apresentação")
	grid.destroy_lair(coord)
	grid._rebuild_props()
	assert_true(grid._resource_props_manager._coord_to_index.get("iron", {}).has(coord))
	assert_true(grid._resource_icon_manager._sprites.has(coord))
