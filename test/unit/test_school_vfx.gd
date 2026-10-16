extends GutTest

func test_rebuilding_lightning_keeps_the_impact_fade() -> void:
	var arc: Node3D = load("res://scripts/vfx/LightningArcFX.gd").new()
	add_child_autofree(arc)
	arc.setup(3.1,Color("b9d7ff"))
	arc.set_process(false)
	var natural = load("res://scripts/vfx/NaturalVFX.gd")
	natural.opacity(arc,.25)
	arc._rebuild()
	assert_almost_eq(arc.geometry.get_child(0).material_override.albedo_color.a,.25,.001)
	natural.opacity(arc,.10)
	assert_almost_eq(arc.geometry.get_child(0).material_override.albedo_color.a,.10,.001,"Rebuilt geometry retains its original alpha as the base")

const KINDS := {"infernal":"v2_unit_infernal_warlock","necromancy":"v2_unit_necromancer","druidism":"v2_unit_druid","arcanism":"v2_unit_arcanist","elementalism":"v2_unit_elementalist"}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var original := {}

func before_each() -> void:
	for key in ["players","rival_players","human_player","hex_grid"]: original[key] = GameManager.get(key)
	original.turn = TurnManager.turn_number
	original.motion = Settings.reduced_motion
	original.lights = Settings.creature_lighting_enabled
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [human,rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	TurnManager.turn_number = 20
	for owner in [human,rival]:
		owner.mana = 600
		for school in KINDS:
			for tier in range(2,10): owner.v2_research.complete_research("v2_magic_%s_%d" % [school,tier])
	Diplomacy.declare_war(human,rival,"VFX",true)
	grid = HexGrid.new()
	add_child_autofree(grid)
	GameManager.hex_grid = grid
	for q in range(-7,8):
		for r in range(-7,8): grid.tiles[Vector2i(q,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

func after_each() -> void:
	SelectionManager.reset()
	human.release_relations()
	rival.release_relations()
	for key in ["players","rival_players","human_player","hex_grid"]: GameManager.set(key,original[key])
	TurnManager.turn_number = original.turn
	Settings.reduced_motion = original.motion
	Settings.creature_lighting_enabled = original.lights

func _unit(kind: String, coord: Vector2i, owner: PlayerData = null) -> Unit:
	var unit := grid.spawn_unit(coord,UnitDatabase.create_unit(kind),human if owner==null else owner)
	unit.visible = true
	return unit

func _effects() -> Array[Node]:
	return get_tree().get_nodes_in_group(SpellVFX.GROUP).filter(func(node):return node.get_parent()==grid and not node.is_queued_for_deletion())

func _effect() -> Node3D:
	assert_eq(_effects().size(),1,"A real successful cast has one presentation")
	var effect: Node3D = _effects()[0]
	effect.set_process(false)
	return effect

func _impact(effect: Node3D) -> void:
	effect.age = effect.arrival+.25
	effect._update_visuals()

func test_all_infernal_spells_resolve_and_present_their_damage() -> void:
	var caster := _unit(KINDS.infernal,Vector2i.ZERO)
	var ally := _unit("warrior",Vector2i(1,1))
	for spell in V2SpellDatabase.for_school("infernal"):
		var target := _unit("warrior",Vector2i(1,0),rival)
		caster.movement_left = caster.unit_data.movement_points
		caster.magic_cooldowns.clear()
		var mana := human.mana
		var hp := target.hp
		var expected_damage := V2MagicRuntime.predict_damage(caster,target,spell)
		assert_true(V2MagicRuntime.cast(caster,spell.id,target.coord,grid),spell.id)
		assert_eq(human.mana,mana-spell.mana_cost)
		assert_eq(target.hp,hp-expected_damage)
		var effect := _effect()
		assert_eq(effect.outcomes.size(),1,"The allied neighbor never receives a fire reaction")
		_impact(effect)
		assert_true(effect.events.any(func(event):return event.node.visible))
		assert_eq(ally.hp,ally.unit_data.max_hp)
		effect._process(effect.duration)
		grid.remove_unit(target)
		await wait_frames(2)
		assert_true(_effects().is_empty())

func test_infernal_lethal_hit_still_leaves_an_impact_at_its_tile() -> void:
	var caster := _unit(KINDS.infernal,Vector2i.ZERO)
	var target := _unit("warrior",Vector2i(1,0),rival)
	target.hp = 2
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_devouring_fire",target.coord,grid))
	var effect := _effect()
	await wait_frames(2)
	assert_null(grid.get_unit_at(Vector2i(1,0)))
	_impact(effect)
	assert_true(effect.events.any(func(event):return event.coord==Vector2i(1,0) and event.node.visible))
	effect._process(effect.duration)
	await wait_frames(2)
	assert_true(_effects().is_empty())

func test_necromancy_summons_and_repairs_real_undead() -> void:
	var caster := _unit(KINDS.necromancy,Vector2i.ZERO)
	for spell in V2SpellDatabase.for_school("necromancy"):
		var coord := Vector2i(1,0)
		caster.movement_left = caster.unit_data.movement_points
		caster.magic_cooldowns.clear()
		var target: Unit
		if not spell.is_summon():
			target = _unit("v2_unit_skeleton_host",coord)
			if spell.is_heal(): target.hp -= 3
		var mana := human.mana
		assert_true(V2MagicRuntime.cast(caster,spell.id,coord,grid))
		assert_eq(human.mana,mana-spell.mana_cost)
		target = grid.get_unit_at(coord)
		assert_not_null(target)
		var effect := _effect()
		_impact(effect)
		assert_false(effect.bodies.is_empty(),"Spawn, repair or empowerment reacts on the actual undead")
		if spell.is_heal(): assert_eq(float(effect.bodies[0].heal),3.0,"The reaction reports the clamped real repair")
		if spell.is_summon():
			assert_eq(target.movement_left,0.0)
			assert_eq(target.unit_data.visual_kind,spell.summon_unit_id)
		if spell.applies_status(): assert_not_null(target.get_node_or_null("SchoolStatus_"+spell.id))
		effect._process(effect.duration)
		grid.remove_unit(target)
		await wait_process_frames(2)

func test_macabre_command_marker_is_idempotent_and_removed_with_status() -> void:
	var caster := _unit(KINDS.necromancy,Vector2i.ZERO)
	var host := _unit("v2_unit_skeleton_host",Vector2i(1,0))
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_macabre_command",host.coord,grid))
	var marker := host.get_node_or_null("SchoolStatus_v2_spell_macabre_command")
	assert_not_null(marker)
	host.refresh_technique_marker(false)
	assert_same(host.get_node("SchoolStatus_v2_spell_macabre_command"),marker)
	TurnManager.turn_number += 1
	marker._process(.1)
	assert_false(marker.is_queued_for_deletion())
	V2MagicRuntime.expire_finished(human)
	assert_null(host.get_node_or_null("SchoolStatus_v2_spell_macabre_command"))

func test_druidism_uses_only_tiles_actually_modified_and_finishes_growth() -> void:
	var caster := _unit(KINDS.druidism,Vector2i.ZERO)
	var center := Vector2i(2,0)
	var excluded := center+Vector2i(1,0)
	V2TerrainRuntime.apply(grid,excluded,"v2_terrain_raised_ground")
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_awaken_forest",center,grid))
	var effect := _effect()
	assert_false(effect.affected_cells().has(excluded),"An unchanged tile is not painted as new forest")
	assert_eq(effect.affected_cells().size(),6)
	var marker: Node3D = grid._terrain_modification_markers[center]
	if not Settings.reduced_motion: assert_lt(marker.scale.y,1.0,"The new vegetation visibly grows")
	_impact(effect)
	effect._process(effect.duration)
	await wait_process_frames(2)
	assert_eq(marker.scale.y,1.0,"Transient growth never leaves the real terrain shrunken")
	assert_eq(V2TerrainRuntime.modification_id_at(grid,excluded),"v2_terrain_raised_ground")
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.clear()
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_restore_terrain",center,grid))
	var restore := _effect()
	_impact(restore)
	assert_false(V2TerrainRuntime.has_modification(grid,center))
	assert_true(restore.events.any(func(event):return event.kind=="restoration"))

func test_arcane_step_keeps_the_departure_after_the_actual_teleport() -> void:
	var caster := _unit(KINDS.arcanism,Vector2i.ZERO)
	var destination := Vector2i(3,0)
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_arcane_step",destination,grid))
	assert_eq(caster.coord,destination)
	var effect := _effect()
	assert_eq(effect.origin,Vector2i.ZERO)
	assert_eq(effect.center,destination)
	_impact(effect)
	assert_true(effect.events.any(func(event):return event.coord==Vector2i.ZERO and event.node.visible))
	assert_eq(caster.position,grid.world_surface_for_coord(destination),"The effect never moves the real unit back to its old tile")

func test_silence_and_dispel_refresh_their_public_visual_state() -> void:
	var caster := _unit(KINDS.arcanism,Vector2i.ZERO)
	var enemy := _unit(KINDS.infernal,Vector2i(1,0),rival)
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_silence",enemy.coord,grid))
	assert_not_null(enemy.get_node_or_null("SchoolStatus_v2_spell_silence"))
	assert_true(V2MagicRuntime.is_spellcasting_silenced(enemy))
	var effect := _effect()
	effect._process(effect.duration)
	await wait_process_frames(2)
	# A harmful spell on one's own caster is dispellable by a second arcanist.
	var dispeller := _unit(KINDS.arcanism,Vector2i(2,0),rival)
	assert_true(V2MagicRuntime.cast(dispeller,"v2_spell_dispel",enemy.coord,grid))
	assert_null(enemy.get_node_or_null("SchoolStatus_v2_spell_silence"))
	assert_false(V2MagicRuntime.is_spellcasting_silenced(enemy))
	assert_false(_effect().bodies.is_empty(),"Dispel reacts on the body whose status was removed")

func test_portals_rebuild_from_save_and_traversal_has_bounded_feedback() -> void:
	var caster := _unit(KINDS.arcanism,Vector2i.ZERO)
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_veil_portal",Vector2i(3,0),grid))
	var effect := _effect()
	var saved := V2PortalSystem.to_save_array(grid)
	assert_eq(V2PortalSystem.load_save_array(saved,grid),1)
	assert_not_null(grid._v2_portal_markers[Vector2i.ZERO].get_node_or_null("PortalVFX"))
	effect._process(effect.duration)
	await wait_process_frames(2)
	caster.movement_left = 2
	assert_true(V2PortalSystem.traverse(caster,grid))
	assert_eq(caster.coord,Vector2i(3,0))
	assert_eq(caster.movement_left,0.0)
	assert_eq(_effects().size(),1)
	var transit: Node3D = _effects()[0]
	transit.set_process(false)
	transit._process(1.2)
	await wait_process_frames(2)
	assert_true(_effects().is_empty())
	assert_true(V2PortalSystem.close_pair_at(caster.coord,grid))
	assert_true(grid._v2_portal_markers.is_empty())

func test_elemental_damage_visuals_happen_on_actual_rounds_and_survive_save() -> void:
	var caster := _unit(KINDS.elementalism,Vector2i.ZERO)
	var target := _unit("warrior",Vector2i(2,0),rival)
	var hp := target.hp
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_lightning_storm",target.coord,grid))
	assert_eq(target.hp,hp,"Creating the field is not an immediate damage hit")
	var effect := _effect()
	assert_eq(effect.affected_cells().size(),7)
	effect._process(effect.duration)
	await wait_process_frames(2)
	var saved := V2EnvironmentalZoneSystem.to_save_array(grid)
	assert_eq(V2EnvironmentalZoneSystem.load_save_array(saved,grid),7)
	assert_not_null(grid._v2_environmental_zone_markers[target.coord].get_node_or_null("ZoneVFX"))
	var result := V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_eq(result.damaged_units,1)
	assert_eq(target.hp,hp-6)
	assert_eq(_effects().size(),1,"One real environmental hit produces one bounded reaction")
	assert_eq(String(_effects()[0].name),"EnvironmentalImpact")
	for impact in _effects():
		impact.set_process(false)
		impact._process(1.1)
	await wait_process_frames(2)
	assert_false(grid.v2_environmental_zones.is_empty())
	V2EnvironmentalZoneSystem.process_global_round(grid)
	assert_true(grid.v2_environmental_zones.is_empty())
	assert_true(grid._v2_environmental_zone_markers.is_empty(),"The atmosphere expires with its actual field")

func test_cataclysm_respects_existing_zones_and_reduced_motion() -> void:
	Settings.reduced_motion = true
	Settings.creature_lighting_enabled = false
	var caster := _unit(KINDS.elementalism,Vector2i.ZERO)
	var center := Vector2i(3,0)
	var occupied := center+Vector2i(1,0)
	V2EnvironmentalZoneSystem.apply(grid,occupied,"v2_zone_gale",0,"elementalism")
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_elemental_cataclysm",center,grid))
	var effect := _effect()
	assert_eq(effect.affected_cells().size(),18)
	assert_false(effect.affected_cells().has(occupied))
	assert_false(effect.light.visible)
	var field: Node3D = grid._v2_environmental_zone_markers[center].get_node("ZoneVFX")
	assert_lte(field.cloud.multimesh.instance_count,7,"Cloud lobes share one draw call")
	assert_lte(field.rain.amount,18,"Reduced motion limits rain particles")
	var transform: Transform3D = field.cloud.multimesh.get_instance_transform(0)
	field._process(1.0)
	assert_eq(field.cloud.multimesh.get_instance_transform(0),transform,"Reduced motion keeps the cloud shape stable")
	assert_eq(String(V2EnvironmentalZoneSystem.zone_entry_at(occupied,grid).zone_id),"v2_zone_gale")

func test_storm_clouds_stay_over_the_field_when_its_occupant_changes() -> void:
	var center := Vector2i(2,0)
	assert_true(V2EnvironmentalZoneSystem.apply(grid,center,"v2_zone_lightning_storm",0,"elementalism"))
	var field: Node3D = grid._v2_environmental_zone_markers[center].get_node("ZoneVFX")
	field.set_process(false)
	field._process(1.1)
	var cloud_position: Vector3 = field.cloud.position
	var rain_position: Vector3 = field.rain.position
	var lifetime: float = field.rain.lifetime
	var target := _unit("v2_manifestation_elemental_primordial",center)
	field._process(.3)
	assert_eq(field.cloud.position,cloud_position,"Clouds belong to the field, not a head attachment")
	assert_eq(field.rain.position,rain_position)
	assert_eq(field.rain.lifetime,lifetime)
	grid.remove_unit(target)
	field._process(.3)
	assert_eq(field.cloud.position,cloud_position,"The weather does not jump down when the unit leaves")
	assert_lte(field.cloud.multimesh.instance_count,5,"A storm tile uses one bounded cloud batch")
	assert_lte(field.rain.amount,24)

func test_school_effects_do_not_reveal_an_enemy_caster_or_hidden_ground() -> void:
	var caster := _unit(KINDS.infernal,Vector2i.ZERO,rival)
	var target := _unit("warrior",Vector2i(2,0))
	grid.visibility[target.coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[caster.coord] = HexGrid.Visibility.EXPLORED
	assert_true(V2MagicRuntime.cast(caster,"v2_spell_infernal_blast",target.coord,grid))
	var effect := _effect()
	_impact(effect)
	assert_false(effect.charge.visible)
	assert_false(effect.projectile.visible)
	for event in effect.events:
		if event.coord!=target.coord: assert_false(event.node.visible,"No effects reveal hidden neighboring tiles")

func test_every_school_and_race_has_a_real_focus_and_manifests_use_their_core() -> void:
	var art = preload("res://scripts/vfx/SacredVFXGeometry.gd")
	for race in ["human","elf","orc","dwarf"]:
		human.civ.race = race
		for school in KINDS:
			var caster := _unit(KINDS[school],Vector2i.ZERO)
			var focus: Dictionary = art.anchor(caster,true)
			assert_gte(int(focus.bone),0,race+"/"+school)
			assert_gt(focus.offset.length(),.35,"Focus follows the actual staff tip instead of the hand/chest")
			grid.remove_unit(caster)
			await wait_process_frames(2)
	for kind in ["v2_manifestation_archdemon","v2_manifestation_lich_sovereign","v2_manifestation_nature_avatar","v2_manifestation_veil_archon","v2_manifestation_elemental_primordial"]:
		var caster := _unit(kind,Vector2i.ZERO)
		var focus: Dictionary = art.anchor(caster,true)
		assert_gte(int(focus.bone),0,kind)
		var skeleton: Skeleton3D = focus.skeleton.get_ref()
		assert_eq(skeleton.get_bone_name(focus.bone),caster.unit_data.glow_bone)
		grid.remove_unit(caster)
		await wait_process_frames(2)

func test_all_spell_schools_have_a_registered_effect() -> void:
	for spell in V2SpellDatabase.all_spells(): assert_true(SpellVFX.SCHOOLS.has(spell.school_branch),spell.id)
