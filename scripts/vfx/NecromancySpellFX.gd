extends "res://scripts/vfx/SchoolCastFX.gd"

func palette() -> Array[Color]: return [Color("ac83df"),Color("c8e2b1")]
func focus_kind() -> String: return "skull"

func build_spell() -> void:
	name = "NecromancyCast"
	add_seal(center,0,.65)
	var legion: bool = spell.id=="v2_spell_raise_legion"
	var kind := "sword" if spell.applies_status() else "skull"
	var event := add_burst(center,kind,40 if legion else 26,0,1.25 if legion else .9)
	event.souls = []
	event.bones = []
	Natural.spiral(event.node,.58,1.45,Color(primary,.65),1.4)
	for i in (10 if legion else 6):
		var soul := Natural.sprite(event.node,Vector2(.16,.30),primary,4)
		event.souls.append(soul)
	if spell.is_summon():
		for i in (8 if legion else 4):
			var bone := Natural.rock(event.node,Vector3(.045,.22,.045),accent)
			bone.rotation.z = (i%2)*PI*.5
			event.bones.append(bone)
	for receipt in outcomes:
		if receipt.has("unit") and (spell.is_summon() or spell.applies_status() or float(receipt.get("heal",0))>0):
			add_body(receipt,primary,accent)

func animate_event(event: Dictionary, time: float) -> void:
	if not event.has("souls"): return
	var progress := clampf(time/1.3,0,1)
	for i in event.souls.size():
		var angle: float = TAU*i/event.souls.size()+(time*.7 if not Settings.reduced_motion else 0.0)
		var radius := .55*(1-progress*.65)
		event.souls[i].position = Vector3(sin(angle)*radius,.15+progress*.95,cos(angle)*radius)
	for i in event.bones.size():
		var angle: float = TAU*i/event.bones.size()
		event.bones[i].position = Vector3(sin(angle)*.38,.05+progress*.75,cos(angle)*.38)
		event.bones[i].scale.y = .22*(.25+progress*.75)
