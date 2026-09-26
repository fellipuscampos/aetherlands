extends GutTest

## Fase 21 — fluxo principal real: partida, cidade, filas, mira/ESC, quatro feitiços,
## Portal explícito, save/load e quinta Grande Manifestação.

const SAVE_PATH := "user://test_v2_phase21_main_flow.json"
const SCHOOL := "arcanism"
const CONCLAVE := "v2_building_arcane_conclave"
const TOWER := "v2_building_arcane_ritual"
const ARCANIST := "v2_unit_arcanist"
const ARCHON := "v2_manifestation_veil_archon"
const STEP := "v2_spell_arcane_step"
const SILENCE := "v2_spell_silence"
const DISPEL := "v2_spell_dispel"
const PORTAL := "v2_spell_veil_portal"
const AEGIS := "v2_spell_sacred_aegis"
const TECHNIQUE := "v2_technique_shield_wall"
const GROVE := "v2_terrain_dense_grove"

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
	grid.generate_map(31, 31, 21021)
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

func _learn(player: PlayerData, tier: int) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [SCHOOL, i]
		if not player.v2_research.is_completed(id):
			assert_true(player.v2_research.complete_research(id), id)

func _clear_city_ring(city: City) -> void:
	for unit in city.owner_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) <= 1:
			var destination := _free_coord(city.coord, 10, 5)
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
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _free_coord(center: Vector2i, max_distance: int, min_distance: int = 1) -> Vector2i:
	for coord in HexMetrics.coords_within(center, max_distance):
		var distance := HexMetrics.axial_distance(center, coord)
		var tile := grid.get_tile(coord)
		if distance >= min_distance and tile != null and not tile.blocks_land_units() and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.get_building_at(coord) == null and not grid.lairs_by_coord.has(coord):
			return coord
	return V2PortalSystem.INVALID_COORD

func _free_neighbor(coord: Vector2i) -> Vector2i:
	for candidate in grid.get_neighbors(coord):
		if grid.get_tile(candidate) != null and not grid.get_tile(candidate).blocks_land_units() and grid.get_unit_at(candidate) == null and grid.get_city_at(candidate) == null:
			return candidate
	return V2PortalSystem.INVALID_COORD

func _prepare_cast(caster: Unit, spell_id: String) -> void:
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.erase(spell_id)
	grid.recompute_fog(caster.owner_player)

func test_arcanism_n1_to_n9_portals_interference_and_archon_across_save_load():
	var human := GameManager.human_player
	var rival := GameManager.rival_players[0]
	var city := _found_city()
	assert_not_null(city)
	city.city_level = 3
	var mana_before := human.mana
	assert_true(human.v2_research.select_research("v2_magic_arcanism_1"))
	_end_turn()
	assert_gt(human.v2_research.get_progress("v2_magic_arcanism_1"), 0.0, "Conhecimento real")
	assert_gt(human.mana, mana_before, "Mana real")

	# N1–N3, Conclave e Arcanista pela fila normal.
	_learn(human, 2)
	_build(city, CONCLAVE)
	_learn(human, 3)
	_clear_city_ring(city)
	city.set_production(ARCANIST)
	_end_turn()
	var arcanist := _find(ARCANIST)
	assert_not_null(arcanist)
	assert_eq(arcanist.unit_data.supply_cost, 2)
	assert_false(arcanist.unit_data.can_basic_attack)

	# N4: mira cancela sem custo e o cast desloca diretamente, sem pagar o terreno intermediário.
	_learn(human, 4)
	human.mana = 300.0
	grid.teleport_unit(arcanist, _free_coord(city.coord, 8, 5))
	grid.recompute_fog(human)
	var step_targets := V2MagicRuntime.target_tiles(arcanist, V2SpellDatabase.get_spell(STEP), grid)
	assert_false(step_targets.is_empty())
	var step_destination: Vector2i = step_targets[-1]
	SelectionManager._select_unit(arcanist)
	SelectionManager.use_v2_spell_selected(STEP)
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC")
	assert_eq(human.mana, 300.0)
	assert_true(V2MagicRuntime.cast(arcanist, STEP, step_destination, grid))
	assert_eq([arcanist.coord, arcanist.movement_left, human.mana], [step_destination, 0.0, 294.0])

	# N5: Silêncio é V2-only, bloqueia spellcast, mas não movimento; expira pela regra do dono.
	_learn(human, 5)
	_learn(rival, 4)
	var enemy_coord := _free_coord(arcanist.coord, 3, 2)
	var enemy := _spawn(ARCANIST, rival, enemy_coord)
	Diplomacy.declare_war(human, rival)
	grid.recompute_fog(human)
	_prepare_cast(arcanist, SILENCE)
	var silence_data := V2SpellDatabase.get_spell(SILENCE)
	assert_true(V2MagicRuntime.cast(arcanist, SILENCE, enemy.coord, grid), "%s / %s" % [V2MagicRuntime.unavailable_reason(arcanist, SILENCE, grid), V2MagicRuntime.target_reason(arcanist, silence_data, enemy, grid)])
	assert_true(V2MagicRuntime.is_spellcasting_silenced(enemy))
	assert_eq(V2MagicRuntime.unavailable_reason(enemy, STEP, grid), "Silêncio — não pode conjurar feitiços.")
	var reachable := grid.unit_reachable(enemy)
	assert_false(reachable.is_empty(), "movimento continua")
	var move_target: Vector2i = reachable.keys()[0]
	grid.move_unit(enemy, move_target, reachable[move_target])
	assert_eq(enemy.coord, move_target)
	TurnManager.turn_number = int(enemy.magic_status[SILENCE])
	assert_eq(V2MagicRuntime.expire_finished(rival), 1)
	assert_false(V2MagicRuntime.is_spellcasting_silenced(enemy))

	# N6: Dissipar remove benefício hostil e harmful próprio, mas nunca Technique.
	_learn(human, 6)
	enemy.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	grid.teleport_unit(arcanist, _free_neighbor(enemy.coord))
	_prepare_cast(arcanist, DISPEL)
	assert_true(V2MagicRuntime.cast(arcanist, DISPEL, enemy.coord, grid))
	assert_false(enemy.magic_status.has(AEGIS))
	var helper := _spawn(ARCANIST, human, _free_neighbor(arcanist.coord))
	helper.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	helper.magic_status[TECHNIQUE] = V2OwnerTurnEffect.expiry_for_now()
	_prepare_cast(arcanist, DISPEL)
	assert_true(V2MagicRuntime.cast(arcanist, DISPEL, helper.coord, grid))
	assert_false(helper.magic_status.has(SILENCE))
	assert_true(helper.magic_status.has(TECHNIQUE))

	# N7: Portal, marcadores e travessia explícita de duas unidades sem stack.
	_learn(human, 7)
	_prepare_cast(arcanist, PORTAL)
	var portal_targets := V2MagicRuntime.target_tiles(arcanist, V2SpellDatabase.get_spell(PORTAL), grid)
	assert_false(portal_targets.is_empty())
	var endpoint_a := arcanist.coord
	var endpoint_b: Vector2i = portal_targets[-1]
	assert_true(V2MagicRuntime.cast(arcanist, PORTAL, endpoint_b, grid))
	assert_true(grid._v2_portal_markers.has(endpoint_a))
	assert_true(grid._v2_portal_markers.has(endpoint_b))
	grid.teleport_unit(arcanist, _free_neighbor(endpoint_a))
	var first := _spawn("warrior", human, endpoint_a)
	assert_true(V2PortalSystem.traverse(first, grid))
	assert_eq([first.coord, first.movement_left], [endpoint_b, 0.0])
	var second := _spawn("warrior", human, endpoint_a)
	assert_true(V2PortalSystem.traverse(second, grid))
	assert_ne(second.coord, endpoint_b)
	assert_eq(HexMetrics.axial_distance(second.coord, endpoint_b), 1)
	assert_eq(second.movement_left, 0.0)

	# Fog não é revelado pelo par. Revelar novamente reabilita a ação.
	var third := _spawn("warrior", human, endpoint_a)
	grid.visibility[endpoint_b] = HexGrid.Visibility.UNSEEN
	assert_eq(V2PortalSystem.traversal_reason(third, grid), V2PortalSystem.REASON_EXIT_HIDDEN)
	grid.visibility[endpoint_b] = HexGrid.Visibility.VISIBLE
	for neighbor in grid.get_neighbors(endpoint_b):
		grid.visibility[neighbor] = HexGrid.Visibility.VISIBLE
	assert_ne(V2PortalSystem.traversal_reason(third, grid), V2PortalSystem.REASON_EXIT_HIDDEN)

	# Camada Druídica e Portal coexistem; Dissipar fecha só o Portal.
	assert_true(V2TerrainRuntime.apply(grid, endpoint_b, GROVE))
	grid.teleport_unit(arcanist, _free_neighbor(endpoint_b))
	_prepare_cast(arcanist, DISPEL)
	assert_true(V2MagicRuntime.cast(arcanist, DISPEL, endpoint_b, grid))
	assert_true(V2PortalSystem.endpoint_at(endpoint_b, grid).is_empty())
	assert_true(V2TerrainRuntime.has_modification(grid, endpoint_b))

	# Um novo par atravessa o SaveManager real e volta com owner, índices e marcadores.
	_prepare_cast(arcanist, PORTAL)
	portal_targets = V2MagicRuntime.target_tiles(arcanist, V2SpellDatabase.get_spell(PORTAL), grid)
	assert_false(portal_targets.is_empty())
	endpoint_a = arcanist.coord
	endpoint_b = portal_targets[0]
	assert_true(V2MagicRuntime.cast(arcanist, PORTAL, endpoint_b, grid))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	rival = GameManager.rival_players[0]
	city = human.cities[0]
	arcanist = _find(ARCANIST)
	assert_eq(V2PortalSystem.paired_endpoint(endpoint_a, grid), endpoint_b)
	assert_true(grid._v2_portal_markers.has(endpoint_a))

	# N8–N9, Torre e Arconte: bateria de Mana, slot por Escola e cooldown reduzido.
	_learn(human, 8)
	_build(city, TOWER)
	_learn(human, 9)
	GameManager.debug_mode = false
	human.mana = 0.0
	city.set_production(ARCHON)
	city.stored_production = UnitDatabase.create_unit(ARCHON).production_cost
	_end_turn()
	assert_null(_find(ARCHON), "produção pronta espera Mana")
	human.mana = 100.0
	_end_turn()
	var archon := _find(ARCHON)
	assert_not_null(archon)
	assert_eq(human.mana, 31.0, "70 Mana cobrados uma vez depois do +1 da economia do turno")
	assert_true(archon.unit_data.is_flying())
	assert_true(V2ManifestationSystem.is_manifestation_unit(archon))
	assert_false(V2ManifestationSystem.spawn_allowed(human, ARCHON), "segundo Arconte fail-closed")
	_prepare_cast(archon, STEP)
	var archon_target := V2MagicRuntime.target_tiles(archon, V2SpellDatabase.get_spell(STEP), grid)[0]
	assert_true(V2MagicRuntime.cast(archon, STEP, archon_target, grid))
	assert_eq(V2MagicRuntime.cooldown_remaining(archon, STEP), 1)
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var cooldown_loaded := HexGrid.new()
	cooldown_loaded._ready()
	assert_true(SaveManager.load_game(cooldown_loaded, SAVE_PATH))
	grid.queue_free()
	grid = cooldown_loaded
	GameManager.hex_grid = cooldown_loaded
	human = GameManager.human_player
	rival = GameManager.rival_players[0]
	city = human.cities[0]
	archon = _find(ARCHON)
	assert_not_null(archon)
	assert_eq(V2MagicRuntime.cooldown_remaining(archon, STEP), 1, "a recarga efetiva, não a base, atravessa o save")

	# Cinco Escolas coexistem; nenhuma usa o slot militar e, sem Ritual Final,
	# o acesso à Transcendência não concede vitória instantânea.
	for kind in ["v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_lich_sovereign", "v2_manifestation_nature_avatar"]:
		_spawn(kind, human, _free_coord(city.coord, 14, 6))
	for school in ["sacred", "infernal", "necromancy", "druidism", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1, school)
	assert_true(V2LegendarySystem.legendary_slot_available(human))
	for school in ["sacred", "infernal", "necromancy", "druidism"]:
		assert_eq(V2SpellDatabase.for_school(school).size(), 4, school)
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55)
	assert_eq(V2InfrastructureContent.CONNECTED_UNLOCK_IDS.size(), 18)
	assert_true(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected)
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)
