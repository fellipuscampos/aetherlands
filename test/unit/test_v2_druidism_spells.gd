extends GutTest

## Aetherlands V2, Fase 20 — os quatro feitiços Druídicos pelo runtime GENÉRICO: EMPTY_TILE com modificação, TILE (com
## unidade e o próprio tile), a área de Despertar a Mata (1..7 tiles, ocupado sim, estrutura/cidade/melhoria/modificado/
## oculto não, ordem estável, Mana uma vez, zero tiles = nada gasto), ESC, spell_range_bonus genérico e as integrações
## com Sagrada, Infernal, Necromancia, Ladino e Cavalaria.

const SAVE_PATH := "user://test_v2_druidism_spells.json"
const DRUID := "v2_unit_druid"
const AVATAR := "v2_manifestation_nature_avatar"
const GROW := "v2_spell_grow_grove"
const RESTORE := "v2_spell_restore_terrain"
const RAISE := "v2_spell_raise_ground"
const AWAKEN := "v2_spell_awaken_forest"
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
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	Diplomacy.declare_war(human, rival)
	TurnManager.turn_number = 40
	human.mana = 300.0

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

func _learn(player: PlayerData, branch: String = "druidism", tier: int = 7) -> void:
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

func _druid(tier: int = 7, coord: Vector2i = Vector2i.ZERO) -> Unit:
	_learn(human, "druidism", tier)
	return _unit(DRUID, human, coord)

func _ready_caster(unit: Unit) -> void:
	unit.movement_left = unit.unit_data.movement_points
	unit.magic_cooldowns.clear()

func _mod(coord: Vector2i) -> String:
	return V2TerrainRuntime.modification_id_at(grid, coord)

# --- Repertório ------------------------------------------------------------------------------------------------------

func test_repertoire_is_derived_and_shared_by_the_avatar():
	_learn(human, "druidism", 3)
	var druid := _unit(DRUID, human, Vector2i.ZERO)
	var avatar := _unit(AVATAR, human, Vector2i(4, 0))
	var expected := []
	for pair in [[4, GROW], [5, RESTORE], [6, RAISE], [7, AWAKEN]]:
		_learn(human, "druidism", pair[0])
		expected.append(pair[1])
		assert_eq(V2MagicRuntime.spells_for_unit(druid).map(func(s): return s.id), expected)
		assert_eq(V2MagicRuntime.spells_for_unit(avatar).map(func(s): return s.id), expected)

# --- Brotar Bosque ---------------------------------------------------------------------------------------------------

func test_grow_grove_applies_the_grove_charges_once_and_spends_the_action():
	var druid := _druid(4)
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(druid, GROW, Vector2i(2, 0)))
	assert_eq(_mod(Vector2i(2, 0)), GROVE)
	assert_eq(human.mana, mana - 6.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, GROW), 1)
	assert_eq(druid.movement_left, 0.0)
	assert_eq(grid.terrain_step_cost(Vector2i(2, 0)), 2.0, "movimento")
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, Vector2i(2, 0)), 1.2, "Defesa")
	assert_true(druid.magic_status.is_empty(), "nenhum status em unidade")

func test_grow_grove_target_validation():
	var druid := _druid(4)
	var spell := V2SpellDatabase.get_spell(GROW)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(3, 0)), "", "alcance 3")
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(4, 0)), "Tile fora do alcance.")
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i.ZERO), "Tile fora do alcance.", "EMPTY_TILE nunca o próprio tile")
	_unit("warrior", human, Vector2i(1, 0))
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(1, 0)), "O tile está ocupado.", "primário precisa estar vazio")
	grid.tiles[Vector2i(0, 1)] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	grid.tiles[Vector2i(-1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(0, 1)), V2TerrainRuntime.REASON_TERRAIN)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(-1, 0)), V2TerrainRuntime.REASON_TERRAIN)
	var city := grid.found_city(Vector2i(0, -3), human, "Capital", true)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, city.coord), V2TerrainRuntime.REASON_CITY)
	grid.place_building(Vector2i(1, -2), "v2_building_market", human)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(1, -2)), "O terreno está ocupado por uma estrutura permanente.")
	city.resource_improvements[Vector2i(-1, -2)] = "v2_improvement_gem_mine"
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(-1, -2)), "O terreno está ocupado por uma estrutura permanente.")
	grid.get_tile(Vector2i(2, -1)).resource = "silk"
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(2, -1)), "", "recurso bruto pode")
	V2TerrainRuntime.apply(grid, Vector2i(-2, 1), RAISED)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(-2, 1)), "Este tile já possui uma modificação de terreno.")
	grid.visibility[Vector2i(2, 0)] = HexGrid.Visibility.UNSEEN
	grid.visibility[Vector2i(3, 0)] = HexGrid.Visibility.VISIBLE
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(2, 0)), "Tile fora do alcance.", "oculto ao humano")
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(3, 0)), "")

func test_aiming_uses_the_utility_channel_and_esc_spends_nothing():
	var druid := _druid(4)
	SelectionManager._select_unit(druid)
	SelectionManager.use_v2_spell_selected(GROW)
	assert_eq(SelectionManager.v2_spell_targeting_id, GROW)
	assert_true(Vector2i(2, 0) in SelectionManager.v2_spell_target_coords)
	assert_eq(V2MagicRuntime.tile_target_label(V2SpellDatabase.get_spell(GROW), Vector2i(2, 0)), "Bosque Denso")
	var mana := human.mana
	assert_true(SelectionManager.cancel_v2_spell_targeting())
	assert_eq(human.mana, mana)
	assert_eq(druid.movement_left, 2.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, GROW), 0)
	assert_true(grid.v2_terrain_modifications.is_empty(), "nada aplicado")
	SelectionManager.use_v2_spell_selected(GROW)
	SelectionManager._handle_v2_spell_targeting_click(Vector2i(2, 0))
	assert_eq(_mod(Vector2i(2, 0)), GROVE, "clique aplica")

# --- Restaurar Terreno -----------------------------------------------------------------------------------------------

func test_restore_terrain_removes_any_modification_even_under_units_and_on_the_casters_tile():
	var druid := _druid(5)
	var spell := V2SpellDatabase.get_spell(RESTORE)
	assert_eq(V2MagicRuntime.unavailable_reason(druid, RESTORE), "Nenhum tile com modificação de terreno ao alcance.")
	V2TerrainRuntime.apply(grid, Vector2i.ZERO, GROVE)
	V2TerrainRuntime.apply(grid, Vector2i(2, 0), RAISED)
	var guest := _unit("warrior", human, Vector2i(2, 0))
	assert_true(Vector2i.ZERO in V2MagicRuntime.target_tiles(druid, spell), "o próprio tile do conjurador conta (alcance 0)")
	assert_true(Vector2i(2, 0) in V2MagicRuntime.target_tiles(druid, spell), "tile com unidade vale")
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(1, 0)), "Não há modificação de terreno para restaurar.")
	assert_eq(V2MagicRuntime.targeting_hint(spell), "Escolha o tile de Restaurar Terreno (ESC cancela)")
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(druid, RESTORE, Vector2i.ZERO))
	assert_eq(_mod(Vector2i.ZERO), "")
	assert_eq(human.mana, mana - 5.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, RESTORE), 1)
	_ready_caster(druid)
	var coord_before := guest.coord
	var hp_before := guest.hp
	assert_true(V2MagicRuntime.cast(druid, RESTORE, Vector2i(2, 0)))
	assert_eq(_mod(Vector2i(2, 0)), "", "Elevado removido")
	assert_eq([guest.coord, guest.hp], [coord_before, hp_before], "sem dano nem movimento")

func test_restore_never_touches_base_terrain_resource_improvement_or_magic_status():
	var druid := _druid(5)
	var coord := Vector2i(1, 0)
	var tile := grid.get_tile(coord)
	tile.resource = "iron"
	V2TerrainRuntime.apply(grid, coord, GROVE)
	var guest := _unit("warrior", human, coord)
	guest.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2MagicRuntime.cast(druid, RESTORE, coord))
	assert_eq([tile.terrain_type, tile.resource], [HexTileData.TerrainType.GRASSLAND, "iron"])
	assert_true(guest.magic_status.has("v2_spell_sacred_aegis"), "não é dissipar")

func test_any_druid_can_restore_any_modification():
	_learn(rival, "druidism", 5)
	rival.mana = 50.0
	var enemy_druid := _unit(DRUID, rival, Vector2i(3, 0))
	var druid := _druid(4)
	assert_true(V2MagicRuntime.cast(druid, GROW, Vector2i(2, 0)))
	assert_true(V2MagicRuntime.cast(enemy_druid, RESTORE, Vector2i(2, 0)), "sem dono: o rival restaura")
	assert_eq(_mod(Vector2i(2, 0)), "")

# --- Erguer Terreno --------------------------------------------------------------------------------------------------

func test_raise_ground_applies_raised():
	var druid := _druid(6)
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(druid, RAISE, Vector2i(0, 2)))
	assert_eq(_mod(Vector2i(0, 2)), RAISED)
	assert_eq(human.mana, mana - 9.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, RAISE), 3)
	assert_eq(grid.terrain_step_cost(Vector2i(0, 2)), 3.0)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, Vector2i(0, 2)), 1.35)
	_ready_caster(druid)
	assert_false(V2MagicRuntime.cast(druid, RAISE, Vector2i(0, 2)), "mesma validade: já modificado")

# --- Despertar a Mata --------------------------------------------------------------------------------------------------

func test_awaken_forest_free_area_makes_exactly_seven_groves_for_one_charge():
	var druid := _druid(7)
	var center := Vector2i(3, 0)
	var mana := human.mana
	var area := V2MagicRuntime.terrain_area_tiles(druid, V2SpellDatabase.get_spell(AWAKEN), center)
	assert_eq(area.size(), 7)
	assert_eq(area[0], center, "primário primeiro")
	var expected := [center]
	for coord in HexMetrics.coords_within(center, 1):
		if coord != center:
			expected.append(coord)
	assert_eq(area, expected as Array[Vector2i], "ordem estável da infraestrutura hexagonal")
	assert_true(V2MagicRuntime.cast(druid, AWAKEN, center))
	for coord in expected:
		assert_eq(_mod(coord), GROVE, str(coord))
	assert_eq(grid.v2_terrain_modifications.size(), 7, "nem 6 nem 8")
	assert_eq(human.mana, mana - 16.0, "Mana uma vez")
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, AWAKEN), 5)

func test_awaken_forest_skips_ineligible_secondaries_and_modifies_under_units():
	var druid := _druid(7)
	var center := Vector2i(3, 0)
	var neighbors: Array = HexMetrics.coords_within(center, 1).filter(func(c): return c != center)
	var occupied: Unit = _unit("warrior", rival, neighbors[0])
	V2TerrainRuntime.apply(grid, neighbors[1], GROVE)
	V2TerrainRuntime.apply(grid, neighbors[2], RAISED)
	grid.place_building(neighbors[3], "v2_building_market", human)
	var city := grid.found_city(neighbors[4], human, "Cidade", true)
	grid.visibility[center] = HexGrid.Visibility.VISIBLE
	for n in neighbors:
		grid.visibility[n] = HexGrid.Visibility.VISIBLE
	grid.visibility[neighbors[5]] = HexGrid.Visibility.EXPLORED
	assert_true(V2MagicRuntime.cast(druid, AWAKEN, center))
	assert_eq(_mod(center), GROVE)
	assert_eq(_mod(neighbors[0]), GROVE, "ocupado recebe")
	assert_eq(_mod(neighbors[1]), GROVE, "o Bosque existente não é reaplicado (continua)")
	assert_eq(_mod(neighbors[2]), RAISED, "nunca sobrescreve o Elevado")
	assert_eq(_mod(neighbors[3]), "", "prédio ignorado")
	assert_eq(_mod(neighbors[4]), "", "cidade ignorada")
	assert_eq(_mod(neighbors[5]), "", "oculto ao humano ignorado")
	assert_eq(occupied.coord, neighbors[0], "ninguém se move")
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, occupied.coord), 1.2, "efeito imediato sob a unidade")
	assert_true(is_instance_valid(city))

func test_awaken_under_a_unit_raises_its_next_defense_prediction_by_twenty_percent():
	var druid := _druid(7)
	var center := Vector2i(3, 0)
	var defender := _unit("warrior", rival, Vector2i(4, 0))
	var attacker := _unit("v2_unit_weapon_master", human, Vector2i(5, 0))
	var before := CombatResolver.predict(attacker, defender, grid)
	assert_true(V2MagicRuntime.cast(druid, AWAKEN, center))
	var after := CombatResolver.predict(attacker, defender, grid)
	assert_almost_eq(before.damage_to_defender - after.damage_to_defender, 0.5 * 3.0 * 0.2, 0.0001)

func test_awaken_requires_an_eligible_primary_and_spends_nothing_otherwise():
	var druid := _druid(7)
	var spell := V2SpellDatabase.get_spell(AWAKEN)
	V2TerrainRuntime.apply(grid, Vector2i(3, 0), RAISED)
	assert_eq(V2MagicRuntime.tile_reason(druid, spell, Vector2i(3, 0)), "Este tile já possui uma modificação de terreno.")
	var mana := human.mana
	assert_false(V2MagicRuntime.cast(druid, AWAKEN, Vector2i(3, 0)))
	assert_eq(human.mana, mana)
	assert_eq(druid.movement_left, 2.0)
	assert_eq(V2MagicRuntime.cooldown_remaining(druid, AWAKEN), 0)
	assert_eq(V2MagicRuntime.terrain_area_tiles(druid, spell, Vector2i(3, 0)), [] as Array[Vector2i], "zero tiles efetivos")

func test_awaken_persists_through_save_and_load():
	var druid := _druid(7)
	assert_true(V2MagicRuntime.cast(druid, AWAKEN, Vector2i(3, 0)))
	assert_true(SaveManager.save_game(grid, SAVE_PATH))
	var loaded := HexGrid.new()
	loaded._ready()
	assert_true(SaveManager.load_game(loaded, SAVE_PATH))
	grid.queue_free()
	grid = loaded
	GameManager.hex_grid = loaded
	assert_eq(loaded.v2_terrain_modifications.size(), 7)
	assert_eq(V2MagicRuntime.cooldown_remaining(loaded.get_unit_at(Vector2i.ZERO), AWAKEN), 5)

# --- spell_range_bonus (Domínio Natural) -------------------------------------------------------------------------------

func test_spell_range_bonus_is_generic_and_only_moves_the_primary_range():
	_learn(human, "druidism", 7)
	var druid := _unit(DRUID, human, Vector2i(-6, 0))
	var avatar := _unit(AVATAR, human, Vector2i.ZERO)
	var grow := V2SpellDatabase.get_spell(GROW)
	var awaken := V2SpellDatabase.get_spell(AWAKEN)
	assert_eq(V2MagicRuntime.effective_range(druid, grow), 3)
	assert_eq(V2MagicRuntime.effective_range(avatar, grow), 4)
	assert_eq(V2MagicRuntime.effective_range(avatar, awaken), 5)
	assert_eq(V2MagicRuntime.tile_reason(avatar, grow, Vector2i(4, 0)), "", "Brotar a 4")
	assert_eq(V2MagicRuntime.tile_reason(avatar, grow, Vector2i(5, 0)), "Tile fora do alcance.")
	assert_eq(V2MagicRuntime.tile_reason(avatar, V2SpellDatabase.get_spell(RESTORE), Vector2i.ZERO), "Não há modificação de terreno para restaurar.", "TILE inclui o próprio tile")
	var mana := human.mana
	assert_true(V2MagicRuntime.cast(avatar, AWAKEN, Vector2i(5, 0)), "Despertar a 5")
	assert_eq(human.mana, mana - 16.0, "mesma Mana")
	assert_eq(V2MagicRuntime.cooldown_remaining(avatar, AWAKEN), 5, "mesma recarga")
	assert_eq(grid.v2_terrain_modifications.size(), 7, "raio da área continua 1")
	var spots := {"v2_unit_sacred_cleric": Vector2i(-6, 4), "v2_unit_infernal_warlock": Vector2i(-6, 5), "v2_unit_necromancer": Vector2i(-6, 6)}
	for kind in spots:
		var caster := _unit(kind, human, spots[kind])
		for spell in V2SpellDatabase.for_school(caster.unit_data.v2_magic_school):
			assert_eq(V2MagicRuntime.effective_range(caster, spell), spell.cast_range, "%s: default 0, idêntico" % spell.id)

func test_range_bonus_never_reveals_fog():
	_learn(human, "druidism", 7)
	var avatar := _unit(AVATAR, human, Vector2i.ZERO)
	var awaken := V2SpellDatabase.get_spell(AWAKEN)
	for coord in HexMetrics.coords_within(Vector2i.ZERO, 6):
		grid.visibility[coord] = HexGrid.Visibility.VISIBLE if HexMetrics.axial_distance(Vector2i.ZERO, coord) <= 4 else HexGrid.Visibility.EXPLORED
	assert_eq(V2MagicRuntime.tile_reason(avatar, awaken, Vector2i(5, 0)), "Tile fora do alcance.", "visão 4: o tile a 5 está oculto")
	grid.visibility[Vector2i(5, 0)] = HexGrid.Visibility.VISIBLE # outra unidade enxerga
	assert_eq(V2MagicRuntime.tile_reason(avatar, awaken, Vector2i(5, 0)), "")
	assert_eq(grid.visibility[Vector2i(6, 0)], HexGrid.Visibility.EXPLORED, "nada revelado")

# --- Integrações ------------------------------------------------------------------------------------------------------

func test_sacred_heals_and_aegis_combine_with_the_grove():
	_learn(human, "sacred", 6)
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i.ZERO)
	var guardian := _unit("v2_unit_guardian", human, Vector2i(1, 0), 10.0)
	var ally := _unit("warrior", human, Vector2i(2, 0), 5.0)
	V2TerrainRuntime.apply(grid, guardian.coord, GROVE)
	var attacker := _unit("v2_unit_weapon_master", rival, Vector2i(1, 1))
	var base := CombatResolver.predict(attacker, guardian, grid)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", guardian.coord))
	var both := CombatResolver.predict(attacker, guardian, grid)
	assert_lt(both.damage_to_defender, base.damage_to_defender, "Égide combina pela cadeia física")
	_ready_caster(cleric)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_restoring_light", guardian.coord))
	_ready_caster(cleric)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_healing_wave", ally.coord))
	assert_eq(_mod(guardian.coord), GROVE, "a Sagrada não mexe no terreno")

func test_infernal_flame_ignores_raised_plus_aegis():
	_learn(rival, "sacred", 5)
	rival.mana = 50.0
	var cleric := _unit("v2_unit_sacred_cleric", rival, Vector2i(4, 1))
	var target := _unit("v2_unit_guardian", rival, Vector2i(3, 0))
	V2TerrainRuntime.apply(grid, target.coord, RAISED)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_sacred_aegis", target.coord))
	_learn(human, "infernal", 4)
	var warlock := _unit("v2_unit_infernal_warlock", human, Vector2i.ZERO)
	var hp := target.hp
	assert_true(V2MagicRuntime.cast(warlock, "v2_spell_infernal_flame", target.coord))
	assert_eq(hp - target.hp, 6.0)

func test_necromancy_hosts_pay_the_cost_get_the_defense_and_uncommanded_still_cannot_move():
	var host := _unit("v2_unit_skeleton_host", human, Vector2i.ZERO)
	var necro := _unit("v2_unit_necromancer", human, Vector2i(-3, 0))
	V2TerrainRuntime.apply(grid, Vector2i(1, 0), GROVE)
	assert_eq(grid.unit_reachable(host).get(Vector2i(1, 0)), 2.0, "Hoste comandada paga +1")
	V2TerrainRuntime.apply(grid, host.coord, RAISED)
	assert_eq(V2TerrainRuntime.defense_multiplier_at(grid, host.coord), 1.35)
	grid.remove_unit(necro)
	assert_false(V2RetinueSystem.is_commanded(host))
	assert_eq(grid.unit_reachable(host), {}, "terreno nunca libera Hoste sem comando")
	_learn(human, "druidism", 5)
	var druid := _unit(DRUID, human, Vector2i(-2, 0))
	assert_true(V2MagicRuntime.cast(druid, RESTORE, host.coord))
	assert_false(V2RetinueSystem.is_commanded(host), "restaurar não mexe no comando")
	_unit("v2_unit_necromancer", human, Vector2i(-4, 0))
	assert_eq(grid.unit_reachable(host).get(Vector2i(1, 0)), 2.0, "comando voltou: move respeitando o custo")

func test_infiltrator_is_not_blocked_by_units_and_cavalry_gets_no_special_rule():
	var shadow := _unit("v2_legendary_shadow_master", human, Vector2i.ZERO)
	_unit("warrior", rival, Vector2i(1, 0))
	V2TerrainRuntime.apply(grid, Vector2i(2, 0), GROVE)
	assert_true(grid.unit_reachable(shadow).has(Vector2i(2, 0)), "atravessa a unidade")
	var cavalier := _unit("v2_unit_cavalier", human, Vector2i(0, 3))
	V2TerrainRuntime.apply(grid, Vector2i(1, 3), GROVE)
	assert_eq(grid.unit_reachable(cavalier).get(Vector2i(1, 3)), 2.0, "Cavalaria: só o +1 genérico")
