extends GutTest

## Fase 30 / UI-3 — City Context Panel: níveis I–IV sem População/Comida/Ciência,
## rendimentos iguais ao runtime, catálogo categorizado por tipo, motivos de bloqueio
## vindos do runtime, Aguardando Mana, estruturas repetíveis, território, Ataque da
## Cidade, Ritual e o caminho único de ações (CityCommands).

const SERAPH := "v2_manifestation_seraph"
const ARCHDEMON := "v2_manifestation_archdemon"
const SHIELDBEARER := "v2_unit_shieldbearer"
const CHAMPION := "v2_legendary_guardian_champion"
const HALL := "v2_building_guardian_hall"
const FORBIDDEN_V1 := ["População", "Populacao", "Comida", "Ciência", "Ciencia", "trabalhad"]

var hud: Control
var router: ContextRouter
var grid: HexGrid
var player: PlayerData
var rival: PlayerData
var city: City
var _original_grid: HexGrid
var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]
var _original_turn: int
var _original_state

func before_each():
	_original_grid = GameManager.hex_grid
	_original_human = GameManager.human_player
	_original_players = GameManager.players
	_original_rivals = GameManager.rival_players
	_original_turn = TurnManager.turn_number
	_original_state = GameManager.state
	grid = HexGrid.new()
	grid._ready()
	for q in range(-7, 8):
		for r in range(-7, 8):
			if absi(q + r) <= 7:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
				grid.visibility[Vector2i(q, r)] = HexGrid.Visibility.VISIBLE
	player = PlayerData.new(CivilizationData.new())
	player.civ.civ_name = "Reino Humano"
	rival = PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Rival"
	GameManager.players = [player, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.human_player = player
	GameManager.state = GameManager.GameState.PLAYING
	player.gold = 500.0
	player.mana = 200.0
	TurnManager.turn_number = 5
	city = grid.found_city(Vector2i.ZERO, player, "Capital", true)
	hud = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	router = hud.ui_shell.context_router

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_grid
	GameManager.human_player = _original_human
	GameManager.players = _original_players
	GameManager.rival_players = _original_rivals
	GameManager.state = _original_state
	TurnManager.turn_number = _original_turn
	player.release_relations()
	rival.release_relations()
	grid.queue_free()

func _learn(prefix: String, tier: int) -> void:
	for i in range(1, tier + 1):
		player.v2_research.complete_research("%s_%d" % [prefix, i])

func _learn_unlock(unlock_id: String) -> void:
	var node := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	for prerequisite in node.prerequisites:
		player.v2_research.complete_research(prerequisite)
	player.v2_research.complete_research(node.id)

func _open(tab: String = "") -> CityContextPanel:
	router.open_city(city, tab)
	return router.city_panel

func _item(panel: CityContextPanel, category: String, id: String) -> Dictionary:
	for item in panel.view.catalog.get(category, []):
		if item.id == id:
			return item
	return {}

func _all_label_text(node: Node) -> String:
	var text := ""
	for child in node.get_children():
		if child is Label:
			text += (child as Label).text + "\n"
		elif child is Button:
			text += (child as Button).text + "\n"
		text += _all_label_text(child)
	return text

# --- Cabeçalho e níveis ---------------------------------------------------------------

func test_city_levels_one_to_four_show_real_hp_and_no_v1_economy():
	for level in [1, 2, 3, 4]:
		city.apply_city_level(level)
		var panel := _open()
		assert_eq(panel.view.level, level)
		assert_eq(panel.view.max_hp, V2CityLevelData.max_hp(level))
		assert_eq(panel.subtitle_label.text.begins_with(V2CityLevelData.level_name(level)), true)
		for tab in ["overview", "production", "structures", "territory", "defense"]:
			panel.select_tab(tab)
			var text := _all_label_text(panel)
			for forbidden in FORBIDDEN_V1:
				assert_false(text.contains(forbidden), "Cidade %d/%s mostra '%s'" % [level, tab, forbidden])

func test_overview_outputs_are_the_runtime_values():
	var panel := _open("overview")
	var expected := {
		"production": V2EconomyRuntime.city_production_income(city),
		"gold": V2EconomyRuntime.city_gold_income(city),
		"supply": V2EconomyRuntime.city_supply_capacity(city),
		"knowledge": V2EconomyRuntime.city_knowledge_income(city),
		"mana": V2EconomyRuntime.city_mana_income(city),
	}
	for output in panel.view.overview.outputs:
		assert_eq(output.value, "+%s" % CityPresenter._number(expected[output.key]), output.key)
	assert_eq(panel.view.overview.slots_max, city.max_building_slots())
	assert_not_null(panel.body.get_node_or_null("Outputs"))

func test_city_panel_is_tabbed_not_a_monolithic_list():
	var panel := _open()
	assert_true(panel.tabs.visible)
	assert_eq(panel.tabs.keys(), ["overview", "production", "structures", "territory", "defense"])
	panel.tabs.button_for("production").pressed.emit()
	assert_eq(panel.current_tab, "production")
	assert_not_null(panel.body.get_node_or_null("CatalogTabs"))

# --- Produção ----------------------------------------------------------------------------

func test_catalog_categories_are_derived_by_type():
	_learn("v2_doctrine_guardian", 3)
	_learn_unlock("v2_building_market")
	_learn("v2_magic_sacred", 9)
	city.apply_city_level(3)
	city.buildings[HALL] = true
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	var panel := _open("production")
	var shield := _item(panel, "units", SHIELDBEARER)
	assert_eq(shield.subgroup, "Exército")
	assert_eq(_item(panel, "units", SERAPH).subgroup, "Lendárias e Manifestações")
	assert_eq(_item(panel, "buildings", "v2_building_market").subgroup, "Economia")
	assert_true(_item(panel, "buildings", HALL).is_empty(), "prédio único já construído mora em Estruturas")
	var projects: Array = panel.view.catalog.projects
	assert_true(projects.any(func(item): return item.category == "development"))
	assert_true(projects.any(func(item): return item.category == "defense"))
	assert_true(_item(panel, "units", "v2_unit_guardian").is_empty(), "forma não pesquisada continua escondida")

func test_production_press_uses_city_commands_for_units_and_placement_for_buildings():
	_learn("v2_doctrine_guardian", 3)
	city.buildings[HALL] = true
	var panel := _open("production")
	panel.catalog_category = "units"
	panel.select_tab("production")
	var button := panel.production_item_for(SHIELDBEARER)
	assert_not_null(button)
	button.pressed.emit()
	assert_eq(city.production_item, SHIELDBEARER)
	_learn_unlock("v2_building_market")
	panel.catalog_category = "buildings"
	panel.select_tab("production")
	panel.production_item_for("v2_building_market").pressed.emit()
	assert_eq(SelectionManager.placing_city, city, "prédio entra no posicionamento no mapa")
	assert_true(SelectionManager.cancel_building_placement())

func test_lock_reasons_come_from_the_runtime():
	_learn("v2_doctrine_guardian", 3)
	var panel := _open("production")
	var shield := _item(panel, "units", SHIELDBEARER)
	assert_eq(shield.state, "blocked")
	assert_eq(shield.reason, "Requer construir: %s" % RaceTheme.building_name(HALL))
	city.buildings[HALL] = true
	player.gold = 0.0
	for id in ["v2_building_warrior_hall", "v2_building_ranger_camp", "v2_building_war_stable"]:
		city.buildings[id] = true
	assert_true(V2EconomyRuntime.is_gold_deficit(player), "pré-condição: Déficit real")
	panel.refresh()
	shield = _item(panel, "units", SHIELDBEARER)
	assert_eq(shield.reason, V2LogisticsRuntime.training_soft_reason(player, city, SHIELDBEARER))
	_learn_unlock("v2_building_farm")
	var farm_building := BuildingDatabase.get_building("v2_building_farm")
	panel.refresh()
	var farm := _item(panel, "buildings", "v2_building_farm")
	assert_eq(farm.reason, CityPresenter.building_lock_reason(city, farm_building))
	assert_string_contains(farm.reason, "Sem espaço", "slots cheios aparecem antes do Déficit")

func test_manifestation_and_legendary_slot_and_mana_reasons_match_the_runtime():
	_learn("v2_magic_sacred", 9)
	_learn("v2_doctrine_guardian", 9)
	city.apply_city_level(3)
	for id in ["v2_building_sacred_temple", "v2_building_sacred_ritual", HALL, "v2_building_guardian_mastery"]:
		city.buildings[id] = true
	var other := grid.found_city(Vector2i(4, 0), player, "Outra", true)
	other.set_production(SERAPH)
	var panel := _open("production")
	var seraph := _item(panel, "units", SERAPH)
	assert_eq(seraph.reason, V2ManifestationSystem.training_soft_reason(player, city, SERAPH))
	assert_ne(seraph.reason, "")
	other.set_production("")
	player.mana = 0.0
	panel.refresh()
	seraph = _item(panel, "units", SERAPH)
	assert_eq(seraph.reason, V2ManifestationSystem.training_soft_reason(player, city, SERAPH))
	assert_string_contains(seraph.meta, "Mana")
	other.set_production(CHAMPION)
	panel.refresh()
	var champion := _item(panel, "units", CHAMPION)
	assert_eq(champion.reason, V2LegendarySystem.slot_only_reason(player, city, CHAMPION))
	assert_eq(champion.state, "blocked")

func test_waiting_mana_is_its_own_state_and_never_idle():
	_learn("v2_magic_sacred", 9)
	city.apply_city_level(3)
	city.buildings["v2_building_sacred_temple"] = true
	city.buildings["v2_building_sacred_ritual"] = true
	city.set_production(SERAPH)
	city.stored_production = city.production_cost()
	player.mana = 0.0
	var panel := _open()
	assert_eq(panel.view.production.state, "waiting_mana")
	var badges: Array = panel.view.badges.map(func(badge): return badge.text)
	assert_has(badges, "Aguardando Mana")
	assert_does_not_have(badges, "Sem produção")
	assert_eq(hud.ui_shell.city_summary.snapshot(city).state, CityProductionPresenter.State.WAITING_MANA, "resumo F29 usa a mesma fonte")

# --- Estruturas e território ----------------------------------------------------------

func test_structures_count_repeatables_and_upkeep_without_v1_buildings():
	city.apply_city_level(3)
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 3
	city.buildings[HALL] = true
	var panel := _open("structures")
	var rows: Array = []
	for group in panel.view.structures.groups:
		rows.append_array(group.rows)
	var farm: Dictionary = rows.filter(func(row): return row.id == "v2_building_farm")[0]
	assert_eq(farm.count, 3)
	assert_true(farm.repeatable)
	assert_almost_eq(float(farm.upkeep), 3.0 * BuildingDatabase.get_building("v2_building_farm").gold_upkeep, 0.001)
	for row in rows:
		assert_true(String(row.id).begins_with("v2_building_"), "sem prédio V1: %s" % row.id)
	assert_not_null(panel.body.find_child("Structure_v2_building_farm", true, false))

func test_territory_shows_radius_annex_points_and_improved_resources_without_worked_tiles():
	city.annexation_points = 2
	var owned := grid.get_neighbors(city.coord)[0]
	if not owned in city.owned_tiles:
		city.owned_tiles.append(owned)
	grid.get_tile(owned).resource = "iron"
	city.resource_improvements[owned] = V2ResourceImprovementData.improvement_id_for_resource("iron")
	var panel := _open("territory")
	assert_eq(panel.view.territory.annex_points, 2)
	assert_eq(panel.view.territory.radius, V2CityLevelData.max_territory_radius(city.city_level))
	var iron: Array = panel.view.territory.resources.filter(func(resource): return resource.coord == owned)
	assert_eq(iron.size(), 1)
	assert_true(iron[0].improved)
	var annex: AEButton = panel.action_buttons.annex
	assert_false(annex.disabled)
	annex.pressed.emit()
	assert_true(SelectionManager.annexing_city == city or SelectionManager.annexing_city == null, "entra no modo real (ou avisa sem tile elegível)")
	SelectionManager.cancel_city_annexation()

# --- Defesa ----------------------------------------------------------------------------

func test_city_attack_is_available_once_per_turn_and_uses_the_common_targeting():
	city.apply_fortification_level(1)
	Diplomacy.declare_war(player, rival, "Teste", true)
	var enemy := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("warrior"), rival)
	var panel := _open("defense")
	assert_eq(panel.view.defense.attack.reason, "")
	var fire: AEButton = panel.action_buttons.city_attack
	assert_false(fire.disabled)
	fire.pressed.emit()
	assert_eq(SelectionManager.city_attack_city, city)
	assert_eq(TargetingPresenter.current().kind, "city_attack")
	assert_true(SelectionManager.cancel_city_attack_targeting())
	city.last_city_attack_turn = TurnManager.turn_number
	panel.refresh()
	assert_true(panel.view.defense.attack.used)
	assert_eq(panel.view.defense.attack.reason, CityDefense.city_attack_unavailable_reason(city))
	assert_true(panel.action_buttons.city_attack.disabled)
	assert_true(is_instance_valid(enemy))

# --- Ritual -----------------------------------------------------------------------------

func test_ritual_card_follows_available_active_and_interruption():
	for branch in ["sacred", "infernal"]:
		_learn("v2_magic_%s" % branch, 9)
	player.v2_research.complete_research("v2_transcendence")
	city.apply_city_level(3)
	city.buildings["v2_building_sacred_ritual"] = true
	player.mana = 200.0
	var units: Array[Unit] = []
	for kind in [SERAPH, ARCHDEMON]:
		var coord := Vector2i(units.size() + 2, 1)
		units.append(grid.spawn_unit(coord, UnitDatabase.create_unit(kind), player))
	var panel := _open("overview")
	assert_true(panel.view.ritual.visible)
	assert_eq(panel.view.ritual.state, "available", str(panel.view.ritual))
	(panel.action_buttons.start_ritual as AEButton).pressed.emit()
	assert_true(V2TranscendenceSystem.has_active_ritual(player))
	assert_eq(panel.view.ritual.state, "active")
	assert_not_null(panel.action_buttons.get("cancel_ritual"))
	V2TranscendenceSystem.interrupt_ritual(player, V2TranscendenceSystem.INTERRUPT_CANCELLED)
	router.flush()
	assert_false(V2TranscendenceSystem.has_active_ritual(player))
	assert_ne(panel.view.ritual.state, "active", "interrupção atualiza o painel por sinal")

# --- Público / deep links -----------------------------------------------------------

func test_rival_city_shows_only_public_information():
	var enemy_city := grid.found_city(Vector2i(-4, 0), rival, "Umbra", true)
	enemy_city.set_production("settler")
	router.open_city(enemy_city)
	var panel := router.city_panel
	assert_false(panel.view.own)
	assert_false(panel.view.has("production"))
	assert_false(panel.view.has("catalog"))
	assert_false(panel.tabs.visible)
	var text := _all_label_text(panel)
	assert_false(text.contains(RaceTheme.unit_name("settler", "human")), "fila rival não vaza")

func test_city_summary_row_opens_the_new_city_panel_on_production():
	hud.ui_shell.toggle_city_summary()
	hud.ui_shell.city_summary.city_requested.emit(city)
	assert_eq(router.mode, ContextRouter.MODE_CITY)
	assert_eq(router.city_panel.current_tab, "production")
	assert_false(hud.tile_info_panel.visible, "painel legado não é mais o destino")

# --- Paridade de ações urbanas (Fase 30) -------------------------------------------------

func test_city_upgrade_and_fortification_start_the_real_projects():
	_learn_unlock("v2_city_level_2")
	var panel := _open("overview")
	var upgrade: AEButton = panel.action_buttons.city_upgrade
	assert_false(upgrade.disabled, city.city_upgrade_unavailable_reason())
	upgrade.pressed.emit()
	assert_eq(city.production_item, V2CityLevelData.project_id_for_level(2))
	city.set_production("")
	city.apply_city_level(2)
	panel.select_tab("defense")
	var fortification := panel.production_item_for(V2FortificationData.project_id(1))
	assert_not_null(fortification)
	assert_false(fortification.disabled, city.fortification_unavailable_reason())
	fortification.pressed.emit()
	assert_eq(city.production_item, V2FortificationData.project_id(1))
