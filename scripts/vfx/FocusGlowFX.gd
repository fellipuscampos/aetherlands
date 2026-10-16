extends Node3D

## A lease on real material emission and WorldGlow light. No visible geometry is added.
const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Masks := preload("res://scripts/vfx/FocusEmissionMasks.gd")
const SHADER := preload("res://assets/vfx/schools/focus_emission.gdshader")
var unit_ref: WeakRef
var manager: Node3D
var anchor: Node3D
var info: Dictionary
var bindings: Array[Dictionary] = []
var leases: Dictionary = {}
var light: OmniLight3D

static func acquire(unit: Node3D, grid: Node3D, token: int, school: String, color: Color) -> Node3D:
	var current := unit.get_node_or_null("SpellFocusGlow")
	if current!=null and current.is_queued_for_deletion():
		unit.remove_child(current)
		current = null
	if current==null:
		current = load("res://scripts/vfx/FocusGlowFX.gd").new()
		current.name = "SpellFocusGlow"
		unit.add_child(current)
		current.setup(unit,grid,school)
	current.leases[token] = {"strength":0.0,"shown":false,"color":color}
	return current

func setup(unit: Node3D, grid: Node3D, school: String) -> void:
	unit_ref = weakref(unit)
	manager = grid.world_glow
	info = Art.anchor(unit,true)
	var skeleton: Skeleton3D = info.skeleton.get_ref() if info.skeleton!=null else null
	if skeleton!=null and int(info.bone)>=0:
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = skeleton.get_bone_name(info.bone)
		skeleton.add_child(attachment)
		anchor = attachment
	else:
		anchor = Node3D.new()
		unit.add_child(anchor)
		anchor.position = Vector3.UP*float(info.height)*.58
	if is_instance_valid(manager):
		light = manager.attach_light(WorldGlow.GROUP_CASTING,get_instance_id(),anchor,StringName("casting_"+school),info.offset)
		manager.set_light_gain(WorldGlow.GROUP_CASTING,get_instance_id(),0.0)
	var model_name: String = unit.unit_data.model_scene_path.get_file().get_basename()
	var rects: Array = Masks.MASKS.get(model_name,[])
	if not is_instance_valid(unit._visual_root): return
	for mesh in unit._visual_root.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			if source==null: continue
			var previous: Material = mesh.get_surface_override_material(surface)
			var copy: Material = source.duplicate()
			var emission := ShaderMaterial.new()
			emission.shader = SHADER
			if not rects.is_empty():
				var values: Array[Vector4] = []
				for r in rects: values.append(Vector4(r[0],r[1],r[2],r[3]))
				emission.set_shader_parameter("focus_rects",values)
				emission.set_shader_parameter("use_uv_mask",true)
			elif source is BaseMaterial3D and source.emission_enabled and source.emission_texture!=null:
				emission.set_shader_parameter("emission_mask",source.emission_texture)
				emission.set_shader_parameter("use_emission_texture",true)
			copy.next_pass = emission
			mesh.set_surface_override_material(surface,copy)
			bindings.append({"mesh":weakref(mesh),"surface":surface,"previous":previous,"copy":copy,"emission":emission})

func update_lease(token: int, strength: float, shown: bool) -> void:
	if not leases.has(token): return
	leases[token].strength = maxf(0,strength)
	leases[token].shown = shown
	var value := 0.0
	var color := Color.WHITE
	for lease in leases.values():
		if bool(lease.shown) and float(lease.strength)>value:
			value = float(lease.strength)
			color = lease.color
	var unit: Node3D = unit_ref.get_ref()
	if not is_instance_valid(unit) or not unit.is_visible_in_tree() or unit.hp<=0: value = 0.0
	var pos := Art.anchor_position(info)
	for binding in bindings:
		binding.emission.set_shader_parameter("strength",value)
		binding.emission.set_shader_parameter("glow_color",color)
		binding.emission.set_shader_parameter("focus_world",pos)
	if is_instance_valid(manager):
		manager.set_light_gain(WorldGlow.GROUP_CASTING,get_instance_id(),value)
		manager.set_light_shown(WorldGlow.GROUP_CASTING,get_instance_id(),value>0 and Settings.creature_lighting_enabled)

func release(token: int) -> void:
	leases.erase(token)
	if leases.is_empty():
		_restore()
		queue_free()

func _restore() -> void:
	for binding in bindings:
		var mesh: MeshInstance3D = binding.mesh.get_ref()
		if is_instance_valid(mesh) and mesh.get_surface_override_material(binding.surface)==binding.copy:
			mesh.set_surface_override_material(binding.surface,binding.previous)
	bindings.clear()
	if is_instance_valid(manager): manager.remove_light(WorldGlow.GROUP_CASTING,get_instance_id())
	if is_instance_valid(anchor): anchor.queue_free()

func _exit_tree() -> void: _restore()
