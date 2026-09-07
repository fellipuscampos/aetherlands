extends Control

## Contador de FPS (pedido do usuario: "coloque o fps na tela") — vive
## dentro do StatusGroup da barra superior, junto dos outros indicadores
## (pedido do usuario numa rodada seguinte: "a barra de cima vai ficar so
## status, dinheiro, mana e etc... qualquer status de algo pode ficar la
## na barra superior" — FPS e um status como outro qualquer). Atualizado
## todo frame em _process(), unica razao de HUD ter um agora.
@onready var fps_label: Label = $TopBar/TopBarRow/StatusGroup/FpsLabel

## Barra superior: SO leitura de status agora (Turno/Ouro/Mana/Cidades-
## Unidades/FPS) — pedido do usuario: "vamos tentar copiar a logica do hud
## do civilization, a barra de cima vai ficar so status, dinheiro, mana e
## etc". Os botoes de navegacao/acao (antigo NavGroup + Finalizar Turno)
## se mudaram pro ActionBar no canto inferior direito (ver mais abaixo),
## no mesmo espirito do agrupamento do Civilization VI: icones de menu
## empilhados por cima do botao grande de Finalizar Turno.
@onready var turn_label: Label = $TopBar/TopBarRow/StatusGroup/TurnLabel
@onready var gold_label: Label = $TopBar/TopBarRow/StatusGroup/GoldLabel
@onready var mana_label: Label = $TopBar/TopBarRow/StatusGroup/ManaLabel
@onready var stats_label: Label = $TopBar/TopBarRow/StatusGroup/StatsLabel
## ActionBar (canto inferior direito, ver HUD.tscn): cluster de botoes de
## menu/acao — pedido do usuario: "no canto inferior direito, você vao ter
## o botao de passar de turno, de abrir a arvore de pesquisa, do grimorio
## e qualquer outra coisa do tipo". Finalizar Turno fica por ULTIMO na
## coluna (mais abaixo, maior — custom_minimum_size.y=44 no .tscn — pra
## ler como a acao PRINCIPAL, mesmo espirito do botao redondo grande do
## Civilization VI embaixo dos icones menores) — continua com borda
## dourada de destaque + atalho Espaco/Enter (ver _style_end_turn_button()).
@onready var action_bar: PanelContainer = $ActionBar
@onready var end_turn_button: Button = $ActionBar/ActionBarBox/EndTurnButton
@onready var save_button: Button = $ActionBar/ActionBarBox/SaveButton
@onready var notification_stack: VBoxContainer = $NotificationStack
@onready var minimap: Control = $Minimap
@onready var tile_info_panel: PanelContainer = $TileInfoPanel
@onready var tile_info_label: Label = $TileInfoPanel/TileInfoBox/TileInfoLabel
## Indicador de progresso do item em producao na cidade vista — pedido do
## usuario: "quando uma construção ta sendo feita, tenha algum indicador de
## avanço... atualmente nao sabemos nem quanto demora... nem o progresso".
## Antes so existia como texto cru embutido no meio de tile_info_label
## ("Produzindo: X (12/25)"), sem barra visual nem estimativa de turnos —
## ver _refresh_production_progress().
@onready var production_progress_label: Label = $TileInfoPanel/TileInfoBox/ProductionProgressLabel
@onready var production_progress_bar: ProgressBar = $TileInfoPanel/TileInfoBox/ProductionProgressBar
## Rush-buy do Mercado (ver City.can_rush_buy()/rush_buy_cost()/rush_buy())
## — so aparece com o Mercado ja construido NESTA cidade e algo de fato em
## producao, ver _refresh_production_progress().
@onready var rush_buy_button: Button = $TileInfoPanel/TileInfoBox/RushBuyButton
## Duas abas (pedido do usuario — painel lateral parecia "uma muralha de
## 15+ botoes cinzas"): "Unidades" e "Construcoes" (predios de producao +
## treino/mana juntos, mas com secao propria dentro da aba). Titulos
## acentuados setados em codigo (ver _ready()) em vez do nome do node, pra
## nao depender de acento sobrevivendo a serializacao do nome do .tscn.
@onready var production_tabs: TabContainer = $TileInfoPanel/TileInfoBox/ProductionTabs
## Container vazio na cena — os botoes de unidade sao criados dinamicamente
## em _build_production_buttons(), um por UnitDatabase.PLAYER_TRAINABLE_
## KINDS, em vez de um por-kind cadastrado a mao na cena (ver comentario
## daquela const: foi exatamente esse hardcode que deixou stone_golem/
## shadow_summoner sem nenhum jeito de treinar quando entraram no jogo).
## GridContainer (nao mais VBoxContainer) — pedido do usuario: reorganizar
## a HUD "parecido com os de civilization 6", que usa uma GRADE de opcoes
## de producao em vez de uma lista vertical unica.
@onready var production_row: GridContainer = $TileInfoPanel/TileInfoBox/ProductionTabs/UnitsTab/ProductionRow
@onready var build_granary_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/BuildingsRow/BuildGranaryButton
@onready var build_workshop_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/BuildingsRow/BuildWorkshopButton
@onready var build_market_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/BuildingsRow/BuildMarketButton
@onready var build_walls_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/BuildingsRow/BuildWallsButton
@onready var build_barracks_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildBarracksButton
@onready var build_archery_range_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildArcheryRangeButton
@onready var build_stable_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildStableButton
@onready var build_siege_workshop_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildSiegeWorkshopButton
@onready var build_arcane_tower_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildArcaneTowerButton
@onready var build_griffin_roost_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildGriffinRoostButton
@onready var build_druid_grove_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildDruidGroveButton
@onready var build_runic_anvil_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildRunicAnvilButton
@onready var build_shadow_crypt_button: Button = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/TrainingRow/BuildShadowCryptButton
@onready var worked_tiles_label: Label = $TileInfoPanel/TileInfoBox/WorkedTilesLabel
## Envelope com altura MAXIMA fixa (118px, ver HUD.tscn) — pedido do
## usuario: "o rodape NUNCA encoste ou passe por cima do Finalizar Turno".
## worked_tiles_row (a lista de verdade, dentro dele) so cresce ATE esse
## teto e depois rola por conta propria, em vez de empurrar o resto do
## painel (e o botao de Finalizar Turno logo abaixo) pra baixo.
@onready var worked_tiles_scroll: ScrollContainer = $TileInfoPanel/TileInfoBox/WorkedTilesScroll
@onready var worked_tiles_row: HFlowContainer = $TileInfoPanel/TileInfoBox/WorkedTilesScroll/WorkedTilesRow
@onready var tech_button: Button = $ActionBar/ActionBarBox/TechButton
@onready var tech_panel: PanelContainer = $TechPanel
@onready var tech_current_label: Label = $TechPanel/TechBox/TechCurrentLabel
## Pedido do usuario: separar a arvore em duas areas — "Magia" (Arcanismo/
## Transmutação/Naturalismo/Elementalismo/Geomancia/Alquimia) e "Tecnologia"
## (so a escola "Doutrina") — cada aba tem sua PROPRIA instancia de
## TechTree.gd, filtrada via TechTree.category (ver _ready()/_refresh_tech_
## panel() abaixo), mantendo a mesma organizacao/algoritmo de tier de hoje.
@onready var tech_tabs: TabContainer = $TechPanel/TechBox/TechTabs
@onready var tech_tree_magic: TechTree = $TechPanel/TechBox/TechTabs/MagicTab/MagicTree
@onready var tech_tree_doutrina: TechTree = $TechPanel/TechBox/TechTabs/DoutrinaTab/DoutrinaTree
@onready var tech_close_button: Button = $TechPanel/TechBox/TechHeader/TechCloseButton
@onready var diplomacy_button: Button = $ActionBar/ActionBarBox/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyHeader/DiplomacyCloseButton
## Roadmap "Fase F" F1/F2/F5 -- mesmo padrao de overlay do Diplomacy acima.
@onready var victory_button: Button = $ActionBar/ActionBarBox/VictoryButton
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_rows: VBoxContainer = $VictoryPanel/VictoryBox/VictoryRows
@onready var victory_close_button: Button = $VictoryPanel/VictoryBox/VictoryHeader/VictoryCloseButton
@onready var grimoire_button: Button = $ActionBar/ActionBarBox/GrimoireButton
@onready var grimoire_panel: PanelContainer = $GrimoirePanel
@onready var grimoire_rows: VBoxContainer = $GrimoirePanel/GrimoireBox/GrimoireRows
@onready var grimoire_close_button: Button = $GrimoirePanel/GrimoireBox/GrimoireHeader/GrimoireCloseButton
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_info_label: Label = $UnitPanel/UnitBox/UnitInfoLabel
## Mover/Fortificar/Explorar (pedido do usuario: "as opções... que se me
## recordo civilization é mover, fortificar e explorar") — ver
## SelectionManager.wake_selected_for_move/fortify_selected/
## toggle_explore_selected.
@onready var move_button: Button = $UnitPanel/UnitBox/UnitActionsRow/MoveButton
@onready var fortify_button: Button = $UnitPanel/UnitBox/UnitActionsRow/FortifyButton
@onready var explore_button: Button = $UnitPanel/UnitBox/UnitActionsRow/ExploreButton
@onready var embark_button: Button = $UnitPanel/UnitBox/UnitActionsRow/EmbarkButton
@onready var found_city_button: Button = $UnitPanel/UnitBox/FoundCityButton
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverBox/GameOverLabel
## Roadmap "Fase F" F6 -- titulo/resumo/snapshot CONGELADOS no momento da
## vitoria (ver _on_victory_achieved), separados do game_over_label
## legado acima (que continua so com o veredito basico + estatisticas).
@onready var game_over_title_label: Label = $GameOverPanel/GameOverBox/GameOverTitleLabel
@onready var game_over_summary_label: Label = $GameOverPanel/GameOverBox/GameOverSummaryLabel
@onready var game_over_snapshot_rows: VBoxContainer = $GameOverPanel/GameOverBox/GameOverSnapshotScroll/GameOverSnapshotRows
@onready var restart_button: Button = $GameOverPanel/GameOverBox/RestartButton
@onready var overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var debug_button: Button = $ActionBar/ActionBarBox/DebugButton
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_close_button: Button = $DebugPanel/DebugBox/DebugHeader/DebugCloseButton
@onready var debug_mode_button: Button = $DebugPanel/DebugBox/DebugModeButton
@onready var debug_reveal_map_button: Button = $DebugPanel/DebugBox/DebugRevealMapButton
@onready var debug_gold_button: Button = $DebugPanel/DebugBox/DebugGoldButton
@onready var debug_complete_research_button: Button = $DebugPanel/DebugBox/DebugCompleteResearchButton
@onready var debug_win_button: Button = $DebugPanel/DebugBox/DebugWinButton
@onready var debug_lose_button: Button = $DebugPanel/DebugBox/DebugLoseButton

var _viewed_city: City = null
## Guarda se UnitPanel estava visivel ANTES de abrir um overlay (pedido do
## usuario: "TODOS os outros paineis da HUD ficam ocultos ate a janela ser
## fechada") — visibilidade dele depende de ter unidade selecionada
## (_on_unit_selected), entao _close_overlay_panels() nao pode simplesmente
## forcar true de volta ao fechar (mostraria o painel vazio sem unidade
## nenhuma selecionada); tem que restaurar o estado exato de antes.
var _unit_panel_was_visible := false
## Mesma ideia de _unit_panel_was_visible, agora pro TileInfoPanel (pedido
## do usuario: o painel ficava sempre visivel, ate sem tile nenhum
## selecionado — "Selecione um tile" sozinho cobrindo boa parte da tela).
## Visibilidade dele passa a depender de haver selecao (ver _on_tile_selected),
## entao _close_overlay_panels() tambem precisa restaurar o estado exato de
## antes em vez de forcar true.
var _tile_info_panel_was_visible := false

func _ready() -> void:
	theme = UITheme.build()
	_style_end_turn_button()
	production_tabs.set_tab_title(0, "Unidades")
	production_tabs.set_tab_title(1, "Construções")
	_label_building_buttons()
	_build_production_buttons()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	found_city_button.pressed.connect(_on_found_city_pressed)
	move_button.pressed.connect(_on_move_pressed)
	fortify_button.pressed.connect(_on_fortify_pressed)
	explore_button.pressed.connect(_on_explore_pressed)
	embark_button.pressed.connect(_on_embark_pressed)
	build_granary_button.pressed.connect(_on_produce_pressed.bind("granary"))
	build_workshop_button.pressed.connect(_on_produce_pressed.bind("workshop"))
	build_market_button.pressed.connect(_on_produce_pressed.bind("market"))
	build_walls_button.pressed.connect(_on_produce_pressed.bind("walls"))
	build_barracks_button.pressed.connect(_on_produce_pressed.bind("barracks"))
	build_archery_range_button.pressed.connect(_on_produce_pressed.bind("archery_range"))
	build_stable_button.pressed.connect(_on_produce_pressed.bind("stable"))
	build_siege_workshop_button.pressed.connect(_on_produce_pressed.bind("siege_workshop"))
	build_arcane_tower_button.pressed.connect(_on_produce_pressed.bind("arcane_tower"))
	build_griffin_roost_button.pressed.connect(_on_produce_pressed.bind("griffin_roost"))
	build_druid_grove_button.pressed.connect(_on_produce_pressed.bind("druid_grove"))
	build_runic_anvil_button.pressed.connect(_on_produce_pressed.bind("runic_anvil"))
	build_shadow_crypt_button.pressed.connect(_on_produce_pressed.bind("shadow_crypt"))
	save_button.pressed.connect(_on_save_pressed)
	tech_button.pressed.connect(_on_tech_pressed)
	rush_buy_button.pressed.connect(_on_rush_buy_pressed)
	tech_close_button.pressed.connect(_on_tech_close_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
	victory_button.pressed.connect(_on_victory_pressed)
	victory_close_button.pressed.connect(_on_victory_close_pressed)
	grimoire_button.pressed.connect(_on_grimoire_pressed)
	grimoire_close_button.pressed.connect(_on_grimoire_close_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	debug_close_button.pressed.connect(_on_debug_close_pressed)
	debug_mode_button.pressed.connect(_on_debug_mode_pressed)
	debug_reveal_map_button.pressed.connect(_on_debug_reveal_map_pressed)
	debug_gold_button.pressed.connect(_on_debug_gold_pressed)
	debug_complete_research_button.pressed.connect(_on_debug_complete_research_pressed)
	debug_win_button.pressed.connect(_on_debug_win_pressed)
	debug_lose_button.pressed.connect(_on_debug_lose_pressed)
	tech_tree_magic.category = "magic"
	tech_tree_doutrina.category = "doutrina"
	tech_tabs.set_tab_title(0, "Magia")
	tech_tabs.set_tab_title(1, "Tecnologia")
	tech_tree_magic.tech_selected.connect(_on_tech_selected)
	tech_tree_doutrina.tech_selected.connect(_on_tech_selected)
	TurnManager.turn_changed.connect(_on_turn_changed)
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.game_over.connect(_on_game_over)
	# Roadmap "Fase F" F6 -- GameManager._end_game() emite game_over.emit()
	# ANTES de victory_achieved.emit() (nunca o contrario) -- entao pra toda
	# vitoria de verdade, _on_game_over ja rodou (mostrou o painel, texto
	# basico) antes de _on_victory_achieved popular titulo/resumo/snapshot
	# detalhados por cima. A ordem destas duas linhas de connect() aqui NAO
	# importa pra essa garantia -- quem decide e a ordem de EMISSAO em
	# _end_game, nao a ordem de conexao.
	EventBus.victory_achieved.connect(_on_victory_achieved)
	EventBus.notify.connect(_on_notify)
	# fog_updated dispara ao fim de start_new_game/recompute_fog — cobre o
	# caso do primeiro turno, onde turn_changed ainda nao foi emitido.
	EventBus.fog_updated.connect(_refresh_stats)

	unit_panel.visible = false
	production_tabs.visible = false
	worked_tiles_label.visible = false
	worked_tiles_scroll.visible = false
	production_progress_label.visible = false
	production_progress_bar.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false
	grimoire_panel.visible = false
	game_over_panel.visible = false
	debug_panel.visible = false
	overlay_backdrop.visible = false
	# So visivel rodando pelo editor/build de debug — nunca aparece pra
	# quem so joga um export de release (pedido do usuario: "opcoes
	# debug", nao um menu de trapaça pro jogador ver).
	debug_button.visible = OS.is_debug_build()
	_on_turn_changed(TurnManager.turn_number, TurnManager.current_player_index)

## Botao de acao IMPONENTE (pedido do usuario: "borda dourada/brilhante"),
## unico da tela com essa borda de destaque — todo o resto dos botoes usa
## o estilo generico de UITheme.build(). Montado em codigo em vez de sub-
## resource no .tscn pra reusar UITheme.panel_style(), mesma tecnica ja
## usada pelos cards da TechTree. Compacto (fonte/borda menores que a
## versao antiga, flutuante) pra caber na faixa de 48px da barra superior
## (ver HUD.tscn TopBar) sem estourar a altura dela.
func _style_end_turn_button() -> void:
	end_turn_button.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_BODY)
	end_turn_button.add_theme_stylebox_override("normal", UITheme.panel_style(UITheme.COLOR_BG_PANEL_LIGHT, UITheme.COLOR_BORDER_BRIGHT, 2, 8))
	end_turn_button.add_theme_stylebox_override("hover", UITheme.panel_style(UITheme.COLOR_BG_PANEL_LIGHT.lightened(0.1), UITheme.COLOR_BORDER_BRIGHT, 3, 8))
	end_turn_button.add_theme_stylebox_override("pressed", UITheme.panel_style(UITheme.COLOR_BG_PANEL.darkened(0.1), UITheme.COLOR_BORDER_BRIGHT, 3, 8))
	end_turn_button.add_theme_color_override("font_color", UITheme.COLOR_BORDER_BRIGHT)
	end_turn_button.add_theme_color_override("font_hover_color", UITheme.COLOR_TEXT)

## Altura fixa do painel COMPACTO (so texto do tile, sem cidade) — pedido
## do usuario, direto: "qual sentido da gente ter esse big ass menu pra
## mostrar 'planicie comida +3'". So o painel de CIDADE (com a grade de
## producao, ver _update_tile_info_panel_size) justifica ocupar a lateral
## inteira da tela feito o Civilization; um tile qualquer e so 3-5 linhas
## de texto, nao precisa de mais que isso.
const TILE_INFO_PANEL_COMPACT_HEIGHT := 220.0
## Espaco reservado pra barra superior (48px) + margem, ver TopBar em
## HUD.tscn — o painel de CIDADE encosta logo abaixo dela.
const TILE_INFO_PANEL_TOP_MARGIN := 56.0
## Borda direita do painel COMPACTO — para 8px a esquerda do ActionBar
## (ver HUD.tscn, ActionBar.offset_left = -200), deixando os dois lado a
## lado sem se sobrepor. Borda EXPANDIDA vai ate a mesma borda direita do
## ActionBar (-8, ver ActionBar.offset_right) — pedido do usuario: "ao
## clicar na cidade, essa area do menu some, e fica so o menu da cidade
## ocupando a parte direita" — o painel de cidade toma conta do espaco
## INTEIRO que o ActionBar ocupava, nao so cresce pra cima.
const TILE_INFO_PANEL_COMPACT_RIGHT := -208.0
const TILE_INFO_PANEL_EXPANDED_RIGHT := -8.0

## Alterna o painel entre COMPACTO (so texto do tile ou tropa, ao lado do
## ActionBar, altura fixa pequena) e EXPANDIDO (cidade selecionada, ocupa
## a lateral direita INTEIRA da tela — largura ate a borda do ActionBar
## (que fica escondido nesse estado, ver _on_tile_selected) pra caber a
## grade de producao, e altura ate quase o topo) — a borda de BAIXO fica
## sempre a 16px do rodape e a borda ESQUERDA sempre a mesma, entao o
## painel sempre "cresce pra cima e pra direita" a partir do mesmo canto,
## nunca muda de lado.
func _update_tile_info_panel_size(expanded: bool) -> void:
	if expanded:
		tile_info_panel.anchor_top = 0.0
		tile_info_panel.offset_top = TILE_INFO_PANEL_TOP_MARGIN
		tile_info_panel.offset_right = TILE_INFO_PANEL_EXPANDED_RIGHT
	else:
		tile_info_panel.anchor_top = 1.0
		tile_info_panel.offset_top = -TILE_INFO_PANEL_COMPACT_HEIGHT
		tile_info_panel.offset_right = TILE_INFO_PANEL_COMPACT_RIGHT

## Mostra o custo de producao de cada predio no proprio botao (pedido do
## usuario: "cards compactos com custo de producao/tempo") — os nomes
## crus (ex: "Celeiro") ja vem do .tscn, aqui so acrescenta o custo lido
## de BuildingDatabase, uma unica fonte de verdade (sem duplicar numero
## nenhum a mao no texto do node).
func _label_building_buttons() -> void:
	for id in BUILDING_IDS:
		_build_button_for(id).text = _building_button_label(id, "human")

## Texto do botao de predio, tematizado por raca (RaceTheme.building_name
## cai no nome cru de BuildingDatabase pra qualquer raca/predio fora do
## ramo militar escopado, ver RaceTheme.gd) — usado tanto na rotulagem
## inicial em _ready() (raca ainda desconhecida, "human" por padrao) quanto
## na retematizacao em _on_tile_selected() assim que a raca do jogador
## humano ja e conhecida.
func _building_button_label(id: String, race: String) -> String:
	var building: BuildingData = BuildingDatabase.get_building(id)
	return "%s  —  %d PP" % [RaceTheme.building_name(id, race), int(building.production_cost)]

## Atalho de teclado pedido pelo usuario ("Espaço ou Enter") pro botao de
## acao principal — "ui_accept" e a acao embutida do proprio Godot pra
## Enter/Kp Enter/Espaco, os tres juntos, sem precisar mexer no input map
## do projeto. So dispara em PLAYING (nao durante fim de jogo) e nunca com
## um overlay aberto (Tecnologia/Diplomacia/Grimorio/Debug) — o
## backdrop escurecido ja bloqueia CLIQUE nesses casos, mas o teclado
## ignora ele, entao a checagem tem que ser explicita aqui.
const END_TURN_BUTTON_TEXT := "Finalizar Turno (Espaço)"
## Pedido do usuario: "enquanto ta processando o botao fica ou
## indisponivel ou substituido por algo como processando" — faz as DUAS
## coisas (ver _process abaixo): desabilita E troca o texto, deixando
## claro que a IA ainda esta "pensando" em vez de so um botao cinza sem
## explicacao.
const END_TURN_BUTTON_PROCESSING_TEXT := "Processando Turno..."

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	# GameManager.is_turn_processing (ver stagger_ai_turns) fica true
	# enquanto a fila de acoes de IA do turno ainda esta drenando aos
	# poucos — desabilita "Encerrar Turno" nesse meio-tempo (junto com
	# _unhandled_input abaixo, que ja respeita end_turn_button.disabled),
	# senao o jogador podia clicar de novo em cima de um turno que ainda
	# nao terminou de verdade. Combinado com o fim de jogo (mesmo botao ja
	# fica desabilitado por _on_game_over/_on_restart_pressed) — recalcular
	# os dois aqui todo frame e mais simples do que coordenar toggle
	# manual em varios lugares diferentes.
	end_turn_button.disabled = GameManager.is_turn_processing or GameManager.state == GameManager.GameState.GAME_OVER
	end_turn_button.text = END_TURN_BUTTON_PROCESSING_TEXT if GameManager.is_turn_processing else END_TURN_BUTTON_TEXT

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if GameManager.state != GameManager.GameState.PLAYING or overlay_backdrop.visible or end_turn_button.disabled:
		return
	_on_end_turn_pressed()
	get_viewport().set_input_as_handled()

func _on_end_turn_pressed() -> void:
	TurnManager.end_turn()

func _on_found_city_pressed() -> void:
	SelectionManager.found_city_with_selected()

func _on_move_pressed() -> void:
	SelectionManager.wake_selected_for_move()

func _on_fortify_pressed() -> void:
	SelectionManager.fortify_selected()

func _on_explore_pressed() -> void:
	SelectionManager.toggle_explore_selected()

func _on_embark_pressed() -> void:
	SelectionManager.toggle_embark_selected()

func _on_produce_pressed(kind: String) -> void:
	if _viewed_city == null or not GameManager.human_player.has_unlocked(kind):
		return
	var building = BuildingDatabase.get_building(kind)
	if building:
		if not _viewed_city.can_build(kind):
			return
		if not building.self_placed:
			# Predio precisa de um tile escolhido no mapa (como fundar
			# cidade) — a producao so comeca de fato quando o jogador clica
			# um tile valido (SelectionManager._handle_building_placement_
			# click).
			SelectionManager.start_building_placement(_viewed_city, kind)
			return
		# self_placed (Muralhas, ver BuildingData.gd): sem tile pra
		# escolher — nao faz sentido "onde" cercar uma cidade que so tem
		# um tile, entao cai direto no mesmo fluxo de treinar uma unidade
		# logo abaixo, sem passar pela UI de posicionamento.
	elif not _viewed_city.can_train(kind):
		return
	_viewed_city.set_production(kind)
	# Trocar pra unidade pode ter abandonado um predio em obra (City.
	# set_production ja limpou pending_building_coord) — sincroniza o
	# marcador de construcao pra ele sumir do mapa junto.
	if GameManager.hex_grid:
		GameManager.hex_grid.refresh_construction_markers()
	_refresh_viewed_city()

func _refresh_viewed_city() -> void:
	if _viewed_city:
		_on_tile_selected(_viewed_city.coord, GameManager.hex_grid.get_tile(_viewed_city.coord))

## Rush-buy do Mercado (ver City.rush_buy()) — gasta ouro do jogador pra
## completar o item em producao na hora (conclusao de fato so no PROXIMO
## turno, ver comentario de City.rush_buy()). Falha silenciosamente (sem
## efeito nenhum) se faltar ouro ou o rush-buy nao estiver disponivel —
## rush_buy_button so aparece habilitado quando ja da pra pagar (ver
## _refresh_production_progress()), entao chegar aqui sem poder pagar so
## aconteceria por uma condicao de corrida (ex: outro efeito descontando
## ouro no mesmo frame), nao pelo fluxo normal.
func _on_rush_buy_pressed() -> void:
	if _viewed_city == null:
		return
	if _viewed_city.rush_buy(GameManager.hex_grid):
		_refresh_viewed_city()
		_refresh_stats() # ouro gasto precisa refletir na TopBar na hora, sem esperar o proximo turno

func _on_save_pressed() -> void:
	if SaveManager.save_game(GameManager.hex_grid):
		EventBus.notify.emit("Jogo salvo.", "confirm")
	else:
		EventBus.notify.emit("Falha ao salvar o jogo.", "")

## Tecnologia/Diplomacia/Grimorio/Debug/FimDeJogo sao todos paineis
## centralizados na mesma posicao — sem isso, abrir um por cima do outro
## (ou o jogo acabar com um deles aberto) deixava tudo empilhado e
## ilegivel. So um fica visivel por vez, e o backdrop escurecido some
## junto (ver _show_overlay).
func _close_overlay_panels() -> void:
	tech_panel.visible = false
	diplomacy_panel.visible = false
	victory_panel.visible = false
	grimoire_panel.visible = false
	game_over_panel.visible = false
	debug_panel.visible = false
	overlay_backdrop.visible = false
	# Restaura os paineis "sempre presentes" do jogo (pedido do usuario —
	# hierarquia visual estavel: minimapa/painel de cidade/unidade ficam
	# ocultos so ENQUANTO um overlay esta aberto, ver _show_overlay).
	# UnitPanel volta pro estado de ANTES (so aparece se de fato ha uma
	# unidade selecionada), os outros voltam incondicionalmente porque sao
	# sempre visiveis fora de um overlay.
	minimap.visible = true
	tile_info_panel.visible = _tile_info_panel_was_visible
	end_turn_button.visible = true
	unit_panel.visible = _unit_panel_was_visible

## Fecha qualquer outro overlay (regra de "so um por vez" acima), esconde
## o resto da HUD de jogo (minimapa, painel de cidade/unidade, botao de
## turno — pedido do usuario: "hierarquia visual estavel... TODOS os
## outros paineis da HUD ficam ocultos ate a janela ser fechada") e mostra
## o pedido, com o fundo escurecido pra deixar claro que o resto da tela
## esta desativado enquanto ele estiver aberto.
func _show_overlay(panel: Control) -> void:
	_close_overlay_panels()
	_unit_panel_was_visible = unit_panel.visible
	_tile_info_panel_was_visible = tile_info_panel.visible
	overlay_backdrop.visible = true
	panel.visible = true
	minimap.visible = false
	tile_info_panel.visible = false
	unit_panel.visible = false
	end_turn_button.visible = false

## Usado pelo menu de pausa (PauseMenu._unhandled_input): ESC deveria
## fechar um overlay da HUD que estiver aberto ANTES de abrir o menu de
## pausa por cima dele — sem isso, ESC abria a pausa em cima do painel
## ainda visivel por baixo (o mesmo tipo de sobreposicao reportado pelo
## usuario). Devolve true se fechou algo, pra quem chamou saber que ja
## "consumiu" o ESC e nao precisa mais abrir a pausa.
func close_topmost_overlay() -> bool:
	if tech_panel.visible or diplomacy_panel.visible or victory_panel.visible or grimoire_panel.visible or debug_panel.visible:
		_close_overlay_panels()
		return true
	return false

func _on_tech_pressed() -> void:
	if tech_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(tech_panel)
	_refresh_tech_panel()

func _on_tech_close_pressed() -> void:
	_close_overlay_panels()

## Mostra a pesquisa atual (com progresso) e as duas arvores (Magia/
## Tecnologia, ver tech_tree_magic/tech_tree_doutrina) — cada tecnologia
## como um card colorido por estado (TechTree.gd cuida do layout/desenho;
## aqui so repassa os dados atuais do jogador pras duas instancias).
func _refresh_tech_panel() -> void:
	var player = GameManager.human_player
	if player == null:
		return

	var race: String = player.civ.race
	if player.current_research != "":
		var tech: TechData = TechDatabase.get_tech(player.current_research)
		tech_current_label.text = "Pesquisando: %s (%d/%d ciencia)" % [
			RaceTheme.tech_name(tech.id, race), int(player.research_progress), int(tech.cost)
		]
	else:
		tech_current_label.text = "Pesquisando: nenhuma, escolha um card disponivel abaixo"

	tech_tree_magic.rebuild(player.researched_techs, player.current_research, player.research_progress, race)
	tech_tree_doutrina.rebuild(player.researched_techs, player.current_research, player.research_progress, race)

func _on_tech_selected(id: String) -> void:
	GameManager.human_player.current_research = id
	_refresh_tech_panel()

func _on_diplomacy_pressed() -> void:
	if diplomacy_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(diplomacy_panel)
	_refresh_diplomacy_panel()

func _on_diplomacy_close_pressed() -> void:
	_close_overlay_panels()

## Uma linha por civ rival: nome + status (guerra/paz) + um botao pra
## inverter. Propor paz pode ser recusado pela IA (Diplomacy.propose_peace,
## heuristica simples de quem esta "perdendo") — o toast avisa o
## resultado, porque um botao que as vezes nao faz nada sem feedback
## nenhum seria confuso.
func _refresh_diplomacy_panel() -> void:
	for child in diplomacy_rows.get_children():
		child.queue_free()

	var human = GameManager.human_player
	if human == null:
		return

	for rival in GameManager.rival_players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var at_war = human.is_at_war_with(rival)
		var eliminated = rival.units.size() == 0 and rival.cities.size() == 0
		var status = "Em guerra" if at_war else "Em paz"
		if eliminated:
			status += " (eliminado)"
		var label := Label.new()
		label.text = "%s: %s" % [rival.civ.civ_name, status]
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		if at_war:
			btn.text = "Propor Paz"
			btn.pressed.connect(_on_propose_peace_pressed.bind(rival))
		else:
			btn.text = "Declarar Guerra"
			btn.pressed.connect(_on_declare_war_pressed.bind(rival))
		row.add_child(btn)

		diplomacy_rows.add_child(row)

func _on_propose_peace_pressed(rival: PlayerData) -> void:
	var accepted = Diplomacy.propose_peace(GameManager.human_player, rival)
	if accepted:
		EventBus.notify.emit("%s aceitou a paz." % rival.civ.civ_name, "confirm")
	else:
		EventBus.notify.emit("%s recusou a paz." % rival.civ.civ_name, "")
	_refresh_diplomacy_panel()

func _on_declare_war_pressed(rival: PlayerData) -> void:
	Diplomacy.declare_war(GameManager.human_player, rival)
	EventBus.notify.emit("Voce declarou guerra a %s!" % rival.civ.civ_name, "combat")
	_refresh_diplomacy_panel()

func _on_victory_pressed() -> void:
	if victory_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(victory_panel)
	_refresh_victory_panel()

func _on_victory_close_pressed() -> void:
	_close_overlay_panels()

## Roadmap "Fase F" F1/F2/F5 -- camada de APRESENTACAO pura sobre
## VictoryConditions (pedido explicito do usuario): "VictoryConditions ->
## progress/read-only -> Victory UI", NUNCA o contrario -- esta funcao so
## LE VictoryConditions.*_progress, nunca calcula uma condicao de vitoria
## por conta propria, nunca escreve em PlayerData. Sem gating de fog-of-
## war nesta fatia (decisao explicita de F2: visibilidade total de todos
## os jogadores). LIVE -- chamada toda vez que o painel abre, ver F6 pra
## contraste com o snapshot CONGELADO de _on_victory_achieved abaixo.
func _refresh_victory_panel() -> void:
	_build_victory_progress_rows(victory_rows)

## Roadmap "Fase F" F6 -- MESMA construcao de linhas de _refresh_victory_
## panel, extraida pra ser reusada tambem pelo snapshot CONGELADO da tela
## de resultado (_on_victory_achieved abaixo) sem duplicar a leitura de
## VictoryConditions em dois lugares. `target` e o container que recebe
## as linhas -- o painel "Vitória" (ao vivo) e o snapshot de fim de jogo
## (congelado no momento da vitoria) usam a MESMA logica de montagem,
## cada um no seu proprio VBoxContainer, nunca compartilhado.
func _build_victory_progress_rows(target: VBoxContainer) -> void:
	for child in target.get_children():
		child.queue_free()

	var human = GameManager.human_player
	var hex_grid = GameManager.hex_grid
	if human == null or hex_grid == null:
		return
	var players: Array[PlayerData] = ([human] as Array[PlayerData]) + GameManager.rival_players

	for player in players:
		var name_label := Label.new()
		name_label.text = player.civ.civ_name
		name_label.theme_type_variation = &"PanelTitle"
		target.add_child(name_label)

		_add_victory_progress_row(target, "Dominação", VictoryConditions.dominance_progress(player, players))
		_add_victory_progress_row(target, "Domínio Territorial", VictoryConditions.territorial_progress(player, hex_grid))
		_add_victory_progress_row(target, "Ascensão Arcana", VictoryConditions.arcane_progress(player, hex_grid))

## `progress` e SEMPRE 0.0-1.0 (contrato comum das 3 funcoes de
## VictoryConditions), mas o SIGNIFICADO por tras de cada numero e
## diferente por tipo (Territorial e uma razao simples contra o limiar;
## Arcana e a media de 4 fracoes; Dominacao e a fracao de rivais
## eliminados) -- esta funcao so formata o numero JA normalizado, nunca
## reinterpreta o que ele significa por tipo (pedido explicito do
## usuario: "a UI deve consumir 0.0-1.0 como contrato, mas nao deve
## assumir que cada tipo de vitoria tem a mesma semantica" -- a
## semantica fica inteiramente do lado de VictoryConditions, aqui so
## chega o numero final).
func _add_victory_progress_row(target: VBoxContainer, label_text: String, progress: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clamp(progress, 0.0, 1.0) * 100.0
	bar.custom_minimum_size = Vector2(120, 0)
	bar.show_percentage = false
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = format_victory_progress_percentage(progress)
	value_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(value_label)

	target.add_child(row)

## Formatacao PURA (nenhuma dependencia de cena/PlayerData/HexGrid) --
## unit-testavel sem instanciar o HUD inteiro. Clampa e arredonda: nunca
## mostra >100% nem negativo mesmo se o progresso bruto de entrada
## passar disso (ver VictoryConditions.territorial_percentage, que NAO e
## clampada -- so territorial_progress e).
static func format_victory_progress_percentage(progress: float) -> String:
	return "%d%%" % int(round(clamp(progress, 0.0, 1.0) * 100.0))

## Roadmap "Fase F" F6 -- titulo da tela de resultado. `winner` pode ser
## null (VICTORY_TYPE_DEBUG forcando derrota sem nenhum rival existir,
## ver GameManager.debug_force_game_over) -- cai num titulo generico em
## vez de quebrar. PURA (nenhuma dependencia de cena) -- unit-testavel
## direto.
static func format_victory_title(winner: PlayerData, victory_type: String) -> String:
	if victory_type == VictoryConditions.VICTORY_TYPE_DEBUG:
		return "Fim de jogo forçado (Debug)"
	if winner == null:
		return "Fim de jogo"
	var victory_name: String
	match victory_type:
		VictoryConditions.VICTORY_TYPE_DOMINANCE:
			victory_name = "Dominação"
		VictoryConditions.VICTORY_TYPE_TERRITORIAL:
			victory_name = "Domínio Territorial"
		VictoryConditions.VICTORY_TYPE_ARCANE:
			victory_name = "Ascensão Arcana"
		_:
			victory_name = victory_type
	return "%s alcançou %s" % [winner.civ.civ_name, victory_name]

## Roadmap "Fase F" F6 -- resumo FIXO por tipo (pedido explicito do
## usuario), nunca gerado a partir do estado de UM jogador especifico --
## so interpola as CONSTANTES ja existentes de VictoryConditions (numero
## de escolas/nodulos/turnos exigidos), nunca calcula nada sobre a
## partida. Texto narrativo/procedural fica pra F6 (identidade/lore),
## combinado explicitamente como fora de escopo aqui.
static func format_victory_summary(victory_type: String) -> String:
	match victory_type:
		VictoryConditions.VICTORY_TYPE_DOMINANCE:
			return "Eliminou todos os reinos rivais."
		VictoryConditions.VICTORY_TYPE_TERRITORIAL:
			return "Controlou pelo menos %d%% do mundo habitável por %d turnos consecutivos." % [
				int(round(VictoryConditions.TERRITORIAL_VICTORY_THRESHOLD * 100.0)),
				VictoryConditions.TERRITORIAL_SUSTAIN_TURNS,
			]
		VictoryConditions.VICTORY_TYPE_ARCANE:
			return "Pesquisou %d das 7 escolas mágicas, controlou %d Nódulos Arcanos e sustentou o Ritual do Nódulo por %d turnos." % [
				VictoryConditions.ARCANE_SCHOOLS_REQUIRED,
				VictoryConditions.ARCANE_NODES_REQUIRED,
				VictoryConditions.ARCANE_SUSTAIN_TURNS,
			]
		VictoryConditions.VICTORY_TYPE_DEBUG:
			return "Fim de jogo disparado manualmente pelo modo debug -- nenhuma condição de vitória real foi avaliada."
		_:
			return ""

## Roadmap "Fase F" F6 -- CONGELA o snapshot no momento exato da vitoria:
## chamado UMA vez, so pelo sinal EventBus.victory_achieved (nunca
## re-chamado por nenhum refresh posterior da HUD). Popula Labels/
## ProgressBars ESTATICOS (game_over_snapshot_rows) que NAO tem nenhuma
## ligacao viva com VictoryConditions depois deste ponto -- diferente do
## painel "Vitória" (_refresh_victory_panel), que consulta de novo toda
## vez que abre. E exatamente essa diferenca que garante o contrato
## pedido explicito do usuario: a tela de resultado continua mostrando
## os valores do MOMENTO da vitoria mesmo que o estado do jogo mude
## depois (partida ja acabou, mas os nodes worldwide/PlayerData podem
## teoricamente continuar existindo/mudando ate a cena ser trocada).
func _on_victory_achieved(winner: PlayerData, victory_type: String) -> void:
	game_over_title_label.text = format_victory_title(winner, victory_type)
	game_over_summary_label.text = format_victory_summary(victory_type)
	_build_victory_progress_rows(game_over_snapshot_rows)

func _on_grimoire_pressed() -> void:
	if grimoire_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(grimoire_panel)
	_refresh_grimoire_panel()

func _on_grimoire_close_pressed() -> void:
	_close_overlay_panels()

## Uma linha por feitico ja desbloqueado (TechDatabase.unlocked_spells_for,
## ver TechData.unlocks_spell) — pedido do usuario: "exiba os feiticos
## ativos no HUD do jogador... permita que o jogador selecione o feitico e
## aplique o efeito no mapa". "Conjurar" entra em modo de mira no mapa
## (SelectionManager.start_spell_targeting) e fecha o painel na hora,
## porque o proximo clique no MUNDO e o que escolhe o alvo de verdade
## (mesma UX de _on_produce_pressed/start_building_placement) — o overlay
## bloqueia clique no mapa enquanto aberto (ver OverlayBackdrop), entao
## precisa sumir antes do jogador conseguir mirar.
func _refresh_grimoire_panel() -> void:
	for child in grimoire_rows.get_children():
		child.queue_free()

	var human = GameManager.human_player
	if human == null:
		return

	var spell_names = TechDatabase.unlocked_spells_for(human.researched_techs)
	if spell_names.is_empty():
		var empty_label := Label.new()
		empty_label.theme_type_variation = &"MutedLabel"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "Nenhum ritual desbloqueado ainda — pesquise uma tecnologia com feitico (ver Tecnologia)."
		grimoire_rows.add_child(empty_label)
		return

	for spell_name in spell_names:
		grimoire_rows.add_child(_build_spell_row(spell_name, human))

## Feitico sem SpellData cadastrado (Ruina Ignea/Metamorfose de Gaia,
## tecnologias de Tier 3 ja pesquisaveis mas sem efeito implementado ainda
## — ver comentario de topo de SpellDatabase.gd) aparece na lista com o
## botao desabilitado em vez de sumir sem explicacao nenhuma.
func _build_spell_row(spell_name: String, human: PlayerData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	var name_label := Label.new()
	# Custo de mana exibido ja reflete o desconto de Nodulo Arcano (Roadmap
	# 2.0 Parte 1, B1, ver SpellManager.effective_mana_cost) quando houver.
	name_label.text = "%s (%d mana)" % [spell_name, int(SpellManager.effective_mana_cost(spell, human, GameManager.hex_grid))] if spell else spell_name
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(name_label)

	# Recarga (tempo) e mana (saldo) sao dois gates INDEPENDENTES — mostra
	# qual dos dois esta bloqueando pra nao deixar o jogador adivinhando
	# (mesma filosofia de tooltip explicito ja usada em _production_lock_
	# reason/_building_lock_reason).
	var cast_button := Button.new()
	if spell == null:
		cast_button.text = "Sem efeito"
		cast_button.disabled = true
	elif not SpellManager.can_cast(human, spell_name, TurnManager.turn_number):
		var turns_left = SpellManager.cooldown_ends_at(human, spell_name) - TurnManager.turn_number
		cast_button.text = "Recarga (%d)" % max(turns_left, 1)
		cast_button.disabled = true
	elif not SpellManager.has_enough_mana(human, spell_name, GameManager.hex_grid):
		cast_button.text = "Sem mana"
		cast_button.disabled = true
	else:
		cast_button.text = "Conjurar"
		cast_button.pressed.connect(_on_cast_spell_pressed.bind(spell_name))
	header.add_child(cast_button)

	var description_label := Label.new()
	description_label.theme_type_variation = &"MutedLabel"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = spell.description if spell else "Efeito ainda não implementado."
	box.add_child(description_label)

	return box

func _on_cast_spell_pressed(spell_name: String) -> void:
	SelectionManager.start_spell_targeting(spell_name)
	_close_overlay_panels()
	EventBus.notify.emit("Escolha um alvo no mapa para %s." % spell_name, "")

## Painel de Debug (botao so visivel em OS.is_debug_build(), ver _ready())
## — pedido do usuario: "adicione opcoes debug onde eu posso tirar a fog
## do mapa e coisas assim". Revelar mapa, ouro extra, completar pesquisa e
## forcar fim de jogo: conveniencias comuns pra testar o resto do jogo sem
## precisar jogar uma partida inteira do zero toda vez.
func _on_debug_pressed() -> void:
	if debug_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(debug_panel)
	_refresh_debug_panel()

func _on_debug_close_pressed() -> void:
	_close_overlay_panels()

func _refresh_debug_panel() -> void:
	var hex_grid = GameManager.hex_grid
	var fog_disabled = hex_grid != null and hex_grid.debug_fog_disabled
	debug_mode_button.button_pressed = GameManager.debug_mode
	debug_mode_button.text = "Desativar Modo Debug" if GameManager.debug_mode else "Ativar Modo Debug (tudo liberado, producao instantanea)"
	debug_reveal_map_button.button_pressed = fog_disabled
	debug_reveal_map_button.text = "Restaurar Neblina" if fog_disabled else "Revelar Mapa (sem neblina)"
	debug_complete_research_button.disabled = GameManager.human_player == null or GameManager.human_player.current_research == ""

## Pedido do usuario: "libere no modo debug, quando eu ativar, tudo
## liberado, tudo fica disponivel todas as pesquisas ficam feitas, e o
## tempo de fazer qualquer unidade e 1 turno". GameManager.set_debug_mode
## faz o trabalho de verdade (marca toda tech como pesquisada + liga o
## efeito continuo de producao instantanea, ver comentario la) — aqui so
## atualiza o que ja esta na tela: o painel de Tecnologia (se aberto, as
## techs viram "Pesquisada" na hora) e o painel de producao da cidade
## sendo vista (novas tropas/predios liberados aparecem sem precisar
## fechar/reabrir a cidade).
func _on_debug_mode_pressed() -> void:
	GameManager.set_debug_mode(not GameManager.debug_mode)
	_refresh_debug_panel()
	if tech_panel.visible:
		_refresh_tech_panel()
	_refresh_viewed_city()

func _on_debug_reveal_map_pressed() -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null:
		return
	hex_grid.set_debug_fog_disabled(not hex_grid.debug_fog_disabled)
	_refresh_debug_panel()

func _on_debug_gold_pressed() -> void:
	if GameManager.human_player == null:
		return
	GameManager.human_player.gold += 100
	_refresh_stats()

func _on_debug_complete_research_pressed() -> void:
	GameManager.debug_complete_current_research()
	_refresh_debug_panel()
	if tech_panel.visible:
		_refresh_tech_panel()

func _on_debug_win_pressed() -> void:
	GameManager.debug_force_game_over(true)

func _on_debug_lose_pressed() -> void:
	GameManager.debug_force_game_over(false)

## Emite o pedido de reinicio (Main.gd regenera mapa/jogo de forma sincrona
## nesse mesmo emit) e so entao atualiza a propria HUD com o estado novo.
func _on_restart_pressed() -> void:
	EventBus.restart_requested.emit()
	_close_overlay_panels()
	end_turn_button.disabled = false
	tech_button.disabled = false
	diplomacy_button.disabled = false
	victory_button.disabled = false
	grimoire_button.disabled = false
	debug_button.disabled = false
	unit_panel.visible = false
	production_tabs.visible = false
	worked_tiles_label.visible = false
	worked_tiles_scroll.visible = false
	production_progress_label.visible = false
	production_progress_bar.visible = false
	_viewed_city = null
	action_bar.visible = true
	tile_info_panel.visible = false
	_update_tile_info_panel_size(false)
	tile_info_label.text = "Selecione um tile"
	for child in notification_stack.get_children():
		child.queue_free()
	_on_turn_changed(TurnManager.turn_number, TurnManager.current_player_index)

func _on_turn_changed(turn_number: int, _player_index: int) -> void:
	turn_label.text = "Turno %d" % turn_number
	_refresh_stats()
	if tech_panel.visible:
		_refresh_tech_panel()
	if diplomacy_panel.visible:
		_refresh_diplomacy_panel()
	if grimoire_panel.visible:
		_refresh_grimoire_panel()
	# Regressao: o painel da cidade so se atualizava ao clicar de novo no
	# tile (_on_produce_pressed/_on_worked_tile_pressed chamavam isso, mas
	# _on_turn_changed nao) — produzir um predio parecia "nao fazer nada"
	# pro jogador, porque progresso/predio concluido nunca aparecia sem
	# reclicar a cidade manualmente.
	_refresh_viewed_city()

## Fonte unica pro texto de ouro/mana/estatisticas da barra superior —
## chamada tanto em troca de turno quanto apos qualquer notificacao
## (_on_notify), o que cobre conjurar um feitico (gasta mana no meio do
## turno, ver SelectionManager._handle_spell_targeting_click) sem precisar
## de mais um gancho de atualizacao dedicado so pra isso.
func _refresh_stats() -> void:
	var player = GameManager.human_player
	if player:
		stats_label.text = "Cidades: %d | Unidades: %d" % [player.cities.size(), player.units.size()]
		gold_label.text = "Ouro: %d" % int(player.gold)
		mana_label.text = "Mana: %d (+%d)" % [int(player.mana), int(player.mana_income_per_turn)]
		_refresh_tech_button_progress(player)

## Progresso da pesquisa atual direto no botao "Tecnologia" da barra
## superior (pedido do usuario: reorganizar a HUD "parecido com os de
## civilization 6" — la o icone de pesquisa na barra ja mostra o progresso
## sem precisar abrir a arvore inteira). So texto (sem anel/barra grafica
## nova) de proposito: menor risco, reusa o mesmo botao/tema que ja existe.
func _refresh_tech_button_progress(player: PlayerData) -> void:
	if player.current_research == "":
		tech_button.text = "Tecnologia"
		return
	var tech: TechData = TechDatabase.get_tech(player.current_research)
	if tech == null:
		tech_button.text = "Tecnologia"
		return
	var pct = int(round(min(player.research_progress / tech.cost, 1.0) * 100.0)) if tech.cost > 0.0 else 100
	tech_button.text = "%s (%d%%)" % [RaceTheme.tech_name(tech.id, player.civ.race), pct]

## Mensagens curtas (combate, fundacao/captura de cidade) que aparecem no
## topo da tela e somem sozinhas — sem isso, um ataque do rival fora de
## tela passaria despercebido ate o jogador notar sozinho.
func _on_notify(text: String, _sfx_kind: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	notification_stack.add_child(label)

	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

	_refresh_stats()

func _on_tile_selected(coord: Vector2i, data: HexTileData) -> void:
	_viewed_city = null
	# ActionBar so some quando uma cidade PROPRIA esta selecionada (ver mais
	# abaixo, "city.owner_player == GameManager.human_player") — pedido do
	# usuario: "ao clicar na cidade, essa area do menu some, e fica so o
	# menu da cidade ocupando a parte direita... ao clicar em outra coisa
	# fora da cidade, o menu da cidade some e volta o menu geral". Default
	# visivel aqui cobre os dois early-return abaixo (sem tile/tropa sem
	# cidade), so a branch de cidade propria mais adiante desliga.
	action_bar.visible = true
	if data == null:
		# Sem tile selecionado, sem painel — antes ficava sempre visivel so
		# com o texto "Selecione um tile", cobrindo boa parte da tela a toa
		# (pedido do usuario).
		tile_info_panel.visible = false
		tile_info_label.text = "Selecione um tile"
		production_tabs.visible = false
		worked_tiles_label.visible = false
		worked_tiles_scroll.visible = false
		production_progress_label.visible = false
		production_progress_bar.visible = false
		return

	var hex_grid = GameManager.hex_grid
	var unit_here = hex_grid.get_unit_at(coord) if hex_grid else null
	var city_here = hex_grid.get_city_at(coord) if hex_grid else null
	# Pedido do usuario: "ao clicar [numa unidade] ao invés de mostrar as
	# características da célula se mostra as características da tropa" —
	# unidade PROPRIA sem cidade no mesmo tile toma conta da tela via
	# UnitPanel (ver _on_unit_selected, que ja disparou nesse MESMO clique
	# — SelectionManager.handle_world_click emite unit_selected ANTES de
	# tile_selected), entao o painel generico de tile fica de fora, sem
	# competir por espaco/atencao. Cidade PROPRIA no mesmo tile (unidade
	# guarnicionada) continua mostrando producao normalmente — gerenciar a
	# cidade nao pode ficar inacessivel so porque ha uma unidade guardando
	# ela.
	if unit_here != null and unit_here.owner_player == GameManager.human_player and city_here == null:
		tile_info_panel.visible = false
		production_tabs.visible = false
		worked_tiles_label.visible = false
		worked_tiles_scroll.visible = false
		production_progress_label.visible = false
		production_progress_bar.visible = false
		return

	tile_info_panel.visible = true
	# Default "sem cidade aqui" — a branch abaixo (city != null) sobrescreve
	# com o item de verdade, mesmo padrao de "action_bar.visible = true" no
	# topo desta funcao (default primeiro, excecao especifica depois).
	_refresh_production_progress(null, null)

	var text = "%s (%d, %d)\nComida %d | Producao %d | Ouro %d" % [
		data.display_name, coord.x, coord.y, data.food_yield, data.production_yield, data.gold_yield
	]
	if data.resource != "":
		text += "\nRecurso: %s" % ResourceDatabase.display_name(data.resource)

	if hex_grid:
		var city = hex_grid.get_city_at(coord)
		if city:
			var city_race: String = city.owner_player.civ.race
			text += "\n\n%s\nPopulacao: %d" % [city.city_name, city.population]
			# Pedido do usuario apos o redesenho do sistema de comida ("lá em
			# cima não tá mostrando a comida"): o painel de cidade nunca
			# mostrou estoque de comida nenhum (nem no sistema antigo, so
			# acumulava silenciosamente) — agora que existe um teto de
			# armazenamento de verdade (City.food_storage_cap()) e consumo por
			# populacao (City.FOOD_CONSUMPTION_PER_POP), o jogador precisa ver
			# os dois pra entender por que a cidade esta (ou nao) perto de
			# crescer. net_food = producao bruta do turno - consumo da
			# populacao (mesma conta de City.process_turn()), com sinal
			# explicito (+/-) pra ficar claro se o estoque esta subindo ou
			# estagnado.
			var net_food = city.collect_yields(hex_grid).food - city.population * City.FOOD_CONSUMPTION_PER_POP
			text += "\nComida: %d/%d (%s%d/turno)" % [
				int(city.stored_food), int(city.food_storage_cap()),
				"+" if net_food >= 0.0 else "", int(net_food)
			]
			_refresh_production_progress(city, hex_grid)
			var built_names: Array[String] = []
			for id in city.buildings.keys():
				var b: BuildingData = BuildingDatabase.get_building(id)
				if b:
					built_names.append(RaceTheme.building_name(id, city_race))
			# Sempre mostra o limite (mesmo com 0 predios ainda) — senao o
			# jogador so descobre que ha um teto quando ja esbarra nele.
			text += "\nPredios: %d/%d" % [city.buildings.size(), city.max_building_slots()]
			if built_names.size() > 0:
				text += " (%s)" % ", ".join(built_names)
			if city.owner_player == GameManager.human_player:
				_viewed_city = city
				action_bar.visible = false

		# Covil de Monstro (Unit neutra, owner_player == null — ver
		# MonsterDatabase): mostra quem guarda e quanto paga derrotar, senao
		# o jogador so descobre o risco DEPOIS de atacar as cegas.
		if unit_here and unit_here.owner_player == null:
			text += "\n\nCovil de Monstro: %s (HP %d/%d)\nRecompensa: %d ouro" % [
				unit_here.unit_data.unit_name, int(unit_here.hp), int(unit_here.unit_data.max_hp),
				int(unit_here.unit_data.gold_reward)
			]

	tile_info_label.text = text
	production_tabs.visible = _viewed_city != null
	_update_tile_info_panel_size(_viewed_city != null)
	if _viewed_city:
		# O painel de cidade toma conta da vizinhanca inteira do ActionBar
		# (ver _update_tile_info_panel_size/action_bar.visible acima) — o
		# UnitPanel ocupa exatamente essa mesma area agora (ver _on_unit_
		# selected), entao precisa sumir enquanto a cidade estiver em foco
		# mesmo que haja uma unidade guarnicionada nela, senao os dois
		# competiriam pelo mesmo espaco. _on_unit_selected roda ANTES desta
		# funcao no mesmo clique (SelectionManager emite unit_selected
		# primeiro), entao essa linha e quem tem a ultima palavra.
		unit_panel.visible = false
		# Pedido do usuario: "faca ser exibido somente tropas que voce pode
		# fazer ao clicar na cidade" — antes TODO kind do roster ficava
		# sempre visivel (so desabilitado com tooltip explicando o motivo,
		# ver _production_lock_reason). Agora o botao so aparece se a
		# tropa estiver REALMENTE treinavel agora (pesquisa E predio, e no
		# caso de tropa racial, tambem a raca certa) — can_train() ja cobre
		# os tres sozinho (ver comentario dela em City.gd), entao nao
		# precisa de checagem separada de raca aqui como tinha antes.
		#
		# A propria grade de producao (botoes de predio/tropa) so aparece pra
		# cidade PROPRIA (ver guarda "city.owner_player == GameManager.
		# human_player" acima) — entao retematizar os rotulos aqui sempre com
		# a raca do jogador humano esta correto, nunca precisa considerar
		# outro dono. Reaplicar o texto a cada clique em vez de so uma vez e
		# barato (mesma troca de string que os outros refreshes deste bloco
		# ja fazem) e cobre o caso comum de a raca so ficar conhecida DEPOIS
		# do _ready() (jogo ainda nao comecou quando os botoes sao criados,
		# ver _build_production_buttons/_label_building_buttons).
		var race: String = GameManager.human_player.civ.race
		for id in BUILDING_IDS:
			var btn := _build_button_for(id)
			btn.text = _building_button_label(id, race)
			# Pedido do usuario: "as construcoes que precisam de pesquisa so
			# aparecem listadas na cidade quando nos de fato criamos a
			# pesquisa, enquanto isso elas nao aparecem no menu da cidade" —
			# mesmo espirito ja aplicado as tropas acima (visivel so quando
			# REALMENTE liberado). Predio de RENDIMENTO sem tech associada
			# (so Torre dos Sabios) continua sempre visivel; predio com tech
			# propria (Quartel/Estabulo/Arquearia via trains_unit, Muralhas/
			# Celeiro/Oficina/Mercado via TechData.unlocks_building) some
			# ate a tech correspondente ser pesquisada, reaproveitando o
			# MESMO gate que ja trava a construcao em si (City._tech_
			# unlocked_for_building) — falta de sala/predio pre-requisito
			# continuam so DESABILITANDO o botao (com tooltip explicando,
			# ver _building_lock_reason), nao escondendo.
			btn.visible = _viewed_city._tech_unlocked_for_building(id)
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			_production_buttons[kind].text = _unit_button_label(kind, race)
			_production_buttons[kind].visible = GameManager.human_player.has_unlocked(kind) and _viewed_city.can_train(kind)
		build_granary_button.disabled = not _viewed_city.can_build("granary")
		build_workshop_button.disabled = not _viewed_city.can_build("workshop")
		build_market_button.disabled = not _viewed_city.can_build("market")
		build_walls_button.disabled = not _viewed_city.can_build("walls")
		build_barracks_button.disabled = not _viewed_city.can_build("barracks")
		build_archery_range_button.disabled = not _viewed_city.can_build("archery_range")
		build_stable_button.disabled = not _viewed_city.can_build("stable")
		build_siege_workshop_button.disabled = not _viewed_city.can_build("siege_workshop")
		build_arcane_tower_button.disabled = not _viewed_city.can_build("arcane_tower")
		build_griffin_roost_button.disabled = not _viewed_city.can_build("griffin_roost")
		build_druid_grove_button.disabled = not _viewed_city.can_build("druid_grove")
		build_runic_anvil_button.disabled = not _viewed_city.can_build("runic_anvil")
		build_shadow_crypt_button.disabled = not _viewed_city.can_build("shadow_crypt")
		_update_production_tooltips()
		_update_building_tooltips()
	_refresh_worked_tiles_row()

const BUILDING_IDS := [
	"granary", "workshop", "market", "walls",
	"barracks", "archery_range", "stable", "siege_workshop", "arcane_tower", "griffin_roost", "druid_grove",
	"runic_anvil", "shadow_crypt",
]

var _production_buttons: Dictionary = {} # kind -> Button, montado uma vez em _build_production_buttons()

## Um botao por UnitDatabase.PLAYER_TRAINABLE_KINDS, criado UMA VEZ aqui
## (nao recriado a cada refresh — perderia foco/hover toda hora a toa) e
## so tem .disabled/.tooltip_text atualizados depois (ver _on_tile_selected/
## _update_production_tooltips). Texto = nome + custo (mesmo formato de
## _label_building_buttons, pra tile de unidade e tile de predio lerem
## como a MESMA familia de card na grade) — um kind novo no roster ja
## aparece certo sem editar nenhum texto a mao. custom_minimum_size igual
## aos botoes de predio (ver HUD.tscn) pra grade ficar com colunas
## uniformes.
func _build_production_buttons() -> void:
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var btn := Button.new()
		btn.text = _unit_button_label(kind, "human")
		btn.custom_minimum_size = Vector2(150, 0)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.pressed.connect(_on_produce_pressed.bind(kind))
		production_row.add_child(btn)
		_production_buttons[kind] = btn

## Mesmo espirito de _building_button_label, pro roster de tropas.
func _unit_button_label(kind: String, race: String) -> String:
	var unit := UnitDatabase.create_unit(kind)
	return "%s  —  %d PP" % [RaceTheme.unit_name(kind, race), int(unit.production_cost)]

## Botao de producao so fica visivel quando a tropa ja esta REALMENTE
## treinavel (ver _on_tile_selected: visible = has_unlocked AND can_train,
## pedido do usuario: "faca ser exibido somente tropas que voce pode fazer
## ao clicar na cidade") — entao o tooltip aqui e so o tempo estimado de
## producao, nunca mais um motivo de bloqueio (esse motivo virou o proprio
## botao nao aparecer, em vez de aparecer desabilitado).
func _update_production_tooltips() -> void:
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		_production_buttons[kind].tooltip_text = _production_lock_reason(kind)

## So chamado pra botoes ja VISIVEIS (ver comentario acima), entao nunca
## precisa mais explicar pesquisa/predio faltando — so o tempo estimado.
func _production_lock_reason(kind: String) -> String:
	return _estimated_turns_tooltip(UnitDatabase.create_unit(kind).production_cost)

## "custo de producao/tempo" no card (pedido do usuario) — o NOME/custo
## cru ja aparece no texto do botao (ver _build_production_buttons), aqui
## Indicador de progresso do item ATUALMENTE em producao (nao um item so
## disponivel/travado — ver _estimated_turns_tooltip pra esse outro caso)
## — pedido do usuario: "quando uma construção ta sendo feita, tenha algum
## indicador de avanço... atualmente nao sabemos nem quanto demora... nem
## o progresso", "isso pra qualquer construção". `city == null` (tile sem
## cidade, ou early-return de tropa/tile vazio) esconde os dois nodes —
## mesmo padrao "default primeiro, excecao depois" de action_bar acima em
## _on_tile_selected. Mostrado pra QUALQUER cidade (propria ou rival, mesmo
## alcance que o texto antigo "Produzindo: X (12/25)" ja tinha), nao so a
## do jogador.
func _refresh_production_progress(city: City, hex_grid: HexGrid) -> void:
	# city.production_item == "" = cidade OCIOSA (ver comentario do campo
	# em City.gd) — nao ha item nenhum em producao pra mostrar progresso
	# de, mesmo tratamento que "sem cidade nenhuma" acima.
	if city == null or city.production_item == "":
		production_progress_label.visible = false
		production_progress_bar.visible = false
		rush_buy_button.visible = false
		return

	var city_race: String = city.owner_player.civ.race
	var building_in_progress: BuildingData = BuildingDatabase.get_building(city.production_item)
	var item_label = RaceTheme.building_name(city.production_item, city_race) if building_in_progress else RaceTheme.unit_name(city.production_item, city_race)
	var cost := city.production_cost()
	var stored := city.stored_production

	var turns_text := ""
	if hex_grid:
		var production_per_turn = city.collect_yields(hex_grid).production
		if production_per_turn > 0.0:
			var turns = ceili(max(cost - stored, 0.0) / production_per_turn)
			var suffix = "" if turns == 1 else "s"
			turns_text = " (~%d turno%s restante%s)" % [turns, suffix, suffix]
		else:
			turns_text = " (sem producao suficiente pra estimar o tempo)"

	production_progress_label.text = "Produzindo: %s — %d/%d PP%s" % [item_label, int(stored), int(cost), turns_text]
	production_progress_bar.max_value = max(cost, 0.01)
	production_progress_bar.value = stored
	production_progress_label.visible = true
	production_progress_bar.visible = true

	# Rush-buy (Mercado, ver City.can_rush_buy()) — pedido do usuario: "o
	# mercado pode servir pra [dar um uso real pro ouro]"/"é uma boa, faça
	# isso". So aparece com o Mercado ja construido NESTA cidade E so pra
	# cidade PROPRIA (mesmo gate de "city.owner_player == GameManager.human_
	# player" usado pra _viewed_city/production_tabs logo abaixo — nao faz
	# sentido comprar producao de uma cidade inimiga so por ela estar sendo
	# espiada). Desabilita (mas continua visivel, com o custo no texto) se o
	# jogador nao tiver ouro suficiente AINDA, em vez de sumir — assim ele
	# sabe que a opcao existe e quanto falta juntar.
	rush_buy_button.visible = city.owner_player == GameManager.human_player and city.can_rush_buy()
	if rush_buy_button.visible:
		var rush_cost := city.rush_buy_cost(GameManager.hex_grid)
		rush_buy_button.text = "Comprar com Ouro (%d)" % int(rush_cost)
		rush_buy_button.disabled = city.owner_player == null or city.owner_player.gold < rush_cost

## e so o tempo ESTIMADO no ritmo de producao atual da cidade vista, pra
## nao ter que fazer conta de cabeca. Arredonda pra cima (ceil): "pronto no
## proximo turno" so quando realmente sobra 1 turno inteiro ou menos.
func _estimated_turns_tooltip(cost: float) -> String:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null or _viewed_city == null:
		return ""
	var production_per_turn = _viewed_city.collect_yields(hex_grid).production
	if production_per_turn <= 0.0:
		return "Custo: %d PP (sem producao suficiente pra estimar o tempo)" % int(cost)
	var turns = ceili(cost / production_per_turn)
	return "Custo: %d PP (~%d turno%s no ritmo atual)" % [int(cost), turns, "" if turns == 1 else "s"]

func _build_button_for(id: String) -> Button:
	match id:
		"granary": return build_granary_button
		"workshop": return build_workshop_button
		"market": return build_market_button
		"walls": return build_walls_button
		"barracks": return build_barracks_button
		"archery_range": return build_archery_range_button
		"stable": return build_stable_button
		"siege_workshop": return build_siege_workshop_button
		"arcane_tower": return build_arcane_tower_button
		"griffin_roost": return build_griffin_roost_button
		"druid_grove": return build_druid_grove_button
		"runic_anvil": return build_runic_anvil_button
		"shadow_crypt": return build_shadow_crypt_button
	return null

func _update_building_tooltips() -> void:
	var race: String = GameManager.human_player.civ.race
	for id in BUILDING_IDS:
		_build_button_for(id).tooltip_text = _building_lock_reason(id, race)

## "" quando o predio ja esta liberado pra construir. Predio de treino
## (Quartel em diante) exige a mesma tecnologia que desbloqueia a tropa
## correspondente (City._tech_unlocked_for_building) — pedido do usuario:
## "so posso construir esses predios especiais quando pesquisar a
## tecnologia, ai aparece disponivel pra construir". Falta de tecnologia
## tem prioridade sobre limite de slots na mensagem (pesquisar primeiro e
## sempre o proximo passo, crescer a cidade nao adianta sem a pesquisa).
func _building_lock_reason(id: String, race: String) -> String:
	if _viewed_city.buildings.has(id):
		return ""
	var building: BuildingData = BuildingDatabase.get_building(id)
	var tech: TechData = TechDatabase.tech_that_unlocks(building.trains_unit) if building else null
	if tech == null and building:
		tech = TechDatabase.tech_that_unlocks_building(id) # ex: Muralhas, sem trains_unit
	if tech and not GameManager.human_player.researched_techs.has(tech.id):
		return "Requer pesquisar: %s" % RaceTheme.tech_name(tech.id, race)
	if _viewed_city.buildings.size() >= _viewed_city.max_building_slots():
		return "Sem espaco: %d/%d predios (cidade precisa crescer)" % [_viewed_city.buildings.size(), _viewed_city.max_building_slots()]
	return _estimated_turns_tooltip(building.production_cost)

## Um botao por vizinho valido (nem oceano) da cidade vista, mostrando
## terreno + rendimento; toggle_mode reflete se aquele cidadao ja esta
## trabalhando ali. So aparece pra cidade PROPRIA (mesma regra do
## production_tabs) — nao da pra microgerenciar cidade alheia.
func _refresh_worked_tiles_row() -> void:
	for child in worked_tiles_row.get_children():
		child.queue_free()

	if _viewed_city == null:
		worked_tiles_label.visible = false
		worked_tiles_scroll.visible = false
		return

	var hex_grid = GameManager.hex_grid
	worked_tiles_label.visible = true
	worked_tiles_scroll.visible = true
	worked_tiles_label.text = "Tiles trabalhados: %d/%d (clique pra trocar)" % [
		_viewed_city.worked_tiles.size(), _viewed_city.population
	]

	for n in hex_grid.get_neighbors(_viewed_city.coord):
		var data: HexTileData = hex_grid.get_tile(n)
		if data == null or data.blocks_land_units():
			continue
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = n in _viewed_city.worked_tiles
		var label = data.display_name
		if data.resource != "":
			label += " (%s)" % ResourceDatabase.display_name(data.resource)
		# Rendimento EFETIVO (com bonus de tecnologia/recurso ja somado) —
		# mostrar so o "cru" do terreno confundiria o jogador sobre por que
		# a cidade rende mais do que os numeros aqui sugerem. Simbolos em
		# vez da notacao crua "F2 P0 G1" (pedido do usuario: "confusa e
		# poluida") — mesma info, leitura visual mais rapida.
		var y = _viewed_city.effective_tile_yield(data)
		btn.text = "%s\n🌾%d ⚙️%d 🪙%d" % [label, y.food, y.production, y.gold]
		btn.pressed.connect(_on_worked_tile_pressed.bind(n))
		worked_tiles_row.add_child(btn)

func _on_worked_tile_pressed(coord: Vector2i) -> void:
	if _viewed_city == null:
		return
	_viewed_city.toggle_worked_tile(coord, GameManager.hex_grid)
	_refresh_viewed_city()

## UnitPanel agora mora na MESMA vizinhanca que TileInfoPanel, ao lado do
## ActionBar (pedido do usuario: "ao clicar em tropas, elas fiquem ali do
## lado do menu de opções, assim como fica quando clicamos nas células" —
## ver anchor/offset dela em HUD.tscn, identicos ao estado COMPACTO de
## TileInfoPanel). Se a mesma tropa estiver guarnicionada numa cidade
## PROPRIA, `_on_tile_selected` (que roda logo em seguida, no MESMO
## clique — SelectionManager emite unit_selected antes de tile_selected)
## forca `unit_panel.visible = false` de volta, porque a cidade toma conta
## dessa mesma area inteira nesse caso (pedido do usuario: "ao clicar na
## cidade... fica so o menu da cidade ocupando a parte direita").
func _on_unit_selected(unit: Unit) -> void:
	if unit == null:
		unit_panel.visible = false
		return
	unit_panel.visible = true
	var owner_race: String = unit.owner_player.civ.race if unit.owner_player else "human"
	var text = "%s (%s)\nHP %d/%d | Ataque %.1f | Defesa %.1f | Movimento %.1f/%.1f" % [
		RaceTheme.unit_name(unit.unit_data.visual_kind, owner_race), unit.veterancy_title(), int(unit.hp), int(unit.unit_data.max_hp),
		unit.unit_data.attack, unit.unit_data.defense, unit.movement_left, unit.unit_data.movement_points
	]
	if unit.unit_data.attack_range > 1:
		text += "\nAlcance de ataque: %d" % unit.unit_data.attack_range
	if unit.veterancy_level > 0:
		text += "\n+%d%% ataque/defesa (%d abates)" % [int(unit.veterancy_level * Unit.VETERANCY_BONUS_PER_LEVEL * 100), unit.kills]
	if unit.embarked:
		text += "\nEmbarcada (em trânsito pelo mar — não pode atacar/fortificar/explorar)"
	elif unit.fortified:
		text += "\nFortificada (+%d%% defesa, cura passiva)" % int(CombatResolver.FORTIFY_DEFENSE_BONUS * 100)
	elif unit.exploring:
		text += "\nExplorando automaticamente"
	elif unit.move_order_target != Unit.NO_MOVE_ORDER:
		text += "\nEm marcha ate (%d, %d)" % [unit.move_order_target.x, unit.move_order_target.y]
	if SelectionManager.move_mode:
		text += "\n» Clique no mapa pra mover «"
	unit_info_label.text = text
	found_city_button.visible = unit.unit_data.can_found_city and not unit.embarked
	# Fortificar/Explorar sao alternancias (toggle_mode, ver HUD.tscn) —
	# button_pressed precisa refletir o estado REAL da unidade toda vez
	# que a selecao (ou o proprio estado) muda, senao o botao mostraria
	# "nao pressionado" pra uma unidade ja fortificada so por ter sido
	# reselecionada. Desabilitados enquanto embarcada (Roadmap 2.0 Parte 1,
	# C2 — unidade em transito nao fortifica/explora; SelectionManager ja
	# recusa a acao, isto e so a segunda camada/feedback visual).
	fortify_button.button_pressed = unit.fortified
	fortify_button.disabled = unit.embarked
	explore_button.button_pressed = unit.exploring
	explore_button.disabled = unit.embarked
	# Embarcar (Roadmap 2.0 Parte 1, acesso naval) — so aparece pra unidade
	# terrestre com Navegação ja pesquisada; desabilitado (mas visivel, pra
	# o jogador entender que existe) fora de um tile costeiro ou ja
	# embarcada (toggle e mao unica, ver SelectionManager.
	# toggle_embark_selected — desembarque e sempre automatico).
	var owner_player := unit.owner_player
	embark_button.visible = not unit.unit_data.flies and owner_player != null and TechDatabase.is_navigation_researched(owner_player.researched_techs)
	if embark_button.visible:
		embark_button.button_pressed = unit.embarked
		embark_button.disabled = unit.embarked or (GameManager.hex_grid and not GameManager.hex_grid.is_coastal_tile(unit.coord))

## Regressao: o painel de fim de jogo podia aparecer POR CIMA de um
## overlay (Tecnologia/Diplomacia/Grimorio) que o jogador tivesse deixado
## aberto — _close_overlay_panels() agora roda ANTES de mostrar este, e os
## botoes que abririam outro overlay ficam desabilitados (senao dava pra
## "fechar" a tela de fim de jogo clicando em Tecnologia sem nenhum jeito
## de trazer ela de volta, ja que so o restart limpa esse estado).
func _on_game_over(victory: bool) -> void:
	# _show_overlay ja fecha qualquer overlay aberto e esconde minimapa/
	# painel de cidade/unidade/botao de turno (mesma regra dos outros
	# overlays agora) — sem precisar duplicar essa logica aqui.
	_show_overlay(game_over_panel)
	end_turn_button.disabled = true
	tech_button.disabled = true
	diplomacy_button.disabled = true
	victory_button.disabled = true
	grimoire_button.disabled = true
	debug_button.disabled = true

	var summary = ""
	if GameManager.human_player:
		summary = "\n\nTurnos: %d | Cidades: %d | Unidades: %d | Ouro: %d" % [
			TurnManager.turn_number, GameManager.human_player.cities.size(),
			GameManager.human_player.units.size(), int(GameManager.human_player.gold)
		]

	# Roadmap "Fase F" F6 -- texto generico de proposito (nao mais "todos os
	## reinos rivais foram derrotados"/"seu reino caiu"): desde que Territorial
	## e Arcana existem, um fim de jogo pode nao ter eliminacao nenhuma
	## envolvida, e este handler nao sabe QUAL vitoria aconteceu (so um bool
	## human-perspective, ver EventBus.game_over) -- o veredito ESPECIFICO
	## (quem, como) fica com _on_victory_achieved logo abaixo, que roda em
	## seguida pra toda vitoria de verdade.
	if victory:
		game_over_label.text = "VITÓRIA!" + summary
	else:
		game_over_label.text = "DERROTA..." + summary
