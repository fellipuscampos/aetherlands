extends GutTest

## Névoa de guerra refeita (2026-10-12) — pedido do usuário:
##  - "tem coisas que aparecem rapidamente entre as viradas de turno pela fog, que deviam estar ocultas";
##  - "a fog foi feita de forma errada por ser uma textura sobre a superfície; ela devia ser algo acima do mapa
##    cobrindo o chão, assim não dá pra ver nada do que tem embaixo, como se fosse uma camada realmente";
##  - área explorada: "dá pra ver o chão, as árvores, recursos do mapa, porém sem ícones, sem dar pra ver os monstros,
##    sem ver o mapa ali sendo atualizado... um filtro mais escuro";
##  - "ela precisa continuar leve".
## Cobre o estado exato por tile, a camada física (FogLayer), o filtro de memória e a regra única de visibilidade das
## entidades aplicada no instante em que nascem ou se movem (inclusive no turno real, com a fila de IA escalonada).

const RADIUS := 12
const FAR := Vector2i(9, 0) # fora da visão do jogador, que começa em (0, 0)
const NEAR := Vector2i(1, 0)

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var scout: Unit
var _original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-RADIUS, RADIUS + 1):
		for r in range(-RADIUS, RADIUS + 1):
			if absi(q + r) <= RADIUS:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	grid.tiles[Vector2i(-3, 5)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.tiles[Vector2i(5, -5)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid._rebuild_multimesh() # terreno, água, props, camada de névoa e estado por tile — como generate_map faz
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.debug_mode = false
	TurnManager.turn_number = 1

func after_each():
	SelectionManager.reset()
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	for player in [human, rival]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

## O jogador põe um batedor no centro e a névoa é calculada: daí em diante existe "o que ele vê agora".
func _look() -> void:
	scout = grid.spawn_unit(Vector2i.ZERO, UnitDatabase.create_unit("warrior"), human)
	grid.recompute_fog(human)

func _state_byte(coord: Vector2i) -> int:
	return grid._fog_state_bytes[grid._fog_state_pixel(coord)]

# --- Estado exato por tile -------------------------------------------------------------------------------------------

func test_every_tile_has_its_own_texel_in_any_map_shape():
	var seen := {}
	for coord in grid.tiles:
		var pixel := grid._fog_state_pixel(coord)
		assert_true(pixel >= 0 and pixel < grid._fog_state_bytes.size(), "tile %s dentro da grade" % coord)
		assert_false(seen.has(pixel), "um texel por tile, sem dois tiles no mesmo")
		seen[pixel] = true
	assert_eq(grid._fog_state_pixel(Vector2i(500, 500)), -1, "fora do mapa não tem texel")
	assert_eq(grid._fog_state_texture.get_width(), grid._fog_grid_size.x)
	assert_eq(grid._fog_state_texture.get_height(), grid._fog_grid_size.y)

func test_the_state_texture_follows_the_three_fog_states():
	assert_eq(_state_byte(Vector2i.ZERO), 0, "mapa recém-criado: tudo nunca visto")
	_look()
	assert_eq(_state_byte(Vector2i.ZERO), 255, "visível agora")
	assert_eq(_state_byte(FAR), 0, "nunca visto")
	grid.teleport_unit(scout, Vector2i(-8, 0))
	grid.recompute_fog(human)
	assert_eq(_state_byte(Vector2i.ZERO), 128, "explorado: já visto, fora da visão agora")
	assert_eq(_state_byte(Vector2i(-8, 0)), 255)
	var terrain_material := grid._multimesh_instance.material_override as ShaderMaterial
	for material in [terrain_material, grid.fog_layer.material()]:
		assert_same(material.get_shader_parameter("fog_state_texture"), grid._fog_state_texture, "terreno e camada leem a MESMA textura")
		assert_eq(material.get_shader_parameter("fog_grid_size"), Vector2(grid._fog_grid_size))

# --- Camada física ----------------------------------------------------------------------------------------------------

func test_the_layer_covers_exactly_the_tiles_never_seen():
	assert_eq(grid.fog_layer.covered_count(), grid.tiles.size(), "partida nova: o mapa inteiro sob a camada")
	_look()
	var unseen := 0
	for coord in grid.tiles:
		var covered: bool = grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.UNSEEN
		assert_eq(grid.fog_layer.covers(coord), covered, "tile %s" % coord)
		unseen += 1 if covered else 0
	assert_eq(grid.fog_layer.covered_count(), unseen)
	assert_false(grid.fog_layer.covers(Vector2i.ZERO))
	assert_true(grid.fog_layer.covers(FAR))
	grid.teleport_unit(scout, Vector2i(-8, 0))
	grid.recompute_fog(human)
	assert_false(grid.fog_layer.covers(Vector2i.ZERO), "tile explorado não volta a ficar sob a camada")

func test_the_layer_sits_above_the_ground_and_the_sea_and_is_built_once():
	assert_gt(FogLayer.TOP_Y, 0.3, "acima do chão comum (Colina fica em 0,3)")
	assert_lt(FogLayer.BOTTOM_Y, HexGrid.LIQUID_LEVEL_Y, "as paredes descem abaixo do plano de água: nada aparece por baixo")
	var chunk := grid.fog_layer.get_child(0) as MultiMeshInstance3D
	assert_eq(chunk.material_override, grid.fog_layer.material(), "um material só para a camada inteira")
	assert_eq(chunk.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "sem passada de sombra")
	assert_eq(chunk.multimesh.mesh.get_faces().size() / 3, 18, "18 triângulos por bloco: tampa + 6 paredes")
	var instances := 0
	for child in grid.fog_layer.get_children():
		instances += (child as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(instances, grid.tiles.size(), "um bloco por tile, nenhum criado ou destruído depois")
	_look()
	assert_eq(grid.fog_layer.get_child_count(), grid.fog_layer.chunk_count(), "mudar a névoa não cria nós")

func test_a_chunk_with_nothing_left_to_hide_is_switched_off():
	assert_eq(grid.fog_layer.active_chunk_count(), grid.fog_layer.chunk_count())
	assert_gt(grid.fog_layer.chunk_count(), 1, "o mapa é dividido em pedaços (culling por câmera)")
	grid.debug_fog_disabled = true
	grid.recompute_fog(human)
	assert_eq(grid.fog_layer.covered_count(), 0)
	assert_eq(grid.fog_layer.active_chunk_count(), 0, "mapa todo revelado: a camada não custa nada")

func test_the_shaders_hide_what_is_under_the_layer_instead_of_painting_fog():
	var terrain := FileAccess.get_file_as_string("res://shaders/terrain.gdshader")
	var water := FileAccess.get_file_as_string("res://shaders/water_shader.gdshader")
	var layer := FileAccess.get_file_as_string("res://shaders/fog_layer.gdshader")
	for source in [terrain, layer]:
		assert_string_contains(source, "#include \"res://shaders/fog_state.gdshaderinc\"")
	assert_string_contains(terrain, "if (fog_tile_is_unseen(MODEL_MATRIX[3].xz)) {", "o prisma de um tile nunca visto é recolhido")
	assert_string_contains(layer, "VERTEX = vec3(0.0);", "o bloco de um tile conhecido é recolhido")
	assert_string_contains(layer, "depth_draw_opaque", "a camada é opaca e escreve profundidade")
	for source in [terrain, water]:
		assert_false(source.contains("fog_cloud") or source.contains("sepia") or source.contains("fog_flatten"), "a névoa pintada no terreno/água saiu")
		assert_string_contains(source, "float memory = 1.0 - smoothstep(0.5, 1.0, fog_level);", "filtro escuro só na área explorada")

# --- Área explorada: o mapa de verdade sob um filtro escuro --------------------------------------------------------------

func test_memory_is_a_darker_filter_that_keeps_the_real_colors():
	var grass := Color(0.3, 0.7, 0.2)
	var remembered := grid._memory_prop_color(grass)
	assert_lt(remembered.get_luminance(), grass.get_luminance() * 0.6, "mais escuro")
	assert_gt(remembered.get_luminance(), grass.get_luminance() * 0.25, "sem virar breu: dá para ler o mapa")
	assert_gt(remembered.g, remembered.r, "verde continua verde (antes virava sépia/cinza)")
	assert_eq(remembered.a, 1.0)
	var tint := Vector3(HexGrid.MEMORY_TINT.r, HexGrid.MEMORY_TINT.g, HexGrid.MEMORY_TINT.b)
	assert_eq((grid._multimesh_instance.material_override as ShaderMaterial).get_shader_parameter("fog_memory_tint"), tint, "terreno usa o mesmo filtro")
	assert_eq((grid._liquid_plane_instance.material_override as ShaderMaterial).get_shader_parameter("fog_memory_tint"), tint, "água usa o mesmo filtro")

func test_resource_icons_show_only_in_current_vision_but_the_resource_stays_on_the_map():
	var spot := Vector2i(2, 0)
	grid.get_tile(spot).resource = "iron"
	grid._rebuild_props()
	_look()
	var icon: Sprite3D = grid._resource_icon_manager._sprites[spot]
	assert_true(icon.visible, "visível agora: ícone")
	grid.teleport_unit(scout, Vector2i(-8, 0))
	grid.recompute_fog(human)
	assert_eq(grid.visibility[spot], HexGrid.Visibility.EXPLORED)
	assert_false(icon.visible, "explorado: sem ícone")
	assert_true(grid._resource_props_manager._coord_to_index["iron"].has(spot), "mas o recurso continua no chão")

# --- Entidades: decididas no instante em que nascem ou se movem ----------------------------------------------------------

func test_before_any_fog_is_computed_everything_shows():
	assert_true(grid.spawn_unit(FAR, UnitDatabase.create_unit("warrior"), rival).visible, "sem névoa calculada (teste, mapa novo)")

func test_units_are_born_hidden_outside_current_vision():
	_look()
	assert_false(grid.spawn_unit(FAR, UnitDatabase.create_unit("warrior"), rival).visible, "tropa rival treinada fora da visão")
	assert_false(grid.spawn_monster_at(Vector2i(8, 1), "goblin").visible, "reforço de covil fora da visão")
	assert_true(grid.spawn_unit(NEAR, UnitDatabase.create_unit("warrior"), rival).visible, "dentro da visão: aparece")
	assert_true(grid.spawn_monster_at(Vector2i(0, 1), "goblin").visible)
	assert_true(grid.spawn_unit(Vector2i(8, 2), UnitDatabase.create_unit("warrior"), human).visible, "as próprias sempre aparecem")

func test_a_unit_hides_or_shows_on_the_very_step_that_crosses_the_vision_edge():
	_look()
	var raider := grid.spawn_unit(NEAR, UnitDatabase.create_unit("warrior"), rival)
	grid.teleport_unit(scout, Vector2i(-8, 0))
	grid.recompute_fog(human)
	assert_eq(grid.visibility[NEAR], HexGrid.Visibility.EXPLORED)
	assert_false(raider.visible, "área explorada não mostra quem está lá")
	grid.teleport_unit(scout, Vector2i.ZERO)
	grid.recompute_fog(human)
	assert_true(raider.visible)
	grid.move_unit(raider, FAR, 0.0)
	assert_false(raider.visible, "saiu da visão: some no próprio passo, sem esperar o fim da rodada")
	grid.move_unit(raider, NEAR, 0.0)
	assert_true(raider.visible, "entrou na visão: aparece no próprio passo")
	grid.teleport_unit(raider, FAR)
	assert_false(raider.visible)

func test_structures_of_others_are_born_hidden_and_mine_always_show():
	_look()
	var enemy_city := grid.found_city(FAR, rival, "Oculta", true)
	assert_false(enemy_city.visible, "cidade rival fundada fora da visão")
	assert_false(grid.place_building(Vector2i(10, 0), "v2_building_market", rival).visible, "prédio rival fora da visão")
	enemy_city.resource_improvements[Vector2i(9, 1)] = "v2_improvement_iron_mine"
	grid.refresh_resource_improvement_marker(Vector2i(9, 1))
	assert_false((grid.improvement_markers_by_coord[Vector2i(9, 1)] as Node3D).visible, "melhoria rival fora da visão")
	var mine := grid.found_city(Vector2i(-9, 2), human, "Minha", true)
	assert_true(mine.visible)
	assert_true(grid.place_building(Vector2i(-9, 3), "v2_building_market", human).visible)
	grid.capture_city(enemy_city, human)
	assert_true(enemy_city.visible, "capturada pelo jogador: passa a aparecer na hora")
	grid.capture_city(mine, rival)
	assert_false(mine.visible, "perdida para o rival fora da visão: some na hora")

func test_an_always_visible_unit_shows_as_soon_as_it_is_marked():
	_look()
	var boss := grid.spawn_monster_at(FAR, "troll")
	assert_false(boss.visible)
	boss.always_visible = true # evento mundial (Dragão): público mesmo na névoa
	assert_true(boss.visible)
	grid.move_unit(boss, Vector2i(8, 1), 0.0)
	assert_true(boss.visible)

func test_a_lair_created_mid_game_respects_the_fog_at_once():
	_look()
	grid.create_lair(FAR, "goblin", HexGrid.LAIR_ROLE_WILD)
	assert_false((grid.lairs_by_coord[FAR] as Node3D).visible, "covil novo em tile nunca visto")

## O relato do usuário, no turno de verdade: com a fila de IA escalonada, o que nasce ao encerrar o turno ficava visível
## até a IA terminar de agir.
func test_nothing_born_at_the_end_of_turn_flashes_through_the_fog():
	GameManager.stagger_ai_turns = true
	_look()
	rival.gold = 500.0
	var enemy_city := grid.found_city(FAR, rival, "Oculta", true)
	grid.spawn_unit(Vector2i(10, 1), UnitDatabase.create_unit("warrior"), rival) # a fila de IA nunca fica vazia
	enemy_city.production_item = "warrior"
	enemy_city.stored_production = enemy_city.production_cost()
	var units_before := rival.units.size()

	TurnManager.end_turn()

	assert_true(GameManager.is_turn_processing, "pré-condição: a IA ainda está agindo")
	assert_gt(rival.units.size(), units_before, "pré-condição: a cidade rival treinou uma unidade neste Encerrar Turno")
	for unit in rival.units:
		assert_false(unit.visible, "%s em %s (fora da visão) não aparece nem por um instante" % [unit.unit_data.unit_name, unit.coord])
	var guard := 0
	while GameManager.is_turn_processing and guard < 500:
		GameManager._process(1.0)
		for unit in rival.units:
			if is_instance_valid(unit) and grid.visibility.get(unit.coord, HexGrid.Visibility.UNSEEN) != HexGrid.Visibility.VISIBLE:
				assert_false(unit.visible, "durante a fase da IA: %s em %s continua oculta" % [unit.unit_data.unit_name, unit.coord])
		guard += 1

# --- Destaque sobre a névoa ---------------------------------------------------------------------------------------------

func test_highlight_reaches_tiles_under_the_layer():
	_look()
	var reachable := [NEAR, FAR]
	grid.set_highlight(reachable, [])
	assert_eq(grid._fog_highlighted, [FAR] as Array[Vector2i], "só o tile nunca visto vai para a camada; o conhecido é tingido no terreno")
	assert_gt(grid._fog_highlight_bytes[grid._fog_state_pixel(FAR) * 4 + 3], 0)
	assert_same(grid.fog_layer.material().get_shader_parameter("fog_highlight_texture"), grid._fog_highlight_texture)
	grid.clear_highlight()
	assert_true(grid._fog_highlighted.is_empty())
	assert_eq(grid._fog_highlight_bytes[grid._fog_state_pixel(FAR) * 4 + 3], 0, "limpar o destaque limpa a camada")
	var texture := grid._fog_highlight_texture
	grid.set_highlight([NEAR], [])
	assert_same(grid._fog_highlight_texture, texture, "destaque só em área conhecida não reenvia nada")
