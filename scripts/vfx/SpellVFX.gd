class_name SpellVFX
extends RefCounted

## Presentation only. Every school enters through the same successful-cast path.
const SCHOOLS := {
	"sacred": preload("res://scripts/vfx/SacredSpellFX.gd"),
	"infernal": preload("res://scripts/vfx/InfernalSpellFX.gd"),
	"necromancy": preload("res://scripts/vfx/NecromancySpellFX.gd"),
	"druidism": preload("res://scripts/vfx/DruidismSpellFX.gd"),
	"arcanism": preload("res://scripts/vfx/ArcanismSpellFX.gd"),
	"elementalism": preload("res://scripts/vfx/ElementalismSpellFX.gd"),
}
const MAX_CASTS_PER_MAP := 12
const GROUP := &"spell_vfx"

static func play(caster: Node3D, spell: Resource, coord: Vector2i, grid: Node3D, outcomes: Array[Dictionary], context: Dictionary = {}) -> Node3D:
	if not is_instance_valid(grid) or not grid.is_inside_tree() or not SCHOOLS.has(spell.school_branch):
		return null
	var count := 0
	for effect in grid.get_tree().get_nodes_in_group(GROUP):
		if effect.get_parent() == grid and not effect.is_queued_for_deletion(): count += 1
	if count >= MAX_CASTS_PER_MAP: return null
	var effect: Node3D = SCHOOLS[spell.school_branch].new()
	grid.add_child(effect)
	effect.add_to_group(GROUP)
	effect.set_meta("origin_coord",context.get("origin_coord",caster.coord))
	effect.set_meta("synchronized_feedback",context.get("synchronized_feedback",false))
	effect.set_meta("start_delay",context.get("start_delay",0.0))
	effect.set_meta("release_seconds",context.get("release_seconds",preload("res://scripts/vfx/CombatFeedback.gd").cast_release(caster)))
	effect.setup(caster, spell, coord, grid, outcomes)
	return effect

static func receipt(unit: Node3D, grid: Node3D) -> Dictionary:
	return {"unit":weakref(unit),"coord":unit.coord,"position":unit.global_position if unit.is_inside_tree() else grid.world_surface_for_coord(unit.coord),"heal":0.0,"damage":0.0}

static func portal_transit(unit: Node3D, from: Vector2i, to: Vector2i, grid: Node3D) -> void:
	if not grid.is_inside_tree(): return
	var count := 0
	for effect in grid.get_tree().get_nodes_in_group(GROUP):
		if effect.get_parent()==grid and not effect.is_queued_for_deletion(): count += 1
	if count>=MAX_CASTS_PER_MAP: return
	var effect: Node3D = preload("res://scripts/vfx/ArcaneTravelFX.gd").new()
	grid.add_child(effect)
	effect.add_to_group(GROUP)
	effect.setup(unit,from,to,grid)

static func zone_hit(receipt_data: Dictionary, kind: String, grid: Node3D) -> void:
	if not grid.is_inside_tree() or float(receipt_data.get("damage",0.0))<=0: return
	var count := 0
	for effect in grid.get_tree().get_nodes_in_group(GROUP):
		if effect.get_parent()==grid and not effect.is_queued_for_deletion(): count += 1
	if count>=MAX_CASTS_PER_MAP: return
	var effect: Node3D = preload("res://scripts/vfx/ZoneImpactFX.gd").new()
	grid.add_child(effect)
	effect.add_to_group(GROUP)
	effect.setup(receipt_data,kind,grid)

static func tile_visible(grid: Node3D, coord: Vector2i) -> bool:
	return grid.debug_fog_disabled or grid.visibility.is_empty() or int(grid.visibility.get(coord, 0)) == 2

static func unit_visible(unit: Node3D, grid: Node3D) -> bool:
	if not is_instance_valid(unit) or not unit.is_inside_tree() or not unit.is_visible_in_tree() or unit.presentation_hp() <= 0.0: return false
	return unit.owner_player == GameManager.human_player or unit.always_visible or tile_visible(grid, unit.coord)
