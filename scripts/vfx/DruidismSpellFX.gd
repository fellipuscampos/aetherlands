extends "res://scripts/vfx/SchoolCastFX.gd"

var growing: Array[WeakRef] = []

func palette() -> Array[Color]: return [Color("89c77b"),Color("e4d9a0")]
func focus_kind() -> String: return "leaf"

func build_spell() -> void:
	name = "DruidismCast"
	for coord in affected_cells():
		var delay := HexMetrics.axial_distance(center,coord)*.12
		add_seal(coord,delay,.82)
		var raised: bool = spell.id=="v2_spell_raise_ground"
		var event := add_burst(coord,"leaf",24,delay,.9)
		event.kind = "earth" if raised else "restoration" if spell.remove_terrain_modification else "growth"
		event.sprouts = []
		for i in 6:
			var angle := TAU*i/6.0
			var sprout: Node3D
			if raised:
				sprout = Natural.rock(event.node,Vector3(.18,.14,.17),Color("aa9878"))
			else:
				sprout = Shapes.glyph(event.node,"leaf",primary,accent,.50)
				sprout.rotation.z = i*.4
			sprout.position = Vector3(sin(angle)*.50,.05,cos(angle)*.50)
			event.sprouts.append(sprout)
		var marker: Node3D = grid._terrain_modification_markers.get(coord)
		if is_instance_valid(marker) and not spell.remove_terrain_modification:
			growing.append(weakref(marker))
			if not Settings.reduced_motion: marker.scale.y = .18

func animate_event(event: Dictionary, time: float) -> void:
	if not event.has("sprouts"): return
	for i in event.sprouts.size():
		var sprout: Node3D = event.sprouts[i]
		if Settings.reduced_motion: continue
		var progress := clampf(time/1.2,0,1)
		if event.kind=="earth":
			sprout.position.y = .05+sin(progress*PI)*.5
			sprout.rotation.y = progress*.6+i
		else:
			sprout.position.y = .05+progress*.65
			sprout.rotation.z = sin(time*1.6+i)*.25
			if event.kind=="restoration": sprout.position.x = sin(i*TAU/6)*(.5+progress*.25)
	for ref in growing:
		var marker: Node3D = ref.get_ref()
		if is_instance_valid(marker): marker.scale.y = 1.0 if Settings.reduced_motion else .18+smoothstep(0,1.1,maxf(0,age-arrival))*.82

func _exit_tree() -> void:
	for ref in growing:
		var marker: Node3D = ref.get_ref()
		if is_instance_valid(marker): marker.scale.y = 1.0
	super._exit_tree()
