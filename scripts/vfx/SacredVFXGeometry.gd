extends RefCounted

const GOLD := Color("f4cf73")
const IVORY := Color("fff1c2")
const MANA := Color("94ded5")
const BODY_SHADER := preload("res://assets/vfx/sacred/body_restore.gdshader")
const FocusProfiles := preload("res://scripts/vfx/SacredFocusProfiles.gd")
const OtherFocusProfiles := preload("res://scripts/vfx/SchoolFocusProfiles.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
static var box_mesh: BoxMesh

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		box_mesh.size = Vector3.ONE
	var node := MeshInstance3D.new()
	node.mesh = box_mesh
	node.scale = size
	node.position = pos
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func opacity(node: Node3D, alpha: float) -> void:
	Natural.opacity(node,clampf(alpha,0,1))

static func sun(parent: Node3D, radius: float) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	box(node, Vector3(.20,.20,.05) * radius, IVORY).rotation.z = PI / 4.0
	for i in 8:
		var angle := TAU * i / 8.0
		var ray := box(node, Vector3(.055,.11,.045) * radius, GOLD, Vector3(sin(angle),cos(angle),0) * .22 * radius)
		ray.rotation.z = -angle
	return node

static func shield(parent: Node3D, size: float) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	# A stepped shield: broad shoulders, square corners, tapered bottom.
	for row in 5:
		var width: float = [.34,.42,.42,.30,.16][row]
		box(node, Vector3(width,.075,.026) * size, GOLD, Vector3(0,(2-row)*.075,0) * size)
	box(node, Vector3(.044,.20,.032) * size, IVORY, Vector3(0,.026,.023) * size)
	box(node, Vector3(.15,.044,.032) * size, IVORY, Vector3(0,.045,.023) * size)
	return node

static func seal(parent: Node3D, grid: Node3D, coord: Vector2i, radius: float, complete: bool = false, color: Color = GOLD, accent: Color = IVORY) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.global_position = grid.world_surface_for_coord(coord)
	node.position.y += .035
	var points := PackedVector3Array()
	for i in 97:
		var pos: Vector3
		if complete:
			var side := mini(5,i/16)
			pos = HexMetrics.corner(radius,side).lerp(HexMetrics.corner(radius,(side+1)%6),float(i-side*16)/16)
		else:
			var angle := TAU*i/96.0
			pos = Vector3(sin(angle)*radius,0,cos(angle)*radius)
		var world := ground_point(grid,coord,pos)
		points.append(Vector3(pos.x,world.y-node.global_position.y,pos.z))
	Natural.ribbon(node,points,.055,Color(color,.38))
	return node

static func ground_point(grid: Node3D, coord: Vector2i, offset: Vector3) -> Vector3:
	var center: Vector3 = grid.world_for_coord(coord)
	var height: float = grid.surface_height_at(coord,Vector2(offset.x,offset.z))
	var tile: Resource = grid.get_tile(coord)
	if tile != null and tile.can_be_embarked_on(): height = maxf(height,float(grid.world_surface_for_coord(coord).y))
	return Vector3(center.x+offset.x,height+.035,center.z+offset.z)

static func anchor(unit: Node3D, focus: bool = false) -> Dictionary:
	var skeletons := unit.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = skeletons[0] if not skeletons.is_empty() else null
	var height: float = maxf(.8, float(unit._marker_height) - .12)
	if unit.is_boat_visual():
		return {"unit":weakref(unit),"skeleton":null,"bone":-1,"offset":Vector3.ZERO,"height":height,"release":1.1}
	var model_path: String = unit.unit_data.model_scene_path
	if "dwarf" in model_path: height = 1.3
	elif "orc" in model_path: height = 2.0
	elif "cleric" in model_path: height = 1.8
	elif "manifestation" in unit.unit_data.visual_kind: height = 3.0
	var model_name := model_path.get_file().get_basename()
	var profile: Dictionary = FocusProfiles.PROFILES.get(model_name, OtherFocusProfiles.PROFILES.get(model_name,{}))
	var bone: String = String(profile.get("bone", "chest")) if focus else "chest"
	var offset := Vector3.ZERO
	if focus and not profile.is_empty():
		var xyz: Array = profile.offset
		offset = Vector3(xyz[0],xyz[1],xyz[2])
	elif focus and unit.unit_data.glow_bone != "": bone = unit.unit_data.glow_bone
	var index := skeleton.find_bone(bone) if skeleton != null else -1
	return {"unit":weakref(unit),"skeleton":weakref(skeleton) if skeleton != null else null,"bone":index,"offset":offset,"height":height,"release":profile.get("release_seconds",1.1)}

static func anchor_position(info: Dictionary) -> Vector3:
	var unit: Node3D = info.unit.get_ref()
	if not is_instance_valid(unit): return Vector3.ZERO
	var skeleton: Skeleton3D = info.skeleton.get_ref() if info.skeleton != null else null
	if is_instance_valid(skeleton) and info.bone >= 0:
		return skeleton.global_transform * (skeleton.get_bone_global_pose(info.bone) * info.offset)
	return unit.global_position + Vector3.UP * float(info.height) * .58

static func particles(parent: Node3D, amount: int, color: Color, radius: float, height: float) -> GPUParticles3D:
	return Natural.particles(parent,amount,color,radius,height)
