extends GutTest

## Sentinela (v2_unit_sentinel, Aetherlands V2 Fase 5): a forma Elite CONVENCIONAL da
## Doutrina do Guardião (N7), o segundo upgrade (Guardião -> Sentinela) e a cadeia completa
## Escudeiro -> Guardião -> Sentinela pelo MESMO sistema genérico (V2UnitUpgrade). Números =
## BALANCE PLACEHOLDER: os testes fixam também as RELAÇÕES e calculam custos pela fórmula.

const SHIELD := "v2_unit_shieldbearer"
const GUARDIAN := "v2_unit_guardian"
const SENTINEL := "v2_unit_sentinel"
const HALL := "v2_building_guardian_hall"
const WALL := "v2_technique_shield_wall"
const BRACE := "v2_technique_brace_spears"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _original_turn: int
var _original_human: PlayerData

func before_each():
	_original_turn = TurnManager.turn_number
	_original_human = GameManager.human_player
	TurnManager.turn_number = 5

func after_each():
	TurnManager.turn_number = _original_turn
	GameManager.human_player = _original_human
	for city in _cities:
		if is_instance_valid(city):
			city.free()
	_cities.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()
	for player in _players:
		player.release_relations()
	_players.clear()

# --- Helpers -------------------------------------------------------------------------------------

func _world() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-4, 5):
		for r in range(-4, 5):
			if absi(q + r) <= 4:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _player(through: int, gold: float = 200.0) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	player.gold = gold
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

## Cidade PRÓPRIA com Salão em (0,0) e uma unidade `kind` no vizinho (1,0).
func _case(through: int, kind: String, with_hall: bool = true) -> Dictionary:
	var grid := _world()
	var player := _player(through)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	if with_hall:
		city.buildings[HALL] = true
	var unit := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), player)
	assert_not_null(unit)
	return {"grid": grid, "player": player, "city": city, "unit": unit}

func _standalone_city(player: PlayerData, with_hall: bool = true) -> City:
	var city := City.new()
	city.owner_player = player
	if with_hall:
		city.buildings[HALL] = true
	# Aetherlands V2, Fase 15 — sem estar em player.cities, a capacidade de Suprimentos desta
	# cidade seria 0 pro runtime (que soma player.cities); a BASE (4, sem Fazenda) já cobre a
	# Sentinela (custo 3, o maior desta linha convencional).
	player.cities.append(city)
	_cities.append(city)
	return city

func _trainable_forms(city: City) -> Array:
	return [SHIELD, GUARDIAN, SENTINEL].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

# --- Definição ---------------------------------------------------------------------------------------

func test_the_sentinel_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(SENTINEL)
	assert_eq(data.unit_name, "Sentinela")
	assert_eq(data.max_hp, 32.0)
	assert_eq(data.attack, 5.0)
	assert_eq(data.defense, 8.0)
	assert_eq(data.movement_points, 2.0)
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.production_cost, 48.0)
	assert_false(data.can_found_city)
	assert_false(data.flies)
	assert_eq(data.visual_kind, SENTINEL, "o SaveManager recria a unidade por ele")

func test_relations_the_sentinel_holds_the_line_and_is_not_dps_or_mobility():
	var guardian := UnitDatabase.create_unit(GUARDIAN)
	var sentinel := UnitDatabase.create_unit(SENTINEL)
	assert_gt(sentinel.max_hp, guardian.max_hp)
	assert_gt(sentinel.defense, guardian.defense)
	assert_gt(sentinel.attack, guardian.attack, "ataque cresce")
	assert_lt(sentinel.attack / guardian.attack, sentinel.defense / guardian.defense + 0.0001, "moderadamente: menos que a defesa")
	assert_lt(sentinel.attack, sentinel.defense, "ataque continua secundário à Defesa")
	assert_lt(sentinel.attack, UnitDatabase.create_unit("men_at_arms").attack, "não vira DPS")
	assert_eq(sentinel.movement_points, guardian.movement_points, "mobilidade não cresce")
	assert_eq(sentinel.vision_range, guardian.vision_range)
	assert_gt(sentinel.production_cost, guardian.production_cost)
	var power := func(d: UnitData): return d.attack + d.defense + d.max_hp * 0.15
	assert_gt(power.call(sentinel), power.call(guardian), "poder por tile superior")

func test_the_progression_of_the_three_forms_is_monotonic():
	var forms := [SHIELD, GUARDIAN, SENTINEL].map(func(k): return UnitDatabase.create_unit(k))
	for stat in ["max_hp", "attack", "defense", "production_cost"]:
		assert_lt(forms[0].get(stat), forms[1].get(stat), stat)
		assert_lt(forms[1].get(stat), forms[2].get(stat), stat)
	for form in forms:
		assert_eq(form.movement_points, 2.0)

func test_no_upkeep_it_is_not_legendary_and_the_provisional_model_is_distinct():
	var data := UnitDatabase.create_unit(SENTINEL)
	assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
	assert_true(ResourceLoader.exists(data.animation_scene_path), data.animation_scene_path)
	var scales := [SHIELD, GUARDIAN, SENTINEL].map(func(k): return UnitDatabase.create_unit(k).model_scale_multiplier)
	assert_lt(scales[0], scales[1])
	assert_lt(scales[1], scales[2], "as três formas se distinguem pela escala (provisório)")

func test_it_is_registered_as_a_trainable_kind_once_and_named_for_every_race():
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(SENTINEL), 1)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.unit_name(SENTINEL, race), "Sentinela", race)

func test_the_hall_is_the_trainer_and_the_mastery_building_is_not_required():
	assert_eq(BuildingDatabase.building_that_trains(SENTINEL), BuildingDatabase.get_building(HALL))
	assert_ne(BuildingDatabase.building_that_trains("v2_legendary_guardian_champion"), BuildingDatabase.get_building(HALL), "o Campeão é do Bastião, não do Salão")
	# A cadeia convencional termina na Sentinela; o Campeão é uma produção Lendária separada.
	# Fases 3–22: todas as seis Doutrinas, o Construtor e as seis Escolas de Magia.
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(k): return k.begins_with("v2_")), [SHIELD, GUARDIAN, SENTINEL, "v2_legendary_guardian_champion", "v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero", "v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter", "v2_unit_cavalier", "v2_unit_shock_cavalier", "v2_unit_armored_cavalier", "v2_legendary_griffon_rider", "v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master", "v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus", "v2_unit_builder", "v2_unit_sacred_cleric", "v2_manifestation_seraph", "v2_unit_infernal_warlock", "v2_manifestation_archdemon", "v2_unit_necromancer", "v2_manifestation_lich_sovereign", "v2_unit_druid", "v2_manifestation_nature_avatar", "v2_unit_arcanist", "v2_manifestation_veil_archon", "v2_unit_elementalist", "v2_manifestation_elemental_primordial"])

func test_v1_units_are_untouched():
	assert_eq(UnitDatabase.create_unit("warrior").attack, 4.0)
	assert_eq(UnitDatabase.create_unit(SHIELD).max_hp, 18.0)
	assert_eq(UnitDatabase.create_unit(GUARDIAN).max_hp, 24.0)

# --- Herança de Técnicas por linha ----------------------------------------------------------------------------

func test_the_sentinel_inherits_both_techniques_by_line_with_no_specific_code():
	var c := _case(6, SENTINEL)
	var unit: Unit = c.unit
	assert_eq(V2UnitLine.branch_of(SENTINEL), "guardian")
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).map(func(t): return t.id), [WALL])
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).map(func(t): return t.id), [BRACE])
	assert_true(V2TechniqueRuntime.can_use(unit, WALL))
	assert_true(V2TechniqueRuntime.activate(unit, WALL))

func test_the_sentinel_gets_the_brace_spears_bonus_and_the_wall_defense():
	var c := _case(6, SENTINEL)
	var unit: Unit = c.unit
	var rival := _player(0)
	var horse_data := UnitDatabase.create_unit("warrior")
	horse_data.traits.append(UnitData.TRAIT_MOUNTED)
	horse_data.max_hp = 60.0
	var horse: Unit = c.grid.spawn_unit(Vector2i(2, 0), horse_data, rival)
	assert_almost_eq(UnitAbilities.attack_multiplier(unit, horse), 1.5, 0.0001)
	var striker_data := UnitDatabase.create_unit("warrior")
	striker_data.attack = 30.0 # forte o bastante pra o dano não cair no piso de 1 contra Defesa 8
	var attacker: Unit = c.grid.spawn_unit(Vector2i(1, 1), striker_data, rival)
	var plain: float = CombatResolver.predict(attacker, unit, c.grid).damage_to_defender
	V2TechniqueRuntime.activate(unit, WALL)
	assert_lt(CombatResolver.predict(attacker, unit, c.grid).damage_to_defender, plain)

# --- Produção: só a forma normal mais avançada ---------------------------------------------------------------

func test_the_hall_offers_exactly_one_form_at_every_research_level():
	var expected := {3: SHIELD, 4: SHIELD, 5: GUARDIAN, 6: GUARDIAN, 7: SENTINEL}
	for through in expected:
		var player := _player(through)
		var offered := _trainable_forms(_standalone_city(player))
		assert_eq(offered, [expected[through]], "até N%d" % through)
		assert_lte(offered.size(), 1, "nunca mais de uma forma da linha ao mesmo tempo")

func test_before_n3_nothing_is_offered():
	assert_eq(_trainable_forms(_standalone_city(_player(2))), [])

func test_n7_the_hall_offers_the_sentinel_and_not_the_guardian_or_the_shieldbearer():
	var player := _player(7)
	var city := _standalone_city(player)
	assert_true(city.can_train(SENTINEL))
	assert_false(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD))
	city.set_production(SENTINEL)
	assert_eq(city.production_cost(), 48.0)

func test_the_sentinel_still_needs_the_hall_and_never_the_v1_barracks_or_the_mastery():
	var player := _player(7)
	var no_hall := _standalone_city(player, false)
	no_hall.buildings["barracks"] = true
	assert_false(no_hall.can_train(SENTINEL))
	assert_true(_standalone_city(player).can_train(SENTINEL), "só o Salão, sem Bastião de Maestria")

func test_two_civilizations_at_different_levels_get_different_forms():
	var novice := _standalone_city(_player(3))
	var veteran := _standalone_city(_player(7))
	assert_eq(_trainable_forms(novice), [SHIELD])
	assert_eq(_trainable_forms(veteran), [SENTINEL])

func test_debug_reset_keeps_what_exists_and_production_follows_the_research():
	var player := _player(7)
	var city := _standalone_city(player)
	player.v2_research.reset()
	assert_true(city.buildings.has(HALL))
	assert_eq(_trainable_forms(city), [])
	for n in range(1, 6):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	assert_eq(_trainable_forms(city), [GUARDIAN], "a produção volta a respeitar a pesquisa atual")

func test_an_ai_civilization_with_n7_resolves_the_sentinel_without_breaking():
	var rival := _player(7)
	var city := _standalone_city(rival)
	var offered := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(SENTINEL))
	assert_false(offered.has(GUARDIAN))
	assert_false(offered.has(SHIELD))

# --- Segundo upgrade: Guardião -> Sentinela ---------------------------------------------------------------------

func test_the_target_comes_from_the_metadata_and_the_cost_from_the_generic_formula():
	var c := _case(7, GUARDIAN)
	var unit: Unit = c.unit
	assert_eq(V2ResearchDatabase.node_for_unlock_id(GUARDIAN).upgrade_to, SENTINEL)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SENTINEL)
	var expected := V2UnitUpgrade.GOLD_PER_PRODUCTION_POINT * (UnitDatabase.create_unit(SENTINEL).production_cost - UnitDatabase.create_unit(GUARDIAN).production_cost)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), expected)
	assert_eq(V2UnitUpgrade.upgrade_cost(unit), 32.0, "com os números atuais: 2 x (48 - 32)")

func test_the_sentinel_has_no_further_evolution():
	var c := _case(7, SENTINEL)
	assert_eq(V2UnitUpgrade.get_upgrade_target(c.unit), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(c.unit), 0.0)

func test_a_valid_second_upgrade_is_allowed():
	var c := _case(7, GUARDIAN)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "")
	assert_true(V2UnitUpgrade.can_upgrade(c.player, c.unit, c.grid))

func test_without_n7_the_guardian_cannot_become_a_sentinel():
	var c := _case(6, GUARDIAN)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(c.player, c.unit, c.grid), "Requer pesquisa: Sentinela.")
	assert_false(V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid))
	assert_eq(c.unit.unit_data.visual_kind, GUARDIAN)

func test_the_same_requirements_as_the_first_upgrade_apply():
	var no_hall := _case(7, GUARDIAN, false)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(no_hall.player, no_hall.unit, no_hall.grid), "Requer Salão dos Guardiões na cidade.")

	var outside := _case(7, GUARDIAN)
	outside.grid.move_unit(outside.unit, Vector2i(4, 0), 1.0)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(outside.player, outside.unit, outside.grid), "Precisa estar em uma cidade própria.")

	var poor := _case(7, GUARDIAN)
	poor.player.gold = 31.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(poor.player, poor.unit, poor.grid), "Ouro insuficiente (custa 32).")

	var spent := _case(7, GUARDIAN)
	spent.unit.movement_left = 0.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(spent.player, spent.unit, spent.grid), "A unidade já agiu neste turno.")

	var walled := _case(7, GUARDIAN)
	V2TechniqueRuntime.activate(walled.unit, WALL)
	walled.unit.movement_left = 2.0
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(walled.player, walled.unit, walled.grid), "Não pode evoluir com Muralha de Escudos ativa.")

func test_the_second_upgrade_preserves_everything_that_does_not_depend_on_the_form():
	var c := _case(7, GUARDIAN)
	var unit: Unit = c.unit
	unit.hp = 12.0 # 12/24 = 50%
	unit.kills = 3
	unit.veterancy_level = 2
	V2TechniqueRuntime.activate(unit, WALL)
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(c.player)
	unit.movement_left = 2.0
	var remaining := V2TechniqueRuntime.cooldown_remaining(unit, WALL)
	assert_eq(remaining, 2)
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	var coord := unit.coord
	var count: int = c.player.units.size()
	var gold: float = c.player.gold

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))

	assert_eq(unit.unit_data.visual_kind, SENTINEL)
	assert_eq(unit.get_instance_id(), id, "mesma unidade")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.coord, coord)
	assert_eq(unit.owner_player, c.player)
	assert_eq(c.player.units.size(), count, "sem duplicar")
	assert_eq(c.player.units.filter(func(u): return u.unit_data.visual_kind == GUARDIAN).size(), 0, "sem Guardião fantasma")
	assert_same(c.grid.get_unit_at(coord), unit)
	assert_almost_eq(unit.hp, 16.0, 0.0001, "50% de 32")
	assert_eq(unit.unit_data.max_hp, 32.0)
	assert_eq(unit.kills, 3)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, WALL), remaining, "recarga da Muralha preservada")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(c.player.gold, gold - 32.0, "Ouro descontado")

func test_the_full_chain_shieldbearer_guardian_sentinel_on_the_same_unit():
	var c := _case(7, SHIELD)
	var unit: Unit = c.unit
	var id := unit.get_instance_id()
	var serial := unit.serial_id
	unit.kills = 4
	unit.veterancy_level = 2
	unit.hp = 9.0 # 9/18 = 50%
	var gold: float = c.player.gold
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), GUARDIAN, "um passo por vez: Escudeiro só vai pra Guardião")

	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, GUARDIAN)
	assert_almost_eq(unit.hp, 12.0, 0.0001, "50% de 24")
	assert_eq(c.player.gold, gold - 24.0)
	assert_false(V2UnitUpgrade.can_upgrade(c.player, unit, c.grid), "sem ação neste turno")

	TurnManager.turn_number = 6
	unit.movement_left = 2.0 # novo turno
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), SENTINEL)
	assert_true(V2UnitUpgrade.perform_upgrade(c.player, unit, c.grid))
	assert_eq(unit.unit_data.visual_kind, SENTINEL)
	assert_almost_eq(unit.hp, 16.0, 0.0001, "50% de 32")
	assert_eq(c.player.gold, gold - 24.0 - 32.0)

	assert_eq(unit.get_instance_id(), id, "a MESMA unidade nas três formas")
	assert_eq(unit.serial_id, serial)
	assert_eq(unit.kills, 4)
	assert_eq(unit.veterancy_level, 2)
	assert_eq(c.player.units.size(), 1)
	assert_eq(V2UnitUpgrade.get_upgrade_target(unit), "", "fim da linha")

func test_the_upgrade_module_has_no_specific_evolution_function():
	for method in ["upgrade_guardian_to_sentinel", "upgrade_shieldbearer_to_guardian", "evolve_to_sentinel"]:
		assert_false(V2UnitUpgrade.new().has_method(method), method)

func test_debug_reset_after_the_second_upgrade_does_not_downgrade():
	var c := _case(7, GUARDIAN)
	V2UnitUpgrade.perform_upgrade(c.player, c.unit, c.grid)
	c.player.v2_research.reset()
	assert_eq(c.unit.unit_data.visual_kind, SENTINEL)
	assert_true(c.city.buildings.has(HALL))
	c.unit.movement_left = 2.0
	assert_false(V2TechniqueRuntime.can_use(c.unit, WALL), "sem N4 não usa a Muralha")
	assert_eq(V2TechniqueRuntime.passive_lines(c.unit), [], "sem N6 a passiva some")
