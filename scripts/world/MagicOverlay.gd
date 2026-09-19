class_name MagicOverlay
extends Node3D

## Somente áreas mágicas ativas; reconstrução por mudança de estado/visibilidade.
const COLORS := {"sagrada": Color("f4da87"), "infernal": Color("f4774e"), "necromancia": Color("bd86e6"), "druidismo": Color("74d894"), "arcanismo": Color("86b9fc"), "elementalismo": Color("85e8ec")}
var _signature := 0

static func school_for_effect(effect: String) -> String:
	for school in MagicContent.EFFECTS:
		if effect in MagicContent.EFFECTS[school]:
			return school
	return "arcanismo"

## Titulo publico de uma area magica ativa (nivel do efeito dentro da escola).
## Compartilhado com TileInspector: o que o mapa rotula e o que o painel de
## inspecao mostra e' exatamente o mesmo texto.
static func region_title(region: Dictionary) -> String:
	var school := school_for_effect(region.effect)
	var effect_index: int = MagicContent.EFFECTS[school].find(region.effect)
	var level: int = [4, 5, 6, 7, 9][effect_index] if effect_index >= 0 else 1
	return MagicContent.SCHOOLS[school].names[level - 1]

func refresh(grid: HexGrid, observer: PlayerData) -> void:
	var items: Array = []
	for player in GameManager.players:
		for region in player.magic_effects:
			if int(region.expires) <= TurnManager.turn_number:
				continue
			var center := MagicRuntime.coord_of(region.center)
			var coords: Array = []
			for coord in [center] + grid.tiles_in_range(center, int(region.radius)):
				if player == observer or grid.visibility.get(coord, 0) == HexGrid.Visibility.VISIBLE:
					coords.append(coord)
			if not coords.is_empty():
				var school := school_for_effect(region.effect)
				var effect_index: int = MagicContent.EFFECTS[school].find(region.effect)
				var level: int = [4, 5, 6, 7, 9][effect_index] if effect_index >= 0 else 1
				var title: String = MagicContent.SCHOOLS[school].names[level - 1]
				items.append({"coords": coords, "center": center, "school": school, "text": "%s · %d turnos" % [title, int(region.expires) - TurnManager.turn_number], "label": center in coords})
		for ritual in player.rituals:
			if ritual.status == "channeling":
				var coord := MagicRuntime.coord_of(ritual.seat)
				# Rituais são anúncios mundiais; a sede é informação pública.
				items.append({"coords": [coord], "center": coord, "school": ritual.school, "text": "%s\n%s · %d/%d" % [player.civ.civ_name, ritual.spell, int(ritual.progress), int(ritual.turns)], "label": true})
		if player.arcane_ritual_active and GameManager.victory_rules_version >= 2:
			items.append({"coords": [player.arcane_ritual_city_coord], "center": player.arcane_ritual_city_coord, "school": "arcanismo", "text": "Transcendência · %d/7" % player.arcane_ritual_streak, "label": true})
	var signature := hash(items)
	if signature == _signature:
		return
	_signature = signature
	for child in get_children():
		child.free()
	var labels := {}
	for item in items:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLORS[item.school]
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
		for coord in item.coords:
			var center: Vector3 = grid.world_for_coord(coord) + Vector3.UP * 0.09
			for edge in range(6):
				for end in [edge, edge + 1]:
					var angle := deg_to_rad(30.0 + end * 60.0)
					mesh.surface_add_vertex(center + Vector3(cos(angle), 0, sin(angle)) * grid.hex_size * 0.87)
		mesh.surface_end()
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		if item.label:
			if labels.has(item.center):
				labels[item.center].text += "\n" + item.text
				continue
			var label := Label3D.new()
			label.text = item.text
			label.font_size = 22
			label.outline_size = 5
			label.pixel_size = 0.007
			label.modulate = COLORS[item.school]
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = grid.world_for_coord(item.center) + Vector3.UP * 3.4
			add_child(label)
			labels[item.center] = label
