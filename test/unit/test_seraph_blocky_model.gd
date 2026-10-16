extends GutTest

const KIND := "v2_manifestation_seraph"
const MODEL := "res://assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.glb"
var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players: player.release_relations()
	_players.clear()

func _seraph(race: String = "human") -> Unit:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_players.append(player)
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(KIND), player, Vector2i.ZERO)
	return unit

func test_every_race_spawns_the_shared_model_with_one_active_controller():
	for race in ["human", "elf", "orc", "dwarf"]:
		var unit := _seraph(race)
		assert_eq(unit.unit_data.model_scene_path, MODEL, race)
		assert_not_null(unit._anim_player, race)
		if unit._anim_player == null: continue
		assert_eq(unit._anim_player.current_animation, "Idle", race)
		var playing := 0
		for player in unit.find_children("*", "AnimationPlayer", true, false):
			if player.is_playing(): playing += 1
		assert_eq(playing, 1, "%s: only Unit controls the skeleton" % race)
		var meshes := unit.find_children("*", "MeshInstance3D", true, false)
		var body: MeshInstance3D
		for mesh in meshes:
			if mesh.skin != null: body = mesh
		assert_not_null(body, race)
		if body == null: continue
		var model := unit._anim_player.get_parent() as Node3D
		assert_eq(model.scale, Vector3.ONE, "%s: native three-meter model" % race)
		assert_almost_eq(body.mesh.get_aabb().size.y, 3.0, 0.001, race)
		assert_almost_eq(model.rotation.y, 0.0, 0.001, "%s: +Z forward" % race)
		var material := body.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(material.emission_enabled and material.emission_texture != null, race)
		assert_true(material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS], race)

func test_four_clips_use_the_correct_loop_and_blend_contract():
	var unit := _seraph()
	var player := unit._anim_player
	assert_not_null(player)
	if player == null: return
	assert_eq(player.get_animation_list().size(), 4)
	for clip in ["Idle", "Walk", "Attack", "Spell"]:
		assert_true(player.has_animation(clip), clip)
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE, clip)
	# 2026-10-13: as trocas de estado usam a transição por captura de pose (test_grand_manifestations_in_game.gd), não o
	# crossfade linear de 0,2 s.
	assert_true(player.get_meta(Unit.POSE_TRANSITION_META, null) is PoseCaptureTransition)
	assert_eq(player.playback_default_blend_time, 0.0)
	assert_eq(unit.attack_animation, "Attack")
	assert_eq(unit.cast_animation, "Spell")
	assert_false(unit.unit_data.can_basic_attack, "Art integration preserves the sacred support unit's rules")
	assert_eq(unit.unit_data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_false(unit.can_embark(), "Flying seraph keeps its own model over water")

func test_actual_movement_selects_walk_and_returns_to_idle_on_arrival():
	var unit := _seraph()
	unit.slide_to(Vector3(2, 0, 0))
	assert_eq(unit._anim_player.current_animation, "Walk")
	unit.place_at(Vector3(2, 0, 0))
	assert_eq(unit._anim_player.current_animation, "Idle")

func test_cast_faces_target_and_automatically_returns_to_idle():
	var unit := _seraph()
	unit.play_cast_visual(Vector3(3, 0, 0))
	assert_eq(unit._anim_player.current_animation, "Spell")
	assert_almost_eq(unit.facing_target_yaw, PI/2, 0.001)
	unit._anim_player.advance(3.1)
	assert_eq(unit._anim_player.current_animation, "Idle")

func test_cast_returns_to_walk_if_the_unit_is_still_moving():
	var unit := _seraph()
	unit.slide_to(Vector3(2, 0, 0))
	unit.play_cast_visual(Vector3(3, 0, 0))
	unit._anim_player.advance(3.1)
	assert_eq(unit._anim_player.current_animation, "Walk")

func test_interrupting_spell_resets_the_core_and_keeps_concentric_rings():
	var unit := _seraph()
	var player := unit._anim_player
	var skeleton := unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	unit.play_cast_visual(Vector3(0, 0, 3))
	for frame in 34: player.advance(1.0 / 24.0)
	assert_gt(skeleton.get_bone_pose_scale(skeleton.find_bone("core")).x, 1.1, "Spell animates the runtime skeleton")
	unit._play_animation("Idle")
	# Advance past the complete pose transition (UnitDatabase.MANIFESTATION_TRANSITION_TIME).
	for frame in ceili(UnitDatabase.MANIFESTATION_TRANSITION_TIME * 24.0) + 2: player.advance(1.0 / 24.0)
	skeleton.force_update_all_bone_transforms()
	var core := skeleton.find_bone("core")
	assert_almost_eq(skeleton.get_bone_pose_scale(core).x, 1.0, 0.001)
	var center := skeleton.get_bone_global_pose(core).origin
	for ring in ["orbit_a", "orbit_b"]:
		assert_almost_eq(center.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone(ring)).origin), 0.0, 0.0001, ring)
