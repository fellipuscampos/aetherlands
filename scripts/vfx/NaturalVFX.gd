extends RefCounted

const FLOW := preload("res://assets/vfx/schools/flow_particle.gdshader")
const RIBBON := preload("res://assets/vfx/schools/energy_ribbon.gdshader")
const CLOUD := preload("res://assets/vfx/schools/cloud_volume.gdshader")
const STORM_CLOUD := preload("res://assets/vfx/schools/storm_cloud.gdshader")
const WARD := preload("res://assets/vfx/schools/ward_surface.gdshader")

static func material(color: Color, kind: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FLOW
	mat.set_shader_parameter("color",color)
	mat.set_shader_parameter("kind",kind)
	return mat

static func sprite(parent: Node3D, size: Vector2, color: Color, kind: int = 0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color,kind)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func opacity(node: Node3D, value: float) -> void:
	if node.has_method("set_vfx_opacity"): node.set_vfx_opacity(value)
	if node is MeshInstance3D:
		var mat: Material = node.material_override
		if mat is ShaderMaterial: mat.set_shader_parameter("opacity",value)
		elif mat is StandardMaterial3D:
			if not mat.has_meta("natural_alpha"): mat.set_meta("natural_alpha",mat.albedo_color.a)
			mat.albedo_color.a = float(mat.get_meta("natural_alpha"))*value
	if node is MultiMeshInstance3D and node.multimesh!=null:
		var mat: Material = node.multimesh.mesh.material
		if mat is ShaderMaterial: mat.set_shader_parameter("opacity",value)
	if node is GPUParticles3D and node.draw_pass_1!=null:
		var mat: Material = node.draw_pass_1.material
		if mat is ShaderMaterial: mat.set_shader_parameter("opacity",value)
	for child in node.get_children():
		if child is Node3D: opacity(child,value)

static func particles(parent: Node3D, amount: int, color: Color, radius: float, height: float, kind: int = 0, continuous: bool = false) -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.amount = amount
	node.lifetime = 1.2 if kind!=1 else .8
	node.one_shot = not continuous
	node.explosiveness = 0.0 if continuous else .65
	node.randomness = .35
	node.local_coords = true
	node.visibility_aabb = AABB(Vector3(-3,-2,-3),Vector3(6,8,6))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(.26,.48) if kind==1 else Vector2(.18,.18) if kind==2 else Vector2(.065,.065)
	quad.material = material(color,kind)
	quad.material.set_shader_parameter("use_particle_color",true)
	node.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(radius,height*.25,radius)
	process.direction = Vector3.UP
	process.spread = 22
	process.initial_velocity_min = .25
	process.initial_velocity_max = .80 if kind!=1 else 1.1
	process.gravity = Vector3.ZERO
	process.scale_min = .55
	process.scale_max = 1.35
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0))
	fade.add_point(.15,Color.WHITE)
	fade.add_point(.6,Color(1,1,1,.8))
	fade.set_color(1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	node.process_material = process
	node.emitting = continuous
	parent.add_child(node)
	return node

static func ribbon(parent: Node3D, points: PackedVector3Array, width: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var tangent := (points[i+1]-points[i]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		if side.length_squared()<.01: side = Vector3.RIGHT
		var a := points[i]-side*width*.5
		var b := points[i]+side*width*.5
		var c := points[i+1]+side*width*.5
		var d := points[i+1]-side*width*.5
		var u := float(i)/maxi(1,points.size()-1)
		var v := float(i+1)/maxi(1,points.size()-1)
		for vertex in [[a,Vector2(u,0)],[b,Vector2(u,1)],[c,Vector2(v,1)],[a,Vector2(u,0)],[c,Vector2(v,1)],[d,Vector2(v,0)]]:
			st.set_uv(vertex[1])
			st.add_vertex(vertex[0])
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = RIBBON
	mat.set_shader_parameter("color",color)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func spiral(parent: Node3D, radius: float, height: float, color: Color, turns: float = 1.3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	var points := PackedVector3Array()
	for i in 49:
		var t := i/48.0
		var angle := t*TAU*turns
		points.append(Vector3(sin(angle)*radius,t*height,cos(angle)*radius))
	ribbon(node,points,.07,color)
	return node

static func cloud_bank(parent: Node3D, color: Color, scale_size: float = 1.0) -> MultiMeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat := ShaderMaterial.new()
	mat.shader = CLOUD
	mat.set_shader_parameter("color",color)
	sphere.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = 7
	var positions := [Vector3(-.40,0,.04),Vector3(.37,.04,.05),Vector3(0,.12,0),Vector3(-.18,-.05,.26),Vector3(.20,0,-.22),Vector3(-.24,.03,-.20),Vector3(.05,.18,.08)]
	for i in 7:
		var size := Vector3(.70,.40,.65)*scale_size*(1.0+float(i%3)*.12)
		multi.set_instance_transform(i,Transform3D(Basis.from_scale(size),positions[i]*scale_size))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

## Camada de tempestade angular e rasa. O vapor arredondado de cloud_bank continua exclusivo da névoa;
## a tempestade usa cinco blocos finos em uma única submissão, sem esferas sobrepostas ou deformação por frame.
static func storm_cloud_bank(parent: Node3D, cell: Vector2i, radius: float = 1.0) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := ShaderMaterial.new()
	mat.shader = STORM_CLOUD
	mesh.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = 5
	var sizes := [Vector3(1.00,.14,.47),Vector3(.70,.20,.50),Vector3(.55,.12,.40),Vector3(.45,.10,.32),Vector3(.34,.12,.30)]
	var positions := [Vector3(-.12,0,.03),Vector3(.30,.08,-.09),Vector3(-.45,.04,-.15),Vector3(.57,.02,.13),Vector3(-.06,.08,.29)]
	var seed_value := posmod(cell.x*17+cell.y*31,11)
	var yaw := float(seed_value%3)*PI/3.0
	var rotation := Basis(Vector3.UP,yaw)
	for i in multi.instance_count:
		var size: Vector3 = sizes[i]*radius
		var position: Vector3 = rotation*(positions[i]*radius)
		multi.set_instance_transform(i,Transform3D(rotation*Basis.from_scale(size),position))
		var tint := .88+float((i+seed_value)%4)*.055
		multi.set_instance_color(i,Color(tint,tint,tint,1.0))
	var node := MultiMeshInstance3D.new()
	node.name = "StormCloudVeil"
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func rain(parent: Node3D, height: float = 2.5) -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.amount = 18 if Settings.reduced_motion else 36
	node.lifetime = height/4.4
	node.local_coords = true
	node.visibility_aabb = AABB(Vector3(-1,-height,-1),Vector3(2,height+1,2))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(.05,-1,.04)
	process.initial_velocity_min = 4.2
	process.initial_velocity_max = 4.8
	process.spread = 3
	process.gravity = Vector3.ZERO
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(.62,.02,.55)
	process.particle_flag_align_y = true
	node.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(.008,.17)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(.73,.85,.94,.40)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	node.draw_pass_1 = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func rock(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 7
	mesh.rings = 3
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	node.material_override = mat
	parent.add_child(node)
	return node
