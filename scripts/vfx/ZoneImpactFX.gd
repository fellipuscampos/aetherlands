extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Shapes := preload("res://scripts/vfx/SchoolVFXArt.gd")
var grid: Node3D
var coord := Vector2i.ZERO
var body: Dictionary = {}
var age := 0.0
var bolt: Node3D

func setup(receipt: Dictionary, kind: String, map: Node3D) -> void:
	name = "EnvironmentalImpact"
	grid = map
	coord = receipt.coord
	global_position = receipt.position
	bolt = Shapes.bolt(self,3.1,Color("d5e6fa"))
	for side in [-1,1]:
		var arc: Node3D = Shapes.bolt(self,.8,Color("9ebfff"))
		arc.position = Vector3(side*.5,.65,0)
		arc.rotation.z = side*.35
	if kind=="cataclysm": Shapes.glyph(self,"elements",Color("ba95d9"),Color("dde8ee"),1.8).position.y = .6
	var particles: GPUParticles3D = Art.particles(self,10 if Settings.reduced_motion else 26,Color("b9c8ed"),.3,1.2)
	if SpellVFX.tile_visible(grid,coord):
		particles.restart()
		particles.emitting = true
	var unit: Node3D = receipt.unit.get_ref()
	if is_instance_valid(unit): body = Shapes.body(unit,Color("8ba7de"),Color("c1def0"))

func _process(delta: float) -> void:
	age += delta
	visible = SpellVFX.tile_visible(grid,coord)
	var camera := get_viewport().get_camera_3d()
	if camera!=null: bolt.global_rotation.y = camera.global_rotation.y
	Art.opacity(self,1-smoothstep(.15,.65,age))
	if not body.is_empty():
		var unit: Node3D = body.unit.get_ref()
		Shapes.body_update(body,(1-smoothstep(.2,.7,age))*.6 if SpellVFX.unit_visible(unit,grid) else 0.0,clampf(age/.7,0,1))
	if age>.95: queue_free()

func _exit_tree() -> void:
	if not body.is_empty(): Shapes.body_clear(body)
