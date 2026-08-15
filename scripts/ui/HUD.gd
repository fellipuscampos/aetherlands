extends Control

## Contador de FPS (pedido do usuario: "coloque o fps na tela") — pequeno,
## fora da barra superior (que ja fica cheia de indicadores de jogo) e sem
## bloquear clique nenhum no mapa (ver mouse_filter no .tscn). Atualizado
## todo frame em _process(), unica razao de HUD ter um agora.
@onready var fps_label: Label = $FpsLabel

## Barra superior: DUAS secoes visuais separadas por um Spacer expansivel
## (pedido do usuario — "elimine a sensacao de desordem visual"): StatusGroup
## (indicadores do imperio, so leitura) a esquerda, NavGroup (botoes de
## navegacao) a direita, num grupo coeso em vez de misturados.
@onready var turn_label: Label = $TopBar/TopBarRow/StatusGroup/TurnLabel
@onready var gold_label: Label = $TopBar/TopBarRow/StatusGroup/GoldLabel
@onready var mana_label: Label = $TopBar/TopBarRow/StatusGroup/ManaLabel
@onready var stats_label: Label = $TopBar/TopBarRow/StatusGroup/StatsLabel
## Finalizar Turno mora na PONTA DIREITA da barra superior (pedido do
## usuario: reorganizar a HUD "parecido com os de civilization 6" — la o
## botao de proximo turno fica sempre no canto superior direito, nao
## flutuando separado no rodape) — continua com borda dourada de destaque
## + atalho Espaco/Enter (ver _style_end_turn_button()), so a POSICAO
## mudou.
@onready var end_turn_button: Button = $TopBar/TopBarRow/EndTurnButton
@onready var help_button: Button = $TopBar/TopBarRow/NavGroup/HelpButton
@onready var save_button: Button = $TopBar/TopBarRow/NavGroup/SaveButton
@onready var pause_button: Button = $TopBar/TopBarRow/NavGroup/PauseButton
@onready var notification_stack: VBoxContainer = $NotificationStack
@onready var minimap: Control = $Minimap
@onready var tile_info_panel: PanelContainer = $TileInfoPanel
@onready var tile_info_label: Label = $TileInfoPanel/TileInfoBox/TileInfoLabel
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
@onready var tech_button: Button = $TopBar/TopBarRow/NavGroup/TechButton
@onready var tech_panel: PanelContainer = $TechPanel
@onready var tech_current_label: Label = $TechPanel/TechBox/TechCurrentLabel
@onready var tech_tree: TechTree = $TechPanel/TechBox/TechTreeScroll/TechTree
@onready var tech_close_button: Button = $TechPanel/TechBox/TechHeader/TechCloseButton
@onready var diplomacy_button: Button = $TopBar/TopBarRow/NavGroup/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyHeader/DiplomacyCloseButton
@onready var grimoire_button: Button = $TopBar/TopBarRow/NavGroup/GrimoireButton
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
@onready var found_city_button: Button = $UnitPanel/UnitBox/FoundCityButton
@onready var help_panel: PanelContainer = $HelpPanel
@onready var help_label: Label = $HelpPanel/HelpBox/HelpScroll/HelpLabel
@onready var help_close_button: Button = $HelpPanel/HelpBox/HelpHeader/HelpCloseButton
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverBox/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/GameOverBox/RestartButton
@onready var overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var debug_button: Button = $TopBar/TopBarRow/NavGroup/DebugButton
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_close_button: Button = $DebugPanel/DebugBox/DebugHeader/DebugCloseButton
@onready var debug_reveal_map_button: Button = $DebugPanel/DebugBox/DebugRevealMapButton
@onready var debug_gold_button: Button = $DebugPanel/DebugBox/DebugGoldButton
@onready var debug_complete_research_button: Button = $DebugPanel/DebugBox/DebugCompleteResearchButton
@onready var debug_win_button: Button = $DebugPanel/DebugBox/DebugWinButton
@onready var debug_lose_button: Button = $DebugPanel/DebugBox/DebugLoseButton

const HELP_TEXT := """W A S D ou setas: mover a camera
Q / E: rotacionar a camera
Scroll do mouse: zoom

Clique numa unidade sua para selecionar.
Tile verde: mover ate la. Tile vermelho: atacar
(ou capturar cidade inimiga sem defensor). Cada tipo
de unidade tem alcance/movimento diferentes — confira
no painel da unidade. Unidade que vence combates ganha
abates e sobe de nivel (Recruta -> Veterano -> Elite ->
Lendario), com bonus permanente de ataque/defesa e uma
cura na hora da promocao.
Passe o mouse pra ver o trajeto e o custo antes de
clicar. Barra de vida aparece sobre a unidade assim
que ela leva dano.

Colonizador selecionado: 'Fundar Cidade' cria uma
cidade no tile atual (consome o colonizador).

Clique numa cidade sua para escolher o que ela esta
produzindo: Colonizador, Guerreiro, Arqueiro e Cavaleiro
sempre disponiveis (Guerreiro exige so o Quartel, sem
pesquisa nenhuma); as tropas MAGICAS (Mago, Ent, Golem de
Pedra, Grifo, Convocador de Sombras, Catapulta Cadenciada)
seguem uma cadeia de tres passos: pesquisar a tecnologia
certa libera CONSTRUIR o predio de treino correspondente,
e so depois de construido o predio a tropa fica disponivel
pra treinar. Botao desabilitado sempre mostra um tooltip
explicando o proximo passo (pesquisar ou construir).
Predios de PRODUCAO (uma vez so por cidade, dura pra
sempre): Celeiro (+comida), Oficina (+producao), Mercado
(+ouro) ou Muralhas (+defesa pra quem estiver
guarnicionado ali, Mago ignora esse bonus tambem).
Numero total de predios (producao + treino) e limitado
pela populacao da cidade (1 predio por ponto de
populacao) — cidade precisa crescer pra caber mais.
O territorio da cidade (ela mesma + vizinhos) fica
destacado em dourado no mapa enquanto ela esta
selecionada. Ao escolher um predio, clique num tile
azul pra posiciona-lo, do mesmo jeito que escolhe onde
fundar uma cidade — o modelo so aparece no mapa quando
a construcao terminar.
Cada ponto de populacao trabalha um tile vizinho —
clique nos botoes de "Tiles trabalhados" pra escolher
quais (a cidade sugere automaticamente, mas voce pode
trocar); tiles com recurso (Ferro, Cavalos, Gemas,
Seda) dao rendimento extra.

'Finalizar Turno' avanca o jogo: unidades recuperam
movimento, cidades crescem/produzem, e os reinos
rivais agem.

'Tecnologia' abre a arvore magica: escolha o que
pesquisar (cada cidade gera ciencia = sua populacao por
turno). Mago, Ent, Golem de Pedra, Grifo, Convocador de
Sombras e Catapulta Cadenciada comecam bloqueados ate
pesquisar a tecnologia certa; as outras tecnologias dao
bonus de rendimento em biomas especificos ou um ritual
novo pro Grimorio.

'Grimório' mostra os rituais ja desbloqueados (Lança de
Arcana, Reanimar...). Cada um custa MANA (numero ao lado
do nome) alem de ter sua propria recarga em turnos — os
dois precisam estar prontos pro botao 'Conjurar' ficar
disponivel. Mana renova todo turno (Nódulo Arcano
trabalhado + predios como a Torre dos Sábios, mostrado na
barra superior como "Mana: X (+Y)"). 'Conjurar' entra em
modo de mira: o proximo clique no mapa escolhe o alvo
(uma unidade inimiga visivel, ou uma sua, dependendo do
feitico).

'Diplomacia' mostra cada reino rival e se voce esta em
guerra ou paz com ele. 'Propor Paz' pode ser recusado
(a IA aceita se estiver em desvantagem numerica);
'Declarar Guerra' e sempre imediato. Em paz, nao da
pra atacar nem ser atacado por aquele reino.

Espalhados pelo mapa, longe do centro, existem Covis
de Monstro guardados por Goblins, Trolls ou Viverns —
hostis a todo mundo, sem diplomacia possivel. Vencer o
guardiao saqueia ouro na hora; perder pode custar a
unidade que atacou. Risco alto, recompensa alta.

'Salvar' grava a partida atual. 'Menu' (ou tecla Esc)
pausa o jogo e abre um menu pra salvar, carregar outra
partida ou voltar ao menu principal sem fechar o jogo.

Vitoria: eliminar todas as unidades e cidades de TODOS
os reinos rivais. Derrota: perder todas as suas."""

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
	help_button.pressed.connect(_on_help_pressed)
	save_button.pressed.connect(_on_save_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	tech_button.pressed.connect(_on_tech_pressed)
	tech_close_button.pressed.connect(_on_tech_close_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
	grimoire_button.pressed.connect(_on_grimoire_pressed)
	grimoire_close_button.pressed.connect(_on_grimoire_close_pressed)
	help_close_button.pressed.connect(_on_help_close_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	debug_close_button.pressed.connect(_on_debug_close_pressed)
	debug_reveal_map_button.pressed.connect(_on_debug_reveal_map_pressed)
	debug_gold_button.pressed.connect(_on_debug_gold_pressed)
	debug_complete_research_button.pressed.connect(_on_debug_complete_research_pressed)
	debug_win_button.pressed.connect(_on_debug_win_pressed)
	debug_lose_button.pressed.connect(_on_debug_lose_pressed)
	tech_tree.tech_selected.connect(_on_tech_selected)
	TurnManager.turn_changed.connect(_on_turn_changed)
	EventBus.tile_selected.connect(_on_tile_selected)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.game_over.connect(_on_game_over)
	EventBus.notify.connect(_on_notify)
	# fog_updated dispara ao fim de start_new_game/recompute_fog — cobre o
	# caso do primeiro turno, onde turn_changed ainda nao foi emitido.
	EventBus.fog_updated.connect(_refresh_stats)

	help_label.text = HELP_TEXT
	unit_panel.visible = false
	production_tabs.visible = false
	worked_tiles_label.visible = false
	worked_tiles_scroll.visible = false
	help_panel.visible = false
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

## Alterna o painel entre COMPACTO (so texto do tile, canto inferior
## direito, altura fixa pequena) e EXPANDIDO (cidade selecionada, ocupa a
## lateral direita inteira da tela pra caber a grade de producao) — so a
## borda de CIMA se move; a borda de baixo fica sempre a 16px do rodape,
## entao o painel sempre "cresce pra cima" a partir do mesmo canto, nunca
## muda de lado.
func _update_tile_info_panel_size(expanded: bool) -> void:
	if expanded:
		tile_info_panel.anchor_top = 0.0
		tile_info_panel.offset_top = TILE_INFO_PANEL_TOP_MARGIN
	else:
		tile_info_panel.anchor_top = 1.0
		tile_info_panel.offset_top = -TILE_INFO_PANEL_COMPACT_HEIGHT

## Mostra o custo de producao de cada predio no proprio botao (pedido do
## usuario: "cards compactos com custo de producao/tempo") — os nomes
## crus (ex: "Celeiro") ja vem do .tscn, aqui so acrescenta o custo lido
## de BuildingDatabase, uma unica fonte de verdade (sem duplicar numero
## nenhum a mao no texto do node).
func _label_building_buttons() -> void:
	for id in BUILDING_IDS:
		var building: BuildingData = BuildingDatabase.get_building(id)
		var btn := _build_button_for(id)
		btn.text = "%s  —  %d PP" % [building.display_name, int(building.production_cost)]

## Atalho de teclado pedido pelo usuario ("Espaço ou Enter") pro botao de
## acao principal — "ui_accept" e a acao embutida do proprio Godot pra
## Enter/Kp Enter/Espaco, os tres juntos, sem precisar mexer no input map
## do projeto. So dispara em PLAYING (nao durante fim de jogo) e nunca com
## um overlay aberto (Tecnologia/Diplomacia/Grimorio/Ajuda/Debug) — o
## backdrop escurecido ja bloqueia CLIQUE nesses casos, mas o teclado
## ignora ele, entao a checagem tem que ser explicita aqui.
func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

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
		# Predio precisa de um tile escolhido no mapa (como fundar cidade) —
		# a producao so comeca de fato quando o jogador clica um tile valido
		# (SelectionManager._handle_building_placement_click).
		SelectionManager.start_building_placement(_viewed_city, kind)
		return
	if not _viewed_city.can_train(kind):
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

func _on_save_pressed() -> void:
	if SaveManager.save_game(GameManager.hex_grid):
		EventBus.notify.emit("Jogo salvo.", "confirm")
	else:
		EventBus.notify.emit("Falha ao salvar o jogo.", "")

func _on_pause_pressed() -> void:
	EventBus.pause_requested.emit()

## Ajuda/Tecnologia/Diplomacia/Debug/FimDeJogo sao todos paineis
## centralizados na mesma posicao — sem isso, abrir um por cima do outro
## (ou o jogo acabar com um deles aberto) deixava tudo empilhado e
## ilegivel. So um fica visivel por vez, e o backdrop escurecido some
## junto (ver _show_overlay).
func _close_overlay_panels() -> void:
	help_panel.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false
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
	if help_panel.visible or tech_panel.visible or diplomacy_panel.visible or grimoire_panel.visible or debug_panel.visible:
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

## Mostra a pesquisa atual (com progresso) e a arvore inteira — cada
## tecnologia como um card colorido por estado (TechTree.gd cuida do
## layout/desenho; aqui so repassa os dados atuais do jogador).
func _refresh_tech_panel() -> void:
	var player = GameManager.human_player
	if player == null:
		return

	if player.current_research != "":
		var tech: TechData = TechDatabase.get_tech(player.current_research)
		tech_current_label.text = "Pesquisando: %s (%d/%d ciencia)" % [
			tech.display_name, int(player.research_progress), int(tech.cost)
		]
	else:
		tech_current_label.text = "Pesquisando: nenhuma, escolha um card disponivel abaixo"

	tech_tree.rebuild(player.researched_techs, player.current_research, player.research_progress)

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
	name_label.text = "%s (%d mana)" % [spell_name, spell.mana_cost] if spell else spell_name
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
	elif not SpellManager.has_enough_mana(human, spell_name):
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
	debug_reveal_map_button.button_pressed = fog_disabled
	debug_reveal_map_button.text = "Restaurar Neblina" if fog_disabled else "Revelar Mapa (sem neblina)"
	debug_complete_research_button.disabled = GameManager.human_player == null or GameManager.human_player.current_research == ""

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

func _on_help_pressed() -> void:
	if help_panel.visible:
		_close_overlay_panels()
		return
	_show_overlay(help_panel)

func _on_help_close_pressed() -> void:
	_close_overlay_panels()

## Emite o pedido de reinicio (Main.gd regenera mapa/jogo de forma sincrona
## nesse mesmo emit) e so entao atualiza a propria HUD com o estado novo.
func _on_restart_pressed() -> void:
	EventBus.restart_requested.emit()
	_close_overlay_panels()
	end_turn_button.disabled = false
	tech_button.disabled = false
	diplomacy_button.disabled = false
	grimoire_button.disabled = false
	help_button.disabled = false
	debug_button.disabled = false
	unit_panel.visible = false
	production_tabs.visible = false
	worked_tiles_label.visible = false
	worked_tiles_scroll.visible = false
	_viewed_city = null
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
	tech_button.text = "%s (%d%%)" % [tech.display_name, pct]

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
	if data == null:
		# Sem tile selecionado, sem painel — antes ficava sempre visivel so
		# com o texto "Selecione um tile", cobrindo boa parte da tela a toa
		# (pedido do usuario).
		tile_info_panel.visible = false
		tile_info_label.text = "Selecione um tile"
		production_tabs.visible = false
		worked_tiles_label.visible = false
		worked_tiles_scroll.visible = false
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
		return

	tile_info_panel.visible = true

	var text = "%s (%d, %d)\nComida %d | Producao %d | Ouro %d" % [
		data.display_name, coord.x, coord.y, data.food_yield, data.production_yield, data.gold_yield
	]
	if data.resource != "":
		text += "\nRecurso: %s" % ResourceDatabase.display_name(data.resource)

	if hex_grid:
		var city = hex_grid.get_city_at(coord)
		if city:
			var building_in_progress: BuildingData = BuildingDatabase.get_building(city.production_item)
			var item_label = building_in_progress.display_name if building_in_progress else UnitDatabase.create_unit(city.production_item).unit_name
			text += "\n\n%s\nPopulacao: %d\nProduzindo: %s (%d/%d)" % [
				city.city_name, city.population, item_label,
				int(city.stored_production), int(city.production_cost())
			]
			var built_names: Array[String] = []
			for id in city.buildings.keys():
				var b: BuildingData = BuildingDatabase.get_building(id)
				if b:
					built_names.append(b.display_name)
			# Sempre mostra o limite (mesmo com 0 predios ainda) — senao o
			# jogador so descobre que ha um teto quando ja esbarra nele.
			text += "\nPredios: %d/%d" % [city.buildings.size(), city.max_building_slots()]
			if built_names.size() > 0:
				text += " (%s)" % ", ".join(built_names)
			if city.owner_player == GameManager.human_player:
				_viewed_city = city

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
		# Guerreiro/Colonizador nao exigem tecnologia (sempre foram de
		# graca), mas Guerreiro exige o Quartel construido, ver City.
		# can_train() — as outras tropas de combate exigem AS DUAS coisas
		# (pesquisa E predio). has_unlocked()/can_train() ja sao fail-open
		# pra kind sem tech/predio associado, entao o mesmo par de checagem
		# funciona pra QUALQUER kind do roster, sem caso especial nenhum.
		var player_race: String = GameManager.human_player.civ.race if GameManager.human_player.civ else ""
		for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
			# Tropa racial de OUTRA raca (ex: jogador Anao olhando o botao
			# do Patrulheiro Elfico) fica ESCONDIDA, nao so desabilitada —
			# ela nunca vai ficar disponivel pra essa partida, entao mostrar
			# desabilitada seria so ruido permanente pro jogador (pedido do
			# usuario: escolher raca precisa de implicacao real, e isso
			# inclui a propria producao so mostrar o que faz sentido).
			var owner_race: String = UnitDatabase.race_for_unique_kind(kind)
			_production_buttons[kind].visible = owner_race == "" or owner_race == player_race
			_production_buttons[kind].disabled = not GameManager.human_player.has_unlocked(kind) or not _viewed_city.can_train(kind)
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
		var unit := UnitDatabase.create_unit(kind)
		btn.text = "%s  —  %d PP" % [unit.unit_name, int(unit.production_cost)]
		btn.custom_minimum_size = Vector2(150, 0)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.pressed.connect(_on_produce_pressed.bind(kind))
		production_row.add_child(btn)
		_production_buttons[kind] = btn

## Um botao desabilitado sem explicacao nenhuma foi exatamente o bug que o
## usuario reportou antes ("parece nao fazer nada") — aqui o motivo (falta
## pesquisa ou falta o predio de treino) fica no tooltip em vez do jogador
## ter que adivinhar.
func _update_production_tooltips() -> void:
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		_production_buttons[kind].tooltip_text = _production_lock_reason(kind)

## "" quando o item ja esta liberado. Falta de tecnologia tem prioridade
## sobre falta de predio na mensagem (pesquisar primeiro sempre resolve
## os dois passos, o predio sozinho nao adianta sem a tecnologia).
func _production_lock_reason(kind: String) -> String:
	if not GameManager.human_player.has_unlocked(kind):
		var tech: TechData = TechDatabase.tech_that_unlocks(kind)
		return "Requer pesquisar: %s" % tech.display_name if tech else ""
	if not _viewed_city.can_train(kind):
		var building: BuildingData = BuildingDatabase.building_that_trains(kind)
		return "Requer: %s" % building.display_name if building else ""
	return _estimated_turns_tooltip(UnitDatabase.create_unit(kind).production_cost)

## "custo de producao/tempo" no card (pedido do usuario) — o NOME/custo
## cru ja aparece no texto do botao (ver _build_production_buttons), aqui
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
	for id in BUILDING_IDS:
		_build_button_for(id).tooltip_text = _building_lock_reason(id)

## "" quando o predio ja esta liberado pra construir. Predio de treino
## (Quartel em diante) exige a mesma tecnologia que desbloqueia a tropa
## correspondente (City._tech_unlocked_for_building) — pedido do usuario:
## "so posso construir esses predios especiais quando pesquisar a
## tecnologia, ai aparece disponivel pra construir". Falta de tecnologia
## tem prioridade sobre limite de slots na mensagem (pesquisar primeiro e
## sempre o proximo passo, crescer a cidade nao adianta sem a pesquisa).
func _building_lock_reason(id: String) -> String:
	if _viewed_city.buildings.has(id):
		return ""
	var building: BuildingData = BuildingDatabase.get_building(id)
	var tech: TechData = TechDatabase.tech_that_unlocks(building.trains_unit) if building else null
	if tech and not GameManager.human_player.researched_techs.has(tech.id):
		return "Requer pesquisar: %s" % tech.display_name
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

func _on_unit_selected(unit: Unit) -> void:
	if unit == null:
		unit_panel.visible = false
		return
	unit_panel.visible = true
	var text = "%s (%s)\nHP %d/%d | Movimento %.1f/%.1f" % [
		unit.unit_data.unit_name, unit.veterancy_title(), int(unit.hp), int(unit.unit_data.max_hp),
		unit.movement_left, unit.unit_data.movement_points
	]
	if unit.unit_data.attack_range > 1:
		text += "\nAlcance de ataque: %d" % unit.unit_data.attack_range
	if unit.veterancy_level > 0:
		text += "\n+%d%% ataque/defesa (%d abates)" % [int(unit.veterancy_level * Unit.VETERANCY_BONUS_PER_LEVEL * 100), unit.kills]
	if unit.fortified:
		text += "\nFortificada (+%d%% defesa, cura passiva)" % int(CombatResolver.FORTIFY_DEFENSE_BONUS * 100)
	elif unit.exploring:
		text += "\nExplorando automaticamente"
	elif unit.move_order_target != Unit.NO_MOVE_ORDER:
		text += "\nEm marcha ate (%d, %d)" % [unit.move_order_target.x, unit.move_order_target.y]
	if SelectionManager.move_mode:
		text += "\n» Clique no mapa pra mover «"
	unit_info_label.text = text
	found_city_button.visible = unit.unit_data.can_found_city
	# Fortificar/Explorar sao alternancias (toggle_mode, ver HUD.tscn) —
	# button_pressed precisa refletir o estado REAL da unidade toda vez
	# que a selecao (ou o proprio estado) muda, senao o botao mostraria
	# "nao pressionado" pra uma unidade ja fortificada so por ter sido
	# reselecionada.
	fortify_button.button_pressed = unit.fortified
	explore_button.button_pressed = unit.exploring

## Regressao: o painel de fim de jogo podia aparecer POR CIMA de um
## overlay (Tecnologia/Diplomacia/Ajuda) que o jogador tivesse deixado
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
	grimoire_button.disabled = true
	help_button.disabled = true
	debug_button.disabled = true

	var summary = ""
	if GameManager.human_player:
		summary = "\n\nTurnos: %d | Cidades: %d | Unidades: %d | Ouro: %d" % [
			TurnManager.turn_number, GameManager.human_player.cities.size(),
			GameManager.human_player.units.size(), int(GameManager.human_player.gold)
		]

	if victory:
		game_over_label.text = "VITORIA!\nTodos os reinos rivais foram derrotados." + summary
	else:
		game_over_label.text = "DERROTA...\nSeu reino caiu." + summary
