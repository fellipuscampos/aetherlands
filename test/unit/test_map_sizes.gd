extends GutTest

## Tamanhos de mapa (2026-10-10): Pequeno 96×56 / Médio 112×64 / Grande 128×72, cada um "uma versão menor do mesmo
## continente" (área reservada por tamanho + ruído em escala, WorldProfile). Saves antigos (144×76, 320×84) regeneram
## exatamente o mesmo mundo.

## Hash do terreno (coord, tipo, altura, recurso) capturado ANTES desta mudança, com a mesma função abaixo.
const LEGACY_HASHES := [
	[144, 76, 11, 990871122],
	[144, 76, 22, 3668940536],
	[144, 76, 33, 1039624815],
	[320, 84, 11, 1541257873],
]
const ESTIMATED_LAND := {"small": 1650, "medium": 2275, "large": 3000}
const SEEDS := [11, 22, 33, 44]

static func terrain_hash(grid: HexGrid) -> int:
	var coords: Array = grid.tiles.keys()
	coords.sort()
	var parts: Array = []
	for c in coords:
		var t: HexTileData = grid.tiles[c]
		parts.append([c.x, c.y, t.terrain_type, snappedf(t.base_height, 0.0001), t.resource])
	return hash(parts)

func _generate(profile: Dictionary, seed_value: int) -> HexGrid:
	var grid := HexGrid.new()
	add_child_autofree(grid)
	grid.generate_map(int(profile.width), int(profile.height), seed_value)
	return grid

func _land_biomes(grid: HexGrid) -> Dictionary:
	var counts := {}
	for coord in grid.tiles:
		var t: HexTileData = grid.tiles[coord]
		if not t.can_be_embarked_on():
			counts[t.terrain_type] = int(counts.get(t.terrain_type, 0)) + 1
	return counts

func test_old_saves_regenerate_exactly_the_same_world():
	for entry in LEGACY_HASHES:
		var grid := HexGrid.new()
		add_child_autofree(grid)
		grid.generate_map(entry[0], entry[1], entry[2])
		assert_eq(terrain_hash(grid), entry[3], "save antigo %dx%d seed %d: mesmo mundo de antes" % [entry[0], entry[1], entry[2]])
		grid.free()

func test_profiles_by_dimensions():
	for profile in WorldProfile.playable_sizes():
		assert_eq(WorldProfile.for_dimensions(profile.width, profile.height), profile, String(profile.id))
		var half := WorldProfile.main_half_extents(profile, profile.width, profile.height)
		var frame: Vector2i = profile.main_frame
		# O canto mais extremo da área reservada (paralelogramo axial) cabe na grade retangular (coluna offset odd-r).
		var corner_col := int(half.x) + int(half.y) / 2
		assert_lt(corner_col, int(profile.width) / 2 + 1, "%s: área reservada cabe na grade" % profile.id)
		assert_lt(frame.y, int(profile.height), "%s: sobra oceano em cima e embaixo" % profile.id)
	assert_eq(WorldProfile.default_size(), WorldProfile.MAP_LARGE, "partida nova: Grande")
	assert_eq(WorldProfile.for_dimensions(144, 76), WorldProfile.STANDARD_1_0, "legado 144x76")
	assert_eq(WorldProfile.for_dimensions(320, 84), WorldProfile.SPECIAL_CONTINENTS, "legado 320x84")
	assert_eq(WorldProfile.for_dimensions(41, 41), WorldProfile.TEST_FIXTURE)
	assert_eq(WorldProfile.for_dimensions(81, 81), WorldProfile.TEST_FIXTURE, "dimensões desconhecidas: regra antiga")
	assert_almost_eq(WorldProfile.noise_scale(WorldProfile.MAP_LARGE), 1.0, 0.0001)
	assert_almost_eq(WorldProfile.noise_scale(WorldProfile.STANDARD_1_0), 1.0, 0.0001, "legado sem escala")
	assert_gt(WorldProfile.noise_scale(WorldProfile.MAP_SMALL), WorldProfile.noise_scale(WorldProfile.MAP_MEDIUM))

func test_each_size_has_the_planned_land_inside_its_reserved_area():
	for profile in WorldProfile.playable_sizes():
		var land := 0
		var water := 0
		for seed_value in SEEDS:
			var grid := _generate(profile, seed_value)
			var half := WorldProfile.main_half_extents(profile, profile.width, profile.height)
			for coord in grid.tiles:
				if grid.tiles[coord].can_be_embarked_on():
					water += 1
				else:
					land += 1
					assert_true(absf(coord.x) <= half.x and absf(coord.y) <= half.y, "%s: terra só dentro da área reservada" % profile.id)
			grid.free()
		var average := float(land) / SEEDS.size()
		var expected := float(ESTIMATED_LAND[profile.id])
		assert_between(average, expected * 0.8, expected * 1.2, "%s: ~%d tiles de terra (medido %.0f)" % [profile.id, int(expected), average])
		var water_share := float(water) / float(land + water)
		assert_between(water_share, 0.6, 0.72, "%s: menos oceano que o antigo 73%% (medido %.1f%%)" % [profile.id, water_share * 100.0])

## A mesma lógica de biomas: a proporção de cada bioma de terra no Pequeno e no Médio fica perto da do Grande.
func test_every_size_keeps_the_same_biome_mix():
	var shares := {}
	for profile in WorldProfile.playable_sizes():
		var counts := {}
		var total := 0
		for seed_value in SEEDS:
			var grid := _generate(profile, seed_value)
			var biomes := _land_biomes(grid)
			for biome in biomes:
				counts[biome] = int(counts.get(biome, 0)) + int(biomes[biome])
				total += int(biomes[biome])
			grid.free()
		var share := {}
		for biome in counts:
			share[biome] = float(counts[biome]) / float(total)
		shares[profile.id] = share
	for size_id in ["small", "medium"]:
		for biome in shares.large:
			var name: String = HexTileData.TerrainType.keys()[biome]
			assert_almost_eq(float(shares[size_id].get(biome, 0.0)), float(shares.large[biome]), 0.035, "%s: %s na mesma proporção do Grande" % [size_id, name])

## "O mesmo continente, menor": com a mesma seed, terra/água em pontos NORMALIZADOS da área reservada coincidem.
func test_the_same_seed_draws_the_same_continent_at_every_size():
	for seed_value in [11, 33]:
		var large := _generate(WorldProfile.MAP_LARGE, seed_value)
		var large_half := WorldProfile.main_half_extents(WorldProfile.MAP_LARGE, 128, 72)
		for profile in [WorldProfile.MAP_SMALL, WorldProfile.MAP_MEDIUM]:
			var grid := _generate(profile, seed_value)
			var half := WorldProfile.main_half_extents(profile, profile.width, profile.height)
			var same := 0
			var samples := 0
			for iy in range(-8, 9):
				for ix in range(-12, 13):
					var u := float(ix) / 12.0 * 0.9
					var v := float(iy) / 8.0 * 0.9
					var a: HexTileData = grid.get_tile(Vector2i(roundi(u * half.x), roundi(v * half.y)))
					var b: HexTileData = large.get_tile(Vector2i(roundi(u * large_half.x), roundi(v * large_half.y)))
					if a == null or b == null:
						continue
					samples += 1
					if a.can_be_embarked_on() == b.can_be_embarked_on():
						same += 1
			assert_gt(float(same) / float(samples), 0.85, "%s seed %d: mesmo desenho de continente do Grande (%d/%d)" % [profile.id, seed_value, same, samples])
			grid.free()
		large.free()

## Partida completa em cada tamanho com o máximo de rivais: capitais em terra, afastadas, ecologia povoada.
func test_a_full_match_starts_cleanly_on_every_size():
	var original := [GameManager.map_width, GameManager.map_height, GameManager.rival_count, GameManager.hex_grid]
	for profile in WorldProfile.playable_sizes():
		var grid := HexGrid.new()
		add_child_autofree(grid)
		GameManager.map_width = int(profile.width)
		GameManager.map_height = int(profile.height)
		GameManager.rival_count = 3
		grid.generate_map(int(profile.width), int(profile.height), 2026)
		GameManager.start_new_game(grid)
		var capitals: Array[Vector2i] = []
		for player in GameManager.players:
			assert_false(player.cities.is_empty() and player.units.is_empty(), "%s: %s começou" % [profile.id, player.civ.civ_name])
			for unit in player.units:
				assert_false(grid.get_tile(unit.coord).blocks_land_units(), "%s: unidade inicial em terra" % profile.id)
			if not player.units.is_empty():
				capitals.append(player.units[0].coord)
		for i in capitals.size():
			for j in range(i + 1, capitals.size()):
				assert_true(HexMetrics.axial_distance(capitals[i], capitals[j]) >= WorldSetup.MIN_CAPITAL_DISTANCE, "%s: civs afastadas" % profile.id)
		assert_eq(GameManager.players.size(), 4, "%s: humano + 3 rivais" % profile.id)
		GameManager.end_match()
		grid.free()
	GameManager.map_width = original[0]
	GameManager.map_height = original[1]
	GameManager.rival_count = original[2]
	# start_new_game aponta GameManager.hex_grid para o grid desta partida (já liberado): devolve o original, senão o
	# próximo arquivo de teste herda uma referência morta.
	GameManager.hex_grid = original[3] if is_instance_valid(original[3]) else null

func test_the_new_game_screen_offers_the_three_sizes_and_defaults_to_large():
	var setup: GameSetupScreen = (load("res://scenes/ui/GameSetupScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(setup)
	assert_eq(setup.map_size_buttons.get_child_count(), 3)
	assert_eq(setup.selected_map_profile(), WorldProfile.MAP_LARGE, "padrão Grande")
	watch_signals(setup)
	setup._on_map_size_pressed("small")
	assert_true(setup.map_size_hint.text.contains("96 × 56"))
	setup.kingdom_name_edit.text = "Teste"
	setup._on_start_game_pressed()
	assert_signal_emitted(setup, "new_game_requested")
	var params: Array = get_signal_parameters(setup, "new_game_requested")
	assert_eq(params[0], 96)
	assert_eq(params[1], 56)
	setup.reset_to_defaults()
	assert_eq(setup.selected_map_profile(), WorldProfile.MAP_LARGE, "voltar ao padrão ao reabrir")
