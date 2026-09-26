extends GutTest

## Aetherlands V2, Fase 13 — integração: save/load real (via SaveManager), captura de cidade
## (preserva nível/pontos/prédios/território), compatibilidade com a IA (permanece Cidade I,
## sem crash), "Cidade Desenvolvida" nunca conecta vitória mesmo com Exército Supremo, e o
## fluxo principal ponta a ponta (§96 do pedido).

const TEST_SAVE_PATH := "user://test_v2_city_level_savegame.json"
const URBANIZATION_1 := "v2_infrastructure_urbanization_1"

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _owned_players: Array[PlayerData] = []
var _created_hex_grids: Array[HexGrid] = []
var _original_players: Array[PlayerData]
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_state
var _original_turn_number: int

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

func before_each():
	_original_players = GameManager.players
	GameManager.players = []
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_state = GameManager.state
	_original_turn_number = TurnManager.turn_number
	hex_grid = HexGrid.new()
	hex_grid._ready()
	hex_grid.generate_map(7, 7, 12345)
	_created_hex_grids.append(hex_grid)
	GameManager.hex_grid = hex_grid
	human = _track_player(CivilizationData.new())
	rival = _track_player(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	GameManager.human_player = human
	GameManager.rival_players = [rival]
	GameManager.players = [human, rival]

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
	GameManager.players = _original_players
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.state = _original_state
	TurnManager.turn_number = _original_turn_number
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
	SaveManager.delete_save(TEST_SAVE_PATH)
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_created_hex_grids.clear()

## load_game substitui GameManager.human_player/rival_players por instâncias NOVAS -- reatribui
## human/rival aqui pra todo chamador continuar operando sobre o jogador REALMENTE carregado
## (os objetos antigos ficam órfãos, ainda liberados no after_each via _owned_players).
func _save_and_reload() -> void:
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH), "save_game")
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH), "load_game")
	hex_grid = loaded_grid
	human = GameManager.human_player
	if GameManager.rival_players.size() > 0:
		rival = GameManager.rival_players[0]

func _founded_city(owner_player: PlayerData, coord: Vector2i) -> City:
	return hex_grid.found_city(coord, owner_player, "Capital")

func _finish_current_production(city: City, max_turns: int = 400) -> void:
	for i in max_turns:
		city.process_turn(hex_grid)
		if city.production_item == "":
			break

# --- §42/§92: save/load ---------------------------------------------------------------------

func test_save_load_preserves_city_level_and_annexation_points():
	var city := _founded_city(human, Vector2i(0, 0))
	human.v2_research.complete_research(URBANIZATION_1)
	human.gold = 100.0
	city.city_level = 2
	city.annexation_points = 3
	var coord := city.coord
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_eq(loaded_city.city_level, 2)
	assert_eq(loaded_city.annexation_points, 3)

func test_save_load_preserves_a_city_project_in_progress():
	var city := _founded_city(human, Vector2i(0, 0))
	human.v2_research.complete_research(URBANIZATION_1)
	human.gold = 100.0
	city.set_production("v2_city_upgrade_2")
	city.stored_production = 25.0
	var coord := city.coord
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_eq(loaded_city.production_item, "v2_city_upgrade_2")
	assert_almost_eq(loaded_city.stored_production, 25.0, 0.001)
	assert_eq(loaded_city.city_level, 1, "ainda não concluiu")

## §81/§92 do pedido: o projeto completou os PP mas ficou esperando Ouro -- esse estado de
## espera também precisa sobreviver ao save/load (sem campo novo: stored_production == cost já É
## o sinal de "esperando", ver City.city_upgrade_waiting_for_gold()).
func test_save_load_preserves_a_city_project_waiting_for_gold():
	var city := _founded_city(human, Vector2i(0, 0))
	human.v2_research.complete_research(URBANIZATION_1)
	human.gold = 100.0
	city.set_production("v2_city_upgrade_2")
	human.gold = 5.0
	city.process_turn(hex_grid)
	for i in 60:
		if city.stored_production >= city.production_cost():
			break
		city.process_turn(hex_grid)
	assert_gt(city.city_upgrade_waiting_for_gold(), 0, "pré-condição: esperando Ouro")
	var coord := city.coord
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_eq(loaded_city.city_level, 1)
	assert_gt(loaded_city.city_upgrade_waiting_for_gold(), 0, "continua esperando após o load")
	human.gold = 100.0 # agora recupera de verdade
	loaded_city.process_turn(hex_grid)
	assert_eq(loaded_city.city_level, 2)

func test_save_load_preserves_manually_annexed_territory():
	var city := _founded_city(human, Vector2i(0, 0))
	city.city_level = 2
	city.annexation_points = 4
	var target: Vector2i = Vector2i.ZERO
	for coord in HexMetrics.coords_within(city.coord, 2):
		if HexMetrics.axial_distance(city.coord, coord) == 2 and city.can_annex_tile(coord, hex_grid):
			target = coord
			break
	city.annex_tile(target, hex_grid)
	var coord := city.coord
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_true(target in loaded_city.owned_tiles)
	assert_eq(loaded_city.annexation_points, 3)

func test_old_save_without_the_new_fields_loads_at_level_1_with_zero_points():
	var city := _founded_city(human, Vector2i(0, 0))
	assert_true(SaveManager.save_game(hex_grid, TEST_SAVE_PATH))
	# Simula um save LEGADO: remove os campos novos do JSON gravado em disco.
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	var players: Array = [data.human]
	players.append_array(data.rivals)
	for p in players:
		for c in p.get("cities", []):
			c.erase("city_level")
			c.erase("annexation_points")
			c.erase("repeatable_building_counts")
	var out := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(data))
	out.close()
	var loaded_grid := HexGrid.new()
	loaded_grid._ready()
	_created_hex_grids.append(loaded_grid)
	assert_true(SaveManager.load_game(loaded_grid, TEST_SAVE_PATH))
	var loaded_city := loaded_grid.get_city_at(city.coord)
	assert_eq(loaded_city.city_level, 1, "legacy default -- nunca inferido")
	assert_eq(loaded_city.annexation_points, 0)

# --- §43/§93: captura preserva o desenvolvimento urbano -----------------------------------------

func test_capturing_a_developed_city_preserves_level_points_buildings_and_territory():
	var city := _founded_city(rival, Vector2i(3, 0))
	city.city_level = 3
	city.annexation_points = 5
	city.buildings["granary"] = true
	var territory_before := city.owned_tiles.duplicate()
	hex_grid.capture_city(city, human)
	assert_eq(city.city_level, 3, "captura NUNCA reseta o nível -- §43 do pedido")
	assert_true(city.is_developed_v2())
	assert_eq(city.annexation_points, 5)
	assert_true(city.buildings.has("granary"))
	assert_eq(city.owned_tiles, territory_before)
	assert_eq(city.owner_player, human)

func test_the_new_owner_of_a_captured_city_does_not_inherit_the_old_owners_research():
	var city := _founded_city(rival, Vector2i(3, 0))
	rival.v2_research.complete_research(URBANIZATION_1)
	city.city_level = 2
	hex_grid.capture_city(city, human)
	assert_false(human.has_unlocked("v2_city_level_2"), "pesquisa é por civilização, nunca por cidade")
	assert_false(city.can_start_city_upgrade(), "o novo dono não pesquisou Urbanização -- não pode evoluir a cidade capturada")

func test_city_project_in_progress_survives_capture_same_semantics_as_any_production():
	var city := _founded_city(rival, Vector2i(3, 0))
	rival.v2_research.complete_research(URBANIZATION_1)
	rival.gold = 100.0
	city.set_production("v2_city_upgrade_2")
	city.stored_production = 10.0
	hex_grid.capture_city(city, human)
	# City.gd não zera production_item na captura (mesma regra de qualquer produção em andamento,
	# ver docs Fase 13 #44) -- o projeto persiste, mas o NOVO dono precisa da PRÓPRIA pesquisa
	# pra ele algum dia concluir de verdade.
	assert_eq(city.production_item, "v2_city_upgrade_2")
	assert_almost_eq(city.stored_production, 10.0, 0.001)

# --- §74/IA: compatibilidade mínima --------------------------------------------------------------

func test_rival_cities_stay_at_level_1_with_four_slots_and_do_not_expand_automatically():
	var city := _founded_city(rival, Vector2i(3, 0))
	var owned_before := city.owned_tiles.size()
	for i in 6:
		TurnManager.turn_number += 1
		city.process_turn(hex_grid)
	assert_eq(city.city_level, 1, "IA não pesquisa/produz Urbanização nesta fase")
	assert_eq(city.max_building_slots(), 4)
	assert_eq(city.owned_tiles.size(), owned_before)

func test_six_real_turns_with_v2_city_level_content_present_no_crash_no_use_by_rivals():
	_founded_city(human, Vector2i(0, 0))
	_founded_city(rival, Vector2i(3, 0))
	human.v2_research.complete_research(URBANIZATION_1)
	GameManager.state = GameManager.GameState.PLAYING
	for i in 6:
		TurnManager.end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "6 turnos reais, sem crash")
	assert_false(rival.has_unlocked("v2_city_level_2"), "rival nunca pesquisou Urbanização")

# --- §20/§94: Cidade Desenvolvida nunca concede vitória, mesmo com Exército Supremo -------------

func test_developed_city_plus_supreme_army_never_triggers_a_v2_victory():
	var city := _founded_city(human, Vector2i(0, 0))
	# O rival também precisa de uma cidade real -- senão VictoryConditions.is_dominance_achieved
	# fica vacuamente verdadeiro (nenhum outro jogador com cidade/unidade), um falso positivo de
	# vitória de Dominação V1 sem relação nenhuma com esta fase (mesmo cuidado da Fase 12).
	_founded_city(rival, Vector2i(4, 0))
	city.city_level = 3
	assert_true(city.is_developed_v2())
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
	human.v2_research.complete_research("v2_supreme_army")
	assert_true(human.has_unlocked("v2_military_supremacy_access"))
	GameManager.state = GameManager.GameState.PLAYING
	watch_signals(EventBus)
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória V2 conectada ainda -- só a API semântica existe")
	assert_signal_not_emitted(EventBus, "victory_achieved")

# --- §96: fluxo principal ponta a ponta (abreviado) ----------------------------------------------

func test_main_end_to_end_flow_research_upgrade_annex_up_to_level_4():
	var city := _founded_city(human, Vector2i(0, 0))
	# O rival precisa de uma cidade real pro check_victories() do passo 42 não achar
	# VictoryConditions.is_dominance_achieved vacuamente verdadeiro (mesmo cuidado da Fase 12).
	_founded_city(rival, Vector2i(4, 0))
	# 1-4: nova cidade em Cidade I com 4 slots.
	assert_eq(city.city_level, 1)
	assert_eq(city.max_building_slots(), 4)
	# 5-10: a árvore de Infraestrutura tem 6 linhas x 3; pesquisa Planejamento Urbano.
	assert_eq(V2ResearchDatabase.nodes_for_tree(V2ResearchNode.TreeType.INFRASTRUCTURE).size(), 18)
	human.v2_research.complete_research(URBANIZATION_1)
	human.gold = 200.0
	# 10-14: upgrade pra Cidade II disponível, inicia e conclui.
	assert_true(city.can_start_city_upgrade())
	city.set_production("v2_city_upgrade_2")
	_finish_current_production(city)
	assert_eq(city.city_level, 2, "14. Cidade II")
	assert_eq(city.max_building_slots(), 7, "15. 7 slots")
	assert_eq(city.annexation_points, 4, "16. 4 Pontos de Anexação")
	# 17-20: anexa um tile escolhido.
	var target := Vector2i.ZERO
	for coord in HexMetrics.coords_within(city.coord, 2):
		if HexMetrics.axial_distance(city.coord, coord) == 2 and city.can_annex_tile(coord, hex_grid):
			target = coord
			break
	assert_true(city.annex_tile(target, hex_grid))
	assert_true(target in city.owned_tiles, "19. ownership confirmado")
	assert_eq(city.annexation_points, 3, "20. 3 pontos restantes")
	# 21-22: passar turnos sem produção -- nenhum tile automático.
	var owned_before := city.owned_tiles.size()
	for i in 5:
		city.process_turn(hex_grid)
	assert_eq(city.owned_tiles.size(), owned_before, "22. nenhum tile automático")
	# 23-28: Cidade Fortificada -> Cidade III.
	human.v2_research.complete_research("v2_infrastructure_urbanization_2")
	city.set_production("v2_city_upgrade_3")
	_finish_current_production(city)
	assert_true(city.is_developed_v2(), "25. developed")
	assert_eq(city.max_building_slots(), 10, "26. 10 slots")
	assert_eq(V2CityLevelData.repeatable_building_limit(city.city_level), 3, "27. cap repetível 3")
	assert_eq(city.annexation_points, 8, "28. 3 + 5 pontos")
	# 29-33: Metrópole -> Cidade IV.
	human.v2_research.complete_research("v2_infrastructure_urbanization_3")
	human.gold += 200.0 # custo de Cidade IV (140 Ouro) -- o que sobrou dos passos anteriores não bastava
	city.set_production("v2_city_upgrade_4")
	_finish_current_production(city)
	assert_eq(city.max_building_slots(), 13, "31. 13 slots")
	assert_eq(V2CityLevelData.repeatable_building_limit(city.city_level), 4, "32. cap repetível 4")
	assert_eq(city.annexation_points, 14, "33. 8 + 6 pontos")
	# 34-40: salvar, carregar, confirmar tudo.
	var coord := city.coord
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_eq(loaded_city.city_level, 4, "36. level")
	assert_eq(loaded_city.annexation_points, 14, "37. pontos")
	assert_true(target in loaded_city.owned_tiles, "38. território")
	assert_true(human.has_unlocked("v2_city_level_4"), "40. pesquisas")
	# 41: Exército Supremo permanece independente.
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "warrior")
	human.v2_research.complete_research("v2_supreme_army")
	assert_true(human.has_unlocked("v2_military_supremacy_access"))
	# 42: check_victories continua sem Supremacia V2.
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "42. sem vitória V2")
