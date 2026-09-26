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
## Aetherlands V2, Fase 14 — Conhecimento/turno e Capacidade de Suprimentos (§71 do pedido).
## Criados em código (_build_v2_economy_status_labels), não no HUD.tscn — mesmo padrão de
## V2Actions/V2CityActions (Fases 4/13): container dinâmico em vez de editar a cena.
var v2_knowledge_label: Label
var v2_supply_label: Label
## ActionBar (canto inferior direito, ver HUD.tscn): cluster de botoes de
## menu/acao — "Pesquisa" (quadro das três árvores, V2ResearchBoard) em cima
## do botão de passar de turno. Finalizar Turno fica por ULTIMO na
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
## Grade da aba Construções — os botões de prédio são criados em código, um por prédio do
## BuildingDatabase (_build_building_buttons).
@onready var buildings_row: GridContainer = $TileInfoPanel/TileInfoBox/ProductionTabs/BuildingsTab/BuildingsTabBox/BuildingsRow
## Botão normal de Pesquisa (Fase 25): abre o quadro das três árvores (V2ResearchBoard) — antes só
## alcançável pelo painel de Debug. Os antigos botões Magia/Tecnologia/Grimório (árvores e magia V1)
## foram removidos da cena.
@onready var research_button: Button = $ActionBar/ActionBarBox/ResearchButton
## Diplomacia e Vitória: ícones compactos no canto SUPERIOR direito (IconGroup do TopBar).
@onready var diplomacy_button: Button = $TopBar/TopBarRow/IconGroup/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyHeader/DiplomacyCloseButton
## Roadmap "Fase F" F1/F2/F5 -- mesmo padrao de overlay do Diplomacy acima.
@onready var victory_button: Button = $TopBar/TopBarRow/IconGroup/VictoryButton
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_rows: VBoxContainer = $VictoryPanel/VictoryBox/VictoryRows
@onready var victory_close_button: Button = $VictoryPanel/VictoryBox/VictoryHeader/VictoryCloseButton
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
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_info_label: Label = $UnitPanel/UnitBox/UnitInfoLabel
## Mover/Fortificar/Explorar (pedido do usuario: "as opções... que se me
## recordo civilization é mover, fortificar e explorar") — ver
## SelectionManager.wake_selected_for_move/fortify_selected/
## toggle_explore_selected.
@onready var move_button: Button = $UnitPanel/UnitBox/UnitActionsRow/MoveButton
@onready var fortify_button: Button = $UnitPanel/UnitBox/UnitActionsRow/FortifyButton
@onready var explore_button: Button = $UnitPanel/UnitBox/UnitActionsRow/ExploreButton
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
## Quadro de Pesquisa: as três árvores (Doutrinas, Magia, Infraestrutura) ligadas ao estado REAL de
## pesquisa da civilização humana (V2ResearchState). Aberto pelo botão normal "Pesquisa"
## (research_button); as ferramentas que MANIPULAM o estado continuam só em debug build (dentro do
## próprio V2ResearchBoard). Construído em código (_build_v2_research_panel).
var v2_research_panel: PanelContainer
var v2_research_board: V2ResearchBoard
## Estado V2 de reserva, só usado se abrirem o painel sem jogador humano (testes/menus).
var _v2_fallback_state: V2ResearchState = V2ResearchState.new()
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
	_build_v2_economy_status_labels()
	production_tabs.set_tab_title(0, "Unidades")
	production_tabs.set_tab_title(1, "Construções")
	_build_building_buttons()
	_build_production_buttons()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	found_city_button.pressed.connect(_on_found_city_pressed)
	move_button.pressed.connect(_on_move_pressed)
	fortify_button.pressed.connect(_on_fortify_pressed)
	explore_button.pressed.connect(_on_explore_pressed)
	research_button.pressed.connect(_on_research_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
	victory_button.pressed.connect(_on_victory_pressed)
	victory_close_button.pressed.connect(_on_victory_close_pressed)
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
	_build_v2_research_panel()
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
	EventBus.v2_unlock_applied.connect(_on_v2_unlock_applied)
	EventBus.v2_transcendence_started.connect(_on_v2_transcendence_changed)
	EventBus.v2_transcendence_progressed.connect(_on_v2_transcendence_changed)
	EventBus.v2_transcendence_interrupted.connect(_on_v2_transcendence_interrupted)
	EventBus.fog_updated.connect(_refresh_selected_unit_panel)
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
	production_progress_label.visible = false
	production_progress_bar.visible = false
	diplomacy_panel.visible = false
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

## Um botão por prédio do BuildingDatabase (todos V2), criado UMA vez aqui dentro da grade da aba
## Construções — visibilidade/habilitação por cidade em _on_tile_selected/_update_building_tooltips.
var _building_buttons: Dictionary = {} # id -> Button

func _build_building_buttons() -> void:
	for building in BuildingDatabase.all_buildings():
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 0)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.text = _building_button_label(building.id)
		button.pressed.connect(_on_produce_pressed.bind(building.id))
		buildings_row.add_child(button)
		_building_buttons[building.id] = button

func _building_button_label(id: String, _race: String = "") -> String:
	var building: BuildingData = BuildingDatabase.get_building(id)
	return "%s  —  %d PP" % [building.display_name, int(building.production_cost)]

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

func _on_produce_pressed(kind: String) -> void:
	if _viewed_city == null or not GameManager.human_player.has_unlocked(kind):
		return
	var building = BuildingDatabase.get_building(kind)
	if building:
		if not _viewed_city.can_build(kind):
			return
		# Todo prédio precisa de um tile escolhido no mapa (como fundar cidade) — a produção só começa
		# de fato quando o jogador clica um tile válido (SelectionManager._handle_building_placement_click).
		SelectionManager.start_building_placement(_viewed_city, kind)
		return
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

## Aetherlands V2 (Fase 3): um unlock V2 acabou de valer pro jogador humano (o toast
## já saiu por EventBus.notify) — os botões de prédio/tropa da cidade aberta
## dependem dele. A pesquisa V2 costuma ser concluída COM o painel V2 aberto (que
## esconde o painel de cidade), então nesse caso a atualização espera o painel
## fechar (ver _close_overlay_panels) em vez de reabrir o painel de cidade por
## cima do overlay.
var _v2_city_refresh_pending := false

func _on_v2_unlock_applied(player: PlayerData, _unlock_type: String, _unlock_id: String) -> void:
	if player != GameManager.human_player or _viewed_city == null:
		return
	if v2_research_panel.visible:
		_v2_city_refresh_pending = true
	else:
		_refresh_viewed_city()

## Pesquisa/Diplomacia/Vitória/Debug/FimDeJogo sao todos paineis
## centralizados na mesma posicao — sem isso, abrir um por cima do outro
## (ou o jogo acabar com um deles aberto) deixava tudo empilhado e
## ilegivel. So um fica visivel por vez, e o backdrop escurecido some
## junto (ver _show_overlay).
func _close_overlay_panels() -> void:
	diplomacy_panel.visible = false
	victory_panel.visible = false
	game_over_panel.visible = false
	debug_panel.visible = false
	v2_research_panel.visible = false
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
	if _v2_city_refresh_pending:
		_v2_city_refresh_pending = false
		_refresh_viewed_city()

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
	if diplomacy_panel.visible or victory_panel.visible or debug_panel.visible or v2_research_panel.visible or dragon_announcement_panel.visible or dragon_resolution_panel.visible:
		_close_overlay_panels()
		return true
	return false

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

## Painel de vitórias (Fase 25): só as TRÊS vias finais — Dominação, Supremacia Militar e
## Transcendência — na ordem de precedência de GameManager.check_victories. Camada de APRESENTAÇÃO pura:
## só lê VictoryConditions/V2VictoryConditions/V2TranscendenceSystem (a regra mora lá, nunca aqui) e
## nunca escreve em PlayerData. Mostra a perspectiva do jogador humano + os Rituais Finais públicos dos
## rivais (informação pública por regra). LIVE — consultado toda vez que o painel abre (ver
## _on_victory_achieved pro snapshot CONGELADO da tela final).
func _refresh_victory_panel() -> void:
	_build_victory_progress_rows(victory_rows)

## Mesma montagem para o painel ao vivo e para o snapshot congelado da tela final, cada um no próprio
## VBoxContainer.
func _build_victory_progress_rows(target: VBoxContainer) -> void:
	for child in target.get_children():
		child.queue_free()
	var human: PlayerData = GameManager.human_player
	if human == null or GameManager.hex_grid == null:
		return
	var players: Array[PlayerData] = ([human] as Array[PlayerData]) + GameManager.rival_players

	_add_victory_heading(target, "Dominação")
	_add_victory_progress_row(target, "Rivais eliminados", VictoryConditions.dominance_progress(human, players))
	_add_victory_detail(target, "Civilizações restantes: %d. Vence quem for a última civilização restante." % VictoryConditions.civilizations_remaining(players))

	_add_victory_heading(target, "Supremacia Militar")
	var supremacy := V2VictoryConditions.military_supremacy_status(human)
	var has_supremacy_access := human.has_unlocked(V2VictoryConditions.MILITARY_SUPREMACY_ACCESS)
	var supremacy_progress := float(supremacy.satisfied_count) / float(maxi(1, supremacy.rival_count)) if has_supremacy_access else 0.0
	_add_victory_progress_row(target, "Rivais satisfeitos", supremacy_progress)
	var supremacy_lines: Array[String] = ["Exército Supremo pesquisado." if has_supremacy_access else "Requer pesquisa: Exército Supremo (duas Doutrinas completas)."]
	supremacy_lines.append_array(V2VictoryConditions.military_supremacy_lines(human))
	supremacy_lines.append("Conquiste e mantenha uma Cidade III+ de cada rival (rival eliminado também conta).")
	_add_victory_detail(target, "\n".join(supremacy_lines))

	_add_victory_heading(target, "Transcendência")
	var transcendence := V2VictoryConditions.transcendence_status(human)
	var transcendence_progress := 0.0
	if transcendence.active:
		transcendence_progress = 1.0 - float(transcendence.remaining_rounds) / float(V2TranscendenceSystem.ROUNDS_REQUIRED)
	_add_victory_progress_row(target, "Ritual Final", transcendence_progress)
	var transcendence_lines: Array[String] = ["Transcendência pesquisada." if transcendence.access else "Requer pesquisa: Transcendência (duas Escolas completas)."]
	transcendence_lines.append_array(V2VictoryConditions.transcendence_lines(human))
	for ritual in V2TranscendenceSystem.public_rituals():
		if int(ritual.owner_index) == V2VictoryConditions.stable_id(human):
			continue
		transcendence_lines.append("%s — Ritual Final em (%d, %d): %d rodada(s) restante(s)." % [ritual.owner_name, ritual.site_coord.x, ritual.site_coord.y, ritual.remaining_rounds])
	_add_victory_detail(target, "\n".join(transcendence_lines))

func _add_victory_heading(target: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.theme_type_variation = &"PanelTitle"
	target.add_child(heading)

func _add_victory_detail(target: VBoxContainer, text: String) -> void:
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.theme_type_variation = &"MutedLabel"
	detail.text = text
	target.add_child(detail)

## `progress` e SEMPRE 0.0-1.0 — esta funcao so formata o numero JA normalizado, nunca reinterpreta
## o que ele significa por tipo de vitória (a semântica fica em VictoryConditions/V2VictoryConditions).
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
## mostra >100% nem negativo mesmo se o progresso bruto de entrada passar disso.
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
	match victory_type:
		VictoryConditions.VICTORY_TYPE_DOMINANCE:
			return "Vitória por Dominação — %s" % winner.civ.civ_name
		V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY:
			return "Vitória por Supremacia Militar — %s" % winner.civ.civ_name
		V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE:
			return "Vitória por Transcendência — %s" % winner.civ.civ_name
	return "%s venceu a partida" % winner.civ.civ_name

## Resumo FIXO por tipo de vitória (nunca gerado do estado de um jogador específico).
static func format_victory_summary(victory_type: String) -> String:
	match victory_type:
		VictoryConditions.VICTORY_TYPE_DOMINANCE:
			return "Eliminou todos os reinos rivais."
		V2VictoryConditions.VICTORY_TYPE_MILITARY_SUPREMACY:
			return "Seu império provou sua supremacia conquistando os centros desenvolvidos de seus rivais."
		V2VictoryConditions.VICTORY_TYPE_TRANSCENDENCE:
			return "Concluiu o Ritual Final mantendo duas Grandes Manifestações e uma cidade ritual por quatro rodadas."
		"eliminated":
			return "Seu reino perdeu todas as cidades e unidades."
		VictoryConditions.VICTORY_TYPE_DEBUG:
			return "Fim de jogo disparado manualmente pelo modo debug -- nenhuma condição de vitória real foi avaliada."
	return ""

## Roadmap "Fase F" F6 -- CONGELA o snapshot no momento exato da vitoria:
## chamado UMA vez, so pelo sinal EventBus.victory_achieved (nunca
## re-chamado por nenhum refresh posterior da HUD). Popula Labels/
## ProgressBars ESTATICOS (game_over_snapshot_rows) que NAO tem nenhuma
## ligacao viva com as condições de vitória depois deste ponto -- diferente do
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

## Painel das árvores V2 — mesmo chrome escuro (fundo + gradiente)
## das árvores V1, em tela cheia. O V2ResearchBoard só reconstrói o conteúdo
## quando aberto/aba/estado muda (sem _process).
func _build_v2_research_panel() -> void:
	v2_research_panel = PanelContainer.new()
	v2_research_panel.name = "ResearchPanel"
	v2_research_panel.visible = false
	add_child(v2_research_panel)
	v2_research_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_sb := UITheme.panel_style(V2ResearchBoard.BG_LEVEL, V2ResearchBoard.BORDER_STEEL, 1, 0, false)
	panel_sb.set_content_margin_all(28)
	v2_research_panel.add_theme_stylebox_override("panel", panel_sb)
	_add_panel_background_gradient(v2_research_panel)
	v2_research_board = V2ResearchBoard.new()
	v2_research_board.close_requested.connect(_close_overlay_panels)
	v2_research_panel.add_child(v2_research_board)

## Gradiente radial sutil de fundo (recurso nativo do Godot, gerado em código) inserido como PRIMEIRO
## filho do painel — o conteúdo continua desenhando por cima.
func _add_panel_background_gradient(panel: PanelContainer) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, V2ResearchBoard.BG_LEVEL.lightened(0.035))
	gradient.set_color(1, V2ResearchBoard.BG_LEVEL.darkened(0.2))
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

## Botão "Pesquisa" (Fase 25 — o acesso normal; antes o quadro só abria pelo painel de Debug). Liga o
## quadro ao estado da civilização humana ATUAL (troca a cada partida nova/carregada; religar o mesmo
## estado é no-op) e alterna o overlay.
func _on_research_pressed() -> void:
	if v2_research_panel.visible:
		_close_overlay_panels()
		return
	v2_research_board.bind_state(V2ResearchState.for_player(GameManager.human_player) if GameManager.human_player != null else _v2_fallback_state)
	_show_overlay(v2_research_panel)
	v2_research_board.refresh()

func _refresh_debug_panel() -> void:
	var hex_grid = GameManager.hex_grid
	var fog_disabled = hex_grid != null and hex_grid.debug_fog_disabled
	debug_mode_button.button_pressed = GameManager.debug_mode
	debug_mode_button.text = "Desativar Modo Debug" if GameManager.debug_mode else "Ativar Modo Debug (producao instantanea)"
	debug_reveal_map_button.button_pressed = fog_disabled
	debug_reveal_map_button.text = "Restaurar Neblina" if fog_disabled else "Revelar Mapa (sem neblina)"
	debug_complete_research_button.disabled = GameManager.human_player == null or GameManager.human_player.v2_research.active_id == ""

## Modo debug: produção da cidade humana em 1 turno (GameManager.set_debug_mode). A pesquisa tem as
## próprias ferramentas de debug dentro do quadro de Pesquisa.
func _on_debug_mode_pressed() -> void:
	GameManager.set_debug_mode(not GameManager.debug_mode)
	_refresh_debug_panel()
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
	research_button.disabled = false
	diplomacy_button.disabled = false
	victory_button.disabled = false
	unit_panel.visible = false
	production_tabs.visible = false
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
	if diplomacy_panel.visible:
		_refresh_diplomacy_panel()
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
	_refresh_selected_unit_panel()
	# Regressao: o painel da cidade so se atualizava ao clicar de novo no
	# tile (_on_produce_pressed/_on_worked_tile_pressed chamavam isso, mas
	# _on_turn_changed nao) — produzir um predio parecia "nao fazer nada"
	# pro jogador, porque progresso/predio concluido nunca aparecia sem
	# reclicar a cidade manualmente.
	_refresh_viewed_city()

## Aetherlands V2, Fase 14 — cria os dois indicadores novos da barra superior (Conhecimento/turno,
## Capacidade de Suprimentos) como filhos do MESMO StatusGroup que já tem Ouro/Mana/Cidades/FPS —
## chamado uma vez em _ready(). Sem editar HUD.tscn (mesmo espírito de V2Actions/V2CityActions).
## Fase 25: ordem fixa da barra — Ouro | Suprimentos | Mana | Conhecimento.
func _build_v2_economy_status_labels() -> void:
	v2_supply_label = Label.new()
	v2_supply_label.name = "V2SupplyLabel"
	_insert_status_label_after(gold_label, v2_supply_label)
	v2_knowledge_label = Label.new()
	v2_knowledge_label.name = "V2KnowledgeLabel"
	_insert_status_label_after(mana_label, v2_knowledge_label)

func _insert_status_label_after(anchor: Label, label: Label) -> void:
	var status_group := anchor.get_parent()
	var separator := VSeparator.new()
	status_group.add_child(separator)
	status_group.move_child(separator, anchor.get_index() + 1)
	status_group.add_child(label)
	status_group.move_child(label, separator.get_index() + 1)

## Fonte unica pro texto de ouro/mana/estatisticas da barra superior —
## chamada tanto em troca de turno quanto apos qualquer notificacao
## (_on_notify), o que cobre conjurar um feitico (gasta mana no meio do
## turno, ver SelectionManager._handle_spell_targeting_click) sem precisar
## de mais um gancho de atualizacao dedicado so pra isso.
func _refresh_stats() -> void:
	var player = GameManager.human_player
	if player:
		stats_label.text = "Cidades: %d | Unidades: %d" % [player.cities.size(), player.units.size()]
		var race_info: Dictionary = GameSetupScreen.RACE_INFO.get(player.civ.race, GameSetupScreen.RACE_INFO.human)
		var racial_lines := V2RaceBonusRuntime.effect_lines(player)
		stats_label.tooltip_text = "Raça: %s\n%s\n• %s" % [race_info.display_name, V2RaceBonusRuntime.summary(player), "\n• ".join(racial_lines)]
		# Aetherlands V2, Fase 15 (§32 do pedido) — Ouro mostra o LÍQUIDO agora (bruto - upkeep dos
		# prédios V2 com manutenção), com sinal explícito quando negativo ("Ouro: 12 (-3)"). A
		# renda em si continua vindo inteira de V2EconomyRuntime; nenhum número daqui soma com a
		# antiga renda V1 (auditoria em docs/AETHERLANDS_V2_IMPLEMENTATION.md Fase 14).
		var gold_gross := V2EconomyRuntime.player_gold_gross_income(player)
		var gold_upkeep := V2EconomyRuntime.player_gold_upkeep(player)
		var gold_net := gold_gross - gold_upkeep
		gold_label.text = "Ouro: %d (%s%d)" % [int(player.gold), "+" if gold_net >= 0.0 else "", int(gold_net)]
		gold_label.tooltip_text = "Renda: +%.0f/turno\nManutenção: -%.0f/turno\nLíquido: %+.0f/turno%s" % [
			gold_gross, gold_upkeep, gold_net,
			"\n\nDÉFICIT: prédios com manutenção operam a 50%." if V2EconomyRuntime.is_gold_deficit(player) else "",
		]
		var mana_income := V2EconomyRuntime.player_mana_income(player)
		mana_label.text = "Mana: %d (+%d)" % [int(player.mana), int(mana_income)]
		mana_label.tooltip_text = "Produção: +%.0f/turno (base das cidades, Santuários Arcanos e Conduítes).
Gasta em feitiços e na produção de Grandes Manifestações." % mana_income
		# Conhecimento mostra só a renda por turno (não é estoque visível na barra — o "estoque" dele é o
		# progresso da pesquisa ativa, visível no botão "Pesquisa", ver _refresh_research_button).
		if v2_knowledge_label:
			v2_knowledge_label.text = "Conhecimento: +%d/turno" % int(V2EconomyRuntime.player_knowledge_income(player))
		# Aetherlands V2, Fase 15 (§22 do pedido) — Suprimentos passa a mostrar USADOS / CAPACIDADE
		# (o consumo militar da Fase 14 era só capacidade, sem uso nenhum ainda). Em Tensão
		# Logística (usados > capacidade), acrescenta "— TENSÃO" no texto.
		if v2_supply_label:
			var supply_used := V2LogisticsRuntime.player_supply_used(player)
			var supply_capacity := int(V2EconomyRuntime.player_supply_capacity(player))
			var strained := supply_used > supply_capacity
			v2_supply_label.text = "Suprimentos: %d / %d%s" % [supply_used, supply_capacity, " — TENSÃO" if strained else ""]
			v2_supply_label.tooltip_text = "Excesso logístico: unidades abastecidas sofrem -15% Ataque e Defesa." if strained else "Capacidade logística total (Fazendas + base por cidade + melhorias de Cavalos)."
		_refresh_research_button(player)

## Progresso da pesquisa ATIVA direto no botão "Pesquisa" (padrão do Civilization: o ícone de
## pesquisa já mostra o progresso sem abrir a árvore). Sem projeto ativo, só "Pesquisa".
func _refresh_research_button(player: PlayerData) -> void:
	var active_id := player.v2_research.active_id
	var node := V2ResearchDatabase.get_node(active_id) if active_id != "" else null
	if node == null:
		research_button.text = "Pesquisa"
		return
	research_button.text = "Pesquisa: %s (%d%%)" % [node.display_name, int(round(player.v2_research.get_progress_ratio(active_id) * 100.0))]

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
	# Aetherlands V2, Fase 16 (achado na validação visual): sem isto, as ações da cidade vista antes
	# (Evoluir/Fortificar/Ataque da Cidade/Anexar) ficavam na tela — e clicáveis — sob um tile qualquer.
	if _viewed_city == null:
		_refresh_v2_city_actions(null)
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
		# Só aparece o que a cidade REALMENTE pode produzir agora: tropa liberada pela pesquisa + prédio de
		# treino (City.can_train), prédio liberado pela pesquisa (City._research_unlocked_for_building).
		# Falta de slot/pré-requisito/Déficit só DESABILITA o botão de prédio, com o motivo no tooltip.
		var race: String = GameManager.human_player.civ.race
		for id in _building_buttons:
			var btn: Button = _building_buttons[id]
			btn.disabled = not _viewed_city.can_build(id)
			btn.visible = _viewed_city._research_unlocked_for_building(id)
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			_production_buttons[kind].text = _unit_button_label(kind, race)
			var can_start: bool = GameManager.human_player.has_unlocked(kind) and _viewed_city.can_train(kind)
			# Fase 6: a Lendária cujo ÚNICO impedimento é o slot global aparece DESABILITADA, com o motivo
			# no tooltip (em vez de sumir sem explicar); qualquer outro bloqueio continua escondendo o botão.
			# Fase 15 (§15 do pedido): Déficit/Suprimentos insuficientes recebem o MESMO tratamento — nunca
			# escondidos atrás de "Indisponível" genérico.
			var slot_reason := "" if can_start else V2LegendarySystem.slot_only_reason(GameManager.human_player, _viewed_city, kind)
			if slot_reason == "" and not can_start:
				slot_reason = V2LogisticsRuntime.training_soft_reason(GameManager.human_player, _viewed_city, kind)
			if slot_reason == "" and not can_start: # Fase 17: slot da Escola ocupado / Mana para iniciar
				slot_reason = V2ManifestationSystem.training_soft_reason(GameManager.human_player, _viewed_city, kind)
			_production_buttons[kind].visible = can_start or slot_reason != ""
			_production_buttons[kind].disabled = slot_reason != ""
		_update_production_tooltips()
		_update_building_tooltips()
		_refresh_v2_city_actions(_viewed_city)

var _production_buttons: Dictionary = {} # kind -> Button, montado uma vez em _build_production_buttons()

## Um botao por UnitDatabase.PLAYER_TRAINABLE_KINDS, criado UMA VEZ aqui
## (nao recriado a cada refresh — perderia foco/hover toda hora a toa) e
## so tem .disabled/.tooltip_text atualizados depois (ver _on_tile_selected/
## _update_production_tooltips). Texto = nome + custo (mesmo formato de
## _building_button_label, pra tile de unidade e tile de predio lerem
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
	if unit.production_mana_cost > 0.0: # Fase 17: Serafim — 100 PP + 60 Mana (a Mana é cobrada na conclusão)
		return "%s  —  %d PP + %d Mana" % [RaceTheme.unit_name(kind, race), int(unit.production_cost), int(unit.production_mana_cost)]
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
	if _viewed_city != null and GameManager.human_player != null:
		var slot_reason := V2LegendarySystem.slot_only_reason(GameManager.human_player, _viewed_city, kind)
		if slot_reason != "":
			return slot_reason
		var supply_reason := V2LogisticsRuntime.training_soft_reason(GameManager.human_player, _viewed_city, kind)
		if supply_reason != "":
			return supply_reason
		var manifestation_reason := V2ManifestationSystem.training_soft_reason(GameManager.human_player, _viewed_city, kind)
		if manifestation_reason != "":
			return manifestation_reason
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
		return

	var city_race: String = city.owner_player.civ.race
	var building_in_progress: BuildingData = BuildingDatabase.get_building(city.production_item)
	var item_label = RaceTheme.building_name(city.production_item, city_race) if building_in_progress else RaceTheme.unit_name(city.production_item, city_race)
	# Projetos locais V2 (Fases 13/16) não são prédio nem unidade: nome vem do próprio dado.
	if V2CityLevelData.is_city_project(city.production_item):
		item_label = V2CityLevelData.level_name(V2CityLevelData.target_level_for_project(city.production_item))
	elif V2FortificationData.is_fortification_project(city.production_item):
		item_label = V2FortificationData.display_name(V2FortificationData.target_level_for_project(city.production_item))
	var cost := city.production_cost()
	var stored := city.stored_production

	var turns_text := ""
	if hex_grid:
		var production_per_turn := V2EconomyRuntime.city_production_income(city)
		if production_per_turn > 0.0:
			var turns = ceili(max(cost - stored, 0.0) / production_per_turn)
			var suffix = "" if turns == 1 else "s"
			turns_text = " (~%d turno%s restante%s)" % [turns, suffix, suffix]
		else:
			turns_text = " (sem producao suficiente pra estimar o tempo)"

	production_progress_label.text = "Produzindo: %s — %d/%d PP%s" % [item_label, int(stored), int(cost), turns_text]
	# Fase 17: PP completos mas Mana insuficiente — a produção espera sem perder nada.
	var waiting_mana := city.production_waiting_for_mana()
	if waiting_mana > 0 and stored >= cost:
		production_progress_label.text = "Produzindo: %s — %d/%d PP. Aguardando %d Mana." % [item_label, int(stored), int(cost), waiting_mana]
	production_progress_bar.max_value = max(cost, 0.01)
	production_progress_bar.value = stored
	production_progress_label.visible = true
	production_progress_bar.visible = true

## e so o tempo ESTIMADO no ritmo de producao atual da cidade vista, pra
## nao ter que fazer conta de cabeca. Arredonda pra cima (ceil): "pronto no
## proximo turno" so quando realmente sobra 1 turno inteiro ou menos.
func _estimated_turns_tooltip(cost: float) -> String:
	var hex_grid = GameManager.hex_grid
	if hex_grid == null or _viewed_city == null:
		return ""
	var production_per_turn := V2EconomyRuntime.city_production_income(_viewed_city)
	if production_per_turn <= 0.0:
		return "Custo: %d PP (sem producao suficiente pra estimar o tempo)" % int(cost)
	var turns = ceili(cost / production_per_turn)
	return "Custo: %d PP (~%d turno%s no ritmo atual)" % [int(cost), turns, "" if turns == 1 else "s"]

func _update_building_tooltips() -> void:
	for id in _building_buttons:
		_building_buttons[id].tooltip_text = _building_lock_reason(id)

## "" quando o prédio já está liberado pra construir — senão o motivo, na ordem: pesquisa → prédio
## pré-requisito → cópias → slots (City Level) → Déficit. Só chamado para botões visíveis (a pesquisa
## já liberou o prédio), mas a checagem de pesquisa fica por segurança.
func _building_lock_reason(id: String, _race: String = "") -> String:
	var building: BuildingData = BuildingDatabase.get_building(id)
	if building == null:
		return ""
	if not _viewed_city._research_unlocked_for_building(id):
		var node := V2ResearchDatabase.node_for_unlock_id(id)
		return "Requer pesquisa: %s" % (node.display_name if node != null else id)
	if building.requires_building != "" and not _viewed_city.buildings.has(building.requires_building):
		return "Requer construir: %s" % RaceTheme.building_name(building.requires_building)
	if _viewed_city.building_count(id) >= _viewed_city.max_copies_for_building(building):
		return "Limite de cópias atingido para %s" % V2CityLevelData.level_name(_viewed_city.city_level)
	if _viewed_city.used_building_slots() >= _viewed_city.max_building_slots():
		return "Sem espaço: %d/%d prédios (evolua a cidade de nível)" % [_viewed_city.used_building_slots(), _viewed_city.max_building_slots()]
	# Fase 15 (§43): prédio com manutenção não pode ser INICIADO em Déficit — checado por ÚLTIMO.
	var deficit_reason := _viewed_city.deficit_build_reason(id)
	if deficit_reason != "":
		return deficit_reason
	return _estimated_turns_tooltip(building.production_cost)

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
	_refresh_v2_unit_actions(unit)
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
	if SelectionManager.technique_targeting_id != "" and SelectionManager.technique_targeting_unit == unit:
		var targeting := V2DoctrineTechniqueDatabase.get_technique(SelectionManager.technique_targeting_id)
		text += "\n» Escolha o %s de %s (ESC cancela) «" % ["tile" if targeting.target_mode == V2DoctrineTechniqueData.TargetMode.TILE else "alvo", targeting.display_name]
	if SelectionManager.v2_spell_targeting_id != "" and SelectionManager.v2_spell_targeting_unit == unit:
		text += "\n» %s «" % V2MagicRuntime.targeting_hint(V2SpellDatabase.get_spell(SelectionManager.v2_spell_targeting_id)) # Fase 17
	if not unit.unit_data.can_basic_attack:
		text += "\nSem ataque básico." # Fase 17: conjurador (Clérigo/Serafim) — nada induz a tentar atacar
	if unit.unit_data.spell_damage_multiplier > 1.0:
		var spell_passive := unit.unit_data.spell_damage_multiplier_name if unit.unit_data.spell_damage_multiplier_name != "" else "Potência Mágica"
		text += "\nPassiva da Manifestação — %s\n+%d%% de dano de feitiços." % [spell_passive, int(round((unit.unit_data.spell_damage_multiplier - 1.0) * 100.0))]
	if unit.unit_data.spell_cooldown_reduction > 0:
		var cooldown_passive := unit.unit_data.spell_cooldown_reduction_name if unit.unit_data.spell_cooldown_reduction_name != "" else "Fluxo Mágico"
		text += "\nPassiva da Manifestação — %s\n-%d turno(s) na recarga aplicada por feitiços." % [cooldown_passive, unit.unit_data.spell_cooldown_reduction]
	if unit.unit_data.environmental_zone_duration_bonus > 0:
		var environmental_passive := unit.unit_data.environmental_zone_duration_bonus_name if unit.unit_data.environmental_zone_duration_bonus_name != "" else "Domínio Ambiental"
		text += "\nPassiva da Manifestação — %s\n+%d rodada(s) na duração das zonas ambientais criadas." % [environmental_passive, unit.unit_data.environmental_zone_duration_bonus]
	# Fase 19 — retinues: passiva de capacidade por dado (Soberania dos Mortos), estado SEM COMANDO e a seção compacta
	# "Comando <Escola>: usado / capacidade" para comandante OU retinue. Tudo derivado (V2RetinueSystem).
	if unit.unit_data.retinue_command_capacity_name != "" and unit.unit_data.is_retinue_commander():
		var passive_owner := "Passiva da Manifestação" if V2ManifestationSystem.is_manifestation_unit(unit) else "Passiva"
		text += "\n%s — %s\nConcede +%d de capacidade de %s." % [passive_owner, unit.unit_data.retinue_command_capacity_name, unit.unit_data.retinue_command_capacity, V2MagicContent.command_label(unit.unit_data.v2_magic_school)]
	# Fase 20 — alcance extra de feitiços por dado (Domínio Natural); o botão mostra o alcance efetivo no tooltip.
	if unit.unit_data.spell_range_bonus > 0 and unit.unit_data.is_v2_caster():
		var range_passive := unit.unit_data.spell_range_bonus_name if unit.unit_data.spell_range_bonus_name != "" else "Alcance Mágico"
		var range_owner := "Passiva da Manifestação" if V2ManifestationSystem.is_manifestation_unit(unit) else "Passiva"
		text += "\n%s — %s\n+%d alcance de feitiços." % [range_owner, range_passive, unit.unit_data.spell_range_bonus]
	if not unit.can_receive_orders():
		text += "\nSEM COMANDO — não pode receber ordens."
	for command_line in V2RetinueSystem.summary_lines(unit):
		text += "\n" + command_line
	unit_info_label.text = text
	if V2LegendarySystem.is_legendary_unit(unit):
		unit_info_label.text = "LENDÁRIO\n" + unit_info_label.text # Unidade Lendária (Fase 6)
	var orders_locked := GameManager.is_turn_processing or not unit.can_receive_orders() # Fase 19: retinue sem comando
	# Task 23 -- mesmos fatos do painel de inspecao: classe/escola, efeitos
	# ativos, acao/recarga do conjurador e o que mais existe neste tile
	# (terreno continua consultavel mesmo com a unidade em cima).
	unit_info_label.text += "\nClasse: %s" % TileInspector.unit_class_label(unit)
	for status_line in TileInspector.status_effect_lines(unit):
		unit_info_label.text += "\n" + status_line
	for caster_line in TileInspector.caster_lines(unit):
		unit_info_label.text += "\n" + caster_line
	for environment_line in V2EnvironmentalZoneSystem.unit_lines(unit, GameManager.hex_grid):
		unit_info_label.text += "\n" + environment_line
	if unit.owner_player == GameManager.human_player:
		for passive_line in V2TechniqueRuntime.passive_lines(unit): # Técnicas passivas V2: só texto, sem botão
			unit_info_label.text += "\n" + passive_line
		for aura_line in V2UnitAuras.lines(unit): # aura intrínseca (Comando Defensivo do Campeão)
			unit_info_label.text += "\n" + aura_line
		for execution_line in UnitAbilities.intrinsic_attack_lines(unit): # passivas intrínsecas de ataque (Execução, Caçada Lendária)
			unit_info_label.text += "\n" + execution_line
		for artillery_line in UnitAbilities.artillery_march_lines(unit): # Artilharia Andante (Colosso de Cerco, Fase 11)
			unit_info_label.text += "\n" + artillery_line
		if UnitAbilities.flight_text(unit.unit_data) != "": # perfil de voo tático (por dado)
			unit_info_label.text += "\n" + UnitAbilities.flight_text(unit.unit_data)
		if UnitAbilities.infiltration_text(unit.unit_data) != "": # perfil de infiltração / Passo Sombrio (por dado)
			unit_info_label.text += "\n" + UnitAbilities.infiltration_text(unit.unit_data)
		if UnitAbilities.ranged_vulnerability_text(unit.unit_data) != "": # counter por dado (vulnerabilidade a ataques à distância)
			unit_info_label.text += "\n" + UnitAbilities.ranged_vulnerability_text(unit.unit_data)
		# Aetherlands V2, Fase 15 (§23 do pedido): Suprimentos + Tensão Logística no painel da
		# própria unidade -- só pra unidade com custo (civis e o Guarda inicial nunca mostram a linha).
		if unit.unit_data.supply_cost > 0:
			unit_info_label.text += "\nSuprimentos: %d" % unit.unit_data.supply_cost
			if V2LogisticsRuntime.is_logistically_strained(unit.owner_player):
				unit_info_label.text += "\nTensão Logística: -15% Ataque / Defesa."
		if V2ConstructorRuntime.is_builder_unit(unit): # §80 do pedido: cargas restantes do Construtor
			unit_info_label.text += "\nCargas restantes: %d" % unit.work_charges_remaining
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
	move_button.tooltip_text = unit.order_block_reason() # Fase 19: "Hoste sem comando necromântico." (vazio para o resto)
	fortify_button.disabled = unit.embarked or orders_locked
	explore_button.button_pressed = unit.exploring
	explore_button.disabled = unit.embarked or orders_locked
	# Embarcar foi desligado na Fase 25 (a trava era a tecnologia V1 "Navegação"; a navegação V2 é uma
	# decisão futura). Uma unidade que já estava embarcada num save continua se movendo e desembarca
	# sozinha ao chegar em terra (HexGrid.move_unit).

## Aetherlands V2 (Fase 13): botão de upgrade urbano ("Evoluir para Cidade N — X PP + Y Ouro") e
## de anexação ("Anexar território (N)") no painel de cidade — mesmo padrão de
## _refresh_v2_unit_actions logo abaixo (container dinâmico, sem mexer no HUD.tscn). O upgrade é
## um PROJETO LOCAL (compete pela mesma produção normal, ver City.gd) — clicar só chama
## set_production, igual qualquer prédio/unidade; Cidade IV não mostra botão de upgrade (§46).
func _refresh_v2_city_actions(city: City) -> void:
	var box := tile_info_panel.get_node("TileInfoBox")
	var old := box.get_node_or_null("V2CityActions")
	if old:
		box.remove_child(old)
		old.queue_free()
	if city == null:
		return
	var row := HFlowContainer.new()
	row.name = "V2CityActions"
	box.add_child(row)

	var next_level := V2CityLevelData.next_level(city.city_level)
	if next_level > 0:
		var upgrade_button := Button.new()
		upgrade_button.name = "CityUpgradeButton"
		var pp := int(V2CityLevelData.upgrade_production_cost(next_level))
		var gold_cost := int(V2CityLevelData.upgrade_gold_cost(next_level))
		upgrade_button.text = "Evoluir para %s — %d PP + %d Ouro" % [V2CityLevelData.level_name(next_level), pp, gold_cost]
		if city.production_item == V2CityLevelData.project_id_for_level(next_level):
			var waiting := city.city_upgrade_waiting_for_gold()
			if waiting > 0:
				upgrade_button.text = "Aguardando %d Ouro." % waiting
			else:
				upgrade_button.text += " (em progresso)"
		var reason := city.city_upgrade_unavailable_reason()
		upgrade_button.tooltip_text = "Projeto local: usa a produção normal da cidade." if reason == "" else reason
		upgrade_button.disabled = reason != "" or GameManager.is_turn_processing
		upgrade_button.pressed.connect(_on_city_upgrade_pressed.bind(city, next_level))
		row.add_child(upgrade_button)

	# Aetherlands V2, Fase 16 — próximo nível de Fortificação (projeto local, mesma fila) e o Ataque
	# da Cidade (ação explícita, uma vez por turno). Números/regras todos de V2FortificationData/
	# City/CityDefense — a HUD só formata.
	var next_fortification := V2FortificationData.next_level(city.fortification_level)
	if next_fortification > 0:
		var fort_button := Button.new()
		fort_button.name = "FortificationButton"
		fort_button.text = "Construir %s — %d PP" % [V2FortificationData.display_name(next_fortification), int(V2FortificationData.production_cost(next_fortification))]
		if city.production_item == V2FortificationData.project_id(next_fortification):
			fort_button.text += " (em progresso)"
		var fort_reason := city.fortification_unavailable_reason()
		fort_button.tooltip_text = ("Projeto local: usa a produção normal da cidade. Manutenção: %d Ouro/turno." % int(V2FortificationData.gold_upkeep(next_fortification))) if fort_reason == "" else fort_reason
		fort_button.disabled = fort_reason != "" or GameManager.is_turn_processing
		fort_button.pressed.connect(_on_fortification_pressed.bind(city, next_fortification))
		row.add_child(fort_button)
	if city.has_fortification():
		var attack_button := Button.new()
		attack_button.name = "CityAttackButton"
		var attack_reason := CityDefense.city_attack_unavailable_reason(city)
		var used := city.last_city_attack_turn == TurnManager.turn_number
		attack_button.text = "Ataque da Cidade — Usado neste turno" if used else "Ataque da Cidade"
		if attack_reason == "" and CityDefense.city_attack_targets(city, GameManager.hex_grid).is_empty():
			attack_reason = "Nenhum alvo hostil visível ao alcance."
		attack_button.tooltip_text = ("Poder %s | Alcance %d. Sem revide." % [TileInspector._format_power(CityDefense.city_attack_power(city)), CityDefense.city_attack_range(city)]) if attack_reason == "" else attack_reason
		attack_button.disabled = attack_reason != "" or GameManager.is_turn_processing
		attack_button.pressed.connect(_on_city_attack_pressed.bind(city))
		row.add_child(attack_button)

	var annex_button := Button.new()
	annex_button.name = "AnnexButton"
	annex_button.text = "Anexar território (%d)" % city.annexation_points
	annex_button.disabled = city.annexation_points <= 0 or GameManager.is_turn_processing
	annex_button.tooltip_text = "Escolha um tile de território no mapa." if city.annexation_points > 0 else "Sem Pontos de Anexação."
	annex_button.pressed.connect(_on_annex_pressed.bind(city))
	row.add_child(annex_button)

	# Fase 23 — ação estratégica paralela à fila de produção. Antes do
	# capstone a cidade não ganha ruído visual algum.
	var player := city.owner_player
	if player == GameManager.human_player and V2TranscendenceSystem.has_access(player):
		if V2TranscendenceSystem.has_active_ritual(player):
			var site := V2TranscendenceSystem.ritual_site(player)
			var rounds := V2TranscendenceSystem.ritual_rounds_remaining(player)
			var status := Label.new()
			status.name = "TranscendenceRitualStatus"
			if site == city:
				status.text = "Ritual de Transcendência — %d rodadas restantes · ATIVO" % rounds
			else:
				status.text = "Ritual ativo em %s — %d rodadas restantes." % [site.city_name if site else "outro local", rounds]
			row.add_child(status)
			if site == city:
				var cancel_button := Button.new()
				cancel_button.name = "CancelTranscendenceRitualButton"
				cancel_button.text = "Interromper Ritual"
				cancel_button.tooltip_text = "Interrompe o Ritual. O progresso e a Mana não serão devolvidos."
				cancel_button.disabled = GameManager.is_turn_processing
				cancel_button.pressed.connect(_on_cancel_transcendence_pressed.bind(player))
				row.add_child(cancel_button)
		else:
			var ritual_button := Button.new()
			ritual_button.name = "StartTranscendenceRitualButton"
			ritual_button.text = "Iniciar Ritual de Transcendência — %d Mana" % int(V2TranscendenceSystem.MANA_COST)
			var ritual_reason := V2TranscendenceSystem.start_unavailable_reason(player, city)
			ritual_button.disabled = ritual_reason != "" or GameManager.is_turn_processing
			ritual_button.tooltip_text = "Ritual Final público: dura %d rodadas e pode ser interrompido. A Mana não será devolvida." % V2TranscendenceSystem.ROUNDS_REQUIRED if ritual_reason == "" else ritual_reason
			ritual_button.pressed.connect(_on_start_transcendence_pressed.bind(player, city))
			row.add_child(ritual_button)

func _on_city_upgrade_pressed(city: City, target_level: int) -> void:
	if city == null or not is_instance_valid(city) or V2CityLevelData.next_level(city.city_level) != target_level:
		return
	if not city.can_start_city_upgrade():
		return
	city.set_production(V2CityLevelData.project_id_for_level(target_level))
	if GameManager.hex_grid:
		GameManager.hex_grid.refresh_construction_markers()
	_refresh_viewed_city()

func _on_fortification_pressed(city: City, target_level: int) -> void:
	if city == null or not is_instance_valid(city) or V2FortificationData.next_level(city.fortification_level) != target_level:
		return
	if not city.can_start_fortification():
		return
	city.set_production(V2FortificationData.project_id(target_level))
	_refresh_viewed_city()

func _on_city_attack_pressed(city: City) -> void:
	if city == null or not is_instance_valid(city):
		return
	SelectionManager.start_city_attack_targeting(city)

func _on_annex_pressed(city: City) -> void:
	if city == null or not is_instance_valid(city):
		return
	SelectionManager.start_city_annexation(city)

func _on_start_transcendence_pressed(player: PlayerData, city: City) -> void:
	if V2TranscendenceSystem.start_ritual(player, city):
		_refresh_viewed_city()
		_refresh_stats()

func _on_cancel_transcendence_pressed(player: PlayerData) -> void:
	if V2TranscendenceSystem.cancel_ritual(player):
		_refresh_viewed_city()

func _on_v2_transcendence_changed(_player: PlayerData, _site_coord: Vector2i, _remaining: int) -> void:
	_refresh_viewed_city()
	if victory_panel.visible:
		_refresh_victory_panel()

func _on_v2_transcendence_interrupted(_player: PlayerData, _site_coord: Vector2i, _reason: String) -> void:
	_refresh_viewed_city()
	if victory_panel.visible:
		_refresh_victory_panel()

## Aetherlands V2 (Fase 4): acoes de Doutrina no painel da unidade — mesmo padrao do
## SpellActions acima (um container dinamico refeito a cada selecao, sem mexer no
## HUD.tscn). Uma linha com (a) um botao por Tecnica Militar que a unidade PODE ter
## (linha da Doutrina + no concluido, ver V2TechniqueRuntime.techniques_for_unit) —
## desabilitado com o motivo no tooltip quando em recarga/sem acao — e (b) o botao
## "Evoluir para X — N Ouro" (V2UnitUpgrade) quando a civilizacao ja pesquisou a forma
## seguinte; o resto (cidade, Salao, Ouro, acao) desabilita com o motivo.
func _refresh_v2_unit_actions(unit: Unit) -> void:
	var box := unit_panel.get_node("UnitBox")
	var old := box.get_node_or_null("V2Actions")
	if old:
		box.remove_child(old)
		old.queue_free()
	if unit.owner_player == null or unit.owner_player != GameManager.human_player:
		return
	var techniques := V2TechniqueRuntime.active_techniques_for_unit(unit) # passivas não têm botão
	var target := V2UnitUpgrade.get_upgrade_target(unit)
	var show_upgrade := target != "" and V2UnlockSystem.is_unlocked(unit.owner_player, target)
	var show_improve := V2ConstructorRuntime.is_builder_unit(unit)
	var show_magic := V2MagicRuntime.is_v2_caster(unit) # Fase 17: seção "Magia — <Escola>" (repertório derivado da pesquisa)
	var show_dissolve := V2RetinueSystem.is_retinue_unit(unit) # Fase 19: só retinue ganha "Dissolver Hoste"
	var show_portal := V2PortalSystem.is_owned_endpoint(unit, GameManager.hex_grid) # Fase 21: ação explícita, nunca pathfinding
	if techniques.is_empty() and not show_upgrade and not show_improve and not show_magic and not show_dissolve and not show_portal:
		return
	var row := HFlowContainer.new()
	row.name = "V2Actions"
	box.add_child(row)
	if show_magic:
		var header := Label.new()
		header.name = "MagicHeader"
		header.text = "Magia — %s" % V2MagicContent.school_title(unit.unit_data.v2_magic_school)
		row.add_child(header)
		var spells := V2MagicRuntime.spells_for_unit(unit) # ordem N4..N7, nunca a de Dictionary
		if spells.is_empty():
			var none := Label.new()
			none.name = "MagicEmpty"
			none.text = "Nenhum feitiço pesquisado."
			row.add_child(none)
		for spell in spells:
			var spell_button := Button.new()
			spell_button.name = "Spell_" + spell.id
			spell_button.text = V2MagicRuntime.button_text(unit, spell)
			var spell_reason := V2MagicRuntime.unavailable_reason(unit, spell.id)
			var effect := V2SpellDatabase.effect_text(spell)
			var command_line := V2MagicRuntime.command_tooltip_line(unit, spell) # Fase 19: "Comando disponível: N." (só invocação)
			if command_line != "":
				effect += "\n" + command_line
			if unit.unit_data.spell_range_bonus != 0: # Fase 20: o texto do dado mostra o alcance BASE; aqui o efetivo
				effect += "\nAlcance efetivo: %d." % V2MagicRuntime.effective_range(unit, spell)
			spell_button.tooltip_text = effect if spell_reason == "" else "%s\n%s" % [effect, spell_reason]
			spell_button.disabled = spell_reason != "" or GameManager.is_turn_processing
			spell_button.pressed.connect(SelectionManager.use_v2_spell_selected.bind(spell.id))
			row.add_child(spell_button)
	if show_portal:
		var portal_button := Button.new()
		portal_button.name = "TraversePortalButton"
		var portal_reason := V2PortalSystem.traversal_reason(unit, GameManager.hex_grid)
		portal_button.text = "Atravessar Portal" if portal_reason == "" else "Atravessar Portal — %s" % portal_reason.trim_suffix(".").to_lower()
		portal_button.tooltip_text = "Teleporta esta unidade pela saída pareada e consome todo o movimento." if portal_reason == "" else portal_reason
		portal_button.disabled = portal_reason != "" or GameManager.is_turn_processing
		portal_button.pressed.connect(SelectionManager.traverse_selected_portal)
		row.add_child(portal_button)
	if show_dissolve:
		var dissolve_button := Button.new()
		dissolve_button.name = "DissolveRetinueButton"
		dissolve_button.text = "Dissolver Hoste"
		dissolve_button.tooltip_text = "Remove esta Hoste e libera sua capacidade de Comando. Não concede recompensa."
		dissolve_button.disabled = GameManager.is_turn_processing # vale mesmo SEM COMANDO (é como se libera um overload)
		dissolve_button.pressed.connect(SelectionManager.dissolve_selected_retinue)
		row.add_child(dissolve_button)
	if show_improve:
		var improve_button := Button.new()
		improve_button.name = "ImproveResourceButton"
		var tile := GameManager.hex_grid.get_tile(unit.coord) if GameManager.hex_grid else null
		var resource_id := tile.resource if tile else ""
		var improve_reason := V2ConstructorRuntime.unavailable_reason(unit, GameManager.hex_grid)
		if V2ResourceImprovementData.has_resource(resource_id):
			improve_button.text = "Construir %s" % V2ResourceImprovementData.display_name_for_resource(resource_id)
		else:
			improve_button.text = "Melhorar recurso"
		improve_button.tooltip_text = "Instantâneo: consome uma carga e a ação. Sem Ouro/Mana/Suprimentos." if improve_reason == "" else improve_reason
		improve_button.disabled = improve_reason != "" or GameManager.is_turn_processing
		improve_button.pressed.connect(SelectionManager.improve_resource_with_selected)
		row.add_child(improve_button)
	for technique in techniques:
		var button := Button.new()
		button.name = "Technique_" + technique.id
		var remaining := V2TechniqueRuntime.cooldown_remaining(unit, technique.id)
		# Técnica de ATAQUE mostra o multiplicador no próprio botão ("Golpe Poderoso ×1.6"); as demais, só o nome.
		var suffix := V2DoctrineTechniqueDatabase.button_suffix(technique)
		var label := technique.display_name if suffix == "" else "%s %s" % [technique.display_name, suffix]
		if V2TechniqueRuntime.is_active(unit, technique.id):
			button.text = "%s — Ativa" % technique.display_name
		elif remaining > 0:
			button.text = "%s (recarga %d)" % [label, remaining]
		else:
			button.text = label
		var reason := V2TechniqueRuntime.unavailable_reason(unit, technique.id)
		button.tooltip_text = technique.description if reason == "" else "%s\n%s" % [technique.description, reason]
		button.disabled = reason != "" or GameManager.is_turn_processing
		button.pressed.connect(SelectionManager.use_technique_selected.bind(technique.id))
		row.add_child(button)
	if show_upgrade:
		var upgrade_button := Button.new()
		upgrade_button.name = "UpgradeButton"
		upgrade_button.text = "Evoluir para %s — %d Ouro" % [V2UnitLine.node_for(target).display_name, int(ceil(V2UnitUpgrade.upgrade_cost(unit)))]
		var upgrade_reason := V2UnitUpgrade.unavailable_upgrade_reason(unit.owner_player, unit, GameManager.hex_grid)
		upgrade_button.tooltip_text = "Moderniza esta unidade na cidade (instantâneo; mantém veterania, HP proporcional e recargas)." if upgrade_reason == "" else upgrade_reason
		upgrade_button.disabled = upgrade_reason != "" or GameManager.is_turn_processing
		upgrade_button.pressed.connect(SelectionManager.upgrade_selected)
		row.add_child(upgrade_button)

## Recarrega o painel da unidade selecionada quando algo do MUNDO mudou o estado dela
## (virada de turno: recarga/expiracao das Tecnicas; Ouro/visao). So se o painel ja esta
## visivel (a cidade guarnecida "toma" a area, ver _on_unit_selected).
func _refresh_selected_unit_panel() -> void:
	var unit: Unit = SelectionManager.selected_unit
	if unit == null or not is_instance_valid(unit) or not unit_panel.visible or unit.hp <= 0.0:
		return
	_on_unit_selected(unit)

## Regressao: o painel de fim de jogo podia aparecer POR CIMA de um
## overlay (Pesquisa/Diplomacia/Vitória) que o jogador tivesse deixado
## aberto — _close_overlay_panels() agora roda ANTES de mostrar este, e os
## botoes que abririam outro overlay ficam desabilitados (senao dava pra
## "fechar" a tela de fim de jogo clicando em Pesquisa sem nenhum jeito
## de trazer ela de volta, ja que so o restart limpa esse estado).
func _on_game_over(victory: bool) -> void:
	# _show_overlay ja fecha qualquer overlay aberto e esconde minimapa/
	# painel de cidade/unidade/botao de turno (mesma regra dos outros
	# overlays agora) — sem precisar duplicar essa logica aqui.
	_show_overlay(game_over_panel)
	end_turn_button.disabled = true
	research_button.disabled = true
	diplomacy_button.disabled = true
	victory_button.disabled = true

	var summary = ""
	if GameManager.human_player:
		summary = "\n\nTurnos: %d | Cidades: %d | Unidades: %d | Ouro: %d" % [
			TurnManager.turn_number, GameManager.human_player.cities.size(),
			GameManager.human_player.units.size(), int(GameManager.human_player.gold)
		]

	# Roadmap "Fase F" F6 -- texto generico de proposito: um fim de jogo (Supremacia Militar,
	## Transcendência) pode nao ter eliminacao nenhuma envolvida, e este handler nao sabe QUAL
	## vitoria aconteceu (so um bool
	## human-perspective, ver EventBus.game_over) -- o veredito ESPECIFICO
	## (quem, como) fica com _on_victory_achieved logo abaixo, que roda em
	## seguida pra toda vitoria de verdade.
	if victory:
		game_over_label.text = "VITÓRIA!" + summary
	else:
		game_over_label.text = "DERROTA..." + summary
