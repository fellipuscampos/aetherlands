class_name AttentionService
extends RefCounted

## Checklist humano derivado dos runtimes reais. Recalcula apenas por sinais/limites
## de turno; nao possui polling, flags resolvidas nem representacao no save.
signal items_changed(items: Array[AttentionItem])

const SORT_WORLD_EVENT := 100
const SORT_RESEARCH := 200
const SORT_CITY_IDLE := 300
const SORT_RITUAL_CRITICAL := 400
const SORT_WAITING_MANA := 500
const SORT_ECONOMY := 600
const SORT_LOGISTICS := 700
const SORT_RETINUE := 800

var _player: PlayerData
var _items: Array[AttentionItem] = []
var _global_signals_connected := false
var _last_signature := ""

func bind_player(player: PlayerData) -> void:
	_connect_global_signals()
	if _player == player:
		refresh()
		return
	_disconnect_player()
	_player = player
	_connect_player()
	refresh()

func player() -> PlayerData:
	return _player

func dispose() -> void:
	_disconnect_player()
	if _global_signals_connected:
		for signal_value in _global_signals():
			if signal_value.is_connected(_on_global_changed):
				signal_value.disconnect(_on_global_changed)
	_global_signals_connected = false
	_player = null

func items() -> Array[AttentionItem]:
	return _items.duplicate()

func required_items() -> Array[AttentionItem]:
	return _items.filter(func(item: AttentionItem): return item.priority == AttentionItem.Priority.REQUIRED)

func warning_items() -> Array[AttentionItem]:
	return _items.filter(func(item: AttentionItem): return item.priority == AttentionItem.Priority.WARNING)

func next_required() -> AttentionItem:
	for item in _items:
		if item.priority == AttentionItem.Priority.REQUIRED:
			return item
	return null

func refresh() -> void:
	var rebuilt: Array[AttentionItem] = []
	if _player != null and _player == GameManager.human_player:
		_append_world_event(rebuilt)
		_append_research(rebuilt)
		_append_cities(rebuilt)
		_append_rituals(rebuilt)
		_append_economy(rebuilt)
		_append_retinues(rebuilt)
	rebuilt.sort_custom(_sort_items)
	_items = rebuilt
	# Fase 30: a mesma lista derivada não reemite (evita remontar a faixa a cada
	# fog_updated quando nada mudou).
	var signature := _signature(rebuilt)
	if signature == _last_signature:
		return
	_last_signature = signature
	items_changed.emit(items())

func _append_world_event(result: Array[AttentionItem]) -> void:
	var human_index := GameManager.players.find(_player)
	if human_index < 0:
		return
	for event in WorldEventManager.active_events:
		if event == null or event.phase != WorldEvent.PHASE_PREPARATION or event.participants.has(human_index):
			continue
		var stable_id := str(event.event_id) if "event_id" in event else str(WorldEventManager.active_events.find(event))
		# Fase 33D3: participação no Dragão é OPCIONAL — aviso, nunca bloqueio do fim de turno.
		var item := AttentionItem.create("world_event_decision:%s" % stable_id, AttentionItem.Priority.WARNING, "Decidir participação no evento", "Existe uma decisão de evento mundial pendente.")
		item.category = "world_event"
		item.severity = UIEventData.Severity.IMPORTANT
		item.primary_action = "world_event"
		item.primary_action_label = "Decidir"
		item.sort_key = SORT_WORLD_EVENT
		result.append(item)
	# Fase 33D3: recompensa do Relicário a escolher (mesmo caminho de decisão do painel de evento). Não bloqueia:
	# sem escolha em ReliquaryEvent.REWARD_CHOICE_ROUNDS rodadas, vale o Ouro.
	for event in WorldEventManager.active_events:
		if event is ReliquaryEvent and (event as ReliquaryEvent).awaiting_choice_from(human_index):
			var choice := AttentionItem.create("world_event_reward:%d" % event.event_id, AttentionItem.Priority.WARNING, "Escolher recompensa do Relicário", "Ouro ou Mana.")
			choice.category = "world_event"
			choice.severity = UIEventData.Severity.IMPORTANT
			choice.primary_action = "world_event"
			choice.primary_action_label = "Escolher"
			choice.sort_key = SORT_WORLD_EVENT
			result.append(choice)

func _append_research(result: Array[AttentionItem]) -> void:
	if _player.v2_research == null or _player.v2_research.active_id != "":
		return
	# V3 / Etapa 2: sem cidade não há o que escolher — nenhum REQUIRED antes da primeira cidade.
	if not V2ResearchAccess.can_start(_player):
		return
	if _player.v2_research.get_completed_ids().size() >= V2ResearchDatabase.all_nodes().size():
		return
	var overflow := _player.v2_research.research_overflow
	var description := "Selecione o próximo projeto de Conhecimento."
	if overflow > 0.0:
		description = "Conhecimento acumulado: %s." % _number(overflow)
	var item := AttentionItem.create("research_idle", AttentionItem.Priority.REQUIRED, "Escolher Pesquisa", description)
	item.category = "research"
	item.severity = UIEventData.Severity.IMPORTANT
	item.primary_action = "research"
	item.primary_action_label = "Abrir Pesquisa"
	item.sort_key = SORT_RESEARCH
	result.append(item)

func _append_cities(result: Array[AttentionItem]) -> void:
	var city_order := 0
	for city in _player.cities:
		if city == null or not is_instance_valid(city) or city.owner_player != _player:
			continue
		if city.production_item == "":
			var startable_items := CityPresenter.startable_production_items(city)
			if startable_items.is_empty():
				result.append(_idle_city_attention(
					city, city_order, AttentionItem.Priority.WARNING,
					"Sem produção disponível — %s" % city.city_name,
					"Não há nenhum projeto que possa ser iniciado nesta cidade agora."
				))
			elif startable_items.size() == 1 and CityPresenter.is_settler_production_item(startable_items[0]):
				result.append(_idle_city_attention(
					city, city_order, AttentionItem.Priority.WARNING,
					"Cidade ociosa — somente Colonizador disponível",
					"Você pode continuar o turno ou produzir um Colonizador."
				))
			else:
				result.append(_idle_city_attention(
					city, city_order, AttentionItem.Priority.REQUIRED,
					"Escolher Produção — %s" % city.city_name,
					"A cidade está sem projeto de produção."
				))
		else:
			var mana_missing := _mana_missing(city)
			if city.stored_production >= city.production_cost() and mana_missing > 0:
				var waiting := AttentionItem.create("production_waiting_mana:%d,%d" % [city.coord.x, city.coord.y], AttentionItem.Priority.WARNING, "Produção aguardando Mana — %s" % city.city_name, "%s está concluído em Produção e aguarda %d Mana." % [_production_name(city.production_item), mana_missing])
				waiting.category = "production"
				waiting.severity = UIEventData.Severity.IMPORTANT
				waiting.primary_action = "focus_city"
				waiting.primary_action_label = "Ver cidade"
				waiting.sort_key = SORT_WAITING_MANA + city_order
				waiting.with_target("city", city.coord, city.city_name)
				result.append(waiting)
		city_order += 1

func _idle_city_attention(city: City, city_order: int, priority: int, title: String, description: String) -> AttentionItem:
	var idle := AttentionItem.create("city_idle:%d,%d" % [city.coord.x, city.coord.y], priority, title, description)
	idle.category = "production"
	idle.severity = UIEventData.Severity.IMPORTANT
	idle.primary_action = "focus_city"
	idle.primary_action_label = "Escolher" if priority == AttentionItem.Priority.REQUIRED else "Ver cidade"
	idle.sort_key = SORT_CITY_IDLE + city_order
	idle.with_target("city", city.coord, city.city_name)
	return idle

func _append_rituals(result: Array[AttentionItem]) -> void:
	for index in GameManager.players.size():
		var rival: PlayerData = GameManager.players[index]
		if rival == null or rival == _player or not V2TranscendenceSystem.has_active_ritual(rival):
			continue
		var remaining := V2TranscendenceSystem.ritual_rounds_remaining(rival)
		if remaining != 1:
			continue
		var rival_name := rival.civ.civ_name if rival.civ != null else "Civilização rival"
		var item := AttentionItem.create("rival_ritual:%d" % index, AttentionItem.Priority.WARNING, "Transcendência iminente", "%s concluirá o Ritual em 1 rodada." % rival_name)
		item.category = "victory"
		item.severity = UIEventData.Severity.CRITICAL
		item.primary_action = "victory"
		item.primary_action_label = "Ver Vitória"
		item.sort_key = SORT_RITUAL_CRITICAL + index
		item.with_target("ritual", V2TranscendenceSystem.ritual_site_coord(rival), rival_name)
		result.append(item)

func _append_economy(result: Array[AttentionItem]) -> void:
	if V2EconomyRuntime.is_gold_deficit(_player):
		var net := V2EconomyRuntime.player_gold_net_income(_player)
		var deficit := AttentionItem.create("economy_deficit", AttentionItem.Priority.WARNING, "Déficit de Ouro", "Renda líquida: %s Ouro/turno. Produções mantidas a Ouro operam com penalidade." % _signed_number(net))
		deficit.category = "economy"
		deficit.severity = UIEventData.Severity.IMPORTANT
		deficit.primary_action = "city_summary"
		deficit.primary_action_label = "Ver cidades"
		deficit.sort_key = SORT_ECONOMY
		result.append(deficit)
	if V2LogisticsRuntime.is_logistically_strained(_player):
		var used := V2LogisticsRuntime.player_supply_used(_player)
		var capacity := int(V2EconomyRuntime.player_supply_capacity(_player))
		var tension := AttentionItem.create("logistics_tension", AttentionItem.Priority.WARNING, "Tensão Logística", "%d / %d Suprimentos em uso." % [used, capacity])
		tension.category = "logistics"
		tension.severity = UIEventData.Severity.IMPORTANT
		tension.primary_action = "city_summary"
		tension.primary_action_label = "Ver cidades"
		tension.sort_key = SORT_LOGISTICS
		result.append(tension)

## Fase 30 — Hostes sem comando: WARNING agregado (nunca Required), derivado de
## Unit.can_receive_orders; a ação foca a primeira Hoste no Unit Panel novo.
func _append_retinues(result: Array[AttentionItem]) -> void:
	var count := 0
	var first: Unit = null
	for unit in _player.units:
		if unit == null or not is_instance_valid(unit) or not unit.unit_data.is_retinue():
			continue
		if unit.can_receive_orders():
			continue
		count += 1
		if first == null:
			first = unit
	if count == 0:
		return
	var title := "1 Hoste sem comando" if count == 1 else "%d Hostes sem comando" % count
	var item := AttentionItem.create("retinue_uncommanded", AttentionItem.Priority.WARNING, title, "Não recebem ordens até recuperar capacidade de Comando. Dissolver continua disponível.")
	item.category = "military"
	item.severity = UIEventData.Severity.IMPORTANT
	item.primary_action = "retinue"
	item.primary_action_label = "Ver Hoste"
	item.sort_key = SORT_RETINUE
	item.with_target("unit", first.coord, str(first.serial_id))
	result.append(item)

func _signature(list: Array[AttentionItem]) -> String:
	var parts: PackedStringArray = []
	for item in list:
		parts.append("%s|%s|%s|%s" % [item.id, item.title, item.description, item.target_coord])
	return "\n".join(parts)

func _connect_player() -> void:
	if _player == null or _player.v2_research == null:
		return
	_connect_signal(_player.v2_research.research_selected)
	_connect_signal(_player.v2_research.research_cancelled)
	_connect_signal(_player.v2_research.research_completed)
	_connect_signal(_player.v2_research.state_reset)

func _connect_global_signals() -> void:
	if _global_signals_connected:
		return
	_global_signals_connected = true
	for signal_value in _global_signals():
		if not signal_value.is_connected(_on_global_changed):
			signal_value.connect(_on_global_changed)

func _global_signals() -> Array[Signal]:
	return [TurnManager.turn_changed, EventBus.ui_state_changed, EventBus.city_founded, EventBus.city_captured, EventBus.diplomacy_changed, EventBus.v2_transcendence_started, EventBus.v2_transcendence_progressed, EventBus.v2_transcendence_interrupted, EventBus.world_event_phase_changed, EventBus.fog_updated]

func _disconnect_player() -> void:
	if _player == null or _player.v2_research == null:
		return
	for signal_value in [_player.v2_research.research_selected, _player.v2_research.research_cancelled, _player.v2_research.research_completed, _player.v2_research.state_reset]:
		if signal_value.is_connected(_on_source_changed):
			signal_value.disconnect(_on_source_changed)

func _connect_signal(signal_value: Signal) -> void:
	if not signal_value.is_connected(_on_source_changed):
		signal_value.connect(_on_source_changed)

func _on_source_changed(_a = null, _b = null, _c = null) -> void:
	refresh()

func _on_global_changed(_a = null, _b = null, _c = null, _d = null, _e = null) -> void:
	refresh()

func _sort_items(a: AttentionItem, b: AttentionItem) -> bool:
	if a.sort_key == b.sort_key:
		return a.id < b.id
	return a.sort_key < b.sort_key

func _mana_missing(city: City) -> int:
	if city.production_item == "" or not V2ResearchDatabase.is_v2_id(city.production_item) or BuildingDatabase.get_building(city.production_item) != null:
		return 0
	var mana_cost := UnitDatabase.create_unit(city.production_item).production_mana_cost
	return maxi(int(ceil(mana_cost - _player.mana)), 0)

func _production_name(kind: String) -> String:
	var building := BuildingDatabase.get_building(kind)
	if building != null:
		return building.display_name
	if V2CityLevelData.is_city_project(kind):
		return V2CityLevelData.level_name(V2CityLevelData.target_level_for_project(kind))
	if V2FortificationData.is_fortification_project(kind):
		return V2FortificationData.display_name(V2FortificationData.target_level_for_project(kind))
	return UnitDatabase.create_unit(kind).unit_name

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _signed_number(value: float) -> String:
	return "%+d" % int(value) if is_equal_approx(value, roundf(value)) else "%+.1f" % value
