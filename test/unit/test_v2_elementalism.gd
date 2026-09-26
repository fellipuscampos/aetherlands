extends GutTest

const SCHOOL := "elementalism"
const CASTER := "v2_unit_elementalist"
const PRIMORDIAL := "v2_manifestation_elemental_primordial"
const MIST := "v2_spell_dense_mist"
const GALE := "v2_spell_gale"
const STORM := "v2_spell_lightning_storm"
const CATACLYSM := "v2_spell_elemental_cataclysm"
const Z_MIST := "v2_zone_dense_mist"
const Z_GALE := "v2_zone_gale"
const Z_STORM := "v2_zone_lightning_storm"
const Z_CATACLYSM := "v2_zone_elemental_cataclysm"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_turn: int

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	grid = HexGrid.new()
	grid._ready()
	for q in range(-10, 11):
		for r in range(-10, 11):
			if absi(q + r) <= 10:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Elemental")
	rival = _player("Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 80
	human.mana = 500.0
	rival.mana = 500.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	for player in _players:
		player.release_relations()
	_players.clear()
	if is_instance_valid(grid):
		grid.queue_free()

func _player(name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = name
	_players.append(player)
	return player

func _learn(player: PlayerData, through: int = 9, branch: String = SCHOOL) -> void:
	for tier in range(1, through + 1):
		var id := "v2_magic_%s_%d" % [branch, tier]
		if not player.v2_research.is_completed(id):
			assert_true(player.v2_research.complete_research(id), id)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _caster(through: int = 7, kind: String = CASTER, coord: Vector2i = Vector2i.ZERO) -> Unit:
	_learn(human, through)
	return _unit(kind, human, coord)

func _apply(coord: Vector2i, zone: String, rounds_bonus: int = 0) -> bool:
	return V2EnvironmentalZoneSystem.apply(grid, coord, zone, 0, SCHOOL, rounds_bonus)

func _code_only(source: String) -> String:
	var lines: Array[String] = []
	for line in source.split("\n"):
		lines.append(line.split("#", true, 1)[0])
	return "\n".join(lines)

func test_all_nine_nodes_and_transcendence_are_canonical_connected():
	var names := ["Escola do Elementalismo", "Observatório Elemental", "Elementalista", "Névoa Cerrada", "Vendaval", "Tempestade Elétrica", "Cataclismo Elemental", "Nexo dos Elementos", "Primordial dos Elementos"]
	var ids := ["v2_magic_school_elementalism", "v2_building_elemental_observatory", CASTER, MIST, GALE, STORM, CATACLYSM, "v2_building_elemental_ritual", PRIMORDIAL]
	var nodes := V2ResearchDatabase.nodes_for_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, SCHOOL)
	assert_eq(nodes.size(), 9)
	for i in 9:
		assert_eq([nodes[i].display_name, nodes[i].unlock_id], [names[i], ids[i]])
		assert_true(nodes[i].gameplay_connected)
		assert_false(nodes[i].is_placeholder)
	assert_eq(V2MagicContent.CONNECTED_UNLOCK_IDS.size(), 55)
	assert_true(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected)

func test_buildings_units_and_manifestation_have_exact_data():
	var observatory := BuildingDatabase.get_building("v2_building_elemental_observatory")
	var nexus := BuildingDatabase.get_building("v2_building_elemental_ritual")
	assert_eq([observatory.display_name, observatory.production_cost, observatory.gold_upkeep, observatory.trains_unit, observatory.copy_limit_mode], ["Observatório Elemental", 24.0, 1.0, CASTER, BuildingData.CopyLimitMode.UNIQUE])
	assert_eq([nexus.display_name, nexus.production_cost, nexus.gold_upkeep, nexus.requires_building, nexus.trains_unit], ["Nexo dos Elementos", 60.0, 2.0, "v2_building_elemental_observatory", PRIMORDIAL])
	var caster := UnitDatabase.create_unit(CASTER)
	assert_eq([caster.max_hp, caster.attack, caster.defense, caster.movement_points, caster.vision_range, caster.production_cost, caster.supply_cost], [11.0, 0.0, 1.5, 2.0, 4, 24.0, 2])
	assert_eq([caster.can_basic_attack, caster.v2_magic_school, caster.movement_profile], [false, SCHOOL, UnitData.MovementProfile.GROUND])
	var primordial := UnitDatabase.create_unit(PRIMORDIAL)
	assert_eq([primordial.max_hp, primordial.attack, primordial.defense, primordial.movement_points, primordial.vision_range, primordial.production_cost, primordial.production_mana_cost, primordial.supply_cost], [40.0, 0.0, 6.5, 4.0, 5, 110.0, 75.0, 0])
	assert_eq([primordial.movement_profile, primordial.environmental_zone_duration_bonus, primordial.environmental_zone_duration_bonus_name], [UnitData.MovementProfile.FLYING, 1, "Coração Elemental"])
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_FLYING, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(primordial.has_trait(trait_id), trait_id)
	for trait_id in [UnitData.TRAIT_LEGENDARY, UnitData.TRAIT_RETINUE, UnitData.TRAIT_UNDEAD]:
		assert_false(primordial.has_trait(trait_id), trait_id)

func test_spell_and_zone_records_are_exact_and_data_driven():
	var defaults := V2EnvironmentalZoneData.new()
	assert_eq([defaults.duration_rounds, defaults.vision_delta, defaults.physical_ranged_attack_multiplier, defaults.round_tick_magic_damage, defaults.dispellable], [0, 0, 1.0, 0.0, true])
	var spells := V2SpellDatabase.for_school(SCHOOL)
	assert_eq(spells.map(func(s): return s.id), [MIST, GALE, STORM, CATACLYSM])
	var expected := [[6.0, 4, 2, 1, Z_MIST], [8.0, 4, 2, 1, Z_GALE], [12.0, 4, 3, 1, Z_STORM], [20.0, 5, 5, 2, Z_CATACLYSM]]
	for i in 4:
		assert_eq([spells[i].mana_cost, spells[i].cast_range, spells[i].cooldown_turns, spells[i].splash_radius, spells[i].environmental_zone_id], expected[i])
		assert_eq(spells[i].target_mode, V2SpellData.TargetMode.TILE)
	var zone_expected := {Z_MIST: [2, -2, 1.0, 0.0], Z_GALE: [2, 0, 0.70, 0.0], Z_STORM: [2, 0, 1.0, 4.0], Z_CATACLYSM: [2, -1, 0.80, 5.0]}
	for id in zone_expected:
		var zone := V2EnvironmentalZoneDatabase.get_zone(id)
		assert_eq([zone.duration_rounds, zone.vision_delta, zone.physical_ranged_attack_multiplier, zone.round_tick_magic_damage], zone_expected[id], id)
		assert_true(zone.dispellable)

func test_environmental_cast_accepts_any_terrain_and_entities_but_rejects_a_zoned_primary():
	var caster := _caster(4)
	var spell := V2SpellDatabase.get_spell(MIST)
	var targets := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	grid.tiles[targets[0]] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.tiles[targets[1]] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid.found_city(targets[2], rival, "Cidade", true)
	_unit("warrior", rival, targets[3])
	for coord in targets:
		assert_eq(V2MagicRuntime.tile_reason(caster, spell, coord, grid), "", str(coord))
	assert_true(V2MagicRuntime.cast(caster, MIST, targets[0], grid))
	assert_eq(V2MagicRuntime.tile_reason(caster, spell, targets[0], grid), V2EnvironmentalZoneSystem.OCCUPIED_REASON)

func test_radius_one_is_primary_first_skips_existing_and_hidden_secondary_and_charges_once():
	var caster := _caster(4)
	var primary := Vector2i(2, 0)
	var existing := Vector2i(2, -1)
	var hidden := Vector2i(1, 1)
	assert_true(_apply(existing, Z_GALE))
	grid.visibility[primary] = HexGrid.Visibility.VISIBLE
	for coord in HexMetrics.coords_within(primary, 1):
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[hidden] = HexGrid.Visibility.UNSEEN
	var before := human.mana
	assert_true(V2MagicRuntime.cast(caster, MIST, primary, grid))
	assert_eq(human.mana, before - 6.0)
	assert_eq(grid.v2_environmental_zones.size(), 6, "1 Gale + primary e quatro secundários")
	assert_eq(String(grid.v2_environmental_zones[existing].zone_id), Z_GALE)
	assert_false(grid.v2_environmental_zones.has(hidden))

func test_cataclysm_fills_nineteen_tiles_and_combines_all_three_effects():
	var caster := _caster(7)
	var primary := Vector2i(2, 0)
	assert_true(V2MagicRuntime.cast(caster, CATACLYSM, primary, grid))
	assert_eq(grid.v2_environmental_zones.size(), 19)
	var zone := V2EnvironmentalZoneSystem.zone_at(primary, grid)
	assert_eq([zone.vision_delta, zone.physical_ranged_attack_multiplier, zone.round_tick_magic_damage], [-1, 0.8, 5.0])

func test_effective_vision_has_fast_path_floor_and_position_semantics():
	var caster := _unit(CASTER, human, Vector2i.ZERO)
	assert_eq(V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid), 4)
	assert_true(_apply(caster.coord, Z_MIST))
	assert_eq(V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid), 2)
	V2EnvironmentalZoneSystem.remove(grid, caster.coord)
	assert_true(_apply(caster.coord, Z_CATACLYSM))
	assert_eq(V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid), 3)
	caster.unit_data.vision_range = 1
	V2EnvironmentalZoneSystem.remove(grid, caster.coord)
	assert_true(_apply(caster.coord, Z_MIST))
	assert_eq(V2EnvironmentalZoneSystem.effective_unit_vision(caster, grid), 1)

func test_mist_updates_human_fog_immediately_and_dispel_restores_it():
	var caster := _caster(4)
	grid.recompute_fog(human)
	var outer := Vector2i(4, 0)
	assert_eq(grid.visibility.get(outer), HexGrid.Visibility.VISIBLE)
	assert_true(V2MagicRuntime.cast(caster, MIST, caster.coord, grid))
	assert_ne(grid.visibility.get(outer), HexGrid.Visibility.VISIBLE)
	V2EnvironmentalZoneSystem.remove(grid, caster.coord, true)
	assert_eq(grid.visibility.get(outer), HexGrid.Visibility.VISIBLE)

func test_gale_uses_attacker_tile_and_only_physical_ranged_pipeline():
	var archer := _unit("archer", human, Vector2i.ZERO)
	var defender := _unit("warrior", rival, Vector2i(2, 0))
	var normal := float(CombatResolver.predict(archer, defender, grid).damage_to_defender)
	assert_true(_apply(archer.coord, Z_GALE))
	var windy := float(CombatResolver.predict(archer, defender, grid).damage_to_defender)
	assert_lt(windy, normal)
	V2EnvironmentalZoneSystem.remove(grid, archer.coord)
	assert_true(_apply(defender.coord, Z_GALE))
	assert_eq(CombatResolver.predict(archer, defender, grid).damage_to_defender, normal, "alvo dentro não importa")
	var melee := _unit("men_at_arms", human, Vector2i(1, -1))
	var melee_normal := float(CombatResolver.predict(melee, defender, grid).damage_to_defender)
	assert_true(_apply(melee.coord, Z_GALE))
	assert_eq(CombatResolver.predict(melee, defender, grid).damage_to_defender, melee_normal)

func test_storm_has_no_immediate_damage_then_ticks_twice_and_expires_impartially():
	var caster := _caster(6)
	var own := _unit("warrior", human, Vector2i(2, 0))
	var enemy := _unit("warrior", rival, Vector2i(2, -1))
	var own_hp := own.hp
	var enemy_hp := enemy.hp
	assert_true(V2MagicRuntime.cast(caster, STORM, own.coord, grid))
	assert_eq([own.hp, enemy.hp], [own_hp, enemy_hp], "sem dano imediato")
	var first := V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_eq([own.hp, enemy.hp], [own_hp - 4.0, enemy_hp - 4.0])
	assert_eq([first.damaged_units, first.expired_zones], [2, 0])
	var second := V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_eq([own.hp, enemy.hp], [own_hp - 8.0, enemy_hp - 8.0])
	assert_gt(second.expired_zones, 0)
	assert_true(grid.v2_environmental_zones.is_empty())

func test_environmental_death_has_no_kill_xp_loot_or_retaliation():
	var victim := _unit("warrior", rival, Vector2i.ZERO)
	victim.hp = 3.0
	var killer_candidate := _unit("warrior", human, Vector2i(1, 0))
	var kills := killer_candidate.kills
	var gold := human.gold
	assert_true(_apply(victim.coord, Z_STORM))
	V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_null(grid.get_unit_at(Vector2i.ZERO))
	assert_eq(killer_candidate.kills, kills)
	assert_eq(human.gold, gold)
	assert_eq(killer_candidate.hp, killer_candidate.unit_data.max_hp)

func test_environmental_damage_is_fixed_through_defense_terrain_aegis_v1_and_flight():
	var fixtures := [
		_unit("warrior", human, Vector2i(0, 0)),
		_unit("homem_de_escudo", rival, Vector2i(1, 0)),
		_unit("v2_manifestation_seraph", human, Vector2i(2, 0)),
		_unit("v2_legendary_griffon_rider", rival, Vector2i(3, 0)),
	]
	fixtures[1].fortified = true
	fixtures[1].magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	grid.tiles[fixtures[1].coord].defense_bonus = 5.0
	var before := fixtures.map(func(unit: Unit): return unit.hp)
	for unit in fixtures:
		assert_true(_apply(unit.coord, Z_STORM))
	V2EnvironmentalZoneSystem.process_global_round(grid)
	for i in fixtures.size():
		assert_eq(fixtures[i].hp, float(before[i]) - 4.0, fixtures[i].unit_data.unit_name)

func test_gale_does_not_change_spell_damage_or_city_attack_formula():
	_learn(human, 4, "infernal")
	var warlock := _unit("v2_unit_infernal_warlock", human, Vector2i.ZERO)
	var target := _unit("warrior", rival, Vector2i(2, 0))
	var flame := V2SpellDatabase.get_spell("v2_spell_infernal_flame")
	var spell_damage := V2MagicRuntime.predict_damage(warlock, target, flame)
	assert_true(_apply(warlock.coord, Z_GALE))
	assert_eq(V2MagicRuntime.predict_damage(warlock, target, flame), spell_damage)
	var city_coord := Vector2i(5, 0)
	var city := grid.found_city(city_coord, rival, "Alvo", true)
	var catapult := _unit("catapult", human, Vector2i(4, 0))
	assert_true(_apply(catapult.coord, Z_GALE))
	var hp_before := city.hp
	var expected := maxf(1.0, catapult.unit_data.attack * catapult.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(catapult) * V2TechniqueRuntime.city_attack_multiplier(catapult) / (1.0 + city.defense_bonus()))
	CombatResolver.resolve_city_attack(catapult, city, grid)
	assert_almost_eq(hp_before - city.hp, expected, 0.0001)

func test_primordial_materializes_three_rounds_while_existing_zones_never_recalculate():
	var elementalista := _caster(7, CASTER, Vector2i.ZERO)
	var primordial := _unit(PRIMORDIAL, human, Vector2i(5, 0))
	assert_true(V2MagicRuntime.cast(elementalista, MIST, Vector2i(1, 0), grid))
	var first := V2EnvironmentalZoneSystem.zone_entry_at(Vector2i(1, 0), grid)
	assert_eq(int(first.remaining_rounds), 2)
	assert_true(V2MagicRuntime.cast(primordial, MIST, Vector2i(6, 0), grid))
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(Vector2i(6, 0), grid).remaining_rounds), 3)
	grid.remove_unit(primordial)
	assert_eq(int(first.remaining_rounds), 2)

func test_dispel_removes_weather_and_portal_together_but_not_druid_terrain():
	_learn(human, 6, "arcanism")
	var arcanist := _unit("v2_unit_arcanist", human, Vector2i.ZERO)
	var coord := Vector2i(2, 0)
	assert_true(V2TerrainRuntime.apply(grid, coord, "v2_terrain_dense_grove"))
	assert_true(_apply(coord, Z_MIST))
	assert_true(V2PortalSystem.create_or_replace_pair(human, "arcanism", arcanist.coord, coord, grid))
	assert_true(V2MagicRuntime.cast(arcanist, "v2_spell_dispel", coord, grid))
	assert_true(V2EnvironmentalZoneSystem.zone_entry_at(coord, grid).is_empty())
	assert_true(V2PortalSystem.endpoint_at(coord, grid).is_empty())
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), "v2_terrain_dense_grove")

func test_one_dispel_removes_enemy_weather_portal_and_eligible_status_but_restore_only_removes_terrain():
	_learn(human, 6, "arcanism")
	var arcanist := _unit("v2_unit_arcanist", human, Vector2i.ZERO)
	var coord := Vector2i(2, 0)
	assert_true(V2PortalSystem.create_or_replace_pair(rival, "arcanism", Vector2i(4, 0), coord, grid))
	var enemy := _unit("v2_unit_sacred_cleric", rival, coord)
	enemy.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2TerrainRuntime.apply(grid, coord, "v2_terrain_dense_grove"))
	assert_true(V2EnvironmentalZoneSystem.apply(grid, coord, Z_MIST, 1, SCHOOL))
	assert_true(V2MagicRuntime.cast(arcanist, "v2_spell_dispel", coord, grid))
	assert_false(enemy.magic_status.has("v2_spell_sacred_aegis"))
	assert_true(V2PortalSystem.endpoint_at(coord, grid).is_empty())
	assert_true(V2EnvironmentalZoneSystem.zone_entry_at(coord, grid).is_empty())
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), "v2_terrain_dense_grove")
	_learn(human, 5, "druidism")
	var druid := _unit("v2_unit_druid", human, Vector2i(0, 2))
	druid.movement_left = druid.unit_data.movement_points
	assert_true(_apply(coord, Z_GALE))
	assert_true(V2MagicRuntime.cast(druid, "v2_spell_restore_terrain", coord, grid))
	assert_false(V2TerrainRuntime.has_modification(grid, coord))
	assert_eq(String(V2EnvironmentalZoneSystem.zone_entry_at(coord, grid).zone_id), Z_GALE)

func test_weather_coexists_with_city_building_resource_improvement_druid_and_portal_and_none_clear_it():
	var city_coord := Vector2i(2, 0)
	var building_coord := Vector2i(3, 0)
	var improved_coord := Vector2i(2, 1)
	var portal_coord := Vector2i(1, 1)
	for coord in [city_coord, building_coord, improved_coord, portal_coord]:
		assert_true(_apply(coord, Z_CATACLYSM))
	var city := grid.found_city(city_coord, human, "Convivência", true)
	assert_not_null(city)
	assert_false(V2EnvironmentalZoneSystem.zone_entry_at(city_coord, grid).is_empty(), "fundar cidade não limpa")
	assert_not_null(grid.place_building(building_coord, "v2_building_market", human, false))
	assert_false(V2EnvironmentalZoneSystem.zone_entry_at(building_coord, grid).is_empty(), "construir não limpa")
	city.owned_tiles.append(improved_coord)
	city.resource_improvements[improved_coord] = "farm"
	assert_false(V2EnvironmentalZoneSystem.zone_entry_at(improved_coord, grid).is_empty(), "melhoria não limpa")
	assert_true(V2TerrainRuntime.apply(grid, portal_coord, "v2_terrain_dense_grove"))
	assert_true(V2PortalSystem.create_or_replace_pair(human, "arcanism", Vector2i.ZERO, portal_coord, grid))
	assert_eq(V2TerrainRuntime.modification_id_at(grid, portal_coord), "v2_terrain_dense_grove")
	assert_false(V2EnvironmentalZoneSystem.zone_entry_at(portal_coord, grid).is_empty())
	assert_false(V2PortalSystem.endpoint_at(portal_coord, grid).is_empty())

func test_sparse_save_roundtrip_is_fail_safe_and_first_duplicate_wins():
	assert_true(_apply(Vector2i.ZERO, Z_MIST, 1))
	var saved := V2EnvironmentalZoneSystem.to_save_array(grid)
	saved.append(saved[0].duplicate(true))
	saved.append({"coord": [1, 0], "zone_id": "missing", "owner_index": 0, "school": SCHOOL, "remaining_rounds": 2})
	grid.v2_environmental_zones.clear()
	assert_eq(V2EnvironmentalZoneSystem.load_save_array(saved, grid), 1)
	var entry := V2EnvironmentalZoneSystem.zone_entry_at(Vector2i.ZERO, grid)
	assert_eq([entry.zone_id, entry.owner_index, entry.school, entry.remaining_rounds], [Z_MIST, 0, SCHOOL, 3])

func test_weather_never_changes_pathfinding_or_druid_and_portal_layers():
	var mover := _unit("warrior", human, Vector2i.ZERO)
	var before := grid.compute_path(mover.coord, Vector2i(5, 0), human, false, false)
	for coord in grid.tiles.keys():
		if grid.v2_environmental_zones.size() >= 100:
			break
		V2EnvironmentalZoneSystem.apply(grid, coord, Z_GALE, 0, SCHOOL, 0, false)
	var after := grid.compute_path(mover.coord, Vector2i(5, 0), human, false, false)
	assert_eq(after, before)

func test_second_primordial_is_blocked_but_other_school_and_military_slots_are_independent():
	_learn(human, 9)
	_learn(human, 9, "sacred")
	var first := _unit(PRIMORDIAL, human, Vector2i.ZERO)
	assert_false(V2ManifestationSystem.spawn_allowed(human, PRIMORDIAL))
	assert_true(V2ManifestationSystem.spawn_allowed(human, "v2_manifestation_seraph"))
	assert_true(V2LegendarySystem.legendary_slot_available(human))
	grid.remove_unit(first)
	assert_true(V2ManifestationSystem.spawn_allowed(human, PRIMORDIAL))

func test_research_reset_keeps_units_and_zones_but_removes_repertoire():
	var caster := _caster(7)
	assert_true(V2MagicRuntime.cast(caster, MIST, Vector2i(1, 0), grid))
	human.v2_research.reset()
	assert_true(is_instance_valid(caster))
	assert_false(grid.v2_environmental_zones.is_empty())
	assert_true(V2MagicRuntime.spells_for_unit(caster).is_empty())
	V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(Vector2i(1, 0), grid).remaining_rounds), 1)

func test_foundations_are_data_driven_and_global_tick_has_one_canonical_hook():
	var foundations := [
		"res://scripts/core/V2EnvironmentalZoneSystem.gd",
		"res://scripts/core/V2MagicRuntime.gd",
		"res://scripts/core/CombatResolver.gd",
		"res://scripts/world/HexGrid.gd",
		"res://scripts/autoload/GameManager.gd",
		"res://scripts/autoload/SelectionManager.gd",
		"res://scripts/ui/HUD.gd",
		"res://scripts/autoload/SaveManager.gd",
	]
	for path in foundations:
		var code := _code_only(FileAccess.get_file_as_string(path)).to_lower()
		for concrete in ["dense_mist", "v2_spell_gale", "lightning_storm", "elemental_cataclysm", "v2_unit_elementalist", "elemental_primordial"]:
			assert_false(code.contains(concrete), "%s cita %s" % [path, concrete])
	var manager := _code_only(FileAccess.get_file_as_string("res://scripts/autoload/GameManager.gd"))
	assert_eq(manager.count("V2EnvironmentalZoneSystem.process_global_round"), 1)
	var finish := manager.split("func _finish_turn")[1]
	assert_lt(finish.find("V2EnvironmentalZoneSystem.process_global_round"), finish.find("hex_grid.recompute_fog"), "tick termina antes do único refresh de fog")
	assert_false(FileAccess.file_exists("res://scripts/core/ElementalismRuntime.gd"))
