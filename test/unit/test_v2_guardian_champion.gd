extends GutTest

## Campeão Guardião (v2_legendary_guardian_champion, Aetherlands V2 Fase 6): o candidato Lendário
## da Doutrina do Guardião (nó N9). NÃO é upgrade da Sentinela nem entra na cadeia convencional;
## herda as Técnicas da linha por Doutrina e tem a aura própria Comando Defensivo (V2UnitAuras).
## Números = BALANCE PLACEHOLDER; os testes fixam também as RELAÇÕES e a matemática das auras.

const CHAMPION := "v2_legendary_guardian_champion"
const SENTINEL := "v2_unit_sentinel"
const GUARDIAN := "v2_unit_guardian"
const SHIELD := "v2_unit_shieldbearer"
const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"
const WALL := "v2_technique_shield_wall"
const BRACE := "v2_technique_brace_spears"
## Ataque do atacante rival: alto o bastante pra o dano nunca cair no piso de 1.
const STRIKE := 30.0

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _cities: Array[City] = []
var _original_turn: int

func before_each():
	_original_turn = TurnManager.turn_number
	TurnManager.turn_number = 5

func after_each():
	TurnManager.turn_number = _original_turn
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
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_grids.append(grid)
	return grid

func _player(through: int = 9) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	_players.append(player)
	for n in range(1, through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	return player

func _unit(grid: HexGrid, player: PlayerData, kind: String, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	assert_not_null(unit, "spawn %s em %s" % [kind, str(coord)])
	# Aetherlands V2, Fase 15 — este arquivo é sobre o Campeão/aura/Muralha, não sobre Suprimentos:
	# sem cidade nenhuma, a capacidade seria 0 e o próprio Campeão (custo 5) entraria em Tensão
	# Logística sozinho, poluindo os números de combate que os testes verificam pela fórmula.
	if unit != null and unit.unit_data.supply_cost > 0 and not _supply_granted.has(player):
		var city := City.new()
		city.owner_player = player
		city.buildings["v2_building_farm"] = true
		city.repeatable_building_counts["v2_building_farm"] = 50
		player.cities.append(city)
		_cities.append(city)
		_supply_granted[player] = true
		if player.gold <= 0.0:
			player.gold = 1000.0
	return unit

var _supply_granted: Dictionary = {}

func _striker(grid: HexGrid, rival: PlayerData, coord: Vector2i) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.attack = STRIKE
	var unit := grid.spawn_unit(coord, data, rival)
	assert_not_null(unit)
	return unit

func _damage(grid: HexGrid, attacker: Unit, defender: Unit) -> float:
	return CombatResolver.predict(attacker, defender, grid).damage_to_defender

## Dano esperado de STRIKE contra `defender` com um multiplicador de defesa extra `extra`.
func _expected(grid: HexGrid, defender: Unit, extra: float) -> float:
	var terrain := 1.0 + grid.get_tile(defender.coord).defense_bonus
	return maxf(1.0, STRIKE - defender.unit_data.defense * terrain * extra * CombatResolver.DEFENSE_MITIGATION_FACTOR)

func _standalone_city(player: PlayerData, with_mastery: bool = true) -> City:
	var city := City.new()
	city.owner_player = player
	city.city_level = 4
	city.buildings[HALL] = true
	if with_mastery:
		city.buildings[MASTERY] = true
	# Aetherlands V2, Fase 15 — a Lendária custa 5 Suprimentos: sem capacidade (e sem esta cidade
	# nem contar pra player.cities, que City.can_train/V2LogisticsRuntime agora consultam), o
	# treino ficaria sempre bloqueado por capacidade, mesmo com prédio/pesquisa/slot corretos.
	# Fazenda ×4 já ocupa os 4 slots do City Level I sozinha (City.used_building_slots() conta
	# cada cópia repetível, §26 da Fase 13) -- City Level III sobra espaço pro Salão/Bastião.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	# Salão/Bastião têm gold_upkeep (§24-30 da Fase 15) e esta cidade fantasma nunca tem Mercado --
	# sem Ouro de sobra a civilização entraria em Déficit sozinha, bloqueando o treino do Campeão
	# por um motivo alheio ao que estes testes verificam.
	if player.gold <= 0.0:
		player.gold = 1000.0
	player.cities.append(city)
	_cities.append(city)
	return city

func _aura_bonus() -> float:
	return UnitDatabase.create_unit(CHAMPION).aura_defense_bonus

# --- Definição -----------------------------------------------------------------------------------

func test_the_champion_has_the_specified_baseline():
	var data := UnitDatabase.create_unit(CHAMPION)
	assert_eq(data.unit_name, "Campeão Guardião")
	assert_eq(data.max_hp, 44.0)
	assert_eq(data.attack, 6.5)
	assert_eq(data.defense, 10.0)
	assert_eq(data.movement_points, 2.0)
	assert_eq(data.vision_range, 3)
	assert_eq(data.attack_range, 1, "corpo a corpo")
	assert_eq(data.production_cost, 90.0)
	assert_false(data.can_found_city)
	assert_false(data.flies)
	assert_eq(data.visual_kind, CHAMPION, "o SaveManager recria a unidade por ele")

func test_relations_the_champion_is_clearly_superior_but_still_a_guardian():
	var sentinel := UnitDatabase.create_unit(SENTINEL)
	var champion := UnitDatabase.create_unit(CHAMPION)
	assert_gt(champion.max_hp, sentinel.max_hp * 1.3, "extremamente resistente")
	assert_gt(champion.defense, sentinel.defense)
	assert_gt(champion.attack, sentinel.attack, "ataque melhor...")
	assert_lt(champion.attack, champion.defense, "...mas continua secundário à Defesa")
	assert_lt(champion.attack, UnitDatabase.create_unit("men_at_arms").attack + 1.5, "não vira DPS")
	assert_eq(champion.movement_points, sentinel.movement_points, "mesma mobilidade")
	assert_eq(champion.vision_range, sentinel.vision_range)
	assert_gt(champion.production_cost, sentinel.production_cost * 1.5, "custo excepcional")
	var power := func(d: UnitData): return d.attack + d.defense + d.max_hp * 0.15
	assert_gt(power.call(champion), power.call(sentinel))

func test_it_is_legendary_data_with_no_upkeep_and_a_distinct_provisional_model():
	var data := UnitDatabase.create_unit(CHAMPION)
	assert_true(data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_true(ResourceLoader.exists(data.model_scene_path), data.model_scene_path)
	assert_true(ResourceLoader.exists(data.animation_scene_path), data.animation_scene_path)
	assert_ne(data.model_scene_path, UnitDatabase.create_unit(SENTINEL).model_scene_path, "silhueta diferente da Sentinela")
	assert_lt(data.model_scale_multiplier, 2.0, "herói, não titã")

func test_it_is_registered_as_a_trainable_kind_and_named_for_every_race():
	assert_eq(UnitDatabase.PLAYER_TRAINABLE_KINDS.count(CHAMPION), 1)
	for race in ["human", "elf", "dwarf", "orc"]:
		assert_eq(RaceTheme.unit_name(CHAMPION, race), "Campeão Guardião", race)

func test_the_champion_can_be_created_and_shown_as_a_unit():
	var grid := _world()
	var unit := _unit(grid, _player(), CHAMPION, Vector2i(0, 0))
	assert_eq(unit.hp, 44.0)
	assert_true(unit.get_child_count() > 0)
	assert_true(V2LegendarySystem.is_legendary_unit(unit))

# --- Fora da cadeia convencional --------------------------------------------------------------------------

func test_the_champion_is_not_part_of_the_conventional_chain():
	assert_false(V2UnitLine.is_line_unit(CHAMPION))
	assert_eq(V2UnitLine.branch_of(CHAMPION), "", "não é forma da cadeia")
	assert_false(CHAMPION in V2UnitLine.unit_ids("guardian"))
	assert_eq(V2UnitLine.unit_ids("guardian"), [SHIELD, GUARDIAN, SENTINEL])

func test_the_sentinel_does_not_evolve_into_the_champion_and_the_champion_does_not_evolve():
	var grid := _world()
	var player := _player()
	var sentinel := _unit(grid, player, SENTINEL, Vector2i(0, 0))
	assert_eq(V2ResearchDatabase.node_for_unlock_id(SENTINEL).upgrade_to, "")
	assert_eq(V2UnitUpgrade.get_upgrade_target(sentinel), "", "a Sentinela é a forma máxima convencional")
	var champion := _unit(grid, player, CHAMPION, Vector2i(2, 0))
	assert_eq(V2UnitUpgrade.get_upgrade_target(champion), "")
	assert_eq(V2UnitUpgrade.upgrade_cost(champion), 0.0)
	for id in V2UnitLine.unit_ids("guardian"):
		assert_ne(V2ResearchDatabase.node_for_unlock_id(id).upgrade_to, CHAMPION, id)

func test_the_champion_never_replaces_the_sentinel_in_the_hall():
	var player := _player(9)
	var city := _standalone_city(player)
	assert_eq(V2UnitLine.resolve_trainable_form(player, SHIELD), SENTINEL)
	assert_eq(V2UnitLine.resolve_trainable_form(player, CHAMPION), "", "o Campeão não tem forma treinável na cadeia")
	assert_eq(V2UnitLine.highest_unlocked_form(player, "guardian"), SENTINEL)
	assert_true(city.can_train(SENTINEL), "o Salão segue oferecendo a Sentinela depois do N9")
	assert_true(city.can_train(CHAMPION), "e o Bastião oferece o Campeão, separado")
	assert_false(city.can_train(GUARDIAN))
	assert_false(city.can_train(SHIELD))

func test_the_champion_appears_only_in_the_legendary_production_not_in_the_conventional_form_list():
	var player := _player(9)
	var city := _standalone_city(player)
	var conventional := [SHIELD, GUARDIAN, SENTINEL].filter(func(k): return city.can_train(k))
	assert_eq(conventional, [SENTINEL])
	var legendary := UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(k): return V2LegendarySystem.is_legendary_kind(k) and city.can_train(k))
	assert_eq(legendary, [CHAMPION])

func test_producing_the_champion_requires_n9_the_mastery_building_and_a_free_slot():
	var no_n9 := _player(8)
	assert_false(_standalone_city(no_n9).can_train(CHAMPION), "sem N9")
	var player := _player(9)
	assert_false(_standalone_city(player, false).can_train(CHAMPION), "sem Bastião")
	assert_true(_standalone_city(player).can_train(CHAMPION), "N9 + Bastião + slot")

# --- Técnicas herdadas por Doutrina -----------------------------------------------------------------------------

func test_the_champion_inherits_both_guardian_techniques_from_the_doctrine():
	var grid := _world()
	var unit := _unit(grid, _player(9), CHAMPION, Vector2i(0, 0))
	assert_eq(V2UnitLine.doctrine_branch_of(CHAMPION), "guardian")
	assert_eq(V2TechniqueRuntime.active_techniques_for_unit(unit).map(func(t): return t.id), [WALL])
	assert_eq(V2TechniqueRuntime.passive_techniques_for_unit(unit).map(func(t): return t.id), [BRACE])
	assert_true(V2TechniqueRuntime.can_use(unit, WALL))
	assert_true(V2TechniqueRuntime.activate(unit, WALL))

func test_the_technique_data_does_not_mention_the_champion():
	for technique in V2DoctrineTechniqueDatabase.for_branch("guardian"):
		assert_eq(technique.doctrine_branch, "guardian", "elegibilidade por Doutrina")
	assert_eq(V2DoctrineTechniqueDatabase.for_branch("guardian").size(), 2, "nenhuma técnica nova nem duplicada")

func test_the_techniques_need_their_research_even_for_the_champion():
	var grid := _world()
	var unit := _unit(grid, _player(3), CHAMPION, Vector2i(0, 0))
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit), [], "sem N4/N6 nada")

func test_the_champion_gets_the_brace_spears_bonus_against_mounted():
	var grid := _world()
	var champion := _unit(grid, _player(9), CHAMPION, Vector2i(0, 0))
	var cavalry := _unit(grid, _player(0), "cavalry", Vector2i(1, 0))
	assert_almost_eq(UnitAbilities.attack_multiplier(champion, cavalry), 1.5, 0.0001)

func test_the_champion_wall_gives_the_normal_bonuses():
	var grid := _world()
	var mine := _player(9)
	var rival := _player(0)
	var champion := _unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 0))
	var before := _damage(grid, attacker, champion)
	V2TechniqueRuntime.activate(champion, WALL)
	assert_lt(_damage(grid, attacker, champion), before)
	assert_almost_eq(_damage(grid, attacker, champion), _expected(grid, champion, 1.35), 0.0001, "+35% próprio (Muralha)")

# --- Comando Defensivo ------------------------------------------------------------------------------------------

func test_the_command_aura_data_is_radius_2_and_plus_20_percent():
	var data := UnitDatabase.create_unit(CHAMPION)
	assert_true(data.has_aura())
	assert_eq(data.aura_name, "Comando Defensivo")
	assert_eq(data.aura_radius, 2)
	assert_almost_eq(data.aura_defense_bonus, 0.2, 0.0001)
	assert_false(UnitDatabase.create_unit(SENTINEL).has_aura(), "nenhuma outra unidade tem aura")

func test_an_ally_at_distance_1_and_2_receives_the_bonus_and_at_3_does_not():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var near := _unit(grid, mine, "archer", Vector2i(1, 0))
	var edge := _unit(grid, mine, "archer", Vector2i(-2, 0))
	var far := _unit(grid, mine, "archer", Vector2i(0, 3))
	var attacker := _striker(grid, rival, Vector2i(4, 0))
	assert_eq(HexMetrics.axial_distance(Vector2i(0, 0), near.coord), 1)
	assert_eq(HexMetrics.axial_distance(Vector2i(0, 0), edge.coord), 2)
	assert_eq(HexMetrics.axial_distance(Vector2i(0, 0), far.coord), 3)
	assert_almost_eq(V2UnitAuras.defense_multiplier(near), 1.0 + _aura_bonus(), 0.0001, "distância 1")
	assert_almost_eq(V2UnitAuras.defense_multiplier(edge), 1.0 + _aura_bonus(), 0.0001, "distância 2")
	assert_eq(V2UnitAuras.defense_multiplier(far), 1.0, "distância 3: nada")
	assert_almost_eq(_damage(grid, attacker, near), _expected(grid, near, 1.2), 0.0001)
	assert_almost_eq(_damage(grid, attacker, edge), _expected(grid, edge, 1.2), 0.0001)
	assert_almost_eq(_damage(grid, attacker, far), _expected(grid, far, 1.0), 0.0001)

func test_the_champion_does_not_buff_itself():
	var grid := _world()
	var champion := _unit(grid, _player(), CHAMPION, Vector2i(0, 0))
	assert_eq(V2UnitAuras.defense_multiplier(champion), 1.0)
	var attacker := _striker(grid, _player(0), Vector2i(1, 0))
	assert_almost_eq(_damage(grid, attacker, champion), _expected(grid, champion, 1.0), 0.0001, "sem +20% no próprio Campeão")

func test_enemies_and_units_of_other_owners_get_nothing():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var enemy := _unit(grid, rival, "archer", Vector2i(1, 0))
	assert_eq(V2UnitAuras.defense_multiplier(enemy), 1.0)

func test_a_dead_or_removed_champion_gives_nothing():
	var grid := _world()
	var mine := _player()
	var champion := _unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0))
	assert_gt(V2UnitAuras.defense_multiplier(ally), 1.0)
	champion.hp = 0.0
	assert_eq(V2UnitAuras.defense_multiplier(ally), 1.0, "morto")
	champion.hp = 44.0
	assert_gt(V2UnitAuras.defense_multiplier(ally), 1.0)
	grid.remove_unit(champion)
	assert_eq(V2UnitAuras.defense_multiplier(ally), 1.0, "removido")

func test_the_bonus_follows_the_real_position_moving_out_and_back_in():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var ally := _unit(grid, mine, "archer", Vector2i(2, 0))
	var attacker := _striker(grid, rival, Vector2i(4, -1))
	var inside := _damage(grid, attacker, ally)
	grid.move_unit(ally, Vector2i(3, 0), 1.0) # sai do raio
	var outside := _damage(grid, attacker, ally)
	assert_gt(outside, inside, "perdeu o bônus sozinho")
	assert_almost_eq(outside, _expected(grid, ally, 1.0), 0.0001)
	grid.move_unit(ally, Vector2i(2, 0), 1.0) # volta
	assert_almost_eq(_damage(grid, attacker, ally), inside, 0.0001, "voltou: recebe de novo")

func test_prediction_and_real_resolution_agree_for_an_ally_in_the_aura():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var ally := _unit(grid, mine, GUARDIAN, Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(2, 0))
	var predicted := _damage(grid, attacker, ally)
	assert_almost_eq(predicted, _expected(grid, ally, 1.2), 0.0001)
	var hp := ally.hp
	CombatResolver.resolve(attacker, ally, grid)
	assert_almost_eq(hp - ally.hp, predicted, 0.0001, "a aura chegou à resolução real")

func test_two_champions_never_stack_the_same_aura():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var first := _unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var second := _unit(grid, mine, CHAMPION, Vector2i(2, 0)) # fixture: o slot global impediria na prática
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 2))
	assert_almost_eq(V2UnitAuras.defense_multiplier(ally), 1.2, 0.0001, "+20% uma vez só, não +44%")
	assert_almost_eq(_damage(grid, attacker, ally), _expected(grid, ally, 1.2), 0.0001)
	assert_false(is_equal_approx(V2UnitAuras.defense_multiplier(ally), 1.2 * 1.2))
	assert_almost_eq(V2UnitAuras.defense_multiplier(first), 1.2, 0.0001, "um Campeão protege o outro, uma única vez")
	assert_almost_eq(V2UnitAuras.defense_multiplier(second), 1.2, 0.0001)

func test_the_aura_is_not_a_saved_status_or_a_technique():
	var grid := _world()
	var mine := _player()
	var champion := _unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0))
	assert_gt(V2UnitAuras.defense_multiplier(ally), 1.0)
	assert_true(ally.magic_status.is_empty(), "nenhum estado aplicado ao aliado")
	assert_true(champion.magic_status.is_empty())
	assert_true(champion.magic_cooldowns.is_empty(), "nenhuma recarga")
	assert_null(V2DoctrineTechniqueDatabase.get_technique("v2_aura_command"), "não é Técnica de Doutrina")

func test_the_aura_still_works_after_a_research_reset_because_it_is_intrinsic():
	var grid := _world()
	var mine := _player()
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0))
	mine.v2_research.reset()
	assert_gt(V2UnitAuras.defense_multiplier(ally), 1.0, "não depende de pesquisa")

# --- Combinação com a Muralha de Escudos ---------------------------------------------------------------------------

func test_command_aura_and_wall_formation_are_distinct_origins_and_multiply():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	_unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var wall_unit := _unit(grid, mine, SENTINEL, Vector2i(2, 0))
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0)) # no raio do Campeão E adjacente à unidade em Muralha
	var attacker := _striker(grid, rival, Vector2i(1, 2))
	assert_true(V2TechniqueRuntime.activate(wall_unit, WALL))
	var wall_factor := V2TechniqueRuntime.defense_multiplier(ally, grid)
	var aura_factor := V2UnitAuras.defense_multiplier(ally)
	var wall_bonus := V2DoctrineTechniqueDatabase.get_technique(WALL).adjacent_ally_defense_bonus
	assert_almost_eq(wall_factor, 1.0 + wall_bonus, 0.0001, "formação da Muralha: +15%")
	assert_almost_eq(aura_factor, 1.0 + _aura_bonus(), 0.0001, "Comando Defensivo: +20%")
	# Composição documentada: origens diferentes MULTIPLICAM; cada uma conta uma vez.
	assert_almost_eq(_damage(grid, attacker, ally), _expected(grid, ally, wall_factor * aura_factor), 0.0001)
	assert_almost_eq(wall_factor * aura_factor, 1.15 * 1.2, 0.0001)

func test_neither_origin_duplicates_itself_with_two_walls_and_two_champions():
	var grid := _world()
	var mine := _player()
	_unit(grid, mine, CHAMPION, Vector2i(-1, 0))
	_unit(grid, mine, CHAMPION, Vector2i(3, 0))
	var wall_a := _unit(grid, mine, SENTINEL, Vector2i(0, 1))
	var wall_b := _unit(grid, mine, SENTINEL, Vector2i(2, -1))
	var ally := _unit(grid, mine, "archer", Vector2i(1, 0))
	V2TechniqueRuntime.activate(wall_a, WALL)
	V2TechniqueRuntime.activate(wall_b, WALL)
	assert_almost_eq(V2TechniqueRuntime.defense_multiplier(ally, grid), 1.15, 0.0001, "duas Muralhas: +15% uma vez")
	assert_almost_eq(V2UnitAuras.defense_multiplier(ally), 1.2, 0.0001, "dois Campeões: +20% uma vez")

func test_a_champion_with_its_own_wall_keeps_its_own_35_percent_and_gets_no_self_aura():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var champion := _unit(grid, mine, CHAMPION, Vector2i(0, 0))
	var attacker := _striker(grid, rival, Vector2i(1, 0))
	V2TechniqueRuntime.activate(champion, WALL)
	assert_eq(V2UnitAuras.defense_multiplier(champion), 1.0)
	assert_almost_eq(V2TechniqueRuntime.defense_multiplier(champion, grid), 1.35, 0.0001)
	assert_almost_eq(_damage(grid, attacker, champion), _expected(grid, champion, 1.35), 0.0001)

# --- UI / inspetor ------------------------------------------------------------------------------------------------

func test_the_owner_lines_show_the_legendary_passive_and_the_normal_techniques():
	var grid := _world()
	var champion := _unit(grid, _player(9), CHAMPION, Vector2i(0, 0))
	assert_eq(V2UnitAuras.lines(champion), ["Passiva Lendária — Comando Defensivo", "Aliados em raio 2 recebem +20% de Defesa."])
	assert_eq(V2TechniqueRuntime.passive_lines(champion), ["Passiva — Preparar Lanças", "+50% de dano de ataque básico contra unidades montadas."])
	assert_eq(V2UnitAuras.lines(_unit(grid, _player(9), SENTINEL, Vector2i(3, 0))), [])

func test_the_public_inspector_facts_show_legendary_and_the_aura_but_not_the_research():
	var grid := _world()
	var champion := _unit(grid, _player(9), CHAMPION, Vector2i(0, 0))
	var traits := TileInspector.unit_traits(champion)
	assert_true(traits.has("Lendária"))
	assert_true(traits.any(func(t): return t.begins_with("Comando Defensivo")), str(traits))
	assert_false(traits.any(func(t): return t.contains("Preparar Lanças") or t.contains("Muralha")), "a pesquisa privada não vaza")
	assert_false(TileInspector.unit_traits(_unit(grid, _player(9), SENTINEL, Vector2i(3, 0))).has("Lendária"))
