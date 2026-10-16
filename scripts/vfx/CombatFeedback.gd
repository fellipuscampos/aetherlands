@static_unload
extends Node3D

## Presentation transaction. Rules resolve synchronously; only visible feedback waits for impact.
## One timer per visible action, bounded per map. No idle _process, animation polling or saved state.
const FocusProfiles := preload("res://scripts/vfx/SacredFocusProfiles.gd")
const SchoolProfiles := preload("res://scripts/vfx/SchoolFocusProfiles.gd")
const TimingProfiles := preload("res://scripts/vfx/CombatTimingProfiles.gd")
const GROUP := &"combat_feedback"
const MAX_PENDING := 12
const FLIGHT_SECONDS := 0.38
static var _stack: Array = []
static var force_in_tests := false
var map: Node3D
var source_ref: WeakRef
var delay := 0.0
var commands: Array = []
var retired: Array[Node3D] = []
var spawned: Array[WeakRef] = []
var completed := false
var scheduled := false

static func current() -> Node:
	return _stack[-1] if not _stack.is_empty() else null

static func visible_at(grid: Node3D, coord: Vector2i) -> bool:
	return grid.debug_fog_disabled or grid.visibility.is_empty() or int(grid.visibility.get(coord, 0)) == 2

static func _begin(grid: Node3D, source: Node3D, seconds: float) -> Node:
	if current() != null or not is_instance_valid(grid) or not grid.is_inside_tree() or seconds <= 0.0:
		return null
	if DisplayServer.get_name() == "headless" and not force_in_tests:
		return null
	if not is_instance_valid(source) or not source.is_visible_in_tree() or not visible_at(grid, source.coord):
		return null
	if int(grid.get_meta("feedback_pending", 0)) >= MAX_PENDING:
		return null
	var batch := new()
	batch.map = grid
	batch.source_ref = weakref(source)
	batch.delay = seconds
	grid.add_child(batch)
	batch.add_to_group(GROUP)
	grid.set_meta("feedback_pending", int(grid.get_meta("feedback_pending", 0)) + 1)
	_stack.append(batch)
	source.set_meta("feedback_last_batch", weakref(batch))
	return batch

static func resume(source: Node3D) -> Node:
	if current() != null or not source.has_meta("feedback_last_batch"): return null
	var batch: Node = source.get_meta("feedback_last_batch").get_ref()
	if not is_instance_valid(batch) or batch.completed or batch.is_queued_for_deletion(): return null
	_stack.append(batch)
	return batch

static func begin_clip(source: Node3D, grid: Node3D, clip: String) -> Node:
	if current() != null: return null
	if DisplayServer.get_name() == "headless" and not force_in_tests: return null
	var player: AnimationPlayer = source._anim_player
	if player == null or not player.has_animation(clip): return null
	var animation := player.get_animation(clip)
	var contact := contact_seconds(source, animation, clip)
	return _begin(grid, source, contact / maxf(absf(player.speed_scale), 0.01))

static func contact_seconds(unit: Node3D, animation: Animation, clip: String) -> float:
	for marker in [&"impact", &"IMPACT"]:
		if animation.has_marker(marker): return animation.get_marker_time(marker)
	var model: String = unit.unit_data.model_scene_path.get_file().get_basename()
	var profiles: Dictionary = TimingProfiles.MODELS.get(model, TimingProfiles.CLIPS)
	var fraction := float(profiles.get(clip, TimingProfiles.CLIPS.get(clip, 0.52)))
	return animation.length * fraction

static func attack_delay(unit: Node3D) -> float:
	var player: AnimationPlayer = unit._anim_player
	if player == null or unit.attack_animation == "":
		return 0.0
	var wait: float = unit._combat_visual_wait
	var clip: String = unit.get_meta("feedback_attack_clip", unit.attack_animation) if wait > 0.0 else player.current_animation
	if not player.has_animation(clip):
		return 0.0
	var animation := player.get_animation(clip)
	# Imported clips may author an exact marker. Factory Attack strikes on frame 14 of 1..26:
	# (14-1)/(26-1) = .52. Other clips use the same normalized contact fallback, not the recovery end.
	var contact := contact_seconds(unit, animation, clip)
	return wait + maxf(0.0, contact - (0.0 if wait > 0.0 else player.current_animation_position)) / maxf(absf(player.speed_scale), 0.01)

static func begin_attack(source: Node3D, grid: Node3D) -> Node:
	if current() != null: return null
	if DisplayServer.get_name() == "headless" and not force_in_tests: return null
	return _begin(grid, source, attack_delay(source))

static func cast_release(source: Node3D) -> float:
	var model: String = source.unit_data.model_scene_path.get_file().get_basename()
	var profile: Dictionary = FocusProfiles.PROFILES.get(model, SchoolProfiles.PROFILES.get(model, {}))
	var release := float(profile.get("release_seconds", 1.1))
	var player: AnimationPlayer = source._anim_player
	return release / maxf(absf(player.speed_scale), 0.01) if player != null else release

static func begin_cast(source: Node3D, grid: Node3D) -> Node:
	if current() != null: return null
	if DisplayServer.get_name() == "headless" and not force_in_tests: return null
	return _begin(grid, source, source.visual_walk_remaining() + cast_release(source) + FLIGHT_SECONDS)

static func finish(batch: Node) -> void:
	if batch == null:
		return
	_stack.erase(batch)
	if not is_instance_valid(batch):
		return
	if batch.scheduled: return
	if batch.commands.is_empty() and batch.retired.is_empty() and batch.spawned.is_empty():
		batch.free()
		return
	batch.scheduled = true
	batch.get_tree().create_timer(batch.delay, false).timeout.connect(batch.flush, CONNECT_ONE_SHOT)

static func defer_call(node: Node3D, method: StringName, args: Array = [], coalesce: bool = false) -> bool:
	var batch := current()
	var key := "feedback_revision_" + String(method)
	if not args.is_empty() and args[0] is Vector2i:
		key += "_q" + str(args[0].x).replace("-", "n") + "_r" + str(args[0].y).replace("-", "n")
	if batch == null or not node.is_inside_tree() or not node.is_visible_in_tree() or not (node == batch.map or batch.map.is_ancestor_of(node)):
		if coalesce and node.has_meta(key): node.set_meta(key, int(node.get_meta(key)) + 1)
		return false
	if node != batch.map and "coord" in node and not visible_at(batch.map, node.coord):
		if coalesce and node.has_meta(key): node.set_meta(key, int(node.get_meta(key)) + 1)
		return false
	var revision := 0
	if coalesce:
		revision = int(node.get_meta(key, 0)) + 1
		node.set_meta(key, revision)
	var stored: Array = []
	for arg in args: stored.append(weakref(arg) if arg is Node else arg)
	batch.commands.append({"node": weakref(node), "method": method, "args": stored, "key": key, "revision": revision, "coord": node.coord if "coord" in node else null})
	return true

static func stage_spawned(unit: Node3D) -> void:
	var batch := current()
	if batch == null: return
	unit.set_meta("feedback_spawn_pending", weakref(batch))
	unit.visible = false
	batch.spawned.append(weakref(unit))

static func hold_removed(unit: Node3D, coord: Variant = null) -> bool:
	var batch := current()
	var tile: Vector2i = unit.coord if "coord" in unit else (coord if coord != null else Vector2i.ZERO)
	if batch == null or not unit.is_inside_tree() or not unit.is_visible_in_tree() or not visible_at(batch.map, tile):
		return false
	# Already removed from all logical indices/rosters. Keep the existing visual, not a model duplicate.
	unit.set_meta("feedback_retired", true)
	if "movement_left" in unit: unit.movement_left = 0.0
	unit.set_meta("feedback_tile", tile)
	unit.reparent(batch, true)
	batch.retired.append(unit)
	unit.visible = visible_at(batch.map, tile)
	return true

static func refresh_fog(grid: Node3D) -> void:
	if int(grid.get_meta("feedback_pending", 0)) == 0: return
	for batch in grid.get_tree().get_nodes_in_group(GROUP):
		if batch.map != grid: continue
		for unit in batch.retired:
			if is_instance_valid(unit): unit.visible = visible_at(grid, unit.get_meta("feedback_tile"))

static func clear_grid(grid: Node3D) -> void:
	if not grid.is_inside_tree(): return
	for batch in grid.get_tree().get_nodes_in_group(GROUP):
		if batch.map == grid:
			_stack.erase(batch)
			batch.free()

func flush() -> void:
	if completed or not is_instance_valid(map): return
	completed = true
	var changed := {}
	for command in commands:
		var node: Node3D = command.node.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if int(command.revision) > 0 and int(node.get_meta(command.key, 0)) != int(command.revision): continue
		if int(command.revision) == 0:
			if node != map and "coord" in node and not visible_at(map, node.coord): continue
			if node == map and command.method == &"_spawn_number_popup" and not visible_at(map, command.args[0]): continue
		var args: Array = []
		for arg in command.args: args.append(arg.get_ref() if arg is WeakRef else arg)
		node.callv(command.method, args)
		if node.has_method("_update_hp_bar"): changed[node.get_instance_id()] = node
	commands.clear()
	_reveal_spawned()
	var bus := map.get_node_or_null("/root/EventBus")
	if bus != null:
		for unit in changed.values(): bus.emit_signal("unit_status_changed", unit)
	for unit in retired:
		if not is_instance_valid(unit): continue
		if unit.has_method("play_death_topple"):
			unit.play_death_topple(0.18)
		else:
			unit.visible = false
	# Small terminal motion only; the body is never an AI unit again.
	if retired.is_empty():
		queue_free()
	else:
		get_tree().create_timer(0.22, false).timeout.connect(queue_free, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
	_stack.erase(self)
	_reveal_spawned()
	if is_instance_valid(map): map.set_meta("feedback_pending", maxi(0, int(map.get_meta("feedback_pending", 0)) - 1))

func _reveal_spawned() -> void:
	for reference in spawned:
		var unit: Node3D = reference.get_ref()
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or not unit.has_meta("feedback_spawn_pending"): continue
		if unit.get_meta("feedback_spawn_pending").get_ref() != self: continue
		unit.remove_meta("feedback_spawn_pending")
		if is_instance_valid(map): unit.visible = map.shown_through_fog(unit.coord, unit.owner_player, unit.always_visible)
	spawned.clear()
