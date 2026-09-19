class_name MagicSchoolBoard
extends TechTree

const COLORS := [Color("e9d68b"), Color("e17a65"), Color("b691d9"), Color("86bc8b"), Color("86b6e5"), Color("76d0cf")]

func rebuild(researched: Dictionary, current_research: String, research_progress: float, _race: String = "human") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_node_rects.clear()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	add_child(layout)
	var explanation := Label.new()
	explanation.text = "Seis escolas independentes • cada nível exige o anterior • magia e tecnologia compartilham ciência"
	explanation.add_theme_color_override("font_color", Color("aeb6c6"))
	layout.add_child(explanation)
	var rows := GridContainer.new()
	rows.columns = 6
	rows.add_theme_constant_override("h_separation", 10)
	rows.add_theme_constant_override("v_separation", 10)
	layout.add_child(rows)
	var available := MagicDatabase.available_techs(researched).map(func(t): return t.id)
	var schools := MagicContent.SCHOOLS.keys()
	for index in range(6):
		var title := Label.new()
		title.text = "%s · %d/9" % [MagicContent.SCHOOLS[schools[index]].name, MagicDatabase.school_level(schools[index], researched)]
		title.add_theme_color_override("font_color", COLORS[index])
		rows.add_child(title)
	for tier in range(1, 10):
		for index in range(6):
			var tech := MagicDatabase.get_tech("%s_%d" % [schools[index], tier])
			rows.add_child(_card(tech, researched, available, current_research, research_progress, COLORS[index]))
	var final := MagicDatabase.get_tech("transcendencia_arcana")
	layout.add_child(_card(final, researched, available, current_research, research_progress, Color("d5bd83")))
	custom_minimum_size = Vector2(1190, 1560)
	layout.size = custom_minimum_size
	queue_redraw()

func _card(tech: TechData, researched: Dictionary, available: Array, current: String, progress: float, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 144)
	var active := tech.id == current
	var complete := researched.has(tech.id)
	var unlocked := tech.id in available
	var style := StyleBoxFlat.new()
	style.bg_color = Color("222a37") if unlocked else Color("151923")
	style.border_color = Color("83b58c") if complete else (Color("d5bd83") if active else accent.darkened(0.45))
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = tech.effect_text
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "N%d · %s" % [tech.tier, tech.display_name]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(165, 48)
	title.add_theme_color_override("font_color", Color("e5e7ec"))
	box.add_child(title)
	var state := Label.new()
	state.add_theme_color_override("font_color", accent)
	state.text = "Concluída" if complete else ("%d / %d ciência" % [int(progress), int(tech.cost)] if active else "%d ciência" % int(tech.cost))
	box.add_child(state)
	var button := Button.new()
	button.text = "Pesquisando" if active else ("Concluída" if complete else ("Pesquisar" if unlocked else "Requer N%d" % (tech.tier - 1)))
	if tech.tier == 10 and not unlocked and not complete:
		button.text = "Duas escolas no N9"
	button.disabled = not unlocked or active
	button.pressed.connect(func(): tech_selected.emit(tech.id))
	box.add_child(button)
	return panel
