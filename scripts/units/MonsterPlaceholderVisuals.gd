class_name MonsterPlaceholderVisuals
extends RefCounted

## V3 / Combat Ecology — Etapa 1: silhuetas PROVISÓRIAS das espécies novas do bestiário (Worg, Aranha
## Gigante, Minotauro, Basilisco, Verme Colossal, Ancião Arbóreo, Devorador de Mana, Herói Corrompido).
## Só primitivas (Box/Cylinder/Capsule/Sphere) + materiais simples, com escala crescente por tier
## (BASIC pequeno, INTERMEDIATE médio, ADVANCED grande) para cada espécie ser reconhecível à distância.
## Não é arte final: o Presentation Pass substitui isto por modelos de verdade. A ausência de modelo
## nunca bloqueia spawn/movimento/combate/save — Unit._build_procedural_body chama isto só no ramo
## padrão e cai na cápsula genérica se a espécie não estiver aqui.

const KINDS: Array[String] = ["worg", "giant_spider", "minotaur", "basilisk", "colossal_worm", "arboreal_ancient", "mana_devourer", "corrupted_hero"]

## Constrói a silhueta de `kind` sob `root` (a própria Unit) usando `mat` (cor do corpo). false = sem
## placeholder para esse kind (o chamador segue com o fallback).
static func build(kind: String, root: Node3D, mat: StandardMaterial3D) -> bool:
	match kind:
		"worg":
			_worg(root, mat)
		"giant_spider":
			_giant_spider(root, mat)
		"minotaur":
			_minotaur(root, mat)
		"basilisk":
			_basilisk(root, mat)
		"colossal_worm":
			_colossal_worm(root, mat)
		"arboreal_ancient":
			_arboreal_ancient(root, mat)
		"mana_devourer":
			_mana_devourer(root, mat)
		"corrupted_hero":
			_corrupted_hero(root, mat)
		_:
			return false
	return true

static func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

static func _add(root: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.scale = scale
	root.add_child(instance)
	return instance

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height if height > 0.0 else radius * 2.0
	return mesh

static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh

static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh

## BASIC — lobo baixo e comprido (corpo horizontal, cabeça à frente, orelhas em ponta).
static func _worg(root: Node3D, mat: StandardMaterial3D) -> void:
	_add(root, _capsule(0.15, 0.62), mat, Vector3(0, 0.3, 0), Vector3(90, 0, 0))
	_add(root, _box(Vector3(0.2, 0.18, 0.24)), mat, Vector3(0, 0.38, 0.34))
	var ear := _cylinder(0.0, 0.05, 0.12)
	_add(root, ear, mat, Vector3(-0.06, 0.52, 0.3))
	_add(root, ear, mat, Vector3(0.06, 0.52, 0.3))
	var eye := _material(Color(1.0, 0.8, 0.1), 1.5)
	_add(root, _sphere(0.025), eye, Vector3(-0.06, 0.41, 0.46))
	_add(root, _sphere(0.025), eye, Vector3(0.06, 0.41, 0.46))
	var leg := _cylinder(0.035, 0.035, 0.24)
	for x in [-0.09, 0.09]:
		for z in [-0.18, 0.18]:
			_add(root, leg, mat, Vector3(x, 0.12, z))

## BASIC — corpo achatado escuro com oito pernas abertas.
static func _giant_spider(root: Node3D, mat: StandardMaterial3D) -> void:
	_add(root, _sphere(0.22, 0.26), mat, Vector3(0, 0.26, -0.08))
	_add(root, _sphere(0.12), mat, Vector3(0, 0.24, 0.18))
	var eye := _material(Color(0.9, 0.1, 0.1), 1.2)
	_add(root, _sphere(0.03), eye, Vector3(-0.04, 0.3, 0.29))
	_add(root, _sphere(0.03), eye, Vector3(0.04, 0.3, 0.29))
	var leg := _cylinder(0.018, 0.018, 0.42)
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 0.12 - float(i) * 0.1
			_add(root, leg, mat, Vector3(side * 0.24, 0.2, z), Vector3(0, float(i - 1.5) * 18.0 * side, side * 62.0))

## INTERMEDIATE — torso largo e alto, cabeça com dois chifres claros.
static func _minotaur(root: Node3D, mat: StandardMaterial3D) -> void:
	var root_node := Node3D.new()
	root_node.scale = Vector3.ONE * 1.2
	root.add_child(root_node)
	_add(root_node, _box(Vector3(0.44, 0.52, 0.3)), mat, Vector3(0, 0.62, 0))
	var leg := _box(Vector3(0.14, 0.36, 0.16))
	_add(root_node, leg, mat, Vector3(-0.11, 0.18, 0))
	_add(root_node, leg, mat, Vector3(0.11, 0.18, 0))
	_add(root_node, _box(Vector3(0.24, 0.24, 0.26)), mat, Vector3(0, 1.0, 0.04))
	var horn := _material(Color(0.93, 0.88, 0.75))
	var horn_mesh := _cylinder(0.0, 0.045, 0.24)
	_add(root_node, horn_mesh, horn, Vector3(-0.18, 1.1, 0.04), Vector3(0, 0, 55))
	_add(root_node, horn_mesh, horn, Vector3(0.18, 1.1, 0.04), Vector3(0, 0, -55))
	var axe := _material(Color(0.55, 0.55, 0.6))
	_add(root_node, _cylinder(0.025, 0.025, 0.7), _material(Color(0.4, 0.28, 0.16)), Vector3(0.3, 0.6, 0.12))
	_add(root_node, _box(Vector3(0.05, 0.2, 0.24)), axe, Vector3(0.3, 0.9, 0.2))

## INTERMEDIATE — réptil comprido rente ao chão, cauda e olhos amarelos brilhantes.
static func _basilisk(root: Node3D, mat: StandardMaterial3D) -> void:
	_add(root, _capsule(0.2, 0.9), mat, Vector3(0, 0.24, 0), Vector3(90, 0, 0))
	_add(root, _box(Vector3(0.26, 0.2, 0.3)), mat, Vector3(0, 0.3, 0.52))
	_add(root, _cylinder(0.02, 0.12, 0.5), mat, Vector3(0, 0.2, -0.62), Vector3(-80, 0, 0))
	var eye := _material(Color(1.0, 0.9, 0.2), 2.5)
	_add(root, _sphere(0.045), eye, Vector3(-0.09, 0.36, 0.66))
	_add(root, _sphere(0.045), eye, Vector3(0.09, 0.36, 0.66))
	var crest := _material(Color(0.6, 0.15, 0.1))
	for i in 3:
		_add(root, _cylinder(0.0, 0.05, 0.16), crest, Vector3(0, 0.46, 0.25 - float(i) * 0.22))

## ADVANCED — segmentos grandes arqueados saindo do chão (a cabeça com anel de dentes).
static func _colossal_worm(root: Node3D, mat: StandardMaterial3D) -> void:
	var segments := [Vector3(0, 0.22, -0.42), Vector3(0, 0.5, -0.18), Vector3(0, 0.8, 0.06), Vector3(0, 1.02, 0.3)]
	for i in segments.size():
		_add(root, _sphere(0.32 - float(i) * 0.03), mat, segments[i])
	var mouth := _material(Color(0.35, 0.05, 0.05))
	_add(root, _cylinder(0.2, 0.2, 0.08), mouth, Vector3(0, 1.08, 0.52), Vector3(70, 0, 0))
	var tooth := _material(Color(0.95, 0.92, 0.8))
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_add(root, _cylinder(0.0, 0.03, 0.1), tooth, Vector3(cos(angle) * 0.16, 1.1 + sin(angle) * 0.05, 0.56 + sin(angle) * 0.14), Vector3(70, 0, 0))
	# V3 / Etapa 3: corpo VISUAL longo — dorsos semienterrados atrás da cabeça, passando um pouco do hex (lê como
	# criatura colossal). Lógica continua 1 hex: os dorsos não bloqueiam nem ocupam o tile vizinho.
	var humps := [Vector3(0.05, 0.06, -0.78), Vector3(-0.06, 0.04, -1.04), Vector3(0.04, 0.02, -1.26)]
	for i in humps.size():
		_add(root, _sphere(0.24 - float(i) * 0.04, 0.3 - float(i) * 0.05), mat, humps[i])

## ADVANCED — tronco alto com copa larga e dois galhos-braços.
static func _arboreal_ancient(root: Node3D, mat: StandardMaterial3D) -> void:
	var bark := _material(Color(0.36, 0.24, 0.14))
	_add(root, _cylinder(0.2, 0.28, 1.1), bark, Vector3(0, 0.55, 0))
	_add(root, _sphere(0.55, 0.8), mat, Vector3(0, 1.3, 0))
	var arm := _cylinder(0.05, 0.08, 0.6)
	_add(root, arm, bark, Vector3(-0.34, 0.8, 0), Vector3(0, 0, 55))
	_add(root, arm, bark, Vector3(0.34, 0.8, 0), Vector3(0, 0, -55))
	var eye := _material(Color(0.7, 1.0, 0.4), 2.0)
	_add(root, _sphere(0.045), eye, Vector3(-0.08, 0.86, 0.22))
	_add(root, _sphere(0.045), eye, Vector3(0.08, 0.86, 0.22))
	var root_mesh := _cylinder(0.03, 0.08, 0.35)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		_add(root, root_mesh, bark, Vector3(cos(angle) * 0.3, 0.08, sin(angle) * 0.3), Vector3(sin(angle) * 60.0, 0, -cos(angle) * 60.0))

## ADVANCED — esfera escura flutuante com núcleo violeta brilhante e anel.
static func _mana_devourer(root: Node3D, mat: StandardMaterial3D) -> void:
	var shell := _material(Color(0.08, 0.05, 0.14))
	_add(root, _sphere(0.42), shell, Vector3(0, 0.9, 0))
	_add(root, _sphere(0.22), _material(mat.albedo_color, 3.0), Vector3(0, 0.9, 0.26))
	_add(root, _cylinder(0.62, 0.62, 0.04), _material(mat.albedo_color, 1.2), Vector3(0, 0.9, 0), Vector3(18, 0, 12))
	var tendril := _cylinder(0.01, 0.06, 0.6)
	for i in 3:
		var angle := TAU * float(i) / 3.0
		_add(root, tendril, shell, Vector3(cos(angle) * 0.2, 0.36, sin(angle) * 0.2))

## ADVANCED — cavaleiro alto e curvado (só se o GLB do Herói faltar): tronco, cabeça e escudo.
static func _corrupted_hero(root: Node3D, mat: StandardMaterial3D) -> void:
	_add(root, _cylinder(0.22, 0.26, 1.1), mat, Vector3(0, 0.75, 0))
	_add(root, _sphere(0.2), _material(Color(0.6, 0.6, 0.62)), Vector3(0, 1.45, -0.05))
	_add(root, _cylinder(0.25, 0.25, 0.05), _material(Color(0.5, 0.52, 0.56)), Vector3(0.35, 0.8, -0.2), Vector3(90, 0, 0))
