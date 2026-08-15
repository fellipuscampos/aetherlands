class_name ResourceIconManager
extends RefCounted

## Icones estilo Civilization flutuando acima de cada tile com recurso
## estrategico/luxo (ver ResourceDatabase/HexTileData.resource) — pedido do
## usuario: "insira uma modificacao onde nos recursos especiais do mapa a
## gente tenha icones que indiquem que naquela celula tem recurso especial,
## tal qual no civilization". Complementa (nao substitui)
## ResourcePropsManager: aquele e o "objeto" no chao (pilha de minerio,
## fardo de feno...), isto aqui e o SELO/PLACA billboard sempre de frente
## pra camera, legivel em qualquer angulo/zoom/distancia — exatamente como
## o icone de recurso do Civilization flutua sobre o tile independente da
## arte de fundo. Sprite3D com textura desenhada em pixels (nao Label3D
## com glifo Unicode) porque a fonte padrao do projeto nao garante
## cobertura de simbolos tipo picareta/ferradura/gema — desenhar o icone
## a mao garante silhueta reconhecivel e distinta por recurso sem
## depender de asset externo (projeto nao tem pasta de icones/sprites).
var _hex_grid: HexGrid

const ICON_SIZE := 32
const BADGE_RADIUS := 13.0
const BADGE_COLOR := Color(0.05, 0.05, 0.08, 0.6)
## Altura acima da superficie do tile (world_for_coord ja inclui
## base_height do terreno) — acima do topo dos props 3D mais altos
## (gemas chegam a 0.28, ver ResourcePropsManager._build_gems_mesh) pra
## nunca ficar espetado dentro da propria geometria do recurso.
const ICON_HEIGHT_OFFSET := 0.55

var _textures: Dictionary = {} # resource_kind (String) -> ImageTexture
var _sprites: Dictionary = {} # Vector2i -> Sprite3D

func _init(hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	for kind in ["iron", "horses", "gems", "silk", "mana_node"]:
		_textures[kind] = _build_icon_texture(kind)

## Reconstroi todos os icones do zero a partir do mapa atual — mesma
## cadencia de ResourcePropsManager.rebuild, chamado de
## HexGrid._rebuild_props() logo depois dele.
func rebuild(tiles: Dictionary) -> void:
	for coord in _sprites.keys():
		var sprite: Sprite3D = _sprites[coord]
		if sprite:
			sprite.queue_free()
	_sprites.clear()

	for coord in tiles.keys():
		var data: HexTileData = tiles[coord]
		if data.resource == "" or not _textures.has(data.resource):
			continue
		_spawn_icon(coord, data.resource)

func _spawn_icon(coord: Vector2i, kind: String) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _textures[kind]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# 32px * 0.016 = ~0.5 unidade de mundo, proporcional ao hex_size padrao
	# (1.0) — badge legivel sem dominar o tile.
	sprite.pixel_size = 0.016
	var pos = _hex_grid.world_for_coord(coord)
	pos.y += ICON_HEIGHT_OFFSET
	sprite.position = pos
	_hex_grid.add_child(sprite)
	_sprites[coord] = sprite

## Chamado de HexGrid._apply_prop_fog(), mesma cadencia dos outros props —
## ao contrario dos MultiMeshInstance3D (que precisam de alfa 0 via
## material porque instancias individuais nao tem "visible"), cada icone
## aqui e um Node3D de verdade, entao UNSEEN so esconde o node direto.
func apply_fog(visibility: Dictionary) -> void:
	for coord in _sprites.keys():
		var sprite: Sprite3D = _sprites[coord]
		var vis = visibility.get(coord, HexGrid.Visibility.UNSEEN)
		match vis:
			HexGrid.Visibility.UNSEEN:
				sprite.visible = false
			HexGrid.Visibility.EXPLORED:
				sprite.visible = true
				sprite.modulate = _hex_grid._sepia_prop_color(Color.WHITE)
			HexGrid.Visibility.VISIBLE:
				sprite.visible = true
				sprite.modulate = Color.WHITE

## Desenha, pixel a pixel, uma placa circular semi-transparente (contraste
## contra qualquer bioma de fundo, igual ao "plaque" do Civilization atras
## do icone de recurso) com a silhueta do recurso por cima em cor propria.
## Construida so UMA VEZ por tipo (a textura e sempre a mesma, igual as
## malhas de ResourcePropsManager).
func _build_icon_texture(kind: String) -> ImageTexture:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	var icon_color := _icon_color(kind)
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			var d := Vector2(x + 0.5, y + 0.5) - center
			var pixel := Color(0, 0, 0, 0)
			if d.length() <= BADGE_RADIUS:
				pixel = BADGE_COLOR
				if _icon_shape_hit(kind, d):
					pixel = icon_color
			img.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(img)

func _icon_color(kind: String) -> Color:
	match kind:
		"iron":
			return Color(0.8, 0.84, 0.9)
		"horses":
			return Color(0.88, 0.72, 0.32)
		"gems":
			return Color(0.85, 0.42, 0.95)
		"silk":
			return Color(0.55, 0.9, 0.55)
		"mana_node":
			return Color(0.4, 0.9, 0.95)
	return Color.WHITE

## `d` = offset em pixels a partir do centro do badge — cada recurso tem
## uma silhueta geometrica simples mas distinta o bastante pra reconhecer
## de relance (triangulo/minerio, ferradura, losango/gema, folha, faisca).
func _icon_shape_hit(kind: String, d: Vector2) -> bool:
	match kind:
		"iron":
			return _hit_triangle(d)
		"horses":
			return _hit_horseshoe(d)
		"gems":
			return _hit_diamond(d)
		"silk":
			return _hit_leaf(d)
		"mana_node":
			return _hit_sparkle(d)
	return false

## Triangulo apontando pra cima (pico/minerio exposto) — apice em y=-7,
## base em y=6, largura interpolada linearmente entre os dois.
func _hit_triangle(d: Vector2) -> bool:
	var apex_y := -7.0
	var base_y := 6.0
	var half_base := 8.0
	if d.y < apex_y or d.y > base_y:
		return false
	var t: float = (d.y - apex_y) / (base_y - apex_y)
	return abs(d.x) <= half_base * t

## Losango (quadrado rotacionado 45 graus) via distancia de Manhattan —
## silhueta de gema classica.
func _hit_diamond(d: Vector2) -> bool:
	return (abs(d.x) + abs(d.y)) <= 9.0

## Elipse alongada rotacionada 45 graus — le como folha/vagem (seda vem do
## bicho-da-seda que se alimenta de folha de amoreira, ver ResourceDatabase).
func _hit_leaf(d: Vector2) -> bool:
	var a := deg_to_rad(45.0)
	var rx := cos(a) * d.x + sin(a) * d.y
	var ry := -sin(a) * d.x + cos(a) * d.y
	return (rx * rx) / (9.0 * 9.0) + (ry * ry) / (4.0 * 4.0) <= 1.0

## Anel com abertura na parte de baixo (angulo ~90 graus no espaco de tela,
## y cresce pra baixo) — silhueta de ferradura.
func _hit_horseshoe(d: Vector2) -> bool:
	var r := d.length()
	if r < 5.0 or r > 9.0:
		return false
	var angle := rad_to_deg(atan2(d.y, d.x))
	var diff: float = abs(wrapf(angle - 90.0, -180.0, 180.0))
	return diff > 35.0

## Faisca de 8 pontas (cruz + X, afunilando do centro) com nucleo cheio —
## icone classico de "arcano/magia" pro Nodulo Arcano.
func _hit_sparkle(d: Vector2) -> bool:
	if d.length() <= 2.0:
		return true
	var ax: float = abs(d.x)
	var ay: float = abs(d.y)
	if ax <= 1.3 and ay <= 11.0:
		return true
	if ay <= 1.3 and ax <= 11.0:
		return true
	var diag1: float = abs(d.x - d.y)
	var diag2: float = abs(d.x + d.y)
	if diag1 <= 1.6 and (ax + ay) <= 11.0:
		return true
	if diag2 <= 1.6 and (ax + ay) <= 11.0:
		return true
	return false
