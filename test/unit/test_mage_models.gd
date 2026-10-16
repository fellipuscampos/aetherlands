extends GutTest

## Magos com modelo próprio (2026-10-10): 6 Escolas x 4 raças, clipes idle/walk/spell. O feitiço toca a conjuração
## uma vez, virado para o alvo, e volta ao repouso/andar com o crossfade normal — o mesmo clipe para todo feitiço.

const SCHOOLS := ["v2_unit_sacred_cleric", "v2_unit_infernal_warlock", "v2_unit_necromancer", "v2_unit_druid", "v2_unit_arcanist", "v2_unit_elementalist"]

var _players: Array[PlayerData] = []

func after_each() -> void:
	for player in _players:
		player.release_relations()
	_players.clear()

func _player(race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	var player := PlayerData.new(civ)
	_players.append(player)
	return player

func _mage(kind: String, race: String) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(UnitDatabase.create_unit(kind), _player(race), Vector2i.ZERO)
	return unit

func test_every_school_of_every_race_wears_its_own_model_with_the_three_clips():
	var folders := {"human": "humans", "dwarf": "dwarves", "elf": "elves", "orc": "orcs"}
	for race in folders:
		for kind in SCHOOLS:
			var unit := _mage(kind, race)
			var label := "%s/%s" % [race, kind]
			var school: String = UnitArtCatalog.MAGE_SCHOOLS[kind]
			var expected := "res://assets/generated/%s/%s_%s_v1/%s_%s_v1.glb" % [folders[race], race, school, race, school]
			assert_eq(unit.unit_data.model_scene_path, expected, label)
			assert_not_null(unit._anim_player, label)
			if unit._anim_player == null:
				continue
			assert_eq(String(unit._anim_player.current_animation), "idle", "%s nasce parado" % label)
			assert_eq(unit.cast_animation, "spell", label)
			assert_gt(unit._anim_player.playback_default_blend_time, 0.0, "%s: transições suaves" % label)
			for clip in ["idle", "walk"]:
				assert_eq(unit._anim_player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s: %s em loop" % [label, clip])
			assert_eq(unit._anim_player.get_animation("spell").loop_mode, Animation.LOOP_NONE, "%s: conjuração uma vez" % label)
			assert_eq(unit.attack_animation, "", "%s: mago sem ataque básico" % label)

func test_a_spell_plays_the_cast_once_facing_the_target_and_returns_to_rest():
	var mage := _mage("v2_unit_arcanist", "elf")
	mage.position = Vector3.ZERO
	mage.play_cast_visual(Vector3(3.0, 0.0, 0.0))
	assert_eq(String(mage._anim_player.current_animation), "spell", "conjura")
	assert_almost_eq(mage.facing_target_yaw, atan2(3.0, 0.0), 0.001, "virado para o alvo")
	mage._on_blended_animation_finished(&"spell", mage._anim_player)
	assert_eq(String(mage._anim_player.current_animation), "idle", "volta ao repouso com o crossfade normal")

func test_the_magic_runtime_triggers_the_cast_for_player_and_ai():
	var source := FileAccess.get_file_as_string("res://scripts/core/V2MagicRuntime.gd")
	assert_true(source.contains("unit.play_cast_visual(grid.world_for_coord(target_coord))"), "um ponto único depois de o feitiço resolver")
	assert_eq(source.count("_play_cast_visual(unit, target_coord, grid, spell"), 2, "feitiço em unidade e em tile")
	for caller in ["res://scripts/autoload/SelectionManager.gd", "res://scripts/core/V2AITacticalAI.gd"]:
		assert_true(FileAccess.get_file_as_string(caller).contains("V2MagicRuntime.cast("), "%s conjura pelo mesmo caminho" % caller)

func test_troops_and_settlers_have_no_cast_clip():
	for kind in ["settler", "v2_unit_warrior", "v2_unit_archer"]:
		assert_eq(UnitDatabase.create_unit(kind).cast_animation_override, "", kind)
