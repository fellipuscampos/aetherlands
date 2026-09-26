extends GutTest

## Aetherlands V2, Fase 19 — Mausoléu Negro, Lich Soberano (terceira Grande Manifestação), Soberania dos Mortos por dado,
## três Manifestações de Escolas diferentes coexistindo, a bateria de Mana de produção (65) e a Transcendência sem Ritual
## mesmo com três Escolas completas.

const SAVE_PATH := "user://test_v2_lich_manifestation.json"
const OSSUARY := "v2_building_necromancy_ossuary"
const MAUSOLEUM := "v2_building_necromancy_ritual"
const NECROMANCER := "v2_unit_necromancer"
const LICH := "v2_manifestation_lich_sovereign"
const SKELETON := "v2_unit_skeleton_host"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"
const SCHOOL := "necromancy"
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
var _original_state

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
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
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 30
	human.gold = 500.0
	human.mana = 200.0

func after_each():
	SelectionManager.reset()
	SaveManager.delete_save(SAVE_PATH)
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	GameManager.state = _original_state
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

func _learn(player: PlayerData, branch: String = "necromancy", tier: int = 9) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_%s_%d" % [branch, i]):
			assert_true(player.v2_research.complete_research("v2_magic_%s_%d" % [branch, i]))

func _ritual_city(owner: PlayerData, coord: Vector2i) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = 3
	city.buildings[OSSUARY] = true
	city.buildings[MAUSOLEUM] = true
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

## Mesmo caminho do GameManager (process_turn + nascimento com a mesma ordem de checagens).
func _complete(city: City) -> void:
	city.stored_production = max(city.stored_production, city.production_cost())
	var result := city.process_turn(grid)
	if result.spawn_unit_kind == "":
		return
	var kind: String = result.spawn_unit_kind
	var player := city.owner_player
	var cost := UnitDatabase.create_unit(kind).production_mana_cost
	if not V2ManifestationSystem.spawn_allowed(player, kind):
		V2ManifestationSystem.refuse_spawn(city, kind, false)
	elif cost > 0.0 and player.mana < cost:
		city.production_item = kind
		city.stored_production += city.production_cost()
	else:
		player.mana -= cost
		grid.spawn_unit(WorldSetup.find_spawn_tile(grid, city.coord), UnitDatabase.create_unit(kind), player)

# --- Mausoléu ---------------------------------------------------------------------------------------------------

func test_mausoleum_requires_n8_and_the_ossuary_in_the_same_city():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	city.buildings[OSSUARY] = true
	_learn(human, "necromancy", 7)
	assert_false(city.can_build(MAUSOLEUM), "sem N8")
	_learn(human, "necromancy", 8)
	assert_true(city.can_build(MAUSOLEUM))
	city.buildings.erase(OSSUARY)
	assert_false(city.can_build(MAUSOLEUM), "sem o Ossuário")

func test_ossuary_needs_n2_and_trains_the_necromancer_after_n3():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	_learn(human, "necromancy", 1)
	assert_false(city.can_build(OSSUARY), "sem N2")
	_learn(human, "necromancy", 2)
	assert_true(city.can_build(OSSUARY))
	city.buildings[OSSUARY] = true
	assert_false(city.can_train(NECROMANCER), "sem N3")
	_learn(human, "necromancy", 3)
	assert_true(city.can_train(NECROMANCER))
	city.buildings.erase(OSSUARY)
	assert_false(city.can_train(NECROMANCER), "Ossuário exigido")

func test_mausoleum_is_a_normal_building_occupying_a_slot_and_blocked_by_deficit():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	city.buildings[OSSUARY] = true
	_learn(human, "necromancy", 8)
	var slots := city.used_building_slots()
	city.buildings[MAUSOLEUM] = true
	assert_eq(city.used_building_slots(), slots + 1)
	city.buildings.erase(MAUSOLEUM)
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human))
	assert_ne(city.deficit_build_reason(MAUSOLEUM), "", "upkeep > 0: Déficit bloqueia iniciar")
	assert_false(city.can_train(NECROMANCER), "Déficit bloqueia unidade com Suprimentos")

# --- Lich ---------------------------------------------------------------------------------------------------------

func test_lich_needs_n9_and_the_mausoleum():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human, "necromancy", 8)
	assert_false(city.can_train(LICH), "N9 exigido")
	_learn(human)
	assert_true(city.can_train(LICH))
	city.buildings.erase(MAUSOLEUM)
	assert_false(city.can_train(LICH), "Mausoléu exigido")

func test_lich_adds_four_command_and_uses_the_shared_repertoire():
	_learn(human)
	var lich := _unit(LICH, human, Vector2i.ZERO)
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4)
	_unit(NECROMANCER, human, Vector2i(3, 0))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 6)
	assert_eq(V2MagicRuntime.spells_for_unit(lich).map(func(spell): return spell.id), ["v2_spell_raise_dead", "v2_spell_mend_undead", "v2_spell_macabre_command", "v2_spell_raise_legion"])
	assert_true(V2MagicRuntime.cast(lich, "v2_spell_raise_dead", Vector2i(1, 0)), "o Lich invoca")
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 1, "o Lich não ocupa o próprio comando")
	assert_false(lich.unit_data.can_basic_attack)
	var enemy := _unit("warrior", rival, Vector2i(-1, 0))
	assert_false(CombatResolver.can_attack_unit(lich, enemy, grid), "sem ataque básico")
	assert_eq(CombatResolver.predict(enemy, lich, grid).damage_to_attacker, 0.0, "sem revide")

func test_lich_death_drops_capacity_without_killing_hosts():
	_learn(human)
	var lich := _unit(LICH, human, Vector2i.ZERO)
	var hosts: Array[Unit] = []
	for i in 4:
		hosts.append(_unit(SKELETON, human, Vector2i(i - 1, 3)))
	assert_eq(hosts.map(func(h): return V2RetinueSystem.is_commanded(h)), [true, true, true, true])
	grid.remove_unit(lich)
	for host in hosts:
		assert_true(host in human.units)
		assert_false(V2RetinueSystem.is_commanded(host))
	assert_true(V2ManifestationSystem.slot_available(human, SCHOOL), "o slot volta")

func test_mend_heals_the_lich_and_sacred_light_too():
	_learn(human)
	_learn(human, "sacred", 4)
	var necromancer := _unit(NECROMANCER, human, Vector2i.ZERO)
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i(-1, 0))
	var lich := _unit(LICH, human, Vector2i(1, 0))
	lich.hp = 10.0
	assert_true(V2MagicRuntime.cast(necromancer, "v2_spell_mend_undead", lich.coord))
	assert_eq(lich.hp, 18.0)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_restoring_light", lich.coord))
	assert_eq(lich.hp, 26.0, "a Sagrada cura qualquer unidade própria, inclusive undead")

func test_lich_counters_dismantle_yes_legend_hunt_no():
	for i in range(1, 7):
		assert_true(rival.v2_research.complete_research("v2_doctrine_rogue_%d" % i))
	var lich := _unit(LICH, human, Vector2i.ZERO)
	var saboteur := _unit("v2_unit_saboteur", rival, Vector2i(1, 0))
	var hunter := _unit("v2_legendary_legend_hunter", rival, Vector2i(-1, 0))
	var plain := _unit("warrior", human, Vector2i(0, 2))
	assert_gt(UnitAbilities.attack_multiplier(saboteur, lich), UnitAbilities.attack_multiplier(saboteur, plain), "Desmantelar: caster")
	assert_eq(UnitAbilities.attack_multiplier(hunter, lich), UnitAbilities.attack_multiplier(hunter, plain), "Caçada Lendária: não é legendary")
	assert_false(V2LegendarySystem.is_legendary_unit(lich))

# --- Três Manifestações ------------------------------------------------------------------------------------------------

func test_three_manifestations_of_three_schools_coexist_and_each_slot_stays_independent():
	var seraph := _unit(SERAPH, human, Vector2i(-3, 0))
	var archdemon := _unit(ARCHDEMON, human, Vector2i(3, 0))
	var lich := _unit(LICH, human, Vector2i(0, 3))
	for school in ["sacred", "infernal", "necromancy"]:
		assert_false(V2ManifestationSystem.slot_available(human, school), school)
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1)
	var city := _ritual_city(human, Vector2i(0, -4))
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	_learn(human)
	_learn(human, "sacred")
	assert_false(city.can_train(LICH), "segundo Lich bloqueado")
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, LICH), V2ManifestationSystem.SLOT_TAKEN_REASON)
	assert_false(city.can_train(SERAPH), "segundo Serafim continua bloqueado pela Sagrada")
	grid.remove_unit(archdemon)
	assert_false(city.can_train(LICH), "a Infernal livre não libera a Necromancia")
	grid.remove_unit(lich)
	assert_true(city.can_train(LICH))
	assert_true(is_instance_valid(seraph))

func test_fail_closed_second_lich_never_spawns():
	var a := _ritual_city(human, Vector2i(-4, 0))
	var b := _ritual_city(human, Vector2i(4, 0))
	_learn(human)
	a.production_item = LICH
	b.production_item = LICH # estado inconsistente: as duas concluem no mesmo ciclo
	_complete(a)
	_complete(b)
	assert_push_error("V2ManifestationSystem")
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1)
	assert_eq(human.mana, 200.0 - 65.0, "uma cobrança só")

# --- Mana de produção (65) ------------------------------------------------------------------------------------------------

func test_production_mana_battery():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	human.mana = 64.0
	assert_false(city.can_train(LICH))
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, LICH), "Requer 65 Mana.")
	human.mana = 65.0
	assert_true(city.can_train(LICH), "exatamente 65 inicia")
	city.set_production(LICH)
	assert_eq(human.mana, 65.0, "nada reservado")
	human.mana = 10.0
	_complete(city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 0, "espera a Mana")
	assert_eq(city.production_item, LICH)
	assert_eq(city.stored_production, 100.0, "PP travados no custo, sem perda")
	assert_eq(city.production_waiting_for_mana(), 65)
	assert_false(V2ManifestationSystem.slot_available(human, SCHOOL, null), "slot reservado")
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var loaded_city: City = human.cities[0]
	assert_eq(loaded_city.production_item, LICH, "a espera sobrevive ao load")
	assert_eq(loaded_city.production_waiting_for_mana(), 65)
	human.mana = 70.0
	_complete(loaded_city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1, "nasce")
	assert_eq(human.mana, 5.0, "65 cobrados uma vez")
	_complete(loaded_city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1, "sem conclusão dupla")

func test_cancelling_the_lich_needs_no_refund():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	city.set_production(LICH)
	city.stored_production = 40.0
	city.set_production("warrior")
	assert_eq(human.mana, 200.0)
	assert_true(V2ManifestationSystem.slot_available(human, SCHOOL))

func test_lich_save_load_keeps_identity_and_command():
	_learn(human)
	var lich := _unit(LICH, human, Vector2i.ZERO)
	lich.hp = 21.0
	_unit(SKELETON, human, Vector2i(2, 0))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var loaded_lich := loaded.get_unit_at(Vector2i.ZERO)
	assert_eq(loaded_lich.unit_data.visual_kind, LICH)
	assert_eq(loaded_lich.hp, 21.0)
	for trait_id in [UnitData.TRAIT_CASTER, UnitData.TRAIT_UNDEAD, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(loaded_lich.unit_data.has_trait(trait_id))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4)
	assert_false(V2ManifestationSystem.slot_available(human, SCHOOL))

# --- Transcendência conectada, mas nunca vitória só por pesquisa -----------------------------------------------------------

func test_three_complete_schools_and_manifestations_without_ritual_do_not_win():
	for branch in ["sacred", "infernal", "necromancy"]:
		human.v2_research.debug_complete_branch(MAGIC, branch)
	_unit(SERAPH, human, Vector2i(-3, 0))
	_unit(ARCHDEMON, human, Vector2i(3, 0))
	_unit(LICH, human, Vector2i(0, 3))
	assert_eq(V2ResearchDatabase.capstone_progress(V2ResearchDatabase.TRANSCENDENCE_ID, human.v2_research.completed_ids), Vector2i(2, 2), "o progresso satura em 2/2")
	var node := V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID)
	assert_true(node.gameplay_connected)
	assert_eq(node.requirement.branch_count, 2, "não sobe para 3")
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	_unit("warrior", rival, Vector2i(5, 0))
	grid.found_city(Vector2i(6, -3), rival, "Rival", true)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória")
	assert_false("arcane_ritual_active" in human, "Fase 25: estado V1 removido")
