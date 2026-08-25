extends GutTest

## Cobre GameSetupScreen.gd — a tela de configuracao de nova partida.
## Bug relatado pelo usuario: "escolhi outro reino e iniciei com o reino
## humano, ao escolher uma civilizacao voce deve jogar como ela, portanto
## iniciando o jogo como ela" — a raca escolhida SEMPRE chegava certa em
## CivilizationData.race (ver test_game_manager.gd), mas o campo de nome
## do reino mostrava sempre o placeholder "Reino de Aldenmark" (nome
## humano, fixo no .tscn) nao importa qual raca estivesse selecionada, e
## GameManager caia no mesmo nome fixo se o jogador deixasse o campo em
## branco — dando a impressao de que o jogo comecou como humano mesmo
## escolhendo outra raca. Este arquivo cobre a metade da UI (o placeholder
## seguir a raca); a metade do fallback em GameManager.setup_players esta
## em test_game_manager.gd.

var screen: GameSetupScreen

func before_each():
	var scene: PackedScene = load("res://scenes/ui/GameSetupScreen.tscn")
	screen = scene.instantiate()
	add_child_autofree(screen)

func test_kingdom_name_placeholder_defaults_to_the_human_kingdom():
	assert_eq(screen.kingdom_name_edit.placeholder_text, GameSetupScreen.RACE_INFO.human.display_name)

func test_selecting_a_different_race_updates_the_kingdom_name_placeholder():
	screen._on_race_pressed("elf")

	assert_eq(screen.kingdom_name_edit.placeholder_text, GameSetupScreen.RACE_INFO.elf.display_name)
	assert_ne(screen.kingdom_name_edit.placeholder_text, GameSetupScreen.RACE_INFO.human.display_name)

func test_selecting_a_race_never_overwrites_a_kingdom_name_the_player_already_typed():
	screen.kingdom_name_edit.text = "Reino Personalizado"

	screen._on_race_pressed("dwarf")

	assert_eq(screen.kingdom_name_edit.text, "Reino Personalizado", "so o placeholder (texto fantasma) deveria mudar, nunca o texto de verdade ja digitado")

func test_reset_to_defaults_restores_the_human_kingdom_placeholder():
	screen._on_race_pressed("orc")
	assert_eq(screen.kingdom_name_edit.placeholder_text, GameSetupScreen.RACE_INFO.orc.display_name, "pre-condicao")

	screen.reset_to_defaults()

	assert_eq(screen.kingdom_name_edit.placeholder_text, GameSetupScreen.RACE_INFO.human.display_name)
