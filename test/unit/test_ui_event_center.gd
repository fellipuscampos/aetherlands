extends GutTest

func before_each():
	UIEvents.clear_session()

func after_each():
	UIEvents.clear_session()

func test_event_center_uses_existing_history_newest_first_and_marks_read():
	for i in range(3):
		UIEvents.publish(UIEventData.create("e%d" % i, UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Evento %d" % i))
	var center := EventCenterPresenter.new()
	add_child_autofree(center)
	center.opened()
	assert_eq(UIEvents.unread_count(), 0)
	assert_eq(UIEvents.get_history().size(), 3)
	var first_panel := center.rows.get_child(0)
	var title: Label = first_panel.get_child(0).get_child(0).get_child(0)
	assert_true(title.text.contains("Evento 2"))

func test_event_center_filters_critical_without_removing_history():
	UIEvents.publish(UIEventData.create("info", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Info"))
	UIEvents.publish(UIEventData.create("critical", UIEventData.Category.WAR, UIEventData.Severity.CRITICAL, "Crítico"))
	var center := EventCenterPresenter.new()
	add_child_autofree(center)
	center.set_filter(EventCenterPresenter.Filter.CRITICAL)
	assert_eq(center.rows.get_child_count(), 1)
	assert_eq(UIEvents.get_history().size(), 2)

func test_event_without_target_has_no_broken_action_button():
	UIEvents.publish(UIEventData.create("info", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "Sem alvo"))
	var center := EventCenterPresenter.new()
	add_child_autofree(center)
	var row := center.rows.get_child(0).get_child(0)
	assert_eq(row.get_child_count(), 1)

func test_critical_banner_queues_and_dismiss_does_not_remove_history():
	var presenter := CriticalAlertPresenter.new()
	add_child_autofree(presenter)
	for type in ["war_declared", "city_lost", "ritual_critical"]:
		var event := UIEventData.create(type, UIEventData.Category.WAR, UIEventData.Severity.CRITICAL, type)
		UIEvents.publish(event)
	assert_eq(presenter.current_event().event_type, "war_declared")
	assert_eq(presenter.queued_count(), 2)
	presenter.dismiss()
	assert_eq(presenter.current_event().event_type, "city_lost")
	assert_eq(UIEvents.get_history().size(), 3)

func test_noncritical_event_never_enters_banner_queue():
	var presenter := CriticalAlertPresenter.new()
	add_child_autofree(presenter)
	UIEvents.publish(UIEventData.create("production_completed", UIEventData.Category.PRODUCTION, UIEventData.Severity.IMPORTANT, "Produção"))
	assert_null(presenter.current_event())
	assert_false(presenter.visible)

func test_shell_drawers_are_mutually_exclusive_and_responsive():
	var shell := (load("res://scenes/ui/UIShell.tscn") as PackedScene).instantiate() as UIShell
	add_child_autofree(shell)
	shell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shell.size = Vector2(1280, 720)
	await get_tree().process_frame
	shell.apply_viewport_size(Vector2(1280, 720))
	shell.toggle_event_center()
	await get_tree().process_frame
	assert_true(shell.event_center.visible)
	assert_lte(shell.event_center.size.x, 400.0)
	assert_eq(shell.event_center.size.y, shell.event_center.preferred_height(), "historico curto nao herda a altura inteira do viewport")
	shell.toggle_city_summary()
	assert_false(shell.event_center.visible)
	assert_true(shell.city_summary.visible)

func test_unread_badge_clears_on_open_but_history_remains():
	var shell := (load("res://scenes/ui/UIShell.tscn") as PackedScene).instantiate() as UIShell
	add_child_autofree(shell)
	UIEvents.publish(UIEventData.create("x", UIEventData.Category.SYSTEM, UIEventData.Severity.INFO, "X"))
	assert_eq(UIEvents.unread_count(), 1)
	shell.toggle_event_center()
	assert_eq(UIEvents.unread_count(), 0)
	assert_eq(UIEvents.get_history().size(), 1)

func test_war_has_event_banner_and_persistent_state_not_only_toast():
	var old_human := GameManager.human_player
	var old_rivals := GameManager.rival_players.duplicate()
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Humano"
	rival.civ.civ_name = "Rival"
	GameManager.human_player = human
	GameManager.rival_players = [rival]
	var banner := CriticalAlertPresenter.new()
	add_child_autofree(banner)
	var alerts := StrategicAlertPresenter.new()
	add_child_autofree(alerts)
	Diplomacy.declare_war(rival, human, "Expansão")
	alerts.bind_player(human)
	assert_eq(UIEvents.get_history().filter(func(event): return event.event_type == "war_declared").size(), 1)
	assert_not_null(banner.current_event())
	assert_eq(alerts.get_child_count(), 1)
	Diplomacy.propose_peace(human, rival)
	alerts.refresh()
	assert_eq(alerts.get_child_count(), 0)
	GameManager.human_player = old_human
	GameManager.rival_players.assign(old_rivals)

func test_ritual_progress_at_one_round_creates_critical_history_entry():
	var old_human := GameManager.human_player
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	human.civ.civ_name = "Humano"
	rival.civ.civ_name = "Rival"
	GameManager.human_player = human
	EventBus.v2_transcendence_progressed.emit(rival, Vector2i(5, 1), 1)
	var matching := UIEvents.get_history().filter(func(event): return event.event_type == "ritual_critical")
	assert_eq(matching.size(), 1)
	assert_eq(matching[0].severity, UIEventData.Severity.CRITICAL)
	assert_eq(matching[0].target_coord, Vector2i(5, 1))
	GameManager.human_player = old_human

func test_city_lost_keeps_coordinate_and_enters_banner_queue():
	var old_human := GameManager.human_player
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	var banner := CriticalAlertPresenter.new()
	add_child_autofree(banner)
	EventBus.city_captured.emit(human, rival, "Aldenmark", Vector2i(-2, 4))
	assert_eq(banner.current_event().event_type, "city_lost")
	assert_eq(banner.current_event().target_coord, Vector2i(-2, 4))
	GameManager.human_player = old_human

func test_city_captured_by_human_is_important_without_critical_banner():
	var old_human := GameManager.human_player
	var human := PlayerData.new(CivilizationData.new())
	var rival := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	var banner := CriticalAlertPresenter.new()
	add_child_autofree(banner)
	EventBus.city_captured.emit(rival, human, "Aldenmark", Vector2i(-2, 4))
	var event: UIEventData = UIEvents.get_history().back()
	assert_eq(event.event_type, "city_captured")
	assert_eq(event.severity, UIEventData.Severity.IMPORTANT)
	assert_null(banner.current_event())
	GameManager.human_player = old_human

func test_structured_city_founded_does_not_duplicate_the_legacy_bridge():
	var old_human := GameManager.human_player
	var human := PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	EventBus.notify.emit("Cidade fundada: Aldenmark", "city")
	EventBus.city_founded.emit(human, "Aldenmark", Vector2i(2, -1))
	assert_eq(UIEvents.get_history().size(), 1)
	assert_eq(UIEvents.get_history()[0].event_type, "city_founded")
	GameManager.human_player = old_human
