extends RefCounted

const BASE := preload("res://scripts/ui/GameSetupTheme.gd")
const ART := "res://assets/ui/loading/"

static func build(factor: float) -> Theme:
	var result := BASE.build(factor)
	for state in ["background", "fill"]:
		var style := StyleBoxTexture.new()
		style.texture = load(ART + ("progress_track.svg" if state == "background" else "progress_fill.svg")) as Texture2D
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			style.set_texture_margin(side, 8)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			style.set_texture_margin(side, 8)
		result.set_stylebox(state, "ProgressBar", style)
	return result
