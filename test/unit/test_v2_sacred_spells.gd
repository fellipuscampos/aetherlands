extends GutTest

## Aetherlands V2, Fase 17 — feitiços da Escola Sagrada pelo runtime genérico (V2MagicRuntime): repertório derivado,
## Mana do pool econômico, recarga, estado temporário, alvos (só unidades próprias), mira/ESC pela SelectionManager.

const CLERIC := "v2_unit_sacred_cleric"
const LIGHT := "v2_spell_restoring_light"
const AEGIS := "v2_spell_sacred_aegis"
const WAVE := "v2_spell_healing_wave"
const MIRACLE := "v2_spell_miracle"

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
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
	for q in range(-8, 9):
		for r in range(-8, 9):
			if absi(q + r) <= 8:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Reino Humano")
	rival = _player("Reino Rival")
	var majors: Array[PlayerData] = [human, rival]
	GameManager.players = majors
	GameManager.human_player = human
	var rivals: Array[PlayerData] = [rival]
	GameManager.rival_players = rivals
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 20
	human.mana = 100.0

func after_each():
	SelectionManager.reset()
	GameManager.players = _original_players
	GameManager.human_player = _original_human
	GameManager.rival_players = _original_rivals
	GameManager.hex_grid = _original_grid
	TurnManager.turn_number = _original_turn
	for player in _players:
		player.release_relations()
	_players.clear()
	grid.queue_free()

func _player(civ_name: String) -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = civ_name
	_players.append(player)
	return player

func _learn(player: PlayerData, tier: int) -> void:
	for i in range(1, tier + 1):
		if not player.v2_research.is_completed("v2_magic_sacred_%d" % i):
			assert_true(player.v2_research.complete_research("v2_magic_sacred_%d" % i))

func _unit(kind: String, owner: PlayerData, coord: Vector2i, hp: float = -1.0) -> Unit:
	var data := UnitDatabase.create_unit(kind)
	var unit := grid.spawn_unit(coord, data, owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	if hp >= 0.0:
		unit.hp = hp
	return unit

func _cleric(tier: int = 7, coord: Vector2i = Vector2i.ZERO) -> Unit:
	_learn(human, tier)
	return _unit(CLERIC, human, coord)

func _ids(spells: Array[V2SpellData]) -> Array:
	return spells.map(func(s): return s.id)

# --- Repertório derivado --------------------------------------------------------------------------------

func test_repertoire_grows_with_research_on_the_same_unit():
	_learn(human, 3)
	var cleric := _unit(CLERIC, human, Vector2i.ZERO)
	assert_eq(_ids(V2MagicRuntime.spells_for_unit(cleric)), [], "N3: nenhum feitiço")
	var expected := []
	for pair in [[4, LIGHT], [5, AEGIS], [6, WAVE], [7, MIRACLE]]:
		_learn(human, pair[0])
		expected.append(pair[1])
		assert_eq(_ids(V2MagicRuntime.spells_for_unit(cleric)), expected, "N%d, sempre na ordem N4..N7" % pair[0])
	for key in cleric.magic_status.keys() + cleric.magic_cooldowns.keys():
		assert_false(String(key).begins_with("v2_spell"), "nenhum spellbook salvo")

func test_repertoire_belongs_to_the_owner_research_only():
	_learn(human, 7)
	var foreign := _unit(CLERIC, rival, Vector2i(5, 0))
	assert_eq(V2MagicRuntime.spells_for_unit(foreign).size(), 0)

func test_non_casters_never_know_spells():
	_learn(human, 7)
	var warrior := _unit("warrior", human, Vector2i.ZERO)
	assert_eq(V2MagicRuntime.spells_for_unit(warrior).size(), 0)
	assert_ne(V2MagicRuntime.unavailable_reason(warrior, LIGHT), "")

# --- Luz Restauradora -------------------------------------------------------------------------------------

func test_restoring_light_data():
	var spell := V2SpellDatabase.get_spell(LIGHT)
	assert_eq([spell.mana_cost, spell.cast_range, spell.cooldown_turns, spell.heal_amount], [4.0, 2, 0, 8.0])

func test_restoring_light_heals_8_costs_4_and_spends_the_action():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(2, 0), 3.0)
	cleric.exploring = true
	assert_true(V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid))
	assert_eq(ally.hp, 11.0)
	assert_eq(human.mana, 96.0)
	assert_eq(cleric.movement_left, 0.0)
	assert_false(cleric.exploring, "cancela a exploração")
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, LIGHT), 0, "sem recarga")

func test_restoring_light_clamps_at_max_hp():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(1, 0))
	ally.hp = ally.unit_data.max_hp - 2.0
	V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid)
	assert_eq(ally.hp, ally.unit_data.max_hp, "sem overheal")

func test_restoring_light_can_target_self():
	var cleric := _cleric(4)
	cleric.hp = 5.0
	assert_true(V2MagicRuntime.cast(cleric, LIGHT, cleric.coord, grid))
	assert_eq(cleric.hp, 12.0, "5 + 8 limitado a 12")

func test_restoring_light_invalid_targets_spend_nothing():
	var cleric := _cleric(4)
	var enemy := _unit("warrior", rival, Vector2i(1, 0), 2.0)
	var healthy := _unit("warrior", human, Vector2i(0, 1))
	var far := _unit("warrior", human, Vector2i(3, 0), 2.0)
	for target in [enemy, healthy, far]:
		assert_false(V2MagicRuntime.cast(cleric, LIGHT, target.coord, grid))
	assert_false(V2MagicRuntime.cast(cleric, LIGHT, Vector2i(-2, 0), grid), "tile vazio")
	var city := grid.found_city(Vector2i(-2, 2), human, "Cidade", true)
	city.hp = 1.0
	assert_false(V2MagicRuntime.cast(cleric, LIGHT, city.coord, grid), "cidade não é alvo")
	assert_eq(human.mana, 100.0)
	assert_eq(cleric.movement_left, 2.0)
	assert_eq([enemy.hp, far.hp], [2.0, 2.0])

func test_restoring_light_without_injured_target_is_disabled_with_reason():
	var cleric := _cleric(4)
	_unit("warrior", human, Vector2i(1, 0))
	assert_eq(V2MagicRuntime.unavailable_reason(cleric, LIGHT, grid), "Nenhuma unidade ferida ao alcance.")

func test_moving_partially_then_casting_is_valid_but_not_with_zero_movement():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(1, 0), 3.0)
	cleric.movement_left = 1.0
	assert_true(V2MagicRuntime.can_cast(cleric, LIGHT, grid))
	cleric.movement_left = 0.0
	assert_eq(V2MagicRuntime.unavailable_reason(cleric, LIGHT, grid), "A unidade já agiu neste turno.")
	assert_false(V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid))

# --- Mana ---------------------------------------------------------------------------------------------

func test_insufficient_mana_blocks_every_spell_without_side_effects_and_exact_mana_works():
	var cleric := _cleric(7)
	_unit("warrior", human, Vector2i(1, 0), 2.0)
	for spell in V2SpellDatabase.for_school("sacred"):
		human.mana = spell.mana_cost - 1.0
		assert_eq(V2MagicRuntime.unavailable_reason(cleric, spell.id, grid), "Mana insuficiente: requer %d." % int(spell.mana_cost), spell.id)
		SelectionManager._select_unit(cleric)
		SelectionManager.use_v2_spell_selected(spell.id)
		assert_eq(SelectionManager.v2_spell_targeting_id, "", "sem mira: %s" % spell.id)
		assert_eq(V2MagicRuntime.cooldown_remaining(cleric, spell.id), 0)
		assert_eq(cleric.movement_left, 2.0)
	human.mana = 4.0
	assert_true(V2MagicRuntime.cast(cleric, LIGHT, Vector2i(1, 0), grid))
	assert_eq(human.mana, 0.0, "exatamente o custo: termina em zero")

func test_mana_is_the_economic_pool_itself():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(1, 0), 2.0)
	var before := human.mana
	V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid)
	assert_eq(human.mana, before - 4.0, "o mesmo player.mana que V2EconomyRuntime credita")

# --- Égide Sagrada ------------------------------------------------------------------------------------------

func test_aegis_data_and_defense_bonus():
	var spell := V2SpellDatabase.get_spell(AEGIS)
	assert_eq([spell.mana_cost, spell.cast_range, spell.cooldown_turns, spell.duration], [6.0, 2, 2, 1])
	var cleric := _cleric(5)
	var ally := _unit("v2_unit_guardian", human, Vector2i(1, 0))
	assert_eq(V2MagicRuntime.defense_multiplier(ally), 1.0)
	assert_true(V2MagicRuntime.cast(cleric, AEGIS, ally.coord, grid))
	assert_almost_eq(V2MagicRuntime.defense_multiplier(ally), 1.35, 0.0001)
	assert_eq(human.mana, 94.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, AEGIS), 2)

func test_aegis_can_target_a_healthy_unit_and_self():
	var cleric := _cleric(5)
	assert_true(V2MagicRuntime.cast(cleric, AEGIS, cleric.coord, grid), "Égide não exige ferimento")
	assert_true(V2MagicRuntime.is_status_active(cleric, AEGIS))

func test_aegis_never_stacks_with_itself_and_a_second_caster_refreshes():
	_learn(human, 5)
	var first := _unit(CLERIC, human, Vector2i(0, 0))
	var second := _unit(CLERIC, human, Vector2i(0, 2))
	var ally := _unit("warrior", human, Vector2i(0, 1))
	V2MagicRuntime.cast(first, AEGIS, ally.coord, grid)
	TurnManager.turn_number += 0
	V2MagicRuntime.cast(second, AEGIS, ally.coord, grid)
	assert_almost_eq(V2MagicRuntime.defense_multiplier(ally), 1.35, 0.0001, "nunca 1,35 x 1,35")

func test_aegis_is_one_factor_in_predict_and_predict_equals_resolve():
	var cleric := _cleric(5)
	var ally := _unit("v2_unit_guardian", human, Vector2i(1, 0))
	var enemy := _unit("warrior", rival, Vector2i(2, 0))
	var before: float = CombatResolver.predict(enemy, ally, grid).damage_to_defender
	V2MagicRuntime.cast(cleric, AEGIS, ally.coord, grid)
	var predicted: Dictionary = CombatResolver.predict(enemy, ally, grid)
	assert_lt(predicted.damage_to_defender, before)
	var hp := ally.hp
	CombatResolver.resolve(enemy, ally, grid)
	assert_almost_eq(hp - ally.hp, predicted.damage_to_defender, 0.0001)

func test_aegis_combines_with_other_origins():
	for i in range(1, 5):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % i)
	var cleric := _cleric(5)
	var guardian := _unit("v2_unit_guardian", human, Vector2i(1, 0))
	var champion := _unit("v2_legendary_guardian_champion", human, Vector2i(2, 0))
	assert_true(V2TechniqueRuntime.activate(guardian, "v2_technique_shield_wall"))
	V2MagicRuntime.cast(cleric, AEGIS, guardian.coord, grid)
	assert_almost_eq(V2TechniqueRuntime.defense_multiplier(guardian, grid) * V2UnitAuras.defense_multiplier(guardian) * V2MagicRuntime.defense_multiplier(guardian), 1.35 * 1.2 * 1.35, 0.0001, "origens diferentes multiplicam")
	assert_not_null(champion)

func test_aegis_under_logistic_tension_still_multiplies_normally():
	var cleric := _cleric(5)
	var guardian := _unit("v2_unit_guardian", human, Vector2i(1, 0))
	for coord in [Vector2i(-3, 0), Vector2i(-3, 1), Vector2i(-3, 2)]:
		_unit("v2_unit_sentinel", human, coord)
	assert_true(V2LogisticsRuntime.is_logistically_strained(human), "pré-condição")
	V2MagicRuntime.cast(cleric, AEGIS, guardian.coord, grid)
	assert_almost_eq(V2MagicRuntime.defense_multiplier(guardian), 1.35, 0.0001, "Tensão não reduz o feitiço")
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(guardian), 0.85, 0.0001, "e segue valendo na Defesa, como fator separado")

func test_aegis_expires_at_the_start_of_the_owner_next_turn():
	var cleric := _cleric(5)
	var ally := _unit("warrior", human, Vector2i(1, 0))
	V2MagicRuntime.cast(cleric, AEGIS, ally.coord, grid)
	TurnManager.turn_number += 1 # a fase dos rivais acontece com turn+1
	assert_true(V2MagicRuntime.is_status_active(ally, AEGIS), "protege durante a fase dos rivais")
	assert_eq(V2MagicRuntime.expire_finished(human), 1, "o dono volta a jogar: termina")
	assert_false(V2MagicRuntime.is_status_active(ally, AEGIS))
	assert_eq(V2MagicRuntime.defense_multiplier(ally), 1.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, AEGIS), 1, "a recarga segue contando")

func test_research_reset_keeps_units_and_running_effects_but_blocks_new_casts():
	var cleric := _cleric(5)
	var ally := _unit("warrior", human, Vector2i(1, 0))
	V2MagicRuntime.cast(cleric, AEGIS, ally.coord, grid)
	human.v2_research.reset()
	assert_true(is_instance_valid(cleric) and cleric.hp > 0.0, "o Clérigo existe")
	assert_true(V2MagicRuntime.is_status_active(ally, AEGIS), "o efeito lançado termina normalmente")
	assert_eq(V2MagicRuntime.spells_for_unit(cleric).size(), 0)
	assert_eq(V2MagicRuntime.unavailable_reason(cleric, LIGHT, grid), "Requer pesquisa: Luz Restauradora.")

# --- Onda de Cura -------------------------------------------------------------------------------------------

func test_healing_wave_data():
	var spell := V2SpellDatabase.get_spell(WAVE)
	assert_eq([spell.mana_cost, spell.cast_range, spell.cooldown_turns, spell.heal_amount, spell.splash_radius], [9.0, 3, 3, 6.0, 1])

func test_healing_wave_heals_primary_and_every_own_unit_in_radius_one_once():
	var cleric := _cleric(6)
	var primary := _unit("warrior", human, Vector2i(3, 0), 2.0)
	var injured := []
	for coord in grid.get_neighbors(primary.coord):
		if grid.get_unit_at(coord) == null and HexMetrics.axial_distance(coord, cleric.coord) > 0:
			injured.append(_unit("warrior", human, coord, 2.0))
	assert_eq(injured.size(), 6, "7 aliados no total, sem limite artificial")
	var enemy_far := _unit("warrior", rival, Vector2i(5, -1), 2.0)
	assert_true(V2MagicRuntime.cast(cleric, WAVE, primary.coord, grid))
	assert_eq(primary.hp, 8.0)
	for unit in injured:
		assert_eq(unit.hp, 8.0)
	assert_eq(enemy_far.hp, 2.0)
	assert_eq(human.mana, 91.0, "uma cobrança só")
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, WAVE), 3)

func test_healing_wave_ignores_enemies_and_full_hp_units_in_the_splash():
	var cleric := _cleric(6)
	var primary := _unit("warrior", human, Vector2i(2, 0), 2.0)
	var enemy := _unit("warrior", rival, Vector2i(3, 0), 2.0)
	var healthy := _unit("warrior", human, Vector2i(2, 1))
	var max_hp := healthy.hp
	V2MagicRuntime.cast(cleric, WAVE, primary.coord, grid)
	assert_eq(enemy.hp, 2.0, "inimigo nunca é curado")
	assert_eq(healthy.hp, max_hp)

func test_healing_wave_healthy_primary_is_valid_if_a_neighbor_is_injured():
	var cleric := _cleric(6)
	var primary := _unit("warrior", human, Vector2i(2, 0))
	var neighbor := _unit("warrior", human, Vector2i(3, 0), 2.0)
	assert_true(V2MagicRuntime.cast(cleric, WAVE, primary.coord, grid))
	assert_eq(neighbor.hp, 8.0)

func test_healing_wave_with_everyone_healthy_is_invalid():
	var cleric := _cleric(6)
	var primary := _unit("warrior", human, Vector2i(2, 0))
	_unit("warrior", human, Vector2i(3, 0))
	cleric.hp = cleric.unit_data.max_hp
	assert_false(V2MagicRuntime.cast(cleric, WAVE, primary.coord, grid))
	assert_eq(human.mana, 100.0)

func test_healing_wave_clamps_each_target():
	var cleric := _cleric(6)
	var primary := _unit("warrior", human, Vector2i(2, 0))
	primary.hp = primary.unit_data.max_hp - 1.0
	V2MagicRuntime.cast(cleric, WAVE, primary.coord, grid)
	assert_eq(primary.hp, primary.unit_data.max_hp)

# --- Milagre -------------------------------------------------------------------------------------------------

func test_miracle_data():
	var spell := V2SpellDatabase.get_spell(MIRACLE)
	assert_eq([spell.mana_cost, spell.cast_range, spell.cooldown_turns, spell.heal_to_full], [16.0, 3, 5, true])

func test_miracle_restores_any_own_unit_to_full():
	var cleric := _cleric(7)
	var cases := [_unit("warrior", human, Vector2i(3, 0), 0.5), _unit("v2_legendary_guardian_champion", human, Vector2i(0, 3), 1.0), _unit("v2_unit_builder", human, Vector2i(-3, 0), 1.0)]
	for i in cases.size():
		var unit: Unit = cases[i]
		cleric.movement_left = 2.0
		cleric.magic_cooldowns.erase(MIRACLE)
		assert_true(V2MagicRuntime.cast(cleric, MIRACLE, unit.coord, grid), unit.unit_data.unit_name)
		assert_eq(unit.hp, unit.unit_data.max_hp)
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, MIRACLE), 5)

func test_miracle_on_full_hp_is_invalid_with_reason():
	var cleric := _cleric(7)
	var healthy := _unit("warrior", human, Vector2i(1, 0))
	assert_eq(V2MagicRuntime.target_reason(cleric, V2SpellDatabase.get_spell(MIRACLE), healthy, grid), "O alvo já está com a Vida máxima.")
	assert_false(V2MagicRuntime.cast(cleric, MIRACLE, healthy.coord, grid))

func test_miracle_never_resurrects_nor_heals_a_city():
	var cleric := _cleric(7)
	var dead := _unit("warrior", human, Vector2i(1, 0), 1.0)
	var coord := dead.coord
	grid.remove_unit(dead)
	assert_false(V2MagicRuntime.cast(cleric, MIRACLE, coord, grid), "nada a ressuscitar")
	var city := grid.found_city(Vector2i(-2, 2), human, "Cidade", true)
	city.hp = 1.0
	assert_false(V2MagicRuntime.cast(cleric, MIRACLE, city.coord, grid))
	assert_eq(city.hp, 1.0)

# --- Sem dano, sem XP, sem Ouro, sem Suprimentos --------------------------------------------------------------

func test_spells_grant_no_xp_gold_or_supply_change():
	var cleric := _cleric(7)
	var ally := _unit("warrior", human, Vector2i(1, 0), 2.0)
	human.gold = 50.0
	var supply := V2LogisticsRuntime.player_supply_used(human)
	V2MagicRuntime.cast(cleric, MIRACLE, ally.coord, grid)
	assert_eq([cleric.kills, human.gold, V2LogisticsRuntime.player_supply_used(human)], [0, 50.0, supply])

func test_deficit_never_reduces_spell_power():
	var cleric := _cleric(4)
	var city := grid.found_city(Vector2i(-4, 0), human, "Cidade", true)
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_guardian_mastery"] = true
	human.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(human))
	var ally := _unit("warrior", human, Vector2i(1, 0), 2.0)
	V2MagicRuntime.cast(cleric, LIGHT, ally.coord, grid)
	assert_eq(ally.hp, 10.0, "cura cheia em Déficit")

# --- Mira (SelectionManager) ------------------------------------------------------------------------------

func test_targeting_highlights_only_valid_own_units_and_esc_spends_nothing():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(1, 0), 3.0)
	_unit("warrior", rival, Vector2i(0, 1), 3.0)
	SelectionManager._select_unit(cleric)
	SelectionManager.use_v2_spell_selected(LIGHT)
	assert_eq(SelectionManager.v2_spell_targeting_id, LIGHT)
	assert_eq(SelectionManager.v2_spell_target_coords, [ally.coord] as Array[Vector2i])
	assert_eq(V2MagicRuntime.targeting_hint(V2SpellDatabase.get_spell(LIGHT)), "Escolha o alvo de Luz Restauradora (ESC cancela)")
	assert_true(SelectionManager.cancel_v2_spell_targeting(), "ESC")
	assert_eq([human.mana, cleric.movement_left, ally.hp], [100.0, 2.0, 3.0])

func test_invalid_click_cancels_without_spending_and_valid_click_casts():
	var cleric := _cleric(4)
	var ally := _unit("warrior", human, Vector2i(1, 0), 3.0)
	SelectionManager._select_unit(cleric)
	SelectionManager.use_v2_spell_selected(LIGHT)
	SelectionManager._handle_v2_spell_targeting_click(Vector2i(4, 0))
	assert_eq(SelectionManager.v2_spell_targeting_id, "")
	assert_eq(human.mana, 100.0)
	SelectionManager.use_v2_spell_selected(LIGHT)
	SelectionManager._handle_v2_spell_targeting_click(ally.coord)
	assert_eq(ally.hp, 11.0)
	assert_eq(human.mana, 96.0)

func test_spell_targeting_is_exclusive_with_the_other_modes():
	for i in range(1, 5):
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % i)
	var cleric := _cleric(4)
	_unit("warrior", human, Vector2i(1, 0), 3.0)
	SelectionManager._select_unit(cleric)
	SelectionManager.use_v2_spell_selected(LIGHT)
	var fighter := _unit("v2_unit_warrior", human, Vector2i(-3, 0))
	_unit("warrior", rival, Vector2i(-4, 0))
	SelectionManager._select_unit(fighter)
	assert_eq(SelectionManager.v2_spell_targeting_id, "", "selecionar outra unidade cancela a mira do feitiço")
	SelectionManager.start_technique_targeting(fighter, "v2_technique_power_strike")
	assert_eq(SelectionManager.technique_targeting_id, "v2_technique_power_strike")
	SelectionManager.start_v2_spell_targeting(cleric, LIGHT)
	assert_eq(SelectionManager.technique_targeting_id, "", "entrar na mira do feitiço cancela a da técnica")
	assert_eq(SelectionManager.v2_spell_targeting_id, LIGHT)
	var city := grid.found_city(Vector2i(-6, 3), human, "Cidade", true)
	city.annexation_points = 1
	city.city_level = 2
	SelectionManager.start_city_annexation(city)
	assert_eq(SelectionManager.v2_spell_targeting_id, "", "anexação cancela")

func test_status_and_cooldown_lines_use_canonical_names():
	var cleric := _cleric(5)
	var ally := _unit("warrior", human, Vector2i(1, 0))
	V2MagicRuntime.cast(cleric, AEGIS, ally.coord, grid)
	assert_true("Égide Sagrada — Ativa (até o início do próximo turno do dono)" in TileInspector.status_effect_lines(ally))
	var lines := TileInspector.caster_lines(cleric)
	assert_true("Égide Sagrada — recarga: 2 turno(s)" in lines, str(lines))
	for line in lines:
		assert_false(line.contains("v2_spell"), "nunca o id cru")
