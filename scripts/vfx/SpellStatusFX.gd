extends Node3D

const Art := preload("res://scripts/vfx/SacredVFXGeometry.gd")
const Shapes := preload("res://scripts/vfx/SchoolVFXArt.gd")
const MANAGED := ["v2_spell_macabre_command","v2_spell_silence"]
var status_id := ""
var age := 0.0
var glyphs: Array[Node3D] = []
var height := 1.8

static func sync(unit: Node3D) -> void:
	for id in MANAGED:
		var node_name: String = "SchoolStatus_"+id
		var existing := unit.get_node_or_null(node_name)
		var active := V2OwnerTurnEffect.is_active(unit.magic_status,id)
		if existing!=null and (not active or existing.is_queued_for_deletion()):
			unit.remove_child(existing)
			existing.queue_free()
			existing = null
		if active and existing==null:
			var effect: Node3D = load("res://scripts/vfx/SpellStatusFX.gd").new()
			effect.name = node_name
			unit.add_child(effect)
			effect.setup(unit,id)

func setup(unit: Node3D, id: String) -> void:
	status_id = id
	height = float(Art.anchor(unit).height)
	var kind := "sword" if id==MANAGED[0] else "silence"
	for side in [-1,1]:
		var glyph: Node3D = Shapes.glyph(self,kind,Color("ad83df"),Color("d0dfd8"),.60)
		glyph.position = Vector3(side*.37,height*.65,.26)
		glyphs.append(glyph)

func _process(delta: float) -> void:
	var unit := get_parent() as Node3D
	if unit==null or unit.hp<=0 or not V2OwnerTurnEffect.is_active(unit.magic_status,status_id):
		queue_free()
		return
	age += delta
	var camera := get_viewport().get_camera_3d()
	for i in glyphs.size():
		if camera!=null: glyphs[i].global_rotation.y = camera.global_rotation.y
		if not Settings.reduced_motion: glyphs[i].position.y = height*.65+sin(age*1.5+i)*.018
	Art.opacity(self,.68)
