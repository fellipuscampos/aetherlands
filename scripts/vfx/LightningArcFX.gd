extends Node3D

const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
var height := 2.5
var color := Color("c8e0ff")
var timer := 0.0
var frame := 0
var geometry: Node3D
var opacity_gain := 1.0

func set_vfx_opacity(value: float) -> void: opacity_gain = value

func setup(length: float, tint: Color) -> void:
	height = length
	color = tint
	_rebuild()

func _process(delta: float) -> void:
	if Settings.reduced_motion or not is_visible_in_tree(): return
	timer += delta
	if timer>=.075:
		timer = 0
		frame += 1
		_rebuild()

func _rebuild() -> void:
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	add_child(geometry)
	var points := PackedVector3Array()
	for i in 13:
		var t := i/12.0
		var jitter := sin(i*4.13+frame*2.71)*.16*sin(t*PI)
		points.append(Vector3(jitter,height*(1-t),cos(i*3.2+frame)*.07*sin(t*PI)))
	_tube(points,.014,Color("f0f5ff"))
	_tube(points,.044,Color(color,.28))
	for branch in 3:
		var start := points[3+branch*2]
		var fork := PackedVector3Array([start,start+Vector3((branch%2*2-1)*.25,-.13,.03),start+Vector3((branch%2*2-1)*.55,-.38,.12)])
		_tube(fork,.008,Color(color,.75))

func _tube(points: PackedVector3Array, width: float, tint: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var along := (points[i+1]-points[i]).normalized()
		var across := along.cross(Vector3.RIGHT).normalized()
		if across.length_squared()<.01: across = Vector3.FORWARD
		var other := along.cross(across).normalized()
		for side in 5:
			var a := across*cos(TAU*side/5)+other*sin(TAU*side/5)
			var b := across*cos(TAU*(side+1)/5)+other*sin(TAU*(side+1)/5)
			for v in [points[i]+a*width,points[i]+b*width,points[i+1]+b*width,points[i]+a*width,points[i+1]+b*width,points[i+1]+a*width]: st.add_vertex(v)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tint
	mat.set_meta("natural_alpha",tint.a)
	mat.albedo_color.a *= opacity_gain
	mat.emission_enabled = true
	mat.emission = Color(tint,1)
	mat.emission_energy_multiplier = 2.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(node)
