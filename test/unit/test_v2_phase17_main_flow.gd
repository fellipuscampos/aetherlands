extends GutTest

## Aetherlands V2, Fase 17 — FLUXO PRINCIPAL DA ESCOLA SAGRADA (§147); o cabeçalho de fixture é o mesmo dos fluxos da Fase 16.
## (Texto original do cabeçalho abaixo.) Fase 16 — FLUXOS PRINCIPAIS num jogo REAL (mapa gerado, pesquisa por
## Conhecimento, projetos pela fila de produção + fim de turno, Ataque da Cidade pela mira da
## SelectionManager, IA rival pelo turno de verdade, save/load de verdade).
## §127 Infraestrutura defensiva: Urbanização N1..N3 -> Cidade II..IV -> Muralhas I..Fortaleza,
##      escudo, upkeep, Déficit, Ataque da Cidade (mira/ESC/uma vez por turno/save), paridade da IA.
## §128 Supremacia Militar V2: acesso, conquistas de Cidade III+, progresso, perda, vitória.
## §129 Cerco x Fortaleza x vitória: a Munição e o Bombardeio atravessam a Fortaleza (escudo
##      primeiro), a captura mantém a fortificação e fecha a vitória.
## Atalhos DECLARADOS: debug_mode acelera só a PRODUÇÃO humana pra 1 turno; o Ouro dos projetos de
## City Level (Fase 13) é concedido; cidades rivais de teste são fundadas num terreno limpo
## ("arena") e as unidades militares de teste nascem direto (não é o assunto destes fluxos).

const TEST_SAVE_PATH := "user://test_v2_phase17_main_flow_savegame.json"
const G_HALL := "v2_building_guardian_hall"
const G_MASTERY := "v2_building_guardian_mastery"
const BOMBARD := "v2_unit_bombard"
const BOMBARDMENT := "v2_technique_prepared_bombardment"
const CAPSTONE := "v2_supreme_army"
const MILITARY := V2ResearchNode.TreeType.MILITARY_DOCTRINE
const MAP_WIDTH := 40
const MAP_HEIGHT := 24

var _hex_grids: Array[HexGrid] = []
var _arena_centers: Array[Vector2i] = []

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
	_arena_centers.clear()

func after_each():
	SelectionManager.reset()
	for player in GameManager.players:
		player.release_relations()
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

# --- Helpers ---------------------------------------------------------------------------------------

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

func _research_unlock(state: V2ResearchState, unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	if state.is_completed(node.id):
		return
	assert_true(state.select_research(node.id), "select %s" % node.id)
	state.add_knowledge(node.cost)
	assert_true(state.is_completed(node.id), "concluiu %s" % node.id)

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing, "sem fila de IA espalhada nos testes")
	_clear_wandering_monsters_near_human_cities()

## Mesma razão dos fluxos das Doutrinas: sem a milícia automática, monstros errantes do mapa gerado
## podem encostar na cidade humana e roubar tiles/ser alvos que este fluxo não controla.
func _clear_wandering_monsters_near_human_cities() -> void:
	var grid: HexGrid = GameManager.hex_grid
	for city in GameManager.human_player.cities:
		for coord in HexMetrics.coords_within(city.coord, 3):
			var unit := grid.get_unit_at(coord)
			if unit != null and unit.owner_player == null and not unit.world_event_managed:
				grid.remove_unit(unit)

func _notified(text: String) -> bool:
	for i in get_signal_emit_count(EventBus, "notify"):
		if String(get_signal_parameters(EventBus, "notify", i)[0]) == text:
			return true
	return false

## Projeto local pela fila (mesmo gate do botão da HUD) + fim de turno.
func _run_city_project(city: City, project_id: String) -> void:
	_clear_city_ring(city)
	city.set_production(project_id)
	assert_eq(city.production_item, project_id)
	_end_turn()

func _clear_city_ring(city: City) -> void:
	var grid: HexGrid = GameManager.hex_grid
	for unit in GameManager.human_player.units.duplicate():
		if not is_instance_valid(unit) or HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		for coord in HexMetrics.coords_within(city.coord, 6):
			if HexMetrics.axial_distance(coord, city.coord) >= 4 and grid.tiles.has(coord) and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
				grid.teleport_unit(unit, coord)
				break

func _upgrade_city(city: City, level: int) -> void:
	GameManager.human_player.gold += V2CityLevelData.upgrade_gold_cost(level) + 50.0 # Ouro concedido (atalho declarado)
	assert_true(city.can_start_city_upgrade(), city.city_upgrade_unavailable_reason())
	_run_city_project(city, V2CityLevelData.project_id_for_level(level))
	assert_eq(city.city_level, level, "Cidade %d" % level)

func _fortify(city: City, level: int) -> void:
	assert_true(city.can_start_fortification(), city.fortification_unavailable_reason())
	_run_city_project(city, V2FortificationData.project_id(level))
	assert_eq(city.fortification_level, level, V2FortificationData.display_name(level))

## Um disco de grama limpo (sem unidades), longe de toda cidade existente e de outras arenas.
func _arena(grid: HexGrid, radius: int = 3) -> Vector2i:
	for coord in grid.tiles.keys():
		var ok := true
		for c in HexMetrics.coords_within(coord, radius + 1):
			if not grid.tiles.has(c):
				ok = false
				break
		if not ok:
			continue
		for other in grid.cities_by_coord.keys():
			if HexMetrics.axial_distance(coord, other) <= radius + 4:
				ok = false
				break
		for other in _arena_centers:
			if HexMetrics.axial_distance(coord, other) <= 2 * radius + 4:
				ok = false
		if not ok:
			continue
		for c in HexMetrics.coords_within(coord, radius):
			grid.tiles[c] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
			var occupant := grid.get_unit_at(c)
			if occupant != null:
				grid.remove_unit(occupant)
		_arena_centers.append(coord)
		return coord
	fail_test("sem espaço pra uma arena de raio %d" % radius)
	return Vector2i(999, 999)

func _rival_city(grid: HexGrid, owner: PlayerData, level: int, fortification: int = 0) -> City:
	var center := _arena(grid)
	var city := grid.found_city(center, owner, "Centro de %s" % owner.civ.civ_name, true)
	city.city_level = level
	city.fortification_level = fortification
	city.hp = city.max_hp()
	city.shield = city.max_shield()
	return city

func _spawn(grid: HexGrid, kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var occupant := grid.get_unit_at(coord)
	if occupant != null:
		grid.remove_unit(occupant) # tile de teste: sai quem sobrou de um passo anterior
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

## Ataque básico real (seleção + clique) até a cidade trocar de dono.
func _capture_with(grid: HexGrid, attacker: Unit, city: City) -> void:
	var owner := attacker.owner_player
	for i in 40:
		if city.owner_player == owner:
			return
		attacker.movement_left = attacker.unit_data.movement_points
		attacker.hp = attacker.unit_data.max_hp
		SelectionManager._select_unit(attacker)
		SelectionManager._attack_from_selected(city.coord)
	assert_eq(city.owner_player, owner, "capturou %s" % city.city_name)

func _save_and_load() -> HexGrid:
	assert_true(SaveManager.save_game(GameManager.hex_grid, TEST_SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	_hex_grids.append(loaded)
	assert_true(SaveManager.load_game(loaded, TEST_SAVE_PATH))
	GameManager.hex_grid = loaded
	return loaded

func _city_named(player: PlayerData, city_name: String) -> City:
	for city in player.cities:
		if city.city_name == city_name:
			return city
	return null


func _learn_node(state: V2ResearchState, node_id: String) -> void:
	if state.is_completed(node_id):
		return
	assert_true(state.select_research(node_id), "select %s" % node_id)
	state.add_knowledge(V2ResearchDatabase.get_node(node_id).cost)
	assert_true(state.is_completed(node_id), "concluiu %s" % node_id)

func _build(city: City, building_id: String) -> void:
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, building_id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "há tile livre pro %s" % building_id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	assert_eq(city.production_item, building_id)
	_end_turn()
	assert_true(city.buildings.has(building_id), "%s construído" % building_id)

func _units_of_kind(player: PlayerData, kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in player.units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

func _find(player: PlayerData, kind: String) -> Unit:
	var units := _units_of_kind(player, kind)
	return units[0] if not units.is_empty() else null

func _free_near(grid: HexGrid, center: Vector2i, distance: int) -> Vector2i:
	for coord in HexMetrics.coords_within(center, distance):
		if HexMetrics.axial_distance(coord, center) >= 1 and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			return coord
	return Vector2i(999, 999)

func _cast(unit: Unit, spell_id: String, target: Unit) -> void:
	unit.movement_left = unit.unit_data.movement_points
	SelectionManager._select_unit(unit)
	SelectionManager.use_v2_spell_selected(spell_id)
	assert_eq(SelectionManager.v2_spell_targeting_id, spell_id, "mira de %s: %s" % [spell_id, V2MagicRuntime.unavailable_reason(unit, spell_id)])
	SelectionManager._handle_v2_spell_targeting_click(target.coord)

# --- §147 Fluxo principal da Escola Sagrada -----------------------------------------------------------------

func test_147_sacred_school_flow_from_the_temple_to_the_seraph_across_save_and_load():
	# 1-4. Nova partida, cidade fundada, Conhecimento e Mana gerados pela economia real.
	var grid := _new_game()
	var human := GameManager.human_player
	var state := human.v2_research
	var city := _found_human_city(grid)
	city.city_level = 3 # atalho declarado: slots pros prédios deste fluxo (City Level tem fluxo próprio)
	var mana_start := human.mana
	assert_true(state.select_research("v2_magic_sacred_1"), "5-6. pesquisa da Escola Sagrada")
	for i in 10:
		if state.is_completed("v2_magic_sacred_1"):
			break
		_end_turn()
	assert_true(state.is_completed("v2_magic_sacred_1"), "3. Conhecimento natural completou o N1")
	assert_gt(human.mana, mana_start, "4. Mana natural (base por cidade)")
	# 7-8. Templo.
	_learn_node(state, "v2_magic_sacred_2")
	_build(city, "v2_building_sacred_temple")
	# 9-12. Clérigo: produção normal, 2 Suprimentos, sem ataque básico.
	_learn_node(state, "v2_magic_sacred_3")
	_clear_city_ring(city)
	var supply_before := V2LogisticsRuntime.player_supply_used(human)
	city.set_production("v2_unit_sacred_cleric")
	_end_turn()
	var cleric := _find(human, "v2_unit_sacred_cleric")
	assert_not_null(cleric, "10. Clérigo treinado")
	assert_eq(V2LogisticsRuntime.player_supply_used(human) - supply_before, 2, "11. supply 2")
	assert_false(cleric.unit_data.can_basic_attack, "12. sem ataque básico")
	SelectionManager._select_unit(cleric)
	assert_true(SelectionManager.attackable.is_empty())
	# 13-16. Aliado ferido, Luz Restauradora, Mana e cura.
	var ally_coord := _free_near(grid, cleric.coord, 1)
	var ally := grid.spawn_unit(ally_coord, UnitDatabase.create_unit("warrior"), human)
	ally.hp = 3.0
	_learn_node(state, "v2_magic_sacred_4")
	human.mana = 100.0 # atalho declarado: Mana de sobra pro repertório (a origem econômica é provada em test_v2_sacred_integration)
	_cast(cleric, "v2_spell_restoring_light", ally)
	assert_eq([ally.hp, human.mana], [11.0, 96.0], "16. cura 8, custa 4")
	# 17-21. Égide em combate real e expiração no turno do dono.
	_learn_node(state, "v2_magic_sacred_5")
	_cast(cleric, "v2_spell_sacred_aegis", ally)
	assert_true(V2MagicRuntime.is_status_active(ally, "v2_spell_sacred_aegis"), "18")
	var rival: PlayerData = GameManager.rival_players[0]
	Diplomacy.declare_war(human, rival)
	var enemy_coord := _free_near(grid, ally.coord, 1)
	var enemy := grid.spawn_unit(enemy_coord, UnitDatabase.create_unit("warrior"), rival)
	var shielded: float = CombatResolver.predict(enemy, ally, grid).damage_to_defender
	var ally_hp := ally.hp
	CombatResolver.resolve(enemy, ally, grid)
	assert_almost_eq(ally_hp - ally.hp, shielded, 0.0001, "19. a Égide entra no combate real")
	grid.remove_unit(enemy)
	_end_turn()
	assert_false(V2MagicRuntime.is_status_active(ally, "v2_spell_sacred_aegis"), "21. expirou no turno do dono")
	# 22-25. Onda de Cura num grupo ferido.
	_learn_node(state, "v2_magic_sacred_6")
	var group: Array[Unit] = [ally]
	for coord in grid.get_neighbors(ally.coord):
		if group.size() >= 3:
			break
		if WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			group.append(grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), human))
	for unit in group:
		unit.hp = 2.0
	_cast(cleric, "v2_spell_healing_wave", ally)
	for unit in group:
		assert_eq(unit.hp, 8.0, "25. múltiplas curas")
	# 26-28. Milagre num aliado quase morto.
	_learn_node(state, "v2_magic_sacred_7")
	ally.hp = 0.5
	_cast(cleric, "v2_spell_miracle", ally)
	assert_eq(ally.hp, ally.unit_data.max_hp, "28. vida cheia")
	# 29-31. Catedral e pesquisa do Serafim.
	_learn_node(state, "v2_magic_sacred_8")
	_build(city, "v2_building_sacred_ritual")
	_learn_node(state, "v2_magic_sacred_9")
	# 32-35. Produção reserva o slot; uma segunda Catedral não pode iniciar.
	assert_eq(UnitDatabase.create_unit("v2_manifestation_seraph").production_cost, 100.0, "32. 100 PP + 60 Mana")
	GameManager.debug_mode = false # a produção do Serafim precisa de turnos reais pra testar a espera
	human.mana = 60.0
	_clear_city_ring(city)
	assert_true(city.can_train("v2_manifestation_seraph"))
	city.set_production("v2_manifestation_seraph")
	assert_false(V2ManifestationSystem.slot_available(human, "sacred", null), "34. slot reservado")
	var other := grid.found_city(_far_land(grid, city.coord), human, "Segunda Catedral", true)
	other.city_level = 3
	other.buildings["v2_building_sacred_temple"] = true
	other.buildings["v2_building_sacred_ritual"] = true
	assert_false(other.can_train("v2_manifestation_seraph"), "35. segundo Serafim bloqueado")
	# 36-38. Gasta Mana antes da conclusão; PP completos -> espera.
	human.mana = 5.0
	city.stored_production = 99.9
	_end_turn()
	assert_eq(_units_of_kind(human, "v2_manifestation_seraph").size(), 0, "38. esperando")
	assert_eq(city.production_item, "v2_manifestation_seraph")
	assert_eq(city.stored_production, 100.0, "sem perder PP")
	# 39-40. Mana recuperada -> nasce, cobrando uma vez.
	human.mana = 80.0
	_end_turn()
	var seraph := _find(human, "v2_manifestation_seraph")
	assert_not_null(seraph, "40. Serafim nasce")
	assert_lt(human.mana, 80.0 - 59.0 + 5.0, "60 cobrados uma vez (mais a renda do turno)")
	# 41-45. Voo, traços, sem ataque, aura, feitiços.
	assert_eq(seraph.unit_data.movement_profile, UnitData.MovementProfile.FLYING, "41")
	assert_true(seraph.unit_data.has_trait(UnitData.TRAIT_CASTER) and seraph.unit_data.has_trait(UnitData.TRAIT_GRAND_MANIFESTATION), "42")
	assert_false(seraph.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(seraph.unit_data.can_basic_attack, "43")
	var near := grid.get_unit_at(_free_near(grid, seraph.coord, 2))
	if near == null:
		near = grid.spawn_unit(_free_near(grid, seraph.coord, 2), UnitDatabase.create_unit("warrior"), human)
	if near.owner_player == human:
		assert_almost_eq(V2UnitAuras.defense_multiplier(near), 1.15, 0.0001, "44. Presença Sagrada")
	assert_eq(V2MagicRuntime.spells_for_unit(seraph).size(), 4, "45. repertório Sagrado")
	# 46-55. Save/load.
	cleric.magic_cooldowns["v2_spell_miracle"] = TurnManager.turn_number + 3
	var mana_saved := human.mana
	var cleric_coord := cleric.coord
	_save_and_load()
	human = GameManager.human_player
	state = human.v2_research
	for i in range(1, 10):
		assert_true(state.is_completed("v2_magic_sacred_%d" % i), "48. pesquisa N%d" % i)
	assert_eq(human.mana, mana_saved, "49. Mana")
	var loaded_city := human.cities[0]
	assert_true(loaded_city.buildings.has("v2_building_sacred_temple"), "50. Templo")
	assert_true(loaded_city.buildings.has("v2_building_sacred_ritual"), "51. Catedral")
	var loaded_cleric := GameManager.hex_grid.get_unit_at(cleric_coord)
	assert_not_null(loaded_cleric, "52. Clérigo")
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_cleric, "v2_spell_miracle"), 3, "53. recarga")
	var loaded_seraph := _find(human, "v2_manifestation_seraph")
	assert_not_null(loaded_seraph, "54. Serafim")
	assert_false(V2ManifestationSystem.slot_available(human, "sacred"), "55. slot derivado")
	# 56-57. O resto do V2 intacto e nenhuma Transcendência.
	assert_eq(V2DoctrineContent.CONNECTED_UNLOCK_IDS.size(), 55, "56. Doutrinas intactas")
	assert_eq(V2InfrastructureContent.CONNECTED_UNLOCK_IDS.size(), 18, "56. Infraestrutura intacta")
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER, "57. sem vitória por Transcendência")

func _far_land(grid: HexGrid, center: Vector2i) -> Vector2i:
	for coord in grid.tiles.keys():
		if HexMetrics.axial_distance(coord, center) >= 6 and WorldSetup._is_valid_spawn(grid, coord) and grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.city_owning_tile(coord) == null:
			var ok := true
			for other in grid.cities_by_coord.keys():
				if HexMetrics.axial_distance(coord, other) < 4:
					ok = false
			if ok:
				return coord
	fail_test("sem terra longe")
	return Vector2i(999, 999)
