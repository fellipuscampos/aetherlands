class_name Building
extends Node3D

## Representacao 3D de um predio de cidade (ver BuildingDatabase) POSICIONADO
## no mapa — o jogador escolhe o tile ao encomendar o predio
## (SelectionManager.start_building_placement), do mesmo jeito que escolhe
## onde fundar uma cidade. Sem modelo Kenney equivalente disponivel (so
## torre+bandeira foram baixados, ver City.gd), cada tipo usa uma forma
## procedural distinta o bastante pra reconhecer de longe qual predio e.
## Excecao: um predio com BuildingData.self_placed (so Muralhas por
## enquanto) nunca vira uma instancia desta classe — o efeito dele e
## inteiramente visual DENTRO da propria City (ver City._add_walls),
## entao nao passa pelo fluxo de escolha de tile nem aparece no match
## abaixo.

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
	# Identidade visual nova (pedido do usuario, ver BuildingData.model_
	# scene_path) — se o predio tiver um modelo externo definido, usa ele
	# em vez de cair no match procedural abaixo. "" (a maioria ainda hoje)
	# continua no comportamento de sempre.
	var data: BuildingData = BuildingDatabase.get_building(building_id)
	if data and data.model_scene_path != "":
		_build_model(data.model_scene_path, accent_color)
		return
	match building_id:
		"granary":
			_build_granary(accent_color)
		"workshop":
			_build_workshop(accent_color)
		"market":
			_build_market(accent_color)
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
		"arcane_sanctuary":
			_build_arcane_sanctuary(accent_color)

## Fator de escala UNICO pra todo modelo do KayKit Medieval Hexagon Pack —
## pedido do usuario apos ver o resultado da primeira tentativa (altura-alvo
## fixa por modelo): "acho que voce chapou um pouco, tem coisa que tem que
## ser maiorzinha e tem coisa que tem que ser menorzinha, faça uma analise
## robusta e pare de tapar buraco". Normalizar TODO predio pra uma unica
## altura-alvo (tentativa anterior) destruia a proporcao relativa que o
## proprio pacote ja definiu de proposito (Moinho vira do MESMO tamanho que
## o Quartel, por exemplo, quando deveriam ser bem diferentes).
##
## A correcao: medir o proprio tile hexagonal do pacote (Assets/gltf/tiles/
## base/hex_grass.gltf) em vez de qualquer predio individual — um hexagono
## regular sem esqueleto/skinning, entao a medicao e limpa e confiavel (ao
## contrario de personagem, que tem bind pose com braco afastado do corpo
## pra ficar bom de "riggar", inflando a largura crua sem representar o
## tamanho real do personagem em pe — motivo de Unit.gd continuar usando
## altura-alvo por modelo em vez deste mesmo esquema). Medido nesta sessao:
## corner-a-corner = 2.309, face-a-face = 2.0 — a razao entre os dois
## (2.309/2.0 = 2/sqrt(3)) confirma que 2.309 e o DIAMETRO (2x circunraio),
## entao o circunraio nativo do pacote e 2.309/2 = 1.1547. Escalar por
## hex_size/1.1547 (hex_size=1.0 nesta partida, ver HexGrid.gd) faz QUALQUER
## modelo do pacote caber exatamente no proprio tile do JOGO do jeito que o
## artista desenhou pro TILE DELE — preserva toda proporcao relativa entre
## predios (Torre alta e mais alta que Moinho baixo, etc.) em vez de achatar
## tudo pro mesmo tamanho.
const KAYKIT_SCALE := 1.0 / 1.1547 # = sqrt(3)/2, ver derivacao acima

## Carrega uma cena externa (KayKit) como corpo do predio em vez de montar
## geometria procedural — ver BuildingData.model_scene_path. `accent_color`
## (cor da civilizacao do dono) NAO tinge o modelo aqui de proposito —
## primeira versao multiplicava albedo_color por cima da textura pintada
## (tecnica de "atlas gradiente" da KayKit) e lavava tudo pra uma cor lisa,
## reportado pelo usuario ("ta todos sem texturas"). Os arquivos ja
## baixados sao todos a variante "blue" do pack (que tem 4 cores prontas
## por predio); diferenciar por civilizacao de verdade fica pra um passe
## futuro que troque de ARQUIVO por civ em vez de tingir em runtime.
func _build_model(scene_path: String, _accent_color: Color) -> void:
	var scene: PackedScene = load(scene_path)
	var model: Node3D = scene.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * KAYKIT_SCALE

## Kit de estilo (RaceTheme) do dono deste predio, ou o kit "human" (que e
## byte-a-byte o material original de antes desta mudanca, ver RaceTheme.
## STYLE_KITS) se nao houver dono — nenhum predio hoje e construido sem
## owner_player de verdade, mas o fallback existe pelo mesmo motivo de
## _body_color() em Unit.gd: nunca deixar uma leitura de .civ.race travar
## por causa de um dono nulo.
func _race_style_kit() -> Dictionary:
	return RaceTheme.style_kit(owner_player.civ.race if owner_player else "human")

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

## Quartel: pedido do usuario ("faça a construção do quartel ser algo mais
## medieval") — evolui do bloco liso + 3 cubos antigo pra uma leitura de
## "pequeno forte": corpo de pedra com ameias na frente E atras (parapeito
## completo, nao so uma fileira), porta de madeira escura encaixada na
## fachada, e uma torre de canto com telhado conico + bandeirola na cor da
## civilizacao (mesmo principio do toldo do Mercado: o pano tingido "avisa"
## de quem e o predio) — silhueta de castelo em miniatura, a mais alta e
## elaborada entre os predios civis, atras so da Torre Arcana.
func _build_barracks(accent_color: Color) -> void:
	var stone_color: Color = _race_style_kit().barracks_color
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.46, 0.34, 0.36)
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = stone_color
	body.material_override = body_mat
	body.position.y = 0.17
	add_child(body)

	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.11, 0.17, 0.02)
	door.mesh = door_mesh
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.22, 0.15, 0.1)
	door.material_override = door_mat
	door.position = Vector3(0, 0.085, 0.19)
	add_child(door)

	var merlon_mat := StandardMaterial3D.new()
	merlon_mat.albedo_color = accent_color.darkened(0.2)
	for z in [0.14, -0.14]:
		for i in range(4):
			var merlon := MeshInstance3D.new()
			var merlon_mesh := BoxMesh.new()
			merlon_mesh.size = Vector3(0.08, 0.09, 0.08)
			merlon.mesh = merlon_mesh
			merlon.material_override = merlon_mat
			merlon.position = Vector3(-0.18 + i * 0.12, 0.385, z)
			add_child(merlon)

	var turret := MeshInstance3D.new()
	var turret_mesh := CylinderMesh.new()
	turret_mesh.top_radius = 0.09
	turret_mesh.bottom_radius = 0.11
	turret_mesh.height = 0.5
	turret.mesh = turret_mesh
	var turret_mat := StandardMaterial3D.new()
	turret_mat.albedo_color = stone_color.darkened(0.15)
	turret.material_override = turret_mat
	turret.position = Vector3(0.2, 0.25, -0.16)
	add_child(turret)

	var turret_roof := MeshInstance3D.new()
	var turret_roof_mesh := CylinderMesh.new()
	turret_roof_mesh.top_radius = 0.005
	turret_roof_mesh.bottom_radius = 0.13
	turret_roof_mesh.height = 0.22
	turret_roof.mesh = turret_roof_mesh
	var turret_roof_mat := StandardMaterial3D.new()
	turret_roof_mat.albedo_color = accent_color.darkened(0.25)
	turret_roof.material_override = turret_roof_mat
	turret_roof.position = Vector3(0.2, 0.61, -0.16)
	add_child(turret_roof)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.012
	pole_mesh.bottom_radius = 0.012
	pole_mesh.height = 0.18
	pole.mesh = pole_mesh
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.3, 0.22, 0.15)
	pole.material_override = pole_mat
	pole.position = Vector3(0.2, 0.81, -0.16)
	add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_mesh := PrismMesh.new()
	flag_mesh.size = Vector3(0.1, 0.06, 0.015)
	flag.mesh = flag_mesh
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = accent_color
	flag.material_override = flag_mat
	flag.position = Vector3(0.25, 0.85, -0.16)
	flag.rotation_degrees = Vector3(0, 90, 0)
	add_child(flag)

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
	post_mat.albedo_color = _race_style_kit().archery_range_color
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
	body_mat.albedo_color = _race_style_kit().stable_color
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

## Santuario do Nodulo: dais de pedra baixo + pedestal com um cristal arcano
## flutuante no topo (roxo, cor FIXA que representa o proprio nodulo magico —
## nao a civilizacao, mesmo principio do orbe branco-azulado da Torre Arcana)
## e quatro obeliscos baixos tingidos na cor da civilizacao ao redor da base,
## marcando de quem e o santuario — mesma logica do toldo do Mercado/bandeira
## do Quartel, so que em pedra em vez de pano.
func _build_arcane_sanctuary(accent_color: Color) -> void:
	var dais := MeshInstance3D.new()
	var dais_mesh := CylinderMesh.new()
	dais_mesh.top_radius = 0.32
	dais_mesh.bottom_radius = 0.34
	dais_mesh.height = 0.06
	dais.mesh = dais_mesh
	var dais_mat := StandardMaterial3D.new()
	dais_mat.albedo_color = Color(0.55, 0.55, 0.58)
	dais.material_override = dais_mat
	dais.position.y = 0.03
	add_child(dais)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.05
	pedestal_mesh.bottom_radius = 0.07
	pedestal_mesh.height = 0.28
	pedestal.mesh = pedestal_mesh
	var pedestal_mat := StandardMaterial3D.new()
	pedestal_mat.albedo_color = Color(0.4, 0.4, 0.42)
	pedestal.material_override = pedestal_mat
	pedestal.position.y = 0.2
	add_child(pedestal)

	var crystal := MeshInstance3D.new()
	var crystal_mesh := SphereMesh.new()
	crystal_mesh.radius = 0.13
	crystal_mesh.height = 0.32
	crystal.mesh = crystal_mesh
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.6, 0.35, 0.85)
	crystal.material_override = crystal_mat
	crystal.position.y = 0.5
	add_child(crystal)

	var obelisk_mat := StandardMaterial3D.new()
	obelisk_mat.albedo_color = accent_color.darkened(0.15)
	for i in range(4):
		var angle = deg_to_rad(i * 90.0 + 45.0)
		var obelisk := MeshInstance3D.new()
		var obelisk_mesh := CylinderMesh.new()
		obelisk_mesh.top_radius = 0.01
		obelisk_mesh.bottom_radius = 0.03
		obelisk_mesh.height = 0.18
		obelisk.mesh = obelisk_mesh
		obelisk.material_override = obelisk_mat
		obelisk.position = Vector3(sin(angle) * 0.3, 0.09, cos(angle) * 0.3)
		add_child(obelisk)
