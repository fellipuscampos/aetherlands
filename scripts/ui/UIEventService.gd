class_name UIEventService
extends Node

signal event_published(event: UIEventData)
signal history_changed
signal unread_changed(count: int)

const DEFAULT_HISTORY_LIMIT := 200

var history_limit := DEFAULT_HISTORY_LIMIT
var _history: Array[UIEventData] = []
var _unread_count := 0
var _next_order := 1

func _ready() -> void:
	_connect_domain_signals()

func publish(event: UIEventData) -> UIEventData:
	if event == null:
		return null
	event.turn = TurnManager.turn_number if event.turn <= 0 else event.turn
	event.timestamp = Time.get_ticks_msec() / 1000.0 if event.timestamp <= 0.0 else event.timestamp
	event.order = _next_order
	_next_order += 1
	_history.append(event)
	while _history.size() > history_limit:
		_history.pop_front()
	_unread_count += 1
	event_published.emit(event)
	history_changed.emit()
	unread_changed.emit(_unread_count)
	return event

func get_history() -> Array[UIEventData]:
	return _history.duplicate()

func unread_count() -> int:
	return _unread_count

func mark_all_read() -> void:
	if _unread_count == 0:
		return
	_unread_count = 0
	unread_changed.emit(0)

func clear_session() -> void:
	_history.clear()
	_unread_count = 0
	_next_order = 1
	history_changed.emit()
	unread_changed.emit(0)

func _connect_domain_signals() -> void:
	_connect_once(EventBus.notify, _on_legacy_notify)
	_connect_once(EventBus.ui_research_completed, _on_research_completed)
	_connect_once(EventBus.ui_production_completed, _on_production_completed)
	_connect_once(EventBus.diplomacy_changed, _on_diplomacy_changed)
	_connect_once(EventBus.city_founded, _on_city_founded)
	_connect_once(EventBus.city_captured, _on_city_captured)
	_connect_once(EventBus.city_threatened, _on_city_threatened)
	_connect_once(EventBus.v2_transcendence_started, _on_ritual_started)
	_connect_once(EventBus.v2_transcendence_progressed, _on_ritual_progressed)
	_connect_once(EventBus.v2_transcendence_interrupted, _on_ritual_interrupted)
	_connect_once(EventBus.victory_achieved, _on_victory)
	_connect_once(EventBus.world_event_announced, _on_world_event_announced)
	_connect_once(EventBus.world_phase_changed, _on_world_phase_changed)
	_connect_once(EventBus.world_threat_discovered, _on_world_threat_discovered)
	_connect_once(EventBus.regional_threat_awakened, _on_regional_threat_awakened)
	_connect_once(EventBus.world_threat_resolved, _on_world_threat_resolved)
	_connect_once(EventBus.guardian_site_spawned, _on_guardian_site_spawned)
	_connect_once(EventBus.public_milestone_reached, _on_public_milestone_reached)
	_connect_once(EventBus.world_event_phase_changed, _on_world_event_phase_changed_d3)

func _connect_once(source: Signal, callable: Callable) -> void:
	if not source.is_connected(callable):
		source.connect(callable)

func _is_human(player: PlayerData) -> bool:
	return player != null and player == GameManager.human_player

func _player_name(player: PlayerData) -> String:
	return player.civ.civ_name if player != null and player.civ != null else "Civilização"

func _on_legacy_notify(text: String, sfx_kind: String) -> void:
	# HexGrid emite este notify legado imediatamente antes do evento estruturado
	# city_founded. A ponte deve cobrir produtores ainda não migrados, não criar
	# duas linhas/toasts para o mesmo fato conhecido.
	if text.begins_with("Cidade fundada: "):
		return
	var category := UIEventData.Category.SYSTEM
	if sfx_kind == "combat":
		category = UIEventData.Category.MILITARY
	elif sfx_kind == "city":
		category = UIEventData.Category.CITY
	elif sfx_kind == "magic":
		category = UIEventData.Category.MAGIC
	var event := UIEventData.create("legacy_notification", category, UIEventData.Severity.INFO, text)
	event.dedup_key = "legacy:%s" % text
	publish(event)

func _on_research_completed(player: PlayerData, research_id: String, display_name: String) -> void:
	if not _is_human(player):
		return
	var event := UIEventData.create("research_completed", UIEventData.Category.RESEARCH, UIEventData.Severity.IMPORTANT, "Pesquisa concluída", display_name)
	event.source_player = _player_name(player)
	event.target_entity = research_id
	event.dedup_key = "research:%s" % research_id
	event.focus_action = "research"
	publish(event)

func _on_production_completed(player: PlayerData, city_name: String, item_id: String, display_name: String, coord: Vector2i) -> void:
	if not _is_human(player):
		return
	var event := UIEventData.create("production_completed", UIEventData.Category.PRODUCTION, UIEventData.Severity.IMPORTANT, "Produção concluída", "%s concluiu %s." % [city_name, display_name])
	event.source_player = _player_name(player)
	event.dedup_key = "production:%s:%s" % [city_name, item_id]
	event.focus_action = "focus_city"
	event.with_target(coord, item_id)
	publish(event)

func _on_diplomacy_changed(change_type: String, source: PlayerData, target: PlayerData, reason: String) -> void:
	if not _is_human(source) and not _is_human(target):
		return
	var other := target if _is_human(source) else source
	if change_type == "war":
		var declared_against_human := _is_human(target)
		var title := "Guerra declarada contra você" if declared_against_human else "Guerra declarada"
		var event := UIEventData.create("war_declared", UIEventData.Category.WAR, UIEventData.Severity.CRITICAL if declared_against_human else UIEventData.Severity.IMPORTANT, title, "%s — %s" % [_player_name(other), reason])
		event.source_player = _player_name(source)
		event.target_entity = _player_name(other)
		event.dedup_key = "war:%s:%s" % [_player_name(source), _player_name(target)]
		event.focus_action = "diplomacy"
		publish(event)
	elif change_type == "peace":
		var peace := UIEventData.create("peace_made", UIEventData.Category.DIPLOMACY, UIEventData.Severity.IMPORTANT, "Acordo de paz", "%s e %s encerraram a guerra." % [_player_name(source), _player_name(target)])
		peace.source_player = _player_name(source)
		peace.target_entity = _player_name(target)
		peace.dedup_key = "peace:%s:%s" % [_player_name(source), _player_name(target)]
		peace.focus_action = "diplomacy"
		publish(peace)

func _on_city_founded(player: PlayerData, city_name: String, coord: Vector2i) -> void:
	if not _is_human(player):
		return
	var event := UIEventData.create("city_founded", UIEventData.Category.CITY, UIEventData.Severity.IMPORTANT, "Cidade fundada", city_name)
	event.source_player = _player_name(player)
	event.dedup_key = "city_founded:%s" % city_name
	event.focus_action = "focus_city"
	event.with_target(coord, city_name)
	publish(event)

func _on_city_captured(old_owner: PlayerData, new_owner: PlayerData, city_name: String, coord: Vector2i) -> void:
	if not _is_human(old_owner) and not _is_human(new_owner):
		return
	var lost := _is_human(old_owner)
	var event := UIEventData.create("city_lost" if lost else "city_captured", UIEventData.Category.CITY, UIEventData.Severity.CRITICAL if lost else UIEventData.Severity.IMPORTANT, "Cidade perdida" if lost else "Cidade capturada", city_name)
	event.source_player = _player_name(new_owner)
	event.dedup_key = "city_capture:%s:%d" % [city_name, TurnManager.turn_number]
	event.focus_action = "focus_city"
	event.with_target(coord, city_name)
	publish(event)

func _on_city_threatened(player: PlayerData, city_name: String, coord: Vector2i, threat_description: String) -> void:
	if not _is_human(player):
		return
	var event := UIEventData.create("city_threatened", UIEventData.Category.CITY, UIEventData.Severity.CRITICAL, "Cidade ameaçada", "%s — %s." % [city_name, threat_description])
	event.source_player = _player_name(player)
	event.dedup_key = "city_threat:%d,%d:%d" % [coord.x, coord.y, TurnManager.turn_number]
	event.focus_action = "focus_city"
	event.with_target(coord, city_name)
	publish(event)

func _on_ritual_started(player: PlayerData, coord: Vector2i, remaining: int) -> void:
	var event := UIEventData.create("ritual_started", UIEventData.Category.VICTORY, UIEventData.Severity.CRITICAL if not _is_human(player) else UIEventData.Severity.IMPORTANT, "Ritual de Transcendência iniciado", "%s — %d rodada(s) restante(s)." % [_player_name(player), remaining])
	event.source_player = _player_name(player)
	event.dedup_key = "ritual:%s" % event.source_player
	event.focus_action = "victory"
	event.with_target(coord, "ritual")
	publish(event)

func _on_ritual_interrupted(player: PlayerData, coord: Vector2i, reason: String) -> void:
	var event := UIEventData.create("ritual_interrupted", UIEventData.Category.VICTORY, UIEventData.Severity.IMPORTANT, "Ritual interrompido", "%s — %s" % [_player_name(player), reason])
	event.source_player = _player_name(player)
	event.dedup_key = "ritual_interrupted:%s" % event.source_player
	event.focus_action = "victory"
	event.with_target(coord, "ritual")
	publish(event)

func _on_ritual_progressed(player: PlayerData, coord: Vector2i, remaining: int) -> void:
	if _is_human(player) or remaining != 1:
		return
	var event := UIEventData.create("ritual_critical", UIEventData.Category.VICTORY, UIEventData.Severity.CRITICAL, "Transcendência iminente", "%s concluirá o Ritual em 1 rodada." % _player_name(player))
	event.source_player = _player_name(player)
	event.dedup_key = "ritual_critical:%s:%d" % [event.source_player, TurnManager.turn_number]
	event.focus_action = "victory"
	event.with_target(coord, "ritual")
	publish(event)

func _on_victory(winner: PlayerData, victory_type: String) -> void:
	var event := UIEventData.create("game_over", UIEventData.Category.VICTORY, UIEventData.Severity.CRITICAL, "Fim de jogo", "%s — %s" % [_player_name(winner), victory_type])
	event.source_player = _player_name(winner)
	event.dedup_key = "game_over"
	event.focus_action = "victory"
	publish(event)

func _on_world_event_announced(event_source: WorldEvent) -> void:
	var event := UIEventData.create("world_event_announced", UIEventData.Category.WORLD, UIEventData.Severity.IMPORTANT, event_source.display_name(), event_source.public_summary())
	event.target_entity = str(event_source.event_id) if "event_id" in event_source else "world_event"
	event.dedup_key = "world:%s" % event.target_entity
	# Fase 33D3: o local do Relicário é público por definição (é a finalidade do anúncio) — foco no tile.
	if event_source is ReliquaryEvent:
		event.with_target((event_source as ReliquaryEvent).site_coord, "reliquary")
	publish(event)

## Fase 33D3 — marco público: publicado para o jogador desta tela, de qualquer reino (fato público do mundo),
## sem posição nem composição. WORLD/IMPORTANT; nunca Attention.
func _on_public_milestone_reached(player: PlayerData, milestone: String) -> void:
	var copy := PublicVictoryMilestones.message_for(player, milestone)
	var event := UIEventData.create("public_milestone", UIEventData.Category.VICTORY, UIEventData.Severity.IMPORTANT, String(copy.title), String(copy.body))
	event.source_player = _player_name(player)
	event.dedup_key = "milestone:%d:%s" % [GameManager.players.find(player), milestone]
	event.focus_action = "victory"
	publish(event)

## Fase 33D3 — desfechos de grandes eventos no Event Center (substitui o modal bloqueante do Dragão).
func _on_world_event_phase_changed_d3(event_source: WorldEvent, _old_phase: String, new_phase: String) -> void:
	if event_source is DragonEvent and new_phase == WorldEvent.PHASE_RESOLUTION:
		var dragon := event_source as DragonEvent
		var outcome := String(dragon.result.get("outcome", ""))
		var lines: Array[String] = []
		for line in DragonEvent.damage_ranking_lines(dragon.damage_by_civ, GameManager.players):
			lines.append(line)
		for index in dragon.result.get("rewards", {}):
			var reward: Dictionary = dragon.result.rewards[index]
			if int(index) < GameManager.players.size():
				lines.append("%s: +%d ouro · +%d mana" % [_player_name(GameManager.players[int(index)]), int(reward.gold), int(reward.mana)])
		var body := DragonEvent._outcome_message(outcome)
		if not lines.is_empty():
			body += "\n" + "\n".join(lines)
		var event := UIEventData.create("dragon_resolved", UIEventData.Category.WORLD, UIEventData.Severity.IMPORTANT, "O Dragão foi derrotado" if outcome == "defeated" else "O Dragão partiu", body)
		event.dedup_key = "dragon_resolved:%d" % dragon.event_id
		publish(event)
	elif event_source is ReliquaryEvent:
		var reliquary := event_source as ReliquaryEvent
		if new_phase == WorldEvent.PHASE_ACTIVE:
			_publish_threat("reliquary_active", "Relicário Desperto", "Os guardiões do Relicário se ergueram. Derrote-os e mantenha o local por %d rodadas." % ReliquaryEvent.CONTROL_ROUNDS_REQUIRED, reliquary.site_coord, "reliquary:active:%d" % reliquary.event_id)
		elif new_phase == WorldEvent.PHASE_RESOLUTION and reliquary.winner_index >= 0 and reliquary.winner_index < GameManager.players.size():
			_publish_threat("reliquary_resolved", "Relicário Desperto", "O Relicário foi reivindicado por %s." % _player_name(GameManager.players[reliquary.winner_index]), reliquary.site_coord, "reliquary:resolved:%d" % reliquary.event_id)

## Fase 33D1 — mudança de era do mundo: um evento WORLD/IMPORTANT (Toast + Event Center), nunca Attention.
## A causa interna (PROGRESS/FALLBACK) não aparece: a apresentação é a mesma.
const WORLD_PHASE_COPY := {
	WorldPhaseRules.Phase.ASCENSION: "Os reinos deixaram de ser pequenos enclaves. Expanda seu território, desenvolva suas cidades e prepare forças capazes de disputar as ameaças e oportunidades do mundo.",
	WorldPhaseRules.Phase.CONVERGENCE: "As grandes estratégias estão tomando forma. Observe os reinos rivais, converta seu poder em vantagem e prepare-se para disputar a vitória.",
}

## Fase 33D2 — ameaças do mundo. Só o que o jogador desta tela legitimamente sabe: a descoberta é dele, o
## despertar só é anunciado ao DONO que já conhece o covil, e a resolução por outro reino não revela quem.
## WORLD/IMPORTANT (Toast + Event Center) com foco no tile; nunca Attention nem alerta crítico.
func _on_world_threat_discovered(player: PlayerData, lair_coord: Vector2i, role: String) -> void:
	if not _is_human(player):
		return
	if role == HexGrid.LAIR_ROLE_REGIONAL:
		var record := RegionalThreatSystem.record_for_lair(lair_coord)
		if record.is_empty() or int(record.owner) != GameManager.players.find(player):
			return
		_publish_threat("regional_threat_discovered", "Ameaça regional", "Um covil hostil ameaça os arredores de seu reino.", lair_coord, "regional:discovered:%s" % lair_coord)
	elif role == HexGrid.LAIR_ROLE_GUARDIAN:
		var site := RegionalThreatSystem.guardian_for_lair(lair_coord)
		var known_resource: bool = site.has("resource_coord") and player.explored_tiles.has(site.resource_coord)
		var resource := ResourceDatabase.display_name(String(site.get("resource", ""))) if known_resource else ""
		_publish_threat("guardian_discovered", "Guardião Troll", "Um Troll guarda %s. Derrotá-lo libera o recurso." % (resource if resource != "" else "um recurso valioso"), lair_coord, "guardian:discovered:%s" % lair_coord)

func _on_regional_threat_awakened(owner_player: PlayerData, lair_coord: Vector2i, _kind: String) -> void:
	if not _is_human(owner_player):
		return
	var record := RegionalThreatSystem.record_for_lair(lair_coord)
	if record.is_empty() or GameManager.players.find(owner_player) not in record.discovered_by:
		return
	_publish_threat("regional_threat_awakened", "Ameaça regional", "Uma ameaça desperta perto de seu reino.", lair_coord, "regional:awake:%s" % lair_coord)

func _on_world_threat_resolved(role: String, owner_player: PlayerData, lair_coord: Vector2i, resolver: PlayerData) -> void:
	if role != HexGrid.LAIR_ROLE_REGIONAL or not _is_human(owner_player):
		return
	var record := RegionalThreatSystem.record_for_lair(lair_coord)
	if record.is_empty() or GameManager.players.find(owner_player) not in record.discovered_by:
		return
	var message := "A ameaça regional foi eliminada." if resolver == owner_player else "A ameaça regional foi eliminada por outro reino."
	_publish_threat("regional_threat_resolved", "Ameaça regional", message, lair_coord, "regional:resolved:%s" % lair_coord)

func _on_guardian_site_spawned(lair_coord: Vector2i, resource_coord: Vector2i, resource: String) -> void:
	var viewer := GameManager.human_player
	if viewer == null or not viewer.explored_tiles.has(resource_coord):
		return
	var resource_name := ResourceDatabase.display_name(resource)
	_publish_threat("guardian_site_spawned", "Guardião Troll", "Um Troll passou a guardar %s." % (resource_name if resource_name != "" else "um recurso valioso"), lair_coord, "guardian:spawned:%s" % lair_coord)

func _publish_threat(type: String, title: String, message: String, coord: Vector2i, dedup: String) -> void:
	var event := UIEventData.create(type, UIEventData.Category.WORLD, UIEventData.Severity.IMPORTANT, title, message)
	event.with_target(coord, "world_threat")
	event.dedup_key = dedup
	publish(event)

func _on_world_phase_changed(_old_phase: int, new_phase: int, turn: int, _cause: String) -> void:
	var title := "A %s começou" % WorldPhaseRules.display_name(new_phase)
	var event := UIEventData.create("world_phase_changed", UIEventData.Category.WORLD, UIEventData.Severity.IMPORTANT, title, String(WORLD_PHASE_COPY.get(new_phase, "")))
	event.dedup_key = "world_phase:%d" % new_phase
	event.target_entity = WorldPhaseRules.id_name(new_phase)
	publish(event)
