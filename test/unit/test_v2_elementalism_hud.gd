extends GutTest

## Fase 22 — apresentação real do Elementalismo no painel da unidade e no
## inspetor de tile. A UI só lê os dados genéricos de magia/ambiente.

const CASTER := "v2_unit_elementalist"
const PRIMORDIAL := "v2_manifestation_elemental_primordial"
const SCHOOL := "elementalism"

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
	for q in range(-7, 8):
		for r in range(-7, 8):
			if absi(q + r) <= 7:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	player = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	player.civ.civ_name = "Elementais"
	rival.civ.civ_name = "Rival"
	GameManager.players = [player, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	player.mana = 200.0

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
		player.v2_research.complete_research("v2_magic_elementalism_%d" % i)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox/V2Actions")

func test_elementalist_panel_lists_all_four_environmental_spells_from_data():
	_learn(7)
	var caster := _unit(CASTER, player, Vector2i.ZERO)
	SelectionManager._select_unit(caster)
	assert_string_contains(hud.unit_info_label.text, "Classe: Conjurador — Escola de Elementalismo")
	assert_string_contains(hud.unit_info_label.text, "Sem ataque básico.")
	var row := _actions()
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola de Elementalismo")
	var expected := {
		"v2_spell_dense_mist": "Névoa Cerrada — 6 Mana",
		"v2_spell_gale": "Vendaval — 8 Mana",
		"v2_spell_lightning_storm": "Tempestade Elétrica — 12 Mana",
		"v2_spell_elemental_cataclysm": "Cataclismo Elemental — 20 Mana",
	}
	for id in expected:
		var button: Button = row.get_node("Spell_" + id)
		assert_eq(button.text, expected[id])
		assert_string_contains(button.tooltip_text, "rodadas globais")
	assert_string_contains(row.get_node("Spell_v2_spell_dense_mist").tooltip_text, "Visão de unidades: -2")
	assert_string_contains(row.get_node("Spell_v2_spell_gale").tooltip_text, "×0.70")
	assert_string_contains(row.get_node("Spell_v2_spell_lightning_storm").tooltip_text, "Dano mágico ambiental por rodada: 4")
	assert_string_contains(row.get_node("Spell_v2_spell_elemental_cataclysm").tooltip_text, "raio 2")

func test_primordial_panel_shows_flight_and_elemental_heart_and_uses_longer_duration():
	_learn(9)
	var primordial := _unit(PRIMORDIAL, player, Vector2i.ZERO)
	SelectionManager._select_unit(primordial)
	assert_string_contains(hud.unit_info_label.text, "Passiva da Manifestação — Coração Elemental")
	assert_string_contains(hud.unit_info_label.text, "+1 rodada(s) na duração das zonas ambientais criadas.")
	assert_string_contains(hud.unit_info_label.text, "Voo tático")
	assert_false(hud.unit_info_label.text.contains("Suprimentos:"))
	assert_true(V2MagicRuntime.cast(primordial, "v2_spell_dense_mist", Vector2i(1, 0), grid))
	assert_eq(int(V2EnvironmentalZoneSystem.zone_entry_at(Vector2i(1, 0), grid).remaining_rounds), 3)

func test_unit_panel_and_tile_inspector_show_visible_environment_but_hide_unseen_zone():
	var caster := _unit(CASTER, player, Vector2i.ZERO)
	assert_true(V2EnvironmentalZoneSystem.apply(grid, caster.coord, "v2_zone_elemental_cataclysm", 1, SCHOOL))
	SelectionManager._select_unit(caster)
	assert_string_contains(hud.unit_info_label.text, "Ambiente — Cataclismo Elemental (2 rodada(s))")
	assert_string_contains(hud.unit_info_label.text, "Visão de unidades: -1")
	grid.visibility[caster.coord] = HexGrid.Visibility.VISIBLE
	var visible := TileInspector.render(TileInspector.inspect(grid, caster.coord, player), "magic:environment")
	assert_string_contains(visible, "Cataclismo Elemental")
	assert_string_contains(visible, "Escola: Escola de Elementalismo")
	assert_string_contains(visible, "Rival")
	assert_string_contains(visible, "Duração restante: 2 rodada(s)")
	assert_string_contains(visible, "Ataques físicos à distância: ×0.80")
	grid.visibility[caster.coord] = HexGrid.Visibility.EXPLORED
	var hidden := TileInspector.render(TileInspector.inspect(grid, caster.coord, player), "magic:environment")
	assert_false(hidden.contains("Cataclismo Elemental"))
