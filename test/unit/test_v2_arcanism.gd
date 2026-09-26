extends GutTest

## Fase 21 — conteúdo canônico do Arcanismo e os quatro efeitos pelo runtime genérico.

const ARCANIST := "v2_unit_arcanist"
const ARCHON := "v2_manifestation_veil_archon"
const STEP := "v2_spell_arcane_step"
const SILENCE := "v2_spell_silence"
const DISPEL := "v2_spell_dispel"
const PORTAL := "v2_spell_veil_portal"
const AEGIS := "v2_spell_sacred_aegis"
const COMMAND := "v2_spell_macabre_command"
const TECHNIQUE := "v2_technique_shield_wall"
const SCHOOL := "arcanism"
const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL

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
	human = _player("Reino Arcano")
	rival = _player("Reino Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 30
	human.mana = 300.0
	rival.mana = 300.0

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

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(player: PlayerData, branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not player.v2_research.is_completed(id):
			assert_true(player.v2_research.complete_research(id), id)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _arcanist(owner: PlayerData = human, coord: Vector2i = Vector2i.ZERO, tier: int = 7) -> Unit:
	_learn(owner, SCHOOL, tier)
	return _unit(ARCANIST, owner, coord)

func test_nine_nodes_are_canonical_and_the_full_magic_tree_is_connected():
	var names := ["Escola do Arcanismo", "Conclave Arcano", "Arcanista", "Passo Arcano", "Silêncio", "Dissipar", "Portal do Véu", "Torre do Véu", "Arconte do Véu"]
	var ids := ["v2_magic_school_arcanism", "v2_building_arcane_conclave", ARCANIST, STEP, SILENCE, DISPEL, PORTAL, "v2_building_arcane_ritual", ARCHON]
	var nodes := V2ResearchDatabase.nodes_for_branch(MAGIC, SCHOOL)
	assert_eq(nodes.size(), 9)
	for i in 9:
		assert_eq([nodes[i].display_name, nodes[i].unlock_id], [names[i], ids[i]])
		assert_true(nodes[i].gameplay_connected)
		assert_false(nodes[i].is_placeholder)
	assert_eq(V2MagicContent.CONNECTED_UNLOCK_IDS.size(), 55)
	for node in V2ResearchDatabase.nodes_for_branch(MAGIC, "elementalism"):
		assert_true(node.gameplay_connected)
	assert_true(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected)

func test_buildings_and_units_have_the_exact_phase_21_data():
	var conclave := BuildingDatabase.get_building("v2_building_arcane_conclave")
	var tower := BuildingDatabase.get_building("v2_building_arcane_ritual")
	assert_eq([conclave.display_name, conclave.production_cost, conclave.gold_upkeep, conclave.trains_unit], ["Conclave Arcano", 24.0, 1.0, ARCANIST])
	assert_eq(conclave.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	assert_eq([tower.display_name, tower.production_cost, tower.gold_upkeep, tower.requires_building, tower.trains_unit], ["Torre do Véu", 60.0, 2.0, "v2_building_arcane_conclave", ARCHON])
	assert_eq(tower.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	var caster := UnitDatabase.create_unit(ARCANIST)
	assert_eq([caster.unit_name, caster.max_hp, caster.attack, caster.defense, caster.movement_points, caster.vision_range, caster.production_cost, caster.supply_cost], ["Arcanista", 10.0, 0.0, 1.5, 2.0, 4, 24.0, 2])
	assert_false(caster.can_basic_attack)
	assert_eq([caster.v2_magic_school, caster.movement_profile], [SCHOOL, UnitData.MovementProfile.GROUND])
	var archon := UnitDatabase.create_unit(ARCHON)
	assert_eq([archon.unit_name, archon.max_hp, archon.attack, archon.defense, archon.movement_points, archon.vision_range, archon.production_cost, archon.production_mana_cost, archon.supply_cost], ["Arconte do Véu", 34.0, 0.0, 5.5, 4.0, 5, 105.0, 70.0, 0])
	assert_false(archon.can_basic_attack)
	assert_eq([archon.movement_profile, archon.spell_cooldown_reduction, archon.spell_cooldown_reduction_name], [UnitData.MovementProfile.FLYING, 1, "Fluxo do Véu"])
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_FLYING, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(archon.has_trait(trait_id), trait_id)
	for trait_id in [UnitData.TRAIT_LEGENDARY, UnitData.TRAIT_RETINUE, UnitData.TRAIT_UNDEAD]:
		assert_false(archon.has_trait(trait_id), trait_id)

func test_spell_records_and_status_metadata_are_data_driven():
	var spells := V2SpellDatabase.for_school(SCHOOL)
	assert_eq(spells.map(func(s): return s.id), [STEP, SILENCE, DISPEL, PORTAL])
	assert_eq([spells[0].target_mode, spells[0].mana_cost, spells[0].cast_range, spells[0].cooldown_turns, spells[0].teleport_caster], [V2SpellData.TargetMode.EMPTY_TILE, 6.0, 4, 2, true])
	assert_eq([spells[1].target_mode, spells[1].mana_cost, spells[1].cast_range, spells[1].cooldown_turns, spells[1].requires_v2_caster_target, spells[1].status_polarity, spells[1].status_dispellable], [V2SpellData.TargetMode.HOSTILE_UNIT, 8.0, 3, 3, true, V2SpellData.StatusPolarity.HARMFUL, true])
	assert_eq([spells[2].target_mode, spells[2].mana_cost, spells[2].cast_range, spells[2].cooldown_turns, spells[2].dispel_at_tile], [V2SpellData.TargetMode.TILE, 7.0, 3, 2, true])
	assert_eq([spells[3].target_mode, spells[3].mana_cost, spells[3].cast_range, spells[3].cooldown_turns, spells[3].creates_portal_pair], [V2SpellData.TargetMode.EMPTY_TILE, 18.0, 6, 5, true])
	for id in [AEGIS, COMMAND]:
		var status := V2SpellDatabase.get_spell(id)
		assert_eq([status.status_polarity, status.status_dispellable], [V2SpellData.StatusPolarity.BENEFICIAL, true])
	assert_null(V2SpellDatabase.get_spell(TECHNIQUE), "Técnica nunca vira V2SpellData")

func test_arcane_step_relocates_directly_and_consumes_only_the_cast_cost():
	var caster := _arcanist(human, Vector2i.ZERO, 4)
	for coord in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
		grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var destination := Vector2i(4, 0)
	caster.exploring = true
	caster.move_order_target = Vector2i(8, 0)
	assert_true(V2MagicRuntime.cast(caster, STEP, destination, grid))
	assert_eq(caster.coord, destination, "a barreira intermediária não participa")
	assert_eq([human.mana, caster.movement_left], [294.0, 0.0])
	assert_false(caster.exploring)
	assert_eq(caster.move_order_target, Unit.NO_MOVE_ORDER)
	assert_eq(V2MagicRuntime.cooldown_remaining(caster, STEP), 2)

func test_arcane_step_rejects_hidden_impassable_occupied_and_out_of_range_without_spending():
	var caster := _arcanist(human, Vector2i.ZERO, 4)
	_unit("warrior", human, Vector2i(1, 0))
	grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.visibility[Vector2i(0, 2)] = HexGrid.Visibility.UNSEEN
	grid.visibility[Vector2i(0, 1)] = HexGrid.Visibility.VISIBLE
	for coord in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(5, 0)]:
		assert_false(V2MagicRuntime.cast(caster, STEP, coord, grid), str(coord))
	assert_eq([human.mana, caster.movement_left, caster.coord], [300.0, 2.0, Vector2i.ZERO])

func test_silence_targets_only_hostile_v2_casters_refreshes_and_expires_by_owner_turn():
	var caster := _arcanist(human, Vector2i.ZERO, 5)
	var target := _arcanist(rival, Vector2i(2, 0), 4)
	var v1 := _unit("cultist", rival, Vector2i(1, 0))
	assert_ne(V2MagicRuntime.target_reason(caster, V2SpellDatabase.get_spell(SILENCE), v1, grid), "")
	assert_true(V2MagicRuntime.cast(caster, SILENCE, target.coord, grid))
	assert_true(V2MagicRuntime.is_spellcasting_silenced(target))
	assert_eq(V2MagicRuntime.unavailable_reason(target, STEP, grid), "Silêncio — não pode conjurar feitiços.")
	var first_expiry := int(target.magic_status[SILENCE])
	TurnManager.turn_number += 1
	caster.movement_left = 2.0
	caster.magic_cooldowns.clear()
	assert_true(V2MagicRuntime.cast(caster, SILENCE, target.coord, grid))
	assert_gt(int(target.magic_status[SILENCE]), first_expiry, "reaplicar renova; não empilha")
	TurnManager.turn_number = int(target.magic_status[SILENCE])
	assert_eq(V2MagicRuntime.expire_finished(rival), 1)
	assert_false(V2MagicRuntime.is_spellcasting_silenced(target))

func test_silence_does_not_block_portal_traversal():
	var traveler := _arcanist(rival, Vector2i(1, 0), 5)
	traveler.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, traveler.coord, Vector2i(5, 0), grid))
	assert_true(V2PortalSystem.traverse(traveler, grid), "travessia é ação de unidade, não cast")
	assert_eq(traveler.coord, Vector2i(5, 0))

func test_silence_gate_is_generic_for_every_v2_caster_and_manifestation():
	var fixtures := [
		["sacred", "v2_unit_sacred_cleric", "v2_spell_restoring_light"],
		["infernal", "v2_unit_infernal_warlock", "v2_spell_infernal_flame"],
		["necromancy", "v2_unit_necromancer", "v2_spell_raise_dead"],
		["druidism", "v2_unit_druid", "v2_spell_grow_grove"],
		[SCHOOL, ARCANIST, STEP],
		["sacred", "v2_manifestation_seraph", "v2_spell_restoring_light"],
		["infernal", "v2_manifestation_archdemon", "v2_spell_infernal_flame"],
		["necromancy", "v2_manifestation_lich_sovereign", "v2_spell_raise_dead"],
		["druidism", "v2_manifestation_nature_avatar", "v2_spell_grow_grove"],
		[SCHOOL, ARCHON, STEP],
	]
	for i in fixtures.size():
		var fixture: Array = fixtures[i]
		_learn(human, fixture[0], 4)
		var caster := _unit(fixture[1], human, Vector2i(-5 + i, 4))
		caster.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
		assert_true(V2MagicRuntime.is_spellcasting_silenced(caster), fixture[1])
		assert_eq(V2MagicRuntime.unavailable_reason(caster, fixture[2], grid), "Silêncio — não pode conjurar feitiços.", fixture[1])
		assert_gt(caster.movement_left, 0.0, "Silêncio não imobiliza %s" % fixture[1])

func test_dispel_removes_own_harmful_and_hostile_beneficial_but_not_technique_or_terrain():
	var caster := _arcanist(human, Vector2i.ZERO, 6)
	caster.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	caster.magic_status[TECHNIQUE] = V2OwnerTurnEffect.expiry_for_now()
	# Para provar Dissipar sobre o próprio Silêncio, a interferência é removida por outro Arcanista aliado.
	var helper := _arcanist(human, Vector2i(0, 1), 6)
	assert_true(V2MagicRuntime.cast(helper, DISPEL, caster.coord, grid))
	assert_false(caster.magic_status.has(SILENCE))
	assert_true(caster.magic_status.has(TECHNIQUE), "Técnica não é feitiço dissipável")
	var enemy := _arcanist(rival, Vector2i(2, 0), 6)
	enemy.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	helper.movement_left = 2.0
	helper.magic_cooldowns.clear()
	assert_true(V2MagicRuntime.cast(helper, DISPEL, enemy.coord, grid))
	assert_false(enemy.magic_status.has(AEGIS))
	V2TerrainRuntime.apply(grid, Vector2i(1, 1), "v2_terrain_dense_grove")
	assert_false(V2MagicRuntime.cast(helper, DISPEL, Vector2i(1, 1), grid), "terreno não é efeito mágico dissipável")
	assert_true(V2TerrainRuntime.has_modification(grid, Vector2i(1, 1)))

func test_dispel_polarity_matrix_and_multiple_statuses_are_resolved_in_one_cast():
	var caster := _arcanist(human, Vector2i.ZERO, 6)
	var own := _arcanist(human, Vector2i(1, 0), 6)
	own.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	own.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	own.magic_status[COMMAND] = V2OwnerTurnEffect.expiry_for_now()
	assert_eq(V2MagicRuntime.dispellable_statuses_for(caster, own, grid), [SILENCE])
	assert_true(V2MagicRuntime.cast(caster, DISPEL, own.coord, grid))
	assert_false(own.magic_status.has(SILENCE))
	assert_true(own.magic_status.has(AEGIS))
	assert_true(own.magic_status.has(COMMAND))
	var enemy := _arcanist(rival, Vector2i(2, 0), 6)
	enemy.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	enemy.magic_status[COMMAND] = V2OwnerTurnEffect.expiry_for_now()
	enemy.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	enemy.magic_status[TECHNIQUE] = V2OwnerTurnEffect.expiry_for_now()
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.erase(DISPEL)
	var mana_before := human.mana
	assert_eq(V2MagicRuntime.dispellable_statuses_for(caster, enemy, grid), [COMMAND, AEGIS])
	assert_true(V2MagicRuntime.cast(caster, DISPEL, enemy.coord, grid))
	assert_eq(human.mana, mana_before - 7.0, "um único custo")
	assert_false(enemy.magic_status.has(AEGIS))
	assert_false(enemy.magic_status.has(COMMAND))
	assert_true(enemy.magic_status.has(SILENCE), "harmful hostil permanece")
	assert_true(enemy.magic_status.has(TECHNIQUE), "Technique permanece")

func test_dispel_closes_the_whole_portal_pair_and_invalid_cast_is_transactional():
	var caster := _arcanist(human, Vector2i.ZERO, 7)
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, Vector2i(1, 0), Vector2i(3, 0), grid))
	assert_true(V2MagicRuntime.cast(caster, DISPEL, Vector2i(1, 0), grid))
	assert_true(V2PortalSystem.endpoint_at(Vector2i(1, 0), grid).is_empty())
	assert_true(V2PortalSystem.endpoint_at(Vector2i(3, 0), grid).is_empty())
	var mana := human.mana
	caster.movement_left = 2.0
	caster.magic_cooldowns.clear()
	assert_false(V2MagicRuntime.cast(caster, DISPEL, Vector2i(2, 0), grid))
	assert_eq([human.mana, caster.movement_left], [mana, 2.0])

func test_archon_reduces_new_cooldowns_by_one_without_retroactivity():
	_learn(human, SCHOOL, 7)
	var arcanist := _unit(ARCANIST, human, Vector2i.ZERO)
	var archon := _unit(ARCHON, human, Vector2i(0, 2))
	assert_eq(V2SpellDatabase.for_school(SCHOOL).map(func(spell): return V2MagicRuntime.effective_cooldown(archon, spell)), [1, 2, 1, 4])
	assert_eq(V2MagicRuntime.effective_cooldown(arcanist, V2SpellDatabase.get_spell(PORTAL)), 5)
	assert_eq(V2MagicRuntime.effective_cooldown(archon, V2SpellDatabase.get_spell(PORTAL)), 4)
	assert_true(V2MagicRuntime.cast(arcanist, PORTAL, Vector2i(5, 0), grid))
	assert_eq(V2MagicRuntime.cooldown_remaining(arcanist, PORTAL), 5)
	arcanist.unit_data.spell_cooldown_reduction = 1
	assert_eq(V2MagicRuntime.cooldown_remaining(arcanist, PORTAL), 5, "recarga gravada não é recalculada")
	assert_true(V2MagicRuntime.cast(archon, PORTAL, Vector2i(5, 2), grid))
	assert_eq(V2MagicRuntime.cooldown_remaining(archon, PORTAL), 4)

func test_six_manifestations_coexist_and_archon_has_its_own_school_slot():
	for pair in [["v2_manifestation_seraph", Vector2i(-5, 0)], ["v2_manifestation_archdemon", Vector2i(-3, 0)], ["v2_manifestation_lich_sovereign", Vector2i(-1, 0)], ["v2_manifestation_nature_avatar", Vector2i(1, 0)], [ARCHON, Vector2i(3, 0)], ["v2_manifestation_elemental_primordial", Vector2i(5, 0)]]:
		_unit(pair[0], human, pair[1])
	for school in ["sacred", "infernal", "necromancy", "druidism", SCHOOL, "elementalism"]:
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1, school)
	assert_false(V2ManifestationSystem.slot_available(human, SCHOOL))
	assert_true(V2LegendarySystem.legendary_slot_available(human), "slot militar independente")

func test_foundation_files_do_not_hardcode_arcanism_specific_ids():
	for path in ["res://scripts/core/V2PortalSystem.gd", "res://scripts/core/V2MagicRuntime.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["v2_spell_arcane_step", "v2_spell_silence", "v2_spell_dispel", "v2_spell_veil_portal", "v2_unit_arcanist", "veil_archon"]:
			assert_false(source.contains(forbidden), "%s contém %s" % [path, forbidden])
	assert_false(FileAccess.get_file_as_string("res://scripts/core/V2PortalSystem.gd").contains("compute_path("), "Portal não vira pathfinding")
