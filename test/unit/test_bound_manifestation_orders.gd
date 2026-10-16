extends GutTest

var grid: HexGrid
var human: PlayerData
var enemy: PlayerData
var home: City
var destination: City
var original := {}

func before_each():
	original = {"players":GameManager.players, "human":GameManager.human_player, "rivals":GameManager.rival_players, "grid":GameManager.hex_grid, "state":GameManager.state, "turn":TurnManager.turn_number}
	grid = HexGrid.new()
	grid._ready()
	for q in range(-12,13):
		for r in range(-12,13):
			var coord := Vector2i(q,r)
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	human = PlayerData.new(CivilizationData.new())
	enemy = PlayerData.new(CivilizationData.new())
	GameManager.players = [human,enemy]
	GameManager.human_player = human
	GameManager.rival_players = [enemy]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	TurnManager.turn_number = 40
	human.mana = 500.0
	human.gold = 500.0
	Diplomacy.declare_war(human,enemy)
	home = grid.found_city(Vector2i(-8,0),human,"Home",true)
	destination = grid.found_city(Vector2i(8,0),enemy,"Enemy",true)
	for coord in grid.tiles: human.explored_tiles[coord] = true

func after_each():
	V2AITacticalAI.clear_views()
	SelectionManager.reset()
	GameManager.players = original.players
	GameManager.human_player = original.human
	GameManager.rival_players = original.rivals
	GameManager.hex_grid = original.grid
	GameManager.state = original.state
	TurnManager.turn_number = original.turn
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	human.release_relations()
	enemy.release_relations()
	grid.queue_free()

func spawn(kind: String, coord: Vector2i = Vector2i.ZERO, owner: PlayerData = null) -> Unit:
	var unit := grid.spawn_unit(coord,UnitDatabase.create_unit(kind),human if owner == null else owner)
	unit.manifestation_ready_turn = TurnManager.turn_number
	return unit

func learn(school: String, tier: int = 9):
	for level in range(2,tier+1):
		assert_true(human.v2_research.complete_research("v2_magic_%s_%d" % [school,level]))

func next_action(unit: Unit):
	TurnManager.turn_number += 1
	unit.movement_left = unit.unit_data.movement_points
	V2ManifestationOrders.act(unit,grid,grid.compute_visible_tiles(human))

func test_four_orders_validate_allegiance_and_identity():
	var unit := spawn("v2_manifestation_seraph")
	var ally := spawn("v2_unit_guardian",Vector2i(1,0))
	var hostile := spawn("v2_unit_guardian",Vector2i(2,0),enemy)
	assert_true(V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid))
	assert_true(V2ManifestationOrders.assign(unit,"protect_city",home.coord,grid))
	assert_true(V2ManifestationOrders.assign(unit,"protect_unit",ally.coord,grid))
	assert_eq(unit.manifestation_order.serial,ally.serial_id)
	assert_true(V2ManifestationOrders.assign(unit,"attack_unit",hostile.coord,grid))
	assert_false(V2ManifestationOrders.assign(unit,"protect_unit",hostile.coord,grid))
	assert_false(V2ManifestationOrders.assign(unit,"attack_unit",ally.coord,grid))
	assert_false(V2ManifestationOrders.assign(unit,"protect_unit",unit.coord,grid))
	grid.visibility[hostile.coord] = HexGrid.Visibility.EXPLORED
	assert_false(V2ManifestationOrders.assign(unit,"attack_unit",hostile.coord,grid))

func test_all_six_march_and_damage_a_city_without_research_or_mana():
	human.mana = 0
	for kind in UnitDatabase.MANIFESTATION_MODELS:
		destination.hp = destination.max_hp()
		var unit := spawn(kind)
		assert_true(V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid))
		var initial := destination.hp
		for turn in 9:
			next_action(unit)
			if destination.hp < initial: break
		assert_lt(destination.hp,initial,"%s can siege" % kind)
		assert_gt(unit.coord.x,0,"%s marched" % kind)
		grid.remove_unit(unit)
	assert_eq(human.mana,0.0)

func test_birth_waits_and_reissuing_never_gives_extra_actions():
	var unit := grid.spawn_unit(Vector2i.ZERO,UnitDatabase.create_unit("v2_manifestation_archdemon"),human)
	var target := spawn("v2_legendary_guardian_champion",Vector2i(2,0),enemy)
	assert_true(V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid))
	assert_true(V2ManifestationOrders.describe(unit).contains("Atacar unidade"))
	assert_true(V2ManifestationOrders.describe(unit).contains("próxima rodada"))
	var initial := target.hp
	V2ManifestationOrders.act(unit,grid,grid.compute_visible_tiles(human))
	assert_eq(target.hp,initial,"fresh summon is dormant")
	next_action(unit)
	assert_lt(target.hp,initial)
	var after := target.hp
	unit.movement_left = unit.unit_data.movement_points
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	V2ManifestationOrders.act(unit,grid,grid.compute_visible_tiles(human))
	assert_eq(target.hp,after,"one decision per round even if order changes")

func test_guard_follows_moving_ward_and_stays_near_it():
	var unit := spawn("v2_manifestation_veil_archon")
	var ward := spawn("v2_unit_guardian",Vector2i(1,0))
	V2ManifestationOrders.assign(unit,"protect_unit",ward.coord,grid)
	grid.teleport_unit(ward,Vector2i(5,0))
	next_action(unit)
	assert_eq(V2ManifestationOrders.target_coord(unit),ward.coord)
	assert_lte(HexMetrics.axial_distance(unit.coord,ward.coord),2)
	assert_true(unit.fortified)

func test_guard_intercepts_hostiles_without_chasing_distant_units():
	var unit := spawn("v2_manifestation_archdemon",Vector2i(-6,0))
	var threat := spawn("v2_unit_guardian",Vector2i(-4,0),enemy)
	V2ManifestationOrders.assign(unit,"protect_city",home.coord,grid)
	var initial := threat.hp
	next_action(unit)
	assert_lt(threat.hp,initial)
	grid.teleport_unit(threat,Vector2i(3,0))
	next_action(unit)
	assert_lte(HexMetrics.axial_distance(unit.coord,home.coord),4)
	assert_eq(threat.hp,initial - (15.0 - threat.unit_data.defense*.5))

func test_missing_target_uses_last_sighting_and_not_actual_position():
	var unit := spawn("v2_manifestation_seraph")
	var target := spawn("v2_unit_guardian",Vector2i(3,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	var old := target.coord
	grid.teleport_unit(target,Vector2i(10,-8))
	grid.visibility[target.coord] = HexGrid.Visibility.UNSEEN
	next_action(unit)
	assert_eq(V2ManifestationOrders.target_coord(unit),old)
	assert_ne(V2ManifestationOrders.target_coord(unit),target.coord)
	for turn in 3: next_action(unit)
	assert_eq(unit.manifestation_order.mode,"protect_city","lost target releases order")

func test_peace_cancels_siege_and_capture_changes_to_protection():
	var unit := spawn("v2_manifestation_seraph")
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	# Same diplomacy mutation used by the peace resolver, without negotiation prerequisites.
	Diplomacy.make_peace(human,enemy)
	next_action(unit)
	assert_eq(unit.manifestation_order.mode,"protect_city")
	human.truces.clear()
	enemy.truces.clear()
	Diplomacy.declare_war(human,enemy)
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	enemy.cities.erase(destination)
	destination.owner_player = human
	human.cities.append(destination)
	next_action(unit)
	assert_eq(unit.manifestation_order.mode,"protect_city")
	assert_eq(V2ManifestationOrders.target_coord(unit),destination.coord)

func test_dead_ward_and_same_tile_replacement_are_not_same_target():
	var unit := spawn("v2_manifestation_seraph")
	var ward := spawn("v2_unit_guardian",Vector2i(2,0))
	V2ManifestationOrders.assign(unit,"protect_unit",ward.coord,grid)
	grid.remove_unit(ward)
	spawn("v2_unit_guardian",Vector2i(2,0))
	next_action(unit)
	assert_eq(unit.manifestation_order.mode,"protect_city")
	assert_eq(V2ManifestationOrders.target_coord(unit),home.coord)

func test_free_casting_is_exclusive_to_entities_and_does_not_cover_hosts():
	learn("sacred")
	var unit := spawn("v2_manifestation_seraph")
	var ally := spawn("v2_unit_guardian",Vector2i(1,0))
	ally.hp = 1.0
	human.mana = 0.0
	V2ManifestationOrders.assign(unit,"protect_unit",ally.coord,grid)
	next_action(unit)
	assert_gt(ally.hp,1.0)
	assert_eq(human.mana,0.0)
	var mortal := spawn("v2_unit_sacred_cleric",Vector2i(-1,0))
	assert_false(V2MagicRuntime.can_cast(mortal,"v2_spell_restoring_light",grid))
	learn("necromancy")
	var lich := spawn("v2_manifestation_lich_sovereign",Vector2i(0,2))
	assert_eq(V2ManifestationBalance.mana_cost(lich,V2SpellDatabase.get_spell("v2_spell_raise_dead")),10.0)
	assert_false(V2MagicRuntime.can_cast(lich,"v2_spell_raise_dead",grid))

func test_advanced_spells_keep_health_cost_and_cooldown():
	learn("infernal")
	var unit := spawn("v2_manifestation_archdemon")
	var target := spawn("v2_legendary_guardian_champion",Vector2i(3,0),enemy)
	human.mana = 0.0
	var initial := unit.hp
	assert_true(V2MagicRuntime.cast(unit,"v2_spell_damnation",target.coord,grid))
	assert_almost_eq(initial-unit.hp,unit.unit_data.max_hp*.35,.001)
	assert_gt(V2MagicRuntime.cooldown_remaining(unit,"v2_spell_damnation"),0)
	assert_eq(human.mana,0.0)

func test_selection_only_offers_four_strategic_commands_and_read_only_spells():
	learn("sacred")
	var unit := spawn("v2_manifestation_seraph")
	SelectionManager._select_unit(unit)
	assert_true(SelectionManager.reachable.is_empty())
	assert_true(SelectionManager.attackable.is_empty())
	var commands := UnitPresenter.commands_for(unit,grid)
	assert_eq(commands.size(),4)
	for command in commands: assert_eq(command.action_kind,"manifestation_order")
	SelectionManager.start_v2_spell_targeting(unit,"v2_spell_restoring_light")
	assert_eq(SelectionManager.v2_spell_targeting_id,"")
	SelectionManager.start_manifestation_targeting("protect_city")
	assert_eq(SelectionManager.manifestation_targeting_mode,"protect_city")
	assert_true(home.coord in SelectionManager.manifestation_target_coords)
	assert_true(SelectionManager.cancel_active_targeting())
	assert_eq(SelectionManager.selected_unit,unit)
	SelectionManager.start_manifestation_targeting("attack_city")
	SelectionManager._handle_manifestation_click(destination.coord)
	assert_eq(unit.manifestation_order.mode,"attack_city")
	assert_eq(SelectionManager.selected_unit,unit)
	var view := UnitPresenter.spell_view(unit,V2SpellDatabase.get_spell("v2_spell_miracle"),grid)
	assert_eq(view.state,UnitAbilityViewData.State.BLOCKED)
	assert_eq(view.cost_text,"0 Mana")
	var elemental := spawn("v2_manifestation_elemental_primordial",Vector2i(0,2))
	view = UnitPresenter.spell_view(elemental,V2SpellDatabase.get_spell("v2_spell_elemental_cataclysm"),grid)
	assert_eq(view.cost_text,"0 Mana · 19 Vida")
	assert_eq(view.blocked_reason,"Automática · 0 Mana · 19 Vida")

func test_save_fields_round_trip_and_legacy_hp_preserves_fraction():
	var unit := spawn("v2_manifestation_seraph")
	var ward := spawn("v2_unit_guardian",Vector2i(2,0))
	V2ManifestationOrders.assign(unit,"protect_unit",ward.coord,grid)
	unit.hp = 25.0
	unit.manifestation_acted_turn = 39
	var data := SaveManager._serialize_player(human,false)
	var saved: Dictionary = data.units[0]
	assert_eq(saved.manifestation_order.serial,ward.serial_id)
	assert_eq(saved.manifestation_acted_turn,39)
	assert_eq(saved.manifestation_profile_version,1)
	assert_eq(V2ManifestationBalance.restored_hp(unit,19.0,0),25.0)
	assert_eq(V2ManifestationBalance.restored_hp(unit,25.0,1),25.0)
	for owned in human.units.duplicate(): grid.remove_unit(owned)
	# Cities are already present, so deserialize only the units in this fixture.
	data.cities = []
	SaveManager._deserialize_player(data,human,grid)
	var restored := grid.get_unit_at(Vector2i.ZERO)
	assert_eq(restored.hp,25.0)
	assert_eq(restored.manifestation_order,saved.manifestation_order)
	assert_eq(restored.manifestation_acted_turn,39)
	assert_eq(restored.manifestation_ready_turn,40)

func test_elemental_automation_rejects_friendly_fire_and_peaceful_bystanders():
	learn("elementalism")
	var unit := spawn("v2_manifestation_elemental_primordial")
	var target := spawn("v2_unit_guardian",Vector2i(4,0),enemy)
	spawn("v2_unit_guardian",Vector2i(5,-1),enemy)
	var ally := spawn("v2_unit_guardian",Vector2i(4,-1))
	var visible := grid.compute_visible_tiles(human)
	var spell := V2SpellDatabase.get_spell("v2_spell_elemental_cataclysm")
	assert_lt(V2ManifestationOrders._spell_score(unit,spell,target.coord,target.coord,grid,visible),0.0)
	grid.remove_unit(ally)
	assert_gt(V2ManifestationOrders._spell_score(unit,spell,target.coord,target.coord,grid,visible),-1.0)

func test_autonomous_sacrifice_does_not_reduce_self_below_a_quarter():
	learn("infernal")
	var unit := spawn("v2_manifestation_archdemon")
	var target := spawn("v2_legendary_guardian_champion",Vector2i(3,0),enemy)
	unit.hp = 26.0
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	next_action(unit)
	assert_eq(unit.hp,26.0,"uses ordinary spell instead of self-endangering sacrifice")
	assert_false(unit.magic_cooldowns.has("v2_spell_damnation"))
	assert_lt(target.hp,target.unit_data.max_hp)

func test_autonomy_can_attack_a_hostile_revealed_by_its_advance():
	var unit := spawn("v2_manifestation_archdemon")
	unit.unit_data.vision_range = 2
	var target := spawn("v2_unit_guardian",Vector2i(4,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	grid.visibility.clear()
	grid.visibility[target.coord] = HexGrid.Visibility.UNSEEN
	var initial := target.hp
	next_action(unit)
	assert_lt(target.hp,initial)
	assert_eq(grid.visibility[target.coord],HexGrid.Visibility.VISIBLE)

func test_targeting_banner_and_cursor_receive_order_mode_and_cancel():
	var unit := spawn("v2_manifestation_seraph")
	SelectionManager._select_unit(unit)
	watch_signals(EventBus)
	SelectionManager.start_manifestation_targeting("protect_city")
	assert_signal_emitted(EventBus,"targeting_changed")
	var state := TargetingPresenter.current()
	assert_eq(state.kind,"manifestation_order")
	assert_eq(state.title,"Proteger cidade")
	assert_true(SelectionManager.is_targeting())
	assert_true(SelectionManager.cancel_active_targeting())
	assert_true(TargetingPresenter.current().is_empty())
	assert_false(SelectionManager.is_targeting())

func test_rival_uses_strategic_order_and_same_once_per_round_execution():
	var unit := spawn("v2_manifestation_nature_avatar",Vector2i(4,0),enemy)
	var target := spawn("v2_legendary_guardian_champion",Vector2i(3,0))
	var visible := RivalAI.begin_turn(enemy,grid,human)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	var initial := target.hp
	RivalAI.act_for_unit(unit,grid,enemy,human,visible)
	assert_lt(target.hp,initial)
	var after := target.hp
	unit.movement_left = unit.unit_data.movement_points
	RivalAI.act_for_unit(unit,grid,enemy,human,visible)
	assert_eq(target.hp,after)

func test_human_batch_contains_only_human_entities_and_executes_them():
	var unit := spawn("v2_manifestation_archdemon")
	spawn("v2_manifestation_seraph",Vector2i(10,0),enemy)
	var target := spawn("v2_unit_guardian",Vector2i(2,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	var items := GameManager._build_manifestation_turn_items()
	assert_eq(items.size(),1)
	assert_eq(items[0].unit,unit)
	var initial := target.hp
	GameManager._ai_turn_queue = items
	GameManager.is_turn_processing = true
	GameManager._process(GameManager.AI_BATCH_INTERVAL+0.01)
	assert_lt(target.hp,initial)
	assert_true(GameManager._ai_turn_queue.is_empty())
	assert_false(GameManager.is_turn_processing)

func test_ground_siege_detours_around_a_mountain_barrier():
	var unit := spawn("v2_manifestation_nature_avatar")
	for r in range(-6,7): grid.tiles[Vector2i(1,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	for turn in 20:
		next_action(unit)
		if unit.coord.x > 1: break
	assert_gt(unit.coord.x,1,"goes around an obstruction even when greedy distance cannot improve")

func test_ground_siege_can_leave_a_pocket_even_when_the_route_initially_moves_away():
	var unit := spawn("v2_manifestation_nature_avatar")
	for r in range(-9,10): grid.tiles[Vector2i(2,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	for q in range(-3,3):
		for r in [-9,9]: grid.tiles[Vector2i(q,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	for turn in 20:
		# Renewing the same objective (as rival protection may do) must preserve a detour.
		V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
		next_action(unit)
		if unit.coord.x > 2: break
	assert_gt(unit.coord.x,2,"does not undo a necessary detour on the next round")

func test_saved_legacy_movement_is_removed_from_bound_entities():
	var unit := spawn("v2_manifestation_seraph")
	var data := SaveManager._serialize_player(human,false)
	data.units[0].exploring = true
	data.units[0].move_order_target = [3,0]
	data.units[0].erase("manifestation_profile_version")
	data.units[0].erase("manifestation_order")
	data.units[0].hp = 19.0
	grid.remove_unit(unit)
	data.cities = []
	SaveManager._deserialize_player(data,human,grid)
	var restored := grid.get_unit_at(Vector2i.ZERO)
	assert_false(restored.exploring)
	assert_eq(restored.move_order_target,Unit.NO_MOVE_ORDER)
	assert_eq(restored.hp,25.0)

func test_revealed_city_is_not_attacked_beyond_range_or_through_its_garrison():
	var unit := spawn("v2_manifestation_archdemon")
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	var full := {}
	for coord in grid.tiles: full[coord] = true
	var initial := destination.hp
	V2ManifestationOrders.act(unit,grid,full)
	assert_eq(destination.hp,initial,"knowing a city does not give infinite attack range")
	grid.teleport_unit(unit,Vector2i(6,0))
	var guard := spawn("v2_unit_guardian",destination.coord,enemy)
	var guard_hp := guard.hp
	next_action(unit)
	assert_eq(destination.hp,initial,"first defeat the unit garrisoning the city")
	assert_lt(guard.hp,guard_hp)

func test_manual_movement_exploration_fortify_and_portals_cannot_bypass_orders():
	var unit := spawn("v2_manifestation_veil_archon")
	assert_true(V2PortalSystem.create_or_replace_pair(human,"arcanism",unit.coord,Vector2i(4,0),grid))
	SelectionManager._select_unit(unit)
	SelectionManager.wake_selected_for_move()
	assert_false(SelectionManager.move_mode)
	SelectionManager.toggle_explore_selected()
	assert_false(unit.exploring)
	SelectionManager.fortify_selected()
	assert_false(unit.fortified)
	SelectionManager.traverse_selected_portal()
	assert_eq(unit.coord,Vector2i.ZERO)
	assert_eq(unit.movement_left,unit.unit_data.movement_points)

func test_actual_capture_immediately_updates_the_order_to_protect():
	var unit := spawn("v2_manifestation_archdemon",Vector2i(6,0))
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	destination.hp = 1.0
	var visible := {}
	for coord in grid.tiles: visible[coord] = true
	V2ManifestationOrders.act(unit,grid,visible)
	assert_eq(destination.owner_player,human)
	assert_eq(unit.manifestation_order.mode,"protect_city")
	assert_eq(V2ManifestationOrders.target_coord(unit),destination.coord)
	assert_eq(unit.movement_left,0.0)

func test_explored_ground_does_not_reveal_a_city_built_under_fog():
	var unit := spawn("v2_manifestation_seraph")
	grid.visibility[destination.coord] = HexGrid.Visibility.EXPLORED
	human.known_enemy_cities.erase(destination.coord)
	assert_false(V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid))
	human.remember_enemy_city(destination)
	assert_true(V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid))

func test_escort_closes_the_gap_before_healing_a_bystanders_scratch():
	learn("sacred")
	var unit := spawn("v2_manifestation_seraph")
	var bystander := spawn("v2_unit_guardian",Vector2i(-1,0))
	bystander.hp -= 1.0
	var ward := spawn("v2_unit_guardian",Vector2i(6,0))
	V2ManifestationOrders.assign(unit,"protect_unit",ward.coord,grid)
	next_action(unit)
	assert_gt(unit.coord.x,0,"following the assigned ward takes priority over incidental support")
	assert_lte(HexMetrics.axial_distance(unit.coord,ward.coord),3)

func test_unit_assault_ends_immediately_when_observed_target_becomes_peaceful():
	var unit := spawn("v2_manifestation_archdemon")
	var target := spawn("v2_unit_guardian",Vector2i(3,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	Diplomacy.make_peace(human,enemy)
	next_action(unit)
	assert_eq(unit.manifestation_order.mode,"protect_city")
	assert_eq(target.hp,target.unit_data.max_hp)

func test_archon_dispels_enemy_beneficial_status_and_remote_ally_silence():
	learn("arcanism")
	var unit := spawn("v2_manifestation_veil_archon")
	var target := spawn("v2_unit_guardian",Vector2i(3,0),enemy)
	target.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	next_action(unit)
	assert_false(target.magic_status.has("v2_spell_sacred_aegis"))
	grid.remove_unit(target)
	var ally := spawn("v2_unit_sacred_cleric",Vector2i(0,3))
	ally.magic_status["v2_spell_silence"] = V2OwnerTurnEffect.expiry_for_now()
	V2ManifestationOrders.assign(unit,"protect_city",home.coord,grid)
	var dispel := V2SpellDatabase.get_spell("v2_spell_dispel")
	var visible := grid.compute_visible_tiles(human)
	assert_true(ally.coord in V2ManifestationOrders._spell_coords(unit,dispel,home.coord,grid,visible))
	assert_gt(V2ManifestationOrders._spell_score(unit,dispel,ally.coord,home.coord,grid,visible),0.0)

func test_gale_values_ranged_threats_and_does_not_fear_friendly_melee():
	var unit := spawn("v2_manifestation_elemental_primordial")
	var target := spawn("v2_unit_elite_marksman",Vector2i(4,0),enemy)
	spawn("v2_unit_guardian",Vector2i(4,-1))
	var gale := V2SpellDatabase.get_spell("v2_spell_gale")
	var visible := grid.compute_visible_tiles(human)
	assert_gt(V2ManifestationOrders._spell_score(unit,gale,target.coord,target.coord,grid,visible),0.0)
	target.unit_data.attack_range = 1
	assert_lte(V2ManifestationOrders._spell_score(unit,gale,target.coord,target.coord,grid,visible),0.0)

func test_manifestation_leaves_lethal_storm_before_attacking():
	var unit := spawn("v2_manifestation_archdemon")
	var target := spawn("v2_unit_guardian",Vector2i(2,0),enemy)
	unit.hp = 5.0
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	assert_true(V2EnvironmentalZoneSystem.apply(grid,unit.coord,"v2_zone_lightning_storm",1,"elementalism"))
	next_action(unit)
	assert_ne(unit.coord,Vector2i.ZERO)
	assert_eq(V2ManifestationOrders._tile_danger(unit,unit.coord,grid),0.0)
	V2EnvironmentalZoneSystem.process_global_round(grid,true)
	assert_gt(unit.hp,0.0)

func test_march_chooses_safe_firing_tile_instead_of_lightning():
	var unit := spawn("v2_manifestation_archdemon")
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	for coord in [Vector2i(3,0),Vector2i(3,-1),Vector2i(3,1)]:
		V2EnvironmentalZoneSystem.apply(grid,coord,"v2_zone_lightning_storm",1,"elementalism")
	next_action(unit)
	assert_gt(unit.coord.x,0)
	assert_eq(V2ManifestationOrders._tile_danger(unit,unit.coord,grid),0.0)

func test_archon_dispels_storm_harming_ward_but_preserves_friendly_portals():
	var unit := spawn("v2_manifestation_veil_archon")
	var ward := spawn("v2_unit_guardian",Vector2i(2,0))
	V2ManifestationOrders.assign(unit,"protect_unit",ward.coord,grid)
	var spell := V2SpellDatabase.get_spell("v2_spell_dispel")
	var visible := grid.compute_visible_tiles(human)
	V2EnvironmentalZoneSystem.apply(grid,ward.coord,"v2_zone_lightning_storm",1,"elementalism")
	assert_gt(V2ManifestationOrders._spell_score(unit,spell,ward.coord,ward.coord,grid,visible),0.0)
	assert_true(V2PortalSystem.create_or_replace_pair(human,"arcanism",ward.coord,Vector2i(5,0),grid))
	assert_lte(V2ManifestationOrders._spell_score(unit,spell,ward.coord,ward.coord,grid,visible),0.0,"dispel closes portals on its tile as well")

func test_seraph_does_not_stop_a_siege_for_incidental_healing():
	learn("sacred")
	var unit := spawn("v2_manifestation_seraph")
	var ally := spawn("v2_unit_guardian",Vector2i(-1,0))
	ally.hp -= 1.0
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	next_action(unit)
	assert_gt(unit.coord.x,0)

func test_siege_can_finish_a_dangerous_enemy_before_chipping_city_walls():
	var unit := spawn("v2_manifestation_archdemon",Vector2i(6,0))
	var target := spawn("v2_legendary_blade_hero",Vector2i(6,1),enemy)
	target.hp = 1.0
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	var initial := destination.hp
	next_action(unit)
	assert_lte(target.hp,0.0)
	assert_eq(destination.hp,initial)

func test_ground_ranged_siege_detours_to_firing_ring_when_adjacent_tiles_are_blocked():
	var unit := spawn("v2_manifestation_lich_sovereign")
	for r in range(-6,7): grid.tiles[Vector2i(1,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	for coord in grid.get_neighbors(destination.coord): grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	V2ManifestationOrders.assign(unit,"attack_city",destination.coord,grid)
	var initial := destination.hp
	for turn in 25:
		next_action(unit)
		if destination.hp < initial: break
	assert_lt(destination.hp,initial,"a reachable firing ring is enough, even without any adjacent landing")

func test_elemental_assault_closes_to_attack_instead_of_alternating_harmless_zones():
	learn("elementalism",5)
	var unit := spawn("v2_manifestation_elemental_primordial")
	var target := spawn("v2_unit_elite_marksman",Vector2i(4,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	next_action(unit)
	assert_lt(HexMetrics.axial_distance(unit.coord,target.coord),4)
	assert_lt(target.hp,target.unit_data.max_hp)

func test_archon_silences_a_caster_before_an_incidental_basic_attack():
	learn("arcanism")
	var unit := spawn("v2_manifestation_veil_archon")
	var target := spawn("v2_unit_infernal_warlock",Vector2i(3,0),enemy)
	V2ManifestationOrders.assign(unit,"attack_unit",target.coord,grid)
	next_action(unit)
	assert_true(V2MagicRuntime.is_spellcasting_silenced(target))
