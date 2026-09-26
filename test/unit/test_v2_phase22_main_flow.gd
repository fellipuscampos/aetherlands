extends GutTest

## Fase 22 — fluxo principal pelo jogo real: pesquisa, filas, mira/ESC,
## rodada global, coexistência das três camadas mágicas, sexta Manifestação,
## save/load e Transcendência ainda sem gameplay.

const SAVE_PATH := "user://test_v2_phase22_main_flow.json"
const SCHOOL := "elementalism"
const OBSERVATORY := "v2_building_elemental_observatory"
const NEXUS := "v2_building_elemental_ritual"
const ELEMENTALIST := "v2_unit_elementalist"
const PRIMORDIAL := "v2_manifestation_elemental_primordial"
const MIST := "v2_spell_dense_mist"
const GALE := "v2_spell_gale"
const STORM := "v2_spell_lightning_storm"
const CATACLYSM := "v2_spell_elemental_cataclysm"

var grid: HexGrid
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
	grid = HexGrid.new()
	grid._ready()
	grid.generate_map(31, 31, 22022)
	GameManager.start_new_game(grid)

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
	if is_instance_valid(grid):
		grid.queue_free()

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing)

func _found_city() -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			return WorldSetup.found_city_from_settler(grid, unit)
	return null

func _learn(player: PlayerData, branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not player.v2_research.is_completed(id):
			assert_true(player.v2_research.complete_research(id), id)

func _clear_city_ring(city: City) -> void:
	for unit in city.owner_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) <= 1:
			var destination := _free_coord(city.coord, 12, 6)
			if destination != V2PortalSystem.INVALID_COORD:
				grid.teleport_unit(unit, destination)

func _build(city: City, id: String) -> Vector2i:
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, id)
	assert_false(SelectionManager.placeable_coords.is_empty(), id)
	var coord: Vector2i = SelectionManager.placeable_coords[0]
	SelectionManager._handle_building_placement_click(coord)
	_end_turn()
	assert_true(city.buildings.has(id), id)
	return coord

func _find(kind: String, player: PlayerData = GameManager.human_player) -> Unit:
	for unit in player.units:
		if is_instance_valid(unit) and unit.unit_data.visual_kind == kind:
			return unit
	return null

func _spawn(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	assert_not_null(unit, kind)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _free_coord(center: Vector2i, max_distance: int, min_distance: int = 1) -> Vector2i:
	for coord in HexMetrics.coords_within(center, max_distance):
		var tile := grid.get_tile(coord)
		if HexMetrics.axial_distance(center, coord) >= min_distance and tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.get_building_at(coord) == null and not grid.lairs_by_coord.has(coord) and not grid.v2_environmental_zones.has(coord):
			return coord
	return V2PortalSystem.INVALID_COORD

func _prepare_cast(caster: Unit, spell_id: String) -> void:
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.erase(spell_id)
	grid.recompute_fog(caster.owner_player)

func test_elementalism_n1_to_n9_environmental_rounds_six_manifestations_and_save():
	var human := GameManager.human_player
	var city := _found_city()
	assert_not_null(city, "1–2. nova partida e cidade")
	city.city_level = 4
	var initial_mana := human.mana
	assert_true(human.v2_research.select_research("v2_magic_elementalism_1"))
	_end_turn()
	assert_gt(human.v2_research.get_progress("v2_magic_elementalism_1"), 0.0, "3–4. Conhecimento real")
	assert_gt(human.mana, initial_mana, "Mana real")

	# 5–10. Escola, estrutura e caster pela fila normal.
	_learn(human, SCHOOL, 2)
	_build(city, OBSERVATORY)
	_learn(human, SCHOOL, 3)
	_clear_city_ring(city)
	city.set_production(ELEMENTALIST)
	_end_turn()
	var elementalista := _find(ELEMENTALIST)
	assert_not_null(elementalista)
	assert_eq(elementalista.unit_data.supply_cost, 2)
	assert_false(elementalista.unit_data.can_basic_attack)

	# 11–20. Névoa: mira cancelável, marker, visão/fog imediatos e uma rodada global exata.
	_learn(human, SCHOOL, 4)
	human.mana = 500.0
	grid.teleport_unit(elementalista, _free_coord(city.coord, 10, 5))
	grid.recompute_fog(human)
	SelectionManager._select_unit(elementalista)
	SelectionManager.use_v2_spell_selected(MIST)
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "13. ESC")
	assert_eq(human.mana, 500.0, "14. ESC não gasta")
	var mist_coord := elementalista.coord
	var base_vision := elementalista.unit_data.vision_range
	assert_true(V2MagicRuntime.cast(elementalista, MIST, mist_coord, grid))
	assert_true(grid._v2_environmental_zone_markers.has(mist_coord))
	assert_eq(V2EnvironmentalZoneSystem.effective_unit_vision(elementalista, grid), base_vision - 2)
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(mist_coord, grid).remaining_rounds), 2)
	_end_turn()
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(mist_coord, grid).remaining_rounds), 1, "19–20. uma rodada, um decremento")

	# 21–25. Vendaval integra a fórmula física ranged, nunca melee nem spell.
	_learn(human, SCHOOL, 5)
	var archer := _spawn("archer", human, _free_coord(city.coord, 10, 5))
	var enemy := _spawn("warrior", GameManager.rival_players[0], _free_coord(archer.coord, 2, 2))
	enemy.unit_data.defense = 0.5
	Diplomacy.declare_war(human, enemy.owner_player)
	var ranged_normal: float = float(CombatResolver.predict(archer, enemy, grid).damage_to_defender)
	assert_true(V2EnvironmentalZoneSystem.apply(grid, archer.coord, "v2_zone_gale", 0, SCHOOL))
	assert_lt(CombatResolver.predict(archer, enemy, grid).damage_to_defender, ranged_normal)
	var melee := _spawn("men_at_arms", human, _free_coord(enemy.coord, 1))
	var melee_normal: float = float(CombatResolver.predict(melee, enemy, grid).damage_to_defender)
	assert_true(V2EnvironmentalZoneSystem.apply(grid, melee.coord, "v2_zone_gale", 0, SCHOOL))
	assert_eq(CombatResolver.predict(melee, enemy, grid).damage_to_defender, melee_normal)
	_learn(human, "infernal", 4)
	var warlock := _spawn("v2_unit_infernal_warlock", human, _free_coord(city.coord, 12, 7))
	var flame := V2SpellDatabase.get_spell("v2_spell_infernal_flame")
	var magic_before := V2MagicRuntime.predict_damage(warlock, enemy, flame)
	assert_true(V2EnvironmentalZoneSystem.apply(grid, warlock.coord, "v2_zone_gale", 0, SCHOOL))
	assert_eq(V2MagicRuntime.predict_damage(warlock, enemy, flame), magic_before)

	# 26–34. Tempestade não dá dano no cast; cada fechamento global dá 4, inclusive no dono, e o segundo expira.
	_learn(human, SCHOOL, 6)
	var storm_target := _spawn("warrior", human, _free_coord(elementalista.coord, 2, 2))
	_prepare_cast(elementalista, STORM)
	var hp := storm_target.hp
	assert_true(V2MagicRuntime.cast(elementalista, STORM, storm_target.coord, grid), "%s / %s" % [V2MagicRuntime.unavailable_reason(elementalista, STORM, grid), V2MagicRuntime.tile_reason(elementalista, V2SpellDatabase.get_spell(STORM), storm_target.coord, grid)])
	assert_eq(storm_target.hp, hp)
	_end_turn()
	assert_eq(storm_target.hp, hp - 4.0)
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(storm_target.coord, grid).remaining_rounds), 1)
	_end_turn()
	assert_eq(storm_target.hp, hp - 8.0)
	assert_true(V2EnvironmentalZoneSystem.zone_entry_at(storm_target.coord, grid).is_empty())

	# 35–47. Cataclismo, Grove e Portal coexistem; Dissipar remove as duas camadas mágicas, Restaurar remove a física.
	_learn(human, SCHOOL, 7)
	_prepare_cast(elementalista, CATACLYSM)
	var area_center := _free_coord(elementalista.coord, 2, 2)
	assert_true(V2MagicRuntime.cast(elementalista, CATACLYSM, area_center, grid))
	var cataclysm_cells := 0
	for coord in grid.v2_environmental_zones:
		if String(grid.v2_environmental_zones[coord].zone_id) == "v2_zone_elemental_cataclysm":
			cataclysm_cells += 1
	assert_eq(cataclysm_cells, 19)
	var zone := V2EnvironmentalZoneSystem.zone_at(area_center, grid)
	assert_eq([zone.vision_delta, zone.physical_ranged_attack_multiplier, zone.round_tick_magic_damage], [-1, 0.8, 5.0])
	assert_true(V2TerrainRuntime.apply(grid, area_center, "v2_terrain_dense_grove"))
	_learn(human, "arcanism", 7)
	var arcanist := _spawn("v2_unit_arcanist", human, _free_coord(area_center, 3, 3))
	assert_true(V2PortalSystem.create_or_replace_pair(human, "arcanism", arcanist.coord, area_center, grid))
	_prepare_cast(arcanist, "v2_spell_dispel")
	assert_true(V2MagicRuntime.cast(arcanist, "v2_spell_dispel", area_center, grid))
	assert_true(V2EnvironmentalZoneSystem.zone_entry_at(area_center, grid).is_empty())
	assert_true(V2PortalSystem.endpoint_at(area_center, grid).is_empty())
	assert_true(V2TerrainRuntime.has_modification(grid, area_center))
	_learn(human, "druidism", 5)
	var druid := _spawn("v2_unit_druid", human, _free_coord(area_center, 3))
	_prepare_cast(druid, "v2_spell_restore_terrain")
	assert_true(V2MagicRuntime.cast(druid, "v2_spell_restore_terrain", area_center, grid))
	assert_false(V2TerrainRuntime.has_modification(grid, area_center))

	# 48–58. Nexo, bateria de Mana da produção e Coração Elemental materializado no cast.
	_learn(human, SCHOOL, 8)
	_build(city, NEXUS)
	_learn(human, SCHOOL, 9)
	GameManager.debug_mode = false
	human.mana = 0.0
	city.set_production(PRIMORDIAL)
	city.stored_production = UnitDatabase.create_unit(PRIMORDIAL).production_cost
	_end_turn()
	assert_null(_find(PRIMORDIAL), "52. PP completo espera Mana")
	human.mana = 100.0
	_end_turn()
	var primordial := _find(PRIMORDIAL)
	assert_not_null(primordial)
	assert_true(primordial.unit_data.is_flying())
	assert_true(V2ManifestationSystem.is_manifestation_unit(primordial))
	assert_eq(primordial.unit_data.environmental_zone_duration_bonus, 1)
	_prepare_cast(primordial, MIST)
	var long_mist := _free_coord(primordial.coord, 4, 2)
	assert_true(V2MagicRuntime.cast(primordial, MIST, long_mist, grid))
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(long_mist, grid).remaining_rounds), 3)

	# 59–68. Seis slots independentes e round-trip complexo das três camadas + status.
	for kind in ["v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_lich_sovereign", "v2_manifestation_nature_avatar", "v2_manifestation_veil_archon"]:
		_spawn(kind, human, _free_coord(city.coord, 14, 7))
	for branch in ["sacred", "infernal", "necromancy", "druidism", "arcanism", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, branch).size(), 1, branch)
	assert_false(V2ManifestationSystem.slot_available(human, SCHOOL))
	var layered := _free_coord(city.coord, 6, 3)
	assert_true(V2TerrainRuntime.apply(grid, layered, "v2_terrain_dense_grove"))
	assert_true(V2EnvironmentalZoneSystem.apply(grid, layered, "v2_zone_gale", 0, SCHOOL))
	assert_true(V2PortalSystem.create_or_replace_pair(human, "arcanism", arcanist.coord, layered, grid))
	elementalista.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	var remaining := int(V2EnvironmentalZoneSystem.zone_entry_at(long_mist, grid).remaining_rounds)
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(long_mist, grid).remaining_rounds), remaining)
	assert_true(grid._v2_environmental_zone_markers.has(long_mist))
	assert_true(V2TerrainRuntime.has_modification(grid, layered))
	assert_false(V2PortalSystem.endpoint_at(layered, grid).is_empty())
	assert_true(_find(ELEMENTALIST).magic_status.has("v2_spell_sacred_aegis"))
	for branch in ["sacred", "infernal", "necromancy", "druidism", "arcanism", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, branch).size(), 1, "slot após load: " + branch)

	# 69–73. Árvore mágica completa; capstone conectado, mas pesquisa sem Ritual não vence.
	for branch in V2ResearchDatabase.MAGIC_BRANCHES:
		_learn(human, String(branch.id), 9)
	assert_eq(V2MagicContent.CONNECTED_UNLOCK_IDS.size(), 55)
	assert_eq(V2ResearchDatabase.capstone_progress(V2ResearchDatabase.TRANSCENDENCE_ID, human.v2_research.completed_ids), Vector2i(2, 2))
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	assert_true(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected)
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)
