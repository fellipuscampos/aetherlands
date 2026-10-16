extends "res://scripts/vfx/SchoolCastFX.gd"

var kind := ""

func palette() -> Array[Color]:
	match spell.environmental_zone_id:
		"v2_zone_dense_mist": return [Color("b5cedd"),Color("edf2ed")]
		"v2_zone_gale": return [Color("87d8d0"),Color("e4f0d5")]
		"v2_zone_lightning_storm": return [Color("9aaee9"),Color("d6e4f0")]
		_: return [Color("c09bda"),Color("e9d5af")]

func focus_kind() -> String: return "elements"

func build_spell() -> void:
	name = "ElementalismCast"
	kind = V2EnvironmentalZoneDatabase.get_zone(spell.environmental_zone_id).visual_kind
	for coord in affected_cells():
		var delay := HexMetrics.axial_distance(center,coord)*.10
		add_seal(coord,delay,.86)
		var event := add_burst(coord,kind if kind!="cataclysm" else "elements",18,delay,1.3)
		event.kind = kind
		# The persistent field supplies rain, clouds and wind after this formation pulse.
		Natural.particles(event.node,5,primary,.50,.3,2)
