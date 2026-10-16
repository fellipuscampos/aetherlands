extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Shapes := preload("res://scripts/vfx/SchoolVFXArt.gd")
var grid: Node3D
var ends: Array[Dictionary] = []
var body: Dictionary
var age := 0.0

func setup(unit: Node3D, from: Vector2i, to: Vector2i, map: Node3D) -> void:
	name = "ArcaneTransit"
	grid = map
	body = Shapes.body(unit,Color("8e97e7"),Color("d5e6f1"))
	for coord in [from,to]:
		var seal: Node3D = Art.seal(self,grid,coord,.55,true,Color("9a97e8"),Color("d7e5ed"))
		var sparks: GPUParticles3D = Art.particles(seal,10 if Settings.reduced_motion else 20,Color("b2c9ed"),.25,1)
		if SpellVFX.tile_visible(grid,coord):
			sparks.restart()
			sparks.emitting = true
		ends.append({"node":seal,"coord":coord})

func _process(delta: float) -> void:
	age += delta
	for end in ends:
		end.node.visible = SpellVFX.tile_visible(grid,end.coord)
		Art.opacity(end.node,1-smoothstep(.20,.85,age))
	var unit: Node3D = body.unit.get_ref()
	Shapes.body_update(body,(1-smoothstep(.15,.75,age))*.75 if SpellVFX.unit_visible(unit,grid) else 0.0,clampf(age/.8,0,1))
	if age>1.05: queue_free()

func _exit_tree() -> void:
	if not body.is_empty(): Shapes.body_clear(body)
