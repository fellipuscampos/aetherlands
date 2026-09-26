extends GutTest

## Aetherlands V2, Fase 19 — os quatro feitiços da Necromancia pelo runtime GENÉRICO: mira EMPTY_TILE, invocação
## persistente (capacidade antes da mira e no cast), cura com required_target_trait, Comando Macabro como
## attack_multiplier (predict == resolve, revide, sem auto-empilhar), Erguer Legião, a escolha 2 Esqueléticas x 1
## Macabra, reset de pesquisa e as integrações com Sagrada, Infernal e Ladino.

const SAVE_PATH := "user://test_v2_necromancy_spells.json"
const NECROMANCER := "v2_unit_necromancer"
const SKELETON := "v2_unit_skeleton_host"
const MACABRE := "v2_unit_macabre_host"
const LICH := "v2_manifestation_lich_sovereign"
const RAISE := "v2_spell_raise_dead"
const MEND := "v2_spell_mend_undead"
const COMMAND := "v2_spell_macabre_command"
const LEGION := "v2_spell_raise_legion"
const SCHOOL := "necromancy"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var peaceful: PlayerData
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
	for q in range(-9, 10):
		for r in range(-9, 10):
			if absi(q + r) <= 9:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	peaceful = _player("Reino em Paz")
	GameManager.players = [human, rival, peaceful] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival, peaceful] as Array[PlayerData]
	GameManager.hex_grid = grid
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

func _learn(player: PlayerData, branch: String = "necromancy", tier: int = 7) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_%s_%d" % [branch, i]):
			assert_true(player.v2_research.complete_research("v2_magic_%s_%d" % [branch, i]))

func _unit(kind: String, owner: PlayerData, coord: Vector2i, hp: float = -1.0) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	if hp >= 0.0:
		unit.hp = hp
	return unit

func _necromancer(tier: int = 7, coord: Vector2i = Vector2i.ZERO) -> Unit:
	_learn(human, "necromancy", tier)
	return _unit(NECROMANCER, human, coord)

func _ready_caster(unit: Unit) -> void:
	unit.movement_left = unit.unit_data.movement_points
	unit.magic_cooldowns.clear()

func _ids(spells: Array[V2SpellData]) -> Array:
	return spells.map(func(spell): return spell.id)

# --- Repertório ---------------------------------------------------------------------------------------------------

func test_repertoire_is_derived_and_shared_by_the_lich():
	_learn(human, "necromancy", 3)
	var necromancer := _unit(NECROMANCER, human, Vector2i.ZERO)
	var lich := _unit(LICH, human, Vector2i(3, 0))
	assert_eq(_ids(V2MagicRuntime.spells_for_unit(necromancer)), [])
	var expected := []
	for pair in [[4, RAISE], [5, MEND], [6, COMMAND], [7, LEGION]]:
		_learn(human, "necromancy", pair[0])
		expected.append(pair[1])
		assert_eq(_ids(V2MagicRuntime.spells_for_unit(necromancer)), expected)
		assert_eq(_ids(V2MagicRuntime.spells_for_unit(lich)), expected, "o Lich usa o mesmo repertório")
	var host := _unit(SKELETON, human, Vector2i(0, 2))
	assert_eq(_ids(V2MagicRuntime.spells_for_unit(host)), [], "Hoste não conjura")

# --- EMPTY_TILE (§43-45, §136) --------------------------------------------------------------------------------------

func test_empty_tile_validation():
	var necromancer := _necromancer(4)
	var spell := V2SpellDatabase.get_spell(RAISE)
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(1, 0)), "", "tile livre")
	_unit("warrior", human, Vector2i(2, 0))
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(2, 0)), "O tile está ocupado.")
	grid.tiles[Vector2i(0, 2)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(0, 2)), "Terreno incompatível com a invocação.")
	grid.tiles[Vector2i(-2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(-2, 0)), "Terreno incompatível com a invocação.")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(3, 0)), "Tile fora do alcance.")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i.ZERO), "Tile fora do alcance.", "o próprio tile nunca")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(99, 0)), "Tile inválido.")
	grid.visibility[Vector2i(1, -1)] = HexGrid.Visibility.UNSEEN
	grid.visibility[Vector2i(0, -1)] = HexGrid.Visibility.VISIBLE
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(1, -1)), "Tile fora do alcance.", "oculto ao humano")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(0, -1)), "")
	var tiles := V2MagicRuntime.target_tiles(necromancer, spell)
	assert_false(Vector2i(2, 0) in tiles)
	assert_false(Vector2i(0, 2) in tiles)
	assert_false(Vector2i(1, -1) in tiles)
	assert_eq(V2MagicRuntime.target_coords(necromancer, spell), tiles)
	assert_eq(V2MagicRuntime.target_units(necromancer, spell), [] as Array[Unit], "EMPTY_TILE nunca mira unidade")

func test_empty_tile_ignores_territory_but_refuses_foreign_cities():
	var necromancer := _necromancer(4)
	var spell := V2SpellDatabase.get_spell(RAISE)
	var own := grid.found_city(Vector2i(0, -2), human, "Própria", true)
	var enemy := grid.found_city(Vector2i(2, -2), rival, "Inimiga", true)
	assert_eq(own.owner_player, human)
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(0, -2)), "", "a própria cidade vale")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(2, -2)), "Não é possível conjurar numa cidade alheia.")
	var enemy_territory := Vector2i(1, -1)
	assert_true(enemy_territory in enemy.owned_tiles)
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, enemy_territory), "", "território inimigo em guerra")
	assert_eq(V2MagicRuntime.tile_reason(necromancer, spell, Vector2i(-1, 1)), "", "neutro")

# --- Erguer Mortos (§56, §137) ---------------------------------------------------------------------------------------

func test_raise_dead_summons_a_skeleton_host_with_movement_zero_and_charges_once():
	var necromancer := _necromancer(4)
	var mana := human.mana
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, RAISE), "")
	assert_eq(V2MagicRuntime.command_tooltip_line(necromancer, V2SpellDatabase.get_spell(RAISE)), "Comando disponível: 2.")
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(1, 0)))
	var host := grid.get_unit_at(Vector2i(1, 0))
	assert_not_null(host)
	assert_eq(host.unit_data.visual_kind, SKELETON)
	assert_eq(host.owner_player, human)
	assert_true(host in human.units, "entra no grid e no roster normais")
	assert_eq(host.hp, host.unit_data.max_hp)
	assert_eq(host.movement_left, 0.0, "não age no turno em que nasce")
	assert_gt(host.serial_id, necromancer.serial_id, "serial normal")
	assert_eq(human.mana, mana - 7.0, "Mana uma vez")
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, RAISE), 2)
	assert_eq(necromancer.movement_left, 0.0, "ação gasta")
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 1)
	assert_true(V2RetinueSystem.is_commanded(host))
	assert_eq(grid.unit_reachable(host), {}, "movimento 0: nenhum destino neste turno")
	host.reset_movement()
	assert_false(grid.unit_reachable(host).is_empty(), "age a partir do próximo turno")

func test_capacity_gates_the_button_before_aiming_and_two_hosts_fill_a_necromancer():
	var necromancer := _necromancer(4)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(1, 0)))
	_ready_caster(necromancer)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(-1, 0)))
	assert_eq(V2RetinueSystem.summary_lines(necromancer), ["Comando Necromântico: 2 / 2"] as Array[String])
	_ready_caster(necromancer)
	var mana := human.mana
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, RAISE), "Comando necromântico insuficiente: requer 1, disponível 0.")
	assert_eq(V2MagicRuntime.command_tooltip_line(necromancer, V2SpellDatabase.get_spell(RAISE)), "")
	SelectionManager._select_unit(necromancer)
	SelectionManager.use_v2_spell_selected(RAISE)
	assert_eq(SelectionManager.v2_spell_targeting_id, "", "a mira nem abre")
	assert_false(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(0, 1)))
	assert_null(grid.get_unit_at(Vector2i(0, 1)))
	assert_eq(human.mana, mana)

func test_capacity_is_revalidated_on_click_without_spending_anything():
	var necromancer := _necromancer(4)
	var second := _unit(NECROMANCER, human, Vector2i(-3, 0))
	_unit(SKELETON, human, Vector2i(3, 3))
	_unit(SKELETON, human, Vector2i(4, 3))
	_unit(SKELETON, human, Vector2i(5, 3)) # 3 / 4: sobra 1
	SelectionManager._select_unit(necromancer)
	SelectionManager.use_v2_spell_selected(RAISE)
	assert_eq(SelectionManager.v2_spell_targeting_id, RAISE)
	assert_true(Vector2i(1, 0) in SelectionManager.v2_spell_target_coords)
	grid.remove_unit(second) # a capacidade cai entre a mira e o clique
	var mana := human.mana
	SelectionManager._handle_v2_spell_targeting_click(Vector2i(1, 0))
	assert_null(grid.get_unit_at(Vector2i(1, 0)), "não spawna")
	assert_eq(human.mana, mana, "não cobra")
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, RAISE), 0, "não inicia recarga")
	assert_eq(necromancer.movement_left, 2.0, "não gasta ação")

func test_aiming_uses_the_utility_channel_and_esc_spends_nothing():
	var necromancer := _necromancer(4)
	SelectionManager._select_unit(necromancer)
	SelectionManager.use_v2_spell_selected(RAISE)
	assert_eq(SelectionManager.v2_spell_targeting_id, RAISE)
	assert_eq(V2MagicRuntime.targeting_hint(V2SpellDatabase.get_spell(RAISE)), "Escolha o tile livre de Erguer Mortos (ESC cancela)")
	var mana := human.mana
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC (PauseMenu) chama este cancelamento")
	assert_eq(human.mana, mana)
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, RAISE), 0)
	assert_eq(necromancer.movement_left, 2.0)
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 0, "não ocupa comando")
	SelectionManager.use_v2_spell_selected(RAISE)
	SelectionManager._handle_v2_spell_targeting_click(Vector2i(5, 5))
	assert_eq(SelectionManager.v2_spell_targeting_id, "", "clique fora cancela")
	assert_eq(human.mana, mana)

func test_summoned_host_persists_through_save_and_load():
	var necromancer := _necromancer(4)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(1, 0)))
	var host := grid.get_unit_at(Vector2i(1, 0))
	host.hp = 13.0
	host.kills = 2
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var loaded_host := loaded.get_unit_at(Vector2i(1, 0))
	assert_not_null(loaded_host)
	assert_eq(loaded_host.unit_data.visual_kind, SKELETON)
	assert_eq([loaded_host.hp, loaded_host.kills, loaded_host.movement_left], [13.0, 2, 0.0])
	assert_true(loaded_host.unit_data.has_trait(UnitData.TRAIT_RETINUE))
	assert_true(V2RetinueSystem.is_commanded(loaded_host))
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 1)
	var loaded_necro := loaded.get_unit_at(Vector2i.ZERO)
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded_necro, RAISE), 2)

# --- Recompor Ossos (§59-62, §138) -----------------------------------------------------------------------------------

func test_mend_undead_heals_only_injured_own_undead():
	var necromancer := _necromancer(5)
	var skeleton := _unit(SKELETON, human, Vector2i(1, 0), 5.0)
	var macabre := _unit(MACABRE, human, Vector2i(2, 0), 29.0)
	var lich := _unit(LICH, human, Vector2i(3, 0), 20.0)
	var living := _unit("v2_unit_guardian", human, Vector2i(0, 1), 3.0)
	var other_necro := _unit(NECROMANCER, human, Vector2i(0, 2), 3.0)
	var full := _unit(SKELETON, human, Vector2i(-1, 0))
	var spell := V2SpellDatabase.get_spell(MEND)
	for unit in [skeleton, macabre, lich]:
		assert_eq(V2MagicRuntime.target_reason(necromancer, spell, unit), "", unit.unit_data.unit_name)
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, living), "Só unidades próprias mortas-vivas podem ser alvo deste feitiço.")
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, other_necro), "Só unidades próprias mortas-vivas podem ser alvo deste feitiço.", "Necromante é humano vivo")
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, necromancer), "Só unidades próprias mortas-vivas podem ser alvo deste feitiço.")
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, full), "O alvo já está com a Vida máxima.")
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(necromancer, MEND, skeleton.coord))
	assert_eq(skeleton.hp, 13.0, "cura 8")
	assert_eq(human.mana, mana - 6.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, MEND), 1)
	_ready_caster(necromancer)
	assert_true(V2MagicRuntime.cast(necromancer, MEND, macabre.coord))
	assert_eq(macabre.hp, 30.0, "sem overheal")
	_ready_caster(necromancer)
	assert_true(V2MagicRuntime.cast(necromancer, MEND, lich.coord))
	assert_eq(lich.hp, 28.0, "o Lich é undead")

func test_mend_without_any_injured_undead_disables_the_button():
	var necromancer := _necromancer(5)
	_unit("warrior", human, Vector2i(1, 0), 2.0)
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, MEND), "Nenhuma entre unidades próprias mortas-vivas ferida ao alcance.")

# --- Comando Macabro (§63-69, §139) ------------------------------------------------------------------------------------

func test_macabre_command_targets_only_retinues_and_adds_forty_percent_attack():
	var necromancer := _necromancer(6)
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	var lich := _unit(LICH, human, Vector2i(2, 0))
	var warrior := _unit("warrior", human, Vector2i(0, 1))
	var spell := V2SpellDatabase.get_spell(COMMAND)
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, host), "")
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, lich), "Só Hostes próprias podem ser alvo deste feitiço.", "Lich é undead, não retinue")
	assert_eq(V2MagicRuntime.target_reason(necromancer, spell, warrior), "Só Hostes próprias podem ser alvo deste feitiço.")
	assert_eq(V2MagicRuntime.attack_multiplier(host), 1.0)
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	assert_eq(human.mana, mana - 7.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, COMMAND), 2)
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001)
	assert_eq(V2MagicRuntime.defense_multiplier(host), 1.0, "buff ofensivo não mexe na Defesa")
	assert_not_null(host.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME), "estado ativo é fato público (anel)")
	assert_true("Comando Macabro — Ativa (até o início do próximo turno do dono)" in V2MagicRuntime.status_lines(host))

func test_macabre_command_enters_physical_combat_and_predict_matches_resolve():
	var necromancer := _necromancer(6)
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	var enemy := _unit("v2_unit_guardian", rival, Vector2i(2, 0))
	var base := CombatResolver.predict(host, enemy, grid)
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	var buffed := CombatResolver.predict(host, enemy, grid)
	assert_gt(buffed.damage_to_defender, base.damage_to_defender)
	var enemy_hp := enemy.hp
	CombatResolver.resolve(host, enemy, grid)
	assert_almost_eq(enemy_hp - enemy.hp, buffed.damage_to_defender, 0.0001, "predict == resolve")

func test_macabre_command_also_strengthens_retaliation():
	var necromancer := _necromancer(6)
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	var attacker := _unit("warrior", rival, Vector2i(2, 0))
	var base := CombatResolver.predict(attacker, host, grid)
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	var buffed := CombatResolver.predict(attacker, host, grid)
	assert_almost_eq(buffed.damage_to_attacker, base.damage_to_attacker * 1.4, 0.0001)
	var attacker_hp := attacker.hp
	CombatResolver.resolve(attacker, host, grid)
	assert_almost_eq(attacker_hp - attacker.hp, buffed.damage_to_attacker, 0.0001)

func test_macabre_command_refreshes_never_stacks_and_expires_on_owner_turn():
	var necromancer := _necromancer(6)
	var second := _unit(NECROMANCER, human, Vector2i(-1, 0))
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	assert_true(V2MagicRuntime.cast(second, COMMAND, host.coord), "segundo conjurador refresca")
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001, "nunca 1,4 x 1,4")
	TurnManager.turn_number += 1 # a fase dos rivais acontece com turn+1
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001, "vale durante a fase dos rivais (revide)")
	assert_eq(V2MagicRuntime.expire_finished(human), 1, "o dono volta a jogar: termina")
	assert_eq(V2MagicRuntime.attack_multiplier(host), 1.0)
	assert_null(host.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))

func test_uncommanded_host_keeps_the_buff_but_cannot_initiate_until_command_returns():
	var necromancer := _necromancer(6)
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	var enemy := _unit("warrior", rival, Vector2i(2, 0))
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	grid.remove_unit(necromancer)
	assert_false(V2RetinueSystem.is_commanded(host))
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001, "mantém o estado")
	assert_false(CombatResolver.can_attack_unit(host, enemy, grid))
	_unit(NECROMANCER, human, Vector2i(-2, 0))
	assert_true(CombatResolver.can_attack_unit(host, enemy, grid), "comando voltou antes de expirar: o buff vale")
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001)

func test_macabre_command_status_survives_save_and_load_and_still_expires():
	var necromancer := _necromancer(6)
	var host := _unit(SKELETON, human, Vector2i(1, 0))
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	human = GameManager.human_player
	var loaded_host := loaded.get_unit_at(Vector2i(1, 0))
	assert_almost_eq(V2MagicRuntime.attack_multiplier(loaded_host), 1.4, 0.0001)
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded.get_unit_at(Vector2i.ZERO), COMMAND), 2)
	TurnManager.turn_number += 2
	V2MagicRuntime.expire_finished(human)
	assert_eq(V2MagicRuntime.attack_multiplier(loaded_host), 1.0)

func test_attack_multiplier_fast_path_and_defensive_spells_never_change_it():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	assert_eq(V2MagicRuntime.attack_multiplier(warrior), 1.0, "sem estado")
	warrior.magic_status["revealed"] = TurnManager.turn_number + 2 # estado V1 qualquer
	assert_eq(V2MagicRuntime.attack_multiplier(warrior), 1.0)
	_learn(human, "sacred", 5)
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i(1, 0))
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", warrior.coord))
	assert_eq(V2MagicRuntime.attack_multiplier(warrior), 1.0, "Égide é defensiva")
	assert_gt(V2MagicRuntime.defense_multiplier(warrior), 1.0)

# --- Erguer Legião (§72-73, §140-141) -----------------------------------------------------------------------------------

func test_raise_legion_summons_a_macabre_host_that_costs_two():
	var necromancer := _necromancer(7)
	var mana := human.mana
	assert_eq(V2MagicRuntime.command_tooltip_line(necromancer, V2SpellDatabase.get_spell(LEGION)), "Comando disponível: 2.")
	assert_true(V2MagicRuntime.cast(necromancer, LEGION, Vector2i(0, 2)))
	var host := grid.get_unit_at(Vector2i(0, 2))
	assert_eq(host.unit_data.visual_kind, MACABRE)
	assert_eq([host.hp, host.movement_left], [30.0, 0.0])
	assert_eq(human.mana, mana - 15.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(necromancer, LEGION), 4)
	assert_eq(V2RetinueSystem.command_used(human, SCHOOL), 2, "capacidade 2 exatamente")
	TurnManager.turn_number += 10
	V2MagicRuntime.expire_finished(human)
	assert_true(host in human.units, "persistente: não expira")

func test_capacity_one_blocks_the_legion():
	var necromancer := _necromancer(7)
	_unit(SKELETON, human, Vector2i(3, 3))
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, LEGION), "Comando necromântico insuficiente: requer 2, disponível 1.")
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, RAISE), "", "a Esquelética ainda cabe")

func test_two_skeletons_or_one_macabre_is_the_strategic_choice():
	# Cenário A: duas Esqueléticas; depois nada cabe.
	var necromancer := _necromancer(7)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(1, 0)))
	_ready_caster(necromancer)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(-1, 0)))
	_ready_caster(necromancer)
	assert_ne(V2MagicRuntime.unavailable_reason(necromancer, RAISE), "")
	assert_ne(V2MagicRuntime.unavailable_reason(necromancer, LEGION), "")
	# Cenário B: dissolve as duas, uma Macabra; depois nem Esquelética cabe.
	for coord in [Vector2i(1, 0), Vector2i(-1, 0)]:
		assert_true(V2RetinueSystem.dissolve(grid.get_unit_at(coord), grid))
	assert_true(V2MagicRuntime.cast(necromancer, LEGION, Vector2i(0, 2)))
	_ready_caster(necromancer)
	assert_eq(V2MagicRuntime.unavailable_reason(necromancer, RAISE), "Comando necromântico insuficiente: requer 1, disponível 0.")
	assert_ne(V2MagicRuntime.unavailable_reason(necromancer, LEGION), "")

func test_a_summon_never_creates_overload():
	var necromancer := _necromancer(7)
	for coord in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_ready_caster(necromancer)
		V2MagicRuntime.cast(necromancer, RAISE, coord)
		var state := V2RetinueSystem.command_state(human, SCHOOL)
		assert_true(state.total_cost <= state.capacity, "uso %d / %d" % [state.total_cost, state.capacity])
	assert_eq(V2RetinueSystem.retinues_for(human, SCHOOL).size(), 2)

# --- Reset de pesquisa (§149) -----------------------------------------------------------------------------------------

func test_research_reset_keeps_units_and_capacity_but_removes_the_repertoire():
	var necromancer := _necromancer(7)
	assert_true(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(1, 0)))
	var host := grid.get_unit_at(Vector2i(1, 0))
	_ready_caster(necromancer)
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MAGIC_SCHOOL, "necromancy")
	var lich := _unit(LICH, human, Vector2i(3, 0))
	_ready_caster(necromancer)
	assert_true(V2MagicRuntime.cast(necromancer, COMMAND, host.coord))
	human.v2_research.reset()
	assert_true(necromancer in human.units and host in human.units and lich in human.units)
	assert_eq(V2RetinueSystem.command_capacity(human, SCHOOL), 6, "capacidade física continua")
	assert_true(V2RetinueSystem.is_commanded(host))
	assert_eq(_ids(V2MagicRuntime.spells_for_unit(necromancer)), [], "repertório some")
	_ready_caster(necromancer)
	assert_false(V2MagicRuntime.cast(necromancer, RAISE, Vector2i(-1, 0)), "não invoca de novo")
	assert_almost_eq(V2MagicRuntime.attack_multiplier(host), 1.4, 0.0001, "buff ativo segue até expirar")
	TurnManager.turn_number += 2
	V2MagicRuntime.expire_finished(human)
	assert_eq(V2MagicRuntime.attack_multiplier(host), 1.0)

# --- Integrações entre Escolas (§116-118, §151-153) ----------------------------------------------------------------------

func test_sacred_heals_protects_and_waves_over_hosts():
	_learn(human, "sacred", 7)
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i.ZERO)
	var a := _unit(SKELETON, human, Vector2i(1, 0), 5.0)
	var b := _unit(SKELETON, human, Vector2i(2, 0), 5.0)
	var c := _unit(MACABRE, human, Vector2i(2, -1), 10.0)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_restoring_light", a.coord))
	assert_eq(a.hp, 13.0, "Luz cura Hoste própria")
	_ready_caster(cleric)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", a.coord))
	assert_gt(V2MagicRuntime.defense_multiplier(a), 1.0, "Égide protege")
	_ready_caster(cleric)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_healing_wave", b.coord))
	assert_eq([b.hp, c.hp], [11.0, 16.0], "Onda cura várias Hostes")
	_ready_caster(cleric)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_miracle", c.coord))
	assert_eq(c.hp, 30.0, "Milagre")

func test_infernal_spells_hit_hosts_ignoring_their_defense():
	var rival_host := _unit(SKELETON, rival, Vector2i(2, 0))
	var second := _unit(SKELETON, rival, Vector2i(3, 0))
	_learn(human, "infernal", 6)
	var warlock := _unit("v2_unit_infernal_warlock", human, Vector2i.ZERO)
	assert_true(V2MagicRuntime.cast(warlock, "v2_spell_infernal_flame", rival_host.coord))
	assert_eq(rival_host.hp, 12.0, "Chama 6, a Defesa 3 da Hoste não reduz")
	_ready_caster(warlock)
	assert_true(V2MagicRuntime.cast(warlock, "v2_spell_infernal_blast", rival_host.coord))
	assert_eq([rival_host.hp, second.hp], [7.0, 13.0], "Explosão atinge várias Hostes, sem exceção undead")

func test_rogue_dismantle_hits_necromancer_and_lich_but_not_hosts_by_caster():
	for i in range(1, 7):
		assert_true(human.v2_research.complete_research("v2_doctrine_rogue_%d" % i)) # Desmantelar (N6)
	var saboteur := _unit("v2_unit_saboteur", human, Vector2i.ZERO)
	var necromancer := _unit(NECROMANCER, rival, Vector2i(1, 0))
	var lich := _unit(LICH, rival, Vector2i(0, 1))
	var host := _unit(SKELETON, rival, Vector2i(-1, 0))
	var host_twin := _unit("warrior", rival, Vector2i(-1, 1))
	assert_gt(UnitAbilities.attack_multiplier(saboteur, necromancer), 1.0, "Desmantelar vale contra Necromante")
	assert_gt(UnitAbilities.attack_multiplier(saboteur, lich), 1.0, "e contra o Lich")
	assert_eq(UnitAbilities.attack_multiplier(saboteur, host), UnitAbilities.attack_multiplier(saboteur, host_twin), "Hoste não é caster")
	assert_true(CombatResolver.can_attack_unit(saboteur, host, grid), "ataque físico normal continua")

func test_legend_hunt_does_not_apply_to_the_lich_or_hosts():
	var hunter := _unit("v2_legendary_legend_hunter", human, Vector2i.ZERO)
	var lich := _unit(LICH, rival, Vector2i(1, 0))
	var host := _unit(SKELETON, rival, Vector2i(0, 1))
	var plain := _unit("warrior", rival, Vector2i(-1, 0))
	assert_eq(UnitAbilities.attack_multiplier(hunter, lich), UnitAbilities.attack_multiplier(hunter, plain))
	assert_eq(UnitAbilities.attack_multiplier(hunter, host), UnitAbilities.attack_multiplier(hunter, plain))
