extends GutTest

## ÍCONES POR TIPO (2026-10-13) — pedido do usuário: "ter ícones por tipo de tropa... uma cor pra monstros neutros, e
## pra cada monstro um ícone; por classe um ícone tank, na cor dos humanos, dos elfos, dos orcs e dos anões; ícones pras
## grandes invocações, ícones para os recursos de mapa; ícones de verdade, tipo símbolos mesmo ao invés de X e formas
## abstratas". IconCatalog decide o pictograma e a cor.
## REFEITO no mesmo dia — "achei que ficou feio, parece algo amador que eu abri o paint e fiz... planejo inserir uma
## mecânica de escolher a cor base do seu reino, então os ícones precisam ser feitos de forma que seja fácil gerar
## variações pra cores diferentes": os pictogramas são máscaras vetoriais sem cor (assets/icons/glyphs, 128x128) e o
## selo inteiro sai de UMA cor base, com a tinta do desenho escolhida pelo contraste.

var grid: HexGrid
var human: PlayerData
var rival: PlayerData

func before_each():
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-4, 5):
		for r in range(-4, 5):
			grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora", Color(0.2, 0.45, 0.85))
	rival = _player("Verdemata", Color(0.25, 0.55, 0.35))

func _player(civ_name: String, color: Color) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	civ.color = color
	return PlayerData.new(civ)

const CENTER := Vector2i(64, 61)

## A cor base com o degradê do selo por cima: mesma matiz, um pouco mais clara ou escura.
func _same_hue(sample: Color, base: Color) -> bool:
	return sample.a > 0.99 and absf(sample.h - base.h) < 0.03 and absf(sample.v - base.v) < 0.3

## Quantos pixels opacos de `image` são da tinta `ink` (dentro da área do pictograma).
func _ink_pixels(image: Image, ink: Color) -> int:
	var count := 0
	for y in range(20, 104):
		for x in range(20, 108):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - ink.r) < 0.02 and absf(pixel.g - ink.g) < 0.02 and absf(pixel.b - ink.b) < 0.02:
				count += 1
	return count

func _all_referenced_glyphs() -> Array[String]:
	var ids: Array[String] = [IconCatalog.DEFAULT_UNIT_GLYPH, IconCatalog.DEFAULT_MONSTER_GLYPH]
	for table in [IconCatalog.CLASS_GLYPHS, IconCatalog.SCHOOL_GLYPHS, IconCatalog.UNIT_GLYPHS, IconCatalog.MONSTER_GLYPHS]:
		for id in table.values():
			ids.append(String(id))
	for entry in IconCatalog.RESOURCE_ICONS.values():
		ids.append(String(entry.glyph))
	return ids

# --- Os pictogramas existem ------------------------------------------------------------------------------------------------

func test_every_pictogram_the_catalog_uses_is_a_smooth_colourless_mask():
	for id in _all_referenced_glyphs():
		assert_true(IconCatalog.has_glyph(id), "pictograma %s existe em %s" % [id, IconCatalog.GLYPH_DIR])
		var image := IconCatalog.glyph_texture(id).get_image()
		assert_eq(image.get_size(), Vector2i(128, 128), id)
		var filled := 0
		var soft := 0
		var coloured := 0
		for y in 128:
			for x in 128:
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.5:
					filled += 1
				if pixel.a > 0.1 and pixel.a < 0.9:
					soft += 1
				if pixel.a > 0.0 and (pixel.r < 0.99 or pixel.g < 0.99 or pixel.b < 0.99):
					coloured += 1
		assert_between(filled, 1500, 12500, "%s é um desenho (nem vazio, nem um bloco cheio)" % id)
		assert_gt(soft, 100, "%s tem borda suavizada (arte vetorial, não pixel art)" % id)
		assert_eq(coloured, 0, "%s não tem cor própria: quem colore é o selo" % id)
		var used := image.get_used_rect()
		assert_gt(maxi(used.size.x, used.size.y), 112, "%s ocupa a moldura: todos têm o mesmo peso visual" % id)

func test_every_pictogram_has_a_versioned_source_and_a_credit():
	# Os ícones são CC BY 3.0: o crédito ao autor não é opcional.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art_pipeline/icon_sources/manifest.json"))
	var credits := FileAccess.get_file_as_string("res://assets/icons/CREDITS.txt")
	assert_string_contains(credits, "CC BY 3.0")
	for id in _all_referenced_glyphs():
		assert_true(manifest.glyphs.has(id), "%s está no manifesto" % id)
		assert_true(FileAccess.file_exists("res://tools/art_pipeline/icon_sources/svg/%s.svg" % id), "%s tem o SVG de origem versionado" % id)
		assert_string_contains(credits, id + ".png")
	for source in manifest.glyphs.values():
		var author := String(source).get_slice("/", 0)
		assert_true(manifest.authors.has(author), "autor %s tem nome de crédito" % author)
		assert_string_contains(credits, "Icons made by %s" % manifest.authors[author])

# --- Tropas: um pictograma por classe, pontos por nível ----------------------------------------------------------------------

func test_each_doctrine_class_has_its_own_pictogram_shared_by_the_whole_line():
	var expected := {"guardian": "shield", "warrior": "sword", "ranger": "bow", "cavalry": "horse", "rogue": "hood", "siege": "catapult"}
	var seen := {}
	for branch in expected:
		var ids := V2UnitLine.unit_ids(branch)
		assert_eq(ids.size(), 3, branch)
		for index in ids.size():
			assert_eq(IconCatalog.glyph_for_kind(ids[index]), expected[branch], "%s: %s" % [branch, ids[index]])
			assert_eq(IconCatalog.tier_pips(ids[index]), index + 1, "%s: forma %d tem %d ponto(s)" % [ids[index], index + 1, index + 1])
			assert_false(IconCatalog.is_elite(ids[index]))
		seen[expected[branch]] = true
	assert_eq(seen.size(), 6, "seis classes, seis pictogramas diferentes")

func test_legendary_units_keep_the_class_pictogram_with_the_gold_ring():
	for pair in [["v2_legendary_guardian_champion", "shield"], ["v2_legendary_blade_hero", "sword"], ["v2_legendary_legend_hunter", "bow"],
			["v2_legendary_griffon_rider", "horse"], ["v2_legendary_shadow_master", "hood"], ["v2_legendary_siege_colossus", "catapult"]]:
		assert_eq(IconCatalog.glyph_for_kind(pair[0]), pair[1], pair[0])
		assert_true(IconCatalog.is_elite(pair[0]), "%s: aro dourado" % pair[0])
		assert_eq(IconCatalog.tier_pips(pair[0]), 0, "a Lendária não é uma forma da linha: sem pontos")

func test_casters_use_their_school_and_civilians_and_manifestations_their_own_pictogram():
	var schools := {"v2_unit_sacred_cleric": "sun", "v2_unit_infernal_warlock": "flame", "v2_unit_necromancer": "scythe",
		"v2_unit_druid": "leaf", "v2_unit_arcanist": "star", "v2_unit_elementalist": "bolt"}
	for kind in schools:
		var data := UnitDatabase.create_unit(kind)
		assert_eq(IconCatalog.glyph_for_kind(kind, false, data.v2_magic_school), schools[kind], kind)
	assert_eq(IconCatalog.glyph_for_kind("settler"), "tent")
	assert_eq(IconCatalog.glyph_for_kind("v2_unit_builder"), "hammer")
	var manifestations := {}
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		if not kind.begins_with("v2_manifestation_"):
			continue
		var glyph := IconCatalog.glyph_for_kind(kind, false, UnitDatabase.create_unit(kind).v2_magic_school)
		assert_false(manifestations.has(glyph), "%s divide o pictograma com outra Manifestação" % kind)
		assert_false(glyph in IconCatalog.SCHOOL_GLYPHS.values(), "%s tem pictograma próprio, não o da Escola" % kind)
		assert_true(IconCatalog.is_elite(kind), kind)
		manifestations[glyph] = true
	assert_eq(manifestations.size(), 6, "seis Grandes Manifestações, seis pictogramas")

func test_every_trainable_unit_resolves_to_a_specific_pictogram():
	for kind in UnitDatabase.PLAYER_TRAINABLE_KINDS:
		var data := UnitDatabase.create_unit(kind)
		var glyph := IconCatalog.glyph_for_kind(kind, false, data.v2_magic_school)
		assert_true(IconCatalog.has_glyph(glyph), "%s -> %s" % [kind, glyph])
		if V2UnitLine.doctrine_branch_of(kind) != "warrior":
			assert_ne(glyph, IconCatalog.DEFAULT_UNIT_GLYPH, "%s não cai no pictograma genérico" % kind)

# --- Monstros: um pictograma por espécie, uma cor só ----------------------------------------------------------------------------

func test_every_monster_species_has_its_own_pictogram():
	var seen := {}
	for species in MonsterDatabase.KIND_DATA:
		assert_true(IconCatalog.MONSTER_GLYPHS.has(species), "%s tem pictograma" % species)
		var glyph := IconCatalog.glyph_for_kind(species, true)
		assert_false(seen.has(glyph), "%s divide o pictograma com %s" % [species, seen.get(glyph, "")])
		seen[glyph] = species

func test_monsters_share_one_colour_and_troops_wear_their_civilization():
	var goblin := grid.spawn_monster_at(Vector2i(0, 0), "goblin")
	var troll := grid.spawn_monster_at(Vector2i(1, 0), "troll")
	var mine := grid.spawn_unit(Vector2i(-2, 0), UnitDatabase.create_unit("v2_unit_shieldbearer"), human)
	var theirs := grid.spawn_unit(Vector2i(2, 2), UnitDatabase.create_unit("v2_unit_shieldbearer"), rival)

	assert_eq(IconCatalog.color_for_unit(goblin), IconCatalog.MONSTER_COLOR)
	assert_eq(IconCatalog.color_for_unit(troll), IconCatalog.MONSTER_COLOR, "todo monstro neutro tem a mesma cor")
	assert_eq(IconCatalog.color_for_unit(mine), human.civ.color)
	assert_eq(IconCatalog.color_for_unit(theirs), rival.civ.color)
	assert_ne(IconCatalog.unit_badge(goblin), IconCatalog.unit_badge(troll), "espécies diferentes, selos diferentes")
	assert_ne(IconCatalog.unit_badge(mine), IconCatalog.unit_badge(theirs), "a mesma tropa de reinos diferentes muda de cor")
	assert_same(IconCatalog.unit_badge(mine), IconCatalog.unit_badge(grid.spawn_unit(Vector2i(-2, 1), UnitDatabase.create_unit("v2_unit_shieldbearer"), human)), "iguais do mesmo dono dividem a textura")

# --- O selo --------------------------------------------------------------------------------------------------------------------

func test_the_badge_carries_the_owner_colour_the_ring_and_the_tier_pips():
	var color := Color(0.2, 0.45, 0.85)
	var plain := IconCatalog.badge("sword", color, 0, false).get_image()
	var size := IconCatalog.BADGE_SIZE
	assert_eq(plain.get_size(), Vector2i(size, size))
	assert_true(plain.has_mipmaps(), "o selo vai reduzido ao mapa: precisa de mipmaps")
	assert_eq(plain.get_pixel(0, 0).a, 0.0, "cantos arredondados: fora da placa é transparente")
	assert_true(_same_hue(plain.get_pixel(22, 40), color), "placa na cor do dono")
	assert_true(_same_hue(plain.get_pixel(106, 82), color), "placa na cor do dono")
	assert_gt(plain.get_pixel(64, 20).v, plain.get_pixel(64, 104).v, "degradê: mais clara em cima que embaixo")
	var rim := plain.get_pixel(CENTER.x, CENTER.y - 53)
	assert_lt(rim.v, color.v * 0.75, "aro: a própria cor, escurecida")
	assert_almost_eq(rim.h, color.h, 0.04, "aro na matiz do dono (nenhuma cor fixa)")
	var shadow := plain.get_pixel(CENTER.x, CENTER.y + 61)
	assert_between(shadow.a, 0.05, 0.6, "sombra suave sob o selo")
	var edge_levels := {}
	for x in range(0, 20):
		edge_levels[snappedf(plain.get_pixel(x, CENTER.y).a, 0.05)] = true
	assert_gt(edge_levels.size(), 2, "borda suavizada, não um degrau")

	var elite := IconCatalog.badge("sword", color, 0, true).get_image().get_pixel(CENTER.x, CENTER.y - 53)
	assert_almost_eq(elite.h, IconCatalog.ELITE_BORDER_COLOR.h, 0.04, "aro dourado")
	assert_gt(elite.v, 0.7)

	var counts: Array[int] = []
	for pips in [0, 1, 2, 3]:
		var image := IconCatalog.badge("sword", color, pips, false).get_image()
		var white := 0
		for y in range(IconCatalog.PIP_CENTER_Y - 4, IconCatalog.PIP_CENTER_Y + 4):
			for x in size:
				if absf(image.get_pixel(x, y).b - IconCatalog.GLYPH_LIGHT.b) < 0.02 and image.get_pixel(x, y).r > 0.97:
					white += 1
		counts.append(white)
	assert_eq(counts[0], 0, "sem pontos, nada na faixa de baixo")
	assert_gt(counts[1], 20)
	assert_lt(counts[1], counts[2], "mais pontos de nível = mais pixels na faixa de baixo")
	assert_lt(counts[2], counts[3])

# --- Qualquer cor de reino funciona ------------------------------------------------------------------------------------------

func test_any_kingdom_colour_gives_a_readable_badge():
	# A mecânica de escolher a cor do reino não precisa de arte nova: toda cor gera o selo, e a tinta do desenho troca
	# de clara para escura quando a cor é clara demais.
	var colors: Array[Color] = [Color.WHITE, Color.BLACK, Color(0.5, 0.5, 0.5), Color(1.0, 0.92, 0.1), IconCatalog.MONSTER_COLOR]
	for step in 24:
		for value in [0.3, 0.65, 1.0]:
			colors.append(Color.from_hsv(step / 24.0, 0.75, value))
			colors.append(Color.from_hsv(step / 24.0, 0.3, value))
	for color in colors:
		var ink := IconCatalog.ink_for(color)
		assert_true(ink == IconCatalog.GLYPH_LIGHT or ink == IconCatalog.GLYPH_DARK)
		assert_gte(IconCatalog.contrast(ink, color), 3.0, "tinta legível sobre %s" % color.to_html(false))
	assert_eq(IconCatalog.ink_for(Color(0.1, 0.15, 0.5)), IconCatalog.GLYPH_LIGHT, "cor escura: desenho claro")
	assert_eq(IconCatalog.ink_for(Color(1.0, 0.92, 0.1)), IconCatalog.GLYPH_DARK, "amarelo: desenho escuro")
	assert_eq(IconCatalog.ink_for(Color.WHITE), IconCatalog.GLYPH_DARK)

	for color in [Color(0.1, 0.15, 0.5), Color(1.0, 0.92, 0.1), Color.WHITE, Color.BLACK, Color(0.9, 0.3, 0.6)]:
		var image := IconCatalog.badge("shield", color, 2, false).get_image()
		assert_gt(_ink_pixels(image, IconCatalog.ink_for(color)), 800, "o desenho aparece na tinta escolhida sobre %s" % color.to_html(false))
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(CENTER.x, CENTER.y - 40).a, 1.0, "placa opaca")

func test_the_same_colour_is_composed_once_and_alpha_is_ignored():
	var color := Color(0.31, 0.62, 0.44)
	assert_same(IconCatalog.badge("bow", color, 1), IconCatalog.badge("bow", Color(0.31, 0.62, 0.44), 1))
	assert_same(IconCatalog.badge("bow", color, 1), IconCatalog.badge("bow", Color(0.31, 0.62, 0.44, 0.4), 1), "a cor do reino é sempre opaca no selo")
	assert_ne(IconCatalog.badge("bow", color, 1), IconCatalog.badge("bow", Color(0.31, 0.62, 0.5), 1))

func test_the_badge_shape_tells_troop_monster_and_resource_apart():
	# Com cor de reino livre, um reino vermelho-escuro não pode ser confundido com monstro: o formato muda.
	var troop := IconCatalog.badge("skull", IconCatalog.MONSTER_COLOR).get_image()
	var monster := IconCatalog.badge("skull", IconCatalog.MONSTER_COLOR, 0, false, IconCatalog.SHAPE_HEX).get_image()
	var medal := IconCatalog.badge("skull", IconCatalog.MONSTER_COLOR, 0, false, IconCatalog.SHAPE_ROUND).get_image()
	var corner := CENTER + Vector2i(46, -46)
	assert_eq(troop.get_pixel(corner.x, corner.y).a, 1.0, "placa: o canto é do selo")
	assert_eq(monster.get_pixel(corner.x, corner.y).a, 0.0, "hexágono: o canto é vazio")
	assert_eq(medal.get_pixel(corner.x, corner.y).a, 0.0, "medalhão: o canto é vazio")
	var top := CENTER + Vector2i(22, -50)
	assert_eq(medal.get_pixel(top.x, top.y).a, 1.0, "medalhão: redondo em cima")
	assert_eq(monster.get_pixel(top.x, top.y).a, 0.0, "hexágono: ponta em cima")
	var goblin := grid.spawn_monster_at(Vector2i(0, 0), "goblin")
	assert_same(IconCatalog.unit_badge(goblin), IconCatalog.badge("goblin", IconCatalog.MONSTER_COLOR, 0, false, IconCatalog.SHAPE_HEX))

func test_resources_have_real_pictograms_on_a_dark_medallion():
	for resource in ["iron", "horses", "gems", "silk", "mana_node"]:
		assert_true(IconCatalog.has_resource_icon(resource), resource)
		var image := IconCatalog.resource_badge(resource).get_image()
		var tint: Color = IconCatalog.RESOURCE_ICONS[resource].color
		assert_lt(image.get_pixel(CENTER.x - 38, CENTER.y - 20).v, 0.3, "%s: medalhão escuro (não é de ninguém)" % resource)
		assert_gt(_ink_pixels(image, tint), 400, "%s: desenho na cor do recurso" % resource)
		assert_eq(image.get_pixel(CENTER.x + 46, CENTER.y - 46).a, 0.0, "%s: redondo" % resource)
	assert_null(IconCatalog.resource_badge("nada"))
	var glyphs := {}
	for entry in IconCatalog.RESOURCE_ICONS.values():
		glyphs[entry.glyph] = true
	assert_eq(glyphs.size(), IconCatalog.RESOURCE_ICONS.size(), "um pictograma por recurso")

# --- No mapa ---------------------------------------------------------------------------------------------------------------------

func test_units_on_the_map_wear_their_badge_and_mages_have_no_letter_emblem():
	var guard := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("v2_unit_shieldbearer"), human)
	var cleric := grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit("v2_unit_sacred_cleric"), human)
	var spider := grid.spawn_monster_at(Vector2i(2, 0), "giant_spider")
	for unit in [guard, cleric, spider]:
		var icon := unit.find_child(Unit.TROOP_ICON_NAME, true, false) as Sprite3D
		assert_not_null(icon, unit.unit_data.unit_name)
		assert_same(icon.texture, IconCatalog.unit_badge(unit), "%s usa o selo do catálogo" % unit.unit_data.unit_name)
		assert_eq(icon.texture_filter, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "arte suavizada, reduzida com mipmaps")
		assert_eq(icon.alpha_cut, SpriteBase3D.ALPHA_CUT_DISABLED, "borda suave e sombra pedem transparência por mistura")
		assert_almost_eq(IconCatalog.BADGE_SIZE * icon.pixel_size, 0.56, 0.03, "tamanho no mundo independe da resolução da arte")
	assert_null(cleric.find_child("SchoolEmblem", true, false), "as duas letras da Escola saíram: o selo já mostra o símbolo dela")
	assert_eq(IconCatalog.glyph_for_unit(cleric), "sun")
	assert_eq(IconCatalog.glyph_for_unit(spider), "spider")

func test_upgrading_a_unit_updates_its_badge():
	var unit := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("v2_unit_shieldbearer"), human)
	var before := (unit.find_child(Unit.TROOP_ICON_NAME, true, false) as Sprite3D).texture

	unit.apply_form(UnitDatabase.create_unit("v2_unit_guardian"))

	var after := (unit.find_child(Unit.TROOP_ICON_NAME, true, false) as Sprite3D).texture
	assert_ne(after, before, "a forma evoluída ganha um ponto de nível")
	assert_same(after, IconCatalog.unit_badge(unit))

func test_changing_the_kingdom_colour_recolours_the_badges_already_on_the_map():
	var unit := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("v2_unit_archer"), human)
	var sprite := unit.find_child(Unit.TROOP_ICON_NAME, true, false) as Sprite3D
	var before := sprite.texture

	human.civ.color = Color(0.95, 0.85, 0.15) # o jogador escolheu amarelo
	unit.refresh_troop_icon()

	assert_ne(sprite.texture, before)
	assert_same(sprite.texture, IconCatalog.badge("bow", Color(0.95, 0.85, 0.15), 1))
	assert_gt(_ink_pixels(sprite.texture.get_image(), IconCatalog.GLYPH_DARK), 400, "amarelo: o arco passa a ser desenhado em tinta escura")

func test_the_unit_card_shows_the_same_badge_as_the_map():
	var unit := grid.spawn_unit(Vector2i(0, 0), UnitDatabase.create_unit("v2_unit_archer"), human)
	var view := UnitPresenter.build(unit, human, grid)
	assert_same(view.portrait_icon, IconCatalog.unit_badge(unit))
	var portrait := AEPortrait.new()
	add_child_autofree(portrait)
	portrait.configure(view.portrait_glyph, view.portrait_accent, view.owner_color, view.portrait_caption)
	portrait.set_icon(view.portrait_icon)
	assert_true(portrait.icon_rect.visible, "o selo aparece no retrato")
	assert_same(portrait.icon_rect.texture, IconCatalog.unit_badge(unit))
	assert_false(portrait.glyph_label.visible, "o caractere de texto dá lugar ao selo")
	portrait.set_icon(null)
	assert_true(portrait.glyph_label.visible, "sem selo, o retrato volta ao glyph")

func test_resource_tiles_show_the_catalog_badge():
	var coord := Vector2i(1, 1)
	grid.tiles[coord].resource = "horses"
	grid._resource_icon_manager.rebuild(grid.tiles)
	var sprite: Sprite3D = grid._resource_icon_manager._sprites.get(coord)
	assert_not_null(sprite)
	assert_same(sprite.texture, IconCatalog.resource_badge("horses"))
