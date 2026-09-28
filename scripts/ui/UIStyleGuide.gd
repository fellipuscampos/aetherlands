class_name UIStyleGuide
extends Control

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	theme = UITheme.build()
	_build_catalog()

func _build_catalog() -> void:
	var background := ColorRect.new()
	background.color = UIThemeTokens.COLOR_CANVAS
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UIThemeTokens.SPACE_8)
	margin.add_theme_constant_override("margin_right", UIThemeTokens.SPACE_8)
	margin.add_theme_constant_override("margin_top", UIThemeTokens.SPACE_6)
	margin.add_theme_constant_override("margin_bottom", UIThemeTokens.SPACE_6)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIThemeTokens.SPACE_4)
	margin.add_child(root)
	var title := Label.new()
	title.text = "Aetherlands — UI Foundation"
	title.theme_type_variation = &"HeadingLabel"
	root.add_child(title)
	var typography := HBoxContainer.new()
	typography.add_theme_constant_override("separation", UIThemeTokens.SPACE_4)
	root.add_child(typography)
	for definition in [["H2", &"SubheadingLabel"], ["H3 / seção", &"SectionLabel"], ["Body", &""], ["Body small", &"BodySmallLabel"], ["Caption", &"CaptionLabel"]]:
		var sample := Label.new()
		sample.text = definition[0]
		sample.theme_type_variation = definition[1]
		typography.add_child(sample)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	root.add_child(buttons)
	for definition in [["Primário", AEButton.Kind.PRIMARY], ["Secundário", AEButton.Kind.SECONDARY], ["Perigo", AEButton.Kind.DANGER], ["Ghost", AEButton.Kind.GHOST]]:
		var button := AEButton.new()
		button.text = definition[0]
		button.kind = definition[1]
		buttons.add_child(button)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	root.add_child(chips)
	for definition in [["Pronto", AEStatusChip.Tone.POSITIVE], ["Bloqueado", AEStatusChip.Tone.NEGATIVE], ["Informativo", AEStatusChip.Tone.NEUTRAL]]:
		var chip := AEStatusChip.new()
		chips.add_child(chip)
		chip.set_status(definition[0], definition[1], 2 if definition[0] == "Bloqueado" else -1)
	var badge := AEBadge.new()
	badge.text = "7"
	badge.tooltip_text = "Eventos não lidos"
	chips.add_child(badge)
	var surface := AEPanel.new()
	surface.surface = AEPanel.Surface.ELEVATED
	root.add_child(surface)
	var surface_row := HBoxContainer.new()
	surface_row.add_theme_constant_override("separation", UIThemeTokens.SPACE_6)
	surface.add_child(surface_row)
	var section := AESectionHeader.new()
	section.custom_minimum_size.x = 260
	surface_row.add_child(section)
	section.set_title("Surface elevada")
	for definition in [["Ouro", "120", "+8 por turno"], ["Mana", "45", "+3 por turno"]]:
		var stat := AEStatDisplay.new()
		surface_row.add_child(stat)
		stat.set_stat(definition[0], definition[1], definition[2])
	var abilities := HBoxContainer.new()
	abilities.add_theme_constant_override("separation", UIThemeTokens.SPACE_2)
	root.add_child(abilities)
	for definition in [["Muralha", AEAbilityButton.AbilityState.AVAILABLE, 0], ["Saraivada", AEAbilityButton.AbilityState.SELECTED, 0], ["Bombardeio", AEAbilityButton.AbilityState.COOLDOWN, 3], ["Passiva", AEAbilityButton.AbilityState.PASSIVE, 0]]:
		var ability := AEAbilityButton.new()
		abilities.add_child(ability)
		ability.configure(definition[0], definition[1], definition[2], "1 ação")
	var progress := AEProgressBar.new()
	root.add_child(progress)
	progress.set_progress("Pesquisa — 72 / 100", 72, 100)
	var modal := AEModalFrame.new()
	modal.custom_minimum_size = Vector2(520, 180)
	root.add_child(modal)
	modal.set_title("Exemplo de modal")
	var body := Label.new()
	body.text = "Hierarquia, contraste, foco e captura de entrada centralizados."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body_host.add_child(body)
