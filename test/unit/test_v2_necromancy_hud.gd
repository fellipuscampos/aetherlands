extends GutTest

## Fase 19 — apresentação da Necromancia no HUD real: seção de Comando Necromântico, estado SEM COMANDO, botão
## Dissolver Hoste (só em retinue), botões/tooltips de invocação e a passiva Soberania dos Mortos.

const NECROMANCER := "v2_unit_necromancer"
const SKELETON := "v2_unit_skeleton_host"
const MACABRE := "v2_unit_macabre_host"
const LICH := "v2_manifestation_lich_sovereign"

var hud: Control
var grid: HexGrid
var player: PlayerData
var rival: PlayerData
var _original_grid: HexGrid
var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]

func before_each():
	_original_grid = GameManager.hex_grid
	_original_human = GameManager.human_player
	_original_players = GameManager.players
	_original_rivals = GameManager.rival_players
	hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	grid = HexGrid.new()
	grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	player = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.players = [player, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	Diplomacy.declare_war(player, rival)
	player.mana = 200.0
	player.gold = 500.0

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_grid
	GameManager.human_player = _original_human
	GameManager.players = _original_players
	GameManager.rival_players = _original_rivals
	player.release_relations()
	rival.release_relations()
	grid.queue_free()

func _learn(tier: int) -> void:
	for i in range(1, tier + 1):
		player.v2_research.complete_research("v2_magic_necromancy_%d" % i)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox").get_node_or_null("V2Actions")

func test_necromancer_panel_shows_school_command_and_spells_in_order():
	_learn(7)
	var necromancer := _unit(NECROMANCER, player, Vector2i.ZERO)
	_unit(SKELETON, player, Vector2i(3, 0))
	SelectionManager._select_unit(necromancer)
	var info: String = hud.unit_info_label.text
	assert_string_contains(info, "Sem ataque básico.")
	assert_string_contains(info, "Comando Necromântico: 1 / 2")
	assert_string_contains(info, "Suprimentos: 2")
	assert_false(info.contains("SEM COMANDO"))
	var row := _actions()
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola de Necromancia")
	var texts := []
	for spell_id in ["v2_spell_raise_dead", "v2_spell_mend_undead", "v2_spell_macabre_command", "v2_spell_raise_legion"]:
		texts.append(row.get_node("Spell_" + spell_id).text)
	assert_eq(texts, ["Erguer Mortos — 7 Mana", "Recompor Ossos — 6 Mana", "Comando Macabro — 7 Mana", "Erguer Legião — 15 Mana"])
	assert_null(row.get_node_or_null("DissolveRetinueButton"), "Necromante não é retinue")

func test_summon_tooltips_show_available_or_insufficient_command():
	_learn(7)
	var necromancer := _unit(NECROMANCER, player, Vector2i.ZERO)
	_unit(SKELETON, player, Vector2i(3, 0))
	SelectionManager._select_unit(necromancer)
	var raise: Button = _actions().get_node("Spell_v2_spell_raise_dead")
	assert_false(raise.disabled)
	assert_string_contains(raise.tooltip_text, "Invoca uma Hoste Esquelética (Comando 1).")
	assert_string_contains(raise.tooltip_text, "Comando disponível: 1.")
	var legion: Button = _actions().get_node("Spell_v2_spell_raise_legion")
	assert_true(legion.disabled)
	assert_string_contains(legion.tooltip_text, "Invoca uma Hoste Macabra (Comando 2).")
	assert_string_contains(legion.tooltip_text, "Comando necromântico insuficiente: requer 2, disponível 1.")

func test_host_panel_has_command_section_dissolve_and_no_spells():
	_unit(NECROMANCER, player, Vector2i(3, 0))
	var host := _unit(SKELETON, player, Vector2i.ZERO)
	SelectionManager._select_unit(host)
	assert_string_contains(hud.unit_info_label.text, "Comando Necromântico: 1 / 2")
	assert_string_contains(hud.unit_info_label.text, "Classe: Hoste — Escola de Necromancia")
	var dissolve: Button = _actions().get_node("DissolveRetinueButton")
	assert_eq(dissolve.text, "Dissolver Hoste")
	assert_eq(dissolve.tooltip_text, "Remove esta Hoste e libera sua capacidade de Comando. Não concede recompensa.")
	assert_false(dissolve.disabled)
	assert_null(_actions().get_node_or_null("MagicHeader"), "Hoste não conjura")
	assert_false(hud.move_button.disabled)

func test_uncommanded_host_shows_the_state_disables_orders_but_can_dissolve():
	_unit(NECROMANCER, player, Vector2i(3, 0))
	_unit(SKELETON, player, Vector2i(3, 2))
	var host := _unit(MACABRE, player, Vector2i.ZERO) # 1 + 2 > 2: a Macabra (maior serial) fica sem comando
	SelectionManager._select_unit(host)
	var info: String = hud.unit_info_label.text
	assert_string_contains(info, "SEM COMANDO — não pode receber ordens.")
	assert_string_contains(info, "Comando Necromântico: 3 / 2")
	assert_string_contains(info, "1 Hoste sem comando")
	assert_true(hud.move_button.disabled)
	assert_eq(hud.move_button.tooltip_text, "Hoste sem comando necromântico.")
	assert_true(hud.fortify_button.disabled)
	assert_true(hud.explore_button.disabled)
	var dissolve: Button = _actions().get_node("DissolveRetinueButton")
	assert_false(dissolve.disabled, "dissolver libera o overload")
	dissolve.pressed.emit()
	assert_false(host in player.units)
	assert_false(hud.unit_panel.visible, "seleção limpa")

func test_normal_units_never_show_command_or_dissolve():
	var warrior := _unit("warrior", player, Vector2i.ZERO)
	SelectionManager._select_unit(warrior)
	assert_false(hud.unit_info_label.text.contains("Comando Necromântico"))
	assert_false(hud.unit_info_label.text.contains("SEM COMANDO"))
	var row := _actions()
	assert_true(row == null or row.get_node_or_null("DissolveRetinueButton") == null)

func test_lich_panel_shows_sovereignty_of_the_dead():
	_learn(9)
	var lich := _unit(LICH, player, Vector2i.ZERO)
	SelectionManager._select_unit(lich)
	var info: String = hud.unit_info_label.text
	assert_string_contains(info, "Passiva da Manifestação — Soberania dos Mortos")
	assert_string_contains(info, "Concede +4 de capacidade de Comando Necromântico.")
	assert_string_contains(info, "Comando Necromântico: 0 / 4")
	assert_string_contains(info, "Sem ataque básico.")
	assert_eq(_actions().get_node("MagicHeader").text, "Magia — Escola de Necromancia")
