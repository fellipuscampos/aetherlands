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
