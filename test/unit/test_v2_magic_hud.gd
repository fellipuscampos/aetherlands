extends GutTest

## Aetherlands V2, Fase 17 — UI da Magia V2: seção "Magia — Escola Sagrada" no painel do conjurador (botões na ordem
## N4..N7, "— N Mana", recarga, desabilitado com motivo), "Sem ataque básico.", dica da mira, e o botão de produção
## do Serafim ("100 PP + 60 Mana", slot/Mana com motivo, "Aguardando 60 Mana.").

const CLERIC := "v2_unit_sacred_cleric"
const SERAPH := "v2_manifestation_seraph"

var hud: Control
var grid: HexGrid
var player: PlayerData
var _original_grid: HexGrid
var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_turn: int

func before_each():
	_original_grid = GameManager.hex_grid
	_original_human = GameManager.human_player
	_original_players = GameManager.players
	_original_turn = TurnManager.turn_number
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)
	grid = HexGrid.new()
	grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	player = PlayerData.new(CivilizationData.new())
	var majors: Array[PlayerData] = [player]
	GameManager.players = majors
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.mana = 100.0
	player.gold = 500.0
	TurnManager.turn_number = 5

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_grid
	GameManager.human_player = _original_human
	GameManager.players = _original_players
	TurnManager.turn_number = _original_turn
	player.release_relations()
	grid.queue_free()

func _learn(tier: int) -> void:
	for i in range(1, tier + 1):
		player.v2_research.complete_research("v2_magic_sacred_%d" % i)

func _unit(kind: String, coord: Vector2i, hp: float = -1.0) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player)
	unit.movement_left = unit.unit_data.movement_points
	if hp >= 0.0:
		unit.hp = hp
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox").get_node_or_null("V2Actions")

func test_caster_panel_lists_the_known_spells_in_order_with_mana_costs():
	_learn(7)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	_unit("warrior", Vector2i(1, 0), 2.0)
	SelectionManager._select_unit(cleric)
	var row := _actions()
	assert_not_null(row)
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola Sagrada")
	var texts: Array = []
	for child in row.get_children():
		if child is Button and String(child.name).begins_with("Spell_"):
			texts.append(child.text)
	assert_eq(texts, ["Luz Restauradora — 4 Mana", "Égide Sagrada — 6 Mana", "Onda de Cura — 9 Mana", "Milagre — 16 Mana"])
	assert_string_contains(hud.unit_info_label.text, "Sem ataque básico.")

func test_caster_without_research_shows_no_spell_and_no_free_spell():
	_learn(3)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	SelectionManager._select_unit(cleric)
	assert_not_null(_actions().get_node_or_null("MagicEmpty"))
	assert_null(_actions().get_node_or_null("Spell_v2_spell_restoring_light"))

func test_spell_button_disabled_with_reason_and_cooldown_suffix():
	_learn(5)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	SelectionManager._select_unit(cleric)
	var light: Button = _actions().get_node("Spell_v2_spell_restoring_light")
	assert_true(light.disabled, "ninguém ferido")
	assert_string_contains(light.tooltip_text, "Nenhuma unidade ferida ao alcance.")
	cleric.magic_cooldowns["v2_spell_sacred_aegis"] = TurnManager.turn_number + 1
	SelectionManager._select_unit(cleric)
	var aegis: Button = _actions().get_node("Spell_v2_spell_sacred_aegis")
	assert_eq(aegis.text, "Égide Sagrada — 6 Mana (recarga 1)")

func test_pressing_a_spell_enters_targeting_and_shows_the_hint():
	_learn(4)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	_unit("warrior", Vector2i(1, 0), 2.0)
	SelectionManager._select_unit(cleric)
	_actions().get_node("Spell_v2_spell_restoring_light").pressed.emit()
	assert_eq(SelectionManager.v2_spell_targeting_id, "v2_spell_restoring_light")
	assert_string_contains(hud.unit_info_label.text, "Escolha o alvo de Luz Restauradora (ESC cancela)")

func test_seraph_production_button_shows_pp_and_mana_and_reasons():
	_learn(9)
	var city := grid.found_city(Vector2i(-3, 0), player, "Capital")
	city.city_level = 3
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	var button: Button = hud._production_buttons[SERAPH]
	assert_eq(button.text, "Serafim  —  100 PP + 60 Mana")
	assert_true(button.visible)
	assert_false(button.disabled)
	player.mana = 10.0
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	assert_true(button.visible and button.disabled)
	assert_string_contains(button.tooltip_text, "Requer 60 Mana.")
	player.mana = 100.0
	_unit(SERAPH, Vector2i(3, 0))
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	assert_true(button.visible and button.disabled)
	assert_string_contains(button.tooltip_text, V2ManifestationSystem.SLOT_TAKEN_REASON)

func test_production_progress_says_waiting_for_mana():
	_learn(9)
	var city := grid.found_city(Vector2i(-3, 0), player, "Capital")
	city.city_level = 3
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	city.set_production(SERAPH)
	city.stored_production = 100.0
	player.mana = 10.0
	hud._on_tile_selected(city.coord, grid.get_tile(city.coord))
	assert_string_contains(hud.production_progress_label.text, "Aguardando 60 Mana.")
