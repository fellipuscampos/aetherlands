extends "res://scripts/vfx/SchoolCastFX.gd"

func palette() -> Array[Color]: return [Color("a397e7"),Color("bddbea")]
func focus_kind() -> String: return "rune"

func build_spell() -> void:
	name = "ArcanismCast"
	if spell.teleport_caster:
		release = .14
		arrival = .28
		duration = 1.8
		for coord in [origin,center]:
			add_seal(coord,0,.65)
			add_burst(coord,"rune",24,0,1.4)
		var caster: Node3D = caster_ref.get_ref()
		add_body(SpellVFX.receipt(caster,grid),primary,accent)
	elif spell.creates_portal_pair:
		for coord in [origin,center]:
			add_seal(coord,0,.65)
			add_burst(coord,"rune",28,0,1.3)
			var marker: Node3D = grid._v2_portal_markers.get(coord)
			if is_instance_valid(marker): marker.get_node("PortalVFX").pulse()
	else:
		add_seal(center,0,.55)
		var event := add_burst(center,"silence" if spell.silences_spellcasting else "rune",28,0,1.3)
		event.fragments = []
		for i in 6:
			var fragment := Natural.sprite(event.node,Vector2(.11,.22),accent,4)
			event.fragments.append(fragment)
		for receipt in outcomes:
			if receipt.has("unit"): add_body(receipt,primary,accent)

func animate_event(event: Dictionary, time: float) -> void:
	if not event.has("fragments"): return
	for i in event.fragments.size():
		var angle: float = TAU*i/event.fragments.size()
		var radius := .25+clampf(time,0,1)*(.50 if spell.dispel_at_tile else .08)
		event.fragments[i].position = Vector3(sin(angle)*radius,.8+cos(angle)*.2,cos(angle)*radius)
