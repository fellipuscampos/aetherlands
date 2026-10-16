extends "res://scripts/vfx/SchoolCastFX.gd"

func palette() -> Array[Color]: return [Color("e86142"),Color("ffd382")]
func focus_kind() -> String: return "flame"

func build_spell() -> void:
	name = "InfernalCast"
	var blast: bool = spell.splash_radius>0
	var cells: Array[Vector2i] = [center]
	if blast: cells.append_array(HexMetrics.coords_within(center,spell.splash_radius))
	for coord in cells:
		if not grid.tiles.has(coord): continue
		add_seal(coord,0 if coord==center else .12,.83 if blast else .55)
	for receipt in outcomes:
		if not receipt.has("unit"): continue
		var event := add_burst(receipt.coord,"flame",32,.0,1.3 if blast else .9)
		event.kind = "eruption" if blast else "fire"
		event.flames = []
		var count := 4 if spell.id=="v2_spell_devouring_fire" else 6
		for i in count:
			var flame: Node3D = Shapes.glyph(event.node,"flame",primary,accent,.95)
			flame.position = Vector3(sin(TAU*i/count)*.55,.15,cos(TAU*i/count)*.55)
			event.flames.append(flame)
		add_body(receipt,Color("af483e"),accent)
	if spell.id=="v2_spell_damnation":
		var event := add_burst(center,"flame",44,0,1.5)
		event.kind = "damnation"
		event.meteor = Shapes.glyph(event.node,"flame",primary,accent,1.5)
		event.meteor.position.y = 3.5
		event.glyph.position.y = 1.2
		for i in 4:
			var plume := Natural.particles(event.node,8,primary,.12,.12,1,true)
			plume.position = Vector3(sin(i*PI/2)*.45,.15,cos(i*PI/2)*.45)

func animate_event(event: Dictionary, time: float) -> void:
	if event.has("flames"):
		for i in event.flames.size():
			var flame: Node3D = event.flames[i]
			if not Settings.reduced_motion:
				flame.position.y = .15+fposmod(maxf(0,time)*.65+i*.17,1)*.9
				flame.rotation.z = sin(time*2+i)*.12
	if event.kind=="damnation":
		event.meteor.position.y = lerpf(3.5,.15,smoothstep(0,.35,maxf(0,time)))
		event.meteor.visible = time<.45
