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
@onready var production_row: HFlowContainer = $TileInfoPanel/TileInfoBox/ProductionRow
@onready var produce_warrior_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceWarriorButton
@onready var produce_archer_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceArcherButton
@onready var produce_cavalry_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceCavalryButton
@onready var produce_settler_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceSettlerButton
@onready var produce_catapult_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceCatapultButton
@onready var produce_mage_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceMageButton
@onready var produce_griffin_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceGriffinButton
@onready var produce_treant_button: Button = $TileInfoPanel/TileInfoBox/ProductionRow/ProduceTreantButton
@onready var buildings_row: HFlowContainer = $TileInfoPanel/TileInfoBox/BuildingsRow
@onready var build_granary_button: Button = $TileInfoPanel/TileInfoBox/BuildingsRow/BuildGranaryButton
@onready var build_workshop_button: Button = $TileInfoPanel/TileInfoBox/BuildingsRow/BuildWorkshopButton
@onready var build_market_button: Button = $TileInfoPanel/TileInfoBox/BuildingsRow/BuildMarketButton
@onready var build_walls_button: Button = $TileInfoPanel/TileInfoBox/BuildingsRow/BuildWallsButton
@onready var worked_tiles_label: Label = $TileInfoPanel/TileInfoBox/WorkedTilesLabel
@onready var worked_tiles_row: HFlowContainer = $TileInfoPanel/TileInfoBox/WorkedTilesRow
@onready var tech_button: Button = $TopBar/TopBarRow/TechButton
@onready var tech_panel: PanelContainer = $TechPanel
@onready var tech_current_label: Label = $TechPanel/TechBox/TechCurrentLabel
@onready var tech_available_row: HFlowContainer = $TechPanel/TechBox/TechAvailableRow
@onready var tech_researched_label: Label = $TechPanel/TechBox/TechResearchedLabel
@onready var tech_close_button: Button = $TechPanel/TechBox/TechCloseButton
@onready var diplomacy_button: Button = $TopBar/TopBarRow/DiplomacyButton
@onready var diplomacy_panel: PanelContainer = $DiplomacyPanel
@onready var diplomacy_rows: VBoxContainer = $DiplomacyPanel/DiplomacyBox/DiplomacyRows
@onready var diplomacy_close_button: Button = $DiplomacyPanel/DiplomacyBox/DiplomacyCloseButton
@onready var unit_panel: PanelContainer = $UnitPanel
@onready var unit_info_label: Label = $UnitPanel/UnitBox/UnitInfoLabel
@onready var found_city_button: Button = $UnitPanel/UnitBox/FoundCityButton
@onready var help_panel: PanelContainer = $HelpPanel
@onready var help_label: Label = $HelpPanel/HelpBox/HelpLabel
@onready var help_close_button: Button = $HelpPanel/HelpBox/HelpCloseButton
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverBox/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/GameOverBox/RestartButton

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
produzindo: Guerreiro, Arqueiro, Cavaleiro, Catapulta
(cerco, ataque forte mas lenta), Mago (ataque magico
que ignora bonus de defesa de terreno), Grifo (voa por
cima de qualquer terreno e ATRAVESSA OCEANO, ignorando
custo de movimento), Ent (lento mas se regenera sozinho
todo turno, em qualquer lugar do mapa) ou Colonizador —
ou um predio (uma vez so por cidade, dura pra sempre):
Celeiro (+comida), Oficina (+producao), Mercado (+ouro)
ou Muralhas (+defesa pra quem estiver guarnicionado ali,
Mago ignora esse bonus tambem). Numero de predios e
limitado pela populacao da cidade (1 predio por ponto
de populacao) — cidade precisa crescer pra caber mais.
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
	help_button.pressed.connect(_on_help_pressed)
	save_button.pressed.connect(_on_save_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	tech_button.pressed.connect(_on_tech_pressed)
	tech_close_button.pressed.connect(_on_tech_close_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_pressed)
	diplomacy_close_button.pressed.connect(_on_diplomacy_close_pressed)
	help_close_button.pressed.connect(_on_help_close_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
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
	production_row.visible = false
	buildings_row.visible = false
	worked_tiles_label.visible = false
	worked_tiles_row.visible = false
	help_panel.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false
	game_over_panel.visible = false
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
	_viewed_city.set_production(kind)
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

## Ajuda/Tecnologia/Diplomacia sao todos paineis centralizados na mesma
## posicao — sem isso, abrir um por cima do outro deixava tudo empilhado e
## ilegivel. So um fica visivel por vez.
func _close_overlay_panels() -> void:
	help_panel.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false

func _on_tech_pressed() -> void:
	var opening = not tech_panel.visible
	_close_overlay_panels()
	tech_panel.visible = opening
	if tech_panel.visible:
		_refresh_tech_panel()

func _on_tech_close_pressed() -> void:
	tech_panel.visible = false

## Mostra a pesquisa atual (com progresso), botoes pra escolher entre as
## tecnologias disponiveis agora (pre-requisitos cumpridos) e a lista das
## ja pesquisadas.
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
		tech_current_label.text = "Pesquisando: nenhuma — escolha abaixo"

	for child in tech_available_row.get_children():
		child.queue_free()
	for tech in TechDatabase.available_techs(player.researched_techs):
		var btn := Button.new()
		btn.text = "%s (%d)" % [tech.display_name, int(tech.cost)]
		btn.disabled = tech.id == player.current_research
		btn.pressed.connect(_on_tech_selected.bind(tech.id))
		tech_available_row.add_child(btn)

	var names: Array[String] = []
	for id in player.researched_techs.keys():
		var t: TechData = TechDatabase.get_tech(id)
		if t:
			names.append(t.display_name)
	tech_researched_label.text = "Pesquisadas: %s" % (", ".join(names) if names.size() > 0 else "nenhuma")

func _on_tech_selected(id: String) -> void:
	GameManager.human_player.current_research = id
	_refresh_tech_panel()

func _on_diplomacy_pressed() -> void:
	var opening = not diplomacy_panel.visible
	_close_overlay_panels()
	diplomacy_panel.visible = opening
	if diplomacy_panel.visible:
		_refresh_diplomacy_panel()

func _on_diplomacy_close_pressed() -> void:
	diplomacy_panel.visible = false

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

func _on_help_pressed() -> void:
	var opening = not help_panel.visible
	_close_overlay_panels()
	help_panel.visible = opening

func _on_help_close_pressed() -> void:
	help_panel.visible = false

## Emite o pedido de reinicio (Main.gd regenera mapa/jogo de forma sincrona
## nesse mesmo emit) e so entao atualiza a propria HUD com o estado novo.
func _on_restart_pressed() -> void:
	EventBus.restart_requested.emit()
	game_over_panel.visible = false
	end_turn_button.disabled = false
	unit_panel.visible = false
	production_row.visible = false
	buildings_row.visible = false
	worked_tiles_label.visible = false
	worked_tiles_row.visible = false
	tech_panel.visible = false
	diplomacy_panel.visible = false
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
		production_row.visible = false
		buildings_row.visible = false
		worked_tiles_label.visible = false
		worked_tiles_row.visible = false
		if GameManager.hex_grid:
			GameManager.hex_grid.clear_city_territory()
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
	production_row.visible = _viewed_city != null
	buildings_row.visible = _viewed_city != null
	if GameManager.human_player:
		produce_archer_button.disabled = not GameManager.human_player.has_unlocked("archer")
		produce_cavalry_button.disabled = not GameManager.human_player.has_unlocked("cavalry")
		produce_catapult_button.disabled = not GameManager.human_player.has_unlocked("catapult")
		produce_mage_button.disabled = not GameManager.human_player.has_unlocked("mage")
		produce_griffin_button.disabled = not GameManager.human_player.has_unlocked("griffin")
		produce_treant_button.disabled = not GameManager.human_player.has_unlocked("treant")
	if _viewed_city:
		build_granary_button.disabled = not _viewed_city.can_build("granary")
		build_workshop_button.disabled = not _viewed_city.can_build("workshop")
		build_market_button.disabled = not _viewed_city.can_build("market")
		build_walls_button.disabled = not _viewed_city.can_build("walls")
		# "Limite da cidade" visivel no mapa (nao so como numero no painel):
		# tinge a propria cidade + vizinhos de dourado, o mesmo raio usado
		# pra tiles trabalhados E pra posicionar predios.
		var territory: Array = [_viewed_city.coord]
		territory.append_array(hex_grid.get_neighbors(_viewed_city.coord))
		hex_grid.show_city_territory(territory)
	elif hex_grid:
		hex_grid.clear_city_territory()
	_refresh_worked_tiles_row()

## Um botao por vizinho valido (nem oceano) da cidade vista, mostrando
## terreno + rendimento; toggle_mode reflete se aquele cidadao ja esta
## trabalhando ali. So aparece pra cidade PROPRIA (mesma regra do
## production_row) — nao da pra microgerenciar cidade alheia.
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
		if data == null or data.terrain_type == HexTileData.TerrainType.OCEAN:
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

func _on_game_over(victory: bool) -> void:
	end_turn_button.disabled = true
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
