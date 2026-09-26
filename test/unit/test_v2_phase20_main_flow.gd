extends GutTest

## Fase 20 — fluxo principal do Druidismo (§156). Partida criada pelo GameManager, cidade fundada pelo Colonizador,
## economia/turnos reais, filas, mira pela SelectionManager, combate pelo CombatResolver, construção/melhoria limpando a
## modificação e save/load. Atalhos: terreno determinístico, debug_mode para projetos de 1 turno, Mana reposta depois de
## provada a geração, recurso bruto posto num tile do território (o mapa de teste é só grama).

const SAVE_PATH := "user://test_v2_phase20_main_flow.json"
const CIRCLE := "v2_building_druidic_circle"
const RITUAL := "v2_building_druidic_ritual"
const DRUID := "v2_unit_druid"
const AVATAR := "v2_manifestation_nature_avatar"
const GROW := "v2_spell_grow_grove"
const RESTORE := "v2_spell_restore_terrain"
const RAISE := "v2_spell_raise_ground"
const AWAKEN := "v2_spell_awaken_forest"
const GROVE := "v2_terrain_dense_grove"
const RAISED := "v2_terrain_raised_ground"
const SCHOOL := "druidism"

var _grid: HexGrid
var _original_state
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_rival_count: int
var _original_debug: bool
var _original_stagger: bool
var _original_turn: int
var _original_turn_player: int

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_debug = GameManager.debug_mode
	_original_stagger = GameManager.stagger_ai_turns
	_original_turn = TurnManager.turn_number
	_original_turn_player = TurnManager.current_player_index
	GameManager.rival_count = 1
	GameManager.debug_mode = true
	GameManager.stagger_ai_turns = false
	_grid = HexGrid.new()
	_grid._ready()
	for q in range(-15, 16):
		for r in range(-15, 16):
			if absi(q + r) <= 15:
				_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.start_new_game(_grid)

func after_each():
	SelectionManager.reset()
	SaveManager.delete_save(SAVE_PATH)
	for player in GameManager.players:
		player.release_relations()
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	GameManager.rival_count = _original_rival_count
	GameManager.debug_mode = _original_debug
	GameManager.stagger_ai_turns = _original_stagger
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	TurnManager.turn_number = _original_turn
	TurnManager.current_player_index = _original_turn_player
	if is_instance_valid(_grid):
		_grid.queue_free()

func _found_city() -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			return WorldSetup.found_city_from_settler(_grid, unit)
	return null

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing)

func _learn(branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not GameManager.human_player.v2_research.is_completed(id):
			assert_true(GameManager.human_player.v2_research.complete_research(id), id)

func _build(city: City, id: String) -> Vector2i:
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "tile para %s" % id)
	var site: Vector2i = SelectionManager.placeable_coords[0]
	SelectionManager._handle_building_placement_click(site)
	_end_turn()
	assert_true(city.buildings.has(id), id)
	return site

func _clear_city_ring(city: City) -> void:
	for unit in GameManager.human_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		var destination := _free_coord(city.coord, 6, 4)
		if destination != Vector2i(999, 999):
			_grid.teleport_unit(unit, destination)

func _free_coord(center: Vector2i, max_distance: int, min_distance: int = 1) -> Vector2i:
	for coord in HexMetrics.coords_within(center, max_distance):
		var distance := HexMetrics.axial_distance(coord, center)
		if distance >= min_distance and _grid.tiles.has(coord) and _grid.get_unit_at(coord) == null and _grid.get_city_at(coord) == null and not V2TerrainRuntime.has_permanent_structure(_grid, coord) and not V2TerrainRuntime.has_modification(_grid, coord) and _grid.city_owning_tile(coord) == null:
			return coord
	return Vector2i(999, 999)

## Um centro a `distance` do conjurador com os 7 tiles da área livres de cidade/território/estrutura/modificação.
func _free_area(caster_coord: Vector2i, distance: int) -> Vector2i:
	for coord in HexMetrics.coords_within(caster_coord, distance):
		if HexMetrics.axial_distance(coord, caster_coord) != distance:
			continue
		var ok := true
		for c in [coord] + HexMetrics.coords_within(coord, 1):
			if not _grid.tiles.has(c) or _grid.get_tile(c).blocks_land_units() or _grid.get_unit_at(c) != null or _grid.city_owning_tile(c) != null or _grid.get_city_at(c) != null or V2TerrainRuntime.has_modification(_grid, c) or V2TerrainRuntime.has_permanent_structure(_grid, c):
				ok = false
				break
		if ok:
			return coord
	return Vector2i(999, 999)

func _spawn(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := _grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _find(kind: String) -> Unit:
	for unit in GameManager.human_player.units:
		if is_instance_valid(unit) and unit.unit_data.visual_kind == kind:
			return unit
	return null

func _aim_and_click(caster: Unit, spell_id: String, coord: Vector2i) -> void:
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.erase(spell_id)
	SelectionManager._select_unit(caster)
	SelectionManager.use_v2_spell_selected(spell_id)
	assert_eq(SelectionManager.v2_spell_targeting_id, spell_id, V2MagicRuntime.unavailable_reason(caster, spell_id, _grid))
	assert_true(coord in SelectionManager.v2_spell_target_coords, "%s mira %s" % [spell_id, str(coord)])
	SelectionManager._handle_v2_spell_targeting_click(coord)

func _end_skirmish(human: PlayerData, rival: PlayerData, spawned: Array) -> void:
	for unit in spawned:
		if is_instance_valid(unit) and unit in rival.units:
			_grid.remove_unit(unit)
	human.enemies.erase(rival)
	rival.enemies.erase(human)

func test_156_druidism_end_to_end_with_terrain_layer_four_manifestations_and_save():
	# 1–3: partida/cidade reais; Conhecimento e Mana gerados pela economia.
	var human := GameManager.human_player
	var rival := GameManager.rival_players[0]
	var city := _found_city()
	assert_not_null(city)
	city.city_level = 3
	var mana_before: float = human.mana
	assert_true(human.v2_research.select_research("v2_magic_druidism_1"))
	_end_turn()
	assert_gt(human.v2_research.get_progress("v2_magic_druidism_1"), 0.0, "Conhecimento real")
	assert_gt(human.mana, mana_before, "Mana real")

	# 4–10: Escola, Círculo pela fila, Druida pela fila (Supply 2, sem ataque básico).
	_learn(SCHOOL, 2)
	_build(city, CIRCLE)
	_learn(SCHOOL, 3)
	_clear_city_ring(city)
	city.set_production(DRUID)
	_end_turn()
	var druid := _find(DRUID)
	assert_not_null(druid)
	assert_eq(druid.unit_data.supply_cost, 2)
	assert_false(druid.unit_data.can_basic_attack)

	# 11–16: Brotar Bosque pela mira; ESC; Mana intacta; cast; Bosque e marcador.
	_learn(SCHOOL, 4)
	human.mana = 200.0
	_grid.teleport_unit(druid, _free_coord(city.coord, 8, 5))
	_grid.recompute_fog(human)
	var grove_tile := _free_coord(druid.coord, 2, 2)
	SelectionManager._select_unit(druid)
	SelectionManager.use_v2_spell_selected(GROW)
	assert_true(grove_tile in SelectionManager.v2_spell_target_coords)
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC")
	assert_eq(human.mana, 200.0)
	_aim_and_click(druid, GROW, grove_tile)
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, grove_tile), GROVE)
	assert_true(_grid._terrain_modification_markers.has(grove_tile), "marcador no mapa")
	assert_eq(human.mana, 194.0)

	# 17–18: uma unidade entra no Bosque pagando +1.
	var walker := _spawn("warrior", human, _free_neighbor(grove_tile))
	_end_turn() # a guarnição do turno anterior não interfere
	walker.movement_left = walker.unit_data.movement_points
	SelectionManager._select_unit(walker)
	assert_eq(SelectionManager.reachable.get(grove_tile), 2.0, "custo 1 + 1")
	SelectionManager._move_selected_to(grove_tile)
	assert_eq(walker.coord, grove_tile)
	assert_eq(walker.movement_left, 0.0)

	# 19–20: combate contra um defensor no Bosque: Defesa física ×1,2; predict == resolve.
	Diplomacy.declare_war(human, rival)
	_grid.teleport_unit(walker, _free_coord(druid.coord, 5, 3))
	var defender := _spawn("warrior", rival, grove_tile)
	var attacker := _spawn("v2_unit_guardian", human, _free_neighbor(grove_tile))
	var with_grove := CombatResolver.predict(attacker, defender, _grid)
	V2TerrainRuntime.remove(_grid, grove_tile)
	var without := CombatResolver.predict(attacker, defender, _grid)
	V2TerrainRuntime.apply(_grid, grove_tile, GROVE)
	assert_almost_eq(without.damage_to_defender - with_grove.damage_to_defender, 0.5 * defender.unit_data.defense * 0.2, 0.0001)
	var hp := defender.hp
	CombatResolver.resolve(attacker, defender, _grid)
	assert_almost_eq(hp - defender.hp, with_grove.damage_to_defender, 0.0001)
	_end_skirmish(human, rival, [defender])
	_grid.remove_unit(attacker)

	# 21–23: Restaurar Terreno remove; custo e Defesa voltam.
	_learn(SCHOOL, 5)
	_aim_and_click(druid, RESTORE, grove_tile)
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, grove_tile), "")
	assert_eq(_grid.terrain_step_cost(grove_tile), 1.0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(_grid, grove_tile), 1.0)

	# 24–27: Erguer Terreno: +2 custo, +35%.
	_learn(SCHOOL, 6)
	_aim_and_click(druid, RAISE, grove_tile)
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, grove_tile), RAISED)
	assert_eq(_grid.terrain_step_cost(grove_tile), 3.0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(_grid, grove_tile), 1.35)

	# 28–32: Despertar a Mata numa área livre, com uma unidade num tile secundário.
	_learn(SCHOOL, 7)
	var center := _free_area(druid.coord, 4)
	assert_ne(center, Vector2i(999, 999), "área livre")
	var secondary := HexMetrics.coords_within(center, 1).filter(func(c): return c != center)[0] as Vector2i
	var guest := _spawn("warrior", human, secondary)
	_grid.recompute_fog(human)
	_aim_and_click(druid, AWAKEN, center)
	var groves := 0
	for c in [center] + HexMetrics.coords_within(center, 1):
		if V2TerrainRuntime.modification_id_at(_grid, c) == GROVE:
			groves += 1
	assert_eq(groves, 7, "centro + 6")
	assert_eq(V2TerrainRuntime.defense_multiplier_at(_grid, guest.coord), 1.2, "a unidade secundária recebe")

	# 33–34: construir num tile modificado limpa a modificação (pela fila real).
	var build_tile := _free_territory_tile(city)
	V2TerrainRuntime.apply(_grid, build_tile, GROVE)
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, "v2_building_market")
	assert_true(build_tile in SelectionManager.placeable_coords)
	SelectionManager._handle_building_placement_click(build_tile)
	_end_turn()
	assert_not_null(_grid.get_building_at(build_tile), "o Mercado foi colocado")
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, build_tile), "", "e limpou o Bosque")

	# 35–36: melhorar um recurso bruto modificado limpa e rende.
	var ore := _free_territory_tile(city)
	_grid.get_tile(ore).resource = "iron"
	V2TerrainRuntime.apply(_grid, ore, GROVE)
	var builder := _spawn("v2_unit_builder", human, ore)
	builder.work_charges_remaining = 1
	var production := V2EconomyRuntime.city_production_income(city)
	assert_true(V2ConstructorRuntime.improve_resource(builder, _grid), V2ConstructorRuntime.unavailable_reason(builder, _grid))
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, ore), "")
	assert_gt(V2EconomyRuntime.city_production_income(city), production)

	# 37–40: save/load — modificações, custo e Defesa.
	var saved := _grid.v2_terrain_modifications.duplicate()
	assert_true(SaveManager.save_game(_grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	_grid.queue_free()
	_grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	rival = GameManager.rival_players[0]
	city = human.cities[0]
	# O load regenera o mapa pela semente (o mapa de grama do teste é artificial): coordenadas que não existem no mapa
	# carregado são ignoradas pelo restore fail-safe; todas as outras voltam idênticas.
	var expected := {}
	for key in saved:
		if _grid.tiles.has(key):
			expected[key] = saved[key]
	assert_gt(expected.size(), 5)
	assert_eq(_grid.v2_terrain_modifications, expected)
	assert_eq(_grid.terrain_step_cost(grove_tile), 3.0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(_grid, center), 1.2)
	druid = _find(DRUID)

	# 41–46: Bosque Ancestral, N9, produção do Avatar esperando Mana.
	_learn(SCHOOL, 8)
	_build(city, RITUAL)
	_learn(SCHOOL, 9)
	GameManager.debug_mode = false
	human.mana = 65.0
	_clear_city_ring(city)
	assert_true(city.can_train(AVATAR), V2ManifestationSystem.training_soft_reason(human, city, AVATAR))
	city.set_production(AVATAR)
	human.mana = 5.0
	city.stored_production = 105.0
	_end_turn()
	assert_null(_find(AVATAR), "espera a Mana")
	human.mana = 80.0
	_end_turn()
	var avatar := _find(AVATAR)
	assert_not_null(avatar)
	GameManager.debug_mode = true
	human.mana = 200.0

	# 47–50: Manifestação, alcance +1; Brotar a 4 e Despertar a 5 com a visão de outra unidade.
	assert_true(avatar.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_false(avatar.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	# Posição com uma área de terra livre exatamente a 5 (o mapa recarregado é o gerado pela semente, com água/relevo).
	var spot := Vector2i(999, 999)
	for c in HexMetrics.coords_within(city.coord, 12):
		var tile := _grid.get_tile(c)
		if tile != null and not tile.blocks_land_units() and _grid.get_unit_at(c) == null and _grid.get_city_at(c) == null and not V2TerrainRuntime.has_permanent_structure(_grid, c) and HexMetrics.axial_distance(c, city.coord) >= 4 and _free_area(c, 5) != Vector2i(999, 999):
			spot = c
			break
	assert_ne(spot, Vector2i(999, 999), "posição para o Avatar")
	_grid.teleport_unit(avatar, spot)
	_grid.recompute_fog(human)
	var far_tile := Vector2i(999, 999)
	for c in HexMetrics.coords_within(avatar.coord, 4):
		if HexMetrics.axial_distance(c, avatar.coord) == 4 and V2MagicRuntime.tile_reason(avatar, V2SpellDatabase.get_spell(GROW), c, _grid) == "":
			far_tile = c
			break
	assert_ne(far_tile, Vector2i(999, 999), "tile a 4 visível")
	_aim_and_click(avatar, GROW, far_tile)
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, far_tile), GROVE)
	var five := _free_area(avatar.coord, 5)
	assert_ne(five, Vector2i(999, 999))
	_spawn("v2_unit_archer", human, _free_neighbor(five)) # outra unidade dá a visão a 5
	_grid.recompute_fog(human)
	_aim_and_click(avatar, AWAKEN, five)
	assert_eq(V2TerrainRuntime.modification_id_at(_grid, five), GROVE, "Despertar a 5")

	# 51–52: quatro Manifestações, quatro slots independentes.
	for kind in ["v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_lich_sovereign"]:
		_spawn(kind, human, _free_coord(city.coord, 14, 6))
	for school in ["sacred", "infernal", "necromancy", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1, school)

	# 53–55: Doutrinas/Infraestrutura/Escolas anteriores intactas; Transcendência sem gameplay.
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55)
	assert_eq(V2InfrastructureContent.CONNECTED_UNLOCK_IDS.size(), 18)
	for school in ["sacred", "infernal", "necromancy"]:
		assert_eq(V2SpellDatabase.for_school(school).size(), 4, school)
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_not_null(druid)

func _free_neighbor(coord: Vector2i) -> Vector2i:
	for n in _grid.get_neighbors(coord):
		if _grid.get_unit_at(n) == null and _grid.get_city_at(n) == null and not _grid.get_tile(n).blocks_land_units():
			return n
	return Vector2i(999, 999)

func _free_territory_tile(city: City) -> Vector2i:
	for coord in city.owned_tiles:
		if coord != city.coord and _grid.get_unit_at(coord) == null and not V2TerrainRuntime.has_permanent_structure(_grid, coord) and not V2TerrainRuntime.has_modification(_grid, coord) and city.is_valid_building_tile(coord, _grid):
			return coord
	return Vector2i(999, 999)
