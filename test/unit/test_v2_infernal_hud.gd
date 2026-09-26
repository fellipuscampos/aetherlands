extends GutTest

## Fase 18 — apresentação da Escola Infernal no HUD real.

const WARLOCK := "v2_unit_infernal_warlock"
const ARCHDEMON := "v2_manifestation_archdemon"

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
		player.v2_research.complete_research("v2_magic_infernal_%d" % i)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox").get_node_or_null("V2Actions")

func test_warlock_panel_lists_infernal_spells_in_n4_to_n7_order():
	_learn(7)
	var warlock := _unit(WARLOCK, player, Vector2i.ZERO)
	_unit("warrior", rival, Vector2i(2, 0))
	SelectionManager._select_unit(warlock)
	var row := _actions()
	assert_not_null(row)
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola Infernal")
	var texts: Array = []
	for child in row.get_children():
		if child is Button and String(child.name).begins_with("Spell_"):
			texts.append(child.text)
	assert_eq(texts, ["Chama Infernal — 5 Mana", "Fogo Voraz — 8 Mana", "Explosão Infernal — 11 Mana", "Condenação — 18 Mana"])
	assert_string_contains(hud.unit_info_label.text, "Sem ataque básico.")
	assert_string_contains(hud.unit_info_label.text, "Classe: Conjurador — Escola Infernal")
	assert_string_contains(hud.unit_info_label.text, "Suprimentos: 2")
	var blast: Button = row.get_node("Spell_v2_spell_infernal_blast")
	assert_string_contains(blast.tooltip_text, "5 de dano mágico")
	assert_string_contains(blast.tooltip_text, "até 3 tiles")
	assert_string_contains(blast.tooltip_text, "Recarga 3")

func test_infernal_spell_button_enters_hostile_targeting():
	_learn(4)
	var warlock := _unit(WARLOCK, player, Vector2i.ZERO)
	var target := _unit("warrior", rival, Vector2i(2, 0))
	SelectionManager._select_unit(warlock)
	_actions().get_node("Spell_v2_spell_infernal_flame").pressed.emit()
	assert_eq(SelectionManager.v2_spell_targeting_id, "v2_spell_infernal_flame")
	assert_eq(SelectionManager.v2_spell_target_coords, [target.coord] as Array[Vector2i])
	assert_string_contains(hud.unit_info_label.text, "Escolha o alvo de Chama Infernal")

func test_archdemon_panel_and_production_show_passive_pp_mana_and_slot_reason():
	_learn(9)
	var city := grid.found_city(Vector2i(-3, 0), player, "Capital")
	city.city_level = 3
	city.buildings["v2_building_infernal_sanctum"] = true
	city.buildings["v2_building_infernal_ritual"] = true
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = hud._production_buttons[ARCHDEMON]
	assert_eq(button.text, "Arquidemônio  —  105 PP + 70 Mana")
	assert_true(button.visible and not button.disabled)
	var archdemon := _unit(ARCHDEMON, player, Vector2i(3, 0))
	SelectionManager._select_unit(archdemon)
	assert_string_contains(hud.unit_info_label.text, "Passiva da Manifestação — Chama Primordial")
	assert_string_contains(hud.unit_info_label.text, "+25% de dano de feitiços")
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	assert_true(button.visible and button.disabled)
	assert_string_contains(button.tooltip_text, V2ManifestationSystem.SLOT_TAKEN_REASON)
