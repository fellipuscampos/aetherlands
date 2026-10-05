extends GutTest

## Modelos próprios das linhas do Guerreiro e do Patrulheiro (Blender MCP, 2026-10-04): cada forma usa o próprio GLB
## (assets/generated/humans/<pasta>), 1:1, com Idle/Walk/Attack e os clipes das técnicas de ATAQUE da linha
## (UnitDatabase._apply_human_troop_model). Durante uma técnica com clipe próprio o combate toca esse clipe UMA vez por
## uso (Unit.play_attack_visual), mesmo quando o golpe resolve vários alvos (Ataque em Arco, Saraivada).

const PS := V2DoctrineTechniqueDatabase.POWER_STRIKE
const CL := V2DoctrineTechniqueDatabase.CLEAVE
const PR := V2DoctrineTechniqueDatabase.PRECISE_SHOT
const VO := V2DoctrineTechniqueDatabase.VOLLEY

## kind -> [pasta, prefixo, técnicas com clipe próprio]
const FORMS := {
	"v2_unit_warrior": ["warrior_v1", "Warrior", [PS]],
	"v2_unit_swordsman": ["swordsman_v1", "Swordsman", [PS, CL]],
	"v2_unit_weapon_master": ["weapon_master_v1", "WeaponMaster", [PS, CL]],
	"v2_legendary_blade_hero": ["blade_hero_v1", "BladeHero", [PS, CL]],
	"v2_unit_archer": ["archer_v1", "Archer", [PR]],
	"v2_unit_hunter": ["hunter_v1", "Hunter", [PR, VO]],
	"v2_unit_elite_marksman": ["elite_marksman_v1", "EliteMarksman", [PR, VO]],
	"v2_legendary_legend_hunter": ["legend_hunter_v1", "LegendHunter", [PR, VO]],
}
const CLIP_SUFFIX := {PS: "_PowerStrike", CL: "_ArcAttack", PR: "_PreciseShot", VO: "_Volley"}

func _player_of(kind: String) -> AnimationPlayer:
	var scene: PackedScene = load(UnitDatabase.create_unit(kind).model_scene_path)
	var root := scene.instantiate()
	var found: Array = root.find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer = found[0] if not found.is_empty() else null
	autofree(root)
	return player

func test_every_form_uses_its_own_model_at_true_scale_with_smooth_transitions():
	for kind in FORMS:
		var data := UnitDatabase.create_unit(kind)
		var path := "res://assets/generated/humans/%s/%s.glb" % [FORMS[kind][0], FORMS[kind][0]]
		assert_eq(data.model_scene_path, path, kind)
		assert_eq(data.animation_scene_path, path, "%s: os clipes vêm do próprio GLB" % kind)
		assert_true(ResourceLoader.exists(path), path)
		assert_eq(data.model_scale_multiplier, 1.0, "%s: a altura já está no modelo (sem a escala do KayKit provisório)" % kind)
		assert_eq(data.model_yaw_offset_degrees, 0.0, kind)
		assert_eq(data.animation_blend_time, UnitDatabase.GUARDIAN_LINE_BLEND_TIME, "%s: crossfade entre os clipes" % kind)
		assert_false(data.merge_shared_walk_animation, kind)
		var prefix: String = FORMS[kind][1]
		assert_eq(data.idle_animation_override, prefix + "_Idle", kind)
		assert_eq(data.walk_animation_override, prefix + "_Walk", kind)
		assert_eq(data.attack_animation_override, prefix + "_Attack", kind)
		assert_eq(data.shield_wall_animation_override, "", "%s: só a linha do Guardião tem a Muralha" % kind)

func test_the_technique_clips_follow_the_line():
	for kind in FORMS:
		var data := UnitDatabase.create_unit(kind)
		var expected := {}
		for technique_id in FORMS[kind][2]:
			expected[technique_id] = FORMS[kind][1] + CLIP_SUFFIX[technique_id]
		assert_eq(data.technique_animation_overrides, expected, kind)

func test_every_glb_carries_the_clips_its_data_names():
	for kind in FORMS:
		var data := UnitDatabase.create_unit(kind)
		var player := _player_of(kind)
		assert_not_null(player, kind)
		if player == null:
			continue
		for clip in [data.idle_animation_override, data.walk_animation_override, data.attack_animation_override] + data.technique_animation_overrides.values():
			assert_true(player.has_animation(clip), "%s: o GLB tem %s" % [kind, clip])
		assert_eq(player.get_animation(data.idle_animation_override).loop_mode, Animation.LOOP_LINEAR, "%s: Idle em loop" % kind)
		assert_eq(player.get_animation(data.attack_animation_override).loop_mode, Animation.LOOP_NONE, "%s: Attack toca uma vez" % kind)
		for clip in data.technique_animation_overrides.values():
			assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s: técnica toca uma vez" % clip)

func test_the_guardian_line_still_has_its_shield_wall():
	var data := UnitDatabase.create_unit("v2_unit_guardian")
	assert_eq(data.shield_wall_hold_animation_override, "Guardian_ShieldWallHold")
	assert_true(data.technique_animation_overrides.is_empty(), "a Muralha é postura, não técnica de ataque com clipe")

# --- Reprodução no combate ---------------------------------------------------------------------------------------------

func _unit(kind: String, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), PlayerData.new(CivilizationData.new()), coord)
	return unit

func test_a_plain_attack_plays_the_attack_clip_facing_the_defender():
	var swordsman := _unit("v2_unit_swordsman", Vector2i(0, 0))
	var target := _unit("v2_unit_warrior", Vector2i(1, 0))
	target.position = swordsman.position + Vector3(2.0, 0.0, 0.0)
	swordsman.play_attack_visual(target)
	assert_eq(swordsman._anim_player.current_animation, "Swordsman_Attack")
	assert_almost_eq(swordsman.rotation.y, atan2(2.0, 0.0), 0.001, "virou para o defensor")

func test_a_technique_plays_its_own_clip_once_for_all_its_targets():
	var hunter := _unit("v2_unit_hunter", Vector2i(0, 0))
	var first := _unit("v2_unit_warrior", Vector2i(2, 0))
	var second := _unit("v2_unit_warrior", Vector2i(2, 1))
	first.position = hunter.position + Vector3(0.0, 0.0, 3.0)
	second.position = hunter.position + Vector3(-3.0, 0.0, 0.0)
	hunter.begin_technique_animation(VO)
	hunter.play_attack_visual(first)
	assert_eq(hunter._anim_player.current_animation, "Hunter_Volley", "Saraivada toca o clipe próprio")
	var facing := hunter.rotation.y
	hunter.play_attack_visual(second)
	assert_eq(hunter._anim_player.current_animation, "Hunter_Volley", "o segundo alvo não troca o clipe")
	assert_almost_eq(hunter.rotation.y, facing, 0.001, "segue virado para o primeiro alvo")
	hunter.end_technique_animation()
	hunter.play_attack_visual(second)
	assert_eq(hunter._anim_player.current_animation, "Hunter_Attack", "fora da técnica volta ao Attack comum")

func test_a_technique_without_its_own_clip_falls_back_to_the_attack():
	var warrior := _unit("v2_unit_warrior", Vector2i(0, 0))
	var target := _unit("v2_unit_archer", Vector2i(1, 0))
	warrior.begin_technique_animation(CL) # o Guerreiro não tem clipe de Ataque em Arco
	warrior.play_attack_visual(target)
	assert_eq(warrior._anim_player.current_animation, "Warrior_Attack")
	warrior.end_technique_animation()

func test_the_technique_clip_returns_to_rest_when_it_ends():
	var master := _unit("v2_unit_weapon_master", Vector2i(0, 0))
	var target := _unit("v2_unit_warrior", Vector2i(1, 0))
	master.begin_technique_animation(PS)
	master.play_attack_visual(target)
	assert_eq(master._anim_player.current_animation, "WeaponMaster_PowerStrike")
	master._on_blended_animation_finished(&"WeaponMaster_PowerStrike", master._anim_player)
	assert_eq(master._anim_player.current_animation, "WeaponMaster_Idle", "a técnica é one-shot: volta ao Idle")
	master.end_technique_animation()
