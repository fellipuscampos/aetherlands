extends SceneTree

## Exporta os selos do jogo em QUALQUER lista de cores de reino — para escolher paleta, revisar legibilidade ou usar
## os PNG fora do jogo. Nada aqui é necessário para o jogo funcionar: em jogo o selo é composto na hora por
## IconCatalog.badge(pictograma, cor); esta ferramenta só chama a mesma função e grava o resultado.
##
## Uso (na raiz do projeto):
##   godot --headless --path . -s tools/art_pipeline/export_icon_variations.gd -- --out=C:/tmp/icones
##   godot --headless --path . -s tools/art_pipeline/export_icon_variations.gd -- --out=C:/tmp/icones --colors=#3373d9,#d9a520,#101014 --files
##
##   --out=<pasta>      onde gravar (obrigatório)
##   --colors=<lista>   cores base em hexadecimal, separadas por vírgula (padrão: as 4 civilizações + um leque de teste)
##   --files            grava também um PNG 128x128 por selo em <pasta>/<cor>/<selo>.png
##   --cell=<px>        lado de cada selo na folha de contato (padrão 72 — perto do tamanho em jogo)
##   --bg=<cor>         fundo da folha (padrão: verde de campina)
##
## Sempre grava <pasta>/sheet.png: uma linha por cor (todas as tropas), depois os monstros e os recursos.
##
## IconCatalog é carregado em `_initialize` (e não citado pelo nome): um script de SceneTree compila antes dos autoloads
## existirem, e o catálogo depende de Unit/PlayerData, que usam EventBus.

const DEFAULT_COLORS := [
	"#3373d9", "#8552b8", "#408c59", "#8c5a33", "#6b7a38", # jogador + Valmere, Verdemata, Ferroeste, Horda
	"#c62828", "#ef6c00", "#f9d71c", "#7cb342", "#00897b", "#29b6f6", "#283593", "#ad1457", "#f5f5f5", "#8d8d8d", "#15151a",
]

var catalog: GDScript

func _initialize() -> void:
	catalog = load("res://scripts/data/IconCatalog.gd")
	var options := {"colors": ",".join(DEFAULT_COLORS), "cell": "72", "bg": "#5c8048", "out": ""}
	var write_files := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--files":
			write_files = true
		elif argument.begins_with("--") and argument.contains("="):
			options[argument.get_slice("=", 0).trim_prefix("--")] = argument.get_slice("=", 1)
	if String(options.out).is_empty():
		push_error("informe --out=<pasta>")
		quit(1)
		return
	var out_dir := String(options.out).replace("\\", "/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var cell := int(options.cell)

	var troops := _troop_entries()
	var rows: Array = []
	var started := Time.get_ticks_usec()
	var composed := 0
	for hex in String(options.colors).split(",", false):
		var color := Color.from_string(hex.strip_edges(), Color.MAGENTA)
		var row: Array[Image] = []
		for entry in troops:
			var image: Image = catalog.badge(entry.glyph, color, entry.pips, entry.elite).get_image()
			composed += 1
			row.append(image)
			if write_files:
				var folder := "%s/%s" % [out_dir, color.to_html(false)]
				DirAccess.make_dir_recursive_absolute(folder)
				image.save_png("%s/%s.png" % [folder, entry.name])
		rows.append(row)
	var monsters: Array[Image] = []
	for species in catalog.MONSTER_GLYPHS:
		monsters.append(catalog.badge(catalog.MONSTER_GLYPHS[species], catalog.MONSTER_COLOR, 0, false, catalog.SHAPE_HEX).get_image())
		composed += 1
		if write_files:
			DirAccess.make_dir_recursive_absolute(out_dir + "/monsters")
			monsters[-1].save_png("%s/monsters/%s.png" % [out_dir, species])
	var resources: Array[Image] = []
	for resource_id in catalog.RESOURCE_ICONS:
		resources.append(catalog.resource_badge(resource_id).get_image())
		composed += 1
		if write_files:
			DirAccess.make_dir_recursive_absolute(out_dir + "/resources")
			resources[-1].save_png("%s/resources/%s.png" % [out_dir, resource_id])
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	rows.append(monsters + resources)

	var columns := 0
	for row in rows:
		columns = maxi(columns, row.size())
	var gap := 6
	var sheet := Image.create(gap + columns * (cell + gap), gap + rows.size() * (cell + gap), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.from_string(String(options.bg), Color(0.36, 0.5, 0.28)))
	for row_index in rows.size():
		for column in rows[row_index].size():
			var badge: Image = rows[row_index][column].duplicate()
			badge.clear_mipmaps()
			badge.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
			sheet.blend_rect(badge, Rect2i(0, 0, cell, cell), Vector2i(gap + column * (cell + gap), gap + row_index * (cell + gap)))
	sheet.save_png(out_dir + "/sheet.png")
	print("%d selo(s) em %.0f ms (%.2f ms cada, com o custo único das camadas) -> %s/sheet.png" % [composed, elapsed_ms, elapsed_ms / maxf(composed, 1), out_dir])
	quit()

## Toda tropa de reino: as seis classes nas três formas e a Lendária, as seis Escolas, as seis Grandes Manifestações
## e os civis.
func _troop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for branch in catalog.CLASS_GLYPHS:
		for pips in [1, 2, 3]:
			entries.append({"name": "%s_%d" % [branch, pips], "glyph": catalog.CLASS_GLYPHS[branch], "pips": pips, "elite": false})
		entries.append({"name": "%s_legendary" % branch, "glyph": catalog.CLASS_GLYPHS[branch], "pips": 0, "elite": true})
	for school in catalog.SCHOOL_GLYPHS:
		entries.append({"name": "mage_%s" % school, "glyph": catalog.SCHOOL_GLYPHS[school], "pips": 0, "elite": false})
	for kind in catalog.UNIT_GLYPHS:
		entries.append({"name": String(kind).trim_prefix("v2_unit_").trim_prefix("v2_"), "glyph": catalog.UNIT_GLYPHS[kind], "pips": 0, "elite": catalog.is_elite(kind)})
	return entries
