extends GutTest

## Cobre a correcao dos bugs de sobreposicao que o usuario reportou
## ("alguns [paineis] entram um por cima do outro"): fim de jogo aparecendo
## por cima de um overlay (Tecnologia/Diplomacia/Ajuda) ainda aberto, e
## botoes que deveriam ficar desabilitados depois do fim de jogo pra nao
## dar pra "fechar" a tela de vitoria/derrota sem querer.

var hud: Control
var _original_state
var _original_human_player: PlayerData

func before_each():
	_original_state = GameManager.state
	_original_human_player = GameManager.human_player
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	GameManager.state = _original_state
	GameManager.human_player = _original_human_player

func test_close_topmost_overlay_returns_false_when_nothing_is_open():
	assert_false(hud.close_topmost_overlay())

func test_close_topmost_overlay_closes_tech_panel():
	hud._on_tech_pressed()
	assert_true(hud.tech_panel.visible, "pre-condicao: painel deveria abrir")

	var closed = hud.close_topmost_overlay()

	assert_true(closed)
	assert_false(hud.tech_panel.visible)
	assert_false(hud.overlay_backdrop.visible, "fundo escurecido deveria sumir junto com o painel")

func test_close_topmost_overlay_closes_diplomacy_panel():
	hud._on_diplomacy_pressed()
	assert_true(hud.diplomacy_panel.visible)

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.diplomacy_panel.visible)

## Regressao: abrir Diplomacia enquanto Tecnologia esta aberta precisa
## fechar a primeira — essa regra ja existia antes, so confirmando que
## sobreviveu ao _show_overlay() novo.
func test_opening_a_second_overlay_closes_the_first_one():
	hud._on_tech_pressed()
	hud._on_diplomacy_pressed()

	assert_false(hud.tech_panel.visible, "abrir diplomacia deveria fechar tecnologia")
	assert_true(hud.diplomacy_panel.visible)

## Regressao principal reportada pelo usuario: painel de fim de jogo
## aparecendo POR CIMA de um overlay ainda aberto. _on_game_over() agora
## fecha qualquer overlay ANTES de mostrar o proprio.
func test_game_over_closes_any_open_overlay_panel():
	hud._on_tech_pressed()
	assert_true(hud.tech_panel.visible)

	hud._on_game_over(true)

	assert_false(hud.tech_panel.visible, "painel de tecnologia nao deveria continuar visivel por baixo do fim de jogo")
	assert_true(hud.game_over_panel.visible)
	assert_true(hud.overlay_backdrop.visible)

## Sem isso, o jogador podia clicar "Tecnologia" depois do fim de jogo e
## a tela de vitoria/derrota sumia sem nenhum jeito de trazer ela de volta
## (so o restart limpa esse estado).
func test_game_over_disables_buttons_that_would_dismiss_the_screen():
	hud._on_game_over(true)

	assert_true(hud.tech_button.disabled)
	assert_true(hud.diplomacy_button.disabled)
	assert_true(hud.grimoire_button.disabled)
	assert_true(hud.help_button.disabled)
	assert_true(hud.debug_button.disabled)

func test_restart_reenables_overlay_buttons():
	hud._on_game_over(true)

	hud._on_restart_pressed()

	assert_false(hud.tech_button.disabled)
	assert_false(hud.diplomacy_button.disabled)
	assert_false(hud.grimoire_button.disabled)
	assert_false(hud.help_button.disabled)
	assert_false(hud.debug_button.disabled)
	assert_false(hud.game_over_panel.visible)

## Painel de Debug (pedido do usuario: "adicione opcoes debug onde eu
## posso tirar a fog do mapa e coisas assim") segue a MESMA regra de "so
## um overlay por vez" que Ajuda/Tecnologia/Diplomacia ja tinham.
func test_close_topmost_overlay_closes_debug_panel():
	hud._on_debug_pressed()
	assert_true(hud.debug_panel.visible, "pre-condicao: painel deveria abrir")

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.debug_panel.visible)

func test_opening_debug_panel_closes_an_already_open_overlay():
	hud._on_tech_pressed()

	hud._on_debug_pressed()

	assert_false(hud.tech_panel.visible, "abrir debug deveria fechar tecnologia")
	assert_true(hud.debug_panel.visible)

func test_debug_button_only_visible_in_debug_builds():
	assert_eq(hud.debug_button.visible, OS.is_debug_build(), "botao de Debug nao deveria aparecer num export de release")

func test_debug_gold_button_adds_gold_to_human_player():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.human_player.gold = 50.0

	hud._on_debug_gold_pressed()

	assert_almost_eq(GameManager.human_player.gold, 150.0, 0.01)
	assert_eq(hud.gold_label.text, "Ouro: 150")

## Barra superior mostra "Mana: X (+Y)" (pedido do usuario, Ponto 3) —
## _refresh_stats() e a fonte unica desse texto, chamada tanto em troca de
## turno quanto apos qualquer EventBus.notify (ver _on_notify), o que
## cobre o saldo atualizar na hora depois de conjurar um feitico.
func test_refresh_stats_shows_mana_balance_and_income():
	var player = PlayerData.new(CivilizationData.new())
	player.mana = 42.0
	player.mana_income_per_turn = 7.0
	GameManager.human_player = player

	hud._refresh_stats()

	assert_eq(hud.mana_label.text, "Mana: 42 (+7)")

## Vencer/Perder Agora reaproveitam o MESMO sinal EventBus.game_over que o
## fim de jogo real usa — clicar um dos dois deveria fechar o painel de
## debug e mostrar a tela de fim de jogo, exatamente como um fim de jogo
## de verdade (ver _on_game_over ja testado acima).
func test_debug_win_button_shows_the_game_over_screen():
	GameManager.state = GameManager.GameState.PLAYING
	hud._on_debug_pressed()

	hud._on_debug_win_pressed()

	assert_true(hud.game_over_panel.visible)
	assert_false(hud.debug_panel.visible, "painel de debug deveria fechar junto com o fim de jogo forcado")

func test_debug_lose_button_shows_the_game_over_screen():
	GameManager.state = GameManager.GameState.PLAYING

	hud._on_debug_lose_pressed()

	assert_true(hud.game_over_panel.visible)

## Botoes de producao de unidade (pedido do usuario: "ler dinamicamente
## todas as unidades cadastradas em UnitDatabase.gd") sao criados em
## _build_production_buttons() (chamado por _ready()), um por
## UnitDatabase.PLAYER_TRAINABLE_KINDS — nenhum node fixo cadastrado a mao
## na cena.
func test_production_row_gets_one_button_per_trainable_kind():
	assert_eq(hud.production_row.get_child_count(), UnitDatabase.PLAYER_TRAINABLE_KINDS.size())

## Grimorio (pedido do usuario: "exiba os feiticos ativos no HUD do
## jogador... painel Grimório/Rituais") segue a MESMA regra de "so um
## overlay por vez" que Tecnologia/Diplomacia/Debug ja tinham.
func test_close_topmost_overlay_closes_grimoire_panel():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	hud._on_grimoire_pressed()
	assert_true(hud.grimoire_panel.visible, "pre-condicao: painel deveria abrir")

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.grimoire_panel.visible)

func test_opening_grimoire_closes_an_already_open_overlay():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	hud._on_tech_pressed()

	hud._on_grimoire_pressed()

	assert_false(hud.tech_panel.visible, "abrir grimorio deveria fechar tecnologia")
	assert_true(hud.grimoire_panel.visible)

func test_grimoire_panel_shows_a_placeholder_message_without_any_spell_unlocked():
	GameManager.human_player = PlayerData.new(CivilizationData.new())

	hud._on_grimoire_pressed()

	assert_eq(hud.grimoire_rows.get_child_count(), 1, "deveria mostrar uma linha unica explicando que nao ha ritual nenhum ainda")

func test_grimoire_panel_lists_one_row_per_unlocked_spell():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_techs["invocacao_espiritos"] = true # concede "Lança de Arcana"
	GameManager.human_player = player

	hud._on_grimoire_pressed()

	assert_eq(hud.grimoire_rows.get_child_count(), 1)

## Economia arcana (Ponto 3): o card do Grimorio mostra o custo de mana no
## nome e desabilita "Conjurar" quando o saldo nao alcanca, mesmo com
## cooldown zerado — pedido do usuario: "o botao Conjurar deve ficar
## desabilitado se o jogador nao tiver saldo de Mana suficiente". Chama
## _build_spell_row() direto (mesmo padrao ja usado por outros testes de
## HUD pra inspecionar nos internos sem precisar simular clique de mouse).

func test_grimoire_row_shows_the_mana_cost_next_to_the_spell_name():
	var player = PlayerData.new(CivilizationData.new())

	var row: Control = hud._build_spell_row("Lança de Arcana", player)
	var name_label: Label = row.get_child(0).get_child(0)

	assert_eq(name_label.text, "Lança de Arcana (25 mana)")

func test_grimoire_conjurar_button_disabled_without_enough_mana():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_techs["invocacao_espiritos"] = true
	player.mana = 10.0 # menos que os 25 exigidos, cooldown ja liberado

	var row: Control = hud._build_spell_row("Lança de Arcana", player)
	var cast_button: Button = row.get_child(0).get_child(1)

	assert_true(cast_button.disabled)
	assert_eq(cast_button.text, "Sem mana")

func test_grimoire_conjurar_button_enabled_with_enough_mana_and_no_cooldown():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_techs["invocacao_espiritos"] = true
	player.mana = 100.0

	var row: Control = hud._build_spell_row("Lança de Arcana", player)
	var cast_button: Button = row.get_child(0).get_child(1)

	assert_false(cast_button.disabled)
	assert_eq(cast_button.text, "Conjurar")

## Pedido do usuario: "ao clicar [numa unidade] ao invés de mostrar as
## características da célula se mostra as características da tropa" —
## selecionar uma unidade PROPRIA sem cidade no mesmo tile deveria
## esconder o painel generico de tile, deixando so o UnitPanel (ver
## _on_unit_selected) cuidar da exibicao.
func test_selecting_a_unit_without_a_city_hides_the_tile_info_panel():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), human, coord)
	hex_grid.units_by_coord[coord] = unit

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_false(hud.tile_info_panel.visible, "painel generico de tile nao deveria aparecer quando uma unidade propria (sem cidade) esta no tile")

	unit.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Cidade PROPRIA continua mostrando o painel de producao normalmente,
## mesmo com uma unidade guarnicionada em cima dela — gerenciar a cidade
## nao pode ficar inacessivel so porque ha uma unidade guardando ela.
func test_selecting_own_city_still_shows_tile_info_panel_even_with_a_garrisoned_unit():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), human, coord)
	hex_grid.units_by_coord[coord] = unit

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud.tile_info_panel.visible, "cidade propria deveria continuar mostrando o painel mesmo com unidade guarnicionada")

	unit.queue_free()
	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Fortificar/Explorar refletidos no painel de unidade (pedido do usuario:
## "as opções... mover, fortificar e explorar") — os botoes toggle
## (FortifyButton/ExploreButton) precisam mostrar o estado REAL da
## unidade ao selecionar, nao ficar sempre "nao pressionado".
func test_selecting_a_fortified_unit_shows_the_fortify_button_pressed():
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), PlayerData.new(CivilizationData.new()), Vector2i(0, 0))
	unit.fortified = true

	hud._on_unit_selected(unit)

	assert_true(hud.fortify_button.button_pressed)
	assert_false(hud.explore_button.button_pressed)
	unit.queue_free()

func test_selecting_an_exploring_unit_shows_the_explore_button_pressed():
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), PlayerData.new(CivilizationData.new()), Vector2i(0, 0))
	unit.exploring = true

	hud._on_unit_selected(unit)

	assert_true(hud.explore_button.button_pressed)
	assert_false(hud.fortify_button.button_pressed)
	unit.queue_free()
