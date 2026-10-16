extends Node3D

const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
const MAX_BANKS := 12
var amount := 0.0
var timer := 0.0
var banks: Dictionary = {}

func set_amount(value: float) -> void:
	amount = clampf(value,0,1)
	if amount<.005:
		for entry in banks.values():
			if is_instance_valid(entry.cloud): entry.cloud.queue_free()
		banks.clear()

func _process(delta: float) -> void:
	if amount<.005:
		for entry in banks.values():
			if is_instance_valid(entry.cloud): entry.cloud.queue_free()
		banks.clear()
		return
	timer += delta
	if timer>.30:
		timer = 0
		_refresh()
	for id in banks.keys():
		var entry: Dictionary = banks[id]
		var unit: Node3D = entry.unit.get_ref()
		if not is_instance_valid(unit) or unit.hp<=0:
			entry.cloud.queue_free()
			banks.erase(id)
			continue
		entry.cloud.visible = unit.is_visible_in_tree()
		if not entry.cloud.visible: continue
		entry.age = minf(2.0,float(entry.age)+delta)
		entry.cloud.global_position = unit.global_position+Vector3.UP*maxf(2.8,float(unit._marker_height)+.65)
		Natural.opacity(entry.cloud,amount*smoothstep(0,1.8,entry.age)*.80)

func _refresh() -> void:
	var grid: Node3D = GameManager.hex_grid
	if not is_instance_valid(grid) or not grid.is_inside_tree(): return
	var camera := get_viewport().get_camera_3d()
	var candidates: Array[Node3D] = []
	for unit in grid.units_by_coord.values():
		if not is_instance_valid(unit) or unit.hp<=0 or not unit.is_visible_in_tree(): continue
		if camera!=null and not camera.is_position_in_frustum(unit.global_position): continue
		candidates.append(unit)
	if camera!=null: candidates.sort_custom(func(a,b):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	var wanted: Dictionary = {}
	for i in mini(MAX_BANKS,candidates.size()):
		var unit := candidates[i]
		var id := unit.get_instance_id()
		wanted[id] = true
		if banks.has(id): continue
		var cloud: Node3D = Natural.cloud_bank(self,Color(.62,.67,.73,.58),1.5)
		banks[id] = {"unit":weakref(unit),"cloud":cloud,"age":0.0}
	for id in banks.keys():
		if not wanted.has(id):
			banks[id].cloud.queue_free()
			banks.erase(id)
