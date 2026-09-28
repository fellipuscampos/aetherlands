extends GutTest

const TEST_SAVE_DIR := "user://test_ui4_slots/"

var _original_scale: int
var _original_motion: bool

func before_each() -> void:
	_original_scale = Settings.ui_scale_percent
	_original_motion = Settings.reduced_motion

func after_each() -> void:
	Settings.ui_scale_percent = _original_scale
	Settings.reduced_motion = _original_motion
	var dir := DirAccess.open(TEST_SAVE_DIR)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)

func test_loading_phase_text_never_replaces_or_resizes_the_progress_anchor() -> void:
	var loading: LoadingScreen = load("res://scenes/ui/LoadingScreen.tscn").instantiate()
	add_child_autofree(loading)
	loading.set_message("Gerando o Mapa...")
	var width_before: float = loading.progress_bar.custom_minimum_size.x
	var progress_row := loading.progress_bar.get_parent() as HBoxContainer
	var row_width_before: float = progress_row.custom_minimum_size.x

	loading.set_progress(0.55, "Distribuindo recursos estrategicos por todos os continentes do mundo")

	assert_eq(loading.title_label.text, "Gerando o Mapa...")
	assert_eq(loading.detail_label.text, "Distribuindo recursos estrategicos por todos os continentes do mundo")
	assert_eq(loading.progress_bar.custom_minimum_size.x, width_before)
	assert_eq(loading.progress_bar.get_parent().custom_minimum_size.x, row_width_before)
	assert_eq(row_width_before, 640.0)

func test_ui_scale_changes_real_control_metrics_and_does_not_mutate_world_settings() -> void:
	var map_width_before := GameManager.map_width
	var map_height_before := GameManager.map_height
	Settings.ui_scale_percent = 150
	var theme := Settings.build_ui_theme()

	assert_eq(theme.get_font_size("font_size", "Label"), int(round(UIThemeTokens.FONT_BODY * 1.5)))
	assert_eq(theme.get_font_size("font_size", "Button"), int(round(UIThemeTokens.FONT_BODY * 1.5)))
	assert_eq(GameManager.map_width, map_width_before)
	assert_eq(GameManager.map_height, map_height_before)

func test_setup_shows_exactly_two_real_bonuses_for_every_race() -> void:
	for race_id in GameSetupScreen.RACE_INFO:
		assert_eq(V2RaceBonusDatabase.effect_lines(race_id).size(), 2, race_id)

func test_setup_lore_is_secondary_and_name_validation_is_inline() -> void:
	var setup: GameSetupScreen = load("res://scenes/ui/GameSetupScreen.tscn").instantiate()
	add_child_autofree(setup)
	assert_false(setup.race_lore_label.visible)
	setup._on_lore_pressed()
	assert_true(setup.race_lore_label.visible)
	setup.kingdom_name_edit.text = "X"
	setup.kingdom_name_edit.text_changed.emit("X")
	assert_true(setup.start_game_button.disabled)
	assert_true("2 caracteres" in setup.status_label.text)

func test_inspect_slots_reports_corrupt_and_incompatible_instead_of_hiding_them() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE_DIR))
	var corrupt := FileAccess.open(TEST_SAVE_DIR.path_join("corrupt.json"), FileAccess.WRITE)
	corrupt.store_string("{nao e json")
	corrupt.close()
	var incompatible := FileAccess.open(TEST_SAVE_DIR.path_join("future.json"), FileAccess.WRITE)
	incompatible.store_string(JSON.stringify({"version": 999, "human_kingdom_name": "Futuro"}))
	incompatible.close()

	var slots := SaveManager.inspect_slots(TEST_SAVE_DIR)
	var statuses: Array[String] = []
	for slot in slots:
		statuses.append(String(slot.status))
	assert_has(statuses, "corrupt")
	assert_has(statuses, "incompatible")

func test_settings_screen_has_real_categories_and_no_developer_tools_route() -> void:
	var screen: SettingsScreen = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	add_child_autofree(screen)
	assert_eq(screen._pages.size(), 5)
	assert_false(screen.debug_button.visible)
	assert_eq(screen.ui_scale_option.item_count, Settings.UI_SCALE_OPTIONS.size())
	assert_true("Remapeamento ainda não é suportado" in screen.controls_text.text)
