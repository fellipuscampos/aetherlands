class_name LairStructure
extends Node3D

## Marcador 3D do Covil de Monstro, independente da Unit guardia (ver
## HexGrid._spawn_monster_lairs/destroy_lair). Antes, a unica pista visual
## de um covil era a tenda pendurada no proprio camp boss (Unit.
## _build_camp_marker) — matar/afastar o chefao apagava o covil do mapa
## mesmo que ele continuasse de pe gerando reforco (HexGrid.lair_coords
## nunca perdia a entrada). Agora o covil e uma entidade de terreno de
## verdade: sobrevive ao chefao e so some quando HexGrid.destroy_lair()
## e chamado de verdade (jogador entra no tile vazio, ver HexGrid.
## move_unit/_grant_lair_clear_reward).

var kind: String = "goblin"
var _hex_grid: HexGrid

## (MeshInstance3D, Color) por primitiva — guardado pra apply_fog_state
## poder re-tingir cada peca sem precisar remontar a malha inteira a cada
## troca de estado de nevoa (mesmo motivo de HexGrid._tint_props guardar
## coord_to_index em vez de reconstruir o MultiMesh toda hora).
var _tinted_meshes: Array = []

func build(for_kind: String, hex_grid: HexGrid) -> void:
	kind = for_kind
	_hex_grid = hex_grid
	match kind:
		"troll":
			_build_cave()
		"skeleton":
			_build_ossuary()
		"wyvern":
			_build_aerie()
		"dragon":
			_build_hoard()
		_: # "goblin" e qualquer kind desconhecido caem na Tenda padrao
			_build_tent()

func _add_mesh(mesh: Mesh, color: Color, position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	instance.material_override = mat
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	add_child(instance)
	_tinted_meshes.append({"mesh": instance, "base_color": color})

## Acampamento Goblin — mesma "tenda" (cone/piramide marrom) que antes
## vivia pendurada no camp boss (Unit._build_camp_marker), so que agora
## centrada no proprio tile em vez de deslocada ao lado da criatura.
const TENT_COLOR := Color(0.32, 0.24, 0.16)
func _build_tent() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.55, 0.5, 0.5)
	_add_mesh(mesh, TENT_COLOR, Vector3(0.0, 0.25, 0.0))

## Caverna de Troll — monte de rocha escura com uma "boca" mais escura
## ainda recuada, pra ler como entrada de caverna mesmo de longe.
const CAVE_ROCK_COLOR := Color(0.38, 0.36, 0.35)
const CAVE_MOUTH_COLOR := Color(0.08, 0.07, 0.07)
func _build_cave() -> void:
	var mound := SphereMesh.new()
	mound.radius = 0.5
	mound.height = 0.55
	_add_mesh(mound, CAVE_ROCK_COLOR, Vector3(0.0, 0.2, 0.0))
	var mouth := CylinderMesh.new()
	mouth.top_radius = 0.16
	mouth.bottom_radius = 0.2
	mouth.height = 0.3
	_add_mesh(mouth, CAVE_MOUTH_COLOR, Vector3(0.0, 0.18, 0.32), Vector3(90, 0, 0))

## Ossario de Esqueleto — pilha de ossos brancos/creme (mesma cor de
## MONSTER_KIND_COLORS["skeleton"] em Unit.gd) coroada por uma caveira.
const BONE_COLOR := Color(0.92, 0.9, 0.82)
func _build_ossuary() -> void:
	for i in range(3):
		var bone := CylinderMesh.new()
		bone.top_radius = 0.03
		bone.bottom_radius = 0.05
		bone.height = 0.55
		var angle = float(i) * 40.0 - 40.0
		_add_mesh(bone, BONE_COLOR, Vector3(0.0, 0.2, 0.0), Vector3(0, 0, 70 + angle))
	var skull := SphereMesh.new()
	skull.radius = 0.16
	skull.height = 0.3
	_add_mesh(skull, BONE_COLOR, Vector3(0.0, 0.4, 0.0))

## Ninho de Vivern — anel de espinhos escuros erguido sobre uma base de
## rocha, tipo um ninho de aves de rapina numa saliencia.
const AERIE_BASE_COLOR := Color(0.4, 0.32, 0.26)
const AERIE_SPIKE_COLOR := Color(0.2, 0.14, 0.12)
func _build_aerie() -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.45
	base.bottom_radius = 0.5
	base.height = 0.2
	_add_mesh(base, AERIE_BASE_COLOR, Vector3(0.0, 0.1, 0.0))
	for i in range(6):
		var angle = TAU * float(i) / 6.0
		var spike := PrismMesh.new()
		spike.size = Vector3(0.1, 0.35, 0.1)
		var offset = Vector3(cos(angle) * 0.35, 0.15, sin(angle) * 0.35)
		_add_mesh(spike, AERIE_SPIKE_COLOR, offset, Vector3(0, rad_to_deg(angle), 0))

## Covil de Dragao — monte de obsidiana roxa com fragmentos "brilhantes"
## de tesouro, escala bem maior que o resto (mesmo espirito de Unit.gd:
## Dragao reusa a silhueta do Vivern numa escala maior, "precisa ler
## muito maior a distancia").
const HOARD_ROCK_COLOR := Color(0.3, 0.12, 0.32)
const HOARD_GEM_COLOR := Color(0.85, 0.7, 0.15)
func _build_hoard() -> void:
	var mound := SphereMesh.new()
	mound.radius = 0.65
	mound.height = 0.7
	_add_mesh(mound, HOARD_ROCK_COLOR, Vector3(0.0, 0.25, 0.0))
	for i in range(4):
		var angle = TAU * float(i) / 4.0
		var gem := PrismMesh.new()
		gem.size = Vector3(0.1, 0.16, 0.1)
		var offset = Vector3(cos(angle) * 0.4, 0.45, sin(angle) * 0.4)
		_add_mesh(gem, HOARD_GEM_COLOR, offset)

## UNSEEN esconde de vez (mesmo tratamento binario de alfa 0 que os props
## de HexGrid usam via TRANSPARENCY_ALPHA_SCISSOR); EXPLORED tinge sepia
## (HexGrid._sepia_prop_color, reusado — nao duplicado, mesmo padrao que
## ResourcePropsManager.apply_fog ja usa); VISIBLE volta a cor original.
func apply_fog_state(vis: int) -> void:
	visible = vis != HexGrid.Visibility.UNSEEN
	if not visible or _hex_grid == null:
		return
	for entry in _tinted_meshes:
		var mesh: MeshInstance3D = entry.mesh
		var mat: StandardMaterial3D = mesh.material_override
		if mat == null:
			continue
		if vis == HexGrid.Visibility.EXPLORED:
			mat.albedo_color = _hex_grid._sepia_prop_color(entry.base_color)
		else:
			mat.albedo_color = entry.base_color
