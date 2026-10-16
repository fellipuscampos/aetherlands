extends RefCounted

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")

static func glyph(parent: Node3D, kind: String, color: Color, accent: Color, size: float = 1.0) -> Node3D:
	var natural = preload("res://scripts/vfx/NaturalVFX.gd")
	var node := Node3D.new()
	parent.add_child(node)
	match kind:
		"flame":
			var flame: MeshInstance3D = natural.sprite(node,Vector2(.55,.95),color,1)
			flame.position.y = .24
			flame.material_override.set_shader_parameter("hot_color",accent)
			natural.particles(node,8,color,.10,.08,1,true)
		"mist":
			natural.cloud_bank(node,Color(color,.18),.65)
		"gale":
			natural.spiral(node,.30,.40,Color(color,.32),1.2)
		"storm":
			natural.spiral(node,.25,.40,Color(color,.20),.65)
		"leaf":
			natural.sprite(node,Vector2(.22,.38),color,3).material_override.set_shader_parameter("hot_color",accent)
		"skull":
			natural.sprite(node,Vector2(.65,.85),Color(color,.60),4)
			natural.particles(node,7,Color(accent,.65),.15,.35,4,true)
		"sword":
			natural.sprite(node,Vector2(.07,.50),Color(accent,.45))
			natural.spiral(node,.21,.18,Color(color,.28),.75)
		"silence":
			natural.spiral(node,.29,.22,Color(color,.45),1.1)
		_:
			natural.sprite(node,Vector2(.55,.75),Color(color,.38),4)
			natural.spiral(node,.25,.30,Color(accent,.25),.8)
	node.scale = Vector3.ONE*size
	return node

static func line(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var along := (b-a).normalized()
	var across := along.cross(Vector3.UP)
	if across.length_squared()<.001: across = along.cross(Vector3.RIGHT)
	across = across.normalized()
	var node := Art.box(parent,Vector3.ONE,color,(a+b)*.5)
	node.basis = Basis(along*a.distance_to(b),across.cross(along)*width,across*width)
	return node

static func bolt(parent: Node3D, height: float, color: Color) -> Node3D:
	var node: Node3D = preload("res://scripts/vfx/LightningArcFX.gd").new()
	parent.add_child(node)
	node.setup(height,color)
	return node

static func body(unit: Node3D, color: Color, accent: Color) -> Dictionary:
	var overlay := ShaderMaterial.new()
	overlay.shader = Art.BODY_SHADER
	overlay.set_shader_parameter("base_color",color)
	overlay.set_shader_parameter("band_color",accent)
	var height: float = Art.anchor(unit).height
	overlay.set_shader_parameter("body_height",height)
	var meshes: Array[WeakRef] = []
	if is_instance_valid(unit._visual_root):
		for mesh in unit._visual_root.find_children("*","MeshInstance3D",true,false): meshes.append(weakref(mesh))
	return {"unit":weakref(unit),"overlay":overlay,"meshes":meshes,"height":height}

static func body_update(info: Dictionary, strength: float, progress: float) -> void:
	var unit: Node3D = info.unit.get_ref()
	info.overlay.set_shader_parameter("floor_y",unit.global_position.y if is_instance_valid(unit) and unit.is_inside_tree() else 0.0)
	info.overlay.set_shader_parameter("progress",progress)
	info.overlay.set_shader_parameter("strength",strength)
	for ref in info.meshes:
		var mesh: MeshInstance3D = ref.get_ref()
		if not is_instance_valid(mesh): continue
		if strength>0 and (mesh.material_overlay==null or mesh.material_overlay==info.overlay): mesh.material_overlay = info.overlay
		elif strength<=0 and mesh.material_overlay==info.overlay: mesh.material_overlay = null

static func body_clear(info: Dictionary) -> void:
	for ref in info.meshes:
		var mesh: MeshInstance3D = ref.get_ref()
		if is_instance_valid(mesh) and mesh.material_overlay==info.overlay: mesh.material_overlay = null
