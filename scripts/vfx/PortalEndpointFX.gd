extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Shapes := preload("res://scripts/vfx/SchoolVFXArt.gd")
const Natural := preload("res://scripts/vfx/NaturalVFX.gd")
var grid: Node3D
var coord := Vector2i.ZERO
var age := 0.0
var flash := 0.0
var frame: Node3D
var sparks: Array[MeshInstance3D] = []

func setup(map: Node3D, cell: Vector2i) -> void:
	name = "PortalVFX"
	grid = map
	coord = cell
	frame = Node3D.new()
	add_child(frame)
	var points := PackedVector3Array()
	for i in 65: points.append(Vector3(sin(TAU*i/64)*.44,.66+cos(TAU*i/64)*.59,0))
	Natural.ribbon(frame,points,.09,Color("939fee"))
	var veil := Natural.sprite(frame,Vector2(.86,1.18),Color("ba94e8"),6)
	veil.position.y = .66
	for i in 6: sparks.append(Natural.sprite(frame,Vector2.ONE*.055,Color("d5e5ed")))

func pulse() -> void: flash = .7

func _process(delta: float) -> void:
	visible = SpellVFX.tile_visible(grid,coord)
	if not is_visible_in_tree(): return
	age += delta
	flash = maxf(0,flash-delta)
	var camera := get_viewport().get_camera_3d()
	if camera!=null: frame.global_rotation.y = camera.global_rotation.y
	Art.opacity(frame,.60+flash*.5)
	for i in sparks.size():
		var phase := float(i)/sparks.size()+(age*.12 if not Settings.reduced_motion else 0.0)
		sparks[i].position = Vector3(sin(phase*TAU)*.25,.66+cos(phase*TAU)*.44,.035)
