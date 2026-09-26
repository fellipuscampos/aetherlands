extends GutTest

## Sistema GLOBAL de Unidade Lendária (V2LegendarySystem, Aetherlands V2 Fase 6): reconhecimento
## por metadata/traço (nunca por nome/id), slot único por civilização ATIVO ou EM PRODUÇÃO,
## derivado das unidades e das ordens de produção reais, reserva contra duas cidades ao mesmo
## tempo e defesa fail-closed. Lendárias de outras Doutrinas ainda não existem: os testes usam
## unidades de teste (fixtures) com o traço `legendary`.

const CHAMPION := "v2_legendary_guardian_champion"
const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"
const SENTINEL := "v2_unit_sentinel"
const FUTURE_LEGENDARIES := ["v2_legendary_shadow_master", "v2_legendary_siege_colossus"]

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _original_turn: int

func before_each():
	_original_turn = TurnManager.turn_number
	TurnManager.turn_number = 5

func after_each():
	TurnManager.turn_number = _original_turn
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

## Cidade com Salão e Bastião (pronta pra treinar a Lendária).
func _city(grid: HexGrid, player: PlayerData, coord: Vector2i) -> City:
	var city := grid.found_city(coord, player, "Cidade %s" % str(coord), true)
	city.city_level = 3
	city.buildings[HALL] = true
	city.buildings[MASTERY] = true
	# Aetherlands V2, Fase 15 — a Lendária custa 5 Suprimentos, acima até da capacidade base de
	# uma cidade sozinha (4); sem isto, o treino ficaria sempre bloqueado por capacidade, mesmo com
	# pesquisa/prédio/slot corretos (o assunto deste arquivo é o SLOT global, não Suprimentos).
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	# Prédios de treino/Maestria/Fazenda têm gold_upkeep e não há Mercado nesta cidade -- sem Ouro
	# de sobra a civilização entraria em Déficit sozinha, bloqueando o treino por um motivo alheio
	# ao slot Lendário (o assunto deste arquivo).
	if player.gold <= 0.0:
		player.gold = 1000.0
	return city

func _champion(grid: HexGrid, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(CHAMPION), player)
	assert_not_null(unit)
	return unit

## Lendária de OUTRA Doutrina, que ainda não existe: unidade de teste com o traço e um id qualquer.
func _fake_legendary(grid: HexGrid, player: PlayerData, coord: Vector2i, id: String = "v2_legendary_shadow_master") -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.visual_kind = id
	data.unit_name = "Lendária de teste"
	data.traits.append(UnitData.TRAIT_LEGENDARY)
	var unit := grid.spawn_unit(coord, data, player)
	assert_not_null(unit)
	return unit

# --- Reconhecimento (metadata / traço) ----------------------------------------------------------------

func test_the_champion_and_every_future_legendary_kind_are_recognized_by_metadata():
	assert_true(V2LegendarySystem.is_legendary_kind(CHAMPION))
	for id in FUTURE_LEGENDARIES:
		assert_true(V2LegendarySystem.is_legendary_kind(id), "%s (ainda sem unidade) já é reconhecida" % id)

func test_conventional_forms_buildings_and_v1_kinds_are_not_legendary():
	for kind in ["v2_unit_shieldbearer", "v2_unit_guardian", SENTINEL, MASTERY, HALL, "v2_technique_shield_wall", "warrior", "men_at_arms", "settler", "", "v2_inexistente"]:
		assert_false(V2LegendarySystem.is_legendary_kind(kind), kind)

func test_every_legendary_candidate_node_is_recognized_and_only_those():
	var recognized := 0
	for node in V2ResearchDatabase.all_nodes():
		if V2LegendarySystem.is_legendary_kind(node.unlock_id):
			assert_eq(node.unlock_type, "legendary_candidate", node.id)
			recognized += 1
	assert_eq(recognized, 6, "os seis N9")

func test_the_champion_data_carries_the_legendary_trait_and_the_sentinel_does_not():
	assert_true(UnitDatabase.create_unit(CHAMPION).has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(UnitDatabase.create_unit(SENTINEL).has_trait(UnitData.TRAIT_LEGENDARY))
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		assert_eq(UnitDatabase.create_unit(kind).has_trait(UnitData.TRAIT_LEGENDARY), kind in [CHAMPION, "v2_legendary_blade_hero", "v2_legendary_legend_hunter", "v2_legendary_griffon_rider", "v2_legendary_shadow_master", "v2_legendary_siege_colossus"], kind)

func test_a_unit_is_legendary_by_its_trait_not_by_name_or_id():
	var grid := _world()
	var player := _player()
	var fake := _fake_legendary(grid, player, Vector2i(0, 0), "qualquer_id_xyz")
	assert_true(V2LegendarySystem.is_legendary_unit(fake), "o traço basta, mesmo com id desconhecido")
	var impostor_data := UnitDatabase.create_unit("warrior")
	impostor_data.visual_kind = CHAMPION
	impostor_data.unit_name = "Campeão Guardião"
	var impostor := grid.spawn_unit(Vector2i(2, 0), impostor_data, player)
	assert_false(V2LegendarySystem.is_legendary_unit(impostor), "nome/id do Campeão sem o traço não classificam")
	assert_false(V2LegendarySystem.is_legendary_unit(null))

func test_the_limit_comes_from_the_global_constant_not_from_any_doctrine():
	assert_eq(V2LegendarySystem.max_active(), V2ResearchDatabase.MAX_ACTIVE_LEGENDARY_UNITS)
	assert_eq(V2LegendarySystem.max_active(), 1)

# --- Slot global (derivado) ----------------------------------------------------------------------------------

func test_an_empty_slot_is_available():
	var player := _player()
	assert_true(V2LegendarySystem.legendary_slot_available(player))
	assert_false(V2LegendarySystem.has_active_legendary(player))
	assert_null(V2LegendarySystem.active_legendary(player))
	assert_eq(V2LegendarySystem.slots_used(player), 0)

func test_an_active_champion_takes_the_slot_and_the_reason_says_so():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	assert_true(V2LegendarySystem.can_train_legendary(player, city, CHAMPION))
	var champion := _champion(grid, player, Vector2i(1, 0))
	assert_true(V2LegendarySystem.has_active_legendary(player))
	assert_same(V2LegendarySystem.active_legendary(player), champion)
	assert_false(V2LegendarySystem.legendary_slot_available(player, city))
	assert_false(V2LegendarySystem.can_train_legendary(player, city, CHAMPION))
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, CHAMPION), "Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização.")
	assert_false(city.can_train(CHAMPION), "o gate real da cidade também fecha")

func test_a_legendary_of_another_doctrine_blocks_the_champion_the_slot_is_global():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	var blade_hero := _fake_legendary(grid, player, Vector2i(2, 0))
	assert_true(V2LegendarySystem.has_active_legendary(player))
	assert_false(city.can_train(CHAMPION), "outra Lendária ativa bloqueia o Campeão")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)
	# ...e a regra vale para QUALQUER id lendário: com o Campeão ativo nenhuma outra Lendária pode nascer.
	grid.remove_unit(blade_hero)
	_champion(grid, player, Vector2i(2, 0))
	for id in FUTURE_LEGENDARIES:
		assert_false(V2LegendarySystem.spawn_allowed(player, id), id)

func test_the_slot_is_freed_when_the_legendary_dies_or_is_removed():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	var champion := _champion(grid, player, Vector2i(1, 0))
	assert_false(city.can_train(CHAMPION))
	champion.hp = 0.0 # morto, ainda na lista
	assert_true(city.can_train(CHAMPION), "hp <= 0 não ocupa slot")
	champion.hp = 44.0
	assert_false(city.can_train(CHAMPION))
	grid.remove_unit(champion) # qualquer remoção real (morte, dissolução, despawn)
	assert_true(city.can_train(CHAMPION), "removida do mapa: slot livre sem restart")
	assert_true(V2LegendarySystem.can_train_legendary(player, city, CHAMPION))

func test_a_real_combat_death_frees_the_slot():
	var grid := _world()
	var mine := _player()
	var rival := _player(0)
	var city := _city(grid, mine, Vector2i(0, 0))
	var champion := _champion(grid, mine, Vector2i(1, 0))
	champion.hp = 1.0
	var data := UnitDatabase.create_unit("warrior")
	data.attack = 60.0
	var killer := grid.spawn_unit(Vector2i(2, 0), data, rival)
	CombatResolver.resolve(killer, champion, grid)
	assert_false(V2LegendarySystem.has_active_legendary(mine), "morreu em combate")
	assert_true(city.can_train(CHAMPION))

func test_the_slot_is_per_civilization_and_a_rival_legendary_does_not_block_me():
	var grid := _world()
	var mine := _player()
	var rival := _player()
	var city := _city(grid, mine, Vector2i(0, 0))
	_champion(grid, rival, Vector2i(3, 0))
	assert_true(V2LegendarySystem.has_active_legendary(rival))
	assert_false(V2LegendarySystem.has_active_legendary(mine))
	assert_true(city.can_train(CHAMPION), "a Lendária do rival não me bloqueia")
	_champion(grid, mine, Vector2i(1, 0))
	assert_false(city.can_train(CHAMPION))
	assert_eq(V2LegendarySystem.active_legendary_units(rival).size(), 1)

func test_a_debug_research_reset_does_not_kill_the_legendary_and_the_slot_stays_taken():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	var champion := _champion(grid, player, Vector2i(1, 0))
	player.v2_research.reset()
	assert_true(is_instance_valid(champion) and champion.hp > 0.0, "a unidade existente não é destruída")
	assert_true(V2LegendarySystem.has_active_legendary(player), "e continua ocupando o slot")
	assert_false(V2LegendarySystem.legendary_slot_available(player, city))
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, CHAMPION), "Requer pesquisa: Campeão Guardião.", "sem N9 a pesquisa é o primeiro impedimento")

# --- Reserva por produção -----------------------------------------------------------------------------------

func test_a_legendary_in_production_reserves_the_slot_before_any_unit_exists():
	var grid := _world()
	var player := _player()
	var city_a := _city(grid, player, Vector2i(-4, 0))
	var city_b := _city(grid, player, Vector2i(4, 0))
	assert_true(city_a.can_train(CHAMPION))
	assert_true(city_b.can_train(CHAMPION))
	city_a.set_production(CHAMPION)
	assert_false(V2LegendarySystem.has_active_legendary(player), "ainda não há unidade nenhuma")
	assert_true(V2LegendarySystem.has_legendary_in_production(player))
	assert_false(city_b.can_train(CHAMPION), "a cidade B não pode iniciar outra")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city_b, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)
	assert_eq(V2LegendarySystem.cities_producing_legendary(player), [city_a])

func test_the_producing_city_is_not_blocked_by_its_own_order():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	city.set_production(CHAMPION)
	assert_true(city.can_train(CHAMPION), "a própria ordem não conta contra a própria cidade")
	assert_true(V2LegendarySystem.legendary_slot_available(player, city))
	assert_eq(V2LegendarySystem.slots_used(player), 1)
	assert_eq(V2LegendarySystem.slots_used(player, city), 0)

func test_switching_or_cancelling_the_order_frees_the_reservation():
	var grid := _world()
	var player := _player()
	var city_a := _city(grid, player, Vector2i(-4, 0))
	var city_b := _city(grid, player, Vector2i(4, 0))
	city_a.set_production(CHAMPION)
	assert_false(city_b.can_train(CHAMPION))
	city_a.set_production(SENTINEL) # troca de item
	assert_true(city_b.can_train(CHAMPION), "a reserva some junto com a ordem")
	city_a.set_production(CHAMPION)
	assert_false(city_b.can_train(CHAMPION))
	city_a.set_production("") # cancela
	assert_true(city_b.can_train(CHAMPION))

func test_losing_the_producing_city_frees_the_reservation():
	var grid := _world()
	var player := _player()
	var city_a := _city(grid, player, Vector2i(-4, 0))
	var city_b := _city(grid, player, Vector2i(4, 0))
	city_a.set_production(CHAMPION)
	assert_false(city_b.can_train(CHAMPION))
	player.cities.erase(city_a) # conquistada/destruída: some da lista da civilização
	assert_true(city_b.can_train(CHAMPION))

func test_a_legendary_of_any_doctrine_in_production_reserves_the_same_slot():
	var grid := _world()
	var player := _player()
	var city_a := _city(grid, player, Vector2i(-4, 0))
	var city_b := _city(grid, player, Vector2i(4, 0))
	city_a.production_item = FUTURE_LEGENDARIES[0] # ordem de outra Lendária (só o kind importa pra reserva)
	assert_true(V2LegendarySystem.has_legendary_in_production(player))
	assert_false(city_b.can_train(CHAMPION), "o slot é global entre ids distintos")

func test_a_rival_production_does_not_reserve_my_slot():
	var grid := _world()
	var mine := _player()
	var rival := _player()
	var my_city := _city(grid, mine, Vector2i(-4, 0))
	var rival_city := _city(grid, rival, Vector2i(4, 0))
	rival_city.set_production(CHAMPION)
	assert_true(my_city.can_train(CHAMPION))

func test_completion_turns_training_into_active_without_a_window_of_two_permissions():
	var grid := _world()
	var player := _player()
	var city_a := _city(grid, player, Vector2i(-4, 0))
	var city_b := _city(grid, player, Vector2i(4, 0))
	city_a.set_production(CHAMPION)
	assert_eq(V2LegendarySystem.slots_used(player), 1, "em treinamento")
	assert_false(city_b.can_train(CHAMPION))
	# Conclusão: a ordem sai da fila e a unidade entra no mesmo instante lógico (GameManager).
	city_a.production_item = ""
	_champion(grid, player, Vector2i(-3, 0))
	assert_eq(V2LegendarySystem.slots_used(player), 1, "agora ativa")
	assert_false(city_b.can_train(CHAMPION), "em nenhum momento o slot ficou livre")

# --- Requisitos / motivos ------------------------------------------------------------------------------------

func test_the_reasons_follow_research_then_building_then_slot():
	var grid := _world()
	var novice := _player(8) # N8 sem N9
	var city := grid.found_city(Vector2i(0, 0), novice, "Capital", true)
	assert_eq(V2LegendarySystem.unavailable_reason(novice, city, CHAMPION), "Requer pesquisa: Campeão Guardião.")
	var player := _player(9)
	var no_mastery := grid.found_city(Vector2i(-4, 0), player, "Sem Bastião", true)
	no_mastery.buildings[HALL] = true
	assert_eq(V2LegendarySystem.unavailable_reason(player, no_mastery, CHAMPION), "Requer Bastião de Maestria na cidade.")
	no_mastery.buildings[MASTERY] = true
	assert_eq(V2LegendarySystem.unavailable_reason(player, no_mastery, CHAMPION), "")

func test_slot_only_reason_appears_only_when_the_slot_is_the_single_blocker():
	var grid := _world()
	var player := _player(9)
	var city := _city(grid, player, Vector2i(0, 0))
	assert_eq(V2LegendarySystem.slot_only_reason(player, city, CHAMPION), "", "livre: nada a explicar")
	_champion(grid, player, Vector2i(1, 0))
	assert_eq(V2LegendarySystem.slot_only_reason(player, city, CHAMPION), V2LegendarySystem.SLOT_TAKEN_REASON)
	var no_mastery := grid.found_city(Vector2i(-4, 0), player, "Sem Bastião", true)
	assert_eq(V2LegendarySystem.slot_only_reason(player, no_mastery, CHAMPION), "", "faltando o prédio o impedimento principal é outro")
	assert_eq(V2LegendarySystem.slot_only_reason(player, city, SENTINEL), "", "não é Lendária")

func test_non_legendary_ids_are_untouched_by_the_slot():
	var grid := _world()
	var player := _player(9)
	var city := _city(grid, player, Vector2i(0, 0))
	_champion(grid, player, Vector2i(1, 0))
	assert_true(city.can_train(SENTINEL), "Sentinela segue treinável com a Lendária ativa")
	assert_eq(V2LegendarySystem.unavailable_reason(player, city, SENTINEL), "")
	assert_false(V2LegendarySystem.can_train_legendary(player, city, SENTINEL), "não é Lendária")

# --- Fail-closed na conclusão ---------------------------------------------------------------------------------

func test_spawn_is_refused_when_a_legendary_is_already_active():
	var grid := _world()
	var player := _player()
	assert_true(V2LegendarySystem.spawn_allowed(player, CHAMPION))
	_champion(grid, player, Vector2i(1, 0))
	assert_false(V2LegendarySystem.spawn_allowed(player, CHAMPION))
	assert_false(V2LegendarySystem.spawn_allowed(player, FUTURE_LEGENDARIES[1]), "qualquer Lendária")
	assert_true(V2LegendarySystem.spawn_allowed(player, SENTINEL), "não-Lendária sempre pode")

func test_refusing_a_spawn_refunds_the_cost_logs_a_clear_error_and_creates_nothing():
	var grid := _world()
	var player := _player()
	var city := _city(grid, player, Vector2i(0, 0))
	var before := player.units.size()
	city.stored_production = 5.0
	V2LegendarySystem.refuse_spawn(city, CHAMPION, false)
	assert_push_error("não nasceu")
	assert_eq(city.stored_production, 5.0 + UnitDatabase.create_unit(CHAMPION).production_cost, "o custo volta pra cidade")
	assert_eq(player.units.size(), before, "nenhuma unidade criada")

func test_the_system_has_no_per_frame_hook_and_no_saved_flag():
	var system := V2LegendarySystem.new()
	assert_false(system.has_method("_process"))
	assert_false(system.has_method("_physics_process"))
	var names: Array = PlayerData.new(CivilizationData.new()).get_property_list().map(func(p): return p.name)
	for forbidden in ["legendary_slot_used", "legendary_slot", "has_legendary", "legendary_reserved"]:
		assert_false(forbidden in names, "%s seria um segundo estado que pode dessincronizar" % forbidden)

func _code_of(path: String) -> String:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return "\n".join(lines)

func test_the_system_never_hardcodes_the_champion_or_any_legendary_id():
	for path in ["res://scripts/core/V2LegendarySystem.gd", "res://scripts/core/V2UnitAuras.gd"]:
		var source := _code_of(path)
		for forbidden in ["guardian_champion", "blade_hero", "legend_hunter", "griffon_rider", "shadow_master", "siege_colossus", "v2_unit_", "v2_legendary_"]:
			assert_false(source.contains(forbidden), "%s não pode hardcodar %s" % [path, forbidden])
