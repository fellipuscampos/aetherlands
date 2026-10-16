extends GutTest

## Rodada de balanceamento de 2026-10-14 — preço em VIDA dos feitiços (V2SpellData.health_cost_fraction): a Condenação e
## o Cataclismo custam mana E uma fração da Vida máxima do conjurador. Nunca mata: sem Vida bastante o feitiço fica
## indisponível; o preço é pago só num cast bem-sucedido. Ver docs/BALANCE_PASS_2026-10-14.md §6.

const WARLOCK := "v2_unit_infernal_warlock"
const ELEMENTALIST := "v2_unit_elementalist"
const DAMNATION := "v2_spell_damnation"
const FLAME := "v2_spell_infernal_flame"
const CATACLYSM := "v2_spell_elemental_cataclysm"

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
	human.mana = 200.0

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

func _learn(branch: String, tier: int = 7) -> void:
	for i in range(V2ResearchDatabase.BRANCH_FIRST_TIER, tier + 1):
		var id := "v2_magic_%s_%d" % [branch, i]
		if not human.v2_research.is_completed(id):
			assert_true(human.v2_research.complete_research(id))

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	assert_not_null(unit, "%s em %s" % [kind, str(coord)])
	unit.movement_left = unit.unit_data.movement_points
	return unit

func test_only_the_brutal_damage_spells_cost_health():
	for spell in V2SpellDatabase.all_spells():
		var expected := 0.35 if spell.id in [DAMNATION, CATACLYSM] else 0.0
		assert_almost_eq(spell.health_cost_fraction, expected, 0.0001, spell.id)

func test_damnation_pays_mana_and_a_fraction_of_max_health_and_hits_hard():
	_learn("infernal")
	var warlock := _unit(WARLOCK, human, Vector2i.ZERO)
	var target := _unit("v2_unit_sentinel", rival, Vector2i(2, 0))
	var spell := V2SpellDatabase.get_spell(DAMNATION)
	var cost := V2MagicRuntime.health_cost(warlock, spell)
	assert_almost_eq(cost, warlock.unit_data.max_hp * 0.35, 0.0001)
	var mana_before := human.mana
	var hp_before := warlock.hp
	var target_before := target.hp
	assert_true(V2MagicRuntime.cast(warlock, DAMNATION, target.coord, grid))
	assert_almost_eq(human.mana, mana_before - spell.mana_cost, 0.0001, "a mana também é paga")
	assert_almost_eq(warlock.hp, hp_before - cost, 0.0001, "o conjurador paga o preço em Vida")
	assert_almost_eq(target.hp, target_before - spell.damage_amount, 0.0001, "dano mágico fixo, sem Defesa")

func test_without_enough_health_the_spell_is_unavailable_and_nothing_is_spent():
	_learn("infernal")
	var warlock := _unit(WARLOCK, human, Vector2i.ZERO)
	var target := _unit("v2_unit_warrior", rival, Vector2i(2, 0))
	var cost := V2MagicRuntime.health_cost(warlock, V2SpellDatabase.get_spell(DAMNATION))
	warlock.set_hp_silent(cost) # Vida igual ao preço: pagar mataria
	assert_string_contains(V2MagicRuntime.unavailable_reason(warlock, DAMNATION, grid), "Vida insuficiente")
	var mana_before := human.mana
	assert_false(V2MagicRuntime.cast(warlock, DAMNATION, target.coord, grid))
	assert_almost_eq(human.mana, mana_before, 0.0001, "nada é gasto")
	assert_almost_eq(warlock.hp, cost, 0.0001, "o conjurador não perde Vida")
	assert_eq(V2MagicRuntime.unavailable_reason(warlock, FLAME, grid), "", "feitiço só de mana continua disponível")

func test_a_tile_spell_with_health_cost_pays_on_success():
	_learn("elementalism")
	var elementalist := _unit(ELEMENTALIST, human, Vector2i.ZERO)
	var hp_before := elementalist.hp
	var cost := V2MagicRuntime.health_cost(elementalist, V2SpellDatabase.get_spell(CATACLYSM))
	assert_true(V2MagicRuntime.cast(elementalist, CATACLYSM, Vector2i(3, 0), grid))
	assert_almost_eq(elementalist.hp, hp_before - cost, 0.0001)

func test_button_and_tooltip_show_the_health_price():
	_learn("infernal")
	var warlock := _unit(WARLOCK, human, Vector2i.ZERO)
	var spell := V2SpellDatabase.get_spell(DAMNATION)
	assert_string_contains(V2MagicRuntime.button_text(warlock, spell), "Vida")
	assert_string_contains(V2SpellDatabase.effect_text(spell), "35% da Vida máxima")
	assert_false(V2MagicRuntime.button_text(warlock, V2SpellDatabase.get_spell(FLAME)).contains("Vida"))

func test_miracle_fully_heals_the_target_and_adjacent_allies():
	_learn("sacred")
	var cleric := _unit("v2_unit_sacred_cleric", human, Vector2i.ZERO)
	var a := _unit("v2_unit_warrior", human, Vector2i(2, 0))
	var b := _unit("v2_unit_warrior", human, Vector2i(3, 0))
	a.set_hp_silent(3.0)
	b.set_hp_silent(4.0)
	assert_true(V2MagicRuntime.cast(cleric, "v2_spell_miracle", a.coord, grid))
	assert_almost_eq(a.hp, a.unit_data.max_hp, 0.0001)
	assert_almost_eq(b.hp, b.unit_data.max_hp, 0.0001, "o vizinho também volta ao máximo")
