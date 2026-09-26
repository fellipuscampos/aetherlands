extends GutTest

## Fase 19 — fluxo principal da Necromancia (§154). Partida criada pelo GameManager, cidade fundada pelo Colonizador,
## economia/turnos reais, filas de produção, mira pela SelectionManager, combate pelo CombatResolver e save/load.
## Atalhos: terreno determinístico, debug_mode para projetos de 1 turno e Mana reposta depois de provada a geração.

const SAVE_PATH := "user://test_v2_phase19_main_flow.json"
const OSSUARY := "v2_building_necromancy_ossuary"
const MAUSOLEUM := "v2_building_necromancy_ritual"
const NECROMANCER := "v2_unit_necromancer"
const SKELETON := "v2_unit_skeleton_host"
const MACABRE := "v2_unit_macabre_host"
const LICH := "v2_manifestation_lich_sovereign"
const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"
const RAISE := "v2_spell_raise_dead"
const MEND := "v2_spell_mend_undead"
const COMMAND := "v2_spell_macabre_command"
const LEGION := "v2_spell_raise_legion"
const SCHOOL := "necromancy"

var _grid: HexGrid
var _original_state
var _original_players: Array[PlayerData]
var _original_human: PlayerData
var _original_rivals: Array[PlayerData]
var _original_grid: HexGrid
var _original_rival_count: int
var _original_debug: bool
var _original_stagger: bool
var _original_turn: int
var _original_turn_player: int

func before_each():
	_original_state = GameManager.state
	_original_players = GameManager.players
	_original_human = GameManager.human_player
	_original_rivals = GameManager.rival_players
	_original_grid = GameManager.hex_grid
	_original_rival_count = GameManager.rival_count
	_original_debug = GameManager.debug_mode
	_original_stagger = GameManager.stagger_ai_turns
	_original_turn = TurnManager.turn_number
	_original_turn_player = TurnManager.current_player_index
	GameManager.rival_count = 1
	GameManager.debug_mode = true
	GameManager.stagger_ai_turns = false
	_grid = HexGrid.new()
	_grid._ready()
	for q in range(-15, 16):
		for r in range(-15, 16):
			if absi(q + r) <= 15:
				_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.start_new_game(_grid)

func after_each():
	SelectionManager.reset()
	SaveManager.delete_save(SAVE_PATH)
	for player in GameManager.players:
		player.release_relations()
	GameManager.state = _original_state
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	GameManager.rival_count = _original_rival_count
	GameManager.debug_mode = _original_debug
	GameManager.stagger_ai_turns = _original_stagger
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue = []
	TurnManager.turn_number = _original_turn
	TurnManager.current_player_index = _original_turn_player
	if is_instance_valid(_grid):
		_grid.queue_free()

func _found_city() -> City:
	for unit in GameManager.human_player.units.duplicate():
		if unit.unit_data.can_found_city:
			return WorldSetup.found_city_from_settler(_grid, unit)
	return null

func _end_turn() -> void:
	TurnManager.end_turn()
	assert_false(GameManager.is_turn_processing)

func _learn(branch: String, tier: int) -> void:
	for i in range(1, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not GameManager.human_player.v2_research.is_completed(id):
			assert_true(GameManager.human_player.v2_research.complete_research(id), id)

func _build(city: City, id: String) -> void:
	_clear_city_ring(city)
	SelectionManager.start_building_placement(city, id)
	assert_false(SelectionManager.placeable_coords.is_empty(), "tile para %s" % id)
	SelectionManager._handle_building_placement_click(SelectionManager.placeable_coords[0])
	_end_turn()
	assert_true(city.buildings.has(id), id)

func _clear_city_ring(city: City) -> void:
	for unit in GameManager.human_player.units.duplicate():
		if HexMetrics.axial_distance(unit.coord, city.coord) > 1:
			continue
		var destination := _free_coord(city.coord, 6, 4)
		if destination != Vector2i(999, 999):
			_grid.teleport_unit(unit, destination)

func _free_coord(center: Vector2i, max_distance: int, min_distance: int = 1) -> Vector2i:
	for coord in HexMetrics.coords_within(center, max_distance):
		var distance := HexMetrics.axial_distance(coord, center)
		if distance >= min_distance and _grid.tiles.has(coord) and _grid.get_unit_at(coord) == null and _grid.get_city_at(coord) == null:
			return coord
	return Vector2i(999, 999)

func _spawn(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var occupant := _grid.get_unit_at(coord)
	if occupant != null:
		_grid.remove_unit(occupant)
	var unit := _grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, kind)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _all(kind: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in GameManager.human_player.units:
		if is_instance_valid(unit) and unit.unit_data.visual_kind == kind:
			result.append(unit)
	return result

func _find(kind: String) -> Unit:
	var found := _all(kind)
	return found[0] if not found.is_empty() else null

func _train(city: City, kind: String) -> Unit:
	var before := _all(kind).size()
	_clear_city_ring(city)
	assert_true(city.can_train(kind), "%s: %s" % [kind, V2LogisticsRuntime.training_soft_reason(GameManager.human_player, city, kind)])
	city.set_production(kind)
	_end_turn()
	var after := _all(kind)
	assert_eq(after.size(), before + 1, "nasceu %s" % kind)
	return after[after.size() - 1]

## Mira pela SelectionManager e clica: prova o fluxo de UI (não o runtime direto).
func _aim_and_click(caster: Unit, spell_id: String, coord: Vector2i) -> void:
	caster.movement_left = caster.unit_data.movement_points
	caster.magic_cooldowns.erase(spell_id)
	SelectionManager._select_unit(caster)
	SelectionManager.use_v2_spell_selected(spell_id)
	assert_eq(SelectionManager.v2_spell_targeting_id, spell_id, V2MagicRuntime.unavailable_reason(caster, spell_id, _grid))
	assert_true(coord in SelectionManager.v2_spell_target_coords, "%s mira %s" % [spell_id, str(coord)])
	SelectionManager._handle_v2_spell_targeting_click(coord)

## Encerra o combate do fixture: remove as unidades rivais que o teste criou e volta à paz direto nos dicionários
## (propose_peace pode ser recusada pela IA) — senão a IA rival marcharia sobre a capital nos turnos seguintes.
func _end_skirmish(human: PlayerData, rival: PlayerData, spawned: Array) -> void:
	for unit in spawned:
		if is_instance_valid(unit) and unit in rival.units:
			_grid.remove_unit(unit)
	human.enemies.erase(rival)
	rival.enemies.erase(human)

func _command_line(unit: Unit) -> String:
	return V2RetinueSystem.summary_lines(unit)[0]

func test_154_necromancy_end_to_end_with_command_loss_three_manifestations_and_save():
	# 1–3: partida/cidade reais; Conhecimento e Mana gerados pela economia.
	var human := GameManager.human_player
	var rival := GameManager.rival_players[0]
	var city := _found_city()
	assert_not_null(city)
	city.city_level = 3 # atalho de slot; City Level tem fluxo próprio.
	var mana_before: float = human.mana
	assert_true(human.v2_research.select_research("v2_magic_necromancy_1"))
	_end_turn()
	assert_gt(human.v2_research.get_progress("v2_magic_necromancy_1"), 0.0, "Conhecimento real")
	assert_gt(human.mana, mana_before, "Mana real")

	# 4–6: Escola + Ossuário pela fila.
	_learn(SCHOOL, 2)
	_build(city, OSSUARY)

	# 7–11: Necromante pela fila; Supply 2; comando 2; sem ataque básico.
	_learn(SCHOOL, 3)
	var necromancer := _train(city, NECROMANCER)
	assert_eq(necromancer.unit_data.supply_cost, 2)
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 2)
	assert_false(necromancer.unit_data.can_basic_attack)
	assert_eq(_command_line(necromancer), "Comando Necromântico: 0 / 2")

	# 12–20: Erguer Mortos pela mira de tile; ESC; Mana intacta; cast; Hoste nasce com movimento 0; 1/2.
	_learn(SCHOOL, 4)
	human.mana = 100.0
	var free_tile := _free_coord(necromancer.coord, 2, 1)
	SelectionManager._select_unit(necromancer)
	SelectionManager.use_v2_spell_selected(RAISE)
	assert_true(free_tile in SelectionManager.v2_spell_target_coords, "tile vazio destacado")
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC")
	assert_eq(human.mana, 100.0, "Mana intacta")
	_aim_and_click(necromancer, RAISE, free_tile)
	var skeleton := _grid.get_unit_at(free_tile)
	assert_not_null(skeleton)
	assert_eq(skeleton.unit_data.visual_kind, SKELETON)
	assert_eq(skeleton.movement_left, 0.0)
	assert_eq(human.mana, 93.0)
	assert_eq(_command_line(necromancer), "Comando Necromântico: 1 / 2")

	# 21–23: próximo turno a Hoste move e combate fisicamente.
	_end_turn()
	assert_gt(skeleton.movement_left, 0.0)
	SelectionManager._select_unit(skeleton)
	var step := Vector2i(999, 999)
	for coord in SelectionManager.reachable.keys():
		if HexMetrics.axial_distance(coord, skeleton.coord) == 1:
			step = coord
			break
	assert_ne(step, Vector2i(999, 999), "tem destino")
	SelectionManager._move_selected_to(step)
	assert_eq(skeleton.coord, step, "a Hoste andou")
	Diplomacy.declare_war(human, rival)
	var enemy := _spawn("warrior", rival, _free_coord(skeleton.coord, 1, 1))
	skeleton.movement_left = skeleton.unit_data.movement_points
	SelectionManager._select_unit(skeleton)
	assert_true(enemy.coord in SelectionManager.attackable)
	var enemy_hp := enemy.hp
	var predicted := CombatResolver.predict(skeleton, enemy, _grid)
	SelectionManager._attack_from_selected(enemy.coord)
	assert_almost_eq(enemy_hp - enemy.hp, predicted.damage_to_defender, 0.0001, "combate físico normal")

	# 24–26: segunda Hoste enche o comando; a terceira é bloqueada antes da mira.
	var second_tile := _free_coord(necromancer.coord, 2, 1)
	_aim_and_click(necromancer, RAISE, second_tile)
	var skeleton_b := _grid.get_unit_at(second_tile)
	assert_eq(skeleton_b.unit_data.visual_kind, SKELETON)
	assert_eq(_command_line(necromancer), "Comando Necromântico: 2 / 2")
	necromancer.movement_left = necromancer.unit_data.movement_points
	necromancer.magic_cooldowns.clear()
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, RAISE, _grid), "Comando necromântico insuficiente: requer 1, disponível 0.")
	SelectionManager._select_unit(necromancer)
	SelectionManager.use_v2_spell_selected(RAISE)
	assert_eq(SelectionManager.v2_spell_targeting_id, "", "terceira bloqueada")

	# 27–29: Recompor Ossos cura 8.
	_learn(SCHOOL, 5)
	skeleton_b.hp = 6.0
	_aim_and_click(necromancer, MEND, skeleton_b.coord)
	assert_eq(skeleton_b.hp, 14.0)

	# 30–32: Comando Macabro: +40% no combate físico real.
	_learn(SCHOOL, 6)
	var target := _spawn("v2_unit_guardian", rival, _free_coord(skeleton_b.coord, 1, 1))
	var plain := CombatResolver.predict(skeleton_b, target, _grid)
	_aim_and_click(necromancer, COMMAND, skeleton_b.coord)
	assert_almost_eq(V2MagicRuntime.attack_multiplier(skeleton_b), 1.4, 0.0001)
	var buffed := CombatResolver.predict(skeleton_b, target, _grid)
	assert_gt(buffed.damage_to_defender, plain.damage_to_defender)
	skeleton_b.movement_left = skeleton_b.unit_data.movement_points
	var target_hp := target.hp
	CombatResolver.resolve(skeleton_b, target, _grid)
	assert_almost_eq(target_hp - target.hp, buffed.damage_to_defender, 0.0001, "predict == resolve com o buff")
	_end_skirmish(human, rival, [enemy, target])

	# 33–38: Erguer Legião bloqueada com comando cheio; dissolver as Esqueléticas libera; Macabra 2/2.
	_learn(SCHOOL, 7)
	necromancer.movement_left = necromancer.unit_data.movement_points
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, LEGION, _grid), "Comando necromântico insuficiente: requer 2, disponível 0.")
	var kills_before := necromancer.kills
	for host in [skeleton, skeleton_b]:
		SelectionManager._select_unit(host)
		SelectionManager.dissolve_selected_retinue()
		assert_false(host in human.units)
	assert_eq(necromancer.kills, kills_before, "dissolver não credita ninguém")
	assert_eq(_command_line(necromancer), "Comando Necromântico: 0 / 2")
	var legion_tile := _free_coord(necromancer.coord, 2, 1)
	_aim_and_click(necromancer, LEGION, legion_tile)
	var macabre := _grid.get_unit_at(legion_tile)
	assert_eq(macabre.unit_data.visual_kind, MACABRE)
	assert_eq(_command_line(necromancer), "Comando Necromântico: 2 / 2")

	# 39–41: segundo Necromante: capacidade 4; mais duas Hostes (o Lich/2º Necromante também conjuram).
	var necromancer_b := _train(city, NECROMANCER)
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4)
	for i in 2:
		_aim_and_click(necromancer_b, RAISE, _free_coord(necromancer_b.coord, 2, 1))
	var skeletons := _all(SKELETON)
	assert_eq(skeletons.size(), 2)
	assert_eq(_command_line(necromancer), "Comando Necromântico: 4 / 4")

	# 42–44: um Necromante morre em combate real → overload; as Esqueléticas (maior serial) ficam sem comando.
	necromancer_b.hp = 0.5
	var killer := _spawn("v2_unit_guardian", rival, _free_coord(necromancer_b.coord, 1, 1))
	CombatResolver.resolve(killer, necromancer_b, _grid)
	assert_false(necromancer_b in human.units)
	_end_skirmish(human, rival, [killer])
	assert_eq(V2RetinueSystem.summary_lines(macabre), ["Comando Necromântico: 4 / 2", "2 Hostes sem comando"] as Array[String])
	assert_true(V2RetinueSystem.is_commanded(macabre), "a Macabra (menor serial) segue comandada")
	var frozen := skeletons[0]
	assert_false(V2RetinueSystem.is_commanded(frozen))
	_end_turn()
	assert_true(frozen in human.units, "overload não mata")
	SelectionManager._select_unit(frozen)
	assert_true(SelectionManager.reachable.is_empty(), "não move")
	assert_true(SelectionManager.attackable.is_empty(), "não ataca")
	var frozen_coord := frozen.coord
	_grid.move_unit(frozen, _free_coord(frozen.coord, 1, 1), 1.0)
	assert_eq(frozen.coord, frozen_coord)

	# 45–46: novo Necromante recupera o comando; a Hoste volta a agir sem rebind.
	var necromancer_c := _train(city, NECROMANCER)
	assert_true(V2RetinueSystem.is_commanded(frozen))
	frozen.movement_left = frozen.unit_data.movement_points
	SelectionManager._select_unit(frozen)
	assert_false(SelectionManager.reachable.is_empty(), "volta a agir")

	# 47–55: Mausoléu, N9, produção do Lich esperando Mana e nascimento; +4 de comando; repertório.
	_learn(SCHOOL, 8)
	_build(city, MAUSOLEUM)
	_learn(SCHOOL, 9)
	GameManager.debug_mode = false
	human.mana = 65.0
	_clear_city_ring(city)
	assert_true(city.can_train(LICH), V2ManifestationSystem.training_soft_reason(human, city, LICH))
	city.set_production(LICH)
	human.mana = 5.0
	city.stored_production = 100.0
	_end_turn()
	assert_null(_find(LICH), "espera a Mana")
	assert_eq(city.production_item, LICH)
	human.mana = 80.0
	_end_turn()
	var lich := _find(LICH)
	assert_not_null(lich)
	for trait_id in [UnitData.TRAIT_UNDEAD, UnitData.TRAIT_CASTER, UnitData.TRAIT_GRAND_MANIFESTATION]:
		assert_true(lich.unit_data.has_trait(trait_id), trait_id)
	assert_false(lich.unit_data.has_trait(UnitData.TRAIT_LEGENDARY))
	assert_false(lich.unit_data.has_trait(UnitData.TRAIT_RETINUE))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 8, "2 Necromantes + Lich")
	GameManager.debug_mode = true
	_aim_and_click(lich, RAISE, _free_coord(lich.coord, 2, 1))
	assert_eq(_all(SKELETON).size(), 3, "o Lich usa o repertório")

	# 56: três Manifestações de Escolas diferentes ao mesmo tempo.
	_spawn(SERAPH, human, _free_coord(city.coord, 9, 7))
	_spawn(ARCHDEMON, human, _free_coord(city.coord, 9, 8))
	for school in ["sacred", "infernal", SCHOOL]:
		assert_eq(V2ManifestationSystem.active_units(human, school).size(), 1, school)

	# 57–66: save/load preserva Hostes, HP, comando re-derivado, pesquisa, Mana, recargas/estados e slots.
	_all(SKELETON)[0].hp = 9.0
	lich.magic_cooldowns[LEGION] = TurnManager.turn_number + 3
	macabre.magic_status[COMMAND] = V2OwnerTurnEffect.expiry_for_now()
	var saved_hp := _all(SKELETON).map(func(u): return u.hp)
	var saved_commanded := _all(SKELETON).map(func(u): return V2RetinueSystem.is_commanded(u))
	var saved_line := _command_line(lich)
	var mana_saved := human.mana
	assert_true(SaveManager.save_game(_grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	_grid.queue_free()
	_grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	assert_eq(_all(SKELETON).map(func(u): return u.hp), saved_hp, "HP")
	assert_eq(_all(SKELETON).map(func(u): return V2RetinueSystem.is_commanded(u)), saved_commanded, "comando re-derivado")
	assert_eq(_all(MACABRE).size(), 1)
	var loaded_lich := _find(LICH)
	assert_eq(_command_line(loaded_lich), saved_line)
	assert_true(human.v2_research.is_completed("v2_magic_necromancy_9"))
	assert_eq(human.mana, mana_saved)
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_lich, LEGION), 3)
	assert_almost_eq(V2MagicRuntime.attack_multiplier(_find(MACABRE)), 1.4, 0.0001)
	for school in ["sacred", "infernal", SCHOOL]:
		assert_false(V2ManifestationSystem.slot_available(human, school), school)
	assert_true(V2ResearchDatabase.get_node("v2_transcendence").gameplay_connected)
	GameManager.check_victories()
	assert_ne(GameManager.state, GameManager.GameState.GAME_OVER)
	assert_eq(_all(NECROMANCER).size(), 2, "os dois Necromantes vivos voltam")
	assert_not_null(necromancer_c)
