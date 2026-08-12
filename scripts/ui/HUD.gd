extends Control

@onready var turn_label: Label = $TopBar/TopBarRow/TurnLabel
@onready var gold_label: Label = $TopBar/TopBarRow/GoldLabel
@onready var stats_label: Label = $TopBar/TopBarRow/StatsLabel
@onready var end_turn_button: Button = $TopBar/TopBarRow/EndTurnButton
@onready var help_button: Button = $TopBar/TopBarRow/HelpButton
@onready var save_button: Button = $TopBar/TopBarRow/SaveButton
@onready var pause_button: Button = $TopBar/TopBarRow/PauseButton
@onready var notification_stack: VBoxContainer = $NotificationStack
@onready var tile_info_label: Label = $TileInfoPanel/TileInfoBox/TileInfoLabel
@onready var production_scroll: ScrollContainer = $TileInfoPanel/TileInfoBox/ProductionScroll
@onready var produce_warrior_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceWarriorButton
@onready var produce_archer_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceArcherButton
@onready var produce_cavalry_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceCavalryButton
@onready var produce_settler_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceSettlerButton
@onready var produce_catapult_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceCatapultButton
@onready var produce_mage_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceMageButton
@onready var produce_griffin_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceGriffinButton
@onready var produce_treant_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/ProductionRow/ProduceTreantButton
@onready var build_granary_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/BuildingsRow/BuildGranaryButton
@onready var build_workshop_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/BuildingsRow/BuildWorkshopButton
@onready var build_market_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/BuildingsRow/BuildMarketButton
@onready var build_walls_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/BuildingsRow/BuildWallsButton
@onready var build_barracks_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildBarracksButton
@onready var build_archery_range_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildArcheryRangeButton
@onready var build_stable_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildStableButton
@onready var build_siege_workshop_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildSiegeWorkshopButton
@onready var build_arcane_tower_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildArcaneTowerButton
@onready var build_griffin_roost_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildGriffinRoostButton
@onready var build_druid_grove_button: Button = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/TrainingRow/BuildDruidGroveButton
@onready var worked_tiles_label: Label = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/WorkedTilesLabel
@onready var worked_tiles_row: HFlowContainer = $TileInfoPanel/TileInfoBox/ProductionScroll/ProductionScrollBox/WorkedTilesRow
@onready var tech_button: Button = $TopBar/TopBarRow/TechButton
@onready var tech_panel: PanelContainer = $TechPanel
@onready var tech_current_label: Label = $TechPanel/TechBox/TechCurrentLabel
@onready var tech_tree: TechTree = $TechPanel/TechBox/TechTreeScroll/TechTree
@onready var tech_close_button: Button = $TechPanel/TechBox/TechHeader/TechCloseButton
@onready var diplomacy_button: Button = $TopBar/TopBarRow/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyHeader/DiplomacyCloseButton
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_info_label: Label = $UnitPanel/UnitBox/UnitInfoLabel
@onready var found_city_button: Button = $UnitPanel/UnitBox/FoundCityButton
@onready var help_panel: PanelContainer = $HelpPanel
@onready var help_label: Label = $HelpPanel/HelpBox/HelpScroll/HelpLabel
@onready var help_close_button: Button = $HelpPanel/HelpBox/HelpHeader/HelpCloseButton
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverBox/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/GameOverBox/RestartButton
@onready var overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var debug_button: Button = $TopBar/TopBarRow/DebugButton
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
produzindo: Colonizador e Guerreiro sempre disponiveis
(Guerreiro exige so o Quartel, sem pesquisa nenhuma); as
outras tropas de combate (Arqueiro, Cavaleiro, Catapulta,
Mago, Grifo, Ent) seguem uma cadeia de tres passos:
pesquisar a tecnologia certa libera CONSTRUIR o predio de
treino correspondente (Campo de Tiro, Estabulo, Arsenal
de Cerco, Torre Arcana, Poleiro de Grifos, Bosque
Druida), e so depois de construido o predio a tropa fica
disponivel pra treinar. Botao desabilitado sempre mostra
um tooltip explicando o proximo passo (pesquisar ou
construir).
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

'Tecnologia' abre a arvore: escolha o que pesquisar
(cada cidade gera ciencia = sua populacao por turno).
Arqueiro, Cavaleiro, Catapulta e Mago comecam
bloqueados ate pesquisar a tecnologia certa; as outras
tecnologias dao bonus de rendimento em biomas
especificos.

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

func _ready() -> void:
	theme = UITheme.build()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	found_city_button.pressed.connect(_on_found_city_pressed)
	produce_warrior_button.pressed.connect(_on_produce_pressed.bind("warrior"))
	produce_archer_button.pressed.connect(_on_produce_pressed.bind("archer"))
	produce_cavalry_button.pressed.connect(_on_produce_pressed.bind("cavalry"))
	produce_settler_button.pressed.connect(_on_produce_pressed.bind("settler"))
	produce_catapult_button.pressed.connect(_on_produce_pressed.bind("catapult"))
	produce_mage_button.pressed.connect(_on_produce_pressed.bind("mage"))
	produce_griffin_button.pressed.connect(_on_produce_pressed.bind("griffin"))
	produce_treant_button.pressed.connect(_on_produce_pressed.bind("treant"))
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
	help_button.pressed.connect(_on_help_pressed)
	save_button.pressed.connect(_on_save_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	tech_button.pressed.connect(_on_tech_pressed)
	tech_close_button.pressed.connect(_on_tech_close_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
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
	production_scroll.visible = false
	worked_tiles_label.visible = false
	worked_tiles_row.visible = false
	help_panel.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false
	game_over_panel.visible = false
	debug_panel.visible = false
	overlay_backdrop.visible = false
	# So visivel rodando pelo editor/build de debug — nunca aparece pra
	# quem so joga um export de release (pedido do usuario: "opcoes
	# debug", nao um menu de trapaça pro jogador ver).
	debug_button.visible = OS.is_debug_build()
	_on_turn_changed(TurnManager.turn_number, TurnManager.current_player_index)

func _on_end_turn_pressed() -> void:
	TurnManager.end_turn()

func _on_found_city_pressed() -> void:
	SelectionManager.found_city_with_selected()

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
	game_over_panel.visible = false
	debug_panel.visible = false
	overlay_backdrop.visible = false

## Fecha qualquer outro overlay (regra de "so um por vez" acima) e mostra
## o pedido, com o fundo escurecido pra deixar claro que o resto da tela
## esta desativado enquanto ele estiver aberto.
func _show_overlay(panel: Control) -> void:
	_close_overlay_panels()
	overlay_backdrop.visible = true
	panel.visible = true

## Usado pelo menu de pausa (PauseMenu._unhandled_input): ESC deveria
## fechar um overlay da HUD que estiver aberto ANTES de abrir o menu de
## pausa por cima dele — sem isso, ESC abria a pausa em cima do painel
## ainda visivel por baixo (o mesmo tipo de sobreposicao reportado pelo
## usuario). Devolve true se fechou algo, pra quem chamou saber que ja
## "consumiu" o ESC e nao precisa mais abrir a pausa.
func close_topmost_overlay() -> bool:
	if help_panel.visible or tech_panel.visible or diplomacy_panel.visible or debug_panel.visible:
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
	gold_label.text = "Ouro: %d" % int(GameManager.human_player.gold)

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
	help_button.disabled = false
	debug_button.disabled = false
	unit_panel.visible = false
	production_scroll.visible = false
	worked_tiles_label.visible = false
	worked_tiles_row.visible = false
	_viewed_city = null
	tile_info_label.text = "Selecione um tile"
	for child in notification_stack.get_children():
		child.queue_free()
	_on_turn_changed(TurnManager.turn_number, TurnManager.current_player_index)

func _on_turn_changed(turn_number: int, _player_index: int) -> void:
	turn_label.text = "Turno %d" % turn_number
	if GameManager.human_player:
		gold_label.text = "Ouro: %d" % int(GameManager.human_player.gold)
	_refresh_stats()
	if tech_panel.visible:
		_refresh_tech_panel()
	if diplomacy_panel.visible:
		_refresh_diplomacy_panel()
	# Regressao: o painel da cidade so se atualizava ao clicar de novo no
	# tile (_on_produce_pressed/_on_worked_tile_pressed chamavam isso, mas
	# _on_turn_changed nao) — produzir um predio parecia "nao fazer nada"
	# pro jogador, porque progresso/predio concluido nunca aparecia sem
	# reclicar a cidade manualmente.
	_refresh_viewed_city()

func _refresh_stats() -> void:
	var player = GameManager.human_player
	if player:
		stats_label.text = "Cidades: %d | Unidades: %d" % [player.cities.size(), player.units.size()]

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
		tile_info_label.text = "Selecione um tile"
		production_scroll.visible = false
		worked_tiles_label.visible = false
		worked_tiles_row.visible = false
		return

	var text = "%s (%d, %d)\nComida %d | Producao %d | Ouro %d" % [
		data.display_name, coord.x, coord.y, data.food_yield, data.production_yield, data.gold_yield
	]
	if data.resource != "":
		text += "\nRecurso: %s" % ResourceDatabase.display_name(data.resource)

	var hex_grid = GameManager.hex_grid
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
		var guardian = hex_grid.get_unit_at(coord)
		if guardian and guardian.owner_player == null:
			text += "\n\nCovil de Monstro: %s (HP %d/%d)\nRecompensa: %d ouro" % [
				guardian.unit_data.unit_name, int(guardian.hp), int(guardian.unit_data.max_hp),
				int(guardian.unit_data.gold_reward)
			]

	tile_info_label.text = text
	production_scroll.visible = _viewed_city != null
	if _viewed_city:
		# Guerreiro nao exige tecnologia (sempre foi de graca), mas agora
		# exige o Quartel construido, ver City.can_train() — as outras
		# tropas de combate exigem AS DUAS coisas (pesquisa E predio).
		produce_warrior_button.disabled = not _viewed_city.can_train("warrior")
		produce_archer_button.disabled = not GameManager.human_player.has_unlocked("archer") or not _viewed_city.can_train("archer")
		produce_cavalry_button.disabled = not GameManager.human_player.has_unlocked("cavalry") or not _viewed_city.can_train("cavalry")
		produce_catapult_button.disabled = not GameManager.human_player.has_unlocked("catapult") or not _viewed_city.can_train("catapult")
		produce_mage_button.disabled = not GameManager.human_player.has_unlocked("mage") or not _viewed_city.can_train("mage")
		produce_griffin_button.disabled = not GameManager.human_player.has_unlocked("griffin") or not _viewed_city.can_train("griffin")
		produce_treant_button.disabled = not GameManager.human_player.has_unlocked("treant") or not _viewed_city.can_train("treant")
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
		_update_production_tooltips()
		_update_building_tooltips()
	_refresh_worked_tiles_row()

const TRAINABLE_KINDS := ["warrior", "archer", "cavalry", "catapult", "mage", "griffin", "treant"]
const BUILDING_IDS := [
	"granary", "workshop", "market", "walls",
	"barracks", "archery_range", "stable", "siege_workshop", "arcane_tower", "griffin_roost", "druid_grove",
]

func _produce_button_for(kind: String) -> Button:
	match kind:
		"warrior": return produce_warrior_button
		"archer": return produce_archer_button
		"cavalry": return produce_cavalry_button
		"catapult": return produce_catapult_button
		"mage": return produce_mage_button
		"griffin": return produce_griffin_button
		"treant": return produce_treant_button
	return null

## Um botao desabilitado sem explicacao nenhuma foi exatamente o bug que o
## usuario reportou antes ("parece nao fazer nada") — aqui o motivo (falta
## pesquisa ou falta o predio de treino) fica no tooltip em vez do jogador
## ter que adivinhar.
func _update_production_tooltips() -> void:
	for kind in TRAINABLE_KINDS:
		_produce_button_for(kind).tooltip_text = _production_lock_reason(kind)

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
	return ""

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
	return ""

## Um botao por vizinho valido (nem oceano) da cidade vista, mostrando
## terreno + rendimento; toggle_mode reflete se aquele cidadao ja esta
## trabalhando ali. So aparece pra cidade PROPRIA (mesma regra do
## production_scroll) — nao da pra microgerenciar cidade alheia.
func _refresh_worked_tiles_row() -> void:
	for child in worked_tiles_row.get_children():
		child.queue_free()

	if _viewed_city == null:
		worked_tiles_label.visible = false
		worked_tiles_row.visible = false
		return

	var hex_grid = GameManager.hex_grid
	worked_tiles_label.visible = true
	worked_tiles_row.visible = true
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
		# a cidade rende mais do que os numeros aqui sugerem.
		var y = _viewed_city.effective_tile_yield(data)
		btn.text = "%s\nF%d P%d G%d" % [label, y.food, y.production, y.gold]
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
	unit_info_label.text = text
	found_city_button.visible = unit.unit_data.can_found_city

## Regressao: o painel de fim de jogo podia aparecer POR CIMA de um
## overlay (Tecnologia/Diplomacia/Ajuda) que o jogador tivesse deixado
## aberto — _close_overlay_panels() agora roda ANTES de mostrar este, e os
## botoes que abririam outro overlay ficam desabilitados (senao dava pra
## "fechar" a tela de fim de jogo clicando em Tecnologia sem nenhum jeito
## de trazer ela de volta, ja que so o restart limpa esse estado).
func _on_game_over(victory: bool) -> void:
	_close_overlay_panels()
	end_turn_button.disabled = true
	tech_button.disabled = true
	diplomacy_button.disabled = true
	help_button.disabled = true
	debug_button.disabled = true
	overlay_backdrop.visible = true
	game_over_panel.visible = true

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
