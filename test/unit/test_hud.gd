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

## Estrutura: 1 label de nome + 3 linhas (Dominacao/Territorial/Arcana,
## NESSA ordem -- mesma ordem fixa de check_victories()) por jogador.
## Reusa VictoryConditions.dominance_progress de verdade (nenhum calculo
## duplicado aqui) pra confirmar que o valor chega correto na linha —
## 1 de 2 rivais eliminados da um valor exato (50%) facil de verificar
## sem precisar montar um cenario territorial/arcano.
func test_victory_panel_builds_header_and_three_rows_per_player_with_correct_values():
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

	assert_eq(hud.victory_rows.get_child_count(), 12, "3 jogadores x (1 nome + 3 linhas de progresso)")
	assert_eq(hud.victory_rows.get_child(0).text, "Reino de Teste", "primeiro bloco e sempre o humano")
	var human_dominance_row: HBoxContainer = hud.victory_rows.get_child(1)
	assert_eq(human_dominance_row.get_child(0).text, "Dominação")
	# humano: 1 de 2 rivais eliminados = 50%
	assert_eq(human_dominance_row.get_child(2).text, "50%")
	assert_almost_eq(human_dominance_row.get_child(1).value, 50.0, 0.01)
	var human_territorial_row: HBoxContainer = hud.victory_rows.get_child(2)
	assert_eq(human_territorial_row.get_child(0).text, "Domínio Territorial")
	var human_arcane_row: HBoxContainer = hud.victory_rows.get_child(3)
	assert_eq(human_arcane_row.get_child(0).text, "Ascensão Arcana")

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

	assert_eq(hud.victory_rows.get_child_count(), 4, "1 jogador (so o humano) x (1 nome + 3 linhas de progresso)")
	hex_grid.queue_free()

## Roadmap "Fase F" F6 -- tela de resultado final: titulo + resumo fixo +
## snapshot CONGELADO das 3 progressões de todos os jogadores.

func test_format_victory_title_for_each_type():
	var winner = PlayerData.new(CivilizationData.new())
	winner.civ.civ_name = "Anões"
	assert_eq(hud.format_victory_title(winner, VictoryConditions.VICTORY_TYPE_DOMINANCE), "Anões alcançou Dominação")
	assert_eq(hud.format_victory_title(winner, VictoryConditions.VICTORY_TYPE_TERRITORIAL), "Anões alcançou Domínio Territorial")
	assert_eq(hud.format_victory_title(winner, VictoryConditions.VICTORY_TYPE_ARCANE), "Anões alcançou Ascensão Arcana")

## `winner` pode ser null (debug_force_game_over(false) sem nenhum rival
## existir, ver GameManager.gd) -- nao deveria quebrar nem mostrar um
## veredito de vitoria real.
func test_format_victory_title_handles_debug_and_null_winner():
	assert_eq(hud.format_victory_title(null, VictoryConditions.VICTORY_TYPE_DEBUG), "Fim de jogo forçado (Debug)")
	assert_eq(hud.format_victory_title(null, VictoryConditions.VICTORY_TYPE_DOMINANCE), "Fim de jogo")

## Resumo e FIXO por tipo (pedido explicito do usuario) mas le as
## CONSTANTES de VictoryConditions em vez de hardcodar os numeros de novo
## -- confirma que os dois nunca podem divergir silenciosamente.
func test_format_victory_summary_reads_victoryconditions_constants():
	assert_eq(hud.format_victory_summary(VictoryConditions.VICTORY_TYPE_DOMINANCE), "Eliminou todos os reinos rivais.")
	assert_eq(hud.format_victory_summary(VictoryConditions.VICTORY_TYPE_TERRITORIAL), "Controlou pelo menos %d%% do mundo habitável por %d turnos consecutivos." % [
		int(round(VictoryConditions.TERRITORIAL_VICTORY_THRESHOLD * 100.0)), VictoryConditions.TERRITORIAL_SUSTAIN_TURNS,
	])
	assert_eq(hud.format_victory_summary(VictoryConditions.VICTORY_TYPE_ARCANE), "Pesquisou %d das 7 escolas mágicas, controlou %d Nódulos Arcanos e sustentou o Ritual do Nódulo por %d turnos." % [
		VictoryConditions.ARCANE_SCHOOLS_REQUIRED, VictoryConditions.ARCANE_NODES_REQUIRED, VictoryConditions.ARCANE_SUSTAIN_TURNS,
	])

func test_on_victory_achieved_populates_title_summary_and_snapshot():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	GameManager.hex_grid = hex_grid
	var human = PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Reino de Teste"
	GameManager.human_player = human
	GameManager.rival_players = []

	hud._on_victory_achieved(human, VictoryConditions.VICTORY_TYPE_DOMINANCE)

	assert_eq(hud.game_over_title_label.text, "Reino de Teste alcançou Dominação")
	assert_eq(hud.game_over_summary_label.text, "Eliminou todos os reinos rivais.")
	assert_eq(hud.game_over_snapshot_rows.get_child_count(), 4, "1 jogador x (1 nome + 3 linhas de progresso)")
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

func test_restart_reenables_overlay_buttons():
	hud._on_game_over(true)

	hud._on_restart_pressed()

	assert_false(hud.tech_button.disabled)
	assert_false(hud.diplomacy_button.disabled)
	assert_false(hud.grimoire_button.disabled)
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
	player.researched_magic["invocacao_espiritos"] = true # concede "Lança de Arcana"
	GameManager.human_player = player

	hud._on_grimoire_pressed()

	var spell_rows = hud.grimoire_rows.get_children().filter(func(child): return child is VBoxContainer)
	assert_eq(spell_rows.size(), 1, "Cabeçalhos de categoria não contam como feitiços.")

## Economia arcana (Ponto 3): o card do Grimorio mostra o custo de mana no
## nome e desabilita "Conjurar" quando o saldo nao alcanca, mesmo com
## cooldown zerado — pedido do usuario: "o botao Conjurar deve ficar
## desabilitado se o jogador nao tiver saldo de Mana suficiente". Chama
## _build_spell_row() direto (mesmo padrao ja usado por outros testes de
## HUD pra inspecionar nos internos sem precisar simular clique de mouse).

func test_grimoire_row_shows_the_mana_cost_next_to_the_spell_name():
	var player = PlayerData.new(CivilizationData.new())

	var row: Control = add_child_autofree(hud._build_spell_row("Lança de Arcana", player))
	var name_label: Label = row.get_child(0).get_child(0)

	assert_eq(name_label.text, "Lança de Arcana (25 mana)")

func test_grimoire_conjurar_button_disabled_without_enough_mana():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_magic["invocacao_espiritos"] = true
	player.mana = 10.0 # menos que os 25 exigidos, cooldown ja liberado

	var row: Control = add_child_autofree(hud._build_spell_row("Lança de Arcana", player))
	var cast_button: Button = row.get_child(0).get_child(1)

	assert_true(cast_button.disabled)
	assert_eq(cast_button.text, "Sem mana")

func test_grimoire_conjurar_button_enabled_with_enough_mana_and_no_cooldown():
	var player = PlayerData.new(CivilizationData.new())
	player.researched_magic["invocacao_espiritos"] = true
	player.mana = 100.0

	var row: Control = add_child_autofree(hud._build_spell_row("Lança de Arcana", player))
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
	assert_false(hud._production_buttons["warrior"].visible, "Guarda agora exige pesquisar a tech 'guarda' (Roadmap arvore de 10 niveis), nao deveria aparecer sem ela")
	assert_false(hud._production_buttons["men_at_arms"].visible, "Homem de Armas sem a tech 'homem_de_armas' nem Quartel construido nao deveria aparecer")

	human.researched_techs["guarda"] = true
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud._production_buttons["warrior"].visible, "Guarda pesquisado deveria aparecer, mesmo sem nenhum predio")

	human.researched_techs["quartel"] = true
	human.researched_techs["homem_de_armas"] = true
	city.buildings["barracks"] = true
	hud._on_tile_selected(coord, hex_grid.get_tile(coord))

	assert_true(hud._production_buttons["men_at_arms"].visible, "Homem de Armas com Quartel construido e a tech propria pesquisada deveria aparecer")

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

## Pedido explicito: "divida a arvore de tecnologia da de magia, serao 2
## botoes... nao serao mais abas juntas" — TechPanel e MagicPanel sao dois
## PanelContainer full-screen separados agora, cada um com seu botao
## proprio (tech_button/magic_button).
func test_tech_panel_and_magic_panel_both_fill_the_whole_screen():
	for panel in [hud.tech_panel, hud.magic_panel]:
		assert_eq(panel.anchor_left, 0.0)
		assert_eq(panel.anchor_top, 0.0)
		assert_eq(panel.anchor_right, 1.0)
		assert_eq(panel.anchor_bottom, 1.0)

func test_tech_and_magic_buttons_open_their_own_independent_panel():
	hud._on_magic_pressed()
	assert_true(hud.magic_panel.visible)
	assert_false(hud.tech_panel.visible, "abrir Magia nao deveria abrir Tecnologia junto")

	hud._on_tech_pressed()
	assert_true(hud.tech_panel.visible)
	assert_false(hud.magic_panel.visible, "abrir Tecnologia deveria fechar Magia (so um overlay por vez)")

func test_magic_close_button_closes_only_the_magic_panel():
	hud._on_magic_pressed()
	assert_true(hud.magic_panel.visible)

	hud._on_magic_close_pressed()
	assert_false(hud.magic_panel.visible)

## Chrome dos dois paineis (fundo + botao de fechar) usa a paleta escura
## local agora, nao mais o dourado/marrom do Theme global — sem titulo
## nenhum (pedido explicito da rodada anterior: "apague o titulo").
func test_both_panels_have_dark_background_and_no_title_text():
	for panel in [hud.tech_panel, hud.magic_panel]:
		assert_true(panel.has_theme_stylebox_override("panel"))
		var sb: StyleBox = panel.get_theme_stylebox("panel")
		assert_true(sb is StyleBoxFlat)
		assert_ne((sb as StyleBoxFlat).bg_color, UITheme.COLOR_BG_PANEL)
		assert_not_null(panel.find_child("PanelBackground", false, false), "cada painel deveria ter seu proprio gradiente de fundo")
	# Nenhum node de titulo sobrou em nenhum dos dois headers — so o
	# espacador (Control puro) + botao de fechar.
	assert_null(hud.tech_panel.find_child("*Title*", true, false))
	assert_null(hud.magic_panel.find_child("*Title*", true, false))

## O progresso da pesquisa ativa aparece no botao do sistema DONO dela
## (TechDatabase -> "Tecnologia", MagicDatabase -> "Magia") — o outro
## botao volta pro rotulo padrao.
func test_research_progress_shows_on_the_owning_system_button_only():
	var player = PlayerData.new(CivilizationData.new())
	player.current_research = "quartel" # TechDatabase
	player.research_progress = 6.5 # custo 13 -> 50%
	GameManager.human_player = player

	hud._refresh_stats()

	assert_true("50%" in hud.tech_button.text)
	assert_eq(hud.magic_button.text, "Magia")

func test_magic_button_disabled_state_follows_the_other_action_buttons():
	hud._on_game_over(true)
	assert_true(hud.magic_button.disabled)

	hud._on_restart_pressed()
	assert_false(hud.magic_button.disabled)
