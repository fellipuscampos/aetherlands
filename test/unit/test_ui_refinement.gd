extends GutTest

var shell: UIShell

func before_each() -> void:
	shell = (load("res://scenes/ui/UIShell.tscn") as PackedScene).instantiate()
	add_child_autofree(shell)

func test_palette_is_neutral_and_blue_remains_semantic() -> void:
	assert_lt(UIThemeTokens.COLOR_CANVAS.s, 0.35)
	assert_lt(UIThemeTokens.COLOR_SURFACE.s, 0.35)
	assert_ne(UIThemeTokens.COLOR_INFO, UIThemeTokens.COLOR_ACCENT)
	assert_lt(UIThemeTokens.ELEVATION_MODAL, 8)

func test_main_menu_has_one_brand_and_no_brand_card() -> void:
	var title: TitleScreen = (load("res://scenes/ui/TitleScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	assert_true(title.brand_panel is MarginContainer)
	var matches := 0
	for child in title.get_node("MainPage").find_children("*", "Label", true, false):
		if (child as Label).text.to_lower() == "aetherlands":
			matches += 1
	assert_eq(matches, 1)

func test_setup_uses_four_equal_tiles_and_numeric_stepper() -> void:
	var setup: GameSetupScreen = (load("res://scenes/ui/GameSetupScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(setup)
	var tiles := setup.get_node("CenterBox/Box/RaceSection/RaceListColumn")
	assert_eq(tiles.get_child_count(), 4)
	for tile in tiles.get_children():
		assert_eq((tile as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	setup._on_rival_count_pressed(3)
	assert_eq(setup.rival_count_value.text, "3")
	assert_true(setup.increase_rivals_button.disabled)
	setup._on_rival_count_pressed(1)
	assert_true(setup.decrease_rivals_button.disabled)

func test_global_bar_is_one_continuous_surface_and_compacts_navigation() -> void:
	assert_eq(shell.global_bar.custom_minimum_size.y, float(UIThemeTokens.GLOBAL_BAR_HEIGHT))
	for item in shell.global_bar._items.values():
		assert_true(item is HBoxContainer)
		assert_false(item is PanelContainer)
	shell.global_bar.set_compact(true)
	assert_eq((shell.global_bar.navigation_row.get_node("EmpireButton") as Button).text, "I")
	assert_eq((shell.global_bar.navigation_row.get_node("VictoryButton") as Button).tooltip_text, "Vitória")

func test_strategy_frame_obeys_safe_margins_and_content_height() -> void:
	var victory: VictoryScreen = (load("res://scenes/ui/strategy/VictoryScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(victory)
	victory.set_anchors_preset(Control.PRESET_TOP_LEFT)
	victory.size = Vector2(1280, 720)
	victory.top_reserved = 64.0
	victory.show_summary()
	victory._layout()
	var rect := victory.frame.get_rect()
	assert_gte(rect.position.x, float(UIThemeTokens.STRATEGIC_SAFE_MARGIN_X))
	assert_gte(rect.position.y, victory.top_reserved + UIThemeTokens.STRATEGIC_SAFE_MARGIN_Y)
	assert_lte(rect.end.x, 1280.0 - UIThemeTokens.STRATEGIC_SAFE_MARGIN_X)
	assert_lte(rect.end.y, 720.0 - UIThemeTokens.STRATEGIC_SAFE_MARGIN_Y)
	assert_lte(rect.size.y, 520.0)
	victory.show_detail(VictoryPresenter.DOMINATION)
	victory._layout()
	assert_gt(victory.frame.size.y, rect.size.y)
	assert_lte(victory.frame.size.y, 480.0)
	var diplomacy: DiplomacyScreen = (load("res://scenes/ui/strategy/DiplomacyScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(diplomacy)
	diplomacy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	diplomacy.size = Vector2(1280, 720)
	diplomacy._layout()
	assert_lte(diplomacy.frame.size.y, 440.0)

func test_drawer_and_system_surface_suppress_then_restore_context() -> void:
	shell.context_router.mode = ContextRouter.MODE_TILE
	shell.context_host.visible = true
	shell.toggle_event_center()
	assert_true(shell.context_router.is_suppressed())
	assert_false(shell.context_host.visible)
	shell.close_auxiliary_drawer()
	assert_false(shell.context_router.is_suppressed())
	assert_true(shell.context_host.visible)
	shell.set_system_surface_active(true)
	assert_false(shell.bottom_host.visible)
	assert_false(shell.auxiliary_host.visible)
	assert_true(shell.context_router.is_suppressed())
	shell.set_system_surface_active(false)
	assert_true(shell.bottom_host.visible)

func test_identity_portrait_is_square_with_top_accent_only() -> void:
	var portrait := AEPortrait.new()
	add_child_autofree(portrait)
	portrait.configure("U", Color.WHITE, Color.RED)
	assert_eq(portrait.custom_minimum_size.x, portrait.custom_minimum_size.y)
	assert_null(portrait.find_child("OwnerStrip", true, false))
	var edge := portrait.find_child("AccentEdge", true, false) as ColorRect
	assert_not_null(edge)
	assert_eq(edge.offset_bottom, 3.0)

func test_bottom_hud_uses_one_margin_token_and_baseline() -> void:
	shell.apply_viewport_size(Vector2(1920, 1080))
	assert_eq(shell.minimap_host.offset_bottom, -float(UIThemeTokens.HUD_EDGE_MARGIN))
	assert_eq(shell.turn_controller_host.offset_bottom, -float(UIThemeTokens.HUD_EDGE_MARGIN))

func test_settings_content_width_is_bounded_and_copy_is_accented() -> void:
	var settings: SettingsScreen = (load("res://scenes/ui/SettingsScreen.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	var page_panel := settings.get_node("Margin/Layout/Body/PagePanel") as PanelContainer
	assert_eq(page_panel.custom_minimum_size, Vector2(680, 440))
	assert_eq(settings.music_slider.custom_minimum_size.x, 480.0)
	assert_true("não é suportado" in settings.controls_text.text)

func test_number_format_never_emits_signed_zero() -> void:
	assert_eq(UIFormat.number(-0.0001, 1), "0")
	assert_eq(UIFormat.delta(-0.0001, 1), "0")
	assert_eq(UIFormat.delta(2.0), "+2")
	assert_eq(UIFormat.delta(-2.0), "-2")
