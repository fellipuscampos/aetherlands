extends GutTest

## Fase 21 — HUD real: repertório, interferência, Fluxo do Véu e ação explícita de Portal.

const ARCANIST := "v2_unit_arcanist"
const ARCHON := "v2_manifestation_veil_archon"
const SCHOOL := "arcanism"

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
	GameManager.players = [player, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	Diplomacy.declare_war(player, rival)
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
		player.v2_research.complete_research("v2_magic_arcanism_%d" % i)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _actions() -> Node:
	return hud.unit_panel.get_node("UnitBox/V2Actions")

func test_arcanist_panel_lists_four_spells_with_costs_and_targeting_hints():
	_learn(7)
	var caster := _unit(ARCANIST, player, Vector2i.ZERO)
	var enemy := _unit(ARCANIST, rival, Vector2i(2, 0))
	enemy.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	SelectionManager._select_unit(caster)
	assert_string_contains(hud.unit_info_label.text, "Classe: Conjurador — Escola do Arcanismo")
	assert_string_contains(hud.unit_info_label.text, "Sem ataque básico.")
	var row := _actions()
	assert_eq(row.get_node("MagicHeader").text, "Magia — Escola do Arcanismo")
	assert_eq(row.get_node("Spell_v2_spell_arcane_step").text, "Passo Arcano — 6 Mana")
	assert_eq(row.get_node("Spell_v2_spell_silence").text, "Silêncio — 8 Mana")
	assert_eq(row.get_node("Spell_v2_spell_dispel").text, "Dissipar — 7 Mana")
	assert_eq(row.get_node("Spell_v2_spell_veil_portal").text, "Portal do Véu — 18 Mana")
	assert_string_contains(row.get_node("Spell_v2_spell_arcane_step").tooltip_text, "Teleporta")
	assert_string_contains(row.get_node("Spell_v2_spell_silence").tooltip_text, "impedir um conjurador hostil")
	assert_string_contains(row.get_node("Spell_v2_spell_dispel").tooltip_text, "dissipar")

func test_silenced_panel_shows_public_status_and_disables_every_spell_but_portal_traversal_remains_an_action():
	_learn(7)
	var caster := _unit(ARCANIST, player, Vector2i.ZERO)
	caster.magic_status["v2_spell_silence"] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2PortalSystem.create_or_replace_pair(player, SCHOOL, caster.coord, Vector2i(4, 0), grid))
	SelectionManager._select_unit(caster)
	assert_string_contains(hud.unit_info_label.text, "Silêncio — não pode conjurar feitiços.")
	for id in ["v2_spell_arcane_step", "v2_spell_silence", "v2_spell_dispel", "v2_spell_veil_portal"]:
		var button: Button = _actions().get_node("Spell_" + id)
		assert_true(button.disabled, id)
		assert_string_contains(button.tooltip_text, "Silêncio")
	var traverse: Button = _actions().get_node("TraversePortalButton")
	assert_false(traverse.disabled)
	assert_eq(traverse.text, "Atravessar Portal")
	traverse.pressed.emit()
	assert_eq(caster.coord, Vector2i(4, 0))

func test_portal_action_only_appears_on_an_owned_endpoint_and_explains_hidden_exit():
	_learn(7)
	var caster := _unit(ARCANIST, player, Vector2i.ZERO)
	SelectionManager._select_unit(caster)
	assert_null(_actions().get_node_or_null("TraversePortalButton"))
	assert_true(V2PortalSystem.create_or_replace_pair(rival, SCHOOL, caster.coord, Vector2i(4, 0), grid))
	SelectionManager._select_unit(caster)
	assert_null(_actions().get_node_or_null("TraversePortalButton"), "Portal rival não dá ação")
	V2PortalSystem.clear_all(grid)
	assert_true(V2PortalSystem.create_or_replace_pair(player, SCHOOL, caster.coord, Vector2i(4, 0), grid))
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.UNSEEN
	grid.visibility[Vector2i(3, 0)] = HexGrid.Visibility.VISIBLE
	SelectionManager._select_unit(caster)
	var button: Button = _actions().get_node("TraversePortalButton")
	assert_true(button.disabled)
	assert_string_contains(button.tooltip_text, "fora de visão")

func test_archon_panel_shows_flight_and_flux_and_buttons_use_reduced_cooldowns():
	_learn(9)
	var archon := _unit(ARCHON, player, Vector2i.ZERO)
	archon.magic_cooldowns["v2_spell_veil_portal"] = TurnManager.turn_number + 4
	SelectionManager._select_unit(archon)
	assert_string_contains(hud.unit_info_label.text, "Fluxo do Véu")
	assert_string_contains(hud.unit_info_label.text, "-1 turno(s) na recarga aplicada por feitiços")
	assert_string_contains(hud.unit_info_label.text, "Voo tático")
	assert_string_contains(_actions().get_node("Spell_v2_spell_veil_portal").text, "recarga 4")

func test_tile_inspector_shows_visible_portal_pair_and_hides_unseen_exit():
	assert_true(V2PortalSystem.create_or_replace_pair(player, SCHOOL, Vector2i.ZERO, Vector2i(4, 0), grid))
	grid.visibility[Vector2i.ZERO] = HexGrid.Visibility.VISIBLE
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.VISIBLE
	var visible := TileInspector.render(TileInspector.inspect(grid, Vector2i.ZERO, player))
	assert_string_contains(visible, "Portal")
	assert_string_contains(visible, "(4, 0)")
	grid.visibility[Vector2i(4, 0)] = HexGrid.Visibility.UNSEEN
	var hidden := TileInspector.render(TileInspector.inspect(grid, Vector2i.ZERO, player))
	assert_string_contains(hidden, "fora de visão")
	assert_false(hidden.contains("(4, 0)"))
