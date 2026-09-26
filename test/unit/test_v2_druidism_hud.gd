extends GutTest

## Fase 20 — apresentação do Druidismo no HUD real: painel do Druida (Escola, sem ataque, Suprimentos, os quatro botões),
## tooltips montados do dado, Domínio Natural e o alcance efetivo no Avatar, e o inspetor mostrando a modificação.

const DRUID := "v2_unit_druid"
const AVATAR := "v2_manifestation_nature_avatar"

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
		player.v2_research.complete_research("v2_magic_druidism_%d" % i)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox").get_node_or_null("V2Actions")

func test_druid_panel_lists_the_school_and_the_four_spells():
	_learn(7)
	var druid := _unit(DRUID, player, Vector2i.ZERO)
	grid.v2_terrain_modifications[Vector2i(1, 0)] = "v2_terrain_dense_grove" # habilita Restaurar
	SelectionManager._select_unit(druid)
	var info: String = hud.unit_info_label.text
	assert_string_contains(info, "Sem ataque básico.")
	assert_string_contains(info, "Classe: Conjurador — Escola Druídica")
	assert_string_contains(info, "Suprimentos: 2")
	var row := _actions()
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola Druídica")
	var texts := []
	for id in ["v2_spell_grow_grove", "v2_spell_restore_terrain", "v2_spell_raise_ground", "v2_spell_awaken_forest"]:
		var button: Button = row.get_node("Spell_" + id)
		texts.append(button.text)
		assert_false(button.disabled, id)
	assert_eq(texts, ["Brotar Bosque — 6 Mana", "Restaurar Terreno — 5 Mana", "Erguer Terreno — 9 Mana", "Despertar a Mata — 16 Mana"])
	assert_string_contains(row.get_node("Spell_v2_spell_grow_grove").tooltip_text, "Cria Bosque Denso: +1 custo de movimento e +20% Defesa física.")
	assert_false(row.get_node("Spell_v2_spell_grow_grove").tooltip_text.contains("Alcance efetivo"), "sem bônus, sem linha extra")

func test_restore_button_disabled_without_any_modification():
	_learn(5)
	var druid := _unit(DRUID, player, Vector2i.ZERO)
	SelectionManager._select_unit(druid)
	var restore: Button = _actions().get_node("Spell_v2_spell_restore_terrain")
	assert_true(restore.disabled)
	assert_string_contains(restore.tooltip_text, "Nenhum tile com modificação de terreno ao alcance.")

func test_avatar_panel_shows_natural_dominion_and_effective_range():
	_learn(9)
	var avatar := _unit(AVATAR, player, Vector2i.ZERO)
	SelectionManager._select_unit(avatar)
	var info: String = hud.unit_info_label.text
	assert_string_contains(info, "Passiva da Manifestação — Domínio Natural")
	assert_string_contains(info, "+1 alcance de feitiços.")
	assert_false(info.contains("Suprimentos:"), "Supply 0 é omitido, como nas outras Manifestações")
	var awaken: Button = _actions().get_node("Spell_v2_spell_awaken_forest")
	assert_string_contains(awaken.tooltip_text, "Alcance efetivo: 5.")
	assert_string_contains(awaken.tooltip_text, "a até 4 tiles", "o texto do dado segue o alcance base")

func test_tile_inspector_panel_shows_the_modification():
	grid.visibility[Vector2i(1, 0)] = HexGrid.Visibility.VISIBLE
	V2TerrainRuntime.apply(grid, Vector2i(1, 0), "v2_terrain_raised_ground")
	var text := TileInspector.render(TileInspector.inspect(grid, Vector2i(1, 0), player))
	assert_string_contains(text, "Modificação: Terreno Elevado")
	assert_string_contains(text, "Movimento: +2 custo")
	assert_string_contains(text, "Defesa física: +35%")
