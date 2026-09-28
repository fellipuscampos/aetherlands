extends GutTest

var _original_human: PlayerData
var _original_turn: int

func before_each():
	_original_human = GameManager.human_player
	_original_turn = TurnManager.turn_number
	TurnManager.turn_number = 12
	UIEvents.clear_session()

func after_each():
	UIEvents.clear_session()
	UIEvents.history_limit = UIEventService.DEFAULT_HISTORY_LIMIT
	GameManager.human_player = _original_human
	TurnManager.turn_number = _original_turn

func _human(name: String = "Humano") -> PlayerData:
	var player := PlayerData.new(CivilizationData.new())
	player.civ.civ_name = name
	GameManager.human_player = player
	return player

func test_model_preserves_semantics_target_turn_timestamp_and_order():
	var event := UIEventData.create("test", UIEventData.Category.WAR, UIEventData.Severity.CRITICAL, "Alerta", "Mensagem")
	event.with_target(Vector2i(3, -2), "cidade_1")
	UIEvents.publish(event)
	assert_eq(event.turn, 12)
	assert_eq(event.target_coord, Vector2i(3, -2))
	assert_true(event.has_target_coord)
	assert_eq(event.target_entity, "cidade_1")
	assert_gt(event.timestamp, 0.0)
	assert_eq(event.order, 1)

func test_history_is_capped_ordered_and_has_unread_lifecycle():
	UIEvents.history_limit = 5
	for i in range(8):
		UIEvents.publish(UIEventData.create("e%d" % i, UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "E%d" % i))
	var history: Array[UIEventData] = UIEvents.get_history()
	assert_eq(history.size(), 5)
	assert_eq(history[0].event_type, "e3")
	assert_lt(history[0].order, history[4].order)
	assert_eq(UIEvents.unread_count(), 8)
	UIEvents.mark_all_read()
	assert_eq(UIEvents.unread_count(), 0)
	UIEvents.history_limit = UIEventService.DEFAULT_HISTORY_LIMIT

func test_war_declared_by_ai_against_human_is_structured_critical():
	var human := _human()
	var rival := PlayerData.new(CivilizationData.new())
	rival.civ.civ_name = "Rival"
	Diplomacy.declare_war(rival, human, "Expansão territorial")
	var event: UIEventData = UIEvents.get_history().back()
	assert_eq(event.event_type, "war_declared")
	assert_eq(event.category, UIEventData.Category.WAR)
	assert_eq(event.severity, UIEventData.Severity.CRITICAL)
	assert_true(event.message.contains("Rival"))

func test_research_completion_is_important_and_names_the_research():
	var human := _human()
	assert_true(human.v2_research.complete_research("v2_doctrine_guardian_1"))
	var matching := UIEvents.get_history().filter(func(event): return event.event_type == "research_completed")
	assert_eq(matching.size(), 1)
	assert_eq(matching[0].severity, UIEventData.Severity.IMPORTANT)
	assert_true(matching[0].message.contains("Doutrina do Guardião"))
	assert_eq(matching[0].target_entity, "v2_doctrine_guardian_1")

func test_production_completion_has_city_item_and_coordinate():
	var human := _human()
	EventBus.ui_production_completed.emit(human, "Aurora", "unit_x", "Sentinela", Vector2i(4, 5))
	var event: UIEventData = UIEvents.get_history().back()
	assert_eq(event.event_type, "production_completed")
	assert_true(event.message.contains("Aurora"))
	assert_eq(event.target_entity, "unit_x")
	assert_eq(event.target_coord, Vector2i(4, 5))

func test_twenty_event_burst_keeps_history_and_limits_visible_toasts():
	var presenter := ToastPresenter.new()
	add_child_autofree(presenter)
	for i in range(20):
		UIEvents.publish(UIEventData.create("burst", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Evento %d" % i))
	assert_eq(UIEvents.get_history().size(), 20)
	assert_lte(presenter.visible_toast_count(), ToastPresenter.MAX_VISIBLE)
	assert_eq(presenter.queued_count(), 17)

func test_dedup_coalesces_visible_toast_but_never_discards_history():
	var presenter := ToastPresenter.new()
	add_child_autofree(presenter)
	for i in range(3):
		var event := UIEventData.create("same", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Repetido")
		event.dedup_key = "same"
		UIEvents.publish(event)
	assert_eq(UIEvents.get_history().size(), 3)
	assert_eq(presenter.visible_toast_count(), 1)
	var label: Label = presenter.get_child(0).get_child(0)
	assert_true(label.text.contains("×3"))

func test_event_service_has_no_serialization_contract():
	assert_false(UIEvents.has_method("to_dict"))
	assert_false(UIEvents.has_method("load_dict"))
