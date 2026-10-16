extends GutTest

## Exercise the real cast/status path. Effects must never change rules or reveal fog.
const LIGHT := "v2_spell_restoring_light"
const AEGIS := "v2_spell_sacred_aegis"
const WAVE := "v2_spell_healing_wave"
const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var original := {}

func test_focus_emits_from_existing_material_without_shared_edits_or_added_meshes() -> void:
	var caster := _unit(Vector2i.ZERO,human,true)
	var twin := _unit(Vector2i(1,0),human,true)
	var mesh: MeshInstance3D = caster._visual_root.find_children("*","MeshInstance3D",true,false)[0]
	var twin_mesh: MeshInstance3D = twin._visual_root.find_children("*","MeshInstance3D",true,false)[0]
	var source := mesh.get_active_material(0)
	var previous := mesh.get_surface_override_material(0)
	var twin_source := twin_mesh.get_active_material(0)
	var focus_script = load("res://scripts/vfx/FocusGlowFX.gd")
	var focus: Node3D = focus_script.acquire(caster,grid,101,"sacred",Art.GOLD)
	assert_same(focus_script.acquire(caster,grid,102,"sacred",Art.GOLD),focus,"Overlapping casts share one emission controller")
	assert_true(focus.find_children("*","MeshInstance3D",true,false).is_empty(),"The staff tip remains the original geometry")
	assert_ne(mesh.get_active_material(0),source,"Only the caster receives a private material override")
	assert_same(twin_mesh.get_active_material(0),twin_source,"Another instance of the model is untouched")
	assert_eq(source.next_pass,null,"Shared imported material is never modified")
	assert_not_null(mesh.get_active_material(0).next_pass)
	focus.update_lease(101,.8,true)
	assert_true(focus.light.visible,"Existing WorldGlow lights the surroundings")
	grid.world_glow.set_darkness(0)
	var day_energy: float = focus.light.light_energy
	grid.world_glow.set_darkness(1)
	assert_gt(focus.light.light_energy,day_energy,"The same darkness response as crystals")
	focus.update_lease(101,1,false)
	assert_false(focus.light.visible,"Hidden casting cannot reveal a light")
	Settings.creature_lighting_enabled = false
	focus.update_lease(102,1,true)
	assert_false(focus.light.visible,"Video lighting preference is respected")
	assert_eq(float(mesh.get_active_material(0).next_pass.get_shader_parameter("strength")),1.0,"Material emission remains available with lights disabled")
	focus.release(101)
	assert_ne(mesh.get_active_material(0),source,"A second lease keeps emission alive")
	focus.release(102)
	assert_same(mesh.get_surface_override_material(0),previous,"Final release restores the exact previous override")
	await wait_frames(2)
	assert_null(caster.get_node_or_null("SpellFocusGlow"))
	assert_null(grid.world_glow.get_light(WorldGlow.GROUP_CASTING,focus.get_instance_id()) if is_instance_valid(focus) else null)

func test_map_rain_has_no_overhead_clouds_and_does_not_control_elemental_storms() -> void:
	var unit := _unit(Vector2i.ZERO,human,true)
	var hidden := _unit(Vector2i(1,0),rival,true)
	hidden.visible = false
	var rig := Node3D.new()
	add_child_autofree(rig)
	var camera := Camera3D.new()
	camera.position = Vector3(0,15,12)
	rig.add_child(camera)
	var weather := WeatherController.new()
	add_child_autofree(weather)
	weather.set_process(false)
	weather.setup(rig,null)
	weather.start_match()
	weather.force_rain(200.0)
	weather.advance(60.0)
	assert_almost_eq(weather.rain_intensity(),1.0,.001)
	assert_true(weather.particles_of(WeatherKinds.RAIN).emitting,"Map rainfall remains enabled")
	assert_gt(weather.wetness_sent,0.9,"The ground still becomes wet")
	assert_true(weather.find_children("*","Node3D",true,false).is_empty(),"Map weather never creates unit cloud controllers")
	assert_true(grid.v2_environmental_zones.is_empty(),"Cosmetic rain does not create magical weather")
	assert_true(V2EnvironmentalZoneSystem.apply(grid,unit.coord,"v2_zone_lightning_storm",0,"elementalism"))
	var field: Node3D = grid._v2_environmental_zone_markers[unit.coord].get_node("ZoneVFX")
	assert_not_null(field.cloud,"Elemental storms retain their cloud")
	assert_not_null(field.rain,"Elemental storms retain their local rain")
	weather.stop()
	assert_false(weather.particles_of(WeatherKinds.RAIN).emitting)
	assert_true(is_instance_valid(field.cloud),"Stopping map rain does not remove spell clouds")
	field._process(.4)
	assert_gt(field.cloud.position.y,unit._marker_height,"Spell clouds stay above the affected unit")
	await AudioManager.drain_audio()

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
	human.mana = 200
	rival.mana = 200
	for owner in [human,rival]:
		for tier in range(2,10): owner.v2_research.complete_research("v2_magic_sacred_%d" % tier)
	grid = HexGrid.new()
	add_child_autofree(grid)
	GameManager.hex_grid = grid
	for q in range(-4,5):
		for r in range(-4,5): grid.tiles[Vector2i(q,r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

func after_each() -> void:
	SelectionManager.reset()
	human.release_relations()
	rival.release_relations()
	for key in ["players","rival_players","human_player","hex_grid"]: GameManager.set(key,original[key])
	TurnManager.turn_number = original.turn
	Settings.reduced_motion = original.motion
	Settings.creature_lighting_enabled = original.lights

func _unit(coord: Vector2i, owner: PlayerData, cleric: bool = false) -> Unit:
	var unit := grid.spawn_unit(coord,UnitDatabase.create_unit("v2_unit_sacred_cleric" if cleric else "warrior"),owner)
	unit.visible = true
	return unit

func _effects() -> Array[Node]:
	return get_tree().get_nodes_in_group(SpellVFX.GROUP).filter(func(node):return node.get_parent()==grid and not node.is_queued_for_deletion())

func test_cast_preserves_rules_and_cleans_body_overlay() -> void:
	var caster := _unit(Vector2i.ZERO,human,true)
	var ally := _unit(Vector2i(1,0),human)
	ally.hp = 3
	await wait_seconds(.3)
	var body: MeshInstance3D = ally._visual_root.find_children("*","MeshInstance3D",true,false)[0]
	var material := body.get_active_material(0)
	var transform := ally.transform
	assert_true(V2MagicRuntime.cast(caster,LIGHT,ally.coord,grid))
	assert_eq(ally.hp,12.0)
	assert_eq(human.mana,195.0)
	assert_eq(caster.movement_left,0.0)
	assert_eq(_effects().size(),1)
	var effect: Node3D = _effects()[0]
	effect.set_process(false)
	var caster_mesh: MeshInstance3D = caster._visual_root.find_children("*","MeshInstance3D",true,false)[0]
	effect.age = .7
	effect._update_visuals(0)
	assert_not_null(caster_mesh.material_overlay,"Mana charge shines on the casting body")
	effect.age = effect.arrival+.25
	effect._update_visuals(0)
	assert_not_null(body.material_overlay,"Restoration reacts on the actual body")
	assert_same(body.get_active_material(0),material,"Original material stays shared and untouched")
	assert_eq(ally.transform,transform,"No gameplay or body movement is introduced")
	effect._process(effect.duration)
	await wait_frames(2)
	assert_null(body.material_overlay,"Expired effects release their overlay")
	assert_null(caster_mesh.material_overlay,"Casting glow also releases its overlay")
	assert_true(_effects().is_empty())

func test_invalid_cast_creates_no_visual_and_spends_nothing() -> void:
	var caster := _unit(Vector2i.ZERO,human,true)
	var healthy := _unit(Vector2i(1,0),human)
	assert_false(V2MagicRuntime.cast(caster,LIGHT,healthy.coord,grid))
	assert_eq(human.mana,200.0)
	assert_true(_effects().is_empty())

func test_wave_uses_real_healing_and_does_not_light_enemies_or_healthy_units() -> void:
	var caster := _unit(Vector2i(-1,0),human,true)
	var primary := _unit(Vector2i.ZERO,human)
	var hurt := _unit(Vector2i(1,0),human)
	var enemy := _unit(Vector2i(0,1),rival)
	hurt.hp = hurt.unit_data.max_hp - 2
	enemy.hp = 2
	assert_true(V2MagicRuntime.cast(caster,WAVE,primary.coord,grid))
	var effect: Node3D = _effects()[0]
	effect.set_process(false)
	assert_eq(effect.ground.size(),7,"The area follows the map's seven hexagons")
	assert_eq(effect.recipients.size(),1,"Only a unit that actually healed receives restoration")
	assert_same(effect.recipients[0].unit.get_ref(),hurt)
	assert_eq(float(effect.recipients[0].heal),2.0,"Actual healing, including the maximum HP clamp")
	assert_eq(enemy.hp,2.0)
	assert_eq(human.mana,184.0)

func test_aegis_marker_survives_enemy_turn_and_rebuilds_from_saved_status() -> void:
	var caster := _unit(Vector2i.ZERO,human,true)
	var ally := _unit(Vector2i(1,0),human)
	assert_true(V2MagicRuntime.cast(caster,AEGIS,ally.coord,grid))
	var ward := ally.get_node_or_null("SacredAegis")
	assert_not_null(ward)
	assert_null(ally.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME),"No duplicate blue generic ring")
	ally.refresh_technique_marker(false)
	assert_same(ally.get_node("SacredAegis"),ward,"Refresh does not duplicate protection")
	TurnManager.turn_number += 1
	ward._process(.1)
	assert_false(ward.is_queued_for_deletion(),"Protection remains during the enemy phase")
	assert_almost_eq(V2MagicRuntime.defense_multiplier(ally),1.4,.001)
	# Loading/form replacement invokes the same idempotent marker refresh.
	ally.remove_child(ward)
	ward.queue_free()
	ally.refresh_technique_marker(false)
	assert_not_null(ally.get_node_or_null("SacredAegis"))
	assert_eq(V2MagicRuntime.expire_finished(human),1)
	assert_null(ally.get_node_or_null("SacredAegis"),"Owner turn expiration removes the visual too")

func test_dispel_and_death_remove_protection() -> void:
	var ally := _unit(Vector2i.ZERO,human)
	ally.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	ally.refresh_technique_marker()
	assert_not_null(ally.get_node_or_null("SacredAegis"))
	ally.magic_status.erase(AEGIS)
	ally.refresh_technique_marker()
	assert_null(ally.get_node_or_null("SacredAegis"))
	ally.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	ally.refresh_technique_marker()
	var ward := ally.get_node("SacredAegis")
	ally.hp = 0
	ward._process(.1)
	assert_true(ward.is_queued_for_deletion())

func test_enemy_spell_does_not_reveal_caster_or_area_outside_fog() -> void:
	var caster := _unit(Vector2i(-1,0),rival,true)
	var ally := _unit(Vector2i.ZERO,rival)
	ally.hp = 3
	grid.visibility[ally.coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[caster.coord] = HexGrid.Visibility.EXPLORED
	assert_true(V2MagicRuntime.cast(caster,WAVE,ally.coord,grid))
	var effect: Node3D = _effects()[0]
	effect.set_process(false)
	effect.age = effect.arrival+.2
	effect._update_visuals(0)
	assert_false(effect.charge.visible,"Never reveal a hidden enemy casting position")
	for mote in effect.stream: assert_false(mote.visible,"No path points back into hidden territory")
	for cell in effect.ground: assert_eq(bool(cell.node.visible),cell.coord==ally.coord)
	assert_true(effect.recipients[0].node.visible,"The visible target may still react")
	grid.visibility[ally.coord] = HexGrid.Visibility.EXPLORED
	effect._update_visuals(0)
	assert_false(effect.recipients[0].node.visible,"Visibility updates while an effect is running")

func test_removed_units_cleanup_and_damage_overlay_has_priority() -> void:
	var caster := _unit(Vector2i.ZERO,human,true)
	var ally := _unit(Vector2i(1,0),human)
	ally.hp = 3
	assert_true(V2MagicRuntime.cast(caster,LIGHT,ally.coord,grid))
	var effect: Node3D = _effects()[0]
	effect.set_process(false)
	var body: MeshInstance3D = ally._visual_root.find_children("*","MeshInstance3D",true,false)[0]
	var damage := Unit._get_hit_flash_material()
	body.material_overlay = damage
	effect.age = effect.arrival+.2
	effect._update_visuals(0)
	assert_same(body.material_overlay,damage)
	grid.remove_unit(caster)
	grid.remove_unit(ally)
	await wait_frames(2)
	effect._process(effect.duration)
	await wait_frames(2)
	assert_true(_effects().is_empty(),"Removing participants does not strand visual nodes")

func test_budget_and_accessibility_keep_casts_working() -> void:
	Settings.reduced_motion = true
	Settings.creature_lighting_enabled = false
	var caster := _unit(Vector2i.ZERO,human,true)
	var ally := _unit(Vector2i(1,0),human)
	var spell := V2SpellDatabase.get_spell(LIGHT)
	for i in SpellVFX.MAX_CASTS_PER_MAP:
		var effect := SpellVFX.play(caster,spell,ally.coord,grid,[])
		effect.set_process(false)
		assert_false(effect.light.visible)
	assert_eq(_effects().size(),SpellVFX.MAX_CASTS_PER_MAP)
	ally.hp = 3
	assert_true(V2MagicRuntime.cast(caster,LIGHT,ally.coord,grid),"At the visual limit, gameplay still resolves")
	assert_eq(ally.hp,12.0)
	assert_eq(human.mana,195.0)
	assert_eq(_effects().size(),SpellVFX.MAX_CASTS_PER_MAP)

func test_ground_marks_follow_elevation_and_stay_above_water() -> void:
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var point := Art.ground_point(grid,Vector2i.ZERO,Vector3(.5,0,0))
	assert_almost_eq(point.y,grid.surface_height_at(Vector2i.ZERO,Vector2(.5,0))+.035,.001)
	assert_lt(point.y,grid.world_surface_for_coord(Vector2i.ZERO).y,"The seal conforms to the slope instead of floating at the summit")
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	point = Art.ground_point(grid,Vector2i.ZERO,Vector3(.5,0,0))
	assert_almost_eq(point.y,grid.world_surface_for_coord(Vector2i.ZERO).y+.035,.001)
	grid.tiles[Vector2i.ZERO] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var seal: Node3D = Art.seal(grid,grid,Vector2i.ZERO,.86,true)
	assert_eq(seal.get_child_count(),1,"A continuous soft ribbon replaces the block segments")
	var ribbon := seal.get_child(0) as MeshInstance3D
	var vertices: PackedVector3Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for side in 6:
		var start: Vector3 = (vertices[side*16*6]+vertices[side*16*6+1])*.5
		var end: Vector3 = (vertices[side*16*6+2]+vertices[side*16*6+5])*.5
		var edge := (HexMetrics.corner(.86,(side+1)%6)-HexMetrics.corner(.86,side)).normalized()
		assert_almost_eq((end-start).normalized().dot(edge),1.0,.001,"All six edges follow the actual hexagon")
