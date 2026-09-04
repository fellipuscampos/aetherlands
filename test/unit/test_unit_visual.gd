extends GutTest

## Identidade visual nova (pedido do usuario: "estude a questao de texturas
## e modelos 3d... substitua tudo... use todos os gratuitos" — pacotes
## KayKit, CC0). Cobre o hook em Unit._build_procedural_body()/_build_
## model_body()/_play_default_animation(): UnitData.model_scene_path troca
## o corpo procedural por uma cena externa, e UnitData.animation_scene_path
## (opcional) toca um clipe padrao reaproveitando o AnimationPlayer de um
## pacote de animacao compartilhado (mesmos nomes de osso entre pacotes de
## personagem e de animacao da KayKit, confirmado manualmente antes de
## implementar isto).

func test_unit_with_model_scene_path_adds_a_child_instead_of_procedural_shapes():
	var human := PlayerData.new(CivilizationData.new())
	var data := UnitData.new()
	data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, human, Vector2i(0, 0))

	assert_gt(unit.get_child_count(), 0, "corpo do modelo externo deveria ter sido adicionado como filho")

## Regressao: a primeira versao tingia cada MeshInstance3D com a cor da
## civilizacao (albedo_color = cor solida), o que lavava a textura pintada
## da KayKit pra uma cor chapada — reportado pelo usuario: "ta todos sem
## texturas". Confirma que NENHUM MeshInstance3D do modelo carregado ganha
## um material override desses (a unica fonte de material continua sendo o
## proprio arquivo importado).
func test_unit_model_body_does_not_override_mesh_materials():
	var human := PlayerData.new(CivilizationData.new())
	var data := UnitData.new()
	data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, human, Vector2i(0, 0))

	var mesh_instances: Array = []
	var stack: Array = unit.get_children()
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			mesh_instances.append(node)
		stack.append_array(node.get_children())

	assert_gt(mesh_instances.size(), 0, "precondicao: modelo deveria ter pelo menos um MeshInstance3D")
	for mi in mesh_instances:
		for i in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			assert_null(mi.get_surface_override_material(i), "nao deveria haver override de material (lavaria a textura pintada)")

func test_unit_with_animation_scene_path_plays_the_default_animation():
	var human := PlayerData.new(CivilizationData.new())
	var data := UnitData.new()
	data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
	data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, human, Vector2i(0, 0))

	var player := unit._find_animation_player(unit)
	assert_not_null(player, "deveria existir um AnimationPlayer dentro da unidade")
	assert_true(player.has_animation(Unit.DEFAULT_ANIMATION))
	assert_eq(player.current_animation, Unit.DEFAULT_ANIMATION, "deveria estar tocando o clipe padrao (Idle_A)")

## Pedido do usuario: "os mobs nao tem animacao de andando?" — slide_to()
## (unica funcao que move uma unidade visualmente, ver HexGrid.move_unit)
## precisa trocar pro clipe de andar assim que o movimento comeca.
func test_slide_to_switches_to_the_walk_animation():
	var human := PlayerData.new(CivilizationData.new())
	var data := UnitData.new()
	data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
	data.animation_scene_path = "res://assets/models/kaykit/animations/Rig_Medium_General.glb"
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, human, Vector2i(0, 0))

	var player := unit._find_animation_player(unit)
	assert_true(player.has_animation(Unit.WALK_ANIMATION), "biblioteca combinada deveria ter o clipe de andar tambem, nao so Idle")

	unit.slide_to(Vector3(1, 0, 0))

	assert_eq(player.current_animation, Unit.WALK_ANIMATION, "slide_to deveria trocar pro clipe de andar na hora")

func test_unit_without_animation_scene_path_has_no_animation_player():
	var human := PlayerData.new(CivilizationData.new())
	var data := UnitData.new()
	data.model_scene_path = "res://assets/models/kaykit/characters/Barbarian.glb"
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.setup(data, human, Vector2i(0, 0))

	assert_null(unit._find_animation_player(unit), "sem animation_scene_path, nao deveria criar AnimationPlayer nenhum")
