extends GutTest

## Cobre a correcao dos bugs de sobreposicao que o usuario reportou
## ("alguns [paineis] entram um por cima do outro"): fim de jogo aparecendo
## por cima de um overlay (Tecnologia/Diplomacia/Grimorio) ainda aberto, e
## botoes que deveriam ficar desabilitados depois do fim de jogo pra nao
## dar pra "fechar" a tela de vitoria/derrota sem querer.

var hud: Control
var _original_state
var _original_human_player: PlayerData
var _original_debug_mode: bool

func before_each():
	_original_state = GameManager.state
	_original_human_player = GameManager.human_player
	_original_debug_mode = GameManager.debug_mode
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	GameManager.state = _original_state
	GameManager.human_player = _original_human_player
	GameManager.debug_mode = _original_debug_mode
	GameManager.is_turn_processing = false

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
	assert_true(hud.debug_button.disabled)

func test_restart_reenables_overlay_buttons():
	hud._on_game_over(true)

	hud._on_restart_pressed()

	assert_false(hud.tech_button.disabled)
	assert_false(hud.diplomacy_button.disabled)
	assert_false(hud.grimoire_button.disabled)
	assert_false(hud.debug_button.disabled)
	assert_false(hud.game_over_panel.visible)

## Painel de Debug (pedido do usuario: "adicione opcoes debug onde eu
## posso tirar a fog do mapa e coisas assim") segue a MESMA regra de "so
## um overlay por vez" que Tecnologia/Diplomacia/Grimorio ja tinham.
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

## Pedido do usuario: "enquanto ta processando o botao fica ou
## indisponivel ou substituido por algo como processando" (ver
## GameManager.is_turn_processing/stagger_ai_turns) — cobre as DUAS coisas.
func test_end_turn_button_disabled_and_relabeled_while_turn_is_processing():
	GameManager.is_turn_processing = true

	hud._process(0.0)

	assert_true(hud.end_turn_button.disabled)
	assert_eq(hud.end_turn_button.text, hud.END_TURN_BUTTON_PROCESSING_TEXT)

	GameManager.is_turn_processing = false

	hud._process(0.0)

	assert_false(hud.end_turn_button.disabled)
	assert_eq(hud.end_turn_button.text, hud.END_TURN_BUTTON_TEXT)

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

## Pedido do usuario: "libere no modo debug, quando eu ativar, tudo
## liberado". Botao toggle (mesmo padrao do DebugRevealMapButton) — clique
## liga GameManager.debug_mode e atualiza o proprio texto/estado visual.
func test_debug_mode_button_toggles_debug_mode_and_updates_its_own_label():
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	assert_false(GameManager.debug_mode, "pre-condicao: modo debug comeca desligado")

	hud._on_debug_mode_pressed()

	assert_true(GameManager.debug_mode)
	assert_true(hud.debug_mode_button.button_pressed)
	assert_eq(hud.debug_mode_button.text, "Desativar Modo Debug")

	hud._on_debug_mode_pressed()

	assert_false(GameManager.debug_mode)
	assert_false(hud.debug_mode_button.button_pressed)

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
## Pedido do usuario, numa rodada seguinte: "ao clicar na cidade, essa area
## do menu [ActionBar] some, e fica so o menu da cidade ocupando a parte
## direita" — a cidade agora tambem faz o UnitPanel sumir (ele mora na
## MESMA area que o ActionBar, ver HUD.tscn), mesmo com a tropa
## guarnicionada la (_on_unit_selected roda ANTES, mesmo clique, e
## _on_tile_selected tem a ultima palavra — ver comentario dela).
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

	# Mesma ordem do clique real (SelectionManager.handle_world_click emite
	# unit_selected ANTES de tile_selected).
	hud._on_unit_selected(unit)
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud.tile_info_panel.visible, "cidade propria deveria continuar mostrando o painel mesmo com unidade guarnicionada")
	assert_false(hud.action_bar.visible, "ActionBar deveria sumir enquanto a cidade esta em foco")
	assert_false(hud.unit_panel.visible, "UnitPanel deveria sumir enquanto a cidade esta em foco, mesmo com a tropa guarnicionada")

	unit.queue_free()
	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Selecionar uma tropa (sem cidade no tile) nao deveria mexer no ActionBar
## — ele so some quando uma CIDADE propria esta em foco (pedido do
## usuario: "elas fiquem ali do lado do menu de opções", nao por cima
## dele).
func test_selecting_a_unit_without_a_city_keeps_the_action_bar_visible():
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

	hud._on_unit_selected(unit)
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud.action_bar.visible)
	assert_true(hud.unit_panel.visible)

	unit.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario: "ao clicar na cidade, essa area do menu some, e fica
## so o menu da cidade ocupando a parte direita" — o painel de cidade
## cresce ate a mesma borda direita do ActionBar (que fica escondido).
func test_selecting_own_city_expands_the_tile_info_panel_to_the_action_bars_edge():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_eq(hud.tile_info_panel.offset_right, hud.TILE_INFO_PANEL_EXPANDED_RIGHT)

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario: "apenas ao clicar em outra coisa fora da cidade, o
## menu da cidade some e volta o menu geral de tecnologia e etc" —
## clicar num tile SEM cidade depois de ter uma cidade selecionada traz o
## ActionBar de volta e volta o painel pra largura compacta.
func test_deselecting_the_city_brings_back_the_action_bar_and_compact_panel_width():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var city_coord := Vector2i(0, 0)
	var empty_coord := Vector2i(1, 0)
	hex_grid.tiles[city_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[empty_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(city_coord, human, "Capital")
	hud._on_tile_selected(city_coord, hex_grid.get_tile(city_coord))
	assert_false(hud.action_bar.visible, "pre-condicao: cidade selecionada deveria esconder o ActionBar")

	hud._on_unit_selected(null)
	hud._on_tile_selected(empty_coord, hex_grid.get_tile(empty_coord))

	assert_true(hud.action_bar.visible)
	assert_eq(hud.tile_info_panel.offset_right, hud.TILE_INFO_PANEL_COMPACT_RIGHT)

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario: "faca ser exibido somente tropas que voce pode fazer
## ao clicar na cidade" — botao de producao so aparece quando REALMENTE
## treinavel agora, nao mais desabilitado-com-tooltip. Cidade recem-fundada
## (sem nenhum predio/pesquisa): Guarda e Colonizador sempre visiveis;
## Homem de Armas (exige Quartel construido) fica escondido.
func test_city_production_row_only_shows_currently_trainable_kinds():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud._production_buttons["settler"].visible)
	assert_true(hud._production_buttons["warrior"].visible, "Guarda nao depende de predio/pesquisa, deveria sempre aparecer")
	assert_false(hud._production_buttons["men_at_arms"].visible, "Homem de Armas sem Quartel construido nao deveria aparecer")

	human.researched_techs["quartel"] = true
	city.buildings["barracks"] = true
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud._production_buttons["men_at_arms"].visible, "Homem de Armas com Quartel construido e pesquisado deveria aparecer")

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Regressao: "lá em cima não tá mostrando a comida" — o painel de cidade
## nunca exibia o estoque de comida (nem no sistema antigo, so acumulava
## silenciosamente). Agora que existe um teto de armazenamento de verdade
## (City.food_storage_cap()) e consumo por populacao, o jogador precisa ver
## os dois pra entender o ritmo de crescimento.
func test_city_panel_shows_food_storage_and_net_food_per_turn():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # comida 3
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	# populacao 1 * FOOD_CONSUMPTION_PER_POP (1) = 1 de consumo; 3 (tile) - 1 = +2/turno.
	assert_true("Comida: 0/%d (+2/turno)" % int(city.food_storage_cap()) in hud.tile_info_label.text, hud.tile_info_label.text)

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Regressao: rush_buy_button (Mercado, ver City.can_rush_buy()) so deveria
## aparecer com o Mercado construido NESTA cidade E algo em producao —
## pedido do usuario: "o mercado pode servir pra [dar um uso real pro
## ouro]"/"é uma boa, faça isso".
func test_rush_buy_button_visible_only_with_market_built_and_production_queued():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))
	assert_false(hud.rush_buy_button.visible, "sem Mercado nem producao, rush-buy nao deveria aparecer")

	city.buildings["market"] = true
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))
	assert_false(hud.rush_buy_button.visible, "cidade ociosa nao tem o que comprar, mesmo com Mercado construido")

	city.set_production("warrior")
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))
	assert_true(hud.rush_buy_button.visible, "com Mercado construido e algo em producao, rush-buy deveria aparecer")

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Clicar em rush_buy_button precisa de fato completar a producao e
## descontar o ouro na hora (sem esperar o proximo turno pra refletir na
## UI) — ver HUD._on_rush_buy_pressed()/City.rush_buy().
func test_pressing_rush_buy_button_completes_production_and_deducts_gold():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 1000.0
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")
	city.buildings["market"] = true
	city.set_production("warrior") # custa 15 producao

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))
	var expected_cost = city.rush_buy_cost()
	assert_gt(expected_cost, 0.0, "precondicao: deveria faltar producao pra comprar")

	hud._on_rush_buy_pressed()

	assert_almost_eq(city.stored_production, city.production_cost(), 0.01, "producao deveria estar completa apos o rush-buy")
	assert_almost_eq(human.gold, 1000.0 - expected_cost, 0.01, "ouro deveria ter sido descontado na hora")

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario, numa rodada seguinte: "as construções que precisam
## de pesquisa, só aparecem listadas na cidade quando nós de fato criamos
## a pesquisa, enquanto isso elas não aparecem no menu da cidade" — mesmo
## principio do teste acima (tropas), agora pros PREDIOS de treino. Depois
## que Celeiro/Oficina/Mercado tambem ganharam tech propria (pedido do
## usuario: "precisamos fazer pesquisa de cada uma dessas coisas, tudo deve
## ter pesquisa"), TODO predio com botao na UI hoje exige alguma tech — so
## a Torre dos Sabios continua sem tech nenhuma, mas ela nao tem botao
## proprio na UI ainda (fora do escopo desta rodada), entao nao ha mais um
## exemplo "sempre visivel" pra testar aqui.
func test_city_construction_row_hides_buildings_that_need_unresearched_tech():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_false(hud.build_granary_button.visible, "Celeiro sem a tech 'celeiro' pesquisada nao deveria aparecer")
	assert_false(hud.build_workshop_button.visible, "Oficina sem a tech 'oficina' pesquisada nao deveria aparecer")
	assert_false(hud.build_market_button.visible, "Mercado sem a tech 'mercado' pesquisada nao deveria aparecer")
	assert_false(hud.build_barracks_button.visible, "Quartel sem a tech 'quartel' pesquisada nao deveria aparecer")
	assert_false(hud.build_stable_button.visible, "Estabulo sem a tech 'estabulo' pesquisada nao deveria aparecer")

	human.researched_techs["celeiro"] = true
	human.researched_techs["oficina"] = true
	human.researched_techs["mercado"] = true
	human.researched_techs["quartel"] = true
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud.build_granary_button.visible, "Celeiro com a tech 'celeiro' pesquisada deveria aparecer")
	assert_true(hud.build_workshop_button.visible, "Oficina com a tech 'oficina' pesquisada deveria aparecer")
	assert_true(hud.build_market_button.visible, "Mercado com a tech 'mercado' pesquisada deveria aparecer")
	assert_true(hud.build_barracks_button.visible, "Quartel com a tech 'quartel' pesquisada deveria aparecer")
	assert_false(hud.build_stable_button.visible, "Estabulo ainda precisa da propria tech ('estabulo'), so 'quartel' nao basta")

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario, numa rodada seguinte: "quando uma construção ta
## sendo feita, tenha algum indicador de avanço... atualmente nao sabemos
## nem quanto demora... nem o progresso". Selecionar uma cidade agora
## mostra uma barra + texto com o item/PP acumulado/PP total.
func test_selecting_a_city_shows_production_progress():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")
	city.set_production("settler") # cidade nasce ociosa (""), ver City.gd — precisa de algo selecionado pra ter progresso
	city.stored_production = 5.0

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud.production_progress_label.visible)
	assert_true(hud.production_progress_bar.visible)
	assert_eq(hud.production_progress_bar.value, 5.0)
	assert_eq(hud.production_progress_bar.max_value, city.production_cost())
	assert_true(hud.production_progress_label.text.contains("5"), "texto deveria mostrar o PP acumulado")

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Sem cidade nenhuma no tile, o indicador de progresso nao deveria ficar
## "preso" mostrando o valor da ultima cidade selecionada.
func test_selecting_a_tile_without_a_city_hides_production_progress():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = hex_grid

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_false(hud.production_progress_label.visible)
	assert_false(hud.production_progress_bar.visible)

	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Cidade OCIOSA (production_item == "", ver comentario do campo em
## City.gd — pedido do usuario: "so produza outra [unidade] se voce for
## la e por pra produzir de novo") tambem nao deveria mostrar a barra de
## progresso — nao ha item nenhum em producao pra ter progresso.
func test_selecting_an_idle_city_hides_production_progress():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")
	city.set_production("")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_false(hud.production_progress_label.visible)
	assert_false(hud.production_progress_bar.visible)

	city.queue_free()
	hex_grid.queue_free()
	GameManager.hex_grid = original_hex_grid

## Pedido do usuario: "essa arvore de tecnologia humana que fizemos, eu
## quero que faca uma equivalente pra cada civilizacao... mudando o nome
## das tropas e aparencia das tropas e edificios em questao" — os botoes
## de producao (predio E tropa) devem mostrar o nome TEMATICO da raca do
## jogador humano, nao o nome cru de UnitDatabase/BuildingDatabase.
func test_production_buttons_use_the_race_themed_name_for_a_dwarf_city():
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var civ := CivilizationData.new()
	civ.race = "dwarf"
	var human := PlayerData.new(civ)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city = hex_grid.found_city(coord, human, "Capital")

	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_eq(hud._production_buttons["cavalry"].text, hud._unit_button_label("cavalry", "dwarf"))
	assert_eq(hud.build_barracks_button.text, hud._building_button_label("barracks", "dwarf"))
	assert_ne(hud._production_buttons["cavalry"].text, hud._unit_button_label("cavalry", "human"), "nome humano cru nao deveria aparecer pra um jogador anao")

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
