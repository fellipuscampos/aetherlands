extends GutTest

## Aetherlands V2, Fase 19 — conteúdo canônico da Necromancia N1–N9 (V2MagicContent), prédios, Necromante, as duas
## Hostes, o Lich e os quatro registros de feitiço; totais históricos da árvore e a
## varredura anti-hardcode das fundações genéricas.

const IDS := ["v2_magic_school_necromancy", "v2_building_necromancy_ossuary", "v2_unit_necromancer", "v2_spell_raise_dead", "v2_spell_mend_undead", "v2_spell_macabre_command", "v2_spell_raise_legion", "v2_building_necromancy_ritual", "v2_manifestation_lich_sovereign"]
const NAMES := ["Escola da Necromancia", "Ossuário", "Necromante", "Erguer Mortos", "Recompor Ossos", "Comando Macabro", "Erguer Legião", "Mausoléu Negro", "Lich Soberano"]
const TYPES := ["school", "school_building", "caster", "spell", "spell", "spell", "spell", "ritual_building", "grand_manifestation"]
const OSSUARY := "v2_building_necromancy_ossuary"
const MAUSOLEUM := "v2_building_necromancy_ritual"
const NECROMANCER := "v2_unit_necromancer"
const SKELETON := "v2_unit_skeleton_host"
const MACABRE := "v2_unit_macabre_host"
const LICH := "v2_manifestation_lich_sovereign"
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

# --- Árvore -------------------------------------------------------------------------------------------------

func test_nine_necromancy_nodes_keep_structure_and_get_canonical_content():
	var nodes := V2ResearchDatabase.nodes_for_branch(MAGIC, "necromancy")
	assert_eq(nodes.size(), 9)
	for i in 9:
		var node := nodes[i]
		assert_eq(node.id, "v2_magic_necromancy_%d" % (i + 1))
		assert_eq(node.tier, i + 1)
		assert_eq(node.cost, V2ResearchDatabase.BRANCH_TIER_COSTS[i])
		assert_eq(node.prerequisites, ([] as Array[String]) if i == 0 else (["v2_magic_necromancy_%d" % i] as Array[String]))
		assert_eq(node.display_name, NAMES[i])
		assert_eq(node.unlock_id, IDS[i])
		assert_eq(node.unlock_type, TYPES[i], node.id)
		assert_true(node.gameplay_connected, node.id)
		assert_false(node.is_placeholder)
		assert_ne(node.intent, "")

func test_totals_are_55_connected_including_transcendence():
	var totals := {}
	for node in V2ResearchDatabase.nodes_for_tree(MAGIC):
		if node.is_universal:
			continue
		var key: String = node.branch if node.gameplay_connected else "inert"
		totals[key] = totals.get(key, 0) + 1
	assert_eq(totals, {"sacred": 9, "infernal": 9, "necromancy": 9, "druidism": 9, "arcanism": 9, "elementalism": 9})
	var transcendence := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	assert_true(transcendence.gameplay_connected)
	assert_eq(transcendence.requirement.branch_count, 2, "três Escolas completas não mudam o requisito")

func test_connected_ids_resolve_to_real_objects_and_never_collide_with_v1():
	for id in IDS:
		assert_true(id in V2MagicContent.CONNECTED_UNLOCK_IDS, id)
	for id in [OSSUARY, MAUSOLEUM]:
		assert_not_null(BuildingDatabase.get_building(id))
	for id in [NECROMANCER, LICH, SKELETON, MACABRE]:
		assert_eq(UnitDatabase.create_unit(id).visual_kind, id, "SaveManager recria pelo visual_kind")
	for id in ["v2_spell_raise_dead", "v2_spell_mend_undead", "v2_spell_macabre_command", "v2_spell_raise_legion"]:
		assert_not_null(V2SpellDatabase.get_spell(id))
	assert_eq(UnitDatabase.create_unit("necromancer").v2_magic_school, "")

func test_tooltips_toasts_and_n1_milestone():
	var player := _player()
	GameManager.human_player = player
	watch_signals(EventBus)
	for i in 4:
		assert_true(player.v2_research.complete_research("v2_magic_necromancy_%d" % (i + 1)))
	var texts: Array[String] = []
	for i in get_signal_emit_count(EventBus, "notify"):
		texts.append(String(get_signal_parameters(EventBus, "notify", i)[0]))
	for text in ["Escola desbloqueada: Escola da Necromancia.", "Novo prédio mágico disponível: Ossuário.", "Novo conjurador disponível: Necromante.", "Novo feitiço disponível: Erguer Mortos."]:
		assert_true(text in texts, text)
	for node in V2ResearchDatabase.nodes_for_branch(MAGIC, "necromancy"):
		assert_false(V2ResearchDatabase.node_tooltip(node).contains(V2ResearchDatabase.GAMEPLAY_NOTICE), node.id)
	var tip := func(id: String) -> String: return V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id(id)).replace("\n", " ")
	assert_string_contains(tip.call("v2_spell_raise_dead"), "Invoca uma Hoste Esquelética (Comando 1).")
	assert_string_contains(tip.call("v2_spell_raise_legion"), "Invoca uma Hoste Macabra (Comando 2).")
	assert_string_contains(tip.call("v2_spell_mend_undead"), "curar 8 de Vida de uma unidade própria morta-viva")
	assert_string_contains(tip.call("v2_spell_macabre_command"), "+40% Ataque a uma Hoste própria")
	assert_string_contains(tip.call(NECROMANCER), "+2 de capacidade de Comando Necromântico")
	assert_string_contains(tip.call(LICH), "100 PP + 65 Mana")
	assert_string_contains(tip.call(LICH), "Soberania dos Mortos")
	var fresh := _player()
	fresh.v2_research.complete_research("v2_magic_necromancy_1")
	assert_true(fresh.has_unlocked("v2_magic_school_necromancy"))
	assert_false(fresh.has_unlocked(OSSUARY), "N1 sozinho não libera o Ossuário")
	assert_false("researched_magic" in fresh, "Fase 25: estado V1 removido")

# --- Prédios --------------------------------------------------------------------------------------------------

func test_ossuary_and_mausoleum_data():
	var ossuary: BuildingData = BuildingDatabase.get_building(OSSUARY)
	assert_eq([ossuary.display_name, ossuary.production_cost, ossuary.gold_upkeep, ossuary.requires_building, ossuary.trains_unit], ["Ossuário", 24.0, 1.0, "", NECROMANCER])
	assert_eq(ossuary.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	var mausoleum: BuildingData = BuildingDatabase.get_building(MAUSOLEUM)
	assert_eq([mausoleum.display_name, mausoleum.production_cost, mausoleum.gold_upkeep, mausoleum.requires_building, mausoleum.trains_unit], ["Mausoléu Negro", 60.0, 2.0, OSSUARY, LICH])
	assert_eq(mausoleum.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	assert_eq(BuildingDatabase.building_that_trains(NECROMANCER).id, OSSUARY)
	assert_eq(BuildingDatabase.building_that_trains(LICH).id, MAUSOLEUM)

# --- Unidades ---------------------------------------------------------------------------------------------------

func test_necromancer_data():
	var data := UnitDatabase.create_unit(NECROMANCER)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range, data.production_cost, data.supply_cost], ["Necromante", 10.0, 0.0, 1.5, 2.0, 3, 24.0, 2])
	assert_false(data.can_basic_attack)
	assert_eq([data.v2_magic_school], ["necromancy"])
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_eq(data.retinue_command_capacity, 2)
	assert_eq(data.retinue_command_cost, 0)
	assert_true(data.has_trait(UnitData.TRAIT_CASTER), "caster vem de v2_magic_school")
	for trait_id in [UnitData.TRAIT_UNDEAD, UnitData.TRAIT_RETINUE, UnitData.TRAIT_LEGENDARY, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_false(data.has_trait(trait_id), trait_id)
	assert_true(NECROMANCER in UnitDatabase.PLAYER_TRAINABLE_KINDS)

func test_host_data_supply_traits_and_not_trainable():
	var skeleton := UnitDatabase.create_unit(SKELETON)
	assert_eq([skeleton.unit_name, skeleton.max_hp, skeleton.attack, skeleton.defense, skeleton.movement_points, skeleton.vision_range, skeleton.attack_range], ["Hoste Esquelética", 18.0, 4.0, 3.0, 2.0, 2, 1])
	assert_eq([skeleton.retinue_school, skeleton.retinue_command_cost], ["necromancy", 1])
	var macabre := UnitDatabase.create_unit(MACABRE)
	assert_eq([macabre.unit_name, macabre.max_hp, macabre.attack, macabre.defense, macabre.movement_points, macabre.vision_range, macabre.attack_range], ["Hoste Macabra", 30.0, 7.0, 5.0, 2.0, 3, 1])
	assert_eq([macabre.retinue_school, macabre.retinue_command_cost], ["necromancy", 2])
	for data in [skeleton, macabre]:
		assert_eq(data.supply_cost, 0)
		assert_true(data.can_basic_attack)
		assert_true(data.has_trait(UnitData.TRAIT_UNDEAD))
		assert_true(data.has_trait(UnitData.TRAIT_RETINUE))
		assert_false(data.has_trait(UnitData.TRAIT_CASTER), "Hoste não é conjuradora")
		assert_false(data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
		assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY))
		assert_eq(data.v2_magic_school, "")
		assert_eq(data.retinue_command_capacity, 0)
		assert_gt(data.model_formation_count, 1, "um token, vários corpos (só visual)")
	for kind in [SKELETON, MACABRE]:
		assert_false(kind in UnitDatabase.PLAYER_TRAINABLE_KINDS, "só nasce por feitiço")
		assert_null(BuildingDatabase.building_that_trains(kind), "nenhum prédio treina Hoste")

func test_hosts_can_never_be_trained_even_with_everything_researched():
	var player := _player()
	player.v2_research.debug_complete_branch(MAGIC, "necromancy")
	var city := City.new()
	city.owner_player = player
	city.buildings[OSSUARY] = true
	city.buildings[MAUSOLEUM] = true
	assert_false(city.can_train(SKELETON))
	assert_false(city.can_train(MACABRE))
	city.free()

func test_lich_data():
	var data := UnitDatabase.create_unit(LICH)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range, data.production_cost, data.production_mana_cost, data.supply_cost], ["Lich Soberano", 34.0, 0.0, 6.0, 2.0, 4, 100.0, 65.0, 0])
	assert_false(data.can_basic_attack)
	assert_eq([data.v2_magic_school], ["necromancy"])
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_eq(data.retinue_command_capacity, 4)
	assert_eq(data.retinue_command_capacity_name, "Soberania dos Mortos")
	assert_eq(data.retinue_command_cost, 0, "cria capacidade, não a consome")
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_UNDEAD, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(data.has_trait(trait_id), trait_id)
	for trait_id in [UnitData.TRAIT_RETINUE, UnitData.TRAIT_LEGENDARY]:
		assert_false(data.has_trait(trait_id), trait_id)
	assert_true(V2ManifestationSystem.is_manifestation_kind(LICH))
	assert_eq(V2ManifestationSystem.school_of_kind(LICH), "necromancy")

func test_unit_data_defaults_are_inert():
	var data := UnitData.new()
	assert_eq([data.retinue_school, data.retinue_command_cost, data.retinue_command_capacity, data.model_formation_count], ["", 0, 0, 1])
	assert_false(data.is_retinue())
	assert_false(data.is_retinue_commander())
	for kind in ["warrior", "v2_unit_guardian", "v2_unit_sacred_cleric", "v2_unit_infernal_warlock", "v2_manifestation_seraph", "v2_legendary_guardian_champion", "v2_unit_builder", "settler", "necromancer"]:
		var existing := UnitDatabase.create_unit(kind)
		assert_false(existing.is_retinue(), kind)
		assert_false(existing.is_retinue_commander(), kind)
		assert_false(existing.has_trait(UnitData.TRAIT_UNDEAD), kind)

# --- Feitiços ---------------------------------------------------------------------------------------------------

func test_spell_records_and_order():
	var ids := V2SpellDatabase.for_school("necromancy").map(func(spell): return spell.id)
	assert_eq(ids, ["v2_spell_raise_dead", "v2_spell_mend_undead", "v2_spell_macabre_command", "v2_spell_raise_legion"])
	var raise := V2SpellDatabase.get_spell("v2_spell_raise_dead")
	assert_eq([raise.target_mode, raise.mana_cost, raise.cast_range, raise.cooldown_turns, raise.summon_unit_id], [V2SpellData.TargetMode.EMPTY_TILE, 7.0, 2, 2, SKELETON])
	var mend := V2SpellDatabase.get_spell("v2_spell_mend_undead")
	assert_eq([mend.target_mode, mend.mana_cost, mend.cast_range, mend.cooldown_turns, mend.heal_amount, mend.required_target_trait], [V2SpellData.TargetMode.OWN_UNIT, 6.0, 3, 1, 8.0, UnitData.TRAIT_UNDEAD])
	var macabre := V2SpellDatabase.get_spell("v2_spell_macabre_command")
	assert_eq([macabre.target_mode, macabre.mana_cost, macabre.cast_range, macabre.cooldown_turns, macabre.attack_bonus, macabre.duration, macabre.required_target_trait], [V2SpellData.TargetMode.OWN_UNIT, 7.0, 3, 2, 0.4, 1, UnitData.TRAIT_RETINUE])
	var legion := V2SpellDatabase.get_spell("v2_spell_raise_legion")
	assert_eq([legion.target_mode, legion.mana_cost, legion.cast_range, legion.cooldown_turns, legion.summon_unit_id], [V2SpellData.TargetMode.EMPTY_TILE, 15.0, 2, 4, MACABRE])
	assert_true(macabre in V2SpellDatabase.offensive_spells())
	assert_false(macabre in V2SpellDatabase.defensive_spells())
	assert_true(macabre in V2SpellDatabase.status_spells())

func test_necromancy_never_deals_magic_damage():
	for spell in V2SpellDatabase.for_school("necromancy"):
		assert_eq(spell.damage_amount, 0.0, spell.id)
		assert_false(spell.is_damage(), spell.id)

func test_spell_data_defaults_are_inert():
	var spell := V2SpellData.new()
	assert_eq([spell.required_target_trait, spell.summon_unit_id, spell.attack_bonus], ["", "", 0.0])
	assert_false(spell.is_summon())
	for sacred in V2SpellDatabase.for_school("sacred"):
		assert_eq(sacred.required_target_trait, "", "Sagrada cura qualquer unidade própria")

# --- Anti-hardcode (§163) ------------------------------------------------------------------------------------------

func _code_without_comments(path: String) -> String:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		lines.append(line.split("##")[0].split("#")[0])
	return "\n".join(lines)

func test_foundations_never_name_necromancy_content():
	var forbidden := ["skeleton_host", "macabre_host", "v2_unit_necromancer", "lich_sovereign", "\"necromancy\"", "raise_dead", "mend_undead", "macabre_command", "raise_legion", "Necromante", "Lich Soberano"]
	for path in ["res://scripts/core/V2RetinueSystem.gd", "res://scripts/core/V2MagicRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/units/Unit.gd", "res://scripts/ui/HUD.gd", "res://scripts/data/V2SpellData.gd", "res://scripts/core/V2ManifestationSystem.gd", "res://scripts/world/HexGrid.gd"]:
		var code := _code_without_comments(path)
		for word in forbidden:
			assert_false(code.contains(word), "%s cita %s" % [path, word])

func test_no_parallel_necromancy_architecture_exists():
	for path in ["res://scripts/core/V2NecromancyContent.gd", "res://scripts/data/V2NecromancyContent.gd", "res://scripts/core/NecromancyRuntime.gd", "res://scripts/core/NecromancyArmySystem.gd", "res://scripts/core/SkeletonSystem.gd", "res://scripts/core/UndeadController.gd", "res://scripts/core/LichSystem.gd", "res://scripts/core/UndeadCombatResolver.gd"]:
		assert_false(FileAccess.file_exists(path), path)
