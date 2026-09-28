class_name UIEventData
extends RefCounted

enum Severity { INFO, IMPORTANT, CRITICAL }
enum Category {
	RESEARCH,
	PRODUCTION,
	DIPLOMACY,
	WAR,
	CITY,
	MILITARY,
	MAGIC,
	VICTORY,
	WORLD,
	ECONOMY,
	SYSTEM,
}

var event_type := ""
var category: Category = Category.SYSTEM
var severity: Severity = Severity.INFO
var title := ""
var message := ""
var turn := 0
var source_player := ""
var target_coord := Vector2i.ZERO
var has_target_coord := false
var target_entity := ""
var dedup_key := ""
var focus_action := ""
var timestamp := 0.0
var order := 0

static func create(type: String, event_category: Category, event_severity: Severity, event_title: String, event_message: String = "") -> UIEventData:
	var event := UIEventData.new()
	event.event_type = type
	event.category = event_category
	event.severity = event_severity
	event.title = event_title
	event.message = event_message
	return event

func with_target(coord: Vector2i, entity: String = "") -> UIEventData:
	target_coord = coord
	has_target_coord = true
	target_entity = entity
	return self

func to_dict() -> Dictionary:
	return {
		"event_type": event_type,
		"category": category,
		"severity": severity,
		"title": title,
		"message": message,
		"turn": turn,
		"source_player": source_player,
		"target_coord": target_coord if has_target_coord else null,
		"target_entity": target_entity,
		"dedup_key": dedup_key,
		"focus_action": focus_action,
		"timestamp": timestamp,
		"order": order,
	}
