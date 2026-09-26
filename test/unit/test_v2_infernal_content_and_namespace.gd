extends GutTest

## Fase 18 — conteúdo N1–N9, colisão real do id "infernal", prédios,
## unidades, slots por Escola e Transcendência estrutural/inativa.

const MAGIC := V2ResearchNode.TreeType.MAGIC_SCHOOL
const SANCTUM := "v2_building_infernal_sanctum"
const RITUAL := "v2_building_infernal_ritual"
const WARLOCK := "v2_unit_infernal_warlock"
const ARCHDEMON := "v2_manifestation_archdemon"
const SERAPH := "v2_manifestation_seraph"
const IDS := ["v2_magic_school_infernal", SANCTUM, WARLOCK, "v2_spell_infernal_flame", "v2_spell_devouring_fire", "v2_spell_infernal_blast", "v2_spell_damnation", RITUAL, ARCHDEMON]
const NAMES := ["Escola Infernal", "Santuário Infernal", "Bruxo Infernal", "Chama Infernal", "Fogo Voraz", "Explosão Infernal", "Condenação", "Círculo Profano", "Arquidemônio"]
const TYPES := ["school", "school_building", "caster", "spell", "spell", "spell", "spell", "ritual_building", "grand_manifestation"]

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _players: Array[PlayerData] = []
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	grid = HexGrid.new()
	grid._ready()
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	human.gold = 500.0
	human.mana = 200.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(branch: String, tier: int = 9) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not human.v2_research.is_completed(id):
			assert_true(human.v2_research.complete_research(id))

func _city(coord: Vector2i = Vector2i.ZERO) -> City:
	var city := grid.found_city(coord, human, "Cidade %s" % str(coord), true)
	city.city_level = 3
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func test_infernal_n1_to_n9_have_canonical_ids_names_types_and_connection():
	var nodes := V2ResearchDatabase.nodes_for_branch(MAGIC, "infernal")
	assert_eq(nodes.size(), 9)
	for i in 9:
		assert_eq(nodes[i].id, "v2_magic_infernal_%d" % (i + 1))
		assert_eq(nodes[i].tier, i + 1)
		assert_eq(nodes[i].display_name, NAMES[i])
		assert_eq(nodes[i].unlock_id, IDS[i])
		assert_eq(nodes[i].unlock_type, TYPES[i])
		assert_true(nodes[i].gameplay_connected)
		assert_false(nodes[i].is_placeholder)

func test_magic_connection_totals_are_six_schools_and_no_normal_node_inert():
	var totals := {"sacred": 0, "infernal": 0, "necromancy": 0, "druidism": 0, "arcanism": 0, "elementalism": 0, "inert": 0}
	for node in V2ResearchDatabase.nodes_for_tree(MAGIC):
		if node.is_universal:
			continue
		if node.gameplay_connected:
			totals[node.branch] += 1
		else:
			totals.inert += 1
	assert_eq(totals, {"sacred": 9, "infernal": 9, "necromancy": 9, "druidism": 9, "arcanism": 9, "elementalism": 9, "inert": 0})
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)

func test_infernal_building_records_are_normal_unique_buildings_without_mana_income():
	var sanctum := BuildingDatabase.get_building(SANCTUM)
	var ritual := BuildingDatabase.get_building(RITUAL)
	assert_eq([sanctum.display_name, sanctum.production_cost, sanctum.gold_upkeep, sanctum.copy_limit_mode], ["Santuário Infernal", 24.0, 1.0, BuildingData.CopyLimitMode.UNIQUE])
	assert_eq([sanctum.requires_building, sanctum.trains_unit], ["", WARLOCK])
	assert_eq([ritual.display_name, ritual.production_cost, ritual.gold_upkeep, ritual.copy_limit_mode], ["Círculo Profano", 60.0, 2.0, BuildingData.CopyLimitMode.UNIQUE])
	assert_eq([ritual.requires_building, ritual.trains_unit], [SANCTUM, ARCHDEMON])

func test_sanctum_and_warlock_use_normal_research_building_supply_and_deficit_gates():
	var city := _city()
	_learn("infernal", 1)
	assert_false(city.can_build(SANCTUM))
	_learn("infernal", 2)
	assert_true(city.can_build(SANCTUM))
	city.buildings[SANCTUM] = true
	assert_false(city.can_train(WARLOCK), "sem N3")
	_learn("infernal", 3)
	assert_true(city.can_train(WARLOCK))
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human))
	assert_false(city.can_train(WARLOCK), "Déficit bloqueia unidade supply2")

func test_warlock_data_traits_and_movement():
	var data := UnitDatabase.create_unit(WARLOCK)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range], ["Bruxo Infernal", 10.0, 0.0, 1.5, 2.0, 3])
	assert_eq([data.production_cost, data.supply_cost, data.attack_range], [24.0, 2, 0])
	assert_eq([data.v2_magic_school, data.spell_damage_multiplier], ["infernal", 1.0])
	assert_false(data.can_basic_attack)
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_true(data.has_trait(UnitData.TRAIT_CASTER))
	assert_true(WARLOCK in UnitDatabase.PLAYER_TRAINABLE_KINDS)

func test_ritual_building_needs_n8_and_the_sanctum_in_the_same_city():
	var city := _city()
	_learn("infernal", 7)
	city.buildings[SANCTUM] = true
	assert_false(city.can_build(RITUAL), "sem N8")
	_learn("infernal", 8)
	assert_true(city.can_build(RITUAL))
	city.buildings.erase(SANCTUM)
	assert_false(city.can_build(RITUAL), "exige o Santuário na mesma cidade")

func test_archdemon_data_passive_and_traits():
	var data := UnitDatabase.create_unit(ARCHDEMON)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range], ["Arquidemônio", 36.0, 0.0, 6.0, 3.0, 4])
	assert_eq([data.production_cost, data.production_mana_cost, data.supply_cost], [105.0, 70.0, 0])
	assert_eq([data.v2_magic_school, data.spell_damage_multiplier, data.spell_damage_multiplier_name], ["infernal", 1.25, "Chama Primordial"])
	assert_false(data.can_basic_attack)
	assert_eq(data.movement_profile, UnitData.MovementProfile.FLYING)
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_FLYING, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(data.has_trait(trait_id), trait_id)
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(V2LegendarySystem.is_legendary_kind(ARCHDEMON))
	assert_string_contains("\n".join(TileInspector.unit_traits(_unit(ARCHDEMON, human, Vector2i.ZERO))), "Chama Primordial")

func test_real_seraph_and_archdemon_use_independent_school_slots_but_two_archdemons_do_not():
	_learn("sacred", 9)
	_learn("infernal", 9)
	var infernal_city := _city(Vector2i(-4, 0))
	infernal_city.buildings[SANCTUM] = true
	infernal_city.buildings[RITUAL] = true
	_unit(SERAPH, human, Vector2i(3, 0))
	assert_true(infernal_city.can_train(ARCHDEMON), "Serafim não ocupa slot Infernal")
	var archdemon := _unit(ARCHDEMON, human, Vector2i(4, 0))
	assert_false(infernal_city.can_train(ARCHDEMON), "segundo Arquidemônio bloqueado")
	assert_eq(V2ManifestationSystem.active_units(human, "sacred").size(), 1)
	assert_eq(V2ManifestationSystem.active_units(human, "infernal").size(), 1)
	grid.remove_unit(archdemon)
	assert_true(infernal_city.can_train(ARCHDEMON), "morte libera slot derivado")

func test_archdemon_production_requires_seventy_mana_without_charging_at_start():
	_learn("infernal", 9)
	var city := _city()
	city.buildings[SANCTUM] = true
	city.buildings[RITUAL] = true
	human.mana = 69.0
	assert_false(city.can_train(ARCHDEMON))
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, ARCHDEMON), "Requer 70 Mana.")
	human.mana = 70.0
	assert_true(city.can_train(ARCHDEMON))
	city.set_production(ARCHDEMON)
	assert_eq(human.mana, 70.0)
	assert_false(V2ManifestationSystem.slot_available(human, "infernal", null), "produção reserva o slot")

func test_archdemon_completion_waits_without_losing_pp_then_finishes_once_mana_returns():
	_learn("infernal", 9)
	var city := _city()
	city.buildings[SANCTUM] = true
	city.buildings[RITUAL] = true
	human.mana = 70.0
	city.set_production(ARCHDEMON)
	human.mana = 10.0
	city.stored_production = 105.0
	var waiting := city.process_turn(grid)
	assert_eq(waiting.spawn_unit_kind, "")
	assert_eq(city.production_item, ARCHDEMON)
	assert_eq(city.stored_production, 105.0)
	assert_eq(city.production_waiting_for_mana(), 70)
	human.mana = 80.0
	var ready := city.process_turn(grid)
	assert_eq(ready.spawn_unit_kind, ARCHDEMON)
	assert_eq(city.production_item, "")
	assert_eq(human.mana, 80.0, "City devolve o kind; a cobranção única pertence ao GameManager")

func test_sacred_n9_plus_infernal_n9_unlocks_connected_transcendence_without_instant_victory():
	_learn("sacred", 9)
	_learn("infernal", 9)
	assert_eq(V2ResearchDatabase.capstone_progress("v2_transcendence", human.v2_research.completed_ids), Vector2i(2, 2))
	assert_true(human.v2_research.is_available("v2_transcendence"))
	assert_true(human.v2_research.complete_research("v2_transcendence"))
	var node := V2ResearchDatabase.get_node("v2_transcendence")
	assert_true(node.gameplay_connected)
	assert_eq(node.unlock_id, V2TranscendenceSystem.ACCESS_ID)
	assert_null(BuildingDatabase.get_building("v2_building_final_ritual"))
	assert_true(FileAccess.get_file_as_string("res://scripts/core/V2VictoryConditions.gd").contains("v2_transcendence"))

func test_foundations_have_no_infernal_specific_runtime_or_hardcoded_logic():
	for path in ["res://scripts/core/InfernalRuntime.gd", "res://scripts/core/V2InfernalRuntime.gd", "res://scripts/data/V2InfernalContent.gd"]:
		assert_false(FileAccess.file_exists(path), path)
	for path in ["res://scripts/core/V2MagicRuntime.gd", "res://scripts/core/V2ManifestationSystem.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/autoload/SelectionManager.gd"]:
		var code_lines: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			code_lines.append(line.split("#")[0])
		var code := "\n".join(code_lines)
		for forbidden in ["infernal", "Arquidemônio", "Bruxo Infernal", "v2_spell_infernal"]:
			assert_false(code.contains(forbidden), "%s cita %s" % [path, forbidden])
