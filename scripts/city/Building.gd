class_name Building
extends Node3D

## Representacao 3D de um predio de cidade (ver BuildingDatabase) POSICIONADO
## no mapa — o jogador escolhe o tile ao encomendar o predio
## (SelectionManager.start_building_placement), do mesmo jeito que escolhe
## onde fundar uma cidade. Sem modelo Kenney equivalente disponivel (so
## torre+bandeira foram baixados, ver City.gd), cada tipo usa uma forma
## procedural distinta o bastante pra reconhecer de longe qual predio e.

var building_id: String
var coord: Vector2i
var owner_player: PlayerData

func setup(id: String, start_coord: Vector2i, player: PlayerData) -> void:
	building_id = id
	coord = start_coord
	owner_player = player
	_build_visual()

func _build_visual() -> void:
	var accent_color = owner_player.civ.color if owner_player else Color(0.6, 0.6, 0.6)
	match building_id:
		"granary":
			_build_granary(accent_color)
		"workshop":
			_build_workshop(accent_color)
		"market":
			_build_market(accent_color)
		"walls":
			_build_walls(accent_color)
		"barracks":
			_build_barracks(accent_color)
		"archery_range":
			_build_archery_range(accent_color)
		"stable":
			_build_stable(accent_color)
		"siege_workshop":
			_build_siege_workshop(accent_color)
		"arcane_tower":
			_build_arcane_tower(accent_color)
		"griffin_roost":
			_build_griffin_roost(accent_color)
		"druid_grove":
			_build_druid_grove(accent_color)

## Celeiro: silo (cilindro) + telhado conico, cor de graos.
func _build_granary(accent_color: Color) -> void:
	var silo := MeshInstance3D.new()
	var silo_mesh := CylinderMesh.new()
	silo_mesh.top_radius = 0.22
	silo_mesh.bottom_radius = 0.24
	silo_mesh.height = 0.4
	silo.mesh = silo_mesh
	var silo_mat := StandardMaterial3D.new()
	silo_mat.albedo_color = Color(0.75, 0.6, 0.35)
	silo.material_override = silo_mat
	silo.position.y = 0.2
	add_child(silo)

	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.02
	roof_mesh.bottom_radius = 0.28
	roof_mesh.height = 0.22
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = accent_color.darkened(0.2)
	roof.material_override = roof_mat
	roof.position.y = 0.51
	add_child(roof)

## Oficina: galpao baixo + chamine, cor de pedra/fumaca.
func _build_workshop(accent_color: Color) -> void:
	var shed := MeshInstance3D.new()
	var shed_mesh := BoxMesh.new()
	shed_mesh.size = Vector3(0.5, 0.32, 0.4)
	shed.mesh = shed_mesh
	var shed_mat := StandardMaterial3D.new()
	shed_mat.albedo_color = Color(0.45, 0.42, 0.4)
	shed.material_override = shed_mat
	shed.position.y = 0.16
	add_child(shed)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.55, 0.18, 0.45)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = accent_color.darkened(0.3)
	roof.material_override = roof_mat
	roof.position.y = 0.41
	add_child(roof)

	var chimney := MeshInstance3D.new()
	var chimney_mesh := CylinderMesh.new()
	chimney_mesh.top_radius = 0.045
	chimney_mesh.bottom_radius = 0.05
	chimney_mesh.height = 0.28
	chimney.mesh = chimney_mesh
	var chimney_mat := StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.3, 0.28, 0.26)
	chimney.material_override = chimney_mat
	chimney.position = Vector3(0.15, 0.5, 0.1)
	add_child(chimney)

## Mercado: banca + toldo triangular tingido na cor da civilizacao (mesma
## logica da bandeira da cidade — o toldo "anuncia" de quem e o mercado).
func _build_market(accent_color: Color) -> void:
	var stall := MeshInstance3D.new()
	var stall_mesh := BoxMesh.new()
	stall_mesh.size = Vector3(0.45, 0.22, 0.3)
	stall.mesh = stall_mesh
	var stall_mat := StandardMaterial3D.new()
	stall_mat.albedo_color = Color(0.55, 0.4, 0.25)
	stall.material_override = stall_mat
	stall.position.y = 0.11
	add_child(stall)

	var awning := MeshInstance3D.new()
	var awning_mesh := PrismMesh.new()
	awning_mesh.size = Vector3(0.55, 0.16, 0.4)
	awning.mesh = awning_mesh
	var awning_mat := StandardMaterial3D.new()
	awning_mat.albedo_color = accent_color
	awning.material_override = awning_mat
	awning.position.y = 0.3
	add_child(awning)

## Muralhas: segmentos de parede formando um arco baixo — nao cerca a
## cidade de verdade (so decora o tile), a defesa de verdade vem de
## BuildingDatabase.defense_bonus_for aplicado em CombatResolver.
func _build_walls(_accent_color: Color) -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.5, 0.52)
	for i in range(4):
		var angle = deg_to_rad(-60.0 + i * 40.0)
		var segment := MeshInstance3D.new()
		var segment_mesh := BoxMesh.new()
		segment_mesh.size = Vector3(0.22, 0.28, 0.1)
		segment.mesh = segment_mesh
		segment.material_override = stone_mat
		segment.position = Vector3(sin(angle) * 0.3, 0.14, cos(angle) * 0.3 - 0.1)
		segment.rotation.y = angle
		add_child(segment)

## Quartel: corpo baixo de pedra com "ameias" (blocos pequenos) no topo,
## tingidas na cor da civilizacao — silhueta de fortim, distinta do galpao
## civil da Oficina.
func _build_barracks(accent_color: Color) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.48, 0.34, 0.38)
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.42, 0.4, 0.38)
	body.material_override = body_mat
	body.position.y = 0.17
	add_child(body)

	var merlon_mat := StandardMaterial3D.new()
	merlon_mat.albedo_color = accent_color.darkened(0.2)
	for i in range(3):
		var merlon := MeshInstance3D.new()
		var merlon_mesh := BoxMesh.new()
		merlon_mesh.size = Vector3(0.1, 0.1, 0.1)
		merlon.mesh = merlon_mesh
		merlon.material_override = merlon_mat
		merlon.position = Vector3(-0.15 + i * 0.15, 0.39, 0.14)
		add_child(merlon)

## Campo de Tiro: alvo circular (aneis) preso num poste, de frente pra
## quem olha — silhueta simples o bastante pra ler "treino de arco" de
## longe sem precisar de flechas modeladas.
func _build_archery_range(accent_color: Color) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.03
	post_mesh.bottom_radius = 0.03
	post_mesh.height = 0.45
	post.mesh = post_mesh
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.4, 0.28, 0.18)
	post.material_override = post_mat
	post.position.y = 0.22
	add_child(post)

	var target := MeshInstance3D.new()
	var target_mesh := CylinderMesh.new()
	target_mesh.top_radius = 0.22
	target_mesh.bottom_radius = 0.22
	target_mesh.height = 0.04
	target.mesh = target_mesh
	var target_mat := StandardMaterial3D.new()
	target_mat.albedo_color = Color(0.85, 0.8, 0.7)
	target.material_override = target_mat
	target.position = Vector3(0, 0.42, 0)
	target.rotation_degrees = Vector3(90, 0, 0)
	add_child(target)

	var bullseye := MeshInstance3D.new()
	var bullseye_mesh := CylinderMesh.new()
	bullseye_mesh.top_radius = 0.07
	bullseye_mesh.bottom_radius = 0.07
	bullseye_mesh.height = 0.05
	bullseye.mesh = bullseye_mesh
	var bullseye_mat := StandardMaterial3D.new()
	bullseye_mat.albedo_color = accent_color
	bullseye.material_override = bullseye_mat
	bullseye.position = Vector3(0, 0.42, 0)
	bullseye.rotation_degrees = Vector3(90, 0, 0)
	add_child(bullseye)

## Estabulo: celeiro baixo com telhado em duas aguas (dois prismas
## inclinados) — mesma familia visual da Oficina, mas mais alongado e sem
## chamine, pra nao confundir os dois de longe.
func _build_stable(accent_color: Color) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.6, 0.28, 0.32)
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.55, 0.42, 0.28)
	body.material_override = body_mat
	body.position.y = 0.14
	add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.64, 0.16, 0.38)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = accent_color.darkened(0.3)
	roof.material_override = roof_mat
	roof.position.y = 0.36
	add_child(roof)

## Arsenal de Cerco: mesma oficina-galpao da Oficina normal, mas com um
## braco de catapulta encostado do lado de fora (a mesma silhueta usada
## pela Catapulta de verdade, ver Unit._build_procedural_body) — deixa
## claro que aqui e onde maquinas de cerco sao montadas.
func _build_siege_workshop(accent_color: Color) -> void:
	var shed := MeshInstance3D.new()
	var shed_mesh := BoxMesh.new()
	shed_mesh.size = Vector3(0.42, 0.3, 0.36)
	shed.mesh = shed_mesh
	var shed_mat := StandardMaterial3D.new()
	shed_mat.albedo_color = Color(0.4, 0.38, 0.36)
	shed.material_override = shed_mat
	shed.position = Vector3(-0.08, 0.15, 0)
	add_child(shed)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.06, 0.42, 0.06)
	arm.mesh = arm_mesh
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = accent_color.darkened(0.3)
	arm.material_override = arm_mat
	arm.position = Vector3(0.2, 0.24, 0)
	arm.rotation_degrees = Vector3(0, 0, -22)
	add_child(arm)

## Torre Arcana: torre fina e alta com um orbe brilhante no topo (esfera
## bem clara, "brilhante" o bastante sem precisar de shader emissivo) —
## unica silhueta VERTICAL entre os predios, de proposito, pra destacar
## que magia e diferente de artesanato/milicia comuns.
func _build_arcane_tower(accent_color: Color) -> void:
	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.08
	spire_mesh.bottom_radius = 0.14
	spire_mesh.height = 0.75
	spire.mesh = spire_mesh
	var spire_mat := StandardMaterial3D.new()
	spire_mat.albedo_color = accent_color.darkened(0.35)
	spire.material_override = spire_mat
	spire.position.y = 0.37
	add_child(spire)

	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.11
	orb_mesh.height = 0.22
	orb.mesh = orb_mesh
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.7, 0.85, 1.0)
	orb.material_override = orb_mat
	orb.position.y = 0.82
	add_child(orb)

## Poleiro de Grifos: poste alto com uma plataforma e um telhado inclinado
## no topo (tipo um pombal), alto o bastante pra sugerir "aqui e onde os
## grifos pousam" mesmo sem animar o proprio grifo.
func _build_griffin_roost(accent_color: Color) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.05
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 0.55
	post.mesh = post_mesh
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.4, 0.28, 0.18)
	post.material_override = post_mat
	post.position.y = 0.27
	add_child(post)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 0.22
	platform_mesh.bottom_radius = 0.22
	platform_mesh.height = 0.05
	platform.mesh = platform_mesh
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.5, 0.38, 0.26)
	platform.material_override = platform_mat
	platform.position.y = 0.56
	add_child(platform)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(0.3, 0.2, 0.3)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = accent_color.darkened(0.2)
	roof.material_override = roof_mat
	roof.position.y = 0.7
	add_child(roof)

## Bosque Druida: arvore sagrada pequena (mesma familia visual do Ent, ver
## Unit._build_procedural_body) cercada por 3 pedras baixas num circulo —
## um bosque em miniatura em vez de mais uma "casa".
func _build_druid_grove(_accent_color: Color) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.06
	trunk_mesh.bottom_radius = 0.09
	trunk_mesh.height = 0.3
	trunk.mesh = trunk_mesh
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.24, 0.16)
	trunk.material_override = trunk_mat
	trunk.position.y = 0.15
	add_child(trunk)

	var foliage := MeshInstance3D.new()
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = 0.22
	foliage_mesh.height = 0.44
	foliage.mesh = foliage_mesh
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.2, 0.45, 0.22)
	foliage.material_override = foliage_mat
	foliage.position.y = 0.42
	add_child(foliage)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.55, 0.55, 0.58)
	for i in range(3):
		var angle = deg_to_rad(i * 120.0)
		var stone := MeshInstance3D.new()
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.06
		stone_mesh.height = 0.1
		stone.mesh = stone_mesh
		stone.material_override = stone_mat
		stone.position = Vector3(sin(angle) * 0.28, 0.05, cos(angle) * 0.28)
		add_child(stone)
