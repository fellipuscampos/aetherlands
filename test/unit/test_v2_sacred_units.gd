extends GutTest

## Aetherlands V2, Fase 17 — prédios e conjurador da Escola Sagrada: Templo Sagrado (N2), Clérigo (N3) e Catedral
## Sagrada (N8), e a semântica explícita de UnitData.can_basic_attack (sem ataque básico, sem revide, sem piso de dano).

const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const TEMPLE := "v2_building_sacred_temple"
const RITUAL := "v2_building_sacred_ritual"
const CLERIC := "v2_unit_sacred_cleric"
const SERAPH := "v2_manifestation_seraph"

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
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	GameManager.human_player = human
	var rivals: Array[PlayerData] = [rival]
	GameManager.rival_players = rivals
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 10
	human.gold = 500.0
	rival.gold = 500.0

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

func _learn(player: PlayerData, tier: int) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_sacred_%d" % i):
			assert_true(player.v2_research.complete_research("v2_magic_sacred_%d" % i))

func _city(owner: PlayerData, coord: Vector2i = Vector2i.ZERO) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = 3
	return city

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

# --- Templo Sagrado (N2) -------------------------------------------------------------------------

func test_temple_data():
	var temple := BuildingDatabase.get_building(TEMPLE)
	assert_eq(temple.display_name, "Templo Sagrado")
	assert_eq(temple.production_cost, 24.0)
	assert_eq(temple.gold_upkeep, 1.0)
	assert_eq(temple.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	assert_eq(temple.requires_building, "", "não depende de prédio nenhum (nem V1)")
	assert_eq(temple.trains_unit, CLERIC)

func test_temple_needs_n2_not_just_n1():
	var city := _city(human)
	assert_false(city.can_build(TEMPLE))
	_learn(human, 1)
	assert_false(city.can_build(TEMPLE), "N1 sozinho não libera")
	_learn(human, 2)
	assert_true(city.can_build(TEMPLE))

func test_temple_never_produces_mana():
	var city := _city(human)
	_learn(human, 2)
	var mana_before := V2EconomyRuntime.player_mana_income(human)
	city.buildings[TEMPLE] = true
	assert_eq(V2EconomyRuntime.player_mana_income(human), mana_before, "a Mana é da infraestrutura Arcana")

func test_temple_research_is_per_civilization():
	var rival_city := _city(rival, Vector2i(5, 0))
	_learn(human, 2)
	assert_false(rival_city.can_build(TEMPLE))

# --- Clérigo (N3) -----------------------------------------------------------------------------------

func test_cleric_data():
	var data := UnitDatabase.create_unit(CLERIC)
	assert_eq([data.unit_name, data.max_hp, data.attack, data.defense, data.movement_points, data.vision_range], ["Clérigo", 12.0, 0.0, 2.0, 2.0, 3])
	assert_eq([data.production_cost, data.supply_cost, data.attack_range], [24.0, 2, 0])
	assert_false(data.can_basic_attack)
	assert_eq(data.v2_magic_school, "sacred")
	assert_true(data.has_trait(UnitData.TRAIT_CASTER), "caster vem do helper unificado, sem lista")
	assert_false(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_eq(data.movement_profile, UnitData.MovementProfile.GROUND)
	assert_true(CLERIC in UnitDatabase.PLAYER_TRAINABLE_KINDS)

func test_cleric_needs_n3_and_a_temple_in_the_same_city():
	var city := _city(human)
	_learn(human, 2)
	city.buildings[TEMPLE] = true
	assert_false(city.can_train(CLERIC), "sem N3")
	_learn(human, 3)
	assert_true(city.can_train(CLERIC))
	var other := _city(human, Vector2i(5, 0))
	assert_false(other.can_train(CLERIC), "o Templo vale só na própria cidade")

func test_cleric_uses_the_normal_production_queue():
	var city := _city(human)
	_learn(human, 3)
	city.buildings[TEMPLE] = true
	city.set_production(CLERIC)
	city.stored_production = 24.0
	var result := city.process_turn(grid)
	assert_eq(result.spawn_unit_kind, CLERIC)

func test_cleric_is_blocked_by_supplies_and_deficit_like_any_supply_unit():
	var city := _city(human)
	_learn(human, 3)
	city.buildings[TEMPLE] = true
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "pré-condição")
	assert_false(city.can_train(CLERIC), "Déficit bloqueia unidade com Suprimentos")
	assert_string_contains(V2LogisticsRuntime.training_soft_reason(human, city, CLERIC), "Déficit")
	human.gold = 500.0
	for coord in [Vector2i(4, 0), Vector2i(4, 1)]:
		_unit("v2_unit_sentinel", human, coord) # 3 + 3 > capacidade base 4
	assert_false(city.can_train(CLERIC))
	assert_string_contains(V2LogisticsRuntime.training_soft_reason(human, city, CLERIC), "Suprimentos insuficientes")

func test_cleric_counts_two_supplies():
	var before := V2LogisticsRuntime.player_supply_used(human)
	_unit(CLERIC, human, Vector2i(2, 0))
	assert_eq(V2LogisticsRuntime.player_supply_used(human) - before, 2)

func test_cleric_moves():
	var cleric := _unit(CLERIC, human, Vector2i(0, 0))
	assert_false(grid.unit_reachable(cleric).is_empty())

# --- Sem ataque básico: bloqueado ANTES da fórmula ----------------------------------------------------

func test_cleric_can_never_attack_even_the_damage_floor():
	var cleric := _unit(CLERIC, human, Vector2i(0, 0))
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	var hp_before := enemy.hp
	assert_false(CombatResolver.can_attack_unit(cleric, enemy, grid))
	assert_eq(CombatResolver.predict(cleric, enemy, grid).damage_to_defender, 0.0, "nem o piso de 1")
	CombatResolver.resolve(cleric, enemy, grid)
	assert_eq(enemy.hp, hp_before, "resolve recusa: nenhum dano")

func test_cleric_never_counterattacks_but_takes_damage_normally():
	var cleric := _unit(CLERIC, human, Vector2i(0, 0))
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	var enemy_hp := enemy.hp
	var prediction := CombatResolver.predict(enemy, cleric, grid)
	assert_eq(prediction.damage_to_attacker, 0.0, "sem revide")
	assert_gt(prediction.damage_to_defender, 0.0)
	CombatResolver.resolve(enemy, cleric, grid)
	assert_eq(enemy.hp, enemy_hp)
	assert_lt(cleric.hp, 12.0)

func test_cleric_never_attacks_a_city():
	var cleric := _unit(CLERIC, human, Vector2i(0, 0))
	var city := _city(rival, Vector2i(1, 0))
	var hp_before := city.hp
	assert_false(CombatResolver.can_attack_city(cleric, city))
	CombatResolver.resolve_city_attack(cleric, city, grid)
	assert_eq(city.hp, hp_before)

func test_selecting_a_cleric_never_marks_anything_attackable():
	var cleric := _unit(CLERIC, human, Vector2i(0, 0))
	_unit("warrior", rival, Vector2i(1, 0))
	SelectionManager._select_unit(cleric)
	assert_true(SelectionManager.attackable.is_empty())

func test_default_can_basic_attack_keeps_every_existing_unit_unchanged():
	for kind in ["warrior", "archer", "v2_unit_guardian", "v2_legendary_griffon_rider", "settler", "v2_unit_builder"]:
		assert_true(UnitDatabase.create_unit(kind).can_basic_attack, kind)

func test_desmantelar_hits_the_cleric_automatically():
	for i in range(1, 7):
		human.v2_research.complete_research("v2_doctrine_rogue_%d" % i)
	var rogue := _unit("v2_unit_assassin", human, Vector2i(0, 0))
	var cleric := _unit(CLERIC, rival, Vector2i(1, 0))
	assert_eq(V2TechniqueRuntime.attack_multiplier(rogue, cleric), 1.5, "caster -> +50%, sem integração nova")

# --- Catedral Sagrada (N8) -----------------------------------------------------------------------------

func test_cathedral_data():
	var ritual := BuildingDatabase.get_building(RITUAL)
	assert_eq(ritual.display_name, "Catedral Sagrada")
	assert_eq([ritual.production_cost, ritual.gold_upkeep], [60.0, 2.0])
	assert_eq(ritual.copy_limit_mode, BuildingData.CopyLimitMode.UNIQUE)
	assert_eq(ritual.requires_building, TEMPLE)
	assert_eq(ritual.trains_unit, SERAPH, "só habilita a Manifestação; nunca treina o Clérigo")

func test_cathedral_needs_n8_and_the_temple():
	var city := _city(human)
	_learn(human, 7)
	city.buildings[TEMPLE] = true
	assert_false(city.can_build(RITUAL), "sem N8")
	_learn(human, 8)
	assert_true(city.can_build(RITUAL))
	city.buildings.erase(TEMPLE)
	assert_false(city.can_build(RITUAL), "sem o Templo")

func test_cathedral_is_a_normal_building_occupying_a_slot_and_blocked_by_deficit():
	var city := _city(human)
	_learn(human, 8)
	city.buildings[TEMPLE] = true
	var slots := city.used_building_slots()
	city.buildings[RITUAL] = true
	assert_eq(city.used_building_slots(), slots + 1)
	city.buildings.erase(RITUAL)
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human))
	assert_ne(city.deficit_build_reason(RITUAL), "", "upkeep > 0: Déficit bloqueia iniciar")

func test_cathedral_does_not_replace_the_temple_for_clerics():
	var city := _city(human)
	_learn(human, 8)
	city.buildings[RITUAL] = true
	assert_false(city.can_train(CLERIC), "sem Templo não treina Clérigo")
