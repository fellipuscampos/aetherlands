class_name AttentionItem
extends RefCounted

## Estado de apresentacao derivado. Nunca referencia Nodes e nunca entra no save.
enum Priority { REQUIRED, WARNING, SUGGESTION }

var id := ""
var category := ""
var priority: Priority = Priority.WARNING
var severity: UIEventData.Severity = UIEventData.Severity.INFO
var title := ""
var description := ""
var target_kind := ""
var target_id := ""
var target_coord := Vector2i.ZERO
var has_target_coord := false
var primary_action := ""
var primary_action_label := "Ver"
var can_defer := false
var blocking_end_turn := false
var sort_key := 0

static func create(item_id: String, item_priority: Priority, item_title: String, item_description: String = "") -> AttentionItem:
	var item := AttentionItem.new()
	item.id = item_id
	item.priority = item_priority
	item.title = item_title
	item.description = item_description
	item.blocking_end_turn = item_priority == Priority.REQUIRED
	item.can_defer = item_priority != Priority.REQUIRED
	return item

func with_target(kind: String, coord: Vector2i, target: String = "") -> AttentionItem:
	target_kind = kind
	target_id = target
	target_coord = coord
	has_target_coord = true
	return self

func to_dict() -> Dictionary:
	return {
		"id": id,
		"category": category,
		"priority": priority,
		"severity": severity,
		"title": title,
		"description": description,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_coord": target_coord if has_target_coord else null,
		"primary_action": primary_action,
		"primary_action_label": primary_action_label,
		"can_defer": can_defer,
		"blocking_end_turn": blocking_end_turn,
		"sort_key": sort_key,
	}
