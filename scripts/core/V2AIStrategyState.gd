class_name V2AIStrategyState
extends RefCounted

enum Orientation { UNSET, MILITARY, ARCANE, BALANCED }
enum VictoryFocus { UNDECIDED, MILITARY_SUPREMACY, TRANSCENDENCE }

var orientation: int = Orientation.UNSET
var victory_focus: int = VictoryFocus.UNDECIDED
var preferred_doctrine_branches: Array[String] = []
var preferred_magic_branches: Array[String] = []
var adaptive_doctrine_branch: String = ""
var pressure_by_role_or_trait: Dictionary = {}
var last_strategy_review_turn: int = -1
var strategy_seed: int = 0

## Transient debug/explanation only. It is deliberately absent from saves.
var last_reasons: Array[String] = []

static func orientation_name(value: int) -> String:
	return ["UNSET", "MILITARY", "ARCANE", "BALANCED"][clampi(value, 0, 3)]

static func focus_name(value: int) -> String:
	return ["UNDECIDED", "MILITARY_SUPREMACY", "TRANSCENDENCE"][clampi(value, 0, 2)]

func is_initialized() -> bool:
	return orientation != Orientation.UNSET

func initialize(rival_index: int, world_seed: int, rival_count: int) -> void:
	if is_initialized():
		return
	strategy_seed = _stable_seed(world_seed, rival_index)
	var offset := posmod(world_seed, 3)
	# The cyclic assignment guarantees exactly one of each with three rivals.
	orientation = [Orientation.MILITARY, Orientation.ARCANE, Orientation.BALANCED][posmod(rival_index + offset, 3)]
	match orientation:
		Orientation.MILITARY:
			victory_focus = VictoryFocus.MILITARY_SUPREMACY
		Orientation.ARCANE:
			victory_focus = VictoryFocus.TRANSCENDENCE
		_:
			victory_focus = VictoryFocus.UNDECIDED
	last_strategy_review_turn = -1

static func _stable_seed(world_seed: int, rival_index: int) -> int:
	return world_seed * 1000003 + (rival_index + 1) * 104729 + 240024

func to_dict() -> Dictionary:
	return {
		"orientation": int(orientation),
		"victory_focus": int(victory_focus),
		"preferred_doctrine_branches": preferred_doctrine_branches.duplicate(),
		"preferred_magic_branches": preferred_magic_branches.duplicate(),
		"adaptive_doctrine_branch": adaptive_doctrine_branch,
		"pressure_by_role_or_trait": pressure_by_role_or_trait.duplicate(),
		"last_strategy_review_turn": last_strategy_review_turn,
		"strategy_seed": strategy_seed,
	}

func load_dict(value: Variant, rival_index: int, world_seed: int, rival_count: int) -> void:
	_clear()
	if typeof(value) == TYPE_DICTIONARY:
		var candidate_orientation := int(value.get("orientation", Orientation.UNSET))
		if candidate_orientation in [Orientation.MILITARY, Orientation.ARCANE, Orientation.BALANCED]:
			orientation = candidate_orientation
		var candidate_focus := int(value.get("victory_focus", VictoryFocus.UNDECIDED))
		if candidate_focus in [VictoryFocus.UNDECIDED, VictoryFocus.MILITARY_SUPREMACY, VictoryFocus.TRANSCENDENCE]:
			victory_focus = candidate_focus
		preferred_doctrine_branches = _valid_string_array(value.get("preferred_doctrine_branches", []), V2ResearchNode.TreeType.MILITARY_DOCTRINE, 2)
		preferred_magic_branches = _valid_string_array(value.get("preferred_magic_branches", []), V2ResearchNode.TreeType.MAGIC_SCHOOL, 2)
		var adaptive: Variant = value.get("adaptive_doctrine_branch", "")
		if typeof(adaptive) == TYPE_STRING and V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MILITARY_DOCTRINE, adaptive).size() > 0:
			adaptive_doctrine_branch = adaptive
		if typeof(value.get("pressure_by_role_or_trait", {})) == TYPE_DICTIONARY:
			for key in value.pressure_by_role_or_trait:
				var amount = value.pressure_by_role_or_trait[key]
				if typeof(key) == TYPE_STRING and (typeof(amount) == TYPE_INT or typeof(amount) == TYPE_FLOAT) and is_finite(float(amount)):
					pressure_by_role_or_trait[key] = clampf(float(amount), 0.0, 1000.0)
		last_strategy_review_turn = maxi(-1, int(value.get("last_strategy_review_turn", -1)))
		strategy_seed = int(value.get("strategy_seed", 0))
	initialize(rival_index, world_seed, rival_count)

func _clear() -> void:
	orientation = Orientation.UNSET
	victory_focus = VictoryFocus.UNDECIDED
	preferred_doctrine_branches.clear()
	preferred_magic_branches.clear()
	adaptive_doctrine_branch = ""
	pressure_by_role_or_trait.clear()
	last_strategy_review_turn = -1
	strategy_seed = 0
	last_reasons.clear()

static func _valid_string_array(value: Variant, tree_type: int, limit: int) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_STRING or entry in result:
			continue
		if V2ResearchDatabase.branch_info(tree_type, entry).size() > 0:
			result.append(entry)
		if result.size() >= limit:
			break
	return result
