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
## Roadmap "dois botoes": Magia e Tecnologia deixaram de ser abas dentro
## de UM painel compartilhado (pedido explicito: "divida a arvore de
## tecnologia da de magia, serao 2 botoes... nao serao mais abas juntas")
## — agora sao DOIS paineis full-screen independentes, cada um com seu
## proprio botao no ActionBar, reusando o MESMO mecanismo generico de
## overlay (_show_overlay/_close_overlay_panels) que Diplomacia/Grimorio/
## Vitoria ja usam. Magia continua no TechTree.gd de sempre (grafo/
## componentes conexos, CONTEUDO intocado). Tecnologia usa TechTierBoard.
## gd (layout por NIVEL). O CHROME (fundo/cabecalho) dos dois paineis usa
## a mesma paleta escura local (ver _style_tech_panel_chrome) — so o
## conteudo interno de Magia continua no visual antigo, regra de sempre.
@onready var magic_button: Button = $ActionBar/ActionBarBox/MagicButton
@onready var magic_panel: PanelContainer = $MagicPanel
@onready var tech_tree_magic: TechTree = $MagicPanel/MagicBox/MagicScroll/MagicTree
@onready var magic_close_button: Button = $MagicPanel/MagicBox/MagicHeader/MagicCloseButton

@onready var tech_button: Button = $ActionBar/ActionBarBox/TechButton
@onready var tech_panel: PanelContainer = $TechPanel
@onready var tech_tree_doutrina: TechTierBoard = $TechPanel/TechBox/DoutrinaScroll/DoutrinaTree
@onready var tech_close_button: Button = $TechPanel/TechBox/TechHeader/TechCloseButton
## Roadmap "reorganizar barra lateral": Diplomacia e Vitoria saíram da
## ActionBar (canto inferior direito) e viraram icones compactos no canto
## SUPERIOR direito (dentro do TopBar, ver IconGroup em HUD.tscn) — pedido
## explicito: "ficam no canto superior direito assim como no civilization
## como icones". So o BOTAO mudou de lugar/tamanho — o painel/logica de
## abrir continuam identicos (_show_overlay, mesmo mecanismo de sempre).
@onready var diplomacy_button: Button = $TopBar/TopBarRow/IconGroup/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyHeader/DiplomacyCloseButton
## Roadmap "Fase F" F1/F2/F5 -- mesmo padrao de overlay do Diplomacy acima.
@onready var victory_button: Button = $TopBar/TopBarRow/IconGroup/VictoryButton
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_rows: VBoxContainer = $VictoryPanel/VictoryBox/VictoryRows
@onready var victory_close_button: Button = $VictoryPanel/VictoryBox/VictoryHeader/VictoryCloseButton
@onready var grimoire_button: Button = $ActionBar/ActionBarBox/GrimoireButton
@onready var grimoire_panel: PanelContainer = $GrimoirePanel
## Roadmap "Fase Macro" 5B.2 -- prompt minimo de Preparation (docs/DRAGON_
## EVENT_DESIGN.md): so aparece enquanto existir um WorldEvent em
## Preparation que o humano ainda nao respondeu (ver _refresh_world_event_
## panel). Nao e' um overlay bloqueante como os outros paineis -- fica
## visivel/escondido sozinho conforme o estado do evento muda a cada turno.
@onready var world_event_panel: PanelContainer = $WorldEventPanel
@onready var world_event_title_label: Label = $WorldEventPanel/WorldEventBox/WorldEventTitleLabel
@onready var world_event_text_label: Label = $WorldEventPanel/WorldEventBox/WorldEventTextLabel
@onready var world_event_participate_button: Button = $WorldEventPanel/WorldEventBox/WorldEventButtons/WorldEventParticipateButton
@onready var world_event_decline_button: Button = $WorldEventPanel/WorldEventBox/WorldEventButtons/WorldEventDeclineButton
## Roadmap "Fase Macro" 5B.3-C (Dragon Event UX) -- pedido explicito do
## usuario apos o playtest visual de 5B.3-B: "o Dragão já funciona como
## entidade de jogo, porém o evento ainda não funciona como evento de jogo
## na camada de comunicação/UX". Modal BLOQUEANTE (mesmo padrao de overlay
## do Tech/Diplomacy/Victory, ver _show_overlay) mostrado UMA VEZ quando um
## evento entra em Announced (ver _on_world_event_phase_changed) -- nunca
## reaproveita o canal de toast generico (EventBus.notify) usado por
## "Goblin eliminado" etc, pedido explicito do usuario: "não misturar esse
## anúncio com o canal visual usado" pros mobs comuns.
@onready var dragon_announcement_panel: PanelContainer = $DragonAnnouncementPanel
@onready var dragon_announcement_text_label: Label = $DragonAnnouncementPanel/DragonAnnouncementBox/DragonAnnouncementTextLabel
@onready var dragon_announcement_continue_button: Button = $DragonAnnouncementPanel/DragonAnnouncementBox/DragonAnnouncementContinueButton
## Roadmap "Fase Macro" 5B.3-G -- mesmo padrao MODAL bloqueante acima,
## agora pro DESFECHO do evento (defeated/devastated/no_target). Playtest
## revelou que o toast pequeno de _resolve_with_outcome (EventBus.notify)
## era UX fraca demais pra um evento continental de varios turnos: "o
## jogador viu apenas um texto minusculo e interpretou como bug/
## desaparecimento". Disparado em _on_world_event_phase_changed quando a
## fase vira Resolution -- DragonEvent.gd nao emite mais notify nenhum
## pro proprio desfecho (ver _resolve_with_outcome).
@onready var dragon_resolution_panel: PanelContainer = $DragonResolutionPanel
@onready var dragon_resolution_title_label: Label = $DragonResolutionPanel/DragonResolutionBox/DragonResolutionTitleLabel
@onready var dragon_resolution_text_label: Label = $DragonResolutionPanel/DragonResolutionBox/DragonResolutionTextLabel
@onready var dragon_resolution_continue_button: Button = $DragonResolutionPanel/DragonResolutionBox/DragonResolutionContinueButton
## Roadmap "Dragon Event v1 fechado" -- ranking de dano (ver format_dragon_
## damage_ranking). Header so' visivel quando ha' pelo menos 1 linha (civ
## com dano > 0) -- eventos sem combate real contra o Dragao (ex.: no_target)
## nunca mostram uma tabela vazia.
@onready var dragon_resolution_ranking_header_label: Label = $DragonResolutionPanel/DragonResolutionBox/DragonResolutionRankingHeaderLabel
@onready var dragon_resolution_ranking_box: VBoxContainer = $DragonResolutionPanel/DragonResolutionBox/DragonResolutionRankingBox
## Tracker persistente (NAO bloqueante, diferente do modal acima) -- visivel
## durante Preparation/Active/Resolution, escondido em Announced/Completed
## (pedido do usuario: "o evento precisa permanecer visível depois do
## modal"). Responde "o que esta acontecendo e o que eu devo fazer", nunca
## "como esta o Dragao" (isso e' a Boss Bar abaixo) -- duas funcoes
## deliberadamente separadas.
@onready var world_event_tracker: PanelContainer = $WorldEventTracker
@onready var world_event_tracker_status_label: Label = $WorldEventTracker/WorldEventTrackerBox/WorldEventTrackerStatusLabel
@onready var world_event_tracker_objective_label: Label = $WorldEventTracker/WorldEventTrackerBox/WorldEventTrackerObjectiveLabel
@onready var world_event_tracker_target_label: Label = $WorldEventTracker/WorldEventTrackerBox/WorldEventTrackerTargetLabel
## Boss Bar -- so' enquanto o evento estiver Active (pedido do usuario: "o
## jogador precisa saber se o Dragão ainda está vivo... sem precisar
## enxergar fisicamente a criatura"). Responde "como esta o Dragao",
## atualizada a cada turno mesmo com a criatura fora de tela.
@onready var dragon_boss_bar: PanelContainer = $DragonBossBar
@onready var dragon_boss_bar_name_label: Label = $DragonBossBar/DragonBossBarBox/DragonBossBarNameLabel
@onready var dragon_boss_bar_health_bar: ProgressBar = $DragonBossBar/DragonBossBarBox/DragonBossBarHealthBar
@onready var dragon_boss_bar_health_label: Label = $DragonBossBar/DragonBossBarBox/DragonBossBarHealthLabel
@onready var dragon_boss_bar_target_label: Label = $DragonBossBar/DragonBossBarBox/DragonBossBarTargetLabel
@onready var grimoire_rows: VBoxContainer = $GrimoirePanel/GrimoireBox/GrimoireScroll/GrimoireRows
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
## Roadmap "reorganizar barra lateral": o botao que ABRE o debug_panel
## saiu da HUD por completo e foi pro menu de pausa (pedido explicito: "o
## debug tambem fica no menu") — ver PauseMenu.gd._on_debug_pressed(), que
## chama HUD._on_debug_pressed() abaixo direto. O painel em si e todos os
## botoes INTERNOS dele continuam aqui, intocados.
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_close_button: Button = $DebugPanel/DebugBox/DebugHeader/DebugCloseButton
@onready var debug_mode_button: Button = $DebugPanel/DebugBox/DebugModeButton
@onready var debug_reveal_map_button: Button = $DebugPanel/DebugBox/DebugRevealMapButton
@onready var debug_gold_button: Button = $DebugPanel/DebugBox/DebugGoldButton
@onready var debug_complete_research_button: Button = $DebugPanel/DebugBox/DebugCompleteResearchButton
@onready var debug_win_button: Button = $DebugPanel/DebugBox/DebugWinButton
@onready var debug_lose_button: Button = $DebugPanel/DebugBox/DebugLoseButton
## Roadmap "Fase Macro" 5B.2 -- SO debug/playtest manual (docs/DRAGON_
## EVENT_DESIGN.md). Nunca muda WorldEventTrigger.should_spawn_dragon (o
## trigger de producao continua intacto); so da um atalho pra ver o
## vertical slice sem esperar turno 30+/RNG.
@onready var debug_force_dragon_button: Button = $DebugPanel/DebugBox/DebugForceDragonButton

var _viewed_city: City = null

## Task 23 -- inspecao unificada (ver TileInspector.gd). O painel guarda so'
## COORD + CHAVE da entidade mostrada (nunca uma referencia a Unit/City):
## cada refresh reconsulta o mapa, entao entidade destruida/capturada/
## carregada de save nunca deixa o painel apontando pra objeto invalido.
const NO_INSPECT_COORD := Vector2i(-999999, -999999)
var _inspect_coord: Vector2i = NO_INSPECT_COORD
var _inspect_key: String = ""
var _inspection: Dictionary = {}
var _inspect_tabs: HFlowContainer
var _tile_info_scroll: ScrollContainer
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
	_build_additional_building_buttons()
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
	magic_button.pressed.connect(_on_magic_pressed)
	magic_close_button.pressed.connect(_on_magic_close_pressed)
	tech_button.pressed.connect(_on_tech_pressed)
	rush_buy_button.pressed.connect(_on_rush_buy_pressed)
	tech_close_button.pressed.connect(_on_tech_close_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
	victory_button.pressed.connect(_on_victory_pressed)
	victory_close_button.pressed.connect(_on_victory_close_pressed)
	grimoire_button.pressed.connect(_on_grimoire_pressed)
	grimoire_close_button.pressed.connect(_on_grimoire_close_pressed)
	world_event_participate_button.pressed.connect(_on_world_event_participate_pressed)
	world_event_decline_button.pressed.connect(_on_world_event_decline_pressed)
	dragon_announcement_continue_button.pressed.connect(_on_dragon_announcement_continue_pressed)
	dragon_resolution_continue_button.pressed.connect(_on_dragon_resolution_continue_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	debug_close_button.pressed.connect(_on_debug_close_pressed)
	debug_mode_button.pressed.connect(_on_debug_mode_pressed)
	debug_reveal_map_button.pressed.connect(_on_debug_reveal_map_pressed)
	debug_gold_button.pressed.connect(_on_debug_gold_pressed)
	debug_complete_research_button.pressed.connect(_on_debug_complete_research_pressed)
	debug_win_button.pressed.connect(_on_debug_win_pressed)
	debug_lose_button.pressed.connect(_on_debug_lose_pressed)
	debug_force_dragon_button.pressed.connect(_on_debug_force_dragon_pressed)
	tech_tree_magic.category = "magic"
	tech_tree_magic.tech_selected.connect(_on_tech_selected)
	tech_tree_doutrina.tech_selected.connect(_on_tech_selected)
	_style_tech_panel_chrome()
	TurnManager.turn_changed.connect(_on_turn_changed)
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.fog_updated.connect(_refresh_inspection)
	_build_inspector_ui()
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
	# Roadmap "Fase Macro" 5B.2 -- os DOIS sinais podem mudar se o painel
	# deveria estar visivel (announced nao muda fase por si, so cria o
	# evento; phase_changed cobre toda transicao real, inclusive pra fora
	# de Preparation, escondendo o painel de novo).
	EventBus.world_event_announced.connect(_on_world_event_changed)
	EventBus.world_event_phase_changed.connect(_on_world_event_phase_changed)
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
	dragon_announcement_panel.visible = false
	dragon_resolution_panel.visible = false
	world_event_tracker.visible = false
	dragon_boss_bar.visible = false
	overlay_backdrop.visible = false
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
const TILE_INFO_PANEL_COMPACT_HEIGHT := 310.0
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
const TILE_INFO_SCROLL_EXPANDED_MIN_HEIGHT := 250.0

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
	# Task 23 -- o texto de inspecao rola dentro do painel: compacto usa toda a
	# altura livre; expandido (cidade) so' o que o texto da cidade precisa, o
	# resto e' da grade de producao.
	if _tile_info_scroll != null:
		_tile_info_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if expanded else Control.SIZE_EXPAND_FILL
		_tile_info_scroll.custom_minimum_size.y = TILE_INFO_SCROLL_EXPANDED_MIN_HEIGHT if expanded else 0.0

## Mostra o custo de producao de cada predio no proprio botao (pedido do
## usuario: "cards compactos com custo de producao/tempo") — os nomes
## crus (ex: "Celeiro") ja vem do .tscn, aqui so acrescenta o custo lido
## de BuildingDatabase, uma unica fonte de verdade (sem duplicar numero
## nenhum a mao no texto do node).
func _label_building_buttons() -> void:
	for id in _all_building_ids():
		_build_button_for(id).text = _building_button_label(id, "human")

var _additional_building_buttons: Dictionary = {}

func _all_building_ids() -> Array:
	return BuildingDatabase.all_buildings().map(func(b): return b.id)

func _build_additional_building_buttons() -> void:
	var row := build_granary_button.get_parent()
	for building in BuildingDatabase.all_buildings():
		if building.id in BUILDING_IDS:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 0)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.pressed.connect(_on_produce_pressed.bind(building.id))
		row.add_child(button)
		_additional_building_buttons[building.id] = button

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
	# manual em varios lugares diferentes. So GRAVA em cima do Button
	# quando o valor de fato muda (perfilamento: Control.text/.disabled
	# disparam redraw/reshape de fonte internos mesmo reatribuindo o MESMO
	# valor -- 60x/s de trabalho de layout gratuito rodando o jogo inteiro,
	# nao so durante troca de turno) -- disabled/text continuam sempre
	# corretos, so' a ESCRITA fica condicional.
	var should_disable = GameManager.is_turn_processing or GameManager.state == GameManager.GameState.GAME_OVER
	if end_turn_button.disabled != should_disable:
		end_turn_button.disabled = should_disable
	var wanted_text = END_TURN_BUTTON_PROCESSING_TEXT if GameManager.is_turn_processing else END_TURN_BUTTON_TEXT
	if end_turn_button.text != wanted_text:
		end_turn_button.text = wanted_text

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
		if not building.self_placed and building.upgrades_building == "":
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

## Tecnologia/Diplomacia/Grimorio/Debug/FimDeJogo sao todos paineis
## centralizados na mesma posicao — sem isso, abrir um por cima do outro
## (ou o jogo acabar com um deles aberto) deixava tudo empilhado e
## ilegivel. So um fica visivel por vez, e o backdrop escurecido some
## junto (ver _show_overlay).
func _close_overlay_panels() -> void:
	tech_panel.visible = false
	magic_panel.visible = false
	diplomacy_panel.visible = false
	victory_panel.visible = false
	grimoire_panel.visible = false
	game_over_panel.visible = false
	debug_panel.visible = false
	dragon_announcement_panel.visible = false
	dragon_resolution_panel.visible = false
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
	if tech_panel.visible or magic_panel.visible or diplomacy_panel.visible or victory_panel.visible or grimoire_panel.visible or debug_panel.visible or dragon_announcement_panel.visible or dragon_resolution_panel.visible:
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

func _on_magic_pressed() -> void:
	if magic_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(magic_panel)
	_refresh_tech_panel()

func _on_magic_close_pressed() -> void:
	_close_overlay_panels()


## Roadmap "dois botoes": Magia e Tecnologia viraram paineis full-screen
## INDEPENDENTES (ver onready vars acima) — o CHROME (fundo/cabecalho) dos
## dois usa a MESMA paleta local que TechTierBoard.gd ja usa (nao toca
## UITheme.gd, entao nenhum outro painel do jogo muda). O CONTEUDO de
## Magia continua 100% no visual antigo (TechTree.gd, marrom/dourado) —
## regra de sempre, so o chrome ao redor fica escuro/consistente com
## Tecnologia. Achado da analise visual: "muito preto vazio sem funcao" —
## um gradiente radial bem sutil (Gradient/GradientTexture2D — recursos
## NATIVOS do Godot, gerados em codigo, nenhum asset/imagem externa) da
## uma sensacao de profundidade sem shader/particula. Inserido como
## PRIMEIRO filho de `panel` (PanelContainer encaixa todo filho no mesmo
## retangulo de conteudo — o fundo desenha antes, o resto continua por
## cima).
func _add_panel_background_gradient(panel: PanelContainer) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, TechTierBoard.BG_LEVEL.lightened(0.035))
	gradient.set_color(1, TechTierBoard.BG_LEVEL.darkened(0.2))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.12)
	texture.fill_to = Vector2(0.5, 1.05)
	texture.width = 128
	texture.height = 128
	var bg_rect := TextureRect.new()
	bg_rect.name = "PanelBackground"
	bg_rect.texture = texture
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg_rect)
	panel.move_child(bg_rect, 0)

## Restiliza um dos dois paineis full-screen (fundo + botao de fechar) —
## chamado uma vez por painel em _ready(). Titulo "ARVORE DE TECNOLOGIA"/
## "ARVORE DE MAGIA" foi apagado por completo (pedido explicito da rodada
## anterior) — so o espacador (MagicHeaderSpacer/TechHeaderSpacer, Control
## puro, sem texto) mantem o botao de fechar alinhado a direita.
func _style_research_panel_chrome(panel: PanelContainer, close_button: Button) -> void:
	var panel_sb := UITheme.panel_style(TechTierBoard.BG_LEVEL, TechTierBoard.BORDER_STEEL, 1, 0, false)
	panel_sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_sb)
	_add_panel_background_gradient(panel)
	_style_doutrina_chip_button(close_button, TechTierBoard.TEXT_PRIMARY)

func _style_tech_panel_chrome() -> void:
	_style_research_panel_chrome(tech_panel, tech_close_button)
	_style_research_panel_chrome(magic_panel, magic_close_button)
	_style_research_panel_chrome(grimoire_panel, grimoire_close_button)

## Estilo "chip" (Roadmap "UI/UX exclusiva") — mesma paleta local de
## TechTierBoard.gd, nao o Theme global. `accent_color` e a cor da propria
## familia (ou dourado neutro pro "Todos") usada no estado marcado/hover —
## pedido explicito: "usar as cores... das familias", nao dourado generico
## pra tudo. Achado da analise visual: em repouso todo chip ficava com a
## MESMA borda de aco neutro, a cor da familia so aparecia ao clicar/
## passar o mouse — agora a borda de repouso ja carrega uma versao
## discreta (lerp 65% em direcao ao aco) da cor da familia, dando
## identidade constante sem competir com o estado ativo (saturacao cheia).
func _style_doutrina_chip_button(b: Button, accent_color: Color) -> void:
	var rest_border := accent_color.lerp(TechTierBoard.BORDER_STEEL, 0.65)
	# Chapado (pedido explicito: sem sombra) — corner_radius reduzido (era
	# 12) pra um pill mais discreto, nao mais um botao com relevo.
	b.add_theme_stylebox_override("normal", UITheme.panel_style(TechTierBoard.BG_CARD, rest_border, 1, 6, false))
	b.add_theme_stylebox_override("hover", UITheme.panel_style(TechTierBoard.BG_CARD.lightened(0.08), accent_color, 1, 6, false))
	b.add_theme_stylebox_override("pressed", UITheme.panel_style(TechTierBoard.BG_LEVEL, accent_color, 1, 6, false))
	b.add_theme_color_override("font_color", TechTierBoard.TEXT_MUTED)
	b.add_theme_color_override("font_pressed_color", accent_color)
	b.add_theme_color_override("font_hover_color", TechTierBoard.TEXT_PRIMARY)

## Atualiza as DUAS arvores (Magia/Tecnologia, ver tech_tree_magic/
## tech_tree_doutrina) mesmo os dois paineis sendo independentes agora
## (Roadmap "dois botoes") — chamado de _on_tech_pressed() E
## _on_magic_pressed()/_on_tech_selected() de proposito: o slot de
## pesquisa ativa continua UNICO/compartilhado entre as duas arvores (ver
## PlayerData), entao pesquisar algo numa reflete na outra mesmo fechada
## (ex: escolher uma tech em Tecnologia marca a pesquisa anterior de Magia
## como concluida) — reconstruir as duas sempre evita estado desatualizado
## quando o jogador trocar de painel. Cada tecnologia vira um card
## colorido por estado (TechTree.gd cuida do layout/desenho da Magia por
## grafo; TechTierBoard.gd cuida do layout por NIVEL da Tecnologia).
func _refresh_tech_panel() -> void:
	var player = GameManager.human_player
	if player == null:
		return

	var race: String = player.civ.race
	tech_tree_magic.rebuild(player.researched_magic, player.current_research, player.research_progress, race)
	tech_tree_doutrina.rebuild(player.researched_techs, player.current_research, player.research_progress, race)

func _on_tech_selected(id: String) -> void:
	GameManager.human_player.select_research(id)
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
		label.text += "\n" + Diplomacy.relation_description(human, rival)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		if at_war:
			btn.text = "Propor Paz"
			btn.pressed.connect(_on_propose_peace_pressed.bind(rival))
		else:
			btn.text = "Declarar Guerra"
			btn.disabled = eliminated or not Diplomacy.can_declare_war(human, rival)
			btn.tooltip_text = "Acordos de paz garantem dez turnos de trégua. Declarar guerra encerra o comércio."
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
	if not Diplomacy.can_declare_war(GameManager.human_player, rival):
		return
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
		if GameManager.victory_rules_version >= 2:
			_add_victory_progress_row(target, "Supremacia", VictoryCampaign.supremacy_progress(player, players))
			_add_victory_progress_row(target, "Transcendência", VictoryCampaign.transcendence_progress(player, hex_grid))
			var detail := Label.new()
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if player.arcane_ritual_active:
				detail.text = "Transcendência em (%d, %d): faltam %d turnos!" % [player.arcane_ritual_city_coord.x, player.arcane_ritual_city_coord.y, maxi(0, VictoryCampaign.CHANNEL_TURNS - player.arcane_ritual_streak)]
			elif player == human:
				detail.text = "Supremacia: Exército Supremo + 2 cidades desenvolvidas conquistadas; representar cada rival por conquista ou eliminação. Cidade desenvolvida: população 3 e 2 edifícios no momento da conquista.\nTranscendência:\n" + "\n".join(VictoryCampaign.preparations(player, hex_grid))
			target.add_child(detail)
			continue

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
		VictoryCampaign.SUPREMACY:
			victory_name = "Supremacia"
		VictoryCampaign.TRANSCENDENCE:
			victory_name = "Transcendência"
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
		VictoryCampaign.SUPREMACY:
			return "Pesquisou Exército Supremo e demonstrou superioridade sobre todos os rivais por conquistas desenvolvidas ou eliminação."
		VictoryCampaign.TRANSCENDENCE:
			return "Dominou duas escolas, concluiu dois Grandes Rituais e sustentou a Transcendência por sete turnos com cinco conjuradores e três Nódulos."
		"eliminated":
			return "Seu reino perdeu todas as cidades e unidades."
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

	var spell_names = MagicDatabase.unlocked_spells_for(human.researched_magic)
	if spell_names.is_empty():
		var empty_label := Label.new()
		empty_label.theme_type_variation = &"MutedLabel"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "Nenhum feitiço aprendido. Abra Magia, desenvolva uma escola e treine seu conjurador."
		grimoire_rows.add_child(empty_label)
		return

	for category in ["spell", "great_spell", "ritual"]:
		var heading := Label.new()
		heading.text = {"spell": "FEITIÇOS", "great_spell": "GRANDES FEITIÇOS", "ritual": "GRANDES RITUAIS"}[category]
		grimoire_rows.add_child(heading)
		for spell_name in spell_names:
			var data := SpellDatabase.get_spell(spell_name)
			if data and data.category == category:
				grimoire_rows.add_child(_build_spell_row(spell_name, human))
	for ritual in human.rituals:
		var progress := Label.new()
		progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state_text: String = {"channeling": "Canalizando", "completed": "Concluído", "interrupted": "Interrompido"}.get(ritual.status, ritual.status)
		progress.text = "%s — %s · %d/%d turnos%s" % [ritual.spell, state_text, int(ritual.progress), int(ritual.turns), " · " + str(ritual.reason) if ritual.has("reason") else ""]
		grimoire_rows.add_child(progress)
		if ritual.status == "channeling":
			var cancel := Button.new()
			cancel.text = "Interromper e liberar conjuradores (sem reembolso)"
			cancel.pressed.connect(func():
				MagicRuntime.interrupt_ritual(human, ritual, "cancelado pelo jogador")
				_refresh_grimoire_panel())
			grimoire_rows.add_child(cancel)
	if GameManager.victory_rules_version >= 2:
		var heading := Label.new()
		heading.text = "TRANSCENDÊNCIA"
		grimoire_rows.add_child(heading)
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var missing := VictoryCampaign.preparations(human, GameManager.hex_grid)
		description.text = "400 mana inicial · 40 por turno · 7 turnos\n" + "\n".join(missing)
		if human.arcane_ritual_active:
			description.text = "Canalizando Transcendência: %d/%d turnos · 40 mana/turno" % [human.arcane_ritual_streak, VictoryCampaign.CHANNEL_TURNS]
		grimoire_rows.add_child(description)
		var activate := Button.new()
		activate.text = "Iniciar Transcendência"
		activate.disabled = human.arcane_ritual_active or not missing.is_empty() or GameManager.is_turn_processing
		activate.pressed.connect(func():
			VictoryCampaign.start(human, GameManager.hex_grid)
			_refresh_grimoire_panel())
		grimoire_rows.add_child(activate)

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
	if spell and spell.effect != "":
		var reason := MagicRuntime.reason(human, spell, GameManager.hex_grid)
		cast_button.disabled = reason != "" or GameManager.is_turn_processing
		cast_button.text = "Preparar ritual" if spell.category == "ritual" else "Conjurar"
		cast_button.tooltip_text = reason if reason != "" else "Escolha o alvo no mapa."
		cast_button.pressed.connect(_on_cast_spell_pressed.bind(spell_name))
		if reason != "":
			var blocked_label := Label.new()
			blocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			blocked_label.text = reason
			box.add_child(blocked_label)
	elif spell == null:
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

func _on_debug_force_dragon_pressed() -> void:
	WorldEventManager.debug_force_dragon_event(GameManager.hex_grid)

## Emite o pedido de reinicio (Main.gd regenera mapa/jogo de forma sincrona
## nesse mesmo emit) e so entao atualiza a propria HUD com o estado novo.
func _on_restart_pressed() -> void:
	EventBus.restart_requested.emit()
	_close_overlay_panels()
	end_turn_button.disabled = false
	tech_button.disabled = false
	magic_button.disabled = false
	diplomacy_button.disabled = false
	victory_button.disabled = false
	grimoire_button.disabled = false
	unit_panel.visible = false
	production_tabs.visible = false
	worked_tiles_label.visible = false
	worked_tiles_scroll.visible = false
	production_progress_label.visible = false
	production_progress_bar.visible = false
	_viewed_city = null
	_clear_inspection()
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
	# Roadmap "Fase Macro" 5B.2 -- NAO condicionado a world_event_panel.
	# visible (diferente dos paineis acima): precisa rodar todo turno pra
	# o texto de contagem regressiva ("faltam N turnos") ficar correto
	# mesmo enquanto a fase nao muda (Preparation dura varios turnos sem
	# emitir phase_changed nenhum nesse meio-tempo). Mesma razao pro Tracker/
	# Boss Bar abaixo (5B.3-C) -- o HP do Dragao muda todo turno em Active
	# sem necessariamente disparar phase_changed nenhum.
	_refresh_world_event_panel()
	_refresh_world_event_tracker()
	_refresh_dragon_boss_bar()
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
		var upkeep := 0.0
		for unit in player.units:
			upkeep += unit.unit_data.mana_upkeep
		for ritual in player.rituals:
			if ritual.status == "channeling":
				upkeep += 20
		if player.arcane_ritual_active and GameManager.victory_rules_version >= 2:
			upkeep += VictoryCampaign.TURN_MANA
		mana_label.tooltip_text = "Produção: %.0f/turno\nManutenção de unidades e rituais: %.0f/turno\nSaldo previsto: %+.0f/turno" % [player.mana_income_per_turn, upkeep, player.mana_income_per_turn - upkeep]
		_refresh_tech_button_progress(player)

## Progresso da pesquisa atual direto no botao correspondente da barra
## superior (pedido do usuario: reorganizar a HUD "parecido com os de
## civilization 6" — la o icone de pesquisa na barra ja mostra o progresso
## sem precisar abrir a arvore inteira). So texto (sem anel/barra grafica
## nova) de proposito: menor risco, reusa o mesmo botao/tema que ja existe.
## Roadmap "dois botoes": Magia e Tecnologia tem botao PROPRIO agora (o
## slot de pesquisa continua unico/compartilhado, ver PlayerData) — o
## progresso aparece so no botao do sistema DONO da pesquisa atual
## (TechDatabase -> tech_button, MagicDatabase -> magic_button), o outro
## volta pro rotulo padrao.
func _refresh_tech_button_progress(player: PlayerData) -> void:
	tech_button.text = "Tecnologia"
	magic_button.text = "Magia"
	if player.current_research == "":
		return
	var tech: TechData = TechDatabase.get_tech(player.current_research)
	var target_button := tech_button
	if tech == null:
		tech = MagicDatabase.get_tech(player.current_research)
		target_button = magic_button
	if tech == null:
		return
	var pct = int(round(min(player.research_progress / tech.cost, 1.0) * 100.0)) if tech.cost > 0.0 else 100
	target_button.text = "%s (%d%%)" % [RaceTheme.tech_name(tech.id, player.civ.race), pct]

## Mensagens curtas (combate, fundacao/captura de cidade) que aparecem no
## topo da tela e somem sozinhas — sem isso, um ataque do rival fora de
## tela passaria despercebido ate o jogador notar sozinho.
func _on_notify(text: String, _sfx_kind: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Roadmap "Fase Macro" 5B.2 -- achado de playtest visual: sem autowrap,
	# um texto mais longo que a NotificationStack (largura fixa, ver
	# HUD.tscn) forcava o container inteiro a crescer alem da propria
	# ancora, cortando o texto pra fora dos dois lados da tela (so
	# acontecia com notificacoes de uma frase so, como "Jogo salvo.";
	# nunca apareceu ate os toasts narrativos do Dragao, mais longos).
	# SIZE_EXPAND_FILL garante que o Label realmente ocupe a largura fixa
	# do container em vez de encolher pro texto de uma so palavra.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	notification_stack.add_child(label)

	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

	_refresh_stats()

## Roadmap "Fase Macro" 5B.3-C (Dragon Event UX) -- pedido explicito do
## usuario apos o playtest visual de 5B.3-B: o Dragao ja funciona como
## entidade de jogo, mas o EVENTO ainda nao se comunicava como evento de
## jogo. So' chamado por _refresh_* abaixo, nunca decide fase nenhuma --
## WorldEvent/DragonEvent continuam a UNICA autoridade sobre o proprio
## estado, mesmo principio ja usado por VictoryConditions -> HUD (nunca o
## contrario). O anuncio bloqueante (ver _show_overlay) e' disparado AQUI,
## na transicao de fase em si -- nunca por um refresh de turno, senao
## reapareceria a cada turno enquanto o evento continuasse Announced.
func _on_world_event_changed(_event: WorldEvent) -> void:
	_refresh_world_event_panel()
	_refresh_world_event_tracker()
	_refresh_dragon_boss_bar()

func _on_world_event_phase_changed(event: WorldEvent, _old_phase: String, new_phase: String) -> void:
	_refresh_world_event_panel()
	_refresh_world_event_tracker()
	_refresh_dragon_boss_bar()
	# Pedido explicito do usuario: "não misturar esse anúncio com o canal
	# visual usado para 'Goblin eliminado', 'Troll derrotado' etc" -- um
	# modal proprio, bloqueante, exigindo confirmacao, em vez do toast
	# generico que o proprio DragonEvent ainda emite (EventBus.notify,
	# mantido pra quem preferir so acompanhar o log de notificacoes).
	if new_phase == WorldEvent.PHASE_ANNOUNCED and event is DragonEvent:
		dragon_announcement_text_label.text = format_dragon_announcement_text(event)
		_show_overlay(dragon_announcement_panel)
	# 5B.3-G -- mesmo padrao acima, agora pro DESFECHO (defeated/devastated/
	# no_target). DragonEvent nao emite mais toast nenhum pro proprio
	# desfecho (ver _resolve_with_outcome) -- este modal e' agora a UNICA
	# comunicacao do resultado.
	if new_phase == WorldEvent.PHASE_RESOLUTION and event is DragonEvent:
		var dragon_event := event as DragonEvent
		var outcome := String(event.result.get("outcome", ""))
		dragon_resolution_title_label.text = format_dragon_resolution_title(outcome)
		dragon_resolution_text_label.text = format_dragon_resolution_text(outcome)
		for child in dragon_resolution_ranking_box.get_children():
			# free() imediato, nao queue_free() -- precisa estar fora da
			# arvore JA, antes de repopular linhas novas logo abaixo (nao
			# so' no fim do frame), senao um evento novo veria as linhas do
			# evento ANTERIOR ainda presentes por um frame inteiro.
			child.free()
		var ranking_lines := format_dragon_damage_ranking(dragon_event.damage_by_civ, GameManager.players)
		for index in dragon_event.result.get("rewards", {}):
			var reward: Dictionary = dragon_event.result.rewards[index]
			if int(index) < GameManager.players.size():
				ranking_lines.append("%s: +%d ouro · +%d mana" % [GameManager.players[int(index)].civ.civ_name, int(reward.gold), int(reward.mana)])
		dragon_resolution_ranking_header_label.visible = not ranking_lines.is_empty()
		for line in ranking_lines:
			var row := Label.new()
			row.text = line
			dragon_resolution_ranking_box.add_child(row)
		_show_overlay(dragon_resolution_panel)

func _on_dragon_announcement_continue_pressed() -> void:
	_close_overlay_panels()

func _on_dragon_resolution_continue_pressed() -> void:
	_close_overlay_panels()

func _refresh_world_event_panel() -> void:
	var event := _find_preparation_event_awaiting_human_decision()
	if event == null:
		world_event_panel.visible = false
		return
	world_event_panel.visible = true
	world_event_title_label.text = format_world_event_title(event)
	world_event_text_label.text = format_world_event_prompt(event, GameManager.players, TurnManager.turn_number)

## Civilizacao-alvo travada (Blocker #3/5B.2) -- extraido de format_world_
## event_prompt pra ser reusado tambem pelo Tracker (mesma info, fase
## diferente).
static func _dragon_target_civ_name(dragon: DragonEvent, players: Array[PlayerData]) -> String:
	if dragon.target_civ_index >= 0 and dragon.target_civ_index < players.size():
		return players[dragon.target_civ_index].civ.civ_name
	return "uma civilização desconhecida"

static func format_world_event_title(event: WorldEvent) -> String:
	if event is DragonEvent:
		return "A Caçada ao Dragão"
	return "Evento Mundial"

## Puro/testavel -- so formata texto, nunca calcula fase/alvo/prazo (esses
## continuam vivendo so em WorldEvent/DragonEvent). Texto reescrito em
## 5B.3-C (pedido do usuario): explica O QUE participar significa, mas de
## proposito NAO promete uma recompensa especifica ainda ("poderá receber
## recompensas pela contribuição") -- a recompensa concreta e' escopo de
## 5B.4, ainda nao decidida.
static func format_world_event_prompt(event: WorldEvent, players: Array[PlayerData], current_turn: int) -> String:
	if event is DragonEvent:
		var dragon := event as DragonEvent
		var target_name := _dragon_target_civ_name(dragon, players)
		var turns_left: int = max(event.turn_deadline - current_turn, 0)
		return "A Guilda dos Aventureiros confirmou a ameaça. Um Dragão poderoso está avançando pelo continente e eventualmente atacará %s em seu caminho. A Guilda convocou todos os reinos para ajudar a derrotá-lo. Faltam %d turno(s) para decidir.\n\nParticipar: seu reino será reconhecido como um dos que enfrentaram a criatura e poderá receber recompensas pela contribuição.\nNão participar: você não receberá essas recompensas, mas o Dragão continuará sua marcha normalmente." % [target_name, turns_left]
	return "Um evento mundial está em preparação. Deseja participar?"

## Texto do modal BLOQUEANTE de Announced (etapa "alerta", separada da
## etapa "chamado" acima) -- pedido explicito do usuario: "o objetivo é
## simplesmente garantir: 'Pare. Isso é importante.'". Generico o
## suficiente pra nao repetir _dragon_target_civ_name (o alvo so trava
## na transicao SEGUINTE, Announced->Preparation -- Blocker #3).
static func format_dragon_announcement_text(event: WorldEvent) -> String:
	if event is DragonEvent:
		return "Batedores relatam a presença de um Dragão ancestral nas proximidades do continente.\n\nA criatura é extremamente poderosa e está se dirigindo para terras habitadas. Todos os reinos foram alertados."
	return "Uma ameaça está surgindo no mundo."

## Modal de DESFECHO -- pedido explicito do usuario, roadmap "Dragon Event
## v1 fechado": textos finais (v2, substituindo os provisorios de 5B.3-G).
## "O importante é que Resolution seja um acontecimento, não uma mensagem
## técnica" -- confirmado pelo usuario que "devastated" usa UM texto so'
## (não dois outcomes de verdade, so' texto). Puro/testavel, mesmo padrao
## de format_dragon_announcement_text acima. "_:"/outcome desconhecido cai
## num texto generico -- nunca deveria acontecer de verdade (so' os 3
## outcomes existem, ver DragonEvent._resolve_with_outcome), mas uma match
## sem default quebraria em vez de degradar.
static func format_dragon_resolution_title(outcome: String) -> String:
	match outcome:
		"defeated":
			return "🐉 O DRAGÃO FOI DERROTADO"
		"devastated":
			return "🐉 O DRAGÃO RECUOU"
		"no_target":
			return "🐉 O DRAGÃO DESAPARECEU"
		_:
			return "🐉 O DRAGÃO SE AFASTOU"

static func format_dragon_resolution_text(outcome: String) -> String:
	match outcome:
		"defeated":
			return "Após uma batalha brutal, os defensores finalmente conseguiram derrubar a criatura.\n\nO Dragão que aterrorizou os reinos não ameaça mais o continente."
		"devastated":
			return "O Dragão atravessou as terras dos reinos, espalhando destruição por onde passou.\n\nApós saciar sua fúria, a criatura abandonou o continente e desapareceu no horizonte.\n\nO Dragão não foi derrotado."
		"no_target":
			return "Sem encontrar novas terras habitadas para atacar, o Dragão desapareceu além dos limites conhecidos."
		_:
			return "O Dragão se afastou das terras habitadas."

## Roadmap "Dragon Event v1 fechado" -- pedido explicito do usuario:
## "ranking de dano... transforma o Dragão numa atividade competitiva
## entre civilizações... eventualmente todos podem participar do mesmo
## evento, mas nem todos recebem a mesma glória". Puro/testavel -- so'
## formata `DragonEvent.damage_by_civ` (a fonte de verdade, populada por
## DragonEvent.record_damage_if_target_is_the_active_dragon), nunca
## calcula dano aqui. Civ com dano 0 (ou nunca registrada) NUNCA aparece
## ("se dá 0, não conta", pedido explicito) -- ordenado por dano
## decrescente, medalha nos 3 primeiros, "4º"/"5º"/etc depois. A linha
## "Sua contribuição: X de Y — Z%" fica pra depois (pedido do usuario:
## "eventualmente"), fora de escopo agora.
static func format_dragon_damage_ranking(damage_by_civ: Dictionary, players: Array[PlayerData]) -> Array[String]:
	var entries: Array = []
	for civ_index in damage_by_civ:
		var damage: float = damage_by_civ[civ_index]
		if damage <= 0.0:
			continue
		var index: int = civ_index
		if index < 0 or index >= players.size():
			continue
		entries.append({"name": players[index].civ.civ_name, "damage": damage})
	entries.sort_custom(func(a, b): return a.damage > b.damage)
	var medals := ["🥇", "🥈", "🥉"]
	var lines: Array[String] = []
	for i in range(entries.size()):
		var rank_label: String = medals[i] if i < medals.size() else "%dº" % (i + 1)
		lines.append("%s %s — %d de dano" % [rank_label, entries[i].name, int(round(entries[i].damage))])
	return lines

func _find_preparation_event_awaiting_human_decision() -> WorldEvent:
	var human_index: int = GameManager.players.find(GameManager.human_player)
	for event in WorldEventManager.active_events:
		if event.phase == WorldEvent.PHASE_PREPARATION and not event.participants.has(human_index):
			return event
	return null

## Responde "o que esta acontecendo e o que eu devo fazer" (pedido do
## usuario: distincao deliberada da Boss Bar, que responde "como esta o
## Dragao"). Visivel em Preparation/Active/Resolution, escondido em
## Announced (o modal bloqueante ja cobre esse momento) e Completed
## (pedido explicito: "Tracker desaparece").
func _find_active_dragon_event() -> WorldEvent:
	for event in WorldEventManager.active_events:
		if event is DragonEvent:
			return event
	return null

## Puro/testavel -- {} quando a fase nao deveria mostrar tracker nenhum.
static func format_world_event_tracker(event: WorldEvent, players: Array[PlayerData]) -> Dictionary:
	if not (event is DragonEvent):
		return {}
	var dragon := event as DragonEvent
	match event.phase:
		WorldEvent.PHASE_PREPARATION:
			return {
				"status": "Preparação",
				"objective": "Decida se seu reino participará.",
				"target": _dragon_target_civ_name(dragon, players),
			}
		WorldEvent.PHASE_ACTIVE:
			var city: City = dragon._choose_target_city(players) if (dragon.dragon_unit != null and is_instance_valid(dragon.dragon_unit)) else null
			return {
				"status": "Em atividade",
				"objective": "Derrote o Dragão.",
				"target": city.city_name if city != null else "—",
			}
		WorldEvent.PHASE_RESOLUTION:
			return {
				"status": _dragon_outcome_label(String(event.result.get("outcome", ""))),
				"objective": "",
				"target": "",
			}
		_:
			return {}

static func _dragon_outcome_label(outcome: String) -> String:
	match outcome:
		"defeated":
			return "Dragão derrotado!"
		"devastated":
			return "Devastação total."
		"no_target":
			return "O Dragão perdeu o rastro."
		_:
			return "O Dragão se afastou."

func _refresh_world_event_tracker() -> void:
	var event := _find_active_dragon_event()
	var info := format_world_event_tracker(event, GameManager.players) if event != null else {}
	if info.is_empty():
		world_event_tracker.visible = false
		return
	world_event_tracker.visible = true
	world_event_tracker_status_label.text = "Status: %s" % info.status
	world_event_tracker_objective_label.text = info.objective
	world_event_tracker_objective_label.visible = info.objective != ""
	world_event_tracker_target_label.text = "Alvo: %s" % info.target
	world_event_tracker_target_label.visible = info.target != ""

## Puro/testavel -- {} enquanto o Dragao nao estiver fisicamente presente
## (fora de Active, ou no exato tick da transicao pra Active antes da Unit
## nascer). Reusa DragonEvent._choose_target_city (mesma logica ja usada
## pelo proprio Dragao pra escolher seu alvo) em vez de ler current_target_
## city_coord direto -- esse campo fica NO_COORD por um tick logo apos
## cada raid ate a proxima escolha, o que faria o alvo "piscar" pra
## traço (—) sem necessidade nenhuma; a formula de escolha em si e' pura
## (sem efeito colateral), segura de chamar so' pra exibir.
static func format_dragon_boss_bar(event: WorldEvent, players: Array[PlayerData]) -> Dictionary:
	if not (event is DragonEvent):
		return {}
	var dragon := event as DragonEvent
	if event.phase != WorldEvent.PHASE_ACTIVE or dragon.dragon_unit == null or not is_instance_valid(dragon.dragon_unit):
		return {}
	var city: City = dragon._choose_target_city(players)
	return {
		"name": "Dragão Ancestral",
		"hp": dragon.dragon_unit.hp,
		"max_hp": dragon.dragon_unit.unit_data.max_hp,
		"target": city.city_name if city != null else "—",
	}

func _refresh_dragon_boss_bar() -> void:
	var event := _find_active_dragon_event()
	var info := format_dragon_boss_bar(event, GameManager.players) if event != null else {}
	if info.is_empty():
		dragon_boss_bar.visible = false
		return
	dragon_boss_bar.visible = true
	dragon_boss_bar_name_label.text = info.name
	dragon_boss_bar_health_bar.max_value = info.max_hp
	dragon_boss_bar_health_bar.value = info.hp
	dragon_boss_bar_health_label.text = "%d / %d HP" % [int(info.hp), int(info.max_hp)]
	dragon_boss_bar_target_label.text = "Alvo: %s" % info.target

func _on_world_event_participate_pressed() -> void:
	GameManager.respond_to_world_event(true)
	_refresh_world_event_panel()

func _on_world_event_decline_pressed() -> void:
	GameManager.respond_to_world_event(false)
	_refresh_world_event_panel()

## Task 23 -- monta (uma vez) o que o painel de inspecao precisa alem do .tscn:
## uma barra de abas (uma por entidade do tile, so' aparece com 2+) e um
## ScrollContainer em volta do texto, pra descricao longa nunca ser cortada.
func _build_inspector_ui() -> void:
	var box := tile_info_label.get_parent() as VBoxContainer
	_tile_info_scroll = ScrollContainer.new()
	_tile_info_scroll.name = "TileInfoScroll"
	_tile_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tile_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tile_info_scroll)
	box.move_child(_tile_info_scroll, tile_info_label.get_index())
	tile_info_label.reparent(_tile_info_scroll)
	tile_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_tabs = HFlowContainer.new()
	_inspect_tabs.name = "InspectorTabs"
	_inspect_tabs.visible = false
	box.add_child(_inspect_tabs)
	box.move_child(_inspect_tabs, _tile_info_scroll.get_index())

func _clear_inspection() -> void:
	_inspect_coord = NO_INSPECT_COORD
	_inspect_key = ""
	_inspection = {}
	if _inspect_tabs != null:
		_inspect_tabs.visible = false

## Reaplica o texto e as abas a partir de `_inspection`. Chave desconhecida
## (ex: a entidade sumiu) cai na entidade principal.
func _render_inspection() -> void:
	if _inspection.is_empty():
		return
	var entry := TileInspector.entry_for_key(_inspection, _inspect_key)
	_inspect_key = entry.get("key", "")
	tile_info_label.text = TileInspector.render(_inspection, _inspect_key)
	_rebuild_inspect_tabs()

func _rebuild_inspect_tabs() -> void:
	if _inspect_tabs == null:
		return
	for child in _inspect_tabs.get_children():
		_inspect_tabs.remove_child(child)
		child.queue_free()
	var entries: Array = _inspection.get("entries", [])
	_inspect_tabs.visible = entries.size() > 1
	if entries.size() <= 1:
		return
	for entry in entries:
		var button := Button.new()
		button.text = entry.tag
		button.toggle_mode = true
		button.button_pressed = entry.key == _inspect_key
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = entry.title
		button.pressed.connect(_on_inspect_tab_pressed.bind(entry.key))
		_inspect_tabs.add_child(button)

func _on_inspect_tab_pressed(key: String) -> void:
	_inspect_key = key
	_render_inspection()

## Reconsulta o mapa e reescreve o painel de inspecao (fim de turno, nevoa
## mudou, unidade morreu...). Nunca reusa objetos antigos; se a cidade
## aberta foi capturada/destruida, refaz o painel inteiro (producao etc.).
func _refresh_inspection() -> void:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null or _inspect_coord == NO_INSPECT_COORD or not hex_grid.tiles.has(_inspect_coord) or not tile_info_panel.visible:
		return
	if _viewed_city != null and (not is_instance_valid(_viewed_city) or _viewed_city.owner_player != GameManager.human_player or hex_grid.get_city_at(_inspect_coord) != _viewed_city):
		_on_tile_selected(_inspect_coord, hex_grid.get_tile(_inspect_coord))
		return
	_inspection = TileInspector.inspect(hex_grid, _inspect_coord, GameManager.human_player)
	_render_inspection()

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
		_clear_inspection()
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
		_clear_inspection()
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

	# Task 23 -- o texto (entidade principal + abas + secao de terreno) vem do
	# TileInspector, sempre respeitando a nevoa. Trocar de tile volta pra
	# entidade principal; reclicar o mesmo tile preserva a aba escolhida.
	if coord != _inspect_coord:
		_inspect_key = ""
	_inspect_coord = coord
	_inspection = TileInspector.inspect(hex_grid, coord, GameManager.human_player) if hex_grid else {}

	if hex_grid:
		var city = hex_grid.get_city_at(coord)
		# Producao/progresso so' da cidade PROPRIA: o painel mostrava "Produzindo:
		# ..." tambem de cidade rival (segredo que o jogador nao deveria ter).
		if city and city.owner_player == GameManager.human_player:
			_refresh_production_progress(city, hex_grid)
			_viewed_city = city
			action_bar.visible = false

	_render_inspection()
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
		for id in _all_building_ids():
			var btn := _build_button_for(id)
			btn.text = _building_button_label(id, race)
			btn.disabled = not _viewed_city.can_build(id)
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
		_production_buttons[kind].tooltip_text = _production_lock_reason(kind) + "\n" + UnitAbilities.description(kind)

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
	if _additional_building_buttons.has(id):
		return _additional_building_buttons[id]
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
	for id in _all_building_ids():
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
	# Ordem importa desde a arvore de 10 niveis (Roadmap): a tech de
	# unlocks_building (gate da CONSTRUCAO) vem ANTES da tech de trains_unit
	# (gate do TREINO) — ver comentario de City._tech_unlocked_for_building.
	var tech: TechData = TechDatabase.tech_that_unlocks_building(id) if building else null
	var researched: Dictionary = GameManager.human_player.researched_techs
	if tech == null and building:
		tech = TechDatabase.tech_that_unlocks(building.trains_unit)
	if tech == null and building:
		tech = MagicDatabase.tech_that_unlocks(building.trains_unit)
		researched = GameManager.human_player.researched_magic
	if tech == null and building:
		tech = MagicDatabase.tech_that_unlocks_building(id)
		researched = GameManager.human_player.researched_magic
	if tech and not researched.has(tech.id):
		return "Requer pesquisar: %s" % RaceTheme.tech_name(tech.id, race)
	if building.requires_building != "" and not _viewed_city.buildings.has(building.requires_building):
		return "Requer construir: %s" % RaceTheme.building_name(building.requires_building, race)
	if building.upgrades_building == "" and _viewed_city.used_building_slots() >= _viewed_city.max_building_slots():
		return "Sem espaco: %d/%d predios (cidade precisa crescer)" % [_viewed_city.used_building_slots(), _viewed_city.max_building_slots()]
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
	var spell_actions := unit_panel.get_node_or_null("UnitBox/SpellActions")
	if spell_actions:
		spell_actions.get_parent().remove_child(spell_actions)
		spell_actions.queue_free()
	if unit.unit_data.magic_school != "" and unit.owner_player == GameManager.human_player:
		spell_actions = HFlowContainer.new()
		spell_actions.name = "SpellActions"
		unit_panel.get_node("UnitBox").add_child(spell_actions)
		for name in MagicDatabase.unlocked_spells_for(unit.owner_player.researched_magic):
			var spell := SpellDatabase.get_spell(name)
			if spell == null or spell.school != unit.unit_data.magic_school or spell.category == "ritual":
				continue
			var button := Button.new()
			button.text = name
			button.tooltip_text = spell.description
			button.disabled = not MagicRuntime.eligible_caster(unit, spell) or unit.owner_player.mana < spell.mana_cost or GameManager.is_turn_processing
			button.pressed.connect(func(): SelectionManager.start_spell_targeting(name, unit))
			spell_actions.add_child(button)
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
	if unit.ritual_id != "":
		unit_info_label.text += "\nCanalizando ritual: movimento e feitiços indisponíveis."
	var autonomous := unit.unit_data.visual_kind in ["elder_lich", "archdemon"]
	var orders_locked := unit.ritual_id != "" or autonomous or GameManager.is_turn_processing
	if autonomous:
		unit_info_label.text += "\nCriatura autônoma: avança ao objetivo do ritual e comanda suas invocações."
	if unit.unit_data.mana_upkeep > 0:
		unit_info_label.text += "\nManutenção: %.0f mana/turno" % unit.unit_data.mana_upkeep
	# Task 23 -- mesmos fatos do painel de inspecao: classe/escola, efeitos
	# ativos, acao/recarga do conjurador e o que mais existe neste tile
	# (terreno continua consultavel mesmo com a unidade em cima).
	unit_info_label.text += "\nClasse: %s" % TileInspector.unit_class_label(unit)
	for status_line in TileInspector.status_effect_lines(unit):
		unit_info_label.text += "\n" + status_line
	for caster_line in TileInspector.caster_lines(unit):
		unit_info_label.text += "\n" + caster_line
	if GameManager.hex_grid != null:
		var here := TileInspector.inspect(GameManager.hex_grid, unit.coord, GameManager.human_player)
		unit_info_label.text += "\nNeste tile: %s" % TileInspector.summary_line(here)
	found_city_button.visible = unit.unit_data.can_found_city and not unit.embarked
	# Task 22 -- mesma regra do SelectionManager (CitySite): botao desabilitado
	# com o motivo no tooltip em vez de um clique que nao faz nada.
	if found_city_button.visible and GameManager.hex_grid != null:
		var found_reason := CitySite.rejection_reason(GameManager.hex_grid, unit.coord, unit.owner_player)
		found_city_button.disabled = found_reason != "" or orders_locked
		found_city_button.tooltip_text = CitySite.reason_text(found_reason)
	# Fortificar/Explorar sao alternancias (toggle_mode, ver HUD.tscn) —
	# button_pressed precisa refletir o estado REAL da unidade toda vez
	# que a selecao (ou o proprio estado) muda, senao o botao mostraria
	# "nao pressionado" pra uma unidade ja fortificada so por ter sido
	# reselecionada. Desabilitados enquanto embarcada (Roadmap 2.0 Parte 1,
	# C2 — unidade em transito nao fortifica/explora; SelectionManager ja
	# recusa a acao, isto e so a segunda camada/feedback visual).
	fortify_button.button_pressed = unit.fortified
	move_button.disabled = orders_locked
	fortify_button.disabled = unit.embarked or orders_locked
	explore_button.button_pressed = unit.exploring
	explore_button.disabled = unit.embarked or orders_locked
	# Embarcar (Roadmap 2.0 Parte 1, acesso naval) — so aparece pra unidade
	# terrestre com Navegação ja pesquisada; desabilitado (mas visivel, pra
	# o jogador entender que existe) fora de um tile costeiro ou ja
	# embarcada (toggle e mao unica, ver SelectionManager.
	# toggle_embark_selected — desembarque e sempre automatico).
	var owner_player := unit.owner_player
	embark_button.visible = not unit.unit_data.flies and owner_player != null and TechDatabase.is_navigation_researched(owner_player.researched_techs)
	if embark_button.visible:
		embark_button.button_pressed = unit.embarked
		embark_button.disabled = orders_locked or unit.embarked or (GameManager.hex_grid and not GameManager.hex_grid.is_coastal_tile(unit.coord))

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
	magic_button.disabled = true
	diplomacy_button.disabled = true
	victory_button.disabled = true
	grimoire_button.disabled = true

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
