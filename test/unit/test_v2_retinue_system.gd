extends GutTest

## Aetherlands V2, Fase 19 — V2RetinueSystem: capacidade global por civilização e Escola, uso, overload com escolha
## determinística por serial_id, estado SEM COMANDO (não move, não inicia ataque, defende e retalia), recuperação
## automática, Dissolver (sem recompensa) e re-derivação após save/load. Nada é salvo.

const SAVE_PATH := "user://test_v2_retinue_system.json"
const NECROMANCER := "v2_unit_necromancer"
const SKELETON := "v2_unit_skeleton_host"
const MACABRE := "v2_unit_macabre_host"
const LICH := "v2_manifestation_lich_sovereign"
const SCHOOL := "necromancy"

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
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 40
	human.mana = 200.0

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

## Nasce pelo pipeline normal (serial crescente na ordem das chamadas). Hostes aqui são fixtures diretas (overload só
## aparece por PERDA de capacidade — o feitiço nunca cria overload, ver test_v2_necromancy_spells).
func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _kill(unit: Unit) -> void:
	grid.remove_unit(unit)

func _commanded(units: Array) -> Array:
	return units.map(func(unit): return V2RetinueSystem.is_commanded(unit))

# --- Capacidade --------------------------------------------------------------------------------------------------

func test_capacity_sums_by_civilization_and_school():
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 0, "0 caster: 0")
	var first := _unit(NECROMANCER, human, Vector2i(0, 0))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 2)
	_unit(NECROMANCER, human, Vector2i(1, 0))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4)
	_kill(first)
	var lich := _unit(LICH, human, Vector2i(2, 0))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 6, "Necromante + Lich")
	_kill(grid.get_unit_at(Vector2i(1, 0)))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4, "só o Lich")
	_unit(NECROMANCER, rival, Vector2i(-3, 0))
	_unit(NECROMANCER, rival, Vector2i(-4, 0))
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 4, "rival não soma")
	assert_eq(V2RetinueSystem.command_capacity(rival, SCHOOL), 4)
	assert_eq(V2RetinueSystem.command_capacity(human, "sacred"), 0, "capacidade é por Escola")
	assert_true(is_instance_valid(lich))

func test_usage_counts_live_retinues_only():
	_unit(NECROMANCER, human, Vector2i(0, 0))
	_unit(NECROMANCER, human, Vector2i(1, 0))
	var skeleton := _unit(SKELETON, human, Vector2i(0, 2))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 1)
	var macabre := _unit(MACABRE, human, Vector2i(1, 2))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 3, "mix")
	var other := _unit(SKELETON, human, Vector2i(2, 2))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 4)
	assert_eq(V2RetinueSystem.command_available(human, SCHOOL), 0)
	_kill(skeleton)
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 3, "morta não conta")
	assert_true(V2RetinueSystem.dissolve(other, grid))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 2, "dissolvida não conta")
	assert_eq(V2RetinueSystem.command_available(human, SCHOOL), 2)
	assert_true(V2RetinueSystem.can_add_retinue(human, SCHOOL, 2))
	assert_false(V2RetinueSystem.can_add_retinue(human, SCHOOL, 3))
	assert_true(is_instance_valid(macabre))
	_unit(SKELETON, rival, Vector2i(-3, 3))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 2, "retinue rival não conta")

func test_fast_path_normal_units_are_always_commanded():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i(1, 0))
	var necromancer := _unit(NECROMANCER, human, Vector2i(2, 0))
	for unit in [warrior, cleric, necromancer]:
		assert_true(V2RetinueSystem.is_commanded(unit))
		assert_true(unit.can_receive_orders())
		assert_eq(unit.order_block_reason(), "")
	warrior.owner_player = null # sem dono: um scan responderia false — o caminho rápido nem olha
	assert_true(V2RetinueSystem.is_commanded(warrior))
	warrior.owner_player = human

# --- Overload determinístico (§18-19) -------------------------------------------------------------------------------

func test_overcap_greedy_by_serial_skips_what_does_not_fit_and_keeps_evaluating():
	# A custo 2, B custo 1, C custo 1; capacidade 2 -> só A.
	var n1 := _unit(NECROMANCER, human, Vector2i(0, 0))
	var n2 := _unit(NECROMANCER, human, Vector2i(1, 0))
	var a := _unit(MACABRE, human, Vector2i(0, 2))
	var b := _unit(SKELETON, human, Vector2i(1, 2))
	var c := _unit(SKELETON, human, Vector2i(2, 2))
	assert_true(a.serial_id < b.serial_id and b.serial_id < c.serial_id)
	assert_eq(_commanded([a, b, c]), [true, true, true], "4 / 4")
	_kill(n2)
	assert_eq(_commanded([a, b, c]), [true, false, false])
	var state := V2RetinueSystem.command_state(human, SCHOOL)
	assert_eq([state.capacity, state.total_cost, state.commanded_cost], [2, 4, 2])
	assert_true(is_instance_valid(n1))

func test_overcap_a_retinue_that_does_not_fit_does_not_stop_the_next_one():
	# A custo 1, B custo 2, C custo 1; capacidade 2 -> A e C.
	_unit(NECROMANCER, human, Vector2i(0, 0))
	var n2 := _unit(NECROMANCER, human, Vector2i(1, 0))
	var a := _unit(SKELETON, human, Vector2i(0, 2))
	var b := _unit(MACABRE, human, Vector2i(1, 2))
	var c := _unit(SKELETON, human, Vector2i(2, 2))
	_kill(n2)
	assert_eq(_commanded([a, b, c]), [true, false, true])
	assert_eq(V2RetinueSystem.commanded_retinues(human, SCHOOL), [a, c] as Array[Unit])
	assert_eq(V2RetinueSystem.uncommanded_retinues(human, SCHOOL), [b] as Array[Unit])
	assert_eq(V2RetinueSystem.command_state(human, SCHOOL).commanded_cost, 2, "uso ativo 2")
	assert_eq(V2RetinueSystem.summary_lines(a), ["Comando Necromântico: 4 / 2", "1 Hoste sem comando"] as Array[String])

func test_command_state_survives_save_and_load_by_serial_without_saving_it():
	var n1 := _unit(NECROMANCER, human, Vector2i(0, 0))
	var a := _unit(SKELETON, human, Vector2i(0, 2))
	var b := _unit(SKELETON, human, Vector2i(1, 2))
	var c := _unit(SKELETON, human, Vector2i(2, 2))
	assert_eq(_commanded([a, b, c]), [true, true, false], "3 Hostes / 1 Necromante: a de maior serial fica sem comando")
	var serials := [a.serial_id, b.serial_id, c.serial_id]
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	for forbidden in ["command_used", "command_capacity", "commanded", "necromancy_capacity", "summons"]:
		assert_false(text.contains(forbidden), "nada de comando salvo: %s" % forbidden)
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var by_serial := {}
	for unit in human.units:
		by_serial[unit.serial_id] = unit
	var loaded_hosts := serials.map(func(serial): return by_serial[serial])
	assert_eq(_commanded(loaded_hosts), [true, true, false], "mesma escolha pela mesma ordem")
	assert_not_null(loaded_hosts[2].get_node_or_null(Unit.COMMAND_MARKER_NAME), "o anel volta re-derivado")
	assert_null(loaded_hosts[0].get_node_or_null(Unit.COMMAND_MARKER_NAME))
	assert_true(is_instance_valid(n1))

# --- Sem comando (§16, §134) ------------------------------------------------------------------------------------------

func _uncommanded_skeleton() -> Unit:
	var skeleton := _unit(SKELETON, human, Vector2i(0, 0))
	assert_false(V2RetinueSystem.is_commanded(skeleton), "nenhum comandante: sem comando")
	return skeleton

func test_uncommanded_host_cannot_move_by_any_path_but_keeps_movement():
	var skeleton := _uncommanded_skeleton()
	assert_eq(skeleton.order_block_reason(), "Hoste sem comando necromântico.")
	assert_eq(grid.unit_reachable(skeleton), {})
	grid.move_unit(skeleton, Vector2i(1, 0), 1.0)
	assert_eq(skeleton.coord, Vector2i(0, 0), "move_unit é o gate central")
	assert_eq(skeleton.movement_left, 2.0, "movement_left não é zerado")
	skeleton.move_order_target = Vector2i(4, 0)
	grid.continue_move_order(skeleton)
	assert_eq(skeleton.coord, Vector2i(0, 0))
	assert_eq(skeleton.move_order_target, Vector2i(4, 0), "a marcha fica pendente")
	skeleton.move_order_target = Unit.NO_MOVE_ORDER
	skeleton.exploring = true
	grid.explore_step(skeleton)
	assert_eq(skeleton.coord, Vector2i(0, 0))
	SelectionManager._select_unit(skeleton)
	assert_true(SelectionManager.reachable.is_empty())
	assert_true(SelectionManager.attackable.is_empty())
	SelectionManager.wake_selected_for_move()
	assert_false(SelectionManager.move_mode, "sem ordem de mover")

func test_uncommanded_host_cannot_initiate_attack_on_unit_city_or_lair():
	var skeleton := _uncommanded_skeleton()
	var enemy := _unit("warrior", rival, Vector2i(1, 0))
	var city := grid.found_city(Vector2i(0, 1), rival, "Rival", true)
	assert_false(CombatResolver.can_attack_unit(skeleton, enemy, grid))
	assert_false(CombatResolver.can_attack_city(skeleton, city))
	var enemy_hp := enemy.hp
	CombatResolver.resolve(skeleton, enemy, grid)
	assert_eq(enemy.hp, enemy_hp, "resolve fail-closed")
	var city_hp := city.hp
	CombatResolver.resolve_city_attack(skeleton, city, grid)
	assert_eq(city.hp, city_hp, "não ataca cidade (nem captura por esse caminho)")
	assert_eq(city.owner_player, rival)
	assert_true(skeleton.unit_data.can_basic_attack, "ela TEM ataque básico; só não recebe ordem")

func test_uncommanded_host_can_be_attacked_keeps_defense_and_retaliates():
	var skeleton := _uncommanded_skeleton()
	var attacker := _unit("warrior", rival, Vector2i(1, 0))
	var commanded_twin := UnitDatabase.create_unit(SKELETON)
	assert_true(CombatResolver.can_attack_unit(attacker, skeleton, grid), "pode ser atacada")
	var prediction := CombatResolver.predict(attacker, skeleton, grid)
	assert_gt(prediction.damage_to_attacker, 0.0, "retaliação física normal")
	var attacker_hp := attacker.hp
	var skeleton_hp := skeleton.hp
	CombatResolver.resolve(attacker, skeleton, grid)
	assert_almost_eq(skeleton_hp - skeleton.hp, prediction.damage_to_defender, 0.0001)
	assert_almost_eq(attacker_hp - attacker.hp, prediction.damage_to_attacker, 0.0001, "revidou")
	assert_eq(skeleton.unit_data.defense, commanded_twin.defense, "Defesa intacta")
	assert_eq(skeleton.owner_player, human)

func test_capacity_returning_reactivates_without_rebind_or_cost():
	var skeleton := _uncommanded_skeleton()
	skeleton.movement_left = 1.0
	skeleton.hp = 11.0
	assert_not_null(skeleton.get_node_or_null(Unit.COMMAND_MARKER_NAME), "anel cinza")
	var mana := human.mana
	_unit(NECROMANCER, human, Vector2i(3, 3))
	assert_true(V2RetinueSystem.is_commanded(skeleton), "volta sozinha")
	assert_null(skeleton.get_node_or_null(Unit.COMMAND_MARKER_NAME), "anel some")
	assert_eq(skeleton.hp, 11.0, "sem perda de HP")
	assert_eq(human.mana, mana, "sem custo")
	var reach := grid.unit_reachable(skeleton)
	assert_true(reach.has(Vector2i(1, 0)), "usa o movimento restante do turno")
	grid.move_unit(skeleton, Vector2i(1, 0), 1.0)
	assert_eq(skeleton.coord, Vector2i(1, 0))

# --- Morte de comandantes (§147-148) ------------------------------------------------------------------------------------

func test_necromancer_death_leaves_both_hosts_uncommanded_and_a_new_one_restores_them():
	var necromancer := _unit(NECROMANCER, human, Vector2i(0, 0))
	var a := _unit(SKELETON, human, Vector2i(0, 2))
	var b := _unit(SKELETON, human, Vector2i(1, 2))
	assert_eq(V2RetinueSystem.summary_lines(a), ["Comando Necromântico: 2 / 2"] as Array[String])
	var attacker := _unit("v2_unit_guardian", rival, Vector2i(1, 0))
	necromancer.hp = 0.5
	CombatResolver.resolve(attacker, necromancer, grid)
	assert_false(necromancer in human.units, "morreu pela pipeline física")
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 0)
	assert_true(a in human.units and b in human.units, "as Hostes permanecem")
	assert_eq(_commanded([a, b]), [false, false])
	assert_eq(V2RetinueSystem.summary_lines(a), ["Comando Necromântico: 2 / 0", "2 Hostes sem comando"] as Array[String])
	_unit(NECROMANCER, human, Vector2i(-2, 0))
	assert_eq(_commanded([a, b]), [true, true])

func test_partial_loss_uses_the_serial_order():
	_unit(NECROMANCER, human, Vector2i(0, 0))
	var n2 := _unit(NECROMANCER, human, Vector2i(1, 0))
	var macabre := _unit(MACABRE, human, Vector2i(0, 2))
	var s1 := _unit(SKELETON, human, Vector2i(1, 2))
	var s2 := _unit(SKELETON, human, Vector2i(2, 2))
	assert_eq(V2RetinueSystem.command_state(human, SCHOOL).total_cost, 4)
	_kill(n2)
	assert_eq(_commanded([macabre, s1, s2]), [true, false, false], "a Macabra (menor serial) fica com os 2")
	for host in [macabre, s1, s2]:
		assert_eq(host.hp, host.unit_data.max_hp, "ninguém perde HP")

# --- Dissolver (§27-28, §107) --------------------------------------------------------------------------------------------

func test_dissolve_removes_frees_command_and_grants_nothing():
	var necromancer := _unit(NECROMANCER, human, Vector2i(0, 0))
	var host := _unit(SKELETON, human, Vector2i(0, 2))
	var enemy := _unit("warrior", rival, Vector2i(-3, 0))
	var gold := [human.gold, rival.gold]
	var kills := [necromancer.kills, enemy.kills]
	var mana := human.mana
	watch_signals(EventBus)
	assert_true(V2RetinueSystem.dissolve(host, grid))
	assert_false(host in human.units)
	assert_null(grid.get_unit_at(Vector2i(0, 2)), "tile liberado")
	assert_eq(V2RetinueSystem.command_available(human, SCHOOL), 2, "comando liberado na hora")
	assert_eq([human.gold, rival.gold], gold, "sem saque")
	assert_eq([necromancer.kills, enemy.kills], kills, "sem abate/XP")
	assert_eq(human.mana, mana, "sem Mana")
	if EventBus.has_signal("unit_died"):
		assert_signal_not_emitted(EventBus, "unit_died")

func test_dissolve_only_accepts_retinues():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	var necromancer := _unit(NECROMANCER, human, Vector2i(1, 0))
	assert_false(V2RetinueSystem.dissolve(warrior, grid))
	assert_false(V2RetinueSystem.dissolve(necromancer, grid))
	assert_true(warrior in human.units and necromancer in human.units)

func test_selection_dissolve_works_even_uncommanded_and_only_for_the_human():
	var skeleton := _uncommanded_skeleton()
	SelectionManager._select_unit(skeleton)
	SelectionManager.dissolve_selected_retinue()
	assert_false(skeleton in human.units, "dissolver vale sem comando (libera overload)")
	assert_null(SelectionManager.selected_unit)
	var rival_host := _unit(SKELETON, rival, Vector2i(-4, 4))
	SelectionManager.selected_unit = rival_host
	SelectionManager.dissolve_selected_retinue()
	assert_true(rival_host in rival.units, "nunca dissolve a Hoste de outro dono")

# --- IA/turno com retinues (§171) -------------------------------------------------------------------------------------------

func test_rival_uncommanded_host_survives_real_turns_without_invalid_orders():
	var host := _unit(SKELETON, rival, Vector2i(-2, 0))
	var commanded := _unit(SKELETON, rival, Vector2i(-4, 2))
	var necromancer := _unit(NECROMANCER, rival, Vector2i(-5, 2))
	_unit(SKELETON, rival, Vector2i(-6, 2))
	# capacidade 2, três Hostes: a de maior serial fica sem comando; a primeira (host) é comandada.
	necromancer.hp = necromancer.unit_data.max_hp
	grid.found_city(Vector2i(6, -3), human, "Capital", true)
	var uncommanded := V2RetinueSystem.uncommanded_retinues(rival, SCHOOL)
	assert_eq(uncommanded.size(), 1)
	var frozen_coord := uncommanded[0].coord
	for i in 3:
		TurnManager.end_turn()
		assert_false(GameManager.is_turn_processing)
	assert_true(uncommanded[0] in rival.units, "continua existindo")
	assert_eq(uncommanded[0].coord, frozen_coord, "nenhuma rotina genérica moveu a Hoste sem comando")
	assert_false(V2RetinueSystem.is_commanded(uncommanded[0]))
	assert_true(host in rival.units and commanded in rival.units, "as comandadas seguem existindo")
