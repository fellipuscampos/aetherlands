extends GutTest

## Fase 18 — fluxo principal Infernal. Usa uma partida criada pelo GameManager,
## cidade fundada pelo Colonizador, economia/turnos, filas, targeting e save/load.
## Os únicos atalhos são o terreno determinístico e debug_mode para projetos de 1 turno.

const SAVE_PATH := "user://test_v2_phase18_main_flow.json"
const SANCTUM := "v2_building_infernal_sanctum"
const RITUAL := "v2_building_infernal_ritual"
const WARLOCK := "v2_unit_infernal_warlock"
const ARCHDEMON := "v2_manifestation_archdemon"
const SERAPH := "v2_manifestation_seraph"

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

func _build(city: City, id: String) -> void:
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "tile para %s" % id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	_end_turn()
	assert_true(city.buildings.has(id), id)

func _clear_city_ring(city: City) -> void:
	for unit in GameManager.human_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		var destination := _free_coord(city.coord, 5, 4)
		if destination != Vector2i(999, 999):
			_grid.teleport_unit(unit, destination)

func _free_coord(center: Vector2i, max_distance: int, min_distance: int = 1) -> Vector2i:
	for coord in HexMetrics.coords_within(center, max_distance):
		var distance := HexMetrics.axial_distance(coord, center)
		if distance >= min_distance and _grid.tiles.has(coord) and _grid.get_unit_at(coord) == null and _grid.get_city_at(coord) == null:
			return coord
	return Vector2i(999, 999)

func _spawn(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var occupant := _grid.get_unit_at(coord)
	if occupant != null:
		_grid.remove_unit(occupant)
	var unit := _grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, kind)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _find(kind: String) -> Unit:
	for unit in GameManager.human_player.units:
		if is_instance_valid(unit) and unit.unit_data.visual_kind == kind:
			return unit
	return null

func _cast(caster: Unit, spell_id: String, target: Unit) -> void:
	caster.movement_left = caster.unit_data.movement_points
	SelectionManager._select_unit(caster)
	SelectionManager.use_v2_spell_selected(spell_id)
	assert_eq(SelectionManager.v2_spell_targeting_id, spell_id, V2MagicRuntime.unavailable_reason(caster, spell_id, _grid))
	SelectionManager._handle_v2_spell_targeting_click(target.coord)

func test_136_infernal_end_to_end_through_two_manifestations_save_and_no_final_ritual():
	# 1–6: partida/cidade/economia real, pesquisa e Santuário pela fila.
	var human := GameManager.human_player
	var rival := GameManager.rival_players[0]
	var city := _found_city()
	assert_not_null(city)
	city.city_level = 3 # atalho de slot; City Level tem seu próprio fluxo dedicado.
	var mana_before: float = human.mana
	assert_true(human.v2_research.select_research("v2_magic_infernal_1"))
	_end_turn()
	assert_gt(human.v2_research.get_progress("v2_magic_infernal_1"), 0.0, "economia gerou Conhecimento")
	assert_gt(human.mana, mana_before, "economia gerou Mana")
	_learn("infernal", 2)
	_build(city, SANCTUM)

	# 7–11: Bruxo pela fila normal, Supply 2, sem ataque e invisível à Magia V1.
	_learn("infernal", 3)
	_clear_city_ring(city)
	city.set_production(WARLOCK)
	_end_turn()
	var warlock := _find(WARLOCK)
	assert_not_null(warlock)
	assert_eq(warlock.unit_data.supply_cost, 2)
	assert_false(warlock.unit_data.can_basic_attack)
	assert_eq(V2MagicRuntime.spells_for_unit(warlock).size(), 0)

	# 12–20: guerra, mira vermelha, cancelamento sem custo, Chama = 6 e sem revide.
	Diplomacy.declare_war(human, rival)
	var target := _spawn("v2_unit_guardian", rival, warlock.coord + Vector2i(2, 0))
	_learn("infernal", 4)
	human.mana = 100.0 # pool real; a geração natural já foi provada acima.
	var mana_at_aim := human.mana
	SelectionManager._select_unit(warlock)
	SelectionManager.use_v2_spell_selected("v2_spell_infernal_flame")
	assert_true(target.coord in SelectionManager.v2_spell_target_coords)
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC usa este cancelamento público")
	assert_eq(human.mana, mana_at_aim)
	var warlock_hp := warlock.hp
	var target_hp := target.hp
	_cast(warlock, "v2_spell_infernal_flame", target)
	assert_eq(target_hp - target.hp, 6.0)
	assert_eq(warlock.hp, warlock_hp, "sem retaliation")

	# 21–25: Fogo Voraz base 8 e bônus 12 no limiar inclusivo de 50%.
	_learn("infernal", 5)
	var full := _spawn("v2_unit_guardian", rival, warlock.coord + Vector2i(2, -1))
	var devouring := V2SpellDatabase.get_spell("v2_spell_devouring_fire")
	assert_eq(V2MagicRuntime.predict_damage(warlock, full, devouring), 8.0)
	full.hp = full.unit_data.max_hp * 0.5
	assert_eq(V2MagicRuntime.predict_damage(warlock, full, devouring), 12.0)
	_cast(warlock, devouring.id, full)

	# 26–30: Explosão resolve o cluster mesmo matando o primário e registra 3 kills.
	_learn("infernal", 6)
	var center := warlock.coord + Vector2i(3, 0)
	var victims: Array[Unit] = [
		_spawn("warrior", rival, center),
		_spawn("warrior", rival, center + Vector2i(-1, 0)),
		_spawn("warrior", rival, center + Vector2i(0, -1)),
	]
	for victim in victims:
		victim.hp = 4.0
	var kills_before := warlock.kills
	_cast(warlock, "v2_spell_infernal_blast", victims[0])
	assert_eq(warlock.kills - kills_before, 3)
	for victim in victims:
		assert_false(victim in rival.units)

	# 31–34: Condenação alcança 4 se outra fonte mantiver o tile visível e causa 15.
	_learn("infernal", 7)
	var far_target := _spawn("v2_unit_guardian", rival, warlock.coord + Vector2i(4, 0))
	_grid.visibility[far_target.coord] = HexGrid.Visibility.VISIBLE
	var far_hp := far_target.hp
	_cast(warlock, "v2_spell_damnation", far_target)
	assert_eq(far_hp - far_target.hp, 15.0)

	# 35–44: Círculo, N9, duas Escolas 2/2, espera de Mana e nascimento do Arquidemônio.
	_learn("infernal", 8)
	_build(city, RITUAL)
	_learn("infernal", 9)
	_learn("sacred", 9)
	assert_eq(V2ResearchDatabase.capstone_progress("v2_transcendence", human.v2_research.completed_ids), Vector2i(2, 2))
	GameManager.debug_mode = false
	human.mana = 70.0
	city.set_production(ARCHDEMON)
	human.mana = 5.0
	city.stored_production = 105.0
	_end_turn()
	assert_eq(city.production_item, ARCHDEMON)
	assert_eq(city.stored_production, 105.0)
	human.mana = 80.0
	_end_turn()
	var archdemon := _find(ARCHDEMON)
	assert_not_null(archdemon)

	# 45–53: identidade da Manifestação, multiplicador por dado e coexistência por Escola.
	assert_eq(archdemon.unit_data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_true(archdemon.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_false(archdemon.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(archdemon.unit_data.can_basic_attack)
	var arch_target := _spawn("v2_unit_guardian", rival, archdemon.coord + Vector2i(2, 0))
	assert_eq(V2MagicRuntime.predict_damage(archdemon, arch_target, V2SpellDatabase.get_spell("v2_spell_infernal_flame")), 7.5)
	arch_target.hp = arch_target.unit_data.max_hp * 0.5
	assert_eq(V2MagicRuntime.predict_damage(archdemon, arch_target, devouring), 15.0)
	var seraph_coord := _free_coord(city.coord, 8, 5)
	var seraph := _spawn(SERAPH, human, seraph_coord)
	assert_not_null(seraph)
	assert_false(V2ManifestationSystem.slot_available(human, "sacred"))
	assert_false(V2ManifestationSystem.slot_available(human, "infernal"))

	# 54–60: round-trip preserva escolas, unidades, Mana, pesquisa e cooldowns sem misturar V1.
	warlock.magic_cooldowns["v2_spell_damnation"] = TurnManager.turn_number + 4
	var mana_saved := human.mana
	assert_true(SaveManager.save_game(_grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	_grid.queue_free()
	_grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	assert_eq(human.mana, mana_saved)
	assert_true(human.v2_research.is_completed("v2_magic_infernal_9"))
	assert_not_null(_find(SERAPH))
	assert_not_null(_find(ARCHDEMON))
	var loaded_warlock := _find(WARLOCK)
	assert_not_null(loaded_warlock)
	assert_eq(loaded_warlock.unit_data.v2_magic_school, "infernal")
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_warlock, "v2_spell_damnation"), 4)

	# 61–63: demais árvores intactas; Transcendência conectada, porém pesquisa sozinha não vence.
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55)
	assert_eq(V2InfrastructureContent.CONNECTED_UNLOCK_IDS.size(), 18)
	assert_true(human.v2_research.complete_research("v2_transcendence"))
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)
