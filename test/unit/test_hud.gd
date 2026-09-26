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
var _original_hex_grid: HexGrid # Roadmap "Fase F" F5 -- so os testes de VictoryPanel tocam nisso; salvar/restaurar aqui evita vazar um HexGrid ja liberado (queue_free) pros testes seguintes do mesmo arquivo
var _original_rival_players: Array[PlayerData]
var _original_players: Array[PlayerData]
var _original_world_events: Array[WorldEvent]
var _original_world_event_next_id: int

func before_each():
	_original_state = GameManager.state
	_original_human_player = GameManager.human_player
	_original_debug_mode = GameManager.debug_mode
	_original_hex_grid = GameManager.hex_grid
	_original_rival_players = GameManager.rival_players
	_original_players = GameManager.players
	_original_world_events = WorldEventManager.active_events
	_original_world_event_next_id = WorldEventManager._next_event_id
	WorldEventManager.active_events = []
	WorldEventManager._next_event_id = 0
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child_autofree(hud)

func after_each():
	GameManager.state = _original_state
	GameManager.human_player = _original_human_player
	GameManager.debug_mode = _original_debug_mode
	GameManager.hex_grid = _original_hex_grid
	GameManager.rival_players = _original_rival_players
	GameManager.players = _original_players
	GameManager.is_turn_processing = false
	WorldEventManager.active_events = _original_world_events
	WorldEventManager._next_event_id = _original_world_event_next_id

func test_close_topmost_overlay_returns_false_when_nothing_is_open():
	assert_false(hud.close_topmost_overlay())

func test_close_topmost_overlay_closes_diplomacy_panel():
	hud._on_diplomacy_pressed()
	assert_true(hud.diplomacy_panel.visible)

	assert_true(hud.close_topmost_overlay())
	assert_false(hud.diplomacy_panel.visible)

## Regressao: abrir Diplomacia enquanto Tecnologia esta aberta precisa
## fechar a primeira — essa regra ja existia antes, so confirmando que
## sobreviveu ao _show_overlay() novo.
func test_opening_a_second_overlay_closes_the_first_one():
	hud._on_research_pressed()
	hud._on_diplomacy_pressed()

	assert_false(hud.v2_research_panel.visible, "abrir diplomacia deveria fechar a pesquisa")
	assert_true(hud.diplomacy_panel.visible)

## Roadmap "Fase F" F1/F2/F5 -- painel de progresso de vitoria, mesmo
## padrao de overlay "so um por vez" de Tecnologia/Diplomacia acima.

func test_victory_panel_opens_and_closes():
	assert_false(hud.victory_panel.visible)

	hud._on_victory_pressed()
	assert_true(hud.victory_panel.visible)
	assert_true(hud.overlay_backdrop.visible)

	hud._on_victory_pressed()
	assert_false(hud.victory_panel.visible)

func test_opening_victory_panel_closes_diplomacy():
	hud._on_diplomacy_pressed()
	assert_true(hud.diplomacy_panel.visible)

	hud._on_victory_pressed()

	assert_false(hud.diplomacy_panel.visible)
	assert_true(hud.victory_panel.visible)

## format_victory_progress_percentage e PURA (nenhuma dependencia de
## cena/PlayerData/HexGrid) -- testada direto, sem precisar de
## _refresh_victory_panel nem GameManager nenhum. Clampa e arredonda:
## nunca mostra >100% nem negativo mesmo com entrada fora de [0,1].
func test_format_victory_progress_percentage_at_zero_intermediate_and_full():
	assert_eq(hud.format_victory_progress_percentage(0.0), "0%")
	assert_eq(hud.format_victory_progress_percentage(0.5), "50%")
	assert_eq(hud.format_victory_progress_percentage(1.0), "100%")

func test_format_victory_progress_percentage_rounds_and_clamps():
	assert_eq(hud.format_victory_progress_percentage(0.336), "34%", "arredonda pro inteiro mais proximo")
	assert_eq(hud.format_victory_progress_percentage(1.5), "100%", "nunca mostra mais que 100% mesmo com entrada fora do contrato")
	assert_eq(hud.format_victory_progress_percentage(-0.2), "0%", "nunca mostra negativo")

## Fase 25: o painel mostra só as três vitórias ativas, sempre nesta ordem (mesma precedência de
## GameManager.check_victories): Dominação, Supremacia Militar, Transcendência -- cada uma com
## título, barra de progresso e detalhe. Nenhuma barra de vitória V1 (Territorial/Arcana).
func test_victory_panel_builds_the_three_active_victories_with_correct_values():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	var alive_rival = PlayerData.new(CivilizationData.new())
	alive_rival.units.append(null)
	var eliminated_rival = PlayerData.new(CivilizationData.new()) # sem unidade/cidade -- ja eliminado
	GameManager.human_player = human
	GameManager.rival_players = [alive_rival, eliminated_rival]

	hud._refresh_victory_panel()

	assert_eq(hud.victory_rows.get_child_count(), 9, "3 vitórias x (título + barra + detalhe)")
	assert_eq(hud.victory_rows.get_child(0).text, "Dominação")
	var dominance_row: HBoxContainer = hud.victory_rows.get_child(1)
	assert_eq(dominance_row.get_child(2).text, "50%", "1 de 2 rivais eliminados")
	assert_almost_eq(dominance_row.get_child(1).value, 50.0, 0.01)
	assert_eq(hud.victory_rows.get_child(3).text, "Supremacia Militar")
	assert_eq(hud.victory_rows.get_child(6).text, "Transcendência")
	for child in hud.victory_rows.get_children():
		if child is Label:
			for legacy in ["Territorial", "Ascensão Arcana", "Ritual do Nódulo", "V1", "V2"]:
				assert_false(child.text.contains(legacy), "%s em '%s'" % [legacy, child.text])

	hex_grid.queue_free()

## NAO testa "refresh 2x sem passar frame nenhum": _refresh_victory_panel
## usa queue_free() (MESMO padrao de _refresh_diplomacy_panel, ver
## comentario la) pra limpar linhas antigas, que so libera de verdade no
## proximo frame -- chamar 2x seguidas SEM deixar um frame passar
## inflaria a contagem por construcao, nao por bug (uso real sempre tem
## uma interacao do jogador entre dois refreshes, atravessando frames).
func test_victory_panel_row_count_matches_player_count_after_refresh():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	GameManager.human_player = PlayerData.new(CivilizationData.new())
	GameManager.rival_players = []

	hud._refresh_victory_panel()

	assert_eq(hud.victory_rows.get_child_count(), 9, "a estrutura não depende do número de jogadores")
	hex_grid.queue_free()

## Roadmap "Fase F" F6 -- tela de resultado final: titulo + resumo fixo +
## snapshot CONGELADO das 3 progressões de todos os jogadores.

func test_format_victory_title_for_each_type():
	var winner = PlayerData.new(CivilizationData.new())
	winner.civ.civ_name = "Anões"
	assert_eq(hud.format_victory_title(winner, VictoryConditions.VICTORY_TYPE_DOMINANCE), "Vitória por Dominação — Anões")
	assert_eq(hud.format_victory_title(winner, V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY), "Vitória por Supremacia Militar — Anões")
	assert_eq(hud.format_victory_title(winner, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE), "Vitória por Transcendência — Anões")

## `winner` pode ser null (debug_force_game_over(false) sem nenhum rival
## existir, ver GameManager.gd) -- nao deveria quebrar nem mostrar um
## veredito de vitoria real.
func test_format_victory_title_handles_debug_and_null_winner():
	assert_eq(hud.format_victory_title(null, VictoryConditions.VICTORY_TYPE_DEBUG), "Fim de jogo forçado (Debug)")
	assert_eq(hud.format_victory_title(null, VictoryConditions.VICTORY_TYPE_DOMINANCE), "Fim de jogo")

## Resumo FIXO por tipo; tipos de vitória V1 (removidos na Fase 25) não têm resumo.
func test_format_victory_summary_covers_only_the_active_victories():
	assert_eq(hud.format_victory_summary(VictoryConditions.VICTORY_TYPE_DOMINANCE), "Eliminou todos os reinos rivais.")
	assert_ne(hud.format_victory_summary(V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY), "")
	assert_ne(hud.format_victory_summary(V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE), "")
	assert_eq(hud.format_victory_summary("territorial"), "")
	assert_eq(hud.format_victory_summary("arcane"), "")

func test_on_victory_achieved_populates_title_summary_and_snapshot():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	GameManager.human_player = human
	GameManager.rival_players = []

	hud._on_victory_achieved(human, VictoryConditions.VICTORY_TYPE_DOMINANCE)

	assert_eq(hud.game_over_title_label.text, "Vitória por Dominação — Reino de Teste")
	assert_eq(hud.game_over_summary_label.text, "Eliminou todos os reinos rivais.")
	assert_eq(hud.game_over_snapshot_rows.get_child_count(), 9, "mesmas 3 vitórias do painel ao vivo")
	hex_grid.queue_free()

## O CONTRATO mais importante desta fatia (pedido explicito do usuario):
## a tela de resultado precisa continuar mostrando os valores do MOMENTO
## da vitoria, mesmo que o jogo mude depois. _on_victory_achieved congela
## o snapshot em Labels/ProgressBars ESTATICOS (game_over_snapshot_rows)
## -- diferente do painel "Vitória" ao vivo (_refresh_victory_panel), que
## le VictoryConditions de novo toda vez que e chamado.
func test_game_over_snapshot_does_not_change_after_later_state_mutation_or_live_panel_refresh():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new()) # sem unidade/cidade -- 1 de 1 rival ja eliminado = 100% dominancia
	GameManager.human_player = human
	GameManager.rival_players = [rival]

	hud._on_victory_achieved(human, VictoryConditions.VICTORY_TYPE_DOMINANCE)
	var frozen_dominance_row: HBoxContainer = hud.game_over_snapshot_rows.get_child(1)
	assert_eq(frozen_dominance_row.get_child(2).text, "100%", "pre-condicao: 1 de 1 rival eliminado")

	# Estado muda DEPOIS da vitoria (ex.: algum callback tardio antes da
	# troca de cena) -- um rival novo e vivo derrubaria a dominancia do
	# humano pra 50% (1 de 2 eliminados) SE recalculada.
	var new_rival = PlayerData.new(CivilizationData.new())
	new_rival.units.append(null)
	GameManager.rival_players = [rival, new_rival]

	# O painel AO VIVO reflete a mudanca (prova que a mudanca de estado e
	# real, nao um erro de teste)...
	hud._refresh_victory_panel()
	var live_dominance_row: HBoxContainer = hud.victory_rows.get_child(1)
	assert_ne(live_dominance_row.get_child(2).text, "100%", "pre-condicao: o painel AO VIVO deveria refletir o novo rival")

	# ...mas o snapshot CONGELADO da tela de resultado NAO muda.
	assert_eq(frozen_dominance_row.get_child(2).text, "100%", "snapshot de fim de jogo nao deveria mudar depois da vitoria")
	hex_grid.queue_free()

## Regressao principal reportada pelo usuario: painel de fim de jogo
## aparecendo POR CIMA de um overlay ainda aberto. _on_game_over() agora
## fecha qualquer overlay ANTES de mostrar o proprio.
func test_game_over_closes_any_open_overlay_panel():
	hud._on_research_pressed()
	assert_true(hud.v2_research_panel.visible)

	hud._on_game_over(true)

	assert_false(hud.v2_research_panel.visible, "painel de pesquisa nao deveria continuar visivel por baixo do fim de jogo")
	assert_true(hud.game_over_panel.visible)
	assert_true(hud.overlay_backdrop.visible)

## Sem isso, o jogador podia clicar "Tecnologia" depois do fim de jogo e
## a tela de vitoria/derrota sumia sem nenhum jeito de trazer ela de volta
## (so o restart limpa esse estado).
func test_game_over_disables_buttons_that_would_dismiss_the_screen():
	hud._on_game_over(true)

	assert_true(hud.research_button.disabled)
	assert_true(hud.diplomacy_button.disabled)

func test_restart_reenables_overlay_buttons():
	hud._on_game_over(true)

	hud._on_restart_pressed()

	assert_false(hud.research_button.disabled)
	assert_false(hud.diplomacy_button.disabled)
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
	hud._on_research_pressed()

	hud._on_debug_pressed()

	assert_false(hud.v2_research_panel.visible, "abrir debug deveria fechar tecnologia")
	assert_true(hud.debug_panel.visible)

## Roadmap "reorganizar barra lateral": o botao que ABRE isto saiu da HUD
## e foi pro menu de pausa (ver test_pause_menu.gd
## test_debug_button_only_visible_in_debug_builds) — HUD.gd so guarda
## _on_debug_pressed() e o painel em si agora, testados acima.

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
	# Aetherlands V2, Fase 14: o rótulo passou a mostrar a renda V2 também (§71 do pedido,
	# "Ouro: 112 (+8)") -- este jogador não tem cidade nenhuma, então a renda é 0.
	assert_eq(hud.gold_label.text, "Ouro: 150 (+0)")

## Barra superior mostra "Mana: X (+Y)" (pedido do usuario, Ponto 3) —
## _refresh_stats() e a fonte unica desse texto, chamada tanto em troca de
## turno quanto apos qualquer EventBus.notify (ver _on_notify), o que
## cobre o saldo atualizar na hora depois de conjurar um feitico.
func test_refresh_stats_shows_mana_balance_and_income():
	var player = PlayerData.new(CivilizationData.new())
	player.mana = 42.0
	GameManager.human_player = player

	hud._refresh_stats()

	# Fase 25: a renda exibida é a da economia V2 (derivada), não um campo gravado.
	assert_eq(hud.mana_label.text, "Mana: 42 (+%d)" % int(V2EconomyRuntime.player_mana_income(player)))

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

## Economia arcana (Ponto 3): o card do Grimorio mostra o custo de mana no
## nome e desabilita "Conjurar" quando o saldo nao alcanca, mesmo com
## cooldown zerado — pedido do usuario: "o botao Conjurar deve ficar
## desabilitado se o jogador nao tiver saldo de Mana suficiente". Chama
## _build_spell_row() direto (mesmo padrao ja usado por outros testes de
## HUD pra inspecionar nos internos sem precisar simular clique de mouse).

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

## Botão de produção só aparece quando REALMENTE treinável. Fase 25: cidade recém-fundada mostra
## só o Colonizador; tropa V1 nem tem botão; tropa V2 aparece com prédio + pesquisa.
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
	for kind in ["warrior", "men_at_arms", "archer", "cavalry"]:
		assert_false(hud._production_buttons.has(kind), "sem botão de produção V1: %s" % kind)
	assert_false(hud._production_buttons["v2_unit_shieldbearer"].visible)

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

## --- Roadmap "Fase Macro" 5B.2: prompt minimo de Preparation --------------
## (docs/DRAGON_EVENT_DESIGN.md: "Não precisa ser bonita. Precisa funcionar.")

func test_format_world_event_prompt_for_dragon_names_target_and_turns_left():
	var target := PlayerData.new(CivilizationData.new())
	target.civ.civ_name = "Reino dos Anões"
	var players: Array[PlayerData] = [target]
	var event := DragonEvent.new()
	event.target_civ_index = 0
	event.turn_deadline = 13

	var text: String = hud.format_world_event_prompt(event, players, 10)

	assert_true("Reino dos Anões" in text)
	assert_true("3 turno" in text, "faltam 13-10=3 turnos")

func test_format_world_event_prompt_handles_no_target_locked_yet():
	var event := DragonEvent.new() # target_civ_index continua -1
	var no_players: Array[PlayerData] = []
	var text: String = hud.format_world_event_prompt(event, no_players, 10)
	assert_true("uma civilização desconhecida" in text)

func test_format_world_event_prompt_never_shows_a_negative_turn_count():
	var event := DragonEvent.new()
	event.turn_deadline = 5
	var no_players: Array[PlayerData] = []
	var text: String = hud.format_world_event_prompt(event, no_players, 10) # turno atual JA passou do prazo
	assert_true("0 turno" in text, "nunca deveria mostrar contagem negativa")

func test_world_event_panel_is_hidden_by_default():
	assert_false(hud.world_event_panel.visible)

func test_world_event_panel_appears_when_a_dragon_is_in_preparation():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)

	hud._refresh_world_event_panel()

	assert_true(hud.world_event_panel.visible)

func test_world_event_panel_hides_once_the_human_has_already_decided():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	event.participants[0] = {"decision": true}
	WorldEventManager.register_event(event)

	hud._refresh_world_event_panel()

	assert_false(hud.world_event_panel.visible)

func test_world_event_panel_hides_when_no_event_is_in_preparation():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]

	hud._refresh_world_event_panel()

	assert_false(hud.world_event_panel.visible)

func test_pressing_participate_records_the_decision_and_hides_the_panel():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)
	hud._refresh_world_event_panel()
	assert_true(hud.world_event_panel.visible, "pre-condicao")

	hud._on_world_event_participate_pressed()

	assert_eq(event.participants.get(0), {"decision": true})
	assert_false(hud.world_event_panel.visible)

func test_pressing_decline_records_the_decision_and_hides_the_panel():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)
	hud._refresh_world_event_panel()

	hud._on_world_event_decline_pressed()

	assert_eq(event.participants.get(0), {"decision": false})
	assert_false(hud.world_event_panel.visible)

## --- Roadmap "Fase Macro" 5B.3-C: Dragon Event UX ---------------------------
## Pedido explicito do usuario apos o playtest visual de 5B.3-B: o Dragao ja
## funciona como entidade de jogo, mas o EVENTO ainda nao se comunicava
## como evento de jogo (aviso pequeno -> aviso pequeno -> modal, sem
## anuncio proprio nem acompanhamento persistente). Cobre: modal bloqueante
## de Announced (uma vez, exige confirmacao), Tracker persistente
## (Preparation/Active/Resolution) e Boss Bar (so' Active).

func _make_hud_test_hex_grid() -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for x in range(-2, 3):
		for y in range(-2, 3):
			grid.tiles[Vector2i(x, y)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return grid

func test_format_world_event_title_for_dragon():
	assert_eq(hud.format_world_event_title(DragonEvent.new()), "A Caçada ao Dragão")

func test_format_world_event_title_generic_fallback():
	assert_eq(hud.format_world_event_title(WorldEvent.new()), "Evento Mundial")

func test_format_world_event_prompt_explains_what_participating_means():
	var target := PlayerData.new(CivilizationData.new())
	target.civ.civ_name = "Reino dos Anões"
	var players: Array[PlayerData] = [target]
	var event := DragonEvent.new()
	event.target_civ_index = 0

	var text: String = hud.format_world_event_prompt(event, players, 10)

	assert_true("Guilda" in text, "precisa explicar QUEM esta convocando, nao so perguntar sim/nao")
	assert_true("recompensas" in text, "precisa sinalizar que ha uma consequencia de participar")
	assert_false("tropas de aventureiros" in text, "nao deveria prometer uma recompensa CONCRETA ainda -- isso e' escopo de 5B.4, ainda nao decidido")

## --- Modal bloqueante de Announced -------------------------------------

func test_dragon_announcement_panel_is_hidden_by_default():
	assert_false(hud.dragon_announcement_panel.visible)

func test_dragon_announcement_panel_shows_when_a_dragon_event_becomes_announced():
	var event := DragonEvent.new()

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED)

	assert_true(hud.dragon_announcement_panel.visible)
	assert_true(hud.overlay_backdrop.visible, "deveria ser um modal bloqueante, igual Tech/Diplomacia/Vitoria")
	assert_true(hud.dragon_announcement_text_label.text.length() > 0)

## Pedido explicito do usuario: "não misturar esse anúncio com o canal
## visual usado para 'Goblin eliminado'... o objetivo é simplesmente
## garantir: 'Pare. Isso é importante.'"
func test_dragon_announcement_panel_never_promises_concrete_rewards():
	var event := DragonEvent.new()
	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED)
	assert_false("recompensa" in hud.dragon_announcement_text_label.text.to_lower(), "o alerta e' so' o rumor -- o chamado pra participar (WorldEventPanel) e' quem fala de recompensa")

func test_dragon_announcement_panel_does_not_show_for_other_phase_transitions():
	var event := DragonEvent.new()

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ANNOUNCED, WorldEvent.PHASE_PREPARATION)

	assert_false(hud.dragon_announcement_panel.visible)

func test_dragon_announcement_continue_button_closes_the_modal():
	var event := DragonEvent.new()
	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED)
	assert_true(hud.dragon_announcement_panel.visible, "pre-condicao")

	hud._on_dragon_announcement_continue_pressed()

	assert_false(hud.dragon_announcement_panel.visible)
	assert_false(hud.overlay_backdrop.visible)

func test_close_topmost_overlay_closes_the_dragon_announcement_panel():
	var event := DragonEvent.new()
	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_DORMANT, WorldEvent.PHASE_ANNOUNCED)

	var closed = hud.close_topmost_overlay()

	assert_true(closed)
	assert_false(hud.dragon_announcement_panel.visible)

## --- Modal bloqueante de Resolution (5B.3-G) -----------------------------
## Playtest revelou que o toast de 1-tick de _resolve_with_outcome era UX
## fraca demais pra um evento continental ("o jogador viu apenas um texto
## minusculo e interpretou como bug/desaparecimento"). Mesmo padrao MODAL
## bloqueante do anuncio acima, agora pro DESFECHO (defeated/devastated/
## no_target) -- disparado pela mesma transicao de fase, nunca mais um
## toast dedicado (ver test_dragon_event.gd, secao "5B.3-G: toast removido").

func test_dragon_resolution_panel_is_hidden_by_default():
	assert_false(hud.dragon_resolution_panel.visible)

func test_dragon_resolution_panel_shows_when_a_dragon_event_reaches_resolution():
	var event := DragonEvent.new()
	event.result = {"outcome": "defeated"}

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)

	assert_true(hud.dragon_resolution_panel.visible)
	assert_true(hud.overlay_backdrop.visible, "deveria ser um modal bloqueante, igual o anuncio de Announced")
	assert_true(hud.dragon_resolution_title_label.text.length() > 0)
	assert_true(hud.dragon_resolution_text_label.text.length() > 0)

func test_dragon_resolution_panel_does_not_show_for_other_phase_transitions():
	var event := DragonEvent.new()

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_PREPARATION, WorldEvent.PHASE_ACTIVE)

	assert_false(hud.dragon_resolution_panel.visible)

func test_dragon_resolution_continue_button_closes_the_modal():
	var event := DragonEvent.new()
	event.result = {"outcome": "devastated"}
	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)
	assert_true(hud.dragon_resolution_panel.visible, "pre-condicao")

	hud._on_dragon_resolution_continue_pressed()

	assert_false(hud.dragon_resolution_panel.visible)
	assert_false(hud.overlay_backdrop.visible)

func test_close_topmost_overlay_closes_the_dragon_resolution_panel():
	var event := DragonEvent.new()
	event.result = {"outcome": "no_target"}
	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)

	var closed = hud.close_topmost_overlay()

	assert_true(closed)
	assert_false(hud.dragon_resolution_panel.visible)

## --- format_dragon_resolution_title/text (puras) -------------------------

func test_format_dragon_resolution_title_and_text_are_distinguishable_per_outcome():
	var outcomes := ["defeated", "devastated", "no_target"]
	for outcome in outcomes:
		assert_true(hud.format_dragon_resolution_title(outcome).length() > 0, "outcome '%s' precisa de um titulo" % outcome)
		assert_true(hud.format_dragon_resolution_text(outcome).length() > 0, "outcome '%s' precisa de um texto" % outcome)
	assert_ne(hud.format_dragon_resolution_title("defeated"), hud.format_dragon_resolution_title("devastated"))
	assert_ne(hud.format_dragon_resolution_title("defeated"), hud.format_dragon_resolution_title("no_target"))
	assert_ne(hud.format_dragon_resolution_title("devastated"), hud.format_dragon_resolution_title("no_target"))
	assert_ne(hud.format_dragon_resolution_text("defeated"), hud.format_dragon_resolution_text("devastated"))
	assert_ne(hud.format_dragon_resolution_text("defeated"), hud.format_dragon_resolution_text("no_target"))
	assert_ne(hud.format_dragon_resolution_text("devastated"), hud.format_dragon_resolution_text("no_target"))

## --- Roadmap "Dragon Event v1 fechado": ranking de dano ------------------
## "Ranking de dano... transforma o Dragão numa atividade competitiva entre
## civilizações... você pode participar do mesmo evento, mas não significa
## que todos recebem a mesma glória."

func test_format_dragon_damage_ranking_sorts_descending_with_medals():
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Império Humano"
	var elf = PlayerData.new(CivilizationData.new())
	elf.civ.civ_name = "Reino Élfico"
	var dwarf = PlayerData.new(CivilizationData.new())
	dwarf.civ.civ_name = "Clãs Anões"
	var players: Array[PlayerData] = [human, elf, dwarf]
	var damage_by_civ := {0: 37.0, 1: 29.0, 2: 18.0}

	var lines: Array = hud.format_dragon_damage_ranking(damage_by_civ, players)

	assert_eq(lines.size(), 3)
	assert_eq(lines[0], "🥇 Império Humano — 37 de dano")
	assert_eq(lines[1], "🥈 Reino Élfico — 29 de dano")
	assert_eq(lines[2], "🥉 Clãs Anões — 18 de dano")

func test_format_dragon_damage_ranking_uses_ordinal_after_the_top_three():
	var players: Array[PlayerData] = []
	var damage_by_civ := {}
	for i in range(4):
		var p := PlayerData.new(CivilizationData.new())
		p.civ.civ_name = "Civ %d" % i
		players.append(p)
		damage_by_civ[i] = float(10 - i) # 10, 9, 8, 7 -- ja em ordem decrescente

	var lines: Array = hud.format_dragon_damage_ranking(damage_by_civ, players)

	assert_eq(lines.size(), 4)
	assert_true(lines[3].begins_with("4º "), "a partir do 4o lugar, sem medalha -- so' '4º', '5º' etc")

func test_format_dragon_damage_ranking_excludes_civs_with_zero_or_no_damage():
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Humano"
	var elf = PlayerData.new(CivilizationData.new())
	elf.civ.civ_name = "Elfo"
	var players: Array[PlayerData] = [human, elf]
	var damage_by_civ := {0: 15.0, 1: 0.0} # elfo nunca acertou um golpe de verdade

	var lines: Array = hud.format_dragon_damage_ranking(damage_by_civ, players)

	assert_eq(lines.size(), 1, "'se dá 0, não conta' -- pedido explicito do usuario")
	assert_true(lines[0].contains("Humano"))

func test_format_dragon_damage_ranking_is_empty_when_no_civ_dealt_damage():
	var players: Array[PlayerData] = [PlayerData.new(CivilizationData.new())]
	assert_true(hud.format_dragon_damage_ranking({}, players).is_empty())

## --- Modal de resolucao mostra o ranking de verdade -----------------------

func test_dragon_resolution_panel_shows_ranking_rows_and_header_when_there_is_damage():
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	var _original_players: Array[PlayerData] = GameManager.players
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.result = {"outcome": "defeated"}
	event.damage_by_civ = {0: 42.0}

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)

	assert_true(hud.dragon_resolution_ranking_header_label.visible)
	assert_eq(hud.dragon_resolution_ranking_box.get_child_count(), 1)
	GameManager.players = _original_players

func test_dragon_resolution_panel_hides_ranking_header_without_damage():
	var _original_players: Array[PlayerData] = GameManager.players
	GameManager.players = []
	var event := DragonEvent.new()
	event.result = {"outcome": "no_target"}

	hud._on_world_event_phase_changed(event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)

	assert_false(hud.dragon_resolution_ranking_header_label.visible)
	assert_eq(hud.dragon_resolution_ranking_box.get_child_count(), 0)
	GameManager.players = _original_players

func test_dragon_resolution_panel_clears_old_ranking_rows_on_a_new_resolution():
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	var _original_players: Array[PlayerData] = GameManager.players
	GameManager.players = [human]
	var first_event := DragonEvent.new()
	first_event.result = {"outcome": "defeated"}
	first_event.damage_by_civ = {0: 10.0}
	hud._on_world_event_phase_changed(first_event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)
	assert_eq(hud.dragon_resolution_ranking_box.get_child_count(), 1, "pre-condicao")

	var second_event := DragonEvent.new()
	second_event.result = {"outcome": "no_target"}
	hud._on_world_event_phase_changed(second_event, WorldEvent.PHASE_ACTIVE, WorldEvent.PHASE_RESOLUTION)

	assert_eq(hud.dragon_resolution_ranking_box.get_child_count(), 0, "linhas do evento ANTERIOR nao deveriam sobreviver pro proximo")
	GameManager.players = _original_players

## --- Event Tracker (format_world_event_tracker) -------------------------

func test_format_world_event_tracker_is_empty_outside_preparation_active_resolution():
	var no_players: Array[PlayerData] = []
	assert_true(hud.format_world_event_tracker(DragonEvent.new(), no_players).is_empty(), "Dormant")
	var announced := DragonEvent.new()
	announced.phase = WorldEvent.PHASE_ANNOUNCED
	assert_true(hud.format_world_event_tracker(announced, no_players).is_empty(), "Announced -- o modal ja cobre este momento")
	var completed := DragonEvent.new()
	completed.phase = WorldEvent.PHASE_COMPLETED
	assert_true(hud.format_world_event_tracker(completed, no_players).is_empty(), "Completed -- pedido explicito: 'Tracker desaparece'")

func test_format_world_event_tracker_during_preparation_names_the_target_civ():
	var target := PlayerData.new(CivilizationData.new())
	target.civ.civ_name = "Reino dos Anões"
	var players: Array[PlayerData] = [target]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	event.target_civ_index = 0

	var info: Dictionary = hud.format_world_event_tracker(event, players)

	assert_eq(info.status, "Preparação")
	assert_eq(info.target, "Reino dos Anões")

func test_format_world_event_tracker_during_active_names_the_current_target_city():
	var grid := _make_hud_test_hex_grid()
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(1, 0), player, "Capital Anã")
	var players: Array[PlayerData] = [player]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")

	var info: Dictionary = hud.format_world_event_tracker(event, players)

	assert_eq(info.status, "Em atividade")
	assert_eq(info.objective, "Derrote o Dragão.")
	assert_eq(info.target, city.city_name)
	grid.queue_free()

func test_format_world_event_tracker_during_active_is_safe_without_a_spawned_unit_yet():
	var no_players: Array[PlayerData] = []
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE # dragon_unit continua null (raro/defensivo)

	var info: Dictionary = hud.format_world_event_tracker(event, no_players)

	assert_eq(info.target, "—")

func test_format_world_event_tracker_during_resolution_names_the_outcome():
	var no_players: Array[PlayerData] = []
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_RESOLUTION
	event.result = {"outcome": "devastated"}

	var info: Dictionary = hud.format_world_event_tracker(event, no_players)

	assert_eq(info.status, "Devastação total.")
	assert_eq(info.objective, "")

func test_refresh_world_event_tracker_shows_and_hides_with_the_event():
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	WorldEventManager.register_event(event)

	hud._refresh_world_event_tracker()
	assert_true(hud.world_event_tracker.visible)
	assert_eq(hud.world_event_tracker_status_label.text, "Status: Preparação")

	WorldEventManager.active_events.clear()
	hud._refresh_world_event_tracker()
	assert_false(hud.world_event_tracker.visible)

## --- Dragon Boss Bar (format_dragon_boss_bar) ---------------------------

func test_format_dragon_boss_bar_is_empty_outside_active():
	var no_players: Array[PlayerData] = []
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_PREPARATION
	assert_true(hud.format_dragon_boss_bar(event, no_players).is_empty())

func test_format_dragon_boss_bar_is_empty_without_a_spawned_unit_yet():
	var no_players: Array[PlayerData] = []
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	assert_true(hud.format_dragon_boss_bar(event, no_players).is_empty())

func test_format_dragon_boss_bar_reports_hp_and_target_during_active():
	var grid := _make_hud_test_hex_grid()
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(1, 0), player, "Capital Anã")
	var players: Array[PlayerData] = [player]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.target_civ_index = 0
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	event.dragon_unit.hp = 32.0

	var info: Dictionary = hud.format_dragon_boss_bar(event, players)

	assert_eq(info.hp, 32.0)
	assert_eq(info.max_hp, event.dragon_unit.unit_data.max_hp)
	assert_eq(info.target, city.city_name)
	grid.queue_free()

func test_refresh_dragon_boss_bar_shows_hp_and_hides_when_the_dragon_is_gone():
	var grid := _make_hud_test_hex_grid()
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.players = [human]
	var event := DragonEvent.new()
	event.phase = WorldEvent.PHASE_ACTIVE
	event.dragon_unit = grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	WorldEventManager.register_event(event)

	hud._refresh_dragon_boss_bar()
	assert_true(hud.dragon_boss_bar.visible)
	assert_eq(hud.dragon_boss_bar_health_bar.value, event.dragon_unit.hp)

	# Resolution/Completed remove a Unit -- a Boss Bar precisa sumir junto
	# (pedido do usuario: "boss bar desaparece quando Dragon é removido").
	grid.remove_unit(event.dragon_unit)
	event.dragon_unit = null
	event.phase = WorldEvent.PHASE_COMPLETED
	hud._refresh_dragon_boss_bar()
	assert_false(hud.dragon_boss_bar.visible)
	grid.queue_free()

## --- Reconstrucao apos save/load -----------------------------------------
## "save/load mantém estado do evento e UI reconstrói corretamente" -- as
## funcoes de formatacao sao puras (nunca dependem de COMO o estado foi
## populado), entao um evento reconstruido via from_save_dict() precisa
## produzir exatamente a mesma leitura de Tracker/Boss Bar que um evento
## vivo no mesmo estado.
func test_tracker_and_boss_bar_reflect_an_event_reconstructed_from_save_dict():
	var grid := _make_hud_test_hex_grid()
	var player := PlayerData.new(CivilizationData.new())
	var city := grid.found_city(Vector2i(1, 0), player, "Capital Reconstruída")
	var players: Array[PlayerData] = [player]
	var live_unit := grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	live_unit.hp = 20.0

	var original := DragonEvent.new()
	original.phase = WorldEvent.PHASE_ACTIVE
	original.target_civ_index = 0
	original.spawn_coord = Vector2i(0, 0)
	var saved := original.to_save_dict()

	var loaded := DragonEvent.new()
	loaded.from_save_dict(saved)
	loaded.relink_unit(grid) # mesmo passo que SaveManager.load_game() chama

	var tracker_info: Dictionary = hud.format_world_event_tracker(loaded, players)
	var boss_bar_info: Dictionary = hud.format_dragon_boss_bar(loaded, players)

	assert_eq(tracker_info.target, city.city_name)
	assert_eq(boss_bar_info.hp, 20.0)
	assert_eq(boss_bar_info.target, city.city_name)
	grid.queue_free()

## SO debug/playtest manual -- confirma que o botao de debug realmente cria
## o evento (a logica de guarda/ignorar trigger ja e' coberta em
## test_world_event_manager.gd).
func test_debug_force_dragon_button_creates_a_dragon_event():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	GameManager.hex_grid = hex_grid

	hud._on_debug_force_dragon_pressed()

	assert_eq(WorldEventManager.active_events.size(), 1)
	assert_true(WorldEventManager.active_events[0] is DragonEvent)
	hex_grid.queue_free()

## --- Roadmap "dois botoes" (Magia e Tecnologia sao paineis independentes) --

## Fase 25: o progresso da pesquisa ATIVA aparece no único botão "Pesquisa".
func test_research_button_shows_the_active_research_progress():
	var player = PlayerData.new(CivilizationData.new())
	GameManager.human_player = player
	hud._refresh_stats()
	assert_eq(hud.research_button.text, "Pesquisa")
	assert_true(player.v2_research.select_research("v2_doctrine_guardian_1"))
	hud._refresh_stats()
	assert_true(hud.research_button.text.begins_with("Pesquisa: "), hud.research_button.text)
	assert_true(hud.research_button.text.ends_with("(0%)"), hud.research_button.text)

## Fase 25: o botão normal "Pesquisa" abre o quadro de pesquisa como overlay único, sem modo debug.
func test_research_button_opens_the_research_panel_as_a_single_overlay_without_debug():
	GameManager.debug_mode = false
	hud._on_debug_pressed()
	assert_true(hud.debug_panel.visible, "pre-condicao")

	hud.research_button.pressed.emit()

	assert_true(hud.v2_research_panel.visible)
	assert_false(hud.debug_panel.visible, "so um overlay por vez")
	assert_true(hud.overlay_backdrop.visible)
	assert_eq(hud.v2_research_board.card_count(), 55, "abre na aba Doutrinas")

func test_no_v1_research_or_magic_ui_remains_in_the_hud():
	for node_name in ["TechPanel", "MagicPanel", "GrimoirePanel", "TechButton", "MagicButton", "GrimoireButton", "RushBuyButton", "EmbarkButton", "DebugV2TreesButton", "WorkedTiles"]:
		assert_null(hud.find_child(node_name, true, false), node_name)

func test_close_topmost_overlay_closes_the_v2_research_panel():
	hud._on_research_pressed()
	assert_true(hud.v2_research_panel.visible, "pre-condicao")

	assert_true(hud.close_topmost_overlay())

	assert_false(hud.v2_research_panel.visible)
	assert_false(hud.overlay_backdrop.visible)

func test_v2_board_close_button_and_other_overlays_hide_the_v2_panel():
	hud._on_research_pressed()
	hud.v2_research_board.close_requested.emit()
	assert_false(hud.v2_research_panel.visible)

	hud._on_research_pressed()
	hud._on_diplomacy_pressed()
	assert_false(hud.v2_research_panel.visible, "abrir outro overlay fecha a pesquisa")
	assert_true(hud.diplomacy_panel.visible)

## Fase 1: o painel V2 mostra e altera o estado REAL da civilização humana.
func test_v2_panel_is_bound_to_the_human_civilization_state():
	var player := PlayerData.new(CivilizationData.new())
	GameManager.human_player = player
	player.v2_research.complete_research("v2_doctrine_guardian_1")

	hud._on_research_pressed()

	assert_same(hud.v2_research_board.get_state(), player.v2_research)
	assert_eq(hud.v2_research_board.node_state_of("v2_doctrine_guardian_1"), V2ResearchDatabase.NodeState.COMPLETED)
	hud.v2_research_board.select_node("v2_doctrine_guardian_2")
	hud.v2_research_board.press_action()
	assert_eq(player.v2_research.active_id, "v2_doctrine_guardian_2", "a UI escreve pela API no estado do jogador")

func test_reopening_the_v2_panel_after_a_new_game_binds_the_new_human_state():
	var first := PlayerData.new(CivilizationData.new())
	GameManager.human_player = first
	hud._on_research_pressed()
	hud.v2_research_board.close_requested.emit()
	var second := PlayerData.new(CivilizationData.new())
	GameManager.human_player = second

	hud._on_research_pressed()

	assert_same(hud.v2_research_board.get_state(), second.v2_research)

func test_v2_panel_without_a_human_player_uses_a_fallback_state():
	GameManager.human_player = null
	hud._on_research_pressed()
	assert_not_null(hud.v2_research_board.get_state())
	assert_eq(hud.v2_research_board.card_count(), 55)

# --- Aetherlands V2, Fase 3: Salão dos Guardiões / Escudeiro na cidade -------------------------------------------

const V2_HALL := "v2_building_guardian_hall"
const V2_SHIELDBEARER := "v2_unit_shieldbearer"

## Cidade humana num grid mínimo, com o HUD já apontando pra ela.
func _v2_city_scene() -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city: City = hex_grid.found_city(coord, human, "Capital", true)
	# Aetherlands V2, Fase 15 — vários testes deste arquivo constroem Salão/Bastião (e as
	# variantes das outras Doutrinas) e testam o botão de produção de uma Lendária (5
	# Suprimentos, acima da capacidade base de uma cidade sozinha). Ouro de sobra + uma Fazenda
	# evitam que Déficit/Suprimentos bloqueiem o botão por um motivo alheio ao que cada teste
	# realmente verifica (mesma cidade -- ainda cabe no único tile deste grid mínimo). A Fazenda
	# ×4 sozinha já ocupa os 4 slots inteiros do City Level I (City.used_building_slots() conta
	# cada cópia repetível, §26 da Fase 13) -- City Level II (7 slots) sobra espaço pro Salão/
	# Bastião/etc. que cada teste realmente constrói, sem afetar DEVELOPED_MIN_LEVEL (3).
	human.gold = 100000.0
	city.city_level = 2
	city.buildings["v2_building_farm"] = true
	city.repeatable_building_counts["v2_building_farm"] = 1
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))
	return {"hex_grid": hex_grid, "human": human, "city": city, "coord": coord, "original_hex_grid": original_hex_grid}

## Fase 4: N4/N5 mudam a produção (o Guardião substitui o Escudeiro), então estes testes de
## Escudeiro completam só até o N3 em vez da linha inteira.
func _v2_complete_guardian(player: PlayerData, through_tier: int) -> void:
	for n in range(1, through_tier + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)

func _v2_city_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.cancel_building_placement()
	scene.human.release_relations()
	scene.city.queue_free()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_v2_hall_button_only_shows_after_n2_and_uses_the_normal_building_button_row():
	var scene := _v2_city_scene()
	var hall_button: Button = hud._building_buttons[V2_HALL]
	assert_false(hall_button.visible, "sem a pesquisa V2 o Salão não aparece")

	scene.human.v2_research.complete_research("v2_doctrine_guardian_1")
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(hall_button.visible, "N1 ainda não libera o Salão")

	scene.human.v2_research.complete_research("v2_doctrine_guardian_2")
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(hall_button.visible, "N2 libera o Salão")
	assert_false(hall_button.disabled)
	assert_true(hall_button.text.begins_with("Salão dos Guardiões"), hall_button.text)
	assert_true(hall_button.text.contains("%d PP" % int(BuildingDatabase.get_building(V2_HALL).production_cost)), hall_button.text)
	assert_same(hall_button.get_parent(), hud.buildings_row, "mesma linha de prédios do jogo")
	_v2_city_scene_cleanup(scene)

func test_v2_hall_button_starts_the_normal_building_placement():
	var scene := _v2_city_scene()
	_v2_complete_guardian(scene.human, 3)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))

	hud._on_produce_pressed(V2_HALL)

	# Grid de 1 tile: sem vizinho livre a colocação é cancelada, mas só depois de
	# passar pelo MESMO caminho (start_building_placement) dos outros prédios.
	assert_eq(scene.city.production_item, "", "a produção só começa quando o tile é escolhido")
	assert_null(SelectionManager.placing_city, "sem terreno livre a colocação é cancelada")
	_v2_city_scene_cleanup(scene)

func test_v2_hall_press_without_the_research_does_nothing():
	var scene := _v2_city_scene()
	hud._on_produce_pressed(V2_HALL)
	assert_null(SelectionManager.placing_city)
	assert_eq(scene.city.production_item, "")
	_v2_city_scene_cleanup(scene)

func test_v2_shieldbearer_button_needs_n3_and_a_hall_in_the_city():
	var scene := _v2_city_scene()
	var button: Button = hud._production_buttons[V2_SHIELDBEARER]
	assert_false(button.visible, "sem nada")

	_v2_complete_guardian(scene.human, 3)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.visible, "N3 sem o Salão construído")

	scene.city.buildings[V2_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible, "N3 + Salão")
	assert_eq(button.text, hud._unit_button_label(V2_SHIELDBEARER, "human"))
	assert_true(button.text.begins_with("Escudeiro"), button.text)
	_v2_city_scene_cleanup(scene)

func test_v2_shieldbearer_button_hidden_with_the_hall_but_without_n3():
	var scene := _v2_city_scene()
	scene.human.v2_research.complete_research("v2_doctrine_guardian_1")
	scene.human.v2_research.complete_research("v2_doctrine_guardian_2")
	scene.city.buildings[V2_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(hud._production_buttons[V2_SHIELDBEARER].visible)
	_v2_city_scene_cleanup(scene)

func test_v2_shieldbearer_button_puts_the_unit_in_the_normal_city_production():
	var scene := _v2_city_scene()
	_v2_complete_guardian(scene.human, 3)
	scene.city.buildings[V2_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))

	hud._on_produce_pressed(V2_SHIELDBEARER)

	assert_eq(scene.city.production_item, V2_SHIELDBEARER)
	assert_eq(scene.city.production_cost(), UnitDatabase.create_unit(V2_SHIELDBEARER).production_cost)
	_v2_city_scene_cleanup(scene)

func test_v2_shieldbearer_press_without_the_hall_does_nothing():
	var scene := _v2_city_scene()
	_v2_complete_guardian(scene.human, 3)
	hud._on_produce_pressed(V2_SHIELDBEARER)
	assert_eq(scene.city.production_item, "")
	_v2_city_scene_cleanup(scene)

## O painel de cidade aberto atualiza sozinho quando o unlock V2 vale (sem reclicar a cidade).
func test_city_panel_refreshes_when_a_v2_unlock_lands_with_the_city_open():
	var scene := _v2_city_scene()
	var hall_button: Button = hud._building_buttons[V2_HALL]
	assert_false(hall_button.visible)

	scene.human.v2_research.complete_research("v2_doctrine_guardian_1")
	scene.human.v2_research.complete_research("v2_doctrine_guardian_2")

	assert_true(hall_button.visible, "o botão apareceu na hora, sem reselecionar a cidade")
	_v2_city_scene_cleanup(scene)

## Com o painel V2 aberto (que esconde o painel de cidade) a atualização espera o fechamento.
func test_city_panel_refresh_waits_for_the_v2_panel_to_close():
	var scene := _v2_city_scene()
	var hall_button: Button = hud._building_buttons[V2_HALL]
	hud._on_research_pressed()
	assert_true(hud.v2_research_panel.visible)

	scene.human.v2_research.complete_research("v2_doctrine_guardian_1")
	scene.human.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_false(hall_button.visible, "ainda não reabriu o painel de cidade por cima do overlay")
	assert_true(hud._v2_city_refresh_pending)

	hud.close_topmost_overlay()
	assert_false(hud._v2_city_refresh_pending)
	assert_true(hall_button.visible, "ao fechar o painel V2 o painel de cidade já reflete o Salão")
	_v2_city_scene_cleanup(scene)

func test_a_rival_unlock_does_not_touch_the_human_city_panel():
	var scene := _v2_city_scene()
	var rival := PlayerData.new(CivilizationData.new())
	rival.v2_research.complete_research("v2_doctrine_guardian_1")
	rival.v2_research.complete_research("v2_doctrine_guardian_2")
	assert_false(hud._building_buttons[V2_HALL].visible)
	rival.release_relations()
	_v2_city_scene_cleanup(scene)

# --- Aetherlands V2, Fase 4: Muralha de Escudos / Guardião / upgrade no painel da unidade e na produção ----------

const V2_GUARDIAN := "v2_unit_guardian"
const V2_WALL := "v2_technique_shield_wall"

## Cidade humana (com Salão) em (0,0) num grid de raio 2 e um Escudeiro no vizinho (1,0), o painel
## da unidade já apontando pra ele.
func _v2_unit_scene(through: int = 4, kind: String = V2_SHIELDBEARER) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-2, 3):
		for r in range(-2, 3):
			if absi(q + r) <= 2:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[V2_HALL] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "city": city, "unit": unit, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_unit_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func _v2_action(node_name: String) -> Button:
	var row: Node = hud.unit_panel.get_node_or_null("UnitBox/V2Actions")
	if row == null:
		return null
	return row.get_node_or_null(node_name) as Button

func test_unit_panel_has_no_v2_actions_before_n4_and_for_non_line_units():
	var scene := _v2_unit_scene(3)
	assert_null(hud.unit_panel.get_node_or_null("UnitBox/V2Actions"), "sem N4 nem N5 não há ação V2")
	var archer: Unit = scene.hex_grid.spawn_unit(Vector2i(-1, 0), UnitDatabase.create_unit("archer"), scene.human)
	scene.human.v2_research.complete_research("v2_doctrine_guardian_4")
	hud._on_unit_selected(archer)
	assert_null(hud.unit_panel.get_node_or_null("UnitBox/V2Actions"), "arqueiro não é da linha do Guardião")
	_v2_unit_scene_cleanup(scene)

func test_wall_button_appears_after_n4_for_the_shieldbearer_and_is_enabled():
	var scene := _v2_unit_scene(3)
	scene.human.v2_research.complete_research("v2_doctrine_guardian_4")
	hud._on_unit_selected(scene.unit)
	var button := _v2_action("Technique_" + V2_WALL)
	assert_not_null(button, "Muralha de Escudos listada")
	assert_eq(button.text, "Muralha de Escudos")
	assert_false(button.disabled)
	assert_true(button.tooltip_text.contains("+35%"), button.tooltip_text)
	assert_null(_v2_action("UpgradeButton"), "sem N5 não há evolução")
	_v2_unit_scene_cleanup(scene)

func test_pressing_the_wall_button_activates_it_and_shows_active_state_and_marker_in_the_panel():
	var scene := _v2_unit_scene()
	_v2_action("Technique_" + V2_WALL).pressed.emit()

	assert_true(V2TechniqueRuntime.is_active(scene.unit, V2_WALL))
	var button := _v2_action("Technique_" + V2_WALL)
	assert_true(button.text.contains("Ativa"), button.text)
	assert_true(button.disabled)
	assert_true(hud.unit_info_label.text.contains("Muralha de Escudos — Ativa"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("Movimento 0.0/"), "a ação/movimento foram gastos")
	assert_not_null(scene.unit.get_node_or_null(Unit.TECHNIQUE_MARKER_NAME))
	_v2_unit_scene_cleanup(scene)

func test_cooldown_is_readable_in_the_button_and_in_the_panel_text():
	var scene := _v2_unit_scene()
	V2TechniqueRuntime.activate(scene.unit, V2_WALL)
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(scene.human)
	scene.unit.movement_left = 2.0
	hud._on_unit_selected(scene.unit)
	var button := _v2_action("Technique_" + V2_WALL)
	assert_eq(button.text, "Muralha de Escudos (recarga 2)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 2 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Muralha de Escudos — recarga: 2 turno(s)"), hud.unit_info_label.text)
	assert_false(hud.unit_info_label.text.contains("— Ativa"))
	_v2_unit_scene_cleanup(scene)

func test_wall_button_is_disabled_when_the_unit_has_no_action_left():
	var scene := _v2_unit_scene()
	scene.unit.movement_left = 0.0
	hud._on_unit_selected(scene.unit)
	var button := _v2_action("Technique_" + V2_WALL)
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("já agiu"), button.tooltip_text)
	_v2_unit_scene_cleanup(scene)

func test_the_panel_refreshes_by_itself_when_the_world_updates_fog_or_the_turn_changes():
	var scene := _v2_unit_scene()
	V2TechniqueRuntime.activate(scene.unit, V2_WALL)
	hud._on_unit_selected(scene.unit)
	assert_true(hud.unit_info_label.text.contains("— Ativa"))
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(scene.human) # o que GameManager._finish_turn faz
	EventBus.fog_updated.emit() # ...e logo em seguida recompute_fog
	assert_false(hud.unit_info_label.text.contains("— Ativa"), "o painel deixou de mostrar a Muralha ativa")
	assert_true(hud.unit_info_label.text.contains("recarga: 2 turno(s)"))
	_v2_unit_scene_cleanup(scene)

func test_upgrade_button_appears_with_n5_shows_the_formula_cost_and_is_enabled_in_a_city_with_the_hall():
	var scene := _v2_unit_scene(5)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Guardião — 24 Ouro")
	assert_false(button.disabled)
	_v2_unit_scene_cleanup(scene)

func test_upgrade_button_explains_why_it_is_disabled():
	var scene := _v2_unit_scene(5)
	scene.human.gold = 3.0
	hud._on_unit_selected(scene.unit)
	assert_true(_v2_action("UpgradeButton").disabled)
	assert_true(_v2_action("UpgradeButton").tooltip_text.contains("Ouro insuficiente"), _v2_action("UpgradeButton").tooltip_text)

	scene.human.gold = 100.0
	scene.city.buildings.erase(V2_HALL)
	hud._on_unit_selected(scene.unit)
	assert_true(_v2_action("UpgradeButton").tooltip_text.contains("Salão dos Guardiões"), _v2_action("UpgradeButton").tooltip_text)

	scene.city.buildings[V2_HALL] = true
	scene.unit.movement_left = 0.0
	hud._on_unit_selected(scene.unit)
	assert_true(_v2_action("UpgradeButton").tooltip_text.contains("já agiu"), _v2_action("UpgradeButton").tooltip_text)

	scene.unit.movement_left = 2.0
	scene.hex_grid.move_unit(scene.unit, Vector2i(2, 0), 1.0)
	hud._on_unit_selected(scene.unit)
	assert_true(_v2_action("UpgradeButton").tooltip_text.contains("cidade própria"), _v2_action("UpgradeButton").tooltip_text)
	_v2_unit_scene_cleanup(scene)

func test_pressing_the_upgrade_button_evolves_the_unit_and_charges_gold():
	var scene := _v2_unit_scene(5)
	_v2_action("UpgradeButton").pressed.emit()

	assert_eq(scene.unit.unit_data.visual_kind, V2_GUARDIAN)
	assert_eq(scene.human.gold, 100.0 - 24.0)
	assert_null(_v2_action("UpgradeButton"), "o Guardião não tem a próxima forma conectada")
	assert_true(hud.unit_info_label.text.begins_with("Guardião"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("HP 24/24"), hud.unit_info_label.text)
	# A Muralha continua disponível pro Guardião (mesma linha).
	assert_not_null(_v2_action("Technique_" + V2_WALL))
	_v2_unit_scene_cleanup(scene)

func test_production_row_shows_the_shieldbearer_before_n5_and_the_guardian_after_never_both():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	_v2_complete_guardian(scene.human, 4)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var shield_button: Button = hud._production_buttons[V2_SHIELDBEARER]
	var guardian_button: Button = hud._production_buttons[V2_GUARDIAN]
	assert_true(shield_button.visible, "antes do N5: Escudeiro")
	assert_eq(shield_button.text, "Escudeiro  —  20 PP")
	assert_false(guardian_button.visible)

	scene.human.v2_research.complete_research("v2_doctrine_guardian_5") # dispara o refresh do painel pelo unlock
	assert_true(guardian_button.visible, "depois do N5: Guardião")
	assert_eq(guardian_button.text, "Guardião  —  32 PP")
	assert_false(shield_button.visible, "o Escudeiro não é mais oferecido")
	_v2_city_scene_cleanup(scene)

func test_pressing_the_guardian_button_puts_it_in_the_normal_production():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	_v2_complete_guardian(scene.human, 5)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	hud._on_produce_pressed(V2_GUARDIAN)
	assert_eq(scene.city.production_item, V2_GUARDIAN)
	assert_eq(scene.city.production_cost(), 32.0)
	hud._on_produce_pressed(V2_SHIELDBEARER)
	assert_eq(scene.city.production_item, V2_GUARDIAN, "o Escudeiro superado não entra na fila")
	_v2_city_scene_cleanup(scene)

# --- Aetherlands V2, Fase 5: Preparar Lanças (passiva) / Sentinela / segundo upgrade no painel e na produção -----

const V2_SENTINEL := "v2_unit_sentinel"
const V2_BRACE := "v2_technique_brace_spears"

func test_brace_spears_shows_as_a_passive_line_and_never_as_a_button():
	var scene := _v2_unit_scene(6, V2_GUARDIAN)
	assert_true(hud.unit_info_label.text.contains("Passiva — Preparar Lanças\n+50% de dano de ataque básico contra unidades montadas."), hud.unit_info_label.text)
	assert_not_null(_v2_action("Technique_" + V2_WALL), "a Muralha continua sendo uma ação")
	assert_null(_v2_action("Technique_" + V2_BRACE), "a passiva NÃO ganha botão")
	var row: Node = hud.unit_panel.get_node("UnitBox/V2Actions")
	var texts: Array = []
	for child in row.get_children():
		texts.append((child as Button).text)
	assert_false(texts.any(func(t): return t.contains("Preparar")), "nenhum botão menciona a passiva: %s" % str(texts))
	_v2_unit_scene_cleanup(scene)

func test_the_passive_line_is_absent_before_n6_and_after_a_reset():
	var scene := _v2_unit_scene(5, V2_GUARDIAN)
	assert_false(hud.unit_info_label.text.contains("Preparar Lanças"))
	scene.human.v2_research.complete_research("v2_doctrine_guardian_6")
	hud._on_unit_selected(scene.unit)
	assert_true(hud.unit_info_label.text.contains("Passiva — Preparar Lanças"))
	scene.human.v2_research.reset()
	hud._on_unit_selected(scene.unit)
	assert_false(hud.unit_info_label.text.contains("Preparar Lanças"), "a passiva é derivada da pesquisa")
	_v2_unit_scene_cleanup(scene)

func test_the_sentinel_panel_shows_the_wall_button_and_the_passive_and_no_upgrade():
	var scene := _v2_unit_scene(7, V2_SENTINEL)
	assert_not_null(_v2_action("Technique_" + V2_WALL))
	assert_true(hud.unit_info_label.text.contains("Sentinela"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("HP 32/32"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("Passiva — Preparar Lanças"))
	assert_null(_v2_action("UpgradeButton"), "a Sentinela é a última forma")
	_v2_unit_scene_cleanup(scene)

func test_guardian_upgrade_button_offers_the_sentinel_with_the_formula_cost():
	var scene := _v2_unit_scene(7, V2_GUARDIAN)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Sentinela — 32 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(scene.unit.unit_data.visual_kind, V2_SENTINEL)
	assert_eq(scene.human.gold, 100.0 - 32.0)
	assert_null(_v2_action("UpgradeButton"))
	assert_true(hud.unit_info_label.text.begins_with("Sentinela"), hud.unit_info_label.text)
	_v2_unit_scene_cleanup(scene)

func test_the_guardian_has_no_upgrade_button_before_n7_and_explains_when_it_cannot_afford_it():
	var scene := _v2_unit_scene(6, V2_GUARDIAN)
	assert_null(_v2_action("UpgradeButton"), "sem N7 não há evolução na tela")
	scene.human.v2_research.complete_research("v2_doctrine_guardian_7")
	scene.human.gold = 10.0
	hud._on_unit_selected(scene.unit)
	assert_true(_v2_action("UpgradeButton").disabled)
	assert_true(_v2_action("UpgradeButton").tooltip_text.contains("Ouro insuficiente (custa 32)"), _v2_action("UpgradeButton").tooltip_text)
	_v2_unit_scene_cleanup(scene)

func test_production_row_walks_shieldbearer_guardian_sentinel_never_two_at_once():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	for n in range(1, 8):
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		if n < 3:
			continue
		var visible_forms: Array = []
		for kind in [V2_SHIELDBEARER, V2_GUARDIAN, V2_SENTINEL]:
			if (hud._production_buttons[kind] as Button).visible:
				visible_forms.append(kind)
		var want := V2_SHIELDBEARER if n < 5 else (V2_GUARDIAN if n < 7 else V2_SENTINEL)
		assert_eq(visible_forms, [want], "N%d" % n)
	assert_eq(hud._production_buttons[V2_SENTINEL].text, "Sentinela  —  48 PP")
	_v2_city_scene_cleanup(scene)

func test_pressing_the_sentinel_button_uses_the_normal_production_and_the_old_forms_do_not_enter():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	for n in range(1, 8):
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	hud._on_produce_pressed(V2_SENTINEL)
	assert_eq(scene.city.production_item, V2_SENTINEL)
	assert_eq(scene.city.production_cost(), 48.0)
	hud._on_produce_pressed(V2_GUARDIAN)
	assert_eq(scene.city.production_item, V2_SENTINEL, "o Guardião superado não entra na fila")
	_v2_city_scene_cleanup(scene)

# --- Aetherlands V2, Fase 6: Bastião de Maestria / Campeão Guardião / slot Lendário na cidade e no painel ---------

const V2_MASTERY := "v2_building_guardian_mastery"
const V2_CHAMPION := "v2_legendary_guardian_champion"

## Duas cidades humanas (tiles distantes), ambas com Salão e Bastião, N1-N9 do Guardião.
func _v2_two_city_scene() -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for coord in [Vector2i(0, 0), Vector2i(5, 0)]:
		hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	_v2_complete_guardian(human, 9)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	var city_a: City = hex_grid.found_city(Vector2i(0, 0), human, "A", true)
	var city_b: City = hex_grid.found_city(Vector2i(5, 0), human, "B", true)
	# Aetherlands V2, Fase 15 — o Campeão custa 5 Suprimentos, acima da base de uma cidade sozinha
	# (4); Salão+Bastião em duas cidades (upkeep de Ouro, §24-30) sem Mercado e sem Ouro em caixa
	# também entrariam em Déficit sozinhos. Ouro de sobra + uma Fazenda em cada evitam que
	# Déficit/Suprimentos bloqueiem o botão por um motivo alheio ao que estes testes verificam (o
	# slot Lendário compartilhado).
	human.gold = 100000.0
	for city in [city_a, city_b]:
		city.buildings[V2_HALL] = true
		city.buildings[V2_MASTERY] = true
		city.buildings["v2_building_farm"] = true
		city.repeatable_building_counts["v2_building_farm"] = 1
	hud._on_tile_selected(Vector2i(0, 0), hex_grid.get_tile(Vector2i(0, 0)))
	return {"hex_grid": hex_grid, "human": human, "a": city_a, "b": city_b, "original_hex_grid": original_hex_grid}

func _v2_two_city_scene_cleanup(scene: Dictionary) -> void:
	scene.human.release_relations()
	scene.a.queue_free()
	scene.b.queue_free()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_mastery_building_button_needs_n8_and_the_hall():
	var scene := _v2_city_scene()
	var button: Button = hud._building_buttons[V2_MASTERY]
	_v2_complete_guardian(scene.human, 7)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.visible, "sem N8 não aparece")

	scene.human.v2_research.complete_research("v2_doctrine_guardian_8")
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible, "N8 libera o botão do Bastião")
	assert_true(button.disabled, "sem o Salão na cidade fica desabilitado (com o motivo no tooltip)")
	assert_true(button.tooltip_text.contains("Salão dos Guardiões"), button.tooltip_text)

	scene.city.buildings[V2_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.disabled, "com o Salão e espaço, habilitado")
	assert_true(button.text.begins_with("Bastião de Maestria"), button.text)
	assert_true(button.text.contains("55 PP"), button.text)
	_v2_city_scene_cleanup(scene)

func test_the_champion_button_shows_in_the_mastery_city_next_to_the_sentinel_and_not_the_older_forms():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	_v2_complete_guardian(scene.human, 9)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false((hud._production_buttons[V2_CHAMPION] as Button).visible, "sem o Bastião na cidade")
	assert_true((hud._production_buttons[V2_SENTINEL] as Button).visible, "a Sentinela é do Salão")

	scene.city.buildings[V2_MASTERY] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var champion_button: Button = hud._production_buttons[V2_CHAMPION]
	assert_true(champion_button.visible)
	assert_false(champion_button.disabled)
	assert_eq(champion_button.text, "Campeão Guardião  —  90 PP")
	assert_true((hud._production_buttons[V2_SENTINEL] as Button).visible, "a Sentinela continua no Salão")
	assert_false((hud._production_buttons[V2_GUARDIAN] as Button).visible)
	assert_false((hud._production_buttons[V2_SHIELDBEARER] as Button).visible)
	_v2_city_scene_cleanup(scene)

func test_pressing_the_champion_button_starts_the_legendary_production():
	var scene := _v2_city_scene()
	scene.city.buildings[V2_HALL] = true
	scene.city.buildings[V2_MASTERY] = true
	_v2_complete_guardian(scene.human, 9)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	hud._on_produce_pressed(V2_CHAMPION)
	assert_eq(scene.city.production_item, V2_CHAMPION)
	assert_eq(scene.city.production_cost(), 90.0)
	_v2_city_scene_cleanup(scene)

func test_the_second_city_sees_the_champion_disabled_with_the_slot_reason_while_the_first_produces_it():
	var scene := _v2_two_city_scene()
	# Cidade A: livre — botão habilitado.
	var button: Button = hud._production_buttons[V2_CHAMPION]
	assert_true(button.visible)
	assert_false(button.disabled)
	hud._on_produce_pressed(V2_CHAMPION)
	assert_eq(scene.a.production_item, V2_CHAMPION)

	# Cidade B: o slot está reservado — o botão aparece DESABILITADO com o motivo (não some sem explicar).
	hud._on_tile_selected(Vector2i(5, 0), scene.hex_grid.get_tile(Vector2i(5, 0)))
	assert_true(button.visible, "o único impedimento é o slot: continua visível")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), button.tooltip_text)
	hud._on_produce_pressed(V2_CHAMPION)
	assert_eq(scene.b.production_item, "", "clicar no botão bloqueado não inicia nada")

	# A própria cidade A continua podendo (a sua ordem não conta contra ela).
	hud._on_tile_selected(Vector2i(0, 0), scene.hex_grid.get_tile(Vector2i(0, 0)))
	assert_false(button.disabled)

	# Cancelar a produção na A libera a B.
	scene.a.set_production("")
	hud._on_tile_selected(Vector2i(5, 0), scene.hex_grid.get_tile(Vector2i(5, 0)))
	assert_false(button.disabled, "reserva liberada")
	_v2_two_city_scene_cleanup(scene)

func test_an_active_champion_disables_the_button_in_every_city_and_death_reenables_it():
	var scene := _v2_two_city_scene()
	var champion: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit(V2_CHAMPION), scene.human)
	assert_not_null(champion)
	var button: Button = hud._production_buttons[V2_CHAMPION]
	hud._on_tile_selected(Vector2i(5, 0), scene.hex_grid.get_tile(Vector2i(5, 0)))
	assert_true(button.visible)
	assert_true(button.disabled, "Lendária ativa ocupa o slot")
	scene.hex_grid.remove_unit(champion)
	hud._on_tile_selected(Vector2i(5, 0), scene.hex_grid.get_tile(Vector2i(5, 0)))
	assert_false(button.disabled, "a morte libera o slot")
	_v2_two_city_scene_cleanup(scene)

func test_the_champion_panel_shows_legendary_the_command_aura_and_the_normal_techniques():
	var scene := _v2_unit_scene(9, V2_CHAMPION)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Campeão Guardião"), text)
	assert_true(text.contains("HP 44/44"), text)
	assert_true(text.contains("Ataque 6.5"), text)
	assert_true(text.contains("Defesa 10.0"), text)
	assert_true(text.contains("Passiva Lendária — Comando Defensivo\nAliados em raio 2 recebem +20% de Defesa."), text)
	assert_true(text.contains("Passiva — Preparar Lanças"), text)
	assert_not_null(_v2_action("Technique_" + V2_WALL), "a Muralha continua disponível")
	assert_null(_v2_action("Technique_" + V2_BRACE), "a passiva não vira botão")
	assert_null(_v2_action("UpgradeButton"), "o Campeão não evolui")
	_v2_unit_scene_cleanup(scene)

func test_a_conventional_unit_panel_has_no_legendary_label():
	var scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	assert_false(hud.unit_info_label.text.contains("Comando Defensivo"))
	_v2_unit_scene_cleanup(scene)

# --- Aetherlands V2, Fase 7: Doutrina do Guerreiro na produção e no painel da unidade ---------------------------------

const W_HALL := "v2_building_warrior_hall"
const W_ARENA := "v2_building_warrior_mastery"
const W_WARRIOR := "v2_unit_warrior"
const W_SWORDSMAN := "v2_unit_swordsman"
const W_MASTER := "v2_unit_weapon_master"
const W_HERO := "v2_legendary_blade_hero"
const W_POWER := "v2_technique_power_strike"
const W_CLEAVE := "v2_technique_cleave"

## Cidade humana (com Salão de Armas) em (0,0) num grid de raio 2, um `kind` do Guerreiro no vizinho (1,0), o painel da unidade já
## apontando pra ele e um inimigo em guerra em (2,0) (adjacente à unidade) se `with_enemy`.
func _v2_warrior_scene(through: int = 4, kind: String = W_WARRIOR, with_enemy: bool = true) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-2, 3):
		for r in range(-2, 3):
			if absi(q + r) <= 2:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[W_HALL] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	var enemy: Unit = null
	if with_enemy:
		var data := UnitDatabase.create_unit("warrior")
		data.max_hp = 40.0
		enemy = hex_grid.spawn_unit(Vector2i(2, 0), data, rival)
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "rival": rival, "city": city, "unit": unit, "enemy": enemy, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_warrior_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.rival.release_relations()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_weapons_hall_and_arena_buttons_follow_n2_and_n8():
	var scene := _v2_city_scene()
	var hall_button: Button = hud._building_buttons[W_HALL]
	var arena_button: Button = hud._building_buttons[W_ARENA]
	assert_false(hall_button.visible, "sem a pesquisa o Salão de Armas não aparece")
	assert_false(arena_button.visible)

	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(hall_button.visible, "N2 libera o Salão de Armas")
	assert_eq(hall_button.text, "Salão de Armas  —  22 PP")
	assert_false(arena_button.visible)

	for n in range(3, 9):
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	scene.city.buildings[W_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(arena_button.visible, "N8 libera a Arena dos Campeões")
	assert_eq(arena_button.text, "Arena dos Campeões  —  55 PP")
	assert_false(arena_button.disabled, "com o Salão de Armas e espaço")
	_v2_city_scene_cleanup(scene)

func test_the_arena_button_is_disabled_with_the_reason_when_the_weapons_hall_is_missing():
	var scene := _v2_city_scene()
	for n in range(1, 9):
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var arena_button: Button = hud._building_buttons[W_ARENA]
	assert_true(arena_button.visible)
	assert_true(arena_button.disabled)
	assert_true(arena_button.tooltip_text.contains("Salão de Armas"), arena_button.tooltip_text)
	_v2_city_scene_cleanup(scene)

func test_the_warrior_production_shows_exactly_one_form_at_each_research_level():
	var scene := _v2_city_scene()
	scene.city.buildings[W_HALL] = true
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	var expected := {3: [W_WARRIOR, "Guerreiro  —  20 PP"], 5: [W_SWORDSMAN, "Espadachim  —  32 PP"], 7: [W_MASTER, "Mestre de Armas  —  48 PP"]}
	var done := 2
	for through in expected:
		for n in range(done + 1, through + 1):
			scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		done = through
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		var visible_forms: Array = [W_WARRIOR, W_SWORDSMAN, W_MASTER].filter(func(k): return (hud._production_buttons[k] as Button).visible)
		assert_eq(visible_forms, [expected[through][0]], "até N%d só uma forma" % through)
		assert_eq((hud._production_buttons[expected[through][0]] as Button).text, expected[through][1])
	_v2_city_scene_cleanup(scene)

func test_the_hero_button_shows_in_the_arena_city_and_is_disabled_with_the_slot_reason_while_a_champion_lives():
	var scene := _v2_city_scene()
	for n in range(1, 10):
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	scene.city.buildings[W_HALL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var hero_button: Button = hud._production_buttons[W_HERO]
	assert_false(hero_button.visible, "sem a Arena na cidade")
	scene.city.buildings[W_ARENA] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(hero_button.visible)
	assert_false(hero_button.disabled)
	assert_eq(hero_button.text, "Herói da Lâmina  —  90 PP")
	assert_true((hud._production_buttons[W_MASTER] as Button).visible, "o Mestre de Armas segue ao lado")

	# O Campeão Guardião ativo ocupa o slot ÚNICO: o botão do Herói fica visível, desabilitado, com o motivo.
	var champion: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("v2_legendary_guardian_champion"), scene.human)
	assert_not_null(champion)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(hero_button.visible, "o único impedimento é o slot")
	assert_true(hero_button.disabled)
	assert_true(hero_button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), hero_button.tooltip_text)
	scene.hex_grid.remove_unit(champion)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(hero_button.disabled, "a morte do Campeão libera o Herói")
	hud._on_produce_pressed(W_HERO)
	assert_eq(scene.city.production_item, W_HERO)
	_v2_city_scene_cleanup(scene)

func test_the_power_strike_button_shows_the_multiplier_and_the_no_target_reason():
	var scene := _v2_warrior_scene(4, W_WARRIOR, false)
	var button := _v2_action("Technique_" + W_POWER)
	assert_not_null(button, "Golpe Poderoso listado a partir do N4")
	assert_eq(button.text, "Golpe Poderoso ×1.6")
	assert_true(button.disabled, "sem inimigo adjacente")
	assert_true(button.tooltip_text.contains("Nenhum inimigo adjacente."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("recarga de 3 turnos"), button.tooltip_text)
	assert_null(_v2_action("Technique_" + W_CLEAVE), "o Arco só a partir do N6")
	_v2_warrior_scene_cleanup(scene)

func test_the_power_strike_button_is_enabled_with_an_adjacent_enemy_and_enters_the_targeting_state():
	var scene := _v2_warrior_scene(4)
	var button := _v2_action("Technique_" + W_POWER)
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, W_POWER)
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Golpe Poderoso (ESC cancela) «"), hud.unit_info_label.text)
	assert_false((scene.unit as Unit).magic_cooldowns.has(W_POWER), "a mira não gasta a recarga")
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o alvo"), "ao cancelar a dica some")
	_v2_warrior_scene_cleanup(scene)

func test_after_a_power_strike_the_button_shows_the_cooldown_and_is_disabled():
	var scene := _v2_warrior_scene(4)
	var unit: Unit = scene.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, W_POWER, scene.enemy, scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + W_POWER)
	assert_eq(button.text, "Golpe Poderoso ×1.6 (recarga 3)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 3 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Golpe Poderoso — recarga: 3 turno(s)"), "o painel também lista a recarga")
	_v2_warrior_scene_cleanup(scene)

func test_the_cleave_button_appears_from_n6_and_acts_without_a_targeting_state():
	var scene := _v2_warrior_scene(6)
	var button := _v2_action("Technique_" + W_CLEAVE)
	assert_not_null(button)
	assert_eq(button.text, "Ataque em Arco ×0.75")
	assert_false(button.disabled, "há um inimigo adjacente")
	var enemy: Unit = scene.enemy
	var hp := enemy.hp
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, "", "o Arco não usa mira")
	assert_lt(enemy.hp, hp, "atingiu o inimigo adjacente")
	assert_eq((scene.unit as Unit).movement_left, 0.0)
	_v2_warrior_scene_cleanup(scene)

func test_the_upgrade_button_shows_the_generic_formula_cost_for_the_swordsman():
	var scene := _v2_warrior_scene(5, W_WARRIOR, false)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Espadachim — 24 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq((scene.unit as Unit).unit_data.visual_kind, W_SWORDSMAN)
	assert_eq(scene.human.gold, 76.0)
	_v2_warrior_scene_cleanup(scene)

func test_the_weapon_master_panel_has_no_upgrade_and_both_technique_buttons():
	var scene := _v2_warrior_scene(7, W_MASTER)
	assert_null(_v2_action("UpgradeButton"), "fim da linha convencional")
	assert_not_null(_v2_action("Technique_" + W_POWER))
	assert_not_null(_v2_action("Technique_" + W_CLEAVE))
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	_v2_warrior_scene_cleanup(scene)

func test_the_hero_panel_shows_legendary_the_execution_passive_and_both_technique_buttons():
	var scene := _v2_warrior_scene(9, W_HERO)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Herói da Lâmina"), text)
	assert_true(text.contains("HP 38/38"), text)
	assert_true(text.contains("Ataque 12.0"), text)
	assert_true(text.contains("Defesa 7.0"), text)
	assert_true(text.contains("Passiva Lendária — Execução\n+30% de Ataque contra unidades com 50% de HP ou menos."), text)
	assert_false(text.contains("Comando Defensivo"), "a aura é do Campeão Guardião")
	assert_not_null(_v2_action("Technique_" + W_POWER))
	assert_not_null(_v2_action("Technique_" + W_CLEAVE))
	assert_null(_v2_action("UpgradeButton"), "o Herói não evolui")
	_v2_warrior_scene_cleanup(scene)

func test_a_guardian_unit_panel_is_not_touched_by_the_warrior_content():
	var scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_not_null(_v2_action("Technique_" + V2_WALL))
	assert_null(_v2_action("Technique_" + W_POWER), "o Guardião não recebe técnicas do Guerreiro")
	assert_false(hud.unit_info_label.text.contains("Execução"))
	_v2_unit_scene_cleanup(scene)

# --- Aetherlands V2, Fase 8: Doutrina do Patrulheiro na produção e no painel da unidade ------------------------------------

const R_CAMP := "v2_building_ranger_camp"
const R_TOWER := "v2_building_ranger_mastery"
const R_ARCHER := "v2_unit_archer"
const R_HUNTER := "v2_unit_hunter"
const R_MARKSMAN := "v2_unit_elite_marksman"
const R_LEGEND := "v2_legendary_legend_hunter"
const R_PRECISE := "v2_technique_precise_shot"
const R_VOLLEY := "v2_technique_volley"

## Cidade humana (com Campo) em (0,0) num grid de raio 6, um `kind` do Patrulheiro no vizinho (1,0), o painel da unidade já apontando pra ele e, se
## `enemy_distance` > 0, um inimigo em guerra a essa distância da unidade (no eixo +q).
func _v2_ranger_scene(through: int = 4, kind: String = R_ARCHER, enemy_distance: int = 0) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[R_CAMP] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	var enemy: Unit = null
	if enemy_distance > 0:
		var data := UnitDatabase.create_unit("warrior")
		data.max_hp = 40.0
		enemy = hex_grid.spawn_unit(Vector2i(1 + enemy_distance, 0), data, rival)
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "rival": rival, "city": city, "unit": unit, "enemy": enemy, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_ranger_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.rival.release_relations()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_camp_and_tower_buttons_follow_n2_and_n8():
	var scene := _v2_city_scene()
	var camp_button: Button = hud._building_buttons[R_CAMP]
	var tower_button: Button = hud._building_buttons[R_TOWER]
	assert_false(camp_button.visible, "sem a pesquisa o Campo não aparece")
	assert_false(tower_button.visible)
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(camp_button.visible, "N2 libera o Campo dos Patrulheiros")
	assert_eq(camp_button.text, "Campo dos Patrulheiros  —  22 PP")
	assert_false(tower_button.visible)
	for n in range(3, 9):
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	scene.city.buildings[R_CAMP] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(tower_button.visible, "N8 libera a Torre dos Patrulheiros")
	assert_eq(tower_button.text, "Torre dos Patrulheiros  —  55 PP")
	assert_false(tower_button.disabled)
	_v2_city_scene_cleanup(scene)

func test_the_tower_button_is_disabled_with_the_reason_when_the_camp_is_missing():
	var scene := _v2_city_scene()
	for n in range(1, 9):
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var tower_button: Button = hud._building_buttons[R_TOWER]
	assert_true(tower_button.visible)
	assert_true(tower_button.disabled)
	assert_true(tower_button.tooltip_text.contains("Campo dos Patrulheiros"), tower_button.tooltip_text)
	_v2_city_scene_cleanup(scene)

func test_the_ranger_production_shows_exactly_one_form_at_each_research_level():
	var scene := _v2_city_scene()
	scene.city.buildings[R_CAMP] = true
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
	var expected := {3: [R_ARCHER, "Arqueiro  —  20 PP"], 5: [R_HUNTER, "Caçador  —  32 PP"], 7: [R_MARKSMAN, "Atirador de Elite  —  48 PP"]}
	var done := 2
	for through in expected:
		for n in range(done + 1, through + 1):
			scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		done = through
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		var visible_forms: Array = [R_ARCHER, R_HUNTER, R_MARKSMAN].filter(func(k): return (hud._production_buttons[k] as Button).visible)
		assert_eq(visible_forms, [expected[through][0]], "até N%d só uma forma" % through)
		assert_eq((hud._production_buttons[expected[through][0]] as Button).text, expected[through][1])
	_v2_city_scene_cleanup(scene)

func test_the_legend_hunter_button_shows_in_the_tower_city_and_is_disabled_by_any_other_legendary():
	var scene := _v2_city_scene()
	for n in range(1, 10):
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	scene.city.buildings[R_CAMP] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var button: Button = hud._production_buttons[R_LEGEND]
	assert_false(button.visible, "sem a Torre na cidade")
	scene.city.buildings[R_TOWER] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible)
	assert_false(button.disabled)
	assert_eq(button.text, "Caçador de Lendas  —  90 PP")
	assert_true((hud._production_buttons[R_MARKSMAN] as Button).visible, "o Atirador de Elite segue ao lado")
	for other_kind in ["v2_legendary_guardian_champion", "v2_legendary_blade_hero"]:
		var other: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit(other_kind), scene.human)
		assert_not_null(other)
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		assert_true(button.visible, "o único impedimento é o slot")
		assert_true(button.disabled, "%s ativo ocupa o slot ÚNICO" % other_kind)
		assert_true(button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), button.tooltip_text)
		scene.hex_grid.remove_unit(other)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.disabled, "sem nenhuma outra Lendária o slot está livre")
	hud._on_produce_pressed(R_LEGEND)
	assert_eq(scene.city.production_item, R_LEGEND)
	_v2_city_scene_cleanup(scene)

func test_the_precise_shot_button_shows_the_multiplier_the_range_and_the_no_target_reason():
	var scene := _v2_ranger_scene(4, R_ARCHER, 0)
	var button := _v2_action("Technique_" + R_PRECISE)
	assert_not_null(button, "Disparo Preciso listado a partir do N4")
	assert_eq(button.text, "Disparo Preciso ×1.4")
	assert_true(button.disabled, "sem inimigo ao alcance")
	assert_true(button.tooltip_text.contains("Nenhum inimigo ao alcance."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("alcance básico +1"), button.tooltip_text)
	assert_null(_v2_action("Technique_" + R_VOLLEY), "a Saraivada só a partir do N6")
	assert_true(hud.unit_info_label.text.contains("Alcance de ataque: 2"), "o painel mostra o alcance ranged")
	_v2_ranger_scene_cleanup(scene)

func test_the_precise_shot_is_enabled_with_an_enemy_at_range_3_and_enters_the_targeting_state():
	var scene := _v2_ranger_scene(4, R_ARCHER, 3)
	var button := _v2_action("Technique_" + R_PRECISE)
	assert_false(button.disabled, "alcance básico 2 + 1 = 3")
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, R_PRECISE)
	assert_eq(SelectionManager.technique_target_coords, [(scene.enemy as Unit).coord])
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Disparo Preciso (ESC cancela) «"), hud.unit_info_label.text)
	assert_false((scene.unit as Unit).magic_cooldowns.has(R_PRECISE), "a mira não gasta a recarga")
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o alvo"), "ao cancelar a dica some")
	_v2_ranger_scene_cleanup(scene)

func test_an_enemy_at_range_4_is_out_of_the_archers_precise_shot_but_inside_the_marksmans():
	var archer_scene := _v2_ranger_scene(7, R_ARCHER, 4)
	assert_true(_v2_action("Technique_" + R_PRECISE).disabled, "o Arqueiro chega a 3")
	_v2_ranger_scene_cleanup(archer_scene)
	var marksman_scene := _v2_ranger_scene(7, R_MARKSMAN, 4)
	assert_false(_v2_action("Technique_" + R_PRECISE).disabled, "o Atirador de Elite chega a 4 (alcance 3 + 1)")
	assert_true(hud.unit_info_label.text.contains("Alcance de ataque: 3"))
	_v2_ranger_scene_cleanup(marksman_scene)

func test_after_a_precise_shot_the_button_shows_the_cooldown_and_is_disabled():
	var scene := _v2_ranger_scene(4, R_ARCHER, 3)
	var unit: Unit = scene.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, R_PRECISE, scene.enemy, scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + R_PRECISE)
	assert_eq(button.text, "Disparo Preciso ×1.4 (recarga 3)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 3 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Disparo Preciso — recarga: 3 turno(s)"))
	_v2_ranger_scene_cleanup(scene)

func test_the_volley_button_appears_from_n6_uses_the_basic_range_and_enters_the_targeting_state():
	var scene := _v2_ranger_scene(6, R_ARCHER, 3)
	var volley_button := _v2_action("Technique_" + R_VOLLEY)
	assert_not_null(volley_button)
	assert_eq(volley_button.text, "Saraivada ×0.7")
	assert_true(volley_button.disabled, "a 3 tiles: fora do alcance básico (2)")
	assert_false(_v2_action("Technique_" + R_PRECISE).disabled, "mas dentro do Disparo Preciso")
	_v2_ranger_scene_cleanup(scene)
	var near := _v2_ranger_scene(6, R_ARCHER, 2)
	var button := _v2_action("Technique_" + R_VOLLEY)
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, R_VOLLEY, "a Saraivada tem mira")
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Saraivada (ESC cancela) «"))
	assert_true(SelectionManager.cancel_technique_targeting())
	_v2_ranger_scene_cleanup(near)

func test_the_upgrade_button_shows_the_generic_formula_cost_for_the_hunter():
	var scene := _v2_ranger_scene(5, R_ARCHER, 0)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Caçador — 24 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq((scene.unit as Unit).unit_data.visual_kind, R_HUNTER)
	assert_eq(scene.human.gold, 76.0)
	_v2_ranger_scene_cleanup(scene)

func test_the_marksman_panel_has_no_upgrade_both_techniques_and_no_legendary_label():
	var scene := _v2_ranger_scene(7, R_MARKSMAN, 0)
	assert_null(_v2_action("UpgradeButton"), "fim da linha convencional")
	assert_not_null(_v2_action("Technique_" + R_PRECISE))
	assert_not_null(_v2_action("Technique_" + R_VOLLEY))
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	_v2_ranger_scene_cleanup(scene)

func test_the_legend_hunter_panel_shows_legendary_the_hunt_passive_the_range_and_both_technique_buttons():
	var scene := _v2_ranger_scene(9, R_LEGEND, 0)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Caçador de Lendas"), text)
	assert_true(text.contains("HP 30/30"), text)
	assert_true(text.contains("Ataque 11.0"), text)
	assert_true(text.contains("Defesa 4.5"), text)
	assert_true(text.contains("Alcance de ataque: 3"), text)
	assert_true(text.contains("Passiva Lendária — Caçada Lendária\n+40% de Ataque contra Unidades Lendárias."), text)
	assert_false(text.contains("Execução"), "a Execução é do Herói da Lâmina")
	assert_false(text.contains("Comando Defensivo"), "a aura é do Campeão Guardião")
	assert_not_null(_v2_action("Technique_" + R_PRECISE))
	assert_not_null(_v2_action("Technique_" + R_VOLLEY))
	assert_null(_v2_action("UpgradeButton"), "o Caçador de Lendas não evolui")
	_v2_ranger_scene_cleanup(scene)

func test_the_other_doctrines_panels_are_not_touched_by_the_ranger_content():
	var scene := _v2_warrior_scene(9, W_MASTER)
	assert_null(_v2_action("Technique_" + R_PRECISE), "o Guerreiro não recebe técnicas do Patrulheiro")
	assert_false(hud.unit_info_label.text.contains("Caçada"))
	_v2_warrior_scene_cleanup(scene)
	var guardian_scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_null(_v2_action("Technique_" + R_VOLLEY))
	_v2_unit_scene_cleanup(guardian_scene)

# --- Aetherlands V2, Fase 9: Doutrina da Cavalaria na produção e no painel da unidade -----------------------------------------

const C_STABLE := "v2_building_war_stable"
const C_ORDER := "v2_building_cavalry_mastery"
const C_CAVALIER := "v2_unit_cavalier"
const C_SHOCK := "v2_unit_shock_cavalier"
const C_ARMORED := "v2_unit_armored_cavalier"
const C_GRIFFON := "v2_legendary_griffon_rider"
const C_CHARGE := "v2_technique_charge"
const C_RETREAT := "v2_technique_tactical_retreat"

## Cidade humana (com Estábulo) em (0,0) num grid de raio 6, um `kind` da Cavalaria no vizinho (1,0), o painel da unidade já apontando pra ele e, se
## `enemy_distance` > 0, um inimigo em guerra a essa distância da unidade (no eixo +q).
func _v2_cavalry_scene(through: int = 4, kind: String = C_CAVALIER, enemy_distance: int = 0) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[C_STABLE] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	var enemy: Unit = null
	if enemy_distance > 0:
		var data := UnitDatabase.create_unit("warrior")
		data.max_hp = 40.0
		enemy = hex_grid.spawn_unit(Vector2i(1 + enemy_distance, 0), data, rival)
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "rival": rival, "city": city, "unit": unit, "enemy": enemy, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_cavalry_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.rival.release_relations()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_stable_and_order_buttons_follow_n2_and_n8():
	var scene := _v2_city_scene()
	var stable_button: Button = hud._building_buttons[C_STABLE]
	var order_button: Button = hud._building_buttons[C_ORDER]
	assert_false(stable_button.visible, "sem a pesquisa o Estábulo de Guerra não aparece")
	assert_false(order_button.visible)
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(stable_button.visible, "N2 libera o Estábulo de Guerra")
	assert_eq(stable_button.text, "Estábulo de Guerra  —  22 PP")
	assert_false(order_button.visible)
	for n in range(3, 9):
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	scene.city.buildings[C_STABLE] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(order_button.visible, "N8 libera a Ordem da Cavalaria")
	assert_eq(order_button.text, "Ordem da Cavalaria  —  55 PP")
	assert_false(order_button.disabled)
	_v2_city_scene_cleanup(scene)

func test_the_order_button_is_disabled_with_the_reason_when_the_stable_is_missing():
	var scene := _v2_city_scene()
	for n in range(1, 9):
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var order_button: Button = hud._building_buttons[C_ORDER]
	assert_true(order_button.visible)
	assert_true(order_button.disabled)
	assert_true(order_button.tooltip_text.contains("Estábulo de Guerra"), order_button.tooltip_text)
	_v2_city_scene_cleanup(scene)

func test_the_cavalry_production_shows_exactly_one_form_at_each_research_level():
	var scene := _v2_city_scene()
	scene.city.buildings[C_STABLE] = true
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
	var expected := {3: [C_CAVALIER, "Cavaleiro  —  24 PP"], 5: [C_SHOCK, "Cavaleiro de Choque  —  38 PP"], 7: [C_ARMORED, "Cavaleiro Blindado  —  56 PP"]}
	var done := 2
	for through in expected:
		for n in range(done + 1, through + 1):
			scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
		done = through
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		var visible_forms: Array = [C_CAVALIER, C_SHOCK, C_ARMORED].filter(func(k): return (hud._production_buttons[k] as Button).visible)
		assert_eq(visible_forms, [expected[through][0]], "até N%d só uma forma" % through)
		assert_eq((hud._production_buttons[expected[through][0]] as Button).text, expected[through][1])
	_v2_city_scene_cleanup(scene)

func test_the_griffon_button_shows_in_the_order_city_and_is_disabled_by_any_other_legendary():
	var scene := _v2_city_scene()
	for n in range(1, 10):
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	scene.city.buildings[C_STABLE] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var button: Button = hud._production_buttons[C_GRIFFON]
	assert_false(button.visible, "sem a Ordem na cidade")
	scene.city.buildings[C_ORDER] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible)
	assert_false(button.disabled)
	assert_eq(button.text, "Cavaleiro de Grifo  —  100 PP")
	assert_true((hud._production_buttons[C_ARMORED] as Button).visible, "o Cavaleiro Blindado segue ao lado")
	for other_kind in ["v2_legendary_guardian_champion", "v2_legendary_blade_hero", "v2_legendary_legend_hunter"]:
		var other: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit(other_kind), scene.human)
		assert_not_null(other)
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		assert_true(button.visible, "o único impedimento é o slot")
		assert_true(button.disabled, "%s ativo ocupa o slot ÚNICO" % other_kind)
		assert_true(button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), button.tooltip_text)
		scene.hex_grid.remove_unit(other)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.disabled, "sem nenhuma outra Lendária o slot está livre")
	hud._on_produce_pressed(C_GRIFFON)
	assert_eq(scene.city.production_item, C_GRIFFON)
	_v2_city_scene_cleanup(scene)

func test_the_charge_button_shows_the_multiplier_and_the_no_target_reason():
	var scene := _v2_cavalry_scene(4, C_CAVALIER, 0)
	var button := _v2_action("Technique_" + C_CHARGE)
	assert_not_null(button, "Carga listada a partir do N4")
	assert_eq(button.text, "Carga ×1.5")
	assert_true(button.disabled, "sem inimigo ao alcance")
	assert_true(button.tooltip_text.contains("Nenhum inimigo ao alcance."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("2 a 4 tiles"), button.tooltip_text)
	assert_null(_v2_action("Technique_" + C_RETREAT), "a Retirada Tática só a partir do N6")
	assert_true(hud.unit_info_label.text.contains("Mov"), "o painel mostra o movimento")
	_v2_cavalry_scene_cleanup(scene)

func test_the_charge_is_enabled_with_an_enemy_at_distance_3_and_enters_the_targeting_state():
	var scene := _v2_cavalry_scene(4, C_CAVALIER, 3)
	var button := _v2_action("Technique_" + C_CHARGE)
	assert_false(button.disabled, "a 3 tiles: dentro da janela de 2 a 4")
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, C_CHARGE)
	assert_eq(SelectionManager.technique_target_coords, [(scene.enemy as Unit).coord])
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Carga (ESC cancela) «"), hud.unit_info_label.text)
	assert_eq((scene.unit as Unit).coord, Vector2i(1, 0), "a mira não move a unidade")
	assert_false((scene.unit as Unit).magic_cooldowns.has(C_CHARGE), "a mira não gasta a recarga")
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o"), "ao cancelar a dica some")
	_v2_cavalry_scene_cleanup(scene)

func test_an_adjacent_enemy_disables_the_charge_with_the_clear_reason_and_one_at_distance_5_is_out_of_reach():
	var adjacent := _v2_cavalry_scene(4, C_CAVALIER, 1)
	var button := _v2_action("Technique_" + C_CHARGE)
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Requer espaço para realizar a Carga."), button.tooltip_text)
	_v2_cavalry_scene_cleanup(adjacent)
	var far := _v2_cavalry_scene(4, C_CAVALIER, 5)
	assert_true(_v2_action("Technique_" + C_CHARGE).disabled)
	_v2_cavalry_scene_cleanup(far)

func test_after_a_charge_the_button_shows_the_cooldown_and_is_disabled():
	var scene := _v2_cavalry_scene(4, C_CAVALIER, 3)
	var unit: Unit = scene.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, C_CHARGE, scene.enemy, scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + C_CHARGE)
	assert_eq(button.text, "Carga ×1.5 (recarga 3)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 3 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Carga — recarga: 3 turno(s)"))
	_v2_cavalry_scene_cleanup(scene)

func test_the_retreat_button_appears_from_n6_is_enabled_without_enemies_and_enters_the_tile_targeting_state():
	var scene := _v2_cavalry_scene(6, C_CAVALIER, 0)
	var button := _v2_action("Technique_" + C_RETREAT)
	assert_not_null(button)
	assert_eq(button.text, "Retirada Tática")
	assert_false(button.disabled, "não precisa de inimigo")
	assert_true(button.tooltip_text.contains("+20%"), button.tooltip_text)
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, C_RETREAT, "a Retirada tem mira de tile")
	assert_false(SelectionManager.technique_target_coords.is_empty())
	assert_false((scene.unit as Unit).coord in SelectionManager.technique_target_coords)
	assert_true(hud.unit_info_label.text.contains("» Escolha o tile de Retirada Tática (ESC cancela) «"), hud.unit_info_label.text)
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o"))
	_v2_cavalry_scene_cleanup(scene)

func test_after_a_retreat_the_button_shows_active_then_the_cooldown_and_the_panel_lists_the_effect():
	var scene := _v2_cavalry_scene(6, C_CAVALIER, 0)
	var unit: Unit = scene.unit
	var tiles := V2TechniqueRuntime.relocation_tiles(unit, V2DoctrineTechniqueDatabase.get_technique(C_RETREAT), scene.hex_grid)
	assert_true(V2TechniqueRuntime.relocate(unit, C_RETREAT, tiles[0], scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + C_RETREAT)
	assert_eq(button.text, "Retirada Tática — Ativa")
	assert_true(button.disabled)
	assert_true(hud.unit_info_label.text.contains("Retirada Tática"), hud.unit_info_label.text)
	TurnManager.turn_number = 6
	V2TechniqueRuntime.expire_finished(scene.human)
	hud._on_unit_selected(unit)
	assert_eq(_v2_action("Technique_" + C_RETREAT).text, "Retirada Tática (recarga 3)")
	_v2_cavalry_scene_cleanup(scene)

func test_the_upgrade_buttons_show_the_generic_formula_cost_for_the_shock_and_the_armored():
	var scene := _v2_cavalry_scene(5, C_CAVALIER, 0)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Cavaleiro de Choque — 28 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq((scene.unit as Unit).unit_data.visual_kind, C_SHOCK)
	assert_eq(scene.human.gold, 72.0)
	_v2_cavalry_scene_cleanup(scene)
	var second := _v2_cavalry_scene(7, C_SHOCK, 0)
	var next_button := _v2_action("UpgradeButton")
	assert_eq(next_button.text, "Evoluir para Cavaleiro Blindado — 36 Ouro")
	_v2_cavalry_scene_cleanup(second)

func test_the_armored_panel_has_no_upgrade_both_techniques_and_no_legendary_label():
	var scene := _v2_cavalry_scene(7, C_ARMORED, 0)
	assert_null(_v2_action("UpgradeButton"), "fim da linha convencional")
	assert_not_null(_v2_action("Technique_" + C_CHARGE))
	assert_not_null(_v2_action("Technique_" + C_RETREAT))
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	assert_false(hud.unit_info_label.text.contains("Vulnerável"), "só o Grifo tem a vulnerabilidade")
	_v2_cavalry_scene_cleanup(scene)

func test_the_griffon_panel_shows_legendary_the_ranged_vulnerability_and_both_technique_buttons():
	var scene := _v2_cavalry_scene(9, C_GRIFFON, 0)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Cavaleiro de Grifo"), text)
	assert_true(text.contains("HP 36/36"), text)
	assert_true(text.contains("Ataque 10.0"), text)
	assert_true(text.contains("Defesa 6.5"), text)
	assert_true(text.contains("Vulnerável a ataques à distância: +25% de dano recebido."), text)
	assert_true(text.contains("Voo tático: atravessa terreno e unidades; pousa só em terra livre."), "o painel diz que voa: %s" % text)
	assert_false(text.contains("Execução"), "a Execução é do Herói da Lâmina")
	assert_false(text.contains("Caçada"), "a Caçada é do Caçador de Lendas")
	assert_not_null(_v2_action("Technique_" + C_CHARGE))
	assert_not_null(_v2_action("Technique_" + C_RETREAT))
	assert_null(_v2_action("UpgradeButton"), "o Cavaleiro de Grifo não evolui")
	_v2_cavalry_scene_cleanup(scene)

func test_the_flying_units_selection_shows_the_flight_reach_not_the_ground_reach():
	var scene := _v2_cavalry_scene(9, C_GRIFFON, 0)
	_set_mountain_ring(scene.hex_grid, Vector2i(1, 0))
	SelectionManager._select_unit(scene.unit)
	assert_eq(SelectionManager.reachable, scene.hex_grid.flight_reachable(scene.unit, scene.unit.movement_left), "o alcance destacado é o do voo")
	assert_true(SelectionManager.reachable.size() > 0, "cercado de montanhas, o Grifo ainda tem por onde ir")
	_v2_cavalry_scene_cleanup(scene)

func _set_mountain_ring(grid: HexGrid, center: Vector2i) -> void:
	for coord in grid.get_neighbors(center):
		if grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null:
			grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.MOUNTAINS)

func test_the_other_doctrines_panels_are_not_touched_by_the_cavalry_content():
	var scene := _v2_ranger_scene(9, R_LEGEND)
	assert_null(_v2_action("Technique_" + C_CHARGE), "o Patrulheiro não recebe técnicas da Cavalaria")
	assert_false(hud.unit_info_label.text.contains("Vulnerável"))
	_v2_ranger_scene_cleanup(scene)
	var guardian_scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_null(_v2_action("Technique_" + C_RETREAT))
	_v2_unit_scene_cleanup(guardian_scene)

# --- Aetherlands V2, Fase 10: Doutrina do Ladino na produção e no painel da unidade -----------------------------------------

const RG_GUILD := "v2_building_rogue_guild"
const RG_MASTERY := "v2_building_rogue_mastery"
const RG_ROGUE := "v2_unit_rogue"
const RG_SABOTEUR := "v2_unit_saboteur"
const RG_ASSASSIN := "v2_unit_assassin"
const RG_SHADOW := "v2_legendary_shadow_master"
const RG_SNEAK := "v2_technique_sneak_attack"
const RG_DISMANTLE := "v2_technique_dismantle"

## Cidade humana (com Guilda) em (0,0) num grid de raio 6, um `kind` do Ladino no vizinho (1,0), o painel da unidade já apontando pra ele e, se
## `enemy_distance` > 0, um inimigo em guerra a essa distância da unidade (no eixo +q).
func _v2_rogue_scene(through: int = 4, kind: String = RG_ROGUE, enemy_distance: int = 0) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[RG_GUILD] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	var enemy: Unit = null
	if enemy_distance > 0:
		var data := UnitDatabase.create_unit("warrior")
		data.max_hp = 40.0
		enemy = hex_grid.spawn_unit(Vector2i(1 + enemy_distance, 0), data, rival)
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "rival": rival, "city": city, "unit": unit, "enemy": enemy, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_rogue_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.rival.release_relations()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_guild_and_refuge_buttons_follow_n2_and_n8():
	var scene := _v2_city_scene()
	var guild_button: Button = hud._building_buttons[RG_GUILD]
	var refuge_button: Button = hud._building_buttons[RG_MASTERY]
	assert_false(guild_button.visible, "sem a pesquisa a Guilda dos Ladinos não aparece")
	assert_false(refuge_button.visible)
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(guild_button.visible, "N2 libera a Guilda dos Ladinos")
	assert_eq(guild_button.text, "Guilda dos Ladinos  —  22 PP")
	assert_false(refuge_button.visible)
	for n in range(3, 9):
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	scene.city.buildings[RG_GUILD] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(refuge_button.visible, "N8 libera o Refúgio das Sombras")
	assert_eq(refuge_button.text, "Refúgio das Sombras  —  55 PP")
	assert_false(refuge_button.disabled)
	_v2_city_scene_cleanup(scene)

func test_the_refuge_button_is_disabled_with_the_reason_when_the_guild_is_missing():
	var scene := _v2_city_scene()
	for n in range(1, 9):
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var refuge_button: Button = hud._building_buttons[RG_MASTERY]
	assert_true(refuge_button.visible)
	assert_true(refuge_button.disabled)
	assert_true(refuge_button.tooltip_text.contains("Guilda dos Ladinos"), refuge_button.tooltip_text)
	_v2_city_scene_cleanup(scene)

func test_the_rogue_production_shows_exactly_one_form_at_each_research_level():
	var scene := _v2_city_scene()
	scene.city.buildings[RG_GUILD] = true
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	var expected := {3: [RG_ROGUE, "Ladino  —  20 PP"], 5: [RG_SABOTEUR, "Sabotador  —  32 PP"], 7: [RG_ASSASSIN, "Assassino  —  48 PP"]}
	var done := 2
	for through in expected:
		for n in range(done + 1, through + 1):
			scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
		done = through
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		var visible_forms: Array = [RG_ROGUE, RG_SABOTEUR, RG_ASSASSIN].filter(func(k): return (hud._production_buttons[k] as Button).visible)
		assert_eq(visible_forms, [expected[through][0]], "até N%d só uma forma" % through)
		assert_eq((hud._production_buttons[expected[through][0]] as Button).text, expected[through][1])
	_v2_city_scene_cleanup(scene)

func test_the_shadow_master_button_shows_in_the_refuge_city_and_is_disabled_by_any_other_legendary():
	var scene := _v2_city_scene()
	for n in range(1, 10):
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	scene.city.buildings[RG_GUILD] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var button: Button = hud._production_buttons[RG_SHADOW]
	assert_false(button.visible, "sem o Refúgio na cidade")
	scene.city.buildings[RG_MASTERY] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible)
	assert_false(button.disabled)
	assert_eq(button.text, "Mestre das Sombras  —  95 PP")
	assert_true((hud._production_buttons[RG_ASSASSIN] as Button).visible, "o Assassino segue ao lado")
	for other_kind in ["v2_legendary_guardian_champion", "v2_legendary_blade_hero", "v2_legendary_legend_hunter", "v2_legendary_griffon_rider"]:
		var other: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit(other_kind), scene.human)
		assert_not_null(other)
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		assert_true(button.visible, "o único impedimento é o slot")
		assert_true(button.disabled, "%s ativo ocupa o slot ÚNICO" % other_kind)
		assert_true(button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), button.tooltip_text)
		scene.hex_grid.remove_unit(other)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.disabled, "sem nenhuma outra Lendária o slot está livre")
	hud._on_produce_pressed(RG_SHADOW)
	assert_eq(scene.city.production_item, RG_SHADOW)
	_v2_city_scene_cleanup(scene)

func test_the_sneak_attack_button_shows_the_multiplier_and_the_no_target_reason():
	var scene := _v2_rogue_scene(4, RG_ROGUE, 0)
	var button := _v2_action("Technique_" + RG_SNEAK)
	assert_not_null(button, "Ataque Furtivo listado a partir do N4")
	assert_eq(button.text, "Ataque Furtivo ×1.35")
	assert_true(button.disabled, "sem inimigo adjacente")
	assert_true(button.tooltip_text.contains("Nenhum inimigo adjacente."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("Ignora 40% da Defesa do alvo."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("O alvo não revida este golpe."), button.tooltip_text)
	assert_null(_v2_action("Technique_" + RG_DISMANTLE), "Desmantelar é PASSIVA: nunca vira botão")
	_v2_rogue_scene_cleanup(scene)

func test_the_sneak_attack_is_enabled_with_an_adjacent_enemy_and_enters_the_targeting_state():
	var scene := _v2_rogue_scene(4, RG_ROGUE, 1)
	var button := _v2_action("Technique_" + RG_SNEAK)
	assert_false(button.disabled, "inimigo adjacente")
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, RG_SNEAK)
	assert_eq(SelectionManager.technique_target_coords, [(scene.enemy as Unit).coord])
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Ataque Furtivo (ESC cancela) «"), hud.unit_info_label.text)
	assert_eq((scene.unit as Unit).coord, Vector2i(1, 0), "a mira não move a unidade")
	assert_false((scene.unit as Unit).magic_cooldowns.has(RG_SNEAK), "a mira não gasta a recarga")
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o"), "ao cancelar a dica some")
	_v2_rogue_scene_cleanup(scene)

func test_after_a_sneak_attack_the_button_shows_the_cooldown_and_is_disabled():
	var scene := _v2_rogue_scene(4, RG_ROGUE, 1)
	var unit: Unit = scene.unit
	assert_true(V2TechniqueRuntime.perform_strike(unit, RG_SNEAK, scene.enemy, scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + RG_SNEAK)
	assert_eq(button.text, "Ataque Furtivo ×1.35 (recarga 3)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 3 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Ataque Furtivo — recarga: 3 turno(s)"))
	_v2_rogue_scene_cleanup(scene)

func test_the_dismantle_passive_appears_from_n6_with_no_button_on_every_form():
	var scene := _v2_rogue_scene(5, RG_ROGUE, 0)
	assert_false(hud.unit_info_label.text.contains("Desmantelar"), "antes do N6")
	_v2_rogue_scene_cleanup(scene)
	var after := _v2_rogue_scene(6, RG_ROGUE, 0)
	assert_true(after.human.v2_research.is_completed("v2_doctrine_rogue_6"))
	assert_true(hud.unit_info_label.text.contains("Passiva — Desmantelar"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("+50% de dano de ataque básico contra conjuradores ou unidades de Cerco"), hud.unit_info_label.text)
	assert_null(_v2_action("Technique_" + RG_DISMANTLE), "sem botão")
	_v2_rogue_scene_cleanup(after)

func test_the_upgrade_buttons_show_the_generic_formula_cost_for_the_saboteur_and_the_assassin():
	var scene := _v2_rogue_scene(5, RG_ROGUE, 0)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Sabotador — 24 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq((scene.unit as Unit).unit_data.visual_kind, RG_SABOTEUR)
	assert_eq(scene.human.gold, 76.0)
	_v2_rogue_scene_cleanup(scene)
	var second := _v2_rogue_scene(7, RG_SABOTEUR, 0)
	var next_button := _v2_action("UpgradeButton")
	assert_eq(next_button.text, "Evoluir para Assassino — 32 Ouro")
	_v2_rogue_scene_cleanup(second)

func test_the_assassin_panel_has_no_upgrade_both_techniques_and_no_legendary_label():
	var scene := _v2_rogue_scene(7, RG_ASSASSIN, 0)
	assert_null(_v2_action("UpgradeButton"), "fim da linha convencional")
	assert_not_null(_v2_action("Technique_" + RG_SNEAK))
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	assert_false(hud.unit_info_label.text.contains("Passo Sombrio"), "só o Mestre das Sombras é INFILTRATOR")
	_v2_rogue_scene_cleanup(scene)

func test_the_shadow_master_panel_shows_legendary_the_infiltration_text_and_both_technique_buttons():
	var scene := _v2_rogue_scene(9, RG_SHADOW, 0)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Mestre das Sombras"), text)
	assert_true(text.contains("HP 30/30"), text)
	assert_true(text.contains("Ataque 10.5"), text)
	assert_true(text.contains("Defesa 4.5"), text)
	assert_true(text.contains("Passo Sombrio: atravessa unidades e ignora custo extra de terreno terrestre; não atravessa terreno impassável."), text)
	assert_false(text.to_lower().contains("voo"), "nunca menciona voo")
	assert_true(text.contains("Passiva — Desmantelar"), "herda Desmantelar (N6 pesquisado no cenário)")
	assert_false(text.contains("Execução"), "a Execução é do Herói da Lâmina")
	assert_false(text.contains("Caçada"), "a Caçada é do Caçador de Lendas")
	assert_not_null(_v2_action("Technique_" + RG_SNEAK))
	assert_null(_v2_action("Technique_" + RG_DISMANTLE), "Desmantelar é passiva")
	assert_null(_v2_action("UpgradeButton"), "o Mestre das Sombras não evolui")
	_v2_rogue_scene_cleanup(scene)

func test_the_shadow_master_selection_shows_the_infiltration_reach_not_the_ground_reach():
	var scene := _v2_rogue_scene(9, RG_SHADOW, 0)
	for coord in scene.hex_grid.get_neighbors(Vector2i(1, 0)):
		if scene.hex_grid.get_unit_at(coord) == null and coord != Vector2i(2, 0):
			scene.hex_grid.spawn_unit(coord, UnitDatabase.create_unit("v2_unit_warrior"), scene.human)
	SelectionManager._select_unit(scene.unit)
	assert_eq(SelectionManager.reachable, scene.hex_grid.infiltrate_reachable(scene.unit, scene.unit.movement_left), "o alcance destacado é o da infiltração")
	assert_true(SelectionManager.reachable.has(Vector2i(2, 0)), "atravessa a própria guarnição ao redor")
	_v2_rogue_scene_cleanup(scene)

func test_the_other_doctrines_panels_are_not_touched_by_the_rogue_content():
	var scene := _v2_cavalry_scene(9, C_GRIFFON)
	assert_null(_v2_action("Technique_" + RG_SNEAK), "a Cavalaria não recebe técnicas do Ladino")
	assert_false(hud.unit_info_label.text.contains("Passo Sombrio"))
	_v2_cavalry_scene_cleanup(scene)
	var guardian_scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_null(_v2_action("Technique_" + RG_SNEAK))
	assert_false(hud.unit_info_label.text.contains("Desmantelar"))
	_v2_unit_scene_cleanup(guardian_scene)

const SG_ARSENAL := "v2_building_siege_arsenal"
const SG_GRAND := "v2_building_grand_arsenal"
const SG_CATAPULT := "v2_unit_catapult"
const SG_TREBUCHET := "v2_unit_trebuchet"
const SG_BOMBARD := "v2_unit_bombard"
const SG_COLOSSUS := "v2_legendary_siege_colossus"
const SG_DEMOLITION := "v2_technique_demolition_ammo"
const SG_BOMBARDMENT := "v2_technique_prepared_bombardment"

## Cidade humana (com Arsenal) em (0,0) num grid de raio 6, um `kind` de Cerco no vizinho (1,0), o painel da unidade já apontando pra ele e, se
## `enemy_city_distance` > 0, uma cidade INIMIGA a essa distância da unidade (no eixo +q) — alvo de Bombardeio Preparado.
func _v2_siege_scene(through: int = 4, kind: String = SG_CATAPULT, enemy_city_distance: int = 0) -> Dictionary:
	var original_hex_grid = GameManager.hex_grid
	var original_turn := TurnManager.turn_number
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	for q in range(-6, 7):
		for r in range(-6, 7):
			if absi(q + r) <= 6:
				hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := PlayerData.new(CivilizationData.new())
	human.gold = 100.0
	for n in range(1, through + 1):
		human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	GameManager.human_player = human
	GameManager.hex_grid = hex_grid
	TurnManager.turn_number = 5
	var rival := PlayerData.new(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city: City = hex_grid.found_city(Vector2i(0, 0), human, "Capital", true)
	city.buildings[SG_ARSENAL] = true
	var unit := hex_grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(kind), human)
	var enemy_city: City = null
	if enemy_city_distance > 0:
		enemy_city = City.new()
		enemy_city.owner_player = rival
		enemy_city.coord = Vector2i(1 + enemy_city_distance, 0)
		enemy_city.city_name = "Cidade Inimiga"
		enemy_city.hp = enemy_city.max_hp()
		hex_grid.cities_by_coord[enemy_city.coord] = enemy_city
	SelectionManager.selected_unit = unit
	hud._on_unit_selected(unit)
	return {"hex_grid": hex_grid, "human": human, "rival": rival, "city": city, "unit": unit, "enemy_city": enemy_city, "original_hex_grid": original_hex_grid, "original_turn": original_turn}

func _v2_siege_scene_cleanup(scene: Dictionary) -> void:
	SelectionManager.selected_unit = null
	SelectionManager.reset()
	TurnManager.turn_number = scene.original_turn
	scene.human.release_relations()
	scene.rival.release_relations()
	if scene.enemy_city != null and is_instance_valid(scene.enemy_city):
		scene.enemy_city.free()
	scene.hex_grid.queue_free()
	GameManager.hex_grid = scene.original_hex_grid

func test_the_arsenal_and_grand_arsenal_buttons_follow_n2_and_n8():
	var scene := _v2_city_scene()
	var arsenal_button: Button = hud._building_buttons[SG_ARSENAL]
	var grand_button: Button = hud._building_buttons[SG_GRAND]
	assert_false(arsenal_button.visible, "sem a pesquisa o Arsenal de Cerco não aparece")
	assert_false(grand_button.visible)
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(arsenal_button.visible, "N2 libera o Arsenal de Cerco")
	assert_eq(arsenal_button.text, "Arsenal de Cerco  —  22 PP")
	assert_false(grand_button.visible)
	for n in range(3, 9):
		scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	scene.city.buildings[SG_ARSENAL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(grand_button.visible, "N8 libera o Grande Arsenal")
	assert_eq(grand_button.text, "Grande Arsenal  —  55 PP")
	assert_false(grand_button.disabled)
	_v2_city_scene_cleanup(scene)

func test_the_grand_arsenal_button_is_disabled_with_the_reason_when_the_arsenal_is_missing():
	var scene := _v2_city_scene()
	for n in range(1, 9):
		scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var grand_button: Button = hud._building_buttons[SG_GRAND]
	assert_true(grand_button.visible)
	assert_true(grand_button.disabled)
	assert_true(grand_button.tooltip_text.contains("Arsenal de Cerco"), grand_button.tooltip_text)
	_v2_city_scene_cleanup(scene)

func test_the_siege_production_shows_exactly_one_form_at_each_research_level():
	var scene := _v2_city_scene()
	scene.city.buildings[SG_ARSENAL] = true
	for n in range(1, 3):
		scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
	var expected := {3: [SG_CATAPULT, "Catapulta  —  28 PP"], 5: [SG_TREBUCHET, "Trebuchet  —  44 PP"], 7: [SG_BOMBARD, "Bombarda  —  64 PP"]}
	var done := 2
	for through in expected:
		for n in range(done + 1, through + 1):
			scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
		done = through
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		var visible_forms: Array = [SG_CATAPULT, SG_TREBUCHET, SG_BOMBARD].filter(func(k): return (hud._production_buttons[k] as Button).visible)
		assert_eq(visible_forms, [expected[through][0]], "até N%d só uma forma" % through)
		assert_eq((hud._production_buttons[expected[through][0]] as Button).text, expected[through][1])
	_v2_city_scene_cleanup(scene)

func test_the_colossus_button_shows_in_the_grand_arsenal_city_and_is_disabled_by_any_other_legendary():
	var scene := _v2_city_scene()
	for n in range(1, 10):
		scene.human.v2_research.complete_research("v2_doctrine_siege_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_ranger_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
		scene.human.v2_research.complete_research("v2_doctrine_rogue_%d" % n)
	scene.city.buildings[SG_ARSENAL] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	var button: Button = hud._production_buttons[SG_COLOSSUS]
	assert_false(button.visible, "sem o Grande Arsenal na cidade")
	scene.city.buildings[SG_GRAND] = true
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_true(button.visible)
	assert_false(button.disabled)
	assert_eq(button.text, "Colosso de Cerco  —  110 PP")
	assert_true((hud._production_buttons[SG_BOMBARD] as Button).visible, "a Bombarda segue ao lado")
	for other_kind in ["v2_legendary_guardian_champion", "v2_legendary_blade_hero", "v2_legendary_legend_hunter", "v2_legendary_griffon_rider", "v2_legendary_shadow_master"]:
		var other: Unit = scene.hex_grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit(other_kind), scene.human)
		assert_not_null(other)
		hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
		assert_true(button.visible, "o único impedimento é o slot")
		assert_true(button.disabled, "%s ativo ocupa o slot ÚNICO" % other_kind)
		assert_true(button.tooltip_text.contains("Já existe uma Unidade Lendária ativa ou em treinamento nesta civilização."), button.tooltip_text)
		scene.hex_grid.remove_unit(other)
	hud._on_tile_selected(scene.coord, scene.hex_grid.get_tile(scene.coord))
	assert_false(button.disabled, "sem nenhuma outra Lendária o slot está livre")
	hud._on_produce_pressed(SG_COLOSSUS)
	assert_eq(scene.city.production_item, SG_COLOSSUS)
	_v2_city_scene_cleanup(scene)

func test_the_demolition_ammo_passive_appears_from_n4_with_no_button_on_every_form():
	var scene := _v2_siege_scene(3, SG_CATAPULT, 0)
	assert_false(hud.unit_info_label.text.contains("Munição Demolidora"), "antes do N4")
	_v2_siege_scene_cleanup(scene)
	var after := _v2_siege_scene(4, SG_CATAPULT, 0)
	assert_true(after.human.v2_research.is_completed("v2_doctrine_siege_4"))
	assert_true(hud.unit_info_label.text.contains("Passiva — Munição Demolidora"), hud.unit_info_label.text)
	assert_true(hud.unit_info_label.text.contains("+40% de dano de ataque contra cidades e fortificações"), hud.unit_info_label.text)
	assert_null(_v2_action("Technique_" + SG_DEMOLITION), "sem botão")
	_v2_siege_scene_cleanup(after)

func test_the_prepared_bombardment_button_shows_the_multiplier_and_the_no_target_reason():
	var scene := _v2_siege_scene(6, SG_CATAPULT, 0)
	var button := _v2_action("Technique_" + SG_BOMBARDMENT)
	assert_not_null(button, "Bombardeio Preparado listado a partir do N6")
	assert_eq(button.text, "Bombardeio Preparado ×1.5")
	assert_true(button.disabled, "sem cidade hostil ao alcance")
	assert_true(button.tooltip_text.contains("Nenhuma cidade hostil ao alcance."), button.tooltip_text)
	assert_true(button.tooltip_text.contains("cidade ou fortificação"), button.tooltip_text)
	assert_true(button.tooltip_text.contains("Exige que a unidade não tenha se movido neste turno."), button.tooltip_text)
	assert_null(_v2_action("Technique_" + SG_DEMOLITION), "Munição Demolidora é PASSIVA: nunca vira botão")
	_v2_siege_scene_cleanup(scene)

func test_the_prepared_bombardment_is_enabled_with_a_hostile_city_in_range_and_enters_the_targeting_state():
	var scene := _v2_siege_scene(6, SG_CATAPULT, 2) # alcance básico (2) + 1 = 3; cidade a distância 3
	var button := _v2_action("Technique_" + SG_BOMBARDMENT)
	assert_false(button.disabled, "cidade hostil ao alcance")
	button.pressed.emit()
	assert_eq(SelectionManager.technique_targeting_id, SG_BOMBARDMENT)
	assert_eq(SelectionManager.technique_target_coords, [(scene.enemy_city as City).coord])
	assert_true(hud.unit_info_label.text.contains("» Escolha o alvo de Bombardeio Preparado (ESC cancela) «"), hud.unit_info_label.text)
	assert_eq((scene.unit as Unit).coord, Vector2i(1, 0), "a mira não move a unidade")
	assert_false((scene.unit as Unit).magic_cooldowns.has(SG_BOMBARDMENT), "a mira não gasta a recarga")
	assert_true(SelectionManager.cancel_technique_targeting())
	assert_false(hud.unit_info_label.text.contains("Escolha o"), "ao cancelar a dica some")
	_v2_siege_scene_cleanup(scene)

func test_a_unit_that_moved_shows_the_stationary_requirement_reason():
	var scene := _v2_siege_scene(6, SG_CATAPULT, 2)
	var unit: Unit = scene.unit
	unit.movement_left = unit.unit_data.movement_points - 0.5
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + SG_BOMBARDMENT)
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Bombardeio Preparado exige que a unidade não tenha se movido neste turno."), button.tooltip_text)
	_v2_siege_scene_cleanup(scene)

func test_after_a_prepared_bombardment_the_button_shows_the_cooldown_and_is_disabled():
	var scene := _v2_siege_scene(6, SG_CATAPULT, 2)
	var unit: Unit = scene.unit
	assert_true(V2TechniqueRuntime.perform_city_strike(unit, SG_BOMBARDMENT, scene.enemy_city, scene.hex_grid))
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + SG_BOMBARDMENT)
	assert_eq(button.text, "Bombardeio Preparado ×1.5 (recarga 4)")
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains("Em recarga: 4 turno(s)."), button.tooltip_text)
	assert_true(hud.unit_info_label.text.contains("Bombardeio Preparado — recarga: 4 turno(s)"))
	_v2_siege_scene_cleanup(scene)

func test_the_upgrade_buttons_show_the_generic_formula_cost_for_the_trebuchet_and_the_bombard():
	var scene := _v2_siege_scene(5, SG_CATAPULT, 0)
	var button := _v2_action("UpgradeButton")
	assert_not_null(button)
	assert_eq(button.text, "Evoluir para Trebuchet — 32 Ouro")
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq((scene.unit as Unit).unit_data.visual_kind, SG_TREBUCHET)
	assert_eq(scene.human.gold, 68.0)
	_v2_siege_scene_cleanup(scene)
	var second := _v2_siege_scene(7, SG_TREBUCHET, 0)
	var next_button := _v2_action("UpgradeButton")
	assert_eq(next_button.text, "Evoluir para Bombarda — 40 Ouro")
	_v2_siege_scene_cleanup(second)

func test_the_bombard_panel_has_no_upgrade_both_techniques_and_no_legendary_label():
	var scene := _v2_siege_scene(7, SG_BOMBARD, 0)
	assert_null(_v2_action("UpgradeButton"), "fim da linha convencional")
	assert_not_null(_v2_action("Technique_" + SG_BOMBARDMENT))
	assert_false(hud.unit_info_label.text.contains("LENDÁRIO"))
	assert_false(hud.unit_info_label.text.contains("Artilharia Andante"), "só o Colosso de Cerco ignora o requisito de preparação")
	_v2_siege_scene_cleanup(scene)

func test_the_colossus_panel_shows_legendary_the_artillery_march_text_and_both_technique_buttons():
	var scene := _v2_siege_scene(9, SG_COLOSSUS, 0)
	var text: String = hud.unit_info_label.text
	assert_true(text.begins_with("LENDÁRIO"), text)
	assert_true(text.contains("Colosso de Cerco"), text)
	assert_true(text.contains("HP 44/44"), text)
	assert_true(text.contains("Ataque 9.0"), text)
	assert_true(text.contains("Defesa 8.0"), text)
	assert_true(text.contains("Passiva — Munição Demolidora"), "herda Munição Demolidora (N4 pesquisado no cenário)")
	assert_true(text.contains("Passiva Lendária — Artilharia Andante"), text)
	assert_true(text.contains("Pode usar Bombardeio Preparado mesmo depois de se mover."), text)
	assert_false(text.contains("Execução"), "a Execução é do Herói da Lâmina")
	assert_false(text.contains("Caçada"), "a Caçada é do Caçador de Lendas")
	assert_false(text.contains("Passo Sombrio"), "não é INFILTRATOR")
	assert_false(text.to_lower().contains(" voo"), "nunca menciona voo")
	assert_not_null(_v2_action("Technique_" + SG_BOMBARDMENT))
	assert_null(_v2_action("Technique_" + SG_DEMOLITION), "Munição Demolidora é passiva")
	assert_null(_v2_action("UpgradeButton"), "o Colosso de Cerco não evolui")
	_v2_siege_scene_cleanup(scene)

func test_the_colossus_can_use_the_bombardment_button_after_moving_the_bombard_cannot():
	var scene := _v2_siege_scene(9, SG_COLOSSUS, 2)
	var unit: Unit = scene.unit
	unit.movement_left = unit.unit_data.movement_points - 0.5
	hud._on_unit_selected(unit)
	var button := _v2_action("Technique_" + SG_BOMBARDMENT)
	assert_false(button.disabled, "o Colosso ignora o requisito de preparação")
	_v2_siege_scene_cleanup(scene)

func test_the_other_doctrines_panels_are_not_touched_by_the_siege_content():
	var scene := _v2_cavalry_scene(9, C_GRIFFON)
	assert_null(_v2_action("Technique_" + SG_BOMBARDMENT), "a Cavalaria não recebe técnicas do Cerco")
	assert_false(hud.unit_info_label.text.contains("Munição Demolidora"))
	assert_false(hud.unit_info_label.text.contains("Artilharia Andante"))
	_v2_cavalry_scene_cleanup(scene)
	var guardian_scene := _v2_unit_scene(9, V2_SENTINEL)
	assert_null(_v2_action("Technique_" + SG_BOMBARDMENT))
	assert_false(hud.unit_info_label.text.contains("Unidade de Cerco"))
	_v2_unit_scene_cleanup(guardian_scene)

# --- Aetherlands V2, Fase 23: Transcendência / Ritual Final ------------------------------------

func _phase23_hud_scene() -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(7, 7, 230023)
	var human := PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Aurora"
	GameManager.human_player = human
	GameManager.rival_players = []
	GameManager.players = [human] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	var city_coord := _phase23_free_coord(grid)
	var city := grid.found_city(city_coord, human, "Lúmen", true)
	hud._on_tile_selected(city_coord, grid.get_tile(city_coord))
	return {"grid": grid, "human": human, "city": city, "units": []}

func _phase23_free_coord(grid: HexGrid) -> Vector2i:
	for coord in grid.tiles.keys():
		if grid.get_city_at(coord) == null and grid.get_unit_at(coord) == null and not grid.get_tile(coord).blocks_land_units():
			return coord
	return V2TranscendenceSystem.INVALID_COORD

func _phase23_unlock(player: PlayerData) -> void:
	for branch in ["sacred", "infernal"]:
		for tier in range(1, 10):
			player.v2_research.complete_research("v2_magic_%s_%d" % [branch, tier])
	player.v2_research.complete_research("v2_transcendence")

func _phase23_manifestation(scene: Dictionary, kind: String) -> Unit:
	var coord := _phase23_free_coord(scene.grid)
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), scene.human, coord)
	scene.human.units.append(unit)
	scene.grid.units_by_coord[coord] = unit
	scene.units.append(unit)
	return unit

func _phase23_hud_cleanup(scene: Dictionary) -> void:
	for unit in scene.units:
		if is_instance_valid(unit):
			unit.queue_free()
	scene.human.release_relations()
	scene.grid.queue_free()

func _phase23_action(scene: Dictionary, name: String) -> Node:
	return hud.tile_info_panel.get_node_or_null("TileInfoBox/V2CityActions/" + name)

func test_transcendence_city_button_is_hidden_before_access_and_explains_each_missing_requirement():
	var scene := _phase23_hud_scene()
	assert_null(_phase23_action(scene, "StartTranscendenceRitualButton"), "pré-capstone não polui o painel")
	_phase23_unlock(scene.human)
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	var button: Button = _phase23_action(scene, "StartTranscendenceRitualButton")
	assert_not_null(button)
	assert_eq(button.text, "Iniciar Ritual de Transcendência — 120 Mana")
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Esta cidade precisa de uma Estrutura Ritual pesquisada.")
	scene.city.buildings["v2_building_sacred_ritual"] = true
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	button = _phase23_action(scene, "StartTranscendenceRitualButton")
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Requer 2 Grandes Manifestações ativas (0 / 2).")
	_phase23_manifestation(scene, "v2_manifestation_seraph")
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	button = _phase23_action(scene, "StartTranscendenceRitualButton")
	assert_eq(button.tooltip_text, "Requer 2 Grandes Manifestações ativas (1 / 2).")
	_phase23_manifestation(scene, "v2_manifestation_archdemon")
	scene.human.mana = 119.0
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	button = _phase23_action(scene, "StartTranscendenceRitualButton")
	assert_true(button.disabled)
	assert_eq(button.tooltip_text, "Mana insuficiente: requer 120, disponível 119.")
	scene.human.mana = 120.0
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	button = _phase23_action(scene, "StartTranscendenceRitualButton")
	assert_false(button.disabled)
	_phase23_hud_cleanup(scene)

func test_transcendence_city_hud_starts_counts_down_and_only_site_can_cancel_without_refund():
	var scene := _phase23_hud_scene()
	_phase23_unlock(scene.human)
	scene.city.buildings["v2_building_sacred_ritual"] = true
	_phase23_manifestation(scene, "v2_manifestation_seraph")
	_phase23_manifestation(scene, "v2_manifestation_archdemon")
	scene.human.mana = 150.0
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	(_phase23_action(scene, "StartTranscendenceRitualButton") as Button).pressed.emit()
	assert_eq(scene.human.mana, 30.0)
	var status: Label = _phase23_action(scene, "TranscendenceRitualStatus")
	assert_not_null(status)
	assert_eq(status.text, "Ritual de Transcendência — 4 rodadas restantes · ATIVO")
	var cancel: Button = _phase23_action(scene, "CancelTranscendenceRitualButton")
	assert_not_null(cancel)
	assert_true(cancel.tooltip_text.contains("Mana não serão devolvidos"))
	var other_coord := _phase23_free_coord(scene.grid)
	var other: City = scene.grid.found_city(other_coord, scene.human, "Orbe", true)
	hud._on_tile_selected(other_coord, scene.grid.get_tile(other_coord))
	status = _phase23_action(scene, "TranscendenceRitualStatus")
	assert_eq(status.text, "Ritual ativo em Lúmen — 4 rodadas restantes.")
	assert_null(_phase23_action(scene, "CancelTranscendenceRitualButton"), "outra cidade só informa")
	hud._on_tile_selected(scene.city.coord, scene.grid.get_tile(scene.city.coord))
	(_phase23_action(scene, "CancelTranscendenceRitualButton") as Button).pressed.emit()
	assert_false(V2TranscendenceSystem.has_active_ritual(scene.human))
	assert_eq(scene.human.mana, 30.0, "cancelar não reembolsa")
	_phase23_hud_cleanup(scene)

func test_rival_transcendence_ritual_is_public_in_the_victory_panel_without_revealing_research():
	var scene := _phase23_hud_scene()
	var rival := PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Crepúsculo"
	GameManager.rival_players = [rival]
	GameManager.players = [scene.human, rival] as Array[PlayerData]
	_phase23_unlock(rival)
	var rival_coord := _phase23_free_coord(scene.grid)
	var rival_city: City = scene.grid.found_city(rival_coord, rival, "Umbra", true)
	rival_city.buildings["v2_building_infernal_ritual"] = true
	var rival_scene := {"grid": scene.grid, "human": rival, "units": scene.units}
	_phase23_manifestation(rival_scene, "v2_manifestation_seraph")
	_phase23_manifestation(rival_scene, "v2_manifestation_archdemon")
	rival.mana = 120.0
	assert_true(V2TranscendenceSystem.start_ritual(rival, rival_city))
	hud._refresh_victory_panel()
	var combined := ""
	for child in hud.victory_rows.get_children():
		if child is Label:
			combined += child.text + "\n"
		elif child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is Label:
			combined += child.get_child(0).text + "\n"
	assert_true(combined.contains("Transcendência"), combined)
	assert_true(combined.contains("Crepúsculo — Ritual Final em (%d, %d): 4 rodada(s) restante(s)." % [rival_coord.x, rival_coord.y]), combined)
	assert_false(V2TranscendenceSystem.has_access(scene.human), "o status público não expõe/concede pesquisa rival")
	rival.release_relations()
	_phase23_hud_cleanup(scene)

func test_rival_city_never_exposes_private_transcendence_actions():
	var scene := _phase23_hud_scene()
	var rival := PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Crepúsculo"
	GameManager.rival_players = [rival]
	GameManager.players = [scene.human, rival] as Array[PlayerData]
	_phase23_unlock(rival)
	var rival_coord := _phase23_free_coord(scene.grid)
	var rival_city: City = scene.grid.found_city(rival_coord, rival, "Umbra", true)
	rival_city.buildings["v2_building_infernal_ritual"] = true
	hud._on_tile_selected(rival_coord, scene.grid.get_tile(rival_coord))
	assert_null(_phase23_action(scene, "StartTranscendenceRitualButton"))
	assert_null(_phase23_action(scene, "CancelTranscendenceRitualButton"))
	assert_null(_phase23_action(scene, "TranscendenceRitualStatus"))
	rival.release_relations()
	_phase23_hud_cleanup(scene)

func test_transcendence_victory_screen_has_its_own_title_and_summary():
	var winner := PlayerData.new(CivilizationData.new())
	winner.civ.civ_name = "Aurora"
	assert_eq(hud.format_victory_title(winner, V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE), "Vitória por Transcendência — Aurora")
	var summary: String = hud.format_victory_summary(V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE)
	assert_true(summary.contains("Ritual Final"))
	assert_true(summary.contains("quatro rodadas"))
