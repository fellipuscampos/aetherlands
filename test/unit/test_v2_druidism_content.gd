extends GutTest

## Aetherlands V2, Fase 20 — conteúdo canônico do Druidismo N1–N9 (V2MagicContent), Círculo, Bosque Ancestral, Druida,
## Avatar e os quatro registros de feitiço; totais atualizados pela Fase 23.

const IDS := ["v2_magic_school_druidism", "v2_building_druidic_circle", "v2_unit_druid", "v2_spell_grow_grove", "v2_spell_restore_terrain", "v2_spell_raise_ground", "v2_spell_awaken_forest", "v2_building_druidic_ritual", "v2_manifestation_nature_avatar"]
const NAMES := ["Escola Druídica", "Círculo Druídico", "Druida", "Brotar Bosque", "Restaurar Terreno", "Erguer Terreno", "Despertar a Mata", "Bosque Ancestral", "Avatar da Natureza"]
const TYPES := ["school", "school_building", "caster", "spell", "spell", "spell", "spell", "ritual_building", "grand_manifestation"]
const CIRCLE := "v2_building_druidic_circle"
const GROVE_RITUAL := "v2_building_druidic_ritual"
const DRUID := "v2_unit_druid"
const AVATAR := "v2_manifestation_nature_avatar"
const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL

var _players: Array[PlayerData] = []
var _original_human: PlayerData

func before_each():
	_original_human = GameManager.human_player

func after_each():
	GameManager.human_player = _original_human
	for player in _players:
		player.release_relations()
	_players.clear()

func _player() -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	return player

func test_nine_druidism_nodes_keep_structure_and_get_canonical_content():
	var nodes := V2ResearchDatabase.nodes_for_branch(MAGIC, "druidism")
	assert_eq(nodes.size(), 9)
	for i in 9:
		var node := nodes[i]
		assert_eq(node.id, "v2_magic_druidism_%d" % (i + 1))
		assert_eq(node.cost, V2ResearchDatabase.BRANCH_TIER_COSTS[i])
		assert_eq(node.prerequisites, ([] as Array[String]) if i == 0 else (["v2_magic_druidism_%d" % i] as Array[String]))
		assert_eq(node.display_name, NAMES[i])
		assert_eq(node.unlock_id, IDS[i])
		assert_eq(node.unlock_type, TYPES[i], node.id)
		assert_true(node.gameplay_connected, node.id)
		assert_false(node.is_placeholder)
		assert_false(V2ResearchDatabase.node_tooltip(node).contains(V2ResearchDatabase.GAMEPLAY_NOTICE), node.id)

func test_totals_are_55_connected_and_transcendence_stays_two_schools():
	var connected := 0
	for node in V2ResearchDatabase.nodes_for_tree(MAGIC):
		if not node.is_universal and node.gameplay_connected:
			connected += 1
	assert_eq(connected, 54)
	assert_eq(V2MagicContent.CONNECTED_UNLOCK_IDS.size(), 55)
	var transcendence := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	assert_true(transcendence.gameplay_connected)
	assert_eq(transcendence.requirement.branch_count, 2, "quatro completas não mudam para 4/4")
	var player := _player()
	for branch in ["sacred", "infernal", "necromancy", "druidism"]:
		player.v2_research.debug_complete_branch(MAGIC, branch)
	assert_eq(V2ResearchDatabase.capstone_progress(transcendence.id, player.v2_research.completed_ids), Vector2i(2, 2))

func test_ids_resolve_and_never_collide_with_v1():
	for id in IDS:
		assert_true(id in V2MagicContent.CONNECTED_UNLOCK_IDS, id)
	for id in [CIRCLE, GROVE_RITUAL]:
		assert_not_null(BuildingDatabase.get_building(id))
	for id in [DRUID, AVATAR]:
		assert_eq(UnitDatabase.create_unit(id).visual_kind, id)
	assert_eq(UnitDatabase.create_unit("druid").v2_magic_school, "")

func test_toasts_and_school_title():
	var player := _player()
	GameManager.human_player = player
	watch_signals(EventBus)
	for i in 4:
		assert_true(player.v2_research.complete_research("v2_magic_druidism_%d" % (i + 1)))
	var texts: Array[String] = []
	for i in get_signal_emit_count(EventBus, "notify"):
		texts.append(String(get_signal_parameters(EventBus, "notify", i)[0]))
	for text in ["Escola desbloqueada: Escola Druídica.", "Novo prédio mágico disponível: Círculo Druídico.", "Novo conjurador disponível: Druida.", "Novo feitiço disponível: Brotar Bosque."]:
		assert_true(text in texts, text)
	assert_eq(V2MagicContent.school_title("druidism"), "Escola Druídica")
	assert_false("researched_magic" in player, "Fase 25: estado V1 removido")

func test_buildings():
	var circle: BuildingData = BuildingDatabase.get_building(CIRCLE)
	assert_eq([circle.display_name, circle.production_cost, circle.gold_upkeep, circle.requires_building, circle.trains_unit], ["Círculo Druídico", 24.0, 1.0, "", DRUID])
	assert_eq(circle.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	var ritual: BuildingData = BuildingDatabase.get_building(GROVE_RITUAL)
	assert_eq([ritual.display_name, ritual.production_cost, ritual.gold_upkeep, ritual.requires_building, ritual.trains_unit], ["Bosque Ancestral", 60.0, 2.0, CIRCLE, AVATAR])
	assert_eq(ritual.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)

func test_druid_data():
	var data := UnitDatabase.create_unit(DRUID)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range, data.production_cost, data.supply_cost], ["Druida", 12.0, 0.0, 2.0, 2.0, 3, 24.0, 2])
	assert_false(data.can_basic_attack)
	assert_eq([data.v2_magic_school, data.spell_range_bonus], ["druidism", 0])
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_true(data.has_trait(UnitData.TRAIT_CASTER))
	for trait_id in [UnitData.TRAIT_UNDEAD, UnitData.TRAIT_RETINUE, UnitData.TRAIT_LEGENDARY, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_false(data.has_trait(trait_id), trait_id)
	assert_true(DRUID in UnitDatabase.PLAYER_TRAINABLE_KINDS)

func test_avatar_data():
	var data := UnitDatabase.create_unit(AVATAR)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range, data.production_cost, data.production_mana_cost, data.supply_cost], ["Avatar da Natureza", 42.0, 0.0, 8.0, 3.0, 4, 105.0, 65.0, 0])
	assert_false(data.can_basic_attack)
	assert_eq([data.v2_magic_school], ["druidism"])
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_eq([data.spell_range_bonus, data.spell_range_bonus_name], [1, "Domínio Natural"])
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(data.has_trait(trait_id), trait_id)
	for trait_id in [UnitData.TRAIT_LEGENDARY, UnitData.TRAIT_RETINUE, UnitData.TRAIT_UNDEAD]:
		assert_false(data.has_trait(trait_id), trait_id)
	assert_eq(V2ManifestationSystem.school_of_kind(AVATAR), "druidism")

func test_spell_records():
	var ids := V2SpellDatabase.for_school("druidism").map(func(spell): return spell.id)
	assert_eq(ids, ["v2_spell_grow_grove", "v2_spell_restore_terrain", "v2_spell_raise_ground", "v2_spell_awaken_forest"])
	var grow := V2SpellDatabase.get_spell("v2_spell_grow_grove")
	assert_eq([grow.target_mode, grow.mana_cost, grow.cast_range, grow.cooldown_turns, grow.terrain_modification_id, grow.splash_radius], [V2SpellData.TargetMode.EMPTY_TILE, 6.0, 3, 1, "v2_terrain_dense_grove", 0])
	var restore := V2SpellDatabase.get_spell("v2_spell_restore_terrain")
	assert_eq([restore.target_mode, restore.mana_cost, restore.cast_range, restore.cooldown_turns, restore.requires_existing_terrain_modification, restore.remove_terrain_modification], [V2SpellData.TargetMode.TILE, 5.0, 3, 1, true, true])
	var raise := V2SpellDatabase.get_spell("v2_spell_raise_ground")
	assert_eq([raise.target_mode, raise.mana_cost, raise.cast_range, raise.cooldown_turns, raise.terrain_modification_id, raise.splash_radius], [V2SpellData.TargetMode.EMPTY_TILE, 9.0, 3, 3, "v2_terrain_raised_ground", 0])
	var awaken := V2SpellDatabase.get_spell("v2_spell_awaken_forest")
	assert_eq([awaken.target_mode, awaken.mana_cost, awaken.cast_range, awaken.cooldown_turns, awaken.terrain_modification_id, awaken.splash_radius], [V2SpellData.TargetMode.EMPTY_TILE, 16.0, 4, 5, "v2_terrain_dense_grove", 1])
	for spell in V2SpellDatabase.for_school("druidism"):
		assert_false(spell.is_damage() or spell.is_heal() or spell.is_buff() or spell.is_summon(), spell.id)
		assert_true(spell.is_terrain_spell())

func test_effect_texts_are_built_from_data():
	var text := func(id: String) -> String: return V2SpellDatabase.effect_text(V2SpellDatabase.get_spell(id))
	assert_string_contains(text.call("v2_spell_grow_grove"), "Cria Bosque Denso: +1 custo de movimento e +20% Defesa física.")
	assert_string_contains(text.call("v2_spell_raise_ground"), "Cria Terreno Elevado: +2 custo de movimento e +35% Defesa física.")
	assert_string_contains(text.call("v2_spell_restore_terrain"), "Remove uma modificação física de terreno do tile")
	assert_string_contains(text.call("v2_spell_awaken_forest"), "Cria Bosque Denso no tile livre alvo")
	assert_string_contains(text.call("v2_spell_awaken_forest"), "tiles adjacentes elegíveis (raio 1)")
	var tip := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id(AVATAR)).replace("\n", " ")
	assert_string_contains(tip, "105 PP + 65 Mana")

func test_spell_data_defaults_are_inert():
	var spell := V2SpellData.new()
	assert_eq([spell.terrain_modification_id, spell.remove_terrain_modification, spell.requires_existing_terrain_modification], ["", false, false])
	assert_false(spell.is_terrain_spell())
	for school in ["sacred", "infernal", "necromancy"]:
		for other in V2SpellDatabase.for_school(school):
			assert_false(other.is_terrain_spell(), other.id)
	assert_eq(UnitData.new().spell_range_bonus, 0)
	for kind in ["v2_unit_sacred_cleric", "v2_unit_infernal_warlock", "v2_unit_necromancer", "v2_manifestation_seraph", "v2_manifestation_archdemon", "v2_manifestation_lich_sovereign"]:
		assert_eq(UnitDatabase.create_unit(kind).spell_range_bonus, 0, kind)
