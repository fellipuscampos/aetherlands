class_name IconCatalog
extends RefCounted

## ÍCONES DO JOGO (2026-10-13) — pedido do usuário: "ter ícones por tipo de tropa; atualmente os ícones são meio
## aleatórios... uma cor pra monstros neutros, e pra cada monstro um ícone (goblin, golem, esqueleto...); por classe
## um ícone tank, que fica como ícone de todos da classe, na cor dos humanos, dos elfos, dos orcs e dos anões...;
## ícones pras grandes invocações, ícones para os recursos de mapa; ícones de verdade, tipo símbolos mesmo".
##
## O QUE ESTE ARQUIVO DECIDE: qual PICTOGRAMA cada coisa usa, de que COR é o selo e como o selo é desenhado.
##
## DE ONDE VÊM OS DESENHOS: ícones vetoriais de https://game-icons.net (CC BY 3.0 — crédito obrigatório, ver
## assets/icons/CREDITS.txt), versionados em tools/art_pipeline/icon_sources/ e rasterizados por
## tools/art_pipeline/build_icon_glyphs.gd em MÁSCARAS sem cor (assets/icons/glyphs/<id>.png, 128x128, branco + alfa
## suavizado). Trocar um desenho = trocar uma linha do manifest.json.
##
## COR É PARÂMETRO, NÃO ARQUIVO (pedido de 2026-10-13: "planejo inserir uma mecânica de escolher a cor base do seu
## reino, então os ícones precisam ser feitos de forma que seja fácil gerar variações pra cores diferentes"): o selo
## inteiro sai de UMA cor base — `badge(pictograma, cor)`. Degradê, aro, brilho e sombra são camadas sem cor (branco e
## preto translúcidos) aplicadas sobre ela, e a tinta do pictograma (clara ou escura) é escolhida pelo contraste
## (`ink_for`), então QUALQUER cor funciona: amarelo e branco ganham desenho escuro, azul-marinho e preto, desenho
## claro. Para o jogo, basta `CivilizationData.color` mudar (`color_for_owner`). Para ver/exportar variações:
## tools/art_pipeline/export_icon_variations.gd.
##
## REGRAS DE LEITURA (o que o jogador aprende uma vez):
##  - DESENHO = o que a coisa é. Tropa: um pictograma por CLASSE (Doutrina) — escudo (Guardião), espada (Guerreiro),
##    arco (Patrulheiro), cavalo (Cavalaria), capuz (Ladino), catapulta (Cerco); a forma da linha é dada pelos PONTOS
##    embaixo (1, 2 ou 3) e a Lendária pelo aro dourado. Conjurador: o símbolo da Escola. Grande Manifestação: um
##    pictograma próprio, com aro dourado. Monstro: um pictograma por espécie.
##  - COR = de quem é. A cor da civilização dona (a mesma da borda do território e do minimapa); monstros neutros,
##    hostis a todos, têm uma cor só (MONSTER_COLOR).
##  - FORMATO DO SELO = que tipo de coisa é: placa quadrada (tropa de um reino), hexágono (monstro neutro), medalhão
##    redondo e escuro (recurso de mapa — não é de ninguém). O formato existe porque a cor do reino será livre: um
##    reino vermelho-escuro não pode ser confundido com monstro.
## Por classe e não por unidade: 24 silhuetas de tropa não se distinguem num selo pequeno sobre o mapa; seis classes
## com pontos de nível, sim.

const GLYPH_DIR := "res://assets/icons/glyphs/"
## Lado do selo composto, em pixels. Vai ao mapa com mipmaps (Sprite3D) e à interface no tamanho que ela pedir.
const BADGE_SIZE := 128

## Formato do selo (ver REGRAS DE LEITURA).
const SHAPE_PLATE := "plate"
const SHAPE_HEX := "hex"
const SHAPE_ROUND := "round"
## Centro do formato no quadro: um pouco acima do meio, para a sombra caber embaixo.
const BADGE_CENTER := Vector2(64.0, 61.0)
## Meio-lado da placa / raio do medalhão / raio do hexágono até a ponta.
const SHAPE_RADIUS := 57.0
const PLATE_CORNER := 20.0
const HEX_CORNER := 7.0
## Lado do pictograma dentro de cada formato (o hexágono tem menos área útil que a placa).
const SHAPE_GLYPH_SIZE := {SHAPE_PLATE: 76, SHAPE_HEX: 62, SHAPE_ROUND: 68}
## Com pontos de nível o pictograma encolhe e sobe, para os pontos caberem embaixo.
const PIPPED_GLYPH_SIZE := 66
const PIPPED_GLYPH_LIFT := 9
const PIP_RADIUS := 5.5
const PIP_SPACING := 18
const PIP_CENTER_Y := 100

## Camadas SEM COR do selo (larguras em pixels, opacidades 0..1) — valem para qualquer cor base.
const RIM_WIDTH := 7.0 # aro: a cor base escurecida (ou dourado / a cor do recurso)
const RIM_DARKEN := 0.52
const HAIRLINE_WIDTH := 1.5 # fio escuro por fora: separa o selo do terreno
const HAIRLINE_ALPHA := 0.9
const BEVEL_WIDTH := 1.6 # fio claro por dentro do aro: dá o relevo
const BEVEL_ALPHA_TOP := 0.5
const BEVEL_ALPHA_BOTTOM := 0.12
const SHADE_LIGHT_TOP := 0.2 # degradê vertical: clareia em cima, escurece embaixo
const SHADE_DARK_BOTTOM := 0.26
const SHADOW_OFFSET := 3.0
const SHADOW_BLUR := 6.0
const SHADOW_ALPHA := 0.42
const GLYPH_OUTLINE := 2 # contorno do pictograma, em pixels
const GLYPH_OUTLINE_ALPHA := 0.6
const GLYPH_HALO_ALPHA := 0.32 # o mesmo contorno, claro, quando a tinta é escura
const GLYPH_SHADOW_OFFSET := 3

## Tinta do pictograma: clara sempre que contrasta o bastante com a placa, senão a que contrastar mais.
const GLYPH_LIGHT := Color(1.0, 0.98, 0.94)
const GLYPH_DARK := Color(0.09, 0.09, 0.12)
const MIN_LIGHT_CONTRAST := 3.0
const INK := Color(0.04, 0.045, 0.07)
## "Decida você": a tinta sai do contraste e o aro, da cor base escurecida.
const AUTO := Color(0, 0, 0, 0)

## Monstros neutros: hostis a todos, uma cor só.
const MONSTER_COLOR := Color(0.62, 0.14, 0.16)
## Unidade de civilização sem cor conhecida (dado de teste).
const UNOWNED_COLOR := Color(0.36, 0.38, 0.44)
## Aro das Unidades Lendárias e das Grandes Manifestações.
const ELITE_BORDER_COLOR := Color(0.98, 0.8, 0.3)
const RESOURCE_BADGE_COLOR := Color(0.1, 0.11, 0.15)

const DEFAULT_UNIT_GLYPH := "sword"
const DEFAULT_MONSTER_GLYPH := "skull"

## Classe (Doutrina Militar) -> pictograma.
const CLASS_GLYPHS := {
	"guardian": "shield",
	"warrior": "sword",
	"ranger": "bow",
	"cavalry": "horse",
	"rogue": "hood",
	"siege": "catapult",
}
## Escola de magia -> pictograma (conjuradores).
const SCHOOL_GLYPHS := {
	"sacred": "sun",
	"infernal": "flame",
	"necromancy": "scythe",
	"druidism": "leaf",
	"arcanism": "star",
	"elementalism": "bolt",
}
## Unidades com pictograma próprio (civis, Grandes Manifestações, Hostes).
const UNIT_GLYPHS := {
	"settler": "tent",
	"v2_unit_builder": "hammer",
	"v2_manifestation_seraph": "seraph",
	"v2_manifestation_archdemon": "demon",
	"v2_manifestation_lich_sovereign": "lich",
	"v2_manifestation_nature_avatar": "tree",
	"v2_manifestation_veil_archon": "eye",
	"v2_manifestation_elemental_primordial": "whirlwind",
	"v2_unit_skeleton_host": "risen",
	"v2_unit_macabre_host": "risen",
}
## Espécie de monstro (UnitData.visual_kind) -> pictograma.
const MONSTER_GLYPHS := {
	"goblin": "goblin",
	"troll": "troll",
	"wyvern": "wyvern",
	"skeleton": "skull",
	"dragon": "dragon",
	"worg": "wolf",
	"giant_spider": "spider",
	"minotaur": "minotaur",
	"basilisk": "snake",
	"colossal_worm": "worm",
	"arboreal_ancient": "golem",
	"mana_devourer": "devourer",
	"corrupted_hero": "helm",
}
## Recurso de mapa -> {glyph, color}.
const RESOURCE_ICONS := {
	"iron": {"glyph": "anvil", "color": Color(0.8, 0.84, 0.9)},
	"horses": {"glyph": "horseshoe", "color": Color(0.9, 0.74, 0.4)},
	"gems": {"glyph": "gem", "color": Color(0.85, 0.5, 0.97)},
	"silk": {"glyph": "spool", "color": Color(0.96, 0.93, 0.82)},
	"mana_node": {"glyph": "crystals", "color": Color(0.45, 0.9, 0.97)},
}

static var _glyph_images: Dictionary = {} # id -> Image (RGBA8, máscara branca + alfa)
static var _glyph_textures: Dictionary = {} # id -> Texture2D
static var _badges: Dictionary = {} # chave -> ImageTexture
static var _shapes: Dictionary = {} # formato -> camadas sem cor (ver _shape_layers)
static var _glyph_layers: Dictionary = {} # "id|lado|tinta|contorno" -> {glyph, outline}
static var _rims: Dictionary = {} # "formato|cor" -> Image (aro tingido)
static var _pips: Dictionary = {} # "tinta|contorno" -> Image (um ponto de nível)
static var _shade: Image

# --- O que cada coisa usa -----------------------------------------------------------------------------------------------

## Pictograma de uma unidade pelo TIPO dela (`kind` = UnitData.visual_kind / id da unidade), sabendo se ela é um
## monstro (`neutral`) e, para conjuradores, a Escola.
static func glyph_for_kind(kind: String, neutral: bool = false, magic_school: String = "") -> String:
	if neutral:
		return String(MONSTER_GLYPHS.get(kind, DEFAULT_MONSTER_GLYPH))
	if UNIT_GLYPHS.has(kind):
		return String(UNIT_GLYPHS[kind])
	if SCHOOL_GLYPHS.has(magic_school):
		return String(SCHOOL_GLYPHS[magic_school])
	var branch := V2UnitLine.doctrine_branch_of(kind)
	if CLASS_GLYPHS.has(branch):
		return String(CLASS_GLYPHS[branch])
	# Um monstro sob o controle de uma civilização (invocação) continua com a cara da espécie.
	return String(MONSTER_GLYPHS.get(kind, DEFAULT_UNIT_GLYPH))

static func glyph_for_unit(unit: Unit) -> String:
	if unit == null or unit.unit_data == null:
		return DEFAULT_UNIT_GLYPH
	return glyph_for_kind(unit.unit_data.visual_kind, unit.owner_player == null, unit.unit_data.v2_magic_school)

## Pontos de NÍVEL sob o pictograma de classe: 1 (forma básica), 2 (primeira evolução), 3 (forma de elite); 0 para
## quem não é forma de uma linha de Doutrina (Lendária, conjurador, civil, monstro).
static func tier_pips(kind: String) -> int:
	var node := V2UnitLine.node_for(kind)
	return V2UnitLine.LINE_ROLES.find(node.tier_role) + 1 if node != null else 0

## Lendária ou Grande Manifestação: aro dourado.
static func is_elite(kind: String) -> bool:
	return V2LegendarySystem.is_legendary_kind(kind) or V2ManifestationSystem.is_manifestation_kind(kind)

## A cor do selo de `unit`: a da civilização dona, ou MONSTER_COLOR para os neutros.
static func color_for_unit(unit: Unit) -> Color:
	if unit == null or unit.owner_player == null:
		return MONSTER_COLOR
	return color_for_owner(unit.owner_player)

static func color_for_owner(owner: PlayerData) -> Color:
	if owner == null:
		return MONSTER_COLOR
	return owner.civ.color if owner.civ != null and owner.civ.color != Color.WHITE else UNOWNED_COLOR

# --- Texturas -----------------------------------------------------------------------------------------------------------

## O selo de `unit` (o que flutua sobre ela no mapa e aparece no card).
static func unit_badge(unit: Unit) -> Texture2D:
	if unit == null or unit.unit_data == null:
		return badge(DEFAULT_UNIT_GLYPH, UNOWNED_COLOR)
	var kind: String = unit.unit_data.visual_kind
	if unit.owner_player == null:
		return badge(glyph_for_unit(unit), MONSTER_COLOR, 0, false, SHAPE_HEX)
	return badge(glyph_for_unit(unit), color_for_unit(unit), tier_pips(kind), is_elite(kind))

## O selo de uma unidade que ainda não existe (lista de produção): o tipo `kind` na cor de `owner`.
static func kind_badge(kind: String, owner: PlayerData, magic_school: String = "") -> Texture2D:
	return badge(glyph_for_kind(kind, false, magic_school), color_for_owner(owner) if owner != null else UNOWNED_COLOR, tier_pips(kind), is_elite(kind))

## O selo de um recurso de mapa; null se o recurso não tem ícone.
static func resource_badge(resource_id: String) -> Texture2D:
	if not RESOURCE_ICONS.has(resource_id):
		return null
	var entry: Dictionary = RESOURCE_ICONS[resource_id]
	return badge(String(entry.glyph), RESOURCE_BADGE_COLOR, 0, false, SHAPE_ROUND, entry.color, entry.color)

static func has_resource_icon(resource_id: String) -> bool:
	return RESOURCE_ICONS.has(resource_id)

## A máscara crua do pictograma (branco + alfa) — para a interface tingir como quiser (`modulate`).
static func glyph_texture(glyph_id: String) -> Texture2D:
	if not _glyph_textures.has(glyph_id):
		var image := _glyph_image(glyph_id)
		_glyph_textures[glyph_id] = ImageTexture.create_from_image(image) if image != null else null
	return _glyph_textures[glyph_id]

static func has_glyph(glyph_id: String) -> bool:
	return _glyph_image(glyph_id) != null

## Selo composto a partir de UMA cor base (`fill`): formato `shape`, aro (a própria cor escurecida, dourado se
## `elite`, ou `rim`), degradê e relevo, o pictograma na tinta de melhor contraste (ou `glyph_color`) com contorno, e
## os pontos de nível. Uma textura por combinação, em cache — pedir a mesma cor duas vezes devolve a mesma textura.
static func badge(glyph_id: String, fill: Color, pips: int = 0, elite: bool = false, shape: String = SHAPE_PLATE, glyph_color: Color = AUTO, rim: Color = AUTO) -> Texture2D:
	var base := Color(fill.r, fill.g, fill.b, 1.0)
	var key := "%s|%s|%d|%s|%s|%s|%s" % [glyph_id, base.to_html(false), pips, str(elite), shape, glyph_color.to_html(), rim.to_html()]
	if _badges.has(key):
		return _badges[key]
	var image := _compose(glyph_id, base, pips, elite, shape, glyph_color, rim)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_badges[key] = texture
	return texture

## Esquece toda textura composta (ferramentas; o jogo não precisa: a chave do cache já inclui a cor).
static func clear_cache() -> void:
	_badges.clear()
	_glyph_layers.clear()
	_rims.clear()
	_pips.clear()

# --- Cor ----------------------------------------------------------------------------------------------------------------

## A tinta do pictograma sobre uma placa `fill`: clara quando contrasta o bastante, senão a de maior contraste.
static func ink_for(fill: Color) -> Color:
	var light := contrast(GLYPH_LIGHT, fill)
	return GLYPH_LIGHT if light >= MIN_LIGHT_CONTRAST or light >= contrast(GLYPH_DARK, fill) else GLYPH_DARK

## Razão de contraste (WCAG) entre duas cores opacas: 1 (iguais) a 21 (preto sobre branco).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Luminância relativa (WCAG) de uma cor sRGB.
static func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b

# --- Composição -----------------------------------------------------------------------------------------------------------

static func _glyph_image(glyph_id: String) -> Image:
	if _glyph_images.has(glyph_id):
		return _glyph_images[glyph_id]
	var image: Image = null
	var path := GLYPH_DIR + glyph_id + ".png"
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			image = texture.get_image()
			if image != null:
				if image.is_compressed():
					image.decompress()
				image.convert(Image.FORMAT_RGBA8)
				image.clear_mipmaps()
	_glyph_images[glyph_id] = image
	return image

## Quase tudo aqui é operação nativa de Image (fill/blend_rect) sobre camadas em cache; por selo novo, o único laço em
## GDScript é o recorte do formato (só os pixels de fora e da borda). Ordem: cor base -> aro -> degradê e fios ->
## pictograma -> pontos -> recorte no formato -> por cima da sombra.
static func _compose(glyph_id: String, fill: Color, pips: int, elite: bool, shape: String, glyph_color: Color, rim: Color) -> Image:
	var layers := _shape_layers(shape)
	var full := Rect2i(0, 0, BADGE_SIZE, BADGE_SIZE)
	var image := Image.create(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	var rim_color := ELITE_BORDER_COLOR if elite else rim
	if rim_color.a > 0.0:
		image.blend_rect(_rim_image(shape, rim_color), full, Vector2i.ZERO)
		image.blend_rect(layers.finish, full, Vector2i.ZERO)
	else:
		image.blend_rect(layers.finish_with_rim, full, Vector2i.ZERO)

	var ink := glyph_color if glyph_color.a > 0.0 else ink_for(fill)
	# Contorno escuro sob tinta clara; halo claro sob tinta escura.
	var dark_outline := luminance(ink) >= luminance(fill)
	var glyph_size: int = PIPPED_GLYPH_SIZE if pips > 0 else int(SHAPE_GLYPH_SIZE.get(shape, SHAPE_GLYPH_SIZE[SHAPE_PLATE]))
	var glyph := _glyph_layer(glyph_id, glyph_size, ink, dark_outline)
	if not glyph.is_empty():
		var origin := Vector2i(roundi(BADGE_CENTER.x - glyph_size * 0.5), roundi(BADGE_CENTER.y - glyph_size * 0.5) - (PIPPED_GLYPH_LIFT if pips > 0 else 0))
		var outline: Image = glyph.outline
		var outline_origin := origin - Vector2i(GLYPH_OUTLINE, GLYPH_OUTLINE)
		var outline_rect := Rect2i(Vector2i.ZERO, outline.get_size())
		image.blend_rect(outline, outline_rect, outline_origin + Vector2i(0, GLYPH_SHADOW_OFFSET)) # sombra projetada
		image.blend_rect(outline, outline_rect, outline_origin)
		image.blend_rect(glyph.glyph, Rect2i(0, 0, glyph_size, glyph_size), origin)
	if pips > 0:
		var pip := _pip_image(ink, dark_outline)
		var pip_size := pip.get_size()
		var start_x := BADGE_CENTER.x - (pips - 1) * PIP_SPACING * 0.5
		for index in pips:
			image.blend_rect(pip, Rect2i(Vector2i.ZERO, pip_size), Vector2i(roundi(start_x + index * PIP_SPACING - pip_size.x * 0.5), PIP_CENTER_Y - pip_size.y / 2))

	# Recorte: fora do formato o alfa vira a cobertura suavizada da borda.
	var data := image.get_data()
	var cut_offsets: PackedInt32Array = layers.cut_offsets
	var cut_alpha: PackedByteArray = layers.cut_alpha
	for index in cut_offsets.size():
		data[cut_offsets[index]] = cut_alpha[index]
	var result: Image = (layers.shadow as Image).duplicate()
	result.blend_rect(Image.create_from_data(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8, data), full, Vector2i.ZERO)
	return result

## Distância com sinal de `point` (relativo ao centro) até a borda do formato: negativa dentro.
static func _shape_distance(shape: String, point: Vector2) -> float:
	match shape:
		SHAPE_ROUND:
			return point.length() - SHAPE_RADIUS
		SHAPE_HEX:
			# Hexágono regular de ponta para cima; `apothem` é a distância do centro às faces laterais.
			var apothem := (SHAPE_RADIUS - HEX_CORNER) * 0.8660254
			var p := Vector2(absf(point.y), absf(point.x))
			var k := Vector2(-0.8660254, 0.5)
			p -= 2.0 * minf(k.dot(p), 0.0) * k
			p -= Vector2(clampf(p.x, -0.57735027 * apothem, 0.57735027 * apothem), apothem)
			return p.length() * signf(p.y) - HEX_CORNER
		_:
			var q := Vector2(absf(point.x), absf(point.y)) - Vector2(SHAPE_RADIUS - PLATE_CORNER, SHAPE_RADIUS - PLATE_CORNER)
			return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - PLATE_CORNER

## As camadas SEM COR de um formato, calculadas uma vez: o recorte suavizado (`cut_offsets`/`cut_alpha`), a sombra
## projetada (`shadow`), a cobertura do aro (`rim_offsets`/`rim_alpha`, para aros tingidos) e os acabamentos prontos
## para `blend_rect` — `finish` (degradê + fio de relevo + fio externo) e `finish_with_rim` (o mesmo, com o aro que
## escurece a cor base).
static func _shape_layers(shape: String) -> Dictionary:
	if _shapes.has(shape):
		return _shapes[shape]
	var size := BADGE_SIZE
	var full := Rect2i(0, 0, size, size)
	var shadow := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rim_dark := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var lines := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cut_offsets := PackedInt32Array()
	var cut_alpha := PackedByteArray()
	var rim_offsets := PackedInt32Array()
	var rim_alpha := PackedByteArray()
	var band := RIM_WIDTH + BEVEL_WIDTH + 1.0
	for y in size:
		var bevel_alpha := lerpf(BEVEL_ALPHA_TOP, BEVEL_ALPHA_BOTTOM, float(y) / float(size - 1))
		for x in size:
			var point := Vector2(x + 0.5, y + 0.5) - BADGE_CENTER
			var distance := _shape_distance(shape, point)
			if distance <= -band:
				continue
			var coverage := clampf(0.5 - distance, 0.0, 1.0)
			if coverage < 1.0:
				cut_offsets.append((y * size + x) * 4 + 3)
				cut_alpha.append(roundi(coverage * 255.0))
				var falloff := 1.0 - clampf(_shape_distance(shape, point - Vector2(0.0, SHADOW_OFFSET)) / SHADOW_BLUR, 0.0, 1.0)
				if falloff > 0.0:
					shadow.set_pixel(x, y, Color(0.0, 0.0, 0.0, SHADOW_ALPHA * falloff * falloff))
			if coverage <= 0.0:
				continue
			var rim := clampf(distance + RIM_WIDTH + 0.5, 0.0, 1.0)
			if rim > 0.0:
				rim_offsets.append(y * size + x)
				rim_alpha.append(roundi(rim * 255.0))
				rim_dark.set_pixel(x, y, Color(0.0, 0.0, 0.0, RIM_DARKEN * rim))
			var hairline := clampf(distance + HAIRLINE_WIDTH + 0.5, 0.0, 1.0)
			var bevel := clampf(distance + RIM_WIDTH + BEVEL_WIDTH + 0.5, 0.0, 1.0) * (1.0 - rim)
			if hairline > 0.0:
				lines.set_pixel(x, y, Color(INK.r, INK.g, INK.b, HAIRLINE_ALPHA * hairline))
			elif bevel > 0.0:
				lines.set_pixel(x, y, Color(1.0, 1.0, 1.0, bevel_alpha * bevel))
	var finish: Image = _shade_image().duplicate()
	finish.blend_rect(lines, full, Vector2i.ZERO)
	var finish_with_rim := rim_dark
	finish_with_rim.blend_rect(finish, full, Vector2i.ZERO)
	var layers := {
		"cut_offsets": cut_offsets, "cut_alpha": cut_alpha, "shadow": shadow,
		"rim_offsets": rim_offsets, "rim_alpha": rim_alpha,
		"finish": finish, "finish_with_rim": finish_with_rim,
	}
	_shapes[shape] = layers
	return layers

## Degradê vertical sem cor: branco translúcido em cima, preto translúcido embaixo.
static func _shade_image() -> Image:
	if _shade == null:
		_shade = Image.create(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8)
		for y in BADGE_SIZE:
			var t := float(y) / float(BADGE_SIZE - 1) * 2.0 - 1.0
			var color := Color(1.0, 1.0, 1.0, SHADE_LIGHT_TOP * -t) if t < 0.0 else Color(0.0, 0.0, 0.0, SHADE_DARK_BOTTOM * t)
			_shade.fill_rect(Rect2i(0, y, BADGE_SIZE, 1), color)
	return _shade

## O aro de `shape` tingido de `color` (dourado das Lendárias, cor do recurso).
static func _rim_image(shape: String, color: Color) -> Image:
	var key := "%s|%s" % [shape, color.to_html(false)]
	if not _rims.has(key):
		var layers := _shape_layers(shape)
		var image := Image.create(BADGE_SIZE, BADGE_SIZE, false, Image.FORMAT_RGBA8)
		var offsets: PackedInt32Array = layers.rim_offsets
		var alpha: PackedByteArray = layers.rim_alpha
		for index in offsets.size():
			image.set_pixel(offsets[index] % BADGE_SIZE, offsets[index] / BADGE_SIZE, Color(color.r, color.g, color.b, alpha[index] / 255.0))
		_rims[key] = image
	return _rims[key]

## O pictograma `glyph_id` no lado `size`, tingido de `ink`, e o seu contorno (a máscara dilatada GLYPH_OUTLINE
## pixels: escura e translúcida sob tinta clara, clara sob tinta escura). {} se o pictograma não existe.
static func _glyph_layer(glyph_id: String, size: int, ink: Color, dark_outline: bool) -> Dictionary:
	var key := "%s|%d|%s|%s" % [glyph_id, size, ink.to_html(false), str(dark_outline)]
	if _glyph_layers.has(key):
		return _glyph_layers[key]
	var layer := {}
	var source := _glyph_image(glyph_id)
	if source != null:
		var mask: Image = source.duplicate()
		mask.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var mask_data := mask.get_data()
		var outline_color := INK if dark_outline else Color.WHITE
		var stamp := _tinted(mask_data, size, outline_color, 1.0)
		var outline_size := size + GLYPH_OUTLINE * 2
		var outline := Image.create(outline_size, outline_size, false, Image.FORMAT_RGBA8)
		var rect := Rect2i(0, 0, size, size)
		for dy in range(-GLYPH_OUTLINE, GLYPH_OUTLINE + 1):
			for dx in range(-GLYPH_OUTLINE, GLYPH_OUTLINE + 1):
				if dx * dx + dy * dy <= GLYPH_OUTLINE * GLYPH_OUTLINE + 1:
					outline.blend_rect(stamp, rect, Vector2i(GLYPH_OUTLINE + dx, GLYPH_OUTLINE + dy))
		layer = {
			"glyph": _tinted(mask_data, size, ink, 1.0),
			"outline": _tinted(outline.get_data(), outline_size, outline_color, GLYPH_OUTLINE_ALPHA if dark_outline else GLYPH_HALO_ALPHA),
		}
	_glyph_layers[key] = layer
	return layer

## Um ponto de nível: disco na tinta do pictograma com o mesmo contorno dele.
static func _pip_image(ink: Color, dark_outline: bool) -> Image:
	var key := "%s|%s" % [ink.to_html(false), str(dark_outline)]
	if not _pips.has(key):
		var outer := PIP_RADIUS + GLYPH_OUTLINE
		var size := ceili(outer) * 2 + 2
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var outline_color := INK if dark_outline else Color.WHITE
		var outline_alpha := GLYPH_OUTLINE_ALPHA if dark_outline else GLYPH_HALO_ALPHA
		for y in size:
			for x in size:
				var distance := (Vector2(x + 0.5, y + 0.5) - Vector2(size, size) * 0.5).length()
				var ring := clampf(outer - distance + 0.5, 0.0, 1.0)
				if ring <= 0.0:
					continue
				var disc := clampf(PIP_RADIUS - distance + 0.5, 0.0, 1.0)
				image.set_pixel(x, y, Color(outline_color.r, outline_color.g, outline_color.b, outline_alpha * ring).blend(Color(ink.r, ink.g, ink.b, disc)))
		_pips[key] = image
	return _pips[key]

## Uma imagem `size`x`size` na cor `color` cujo alfa é o alfa de `rgba` (dados RGBA8) vezes `opacity`.
static func _tinted(rgba: PackedByteArray, size: int, color: Color, opacity: float) -> Image:
	var data := PackedByteArray()
	data.resize(rgba.size())
	var rgb := color.r8 | (color.g8 << 8) | (color.b8 << 16)
	var scale := int(roundf(opacity * 256.0))
	for offset in range(0, rgba.size(), 4):
		data.encode_u32(offset, rgb | (((rgba[offset + 3] * scale) >> 8) << 24))
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
