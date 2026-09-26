extends GutTest

## Aetherlands V2, Fase 14 — integração: save/load real (via SaveManager, prédios repetíveis com
## posição física), captura transferindo a economia, compatibilidade com IA, especialização por
## City Level (§110), o fluxo principal ponta a ponta (§113, abreviado) e a integração Economia
## V2 <-> Doutrinas Militares (§114).

const TEST_SAVE_PATH := "user://test_v2_economy_savegame.json"
const MARKET := "v2_building_market"
const FARM := "v2_building_farm"
const WORKSHOP := "v2_building_workshop"
const ACADEMY := "v2_building_academy"
const SHRINE := "v2_building_arcane_shrine"

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
	hex_grid.generate_map(7, 7, 424242)
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

func _research(player: PlayerData, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	assert_not_null(node, unlock_id)
	assert_true(player.v2_research.complete_research(node.id), unlock_id)

func _free_neighbor(city: City) -> Vector2i:
	for n in hex_grid.get_neighbors(city.coord):
		if city.is_valid_building_tile(n, hex_grid):
			return n
	for n in city.owned_tiles:
		if city.is_valid_building_tile(n, hex_grid):
			return n
	return Vector2i(999998, 999998)

func _build_copy(city: City, building_id: String) -> Vector2i:
	var target := _free_neighbor(city)
	city.set_production(building_id)
	city.pending_building_coord = target
	city.stored_production = city.production_cost()
	var result := city.process_turn(hex_grid)
	if result.built_coord != City.NO_PENDING_COORD:
		hex_grid.place_building(result.built_coord, result.built_kind, city.owner_player)
	return target

# --- §110: especialização por City Level ------------------------------------------------------------

func test_city_level_four_can_hold_four_copies_of_the_same_building_without_four_research_tiers():
	var city := _founded_city(human, Vector2i(0, 0))
	city.city_level = 4
	_research(human, "v2_building_farm")
	# Aetherlands V2, Fase 15 — 4 Fazendas têm gold_upkeep (§25) e esta cidade não tem Mercado; sem
	# Ouro de sobra a civilização entraria em Déficit sozinha, descontando 50% da contribuição das
	# Fazendas por um motivo alheio ao que este teste verifica (a escala por cópia no tier 1).
	human.gold = 1000.0
	for i in 4:
		_build_copy(city, FARM)
	assert_eq(city.building_count(FARM), 4)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), V2InfrastructureEconomyData.BASE_SUPPLY_PER_CITY + 4.0 * 4.0, "4 cópias no tier 1 -- sem pesquisar N2/N3")

# --- Captura transfere a economia de verdade (§82/§83) -----------------------------------------------

func test_capture_transfers_gold_supply_knowledge_mana_immediately():
	var city := _founded_city(human, Vector2i(0, 0))
	_founded_city(rival, Vector2i(4, 0))
	_research(human, "v2_building_market")
	_research(human, "v2_building_farm")
	_build_copy(city, MARKET)
	_build_copy(city, FARM)
	var human_gold_before := V2EconomyRuntime.player_gold_income(human)
	var rival_gold_before := V2EconomyRuntime.player_gold_income(rival)
	assert_gt(human_gold_before, rival_gold_before)
	hex_grid.capture_city(city, rival)
	assert_almost_eq(V2EconomyRuntime.player_gold_income(human), 0.0, 0.01, "perdeu a única cidade -- renda cai pra 0")
	assert_gt(V2EconomyRuntime.player_gold_income(rival), rival_gold_before, "o Mercado capturado já conta pro novo dono")
	for coords in city.repeatable_building_coords.values():
		for c in coords:
			var b := hex_grid.get_building_at(c)
			assert_not_null(b, "modelo físico continua no mapa após a captura")
			assert_eq(b.owner_player, rival, "repintado pro novo dono")

# --- IA: rivais recebem a base, nunca constroem ------------------------------------------------------

func test_six_real_turns_rivals_get_base_income_and_never_build_economy():
	_founded_city(human, Vector2i(0, 0))
	var rival_city := _founded_city(rival, Vector2i(4, 0))
	GameManager.state = GameManager.GameState.PLAYING
	for i in 6:
		TurnManager.end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "6 turnos reais, sem crash")
	assert_eq(rival_city.building_count(MARKET), 0, "IA não constrói infraestrutura econômica V2 ainda")
	assert_gt(V2EconomyRuntime.player_gold_income(rival), 0.0, "mas continua recebendo a renda base")

# --- §113: fluxo principal ponta a ponta (abreviado) --------------------------------------------------

func test_main_end_to_end_economy_flow():
	var city := _founded_city(human, Vector2i(0, 0))
	_founded_city(rival, Vector2i(4, 0)) # evita dominância vácua no check_victories do fim
	human.gold = 0.0

	# 3-4: Cidade I, renda-base exata.
	assert_eq(city.city_level, 1)
	assert_eq(V2EconomyRuntime.city_gold_income(city), 2.0)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), 4.0)
	assert_eq(V2EconomyRuntime.city_production_income(city), 4.0)
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), 2.0)
	assert_eq(V2EconomyRuntime.city_mana_income(city), 1.0)

	# 5-7: pesquisa real progredindo SEM debug de Conhecimento -- só a renda de turno (usa
	# V2EconomyRuntime.apply_turn_income diretamente, o MESMO que GameManager chama a cada
	# TurnManager.end_turn() real -- o turno completo com IA/combate é testado à parte, em
	# test_six_real_turns_rivals_get_base_income_and_never_build_economy).
	human.v2_research.select_research("v2_infrastructure_economy_1")
	GameManager.state = GameManager.GameState.PLAYING
	var turns := 0
	while not human.v2_research.is_completed("v2_infrastructure_economy_1") and turns < 50:
		V2EconomyRuntime.apply_turn_income(human)
		turns += 1
	assert_true(human.v2_research.is_completed("v2_infrastructure_economy_1"), "progrediu naturalmente, sem +Knowledge de debug")

	# 9-14: Mercado, Contabilidade, Rede Mercantil.
	_build_copy(city, MARKET)
	assert_eq(V2EconomyRuntime.city_gold_income(city), 2.0 + 4.0, "prédio concluído -- vale a partir daqui")
	_research(human, "v2_market_efficiency_2")
	assert_eq(V2EconomyRuntime.city_gold_income(city), 2.0 + 6.0)
	_research(human, "v2_market_efficiency_3")
	assert_eq(V2EconomyRuntime.city_gold_income(city), 2.0 + 8.0)

	# 15-19: Fazenda + Logística II/III.
	_research(human, "v2_building_farm")
	_build_copy(city, FARM)
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), 4.0 + 4.0)
	_research(human, "v2_farm_efficiency_2")
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), 4.0 + 6.0)
	_research(human, "v2_farm_efficiency_3")
	assert_eq(V2EconomyRuntime.city_supply_capacity(city), 4.0 + 8.0)

	# 20-26: Oficina + Engenharia/Manufatura.
	_research(human, "v2_building_workshop")
	_build_copy(city, WORKSHOP)
	assert_eq(V2EconomyRuntime.city_production_income(city), 4.0 + 2.0)
	_research(human, "v2_workshop_efficiency_2")
	assert_eq(V2EconomyRuntime.city_production_income(city), 4.0 + 3.0)
	_research(human, "v2_workshop_efficiency_3")
	assert_eq(V2EconomyRuntime.city_production_income(city), 4.0 + 4.0)

	# 27-31: Academia + Métodos de Estudo/Centros de Pesquisa, Conhecimento usado numa pesquisa real.
	_research(human, "v2_building_academy")
	_build_copy(city, ACADEMY)
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), 2.0 + 3.0)
	human.v2_research.select_research("v2_infrastructure_academy_2")
	var before_progress := human.v2_research.get_progress("v2_infrastructure_academy_2")
	V2EconomyRuntime.apply_turn_income(human)
	assert_gt(human.v2_research.get_progress("v2_infrastructure_academy_2"), before_progress, "Conhecimento real avançou a pesquisa")
	_research(human, "v2_academy_efficiency_2")
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), 2.0 + 4.0)
	_research(human, "v2_academy_efficiency_3")
	assert_eq(V2EconomyRuntime.city_knowledge_income(city), 2.0 + 5.0)

	# 32-35: Santuário Arcano + Condução/Nexos.
	_research(human, "v2_building_arcane_shrine")
	_build_copy(city, SHRINE)
	assert_eq(V2EconomyRuntime.city_mana_income(city), 1.0 + 2.0)
	_research(human, "v2_arcane_shrine_efficiency_2")
	assert_eq(V2EconomyRuntime.city_mana_income(city), 1.0 + 3.0)
	_research(human, "v2_arcane_shrine_efficiency_3")
	assert_eq(V2EconomyRuntime.city_mana_income(city), 1.0 + 4.0)

	# 36-38: evolui pra Cidade II, segunda cópia de um prédio econômico, yield dobra.
	human.v2_research.complete_research("v2_infrastructure_urbanization_1")
	human.gold = 1000.0
	city.set_production(V2CityLevelData.project_id_for_level(2))
	for i in 400:
		city.process_turn(hex_grid)
		if city.city_level == 2:
			break
	assert_eq(city.city_level, 2)
	var gold_before_second_market := V2EconomyRuntime.city_gold_income(city)
	_build_copy(city, MARKET)
	assert_eq(V2EconomyRuntime.city_gold_income(city), gold_before_second_market + 8.0, "2ª cópia dobra a contribuição do Mercado (tier 3: 8 cada)")

	# 39-45: salva, carrega, confirma cópias/outputs/recursos/pesquisa/City Level.
	var coord := city.coord
	var gold_income_before_save := V2EconomyRuntime.player_gold_income(human)
	_save_and_reload()
	var loaded_city := hex_grid.get_city_at(coord)
	assert_eq(loaded_city.building_count(MARKET), 2)
	assert_eq(loaded_city.city_level, 2)
	assert_almost_eq(V2EconomyRuntime.player_gold_income(human), gold_income_before_save, 0.01)
	# is_completed() espera o id do NÓ de pesquisa, não o unlock_id (a tradução unlock_id -> nó é
	# V2ResearchDatabase.node_for_unlock_id, usada por V2EconomyRuntime internamente).
	assert_true(human.v2_research.is_completed("v2_infrastructure_economy_3"), "Rede Mercantil sobreviveu ao save/load")

	# 47: Doutrinas militares continuam funcionando (nenhum sistema isolado quebrou).
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	assert_true(human.v2_research.is_completed("v2_doctrine_guardian_1"))
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nada disto conecta vitória")

# --- §114: Economia V2 <-> Doutrinas Militares --------------------------------------------------------

func test_workshop_speeds_up_v2_military_production():
	var city := _founded_city(human, Vector2i(0, 0))
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	human.v2_research.complete_research("v2_doctrine_guardian_2")
	_build_copy(city, "v2_building_guardian_hall")
	city.set_production("v2_unit_shieldbearer")
	var without_workshop := V2EconomyRuntime.city_production_income(city)
	_research(human, "v2_building_workshop")
	_build_copy(city, WORKSHOP)
	city.set_production("v2_unit_shieldbearer")
	var with_workshop := V2EconomyRuntime.city_production_income(city)
	assert_gt(with_workshop, without_workshop, "Oficina acelera a produção militar V2 pela MESMA fila")

func test_market_gold_funds_a_unit_upgrade():
	var city := _founded_city(human, Vector2i(0, 0))
	human.v2_research.complete_research("v2_doctrine_guardian_1")
	human.v2_research.complete_research("v2_doctrine_guardian_2")
	human.v2_research.complete_research("v2_doctrine_guardian_3")
	human.v2_research.complete_research("v2_doctrine_guardian_4")
	human.v2_research.complete_research("v2_doctrine_guardian_5")
	_research(human, "v2_building_market")
	_build_copy(city, MARKET)
	human.gold = 0.0
	V2EconomyRuntime.apply_turn_income(human)
	assert_gt(human.gold, 0.0, "o Ouro do Mercado está disponível pro upgrade de unidade V2UnitUpgrade gastar (V2UnitUpgrade.gd, intocado nesta fase)")

func test_academy_knowledge_completes_a_doctrine_research_and_unlocks_a_unit():
	var city := _founded_city(human, Vector2i(0, 0))
	_research(human, "v2_building_academy")
	_build_copy(city, ACADEMY)
	human.v2_research.select_research("v2_doctrine_guardian_1")
	var turns := 0
	while not human.v2_research.is_completed("v2_doctrine_guardian_1") and turns < 50:
		V2EconomyRuntime.apply_turn_income(human)
		turns += 1
	assert_true(human.v2_research.is_completed("v2_doctrine_guardian_1"), "Conhecimento da Academia concluiu uma pesquisa de Doutrina real")
