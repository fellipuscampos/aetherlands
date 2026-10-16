extends GutTest

## Contratos de gameplay: líder fora da porta/subterrâneo, conquista regional, população finita,
## reocupação justa, uma única cadência e continuidade de saves.
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var original := {}

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	grid = HexGrid.new()
	add_child(grid)
	grid.map_seed = 4242
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for coord in HexMetrics.coords_within(Vector2i.ZERO, 26):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	WorldEventManager.reset_for_new_match()
	MonsterEcologySystem.enabled = true
	MonsterEcologySystem.rng.seed = 4242 + MonsterEcologyData.RNG_SALT
	MonsterEcologySystem.targets = {"BASIC": 0, "INTERMEDIATE": 0, "ADVANCED": 0}
	TurnManager.turn_number = 10

func after_each():
	SelectionManager.reset()
	V2AITacticalAI.clear_views()
	for player in GameManager.players:
		player.release_relations()
	grid.queue_free()
	for key in original:
		if key not in ["turn", "events"]:
			GameManager.set(key, original[key])
	TurnManager.turn_number = original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(original.events)
	await get_tree().process_frame

func _site(kind: String, coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	return MonsterEcologySystem._create_lair_site(grid, kind, coord, MonsterEcologySystem.SOURCE_INITIAL, TurnManager.turn_number, [] as Array[Vector2i])

func _round(turn: int) -> void:
	TurnManager.turn_number = turn
	grid.process_monster_lairs(turn)

func _soldier(coord: Vector2i = Vector2i(1, 0)) -> Unit:
	var old := grid.get_unit_at(coord)
	if old != null:
		grid.remove_unit(old)
	return grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), human)

func test_all_twelve_species_have_a_real_lair_one_leader_and_unchanged_attributes():
	var column := -22
	for species in MonsterEcologyData.SPECIES_ORDER:
		var site := _site(species, Vector2i(column, 0))
		var members := grid.lair_members(site.lair)
		assert_eq(members.size(), MonsterEcologyData.group_size(species))
		assert_true(grid.lairs_by_coord.has(site.lair))
		assert_null(grid.get_unit_at(site.lair), "porta reservada para a estrutura")
		var count := 0
		var base := MonsterDatabase.create_monster(species)
		for member in members:
			count += 1 if MonsterEcologySystem.is_lair_leader(member) else 0
			assert_eq(member.unit_data.max_hp, base.max_hp)
			assert_eq(member.unit_data.attack, base.attack)
			assert_eq(member.unit_data.defense, base.defense)
			assert_eq(member.unit_data.movement_points, base.movement_points)
		assert_eq(count, 1, species + " tem exatamente um líder")
		column += 4

func test_living_leader_protects_the_structure_away_from_the_door_and_underground():
	var site := _site("colossal_worm")
	var leader := MonsterEcologySystem.leader_for_lair(site.lair)
	grid.units_by_coord.erase(leader.coord)
	leader.coord = Vector2i(6, 0)
	grid.units_by_coord[leader.coord] = leader
	var soldier := _soldier()
	assert_false(CombatResolver.can_attack_lair(soldier, site.lair, grid))
	grid.units_by_coord.erase(leader.coord)
	MonsterAbilitySystem.burrowed.append(leader)
	assert_false(CombatResolver.can_attack_lair(soldier, site.lair, grid), "enterrar-se não equivale a morrer")
	MonsterAbilitySystem.burrowed.erase(leader)
	grid.remove_unit(leader)
	assert_true(CombatResolver.can_attack_lair(soldier, site.lair, grid))

func test_leader_death_unlocks_one_hit_clear_even_with_surviving_companions():
	var site := _site("skeleton")
	var coord: Vector2i = site.lair
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(coord))
	var soldier := _soldier()
	assert_gt(grid.lair_population(coord), 0, "há sobreviventes")
	assert_true(CombatResolver.can_attack_lair(soldier, coord, grid))
	var gold := human.gold
	var reward: float = grid.lair_clear_rewards(coord).gold
	CombatResolver.resolve_lair_attack(soldier, coord, grid)
	assert_false(grid.lairs_by_coord.has(coord))
	assert_eq(human.gold, gold + reward)
	assert_gt(grid.lair_population(coord), 0, "destruir não apaga criaturas vivas")
	assert_false(MonsterEcologyPlanner.depletion_ok(Vector2i(8, 0), MonsterEcologySystem.depleted, 29))
	assert_true(MonsterEcologyPlanner.depletion_ok(Vector2i(8, 0), MonsterEcologySystem.depleted, 30))
	soldier.movement_left = 2.0
	CombatResolver.resolve_lair_attack(soldier, coord, grid)
	assert_eq(human.gold, gold + reward, "sem recompensa duplicada")

func test_reinforcements_count_patrollers_and_share_one_global_birth_budget():
	var records: Array[Dictionary] = []
	for index in 5:
		var site := _site("skeleton", Vector2i(index * 4 - 8, 0))
		records.append(site)
		for member in grid.lair_members(site.lair):
			if not MonsterEcologySystem.is_lair_leader(member):
				grid.remove_unit(member)
		var leader := MonsterEcologySystem.leader_for_lair(site.lair)
		grid.units_by_coord.erase(leader.coord)
		leader.coord = Vector2i(index * 4 - 8, 6)
		grid.units_by_coord[leader.coord] = leader
	var before := grid.neutral_units().size()
	_round(16)
	assert_eq(grid.neutral_units().size() - before, MonsterEcologyData.MAX_BIRTHS_PER_ROUND)
	var after := grid.neutral_units().size()
	_round(16)
	assert_eq(grid.neutral_units().size(), after, "mesma rodada não processa duas vezes")
	for turn in range(17, 61):
		_round(turn)
	for site in records:
		assert_eq(grid.lair_population(site.lair), 3, "patrulheiros contam no teto pela origem")

func test_no_reinforcement_or_recovery_in_view_of_either_civilization():
	var site := _site("goblin")
	for member in grid.lair_members(site.lair):
		if not MonsterEcologySystem.is_lair_leader(member):
			grid.remove_unit(member)
	grid.spawn_unit(Vector2i(2, 0), UnitDatabase.create_unit("warrior"), rival)
	_round(16)
	assert_eq(grid.lair_population(site.lair), 1, "visão da IA também bloqueia spawn")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	for turn in range(17, 39):
		_round(turn)
	assert_eq(grid.lair_population(site.lair), 0, "sem chegada surpresa enquanto observado")

func test_abandoned_lair_has_a_twelve_round_window_then_reoccupies_with_preparation():
	var site := _site("troll")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	for turn in range(11, 22):
		_round(turn)
	assert_null(MonsterEcologySystem.leader_for_lair(site.lair))
	_round(22)
	_round(23) # cadência global de duas rodadas pode adiar a primeira oportunidade em uma rodada
	var leader := MonsterEcologySystem.leader_for_lair(site.lair)
	assert_not_null(leader)
	assert_eq(MonsterEcologySystem.monster_directive(leader).mode, "dormant")
	_round(26)
	assert_eq(MonsterEcologySystem.monster_directive(leader).mode, "ecology")

func test_cleared_region_blocks_births_from_nearby_surviving_lairs_too():
	var cleared := _site("troll")
	var nearby := _site("skeleton", Vector2i(5, 0))
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(cleared.lair))
	grid.destroy_lair(cleared.lair)
	for member in grid.lair_members(nearby.lair):
		if not MonsterEcologySystem.is_lair_leader(member):
			grid.remove_unit(member)
	for turn in range(11, 30):
		_round(turn)
	assert_eq(grid.lair_population(nearby.lair), 1)
	_round(30)
	assert_gt(grid.lair_population(nearby.lair), 1, "a trégua termina, não é uma extinção permanente")

func test_destroying_every_lair_does_not_disable_future_recolonization():
	var site := _site("troll")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	grid.destroy_lair(site.lair)
	MonsterEcologySystem.targets.INTERMEDIATE = 1
	for turn in range(11, 45):
		_round(turn)
	assert_gt(grid.neutral_units().size(), 0)
	assert_eq(int(MonsterEcologySystem.sites_by_tier().INTERMEDIATE), 1)
	for current in MonsterEcologySystem.sites:
		assert_true(grid.lairs_by_coord.has(current.lair))
		assert_not_null(MonsterEcologySystem.leader_for_lair(current.lair))

func test_regional_and_resource_lairs_join_the_same_registry_and_population_budget():
	grid.create_lair(Vector2i.ZERO, "skeleton", HexGrid.LAIR_ROLE_REGIONAL, Vector2i(-1, 0))
	var regional := MonsterEcologySystem.register_lair(grid, Vector2i.ZERO, 10)
	assert_false(regional.is_empty())
	assert_eq(int(MonsterEcologySystem.sites_by_tier().BASIC), 1)
	MonsterEcologySystem.targets.BASIC = 1
	assert_eq(int(MonsterEcologySystem.deficits_by_tier().BASIC), 0)
	var again := MonsterEcologySystem.register_lair(grid, Vector2i.ZERO, 10)
	assert_eq(int(again.id), int(regional.id), "registro idempotente")
	grid.create_lair(Vector2i(8, 0), "troll", HexGrid.LAIR_ROLE_GUARDIAN, Vector2i(9, 0))
	MonsterEcologySystem.register_lair(grid, Vector2i(8, 0), 10)
	assert_eq(int(MonsterEcologySystem.sites_by_tier().INTERMEDIATE), 1)
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(Vector2i(8, 0)))
	for turn in range(11, 40):
		_round(turn)
	assert_eq(grid.lair_population(Vector2i(8, 0)), 0, "recurso conquistado não recebe guardião recorrente")

func test_save_restores_leader_death_recovery_clock_rng_and_round_guard_without_spawning():
	var site := _site("goblin")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	_round(14)
	var saved := MonsterEcologySystem.to_save_dict()
	var count := grid.neutral_units().size()
	MonsterEcologySystem.load_save_dict(saved, grid)
	assert_eq(grid.neutral_units().size(), count)
	assert_eq(MonsterEcologySystem.to_save_dict(), saved)
	assert_null(MonsterEcologySystem.leader_for_lair(site.lair), "save não promove sobrevivente a líder")
	_round(14)
	assert_eq(MonsterEcologySystem.to_save_dict(), saved)

func test_v26_territory_materializes_locally_on_next_round_without_extra_monsters():
	var site := MonsterEcologySystem._create_site(grid, "troll", Vector2i.ZERO, HexGrid.NO_LAIR, MonsterEcologySystem.SOURCE_INITIAL, 10, [Vector2i.ZERO] as Array[Vector2i])
	var saved := MonsterEcologySystem.to_save_dict()
	saved.erase("lair_rules_version")
	for record in saved.sites:
		record.erase("leader_serial")
	var before := grid.neutral_units().size()
	MonsterEcologySystem.load_save_dict(saved, grid)
	assert_eq(grid.lairs_by_coord.size(), 0, "nenhuma estrutura nasce no deserialize")
	_round(11)
	var restored := MonsterEcologySystem.site_by_id(int(site.id))
	assert_true(grid.lairs_by_coord.has(restored.lair))
	assert_lte(HexMetrics.axial_distance(restored.lair, Vector2i.ZERO), 2)
	assert_eq(grid.neutral_units().size(), before)
	assert_not_null(MonsterEcologySystem.leader_for_lair(restored.lair))

func test_worm_keeps_leadership_through_real_burrow_save_load_and_emergence():
	var site := _site("colossal_worm")
	var leader := MonsterEcologySystem.leader_for_lair(site.lair)
	_soldier(Vector2i(1, 0))
	leader.hp = leader.unit_data.max_hp * 0.3
	assert_true(MonsterAbilitySystem._try_burrow(leader, grid, site.anchor, 6))
	assert_true(MonsterEcologySystem.is_lair_leader(leader))
	var saved := MonsterEcologySystem.to_save_dict()
	MonsterAbilitySystem.burrowed.erase(leader)
	leader.queue_free()
	MonsterEcologySystem.load_save_dict(saved, grid)
	var restored := MonsterEcologySystem.leader_for_lair(site.lair)
	assert_not_null(restored)
	assert_true(MonsterAbilitySystem.is_burrowed(restored))
	assert_eq(restored.source_lair_coord, site.lair)
	_round(11)
	assert_false(MonsterAbilitySystem.is_burrowed(restored))
	assert_true(MonsterEcologySystem.is_lair_leader(restored))
	assert_eq(MonsterEcologySystem.leader_for_lair(site.lair), restored)

func test_reoccupied_coordinate_is_not_deleted_by_the_saved_clear_history():
	var site := _site("troll")
	var coord: Vector2i = site.lair
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(coord))
	grid.destroy_lair(coord)
	assert_true(coord in grid.cleared_lair_coords)
	TurnManager.turn_number = 30
	_site("troll", coord)
	assert_false(coord in grid.cleared_lair_coords, "só a estrutura antiga foi destruída")
	var saved := SaveManager._serialize_lair_state(grid)
	assert_true((saved.added as Array).any(func(entry): return int(entry[0]) == coord.x and int(entry[1]) == coord.y))

func test_legacy_flying_lair_on_lava_uses_unified_leader_recovery():
	for coord in [Vector2i.ZERO] + grid.get_neighbors(Vector2i.ZERO):
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
	grid.create_lair(Vector2i.ZERO, "wyvern", HexGrid.LAIR_ROLE_WILD, Vector2i(-1, 0))
	var site := MonsterEcologySystem.register_lair(grid, Vector2i.ZERO, 10)
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	for turn in range(11, 24):
		_round(turn)
	var leader := MonsterEcologySystem.leader_for_lair(site.lair)
	assert_not_null(leader, "covil legado de voador não é abandonado pelo novo controlador")
	assert_eq(grid.lair_population(site.lair), 1, "espécie solitária continua com um indivíduo")
	assert_true(leader.unit_data.flies)

func _relocate(unit: Unit, destination: Vector2i) -> void:
	grid.units_by_coord.erase(unit.coord)
	unit.coord = destination
	grid.units_by_coord[destination] = unit

func _monster_action(unit: Unit, turn: int) -> void:
	TurnManager.turn_number = turn
	unit.reset_movement()
	MonsterAI.act_for_unit(unit, grid, turn)

func test_off_era_monster_reacts_to_ranged_damage_then_attacks_the_aggressor():
	var site := _site("mana_devourer")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var home := monster.coord
	var archer := grid.spawn_unit(home + Vector2i(3, 0), UnitDatabase.create_unit("v2_unit_elite_marksman"), human)
	TurnManager.turn_number = 11
	CombatResolver.resolve(archer, monster, grid)
	assert_true(monster.ability_state.has("retaliation"))
	_monster_action(monster, 11)
	assert_lt(HexMetrics.axial_distance(monster.coord, archer.coord), 3, "alcance de detecção passiva não impede a defesa")
	_monster_action(monster, 12)
	_monster_action(monster, 13)
	assert_true(archer.hp < archer.unit_data.max_hp or UnitStatusEffects.is_active(archer, UnitStatusEffects.SILENCED), "chega ao agressor e reage")

func test_fleeing_aggressor_is_dropped_and_monster_returns_without_healing_or_teleporting():
	var site := _site("mana_devourer")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var home := monster.coord
	var attacker := _soldier(home + Vector2i(3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	_monster_action(monster, 11)
	assert_ne(monster.coord, home)
	var hp := monster.hp
	_relocate(attacker, home + Vector2i(12, 0))
	_monster_action(monster, 12)
	_monster_action(monster, 13)
	assert_lte(HexMetrics.axial_distance(monster.coord, home), MonsterAI.RETURN_HOME_RADIUS)
	assert_eq(monster.hp, hp, "retorno não restaura Vida")
	assert_false(monster.ability_state.has("retaliation"))

func test_repeated_pokes_do_not_move_the_retaliation_home_or_expand_its_leash():
	var site := _site("mana_devourer")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var attacker := _soldier(monster.coord + Vector2i(3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	var home: Array = monster.ability_state.retaliation.home.duplicate()
	var radius := int(monster.ability_state.retaliation.radius)
	_monster_action(monster, 11)
	_relocate(attacker, monster.coord + Vector2i(3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	assert_eq(monster.ability_state.retaliation.home, home)
	assert_eq(int(monster.ability_state.retaliation.radius), radius)

func test_attacking_a_dormant_lair_provokes_only_its_nearby_band_including_on_a_killing_blow():
	var site := _site("skeleton")
	site.wake_turn = 40
	var leader := MonsterEcologySystem.leader_for_lair(site.lair)
	var stranger_site := _site("goblin", Vector2i(4, 0))
	var attacker := _soldier(Vector2i(0, 3))
	CombatResolver.apply_direct_unit_damage(attacker, leader, 1000.0, grid)
	var alerted := 0
	for member in grid.lair_members(site.lair):
		if member.ability_state.has("retaliation"):
			alerted += 1
			var before := HexMetrics.axial_distance(member.coord, attacker.coord)
			_monster_action(member, 11)
			assert_lt(HexMetrics.axial_distance(member.coord, attacker.coord), before)
	assert_gt(alerted, 0, "companheiros defendem o bando mesmo durante o aviso de preparação")
	for member in grid.lair_members(stranger_site.lair):
		assert_false(member.ability_state.has("retaliation"), "sem aggro de covis alheios")

func test_provocation_overrides_raid_and_retargets_the_latest_attacker():
	var site := _site("goblin")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var first := _soldier(monster.coord + Vector2i(3, 0))
	var second := _soldier(monster.coord + Vector2i(-3, 0))
	monster.ability_state.raid_target = [8, 0]
	CombatResolver.apply_direct_unit_damage(first, monster, 1.0, grid)
	CombatResolver.apply_direct_unit_damage(second, monster, 1.0, grid)
	assert_eq(int(monster.ability_state.retaliation.target), second.serial_id)
	assert_false(monster.ability_state.has("raid_target"))
	var before := HexMetrics.axial_distance(monster.coord, second.coord)
	_monster_action(monster, 11)
	assert_lt(HexMetrics.axial_distance(monster.coord, second.coord), before)

func test_retaliation_keeps_its_target_across_serializable_state_and_ends_when_target_dies():
	var site := _site("mana_devourer")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var attacker := _soldier(monster.coord + Vector2i(3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	var saved_units: Array = JSON.parse_string(JSON.stringify(SaveManager._serialize_neutral_units(grid)))
	var saved_ecology: Dictionary = JSON.parse_string(JSON.stringify(MonsterEcologySystem.to_save_dict()))
	grid.remove_unit(monster)
	SaveManager._deserialize_neutral_units(saved_units, grid)
	MonsterEcologySystem.load_save_dict(saved_ecology, grid)
	monster = MonsterEcologySystem.leader_for_lair(site.lair)
	assert_not_null(monster)
	_monster_action(monster, 11)
	assert_eq(int(monster.ability_state.retaliation.target), attacker.serial_id)
	grid.remove_unit(attacker)
	_monster_action(monster, 12)
	_monster_action(monster, 13)
	assert_false(monster.ability_state.has("retaliation"))

func test_registered_legacy_leader_can_move_to_answer_ranged_attack():
	grid.create_lair(Vector2i.ZERO, "troll", HexGrid.LAIR_ROLE_GUARDIAN, Vector2i(-1, 0))
	var site := MonsterEcologySystem.register_lair(grid, Vector2i.ZERO, 10)
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	assert_eq(monster.unit_data.movement_points, MonsterDatabase.create_monster("troll").movement_points)
	var attacker := _soldier(monster.coord + Vector2i(-3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	var before := HexMetrics.axial_distance(monster.coord, attacker.coord)
	_monster_action(monster, 11)
	assert_lt(HexMetrics.axial_distance(monster.coord, attacker.coord), before)

func test_lair_is_placed_at_actual_surface_height():
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.CRYSTAL_PEAKS)
	grid.create_lair(Vector2i.ZERO, "mana_devourer", HexGrid.LAIR_ROLE_ECOLOGY)
	assert_almost_eq((grid.lairs_by_coord[Vector2i.ZERO] as LairStructure).position.y, grid.world_surface_for_coord(Vector2i.ZERO).y, 0.0001)

func test_caster_without_basic_attack_can_only_dismantle_an_undefended_lair_from_adjacent():
	var site := _site("troll")
	var mage := grid.spawn_unit(Vector2i(-2, 0), UnitDatabase.create_unit("v2_unit_infernal_warlock"), human)
	assert_false(mage.unit_data.can_basic_attack)
	assert_false(CombatResolver.can_attack_lair(mage, site.lair, grid), "líder ainda protege a estrutura")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	assert_false(CombatResolver.can_attack_lair(mage, site.lair, grid), "desmantelar exige adjacência")
	_relocate(mage, Vector2i(-1, 0))
	assert_true(CombatResolver.can_attack_lair(mage, site.lair, grid))
	SelectionManager._select_unit(mage)
	assert_true(site.lair in SelectionManager.attackable, "a ação também está disponível na seleção humana")
	var mana := human.mana
	SelectionManager._resolve_attack_from_selected(site.lair, "")
	assert_false(grid.lairs_by_coord.has(site.lair))
	assert_eq(mage.movement_left, 0.0)
	assert_eq(human.mana, mana, "desmantelar não conjura feitiço")
	assert_false(mage.unit_data.can_basic_attack, "não concede ataque básico")

func test_civilians_cannot_dismantle_a_lair_and_a_spent_caster_cannot_repeat_the_action():
	var site := _site("troll")
	grid.remove_unit(MonsterEcologySystem.leader_for_lair(site.lair))
	var settler := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("settler"), human)
	assert_false(CombatResolver.can_attack_lair(settler, site.lair, grid))
	var mage := grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("v2_unit_infernal_warlock"), human)
	mage.movement_left = 0.0
	assert_false(CombatResolver.can_attack_lair(mage, site.lair, grid))

func test_dormant_troll_guardian_regenerates_once_per_action_and_damage_interrupts_it():
	var site := _site("troll")
	grid.set_lair_role(site.lair, HexGrid.LAIR_ROLE_GUARDIAN)
	var troll := MonsterEcologySystem.leader_for_lair(site.lair)
	troll.set_hp_silent(10.0)
	troll.took_damage_since_regen = false
	_monster_action(troll, 11)
	assert_eq(troll.hp, 12.0, "passiva do guardião não desaparece por causa do papel")
	var attacker := _soldier(troll.coord + Vector2i(3, 0))
	CombatResolver.apply_direct_unit_damage(attacker, troll, 1.0, grid)
	_monster_action(troll, 12)
	assert_eq(troll.hp, 11.0, "tomar dano interrompe a regeneração")
	_monster_action(troll, 13)
	assert_eq(troll.hp, 13.0, "mesmo reagindo, cura uma vez por ação")

func test_all_twelve_species_answer_damage_outside_their_native_era():
	for kind in MonsterEcologyData.SPECIES_ORDER:
		WorldEventManager.world_phase = WorldPhaseRules.Phase.CONVERGENCE if MonsterEcologyData.tier_of(kind) == MonsterEcologyData.TIER_BASIC else WorldPhaseRules.Phase.FOUNDATION
		var site := _site(kind)
		var monster := MonsterEcologySystem.leader_for_lair(site.lair)
		var home := monster.coord
		var attacker := _soldier(home + Vector2i(3, 0))
		CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
		_monster_action(monster, 11)
		assert_true(monster.coord != home or attacker.hp < attacker.unit_data.max_hp or not monster.magic_cooldowns.is_empty(), kind + " reage fora da era")
		for member in grid.neutral_units().duplicate():
			grid.remove_unit(member)
		grid.remove_unit(attacker)
		grid.destroy_lair(site.lair)

func test_real_offensive_spell_provokes_an_off_era_monster_without_granting_an_extra_action():
	var site := _site("arboreal_ancient")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	var home := monster.coord
	var mage := grid.spawn_unit(home + Vector2i(3, 0), UnitDatabase.create_unit("v2_unit_infernal_warlock"), human)
	human.mana = 100.0
	for tier in range(V2ResearchDatabase.BRANCH_FIRST_TIER, 5):
		human.v2_research.complete_research("v2_magic_infernal_%d" % tier)
	assert_true(V2MagicRuntime.cast(mage, "v2_spell_infernal_flame", monster.coord, grid))
	assert_eq(int(monster.ability_state.retaliation.target), mage.serial_id)
	assert_eq(monster.coord, home, "dano não dispara uma ação fora do turno")
	_monster_action(monster, 11)
	assert_ne(monster.coord, home)

func test_retaliation_does_not_seek_a_continent_wide_detour_to_an_unreachable_aggressor():
	var site := _site("mana_devourer")
	var monster := MonsterEcologySystem.leader_for_lair(site.lair)
	_relocate(monster, Vector2i(-1, 0))
	for r in range(-8, 9):
		if r != 0:
			grid.tiles[Vector2i(0, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var attacker := _soldier(Vector2i(2, 0))
	CombatResolver.apply_direct_unit_damage(attacker, monster, 1.0, grid)
	_monster_action(monster, 11)
	_monster_action(monster, 12)
	assert_eq(monster.coord, Vector2i(-1, 0), "a rota por fora do confronto não é uma perseguição legal")
	assert_true(bool(monster.ability_state.retaliation.returning), "desiste após duas tentativas sem progresso")
	_monster_action(monster, 13)
	assert_false(monster.ability_state.has("retaliation"))
