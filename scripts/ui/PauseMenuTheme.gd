extends RefCounted

## Local to the pause surface. Reuses imported menu textures; no animated background.
const BASE := preload("res://scripts/ui/FantasyMenuTheme.gd")

static func build(factor: float) -> Theme:
	var result := BASE.build(factor)
	for role in ["PauseTitle","PauseKicker","PauseBody","PauseMuted"]:
		result.set_type_variation(role,"Label")
		var font_size: int = {"PauseTitle":32,"PauseKicker":14,"PauseBody":16,"PauseMuted":14}[role]
		result.set_font_size("font_size",role,roundi(font_size*factor))
		result.set_font("font",role,ThemeDB.fallback_font if role in ["PauseBody","PauseMuted"] else result.default_font)
		result.set_color("font_color",role,Color("b6c5bb") if role=="PauseMuted" else Color("f3d39b") if role in ["PauseTitle","PauseKicker"] else Color("f4e9d3"))
	result.set_type_variation("PausePanel","PanelContainer")
	var frame := BASE.panel(false,factor)
	frame.set_content_margin_all(22*factor)
	result.set_stylebox("panel","PausePanel",frame)
	for role in ["PauseButton","PausePrimaryButton","PauseUtilityButton","PauseExitButton"]:
		result.set_type_variation(role,"SetupSmallButton")
		result.set_font_size("font_size",role,roundi((18 if role=="PauseUtilityButton" else 20)*factor))
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var stem := "button_bronze" if role=="PausePrimaryButton" else "button_stone"
			if state in ["hover","hover_pressed"]: stem += "_hover"
			elif state=="pressed": stem += "_pressed"
			elif state=="disabled": stem = "button_disabled"
			elif state=="focus": stem = "button_focus"
			result.set_stylebox(state,role,BASE.BASE._button(stem,factor))
	result.set_color("font_color","PauseUtilityButton",Color("b6c5bb"))
	result.set_color("font_color","PauseExitButton",Color("eabda7"))
	return result
