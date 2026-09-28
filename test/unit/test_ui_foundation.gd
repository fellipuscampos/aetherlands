extends GutTest

var shell: UIShell

func before_each():
	var scene: PackedScene = load("res://scenes/ui/UIShell.tscn")
	shell = scene.instantiate()
	add_child_autofree(shell)

func test_real_theme_loads_with_critical_variations():
	var theme := load(UITheme.THEME_PATH) as Theme
	assert_not_null(theme)
	for variation in [&"PrimaryButton", &"SecondaryButton", &"DangerButton", &"GhostButton", &"IconButton", &"HeadingLabel", &"SubheadingLabel", &"SectionLabel", &"BodySmallLabel", &"UIControlLabel", &"MutedLabel", &"CaptionLabel", &"SurfacePanel", &"ElevatedPanel", &"ModalPanel"]:
		assert_ne(theme.get_type_variation_base(variation), &"", "variação ausente: %s" % variation)

func test_component_library_instantiates_and_has_minimum_targets():
	var components: Array[Control] = [
		AEButton.new(), AEIconButton.new(), AEPanel.new(), AESectionHeader.new(),
		AEStatDisplay.new(), AEProgressBar.new(), AEBadge.new(), AEStatusChip.new(),
		AETooltipHost.new(), AEModalFrame.new(), AEAbilityButton.new(),
	]
	for component in components:
		add_child_autofree(component)
	assert_gte((components[0] as AEButton).custom_minimum_size.y, float(UIThemeTokens.TARGET_MIN))
	assert_gte((components[1] as AEIconButton).custom_minimum_size.x, float(UIThemeTokens.TARGET_MIN))

func test_ability_button_represents_cooldown_cost_selected_and_passive_without_ids():
	var ability := AEAbilityButton.new()
	add_child_autofree(ability)
	ability.configure("Técnica", AEAbilityButton.AbilityState.COOLDOWN, 3, "20 Mana")
	assert_true(ability.disabled)
	assert_true(ability.get_node("CooldownBadge").visible)
	assert_eq(ability.get_node("CooldownBadge").text, "3")
	assert_eq(ability.get_node("CostBadge").text, "20 Mana")
	ability.configure("Passiva", AEAbilityButton.AbilityState.PASSIVE)
	assert_eq(ability.theme_type_variation, &"GhostButton")

func test_status_chip_has_semantic_tone_and_duration():
	var chip := AEStatusChip.new()
	add_child_autofree(chip)
	chip.set_status("Fortificado", AEStatusChip.Tone.POSITIVE, 2, "+")
	assert_eq(chip.tone, AEStatusChip.Tone.POSITIVE)
	assert_eq(chip.duration_turns, 2)
	assert_true(chip.label.text.contains("2T"))

func test_shell_has_definitive_hosts_and_strict_layer_order():
	assert_not_null(shell.global_bar)
	assert_not_null(shell.context_host)
	assert_not_null(shell.bottom_host)
	assert_not_null(shell.strategic_overlay_host)
	assert_not_null(shell.modal_manager)
	assert_not_null(shell.toast_presenter)
	assert_not_null(shell.tooltip_host)
	assert_not_null(shell.minimap_host)
	assert_not_null(shell.attention_presenter)
	assert_not_null(shell.turn_controller)
	assert_not_null(shell.event_center)
	var layers := shell.layer_order()
	assert_lt(layers.map, layers.chrome)
	assert_lt(layers.chrome, layers.strategic)
	assert_lt(layers.strategic, layers.modal)
	assert_lt(layers.modal, layers.toast)
	assert_lt(layers.toast, layers.tooltip)
	assert_lt(layers.tooltip, layers.debug)
	assert_eq(shell.map_pass_through.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_hud_physically_rehosts_the_existing_minimap_without_replacing_it():
	var hud := (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_same(hud.minimap.get_parent(), hud.ui_shell.minimap_host)
	assert_true(hud.minimap.has_method("_gui_input"))

func test_navigation_is_exclusive_and_escape_closes_the_active_overlay():
	var research := PanelContainer.new()
	var diplomacy := PanelContainer.new()
	add_child_autofree(research)
	add_child_autofree(diplomacy)
	shell.register_strategic_overlay(NavigationManager.RESEARCH, research)
	shell.register_strategic_overlay(NavigationManager.DIPLOMACY, diplomacy)
	shell.open_destination(NavigationManager.RESEARCH)
	assert_true(research.visible)
	shell.open_destination(NavigationManager.DIPLOMACY)
	assert_false(research.visible)
	assert_true(diplomacy.visible)
	assert_true(shell.handle_escape())
	assert_false(diplomacy.visible)

func test_pause_is_a_semantic_navigation_destination():
	var called := [false]
	shell.register_pause_action(func(): called[0] = true)
	assert_true(shell.open_destination(NavigationManager.PAUSE))
	assert_true(called[0])

func test_modal_blocks_click_space_and_hotkeys_and_honors_cancelability():
	var modal := AEModalFrame.new()
	assert_true(shell.modal_manager.present(modal, true, true))
	var click := InputEventMouseButton.new()
	click.pressed = true
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	var hotkey := InputEventKey.new()
	hotkey.pressed = true
	hotkey.keycode = KEY_R
	assert_true(shell.modal_manager.blocks_gameplay_input(click))
	assert_true(shell.modal_manager.blocks_gameplay_input(space))
	assert_true(shell.modal_manager.blocks_gameplay_input(hotkey))
	assert_true(shell.modal_manager.handle_escape())
	assert_false(shell.modal_manager.is_modal_open())
	var locked := AEModalFrame.new()
	assert_true(shell.modal_manager.present(locked, false, true))
	assert_true(shell.modal_manager.handle_escape(), "ESC é consumido mesmo sem cancelar")
	assert_true(shell.modal_manager.is_modal_open(), "modal não cancelável permanece")
	shell.modal_manager.dismiss_top(true)

func test_responsive_context_bounds_at_required_resolutions():
	for viewport_size in [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1080)]:
		shell.apply_viewport_size(viewport_size)
		assert_lte(shell.context_width, 460.0)
		assert_gte(shell.context_width, 360.0)
		assert_lt(shell.context_width, viewport_size.x * 0.4)
	assert_eq(UIThemeTokens.breakpoint_name(1280), "medium")
	assert_eq(UIThemeTokens.breakpoint_name(1600), "large")

func test_global_bar_snapshot_uses_real_runtime_values():
	var player := PlayerData.new(CivilizationData.new())
	player.gold = 73.0
	player.mana = 19.0
	TurnManager.turn_number = 7
	var snapshot := shell.global_bar.build_snapshot(player)
	assert_eq(snapshot.turn, 7)
	assert_eq(snapshot.gold, 73)
	assert_eq(snapshot.supply_used, 0)
	assert_eq(snapshot.mana, 19)
	assert_eq(snapshot.knowledge_income, 0)
	assert_eq(snapshot.cities, 0)
	assert_eq(snapshot.units, 0)
	assert_true(shell.global_bar._icons.has("gold"), "cada recurso reserva um slot de ícone futuro")

func test_hud_hides_legacy_bar_duplicate_research_and_release_fps():
	var hud := (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child_autofree(hud)
	assert_false(hud.get_node("TopBar").visible)
	assert_false(hud.research_button.visible)
	assert_eq(hud.fps_label.visible, OS.is_debug_build())
	assert_not_null(hud.ui_shell.global_bar.navigation_row.get_node("ResearchButton"))
