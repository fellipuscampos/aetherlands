extends GutTest

## Fase 30 / UI-3 — ContextHost real: roteamento Tile/Unidade/Cidade, Unit Panel
## (hierarquia, comandos × habilidades, passivas × status, SEM COMANDO, casters,
## Lendária, Manifestação, Construtor, Colonizador, Cerco, Voadora), estados do
## AEAbilityButton, varredura genérica das 12 Técnicas + 24 feitiços, banner de
## mira e Tile Context com névoa.

const CLERIC := "v2_unit_sacred_cleric"
const SERAPH := "v2_manifestation_seraph"
const SHIELDBEARER := "v2_unit_shieldbearer"
const CHAMPION := "v2_legendary_guardian_champion"
const SKELETON := "v2_unit_skeleton_host"
const BUILDER := "v2_unit_builder"
const CATAPULT := "v2_unit_catapult"
const GRIFFON := "v2_legendary_griffon_rider"

var hud: Control
var router: ContextRouter
var grid: HexGrid
var player: PlayerData
var rival: PlayerData
var _original_grid: HexGrid
var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]
var _original_turn: int

func before_each():
	_original_grid = GameManager.hex_grid
	_original_human = GameManager.human_player
	_original_players = GameManager.players
	_original_rivals = GameManager.rival_players
	_original_turn = TurnManager.turn_number
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
	player.mana = 100.0
	player.gold = 500.0
	TurnManager.turn_number = 5
	hud = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	router = hud.ui_shell.context_router

func after_each():
	SelectionManager.reset()
	GameManager.hex_grid = _original_grid
	GameManager.human_player = _original_human
	GameManager.players = _original_players
	GameManager.rival_players = _original_rivals
	TurnManager.turn_number = _original_turn
	player.release_relations()
	rival.release_relations()
	grid.queue_free()

func _learn(prefix: String, tier: int, who: PlayerData = null) -> void:
	var target := who if who != null else player
	for i in range(1, tier + 1):
		target.v2_research.complete_research("%s_%d" % [prefix, i])

func _unit(kind: String, coord: Vector2i, owner: PlayerData = null) -> Unit:
	var unit := grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner if owner != null else player)
	unit.movement_left = unit.unit_data.movement_points
	return unit

func _select(unit: Unit) -> UnitContextPanel:
	SelectionManager.select_unit(unit)
	router.flush()
	return router.unit_panel

func _click_tile(coord: Vector2i) -> void:
	EventBus.tile_selected.emit(coord, grid.get_tile(coord))
	router.flush()

func _visible_primary_count() -> int:
	var count := 0
	for panel in [router.unit_panel, router.city_panel, router.tile_panel]:
		if (panel as Control).visible:
			count += 1
	return count

func _ability(panel: UnitContextPanel, id: String) -> UnitAbilityViewData:
	for view in panel.view.abilities:
		if view.id == id:
			return view
	return null

func _command(panel: UnitContextPanel, id: String) -> UnitAbilityViewData:
	for view in panel.view.commands:
		if view.id == id:
			return view
	return null

func _passive_titles(panel: UnitContextPanel) -> Array:
	return panel.view.passives.map(func(entry): return entry.title)

func _status_titles(panel: UnitContextPanel) -> Array:
	return panel.view.statuses.map(func(entry): return entry.title)

# --- Roteamento ----------------------------------------------------------------------

func test_selection_routes_to_exactly_one_primary_context():
	var empty := Vector2i(3, 0)
	_click_tile(empty)
	assert_eq(router.mode, ContextRouter.MODE_TILE)
	assert_eq(_visible_primary_count(), 1)
	var own := _unit(SHIELDBEARER, Vector2i(0, 0))
	_select(own)
	assert_eq(router.mode, ContextRouter.MODE_UNIT)
	assert_eq(_visible_primary_count(), 1)
	var enemy := _unit("warrior", Vector2i(-3, 0), rival)
	_click_tile(enemy.coord)
	assert_eq(router.mode, ContextRouter.MODE_UNIT, "unidade rival visível abre o Unit Panel somente leitura")
	assert_false(router.unit_panel.view.own)
	var city := grid.found_city(Vector2i(0, 3), player, "Capital")
	_click_tile(city.coord)
	assert_eq(router.mode, ContextRouter.MODE_CITY)
	assert_eq(_visible_primary_count(), 1)
	router.close_context()
	assert_false(hud.ui_shell.context_host.visible)
	assert_eq(_visible_primary_count(), 0)
	assert_false(hud.unit_panel.visible, "UnitPanel legado nunca aparece")
	assert_false(hud.tile_info_panel.visible, "TileInfoPanel legado nunca aparece")

func test_garrisoned_city_uses_a_compact_selector_instead_of_stacked_panels():
	var city := grid.found_city(Vector2i(0, 0), player, "Capital")
	var guard := _unit(SHIELDBEARER, city.coord)
	_select(guard)
	assert_eq(router.mode, ContextRouter.MODE_CITY, "cidade própria continua o contexto principal")
	assert_eq(router.options, ["city", "unit", "tile"])
	assert_true(router.selector.visible)
	router.selector_button("unit").pressed.emit()
	router.flush()
	assert_eq(router.mode, ContextRouter.MODE_UNIT)
	assert_eq(_visible_primary_count(), 1)
	router.selector_button("tile").pressed.emit()
	assert_eq(router.mode, ContextRouter.MODE_TILE)

func test_context_width_stays_below_forty_percent_at_baselines():
	for size in [Vector2(1920, 1080), Vector2(1600, 900), Vector2(1280, 720)]:
		hud.ui_shell.apply_viewport_size(size)
		assert_lt(hud.ui_shell.context_width, size.x * 0.4)
		assert_lte(hud.ui_shell.context_width, 440.0)

# --- Unit Panel ----------------------------------------------------------------------

func test_mundane_unit_panel_separates_stats_commands_techniques_passives_and_supply():
	_learn("v2_doctrine_guardian", 6)
	var unit := _unit(SHIELDBEARER, Vector2i.ZERO)
	var panel := _select(unit)
	assert_eq(panel.name_label.text, RaceTheme.unit_name(SHIELDBEARER, "human"))
	var keys: Array = panel.view.stats.map(func(stat): return stat.key)
	assert_eq(keys, ["attack", "defense", "movement"])
	assert_eq(panel.stat_items.size(), 3, "stats viram blocos, não uma linha corrida")
	for id in ["move", "fortify", "explore"]:
		assert_not_null(_command(panel, id), id)
	var wall := _ability(panel, V2DoctrineTechniqueDatabase.SHIELD_WALL)
	assert_not_null(wall, "Técnica ativa entra no grid de habilidades")
	assert_eq(wall.category, UnitAbilityViewData.Category.TECHNIQUE)
	assert_null(_ability(panel, V2DoctrineTechniqueDatabase.BRACE_SPEARS), "passiva nunca vira botão")
	var brace := V2DoctrineTechniqueDatabase.get_technique(V2DoctrineTechniqueDatabase.BRACE_SPEARS)
	assert_has(_passive_titles(panel), brace.display_name)
	var footer: Array = panel.view.footer.map(func(entry): return entry.caption)
	assert_has(footer, "Suprimentos")
	assert_not_null(panel.button_for("move"))
	assert_true(panel.get_node("Scroll/Body/Commands") != null)

func test_caster_with_four_spells_has_no_basic_attack_and_readable_spell_states():
	_learn("v2_magic_sacred", 7)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	var injured := _unit("warrior", Vector2i(1, 0))
	injured.hp = 2.0
	var panel := _select(cleric)
	assert_eq(panel.view.abilities.size(), 4)
	assert_true(String(panel.view.ability_title).begins_with("Magia"))
	var attack: Dictionary = panel.view.stats[0]
	assert_eq(attack.value, "—")
	assert_string_contains(attack.tooltip, "Sem ataque básico.")
	for view in panel.view.abilities:
		assert_eq(view.category, UnitAbilityViewData.Category.SPELL)
		assert_string_contains(view.cost_text, "Mana")
	cleric.magic_cooldowns["v2_spell_sacred_aegis"] = TurnManager.turn_number + 2
	player.mana = 0.0
	panel.refresh()
	var aegis := _ability(panel, "v2_spell_sacred_aegis")
	assert_eq(aegis.state, UnitAbilityViewData.State.COOLDOWN)
	assert_eq(aegis.cooldown_current, 2)
	var aegis_button := panel.button_for("v2_spell_sacred_aegis") as AEAbilityButton
	assert_true(aegis_button.get_node("Content/IconSlot/CooldownNumber").visible, "recarga lida NO ícone")
	assert_eq(aegis_button.get_node("Content/IconSlot/CooldownNumber").text, "2")
	var light := _ability(panel, "v2_spell_restoring_light")
	assert_eq(light.state, UnitAbilityViewData.State.BLOCKED)
	assert_string_contains(light.blocked_reason, "Mana insuficiente")
	assert_eq(light.cost_text, "%d Mana" % int(V2SpellDatabase.get_spell("v2_spell_restoring_light").mana_cost), "custo continua visível quando bloqueado")
	assert_string_contains(light.tooltip(), "Mana insuficiente")

func test_silence_blocks_spells_with_the_runtime_reason_and_shows_as_harmful_status():
	_learn("v2_magic_sacred", 7)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	cleric.magic_status["v2_spell_silence"] = V2OwnerTurnEffect.expiry_for_now()
	var panel := _select(cleric)
	for view in panel.view.abilities:
		assert_eq(view.blocked_reason, V2MagicRuntime.unavailable_reason(cleric, view.id, grid))
		assert_string_contains(view.blocked_reason, "Silêncio")
	var silence: Array = panel.view.statuses.filter(func(entry): return entry.title == V2SpellDatabase.get_spell("v2_spell_silence").display_name)
	assert_eq(silence.size(), 1)
	assert_eq(silence[0].tone, AEStatusChip.Tone.NEGATIVE)

func test_aegis_is_a_temporary_status_with_duration_not_a_passive():
	var warrior := _unit("warrior", Vector2i.ZERO)
	warrior.magic_status["v2_spell_sacred_aegis"] = V2OwnerTurnEffect.expiry_for_now()
	var panel := _select(warrior)
	var aegis_name := V2SpellDatabase.get_spell("v2_spell_sacred_aegis").display_name
	assert_has(_status_titles(panel), aegis_name)
	assert_does_not_have(_passive_titles(panel), aegis_name)
	var entry: Dictionary = panel.view.statuses.filter(func(e): return e.title == aegis_name)[0]
	assert_eq(entry.turns, 1, "até o início do próximo turno do dono")
	assert_eq(entry.tone, AEStatusChip.Tone.POSITIVE)

func test_manifestation_has_school_badge_supply_zero_and_is_not_legendary():
	var seraph := _unit(SERAPH, Vector2i.ZERO)
	var panel := _select(seraph)
	var badges: Array = panel.view.badges.map(func(badge): return badge.text)
	assert_true(badges.any(func(text): return String(text).begins_with("GRANDE MANIFESTAÇÃO")), str(badges))
	assert_true(badges.any(func(text): return String(text).contains("SAGRADA")), str(badges))
	assert_false(badges.has("LENDÁRIA"))
	assert_eq(seraph.unit_data.supply_cost, 0)
	assert_false(panel.view.footer.any(func(entry): return entry.caption == "Suprimentos"))

func test_legendary_champion_shows_badge_aura_and_techniques_in_the_same_architecture():
	_learn("v2_doctrine_guardian", 9)
	var champion := _unit(CHAMPION, Vector2i.ZERO)
	var panel := _select(champion)
	var badges: Array = panel.view.badges.map(func(badge): return badge.text)
	assert_has(badges, "LENDÁRIA")
	assert_has(_passive_titles(panel), champion.unit_data.aura_name)
	assert_not_null(_ability(panel, V2DoctrineTechniqueDatabase.SHIELD_WALL))
	assert_true(panel.view.passives.all(func(entry): return not String(entry.title).contains("legendary")), "sem trait id cru")

func test_uncommanded_retinue_warns_blocks_orders_and_keeps_dissolve():
	var host := _unit(SKELETON, Vector2i.ZERO)
	assert_false(host.can_receive_orders(), "sem Necromante não há capacidade de Comando")
	var panel := _select(host)
	assert_not_null(panel.warning_panel)
	assert_eq(panel.warning_panel.get_node("Content/WarningTitle").text, "SEM COMANDO")
	for id in ["move", "fortify", "explore"]:
		assert_eq(_command(panel, id).state, UnitAbilityViewData.State.BLOCKED, id)
	var dissolve := _ability(panel, "dissolve")
	assert_not_null(dissolve)
	assert_eq(dissolve.state, UnitAbilityViewData.State.READY, "Dissolver vale mesmo sem comando")
	var attention: AttentionService = hud.ui_shell.attention_service
	attention.refresh()
	var retinue_items := attention.items().filter(func(item): return item.id == "retinue_uncommanded")
	assert_eq(retinue_items.size(), 1)
	assert_eq(retinue_items[0].priority, AttentionItem.Priority.WARNING, "nunca Required")
	(panel.button_for("dissolve") as AEAbilityButton).pressed.emit()
	assert_true(host.is_queued_for_deletion() or not is_instance_valid(host) or not player.units.has(host))

func test_builder_shows_charges_and_improvement_command_with_runtime_reason():
	var builder := _unit(BUILDER, Vector2i.ZERO)
	builder.work_charges_remaining = 2
	var panel := _select(builder)
	var improve := _command(panel, "improve_resource")
	assert_not_null(improve)
	assert_eq(improve.blocked_reason, V2ConstructorRuntime.unavailable_reason(builder, grid))
	assert_true(panel.view.footer.any(func(entry): return entry.caption == "Cargas" and String(entry.text).begins_with("2")))
	assert_true(panel.view.abilities.is_empty(), "Construtor não vira painel de combate")

func test_settler_offers_found_city_without_supply_or_empty_ability_box():
	var settler := _unit("settler", Vector2i.ZERO)
	var panel := _select(settler)
	var found := _command(panel, "found_city")
	assert_not_null(found)
	assert_true(panel.view.abilities.is_empty())
	assert_null(panel.get_node_or_null("Scroll/Body/Abilities"), "sem seção de habilidades vazia")
	assert_false(panel.view.footer.any(func(entry): return entry.caption == "Suprimentos"))

func test_siege_and_flying_badges_come_from_unit_data():
	var catapult := _unit(CATAPULT, Vector2i.ZERO)
	var panel := _select(catapult)
	assert_true(panel.view.badges.any(func(badge): return badge.text == "Cerco"))
	var griffon := _unit(GRIFFON, Vector2i(2, 0))
	panel = _select(griffon)
	assert_true(panel.view.badges.any(func(badge): return badge.text == "Voadora"))

func test_enemy_unit_is_read_only_and_hides_private_state():
	_learn("v2_doctrine_guardian", 6, rival)
	var enemy := _unit(SHIELDBEARER, Vector2i(2, 0), rival)
	enemy.magic_cooldowns[V2DoctrineTechniqueDatabase.SHIELD_WALL] = TurnManager.turn_number + 3
	_click_tile(enemy.coord)
	var panel := router.unit_panel
	assert_false(panel.view.own)
	assert_true(panel.view.commands.is_empty())
	assert_true(panel.view.abilities.is_empty())
	assert_eq(panel.command_buttons.size() + panel.ability_buttons.size(), 0)
	var brace := V2DoctrineTechniqueDatabase.get_technique(V2DoctrineTechniqueDatabase.BRACE_SPEARS)
	assert_does_not_have(_passive_titles(panel), brace.display_name, "pesquisa rival não vaza")
	assert_false(panel.view.stats.any(func(stat): return String(stat.value).contains("/")), "movimento restante é privado")

# --- AEAbilityButton ----------------------------------------------------------------

func test_ability_button_states_are_distinct_and_passive_is_not_clickable():
	var button := AEAbilityButton.new()
	add_child_autofree(button)
	var view := UnitAbilityViewData.create("x", "Golpe", UnitAbilityViewData.Category.TECHNIQUE)
	button.configure_view(view)
	assert_false(button.disabled)
	view.state = UnitAbilityViewData.State.TARGETING
	button.configure_view(view)
	assert_true(button.button_pressed)
	assert_eq(button.meta_label.text, "Escolha o alvo")
	view.state = UnitAbilityViewData.State.COOLDOWN
	view.cooldown_current = 3
	button.configure_view(view)
	assert_true(button.disabled)
	assert_eq(button.get_node("Content/IconSlot/CooldownNumber").text, "3")
	assert_true(button.get_node("Content/IconSlot/CooldownShade").visible)
	view.state = UnitAbilityViewData.State.BLOCKED
	view.cooldown_current = 0
	view.blocked_reason = "Nenhuma unidade hostil ao alcance."
	button.configure_view(view)
	assert_true(button.disabled)
	assert_eq(button.meta_label.text, "Nenhuma unidade hostil ao alcance")
	assert_string_contains(button.tooltip_text, AETooltip.REASON_PREFIX + "Nenhuma unidade hostil ao alcance.")
	view.state = UnitAbilityViewData.State.PASSIVE
	button.configure_view(view)
	assert_true(button.disabled)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(button.theme_type_variation, &"GhostButton")
	view.state = UnitAbilityViewData.State.ACTIVE
	button.configure_view(view)
	assert_eq(button.meta_label.text, "Ativa")

func test_all_twelve_techniques_and_twenty_four_spells_render_through_the_generic_descriptor():
	var seen_techniques := {}
	for technique in V2DoctrineTechniqueDatabase.all_techniques():
		var branch: String = technique.doctrine_branch
		_learn("v2_doctrine_%s" % branch, 9)
		var kind: String = V2UnitLine.unit_ids(branch)[0]
		var unit := _unit(kind, Vector2i(4, -2))
		var abilities := UnitPresenter.abilities_for(unit, grid)
		var found: bool = abilities.any(func(view): return view.id == technique.id and view.category == UnitAbilityViewData.Category.TECHNIQUE)
		var passive: bool = UnitPresenter.build(unit, player, grid).passives.any(func(entry): return entry.title == technique.display_name)
		assert_true(found != passive, "%s aparece como ativa OU passiva" % technique.id)
		seen_techniques[technique.id] = true
		grid.remove_unit(unit)
	assert_eq(seen_techniques.size(), 12)
	var spell_ids := {}
	var schools := {}
	for spell in V2SpellDatabase.all_spells():
		schools[spell.school_branch] = true
	for school in schools:
		_learn("v2_magic_%s" % school, 9)
		var caster_kind := ""
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			var data := UnitDatabase.create_unit(kind)
			if data.v2_magic_school == school and not V2ManifestationSystem.is_manifestation_kind(kind):
				caster_kind = kind
				break
		assert_ne(caster_kind, "", school)
		var caster := _unit(caster_kind, Vector2i(0, 2))
		for view in UnitPresenter.abilities_for(caster, grid):
			if view.category != UnitAbilityViewData.Category.SPELL:
				continue
			var button := AEAbilityButton.new()
			add_child_autofree(button)
			button.configure_view(view)
			assert_eq(button.title_label.text, view.display_name)
			spell_ids[view.id] = true
		grid.remove_unit(caster)
	assert_eq(spell_ids.size(), 24)

func test_ability_components_never_cite_concrete_ids():
	for path in ["res://scripts/ui/components/AEAbilityButton.gd", "res://scripts/ui/presenters/UnitPresenter.gd", "res://scripts/ui/presenters/UnitAbilityViewData.gd", "res://scripts/ui/context/UnitContextPanel.gd"]:
		var source := FileAccess.get_file_as_string(path)
		# Só literais de id (entre aspas); nomes de API como `v2_spell_targeting_id` são permitidos.
		for forbidden in ["\"v2_spell_", "\"v2_technique_", "\"v2_unit_", "\"v2_legendary_", "\"v2_manifestation_"]:
			assert_false(source.contains(forbidden), "%s cita %s" % [path, forbidden])

# --- Mira --------------------------------------------------------------------------------

func test_spell_targeting_shows_banner_and_escape_cancels_without_spending():
	_learn("v2_magic_sacred", 4)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	var injured := _unit("warrior", Vector2i(1, 0))
	injured.hp = 2.0
	var panel := _select(cleric)
	var mana_before := player.mana
	(panel.button_for("v2_spell_restoring_light") as AEAbilityButton).pressed.emit()
	assert_eq(SelectionManager.v2_spell_targeting_id, "v2_spell_restoring_light")
	var banner: TargetingBanner = hud.ui_shell.targeting_banner
	assert_true(banner.is_active())
	assert_eq(banner.title_label.text, V2SpellDatabase.get_spell("v2_spell_restoring_light").display_name)
	assert_eq(int(banner.current.range), V2MagicRuntime.effective_range(cleric, V2SpellDatabase.get_spell("v2_spell_restoring_light")))
	router.flush()
	assert_eq(router.unit_panel.view.abilities[0].state, UnitAbilityViewData.State.TARGETING, "o painel só marca a habilidade em mira")
	assert_true(SelectionManager.cancel_active_targeting(), "ESC/cancelar")
	assert_false(banner.is_active())
	assert_eq(player.mana, mana_before)
	assert_eq(V2MagicRuntime.cooldown_remaining(cleric, "v2_spell_restoring_light"), 0)
	assert_gt(cleric.movement_left, 0.0)

func test_invalid_target_click_gives_short_feedback_and_spends_nothing():
	_learn("v2_magic_sacred", 4)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	var injured := _unit("warrior", Vector2i(1, 0))
	injured.hp = 2.0
	_select(cleric)
	SelectionManager.use_v2_spell_selected("v2_spell_restoring_light")
	var mana_before := player.mana
	SelectionManager._handle_v2_spell_targeting_click(Vector2i(-5, 0))
	var banner: TargetingBanner = hud.ui_shell.targeting_banner
	assert_true(banner.feedback_panel.visible)
	assert_string_contains(banner.feedback_label.text, "Nenhuma Mana")
	assert_eq(player.mana, mana_before)
	assert_eq(SelectionManager.v2_spell_targeting_id, "")

func test_opening_a_strategic_screen_ends_targeting():
	_learn("v2_magic_sacred", 4)
	var cleric := _unit(CLERIC, Vector2i.ZERO)
	var injured := _unit("warrior", Vector2i(1, 0))
	injured.hp = 2.0
	_select(cleric)
	SelectionManager.use_v2_spell_selected("v2_spell_restoring_light")
	assert_true(SelectionManager.is_targeting())
	hud.ui_shell.open_destination(NavigationManager.EMPIRE)
	assert_false(SelectionManager.is_targeting())
	hud.ui_shell.close_strategic_overlay()

func test_building_placement_is_targeting_and_escape_path_cancels_it():
	var city := grid.found_city(Vector2i.ZERO, player, "Capital")
	_learn("v2_doctrine_guardian", 2)
	SelectionManager.start_building_placement(city, "v2_building_guardian_hall")
	assert_true(SelectionManager.is_targeting())
	assert_eq(TargetingPresenter.current().kind, "placement")
	assert_true(SelectionManager.cancel_building_placement())
	assert_eq(TargetingPresenter.current(), {})

# --- Tile ------------------------------------------------------------------------------

func test_tile_context_separates_base_terrain_modification_environment_resource_and_portal():
	var coord := Vector2i(2, 1)
	V2TerrainRuntime.apply(grid, coord, "v2_terrain_raised_ground")
	assert_true(V2EnvironmentalZoneSystem.apply(grid, coord, "v2_zone_dense_mist", 1, "elementalism"))
	grid.get_tile(coord).resource = "iron"
	var view := TilePresenter.build(grid, coord, player)
	assert_eq(view.terrain.name, grid.get_tile(coord).display_name, "terreno-base")
	assert_false(view.modification.is_empty(), "modificação druídica é uma camada própria")
	assert_ne(view.modification.name, view.terrain.name)
	assert_false(view.environment.is_empty(), "ambiente temporário separado da modificação")
	_click_tile(coord)
	assert_eq(router.mode, ContextRouter.MODE_TILE)
	var body := router.tile_panel.body
	assert_not_null(body.get_node_or_null("Terrain"))
	assert_not_null(body.get_node_or_null("Modification"))
	assert_not_null(body.get_node_or_null("Environment"))
	assert_true(view.features.any(func(feature): return feature.kind == "resource"), "recurso aparece como característica")
	var portal_a := Vector2i(-3, 1)
	var portal_b := Vector2i(-5, 3)
	assert_true(V2PortalSystem.create_or_replace_pair(player, "arcanism", portal_a, portal_b, grid))
	var portal_view := TilePresenter.build(grid, portal_a, player)
	assert_true(portal_view.features.any(func(feature): return feature.kind == "portal"))

func test_fog_hides_entities_and_marks_remembered_tiles():
	var hidden := Vector2i(5, -2)
	_unit("warrior", hidden, rival)
	grid.visibility[hidden] = HexGrid.Visibility.UNSEEN
	var unseen := TilePresenter.build(grid, hidden, player)
	assert_eq(unseen.state, TileInspector.STATE_UNSEEN)
	assert_true(unseen.occupants.is_empty())
	assert_true(unseen.features.is_empty())
	grid.visibility[hidden] = HexGrid.Visibility.EXPLORED
	var remembered := TilePresenter.build(grid, hidden, player)
	assert_true(remembered.remembered)
	assert_true(remembered.occupants.is_empty(), "unidade rival fora da visão não aparece")
	_click_tile(hidden)
	assert_eq(router.mode, ContextRouter.MODE_TILE, "névoa nunca abre contexto de unidade")

func test_unit_death_invalidates_context_without_dangling_references():
	var unit := _unit(SHIELDBEARER, Vector2i.ZERO)
	_select(unit)
	grid.remove_unit(unit)
	unit.free()
	EventBus.fog_updated.emit()
	router.flush()
	assert_ne(router.mode, ContextRouter.MODE_UNIT)

# --- Paridade de ações (Fase 30) -------------------------------------------------------

func _press(panel: UnitContextPanel, id: String) -> void:
	var button := panel.button_for(id) as BaseButton
	assert_not_null(button, id)
	button.pressed.emit()
	router.flush()

func test_commands_and_technique_use_the_same_selection_manager_paths():
	_learn("v2_doctrine_guardian", 4)
	var unit := _unit(SHIELDBEARER, Vector2i.ZERO)
	var panel := _select(unit)
	_press(panel, "move")
	assert_true(SelectionManager.move_mode, "Mover liga o modo de movimento")
	_press(panel, "fortify")
	assert_true(unit.fortified)
	_press(panel, "fortify")
	assert_false(unit.fortified, "Fortificar é alternância")
	_press(panel, V2DoctrineTechniqueDatabase.SHIELD_WALL)
	assert_true(V2TechniqueRuntime.is_active(unit, V2DoctrineTechniqueDatabase.SHIELD_WALL))
	assert_eq(unit.movement_left, 0.0, "Técnica gasta a ação pela regra real")
	assert_true(panel.view.statuses.any(func(entry): return entry.title == V2DoctrineTechniqueDatabase.get_technique(V2DoctrineTechniqueDatabase.SHIELD_WALL).display_name))
	assert_eq(_ability(panel, V2DoctrineTechniqueDatabase.SHIELD_WALL).state, UnitAbilityViewData.State.ACTIVE)

func test_explore_command_toggles_the_real_order():
	# A exploração real se desliga sozinha sem região inexplorada: deixa o leste escondido.
	for coord in grid.tiles.keys():
		if coord.x >= 4:
			grid.visibility[coord] = HexGrid.Visibility.UNSEEN
	var unit := _unit("warrior", Vector2i.ZERO)
	var panel := _select(unit)
	_press(panel, "explore")
	assert_true(unit.exploring)

func test_found_city_command_founds_through_city_site():
	var settler := _unit("settler", Vector2i(-2, 2))
	var panel := _select(settler)
	assert_eq(_command(panel, "found_city").state, UnitAbilityViewData.State.READY)
	_press(panel, "found_city")
	assert_not_null(grid.get_city_at(Vector2i(-2, 2)))

func test_upgrade_ability_evolves_through_the_real_rule():
	_learn("v2_doctrine_guardian", 5)
	var city := grid.found_city(Vector2i(2, 2), player, "Forte", true)
	city.buildings["v2_building_guardian_hall"] = true
	var unit := _unit(SHIELDBEARER, city.coord)
	var panel := _select(unit)
	router.selector_button("unit").pressed.emit()
	router.flush()
	panel = router.unit_panel
	var upgrade := _ability(panel, "upgrade")
	assert_not_null(upgrade)
	assert_eq(upgrade.blocked_reason, "", str(upgrade.blocked_reason))
	var gold := player.gold
	_press(panel, "upgrade")
	assert_ne(unit.unit_data.visual_kind, SHIELDBEARER)
	assert_lt(player.gold, gold)

func test_portal_command_traverses_through_the_runtime():
	var traveler := _unit("warrior", Vector2i(-4, 0))
	assert_true(V2PortalSystem.create_or_replace_pair(player, "arcanism", traveler.coord, Vector2i(4, -3), grid))
	var panel := _select(traveler)
	var portal := _command(panel, "traverse_portal")
	assert_not_null(portal)
	assert_eq(portal.blocked_reason, V2PortalSystem.traversal_reason(traveler, grid))
	_press(panel, "traverse_portal")
	assert_ne(traveler.coord, Vector2i(-4, 0))

func test_builder_command_builds_the_improvement():
	var city := grid.found_city(Vector2i(0, -3), player, "Mina", true)
	var coord := grid.get_neighbors(city.coord)[0]
	if not coord in city.owned_tiles:
		city.owned_tiles.append(coord)
	grid.get_tile(coord).resource = "iron"
	var builder := _unit(BUILDER, coord)
	builder.work_charges_remaining = 2
	var panel := _select(builder)
	assert_eq(_command(panel, "improve_resource").state, UnitAbilityViewData.State.READY, V2ConstructorRuntime.unavailable_reason(builder, grid))
	_press(panel, "improve_resource")
	assert_true(city.resource_improvements.has(coord))

func test_logistic_tension_is_shown_as_a_derived_status():
	var unit := _unit(SHIELDBEARER, Vector2i.ZERO)
	assert_true(V2LogisticsRuntime.is_logistically_strained(player), "pré-condição: sem cidade não há capacidade")
	var panel := _select(unit)
	assert_has(_status_titles(panel), "Tensão Logística")
