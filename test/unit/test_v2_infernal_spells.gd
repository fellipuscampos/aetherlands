extends GutTest

## Fase 18 — Escola Infernal pelo runtime genérico: alvo hostil, fórmula de dano
## mágico, condicional por HP, AoE determinística e pipeline normal de morte.

const WARLOCK := "v2_unit_infernal_warlock"
const ARCHDEMON := "v2_manifestation_archdemon"
const FLAME := "v2_spell_infernal_flame"
const DEVOURING := "v2_spell_devouring_fire"
const BLAST := "v2_spell_infernal_blast"
const DAMNATION := "v2_spell_damnation"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var peaceful: PlayerData
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
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	peaceful = _player("Reino em Paz")
	GameManager.players = [human, rival, peaceful] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival, peaceful] as Array[PlayerData]
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 40
	human.mana = 200.0

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
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(player: PlayerData, tier: int = 7) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_infernal_%d" % i):
			assert_true(player.v2_research.complete_research("v2_magic_infernal_%d" % i))

func _unit(kind: String, owner: PlayerData, coord: Vector2i, hp: float = -1.0) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	if hp >= 0.0:
		unit.hp = hp
	return unit

func _warlock(tier: int = 7, coord: Vector2i = Vector2i.ZERO) -> Unit:
	_learn(human, tier)
	return _unit(WARLOCK, human, coord)

func _ids(spells: Array[V2SpellData]) -> Array:
	return spells.map(func(spell): return spell.id)

func test_infernal_spell_records_are_canonical_and_ordered():
	var flame := V2SpellDatabase.get_spell(FLAME)
	var devouring := V2SpellDatabase.get_spell(DEVOURING)
	var blast := V2SpellDatabase.get_spell(BLAST)
	var damnation := V2SpellDatabase.get_spell(DAMNATION)
	assert_eq(_ids(V2SpellDatabase.for_school("infernal")), [FLAME, DEVOURING, BLAST, DAMNATION])
	for spell in [flame, devouring, blast, damnation]:
		assert_eq(spell.school_branch, "infernal")
		assert_eq(spell.target_mode, V2SpellData.TargetMode.HOSTILE_UNIT)
	assert_eq([flame.mana_cost, flame.cast_range, flame.cooldown_turns, flame.damage_amount, flame.splash_radius], [5.0, 3, 0, 6.0, 0])
	assert_eq([devouring.mana_cost, devouring.cast_range, devouring.cooldown_turns, devouring.damage_amount], [8.0, 3, 2, 8.0])
	assert_eq([devouring.low_hp_threshold, devouring.low_hp_damage_bonus], [0.5, 0.5])
	assert_eq([blast.mana_cost, blast.cast_range, blast.cooldown_turns, blast.damage_amount, blast.splash_radius], [11.0, 3, 3, 5.0, 1])
	assert_eq([damnation.mana_cost, damnation.cast_range, damnation.cooldown_turns, damnation.damage_amount, damnation.splash_radius], [18.0, 4, 5, 15.0, 0])

func test_repertoire_is_derived_from_owner_research_in_n4_to_n7_order():
	_learn(human, 3)
	var warlock := _unit(WARLOCK, human, Vector2i.ZERO)
	assert_eq(_ids(V2MagicRuntime.spells_for_unit(warlock)), [])
	var expected := []
	for pair in [[4, FLAME], [5, DEVOURING], [6, BLAST], [7, DAMNATION]]:
		_learn(human, pair[0])
		expected.append(pair[1])
		assert_eq(_ids(V2MagicRuntime.spells_for_unit(warlock)), expected)

func test_flame_damages_six_costs_five_and_spends_action_without_retaliation():
	var warlock := _warlock(4)
	var enemy := _unit("warrior", rival, Vector2i(3, 0))
	var enemy_hp := enemy.hp
	var caster_hp := warlock.hp
	assert_true(V2MagicRuntime.cast(warlock, FLAME, enemy.coord, grid))
	assert_eq(enemy.hp, enemy_hp - 6.0)
	assert_eq(warlock.hp, caster_hp, "feitiço não causa revide")
	assert_eq(human.mana, 195.0)
	assert_eq(warlock.movement_left, 0.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(warlock, FLAME), 0)

func test_hostile_targeting_rejects_self_own_units_peace_and_out_of_range():
	var warlock := _warlock(4)
	var own := _unit("warrior", human, Vector2i(1, 0))
	var peace := _unit("warrior", peaceful, Vector2i(0, 1))
	var enemy := _unit("warrior", rival, Vector2i(3, 0))
	var far := _unit("warrior", rival, Vector2i(4, 0))
	var spell := V2SpellDatabase.get_spell(FLAME)
	assert_ne(V2MagicRuntime.target_reason(warlock, spell, warlock, grid), "")
	assert_ne(V2MagicRuntime.target_reason(warlock, spell, own, grid), "")
	assert_ne(V2MagicRuntime.target_reason(warlock, spell, peace, grid), "")
	assert_eq(V2MagicRuntime.target_reason(warlock, spell, enemy, grid), "")
	assert_ne(V2MagicRuntime.target_reason(warlock, spell, far, grid), "")

func test_human_cannot_target_a_hidden_hostile_but_can_target_a_visible_one():
	var warlock := _warlock(4)
	var visible := _unit("warrior", rival, Vector2i(2, 0))
	var hidden := _unit("warrior", rival, Vector2i(0, 2))
	grid.visibility[visible.coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[hidden.coord] = HexGrid.Visibility.EXPLORED
	var targets := V2MagicRuntime.target_units(warlock, V2SpellDatabase.get_spell(FLAME), grid)
	assert_true(visible in targets)
	assert_false(hidden in targets)

func test_spell_hostility_does_not_depend_on_basic_attack_and_basic_attack_still_does():
	var warlock := _warlock(4)
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	assert_false(warlock.unit_data.can_basic_attack)
	assert_true(CombatResolver.is_hostile_unit_target(human, enemy, grid))
	assert_false(CombatResolver.can_attack_unit(warlock, enemy, grid))
	var warrior := _unit("warrior", human, Vector2i(0, 1))
	assert_true(CombatResolver.can_attack_unit(warrior, enemy, grid), "ataque básico preserva a regra diplomática")

func test_magical_damage_ignores_every_physical_defense_input():
	var warlock := _warlock(4)
	var enemy := _unit("v2_unit_guardian", rival, Vector2i(2, 0))
	enemy.unit_data.defense = 999.0
	enemy.fortified = true
	enemy.magic_status["v2_spell_sacred_aegis"] = TurnManager.turn_number + 1
	enemy.magic_status["v2_technique_shield_wall"] = TurnManager.turn_number + 1
	grid.tiles[enemy.coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	var predicted := V2MagicRuntime.predict_damage(warlock, enemy, V2SpellDatabase.get_spell(FLAME))
	var before := enemy.hp
	assert_eq(predicted, 6.0)
	assert_true(V2MagicRuntime.cast(warlock, FLAME, enemy.coord, grid))
	assert_eq(before - enemy.hp, predicted)

func test_devouring_fire_threshold_is_inclusive_and_uses_the_same_prediction_formula():
	var warlock := _warlock(5)
	var target := _unit("warrior", rival, Vector2i(2, 0))
	var spell := V2SpellDatabase.get_spell(DEVOURING)
	target.hp = target.unit_data.max_hp * 0.501
	assert_eq(V2MagicRuntime.predict_damage(warlock, target, spell), 8.0, "50,1% não recebe bônus")
	target.hp = target.unit_data.max_hp * 0.5
	assert_eq(V2MagicRuntime.predict_damage(warlock, target, spell), 12.0, "50% exato recebe bônus")
	target.hp = target.unit_data.max_hp * 0.49
	assert_eq(V2MagicRuntime.predict_damage(warlock, target, spell), 12.0)

func test_archdemon_multiplier_applies_only_as_spell_damage_data():
	_learn(human, 7)
	var archdemon := _unit(ARCHDEMON, human, Vector2i.ZERO)
	var target := _unit("v2_legendary_guardian_champion", rival, Vector2i(2, 0))
	var devouring := V2SpellDatabase.get_spell(DEVOURING)
	assert_eq(V2MagicRuntime.predict_damage(archdemon, target, V2SpellDatabase.get_spell(FLAME)), 7.5)
	assert_eq(V2MagicRuntime.predict_damage(archdemon, target, devouring), 10.0)
	target.hp = target.unit_data.max_hp * 0.5
	assert_eq(V2MagicRuntime.predict_damage(archdemon, target, devouring), 15.0)
	assert_eq(V2MagicRuntime.predict_damage(archdemon, target, V2SpellDatabase.get_spell(BLAST)), 6.25)
	assert_eq(V2MagicRuntime.predict_damage(archdemon, target, V2SpellDatabase.get_spell(DAMNATION)), 18.75)

func test_blast_primary_is_first_and_secondaries_are_hp_ratio_then_serial():
	var warlock := _warlock(6)
	var primary := _unit("warrior", rival, Vector2i(2, 0))
	var first_serial := _unit("warrior", rival, Vector2i(3, 0))
	var low_hp := _unit("warrior", rival, Vector2i(2, 1))
	var later_serial := _unit("warrior", rival, Vector2i(1, 1))
	first_serial.hp = first_serial.unit_data.max_hp * 0.5
	later_serial.hp = later_serial.unit_data.max_hp * 0.5
	low_hp.hp = low_hp.unit_data.max_hp * 0.25
	var affected := V2MagicRuntime.affected_units(warlock, V2SpellDatabase.get_spell(BLAST), primary, grid)
	assert_eq(affected, [primary, low_hp, first_serial, later_serial])

func test_blast_hits_all_hostiles_once_without_friendly_fire_or_peace_targets():
	var warlock := _warlock(6)
	var primary := _unit("warrior", rival, Vector2i(2, 0))
	var hostile_a := _unit("warrior", rival, Vector2i(3, 0))
	var hostile_b := _unit("warrior", rival, Vector2i(2, 1))
	var own := _unit("warrior", human, Vector2i(1, 1))
	var peace := _unit("warrior", peaceful, Vector2i(2, -1))
	var before := [primary.hp, hostile_a.hp, hostile_b.hp, own.hp, peace.hp]
	assert_true(V2MagicRuntime.cast(warlock, BLAST, primary.coord, grid))
	assert_eq([before[0] - primary.hp, before[1] - hostile_a.hp, before[2] - hostile_b.hp], [5.0, 5.0, 5.0])
	assert_eq([own.hp, peace.hp], [before[3], before[4]])
	assert_eq(human.mana, 189.0, "uma cobrança, não por vítima")

func test_blast_resolves_secondaries_after_primary_dies_and_credits_each_kill_once():
	var warlock := _warlock(6)
	var primary := _unit("warrior", rival, Vector2i(2, 0), 5.0)
	var secondary_a := _unit("warrior", rival, Vector2i(3, 0), 5.0)
	var secondary_b := _unit("warrior", rival, Vector2i(2, 1), 5.0)
	assert_true(V2MagicRuntime.cast(warlock, BLAST, primary.coord, grid))
	for target in [primary, secondary_a, secondary_b]:
		assert_null(grid.get_unit_at(target.coord))
	assert_eq(warlock.kills, 3)

func test_hidden_blast_secondary_is_not_damaged_for_the_human():
	var warlock := _warlock(6)
	var primary := _unit("warrior", rival, Vector2i(2, 0))
	var shown := _unit("warrior", rival, Vector2i(3, 0))
	var hidden := _unit("warrior", rival, Vector2i(2, 1))
	grid.visibility[primary.coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[shown.coord] = HexGrid.Visibility.VISIBLE
	grid.visibility[hidden.coord] = HexGrid.Visibility.EXPLORED
	var hidden_hp := hidden.hp
	assert_true(V2MagicRuntime.cast(warlock, BLAST, primary.coord, grid))
	assert_eq(hidden.hp, hidden_hp)
	assert_eq(shown.hp, shown.unit_data.max_hp - 5.0)

func test_damnation_uses_range_four_when_another_source_reveals_the_target():
	var warlock := _warlock(7)
	var target := _unit("v2_legendary_guardian_champion", rival, Vector2i(4, 0))
	grid.visibility[target.coord] = HexGrid.Visibility.VISIBLE
	var before := target.hp
	assert_true(V2MagicRuntime.cast(warlock, DAMNATION, target.coord, grid))
	assert_eq(before - target.hp, 15.0)
	assert_eq(human.mana, 182.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(warlock, DAMNATION), 5)

func test_damnation_at_range_four_is_blocked_while_hidden():
	var warlock := _warlock(7)
	var target := _unit("warrior", rival, Vector2i(4, 0))
	grid.visibility[target.coord] = HexGrid.Visibility.EXPLORED
	assert_false(V2MagicRuntime.cast(warlock, DAMNATION, target.coord, grid))
	assert_eq(human.mana, 200.0)

func test_spell_kill_uses_normal_kill_and_removal_pipeline():
	var warlock := _warlock(4)
	var target := _unit("warrior", rival, Vector2i(2, 0), 6.0)
	assert_true(V2MagicRuntime.cast(warlock, FLAME, target.coord, grid))
	assert_eq(warlock.kills, 1)
	assert_eq(warlock.veterancy_level, 1)
	assert_null(grid.get_unit_at(Vector2i(2, 0)))
	assert_false(target in rival.units)

func test_effect_text_is_generated_from_generic_spell_data():
	var flame := V2SpellDatabase.effect_text(V2SpellDatabase.get_spell(FLAME))
	var devouring := V2SpellDatabase.effect_text(V2SpellDatabase.get_spell(DEVOURING))
	var blast := V2SpellDatabase.effect_text(V2SpellDatabase.get_spell(BLAST))
	assert_string_contains(flame, "6 de dano mágico")
	assert_string_contains(devouring, "+50% contra alvos com 50% de Vida ou menos")
	assert_string_contains(blast, "5 de dano mágico ao alvo")
	assert_string_contains(blast, "inimigos adjacentes")

func test_offensive_targeting_mode_keeps_the_hostile_coords_and_cancels_cleanly():
	var warlock := _warlock(4)
	var target := _unit("warrior", rival, Vector2i(2, 0))
	SelectionManager._select_unit(warlock)
	SelectionManager.use_v2_spell_selected(FLAME)
	assert_eq(SelectionManager.v2_spell_targeting_id, FLAME)
	assert_eq(SelectionManager.v2_spell_target_coords, [target.coord] as Array[Vector2i])
	assert_eq(grid._last_highlighted_land_coords, [target.coord])
	assert_true(SelectionManager.cancel_v2_spell_targeting())
	assert_eq([human.mana, warlock.movement_left], [200.0, 2.0])
