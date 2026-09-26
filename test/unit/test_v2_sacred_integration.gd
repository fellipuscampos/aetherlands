extends GutTest

## Aetherlands V2, Fase 17 — a Magia Sagrada integrada ao que já existia: a Mana da Infraestrutura Arcana abastece os
## feitiços (§144); a magia sustenta o exército das Doutrinas (§145); o Ladino contraria o conjurador sem integração
## nova (§146); a IA convive com o conteúdo sem estratégia (§153).

const CLERIC := "v2_unit_sacred_cleric"
const SERAPH := "v2_manifestation_seraph"
const LIGHT := "v2_spell_restoring_light"
const AEGIS := "v2_spell_sacred_aegis"
const SHRINE := "v2_building_arcane_shrine"

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
var _original_stagger: bool

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	_original_stagger = GameManager.stagger_ai_turns
	GameManager.stagger_ai_turns = false
	grid = HexGrid.new()
	grid._ready()
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	GameManager.human_player = human
	var rivals: Array[PlayerData] = [rival]
	GameManager.rival_players = rivals
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 40
	human.gold = 500.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	GameManager.state = _original_state
	GameManager.stagger_ai_turns = _original_stagger
	GameManager.is_turn_processing = false
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(player: PlayerData, tier: int = 9) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_sacred_%d" % i):
			assert_true(player.v2_research.complete_research("v2_magic_sacred_%d" % i))

func _unit(kind: String, owner: PlayerData, coord: Vector2i, hp: float = -1.0) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	if hp >= 0.0:
		unit.hp = hp
	return unit

# --- §144 Economia -> Magia ---------------------------------------------------------------------------------

func test_arcane_shrine_mana_feeds_the_spells_and_turns_refill_it():
	var city := grid.found_city(Vector2i(-5, 0), human, "Capital", true)
	var base_income := V2EconomyRuntime.player_mana_income(human)
	city.buildings[SHRINE] = true
	city.repeatable_building_counts[SHRINE] = 1
	var income := V2EconomyRuntime.player_mana_income(human)
	assert_gt(income, base_income, "o Santuário Arcano soma Mana")
	human.mana = 0.0
	V2EconomyRuntime.apply_turn_income(human)
	assert_eq(human.mana, income, "a economia credita o MESMO pool")
	_learn(human, 4)
	var cleric := _unit(CLERIC, human, Vector2i.ZERO)
	var ally := _unit("warrior", human, Vector2i(1, 0), 2.0)
	human.mana = 10.0
	assert_true(V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid))
	assert_eq(human.mana, 6.0, "Mana cai")
	V2EconomyRuntime.apply_turn_income(human)
	assert_eq(human.mana, 6.0 + income, "e a economia repõe")

# --- §145 Militar -> Magia ----------------------------------------------------------------------------------

func test_magic_sustains_the_doctrine_army_in_real_combat():
	for i in range(1, 7):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % i)
	_learn(human, 5)
	var guardian := _unit("v2_unit_guardian", human, Vector2i.ZERO, 6.0)
	var cleric := _unit(CLERIC, human, Vector2i(-1, 0))
	var champion := _unit("v2_legendary_guardian_champion", human, Vector2i(-2, 0))
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	human.mana = 50.0
	assert_true(V2MagicRuntime.cast(cleric, LIGHT, guardian.coord, grid))
	assert_eq(guardian.hp, 14.0, "Luz Restauradora: +8")
	var second_cleric := _unit(CLERIC, human, Vector2i(0, -1))
	assert_true(V2MagicRuntime.cast(second_cleric, AEGIS, guardian.coord, grid))
	assert_true(V2TechniqueRuntime.activate(guardian, "v2_technique_shield_wall"))
	var expected_factor: float = 1.35 * 1.35 * 1.20
	var got_factor: float = V2TechniqueRuntime.defense_multiplier(guardian, grid) * V2MagicRuntime.defense_multiplier(guardian) * V2UnitAuras.defense_multiplier(guardian)
	assert_almost_eq(got_factor, expected_factor, 0.0001, "Muralha x Égide x Comando: origens diferentes multiplicam")
	var predicted: Dictionary = CombatResolver.predict(enemy, guardian, grid)
	var hp := guardian.hp
	CombatResolver.resolve(enemy, guardian, grid)
	assert_almost_eq(hp - guardian.hp, predicted.damage_to_defender, 0.0001, "predict == resolve")
	assert_not_null(champion)

# --- §146 Counter do Ladino ---------------------------------------------------------------------------------

func test_rogue_counter_works_through_aegis_by_the_existing_formula():
	for i in range(1, 7):
		rival.v2_research.complete_research("v2_doctrine_rogue_%d" % i)
	_learn(human, 5)
	var cleric := _unit(CLERIC, human, Vector2i.ZERO)
	var assassin := _unit("v2_unit_assassin", rival, Vector2i(1, 0))
	human.mana = 20.0
	V2MagicRuntime.cast(cleric, AEGIS, cleric.coord, grid)
	assert_true(cleric.unit_data.has_trait(UnitData.TRAIT_CASTER))
	assert_eq(V2TechniqueRuntime.attack_multiplier(assassin, cleric), 1.5, "Desmantelar ativa")
	var technique := V2DoctrineTechniqueDatabase.get_technique("v2_technique_sneak_attack")
	var pen := technique.strike_defense_penetration
	# D(aegis, pen) = atk - Def * aegis * (1 - pen) * 0,5. Com a Égide e a penetração, a diferença para o golpe SEM
	# penetração é 1,35 * Def * pen * 0,5; a diferença entre sem e com Égide (ambos com penetração) é 0,35 * Def * (1 - pen) * 0,5.
	var with_both: float = CombatResolver.predict(assassin, cleric, grid, technique.strike_multiplier, pen, true).damage_to_defender
	var aegis_no_pen: float = CombatResolver.predict(assassin, cleric, grid, technique.strike_multiplier, 0.0, true).damage_to_defender
	cleric.magic_status.erase(AEGIS)
	var pen_no_aegis: float = CombatResolver.predict(assassin, cleric, grid, technique.strike_multiplier, pen, true).damage_to_defender
	var ratio := (with_both - aegis_no_pen) / (pen_no_aegis - with_both)
	assert_almost_eq(ratio, (1.35 * pen) / (0.35 * (1.0 - pen)), 0.0001, "a penetração age sobre a Defesa JÁ multiplicada pela Égide, na fórmula existente")

# --- Tensão Logística ------------------------------------------------------------------------------------------

func test_tension_hits_the_cleric_defense_but_never_the_healing_output():
	_learn(human, 4)
	var cleric := _unit(CLERIC, human, Vector2i.ZERO)
	for coord in [Vector2i(-4, 0), Vector2i(-4, 1)]:
		_unit("v2_unit_sentinel", human, coord)
	assert_true(V2LogisticsRuntime.is_logistically_strained(human))
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(cleric), 0.85, 0.0001, "supply 2: a Defesa sofre a Tensão")
	var ally := _unit("warrior", human, Vector2i(1, 0), 2.0)
	human.mana = 10.0
	V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid)
	assert_eq(ally.hp, 10.0, "cura cheia")

# --- §117 Fortificação -------------------------------------------------------------------------------------

func test_spells_never_touch_city_hp_shield_or_defense():
	_learn(human)
	var cleric := _unit(CLERIC, human, Vector2i.ZERO)
	var city := grid.found_city(Vector2i(1, 0), human, "Muralha", true)
	city.city_level = 2
	city.fortification_level = 1
	city.hp = 5.0
	city.shield = 1.0
	human.mana = 100.0
	for spell_id in ["v2_spell_restoring_light", "v2_spell_healing_wave", "v2_spell_miracle", AEGIS]:
		cleric.movement_left = 2.0
		V2MagicRuntime.cast(cleric, spell_id, city.coord, grid)
	assert_eq([city.hp, city.shield, city.defense_bonus()], [5.0, 1.0, 0.10])

# --- §153 IA: compatibilidade mínima ---------------------------------------------------------------------------

func test_ai_with_sacred_content_runs_turns_without_crash_or_basic_attacks():
	_learn(rival)
	var rival_city := grid.found_city(Vector2i(6, -2), rival, "Rival", true)
	rival_city.buildings["v2_building_sacred_temple"] = true
	rival_city.buildings["v2_building_sacred_ritual"] = true
	rival.mana = 5.0
	var rival_cleric := _unit(CLERIC, rival, Vector2i(5, -1))
	var rival_seraph := _unit(SERAPH, rival, Vector2i(6, 0))
	grid.found_city(Vector2i(-6, 2), human, "Capital", true)
	var human_unit := _unit("warrior", human, Vector2i(4, -1))
	var hp := human_unit.hp
	for turn in 3:
		RivalAI.take_turn(rival, grid, human)
		CityDefense.ai_city_defense_turn(rival_city, grid)
		TurnManager.turn_number += 1
	assert_true(is_instance_valid(rival_cleric))
	assert_true(is_instance_valid(rival_seraph) and grid.tiles.has(rival_seraph.coord), "pathfinding do Serafim estável")
	assert_true(not is_instance_valid(human_unit) or human_unit.hp == hp, "nenhum ataque básico inválido de conjurador")
	assert_true(rival.mana >= 0.0, "Mana respeitada")
