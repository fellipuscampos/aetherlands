extends GutTest

## Aetherlands V2, Fase 20 — a fundação GENÉRICA de modificação física persistente de terreno (V2TerrainRuntime):
## dado/banco, estado por coordenada sem dono, elegibilidade, custo de movimento pela fonte única do HexGrid (alcance,
## A* com desvio, marcha, regra do primeiro passo, perfis que ignoram terreno), Defesa física em predict == resolve,
## dano mágico intocado, limpeza por construção/melhoria/fundação, anexação e captura não limpam, save/load global,
## save antigo, id inválido, marcador visual e neblina, inspetor e caminho rápido.

const SAVE_PATH := "user://test_v2_terrain_modification.json"
const GROVE := "v2_terrain_dense_grove"
const RAISED := "v2_terrain_raised_ground"

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

func before_each():
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 20
	human.gold = 500.0

func after_each():
	SelectionManager.reset()
	SaveManager.delete_save(SAVE_PATH)
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	GameManager.state = _original_state
	for player in _players:
		player.release_relations()
	_players.clear()
	if is_instance_valid(grid):
		grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _apply(coord: Vector2i, id: String = GROVE) -> void:
	assert_true(V2TerrainRuntime.apply(grid, coord, id), "%s em %s" % [id, str(coord)])

# --- Dado ---------------------------------------------------------------------------------------------------------

func test_modification_records_and_inert_defaults():
	var grove := V2TerrainModificationDatabase.get_modification(GROVE)
	assert_eq([grove.display_name, grove.movement_cost_delta, grove.defense_multiplier, grove.requires_ground_passable], ["Bosque Denso", 1, 1.20, true])
	var raised := V2TerrainModificationDatabase.get_modification(RAISED)
	assert_eq([raised.display_name, raised.movement_cost_delta, raised.defense_multiplier, raised.requires_ground_passable], ["Terreno Elevado", 2, 1.35, true])
	assert_ne(grove.visual_kind, raised.visual_kind, "marcadores distintos")
	var blank := V2TerrainModificationData.new()
	assert_eq([blank.movement_cost_delta, blank.defense_multiplier, blank.requires_ground_passable], [0, 1.0, true])
	assert_null(V2TerrainModificationDatabase.get_modification("v2_terrain_nao_existe"))
	assert_eq(V2TerrainModificationDatabase.movement_delta("v2_terrain_nao_existe"), 0)
	assert_eq(V2TerrainModificationDatabase.all_modifications().size(), 2, "exatamente duas nesta fase")
	assert_eq(V2TerrainModificationDatabase.effect_summary(grove), "+1 custo de movimento e +20% Defesa física")

# --- Aplicar / remover --------------------------------------------------------------------------------------------

func test_eligibility_matrix():
	var coord := Vector2i(2, 0)
	assert_eq(V2TerrainRuntime.application_reason(grid, coord, GROVE), "", "grama livre")
	assert_eq(V2TerrainRuntime.application_reason(grid, Vector2i(99, 0), GROVE), V2TerrainRuntime.REASON_INVALID)
	assert_eq(V2TerrainRuntime.application_reason(grid, coord, "v2_terrain_nao_existe"), V2TerrainRuntime.REASON_INVALID)
	grid.tiles[Vector2i(3, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.tiles[Vector2i(4, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.LAVA)
	for blocked in [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]:
		assert_eq(V2TerrainRuntime.application_reason(grid, blocked, GROVE), V2TerrainRuntime.REASON_TERRAIN, str(blocked))
	var city := grid.found_city(Vector2i(-4, 0), human, "Capital", true)
	assert_eq(V2TerrainRuntime.application_reason(grid, city.coord, GROVE), V2TerrainRuntime.REASON_CITY)
	grid.place_building(Vector2i(-3, 0), "v2_building_market", human)
	assert_eq(V2TerrainRuntime.application_reason(grid, Vector2i(-3, 0), GROVE), V2TerrainRuntime.REASON_STRUCTURE)
	city.resource_improvements[Vector2i(-4, 1)] = "v2_improvement_iron_mine"
	assert_eq(V2TerrainRuntime.application_reason(grid, Vector2i(-4, 1), GROVE), V2TerrainRuntime.REASON_STRUCTURE, "melhoria de recurso V2")
	grid.get_tile(Vector2i(0, 2)).resource = "iron"
	assert_eq(V2TerrainRuntime.application_reason(grid, Vector2i(0, 2), GROVE), "", "recurso natural bruto pode ficar")
	_unit("warrior", human, Vector2i(1, 1))
	assert_eq(V2TerrainRuntime.application_reason(grid, Vector2i(1, 1), GROVE), "", "unidade não impede a camada")
	_apply(coord)
	assert_eq(V2TerrainRuntime.application_reason(grid, coord, RAISED), V2TerrainRuntime.REASON_ALREADY, "uma por tile")
	assert_false(V2TerrainRuntime.apply(grid, coord, RAISED), "nunca empilha")
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), GROVE)

func test_apply_keeps_base_terrain_and_resource_and_remove_restores():
	var coord := Vector2i(1, 0)
	var tile := grid.get_tile(coord)
	tile.resource = "gems"
	var type_before := tile.terrain_type
	var yields_before := [tile.food_yield, tile.production_yield, tile.gold_yield, tile.movement_cost, tile.defense_bonus]
	_apply(coord, RAISED)
	assert_eq(grid.get_tile(coord), tile, "o objeto do tile nunca é trocado")
	assert_eq(tile.terrain_type, type_before)
	assert_eq(tile.resource, "gems", "recurso intacto")
	assert_eq([tile.food_yield, tile.production_yield, tile.gold_yield, tile.movement_cost, tile.defense_bonus], yields_before)
	assert_true(V2TerrainRuntime.remove(grid, coord))
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), "")
	assert_false(V2TerrainRuntime.remove(grid, coord), "remover nada = false")
	assert_eq(V2TerrainRuntime.removal_reason(grid, coord), V2TerrainRuntime.REASON_NONE)
	assert_eq(tile.resource, "gems")

func test_ownerless_across_territories_and_capture():
	var own := grid.found_city(Vector2i(-4, 0), human, "Própria", true)
	var enemy := grid.found_city(Vector2i(4, 0), rival, "Inimiga", true)
	_apply(Vector2i(-3, 0))     # território próprio
	_apply(Vector2i(0, 3))      # neutro
	_apply(Vector2i(3, 0))      # território inimigo
	assert_true(Vector2i(3, 0) in enemy.owned_tiles and Vector2i(-3, 0) in own.owned_tiles)
	var enemy_defender := _unit("warrior", rival, Vector2i(3, 0))
	var own_defender := _unit("warrior", human, Vector2i(-3, 0))
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, enemy_defender.coord), 1.2, "o inimigo aproveita")
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, own_defender.coord), 1.2)
	grid.capture_city(enemy, human)
	assert_eq(V2TerrainRuntime.modification_id_at(grid, Vector2i(3, 0)), GROVE, "a captura não limpa")
	var annex_target := Vector2i(-2, 0)
	_apply(annex_target)
	own.city_level = 2
	own.annexation_points = 1
	assert_true(own.annex_tile(annex_target, grid), own.annex_unavailable_reason(annex_target, grid))
	assert_eq(V2TerrainRuntime.modification_id_at(grid, annex_target), GROVE, "a anexação não limpa")
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	assert_false(text.contains("creator"), "nenhum dono salvo")

# --- Movimento --------------------------------------------------------------------------------------------------

func test_reachable_cost_grows_by_the_delta_and_raised_never_becomes_a_wall():
	var warrior := _unit("warrior", human, Vector2i.ZERO)
	assert_eq(grid.unit_reachable(warrior).get(Vector2i(1, 0)), 1.0)
	_apply(Vector2i(1, 0))
	assert_eq(grid.terrain_step_cost(Vector2i(1, 0)), 2.0)
	assert_eq(grid.unit_reachable(warrior).get(Vector2i(1, 0)), 2.0, "Bosque: +1")
	assert_false(grid.unit_reachable(warrior).has(Vector2i(2, 0)), "(2,0) só passa por (1,0): 2 + 1 = 3 > 2")
	V2TerrainRuntime.remove(grid, Vector2i(1, 0))
	_apply(Vector2i(1, 0), RAISED)
	assert_eq(grid.terrain_step_cost(Vector2i(1, 0)), 3.0)
	var reach := grid.unit_reachable(warrior)
	assert_true(reach.has(Vector2i(1, 0)), "regra do primeiro passo: custo 3 com Movimento 2 ainda entra")
	assert_eq(reach[Vector2i(1, 0)], 2.0, "e gasta todo o movimento")
	grid.move_unit(warrior, Vector2i(1, 0), reach[Vector2i(1, 0)])
	assert_eq(warrior.movement_left, 0.0)

func test_first_step_rule_only_applies_to_the_first_step():
	var warrior := _unit("warrior", human, Vector2i.ZERO)
	_apply(Vector2i(2, 0), RAISED)
	var reach := grid.unit_reachable(warrior)
	assert_eq(reach.get(Vector2i(1, 0)), 1.0)
	assert_false(reach.has(Vector2i(2, 0)), "no segundo passo o custo 3 não cabe no 1 restante")
	assert_eq(HexGrid.affordable_step_cost(3.0, 2.0, true), 2.0)
	assert_eq(HexGrid.affordable_step_cost(3.0, 1.0, false), -1.0)
	assert_eq(HexGrid.affordable_step_cost(1.0, 2.0, false), 1.0)
	assert_eq(HexGrid.affordable_step_cost(3.0, 0.0, true), -1.0)

func test_pathfinder_detours_when_cheaper_and_crosses_when_not():
	assert_eq(grid.compute_path(Vector2i.ZERO, Vector2i(2, 0), human).size(), 2, "direto por (1,0)")
	_apply(Vector2i(1, 0), RAISED)
	var detour := grid.compute_path(Vector2i.ZERO, Vector2i(2, 0), human)
	assert_eq(detour.size(), 3, "desvia: 3 passos (custo 3) < direto (3 + 1)")
	assert_false(Vector2i(1, 0) in detour)
	V2TerrainRuntime.remove(grid, Vector2i(1, 0))
	_apply(Vector2i(1, 0))
	var through := grid.compute_path(Vector2i.ZERO, Vector2i(2, 0), human)
	var cost := 0.0
	for step in through:
		cost += grid.terrain_step_cost(step)
	assert_eq(cost, 3.0, "Bosque (2 + 1) empata com o desvio (3): qualquer rota ótima custa 3")

func test_multi_turn_orders_follow_the_existing_recompute_behavior():
	var warrior := _unit("warrior", human, Vector2i.ZERO)
	warrior.move_order_target = Vector2i(4, 0)
	_apply(Vector2i(1, 0), RAISED)
	grid.continue_move_order(warrior)
	assert_ne(warrior.coord, Vector2i(1, 0), "a marcha recalcula o caminho a cada turno e evita o tile caro")
	assert_eq(warrior.move_order_target, Vector2i(4, 0), "a ordem continua")

func test_flying_v1_flies_infiltrator_and_retreat_flat_cost_ignore_the_delta_like_base_terrain():
	for coord in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, -1)]:
		_apply(coord, RAISED)
	var griffon := _unit("v2_legendary_griffon_rider", human, Vector2i.ZERO)
	assert_eq(grid.unit_reachable(griffon).get(Vector2i(1, 0)), 1.0, "voo tático: distância geométrica")
	var v1_griffin := _unit("griffin", human, Vector2i(-3, 0))
	_apply(Vector2i(-2, 0), RAISED)
	assert_eq(grid.compute_reachable(v1_griffin.coord, 3.0, human, true).get(Vector2i(-2, 0)), 1.0, "voo V1: 1 por passo")
	var shadow := _unit("v2_legendary_shadow_master", human, Vector2i(3, 3))
	_apply(Vector2i(4, 3), RAISED)
	assert_eq(grid.unit_reachable(shadow).get(Vector2i(4, 3)), 1.0, "Passo Sombrio: custo plano, como já ignora o terreno-base")
	var ground := _unit("warrior", human, Vector2i(4, 2)) # vizinho de (4,3)
	assert_eq(grid.compute_reachable(ground.coord, 3.0, human).get(Vector2i(4, 3)), 3.0, "o terrestre normal paga +2")
	assert_eq(grid.compute_reachable(ground.coord, 3.0, human, false, false, true).get(Vector2i(4, 3)), 1.0, "custo plano (Retirada Tática) ignora o terreno")

func test_ai_step_movement_pays_the_central_cost():
	var warrior := _unit("warrior", rival, Vector2i.ZERO)
	_apply(Vector2i(1, 0))
	RivalAI.move_unit_toward(warrior, grid, Vector2i(3, 0))
	assert_ne(warrior.coord, Vector2i.ZERO, "andou")
	if warrior.coord == Vector2i(1, 0):
		assert_eq(warrior.movement_left, 0.0, "entrar no Bosque custou 2")

# --- Defesa ------------------------------------------------------------------------------------------------------

func test_physical_defense_factor_predict_equals_resolve():
	var attacker := _unit("v2_unit_weapon_master", rival, Vector2i(-1, 0))
	var defender := _unit("warrior", human, Vector2i.ZERO)
	var base := CombatResolver.predict(attacker, defender, grid)
	_apply(Vector2i.ZERO)
	var grove := CombatResolver.predict(attacker, defender, grid)
	assert_almost_eq(base.damage_to_defender - grove.damage_to_defender, 0.5 * 3.0 * 0.20, 0.0001, "+20% da Defesa 3 mitigada pela metade")
	V2TerrainRuntime.remove(grid, Vector2i.ZERO)
	_apply(Vector2i.ZERO, RAISED)
	var raised := CombatResolver.predict(attacker, defender, grid)
	assert_almost_eq(base.damage_to_defender - raised.damage_to_defender, 0.5 * 3.0 * 0.35, 0.0001)
	assert_gt(raised.damage_to_attacker, base.damage_to_attacker, "o revide sai da Defesa: cresce junto, sem exceção")
	var hp := defender.hp
	var attacker_hp := attacker.hp
	CombatResolver.resolve(attacker, defender, grid)
	assert_almost_eq(hp - defender.hp, raised.damage_to_defender, 0.0001, "predict == resolve")
	assert_almost_eq(attacker_hp - attacker.hp, raised.damage_to_attacker, 0.0001)

func test_terrain_ignoring_attacker_ignores_the_modification_too():
	var mage := _unit("mage", rival, Vector2i(-2, 0))
	var defender := _unit("warrior", human, Vector2i.ZERO)
	assert_true(mage.unit_data.ignores_terrain_defense)
	var base := CombatResolver.predict(mage, defender, grid)
	_apply(Vector2i.ZERO, RAISED)
	assert_almost_eq(CombatResolver.predict(mage, defender, grid).damage_to_defender, base.damage_to_defender, 0.0001)

func test_flying_defender_gets_the_bonus_like_base_terrain():
	var attacker := _unit("v2_unit_weapon_master", rival, Vector2i(-1, 0))
	var seraph := _unit("v2_manifestation_seraph", human, Vector2i.ZERO)
	var base := CombatResolver.predict(attacker, seraph, grid)
	_apply(Vector2i.ZERO)
	assert_lt(CombatResolver.predict(attacker, seraph, grid).damage_to_defender, base.damage_to_defender, "o terreno-base também protege voadores neste motor")

func test_magic_damage_ignores_the_modification():
	for i in range(1, 5):
		human.v2_research.complete_research("v2_magic_infernal_%d" % i)
	human.mana = 100.0
	var warlock := _unit("v2_unit_infernal_warlock", human, Vector2i.ZERO)
	var targets := [_unit("warrior", rival, Vector2i(2, 0)), _unit("warrior", rival, Vector2i(0, 2)), _unit("warrior", rival, Vector2i(-2, 2))]
	_apply(targets[1].coord)
	_apply(targets[2].coord, RAISED)
	var flame := V2SpellDatabase.get_spell("v2_spell_infernal_flame")
	for target in targets:
		assert_eq(V2MagicRuntime.predict_damage(warlock, target, flame), 6.0)
		warlock.movement_left = 2.0
		var hp: float = target.hp
		assert_true(V2MagicRuntime.cast(warlock, flame.id, target.coord))
		assert_eq(hp - target.hp, 6.0, "sem, Bosque, Elevado: dano idêntico")

# --- Construção limpa -----------------------------------------------------------------------------------------------

func test_building_placement_clears_only_when_it_actually_happens():
	var city := grid.found_city(Vector2i(-4, 0), human, "Capital", true)
	var site := Vector2i(-3, 0)
	_apply(site)
	assert_true(city.is_valid_building_tile(site, grid), "a modificação não impede construir")
	grid.place_building(site, "v2_building_market", human)
	assert_eq(V2TerrainRuntime.modification_id_at(grid, site), "", "o prédio limpou")
	assert_not_null(grid.get_building_at(site))
	var other := Vector2i(-4, 1)
	_apply(other)
	SelectionManager.start_building_placement(city, "v2_building_market")
	SelectionManager._handle_building_placement_click(Vector2i(6, -6)) # fora da área: a colocação não acontece
	assert_eq(V2TerrainRuntime.modification_id_at(grid, other), GROVE, "construção que não ocorre não limpa")

func test_resource_improvement_clears_on_success_only_and_yield_works():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var coord := Vector2i(1, 0)
	grid.get_tile(coord).resource = "iron"
	_apply(coord)
	var builder := _unit("v2_unit_builder", human, coord)
	builder.work_charges_remaining = 0
	assert_false(V2ConstructorRuntime.improve_resource(builder, grid), "sem carga: falha")
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), GROVE, "falha não limpa")
	builder.work_charges_remaining = 1
	var production := V2EconomyRuntime.city_production_income(city)
	assert_true(V2ConstructorRuntime.improve_resource(builder, grid))
	assert_eq(V2TerrainRuntime.modification_id_at(grid, coord), "", "a Mina limpou o Bosque")
	assert_eq(city.resource_improvements.get(coord), "v2_improvement_iron_mine")
	assert_gt(V2EconomyRuntime.city_production_income(city), production, "rendimento normal")

func test_city_foundation_clears_the_center_only():
	_apply(Vector2i.ZERO)
	_apply(Vector2i(1, 0))
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	assert_not_null(city)
	assert_eq(V2TerrainRuntime.modification_id_at(grid, Vector2i.ZERO), "")
	assert_eq(V2TerrainRuntime.modification_id_at(grid, Vector2i(1, 0)), GROVE, "o resto do território fica")

func test_enemy_can_still_build_on_a_grove_so_there_is_no_permanent_economic_lock():
	var city := grid.found_city(Vector2i(4, 0), rival, "Rival", true)
	_apply(Vector2i(3, 0))
	grid.place_building(Vector2i(3, 0), "v2_building_market", rival)
	assert_false(V2TerrainRuntime.has_modification(grid, Vector2i(3, 0)))
	assert_true(is_instance_valid(city))

# --- Save / load ----------------------------------------------------------------------------------------------------

func _roundtrip() -> void:
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	rival = GameManager.rival_players[0]

func test_global_save_and_load_restores_ids_effects_and_markers():
	grid.found_city(Vector2i(-4, 0), human, "Própria", true)
	grid.found_city(Vector2i(4, 0), rival, "Inimiga", true)
	_apply(Vector2i(-3, 0))
	_apply(Vector2i(0, 3), RAISED)
	_apply(Vector2i(3, 0))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	assert_true(text.contains("v2_terrain_modifications"))
	for forbidden in ["movement_cost_delta", "defense_multiplier", "creator"]:
		assert_false(text.contains(forbidden), "nada derivado salvo: %s" % forbidden)
	_roundtrip()
	assert_eq(grid.v2_terrain_modifications.size(), 3)
	assert_eq(V2TerrainRuntime.modification_id_at(grid, Vector2i(0, 3)), RAISED)
	assert_eq(grid.terrain_step_cost(Vector2i(0, 3)), 3.0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, Vector2i(3, 0)), 1.2)
	for coord in [Vector2i(-3, 0), Vector2i(0, 3), Vector2i(3, 0)]:
		assert_true(grid._terrain_modification_markers.has(coord), "marcador recriado: %s" % str(coord))

func test_legacy_save_without_the_block_loads_with_no_modifications():
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data.erase("v2_terrain_modifications")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_roundtrip()
	assert_true(grid.v2_terrain_modifications.is_empty())

func test_invalid_entries_are_ignored_without_breaking_the_load():
	_apply(Vector2i(1, 0))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data["v2_terrain_modifications"].append([2, 0, "v2_terrain_nao_existe"])
	data["v2_terrain_modifications"].append([999, 999, GROVE])
	data["v2_terrain_modifications"].append("lixo")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_roundtrip()
	assert_eq(grid.v2_terrain_modifications, {Vector2i(1, 0): GROVE})

# --- Visual, neblina, inspetor, caminho rápido ----------------------------------------------------------------------

func test_marker_is_created_updated_per_tile_and_follows_current_visibility():
	var coord := Vector2i(1, 0)
	_apply(coord)
	var marker: Node3D = grid._terrain_modification_markers[coord]
	assert_not_null(marker)
	assert_true(marker.get_child_count() > 0, "árvores reaproveitadas")
	assert_eq(grid._terrain_modification_markers.size(), 1, "só o tile tocado")
	var other := Vector2i(0, 2)
	_apply(other, RAISED)
	assert_eq(grid._terrain_modification_markers.size(), 2)
	grid.visibility[coord] = HexGrid.Visibility.EXPLORED
	grid.visibility[other] = HexGrid.Visibility.VISIBLE
	grid._apply_fog_to_entities(human)
	assert_false(marker.visible, "fora da visão não mostra")
	assert_true(grid._terrain_modification_markers[other].visible)
	assert_true(V2TerrainRuntime.has_modification(grid, coord), "a neblina nunca apaga o estado")
	V2TerrainRuntime.remove(grid, coord)
	assert_false(grid._terrain_modification_markers.has(coord))

func test_inspector_shows_the_modification_only_when_present_and_visible():
	var coord := Vector2i(1, 0)
	grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var plain := TileInspector.inspect(grid, coord, human)
	assert_false("\n".join(plain.terrain_lines).contains("Modificação"), "sem seção vazia")
	_apply(coord)
	var lines: Array = TileInspector.inspect(grid, coord, human).terrain_lines
	assert_true("Modificação: Bosque Denso" in lines)
	assert_true("Movimento: +1 custo" in lines)
	assert_true("Defesa física: +20%" in lines)
	grid.visibility[coord] = HexGrid.Visibility.EXPLORED
	assert_false("Modificação: Bosque Denso" in TileInspector.inspect(grid, coord, human).terrain_lines, "fora da visão não revela")

func test_fast_path_without_modifications():
	assert_true(grid.v2_terrain_modifications.is_empty())
	assert_eq(V2TerrainRuntime.movement_cost_delta(grid, Vector2i(1, 0)), 0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, Vector2i(1, 0)), 1.0)
	assert_eq(grid.terrain_step_cost(Vector2i(1, 0)), float(grid.get_tile(Vector2i(1, 0)).movement_cost))
	assert_eq(V2TerrainRuntime.defense_multiplier_at(null, Vector2i(1, 0)), 1.0)

func test_v1_terrain_transform_keeps_the_modification_layer():
	_apply(Vector2i(1, 0))
	grid.transform_tile_terrain(Vector2i(1, 0), HexTileData.TerrainType.PLAINS)
	assert_eq(V2TerrainRuntime.modification_id_at(grid, Vector2i(1, 0)), GROVE, "o estado vive por coordenada, não no objeto do tile")

func test_foundations_never_name_druidic_content():
	var forbidden := ["dense_grove", "raised_ground", "v2_unit_druid", "nature_avatar", "\"druidism\"", "grow_grove", "restore_terrain", "raise_ground", "awaken_forest", "Bosque Denso", "Terreno Elevado"]
	for path in ["res://scripts/core/V2TerrainRuntime.gd", "res://scripts/core/V2MagicRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/world/HexGrid.gd", "res://scripts/autoload/SelectionManager.gd", "res://scripts/autoload/SaveManager.gd", "res://scripts/data/V2TerrainModificationData.gd", "res://scripts/ui/HUD.gd", "res://scripts/ui/TileInspector.gd", "res://scripts/core/RivalAI.gd"]:
		var lines: Array[String] = []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			lines.append(line.split("##")[0].split("#")[0])
		var code := "\n".join(lines)
		for word in forbidden:
			assert_false(code.contains(word), "%s cita %s" % [path, word])

func test_no_parallel_druid_architecture_exists():
	for path in ["res://scripts/core/V2DruidRuntime.gd", "res://scripts/core/DruidCombatResolver.gd", "res://scripts/core/DruidPathfinder.gd", "res://scripts/core/DruidTerrainSystem.gd", "res://scripts/core/ForestSpellSystem.gd", "res://scripts/core/RaisedGroundSystem.gd", "res://scripts/data/V2DruidismContent.gd"]:
		assert_false(FileAccess.file_exists(path), path)
