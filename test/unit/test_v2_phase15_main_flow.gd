extends GutTest

## Aetherlands V2, Fase 15 — TESTE PRINCIPAL DE INTEGRAÇÃO (§116), fluxo completo de 43 passos num
## jogo REAL (mapa gerado, pesquisa por Conhecimento, construção por posicionamento + fim de turno,
## treino pela fila de produção, Ouro creditado/debitado por TurnManager.end_turn, save/load de
## verdade). O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1
## turno — nenhum atalho de economia. Atalho declarado: City Level III e Pontos de Anexação são
## concedidos direto (o projeto de City Level é da Fase 13 e já tem fluxo próprio), pra sobrar
## território/slots pros oito prédios e três recursos deste fluxo.

const TEST_SAVE_PATH := "user://test_v2_phase15_main_flow_savegame.json"
const WORKSHOP := "v2_building_workshop"
const FARM := "v2_building_farm"
const MARKET := "v2_building_market"
const ACADEMY := "v2_building_academy"
const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"
const GUARDIAN := "v2_unit_guardian" # N5, custo 2
const BUILDER := "v2_unit_builder"
const WALL := "v2_technique_shield_wall"
const BRACE := "v2_technique_brace_spears"
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []
var _reserved: Array[Vector2i] = []

var _original_state
var _original_players: Array[PlayerData]
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_hex_grid: HexGrid
var _original_rival_count: int
var _original_map_width: int
var _original_map_height: int
var _original_turn_number: int
var _original_turn_player_index: int
var _original_difficulty: String
var _original_human_race: String
var _original_debug_mode: bool
var _original_stagger_ai_turns: bool
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int
var _original_current_save_slot: String
var _original_kingdom_name: String

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_hex_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_map_width = GameManager.map_width
	_original_map_height = GameManager.map_height
	_original_turn_number = TurnManager.turn_number
	_original_turn_player_index = TurnManager.current_player_index
	_original_difficulty = GameManager.difficulty
	_original_human_race = GameManager.human_race
	_original_debug_mode = GameManager.debug_mode
	_original_stagger_ai_turns = GameManager.stagger_ai_turns
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	_original_current_save_slot = GameManager.current_save_slot
	_original_kingdom_name = GameManager.human_kingdom_name
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	GameManager.stagger_ai_turns = false
	GameManager.human_race = "human"
	GameManager.rival_count = 2
	GameManager.map_width = MAP_WIDTH
	GameManager.map_height = MAP_HEIGHT
	GameManager.debug_mode = true
	_reserved.clear()

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
	for player in _players_to_release:
		player.release_relations()
	_players_to_release.clear()
	SaveManager.delete_save(TEST_SAVE_PATH)
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.hex_grid = _original_hex_grid
	GameManager.rival_count = _original_rival_count
	GameManager.map_width = _original_map_width
	GameManager.map_height = _original_map_height
	TurnManager.turn_number = _original_turn_number
	TurnManager.current_player_index = _original_turn_player_index
	GameManager.difficulty = _original_difficulty
	GameManager.human_race = _original_human_race
	GameManager.debug_mode = _original_debug_mode
	GameManager.stagger_ai_turns = _original_stagger_ai_turns
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	GameManager._ai_batch_timer = 0.0
	GameManager.current_save_slot = _original_current_save_slot
	GameManager.human_kingdom_name = _original_kingdom_name
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id
	for grid in _hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_hex_grids.clear()

# --- Helpers (mesmo roteiro dos fluxos das Doutrinas) ----------------------------------------------

func _new_game() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_WIDTH, MAP_HEIGHT, 555)
	_hex_grids.append(grid)
	GameManager.start_new_game(grid)
	# Esta fixture preserva os números exatos do fluxo da Fase 15. A identidade racial
	# da Fase 26 tem cobertura própria; aqui uma raça desconhecida é deliberadamente neutra.
	GameManager.human_player.civ.race = "phase15_neutral_fixture"
	return grid

func _found_human_city(grid: HexGrid) -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			var city := WorldSetup.found_city_from_settler(grid, unit)
			assert_not_null(city, "pré-condição: o Colonizador inicial funda a cidade")
			return city
	fail_test("o humano deveria começar com um Colonizador")
	return null

## Pesquisa real: seleciona o nó e credita o Conhecimento que ele custa (o mesmo caminho da renda).
func _research_unlock(state: V2ResearchState, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	_research_node(state, node.id)

func _research_node(state: V2ResearchState, node_id: String) -> void:
	if state.is_completed(node_id):
		return
	assert_true(state.select_research(node_id), "select %s" % node_id)
	state.add_knowledge(V2ResearchDatabase.get_node(node_id).cost)
	assert_true(state.is_completed(node_id), "concluiu %s" % node_id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")

func _units_of_kind(player: PlayerData, kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in player.units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

## Construção real: posicionamento num tile livre que NÃO seja um dos tiles de recurso reservados.
func _build(city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	var target := Vector2i(9999, 9999)
	for coord in SelectionManager.placeable_coords:
		if not coord in _reserved:
			target = coord
			break
	assert_ne(target, Vector2i(9999, 9999), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(target)
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

## Treino real pela fila de produção (mesmo gate da HUD). Antes, afasta as próprias unidades do
## anel da cidade (como o jogador faria): num mapa real com vários prédios, sem isso o spawn da
## unidade nova pode não ter tile livre.
func _train(city: City, kind: String) -> bool:
	if not GameManager.human_player.has_unlocked(kind) or not city.can_train(kind):
		return false
	_clear_city_ring(city)
	city.set_production(kind)
	_end_turn()
	return true

func _clear_city_ring(city: City) -> void:
	var grid: HexGrid = GameManager.hex_grid
	for unit in GameManager.human_player.units.duplicate():
		if not is_instance_valid(unit) or HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		for coord in HexMetrics.coords_within(city.coord, 5):
			var distance := HexMetrics.axial_distance(coord, city.coord)
			if distance >= 3 and grid.tiles.has(coord) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
				grid.teleport_unit(unit, coord)
				break

## Um tile próprio de terra, livre, sem prédio/unidade — vira tile de recurso reservado.
func _reserve_resource_tile(grid: HexGrid, city: City, resource_id: String) -> Vector2i:
	for coord in city.owned_tiles:
		if coord == city.coord or coord in _reserved:
			continue
		if WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_building_at(coord) == null and not grid.is_tile_building_site(coord):
			grid.get_tile(coord).resource = resource_id
			_reserved.append(coord)
			return coord
	fail_test("sem tile livre pro recurso %s" % resource_id)
	return Vector2i(9999, 9999)

func _improve_with(grid: HexGrid, builder: Unit, coord: Vector2i) -> void:
	grid.teleport_unit(builder, coord)
	builder.movement_left = builder.unit_data.movement_points
	SelectionManager._select_unit(builder)
	SelectionManager.improve_resource_with_selected()

# --- O fluxo -----------------------------------------------------------------------------------------

func test_phase15_main_integration_flow_across_save_and_load():
	# 1-2. Nova partida, fundar cidade.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var city := _found_human_city(grid)
	city.city_level = 3
	city.annexation_points = 20

	# 3-4. Pesquisa Infraestrutura (Oficinas) e constrói a Oficina.
	_research_unlock(state, WORKSHOP)
	assert_true(city.can_build(WORKSHOP), "3. Oficinas libera a Oficina")
	_build(city, WORKSHOP)

	# 5-6. Treina o Construtor N1: nasce com 1 carga (hook real do GameManager).
	assert_true(_train(city, BUILDER), "5. Construtor em treino")
	var builders := _units_of_kind(human, BUILDER)
	assert_eq(builders.size(), 1)
	assert_eq(builders[0].work_charges_remaining, 1, "6. tier 1 de Indústria -- 1 carga")

	# 7. Anexa um recurso (Gemas) pelo modo de anexação real da Fase 13.
	var gems := Vector2i(9999, 9999)
	for candidate in city.eligible_annexation_tiles(grid):
		if WorldSetup._is_valid_spawn(grid, candidate) and grid.get_unit_at(candidate) == null:
			gems = candidate
			break
	assert_ne(gems, Vector2i(9999, 9999), "há tile de fronteira de terra")
	grid.get_tile(gems).resource = "gems"
	_reserved.append(gems)
	SelectionManager.start_city_annexation(city)
	SelectionManager._handle_city_annexation_click(gems)
	SelectionManager.cancel_city_annexation()
	assert_true(gems in city.owned_tiles, "7. recurso anexado")
	# Território extra pros prédios deste fluxo (mesma mecânica, sem clique).
	for i in 12:
		var eligible := city.eligible_annexation_tiles(grid)
		if eligible.is_empty():
			break
		city.annex_tile(eligible[0], grid)

	# 8-9. Melhora o recurso; carga única: o Construtor é consumido.
	var gold_before := V2EconomyRuntime.player_gold_income(human)
	_improve_with(grid, builders[0], gems)
	assert_eq(city.resource_improvements.get(gems), "v2_improvement_gem_mine", "8. Mina de Gemas")
	assert_true(builders[0].is_queued_for_deletion(), "9. Construtor consumido")
	assert_almost_eq(V2EconomyRuntime.player_gold_income(human), gold_before + 4.0, 0.0001)

	# 10-12. Engenharia (Indústria N2): o PRÓXIMO Construtor nasce com 2 cargas.
	_research_unlock(state, "v2_workshop_efficiency_2")
	assert_true(_train(city, BUILDER), "11. novo Construtor")
	builders = _units_of_kind(human, BUILDER)
	assert_eq(builders.size(), 1)
	assert_eq(builders[0].work_charges_remaining, 2, "12. tier 2 -- 2 cargas")

	# 13. Melhora dois recursos (Ferro e Nódulo Arcano) com as duas cargas.
	var iron := _reserve_resource_tile(grid, city, "iron")
	var node := _reserve_resource_tile(grid, city, "mana_node")
	_improve_with(grid, builders[0], iron)
	assert_eq(builders[0].work_charges_remaining, 1)
	_end_turn()
	_improve_with(grid, builders[0], node)
	assert_eq(city.resource_improvements.get(iron), "v2_improvement_iron_mine")
	assert_eq(city.resource_improvements.get(node), "v2_improvement_arcane_conduit", "13. dois recursos melhorados")
	assert_true(builders[0].is_queued_for_deletion(), "segunda carga consumida")

	# 14-15. Abastecimento + Fazenda: capacidade 4 + 4.
	_research_unlock(state, FARM)
	_build(city, FARM)
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(human), 8.0, 0.0001, "15. capacidade 8")

	# 16-19. Guardião N1-N5, Salão, Guardiões (custo 2) até o limite; o próximo é bloqueado.
	for n in range(1, 3):
		_research_node(state, "v2_doctrine_guardian_%d" % n)
	_build(city, HALL)
	for n in range(3, 6):
		_research_node(state, "v2_doctrine_guardian_%d" % n)
	for i in 4:
		assert_true(_train(city, GUARDIAN), "16. Guardião %d" % (i + 1))
	assert_eq(V2LogisticsRuntime.player_supply_used(human), 8, "17. 8 usados")
	assert_false(city.can_train(GUARDIAN), "18-19. limite atingido, produção bloqueada")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(human, city, GUARDIAN), "Suprimentos insuficientes: requer 2, disponíveis 0.")

	# 20-21. Segunda Fazenda (City Level III permite 3 cópias): capacidade 12, produção liberada.
	_build(city, FARM)
	assert_eq(city.building_count(FARM), 2)
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(human), 12.0, 0.0001)
	assert_true(_train(city, GUARDIAN), "21. produção liberada")
	assert_eq(V2LogisticsRuntime.player_supply_used(human), 10)

	# 22-24. Prédios militares e a Academia: upkeep supera a renda (net negativo).
	for n in range(6, 9):
		_research_node(state, "v2_doctrine_guardian_%d" % n)
	_build(city, MASTERY)
	_research_unlock(state, ACADEMY)
	_build(city, ACADEMY)
	var upkeep := V2EconomyRuntime.player_gold_upkeep(human)
	assert_almost_eq(upkeep, 1.0 + 2.0 + 1.0 + 2.0 + 1.0, 0.0001, "23. Oficina + 2 Fazendas + Salão + Bastião + Academia")
	assert_lt(V2EconomyRuntime.player_gold_net_income(human), 0.0, "24. net negativo (renda 2 + Gemas 4 = 6 < 7)")

	# 25-26. O tesouro é gasto turno a turno até zerar: Déficit.
	human.gold = 2.0
	var guard := 0
	while human.gold > 0.0 and guard < 10:
		_end_turn()
		guard += 1
	assert_eq(human.gold, 0.0, "25. tesouro gasto, nunca negativo")
	assert_true(V2EconomyRuntime.is_gold_deficit(human), "26. Déficit")

	# 27-28. Prédios com upkeep a 50% (capacidade 4 + 2x4x0,5 = 8) -> Tensão (10 > 8).
	assert_true(V2EconomyRuntime.city_income_breakdown(city, "supply").deficit_discounted, "27. Fazendas a 50%")
	assert_true(V2EconomyRuntime.city_income_breakdown(city, "knowledge").deficit_discounted, "Academia a 50%")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(human), 8.0, 0.0001)
	assert_true(V2LogisticsRuntime.is_logistically_strained(human), "28. Tensão")
	assert_false(city.can_train(GUARDIAN), "Déficit bloqueia treino novo")
	assert_false(city.can_build(FARM), "Déficit bloqueia prédio com upkeep")

	# 29-31. Mercado (sem upkeep, liberado em Déficit): sai do Déficit, outputs voltam a 100%.
	_research_unlock(state, MARKET)
	assert_true(city.can_build(MARKET), "29. Mercado liberado mesmo em Déficit")
	_build(city, MARKET)
	assert_false(V2EconomyRuntime.is_gold_deficit(human), "30. saiu do Déficit")
	assert_false(V2EconomyRuntime.city_income_breakdown(city, "supply").deficit_discounted, "31. Fazendas a 100%")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(human), 12.0, 0.0001)
	assert_false(V2LogisticsRuntime.is_logistically_strained(human))

	# Um Construtor vivo (2 cargas) atravessa o save/load.
	assert_true(_train(city, BUILDER))
	assert_eq(_units_of_kind(human, BUILDER)[0].work_charges_remaining, 2)

	var before := {
		"buildings": city.buildings.keys(),
		"farm_copies": city.building_count(FARM),
		"upkeep": V2EconomyRuntime.player_gold_upkeep(human),
		"gold": human.gold,
		"used": V2LogisticsRuntime.player_supply_used(human),
		"capacity": V2EconomyRuntime.player_supply_capacity(human),
		"improvements": city.resource_improvements.duplicate(),
		"research": state.get_completed_ids(),
		"guardians": _units_of_kind(human, GUARDIAN).size(),
		"strained": V2LogisticsRuntime.is_logistically_strained(human),
		"deficit": V2EconomyRuntime.is_gold_deficit(human),
	}

	# 32-33. Salvar e carregar.
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH), "32. save")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_hex_grids.append(loaded_grid)
	_players_to_release.append_array(GameManager.players)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH), "33. load")
	var loaded := GameManager.human_player
	var loaded_city: City = loaded.cities[0]

	# 34-43. Tudo confere depois do load.
	for id in before.buildings:
		assert_true(loaded_city.buildings.has(id), "34. prédio %s" % id)
	assert_eq(loaded_city.building_count(FARM), before.farm_copies, "34. cópias de Fazenda")
	assert_almost_eq(V2EconomyRuntime.player_gold_upkeep(loaded), before.upkeep, 0.0001, "35. upkeep")
	assert_almost_eq(loaded.gold, before.gold, 0.0001, "36. Ouro")
	assert_eq(V2LogisticsRuntime.player_supply_used(loaded), before.used, "37. Suprimentos usados")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(loaded), before.capacity, 0.0001, "37. capacidade")
	assert_eq(loaded_city.resource_improvements, before.improvements, "38. melhorias")
	for coord in before.improvements:
		assert_true(loaded_grid.improvement_markers_by_coord.has(coord), "38. marcador visual reconstruído")
	var loaded_builders := _units_of_kind(loaded, BUILDER)
	assert_eq(loaded_builders.size(), 1)
	assert_eq(loaded_builders[0].work_charges_remaining, 2, "39. cargas")
	assert_eq(loaded.v2_research.get_completed_ids(), before.research, "40. pesquisa")
	var loaded_guardians := _units_of_kind(loaded, GUARDIAN)
	assert_eq(loaded_guardians.size(), before.guardians, "41. unidades")
	assert_eq(V2LogisticsRuntime.is_logistically_strained(loaded), before.strained, "42. Tensão re-derivada")
	assert_eq(V2EconomyRuntime.is_gold_deficit(loaded), before.deficit, "42. Déficit re-derivado")
	var techniques: Array = V2TechniqueRuntime.techniques_for_unit(loaded_guardians[0]).map(func(t): return t.id)
	assert_true(WALL in techniques and BRACE in techniques, "43. Doutrina/técnicas intactas: %s" % str(techniques))
	assert_true(loaded_city.can_train("v2_legendary_guardian_champion") or V2LogisticsRuntime.training_unavailable_reason(loaded, loaded_city, "v2_legendary_guardian_champion") != "", "43. Bastião continua oferecendo o Campeão (ou explica o motivo)")
