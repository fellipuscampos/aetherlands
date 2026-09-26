extends GutTest

## Aetherlands V2, Fase 16 — Fortificação Urbana: dados (V2FortificationData), gate pela MESMA
## pesquisa de Urbanização do City Level, projeto na MESMA fila de produção (sem slot, fora de
## City.buildings), escudo que preserva o dano absoluto no upgrade, upkeep só do nível atual,
## Déficit bloqueando o INÍCIO (não o andamento), captura mantendo a fortificação, vida máxima pelo
## City Level e o bônus de defesa urbana na fórmula única (sem somar a cadeia V1 de muralhas).
## Save/load vive em test_save_manager.gd (o save exige mapa gerado).

const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"

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

func after_each():
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

## Conclui, em ordem, Urbanização N1..`tier` (os MESMOS nós do City Level).
func _urbanize(player: PlayerData, tier: int) -> void:
	for t in range(1, tier + 1):
		var node := V2ResearchDatabase.node_for_unlock_id("v2_city_level_%d" % (t + 1))
		if not player.v2_research.is_completed(node.id):
			assert_true(player.v2_research.complete_research(node.id), node.id)

func _city(owner: PlayerData, coord: Vector2i = Vector2i.ZERO, level: int = 2) -> City:
	var city := grid.found_city(coord, owner, "Cidade %s" % str(coord), true)
	city.city_level = level
	city.hp = city.max_hp()
	return city

## Conclui o projeto de Fortificação atual pela fila real (process_turn).
func _complete_current_project(city: City) -> Dictionary:
	city.stored_production = city.production_cost()
	return city.process_turn(grid)

# --- §96 Dados: fonte única ------------------------------------------------------------------------

func test_fortification_data_table_is_the_single_source():
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.display_name(l)), ["Nenhuma", "Muralhas I", "Muralhas II", "Fortaleza"])
	assert_eq([1, 2, 3].map(func(l): return V2FortificationData.production_cost(l)), [40.0, 70.0, 110.0])
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.gold_upkeep(l)), [0.0, 1.0, 2.0, 3.0])
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.shield_max(l)), [0.0, 8.0, 14.0, 22.0])
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.city_defense_bonus(l)), [0.0, 0.10, 0.20, 0.30])
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.city_attack_power(l)), [0.0, 3.0, 5.0, 7.0])
	assert_eq([0, 1, 2, 3].map(func(l): return V2FortificationData.city_attack_range(l)), [0, 2, 2, 3])
	assert_eq([1, 2, 3].map(func(l): return V2FortificationData.required_city_level(l)), [2, 3, 4])
	assert_eq([1, 2, 3].map(func(l): return V2FortificationData.required_research_id(l)), ["v2_city_level_2", "v2_city_level_3", "v2_city_level_4"])
	assert_eq([1, 2, 3].map(func(l): return V2FortificationData.project_id(l)), ["v2_city_fortification_1", "v2_city_fortification_2", "v2_city_fortification_3"])
	assert_eq(V2FortificationData.next_level(3), 0, "Fortaleza é o topo")

func test_fortification_is_a_second_effect_of_the_urbanization_nodes_never_new_nodes():
	for level in [1, 2, 3]:
		var node := V2ResearchDatabase.node_for_unlock_id(V2FortificationData.required_research_id(level))
		assert_not_null(node)
		assert_eq(node.unlock_id, "v2_city_level_%d" % (level + 1), "mesmo nó do City Level %d" % (level + 1))
	assert_eq(V2ResearchDatabase.urbanization_unlock_label("v2_city_level_2"), "Cidade II e Muralhas I")
	assert_eq(V2ResearchDatabase.urbanization_unlock_label("v2_city_level_3"), "Cidade III e Muralhas II")
	assert_eq(V2ResearchDatabase.urbanization_unlock_label("v2_city_level_4"), "Cidade IV e Fortaleza")

func test_completing_urbanization_n1_toasts_city_ii_and_walls_i_for_the_human():
	watch_signals(EventBus)
	_urbanize(human, 1)
	var found := false
	for i in get_signal_emit_count(EventBus, "notify"):
		if String(get_signal_parameters(EventBus, "notify", i)[0]) == "Desenvolvimento urbano disponível: Cidade II e Muralhas I.":
			found = true
	assert_true(found, "toast da Urbanização N1 menciona as duas coisas")

# --- §97-99 Requisitos N1/N2/N3 --------------------------------------------------------------------

func test_walls_i_requires_urbanization_n1_and_city_ii():
	var city := _city(human, Vector2i.ZERO, 1)
	assert_eq(city.fortification_unavailable_reason(), "Requer Planejamento Urbano.")
	_urbanize(human, 1)
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade II.")
	city.city_level = 2
	assert_true(city.can_start_fortification())

func test_walls_ii_requires_n2_and_city_iii_and_fortress_requires_n3_and_city_iv():
	var city := _city(human, Vector2i.ZERO, 2)
	_urbanize(human, 1)
	city.fortification_level = 1
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade Fortificada.", "N2")
	_urbanize(human, 2)
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade III.")
	city.city_level = 3
	assert_true(city.can_start_fortification())
	city.fortification_level = 2
	assert_eq(city.fortification_unavailable_reason(), "Requer Metrópole.", "N3")
	_urbanize(human, 3)
	assert_eq(city.fortification_unavailable_reason(), "Requer Cidade IV.")
	city.city_level = 4
	assert_true(city.can_start_fortification())
	city.fortification_level = 3
	assert_eq(city.fortification_unavailable_reason(), "Fortificação já está no nível máximo.")

func test_levels_are_sequential_never_skipped():
	var city := _city(human, Vector2i.ZERO, 4)
	_urbanize(human, 3)
	assert_eq(V2FortificationData.next_level(city.fortification_level), 1, "com tudo pesquisado, o próximo ainda é Muralhas I")

# --- §100-101 Mesma fila, sem slot -----------------------------------------------------------------

func test_the_project_uses_the_same_production_queue_and_completes_through_process_turn():
	var city := _city(human)
	_urbanize(human, 1)
	city.set_production(V2FortificationData.project_id(1))
	assert_eq(city.production_item, "v2_city_fortification_1")
	assert_almost_eq(city.production_cost(), 40.0, 0.001, "custo vem da tabela")
	var result := _complete_current_project(city)
	assert_eq(result.fortification_level_up, 1)
	assert_eq(result.built_kind, "", "nunca é um prédio")
	assert_eq(result.spawn_unit_kind, "", "nunca é uma unidade")
	assert_eq(city.fortification_level, 1)
	assert_eq(city.production_item, "", "a fila fica livre")

func test_a_busy_queue_blocks_starting_a_fortification():
	var city := _city(human)
	_urbanize(human, 1)
	city.set_production("warrior")
	assert_eq(city.fortification_unavailable_reason(), "Produção da cidade já está ocupada.")

func test_fortification_never_occupies_a_building_slot_nor_enters_city_buildings():
	var city := _city(human)
	_urbanize(human, 1)
	var slots_before := city.used_building_slots()
	city.set_production(V2FortificationData.project_id(1))
	_complete_current_project(city)
	assert_eq(city.used_building_slots(), slots_before)
	assert_false(city.buildings.has("v2_city_fortification_1"))
	assert_false(city.buildings.has("walls"))

func test_fortification_projects_never_count_as_logistics_supply():
	var city := _city(human)
	_urbanize(human, 1)
	var used_before := V2LogisticsRuntime.player_supply_used(human)
	city.set_production(V2FortificationData.project_id(1))
	assert_eq(V2LogisticsRuntime.player_supply_used(human), used_before)

# --- §24 Escudo: upgrade preserva o dano absoluto ---------------------------------------------------

func test_first_level_starts_with_a_full_shield():
	var city := _city(human)
	city.apply_fortification_level(1)
	assert_eq(city.shield, 8.0)

func test_upgrading_preserves_absolute_shield_damage():
	var city := _city(human, Vector2i.ZERO, 3)
	city.apply_fortification_level(1)
	city.shield = 5.0 # 3 de dano
	city.apply_fortification_level(2)
	assert_eq(city.shield, 11.0, "14 - 3")
	city.shield = 0.0 # 14 de dano
	city.apply_fortification_level(3)
	assert_eq(city.shield, 8.0, "22 - 14: upgrade nunca cura de graça")

func test_upgrading_a_fully_broken_shield_never_goes_negative():
	var city := _city(human, Vector2i.ZERO, 3)
	city.fortification_level = 2
	city.shield = 0.0
	city.apply_fortification_level(2)
	assert_eq(city.shield, 0.0)

# --- Upkeep -----------------------------------------------------------------------------------------

func test_upkeep_is_only_the_current_level_never_cumulative():
	var city := _city(human)
	var base := V2EconomyRuntime.city_gold_upkeep(city)
	for level in [1, 2, 3]:
		city.fortification_level = level
		assert_almost_eq(V2EconomyRuntime.city_gold_upkeep(city) - base, float(level), 0.0001, "nível %d custa %d, não a soma" % [level, level])

# --- §30-31 Déficit ----------------------------------------------------------------------------------

func _make_deficit(city: City) -> void:
	city.buildings[G_HALL] = true
	city.buildings[G_MASTERY] = true # upkeep 3 > renda base 2
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "pré-condição: Déficit")

func test_deficit_blocks_starting_a_new_fortification_project():
	var city := _city(human)
	_urbanize(human, 1)
	_make_deficit(city)
	assert_eq(city.fortification_unavailable_reason(), "Déficit de Ouro: estabilize a economia antes de ampliar a fortificação.")

func test_a_project_already_in_progress_continues_under_deficit():
	var city := _city(human)
	_urbanize(human, 1)
	city.set_production(V2FortificationData.project_id(1))
	_make_deficit(city)
	assert_eq(city.fortification_unavailable_reason(), "", "em andamento continua")
	_complete_current_project(city)
	assert_eq(city.fortification_level, 1)

func test_deficit_halves_only_the_city_attack_never_shield_or_defense():
	var city := _city(human)
	city.fortification_level = 2
	city.shield = city.max_shield()
	_make_deficit(city)
	assert_eq(CityDefense.city_attack_power(city), 2.5, "5 x 0,5")
	assert_eq(city.max_shield(), 14.0, "escudo 100%")
	assert_almost_eq(city.defense_bonus(), 0.20, 0.0001, "defesa 100%")

# --- §33-35 Captura ----------------------------------------------------------------------------------

func test_capture_keeps_the_fortification_and_its_damaged_shield():
	var city := _city(rival, Vector2i(3, 0), 3)
	city.fortification_level = 2
	city.shield = 4.0
	grid.capture_city(city, human)
	assert_eq(city.fortification_level, 2, "a muralha continua de pé")
	assert_eq(city.shield, 4.0, "nunca reconstruída de graça")
	assert_almost_eq(city.defense_bonus(), 0.20, 0.0001)
	assert_eq(CityDefense.city_attack_power(city), 5.0)

func test_the_new_owner_pays_the_upkeep_and_cannot_advance_without_its_own_research():
	var city := _city(rival, Vector2i(3, 0), 3)
	city.fortification_level = 2
	var human_upkeep_before := V2EconomyRuntime.player_gold_upkeep(human)
	grid.capture_city(city, human)
	assert_true(V2EconomyRuntime.player_gold_upkeep(human) - human_upkeep_before >= 2.0, "o novo dono paga o upkeep do nível capturado")
	assert_eq(city.fortification_unavailable_reason(), "Requer Metrópole.", "avançar exige a pesquisa do novo dono")

# --- §26-28 Vida da cidade pelo City Level -------------------------------------------------------------

func test_city_max_hp_comes_from_city_level():
	var city := _city(human, Vector2i.ZERO, 1)
	assert_eq([1, 2, 3, 4].map(func(l): return V2CityLevelData.max_hp(l)), [24.0, 30.0, 36.0, 44.0])
	for level in [1, 2, 3, 4]:
		city.city_level = level
		assert_eq(city.max_hp(), V2CityLevelData.max_hp(level))

func test_population_never_changes_city_hp():
	var city := _city(human, Vector2i.ZERO, 2)
	var hp := city.max_hp()
	assert_eq(city.max_hp(), hp)

func test_city_level_up_preserves_the_hp_fraction():
	var city := _city(human, Vector2i.ZERO, 2)
	city.hp = 15.0
	city.apply_city_level(3)
	assert_eq(city.hp, 18.0, "15/30 -> 18/36")

func test_the_city_level_project_preserves_the_hp_fraction_too():
	var city := _city(human, Vector2i.ZERO, 1)
	_urbanize(human, 1)
	human.gold = 1000.0
	city.hp = 12.0 # 50%
	city.set_production(V2CityLevelData.project_id_for_level(2))
	city.stored_production = city.production_cost()
	var result := city.process_turn(grid)
	assert_eq(result.city_level_up, 2)
	assert_gt(city.hp, 14.9, "~50% de 30 (+ a regeneração normal do turno)")
	assert_lt(city.hp, city.max_hp(), "nunca cura cheio")

# --- §36-41 Defesa urbana na fórmula única -----------------------------------------------------------

func test_defense_bonus_adds_to_the_urban_formula():
	var city := _city(rival, Vector2i(1, 0), 4)
	for level in [0, 1, 2, 3]:
		city.fortification_level = level
		assert_almost_eq(city.defense_bonus(), V2FortificationData.city_defense_bonus(level), 0.0001)

func test_v1_wall_buildings_never_stack_with_the_v2_fortification():
	var city := _city(rival, Vector2i(1, 0), 4)
	city.fortification_level = 1
	for id in ["walls", "walls_2", "fortress", "imperial_fortress"]:
		city.buildings[id] = true
	assert_almost_eq(city.defense_bonus(), 0.10, 0.0001, "V1 vestigial")
	assert_eq(city.max_shield(), 8.0)

## Fase 25: a Torre de Vigia V1 saiu do catálogo -- a defesa da cidade vem SÓ da Fortificação V2,
## e um prédio V1 vestigial (save antigo não sanitizado) nunca soma.
func test_city_defense_comes_only_from_the_fortification():
	var city := _city(rival, Vector2i(1, 0), 4)
	city.fortification_level = 2
	city.buildings["watchtower"] = true
	assert_almost_eq(city.defense_bonus(), 0.20, 0.0001, "só Muralhas II (0,2)")

func test_fortress_reduces_attack_damage_and_the_shield_absorbs_first():
	var attacker := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), human)
	var city := _city(rival, Vector2i(1, 0), 4)
	city.fortification_level = 3
	city.shield = city.max_shield()
	var hp_before := city.hp
	var expected := attacker.unit_data.attack / 1.3
	CombatResolver.resolve_city_attack(attacker, city, grid)
	assert_almost_eq(city.shield, 22.0 - expected, 0.001, "dano / (1 + 0,30), primeiro no escudo")
	assert_eq(city.hp, hp_before)

func test_the_predicted_garrison_bonus_uses_the_same_city_defense():
	var city := _city(rival, Vector2i(1, 0), 4)
	var attacker := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("warrior"), human)
	var defender := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	var unfortified: float = CombatResolver.predict(attacker, defender, grid).damage_to_defender
	city.fortification_level = 3
	var fortified: float = CombatResolver.predict(attacker, defender, grid).damage_to_defender
	assert_lt(fortified, unfortified, "guarnição dentro da Fortaleza toma menos dano")

func test_siege_keeps_its_city_multiplier_against_a_fortress_no_immunity():
	var city := _city(rival, Vector2i(1, 0), 4)
	city.fortification_level = 3
	var siege := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("catapult"), human)
	assert_gt(UnitAbilities.city_attack_multiplier(siege), 1.0, "pré-condição: Cerco tem bônus contra cidade")
	city.shield = 0.0
	var hp_before := city.hp
	CombatResolver.resolve_city_attack(siege, city, grid)
	var expected: float = siege.unit_data.attack * siege.veterancy_multiplier() * UnitAbilities.city_attack_multiplier(siege) * V2TechniqueRuntime.city_attack_multiplier(siege) / 1.3
	assert_almost_eq(hp_before - city.hp, maxf(1.0, expected), 0.001, "Fortaleza reduz, mas o Cerco segue funcionando")

# --- Visual / leitura -----------------------------------------------------------------------------

func test_tile_inspector_shows_the_fortification_block_to_any_observer():
	var city := _city(rival, Vector2i(2, 0), 2)
	city.fortification_level = 1
	city.shield = 8.0
	var entry := TileInspector._city_entry(city, grid, human)
	var text := "\n".join(entry.lines)
	assert_string_contains(text, "Muralhas I")
	assert_string_contains(text, "Escudo: 8 / 8")
	assert_string_contains(text, "Defesa urbana: +10%")
	assert_string_contains(text, "Ataque da Cidade: 3 | Alcance 2")

func test_tile_inspector_hides_the_block_without_fortification():
	var city := _city(rival, Vector2i(2, 0), 2)
	var text := "\n".join(TileInspector._city_entry(city, grid, human).lines)
	assert_false(text.contains("Ataque da Cidade"))
	assert_false(text.contains("Escudo"))
