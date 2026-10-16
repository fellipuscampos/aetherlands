extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
const STATUS := "v2_spell_sacred_aegis"
var age := 0.0
var plates: Array[Node3D] = []
var base: Node3D
var body_height := 1.8

func setup(unit: Node3D) -> void:
	name = "SacredAegis"
	body_height = float(Art.anchor(unit).height)
	base = Node3D.new()
	add_child(base)
	var points := PackedVector3Array()
	for i in 65: points.append(Vector3(sin(TAU*i/64)*.53,.08,cos(TAU*i/64)*.53))
	Natural.ribbon(base,points,.045,Art.GOLD)
	var shield := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .60
	sphere.height = body_height*1.12
	sphere.radial_segments = 32
	sphere.rings = 16
	shield.mesh = sphere
	shield.position.y = body_height*.52
	var mat := ShaderMaterial.new()
	mat.shader = Natural.WARD
	shield.material_override = mat
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)

func _process(delta: float) -> void:
	var unit := get_parent() as Node3D
	if unit == null or not V2OwnerTurnEffect.is_active(unit.magic_status, STATUS) or unit.hp <= 0:
		queue_free()
		return
	age += delta
	# Stationary protection, no spinning bubble or physical changes to the model.
	var pulse := .66 + sin(age*1.8)*.09
	Art.opacity(self,pulse)
	if not Settings.reduced_motion:
		for i in plates.size(): plates[i].position.y = body_height*.52 + sin(age*1.8+i*.5)*.022
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		for plate in plates: plate.global_rotation.y = camera.global_rotation.y
