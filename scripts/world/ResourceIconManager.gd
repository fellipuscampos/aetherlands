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
## arte de fundo. Desde 2026-10-13 o selo vem de IconCatalog.resource_badge: um pictograma de verdade por recurso
## (bigorna, ferradura, gema, carretel, cristais) na cor do recurso sobre um medalhão escuro — antes eram formas
## abstratas desenhadas aqui (triângulo, losango, elipse).
var _hex_grid: HexGrid

## Tamanho no mundo do selo de recurso = IconCatalog.BADGE_SIZE * ICON_PIXEL_SIZE (o quadro inclui a margem da
## sombra; o medalhão fica com ~0.48, proporcional ao hex).
const ICON_PIXEL_SIZE := 0.0042
## Altura acima da superficie: selos acima dos modelos exportados,
## incluindo a metade inferior do badge.
const ICON_HEIGHT_OFFSET := 0.55
const CRYSTAL_ICON_HEIGHT_OFFSET := 1.05
const MANA_NODE_ICON_HEIGHT_OFFSET := 1.15
const IRON_ICON_HEIGHT_OFFSET := 0.84
const SILK_ICON_HEIGHT_OFFSET := 0.98
const HORSE_ICON_HEIGHT_OFFSET := 1.0

var _textures: Dictionary = {} # resource_kind (String) -> ImageTexture
var _sprites: Dictionary = {} # Vector2i -> Sprite3D

func _init(hex_grid: HexGrid) -> void:
	_hex_grid = hex_grid
	for kind in IconCatalog.RESOURCE_ICONS:
		_textures[kind] = IconCatalog.resource_badge(kind)

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
		if _hex_grid.lairs_by_coord.has(coord):
			continue
		var data: HexTileData = tiles[coord]
		if data.resource == "" or not _textures.has(data.resource):
			continue
		_spawn_icon(coord, data.resource)

func refresh_tile(coord: Vector2i) -> void:
	var tile := _hex_grid.get_tile(coord)
	if _sprites.has(coord):
		_sprites[coord].free()
		_sprites.erase(coord)
	if tile and not _hex_grid.lairs_by_coord.has(coord) and _textures.has(tile.resource):
		_spawn_icon(coord, tile.resource)

## Ver ResourcePropsManager.clear_prop_at -- mesma remocao, so pro icone
## billboard (nunca respawna, ao contrario de refresh_tile acima: aqui a
## estrutura nova ocupou o tile de vez, nao e' uma atualizacao de terreno).
func clear_icon_at(coord: Vector2i) -> void:
	if _sprites.has(coord):
		_sprites[coord].free()
		_sprites.erase(coord)

func _spawn_icon(coord: Vector2i, kind: String) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _textures[kind]
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # arte suavizada, reduzida de 128 px
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = ICON_PIXEL_SIZE # selo legível sem dominar o tile
	var pos = _hex_grid.world_for_coord(coord)
	var icon_height := ICON_HEIGHT_OFFSET
	match kind:
		"gems":
			icon_height = CRYSTAL_ICON_HEIGHT_OFFSET
		"mana_node":
			icon_height = MANA_NODE_ICON_HEIGHT_OFFSET
		"iron":
			icon_height = IRON_ICON_HEIGHT_OFFSET
		"silk":
			icon_height = SILK_ICON_HEIGHT_OFFSET
		"horses":
			icon_height = HORSE_ICON_HEIGHT_OFFSET
	pos.y = _hex_grid._tile_surface_height(coord) + icon_height
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
		# Ícone só em tile VISÍVEL agora: a área explorada mostra o mapa (o próprio recurso continua lá, no chão), "porém
		# sem ícones" (pedido do usuário 2026-10-12) — é memória, não informação viva.
		sprite.visible = vis == HexGrid.Visibility.VISIBLE
