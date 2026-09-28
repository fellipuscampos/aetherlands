class_name AETooltip
extends RefCounted

## Schema comum de tooltip da UI-3. Toda superfície nova escreve o texto por
## `compose` e desenha por `make_card`, então habilidade, stat, produção, status,
## vitória e diplomacia leem igual: título, corpo, detalhes, motivo e atalho.
## O texto continua legível como tooltip nativo quando nenhum card é usado.

const DETAIL_PREFIX := "· "
const REASON_PREFIX := "▲ "
const SHORTCUT_PREFIX := "Tecla: "
const CARD_WIDTH := 300.0

static func compose(title: String, body: String = "", details: Array = [], reason: String = "", shortcut: String = "") -> String:
	var lines: Array[String] = []
	if not title.is_empty():
		lines.append(title)
	if not body.is_empty():
		lines.append(body)
	for detail in details:
		var text := String(detail)
		if not text.is_empty():
			lines.append(DETAIL_PREFIX + text)
	if not reason.is_empty():
		lines.append(REASON_PREFIX + reason)
	if not shortcut.is_empty():
		lines.append(SHORTCUT_PREFIX + shortcut)
	return "\n".join(lines)

## Card desenhado a partir do texto canônico; o painel externo vem do
## `TooltipPanel` do tema, por isso aqui só existe o conteúdo.
static func make_card(text: String) -> Control:
	if text.is_empty():
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIThemeTokens.SPACE_1)
	box.custom_minimum_size.x = CARD_WIDTH
	var lines := text.split("\n")
	for index in lines.size():
		var line := lines[index]
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = CARD_WIDTH
		if index == 0:
			label.text = line
			label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY)
			label.add_theme_color_override("font_color", UIThemeTokens.COLOR_ACCENT)
		elif line.begins_with(REASON_PREFIX):
			label.text = line
			label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
			label.add_theme_color_override("font_color", UIThemeTokens.COLOR_WARNING)
		elif line.begins_with(SHORTCUT_PREFIX):
			label.text = line
			label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_CAPTION)
			label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT_MUTED)
		else:
			label.text = line
			label.add_theme_font_size_override("font_size", UIThemeTokens.FONT_BODY_SMALL)
			label.add_theme_color_override("font_color", UIThemeTokens.COLOR_TEXT if not line.begins_with(DETAIL_PREFIX) else UIThemeTokens.COLOR_TEXT_MUTED)
		box.add_child(label)
	return box

static func reason_of(text: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(REASON_PREFIX):
			return line.trim_prefix(REASON_PREFIX)
	return ""
