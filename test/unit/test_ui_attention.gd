extends GutTest

class NoSettlerCity extends City:
	func can_train(kind: String) -> bool:
		var data := UnitDatabase.create_unit(kind)
		if data != null and data.can_found_city:
			return false
		return super.can_train(kind)

var _original_human: PlayerData
var _original_players: Array[PlayerData]
var _original_rivals: Array[PlayerData]
var _original_events: Array[WorldEvent]
var human: PlayerData
var service: AttentionService
var _original_state: GameManager.GameState

func before_each():
	_original_human = GameManager.human_player
	_original_players = GameManager.players.duplicate()
	_original_rivals = GameManager.rival_players.duplicate()
	_original_events = WorldEventManager.active_events.duplicate()
	_original_state = GameManager.state
	human = _player("Humano")
	GameManager.human_player = human
	GameManager.players = [human]
	GameManager.rival_players = []
	WorldEventManager.active_events.clear()
	GameManager.state = GameManager.GameState.PLAYING
	service = AttentionService.new()
	service.bind_player(human)

func after_each():
	service.dispose()
	for city in human.cities:
		if is_instance_valid(city):
			city.free()
	WorldEventManager.active_events.assign(_original_events)
	GameManager.human_player = _original_human
	GameManager.players.assign(_original_players)
	GameManager.rival_players.assign(_original_rivals)
	GameManager.state = _original_state

## V3 / Etapa 2: pesquisa só depois da primeira cidade — os casos de Attention de pesquisa começam com uma cidade que
## já está produzindo (para não somar o Attention de cidade ociosa).
func _research_ready() -> City:
	var city := _city_without_settler("Capital", Vector2i(40, 40))
	city.production_item = "warrior"
	service.refresh()
	return city

func _player(name: String) -> PlayerData:
	var result := PlayerData.new(CivilizationData.new())
	result.civ.civ_name = name
	return result

func _city(name: String, coord: Vector2i) -> City:
	var city := City.new()
	city.city_name = name
	city.coord = coord
	city.owner_player = human
	human.cities.append(city)
	return city

func _city_without_settler(name: String, coord: Vector2i) -> City:
	var city := NoSettlerCity.new()
	city.city_name = name
	city.coord = coord
	city.owner_player = human
	human.cities.append(city)
	return city

func _ids(items: Array[AttentionItem]) -> Array[String]:
	var result: Array[String] = []
	for item in items:
		result.append(item.id)
	return result

func test_research_idle_is_required_and_primary():
	_research_ready()
	service.refresh()
	assert_eq(service.next_required().id, "research_idle")
	assert_true(service.next_required().blocking_end_turn)

func test_selecting_research_removes_idle_attention():
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	assert_false(_ids(service.items()).has("research_idle"))

func test_all_128_research_nodes_complete_never_requests_impossible_choice():
	var ids: Array[String] = []
	for node in V2ResearchDatabase.all_nodes():
		ids.append(node.id)
	human.v2_research.load_dict({"completed_ids": ids})
	assert_false(_ids(service.items()).has("research_idle"))

func test_idle_cities_are_required_in_stable_player_order():
	assert_true(human.v2_research.complete_research("v2_infrastructure_academy_1"))
	_city("Aldenmark", Vector2i(4, -1))
	_city("Valeforte", Vector2i(-2, 3))
	service.refresh()
	var required := service.required_items()
	assert_eq(required.size(), 3)
	assert_eq(required[1].id, "city_idle:4,-1")
	assert_eq(required[2].id, "city_idle:-2,3")

func test_only_settler_is_a_non_blocking_idle_warning():
	_city("Aldenmark", Vector2i(4, -1))
	service.refresh()
	var idle := service.items().filter(func(item: AttentionItem): return item.id == "city_idle:4,-1")
	assert_eq(idle.size(), 1)
	assert_eq(idle[0].priority, AttentionItem.Priority.WARNING)
	assert_false(idle[0].blocking_end_turn)
	assert_eq(idle[0].title, "Cidade ociosa — somente Colonizador disponível")
	assert_eq(idle[0].description, "Você pode continuar o turno ou produzir um Colonizador.")
	assert_eq(idle[0].primary_action, "focus_city")

func test_second_startable_option_restores_required_production_automatically():
	_city("Aldenmark", Vector2i(4, -1))
	service.refresh()
	assert_eq(service.items().filter(func(item: AttentionItem): return item.id == "city_idle:4,-1")[0].priority, AttentionItem.Priority.WARNING)
	assert_true(human.v2_research.complete_research("v2_infrastructure_academy_1"))
	var idle := service.items().filter(func(item: AttentionItem): return item.id == "city_idle:4,-1")
	assert_eq(idle.size(), 1)
	assert_eq(idle[0].priority, AttentionItem.Priority.REQUIRED)
	assert_true(idle[0].blocking_end_turn)

func test_single_non_settler_option_remains_required():
	assert_true(human.v2_research.complete_research("v2_infrastructure_academy_1"))
	_city_without_settler("Aldenmark", Vector2i(4, -1))
	service.refresh()
	var idle := service.items().filter(func(item: AttentionItem): return item.id == "city_idle:4,-1")
	assert_eq(idle.size(), 1)
	assert_eq(idle[0].priority, AttentionItem.Priority.REQUIRED)

func test_zero_startable_items_are_a_non_blocking_warning():
	_city_without_settler("Aldenmark", Vector2i(4, -1))
	service.refresh()
	var idle := service.items().filter(func(item: AttentionItem): return item.id == "city_idle:4,-1")
	assert_eq(idle.size(), 1)
	assert_eq(idle[0].priority, AttentionItem.Priority.WARNING)
	assert_false(idle[0].blocking_end_turn)
	assert_true(idle[0].title.begins_with("Sem produção disponível"))

func test_city_with_production_is_not_idle():
	var city := _city("Aldenmark", Vector2i(1, 2))
	city.production_item = "settler"
	service.refresh()
	assert_false(_ids(service.items()).has("city_idle:1,2"))

func test_waiting_mana_is_warning_not_idle_or_blocker():
	var city := _city("Aurora", Vector2i(2, 1))
	city.production_item = "v2_manifestation_seraph"
	city.stored_production = city.production_cost()
	human.mana = 0.0
	service.refresh()
	var matching := service.items().filter(func(item: AttentionItem): return item.id == "production_waiting_mana:2,1")
	assert_eq(matching.size(), 1)
	assert_eq(matching[0].priority, AttentionItem.Priority.WARNING)
	assert_false(matching[0].blocking_end_turn)
	assert_false(_ids(service.items()).has("city_idle:2,1"))

func test_negative_net_with_treasury_is_not_called_deficit():
	var city := _city("Aurora", Vector2i.ZERO)
	city.buildings = {"v2_building_guardian_hall": true, "v2_building_warrior_hall": true, "v2_building_ranger_camp": true, "v2_building_war_stable": true, "v2_building_rogue_guild": true, "v2_building_siege_arsenal": true}
	human.gold = 10.0
	service.refresh()
	assert_lt(V2EconomyRuntime.player_gold_net_income(human), 0.0)
	assert_false(_ids(service.items()).has("economy_deficit"))

func test_real_deficit_is_warning_and_never_required():
	var city := _city("Aurora", Vector2i.ZERO)
	city.buildings = {"v2_building_guardian_hall": true, "v2_building_warrior_hall": true, "v2_building_ranger_camp": true, "v2_building_war_stable": true, "v2_building_rogue_guild": true, "v2_building_siege_arsenal": true}
	human.gold = 0.0
	service.refresh()
	var deficit := service.items().filter(func(item: AttentionItem): return item.id == "economy_deficit")
	assert_eq(deficit.size(), 1)
	assert_eq(deficit[0].priority, AttentionItem.Priority.WARNING)

func test_rival_ritual_only_becomes_attention_at_one_round():
	var rival := _player("Rival")
	GameManager.players.append(rival)
	GameManager.rival_players.append(rival)
	rival.v2_transcendence_ritual = {"site_coord": Vector2i(7, 2), "remaining_rounds": 2}
	service.refresh()
	assert_false(_ids(service.items()).has("rival_ritual:1"))
	rival.v2_transcendence_ritual.remaining_rounds = 1
	service.refresh()
	var ritual := service.items().filter(func(item: AttentionItem): return item.id == "rival_ritual:1")
	assert_eq(ritual.size(), 1)
	assert_eq(ritual[0].severity, UIEventData.Severity.CRITICAL)
	assert_false(ritual[0].blocking_end_turn)

func test_service_has_no_save_contract_or_node_references():
	assert_false(service.has_method("to_dict"))
	assert_false(service.has_method("load_dict"))
	for item in service.items():
		assert_eq(typeof(item.target_id), TYPE_STRING)

func test_turn_controller_routes_required_instead_of_ending_turn():
	_research_ready()
	var manager := ModalManager.new()
	manager.add_child(ColorRect.new())
	manager.get_child(0).name = "Dimmer"
	var center := CenterContainer.new()
	center.name = "ContentHost"
	manager.add_child(center)
	add_child_autofree(manager)
	var controller := TurnController.new()
	add_child_autofree(controller)
	controller.bind(service, manager)
	var actions: Array[String] = []
	var ended := [0]
	controller.action_requested.connect(func(action: String, _item: AttentionItem): actions.append(action))
	controller.end_turn_requested.connect(func(): ended[0] += 1)
	controller.request_primary_action()
	assert_eq(actions, ["research"])
	assert_eq(ended[0], 0)

func test_turn_controller_ends_normally_when_only_warnings_exist():
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	_city("Aldenmark", Vector2i(4, -1))
	service.refresh()
	var controller := TurnController.new()
	add_child_autofree(controller)
	controller.bind(service, null)
	var ended := [0]
	controller.end_turn_requested.connect(func(): ended[0] += 1)
	controller.request_primary_action()
	assert_eq(ended[0], 1)
	assert_false(controller.override_button.visible)

func test_rebinding_same_player_is_idempotent_and_does_not_duplicate_callbacks():
	_research_ready()
	var changes := [0]
	service.items_changed.connect(func(_items): changes[0] += 1)
	service.bind_player(human)
	service.bind_player(human)
	changes[0] = 0
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	assert_eq(changes[0], 1)

func test_rebinding_replaces_old_player_research_connections():
	var replacement := _player("Substituto")
	var replacement_city := City.new()
	replacement_city.owner_player = replacement
	replacement_city.production_item = "warrior"
	replacement.cities.append(replacement_city)
	GameManager.human_player = replacement
	GameManager.players = [replacement]
	service.bind_player(replacement)
	var changes := [0]
	service.items_changed.connect(func(_items): changes[0] += 1)
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	assert_eq(changes[0], 0)
	assert_true(replacement.v2_research.select_research("v2_doctrine_guardian_1"))
	assert_eq(changes[0], 1)

func test_turn_controller_override_confirms_once_without_resolving_attention():
	_research_ready()
	var manager := ModalManager.new()
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	manager.add_child(dimmer)
	var center := CenterContainer.new()
	center.name = "ContentHost"
	manager.add_child(center)
	add_child_autofree(manager)
	var controller := TurnController.new()
	add_child_autofree(controller)
	controller.bind(service, manager)
	var ended := [0]
	controller.end_turn_requested.connect(func(): ended[0] += 1)
	controller.request_override()
	assert_true(manager.is_modal_open())
	assert_eq(ended[0], 0)
	var dialog := center.get_child(0) as Control
	var confirm: Button
	for child in dialog.find_children("*", "Button", true, false):
		if (child as Button).text == "Encerrar turno mesmo assim":
			confirm = child
			break
	assert_not_null(confirm)
	confirm.pressed.emit()
	assert_eq(ended[0], 1)
	assert_false(manager.is_modal_open())
	assert_eq(service.next_required().id, "research_idle")

func test_processing_turn_controller_never_routes_or_ends():
	var controller := TurnController.new()
	add_child_autofree(controller)
	controller.bind(service, null)
	var actions := [0]
	var ended := [0]
	controller.action_requested.connect(func(_action: String, _item: AttentionItem): actions[0] += 1)
	controller.end_turn_requested.connect(func(): ended[0] += 1)
	controller.set_processing(true)
	controller.request_primary_action()
	assert_eq(actions[0], 0)
	assert_eq(ended[0], 0)
	assert_true(controller.primary_button.disabled)

func test_research_widget_shows_idle_active_eta_and_zero_income():
	var capital := _research_ready()
	var widget := ResearchStatusWidget.new()
	add_child_autofree(widget)
	widget.bind_player(human)
	assert_true(widget.name_label.text.contains("Escolher"))
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	# Renda zero: sem cidade a pesquisa já ativa continua (só não progride) — V3 / Etapa 2.
	human.cities.erase(capital)
	capital.free()
	widget.refresh()
	assert_true(widget.progress.visible)
	assert_true(widget.detail_label.text.contains("Sem progresso"))
	var city := _city("Academia", Vector2i.ZERO)
	city.buildings = {"v2_building_academy": true}
	widget.refresh()
	assert_true(widget.detail_label.text.contains("turno"))

func test_city_summary_snapshots_idle_producing_and_waiting_mana():
	var presenter := CityProductionPresenter.new()
	add_child_autofree(presenter)
	presenter.bind_player(human)
	var city := _city("Aurora", Vector2i.ZERO)
	assert_eq(presenter.snapshot(city).state, CityProductionPresenter.State.IDLE)
	city.production_item = "settler"
	assert_eq(presenter.snapshot(city).state, CityProductionPresenter.State.PRODUCING)
	city.production_item = "v2_manifestation_seraph"
	city.stored_production = city.production_cost()
	assert_eq(presenter.snapshot(city).state, CityProductionPresenter.State.WAITING_MANA)

func test_attention_sort_is_deterministic_after_repeated_refresh():
	_city("A", Vector2i(3, 1))
	_city("B", Vector2i(-3, 1))
	service.refresh()
	var first := _ids(service.items())
	service.refresh()
	assert_eq(_ids(service.items()), first)

func test_ten_city_refresh_keeps_only_settler_states_non_blocking():
	assert_true(human.v2_research.select_research("v2_doctrine_guardian_1"))
	for index in 10:
		_city("Cidade %d" % index, Vector2i(index, -index))
	var started := Time.get_ticks_usec()
	for _iteration in 100:
		service.refresh()
	var elapsed := Time.get_ticks_usec() - started
	print("PHASE33A2_PERF: 100 refreshes / 10 cities = %d us" % elapsed)
	assert_eq(service.required_items().size(), 0)
	assert_eq(service.warning_items().filter(func(item: AttentionItem): return item.id.begins_with("city_idle:")).size(), 10)

func test_attention_and_gameplay_entry_remain_signal_driven_without_polling():
	var attention_source := FileAccess.get_file_as_string("res://scripts/ui/AttentionService.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main/Main.gd")
	assert_false(attention_source.contains("func _process("))
	assert_true(main_source.contains("hud.ui_shell.bind_player(GameManager.human_player)"))
