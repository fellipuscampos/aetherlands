class_name Building
extends Node3D

## Representacao 3D de um predio de cidade (ver BuildingDatabase) POSICIONADO
## no mapa — o jogador escolhe o tile ao encomendar o predio
## (SelectionManager.start_building_placement), do mesmo jeito que escolhe
## onde fundar uma cidade. Os prédios usam cenas KayKit ou arte própria
## (BuildingData.model_scene_path); os corpos procedurais dos prédios V1 e das
## estruturas das Escolas V1 saíram na Fase 25.

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
	var data: BuildingData = BuildingDatabase.get_building(building_id)
	# A arte segue a raça do dono ATUAL (BuildingArtCatalog); captura/load recriam o prédio.
	var model_path := BuildingDatabase.model_path_for(building_id, BuildingArtCatalog.race_of(owner_player))
	if data and model_path != "":
		var packed_scene := load(model_path) as PackedScene
		if packed_scene != null:
			_build_model(packed_scene, model_path, data.model_scale_multiplier, accent_color)
			return
	_build_fallback(accent_color)

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

## Carrega uma cena externa como corpo do predio em vez de montar
## geometria procedural — ver BuildingData.model_scene_path. `accent_color`
## (cor da civilizacao do dono) NUNCA tinge o modelo inteiro — primeira versao
## multiplicava albedo_color por cima da textura pintada (tecnica de "atlas
## gradiente" da KayKit) e lavava tudo pra uma cor lisa, reportado pelo
## usuario ("ta todos sem texturas"). A diferenciação por civilização é por
## ARQUIVO (arte da raça, BuildingArtCatalog); a cor do dono entra só nas
## malhas `*_Faction` (bandeira/placa) da arte própria, igual ao centro da cidade.
func _build_model(scene: PackedScene, model_path: String, scale_multiplier: float, accent_color: Color) -> void:
	var model: Node3D = scene.instantiate()
	add_child(model)
	# Arte própria em metros não usa a unidade de tile nativa do pacote KayKit.
	var generated := BuildingArtCatalog.is_generated(model_path)
	var source_scale := 1.0 if generated else KAYKIT_SCALE
	model.scale = Vector3.ONE * source_scale * scale_multiplier
	if generated:
		BuildingArtCatalog.apply_owner_color(model, accent_color.lightened(0.1))

## Fallback procedural (galpão baixo + chaminé) para um prédio sem model_scene_path — hoje todo
## prédio do BuildingDatabase tem modelo externo; isto só evita um tile vazio se um faltar.
func _build_fallback(accent_color: Color) -> void:
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
