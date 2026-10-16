extends SceneTree

## Gera as MÁSCARAS dos pictogramas do jogo a partir dos SVG versionados.
##
##   tools/art_pipeline/icon_sources/svg/<id>.svg  ->  assets/icons/glyphs/<id>.png  (128x128, branco + alfa suavizado)
##                                                     assets/icons/CREDITS.txt      (crédito CC BY 3.0, obrigatório)
##
## Uso (na raiz do projeto), depois reimportar:
##   godot --headless --path . -s tools/art_pipeline/build_icon_glyphs.gd
##   godot --headless --path . --import
##
## A máscara NÃO tem cor: quem colore é IconCatalog, em tempo de execução, a partir da cor base do reino — por isso
## trocar/criar cor de reino nunca exige regerar arquivo. Cada desenho é recortado na sua caixa e encaixado na mesma
## moldura (GLYPH_FIT dentro de GLYPH_SIZE), para todos terem o mesmo peso visual dentro do selo.
## Para trocar um desenho: edite a linha em icon_sources/manifest.json, rode fetch_icon_sources.py e este script.

const SOURCE_DIR := "res://tools/art_pipeline/icon_sources/"
const OUT_DIR := "res://assets/icons/glyphs/"
const CREDITS_PATH := "res://assets/icons/CREDITS.txt"
## O fundo preto 512x512 que todo ícone do game-icons.net traz; sai, fica só o desenho branco.
const BACKGROUND_PATH := "<path d=\"M0 0h512v512H0z\"/>"
const GLYPH_SIZE := 128
const GLYPH_FIT := 120

func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_DIR + "manifest.json"))
	var glyphs: Dictionary = manifest.glyphs
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for glyph_id in glyphs:
		var image := _rasterize(String(glyph_id))
		if image == null:
			failed += 1
			continue
		image.save_png(OUT_DIR + String(glyph_id) + ".png")
	_remove_stale(glyphs)
	_write_credits(manifest)
	print("pictogramas: %d gerado(s), %d falha(s)" % [glyphs.size() - failed, failed])
	quit(1 if failed > 0 else 0)

func _rasterize(glyph_id: String) -> Image:
	var svg := FileAccess.get_file_as_string(SOURCE_DIR + "svg/" + glyph_id + ".svg")
	if svg.is_empty() or not svg.contains(BACKGROUND_PATH):
		push_error("%s: SVG ausente ou sem o fundo padrão do game-icons" % glyph_id)
		return null
	var source := Image.new()
	if source.load_svg_from_string(svg.replace(BACKGROUND_PATH, ""), 1.0) != OK:
		push_error("%s: SVG inválido" % glyph_id)
		return null
	source.convert(Image.FORMAT_RGBA8)
	var used := source.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		push_error("%s: desenho vazio" % glyph_id)
		return null
	var drawing := source.get_region(used)
	var factor := float(GLYPH_FIT) / float(maxi(used.size.x, used.size.y))
	var fitted := Vector2i(maxi(roundi(used.size.x * factor), 1), maxi(roundi(used.size.y * factor), 1))
	drawing.resize(fitted.x, fitted.y, Image.INTERPOLATE_LANCZOS)
	var image := Image.create(GLYPH_SIZE, GLYPH_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var origin := (Vector2i(GLYPH_SIZE, GLYPH_SIZE) - fitted) / 2
	# Só o alfa interessa: o RGB fica branco em todo pixel, para nenhuma borda escura aparecer ao tingir/filtrar.
	for y in fitted.y:
		for x in fitted.x:
			image.set_pixel(origin.x + x, origin.y + y, Color(1, 1, 1, drawing.get_pixel(x, y).a))
	return image

## Um id que saiu do manifesto não deixa PNG órfão para trás.
func _remove_stale(glyphs: Dictionary) -> void:
	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		var glyph_id := file_name.get_slice(".", 0)
		if file_name.get_extension() in ["png", "import"] and not glyphs.has(glyph_id):
			dir.remove(file_name)
			print("removido ", file_name)

func _write_credits(manifest: Dictionary) -> void:
	var by_author := {}
	for glyph_id in manifest.glyphs:
		var source := String(manifest.glyphs[glyph_id])
		var author := source.get_slice("/", 0)
		if not by_author.has(author):
			by_author[author] = []
		by_author[author].append("%s.png (\"%s\")" % [glyph_id, source.get_slice("/", 1)])
	var lines: PackedStringArray = [
		"Icones do jogo (assets/icons/glyphs) - creditos",
		"",
		"Os pictogramas sao derivados de icones de https://game-icons.net (github.com/game-icons/icons),",
		"licenciados sob Creative Commons Atribuicao 3.0 (%s)." % String(manifest.license_url),
		"O CREDITO AO AUTOR E OBRIGATORIO em qualquer distribuicao do jogo: \"Icons made by <autor>\" (lista abaixo).",
		"Modificacoes: fundo removido, recorte/escala para 128x128 e coloracao em tempo de execucao (IconCatalog).",
		"",
		"Arquivo gerado por tools/art_pipeline/build_icon_glyphs.gd a partir de icon_sources/manifest.json - nao editar a mao.",
		"",
	]
	var authors := by_author.keys()
	authors.sort()
	for author in authors:
		var files: Array = by_author[author]
		files.sort()
		lines.append("Icons made by %s (https://game-icons.net) - CC BY 3.0" % String(manifest.authors.get(author, author)))
		for entry in files:
			lines.append("\t" + String(entry))
		lines.append("")
	var file := FileAccess.open(CREDITS_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
