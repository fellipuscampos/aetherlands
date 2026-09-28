extends Node

## Fase 33A — sonda executável do opening real. Não altera regras nem números:
## instancia Main.tscn, funda a capital pelo Colonizador, inicia a única
## produção imediatamente disponível e registra o catálogo/Attention em marcos.

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const CHECKPOINTS := [1, 3, 5, 10, 15, 20, 30]

var failures: Array[String] = []
var snapshots: Array[Dictionary] = []
var colonizer_completed_turn := -1
var first_alternative_turn := -1

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PHASE33A_OK: ", message)
	else:
		failures.append(message)
		push_error("PHASE33A_FAIL: " + message)

func _settle(frames: int = 3) -> void:
	for _i in frames:
		await get_tree().process_frame

func _catalog_snapshot(city: City, label: String) -> Dictionary:
	var catalog := CityPresenter.catalog(city)
	var groups := {
		"UNITS": [],
		"BUILDINGS": [],
		"PROJECTS": [],
		"DEFENSE": [],
		"OTHER": [],
	}
	for item in catalog.units:
		groups.UNITS.append(_item_snapshot(item))
	for item in catalog.buildings:
		groups.BUILDINGS.append(_item_snapshot(item))
	for item in catalog.projects:
		var group := "PROJECTS" if item.category == "development" else ("DEFENSE" if item.category == "defense" else "OTHER")
		groups[group].append(_item_snapshot(item))

	var attention: Array[String] = []
	var shell: UIShell = get_node("Main/UILayer/HUD").ui_shell
	shell.attention_service.refresh()
	for item in shell.attention_service.items():
		attention.append("%s | %s | %s" % [["REQUIRED", "WARNING", "SUGGESTION"][item.priority], item.title, item.description])

	var result := {
		"label": label,
		"turn": TurnManager.turn_number,
		"production_item": city.production_item,
		"stored_production": snappedf(city.stored_production, 0.01),
		"knowledge_income": snappedf(V2EconomyRuntime.player_knowledge_income(GameManager.human_player), 0.01),
		"knowledge_overflow": snappedf(GameManager.human_player.v2_research.research_overflow, 0.01),
		"research_active": GameManager.human_player.v2_research.active_id,
		"research_completed": GameManager.human_player.v2_research.get_completed_ids(),
		"groups": groups,
		"attention": attention,
	}
	print("PHASE33A_OPENING: ", JSON.stringify(result))
	snapshots.append(result)
	return result

func _item_snapshot(item: Dictionary) -> Dictionary:
	return {
		"id": item.id,
		"name": item.name,
		"state": item.state,
		"reason": item.reason,
		"subgroup": item.subgroup,
		"pp": item.pp,
	}

func _has_startable_alternative(snapshot: Dictionary) -> bool:
	for group_name in snapshot.groups:
		for item in snapshot.groups[group_name]:
			if item.id != "settler" and item.state == "available":
				return true
	return false

func _continue_research_path(player: PlayerData) -> void:
	if player.v2_research.active_id != "":
		return
	for id in [
		"v2_infrastructure_academy_1",
		"v2_doctrine_guardian_1",
		"v2_doctrine_guardian_2",
		"v2_doctrine_guardian_3",
	]:
		if not player.v2_research.is_completed(id):
			player.v2_research.select_research(id)
			return

func _capture_named(file_name: String, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("PHASE33A_CAPTURE_SKIPPED_HEADLESS: ", file_name)
		return
	await _settle()
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png("user://%s" % file_name) == OK, label)

func _run() -> void:
	seed(33001)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var main := MAIN_SCENE.instantiate()
	main.name = "Main"
	add_child(main)
	await _settle()
	_check(main.title_screen.visible, "Title Screen real abre antes da partida")
	main._on_new_game_setup_requested()
	await _settle()
	_check(main.game_setup_screen.visible, "Setup real é alcançável a partir do título")
	await main._on_new_game_requested(41, 41, "Auditoria F33A", 1, "normal", "human")
	GameManager.stagger_ai_turns = false
	await _settle(5)
	_check(GameManager.state == GameManager.GameState.PLAYING, "Loading termina em partida jogável")
	_check(GameManager.human_player.units.size() == 2, "forças iniciais são Colonizador + Guarda")
	_check(main.hud.ui_shell.attention_service.player() == GameManager.human_player, "UIShell já está ligado ao jogador humano no primeiro estado útil")
	_check(main.hud.ui_shell.attention_service.next_required() != null and main.hud.ui_shell.attention_service.next_required().id == "research_idle", "Pesquisa ociosa já aparece no primeiro frame útil")

	var settler: Unit = GameManager.human_player.units.filter(func(unit): return unit.unit_data.can_found_city)[0]
	SelectionManager.select_unit(settler)
	var city := WorldSetup.found_city_from_settler(GameManager.hex_grid, settler)
	_check(city != null, "capital fundada pelo comando real do Colonizador")
	main.hud.ui_shell.context_router.open_city(city, "production")
	await _settle()

	var before := _catalog_snapshot(city, "T1_BEFORE_CHOICES")
	_check(before.groups.UNITS.size() == 1 and before.groups.UNITS[0].id == "settler", "capital começa com somente Colonizador em Unidades")
	_check(before.groups.BUILDINGS.is_empty(), "capital começa sem prédio pesquisado visível")
	_check(before.groups.PROJECTS.size() == 1 and before.groups.PROJECTS[0].state == "blocked", "Cidade II aparece bloqueada com motivo")
	_check(before.groups.DEFENSE.size() == 1 and before.groups.DEFENSE[0].state == "blocked", "Muralhas I aparecem bloqueadas com motivo")
	_check(before.attention.filter(func(text): return text.contains("REQUIRED | Escolher Pesquisa")).size() == 1, "pesquisa ociosa continua Attention Required")
	_check(before.attention.filter(func(text): return text.contains("WARNING | Cidade ociosa — somente Colonizador disponível")).size() == 1, "só Colonizador gera aviso não bloqueante")
	_check(before.attention.filter(func(text): return text.contains("REQUIRED | Escolher Produção")).is_empty(), "só Colonizador não cria falsa decisão obrigatória")
	await _capture_named("phase33a2_only_settler.png", "captura da capital com somente Colonizador")
	main.hud.ui_shell.attention_presenter._toggle()
	await _capture_named("phase33a2_attention_expanded.png", "captura do Attention expandido")
	main.hud.ui_shell.attention_presenter.collapse()

	_check(GameManager.human_player.v2_research.select_research("v2_infrastructure_academy_1"), "Academias escolhida pelo slot único")
	main.hud.ui_shell.attention_service.refresh()
	_check(main.hud.ui_shell.attention_service.required_items().is_empty(), "só o aviso do Colonizador não bloqueia Encerrar Turno")
	_check(not main.hud.ui_shell.turn_controller.override_button.visible, "override some quando não existe Required")
	city.set_production("settler")
	var queued := _catalog_snapshot(city, "T1_AFTER_CHOICES")
	_check(queued.groups.UNITS[0].state == "current", "Colonizador entra na fila normal")
	_check(queued.attention.filter(func(text): return text.contains("Escolher Produção")).is_empty(), "fila preenchida resolve a atenção de produção")

	while TurnManager.turn_number < 30 and GameManager.state == GameManager.GameState.PLAYING:
		var prior_item := city.production_item
		TurnManager.end_turn()
		await _settle(2)
		city = GameManager.human_player.cities[0]
		if prior_item == "settler" and city.production_item == "" and colonizer_completed_turn < 0:
			colonizer_completed_turn = TurnManager.turn_number
		_continue_research_path(GameManager.human_player)
		var current_snapshot: Dictionary = {}
		if TurnManager.turn_number in CHECKPOINTS:
			current_snapshot = _catalog_snapshot(city, "T%d" % TurnManager.turn_number)
		else:
			current_snapshot = {"groups": CityPresenter.catalog(city)}
		if first_alternative_turn < 0:
			var normalized := current_snapshot
			if not normalized.has("turn"):
				normalized = _catalog_snapshot(city, "T%d_FIRST_ALTERNATIVE_PROBE" % TurnManager.turn_number)
			if _has_startable_alternative(normalized):
				first_alternative_turn = TurnManager.turn_number
				_check(normalized.attention.any(func(text): return text.contains("REQUIRED | Escolher Produção")), "segunda opção iniciável restaura Attention Required")
				main.hud.ui_shell.context_router.city_panel.catalog_category = "buildings"
				main.hud.ui_shell.context_router.city_panel.refresh()
				await _capture_named("phase33a2_second_production_option.png", "captura com segunda opção real de produção")

	_check(GameManager.state == GameManager.GameState.PLAYING, "opening chega ao turno 30 sem estado terminal")
	_check(colonizer_completed_turn > 1, "Colonizador conclui pela fila e deixa a cidade ociosa")
	_check(first_alternative_turn > 1, "uma alternativa real de produção aparece por pesquisa")
	_check(GameManager.human_player.v2_research.is_completed("v2_infrastructure_academy_1"), "Academia I foi alcançada pela cadeia normal")
	_check(GameManager.human_player.v2_research.is_completed("v2_doctrine_guardian_2"), "Salão dos Guardiões foi alcançado pela cadeia normal")
	_check(not GameManager.human_player.v2_research.is_completed("v2_doctrine_guardian_3"), "N3 não foi pulado no recorte do opening")
	print("PHASE33A_DIAGNOSTIC: colonizer_completed_turn=%d first_alternative_turn=%d idle_pp_t30=%.2f failures=%d" % [colonizer_completed_turn, first_alternative_turn, city.stored_production, failures.size()])
	await _capture_named("phase33a_opening_t30.png", "captura do opening no turno 30")
	get_tree().quit(0 if failures.is_empty() else 1)
