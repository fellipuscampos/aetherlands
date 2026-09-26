extends GutTest

## FLUXO REAL de ponta a ponta da Doutrina da Cavalaria N1-N9 (Aetherlands V2, Fase 9), pelos mesmos caminhos do jogo (HUD/SelectionManager/produção/save/neblina):
## jogo novo -> N1 -> N2 -> Estábulo de Guerra -> N3 -> Cavaleiro (movimento 4) -> N4 -> Carga (mira, ESC, clique: a unidade percorre a rota e termina adjacente)
## -> N5 -> Cavaleiro de Choque (upgrade) -> N6 -> Retirada Tática (mira de TILE, ESC, clique; +20% de Defesa até o próximo turno) -> N7 -> Cavaleiro Blindado ->
## N8 -> Ordem da Cavalaria -> N9 -> Cavaleiro de Grifo (voo tático; Carga e Retirada aéreas; +25% de dano de ataques à distância) -> salvar -> carregar -> slot Lendário
## compartilhado com as outras TRÊS Doutrinas. O modo debug (GameManager.debug_mode) só acelera a PRODUÇÃO da cidade humana pra 1 turno.

const TEST_SAVE_PATH := "user://test_v2_cavalry_flow_savegame.json"
const STABLE := "v2_building_war_stable"
const CAVALIER := "v2_unit_cavalier"
const SHOCK := "v2_unit_shock_cavalier"
const ARMORED := "v2_unit_armored_cavalier"
const ORDER := "v2_building_cavalry_mastery"
const GRIFFON := "v2_legendary_griffon_rider"
const CHARGE := "v2_technique_charge"
const RETREAT := "v2_technique_tactical_retreat"
const BRACE := "v2_technique_brace_spears"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const W_HALL := "v2_building_warrior_hall"
const ARENA := "v2_building_warrior_mastery"
const R_CAMP := "v2_building_ranger_camp"
const R_TOWER := "v2_building_ranger_mastery"
const CHAMPION := "v2_legendary_guardian_champion"
const HERO := "v2_legendary_blade_hero"
const LEGEND_HUNTER := "v2_legendary_legend_hunter"
## Mapa grande o bastante pra o Colonizador inicial não nascer perto demais de uma capital rival.
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _players_to_release: Array[PlayerData] = []

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

# --- Helpers ----------------------------------------------------------------------------------------------

func _new_game() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_WIDTH, MAP_HEIGHT, 555)
	_hex_grids.append(grid)
	GameManager.start_new_game(grid)
	return grid

func _found_human_city(grid: HexGrid) -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			var city := WorldSetup.found_city_from_settler(grid, unit)
			assert_not_null(city, "pré-condição: o Colonizador inicial funda a cidade")
			return city
	fail_test("o humano deveria começar com um Colonizador")
	return null

func _research(state: V2ResearchState, node_id: String) -> void:
	assert_true(state.select_research(node_id), "select %s" % node_id)
	state.add_knowledge(V2ResearchDatabase.get_node(node_id).cost)
	assert_true(state.is_completed(node_id), "concluiu %s" % node_id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")
	_clear_wandering_monsters_next_to_human_cities()

## Aetherlands V2, Fase 16 — a milícia AUTOMÁTICA (que abatia monstros neutros colados às cidades todo
## turno) saiu; a defesa própria agora é o Ataque da Cidade, explícito e só com fortificação. Este
## fluxo verifica a Doutrina, não pressão de monstros: remove os monstros errantes do mapa gerado que
## encostarem numa cidade humana (o que a milícia antiga fazia de graça), pra não ocuparem os tiles
## de construção/treino.
func _clear_wandering_monsters_next_to_human_cities() -> void:
	var grid: HexGrid = GameManager.hex_grid
	for city in GameManager.human_player.cities:
		for coord in grid.get_neighbors(city.coord):
			var unit := grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.world_event_managed:
				grid.remove_unit(unit)

func _units_of_kind(player: PlayerData, kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in player.units:
		if unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

## Produz `kind` pelo mesmo gate/fluxo da HUD (has_unlocked + can_train + set_production) e
## fecha o turno. Devolve true se a cidade aceitou.
func _train(city: City, kind: String) -> bool:
	if not GameManager.human_player.has_unlocked(kind) or not city.can_train(kind):
		return false
	city.set_production(kind)
	_end_turn()
	return true

func _save_and_reload() -> HexGrid:
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH), "save_game")
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	_players_to_release.append_array(GameManager.players)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH), "load_game")
	return loaded

## Constrói `building_id` na cidade pelo fluxo normal (posicionamento de tile + fim de turno).
func _build(grid: HexGrid, city: City, building_id: String) -> void:
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

## Um tile de terra livre a EXATAMENTE `distance` de `center` (ordem fixa), fora de `avoid`.
func _free_at(grid: HexGrid, center: Vector2i, distance: int, avoid: Array = []) -> Vector2i:
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(center, coord) == distance and grid.tiles.has(coord) and not (coord in avoid) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_city_at(coord) == null:
			return coord
	fail_test("sem tile livre a distância %d de %s" % [distance, str(center)])
	return Vector2i(999, 999)

func _spawn_foe(grid: HexGrid, owner: PlayerData, coord: Vector2i, hp: float = 100.0, defense: float = 3.0) -> Unit:
	var data := UnitDatabase.create_unit("warrior")
	data.max_hp = hp
	data.defense = defense
	var foe := grid.spawn_unit(coord, data, owner)
	assert_not_null(foe, "inimigo em %s" % str(coord))
	return foe

func _clear_foes(grid: HexGrid, foes: Array) -> void:
	for foe in foes:
		if is_instance_valid(foe) and foe.hp > 0.0:
			grid.remove_unit(foe)

## Uma SEGUNDA cidade do humano (com os prédios `buildings`) num tile válido distante da primeira.
func _second_city(grid: HexGrid, human: PlayerData, buildings: Array[String]) -> City:
	for coord in grid.tiles.keys():
		if CitySite.rejection_reason(grid, coord, human) == "" and grid.get_unit_at(coord) == null:
			var city := grid.found_city(coord, human, "Segunda Cidade", true)
			for id in buildings:
				city.buildings[id] = true
			return city
	fail_test("sem tile válido pra a segunda cidade")
	return null


func _trainable_forms(city: City) -> Array:
	return [CAVALIER, SHOCK, ARMORED].filter(func(kind): return city.owner_player.has_unlocked(kind) and city.can_train(kind))

## Um inimigo a `distance` tiles de `unit` para o qual a Carga tem rota REAL (o mapa gerado tem água e montanha): o primeiro candidato que a mira aceita.
func _charge_foe(grid: HexGrid, owner: PlayerData, unit: Unit, distance: int, hp: float = 100.0, defense: float = 3.0) -> Unit:
	var technique := V2DoctrineTechniqueDatabase.get_technique(CHARGE)
	for coord in HexMetrics.coords_within(unit.coord, distance):
		if HexMetrics.axial_distance(unit.coord, coord) != distance or not grid.tiles.has(coord) or grid.get_unit_at(coord) != null or grid.get_city_at(coord) != null or not WorldSetup._is_valid_spawn(grid, coord):
			continue
		var foe := _spawn_foe(grid, owner, coord, hp, defense)
		grid.recompute_fog(GameManager.human_player)
		if foe in V2TechniqueRuntime.strike_targets(unit, technique, grid):
			return foe
		grid.remove_unit(foe)
	fail_test("sem inimigo a %d tiles com rota de Carga" % distance)
	return null

## Um pedaço REMOTO do mapa (longe de qualquer cidade e de qualquer covil; as unidades que não são do humano saem dele) transformado em ARENA controlada: grama num raio de 6 ao redor de `center` e,
## se pedido, um anel de OCEANO à distância `sea_ring` (a barreira que só o voo atravessa). Devolve o centro.
func _arena(grid: HexGrid, sea_ring: int = 0) -> Vector2i:
	var cities: Array[Vector2i] = []
	for player in GameManager.players:
		for city in player.cities:
			cities.append(city.coord)
	for center in grid.tiles.keys():
		var area: Array[Vector2i] = HexMetrics.coords_within(center, 7)
		area.append(center)
		var ok := true
		for coord in area:
			if not grid.tiles.has(coord) or grid.lairs_by_coord.has(coord) or grid.get_city_at(coord) != null:
				ok = false
				break
		for city_coord in cities:
			if HexMetrics.axial_distance(center, city_coord) < 9:
				ok = false
		if not ok:
			continue
		_clear_area(grid, center, 7, GameManager.human_player) # monstros neutros e rivais do mapa gerado saem da arena
		for coord in area:
			if HexMetrics.axial_distance(center, coord) > 6:
				continue
			var terrain := HexTileData.TerrainType.OCEAN if (sea_ring > 0 and HexMetrics.axial_distance(center, coord) == sea_ring) else HexTileData.TerrainType.GRASSLAND
			grid.tiles[coord] = TerrainDatabase.create_tile(terrain)
		return center
	fail_test("sem um pedaço remoto do mapa para a arena")
	return Vector2i(999, 999)

## Remove do grid toda unidade que não é de `keep` num raio de `radius` de `center` (monstros neutros e rivais do mapa gerado atrapalhariam as contas exatas).
func _clear_area(grid: HexGrid, center: Vector2i, radius: int, keep: PlayerData) -> void:
	for coord in HexMetrics.coords_within(center, radius):
		var other := grid.get_unit_at(coord)
		if other != null and other.owner_player != keep:
			grid.remove_unit(other)

func _place(grid: HexGrid, unit: Unit, coord: Vector2i) -> void:
	grid.teleport_unit(unit, coord)
	unit.movement_left = unit.unit_data.movement_points

## Cenário curto: jogo novo, cidade com Estábulo, Cavalaria pesquisada até `through` e uma unidade `kind` viva, em guerra com o rival.
func _short_setup(through: int = 4, kind: String = CAVALIER) -> Dictionary:
	var grid := _new_game()
	var human := GameManager.human_player
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	city.buildings[STABLE] = true
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Estábulo/Ordem/outros Salões
	# de Maestria (upkeep de Ouro) e chegam a treinar o Cavaleiro de Grifo (5 Suprimentos, acima
	# da capacidade base de uma cidade sozinha). Ouro de sobra + uma Fazenda evitam que Déficit/
	# Suprimentos bloqueiem por um motivo alheio ao que cada teste realmente verifica.
	human.gold = 100000.0
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	var spawn := WorldSetup.find_spawn_tile(grid, city.coord)
	var unit := grid.spawn_unit(spawn, UnitDatabase.create_unit(kind), human)
	assert_not_null(unit)
	grid.recompute_fog(human)
	return {"grid": grid, "human": human, "rival": rival, "city": city, "unit": unit}

# --- O fluxo -----------------------------------------------------------------------------------------------

func test_cavalry_n1_to_n9_flow_from_the_stable_to_the_griffon_across_save_and_load():
	# 1. Nova partida (em guerra com o rival, pra a Carga ter alvo).
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var city := _found_human_city(grid)
	# Aetherlands V2, Fase 15 — a forma viva (N5, 2) mais o Cavaleiro Blindado (N7, 3) já somam 5,
	# acima da base de uma cidade sozinha (4) -- Fazenda desde o início evita que este fluxo
	# pré-existente tropece num gate que não é o assunto dele (ver também a concessão mais abaixo,
	# antes da Ordem, que agora só reafirma o mesmo estado).
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 2 cópias de Fazenda TAMBÉM dobram o upkeep dela (§30: cada cópia multiplica o upkeep) -- Ouro
	# de sobra evita que isso sozinho derrube a cidade em Déficit assim que o Estábulo é construído.
	human.gold = 1000.0
	assert_false(V2UnlockSystem.is_unlocked(human, "v2_doctrine_cavalry"))

	# 2. N1: estabelece a linha, sem bônus; só o N2 fica disponível.
	_research(state, "v2_doctrine_cavalry_1")
	assert_eq(V2UnlockSystem.unlocked_ids(human), ["v2_doctrine_cavalry"], "2. o N1 não libera nada além da Doutrina")
	assert_false(city.can_build(STABLE))
	assert_true(state.is_available("v2_doctrine_cavalry_2"))

	# 3-4. N2 e o Estábulo de Guerra (construção normal, sem depender do Estábulo V1).
	_research(state, "v2_doctrine_cavalry_2")
	assert_true(city.can_build(STABLE), "3. N2 libera o Estábulo de Guerra")
	_build(grid, city, STABLE)

	# 5-6. N3 e o Cavaleiro.
	assert_false(city.can_train(CAVALIER), "sem N3 não treina")
	_research(state, "v2_doctrine_cavalry_3")
	assert_true(_train(city, CAVALIER), "6. Cavaleiro em treino")
	var cavaliers := _units_of_kind(human, CAVALIER)
	assert_eq(cavaliers.size(), 1)
	var unit: Unit = cavaliers[0]
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.defense, unit.unit_data.movement_points], [17.0, 5.0, 3.0, 4.0])
	assert_true(UnitAbilities.is_mounted(unit.unit_data), "montado")

	# 7. Movimento 4 pelo pathfinding terrestre de sempre (nenhuma regra nova pra unidade convencional).
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(SelectionManager.reachable, grid.compute_reachable(unit.coord, unit.movement_left, human, false, false), "7. o alcance é o Dijkstra terrestre normal")
	for coord in SelectionManager.reachable:
		assert_lte(HexMetrics.axial_distance(unit.coord, coord), 4, "nada além do movimento 4")

	# 8. N4 e a Carga.
	assert_true(V2TechniqueRuntime.techniques_for_unit(unit).is_empty(), "antes do N4 não há técnica")
	_research(state, "v2_doctrine_cavalry_4")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [CHARGE], "8. Carga")

	# 9. Só um inimigo ADJACENTE: sem espaço, indisponível com o motivo claro, e o botão não entra na mira. (O mapa real tem monstros neutros: a área é limpa.)
	_clear_area(grid, unit.coord, 6, human)
	var adjacent := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 1))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CHARGE, grid), "Requer espaço para realizar a Carga.", "9. inimigo adjacente")
	SelectionManager.use_technique_selected(CHARGE)
	assert_eq(SelectionManager.technique_targeting_id, "", "sem alvo válido não há mira")
	_clear_foes(grid, [adjacent])

	# 10-12. Um inimigo a 3 tiles COM rota: mira, ESC sem gastar nada, clique — a unidade anda de verdade e ataca a 1,50x.
	var target := _charge_foe(grid, rival, unit, 3)
	var start := unit.coord
	var gold := human.gold
	var mana := human.mana
	SelectionManager._select_unit(unit)
	var predicted: float = CombatResolver.predict(unit, target, grid, 1.5).damage_to_defender
	SelectionManager.use_technique_selected(CHARGE)
	assert_eq(SelectionManager.technique_targeting_id, CHARGE, "10. entrou no modo de mira")
	assert_true(target.coord in SelectionManager.technique_target_coords, "o alvo válido está destacado")
	assert_eq(unit.coord, start, "a mira não move")
	assert_true(SelectionManager.cancel_technique_targeting(), "11. ESC cancela")
	assert_eq(unit.coord, start, "cancelar não move")
	assert_eq(unit.movement_left, unit.unit_data.movement_points, "cancelar não gasta a ação")
	assert_false(unit.magic_cooldowns.has(CHARGE), "cancelar não inicia a recarga")
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(CHARGE)
	var target_hp := target.hp
	SelectionManager._handle_technique_targeting_click(target.coord)
	assert_eq(HexMetrics.axial_distance(unit.coord, target.coord), 1, "12. terminou adjacente")
	assert_ne(unit.coord, start, "a posição da unidade mudou")
	assert_same(grid.get_unit_at(unit.coord), unit, "o grid a registra no novo tile")
	assert_almost_eq(target_hp - target.hp, predicted, 0.0001, "o golpe real bate com a previsão de 1,50x")
	assert_eq(unit.movement_left, 0.0, "consumiu a ação")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CHARGE), 3, "recarga de 3 turnos")
	assert_eq([human.gold, human.mana], [gold, mana], "zero Ouro e zero Mana")
	_clear_foes(grid, [target])

	# 13-16. N5 e o Cavaleiro de Choque: a produção oferece só ele e o Cavaleiro evolui pelo V2UnitUpgrade (28 Ouro).
	_research(state, "v2_doctrine_cavalry_5")
	assert_eq(_trainable_forms(city), [SHOCK], "13. a produção oferece só o Cavaleiro de Choque — 38 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid), "")
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, SHOCK, "14. evoluiu para Cavaleiro de Choque")
	assert_eq(human.gold, 100.0 - 28.0, "2 x (38 - 24) = 28 Ouro")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, CHARGE), 2, "15. a recarga da Carga foi preservada pela evolução")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.attack, unit.unit_data.movement_points], [22.0, 7.0, 4.0], "16. mesmo movimento, mais Ataque e vida")

	# 17-22. N6 e a Retirada Tática: mira de TILE, ESC, clique; +20% de Defesa até o próximo turno do dono.
	_research(state, "v2_doctrine_cavalry_6")
	_end_turn()
	unit.movement_left = unit.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [CHARGE, RETREAT], "17. herda as duas")
	var retreat_from := unit.coord
	SelectionManager.use_technique_selected(RETREAT)
	assert_eq(SelectionManager.technique_targeting_id, RETREAT, "18. mira de tile")
	assert_false(SelectionManager.technique_target_coords.is_empty(), "há tiles livres destacados")
	var dest := SelectionManager.technique_target_coords[0]
	for coord in SelectionManager.technique_target_coords:
		assert_lte(HexMetrics.axial_distance(retreat_from, coord), 3, "nada além de 3 passos")
		assert_null(grid.get_unit_at(coord), "só tiles livres")
		assert_false(grid.get_tile(coord).blocks_land_units(), "só tiles em que uma unidade pode ficar")
		if HexMetrics.axial_distance(retreat_from, coord) == 3:
			dest = coord
	assert_true(SelectionManager.cancel_technique_targeting(), "19. ESC cancela")
	assert_eq(unit.coord, retreat_from)
	assert_false(unit.magic_cooldowns.has(RETREAT), "cancelar não gasta nada")
	assert_eq(unit.movement_left, unit.unit_data.movement_points)
	SelectionManager.use_technique_selected(RETREAT)
	var gold_before_retreat := human.gold
	# Aetherlands V2, Fase 14: `mana` (capturado na linha 350, antes dos dois _end_turn() das
	# linhas 377/391) ficou desatualizado -- cada turno real agora credita +1 Mana base
	# (V2EconomyRuntime), então reusar aquele valor aqui compararia contra um número de ANTES
	# desses turnos. Um snapshot fresco, capturado agora, é o jeito certo de provar "esta técnica
	# em si não gasta Mana" sem se confundir com a renda normal de turno.
	var mana_before_retreat := human.mana
	SelectionManager._handle_technique_targeting_click(dest)
	assert_eq(unit.coord, dest, "20. a unidade foi ao tile escolhido")
	assert_true(V2TechniqueRuntime.is_active(unit, RETREAT), "+20% de Defesa ativo")
	assert_eq(unit.movement_left, 0.0)
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, RETREAT), 4, "recarga de 4 turnos")
	assert_eq([human.gold, human.mana], [gold_before_retreat, mana_before_retreat], "zero Ouro e zero Mana")
	assert_not_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "feedback visual no mapa")
	var striker := _spawn_foe(grid, rival, _free_at(grid, unit.coord, 1))
	striker.unit_data.attack = 12.0
	var stanced: float = CombatResolver.predict(striker, unit, grid).damage_to_defender
	unit.magic_status.erase(RETREAT)
	var plain: float = CombatResolver.predict(striker, unit, grid).damage_to_defender
	unit.magic_status[RETREAT] = TurnManager.turn_number + V2TechniqueRuntime.ACTIVE_TURNS
	assert_lt(stanced, plain, "21. a Retirada reduz o dano recebido")
	var hp_before := unit.hp
	CombatResolver.resolve(striker, unit, grid)
	assert_almost_eq(hp_before - unit.hp, stanced, 0.0001, "o modificador chegou à resolução real do combate")
	unit.hp = unit.unit_data.max_hp
	grid.remove_unit(striker)
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(unit, RETREAT), "22. expirou no início do turno seguinte do dono")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(unit, RETREAT), 3, "a recarga continua contando")
	assert_null(unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "o anel some junto")

	# 23-26. N7 e o Cavaleiro Blindado: a produção oferece só ele e o Choque evolui (36 Ouro).
	_research(state, "v2_doctrine_cavalry_7")
	assert_eq(_trainable_forms(city), [ARMORED], "23. a produção oferece só o Cavaleiro Blindado — 56 PP")
	_end_turn()
	human.gold = 100.0
	_place(grid, unit, WorldSetup.find_spawn_tile(grid, city.coord))
	grid.recompute_fog(human)
	SelectionManager._select_unit(unit)
	assert_true(V2UnitUpgrade.can_upgrade(human, unit, grid), V2UnitUpgrade.unavailable_upgrade_reason(human, unit, grid))
	SelectionManager.upgrade_selected()
	assert_eq(unit.unit_data.visual_kind, ARMORED, "24. evoluiu para Cavaleiro Blindado")
	assert_eq(human.gold, 100.0 - 36.0, "2 x (56 - 38) = 36 Ouro")
	assert_eq([unit.unit_data.max_hp, unit.unit_data.defense, unit.unit_data.movement_points], [30.0, 6.0, 4.0], "25. mais resistente, mobilidade preservada")
	assert_lt(unit.unit_data.defense, UnitDatabase.create_unit("v2_unit_sentinel").defense, "26. nunca supera a Sentinela")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(unit).map(func(t): return t.id), [CHARGE, RETREAT], "herda as duas técnicas")

	# Aetherlands V2, Fase 15 — o Cavaleiro de Grifo custa 5 Suprimentos, acima da capacidade base
	# de uma cidade sozinha (4); este fluxo nunca constrói Fazenda (assunto de outra fase), então
	# concede capacidade de sobra aqui, pouco antes do treino da Lendária, sem alterar nada do que
	# já foi verificado até este ponto. A Fazenda ×4 sozinha ocuparia os 4 slots do City Level I
	# (City.used_building_slots() conta cada cópia repetível, §26 da Fase 13) por cima do Estábulo
	# já construído, sem sobrar espaço pra Ordem que este trecho ainda constrói -- City Level III
	# resolve.
	city.city_level = 3
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 2
	# 27-29. N8 e a Ordem da Cavalaria (exige o Estábulo).
	assert_false(city.can_build(ORDER), "antes do N8 não constrói")
	_research(state, "v2_doctrine_cavalry_8")
	assert_true(city.can_build(ORDER), "27. N8 libera a Ordem da Cavalaria")
	_place(grid, unit, _free_at(grid, city.coord, 3)) # o Blindado sai do tile ao lado da cidade (que o terreno da Ordem pode precisar)
	_build(grid, city, ORDER)
	assert_true(city.buildings.has(STABLE), "a Ordem não substitui o Estábulo")
	assert_false(city.can_train(GRIFFON), "sem N9 o Cavaleiro de Grifo ainda não treina")

	# 30-32. N9 e o Cavaleiro de Grifo: produção separada; o Blindado segue disponível no Estábulo.
	_research(state, "v2_doctrine_cavalry_9")
	assert_eq(V2ResearchDatabase.capstone_progress("v2_supreme_army", state.completed_ids), Vector2i(1, 2), "só a Cavalaria completa: 1 / 2")
	assert_true(city.can_train(GRIFFON))
	assert_true(_train(city, GRIFFON), "30. Cavaleiro de Grifo em treino")
	var griffons := _units_of_kind(human, GRIFFON)
	assert_eq(griffons.size(), 1)
	var griffon: Unit = griffons[0]
	assert_true(V2LegendarySystem.is_legendary_unit(griffon))
	assert_same(V2LegendarySystem.active_legendary(human), griffon)
	assert_eq(griffon.unit_data.movement_profile, UnitData.MovementProfile.FLYING)
	assert_true(griffon.unit_data.has_trait(UnitData.TRAIT_FLYING) and griffon.unit_data.has_trait(UnitData.TRAIT_MOUNTED))
	assert_eq(_trainable_forms(city), [ARMORED], "31. o Cavaleiro Blindado continua disponível no Estábulo")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(griffon).map(func(t): return t.id), [CHARGE, RETREAT], "32. herda Carga e Retirada")

	# 33. O voo no mapa gerado: alcance geométrico, sobre qualquer terreno, só pousos legais.
	griffon.movement_left = griffon.unit_data.movement_points
	grid.recompute_fog(human)
	SelectionManager._select_unit(griffon)
	assert_eq(SelectionManager.reachable, grid.flight_reachable(griffon, griffon.movement_left), "33. o alcance é o do voo tático")
	for coord in SelectionManager.reachable:
		assert_false(grid.get_tile(coord).blocks_land_units(), "só pousa em tile de terra")
	for coord in grid.compute_reachable(griffon.coord, griffon.movement_left, human):
		assert_true(SelectionManager.reachable.has(coord), "tudo que o chão alcança, o voo alcança")

	# 34-36. A ARENA com um anel de oceano: a cavalaria terrestre não atravessa; o Grifo faz a Carga por cima e termina em terra.
	var center := _arena(grid, 2)
	_place(grid, griffon, center)
	_place(grid, unit, center + Vector2i(1, 0)) # o Blindado, dentro do anel
	var barrier_foe := _spawn_foe(grid, rival, center + Vector2i(4, 0))
	grid.recompute_fog(human)
	assert_true(grid.get_tile(center + Vector2i(2, 0)).blocks_land_units(), "pré-condição: o anel é oceano")
	assert_eq(V2TechniqueRuntime.unavailable_reason(unit, CHARGE, grid), "Sem rota até um tile adjacente ao alvo.", "34. o Blindado terrestre não atravessa o mar")
	assert_true(V2TechniqueRuntime.can_use(griffon, CHARGE, grid), "35. o Grifo voa por cima")
	SelectionManager._select_unit(griffon)
	var air_predicted: float = CombatResolver.predict(griffon, barrier_foe, grid, 1.5).damage_to_defender
	SelectionManager.use_technique_selected(CHARGE)
	assert_true(barrier_foe.coord in SelectionManager.technique_target_coords)
	var barrier_hp := barrier_foe.hp
	SelectionManager._handle_technique_targeting_click(barrier_foe.coord)
	assert_eq(griffon.coord, center + Vector2i(3, 0), "36. pousou no tile de terra adjacente de menor custo")
	assert_false(grid.get_tile(griffon.coord).blocks_land_units())
	assert_almost_eq(barrier_hp - barrier_foe.hp, air_predicted, 0.0001, "10,0 x 1,5: previsão == resolução")
	assert_eq(V2TechniqueRuntime.cooldown_remaining(griffon, CHARGE), 3)
	_clear_foes(grid, [barrier_foe])

	# 37. Retirada aérea: cercado de montanhas, o Grifo ainda tem por onde sair (a cavalaria terrestre não teria).
	_end_turn()
	griffon.movement_left = griffon.unit_data.movement_points
	for coord in grid.get_neighbors(griffon.coord):
		if grid.get_unit_at(coord) == null:
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid.recompute_fog(human)
	var walled_tiles := V2TechniqueRuntime.relocation_tiles(griffon, V2DoctrineTechniqueDatabase.get_technique(RETREAT), grid)
	assert_false(walled_tiles.is_empty(), "37. o Grifo sai por cima das montanhas")
	for coord in walled_tiles:
		assert_false(grid.get_tile(coord).blocks_land_units(), "sem pouso em montanha")
	SelectionManager._select_unit(griffon)
	SelectionManager.use_technique_selected(RETREAT)
	assert_eq(SelectionManager.technique_targeting_id, RETREAT)
	SelectionManager._handle_technique_targeting_click(walled_tiles[walled_tiles.size() - 1])
	assert_true(V2TechniqueRuntime.is_active(griffon, RETREAT))
	assert_eq(griffon.coord, walled_tiles[walled_tiles.size() - 1])

	# 38. +25% de dano de ataques À DISTÂNCIA: arqueiro rival x Grifo (previsão == resolução); atacante corpo a corpo não recebe o bônus.
	var archer_data := UnitDatabase.create_unit("archer")
	archer_data.attack = 14.0
	var archer := grid.spawn_unit(_free_at(grid, griffon.coord, 2), archer_data, rival)
	assert_not_null(archer)
	var melee := _spawn_foe(grid, rival, _free_at(grid, griffon.coord, 1, [archer.coord]))
	melee.unit_data.attack = 14.0
	grid.recompute_fog(human)
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(archer, griffon), 1.25, "38. atacante à distância")
	assert_eq(UnitAbilities.ranged_vulnerability_multiplier(melee, griffon), 1.0, "corpo a corpo: sem bônus")
	var shot: float = CombatResolver.predict(archer, griffon, grid).damage_to_defender
	var original_bonus := griffon.unit_data.ranged_damage_taken_bonus
	griffon.unit_data.ranged_damage_taken_bonus = 0.0
	var shot_plain: float = CombatResolver.predict(archer, griffon, grid).damage_to_defender
	griffon.unit_data.ranged_damage_taken_bonus = original_bonus
	assert_almost_eq(shot, shot_plain * 1.25, 0.0001, "exatamente +25%")
	var griffon_hp := griffon.hp
	CombatResolver.resolve(archer, griffon, grid)
	assert_almost_eq(griffon_hp - griffon.hp, shot, 0.0001, "previsão == resolução")
	griffon.hp = griffon.unit_data.max_hp
	_clear_foes(grid, [archer, melee])

	# 39-46. Salva e carrega: pesquisas, prédios, unidades, perfil de voo, recargas, status e o slot global.
	var griffon_coord := griffon.coord
	var griffon_charge_left := V2TechniqueRuntime.cooldown_remaining(griffon, CHARGE)
	var armored_coord := unit.coord
	assert_gt(griffon_charge_left, 0, "pré-condição: a Carga do Grifo está em recarga")
	assert_true(V2TechniqueRuntime.is_active(griffon, RETREAT), "pré-condição: a Retirada do Grifo está ativa")
	var loaded_grid := _save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.v2_research.get_completed_ids().size(), 9, "40. as 9 pesquisas da Cavalaria")
	var loaded_city: City = loaded.cities[0]
	assert_true(loaded_city.buildings.has(STABLE) and loaded_city.buildings.has(ORDER), "41. Estábulo e Ordem restaurados")
	var loaded_armored := _units_of_kind(loaded, ARMORED)
	assert_eq(loaded_armored.size(), 1, "42. o Cavaleiro Blindado voltou")
	assert_eq(loaded_armored[0].coord, armored_coord)
	var loaded_griffons := _units_of_kind(loaded, GRIFFON)
	assert_eq(loaded_griffons.size(), 1, "43. o Cavaleiro de Grifo voltou")
	var loaded_griffon: Unit = loaded_griffons[0]
	assert_eq(loaded_griffon.coord, griffon_coord)
	assert_eq([loaded_griffon.unit_data.max_hp, loaded_griffon.unit_data.movement_points], [36.0, 5.0])
	assert_eq(loaded_griffon.unit_data.movement_profile, UnitData.MovementProfile.FLYING, "44. o perfil de voo vem do dado")
	assert_eq(loaded_griffon.unit_data.ranged_damage_taken_bonus, 0.25)
	assert_true(loaded_griffon.unit_data.has_trait(UnitData.TRAIT_LEGENDARY) and loaded_griffon.unit_data.has_trait(UnitData.TRAIT_FLYING) and loaded_griffon.unit_data.has_trait(UnitData.TRAIT_MOUNTED))
	assert_eq(V2TechniqueRuntime.cooldown_remaining(loaded_griffon, CHARGE), griffon_charge_left, "45. recarga da Carga")
	assert_true(V2TechniqueRuntime.is_active(loaded_griffon, RETREAT), "46. a Retirada ativa continua ativa")
	loaded_griffon.movement_left = loaded_griffon.unit_data.movement_points
	assert_eq(loaded_grid.unit_reachable(loaded_griffon), loaded_grid.flight_reachable(loaded_griffon, loaded_griffon.movement_left), "o voo continua voo depois do load")
	loaded_armored[0].movement_left = loaded_armored[0].unit_data.movement_points
	assert_eq(loaded_grid.unit_reachable(loaded_armored[0]), loaded_grid.compute_reachable(armored_coord, 4.0, loaded, false, false), "e o chão continua chão")
	assert_eq(V2TechniqueRuntime.techniques_for_unit(loaded_griffon).map(func(t): return t.id), [CHARGE, RETREAT])
	# Slot global: com o Grifo vivo, o Campeão, o Herói e o Caçador de Lendas estão bloqueados, mesmo com os prédios e as pesquisas das outras Doutrinas.
	assert_true(V2LegendarySystem.has_active_legendary(loaded), "o slot continua ocupado")
	for n in range(1, 10):
		loaded.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		loaded.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	for id in [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER]:
		loaded_city.buildings[id] = true
	for kind in [CHAMPION, HERO, LEGEND_HUNTER, GRIFFON]:
		assert_eq(V2LegendarySystem.unavailable_reason(loaded, loaded_city, kind), V2LegendarySystem.SLOT_TAKEN_REASON, kind)
	# E as quatro Doutrinas completas mostram o Exército Supremo no teto (2 / 2): pesquisável, inerte, sem vitória.
	assert_true(loaded.v2_research.is_available("v2_supreme_army"))
	GameManager.check_victories()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "nenhuma vitória disparou")

# --- Casos isolados ------------------------------------------------------------------------------------------

func test_cancelling_the_charge_and_retreat_targeting_by_any_means_consumes_nothing():
	var c := _short_setup(6)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _charge_foe(grid, c.rival, unit, 3)
	var start := unit.coord
	var hp := foe.hp
	grid.recompute_fog(c.human)
	SelectionManager._select_unit(unit)
	# (a) clique em outro tile (que não é um alvo)
	SelectionManager.use_technique_selected(CHARGE)
	assert_eq(SelectionManager.technique_targeting_id, CHARGE)
	var elsewhere := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if coord != foe.coord and coord != unit.coord and not (coord in SelectionManager.technique_target_coords):
			elsewhere = coord
			break
	SelectionManager._handle_technique_targeting_click(elsewhere)
	assert_eq(SelectionManager.technique_targeting_id, "", "clicar fora cancela")
	assert_eq(foe.hp, hp)
	assert_eq(unit.coord, start)
	assert_gt(unit.movement_left, 0.0)
	assert_false(unit.magic_cooldowns.has(CHARGE))
	assert_same(SelectionManager.selected_unit, unit, "a unidade continua selecionada")
	# (b) limpar a seleção durante a mira da Retirada
	SelectionManager.use_technique_selected(RETREAT)
	assert_eq(SelectionManager.technique_targeting_id, RETREAT)
	SelectionManager._clear_selection()
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_false(unit.magic_cooldowns.has(RETREAT))
	assert_eq(unit.coord, start)
	SelectionManager._select_unit(unit)
	# (c) ESC (o mesmo caminho do PauseMenu): cancela a mira; sem mira não faz nada
	SelectionManager.use_technique_selected(RETREAT)
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(unit.magic_cooldowns.has(RETREAT))
	assert_false(SelectionManager.cancel_technique_targeting(), "sem mira o ESC não faz nada")
	# (d) clicar num tile que NÃO está destacado cancela a Retirada sem mover
	SelectionManager.use_technique_selected(RETREAT)
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_eq(SelectionManager.technique_targeting_id, "")
	assert_eq(unit.coord, start)
	# (e) depois de tudo, a Carga ainda funciona
	SelectionManager._select_unit(unit)
	SelectionManager.use_technique_selected(CHARGE)
	SelectionManager._handle_technique_targeting_click(foe.coord)
	assert_lt(foe.hp, hp)
	assert_ne(unit.coord, start)

func test_the_charge_only_highlights_visible_enemies_in_the_window_and_a_target_in_the_fog_is_refused():
	var c := _short_setup(4)
	var grid: HexGrid = c.grid
	var unit: Unit = c.unit
	var foe := _charge_foe(grid, c.rival, unit, 3)
	grid.visibility[foe.coord] = HexGrid.Visibility.EXPLORED # fora da visão agora
	SelectionManager._select_unit(unit)
	var technique := V2DoctrineTechniqueDatabase.get_technique(CHARGE)
	assert_false(foe in V2TechniqueRuntime.strike_targets(unit, technique, grid), "fora da visão agora: não é alvo")
	SelectionManager.use_technique_selected(CHARGE)
	assert_false(foe.coord in SelectionManager.technique_target_coords, "nem destacado")
	SelectionManager.cancel_technique_targeting()
	grid.visibility[foe.coord] = HexGrid.Visibility.VISIBLE
	assert_true(foe in V2TechniqueRuntime.strike_targets(unit, technique, grid), "visível: é alvo")

func test_the_charge_cooldown_and_the_retreat_status_survive_save_and_load():
	var c := _short_setup(6)
	var unit: Unit = c.unit
	var grid: HexGrid = c.grid
	var foe := _charge_foe(grid, c.rival, unit, 3)
	assert_true(V2TechniqueRuntime.perform_strike(unit, CHARGE, foe, grid))
	unit.movement_left = unit.unit_data.movement_points
	var tiles := V2TechniqueRuntime.relocation_tiles(unit, V2DoctrineTechniqueDatabase.get_technique(RETREAT), grid)
	assert_true(V2TechniqueRuntime.relocate(unit, RETREAT, tiles[0], grid))
	var left := [V2TechniqueRuntime.cooldown_remaining(unit, CHARGE), V2TechniqueRuntime.cooldown_remaining(unit, RETREAT)]
	assert_eq(left, [3, 4])
	var coord := unit.coord
	_save_and_reload()
	var loaded_units := _units_of_kind(GameManager.human_player, CAVALIER)
	assert_eq(loaded_units.size(), 1)
	assert_eq(loaded_units[0].coord, coord)
	assert_eq([V2TechniqueRuntime.cooldown_remaining(loaded_units[0], CHARGE), V2TechniqueRuntime.cooldown_remaining(loaded_units[0], RETREAT)], left)
	assert_true(V2TechniqueRuntime.is_active(loaded_units[0], RETREAT), "o efeito da Retirada foi salvo")
	assert_false(loaded_units[0].magic_status.has(CHARGE), "a Carga não guarda efeito")
	_end_turn()
	assert_false(V2TechniqueRuntime.is_active(loaded_units[0], RETREAT), "e expira no turno certo depois do load")

func test_a_griffon_in_production_survives_save_and_load_and_blocks_the_others_in_another_city():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	var city: City = c.city
	city.buildings[ORDER] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY, W_HALL, ARENA, R_CAMP, R_TOWER])
	assert_true(second.can_train(CHAMPION) and second.can_train(HERO) and second.can_train(LEGEND_HUNTER))
	city.set_production(GRIFFON)
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(second.can_train(kind), "o Grifo em produção reserva o slot único (%s)" % kind)
	_save_and_reload()
	var loaded := GameManager.human_player
	assert_eq(loaded.cities.size(), 2)
	var producing: City = loaded.cities.filter(func(x): return x.production_item == GRIFFON)[0]
	var other: City = loaded.cities.filter(func(x): return x != producing)[0]
	assert_true(V2LegendarySystem.has_legendary_in_production(loaded))
	for kind in [CHAMPION, HERO, LEGEND_HUNTER]:
		assert_false(other.can_train(kind), "a reserva vem da ordem de produção salva (%s)" % kind)
	producing.set_production("")
	assert_true(other.can_train(CHAMPION) and other.can_train(HERO) and other.can_train(LEGEND_HUNTER), "cancelar libera")

func test_a_griffon_and_a_champion_finishing_in_the_same_turn_never_create_two_legendaries():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	for n in range(1, 10):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	var city: City = c.city
	city.buildings[ORDER] = true
	var second := _second_city(c.grid, human, [G_HALL, G_MASTERY])
	# Estado forçado (o gate normal impediria): duas ordens Lendárias prontas no mesmo turno, de Doutrinas diferentes.
	city.set_production(GRIFFON)
	second.set_production(CHAMPION)
	_end_turn()
	assert_push_error("não nasceu")
	var legends := 0
	for unit in human.units:
		if V2LegendarySystem.is_legendary_unit(unit):
			legends += 1
	assert_eq(legends, 1, "jamais duas Lendárias ativas")
	assert_eq(V2LegendarySystem.active_legendary_units(human).size(), 1)

func test_the_conventional_armored_production_is_untouched_by_the_legendary_slot():
	var c := _short_setup(9)
	var human: PlayerData = c.human
	var city: City = c.city
	city.buildings[ORDER] = true
	city.set_production(GRIFFON)
	assert_true(city.can_train(ARMORED))
	city.set_production(ARMORED)
	_end_turn()
	assert_eq(_units_of_kind(human, ARMORED).size(), 1)
	assert_eq(_units_of_kind(human, GRIFFON).size(), 0)

func test_a_flying_unit_takes_no_multi_turn_move_orders_and_a_ground_cavalier_keeps_them():
	var c := _short_setup(9)
	var grid: HexGrid = c.grid
	var human: PlayerData = c.human
	var cavalier: Unit = c.unit
	var griffon := grid.spawn_unit(WorldSetup.find_spawn_tile(grid, cavalier.coord), UnitDatabase.create_unit(GRIFFON), human)
	assert_not_null(griffon)
	var far := Vector2i(999, 999)
	for coord in grid.tiles.keys():
		if HexMetrics.axial_distance(cavalier.coord, coord) >= 8 and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and not grid.compute_path(cavalier.coord, coord, human, false, false).is_empty():
			far = coord
			break
	assert_ne(far, Vector2i(999, 999), "pré-condição: um destino distante com caminho por terra")
	assert_false(SelectionManager._try_queue_move_order(griffon, far), "o voo tático não tem ordem de vários turnos")
	assert_eq(griffon.move_order_target, Unit.NO_MOVE_ORDER)
	assert_true(SelectionManager._try_queue_move_order(cavalier, far), "a cavalaria terrestre segue com a ordem de sempre")
	assert_ne(cavalier.move_order_target, Unit.NO_MOVE_ORDER)

func test_ai_civilizations_keep_playing_with_the_cavalry_content_present():
	var c := _short_setup(9)
	for i in 6:
		_end_turn()
	for rival in GameManager.rival_players:
		for rival_city in rival.cities:
			assert_false(rival_city.buildings.has(STABLE))
			assert_false(rival_city.buildings.has(ORDER))
			assert_ne(rival_city.production_item, GRIFFON)
		assert_eq(_units_of_kind(rival, GRIFFON).size(), 0)
		assert_eq(_units_of_kind(rival, CAVALIER).size(), 0, "a IA não usa conteúdo V2")
	assert_eq(GameManager.state, GameManager.GameState.PLAYING)
	assert_true(is_instance_valid(c.grid))

func test_an_ai_civilization_given_the_research_by_debug_builds_trains_charges_flies_and_respects_the_slot():
	var c := _short_setup(3)
	var rival: PlayerData = c.rival
	for n in range(1, 10):
		rival.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	var rival_city: City = rival.cities[0]
	rival_city.city_level = 3
	rival_city.buildings[STABLE] = true
	rival_city.buildings[ORDER] = true
	# Aetherlands V2, Fase 15 — o Grifo custa 5 Suprimentos (acima da base de 4) e Estábulo+Ordem
	# têm gold_upkeep sem Mercado -- Fazenda + Ouro de sobra evitam que Suprimentos/Déficit
	# bloqueiem o que este teste verifica (RivalAI resolve a forma certa e respeita o slot).
	rival_city.buildings["v2_building_farm"] = true
	rival_city.repeatable_building_counts["v2_building_farm"] = 1
	if rival.gold <= 0.0:
		rival.gold = 1000.0
	var offered: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.filter(func(kind): return rival.has_unlocked(kind) and rival_city.can_train(kind) and kind.begins_with("v2_"))
	assert_true(offered.has(ARMORED), "resolve a forma correta")
	assert_false(offered.has(CAVALIER) or offered.has(SHOCK))
	assert_true(offered.has(GRIFFON), "e o Lendário respeita o slot: livre, pode")
	# As técnicas funcionam sem crash quando a civilização de IA as usa (sem estratégia: só o runtime), inclusive o voo.
	var grid: HexGrid = c.grid
	var charger := grid.spawn_unit(_free_at(grid, rival_city.coord, 2), UnitDatabase.create_unit(ARMORED), rival)
	var victim := _charge_foe(grid, c.human, charger, 3)
	assert_true(V2TechniqueRuntime.can_use(charger, CHARGE, grid), V2TechniqueRuntime.unavailable_reason(charger, CHARGE, grid))
	assert_true(V2TechniqueRuntime.perform_strike(charger, CHARGE, victim, grid))
	var flyer := grid.spawn_unit(_free_at(grid, rival_city.coord, 3), UnitDatabase.create_unit(GRIFFON), rival)
	assert_not_null(flyer)
	assert_false(rival_city.can_train(GRIFFON), "com o Grifo da IA vivo o slot dela está tomado")
	for i in 3:
		_end_turn()
	assert_eq(GameManager.state, GameManager.GameState.PLAYING, "não crasha com a unidade voadora no jogo da IA")
	assert_true(is_instance_valid(flyer))
