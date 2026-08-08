extends GutTest

## Cobre Settings.gd: clamping de volume e o ciclo salvar/carregar via
## ConfigFile. Usa um arquivo de teste isolado (TEST_SETTINGS_PATH) pra
## nunca tocar no user://settings.cfg de verdade do jogador.

const TEST_SETTINGS_PATH := "user://test_settings.cfg"

var _original_music_volume: float
var _original_sfx_volume: float

func before_each():
	_original_music_volume = Settings.music_volume
	_original_sfx_volume = Settings.sfx_volume

func after_each():
	Settings.music_volume = _original_music_volume
	Settings.sfx_volume = _original_sfx_volume
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func test_set_music_volume_clamps_above_one():
	Settings.set_music_volume(3.0)
	assert_almost_eq(Settings.music_volume, 1.0, 0.01)

func test_set_music_volume_clamps_below_zero():
	Settings.set_music_volume(-1.0)
	assert_almost_eq(Settings.music_volume, 0.0, 0.01)

func test_set_sfx_volume_clamps_to_valid_range():
	Settings.set_sfx_volume(5.0)
	assert_almost_eq(Settings.sfx_volume, 1.0, 0.01)

func test_set_volume_emits_volume_changed():
	watch_signals(Settings)
	Settings.set_music_volume(0.5)
	assert_signal_emitted(Settings, "volume_changed")

func test_save_and_load_settings_round_trip():
	Settings.music_volume = 0.35
	Settings.sfx_volume = 0.6
	Settings.save_settings(TEST_SETTINGS_PATH)

	Settings.music_volume = 1.0
	Settings.sfx_volume = 1.0
	Settings.load_settings(TEST_SETTINGS_PATH)

	assert_almost_eq(Settings.music_volume, 0.35, 0.01)
	assert_almost_eq(Settings.sfx_volume, 0.6, 0.01)

func test_load_settings_without_a_file_keeps_current_values():
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	Settings.music_volume = 0.42
	Settings.load_settings(TEST_SETTINGS_PATH)
	assert_almost_eq(Settings.music_volume, 0.42, 0.01, "sem arquivo, deveria manter o valor atual em vez de resetar")
