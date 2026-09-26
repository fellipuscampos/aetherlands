extends GutTest

## Aetherlands V2, Fase 17 — conteúdo canônico da Magia V2 (V2MagicContent), aplicado sobre a estrutura das Fases 0-1:
## As seis Escolas e a Transcendência estão conectadas (Fase 23). Mesmo espírito de
## test_v2_doctrine_content.gd.

const SACRED_IDS := ["v2_magic_school_sacred", "v2_building_sacred_temple", "v2_unit_sacred_cleric", "v2_spell_restoring_light", "v2_spell_sacred_aegis", "v2_spell_healing_wave", "v2_spell_miracle", "v2_building_sacred_ritual", "v2_manifestation_seraph"]
const INFERNAL_IDS := ["v2_magic_school_infernal", "v2_building_infernal_sanctum", "v2_unit_infernal_warlock", "v2_spell_infernal_flame", "v2_spell_devouring_fire", "v2_spell_infernal_blast", "v2_spell_damnation", "v2_building_infernal_ritual", "v2_manifestation_archdemon"]
const SACRED_NAMES := ["Escola Sagrada", "Templo Sagrado", "Clérigo", "Luz Restauradora", "Égide Sagrada", "Onda de Cura", "Milagre", "Catedral Sagrada", "Serafim"]
const SACRED_TYPES := ["school", "school_building", "caster", "spell", "spell", "spell", "spell", "ritual_building", "grand_manifestation"]
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

func _sacred_nodes() -> Array[V2ResearchNode]:
	return V2ResearchDatabase.nodes_for_branch(MAGIC, "sacred")

func test_the_nine_sacred_nodes_keep_their_structural_ids_costs_and_prerequisites():
	var nodes := _sacred_nodes()
	assert_eq(nodes.size(), 9)
	for i in 9:
		var node := nodes[i]
		assert_eq(node.id, "v2_magic_sacred_%d" % (i + 1))
		assert_eq(node.tier, i + 1)
		assert_eq(node.cost, V2ResearchDatabase.BRANCH_TIER_COSTS[i], "custo placeholder inalterado")
		if i == 0:
			assert_eq(node.prerequisites, [] as Array[String])
		else:
			assert_eq(node.prerequisites, ["v2_magic_sacred_%d" % i] as Array[String])

func test_canonical_names_unlock_ids_and_types():
	var nodes := _sacred_nodes()
	for i in 9:
		assert_eq(nodes[i].display_name, SACRED_NAMES[i])
		assert_eq(nodes[i].unlock_id, SACRED_IDS[i])
		assert_eq(nodes[i].unlock_type, SACRED_TYPES[i], nodes[i].id)
		assert_false(nodes[i].is_placeholder)
		assert_ne(nodes[i].intent, "", "função pretendida")

func test_six_schools_and_transcendence_are_connected():
	var connected := 0
	for node in V2ResearchDatabase.nodes_for_tree(MAGIC):
		if node.is_universal:
			continue
		if node.branch in ["sacred", "infernal", "necromancy", "druidism", "arcanism", "elementalism"]:
			assert_true(node.gameplay_connected, node.id)
			connected += 1
		else:
			assert_false(node.gameplay_connected, node.id)
			assert_true(node.is_placeholder, node.id)
	assert_eq(connected, 54)
	assert_eq(V2MagicContent.entries_for("infernal").size(), 9)
	assert_eq(V2MagicContent.entries_for("necromancy").size(), 9)
	assert_eq(V2MagicContent.entries_for("druidism").size(), 9)
	assert_eq(V2MagicContent.entries_for("arcanism").size(), 9)
	assert_eq(V2MagicContent.entries_for("elementalism").size(), 9)

func test_transcendence_is_the_connected_victory_capstone():
	var node := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	assert_true(node.gameplay_connected)
	assert_eq(node.unlock_id, V2MagicContent.TRANSCENDENCE_UNLOCK_ID)
	assert_eq(node.requirement.branch_count, 2, "estrutura inalterada: duas Escolas")

func test_connected_ids_are_exactly_the_fifty_five_and_unique_and_never_collide_with_v1():
	assert_eq(V2MagicContent.CONNECTED_UNLOCK_IDS.size(), 55)
	var seen := {}
	for id in V2MagicContent.CONNECTED_UNLOCK_IDS:
		assert_false(seen.has(id), "único: %s" % id)
		seen[id] = true
		assert_true(id.begins_with("v2_"))
		assert_false(V2DoctrineContent.CONNECTED_UNLOCK_IDS.has(id))
	for id in ["v2_building_sacred_temple", "v2_building_sacred_ritual"]:
		assert_not_null(BuildingDatabase.get_building(id))
	for id in ["v2_unit_sacred_cleric", "v2_manifestation_seraph"]:
		assert_eq(UnitDatabase.create_unit(id).visual_kind, id)
	for id in ["v2_spell_restoring_light", "v2_spell_sacred_aegis", "v2_spell_healing_wave", "v2_spell_miracle"]:
		assert_not_null(V2SpellDatabase.get_spell(id))
	for id in ["v2_building_infernal_sanctum", "v2_building_infernal_ritual"]:
		assert_not_null(BuildingDatabase.get_building(id))
	for id in ["v2_unit_infernal_warlock", "v2_manifestation_archdemon"]:
		assert_eq(UnitDatabase.create_unit(id).visual_kind, id)
	for id in ["v2_spell_infernal_flame", "v2_spell_devouring_fire", "v2_spell_infernal_blast", "v2_spell_damnation"]:
		assert_not_null(V2SpellDatabase.get_spell(id))

func test_v2_school_id_is_distinct_from_the_v1_school():
	assert_true(V2MagicContent.is_v2_school("sacred"))
	assert_true(V2MagicContent.is_v2_school("infernal"), "a colisão literal é separada pelo campo, não pelo valor")
	assert_false(V2MagicContent.is_v2_school("sagrada"), "V1")

func test_tooltips_explain_real_effects_never_the_not_connected_notice():
	for node in _sacred_nodes():
		var tooltip := V2ResearchDatabase.node_tooltip(node).replace("\n", " ")
		assert_false(tooltip.contains(V2ResearchDatabase.GAMEPLAY_NOTICE), node.id)
	var light := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id("v2_spell_restoring_light")).replace("\n", " ")
	assert_string_contains(light, "Gasta 4 Mana para curar 8 de Vida de uma unidade própria a até 2 tiles.")
	var aegis := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id("v2_spell_sacred_aegis")).replace("\n", " ")
	assert_string_contains(aegis, "Gasta 6 Mana para conceder +35% Defesa")
	assert_string_contains(aegis, "até o início do próximo turno do dono")
	var wave := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id("v2_spell_healing_wave")).replace("\n", " ")
	assert_string_contains(wave, "Gasta 9 Mana para curar 6 de Vida do alvo")
	assert_string_contains(wave, "unidades próprias adjacentes")
	var miracle := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id("v2_spell_miracle")).replace("\n", " ")
	assert_string_contains(miracle, "Gasta 16 Mana para restaurar uma unidade própria")
	assert_string_contains(miracle, "Recarga 5.")
	var seraph := V2ResearchDatabase.node_tooltip(V2ResearchDatabase.node_for_unlock_id("v2_manifestation_seraph")).replace("\n", " ")
	assert_string_contains(seraph, "100 PP + 60 Mana")

func test_toasts_are_generic_by_type():
	var player := _player()
	GameManager.human_player = player
	var expected := [
		"Escola desbloqueada: Escola Sagrada.",
		"Novo prédio mágico disponível: Templo Sagrado.",
		"Novo conjurador disponível: Clérigo.",
		"Novo feitiço disponível: Luz Restauradora.",
	]
	watch_signals(EventBus)
	for i in 4:
		assert_true(player.v2_research.complete_research("v2_magic_sacred_%d" % (i + 1)))
	var texts: Array[String] = []
	for i in get_signal_emit_count(EventBus, "notify"):
		texts.append(String(get_signal_parameters(EventBus, "notify", i)[0]))
	for text in expected:
		assert_true(text in texts, text)
	assert_eq(V2UnlockSystem.announcement_text("ritual_building", "Catedral Sagrada"), "Nova estrutura ritual disponível: Catedral Sagrada.")
	assert_eq(V2UnlockSystem.announcement_text("grand_manifestation", "Serafim"), "Grande Manifestação disponível: Serafim.")

func test_n1_is_a_milestone_without_passive_bonus():
	var player := _player()
	var mana_before := V2EconomyRuntime.player_mana_income(player)
	player.v2_research.complete_research("v2_magic_sacred_1")
	assert_eq(V2EconomyRuntime.player_mana_income(player), mana_before)
	assert_true(player.has_unlocked("v2_magic_school_sacred"))
	assert_false(player.has_unlocked("v2_building_sacred_temple"), "N1 sozinho não libera o Templo")

func test_research_never_writes_v1_magic_state():
	var player := _player()
	for i in 9:
		player.v2_research.complete_research("v2_magic_sacred_%d" % (i + 1))
	assert_false("researched_magic" in player, "Fase 25: estado V1 removido")
	assert_false("current_research" in player, "Fase 25: estado V1 removido")

func test_unlock_types_have_labels():
	for type in ["school", "school_building", "caster", "spell", "ritual_building", "grand_manifestation"]:
		assert_true(type in V2UnlockSystem.CONNECTED_TYPES, type)
		assert_ne(V2ResearchDatabase.unlock_type_label(type), type, "rótulo em português: %s" % type)

# --- §154/§162 Anti-hardcode: as fundações não conhecem a Escola Sagrada ---------------------------------------

func _code_without_comments(path: String) -> String:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code := line.split("##")[0].split("#")[0]
		lines.append(code)
	return "\n".join(lines)

func test_foundations_never_name_a_concrete_spell_unit_or_school():
	var forbidden: Array = SACRED_IDS.duplicate()
	forbidden.append_array(["\"sacred\"", "Sagrada", "Serafim", "Clérigo"])
	for path in ["res://scripts/core/V2MagicRuntime.gd", "res://scripts/data/V2SpellData.gd", "res://scripts/core/V2ManifestationSystem.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/core/V2UnlockSystem.gd", "res://scripts/core/V2OwnerTurnEffect.gd"]:
		var code := _code_without_comments(path)
		for word in forbidden:
			assert_false(code.contains(word), "%s cita %s" % [path, word])

func test_no_parallel_sacred_architecture_exists():
	for path in ["res://scripts/core/SacredRuntime.gd", "res://scripts/core/SacredCombatResolver.gd", "res://scripts/core/SacredTargetingSystem.gd", "res://scripts/core/V2SeraphSystem.gd", "res://scripts/core/SacredSpellRuntime.gd"]:
		assert_false(FileAccess.file_exists(path), path)
