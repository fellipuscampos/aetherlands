extends GutTest

## Aetherlands V2, Fase 20 — Círculo Druídico, Druida, Bosque Ancestral, Avatar da Natureza (quarta Grande
## Manifestação), Domínio Natural por dado, quatro Manifestações de Escolas diferentes, bateria de Mana de produção (65)
## e a Transcendência sem Ritual Final com quatro Escolas completas.

const SAVE_PATH := "user://test_v2_nature_avatar.json"
const CIRCLE := "v2_building_druidic_circle"
const RITUAL := "v2_building_druidic_ritual"
const DRUID := "v2_unit_druid"
const AVATAR := "v2_manifestation_nature_avatar"
const SCHOOL := "druidism"
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

func _learn(player: PlayerData, branch: String = "druidism", tier: int = 9) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_%s_%d" % [branch, i]):
			assert_true(player.v2_research.complete_research("v2_magic_%s_%d" % [branch, i]))

func _ritual_city(owner: PlayerData, coord: Vector2i) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = 3
	city.buildings[CIRCLE] = true
	city.buildings[RITUAL] = true
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

## Mesmo caminho do GameManager (process_turn + nascimento com as mesmas checagens).
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

# --- Círculo e Druida -------------------------------------------------------------------------------------------------

func test_circle_needs_n2_and_trains_the_druid_after_n3():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	var mana_base := V2EconomyRuntime.city_mana_income(city)
	_learn(human, SCHOOL, 1)
	assert_false(city.can_build(CIRCLE), "sem N2")
	_learn(human, SCHOOL, 2)
	assert_true(city.can_build(CIRCLE))
	city.buildings[CIRCLE] = true
	assert_eq(V2EconomyRuntime.city_mana_income(city), mana_base, "o Círculo não gera Mana")
	assert_false(city.can_train(DRUID), "sem N3")
	_learn(human, SCHOOL, 3)
	assert_true(city.can_train(DRUID))
	city.buildings.erase(CIRCLE)
	assert_false(city.can_train(DRUID), "Círculo exigido")

func test_druid_is_blocked_by_deficit_and_supplies_like_any_supply_unit():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	city.buildings[CIRCLE] = true
	_learn(human, SCHOOL, 3)
	assert_true(city.can_train(DRUID))
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human))
	assert_false(city.can_train(DRUID), "Déficit bloqueia unidade com Suprimentos")
	assert_string_contains(V2LogisticsRuntime.training_soft_reason(human, city, DRUID), "Déficit")

func test_druid_tension_reduces_defense_but_never_the_spells():
	var druid := _unit(DRUID, human, Vector2i.ZERO)
	for i in 3:
		_unit("v2_unit_guardian", human, Vector2i(i - 1, 3)) # 6 Suprimentos sem cidade: Tensão
	assert_true(V2LogisticsRuntime.is_logistically_strained(human))
	assert_eq(V2LogisticsRuntime.combat_multiplier(druid), V2LogisticsRuntime.TENSION_MULTIPLIER)
	_learn(human, SCHOOL, 4)
	assert_true(V2MagicRuntime.cast(druid, "v2_spell_grow_grove", Vector2i(2, 0)))
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, Vector2i(2, 0)), 1.2, "o efeito do feitiço é o mesmo")

# --- Bosque Ancestral ------------------------------------------------------------------------------------------------

func test_ritual_needs_n8_and_the_circle_occupies_a_slot_and_deficit_blocks():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	city.city_level = 3
	city.buildings[CIRCLE] = true
	_learn(human, SCHOOL, 7)
	assert_false(city.can_build(RITUAL), "sem N8")
	_learn(human, SCHOOL, 8)
	assert_true(city.can_build(RITUAL))
	city.buildings.erase(CIRCLE)
	assert_false(city.can_build(RITUAL), "sem o Círculo")
	city.buildings[CIRCLE] = true
	var slots := city.used_building_slots()
	city.buildings[RITUAL] = true
	assert_eq(city.used_building_slots(), slots + 1)
	city.buildings.erase(RITUAL)
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	human.gold = 0.0
	assert_ne(city.deficit_build_reason(RITUAL), "", "Déficit bloqueia iniciar")

# --- Avatar ----------------------------------------------------------------------------------------------------------

func test_avatar_needs_n9_and_the_ritual_and_never_attacks():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human, SCHOOL, 8)
	assert_false(city.can_train(AVATAR), "N9 exigido")
	_learn(human)
	assert_true(city.can_train(AVATAR))
	city.buildings.erase(RITUAL)
	assert_false(city.can_train(AVATAR))
	var avatar := _unit(AVATAR, human, Vector2i(3, 0))
	var enemy := _unit("warrior", rival, Vector2i(4, 0))
	assert_false(CombatResolver.can_attack_unit(avatar, enemy, grid))
	assert_eq(CombatResolver.predict(enemy, avatar, grid).damage_to_attacker, 0.0, "sem revide")
	assert_false(V2LegendarySystem.is_legendary_unit(avatar))

func test_avatar_counters_dismantle_yes_legend_hunt_no():
	for i in range(1, 7):
		assert_true(rival.v2_research.complete_research("v2_doctrine_rogue_%d" % i))
	var avatar := _unit(AVATAR, human, Vector2i.ZERO)
	var plain := _unit("warrior", human, Vector2i(0, 2))
	var saboteur := _unit("v2_unit_saboteur", rival, Vector2i(1, 0))
	var hunter := _unit("v2_legendary_legend_hunter", rival, Vector2i(-1, 0))
	assert_gt(UnitAbilities.attack_multiplier(saboteur, avatar), UnitAbilities.attack_multiplier(saboteur, plain), "Desmantelar: caster")
	assert_eq(UnitAbilities.attack_multiplier(hunter, avatar), UnitAbilities.attack_multiplier(hunter, plain), "não é legendary")

func test_four_manifestations_coexist_and_each_school_slot_stays_independent():
	var seraph := _unit("v2_manifestation_seraph", human, Vector2i(-3, 0))
	var archdemon := _unit("v2_manifestation_archdemon", human, Vector2i(3, 0))
	var lich := _unit("v2_manifestation_lich_sovereign", human, Vector2i(0, 3))
	var avatar := _unit(AVATAR, human, Vector2i(0, -3))
	for school in ["sacred", "infernal", "necromancy", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1, school)
	var city := _ritual_city(human, Vector2i(5, -5))
	_learn(human)
	assert_false(city.can_train(AVATAR), "segundo Avatar bloqueado")
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, AVATAR), V2ManifestationSystem.SLOT_TAKEN_REASON)
	assert_true(V2LegendarySystem.legendary_slot_available(human, city), "o slot Lendário Militar não é tocado")
	grid.remove_unit(lich)
	assert_false(city.can_train(AVATAR), "outra Escola livre não libera o Druidismo")
	grid.remove_unit(avatar)
	assert_true(city.can_train(AVATAR))
	assert_true(is_instance_valid(seraph) and is_instance_valid(archdemon))

func test_fail_closed_second_avatar_never_spawns():
	var a := _ritual_city(human, Vector2i(-4, 0))
	var b := _ritual_city(human, Vector2i(4, 0))
	_learn(human)
	a.production_item = AVATAR
	b.production_item = AVATAR
	_complete(a)
	_complete(b)
	assert_push_error("V2ManifestationSystem")
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1)
	assert_eq(human.mana, 200.0 - 65.0, "uma cobrança só")

func test_production_mana_battery_with_save_and_cancel():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	human.mana = 64.0
	assert_false(city.can_train(AVATAR))
	assert_eq(V2ManifestationSystem.training_soft_reason(human, city, AVATAR), "Requer 65 Mana.")
	human.mana = 65.0
	assert_true(city.can_train(AVATAR))
	city.set_production(AVATAR)
	assert_eq(human.mana, 65.0, "nada reservado")
	human.mana = 10.0
	_complete(city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 0, "espera")
	assert_eq(city.stored_production, 105.0, "PP travados no custo")
	assert_eq(city.production_waiting_for_mana(), 65)
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var loaded_city: City = human.cities[0]
	assert_eq(loaded_city.production_waiting_for_mana(), 65, "a espera sobrevive ao load")
	human.mana = 70.0
	_complete(loaded_city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1)
	assert_eq(human.mana, 5.0, "65 uma vez")
	_complete(loaded_city)
	assert_eq(V2ManifestationSystem.active_units(human, SCHOOL).size(), 1, "sem conclusão dupla")

func test_cancelling_the_avatar_needs_no_refund():
	var city := _ritual_city(human, Vector2i.ZERO)
	_learn(human)
	city.set_production(AVATAR)
	city.stored_production = 30.0
	city.set_production("warrior")
	assert_eq(human.mana, 200.0)
	assert_true(V2ManifestationSystem.slot_available(human, SCHOOL))

func test_avatar_save_load_keeps_identity_and_range_bonus():
	_learn(human)
	var avatar := _unit(AVATAR, human, Vector2i.ZERO)
	avatar.hp = 30.0
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	var loaded_avatar := loaded.get_unit_at(Vector2i.ZERO)
	assert_eq(loaded_avatar.unit_data.visual_kind, AVATAR)
	assert_eq(loaded_avatar.hp, 30.0)
	assert_eq(loaded_avatar.unit_data.spell_range_bonus, 1)
	assert_true(loaded_avatar.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION))
	assert_eq(V2MagicRuntime.effective_range(loaded_avatar, V2SpellDatabase.get_spell("v2_spell_awaken_forest")), 5)

func test_four_complete_schools_and_manifestations_without_final_ritual_never_win():
	for branch in ["sacred", "infernal", "necromancy", SCHOOL]:
		human.v2_research.debug_complete_branch(MAGIC, branch)
	for pair in [["v2_manifestation_seraph", Vector2i(-3, 0)], ["v2_manifestation_archdemon", Vector2i(3, 0)], ["v2_manifestation_lich_sovereign", Vector2i(0, 3)], [AVATAR, Vector2i(0, -3)]]:
		_unit(pair[0], human, pair[1])
	assert_true(human.v2_research.complete_research(V2ResearchDatabase.TRANSCENDENCE_ID))
	assert_true(V2ResearchDatabase.get_node(V2ResearchDatabase.TRANSCENDENCE_ID).gameplay_connected)
	_unit("warrior", rival, Vector2i(6, 0))
	grid.found_city(Vector2i(6, -3), rival, "Rival", true)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória")
	assert_false("arcane_ritual_active" in human, "Fase 25: estado V1 removido")
